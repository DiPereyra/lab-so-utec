# =============================================================================
# Variables generales del laboratorio
# Los valores se cargan en terraform.tfvars (copiar terraform.tfvars.example).
# Las variables de las instancias se definen en instancias.tf.
# =============================================================================

variable "grupo" {
  description = "Identificador del grupo que indicó el docente, en minúsculas (ej.: g3). Se usa en nombres, etiquetas y en el subdominio: el token de DNS del grupo solo sirve para este nombre."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{1,12}$", var.grupo))
    error_message = "Usar de 1 a 12 caracteres: minúsculas, números o guiones."
  }
}

variable "region" {
  description = "Región de AWS. AWS Academy solo permite us-east-1 y us-west-2."
  type        = string
  default     = "us-east-1"
}

variable "perfil_aws" {
  description = "Perfil de ~/.aws/credentials a usar. null = variables de entorno o perfil default."
  type        = string
  default     = null
}

variable "cidr_vpc" {
  description = "Bloque de direcciones de la VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "mi_ip_cidr" {
  description = "IP pública desde donde se conecta el grupo por SSH al bastión, en formato CIDR (ej.: 190.64.10.20/32)."
  type        = string

  validation {
    condition     = can(cidrhost(var.mi_ip_cidr, 0))
    error_message = "Debe ser un CIDR válido, por ejemplo 190.64.10.20/32."
  }
}

variable "dominio_base" {
  description = "Zona DNS del curso en deSEC. Cada grupo usa <grupo>.<dominio_base>."
  type        = string
  default     = "lab.jplorier.com"
}

variable "cantidad_tareas" {
  description = "Tareas ECS a mantener corriendo. Poner 0 para pausar el servicio sin destruirlo."
  type        = number
  default     = 1
}

variable "usar_roles_existentes" {
  description = "true en AWS Academy Learner Lab (usa LabRole y LabInstanceProfile); false en cuenta propia."
  type        = bool
  default     = false
}
