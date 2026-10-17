#!/usr/bin/env bash
# shellcheck shell=bash
# Funciones compartidas por los scripts de encendido y apagado.
# No se ejecuta solo: lo cargan los otros scripts con "source".

set -euo pipefail

# Los scripts se ejecutan desde la carpeta raíz del proyecto.
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

leer_tfvar() {
  # Lee una variable simple (nombre = "valor") de terraform.tfvars.
  sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\"\(.*\)\".*/\1/p" terraform.tfvars 2>/dev/null | head -n1
}

GRUPO="${GRUPO:-$(leer_tfvar grupo)}"
REGION="${AWS_REGION:-$(leer_tfvar region)}"
REGION="${REGION:-us-east-1}"
PERFIL="$(leer_tfvar perfil_aws)"
if [[ -n "$PERFIL" && -z "${AWS_PROFILE:-}" ]]; then
  export AWS_PROFILE="$PERFIL"
fi
export AWS_REGION="$REGION"

if [[ -z "$GRUPO" ]]; then
  echo "No encuentro el grupo. Definí grupo en terraform.tfvars o exportá GRUPO=..." >&2
  exit 1
fi

# Devuelve los IDs de las instancias del grupo, filtrando por la etiqueta Rol.
#   $1 = bastion | privada | todas
#   $2 = estados separados por coma (ej.: running,pending)
ids_instancias() {
  local rol="$1" estados="$2" filtro_rol=()
  if [[ "$rol" != "todas" ]]; then
    filtro_rol=("Name=tag:Rol,Values=$rol")
  fi
  aws ec2 describe-instances \
    --filters "Name=tag:Laboratorio,Values=lab-aws" \
              "Name=tag:Grupo,Values=$GRUPO" \
              "Name=instance-state-name,Values=$estados" \
              ${filtro_rol[@]+"${filtro_rol[@]}"} \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text
}

validar_rol() {
  case "$1" in
    bastion|privada|todas) ;;
    *) echo "Uso: $0 [bastion|privada|todas]" >&2; exit 1 ;;
  esac
}
