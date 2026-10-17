#!/usr/bin/env bash
# Muestra qué recursos del grupo están consumiendo crédito ahora mismo.
#
# Uso:  ./scripts/estado.sh

source "$(dirname "$0")/comun.sh"

FILTROS=("Name=tag:Laboratorio,Values=lab-aws" "Name=tag:Grupo,Values=$GRUPO")

echo "== Instancias EC2 (grupo $GRUPO, región $REGION) =="
aws ec2 describe-instances --filters "${FILTROS[@]}" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`]|[0].Value,InstanceType,State.Name,PublicIpAddress,PrivateIpAddress]' \
  --output table

echo "== NAT Gateways (cobran por hora mientras existan) =="
aws ec2 describe-nat-gateways --filter "${FILTROS[@]}" "Name=state,Values=pending,available" \
  --query 'NatGateways[].[NatGatewayId,State,SubnetId]' --output table

echo "== Load balancers del grupo (cobran por hora mientras existan) =="
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?starts_with(LoadBalancerName, 'lab-$GRUPO-')].[LoadBalancerName,State.Code,DNSName]" \
  --output table

echo "== Servicio ECS =="
aws ecs describe-services --cluster "lab-$GRUPO-cluster" --services "lab-$GRUPO-web" \
  --query 'services[].[serviceName,status,desiredCount,runningCount]' --output table 2>/dev/null \
  || echo "(no existe)"
