#!/bin/bash
# crear-vpc.sh — crea la VPC del laboratorio: una subred pública, una privada,
# el Internet Gateway y sus tablas de rutas. Todo lleva la etiqueta Proyecto=lab.
# Uso: bash crear-vpc.sh        (con la sesión de aws login abierta)
set -euo pipefail
export AWS_PAGER=""

# Etiquetas para --tag-specifications: tipo de recurso y nombre
etiquetas() { echo "ResourceType=$1,Tags=[{Key=Name,Value=$2},{Key=Proyecto,Value=lab}]"; }

if [[ $(aws ec2 describe-vpcs --filters Name=tag:Name,Values=lab-vpc --query 'length(Vpcs)') != 0 ]]; then
  echo "Ya existe una lab-vpc. Si quieres empezar de cero: bash borrar-vpc.sh" >&2
  exit 1
fi

# Una zona donde haya t3.small (no todas las zonas tienen todos los tipos)
AZ=$(aws ec2 describe-instance-type-offerings --location-type availability-zone \
  --filters Name=instance-type,Values=t3.small \
  --query 'sort(InstanceTypeOfferings[].Location)[0]' --output text)

VPC=$(aws ec2 create-vpc --cidr-block 10.20.0.0/16 \
  --tag-specifications "$(etiquetas vpc lab-vpc)" --query Vpc.VpcId --output text)
aws ec2 wait vpc-available --vpc-ids "$VPC"
aws ec2 modify-vpc-attribute --vpc-id "$VPC" --enable-dns-hostnames '{"Value":true}'

PUB=$(aws ec2 create-subnet --vpc-id "$VPC" --cidr-block 10.20.1.0/24 --availability-zone "$AZ" \
  --tag-specifications "$(etiquetas subnet lab-publica)" --query Subnet.SubnetId --output text)
PRIV=$(aws ec2 create-subnet --vpc-id "$VPC" --cidr-block 10.20.2.0/24 --availability-zone "$AZ" \
  --tag-specifications "$(etiquetas subnet lab-privada)" --query Subnet.SubnetId --output text)
aws ec2 modify-subnet-attribute --subnet-id "$PUB" --map-public-ip-on-launch

IGW=$(aws ec2 create-internet-gateway --tag-specifications "$(etiquetas internet-gateway lab-igw)" \
  --query InternetGateway.InternetGatewayId --output text)
aws ec2 attach-internet-gateway --internet-gateway-id "$IGW" --vpc-id "$VPC"

RT_PUB=$(aws ec2 create-route-table --vpc-id "$VPC" \
  --tag-specifications "$(etiquetas route-table lab-rutas-publica)" --query RouteTable.RouteTableId --output text)
aws ec2 create-route --route-table-id "$RT_PUB" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW" >/dev/null
aws ec2 associate-route-table --route-table-id "$RT_PUB" --subnet-id "$PUB" >/dev/null

RT_PRIV=$(aws ec2 create-route-table --vpc-id "$VPC" \
  --tag-specifications "$(etiquetas route-table lab-rutas-privada)" --query RouteTable.RouteTableId --output text)
aws ec2 associate-route-table --route-table-id "$RT_PRIV" --subnet-id "$PRIV" >/dev/null

echo "lab-vpc lista en $AZ:"
echo "  VPC=$VPC  IGW=$IGW"
echo "  PUB=$PUB  (rutas $RT_PUB: local + 0.0.0.0/0 → IGW)"
echo "  PRIV=$PRIV  (rutas $RT_PRIV: solo local)"
