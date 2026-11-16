package main

import (
	"encoding/json"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// The test binary also plays agent-op, a fake op, and the command op runs,
// chosen by argv[0] and AGENT_OP_TEST_HELPER. Without the setgid wrapper the
// group drop is a no-op, so this checks the exec chain, not the permissions.
func TestMain(m *testing.M) {
	switch filepath.Base(os.Args[0]) {
	case "op":
		os.Exit(fakeOp())
	case "probe":
		os.Exit(probe())
	}
	if os.Getenv("AGENT_OP_TEST_HELPER") == "1" {
		tokenFile = os.Getenv("AGENT_OP_TEST_TOKEN_FILE")
		opProgram = os.Getenv("AGENT_OP_TEST_OP")
		selfProgram = os.Getenv("AGENT_OP_TEST_SELF")
		os.Exit(realMain(os.Args[1:]))
	}
	os.Exit(m.Run())
}

type opRecord struct {
	Args     []string          `json:"args"`
	Env      map[string]string `json:"env"`
	EnvFiles []string          `json:"envFiles"`
}

func fakeOp() int {
	rec := opRecord{Args: os.Args[1:], Env: map[string]string{}}
	for _, kv := range os.Environ() {
		name, value, _ := strings.Cut(kv, "=")
		if strings.HasPrefix(name, "OP_") || name == "GODEBUG" {
			rec.Env[name] = value
		}
	}
	command := []string(nil)
	for i, arg := range rec.Args {
		if path, ok := strings.CutPrefix(arg, "--env-file="); ok {
			content, err := os.ReadFile(path)
			if err != nil {
				rec.EnvFiles = append(rec.EnvFiles, "error: "+err.Error())
			} else {
				rec.EnvFiles = append(rec.EnvFiles, string(content))
			}
		}
		if arg == "--" {
			command = rec.Args[i+1:]
			break
		}
	}
	if err := writeJSON("op.json", rec); err != nil {
		return 3
	}
	if command == nil {
		return 0
	}
	cmd := exec.Command(command[0], command[1:]...)
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
	if err := cmd.Run(); err != nil {
		if exit, ok := errors.AsType[*exec.ExitError](err); ok {
			return exit.ExitCode()
		}
		return 4
	}
	return 0
}

func probe() int {
	_, present := os.LookupEnv(tokenVar)
	if err := writeJSON("probe.json", map[string]any{"tokenPresent": present, "args": os.Args[1:]}); err != nil {
		return 3
	}
	return 0
}

func writeJSON(name string, v any) error {
	data, err := json.Marshal(v)
	if err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(os.Getenv("AGENT_OP_TEST_OUT"), name), data, 0o600)
}

type harness struct {
	t    *testing.T
	dir  string
	self string
}

func newHarness(t *testing.T) *harness {
	t.Helper()
	self, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	dir := t.TempDir()
	for _, name := range []string{"op", "probe"} {
		if err := os.Symlink(self, filepath.Join(dir, name)); err != nil {
			t.Fatal(err)
		}
	}
	token := "OP_SERVICE_ACCOUNT_TOKEN=\"ops_test_token\"\n"
	if err := os.WriteFile(filepath.Join(dir, "token"), []byte(token), 0o600); err != nil {
		t.Fatal(err)
	}
	return &harness{t: t, dir: dir, self: self}
}

func (h *harness) run(args ...string) (int, string) {
	h.t.Helper()
	cmd := exec.Command(h.self, args...)
	cmd.Env = []string{
		"PATH=" + os.Getenv("PATH"),
		"AGENT_OP_TEST_HELPER=1",
		"AGENT_OP_TEST_TOKEN_FILE=" + filepath.Join(h.dir, "token"),
		"AGENT_OP_TEST_OP=" + filepath.Join(h.dir, "op"),
		"AGENT_OP_TEST_SELF=" + h.self,
		"AGENT_OP_TEST_OUT=" + h.dir,
		"OP_ACCOUNT=tony",
		"OP_SERVICE_ACCOUNT_TOKEN=from-caller",
		"GODEBUG=http2debug=2",
	}
	out, err := cmd.CombinedOutput()
	if err != nil {
		exit, ok := errors.AsType[*exec.ExitError](err)
		if !ok {
			h.t.Fatalf("running agent-op: %v", err)
		}
		return exit.ExitCode(), string(out)
	}
	return 0, string(out)
}

func (h *harness) read(name string, v any) bool {
	h.t.Helper()
	data, err := os.ReadFile(filepath.Join(h.dir, name))
	if errors.Is(err, os.ErrNotExist) {
		return false
	}
	if err != nil {
		h.t.Fatal(err)
	}
	if err := json.Unmarshal(data, v); err != nil {
		h.t.Fatal(err)
	}
	return true
}

func TestRunPassesTokenToOpOnly(t *testing.T) {
	h := newHarness(t)
	envFile := filepath.Join(h.dir, "refs.env")
	if err := os.WriteFile(envFile, []byte("A=op://Dev/item/credential\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	probePath := filepath.Join(h.dir, "probe")

	code, out := h.run("run", "--env-file", envFile, "--", probePath, "arg 1")
	if code != 0 {
		t.Fatalf("exit %d: %s", code, out)
	}

	var rec opRecord
	if !h.read("op.json", &rec) {
		t.Fatal("op did not run")
	}
	if got := rec.Env[tokenVar]; got != "ops_test_token" {
		t.Errorf("op got token %q, want the one from the token file", got)
	}
	if _, ok := rec.Env["OP_ACCOUNT"]; ok {
		t.Error("op inherited OP_ACCOUNT")
	}
	if _, ok := rec.Env["GODEBUG"]; ok {
		t.Error("op inherited GODEBUG")
	}
	if rec.Env["OP_BIOMETRIC_UNLOCK_ENABLED"] != "false" || rec.Env["OP_CACHE"] != "false" {
		t.Errorf("op env = %v, want biometric unlock and cache off", rec.Env)
	}
	if len(rec.EnvFiles) != 1 || rec.EnvFiles[0] != "A=op://Dev/item/credential\n" {
		t.Errorf("op read env files %q", rec.EnvFiles)
	}
	if strings.Contains(strings.Join(rec.Args, " "), envFile) {
		t.Errorf("op was given the env file path instead of a copy: %q", rec.Args)
	}

	var p struct {
		TokenPresent bool     `json:"tokenPresent"`
		Args         []string `json:"args"`
	}
	if !h.read("probe.json", &p) {
		t.Fatal("the command did not run")
	}
	if p.TokenPresent {
		t.Error("the command inherited OP_SERVICE_ACCOUNT_TOKEN")
	}
	if len(p.Args) != 1 || p.Args[0] != "arg 1" {
		t.Errorf("command args = %q", p.Args)
	}
	if strings.Contains(out, "ops_test_token") {
		t.Error("output contains the token")
	}
}

func TestRefusalsNeverReachOp(t *testing.T) {
	h := newHarness(t)
	leaky := filepath.Join(h.dir, "leak.env")
	if err := os.WriteFile(leaky, []byte("R=op://${OP_SERVICE_ACCOUNT_TOKEN}/y/z\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	for _, args := range [][]string{
		{"read", "op://v/i/f"},
		{"run", "--env-file=" + leaky, "--", "true"},
		{"run", filepath.Join(h.dir, "probe"), "--", "x"},
		{"run", "--env-file=" + filepath.Join(h.dir, "missing.env"), "--", "true"},
	} {
		code, out := h.run(args...)
		if code == 0 {
			t.Errorf("%q: exit 0, want a refusal", args)
		}
		if strings.Contains(out, "ops_test_token") {
			t.Errorf("%q: output contains the token", args)
		}
		var rec opRecord
		if h.read("op.json", &rec) {
			t.Fatalf("%q reached op", args)
		}
	}
}

func TestHelpSkipsToken(t *testing.T) {
	h := newHarness(t)
	if code, out := h.run("--version"); code != 0 {
		t.Fatalf("exit %d: %s", code, out)
	}
	var rec opRecord
	if !h.read("op.json", &rec) {
		t.Fatal("op did not run")
	}
	if _, ok := rec.Env[tokenVar]; ok {
		t.Error("--version passed a token to op")
	}
}

func TestMissingTokenFile(t *testing.T) {
	h := newHarness(t)
	if err := os.Remove(filepath.Join(h.dir, "token")); err != nil {
		t.Fatal(err)
	}
	code, out := h.run("whoami")
	if code != 1 || !strings.Contains(out, "cannot read the service-account token") {
		t.Errorf("exit %d, output %q", code, out)
	}
}
