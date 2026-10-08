// Units of measure.
//
// Odoo 19 chains each unit to another unit with a relative factor, so a conversion walks a tree and the precision
// is one setting for every unit. Frappe stores a loose pair table (from, to, value) that has to be filled for each
// combination and has no notion of a family of units. Here a unit belongs to a group (length, mass, ...), holds one
// factor to that group's reference unit, and carries its own rounding. Two units convert only when they share a
// group, through the reference unit, so a group of n units needs n numbers and not n * (n - 1).

private fn blank(v) { v == () || v == "" }

private fn number(value, name) {
    let kind = type_of(value);
    if kind == "i64" { return value.to_float(); }
    if kind == "f64" { return value; }
    fail(name + " must be a number");
}

private fn clean_code(code, what) {
    if blank(code) { fail("a " + what + " code is required"); }
    let c = code.to_lower();
    c.trim();
    if c == "" || c.len() > 30 { fail("a " + what + " code is 1 to 30 characters"); }
    c
}

private fn round_to(value, places) {
    let factor = 1.0;
    for i in 0..places { factor *= 10.0; }
    (value * factor).round() / factor
}

private fn unit_by_code(code) {
    let rows = db::find("uom", #{ filter: #{ code: clean_code(code, "unit") }, limit: 1 });
    if rows.len() == 0 { fail("there is no unit " + code); }
    rows[0]
}

private fn group_by_code(code) {
    let rows = db::find("uom_group", #{ filter: #{ code: clean_code(code, "group") }, limit: 1 });
    if rows.len() == 0 { fail("there is no unit group " + code); }
    rows[0]
}

fn create_group(input) {
    let code = clean_code(input.code, "group");
    if db::find("uom_group", #{ filter: #{ code: code }, limit: 1 }).len() > 0 { fail("the group " + code + " already exists"); }
    if blank(input.name) { fail("a name is required"); }
    db::create("uom_group", #{ code: code, name: input.name })
}

fn create_unit(input) {
    let code = clean_code(input.code, "unit");
    if db::find("uom", #{ filter: #{ code: code }, limit: 1 }).len() > 0 { fail("the unit " + code + " already exists"); }
    if blank(input.name) { fail("a name is required"); }
    let group = group_by_code(input.group);
    let existing = db::find("uom", #{ filter: #{ group: group.id, is_reference: true }, limit: 1 });
    let is_ref = input.is_reference == true;
    let factor = if is_ref { 1.0 } else { number(input.factor, "the factor") };
    if factor <= 0.0 { fail("the factor is greater than zero"); }
    if is_ref && existing.len() > 0 { fail("the group " + group.code + " already has the reference unit " + existing[0].code); }
    if !is_ref && existing.len() == 0 { fail("create the reference unit of " + group.code + " first"); }
    let decimals = input.decimals ?? 3;
    if type_of(decimals) != "i64" || decimals < 0 || decimals > 8 { fail("decimals are 0 to 8"); }
    db::create("uom", #{ code: code, name: input.name, group: group.id, factor: factor, decimals: decimals, is_reference: is_ref, active: true })
}

fn list_units(input) {
    let filter = #{ active: true };
    if input != () && !blank(input.group) { filter.group = group_by_code(input.group).id; }
    db::find("uom", #{ filter: filter, order: "code", limit: 500 })
}

fn list_groups(input) { db::find("uom_group", #{ order: "code", limit: 100 }) }

// A quantity from one unit to another, rounded to the target unit's own decimals.
fn convert(input) {
    let qty = number(input.quantity, "the quantity");
    let from = unit_by_code(input.from);
    let to = unit_by_code(input.to);
    if from.group != to.group {
        fail(from.code + " and " + to.code + " measure different things and cannot be converted");
    }
    let result = round_to(qty * from.factor / to.factor, to.decimals);
    #{ quantity: result, unit: to.code }
}

// A price per `from` unit as a price per `to` unit (the inverse of a quantity).
fn convert_price(input) {
    let price = number(input.price, "the price");
    let from = unit_by_code(input.from);
    let to = unit_by_code(input.to);
    if from.group != to.group { fail(from.code + " and " + to.code + " measure different things"); }
    #{ price: price * to.factor / from.factor, unit: to.code }
}

fn seed_units(input) {
    let groups = [
        ["count", "Count"], ["mass", "Mass"], ["length", "Length"], ["volume", "Volume"], ["time", "Time"],
    ];
    let units = [
        // group, code, name, factor to the reference unit, decimals, reference
        ["count", "unit", "Unit", 1.0, 0, true], ["count", "dozen", "Dozen", 12.0, 3, false], ["count", "pair", "Pair", 2.0, 3, false],
        ["mass", "kg", "Kilogram", 1.0, 3, true], ["mass", "g", "Gram", 0.001, 1, false], ["mass", "t", "Tonne", 1000.0, 3, false],
        ["mass", "lb", "Pound", 0.45359237, 3, false],
        ["length", "m", "Metre", 1.0, 3, true], ["length", "cm", "Centimetre", 0.01, 1, false], ["length", "km", "Kilometre", 1000.0, 3, false],
        ["length", "mm", "Millimetre", 0.001, 0, false], ["length", "in", "Inch", 0.0254, 2, false], ["length", "ft", "Foot", 0.3048, 2, false],
        ["volume", "l", "Litre", 1.0, 3, true], ["volume", "ml", "Millilitre", 0.001, 0, false], ["volume", "gal", "Gallon (US)", 3.785411784, 3, false],
        ["time", "hour", "Hour", 1.0, 2, true], ["time", "day", "Day", 24.0, 3, false], ["time", "minute", "Minute", 0.016666666667, 0, false],
    ];
    let made = 0;
    for g in groups {
        if db::find("uom_group", #{ filter: #{ code: g[0] }, limit: 1 }).len() == 0 { create_group(#{ code: g[0], name: g[1] }); }
    }
    for u in units {
        if db::find("uom", #{ filter: #{ code: u[1] }, limit: 1 }).len() == 0 {
            create_unit(#{ group: u[0], code: u[1], name: u[2], factor: u[3], decimals: u[4], is_reference: u[5] });
            made += 1;
        }
    }
    #{ created: made }
}
