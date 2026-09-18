{
  appimageTools,
  fetchurl,
  makeDesktopItem,
}:
let
  pname = "cursor";
  version = "3.21.12";
  src = fetchurl {
    url = "https://downloads.cursor.com/production/05ddb9e824590e2c1db6bd2548dd71bf67ac9d2b/linux/x64/Cursor-3.21.12-x86_64.AppImage";
    hash = "sha256-nB7j86GHAdwJw2591yxtu6v6xr0to0CyBK34vAUYncE=";
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
