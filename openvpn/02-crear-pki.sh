#!/usr/bin/env bash
# PASO 2 — Crear la PKI: la autoridad certificante (CA) y el certificado del
# servidor.
#
# Idea central: servidor y clientes NO comparten una contraseña. Cada uno
# tiene un par de claves y un CERTIFICADO firmado por la CA. Al conectarse,
# cada extremo verifica que el certificado del otro lo haya firmado la CA.
#
#   ca.crt         certificado público de la CA     -> lo tienen todos
#   ca.key         clave privada de la CA           -> SOLO quien emite certificados
#   servidor.crt   certificado del servidor         -> servidor
#   servidor.key   clave privada del servidor       -> solo el servidor
#   ta.key         clave compartida tls-crypt       -> servidor y clientes
#                  (cifra el propio handshake TLS: el servidor descarta sin
#                   responder cualquier paquete que no la use)
#
# En producción la CA vive en una máquina aislada, no en el servidor VPN.
# En el laboratorio la dejamos en el bastión por simplicidad.
set -euo pipefail
source "$(dirname "$0")/config.sh"

if [[ -d "$DIR_EASYRSA/pki" ]]; then
  echo "Ya existe $DIR_EASYRSA/pki. Para empezar de cero: rm -rf $DIR_EASYRSA" >&2
  exit 1
fi

# Copia propia de easy-rsa (la del sistema es de solo lectura).
mkdir -p "$DIR_EASYRSA"
cp -rL /usr/share/easy-rsa/3/* "$DIR_EASYRSA/"
cd "$DIR_EASYRSA"

echo "== Inicializando la PKI =="
./easyrsa init-pki

echo "== Creando la CA =="
./easyrsa --req-cn="CA laboratorio AWS" build-ca nopass

echo "== Creando y firmando el certificado del servidor =="
./easyrsa build-server-full servidor nopass

echo "== Generando la clave tls-crypt =="
openvpn --genkey secret pki/ta.key

echo
echo "PKI lista en $DIR_EASYRSA/pki"
echo "Inspeccionen el certificado del servidor:"
echo "  openssl x509 -in $DIR_EASYRSA/pki/issued/servidor.crt -noout -subject -issuer -dates -ext extendedKeyUsage"
echo "Siguiente paso: ./03-configurar-servidor.sh"
