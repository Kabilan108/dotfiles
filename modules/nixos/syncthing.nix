{ config, lib, ... }:
let
  hostname = config.networking.hostName;
  otherHost = if hostname == "sietch" then "jacurutu" else "sietch";

  tailscaleIPs = {
    sietch = "100.71.183.33";
    jacurutu = "100.108.28.4";
    pixel = "100.126.253.59";
  };

  deviceIDs = {
    sietch = "FXOR5QA-TYXM3MA-KZ2B2N3-TDYBRDW-MIR6QTS-7PHOJ6T-WRMFKXK-3P7SUAO";
    jacurutu = "6BMQFGS-CVYNPKR-YVEJVJK-E3IRXG5-R4QE6GH-CHQIBGR-5NUPUAC-WGD33QG";
    pixel = "7JOV3CC-Z3YCMVH-25V7NT7-72I7VV4-QAWNJXY-UIR7DBW-4XOFPJU-RZUFQQN";
  };
in
{
  age.secrets.syncthing-cert = {
    file = ../../secrets/syncthing/${hostname}-cert.age;
    owner = "kabilan";
    group = "users";
  };
  age.secrets.syncthing-key = {
    file = ../../secrets/syncthing/${hostname}-key.age;
    owner = "kabilan";
    group = "users";
    mode = "0600";
  };

  services.syncthing = {
    enable = false;
    user = "kabilan";
    group = "users";
    dataDir = "/home/kabilan";
    configDir = "/home/kabilan/.config/syncthing";
    openDefaultPorts = false;
    overrideDevices = true;
    overrideFolders = true;

    cert = config.age.secrets.syncthing-cert.path;
    key = config.age.secrets.syncthing-key.path;

    guiAddress = "0.0.0.0:8384";

    settings = {
      options = {
        listenAddresses = [ "tcp://0.0.0.0:22000" ];
        globalAnnounceEnabled = false;
        localAnnounceEnabled = false;
        relaysEnabled = false;
        natEnabled = false;
        crashReportingEnabled = false;
        urAccepted = -1;
      };

      devices.${otherHost} = {
        id = deviceIDs.${otherHost};
        addresses = [ "tcp://${tailscaleIPs.${otherHost}}:22000" ];
      };
      devices.pixel = {
        id = deviceIDs.pixel;
        addresses = [ "tcp://${tailscaleIPs.pixel}:22000" ];
      };
    };
  };

  systemd.services.syncthing = lib.mkIf config.services.syncthing.enable {
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
  };
}
