# shellcheck shell=bash
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
       deploy-tag [-C DIR] moves-forward TAG HOST RUNNING [OBJECT]
       deploy-tag [-C DIR] approves TAG HOST OBJECT COMMIT
       deploy-tag [-C DIR] sign --key FILE [--message TEXT] HOST... REV
       deploy-tag [-C DIR] fleet-hosts
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

valid_host() {
  [[ $1 =~ ^[a-z0-9-]+$ && $1 != fleet ]]
}

hex_of() {
  printf '%s' "$1" | od -An -v -tx1 | tr -d ' \n'
}

sk_signature_flags() {
  local hex n pos len sig_end type
  hex=$(sed '1d;$d' | base64 -d | od -An -v -tx1 | tr -d ' \n')
  n=$((${#hex} / 2))
  [[ $n -ge 10 && ${hex:0:12} == "$(hex_of SSHSIG)" ]] || return 1
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

verify() {
  local tag=$1 ref=${2:-refs/tags/$1} object name type blocks message flags
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

signed_message() {
  sed '1,/^$/d; /^-----BEGIN SSH SIGNATURE-----$/,$d'
}

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

listed_hosts() {
  g cat-file tag "refs/tags/$1" | signed_message | first_paragraph | sed -n 's/^Hosts: //p'
}

names_host() {
  local tag=$1 host=$2
  [[ $tag == deploy/fleet/* ]] || return 1
  verify "$tag" 2>/dev/null || return 1
  [[ " $(listed_hosts "$tag") " == *" $host "* ]]
}

allows_rollback() {
  local tag=$1 ref=${2:-refs/tags/$1} object message
  verify "$tag" "$ref" 2>/dev/null || return 1
  object=$(g cat-file tag "$ref")
  message=$(signed_message <<<"$object")
  awk '/^$/ { exit } $0 == "Allow-Rollback: yes" { found = 1 } END { exit !found }' <<<"$message"
}

moves_forward() {
  local tag=$1 host=$2 running=${3%-dirty} ref=${4:-refs/tags/$1} commit
  if allows_rollback "$tag" "$ref"; then
    return 0
  fi
  verify "$tag" "$ref" || return 1
  if [[ ! $running =~ ^[0-9a-f]{40}$ ]]; then
    refuse "$tag" "can't read the commit $host runs; deploying needs a tag signed with --allow-rollback"
    return 1
  fi
  commit=$(g rev-parse "$ref^{commit}")
  if ! g merge-base --is-ancestor "$running" "$commit" 2>/dev/null; then
    refuse "$tag" "$commit doesn't descend from $running, which $host runs; a rollback needs a tag signed with --allow-rollback"
    return 1
  fi
}

approves() {
  local tag=$1 host=$2 object=$3 commit=$4 now
  if [[ ! $object =~ ^[0-9a-f]{40}$ || ! $commit =~ ^[0-9a-f]{40}$ ]]; then
    refuse "$tag" "expected a tag object and a commit, got '$object' and '$commit'"
    return 1
  fi
  now=$(g rev-parse --verify --quiet "refs/tags/$tag" || true)
  if [[ $now != "$object" ]]; then
    refuse "$tag" "it now resolves to ${now:-nothing}, not $object, the tag object that was checked"
    return 1
  fi
  if [[ $tag != deploy/fleet/* ]]; then
    refuse "$tag" "only a fleet tag can approve a build"
    return 1
  fi
  verify "$tag" "$object" || return 1
  if [[ " $(g cat-file tag "$object" | signed_message | first_paragraph | sed -n 's/^Hosts: //p') " != *" $host "* ]]; then
    refuse "$tag" "its Hosts: line doesn't name $host"
    return 1
  fi
  if [[ $(g rev-parse "$object^{commit}") != "$commit" ]]; then
    refuse "$tag" "it points at $(g rev-parse "$object^{commit}"), not $commit"
    return 1
  fi
}

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
  local key=$1 tag=$2 object
  : "${DEPLOY_PUSH_URL:?DEPLOY_PUSH_URL must name the repo to push to}"
  : "${DEPLOY_PUSH_KNOWN_HOSTS:?DEPLOY_PUSH_KNOWN_HOSTS must name a known_hosts file}"
  [[ -r $key && $key != *"'"* ]] || die "can't use key file $key"
  object=$(g rev-parse --verify --quiet "refs/tags/$tag") || die "no tag $tag"
  verify "$tag" "$object" || die "won't push $tag"
  echo "Enter the PIN and touch $(basename "$key") again to push $tag." >&2
  g -c core.sshCommand="ssh -F /dev/null -i '$key' -o IdentitiesOnly=yes -o IdentityAgent=none \
-o UserKnownHostsFile='$DEPLOY_PUSH_KNOWN_HOSTS' -o StrictHostKeyChecking=yes" \
    push --quiet "$DEPLOY_PUSH_URL" "$object:refs/tags/$tag"
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
  [[ $# -eq 4 || $# -eq 5 ]] || usage
  moves_forward "$2" "$3" "$4" "${5:-refs/tags/$2}"
  ;;
fleet-hosts)
  [[ $# -eq 1 ]] || usage
  : "${DEPLOY_CONTROLLER:?}" "${DEPLOY_RECEIVERS:?}"
  echo "$DEPLOY_CONTROLLER $DEPLOY_RECEIVERS"
  ;;
approves)
  [[ $# -eq 5 ]] || usage
  approves "$2" "$3" "$4" "$5"
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
