local export = {}


--[=[

Authorship: Ben Wing <benwing2>

]=]

--[=[

TERMINOLOGY:

-- "slot" = A particular combination of tense/mood/person/number/etc.
	 Example slot names for verbs are "pres_1s" (present indicative first-person singular), "pres_sub_2s" (present
	 subjunctive second-person singular) "impf_sub_3p" (imperfect subjunctive third-person plural),
	 "imp_1p_comb_lo" (imperative first-person plural combined with clitic [[lo]]).
	 Each slot is filled with zero or more forms.

-- "form" = The conjugated Portuguese form representing the value of a given slot.

-- "lemma" = The dictionary form of a given Portuguese term. For Portuguese, always the infinitive.
]=]

--[=[

FIXME:

--]=]

local lang = require("Module:languages").getByCode("pt")
local m_string_utilities = require("Module:string utilities")
local m_links = require("Module:links")
local m_table = require("Module:table")
local iut = require("Module:inflection utilities")
local com = require("Module:pt-common")

local force_cat = false -- set to true for debugging
local check_for_red_links = false -- set to false for debugging

local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local rsub = com.rsub
local u = mw.ustring.char

local function link_term(term)
	return m_links.full_link({ lang = lang, term = term }, "term")
end


local V = com.V -- vowel regex class
local AV = com.AV -- accented vowel regex class
local C = com.C -- consonant regex class

local AC = u(0x0301) -- acute =  ́
local GR = u(0x0300) -- grave =  ̀
local CFLEX = u(0x0302) -- circumflex =  ̂

local short_pp_footnote = "[usually used with auxiliary verbs " .. link_term("ser") .. " and " .. link_term("estar") .. "]"
local long_pp_footnote = "[usually used with auxiliary verbs " .. link_term("haver") .. " and " .. link_term("ter") .. "]"

local vowel_alternants = m_table.listToSet({"i", "í", "u", "ú", "ei", "+"})
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
	["3s"] = "3|s",
	["1p"] = "1|p",
	["2p"] = "2|p",
	["3p"] = "3|p",
}

local person_number_list_basic = {"1s", "2s", "3s", "1p", "2p", "3p"}
local imp_person_number_list = {"2s", "3s", "1p", "2p", "3p"}
local neg_imp_person_number_list = {"2s", "3s", "1p", "2p", "3p"}

person_number_to_reflexive_pronoun = {
	["1s"] = "me",
	["2s"] = "te",
	["3s"] = "se",
	["1p"] = "nos",
	["2p"] = "os",
	["3p"] = "se",
}


-- Initialize all the slots for which we generate forms. The particular slots may depend on whether we're generating
-- combined slots (`not alternant_multiword_spec.nocomb`, which is always false if we're dealing with a verb with an
-- attached clitic, such as [[hincarla]], or a reflexive or partly-reflexive verb, where a partly-reflexive verb is
-- a conjoined term made up of two or more verbs, where some but not all are reflexive). It may also depend on whether
-- we're being requested to generate some double-combined forms, such as [[llevándoselo]]; see the comment below for
-- `verb_slot_double_combined_rows`.
local function add_slots(alternant_multiword_spec)
	-- "Basic" slots: All slots that go into the regular table (not the combined-form table).
	alternant_multiword_spec.verb_slots_basic = {
		{"infinitive", "inf"},
		{"infinitive_linked", "inf"},
		{"gerund", "ger"},
		{"pp_ms", "m|s|past|part"},
		{"pp_fs", "f|s|past|part"},
		{"pp_mp", "m|p|past|part"},
		{"pp_fp", "f|p|past|part"},
	}

	-- Slots that go into the combined-form table, along with double-combined slots (e.g. [[llevándoselo]]) that are
	-- requested for use with {{pt-verb form of}}.
	alternant_multiword_spec.verb_slots_combined = {}

	-- Special slots used to handle non-reflexive parts of reflexive verbs in {{pt-verb form of}}.
	-- For example, for a reflexive-only verb like [[jambarse]], we want to be able to use {{pt-verb form of}} on
	-- [[jambe]] (which should mention that it is a part of 'me jambe', first-person singular present subjunctive, and
	-- 'se jambe', third-person singular present subjunctive) or on [[jambamos]] (which should mention that it is a
	-- part of 'nos jambamos', first-person plural present indicative or preterite). Similarly, we want to use
	-- {{pt-verb form of}} on [[jambando]] (which should mention that it is a part of 'se ... jambando', syntactic
	-- variant of [[jambándose]], which is the gerund of [[jambarse]]). To do this, we need to be able to map
	-- non-reflexive parts like [[jambe]], [[jambamos]], [[jambando]], etc. to their reflexive equivalent(s), to the
	-- tag(s) of the equivalent(s), and, in the case of forms like [[jambando]], [[jambar]] and imperatives, to the
	-- separated syntactic variant of the verb+clitic combination. We do this by creating slots for the non-reflexive
	-- part equivalent of each basic reflexive slot, and for the separated syntactic-variant equivalent of each basic
	-- reflexive slot that is formed of verb+clitic. We use slots in this way to deal with multiword lemmas. Note that
	-- we run into difficulties mapping between reflexive verbs, non-reflexive part equivalents, and separated syntactic
	-- variants if a slot contains more than one form. To handle this, if there are the same number of forms in two
	-- slots we're trying to match up, we assume the forms match one-to-one; otherwise we don't match up the two slots
	-- (which means {{pt-verb form of}} won't work in this case, but such a case is extremely rare and not worth
	-- worrying about). Alternatives that handle this "properly" are significantly more complicated and require
	-- non-trivial modifications to [[Module:inflection utilities]].
	local need_special_verb_form_of_slots = alternant_multiword_spec.from_verb_form_of and alternant_multiword_spec.refl

	if need_special_verb_form_of_slots then
		alternant_multiword_spec.verb_slots_reflexive_verb_form_of = {
			{"infinitive_non_reflexive", "-"},
			{"infinitive_variant", "-"},
			{"gerund_non_reflexive", "-"},
			{"gerund_variant", "-"},
		}
	else
		alternant_multiword_spec.verb_slots_reflexive_verb_form_of = {}
	end

	-- For generating combined forms, i.e. combinations of a basic form (specifically, infinitive, gerund or an
	-- imperative form) with a clitic (or in some cases, two clitics). This is a list of lists of the form
	-- {BASIC_SLOT, CLITICS} where BASIC_SLOT is the slot to add the clitic pronouns to (e.g. "gerund" or "imp_2s")
	-- and CLITICS is a list of the clitic pronouns to add.
	alternant_multiword_spec.verb_slot_combined_rows = {}

	-- For generating double combined forms (e.g. [[llevándoselo]] or [[dámela]]). This is used by {{pt-verb form of}}
	-- when it detects that it is being requested to find the inflection tags for a double-combined form. The number of
	-- double-combined forms is relatively large, so to optimize this, [[Module:pt-inflections]] (which implements
	-- {{pt-verb form of}}) detects which two clitics are involved, and we only generate double-combined forms
	-- involving those two clitics; this is specified using `double_combined_forms_to_include`, passed into
	-- do_generate_forms(). The value of this field is a list of lists of the form {SINGLE_COMB_SLOT, CLITICS} where
	-- SINGLE_COMB_SLOT is the single-combined slot to add the object clitic pronouns to (e.g. "gerund_comb_se" or
	-- "imp_2s_comb_me") and CLITICS is a list of the clitic pronouns to add. CLITICS will normally be a length-one
	-- list whose value is one of {"lo", "la", "le", "los", "las", "les"}.
	alternant_multiword_spec.verb_slot_double_combined_rows = {}

	-- Add entries for a slot with person/number variants.
	-- `verb_slots` is the table to add to.
	-- `slot_prefix` is the prefix of the slot, typically specifying the tense/aspect.
	-- `tag_suffix` is a string listing the set of inflection tags to add after the person/number tags.
	-- `person_number_list` is a list of the person/number slot suffixes to add to `slot_prefix`.
	local function add_personal_slot(verb_slots, slot_prefix, tag_suffix, person_number_list)
		for _, persnum in ipairs(person_number_list) do
			local persnum_tag = all_persons_numbers[persnum]
			local slot = slot_prefix .. "_" .. persnum
			local accel = persnum_tag .. "|" .. tag_suffix
			table.insert(verb_slots, {slot, accel})
		end
	end

	-- Add a personal slot (i.e. a slot with person/number variants) to `verb_slots_basic`.
	local function add_basic_personal_slot(slot_prefix, tag_suffix, person_number_list, no_special_verb_form_of_slot,
		need_variant_slot)
		add_personal_slot(alternant_multiword_spec.verb_slots_basic, slot_prefix, tag_suffix, person_number_list)
		-- Add special slots for handling non-reflexive parts of reflexive verbs in {{pt-verb form of}}.
		-- See comment above in `need_special_verb_form_of_slots`.
		if need_special_verb_form_of_slots and not no_special_verb_form_of_slot then
			for _, persnum in ipairs(person_number_list) do
				local persnum_tag = all_persons_numbers[persnum]
				local basic_slot = slot_prefix .. "_" .. persnum
				local accel = persnum_tag .. "|" .. tag_suffix
				table.insert(alternant_multiword_spec.verb_slots_reflexive_verb_form_of, {basic_slot .. "_non_reflexive", "-"})
				if need_variant_slot then
					table.insert(alternant_multiword_spec.verb_slots_reflexive_verb_form_of, {basic_slot .. "_variant", "-"})
				end
			end
		end
	end

	add_basic_personal_slot("pres", "pres|ind", person_number_list_voseo)
	add_basic_personal_slot("impf", "impf|ind", person_number_list_basic)
	add_basic_personal_slot("pret", "pret|ind", person_number_list_basic)
	add_basic_personal_slot("fut", "fut|ind", person_number_list_basic)
	add_basic_personal_slot("cond", "cond", person_number_list_basic)
	add_basic_personal_slot("pres_sub", "pres|sub", person_number_list_voseo)
	add_basic_personal_slot("impf_sub_ra", "impf|sub", person_number_list_basic)
	add_basic_personal_slot("impf_sub_se", "impf|sub", person_number_list_basic)
	add_basic_personal_slot("fut_sub", "fut|sub", person_number_list_basic)
	-- Need variant slots because the imperative clitics are suffixed.
	add_basic_personal_slot("imp", "imp", imp_person_number_list, nil, "need variant slot")
	-- Don't need special non-reflexive-part slots because the negative imperative is multiword, of which the
	-- individual words are 'no' + subjunctive.
	add_basic_personal_slot("neg_imp", "neg|imp", neg_imp_person_number_list, "no special verb form of")
	-- Don't need special non-reflexive-part slots because we don't want [[jambando]] mapping to [[jambándome]]
	-- (only [[jambándose]]) or [[jambar]] mapping to [[jambarme]] (only [[jambarse]]).
	add_basic_personal_slot("infinitive", "inf", person_number_list_basic, "no special verb form of")
	add_basic_personal_slot("gerund", "ger", person_number_list_basic, "no special verb form of")

	local third_person_object_clitics = {"lo", "la", "le", "los", "las", "les"}

	-- Add combined-form slots.
	if not alternant_multiword_spec.nocomb then
		-- Add a row of slots representing the combination of a basic slot with a clitic. `basic_slot` is the basic slot
		-- descriptor, `tag_prefix` is a string describing the inflection tags of the basic slot, and `personal_clitics`
		-- is a list of the personal clitics ("me", "te", "se", "nos" or "os") to add to the basic slot.
		local function add_combined_slot_row(basic_slot, tag_prefix, personal_clitics)
			-- First, add each individual combined slot to `verb_slots_combined`.
			local clitics_with_object = m_table.append(personal_clitics, third_person_object_clitics)
			for _, clitic in ipairs(clitics_with_object) do
				local slot = basic_slot .. "_comb_" .. clitic
				-- You have to pass this through full_link() to get a Portuguese-specific link
				local accel = tag_prefix .. "|combined with [[" .. clitic .. "]]"
				table.insert(alternant_multiword_spec.verb_slots_combined, {slot, accel})
			end

			-- Also, add the row to `verb_slot_combined_rows`.
			table.insert(alternant_multiword_spec.verb_slot_combined_rows, {basic_slot, clitics_with_object})

			-- Also do double-combined forms for a specific set of clitics, if requested. See the comment above
			-- `verb_slot_double_combined_rows` above.
			if alternant_multiword_spec.double_combined_forms_to_include then
				for _, personal_clitic in ipairs(personal_clitics) do
					for _, object_clitic in ipairs(third_person_object_clitics) do
						for _, form_to_include in ipairs(alternant_multiword_spec.double_combined_forms_to_include) do
							local to_include_personal_clitic, to_include_object_clitic = unpack(form_to_include)
							if personal_clitic == to_include_personal_clitic and object_clitic == to_include_object_clitic then
								local single_comb_slot = basic_slot .. "_comb_" .. personal_clitic
								local slot = single_comb_slot .. "_" .. object_clitic
								local accel = tag_prefix .. "|combined with [[" .. personal_clitic .. "]] and [[" ..
									object_clitic .. "]]"
								table.insert(alternant_multiword_spec.verb_slots_combined, {slot, accel})
								table.insert(alternant_multiword_spec.verb_slot_double_combined_rows,
									{single_comb_slot, {object_clitic}})
								break
							end
						end
					end
				end
			end
		end

		add_combined_slot_row("infinitive", "inf", {"me", "te", "se", "nos", "os"})
		add_combined_slot_row("gerund", "gerund", {"me", "te", "se", "nos", "os"})

		local function add_combined_imp_slot_row(persnum, personal_clitics)
			add_combined_slot_row("imp_" .. persnum, all_persons_numbers[persnum] .. "|imp", personal_clitics)
		end
		add_combined_imp_slot_row("2s", {"me", "te", "nos"})
		add_combined_imp_slot_row("3s", {"me", "se", "nos"})
		add_combined_imp_slot_row("1p", {"te", "nos", "os"})
		add_combined_imp_slot_row("2p", {"me", "nos", "os"})
		add_combined_imp_slot_row("3p", {"me", "se", "nos"})
	end

	-- Generate the list of all slots.
	alternant_multiword_spec.all_verb_slots = {}
	for _, slot_and_accel in ipairs(alternant_multiword_spec.verb_slots_basic) do
		table.insert(alternant_multiword_spec.all_verb_slots, slot_and_accel)
	end
	for _, slot_and_accel in ipairs(alternant_multiword_spec.verb_slots_combined) do
		table.insert(alternant_multiword_spec.all_verb_slots, slot_and_accel)
	end
	for _, slot_and_accel in ipairs(alternant_multiword_spec.verb_slots_reflexive_verb_form_of) do
		table.insert(alternant_multiword_spec.all_verb_slots, slot_and_accel)
	end

	alternant_multiword_spec.verb_slots_basic_map = {}
	for _, slotaccel in ipairs(alternant_multiword_spec.verb_slots_basic) do
		local slot, accel = unpack(slotaccel)
		alternant_multiword_spec.verb_slots_basic_map[slot] = accel
	end

	alternant_multiword_spec.verb_slots_combined_map = {}
	for _, slotaccel in ipairs(alternant_multiword_spec.verb_slots_combined) do
		local slot, accel = unpack(slotaccel)
		alternant_multiword_spec.verb_slots_combined_map[slot] = accel
	end
end


-- Useful as the value of the `match` property of an irregular verb. `main_verb_spec` is a Lua pattern that should match
-- the non-prefixed part of a verb, and `prefix_specs` is a list of Lua patterns that should match the prefixed part of
-- a verb. If a prefix spec is preceded by ^, it must match exactly at the beginning of the verb; otherwise, additional
-- prefixes (e.g. re-, des-) may precede. Return the prefix and main verb.
local function match_against_verbs(main_verb_spec, prefix_specs)
	return function(verb)
		for _, prefix_spec in ipairs(prefix_specs) do
			if prefix_spec:find("^%^") then
				-- must match exactly
				prefix_spec = prefix_spec:gsub("^%^", "")
				if prefix_spec == "" then
					-- We can't use the second branch of the if-else statement because an empty () returns the current position
					-- in rmatch().
					local main_verb = rmatch(verb, "^(" .. main_verb_spec .. ")$")
					if main_verb then
						return "", main_verb
					end
				else
					local prefix, main_verb = rmatch(verb, "^(" .. prefix_spec .. ")(" .. main_verb_spec .. ")$")
					if prefix then
						return prefix, main_verb
					end
				end
			else
				local prefix, main_verb = rmatch(verb, "^(.*" .. prefix_spec .. ")(" .. main_verb_spec .. ")$")
				if prefix then
					return prefix, main_verb
				end
			end
		end
		return nil
	end
end

--[=[

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

-- pres_unstressed: The present indicative unstressed stem (1p, 2p). Also controls the imperative 2p
     and gerund. Defaults to the infinitive stem.
-- pres_stressed: The present indicative stressed stem (1s, 2s, 3s, 3p). Also controls the imperative 2s.
     Default is empty if indicator `no_pres_stressed`, else a vowel alternation if such an indicator is given
	 (e.g. `ue`, `ì`), else the infinitive stem.
-- pres1_and_sub: Overriding stem for 1s present indicative and the entire subjunctive. Only set by irregular verbs
     and by the indicators `no_pres_stressed` (e.g. [[precaver]]) and `no_pres1_and_sub` (since verbs of this sort,
	 e.g. [[puir]], are missing the entire subjunctive as well as the 1s present indicative). Used by many irregular
	 verbs, e.g. [[caber]], verbs in '-air', [[dizer], [[ter]], [[valer]], etc. Some verbs set this and then supply an
	 override for the pres_1sg if it's irregular, e.g. [[saber]], with irregular subjunctive stem "saib-" and special
	 1s present indicative "sei".
-- pres1: Special stem for 1s present indicative. Normally, do not set this explicitly. If you need to specify an
     irregular 1s present indicative, use the form override pres_1s= to specify the entire form. Defaults to
	 pres1_and_sub if given, else pres_stressed.
-- pres_sub_unstressed: The present subjunctive unstressed stem (1p, 2p). Defaults to pres1_and_sub if given, else the
     infinitive stem.
-- pres_sub_stressed: The present subjunctive stressed stem (1s, 2s, 3s, 1p). Defaults to pres1.
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
-- pp_inv: FIXME
]=]

local irreg_conjugations = {

	--------------------------------------------------------------------------------------------
	--                                             -ar                                        --
	--------------------------------------------------------------------------------------------

	-- Verbs not needing entries here:
	--
	-- (1) Verbs with short past participles: need to specify the short pp explicitly.
	--
	-- aceitar: use <short_pp:aceito[Brazil],aceite[Portugal]>
	-- anexar, completar, expressar, expulsar, findar, fritar, ganhar, gastar, limpar, pagar, pasmar, pegar, soltar:
	--   use <short_pp:anexo> etc.
	-- assentar: use <short_pp:assente>
	-- entregar: use <short_pp:entregue>
	-- enxugar: use <short_pp:enxuto>
	-- matar: use <short_pp:morto>
	--
	-- (2) Verbs with orthographic consonant alternations: handled automatically.
	--
	-- -car (brincar, buscar, pecar, trancar, etc.): automatically handled in combine_stem_ending()
	-- -çar (alcançar, começar, laçar): automatically handled in combine_stem_ending()
    -- -gar (apagar, cegar, esmagar, largar, navegar, resmungar, sugar, etc.): automatically handled in combine_stem_ending()
	-- (3) Verbs with vowel alternations: need to specify the alternation explicitly unless it always happens, in
	--     which case it's handled automatically through an entry below.
	--
	-- esmiuçar changing to esmiúço: use <ú>
	-- faiscar changing to faísco: use <í>
	-- -iar changing to -eio (ansiar, incendiar, mediar, odiar, remediar, etc.): use <ei>
	-- -izar changing to -ízo (ajuizar, enraizar, homogeneizar, plebeizar, etc.): use <í>
	-- mobiliar changing to mobílio: use <í>
	-- reusar changing to reúso: use <ú>
	-- saudar changing to saúdo: use <ú>
	-- tuitar/retuitar changing to (re)tuíto: use <í>

	{
		-- dar, desdar
		match = match_against_verbs("dar", {"^", "des"}),
		forms = {
			pres_1s = "dou",
			pres_2s = "dás",
			pres_3s = "dá",
			-- damos, dais regular
			pres_3p = "dão",
			pret = "dé", pret_conj = "irreg", pret_1s = "dei", pret_3s = "deu",
			pres_sub_1s = "dê",
			pres_sub_2s = "dês",
			pres_sub_3s = "dê",
			-- deis regular
			pres_sub_1p = "dêmos",
			pres_sub_3p = "deem",
		}
	},
	{
		-- -ear (frear, nomear, semear, etc.)
		match = "ear",
		forms = {
			pres_stressed = "ei",
		}
	},
	{
		-- estar
		match = "^estar",
		forms = {
			pres_1s = "estou",
			pres_2s = "estás",
			pres_3s = "está",
			-- FIXME, estámos is claimed as an alternative pres_1p in the old conjugation data, but I believe this is garbage
			pres_3p = "estão",
			pres1_and_sub = "estej", -- only for subjunctive as we override pres_1s
			pret = "estivé", pret_conj = "irreg", pret_1s = "estive", pret_3s = "esteve",
			pp_inv = true,
		}
	},
	{
		-- sobestar, sobrestar
		match = match_against_verbs("estar", {"sob", "sobr"}),
		forms = {
			pres_1s = "estou",
			pres_2s = "estás",
			pres_3s = "está",
			-- FIXME, estámos is claimed as an alternative pres_1p in the old conjugation data, but I believe this is garbage
			pres_3p = "estão",
			pres1_and_sub = "estej", -- only for subjunctive as we override pres_1s
			pret = "estivé", pret_conj = "irreg", pret_1s = "estive", pret_3s = "esteve",
			-- does not have pp_inv
		}
	},
	{
		-- folegar, resfolegar, tresfolegar
		match = "folegar",
		forms = {
			pres_stressed = {"fóleg", "foleg"},
		}
	},
	{
		-- aguar/desaguar/enxaguar, ambiguar/apaziguar/averiguar, minguar, cheguar?? (obsolete variant of [[chegar]])
		match = "guar",
		forms = {
			-- combine_stem_ending() will move the acute accent backwards so it sits after the last vowel in [[minguar]]
			pres_stressed = {{form = AC .. "gu", footnotes = {"[Brazil]"}}, {form = "gu", footnotes = {"[Portugal]"}}},
			pres_sub_stressed = {
				{form = AC .. "gu", footnotes = {"[Brazil]"}},
				{form = "gu", footnotes = {"[Portugal]"}},
				{form = AC .. "gü", footnotes = {"[Brazil]", "[superseded]"}},
				{form = "gú", footnotes = {"[Portugal]", "[superseded]"}},
			},
			pres_sub_unstressed = {"gu", {form = "gü", footnotes = {"[Brazil]", "[superseded]"}}},
			pret_1s = {"guei", {form = "güei", footnotes = {"[Brazil]", "[superseded]"}}},
		}
	},
	{
		-- adequar/readequar, antiquar/obliquar, apropinquar
		match = "quar",
		forms = {
			-- combine_stem_ending() will move the acute accent backwards so it sits after the last vowel in [[apropinquar]]
			pres_stressed = {{form = AC .. "qu", footnotes = {"[Brazil]"}}, {form = "qu", footnotes = {"[Portugal]"}}},
			pres_sub_stressed = {
				{form = AC .. "qu", footnotes = {"[Brazil]"}},
				{form = "qu", footnotes = {"[Portugal]"}},
				{form = AC .. "qü", footnotes = {"[Brazil]", "[superseded]"}},
				{form = "qú", footnotes = {"[Portugal]", "[superseded]"}},
			},
			pres_sub_unstressed = {"qu", {form = "qü", footnotes = {"[Brazil]", "[superseded]"}}},
			pret_1s = {"quei", {form = "qüei", footnotes = {"[Brazil]", "[superseded]"}}},
		}
	},
	{
		-- -oar (abençoar, coroar, enjoar, perdoar, etc.)
		match = "oar",
		forms = {
			pres_1s = {"oo", {form = "ôo", footnotes = {"[superseded]"}}},
		}
	},
	{
		-- -oiar (apoiar, boiar)
		match = "oiar",
		forms = {
			pres_stressed = {"oi", {form = "ói", footnotes = {"[Brazil]", "[superseded]"}}},
		}
	},
	{
		-- parar
		match = "^parar",
		forms = {
			pres_3s = {"para", {form = "pára", footnotes = {"[superseded]"}}},
		}
	},
	{
		-- pelar
		match = "^pelar",
		forms = {
			pres_1s = {"pelo", {form = "pélo", footnotes = {"[superseded]"}}},
			pres_2s = {"pelas", {form = "pélas", footnotes = {"[superseded]"}}},
			pres_3s = {"pela", {form = "péla", footnotes = {"[superseded]"}}},
		}
	},

	--------------------------------------------------------------------------------------------
	--                                             -er                                        --
	--------------------------------------------------------------------------------------------

	-- Verbs not needing entries here:
	--
	-- precaver: use <no_pres_stressed>
	-- -cer (verbs in -ecer, descer, vencer, etc.): automatically handled in combine_stem_ending()
	-- -ger (proteger, reger, etc.): automatically handled in combine_stem_ending()
	-- -guer (erguer/reerguer/soerguer): automatically handled in combine_stem_ending()

	{
		-- benzer
		match = "benzer",
		forms = {short_pp = "bento"}
	},
	{
		-- caber
		match = "caber",
		forms = {
			pres1_and_sub = "caib",
			pret = "coubé", pret_1s = "coube", pret_3s = "coube", pret_conj = "irreg"
		}
	},
	{
		-- crer, descrer
		match = "crer",
		forms = {
			pres_2s = "crês", pres_3s = "crê",
			pres_2p = "credes", pres_3p = {"creem", {form = "crêem", footnotes = {"[superseded]"}}},
			pres1_and_sub = "crei",
		},
	},
	{
		-- dizer, bendizer, condizer, contradizer, desdizer, maldizer, predizer, etc.
		match = "dizer",
		forms = {
			-- use 'digu' because we're in a front environment; if we use 'dig', we'll get '#dijo'
			pres1_and_sub = "digu", pres_3s = "diz",
			pret = "dissé", pret_conj = "irreg", pret_1s = "disse", pret_3s = "disse", pp = "dito",
			fut = "dir",
			imp_2s = {"diz", "dize"}, -- per Infopédia
		}
	},
	{
		-- eleger, reeleger
		match = "eleger",
		forms = {short_pp = "eleito"}
	},
	{
		-- acender, prender; not desprender, etc.
		match = match_against_verbs("ender", {"^ac", "^pr"}),
		forms = {short_pp = "eso"}
	},
	{
		-- fazer, afazer, contrafazer, desfazer, liquefazer, perfazer, putrefazer, rarefazer, refazer, satisfazer, tumefazer
		match = "fazer",
		forms = {
			pres1_and_sub = "faç", pres_3s = "faz",
			pret = "fizé", pret_conj = "irreg", pret_1s = "fiz", pret_3s = "fez", pp = "feito",
			fut = "far",
		}
	},
	{
		match = "^haber",
		forms = {
			pres_1s = "hei",
			pres_2s = "hás",
			pres_3s = "há",
			pres_1p = {"havemos", "hemos"},
			pres_2p = {"haveis", "heis"},
			pres_3p = "hão",
			pres1_and_sub = "haj", -- only for subjunctive as we override pres_1s
			pret = "houvé", pret_conj = "irreg", pret_1s = "houve", pret_3s = "houve",
			imp_2p = "havei",
		}
	},
	-- reaver below under r-
	{
		-- jazer, adjazer
		match = "jazer",
		forms = {
			pres_3s = "jaz",
			imp_2s = {"jaz", "jaze"}, -- per Infopédia
		}
	},
	{
		-- ler, reler, tresler; not excel(l)er, valer, etc.
		match = match_against_verbs("ler", {"^", "^re", "tres"}),
		forms = {
			pres_2s = "lês", pres_3s = "lê",
			pres_2p = "ledes", pres_3p = {"leem", {form = "lêem", footnotes = {"[superseded]"}}},
			pres1_and_sub = "lei",
		},
	},
	{
		-- morrer, desmorrer
		match = "morrer",
		forms = {short_pp = "morto"}
	},
	{
		-- doer, moer/remoer, roer/corroer, soer
		-- doer should be handled using 'only3sp'
		-- soer should be handled using 'no_pres1_and_sub'
		match = "oer",
		forms = {
			pres_1s = {"oo", {form = "ôo", footnotes = {"[superseded]"}}}, pres_2s = "óis", pres_3s = "ói",
			-- impf -ía etc., pret_1s -oí and pp -oído handled automatically in combine_stem_ending()
		}
	},
	{
		-- perder
		match = "perder",
		forms = {pres1_and_sub = "perc"}
	},
	{
		-- poder
		match = "poder",
		forms = {
			pres1_and_sub = "poss",
			pret = "pudé", pret_1s = "pude", pret_3s = "pôde", pret_conj = "irreg",
		}
	},
	{
		-- prazer, aprazer, desprazer; should use 'only3s'
		match = "prazer",
		forms = {
			pres_3s = "praz",
			pret = "prouvé", pret_1s = "prouve", pret_3s = "prouve", pret_conj = "irreg",
		}
	},
	-- prover below, just below ver
	{
		-- requerer; must precede querer
		match = "requerer",
		forms = {
			-- old module claims alt pres_3s 'requere' and alt imp_2s 'requere'; not in Infopédia, which lists
			-- alt imp_2s 'quere' for [[querer]]
			pres_1s = "requero", pres_3s = "requer",
			pres1_and_sub = "requeir", -- only for subjunctive as we override pres_1s
			-- regular preterite, unlike [[querer]]
		},
	},
	{
		-- querer, desquerer, malquerer
		match = "querer",
		forms = {
			-- old module claims alt pres_3s 'quere'; not in Infopédia, which lists alt imp_2s 'quere'
			pres_1s = "quero", pres_3s = "quer",
			pres1_and_sub = "queir", -- only for subjunctive as we override pres_1s
			pret = "quisé", pret_1s = "quis", pret_3s = "quis", pret_conj = "irreg",
			imp_2s = {"quer", "quere"}, -- per Infopédia
		},
	},
	{
		match = "reaver",
		forms = {
			no_pres_stressed = true,
			pret = "reouvé", pret_conj = "irreg", pret_1s = "reouve", pret_3s = "reouve",
		}
	},
	{
		-- saber, resaber
		match = "saber",
		forms = {
			pres_1s = "sei",
			pres1_and_sub = "saib", -- only for subjunctive as we override pres_1s
			pret = "soubé", pret_1s = "soube", pret_3s = "soube", pret_conj = "irreg",
		}
	},
	{
		-- escrever/reescrever, circunscrever, descrever/redescrever, inscrever, prescrever, proscrever, subscrever,
		-- transcrever, others?
		match = "screver",
		forms = {pp = "scrito"}
	},
	{
		-- suspender
		match = "suspender",
		forms = {short_pp = "suspenso"}
	},
	{
		match = "^ser",
		forms = {
			pres_1s = "sou", pres_2s = "és", pres_3s = "é",
			pres_1p = "somos", pres_2p = "sois", pres_3p = "são",
			pres1_and_sub = "sej", -- only for subjunctive as we override pres_1s
			full_impf = "er", impf_1p = "éramos", impf_2p = "éreis",
			pret = "fô", pret_1s = "fui", pret_3s = "foi", pret_conj = "irreg",
			imp_2s = "sê", imp_2p = "sede",
		}
	},
	{
		-- We want to match abster, conter, deter, etc. but not abater, cometer, etc. No way to avoid listing each verb.
		match = match_against_verbs("ter", {"abs", "^a", "con", "de", "entre", "man", "ob", "^re", "sus", "^"}),
		forms = {
			-- the initial # indicates that the accent disappears in the simplex form [[ter]]
			pres_2s = "#téns", pres_3s = "#tém", pres_2p = "tendes", pres_3p = "têm",
			pres1_and_sub = "tenh",
			full_impf = "tinh", impf_1p = "tínhamos", impf_2p = "tínheis",
			pret = "tivé", pret_1s = "tive", pret_3s = "teve", pret_conj = "irreg",
		}
	},
	{
		match = "trazer",
		forms = {
			-- use 'tragu' because we're in a front environment; if we use 'trag', we'll get '#trajo'
			pres1_and_sub = "tragu", pres_3s = "traz",
			pret = "trouxé", pret_1s = "trouxe", pret_3s = "trouxe", pret_conj = "irreg",
			fut = "trar",
		}
	},
	{
		-- valer, desvaler, equivaler
		match = "valer",
		forms = {pres1_and_sub = "valh"}
	},
	{
		-- We want to match antever etc. but not absolver, atrever etc. No way to avoid listing each verb.
		match = match_against_verbs("ver", {"ante", "entre", "pre", "^re", "^"}),
		forms = {
			pres_2s = "vês", pres_3s = "vê",
			pres_2p = "vedes", pres_3p = {"veem", {form = "vêem", footnotes = {"[superseded]"}}},
			pres1_and_sub = "vej",
			pret = "ví", pret_1s = "vi", pret_3s = "viu", pret_conj = "irreg",
			pp = "visto",
		}
	},
	{
		-- prover, desprover
		match = "prover",
		forms = {
			pres_2s = "vês", pres_3s = "vê",
			pres_2p = "vedes", pres_3p = {"veem", {form = "vêem", footnotes = {"[superseded]"}}},
			pres1_and_sub = "vej",
			pret = "ví", pret_1s = "vi", pret_3s = "viu", pret_conj = "irreg",
			-- pp is regular, unlike other compounds of [[ver]]
		}
	},
	{
		-- Only envolver, revolver. Not volver, desenvolver, devolver, evolver, etc.
		match = match_against_verbs("volver", {"^en", "^re"}),
		forms = {short_pp = "volto"},
	},

	--------------------------------------------------------------------------------------------
	--                                             -ir                                        --
	--------------------------------------------------------------------------------------------

	-- Verbs not needing entries here:
	--
	-- abolir: use <u-o> (claimed in old module to have no pres1 or pres sub, but Priberam disagrees)
	-- barrir: use <only3sp>
	-- carpir, colorir/descolorir, demolir: use <no_pres1_and_sub>
	-- delir, empedernir, espavorir, falir, florir, remir, renhir: use <no_pres_stressed>
	-- empedernir: use <i-e> (claimed in old module to have no pres stressed, but Priberam disagrees)
	-- transir: totally regular (claimed in old module to have no pres stressed, but Priberam disagrees)
	-- aspergir, despir, flectir/deflectir/reflectir, mentir/desmentir,
	--   sentir/assentir/consentir/dissentir/pressentir/ressentir, convergir/divergir, aderir/adherir,
	--   ferir/auferir/conferir/deferir/desferir/diferir/differir/inferir/interferir/preferir/preferir/referir/transferir,
	--   gerir/digerir/ingerir/sugerir, preterir, competir/repetir, servir, advertir/divertir,
	--   vestir/investir/revestir/travestir,
	--   seguir/conseguir/desconseguir/desseguir/perseguir/prosseguir: use <i-e>
	-- inerir: use <i-e> (per Infopédia), use <only3sp> (per Priberam)
	-- dormir, engolir, tossir, subir, acudir/sacudir, fugir, sumir/consumir: use <u-o>
	-- polir/repolir (claimed in old module to have no pres stressed, but Priberam disagrees; Infopédia lists
	--   repolir as completely regular and not like polir, but I think that's an error): use <u>
	-- premir (claimed in old module to have no pres1 or sub, but Priberam and Infopédia disagree; Priberam says
	--   primo/primes/prime, while Infopédia says primo/premes/preme; Priberam is probably more reliable): use <i>
	-- extorquir/retorquir (claimed in old module to have no pres1 or sub, but Priberam disagrees): use <u-o,u>
	-- agredir/progredir/regredir/transgredir: use <i>
	-- cerzir/cergir: use <i-e,i> (per Infopédia; Priberam just says <i-e>)
	-- proibir/coibir: use <í>
	-- reunir: use <ú>
	-- parir/malparir: use <no_pres_stressed> (old module had pres_1s = {paro (1_defective), pairo (1_obsolete_alt)},
	--   pres_2s = pares, pres_3s = pare, and subjunctive stem par- or pair-, but both Priberam and Infopédia agree
	--   in these verbs being no_pres_stressed)
	-- explodir/implodir: use <u-o> (claimed in old module to be <+,u-o> but neither Priberam nor Infopédia agree)
	--
	-- -cir alternations (aducir, ressarcir): automatically handled in combine_stem_ending()
	-- -gir alternations (agir, dirigir, exigir): automatically handled in combine_stem_ending()
	-- -guir alternations: automatically handled in combine_stem_ending()

	{
		-- verbs in -air (cair, sair, trair and derivatives: decair/descair/recair, sobres(s)air,
		-- abstrair/atrair/contrair/distrair/extrair/protrair/retrair/subtrair)
		match = "air",
		forms = {
			pres1_and_sub = "ai", pres_2s = "ais", pres_3s = "ai",
			-- all occurrences of accented í in endings handled in combine_stem_ending()
		}
	},
	{
		-- abrir/desabrir/reabrir, cobrir/descobrir/encobrir/recobrir/redescobrir
		match = "brir",
		forms = {pp = "berto"}
	},
	{
		-- conduzir, produzir, reduzir, traduzir, etc.
		match = "duzir",
		forms = {
			pres_3s = "duz",
			imp_2s = {"duz", "duze"}, -- per Infopédia
		}
	},
	{
		-- pedir, desimpedir, despedir, espedir, expedir, impedir
		-- medir
		-- comedir (claimed in old module to have no pres stressed, but Priberam disagrees)
		match = match_against_verbs("edir", {"m", "p"}),
		forms = {pres1_and_sub = "eço"},
	},
	{
		-- frigir
		match = "frigir",
		forms = {vowel_alt = "i-e", short_pp = "frito"},
	},	
	{
		-- inserir
		match = "inserir",
		forms = {vowel_alt = "i-e", short_pp = "inserto"},
	},
	{
		-- ir
		match = "^ir",
		forms = {
			pres_1s = "vou", pres_2s = "vais", pres_3s = "vai",
			pres_1p = "vamos", pres_2p = "ides", pres_3p = "vão",
			pres_sub_1s = "vá", pres_sub_2s = "vás", pres_sub_3s = "vá",
			pres_sub_1p = "vamos", pres_sub_2p = "vades", pres_sub_3p = "vão",
			pret = "fô", pret_1s = "fui", pret_3s = "foi", pret_conj = "irreg",
		}
	},
	{
		-- emergir, imergir, submergir
		match = "mergir",
		forms = {vowel_alt = {"i-e", "+"}, short_pp = "merso"},
	},
	{
		match = "ouvir",
		forms = {pres1_and_sub = {"ouç", "oiç"}},
	},
	{
		-- old module says repelir specifically has short_pp = repulso but neither Infopédia nor Priberam agrees
		match = "pelir",
		forms = {pres1_and_sub = {{form = "pil", footnotes = "[per Infopédia; Priberam says these forms are missing]"}}},
	},
	{
		-- exprimir, imprimir but not comprimir/descomprimir, deprimir, oprimir/opprimir, reprimir, suprimir/supprimir
		-- exprimir with short_pp expresso per Infopédia
		match = match_against_verbs("primir", {"ex", "im"}),
		forms = {short_pp = "presso"}
	},
	{
		-- rir, sorrir
		match = match_against_verbs("rir", {"^", "sor"}),
		forms = {
			pres_2s = "ris", pres_3s = "ri", pres_2p = "rides", pres_3p = "riem",
			pres1_and_sub = "ri",
		},
	},
	{
		-- distinguir, extinguir
		match = "tinguir",
		forms = {
			short_pp = "tinto",
			-- gu/g alternations handled in combine_stem_ending()
		}
	},
	{
		-- delinquir, arguir/redarguir
		-- NOTE: The following is based on delinquir, with arguir/redarguir by parallelism.
		-- In Priberam, delinquir and arguir are exactly parallel, but in Infopédia they aren't; only delinquir has
		-- alternatives like 'delínques'. I assume this is because forms like 'delínques' are Brazilian and
		-- Infopédia is from Portugal, so their coverage of Brazilian forms may be inconsistent.
		match = match_against_verbs("uir", {"delinq", "arg"}),
		forms = {
			-- use 'ü' because we're in a front environment; if we use 'u', we'll get '#delinco', '#argo'
			pres1_and_sub = {{form = AC .. "ü", footnotes = {"[Brazil]"}}, {form = "ü", footnotes = {"[Portugal]"}}},
			-- FIXME: verify. This is by partial parallelism with the present subjunctive of verbs in -quar (also a
			-- front environment). Infopédia has 'delinquis ou delínques' and Priberam has 'delinqúis'.
			pres_2s = {
				{form = AC .. "ues", footnotes = {"[Brazil]"}},
				{form = "uis", footnotes = {"[Portugal]"}},
				-- This form should occur only with an infinitive 'delinqüir' etc.
				-- {form = AC .. "ües", footnotes = {"[Brazil]", "[superseded]"}},
				{form = "úis", footnotes = {"[Portugal]", "[superseded]"}},
			},
			-- Same as previous.
			pres_3s = {
				{form = AC .. "ue", footnotes = {"[Brazil]"}},
				{form = "ui", footnotes = {"[Portugal]"}},
				-- This form should occur only with an infinitive 'delinqüir' etc.
				-- {form = AC .. "üe", footnotes = {"[Brazil]", "[superseded]"}},
				{form = "úi", footnotes = {"[Portugal]", "[superseded]"}},
			},
			-- Infopédia has 'delinquem ou delínquem' and Priberam has 'delinqúem'.
			pres_3p = {
				{form = AC .. "uem", footnotes = {"[Brazil]"}},
				{form = "uem", footnotes = {"[Portugal]"}},
				-- This form should occur only with an infinitive 'delinqüir' etc.
				-- {form = AC .. "üem", footnotes = {"[Brazil]", "[superseded]"}},
				{form = "úem", footnotes = {"[Portugal]", "[superseded]"}},
			},
			-- FIXME: The old module also had several other alternative forms (given as [123]_alt, not identified as
			-- obsolete):
			-- impf: delinquia/delinquía, delinquias/delinquías, delinquia/delinquía, delinquíamos, delinquíeis, delinquiam/delinquíam
			-- plup: delinquira/delinquíra, delinquiras/delinquíras, delinquira/delinquíra, delinquíramos, delinquíreis, delinquiram/delinquíram
			-- pres_1p = delinquimos/delinquímos, pres_2p = delinquis/delinquís
			-- pret = delinqui/delinquí, delinquiste/delinquíste, delinquiu, delinquimos/delinquímos, delinquistes/delinquístes, delinquiram/delinquíram
			-- pers_inf = delinquir, delinquires, delinquir, delinquirmos, delinquirdes, delinquirem/delinquírem
			-- fut_sub = delinquir, delinquires, delinquir, delinquirmos, delinquirdes, delinquirem/delinquírem
			--
			-- None of these alternative forms can be found in the Infopédia, Priberam, Collins or Reverso conjugation
			-- tables, so their status is unclear, and I have omitted them.
		}
	},
	{
		-- verbs in -truir (construir, destruir, reconstruir) but not obstruir/desobstruir, instruir, which are handled
		-- by the default -uir handler below
		match = match_against_verbs("struir", {"con", "de"}),
		forms = {
			pres_2s = {"stróis", "struis"}, pres_3s = {"strói", "strui"}, pres_3p = {"stroem", "struem"}
			-- all occurrences of accented í in endings handled in combine_stem_ending()
		}
	},
	{
		-- puir, ruir: like -uir but defective in pres_1s, all pres sub
		match = match_against_verbs("uir", {"^p", "^r"}),
		forms = {
			pres_2s = "uis", pres_3s = "ui",
			no_pres1_and_sub = true,
		}
	},
	{
		-- remaining verbs in -uir (concluir/excluir/incluir/concruir/concruyr, abluir/diluir, afluir/fluir/influir,
		-- aluir, anuir, atribuir/contribuir/distribuir/redistribuir/retribuir/substituir, coevoluir/evoluir,
		-- constituir/destituir/instituir/reconstituir/restituir, derruir, diminuir, estatuir, fruir/usufruir, imbuir,
		-- imiscuir, poluir, possuir, pruir
		-- FIXME: old module lists short pp incluso for incluir that can't be verified, ask about this
		-- FIXME: handle -uyr verbs?
		match = function(verb)
			-- Don't match -guir verbs (e.g. seguir, conseguir).
			if verb:find("guir") then
				return nil
			else
				return match_against_verbs("uir", {""})
			end
		end,
		forms = {
			pres_2s = "uis", pres_3s = "ui",
			-- all occurrences of accented í in endings handled in combine_stem_ending()
		}
	},
	{
		-- We want to match advir, convir, devir, etc. but not ouvir, servir, etc. No way to avoid listing each verb.
		match = match_against_verbs("vir", {"ad", "^a", "con", "contra", "de", "^desa", "inter", "pro", "^re", "sobre", "^"}),
		forms = {
			-- the initial # indicates that the accent disappears in the simplex form [[vir]]
			pres_2s = "#véns", pres_3s = "#vém", pres_2p = "vindes", pres_3p = "vêm",
			pres1_and_sub = "venh",
			full_impf = "vinh", impf_1p = "vínhamos", impf_2p = "vínheis",
			pret = "vié", pret_1s = "vim", pret_3s = "veio", pret_conj = "irreg",
			pp = "vindo",
		}
	},

	--------------------------------------------------------------------------------------------
	--                                            misc                                        --
	--------------------------------------------------------------------------------------------

	{
		-- pôr, antepor, apor, compor/decompor/descompor, contrapor, depor, dispor, expor, impor, interpor, justapor,
		-- opor, pospor, propor, repor, sobrepor, supor/pressupor, transpor, others?
		match = function(verb)
			if verb == "pôr" then
				return "", "pôr"
			else
				return match_against_verbs("por", {""})
			end
		end,
		forms = {
			-- FIXME, we need some special-casing of the infinitive
			pres1_and_sub = "ponh",
			pres_2s = "pões", pres_3s = "põe", pres_1p = "pomos", pres_2p = "pondes", pres_3p = "põem",
			full_impf = "punh", impf_1p = "púnhamos", impf_2p = "púnheis",
			pret = "pusé", pret_1s = "pus", pret_3s = "pôs", pret_conj = "irreg",
			pers_inf = "por",
			ger = "pondo", pp = "posto",
		}
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

	if (base.only3s or base.only3sp or base.only3p) and (slot:find("^imp_") or slot:find("^neg_imp_")) then
		return true
	end

	if base.only3s and not slot:find("3s") then
		-- diluviar, atardecer, neviscar
		return true
	end

	if base.only3sp and not slot:find("3[sp]") then
		-- atañer, concernir
		return true
	end

	if base.only3p and not slot:find("3p") then
		-- [[caer cuatro gotas]], [[caer chuzos de punta]], [[entrarle los siete males]]
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


-- Apply vowel alternation to stem.
local function apply_vowel_alternation(stem, alternation)
	local ret, err
	-- Treat final -gu, -qu as a consonant, so the previous vowel can alternate (e.g. conseguir -> consigo).
	-- This means a verb in -guar can't have a u-ú alternation but I don't think there are any verbs like that.
	stem = rsub(stem, "([gq])u$", "%1" .. TEMPC1)
	local before_last_vowel, last_vowel, after_last_vowel = rmatch(stem, "^(.*)(" .. V .. ")(.-)$")
	if alternation == "ie" then
		if last_vowel == "e" or last_vowel == "i" then
			-- allow i for adquirir -> adquiero, inquirir -> inquiero, etc.
			ret = before_last_vowel .. "ie" .. after_last_vowel
		else
			err = "should have -e- or -i- as the last vowel"
		end
	elseif alternation == "ye" then
		if last_vowel == "e" then
			ret = before_last_vowel .. "ye" .. after_last_vowel
		else
			err = "should have -e- as the last vowel"
		end
	elseif alternation == "ue" then
		if last_vowel == "o" or last_vowel == "u" then
			-- allow u for jugar -> juego; correctly handle avergonzar -> avergüenzo
			ret = (
				last_vowel == "o" and before_last_vowel:find("g$") and before_last_vowel .. "üe" .. after_last_vowel or
				before_last_vowel .. "ue" .. after_last_vowel
			)
		else
			err = "should have -o- or -u- as the last vowel"
		end
	elseif alternation == "hue" then
		if last_vowel == "o" then
			ret = before_last_vowel .. "hue" .. after_last_vowel
		else
			err = "should have -o- as the last vowel"
		end
	elseif alternation == "i" then
		if last_vowel == "e" then
			ret = before_last_vowel .. "i" .. after_last_vowel
		else
			err = "should have -i- as the last vowel"
		end
	elseif alternation == "í" then
		if last_vowel == "i" then
			ret = before_last_vowel .. "í" .. after_last_vowel
		else
			err = "should have -i- as the last vowel"
		end
	elseif alternation == "ú" then
		if last_vowel == "u" then
			ret = before_last_vowel .. "ú" .. after_last_vowel
		else
			err = "should have -u- as the last vowel"
		end
	else
		error("Internal error: Unrecognized vowel alternation '" .. alternation .. "'")
	end
	ret = ret and ret:gsub(TEMPC1, "u") or nil
	return {ret = ret, err = err}
end


-- Add the `stem` to the `ending` for the given `slot` and apply any phonetic modifications.
-- `is_combining_ending` is true if `ending` is actually the ending (this function is also
-- called to combine prefix + stem). WARNING: This function is written very carefully; changes
-- to it can easily have unintended consequences.
local function combine_stem_ending(base, slot, stem, ending, is_combining_ending)
	if not is_combining_ending then
		return stem .. ending
	end

	-- If the ending begins with an acute accent, this is a signal to move the accent onto the last vowel of the stem.
	-- Cf. míngua of minguar.
	if ending:find("^" .. AC) then
		ending = rsub(ending, "^" .. AC, "")
		stem = rsub(stem, "([aeiouyAEIOUY])([^aeiouyAEIOUY]*)$", "%1" .. AC .. "%2")
	end

	-- If ending begins with i, it must get an accent after an unstressed vowel (in some but not all cases) to prevent
	-- the two merging into a diphthong:
	-- * cair ->
	-- *   pres: caímos, caís;
	-- *   impf: all forms (caí-);
	-- *   pret: caí, caíste (but not caiu), caímos, caístes, caíram;
	-- *   plup: all forms (caír-);
	-- *   impf_sub: all forms (caíss-);
	-- *   fut_sub: caíres, caírem (but not cair, cairmos, cairdes)
	-- *   pp: caído (but not gerund caindo)
	-- * atribuir, other verbs in -uir -> same pattern as for cair etc.
	-- * roer ->
	-- *   pret: roí
	-- *   impf: all forms (roí-)
	-- *   pp: roído
	if ending:find("^i") and stem:find("[aeiou]$") and ending ~= "ir" and ending ~= "iu" and ending ~= "indo" and
		not ending:find("^ir[md]") then
		ending = ending:gsub("^i", "í")
	end

	-- Spelling changes in the stem; it depends on whether the stem given is the pre-front-vowel or
	-- pre-back-vowel variant, as indicated by `frontback`. We want these front-back spelling changes to happen
	-- between stem and ending, not between prefix and stem; the prefix may not have the same "front/backness"
	-- as the stem.
	local is_front = rfind(ending, "^[eiéí]")
	if base.frontback == "front" and not is_front then
		stem = stem:gsub("c$", "ç") -- conhecer -> conheço, vencer -> venço, descer -> desço
		stem = stem:gsub("g$", "j") -- proteger -> protejo, fugir -> fujo
		stem = stem:gsub("gu$", "g") -- distinguir -> distingo, conseguir -> consigo
		stem = stem:gsub("([gq])ü$", "%1u") -- argüir (superseded) -> arguo, delinqüir (superseded) -> delinquo
	elseif base.frontback == "back" and is_front then
		-- The following changes are all superseded so we don't do them:
		-- averiguar -> averigüei, minguar -> mingüei; antiquar -> antiqüei, apropinquar -> apropinqüei
		-- stem = stem:gsub("([gq])u$", "%1ü")
		stem = stem:gsub("g$", "gu") -- cargar -> carguei, apagar -> apaguei
		stem = stem:gsub("c$", "qu") -- marcar -> marquei
		stem = rsub(stem, "ç$", "c") -- começar -> comecei
		-- j does not go to g here; desejar -> deseje not #desege
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
	local s2, s3, p1, p2, p3
	if base.conj == "ar" then
		s2, s3, p1, p2, p3 = "as", "a", "amos", "ais", "am"
	elseif base.conj == "er" then
		s2, s3, p1, p2, p3 = "es", "e", "emos", "eis", "em"
	elseif base.conj == "ir" then
		s2, s3, p1, p2, p3 = "es", "e", "imos", "is", "em"
	else
		error("Internal error: Unrecognized conjugation " .. base.conj)
	end

	addit("1s", base.stems.pres1, "o")
	addit("2s", base.stems.pres_stressed, s2)
	addit("3s", base.stems.pres_stressed, s3)
	addit("1p", base.stems.pres_unstressed, p1)
	addit("2p", base.stems.pres_unstressed, p2)
	addit("3p", base.stems.pres_stressed, p3)
end


local function add_present_subj(base)
	local function addit(slot, stems, ending)
		add3(base, "pres_sub_" .. slot, base.prefix, stems, ending)
	end
	local s1, s2 s3, p1, p2, p3
	if base.conj == "ar" then
		s1, s2, s3, p1, p2, p3 = "e", "es", "e", "emos", "eis", "em"
	else
		s1, s2, s3, p1, p2, p3 = "a", "as", "a", "amos", "ais", "am"
	end

	addit("1s", base.stems.pres_sub_stressed, s1)
	addit("2s", base.stems.pres_sub_stressed, s2)
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
		addit("2p", base.stems.pres_unstressed, "ai")
	elseif base.conj == "er" then
		addit("2s", base.stems.pres_stressed, "e")
		addit("2p", base.stems.pres_unstressed, "ei")
	elseif base.conj == "ir" then
		addit("2s", base.stems.pres_stressed, "e")
		addit("2p", base.stems.pres_unstressed, "i")
	else
		error("Internal error: Unrecognized conjugation " .. base.conj)
	end
end


local function add_finite_non_present(base)
	local function add_tense(slot, stem, s1, s2, s3, p1, p2, p3)
		add_single_stem_tense(base, slot, stem, s1, s2, s3, p1, p2, p3)
	end

	local stems = base.stems

	if stems.full_impf then
		-- An override needs to be supplied for the impf_1p and impf_2p due to the written accent on the stem.
		add_tense("impf", stems.full_impf, "a", "as", "a", {}, {}, "am")
	elseif base.conj == "ar" then
		add_tense("impf", stems.impf, "ava", "avas", "ava", "ávamos", "aveis", "avam")
	else
		add_tense("impf", stems.impf, "ia", "ias", "ia", "íamos", "íeis", "iam")
	end

	if stems.pret_conj == "irreg" then
		-- FIXME
		error("This needs more thinking")
		-- add_tense("pret", stems.pret, "e", "iste", "o", "imos", "isteis", "ieron")
	elseif stems.pret_conj == "ar" then
		add_tense("pret", stems.pret, "ei", "aste", "ou",
			{{form = "amos", footnotes = {"[Brazil]"}}, {form = "ámos", footnotes = {"[Portugal]"}}}, "astes", "aram")
	elseif stems.pret_conj == "er" then
		add_tense("pret", stems.pret, "ei", "este", "eu", "emos", "estes", "eram")
	else
		add_tense("pret", stems.pret, "i", "iste", "iu", "imos", "istes", "iram")
	end

	if stems.pret_conj == "ar" then
		add_tense("plup", stems.plup, "ara", "aras", "ara", "áramos", "áreis", "aram")
		add_tense("impf_sub", stems.impf_sub, "asse", "asses", "asse", "ássemos", "ásseis", "assem")
		add_tense("fut_sub", stems.fut_sub, "ar", "ares", "ar", "armos", "ardes", "arem")
	elseif stems.pret_conj == "er" then
		add_tense("plup", stems.plup, "era", "eras", "era", "êramos", "êreis", "eram")
		add_tense("impf_sub", stems.impf_sub, "esse", "esses", "esse", "êssemos", "êsseis", "êssem")
		add_tense("fut_sub", stems.fut_sub, "er", "eres", "er", "ermos", "erdes", "erem")
	else
		add_tense("plup", stems.plup, "ira", "iras", "ira", "íramos", "íreis", "iram")
		add_tense("impf_sub", stems.impf_sub, "isse", "isses", "isse", "íssemos", "ísseis", "issem")
		add_tense("fut_sub", stems.fut_sub, "ir", "ires", "ir", "irmos", "irdes", "irem")
	end

	add_tense("fut", stems.fut, "ei", "ás", "á", "emos", "eis", "ão")
	add_tense("cond", stems.cond, "ia", "ias", "ia", "íamos", "íeis", "iam")
end


local function add_non_finite_forms(base)
	local stems = base.stems
	local function addit(slot, stems, ending)
		add3(base, slot, base.prefix, stems, ending)
	end
	insert_form(base, "infinitive", {form = base.verb})
	for _, persnum in ipairs(person_number_list_basic) do
		insert_form(base, "infinitive_" .. persnum, {form = base.verb})
	end
	local ger_ending = base.conj == "ar" and "ando" or base.conj == "er" and "endo" or "indo"
	addit("gerund", stems.pres_unstressed, ger_ending)
	for _, persnum in ipairs(person_number_list_basic) do
		addit("gerund_" .. persnum, stems.pres_unstressed, ger_ending)
	end
	addit("pp_ms", stems.pp_ms, "")
	addit("pp_fs", stems.pp_fs, "")
	addit("pp_mp", stems.pp_ms, "s")
	addit("pp_fp", stems.pp_fs, "s")
end


local function copy_subjunctives_to_imperatives(base)
	-- Copy subjunctives to imperatives, unless there's an override for the given slot (as with the imp_1p of [[ir]]).
	for _, persnum in ipairs({"3s", "1p", "3p"}) do
		local from = "pres_sub_" .. persnum
		local to = "imp_" .. persnum
		insert_forms(base, to, iut.map_forms(base.forms[from], function(form) return form end))
	end
end


-- Add the appropriate clitic pronouns in `clitics` to the forms in `base_slot`. `store_cliticized_form` is a function
-- of three arguments (clitic, formobj, cliticized_form) and should store the cliticized form for the specified clitic
-- and form object.
local function add_forms_with_clitic(base, base_slot, clitics, store_cliticized_form)
	if not base.forms[base_slot] then
		-- This can happen, e.g. in only3s/only3sp/only3p verbs.
		return
	end
	for _, formobj in ipairs(base.forms[base_slot]) do
		-- Figure out the correct accenting of the verb when a clitic pronoun is attached to it. We may need to
		-- add or remove an accent mark:
		-- (1) No accent mark currently, none needed: infinitive sentar -> sentarlo; imperative singular ten -> tenlo;
		-- (2) Accent mark currently, still needed: infinitive oír -> oírlo;
		-- (3) No accent mark currently, accent needed: imperative singular siente -> siéntelo;
		-- (4) Accent mark currently, not needed: imperative singular está -> estalo, sé -> selo.
		local syllables = com.syllabify(formobj.form)
		local sylno = com.stressed_syllable(syllables)
		table.insert(syllables, "lo")
		local needs_accent = com.accent_needed(syllables, sylno)
		if needs_accent then
			syllables[sylno] = com.add_accent_to_syllable(syllables[sylno])
		else
			syllables[sylno] = com.remove_accent_from_syllable(syllables[sylno])
		end
		table.remove(syllables) -- remove added clitic pronoun
		local reaccented_form = table.concat(syllables)
		for _, clitic in ipairs(clitics) do
			local cliticized_form
			-- Some further special cases.
			if base_slot == "imp_1p" and (clitic == "nos" or clitic == "os") then
				-- Final -s disappears: sintamos + nos -> sintámonos, sintamos + os -> sintámoos
				cliticized_form = reaccented_form:gsub("s$", "") .. clitic
			elseif base_slot == "imp_2p" and clitic == "os" then
				-- Final -d disappears, which may cause an accent to be required:
				-- haced + os -> haceos, sentid + os -> sentíos
				if reaccented_form:find("id$") then
					cliticized_form = reaccented_form:gsub("id$", "íos")
				else
					cliticized_form = reaccented_form:gsub("d$", "os")
				end
			else
				cliticized_form = reaccented_form .. clitic
			end
			store_cliticized_form(clitic, formobj, cliticized_form)
		end
	end
end


-- Generate the combinations of verb form (infinitive, gerund or various imperatives) + clitic pronoun.
local function add_combined_forms(base)
	for _, base_slot_and_clitics in ipairs(base.alternant_multiword_spec.verb_slot_combined_rows) do
		local base_slot, clitics = unpack(base_slot_and_clitics)
		add_forms_with_clitic(base, base_slot, clitics,
			function(clitic, formobj, cliticized_form)
				insert_form(base, base_slot .. "_comb_" .. clitic,
					{form = cliticized_form, footnotes = formobj.footnotes})
			end
		)
	end
	for _, single_comb_slot_and_clitics in ipairs(base.alternant_multiword_spec.verb_slot_double_combined_rows) do
		local single_comb_slot, clitics = unpack(single_comb_slot_and_clitics)
		add_forms_with_clitic(base, single_comb_slot, clitics,
			function(clitic, formobj, cliticized_form)
				insert_form(base, single_comb_slot .. "_" .. clitic,
					{form = cliticized_form, footnotes = formobj.footnotes})
			end
		)
	end
end


local function process_slot_overrides(base, do_basic, reflexive_only)
	local overrides = reflexive_only and base.basic_reflexive_only_overrides or
		do_basic and base.basic_overrides or base.combined_overrides
	for slot, forms in pairs(overrides) do
		add(base, slot, base.prefix, forms, false, "allow overrides")
	end
end


-- Prefix `form` with `clitic`, adding fixed text `between` between them. Add links as appropriate unless the user
-- requested no links. Check whether form already has brackets (as will be the case if the form has a fixed clitic).
local function add_clitic_to_form(base, clitic, between, form)
	if base.alternant_multiword_spec.args.noautolinkverb then
		return clitic .. between .. form
	else
		local clitic_pref = "[[" .. clitic .. "]]" .. between
		if form:find("%[%[") then
			return clitic_pref .. form
		else
			return clitic_pref .. "[[" .. form .. "]]"
		end
	end
end


-- Add a reflexive pronoun or fixed clitic, e.g. [[lo]], as appropriate to the base form that were generated.
-- `do_joined` means to do only the forms where the pronoun is joined to the end of the form; otherwise, do only the
-- forms where it is not joined and precedes the form.
local function add_reflexive_or_fixed_clitic_to_forms(base, do_reflexive, do_joined)
	for _, slotaccel in ipairs(base.alternant_multiword_spec.verb_slots_basic) do
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
			if do_reflexive and slot:find("^pp_") or slot == "infinitive_linked" then
				-- do nothing with reflexive past participles or with infinitive linked (handled at the end)
			elseif slot:find("^neg_imp_") then
				error("Internal error: Should not have forms set for negative imperative at this stage")
			else
				local slot_has_suffixed_clitic = slot:find("infinitive") or slot:find("gerund") or slot:find("^imp_")
				-- Maybe generate non-reflexive parts and separated syntactic variants for use in {{pt-verb form of}}.
				-- See comment in add_slots() above `need_special_verb_form_of_slots`.
				if do_reflexive and base.alternant_multiword_spec.from_verb_form_of and
					-- Skip personal variants of infinitives and gerunds so we don't think [[jambando]] is a
					-- non-reflexive equivalent of [[jambándome]].
					not slot:find("infinitive_") and not slot:find("gerund_") then
					-- Clone the forms because we will be destructively modifying them just below, adding the reflexive
					-- pronoun.
					insert_forms(base, slot .. "_non_reflexive", mw.clone(base.forms[slot]))
					if slot_has_suffixed_clitic then
						insert_forms(base, slot .. "_variant", iut.map_forms(base.forms[slot], function(form)
							add_clitic_to_form(base, clitic, " ... ", form)
						end))
					end
				end
				if slot_has_suffixed_clitic then
					if do_joined then
						add_forms_with_clitic(base, slot, {clitic},
							function(clitic, formobj, cliticized_form)
								formobj.form = cliticized_form
							end
						)
					end
				elseif not do_joined then
					-- Add clitic as separate word before all other forms.
					for _, form in ipairs(base.forms[slot]) do
						form.form = add_clitic_to_form(base, clitic, " ", form.form)
					end
				end
			end
		end
	end
end


local function handle_infinitive_linked(base)
	-- Compute linked versions of potential lemma slots, for use in {{pt-verb}}.
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
	for _, persnum in ipairs(neg_imp_person_number_list) do
		local from = "pres_sub_" .. persnum
		local to = "neg_imp_" .. persnum
		insert_forms(base, to, iut.map_forms(base.forms[from], function(form)
			if base.alternant_multiword_spec.args.noautolinkverb then
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
	add_finite_non_present(base)
	add_non_finite_forms(base)
	-- This should happen before add_combined_forms() so overrides of basic forms end up part of the combined forms.
	process_slot_overrides(base, "do basic") -- do basic slot overrides
	-- This should happen after process_slot_overrides() in case a derived slot is based on an override (as with the
	-- imp_3s of [[dar]], [[estar]]).
	copy_subjunctives_to_imperatives(base)
	if not base.nocomb then
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
		process_slot_overrides(base, false) -- do combined slot overrides
	end
	-- This should happen before add_missing_links_to_forms() so that the comparison `form == base.lemma`
	-- in handle_infinitive_linked() works correctly and compares unlinked forms to unlinked forms.
	handle_infinitive_linked(base)
	if not base.alternant_multiword_spec.args.noautolinkverb then
		add_missing_links_to_forms(base)
	end
end


local function parse_indicator_spec(angle_bracket_spec)
	-- Store the original angle bracket spec so we can reconstruct the overall conj spec with the lemma(s) in them.
	local base = {angle_bracket_spec = angle_bracket_spec}
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
				first_element == "only3s" or first_element == "only3sp" or first_element == "only3p") then
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


-- Reconstruct the overall verb spec from the output of iut.parse_inflected_text(), so we can use it in
-- [[Module:accel/pt]].
function export.reconstruct_verb_spec(alternant_multiword_spec)
	local parts = {}

	for _, alternant_or_word_spec in ipairs(alternant_multiword_spec.alternant_or_word_specs) do
		table.insert(parts, alternant_or_word_spec.user_specified_before_text)
		if alternant_or_word_spec.alternants then
			table.insert(parts, "((")
			for i, multiword_spec in ipairs(alternant_or_word_spec.alternants) do
				if i > 1 then
					table.insert(parts, ",")
				end
				for _, word_spec in ipairs(multiword_spec.word_specs) do
					table.insert(parts, word_spec.user_specified_before_text)
					table.insert(parts, word_spec.user_specified_lemma)
					table.insert(parts, word_spec.angle_bracket_spec)
				end
				table.insert(parts, multiword_spec.user_specified_post_text)
			end
			table.insert(parts, "))")
		else
			table.insert(parts, alternant_or_word_spec.user_specified_lemma)
			table.insert(parts, alternant_or_word_spec.angle_bracket_spec)
		end
	end
	table.insert(parts, alternant_multiword_spec.user_specified_post_text)

	-- As a special case, if we see e.g. "amar<>", remove the <>. Don't do this if there are spaces, hyphens or
	-- alternants.
	local retval = table.concat(parts)
	if not retval:find("[ %-]") and not retval:find("%(%(") then
		local retval_no_angle_brackets = retval:match("^(.*)<>$")
		if retval_no_angle_brackets then
			return retval_no_angle_brackets
		end
	end
	return retval
end


-- Normalize all lemmas, substituting the pagename for blank lemmas and adding links to multiword lemmas.
local function normalize_all_lemmas(alternant_multiword_spec, pagename)

	-- (1) Add links to all before and after text. Remember the original text so we can reconstruct the verb spec later.
	if not alternant_multiword_spec.args.noautolinktext then
		for _, alternant_or_word_spec in ipairs(alternant_multiword_spec.alternant_or_word_specs) do
			alternant_or_word_spec.user_specified_before_text = alternant_or_word_spec.before_text
			alternant_or_word_spec.before_text = com.add_links(alternant_or_word_spec.before_text)
			if alternant_or_word_spec.alternants then
				for _, multiword_spec in ipairs(alternant_or_word_spec.alternants) do
					for _, word_spec in ipairs(multiword_spec.word_specs) do
						word_spec.user_specified_before_text = word_spec.before_text
						word_spec.before_text = com.add_links(word_spec.before_text)
					end
					multiword_spec.user_specified_post_text = multiword_spec.post_text
					multiword_spec.post_text = com.add_links(multiword_spec.post_text)
				end
			end
		end
		alternant_multiword_spec.user_specified_post_text = alternant_multiword_spec.post_text
		alternant_multiword_spec.post_text = com.add_links(alternant_multiword_spec.post_text)
	end

	-- (2) Remove any links from the lemma, but remember the original form
	--     so we can use it below in the 'lemma_linked' form.
	iut.map_word_specs(alternant_multiword_spec, function(base)
		if base.lemma == "" then
			base.lemma = pagename
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
	base.non_reflexive_forms = {}
	base.stems = {}

	if (base.only3s and 1 or 0) + (base.only3sp and 1 or 0) + (base.only3p and 1 or 0) > 1 then
		error("Only one of 'only3s', 'only3sp' and 'only3p' can be specified")
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
					if not base.alternant_multiword_spec.verb_slots_basic_map[stem] then
						error("Internal error: setting for 'refl_" .. stem .. "' does not refer to a basic verb slot")
					end
					base.basic_reflexive_only_overrides[stem] = forms
				elseif base.alternant_multiword_spec.verb_slots_basic_map[stem] then
					-- an individual form override of a basic form
					base.basic_overrides[stem] = forms
				elseif base.alternant_multiword_spec.verb_slots_combined_map[stem] then
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


local function detect_all_indicator_specs(alternant_multiword_spec)
	-- Propagate some settings up or down.
	iut.map_word_specs(alternant_multiword_spec, function(base)
		for _, prop in ipairs { "refl", "clitic", "only3s", "only3sp", "only3p" } do
			if base[prop] then
				alternant_multiword_spec[prop] = true
			end
		end
		base.alternant_multiword_spec = alternant_multiword_spec
		-- If reflexive or fixed clitic, don't include combined forms.
		alternant_multiword_spec.nocomb = alternant_multiword_spec.nocomb or base.clitic or base.refl
	end)

	add_slots(alternant_multiword_spec)

	iut.map_word_specs(alternant_multiword_spec, function(base)
		base.nocomb = alternant_multiword_spec.args.nocomb
		detect_indicator_spec(base)
		construct_stems(base)
	end)
end


local function add_categories_and_annotation(alternant_multiword_spec, base, multiword_lemma)
	local function insert_ann(anntype, value)
		m_table.insertIfNot(alternant_multiword_spec.annotation[anntype], value)
	end

	local function insert_cat(cat, also_when_multiword)
		-- Don't place multiword terms in categories like 'Portuguese verbs ending in -ar' to avoid spamming the
		-- categories with such terms.
		if also_when_multiword or not multiword_lemma then
			m_table.insertIfNot(alternant_multiword_spec.categories, "Portuguese " .. cat)
		end
	end

	if check_for_red_links and not alternant_multiword_spec.from_headword and not alternant_multiword_spec.from_verb_form_of
		and multiword_lemma then
		for _, slot_and_accel in ipairs(alternant_multiword_spec.all_verb_slots) do
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
	elseif base.only3p then
		insert_ann("defective", "third-person plural only")
		insert_cat("third-person-plural-only verbs")
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
local function compute_categories_and_annotation(alternant_multiword_spec)
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
		add_categories_and_annotation(alternant_multiword_spec, base, multiword_lemma)
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
	local lemmas = iut.map_forms(alternant_multiword_spec.forms.infinitive, remove_reflexive_indicators)
	alternant_multiword_spec.lemmas = lemmas -- save for later use in make_table()

	local reconstructed_verb_spec = export.reconstruct_verb_spec(alternant_multiword_spec)

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

	local function transform_accel_obj(slot, formobj, accel_obj)
		-- No accelerators for negative imperatives, which are always multiword and derived directly from the
		-- present subjunctive.
		if slot:find("^neg_imp") then
			return nil
		end
		if accel_obj then
			accel_obj.form = "verb-form-" .. reconstructed_verb_spec
		end
		return accel_obj
	end

	local props = {
		lang = lang,
		lemmas = lemmas,
		create_footnote_obj = create_footnote_obj,
		transform_accel_obj = transform_accel_obj,
	}
	props.slot_list = alternant_multiword_spec.verb_slots_basic
	iut.show_forms(alternant_multiword_spec.forms, props)
	alternant_multiword_spec.footnote_basic = alternant_multiword_spec.forms.footnote
	props.create_footnote_obj = nil
	props.slot_list = alternant_multiword_spec.verb_slots_combined
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
<div class="NavHead" align=center>&nbsp; &nbsp; Conjugation of {title} (See [[Appendix:Portuguese verbs]])</div>
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
|-{reflexive_non_finite_clause}
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

local reflexive_non_finite_template = [=[

! rowspan="3" style="background:#e2e4c0" | personal non-finite
! style="background:#ECECEC;width:12.5%" |
! style="background:#ECECEC;width:12.5%" | yo
! style="background:#ECECEC;width:12.5%" | tú<br />vos
! style="background:#ECECEC;width:12.5%" | él/ella/ello<br />usted
! style="background:#ECECEC;width:12.5%" | nosotros<br />nosotras
! style="background:#ECECEC;width:12.5%" | vosotros<br />vosotras
! style="background:#ECECEC;width:12.5%" | ellos/ellas<br />ustedes
|-
! style="height:3em;background:#ECECEC" | <span title="infinitivo">infinitive</span>
| {infinitive_1s}
| {infinitive_2s}
| {infinitive_3s}
| {infinitive_1p}
| {infinitive_2p}
| {infinitive_3p}
|-
! style="height:3em;background:#ECECEC" | <span title="gerundio">gerund</span>
| {gerund_1s}
| {gerund_2s}
| {gerund_3s}
| {gerund_1p}
| {gerund_2p}
| {gerund_3p}
|-
! style="background:#DEDEDE;height:.75em" colspan="8" |
|-]=]

local combined_form_combined_tu_vos_template = [=[

! style="background:#DEDEDE;height:.35em" colspan="8" |
|-
! rowspan="3" style="background:#f2caa4" | with informal second-person singular ''tú/vos'' imperative {imp_2s}
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
|-]=]

local combined_form_separate_tu_vos_template = [=[

! style="background:#DEDEDE;height:.35em" colspan="8" |
|-
! rowspan="3" style="background:#f2caa4" | with informal second-person singular ''tú'' imperative {imp_2s}
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
! rowspan="3" style="background:#f2caa4" | with informal second-person singular ''vos'' imperative {imp_2sv}
|-
! style="height:3em;background:#ECECEC" | dative
| {imp_2sv_comb_me}
| {imp_2sv_comb_te}
| {imp_2sv_comb_le}
| {imp_2sv_comb_nos}
| ''not used''
| {imp_2sv_comb_les}
|-
! style="height:3em;background:#ECECEC" | accusative
| {imp_2sv_comb_me}
| {imp_2sv_comb_te}
| {imp_2sv_comb_lo}, {imp_2sv_comb_la}
| {imp_2sv_comb_nos}
| ''not used''
| {imp_2sv_comb_los}, {imp_2sv_comb_las}
|-]=]

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
|-{tu_vos_clause}
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


local function make_table(alternant_multiword_spec)
	local forms = alternant_multiword_spec.forms

	forms.title = link_term(alternant_multiword_spec.lemmas[1].form)
	if alternant_multiword_spec.annotation ~= "" then
		forms.title = forms.title .. " (" .. alternant_multiword_spec.annotation .. ")"
	end
	forms.description = ""

	-- Format the basic table.
	forms.footnote = alternant_multiword_spec.footnote_basic
	forms.reflexive_non_finite_clause = alternant_multiword_spec.refl and m_string_utilities.format(reflexive_non_finite_template, forms) or ""
	forms.notes_clause = forms.footnote ~= "" and m_string_utilities.format(notes_template, forms) or ""
	-- The separate_* values are computed in show_forms().
	forms.pres_2sv_text = alternant_multiword_spec.separate_pres_2sv and m_string_utilities.format(pres_2sv_template, forms) or ""
	forms.pres_sub_2sv_text = alternant_multiword_spec.separate_pres_sub_2sv and m_string_utilities.format(pres_sub_2sv_template, forms) or ""
	forms.imp_2sv_text = alternant_multiword_spec.separate_imp_2sv and m_string_utilities.format(imp_2sv_template, forms) or ""
	local formatted_basic_table = m_string_utilities.format(basic_table, forms)

	-- Format the combined table.
	local formatted_combined_table
	if alternant_multiword_spec.refl or alternant_multiword_spec.args.nocomb or alternant_multiword_spec.clitic then
		formatted_combined_table = ""
	else
		forms.footnote = alternant_multiword_spec.footnote_combined
		forms.notes_clause = forms.footnote ~= "" and m_string_utilities.format(notes_template, forms) or ""
		-- separate_imp_2sv is computed in show_forms().
		local tu_vos_template = alternant_multiword_spec.separate_imp_2sv and combined_form_separate_tu_vos_template or
			combined_form_combined_tu_vos_template
		forms.tu_vos_clause = m_string_utilities.format(tu_vos_template, forms)
		formatted_combined_table = m_string_utilities.format(combined_form_table, forms)
	end

	-- Paste them together.
	return formatted_basic_table .. formatted_combined_table
end


-- Externally callable function to parse and conjugate a verb given user-specified arguments.
-- Return value is WORD_SPEC, an object where the conjugated forms are in `WORD_SPEC.forms`
-- for each slot. If there are no values for a slot, the slot key will be missing. The value
-- for a given slot is a list of objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms(parent_args, from_headword, from_verb_form_of, double_combined_forms_to_include)
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
	local function in_template_space()
		return mw.title.getCurrentTitle().nsText == "Template"
	end

	-- Determine the verb spec we're being asked to generate the conjugation of. This may be taken from the
	-- current page title or the value of |pagename=; but not when called from {{pt-verb form of}}, where the
	-- page title is a non-lemma form. Note that the verb spec may omit the infinitive; e.g. it may be "<ue>".
	-- For this reason, we use the value of `pagename` computed here down below, when calling normalize_all_lemmas().
	local pagename = not from_verb_form_of and args.pagename or from_headword and args.head[1] or PAGENAME
	local arg1 = args[1]
	if not arg1 then
		if (PAGENAME == "pt-conj" or PAGENAME == "pt-verb") and in_template_space() then
			arg1 = "licuar<+,ú>"
		elseif PAGENAME == "pt-verb form of" and in_template_space() then
			arg1 = "amar"
		else
			arg1 = pagename
		end
	end

	-- When called from {{pt-verb form of}}, determine the non-lemma form whose inflections we're being asked to
	-- determine. This normally comes from the page title or the value of |pagename=.
	local verb_form_of_form
	if from_verb_form_of then
		verb_form_of_form = args.pagename
		if not verb_form_of_form then
			if PAGENAME == "pt-verb form of" and in_template_space() then
				verb_form_of_form = "ame"
			else
				verb_form_of_form = PAGENAME
			end
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
		allow_default_indicator = true,
		allow_blank_lemma = true,
	}
	local escaped_arg1 = escape_reflexive_indicators(arg1)
	local alternant_multiword_spec = iut.parse_inflected_text(escaped_arg1, parse_props)
	alternant_multiword_spec.pos = pos or "verbs"
	alternant_multiword_spec.args = args
	alternant_multiword_spec.from_headword = from_headword
	alternant_multiword_spec.from_verb_form_of = from_verb_form_of
	alternant_multiword_spec.verb_form_of_form = verb_form_of_form

	-- Now determine if we need to generate any double-combined forms, and if so, which clitics are involved.
	-- See the comment above the initialization of `verb_slot_double_combined_rows` above in add_slots().
	if verb_form_of_form and rfind(verb_form_of_form, AV) then
		-- All double-clitic forms have an explicit accent, so we check for this. In addition, all double-clitic forms
		-- are of the form "(me|te|se|nos|os)(lo|la|le)s$". We have no alternations in Lua patterns, but we can exploit
		-- the similarity of the clitics in question.
		local single_comb_form, object_clitic = rmatch(verb_form_of_form, "^(.*)(l[aeo]s?)$")
		if single_comb_form then
			local personal_clitic = rmatch(single_comb_form, "^.*([mts]e)$")
			if not personal_clitic then
				personal_clitic = rmatch(single_comb_form, "^.-(n?os)$")
			end
			if personal_clitic then
				if personal_clitic == "nos" then
					-- "os" is a substring of "nos"; conceivably we could have a form ending in -n + os, and we don't
					-- know whether to interpret as -n + os or - + nos.
					alternant_multiword_spec.double_combined_forms_to_include =
						{{"nos", object_clitic}, {"os", object_clitic}}
				else
					alternant_multiword_spec.double_combined_forms_to_include = {{personal_clitic, object_clitic}}
				end
			end
		end
	end

	normalize_all_lemmas(alternant_multiword_spec, pagename)
	detect_all_indicator_specs(alternant_multiword_spec)
	local inflect_props = {
		slot_list = alternant_multiword_spec.all_verb_slots,
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

	compute_categories_and_annotation(alternant_multiword_spec)
	if args.json and not from_headword and not from_verb_form_of then
		return require("Module:JSON").toJSON(alternant_multiword_spec)
	end
	return alternant_multiword_spec
end


-- Entry point for {{pt-conj}}. Template-callable function to parse and conjugate a verb given
-- user-specified arguments and generate a displayable table of the conjugated forms.
function export.show(frame)
	local parent_args = frame:getParent().args
	local alternant_multiword_spec = export.do_generate_forms(parent_args)
	show_forms(alternant_multiword_spec)
	return make_table(alternant_multiword_spec) ..
		require("Module:utilities").format_categories(alternant_multiword_spec.categories, lang, nil, nil, force_cat)
end


return export
