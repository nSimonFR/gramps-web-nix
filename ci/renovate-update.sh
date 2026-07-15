#!/usr/bin/env bash
# Recompute Gramps Web Nix hashes after Renovate bumps a component version.
#
# Two upstream components are tracked, each by its own Renovate customManager:
#   * gramps-project/gramps-web      → pkgs/frontend.nix       (src + npmDepsHash)
#   * gramps-project/gramps-web-api  → pkgs/gramps-web-api/default.nix (src only)
# Renovate runs this postUpgradeTask per branch, passing the depName so we know
# which component was bumped: `ci/renovate-update.sh <depName> <newVersion>`.
# Requires nurl + nix on PATH (the CI workflow installs them).
set -euo pipefail
cd "$(dirname "$0")/.."

dep="${1:-}"; ver="${2:-}"
[ -n "$dep" ] && [ -n "$ver" ] || { echo "usage: $0 <depName> <newVersion>"; exit 1; }

# Replace only the src hash in $1 (value-based, from the fetchFromGitHub block, so
# a sibling npmDepsHash line is never touched).
replace_src() {
  local f="$1" url="$2" newsrc oldsrc
  newsrc=$(nurl "$url" "v$ver" 2>/dev/null | grep -oE 'sha256-[A-Za-z0-9+/=]+' | head -1)
  [ -n "$newsrc" ] || { echo "ERROR: nurl returned no src hash for $url v$ver"; exit 1; }
  oldsrc=$(sed -n '/src = fetchFromGitHub {/,/};/p' "$f" | grep -oE 'sha256-[A-Za-z0-9+/=]+' | head -1)
  [ -n "$oldsrc" ] || { echo "ERROR: could not locate current src hash in $f"; exit 1; }
  [ "$oldsrc" = "$newsrc" ] || sed -i "s#$oldsrc#$newsrc#" "$f"
  echo ">> $f src = $newsrc"
}

# Recompute a fixed-output derivation ($1=flake attr, $2=file holding its hash).
recompute_fod() {
  local attr="$1" f="$2" out spec got
  out=$(nix build ".#$attr" --no-link 2>&1) || true
  if printf '%s\n' "$out" | grep -q 'hash mismatch'; then
    spec=$(printf '%s\n' "$out" | grep -oE 'specified:[[:space:]]+sha256-[A-Za-z0-9+/=]+' | grep -oE 'sha256-[A-Za-z0-9+/=]+' | head -1)
    got=$(printf '%s\n' "$out"  | grep -oE 'got:[[:space:]]+sha256-[A-Za-z0-9+/=]+'       | grep -oE 'sha256-[A-Za-z0-9+/=]+' | head -1)
    [ -n "$spec" ] && [ -n "$got" ] || { printf '%s\n' "$out"; echo "ERROR: $attr mismatch without spec/got"; exit 1; }
    sed -i "s#$spec#$got#g" "$f"
    echo ">> $attr = $got (updated)"
    nix build ".#$attr" --no-link >/dev/null # confirm it resolves
  elif printf '%s\n' "$out" | grep -qE '^/nix/store/'; then
    echo ">> $attr unchanged"
  else
    printf '%s\n' "$out"; echo "ERROR: $attr build failed for a reason other than a hash mismatch"; exit 1
  fi
}

case "$dep" in
  *gramps-web-api)
    echo ">> recomputing gramps-web-api v$ver (src only)"
    replace_src pkgs/gramps-web-api/default.nix "https://github.com/gramps-project/gramps-web-api"
    ;;
  *gramps-web)
    echo ">> recomputing gramps-web (frontend) v$ver (src + npmDepsHash)"
    replace_src pkgs/frontend.nix "https://github.com/gramps-project/gramps-web"
    recompute_fod gramps-web.npmDeps pkgs/frontend.nix
    ;;
  *)
    echo "ERROR: unknown depName '$dep'"; exit 1 ;;
esac

echo ">> hash recompute complete for $dep v$ver"
