# shellcheck shell=bash disable=SC2034
# Parámetros compartidos por los scripts de OpenVPN.
# Si cambiaron el CIDR de la VPC en OpenTofu, cámbienlo también acá.

# Red de la VPC que se publica a los clientes VPN (debe coincidir con cidr_vpc).
RED_VPC="10.20.0.0"
MASCARA_VPC="255.255.0.0"
CIDR_VPC="10.20.0.0/16"

# Red interna del túnel: cada cliente recibe una IP de acá.
# No debe superponerse con la VPC ni con la red de tu casa.
RED_VPN="10.8.0.0"
MASCARA_VPN="255.255.255.0"
CIDR_VPN="10.8.0.0/24"

PUERTO_VPN="1194"

# Dónde vive la PKI (infraestructura de clave pública) de easy-rsa.
DIR_EASYRSA="$HOME/easy-rsa"

# Dónde lee OpenVPN su configuración en Fedora (servicio openvpn-server@).
DIR_SERVIDOR="/etc/openvpn/server"

# Carpeta donde se dejan los perfiles .ovpn generados.
DIR_SALIDA="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/salida"

# easy-rsa en modo no interactivo, con curvas elípticas (claves cortas y rápidas).
export EASYRSA_BATCH=1
export EASYRSA_ALGO=ec
export EASYRSA_CURVE=prime256v1
export EASYRSA_CERT_EXPIRE=180
