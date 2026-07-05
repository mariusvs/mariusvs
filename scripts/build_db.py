#!/usr/bin/env python3
"""Build db/tariffs.db from schema.sql and the JSON seed files in data/.

Usage:  python3 scripts/build_db.py
"""
import json
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DB_PATH = ROOT / "db" / "tariffs.db"
SCHEMA = ROOT / "schema.sql"
MUNIS = ROOT / "data" / "municipalities.json"
TARIFF_DIR = ROOT / "data" / "tariffs"


def load_municipalities(con):
    data = json.loads(MUNIS.read_text(encoding="utf-8"))
    con.executemany(
        "INSERT INTO provinces (code, name) VALUES (?, ?)",
        [(p["code"], p["name"]) for p in data["provinces"]],
    )
    rows = [
        (m["code"], m["name"], m["official_name"], m["category"], m["province"], m["district"])
        for m in data["municipalities"]
    ]
    con.executemany(
        "INSERT INTO municipalities (mdb_code, name, official_name, category, province_code, district_code)"
        " VALUES (?, ?, ?, ?, ?, ?)",
        rows,
    )
    return len(rows)


def get_source_id(con, cache, url, publisher=None, source_class="news", title=None, accessed="2026-07-05"):
    if url in cache:
        return cache[url]
    cur = con.execute(
        "INSERT OR IGNORE INTO sources (url, title, publisher, source_class, accessed_date)"
        " VALUES (?, ?, ?, ?, ?)",
        (url, title, publisher, source_class, accessed),
    )
    row = con.execute("SELECT id FROM sources WHERE url = ?", (url,)).fetchone()
    cache[url] = row[0]
    return row[0]


def load_tariff_file(con, path, src_cache):
    doc = json.loads(path.read_text(encoding="utf-8"))
    d = doc["distributor"]
    con.execute(
        "INSERT INTO distributors (name, municipality_code, distributor_type, notes)"
        " VALUES (?, ?, ?, ?)",
        (d["name"], d.get("municipality_code"), d.get("type", "municipal"), d.get("notes")),
    )
    dist_id = con.execute("SELECT id FROM distributors WHERE name = ?", (d["name"],)).fetchone()[0]

    inc = doc.get("approved_increase")
    if inc:
        src_id = None
        if inc.get("source"):
            s = inc["source"]
            src_id = get_source_id(con, src_cache, s["url"], s.get("publisher"), s.get("class", "news"))
        con.execute(
            "INSERT INTO approved_increases (distributor_id, financial_year, avg_increase_pct,"
            " status, effective_from, effective_to, source_id, notes)"
            " VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (dist_id, inc.get("financial_year", "2026/27"), inc.get("avg_increase_pct"),
             inc.get("status", "approved"),
             inc.get("effective_from", "2026-07-01"), inc.get("effective_to", "2027-06-30"),
             src_id, inc.get("notes")),
        )

    n_plans = n_comp = 0
    for plan in doc.get("tariff_plans", []):
        con.execute(
            "INSERT INTO tariff_plans (distributor_id, code, name, customer_class, metering,"
            " structure, vat_treatment, valid_from, valid_to, verification, eligibility, notes)"
            " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (dist_id, plan.get("code"), plan["name"], plan["customer_class"], plan.get("metering"),
             plan["structure"], plan.get("vat_treatment", "unknown"),
             plan.get("valid_from", "2026-07-01"), plan.get("valid_to", "2027-06-30"),
             plan.get("verification", "unverified"), plan.get("eligibility"), plan.get("notes")),
        )
        plan_id = con.execute(
            "SELECT id FROM tariff_plans WHERE distributor_id = ? AND name = ? AND valid_from = ?",
            (dist_id, plan["name"], plan.get("valid_from", "2026-07-01")),
        ).fetchone()[0]
        n_plans += 1

        for c in plan.get("components", []):
            src_id = None
            if c.get("source"):
                s = c["source"]
                src_id = get_source_id(con, src_cache, s["url"], s.get("publisher"), s.get("class", "news"))
            con.execute(
                "INSERT INTO tariff_components (plan_id, component_type, description, rate, unit,"
                " block_min_kwh, block_max_kwh, tou_period, season, voltage_level, vat_inclusive,"
                " source_id, notes) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (plan_id, c["component_type"], c["description"], c.get("rate"), c["unit"],
                 c.get("block_min_kwh"), c.get("block_max_kwh"), c.get("tou_period"),
                 c.get("season", "all"), c.get("voltage_level"),
                 1 if c.get("vat_inclusive") else 0, src_id, c.get("notes")),
            )
            n_comp += 1

        for r in plan.get("rules", []):
            src_id = None
            if r.get("source"):
                s = r["source"]
                src_id = get_source_id(con, src_cache, s["url"], s.get("publisher"), s.get("class", "news"))
            con.execute(
                "INSERT INTO tariff_rules (plan_id, rule_type, description, params_json, source_id)"
                " VALUES (?, ?, ?, ?, ?)",
                (plan_id, r["rule_type"], r["description"],
                 json.dumps(r.get("params")) if r.get("params") is not None else None, src_id),
            )
    return doc["distributor"]["name"], n_plans, n_comp


def main():
    DB_PATH.parent.mkdir(exist_ok=True)
    if DB_PATH.exists():
        DB_PATH.unlink()
    con = sqlite3.connect(DB_PATH)
    con.executescript(SCHEMA.read_text(encoding="utf-8"))

    n = load_municipalities(con)
    print(f"municipalities: {n}")

    src_cache = {}
    for path in sorted(TARIFF_DIR.glob("*.json")):
        name, plans, comps = load_tariff_file(con, path, src_cache)
        print(f"{path.name}: {name} — {plans} plans, {comps} components")

    con.commit()

    cats = dict(con.execute("SELECT category, COUNT(*) FROM municipalities GROUP BY category").fetchall())
    print(f"category counts: A={cats.get('A', 0)} B={cats.get('B', 0)} C={cats.get('C', 0)}")
    if (cats.get("A"), cats.get("B"), cats.get("C")) != (8, 205, 44):
        print("ERROR: municipality counts do not match official 8/205/44", file=sys.stderr)
        sys.exit(1)
    con.close()
    print(f"built {DB_PATH}")


if __name__ == "__main__":
    main()
