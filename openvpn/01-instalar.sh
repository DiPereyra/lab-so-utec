#!/usr/bin/env bash
# PASO 1 — Instalar paquetes en el bastión (Fedora).
#   openvpn  : el servidor (y cliente) VPN
#   easy-rsa : herramienta para administrar una autoridad certificante (CA)
#   nftables : firewall del kernel; lo usamos para hacer NAT de los clientes
set -euo pipefail

if ! grep -qi fedora /etc/os-release; then
  echo "Este script está pensado para el bastión Fedora." >&2
  exit 1
fi

sudo dnf install -y openvpn easy-rsa nftables

echo
openvpn --version | head -n1
ls -d /usr/share/easy-rsa/3* >/dev/null && echo "easy-rsa instalado en /usr/share/easy-rsa/"
echo "Siguiente paso: ./02-crear-pki.sh"
