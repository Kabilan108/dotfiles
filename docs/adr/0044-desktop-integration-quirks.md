# Desktop configuration works around GLib, XDG, libadwaita and AppImage quirks, and file dialogs open in scout

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

- GLib launches `Terminal=true` entries (nvim.desktop) only through xdg-terminal-exec or a hardcoded terminal list that lacks Ghostty.
- The Downloads folder is lowercase (`~/downloads`).
- Zotero's desktop entry claims `text/plain`, which every code and markdown type inherits.
- XDG default applications need explicit MIME types; wildcards do not work.
- Under Home Manager `mimeapps.list` is read-only, so Grok Bot cannot register its own deep-link handlers.
- AppImages such as T3 Code export their bundled library path, and every Ghostty window is a child of one resident process.
- Ghostty's io_uring event waits inflate Linux I/O-pressure readings while idle.
- Libadwaita apps refuse named GTK themes, so `resource:///org/gnome/theme/gtk.css` is never registered and Home Manager's CSS import chain silently fails.
- libadwaita reads dark mode from the portal `color-scheme` setting; `gtk-application-prefer-dark-theme` only works for GTK3 and non-libadwaita GTK4.
- scout is the keyboard-first file manager. Applications reach a file chooser through xdg-desktop-portal, and GTK apps use their built-in dialog unless told to use the portal. GTK 4 and recent GTK 3 follow `GDK_DEBUG=portals`; older GTK 3 follows `GTK_USE_PORTAL=1`. niri ships its own `niri-portals.conf`.

## Decision

- `xdg.terminal-exec` defaults to Ghostty.
- `xdg.userDirs` writes `~/.config/user-dirs.dirs` so scout's `gd`, browsers and file dialogs find the lowercase downloads folder.
- The Zotero `text/plain` association is removed, and image types are listed one by one.
- Grok Bot's `x-scheme-handler/grokbot` and `x-scheme-handler/sand` are declared in Home Manager.
- The resident Ghostty service unsets `LD_LIBRARY_PATH`, `APPDIR`, `APPIMAGE` and `GSETTINGS_SCHEMA_DIR`, so shells stay clean whichever app opened the window, and Ghostty uses the epoll backend.
- The WhiteSur theme package has every gtk-4.0 gresource extracted to plain files so `file://` imports work, and dconf sets `color-scheme = prefer-dark` alongside the GTK3 setting.
- scout bookmarks skip `d` and `r`, since `gd` already follows the XDG downloads folder and `gr` is `~/repos`.
- `pkgs.scout` is installed as a portal backend next to `xdg-desktop-portal-gtk`. A user `niri-portals.conf` shadows niri's, keeps its defaults, and routes only `FileChooser` to `scout;gnome;gtk`. The session sets `GDK_DEBUG=portals` and `GTK_USE_PORTAL=1`.

## Consequences

A new app that registers URL handlers needs them declared in Home Manager. Theme packages swapped in for WhiteSur need the same gresource extraction. Changes to niri's packaged portal defaults do not reach the shadowing file automatically. If scout's portal fails, the chooser falls back to GNOME's, then GTK's.

## Where

- `home/default.nix` (`xdg.terminal-exec`, `xdg.userDirs`, `xdg.mimeApps`)
- `home/services/grok-bot.nix`
- `modules/home/ghostty.nix` (`resident.conf`, `async-backend`)
- `modules/home/gtk.nix` (`extractGtkGresources`, `dconf.settings`)
- `modules/home/scout.nix` (`bookmarks`, `xdg.configFile."xdg-desktop-portal/niri-portals.conf"`)
- `modules/nixos/desktop-wayland.nix` (`xdg.portal.extraPortals`, `environment.sessionVariables`)
