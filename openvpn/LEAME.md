# Kit OpenVPN para el bastión (Fedora)

Estos scripts se copian al bastión y se ejecutan **ahí**, como el usuario
`fedora`, en orden. Cada uno explica en sus comentarios qué hace y por qué.

```bash
# Desde la carpeta del proyecto, en tu máquina:
scp -F claves/ssh_config -r openvpn lab-bastion:~
ssh -F claves/ssh_config lab-bastion

# Ya dentro del bastión:
cd ~/openvpn
./01-instalar.sh
./02-crear-pki.sh
./03-configurar-servidor.sh
./04-crear-cliente.sh ana        # uno por integrante, nombres distintos
./04-crear-cliente.sh bruno
```

Después, desde tu máquina, se trae el perfil y se prueba:

```bash
scp -F claves/ssh_config lab-bastion:~/openvpn/salida/ana.ovpn .
sudo openvpn --config ana.ovpn        # Linux/macOS (o importarlo en la app OpenVPN Connect)

# En otra terminal, con la VPN levantada, el servidor privado responde
# SIN pasar por el salto SSH:
ping 10.20.10.X
ssh -i claves/privada.pem ec2-user@10.20.10.X
```

## Qué genera cada paso

| Script | Resultado |
|---|---|
| `01-instalar.sh` | Paquetes `openvpn`, `easy-rsa`, `nftables` |
| `02-crear-pki.sh` | `~/easy-rsa/pki`: CA, certificado del servidor y clave `tls-crypt` |
| `03-configurar-servidor.sh` | `/etc/openvpn/server/servidor.conf`, reenvío IP, NAT y el servicio arrancado |
| `04-crear-cliente.sh NOMBRE` | `salida/NOMBRE.ovpn`: perfil autocontenido para el cliente |
| `05-revocar-cliente.sh NOMBRE` | (opcional) Revoca un certificado y activa la lista de revocación |

## Archivos que NO se comparten

- `~/easy-rsa/pki/private/ca.key`: con ella cualquiera puede emitir
  certificados válidos para tu VPN.
- Cada `.ovpn`: incluye la clave privada de ese cliente. Uno por persona.

## Si el bastión se apaga y se enciende

La IP pública cambia. El servidor sigue configurado (está en el disco), pero
los `.ovpn` apuntan a la IP vieja: editen la línea `remote` o vuelvan a
ejecutar `04-crear-cliente.sh` con un nombre nuevo.
