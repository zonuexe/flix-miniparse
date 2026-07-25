#!/usr/bin/env bash
# Build this package and sibling flix-parsec; install fpkgs into bench/lib/github/...
# so Flix resolves them without a published flix-parsec 0.3.0 tag.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"          # .../flix-miniparse/bench
MINI="$(cd "$ROOT/.." && pwd)"                    # .../flix-miniparse
PARSEC="$(cd "$MINI/../flix-parsec" && pwd)"      # .../flix/flix-parsec

need_dir() {
  if [[ ! -d "$1" ]]; then
    echo "error: missing directory: $1" >&2
    exit 1
  fi
}

need_dir "$MINI"
need_dir "$PARSEC"

echo "==> build miniparse (parent)"
( cd "$MINI" && flix build-pkg )

echo "==> build flix-parsec (sibling)"
( cd "$PARSEC" && flix build-pkg )

install_pkg() {
  local src_dir="$1"
  local owner="$2"
  local name="$3"
  local version="$4"
  local dest="$ROOT/lib/github/${owner}/${name}/${version}"
  mkdir -p "$dest"
  cp "${src_dir}/artifact/${name}.fpkg" "${dest}/${name}-${version}.fpkg"
  cp "${src_dir}/artifact/flix.toml" "${dest}/${name}-${version}.toml"
  echo "installed ${owner}/${name}@${version} -> ${dest}"
}

# Package file basenames match flix build-pkg output (directory-based).
install_pkg "$MINI" "zonuexe" "flix-miniparse" "0.2.0"
install_pkg "$PARSEC" "stephentetley" "flix-parsec" "0.3.0"

echo "ok: local dependencies ready under ${ROOT}/lib"
echo "run:  cd ${ROOT} && JAVA_OPTS='-Xss8m' flix run"
