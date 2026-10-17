# =============================================================================
# Salidas del módulo: lo que el proyecto raíz puede usar o mostrar.
# =============================================================================

output "url_sitio_s3" {
  description = "URL del sitio estático servido por S3 (solo HTTP)."
  value       = "http://${aws_s3_bucket_website_configuration.sitio.website_endpoint}"
}

output "bucket_sitio" {
  description = "Nombre del bucket del sitio."
  value       = aws_s3_bucket.sitio.bucket
}

output "url_alb" {
  description = "URL con el nombre DNS propio del ALB (responde la página por defecto)."
  value       = "http://${aws_lb.principal.dns_name}"
}

output "dns_alb" {
  description = "Nombre DNS del ALB, para apuntarle un CNAME."
  value       = aws_lb.principal.dns_name
}

output "url_sitio" {
  description = "URL base del grupo en el ALB; el sitio está en /s3, /ecs/ y /vm/."
  value       = "http://${var.dominio}"
}

output "target_group_vm_arn" {
  description = "ARN del target group donde se registra el servidor privado."
  value       = aws_lb_target_group.vm.arn
}

output "script_sitio_vm" {
  description = "Script que descarga el sitio en /usr/share/nginx/html/vm (para el user_data del servidor privado)."
  value = templatefile("${path.module}/plantillas/descargar-sitio.sh.tftpl", {
    url      = "http://${aws_s3_bucket_website_configuration.sitio.website_endpoint}"
    archivos = local.archivos_sitio
    destino  = "/usr/share/nginx/html/vm"
  })

  # Quien use el script (la instancia) tiene que esperar a que estén los archivos.
  depends_on = [aws_s3_object.sitio]
}

output "cluster_ecs" {
  description = "Nombre del cluster ECS."
  value       = aws_ecs_cluster.principal.name
}

output "servicio_ecs" {
  description = "Nombre del servicio ECS."
  value       = aws_ecs_service.web.name
}

output "grupo_logs" {
  description = "Grupo de CloudWatch Logs donde escriben los contenedores."
  value       = aws_cloudwatch_log_group.web.name
}

output "perfil_instancia" {
  description = "Nombre del instance profile para asociar a las instancias EC2."
  value       = local.perfil_instancia
}

output "sg_alb_id" {
  description = "ID del security group del ALB."
  value       = aws_security_group.alb.id
}

output "sg_tareas_id" {
  description = "ID del security group de las tareas ECS."
  value       = aws_security_group.tareas.id
}
