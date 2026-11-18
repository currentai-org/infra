terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  required_version = ">= 1.2"
}

provider "aws" {
  region = local.region
}

provider "aws" {
  alias  = "staging"
  region = local.backends.staging.region
}

provider "aws" {
  alias  = "prod"
  region = local.backends.prod.region
}
