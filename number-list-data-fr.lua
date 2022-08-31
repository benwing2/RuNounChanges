local export = {numbers = {}}

local m_numutils = require("Module:number list/utils")
local map = m_numutils.map
local power_of = m_numutils.power_of

local numbers = export.numbers

local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

local function add_ordinal_suffix(term)
	if rfind(term, "f$") then
		return rsub(term, "f$", "vième") -- neuf -> neuvième
	elseif rfind(term, "q$") then
		return term .. "uième" -- cinq -> cinquième
	elseif rfind(term, "ts$") then
		return rsub(term, "s$", "ième") -- quatre-vingts -> quatre-vingtième
	else
		return rsub(term, "e$", "") .. "ième" -- quatre -> quatrième, trois -> troisième
	end
end

local function make_number(num, cardinal, ordinal, multiplier, wplink)
	local numstr = m_numutils.format_fixed(num)
	local with_thousands = #numstr < 10 and m_numutils.add_thousands_separator(numstr, " ") or nil
	numbers[num] = {
		cardinal = cardinal,
		ordinal = ordinal or map(function (card) return add_ordinal_suffix(card) end, cardinal),
		-- FIXME, should use superscript e
		ordinal_abbr = with_thousands and {with_thousands .. "e", with_thousands .. "ème<q:nonstandard>"} or nil,
		multiplier = multiplier,
		wplink = wplink or type(num) == "number" and num < 1000000 and num .. " (nombre)" or nil,
	}
end

make_number(0, "zéro")

numbers[1] = {
	cardinal = "un",
	ordinal = "premier",
	ordinal_abbr = "1er",
	fractional = "entier",
	multiplier = "simple",
	wplink = "1 (nombre)",
}

numbers[2] = {
	cardinal = "deux",
	ordinal = {"deuxième", "second"},
	ordinal_abbr = {"2e", "2d", "2ème<q:nonstandard>"},
	fractional = {"demi", "moitié"},
	multiplier = "double",
	wplink = "2 (nombre)",
}

numbers[3] = {
	cardinal = "trois",
	ordinal = "troisième",
	ordinal_abbr = {"3e", "3ème<q:nonstandard>"},
	fractional = "tiers",
	multiplier = "triple",
	wplink = "3 (nombre)",
}

numbers[4] = {
	cardinal = "quatre",
	ordinal = "quatrième",
	ordinal_abbr = {"4e", "4ème<q:nonstandard>"},
	fractional = "quart",
	multiplier = "quadruple",
	wplink = "4 (nombre)",
}

make_number(5, "cinq", nil, "quintuple")
make_number(6, "six", nil, "sextuple")
make_number(7, "sept", nil, "septuple")
make_number(8, "huit", nil, "octuple")
make_number(9, "neuf", nil, "nonuple")
make_number(10, "dix", nil, "décuple")

-- Generate numbers from 11 through 19.
for i, teen in ipairs { "onze", "douze", "treize", "quatorze", "quinze", "seize",
	"dix-sept", "dix-huit", "dix-neuf" } do
	make_number(i + 10, teen)
end

-- Generate even multiples of 10 from 20 through 90.
for i, ten_multiple in ipairs { "vingt", "trente", "quarante", "cinquante", "soixante",
	{"soixante-dix<tag:vigesimal>", "septante<tag:decimal>"},
	{"quatre-vingts<tag:vigesimal>", "huitante<tag:decimal>", "octante<tag:decimal>"},
	{"quatre-vingt-dix<tag:vigesimal>", "nonante<tag:decimal>"},
} do
	make_number((i + 1) * 10, ten_multiple)
end

-- Generate numbers from 21 through 99, other than even multiples of ten.
for tens = 20, 90, 10 do
	for ones = 1, 9 do
		local num = tens + ones
		-- Generate the cardinal given the cardinal form for the tens (e.g. "trente", "septante", "quatre-vingt-dix",
		-- etc.). There are several special cases:
		-- (1) soixante and quatre-vingts are vigesimal, hence 72 = soixante-douze, 92 = quatre-vingt-douze.
		-- (2) -et- is inserted before "un" and "onze", but not after quatre-vingts.
		-- (3) quatre-vingts changes to quatre-vingt- before a ones numeral.
		local function generate_cardinal(tens_cardinal)
			local ones_cardinal
			tens_cardinal = rsub(tens_cardinal, "%-dix$", "") -- chop off -dix from vigesimal 70 and 90
			tens_cardinal = rsub(tens_cardinal, "ts$", "t") -- quatre-vingts -> quatre-vingt
			if tens_cardinal == "soixante" or tens_cardinal == "quatre-vingt" then
				-- vigesimal
				ones_cardinal = numbers[num % 20].cardinal
			else
				ones_cardinal = numbers[ones].cardinal
			end
			if ones == 1 and tens_cardinal ~= "quatre-vingt" or ones == 11 and tens_cardinal == "soixante" then
				return {("%s et %s<tag:traditional spelling>"):format(tens_cardinal, ones_cardinal),
					("%s-et-%s<tag:post-1990 spelling>"):format(tens_cardinal, ones_cardinal)}
			else
				return tens_cardinal .. "-" .. ones_cardinal
			end
		end

		local cardinal = map(generate_cardinal, numbers[tens].cardinal)
		make_number(num, cardinal)
	end
end

make_number(100, "cent", nil, "centuple")

-- Generate 200 through 900 by 100.
for i = 200, 900, 100 do
	local base = i / 100
	local base_cardinal = numbers[base].cardinal
	make_number(i,
		{base_cardinal .. " cents<tag:traditional spelling>", base_cardinal .. "-cents<tag:post-1990 spelling>"},
		{base_cardinal .. " centième<tag:traditional spelling>", base_cardinal .. "-centième<tag:post-1990 spelling>"}
	)
end

make_number(1000, "mille")

-- Generate 2000 through 10000 by 1000.
for i = 2000, 10000, 1000 do
	local base = i / 1000
	local base_cardinal = numbers[base].cardinal
	make_number(i,
		{base_cardinal .. " mille<tag:traditional spelling>", base_cardinal .. "-mille<tag:post-1990 spelling>"},
		{base_cardinal .. " millième<tag:traditional spelling>", base_cardinal .. "-millième<tag:post-1990 spelling>"}
	)
end

make_number(100000, {"cent mille<tag:traditional spelling>", "cent-mille<tag:post-1990 spelling"},
	{"cent millième<tag:traditional spelling>", "cent-millième<tag:post-1990 spelling>"})
make_number(1000000, {"[[un]] [[million]]<link:million><tag:traditional spelling>", "[[un]]-[[million]]<link:million><tag:post-1990 spelling>"},
	"millionième", nil, "million")
make_number(2000000, {"[[deux]] [[million]]s<tag:traditional spelling>", "[[deux]]-[[million]]s<tag:post-1990 spelling>"},
	{"deux millionième<tag:traditional spelling>", "deux-millionième<tag:post-1990 spelling>"})
make_number(power_of(9), {"[[un]] [[milliard]]<link:milliard><tag:traditional spelling>", "[[un]]-[[milliard]]<link:milliard><tag:post-1990 spelling>"},
	"milliardième", nil, "milliard")
make_number(power_of(12), {"[[un]] [[billion]]<link:billion><tag:traditional spelling>", "[[un]]-[[billion]]<link:billion><tag:post-1990 spelling>", "[[mille]] [[milliard]]s<tag:traditional spelling>", "[[mille]]-[[milliard]]s<tag:post-1990 spelling>"},
	{"billionième", "[[millième]] [[de]] [[milliardième]]"}, nil, "billion")
make_number(power_of(15), {"[[un]] [[billiard]]<link:billiard><tag:traditional spelling>", "[[un]]-[[billiard]]<link:billiard><tag:post-1990 spelling>", "[[un]] [[million]] [[de]] [[milliard]]s<tag:traditional spelling>", "[[un]]-[[million]] [[de]] [[milliard]]s<tag:post-1990 spelling>"},
	{"billiardième", "[[millionième]] [[de]] [[milliardième]]"}, nil, "billiard")
make_number(power_of(18), {"[[un]] [[trillion]]<link:trillion><tag:traditional spelling>", "[[un]]-[[trillion]]<link:trillion><tag:post-1990 spelling>", "[[un]] [[milliard]] [[de]] [[milliard]]s<tag:traditional spelling>", "[[un]]-[[milliard]] [[de]] [[milliard]]s<tag:post-1990 spelling>"},
	{"trillionième", "[[milliardième]] [[de]] [[milliardième]]"}, nil, "trillion")
make_number(power_of(21), {"[[un]] [[trilliard]]<link:trilliard><tag:traditional spelling>", "[[un]]-[[trilliard]]<link:trilliard><tag:post-1990 spelling>", "[[mille]] [[milliard]]s [[de]] [[milliard]]s<tag:traditional spelling>", "[[mille]]-[[milliard]]s [[de]] [[milliard]]s<tag:post-1990 spelling>"},
	{"trilliardième", "[[millième]] [[de]] [[milliardième]] [[de]] [[milliardième]]"},  nil, "trilliard")

local function make_high_number(power, base)
	make_number(power_of(power), {("[[un]] [[%s]]<link:%s><tag:traditional spelling>"):format(base, base), ("[[un]]-[[%s]]<link:%s><tag:post-1990 spelling>"):format(base, base)},
		base .. "ième", nil, base)
end

make_high_number(24, "quadrillion")
make_high_number(27, "quadrilliard")
make_high_number(30, "quintillion")
make_high_number(33, "quintilliard")
make_high_number(36, "sextillion")
make_high_number(39, "sextilliard")
make_high_number(42, "septillion")
make_high_number(45, "septilliard")
make_high_number(48, "octillion")
make_high_number(51, "octilliard")
make_high_number(54, "nonillion")
make_high_number(57, "nonilliard")
make_high_number(60, "décillion")
make_high_number(63, "décilliard")

return export
