# sietch-vm skill draft

Not installed. `bin/sync-agent-skills` reads `agents/skills/`, not this
directory. The draft describes the Stage B launcher in
`docs/plans/agent-vm/policy.md`, which does not exist yet. Its CLI flags,
paths and caps are placeholders until the module and the choices C5 to C8
and C11 to C12 are settled. Stage A must have shipped through the
fleet-security cheap-fixes PR before the skill's libvirt row is true.

Promote it to `agents/skills/sietch-vm/` only after validation step 3 in the
policy passes on sietch. Update the numbers in "What the host enforces" from
the module at that point.
