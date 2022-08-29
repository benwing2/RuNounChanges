local export = {numbers = {}}

local m_numutils = require("Module:number list/utils")
local map = m_numutils.map
local power_of = m_numutils.power_of

export.additional_number_types = {
	{key = "sequence_adverb", after = "ordinal"},
	{key = "adverbial_abbreviation", after = "adverbial"},
	{key = "multiplier_abbreviation", after = "multiplier"},
	{key = "polygon"},
	{key = "polygon_abbreviation"},
	{key = "polygonal_adjective"},
	{key = "polygonal_adjective_abbreviation"},
	{key = "polyhedron"},
	{key = "polyhedron_abbreviation"},
}

local numbers = export.numbers

local lcfirst = function(text) return mw.getContentLanguage():lcfirst(text) end
local ucfirst = function(text) return mw.getContentLanguage():ucfirst(text) end

local function add_ordinal_suffix(num, term)
	term = lcfirst(term):gsub("e$", "")
	if type(num) == "number" and num < 20 then
		return term .. "te"
	else
		return term .. "ste"
	end
end

local function add_suffix(numstr, term, suffix)
	term = lcfirst(term):gsub("e$", "")
	if #numstr >= 7 and not term:find("en$") then
		-- Million -> millionenmal, Milliarde -> milliardenmal
		term = term .. "en"
	end
	return term .. suffix
end

local function has_polygon(num)
	if type(num) == "string" then
		return false
	end
	return num >= 3 and num <= 22 or num == 24 or num == 27 or num == 28 or num == 30 or num == 31 or num == 32 or
		num == 34 or num == 36 or num == 40 or num == 48 or num == 50 or num == 51 or num == 60 or num == 70 or
		num == 80
end

local function make_number(num, props, card_base)
	local numstr = m_numutils.format_fixed(num)
	local ordinal_abbr
	if #numstr < 10 then
		local with_thousands_dot = m_numutils.add_thousands_separator(numstr, ".") .. "."
		local with_thousands_space = m_numutils.add_thousands_separator(numstr, " ") .. "."
		if with_thousands_dot == with_thousands_space then
			ordinal_abbr = with_thousands_dot
		else
			ordinal_abbr = {with_thousands_dot, with_thousands_space}
		end
	end

	card_base = card_base or props.cardinal
	props.ordinal = props.ordinal or map(function(card) return add_ordinal_suffix(num, card) end, card_base)
	props.ordinal_abbr = ordinal_abbr
	if props.wplink == true then
		props.wplink = card_base
	end
	if props.adverbial == true then
		props.adverbial = map(function(card) return add_suffix(numstr, card, "mal") end, card_base)
	end
	if props.adverbial and type(num) == "number" and num <= 100 then
		props.adverbial_abbreviation = num .. "-mal"
	end
	if props.multiplier == true then
		props.multiplier = map(function(card) return add_suffix(numstr, card, "fach") end, card_base)
	end
	if props.multiplier and type(num) == "number" and num <= 100 then
		props.multiplier_abbreviation = num .. "-fach"
	end
	if props.fractional == true then
		props.fractional = map(function(ord) return ucfirst(ord) .. "l" end, props.ordinal)
	end
	if props.sequence_adverb == true then
		props.sequence_adverb = map(function(ord) return ord .. "ns" end, props.ordinal)
	end
	if has_polygon(num) then
		props.polygon = map(function(card) return ucfirst(card) .. "eck" end, card_base)
		props.polygon_abbreviation = num .. "-Eck"
		props.polygonal_adjective = map(function(polygon) return lcfirst(polygon) .. "ig" end, props.polygon)
		props.polygonal_adjective_abbreviation = num .. "-eckig"
	end

	numbers[num] = props
end

make_number(0, {
	cardinal = "null",
	wplink = true,
	adverbial = true,
	multiplier = true,
})
make_number(1, {
	cardinal = {"eins", "ein<q:before a noun>"},
	ordinal = "erste",
	wplink = "eins",
	adverbial = true,
	multiplier = true,
	fractional = "Ganzes",
	sequence_adverb = true,
}, "ein")
make_number(2, {
	cardinal = "zwei",
	wplink = true,
	adverbial = true,
	multiplier = true,
	fractional = "Hälfte",
	sequence_adverb = true,
})

-- Do numbers 3 through 12.
for i, cardinal in ipairs { "drei", "vier", "fünf", "sechs", "sieben", "acht", "neun", "zehn", "elf", "zwölf" } do
	local num = i + 2
	local ordinal
	if num == 3 then
		ordinal = "dritte"
	elseif num == 7 then
		ordinal = "siebte"
	elseif num == 8 then
		ordinal = "achte"
	else
		ordinal = cardinal .. "te"
	end
	make_number(num, {
		cardinal = cardinal,
		ordinal = ordinal,
		wplink = true,
		adverbial = true,
		multiplier = true,
		fractional = true,
		sequence_adverb = true,
	})
end

-- Do numbers 13 through 19.
for i, teen in ipairs {
	"dreizehn", "vierzehn", "fünfzehn", "sechzehn", "siebzehn", "achtzehn", "neunzehn"
} do
	local num = i + 12
	make_number(num, {
		cardinal = teen,
		wplink = true,
		adverbial = true,
		multiplier = true,
		fractional = true,
		sequence_adverb = true,
	})
end

-- Do numbers 20 through 99.
for i, tens_cardinal in ipairs {
	"zwanzig", {"dreißig<tag:Germany, Austria>", "dreissig<tag:Switzerland, Liechtenstein>"}, "vierzig", "fünfzig",
	"sechzig", "siebzig", "achtzig", "neunzig",
} do
	local tens = (i + 1) * 10
	for ones = 0, 9 do
		local num = tens + ones
		local ones_prefix
		if ones == 0 then
			ones_prefix = ""
		elseif ones == 1 then
			ones_prefix = "einund"
		else
			ones_prefix = numbers[ones].cardinal .. "und"
		end
		local cardinal = map(function(tens_card) return ones_prefix .. tens_card end, tens_cardinal)
		local wplink
		if num >= 30 and num <= 39 then
			wplink = ones_prefix .. "dreißig"
		elseif num <= 40 or num == 50 or num == 60 or num == 64 or num == 72 or num == 73 or num == 88 or
			num == 97 or num == 98 or num == 99 then
			-- Really random collection of numbers for which there are currently German Wikipedia entries.
			wplink = true
		end
		make_number(num, {
			cardinal = cardinal,
			wplink = wplink,
			adverbial = true,
			multiplier = true,
			fractional = true,
			sequence_adverb = true,
		})
	end
end

make_number(100, {
	cardinal = {"hundert", "einhundert"},
	wplink = true,
	adverbial = true,
	multiplier = true,
	fractional = true,
	sequence_adverb = true,
}, "hundert")

make_number(101, {
	cardinal = {"hunderteins", "einhunderteins"},
	ordinal = {"hunderterste", "einhunderterste"},
	adverbial = true,
	multiplier = true,
	fractional = true,
	sequence_adverb = true,
}, {"hundertein", "einhundertein"})

-- Do numbers 200 through 900 by 100.
for i=200, 900, 100 do
	make_number(i, {
		cardinal = numbers[i / 100].cardinal .. "hundert",
		-- no wplink for any of these numbers
		adverbial = true,
		multiplier = true,
		fractional = true,
		sequence_adverb = true,
	})
end

make_number(1000, {
	cardinal = {"tausend", "eintausend"},
	wplink = true,
	adverbial = true,
	multiplier = true,
	fractional = true,
	sequence_adverb = true,
}, "tausend")

local function make_large_number(num, cardinal, card_base, wplink)
	make_number(num, {
		cardinal = cardinal,
		wplink = wplink,
		adverbial = true,
		multiplier = true,
		fractional = true,
		-- sequence adverbs this large can't easily be attested.
	}, card_base)
end

-- Do numbers 2000 through 9000 by 1000.
for i=2000, 9000, 1000 do
	-- no wplink for any of these numbers
	make_large_number(i, numbers[i / 1000].cardinal .. "tausend")
end

-- Do numbers 10,000 through 90,000 by 10,000.
for i=10000, 90000, 10000 do
	-- no wplink for any of these numbers
	make_large_number(i,
		-- Need to use map() because of 30.
		map(function(base_card) return base_card .. "tausend" end, numbers[i / 1000].cardinal)
	)
end

-- Do numbers 100,000 through 900,000 by 100,000.
for i=100000, 900000, 100000 do
	-- no wplink for any of these numbers
	make_large_number(i,
		-- Need to use map() because of 100.
		map(function(base_card) return base_card .. "tausend" end, numbers[i / 1000].cardinal)
	)
end

make_large_number(1000000, "[[ein|eine]] [[Million]]<link:Million>", "million", "Million")
make_large_number(2000000, "[[zwei]] [[Million]]en", "zweimillion")
make_large_number(power_of(7), "[[zehn]] [[Million]]en", "zehnmillion")
make_large_number(power_of(8), "[[hundert]] [[Million]]en", "hundertmillion")
make_large_number(power_of(9), "[[ein|eine]] [[Milliarde]]<link:Milliarde>", "milliard", "Milliarde")
make_large_number(power_of(9, 2), "[[zwei]] [[Milliarde]]n", "zweimilliard")
make_large_number(power_of(10), "[[zehn]] [[Milliarde]]n", "zehnmilliard")
make_large_number(power_of(11), "[[hundert]] [[Milliarde]]n", "hundertmilliard")
make_large_number(power_of(12), "[[ein|eine]] [[Billion]]<link:Billion>", "billion", "Billion")
make_large_number(power_of(13), "[[zehn]] [[Billion]]en", "zehnbillion")
make_large_number(power_of(14), "[[hundert]] [[Billion]]en", "hundertbillion")
make_large_number(power_of(15), "[[ein|eine]] [[Billiarde]]<link:Billiarde>", "billiard", "Billiarde")
make_large_number(power_of(18), "[[ein|eine]] [[Trillion]]<link:Trillion>", "trillion", "Trillion")
make_large_number(power_of(21), "[[ein|eine]] [[Trilliarde]]<link:Trilliarde>", "trilliard", "Trilliarde")
make_large_number(power_of(24), "[[ein|eine]] [[Quadrillion]]<link:Quadrillion>", "quadrillion", "Quadrillion")
make_large_number(power_of(27), "[[ein|eine]] [[Quadrilliarde]]<link:Quadrilliarde>", "quadrilliard", "Quadrilliarde")
make_large_number(power_of(30), "[[ein|eine]] [[Quintillion]]<link:Quintillion>", "quintillion", "Quintillion")
make_large_number(power_of(33), "[[ein|eine]] [[Quintilliarde]]<link:Quintilliarde>", "quintilliard", "Quintilliarde")
make_large_number(power_of(36), "[[ein|eine]] [[Sextillion]]<link:Sextillion>", "sextillion", "Sextillion")
make_large_number(power_of(39), "[[ein|eine]] [[Sextilliarde]]<link:Sextilliarde>", "sextilliard", "Sextilliarde")
make_large_number(power_of(42), "[[ein|eine]] [[Septillion]]<link:Septillion>", "septillion", "Septillion")
make_large_number(power_of(45), "[[ein|eine]] [[Septilliarde]]<link:Septilliarde>", "septilliard", "Septilliarde")
make_large_number(power_of(48), "[[ein|eine]] [[Oktillion]]<link:Oktillion>", "oktillion", "Oktillion")
make_large_number(power_of(51), "[[ein|eine]] [[Oktilliarde]]<link:Oktilliarde>", "oktilliard", "Oktilliarde")
make_large_number(power_of(54), "[[ein|eine]] [[Nonillion]]<link:Nonillion>", "nonillion", "Nonillion")
make_large_number(power_of(57), "[[ein|eine]] [[Nonilliarde]]<link:Nonilliarde>", "nonilliard", "Nonilliarde")
make_large_number(power_of(60), "[[ein|eine]] [[Dezillion]]<link:Dezillion>", "dezillion", "Dezillion")
make_large_number(power_of(63), "[[ein|eine]] [[Dezilliarde]]<link:Dezilliarde>", "dezilliard", "Dezilliarde")
make_large_number(power_of(66), "[[ein|eine]] [[Undezillion]]<link:Undezillion>", "undezillion", "Undezillion")
make_large_number(power_of(69), "[[ein|eine]] [[Undezilliarde]]<link:Undezilliarde>", "undezilliard", "Undezilliarde")
make_large_number(power_of(72), "[[ein|eine]] [[Duodezillion]]<link:Duodezillion>", "duodezillion", "Duodezillion")
make_large_number(power_of(75), "[[ein|eine]] [[Duodezilliarde]]<link:Duodezilliarde>", "duodezilliard", "Duodezilliarde")
make_large_number(power_of(78), "[[ein|eine]] [[Tredezillion]]<link:Tredezillion>", "tredezillion", "Tredezillion")
make_large_number(power_of(81), "[[ein|eine]] [[Tredezilliarde]]<link:Tredezilliarde>", "tredezilliard", "Tredezilliarde")
make_large_number(power_of(84), "[[ein|eine]] [[Quattuordezillion]]<link:Quattuordezillion>", "quattuordezillion", "Quattuordezillion")
make_large_number(power_of(87), "[[ein|eine]] [[Quattuordezilliarde]]<link:Quattuordezilliarde>", "quattuordezilliard", "Quattuordezilliarde")
make_large_number(power_of(120), "[[ein|eine]] [[Vigintillion]]<link:Vigintillion>", "vigintillion", "Vigintillion")
make_large_number(power_of(123), "[[ein|eine]] [[Vigintilliarde]]<link:Vigintilliarde>", "vigintilliard", "Vigintilliarde")

return export
