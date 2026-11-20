{ pkgs }:
pkgs.openssh.overrideAttrs (old: {
  pname = "openssh-sk-dummy";
  doCheck = false;
  postBuild = (old.postBuild or "") + ''
    make regress/misc/sk-dummy/sk-dummy.so
  '';
  postInstall = (old.postInstall or "") + ''
    install -D regress/misc/sk-dummy/sk-dummy.so $out/lib/sk-dummy.so
  '';
})
