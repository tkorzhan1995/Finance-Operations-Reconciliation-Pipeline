"""
Reconciliation engine for matching operational and financial records.
"""
from typing import List, Dict, Tuple
from decimal import Decimal
from datetime import timedelta

from src.models import Order, Shipment, Invoice, LedgerPosting, ReconciliationMatch, ReconciliationSummary


class ReconciliationEngine:
    """
    Main reconciliation engine that matches operational records (orders, shipments)
    with financial records (invoices, ledger postings).
    """
    
    def __init__(self, tolerance_amount: Decimal = Decimal('0.01'), 
                 timing_tolerance_days: int = 5):
        """
        Initialize the reconciliation engine.
        
        Args:
            tolerance_amount: Maximum acceptable difference in amounts to consider a match
            timing_tolerance_days: Number of days difference acceptable for timing exceptions
        """
        self.tolerance_amount = tolerance_amount
        self.timing_tolerance_days = timing_tolerance_days
    
    def reconcile(self, orders: List[Order], shipments: List[Shipment],
                  invoices: List[Invoice], ledger_postings: List[LedgerPosting]) -> Tuple[List[ReconciliationMatch], ReconciliationSummary]:
        """
        Perform full reconciliation between operational and financial data.
        
        Returns:
            Tuple of (list of matches, summary statistics)
        """
        matches = []
        
        # Create lookup dictionaries for efficient matching
        invoice_by_order = {inv.order_id: inv for inv in invoices}
        shipments_by_order = {}
        for shipment in shipments:
            if shipment.order_id not in shipments_by_order:
                shipments_by_order[shipment.order_id] = []
            shipments_by_order[shipment.order_id].append(shipment)
        
        ledger_by_invoice = {}
        for posting in ledger_postings:
            if posting.invoice_id not in ledger_by_invoice:
                ledger_by_invoice[posting.invoice_id] = []
            ledger_by_invoice[posting.invoice_id].append(posting)
        
        # Track which invoices have been matched
        matched_invoices = set()
        
        # Match each order with its corresponding invoice
        for order in orders:
            invoice = invoice_by_order.get(order.order_id)
            
            if invoice is None:
                # No invoice found for this order
                match = self._create_missing_invoice_match(order)
            else:
                matched_invoices.add(invoice.invoice_id)
                # Check if amounts match
                match = self._match_order_invoice(order, invoice, 
                                                   shipments_by_order.get(order.order_id, []),
                                                   ledger_by_invoice.get(invoice.invoice_id, []))
            
            matches.append(match)
        
        # Find invoices without corresponding orders
        for invoice in invoices:
            if invoice.invoice_id not in matched_invoices:
                match = self._create_missing_order_match(invoice)
                matches.append(match)
        
        # Generate summary
        summary = self._generate_summary(matches, orders, invoices)
        
        return matches, summary
    
    def _match_order_invoice(self, order: Order, invoice: Invoice,
                            shipments: List[Shipment], 
                            ledger_postings: List[LedgerPosting]) -> ReconciliationMatch:
        """Match an order with its invoice and determine if there are exceptions."""
        
        # Calculate total shipped amount
        total_shipped = sum(s.shipped_amount for s in shipments if s.status != 'returned')
        
        # Calculate net ledger amount (considering refunds)
        net_ledger = Decimal('0')
        has_refund = False
        for posting in ledger_postings:
            if posting.transaction_type == 'refund':
                net_ledger -= posting.amount
                has_refund = True
            else:
                net_ledger += posting.amount
        
        operational_amount = order.amount
        financial_amount = invoice.amount
        difference = operational_amount - financial_amount
        
        # Determine match status and exception type
        match_status = 'matched'
        exception_type = None
        notes = []
        
        # Check for amount mismatch
        if abs(difference) > self.tolerance_amount:
            match_status = 'exception'
            
            # Check if it's a partial fulfillment
            if total_shipped > 0 and abs(total_shipped - financial_amount) <= self.tolerance_amount:
                exception_type = 'partial_fulfillment'
                notes.append(f"Partial fulfillment: shipped ${total_shipped}, invoiced ${financial_amount}")
            # Check if it's a refund
            elif has_refund:
                exception_type = 'refund'
                notes.append(f"Refund detected: net amount after refunds ${net_ledger}")
            else:
                exception_type = 'amount_mismatch'
                notes.append(f"Amount mismatch: order ${operational_amount} vs invoice ${financial_amount}")
        
        # Check for timing issues
        date_diff = abs((order.order_date - invoice.invoice_date).days)
        if date_diff > self.timing_tolerance_days:
            if match_status != 'exception':
                match_status = 'exception'
                exception_type = 'timing'
            notes.append(f"Timing issue: {date_diff} days between order and invoice")
        
        # Check for cancelled/pending status
        if order.status == 'cancelled' or invoice.status == 'cancelled':
            match_status = 'exception'
            exception_type = 'cancelled'
            notes.append(f"Cancelled: order status={order.status}, invoice status={invoice.status}")
        
        return ReconciliationMatch(
            order_id=order.order_id,
            invoice_id=invoice.invoice_id,
            match_status=match_status,
            exception_type=exception_type,
            operational_amount=operational_amount,
            financial_amount=financial_amount,
            difference=difference,
            notes='; '.join(notes) if notes else 'OK'
        )
    
    def _create_missing_invoice_match(self, order: Order) -> ReconciliationMatch:
        """Create a match record for an order without an invoice."""
        return ReconciliationMatch(
            order_id=order.order_id,
            invoice_id=None,
            match_status='exception',
            exception_type='missing_invoice',
            operational_amount=order.amount,
            financial_amount=Decimal('0'),
            difference=order.amount,
            notes=f"No invoice found for order {order.order_id}"
        )
    
    def _create_missing_order_match(self, invoice: Invoice) -> ReconciliationMatch:
        """Create a match record for an invoice without an order."""
        return ReconciliationMatch(
            order_id=invoice.order_id,  # Use order_id from invoice
            invoice_id=invoice.invoice_id,
            match_status='exception',
            exception_type='missing_order',
            operational_amount=Decimal('0'),
            financial_amount=invoice.amount,
            difference=-invoice.amount,
            notes=f"No order found for invoice {invoice.invoice_id}"
        )
    
    def _generate_summary(self, matches: List[ReconciliationMatch],
                         orders: List[Order], invoices: List[Invoice]) -> ReconciliationSummary:
        """Generate summary statistics from reconciliation results."""
        
        matched_count = sum(1 for m in matches if m.match_status == 'matched')
        exception_count = sum(1 for m in matches if m.match_status == 'exception')
        
        # Count specific exception types
        timing_exceptions = sum(1 for m in matches if m.exception_type == 'timing')
        amount_mismatches = sum(1 for m in matches if m.exception_type == 'amount_mismatch')
        missing_invoices = sum(1 for m in matches if m.exception_type == 'missing_invoice')
        missing_orders = sum(1 for m in matches if m.exception_type == 'missing_order')
        partial_fulfillments = sum(1 for m in matches if m.exception_type == 'partial_fulfillment')
        refunds = sum(1 for m in matches if m.exception_type == 'refund')
        
        # Calculate totals
        total_operational = sum(o.amount for o in orders)
        total_financial = sum(i.amount for i in invoices)
        total_difference = total_operational - total_financial
        
        return ReconciliationSummary(
            total_orders=len(orders),
            total_invoices=len(invoices),
            matched_count=matched_count,
            exception_count=exception_count,
            timing_exceptions=timing_exceptions,
            amount_mismatches=amount_mismatches,
            missing_invoices=missing_invoices,
            missing_orders=missing_orders,
            partial_fulfillments=partial_fulfillments,
            refunds=refunds,
            total_operational_amount=total_operational,
            total_financial_amount=total_financial,
            total_difference=total_difference
        )
