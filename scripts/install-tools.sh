#!/usr/bin/env bash
# Instala kind, kubectl y helm en ./.bin con versión fijada y checksum verificado.
# No toca el sistema: todo queda dentro del repo.
source "$(dirname "$0")/lib.sh"

BIN="$ROOT/.bin"; mkdir -p "$BIN"
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$OS" in linux|darwin) ;; *) die "SO no soportado: $OS (usa Linux, macOS o WSL2)";; esac
case "$(uname -m)" in
  x86_64|amd64)  ARCH=amd64 ;;
  arm64|aarch64) ARCH=arm64 ;;
  *) die "Arquitectura no soportada: $(uname -m)" ;;
esac
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

sha256() { if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi | awk '{print $1}'; }
verify() { # archivo hash_esperado
  local got; got="$(sha256 "$1")"
  [[ "$got" == "$2" ]] || die "checksum inválido para $(basename "$1"): esperado $2, obtenido $got"
}

step "kind $KIND_VERSION ($OS/$ARCH)"
if "$BIN/kind" version 2>/dev/null | grep -q "$KIND_VERSION"; then ok "ya instalado"; else
  base="https://github.com/kubernetes-sigs/kind/releases/download/$KIND_VERSION/kind-$OS-$ARCH"
  curl -fsSLo "$TMP/kind" "$base"
  verify "$TMP/kind" "$(curl -fsSL "$base.sha256sum" | awk '{print $1}')"
  install -m 0755 "$TMP/kind" "$BIN/kind"; ok "instalado y verificado"
fi

step "kubectl $KUBECTL_VERSION"
if "$BIN/kubectl" version --client 2>/dev/null | grep -q "$KUBECTL_VERSION"; then ok "ya instalado"; else
  base="https://dl.k8s.io/release/$KUBECTL_VERSION/bin/$OS/$ARCH/kubectl"
  curl -fsSLo "$TMP/kubectl" "$base"
  verify "$TMP/kubectl" "$(curl -fsSL "$base.sha256")"
  install -m 0755 "$TMP/kubectl" "$BIN/kubectl"; ok "instalado y verificado"
fi

step "helm $HELM_VERSION"
if "$BIN/helm" version --short 2>/dev/null | grep -q "$HELM_VERSION"; then ok "ya instalado"; else
  f="helm-$HELM_VERSION-$OS-$ARCH.tar.gz"
  curl -fsSLo "$TMP/$f" "https://get.helm.sh/$f"
  verify "$TMP/$f" "$(curl -fsSL "https://get.helm.sh/$f.sha256sum" | awk '{print $1}')"
  tar -xzf "$TMP/$f" -C "$TMP"
  install -m 0755 "$TMP/$OS-$ARCH/helm" "$BIN/helm"; ok "instalado y verificado"
fi

echo; ok "Herramientas listas en $BIN (el Makefile ya las pone primero en el PATH)"
