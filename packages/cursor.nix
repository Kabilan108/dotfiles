{
  appimageTools,
  fetchurl,
  makeDesktopItem,
}:
let
  pname = "cursor";
  version = "2.2.44";
  src = fetchurl {
    url = "https://api2.cursor.sh/updates/download/golden/linux-x64/cursor/3.16";
    hash = "sha256-I7qQxcbNBDiWPyh0WUEOwVfRVT8IjtVYsErZfr+NH6U=";
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
