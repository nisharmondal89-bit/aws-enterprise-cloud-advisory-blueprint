import json
import random
import time
from decimal import Decimal
import boto3
import redis


class FinPayLedgerEngine:
    def __init__(
        self,
        table_name: str = "finpay-ledger-transactions",
        staging_bucket: str = "finpay-ledger-olap-staging-lake",
        aws_endpoint: str | None = "http://localhost:4566",
        redis_host: str = "localhost",
        redis_port: int = 6379,
    ):
        self.table_name = table_name
        self.staging_bucket = staging_bucket

        session_kwargs = {"region_name": "us-east-1"}
        if aws_endpoint:
            session_kwargs.update(
                {
                    "endpoint_url": aws_endpoint,
                    "aws_access_key_id": "test",
                    "aws_secret_access_key": "test",
                }
            )

        self.dynamodb = boto3.resource("dynamodb", **session_kwargs)
        self.s3 = boto3.client("s3", **session_kwargs)
        self.table = self.dynamodb.Table(table_name)
        self.cache = redis.Redis(host=redis_host, port=redis_port, decode_responses=True)

    def record_transaction(
        self, account_id: str, tx_id: str, merchant_id: str, amount: str, status: str = "AUTHORIZED"
    ) -> dict:
        """Writes an immutable ledger entry to DynamoDB and invalidates stale balance cache."""
        timestamp = int(time.time())
        item = {
            "PK": f"ACCT#{account_id}",
            "SK": f"TX#{timestamp}#{tx_id}",
            "GSI1PK": f"MERCHANT#{merchant_id}",
            "AccountId": account_id,
            "TransactionId": tx_id,
            "MerchantId": merchant_id,
            "Amount": Decimal(amount),
            "Status": status,
            "CreatedAt": timestamp,
        }
        self.table.put_item(Item=item)
        # Invalidate cache-aside key on write to guarantee read consistency
        self.cache.delete(f"acct:latest:{account_id}")
        return item

    def get_latest_account_activity(self, account_id: str) -> tuple[list[dict], str]:
        """Cache-aside read pattern using ElastiCache Redis with TTL jitter."""
        cache_key = f"acct:latest:{account_id}"
        cached_payload = self.cache.get(cache_key)
        if cached_payload:
            return json.loads(cached_payload), "CACHE_HIT"

        response = self.table.query(
            KeyConditionExpression="PK = :pk AND begins_with(SK, :prefix)",
            ExpressionAttributeValues={":pk": f"ACCT#{account_id}", ":prefix": "TX#"},
            ScanIndexForward=False,
            Limit=10,
        )
        items = [
            {k: (str(v) if isinstance(v, Decimal) else v) for k, v in row.items()}
            for row in response.get("Items", [])
        ]

        # Add +/- 15s jitter to prevent simultaneous cache expiration (cache stampede)
        ttl_with_jitter = 60 + random.randint(-15, 15)
        self.cache.setex(cache_key, ttl_with_jitter, json.dumps(items))
        return items, "CACHE_MISS_DB_FETCH"

    def stage_batch_for_redshift_olap(self, batch_id: str, records: list[dict]) -> str:
        """Stages JSON-lines ledger records in S3 and returns the Redshift COPY command."""
        s3_key = f"redshift-ingest/dt=2026-11-19/{batch_id}.jsonl"
        ndjson_body = "\n".join(json.dumps(r, default=str) for r in records)
        self.s3.put_object(Bucket=self.staging_bucket, Key=s3_key, Body=ndjson_body.encode("utf-8"))

        redshift_copy_sql = f"""
        COPY compliance.fact_transactions
        FROM 's3://{self.staging_bucket}/{s3_key}'
        IAM_ROLE 'arn:aws:iam::123456789012:role/FinPayRedshiftIngestRole'
        FORMAT AS JSON 'auto'
        TIMEFORMAT 'epochsecs';
        """.strip()
        return redshift_copy_sql

