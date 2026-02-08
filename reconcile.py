#!/usr/bin/env python3
"""
Main reconciliation pipeline script.

This script runs the complete Finance Operations Reconciliation Pipeline,
loading operational and financial data, performing reconciliation, and
generating reports.
"""
import argparse
import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent))

from src.loaders import DataLoader
from src.reconciliation import ReconciliationEngine
from src.reporting import ReportGenerator
from decimal import Decimal


def main():
    """Main entry point for the reconciliation pipeline."""
    parser = argparse.ArgumentParser(
        description='Finance Operations Reconciliation Pipeline',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Run with default sample data
  python reconcile.py
  
  # Run with custom data files
  python reconcile.py --orders data/orders.csv --invoices data/invoices.csv
  
  # Adjust tolerance settings
  python reconcile.py --amount-tolerance 1.00 --timing-tolerance 10
        """
    )
    
    parser.add_argument(
        '--orders',
        default='sample_data/orders.csv',
        help='Path to orders CSV file (default: sample_data/orders.csv)'
    )
    parser.add_argument(
        '--shipments',
        default='sample_data/shipments.csv',
        help='Path to shipments CSV file (default: sample_data/shipments.csv)'
    )
    parser.add_argument(
        '--invoices',
        default='sample_data/invoices.csv',
        help='Path to invoices CSV file (default: sample_data/invoices.csv)'
    )
    parser.add_argument(
        '--ledger',
        default='sample_data/ledger_postings.csv',
        help='Path to ledger postings CSV file (default: sample_data/ledger_postings.csv)'
    )
    parser.add_argument(
        '--output-dir',
        default='outputs',
        help='Directory for output reports (default: outputs)'
    )
    parser.add_argument(
        '--amount-tolerance',
        type=float,
        default=0.01,
        help='Maximum acceptable amount difference for matching (default: 0.01)'
    )
    parser.add_argument(
        '--timing-tolerance',
        type=int,
        default=5,
        help='Maximum days difference for timing exceptions (default: 5)'
    )
    
    args = parser.parse_args()
    
    print("=" * 70)
    print("Finance Operations Reconciliation Pipeline")
    print("=" * 70)
    print()
    
    # Load data
    print("Loading operational data...")
    try:
        orders = DataLoader.load_orders(args.orders)
        print(f"  ✓ Loaded {len(orders)} orders from {args.orders}")
    except Exception as e:
        print(f"  ✗ Error loading orders: {e}")
        return 1
    
    try:
        shipments = DataLoader.load_shipments(args.shipments)
        print(f"  ✓ Loaded {len(shipments)} shipments from {args.shipments}")
    except Exception as e:
        print(f"  ✗ Error loading shipments: {e}")
        return 1
    
    print("\nLoading financial data...")
    try:
        invoices = DataLoader.load_invoices(args.invoices)
        print(f"  ✓ Loaded {len(invoices)} invoices from {args.invoices}")
    except Exception as e:
        print(f"  ✗ Error loading invoices: {e}")
        return 1
    
    try:
        ledger_postings = DataLoader.load_ledger_postings(args.ledger)
        print(f"  ✓ Loaded {len(ledger_postings)} ledger postings from {args.ledger}")
    except Exception as e:
        print(f"  ✗ Error loading ledger postings: {e}")
        return 1
    
    # Validate data
    print("\nValidating data...")
    issues = DataLoader.validate_data(orders, invoices)
    has_critical_issues = False
    for issue_type, issue_list in issues.items():
        if issue_list:
            print(f"  ⚠ {issue_type}: {len(issue_list)} found")
            has_critical_issues = True
    
    if not has_critical_issues:
        print("  ✓ No data validation issues found")
    
    # Run reconciliation
    print("\nRunning reconciliation...")
    engine = ReconciliationEngine(
        tolerance_amount=Decimal(str(args.amount_tolerance)),
        timing_tolerance_days=args.timing_tolerance
    )
    
    matches, summary = engine.reconcile(orders, shipments, invoices, ledger_postings)
    print(f"  ✓ Reconciliation complete: {len(matches)} records processed")
    
    # Generate reports
    print("\nGenerating reports...")
    report_gen = ReportGenerator(output_dir=args.output_dir)
    report_paths = report_gen.generate_all_reports(matches, summary)
    
    for report_type, path in report_paths.items():
        print(f"  ✓ {report_type.capitalize()} report: {path}")
    
    # Print summary
    report_gen.print_summary(summary)
    
    print("\n" + "=" * 70)
    print("Pipeline execution completed successfully!")
    print("=" * 70)
    
    return 0


if __name__ == '__main__':
    sys.exit(main())
