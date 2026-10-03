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
