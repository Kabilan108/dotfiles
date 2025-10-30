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
    url = "https://api2.cursor.sh/updates/download/golden/linux-x64/cursor/2.0";
    hash = "sha256-HD+8OytWJrWgMy8PVo2+X7b5UdL6fBQpw7XRH+lvzDA=";
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
