{
  config,
  inputs,
  pkgs,
  ...
}:
let
  port = 8787;
  dataDir = "/vault/userdata/hark-server";
  downloadsDir = "/vault/userdata/hark-downloads";
in
{
  imports = [ inputs.hark.nixosModules.default ];

  selfhost.tailnetServices.hark.port = port;

  age.secrets.selfhost-hark-env = {
    file = ../../../secrets/selfhost/hark-env.age;
    owner = "hark";
    group = "hark";
  };
  age.secrets.selfhost-hark-fcm-service-account = {
    file = ../../../secrets/selfhost/hark-fcm-service-account.age;
    owner = "hark";
    group = "hark";
  };
  age.secrets.hark-android-release-keystore = {
    file = ../../../secrets/hark/android-release-keystore.age;
    owner = "kabilan";
    group = "users";
  };
  age.secrets.hark-android-signing-properties = {
    file = ../../../secrets/hark/android-signing-properties.age;
    owner = "kabilan";
    group = "users";
  };

  systemd.tmpfiles.rules = [ "d ${downloadsDir} 0755 kabilan users -" ];

  environment.systemPackages = [ pkgs.sqlite ];

  services.hark = {
    enable = true;
    inherit port dataDir downloadsDir;
    requireExistingDatabase = true;
    environmentFile = config.age.secrets.selfhost-hark-env.path;
    fcmServiceAccountFile = config.age.secrets.selfhost-hark-fcm-service-account.path;
  };
}
