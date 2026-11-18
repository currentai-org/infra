resource "aws_security_group" "elasticache" {
  name        = "${var.env}-${var.org}-elasticache-sg"
  description = "Security group for ElastiCache (${var.env})"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow Valkey/Redis traffic from EKS cluster pods/nodes"
    from_port       = 6379
    to_port         = 6379
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
    Name        = "${var.env}-${var.org}-elasticache-sg"
    Environment = var.env
  }
}

resource "aws_elasticache_serverless_cache" "this" {
  count = var.enable_serverless_cache ? 1 : 0

  name                     = "${var.env}-${var.org}-cache"
  engine                   = "valkey"
  major_engine_version     = var.valkey_major_engine_version
  description              = "ElastiCache Serverless Valkey Cache for ${var.org} ${var.env}"
  daily_snapshot_time      = "03:00"
  snapshot_retention_limit = 0
  security_group_ids       = [aws_security_group.elasticache.id]
  subnet_ids               = var.private_subnet_ids

  tags = {
    Name        = "${var.env}-${var.org}-cache"
    Environment = var.env
  }
}

resource "aws_elasticache_subnet_group" "non_cluster" {
  count = var.enable_replication_group ? 1 : 0

  name        = "${var.env}-${var.org}-non-cluster-subnet-group"
  description = "Subnet group for non-cluster ElastiCache Redis (${var.env})"
  subnet_ids  = var.private_subnet_ids

  tags = {
    Name        = "${var.env}-${var.org}-non-cluster-subnet-group"
    Environment = var.env
  }
}

resource "aws_elasticache_replication_group" "non_cluster" {
  count = var.enable_replication_group ? 1 : 0

  replication_group_id       = "${var.env}-${var.org}-non-cluster"
  description                = "Non-cluster ElastiCache Redis (${var.env})"
  engine                     = "redis"
  engine_version             = "7.1"
  node_type                  = var.replication_group_node_type
  num_cache_clusters         = var.replication_group_num_cache_clusters
  parameter_group_name       = "default.redis7"
  port                       = 6379
  subnet_group_name          = aws_elasticache_subnet_group.non_cluster[0].name
  security_group_ids         = [aws_security_group.elasticache.id]
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auto_minor_version_upgrade = true

  tags = {
    Name        = "${var.env}-${var.org}-non-cluster-cache"
    Environment = var.env
  }
}
