#!/usr/bin/env bash
# PASO 4 — Emitir un certificado de cliente y armar su perfil .ovpn
#
# Uso: ./04-crear-cliente.sh NOMBRE
#
# El .ovpn es "autocontenido": lleva adentro el certificado de la CA, el
# certificado y la clave privada del cliente y la clave tls-crypt. Con ese
# único archivo el cliente se conecta. Por eso es secreto y es personal.
set -euo pipefail
source "$(dirname "$0")/config.sh"

NOMBRE="${1:-}"
if ! [[ "$NOMBRE" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "Uso: $0 NOMBRE   (letras, números, guion o guion bajo)" >&2
  exit 1
fi

PKI="$DIR_EASYRSA/pki"
if [[ -f "$PKI/issued/$NOMBRE.crt" ]]; then
  echo "Ya existe un certificado para '$NOMBRE'. Usen otro nombre o revóquenlo." >&2
  exit 1
fi

echo "== Emitiendo certificado de cliente '$NOMBRE' =="
(cd "$DIR_EASYRSA" && ./easyrsa build-client-full "$NOMBRE" nopass)

# IP pública del bastión, consultada al servicio de metadatos (IMDSv2):
# primero se pide un token con PUT y después se lo usa en la consulta.
TOKEN=$(curl -sS -X PUT "http://169.254.169.254/latest/api/token" \
          -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
IP_PUBLICA=$(curl -sS -H "X-aws-ec2-metadata-token: $TOKEN" \
          "http://169.254.169.254/latest/meta-data/public-ipv4")

mkdir -p "$DIR_SALIDA"
chmod 700 "$DIR_SALIDA"
PERFIL="$DIR_SALIDA/$NOMBRE.ovpn"
umask 077

{
  cat <<EOF
# Perfil OpenVPN de $NOMBRE — Laboratorio AWS
# Generado $(date -Iseconds). Si el bastión cambia de IP, editar la línea "remote".
client
dev tun
proto udp
remote $IP_PUBLICA $PUERTO_VPN
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
tls-version-min 1.2
data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305
verb 3
EOF
  echo "<ca>";        cat "$PKI/ca.crt";                                   echo "</ca>"
  echo "<cert>";      openssl x509 -in "$PKI/issued/$NOMBRE.crt";          echo "</cert>"
  echo "<key>";       cat "$PKI/private/$NOMBRE.key";                      echo "</key>"
  echo "<tls-crypt>"; cat "$PKI/ta.key";                                   echo "</tls-crypt>"
} > "$PERFIL"

echo
echo "Perfil creado: $PERFIL"
echo "Traerlo a tu máquina (desde la carpeta del proyecto):"
echo "  scp -F claves/ssh_config lab-bastion:$PERFIL ."
