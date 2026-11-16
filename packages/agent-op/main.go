// Command agent-op runs 1Password's op as this host's agent service account.
//
// NixOS installs it as a setgid-opagent wrapper. Only that group can read the
// token, so agents running as the user cannot. agent-op reads it, drops back
// to the real group, and execs op with the token in OP_SERVICE_ACCOUNT_TOKEN.
// Subcommands that print secret values are refused: hand secrets to a command
// with `agent-op run --env-file=<file of op:// refs> -- <cmd>`.
package main

import (
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"syscall"
	"unsafe"
)

// Set with -ldflags -X by packages/agent-op/default.nix. opProgram must be the
// setgid op wrapper: a process exec'd without a credential change is
// dumpable, and the user could read the token from /proc/<pid>/environ.
var (
	tokenFile   string
	opProgram   string
	selfProgram string
)

const (
	maxTokenFileSize = 64 << 10
	maxEnvFileSize   = 1 << 20
)

func main() {
	os.Exit(realMain(os.Args[1:]))
}

func realMain(args []string) int {
	if len(args) > 0 && args[0] == childMarker {
		return execChild(args[1:])
	}

	p, err := parse(args)
	if err != nil {
		fmt.Fprintf(os.Stderr, "agent-op: %v; %s\n", err, usageHint)
		return 2
	}
	if tokenFile == "" || opProgram == "" || selfProgram == "" {
		fmt.Fprintln(os.Stderr, "agent-op: built without its NixOS paths; install it through modules/nixos/agent-op.nix")
		return 1
	}

	token := ""
	var tokenErr error
	if p.needsToken {
		token, tokenErr = readToken(tokenFile)
	}
	// Everything after this runs with the user's own group, including reading
	// env files, so they cannot name the token file.
	if err := dropGroup(); err != nil {
		fmt.Fprintf(os.Stderr, "agent-op: %v\n", err)
		return 1
	}
	if tokenErr != nil {
		fmt.Fprintf(os.Stderr, "agent-op: %v\n", tokenErr)
		return 1
	}

	opArgs := p.opArgs
	if p.run != nil {
		paths, err := sealEnvFiles(p.run.envFiles)
		if err != nil {
			return report(err)
		}
		opArgs = p.run.opArgs(paths, selfProgram)
	}
	env, err := opEnv(os.Environ(), token)
	if err != nil {
		return report(err)
	}

	err = syscall.Exec(opProgram, append([]string{"op"}, opArgs...), env)
	fmt.Fprintf(os.Stderr, "agent-op: cannot run %s: %v\n", opProgram, err)
	return 1
}

func report(err error) int {
	if _, ok := errors.AsType[refusal](err); ok {
		fmt.Fprintf(os.Stderr, "agent-op: %v; %s\n", err, usageHint)
		return 2
	}
	fmt.Fprintf(os.Stderr, "agent-op: %v\n", err)
	return 1
}

func readToken(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", fmt.Errorf("cannot read the service-account token (agenix secret secrets/op/agents.age): %w", err)
	}
	defer f.Close()
	content, err := io.ReadAll(io.LimitReader(f, maxTokenFileSize))
	if err != nil {
		return "", fmt.Errorf("cannot read the service-account token: %w", err)
	}
	token, ok := parseToken(content)
	if !ok {
		return "", fmt.Errorf("no %s in %s", tokenVar, path)
	}
	return token, nil
}

func dropGroup() error {
	gid := syscall.Getgid()
	if err := syscall.Setresgid(gid, gid, gid); err != nil {
		return fmt.Errorf("cannot drop the opagent group: %w", err)
	}
	if syscall.Getegid() != gid {
		return errors.New("cannot drop the opagent group")
	}
	return nil
}

// sealEnvFiles copies each env file into a memfd that op inherits, so the file
// op parses is the one checked here, not one swapped in afterwards.
func sealEnvFiles(paths []string) ([]string, error) {
	sealed := make([]string, 0, len(paths))
	for _, path := range paths {
		content, err := readEnvFile(path)
		if err != nil {
			return nil, err
		}
		if err := checkEnvFile(path, content); err != nil {
			return nil, err
		}
		fd, err := memfdWithContent(content)
		if err != nil {
			return nil, fmt.Errorf("cannot pass env file %s to op: %w", path, err)
		}
		sealed = append(sealed, fmt.Sprintf("/proc/self/fd/%d", fd))
	}
	return sealed, nil
}

func readEnvFile(path string) ([]byte, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("cannot read env file: %w", err)
	}
	defer f.Close()
	content, err := io.ReadAll(io.LimitReader(f, maxEnvFileSize+1))
	if err != nil {
		return nil, fmt.Errorf("cannot read env file %s: %w", path, err)
	}
	if len(content) > maxEnvFileSize {
		return nil, refusef("env file %s is larger than %d bytes", path, maxEnvFileSize)
	}
	return content, nil
}

// The fd is left open across exec on purpose.
func memfdWithContent(content []byte) (int, error) {
	name, err := syscall.BytePtrFromString("agent-op-env-file")
	if err != nil {
		return -1, err
	}
	r, _, errno := syscall.Syscall(sysMemfdCreate, uintptr(unsafe.Pointer(name)), 0, 0)
	if errno != 0 {
		return -1, errno
	}
	fd := int(r)
	for len(content) > 0 {
		n, err := syscall.Write(fd, content)
		if err != nil {
			syscall.Close(fd)
			return -1, err
		}
		content = content[n:]
	}
	return fd, nil
}

func execChild(args []string) int {
	if err := dropGroup(); err != nil {
		fmt.Fprintf(os.Stderr, "agent-op: %v\n", err)
		return 1
	}
	if len(args) < 2 || args[0] != "--" {
		fmt.Fprintf(os.Stderr, "agent-op: %s needs '-- <cmd>'\n", childMarker)
		return 2
	}
	command := args[1:]
	path, err := exec.LookPath(command[0])
	if errors.Is(err, exec.ErrDot) {
		err = nil
	}
	if err != nil {
		fmt.Fprintf(os.Stderr, "agent-op: %v\n", err)
		return 127
	}
	err = syscall.Exec(path, command, childEnv(os.Environ()))
	fmt.Fprintf(os.Stderr, "agent-op: cannot run %s: %v\n", command[0], err)
	return 126
}
