{
  symlinkJoin,
  makeWrapper,
  nomacs,
  ...
}:

symlinkJoin {
  name = "nomacs";
  paths = [ nomacs ];
  buildInputs = [ makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/nomacs \
      --run "mkdir -p \$HOME/.config/nomacs" \
      --run "if [ ! -f \"\$HOME/.config/nomacs/Image Lounge.ini\" ]; then cp ${../config/nomacs.conf} \"\$HOME/.config/nomacs/Image Lounge.conf\"; chmod u+w \"\$HOME/.config/nomacs/Image Lounge.conf\"; fi"
  '';
}
