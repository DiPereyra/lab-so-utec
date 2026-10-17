# =============================================================================
# ECS con Fargate
#
#   Cluster          -> agrupación lógica (en Fargate no hay servidores que ver)
#   Task definition  -> "receta": imagen, CPU, memoria, puertos, logs, rol
#   Service          -> mantiene N copias (tareas) de la receta corriendo y las
#                       registra en el target group del ALB
#
# Las tareas corren en las subredes PRIVADAS. Para descargar la imagen desde
# public.ecr.aws, y el sitio desde el bucket, salen a Internet a través del
# NAT gateway.
# =============================================================================

resource "aws_ecs_cluster" "principal" {
  name = "${var.nombre}-cluster"

  # Container Insights genera métricas extra que se cobran; lo dejamos apagado.
  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

resource "aws_cloudwatch_log_group" "web" {
  name              = "/ecs/${var.nombre}/web"
  retention_in_days = 1 # Logs de laboratorio: no vale la pena guardarlos.
}

data "aws_region" "actual" {}

locals {
  # El contenedor, al arrancar, descarga el sitio del bucket a la carpeta /ecs/
  # de nginx (la ruta que le corresponde en el ALB) y después inicia nginx.
  script_contenedor = join("\n", [
    templatefile("${path.module}/plantillas/descargar-sitio.sh.tftpl", {
      url      = "http://${aws_s3_bucket_website_configuration.sitio.website_endpoint}"
      archivos = local.archivos_sitio
      destino  = "/usr/share/nginx/html/ecs"
    }),
    "exec nginx -g 'daemon off;'",
  ])

  contenedor_base = {
    name      = "web"
    image     = var.imagen_contenedor
    essential = true
    portMappings = [{
      containerPort = var.puerto_contenedor
      protocol      = "tcp"
    }]
    # VERSION_SITIO cambia cuando cambia algún archivo del sitio: eso genera
    # una nueva task definition y ECS reemplaza las tareas, que lo vuelven a
    # descargar.
    environment = [{ name = "VERSION_SITIO", value = local.version_sitio }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.web.name
        awslogs-region        = data.aws_region.actual.region
        awslogs-stream-prefix = "web"
      }
    }
  }

  contenedor = merge(
    local.contenedor_base,
    var.publicar_sitio ? {
      entryPoint = ["/bin/sh", "-c"]
      command    = [local.script_contenedor]
    } : {}
  )
}

resource "aws_ecs_task_definition" "web" {
  family                   = "${var.nombre}-web"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc" # Cada tarea recibe su propia interfaz de red e IP.
  cpu                      = var.cpu_tarea
  memory                   = var.memoria_tarea
  execution_role_arn       = local.rol_ejecucion_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.arquitectura
  }

  container_definitions = jsonencode([local.contenedor])
}

# --- Security group de las tareas --------------------------------------------

resource "aws_security_group" "tareas" {
  name        = "${var.nombre}-tareas"
  description = "Tareas ECS: solo aceptan trafico desde el ALB"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.nombre}-tareas" }
}

# La regla NO usa un rango de IP sino OTRO security group como origen:
# "acepto tráfico de cualquier cosa que tenga puesto el SG del ALB".
resource "aws_vpc_security_group_ingress_rule" "tareas_desde_alb" {
  security_group_id            = aws_security_group.tareas.id
  description                  = "HTTP solo desde el ALB"
  ip_protocol                  = "tcp"
  from_port                    = var.puerto_contenedor
  to_port                      = var.puerto_contenedor
  referenced_security_group_id = aws_security_group.alb.id
}

# Salida libre: hace falta para descargar la imagen y el sitio, y enviar logs (vía NAT).
resource "aws_vpc_security_group_egress_rule" "tareas_salida" {
  security_group_id = aws_security_group.tareas.id
  description       = "Salida a Internet via NAT"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# --- Servicio ------------------------------------------------------------------

resource "aws_ecs_service" "web" {
  name            = "${var.nombre}-web"
  cluster         = aws_ecs_cluster.principal.id
  task_definition = aws_ecs_task_definition.web.arn
  launch_type     = "FARGATE"
  desired_count   = var.cantidad_tareas

  network_configuration {
    subnets          = var.subredes_privadas
    security_groups  = [aws_security_group.tareas.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs.arn
    container_name   = "web"
    container_port   = var.puerto_contenedor
  }

  health_check_grace_period_seconds = 30

  # El target group tiene que estar asociado a una regla del listener antes de
  # crear el servicio, y los archivos tienen que estar en el bucket antes de
  # que arranque la primera tarea.
  depends_on = [aws_lb_listener_rule.ecs, aws_s3_object.sitio]
}
