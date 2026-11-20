# Junior Cloud Engineer Onboarding & Pull Request Rubric

## Purpose
This guide establishes clear architectural guardrails so junior engineers can ship Terraform and Python changes safely without introducing security regressions or unexpected AWS spend.

## Mandatory Pull Request Checklist (Reviewer & Author)
- [ ] **Zero Public Exposure:** Are all data stores (`DynamoDB`, `ElastiCache`, `Redshift`, `S3`) blocked from public internet access?
- [ ] **Least-Privilege IAM:** Does every IAM role avoid `"Action": "*"` and attach the `finpay-ledger-iam-boundary` permission boundary?
- [ ] **Cost Guardrail:** Are high-cost managed clusters (`enable_managed_analytics = true`) gated behind explicit environment variables so dev/CI runs cost $0?
- [ ] **LocalStack Verification:** Does `pytest tests/` pass cleanly against `docker compose up -d`?

## Pair-Programming & Mentorship Cadence
1. **First Ticket ("Good First Issue"):** Add a new CloudWatch Alarm or DynamoDB TTL attribute using an existing module pattern.
2. **Architecture Walkthrough:** Every PR modifying `networking-security` includes a 15-minute whiteboard review tracing packet flow and IAM policy evaluation order.

