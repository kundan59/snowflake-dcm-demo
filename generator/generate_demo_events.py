"""
generate_demo_events.py
Generates realistic, nested semi-structured e-commerce JSON orders.
Supports:
  1. Generating local JSON files (for manual inspection or PUT into stage).
  2. Direct upload to Azure Blob Storage (triggering Event Grid -> Snowpipe auto-ingest live).
  3. Direct upload to Snowflake internal stage using snowflake-connector-python.
"""

import os
import sys
import json
import random
import uuid
import argparse
from datetime import datetime, timezone

# Realistic categories and products for demonstration
CATALOG = {
    "Cloud Infrastructure": [
        ("ITM-101", "Snowpark Optimized Virtual Compute", 249.50),
        ("ITM-102", "Lakehouse High-IOPS Flash Storage", 120.00),
        ("ITM-103", "Apache Iceberg Metadata Accelerator", 185.00),
    ],
    "Analytics & AI": [
        ("ITM-201", "Cortex Generative Search License", 399.00),
        ("ITM-202", "Automated Feature Store Registry", 145.00),
        ("ITM-203", "Data Quality DMF Metric Monitor", 89.99),
    ],
    "DataOps & Governance": [
        ("ITM-301", "Data Lineage & Tagging Engine", 175.50),
        ("ITM-302", "Dynamic Masking Policy Controller", 99.00),
        ("ITM-303", "Zero-Copy Snapshot Orchestrator", 210.00),
    ]
}

REGIONS = ["EMEA", "APAC", "US", "LATAM"]
TIERS = ["BRONZE", "SILVER", "GOLD", "PLATINUM"]
PAYMENT_METHODS = ["CREDIT_CARD", "PAYPAL", "WIRE_TRANSFER", "APPLE_PAY"]
CITIES = {
    "EMEA": [("Frankfurt", "Germany"), ("London", "United Kingdom"), ("Paris", "France"), ("Amsterdam", "Netherlands")],
    "APAC": [("Singapore", "Singapore"), ("Tokyo", "Japan"), ("Sydney", "Australia"), ("Bangalore", "India")],
    "US": [("New York", "USA"), ("San Francisco", "USA"), ("Austin", "USA"), ("Chicago", "USA")],
    "LATAM": [("Sao Paulo", "Brazil"), ("Mexico City", "Mexico"), ("Bogota", "Colombia")]
}

FIRST_NAMES = ["Alice", "Bob", "Charlie", "Diana", "Elena", "Franklin", "Grace", "Hiroshi", "Isabella", "Javier"]
LAST_NAMES = ["Smith", "Tanaka", "Muller", "Dubois", "Silva", "Sharma", "Kowalski", "Chen", "Novak", "O'Connor"]
DOMAINS = ["cloudcorp.com", "fintech-hub.org", "enterprise-data.net", "innovate.io", "globalsystems.de"]


def create_order_event(index: int) -> dict:
    """Generate a single nested JSON order event."""
    region = random.choice(REGIONS)
    city, country = random.choice(CITIES[region])
    first_name = random.choice(FIRST_NAMES)
    last_name = random.choice(LAST_NAMES)
    customer_name = f"{first_name} {last_name}"
    customer_email = f"{first_name.lower()}.{last_name.lower()}@{random.choice(DOMAINS)}"
    customer_id = f"CUST-{random.randint(1000, 9999)}"
    customer_tier = random.choice(TIERS)

    # Generate 1 to 4 items per order
    category = random.choice(list(CATALOG.keys()))
    num_items = random.randint(1, 3)
    selected_products = random.sample(CATALOG[category], min(num_items, len(CATALOG[category])))

    items = []
    order_total = 0.0
    for idx, (item_id, prod_name, price) in enumerate(selected_products, start=1):
        qty = random.randint(1, 4)
        line_total = round(qty * price, 2)
        order_total += line_total
        items.append({
            "item_id": item_id,
            "product_name": prod_name,
            "category": category,
            "quantity": qty,
            "unit_price": price
        })

    event_payload = {
        "event_id": f"evt_{uuid.uuid4()}",
        "event_type": "order_placed",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "order": {
            "order_id": f"ORD-2026-{random.randint(100000, 999999)}",
            "customer": {
                "customer_id": customer_id,
                "name": customer_name,
                "email": customer_email,
                "region": region,
                "tier": customer_tier
            },
            "payment": {
                "method": random.choice(PAYMENT_METHODS),
                "card_last4": f"{random.randint(1000, 9999)}",
                "currency": "USD" if region in ["US", "APAC", "LATAM"] else "EUR",
                "total_amount": round(order_total, 2)
            },
            "items": items,
            "delivery": {
                "status": "CONFIRMED",
                "estimated_days": random.randint(1, 5),
                "address": {
                    "city": city,
                    "country": country
                }
            }
        }
    }
    return event_payload


def save_local_files(events: list, output_dir: str, batch_size: int = 10) -> list:
    """Save generated events into JSON files in batches."""
    os.makedirs(output_dir, exist_ok=True)
    created_files = []
    timestamp_str = datetime.now().strftime("%Y%m%d_%H%M%S")

    for i in range(0, len(events), batch_size):
        chunk = events[i:i + batch_size]
        filename = f"orders_batch_{timestamp_str}_{i // batch_size + 1:02d}.json"
        filepath = os.path.join(output_dir, filename)
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(chunk, f, indent=2)
        created_files.append(filepath)
        print(f" [+] Generated: {filepath} ({len(chunk)} orders)")

    return created_files


def upload_to_azure(file_paths: list, connection_string: str, container_name: str):
    """Upload JSON files to Azure Blob Storage to trigger Snowpipe auto-ingest."""
    try:
        from azure.storage.blob import BlobServiceClient
    except ImportError:
        print(" [!] azure-storage-blob library not installed. Run: pip install azure-storage-blob")
        sys.exit(1)

    print(f"\n[Azure Upload] Connecting to Blob Storage container '{container_name}'...")
    service_client = BlobServiceClient.from_connection_string(connection_string)
    container_client = service_client.get_container_client(container_name)

    for file_path in file_paths:
        blob_name = os.path.basename(file_path)
        print(f" -> Uploading {blob_name} to Azure Blob Storage...")
        with open(file_path, "rb") as data:
            container_client.upload_blob(name=blob_name, data=data, overwrite=True)
        print("    [OK] Uploaded! Azure Event Grid event dispatched -> Snowpipe triggered!")


def upload_to_snowflake_stage(file_paths: list, account: str, user: str, password: str, database: str, schema: str, stage: str):
    """Upload directly to Snowflake internal stage using PUT command."""
    try:
        import snowflake.connector
    except ImportError:
        print(" [!] snowflake-connector-python not installed. Run: pip install snowflake-connector-python")
        sys.exit(1)

    print(f"\n[Snowflake PUT] Connecting to account '{account}'...")
    ctx = snowflake.connector.connect(
        user=user,
        password=password,
        account=account,
        database=database,
        schema=schema
    )
    cs = ctx.cursor()
    try:
        for file_path in file_paths:
            normalized_path = file_path.replace("\\", "/")
            put_sql = f"PUT file://{normalized_path} @{stage} AUTO_COMPRESS=TRUE OVERWRITE=TRUE"
            print(f" -> Executing: {put_sql}")
            cs.execute(put_sql)
            print(f"    [OK] Staged in Snowflake @{stage}")
    finally:
        cs.close()
        ctx.close()


def main():
    parser = argparse.ArgumentParser(description="Synthetic Order Generator for Snowflake Modern Pipeline Demo")
    parser.add_argument("--count", type=int, default=20, help="Number of order events to generate")
    parser.add_argument("--batch-size", type=int, default=10, help="Events per JSON file")
    parser.add_argument("--output-dir", type=str, default="./data", help="Output directory for JSON files")
    parser.add_argument("--azure-conn-str", type=str, default=os.getenv("AZURE_STORAGE_CONNECTION_STRING"), help="Azure Blob Connection String")
    parser.add_argument("--azure-container", type=str, default="raw-events", help="Azure Blob Container Name")
    parser.add_argument("--upload-azure", action="store_true", help="Upload to Azure Blob Storage")
    
    args = parser.parse_args()

    print("==============================================================")
    print("  [>] Snowflake Medallion Pipeline Demo: Event Generator")
    print("==============================================================")
    print(f"Generating {args.count} realistic e-commerce order events...")

    events = [create_order_event(i) for i in range(args.count)]
    files = save_local_files(events, args.output_dir, args.batch_size)

    if args.upload_azure and args.azure_conn_str:
        upload_to_azure(files, args.azure_conn_str, args.azure_container)
    elif args.upload_azure and not args.azure_conn_str:
        print(" [!] Please provide --azure-conn-str or set AZURE_STORAGE_CONNECTION_STRING env var.")

    print("\n[SUCCESS] Event generation complete!")
    print(f"  Files are ready at: {os.path.abspath(args.output_dir)}")


if __name__ == "__main__":
    main()
