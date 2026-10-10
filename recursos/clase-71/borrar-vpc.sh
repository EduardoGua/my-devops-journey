#!/bin/bash
# borrar-vpc.sh — borra la lab-vpc y todo lo que tenga dentro, en el orden que
# AWS exige: instancias, NAT Gateways, IP elásticas, endpoints, tablas de rutas,
# subredes, Internet Gateway, security groups, NACLs y, por último, la VPC.
# Uso: bash borrar-vpc.sh
set -uo pipefail
export AWS_PAGER=""

# Algunas dependencias tardan unos segundos en soltarse: reintenta antes de rendirte
reintentar() { for _ in 1 2 3 4 5 6; do "$@" 2>/dev/null && return 0; sleep 5; done; "$@"; }

VPC=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=lab-vpc --query 'Vpcs[0].VpcId' --output text)
if [[ -z $VPC || $VPC == None ]]; then echo "No hay ninguna lab-vpc: nada que borrar."; exit 0; fi
echo "Borrando $VPC…"
F="Name=vpc-id,Values=$VPC"

INST=$(aws ec2 describe-instances --filters "$F" Name=instance-state-name,Values=pending,running,stopping,stopped \
  --query 'Reservations[].Instances[].InstanceId' --output text)
if [[ -n $INST ]]; then
  aws ec2 terminate-instances --instance-ids $INST >/dev/null
  echo "  terminando instancias: $INST (puede tardar un par de minutos)"
  aws ec2 wait instance-terminated --instance-ids $INST
fi

NATS=$(aws ec2 describe-nat-gateways --filter "$F" Name=state,Values=pending,available \
  --query 'NatGateways[].NatGatewayId' --output text)
if [[ -n $NATS ]]; then
  for n in $NATS; do aws ec2 delete-nat-gateway --nat-gateway-id "$n" >/dev/null; done
  echo "  borrando NAT Gateways: $NATS (puede tardar un par de minutos)"
  aws ec2 wait nat-gateway-deleted --nat-gateway-ids $NATS
fi

for a in $(aws ec2 describe-addresses --filters Name=tag:Proyecto,Values=lab --query 'Addresses[].AllocationId' --output text); do
  reintentar aws ec2 release-address --allocation-id "$a" && echo "  IP elástica liberada: $a"
done

EPS=$(aws ec2 describe-vpc-endpoints --query "VpcEndpoints[?VpcId=='$VPC'].VpcEndpointId" --output text)
[[ -n $EPS ]] && aws ec2 delete-vpc-endpoints --vpc-endpoint-ids $EPS >/dev/null && echo "  endpoints borrados: $EPS"

# Las tablas de rutas propias se desasocian de sus subredes y se borran (la principal se va con la VPC)
for r in $(aws ec2 describe-route-tables --filters "$F" \
    --query 'RouteTables[?length(Associations[?Main==`true`]) == `0`].RouteTableId' --output text); do
  for a in $(aws ec2 describe-route-tables --route-table-ids "$r" \
      --query 'RouteTables[0].Associations[?!Main].RouteTableAssociationId' --output text); do
    aws ec2 disassociate-route-table --association-id "$a"
  done
  aws ec2 delete-route-table --route-table-id "$r" && echo "  tabla de rutas borrada: $r"
done

for s in $(aws ec2 describe-subnets --filters "$F" --query 'Subnets[].SubnetId' --output text); do
  reintentar aws ec2 delete-subnet --subnet-id "$s" && echo "  subred borrada: $s"
done

for i in $(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC" \
    --query 'InternetGateways[].InternetGatewayId' --output text); do
  aws ec2 detach-internet-gateway --internet-gateway-id "$i" --vpc-id "$VPC"
  aws ec2 delete-internet-gateway --internet-gateway-id "$i" && echo "  Internet Gateway borrado: $i"
done

# Los security groups pueden referenciarse entre sí: primero se vacían sus reglas de entrada
SGS=$(aws ec2 describe-security-groups --filters "$F" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text)
for g in $SGS; do
  REGLAS=$(aws ec2 describe-security-groups --group-ids "$g" --query 'SecurityGroups[0].IpPermissions' --output json)
  [[ $REGLAS != "[]" ]] && aws ec2 revoke-security-group-ingress --group-id "$g" --ip-permissions "$REGLAS" >/dev/null
done
for g in $SGS; do reintentar aws ec2 delete-security-group --group-id "$g" && echo "  security group borrado: $g"; done

for n in $(aws ec2 describe-network-acls --filters "$F" --query 'NetworkAcls[?IsDefault==`false`].NetworkAclId' --output text); do
  aws ec2 delete-network-acl --network-acl-id "$n" && echo "  NACL borrada: $n"
done

if reintentar aws ec2 delete-vpc --vpc-id "$VPC"; then
  echo "lab-vpc borrada."
else
  echo "No pude borrar $VPC: mira en la consola (VPC → Your VPCs → Resource map) qué queda dentro." >&2
  exit 1
fi
