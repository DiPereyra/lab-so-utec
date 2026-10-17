# =============================================================================
# PARTE 2 — Red: VPC, subredes, Internet Gateway, NAT Gateway y ruteo
#
# Objetivo: una VPC repartida en DOS zonas de disponibilidad (AZ). En cada AZ
# hay una subred PÚBLICA y una PRIVADA.
#
#                         Internet
#                            |
#                    [Internet Gateway]
#                            |
#   +------------------- VPC 10.20.0.0/16 -------------------+
#   |   AZ a                         AZ b                    |
#   |  publica-a 10.20.0.0/24       publica-b 10.20.1.0/24   |
#   |   [NAT GW] [bastion] [ALB]          [ALB]              |
#   |  privada-a 10.20.10.0/24      privada-b 10.20.11.0/24  |
#   |   [servidor privado] [ECS]          [ECS]              |
#   +--------------------------------------------------------+
#
# ¿Por qué dos AZ? Un Application Load Balancer EXIGE subredes en al menos dos
# zonas de disponibilidad. Además es la base de la alta disponibilidad.
#
# Qué hace pública a una subred: que su tabla de ruteo tenga una ruta
# 0.0.0.0/0 hacia un Internet Gateway. Nada más.
# Qué hace privada a una subred: que NO tenga esa ruta. Para que sus máquinas
# puedan SALIR a Internet (actualizar paquetes, descargar imágenes) se usa un
# NAT Gateway ubicado en una subred pública.
#
# La mitad pública ya está resuelta como ejemplo. La mitad privada la
# completan ustedes siguiendo los pasos TODO.
#
# IMPORTANTE: respeten los nombres de los recursos (aws_subnet.privada,
# aws_route_table_association.privada, etc.). Otros archivos los usan.
# =============================================================================

# Lista de AZ disponibles en la región; nos quedamos con las dos primeras.
data "aws_availability_zones" "disponibles" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.disponibles.names, 0, 2)
}

# --- VPC -------------------------------------------------------------------------

resource "aws_vpc" "principal" {
  cidr_block           = var.cidr_vpc
  enable_dns_support   = true # Resolver DNS de AWS dentro de la VPC
  enable_dns_hostnames = true # Nombres DNS para las instancias
  tags                 = { Name = "lab-${var.grupo}-vpc" }
}

# Puerta de la VPC hacia Internet (entrada y salida). Una por VPC, sin costo.
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.principal.id
  tags   = { Name = "lab-${var.grupo}-igw" }
}

# --- Subredes públicas (EJEMPLO RESUELTO) -----------------------------------------

# count = 2 crea dos copias del recurso: aws_subnet.publica[0] y [1].
# cidrsubnet("10.20.0.0/16", 8, n) devuelve la subred /24 número n:
#   n = 0 -> 10.20.0.0/24      n = 1 -> 10.20.1.0/24
# Pruébenlo en la consola interactiva:  tofu console
#   > cidrsubnet("10.20.0.0/16", 8, 10)
resource "aws_subnet" "publica" {
  count                   = 2
  vpc_id                  = aws_vpc.principal.id
  availability_zone       = local.azs[count.index]
  cidr_block              = cidrsubnet(var.cidr_vpc, 8, count.index)
  map_public_ip_on_launch = true # Las instancias reciben IP pública automáticamente
  tags                    = { Name = "lab-${var.grupo}-publica-${substr(local.azs[count.index], -1, 1)}" }
}

# Tabla de ruteo pública: todo lo que no es de la VPC sale por el IGW.
# (La ruta "local" 10.20.0.0/16 la agrega AWS sola en todas las tablas.)
resource "aws_route_table" "publica" {
  vpc_id = aws_vpc.principal.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "lab-${var.grupo}-rt-publica" }
}

# Asociar cada subred pública con la tabla pública.
resource "aws_route_table_association" "publica" {
  count          = 2
  subnet_id      = aws_subnet.publica[count.index].id
  route_table_id = aws_route_table.publica.id
}

# =============================================================================
# A COMPLETAR: mitad privada
# Descomenten cada bloque (sacar el "# " del principio) y reemplacen los ???.
# Después de cada paso:  tofu fmt && tofu validate && tofu plan
# =============================================================================

# --- TODO 2.1: subredes privadas ------------------------------------------------
# Dos subredes, una por AZ, con los rangos 10.20.10.0/24 y 10.20.11.0/24.
# Pistas:
#   - ¿Qué número n le pasan a cidrsubnet para obtener 10.20.10.0/24? ¿Y la segunda?
#   - ¿Tiene que estar map_public_ip_on_launch? ¿Con qué valor? (el valor por
#     defecto es false)
#
# resource "aws_subnet" "privada" {
#   count             = 2
#   vpc_id            = aws_vpc.principal.id
#   availability_zone = local.azs[count.index]
#   cidr_block        = cidrsubnet(var.cidr_vpc, 8, ???)
#   tags              = { Name = "lab-${var.grupo}-privada-${substr(local.azs[count.index], -1, 1)}" }
# }

# --- TODO 2.2: IP elástica para el NAT --------------------------------------------
# El NAT Gateway necesita una IP pública fija: una Elastic IP (EIP).
#
# resource "aws_eip" "nat" {
#   domain = "vpc"
#   tags   = { Name = "lab-${var.grupo}-eip-nat" }
# }

# --- TODO 2.3: NAT Gateway --------------------------------------------------------
# Pregunta clave: ¿en qué subred va el NAT, pública o privada? ¿Por qué?
# El NAT es el recurso MÁS CARO del laboratorio (se cobra por hora aunque no
# pase tráfico). Usamos uno solo, en la AZ "a". En producción se pone uno por AZ.
#
# resource "aws_nat_gateway" "nat" {
#   allocation_id = aws_eip.nat.id
#   subnet_id     = ???                    # ej.: aws_subnet.XXXX[0].id
#   tags          = { Name = "lab-${var.grupo}-nat" }
#
#   # Dependencia explícita: el NAT no funciona sin el IGW en la VPC.
#   depends_on = [aws_internet_gateway.igw]
# }

# --- TODO 2.4: tabla de ruteo privada -------------------------------------------
# Igual que la pública, pero la ruta por defecto apunta al NAT.
# Atención: el atributo NO es gateway_id sino nat_gateway_id.
#
# resource "aws_route_table" "privada" {
#   vpc_id = aws_vpc.principal.id
#
#   route {
#     cidr_block     = "0.0.0.0/0"
#     nat_gateway_id = ???
#   }
#
#   tags = { Name = "lab-${var.grupo}-rt-privada" }
# }

# --- TODO 2.5: asociaciones ---------------------------------------------------------
# Escriban ustedes el recurso aws_route_table_association "privada" para las
# dos subredes privadas, copiando el modelo de las públicas.
