{
  lib,
  pkgs,
  ...
}:
let
  heliumAgentsProfile = "/vault/userdata/browser-profiles/helium/agents";
  heliumAgentsDevtoolsPort = "9222";
  heliumAppImage = {
    repo = "imputnet/helium-linux";
    pattern = "helium-*.AppImage";
    downloadPattern = "*x86_64.AppImage";
    comment = "Helium browser";
    categories = [
      "Network"
      "WebBrowser"
    ];
  };
  heliumIcon = ''
    <svg width="256" height="256" viewBox="0 0 256 256" fill="none" xmlns="http://www.w3.org/2000/svg"><rect width="256" height="256" rx="67" fill="#3450D1"/><path d="M145.966 207.813L128 221L110.034 207.813L118.198 144.891L67.4689 183.379L47 174.5L49.4993 152.438L108.391 128L49.4993 103.562L47 81.5L67.4689 72.6214L118.198 111.109L110.034 48.1871L128 35L145.966 48.1871L137.802 111.109L188.531 72.6214L209 81.5L206.501 103.562L147.609 128L206.501 152.438L209 174.5L188.531 183.379L137.802 144.891L145.966 207.813Z" fill="#FBFCFF"/></svg>
  '';
  mkHeliumIconVariant =
    background: foreground:
    lib.replaceStrings
      [
        "#3450D1"
        "#FBFCFF"
      ]
      [
        background
        foreground
      ]
      heliumIcon;
  heliumAgentsIcon = mkHeliumIconVariant "#12343b" "#e9c46a";
  heliumAgentsDevtoolsIcon = mkHeliumIconVariant "#2b1b17" "#f4a261";
in
{
  home.sessionVariables = {
    HELIUM_AGENTS_PROFILE = heliumAgentsProfile;
    HELIUM_AGENTS_CDP_PORT = heliumAgentsDevtoolsPort;
  };

  programs.appimages.apps = {
    helium = heliumAppImage // {
      desktopName = "Helium";
      icon = "helium";
      startupWMClass = "Helium";
    };
    helium-agents = heliumAppImage // {
      desktopName = "Helium Agents";
      icon = "helium-agents";
      startupWMClass = "HeliumAgents";
      executableSessionVariable = "AGENT_BROWSER_EXECUTABLE_PATH";
      preExec = ''
        mkdir -p ${lib.escapeShellArg heliumAgentsProfile}
      '';
      args = [
        "--user-data-dir=${heliumAgentsProfile}"
        "--class=HeliumAgents"
      ];
    };
    helium-agents-devtools = heliumAppImage // {
      desktopName = "Helium Agents DevTools";
      icon = "helium-agents-devtools";
      startupWMClass = "HeliumAgentsDevTools";
      preExec = ''
        profile=${lib.escapeShellArg heliumAgentsProfile}
        port=${lib.escapeShellArg heliumAgentsDevtoolsPort}

        mkdir -p "$profile"

        if { [ -e "$profile/SingletonLock" ] || [ -S "$profile/SingletonSocket" ]; } \
          && ! ${lib.getExe pkgs.curl} -fsS "http://127.0.0.1:$port/json/version" >/dev/null 2>&1; then
          ${lib.getExe pkgs.libnotify} -u critical "Helium Agents DevTools" "Close Helium Agents before launching the CDP-enabled instance."
          printf '%s\n' "helium-agents-devtools: close Helium Agents before launching the CDP-enabled instance." >&2
          exit 1
        fi
      '';
      args = [
        "--user-data-dir=${heliumAgentsProfile}"
        "--remote-debugging-address=127.0.0.1"
        "--remote-debugging-port=${heliumAgentsDevtoolsPort}"
        "--class=HeliumAgentsDevTools"
      ];
    };
  };

  xdg.dataFile = {
    "icons/hicolor/scalable/apps/helium.svg".text = heliumIcon;
    "icons/hicolor/scalable/apps/helium-agents.svg".text = heliumAgentsIcon;
    "icons/hicolor/scalable/apps/helium-agents-devtools.svg".text = heliumAgentsDevtoolsIcon;
  };
}
