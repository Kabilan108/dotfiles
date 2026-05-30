{ ... }:
let
  # Xfinity default gateway. If you ever change the LAN subnet, update this.
  gateway = "10.0.0.1";
in
{
  # Shrink attack surface and make IPv4 egress filtering authoritative — no dynamic
  # IPv6 LAN prefix to chase. The agent box has no need for IPv6: model APIs, the Nix
  # binary cache, and Tailscale all work fine over IPv4.
  networking.enableIPv6 = false;

  networking.nftables = {
    enable = true;

    # Egress containment. The agent may reach the public internet (model APIs) and the
    # tailnet (already gated by Tailscale ACLs), but cannot INITIATE connections to other
    # hosts on the home LAN. Inbound admin (e.g. SSH from jacurutu) is unaffected — its
    # replies ride the established/related accept.
    tables.egress = {
      family = "ip";
      content = ''
        chain output {
          type filter hook output priority 0; policy accept;

          oifname "lo" accept
          oifname "tailscale0" accept
          ct state established,related accept

          # Router services: DNS / DHCP / gateway.
          ip daddr ${gateway} accept
          udp dport { 67, 68 } accept
          udp dport 53 accept
          tcp dport 53 accept

          # Block lateral movement: no new connections to private LAN ranges.
          ip daddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 } drop

          # Everything else (public internet) is allowed by the chain policy.
        }
      '';
    };
  };
}
