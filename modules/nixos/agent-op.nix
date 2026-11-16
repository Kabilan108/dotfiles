# 1Password for coding agents, signed in as this host's service account.
# Agents run as kabilan, so the token is readable only by the opagent group,
# and only the setgid agent-op wrapper runs with that group. See packages/agent-op.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.security) wrapperDir;
  secret = config.age.secrets."secrets/op/agents.age";
  agent-op = pkgs.callPackage ../../packages/agent-op {
    # The real file, not the symlink in $HOME, which the user could repoint.
    tokenFile = "${config.age.secretsDir}/${secret.name}";
    opProgram = "${wrapperDir}/op";
    selfProgram = "${wrapperDir}/agent-op";
  };
in
{
  assertions = [
    {
      assertion = config.security.wrappers ? op && config.security.wrappers.op.setgid;
      message = "agent-op execs ${wrapperDir}/op, which needs programs._1password.enable: op must start setgid so the user cannot read the token from its /proc environ.";
    }
  ];

  users.groups.opagent = { };

  # OP_SERVICE_ACCOUNT_TOKEN=..., encrypted to the host key. The path is kept
  # for the deny rules that name it; reading it now fails for the user.
  age.secrets."secrets/op/agents.age" = {
    file =
      if config.networking.hostName == "sietch" then
        ../../secrets/op/sietch-agents.age
      else
        ../../secrets/op/jacurutu-agents.age;
    path = "${config.users.users.kabilan.home}/.config/op-agents/env";
    mode = "0440";
    owner = "root";
    group = "opagent";
  };

  security.wrappers.agent-op = {
    source = lib.getExe agent-op;
    owner = "root";
    group = "opagent";
    setuid = false;
    setgid = true;
  };
}
