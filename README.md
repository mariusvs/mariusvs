# South African Municipal Electricity Tariff Database — FY 2026/27

SQLite database of municipal electricity tariffs for the financial year
**1 July 2026 to 30 June 2027**, as approved by NERSA (the National Energy
Regulator of South Africa approved all 176 licensed municipal and private
distributor tariffs by 27 May 2026; national average increase **9.01%**).

## Contents

| Path | Description |
|---|---|
| `db/tariffs.db` | The built SQLite database |
| `schema.sql` | Full schema (tables, constraints, views) |
| `data/municipalities.json` | All **257** official municipalities (8 metro / 44 district / 205 local) with MDB codes, official names, provinces and district links |
| `data/tariffs/*.json` | Per-distributor tariff source files (one per distributor, named by MDB code) |
| `scripts/build_db.py` | Rebuilds `db/tariffs.db` from schema + data files |
| `scripts/validate.py` | 10 integrity checks (counts, naming, block continuity, provenance, verification consistency) |

Rebuild and validate:

```bash
python3 scripts/build_db.py
python3 scripts/validate.py
```

## Schema overview

- **municipalities** — the complete official list (Municipal Demarcation Board codes and official names). Every one of the 257 municipalities is present and correctly categorised (A=metro, B=local, C=district) with locals linked to their parent district.
- **distributors** — NERSA electricity licensees (the municipality itself, a municipal entity such as City Power or CENTLEC, or Eskom for direct-supply areas).
- **approved_increases** — the 2026/27 average % increase per distributor, with a `status` column that distinguishes `approved` / `implemented` from `proposed` / `application` figures so draft numbers are never mistaken for final ones.
- **tariff_plans** — named tariffs (e.g. Cape Town "Home User", Ekurhuleni "Tariff A.2"), with customer class, structure (flat / inclining block / time-of-use / demand / hybrid), VAT treatment, validity window and a `verification` flag.
- **tariff_components** — the individual charges: energy (c/kWh with block ranges or TOU period/season), fixed (R/month), capacity, demand (R/kVA), reactive energy, surcharges and credits (e.g. free basic electricity). Every priced component cites a source.
- **tariff_rules** — structural logic: block definitions, TOU schedules, season definitions, eligibility, free-basic allocations, connection limits.
- **sources** — provenance for every figure (regulator / municipality / utility / news), with access date.
- Views: `v_tariff_detail` (flat component-level view) and `v_municipality_summary`.

## Example queries

```sql
-- All verified rates with sources
SELECT * FROM v_tariff_detail WHERE rate IS NOT NULL;

-- 2026/27 increases, highest first (status shows approved vs proposed)
SELECT d.name, ai.avg_increase_pct, ai.status
FROM approved_increases ai JOIN distributors d ON d.id = ai.distributor_id
ORDER BY ai.avg_increase_pct DESC;

-- Cape Town residential blocks
SELECT tariff_plan, description, rate, unit
FROM v_tariff_detail WHERE mdb_code = 'CPT' AND customer_class = 'residential';
```

## Data status and honesty notes (read this)

Every number in this database was captured on **2026-07-05** from cited public
sources, with a hard rule: **no rate was estimated, extrapolated or carried
over from 2025/26**. Where an exact 2026/27 figure could not be verified, the
component is present with `rate = NULL` and a note saying where the official
figure lives, and the plan is marked `partial` or `unverified` — not filled
with a guess.

Current coverage:

- **257 / 257 municipalities** listed with correct official names and MDB codes.
- **23 distributors** loaded (all 8 metros, Eskom, and 14 significant locals) with their 2026/27 increase percentages and status.
- **Component-level verified rates** for: City of Cape Town (residential tariffs largely complete), Overstrand (full prepaid block structure), George (prepaid rate), plus verified fixed charges for City Power (R70 service + R140 network capacity), CENTLEC (R50 basic — deferred by council 29 June 2026; R322.11 business prepaid) and Buffalo City (R487 prepaid basic, draft-stage).
- **Structural rules** verified for 2026/27: Ekurhuleni abolished its residential inclining-block tariff (flat rate above 50 kWh, seasonal); eThekwini uses flat rates per class with no blocks; City Power indigent exemption (R210/month); NERSA national Free Basic Electricity rate 238.60 c/kWh.

Known limitations:

- Exact c/kWh schedules for Johannesburg, Tshwane, Ekurhuleni, eThekwini,
  Nelson Mandela Bay, Buffalo City, Mangaung and Msunduzi are published only
  in official PDFs (URLs recorded in the data files) that were not reachable
  from this environment's network policy. The JSON files are structured so
  those numbers can be dropped in and the DB rebuilt in minutes.
- NERSA's consolidated decision documents (nersa.org.za) were also
  unreachable; the remaining ~150 smaller distributors' schedules can be
  ingested from there using the same file format.
- Conflicting figures found in sources are recorded in `notes` rather than
  silently resolved (e.g. Ekurhuleni 8.76% official vs 12.7% press roundup;
  NMB 10.95% vs 10.09%; City Power's R140 network charge vs a "held flat"
  statement).

### Key official source documents for completing rates

- Johannesburg: `joburg.org.za/documents_/Documents/TARIFFS/Approved-Tariffs-20262027.pdf`
- Cape Town: Budget 2026/27 Annexure 6 (`resource.capetown.gov.za` — Electricity Consumptive Tariffs)
- eThekwini: `durban.gov.za/uploads/0000/13/2026/06/01/final-tariff-tables-2026-2027.pdf`
- Ekurhuleni: Schedule 2 of Electricity Tariffs 2026/27 (`ekurhuleni.gov.za`)
- Buffalo City: `AnnexureF-BCMMtariffBook20March2026.pdf` (`buffalocity.gov.za`)
- Tshwane: promulgated Gauteng Provincial Gazette schedule (via `tshwane.gov.za/?page_id=6924`)
- NERSA reasons-for-decision per distributor: `nersa.org.za` (published 30 June 2026)

## Adding / completing a distributor

1. Create or edit `data/tariffs/<MDB_CODE>.json` (copy `WC032.json` as a fully-worked example).
2. Fill `rate` values only from an official schedule; set `vat_inclusive` correctly; cite a `source` for every priced component.
3. Set plan `verification` to `verified` only when every component is confirmed.
4. Run `python3 scripts/build_db.py && python3 scripts/validate.py`.
