# Terraform Infrastructure

Modular Terraform layout with isolated state per environment:

```text
terraform/
├── modules/
│   ├── vpc/          # VPC, IGW, 2 public + 2 private subnets, NAT GW(s), route tables
│   ├── eks/          # EKS Auto Mode cluster, OIDC, Pod Identity, ALB Controller role
│   ├── rds/          # KMS-encrypted Aurora PostgreSQL Serverless v2 cluster
│   ├── redis/        # ElastiCache Serverless Valkey (and optional non-cluster Redis)
│   ├── secrets-iam/  # Auto-generated repo secrets, Doppler data sources, ESO & Holmes IRSA
│   └── addons/       # Argo CD + External Secrets Operator Helm releases
└── environments/
    ├── staging/      # eu-north-1, single NAT GW, 1 RDS instance, deletion_protection = false
    └── production/   # eu-west-3, Multi-AZ NAT GW, 2 RDS instances, deletion_protection = true
```

## Prerequisites

1. **Remote State S3 Bucket & DynamoDB Lock Table** (one per environment/region):
   - Staging (`eu-north-1`): bucket `staging-terraform-state-currentai`, table `terraform-state` (or update `environments/staging/backend.tf`).
   - Production (`eu-west-3`): bucket `prod-terraform-state-currentai`, table `terraform-state` (or update `environments/production/backend.tf`).
2. **Doppler-synced AWS Secrets Manager secrets**:
   Before running `terraform plan` / `apply`, ensure Doppler has synced these secrets into the target region's AWS Secrets Manager:
   - `/agent-service`
   - `/router-aipotluck-org`
   - `/pangolin`

## Usage

```bash
# Staging (eu-north-1)
cd terraform/environments/staging
terraform init
terraform plan
terraform apply

# Production (eu-west-3)
cd terraform/environments/production
terraform init
terraform plan
terraform apply
```
