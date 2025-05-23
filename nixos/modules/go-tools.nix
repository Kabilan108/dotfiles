{ pkgs, lib }:

[
  (pkgs.buildGoModule rec {
    pname = "dump";
    version = "0.2.2";
    src = pkgs.fetchFromGitHub {
      owner = "kabilan108";
      repo = "dump";
      rev = "v${version}";
      sha256 =  "sha256-rAZofwBMgcVgH5kdwkQ1IQqCAiQTZjcv2+SaU/xPPKE=";
    };

    vendorHash = "sha256-A8PH2ITmJE8SD9KVTN76OyXZrmc/oq9JH8Vm0HFZWPw=";

    meta = with pkgs.lib; {
      description = "A CLI tool to dump stuff (replace with actual description)";
      homepage = "https://github.com/kabilan108/dump";
      license = licenses.mit;
      maintainers = [ "kabilan108" ];
    };
  })

  (pkgs.buildGoModule rec {
    pname = "diffgpt";
    version = "0.4.0";
    src = pkgs.fetchFromGitHub {
      owner = "kabilan108";
      repo = "diffgpt";
      rev = "v${version}";
      sha256 =  "sha256-ekbT5W3mB8ra4MPJlbdUQdWMEl8i7cHkwoN84P78AwY=";
    };

    vendorHash = "sha256-YMPiHe2DEA/1E8wtB1GJf/pvJ0vl3TjfquZdvDA9NDU=";

    meta = with pkgs.lib; {
      description = "write commit messages with llms";
      homepage = "https://github.com/kabilan108/diffgpt";
      license = licenses.mit;
      maintainers = [ "kabilan108" ];
    };
  })

  (pkgs.stdenv.mkDerivation rec {
    pname = "capscreen";
    version = "0.1.1";

    src = pkgs.fetchurl {
      url = "https://github.com/Kabilan108/capscreen/releases/download/v${version}/capscreen-linux-amd64.tar.gz";
      sha256 = "sha256-dsAsWE2zIcrCeYJi8RAUwiXvzGSgtbIGqsHJJSF9NgI=";
    };

    installPhase = ''
      mkdir -p $out/bin
      cp bin/capscreen $out/bin/
      chmod +x $out/bin/capscreen
    '';
  })
]
