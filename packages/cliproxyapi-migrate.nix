{ cliproxyapi }:
cliproxyapi.overrideAttrs {
  pname = "cliproxyapi-migrate";
  subPackages = [ "cmd/config-migrate" ];
  postPatch = ''
    mkdir -p cmd/config-migrate
    cp ${./cliproxyapi-migrate.go} cmd/config-migrate/main.go
  '';
  postInstall = "";
  meta = cliproxyapi.meta // {
    mainProgram = "config-migrate";
  };
}
