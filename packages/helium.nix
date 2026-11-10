{ pkgs }:
let
  inherit (pkgs) lib;
  pin = builtins.fromJSON (builtins.readFile ./helium-version.json);
  inherit (pin) version;
  name = "helium-${version}-x86_64_linux";
  releaseUrl = "https://github.com/imputnet/helium-linux/releases/download/${version}/${name}.tar.xz";
  tarball = pkgs.fetchurl {
    url = releaseUrl;
    inherit (pin) hash;
  };
  signature = pkgs.fetchurl {
    url = "${releaseUrl}.asc";
    hash = pin.signatureHash;
  };

  # Runtime libraries, following nixpkgs' google-chrome package.
  deps = with pkgs; [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    bzip2
    cairo
    cups
    curl
    dbus
    expat
    flac
    fontconfig
    freetype
    gcc-unwrapped.lib
    gdk-pixbuf
    glib
    gtk3
    gtk4
    harfbuzz
    icu
    libcap
    libdrm
    libexif
    libglvnd
    libkrb5
    libpng
    libpulseaudio
    libva
    libx11
    libxcb
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxkbcommon
    libxrandr
    libxrender
    libxscrnsaver
    libxshmfence
    libxtst
    libgbm
    nspr
    nss
    (libopus.override { withCustomModes = true; })
    pango
    pciutils
    pipewire
    snappy
    speechd-minimal
    systemdLibs
    util-linux
    vulkan-loader
    wayland
  ];
  rpath = lib.makeLibraryPath deps + ":" + lib.makeSearchPathOutput "lib" "lib64" deps;
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "helium";
  inherit version;
  src = tarball;

  nativeBuildInputs = with pkgs; [
    gnupg
    makeWrapper
    patchelf
  ];
  buildInputs = with pkgs; [
    adwaita-icon-theme
    glib
    gtk3
    gtk4
    gsettings-desktop-schemas
  ];

  # The pinned hash fixes the bytes; the signature proves Helium published them.
  postUnpack = ''
    gpg --homedir "$TMPDIR/gnupg" --dearmor < ${./helium-signing-key.asc} > "$TMPDIR/helium.gpg"
    gpgv --keyring "$TMPDIR/helium.gpg" ${signature} ${tarball}
  '';

  installPhase = ''
    runHook preInstall

    app=$out/opt/helium
    mkdir -p $out/bin $app
    cp -a . $app

    rm $app/libvulkan.so.1
    ln -s ${lib.getLib pkgs.vulkan-loader}/lib/libvulkan.so.1 $app/libvulkan.so.1

    for elf in $app/helium $app/helium_crashpad_handler $app/chromedriver; do
      patchelf --set-interpreter ${pkgs.bintools.dynamicLinker} --set-rpath "${rpath}:$app" $elf
    done

    makeWrapper $app/helium-wrapper $out/bin/helium \
      --prefix LD_LIBRARY_PATH : "${rpath}" \
      --suffix PATH : "${lib.makeBinPath [ pkgs.xdg-utils ]}" \
      --prefix XDG_DATA_DIRS : "$XDG_ICON_DIRS:$GSETTINGS_SCHEMAS_PATH:${pkgs.addDriverRunpath.driverLink}/share"
    ln -s $app/chromedriver $out/bin/helium-chromedriver

    install -Dm644 $app/helium.desktop $out/share/applications/helium.desktop
    substituteInPlace $out/share/applications/helium.desktop \
      --replace-fail 'Exec=helium' "Exec=$out/bin/helium"
    install -Dm644 $app/product_logo_256.png $out/share/icons/hicolor/256x256/apps/helium.png

    runHook postInstall
  '';

  dontPatchELF = true;
  dontStrip = true;

  passthru = { inherit tarball signature; };

  meta = {
    description = "Helium browser, from the signed upstream Linux tarball";
    homepage = "https://github.com/imputnet/helium-linux";
    license = lib.licenses.gpl3Only;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "helium";
    platforms = [ "x86_64-linux" ];
  };
}
