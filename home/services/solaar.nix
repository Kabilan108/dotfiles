{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.solaar;
  mouseSerials = [
    "DFDC1A38"
    "C80A6735"
  ];
  python = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);
  configureMouse = pkgs.writeText "solaar-thumb-button.py" ''
    import sys
    from pathlib import Path

    import yaml

    path = Path(sys.argv[1])
    data = yaml.safe_load(path.read_text()) if path.exists() else ["1.1.20"]
    for serial in ${builtins.toJSON mouseSerials}:
        device = next(
            (entry for entry in data[1:] if entry.get("_serial") == serial),
            None,
        )
        if device is None:
            device = {
                "_serial": serial,
                "_wpid": "4069",
                "_NAME": "Wireless Mouse MX Master 2S",
            }
            data.append(device)
        # Divert the thumb button to HID++ notifications. Keep its firmware fallback
        # free of gesture navigation, which suppressed movement when the switch stuck.
        device.setdefault("divert-keys", {})[195] = 1
        device.setdefault("reprogrammable-keys", {})[195] = 196
        device.setdefault("_sensitive", {}).update({
            "divert-keys": False,
            "reprogrammable-keys": False,
        })
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(".yaml.tmp")
    temporary.write_text(yaml.safe_dump(data, sort_keys=False))
    temporary.replace(path)
  '';
  startSolaar = pkgs.writeShellApplication {
    name = "solaar-dictation";
    text = ''
      ${python}/bin/python ${configureMouse} ${lib.escapeShellArg "${config.xdg.configHome}/solaar/config.yaml"}
      exec ${lib.getExe pkgs.solaar} --window=hide
    '';
  };
in
{
  options.dotfiles.services.solaar.enable =
    lib.mkEnableOption "Solaar with MX Master 2S thumb-button dictation";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.dotfiles.services.dictator.enable;
        message = "Solaar thumb-button dictation requires Dictator to be enabled.";
      }
    ];

    xdg.configFile."solaar/rules.yaml" = {
      # Replace the local rule created while testing the physical button.
      force = true;
      text = ''
        ---
        - Or:
        ${lib.concatMapStringsSep "\n" (serial: "    - Device: ${serial}") mouseSerials}
        - Key: [Mouse Gesture Button, pressed]
        - Execute: [${lib.getExe config.services.dictator.package}, toggle]
        ...
      '';
    };

    xdg.configFile."autostart/solaar.desktop" = {
      force = true;
      text = ''
        [Desktop Entry]
        Type=Application
        Name=Solaar
        Comment=Logitech mouse settings and thumb-button dictation
        Exec=${lib.getExe startSolaar}
        Terminal=false
      '';
    };
  };
}
