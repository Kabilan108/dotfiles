{ pkgs }:
let
  pin = builtins.fromJSON (builtins.readFile ./chatgpt-desktop-version.json);
  inherit (pin) version;
  deb = pkgs.fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${version}_amd64.deb";
    inherit (pin) hash;
  };
  # Extract only. No ELF, ASAR, launcher, or feature patches.
  payload =
    pkgs.runCommand "chatgpt-official-payload-${version}"
      {
        nativeBuildInputs = [ pkgs.dpkg ];
      }
      ''
        mkdir -p "$out"
        dpkg-deb --extract ${deb} "$out"
      '';
  launcher = pkgs.writeShellScript "chatgpt-desktop-launch" ''
    set -euo pipefail
    # Use the normal Electron profile and the intentional ~/.codex configuration.
    unset CODEX_HOME CODEX_ELECTRON_USER_DATA_PATH
    unset XDG_CONFIG_HOME XDG_CACHE_HOME XDG_DATA_HOME
    unset CODEX_CLI_PATH NIX_LD_LIBRARY_PATH LD_LIBRARY_PATH
    unset CODEX_REMOTE_CONTROL_APP_SERVER_MODE CODEX_REMOTE_CONTROL_APP_SERVER_PROXY_SOCKET
    if [ "''${1:-}" = --check ]; then
      dependency_report=$(mktemp)
      trap 'rm -f "$dependency_report"' EXIT
      ldd /usr/lib/chatgpt/ChatGPT > "$dependency_report"
      if grep -q 'not found' "$dependency_report"; then
        cat "$dependency_report"
        exit 1
      fi
      echo 'Official app shared libraries resolved.'
      /usr/lib/chatgpt/resources/codex --version
      exit 0
    fi
    exec /usr/lib/chatgpt/ChatGPT \
      --ozone-platform=x11 "$@"
  '';
  fhs = pkgs.buildFHSEnv {
    name = "chatgpt-desktop";
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
        libdrm
        libgbm
        libGL
        libsecret
        nspr
        nss
        pango
        stdenv.cc.cc.lib
        systemd
        vulkan-loader
        wayland
        libx11
        libxcomposite
        libxdamage
        libxext
        libxfixes
        libxrandr
        libxcb
        libxkbfile
        libxkbcommon
        curl
        git
        openssh
        xdg-utils
        zlib
      ];
    multiPkgs = _: [ ];
    extraBuildCommands = ''
      ln -s ${payload}/usr/lib/chatgpt "$out/usr/lib64/chatgpt"
    '';
    runScript = launcher;
  };
in
pkgs.symlinkJoin {
  name = "chatgpt-desktop-${version}";
  paths = [ fhs ];
  postBuild = ''
    ln -s chatgpt-desktop "$out/bin/chatgpt"
    ln -s chatgpt-desktop "$out/bin/codex-desktop"
    mkdir -p "$out/share/applications" "$out/share/icons/hicolor/256x256/apps"
    cp ${payload}/usr/share/pixmaps/chatgpt.png "$out/share/icons/hicolor/256x256/apps/chatgpt.png"
    cp ${payload}/usr/share/applications/chatgpt.desktop "$out/share/applications/chatgpt.desktop"
    substituteInPlace "$out/share/applications/chatgpt.desktop" \
      --replace-fail 'Exec=chatgpt %U' "Exec=$out/bin/chatgpt-desktop %U"
  '';
  passthru = {
    inherit payload deb version;
    workspaceRuntimeLibraries = import ./chatgpt-runtime-libraries.nix { inherit pkgs; };
  };
  meta = {
    description = "Unmodified official ChatGPT desktop app in an FHS environment";
    mainProgram = "chatgpt-desktop";
    platforms = [ "x86_64-linux" ];
  };
}
