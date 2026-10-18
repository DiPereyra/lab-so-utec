# =============================================================================
# Application Load Balancer (ALB)
#
# El mismo sitio se publica de tres formas, todas bajo el subdominio del grupo
# (var.dominio, ej.: g1.lab.jplorier.com):
#
#   https://g1.lab.jplorier.com/ecs/  --> target group "ecs" --> tareas Fargate
#   https://g1.lab.jplorier.com/vm/   --> target group "vm"  --> servidor privado (EC2)
#   http://g1.lab.jplorier.com/s3     --> redirección 302 al sitio web del bucket
#
# HTTPS: con var.usar_https y var.certificado_arn (el certificado
# *.lab.jplorier.com del curso, importado en ACM), el ALB escucha también en
# el 443 y las reglas de /ecs/ y /vm/ van en ese listener; en el 80, lo que
# llega para el dominio del grupo se redirige al 443. /s3 queda siempre en el
# 80: el sitio web de S3 solo existe en HTTP y un listener HTTPS no puede
# redirigir a HTTP. Sin certificado, todo funciona igual pero solo por HTTP.
#
# Flujo de una petición:
#   Internet --> ALB (subredes públicas, puertos 80 y 443) --> listener
#            --> reglas, de menor a mayor prioridad: la primera cuyas
#                condiciones (host Y ruta) se cumplen decide qué hacer
#            --> si ninguna se cumple: acción por defecto (página fija)
#
# El ALB NO recorta la ruta: una petición a /ecs/estilo.css llega al
# contenedor como /ecs/estilo.css. Por eso cada servidor guarda el sitio en
# una carpeta con el mismo nombre que su ruta.
#
# El ALB es lo ÚNICO expuesto a Internet. Las tareas y el servidor privado no
# tienen IP pública y solo aceptan tráfico que venga del security group del ALB.
# =============================================================================

data "aws_vpc" "seleccionada" {
  id = var.vpc_id
}

locals {
  https   = var.usar_https
  esquema = local.https ? "https" : "http"

  # Las reglas de /ecs/ y /vm/ van en el listener 443 si hay certificado.
  listener_sitio = local.https ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn

  # Página que arma el propio ALB cuando ninguna regla coincide.
  portada = <<-EOT
    <!doctype html><meta charset="utf-8"><title>${var.nombre}</title>
    <body style="font-family:sans-serif;max-width:40em;margin:3em auto">
    <h1>${var.nombre}</h1>
    <p>Esta respuesta la arma el ALB: ninguna regla coincidi&oacute; con el host y la ruta pedidos.</p>
    <ul>
    <li><a href="http://${var.dominio}/s3">http://${var.dominio}/s3</a> &mdash; S3 (solo HTTP)</li>
    <li><a href="${local.esquema}://${var.dominio}/ecs/">${local.esquema}://${var.dominio}/ecs/</a> &mdash; ECS Fargate</li>
    <li><a href="${local.esquema}://${var.dominio}/vm/">${local.esquema}://${var.dominio}/vm/</a> &mdash; EC2</li>
    </ul></body>
  EOT
}

# --- Security group del ALB --------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${var.nombre}-alb"
  description = "ALB: HTTP desde Internet"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.nombre}-alb" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP desde cualquier origen"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  count             = local.https ? 1 : 0
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS desde cualquier origen"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

# El ALB solo necesita salir hacia adentro de la VPC (hacia las tareas y el
# servidor privado; los dos escuchan en el mismo puerto).
resource "aws_vpc_security_group_egress_rule" "alb_hacia_vpc" {
  security_group_id = aws_security_group.alb.id
  description       = "Hacia las tareas y el servidor privado dentro de la VPC"
  ip_protocol       = "tcp"
  from_port         = var.puerto_contenedor
  to_port           = var.puerto_contenedor
  cidr_ipv4         = data.aws_vpc.seleccionada.cidr_block
}

# --- Balanceador -------------------------------------------------------------

resource "aws_lb" "principal" {
  name               = "${var.nombre}-alb"
  load_balancer_type = "application"
  internal           = false
  subnets            = var.subredes_publicas
  security_groups    = [aws_security_group.alb.id]
}

# --- Target groups: a quién le reenvía el ALB --------------------------------

# Tareas ECS. Fargate registra la IP de cada tarea, no una instancia.
resource "aws_lb_target_group" "ecs" {
  name        = "${var.nombre}-ecs"
  port        = var.puerto_contenedor
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  # Tiempo que el ALB espera antes de dar de baja un destino. Lo bajamos para
  # que destroy y los redespliegues sean rápidos (en producción se deja mayor).
  deregistration_delay = 10

  health_check {
    path                = "/ecs/"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

# Servidor privado (EC2). Acá se registra el ID de la instancia; ese registro
# (aws_lb_target_group_attachment) lo escriben ustedes en instancias.tf.
resource "aws_lb_target_group" "vm" {
  name        = "${var.nombre}-vm"
  port        = var.puerto_contenedor
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  deregistration_delay = 10

  health_check {
    path                = "/vm/"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

# --- Listeners: puertos donde escucha el ALB --------------------------------

# Si ninguna regla coincide (por ejemplo, si se entra con el nombre DNS propio
# del ALB en lugar del subdominio), responde el propio ALB con local.portada.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.principal.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/html"
      status_code  = "200"
      message_body = local.portada
    }
  }
}

# El ALB descifra el TLS con el certificado y habla HTTP con los destinos
# (dentro de la VPC). La política de seguridad fija versiones de TLS y cifrados.
resource "aws_lb_listener" "https" {
  count             = local.https ? 1 : 0
  load_balancer_arn = aws_lb.principal.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificado_arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/html"
      status_code  = "200"
      message_body = local.portada
    }
  }
}

# Con HTTPS: lo que llega por HTTP para el dominio del grupo se redirige al 443
# (301: permanente) conservando la ruta. Prioridad 100: se evalúa DESPUÉS de
# la regla de /s3 (30), que tiene que seguir funcionando por HTTP.
resource "aws_lb_listener_rule" "a_https" {
  count        = local.https ? 1 : 0
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    host_header {
      values = [var.dominio]
    }
  }

  action {
    type = "redirect"

    redirect {
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301"
    }
  }
}

# --- Reglas del listener -------------------------------------------------------

resource "aws_lb_listener_rule" "ecs" {
  listener_arn = local.listener_sitio
  priority     = 10

  condition {
    host_header {
      values = [var.dominio]
    }
  }
  condition {
    path_pattern {
      values = ["/ecs", "/ecs/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs.arn
  }
}

resource "aws_lb_listener_rule" "vm" {
  listener_arn = local.listener_sitio
  priority     = 20

  condition {
    host_header {
      values = [var.dominio]
    }
  }
  condition {
    path_pattern {
      values = ["/vm", "/vm/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vm.arn
  }
}

# S3 no está detrás del ALB: el ALB le contesta al navegador "andá a esta otra
# dirección" (HTTP 302) y el navegador va directo al bucket. Va siempre en el
# listener 80: el ALB no permite redirigir de HTTPS a HTTP.
resource "aws_lb_listener_rule" "s3" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 30

  condition {
    host_header {
      values = [var.dominio]
    }
  }
  condition {
    path_pattern {
      values = ["/s3", "/s3/*"]
    }
  }

  action {
    type = "redirect"

    redirect {
      host        = aws_s3_bucket_website_configuration.sitio.website_endpoint
      path        = "/"
      port        = "80"
      protocol    = "HTTP"
      status_code = "HTTP_302" # temporal: el navegador no la guarda para siempre
    }
  }
}
