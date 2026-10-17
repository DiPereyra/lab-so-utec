#!/usr/bin/env bash
# Enciende las instancias del grupo y regenera claves/ssh_config con la nueva
# IP pública del bastión (la IP pública cambia en cada encendido).
#
# Uso:  ./scripts/encender.sh [bastion|privada|todas]     (por defecto: todas)

source "$(dirname "$0")/comun.sh"

ROL="${1:-todas}"
validar_rol "$ROL"

IDS=$(ids_instancias "$ROL" "stopped")
if [[ -z "$IDS" ]]; then
  echo "No hay instancias apagadas para '$ROL' en el grupo $GRUPO."
else
  echo "Encendiendo: $IDS"
  # shellcheck disable=SC2086
  aws ec2 start-instances --instance-ids $IDS --output table \
    --query 'StartingInstances[].[InstanceId,PreviousState.Name,CurrentState.Name]'
  echo "Esperando a que estén en estado running..."
  # shellcheck disable=SC2086
  aws ec2 wait instance-running --instance-ids $IDS
fi

echo "Actualizando claves/ssh_config con las IP actuales..."
tofu apply -auto-approve -target=local_file.ssh_config >/dev/null
tofu output ip_publica_bastion 2>/dev/null || true

echo "Listo. Esperá ~30 s a que arranque sshd y conectate con:"
echo "  ssh -F claves/ssh_config lab-bastion"
