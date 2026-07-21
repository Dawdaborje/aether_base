DEFINE TABLE IF NOT EXISTS base_attachment;
DEFINE FIELD IF NOT EXISTS name ON TABLE base_attachment TYPE string;
DEFINE FIELD IF NOT EXISTS model ON TABLE base_attachment TYPE string;
DEFINE FIELD IF NOT EXISTS res_id ON TABLE base_attachment TYPE string;
-- Pointer to org `media` row id (kernel media table)
DEFINE FIELD IF NOT EXISTS media_id ON TABLE base_attachment TYPE string;
DEFINE FIELD IF NOT EXISTS mimetype ON TABLE base_attachment TYPE option<string | NONE>;
DEFINE FIELD IF NOT EXISTS uploaded_by ON TABLE base_attachment TYPE option<string | NONE>;
DEFINE FIELD IF NOT EXISTS date_created ON TABLE base_attachment TYPE datetime DEFAULT time::now();
DEFINE INDEX IF NOT EXISTS base_attachment_doc ON TABLE base_attachment COLUMNS model, res_id;
