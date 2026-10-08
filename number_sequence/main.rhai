// Document numbers.
//
// What the sources do and what is different here:
//  * Odoo's ir.sequence keeps one counter on the sequence row plus date ranges as sub-rows created on demand, and
//    its "no gap" mode takes a row lock; the standard mode silently skips numbers.
//  * Frappe's naming series is a counter row per prefix, and a failed insert still burns the number.
// Here every period has its own counter row, so a yearly or monthly reset is a new row and never a race with the
// old one, and the increment is the kernel's atomic one. A sequence marked gapless also records each number it
// issues; a number whose document failed is voided with a reason instead of vanishing, and `audit_gaps` lists every
// hole that nobody explained.

private fn blank(v) { v == () || v == "" }

private fn digits(text, from, count) {
    for i in from..(from + count) {
        let ch = text.sub_string(i, 1);
        if ch < "0" || ch > "9" { return false; }
    }
    true
}

private fn today() { context::get().now.sub_string(0, 10) }

private fn clean_date(date) {
    if blank(date) { return today(); }
    let ok = type_of(date) == "string" && date.len() == 10 && digits(date, 0, 4) && digits(date, 5, 2) && digits(date, 8, 2)
        && date.sub_string(4, 1) == "-" && date.sub_string(7, 1) == "-";
    if ok {
        let month = date.sub_string(5, 2).parse_int();
        let day = date.sub_string(8, 2).parse_int();
        ok = month >= 1 && month <= 12 && day >= 1 && day <= 31;
    }
    if !ok { fail("a date is written like 2026-10-05"); }
    date
}

private fn clean_code(code) {
    if blank(code) { fail("a sequence code is required"); }
    let c = code.to_lower();
    c.trim();
    if c == "" || c.len() > 60 { fail("a sequence code is 1 to 60 characters"); }
    for ch in c.chars() {
        let ok = (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') || ch == '_' || ch == '.' || ch == '-';
        if !ok { fail("a sequence code uses letters, digits, '_', '.' and '-'"); }
    }
    c
}

private fn scope_of(input) { if blank(input.scope) { "" } else { input.scope } }

private fn key_of(code, scope) { if scope == "" { code } else { code + "@" + scope } }

private fn period_of(reset, date) {
    if reset == "year" { date.sub_string(0, 4) }
    else if reset == "month" { date.sub_string(0, 7) }
    else { "all" }
}

private fn pad(n, width) {
    let s = n.to_string();
    while s.len() < width { s = "0" + s; }
    s
}

private fn fill(text, date) {
    let out = text;
    out.replace("{YYYY}", date.sub_string(0, 4));
    out.replace("{YY}", date.sub_string(2, 2));
    out.replace("{MM}", date.sub_string(5, 2));
    out.replace("{DD}", date.sub_string(8, 2));
    out
}

private fn must_sequence(code, scope) {
    let rows = db::find("number_sequence", #{ filter: #{ key: key_of(code, scope) }, limit: 1 });
    // A sequence made without a scope serves every scope that has none of its own.
    if rows.len() == 0 && scope != "" {
        rows = db::find("number_sequence", #{ filter: #{ key: code }, limit: 1 });
    }
    if rows.len() == 0 { fail("there is no number sequence " + code); }
    if rows[0].active == false { fail("the number sequence " + code + " is switched off"); }
    rows[0]
}

private fn format(seq, value, date) {
    fill(seq.prefix ?? "", date) + pad(value, seq.padding ?? 5) + fill(seq.suffix ?? "", date)
}

private fn counter_for(seq, period) {
    let key = seq.key + "|" + period;
    let rows = db::find("number_counter", #{ filter: #{ key: key }, limit: 1 });
    if rows.len() > 0 { return rows[0]; }
    try {
        db::create("number_counter", #{ key: key, sequence: seq.key, period: period, last: seq.start - seq.step })
    } catch (e) {
        // Another call made the row first; the unique key makes that the one to use.
        let again = db::find("number_counter", #{ filter: #{ key: key }, limit: 1 });
        if again.len() == 0 { fail(e.to_string()); }
        again[0]
    }
}

// ---- sequences

fn create_sequence(input) {
    let code = clean_code(input.code);
    let scope = scope_of(input);
    if blank(input.label) { fail("a label is required"); }
    let reset = input.reset ?? "never";
    if reset != "never" && reset != "year" && reset != "month" { fail("reset is never, year or month"); }
    let padding = input.padding ?? 5;
    if type_of(padding) != "i64" || padding < 0 || padding > 12 { fail("padding is 0 to 12 digits"); }
    let step = input.step ?? 1;
    if type_of(step) != "i64" || step < 1 { fail("the step is a whole number of at least 1"); }
    let start = input.start ?? 1;
    if type_of(start) != "i64" || start < 0 { fail("the first number is a whole number, 0 or more"); }
    let key = key_of(code, scope);
    if db::find("number_sequence", #{ filter: #{ key: key }, limit: 1 }).len() > 0 {
        fail("the number sequence " + key + " already exists");
    }
    db::create("number_sequence", #{
        code: code, label: input.label, prefix: input.prefix ?? "", suffix: input.suffix ?? "",
        padding: padding, start: start, step: step, reset: reset, scope: scope,
        gapless: input.gapless == true, active: true, key: key,
    })
}

fn get_sequence(input) { must_sequence(clean_code(input.code), scope_of(input)) }

fn list_sequences(input) { db::find("number_sequence", #{ order: "code", limit: 500 }) }

// ---- numbers

// The next number for a document dated `date` (today when not given). `reference` says what it is for, and is kept on
// gapless sequences.
fn next_number(input) {
    let code = clean_code(input.code);
    let seq = must_sequence(code, scope_of(input));
    let date = clean_date(input.date);
    let period = period_of(seq.reset, date);
    let counter = counter_for(seq, period);
    let after = db::increment("number_counter", counter.id, "last", seq.step);
    let value = after.last;
    let number = format(seq, value, date);
    if seq.gapless == true {
        db::create("number_issue", #{
            key: counter.key + "|" + value, sequence: seq.key, period: period, value: value,
            number: number, reference: input.reference ?? "", state: "issued",
        });
    }
    #{ number: number, value: value, period: period }
}

// What the next number would look like, without taking it.
fn peek_number(input) {
    let seq = must_sequence(clean_code(input.code), scope_of(input));
    let date = clean_date(input.date);
    let period = period_of(seq.reset, date);
    let rows = db::find("number_counter", #{ filter: #{ key: seq.key + "|" + period }, limit: 1 });
    let last = if rows.len() == 0 { seq.start - seq.step } else { rows[0].last };
    #{ number: format(seq, last + seq.step, date), value: last + seq.step, period: period }
}

// The document that held a number was not made. The number stays in the record, marked void with the reason.
fn void_number(input) {
    if blank(input.number) { fail("the number to void is required"); }
    if blank(input.reason) { fail("a reason is required to void a number"); }
    let code = clean_code(input.code);
    let seq = must_sequence(code, scope_of(input));
    if seq.gapless != true { fail("only a gapless sequence records its numbers"); }
    let rows = db::find("number_issue", #{ filter: #{ sequence: seq.key, number: input.number }, limit: 1 });
    if rows.len() == 0 { fail("the number " + input.number + " was not issued by " + seq.key); }
    if rows[0].state == "void" { fail("the number " + input.number + " is already void"); }
    db::update("number_issue", rows[0].id, #{ state: "void", void_reason: input.reason })
}

// Values missing between the first and last issued number of a period: a number taken and never recorded.
fn audit_gaps(input) {
    let seq = must_sequence(clean_code(input.code), scope_of(input));
    if seq.gapless != true { fail("only a gapless sequence records its numbers"); }
    let filter = #{ sequence: seq.key };
    if !blank(input.period) { filter.period = input.period; }
    let rows = db::find("number_issue", #{ filter: filter, order: "value", limit: 5000 });
    let seen = #{};
    let first = #{};
    let last = #{};
    for row in rows {
        seen[row.period + "|" + row.value] = true;
        if first[row.period] == () || row.value < first[row.period] { first[row.period] = row.value; }
        if last[row.period] == () || row.value > last[row.period] { last[row.period] = row.value; }
    }
    let gaps = [];
    for period in first.keys() {
        let v = first[period];
        while v <= last[period] {
            if seen[period + "|" + v] == () { gaps.push(#{ period: period, value: v }); }
            v += seq.step;
        }
    }
    #{ sequence: seq.key, gaps: gaps, truncated: rows.len() == 5000 }
}
