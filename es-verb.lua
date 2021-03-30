local export = {}


--[=[

Authorship: Ben Wing <benwing2>

]=]

--[=[

TERMINOLOGY:

-- "slot" = A particular combination of tense/mood/person/number/etc.
	 Example slot names for verbs are "pres_1s" (present first singular) and
	 "subc_subii_3p" (subordinate-clause subjunctive II third plural).
	 Each slot is filled with zero or more forms.

-- "form" = The conjugated German form representing the value of a given slot.

-- "lemma" = The dictionary form of a given German term. For German, always the infinitive.
]=]

--[=[

FIXME:

1. Implement no_pres3 for aterir, garantir.
2. Support concluyo.
--]=]

local lang = require("Module:languages").getByCode("es")
local m_string_utilities = require("Module:string utilities")
local m_links = require("Module:links")
local m_table = require("Module:table")
local iut = require("Module:inflection utilities")

local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsplit = mw.text.split

local function link_term(term, face)
	return m_links.full_link({ lang = lang, term = term }, face)
end


local vowel = "aeiouáéíóúý"
local V = "[" .. vowel .. "]"
local SV = "[áéíóúý]" -- stressed vowel
local W = "[iyuw]" -- glide
local C = "[^" .. vowel .. ".]"


local all_persons_numbers = {
	["1s"] = "1|s",
	["2s"] = "2|s",
	["2sv"] = "2|s|voseo",
	["3s"] = "3|s",
	["1p"] = "1|p",
	["2p"] = "2|p",
	["3p"] = "3|p",
	["me"] = "me",
	["te"] = "te",
	["se"] = "se",
	["nos"] = "nos",
	["os"] = "os",
	["lo"] = "lo",
	["la"] = "la",
	["le"] = "le",
	["los"] = "los",
	["las"] = "las",
	["les"] = "les",
}

local person_number_list_basic = { "1s", "2s", "3s", "1p", "2p", "3p", }
local person_number_list_voseo = { "1s", "2s", "2sv", "3s", "1p", "2p", "3p", }
-- local persnum_to_index = {}
-- for k, v in pairs(person_number_list) do
-- 	persnum_to_index[v] = k
-- end
local imp_person_number_list = { "2s", "2p", }

local verb_slots_basic = {
	{"infinitive", "inf"},
	{"infinitive_linked", "inf"},
	{"gerund", "ger"},
	{"pp_ms", "m|s|past|part"},
	{"pp_fs", "f|s|past|part"},
	{"pp_mp", "m|p|past|part"},
	{"pp_fp", "f|p|past|part"},
}

-- Add entries for a slot with person/number variants.
-- `verb_slots` is the table to add to.
-- `slot_prefix` is the prefix of the slot, typically specifying the tense/aspect.
-- `tag_suffix` is the set of inflection tags to add after the person/number tags,
-- or "-" to use "-" as the inflection tags (which indicates that no accelerator entry
-- should be generated).
local function add_slot_personal(verb_slots, slot_prefix, tag_suffix, person_number_list)
	for _, persnum in ipairs(person_number_list) do
		local persnum_tag = all_persons_numbers[persnum]
		local slot = slot_prefix .. "_" .. persnum
		if tag_suffix == "-" then
			table.insert(verb_slots, {slot, "-"})
		else
			table.insert(verb_slots, {slot, persnum_tag .. "|" .. tag_suffix})
		end
	end
end

add_slot_personal(verb_slots_basic, "pres", "pres|ind", person_number_list_voseo)
add_slot_personal(verb_slots_basic, "impf", "impf|ind", person_number_list_basic)
add_slot_personal(verb_slots_basic, "pret", "pret|ind", person_number_list_basic)
add_slot_personal(verb_slots_basic, "fut", "fut|ind", person_number_list_basic)
add_slot_personal(verb_slots_basic, "cond", "cond", person_number_list_basic)
add_slot_personal(verb_slots_basic, "pres_sub", "pres|sub", person_number_list_voseo)
add_slot_personal(verb_slots_basic, "impf_sub_ra", "impf|sub", person_number_list_basic)
add_slot_personal(verb_slots_basic, "impf_sub_se", "impf|sub", person_number_list_basic)
add_slot_personal(verb_slots_basic, "fut_sub", "fut|sub", person_number_list_basic)
add_slot_personal(verb_slots_basic, "imp", "imp", {"2s", "2sv", "3s", "1p", "2p", "3p"})
add_slot_personal(verb_slots_basic, "neg_imp", "-", {"2s", "3s", "1p", "2p", "3p"})

add_slot_personal(verb_slots_combined, "infinitive_comb", "inf|combined",
	{"me", "te", "se", "nos", "os", "lo", "la", "le", "los", "las", "les"})
add_slot_personal(verb_slots_combined, "gerund_comb", "gerund|combined",
	{"me", "te", "se", "nos", "os", "lo", "la", "le", "los", "las", "les"})
add_slot_personal(verb_slots_combined, "imp_2s_comb", "imp|2s|combined",
	{"me", "te", "nos", "lo", "la", "le", "los", "las", "les"})
add_slot_personal(verb_slots_combined, "imp_3s_comb", "imp|3s|combined",
	{"me", "se", "nos", "lo", "la", "le", "los", "las", "les"})
add_slot_personal(verb_slots_combined, "imp_1p_comb", "imp|1p|combined",
	{"te", "nos", "os", "lo", "la", "le", "los", "las", "les"})
add_slot_personal(verb_slots_combined, "imp_2p_comb", "imp|2p|combined",
	{"me", "nos", "os", "lo", "la", "le", "los", "las", "les"})
add_slot_personal(verb_slots_combined, "imp_3p_comb", "imp|3p|combined",
	{"me", "se", "nos", "lo", "la", "le", "los", "las", "les"})

local all_verb_slots = {}
for _, slot_and_accel in ipairs(verb_slots_basic) do
	table.insert(all_verb_slots, slot_and_accel)
end
for _, slot_and_accel in ipairs(verb_slots_combined) do
	table.insert(all_verb_slots, slot_and_accel)
end

local all_verb_slot_map = {}
for _, slot in ipairs(all_verb_slots) do
	all_verb_slot_map[slot[1]] = slot[2]
end


local irreg_conjugations = {
	{
		-- we don't want to match e.g. mandar.
		match = function(verb) return verb == "andar" and "" or verb == "desandar" and "des" end,
		forms = {pret = "anduv", pret_conj = "irreg"}
	},
	{
		match = "asir",
		forms = {pres1_and_sub = "asg"}
	},
	{
		match = "brir", -- abrir, cubrir and compounds
		forms = {pp = "biert"}
	},
	{
		match = "caber",
		forms = {pres1_and_sub = "quep", pret = "cup", fut = "cabr"}
	},
	{
		match = "caer",
		forms = {pres1_and_sub = "caig"}
	},
	{
		match = "^dar",
		forms = {pres_1s = "doy", pret = "d", pret_conj = "er", pres_sub_1s = "dé", pres_sub_3s = "dé"}
	},
	{
		match = "decir",
		forms = {pres1_and_sub = "dig", pres3 = "dic", pret = "dij", pret_conj = "irreg", pp = "dich", fut = "dir", imp_2s = "di"}
	},
	{
		match = "^desosar",
		forms = {pres3 = "deshues"}
	},
	{
		match = "ducir", -- conducir, producir, reducir, traducir, etc.
		forms = {pret = "duj", pret_conj = "irreg"}
	},
	{
		match = "^errar",
		forms = {pres3 = {
			{form = "yerr", footnotes = {"[Spain]"}},
			{form = "err", footnotes = {"[Latin America]"}}
		}}
	},
	{
		match = "^estar",
		forms = {
			pres_1s = "estoy",
			pres_2s = "estás",
			pres_2sv = "estás",
			pres_3s = "está",
			pres_3p = "están",
			pret = "estuv",
			pret_conj = "irreg",
			pres_sub_1s = "esté",
			pres_sub_2s = "estés",
			pres_sub_2sv = "estés",
			pres_sub_3s = "esté",
			pres_sub_3p = "estén",
			imp_2s = "está",
			imp_2sv = "está",
		}
	},
	{
		match = "^haber",
		forms = {
			pres_1s = "he",
			pres_2s = "has",
			pres_2sv = "has",
			pres_3s = {"ha", {form = "hay", footnotes = {"[used impersonally]"}}},
			pres_1p = "hemos",
			pres_3p = "han",
			pres1_and_sub = "hay", -- only for subjunctive as we override pres_1s
			pret = "hub",
			pret_conj = "irreg",
			imp_2s = {"habe", "he"},
			imp_2sv = {"habe", "he"},
		}
	},
	{
		match = "hacer",
		forms = {pres1_and_sub = "hag", pret = "hic", pret_conj = "irreg", pp = "hech", fut = "har", imp_2s = {"hace", "haz"}}
	},
	{
		match = "imprimir",
		forms = {pp = {"imprimid", "impres"}}
	},
	{
		match = "^ir",
		forms = {
			pres_1s = "voy",
			pres_2s = "vas",
			pres_2sv = "vas",
			pres_3s = "va",
			pres_1p = "vamos",
			pres_2p = "vais",
			pres_3p = "van",
			pres1_and_sub = "vay", -- only for subjunctive as we override pres_1s
			full_impf = "ib",
			impf_1p = "íbamos",
			pret = "fu",
			pret_3s = "fue",
			imp_2s = "ve",
			imp_2sv = "andá",
		}
	},
	{
		match = "manumitir",
		forms = {pp = {"manumitid", "manumis"}}
	},
	{
		match = "oír",
		forms = {pres1_and_sub = "oig"}
	},
	{
		match = "^oler",
		forms = {pres3 = "huel"}
	},
	{
		match = "olver", -- solver, volver, bolver and derivatives
		forms = {pres3 = "uelv", pp = "uelt"}
	},
	{
		match = "placer",
		forms = {
			pret_3s = {"plació", {form = "plugo", footnotes = {"[archaic]"}}},
			pret_3p = {"placieron", {form = "pluguieron", footnotes = {"[archaic]"}}},
			pres_sub_3s = {"plazca", {form = "plega", footnotes = {"[archaic]"}}, {form = "plegue", footnotes = {"[archaic]"}}},
			impf_sub_ra_3s = {"placiera", {form = "pluguiera", footnotes = {"[archaic]"}}},
			impf_sub_ra_3p = {"placieran", {form = "pluguieran", footnotes = {"[archaic]"}}},
			impf_sub_se_3s = {"placiese", {form = "pluguiese", footnotes = {"[archaic]"}}},
			impf_sub_se_3p = {"placiesen", {form = "pluguiesen", footnotes = {"[archaic]"}}},
			fut_sub_3s = {"placiere", {form = "pluguiere", footnotes = {"[archaic]"}}},
			fut_sub_3p = {"placieren", {form = "pluguieren", footnotes = {"[archaic]"}}},
		}
	},
	{
		match = "poder",
		forms = {pres3 = "pued", pret = "pud", pret_conj = "irreg", fut = "podr"}
	},
	{
		match = "poner",
		forms = {pres1_and_sub = "pong", pret = "pus", pret_conj = "irreg", fut = "pondr", imp_2s = "pon"}
	},
	{
		match = "pudrir",
		forms = {pp = "podrid"}
	},
	{
		match = "raer",
		forms = {
			pres1_and_sub = {"raig", "ray"}, -- only for subjunctive as we override pres_1s
			pres1_sg = {"ra", "raig", "ray"},
		}
	},
	{
		match = "rehuir",
		forms = {pres3 = "rehúy"}
	},
	{
		match = "roer",
		forms = {pres1_and_sub = {"ro", "roig", "roy"}}
	},
	{
		match = "romper",
		forms = {pp = "rot"}
	},
	{
		match = "querer",
		forms = {pres3 = "quier", pret = "quis", pret_conj = "irreg", fut = "querr"}
	},
	{
		match = "saber",
		forms = {
			pres_1s = "sé",
			pres1_and_sub = "sep", -- only for subjunctive as we override pres_1s
			pret = "sup",
			pret_conj = "irreg",
			fut = "sabr",
		}
	},
	{
		match = "salir",
		forms = {pres1_and_sub = "salg", fut = "saldr", imp_2s = "sal"}
	},
	{
		match = "scribir", -- escribir, describir, proscribir, etc.
		forms = {pp = {"scrit", {form = "script", footnotes = {"[Argentina and Uruguay]"}}}}
	},
	{
		match = "^ser",
		forms = {
			pres_1s = "soy",
			pres_2s = "eres",
			pres_2sv = "sos",
			pres_3s = "es",
			pres_1p = "somos",
			pres_2p = "sois",
			pres_3p = "son",
			pres1_and_sub = "se", -- only for subjunctive as we override pres_1s
			full_impf = "er",
			impf_1p = "éramos",
			pret = "fu",
			pret_3s = "fue",
			fut = "ser",
			imp_2s = "sé",
			imp_2sv = "sé",
		}
	},
	{
		match = "^soler",
		forms = {
			pres3 = "suel",
			fut = {{form = "soler", footnotes = {"[rare but acceptable]"}}},
			fut_sub = {{form = "sol", footnotes = {"[rare but acceptable]"}}},
		}
	},
	{
		match = "tener",
		forms = {pres1_and_sub = "teng", pres3 = "tien", pret = "tuv", pret_conj = "irreg", fut = "tendr", imp_2s = "ten"}
	},
	{
		match = "traer",
		forms = {pres1_and_sub = "traig", pret = "traj", pret_conj = "irreg"}
	},
	{
		match = "valer",
		forms = {pres1_and_sub = "valg", fut = "valdr", imp_2s = {"vale", "val"}}
	},
	{
		match = "venir",
		forms = {pres1_and_sub = "veng", pres3 = "vien", pret = "vin", pret_conj = "irreg", fut = "vendr", imp_2s = "ven"}
	},
	{
		-- We want to match antever etc. but not atrever etc. No way to avoid listing each verb.
		match = function(verb) return
			for _, prefix in ipairs({"ante", "entre", "pre", "re", ""}) do
				if verb == prefix .. "ver" then
					return prefix
				end
			end
			return nil
		end,
		forms = {pres1_and_sub = "ve", impf = "ve", pp = "vist"}
	},
}


local sein_forms = {
	["sein"] = {"mein", "dein", "sein", "unser", "euer", "ihr"},
	["seine"] = {"meine", "deine", "seine", "unsere", "eure", "ihre"},
	["seinen"] = {"meinen", "deinen", "seinen", "unseren", "euren", "ihren"},
	["seinem"] = {"meinem", "deinem", "seinem", "unserem", "eurem", "ihrem"},
	["seiner"] = {"meiner", "deiner", "seiner", "unserer", "eurer", "ihrer"},
	["seines"] = {"meines", "deines", "seines", "unseses", "eures", "ihres"},
}


local sich_forms = {
	["accpron"] = {"mich", "dich", "sich", "uns", "euch", "sich"},
	["datpron"] = {"mir", "dir", "sich", "uns", "euch", "sich"},
}


local function skip_slot(base, slot)
	if base.overrides[slot] then
		-- Skip any slots for which there are overrides.
		return true
	end

	if not slot:find("[123]") then
		-- Don't skip non-personal slots.
		return false
	end

	if base.nofinite then
		return true
	end

	if base.only3s and not slot:find("3s") or
		base.only3sp and not slot:find("3[sp]") then
		return true
	end

	return false
end


local function strip_spaces(text)
	return text:gsub("^%s*(.-)%s*", "%1")
end


local function escape_reflexive_indicators(arg1)
	if not arg1:find("pron>") then
		return arg1
	end
	local segments = iut.parse_balanced_segment_run(arg1, "<", ">")
	-- Loop over every other segment. The even-numbered segments are angle-bracket specs while
	-- the odd-numbered segments are the text between them.
	for i = 2, #segments - 1, 2 do
		if segments[i] == "<accpron>" then
			segments[i] = "⦃⦃accpron⦄⦄"
		elseif segments[i] == "<datpron>" then
			segments[i] = "⦃⦃datpron⦄⦄"
		elseif segments[i] == "<pron>" then
			segments[i] = "⦃⦃pron⦄⦄"
		end
	end
	return table.concat(segments)
end


local function undo_escape_form(form)
	-- assign to var to throw away second value
	local newform = form:gsub("⦃⦃", "<"):gsub("⦄⦄", ">")
	return newform
end


local function remove_reflexive_indicators(form)
	-- assign to var to throw away second value
	local newform = form:gsub("⦃⦃.-⦄⦄", "")
	return newform
end


local function replace_reflexive_indicators(slot, form)
	if not form:find("⦃") then
		return form
	end
	error("Internal error: replace_reflexive_indicators not implemented yet")
end


local function combine_stem_ending(slot, stem, frontback, ending)
	-- Lots of sound changes involving endings beginning with i + vowel
	if rfind(ending, "^i" .. V) then
		-- (1) need to raise e -> i, o -> u: dormir -> durmió, durmiera, durmiendo
		local raise_vowel = {["e"] = "i", ["o"] = "u"}
		stem = rsub(stem, "([eo])(" .. C .. "*)$", function(vowel, rest) return raise_vowel[vowel] .. rest end)

		-- (2) final -i of stem absorbed: sonreír -> sonrió, sonriera, sonriendo; note that this rule may be fed
		-- by the preceding one (stem sonre- raised to sonri-, then final i absorbed)
		stem = stem:gsub("i$", "")

		-- (3) initial i -> y after vowel: poseer -> poseyó, poseyera, poseyendo; concluir -> concluyó, concluyera, concluyendo
		if rfind(stem, V .. "$") then
			ending = ending:gsub("^i", "y")
		end

		-- (4) initial i absorbed after ñ, ll, y: tañer -> tañó, tañera, tañendo
		if rfind(stem, "[ñy]$") or rfind(stem, "ll$") then
			ending = ending:gsub("^i", "")
		end
	end

	-- If ending begins with (h)i, it must get an accent after a/e/i/o to prevent the two merging into a diphthong:
	-- caer -> caíste, caímos; reír -> reíste, reímos (pres and pret); re + hice -> rehíce. This does not apply
	-- after u, e.g. concluir -> concluiste, concluimos.
	if ending:find("^h?i") and stem:find("[aeio]$") then
		ending = ending:gsub("^(h?)i", "%1í")
	end

	-- Spelling changes in the stem; it depends on whether the stem given is the pre-front-vowel or
	-- pre-back-vowel variant, as indicated by `frontback`.
	local is_front = rfind(ending, "^[eiéí]")
	if frontback == "front" and not is_front then
		stem = stem:gsub("c$", "z") -- ejercer -> ejerzo, uncir -> unzo; parecer -> parezco handled by caller
		stem = stem:gsub("qu$", "c") -- delinquir -> delinco
		stem = stem:gsub("g$", "j") -- coger -> cojo, afligir -> aflijo
		stem = stem:gsub("gu$", "g") -- distinguir -> distingo
		stem = stem:gsub("gü$", "gu") -- may not occur; argüir -> arguyo handled by caller
	elseif frontback == "back" and is_front then
		stem = stem:gsub("gu$", "gü") -- averiguar -> averigüé
		stem = stem:gsub("g", "gu") -- cargar -> cargué
		stem = stem:gsub("c", "qu") -- marcar -> marqué
		stem = rsub(stem, "[çz]$", "c") -- aderezar/adereçar -> aderecé
	end

	return replace_reflexive_indicators(slot, stem .. ending)
end


local function add(base, slot, stems, frontback, endings, footnotes)
	if skip_slot(base, slot) then
		return
	end
	local function do_combine_stem_ending(stem, ending)
		return combine_stem_ending(slot, stem, frontback, ending)
	end
	iut.add_forms(base.forms, slot, stems, endings, do_combine_stem_ending, nil, nil, base.all_footnotes)
end


local function add_multi(base, slot, frontback, stems_and_endings, footnotes)
end


local function add3(base, slot, prefix, stems, frontback, endings, footnotes)
	if skip_slot(base, slot) then
		return
	end
	local first = true
	local function do_combine_stem_ending(stem, ending)
		-- We don't want front-back modifications to occur when combining the prefix with the stem,
		-- which occurs before combining the resulting prefix+stem with the ending, so we set it
		-- to "neither" the first time around. This is a bit of a hack but prevents unwelcome surprises
		-- that might otherwise happen.
		local frontback = first and "neither" or frontback
		first = false
		return combine_stem_ending(slot, stem, frontback, ending)
	end
	iut.add_multiple_forms(base.forms, slot, {prefix, stems, endings}, do_combine_stem_ending, nil, nil,
		base.all_footnotes)
end


local function add_single_stem_tense(base, slot_pref, stems, frontback, s1, s2, s3, p1, p2, p3)
	local function addit(slot, ending)
		add3(base, slot_pref .. "_" .. slot, base.prefix, stems, frontback, ending)
	end
	addit("1s", s1)
	addit("2s", s2)
	addit("3s", s3)
	addit("1p", p1)
	addit("2p", p2)
	addit("3p", p3)
end



local function add_present_indic(base, conj)
	local function addit(slot, stems, ending)
		add3(base, "pres_" .. slot, base.prefix, stems, base.frontback, ending)
	end
	local s2, s2v, s3, p1, p2, p3
	if conj == "ar" then
		s2, s2v, s3, p1, p2, p3 = "as", "ás", "a", "amos", "áis", "an"
	elseif conj == "er" then
		s2, s2v, s3, p1, p2, p3 = "es", "és", "e", "emos", "éis", "en"
	elseif conj == "ir" then
		s2, s2v, s3, p1, p2, p3 = "es", "ís", "e", "imos", "ís", "en"
	else
		error("Internal error: Unrecognized conjugation " .. conj)
	end

	addit("1s", base.stem.pres1, "o")
	addit("2s", base.stem.pres3, s2)
	addit("2sv", base.stem.pres, s2v)
	addit("3s", base.stem.pres3, s3)
	addit("1p", base.stem.pres, p1)
	addit("2p", base.stem.pres, p2)
	addit("3p", base.stem.pres3, p3)
end


local function add_present_subj(base, conj)
	local function addit(slot, stems, ending)
		add3(base, "pres_sub_" .. slot, base.prefix, stems, base.frontback, ending)
	end
	local s1, s2, s2v, s3, p1, p2, p3
	if conj == "ar" then
		s1, s2, s2v, s3, p1, p2, p3 = "e", "es", "és", "e", "emos", "éis", "en"
	else
		-- voseo and tu forms are identical
		s1, s2, s2v, s3, p1, p2, p3 = "a", "as", "as", "a", "amos", "áis", "an"
	end

	addit("pres_1s", base.stems.pres_sub1, s1)
	addit("pres_2s", base.stems.pres_sub1, s2)
	addit("pres_2sv", base.stems.pres_sub, s2v)
	addit("pres_3s", base.stems.pres_sub1, s3)
	addit("pres_1p", base.stems.pres_sub, p1)
	addit("pres_2p", base.stems.pres_sub, p2)
	addit("pres_3p", base.stems.pres_sub1, p3)
end


local function add_imper(base, conj)
	local function addit(slot, stems, ending)
		add3(base, "imp_" .. slot, base.prefix, stems, base.frontback, ending)
	end
	if conj == "ar" then
		addit("2s", base.stems.pres3, "a")
		addit("2sv", base.stems.pres, "á")
		addit("2p", base.stems.pres, "ad")
	elseif conj == "er" then
		addit("2s", base.stems.pres3, "e")
		addit("2sv", base.stems.pres, "é")
		addit("2p", base.stems.pres, "ed")
	elseif conj == "ir" then
		addit("2s", base.stems.pres3, "e")
		addit("2sv", base.stems.pres, "í")
		addit("2p", base.stems.pres, "id")
	else
		error("Internal error: Unrecognized conjugation " .. conj)
	end
end


local function add_non_present(base, conj)
	local function add_tense(slot, stem, s1, s2, s3, p1, p2, p3)
		add_single_stem_tense(base, slot, stem, base.frontback, s1, s2, s3, p1, p2, p3)
	end

	if base.stems.full_impf then
		-- An override needs to be supplied for the impf_1p due to the accent on the stem.
		add_tense("impf", base.stems.full_impf, "a", "as", "a", {}, "ais", "an")
	elseif conj == "ar" then
		add_tense("impf", base.stems.impf, "aba", "abas", "aba", "ábamos", "abais", "aban")
	else
		add_tense("impf", base.stems.impf, "ía", "ías", "ía", "íamos", "íais", "ían")
	end

	if base.stems.pret_conj == "irreg" then
		add_tense("pret", base.stems.pret, "e", "iste", "o", "imos", "isteis", "ieron")
	elseif (base.pret_conj or conj) == "ar" then
		add_tense("pret", base.stems.pret, "é", "aste", "ó", "amos", "asteis", "aron")
	else
		add_tense("pret", base.stems.pret, "í", "iste", "ió", "imos", "isteis", "ieron")
	end

	if (base.pret_conj or conj) == "ar" then
		add_tense("impf_sub_ra", base.stems.impf_sub_ra, "ara", "aras", "ara", "áramos", "arais", "aran")
		add_tense("impf_sub_se", base.stems.impf_sub_se, "ase", "ases", "ase", "ásemos", "aseis", "asen")
		add_tense("fut_sub", base.stems.fut_sub, "are", "ares", "are", "áremos", "areis", "aren")
	else
		add_tense("impf_sub_ra", base.stems.impf_sub_ra, "iera", "ieras", "iera", "iéramos", "ierais", "ieran")
		add_tense("impf_sub_se", base.stems.impf_sub_se, "iese", "ieses", "iese", "iésemos", "ieseis", "iesen")
		add_tense("fut_sub", base.stems.fut_sub, "iere", "ieres", "iere", "iéremos", "iereis", "ieren")
	end

	add_tense("fut", base.stems.fut, "é", "ás", "á", "emos", "éis", "án")
	add_tense("cond", base.stems.cond, "ía", "ías", "ía", "íamos", "íais", "ían")

	-- Do the participles.
	local function addit(slot, stems, ending)
		add3(base, slot, base.prefix, stems, base.frontback, ending)
	end
	addit("gerund", base.stems.pres, conj == "ar" and "ando" or "iendo")
	addit("pp_ms", base.stems.pp, "o")
	addit("pp_fs", base.stems.pp, "a")
	addit("pp_mp", base.stems.pp, "os")
	addit("pp_fp", base.stems.pp, "as")
end


local function construct_stems(base)
	local pres_stem, suffix = rmatch(base.infinitive, "^(.*)([aeií]r)$")
	if not pres_stem then
		error("Unrecognized infinitive: " .. base.infinitive)
	end
	base.conj = suffix == "ír" and "ir" or suffix
	base.frontback = suffix == "ar" and "back" or "front"
	local stems = {}
	base.stems = stems
	base.overrides = {}
	base.prefix = ""
	for _, irreg_conj in ipairs(irreg_conjugations) do
		if type(irreg_conj.match) == "function" then
			base.prefix = irreg_conj.match(base.infinitive)
		elseif irreg_conj.match:find("^%^") and rsub(irreg_conj.match, "^%^", "") == base.infinitive then
			-- begins with ^, for exact match, and matches
			base.prefix = ""
		else
			base.prefix = rmatch(base.infinitive, "^(.*)" .. irreg_conj.match .. "$")
		end
		if base.prefix then
			-- we found an irregular verb
			for stem, forms in pairs(base.forms) do
				if all_verb_slot_map[stem] then
					-- an individual form override
					base.overrides[stem] = forms
				elseif stem == "pres3" then
					if conj == "ar" then
						stems.pres3 

					stems[stem] = forms
				end
			end
			break
		end
	end

	stems.pres = stems.pres or pres_stem
	stems.pres3 = stems.pres3 or stems.pres
	stems.pres1 = stems.pres1 or stems.pres3
	stems.impf = stems.impf or stems.pres
	stems.pret = stems.pret or stems.pres
	stems.pret_conj = stems.pret_conj or base.conj
	stems.fut = stems.fut or stems.pres
	stems.cond = stems.cond or stems.fut
	stems.pres_sub1 = stems.pres_sub1 or stems.pres1_and_sub or stems.pres1
	stems.pres_sub = stems.pres_sub or stems.pres1_and_sub or stems.pres
	stems.impf_sub_ra = stems.impf_sub_ra or stems.pret
	stems.impf_sub_se = stems.impf_sub_se or stems.pret
	stems.fut_sub = stems.fut_sub or stems.pret
	stems.pp = stems.pp or base.conj == "ar" and
		combine_stem_ending("pp_ms", pres_stem, base.frontback, "ad") or
		-- use combine_stem_ending esp. so we get reído, caído, etc.
		combine_stem_ending("pp_ms", pres_stem, base.frontback, "id")
end


local function add_composed_forms(base)
	local forms = base.forms

	local function add_composed(tense_mood, index, persnum, auxforms, participle, suffix, footnotes)
		local pers_auxforms = iut.convert_to_general_list_form(auxforms[index])
		local linked_pers_auxforms = iut.map_forms(pers_auxforms, function(form) return "[[" .. form .. "]] " end)
		add4(base, tense_mood .. "_" .. persnum, linked_pers_auxforms, "[[" .. base.pre_pref, participle, "]]" .. suffix, footnotes)
	end

	local function add_composed_perf(tense_mood, index, persnum, haben_auxforms, sein_auxforms, haben_suffix, sein_suffix)
		for _, auxform in ipairs(base.aux) do
			if auxform.form == "haben" then
				add_composed(tense_mood, index, persnum, haben_auxforms, base.pp, haben_suffix, auxform.footnotes)
			end
			if auxform.form == "sein" then
				add_composed(tense_mood, index, persnum, sein_auxforms, base.pp, sein_suffix, auxform.footnotes)
			end
		end
	end

	local haben_forms = irreg_verbs["haben"]
	local sein_forms = irreg_verbs["sein"]
	local werden_forms = irreg_verbs["werden"]
	for index, persnum in ipairs(person_number_list) do
		add_composed_perf("perf_ind", index, persnum, haben_forms["pres"], sein_forms["pres"], "", "")
		add_composed_perf("perf_sub", index, persnum, haben_forms["subi"], sein_forms["subi"], "", "")
		add_composed_perf("plup_ind", index, persnum, haben_forms["pret"], sein_forms["pret"], "", "")
		add_composed_perf("plup_sub", index, persnum, haben_forms["subii"], sein_forms["subii"], "", "")
		for _, mood in ipairs({"ind", "subi", "subii"}) do
			local tense = mood == "ind" and "pres" or mood
			add_composed("futi_" .. mood, index, persnum, werden_forms[tense], base.bare_infinitive, "")
			add_composed_perf("futii_" .. mood, index, persnum, werden_forms[tense], werden_forms[tense], " [[haben]]", " [[sein]]")
		end
	end

	add3(base, "futi_inf", "[[" .. base.pre_pref, base.bare_infinitive, "]] [[werden]]")
	add5(base, "futii_inf", "[[" .. base.pre_pref, base.pp, "]] [[", base.aux, "]] [[werden]]")
end

local function process_slot_overrides(base)
	for slot, forms in ipairs(base.overrides) do
		add(base, slot, base.prefix, base.frontback, forms)
	end
end

local function handle_derived_slots(base)
	-- Compute linked versions of potential lemma slots, for use in {{de-verb}}.
	-- We substitute the original lemma (before removing links) for forms that
	-- are the same as the lemma, if the original lemma has links.
	for _, slot in ipairs({"infinitive"}) do
		iut.insert_forms(base.forms, slot .. "_linked", iut.map_forms(base.forms[slot], function(form)
			if form == base.lemma and rfind(base.linked_lemma, "%[%[") then
				return base.linked_lemma
			else
				return form
			end
		end))
	end
end


local function conjugate_verb(base)
	if not conjs[base.conj] then
		error("Internal error: Unrecognized conjugation type '" .. base.conj .. "'")
	end
	conjs[base.conj](base)
	add_composed_forms(base)
	process_slot_overrides(base)
	handle_derived_slots(base)
end


local function parse_indicator_spec(angle_bracket_spec)
	local base = {}
	local function parse_err(msg)
		error(msg .. ": " .. angle_bracket_spec)
	end
	local function fetch_footnotes(separated_group)
		local footnotes
		for j = 2, #separated_group - 1, 2 do
			if separated_group[j + 1] ~= "" then
				parse_err("Extraneous text after bracketed footnotes: '" .. table.concat(separated_group) .. "'")
			end
			if not footnotes then
				footnotes = {}
			end
			table.insert(footnotes, separated_group[j])
		end
		return footnotes
	end

	local function fetch_specs(comma_separated_group, transform_form)
		if not comma_separated_group then
			return {{}}
		end
		local specs = {}
		
		local colon_separated_groups = iut.split_alternating_runs(comma_separated_group, ":")
		for _, colon_separated_group in ipairs(colon_separated_groups) do
			local form = colon_separated_group[1]
			if transform_form then
				form = transform_form(form)
			end
			table.insert(specs, {form = form, footnotes = fetch_footnotes(colon_separated_group)})
		end
		return specs
	end

	local inside = angle_bracket_spec:match("^<(.*)>$")
	assert(inside)
	if inside == "" then
		return base
	end
	local segments = iut.parse_balanced_segment_run(inside, "[", "]")
	local dot_separated_groups = iut.split_alternating_runs(segments, "%.")
	for i, dot_separated_group in ipairs(dot_separated_groups) do
		local comma_separated_groups = iut.split_alternating_runs(dot_separated_group, "%s*[,#]%s*", "preserve splitchar")
		local first_element = comma_separated_groups[1][1]
		if first_element == "haben" or first_element == "sein" then
			for j = 1, #comma_separated_groups, 2 do
				if j > 1 and strip_spaces(comma_separated_groups[j - 1][1]) ~= "," then
					parse_err("Separator of # not allowed with haben or sein")
				end
				local aux = comma_separated_groups[j][1]
				if aux ~= "haben" and aux ~= "sein" then
					parse_err("Unrecognized auxiliary '" .. aux .. "'")
				end
				if base.aux then
					for _, existing_aux in ipairs(base.aux) do
						if existing_aux.form == aux then
							parse_err("Auxiliary '" .. aux .. "' specified twice")
						end
					end
				else
					base.aux = {}
				end
				table.insert(base.aux, {form = aux, footnotes = fetch_footnotes(comma_separated_groups[j])})
			end
		elseif first_element == "-ge" or first_element == "+ge" then
			for j = 1, #comma_separated_groups, 2 do
				if j > 1 and strip_spaces(comma_separated_groups[j - 1][1]) ~= "," then
					parse_err("Separator of # not allowed with +ge or -ge")
				end
				local prefix = comma_separated_groups[j][1]
				if prefix ~= "+ge" and prefix ~= "-ge" then
					parse_err("Unrecognized ge- prefix '" .. prefix .. "'")
				end
				local ge_prefix
				if prefix == "+ge" then
					ge_prefix = "ge"
				else
					ge_prefix = ""
				end
				if base.ge_prefix then
					for _, existing_prefix in ipairs(base.ge_prefix) do
						if existing_prefix.form == ge_prefix then
							parse_err("Ge- prefix '" .. prefix .. "' specified twice")
						end
					end
				else
					base.ge_prefix = {}
				end
				table.insert(base.ge_prefix, {form = ge_prefix, footnotes = fetch_footnotes(comma_separated_groups[j])})
			end
		elseif #comma_separated_groups > 1 then
			-- principal parts specified
			if base.past then
				parse_err("Can't specify principal parts twice")
			end
			local parts = {}
			assert(#comma_separated_groups[2] == 1)
			local past_index
			local first_separator = strip_spaces(comma_separated_groups[2][1])
			if first_separator == "#" then
				-- present 3rd singular specified
				base.pres_23 = fetch_specs(comma_separated_groups[1], function(form)
					local stem
					if base.conj == "pretpres" then
						stem = form
					else
						stem = form:match("^(.-)%-$")
						if not stem then
							stem = form:match("^(.-)e?t$")
						end
					end
					if stem then
						return stem
					else
						parse_err("Present 3sg form '" .. form .. "' should end in - (for the stem) or -t")
					end
				end)
				past_index = 3
			else
				past_index = 1
			end

			base.past = fetch_specs(comma_separated_groups[past_index], function(form)
				return form
			end)

			if #comma_separated_groups < past_index + 2 then
				parse_err("Missing past participle spec")
			end
			assert(#comma_separated_groups[past_index + 1] == 1)
			if strip_spaces(comma_separated_groups[past_index + 1][1]) ~= "," then
				parse_err("Only first separator can be a #")
			end
			base.pp = fetch_specs(comma_separated_groups[past_index + 2], function(form)
				if form:find("e[nd]$") or form:find("t$") then
					return form
				else
					parse_err("Past participle '" .. form .. "' should end in -en, -t, or -ed")
				end
			end)

			if #comma_separated_groups > past_index + 2 then
				assert(#comma_separated_groups[past_index + 3] == 1)
				if strip_spaces(comma_separated_groups[past_index + 3][1]) ~= "," then
					parse_err("Only first separator can be a #")
				end
				base.past_sub = fetch_specs(comma_separated_groups[past_index + 4], function(form)
					local stem = form:match("^(.-)e$")
					if not stem then
						parse_err("Past subjunctive '" .. form .. "' should end in -e")
					end
					return stem
				end)
				if #comma_separated_groups > past_index + 4 then
					parse_err("Too many specs given")
				end
			end
		elseif first_element == "pretpres" or first_element == "irreg" then
			if #comma_separated_groups[1] > 1 then
				parse_err("No footnotes allowed with '" .. first_element .. "' spec")
			end
			if base.conj then
				parse_err("Conjugation specified as '" .. first_element .. "' but already specified or autodetermined as '" .. base.conj .. "'")
			end
			base.conj = first_element
		elseif first_element == "einfix" or first_element == "-einfix" then
			if #comma_separated_groups[1] > 1 then
				parse_err("No footnotes allowed with '" .. first_element .. "' spec")
			end
			base.unstressed_e_infix = first_element == "einfix"
		elseif first_element == "shortimp" or first_element == "longimp" or
			first_element == "only3s" or first_element == "only3sp" or
			first_element == "nofinite" then
			if #comma_separated_groups[1] > 1 then
				parse_err("No footnotes allowed with '" .. first_element .. "' spec")
			end
			base[first_element] = true
		elseif first_element == "" or first_element == "inf" then
			local footnotes = fetch_footnotes(comma_separated_groups[1])
			if not footnotes then
				parse_err("Empty spec and 'inf' spec without footnotes not allowed")
			end
			if first_element == "inf" then
				base.infstem_footnotes = footnotes
			else
				base.all_footnotes = footnotes
			end
		else
			parse_err("Unrecognized spec '" .. comma_separated_groups[1][1] .. "'")
		end
	end

	return base
end


-- Normalize all lemmas, splitting off separable prefixes and substituting the pagename for blank lemmas.
local function normalize_all_lemmas(alternant_multiword_spec, from_headword)
	local any_pre_pref
	iut.map_word_specs(alternant_multiword_spec, function(base)
		if base.lemma == "" then
			local PAGENAME = mw.title.getCurrentTitle().text
			base.lemma = PAGENAME
		end
		if base.lemma:find("_") and not base.lemma:find("%[%[") then
			-- If lemma is multiword and has no links, add links automatically.
			base.lemma= "[[" .. base.lemma:gsub("_", "]]_[[") .. "]]"
		end
		base.orig_lemma = base.lemma
		base.orig_lemma_no_links = m_links.remove_links(base.lemma)
		-- Normalize the linked lemma by removing dot, underscore, and <pron> and such indicators.
		base.linked_lemma = remove_reflexive_indicators(base.lemma:gsub("%.", ""):gsub("_", " "))
		base.lemma = m_links.remove_links(base.linked_lemma)
		local lemma = base.orig_lemma_no_links
		base.pre_pref, base.post_pref = "", ""
		local prefix, verb = lemma:match("^(.*)_(.-)$")
		if prefix then
			prefix = prefix:gsub("_", " ") -- in case of multiple preceding words
			base.pre_pref = base.pre_pref .. prefix .. " "
			base.post_pref = base.post_pref .. " " .. prefix
		else
			verb = lemma
		end
		prefix, base.base_verb = verb:match("^(.*)%.(.-)$")
		if prefix then
			-- There may be multiple separable prefixes (e.g. [[wiedergutmachen]], ich mache wieder gut)
			base.pre_pref = base.pre_pref .. prefix:gsub("%.", "")
			base.post_pref = base.post_pref .. " " .. prefix:gsub("%.", " ")
		else
			base.base_verb = verb
		end
		if base.pre_pref ~= "" then
			any_pre_pref = true
		end
		if base.only3s then
			alternant_multiword_spec.only3s = true
		end
		if base.only3sp then
			alternant_multiword_spec.only3sp = true
		end
		-- Remove <pron> indicators and such.
		local reconstructed_lemma = remove_reflexive_indicators(base.pre_pref .. base.base_verb)
		if reconstructed_lemma ~= base.lemma then
			error("Internal error: Raw lemma '" .. base.lemma .. "' differs from reconstructed lemma '" .. reconstructed_lemma .. "'")
		end
		base.from_headword = from_headword
	end)
	if any_pre_pref then
		iut.map_word_specs(alternant_multiword_spec, function(base)
			base.any_pre_pref = true
		end)
	end
	if alternant_multiword_spec.only3s then
		iut.map_word_specs(alternant_multiword_spec, function(base)
			if not base.only3s then
				error("If some alternants specify 'only3s', all must")
			end
		end)
	end
	if alternant_multiword_spec.only3sp then
		iut.map_word_specs(alternant_multiword_spec, function(base)
			if not base.only3sp then
				error("If some alternants specify 'only3sp', all must")
			end
		end)
	end
end


local function detect_verb_type(base, verb_types)
	local this_verb_types = {}

	local function set_verb_type()
		base.verb_types = this_verb_types
	
		if verb_types then
			for _, verb_type in ipairs(this_verb_types) do
				m_table.insertIfNot(verb_types, verb_type)
			end
		end
	end

	if base.conj == "pretpres" then
		m_table.insertIfNot(this_verb_types, "pretpres")
		set_verb_type()
		return
	elseif base.conj == "irreg" then
		m_table.insertIfNot(this_verb_types, "irreg")
		set_verb_type()
		return
	end

	local infstem = m_table.deepcopy(base.infstem)
	local past = m_table.deepcopy(base.past)
	local pp = m_table.deepcopy(base.pp)

	local function matches_forms(forms, expected, ending_to_chop)
		expected = expected:gsub("C", not_vowel_c) .. "$"
		local seen = false
		for _, form in ipairs(forms) do
			local stem
			if ending_to_chop then
				stem = rmatch(form.form, "^(.*)" .. ending_to_chop .. "$")
			else
				stem = form.form
			end
			if stem and rfind("#" .. stem, expected) then
				seen = true
				form.seen = form.seen or "maybe"
			end
		end
		return seen
	end

	local function reset_maybes(forms, value)
		for _, form in ipairs(forms) do
			if form.seen == "maybe" then
				form.seen = value
			end
		end
	end

	local function reset_all_maybes(value)
		reset_maybes(infstem, value)
		reset_maybes(past, value)
		reset_maybes(pp, value)
	end

	local function has_unseen_weak_pp()
		for _, form in ipairs(pp) do
			if not form.seen and form.form:find("[dt]$") then
				return true
			end
		end
		return false
	end

	local function has_unseen_strong_pp()
		for _, form in ipairs(pp) do
			if not form.seen and form.form:find("n$") then
				return true
			end
		end
		return false
	end

	local function check(verbtype, infre, pastre, ppre, exclude)
		if exclude then
			for _, form in ipairs(infstem) do
				if exclude(form.form) then
					return
				end
			end
		end
		if matches_forms(infstem, infre) and
			matches_forms(past, pastre) and
			matches_forms(pp, ppre, "en") then
			m_table.insertIfNot(this_verb_types, verbtype)
			reset_all_maybes(true)
		else
			reset_all_maybes(false)
		end
	end

	local function check_strong()
		check("1", "Ce[iy]C*", "CieC*", "Cie?C*") -- beigen, bleiben, gedeihen, leihen, meiden, preisen, reiben, reihen,
			-- scheiden, scheinen, schreiben, schreien, schweigen, speiben, speien, speisen, steigen, treiben, weisen,
			-- zeihen; use 'Cie?C*' for past participle to handle 'schrien', 'spien'
		check("1", "Ce[iy]C*", "CiC*", "CiC*") -- beißen/beissen/beyßen/beyssen, bleichen, fleißen/fleissen, gleichen,
			-- gleiten, greifen, kneifen, kreischen, leiden, pfeifen, reißen/reissen, reiten, scheißen/scheissen,
			-- schleichen, schleifen, schleißen/schleissen, schmeißen/schmeissen, schneiden/schneyden, schreiten,
			-- spleißen/spleissen, streichen, streiten, weichen
		check("2", "CieC*", "CoC*", "CoC*") -- biegen, bieten, fliegen, fliehen, fließen/fliessen, frieren,
			-- genießen/geniessen, gießen/giessen, kiesen, kriechen, riechen, schieben, schießen/schiessen, schliefen,
			-- schließen/schliessen, sieden, sprießen/spriessen, stieben, triefen, verdrießen/verdriessen, verlieren,
			-- wiegen, ziehen
		check("2", "CauC*", "CoC*", "CoC*") -- krauchen, saufen, saugen
		check("2", "CüC", "CoC", "CoC") -- lügen, trügen
		local function exclude_nehmen_sprechen(form)
			-- need to exclude nehmen, stehlen, befehlen/empfehlen, sprechen, brechen, stechen
			return rfind(form, vowel_c .. "ch$") or rfind(form, vowel_c .. "h" .. not_vowel_c .. "$")
		end
		check("3", "C[ei]CC+", "CaCC+", "C[ou]CC+", exclude_nehmen_sprechen) -- [with e, + o in pp]: bergen, bersten,
			-- gelten, helfen, schelten, sterben, verderben, werben, werfen; [with i, + u in pp]: binden, brinnen, dringen,
			-- finden, gelingen, klingen, misslingen, ringen, schlingen, schwinden, schwingen, singen, sinken, springen,
			-- stinken, trinken, winden, wringen, zwingen; [with i, + o in pp]: rinnen, gewinnen, schwimmen, sinnen,
			-- spinnen
		check("3", "C[eiaö]CC+", "CoCC+", "CoCC+", exclude_nehmen_sprechen)
			-- [with e]: dreschen, fechten, flechten, melken, quellen, schmelzen, schwellen; [with i]: glimmen, klimmen;
			-- [with a]: schallen (geschallt), erschallen; [with ö]: erlöschen
		check("3", "quell", "quoll", "quoll") -- need to special-case quellen due to u preceding e
		check("3", "schind", "schund", "schund") -- need to special-case due to 'u' in past
		check("4", "C[eäo]C*", "Cah?Ch?", "CoC*") -- [with e]: befehlen, brechen, schrecken, nehmen, sprechen, stechen,
			-- stecken (gesteckt), stehlen, treffen; [with ä]: gebären; [with o]: kommen
		check("4", "C[äe]C", "Coh?C", "Coh?C", function(form) return form:find("heb$") end)
			-- [with ä]: gären, wägen, schwären; [with e]: bewegen, weben, scheren (but not heben)
		check("5", "C[ei]C*", "CaC", "CeC*") -- [with e, one C]: geben, genesen, geschehen, lesen, meßen, sehen, treten;
			-- [with e, two C]: essen, fressen, messen, vergessen; [with i, two C]: bitten, sitzen
		check("5", "C[ei]C*", "Cass", "Cess") -- essen, fressen, messen, sitzen in Swiss spelling
		check("5", "CieC", "CaC", "CeC") -- liegen
		check("6", "CaC*", "CuC*", "CaC*") -- backen, fragen (gefragt), graben, laden, mahlen, schaffen, schlagen,
			-- tragen, wachsen, waschen
		check("6", "heb", "h[ou]b", "hob") -- we need to special-case this because heben (class 6 per Wikipedia) has the
			-- exact same vowels as weben (class 4 per Wikipedia)
		check("6", "schwör", "schw[ou]r", "schwor") -- only strong verb with these vowels
		check("7", "CaC*", "CieC*", "CaC*") -- blasen, braten, fallen, halten, lassen, raten/rathen, schlafen
		check("7", "C[aäe]C*", "CiC*", "CaC*") -- [with a]: fangen; [with ä]: hängen; [with e]: gehen
		check("7", "Ce[iy]C*", "CieC*", "Ce[iy]C*") -- heißen/heissen/heyßen/heyssen
		check("7", "CauC*", "CieC*", "CauC*") -- hauen, laufen
		check("7", "CoC*", "CieC*", "CoC*") -- stoßen/stossen
		check("7", "CuC*", "CieC*", "CuC*") -- rufen
	end

	for _, form in ipairs(past) do
		local past_stem = form.form:match("^(.*)te$")
		if past_stem then
			if matches_forms(infstem, "#" .. past_stem) then
				-- Need to run matches_forms() on all possibilities even if earlier ones match,
				-- to mark the seen forms correctly.
				local matches_pp = matches_forms(pp, "#" .. past_stem .. "t")
				matches_pp = matches_forms(pp, "#ge" .. past_stem .. "t") or matches_pp
				if matches_pp then
					m_table.insertIfNot(this_verb_types, "weak")
					form.seen = true
					reset_all_maybes(true)
				else
					reset_all_maybes(false)
				end
			end
		end
		if not form.seen and form.form:find("ete$") then
			if matches_forms(infstem, "#" .. past_stem:gsub("e$", "")) then
				-- Need to run matches_forms() on all possibilities even if earlier ones match,
				-- to mark the seen forms correctly.
				local matches_pp = matches_forms(pp, "#" .. past_stem .. "t")
				matches_pp = matches_forms(pp, "#ge" .. past_stem .. "t") or matches_pp
				matches_pp = matches_forms(pp, "#" .. past_stem .. "d") or matches_pp
				matches_pp = matches_forms(pp, "#ge" .. past_stem .. "d") or matches_pp
				if matches_pp then
					m_table.insertIfNot(this_verb_types, "weak")
					form.seen = true
					reset_all_maybes(true)
				else
					reset_all_maybes(false)
				end
			end
		end
		if past_stem and not form.seen then
			if not has_unseen_weak_pp() and has_unseen_strong_pp() then
				m_table.insertIfNot(this_verb_types, "mixed")
			else
				m_table.insertIfNot(this_verb_types, "irregweak")
			end
			matches_forms(pp, "#" .. past_stem .. "t")
			matches_forms(pp, "#ge" .. past_stem .. "t")
			form.seen = true
			reset_all_maybes(true)
		end
		if not form.seen then
			check_strong()
		end
		if not form.seen then
			if not has_unseen_strong_pp() and has_unseen_weak_pp() then
				m_table.insertIfNot(this_verb_types, "mixed")
			else
				m_table.insertIfNot(this_verb_types, "irregstrong")
			end
		end
	end

	for _, form in ipairs(pp) do
		if not form.seen then
			if form.form:find("n$") then
				if m_table.contains(this_verb_types, "strong") then
					m_table.insertIfNot(this_verb_types, "irregstrong")
				elseif m_table.contains(this_verb_types, "weak") then
					m_table.insertIfNot(this_verb_types, "mixed")
				end
			elseif form.form:find("[dt]$") then
				if m_table.contains(this_verb_types, "weak") then
					m_table.insertIfNot(this_verb_types, "irregweak")
				elseif m_table.contains(this_verb_types, "strong") then
					m_table.insertIfNot(this_verb_types, "mixed")
				end
			end
		end
	end

	base.verb_types = this_verb_types

	if verb_types then
		for _, verb_type in ipairs(this_verb_types) do
			m_table.insertIfNot(verb_types, verb_type)
		end
	end

	set_verb_type()
end


local function detect_indicator_spec(base)
	base.forms = {}
	base.aux = base.aux or {{form = "haben"}}
	base.bare_infinitive = {{form = base.base_verb, footnotes = base.infstem_footnotes}}
	add(base, "infinitive", base.pre_pref, base.bare_infinitive)

	if base.only3s and base.only3sp then
		error("'only3s' and 'only3sp' cannot both be specified")
	end

	if base.conj == "irreg" then
		for irregverb, verbobj in pairs(irreg_verbs) do
			base.insep_prefix = base.base_verb:match("^(.-)" .. irregverb .. "$")
			if base.insep_prefix then
				base.irregverb = irregverb
				base.irregverbobj = verbobj
				if not base.ge_prefix then
					if base.insep_prefix ~= "" then
						base.ge_prefix = {{form = ""}}
					else
						base.ge_prefix = {{form = "ge"}}
					end
				end
				return
			end
		end
		error("Unrecognized irregular base verb '" .. base.base_verb .. "'")
	end

	-- The following applies to everything but 'irreg' verbs.

	local infstem, infroot = base.base_verb:match("^((.*)e[lr])n$")
	if infstem then
		base.unstressed_el_er = true
	else
		infstem, infroot = base.base_verb:match("^((.*)erl)n$") -- [[fensterln]]
		if infstem then
			base.unstressed_erl = true
		else
			infstem = base.base_verb:match("^(.*)en$")
			infroot = infstem
			if not infstem then
				error("Unrecognized infinitive, should end in -en, -eln, -ern or -erln: '" .. base.base_verb .. "'")
			end
		end
	end
	base.infstem = {{form = infstem, footnotes = base.infstem_footnotes}}

	if base.unstressed_e_infix == nil then
		-- Autodetect whether we need an -e- infix in the pres_2s and pres_3s ([[atmen]], [[eignen]], etc.).
		-- Almost all such cases have -Cmen or -Cnen where C is a consonant other than r or l and other than the
		-- following m or n (hence [[meinen]], [[lernen]], [[filmen]], [[schwimmen]] should be excluded); we also
		-- need to exclue -Vhmen and -Vhnen ([[wohnen]], [[rühmen]]), but not -Chmen and -Chnen ([[zeichnen]]).
		if base.base_verb:find("[mn]en$") and not base.base_verb:find("([mn])%1en$") and
			not rfind(base.base_verb, vowel_c .. "[hrl]?[mn]en$") then
			base.unstressed_e_infix = true
		end
	end

	if not base.conj then
		base.conj = "normal"
	end
	if base.conj == "normal" then
		local weak_past
		if not base.past then
			if base.unstressed_e_infix or ends_in_dt(infstem) then
				weak_past = infstem .. "et"
			else
				weak_past = infstem .. "t"
			end
			base.past = {{form = weak_past .. "e"}}
		end
		if not base.pp then
			if not weak_past then
				error("Internal error: past was explicitly given but not past participle")
			end
			if not base.ge_prefix then
				local no_ge
				for _, insep_prefix in ipairs(inseparable_prefixes) do
					-- There must be a vowel following the inseparable prefix; excludes beben, bechern, belfern, bellen, bessern,
					-- beten, betteln, betten, erben, erden, ernten, erzen, entern, gecken, gehren, gellen, gerben, geten, missen,
					-- zergen, zerren, etc.
					if rfind(infroot, "^" .. insep_prefix .. ".*" .. vowel_c .. ".*") and
						-- Exclude cases like beigen, beichten, beugen, beulen, geifern; this also wrongly excludes
						-- beirren, which needs -ge.
						not rfind(infroot, "^[bg]e[iu]" .. not_vowel_c .. "*$") then
						no_ge = true
						break
					end
					-- Check for -ier preceded by a vowel (excludes bieren, frieren, gieren, schmieren, stieren, zieren, etc.)
					if not base.unstressed_el_er and not base.unstressed_erl and rfind(infroot, "^.*" .. vowel_c .. ".*ier$") then
						no_ge = true
						break
					end
				end
				if no_ge then
					base.ge_prefix = {{form = ""}}
				else
					base.ge_prefix = {{form = "ge"}}
				end
			end
			base.pp = iut.map_forms(base.ge_prefix, function(form)
				if base.unstressed_el_er or base.unstressed_erl then
					return form .. base.base_verb:gsub("n$", "") .. "t"
				else
					return form .. weak_past
				end
			end)
		end
	else
		if not base.pp then
			error("For '" .. base.conj .. "' type verbs, past participle must be explicitly given")
		end
	end

	add(base, "perf_part", base.pre_pref, base.pp)
end


local function detect_all_indicator_specs(alternant_multiword_spec)
	iut.map_word_specs(alternant_multiword_spec, function(base)
		detect_indicator_spec(base)
		detect_verb_type(base)
	end)
end


-- Set the overall auxiliary or auxiliaries. We can't do this using the normal inflection
-- code as it will produce e.g. '[[haben]] und [[haben]]' for conjoined verbs.
local function compute_auxiliary(alternant_multiword_spec)
	iut.map_word_specs(alternant_multiword_spec, function(base)
		iut.insert_forms(alternant_multiword_spec.forms, "aux", base.aux)
	end)
end


function export.process_verb_classes(classes)
	local class_descs = {}
	local cats = {}

	local function insert_desc(desc)
		m_table.insertIfNot(class_descs, desc)
	end

	local function insert_cat(cat)
		m_table.insertIfNot(cats, "German " .. cat)
	end

	for _, class in ipairs(classes) do
		if class == "weak" then
			insert_desc("[[Appendix:Glossary#weak verb|weak]]")
			insert_cat("weak verbs")
		elseif class == "irregweak" then
			insert_desc("[[Appendix:Glossary#irregular|irregular]] [[Appendix:Glossary#weak verb|weak]]")
			insert_cat("weak verbs")
			insert_cat("irregular weak verbs")
		elseif class == "pretpres" then
			insert_desc("[[Appendix:Glossary#preterite-present verb|preterite-present]]")
			insert_cat("preterite-present verbs")
		elseif class == "irreg" then
			insert_desc("[[Appendix:Glossary#irregular|irregular]]")
			insert_cat("irregular verbs")
		elseif class == "mixed" then
			insert_desc("mixed")
			insert_cat("mixed verbs")
		elseif class == "irregstrong" then
			insert_desc("[[Appendix:Glossary#irregular|irregular]] [[Appendix:Glossary#strong verb|strong]]")
			insert_cat("strong verbs")
			insert_cat("irregular strong verbs")
		elseif class:find("^[1-7]$") then
			insert_desc("class " .. class .. " [[Appendix:Glossary#strong verb|strong]]")
			insert_cat("strong verbs")
			insert_cat("class " .. class .. " strong verbs")
		else
			error("Unrecognized verb class '" .. class .. "'")
		end
	end

	return class_descs, cats
end


local function add_categories_and_annotation(alternant_multiword_spec, base, from_headword, manual)
	local function insert_cat(full_cat)
		m_table.insertIfNot(alternant_multiword_spec.categories, full_cat)
	end

	if not from_headword then
		for _, slot_and_accel in ipairs(all_verb_slots) do
			local slot = slot_and_accel[1]
			local forms = base.forms[slot]
			local must_break = false
			if forms then
				for _, form in ipairs(forms) do
					if not form.form:find("%[%[") then
						local title = mw.title.new(form.form)
						if title and not title.exists then
							insert_cat("German verbs with red links in their inflection tables")
							must_break = true
							break
						end
					end
				end
			end
			if must_break then
				break
			end
		end
	end

	if manual then
		return
	end

	local class_descs, cats = export.process_verb_classes(base.verb_types)
	for _, desc in ipairs(class_descs) do
		m_table.insertIfNot(alternant_multiword_spec.verb_types, desc)
	end
	-- Don't place multiword terms in categories like 'German class 4 strong verbs' to avoid spamming the
	-- categories with such terms.
	if from_headword and not base.lemma:find(" ") then
		for _, cat in ipairs(cats) do
			insert_cat(cat)
		end
	end

	for _, aux in ipairs(base.aux) do
		m_table.insertIfNot(alternant_multiword_spec.auxiliaries, link_term(aux.form, "term"))
		if from_headword and not base.lemma:find(" ") then -- see above
			insert_cat("German verbs using " .. aux.form .. " as auxiliary")
			-- Set flags for use below in adding 'German verbs using haben and sein as auxiliary'
			alternant_multiword_spec["saw_" .. aux.form] = true
		end
	end
end


-- Compute the categories to add the verb to, as well as the annotation to display in the
-- conjugation title bar. We combine the code to do these functions as both categories and
-- title bar contain similar information.
local function compute_categories_and_annotation(alternant_multiword_spec, from_headword, manual)
	alternant_multiword_spec.categories = {}
	alternant_multiword_spec.verb_types = {}
	alternant_multiword_spec.auxiliaries = {}
	iut.map_word_specs(alternant_multiword_spec, function(base)
		add_categories_and_annotation(alternant_multiword_spec, base, from_headword)
	end)
	if manual then
		alternant_multiword_spec.annotation = ""
		return
	end
	local ann_parts = {}
	table.insert(ann_parts, table.concat(alternant_multiword_spec.verb_types, " or "))
	if #alternant_multiword_spec.auxiliaries > 0 then
		table.insert(ann_parts, ", auxiliary " .. table.concat(alternant_multiword_spec.auxiliaries, " or "))
	end
	if from_headword and alternant_multiword_spec.saw_haben and alternant_multiword_spec.saw_sein then
		m_table.insertIfNot(alternant_multiword_spec.categories, "German verbs using haben and sein as auxiliary")
	end
	alternant_multiword_spec.annotation = table.concat(ann_parts)
end


local function show_forms(alternant_multiword_spec)
	local lemmas = iut.map_forms(alternant_multiword_spec.forms.infinitive,
		remove_reflexive_indicators)
	alternant_multiword_spec.lemmas = lemmas -- save for later use in make_table()
	local linked_pronouns = {}
	for index, pronoun in ipairs(pronouns) do
		-- use 'es' instead of 'er' for 3s-only verbs
		if index == 3 and alternant_multiword_spec.only3s then
			linked_pronouns[index] = link_term("es")
		else
			linked_pronouns[index] = link_term(pronoun)
		end
	end
	dass = link_term("dass") .. " "
	local function add_pronouns(slot, link)
		local persnum = slot:match("^imp_(2[sp])$")
		if persnum then
			link = link .. " (" .. linked_pronouns[persnum_to_index[persnum]] .. ")"
		else
			persnum = slot:match("^.*_([123][sp])$")
			if persnum then
				link = linked_pronouns[persnum_to_index[persnum]] .. " " .. link
			end
			if slot:find("^subc_") then
				link = dass .. link
			end
		end
		return link
	end
	local function join_spans(slot, spans)
		if slot == "aux" then
			return table.concat(spans, " or ")
		else
			return table.concat(spans, "<br />")
		end
	end
	local props = {
		lang = lang,
		lemmas = lemmas,
		transform_link = add_pronouns,
		join_spans = join_spans,
	}
	props.slot_list = verb_slots_basic
	iut.show_forms(alternant_multiword_spec.forms, props)
	alternant_multiword_spec.footnote_basic = alternant_multiword_spec.forms.footnote
	props.slot_list = verb_slots_subordinate_clause
	iut.show_forms(alternant_multiword_spec.forms, props)
	alternant_multiword_spec.footnote_subordinate_clause = alternant_multiword_spec.forms.footnote
	props.slot_list = verb_slots_composed
	iut.show_forms(alternant_multiword_spec.forms, props)
	alternant_multiword_spec.footnote_composed = alternant_multiword_spec.forms.footnote
end


local notes_template = [=[
<div style="width:100%;text-align:left;background:#d9ebff">
<div style="display:inline-block;text-align:left;padding-left:1em;padding-right:1em">
{footnote}
</div></div>
]=]

local zu_infinitive_table = [=[
|-
! colspan="2" style="background:#d0d0d0" | zu-infinitive
| colspan="4" | {zu_infinitive}
]=]

local basic_table = [=[
<div class="NavFrame" style="">
<div class="NavHead" style="">Conjugation of {title}</div>
<div class="NavContent">
{\op}| border="1px solid #000000" style="border-collapse:collapse; background:#fafafa; text-align:center; width:100%" class="inflection-table"
|-
! colspan="2" style="background:#d0d0d0" | <span title="Infinitiv">infinitive</span>
| colspan="4" | {infinitive}
|-
! colspan="2" style="background:#d0d0d0" | <span title="Partizip I (Partizip Präsens)">present participle</span>
| colspan="4" | {pres_part}
|-
! colspan="2" style="background:#d0d0d0" | <span title="Partizip II (Partizip Perfekt)">past participle</span>
| colspan="4" | {perf_part}
{zu_infinitive_table}|-
! colspan="2" style="background:#d0d0d0" | <span title="Hilfsverb">auxiliary</span>
| colspan="4" | {aux}
|-
| style="background:#a0ade3" |
! colspan="2" style="background:#a0ade3" | <span title="Indikativ">indicative</span>
| style="background:#a0ade3" |
! colspan="2" style="background:#a0ade3" | <span title="Konjunktiv">subjunctive</span>
|-
! rowspan="3" style="background:#c0cfe4; width:7em" | <span title="Präsens">present</span>
| {pres_1s}
| {pres_1p}
! rowspan="3" style="background:#c0cfe4; width:7em" | <span title="Konjunktiv I (Konjunktiv Präsens)">i</span>
| {subi_1s}
| {subi_1p}
|-
| {pres_2s}
| {pres_2p}
| {subi_2s}
| {subi_2p}
|-
| {pres_3s}
| {pres_3p}
| {subi_3s}
| {subi_3p}
|-
| colspan="6" style="background:#d5d5d5; height: .25em" | 
|-
! rowspan="3" style="background:#c0cfe4" | <span title="Präteritum">preterite</span>
| {pret_1s}
| {pret_1p}
! rowspan="3" style="background:#c0cfe4" | <span title="Konjunktiv II (Konjunktiv Präteritum)">ii</span>
| {subii_1s}
| {subii_1p}
|-
| {pret_2s}
| {pret_2p}
| {subii_2s}
| {subii_2p}
|-
| {pret_3s}
| {pret_3p}
| {subii_3s}
| {subii_3p}
|-
| colspan="6" style="background:#d5d5d5; height: .25em" | 
|-
! style="background:#c0cfe4" | <span title="Imperativ">imperative</span>
| {imp_2s}
| {imp_2p}
| colspan="3" style="background:#e0e0e0" |
|{\cl}{notes_clause}</div></div>
]=]

local subordinate_clause_table = [=[
<div class="NavFrame" style="">
<div class="NavHead" style="">Subordinate-clause forms of {title}</div>
<div class="NavContent">
{\op}| border="1px solid #000000" style="border-collapse:collapse; background:#fafafa; text-align:center; width:100%" class="inflection-table"
|-
| style="background:#a0ade3" |
! colspan="2" style="background:#a0ade3" | <span title="Indikativ">indicative</span>
| style="background:#a0ade3" |
! colspan="2" style="background:#a0ade3" | <span title="Konjunktiv">subjunctive</span>
|-
! rowspan="3" style="background:#c0cfe4; width:7em" | <span title="Präsens">present</span>
| {subc_pres_1s}
| {subc_pres_1p}
! rowspan="3" style="background:#c0cfe4; width:7em" | <span title="Konjunktiv I (Konjunktiv Präsens)">i</span> 
| {subc_subi_1s}
| {subc_subi_1p}
|-
| {subc_pres_2s}
| {subc_pres_2p}
| {subc_subi_2s}
| {subc_subi_2p}
|-
| {subc_pres_3s}
| {subc_pres_3p}
| {subc_subi_3s}
| {subc_subi_3p}
|-
| colspan="6" style="background:#d5d5d5; height: .25em" | 
|-
! rowspan="3" style="background:#c0cfe4" | <span title="Präteritum">preterite</span>
| {subc_pret_1s}
| {subc_pret_1p}
! rowspan="3" style="background:#c0cfe4" | <span title="Konjunktiv II (Konjunktiv Präteritum)">ii</span>
| {subc_subii_1s}
| {subc_subii_1p}
|-
| {subc_pret_2s}
| {subc_pret_2p}
| {subc_subii_2s}
| {subc_subii_2p}
|-
| {subc_pret_3s}
| {subc_pret_3p}
| {subc_subii_3s}
| {subc_subii_3p}
|{\cl}{notes_clause}</div></div>
]=]

local composed_table = [=[
<div class="NavFrame" style="">
<div class="NavHead" style="">Composed forms of {title}</div>
<div class="NavContent">
{\op}| border="1px solid #000000" style="border-collapse:collapse; background:#fafafa; text-align:center; width:100%" class="inflection-table"
|-
! colspan="6" style="background:#99cc99" | <span title="Perfekt">perfect</span>
|-
! rowspan="3" style="background:#cfedcc; width:7em" | <span title="Indikativ">indicative</span>
| {perf_ind_1s}
| {perf_ind_1p}
! rowspan="3" style="background:#cfedcc; width:7em" | <span title="Konjunktiv">subjunctive</span>
| {perf_sub_1s}
| {perf_sub_1p}
|-
| {perf_ind_2s}
| {perf_ind_2p}
| {perf_sub_2s}
| {perf_sub_2p}
|-
| {perf_ind_3s}
| {perf_ind_3p}
| {perf_sub_3s}
| {perf_sub_3p}
|-
! colspan="6" style="background:#99CC99" | <span title="Plusquamperfekt">pluperfect</span>
|-
! rowspan="3" style="background:#cfedcc" | <span title="Indikativ">indicative</span>
| {plup_ind_1s}
| {plup_ind_1p}
! rowspan="3" style="background:#cfedcc" | <span title="Konjunktiv">subjunctive</span>
| {plup_sub_1s}
| {plup_sub_1p}
|-
| {plup_ind_2s}
| {plup_ind_2p}
| {plup_sub_2s}
| {plup_sub_2p}
|-
| {plup_ind_3s}
| {plup_ind_3p}
| {plup_sub_3s}
| {plup_sub_3p}
|-
! colspan="6" style="background:#9999DF" | <span title="Futur I">future i</span>
|-
! rowspan="3" style="background:#ccccff" | <span title="Infinitiv">infinitive</span>
| rowspan="3" colspan="2" | {futi_inf}
! rowspan="3" style="background:#ccccff" | <span title="Konjunktiv I (Konjunktiv Präsens)">subjunctive i</span>
| {futi_subi_1s}
| {futi_subi_1p}
|-
| {futi_subi_2s}
| {futi_subi_2p}
|-
| {futi_subi_3s}
| {futi_subi_3p}
|-
! colspan="6" style="background:#d5d5d5; height: .25em" |
|-
! rowspan="3" style="background:#ccccff" | <span title="Indikativ">indicative</span>
| {futi_ind_1s}
| {futi_ind_1p}
! rowspan="3" style="background:#ccccff" | <span title="Konjunktiv II (Konjunktiv Präteritum)">subjunctive ii</span>
| {futi_subii_1s}
| {futi_subii_1p}
|-
| {futi_ind_2s}
| {futi_ind_2p}
| {futi_subii_2s}
| {futi_subii_2p}
|-
| {futi_ind_3s}
| {futi_ind_3p}
| {futi_subii_3s}
| {futi_subii_3p}
|-
! colspan="6" style="background:#9999DF" | <span title="Futur II">future ii</span>
|-
! rowspan="3" style="background:#ccccff" | <span title="Infinitiv">infinitive</span>
| rowspan="3" colspan="2" | {futii_inf}
! rowspan="3" style="background:#ccccff" | <span title="Konjunktiv I (Konjunktiv Präsens)">subjunctive i</span>
| {futii_subi_1s}
| {futii_subi_1p}
|-
| {futii_subi_2s}
| {futii_subi_2p}
|-
| {futii_subi_3s}
| {futii_subi_3p}
|-
! colspan="6" style="background:#d5d5d5; height: .25em" |
|-
! rowspan="3" style="background:#ccccff" | <span title="Indikativ">indicative</span>
| {futii_ind_1s}
| {futii_ind_1p}
! rowspan="3" style="background:#ccccff" | <span title="Konjunktiv II (Konjunktiv Präteritum)">subjunctive ii</span>
| {futii_subii_1s}
| {futii_subii_1p}
|-
| {futii_ind_2s}
| {futii_ind_2p}
| {futii_subii_2s}
| {futii_subii_2p}
|-
| {futii_ind_3s}
| {futii_ind_3p}
| {futii_subii_3s}
| {futii_subii_3p}
|{\cl}{notes_clause}</div></div>]=]


local function make_table(alternant_multiword_spec)
	local forms = alternant_multiword_spec.forms

	forms.title = link_term(alternant_multiword_spec.lemmas[1].form, "term")
	if alternant_multiword_spec.annotation ~= "" then
		forms.title = forms.title .. " (" .. alternant_multiword_spec.annotation .. ")"
	end

	-- Maybe format the subordinate clause table.
	local formatted_subordinate_clause_table
	if forms.subc_pres_3s ~= "—" then -- use 3s in case of only3s verb
		forms.zu_infinitive_table = m_string_utilities.format(zu_infinitive_table, forms)
		forms.footnote = alternant_multiword_spec.footnote_subordinate_clause
		forms.notes_clause = forms.footnote ~= "" and m_string_utilities.format(notes_template, forms) or ""
		formatted_subordinate_clause_table = m_string_utilities.format(subordinate_clause_table, forms)
	else
		forms.zu_infinitive_table = ""
		formatted_subordinate_clause_table = ""
	end

	-- Format the basic table.
	forms.footnote = alternant_multiword_spec.footnote_basic
	forms.notes_clause = forms.footnote ~= "" and m_string_utilities.format(notes_template, forms) or ""
	local formatted_basic_table = m_string_utilities.format(basic_table, forms)

	-- Format the composed table.
	forms.footnote = alternant_multiword_spec.footnote_composed
	forms.notes_clause = forms.footnote ~= "" and m_string_utilities.format(notes_template, forms) or ""
	local formatted_composed_table = m_string_utilities.format(composed_table, forms)

	-- Paste them together.
	return formatted_basic_table .. formatted_subordinate_clause_table .. formatted_composed_table
end


-- Externally callable function to parse and conjugate a verb given user-specified arguments.
-- Return value is WORD_SPEC, an object where the conjugated forms are in `WORD_SPEC.forms`
-- for each slot. If there are no values for a slot, the slot key will be missing. The value
-- for a given slot is a list of objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms(parent_args, from_headword, def)
	local params = {
		[1] = {},
	}

	if from_headword then
		params["lemma"] = {list = true}
		params["id"] = {}
	end

	local args = require("Module:parameters").process(parent_args, params)
	local PAGENAME = mw.title.getCurrentTitle().text

	if not args[1] then
		if PAGENAME == "de-conj" or PAGENAME == "de-verb" then
			args[1] = def or "aus.fahren<fährt#fuhr,gefahren,führe.haben,sein>"
		else
			args[1] = PAGENAME
			-- If pagename has spaces in it, add links around each word
			if args[1]:find(" ") then
				args[1] = "[[" .. args[1]:gsub(" ", "]] [[") .. "]]"
			end
		end
	end
	local parse_props = {
		parse_indicator_spec = parse_indicator_spec,
		lang = lang,
		allow_default_indicator = true,
		allow_blank_lemma = true,
	}
	local escaped_arg1 = escape_reflexive_indicators(args[1])
	local alternant_multiword_spec = iut.parse_inflected_text(escaped_arg1, parse_props)
	alternant_multiword_spec.pos = pos or "verbs"
	alternant_multiword_spec.args = args
	normalize_all_lemmas(alternant_multiword_spec, from_headword)
	detect_all_indicator_specs(alternant_multiword_spec)
	local inflect_props = {
		slot_list = all_verb_slots,
		lang = lang,
		inflect_word_spec = conjugate_verb,
		-- We add links around the generated verbal forms rather than allow the entire multiword
		-- expression to be a link, so ensure that user-specified links get included as well.
		include_user_specified_links = true,
	}
	iut.inflect_multiword_or_alternant_multiword_spec(alternant_multiword_spec, inflect_props)
	compute_auxiliary(alternant_multiword_spec)
	compute_categories_and_annotation(alternant_multiword_spec, from_headword)
	return alternant_multiword_spec
end


-- Entry point for {{de-conj}}. Template-callable function to parse and conjugate a verb given
-- user-specified arguments and generate a displayable table of the conjugated forms.
function export.show(frame)
	local parent_args = frame:getParent().args
	local alternant_multiword_spec = export.do_generate_forms(parent_args)
	show_forms(alternant_multiword_spec)
	return make_table(alternant_multiword_spec) .. require("Module:utilities").format_categories(alternant_multiword_spec.categories, lang)
end


-- Concatenate all forms of all slots into a single string of the form
-- "SLOT=FORM,FORM,...|SLOT=FORM,FORM,...|...". Embedded pipe symbols (as might occur
-- in embedded links) are converted to <!>. If INCLUDE_PROPS is given, also include
-- additional properties (currently, none). This is for use by bots.
local function concat_forms(alternant_multiword_spec, include_props)
	local ins_text = {}
	for _, slot_and_accel in ipairs(all_verb_slots) do
		local slot = slot_and_accel[1]
		local formtext = iut.concat_forms_in_slot(alternant_multiword_spec.forms[slot])
		if formtext then
			table.insert(ins_text, slot .. "=" .. formtext)
		end
	end
	if include_props then
		local verb_types = {}
		iut.map_word_specs(alternant_multiword_spec, function(base)
			detect_verb_type(base, verb_types)
		end)
		table.insert(ins_text, "class=" .. table.concat(verb_types, ","))
	end
	return table.concat(ins_text, "|")
end


local numbered_params = {
	-- required params
	[1] = "infinitive",
	[2] = "pres_part",
	[3] = "perf_part",
	[4] = "aux",
	[5] = "pres_1s",
	[6] = "pres_2s",
	[7] = "pres_3s",
	[8] = "pres_1p",
	[9] = "pres_2p",
	[10] = "pres_3p",
	[11] = "pret_1s",
	[12] = "pret_2s",
	[13] = "pret_3s",
	[14] = "pret_1p",
	[15] = "pret_2p",
	[16] = "pret_3p",
	[17] = "subi_1s",
	[18] = "subi_2s",
	[19] = "subi_3s",
	[20] = "subi_1p",
	[21] = "subi_2p",
	[22] = "subi_3p",
	[23] = "subii_1s",
	[24] = "subii_2s",
	[25] = "subii_3s",
	[26] = "subii_1p",
	[27] = "subii_2p",
	[28] = "subii_3p",
	[29] = "imp_2s",
	[30] = "imp_2p",
	-- [31] formerly the 2nd variant of imp_2s; now no longer allowed (use comma-separated 29=)
	-- [32] formerly indicated whether the 2nd variant of imp_2s was present
	-- optional params
	[33] = "subc_pres_1s",
	[34] = "subc_pres_2s",
	[35] = "subc_pres_3s",
	[36] = "subc_pres_1p",
	[37] = "subc_pres_2p",
	[38] = "subc_pres_3p",
	[39] = "subc_pret_1s",
	[40] = "subc_pret_2s",
	[41] = "subc_pret_3s",
	[42] = "subc_pret_1p",
	[43] = "subc_pret_2p",
	[44] = "subc_pret_3p",
	[45] = "subc_subi_1s",
	[46] = "subc_subi_2s",
	[47] = "subc_subi_3s",
	[48] = "subc_subi_1p",
	[49] = "subc_subi_2p",
	[50] = "subc_subi_3p",
	[51] = "subc_subii_1s",
	[52] = "subc_subii_2s",
	[53] = "subc_subii_3s",
	[54] = "subc_subii_1p",
	[55] = "subc_subii_2p",
	[56] = "subc_subii_3p",
	[57] = "zu_infinitive",
}

local max_required_param = 30



-- Externally callable function to parse and conjugate a verb where all forms are given manually.
-- Return value is WORD_SPEC, an object where the conjugated forms are in `WORD_SPEC.forms`
-- for each slot. If there are no values for a slot, the slot key will be missing. The value
-- for a given slot is a list of objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms_manual(parent_args)
	local params = {
		["generate_forms"] = {type = "boolean"},
	}
	for paramnum, _ in pairs(numbered_params) do
		params[paramnum] = {required = paramnum <= max_required_param}
	end

	local args = require("Module:parameters").process(parent_args, params)

	local base = {
		forms = {},
		manual = true,
	}
	local function process_numbered_param(paramnum)
		local argval = args[paramnum]
		if paramnum == 4 then
			if argval == "h" then
				base.aux = {{form = "haben"}}
			elseif argval == "s" then
				base.aux = {{form = "sein"}}
			elseif argval == "hs" then
				base.aux = {{form = "haben"}, {form = "sein"}}
			elseif argval == "sh" then
				base.aux = {{form = "sein"}, {form = "haben"}}
			elseif not argval then
				error("Missing auxiliary in 4=")
			else
				error("Unrecognized auxiliary 4=" .. argval)
			end
		elseif argval and argval ~= "-" then
			local split_vals = rsplit(argval, "%s*,%s*")
			for _, val in ipairs(split_vals) do
				-- FIXME! This won't work with commas or brackets in footnotes.
				-- To fix this, use functions from [[Module:inflection utilities]].
				local form, footnote = val:match("^(.-)%s*(%[[^%]%[]-%])$")
				local footnotes
				if form then
					footnotes = {footnote}
				else
					form = val
				end
				local slot = numbered_params[paramnum]
				--if slot:find("subii") then
				--	local subii_footnotes = get_subii_note(base)
				--	footnotes = iut.combine_footnotes(subii_footnotes, footnotes)
				--end
				iut.insert_form(base.forms, slot, {form = form, footnotes = footnotes})
			end
		end
	end

	-- Do the infinitive first as we need to reference it in subjunctive II footnotes.
	process_numbered_param(1)
	for paramnum, _ in pairs(numbered_params) do
		if paramnum ~= 1 then
			process_numbered_param(paramnum)
		end
	end

	add_composed_forms(base)
	compute_categories_and_annotation(base, nil, "manual")
	return base, args.generate_forms
end


-- Entry point for {{de-conj-table}}. Template-callable function to parse and conjugate a verb given
-- manually-specified inflections and generate a displayable table of the conjugated forms.
function export.show_manual(frame)
	local parent_args = frame:getParent().args
	local base, generate_forms = export.do_generate_forms_manual(parent_args)
	if generate_forms then
		return concat_forms(base)
	end
	show_forms(base)
	return make_table(base) .. require("Module:utilities").format_categories(base.categories, lang)
end


-- Template-callable function to parse and conjugate a verb given user-specified arguments and return
-- the forms as a string "SLOT=FORM,FORM,...|SLOT=FORM,FORM,...|...". Embedded pipe symbols (as might
-- occur in embedded links) are converted to <!>. If |include_props=1 is given, also include
-- additional properties (currently, none). This is for use by bots.
function export.generate_forms(frame)
	local include_props = frame.args["include_props"]
	local parent_args = frame:getParent().args
	local alternant_multiword_spec = export.do_generate_forms(parent_args)
	return concat_forms(alternant_multiword_spec, include_props)
end


return export
