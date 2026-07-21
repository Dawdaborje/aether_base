DEFINE TABLE IF NOT EXISTS base_company_profile;
DEFINE FIELD IF NOT EXISTS legal_name ON TABLE base_company_profile TYPE string;
DEFINE FIELD IF NOT EXISTS trade_name ON TABLE base_company_profile TYPE option<string | NONE>;
DEFINE FIELD IF NOT EXISTS email ON TABLE base_company_profile TYPE option<string | NONE>
  ASSERT $value = NONE OR string::is_email($value);
DEFINE FIELD IF NOT EXISTS phone ON TABLE base_company_profile TYPE option<string | NONE>;
DEFINE FIELD IF NOT EXISTS website ON TABLE base_company_profile TYPE option<string | NONE>;
DEFINE FIELD IF NOT EXISTS vat ON TABLE base_company_profile TYPE option<string | NONE>;
DEFINE FIELD IF NOT EXISTS street ON TABLE base_company_profile TYPE option<string | NONE>;
DEFINE FIELD IF NOT EXISTS city ON TABLE base_company_profile TYPE option<string | NONE>;
DEFINE FIELD IF NOT EXISTS country_code ON TABLE base_company_profile TYPE option<string | NONE>;
DEFINE FIELD IF NOT EXISTS currency ON TABLE base_company_profile TYPE option<record<base_currency> | NONE>;
DEFINE FIELD IF NOT EXISTS logo_media_id ON TABLE base_company_profile TYPE option<string | NONE>;
DEFINE FIELD IF NOT EXISTS date_created ON TABLE base_company_profile TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS date_updated ON TABLE base_company_profile TYPE datetime VALUE time::now();
