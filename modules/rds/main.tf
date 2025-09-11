resource "aws_db_subnet_group" "this" {
  count       = var.existing_db_subnet_group_name == "" ? 1 : 0
  name        = "${var.namespace}-db-subnet-group"
  description = "DB subnet group for ${var.namespace}"
  subnet_ids  = var.db_subnet_ids
  lifecycle { create_before_destroy = true }
}

resource "aws_security_group" "rds" {
  count  = var.existing_rds_security_group_id == "" ? 1 : 0
  name   = "${var.namespace}-rds-sg"
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.namespace}-rds-sg" }
}

// Resolve which names/ids to use
locals {
  db_subnet_group_name = var.existing_db_subnet_group_name != "" ? var.existing_db_subnet_group_name : aws_db_subnet_group.this[0].name
  rds_sg_id            = var.existing_rds_security_group_id != "" ? var.existing_rds_security_group_id : aws_security_group.rds[0].id
}

// Ensure your DB instance uses the resolved values
resource "aws_db_instance" "mariadb" {
  identifier             = "${var.namespace}-mariadb"
  engine                 = "mariadb"
  engine_version         = "10.6"
  instance_class         = var.instance_class
  allocated_storage      = 20
  username               = var.db_username
  password               = var.db_password
  db_name                = var.db_name
  port                   = 3306
  multi_az               = var.multi_az
  skip_final_snapshot    = true
  deletion_protection    = false
  db_subnet_group_name   = local.db_subnet_group_name
  vpc_security_group_ids = concat([local.rds_sg_id], var.allowed_security_group_ids)
  publicly_accessible    = false
}
