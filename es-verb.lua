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

1. Implement no_pres_stressed for aterir, garantir. (NOTE: Per RAE, garantir used in all forms in Argentina/Uruguay.)
2. Support concluyo.
3. Fixes for veo -> ve vs. preveo -> prevé.
4. Various more irregular verbs, e.g. predecir, redecir, bendecir, maldecir.
5. Raising of e -> i, o -> u before -iendo, -ió, etc. occurs only in -ir verbs.
6. Raising of e -> i, o -> u happens before subjunctive -amos, -áis in -ir verbs.
--]=]

local lang = require("Module:languages").getByCode("es")
local m_string_utilities = require("Module:string utilities")
local m_links = require("Module:links")
local m_table = require("Module:table")
local iut = require("Module:inflection utilities")
local com = require("Module:es-common")

local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsplit = mw.text.split

local function link_term(term, face)
	return m_links.full_link({ lang = lang, term = term }, face)
end


local V = com.V -- vowel regex class
local AV = com.AV -- accented vowel regex class
local C = com.C -- consonant regex class


local fut_sub_note = "Mostly obsolete form, now mainly used in legal jargon."
local pres_sub_voseo_note = "Argentine and Uruguayan " .. link_term("voseo", "term") .. " prefers the " ..
	link_term("tú", "term") .. " form for the present subjunctive."

local vowel_alternants = m_table.listToSet({"ie", "ie-i", "ue", "ue-u", "i", "í", "ú", "+"})

local raise_vowel = {["e"] = "i", ["o"] = "u"}

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

local verb_slots_combined = {}

local verb_slot_combined_rows = {}

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

local function add_combined_slot(basic_slot, tag, pronouns)
	add_slot_personal(verb_slots_combined, basic_slot .. "_comb", tag_suffix .. "|combined", pronouns)
	table.insert(verb_slot_combined_rows, {basic_slot, pronouns})
end

add_combined_slot("infinitive", "inf", {"me", "te", "se", "nos", "os", "lo", "la", "le", "los", "las", "les"})
add_combined_slot("gerund", "gerund", {"me", "te", "se", "nos", "os", "lo", "la", "le", "los", "las", "les"})
add_combined_slot("imp_2s", "imp|2s", {"me", "te", "nos", "lo", "la", "le", "los", "las", "les"})
add_combined_slot("imp_3s", "imp|3s", {"me", "se", "nos", "lo", "la", "le", "los", "las", "les"})
add_combined_slot("imp_1p", "imp|1p", {"te", "nos", "os", "lo", "la", "le", "los", "las", "les"})
add_combined_slot("imp_2p", "imp|2p", {"me", "nos", "os", "lo", "la", "le", "los", "las", "les"})
add_combined_slot("imp_3p", "imp|3p", {"me", "se", "nos", "lo", "la", "le", "los", "las", "les"})

local all_verb_slots = {}
for _, slot_and_accel in ipairs(verb_slots_basic) do
	table.insert(all_verb_slots, slot_and_accel)
end
for _, slot_and_accel in ipairs(verb_slots_combined) do
	table.insert(all_verb_slots, slot_and_accel)
end

local verb_slots_basic_map = {}
for _, slotaccel in ipairs(verb_slots_basic) do
	local slot, accel = unpack(slotaccel)
	verb_slots_basic_map[slot] = accel
end

local verb_slots_combined_map = {}
for _, slotaccel in ipairs(verb_slots_basic) do
	local slot, accel = unpack(slotaccel)
	verb_slots_combined_map[slot] = accel
end

local function match_against_verbs(ref_verb, prefixes)
	return function(verb)
		for _, prefix in ipairs(prefixes) do
			if verb == prefix .. ref_verb then
				return prefix
			end
		end
		return nil
	end
end


--[=[

Special cases for verbs:

auxiliar, gloriar, afiliar, extasiar, acuantiar, desafiliar: -io or -ío. These can be handled by specifying the
appropriate params in the conjugation.

diluviar, atardecer, empecer: impersonal; all finite non-3s forms are nonexistent or hypothetical. Handle using
'.only3s'.

atañer, concernir: all finite non-third-person forms are nonexistent or hypothetical. Handle using '.only3sp'.

desposeer: Former module claimed an irregular past participle 'desposeso'. Not per RAE.

rehuir: Handle using +ú.

-ir verbs:

There are several types of vowel alternations:

1. No alternation. Includes some verbs in -e- and -o-, e.g. tra(n)sgredir, abolir, although the stressed
   forms are rare or disused.
2. ie: Infinitive has -e-, changing to -ie- when stressed. No raising before i+V. Only hendir, cernir, discernir:
   discernir -> discierno, discerniendo, discernió, discernamos.
3. ie-i: Infinitive has -e- or -i-, changing to -ie- when stressed. Raising before i+V and 1p/2p pres subjunctive:
   sentir -> siento, sintiendo, sintió, sintamos.
   adquirir -> adquiero, adquiriendo, adquirió, adquiramos.
4. i: Infinitive has -e-, changing to -i- when stressed. Raising before i+V and 1p/2p pres subjunctive:
   vestir -> visto, vistiendo, vistió, vistamos. Variant: ceñir -> ciño, ciñendo, ciñó, ciñamos.
5. ue-u: Infinitive has -o-, changing to -ue- when stressed. Raising before i+V and 1p/2p pres subjunctive:
   Only dormir, morir and compounds. dormir -> duermo, durmiendo, durmió, durmamos.
6. ue: This type would be parallel to 'ie' but doesn't appear to exist.
]=]

--[=[
Irregular conjugations.

Each key of `forms` can either be a stem or an individual override form. Each value can either be a string
(a single stem or form), a list of strings, or a list of objects of the form
{form = STEM_OR_FORM, footnotes = {FOONOTES}}.

NOTE: Various phonetic modifications occur automatically whenever they are predictable; see combine_stem_ending().
In particular:

1. Spelling-based modifications (c/z, g/gu, gu/gü, g/j) occur automatically as appropriate for the ending.
2. Numerous modifications are automatically made before an ending beginning with i + vowel. These include raising
   of e -> i, o -> u (dormir -> durmiendo, durmió
The following stems are recognized:

-- pres_unstressed: The present indicative unstressed stem (2s voseo, 1p, 2p). Also controls the imperative 2p
     and gerund. Defaults to the infinitive stem.
-- pres_stressed: The present indicative stressed stem (1s, 2s, 3s, 3p). Also controls the imperative 2s.
     Default is empty if indicator `no_pres_stressed`, else a vowel alternation if such an indicator is given
	 (e.g. `ue`, `ì`), else infinitive stem + 'y' for verbs in -uir, else the infinitive stem.
-- pres_sub_unstressed: The present subjunctive unstressed stem (1p, 2p, also 2s voseo for -ar verbs).
     
-- 

]=]

local irreg_conjugations = {
	{
		-- andar, desandar
		-- we don't want to match e.g. mandar.
		match = match_against_verbs("andar", {"", "des"}),
		forms = {pret = "anduv", pret_conj = "irreg"}
	},
	{
		-- asir, desasir
		match = "asir",
		forms = {pres1_and_sub = "asg"}
	},
	{
		-- abrir, cubrir and compounds
		match = "brir",
		forms = {pp = "biert"}
	},
	{
		match = "caber",
		forms = {pres1_and_sub = "quep", pret = "cup", fut = "cabr"}
	},
	{
		-- caer, decaer, descaer, recaer
		match = "caer",
		forms = {pres1_and_sub = "caig"}
	},
	{
		match = "^dar",
		forms = {
			pres_1s = "doy", pret = "d", pret_conj = "er",
			pres_sub_1s = "dé*", pres_sub_3s = "dé*" -- * signals that the monosyllabic accent must remain
		}
	},
	{
		-- decir, redecir, entredecir
		match = match_against_verbs("decir", {"", "re", "entre"}),
		forms = {
			pres1_and_sub = "dig", pres_stressed = "dic", raising_conj = true, pret = "dij", pret_conj = "irreg",
			pp = "dich", fut = "dir",
			imp_2s = "dí" -- need the accent for the compounds; it will be removed in the simplex
		}
	},
	{
		-- antedecir, interdecir
		match = match_against_verbs("decir", {"ante", "inter"}),
		forms = {
			pres1_and_sub = "dig", pres_stressed = "dic", raising_conj = true, pret = "dij", pret_conj = "irreg",
			pp = "dich", fut = "dir" -- imp_2s regular
		}
	},
	{
		-- bendecir, maldecir
		match = match_against_verbs("decir", {"ben", "mal"}),
		forms = {
			pres1_and_sub = "dig", pres_stressed = "dic", raising_conj = true, pret = "dij", pret_conj = "irreg",
			pp = {"decid", "dit"} -- imp_2s regular, fut regular
		}
	},
	{
		-- condecir, contradecir, desdecir, predecir, others?
		match = "decir",
		forms = {
			pres1_and_sub = "dig", pres_stressed = "dic", raising_conj = true, pret = "dij", pret_conj = "irreg",
			pp = "dich", fut = {"decir", "dir"} -- imp_2s regular
		}
	},
	{
		-- FIXME: does this verb really exist? Not in RAE.
		match = "desnacer",
		forms = {pp = {"desnacid", "desnat"}}
	},
	{
		match = "^desosar",
		forms = {pres_stressed = "deshues"}
	},
	{
		-- conducir, producir, reducir, traducir, etc.
		match = "ducir",
		forms = {pret = "duj", pret_conj = "irreg"}
	},
	{
		-- elegir, reelegir; not preelegir, per RAE
		match = match_against_verbs("elegir", {"", "re"}),
		forms = {pres_stressed = "elig", raising_conj = true, pp = {"elegid", "elect"}}
	},
	{
		match = "^errar",
		forms = {pres_stressed = {
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
		match = "garantir",
		forms = {pres_stressed = {{form = "garant", footnotes = {"[only used in Argentina and Uruguay]"}}},
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
		match = "satisfacer",
		forms = {
			pres1_and_sub = "satisfag", pret = "satisfic", pret_conj = "irreg", pp = "satisfech", fut = "satisfar",
			imp_2s = {"satisface", "satisfaz"}
		}
	},
	{
		-- hacer, deshacer, contrahacer, rehacer, facer, desfacer, jacer
		-- contrahacer/rehacer require an extra accent in the preterite (rehíce, rehízo), but this is handled
		-- automatically by combine_stem_ending().
		match = function(verb) return rmatch(verb, "^(.*[hjf])acer$") end,
		forms = {pres1_and_sub = "ag", pret = "ic", pret_conj = "irreg", pp = "ech", fut = "ar", imp_2s = "az"}
	},
	{
		-- imprimir, reimprimir
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
		-- RAE doesn't list irregular PP manumiso.
		match = "manumitir",
		forms = {pp = {"manumitid", "manumis"}}
	},
	{
		-- mecer, remecer
		-- we don't want to match e.g. adormecer, estremecer
		match = match_against_verbs("mecer", {"re", ""}),
		forms = {pres1_and_sub = "mez"}, -- not mezco, as would normally be generated
	},
	{
		-- morir, desmorir, premorir
		match = "morir",
		forms = {pres_stressed = "muer", raising_conj = true, pp = "muert"},
	},
	{
		match = "oír",
		forms = {pres1_and_sub = "oig"}
	},
	{
		match = "^oler",
		forms = {pres_stressed = "huel"}
	},
	{
		match = "olver", -- solver, volver, bolver and derivatives
		forms = {pres_stressed = "uelv", pp = "uelt"}
	},
	{
		-- placer, desplacer
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
		forms = {pres_stressed = "pued", pret = "pud", pret_conj = "irreg", fut = "podr"}
	},
	{
		-- poner, componer, deponer, imponer, oponer, suponer, many others
		match = "poner",
		forms = {
			pres1_and_sub = "pong", pret = "pus", pret_conj = "irreg", fut = "pondr",
			imp_2s = "pón" -- need the accent for the compounds; it will be removed in the simplex
		}
	},
	{
		-- proveer, desproveer
		match = "proveer",
		forms = {pp = {"proveíd", "provist"}},
	},
	{
		match = "pudrir",
		forms = {pp = "podrid"}
	},
	{
		-- querer, desquerer, malquerer
		match = "querer",
		forms = {pres_stressed = "quier", pret = "quis", pret_conj = "irreg", fut = "querr"}
	},
	{
		match = "raer",
		forms = {
			pres1_and_sub = {"raig", "ray"}, -- only for subjunctive as we override pres_1s
			pres_1s = {"raigo", "rayo", "rao"}, -- RAE doesn't allow rao
		}
	},
	{
		-- roer, corroer
		match = "roer",
		forms = {pres1_and_sub = {"ro", "roig", "roy"}}
	},
	{
		-- romper, interromper?
		match = "romper",
		forms = {pp = "rot"}
	},
	{
		-- saber, resaber
		match = "saber",
		forms = {
			pres_1s = "sé*", -- * signals that the monosyllabic accent must remain
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
			imp_2s = "sé*", -- * signals that the monosyllabic accent must remain
			imp_2sv = "sé*",
		}
	},
	{
		match = "^soler",
		forms = {
			pres_stressed = "suel",
			fut = {{form = "soler", footnotes = {"[rare but acceptable]"}}},
			fut_sub = {{form = "sol", footnotes = {"[rare but acceptable]"}}},
		}
	},
	{
		-- tener, abstener, contener, detener, obtener, sostener, and many others
		match = "tener",
		forms = {
			pres1_and_sub = "teng", pres_stressed = "tien", pret = "tuv", pret_conj = "irreg", fut = "tendr",
			imp_2s = "tén" -- need the accent for the compounds; it will be removed in the simplex
		}
	},
	{
		-- traer, atraer, detraer, distraer, extraer, sustraer, and many others
		match = "traer",
		forms = {pres1_and_sub = "traig", pret = "traj", pret_conj = "irreg"}
	},
	{
		-- valer, equivaler, prevaler
		match = "valer",
		forms = {
			pres1_and_sub = "valg", fut = "valdr",
			imp_2s = {"vale", "val"} -- RAE does not list val
		}
	},
	{
		match = "venir",
		forms = {pres1_and_sub = "veng", pres_stressed = "vien", raising_conj = true, pret = "vin", pret_conj = "irreg", fut = "vendr", imp_2s = "ven"}
	},
	{
		-- We want to match antever etc. but not atrever etc. No way to avoid listing each verb.
		match = match_against_verbs("ver", {"ante", "entre", "pre", "re", ""}),
		forms = {
			-- we need to override various present indicative forms and add an accent for the compounds;
			-- not needed for the simplex and in fact the accents will be removed in that case
			pres_2s = "vés",
			pres_2sv = "vés",
			pres_3s = "vé",
			pres_2p = "véis",
			pres_3p = "vén",
			pres1_and_sub = "ve",
			impf = "ve", pp = "vist"
		}
	},
	{
		-- yacer, adyacer, subyacer
		match = "yacer",
		forms = {pres1_and_sub = {"yazc", "yazg", "yag"}, imp_2s = {"yace", "yaz"}}
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
	if base.basic_overrides[slot] or base.combined_overrides[slot] then
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

	if base.only3s and (not slot:find("3s") or slot:find("^imp")) then
		-- atardecer
		return true
	end

	if base.only3sp and (not slot:find("3[sp]") or slot:find("^imp")) then
		-- atañer
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


local function combine_stem_ending(base, slot, stem, ending, is_combining_ending)
	if base.stems.raising_conj and (rfind(ending, "^i" .. V) or slot == "pres_sub_1p" or slot == "pres_sub_2p") then
		-- need to raise e -> i, o -> u: dormir -> durmió, durmiera, durmiendo, durmamos
		stem = rsub(stem, "([eo])(" .. C .. "*)$", function(vowel, rest) return raise_vowel[vowel] .. rest end)
		-- also with stem ending in -gu or -qu (e.g. erguir -> irguió, irguiera, irguiendo, irgamos)
		stem = rsub(stem, "([eo])(" .. C .. "*[gq]u)$", function(vowel, rest) return raise_vowel[vowel] .. rest end)
	end

	-- Lots of sound changes involving endings beginning with i + vowel
	if rfind(ending, "^i" .. V) then
		-- (1) final -i of stem absorbed: sonreír -> sonrió, sonriera, sonriendo; note that this rule may be fed
		-- by the preceding one (stem sonre- raised to sonri-, then final i absorbed)
		stem = stem:gsub("i$", "")

		-- (2) initial i -> y after vowel: poseer -> poseyó, poseyera, poseyendo; concluir -> concluyó, concluyera, concluyendo
		if rfind(stem, V .. "$") then
			ending = ending:gsub("^i", "y")
		end

		-- (3) initial i absorbed after ñ, ll, y: tañer -> tañó, tañera, tañendo; bullir -> bulló, bullera, bullendo
		if rfind(stem, "[ñy]$") or rfind(stem, "ll$") then
			ending = ending:gsub("^i", "")
		end

		-- (4) In the preterite of irregular verbs (likewise for other tenses derived from the preterite stem, i.e.
		--     imperfect and future subjunctive), initial i absorbed after j (dijeron not #dijieron, likewise for
		--     condujeron, trajeron). Does not apply in tejer (tejieron not #tejeron).
		if base.stems.pret_conj == "irreg" and rfind(stem, "j$") then
			ending = ending:gsub("^i", "")
		end
	end

	-- If ending begins with (h)i, it must get an accent after a/e/i/o to prevent the two merging into a diphthong:
	-- caer -> caíste, caímos; reír -> reíste, reímos (pres and pret); re + hice -> rehíce. This does not apply
	-- after u, e.g. concluir -> concluiste, concluimos.
	if ending:find("^h?i") and stem:find("[aeio]$") then
		ending = ending:gsub("^(h?)i", "%1í")
	end

	-- If -uir (i.e. -ir with stem ending in -u), a y must be added before endings beginning with a/e/o.
	if base.conj == "ir" and ending:find("^[aeo]") then
		if stem:find("u$") then
			stem = stem .. "y"
		elseif stem:find("ü$") then -- argüir -> arguyendo
			stem = stem:gsub("ü$", "uy")
		end
	end

	if is_combining_ending then
		-- Spelling changes in the stem; it depends on whether the stem given is the pre-front-vowel or
		-- pre-back-vowel variant, as indicated by `frontback`. We want these front-back spelling changes to happen
		-- between stem and ending, not between prefix and stem; the prefix may not have the same "front/backness"
		-- as the stem.
		local is_front = rfind(ending, "^[eiéí]")
		if base.frontback == "front" and not is_front then
			-- parecer -> parezco, conducir -> conduzco; use zqu to avoid triggering the following gsub();
			-- the third line will replace zqu -> zc
			stem = rsub(stem, "(" .. V .. ")c$", "%1zqu")
			stem = stem:gsub("c$", "z") -- ejercer -> ejerzo, uncir -> unzo
			stem = stem:gsub("qu$", "c") -- delinquir -> delinco, parecer -> parezqu- -> parezco
			stem = stem:gsub("g$", "j") -- coger -> cojo, afligir -> aflijo
			stem = stem:gsub("gu$", "g") -- distinguir -> distingo
			stem = stem:gsub("gü$", "gu") -- may not occur; argüir -> arguyo handled above
		elseif base.frontback == "back" and is_front then
			stem = stem:gsub("gu$", "gü") -- averiguar -> averigüé
			stem = stem:gsub("g", "gu") -- cargar -> cargué
			stem = stem:gsub("c", "qu") -- marcar -> marqué
			stem = rsub(stem, "[çz]$", "c") -- aderezar/adereçar -> aderecé
		end
	end

	return replace_reflexive_indicators(slot, stem .. ending)
end


local function add(base, slot, stems, endings, is_combining_ending)
	if skip_slot(base, slot) then
		return
	end
	local function do_combine_stem_ending(stem, ending)
		return combine_stem_ending(base, slot, stem, ending, is_combining_ending)
	end
	iut.add_forms(base.forms, slot, stems, endings, do_combine_stem_ending, nil, nil, base.all_footnotes)
end


local function add3(base, slot, prefix, stems, endings)
	if skip_slot(base, slot) then
		return
	end
	local first = true
	local function do_combine_stem_ending(stem, ending)
		-- We need to distinguish the case of combining prefix with stem vs. stem with ending inside of
		-- combine_stem_ending(), in particular in the front-back stem handling. The way we do it is a bit
		-- of a hack but works.
		local is_combining_ending = not first
		first = false
		return combine_stem_ending(base, slot, stem, ending, is_combining_ending)
	end
	iut.add_multiple_forms(base.forms, slot, {prefix, stems, endings}, do_combine_stem_ending, nil, nil,
		base.all_footnotes)
end


local function add_single_stem_tense(base, slot_pref, stems, s1, s2, s3, p1, p2, p3)
	local function addit(slot, ending)
		add3(base, slot_pref .. "_" .. slot, base.prefix, stems, ending)
	end
	addit("1s", s1)
	addit("2s", s2)
	addit("3s", s3)
	addit("1p", p1)
	addit("2p", p2)
	addit("3p", p3)
end



local function add_present_indic(base)
	local function addit(slot, stems, ending)
		add3(base, "pres_" .. slot, base.prefix, stems, ending)
	end
	local s2, s2v, s3, p1, p2, p3
	if base.conj == "ar" then
		s2, s2v, s3, p1, p2, p3 = "as", "ás", "a", "amos", "áis", "an"
	elseif base.conj == "er" then
		s2, s2v, s3, p1, p2, p3 = "es", "és", "e", "emos", "éis", "en"
	elseif base.conj == "ir" then
		s2, s2v, s3, p1, p2, p3 = "es", "ís", "e", "imos", "ís", "en"
	else
		error("Internal error: Unrecognized conjugation " .. base.conj)
	end

	addit("1s", base.stem.pres1, "o")
	addit("2s", base.stem.pres_stressed, s2)
	addit("2sv", base.stem.pres_unstressed, s2v)
	addit("3s", base.stem.pres_stressed, s3)
	addit("1p", base.stem.pres_unstressed, p1)
	addit("2p", base.stem.pres_unstressed, p2)
	addit("3p", base.stem.pres_stressed, p3)
end


local function add_present_subj(base)
	local function addit(slot, stems, ending)
		add3(base, "pres_sub_" .. slot, base.prefix, stems, ending)
	end
	local s1, s2, s2v, s3, p1, p2, p3, voseo_stem
	if base.conj == "ar" then
		voseo_stem = base.stems.pres_sub_stressed
		s1, s2, s2v, s3, p1, p2, p3 = "e", "es", "és", "e", "emos", "éis", "en"
	else
		-- voseo and tu forms are identical
		voseo_stem = base.stems.pres_sub_unstressed
		s1, s2, s2v, s3, p1, p2, p3 = "a", "as", "as", "a", "amos", "áis", "an"
	end

	addit("pres_1s", base.stems.pres_sub_stressed, s1)
	addit("pres_2s", base.stems.pres_sub_stressed, s2)
	addit("pres_2sv", voseo_stem, s2v)
	addit("pres_3s", base.stems.pres_sub_stressed, s3)
	addit("pres_1p", base.stems.pres_sub_unstressed, p1)
	addit("pres_2p", base.stems.pres_sub_unstressed, p2)
	addit("pres_3p", base.stems.pres_sub_stressed, p3)
end


local function add_imper(base)
	local function addit(slot, stems, ending)
		add3(base, "imp_" .. slot, base.prefix, stems, ending)
	end
	if base.conj == "ar" then
		addit("2s", base.stems.pres_stressed, "a")
		addit("2sv", base.stems.pres_unstressed, "á")
		addit("2p", base.stems.pres_unstressed, "ad")
	elseif base.conj == "er" then
		addit("2s", base.stems.pres_stressed, "e")
		addit("2sv", base.stems.pres_unstressed, "é")
		addit("2p", base.stems.pres_unstressed, "ed")
	elseif base.conj == "ir" then
		addit("2s", base.stems.pres_stressed, "e")
		addit("2sv", base.stems.pres_unstressed, "í")
		addit("2p", base.stems.pres_unstressed, "id")
	else
		error("Internal error: Unrecognized conjugation " .. base.conj)
	end
end


local function add_non_present(base)
	local function add_tense(slot, stem, s1, s2, s3, p1, p2, p3)
		add_single_stem_tense(base, slot, stem, s1, s2, s3, p1, p2, p3)
	end

	local stems = base.stems

	if stems.full_impf then
		-- An override needs to be supplied for the impf_1p due to the accent on the stem.
		add_tense("impf", stems.full_impf, "a", "as", "a", {}, "ais", "an")
	elseif base.conj == "ar" then
		add_tense("impf", stems.impf, "aba", "abas", "aba", "ábamos", "abais", "aban")
	else
		add_tense("impf", stems.impf, "ía", "ías", "ía", "íamos", "íais", "ían")
	end

	if stems.pret_conj == "irreg" then
		add_tense("pret", stems.pret, "e", "iste", "o", "imos", "isteis", "ieron")
	elseif stems.pret_conj == "ar" then
		add_tense("pret", stems.pret, "é", "aste", "ó", "amos", "asteis", "aron")
	else
		add_tense("pret", stems.pret, "í", "iste", "ió", "imos", "isteis", "ieron")
	end

	if stems.pret_conj == "ar" then
		add_tense("impf_sub_ra", stems.impf_sub_ra, "ara", "aras", "ara", "áramos", "arais", "aran")
		add_tense("impf_sub_se", stems.impf_sub_se, "ase", "ases", "ase", "ásemos", "aseis", "asen")
		add_tense("fut_sub", stems.fut_sub, "are", "ares", "are", "áremos", "areis", "aren")
	else
		add_tense("impf_sub_ra", stems.impf_sub_ra, "iera", "ieras", "iera", "iéramos", "ierais", "ieran")
		add_tense("impf_sub_se", stems.impf_sub_se, "iese", "ieses", "iese", "iésemos", "ieseis", "iesen")
		add_tense("fut_sub", stems.fut_sub, "iere", "ieres", "iere", "iéremos", "iereis", "ieren")
	end

	add_tense("fut", stems.fut, "é", "ás", "á", "emos", "éis", "án")
	add_tense("cond", stems.cond, "ía", "ías", "ía", "íamos", "íais", "ían")

	-- Do the participles.
	local function addit(slot, stems, ending)
		add3(base, slot, base.prefix, stems, ending)
	end
	addit("gerund", stems.pres_unstressed, conj == "ar" and "ando" or "iendo")
	addit("pp_ms", stems.pp, "o")
	addit("pp_fs", stems.pp, "a")
	addit("pp_mp", stems.pp, "os")
	addit("pp_fp", stems.pp, "as")
end


-- Remove monosyllabic accents (e.g. the 3sg preterite of fiar is fio not #fió). Note that there are a
-- few monosyllabic verb forms that intentionally have an accent, to distinguish them from other words
-- with the same pronunciation. These are as follows:
-- (1) [[sé]] 1sg present indicative of [[saber]];
-- (2) [[sé]] 2sg imperative of [[ser]];
-- (3) [[dé]] 1sg and 3sg present subjunctive of [[dar]].
-- For these, a * is added, which indicates that the accent needs to remain. If we see such a *, we remove
-- it but otherwise leave the form alone.
local function remove_monosyllabic_accents(base)
	for _, slotaccel in ipairs(verb_slots_basic) do
		local slot, accel = unpack(slotaccel)
		if base.forms[slot] then
			for _, form in ipairs(base.forms[slot]) do
				if form.form:find("%*") then -- * means leave alone any accented vowel
					form.form = form.form:gsub("%*", "")
				elseif rfind(form.form, SV) and not rfind(form.form, V .. C .. V) then
					-- Has an accented vowel and no VCV sequence; may be monosyllabic, in which case we need
					-- to remove the accent. Check # of syllables and remove accent if only 1. Note that
					-- the checks for accented vowel and VCV sequence are not strictly needed, but are
					-- optimizations to avoid running the whole syllabification algorithm on every verb form.
					local syllables = com.syllabify(form.form)
					if #syllables == 1 then
						form.form = com.remove_accent_from_syllable(syllables[1])
					end
				end
			end
		end
	end
end


local function construct_stems(base)
	local stems = base.stems
	base.basic_overrides = {}
	base.combined_overrides = {}
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
				if verb_slots_basic_map[stem] then
					-- an individual form override of a basic form
					base.basic_overrides[stem] = forms
				elseif verb_slots_combined_map[stem] then
					-- an individual form override of a combined form
					base.combined_overrides[stem] = forms
				else
					stems[stem] = forms
				end
			end
			break
		end
	end

	stems.pres_unstressed = stems.pres_unstressed or base.inf_stem
	stems.pres_stressed = stems.pres_stressed or
		-- If no_pres_stressed given, pres_stressed stem should be empty so no forms are generated.
		base.no_pres_stressed and {} or
		base.vowelalt or
		base.inf_stem
	stems.pres1 = stems.pres1 or stems.pres1_and_sub or stems.pres_stressed
	stems.impf = stems.impf or base.inf_stem
	stems.pret = stems.pret or base.inf_stem
	stems.pret_conj = stems.pret_conj or base.conj
	stems.fut = stems.fut or base.inf_stem
	stems.cond = stems.cond or stems.fut
	stems.pres_sub_stressed = stems.pres_sub_stressed or stems.pres1_and_sub or stems.pres1
	stems.pres_sub_unstressed = stems.pres_sub_unstressed or stems.pres1_and_sub or stems.pres_unstressed
	stems.impf_sub_ra = stems.impf_sub_ra or stems.pret
	stems.impf_sub_se = stems.impf_sub_se or stems.pret
	stems.fut_sub = stems.fut_sub or stems.pret
	stems.pp = stems.pp or base.conj == "ar" and
		combine_stem_ending(base, "pp_ms", base.inf_stem, "ad", "is combining ending") or
		-- use combine_stem_ending esp. so we get reído, caído, etc.
		combine_stem_ending(base, "pp_ms", base.inf_stem, "id", "is combining ending")
end


-- Generate the combinations of verb form (infinitive, gerund or various imperatives) + clitic pronoun.
local function add_combined_forms(base)
	for _, base_slot_and_pronouns in ipairs(verb_slot_combined_rows) do
		local base_slot, pronouns = unpack(base_slot_and_pronouns)
		for _, form in ipairs(base.forms[base_slot]) do
			-- Figure out that correct accenting of the verb when a clitic pronoun is attached to it. We may need to
			-- add or remove an accent mark:
			-- (1) No accent mark currently, none needed: infinitive sentar because of sentarlo; imperative singular
			--     ten because of tenlo;
			-- (2) Accent mark currently, still needed: infinitive oír because of oírlo;
			-- (3) No accent mark currently, accent needed: imperative singular siente -> siénte because of siéntelo;
			-- (4) Accent mark currently, not needed: imperative singular está -> estálo, sé -> selo.
			local syllables = com.syllabify(form.form)
			local sylno = com.stressed_syllable(syllables)
			table.insert(syllables, "lo")
			local needs_accent = com.accent_needed(syllables, sylno)
			if needs_accent then
				syllables[sylno] = com.add_accent_to_syllable(syllables[sylno])
			else
				syllables[sylno] = com.remove_accent_from_syllable(syllables[sylno])
			end
			table.remove(syllables) -- remove added clitic pronoun
			local reaccented_verb = table.concat(syllables)
			for _, pronoun in ipairs(pronouns) do
				local cliticized_verb
				-- Some further special cases.
				if base_slot == "imp_1p" and (pronoun == "nos" or pronoun == "os") then
					-- Final -s disappears: sintamos + nos -> sintámonos, sintamos + os -> sintámoos
					cliticized_verb = reaccented_verb:gsub("s$", "") .. pronoun
				elseif base_slot == "imp_2p" and pronoun == "os" then
					-- Final -d disappears, which may cause an accent to be required:
					-- haced + os -> haceos, sentid + os -> sentíos
					if reaccented_verb:find("id$") then
						cliticized_verb = reaccented_verb:gsub("id$", "íos")
					else
						cliticized_verb = reaccented_verb:gsub("d$", "os")
					end
				else
					cliticized_verb = reaccented_verb .. pronoun
				end
				iut.insert_form(base.forms, base_slot .. "_comb_" .. pronoun,
					{form = cliticized_verb, footnotes = form.footnotes})
			end
		end
	end
end

local function process_slot_overrides(base, do_basic)
	for slot, forms in ipairs(do_basic and base.basic_overrides or base.combined_overrides) do
		add(base, slot, base.prefix, forms, false)
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

	-- Copy subjunctives to imperatives, unless there's an override for the given slot (as with the imp_1p of [[ir]]).
	for _, persnum in ipairs({"3s", "1p", "3p"}) do
		local from = "pres_sub_" .. persnum
		local to = "imp_" .. persnum
		if not base.overrides[from] then
			iut.insert_forms(base.forms, to, iut.map_forms(base.forms[from], function(form) return form end))
		end
	end
end


local function handle_negative_imperatives(base)
	-- Copy subjunctives to negative imperatives, preceded by "no".
	for _, persnum in ipairs({"2s", "3s", "1p", "2p", "3p"}) do
		local from = "pres_sub_" .. persnum
		local to = "imp_" .. persnum
		iut.insert_forms(base.forms, to, iut.map_forms(base.forms[from], function(form)
			return "no [[" .. form .. "]]"
		end))
	end
end


local function conjugate_verb(base)
	add_present_indic(base)
	add_present_subj(base)
	add_imper(base)
	add_non_present(base)
	handle_derived_slots(base)
	process_slot_overrides(base, "do basic") -- do basic slot overrides
	remove_monosyllabic_accents(base)
	handle_negative_imperatives(base)
	add_combined_forms(base)
	process_slot_overrides(base, false) -- do combined slot overrides
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

	local inside = angle_bracket_spec:match("^<(.*)>$")
	assert(inside)
	if inside == "" then
		return base
	end
	local segments = iut.parse_balanced_segment_run(inside, "[", "]")
	local dot_separated_groups = iut.split_alternating_runs(segments, "%.")
	for i, dot_separated_group in ipairs(dot_separated_groups) do
		local comma_separated_groups = iut.split_alternating_runs(dot_separated_group, "%s*,%s*")
		local first_element = comma_separated_groups[1][1]
		if vowel_alternants[first_element] then
			for j = 1, #comma_separated_groups do
				local alt = comma_separated_groups[j][1]
				if not vowel_alternants[alt] then
					parse_err("Unrecognized vowel alternant '" .. alt .. "'")
				end
				if base.vowelalt then
					for _, existing_alt in ipairs(base.vowelalt) do
						if existing_alt.form == alt then
							parse_err("Vowel alternant '" .. alt .. "' specified twice")
						end
					end
				else
					base.vowelalt = {}
				end
				table.insert(base.vowelalt, {form = alt, footnotes = fetch_footnotes(comma_separated_groups[j])})
			end
		elseif first_element == "no_pres_stressed" or first_element == "only3s" or first_element == "only3sp" then
			if #comma_separated_groups[1] > 1 then
				parse_err("No footnotes allowed with '" .. first_element .. "' spec")
			end
			if base[first_element] then
				parse_err("Spec '" .. first_element .. "' specified twice")
			base[first_element] = true
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
		--if base.lemma:find(" ") and not base.lemma:find("%[%[") then
		--	-- If lemma is multiword and has no links, add links automatically.
		--	base.lemma= "[[" .. base.lemma:gsub(" ", "]] [[") .. "]]"
		--end
		base.orig_lemma = base.lemma
		base.orig_lemma_no_links = m_links.remove_links(base.lemma)
		-- Normalize the linked lemma by removing dot, underscore, and <pron> and such indicators.
		base.linked_lemma = remove_reflexive_indicators(base.lemma)
		base.lemma = m_links.remove_links(base.linked_lemma)
		local lemma = base.orig_lemma_no_links
		base.pre_pref, base.post_pref = "", ""
		local refl_verb, clitic = rmatch(lemma, "^(.-)(l[aeo]s?)$")
		if not refl_verb then
			refl_verb, clitic = refl_clitic_verb, nil
		end
		local verb, refl = rmatch(refl_verb, "^(.-)(se)$")
		if not verb then
			verb, refl = refl_verb, nil
		end
		base.verb = verb
		base.refl = refl
		base.clitic = clitic
		if base.refl then
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


local function detect_indicator_spec(base)
	base.forms = {}
	base.stems = {}
	local inf_stem, suffix = rmatch(base.infinitive, "^(.*)([aeií]r)$")
	if not inf_stem then
		error("Unrecognized infinitive: " .. base.infinitive)
	end
	base.inf_stem = inf_stem
	base.conj = suffix == "ír" and "ir" or suffix
	base.frontback = suffix == "ar" and "back" or "front"

	if base.only3s and base.only3sp then
		error("'only3s' and 'only3sp' cannot both be specified")
	end

	-- Convert vowel alternation indicators into stems.
	if base.vowelalt then
		for _, alt in ipairs(base.vowelalt) do
			if base.conj == "ir" then
				local raising = alt.form == "ie-i" or alt.form == "ue-u" or alt.form == "i"
				if base.stems.raising_conj == nil then
					base.stems.raising_conj = raising
				elseif base.stems.raising_conj ~= raising then
					error("Can't currently support a mixture of raising (e.g. 'ie-i') and non-raising (e.g. 'ie') vowel alternations in -ir verbs")
				end
			end
			if alt.form == "ie-i" or alt.form == "ue-u" then
				if base.conj ~= "ir" then
					error("Vowel alternation '" .. alt.form .. "' only supported with -ir verbs")
				end
				alt.form = alt.form == "ie-i" and "ie" or "ue"
			end
			if alt.form == "+" then
				alt.form = base.inf_stem
			else
				local ret = com.apply_vowel_alternation(base.inf_stem, alt.form)
				if ret.err then
					error("To use '" .. alt.form .. "', present stem '" .. base.inf_stem .. "' " .. ret.err)
				end
				alt.form = ret.ret
			end
		end
	end
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

local basic_table = [=[
{description}
<div class="NavFrame">
<div class="NavHead" align=center>&nbsp; &nbsp; Conjugation of {title} (See [[Appendix:Spanish verbs]])</div>
<div class="NavContent">
{\op}| style="background:#F9F9F9;text-align:center;width:100%"
|-
! colspan="3" style="background:#e2e4c0" | <span title="infinitivo">infinitive</span>
| colspan="5" | {infinitive}

|-
! colspan="3" style="background:#e2e4c0" | <span title="gerundio">gerund</span>
| colspan="5" | {gerund}

|-
! rowspan="3" colspan="2" style="background:#e2e4c0" | <span title="participio (pasado)">past participle</span>
| colspan="2" style="background:#e2e4c0" |
! colspan="2" style="background:#e2e4c0" | <span title="masculino">masculine</span>
! colspan="2" style="background:#e2e4c0" | <span title="femenino">feminine</span>
|-
! colspan="2" style="background:#e2e4c0" | singular
| colspan="2" | {pp_ms}
| colspan="2" | {pp_fs}
|-
! colspan="2" style="background:#e2e4c0" | plural
| colspan="2" | {pp_mp}
| colspan="2" | {pp_fp}

|-
! colspan="2" rowspan="2" style="background:#DEDEDE" |
! colspan="3" style="background:#DEDEDE" | singular
! colspan="3" style="background:#DEDEDE" | plural

|-
! style="background:#DEDEDE" | 1st person
! style="background:#DEDEDE" | 2nd person
! style="background:#DEDEDE" | 3rd person
! style="background:#DEDEDE" | 1st person
! style="background:#DEDEDE" | 2nd person
! style="background:#DEDEDE" | 3rd person

|-
! rowspan="6" style="background:#c0cfe4" | <span title="indicativo">indicative</span>

! style="background:#ECECEC;width:12.5%" |
! style="background:#ECECEC;width:12.5%" | yo
! style="background:#ECECEC;width:12.5%" | tú<br />vos
! style="background:#ECECEC;width:12.5%" | él/ella/ello<br />usted
! style="background:#ECECEC;width:12.5%" | nosotros<br />nosotras
! style="background:#ECECEC;width:12.5%" | vosotros<br />vosotras
! style="background:#ECECEC;width:12.5%" | ellos/ellas<br />ustedes

|-
! style="height:3em;background:#ECECEC" | <span title="presente de indicativo">present</span>
| {pres_1s}
| {pres_2s}{pres_2sv_text}
| {pres_3s}
| {pres_1p}
| {pres_2p}
| {pres_3p}

|-
! style="height:3em;background:#ECECEC" | <span title="pretérito imperfecto (copréterito)">imperfect</span>
| {impf_1s}
| {impf_2s}
| {impf_3s}
| {impf_1p}
| {impf_2p}
| {impf_3p}

|-
! style="height:3em;background:#ECECEC" | <span title="pretérito perfecto simple (pretérito indefinido)">preterite</span>
| {pret_1s}
| {pret_2s}
| {pret_3s}
| {pret_1p}
| {pret_2p}
| {pret_3p}

|-
! style="height:3em;background:#ECECEC" | <span title="futuro simple (futuro imperfecto)">future</span>
| {fut_1s}
| {fut_2s}
| {fut_3s}
| {fut_1p}
| {fut_2p}
| {fut_3p}

|-
! style="height:3em;background:#ECECEC" | <span title="condicional simple (pospretérito de modo indicativo)">conditional</span>
| {cond_1s}
| {cond_2s}
| {cond_3s}
| {cond_1p}
| {cond_2p}
| {cond_3p}

|-
! style="background:#DEDEDE;height:.75em" colspan="8" |
|-
! rowspan="5" style="background:#c0e4c0" | <span title="subjuntivo">subjunctive</span>
! style="background:#ECECEC" |
! style="background:#ECECEC" | yo
! style="background:#ECECEC" | tú<br />vos
! style="background:#ECECEC" | él/ella/ello<br />usted
! style="background:#ECECEC" | nosotros<br />nosotras
! style="background:#ECECEC" | vosotros<br />vosotras
! style="background:#ECECEC" | ellos/ellas<br />ustedes

|-
! style="height:3em;background:#ECECEC" | <span title="presente de subjuntivo">present</span>
| {pres_sub_1s}
| {pres_sub_2s}{pres_sub_2sv_text}
| {pres_sub_3s}
| {pres_sub_1p}
| {pres_sub_2p}
| {pres_sub_3p}

|-
! style="height:3em;background:#ECECEC" | <span title="pretérito imperfecto de subjuntivo">imperfect</span><br />(ra)
| {impf_sub_ra_1s}
| {impf_sub_ra_2s}
| {impf_sub_ra_3s}
| {impf_sub_ra_1p}
| {impf_sub_ra_2p}
| {impf_sub_ra_3p}

|-
! style="height:3em;background:#ECECEC" | <span title="pretérito imperfecto de subjuntivo">imperfect</span><br />(se)
| {impf_sub_se_1s}
| {impf_sub_se_2s}
| {impf_sub_se_3s}
| {impf_sub_se_1p}
| {impf_sub_se_2p}
| {impf_sub_se_3p}

|-
! style="height:3em;background:#ECECEC" | <span title="futuro simple de subjuntivo (futuro de subjuntivo)">future</span><sup style="color:red">1</sup>
| {fut_sub_1s}
| {fut_sub_2s}
| {fut_sub_3s}
| {fut_sub_1p}
| {fut_sub_2p}
| {fut_sub_3p}

|-
! style="background:#DEDEDE;height:.75em" colspan="8" |
|-
! rowspan="6" style="background:#e4d4c0" | <span title="imperativo">imperative</span>
! style="background:#ECECEC" |
! style="background:#ECECEC" | —
! style="background:#ECECEC" | tú<br />vos
! style="background:#ECECEC" | usted
! style="background:#ECECEC" | nosotros<br />nosotras
! style="background:#ECECEC" | vosotros<br />vosotras
! style="background:#ECECEC" | ustedes

|-
! style="height:3em;background:#ECECEC" | <span title="imperativo afirmativo">affirmative</span>
|
| {imp_2s}{imp_2sv_text}
| {imp_3s}
| {imp_1p}
| {imp_2p}
| {imp_3p}

|-
! style="height:3em;background:#ECECEC" | <span title="imperativo negativo">negative</span>
|
| {neg_imp_2s}
| {neg_imp_3s}
| {neg_imp_1p}
| {neg_imp_2p}
| {neg_imp_3p}
|{\cl}{notes_clause}</div></div>
]=]


local combined_form_table = [=[
{description}
<div class="NavFrame">
<div class="NavHead" align=center>&nbsp; &nbsp; Selected combined forms of {title}</div>
<div class="NavContent">
These forms are generated automatically and may not actually be used. Pronoun usage varies by region.
{\op}| class="inflection-table" style="background:#F9F9F9;text-align:center;width:100%"

|-
! colspan="2" rowspan="2" style="background:#DEDEDE" |
! colspan="3" style="background:#DEDEDE" | singular
! colspan="3" style="background:#DEDEDE" | plural

|-
! style="background:#DEDEDE" | 1st person
! style="background:#DEDEDE" | 2nd person
! style="background:#DEDEDE" | 3rd person
! style="background:#DEDEDE" | 1st person
! style="background:#DEDEDE" | 2nd person
! style="background:#DEDEDE" | 3rd person

|-
! rowspan="3" style="background:#c0cfe4" | with infinitive {infinitive}

|-
! style="height:3em;background:#ECECEC" | dative
| {infinitive_comb_me}
| {infinitive_comb_te}
| {infinitive_comb_le}, {infinitive_comb_se}
| {infinitive_comb_nos}
| {infinitive_comb_os}
| {infinitive_comb_les}, {infinitive_comb_se}

|-
! style="height:3em;background:#ECECEC" | accusative
| {infinitive_comb_me}
| {infinitive_comb_te}
| {infinitive_comb_lo}, {infinitive_comb_la}, {infinitive_comb_se}
| {infinitive_comb_nos}
| {infinitive_comb_os}
| {infinitive_comb_los}, {infinitive_comb_las}, {infinitive_comb_se}

|-
! style="background:#DEDEDE;height:.35em" colspan="8" |
|-
! rowspan="3" style="background:#d0cfa4" | with gerund {gerund}

|-
! style="height:3em;background:#ECECEC" | dative
| {gerund_comb_me}
| {gerund_comb_te}
| {gerund_comb_le}, {gerund_comb_se}
| {gerund_comb_nos}
| {gerund_comb_os}
| {gerund_comb_les}, {gerund_comb_se}

|-
! style="height:3em;background:#ECECEC" | accusative
| {gerund_comb_me}
| {gerund_comb_te}
| {gerund_comb_lo}, {gerund_comb_la}, {gerund_comb_se}
| {gerund_comb_nos}
| {gerund_comb_os}
| {gerund_comb_los}, {gerund_comb_las}, {gerund_comb_se}

|-
! style="background:#DEDEDE;height:.35em" colspan="8" |
|-
! rowspan="3" style="background:#f2caa4" | with informal second-person singular imperative {imp_2s}

|-
! style="height:3em;background:#ECECEC" | dative
| {imp_2s_comb_me}
| {imp_2s_comb_te}
| {imp_2s_comb_le}
| {imp_2s_comb_nos}
| ''not used''
| {imp_2s_comb_les}

|-
! style="height:3em;background:#ECECEC" | accusative
| {imp_2s_comb_me}
| {imp_2s_comb_te}
| {imp_2s_comb_lo}, {imp_2s_comb_la}
| {imp_2s_comb_nos}
| ''not used''
| {imp_2s_comb_los}, {imp_2s_comb_las}

|-
! style="background:#DEDEDE;height:.35em" colspan="8" |
|-
! rowspan="3" style="background:#f2caa4" | with formal second-person singular imperative {imp_3s}

|-
! style="height:3em;background:#ECECEC" | dative
| {imp_3s_comb_me}
| ''not used''
| {imp_3s_comb_le}, {imp_3s_comb_se}
| {imp_3s_comb_nos}
| ''not used''
| {imp_3s_comb_les}

|-
! style="height:3em;background:#ECECEC" | accusative
| {imp_3s_comb_me}
| ''not used''
| {imp_3s_comb_lo}, {imp_3s_comb_la}, {imp_3s_comb_se}
| {imp_3s_comb_nos}
| ''not used''
| {imp_3s_comb_los}, {imp_3s_comb_las}

|-
! style="background:#DEDEDE;height:.35em" colspan="8" |
|-
! rowspan="3" style="background:#f2caa4" | with first-person plural imperative {imp_1p}

|-
! style="height:3em;background:#ECECEC" | dative
| ''not used''
| {imp_1p_comb_te}
| {imp_1p_comb_le}
| {imp_1p_comb_nos}
| {imp_1p_comb_os}
| {imp_1p_comb_les}

|-
! style="height:3em;background:#ECECEC" | accusative
| ''not used''
| {imp_1p_comb_te}
| {imp_1p_comb_lo}, {imp_1p_comb_la}
| {imp_1p_comb_nos}
| {imp_1p_comb_os}
| {imp_1p_comb_los}, {imp_1p_comb_las}

|-
! style="background:#DEDEDE;height:.35em" colspan="8" |
|-
! rowspan="3" style="background:#f2caa4" | with informal second-person plural imperative {imp_2p}

|-
! style="height:3em;background:#ECECEC" | dative
| {imp_2p_comb_me}
| ''not used''
| {imp_2p_comb_le}
| {imp_2p_comb_nos}
| {imp_2p_comb_os}
| {imp_2p_comb_les}

|-
! style="height:3em;background:#ECECEC" | accusative
| {imp_2p_comb_me}
| ''not used''
| {imp_2p_comb_lo}, {imp_2p_comb_la}
| {imp_2p_comb_nos}
| {imp_2p_comb_os}
| {imp_2p_comb_los}, {imp_2p_comb_las}

|-
! style="background:#DEDEDE;height:.35em" colspan="8" |
|-
! rowspan="3" style="background:#f2caa4" | with formal second-person plural imperative {imp_3p}

|-
! style="height:3em;background:#ECECEC" | dative
| {imp_3p_comb_me}
| ''not used''
| {imp_3p_comb_le}
| {imp_3p_comb_nos}
| ''not used''
| {imp_3p_comb_les}, {imp_3p_comb_se}

|-
! style="height:3em;background:#ECECEC" | accusative
| {imp_3p_comb_me}
| ''not used''
| {imp_3p_comb_lo}, {imp_3p_comb_la}
| {imp_3p_comb_nos}
| ''not used''
| {imp_3p_comb_los}, {imp_3p_comb_las}, {imp_3p_comb_se}
|{\cl}{notes_clause}</div></div>
]=]


local combined_form_reflexive_table = [=[
{description}
<div class="NavFrame">
<div class="NavHead" align=center>&nbsp; &nbsp; Selected combined forms of {title}</div>
<div class="NavContent">
{| class="inflection-table" style="background:#F9F9F9;text-align:center;width:100%"

|-
! colspan="2" rowspan="2" style="background:#DEDEDE" |
! colspan="3" style="background:#DEDEDE" | singular
! colspan="3" style="background:#DEDEDE" | plural

|-
! style="background:#DEDEDE" | 1st person
! style="background:#DEDEDE" | 2nd person
! style="background:#DEDEDE" | 3rd person
! style="background:#DEDEDE" | 1st person
! style="background:#DEDEDE" | 2nd person
! style="background:#DEDEDE" | 3rd person

|-
! rowspan="2" style="background:#c0cfe4" | Infinitives

|-
! style="height:3em;background:#ECECEC" | accusative
| {infinitive_comb_me}
| {infinitive_comb_te}
| {infinitive_comb_se}
| {infinitive_comb_nos}
| {infinitive_comb_os}
| {infinitive_comb_se}

|-
! style="background:#DEDEDE;height:.35em" colspan="8" |
|-
! rowspan="2" style="background:#d0cfa4" | gerunds

|-
! style="height:3em;background:#ECECEC" | accusative
| {gerund_comb_me}
| {gerund_comb_te}
| {gerund_comb_se}
| {gerund_comb_nos}
| {gerund_comb_os}
| {gerund_comb_se}

|-
! style="background:#DEDEDE;height:.35em" colspan="8" |
|-
! rowspan="2" style="background:#f2caa4" | with positive imperatives

|-
! style="height:3em;background:#ECECEC" | accusative
| ''not used''
| {imp_2s_comb_te}
| {imp_3s_comb_se}
| {imp_1p_comb_nos}
| {imp_2p_comb_os}
| {imp_3p_comb_se}
|{\cl}{notes_clause}</div></div>
]=]


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
