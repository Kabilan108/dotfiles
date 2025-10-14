{
  lib,
  appimageTools,
  fetchurl,
  makeDesktopItem,
}:
let
  pname = "cursor";
  version = "1.7.17";
  src = fetchurl {
    url = "https://api2.cursor.sh/updates/download/golden/linux-x64/cursor/1.7";
    hash = "sha256-XDKDZYCagr7bEL4HzQFkhdUhPiL5MaRzZTPNrLDPZDM=";
  };

  appimageContents = appimageTools.extract { inherit pname version src; };

  desktopItem = makeDesktopItem {
    name = "cursor";
    exec = "cursor";
    icon = "cursor";
    desktopName = "Cursor";
    comment = "AI-powered code editor";
    categories = [
      "Development"
      "TextEditor"
    ];
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    mkdir -p $out/share/applications
    cp ${desktopItem}/share/applications/* $out/share/applications/

    mkdir -p $out/share/pixmaps
    cp ${appimageContents}/usr/share/icons/hicolor/512x512/apps/cursor.png \
       $out/share/pixmaps/cursor.png
  '';
}
