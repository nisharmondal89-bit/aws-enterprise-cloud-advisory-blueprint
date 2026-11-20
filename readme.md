# AWS Enterprise Cloud Advisory Blueprint: FinTech Ledger Modernization

[![Terraform Validate & Checkov](https://github.com)](https://github.com)

## Executive Overview
This repository simulates a complete end-to-end **Enterprise Cloud Advisory & Delivery Engagement** for a high-throughput payment processing platform migrating from a monolithic relational database to a zero-trust, purpose-built AWS architecture.


---

## Architecture Mapping to Enterprise Requirements

| Advisory Domain | Implementation in This Repository | Location |
| :--- | :--- | :--- |
| **Client Discovery & Trade-offs** | Translating business SLAs (99.99% availability, PCI-DSS isolation, sub-15ms reads) into technical Architecture Decision Records (ADRs). | `docs/01-client-discovery-brief.md`<br>`docs/02-adr/` |
| **Advanced Networking & Security** | Multi-AZ 3-tier VPC, isolated data subnets, VPC Gateway/Interface Endpoints (eliminating NAT data transfer exposure), NACLs, and least-privilege IAM boundaries. | `terraform/modules/networking-security/` |
| **Purpose-Built AWS Databases** | **DynamoDB** (Single-Table OLTP ledger), **ElastiCache Redis** (cache-aside session/balance reads), and **Redshift** (OLAP compliance & fraud analytics). | `terraform/modules/purpose-built-data/`<br>`src/ledger-service/` |
| **Network & Platform Troubleshooting** | Production Root Cause Analysis (RCA) runbooks for VPC routing blackholes, EKS CNI IP exhaustion, and DynamoDB hot-partition throttling. | `docs/03-troubleshooting-runbooks/` |
| **Mentorship & Delivery Standards** | Junior engineer onboarding guide, Terraform PR review rubric, and standardized module guardrails. | `docs/04-junior-engineer-onboarding/` |

---

## Quickstart: Clone & Run Locally

Anyone cloning this repository can validate the Terraform infrastructure and run the Python microservice locally using **Docker** and **LocalStack**:

```bash
# 1. Start local AWS cloud emulation (DynamoDB, VPC, IAM, S3) & Redis
docker compose up -d

# 2. Deploy the Terraform blueprint against LocalStack
cd terraform/environments/prod-blueprint
terraform init
terraform apply -var-file="localstack.tfvars" -auto-approve

# 3. Run the Python ledger service & integration tests
cd ../../../
python3 -m venv .venv && source .venv/bin/activate
pip install -r src/ledger-service/requirements.txt
pytest tests/
```

