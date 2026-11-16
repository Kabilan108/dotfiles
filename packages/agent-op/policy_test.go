package main

import (
	"errors"
	"slices"
	"testing"
)

func TestParseRefuses(t *testing.T) {
	tests := []struct {
		name string
		args []string
	}{
		{"no subcommand", nil},
		{"read", []string{"read", "op://v/i/f"}},
		{"inject", []string{"inject", "-i", "tpl"}},
		{"item get", []string{"item", "get", "x"}},
		{"item without verb", []string{"item"}},
		{"vault get", []string{"vault", "get", "x"}},
		{"signin", []string{"signin"}},
		{"global flag first", []string{"--format", "json", "whoami"}},
		{"whoami --account", []string{"whoami", "--account", "my"}},
		{"whoami --account=", []string{"whoami", "--account=my"}},
		{"whoami --session", []string{"whoami", "--session=abc"}},
		{"whoami --debug", []string{"whoami", "--debug"}},
		{"whoami --cache", []string{"whoami", "--cache=true"}},
		{"item list --debug", []string{"item", "list", "--debug"}},
		{"vault list --account", []string{"vault", "list", "--account", "x"}},
		{"run --no-masking", []string{"run", "--no-masking", "--", "env"}},
		{"run --no-masking=", []string{"run", "--no-masking=true", "--", "env"}},
		{"run --debug", []string{"run", "--debug", "--", "env"}},
		{"run --cache", []string{"run", "--cache", "--", "env"}},
		{"run without --", []string{"run", "--env-file=a"}},
		{"run with empty command", []string{"run", "--env-file=a", "--"}},
		{"run with nothing", []string{"run"}},
		{"run positional before --", []string{"run", "python3", "--", "-c", "x"}},
		{"run unknown flag", []string{"run", "--evil", "--", "true"}},
		{"run short flag", []string{"run", "-x", "--", "true"}},
		{"run bare dash", []string{"run", "-", "--", "true"}},
		{"run -h=", []string{"run", "-h=1", "--", "true"}},
		{"run --env-file without value", []string{"run", "--env-file"}},
		{"run value flag eats --", []string{"run", "--environment", "--", "true"}},
		{"run --version", []string{"run", "--version", "--", "true"}},
		{"run --no-masking after value flag", []string{"run", "--format", "json", "--no-masking", "--", "x"}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			p, err := parse(tt.args)
			if _, ok := errors.AsType[refusal](err); !ok {
				t.Fatalf("parse(%q) = %+v, %v; want a refusal", tt.args, p, err)
			}
		})
	}
}

func TestParseAllows(t *testing.T) {
	const self = "/run/wrappers/bin/agent-op"
	tests := []struct {
		name      string
		args      []string
		envFiles  []string
		wantArgs  []string
		wantToken bool
	}{
		{"version", []string{"--version"}, nil, []string{"--version"}, false},
		{"-v", []string{"-v"}, nil, []string{"-v"}, false},
		{"help", []string{"--help"}, nil, []string{"--help"}, false},
		{"-h", []string{"-h", "run"}, nil, []string{"-h", "run"}, false},
		{"whoami", []string{"whoami"}, nil, []string{"whoami"}, true},
		{"whoami --format", []string{"whoami", "--format", "json"}, nil, []string{"whoami", "--format", "json"}, true},
		{"vault list", []string{"vault", "list"}, nil, []string{"vault", "list"}, true},
		{
			"item list flags",
			[]string{"item", "list", "--vault", "Dev", "--format=json"},
			nil,
			[]string{"item", "list", "--vault", "Dev", "--format=json"},
			true,
		},
		{"item list stops at --", []string{"item", "list", "--", "--debug"}, nil, []string{"item", "list", "--", "--debug"}, true},
		{
			"run",
			[]string{"run", "--", "sh", "-c", "echo hi"},
			nil,
			[]string{"run", "--", self, childMarker, "--", "sh", "-c", "echo hi"},
			true,
		},
		{
			"run env files both forms",
			[]string{"run", "--env-file", "a.env", "--no-color", "--env-file=b.env", "--format", "json", "--", "x", "--", "y"},
			[]string{"a.env", "b.env"},
			[]string{
				"run", "--no-color", "--format=json", "--env-file=FD0", "--env-file=FD1",
				"--", self, childMarker, "--", "x", "--", "y",
			},
			true,
		},
		{
			"run value flag takes a value that looks like a flag",
			[]string{"run", "--environment", "--env-file=x", "--", "true"},
			nil,
			[]string{"run", "--environment=--env-file=x", "--", self, childMarker, "--", "true"},
			true,
		},
		{
			"run value flag takes --, then the real separator",
			[]string{"run", "--config", "--", "--", "true"},
			nil,
			[]string{"run", "--config=--", "--", self, childMarker, "--", "true"},
			true,
		},
		{"run --help", []string{"run", "--help"}, nil, []string{"run", "--help"}, true},
		{"run -h --", []string{"run", "-h", "--"}, nil, []string{"run", "-h"}, true},
		{
			"run help with env file",
			[]string{"run", "--env-file=a", "-h"},
			[]string{"a"},
			[]string{"run", "-h", "--env-file=FD0"},
			true,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			p, err := parse(tt.args)
			if err != nil {
				t.Fatalf("parse(%q): %v", tt.args, err)
			}
			if p.needsToken != tt.wantToken {
				t.Errorf("needsToken = %v, want %v", p.needsToken, tt.wantToken)
			}
			got := p.opArgs
			if p.run != nil {
				if !slices.Equal(p.run.envFiles, tt.envFiles) {
					t.Errorf("envFiles = %q, want %q", p.run.envFiles, tt.envFiles)
				}
				fds := make([]string, len(p.run.envFiles))
				for i := range fds {
					fds[i] = "FD" + string(rune('0'+i))
				}
				got = p.run.opArgs(fds, self)
			}
			if !slices.Equal(got, tt.wantArgs) {
				t.Errorf("op args = %q, want %q", got, tt.wantArgs)
			}
		})
	}
}

func TestCheckEnvFile(t *testing.T) {
	tests := []struct {
		content string
		ok      bool
	}{
		{"A=op://Dev/item/credential\nB=plain value\n", true},
		{"", true},
		{"LEAK=${OP_SERVICE_ACCOUNT_TOKEN}\n", false},
		{"LEAK=$OP_SERVICE_ACCOUNT_TOKEN\n", false},
		{"R=op://${OP_SERVICE_ACCOUNT_TOKEN}/y/z\n", false},
		{"R=op://$APP_ENV/db/password\n", false},
	}
	for _, tt := range tests {
		err := checkEnvFile("f.env", []byte(tt.content))
		if (err == nil) != tt.ok {
			t.Errorf("checkEnvFile(%q) = %v, want ok=%v", tt.content, err, tt.ok)
		}
	}
}

func TestOpEnv(t *testing.T) {
	env, err := opEnv([]string{
		"PATH=/bin",
		"OP_ACCOUNT=tony",
		"OP_SESSION_my=abc",
		"OP_SERVICE_ACCOUNT_TOKEN=stale",
		"OP_DEBUG=true",
		"GODEBUG=http2debug=2",
		"X=op://Dev/item/field",
	}, "tok")
	if err != nil {
		t.Fatal(err)
	}
	want := []string{
		"PATH=/bin",
		"X=op://Dev/item/field",
		"OP_SERVICE_ACCOUNT_TOKEN=tok",
		"OP_BIOMETRIC_UNLOCK_ENABLED=false",
		"OP_CACHE=false",
	}
	if !slices.Equal(env, want) {
		t.Errorf("opEnv = %q, want %q", env, want)
	}

	env, err = opEnv([]string{"OP_ACCOUNT=x", "HOME=/h"}, "")
	if err != nil {
		t.Fatal(err)
	}
	if want := []string{"HOME=/h", "OP_BIOMETRIC_UNLOCK_ENABLED=false", "OP_CACHE=false"}; !slices.Equal(env, want) {
		t.Errorf("opEnv without token = %q, want %q", env, want)
	}

	if _, err := opEnv([]string{"X=op://${OP_SERVICE_ACCOUNT_TOKEN}/a/b"}, "tok"); err == nil {
		t.Error("opEnv accepted a secret reference with '$'")
	}
}

func TestChildEnv(t *testing.T) {
	got := childEnv([]string{"A=1", "OP_SERVICE_ACCOUNT_TOKEN=tok", "OP_CACHE=false", "OP_SERVICE_ACCOUNT_TOKEN_X=y"})
	want := []string{"A=1", "OP_CACHE=false", "OP_SERVICE_ACCOUNT_TOKEN_X=y"}
	if !slices.Equal(got, want) {
		t.Errorf("childEnv = %q, want %q", got, want)
	}
}

func TestParseToken(t *testing.T) {
	tests := []struct {
		content string
		want    string
		ok      bool
	}{
		{"OP_SERVICE_ACCOUNT_TOKEN=ops_abc\n", "ops_abc", true},
		{`OP_SERVICE_ACCOUNT_TOKEN="ops_abc"`, "ops_abc", true},
		{"# comment\nOTHER=1\nOP_SERVICE_ACCOUNT_TOKEN=first\nOP_SERVICE_ACCOUNT_TOKEN=last", "last", true},
		{"OTHER=1\n", "", false},
		{"OP_SERVICE_ACCOUNT_TOKEN=\n", "", false},
		{" OP_SERVICE_ACCOUNT_TOKEN=indented\n", "", false},
	}
	for _, tt := range tests {
		got, ok := parseToken([]byte(tt.content))
		if got != tt.want || ok != tt.ok {
			t.Errorf("parseToken(%q) = %q, %v; want %q, %v", tt.content, got, ok, tt.want, tt.ok)
		}
	}
}
