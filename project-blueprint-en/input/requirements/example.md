# We Need a Better Equipment Management System

> This is a sample. Use it as a reference when writing requirement notes.
> Any format is fine — bullet points, pasted meeting notes, etc.

## Background

- The General Affairs department manages equipment with an Excel ledger, but the process is falling apart
- Monthly inventory checks take an entire day, crowding out regular work
- There's talk of wanting to improve this by the fiscal year starting in April [YYYY]

## Current Problems

- We track equipment inventory in Excel, but we lose track of who has what
- Many people forget to update the ledger when new equipment is purchased
- Physical inventory checks take an entire day every time
- Broken equipment sometimes gets left unaddressed

## What We Want

- Ability to register "I'm borrowing this item" from a smartphone
- A list view showing who currently has what
- Ability to report broken equipment, with notifications sent to administrators
- A checklist that appears during inventory checks would be great
- It would be nice to see how much equipment each department is using

## Users

- General employees (~200 people): Borrow and return equipment
- General Affairs administrators (3 people): Register, dispose of, and inventory equipment
- Department heads (~10 people): View their department's usage status

## Constraints & Conditions

- Internal network access only is fine (no need for external access)
- We want to migrate data from the existing Excel ledger (~500 records)
- Budget is limited. Ideally it would run on our existing servers
- At minimum, check-out management should be running by the April [YYYY] inventory check

## Undecided Items

- Barcode or QR code scanning for equipment might be convenient, but it's not essential
- Whether a native mobile app is needed, or browser-based is sufficient
- Whether a supervisor approval flow is needed for check-outs

## Priorities

1. First, the ability to manage check-outs and returns (this is our biggest pain point)
2. Next, equipment ledger management (registration, editing, disposal)
3. Inventory check features can come later
4. Reports and analytics are nice-to-have if time permits
