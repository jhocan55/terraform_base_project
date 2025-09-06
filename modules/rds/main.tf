resource "aws_db_subnet_group" "this" {
  name        = "${var.namespace}-db-subnet-group"
  description = "DB subnet group for ${var.namespace}"
  subnet_ids  = var.db_subnet_ids
  lifecycle { create_before_destroy = true }
}

resource "aws_security_group" "rds" {
  name   = "${var.namespace}-rds-sg"
  vpc_id = var.vpc_id

  # Allow from EKS SGs
  dynamic "ingress" {
    for_each = var.allowed_security_group_ids
    content {
      from_port       = 3306
      to_port         = 3306
      protocol        = "tcp"
      security_groups = [ingress.value]
      description     = "Access from EKS"
    }
  }

  # Optional: allow from CIDRs
  dynamic "ingress" {
    for_each = var.allowed_cidr_blocks
    content {
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "VPC access"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

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
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
}
