#!/usr/bin/env bash
# PASO 3 — Instalar la configuración, habilitar el reenvío de paquetes y el
# NAT, y arrancar el servicio.
#
# Camino de un paquete de un cliente VPN hacia el servidor privado:
#
#   cliente 10.8.0.2 --túnel UDP 1194--> bastión (tun0)
#       bastión reenvía (ip_forward=1) y ENMASCARA el origen (NAT):
#       10.8.0.2 -> IP privada del bastión
#   --> servidor privado 10.20.10.x
#
# Gracias al enmascaramiento:
#   - el servidor privado ve llegar el tráfico desde el bastión, así que su
#     security group (que solo permite al bastión) lo acepta;
#   - la respuesta vuelve al bastión, que la devuelve por el túnel; no hace
#     falta agregar rutas hacia 10.8.0.0/24 en las tablas de ruteo de la VPC.
set -euo pipefail
source "$(dirname "$0")/config.sh"
DIR_KIT="$(cd "$(dirname "$0")" && pwd)"
PKI="$DIR_EASYRSA/pki"

if [[ ! -f "$PKI/issued/servidor.crt" ]]; then
  echo "Falta la PKI. Ejecuten primero ./02-crear-pki.sh" >&2
  exit 1
fi

echo "== Copiando certificados a $DIR_SERVIDOR =="
sudo install -d -m 750 "$DIR_SERVIDOR"
sudo install -m 644 "$PKI/ca.crt"                "$DIR_SERVIDOR/ca.crt"
sudo install -m 644 "$PKI/issued/servidor.crt"   "$DIR_SERVIDOR/servidor.crt"
sudo install -m 600 "$PKI/private/servidor.key"  "$DIR_SERVIDOR/servidor.key"
sudo install -m 600 "$PKI/ta.key"                "$DIR_SERVIDOR/ta.key"

echo "== Generando servidor.conf =="
sed -e "s/__PUERTO_VPN__/$PUERTO_VPN/" \
    -e "s/__RED_VPN__/$RED_VPN/"       -e "s/__MASCARA_VPN__/$MASCARA_VPN/" \
    -e "s/__RED_VPC__/$RED_VPC/"       -e "s/__MASCARA_VPC__/$MASCARA_VPC/" \
    "$DIR_KIT/servidor.conf" | sudo tee "$DIR_SERVIDOR/servidor.conf" >/dev/null

# SELinux: los archivos copiados tienen que llevar la etiqueta que permite a
# OpenVPN leerlos. restorecon aplica la etiqueta correcta según la ruta.
sudo restorecon -R "$DIR_SERVIDOR" || true

echo "== Habilitando reenvío de paquetes IPv4 =="
echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/90-lab-vpn.conf >/dev/null
sudo sysctl -p /etc/sysctl.d/90-lab-vpn.conf

echo "== Configurando NAT con nftables =="
sudo tee /etc/nftables/lab-vpn.nft >/dev/null <<EOF
# NAT de los clientes VPN hacia la VPC (generado por 03-configurar-servidor.sh)
table ip lab_vpn
delete table ip lab_vpn
table ip lab_vpn {
    chain postrouting {
        type nat hook postrouting priority srcnat; policy accept;
        ip saddr $CIDR_VPN ip daddr $CIDR_VPC masquerade
    }
}
EOF
if ! sudo grep -q 'lab-vpn.nft' /etc/sysconfig/nftables.conf 2>/dev/null; then
  echo 'include "/etc/nftables/lab-vpn.nft"' | sudo tee -a /etc/sysconfig/nftables.conf >/dev/null
fi
sudo systemctl enable --now nftables
sudo nft -f /etc/nftables/lab-vpn.nft

# Si firewalld estuviera activo, también hay que abrirle el puerto.
if systemctl is-active --quiet firewalld; then
  echo "firewalld activo: abriendo $PUERTO_VPN/udp y habilitando enmascaramiento"
  sudo firewall-cmd --permanent --add-port="$PUERTO_VPN/udp"
  sudo firewall-cmd --permanent --add-masquerade
  sudo firewall-cmd --permanent --zone=trusted --add-interface=tun0
  sudo firewall-cmd --reload
fi

echo "== Arrancando openvpn-server@servidor =="
sudo systemctl enable --now openvpn-server@servidor
sleep 2
sudo systemctl --no-pager --lines=5 status openvpn-server@servidor || true

echo
ip -brief address show tun0 || echo "tun0 no aparece: revisen 'sudo journalctl -u openvpn-server@servidor'"
echo "Siguiente paso: ./04-crear-cliente.sh NOMBRE"
