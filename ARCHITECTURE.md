# System Architecture

## Overview

The Finance Operations Reconciliation Pipeline is designed as a modular Python application with clear separation of concerns.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     Input Data Sources                           │
├──────────────┬──────────────┬──────────────┬───────────────────┤
│   Orders     │  Shipments   │   Invoices   │ Ledger Postings   │
│   (CSV/JSON) │  (CSV/JSON)  │  (CSV/JSON)  │   (CSV/JSON)      │
└──────┬───────┴──────┬───────┴──────┬───────┴─────────┬─────────┘
       │              │              │                 │
       │              │              │                 │
       ▼              ▼              ▼                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Data Loaders                               │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  • CSV/JSON parsing                                       │   │
│  │  • Date conversion                                        │   │
│  │  • Data validation                                        │   │
│  │  • Type conversion (Decimal for amounts)                 │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Data Models                                │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Order         Shipment      Invoice     LedgerPosting   │   │
│  │    ↓              ↓             ↓              ↓         │   │
│  │  [order_id]   [shipment_id] [invoice_id]  [posting_id]  │   │
│  │  customer_id   order_id     order_id      invoice_id    │   │
│  │  order_date    shipped_amt  invoice_date  amount        │   │
│  │  amount        status       amount        account       │   │
│  │  status                     status        trans_type    │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Reconciliation Engine                           │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                                                           │   │
│  │  1. Match by Order ID                                    │   │
│  │     Orders ──┬──> Invoices                               │   │
│  │              └──> Shipments                              │   │
│  │                                                           │   │
│  │  2. Compare Amounts (within tolerance)                   │   │
│  │     • Order amount vs Invoice amount                     │   │
│  │     • Check shipped amounts for partial fulfillment      │   │
│  │                                                           │   │
│  │  3. Check Timing (within tolerance)                      │   │
│  │     • Order date vs Invoice date                         │   │
│  │                                                           │   │
│  │  4. Detect Refunds                                       │   │
│  │     • Analyze ledger postings for refund transactions    │   │
│  │                                                           │   │
│  │  5. Identify Exceptions                                  │   │
│  │     • Missing invoices                                   │   │
│  │     • Missing orders                                     │   │
│  │     • Amount mismatches                                  │   │
│  │     • Timing issues                                      │   │
│  │     • Partial fulfillments                               │   │
│  │     • Cancelled transactions                             │   │
│  │                                                           │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Reconciliation Results                          │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  ReconciliationMatch (per record)                        │   │
│  │    • order_id, invoice_id                                │   │
│  │    • match_status: matched | exception                   │   │
│  │    • exception_type: timing | amount_mismatch | etc.     │   │
│  │    • amounts and differences                             │   │
│  │    • explanatory notes                                   │   │
│  │                                                           │   │
│  │  ReconciliationSummary (aggregate)                       │   │
│  │    • Total counts                                        │   │
│  │    • Exception breakdown by type                         │   │
│  │    • Financial totals                                    │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Report Generator                              │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Generates multiple report formats:                       │   │
│  │                                                           │   │
│  │  1. Summary Report (TXT)                                 │   │
│  │     • High-level statistics                              │   │
│  │     • Exception breakdown                                │   │
│  │     • Financial summary                                  │   │
│  │                                                           │   │
│  │  2. Matched Records (CSV)                                │   │
│  │     • All successfully matched records                   │   │
│  │                                                           │   │
│  │  3. Exceptions Report (CSV)                              │   │
│  │     • Detailed exception list                            │   │
│  │     • Sorted by exception type                           │   │
│  │                                                           │   │
│  │  4. Detailed Report (JSON)                               │   │
│  │     • Complete data for programmatic access              │   │
│  │                                                           │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Outputs                                   │
├─────────────┬─────────────┬─────────────┬──────────────────────┤
│   Summary   │   Matched   │ Exceptions  │   Detailed Report    │
│   (TXT)     │   (CSV)     │   (CSV)     │      (JSON)          │
└─────────────┴─────────────┴─────────────┴──────────────────────┘
```

## Component Details

### 1. Data Loaders (`src/loaders/`)
- **Purpose**: Load and validate input data from CSV or JSON files
- **Key Features**:
  - Supports both CSV and JSON formats
  - Converts date strings to datetime objects
  - Converts amounts to Decimal for precise calculations
  - Validates data for duplicates and invalid values
- **Output**: Lists of typed data model objects

### 2. Data Models (`src/models/`)
- **Purpose**: Define the structure of all data entities
- **Key Classes**:
  - `Order`: Operational order records
  - `Shipment`: Shipment/delivery records
  - `Invoice`: Financial invoice records
  - `LedgerPosting`: Accounting ledger entries
  - `ReconciliationMatch`: Result of matching one order to invoices
  - `ReconciliationSummary`: Aggregate statistics
- **Features**: Type-safe dataclasses with validation

### 3. Reconciliation Engine (`src/reconciliation/`)
- **Purpose**: Core matching and exception detection logic
- **Algorithm**:
  1. Build lookup tables for efficient matching
  2. Match orders to invoices by order_id
  3. Compare amounts within tolerance
  4. Check date differences
  5. Analyze shipments for partial fulfillment
  6. Check ledger for refunds
  7. Categorize exceptions
- **Configuration**:
  - `tolerance_amount`: Max acceptable amount difference (default: $0.01)
  - `timing_tolerance_days`: Max acceptable date difference (default: 5 days)

### 4. Report Generator (`src/reporting/`)
- **Purpose**: Generate human-readable and machine-readable reports
- **Report Types**:
  - **Summary**: Executive overview with statistics
  - **Matched**: List of successful matches
  - **Exceptions**: Detailed list of issues requiring attention
  - **Detailed**: Complete JSON for integration/analysis
- **Output Location**: `outputs/` directory with timestamped filenames

## Data Flow

1. **Input Stage**: Load data from CSV/JSON files
2. **Validation Stage**: Check for data quality issues
3. **Reconciliation Stage**: Match records and detect exceptions
4. **Reporting Stage**: Generate multiple report formats
5. **Output Stage**: Save reports to disk

## Exception Types

The system categorizes exceptions into specific types:

- **timing**: Date difference exceeds tolerance
- **amount_mismatch**: Amount difference exceeds tolerance
- **missing_invoice**: Order exists but no invoice found
- **missing_order**: Invoice exists but no order found
- **partial_fulfillment**: Only part of order was fulfilled/invoiced
- **refund**: Refund transaction detected in ledger
- **cancelled**: Transaction was cancelled

## Extensibility

The modular design allows for easy extension:

1. **Add new data sources**: Extend DataLoader with new format parsers
2. **Add new matching rules**: Extend ReconciliationEngine logic
3. **Add new report formats**: Extend ReportGenerator with new methods
4. **Add new exception types**: Update models and reconciliation logic
5. **Integration**: Use as a library in other Python applications

## Performance Considerations

- Uses lookup dictionaries for O(1) matching
- Processes data in memory (suitable for millions of records)
- Generates reports incrementally
- Pandas for efficient CSV/JSON parsing

## Configuration

Configurable via CLI arguments:
- Input file paths
- Output directory
- Amount tolerance
- Timing tolerance

## Dependencies

- **pandas**: Data loading and manipulation
- **numpy**: Numerical operations (via pandas)
- **python-dateutil**: Date parsing (via pandas)
- Standard library: dataclasses, decimal, datetime, pathlib, json
