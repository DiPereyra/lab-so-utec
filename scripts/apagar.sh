#!/usr/bin/env bash
# Apaga (stop) las instancias del grupo. Una instancia apagada no cobra horas
# de cómputo, pero SÍ cobra el disco EBS (poco). El NAT Gateway y el ALB
# siguen cobrando: al terminar la jornada, usar "tofu destroy".
#
# Uso:  ./scripts/apagar.sh [bastion|privada|todas]     (por defecto: todas)

source "$(dirname "$0")/comun.sh"

ROL="${1:-todas}"
validar_rol "$ROL"

IDS=$(ids_instancias "$ROL" "pending,running")
if [[ -z "$IDS" ]]; then
  echo "No hay instancias encendidas para '$ROL' en el grupo $GRUPO."
  exit 0
fi

echo "Apagando: $IDS"
# shellcheck disable=SC2086
aws ec2 stop-instances --instance-ids $IDS --output table \
  --query 'StoppingInstances[].[InstanceId,PreviousState.Name,CurrentState.Name]'
echo "Esperando a que estén en estado stopped..."
# shellcheck disable=SC2086
aws ec2 wait instance-stopped --instance-ids $IDS
echo "Apagadas."
