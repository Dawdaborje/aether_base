DEFINE TABLE IF NOT EXISTS base_sequence;

DEFINE FIELD IF NOT EXISTS name ON TABLE base_sequence TYPE string;
DEFINE FIELD IF NOT EXISTS code ON TABLE base_sequence TYPE string;
DEFINE FIELD IF NOT EXISTS prefix ON TABLE base_sequence TYPE option<string | NONE> DEFAULT "";
DEFINE FIELD IF NOT EXISTS suffix ON TABLE base_sequence TYPE option<string | NONE> DEFAULT "";
DEFINE FIELD IF NOT EXISTS padding ON TABLE base_sequence TYPE int DEFAULT 5;
DEFINE FIELD IF NOT EXISTS next_number ON TABLE base_sequence TYPE int DEFAULT 1;
DEFINE FIELD IF NOT EXISTS step ON TABLE base_sequence TYPE int DEFAULT 1;
DEFINE FIELD IF NOT EXISTS use_date_range ON TABLE base_sequence TYPE bool DEFAULT false;
DEFINE FIELD IF NOT EXISTS active ON TABLE base_sequence TYPE bool DEFAULT true;
DEFINE FIELD IF NOT EXISTS date_created ON TABLE base_sequence TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS date_updated ON TABLE base_sequence TYPE datetime VALUE time::now();

DEFINE INDEX IF NOT EXISTS base_sequence_code ON TABLE base_sequence COLUMNS code UNIQUE;
