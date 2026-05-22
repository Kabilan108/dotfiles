{ config, ... }:
let
  colors = config.lib.stylix.colors.withHashtag;
in
{
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
    solid_color=${colors.base00}
    loginbox=${colors.base00}99
    loginshadow=00000000
    locktext=""
    font="FiraMono Nerd Font"
    ringcolor=${colors.base0E}ff
    insidecolor=${colors.base00}99
    separatorcolor=00000000
    ringvercolor=${colors.base0B}ff
    insidevercolor=${colors.base00}99
    ringwrongcolor=${colors.base08}ff
    insidewrongcolor=${colors.base00}99
    timecolor=${colors.base05}ff
    time_format="%H:%M:%S"
    greetercolor=${colors.base05}ff
    layoutcolor=${colors.base05}ff
    keyhlcolor=${colors.base08}ff
    bshlcolor=${colors.base08}ff
    veriftext="verifying..."
    verifcolor=${colors.base05}ff
    wrongtext="failure!"
    wrongcolor=${colors.base08}ff
    modifcolor=${colors.base08}ff
    bgcolor=${colors.base00}ff

    suspend_command="systemctl suspend"
    lockargs=()
    lockargs+=(--screen 1)
    lockargs+=(--indicator)
    lockargs+=(--verif-text="authenticating...")
    lockargs+=(--wrong-text="try again")
    lockargs+=(--nofork)
  '';
}
