{ lib, ... }:
let
  fleet = import ../../lib/fleet.nix;
  kvmOrigins = lib.mapAttrsToList (name: _: "http://${name}.${fleet.tailnet}") (
    lib.filterAttrs (_: device: device.role == "kvm") fleet.devices
  );
in
{
  environment.etc."chromium/policies/managed/helium.json".text = builtins.toJSON {
    WebRtcIPHandlingUrl = [
      {
        url = "http://[*.]${fleet.tailnet}";
        handling = "default";
      }
      {
        url = "https://[*.]${fleet.tailnet}";
        handling = "default";
      }
    ];
    OverrideSecurityRestrictionsOnInsecureOrigin = kvmOrigins;
  };
}
