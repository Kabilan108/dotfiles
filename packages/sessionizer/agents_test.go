package main

import (
	"slices"
	"testing"
)

func TestUniqueAgents(t *testing.T) {
	cases := []struct {
		name  string
		panes []Pane
		want  []string
	}{
		{"no panes", nil, nil},
		{"no agents", []Pane{{Command: "bash"}, {Command: "nvim"}}, nil},
		{"one per pane", []Pane{{Agents: []string{"claude"}}, {Agents: []string{"codex"}}}, []string{"claude", "codex"}},
		{"repeats collapse", []Pane{{Agents: []string{"claude"}}, {Agents: []string{"claude"}}, {Agents: []string{"claude"}}}, []string{"claude"}},
		{
			"first appearance order",
			[]Pane{{Agents: []string{"codex"}}, {Command: "bash"}, {Agents: []string{"claude", "codex"}}, {Agents: []string{"opencode"}}},
			[]string{"codex", "claude", "opencode"},
		},
	}
	for _, c := range cases {
		if got := uniqueAgents(c.panes); !slices.Equal(got, c.want) {
			t.Errorf("%s: got %v, want %v", c.name, got, c.want)
		}
	}
}
