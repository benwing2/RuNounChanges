local export = {numbers = {}}

local m_numutils = require("Module:User:Benwing2/number list/utils")
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

make_number(100000, "cent mille", {"cent millième", "cent-millième"})
make_number(1000000, "[[un]] [[million]]<link:million>", "millionième", nil, "million")
make_number(2000000, "[[deux]] [[million]]s",
	{"deux millionième<tag:traditional spelling>", "deux-millionième<tag:post-1990 spelling>"})
make_number(power_of(9), "[[un]] [[milliard]]<link:milliard>", "milliardième", nil, "milliard")
make_number(power_of(12), {"[[un]] [[billion]]<link:billion>", "[[mille]] [[milliard]]s"},
	{"[[billionième]], [[millième]] [[de]] [[milliardième]]"}, nil, "billion")
make_number(power_of(15), {"[[un]] [[billiard]]<link:billiard>", "[[un]] [[million]] [[de]] [[milliard]]s"},
	{"billiardième", "[[millionième]] [[de]] [[milliardième]]"}, nil, "billiard")
make_number(power_of(18), {"[[un]] [[trillion]]<link:trillion>", "[[un]] [[milliard]] [[de]] [[milliard]]s"},
	{"trillionième", "[[milliardième]] [[de]] [[milliardième]]"}, nil, "trillion")
make_number(power_of(21), {"[[un]] [[trilliard]]<link:trilliard>", "[[mille]] [[milliard]]s [[de]] [[milliard]]s"},
	{"trilliardième", "[[millième]] [[de]] [[milliardième]] [[de]] [[milliardième]]"},  nil, "trilliard")
make_number(power_of(24), "[[un]] [[quadrillion]]<link:quadrillion>", "quadrillionième", nil, "quadrillion")
make_number(power_of(27), "[[un]] [[quadrilliard]]<link:quadrilliard>", "quadrilliardième", nil, "quadrilliard")
make_number(power_of(30), "[[un]] [[quintillion]]<link:quintillion>", "quintillionième", nil, "quintillion")
make_number(power_of(33), "[[un]] [[quintilliard]]<link:quintilliard>", "quintilliardième", nil, "quintilliard")
make_number(power_of(36), "[[un]] [[sextillion]]<link:sextillion>", "sextillionième", nil, "sextillion")
make_number(power_of(39), "[[un]] [[sextilliard]]<link:sextilliard>", "sextilliardième", nil, "sextilliard")
make_number(power_of(42), "[[un]] [[septillion]]<link:septillion>", "septillionième", nil, "septillion")
make_number(power_of(45), "[[un]] [[septilliard]]<link:septilliard>", "septilliardième", nil, "septilliard")
make_number(power_of(48), "[[un]] [[octillion]]<link:octillion>", "octillionième", nil, "octillion")
make_number(power_of(51), "[[un]] [[octilliard]]<link:octilliard>", "octilliardième", nil, "octilliard")
make_number(power_of(54), "[[un]] [[nonillion]]<link:nonillion>", "nonillionième", nil, "nonillion")
make_number(power_of(57), "[[un]] [[nonilliard]]<link:nonilliard>", "nonilliardième", nil, "nonilliard")
make_number(power_of(60), "[[un]] [[décillion]]<link:décillion>", "décillionième", nil, "décillion")
make_number(power_of(63), "[[un]] [[décilliard]]<link:décilliard>", "décilliardième", nil, "décilliard")

return export
