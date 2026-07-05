#!/usr/bin/env python3
"""Validation checks for db/tariffs.db.

Usage:  python3 scripts/validate.py
Exits non-zero if any check fails.
"""
import sqlite3
import sys
from pathlib import Path

DB = Path(__file__).resolve().parent.parent / "db" / "tariffs.db"

failures = []


def check(name, ok, detail=""):
    status = "PASS" if ok else "FAIL"
    print(f"[{status}] {name}" + (f" — {detail}" if detail else ""))
    if not ok:
        failures.append(name)


con = sqlite3.connect(DB)

# 1. Municipality counts match the official MDB structure
a, b, c = [con.execute("SELECT COUNT(*) FROM municipalities WHERE category=?", (x,)).fetchone()[0]
           for x in ("A", "B", "C")]
check("257 municipalities (8 metro / 205 local / 44 district)",
      (a, b, c) == (8, 205, 44), f"got A={a} B={b} C={c}")

# 2. Every local municipality has a valid district parent
orphans = con.execute(
    "SELECT COUNT(*) FROM municipalities m WHERE m.category='B' AND (m.district_code IS NULL"
    " OR NOT EXISTS (SELECT 1 FROM municipalities d WHERE d.mdb_code=m.district_code AND d.category='C'))"
).fetchone()[0]
check("all locals linked to a valid district", orphans == 0, f"{orphans} orphans")

# 3. Metros/districts have no district parent
bad = con.execute(
    "SELECT COUNT(*) FROM municipalities WHERE category IN ('A','C') AND district_code IS NOT NULL"
).fetchone()[0]
check("metros/districts have no parent district", bad == 0)

# 4. No duplicate municipality names within a province+category
dupes = con.execute(
    "SELECT COUNT(*) FROM (SELECT name, province_code, category FROM municipalities"
    " GROUP BY name, province_code, category HAVING COUNT(*) > 1)"
).fetchone()[0]
check("no duplicate names within province+category", dupes == 0)

# 5. All tariff plans fall inside FY 2026/27
bad = con.execute(
    "SELECT COUNT(*) FROM tariff_plans WHERE valid_from != '2026-07-01' OR valid_to != '2027-06-30'"
).fetchone()[0]
check("all plans valid 2026-07-01 → 2027-06-30", bad == 0)

# 6. Rates are positive where present (credits may be zero/negative)
bad = con.execute(
    "SELECT COUNT(*) FROM tariff_components WHERE rate IS NOT NULL AND rate < 0"
    " AND component_type != 'credit'"
).fetchone()[0]
check("no negative rates outside credits", bad == 0)

# 7. Inclining blocks: no overlaps within a plan/season/tou slice
overlaps = con.execute("""
    SELECT COUNT(*) FROM tariff_components x
    JOIN tariff_components y ON x.plan_id = y.plan_id AND x.id < y.id
      AND x.component_type = 'energy' AND y.component_type = 'energy'
      AND IFNULL(x.tou_period,'') = IFNULL(y.tou_period,'')
      AND x.season = y.season
      AND x.block_min_kwh IS NOT NULL AND y.block_min_kwh IS NOT NULL
      AND x.block_min_kwh < IFNULL(y.block_max_kwh, 1e12)
      AND y.block_min_kwh < IFNULL(x.block_max_kwh, 1e12)
""").fetchone()[0]
check("no overlapping consumption blocks", overlaps == 0, f"{overlaps} overlaps")

# 8. Every component with a rate cites a source
uncited = con.execute(
    "SELECT COUNT(*) FROM tariff_components WHERE rate IS NOT NULL AND source_id IS NULL"
).fetchone()[0]
check("every priced component has a source", uncited == 0, f"{uncited} uncited")

# 9. Verified plans have no NULL-rate components
bad = con.execute("""
    SELECT COUNT(*) FROM tariff_plans p WHERE p.verification = 'verified'
    AND EXISTS (SELECT 1 FROM tariff_components c WHERE c.plan_id = p.id AND c.rate IS NULL)
""").fetchone()[0]
check("'verified' plans have no missing rates", bad == 0)

# 10. Distributors reference real municipalities
bad = con.execute(
    "SELECT COUNT(*) FROM distributors d WHERE d.municipality_code IS NOT NULL AND NOT EXISTS"
    " (SELECT 1 FROM municipalities m WHERE m.mdb_code = d.municipality_code)"
).fetchone()[0]
check("distributor municipality codes resolve", bad == 0)

con.close()
if failures:
    print(f"\n{len(failures)} check(s) failed", file=sys.stderr)
    sys.exit(1)
print("\nall checks passed")
