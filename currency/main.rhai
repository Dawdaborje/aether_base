// Currencies and exchange rates.
//
// Rates are expressed against one base currency: a rate is "units of this currency for one unit of
// the base". Converting from A to B on a date is amount / rate(A) * rate(B), using for each the
// newest rate on or before that date. The base currency's rate is always 1.

private fn today() {
    context::get().now.sub_string(0, 10)
}

private fn number(value, name) {
    let kind = type_of(value);
    if kind == "i64" { return value.to_float(); }
    if kind == "f64" { return value; }
    fail(name + " must be a number");
}

private fn digits(text, from, count) {
    for i in from..(from + count) {
        let ch = text.sub_string(i, 1);
        if ch < "0" || ch > "9" { return false; }
    }
    true
}

private fn days_in(month, year) {
    if month == 2 { return if year % 4 == 0 && (year % 100 != 0 || year % 400 == 0) { 29 } else { 28 }; }
    if month == 4 || month == 6 || month == 9 || month == 11 { 30 } else { 31 }
}

private fn clean_date(date) {
    let ok = type_of(date) == "string" && date.len() == 10 && digits(date, 0, 4) && digits(date, 5, 2) && digits(date, 8, 2)
        && date.sub_string(4, 1) == "-" && date.sub_string(7, 1) == "-";
    if ok {
        let month = date.sub_string(5, 2).parse_int();
        let day = date.sub_string(8, 2).parse_int();
        ok = month >= 1 && month <= 12 && day >= 1 && day <= days_in(month, date.sub_string(0, 4).parse_int());
    }
    if !ok { fail("a date is written like 2026-10-05"); }
    date
}

private fn clean_code(code) {
    if code == () { fail("a currency code is required"); }
    let c = code.to_upper();
    c.trim();
    let ok = c.len() == 3;
    for ch in c.chars() { if ch < 'A' || ch > 'Z' { ok = false; } }
    if !ok { fail("a currency code is three letters, such as USD"); }
    c
}

private fn by_code(code) {
    let rows = db::find("currency", #{ filter: #{ code: code }, limit: 1 });
    if rows.len() == 0 { () } else { rows[0] }
}

private fn must_find(code) {
    let clean = clean_code(code);
    let found = by_code(clean);
    if found == () { fail("there is no currency " + clean); }
    found
}

private fn round_to(value, places) {
    let factor = 1.0;
    for i in 0..places { factor *= 10.0; }
    (value * factor).round() / factor
}

private fn rate_on(currency, date) {
    if currency.is_base == true { return 1.0; }
    let rows = db::find("currency_rate", #{ filter: #{ currency: currency.id }, order: "-date", limit: 500 });
    for row in rows {
        if row.date <= date { return row.rate; }
    }
    fail("there is no rate for " + currency.code + " on or before " + date);
}

private fn or_empty(input) {
    if input == () { #{} } else { input }
}

// ---- currencies

fn create_currency(input) {
    let code = clean_code(input.code);
    if by_code(code) != () { fail("the currency " + code + " already exists"); }
    if input.name == () || input.name == "" { fail("a name is required"); }
    let symbol = if input.symbol == () || input.symbol == "" { code } else { input.symbol };
    let places = if input.decimal_places == () { 2 } else { input.decimal_places };
    if type_of(places) != "i64" || places < 0 || places > 6 { fail("decimal places are 0 to 6"); }
    db::create("currency", #{ code: code, name: input.name, symbol: symbol, decimal_places: places, is_base: false, active: true })
}

fn update_currency(input) {
    let changes = #{};
    for key in ["name", "symbol", "decimal_places"] {
        if input[key] != () { changes[key] = input[key]; }
    }
    if changes.is_empty() { fail("there is nothing to change"); }
    if changes.decimal_places != () && (type_of(changes.decimal_places) != "i64" || changes.decimal_places < 0 || changes.decimal_places > 6) {
        fail("decimal places are 0 to 6");
    }
    db::update("currency", input.id, changes)
}

// For other plugins (the country plugin links to a currency by its code); null when there is none.
fn get_currency_by_code(input) {
    by_code(clean_code(input.code))
}

fn get_currency(input) {
    let found = db::get("currency", input.id);
    if found == () { fail("there is no such currency"); }
    found
}

fn list_currencies(input) {
    let input = or_empty(input);
    let filter = #{};
    if input.all != true { filter.active = true; }
    db::find("currency", #{ filter: filter, order: "code", limit: 500 })
}

fn set_active(input) {
    let c = must_find(input.code);
    if c.is_base == true && input.active == false { fail("the base currency cannot be switched off"); }
    db::update("currency", c.id, #{ active: input.active == true })
}

// ---- the base currency

fn get_base(input) {
    let rows = db::find("currency", #{ filter: #{ is_base: true }, limit: 1 });
    if rows.len() == 0 { () } else { rows[0] }
}

fn set_base(input) {
    let target = must_find(input.code);
    let ops = [];
    for row in db::find("currency", #{ filter: #{ is_base: true }, limit: 10 }) {
        if row.id != target.id { ops.push(#{ op: "update", model: "currency", id: row.id, data: #{ is_base: false } }); }
    }
    ops.push(#{ op: "update", model: "currency", id: target.id, data: #{ is_base: true, active: true } });
    db::transaction(ops);
    target.code
}

// ---- rates

fn set_rate(input) {
    let c = must_find(input.code);
    if c.is_base == true { fail("the base currency is always 1; set the rates of the others"); }
    let rate = number(input.rate, "the rate");
    if rate <= 0.0 { fail("a rate is greater than zero"); }
    let date = if input.date == () { today() } else { clean_date(input.date) };
    let existing = db::find("currency_rate", #{ filter: #{ currency: c.id, date: date }, limit: 1 });
    let row = if existing.len() > 0 {
        db::update("currency_rate", existing[0].id, #{ rate: rate })
    } else {
        db::create("currency_rate", #{ currency: c.id, rate: rate, date: date })
    };
    events::emit(#{ event: "rate_changed", payload: #{ code: c.code, rate: rate, date: date } });
    row
}

fn get_rate(input) {
    let c = must_find(input.code);
    let date = if input.date == () { today() } else { clean_date(input.date) };
    #{ code: c.code, rate: rate_on(c, date), date: date }
}

fn list_rates(input) {
    let c = must_find(input.code);
    db::find("currency_rate", #{ filter: #{ currency: c.id }, order: "-date", limit: 200 })
}

fn convert(input) {
    let amount = number(input.amount, "the amount");
    let from = must_find(input.from);
    let to = must_find(input.to);
    let date = if input.date == () { today() } else { clean_date(input.date) };
    let rate_from = rate_on(from, date);
    let rate_to = rate_on(to, date);
    #{
        amount: round_to(amount / rate_from * rate_to, to.decimal_places),
        currency: to.code,
        rate: rate_to / rate_from,
        date: date
    }
}

// ---- the currencies in common use

fn seed_currencies(input) {
    let common = [
        ["USD", "US Dollar", "$", 2], ["EUR", "Euro", "€", 2], ["GBP", "Pound Sterling", "£", 2],
        ["NGN", "Naira", "₦", 2], ["GHS", "Ghana Cedi", "GH₵", 2], ["KES", "Kenyan Shilling", "KSh", 2],
        ["ZAR", "Rand", "R", 2], ["XOF", "CFA Franc BCEAO", "F CFA", 0], ["XAF", "CFA Franc BEAC", "FCFA", 0],
        ["CDF", "Congolese Franc", "FC", 2], ["TZS", "Tanzanian Shilling", "TSh", 2], ["UGX", "Ugandan Shilling", "USh", 0],
        ["RWF", "Rwandan Franc", "FRw", 0], ["ETB", "Birr", "Br", 2], ["EGP", "Egyptian Pound", "E£", 2],
        ["MAD", "Moroccan Dirham", "MAD", 2], ["DZD", "Algerian Dinar", "DA", 2], ["TND", "Tunisian Dinar", "DT", 3],
        ["LYD", "Libyan Dinar", "LD", 3], ["AOA", "Kwanza", "Kz", 2], ["MZN", "Metical", "MT", 2],
        ["ZMW", "Zambian Kwacha", "ZK", 2], ["BWP", "Pula", "P", 2], ["NAD", "Namibian Dollar", "N$", 2],
        ["MUR", "Mauritian Rupee", "Rs", 2], ["MGA", "Ariary", "Ar", 2], ["SDG", "Sudanese Pound", "SDG", 2],
        ["SSP", "South Sudanese Pound", "SSP", 2], ["SOS", "Somali Shilling", "Sh", 2], ["BIF", "Burundi Franc", "FBu", 0],
        ["DJF", "Djibouti Franc", "Fdj", 0], ["KMF", "Comorian Franc", "CF", 0], ["GMD", "Dalasi", "D", 2],
        ["GNF", "Guinean Franc", "FG", 0], ["LRD", "Liberian Dollar", "L$", 2], ["SLE", "Leone", "Le", 2],
        ["CVE", "Cabo Verde Escudo", "$", 2], ["STN", "Dobra", "Db", 2], ["SCR", "Seychelles Rupee", "SR", 2],
        ["SZL", "Lilangeni", "E", 2], ["LSL", "Loti", "L", 2], ["MWK", "Malawian Kwacha", "MK", 2],
        ["ERN", "Nakfa", "Nfk", 2], ["MRU", "Ouguiya", "UM", 2], ["ZWL", "Zimbabwe Dollar", "Z$", 2],
        ["CAD", "Canadian Dollar", "CA$", 2], ["CHF", "Swiss Franc", "CHF", 2], ["INR", "Indian Rupee", "₹", 2],
        ["CNY", "Yuan", "CN¥", 2], ["JPY", "Yen", "¥", 0], ["KRW", "Won", "₩", 0],
        ["AED", "UAE Dirham", "AED", 2], ["SAR", "Saudi Riyal", "SAR", 2], ["TRY", "Turkish Lira", "₺", 2],
        ["BRL", "Real", "R$", 2], ["MXN", "Mexican Peso", "MX$", 2], ["AUD", "Australian Dollar", "A$", 2],
        ["NZD", "New Zealand Dollar", "NZ$", 2], ["RUB", "Russian Rouble", "₽", 2], ["SGD", "Singapore Dollar", "S$", 2],
        ["HKD", "Hong Kong Dollar", "HK$", 2], ["IDR", "Rupiah", "Rp", 2], ["PKR", "Pakistani Rupee", "Rs", 2],
        ["BDT", "Taka", "৳", 2], ["LKR", "Sri Lanka Rupee", "Rs", 2]
    ];
    let created = 0;
    let had = 0;
    for entry in common {
        if by_code(entry[0]) == () {
            db::create("currency", #{ code: entry[0], name: entry[1], symbol: entry[2], decimal_places: entry[3], is_base: false, active: true });
            created += 1;
        } else {
            had += 1;
        }
    }
    // The first run gives the books a base currency to start from.
    let base = get_base(#{});
    let base_code = if base == () { set_base(#{ code: "USD" }) } else { base.code };
    #{ created: created, already_there: had, base: base_code }
}
