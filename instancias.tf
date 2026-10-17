# =============================================================================
# PARTE 4 — Instancias EC2: EXTENSIÓN DEL PROYECTO (la escriben ustedes)
#
#   bastion  -> Fedora Cloud (sin interfaz gráfica), subred PÚBLICA,
#               clave claves/bastion.pem, usuario "fedora". Correrá OpenVPN.
#   privada  -> Amazon Linux 2023, subred PRIVADA, sin IP pública,
#               clave claves/privada.pem, usuario "ec2-user".
#
# ¿Por qué Fedora en el bastión? OpenVPN y easy-rsa están en los repositorios
# oficiales de Fedora; Amazon Linux 2023 no los trae ni usa EPEL.
#
# Las claves SSH ya están creadas en claves.tf (aws_key_pair.bastion y
# aws_key_pair.privada). El instance profile lo devuelve el módulo:
# module.servicios.perfil_instancia
#
# Método de trabajo: descomentar de a un bloque, completar los ???,
# y después:  tofu fmt && tofu validate && tofu plan
# =============================================================================


# --- TODO 4.1: variables de dimensionamiento ------------------------------------
# Elijan el tipo de instancia MÁS BARATO que alcance para cada rol y
# justifiquen la elección en el informe. Criterios:
#   - Arquitectura: las familias t4g (Graviton, ARM) cuestan menos que t3 (x86).
#     Si eligen ARM, las AMI tienen que ser arm64; si eligen x86, x86_64.
#   - Memoria: dnf (Fedora) con 512 MiB suele quedarse sin memoria al
#     actualizar metadatos. Un servidor que solo atiende SSH no necesita más.
#   - Las instancias "t" son de rendimiento ampliable (burstable): acumulan
#     créditos de CPU mientras están ociosas. Ideal para un laboratorio.
#   - AWS Academy solo permite tamaños nano, micro, small, medium y large.
# Precios: https://aws.amazon.com/ec2/pricing/on-demand/
#
# variable "tipo_bastion" {
#   description = "Tipo de instancia del bastión (Fedora + OpenVPN)."
#   type        = string
#   default     = "???"
# }
#
# variable "tipo_privada" {
#   description = "Tipo de instancia del servidor privado (Amazon Linux 2023)."
#   type        = string
#   default     = "???"
# }
#
# variable "version_fedora" {
#   description = "Versión de Fedora Cloud a buscar."
#   type        = string
#   default     = "???"   # la última versión estable publicada
# }


# --- TODO 4.2: imágenes (AMI) ------------------------------------------------------
# Una AMI es la imagen de disco a partir de la cual arranca la instancia.
# Cambia de ID según la región y se actualiza seguido, por eso NO se escribe
# el ID a mano: se busca con un data source.
#
# EJEMPLO RESUELTO — Amazon Linux 2023 para ARM:
#
# data "aws_ami" "amazon_linux" {
#   most_recent = true
#   owners      = ["amazon"]
#
#   filter {
#     name   = "name"
#     values = ["al2023-ami-2023.*-kernel-*-arm64"]
#   }
#   filter {
#     name   = "architecture"
#     values = ["arm64"]
#   }
# }
#
# A COMPLETAR — Fedora Cloud. Datos:
#   - El Proyecto Fedora publica sus AMI desde la cuenta 125523088429.
#   - Para explorar los nombres disponibles:
#       aws ec2 describe-images --owners 125523088429 \
#         --filters "Name=architecture,Values=arm64" \
#         --query 'reverse(sort_by(Images,&CreationDate))[:5].[Name,ImageId]' \
#         --output table
#   - Cuidado con elegir una imagen "Beta" o de una versión sin publicar.
#
# data "aws_ami" "fedora" {
#   most_recent = true
#   owners      = ["???"]
#
#   filter {
#     name   = "name"
#     values = ["Fedora-Cloud-Base*-${var.version_fedora}-*"]
#   }
#   filter {
#     name   = "architecture"
#     values = ["???"]
#   }
# }


# --- TODO 4.3: security groups ---------------------------------------------------
# Un security group es un firewall con estado asociado a la interfaz de red.
# Por defecto NIEGA toda entrada; se agregan reglas de lo que se permite.
# Si se permite una entrada, la respuesta sale sola (por eso "con estado").
#
# EJEMPLO RESUELTO — bastión:
#   entrada: SSH (TCP 22) solo desde la IP del grupo; OpenVPN (UDP 1194)
#   salida : libre
#
# resource "aws_security_group" "bastion" {
#   name        = "lab-${var.grupo}-bastion"
#   description = "Bastion: SSH desde la IP del grupo y OpenVPN"   # solo ASCII
#   vpc_id      = aws_vpc.principal.id
#   tags        = { Name = "lab-${var.grupo}-bastion" }
# }
#
# resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
#   security_group_id = aws_security_group.bastion.id
#   description       = "SSH desde la IP del grupo"
#   ip_protocol       = "tcp"
#   from_port         = 22
#   to_port           = 22
#   cidr_ipv4         = var.mi_ip_cidr
# }
#
# resource "aws_vpc_security_group_ingress_rule" "bastion_vpn" {
#   security_group_id = aws_security_group.bastion.id
#   description       = "OpenVPN"
#   ip_protocol       = "udp"
#   from_port         = 1194
#   to_port           = 1194
#   cidr_ipv4         = "0.0.0.0/0"
# }
#
# resource "aws_vpc_security_group_egress_rule" "bastion_salida" {
#   security_group_id = aws_security_group.bastion.id
#   description       = "Salida libre"
#   ip_protocol       = "-1"            # -1 = todos los protocolos
#   cidr_ipv4         = "0.0.0.0/0"
# }
#
# A COMPLETAR — servidor privado:
#   entrada: SSH solo desde el BASTIÓN. No usen una IP: usen el security group
#            del bastión como origen (atributo referenced_security_group_id).
#            Miren cómo lo hace el módulo en modulos/servicios/ecs.tf.
#            Opcional: ICMP (ping) desde el bastión (ip_protocol = "icmp",
#            from_port = -1, to_port = -1).
#   salida : libre (sale a Internet a través del NAT).
#
# Pregunta para el informe: cuando un cliente VPN se conecta al servidor
# privado, ¿por qué alcanza con la regla "desde el SG del bastión"?
#
# resource "aws_security_group" "privada" {
#   ...
# }
#
# resource "aws_vpc_security_group_ingress_rule" "privada_ssh" {
#   ...
# }
#
# resource "aws_vpc_security_group_egress_rule" "privada_salida" {
#   ...
# }


# --- TODO 4.4: instancias ------------------------------------------------------------
# EJEMPLO RESUELTO — bastión:
#
# resource "aws_instance" "bastion" {
#   ami                    = data.aws_ami.fedora.id
#   instance_type          = var.tipo_bastion
#   subnet_id              = aws_subnet.publica[0].id
#   vpc_security_group_ids = [aws_security_group.bastion.id]
#   key_name               = aws_key_pair.bastion.key_name      # clave PROPIA del bastión
#   iam_instance_profile   = module.servicios.perfil_instancia
#
#   # Si se ejecuta "sudo shutdown" dentro de la instancia, se APAGA (stop)
#   # en lugar de destruirse. Lo usamos para el apagado automático.
#   instance_initiated_shutdown_behavior = "stop"
#
#   metadata_options {
#     http_tokens = "required"     # obliga a usar IMDSv2 (más seguro)
#   }
#
#   root_block_device {
#     volume_type = "gp3"          # más barato que gp2 a igual tamaño
#   }
#
#   tags = { Name = "lab-${var.grupo}-bastion", Rol = "bastion" }
# }
#
# A COMPLETAR — servidor privado. Diferencias con el bastión:
#   - AMI de Amazon Linux, tipo var.tipo_privada
#   - subred PRIVADA (aws_subnet.privada[0])
#   - su security group y SU clave (aws_key_pair.privada)
#   - tag Rol = "privada" (lo usan los scripts de encendido/apagado)
#   - depends_on = [aws_route_table_association.privada]
#     (sin ruta por el NAT, dnf no puede descargar paquetes en el arranque)
#   - el user_data del TODO 4.6 (pueden agregarlo ya ahora)
#
# resource "aws_instance" "privada" {
#   ...
# }


# --- TODO 4.5: configuración SSH --------------------------------------------------
# Genera claves/ssh_config a partir de plantillas/ssh_config.tftpl, con las IP
# reales. Descomenten cuando las dos instancias existan.
#
# resource "local_file" "ssh_config" {
#   filename        = "${path.root}/claves/ssh_config"
#   file_permission = "0600"
#   content = templatefile("${path.root}/plantillas/ssh_config.tftpl", {
#     dir             = abspath("${path.root}/claves")
#     ip_bastion      = aws_instance.bastion.public_ip
#     usuario_bastion = "fedora"
#     ip_privada      = aws_instance.privada.private_ip
#     usuario_privada = "ec2-user"
#   })
# }


# --- TODO 4.6: publicar el servidor privado detrás del ALB -----------------------
# El ALB ya tiene una regla para /vm/ y un target group vacío
# (module.servicios.target_group_vm_arn). Hasta completar este paso,
# http://<grupo>.<dominio_base>/vm/ responde 503: no hay destinos.
#
# Tres piezas:
#
# a) Dentro de su aws_instance "privada", agreguen el user_data. cloud-init lo
#    ejecuta en el primer arranque: instala nginx y descarga el sitio del
#    bucket en /usr/share/nginx/html/vm (lean plantillas/servidor-web.sh.tftpl).
#
#      user_data = templatefile("${path.root}/plantillas/servidor-web.sh.tftpl", {
#        script_sitio = module.servicios.script_sitio_vm
#      })
#
#    Ojo: si la instancia ya existe, cambiar el user_data la apaga y la vuelve
#    a encender, pero el user_data NO se vuelve a ejecutar. Para que corra hay
#    que recrearla:  tofu apply -replace=aws_instance.privada
#
# b) Una regla de entrada en el security group del servidor privado: HTTP
#    (TCP 80) solo desde el security group del ALB (module.servicios.sg_alb_id).
#    Mismo modelo que la regla SSH desde el bastión.
#
# resource "aws_vpc_security_group_ingress_rule" "privada_http" {
#   ...
# }
#
# c) Registrar la instancia en el target group.
#    Recurso: aws_lb_target_group_attachment (target_group_arn, target_id, port).
#    ¿Qué va en target_id para un target group de tipo "instance"?
#
# resource "aws_lb_target_group_attachment" "privada" {
#   ...
# }
