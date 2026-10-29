# shellcheck shell=bash
# Find, check and create YubiKey-signed deploy tags, named
# deploy/<host>/<UTC time> (e.g. deploy/sietch/20261029T143012Z).
#
#   deploy-tag [-C DIR] latest HOST
#       Print "TAG COMMIT" for the newest valid deploy/HOST/* tag.
#   deploy-tag [-C DIR] verify TAG
#       Exit 0 if TAG is valid, else print why to stderr and exit 1.
#   deploy-tag [-C DIR] sign --key FILE [--message TEXT] HOST REV
#       Sign the next deploy/HOST tag at REV, check it, and print its name.
#
# A valid tag is an annotated tag on a commit whose embedded name matches its
# ref, with exactly one SSH signature by a key in DEPLOY_SIGNERS. With
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
       deploy-tag [-C DIR] sign --key FILE [--message TEXT] HOST REV
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
  local tag=$1 ref=refs/tags/$1 object name type blocks flags
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

latest() {
  local host=$1 ref tag
  while read -r ref; do
    tag=${ref#refs/tags/}
    if verify "$tag"; then
      printf '%s %s\n' "$tag" "$(g rev-parse "$ref^{commit}")"
      return 0
    fi
  done < <(g for-each-ref --sort=-refname --format='%(refname)' "refs/tags/deploy/$host/")
  return 1
}

sign() {
  local key=$1 message=$2 host=$3 rev=$4 commit tag
  [[ $host =~ ^[a-z0-9-]+$ ]] || die "bad host name: $host"
  [[ -r $key ]] || die "no signing key at $key"
  commit=$(g rev-parse --verify --quiet "$rev^{commit}") || die "no commit $rev"
  tag=deploy/$host/$(date -u +%Y%m%dT%H%M%SZ)
  echo "Touch the YubiKey to sign $tag (enter its PIN if asked)." >&2
  g -c gpg.format=ssh -c gpg.ssh.program="$ssh_keygen" -c user.signingKey="$key" \
    tag --sign --message "${message:-deploy $host}" "$tag" "$commit"
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

case ${1:-} in
latest)
  [[ $# -eq 2 ]] || usage
  latest "$2"
  ;;
verify)
  [[ $# -eq 2 ]] || usage
  verify "$2"
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
  [[ -n $key && $# -eq 2 ]] || usage
  sign "$key" "$message" "$1" "$2"
  ;;
*) usage ;;
esac
