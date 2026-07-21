DEFINE TABLE IF NOT EXISTS base_product;
DEFINE FIELD IF NOT EXISTS name ON TABLE base_product TYPE string;
DEFINE FIELD IF NOT EXISTS code ON TABLE base_product TYPE option<string | NONE>;
DEFINE FIELD IF NOT EXISTS product_type ON TABLE base_product TYPE string DEFAULT "consu";
-- consu | service | stock
DEFINE FIELD IF NOT EXISTS list_price ON TABLE base_product TYPE float DEFAULT 0.0;
DEFINE FIELD IF NOT EXISTS cost ON TABLE base_product TYPE float DEFAULT 0.0;
DEFINE FIELD IF NOT EXISTS currency ON TABLE base_product TYPE option<record<base_currency> | NONE>;
DEFINE FIELD IF NOT EXISTS uom ON TABLE base_product TYPE option<record<base_uom> | NONE>;
DEFINE FIELD IF NOT EXISTS description ON TABLE base_product TYPE option<string | NONE>;
DEFINE FIELD IF NOT EXISTS active ON TABLE base_product TYPE bool DEFAULT true;
DEFINE FIELD IF NOT EXISTS date_created ON TABLE base_product TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS date_updated ON TABLE base_product TYPE datetime VALUE time::now();
DEFINE INDEX IF NOT EXISTS base_product_code ON TABLE base_product COLUMNS code UNIQUE;
DEFINE INDEX IF NOT EXISTS base_product_name ON TABLE base_product COLUMNS name;
