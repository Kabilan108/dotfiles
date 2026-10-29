# OpenSSH plus its test-only software security key (sk-dummy.so), so the
# deploy gate tests can sign like a YubiKey without one. Signatures carry
# whatever touch and PIN flags the key file asks for.
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
