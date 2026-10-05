// Countries (ISO 3166-1) and their regions.
//
// A country links to its usual currency in the `currency` plugin (a link across plugins). Run
// `aether --command country.seed --org <organization>` to create the 54 African countries and the
// main economies of the rest of the world; add others with `create_country`.

private fn or_empty(input) {
    if input == () { #{} } else { input }
}

private fn letters(text, count, name) {
    if type_of(text) != "string" { fail(name + " is required"); }
    let t = text.to_upper();
    t.trim();
    let ok = t.len() == count;
    for ch in t.chars() { if ch < 'A' || ch > 'Z' { ok = false; } }
    if !ok { fail(name + " is " + count.to_string() + " letters"); }
    t
}

private fn by_code(code) {
    let rows = db::find("country", #{ filter: #{ code: code }, limit: 1 });
    if rows.len() == 0 { () } else { rows[0] }
}

private fn currency_id(code) {
    if code == () || code == "" { return (); }
    let found = plugins::invoke("currency", "get_currency_by_code", #{ code: code });
    if found == () { () } else { found.id }
}

private fn clean_prefix(prefix) {
    if prefix == () || prefix == "" { return (); }
    let p = prefix;
    p.trim();
    let ok = p.len() >= 2 && p.len() <= 6 && p.sub_string(0, 1) == "+";
    for i in 1..p.len() { let ch = p.sub_string(i, 1); if ch < "0" || ch > "9" { ok = false; } }
    if !ok { fail("a phone prefix is a plus sign and digits, such as +234"); }
    p
}

fn create_country(input) {
    let code = letters(input.code, 2, "the country code");
    if by_code(code) != () { fail("the country " + code + " already exists"); }
    if input.name == () || input.name == "" { fail("a name is required"); }
    let data = #{ code: code, name: input.name, active: true };
    if input.code3 != () && input.code3 != "" { data.code3 = letters(input.code3, 3, "the 3-letter code"); }
    let prefix = clean_prefix(input.phone_prefix);
    if prefix != () { data.phone_prefix = prefix; }
    let currency = currency_id(input.currency_code);
    if currency != () { data.currency = currency; }
    db::create("country", data)
}

fn update_country(input) {
    let changes = #{};
    for key in ["name", "active"] {
        if input[key] != () { changes[key] = input[key]; }
    }
    if input.phone_prefix != () { changes.phone_prefix = clean_prefix(input.phone_prefix); }
    if input.currency_code != () {
        let currency = currency_id(input.currency_code);
        if currency == () { fail("there is no currency " + input.currency_code); }
        changes.currency = currency;
    }
    if changes.is_empty() { fail("there is nothing to change"); }
    db::update("country", input.id, changes)
}

fn get_country(input) {
    let found = if input.code != () { by_code(letters(input.code, 2, "the country code")) } else { db::get("country", input.id) };
    if found == () { fail("there is no such country"); }
    found
}

fn list_countries(input) {
    let input = or_empty(input);
    let filter = #{};
    if input.all != true { filter.active = true; }
    db::find("country", #{ filter: filter, order: "name", limit: 400 })
}

// ---- regions (states, provinces, ...)

fn add_region(input) {
    let country = by_code(letters(input.country_code, 2, "the country code"));
    if country == () { fail("there is no such country"); }
    if input.name == () || input.name == "" { fail("a name is required"); }
    let data = #{ country: country.id, name: input.name };
    if input.code != () && input.code != "" { data.code = input.code; }
    db::create("country_region", data)
}

fn list_regions(input) {
    let country = by_code(letters(input.country_code, 2, "the country code"));
    if country == () { fail("there is no such country"); }
    db::find("country_region", #{ filter: #{ country: country.id }, order: "name", limit: 500 })
}

fn remove_region(input) {
    db::delete("country_region", input.id)
}

// ---- the countries

fn seed_countries(input) {
    let countries = [
        ["DZ", "DZA", "Algeria", "+213", "DZD", "Africa"],
        ["AO", "AGO", "Angola", "+244", "AOA", "Africa"],
        ["BJ", "BEN", "Benin", "+229", "XOF", "Africa"],
        ["BW", "BWA", "Botswana", "+267", "BWP", "Africa"],
        ["BF", "BFA", "Burkina Faso", "+226", "XOF", "Africa"],
        ["BI", "BDI", "Burundi", "+257", "BIF", "Africa"],
        ["CM", "CMR", "Cameroon", "+237", "XAF", "Africa"],
        ["CV", "CPV", "Cabo Verde", "+238", "CVE", "Africa"],
        ["CF", "CAF", "Central African Republic", "+236", "XAF", "Africa"],
        ["TD", "TCD", "Chad", "+235", "XAF", "Africa"],
        ["KM", "COM", "Comoros", "+269", "KMF", "Africa"],
        ["CG", "COG", "Congo", "+242", "XAF", "Africa"],
        ["CD", "COD", "Democratic Republic of the Congo", "+243", "CDF", "Africa"],
        ["CI", "CIV", "Côte d'Ivoire", "+225", "XOF", "Africa"],
        ["DJ", "DJI", "Djibouti", "+253", "DJF", "Africa"],
        ["EG", "EGY", "Egypt", "+20", "EGP", "Africa"],
        ["GQ", "GNQ", "Equatorial Guinea", "+240", "XAF", "Africa"],
        ["ER", "ERI", "Eritrea", "+291", "ERN", "Africa"],
        ["SZ", "SWZ", "Eswatini", "+268", "SZL", "Africa"],
        ["ET", "ETH", "Ethiopia", "+251", "ETB", "Africa"],
        ["GA", "GAB", "Gabon", "+241", "XAF", "Africa"],
        ["GM", "GMB", "Gambia", "+220", "GMD", "Africa"],
        ["GH", "GHA", "Ghana", "+233", "GHS", "Africa"],
        ["GN", "GIN", "Guinea", "+224", "GNF", "Africa"],
        ["GW", "GNB", "Guinea-Bissau", "+245", "XOF", "Africa"],
        ["KE", "KEN", "Kenya", "+254", "KES", "Africa"],
        ["LS", "LSO", "Lesotho", "+266", "LSL", "Africa"],
        ["LR", "LBR", "Liberia", "+231", "LRD", "Africa"],
        ["LY", "LBY", "Libya", "+218", "LYD", "Africa"],
        ["MG", "MDG", "Madagascar", "+261", "MGA", "Africa"],
        ["MW", "MWI", "Malawi", "+265", "MWK", "Africa"],
        ["ML", "MLI", "Mali", "+223", "XOF", "Africa"],
        ["MR", "MRT", "Mauritania", "+222", "MRU", "Africa"],
        ["MU", "MUS", "Mauritius", "+230", "MUR", "Africa"],
        ["MA", "MAR", "Morocco", "+212", "MAD", "Africa"],
        ["MZ", "MOZ", "Mozambique", "+258", "MZN", "Africa"],
        ["NA", "NAM", "Namibia", "+264", "NAD", "Africa"],
        ["NE", "NER", "Niger", "+227", "XOF", "Africa"],
        ["NG", "NGA", "Nigeria", "+234", "NGN", "Africa"],
        ["RW", "RWA", "Rwanda", "+250", "RWF", "Africa"],
        ["ST", "STP", "São Tomé and Príncipe", "+239", "STN", "Africa"],
        ["SN", "SEN", "Senegal", "+221", "XOF", "Africa"],
        ["SC", "SYC", "Seychelles", "+248", "SCR", "Africa"],
        ["SL", "SLE", "Sierra Leone", "+232", "SLE", "Africa"],
        ["SO", "SOM", "Somalia", "+252", "SOS", "Africa"],
        ["ZA", "ZAF", "South Africa", "+27", "ZAR", "Africa"],
        ["SS", "SSD", "South Sudan", "+211", "SSP", "Africa"],
        ["SD", "SDN", "Sudan", "+249", "SDG", "Africa"],
        ["TZ", "TZA", "Tanzania", "+255", "TZS", "Africa"],
        ["TG", "TGO", "Togo", "+228", "XOF", "Africa"],
        ["TN", "TUN", "Tunisia", "+216", "TND", "Africa"],
        ["UG", "UGA", "Uganda", "+256", "UGX", "Africa"],
        ["ZM", "ZMB", "Zambia", "+260", "ZMW", "Africa"],
        ["ZW", "ZWE", "Zimbabwe", "+263", "ZWL", "Africa"],
        ["US", "USA", "United States", "+1", "USD", "World"],
        ["CA", "CAN", "Canada", "+1", "CAD", "World"],
        ["GB", "GBR", "United Kingdom", "+44", "GBP", "World"],
        ["FR", "FRA", "France", "+33", "EUR", "World"],
        ["DE", "DEU", "Germany", "+49", "EUR", "World"],
        ["ES", "ESP", "Spain", "+34", "EUR", "World"],
        ["IT", "ITA", "Italy", "+39", "EUR", "World"],
        ["PT", "PRT", "Portugal", "+351", "EUR", "World"],
        ["NL", "NLD", "Netherlands", "+31", "EUR", "World"],
        ["BE", "BEL", "Belgium", "+32", "EUR", "World"],
        ["CH", "CHE", "Switzerland", "+41", "CHF", "World"],
        ["IE", "IRL", "Ireland", "+353", "EUR", "World"],
        ["IN", "IND", "India", "+91", "INR", "World"],
        ["CN", "CHN", "China", "+86", "CNY", "World"],
        ["JP", "JPN", "Japan", "+81", "JPY", "World"],
        ["KR", "KOR", "South Korea", "+82", "KRW", "World"],
        ["AE", "ARE", "United Arab Emirates", "+971", "AED", "World"],
        ["SA", "SAU", "Saudi Arabia", "+966", "SAR", "World"],
        ["TR", "TUR", "Türkiye", "+90", "TRY", "World"],
        ["BR", "BRA", "Brazil", "+55", "BRL", "World"],
        ["MX", "MEX", "Mexico", "+52", "MXN", "World"],
        ["AU", "AUS", "Australia", "+61", "AUD", "World"],
        ["NZ", "NZL", "New Zealand", "+64", "NZD", "World"],
        ["RU", "RUS", "Russia", "+7", "RUB", "World"],
        ["SG", "SGP", "Singapore", "+65", "SGD", "World"],
        ["HK", "HKG", "Hong Kong", "+852", "HKD", "World"],
        ["ID", "IDN", "Indonesia", "+62", "IDR", "World"],
        ["PK", "PAK", "Pakistan", "+92", "PKR", "World"],
        ["BD", "BGD", "Bangladesh", "+880", "BDT", "World"],
        ["LK", "LKA", "Sri Lanka", "+94", "LKR", "World"]
    ];
    let created = 0;
    let had = 0;
    let without_currency = [];
    for c in countries {
        if by_code(c[0]) != () { had += 1; continue; }
        let data = #{ code: c[0], code3: c[1], name: c[2], phone_prefix: c[3], active: true };
        let currency = currency_id(c[4]);
        if currency == () { without_currency.push(c[0] + " (" + c[4] + ")"); } else { data.currency = currency; }
        db::create("country", data);
        created += 1;
    }
    #{ created: created, already_there: had, without_currency: without_currency }
}
