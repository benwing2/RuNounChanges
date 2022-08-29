local export = {numbers = {}}

local m_numutils = require("Module:number list/utils")
local map = m_numutils.map
local power_of = m_numutils.power_of

export.additional_number_types = {
	{key = "group"},
}

local numbers = export.numbers

local function make_number(num, cardinal, ordinal, wplink, fractional)
	local numstr = m_numutils.format_fixed(num)
	local thousands_numstr = #numstr < 10 and m_numutils.add_thousands_separator(numstr, ".") or nil
	if not fractional then
		-- exceptions to the following rules need to be given explicitly
		if num == 0 or num == 1 then
			-- no fractional
		elseif type(num) == "number" and num <= 10 then
			fractional = ordinal
		else
			local avos_form = map(function(card)
				if not card:find("%[") then
					card = ("[[%s]]"):format(card)
				end
				return ("%s [[avo]]s"):format(card)
			end, cardinal)
			if fractional == true then
				-- both ordinal and cardinal + avos are possible
				local combined = {}
				local function insert_one_or_more(els)
					if type(els) == "table" then
						for _, el in ipairs(els) do
							table.insert(combined, el)
						end
					else
						table.insert(combined, els)
					end
				end
				insert_one_or_more(ordinal)
				insert_one_or_more(avos_form)
				fractional = combined
			else
				fractional = avos_form
			end
		end
	end
	numbers[num] = {
		cardinal = cardinal,
		ordinal = ordinal,
		ordinal_abbr = thousands_numstr and {thousands_numstr .. "º", thousands_numstr .. ".º"} or nil,
		fractional = fractional,
		wplink = wplink,
	}
end

make_number(0, "zero", "zerésimo", "0 (número)")
make_number(1, "um", "primeiro", "um")
numbers[1].multiplier = {"único", "singular"}
make_number(2, "dois", "segundo", "dois", {"meio", "mitade"})
numbers[2].multiplier = {"dobro", "duplo"}
numbers[2].group = {"dupla", "par", "duo"}
make_number(3, "três", "terceiro", "três")
numbers[3].multiplier = {"triplo", "tríplice"}
numbers[3].group = {"trio", "trinca", "terceto", "tríade"}
make_number(4, "quatro", "quarto", "quatro")
numbers[4].multiplier = "quádruplo"
numbers[4].group = "quarteto"
make_number(5, "cinco", "quinto", "cinco")
numbers[5].multiplier = "quíntuplo"
numbers[5].group = "quinteto"
make_number(6, "seis", "sexto", "seis")
numbers[6].multiplier = "sêxtuplo"
numbers[6].group = "sexteto"
make_number(7, "sete", "sétimo", "sete")
numbers[7].multiplier = {"sétuplo", "séptuplo"}
numbers[7].group = "septeto"
make_number(8, "oito", "oitavo", "oito")
numbers[8].multiplier = "óctuplo"
numbers[8].group = "octeto"
make_number(9, "nove", {"nono", "noveno"}, "nove")
numbers[9].multiplier = {"nônuplo<tag:Brazil>", "nónuplo<tag:Portugal>"}
numbers[9].group = "noneto"
make_number(10, "dez", "décimo", "dez")
numbers[10].multiplier = "décuplo"
make_number(11, "onze", {"décimo primeiro", "undécimo"}, nil, {"undécimo", "[[onze]] [[avo]]s"})
numbers[11].multiplier = "undécuplo"
make_number(12, "doze", {"décimo segundo", "duodécimo"}, nil, {"duodécimo", "[[doze]] [[avo]]s"})
numbers[12].multiplier = "duodécuplo"
make_number(13, "treze", "décimo terceiro", "treze")
make_number(14, {"catorze", "quatorze"}, "décimo quarto", "catorze")
make_number(15, "quinze", "décimo quinto")
make_number(16, {"dezesseis<tag:Brazil>", "dezasseis<tag:Portugal>"}, "décimo sexto")
make_number(17, {"dezessete<tag:Brazil>", "dezassete<tag:Portugal>"}, "décimo sétimo", "17 (número)")
make_number(18, "dezoito", "décimo oitavo", "dezoito")
make_number(19, {"dezenove<tag:Brazil>", "dezanove<tag:Portugal>"}, "décimo nono")

for i, vals in ipairs {
	{ "vinte", "vigésimo" },
	{ "trinta", "trigésimo" },
	{ "quarenta", "quadragésimo" },
	{ "cinquenta", "quinquagésimo" },
	{ "sessenta", "sexagésimo" },
	{ "setenta", {"septuagésimo", "setuagésimo"}, },
	{ "oitenta", "octogésimo" },
	{ "noventa", "nonagésimo" },
} do
	local tens = (i + 1) * 10
	local tens_cardinal, tens_ordinal = unpack(vals)
	local function has_wplink(num)
		-- random collection of numbers with Portuguese Wikipedia entries; update as appropriate
		return num == 23 or num == 25 or num == 30 or num == 35 or num == 36 or num == 37
	end

	-- true here means both ordinal and cardinal + avos are possible fractional forms
	make_number(tens, tens_cardinal, tens_ordinal, has_wplink(tens) and tens_cardinal or nil, true)

	for ones = 1, 9 do
		local num = tens + ones
		local ones_numeral = numbers[ones]
		local ones_ordinal = ones_numeral.ordinal
		if ones == 9 then
			ones_ordinal = "nono"
		end
		local cardinal = tens_cardinal .. " e " .. ones_numeral.cardinal
		-- Use map() because of 70th.
		local ordinal = map(function(tens_ord) return tens_ord .. " " .. ones_ordinal end, tens_ordinal)
		local wplink = has_wplink(num) and tens_cardinal or nil
		make_number(num, cardinal, ordinal, wplink)
	end
end

-- Ordinals from https://www.normaculta.com.br/numerais-ordinais/
-- Fractionals from https://www.normaculta.com.br/numerais-fracionarios/
-- Note that the above site says 1/100 = only "um centésimo", but in fact "um cem avos" is also common and endorsed by
-- other sites such as http://www.uel.br/projetos/matessencial/basico/fundamental/fracoes.html
make_number(100, {"cem<q:alone or followed by a noun or higher numeral>", "cento<q:followed by a lower numeral>"}, "centésimo", nil, {"centésimo", "[[cem]] [[avo]]s"})
numbers[100].multiplier = "cêntuplo"
make_number(200, "duzentos", "ducentésimo", nil, true)
make_number(300, "trezentos", {"trecentésimo", "tricentésimo"}, nil, true)
make_number(400, "quatrocentos", "quadringentésimo", nil, true)
make_number(500, "quinhentos", "quingentésimo", "quinhentos", true)
make_number(600, "seiscentos", {"sexcentésimo", "seiscentésimo"}, "seiscentos", true)
make_number(700, "setecentos", {"septingentésimo", "setingentésimo"}, "setecentos", true)
make_number(800, "oitocentos", "octingentésimo", nil, true)
make_number(900, "novecentos", {"noningentésimo", "nongentésimo"}, "novecentos", true)
make_number(1000, "mil", "milésimo", nil, true)
make_number(10000, "[[dez]] [[mil]]", {"[[décimo]] [[milésimo]]", "[[décimo]] [[de]] [[milésimo]]"}, "dez mil", true)
make_number(100000, "[[cem]] [[mil]]", {"[[centésimo]] [[milésimo]]", "[[centésimo]] [[de]] [[milésimo]]"}, nil, true)
make_number(1000000, "[[um]] [[milhão]]<link:milhão>", "milionésimo", "milhão", true)
make_number(10000000, "[[dez]] [[milhão|milhões]]", {"[[décimo]] [[milionésimo]]", "[[décimo]] [[de]] [[milionésimo]]"}, nil, true)
make_number(100000000, "[[cem]] [[milhão|milhões]]", {"[[centésimo]] [[milionésimo]]", "[[centésimo]] [[de]] [[milionésimo]]"}, nil, true)
make_number(power_of(9), {"[[um]] [[bilhão]]<link:bilhão><tag:Brazil>", "[[mil]] [[milhão|milhões]]<tag:Portugal>"}, {"bilionésimo<tag:Brazil>", "[[milésimo]] [[milionésimo]]<tag:Portugal>", "[[milésimo]] [[de]] [[milionésimo]]<tag:Portugal>"},
	"1 000 000 000", true)
make_number(power_of(12), {"[[um]] [[trilhão]]<link:trilhão><tag:Brazil>", "[[um]] [[bilião]]<link:bilião><tag:Portugal>"}, {"trilionésimo<tag:Brazil>", "bilionésimo<tag:Portugal>"},
	"1 000 000 000 000", true)
make_number(power_of(15), {"[[um]] [[quatrilhão]]<link:quatrilhão><tag:Brazil>", "[[um]] [[quadrilhão]]<link:quadrilhão><tag:Brazil>", "[[mil]] [[bilião|biliões]]<tag:Portugal>"}, {"quatrilionésimo<tag:Brazil>", "quadrilionésimo<tag:Brazil>", "[[milésimo]] [[bilionésimo]]<tag:Portugal>", "[[milésimo]] [[de]] [[bilionésimo]]<tag:Portugal>"},
	"1000000000000000", true)
make_number(power_of(18), {"[[um]] [[quintilhão]]<link:quintilhão><tag:Brazil>", "[[um]] [[trilião]]<link:trilião><tag:Portugal>"}, {"quintilionésimo<tag:Brazil>", "trilionésimo<tag:Portugal>"},
	"1000000000000000000", true)
make_number(power_of(21), {"[[um]] [[sextilhão]]<link:sextilhão><tag:Brazil>", "[[mil]] [[trilião|triliões]]<tag:Portugal>"}, {"sextilionésimo<tag:Brazil>", "[[milésimo]] [[trilionésimo]]<tag:Portugal>", "[[milésimo]] [[de]] [[trilionésimo]]<tag:Portugal>"},
	nil, true)
make_number(power_of(24), {"[[um]] [[septilhão]]<link:septilhão><tag:Brazil>", "[[um]] [[quatrilião]]<link:quatrilião><tag:Portugal>", "[[um]] [[quadrilião]]<link:quadrilião><tag:Portugal>"}, {"septilionésimo<tag:Brazil>", "quatrilionésimo<tag:Portugal>", "quadrilionésimo<tag:Portugal>"},
	nil, true)
make_number(power_of(27), {"[[um]] [[octilhão]]<link:octilhão><tag:Brazil>", "[[mil]] [[quatrilião|quatriliões]]<tag:Portugal>", "[[mil]] [[quadrilião|quadriliões]]<tag:Portugal>"}, {"octilionésimo<tag:Brazil>", "[[milésimo]] [[quatrilionésimo]]<tag:Portugal>", "[[milésimo]] [[quadrilionésimo]]<tag:Portugal>", "[[milésimo]] [[de]] [[quatrilionésimo]]<tag:Portugal>", "[[milésimo]] [[de]] [[quadrilionésimo]]<tag:Portugal>"},
	nil, true)
make_number(power_of(30), {"[[um]] [[nonilhão]]<link:nonilhão><tag:Brazil>", "[[um]] [[quintilião]]<link:quintilião><tag:Portugal>"}, {"nonilionésimo<tag:Brazil>", "quintilionésimo<tag:Portugal>"},
	nil, true)

return export
