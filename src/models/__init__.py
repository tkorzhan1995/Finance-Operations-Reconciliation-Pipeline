"""
Data models for the Finance Operations Reconciliation Pipeline.
"""
from dataclasses import dataclass
from datetime import datetime
from typing import Optional
from decimal import Decimal


@dataclass
class Order:
    """Represents an operational order record."""
    order_id: str
    customer_id: str
    order_date: datetime
    amount: Decimal
    status: str  # e.g., 'pending', 'completed', 'cancelled'
    
    @classmethod
    def from_dict(cls, data: dict) -> 'Order':
        """Create an Order from a dictionary."""
        return cls(
            order_id=str(data['order_id']),
            customer_id=str(data['customer_id']),
            order_date=data['order_date'] if isinstance(data['order_date'], datetime) else datetime.fromisoformat(str(data['order_date'])),
            amount=Decimal(str(data['amount'])),
            status=str(data['status'])
        )


@dataclass
class Shipment:
    """Represents an operational shipment record."""
    shipment_id: str
    order_id: str
    shipment_date: datetime
    shipped_amount: Decimal
    status: str  # e.g., 'shipped', 'delivered', 'returned'
    
    @classmethod
    def from_dict(cls, data: dict) -> 'Shipment':
        """Create a Shipment from a dictionary."""
        return cls(
            shipment_id=str(data['shipment_id']),
            order_id=str(data['order_id']),
            shipment_date=data['shipment_date'] if isinstance(data['shipment_date'], datetime) else datetime.fromisoformat(str(data['shipment_date'])),
            shipped_amount=Decimal(str(data['shipped_amount'])),
            status=str(data['status'])
        )


@dataclass
class Invoice:
    """Represents a financial invoice record."""
    invoice_id: str
    order_id: str
    customer_id: str
    invoice_date: datetime
    amount: Decimal
    status: str  # e.g., 'pending', 'paid', 'cancelled'
    
    @classmethod
    def from_dict(cls, data: dict) -> 'Invoice':
        """Create an Invoice from a dictionary."""
        return cls(
            invoice_id=str(data['invoice_id']),
            order_id=str(data['order_id']),
            customer_id=str(data['customer_id']),
            invoice_date=data['invoice_date'] if isinstance(data['invoice_date'], datetime) else datetime.fromisoformat(str(data['invoice_date'])),
            amount=Decimal(str(data['amount'])),
            status=str(data['status'])
        )


@dataclass
class LedgerPosting:
    """Represents a financial ledger posting."""
    posting_id: str
    invoice_id: str
    posting_date: datetime
    amount: Decimal
    account: str
    transaction_type: str  # e.g., 'debit', 'credit', 'refund'
    
    @classmethod
    def from_dict(cls, data: dict) -> 'LedgerPosting':
        """Create a LedgerPosting from a dictionary."""
        return cls(
            posting_id=str(data['posting_id']),
            invoice_id=str(data['invoice_id']),
            posting_date=data['posting_date'] if isinstance(data['posting_date'], datetime) else datetime.fromisoformat(str(data['posting_date'])),
            amount=Decimal(str(data['amount'])),
            account=str(data['account']),
            transaction_type=str(data['transaction_type'])
        )


@dataclass
class ReconciliationMatch:
    """Represents a matched record between operational and financial data."""
    order_id: str
    invoice_id: Optional[str]
    match_status: str  # 'matched', 'partial', 'exception'
    exception_type: Optional[str]  # 'timing', 'amount_mismatch', 'missing_invoice', 'missing_order', 'partial_fulfillment', 'refund'
    operational_amount: Decimal
    financial_amount: Decimal
    difference: Decimal
    notes: str
    
    def to_dict(self) -> dict:
        """Convert to dictionary for reporting."""
        return {
            'order_id': self.order_id,
            'invoice_id': self.invoice_id,
            'match_status': self.match_status,
            'exception_type': self.exception_type,
            'operational_amount': str(self.operational_amount),
            'financial_amount': str(self.financial_amount),
            'difference': str(self.difference),
            'notes': self.notes
        }


@dataclass
class ReconciliationSummary:
    """Summary statistics for a reconciliation run."""
    total_orders: int
    total_invoices: int
    matched_count: int
    exception_count: int
    timing_exceptions: int
    amount_mismatches: int
    missing_invoices: int
    missing_orders: int
    partial_fulfillments: int
    refunds: int
    total_operational_amount: Decimal
    total_financial_amount: Decimal
    total_difference: Decimal
    
    def to_dict(self) -> dict:
        """Convert to dictionary for reporting."""
        return {
            'total_orders': self.total_orders,
            'total_invoices': self.total_invoices,
            'matched_count': self.matched_count,
            'exception_count': self.exception_count,
            'timing_exceptions': self.timing_exceptions,
            'amount_mismatches': self.amount_mismatches,
            'missing_invoices': self.missing_invoices,
            'missing_orders': self.missing_orders,
            'partial_fulfillments': self.partial_fulfillments,
            'refunds': self.refunds,
            'total_operational_amount': str(self.total_operational_amount),
            'total_financial_amount': str(self.total_financial_amount),
            'total_difference': str(self.total_difference)
        }
