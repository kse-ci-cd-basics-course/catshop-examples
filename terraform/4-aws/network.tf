# A VPC is REGIONAL and a subnet is ZONAL. That one sentence is most of the
# difference from Google, where the VPC is global and the subnet covers the
# whole region.
#
# The consequence shows up immediately: anything that wants to be highly
# available needs a subnet per zone, declared by you.

resource "aws_vpc" "main" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

# TWO. An Application Load Balancer refuses to be created with fewer, and the
# error arrives at apply rather than at plan.
resource "aws_subnet" "public" {
  count                   = length(var.zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = var.zones[count.index]
  map_public_ip_on_launch = true
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# There is deliberately NO aws_nat_gateway here. It is ~$32 a month PER ZONE
# plus data processing, so the highly-available version costs ~$64 before a
# single byte moves. Public subnets and an internet gateway cost nothing. On
# Google the equivalent is one Cloud NAT per region, ~$33.

# A security group is STATEFUL and attaches to an interface. The Google
# equivalent is a firewall rule on the network, matched by tag.
resource "aws_security_group" "lb" {
  name   = "${var.name}-lb"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# And here is the real difference. The health check comes from the load
# balancer itself, because an ALB has network interfaces INSIDE these subnets.
# On Google it comes from two fixed external ranges, because the load balancer
# is not in your network at all.
resource "aws_security_group" "app" {
  name   = "${var.name}-app"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.lb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db" {
  name   = "${var.name}-db"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }
}
