{ config, lib, ... }:
let
  cfg = config.tleilax.mobergVpn;
  profile = ../../secrets/moberg/tleilax-openvpn.ovpn.age;
in
{
  options.tleilax.mobergVpn = {
    interface = lib.mkOption {
      type = lib.types.str;
      default = "tun-moberg";
      readOnly = true;
      description = "Tunnel interface. The egress filters let traffic to the office subnet out only through it.";
    };

    subnet = lib.mkOption {
      type = lib.types.str;
      default = "10.1.10.0/24";
      readOnly = true;
      description = "Office subnet routed through the tunnel (the route below spells it as a netmask).";
    };
  };

  config = {
    assertions = [
      {
        assertion = builtins.pathExists profile;
        message = "Encrypt the Moberg VPN profile to secrets/moberg/tleilax-openvpn.ovpn.age on jacurutu first.";
      }
    ];

    tleilax.executor.officeServices = [
      "https://pipelines.office.bedsideinfo.org"
    ];

    age.secrets.moberg-openvpn = {
      file = profile;
      mode = "0400";
    };

    services.openvpn.servers.moberg = {
      autoStart = true;
      updateResolvConf = false;
      config = ''
        config ${config.age.secrets.moberg-openvpn.path}
        dev ${cfg.interface}
        dev-type tun
        route-nopull
        route 10.1.10.0 255.255.255.0
      '';
    };
  };
}
