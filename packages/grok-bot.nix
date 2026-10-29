{ pkgs }:
let
  pin = builtins.fromJSON (builtins.readFile ./grok-bot-version.json);
  inherit (pin) version commitSha;
  deb = pkgs.fetchurl {
    url = "https://downloads.cursor.com/grokbot/stable/${commitSha}/linux/x64/grok-bot_${version}_amd64.deb";
    inherit (pin) hash;
  };
  # Extract only. dpkg maintainer scripts (apt source, AppArmor profile) are not run.
  payload =
    pkgs.runCommand "grok-bot-official-payload-${version}"
      {
        nativeBuildInputs = [ pkgs.dpkg ];
      }
      ''
        mkdir -p "$out"
        dpkg-deb --extract ${deb} "$out"
      '';
  appDir = "/usr/lib/grok-bot";
  launcher = pkgs.writeShellScript "grok-bot-launch" ''
    set -euo pipefail
    unset NIX_LD_LIBRARY_PATH LD_LIBRARY_PATH
    if [ "''${1:-}" = --check ]; then
      dependency_report=$(mktemp)
      trap 'rm -f "$dependency_report"' EXIT
      find -L ${appDir} -type f \( -name grok-bot -o -name '*.so' -o -name '*.node' \) \
        -exec sh -c 'for f; do echo "== $f"; ldd "$f" 2>&1; done' sh {} + > "$dependency_report"
      if grep -q 'not found' "$dependency_report"; then
        awk '/^== /{file=$0} /not found/{print file; print}' "$dependency_report"
        exit 1
      fi
      echo 'Official app shared libraries resolved.'
      exit 0
    fi
    exec ${appDir}/grok-bot "$@"
  '';
  fhs = pkgs.buildFHSEnv {
    name = "grok-bot";
    targetPkgs =
      p: with p; [
        alsa-lib
        at-spi2-atk
        at-spi2-core
        atk
        cairo
        cups
        dbus
        expat
        fontconfig
        freetype
        gdk-pixbuf
        glib
        gtk3
        libayatana-appindicator
        libdrm
        libgbm
        libGL
        libnotify
        libsecret
        nspr
        nss
        pango
        stdenv.cc.cc.lib
        systemd
        util-linux.lib
        vulkan-loader
        wayland
        libx11
        libxcomposite
        libxdamage
        libxext
        libxfixes
        libxrandr
        libxscrnsaver
        libxtst
        libxcb
        libxkbfile
        libxkbcommon
        xdg-utils
        zlib
      ];
    multiPkgs = _: [ ];
    extraBuildCommands = ''
      ln -s "${payload}/opt/Grok Bot" "$out/usr/lib64/grok-bot"
    '';
    runScript = launcher;
  };
in
pkgs.symlinkJoin {
  name = "grok-bot-${version}";
  paths = [ fhs ];
  postBuild = ''
    mkdir -p "$out/share/applications"
    cp -r ${payload}/usr/share/icons "$out/share/icons"
    cp ${payload}/usr/share/applications/grok-bot.desktop "$out/share/applications/grok-bot.desktop"
    substituteInPlace "$out/share/applications/grok-bot.desktop" \
      --replace-fail 'Exec=grok-bot -- %U' "Exec=$out/bin/grok-bot -- %U"
  '';
  passthru = {
    inherit payload deb version;
  };
  meta = {
    description = "Unmodified official Grok Bot desktop app in an FHS environment";
    mainProgram = "grok-bot";
    platforms = [ "x86_64-linux" ];
  };
}
