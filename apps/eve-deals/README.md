# EVE Deals Finder

A local Flask web app that logs into EVE Online via SSO, finds your current
solar system, and scans public contracts in that system and a reference
system of your choosing for good deals — item-exchange contracts priced well
below a fair market value.

**Fair value pricing:** for each item in a contract, the app pulls current
sell orders for that item in the region, drops the single highest and single
lowest price (unless there's only one order), and averages the rest. This
keeps one junk listing from skewing the reference price. A contract is
flagged as a deal if its total price is at least 15% below this fair value
(see `DEAL_DISCOUNT_THRESHOLD_PCT` in `eve_deals/config.py`).

## Setup

### 1. Register an EVE SSO application

1. Go to https://developers.eveonline.com/applications and log in with your
   EVE Online account.
2. Create a new application:
   - **Connection Type:** Authentication & API Access
   - **Permissions (scopes):** `esi-location.read_location.v1`
   - **Callback URL:** `http://localhost:5000/auth/callback`
3. Copy the generated **Client ID** and **Secret Key**.

### 2. Configure the app

```bash
cd apps/eve-deals
cp .env.example .env
```

Edit `.env` and fill in `ESI_CLIENT_ID` and `ESI_CLIENT_SECRET` from step 1.

### 3. Install dependencies and run

```bash
python -m venv .venv
source .venv/bin/activate   # or .venv\Scripts\activate on Windows
pip install -r requirements.txt
python app.py
```

Open http://localhost:5000, click **Login with EVE Online**, authorize the
app, then enter a reference system (e.g. `Jita`) and click **Poll**.

## How it works

1. EVE SSO login gives an OAuth2 token identifying your character and
   granting permission to read its current location.
2. `GET /characters/{id}/location/` returns your current solar system.
3. Contracts are only queryable **per region**, so the app resolves each
   target system to its region, pulls all public contracts in that region,
   then filters down to contracts whose start location is in the target
   system.
4. Each item-exchange contract's items are priced via the trimmed-mean
   market logic above; contracts beating the discount threshold are saved
   locally (SQLite) and shown in the results table.

All data — OAuth tokens, universe lookups cache, and found deals — is stored
locally in `eve_deals.db` (SQLite). Nothing leaves your machine except calls
to EVE's own ESI API.

## Notes / limitations

- Player-owned structures (citadels) can only be resolved to a system if
  your token has docking/structure access; contracts starting at
  inaccessible structures are skipped rather than causing an error.
- No TTL/expiry on cached universe lookups (station→system, system→region)
  since that data never changes. The `deals` table accumulates a history of
  every poll; there's no cleanup job.
