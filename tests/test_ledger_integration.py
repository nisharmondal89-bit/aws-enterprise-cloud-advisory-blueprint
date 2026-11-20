from decimal import Decimal
import os
import sys

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SERVICE_DIR = os.path.join(ROOT_DIR, "src", "ledger-service")
if SERVICE_DIR not in sys.path:
    sys.path.insert(0, SERVICE_DIR)

from ledger_engine import FinPayLedgerEngine


def test_end_to_end_oltp_cache_and_olap_pipeline():
    engine = FinPayLedgerEngine()

    # 1. Write transaction to DynamoDB
    tx = engine.record_transaction(
        account_id="ACC-9001",
        tx_id="TX-1001",
        merchant_id="M-77",
        amount="249.50",
    )
    assert tx["PK"] == "ACCT#ACC-9001"

    # 2. First read should miss Redis and query DynamoDB
    records_first, source_first = engine.get_latest_account_activity("ACC-9001")
    assert source_first == "CACHE_MISS_DB_FETCH"
    assert len(records_first) >= 1
    assert Decimal(next(iter(records_first))["Amount"]) == Decimal("249.50")

    # 3. Second read should serve directly from ElastiCache Redis
    records_second, source_second = engine.get_latest_account_activity("ACC-9001")
    assert source_second == "CACHE_HIT"
    assert next(iter(records_second))["TransactionId"] == "TX-1001"

    # 4. Stage analytical batch to S3 for Redshift ingestion
    copy_sql = engine.stage_batch_for_redshift_olap("batch-001", records_second)
    assert "COPY compliance.fact_transactions" in copy_sql
    assert "s3://finpay-ledger-olap-staging-lake/" in copy_sql
