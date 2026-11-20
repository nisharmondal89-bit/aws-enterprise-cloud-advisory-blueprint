variable "project_name" { type = string }
variable "isolated_subnet_ids" { type = list(string) }
variable "enable_managed_analytics" {
  type        = bool
  default     = false
  description = "Set true in AWS prod; false in LocalStack Community validation"
}

# 1. OLTP Transactional Ledger: Amazon DynamoDB (Single-Table Design)
resource "aws_dynamodb_table" "ledger" {
  name         = "${var.project_name}-transactions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  attribute {
    name = "GSI1PK"
    type = "S"
  }

  global_secondary_index {
    name            = "MerchantSettlementIndex"
    hash_key        = "GSI1PK"
    range_key       = "SK"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }
}

# 2. OLAP Staging Lake: S3 Bucket for Redshift COPY Ingestion
resource "aws_s3_bucket" "analytics_staging" {
  bucket        = "${var.project_name}-olap-staging-lake"
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "staging_sse" {
  bucket = aws_s3_bucket.analytics_staging.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "staging_block" {
  bucket                  = aws_s3_bucket.analytics_staging.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 3. Sub-Millisecond Cache: ElastiCache Redis Replication Group (AWS Prod)
resource "aws_elasticache_subnet_group" "redis" {
  count      = var.enable_managed_analytics ? 1 : 0
  name       = "${var.project_name}-redis-subnets"
  subnet_ids = var.isolated_subnet_ids
}

resource "aws_elasticache_replication_group" "ledger_cache" {
  count                      = var.enable_managed_analytics ? 1 : 0
  replication_group_id       = "${var.project_name}-redis"
  description                = "Cache-aside balance and authorization lookup cluster"
  node_type                  = "cache.r7g.large"
  num_cache_clusters         = 2
  automatic_failover_enabled = true
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  subnet_group_name          = aws_elasticache_subnet_group.redis[0].name
}

# 4. OLAP Data Warehouse: Redshift Serverless Namespace (AWS Prod)
resource "aws_redshiftserverless_namespace" "compliance_olap" {
  count          = var.enable_managed_analytics ? 1 : 0
  namespace_name = "${var.project_name}-olap"
  db_name        = "finpay_compliance"
}

output "dynamodb_table_name" { value = aws_dynamodb_table.ledger.name }
output "staging_bucket_name" { value = aws_s3_bucket.analytics_staging.id }

