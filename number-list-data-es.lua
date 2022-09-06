local export = {numbers = {}}

local m_numutils = require("Module:number list/utils")
local power_of = m_numutils.power_of

export.additional_number_types = {
	{key = "apocopated_cardinal", after = "cardinal"},
	{key = "apocopated_ordinal", after = "ordinal"},
}

local numbers = export.numbers

local function make_number(num, number)
	local numstr = m_numutils.format_fixed(num)
	number.wplink = number.wplink or type(num) == "number" and num < 1000 and number.cardinal or nil
	number.ordinal_abbr = number.ordinal_abbr or #numstr < 10 and m_numutils.add_thousands_separator(numstr, " ") .. ".º" or nil
	numbers[num] = number
end

local function make_simple_number(num, cardinal, ordinal, fractional, wplink)
	make_number(num, {
		cardinal = cardinal,
		ordinal = ordinal,
		fractional = fractional or ordinal,
		wplink = wplink,
	})
end

make_number(0, {
	cardinal = "cero",
	ordinal = { "cero", "ceroésimo" },
})

make_number(1, {
	cardinal = "uno",
	apocopated_cardinal = "un",
	ordinal = "primero",
	apocopated_ordinal = "primer",
	multiplier = "simple",
})

make_number(2, {
	cardinal = "dos",
	ordinal = "segundo",
	multiplier = "doble",
	fractional = { "medio", "mitad" },
})

make_number(3, {
	cardinal = "tres",
	ordinal = "tercero",
	apocopated_ordinal = "tercer",
	multiplier = "triple",
	fractional = "tercio",
})

make_number(4, {
	cardinal = "cuatro",
	ordinal = "cuarto",
	multiplier = "cuádruple",
	fractional = "cuarto",
})

make_number(5, {
	cardinal = "cinco",
	ordinal = "quinto",
	multiplier = "quíntuple",
	fractional = "quinto",
})

make_number(6, {
	cardinal = "seis",
	ordinal = "sexto",
	multiplier = "séxtuple",
	fractional = { "sexto", "seisavo" },
})

make_number(7, {
	cardinal = "siete",
	ordinal = {"séptimo", "sétimo" },
	multiplier = "séptuple",
	fractional = {"séptimo", "sétimo" },
})

make_number(8, {
	cardinal = "ocho",
	ordinal = "octavo",
	multiplier = "óctuple",
	fractional = "octavo",
})

make_number(9, {
	cardinal = "nueve",
	ordinal = "noveno",
	multiplier = "nónuple",
	fractional = "noveno",
})

make_number(10, {
	cardinal = "diez",
	ordinal = "décimo",
	multiplier = "décuplo",
	fractional = "décimo",
})

make_number(11, {
	cardinal = "once",
	ordinal = { "undécimo", "decimoprimero", "décimo primero" },
	apocopated_ordinal = { "decimoprimer", "décimo primer" },
	multiplier = "undécuple",
	fractional = {"onceavo", "undécimo"},
})

make_number(12, {
	cardinal = "doce",
	ordinal = { "duodécimo", "decimosegundo", "décimo segundo" },
	multiplier = "duodécuple",
	fractional = {"doceavo", "duodécimo"},
})

-- Do 13 through 19
for i, cardinal in ipairs {
	"trece", "catorce", "quince", "dieciséis", "diecisiete", "dieciocho", "diecinueve"
} do
	local num = i + 13 - 1
	local ones = num - 10
	local ordinal
	if num == 17 then
		-- Special-case because of alternative ordinal [[sétimo]], which appears not in use in compound ordinals.
		ordinal = {"decimoséptimo", "décimo séptimo"}
	elseif num == 18 then
		-- Special-case because of single-word form [[decimoctavo]].
		ordinal = {"decimoctavo", "décimo octavo"}
	else
		local ones_ordinal = numbers[ones].ordinal
		ordinal = {"decimo" .. ones_ordinal, "décimo " .. ones_ordinal}
	end
	local apocopated_ordinal
	if num == 13 then
		apocopated_ordinal = {"decimotercer", "décimo tercer"}
	end
	local fractional
	if num == 16 then
		fractional = "dieciseisavo"
	elseif num == 18 then
		-- https://www.rae.es/dpd/fraccionarios, point 4 allows -ochavo
		fractional = {"dieciochoavo", "dieciochavo"}
	else
		fractional = cardinal .. "avo"
	end
	make_number(num, {
		cardinal = cardinal,
		ordinal = ordinal,
		apocopated_ordinal = apocopated_ordinal,
		fractional = fractional,
	})
end

-- Do 20 through 29. We handle separately from 30 through 99 because of various special cases.
make_simple_number(20, "veinte", "vigésimo", {"veinteavo", "vigésimo"})
for ones = 1, 9 do
	local num = 20 + ones
	local ones_cardinal = numbers[ones].cardinal

	local cardinal
	if num == 22 then
		cardinal = "veintidós"
	elseif num == 23 then
		cardinal = "veintitrés"
	elseif num == 26 then
		cardinal = "veintiséis"
	else
		-- veintiuno, veinticuatro, etc.
		cardinal = "veinti" .. ones_cardinal
	end

	local ordinal
	if num == 27 then
		-- Special-case because of alternative ordinal [[sétimo]], which appears not in use in compound ordinals.
		ordinal = {"vigesimoséptimo", "vigésimo séptimo"}
	elseif num == 28 then
		-- Special-case because of single-word form [[vigesimoctavo]].
		ordinal = {"vigesimoctavo", "vigésimo octavo"}
	else
		local ones_ordinal = numbers[ones].ordinal
		ordinal = {"vigesimo" .. ones_ordinal, "vigésimo " .. ones_ordinal}
	end

	local fractional
	if num == 21 then
		-- Non-even multiples of ten less than 100 use only -avo.
		fractional = "veintiunavo"
	elseif num == 28 then
		-- https://www.rae.es/dpd/fraccionarios, point 4 allows -ochavo
		fractional = {"veintiochoavo", "veintiochavo"}
	else
		fractional = "veinti" .. ones_cardinal .. "avo"
	end

	local apocopated_cardinal, apocopated_ordinal
	if num == 21 then
		apocopated_cardinal = "veintiún"
		apocopated_ordinal = {"vigesimoprimer", "vigésimo primer"}
	elseif num == 23 then
		apocopated_ordinal = {"vigesimotercer", "vigésimo tercer"}
	end

	make_number(num, {
		cardinal = cardinal,
		apocopated_cardinal = apocopated_cardinal,
		ordinal = ordinal,
		apocopated_ordinal = apocopated_ordinal,
		fractional = fractional,
	})
end

-- Do 30 through 99.
for i, cardinal_and_ordinal in ipairs {
	{ "treinta", "trigésimo" },
	{ "cuarenta", "cuadragésimo" },
	{ "cincuenta", "quincuagésimo" },
	{ "sesenta", "sexagésimo" },
	{ "setenta", "septuagésimo" },
	{ "ochenta", "octogésimo" },
	{ "noventa", "nonagésimo" },
} do
	local tens_cardinal, tens_ordinal = unpack(cardinal_and_ordinal)
	local tens = (i + 2) * 10
	make_number(tens, {
		cardinal = tens_cardinal,
		ordinal = tens_ordinal,
		fractional = {tens_cardinal .. "vo", tens_ordinal},
	})
	for ones = 1, 9 do
		local ones_cardinal = numbers[ones].cardinal
		local ones_ordinal
		if ones == 7 then
			-- [[sétimo]] appears not in use in compound ordinals
			ones_ordinal = "séptimo"
		else
			ones_ordinal = numbers[ones].ordinal
		end
		local cardinal = tens_cardinal .. " y " .. ones_cardinal
		local ordinal = tens_ordinal .. " " .. ones_ordinal
		local apocopated_cardinal, apocopated_ordinal
		if ones == 1 then
			apocopated_cardinal = tens_cardinal .. " y ún"
		end
		if ones == 1 or ones == 3 then
			apocopated_ordinal = ordinal:gsub("ero$", "er")
		end

		local fractional_base = tens_cardinal .. "i"
		if ones == 1 then
			-- Non-even multiples of ten less than 100 use only -avo.
			fractional = fractional_base .. "unavo"
		elseif ones == 8 then
			-- https://www.rae.es/dpd/fraccionarios, point 4 allows -ochavo
			fractional = {fractional_base .. "ochoavo", fractional_base .. "ochavo"}
		else
			fractional = fractional_base .. ones_cardinal .. "avo"
		end

		make_number(tens + ones, {
			cardinal = cardinal,
			apocopated_cardinal = apocopated_cardinal,
			ordinal = ordinal,
			apocopated_ordinal = apocopated_ordinal,
			fractional = fractional,
		})
	end
end

make_number(100, {
	cardinal = {"cien", "ciento<q:before lower numerals>"},
	ordinal = "centésimo",
	multiplier = "céntuplo",
	fractional = {"centésimo", "centavo", "céntimo"},
	wplink = "cien",
})

make_number(101, {
	cardinal = "ciento uno",
	apocopated_cardinal = "ciento un",
	ordinal = "centésimo primero",
	apocopated_ordinal = "centésimo primer",
	fractional = "centésimo primero",
})

-- Generate 200 through 900 by 100.
for i, cardinal_and_ordinal in ipairs {
	{ "doscientos", "ducentésimo" },
	{ "trescientos", "tricentésimo" },
	{ "cuatrocientos", "cuadringentésimo" },
	{ "quinientos", "quingentésimo" },
	{ "seiscientos", "sexcentésimo" },
	{ "setecientos", "septingentésimo" },
	{ "ochocientos", "octingentésimo" },
	{ "novecientos", "noningentésimo" },
} do
	local cardinal, ordinal = unpack(cardinal_and_ordinal)
	-- Formerly listed doscientosavo, trescientosavo, etc. first as fractional forms; but these forms do not exist per
	-- the RAE https://www.rae.es/dpd/fraccionarios, and are very rare in Google Ngrams.
	make_simple_number((i + 1) * 100, cardinal, ordinal)
end

make_simple_number(1000, "mil", "milésimo", "milésimo")

-- Generate 2000 through 10000 by 1000.
for i = 2000, 10000, 1000 do
	local base = i / 1000
	local base_cardinal = numbers[base].cardinal
	make_simple_number(i, base_cardinal .. " mil", base_cardinal .. "milésimo")
end

make_simple_number(20000, "veinte mil", "veintemilésimo")
make_simple_number(21000, "veintiún mil", "veintiunmilésimo")
make_simple_number(100000, "cien mil", "cienmilésimo")
make_simple_number(200000, "doscientos mil", "doscientosmilésimo")
make_simple_number(1000000, "[[un]] [[millón]]<link:millón>", "millonésimo", nil, "millón")
make_simple_number(2000000, "[[dos]] [[millón|millones]]", "dosmillonésimo")
make_simple_number(10000000, "[[diez]] [[millón|millones]]", "diezmillonésimo")
make_simple_number(100000000, "[[cien]] [[millón|millones]]", "cienmillonésimo")
make_simple_number(power_of(9), {"mil millones", "[[un]] [[millardo]]<link:millardo>"}, {"milmillonésimo", "millardésimo"}, nil, "millardo")

local function make_large_number(power, cardinal, nowplink)
	local ordinal = cardinal:gsub("ón$", "onésimo")
	make_simple_number(power_of(power), ("[[un]] [[%s]]<link:%s>"):format(cardinal, cardinal), ordinal, nil,
		not nowplink and cardinal or nil)
end

make_large_number(12, "billón")
make_large_number(18, "trillón")
make_large_number(24, "cuatrillón")
make_large_number(30, "quintillón")
make_large_number(36, "sextillón")
make_large_number(42, "septillón")
make_large_number(48, "octillón")
make_large_number(54, "nonillón", "nowplink") -- no Spanish Wikipedia entry for [[nonillón]]
make_large_number(60, "decillón", "nowplink") -- no Spanish Wikipedia entry for [[decillón]]
make_large_number(66, "undecillón")
make_large_number(72, "duodecillón")
make_large_number(78, "tredecillón")
make_large_number(84, "cuatrodecillón")
make_large_number(90, "quindecillón")
make_large_number(96, "sexdecillón")
make_large_number(102, "septendecillón")
make_large_number(108, "octodecillón")
make_large_number(114, "novendecillón")
make_large_number(120, "vigintillón")

return export
