# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Facturation** is a French-language invoicing and job-tracking web application for small service businesses (HVAC, etc.). It is a static, no-build-step SPA using vanilla JS, Tailwind CSS (CDN), and Firebase as the only backend.

## Running the App

No build process. Open either HTML file directly in a browser or serve them with any static file server:

```bash
# Quick local server (Python)
python -m http.server 8080

# Or with Node
npx serve .
```

The two entry points:
- `index.html` — main invoice management dashboard
- `jobs.html` — jobs/interventions tracker

## Architecture

### Two-Page Structure

**`index.html`** — Full invoicing workflow, organized as tabs:
- **Dashboard** — stats (client count, products, invoices, jobs) and last invoice summary
- **Clients** — CRUD for client records
- **Products** — product/service catalog with pricing
- **Invoices** — saved invoice list with search/filter and reopen capability
- **New Invoice** — invoice builder with line items, tax, discount, stamp duty, and A4 print template

**`jobs.html`** — Service intervention tracker:
- Form to create/edit jobs (client, location, service, price, payment tracking, status)
- Filterable jobs list with totals
- "Convert job to invoice" bridge that opens `index.html` with pre-filled data via `localStorage`

### Firebase Collections (all user-scoped by `userId` field)

| Collection   | Key Fields |
|--------------|-----------|
| `settings`   | `name`, `details`, `phone`, `mf`, `userId` |
| `clients`    | `name`, `address`, `email`, `phone`, `mf`, `userId` |
| `products`   | `name`, `description`, `price`, `currency`, `userId` |
| `invoices`   | `number`, `date`, `clientName`, `lines[]`, `subtotal`, `taxRate`, `taxAmount`, `discountRate`, `stampDuty`, `total`, `userId` |
| `jobs`       | `client`, `location`, `service`, `price`, `date`, `status`, `amountPaid`, `userId` |

All queries filter by `userId` from `firebase.auth().currentUser.uid`.

### Key Patterns

- **Real-time sync**: All collections use `onSnapshot` listeners, not one-shot `get()`. Listeners are attached after login.
- **Auth gate**: All Firebase operations are guarded by `firebase.auth().onAuthStateChanged`. On sign-out, listeners are detached and UI resets.
- **Cross-page communication**: `jobs.html` → `index.html` job-to-invoice conversion uses `localStorage` as message bus.
- **Print/PDF**: Invoice and job list print layouts are hidden `div`s revealed via `window.print()`. Tailwind's `print:` variants control what's shown on paper.
- **Firebase config**: Hardcoded in both HTML files (no `.env`). Project: `testf-2497a`.

## Firebase SDK

Loaded via CDN (compat v10 API):
```html
<script src="https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.12.2/firebase-auth-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore-compat.js"></script>
```

Use the `firebase.firestore()` / `firebase.auth()` compat namespace throughout — do not mix with the modular v9 import syntax.
