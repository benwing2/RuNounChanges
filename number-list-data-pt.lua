local export = {numbers = {}}

local numbers = export.numbers

numbers[0] = {
	cardinal = "zero",
	ordinal = "zerésimo",
}

numbers[1] = {
	cardinal = "um",
	ordinal = "primeiro",
	-- adverbial = "",
	-- multiplier = "",
	-- distributive = "",
	-- collective = "",
	-- fractional = "",
}

numbers[2] = {
	cardinal = "dois",
	ordinal = "segundo",
}

numbers[3] = {
	cardinal = "três",
	ordinal = "terceiro",
}

numbers[4] = {
	cardinal = "quatro",
	ordinal = "quarto",
}

numbers[5] = {
	cardinal = "cinco",
	ordinal = "quinto",
}

numbers[6] = {
	cardinal = "seis",
	ordinal = "sexto",
}

numbers[7] = {
	cardinal = "sete",
	ordinal = "sétimo",
}

numbers[8] = {
	cardinal = "oito",
	ordinal = "oitavo",
}

numbers[9] = {
	cardinal = "nove",
	ordinal = { "nono", "noveno" },
}

numbers[10] = {
	cardinal = "dez",
	ordinal = "décimo",
}

numbers[11] = {
	cardinal = "onze",
	ordinal = { "décimo primeiro", "undécimo" },
}

numbers[12] = {
	cardinal = "doze",
	ordinal = { "décimo segundo", "duodécimo" },
}

numbers[13] = {
	cardinal = "treze",
	ordinal = { "décimo terceiro", "tredécimo" },
}

numbers[14] = {
	cardinal = { "quatorze", "catorze" },
	ordinal = "décimo quarto",
}

numbers[15] = {
	cardinal = "quinze",
	ordinal = "décimo quinto",
}

numbers[16] = {
	cardinal = {"dezesseis<tag:Brazil>", "dezasseis<tag:Portugal>"},
	ordinal = "décimo sexto",
}

numbers[17] = {
	cardinal = {"dezessete<tag:Brazil>", "dezassete<tag:Portugal>"},
	ordinal = "décimo sétimo",
}

numbers[18] = {
	cardinal = "dezoito",
	ordinal = "décimo oitavo",
}

numbers[19] = {
	cardinal = {"dezenove<tag:Brazil>", "dezanove<tag:Portugal>"},
	ordinal = "décimo nono",
}

local function first_element_if_table(t)
	if type(t) == "table" then
		return t[1]
	else
		return t
	end
end

for i, vals in ipairs {
	{ "vinte", "vigésimo" },
	{ "trinta", "trigésimo" },
	{ "quarenta", "quadragésimo" },
	{ "cinquenta", "quinquagésimo" },
	{ "sessenta", "sexagésimo" },
	{ "setenta", "septagésimo" },
	{ "oitenta", "octagésimo" },
	{ "noventa", "nonagésimo" },
} do
	local tens = (i + 1) * 10
	local tens_cardinal, tens_ordinal = unpack(vals)
	numbers[tens] = {
		cardinal = tens_cardinal,
		ordinal = tens_ordinal,
	}
	
	for ones = 1, 9 do
		local ones_numeral = numbers[ones]
		numbers[tens + ones] = {
			cardinal = tens_cardinal .. " e " .. first_element_if_table(ones_numeral.cardinal),
			ordinal = tens_ordinal .. " " .. first_element_if_table(ones_numeral.ordinal),
		}
	end
end

local function add_number(number, cardinal, ordinal)
	numbers[number] = {
		cardinal = cardinal,
		ordinal = ordinal,
	}
end

add_number(100, "cem", "centésimo")
add_number(200, "duzentos", "ducentésimo")
add_number(300, "trezentos", "trecentésimo")
add_number(400, "quatrocentos", "quadrigentésimo")
add_number(500, "quinhentos", "quingentésimo")
add_number(600, "seiscentos", "sexcentésimo")
add_number(700, "setecentos", "septicentésimo")
add_number(800, "oitocentos", "octigentésimo")
add_number(900, "novecentos", "nongentésimo")
add_number(1000, "mil", "milésimo")
add_number(1e6, "um milhão", "milionésimo")
add_number(1e6, "um milhão", "milionésimo")
add_number(1e9, { "um bilhão", "mil milhões" }, "bilionésimo")
add_number(1e12, { "um trilhão", "um bilhão" }, { "trilionésimo", "bilionésimo" })

return export
