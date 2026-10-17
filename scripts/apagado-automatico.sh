#!/usr/bin/env bash
# Programa el apagado de las DOS instancias dentro de N minutos, como red de
# seguridad por si el grupo se olvida de apagarlas.
#
# Funciona porque las instancias tienen
#   instance_initiated_shutdown_behavior = "stop"
# entonces "shutdown" dentro del sistema operativo equivale a un stop de EC2.
#
# Uso:  ./scripts/apagado-automatico.sh [minutos]     (por defecto: 120)
# Cancelar: entrar a cada instancia y ejecutar "sudo shutdown -c"

source "$(dirname "$0")/comun.sh"

MINUTOS="${1:-120}"
if ! [[ "$MINUTOS" =~ ^[0-9]+$ ]]; then
  echo "Uso: $0 [minutos]" >&2
  exit 1
fi

for host in lab-bastion lab-privada; do
  echo "Programando apagado de $host en $MINUTOS minutos..."
  ssh -F claves/ssh_config "$host" "sudo shutdown -h +$MINUTOS"
done
