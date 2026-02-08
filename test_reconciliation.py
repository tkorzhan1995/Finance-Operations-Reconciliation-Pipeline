"""
Simple tests for the Finance Operations Reconciliation Pipeline.
"""
import sys
from pathlib import Path
from decimal import Decimal
from datetime import datetime

# Add src to path
sys.path.insert(0, str(Path(__file__).parent))

from src.models import Order, Invoice, ReconciliationMatch
from src.reconciliation import ReconciliationEngine


def test_perfect_match():
    """Test that identical order and invoice match correctly."""
    print("Test 1: Perfect Match")
    
    order = Order(
        order_id="TEST-001",
        customer_id="CUST-001",
        order_date=datetime(2024, 1, 15),
        amount=Decimal("1000.00"),
        status="completed"
    )
    
    invoice = Invoice(
        invoice_id="INV-001",
        order_id="TEST-001",
        customer_id="CUST-001",
        invoice_date=datetime(2024, 1, 15),
        amount=Decimal("1000.00"),
        status="paid"
    )
    
    engine = ReconciliationEngine()
    matches, summary = engine.reconcile([order], [], [invoice], [])
    
    assert len(matches) == 1, "Should have one match"
    assert matches[0].match_status == "matched", "Should be matched"
    assert matches[0].exception_type is None, "Should have no exception"
    assert summary.matched_count == 1, "Should have 1 matched record"
    assert summary.exception_count == 0, "Should have 0 exceptions"
    
    print("  ✓ Perfect match test passed")


def test_amount_mismatch():
    """Test that orders and invoices with different amounts create exceptions."""
    print("Test 2: Amount Mismatch")
    
    order = Order(
        order_id="TEST-002",
        customer_id="CUST-002",
        order_date=datetime(2024, 1, 15),
        amount=Decimal("1000.00"),
        status="completed"
    )
    
    invoice = Invoice(
        invoice_id="INV-002",
        order_id="TEST-002",
        customer_id="CUST-002",
        invoice_date=datetime(2024, 1, 15),
        amount=Decimal("1050.00"),
        status="paid"
    )
    
    engine = ReconciliationEngine()
    matches, summary = engine.reconcile([order], [], [invoice], [])
    
    assert len(matches) == 1, "Should have one match"
    assert matches[0].match_status == "exception", "Should be exception"
    assert matches[0].exception_type == "amount_mismatch", "Should be amount mismatch"
    assert summary.exception_count == 1, "Should have 1 exception"
    assert summary.amount_mismatches == 1, "Should have 1 amount mismatch"
    
    print("  ✓ Amount mismatch test passed")


def test_timing_exception():
    """Test that orders and invoices with dates too far apart create exceptions."""
    print("Test 3: Timing Exception")
    
    order = Order(
        order_id="TEST-003",
        customer_id="CUST-003",
        order_date=datetime(2024, 1, 1),
        amount=Decimal("1000.00"),
        status="completed"
    )
    
    invoice = Invoice(
        invoice_id="INV-003",
        order_id="TEST-003",
        customer_id="CUST-003",
        invoice_date=datetime(2024, 1, 20),  # 19 days later
        amount=Decimal("1000.00"),
        status="paid"
    )
    
    engine = ReconciliationEngine(timing_tolerance_days=5)
    matches, summary = engine.reconcile([order], [], [invoice], [])
    
    assert len(matches) == 1, "Should have one match"
    assert matches[0].match_status == "exception", "Should be exception"
    assert matches[0].exception_type == "timing", "Should be timing exception"
    assert summary.timing_exceptions == 1, "Should have 1 timing exception"
    
    print("  ✓ Timing exception test passed")


def test_missing_invoice():
    """Test that orders without invoices are flagged."""
    print("Test 4: Missing Invoice")
    
    order = Order(
        order_id="TEST-004",
        customer_id="CUST-004",
        order_date=datetime(2024, 1, 15),
        amount=Decimal("1000.00"),
        status="completed"
    )
    
    engine = ReconciliationEngine()
    matches, summary = engine.reconcile([order], [], [], [])
    
    assert len(matches) == 1, "Should have one match"
    assert matches[0].match_status == "exception", "Should be exception"
    assert matches[0].exception_type == "missing_invoice", "Should be missing invoice"
    assert summary.missing_invoices == 1, "Should have 1 missing invoice"
    
    print("  ✓ Missing invoice test passed")


def test_missing_order():
    """Test that invoices without orders are flagged."""
    print("Test 5: Missing Order")
    
    invoice = Invoice(
        invoice_id="INV-005",
        order_id="TEST-005",
        customer_id="CUST-005",
        invoice_date=datetime(2024, 1, 15),
        amount=Decimal("1000.00"),
        status="paid"
    )
    
    engine = ReconciliationEngine()
    matches, summary = engine.reconcile([], [], [invoice], [])
    
    assert len(matches) == 1, "Should have one match"
    assert matches[0].match_status == "exception", "Should be exception"
    assert matches[0].exception_type == "missing_order", "Should be missing order"
    assert summary.missing_orders == 1, "Should have 1 missing order"
    
    print("  ✓ Missing order test passed")


def test_summary_statistics():
    """Test that summary statistics are calculated correctly."""
    print("Test 6: Summary Statistics")
    
    orders = [
        Order("O1", "C1", datetime(2024, 1, 1), Decimal("100"), "completed"),
        Order("O2", "C2", datetime(2024, 1, 1), Decimal("200"), "completed"),
        Order("O3", "C3", datetime(2024, 1, 1), Decimal("300"), "completed"),
    ]
    
    invoices = [
        Invoice("I1", "O1", "C1", datetime(2024, 1, 1), Decimal("100"), "paid"),
        Invoice("I2", "O2", "C2", datetime(2024, 1, 1), Decimal("200"), "paid"),
    ]
    
    engine = ReconciliationEngine()
    matches, summary = engine.reconcile(orders, [], invoices, [])
    
    assert summary.total_orders == 3, "Should have 3 orders"
    assert summary.total_invoices == 2, "Should have 2 invoices"
    assert summary.matched_count == 2, "Should have 2 matches"
    assert summary.exception_count == 1, "Should have 1 exception"
    assert summary.total_operational_amount == Decimal("600"), "Total operational should be 600"
    assert summary.total_financial_amount == Decimal("300"), "Total financial should be 300"
    
    print("  ✓ Summary statistics test passed")


def run_all_tests():
    """Run all tests."""
    print("\n" + "=" * 60)
    print("Running Finance Operations Reconciliation Tests")
    print("=" * 60 + "\n")
    
    try:
        test_perfect_match()
        test_amount_mismatch()
        test_timing_exception()
        test_missing_invoice()
        test_missing_order()
        test_summary_statistics()
        
        print("\n" + "=" * 60)
        print("All tests passed! ✓")
        print("=" * 60 + "\n")
        return 0
    except AssertionError as e:
        print(f"\n✗ Test failed: {e}\n")
        return 1
    except Exception as e:
        print(f"\n✗ Unexpected error: {e}\n")
        return 1


if __name__ == "__main__":
    sys.exit(run_all_tests())
