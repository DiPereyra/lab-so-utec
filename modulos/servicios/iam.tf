# =============================================================================
# IAM: quién puede hacer qué
#
#  - Rol de EJECUCIÓN de ECS: lo usa el agente de ECS (no tu aplicación) para
#    descargar la imagen y escribir los logs en CloudWatch.
#  - Rol + instance profile para EC2: permite que las instancias se registren
#    en Systems Manager (Session Manager), útil como alternativa a SSH.
#
# Un "instance profile" es el contenedor que permite asociar un rol a una
# instancia EC2. Las instancias no reciben claves: obtienen credenciales
# temporales del rol a través del servicio de metadatos (IMDS).
# =============================================================================

data "aws_caller_identity" "actual" {}
data "aws_partition" "actual" {}

locals {
  crear_roles = !var.usar_roles_existentes

  rol_ejecucion_arn = (
    local.crear_roles
    ? aws_iam_role.ejecucion_ecs[0].arn
    : "arn:${data.aws_partition.actual.partition}:iam::${data.aws_caller_identity.actual.account_id}:role/${var.rol_existente_ecs}"
  )

  perfil_instancia = (
    local.crear_roles
    ? aws_iam_instance_profile.instancias[0].name
    : var.perfil_instancia_existente
  )
}

# --- Rol de ejecución de tareas ECS ------------------------------------------

# "Política de confianza": dice QUIÉN puede asumir el rol (acá, el servicio ECS).
data "aws_iam_policy_document" "confianza_ecs" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ejecucion_ecs" {
  count              = local.crear_roles ? 1 : 0
  name               = "${var.nombre}-ecs-ejecucion"
  assume_role_policy = data.aws_iam_policy_document.confianza_ecs.json
}

# "Política de permisos": dice QUÉ puede hacer quien asumió el rol.
# Usamos una política administrada por AWS en lugar de escribirla a mano.
resource "aws_iam_role_policy_attachment" "ejecucion_ecs" {
  count      = local.crear_roles ? 1 : 0
  role       = aws_iam_role.ejecucion_ecs[0].name
  policy_arn = "arn:${data.aws_partition.actual.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- Rol e instance profile para EC2 -----------------------------------------

data "aws_iam_policy_document" "confianza_ec2" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instancias" {
  count              = local.crear_roles ? 1 : 0
  name               = "${var.nombre}-ec2"
  assume_role_policy = data.aws_iam_policy_document.confianza_ec2.json
}

resource "aws_iam_role_policy_attachment" "instancias_ssm" {
  count      = local.crear_roles ? 1 : 0
  role       = aws_iam_role.instancias[0].name
  policy_arn = "arn:${data.aws_partition.actual.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instancias" {
  count = local.crear_roles ? 1 : 0
  name  = "${var.nombre}-ec2"
  role  = aws_iam_role.instancias[0].name
}
