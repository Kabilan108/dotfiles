_final: prev: {
  teamviewer =
    if prev.lib.versionAtLeast prev.teamviewer.version "15.83" then
      throw "Remove the obsolete security override for teamviewer"
    else
      prev.teamviewer.overrideAttrs {
        version = "15.83.3";
        src = prev.fetchurl {
          url = "https://dl.teamviewer.com/download/linux/version_15x/teamviewer_15.83.3_amd64.deb";
          hash = "sha256-8xMNJO2+JZ71ukalQ8bVqCOuoqFPUzg08uSEv9ymiQk=";
        };
      };
}
