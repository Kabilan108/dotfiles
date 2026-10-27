{
  pkgs,
  inputs,
  ...
}:
{
  imports = [ inputs.zen-browser.homeModules.beta ];

  programs.zen-browser = {
    enable = true;
    policies = {
      Preferences = {
        "extensions.openPopupWithoutUserGesture.enabled" = {
          Value = true;
          Status = "locked";
        };
        # File dialogs through the portal, so they open in scout.
        "widget.use-xdg-desktop-portal.file-picker" = {
          Value = 1;
          Status = "default";
        };
      };
    };
    policies = {
      AutofillAddressEnabled = true;
      AutofillCreditCardEnabled = false;
      DisableAppUpdate = true;
      DisableFeedbackCommands = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisableTelemetry = true;
      DontCheckDefaultBrowser = true;
      NoDefaultBookmarks = true;
      OfferToSaveLogins = false;
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
      };
    };
    profiles."default".extensions.packages =
      with inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system}; [
        bitwarden
 	      raindropio
        react-devtools
        web-clipper-obsidian
        ublock-origin
      ];
  };

  home.file.".config/zen/default/zen-keyboard-shortcuts.json".source = ./keyboard-shortcuts.json;
}
