{ config, ... }:
let
  gateway = "10.0.0.1";
in
{
  networking.useNetworkd = true;
  networking.firewall.enable = true;
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];

  services.tailscale = {
    enable = true;
    authKeyFile = "/var/lib/tailscale/first-boot-auth-key";
    extraUpFlags = [ "--advertise-tags=tag:credentials" ];
  };

  networking.enableIPv6 = false;

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

          ip daddr ${gateway} accept
          udp dport { 67, 68 } accept
          udp dport 53 accept
          tcp dport 53 accept

          oifname "${config.tleilax.mobergVpn.interface}" ip daddr ${config.tleilax.mobergVpn.subnet} accept

          ip daddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 } drop
        }
      '';
    };
  };
}
