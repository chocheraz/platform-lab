#!/usr/bin/env bash
# Funciones comunes. Se carga con: source "$(dirname "$0")/lib.sh"
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../versions.env
source "$ROOT/versions.env"
export PATH="$ROOT/.bin:$PATH"

ok()   { printf '  \033[32m✔\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
fail() { printf '  \033[31m✘\033[0m %s\n' "$*"; }
die()  { fail "$*"; exit 1; }
step() { printf '\n\033[1m▸ %s\033[0m\n' "$*"; }

# ¿La salida de un comando contiene un texto? Uso: version_matches "v1.2.3" kind version
# Sin pipe a propósito: con `pipefail`, `cmd | grep -q` falla al azar cuando grep cierra
# el pipe antes de que cmd termine de escribir (SIGPIPE). Ver M1, troubleshooting de make tools.
version_matches() {
  local want="$1"; shift
  local out
  out="$("$@" 2>/dev/null)" || return 1
  [[ "$out" == *"$want"* ]]
}
