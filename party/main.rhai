// Parties: the people and organizations the business deals with.
//
// A party is a person or an organization. A person may belong to an organization (`parent`), which is
// how an organization's contacts are kept. Roles (customer, supplier, employee, bank) are flags so
// that lists can be filtered by them; other plugins add what they need by linking to a party.
//
// Records are never deleted, only archived, because other records point at them.

// ---- small helpers

private fn blank(value) {
    value == () || value == ""
}

private fn or_empty(input) {
    if input == () { #{} } else { input }
}

private fn text_of(value, name, max) {
    if type_of(value) != "string" { fail(name + " must be text"); }
    let t = value;
    t.trim();
    if t.len() > max { fail(name + " is at most " + max.to_string() + " characters"); }
    t
}

// An email address, lower case, with one @ and a dot in the domain; nothing else is checked.
private fn clean_email(value) {
    let e = text_of(value, "the email", 254).to_lower();
    let at = e.index_of("@");
    let ok = at > 0 && e.index_of("@", at + 1) == -1 && e.len() > at + 3 && !e.contains(" ");
    if ok {
        let domain = e.sub_string(at + 1);
        ok = domain.contains(".") && !domain.starts_with(".") && !domain.ends_with(".") && !domain.contains("..");
    }
    if !ok { fail("`" + e + "` is not an email address"); }
    e
}

// International form: a plus sign and 8 to 15 digits. Spaces, dashes, dots and brackets are dropped.
private fn clean_phone(value, name) {
    let raw = text_of(value, name, 40);
    let digits = "";
    for ch in raw.chars() {
        if ch == ' ' || ch == '-' || ch == '.' || ch == '(' || ch == ')' { continue; }
        digits += ch;
    }
    let ok = digits.len() >= 9 && digits.len() <= 16 && digits.sub_string(0, 1) == "+" && digits.sub_string(1, 1) != "0";
    for i in 1..digits.len() { let ch = digits.sub_string(i, 1); if ch < "0" || ch > "9" { ok = false; } }
    if !ok { fail(name + " is a phone number in international form, such as +2348012345678"); }
    digits
}

private fn display_of(kind, name, parent) {
    if kind == "person" && parent != () { name + " (" + parent.name + ")" } else { name }
}

private fn currency_id(code) {
    let c = code.to_upper();
    let found = plugins::invoke("currency", "get_currency_by_code", #{ code: c });
    if found == () { fail("there is no currency " + c); }
    found.id
}

private fn must_get(id) {
    if blank(id) { fail("a party id is required"); }
    let found = db::get("party", id);
    if found == () { fail("there is no such party"); }
    found
}

private fn same_tax_id(tax_id, except_id) {
    let rows = db::find("party", #{ filter: #{ tax_id: tax_id }, limit: 5 });
    for r in rows { if r.id != except_id { return r; } }
    ()
}

// Rhai passes maps by value, so this returns the map with the roles set instead of changing the caller's.
private fn with_roles(input, data) {
    for key in ["is_customer", "is_supplier", "is_employee", "is_bank"] {
        if input[key] != () { data[key] = input[key] == true; }
    }
    data
}

// Everything that can be set on a party, checked and normalized, as the fields to store.
private fn checked_fields(input, kind, existing) {
    let data = #{};
    let except = if existing == () { "" } else { existing.id };
    if input.name != () {
        let name = text_of(input.name, "the name", 200);
        if name == "" { fail("a name is required"); }
        data.name = name;
    }
    if input.email != () { if input.email == "" { data.email = (); } else { data.email = clean_email(input.email); } }
    if input.phone != () { if input.phone == "" { data.phone = (); } else { data.phone = clean_phone(input.phone, "the phone number"); } }
    if input.mobile != () { if input.mobile == "" { data.mobile = (); } else { data.mobile = clean_phone(input.mobile, "the mobile number"); } }
    for pair in [["website", 200], ["language", 10], ["job_title", 100], ["notes", 20000]] {
        if input[pair[0]] != () { data[pair[0]] = text_of(input[pair[0]], pair[0], pair[1]); }
    }
    if input.tax_id != () {
        if input.tax_id == "" {
            data.tax_id = ();
        } else {
            let tax = text_of(input.tax_id, "the tax number", 64);
            let clash = same_tax_id(tax, except);
            if clash != () { fail("the tax number " + tax + " is already used by " + clash.display_name); }
            data.tax_id = tax;
        }
    }
    if input.currency_code != () {
        if input.currency_code == "" { data.currency = (); } else { data.currency = currency_id(input.currency_code); }
    }
    if input.user != () { data.user = if input.user == "" { () } else { text_of(input.user, "the login account", 64) }; }
    with_roles(input, data)
}

private fn parent_of(id) {
    if blank(id) { return (); }
    let found = db::get("party", id);
    if found == () { fail("there is no such organization to belong to"); }
    found
}

// ---- creating and changing

// On create, a field left empty is simply not stored (on update, empty clears it).
private fn without_units(data) {
    let out = #{};
    for key in data.keys() { if data[key] != () { out[key] = data[key]; } }
    out
}

private fn create_party(kind, input) {
    let data = without_units(checked_fields(input, kind, ()));
    if data.name == () { fail("a name is required"); }
    data.kind = kind;
    let parent = parent_of(input.parent_id);
    if parent != () {
        if parent.kind != "organization" { fail("a party can only belong to an organization"); }
        data.parent = parent.id;
    }
    data.display_name = display_of(kind, data.name, parent);
    data.is_active = true;
    let created = db::create("party", data);
    events::emit(#{ event: "created", payload: #{ id: created.id, kind: kind, name: data.name } });
    created
}

fn create_person(input) {
    create_party("person", input)
}

fn create_organization(input) {
    if input.parent_id != () && input.parent_id != "" { fail("an organization is not part of another here; link a branch with its head office through update_party"); }
    create_party("organization", input)
}

fn update_party(input) {
    let existing = must_get(input.id);
    let data = checked_fields(input, existing.kind, existing);
    if input.parent_id != () {
        if input.parent_id == "" {
            data.parent = ();
        } else {
            let parent = parent_of(input.parent_id);
            if parent.id == existing.id { fail("a party cannot belong to itself"); }
            if parent.kind != "organization" { fail("a party can only belong to an organization"); }
            data.parent = parent.id;
        }
    }
    if data.is_empty() { fail("there is nothing to change"); }
    let new_name = if data.name == () { existing.name } else { data.name };
    let parent_id = if data.contains("parent") { data.parent } else { existing.parent };
    let parent = parent_of(parent_id);
    data.display_name = display_of(existing.kind, new_name, parent);
    let updated = db::update("party", existing.id, data);
    // The people who belong to an organization show its name.
    if existing.kind == "organization" && data.name != () && data.name != existing.name {
        for person in db::find("party", #{ filter: #{ parent: existing.id }, limit: 1000 }) {
            db::update("party", person.id, #{ display_name: display_of(person.kind, person.name, updated) });
        }
    }
    events::emit(#{ event: "updated", payload: #{ id: existing.id, kind: existing.kind } });
    updated
}

fn get_party(input) {
    must_get(input.id)
}

// The party with what hangs off it, for a detail view. Bank accounts are listed separately.
fn get_party_details(input) {
    let p = must_get(input.id);
    p.addresses = db::find("party_address", #{ filter: #{ party: p.id }, limit: 100 });
    p.contacts = db::find("party", #{ filter: #{ parent: p.id }, order: "display_name", limit: 200 });
    let tags = [];
    for link in db::find("party_tag_link", #{ filter: #{ party: p.id }, limit: 100 }) {
        let tag = db::get("party_tag", link.tag);
        if tag != () { tags.push(tag.name); }
    }
    p.tags = tags;
    p
}

fn archive(input) {
    let p = must_get(input.id);
    if p.is_active != true { return p; }
    let people = db::find("party", #{ filter: #{ parent: p.id, is_active: true }, limit: 1000 });
    if people.len() > 0 && input.with_contacts != true {
        fail(p.name + " has " + people.len().to_string() + " active contact(s); archive them too with with_contacts, or move them first");
    }
    for person in people { db::update("party", person.id, #{ is_active: false }); }
    let archived = db::update("party", p.id, #{ is_active: false });
    events::emit(#{ event: "archived", payload: #{ id: p.id, kind: p.kind, name: p.name } });
    archived
}

fn unarchive(input) {
    let p = must_get(input.id);
    db::update("party", p.id, #{ is_active: true })
}

fn link_user(input) {
    let p = must_get(input.id);
    if blank(input.user) { fail("a login account id is required"); }
    let user = text_of(input.user, "the login account", 64);
    for other in db::find("party", #{ filter: #{ user: user }, limit: 5 }) {
        if other.id != p.id { fail("that login account already belongs to " + other.display_name); }
    }
    db::update("party", p.id, #{ user: user })
}

// ---- finding

fn search(input) {
    let input = or_empty(input);
    let filter = #{};
    if input.include_inactive != true { filter.is_active = true; }
    if input.kind != () {
        if input.kind != "person" && input.kind != "organization" { fail("kind is person or organization"); }
        filter.kind = input.kind;
    }
    if input.role != () {
        let flag = "is_" + input.role;
        if !(flag in ["is_customer", "is_supplier", "is_employee", "is_bank"]) { fail("role is customer, supplier, employee or bank"); }
        filter[flag] = true;
    }
    if input.tag != () {
        let tags = db::find("party_tag", #{ filter: #{ name: input.tag }, limit: 1 });
        let wanted = [];
        if tags.len() > 0 {
            for link in db::find("party_tag_link", #{ filter: #{ tag: tags[0].id }, limit: 500 }) { wanted.push(link.party); }
        }
        if wanted.len() == 0 { return []; }
        filter.id = #{ "in": wanted };
    }
    let text = if blank(input.text) { "" } else { input.text.trim().to_lower() };
    let limit = if input.limit == () { 50 } else { input.limit };
    if type_of(limit) != "i64" || limit < 1 || limit > 500 { fail("limit is 1 to 500"); }
    // The database does the matching (`like` is a case-insensitive substring), so the limit counts matches.
    if text != "" {
        filter["or"] = [
            #{ display_name: #{ like: text } }, #{ email: #{ like: text } }, #{ phone: #{ like: text } },
            #{ mobile: #{ like: text } }, #{ tax_id: #{ like: text } },
        ];
    }
    db::find("party", #{ filter: filter, order: "display_name", limit: limit })
}

// The same, for a page's list.
fn list_parties(input) {
    search(input)
}

// Parties that look like the same real-world person or company: they share a tax number, an email
// address or a phone number. With an id, the others like that one; without, all the groups.
fn find_duplicates(input) {
    let input = or_empty(input);
    let groups = #{};
    let rows = db::find("party", #{ filter: #{ is_active: true }, limit: 1000 });
    for r in rows {
        for pair in [["tax_id", r.tax_id], ["email", r.email], ["phone", r.phone]] {
            if pair[1] == () || pair[1] == "" { continue; }
            let key = pair[0] + ":" + pair[1];
            // Indexing a map gives a copy, so the list is changed and put back.
            let list = if groups[key] == () { [] } else { groups[key] };
            list.push(r.id);
            groups[key] = list;
        }
    }
    let found = [];
    for key in groups.keys() {
        let ids = groups[key];
        if ids.len() < 2 { continue; }
        if input.id != () && !(input.id in ids) && !ids.some(|x| x.ends_with(":" + input.id) || x == input.id) { continue; }
        found.push(#{ matched_on: key, parties: ids });
    }
    found
}

// ---- addresses

private fn country_id(code) {
    if blank(code) { return (); }
    try {
        plugins::invoke("country", "get_country", #{ code: code }).id
    } catch (e) {
        // The country plugin says what is wrong ("there is no such country"); pass it on as this call's failure.
        fail(e.to_string());
    }
}

private fn make_default(address) {
    let ops = [];
    for other in db::find("party_address", #{ filter: #{ party: address.party, type: address.type, is_default: true }, limit: 50 }) {
        if other.id != address.id { ops.push(#{ op: "update", model: "party_address", id: other.id, data: #{ is_default: false } }); }
    }
    ops.push(#{ op: "update", model: "party_address", id: address.id, data: #{ is_default: true } });
    db::transaction(ops);
}

fn add_address(input) {
    let p = must_get(input.party_id);
    let kind = if input.type == () { "billing" } else { input.type };
    if !(kind in ["billing", "shipping", "home", "office", "other"]) { fail("an address type is billing, shipping, home, office or other"); }
    let data = #{ party: p.id, type: kind, is_default: false };
    for pair in [["street", 200], ["street2", 200], ["city", 100], ["region", 100], ["postal_code", 20]] {
        if input[pair[0]] != () { data[pair[0]] = text_of(input[pair[0]], pair[0], pair[1]); }
    }
    let country = country_id(input.country_code);
    if country != () { data.country = country; }
    for key in ["latitude", "longitude"] {
        if input[key] != () { data[key] = input[key].to_float(); }
    }
    let first_of_type = db::find("party_address", #{ filter: #{ party: p.id, type: kind }, limit: 1 }).len() == 0;
    let created = db::create("party_address", data);
    if first_of_type || input.is_default == true { make_default(created); }
    db::get("party_address", created.id)
}

fn set_default_address(input) {
    let a = db::get("party_address", input.id);
    if a == () { fail("there is no such address"); }
    make_default(a);
    db::get("party_address", a.id)
}

fn list_addresses(input) {
    db::find("party_address", #{ filter: #{ party: must_get(input.party_id).id }, limit: 100 })
}

fn remove_address(input) {
    db::delete("party_address", input.id)
}

// A person who belongs to an organization.
fn add_contact(input) {
    let org = must_get(input.parent_id);
    if org.kind != "organization" { fail("contacts belong to an organization"); }
    create_party("person", input)
}

// ---- bank accounts (sensitive: not part of get_party_details)

fn add_bank_account(input) {
    let p = must_get(input.party_id);
    if blank(input.account_number) && blank(input.iban) { fail("an account number or an IBAN is required"); }
    let data = #{ party: p.id, is_default: false };
    for pair in [["bank_name", 120], ["account_number", 64], ["iban", 40], ["swift", 16], ["holder_name", 200]] {
        if input[pair[0]] != () { data[pair[0]] = text_of(input[pair[0]], pair[0], pair[1]); }
    }
    if data.iban != () { data.iban = data.iban.to_upper(); }
    if input.currency_code != () && input.currency_code != "" { data.currency = currency_id(input.currency_code); }
    let first = db::find("party_bank_account", #{ filter: #{ party: p.id }, limit: 1 }).len() == 0;
    let created = db::create("party_bank_account", data);
    if first || input.is_default == true {
        let ops = [];
        for other in db::find("party_bank_account", #{ filter: #{ party: p.id, is_default: true }, limit: 50 }) {
            if other.id != created.id { ops.push(#{ op: "update", model: "party_bank_account", id: other.id, data: #{ is_default: false } }); }
        }
        ops.push(#{ op: "update", model: "party_bank_account", id: created.id, data: #{ is_default: true } });
        db::transaction(ops);
    }
    db::get("party_bank_account", created.id)
}

fn list_bank_accounts(input) {
    db::find("party_bank_account", #{ filter: #{ party: must_get(input.party_id).id }, limit: 50 })
}

fn remove_bank_account(input) {
    db::delete("party_bank_account", input.id)
}

// ---- tags

fn add_tag(input) {
    if blank(input.name) { fail("a tag needs a name"); }
    let name = text_of(input.name, "the tag name", 60);
    let existing = db::find("party_tag", #{ filter: #{ name: name }, limit: 1 });
    if existing.len() > 0 { return existing[0]; }
    let data = #{ name: name };
    if !blank(input.color) { data.color = text_of(input.color, "the colour", 20); }
    db::create("party_tag", data)
}

fn list_tags(input) {
    db::find("party_tag", #{ order: "name", limit: 500 })
}

fn tag_party(input) {
    let p = must_get(input.party_id);
    let tag = add_tag(#{ name: input.tag });
    if db::find("party_tag_link", #{ filter: #{ party: p.id, tag: tag.id }, limit: 1 }).len() == 0 {
        db::create("party_tag_link", #{ party: p.id, tag: tag.id });
    }
    tag
}

fn untag_party(input) {
    let p = must_get(input.party_id);
    let tags = db::find("party_tag", #{ filter: #{ name: input.tag }, limit: 1 });
    if tags.len() == 0 { return false; }
    let links = db::find("party_tag_link", #{ filter: #{ party: p.id, tag: tags[0].id }, limit: 5 });
    for link in links { db::delete("party_tag_link", link.id); }
    links.len() > 0
}

// ---- merging duplicates
//
// Odoo's partner merge rewrites every foreign key in the database from a wizard that knows all the models, and
// deletes the losers. Frappe's merge renames the document and runs a link search over every doctype. A plugin here
// cannot touch another plugin's data, so the merge is split along that line: this plugin moves what it owns
// (addresses, bank accounts, contacts, tags), fills the blanks of the surviving party from the other one, archives
// the other one pointing at the survivor, and announces `merged` so each plugin repoints its own links. Nothing is
// deleted, and running the merge again after a failure carries on where it stopped.
fn merge(input) {
    let keep = must_get(input.into);
    let gone = must_get(input.from);
    if keep.id == gone.id { fail("a party cannot be merged into itself"); }
    if keep.kind != gone.kind { fail("a person and an organization cannot be merged"); }
    if keep.is_active != true { fail("the party to keep is archived; unarchive it first"); }

    let moved = #{ addresses: 0, bank_accounts: 0, contacts: 0, tags: 0 };

    for a in db::find("party_address", #{ filter: #{ party: gone.id }, limit: 1000 }) {
        db::update("party_address", a.id, #{ party: keep.id, is_default: false });
        moved.addresses += 1;
    }
    for b in db::find("party_bank_account", #{ filter: #{ party: gone.id }, limit: 1000 }) {
        db::update("party_bank_account", b.id, #{ party: keep.id });
        moved.bank_accounts += 1;
    }
    for c in db::find("party", #{ filter: #{ parent: gone.id }, limit: 1000 }) {
        db::update("party", c.id, #{ parent: keep.id });
        moved.contacts += 1;
    }
    let have = #{};
    for l in db::find("party_tag_link", #{ filter: #{ party: keep.id }, limit: 1000 }) { have[l.tag] = true; }
    for l in db::find("party_tag_link", #{ filter: #{ party: gone.id }, limit: 1000 }) {
        if have[l.tag] == () { db::update("party_tag_link", l.id, #{ party: keep.id }); moved.tags += 1; }
        else { db::delete("party_tag_link", l.id); }
    }

    let fill = #{};
    for key in ["email", "phone", "mobile", "website", "tax_id", "language", "currency", "job_title"] {
        if blank(keep[key]) && !blank(gone[key]) { fill[key] = gone[key]; }
    }
    for role in ["is_customer", "is_supplier", "is_employee", "is_bank"] {
        if gone[role] == true && keep[role] != true { fill[role] = true; }
    }
    if keep.user == () && gone.user != () { fill.user = gone.user; }

    // The tax number and the login are freed on the old record before the survivor takes them.
    let release = #{ is_active: false, notes: ((gone.notes ?? "") + "\nMerged into " + keep.display_name + " (" + keep.id + ").").trim() };
    if fill.tax_id != () { release.tax_id = (); }
    if fill.user != () { release.user = (); }
    db::update("party", gone.id, release);
    if !fill.is_empty() { db::update("party", keep.id, fill); }

    events::emit(#{ event: "merged", payload: #{ from: gone.id, into: keep.id, kind: keep.kind } });
    #{ into: keep.id, from: gone.id, moved: moved, filled: fill.keys() }
}
