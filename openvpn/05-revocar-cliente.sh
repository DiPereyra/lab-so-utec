#!/usr/bin/env bash
# PASO 5 (OPCIONAL) — Revocar el certificado de un cliente.
#
# Un certificado vale hasta su fecha de vencimiento. Si un .ovpn se pierde o
# un integrante deja el grupo, hay que REVOCARLO: la CA publica una lista de
# certificados revocados (CRL) y el servidor la consulta en cada conexión.
#
# Uso: ./05-revocar-cliente.sh NOMBRE
set -euo pipefail
source "$(dirname "$0")/config.sh"

NOMBRE="${1:-}"
if [[ -z "$NOMBRE" ]]; then
  echo "Uso: $0 NOMBRE" >&2
  exit 1
fi

cd "$DIR_EASYRSA"
./easyrsa revoke "$NOMBRE"
./easyrsa gen-crl

sudo install -m 644 pki/crl.pem "$DIR_SERVIDOR/crl.pem"
sudo restorecon "$DIR_SERVIDOR/crl.pem" || true
sudo sed -i 's/^# *crl-verify crl.pem/crl-verify crl.pem/' "$DIR_SERVIDOR/servidor.conf"
sudo systemctl restart openvpn-server@servidor

rm -f "$DIR_SALIDA/$NOMBRE.ovpn"
echo "Certificado '$NOMBRE' revocado. Ese perfil ya no puede conectarse."
echo "La CRL también vence: si pasan muchos días, regenerarla con ./easyrsa gen-crl y reinstalarla."
