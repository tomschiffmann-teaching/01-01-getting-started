# ---------------------------------------------------------------
# Netzwerk
# ---------------------------------------------------------------

# Das VPC: unser eigenes, abgeschottetes Netzwerk
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "${var.vorname}-vpc"
  }
}

# Das Internet Gateway: die Tür vom VPC ins Internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.vorname}-igw"
  }
}

# Das Subnetz: ein Teilbereich des VPCs in einer Availability Zone
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.vorname}-public-subnet"
  }
}

# Die Route Table: Alles, was nicht ins VPC gehört, geht zum Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.vorname}-public-rt"
  }
}

# Die Route Table mit dem Subnetz verbinden – erst das macht es "öffentlich"
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
