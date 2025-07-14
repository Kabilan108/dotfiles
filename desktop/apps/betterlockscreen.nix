{ theme, pkgs, ... }:
let
  palette = theme.palette;
in
{
  services.betterlockscreen = {
    enable = true;
    package = pkgs.betterlockscreen;
  };

  xdg.configFile."betterlockscreen/betterlockscreenrc".text = ''
    display_on=all
    span_image=false
    lock_timeout=1800  # 30 minutes
    fx_list=(dim blur dimblur pixel dimpixel color)
    dim_level=40
    blur_level=1
    pixel_scale=10,1000
    wallpaper_cmd="feh --bg-fill"
    quiet=false

    # theme
    solid_color=${palette.base00}
    loginbox=${palette.base00}99
    loginshadow=00000000
    locktext=""
    font="FiraMono Nerd Font"
    ringcolor=${palette.base0E}ff
    insidecolor=${palette.base00}99
    separatorcolor=00000000
    ringvercolor=${palette.base0B}ff
    insidevercolor=${palette.base00}99
    ringwrongcolor=${palette.base08}ff
    insidewrongcolor=${palette.base00}99
    timecolor=${palette.base05}ff
    time_format="%H:%M:%S"
    greetercolor=${palette.base05}ff
    layoutcolor=${palette.base05}ff
    keyhlcolor=${palette.base08}ff
    bshlcolor=${palette.base08}ff
    veriftext="verifying..."
    verifcolor=${palette.base05}ff
    wrongtext="failure!"
    wrongcolor=${palette.base08}ff
    modifcolor=${palette.base08}ff
    bgcolor=${palette.base00}ff

    suspend_command="systemctl suspend"
    lockargs=()
    lockargs+=(--screen 1)
    lockargs+=(--indicator)
    lockargs+=(--verif-text="authenticating...")
    lockargs+=(--wrong-text="try again")
    lockargs+=(--nofork)
  '';
}
