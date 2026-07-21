DEFINE TABLE IF NOT EXISTS base_uom_category;
DEFINE FIELD IF NOT EXISTS name ON TABLE base_uom_category TYPE string;
DEFINE FIELD IF NOT EXISTS date_created ON TABLE base_uom_category TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS date_updated ON TABLE base_uom_category TYPE datetime VALUE time::now();
DEFINE INDEX IF NOT EXISTS base_uom_category_name ON TABLE base_uom_category COLUMNS name UNIQUE;

DEFINE TABLE IF NOT EXISTS base_uom;
DEFINE FIELD IF NOT EXISTS name ON TABLE base_uom TYPE string;
DEFINE FIELD IF NOT EXISTS category ON TABLE base_uom TYPE record<base_uom_category>;
DEFINE FIELD IF NOT EXISTS factor ON TABLE base_uom TYPE float DEFAULT 1.0;
DEFINE FIELD IF NOT EXISTS rounding ON TABLE base_uom TYPE float DEFAULT 0.01;
DEFINE FIELD IF NOT EXISTS is_reference ON TABLE base_uom TYPE bool DEFAULT false;
DEFINE FIELD IF NOT EXISTS active ON TABLE base_uom TYPE bool DEFAULT true;
DEFINE FIELD IF NOT EXISTS date_created ON TABLE base_uom TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS date_updated ON TABLE base_uom TYPE datetime VALUE time::now();
DEFINE INDEX IF NOT EXISTS base_uom_name ON TABLE base_uom COLUMNS name;
