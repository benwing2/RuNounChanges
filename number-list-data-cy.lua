local export = {numbers = {}}

local m_numutils = require("Module:number list/utils")
local map = m_numutils.map

local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

local numbers = export.numbers

local 


numbers[0] = {
	cardinal = "sero",
	ordinal = "serofed",
	ordinal_abbr = "0fed",
	wplink = "sero",
}

numbers[1] = {
	cardinal = "un",
	ordinal = "cyntaf",
	ordinal_abbr = "1af",
	adverbial = "unwaith",
	wplink = "un",
}

numbers[2] = {
	cardinal = {"dau<tag:masculine>", "dwy<tag:feminine>"},
	ordinal = "ail",
	ordinal_abbr = "2il",
	adverbial = "dwywaith",
	multiplier = "dwbl",
	wplink = "dau",
}

numbers[3] = {
	cardinal = {"tri<tag:masculine>", "tair<tag:feminine>"},
	ordinal = {"trydydd<tag:masculine>", "trydedd<tag:feminine>"},
	ordinal_abbr = {"3ydd<tag:masculine>", "3edd<tag:feminine>"},
	adverbial = "teirgwaith",
	multiplier = "triphlyg",
	wplink = "tri",
}

numbers[4] = {
	cardinal = {"pedwar<tag:masculine>", "pedair<tag:feminine>"},
	ordinal = {"pedwerydd<tag:masculine>", "pedwaredd<tag:feminine>"},
	ordinal_abbr = {"4ydd<tag:masculine>", "4edd<tag:feminine>"},
	multiplier = "pedwarplyg",
	wplink = "pedwar",
}

numbers[5] = {
	cardinal = {"pump", "pum<q:before nouns>"},
	ordinal = "pumed",
	ordinal_abbr = "5ed",
	wplink = "pump",
}

numbers[6] = {
	cardinal = {"chwech", "chwe<q:before nouns>"},
	ordinal = "chweched",
	ordinal_abbr = "6ed",
	wplink = "chwech",
}

numbers[7] = {
	cardinal = "saith",
	ordinal = "seithfed",
	ordinal_abbr = "7fed",
	wplink = "saith",
}

numbers[8] = {
	cardinal = "wyth",
	ordinal = "wythfed",
	ordinal_abbr = "8fed",
	wplink = "wyth",
}

numbers[9] = {
	cardinal = "naw",
	ordinal = "nawfed",
	ordinal_abbr = "9fed",
	wplink = "naw",
}

numbers[10] = {
	cardinal = "deg",
	ordinal = "degfed",
	ordinal_abbr = "10fed",
	wplink = "deg",
}

numbers[11] = {
	cardinal = {"un deg un<tag:decimal>", "un ar ddeg<tag:vigesimal>"},
	ordinal = "unfed ar ddeg",
	ordinal_abbr = "11eg",
	wplink = "un deg un",
}

numbers[12] = {
	cardinal = {"un deg dau<tag:decimal><tag:masculine>", "un deg dwy<tag:decimal><tag:feminine>", "deuddeg<tag:vigesimal>"},
	ordinal = "deuddegfed",
	ordinal_abbr = "12fed",
	wplink = "un deg dau",
}

numbers[13] = {
	cardinal = {"un deg tri<tag:decimal><tag:masculine>", "un deg tair<tag:decimal><tag:feminine>", "tri ar ddeg<tag:vigesimal><tag:masculine>", "tair ar ddeg<tag:vigesimal><tag:feminine>"},
	ordinal = {"trydydd ar ddeg<tag:masculine>", "trydedd ar ddeg<tag:feminine>"},
	ordinal_abbr = "13eg",
	wplink = "un deg tri",
}

numbers[14] = {
	cardinal = {"un deg pedwar<tag:decimal><tag:masculine>", "un deg pedair<tag:decimal><tag:feminine>", "pedwar ar ddeg<tag:vigesimal><tag:masculine>", "pedair ar ddeg<tag:vigesimal><tag:feminine>"},
	ordinal = {"pedwerydd ar ddeg<tag:masculine>", "pedwaredd ar ddeg<tag:feminine>"},
	ordinal_abbr = "14eg",
	wplink = "un deg pedwar",
}

numbers[15] = {
	cardinal = {"un deg pump<tag:decimal>", "pymtheg<tag:vigesimal>"},
	ordinal = "pymthegfed",
	ordinal_abbr = "15fed",
	wplink = "un deg pump",
}

numbers[16] = {
	cardinal = {"un deg chwech<tag:decimal>", "un ar bymtheg<tag:vigesimal>"},
	ordinal = "unfed ar bymtheg",
	ordinal_abbr = "16eg",
	wplink = "un deg chwech",
}

numbers[17] = {
	cardinal = {"un deg saith<tag:decimal>", "dau ar bymtheg<tag:vigesimal><tag:masculine>", "dwy ar bymtheg<tag:vigesimal><tag:feminine>"},
	ordinal = "ail ar bymtheg",
	ordinal_abbr = "17eg",
	wplink = "un deg saith",
}

numbers[18] = {
	cardinal = {"un deg wyth<tag:decimal>", "deunaw<tag:vigesimal>"},
	ordinal = "deunawfed",
	ordinal_abbr = "18fed",
	wplink = "un deg wyth",
}

numbers[19] = {
	cardinal = {"un deg naw<tag:decimal>", "pedwar ar bymtheg<tag:vigesimal><tag:masculine>", "pedair ar bymtheg<tag:vigesimal><tag:feminine>"},
	ordinal = {"pedwerydd ar bymtheg<tag:masculine>", "pedwaredd ar bymtheg<tag:feminine>"},
	ordinal_abbr = "19eg",
	wplink = "un deg naw",
}

numbers[20] = {
	cardinal = {"dau ddeg<tag:decimal>", "ugain<tag:vigesimal>"},
	ordinal = "ugeinfed",
	ordinal_abbr = "20fed",
	wplink = "dau ddeg",
}

numbers[30] = {
	cardinal = {"tri deg<tag:decimal>", "deg ar hugain<tag:vigesimal>"},
	ordinal = "degfed ar hugain",
	ordinal_abbr = "30ain",
}

numbers[40] = {
	cardinal = {"pedwar deg<tag:decimal>", "deugain<tag:vigesimal>"},
	ordinal = "deugeinfed",
	ordinal_abbr = "40fed",
}

numbers[50] = {
	cardinal = {"pum deg<tag:decimal>", "hanner cant<tag:vigesimal>"},
	ordinal = "hanner canfed",
	ordinal_abbr = "50fed",
}

numbers[60] = {
	cardinal = {"chwe deg<tag:decimal>", "trigain<tag:vigesimal>"},
	ordinal = "trigeinfed", -- FIXME: trigainfed? Misspelling?
	ordinal_abbr = "60fed",
}

numbers[70] = {
	cardinal = {"saith deg<tag:decimal>", "deg a thrigain<tag:vigesimal>"},
	ordinal = "degfed a thrigain",
	ordinal_abbr = "70ain",
}

numbers[80] = {
	cardinal = {"wyth deg<tag:decimal>", "pedwar ugain<tag:vigesimal>"},
	ordinal = "pedwar ugeinfed",
	ordinal_abbr = "80fed",
}

numbers[90] = {
	cardinal = {"naw deg<tag:decimal>", "deg a phedwar ugain<tag:vigesimal>"},
	ordinal = "degfed a phedwar ugain",
	ordinal_abbr = "90ain",
}

-- Templates for vigesimal numbers 21-99, not counting even multiples of 10. Some vigesimal numbers are actually
-- vigesimal and take units in the 11-19 range, while others take units in the 1-9 range even when they would be
-- expected to take units in the 11-19 range. An example of the latter is 52, formed as "hanner cant ac" + the number
-- for 2 (hence masculine "hanner cant ac dau", feminine "hanner cant ac dwy"). An example of the former is 74, formed
-- as the number for 14 + "a thrigain" (hence masculine "pedwar ar ddeg a thrigain" and feminine
-- "pedair ar ddeg a thrigain").
--
-- We determine the unit by taking either mod 10 or mod 20 of the overall number (depending on the second element of the
-- two-element table below), and fetching the corresponding units cardinal(s) or ordinal(s). If at least one element in
-- the resulting unit form(s) has a <tag:vigesimal> modifier, this means the number has different decimal and vigesimal
-- forms (this happens with numbers 11 and above), so filter down to only the ones with the vigesimal tag, and remove
-- it; otherwise take all forms. Then substitute the resulting unit form(s) into the template where it says UNIT, taking
-- care to move tags on the unit form(s) to the end; map() does this automatically. Also add "<tag:vigesimal>" at the
-- end of the return value to map(), i.e. directly after the template; any modifiers from the units forms will be tacked
-- on after that.
local vigesimal_templates = {
	[2] = {"UNIT ar hugain", 10},
	[3] = {"UNIT ar hugain", 20},
	[4] = {"deugain ac UNIT", 10},
	[5] = {"hanner cant ac UNIT", 10},
	[6] = {"trigain ac UNIT", 10},
	[7] = {"UNIT a thrigain", 20},
	[8] = {"pedwar ugain ac UNIT", 10},
	[9] = {"UNIT a phedwar ugain", 20},
}

-- Generate the numbers from 20 to 99. This is not easy both because there are two systems for forming cardinals
-- (decimal and vigesimal) and because of all sorts of complexities, including masculine and feminine variants of
-- certain numbers (exactly which numbers differs between the decimal and vigesimal systems), apocopated variants of
-- certain numbers before nouns (e.g. 5 and 6), and nasalized variants of [[deg]] (10) and certain derivatives of it.
for ten_multiplier=2, 9 do
	for one=1, 9 do
		local num = ten_multiplier * 10 + one

		-- First, the decimal forms. Only the cardinal is decimal. Formation is "TEN_UNIT deg ONE_UNIT" where
		-- TEN_UNIT = the cardinal associated with `ten_multiplier` and ONE_UNIT = the cardinal associated with `one`.
		-- Irregularities in the word "deg" follow the even multiples of 10, so we just copy them.
		local decimal_ten_card = filter(function(card) return card:find("<tag:decimal>") end, numbers[ten_multiplier].cardinal)
		if #decimal_ten_card ~= 1 then
			error("Internal error: Multiple or no decimal ten multiplier forms: " .. table.concat(decimal_ten_card, ", "))
		end
		local decimal_cardinal = map(function(unit_card)
			return map(function(ten_card) return ten_card .. " " .. unit_card end, decimal_ten_card)
		end, numbers[one].cardinal)

		-- Now the vigesimal forms. See the comment above `vigesimal_template`.
		local vigesimal_template, unit_mod = unpack(vigesimal_templates[ten_multiplier])
		local vigesimal_unit = num % unit_mod

		-- First cardinal forms.
		local vigesimal_unit_card = filter(function(card) return card:find("<tag:vigesimal>") end, numbers[vigesimal_unit].cardinal)
		if #vigesimal_unit_card > 0 then
			vigesimal_unit_card = map(function(unit_card) return rsub(unit_card, "<tag:vigesimal>", "") end, vigesimal_unit_card)
		else
			vigesimal_unit_card = numbers[vigesimal_unit].cardinal
		end
		local vigesimal_cardinal = map(function(unit_card) return rsub(vigesimal_template, "UNIT", unit_card) .. "<tag:vigesimal>" end,
			vigesimal_unit_card)

		-- Next ordinal forms.
		vigesimal_unit_ord = numbers[vigesimal_unit].ordinal -- ordinals always vigesimal
		local vigesimal_ordinal = map(function(unit_ord) return rsub(vigesimal_template, "UNIT", unit_ord) .. "<tag:vigesimal>" end,
			vigesimal_unit_ord)

		-- Now combine vigesimal + decimal cardinal forms, possibly with special form for 99; similarly, take the
		-- ordinal forms, possibly combining with special form for 99.
		local combined_card
		local combined_ord
		if num == 99 then -- include special forms for 99 before regular forms
			combined_card = {"cant namyn un"}
			combined_ord = {"canfed namyn un"}
		else
			combined_card = {}
			-- don't set combined_ord; it just uses the vigesimal forms directly.
		end
		map(function(card) table.insert(combined_card, card) end, vigesimal_cardinal)
		map(function(card) table.insert(combined_card, card) end, decimal_cardinal)
		if combined_ord then
			map(function(ord) table.insert(combined_ord, ord) end, vigesimal_ordinal)
		else
			combined_ord = vigesimal_ordinal
			if #combined_ord == 1 then
				combined_ord = combined_ord[1]
			end
		end

		-- Now generate ordinal abbreviations.
		-- FIXME

		numbers[num] = {
			cardinal = combined_card,
			ordinal = combined_ord,
			ordinal_abbr = ordinal_abbr,
		}
	end
end
	
numbers[21] = {
	cardinal = {"dau ddeg un<tag:decimal>", "un ar hugain<tag:vigesimal>"},
	ordinal = "unfed ar hugain",
	ordinal_abbr = "21ain",
	wplink = "dau ddeg un",
}

numbers[22] = {
	cardinal = {"dau ar hugain", "dau ddeg dau", "dau ddeg dwy", "dwy ar hugain"},
	ordinal = "ail ar hugain",
	[[decimal|Decimal]] = {"dau ddeg dau", "dau ddeg dwy"},
	[[feminine|Feminine]] = {"dwy ar hugain", "dau ddeg dwy"},
	[[masculine|Masculine]] = {"dau ddeg dau", "dau ar hugain"},
	[[vigesimal|Vigesimal]] = {"dau ar hugain", "dwy ar hugain"},
}

numbers[23] = {
	cardinal = {"tri ar hugain", "dau ddeg tri", "dau ddeg tair", "tair ar hugain"},
	ordinal = {"trydydd ar hugain", "trydedd ar hugain"},
	[[decimal|Decimal]] = {"dau ddeg tri", "dau ddeg tair", "un deg tair", "un deg tri"},
	[[feminine|Feminine]] = {"dau ddeg tair", "tair ar hugain", "trydedd ar hugain"},
	[[masculine|Masculine]] = {"dau ddeg tri", "tri ar hugain", "trydydd ar hugain"},
	[[vigesimal|Vigesimal]] = {"tri ar hugain", "tair ar hugain"},
}

numbers[24] = {
	cardinal = {"dau ddeg pedwar", "pedwar ar hugain", "dau ddeg pedair", "pedair ar hugain"},
	ordinal = {"pedwerydd ar hugain", "pedwaredd ar hugain"},
	[[decimal|Decimal]] = {"dau ddeg pedwar", "dau ddeg pedair"},
	[[feminine|Feminine]] = {"dau ddeg pedair", "pedair ar hugain", "pedwaredd ar hugain"},
	[[masculine|Masculine]] = {"dau ddeg pedwar", "pedwar ar hugain"},
	[[vigesimal|Vigesimal]] = {"pedwar ar hugain", "pedair ar hugain"},
}

numbers[25] = {
	cardinal = {"pump ar hugain", "dau ddeg pump"},
	ordinal = "pumed ar hugain",
	[[decimal|Decimal]] = "dau ddeg pump",
	[[vigesimal|Vigesimal]] = "pump ar hugain",
}

numbers[26] = {
	cardinal = {"chwech ar hugain", "dau ddeg chwech"},
	ordinal = "chweched ar hugain",
	[[decimal|Decimal]] = "dau ddeg chwech",
	[[vigesimal|Vigesimal]] = "chwech ar hugain",
}

numbers[27] = {
	cardinal = {"saith ar hugain", "dau ddeg saith"},
	ordinal = "seithfed ar hugain",
	[[decimal|Decimal]] = "dau ddeg saith",
	[[vigesimal|Vigesimal]] = "saith ar hugain",
}

numbers[28] = {
	cardinal = {"dau ddeg wyth", "wyth ar hugain"},
	ordinal = "wythfed ar hugain",
	[[decimal|Decimal]] = "dau ddeg wyth",
	[[vigesimal|Vigesimal]] = "wyth ar hugain",
}

numbers[29] = {
	cardinal = {"dau ddeg naw", "naw ar hugain"},
	ordinal = "nawfed ar hugain",
	[[decimal|Decimal]] = "dau ddeg naw",
	[[vigesimal|Vigesimal]] = "naw ar hugain",
}

numbers[31] = {
	cardinal = {"un ar ddeg ar hugain", "tri deg un"},
	ordinal = "unfed ar ddeg ar hugain",
	[[decimal|Decimal]] = "tri deg un",
	[[vigesimal|Vigesimal]] = "un ar ddeg ar hugain",
}

numbers[32] = {
	cardinal = {"deuddeg ar hugain", "tri deg dau"},
	ordinal = "deuddegfed ar hugain",
	[[decimal|Decimal]] = "tri ddeg dau",
}

numbers[33] = {
	cardinal = "tri ar ddeg ar hugain",
}

numbers[39] = {
	cardinal = "pedwar ar bymtheg ar hugain",
	ordinal = "pedwerydd ar bymtheg ar hugain",
}

numbers[41] = {
	cardinal = "un a deugain",
	ordinal = "unfed ar deugain",
}

numbers[49] = {
	cardinal = {"naw a deugain", "pedwar deg naw"},
}

numbers[51] = {
	cardinal = {"hanner cant ac un", "pum deg un"},
}

numbers[59] = {
	cardinal = {"pum deg naw", "pedwar ar bymtheg a deugain"},
}

numbers[61] = {
	cardinal = {"chwe deg un", "un a thrigain"},
}

numbers[69] = {
	cardinal = "naw a thrigain",
}

numbers[71] = {
	cardinal = "un ar ddeg a thrigain",
}

numbers[79] = {
	cardinal = "pedwar ar bymtheg a thrigain",
}

numbers[81] = {
	cardinal = "un a phedwar ugain",
}

numbers[89] = {
	cardinal = "naw a phedwar ugain",
}

numbers[91] = {
	cardinal = "un ar ddeg a phedwar ugain",
}

numbers[98] = {
	cardinal = {"deunaw a phedwar ugain", "naw deg wyth"},
	ordinal = "deunawfed a phedwar ugain",
}

numbers[99] = {
	cardinal = {"pedwar ar bymtheg a phedwar ugain", "cant namyn un", "naw deg naw", "pedair ar bymtheg a phedwar ugain"},
	ordinal = {"canfed namyn un", "pedwerydd ar bymtheg a phedwar ugain", "pedwaredd ar bymtheg a phedwar ugain"},
	[[decimal|Decimal]] = "naw deg naw",
	[[feminine|Feminine]] = {"pedair ar bymtheg a phedwar ugain", "pedwaredd ar bymtheg a phedwar ugain"},
	[[masculine|Masculie]] = "pedwar ar bymtheg a phedwar ugain",
	[[vigesimal|Vigesimal]] = "pedwar ar bymtheg a phedwar ugain",
}

numbers[100] = {
	cardinal = "cant",
	ordinal = "canfed",
}

numbers[101] = {
	cardinal = "cant ac un",
	ordinal = "cyntaf wedi'r cant",
}

numbers[102] = {
	cardinal = "cant a dau",
	ordinal = "ail wedi'r cant",
}

return export
