# shellcheck shell=bash

guard_chain="NIXOS-DOCKER-GUARD"
sys_class_net="${SYS_CLASS_NET:-/sys/class/net}"
iptables_bin="${IPTABLES_BIN:-iptables}"
ip6tables_bin="${IP6TABLES_BIN:-ip6tables}"

chain_exists() {
  local tool="$1"
  local chain="$2"

  "$tool" --wait -n -L "$chain" >/dev/null 2>&1
}

remove_jump() {
  local tool="$1"

  if ! chain_exists "$tool" DOCKER-USER; then
    return
  fi

  while "$tool" --wait -C DOCKER-USER -j "$guard_chain" >/dev/null 2>&1; do
    "$tool" --wait -D DOCKER-USER -j "$guard_chain"
  done
}

install_family() {
  local tool="$1"
  local interface_path
  local interface

  if ! chain_exists "$tool" DOCKER-USER; then
    echo "$tool: Docker did not create the DOCKER-USER chain" >&2
    return 1
  fi

  if ! chain_exists "$tool" "$guard_chain"; then
    "$tool" --wait -N "$guard_chain"
  fi

  "$tool" --wait -F "$guard_chain"
  "$tool" --wait -A "$guard_chain" -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
  "$tool" --wait -A "$guard_chain" -i lo -j RETURN
  "$tool" --wait -A "$guard_chain" -i tailscale0 -j RETURN
  "$tool" --wait -A "$guard_chain" -i docker0 -j RETURN
  "$tool" --wait -A "$guard_chain" -i 'br+' -j RETURN

  shopt -s nullglob
  for interface_path in "$sys_class_net"/*; do
    if [[ ! -e "$interface_path/device" ]]; then
      continue
    fi

    interface="${interface_path##*/}"
    "$tool" --wait -A "$guard_chain" -i "$interface" \
      -m conntrack --ctstate NEW -j DROP
  done

  "$tool" --wait -A "$guard_chain" -j RETURN
  remove_jump "$tool"
  "$tool" --wait -I DOCKER-USER 1 -j "$guard_chain"
}

remove_family() {
  local tool="$1"

  remove_jump "$tool"
  if chain_exists "$tool" "$guard_chain"; then
    "$tool" --wait -F "$guard_chain"
    "$tool" --wait -X "$guard_chain"
  fi
}

case "${1:-}" in
  install)
    install_family "$iptables_bin"
    install_family "$ip6tables_bin"
    ;;
  remove)
    remove_family "$iptables_bin"
    remove_family "$ip6tables_bin"
    ;;
  *)
    echo "usage: docker-user-firewall install|remove" >&2
    exit 2
    ;;
esac
