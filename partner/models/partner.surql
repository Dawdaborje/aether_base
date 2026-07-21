-- Org DB model: base_partner
DEFINE TABLE IF NOT EXISTS base_partner;

DEFINE FIELD IF NOT EXISTS name ON TABLE base_partner TYPE string;
DEFINE FIELD IF NOT EXISTS display_name ON TABLE base_partner TYPE option<string | NONE>;
DEFINE FIELD IF NOT EXISTS is_company ON TABLE base_partner TYPE bool DEFAULT false;
DEFINE FIELD IF NOT EXISTS is_customer ON TABLE base_partner TYPE bool DEFAULT true;
DEFINE FIELD IF NOT EXISTS is_vendor ON TABLE base_partner TYPE bool DEFAULT false;
DEFINE FIELD IF NOT EXISTS email ON TABLE base_partner TYPE option<string | NONE>
  ASSERT $value = NONE OR string::is_email($value);
DEFINE FIELD IF NOT EXISTS phone ON TABLE base_partner TYPE option<string | NONE>;
DEFINE FIELD IF NOT EXISTS mobile ON TABLE base_partner TYPE option<string | NONE>;
DEFINE FIELD IF NOT EXISTS website ON TABLE base_partner TYPE option<string | NONE>;
DEFINE FIELD IF NOT EXISTS vat ON TABLE base_partner TYPE option<string | NONE>;
DEFINE FIELD IF NOT EXISTS street ON TABLE base_partner TYPE option<string | NONE>;
DEFINE FIELD IF NOT EXISTS city ON TABLE base_partner TYPE option<string | NONE>;
DEFINE FIELD IF NOT EXISTS state ON TABLE base_partner TYPE option<string | NONE>;
DEFINE FIELD IF NOT EXISTS zip ON TABLE base_partner TYPE option<string | NONE>;
DEFINE FIELD IF NOT EXISTS country_code ON TABLE base_partner TYPE option<string | NONE>;
DEFINE FIELD IF NOT EXISTS parent ON TABLE base_partner TYPE option<record<base_partner> | NONE>;
DEFINE FIELD IF NOT EXISTS currency ON TABLE base_partner TYPE option<record<base_currency> | NONE>;
DEFINE FIELD IF NOT EXISTS notes ON TABLE base_partner TYPE option<string | NONE>;
DEFINE FIELD IF NOT EXISTS active ON TABLE base_partner TYPE bool DEFAULT true;
DEFINE FIELD IF NOT EXISTS date_created ON TABLE base_partner TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS date_updated ON TABLE base_partner TYPE datetime VALUE time::now();

DEFINE INDEX IF NOT EXISTS base_partner_email ON TABLE base_partner COLUMNS email;
DEFINE INDEX IF NOT EXISTS base_partner_name ON TABLE base_partner COLUMNS name;
