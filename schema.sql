-- =============================================================================
-- South African Municipal Electricity Tariff Database
-- Financial year 2026/27: tariffs effective 1 July 2026 to 30 June 2027
-- =============================================================================

PRAGMA foreign_keys = ON;

-- ---------------------------------------------------------------------------
-- Provinces
-- ---------------------------------------------------------------------------
CREATE TABLE provinces (
    code        TEXT PRIMARY KEY,          -- e.g. 'WC'
    name        TEXT NOT NULL UNIQUE       -- e.g. 'Western Cape'
);

-- ---------------------------------------------------------------------------
-- Municipalities (official Municipal Demarcation Board list: 257 in total —
-- 8 metropolitan (Cat A), 44 district (Cat C), 205 local (Cat B))
-- ---------------------------------------------------------------------------
CREATE TABLE municipalities (
    mdb_code       TEXT PRIMARY KEY,       -- official MDB code, e.g. 'CPT', 'WC023', 'DC2'
    name           TEXT NOT NULL,          -- short name, e.g. 'Drakenstein'
    official_name  TEXT NOT NULL,          -- e.g. 'Drakenstein Local Municipality'
    category       TEXT NOT NULL CHECK (category IN ('A','B','C')),
                                           -- A=metropolitan, B=local, C=district
    province_code  TEXT NOT NULL REFERENCES provinces(code),
    district_code  TEXT REFERENCES municipalities(mdb_code)
                                           -- parent district for Cat B; NULL for A and C
);

-- ---------------------------------------------------------------------------
-- Electricity distributors (NERSA licensees). Usually the municipality itself,
-- but sometimes a separate entity (City Power, CENTLEC) and some municipalities
-- are supplied directly by Eskom (no municipal distribution licence).
-- ---------------------------------------------------------------------------
CREATE TABLE distributors (
    id                INTEGER PRIMARY KEY,
    name              TEXT NOT NULL UNIQUE,   -- e.g. 'City Power Johannesburg (SOC) Ltd'
    municipality_code TEXT REFERENCES municipalities(mdb_code),
    distributor_type  TEXT NOT NULL CHECK (distributor_type IN
                        ('municipal','municipal_entity','national_utility','private')),
    notes             TEXT
);

-- ---------------------------------------------------------------------------
-- NERSA-approved average tariff increases per distributor per financial year
-- ---------------------------------------------------------------------------
CREATE TABLE approved_increases (
    id               INTEGER PRIMARY KEY,
    distributor_id   INTEGER NOT NULL REFERENCES distributors(id),
    financial_year   TEXT NOT NULL,           -- '2026/27'
    avg_increase_pct REAL,                    -- average % increase
    status           TEXT NOT NULL DEFAULT 'approved' CHECK (status IN
                       ('approved',           -- NERSA-approved / council-adopted final
                        'implemented',        -- confirmed in force from 1 July 2026
                        'proposed',           -- draft/budget proposal, final not confirmed
                        'application')),      -- as applied for to NERSA
    effective_from   TEXT NOT NULL,           -- '2026-07-01'
    effective_to     TEXT NOT NULL,           -- '2027-06-30'
    source_id        INTEGER REFERENCES sources(id),
    notes            TEXT,
    UNIQUE (distributor_id, financial_year)
);

-- ---------------------------------------------------------------------------
-- Tariff plans: a named tariff a customer can be on
-- ---------------------------------------------------------------------------
CREATE TABLE tariff_plans (
    id               INTEGER PRIMARY KEY,
    distributor_id   INTEGER NOT NULL REFERENCES distributors(id),
    code             TEXT,                    -- distributor's own code if any (e.g. 'Tariff A')
    name             TEXT NOT NULL,           -- e.g. 'Home User', 'Residential Prepaid Low'
    customer_class   TEXT NOT NULL CHECK (customer_class IN
                        ('residential','commercial','industrial','agricultural',
                         'streetlighting','public','resale','other')),
    metering         TEXT CHECK (metering IN ('conventional','prepaid','both', NULL)),
    structure        TEXT NOT NULL CHECK (structure IN
                        ('flat','inclining_block','time_of_use','demand','hybrid')),
    vat_treatment    TEXT NOT NULL CHECK (vat_treatment IN ('incl','excl','mixed','unknown')),
    valid_from       TEXT NOT NULL,           -- '2026-07-01'
    valid_to         TEXT NOT NULL,           -- '2027-06-30'
    verification     TEXT NOT NULL DEFAULT 'unverified' CHECK (verification IN
                        ('verified','partial','unverified')),
                       -- verified  = every component confirmed against a cited source
                       -- partial   = some components confirmed, gaps flagged in notes
    eligibility      TEXT,                    -- qualification rules in plain language
    notes            TEXT,
    UNIQUE (distributor_id, name, valid_from)
);

-- ---------------------------------------------------------------------------
-- Tariff components: the individual charges that make up a plan
-- ---------------------------------------------------------------------------
CREATE TABLE tariff_components (
    id             INTEGER PRIMARY KEY,
    plan_id        INTEGER NOT NULL REFERENCES tariff_plans(id),
    component_type TEXT NOT NULL CHECK (component_type IN
                     ('energy',            -- c/kWh consumption charge
                      'fixed',             -- R/day or R/month service/basic charge
                      'capacity',          -- R/month network capacity / R/amp
                      'demand',            -- R/kVA or R/kW maximum demand
                      'network_demand',    -- R/kVA network demand charge
                      'reactive_energy',   -- c/kvarh
                      'surcharge',         -- levies, riders
                      'credit')),          -- rebates / free basic electricity
    description    TEXT NOT NULL,
    rate           REAL,                   -- numeric value; NULL if published but unknown
    unit           TEXT NOT NULL,          -- 'c/kWh','R/month','R/day','R/kVA','R/amp','c/kvarh','kWh free'
    block_min_kwh  REAL,                   -- inclining-block lower bound (inclusive)
    block_max_kwh  REAL,                   -- upper bound (inclusive); NULL = unbounded
    tou_period     TEXT CHECK (tou_period IN ('peak','standard','off_peak', NULL)),
    season         TEXT NOT NULL DEFAULT 'all' CHECK (season IN ('all','high','low')),
                                           -- high = winter demand season (Jun–Aug)
    voltage_level  TEXT,                   -- e.g. 'LV', 'MV', '<500V', '11kV'
    vat_inclusive  INTEGER NOT NULL DEFAULT 0 CHECK (vat_inclusive IN (0,1)),
    source_id      INTEGER REFERENCES sources(id),
    notes          TEXT
);

-- ---------------------------------------------------------------------------
-- Tariff rules: structural/eligibility logic that isn't a simple charge
-- ---------------------------------------------------------------------------
CREATE TABLE tariff_rules (
    id          INTEGER PRIMARY KEY,
    plan_id     INTEGER NOT NULL REFERENCES tariff_plans(id),
    rule_type   TEXT NOT NULL CHECK (rule_type IN
                  ('inclining_block',   -- block structure definition
                   'tou_schedule',      -- time-of-use period definitions
                   'season_definition', -- high/low season months
                   'eligibility',       -- who qualifies for the plan
                   'free_basic',        -- free basic electricity allocation
                   'connection_limit',  -- amperage/supply size limits
                   'other')),
    description TEXT NOT NULL,
    params_json TEXT,                   -- machine-readable parameters (JSON)
    source_id   INTEGER REFERENCES sources(id)
);

-- ---------------------------------------------------------------------------
-- Sources: provenance for every figure
-- ---------------------------------------------------------------------------
CREATE TABLE sources (
    id            INTEGER PRIMARY KEY,
    url           TEXT NOT NULL UNIQUE,
    title         TEXT,
    publisher     TEXT,                  -- e.g. 'NERSA', 'City of Cape Town', 'BusinessTech'
    source_class  TEXT NOT NULL CHECK (source_class IN
                    ('regulator','municipality','utility','news','aggregator','other')),
    accessed_date TEXT NOT NULL          -- ISO date this source was checked
);

-- ---------------------------------------------------------------------------
-- Convenience views
-- ---------------------------------------------------------------------------
CREATE VIEW v_tariff_detail AS
SELECT
    m.province_code,
    m.name              AS municipality,
    m.mdb_code,
    d.name              AS distributor,
    p.name              AS tariff_plan,
    p.customer_class,
    p.structure,
    p.verification,
    c.component_type,
    c.description,
    c.rate,
    c.unit,
    c.block_min_kwh,
    c.block_max_kwh,
    c.tou_period,
    c.season,
    c.vat_inclusive,
    s.url               AS source_url
FROM tariff_components c
JOIN tariff_plans   p ON p.id = c.plan_id
JOIN distributors   d ON d.id = p.distributor_id
LEFT JOIN municipalities m ON m.mdb_code = d.municipality_code
LEFT JOIN sources   s ON s.id = c.source_id;

CREATE VIEW v_municipality_summary AS
SELECT
    m.mdb_code,
    m.official_name,
    m.category,
    m.province_code,
    d.name  AS distributor,
    ai.avg_increase_pct AS approved_increase_2026_27,
    COUNT(DISTINCT p.id)  AS tariff_plans_captured
FROM municipalities m
LEFT JOIN distributors d       ON d.municipality_code = m.mdb_code
LEFT JOIN approved_increases ai ON ai.distributor_id = d.id AND ai.financial_year = '2026/27'
LEFT JOIN tariff_plans p        ON p.distributor_id = d.id
GROUP BY m.mdb_code, d.id;
