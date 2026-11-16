# shellcheck shell=bash
# Find, check and create YubiKey-signed deploy tags. A fleet tag,
# deploy/fleet/<UTC time> (e.g. deploy/fleet/20261115T143012Z), approves its
# commit for the hosts on the "Hosts:" line of its signed message's first
# paragraph. Older tags are named deploy/<host>/<UTC time> and approve one host;
# nothing signs those any more, and receivers ignore them.
#
#   deploy-tag [-C DIR] latest HOST
#       Print "TAG COMMIT" for the newest valid tag approving HOST: a fleet tag
#       naming it, or one of its old deploy/HOST/* tags. Only for showing what
#       changed since; it approves nothing.
#   deploy-tag [-C DIR] verify TAG
#       Exit 0 if TAG is valid, else print why to stderr and exit 1.
#   deploy-tag [-C DIR] names-host TAG HOST
#       Exit 0 if TAG is a valid fleet tag whose "Hosts:" line names HOST.
#   deploy-tag [-C DIR] allows-rollback TAG
#       Exit 0 if TAG is valid and its signed message's first paragraph has
#       the line "Allow-Rollback: yes".
#   deploy-tag [-C DIR] moves-forward TAG HOST RUNNING
#       The rule for switching HOST, which runs commit RUNNING (a trailing
#       -dirty is dropped), to TAG's commit. Exit 0 if TAG is valid and allows
#       a rollback, or if its commit descends from RUNNING. An unreadable
#       RUNNING needs the rollback. Else print why and exit 1.
#   deploy-tag [-C DIR] sign --key FILE [--message TEXT] HOST... REV
#       Sign the next fleet tag at REV for the HOSTs with FILE, never an
#       ssh-agent, check it, and print its name. The "Hosts:" line goes at the
#       end of TEXT's first paragraph.
#   deploy-tag [-C DIR] push --key FILE TAG
#       Check TAG and push it to DEPLOY_PUSH_URL, authenticating with FILE.
#       GitHub's tag ruleset lets only the repo's deploy keys create deploy/*
#       tags, and the signer keys are those deploy keys, so an agent pushing
#       as the account can't create one. Pushing takes the PIN and a touch
#       again.
#
# A valid tag is an annotated tag on a commit whose embedded name matches its
# ref, with exactly one SSH signature by a key in DEPLOY_SIGNERS and nothing
# after that signature, since git and ssh-keygen don't cover it. Its signed
# message has no carriage return and no line of only whitespace, so the one
# paragraph break is an empty line. A fleet tag's first paragraph has exactly
# one "Hosts:" line, naming hosts other than "fleet". With
# DEPLOY_REQUIRE_TOUCH=1 (and DEPLOY_REQUIRE_PIN=1) the signature must come
# from a security key and carry the touch (and PIN) flag. ssh-keygen and git
# verify-tag don't check those flags.
set -euo pipefail
export LC_ALL=C

: "${DEPLOY_SIGNERS:?DEPLOY_SIGNERS must name an allowed-signers file}"
if [[ ! ${DEPLOY_REQUIRE_TOUCH:-} =~ ^[01]$ || ! ${DEPLOY_REQUIRE_PIN:-} =~ ^[01]$ ]]; then
  echo "deploy-tag: DEPLOY_REQUIRE_TOUCH and DEPLOY_REQUIRE_PIN must each be 0 or 1" >&2
  exit 2
fi

ssh_keygen=$(command -v ssh-keygen)
repo=.

usage() {
  cat >&2 <<'EOF'
usage: deploy-tag [-C DIR] latest HOST
       deploy-tag [-C DIR] verify TAG
       deploy-tag [-C DIR] names-host TAG HOST
       deploy-tag [-C DIR] allows-rollback TAG
       deploy-tag [-C DIR] moves-forward TAG HOST RUNNING
       deploy-tag [-C DIR] sign --key FILE [--message TEXT] HOST... REV
       deploy-tag [-C DIR] push --key FILE TAG
EOF
  exit 2
}

die() {
  echo "deploy-tag: $*" >&2
  exit 1
}

refuse() {
  echo "deploy-tag: refusing $1: $2" >&2
}

g() {
  git -C "$repo" "$@"
}

# A host name a tag can carry. "fleet" is the fleet tags' own namespace.
valid_host() {
  [[ $1 =~ ^[a-z0-9-]+$ && $1 != fleet ]]
}

hex_of() {
  printf '%s' "$1" | od -An -v -tx1 | tr -d ' \n'
}

# Print the flags byte of the security-key signature in the armored SSH
# signature on stdin. Fail for any other key type. Layout from OpenSSH's
# PROTOCOL.sshsig and PROTOCOL.u2f.
sk_signature_flags() {
  local hex n pos len sig_end type
  hex=$(sed '1d;$d' | base64 -d | od -An -v -tx1 | tr -d ' \n')
  n=$((${#hex} / 2))
  [[ $n -ge 10 && ${hex:0:12} == "$(hex_of SSHSIG)" ]] || return 1
  # Skip the version, then publickey, namespace, reserved and hash_algorithm.
  pos=10
  for _ in 1 2 3 4; do
    ((pos + 4 <= n)) || return 1
    pos=$((pos + 4 + 16#${hex:pos*2:8}))
  done
  ((pos + 4 <= n)) || return 1
  sig_end=$((pos + 4 + 16#${hex:pos*2:8}))
  ((sig_end <= n)) || return 1
  pos=$((pos + 4))
  ((pos + 4 <= sig_end)) || return 1
  len=$((16#${hex:pos*2:8}))
  ((pos + 4 + len <= sig_end)) || return 1
  type=${hex:(pos+4)*2:len*2}
  case $type in
  "$(hex_of sk-ssh-ed25519@openssh.com)" | "$(hex_of sk-ecdsa-sha2-nistp256@openssh.com)" | "$(hex_of webauthn-sk-ecdsa-sha2-nistp256@openssh.com)") ;;
  *) return 1 ;;
  esac
  pos=$((pos + 4 + len))
  ((pos + 4 <= sig_end)) || return 1
  pos=$((pos + 4 + 16#${hex:pos*2:8}))
  ((pos + 1 <= sig_end)) || return 1
  echo $((16#${hex:pos*2:2}))
}

# Each check returns explicitly: callers use `if verify`, which turns off
# errexit inside the function.
verify() {
  local tag=$1 ref=refs/tags/$1 object name type blocks message flags
  if [[ ! $tag =~ ^deploy/[a-z0-9-]+/[0-9]{8}T[0-9]{6}Z$ ]]; then
    refuse "$tag" "not a deploy/<host>/<YYYYMMDDTHHMMSSZ> name"
    return 1
  fi
  if [[ $(g cat-file -t "$ref" 2>/dev/null) != tag ]]; then
    refuse "$tag" "not an annotated tag"
    return 1
  fi
  object=$(g cat-file tag "$ref")
  name=$(sed -n '/^$/q; s/^tag //p' <<<"$object")
  type=$(sed -n '/^$/q; s/^type //p' <<<"$object")
  if [[ $name != "$tag" ]]; then
    refuse "$tag" "the signed tag object is named '$name'"
    return 1
  fi
  if [[ $type != commit ]]; then
    refuse "$tag" "it points at a $type, not a commit"
    return 1
  fi
  # git verifies the last signature block; allow only one so it's this one.
  blocks=$(grep -c -e '^-----BEGIN PGP SIGNATURE-----' -e '^-----BEGIN PGP MESSAGE-----' \
    -e '^-----BEGIN SIGNED MESSAGE-----' -e '^-----BEGIN SSH SIGNATURE-----' <<<"$object" || true)
  if [[ $blocks != 1 ]] || ! grep -qx -e '-----BEGIN SSH SIGNATURE-----' <<<"$object"; then
    refuse "$tag" "it needs exactly one SSH signature"
    return 1
  fi
  if [[ $(grep -cx -e '-----END SSH SIGNATURE-----' <<<"$object" || true) != 1 ]] ||
    [[ -n $(sed '1,/^-----END SSH SIGNATURE-----$/d' <<<"$object" | tr -d '[:space:]') ]]; then
    refuse "$tag" "it has content after its signature, which the signature doesn't cover"
    return 1
  fi
  # A non-empty line needs a printable ASCII character, which rules out
  # spaces, tabs and Unicode spaces alike.
  message=$(signed_message <<<"$object")
  if [[ $message == *$'\r'* ]] || grep -qvx -e '' -e '.*[!-~].*' <<<"$message"; then
    refuse "$tag" "its message has a carriage return or a line of only whitespace"
    return 1
  fi
  if [[ $tag == deploy/fleet/* ]] && ! hosts_line_ok "$message"; then
    refuse "$tag" "its message needs one 'Hosts: <host>...' line in its first paragraph"
    return 1
  fi
  if ! g -c gpg.ssh.program="$ssh_keygen" -c gpg.ssh.allowedSignersFile="$DEPLOY_SIGNERS" \
    -c gpg.minTrustLevel=fully verify-tag "$ref" >/dev/null 2>&1; then
    refuse "$tag" "not signed by an allowed key"
    return 1
  fi
  if ((DEPLOY_REQUIRE_TOUCH || DEPLOY_REQUIRE_PIN)); then
    if ! flags=$(sed -n '/^-----BEGIN SSH SIGNATURE-----$/,/^-----END SSH SIGNATURE-----$/p' <<<"$object" |
      sk_signature_flags); then
      refuse "$tag" "not signed by a security key"
      return 1
    fi
    if ((DEPLOY_REQUIRE_TOUCH && !(flags & 0x01))); then
      refuse "$tag" "signed without a touch"
      return 1
    fi
    if ((DEPLOY_REQUIRE_PIN && !(flags & 0x04))); then
      refuse "$tag" "signed without the PIN"
      return 1
    fi
  fi
  return 0
}

# The signed message of a tag object on stdin: after the headers, before the
# signature.
signed_message() {
  sed '1,/^$/d; /^-----BEGIN SSH SIGNATURE-----$/,$d'
}

# The first paragraph of a message on stdin. verify allows no blank line
# other than an empty one, so the first empty line ends it.
first_paragraph() {
  awk '/^$/ { exit } { print }'
}

hosts_line_ok() {
  local lines names host
  lines=$(first_paragraph <<<"$1" | grep '^Hosts:' || true)
  [[ $lines =~ ^Hosts:( [a-z0-9-]+)+$ ]] || return 1
  read -ra names <<<"${lines#Hosts: }"
  for host in "${names[@]}"; do
    valid_host "$host" || return 1
  done
}

# The hosts on a fleet tag's "Hosts:" line, without checking the tag.
listed_hosts() {
  g cat-file tag "refs/tags/$1" | signed_message | first_paragraph | sed -n 's/^Hosts: //p'
}

names_host() {
  local tag=$1 host=$2
  [[ $tag == deploy/fleet/* ]] || return 1
  verify "$tag" 2>/dev/null || return 1
  [[ " $(listed_hosts "$tag") " == *" $host "* ]]
}

# The override counts only inside the first paragraph of the signed message,
# which ends at the first empty line (verify allows no other kind of blank
# line). `deploy` writes it there, and the commit list it adds after that can't
# produce the line.
allows_rollback() {
  local tag=$1 object message
  verify "$tag" 2>/dev/null || return 1
  object=$(g cat-file tag "refs/tags/$tag")
  message=$(signed_message <<<"$object")
  awk '/^$/ { exit } $0 == "Allow-Rollback: yes" { found = 1 } END { exit !found }' <<<"$message"
}

moves_forward() {
  local tag=$1 host=$2 running=${3%-dirty} commit
  if allows_rollback "$tag"; then
    return 0
  fi
  verify "$tag" || return 1
  if [[ ! $running =~ ^[0-9a-f]{40}$ ]]; then
    refuse "$tag" "can't read the commit $host runs; deploying needs a tag signed with --allow-rollback"
    return 1
  fi
  commit=$(g rev-parse "refs/tags/$tag^{commit}")
  if ! g merge-base --is-ancestor "$running" "$commit" 2>/dev/null; then
    refuse "$tag" "$commit doesn't descend from $running, which $host runs; a rollback needs a tag signed with --allow-rollback"
    return 1
  fi
}

# Fleet tags and HOST's old tags together, newest UTC time first.
latest() {
  local host=$1 ref tag
  valid_host "$host" || die "bad host name: $host"
  while read -r ref; do
    tag=${ref#refs/tags/}
    verify "$tag" || continue
    if [[ $tag == deploy/fleet/* && " $(listed_hosts "$tag") " != *" $host "* ]]; then
      continue
    fi
    printf '%s %s\n' "$tag" "$(g rev-parse "$ref^{commit}")"
    return 0
  done < <(g for-each-ref --format='%(refname)' refs/tags/deploy/fleet/ "refs/tags/deploy/$host/" |
    awk -F/ '{ print $NF, $0 }' | sort -r | cut -d' ' -f2-)
  return 1
}

sign() {
  local key=$1 text=$2 rev=${*: -1} hosts=("${@:3:$#-3}") host commit para message rest tag
  for host in "${hosts[@]}"; do
    valid_host "$host" || die "bad host name: $host"
  done
  if [[ $(printf '%s\n' "${hosts[@]}" | sort | uniq -d) ]]; then
    die "a host is named twice: ${hosts[*]}"
  fi
  [[ -r $key ]] || die "no signing key at $key"
  commit=$(g rev-parse --verify --quiet "$rev^{commit}") || die "no commit $rev"
  text=${text:-deploy ${hosts[*]}}
  para=$(first_paragraph <<<"$text")
  if [[ $'\n'$para == *$'\nHosts:'* ]]; then
    die "the message already has a Hosts: line"
  fi
  message=$para$'\n'"Hosts: ${hosts[*]}"
  rest=$(awk 'found { print } /^$/ { found = 1 }' <<<"$text")
  if [[ -n $rest ]]; then
    message+=$'\n\n'$rest
  fi
  tag=deploy/fleet/$(date -u +%Y%m%dT%H%M%SZ)
  echo "Enter the YubiKey PIN when asked, then touch the key to sign $tag for ${hosts[*]}." >&2
  # ssh-keygen signs through any agent that lists the key, and an agent
  # (GNOME Keyring's lists every ~/.ssh/*.pub) can't ask for the PIN. Without
  # one, ssh-keygen loads the handle file and asks on the terminal.
  (
    unset SSH_AUTH_SOCK
    g -c gpg.format=ssh -c gpg.ssh.program="$ssh_keygen" -c user.signingKey="$key" \
      tag --sign --message "$message" "$tag" "$commit"
  )
  if ! verify "$tag"; then
    g tag --delete "$tag" >/dev/null
    die "$tag failed its own check and was deleted"
  fi
  echo "$tag"
}

if [[ ${1:-} == -C ]]; then
  [[ $# -ge 2 ]] || usage
  repo=$2
  shift 2
fi

push() {
  local key=$1 tag=$2
  : "${DEPLOY_PUSH_URL:?DEPLOY_PUSH_URL must name the repo to push to}"
  : "${DEPLOY_PUSH_KNOWN_HOSTS:?DEPLOY_PUSH_KNOWN_HOSTS must name a known_hosts file}"
  [[ -r $key && $key != *"'"* ]] || die "can't use key file $key"
  verify "$tag" || die "won't push $tag"
  echo "Enter the PIN and touch $(basename "$key") again to push $tag." >&2
  # Only this key, never the account key from ~/.ssh/config or the agent:
  # GitHub would accept that key, then refuse the tag.
  g -c core.sshCommand="ssh -F /dev/null -i '$key' -o IdentitiesOnly=yes -o IdentityAgent=none \
-o UserKnownHostsFile='$DEPLOY_PUSH_KNOWN_HOSTS' -o StrictHostKeyChecking=yes" \
    push --quiet "$DEPLOY_PUSH_URL" "refs/tags/$tag"
}

case ${1:-} in
latest)
  [[ $# -eq 2 ]] || usage
  latest "$2"
  ;;
verify)
  [[ $# -eq 2 ]] || usage
  verify "$2"
  ;;
names-host)
  [[ $# -eq 3 ]] || usage
  names_host "$2" "$3"
  ;;
allows-rollback)
  [[ $# -eq 2 ]] || usage
  allows_rollback "$2"
  ;;
moves-forward)
  [[ $# -eq 4 ]] || usage
  moves_forward "$2" "$3" "$4"
  ;;
sign)
  shift
  key="" message=""
  while [[ $# -gt 0 ]]; do
    case $1 in
    --key)
      key=${2:?--key needs a file}
      shift 2
      ;;
    --message)
      message=${2?--message needs text}
      shift 2
      ;;
    *) break ;;
    esac
  done
  [[ -n $key && $# -ge 2 ]] || usage
  sign "$key" "$message" "$@"
  ;;
push)
  [[ $# -eq 4 && $2 == --key && -n $3 ]] || usage
  push "$3" "$4"
  ;;
*) usage ;;
esac
