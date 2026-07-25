#!/usr/bin/env bash
# Guard: published fpkg must ship library sources only (no Main / Examples demos).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FPKG="${1:-$ROOT/artifact/flix-miniparse.fpkg}"

if [[ ! -f "$FPKG" ]]; then
  echo "error: missing package file: $FPKG" >&2
  echo "hint: run \`flix build-pkg\` first" >&2
  exit 1
fi

ENTRIES="$(unzip -Z1 "$FPKG" | sort)"
echo "fpkg entries:"
echo "$ENTRIES" | sed 's/^/  /'

fail=0

if echo "$ENTRIES" | grep -E '(^|/)Main\.flix$' >/dev/null; then
  echo "error: fpkg must not contain Main.flix" >&2
  fail=1
fi

if echo "$ENTRIES" | grep -E '(^|/)Examples(/|$)' >/dev/null; then
  echo "error: fpkg must not contain Examples" >&2
  fail=1
fi

require() {
  local needle="$1"
  if ! echo "$ENTRIES" | grep -Fx "$needle" >/dev/null; then
    echo "error: fpkg missing required path: $needle" >&2
    fail=1
  fi
}

require "flix.toml"
require "README.md"
require "LICENSE.md"
require "src/MiniParse.flix"
require "src/MiniParse/Core.flix"
require "src/MiniParse/Combinator.flix"
require "src/MiniParse/Parsec.flix"
require "src/MiniParse/PEG.flix"
require "src/MiniParse/Stream.flix"
require "src/MiniParse/Suspend.flix"
require "src/MiniParse/ErrorFormat.flix"
require "src/MiniParse/Bridge.flix"

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi

echo "ok: fpkg is library-only (MiniParse.*) and includes required metadata"
