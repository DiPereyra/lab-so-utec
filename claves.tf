# =============================================================================
# Claves SSH de las instancias  (ARCHIVO ENTREGADO: no hace falta modificarlo)
#
# Requisito del laboratorio: UNA CLAVE DISTINTA POR INSTANCIA.
#   - claves/bastion.pem  -> solo abre el bastión
#   - claves/privada.pem  -> solo abre el servidor privado
#
# Ambas claves privadas quedan en TU máquina. Al saltar a través del bastión
# con ProxyJump (ssh -J), la clave del servidor privado nunca se copia al
# bastión: el bastión solo reenvía la conexión cifrada.
#
# Cómo funciona:
#   1. tls_private_key genera un par de claves (pública + privada).
#   2. aws_key_pair registra la clave PÚBLICA en EC2 con un nombre.
#   3. Al crear la instancia se indica key_name; cloud-init copia la clave
#      pública a ~/.ssh/authorized_keys del usuario por defecto.
#   4. local_sensitive_file guarda la clave PRIVADA en ./claves con permisos
#      0400 (ssh se niega a usar claves privadas legibles por otros).
#
# ATENCIÓN: las claves privadas también quedan guardadas en terraform.tfstate.
# Por eso el estado no se comparte ni se sube a git.
# =============================================================================

# --- Bastión -------------------------------------------------------------------

resource "tls_private_key" "bastion" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "bastion" {
  key_name   = "lab-${var.grupo}-bastion"
  public_key = tls_private_key.bastion.public_key_openssh
}

resource "local_sensitive_file" "clave_bastion" {
  content         = tls_private_key.bastion.private_key_openssh
  filename        = "${path.root}/claves/bastion.pem"
  file_permission = "0400"
}

# --- Servidor privado ----------------------------------------------------------

resource "tls_private_key" "privada" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "privada" {
  key_name   = "lab-${var.grupo}-privada"
  public_key = tls_private_key.privada.public_key_openssh
}

resource "local_sensitive_file" "clave_privada" {
  content         = tls_private_key.privada.private_key_openssh
  filename        = "${path.root}/claves/privada.pem"
  file_permission = "0400"
}
