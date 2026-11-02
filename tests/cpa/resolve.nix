# Applied to nixosConfigurations.sietch by run.sh. Prints the store paths the
# CPA tests use as shell variables, so a checkout tests what it builds.
sys:
let
  inherit (sys) pkgs;
  inherit (pkgs) lib;
  svc = sys.config.systemd.services.cliproxyapi;
  unitText = sys.config.systemd.units."cliproxyapi.service".text;
  nginxStart = sys.config.systemd.services.nginx.serviceConfig.ExecStart;
  python = pkgs.python3.withPackages (ps: [ ps.websockets ]);
  firstWord = s: builtins.head (lib.splitString " " s);
  nginxConf = builtins.head (builtins.match ".* -c '([^']+)'.*" nginxStart);
  drvsOf = s: lib.filter (lib.hasSuffix ".drv") (builtins.attrNames (builtins.getContext s));
in
lib.toShellVars {
  cpa = firstWord (lib.head (lib.toList svc.serviceConfig.ExecStart));
  pre_start = lib.head (lib.toList svc.serviceConfig.ExecStartPre);
  panel = svc.environment.MANAGEMENT_STATIC_PATH;
  unit_path = svc.environment.PATH;
  nginx = firstWord nginxStart;
  nginx_conf = nginxConf;
  python = "${python}/bin/python3";
  yq = lib.getExe pkgs.yq-go;
  unit_text = unitText;
  front_port = toString sys.config.selfhost.tailnetServices.cliproxyapi.port;
  admin_port = toString sys.config.selfhost.tailnetServices.cpa-admin.port;
  drvs = lib.unique (
    lib.concatMap drvsOf [
      unitText
      nginxStart
      "${python}"
      "${pkgs.yq-go}"
    ]
  );
}
