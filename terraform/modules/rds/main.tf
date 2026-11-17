resource "aws_kms_key" "db" {
  description             = "KMS key for ${var.env} Aurora PostgreSQL database encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name        = "${var.env}-${var.org}-db-kms-key"
    Environment = var.env
  }
}

resource "aws_kms_alias" "db" {
  name          = "alias/${var.env}-${var.org}-db-key"
  target_key_id = aws_kms_key.db.key_id
}

resource "aws_db_subnet_group" "db" {
  name        = "${var.env}-${var.org}-db-subnet-group"
  description = "Database subnet group in private subnets (${var.env})"
  subnet_ids  = var.private_subnet_ids

  tags = {
    Name        = "${var.env}-${var.org}-db-subnet-group"
    Environment = var.env
  }
}

resource "aws_security_group" "db" {
  name        = "${var.env}-${var.org}-db-sg"
  description = "Security group for Aurora PostgreSQL database (${var.env})"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow PostgreSQL traffic from EKS cluster pods/nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_cluster_security_group_id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.env}-${var.org}-db-sg"
    Environment = var.env
  }
}

resource "aws_iam_role" "rds_monitoring" {
  name = "${var.env}-${var.org}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.env}-${var.org}-rds-monitoring-role"
    Environment = var.env
  }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_rds_cluster" "this" {
  cluster_identifier                  = "${var.env}-${var.org}-db"
  engine                              = "aurora-postgresql"
  engine_version                      = var.engine_version
  engine_mode                         = "provisioned"
  database_name                       = null
  master_username                     = var.master_username
  master_password                     = var.master_password
  db_cluster_parameter_group_name     = "default.aurora-postgresql16"
  db_subnet_group_name                = aws_db_subnet_group.db.name
  vpc_security_group_ids              = [aws_security_group.db.id]
  storage_encrypted                   = true
  kms_key_id                          = aws_kms_key.db.arn
  deletion_protection                 = var.deletion_protection
  skip_final_snapshot                 = var.skip_final_snapshot
  final_snapshot_identifier           = var.skip_final_snapshot ? null : "${var.env}-${var.org}-db-final-snapshot"
  backup_retention_period             = var.backup_retention_period
  preferred_backup_window             = "03:33-04:03"
  preferred_maintenance_window        = "sun:09:00-sun:09:30"
  copy_tags_to_snapshot               = true
  iam_database_authentication_enabled = false
  monitoring_interval                 = 60
  monitoring_role_arn                 = aws_iam_role.rds_monitoring.arn
  enable_global_write_forwarding      = false
  enable_local_write_forwarding       = false

  performance_insights_enabled          = true
  performance_insights_kms_key_id       = aws_kms_key.db.arn
  performance_insights_retention_period = 7

  serverlessv2_scaling_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  tags = {
    Name        = "${var.env}-${var.org}-db"
    Environment = var.env
  }
}

resource "aws_rds_cluster_instance" "this" {
  count = var.instance_count

  cluster_identifier                    = aws_rds_cluster.this.id
  identifier                            = "${var.env}-${var.org}-db-instance-${count.index + 1}"
  instance_class                        = "db.serverless"
  engine                                = aws_rds_cluster.this.engine
  engine_version                        = aws_rds_cluster.this.engine_version
  db_subnet_group_name                  = aws_rds_cluster.this.db_subnet_group_name
  db_parameter_group_name               = "default.aurora-postgresql16"
  publicly_accessible                   = false
  auto_minor_version_upgrade            = true
  ca_cert_identifier                    = "rds-ca-rsa2048-g1"
  monitoring_interval                   = 60
  monitoring_role_arn                   = aws_iam_role.rds_monitoring.arn
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = aws_kms_key.db.arn
  performance_insights_retention_period = 7
  promotion_tier                        = count.index + 1

  tags = {
    Name        = "${var.env}-${var.org}-db-instance-${count.index + 1}"
    Environment = var.env
  }
}
