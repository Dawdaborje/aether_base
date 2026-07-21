DEFINE TABLE IF NOT EXISTS base_currency;
DEFINE FIELD IF NOT EXISTS name ON TABLE base_currency TYPE string;
DEFINE FIELD IF NOT EXISTS symbol ON TABLE base_currency TYPE string;
DEFINE FIELD IF NOT EXISTS code ON TABLE base_currency TYPE string;
DEFINE FIELD IF NOT EXISTS decimal_places ON TABLE base_currency TYPE int DEFAULT 2;
DEFINE FIELD IF NOT EXISTS is_base ON TABLE base_currency TYPE bool DEFAULT false;
DEFINE FIELD IF NOT EXISTS active ON TABLE base_currency TYPE bool DEFAULT true;
DEFINE FIELD IF NOT EXISTS date_created ON TABLE base_currency TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS date_updated ON TABLE base_currency TYPE datetime VALUE time::now();
DEFINE INDEX IF NOT EXISTS base_currency_code ON TABLE base_currency COLUMNS code UNIQUE;

DEFINE TABLE IF NOT EXISTS base_currency_rate;
DEFINE FIELD IF NOT EXISTS currency ON TABLE base_currency_rate TYPE record<base_currency>;
DEFINE FIELD IF NOT EXISTS rate ON TABLE base_currency_rate TYPE float;
DEFINE FIELD IF NOT EXISTS rate_date ON TABLE base_currency_rate TYPE datetime;
DEFINE FIELD IF NOT EXISTS date_created ON TABLE base_currency_rate TYPE datetime DEFAULT time::now();
DEFINE INDEX IF NOT EXISTS base_currency_rate_unique ON TABLE base_currency_rate COLUMNS currency, rate_date UNIQUE;
