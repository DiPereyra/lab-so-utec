terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    # DNS gratuito de deSEC (desec.io): crea el subdominio de cada grupo.
    desec = {
      source  = "valodim/desec"
      version = "~> 0.6"
    }
  }

  # El estado (terraform.tfstate) queda en esta carpeta, en la máquina de quien
  # ejecuta "tofu apply". Consecuencias:
  #   - Un solo integrante del grupo aplica los cambios (o se pasan el estado).
  #   - NUNCA se sube el estado a git: contiene las claves privadas generadas.
}
