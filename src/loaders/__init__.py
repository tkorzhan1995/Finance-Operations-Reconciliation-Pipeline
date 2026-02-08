"""
Data loading utilities for the Finance Operations Reconciliation Pipeline.
"""
import pandas as pd
from typing import List, Dict
from datetime import datetime
from pathlib import Path
import json

from src.models import Order, Shipment, Invoice, LedgerPosting


class DataLoader:
    """Loads operational and financial data from CSV or JSON files."""
    
    @staticmethod
    def load_orders(file_path: str) -> List[Order]:
        """Load orders from CSV or JSON file."""
        path = Path(file_path)
        
        if path.suffix == '.csv':
            df = pd.read_csv(file_path)
        elif path.suffix == '.json':
            df = pd.read_json(file_path)
        else:
            raise ValueError(f"Unsupported file format: {path.suffix}")
        
        # Convert date strings to datetime
        df['order_date'] = pd.to_datetime(df['order_date'])
        
        orders = []
        for _, row in df.iterrows():
            orders.append(Order.from_dict(row.to_dict()))
        
        return orders
    
    @staticmethod
    def load_shipments(file_path: str) -> List[Shipment]:
        """Load shipments from CSV or JSON file."""
        path = Path(file_path)
        
        if path.suffix == '.csv':
            df = pd.read_csv(file_path)
        elif path.suffix == '.json':
            df = pd.read_json(file_path)
        else:
            raise ValueError(f"Unsupported file format: {path.suffix}")
        
        # Convert date strings to datetime
        df['shipment_date'] = pd.to_datetime(df['shipment_date'])
        
        shipments = []
        for _, row in df.iterrows():
            shipments.append(Shipment.from_dict(row.to_dict()))
        
        return shipments
    
    @staticmethod
    def load_invoices(file_path: str) -> List[Invoice]:
        """Load invoices from CSV or JSON file."""
        path = Path(file_path)
        
        if path.suffix == '.csv':
            df = pd.read_csv(file_path)
        elif path.suffix == '.json':
            df = pd.read_json(file_path)
        else:
            raise ValueError(f"Unsupported file format: {path.suffix}")
        
        # Convert date strings to datetime
        df['invoice_date'] = pd.to_datetime(df['invoice_date'])
        
        invoices = []
        for _, row in df.iterrows():
            invoices.append(Invoice.from_dict(row.to_dict()))
        
        return invoices
    
    @staticmethod
    def load_ledger_postings(file_path: str) -> List[LedgerPosting]:
        """Load ledger postings from CSV or JSON file."""
        path = Path(file_path)
        
        if path.suffix == '.csv':
            df = pd.read_csv(file_path)
        elif path.suffix == '.json':
            df = pd.read_json(file_path)
        else:
            raise ValueError(f"Unsupported file format: {path.suffix}")
        
        # Convert date strings to datetime
        df['posting_date'] = pd.to_datetime(df['posting_date'])
        
        postings = []
        for _, row in df.iterrows():
            postings.append(LedgerPosting.from_dict(row.to_dict()))
        
        return postings
    
    @staticmethod
    def validate_data(orders: List[Order], invoices: List[Invoice]) -> Dict[str, List[str]]:
        """Validate loaded data for common issues."""
        issues = {
            'duplicate_orders': [],
            'duplicate_invoices': [],
            'invalid_amounts': [],
            'invalid_statuses': []
        }
        
        # Check for duplicate order IDs
        order_ids = [o.order_id for o in orders]
        duplicates = set([x for x in order_ids if order_ids.count(x) > 1])
        if duplicates:
            issues['duplicate_orders'] = list(duplicates)
        
        # Check for duplicate invoice IDs
        invoice_ids = [i.invoice_id for i in invoices]
        duplicates = set([x for x in invoice_ids if invoice_ids.count(x) > 1])
        if duplicates:
            issues['duplicate_invoices'] = list(duplicates)
        
        # Check for negative or zero amounts
        for order in orders:
            if order.amount <= 0:
                issues['invalid_amounts'].append(f"Order {order.order_id} has invalid amount: {order.amount}")
        
        for invoice in invoices:
            if invoice.amount <= 0:
                issues['invalid_amounts'].append(f"Invoice {invoice.invoice_id} has invalid amount: {invoice.amount}")
        
        return issues
