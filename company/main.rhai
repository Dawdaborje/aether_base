// Companies: the legal entities that keep the books.
//
// The name, tax number, addresses and bank accounts of a company are those of its party record
// (`party`, a link to the party plugin's model). The company adds its currency, its fiscal year and
// whether it is the default company.

private fn or_empty(input) {
    if input == () { #{} } else { input }
}

private fn blank(value) {
    value == () || value == ""
}

private fn leap(year) {
    year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
}

private fn days_in(month, year) {
    if month == 2 { return if leap(year) { 29 } else { 28 }; }
    if month == 4 || month == 6 || month == 9 || month == 11 { 30 } else { 31 }
}

private fn whole(value, name, low, high) {
    if type_of(value) != "i64" || value < low || value > high {
        fail(name + " is a whole number from " + low.to_string() + " to " + high.to_string());
    }
    value
}

private fn two(n) {
    if n < 10 { "0" + n.to_string() } else { n.to_string() }
}

// A call to another plugin; if it refuses, its message becomes this call's own failure.
private fn through(plugin, function, args) {
    try {
        plugins::invoke(plugin, function, args)
    } catch (e) {
        fail(e.to_string());
    }
}

private fn currency_id(code) {
    let currency = through("currency", "get_currency_by_code", #{ code: code });
    if currency == () { fail("there is no currency " + code); }
    currency.id
}

private fn must_get(id) {
    if blank(id) { fail("a company id is required"); }
    let found = db::get("company", id);
    if found == () { fail("there is no such company"); }
    found
}

private fn check_fiscal(month, day) {
    whole(month, "the fiscal year's first month", 1, 12);
    whole(day, "the fiscal year's first day", 1, days_in(month, 2024));
}

// What to tell the party plugin about the entity.
private fn party_fields(input) {
    let out = #{};
    for key in ["tax_id", "email", "phone", "website", "currency_code"] {
        if input[key] != () { out[key] = input[key]; }
    }
    out
}

fn create_company(input) {
    if blank(input.name) { fail("a name is required"); }
    let month = if input.fiscal_year_start_month == () { 1 } else { input.fiscal_year_start_month };
    let day = if input.fiscal_year_start_day == () { 1 } else { input.fiscal_year_start_day };
    check_fiscal(month, day);
    if db::find("company", #{ filter: #{ name: input.name }, limit: 1 }).len() > 0 {
        fail("there is already a company called " + input.name);
    }
    // Checked first, so a mistake does not leave a party record behind.
    let currency = if blank(input.currency_code) { () } else { currency_id(input.currency_code) };
    let fields = party_fields(input);
    fields.name = input.name;
    fields.is_customer = false;
    let entity = through("party", "create_organization", fields);
    let data = #{ name: input.name, party: entity.id, fiscal_year_start_month: month, fiscal_year_start_day: day, is_default: false, is_active: true };
    if currency != () { data.currency = currency; }
    if !blank(input.logo_url) { data.logo_url = input.logo_url; }
    let created = db::create("company", data);
    // The first company is the default one.
    if db::find("company", #{ filter: #{ is_default: true }, limit: 1 }).len() == 0 || input.is_default == true {
        set_default_company(#{ id: created.id });
    }
    db::get("company", created.id)
}

fn update_company(input) {
    let c = must_get(input.id);
    let changes = #{};
    if input.name != () {
        if blank(input.name) { fail("a name is required"); }
        changes.name = input.name;
        through("party", "update_party", #{ id: c.party, name: input.name });
    }
    let others = party_fields(input);
    others.remove("currency_code");
    if !others.is_empty() {
        others.id = c.party;
        through("party", "update_party", others);
    }
    if !blank(input.currency_code) { changes.currency = currency_id(input.currency_code); }
    if input.fiscal_year_start_month != () || input.fiscal_year_start_day != () {
        let month = if input.fiscal_year_start_month == () { c.fiscal_year_start_month } else { input.fiscal_year_start_month };
        let day = if input.fiscal_year_start_day == () { c.fiscal_year_start_day } else { input.fiscal_year_start_day };
        check_fiscal(month, day);
        changes.fiscal_year_start_month = month;
        changes.fiscal_year_start_day = day;
    }
    if input.logo_url != () { changes.logo_url = input.logo_url; }
    if changes.is_empty() && others.is_empty() { fail("there is nothing to change"); }
    if changes.is_empty() { return c; }
    db::update("company", c.id, changes)
}

fn get_company(input) {
    must_get(input.id)
}

fn list_companies(input) {
    let input = or_empty(input);
    let filter = #{};
    if input.all != true { filter.is_active = true; }
    db::find("company", #{ filter: filter, order: "name", limit: 200 })
}

fn get_default_company(input) {
    let rows = db::find("company", #{ filter: #{ is_default: true, is_active: true }, limit: 1 });
    if rows.len() == 0 { () } else { rows[0] }
}

fn set_default_company(input) {
    let target = must_get(input.id);
    if target.is_active != true { fail("an archived company cannot be the default"); }
    let ops = [];
    for other in db::find("company", #{ filter: #{ is_default: true }, limit: 20 }) {
        if other.id != target.id { ops.push(#{ op: "update", model: "company", id: other.id, data: #{ is_default: false } }); }
    }
    ops.push(#{ op: "update", model: "company", id: target.id, data: #{ is_default: true } });
    db::transaction(ops);
    db::get("company", target.id)
}

fn archive_company(input) {
    let c = must_get(input.id);
    if c.is_default == true { fail("make another company the default before archiving this one"); }
    db::update("company", c.id, #{ is_active: false })
}

// The fiscal year that contains a date, for a company (the default one unless an id is given):
// { start, end } as dates, both included.
fn fiscal_year(input) {
    let input = or_empty(input);
    let c = if blank(input.id) { get_default_company(#{}) } else { must_get(input.id) };
    if c == () { fail("there is no default company"); }
    let date = if blank(input.date) { context::get().now.sub_string(0, 10) } else { input.date };
    if type_of(date) != "string" || date.len() != 10 { fail("a date is written like 2026-10-05"); }
    let year = date.sub_string(0, 4).parse_int();
    let month = date.sub_string(5, 2).parse_int();
    let day = date.sub_string(8, 2).parse_int();
    let sm = c.fiscal_year_start_month;
    let sd = c.fiscal_year_start_day;
    // A fiscal year that starts on 29 February starts on the 28th in years without one.
    let this_year_day = if sm == 2 && sd == 29 && !leap(year) { 28 } else { sd };
    let starts_before = month > sm || (month == sm && day >= this_year_day);
    let start_year = if starts_before { year } else { year - 1 };
    let start_day = if sm == 2 && sd == 29 && !leap(start_year) { 28 } else { sd };
    let next_year = start_year + 1;
    let next_day = if sm == 2 && sd == 29 && !leap(next_year) { 28 } else { sd };
    // The year ends the day before the next one starts.
    let end_year = next_year;
    let end_month = sm;
    let end_day = next_day - 1;
    if end_day < 1 {
        end_month = sm - 1;
        if end_month < 1 { end_month = 12; end_year = next_year - 1; }
        end_day = days_in(end_month, end_year);
    }
    #{
        company: c.id,
        start: start_year.to_string() + "-" + two(sm) + "-" + two(start_day),
        end: end_year.to_string() + "-" + two(end_month) + "-" + two(end_day)
    }
}
