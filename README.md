# Shop Manager (Flutter + Node.js) — SRE-style Documentation

A multi-platform Flutter client paired with a Node.js/Express backend that manages products, cashiers, and sales for small shops. Owners can manage inventory, view reports and activity, and provision cashier accounts; cashiers can sell items and view their own sales history.

This README is structured to cover architecture, setup, run procedures, role and permissions, functional flows, APIs, operational runbooks, and troubleshooting like an SRE handbook.

---

## 1. Architecture Overview

- Frontend: Flutter app (Web, Android, iOS, Windows, macOS, Linux)
  - Key screens: Welcome, Login, Register (Owner-only), Owner Dashboard (Home, Items, Transactions, Settings), Cashier Product Page
  - Auth: JWT token returned by backend; role provided by backend (OWNER or CASHIER)
- Backend: Node.js + Express
  - Database: PostgreSQL via `db.js` pool
  - Auth: `/login` issues JWT with `{ id, username, role }`
  - Public registration: `/register` creates OWNER accounts only
  - Owner-only: `/cashiers` to manage cashier accounts; `/reports/*` and `/activity`
  - Shared: `/products`, `/sales` (role-gated behavior)
- Data model (at minimum): `users (username, password hash, role)`, `products (name, price, stock_quantity)`, `sales`, and `activity_logs`

### Directory Structure
```
login_ui/
  lib/                   # Flutter client (app UI/logic)
  backend/               # Additional backend artifacts (migrations, etc.)
  index.js               # Express server
  db.js                  # PostgreSQL connection
  pubspec.yaml           # Flutter dependencies
  package.json           # Backend dependencies
  android/ ios/ web/ ... # Flutter platform scaffolding
```

---

## 2. Prerequisites

- Flutter SDK (3.x recommended)
- Node.js (>= 18)
- PostgreSQL (local or remote)
- Windows PowerShell (your shell)

### Environment Variables (Backend)
Create a `.env` file in project root:
```
DATABASE_URL=postgres://user:pass@localhost:5432/shopdb
JWT_SECRET=your-production-secret
PORT=5000
```
If you don’t use `DATABASE_URL`, ensure `db.js` reads from your local connection settings.

---

## 3. Setup & Installation

### Backend
- Install dependencies:
```powershell
npm install
```
- Apply SQL migrations to your Postgres database (sample migrations in `backend/migrations`):
```powershell
psql -h localhost -U postgres -d shopdb -f backend/migrations/001_create_sales.sql
psql -h localhost -U postgres -d shopdb -f backend/migrations/002_create_activity_logs.sql
```
Note: The server also creates `activity_logs` table at startup if missing, but you should apply core schema (users, products, sales) during initial setup.

### Frontend (Flutter)
- Fetch packages:
```powershell
flutter pub get
```
- Optional: Configure Firebase hosting or platform-specific assets (not required to run).

---

## 4. Running Locally

### Start Backend (Express)
```powershell
node index.js
```
The server listens on `http://localhost:5000` by default.

### Start Flutter App (Web)
```powershell
flutter run -d chrome
```
You can also run on Android/iOS or desktop targets, e.g.:
```powershell
flutter run -d windows
```

### API Base URL
Update the Flutter config in `lib/config/api.dart` to point to the backend:
- Example content:
```dart
class ApiConfig {
  static const String baseUrl = 'http://localhost:5000';
}
```
If running on a device/emulator, adjust to reachable host (e.g., your machine IP).

---

## 5. Roles & Permissions

- OWNER
  - Can register via public `/register` (creates OWNER)
  - Can create cashiers via `/cashiers` (owner-only, sets role=CASHIER)
  - Can manage products (`POST/PUT/DELETE /products`)
  - Can view all sales and reports (`GET /sales`, `/reports/*`, `/activity`)
  - Sees Owner Dashboard (Home, Items, Transactions, Settings)
- CASHIER
  - Cannot self-register; no public cashier registration
  - Can login via `/login` with provided credentials
  - Can list products (`GET /products`)
  - Can record sales (`POST /sales`)
  - Can view only their own sales (`GET /sales` filtered by cashier_id)
  - Sees Cashier Product Page (with logout)

Enforcement is handled server-side via JWT role checks and middleware.

---

## 6. Functional Flow (User Journey)

- Welcome
  - CTA to Login or Register
- Register (Owner only)
  - Submits `username`, `password` to `/register`
  - Backend creates `role='OWNER'`
  - Redirect to Login
- Login
  - Submits credentials to `/login`
  - Backend returns `{ token, role }`
  - Frontend routes based on role:
    - OWNER → `MainDashboardPage`
    - CASHIER → `ProductPage`
- Owner Dashboard (`MainDashboardPage`)
  - HomeView: Summary stats (products, cashiers, revenue, orders, items), heatmap, recent activity
  - ItemsView: List products, add/edit/delete (owner-only)
  - TransactionsView: List sales; owners also see recent activity
  - SettingsView: Role info and Cashier Management (list, add cashier)
  - AppBar actions include logout for owners
- Cashier Product Page (`ProductPage`)
  - List products and search
  - Record sales via the backend
  - AppBar includes logout; optional reports shortcut is visible only to owners

---

## 7. API Endpoints (Summary)

Auth
- POST `/register` — Public; creates OWNER account
  - body: `{ username, password }`
  - response: `201 Created`
- POST `/login` — Public; returns JWT and role
  - body: `{ username, password }`
  - response: `{ token, role }`

Products
- GET `/products` — Auth required (OWNER or CASHIER)
- POST `/products` — OWNER only
- PUT `/products/:id` — OWNER only
- DELETE `/products/:id` — OWNER only

Sales
- POST `/sales` — Auth required (OWNER or CASHIER); cashier_id from JWT
- GET `/sales` — Auth required (OWNER or CASHIER)
  - OWNER: returns all
  - CASHIER: returns own
  - query params: `from`, `to` optional

Reports & Activity (OWNER)
- GET `/reports/summary` — OWNER only
- GET `/reports/heatmap?days=90` — OWNER only
- GET `/activity?limit=200` — OWNER only

Cashier Management (OWNER)
- GET `/cashiers` — OWNER only
- POST `/cashiers` — OWNER only
  - body: `{ username, password }`
  - role assigned server-side to `CASHIER`

Auth Middleware
- `authMiddleware`: validates JWT and adds `req.user`
- `ownerOnly`: allows only OWNER
- `ownerOrCashier`: allows OWNER or CASHIER

---

## 8. Data & Tables (indicative)

- `users`
  - `id`, `username` (unique), `password` (hash), `role` ('OWNER'|'CASHIER'), `created_at`
- `products`
  - `id`, `name`, `price`, `stock_quantity`, `created_at`, `updated_at`
- `sales`
  - `id`, `product_id`, `cashier_id`, `quantity`, `unit_price`, `total_price`, `created_at`
- `activity_logs`
  - `id`, `actor_id`, `actor_role`, `action`, `product_id`, `details` (json), `created_at`

Migrations are located under `backend/migrations`; some tables (activity_logs) are ensured at server startup.

---

## 9. Operational Runbooks (SRE)

### 9.1. Startup
- Preconditions: DB reachable, `.env` configured
- Sequence:
  1. Start Postgres
  2. Apply migrations (if first install)
  3. Run backend
  4. Launch Flutter app
- Health check: `GET /health` should return `{ status: 'ok' }`

### 9.2. Provisioning
- Create first Owner via Register
- Owner logs in
- Owner creates Cashiers via Settings → Add Cashier (POST `/cashiers`)

### 9.3. Backups
- Database: Daily pg_dump of `shopdb`
- App config: Backup `.env` securely

### 9.4. Monitoring
- Logs: Use `node index.js` output; ship to a log aggregator in production
- Metrics:
  - Request rate per endpoint
  - Error rates (`5xx`, `4xx`)
  - Sales throughput and revenue
  - DB connection pool utilization
- Alerts:
  - Elevated `500` responses
  - Authentication failures spike
  - DB connectivity failures

### 9.5. Incident Response
- Symptoms: 500 errors, login failures, empty product list
- Standard Checks:
  - Backend up? `GET /health`
  - DB connectivity OK? Review `db.js` and environment variables
  - JWT secret consistent? Ensure `JWT_SECRET`
  - Cross-origin policy? Confirm `cors()` configured in `index.js`
- Rollback/Hotfix:
  - Revert recent deployment if applicable
  - Increase DB pool or fix slow queries

### 9.6. Deployment
- Backend
  - Use process manager (PM2/systemd)
  - Set `PORT`, `JWT_SECRET`, and DB envs
- Frontend
  - Flutter Web: `flutter build web` then host via Nginx/Netlify/etc.
  - Mobile/Desktop: standard platform builds

---

## 10. Security & Hardening

- Passwords hashed with bcrypt
- JWT secret must be strong and rotated periodically
- Rate-limit auth routes in production
- Enforce HTTPS and secure CORS
- Restrict `/cashiers`, `/reports/*`, and `/activity` to OWNER via server-side checks
- Validate all inputs (`username`, `password`, product CRUD) and sanitize errors

---

## 11. Testing & Quality Gates

- Build: Flutter `flutter analyze` and `flutter test`; Node `npm test` (if configured)
- Unit/Integration: Add tests for
  - Auth: login success/fail
  - Role enforcement: OWNER vs CASHIER endpoints
  - Product CRUD: owner-only
  - Sales record: cashier flow updates stock and logs activity
- Smoke Test:
  1. Register Owner
  2. Login Owner → Dashboard loads with summary
  3. Add product → ItemsView lists it
  4. Add cashier → appears in Settings
  5. Login Cashier → ProductPage loads
  6. Record sale → stock decremented; transaction listed; activity logged

---

## 12. Troubleshooting

- Login fails with "User not found"
  - Ensure registration completed and DB contains the user
- Login fails with 400 "Invalid password"
  - Verify credentials and bcrypt hashing
- 401 "No token provided" or "Invalid token"
  - Confirm frontend stores and includes `Authorization: Bearer <token>`
- Owner pages show empty summary or heatmap
  - Check that `/reports/*` and `/activity` are reachable and the user is OWNER
- Product CRUD returns 403
  - Ensure JWT role is OWNER; cashier cannot manage products
- Sales returns 400 "Insufficient stock"
  - Adjust product stock or quantity

---

## 13. Maintenance Notes

- Keep dependencies up to date (`npm outdated`, `flutter pub outdated`)
- Pin critical versions in production
- Review CVEs periodically for Node/Flutter dependencies
- Add DB indexes for frequent queries (products name, sales created_at)

---

## 14. License

Add your preferred license (MIT/Apache-2.0/etc.).

---

## 15. Quick Start (TL;DR)

```powershell
# Backend
npm install
$env:DATABASE_URL="postgres://user:pass@localhost:5432/shopdb"; $env:JWT_SECRET="secret"; $env:PORT=5000
node index.js

# Frontend
flutter pub get
flutter run -d chrome
```

Configure `lib/config/api.dart` to point to your backend URL.
