local export = {}


--[=[

Authorship: Ben Wing <benwing2>

]=]

--[=[

TERMINOLOGY:

-- "slot" = A particular combination of tense/mood/person/number/etc.
	 Example slot names for verbs are "pres_1s" (present indicative first-person singular), "pres_sub_2sv" (present
	 subjunctive second-person singular voseo form) "impf_sub_ra_3p" (imperfect subjunctive -ra form third-person
	 plural), "imp_1p_comb_lo" (imperative first-person plural combined with clitic [[lo]]).
	 Each slot is filled with zero or more forms.

-- "form" = The conjugated Spanish form representing the value of a given slot.

-- "lemma" = The dictionary form of a given Spanish term. For Spanish, always the infinitive.
]=]

--[=[

FIXME:

1. Implement no_pres_stressed for aterir, garantir. (NOTE: Per RAE, garantir used in all forms in Argentina/Uruguay.) [DONE]
2. Support concluyo. [DONE]
3. Fixes for veo -> ve vs. preveo -> prevé. [DONE]
4. Various more irregular verbs, e.g. predecir, redecir, bendecir, maldecir. [DONE]
5. Raising of e -> i, o -> u before -iendo, -ió, etc. occurs only in -ir verbs. [DONE]
6. Raising of e -> i, o -> u happens before subjunctive -amos, -áis in -ir verbs. [DONE]
7. Implement reflexive verbs. [DONE]
8. Implement categories. [DONE]
9. Implement show_forms. [DONE]
10. Reconcile stems.vowel_alt from irregular verbs with vowel_alt from indicators. May require
    moving the irregular-verb handling code in construct_stems() into detect_indicator_spec(). [DONE]
11. Implement make_table. [DONE]
12. Vowel alternation should show u-ue (jugar), i-ie (adquirir), e-í (reír) alternations specially. [DONE]
13. Handle linking of multiword forms as is done in [[Module:es-headword]]. [DONE]
14. Implement comparison against previous module. [DONE]
15. Implement categorization of irregularities for individual tenses.
16. Support nocomb=1. [DONE]
17. (Possibly) display irregular forms in a different color, as with the old module.
18. (Possibly) display a "rule" description indicating the types of alternations.
19. Implement replace_reflexive_indicators().
20. Implement verbs with attached clitics e.g. [[pasarlo]], [[corrérsela]]. [DONE]
21. When footnote + tú/vos notation, add a space before tú/vos.
22. Fix [[erguir]] so ie-i vowel alternation produces ye- at beginning of word, similarly for errar. Also allow
    multiple vowel alternation specs in irregular verbs, for errar. Finally, ie should show as e-ye for errar
    and as e-ye-i for erguir. [DONE]
23. Figure out why red links in combined forms show up as black not red.
24. Consider including alternative superseded forms of verbs like [[ciar]] (e.g. pret_3s = cio, ció with footnote).
25. Allow conjugation of suffixes e.g. -ir, -ecer; need to fix in [[Module:inflection utilities]]. [DONE]
26. Allow specification of stems esp. so that footnotes can be hung off them; use + for the default.
27. Don't remove monosyllabic accents when conjugating suffixes. [DONE]
28. If multiword expression with no <>, add <> after first word, as with [[Module:es-headword]]. [DONE]
29. (Possibly) link the parts of a reflexive or cliticized infinitive, as done in [[Module:es-headword]]. [DONE]
30. Final fixes to allow [[Module:es-headword]] to use this module. [DONE]
--]=]

local lang = require("Module:languages").getByCode("es")
local m_string_utilities = require("Module:string utilities")
local m_links = require("Module:links")
local m_table = require("Module:table")
local iut = require("Module:inflection utilities")
local com = require("Module:es-common")

local force_cat = false -- set to true for debugging
local check_for_red_links = false -- set to false for debugging

local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local rsub = com.rsub

local function link_term(term)
	return m_links.full_link({ lang = lang, term = term }, "term")
end


local V = com.V -- vowel regex class
local AV = com.AV -- accented vowel regex class
local C = com.C -- consonant regex class


local fut_sub_note = "[mostly obsolete, now mainly used in legal language]"
local pres_sub_voseo_note = "[Argentine and Uruguayan " .. link_term("voseo") .. " prefers the " ..
	link_term("tú") .. " form for the present subjunctive]"

local vowel_alternants = m_table.listToSet({"ie", "ie-i", "ye", "ye-i", "ue", "ue-u", "hue", "i", "í", "ú", "+"})
local vowel_alternant_to_desc = {
	["ie"] = "e-ie",
	["ie-i"] = "e-ie-i",
	["ye"] = "e-ye",
	["ye-i"] = "e-ye-i",
	["ue"] = "o-ue",
	["ue-u"] = "o-ue-u",
	["hue"] = "o-hue",
	["i"] = "e-i",
	["í"] = "i-í",
	["ú"] = "u-ú",
}

local raise_vowel = {["e"] = "i", ["o"] = "u"}

local all_persons_numbers = {
	["1s"] = "1|s",
	["2s"] = "2|s",
	["2sv"] = "2|s|voseo",
	["3s"] = "3|s",
	["1p"] = "1|p",
	["2p"] = "2|p",
	["3p"] = "3|p",
}

local person_number_list_basic = { "1s", "2s", "3s", "1p", "2p", "3p", }
local person_number_list_voseo = { "1s", "2s", "2sv", "3s", "1p", "2p", "3p", }
-- local persnum_to_index = {}
-- for k, v in pairs(person_number_list) do
-- 	persnum_to_index[v] = k
-- end
local imp_person_number_list = { "2s", "2p", }

person_number_to_reflexive_pronoun = {
	["1s"] = "me",
	["2s"] = "te",
	["2sv"] = "te",
	["3s"] = "se",
	["1p"] = "nos",
	["2p"] = "os",
	["3p"] = "se",
}


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

-- Accelerators for use in {{es-verb form of}} when we set the accelerator in all_verb_slots to "-".
export.overriding_slot_accel = {}

-- Add entries for a slot with person/number variants.
-- `verb_slots` is the table to add to.
-- `slot_prefix` is the prefix of the slot, typically specifying the tense/aspect.
-- `tag_suffix` is the set of inflection tags to add after the person/number tags.
-- `no_accel` indicates that no accelerator entry should be generated.
local function add_slot_personal(verb_slots, slot_prefix, tag_suffix, person_number_list, no_accel)
	for _, persnum in ipairs(person_number_list) do
		local persnum_tag = all_persons_numbers[persnum]
		local slot = slot_prefix .. "_" .. persnum
		local accel = persnum_tag .. "|" .. tag_suffix
		if no_accel then
			table.insert(verb_slots, {slot, "-"})
			export.overriding_slot_accel[slot] = accel
		else
			table.insert(verb_slots, {slot, accel})
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
add_slot_personal(verb_slots_basic, "neg_imp", "neg|imp", {"2s", "3s", "1p", "2p", "3p"}, "no accel")

local function add_combined_slot(basic_slot, slot_prefix, pronouns)
	for _, pronoun in ipairs(pronouns) do
		local slot = basic_slot .. "_comb_" .. pronoun
		-- You have to pass this through full_link() to get a Spanish-specific link
		local accel = slot_prefix .. "|combined with [[" .. pronoun .. "]]"
		table.insert(verb_slots_combined, {slot, accel})
	end
	table.insert(verb_slot_combined_rows, {basic_slot, pronouns})
end

add_combined_slot("infinitive", "inf", {"me", "te", "se", "nos", "os", "lo", "la", "le", "los", "las", "les"})
add_combined_slot("gerund", "gerund", {"me", "te", "se", "nos", "os", "lo", "la", "le", "los", "las", "les"})
add_combined_slot("imp_2s", "2s|imp", {"me", "te", "nos", "lo", "la", "le", "los", "las", "les"})
add_combined_slot("imp_3s", "3s|imp", {"me", "se", "nos", "lo", "la", "le", "los", "las", "les"})
add_combined_slot("imp_1p", "1p|imp", {"te", "nos", "os", "lo", "la", "le", "los", "las", "les"})
add_combined_slot("imp_2p", "2p|imp", {"me", "nos", "os", "lo", "la", "le", "los", "las", "les"})
add_combined_slot("imp_3p", "3p|imp", {"me", "se", "nos", "lo", "la", "le", "los", "las", "les"})

export.all_verb_slots = {}
for _, slot_and_accel in ipairs(verb_slots_basic) do
	table.insert(export.all_verb_slots, slot_and_accel)
end
for _, slot_and_accel in ipairs(verb_slots_combined) do
	table.insert(export.all_verb_slots, slot_and_accel)
end

local verb_slots_basic_map = {}
for _, slotaccel in ipairs(verb_slots_basic) do
	local slot, accel = unpack(slotaccel)
	verb_slots_basic_map[slot] = accel
end

local verb_slots_combined_map = {}
for _, slotaccel in ipairs(verb_slots_combined) do
	local slot, accel = unpack(slotaccel)
	verb_slots_combined_map[slot] = accel
end

local function match_against_verbs(ref_verb, prefixes)
	return function(verb)
		for _, prefix in ipairs(prefixes) do
			if verb == prefix .. ref_verb then
				return prefix, ref_verb
			end
		end
		return nil
	end
end


--[=[

Special cases for verbs:

diluviar, atardecer: impersonal; all finite non-3s forms are nonexistent or hypothetical. Handle using
'.only3s'.

empecer, atañer, concernir: all finite non-third-person forms are nonexistent or hypothetical. Handle using '.only3sp'.

desnacer: Former module claimed an irregular past participle 'desnato'. Verb is not in RAE at all and barely exists;
unlikely to have irregular past participle.

desposeer: Former module claimed an irregular past participle 'desposeso'. Not per RAE.

valer: Former module claimed an irregular imperative 'val'. Not per RAE.

manumitir: Former module claimed an irregular past participle 'manumiso'. Not per RAE.

raer: Former module claimed a pres 1sg rao. Not per RAE.

rehuir: Handle using +ú.

sustituir: Former module claimed an irregular past participle 'sustituto'. Not per RAE.

venir: Former module claimed an irregular clitic combination ven + nos -> venos. Not per native speakers.


---------


Verbs to check: rehuir (+ú), prohibir (+í), reunir (+ú)


---------


-ir verbs:

There are several types of vowel alternations:

1. No alternation. Includes some verbs in -e- and -o-, e.g. aterir(se) (no_pres_stressed), tra(n)sgredir
   (pres_stressed forms rare), abolir (pres_stressed forms rare), colorir (no_pres_stressed), sumergir, divergir,
   convergir, arrecir (no_pres_stressed), rostir, polir (obsolete), condir (obsolete), possibly ascondir (obsolete),
   atordir (obsolete), sacodir (obsolete), sobrevendir (possible misspelling), empedernir (no_pres_stressed),
   decebir (obsolete; possibly actually like concebir, i.e. decibo not decebo),
   premir (obsolete), expremir (obsolete), exir (obsolete), escreuir (obsolete; fix conjugation), escrebir (obsolete),
   agredir; sometimes the stressed forms are rare or disused. (Also embaír, desvaír are no_pres_stressed.)
2a. ie: Infinitive has -e-, changing to -ie- when stressed. No raising before i+V. Only hendir, cernir, discernir,
   concernir (only3sp); discernir -> discierno, discerniendo, discernió, discernamos.
2b. ye: Infinitive has -e-, changing to -ye- when stressed. No raising before i+V. Does not occur (cf. errar).
3a. ie-i: Infinitive has -e- or -i-, changing to -ie- when stressed. Raising before i+V and 1p/2p pres subjunctive:
   sentir -> siento, sintiendo, sintió, sintamos.
   adquirir -> adquiero, adquiriendo, adquirió, adquiramos.
3b. ye-i: Infinitive has -e-, changing to -ye- when stressed. Raising before i+V and 1p/2p pres subjunctive.
   Only erguir: erguir -> yergo, irguiendo, irguió, irgamos.
4. i: Infinitive has -e-, changing to -i- when stressed. Raising before i+V and 1p/2p pres subjunctive:
   vestir -> visto, vistiendo, vistió, vistamos. Variant: ceñir -> ciño, ciñendo, ciñó, ciñamos.
   NOTE: preterir (no_pres_stressed).
5. ue-u: Infinitive has -o-, changing to -ue- when stressed. Raising before i+V and 1p/2p pres subjunctive:
   Only dormir, morir and compounds. dormir -> duermo, durmiendo, durmió, durmamos.
6. ue: This type would be parallel to 'ie' but doesn't appear to exist.


---------


Verbs to fix (extra forms need to be excised or deleted): The above verbs under type (1) -ir vowel alternations;
[[neviscar]] (impersonal), [[acaecer]] (third-person only), [[acontecer]] (third-person only),
[[cellisquear]] (impersonal), [[pintear]] (impersonal? other meaning "to play hookey" given, not in RAE),
[[diluviar]] (impersonal). [[desabrir]] (not like abrir, rare in pres_stressed/sub forms), [[jabrir]]
(not like abrir).

Verbs with existing errors:
* [[abeldar]]: (missing <ie>) [FORMS TO DELETE]
* [[acaecer]]: (used only in 3rd person) [DELETE ALL FIRST AND SECOND PERSON FORMS]
* [[acontecer]]: (used only in 3rd person) [DELETE ALL FIRST AND SECOND PERSON FORMS]
* [[anticuar]] (conjugated without ú) [FORMS TO DELETE]
* [[antojar]]: (used only in 3rd person) [DELETE ALL FIRST AND SECOND PERSON FORMS]
* [[aerografiar]]: (conjugated without í) [FORMS TO DELETE]
* [[afiliar]]: (conjugated with í/+ should be only +) [FORMS TO DELETE]
* [[agraviar]]: (wrongly has í) [FORMS TO DELETE]
* [[arrecir]]: (not given as no_pres_stressed) [FORMS TO DELETE]
* [[aserrar]]: (missing <ie>) [FORMS TO DELETE]
* [[aspaventar]]: (missing <ie>) [OK]
* [[atesar]]: (wrongly has ie) [FORMS TO DELETE]
* [[avalentar]]: (wrongly has ie) [FORMS TO DELETE]
* [[autorregularse]] (conjugated as non-reflexive) [OK]
* [[auxiliar]]: (conjugated with í/+ should be only +) [FORMS TO DELETE]
* [[balbucir]] (pres1_and_sub nonexistent) [DELETE PRES1_AND_SUB FORMS]
* [[caçar]] (conjugated as -zar) [OK]
* [[calefacer]] (extra form caleface) [FIX]
* [[cellisquear]]: (used only in 3rd person singular) [DELETE ALL FIRST AND SECOND PERSON FORMS, ALL 3RD PLURAL FORMS AND ALL PP NON-MS FORMS]
* [[chilenizar]] (conjugated with no cons alternation) [OK]
* [[colorir]]: (not given as no_pres_stressed) [FORMS TO DELETE]
* [[comisariar]] (conjugated without í) [FORMS TO DELETE]
* [[complacer]] (missing complega in imperative 3s) [OK]
* [[comprehender]] (conjugated as comprender) [OK]
* [[decebir]] (was conjugated without <i>) [FORMS TO DELETE]
* [[desafiliar]]: (conjugated with í/+ should be only +) [FORMS TO DELETE]
* [[desagregar]] (conjugated with no cons alternation) [FORMS TO DELETE]
* [[desairar]]: (conjugated with í should be only +) [FORMS TO DELETE]
* [[descordar]]: (missing <ue>) [FORMS TO DELETE]
* [[deseleccionar]] (conjugated as desseleccionar) [OK]
* [[desestacionalizar]] (conjugated with no cons alternation) [FORMS TO DELETE]
* [[desgonzar]] (conjugated with no cons alternation) [FORMS TO DELETE]
* [[desguinzar]] (conjugated with no cons alternation) [FORMS TO DELETE]
* [[deshacer]] (extra form deshace, desháceme etc.) [OK]
* [[desnacer]] (extra form desnato etc.) [DELETE PP FORMS]
* [[desposeer]] (extra form desposeso etc.) [DELETE PP FORMS]
* [[dezmar]]: (wrongly has ie) [FORMS TO DELETE]
* [[diluviar]]: (used only in 3rd person singular) [DELETE ALL FIRST AND SECOND PERSON FORMS, ALL 3RD PLURAL FORMS AND ALL PP NON-MS FORMS]
* [[draftear]] (extraneous param lang=es) [REMOVE PARAM]
* [[ejemplarizar]] (extraneous param compound=1) [compound -> combined]
* [[ejercitar]] (extraneous param compound=1) [compound -> combined]
* [[empecer]] (empezca has imperatives, 1s in its verb form entry) [FIX]
* [[encentar]]: (wrongly has ie) [OK]
* [[encubertar]]: (wrongly has ie) [FORMS TO DELETE]
* [[entrechocar]] (conjugated with no cons alternation) [FORMS TO DELETE]
* [[entredecir]] (imp_2s has entredice should be entredí; extra future/cond forms entredeciré etc.) [FORMS TO DELETE/FIX]
* [[escenografiar]]: (conjugated without í) [FORMS TO DELETE]
* [[estar]] (incorrect combined forms, e.g. éstela instead of estela) [OK]
* [[extasiar]]: (conjugated with í/+ should be only í) [FORMS TO DELETE]
* [[facer]] (extra form face, fáceme, etc.) [FIX]
* [[ferrar]]: (missing <ie>) [FORMS TO DELETE]
* [[gloriar]]: (conjugated with í/+ should be only í) [FORMS TO DELETE]
* [[hacer]] (extra form hace, háceme, etc.) [DELETE hácete]
* [[homogeneizar]] (extra form homogeneízo) [DELETE homogeneízo, homogeneízas, homogeneíza, homogeneízan, homogeneícen, homogeneícemos]
* [[incensar]]: (missing <ie>) [FORMS TO DELETE]
* [[ir]] (extraneous param aux=ser) [REMOVE PARAM]
* [[jacer]] (extra form jace, jáceme, etc.) [FIX]
* [[jarrear]] (extraneous param impersonal=yes)
* [[litografiar]]: (conjugated without í) [FORMS TO DELETE]
* [[manumitir]] (extra form manumiso, etc.) [FIX; is an adjective]
* [[mecanografiar]]: (conjugated without í) [FORMS TO DELETE]
* [[mordiscar]] (conjugated with no cons alternation) [FORMS TO DELETE]
* [[neviscar]]: (used only in 3rd person singular) [DELETE ALL FIRST AND SECOND PERSON FORMS, ALL 3RD PLURAL FORMS AND ALL PP NON-MS FORMS]
* [[obsipar]] (conjugated as obispar) [DELETE VERB]
* [[obstar]]: (used only in 3rd person) [DELETE ALL FIRST AND SECOND PERSON FORMS]
* [[orificar]] (conjugated as orificiar) [OK]
* [[complacer]], [[placer]] (missing plega in imperative 3s, etc.) [OK]
* [[prevaler]] (extra form preval, incorrect form prévalme etc.) [DELETE preval]
* [[preterir]]: (not given as no_pres_stressed) [FORMS TO DELETE]
* [[raer]] (extra form rao) [DELETE rao]
* [[rebordar]] (extraneous param lang=es) [REMOVE PARAM]
* [[redecir]] (incorrect imp_2s redice instead of redí) [FIX]
* [[reinstitucionalizar]] (conjugated with no cons alternation) [FORMS TO DELETE]
* [[reirse]] [DELETE]
* [[serigrafiar]]: (conjugated without í) [FORMS TO DELETE]
* [[sobresalir]] (incorrect combined forms e.g. sobrésalme) [OK]
* [[superpoblar]] (missing <ue>) [FORMS TO DELETE]
* [[sustituir]] (extra form sustituto, etc.) [OK]
* [[usucapir]]: (used only in inf and pp) [DELETE ALL FORMS BUT PP]
* [[valefacer]] (extra form valeface) [FIX]
* [[valer]] (extra form val, etc.) [OK]

* LOTS OF COMBINED FORMS OF VERBS IN -iar, -uar, -ai-, -au-, -ei-, -eu-, etc.
Example: afeitar (afeítate, afeítese, afeítense). Need a script to find them.

* [[acostar]]: normally <ue> but in meaning "arrive at the coast", <>
* [[adecuar]]: <+,ú>
* [[aerografiar]]: <í>
* [[aferrar]]: <+,ie[obsolete]>
* [[afiliar]]: <>
* [[aforar]]: in meaning "to gauge, to measure": <>; in meaning "otorgar fuero": <ue>
* [[arrecir]]: <no_pres_stressed>
* [[agraviar]]: <>
* [[agriar]]: <í,+>
* [[aserrar]]: <ie>
* [[asolar]]: in meaning "destroy": <ue,+>; in meaning "to dry up": <>
* [[aspaventar]]: <ie>
* [[atentar]]: in meaning "to commit a crime" does not have vowel alt
* [[atesar]]: <>; possibly <ie> in obsolete meaning "atiesar"
* [[atestar]]: in meaning "to pack": <ie,+>; in meaning "testify": <>
* [[autoevacuarse]]: <+,ú>
* [[auxiliar]]: <>
* [[avalentar]]: <>
* [[cimentar]]: <ie,+>
* [[colar]]: most meanings <ue> but "canonically confer (an ecclesiastical benefit)" <>
* [[colorir]]: <no_pres_stressed>
* [[comisariar]]: <í>
* [[desafiliar]]: <>
* [[desaforar]]: "to deprive of fuero": <ue,+[less common]>
* [[desairar]]: <>
* [[desolar]]: <ue,+>
* [[desmembrar]]: <ie,+>
* [[dezmar]]: <>
* [[ejecutoriar]]: <í,+>
* [[emparentar]]: <ie,+>
* [[encentar]]: <>
* [[encubertar]]: <>
* [[engrosar]]: <ue,+>
* [[escenografiar]]: <í>
* [[evacuar]]: <+,ú>
* [[expatriar]]: <í,+>
* [[extasiar]]: <í>
* [[ferrar]]: <ie>
* [[follar]]: <ue>
* [[gloriar]]: <í>
* [[hibernar]]: no vowel alt or e-ie; e-ie not in RAE, ask about it
* [[historiar]]: <í,+>
* [[incensar]]: <ie>
* [[invernar]]: <ie,+>
* [[licuar]]: <+,ú>
* [[litografiar]]: <í>
* [[mecanografiar]]: <í>
* [[paliar]]: <í,+>
* [[preterir]]: <i.no_pres_stressed>
* [[promiscuar]]: <+,ú>
* [[readecuar]]: <+,ú>
* [[repatriar]]: <í,+>
* [[retrocar]]: <ue,+>
* [[serigrafiar]]: <í>
* [[soterrar]]: <ie,+>
* [[superpoblar]]: <ue>
* [[templar]]: <+,ie[in some parts of Latin America]>
* [[vidriar]]: <í,+>

Second round of verbs to fix:

* [[apropriar]]: forms point to reflexive [FORMS TO FIX]
* [[autogobernarse]]: (missing <ie>) [FORMS TO DELETE]
* [[autorreproducirse]]: (wrongly had regular preterite and impf/fut sub) [FORMS TO DELETE]
* [[aventarse]]: (missing <ie>) [FORMS TO DELETE]
* [[aventar]]: forms point to reflexive [FORMS TO FIX]
* [[culiar]]: yo culio or culío? [VERIFY]
* [[desnacer]]: delete [[dasnatos]]
* [[poseer]]: delete [[posesa]], [[posesos]], [[posesas]]
* [[reproducir]]: (wrongly had regular preterite and impf/fut sub) [FORMS TO DELETE]
* [[trasgredir]]: (wrongly had <i>) [FORMS TO DELETE]

---------


Irregular conjugations.

Each entry is processed in turn and consists of an object with two fields:
1. match=: Specifies the irregular verbs that match this object.
2. forms=: Specifies the irregular stems and forms for these verbs.

The value of match= is either a string beginning with "^" (match only the specified verb), a string not beginning
with "^" (match any verb ending in that string), or a function that is passed in the verb and should return the
prefix of the verb if it matches, otherwise nil. The function match_against_verbs() is provided to facilitate matching
a set of verbs with a common ending and specific prefixes (e.g. [[andar]] and [[desandar]] but not [[mandar]], etc.).

The value of forms= is a table specifying stems and individual override forms. Each key of the table names either a
stem (e.g. `pres_stressed`), a stem property (e.g. `vowel_alt`) or an individual override form (e.g. `pres_1s`).
Each value of a stem can either be a string (a single stem), a list of strings, or a list of objects of the form
{form = STEM, footnotes = {FOONOTES}}. Each value of an individual override should be of exactly the same form except
that the strings specify full forms rather than stems. The values of a stem property depend on the specific property
but are generally strings or booleans.

In order to understand how the stem specifications work, it's important to understand the phonetic modifications done
by combine_stem_ending(). In general, the complexities of predictable stem and ending modifications are all handled
in this function. In particular:

1. Spelling-based modifications (c/z, g/gu, gu/gü, g/j) occur automatically as appropriate for the ending.
2. Raising of e -> i, o -> u in -ir verbs before an ending beginning with i + vowel, as well as in the 1p/2p forms of
   the present subjunctive (dormir -> durmiendo, durmió, durmamos), are handled here. Raising happens only for -ir
   verbs and only when the stem setting `raising_conj` is true (which is normally set to true when vowel alternations
   `ie-i`, `ye-i`, `ue-u`, `i`, `í` or `ú` are specified).
3. Numerous modifications are automatically made before an ending beginning with i + vowel. These include:
   a. final -i of stem absorbed: sonreír -> sonrió, sonriera, sonriendo;
   b. in the preterite of irregular verbs (likewise for other tenses derived from the preterite stem, i.e. imperfect
      and and future subjunctive), initial i absorbed after j and u (dijeron not #dijieron, likewise for condujeron,
	  trajeron; also fueron not #fuyeron). This happens only when stem setting `pret_conj` == "irreg"; this must be set
	  explicitly by irregular verbs. Does not apply everywhere because of cases like regular [[tejer]] (tejieron not
	  #tejeron), regular [[concluir]] (concluyeron not #conclueron).
   c. initial i of ending -> y after vowel and word-initially: poseer -> poseyó, poseyera, poseyendo; ir -> yendo;
   d. initial i of ending -> y after gü, which becomes gu: argüir -> arguyó, arguyera, arguyendo;
   e. initial i of ending absorbed after ñ, ll, y: tañer -> tañó, tañera, tañendo; bullir -> bulló, bullera, bullendo
4. If the ending begins with (h)i, it gets an accent after a/e/i/o to prevent the two merging into a diphthong:
   caer -> caíste, caímos; reír -> reíste, reímos (pres and pret). This does not apply after u, e.g.
   concluir -> concluiste, concluimos.
5. In -uir verbs (i.e. -ir verbs with stem ending in -u), a y is added before endings beginning with a/e/o:
   concluir -> concluyo, concluyen, concluya, concluyamos. Note that preterite concluyó, gerund concluyendo, etc.
   are handled by a different rule above (3b).

The following stems are recognized:

-- pres_unstressed: The present indicative unstressed stem (2s voseo, 1p, 2p). Also controls the imperative 2p
     and gerund. Defaults to the infinitive stem.
-- pres_stressed: The present indicative stressed stem (1s, 2s, 3s, 3p). Also controls the imperative 2s.
     Default is empty if indicator `no_pres_stressed`, else a vowel alternation if such an indicator is given
	 (e.g. `ue`, `ì`), else the infinitive stem.
-- pres1_and_sub: Overriding stem for 1s present indicative and the entire subjunctive. Only set by irregular verbs
     and by the indicator `no_pres_stressed` (since verbs of this sort, e.g. [[aterir]], are missing the entire
	 subjunctive as well as the forms with stressed root). Used by many irregular verbs, e.g. [[caer]], [[roer]],
	 [[salir]], [[tener]], [[valer]], [[venir]], etc. Some verbs set this and then supply an override for the pres_1sg
	 if it's irregular, e.g. [[saber]], with irregular subjunctive stem "sep-" and special 1s present indicative "sé*"
	 (the * indicates that the monosyllabic accent should not be removed).
-- pres1: Special stem for 1s present indicative. Normally, do not set this explicitly. If you need to specify an
     irregular 1s present indicative, use the form override pres_1s= to specify the entire form. Defaults to
	 pres1_and_sub if given, else pres_stressed.
-- pres_sub_unstressed: The present subjunctive unstressed stem (1p, 2p, also 2s voseo for -ar verbs). Defaults to
     pres1_and_sub if given, else the infinitive stem.
-- pres_sub_stressed: The present subjunctive stressed stem (1s, 2s, 3s, 1p, also 2s voseo for -er/-ir verbs). Defaults
     to pres1.
-- impf: The imperfect stem. Defaults to the infinitive stem.
-- pret: The preterite stem. Defaults to the infinitive stem.
-- pret_conj: Determines the set of endings used in the preterite. Should be one of "ar", "er", "ir" or "irreg".
     Defaults to the conjugation as determined from the infinitive.
-- fut: The future stem. Defaults to the infinitive stem.
-- cond: The conditional stem. Defaults to fut.
-- impf_sub_ra: The imperfect subjunctive -ra stem. Defaults to the preterite stem.
-- impf_sub_se: The imperfect subjunctive -se stem. Defaults to the preterite stem.
-- fut_sub: The future subjunctive stem. Defaults to the preterite stem.
-- pp: The past participle stem. Default is based on the verb conjugation: infinitive stem + "ad" for -ar verbs,
     otherwise infinitive stem + "id".
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
		-- use 'asgu' because we're in a front environment; if we use 'asg', we'll get '#asjo'
		forms = {pres1_and_sub = "asgu"}
	},
	{
		-- abrir, cubrir and compounds
		match = function(verb)
			local prefix, base_verb = rmatch(verb, "^(.*)(brir)$")
			-- Only match abrir, cubrir and compounds, and don't match desabrir/jabrir
			if not prefix then
				return nil
			elseif not prefix:find("a$") and not prefix:find("cu$") then
				return nil
			elseif prefix == "desa" or prefix == "ja" then
				return nil
			else
				return prefix, base_verb
			end
		end,
		forms = {pp = "biert"}
	},
	{
		match = "caber",
		forms = {pres1_and_sub = "quep", pret = "cup", pret_conj = "irreg", fut = "cabr"}
	},
	{
		-- caer, decaer, descaer, recaer
		match = "caer",
		-- use 'caigu' because we're in a front environment; if we use 'caig', we'll get '#caijo'
		forms = {pres1_and_sub = "caigu"}
	},
	{
		-- cocer, escocer, precocer, etc.
		match = "cocer",
		-- override cons_alt, otherwise the verb would be categorized as a c-zc alternating verb
		forms = {vowel_alt = "ue", pres1 = "cuez", pres_sub_unstressed = "coz", cons_alt = "c-z"}, -- not cozco, as would normally be generated
	},
	{
		-- dar, desdar
		match = match_against_verbs("dar", {"", "des"}),
		forms = {
			-- we need to override various present indicative forms and add an accent for the compounds;
			-- not needed for the simplex and in fact the accents will be removed in that case
			pres_1s = "doy",
			pres_2s = "dás",
			pres_3s = "dá",
			pres_2p = "dáis",
			pres_3p = "dán",
			pret = "d", pret_conj = "er",
			pres_sub_1s = "dé*",  -- * signals that the monosyllabic accent must remain
			pres_sub_2s = "dés",
			pres_sub_3s = "dé*",
			pres_sub_2p = "déis",
			pres_sub_3p = "dén",
			imp_2s = "dá",
		}
	},
	{
		-- decir, redecir, entredecir
		match = match_against_verbs("decir", {"", "re", "entre"}),
		forms = {
			-- for this and variant verbs in -decir, we set cons_alt to false because we don't want the
			-- verb categorized as a c-zc alternating verb, which would happen by default
			-- use 'digu' because we're in a front environment; if we use 'dig', we'll get '#dijo'
			pres1_and_sub = "digu", vowel_alt = "i", cons_alt = false, pret = "dij", pret_conj = "irreg",
			pp = "dich", fut = "dir",
			imp_2s = "dí" -- need the accent for the compounds; it will be removed in the simplex
		}
	},
	{
		-- antedecir, interdecir
		match = match_against_verbs("decir", {"ante", "inter"}),
		forms = {
			pres1_and_sub = "digu", vowel_alt = "i", cons_alt = false, pret = "dij", pret_conj = "irreg",
			pp = "dich", fut = "dir" -- imp_2s regular
		}
	},
	{
		-- bendecir, maldecir
		match = match_against_verbs("decir", {"ben", "mal"}),
		forms = {
			pres1_and_sub = "digu", vowel_alt = "i", cons_alt = false, pret = "dij", pret_conj = "irreg",
			pp = {"decid", "dit"} -- imp_2s regular, fut regular
		}
	},
	{
		-- condecir, contradecir, desdecir, predecir, others?
		match = "decir",
		forms = {
			pres1_and_sub = "digu", vowel_alt = "i", cons_alt = false, pret = "dij", pret_conj = "irreg",
			pp = "dich", fut = {"decir", "dir"} -- imp_2s regular
		}
	},
	{
		-- conducir, producir, reducir, traducir, etc.
		match = "ducir",
		forms = {pret = "duj", pret_conj = "irreg"}
	},
	{
		-- elegir, reelegir; not preelegir, per RAE
		match = match_against_verbs("elegir", {"", "re"}),
		forms = {vowel_alt = "i", pp = {"elegid", "elect"}}
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
		-- freír, refreír
		match = "freír",
		forms = {vowel_alt = "í", pp = {"freíd", "frit"}}
	},
	{
		match = "garantir",
		forms = {
			pres_stressed = {{form = "garant", footnotes = {"[only used in Argentina and Uruguay]"}}},
			pres1_and_sub = {{form = "garant", footnotes = {"[only used in Argentina and Uruguay]"}}},
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
			fut = "habr",
		}
	},
	{
		match = "satisfacer",
		forms = {
			-- see below for cons_alt setting and pres1_and_sub setting
			pres1_and_sub = "satisfagu", cons_alt = false, pret = "satisfic", pret_conj = "irreg",
			pp = "satisfech", fut = "satisfar", imp_2s = {"satisface", "satisfaz"}
		}
	},
	{
		match = match_against_verbs("hacer", {"contra", "re"}),
		-- contrahacer/rehacer require an extra accent in the preterite (rehíce, rehízo).
		forms = {
			-- see below for cons_alt setting and pres1_and_sub setting
			pres1_and_sub = "hagu", cons_alt = false,
			pret = "hic", pret_1s = "híce", pret_3s = "hízo", pret_conj = "irreg",
			pp = "hech", fut = "har", imp_2s = "haz"
		}
	},
	{
		-- hacer, deshacer, contrahacer, rehacer, facer, desfacer, jacer
		match = function(verb) return rmatch(verb, "^(.*[hjf])(acer)$") end,
		forms = {
			-- for these verbs, we set cons_alt to false because we don't want the verb categorized as a
			-- c-zc alternating verb, which would happen by default
			-- use 'agu' because we're in a front environment; if we use 'ag', we'll get '#hajo'
			pres1_and_sub = "agu", cons_alt = false, pret = "ic", pret_conj = "irreg", pp = "ech",
			fut = "ar", imp_2s = "az"
		}
	},
	{
		-- imprimir, reimprimir
		match = "imprimir",
		forms = {pp = {"imprimid", "impres"}}
	},
	{
		-- infecir
		match = "infecir",
		-- override cons_alt, otherwise the verb would be categorized as a c-zc alternating verb
		forms = {vowel_alt = "i", pres1 = "infiz", pres_sub_unstressed = "infez", cons_alt = "c-z"}, -- not infizco, as would normally be generated
	},
	{
		match = "infecir",
		-- override cons_alt, otherwise the verb would be categorized as a c-zc alternating verb
		forms = {pres1_and_sub = "infez", cons_alt = "c-z"}, -- not mezco, as would normally be generated
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
			pret_conj = "irreg", -- this signals that fu + -ieron -> fueron not fuyeron
			pret_1s = "fui",
			pret_3s = "fue",
			imp_2s = "ve",
			imp_2sv = "andá",
			imp_1p = {"vamos", "vayamos"},
			refl_imp_2p = {"idos", "iros"},
			imp_2p_comb_os = {"idos", "iros"},
		}
	},
	{
		-- mecer, remecer
		-- we don't want to match e.g. adormecer, estremecer
		match = match_against_verbs("mecer", {"re", ""}),
		-- override cons_alt, otherwise the verb would be categorized as a c-zc alternating verb
		forms = {pres1_and_sub = "mez", cons_alt = "c-z"}, -- not mezco, as would normally be generated
	},
	{
		-- morir, desmorir, premorir
		match = "morir",
		forms = {vowel_alt = "ue-u", pp = "muert"},
	},
	{
		-- oír, desoír, entreoír, trasoír
		match = "oír",
		-- use 'oigu' because we're in a front environment; if we use 'oig', we'll get '#oijo'
		forms = {pres1_and_sub = "oigu"}
	},
	{
		match = "olver", -- solver, volver, bolver and derivatives
		forms = {vowel_alt = "ue", pp = "uelt"}
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
		forms = {vowel_alt = "ue", pret = "pud", pret_conj = "irreg", fut = "podr", gerund = "pudiendo"}
	},
	{
		-- poner, componer, deponer, imponer, oponer, suponer, many others
		match = "poner",
		forms = {
			-- use 'pongu' because we're in a front environment; if we use 'pong', we'll get '#ponjo'
			pres1_and_sub = "pongu", pret = "pus", pret_conj = "irreg", fut = "pondr", pp = "puest",
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
		forms = {vowel_alt = "ie", pret = "quis", pret_conj = "irreg", fut = "querr"}
	},
	{
		match = "^raer",
		-- use 'raigu' because we're in a front environment; if we use 'raig', we'll get '#raijo'
		forms = {pres1_and_sub = {"raigu", "ray"}}
	},
	{
		-- roer, corroer
		match = "roer",
		-- use 'roigu' because we're in a front environment; if we use 'roig', we'll get '#roijo'
		forms = {pres1_and_sub = {"ro", "roigu", "roy"}}
	},
	{
		-- romper, entrerromper, arromper, derromper; not corromper; FIXME: not sure about interromper (obsolete)
		match = function(verb)
			local prefix, base_verb = rmatch(verb, "^(.*)(romper)$")
			-- Don't match corromper
			if prefix == "cor" then
				return nil
			else
				return prefix, base_verb
			end
		end,
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
		forms = {
			-- use 'salgu' because we're in a front environment; if we use 'salg', we'll get '#saljo'
			pres1_and_sub = "salgu", fut = "saldr", imp_2s = "sal",
			-- These don't exist per the RAE.
			imp_2s_comb_lo = {}, imp_2s_comb_los = {}, imp_2s_comb_la = {}, imp_2s_comb_las = {},
			imp_2s_comb_le = {}, imp_2s_comb_les = {},
		},
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
			pret_conj = "irreg", -- this signals that fu + -ieron -> fueron not fuyeron
			pret_1s = "fui",
			pret_3s = "fue",
			fut = "ser",
			imp_2s = "sé*", -- * signals that the monosyllabic accent must remain
			imp_2sv = "sé*",
		}
	},
	{
		match = "^soler",
		forms = {
			vowel_alt = "ue",
			fut = {{form = "soler", footnotes = {"[rare but acceptable]"}}},
			fut_sub = {{form = "sol", footnotes = {"[rare but acceptable]"}}},
			pp = {{form = "solid", footnotes = {"[rare but acceptable]"}}},
		}
	},
	{
		-- tener, abstener, contener, detener, obtener, sostener, and many others
		match = "tener",
		forms = {
			-- use 'tengu' because we're in a front environment; if we use 'teng', we'll get '#tenjo'
			pres1_and_sub = "tengu", vowel_alt = "ie", pret = "tuv", pret_conj = "irreg", fut = "tendr",
			imp_2s = "tén" -- need the accent for the compounds; it will be removed in the simplex
		}
	},
	{
		-- traer, atraer, detraer, distraer, extraer, sustraer, and many others
		match = "traer",
		-- use 'traigu' because we're in a front environment; if we use 'traig', we'll get '#traijo'
		forms = {pres1_and_sub = "traigu", pret = "traj", pret_conj = "irreg"}
	},
	{
		-- valer, equivaler, prevaler
		match = "valer",
		-- use 'valgu' because we're in a front environment; if we use 'valg', we'll get '#valjo'
		forms = {pres1_and_sub = "valgu", fut = "valdr"}
	},
	{
		match = "venir",
		forms = {
			-- use 'vengu' because we're in a front environment; if we use 'veng', we'll get '#venjo'
			pres1_and_sub = "vengu", vowel_alt = "ie-i", pret = "vin", pret_conj = "irreg",
			-- uniquely for this verb, pres sub 2sv/1p/2p do not raise the vowel even though we are an
			-- e-ie-i verb (contrast sentir -> sintamos/sintáis)
			pres_sub_2sv = "vengás", pres_sub_1p = "vengamos", pres_sub_2p = "vengáis",
			fut = "vendr", imp_2s = "vén" -- need the accent for the compounds; it will be removed in the simplex
		}
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
			impf = "ve", pp = "vist",
			imp_2s = "vé" -- need the accent for the compounds; it will be removed in the simplex
		}
	},
	{
		-- yacer, adyacer, subyacer
		match = "yacer",
		-- use 'yazqu/yazgu/yagu' because we're in a front environment; see 'decir' above
		forms = {pres1_and_sub = {"yazqu", "yazgu", "yagu"}, imp_2s = {"yace", "yaz"}}
	},
}

local reflexive_masc_forms = {
	["su"] = {"mi", "tu", "su", "nuestro", "vuestro", "su"},
	["sus"] = {"mis", "tus", "sus", "nuestros", "vuestros", "sus"},
	["sí"] = {"mí", "ti", "sí", "nosotros", "vosotros", "sí"},
	["consigo"] = {"conmigo", "contigo", "consigo", "con nosotros", "con vosotros", "consigo"},
}

local reflexive_fem_forms = {
	["su"] = {"mi", "tu", "su", "nuestra", "vuestra", "su"},
	["sus"] = {"mis", "tus", "sus", "nuestras", "vuestras", "sus"},
	["sí"] = {"mí", "ti", "sí", "nosotras", "vosotras", "sí"},
	["consigo"] = {"conmigo", "contigo", "consigo", "con nosotras", "con vosotras", "consigo"},
}

local reflexive_forms = {
	["se"] = {"me", "te", "se", "nos", "os", "se"},
	["suyo"] = {"mío", "tuyo", "suyo", "nuestro", "vuestro", "suyo"},
	["suya"] = {"mía", "tuya", "suya", "nuestra", "vuestra", "suya"},
	["suyos"] = {"míos", "tuyos", "suyos", "nuestros", "vuestros", "suyos"},
	["suyas"] = {"mías", "tuyas", "suyas", "nuestras", "vuestras", "suyas"},
}


local function skip_slot(base, slot, allow_overrides)
	if not allow_overrides and (base.basic_overrides[slot] or base.combined_overrides[slot] or
		base.refl and base.basic_reflexive_only_overrides[slot]) then
		-- Skip any slots for which there are overrides.
		return true
	end

	if base.only3s and (slot:find("^pp_f") or slot:find("^pp_mp")) then
		-- diluviar, atardecer, neviscar; impersonal verbs have only masc sing pp
		return true
	end

	if not slot:find("[123]") then
		-- Don't skip non-personal slots.
		return false
	end

	if base.nofinite then
		return true
	end

	if base.only3s and (not slot:find("3s") or slot:find("^imp_") or slot:find("^neg_imp_")) then
		-- diluviar, atardecer, neviscar
		return true
	end

	if base.only3sp and (not slot:find("3[sp]") or slot:find("^imp_") or slot:find("^neg_imp_")) then
		-- atañer, concernir
		return true
	end

	return false
end


local function escape_reflexive_indicators(arg1)
	if not arg1:find("pron>") then
		return arg1
	end
	local segments = iut.parse_balanced_segment_run(arg1, "<", ">")
	-- Loop over every other segment. The even-numbered segments are angle-bracket specs while
	-- the odd-numbered segments are the text between them.
	for i = 2, #segments - 1, 2 do
		if segments[i] == "<mpron>" then
			segments[i] = "⦃⦃mpron⦄⦄"
		elseif segments[i] == "<fpron>" then
			segments[i] = "⦃⦃fpron⦄⦄"
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


-- Add the `stem` to the `ending` for the given `slot` and apply any phonetic modifications.
-- `is_combining_ending` is true if `ending` is actually the ending (this function is also
-- called to combine prefix + stem). WARNING: This function is written very carefully; changes
-- to it can easily have unintended consequences.
local function combine_stem_ending(base, slot, stem, ending, is_combining_ending)
	if not is_combining_ending then
		return stem .. ending
	end

	if base.stems.raising_conj and (rfind(ending, "^i" .. V) or
		slot == "pres_sub_1p" or slot == "pres_sub_2p" or slot == "pres_sub_2sv") then
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

		-- (2) In the preterite of irregular verbs (likewise for other tenses derived from the preterite stem, i.e.
		--     imperfect and future subjunctive), initial i absorbed after j (dijeron not #dijieron, likewise for
		--     condujeron, trajeron) and u (fueron not #fuyeron). Does not apply in regular verb tejer (tejieron not
		--     #tejeron) and concluir (concluyeron not #conclueron).
		if base.stems.pret_conj == "irreg" and rfind(stem, "[ju]$") then
			ending = ending:gsub("^i", "")
		end

		-- (3) initial i -> y after vowel and word-initially: poseer -> poseyó, poseyera, poseyendo;
		-- concluir -> concluyó, concluyera, concluyendo; ir -> yendo; but not conseguir/delinquir
		if stem == "" or (rfind(stem, V .. "$") and not rfind(stem, "[gq]u$")) then
			ending = ending:gsub("^i", "y")
		end

		-- (4) -gü + ie- -> -guye-: argüir -> arguyó, arguyera, arguyendo
		if stem:find("gü$") then
			-- transfer the y to the stem to avoid gü -> gu below in front/back conversions
			stem = stem:gsub("ü$", "uy")
			ending = ending:gsub("^i", "")
		end

		-- (5) initial i absorbed after ñ, ll, y: tañer -> tañó, tañera, tañendo; bullir -> bulló, bullera, bullendo
		if rfind(stem, "[ñy]$") or rfind(stem, "ll$") then
			ending = ending:gsub("^i", "")
		end
	end

	-- If ending begins with i, it must get an accent after a/e/i/o to prevent the two merging into a diphthong:
	-- caer -> caíste, caímos; reír -> reíste, reímos (pres and pret). This does not apply after u, e.g.
	-- concluir -> concluiste, concluimos.
	if ending:find("^i") and stem:find("[aeio]$") then
		ending = ending:gsub("^i", "í")
	end

	-- If -oír/-uir (i.e. -ir with stem ending in -o/u, e.g. oír, concluir), a y must be added before endings
	-- beginning with a/e/o. Check for base.stems.pret_conj == "irreg" to exclude stem fu- of [[ir]].
	if base.conj == "ir" and rfind(ending, "^[aeoáéó]") and base.stems.pret_conj ~= "irreg" then
		if rfind(stem, "[oú]$") then -- oír -> oye, rehuir -> rehúyo/rehúye (with indicator 'ú')
			stem = stem .. "y"
		elseif rfind(stem, "[^gq]u$") then -- concluir, but not conseguir or delinquir
			stem = stem .. "y"
		elseif stem:find("ü$") then -- argüir -> arguyendo
			stem = stem:gsub("ü$", "uy")
		end
	end

	-- Spelling changes in the stem; it depends on whether the stem given is the pre-front-vowel or
	-- pre-back-vowel variant, as indicated by `frontback`. We want these front-back spelling changes to happen
	-- between stem and ending, not between prefix and stem; the prefix may not have the same "front/backness"
	-- as the stem.
	local is_front = rfind(ending, "^[eiéí]")
	if base.frontback == "front" and not is_front then
		-- parecer -> parezco, conducir -> conduzco; use zqu to avoid triggering the following gsub();
		-- the third line will replace zqu -> zc
		if slot ~= "pret_3s" then -- exclude hice -> hizo (not #hizco)
			stem = rsub(stem, "(" .. V .. ")c$", "%1zqu")
		end
		stem = stem:gsub("sc$", "squ") -- evanescer -> evanesco, fosforescer -> fosforesco
		stem = stem:gsub("c$", "z") -- ejercer -> ejerzo, uncir -> unzo
		stem = stem:gsub("qu$", "c") -- delinquir -> delinco, parecer -> parezqu- -> parezco
		stem = stem:gsub("g$", "j") -- coger -> cojo, afligir -> aflijo
		stem = stem:gsub("gu$", "g") -- distinguir -> distingo
		stem = stem:gsub("gü$", "gu") -- may not occur; argüir -> arguyo handled above
	elseif base.frontback == "back" and is_front then
		stem = stem:gsub("gu$", "gü") -- averiguar -> averigüé
		stem = stem:gsub("g$", "gu") -- cargar -> cargué
		stem = stem:gsub("c$", "qu") -- marcar -> marqué
		stem = rsub(stem, "[çz]$", "c") -- aderezar/adereçar -> aderecé
	end

	return stem .. ending
end


local function add(base, slot, stems, endings, is_combining_ending, allow_overrides)
	if skip_slot(base, slot, allow_overrides) then
		return
	end
	local function do_combine_stem_ending(stem, ending)
		return combine_stem_ending(base, slot, stem, ending, is_combining_ending)
	end
	iut.add_forms(base.forms, slot, stems, endings, do_combine_stem_ending, nil, nil, base.all_footnotes)
end


local function add3(base, slot, prefix, stems, endings, allow_overrides)
	if prefix == "" then
		return add(base, slot, stems, endings, "is combining ending", allow_overrides)
	end

	if skip_slot(base, slot, allow_overrides) then
		return
	end

	local is_combining_ending = false

	local function do_combine_stem_ending(stem, ending)
		return combine_stem_ending(base, slot, stem, ending, is_combining_ending)
	end

	-- Have to reimplement add_multiple_forms() ourselves due to the is_combining_ending
	-- flag, which needs to be different when adding prefix to stems vs. stems to ending.
	-- Otherwise we get e.g. #reímpreso instead of reimpreso.
	local tempdest = {}
	iut.add_forms(tempdest, slot, prefix, stems, do_combine_stem_ending)
	is_combining_ending = true
	iut.add_forms(base.forms, slot, tempdest[slot], endings, do_combine_stem_ending)
end


local function insert_form(base, slot, form)
	if not skip_slot(base, slot) then
		iut.insert_form(base.forms, slot, form)
	end
end


local function insert_forms(base, slot, forms)
	if not skip_slot(base, slot) then
		iut.insert_forms(base.forms, slot, forms)
	end
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

	addit("1s", base.stems.pres1, "o")
	addit("2s", base.stems.pres_stressed, s2)
	addit("2sv", base.stems.pres_unstressed, s2v)
	addit("3s", base.stems.pres_stressed, s3)
	addit("1p", base.stems.pres_unstressed, p1)
	addit("2p", base.stems.pres_unstressed, p2)
	addit("3p", base.stems.pres_stressed, p3)
end


local function add_present_subj(base)
	local function addit(slot, stems, ending)
		add3(base, "pres_sub_" .. slot, base.prefix, stems, ending)
	end
	local s1, s2, s2v, s3, p1, p2, p3, voseo_stem
	if base.conj == "ar" then
		s1, s2, s2v, s3, p1, p2, p3 = "e", "es", "és", "e", "emos", "éis", "en"
	else
		s1, s2, s2v, s3, p1, p2, p3 = "a", "as", "ás", "a", "amos", "áis", "an"
	end

	addit("1s", base.stems.pres_sub_stressed, s1)
	addit("2s", base.stems.pres_sub_stressed, s2)
	addit("2sv", base.stems.pres_sub_unstressed, s2v)
	addit("3s", base.stems.pres_sub_stressed, s3)
	addit("1p", base.stems.pres_sub_unstressed, p1)
	addit("2p", base.stems.pres_sub_unstressed, p2)
	addit("3p", base.stems.pres_sub_stressed, p3)
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
	insert_form(base, "infinitive", {form = base.verb})
	addit("gerund", stems.pres_unstressed, base.conj == "ar" and "ando" or "iendo")
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
				elseif not rfind(form.form, "^%-") and rfind(form.form, AV) and not rfind(form.form, V .. C .. V) then
					-- Has an accented vowel and no VCV sequence and not a suffix; may be monosyllabic, in which
					-- case we need to remove the accent. Check # of syllables and remove accent if only 1. Note
					-- that the checks for accented vowel and VCV sequence are not strictly needed, but are
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


-- Add the clitic pronouns in `pronouns` to the forms in `base_slot`. If `do_combined_slots` is given,
-- store the results into the appropriate combined slots, e.g. `imp_2s_comb_lo` for second singular imperative + lo.
-- Otherwise, directly modify `base_slot`. The latter case is used for handling reflexive verbs, and in that case
-- `pronouns` should contain only a single pronoun.
local function add_forms_with_clitic(base, base_slot, pronouns, do_combined_slots)
	if not base.forms[base_slot] then
		-- This can happen, e.g. in only3s/only3sp verbs.
		return
	end
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
			if do_combined_slots then
				insert_form(base, base_slot .. "_comb_" .. pronoun,
					{form = cliticized_verb, footnotes = form.footnotes})
			else
				form.form = cliticized_verb
			end
		end
	end
end


-- Generate the combinations of verb form (infinitive, gerund or various imperatives) + clitic pronoun.
local function add_combined_forms(base)
	for _, base_slot_and_pronouns in ipairs(verb_slot_combined_rows) do
		local base_slot, pronouns = unpack(base_slot_and_pronouns)
		-- Skip non-infinitive/gerund combinations for reflexive verbs. We will copy the appropriate imperative
		-- combinations later.
		if not base.refl or base_slot == "infinitive" or base_slot == "gerund" then
			add_forms_with_clitic(base, base_slot, pronouns, "do combined slots")
		end
	end
end


local function process_slot_overrides(base, do_basic, reflexive_only)
	local overrides = reflexive_only and base.basic_reflexive_only_overrides or
		do_basic and base.basic_overrides or base.combined_overrides
	for slot, forms in pairs(overrides) do
		add(base, slot, base.prefix, forms, false, "allow overrides")
	end
end


-- Add a reflexive pronoun or fixed clitic, e.g. [[lo]], as appropriate to the base form that were generated.
-- `do_joined` means to do only the forms where the pronoun is joined to the end of the form; otherwise, do only the
-- forms where it is not joined and precedes the form.
local function add_reflexive_or_fixed_clitic_to_forms(base, do_reflexive, do_joined)
	for _, slotaccel in ipairs(verb_slots_basic) do
		local slot, accel = unpack(slotaccel)
		local clitic
		if not do_reflexive then
			clitic = base.clitic
		elseif slot:find("[123]") then
			local persnum = slot:match("^.*_(.-)$")
			clitic = person_number_to_reflexive_pronoun[persnum]
		else
			clitic = "se"
		end
		if base.forms[slot] then
			if slot == "infinitive" or slot == "gerund" or slot:find("^imp_") then
				if do_joined then
					add_forms_with_clitic(base, slot, {clitic})
				end
			elseif do_reflexive and slot:find("^pp_") or slot == "infinitive_linked" then
				-- do nothing with reflexive past participles or with infinitive linked (handled at the end)
			elseif slot:find("^neg_imp_") then
				error("Internal error: Should not have forms set for negative imperative at this stage")
			elseif not do_joined then
				-- Add clitic as separate word before all other forms. Check whether form already has brackets
				-- (as will be the case if the form has a fixed clitic).
				for _, form in ipairs(base.forms[slot]) do
					if base.args.noautolinkverb then
						form.form = clitic .. " " .. form.form
					else
						local clitic_pref = "[[" .. clitic .. "]] "
						if form.form:find("%[%[") then
							form.form = clitic_pref .. form.form
						else
							form.form = clitic_pref .. "[[" .. form.form .. "]]"
						end
					end
				end
			end
		end
	end
end


local function copy_subjunctives_to_imperatives(base)
	-- Copy subjunctives to imperatives, unless there's an override for the given slot (as with the imp_1p of [[ir]]).
	for _, persnum in ipairs({"3s", "1p", "3p"}) do
		local from = "pres_sub_" .. persnum
		local to = "imp_" .. persnum
		insert_forms(base, to, iut.map_forms(base.forms[from], function(form) return form end))
	end
end


local function handle_infinitive_linked(base)
	-- Compute linked versions of potential lemma slots, for use in {{es-verb}}.
	-- We substitute the original lemma (before removing links) for forms that
	-- are the same as the lemma, if the original lemma has links.
	for _, slot in ipairs({"infinitive"}) do
		insert_forms(base, slot .. "_linked", iut.map_forms(base.forms[slot], function(form)
			if form == base.lemma and rfind(base.linked_lemma, "%[%[") then
				return base.linked_lemma
			else
				return form
			end
		end))
	end
end


local function generate_negative_imperatives(base)
	-- Copy subjunctives to negative imperatives, preceded by "no".
	for _, persnum in ipairs({"2s", "3s", "1p", "2p", "3p"}) do
		local from = "pres_sub_" .. persnum
		local to = "neg_imp_" .. persnum
		insert_forms(base, to, iut.map_forms(base.forms[from], function(form)
			if base.args.noautolinkverb then
				return "no " .. form
			elseif form:find("%[%[") then
				-- already linked, e.g. when reflexive
				return "[[no]] " .. form
			else
				return "[[no]] [[" .. form .. "]]"
			end
		end))
	end
end


local function copy_imperatives_to_reflexive_combined_forms(base)
	local copy_table = {
		{"imp_2s", "imp_2s_comb_te"},
		{"imp_3s", "imp_3s_comb_se"},
		{"imp_1p", "imp_1p_comb_nos"},
		{"imp_2p", "imp_2p_comb_os"},
		{"imp_3p", "imp_3p_comb_se"},
	}

	-- Copy imperatives (with the clitic reflexive pronoun already added) to the appropriate "combined" reflexive
	-- forms.
	for _, entry in ipairs(copy_table) do
		local from, to = unpack(entry)
		-- Need to call map_forms() to clone the form objects because insert_forms() doesn't clone them, and may
		-- side-effect them when inserting footnotes.
		insert_forms(base, to, iut.map_forms(base.forms[from], function(form) return form end))
	end
end


local function add_missing_links_to_forms(base)
	-- Any forms without links should get them now. Redundant ones will be stripped later.
	for slot, forms in pairs(base.forms) do
		for _, form in ipairs(forms) do
			if not form.form:find("%[%[") then
				form.form = "[[" .. form.form .. "]]"
			end
		end
	end
end


local function conjugate_verb(base)
	add_present_indic(base)
	add_present_subj(base)
	add_imper(base)
	add_non_present(base)
	-- This should happen before add_combined_forms() so overrides of basic forms end up part of the combined forms.
	process_slot_overrides(base, "do basic") -- do basic slot overrides
	-- This should happen after process_slot_overrides() in case a derived slot is based on an override (as with the
	-- imp_3s of [[dar]], [[estar]]).
	copy_subjunctives_to_imperatives(base)
	-- This should happen after process_slot_overrides() because overrides may have accents in them that need to be
	-- removed. (This happens e.g. for most present indicative forms of [[ver]], which have accents in them for the
	-- prefixed derived verbs, but the accents shouldn't be present in the base verb.)
	remove_monosyllabic_accents(base)
	if not base.nocomb then
		-- This should happen before add_reflexive_pronouns() because the combined forms of reflexive verbs don't have
		-- the reflexive attached.
		add_combined_forms(base)
	end
	-- We need to add joined reflexives, then joined and non-joined clitics, then non-joined reflexives, so we get
	-- [[házmelo]] but [[no]] [[me]] [[lo]] [[haga]].
	if base.refl then
		-- This should happen after remove_monosyllabic_accents() so the * marking the preservation of monosyllabic
		-- accents doesn't end up in the middle of a word.
		add_reflexive_or_fixed_clitic_to_forms(base, "do reflexive", "do joined")
		process_slot_overrides(base, "do basic", "do reflexive") -- do reflexive-only basic slot overrides
	end
	if base.clitic then
		-- This should happen after reflexives are added.
		add_reflexive_or_fixed_clitic_to_forms(base, false, "do joined")
		add_reflexive_or_fixed_clitic_to_forms(base, false, false)
	end
	if base.refl then
		add_reflexive_or_fixed_clitic_to_forms(base, "do reflexive", false)
	end
	-- This should happen after add_reflexive_or_fixed_clitic_to_forms() so negative imperatives get the reflexive pronoun
	-- and clitic in them.
	generate_negative_imperatives(base)
	if not base.nocomb then
		if base.refl then
			-- This should happen after process_slot_overrides() for reflexive-only basic slots so the overridden
			-- forms (e.g. [[idos]]/[[iros]] for [[ir]]) get appropriately copied.
			copy_imperatives_to_reflexive_combined_forms(base)
		end
		process_slot_overrides(base, false) -- do combined slot overrides
	end
	-- This should happen before add_missing_links_to_forms() so that the comparison `form == base.lemma`
	-- in handle_infinitive_linked() works correctly and compares unlinked forms to unlinked forms.
	handle_infinitive_linked(base)
	if not base.args.noautolinkverb then
		add_missing_links_to_forms(base)
	end
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
				if base.vowel_alt then
					for _, existing_alt in ipairs(base.vowel_alt) do
						if existing_alt.form == alt then
							parse_err("Vowel alternant '" .. alt .. "' specified twice")
						end
					end
				else
					base.vowel_alt = {}
				end
				table.insert(base.vowel_alt, {form = alt, footnotes = fetch_footnotes(comma_separated_groups[j])})
			end
		elseif (first_element == "no_pres_stressed" or first_element == "no_pres1_and_sub" or
				first_element == "only3s" or first_element == "only3sp") then
			if #comma_separated_groups[1] > 1 then
				parse_err("No footnotes allowed with '" .. first_element .. "' spec")
			end
			if base[first_element] then
				parse_err("Spec '" .. first_element .. "' specified twice")
			end
			base[first_element] = true
		else
			parse_err("Unrecognized spec '" .. comma_separated_groups[1][1] .. "'")
		end
	end

	return base
end


-- Normalize all lemmas, substituting the pagename for blank lemmas and adding links to multiword lemmas.
local function normalize_all_lemmas(alternant_multiword_spec)

	-- (1) Add links to all before and after text.
	if not alternant_multiword_spec.args.noautolinktext then
		alternant_multiword_spec.post_text = com.add_links(alternant_multiword_spec.post_text)
		for _, alternant_or_word_spec in ipairs(alternant_multiword_spec.alternant_or_word_specs) do
			alternant_or_word_spec.before_text = com.add_links(alternant_or_word_spec.before_text)
			if alternant_or_word_spec.alternants then
				for _, multiword_spec in ipairs(alternant_or_word_spec.alternants) do
					multiword_spec.post_text = com.add_links(multiword_spec.post_text)
					for _, word_spec in ipairs(multiword_spec.word_specs) do
						word_spec.before_text = com.add_links(word_spec.before_text)
					end
				end
			end
		end
	end

	-- (2) Remove any links from the lemma, but remember the original form
	--     so we can use it below in the 'lemma_linked' form.
	iut.map_word_specs(alternant_multiword_spec, function(base)
		if base.lemma == "" then
			base.lemma = alternant_multiword_spec.args.pagename or
				alternant_multiword_spec.args.head and alternant_multiword_spec.args.head[1]
			if not base.lemma then
				local PAGENAME = mw.title.getCurrentTitle().text
				base.lemma = PAGENAME
			end
		end

		base.user_specified_lemma = base.lemma

		base.lemma = m_links.remove_links(base.lemma)
		local refl_verb, clitic = rmatch(base.lemma, "^(.-)(l[aeo]s?)$")
		if not refl_verb then
			refl_verb, clitic = base.lemma, nil
		end
		local verb, refl = rmatch(refl_verb, "^(.-)(se)$")
		if not verb then
			verb, refl = refl_verb, nil
		end
		base.user_specified_verb = verb
		base.refl = refl
		base.clitic = clitic

		if base.refl and base.clitic then
			-- We have to parse the verb suffix to see how to construct the base verb; e.g.
			-- abrírsela -> abrir but oírsela -> oír. We parse the verb suffix again in all cases
			-- in detect_indicator_spec(), after splitting off the prefix of irrregular verbs.
			local actual_verb
			local inf_stem, suffix = rmatch(base.user_specified_verb, "^(.*)([aáeéií]r)$")
			if not inf_stem then
				error("Unrecognized infinitive: " .. base.user_specified_verb)
			end
			if suffix == "ír" and inf_stem:find("[aeo]$") then
				-- accent on suffix should remain
				base.verb = base.user_specified_verb
			else
				base.verb = inf_stem .. com.remove_accent_from_syllable(suffix)
			end
		else
			base.verb = base.user_specified_verb
		end

		local linked_lemma
		if alternant_multiword_spec.args.noautolinkverb or base.user_specified_lemma:find("%[%[") then
			linked_lemma = base.user_specified_lemma
		elseif base.refl or base.clitic then
			-- Reconstruct the linked lemma with separate links around base verb, reflexive pronoun and clitic.
			linked_lemma = base.user_specified_verb == base.verb and "[[" .. base.user_specified_verb .. "]]" or
				"[[" .. base.verb .. "|" .. base.user_specified_verb .. "]]"
			linked_lemma = linked_lemma .. (refl and "[[" .. refl .. "]]" or "") ..
				(clitic and "[[" .. clitic .. "]]" or "")
		else
			-- Add links to the lemma so the user doesn't specifically need to, since we preserve
			-- links in multiword lemmas and include links in non-lemma forms rather than allowing
			-- the entire form to be a link.
			linked_lemma = com.add_links(base.user_specified_lemma)
		end
		base.linked_lemma = linked_lemma
	end)
end


local function construct_stems(base)
	local stems = base.stems
	stems.pres_unstressed = stems.pres_unstressed or base.inf_stem
	stems.pres_stressed = stems.pres_stressed or
		-- If no_pres_stressed given, pres_stressed stem should be empty so no forms are generated.
		base.no_pres_stressed and {} or
		base.vowel_alt or
		base.inf_stem
	stems.pres1_and_sub = stems.pres1_and_sub or
		-- If no_pres_stressed given, the entire subjunctive is missing.
		base.no_pres_stressed and {} or
		-- If no_pres1_and_sub given, pres1 and entire subjunctive are missing.
		base.no_pres1_and_sub and {} or
		nil
	stems.pres1 = stems.pres1 or stems.pres1_and_sub or stems.pres_stressed
	stems.impf = stems.impf or base.inf_stem
	stems.pret = stems.pret or base.inf_stem
	stems.pret_conj = stems.pret_conj or base.conj
	stems.fut = stems.fut or base.inf_stem .. base.conj
	stems.cond = stems.cond or stems.fut
	stems.pres_sub_stressed = stems.pres_sub_stressed or stems.pres1
	stems.pres_sub_unstressed = stems.pres_sub_unstressed or stems.pres1_and_sub or stems.pres_unstressed
	stems.impf_sub_ra = stems.impf_sub_ra or stems.pret
	stems.impf_sub_se = stems.impf_sub_se or stems.pret
	stems.fut_sub = stems.fut_sub or stems.pret
	stems.pp = stems.pp or base.conj == "ar" and
		combine_stem_ending(base, "pp_ms", base.inf_stem, "ad", "is combining ending") or
		-- use combine_stem_ending esp. so we get reído, caído, etc.
		combine_stem_ending(base, "pp_ms", base.inf_stem, "id", "is combining ending")
end


local function detect_indicator_spec(base)
	base.forms = {}
	base.stems = {}

	if base.only3s and base.only3sp then
		error("'only3s' and 'only3sp' cannot both be specified")
	end

	base.basic_overrides = {}
	base.basic_reflexive_only_overrides = {}
	base.combined_overrides = {}
	for _, irreg_conj in ipairs(irreg_conjugations) do
		if type(irreg_conj.match) == "function" then
			base.prefix, base.non_prefixed_verb = irreg_conj.match(base.verb)
		elseif irreg_conj.match:find("^%^") and rsub(irreg_conj.match, "^%^", "") == base.verb then
			-- begins with ^, for exact match, and matches
			base.prefix, base.non_prefixed_verb = "", base.verb
		else
			base.prefix, base.non_prefixed_verb = rmatch(base.verb, "^(.*)(" .. irreg_conj.match .. ")$")
		end
		if base.prefix then
			-- we found an irregular verb
			base.irreg_verb = true
			for stem, forms in pairs(irreg_conj.forms) do
				if stem:find("^refl_") then
					stem = stem:gsub("^refl_", "")
					if not verb_slots_basic_map[stem] then
						error("Internal error: setting for 'refl_" .. stem .. "' does not refer to a basic verb slot")
					end
					base.basic_reflexive_only_overrides[stem] = forms
				elseif verb_slots_basic_map[stem] then
					-- an individual form override of a basic form
					base.basic_overrides[stem] = forms
				elseif verb_slots_combined_map[stem] then
					-- an individual form override of a combined form
					base.combined_overrides[stem] = forms
				else
					base.stems[stem] = forms
				end
			end
			break
		end
	end
	base.prefix = base.prefix or ""
	base.non_prefixed_verb = base.non_prefixed_verb or base.verb
	local inf_stem, suffix = rmatch(base.non_prefixed_verb, "^(.*)([aeií]r)$")
	if not inf_stem then
		error("Unrecognized infinitive: " .. base.verb)
	end
	base.inf_stem = inf_stem
	suffix = suffix == "ír" and "ir" or suffix
	base.conj = suffix
	base.frontback = suffix == "ar" and "back" or "front"

	if base.stems.vowel_alt then -- irregular verb with specified vowel alternation
		if base.vowel_alt then
			error(base.verb .. " is a recognized irregular verb, and should not have vowel alternations specified with it")
		end
		base.vowel_alt = iut.convert_to_general_list_form(base.stems.vowel_alt)
	end

	-- Convert vowel alternation indicators into stems.
	if base.vowel_alt then
		for _, altform in ipairs(base.vowel_alt) do
			altform.alt = altform.form -- save original indicator
			local alt = altform.alt
			if base.conj == "ir" then
				local raising = (
					alt == "ie-i" or alt == "ye-i" or alt == "ue-u" or alt == "i" or alt == "í" or alt == "ú"
				)
				if base.stems.raising_conj == nil then
					base.stems.raising_conj = raising
				elseif base.stems.raising_conj ~= raising then
					error("Can't currently support a mixture of raising (e.g. 'ie-i') and non-raising (e.g. 'ie') vowel alternations in -ir verbs")
				end
			end
			if alt == "+" then
				altform.form = base.inf_stem
			else
				local normalized_alt = alt
				if alt == "ie-i" or alt == "ye-i" or alt == "ue-u" then
					if base.conj ~= "ir" then
						error("Vowel alternation '" .. alt .. "' only supported with -ir verbs")
					end
					-- ie-i is like i except for the vowel raising before i+V, similarly for ye-i, ue-u,
					-- so convert appropriately.
					normalized_alt = alt == "ie-i" and "ie" or alt == "ye-i" and "ye" or "ue"
				end
				local ret = com.apply_vowel_alternation(base.inf_stem, normalized_alt)
				if ret.err then
					error("To use '" .. alt .. "', present stem '" .. base.inf_stem .. "' " .. ret.err)
				end
				altform.form = ret.ret
			end
		end
	end
end


local function detect_all_indicator_specs(alternant_multiword_spec, from_headword)
	-- Propagate some settings up or down.
	iut.map_word_specs(alternant_multiword_spec, function(base)
		for _, prop in ipairs { "refl", "clitic", "only3s", "only3sp" } do
			if base[prop] then
				alternant_multiword_spec[prop] = true
			end
		end
		base.from_headword = from_headword
		base.args = alternant_multiword_spec.args
		-- If fixed clitic, don't include combined forms.
		base.nocomb = alternant_multiword_spec.args.nocomb or base.clitic
	end)

	if not from_headword and not alternant_multiword_spec.args.nocomb then
		-- If we have a combined table, we run into issues if we have multiple
		-- verbs and some are reflexive and some aren't, because we use a
		-- different table for reflexive verbs. So throw an error.
		if alternant_multiword_spec.refl then
			iut.map_word_specs(alternant_multiword_spec, function(base)
				if not base.refl then
					error("If some alternants are reflexive, all must be")
				end
			end)
		end
	end

	iut.map_word_specs(alternant_multiword_spec, function(base)
		detect_indicator_spec(base)
		construct_stems(base)
	end)
end


local function add_categories_and_annotation(alternant_multiword_spec, base, multiword_lemma, from_headword)
	local function insert_ann(anntype, value)
		m_table.insertIfNot(alternant_multiword_spec.annotation[anntype], value)
	end

	local function insert_cat(cat, also_when_multiword)
		-- Don't place multiword terms in categories like 'Spanish verbs ending in -ar' to avoid spamming the
		-- categories with such terms.
		if also_when_multiword or not multiword_lemma then
			m_table.insertIfNot(alternant_multiword_spec.categories, "Spanish " .. cat)
		end
	end

	if check_for_red_links and not from_headword and not multiword_lemma then
		for _, slot_and_accel in ipairs(export.all_verb_slots) do
			local slot = slot_and_accel[1]
			local forms = base.forms[slot]
			local must_break = false
			if forms then
				for _, form in ipairs(forms) do
					if not form.form:find("%[%[") then
						local title = mw.title.new(form.form)
						if title and not title.exists then
							insert_cat("verbs with red links in their inflection tables")
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

	insert_cat("verbs ending in -" .. base.conj)

	if base.irreg_verb then
		insert_ann("irreg", "irregular")
		insert_cat("irregular verbs")
	else
		insert_ann("irreg", "regular")
	end

	if base.only3s then
		insert_ann("defective", "impersonal")
		insert_cat("impersonal verbs")
	elseif base.only3sp then
		insert_ann("defective", "third-person only")
		insert_cat("third-person-only verbs")
	elseif base.no_pres_stressed or base.no_pres1_and_sub then
		insert_ann("defective", "defective")
		insert_cat("defective verbs")
	else
		insert_ann("defective", "regular")
	end

	if base.clitic then
		insert_cat("verbs with lexical clitics")
	end

	if base.refl then
		insert_cat("reflexive verbs")
	end

	if not base.vowel_alt then
		insert_ann("vowel_alt", "non-alternating")
	else
		local inf_stem = base.inf_stem:gsub("[gq]u$", "x")
		for _, alt in ipairs(base.vowel_alt) do
			if alt.alt == "+" then
				insert_ann("vowel_alt", "non-alternating")
			else
				local desc
				if alt.alt == "ue" and rfind(inf_stem, "u" .. C .. "*$") then
					desc = "u-ue alternation" -- jugar
				elseif alt.alt == "ie" and rfind(inf_stem, "i" .. C .. "*$") then
					desc = "i-ie alternation" -- adquirir
				elseif alt.alt == "í" and rfind(inf_stem, "e" .. C .. "*$") then
					desc = "e-í alternation" -- reír, freír, etc.
				else
					desc = vowel_alternant_to_desc[alt.alt] .. " alternation"
				end
				insert_ann("vowel_alt", desc)
				insert_cat("verbs with " .. desc)
			end
		end
	end

	local cons_alt = base.stems.cons_alt
	if cons_alt == nil then
		if base.conj == "ar" then
			if base.inf_stem:find("z$") then
				cons_alt = "c-z"
			elseif base.inf_stem:find("ç$") then
				cons_alt = "c-ç"
			elseif base.inf_stem:find("c$") then
				cons_alt = "c-qu"
			elseif base.inf_stem:find("g$") then
				cons_alt = "g-gu"
			elseif base.inf_stem:find("gu$") then
				cons_alt = "gu-gü"
			end
		else
			if base.no_pres_stressed or base.no_pres1_and_sub then
				cons_alt = nil -- no c-zc alternation in balbucir or arrecir
			elseif rfind(base.inf_stem, V .. "c$") then
				cons_alt = "c-zc"
			elseif base.inf_stem:find("sc$") then
				cons_alt = "hard-soft"
			elseif base.inf_stem:find("c$") then
				cons_alt = "c-z"
			elseif base.inf_stem:find("qu$") then
				cons_alt = "c-qu"
			elseif base.inf_stem:find("g$") then
				cons_alt = "g-j"
			elseif base.inf_stem:find("gu$") then
				cons_alt = "g-gu"
			elseif base.inf_stem:find("gü$") then
				cons_alt = "gu-gü"
			end
		end
	end

	if cons_alt then
		local desc = cons_alt .. " alternation"
		insert_ann("cons_alt", desc)
		insert_cat("verbs with " .. desc)
	else
		insert_ann("cons_alt", "non-alternating")
	end
end


-- Compute the categories to add the verb to, as well as the annotation to display in the
-- conjugation title bar. We combine the code to do these functions as both categories and
-- title bar contain similar information.
local function compute_categories_and_annotation(alternant_multiword_spec, from_headword)
	alternant_multiword_spec.categories = {}
	local ann = {}
	alternant_multiword_spec.annotation = ann
	ann.irreg = {}
	ann.defective = {}
	ann.vowel_alt = {}
	ann.cons_alt = {}

	local multiword_lemma = false
	for _, form in ipairs(alternant_multiword_spec.forms.infinitive) do
		if form.form:find(" ") then
			multiword_lemma = true
			break
		end
	end

	iut.map_word_specs(alternant_multiword_spec, function(base)
		add_categories_and_annotation(alternant_multiword_spec, base, multiword_lemma, from_headword)
	end)
	local ann_parts = {}
	local irreg = table.concat(ann.irreg, " or ")
	if irreg ~= "" and irreg ~= "regular" then
		table.insert(ann_parts, irreg)
	end
	local defective = table.concat(ann.defective, " or ")
	if defective ~= "" and defective ~= "regular" then
		table.insert(ann_parts, defective)
	end
	local vowel_alt = table.concat(ann.vowel_alt, " or ")
	if vowel_alt ~= "" and vowel_alt ~= "non-alternating" then
		table.insert(ann_parts, vowel_alt)
	end
	local cons_alt = table.concat(ann.cons_alt, " or ")
	if cons_alt ~= "" and cons_alt ~= "non-alternating" then
		table.insert(ann_parts, cons_alt)
	end
	alternant_multiword_spec.annotation = table.concat(ann_parts, "; ")
end


local function show_forms(alternant_multiword_spec)
	local lemmas = iut.map_forms(alternant_multiword_spec.forms.infinitive,
		remove_reflexive_indicators)
	alternant_multiword_spec.lemmas = lemmas -- save for later use in make_table()

	-- Initialize the footnotes with those for the future subjunctive and maybe the pres subjunctive
	-- voseo usage. In the latter case, we only do it if there is a distinct pres subjunctive voseo form.
	local function create_footnote_obj()
		local obj = iut.create_footnote_obj()
		iut.get_footnote_text({footnotes = {fut_sub_note}}, obj)
		-- Compute whether the tú and voseo variants are different, for each voseo variant.
		-- We use this later in make_table().
		for _, slot in ipairs({"pres_2s", "pres_sub_2s", "imp_2s"}) do
			alternant_multiword_spec["separate_" .. slot .. "v"] = false
			iut.map_word_specs(alternant_multiword_spec, function(base)
				if not m_table.deepEquals(base.forms[slot], base.forms[slot .. "v"]) then
					alternant_multiword_spec["separate_" .. slot .. "v"] = true
				end
			end)
		end
		if alternant_multiword_spec.separate_pres_sub_2sv then
			iut.get_footnote_text({footnotes = {pres_sub_voseo_note}}, obj)
		end
		return obj
	end

	local props = {
		lang = lang,
		lemmas = lemmas,
		create_footnote_obj = create_footnote_obj,
	}
	props.slot_list = verb_slots_basic
	iut.show_forms(alternant_multiword_spec.forms, props)
	alternant_multiword_spec.footnote_basic = alternant_multiword_spec.forms.footnote
	props.create_footnote_obj = nil
	props.slot_list = verb_slots_combined
	iut.show_forms(alternant_multiword_spec.forms, props)
	alternant_multiword_spec.footnote_combined = alternant_multiword_spec.forms.footnote
end


local notes_template = [=[
<div style="width:100%;text-align:left;background:#d9ebff">
<div style="display:inline-block;text-align:left;padding-left:1em;padding-right:1em">
{footnote}
</div></div>
]=]

local pres_2sv_template = '<sup><sup>tú</sup></sup><br />{pres_2sv}<sup><sup>vos</sup></sup>'
local pres_sub_2sv_template = '<sup><sup>tú</sup></sup><br />{pres_sub_2sv}<sup><sup>vos<sup style="color:red">2</sup></sup></sup>'
local imp_2sv_template = '<sup><sup>tú</sup></sup><br />{imp_2sv}<sup><sup>vos</sup></sup>'

local basic_table = [=[
{description}<div class="NavFrame">
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
{description}<div class="NavFrame">
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
{description}<div class="NavFrame">
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

	forms.title = link_term(alternant_multiword_spec.lemmas[1].form)
	if alternant_multiword_spec.annotation ~= "" then
		forms.title = forms.title .. " (" .. alternant_multiword_spec.annotation .. ")"
	end
	forms.description = ""

	-- Format the basic table.
	forms.footnote = alternant_multiword_spec.footnote_basic
	forms.notes_clause = forms.footnote ~= "" and m_string_utilities.format(notes_template, forms) or ""
	-- The separate_* values are computed in show_forms().
	forms.pres_2sv_text = alternant_multiword_spec.separate_pres_2sv and m_string_utilities.format(pres_2sv_template, forms) or ""
	forms.pres_sub_2sv_text = alternant_multiword_spec.separate_pres_sub_2sv and m_string_utilities.format(pres_sub_2sv_template, forms) or ""
	forms.imp_2sv_text = alternant_multiword_spec.separate_imp_2sv and m_string_utilities.format(imp_2sv_template, forms) or ""
	local formatted_basic_table = m_string_utilities.format(basic_table, forms)

	-- Format the combined table.
	local formatted_combined_table
	if alternant_multiword_spec.args.nocomb or alternant_multiword_spec.clitic then
		formatted_combined_table = ""
	else
		forms.footnote = alternant_multiword_spec.footnote_combined
		forms.notes_clause = forms.footnote ~= "" and m_string_utilities.format(notes_template, forms) or ""
		local combined_table = alternant_multiword_spec.refl and combined_form_reflexive_table or combined_form_table
		formatted_combined_table = m_string_utilities.format(combined_table, forms)
	end

	-- Paste them together.
	return formatted_basic_table .. formatted_combined_table
end


-- Externally callable function to parse and conjugate a verb given user-specified arguments.
-- Return value is WORD_SPEC, an object where the conjugated forms are in `WORD_SPEC.forms`
-- for each slot. If there are no values for a slot, the slot key will be missing. The value
-- for a given slot is a list of objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms(parent_args, from_headword, from_verb_form_of)
	local params = {
		[1] = {required = from_verb_form_of},
		["nocomb"] = {type = "boolean"},
		["noautolinktext"] = {type = "boolean"},
		["noautolinkverb"] = {type = "boolean"},
		["pagename"] = {}, -- for testing/documentation pages
		["json"] = {type = "boolean"}, -- for bot use
	}

	if from_headword then
		params["head"] = {list = true}
		params["pres"] = {list = true} --present
		params["pres_qual"] = {list = "pres=_qual", allow_holes = true}
		params["pret"] = {list = true} --preterite
		params["pret_qual"] = {list = "pret=_qual", allow_holes = true}
		params["part"] = {list = true} --participle
		params["part_qual"] = {list = "part=_qual", allow_holes = true}
		params["attn"] = {type = "boolean"}
		params["id"] = {}
	end

	local args = require("Module:parameters").process(parent_args, params)
	local PAGENAME = mw.title.getCurrentTitle().text

	local arg1 = args[1] or not from_verb_form_of and args.pagename
	if not arg1 and from_headword then
		arg1 = args.head[1]
	end
	if not arg1 then
		if (PAGENAME == "es-conj" or PAGENAME == "es-verb") and mw.title.getCurrentTitle().nsText == "Template" then
			arg1 = "licuar<+,ú>"
		elseif PAGENAME == "es-verb form of" and mw.title.getCurrentTitle().nsText == "Template" then
			arg1 = "amar"
		else
			arg1 = PAGENAME
		end
	end

	if arg1:find(" ") and not arg1:find("<") then
		-- If multiword lemma without <> already, try to add it after the first word.

		local need_explicit_angle_brackets = false
		if arg1:find("%(%(") then
			need_explicit_angle_brackets = true
		else
			local refl_clitic_verb, orig_refl_clitic_verb, post

			-- Try to preserve the brackets in the part after the verb, but don't do it
			-- if there aren't the same number of left and right brackets in the verb
			-- (which means the verb was linked as part of a larger expression).
			refl_clitic_verb, post = rmatch(arg1, "^(.-)( .*)$")
			local left_brackets = rsub(refl_clitic_verb, "[^%[]", "")
			local right_brackets = rsub(refl_clitic_verb, "[^%]]", "")
			if #left_brackets == #right_brackets then
				arg1 = refl_clitic_verb .. "<>" .. post
			else
				need_explicit_angle_brackets = true
			end
		end

		if need_explicit_angle_brackets then
			error("Multiword argument without <> and with alternants, a multiword linked verb or unbalanced brackets; please include <> explicitly: " .. arg1)
		end
	end

	local parse_props = {
		parse_indicator_spec = parse_indicator_spec,
		lang = lang,
		allow_default_indicator = true,
		allow_blank_lemma = true,
	}
	local escaped_arg1 = escape_reflexive_indicators(arg1)
	local alternant_multiword_spec = iut.parse_inflected_text(escaped_arg1, parse_props)
	alternant_multiword_spec.pos = pos or "verbs"
	alternant_multiword_spec.args = args
	normalize_all_lemmas(alternant_multiword_spec)
	detect_all_indicator_specs(alternant_multiword_spec, from_headword)
	local inflect_props = {
		slot_list = export.all_verb_slots,
		lang = lang,
		inflect_word_spec = conjugate_verb,
		-- We add links around the generated verbal forms rather than allow the entire multiword
		-- expression to be a link, so ensure that user-specified links get included as well.
		include_user_specified_links = true,
	}
	iut.inflect_multiword_or_alternant_multiword_spec(alternant_multiword_spec, inflect_props)

	-- Remove redundant brackets around entire forms.
	for slot, forms in pairs(alternant_multiword_spec.forms) do
		for _, form in ipairs(forms) do
			form.form = com.strip_redundant_links(form.form)
		end
	end

	compute_categories_and_annotation(alternant_multiword_spec, from_headword)
	if args.json then
		return require("Module:JSON").toJSON(alternant_multiword_spec)
	end
	return alternant_multiword_spec
end


-- Entry point for {{es-conj}}. Template-callable function to parse and conjugate a verb given
-- user-specified arguments and generate a displayable table of the conjugated forms.
function export.show(frame)
	local parent_args = frame:getParent().args
	local alternant_multiword_spec = export.do_generate_forms(parent_args)
	show_forms(alternant_multiword_spec)
	return make_table(alternant_multiword_spec) ..
		require("Module:utilities").format_categories(alternant_multiword_spec.categories, lang, nil, nil, force_cat)
end


return export
