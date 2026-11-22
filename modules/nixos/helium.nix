{ ... }:
let
  fleet = import ../../lib/fleet.nix;
in
{
  environment.etc."chromium/policies/managed/helium-webrtc.json".text = builtins.toJSON {
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
  };
}
