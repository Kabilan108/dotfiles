# bin/sessionizer.py for a host without a ~/dotfiles checkout. deploy-gate
# runs it as `sessionizer --inventory` so jacurutu's picker can list the
# host's tmux sessions.
{
  lib,
  writeShellApplication,
  fd,
  python3,
  tmux,
  uv,
}:
writeShellApplication {
  name = "sessionizer";
  runtimeInputs = [
    fd
    tmux
    uv
  ];
  runtimeEnv = {
    # The script has no dependencies, so uv never needs the network.
    UV_PYTHON = lib.getExe python3;
    UV_PYTHON_DOWNLOADS = "never";
    UV_OFFLINE = "1";
  };
  text = ''
    exec uv --quiet run --script ${../bin/sessionizer.py} "$@"
  '';
}
