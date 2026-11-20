# Runbook: DynamoDB Hot-Partition Throttling & Cache Stampede

## Symptoms
* Spike in `ProvisionedThroughputExceededException` or `ThrottledRequests` on a high-volume merchant settlement key (`GSI1PK = MERCHANT#BIG_RETAILER`).

## Diagnostic Steps
1. Enable **Amazon CloudWatch Contributor Insights** on `finpay-ledger-transactions` to identify the exact throttled partition key.
2. Check Redis `keyspace_misses` metric to verify whether a simultaneous TTL expiration triggered a cache stampede back to DynamoDB.

## Mitigation
1. **Write Sharding:** Append a calculated suffix (`MERCHANT#BIG_RETAILER#0` through `#9`) to distribute writes across 10 physical partitions, scattering reads via parallel `Query` calls.
2. **Jittered TTLs:** Enforce `TTL = base_ttl + random(-15, +15)` in `ledger_engine.py` so keys expire asynchronously.

