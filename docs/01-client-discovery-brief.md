# Client Discovery Brief: FinPay Ledger Modernization

## 1. Client Context & Business Problem
**Client:** FinPay Corp (Mid-Market Payment Processor)  
**Current State:** A single-region monolithic PostgreSQL database experiences severe lock contention during peak settlement windows, high cross-AZ data transfer bills, and slow analytical reporting queries that degrade live payment latency.

## 2. Stakeholder Requirements & Constraints
* **Latency:** Payment authorization lookups must complete in **< 15ms (p99)**.
* **Compliance & Security:** Zero database subnets may have routes to an Internet Gateway (`0.0.0.0/0 -> igw`). All AWS API traffic must stay on the private AWS backbone.
* **Analytics:** Risk and compliance teams need daily batch aggregations across 500M+ historical transactions without impacting live OLTP throughput.
* **Team Enablement:** The client has 4 junior cloud engineers who will maintain the Terraform codebase post-handoff; strict guardrails and PR standards are mandatory.

## 3. Architectural Translation
1. **Decouple OLTP & OLAP:** Migrate transactional state to **Amazon DynamoDB** (On-Demand, Single-Table Design) and offload historical reporting to **Amazon Redshift** via S3 staging.
2. **Sub-Millisecond Read Layer:** Introduce **Amazon ElastiCache (Redis)** using a cache-aside pattern with TTL jitter to prevent cache stampedes.
3. **Private Backbone Networking:** Deploy **VPC Gateway Endpoints** (DynamoDB, S3) and **Interface Endpoints** (STS, CloudWatch, KMS) inside isolated subnets controlled by restrictive Security Groups and IAM Permission Boundaries.

