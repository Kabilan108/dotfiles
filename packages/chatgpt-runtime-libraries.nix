{ pkgs }:
let
  # Retain the existing nix-ld support for bundled workspace tools.
  curlWithGnuTlsCompat =
    (pkgs.curl.override {
      gnutlsSupport = true;
      http3Support = false;
      opensslSupport = false;
    }).overrideAttrs
      (previousAttrs: {
        postPatch = (previousAttrs.postPatch or "") + ''
          substituteInPlace lib/libcurl.vers.in \
            --replace-fail \
              'CURL_@CURL_LIBCURL_VERSIONED_SYMBOLS_PREFIX@@CURL_LIBCURL_VERSIONED_SYMBOLS_SONAME@' \
              'CURL_GNUTLS_3'
        '';
      });
in
with pkgs;
[
  alsa-lib
  atk
  at-spi2-atk
  at-spi2-core
  cairo
  cups
  dbus
  expat
  gdk-pixbuf
  glib
  graphite2
  gtk3
  libdrm
  libgbm
  libglvnd
  libnotify
  libusb1
  libxkbcommon
  mesa
  nspr
  nss
  openssl
  pango
  pipewire
  systemd
  stdenv.cc.cc.lib
  tpm2-tss
  wayland
  xz
  zstd
  libx11
  libxcomposite
  libxcursor
  libxdamage
  libxext
  libxfixes
  libxi
  libxrandr
  libxscrnsaver
  libxtst
  libxcb
  libxcrypt-legacy
  zlib
  fontconfig
  freetype
  lcms2.out
  curl.out
  curlWithGnuTlsCompat.out
]
