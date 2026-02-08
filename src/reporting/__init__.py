"""
Reporting utilities for the Finance Operations Reconciliation Pipeline.
"""
import pandas as pd
from typing import List
from pathlib import Path
import json
from datetime import datetime

from src.models import ReconciliationMatch, ReconciliationSummary


class ReportGenerator:
    """Generates reports from reconciliation results."""
    
    def __init__(self, output_dir: str = 'outputs'):
        """
        Initialize the report generator.
        
        Args:
            output_dir: Directory where reports will be saved
        """
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True, parents=True)
    
    def generate_all_reports(self, matches: List[ReconciliationMatch],
                            summary: ReconciliationSummary,
                            timestamp: str = None) -> dict:
        """
        Generate all reports and save to files.
        
        Returns:
            Dictionary with paths to generated reports
        """
        if timestamp is None:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        
        report_paths = {}
        
        # Generate summary report
        summary_path = self.generate_summary_report(summary, timestamp)
        report_paths['summary'] = str(summary_path)
        
        # Generate matched records report
        matched_path = self.generate_matched_records_report(matches, timestamp)
        report_paths['matched'] = str(matched_path)
        
        # Generate exceptions report
        exceptions_path = self.generate_exceptions_report(matches, timestamp)
        report_paths['exceptions'] = str(exceptions_path)
        
        # Generate detailed report
        detailed_path = self.generate_detailed_report(matches, timestamp)
        report_paths['detailed'] = str(detailed_path)
        
        return report_paths
    
    def generate_summary_report(self, summary: ReconciliationSummary,
                               timestamp: str) -> Path:
        """Generate a summary report with key statistics."""
        output_path = self.output_dir / f'reconciliation_summary_{timestamp}.txt'
        
        with open(output_path, 'w') as f:
            f.write("=" * 60 + "\n")
            f.write("FINANCE OPERATIONS RECONCILIATION SUMMARY\n")
            f.write("=" * 60 + "\n\n")
            
            f.write(f"Report Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            
            f.write("OVERVIEW:\n")
            f.write("-" * 60 + "\n")
            f.write(f"Total Orders:           {summary.total_orders:>10}\n")
            f.write(f"Total Invoices:         {summary.total_invoices:>10}\n")
            f.write(f"Matched Records:        {summary.matched_count:>10}\n")
            f.write(f"Exception Records:      {summary.exception_count:>10}\n")
            f.write(f"Match Rate:             {summary.matched_count / max(summary.total_orders, 1) * 100:>9.1f}%\n\n")
            
            f.write("EXCEPTION BREAKDOWN:\n")
            f.write("-" * 60 + "\n")
            f.write(f"Timing Issues:          {summary.timing_exceptions:>10}\n")
            f.write(f"Amount Mismatches:      {summary.amount_mismatches:>10}\n")
            f.write(f"Missing Invoices:       {summary.missing_invoices:>10}\n")
            f.write(f"Missing Orders:         {summary.missing_orders:>10}\n")
            f.write(f"Partial Fulfillments:   {summary.partial_fulfillments:>10}\n")
            f.write(f"Refunds:                {summary.refunds:>10}\n\n")
            
            f.write("FINANCIAL SUMMARY:\n")
            f.write("-" * 60 + "\n")
            f.write(f"Total Operational Amt:  ${summary.total_operational_amount:>15,.2f}\n")
            f.write(f"Total Financial Amt:    ${summary.total_financial_amount:>15,.2f}\n")
            f.write(f"Total Difference:       ${summary.total_difference:>15,.2f}\n")
            f.write(f"Difference %:           {abs(summary.total_difference) / max(summary.total_operational_amount, Decimal('0.01')) * 100:>14.2f}%\n\n")
            
            f.write("=" * 60 + "\n")
        
        return output_path
    
    def generate_matched_records_report(self, matches: List[ReconciliationMatch],
                                       timestamp: str) -> Path:
        """Generate CSV report of successfully matched records."""
        matched = [m for m in matches if m.match_status == 'matched']
        
        df = pd.DataFrame([m.to_dict() for m in matched])
        output_path = self.output_dir / f'matched_records_{timestamp}.csv'
        df.to_csv(output_path, index=False)
        
        return output_path
    
    def generate_exceptions_report(self, matches: List[ReconciliationMatch],
                                  timestamp: str) -> Path:
        """Generate CSV report of exception records."""
        exceptions = [m for m in matches if m.match_status == 'exception']
        
        df = pd.DataFrame([m.to_dict() for m in exceptions])
        
        # Sort by exception type for easier review
        if not df.empty:
            df = df.sort_values(['exception_type', 'difference'], ascending=[True, False])
        
        output_path = self.output_dir / f'exceptions_{timestamp}.csv'
        df.to_csv(output_path, index=False)
        
        return output_path
    
    def generate_detailed_report(self, matches: List[ReconciliationMatch],
                                timestamp: str) -> Path:
        """Generate comprehensive JSON report with all details."""
        output_path = self.output_dir / f'detailed_report_{timestamp}.json'
        
        report_data = {
            'timestamp': datetime.now().isoformat(),
            'matches': [m.to_dict() for m in matches]
        }
        
        with open(output_path, 'w') as f:
            json.dump(report_data, f, indent=2)
        
        return output_path
    
    def print_summary(self, summary: ReconciliationSummary):
        """Print summary to console."""
        print("\n" + "=" * 60)
        print("RECONCILIATION SUMMARY")
        print("=" * 60)
        print(f"\nTotal Orders:           {summary.total_orders}")
        print(f"Total Invoices:         {summary.total_invoices}")
        print(f"Matched Records:        {summary.matched_count}")
        print(f"Exception Records:      {summary.exception_count}")
        print(f"\nException Breakdown:")
        print(f"  - Timing Issues:      {summary.timing_exceptions}")
        print(f"  - Amount Mismatches:  {summary.amount_mismatches}")
        print(f"  - Missing Invoices:   {summary.missing_invoices}")
        print(f"  - Missing Orders:     {summary.missing_orders}")
        print(f"  - Partial Fulfillment:{summary.partial_fulfillments}")
        print(f"  - Refunds:            {summary.refunds}")
        print(f"\nTotal Operational:      ${summary.total_operational_amount:,.2f}")
        print(f"Total Financial:        ${summary.total_financial_amount:,.2f}")
        print(f"Total Difference:       ${summary.total_difference:,.2f}")
        print("=" * 60 + "\n")


# Import Decimal for the summary report
from decimal import Decimal
