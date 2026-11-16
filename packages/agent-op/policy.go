package main

import (
	"bytes"
	"fmt"
	"strings"
)

const usageHint = "hand secrets to a command with: agent-op run --env-file=<file of op:// refs> -- <cmd>"

// op run starts the command as `agent-op <childMarker> -- <cmd>`, so the
// process that still carries the token is setgid and therefore non-dumpable.
const childMarker = "__agent-op-child"

const tokenVar = "OP_SERVICE_ACCOUNT_TOKEN"

type refusal string

func (r refusal) Error() string { return string(r) }

func refusef(format string, args ...any) error {
	return refusal(fmt.Sprintf(format, args...))
}

type plan struct {
	needsToken bool
	opArgs     []string
	run        *runArgs
}

type runArgs struct {
	flags    []string
	envFiles []string
	// command is nil for `run --help`.
	command []string
}

// Flags op accepts before `run`'s `--`, by whether pflag reads a value for them.
// Anything else there is refused: pflag treats a bare word as the command, which
// would start it before the token is stripped.
var (
	runValueFlags = map[string]bool{
		"--env-file":    true,
		"--environment": true,
		"--config":      true,
		"--encoding":    true,
		"--format":      true,
	}
	runBoolFlags = map[string]bool{
		"--help":           true,
		"--iso-timestamps": true,
		"--no-color":       true,
	}
)

func parse(args []string) (*plan, error) {
	if len(args) == 0 {
		return nil, refusal("no subcommand given")
	}
	switch args[0] {
	case "--version", "-v", "--help", "-h":
		return &plan{opArgs: args}, nil
	case "whoami":
		if err := refuseFlags(args); err != nil {
			return nil, err
		}
		return &plan{needsToken: true, opArgs: args}, nil
	case "vault", "item":
		if len(args) < 2 || args[1] != "list" {
			second := ""
			if len(args) > 1 {
				second = args[1]
			}
			return nil, refusef("'%s %s' is not allowed (only '%s list')", args[0], second, args[0])
		}
		if err := refuseFlags(args); err != nil {
			return nil, err
		}
		return &plan{needsToken: true, opArgs: args}, nil
	case "run":
		run, err := parseRun(args[1:])
		if err != nil {
			return nil, err
		}
		return &plan{needsToken: true, run: run}, nil
	default:
		return nil, refusef("'%s' is not allowed (allowed: run, whoami, vault list, item list, --version, --help)", args[0])
	}
}

func refuseFlags(args []string) error {
	for _, arg := range args {
		if arg == "--" {
			return nil
		}
		if err := refuseFlag(arg); err != nil {
			return err
		}
	}
	return nil
}

func refuseFlag(arg string) error {
	if strings.HasPrefix(arg, "--no-masking") {
		return refusal("--no-masking is not allowed")
	}
	// --cache: op's cache daemon outlives the call, holds the session, and is
	// dumpable, so the service account always runs without it.
	for _, prefix := range []string{"--account", "--session", "--debug", "--cache"} {
		if strings.HasPrefix(arg, prefix) {
			name, _, _ := strings.Cut(arg, "=")
			return refusef("%s is not allowed", name)
		}
	}
	return nil
}

func parseRun(rest []string) (*runArgs, error) {
	run := &runArgs{}
	help := false
	for i := 0; i < len(rest); i++ {
		arg := rest[i]
		if arg == "--" {
			if i+1 < len(rest) {
				run.command = rest[i+1:]
			}
			break
		}
		if err := refuseFlag(arg); err != nil {
			return nil, err
		}
		name, value, hasValue := strings.Cut(arg, "=")
		switch {
		case arg == "-h":
			help = true
			run.flags = append(run.flags, arg)
		case runBoolFlags[name]:
			help = help || name == "--help"
			run.flags = append(run.flags, arg)
		case runValueFlags[name]:
			if !hasValue {
				if i+1 >= len(rest) {
					return nil, refusef("%s needs a value", name)
				}
				i++
				value = rest[i]
			}
			if name == "--env-file" {
				run.envFiles = append(run.envFiles, value)
			} else {
				run.flags = append(run.flags, name+"="+value)
			}
		default:
			return nil, refusef("'%s' is not allowed before run's '--' (allowed: --env-file, --environment, --config, --encoding, --format, --iso-timestamps, --no-color, --help)", arg)
		}
	}
	if run.command == nil && !help {
		return nil, refusal("run needs '-- <cmd>'")
	}
	return run, nil
}

func (r *runArgs) opArgs(envFilePaths []string, self string) []string {
	args := append([]string{"run"}, r.flags...)
	for _, path := range envFilePaths {
		args = append(args, "--env-file="+path)
	}
	if r.command != nil {
		args = append(args, "--", self, childMarker, "--")
		args = append(args, r.command...)
	}
	return args
}

// op expands $VAR and ${VAR} in env files from its own environment, which
// holds the token: `X=${OP_SERVICE_ACCOUNT_TOKEN}` hands it to the command,
// and `X=op://${OP_SERVICE_ACCOUNT_TOKEN}/a/b` prints it in an error.
func checkEnvFile(path string, content []byte) error {
	if bytes.ContainsRune(content, '$') {
		return refusef("env file %s uses '$'; variable expansion is not allowed", path)
	}
	return nil
}

func opEnv(environ []string, token string) ([]string, error) {
	env := make([]string, 0, len(environ)+3)
	for _, kv := range environ {
		name, value, _ := strings.Cut(kv, "=")
		if strings.HasPrefix(name, "OP_") || name == "GODEBUG" {
			continue
		}
		if strings.Contains(value, "op://") && strings.Contains(value, "$") {
			return nil, refusef("$%s holds a secret reference with '$'; variable expansion is not allowed", name)
		}
		env = append(env, kv)
	}
	if token != "" {
		env = append(env, tokenVar+"="+token)
	}
	return append(env, "OP_BIOMETRIC_UNLOCK_ENABLED=false", "OP_CACHE=false"), nil
}

func childEnv(environ []string) []string {
	env := make([]string, 0, len(environ))
	for _, kv := range environ {
		if name, _, _ := strings.Cut(kv, "="); name != tokenVar {
			env = append(env, kv)
		}
	}
	return env
}

func parseToken(content []byte) (string, bool) {
	token := ""
	for line := range strings.SplitSeq(string(content), "\n") {
		if value, ok := strings.CutPrefix(line, tokenVar+"="); ok {
			value = strings.TrimSuffix(value, `"`)
			token = strings.TrimPrefix(value, `"`)
		}
	}
	return token, token != ""
}
