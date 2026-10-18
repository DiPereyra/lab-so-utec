# =============================================================================
# Salidas: se muestran al final de "tofu apply" y con "tofu output".
# Vayan descomentando a medida que completan cada parte.
# =============================================================================

output "vpc_id" {
  value = aws_vpc.principal.id
}

output "subredes_publicas" {
  value = aws_subnet.publica[*].cidr_block
}

# --- Parte 2 -----------------------------------------------------------------------
# output "subredes_privadas" {
#   value = aws_subnet.privada[*].cidr_block
# }

# --- Parte 3 -----------------------------------------------------------------------
# output "url_sitio_s3" {
#   description = "Sitio estático servido por S3."
#   value       = module.servicios.url_sitio_s3
# }
#
# output "url_alb" {
#   description = "Nombre DNS propio del ALB: responde la página por defecto."
#   value       = module.servicios.url_alb
# }
#
# output "urls_sitio" {
#   description = "El mismo sitio, publicado de tres formas."
#   value = {
#     s3  = module.servicios.url_s3_por_alb
#     ecs = "${module.servicios.url_sitio}/ecs/"
#     vm  = "${module.servicios.url_sitio}/vm/"
#   }
# }

# --- Parte 4 -----------------------------------------------------------------------
# output "ip_publica_bastion" {
#   description = "Cambia cada vez que el bastión se apaga y se enciende."
#   value       = aws_instance.bastion.public_ip
# }
#
# output "ip_privada_servidor" {
#   value = aws_instance.privada.private_ip
# }
#
# output "ssh_bastion" {
#   value = "ssh -F claves/ssh_config lab-bastion"
# }
#
# output "ssh_privada" {
#   value = "ssh -F claves/ssh_config lab-privada"
# }
