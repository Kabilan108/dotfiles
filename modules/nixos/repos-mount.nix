{
  config,
  lib,
  pkgs,
  ...
}:
let
  user = config.users.users.kabilan;
  repos = "${user.home}/repos";
  quoted = lib.escapeShellArg repos;
in
{
  fileSystems.${repos} = {
    device = "/vault/repos";
    fsType = "none";
    options = [ "bind" ];
  };

  system.activationScripts.reposMountpoint = ''
    if [ -L ${quoted} ]; then
      rm ${quoted}
      install -d -m 0755 -o ${user.name} -g ${user.group} ${quoted}
    elif [ ! -e ${quoted} ]; then
      install -d -m 0755 -o ${user.name} -g ${user.group} ${quoted}
    elif ${pkgs.util-linux}/bin/mountpoint -q ${quoted}; then
      :
    elif [ -d ${quoted} ] && [ -n "$(ls -A ${quoted})" ]; then
      echo "warning: ${repos} is a non-empty directory, not the /vault/repos bind mount." >&2
      echo "warning: the mount will hide its contents; move them into /vault/repos and empty it." >&2
    elif [ ! -d ${quoted} ]; then
      echo "warning: ${repos} is neither a directory nor a symlink; the /vault/repos bind mount can't land." >&2
    fi
  '';
}
