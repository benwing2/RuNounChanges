local export = {numbers = {}}

local m_numutils = require("Module:number list/utils")
local map = m_numutils.map
local power_of = m_numutils.power_of

export.additional_number_types = {
	{key = "sequence_adverb", after = "ordinal"},
	{key = "polygon"},
	{key = "polygonal_adjective"},
	{key = "polyhedron"},
}

local numbers = export.numbers

local lcfirst = mw.getContentLanguage():lcfirst
local ucfirst = mw.getContentLanguage():ucfirst

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

local function make_number(num, props, card_base)
	local numstr = m_numutils.format_fixed(num)
	local with_thousands_dot = #numstr < 10 and m_numutils.add_thousands_separator(numstr, " ") or nil
	local with_thousands_space = #numstr < 10 and m_numutils.add_thousands_separator(numstr, " ") or nil
	local ordinal_abbr
	if with_thousands then
		if type(num) == "number" and num >= 20 or type(num) == "string" then
			ordinal_abbr = {with_thousands .. ".", with_thousands .. "ste"}
		else
			ordinal_abbr = with_thousands .. "."
		end
	end

	card_base = card_base or props.cardinal
	props.ordinal = props.ordinal or map(function(card) return add_ordinal_suffix(num, card) end, card_base)
	if props.wplink == true then
		props.wplink = card_base
	end
	if props.adverbial == true then
		props.adverbial = map(function(card) return add_suffix(numstr, card, "mal") end, card_base)
	end
	if props.multiplier == true then
		props.multiplier = map(function(card) return add_suffix(numstr, card, "fach") end, card_base)
	end
	if props.fractional == true then
		props.fractional = map(function(ord) return ucfirst(ord) .. "l" end, props.ordinal)
	end
	if props.sequence_adverb == true then
		props.sequence_adverb = map(function(ord) return ord .. "ns" end, props.ordinal)
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
for i, cardinal in ipairs { "zwei", "drei", "vier", "fünf", "sechs", "sieben", "acht", "neun", "zehn", "elf", "zwölf" } do
	local num = i + 1
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
			ones_prefix = number[ones].cardinal .. "und"
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

-- Do numbers 200 through 900 by 100.
for i=200, 900, 100 do
	make_number(i, {
		cardinal = number[i / 100].cardinal .. "hundert",
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

-- Do numbers 2000 through 9000 by 1000.
for i=2000, 9000, 1000 do
	make_number(i, {
		cardinal = number[i / 1000].cardinal .. "tausend",
		-- no wplink for any of these numbers
		adverbial = true,
		multiplier = true,
		fractional = true,
		-- sequence adverbs this large can't easily be attested.
	})
end

-- Do numbers 10000 through 90000 by 10000.
for i=10000, 90000, 10000 do
	make_number(i, {
		-- Need to use map() because of 30.
		cardinal = map(function(base_card) return base_card .. "tausend" end, number[i / 10000].cardinal),
		-- no wplink for any of these numbers
		adverbial = true,
		multiplier = true,
		fractional = true,
		-- sequence adverbs this large can't easily be attested.
	})
end

return export
