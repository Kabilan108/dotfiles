# Ethernet with DHCP (reserve the Pi's address on the router; lib/fleet.nix
# initrdUnlock.lanAddress). SSH is reachable on the tailnet only, where the
# policy lets jacurutu in and keeps sietch out (docs/tailscale-policy.jsonc).
{ ... }:
let
  inherit (import ./lan.nix) gateway;
in
{
  networking.useNetworkd = true;
  networking.firewall.enable = true;
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];

  services.tailscale = {
    enable = true;
    # Read only while the node is logged out, so in practice once: a
    # single-use key for tag:credentials, placed here during the install.
    authKeyFile = "/var/lib/tailscale/first-boot-auth-key";
    extraUpFlags = [ "--advertise-tags=tag:credentials" ];
  };

  # IPv4 only, so the egress filter below has no LAN IPv6 prefix to chase.
  networking.enableIPv6 = false;

  # The Pi may reach the internet (cache.nixos.org, GitHub) and the tailnet
  # (governed by the policy), but can't open connections to other hosts on
  # the home LAN. Replies to inbound connections ride the established rule.
  networking.nftables = {
    enable = true;
    tables.egress = {
      family = "ip";
      content = ''
        chain output {
          type filter hook output priority 0; policy accept;

          oifname "lo" accept
          oifname "tailscale0" accept
          ct state established,related accept

          # Router services: DNS, DHCP, gateway.
          ip daddr ${gateway} accept
          udp dport { 67, 68 } accept
          udp dport 53 accept
          tcp dport 53 accept

          ip daddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 } drop
        }
      '';
    };
  };
}
