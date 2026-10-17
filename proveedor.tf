# =============================================================================
# Proveedor AWS
#
# Las credenciales se pasan por VARIABLES DE ENTORNO (es lo que usa este
# laboratorio; ver la Parte 0 del enunciado):
#   AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN (Learner Lab)
#   y AWS_REGION. Están en .env (copia de .env.example) y se cargan con:
#     source .env
#
# Si no hay variables de entorno, OpenTofu busca después el perfil indicado en
# "perfil_aws" y el perfil "default" de ~/.aws/credentials.
#
# Las credenciales NUNCA se escriben en archivos .tf ni en terraform.tfvars.
# =============================================================================

provider "aws" {
  region  = var.region
  profile = var.perfil_aws

  # Etiquetas que se agregan automáticamente a TODOS los recursos.
  # Sirven para encontrar y filtrar lo que creó cada grupo (y lo usan los
  # scripts de encendido/apagado).
  default_tags {
    tags = {
      Laboratorio = "lab-aws"
      Grupo       = var.grupo
      Gestionado  = "opentofu"
    }
  }
}

# =============================================================================
# Proveedor deSEC (DNS)
#
# deSEC es un servicio de DNS gratuito. La zona del curso es lab.jplorier.com
# y cada grupo crea ahí su subdominio:
#   grupo1.lab.jplorier.com -> CNAME -> nombre DNS del ALB
#
# El docente entrega a cada grupo SU token, que solo puede escribir el registro
# CNAME <grupo>.lab.jplorier.com. Se pasa por variable de entorno, igual que
# las credenciales de AWS (en .env):
#   export DESEC_API_TOKEN="..."
# Nunca se escribe en archivos .tf ni en terraform.tfvars.
#
# Ojo: OpenTofu configura este proveedor apenas exista un recurso desec_* en
# el código, así que desde la Parte 3 sin el token falla "tofu plan".
# =============================================================================

provider "desec" {}
