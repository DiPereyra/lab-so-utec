# =============================================================================
# PARTE 3 — Módulo de servicios: S3 (sitio estático), ALB, ECS e IAM
#
# El mismo sitio (carpeta sitio/) se publica de tres formas, todas bajo el
# subdominio del grupo:
#   http://g1.lab.jplorier.com/s3    S3: el ALB redirige al bucket
#   http://g1.lab.jplorier.com/ecs/  ECS Fargate detrás del ALB
#   http://g1.lab.jplorier.com/vm/   servidor privado (EC2) detrás del ALB
#                                      (se conecta en la Parte 4, TODO 4.6)
#
# El módulo ./modulos/servicios se entrega terminado. Lean sus archivos:
#   s3.tf   bucket con sitio web y política de lectura pública
#   alb.tf  security group, balanceador, target groups, listener y reglas
#   ecs.tf  cluster, task definition, servicio y security group de tareas
#   iam.tf  roles y políticas (o uso de LabRole en Learner Lab)
#
# Un módulo es como una función: recibe variables (variables.tf) y devuelve
# salidas (outputs.tf). Desde acá se lo "llama" con un bloque module.
#
# TODO 3.1: cuando la red privada esté completa, descomenten el bloque y
# ejecuten:  tofu init   (para que registre el módulo)  y  tofu apply
# =============================================================================

# Nombre por el que se entra al sitio del grupo: g1.lab.jplorier.com
locals {
  dominio = "${var.grupo}.${var.dominio_base}"
}

# module "servicios" {
#   source = "./modulos/servicios"
#
#   nombre            = "lab-${var.grupo}"
#   vpc_id            = aws_vpc.principal.id
#   subredes_publicas = aws_subnet.publica[*].id   # [*] = lista con los id de todas las copias
#   subredes_privadas = aws_subnet.privada[*].id
#   dominio           = local.dominio            # las reglas del ALB responden a este host
#   usar_https        = local.hay_certificado    # HTTPS (certificado.tf); false si no hay certs/
#   certificado_arn   = local.certificado_arn
#
#   directorio_sitio = "${path.root}/sitio"
#
#   cantidad_tareas       = var.cantidad_tareas
#   usar_roles_existentes = var.usar_roles_existentes
#
#   # Las tareas necesitan la ruta por el NAT para descargar la imagen.
#   depends_on = [aws_route_table_association.privada]
# }

# --- TODO 3.2: subdominio del grupo en deSEC (EJEMPLO RESUELTO) ----------------
# El ALB tiene un nombre DNS largo que cambia cada vez que se recrea
# (lab-g1-alb-123456789.us-east-1.elb.amazonaws.com). Le apuntamos un
# nombre fijo con un registro CNAME ("alias de otro nombre").
#
# ¿Por qué CNAME y no un registro A con la IP? Porque el ALB no tiene una IP
# fija: AWS le cambia y agrega IP según la carga.
#
# Antes de descomentar, carguen el token de DNS de SU grupo (Parte 0):
#   source .env                 (define DESEC_API_TOKEN)
# Ese token solo puede escribir el CNAME <grupo>.lab.jplorier.com: si
# var.grupo no coincide con el nombre que les dio el docente, deSEC lo rechaza.
#
# resource "terraform_data" "dns" {
#   input = {
#     dominio = var.dominio_base
#     subname = var.grupo
#     destino = "${lower(module.servicios.dns_alb)}." # punto final: nombre absoluto
#     ttl     = 900                                   # 15 min: el mínimo de la zona en deSEC
#   }
#
#   # PUT sobre la lista de registros crea el registro o lo reemplaza.
#   provisioner "local-exec" {
#     command = <<-EOT
#       curl -fsS --retry 5 -X PUT "https://desec.io/api/v1/domains/${self.input.dominio}/rrsets/" \
#         -H "Authorization: Token $${DESEC_API_TOKEN:?Falta DESEC_API_TOKEN: ejecuten source .env}" \
#         -H "Content-Type: application/json" \
#         --data '${jsonencode([{ subname = self.input.subname, type = "CNAME", ttl = self.input.ttl, records = [self.input.destino] }])}'
#     EOT
#   }
#
#   # Con "records" vacío, deSEC borra el registro (PATCH: no exige el ttl).
#   provisioner "local-exec" {
#     when    = destroy
#     command = <<-EOT
#       curl -fsS --retry 5 -X PATCH "https://desec.io/api/v1/domains/${self.input.dominio}/rrsets/" \
#         -H "Authorization: Token $${DESEC_API_TOKEN:?Falta DESEC_API_TOKEN: ejecuten source .env}" \
#         -H "Content-Type: application/json" \
#         --data '${jsonencode([{ subname = self.input.subname, type = "CNAME", records = [] }])}'
#     EOT
#   }
# }
