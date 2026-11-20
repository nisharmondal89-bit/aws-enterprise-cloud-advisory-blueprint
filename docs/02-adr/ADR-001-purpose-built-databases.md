# ADR-001: Purpose-Built Database Selection (DynamoDB, ElastiCache, Redshift)


## Context
FinPay's monolithic PostgreSQL instance suffers CPU saturation during settlement windows because high-concurrency OLTP writes compete directly with long-running compliance `GROUP BY` queries.

## Decision
Decompose data storage by access pattern:
1. **Amazon DynamoDB (Single-Table Design):** Handles high-velocity payment authorizations (`PK = ACCT#<id>`, `SK = TX#<ts>#<id>`) with predictable single-digit millisecond write latency and On-Demand scaling.
2. **Amazon ElastiCache for Redis:** Absorbs bursty balance/status reads via a cache-aside pattern with randomized TTL jitter (`60s ± 15s`) to eliminate stampedes.
3. **Amazon Redshift Serverless:** Receives micro-batched NDJSON files from S3 via `COPY` commands to isolate heavy compliance aggregations from live payment traffic.

## Trade-offs & Consequences
* **Eventual Consistency on Analytics:** Compliance dashboards lag real-time OLTP transactions by ~5 minutes (acceptable per stakeholder SLA).
* **Schema Rigidity:** Access patterns must be modeled upfront in DynamoDB; ad-hoc queries are strictly routed to Redshift.

