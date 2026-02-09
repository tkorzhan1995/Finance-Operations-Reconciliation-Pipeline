# Reconciliation Logic

This document explains how the Finance Operations Reconciliation Pipeline matches records between different systems and identifies discrepancies.

## Overview

The reconciliation process validates that financial data is consistent across three sources:
- **Orders**: Customer purchase orders
- **Invoices**: Bills sent to customers
- **Ledger**: Accounting system records

## Matching Rules

### Orders ↔ Invoices

This step ensures that every order has a corresponding invoice and vice versa.

**Matching Criteria:**
- **Primary Key**: Records match on `order_id`
- **Timing Tolerance**: Invoice dates can differ from order dates by up to ±5 days
  - Example: An order dated Jan 10 can match an invoice dated between Jan 5 and Jan 15
- **Amount Matching**: Order total and invoice total should match within an acceptable tolerance
  - Small differences (e.g., rounding, minor adjustments) are allowed
  - Large discrepancies trigger an exception

**What This Catches:**
- Missing invoices for placed orders
- Invoices without corresponding orders
- Significant pricing differences between order and invoice

---

### Invoices ↔ Ledger

This step verifies that invoices have been properly recorded in the accounting system.

**Matching Criteria:**
- **Primary Key**: Records match on `invoice_id`
- **Amount Validation**: The posted amount in the ledger must equal the invoice amount
- **Multiple Entries**: A single invoice may have multiple ledger entries that sum to the invoice total
  - Example: An invoice for $1,000 might have separate ledger entries for $900 (revenue) and $100 (tax)

**What This Catches:**
- Invoices that were never posted to the ledger
- Incorrect amounts posted to the ledger
- Partial postings or missing entries

---

## Exception Categories

When records don't match according to the rules above, the system categorizes the issue into one of the following exception types:

### MISSING_INVOICE
**Description**: An order exists, but no corresponding invoice was found.

**Common Causes:**
- Invoice not yet created
- Invoice creation process failed
- Order was cancelled but not properly recorded

**Action Required**: Investigate whether the invoice should be created or if the order should be voided.

---

### AMOUNT_MISMATCH
**Description**: Records match by ID, but the amounts don't align within acceptable tolerance.

**Common Causes:**
- Manual adjustments not reflected in both systems
- Data entry errors
- Currency conversion issues
- Discounts or credits applied incorrectly

**Action Required**: Review the amounts in both systems and determine which is correct. Update or document the difference.

---

### TIMING_DIFFERENCE
**Description**: Records match by ID and amount, but the dates are outside the acceptable ±5 day window.

**Common Causes:**
- Processing delays
- Month-end cutoff issues
- System downtime causing delayed entry

**Action Required**: Verify that the timing difference is legitimate and document the reason. May require period adjustments.

---

### DUPLICATE_POSTING
**Description**: The same invoice or transaction appears multiple times in the ledger.

**Common Causes:**
- System glitches causing double-posting
- Manual entry of an already-posted invoice
- Retry logic in integration code

**Action Required**: Identify the duplicate entry and reverse it. Ensure the correct amount is posted only once.

---

### UNPOSTED_INVOICE
**Description**: An invoice exists but has no corresponding entry in the ledger.

**Common Causes:**
- Invoice approved but not yet posted
- Integration failure between invoicing and accounting systems
- Manual posting step missed

**Action Required**: Post the invoice to the ledger or investigate why it shouldn't be posted.

---

## Reconciliation Process Flow

1. **Extract Data**: Pull records from Orders, Invoices, and Ledger systems
2. **Match Orders ↔ Invoices**: Apply matching rules and identify exceptions
3. **Match Invoices ↔ Ledger**: Apply matching rules and identify exceptions
4. **Categorize Exceptions**: Assign each discrepancy to an exception category
5. **Generate Report**: Output all exceptions for review and resolution
6. **Resolution Tracking**: Monitor which exceptions have been addressed

---

## Tolerance Settings

The following tolerances are configurable:

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| Date Tolerance | ±5 days | Allowable difference between order and invoice dates |
| Amount Tolerance | TBD | Percentage or fixed amount for acceptable differences |

---

## Best Practices

- **Run Regularly**: Execute reconciliation daily to catch issues early
- **Investigate Quickly**: Address exceptions within 24-48 hours
- **Document Resolutions**: Note why each exception occurred and how it was resolved
- **Monitor Patterns**: Track which exception types occur most frequently
- **Adjust Rules**: Fine-tune matching rules and tolerances based on business needs

---

## Questions or Issues?

If you have questions about the reconciliation logic or encounter unexpected results, please contact the Finance Operations team.