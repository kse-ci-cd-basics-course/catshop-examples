# RDS lives in YOUR subnets. There is no peering and no service-networking
# connection, because the database is simply inside the network you declared —
# which is the one place AWS is simpler than Google here.
#
# The price of that simplicity is the subnet group: another object that exists
# only to say "these subnets, in these zones".

resource "aws_db_subnet_group" "main" {
  name       = "${var.name}-db"
  subnet_ids = aws_subnet.public[*].id
}

resource "aws_db_instance" "main" {
  identifier             = "${var.name}-db"
  engine                 = "postgres"
  engine_version         = "16"
  instance_class         = "db.t4g.micro"
  allocated_storage      = 20
  db_name                = "catshop"
  username               = "catshop"
  password               = random_password.db.result
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]

  # Both of these are wrong for production and right for something you intend
  # to take down again.
  skip_final_snapshot = true
  publicly_accessible = false
}
