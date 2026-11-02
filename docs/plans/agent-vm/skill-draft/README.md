# sietch-vm skill draft

Not installed. `bin/sync-agent-skills` reads `agents/skills/`, not this
directory. The draft covers both VM paths: raw QEMU for trusted guests,
which needs the agent account in `kvm` (Stage C), and the Stage B launcher
for risky guests, which does not exist yet. The launcher's CLI flags, paths
and caps are placeholders until the module and choices C5 to C9 and C11
are settled.

Promote it to `agents/skills/sietch-vm/` only after validation step 3 in the
policy passes on sietch. Update the numbers in "What the host enforces" from
the module at that point.
