# =============================================================================
# Módulo "servicios" — variables de entrada
#
# Este módulo se entrega TERMINADO. No hace falta modificarlo para aprobar el
# laboratorio, pero sí hay que entender qué recibe y qué devuelve.
# =============================================================================

variable "nombre" {
  description = "Prefijo para nombrar todos los recursos (ej.: lab-grupo3). Solo minúsculas, números y guiones."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.nombre))
    error_message = "El nombre debe tener entre 3 y 20 caracteres: minúsculas, números o guiones."
  }
}

variable "vpc_id" {
  description = "ID de la VPC donde se crean el ALB, el servicio ECS y los security groups."
  type        = string
}

variable "subredes_publicas" {
  description = "IDs de las subredes públicas (al menos 2, en AZ distintas). Ahí vive el ALB."
  type        = list(string)

  validation {
    condition     = length(var.subredes_publicas) >= 2
    error_message = "Un ALB necesita subredes en al menos dos zonas de disponibilidad."
  }
}

variable "subredes_privadas" {
  description = "IDs de las subredes privadas. Ahí corren las tareas de ECS (sin IP pública)."
  type        = list(string)

  validation {
    condition     = length(var.subredes_privadas) >= 1
    error_message = "Se necesita al menos una subred privada."
  }
}

variable "dominio" {
  description = "Nombre DNS por el que se entra al ALB (ej.: grupo1.lab.jplorier.com). Las reglas del listener solo responden a este host."
  type        = string
}

# --- Sitio estático en S3 ----------------------------------------------------

variable "directorio_sitio" {
  description = "Carpeta local cuyo contenido se sube al bucket S3 como sitio web."
  type        = string
}

# --- Servicio ECS --------------------------------------------------------------

variable "imagen_contenedor" {
  description = "Imagen del contenedor. Por defecto nginx desde la galería pública de ECR."
  type        = string
  default     = "public.ecr.aws/nginx/nginx:stable-alpine"
}

variable "publicar_sitio" {
  description = "Si es true, el contenedor nginx descarga el sitio del bucket al arrancar y lo sirve en /ecs/. Ponerlo en false si se cambia la imagen (la nueva imagen tiene que responder en /ecs/)."
  type        = bool
  default     = true
}

variable "puerto_contenedor" {
  description = "Puerto en el que escucha el contenedor."
  type        = number
  default     = 80
}

variable "cpu_tarea" {
  description = "CPU de la tarea Fargate en unidades (256 = 0,25 vCPU). Es el mínimo y el más barato."
  type        = number
  default     = 256
}

variable "memoria_tarea" {
  description = "Memoria de la tarea Fargate en MiB. 512 es el mínimo para 256 de CPU."
  type        = number
  default     = 512
}

variable "arquitectura" {
  description = "Arquitectura de CPU de la tarea: X86_64 o ARM64 (ARM64 es más barato en Fargate)."
  type        = string
  default     = "ARM64"

  validation {
    condition     = contains(["X86_64", "ARM64"], var.arquitectura)
    error_message = "La arquitectura debe ser X86_64 o ARM64."
  }
}

variable "cantidad_tareas" {
  description = "Cantidad de tareas del servicio. Con 0 el servicio queda creado pero no consume Fargate."
  type        = number
  default     = 1
}

# --- IAM ---------------------------------------------------------------------

variable "usar_roles_existentes" {
  description = <<-EOT
    false: el módulo crea sus propios roles IAM (cuenta AWS propia).
    true : usa roles que ya existen en la cuenta (AWS Academy Learner Lab no
           permite crear roles; ahí existen LabRole y LabInstanceProfile).
  EOT
  type        = bool
  default     = false
}

variable "rol_existente_ecs" {
  description = "Nombre del rol existente para ejecutar tareas ECS (solo si usar_roles_existentes = true)."
  type        = string
  default     = "LabRole"
}

variable "perfil_instancia_existente" {
  description = "Nombre del instance profile existente para EC2 (solo si usar_roles_existentes = true)."
  type        = string
  default     = "LabInstanceProfile"
}
