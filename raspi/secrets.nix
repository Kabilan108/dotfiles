# agenix recipients for the Pi — intentionally SEPARATE from the root dotfiles secrets.nix.
# The Pi gets its own identity and its own secret files; it cannot read sietch/jacurutu secrets,
# and they cannot read its. That separation is the blast-radius boundary.
#
# PHASE 2: after first boot, grab the Pi's host key and paste it below:
#   ssh kabilan@tleilax.local 'cat /etc/ssh/ssh_host_ed25519_key.pub'
let
  # Admin editor: lets you `agenix -e` Pi secrets from jacurutu. This does NOT widen the
  # Pi's blast radius — it only lets your laptop decrypt for editing. The Pi can still only
  # read secrets it is itself listed as a recipient of.
  sietch = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDW1t7U7qDPNYEVWqnxivPK21jkOM5OFwQRmlrQh7XoE kabilan@sietch";
  jacurutu = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPN/jpn1y7lmxhrBSmApiVvA+H2YN3AFkczBJbKIGVUe kabilan@jacurutu";
  tleilax = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILrTgetUqAUt7NEK+51GGGEOgea/uME+vlOJpOdggJB2 root@tleilax";
in
{
  "secrets/wifi-env.age".publicKeys = [
    sietch
    jacurutu
    tleilax
  ];

  # Future Pi-only secrets (create with: agenix -e secrets/<name>.age):
  # "secrets/tailscale-authkey.age".publicKeys = [ admin tleilax ];
  # "secrets/model-api-keys.age".publicKeys = [ admin tleilax ];
}
