--[=[

This module implements {{gl-reinteg-conj}} and provides the underlying conjugation functions for {{gl-reinteg-verb}},
as well as for {{gl-verb}} when invoked with |reinteg=1. The actual formatting of both {{gl-reinteg-verb}} and
{{gl-verb}} happens in [[Module:gl-headword]]. This module uses the [[Appendix:Reintegrationism|reintegrationst]] norm
for Galician spelling. See also [[Module:gl-verb]], which implements the standard norm.


Authorship: Ben Wing <benwing2>, MedK <medk1>

]=]

local export = {}


--[=[

TERMINOLOGY:

-- "slot" = A particular combination of tense/mood/person/number/etc.
	 Example slot names for verbs are "pres_1s" (present indicative first-person singular), "pres_sub_2s" (present
	 subjunctive second-person singular) "impf_sub_3p" (imperfect subjunctive third-person plural).
	 Each slot is filled with zero or more forms.

-- "form" = The conjugated Galician form representing the value of a given slot.

-- "lemma" = The dictionary form of a given Galician term. For Galician, always the infinitive.
]=]

--[=[

FIXME:

--]=]

local lang = require("Module:languages").getByCode("gl")
local m_string_utilities = require("Module:string utilities")
local m_links = require("Module:links")
local m_table = require("Module:table")
local iut = require("Module:inflection utilities")
local com = require("Module:gl-reinteg-common")

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
local TEMPC1 = u(0xFFF1) -- temporary character used for consonant substitutions
local TEMP_MESOCLITIC_INSERTION_POINT = u(0xFFF2) -- temporary character used to mark the mesoclitic insertion point
-- Variant codes and the like.
-- NOTE: These codes should be *PREFIXED* onto stems and *SUFFIXED* onto endings. That way they won't interfere in the
-- operation of combine_stem_ending().
--
-- GL_TYPE = "Galician-type", PT_TYPE = "Portuguese-type". GL_TYPE stems cannot combine with PT_TYPE endings and
-- vice-versa. GL_ONLY_TYPE = "Galician-only type"; GL_ONLY_TYPE stems can only combine with endings specifically
-- marked as GL_TYPE.
local GL_TYPE = u(0xFFF3)
local GL_ONLY_TYPE = u(0xFFF4)
local PT_TYPE = u(0xFFF5)
-- ALTVAR = Less-recommended variants listed at the bottom of the Estraviz conjugation tables rather than in the main
-- table. We list these in the main table but with a footnote indicating they are less-recommended alternatives, and
-- italicize them to visually set them apart.
local ALTVAR = u(0xFFF6)
local GL_ALTVAR = GL_TYPE .. ALTVAR
local GL_ONLY_ALTVAR = GL_ONLY_TYPE .. ALTVAR
local var_codes_no_altvar = GL_TYPE .. GL_ONLY_TYPE .. PT_TYPE
local all_var_codes = var_codes_no_altvar .. ALTVAR
local var_code_c = "[" .. all_var_codes .. "]"
local var_code_no_altvar_c = "[" .. var_codes_no_altvar .. "]"
local not_var_code_c = "[^" .. all_var_codes .. "]"

-- Export variant codes for use in [[Module:pt-gl-inflections]].
export.GL_TYPE = GL_TYPE
export.GL_ONLY_TYPE = GL_ONLY_TYPE
export.PT_TYPE = PT_TYPE
export.ALTVAR = ALTVAR

local short_pp_footnote = "[usually used with auxiliary verbs " .. link_term("ser") .. " and " .. link_term("estar") .. "]"
local long_pp_footnote = "[usually used with auxiliary verbs " .. link_term("haver") .. " and " .. link_term("ter") .. "]"

--[=[

Vowel alternations:

<i-e>: 'i' in pres1s and the whole present subjunctive; 'e' elsewhere when stressed. Generally 'e' otherwise when
       unstressed. E.g. [[sentir]], [[conseguir]] (the latter additionally with 'gu-g' alternation).
<u-o>: 'u' in pres1s and the whole present subjunctive; 'o' elsewhere when stressed. Either 'o' or 'u' otherwise when
       unstressed. E.g. [[dormir]], [[subir]].
<i>: 'i' whenever stressed (in the present singular and third plural) and throughout the whole present subjunctive.
      Otherwise 'e'. E.g. [[progredir]], [[premir]].
<u>: 'u' whenever stressed (in the present singular and third plural) and throughout the whole present subjunctive.
      Otherwise 'o'. E.g. [[polir]], [[extorquir]] (the latter also <u-o>).
<í>: The last 'i' of the stem (excluding stem-final 'i') becomes 'í' when stressed. E.g.:
     * [[proibir]] ('proíbo, proíbe(s), proíbem, proíba(s), proíbam')
	 * [[faiscar]] ('faísco, faísca(s), faíscam, faísque(s), faísquem' also with 'c-qu' alternation)
	 * [[homogeneizar]] ('homogeneízo', etc.)
	 * [[mobiliar]] ('mobílio', etc.; note here the final -i is ignored when determining which vowel to stress)
	 * [[tuitar]] ('tuíto', etc.)
<ú>: The last 'u' of the stem (excluding stem-final 'u') becomes 'ú' when stressed. E.g.:
     * [[reunir]] ('reúno, reúne(s), reúnem, reúna(s), reúnam')
	 * [[esmiuçar]] ('esmiúço, esmiúça(s), esmiúça, esmiúce(s), esmiúcem' also with 'ç-c' alternation)
     * [[reusar]] ('reúso, reúsa(s), reúsa, reúse(s), reúsem')
     * [[saudar]] ('saúdo, saúda(s), saúda, saúde(s), saúdem')
]=]

local vowel_alternants = m_table.listToSet({"i-e", "i", "í", "u-o", "u", "ú", "ei", "+"})
local vowel_alternant_to_desc = {
	["i-e"] = "''i-e'' alternation in present singular",
	["i"] = "''e'' becomes ''i'' when stressed",
	["í"] = "''i'' becomes ''í'' when stressed",
	["u-o"] = "''u-o'' alternation in present singular",
	["u"] = "''o'' becomes ''u'' when stressed",
	["ú"] = "''u'' becomes ''ú'' when stressed",
	["ei"] = "''i'' becomes ''ei'' when stressed",
}

local vowel_alternant_to_cat = {
	["i-e"] = "i-e alternation in present singular",
	["i"] = "e becoming i when stressed",
	["í"] = "i becoming í when stressed",
	["u-o"] = "u-o alternation in present singular",
	["u"] = "o becoming u when stressed",
	["ú"] = "u becoming ú when stressed",
	["ei"] = "i becoming ei when stressed",
}

local all_persons_numbers = {
	["1s"] = "1|s",
	["2s"] = "2|s",
	["3s"] = "3|s",
	["1p"] = "1|p",
	["2p"] = "2|p",
	["3p"] = "3|p",
}

local person_number_list = {"1s", "2s", "3s", "1p", "2p", "3p"}
local imp_person_number_list = {"2s", "3s", "1p", "2p", "3p"}
local neg_imp_person_number_list = {"2s", "3s", "1p", "2p", "3p"}

person_number_to_reflexive_pronoun = {
	["1s"] = "me",
	["2s"] = "te",
	["3s"] = "se",
	["1p"] = "nos",
	["2p"] = "vos",
	["3p"] = "se",
}

local indicator_flags = m_table.listToSet {
	"no_pres_stressed", "no_pres1_and_sub",
	"only3s", "only3sp", "only3p",
	"pp_inv", "irreg", "no_built_in", "e_ei_cat",
}

-- Remove any variant codes e.g. GL_TYPE, PT_TYPE, ALTVAR. Needs to be called from [[Module:gl-reinteg-headword]] on the
-- output of do_generate_forms(). `keep_altvar` leaves ALTVAR; used in the `canonicalize` function of show_forms()
-- because we then process and remove it in `generate_forms`. FIXME: Use metadata for this once it's supported in
-- [[Module:inflection utilities]].
function export.remove_variant_codes(form, keep_altvar)
	return rsub(form, keep_altvar and var_code_no_altvar_c or var_code_c, "")
end

-- Initialize all the slots for which we generate forms.
local function add_slots(alternant_multiword_spec)
	-- "Basic" slots: All slots that go into the regular table (not the reflexive form-of table).
	alternant_multiword_spec.verb_slots_basic = {
		{"infinitive", "inf"},
		{"infinitive_linked", "inf"},
		{"gerund", "ger"},
		{"short_pp_ms", "short|m|s|past|part"},
		{"short_pp_fs", "short|f|s|past|part"},
		{"short_pp_mp", "short|m|p|past|part"},
		{"short_pp_fp", "short|f|p|past|part"},
		{"pp_ms", "m|s|past|part"},
		{"pp_fs", "f|s|past|part"},
		{"pp_mp", "m|p|past|part"},
		{"pp_fp", "f|p|past|part"},
	}

	-- Special slots used to handle non-reflexive parts of reflexive verbs in {{gl-reinteg-verb form of}}. For example,
	-- for a reflexive-only verb like [[arrepender-se]], we want to be able to use {{gl-reinteg-verb form of}} on
	-- [[arrependa]] (which should mention that it is a part of 'me arrependa', first-person singular present
	-- subjunctive, and 'se arrependa', third-person singular present subjunctive) or on [[arrependemos]] (which should
	-- mention that it is a part of 'arrependemo-nos', first-person plural present indicative or preterite). Similarly,
	-- we want to use {{gl-reinteg-verb form of}} on [[arrependendo]] (which should mention that it is a part of
	-- 'se ... arrependendo', syntactic variant of [[arrependendo-se]], which is the gerund of [[arrepender-se]]). To
	-- do this, we need to be able to map non-reflexive parts like [[arrependa]], [[arrependemos]], [[arrependendo]],
	-- etc. to their reflexive equivalent(s), to the tag(s) of the equivalent(s), and, in the case of forms like
	-- [[arrependendo]], [[arrepender]] and imperatives, to the separated syntactic variant of the verb+clitic
	-- combination. We do this by creating slots for the non-reflexive part equivalent of each basic reflexive slot,
	-- and for the separated syntactic-variant equivalent of each basic reflexive slot that is formed of verb+clitic.
	-- We use slots in this way to deal with multiword lemmas. Note that we run into difficulties mapping between
	-- reflexive verbs, non-reflexive part equivalents, and separated syntactic variants if a slot contains more than
	-- one form. To handle this, if there are the same number of forms in two slots we're trying to match up, we assume
	-- the forms match one-to-one; otherwise we don't match up the two slots (which means {{gl-reinteg-verb form of}} won't
	-- work in this case, but such a case is extremely rare and not worth worrying about). Alternatives that handle
	-- this "properly" are significantly more complicated and require non-trivial modifications to
	-- [[Module:inflection utilities]].
	local need_special_verb_form_of_slots = alternant_multiword_spec.source_template == "gl-reinteg-verb form of" and
		alternant_multiword_spec.refl

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
	local function add_basic_personal_slot(slot_prefix, tag_suffix, person_number_list, no_special_verb_form_of_slot)
		add_personal_slot(alternant_multiword_spec.verb_slots_basic, slot_prefix, tag_suffix, person_number_list)
		-- Add special slots for handling non-reflexive parts of reflexive verbs in {{gl-reinteg-verb form of}}.
		-- See comment above in `need_special_verb_form_of_slots`.
		if need_special_verb_form_of_slots and not no_special_verb_form_of_slot then
			for _, persnum in ipairs(person_number_list) do
				local persnum_tag = all_persons_numbers[persnum]
				local basic_slot = slot_prefix .. "_" .. persnum
				local accel = persnum_tag .. "|" .. tag_suffix
				table.insert(alternant_multiword_spec.verb_slots_reflexive_verb_form_of, {basic_slot .. "_non_reflexive", "-"})
			end
		end
	end

	add_basic_personal_slot("pres", "pres|ind", person_number_list)
	add_basic_personal_slot("impf", "impf|ind", person_number_list)
	add_basic_personal_slot("pret", "pret|ind", person_number_list)
	add_basic_personal_slot("plup", "plup|ind", person_number_list)
	add_basic_personal_slot("fut", "fut|ind", person_number_list)
	add_basic_personal_slot("cond", "cond", person_number_list)
	add_basic_personal_slot("pres_sub", "pres|sub", person_number_list)
	add_basic_personal_slot("impf_sub", "impf|sub", person_number_list)
	add_basic_personal_slot("fut_sub", "fut|sub", person_number_list)
	add_basic_personal_slot("imp", "imp", imp_person_number_list)
	add_basic_personal_slot("pers_inf", "pers|inf", person_number_list)
	-- Don't need special non-reflexive-part slots because the negative imperative is multiword, of which the
	-- individual words are 'nom' + subjunctive.
	add_basic_personal_slot("neg_imp", "neg|imp", neg_imp_person_number_list, "no special verb form of")
	-- Don't need special non-reflexive-part slots because we don't want [[arrependendo]] mapping to [[arrependendo-me]]
	-- (only [[arrependendo-se]]) or [[arrepender]] mapping to [[arrepender-me]] (only [[arrepender-se]]).
	add_basic_personal_slot("infinitive", "inf", person_number_list, "no special verb form of")
	add_basic_personal_slot("gerund", "ger", person_number_list, "no special verb form of")

	-- Generate the list of all slots.
	alternant_multiword_spec.all_verb_slots = {}
	for _, slot_and_accel in ipairs(alternant_multiword_spec.verb_slots_basic) do
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
end


local overridable_stems = {}

local function allow_multiple_values(separated_groups, data)
	local retvals = {}
	for _, separated_group in ipairs(separated_groups) do
		local footnotes = data.fetch_footnotes(separated_group)
		local retval = {form = separated_group[1], footnotes = footnotes}
		table.insert(retvals, retval)
	end
	return retvals
end

local function simple_choice(choices)
	return function(separated_groups, data)
		if #separated_groups > 1 then
			data.parse_err("For spec '" .. data.prefix .. ":', only one value currently allowed")
		end
		if #separated_groups[1] > 1 then
			data.parse_err("For spec '" .. data.prefix .. ":', no footnotes currently allowed")
		end
		local choice = separated_groups[1][1]
		if not m_table.contains(choices, choice) then
			data.parse_err("For spec '" .. data.prefix .. ":', saw value '" .. choice .. "' but expected one of '" ..
				table.concat(choices, ",") .. "'")
		end
		return choice
	end
end

for _, overridable_stem in ipairs {
	"pres_unstressed",
	"pres_stressed",
	"pres1_and_sub",
	-- Don't include pres1; use pres_1s if you need to override just that form
	"impf",
	"full_impf",
	{"pret_conj", simple_choice({"irreg", "ar", "er", "ir"}) },
	"pret_base",
	"pret",
	"gl_short_pret",
	"pt_pret_1s",
	"pt_pret_3s",
	"fut",
	"cond",
	"pres_sub_stressed",
	"pres_sub_unstressed",
	{"sub_conj", simple_choice({"ar", "er"}) },
	"plup",
	"impf_sub",
	"fut_sub",
	"pers_inf",
	"pp",
	"short_pp",
} do
	if type(overridable_stem) == "string" then
		overridable_stems[overridable_stem] = allow_multiple_values
	else
		local stem, validator = unpack(overridable_stem)
		overridable_stems[stem] = validator
	end
end


-- Useful as the value of the `match` property of a built-in verb. `main_verb_spec` is a Lua pattern that should match
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

Built-in (usually irregular) conjugations.

Each entry is processed in turn and consists of an object with two fields:
1. match=: Specifies the built-in verbs that match this object.
2. forms=: Specifies the built-in stems and forms for these verbs.

The value of match= is either a string beginning with "^" (match only the specified verb), a string not beginning
with "^" (match any verb ending in that string), or a function that is passed in the verb and should return the prefix
of the verb if it matches, otherwise nil. The function match_against_verbs() is provided to facilitate matching a set
of verbs with a common ending and specific prefixes (e.g. [[ter]] and [[ater]] but not [[abater]], etc.).

The value of forms= is a table specifying stems and individual override forms. Each key of the table names either a
stem (e.g. `pres_stressed`), a stem property (e.g. `vowel_alt`) or an individual override form (e.g. `pres_1s`).
Each value of a stem can either be a string (a single stem), a list of strings, or a list of objects of the form
{form = STEM, footnotes = {FOONOTES}}. Each value of an individual override should be of exactly the same form except
that the strings specify full forms rather than stems. The values of a stem property depend on the specific property
but are generally strings or booleans.

In order to understand how the stem specifications work, it's important to understand the phonetic modifications done
by combine_stem_ending(). In general, the complexities of predictable prefix, stem and ending modifications are all
handled in this function. In particular:

1. Spelling-based modifications (c/z, g/gu, gu/gü, g/j) occur automatically as appropriate for the ending.
2. If the stem begins with an acute accent, the accent is moved onto the last vowel of the prefix (for handling verbs
   in -uar such as [[minguar]], pres_3s 'míngua').
3. If the ending begins with a double asterisk, this is a signal to conditionally delete the accent on the last letter
   of the stem. "Conditionally" means we don't do it if the last two letters would form a diphthong without the accent
   on the second one (e.g. in [[sair]], with stem 'saí'); but as an exception, we do delete the accent in stems
   ending in -guí, -quí (e.g. in [[conseguir]]) because in this case the ui isn't a diphthong.
4. If the ending begins with an asterisk, this is a signal to delete the accent on the last letter of the stem, e.g.
   fizé -> fizermos. Unlike for **, this removal is unconditional, so we get e.g. 'sairmos' not #'saírmos'.
5. If ending begins with i, it must get an accent after an unstressed vowel (in some but not all cases) to prevent the
   two merging into a diphthong. See combine_stem_ending() for specifics.

The following stems are recognized:

-- pres_unstressed: The present indicative unstressed stem (1p, 2p). Also controls the imperative 2p
     and gerund. Defaults to the infinitive stem (minus the ending -ar/-er/-ir/-or).
-- pres_stressed: The present indicative stressed stem (1s, 2s, 3s, 3p). Also controls the imperative 2s.
     Default is empty if indicator `no_pres_stressed`, else a vowel alternation if such an indicator is given
	 (e.g. `ue`, `ì`), else the infinitive stem.
-- pres1_and_sub: Overriding stem for 1s present indicative and the entire subjunctive. Only set by irregular verbs
     and by the indicators `no_pres_stressed` (e.g. [[precaver]]) and `no_pres1_and_sub` (since verbs of this sort,
	 e.g. [[puir]], are missing the entire subjunctive as well as the 1s present indicative). Used by many irregular
	 verbs, e.g. [[caber]], verbs in '-air', [[dizer]], [[ter]], [[valer]], etc. Some verbs set this and then supply an
	 override for the pres_1sg if it's irregular, e.g. [[saber]], with irregular subjunctive stem "saib-" and special
	 1s present indicative "sei".
-- pres1: Special stem for 1s present indicative. Normally, do not set this explicitly. If you need to specify an
     irregular 1s present indicative, use the form override pres_1s= to specify the entire form. Defaults to
	 pres1_and_sub if given, else pres_stressed.
-- pres_sub_unstressed: The present subjunctive unstressed stem (1p, 2p). Defaults to pres1_and_sub if given, else the
     infinitive stem.
-- pres_sub_stressed: The present subjunctive stressed stem (1s, 2s, 3s, 1p). Defaults to pres1.
-- sub_conj: Determines the set of endings used in the subjunctive. Should be one of "ar" or "er".
-- impf: The imperfect stem (not including the -av-/-i- stem suffix, which is determined by the conjugation). Defaults
     to the infinitive stem.
-- full_impf: The full imperfect stem missing only the endings (-a, -as, -am, etc.). Used for verbs with irregular
     imperfects such as [[ser]], [[ter]], [[vir]] and [[pôr]]. Needs to include an accent on the stressed vowel, which
	 will automatically be removed when not needed.
-- pret_conj: Determines the set of endings used in the preterite. Should be one of "ar", "er", "ir" or "irreg".
     Defaults to the conjugation as determined from the infinitive. When pret_conj == "irreg", `pret` is used, otherwise
	 `pret_base`.
-- pret_base: The preterite stem (not including the -a-/-e-/-i- stem suffix). Defaults to the infinitive stem.
	 Only used when pret_conj ~= "irreg". 
-- pret: The full preterite stem missing only the endings (-ste, -mos, etc.). Needs to include the accent on the final
	 vowel that occurs in some forms, e.g. 'figé' for [[fazer]], 'fô' for [[ser]]; the accent will automatically be
	 removed when not needed. Only used for verbs with irregular preterites (pret_conj == "irreg") such as [[fazer]],
	 [[poder]], [[trazer]], etc. The pret_1s and pret_3s are handled using the gl_short_pret stem instead for
	 "Galician"-ending forms (pret_1s '-em', pret_3s '-o') and using pt_pret_1s and pt_pret_3s for "Portuguese"-ending
	 forms. Defaults to `pret_base` + the accented conjugation vowel.
-- gl_short_pret: The short preterite stem, used with "Galician" 1s and 3s endings (pret_1s '-em', pret_3s '-o'). Only
	 used with irregular preterites (pret_conj == "irreg"). Normally derived from gl_pret by deleting the final vowel,
	 and doesn't need to be given explicitly.
-- pt_pret_1s: The "Portuguese" pret_1s form. In addition to this, the "Galician" pret_1s form will be included, formed
	 from gl_short_pret by adding '-em'. Does not need to be given if an override for pret_1s is supplied.
-- pt_pret_3s: The "Portuguese" pret_3s form. In addition to this, the "Galician" pret_3s form will be included, formed
	 from gl_short_pret by adding '-o' (which may cause the preceding consonant to shift to preserve the sound). Does
	 not need to be given if an override for pret_3s is supplied.
-- fut: The future stem. Defaults to the infinitive stem + the unaccented conjugation vowel.
-- cond: The conditional stem. Defaults to `fut`.
-- impf_sub: The imperfect subjunctive stem. Needs to include the accent on the final vowel that occurs in some forms;
	 see `pret` for more information. Defaults to `pret`.
-- fut_sub: The future subjunctive stem. Needs to include the accent on the final vowel that occurs in some forms; see
	 `gl_pret` for more information. Defaults to the merger of `gl_pret` and `pt_pret`.
-- plup: The pluperfect stem. Needs to include the accent on the final vowel that occurs in some forms; see `pret` for
	 more information. Defaults to `pret`.
-- pers_inf: The personal infinitive stem. Defaults to the infinitive stem + the accented conjugation vowel.
-- pp: The masculine singular past participle. Default is based on the verb conjugation: infinitive stem + '-ado' for
     -ar verbs, otherwise infinitive stem + '-ido'.
-- short_pp: The short masculine singular past participle, for verbs with such a form. No default.
-- pp_inv: `true` if the past participle exists only in the masculine singular.
]=]

local built_in_conjugations = {

	--------------------------------------------------------------------------------------------
	--                                             -ar                                        --
	--------------------------------------------------------------------------------------------

	-- Verbs not needing entries here:
	--
	-- (1) Verbs with short past participles: need to specify the short pp explicitly.
	--
	-- aceitar: use <short_pp:aceite>
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
	--
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
		match = match_against_verbs("dar", {"^", "^des", "^re"}),
		forms = {
			pres_1s = "dou",
			pres_2s = "dás",
			pres_3s = "dá",
			-- damos, dades/dais regular
			pres_3p = {GL_TYPE .. "dam", PT_TYPE .. "dão"},
			pret_conj = "irreg", pret = "dé", pret_1s = "dei", pret_3s = "deu",
			pres_sub_1s = "dê",
			pres_sub_2s = "dês",
			pres_sub_3s = "dê",
			-- demos, dedes/deis regular
			pres_sub_3p = {GL_TYPE .. "dem", PT_TYPE .. "deem"},
			irreg = true,
		}
	},
	{
		-- -ear (frear, nomear, semear, etc.)
		match = "ear",
		forms = {
			pres_stressed = {"ei", GL_ALTVAR .. "e"},
			e_ei_cat = true,
		}
	},
	{
		-- estar
		match = match_against_verbs("estar", {"^", "sob", "sobr"}),
		forms = {
			pres_1s = "estou",
			pres_2s = "estás",
			pres_3s = "está",
			pres_3p = {GL_TYPE .. "estám", PT_TYPE .. "estão"},
			pres1_and_sub = "estej", -- only for subjunctive as we override pres_1s
			sub_conj = "er",
			pret_conj = "irreg", pret = "estivé", pt_pret_1s = "estive", pt_pret_3s = "esteve",
			-- [[sobestar]], [[sobrestar]] are transitive so they have fully inflected past participles
			pp_inv = function(base, prefix) return prefix == "" end,
			irreg = true,
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
			pret_conj = "irreg", pret = "coubé", pt_pret_1s = "coube", pt_pret_3s = "coube",
			irreg = true,
		}
	},
	{
		-- crer, descrer
		match = "crer",
		forms = {
			pres_2s = "crês", pres_3s = "crê",
			pres_2p = "credes", pres_3p = {GL_TYPE .. "crem", PT_TYPE .. "creem"},
			pres1_and_sub = {"crei", GL_ALTVAR .. "cre"},
			irreg = true,
		}
	},
	{
		-- dizer, bendizer, condizer, contradizer, desdizer, maldizer, predizer, etc.
		match = "dizer",
		forms = {
			-- use 'digu' because we're in a front environment; if we use 'dig', we'll get '#dijo'
			pres1_and_sub = "digu",
			pres_2s = {GL_TYPE .. "dis", PT_TYPE .. "dizes"},
			pres_3s = {GL_TYPE .. "di", PT_TYPE .. "diz"},
			pres_3p = {GL_TYPE .. "dim", PT_TYPE .. "dizem"},
			pret_conj = "irreg", pret = {GL_TYPE .. "dixé", PT_TYPE .. "dissé"},
			pt_pret_1s = "disse", pt_pret_3s = "disse",
			pp = "dito",
			fut = "dir",
			irreg = true,
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
			-- use 'fagu' because we're in a front environment; if we use 'fag', we'll get '#fajo'
			pres1_and_sub = {GL_TYPE .. "fagu", PT_TYPE .. "faç"},
			pres_2s = {GL_TYPE .. "fás", PT_TYPE .. "fazes"},
			pres_3s = {GL_TYPE .. "fai", PT_TYPE .. "faz"},
			pres_3p = {GL_TYPE .. "fam", PT_TYPE .. "fazem"},
			pret_conj = "irreg", pret = {GL_TYPE .. "figé", PT_TYPE .. "fizé", GL_ONLY_ALTVAR .. "fizé"},
			pt_pret_1s = "fiz", pt_pret_3s = "fez",
			pp = "feito",
			fut = "far",
			irreg = true,
		}
	},
	{
		match = "^haver",
		forms = {
			pres_1s = "hei",
			pres_2s = "hás",
			pres_3s = {"há", {form = GL_ALTVAR .. "hai", footnotes = {"[also impersonal]"}}},
			pres_3p = {GL_TYPE .. "ham", PT_TYPE .. "hão"},
			pres1_and_sub = "haj", -- only for subjunctive as we override pres_1s
			pret_conj = "irreg", pret = "houvé", pt_pret_1s = "houve", pt_pret_3s = "houve",
			imp_2s = "há",
			irreg = true,
		}
	},
	-- reaver below under r-
	{
		-- jazer, adjazer
		match = "jazer",
		forms = {
			pres_3s = "jaz",
			irreg = true,
		}
	},
	{
		-- ler, reler, tresler; not excel(l)er, valer, etc.
		match = match_against_verbs("ler", {"^", "^re", "tres"}),
		forms = {
			pres_2s = "lês", pres_3s = "lê",
			pres_2p = "ledes", pres_3p = {GL_TYPE .. "lem", PT_TYPE .. "leem"},
			pres1_and_sub = {"lei", GL_ALTVAR .. "le"},
			irreg = true,
		}
	},
	{
		-- morrer, desmorrer
		match = "morrer",
		forms = {short_pp = "morto"}
	},
	{
		-- moer, but not remoer
		match = "^moer",
		forms = {
			pres_2s = "móis", pres_3s = "mói",
			-- impf -ía etc., pret_1s -oí and pp -oído handled automatically in combine_stem_ending()
			pres1_and_sub = {"mo", GL_ALTVAR .. "moi"},
			short_pp = "mudo",
			irreg = true,
		}
	},
	{
		-- doer, remoer, roer/corroer, soer
		match = "oer",
		forms = {
			pres_2s = "óis", pres_3s = "ói",
			-- impf -ía etc., pret_1s -oí and pp -oído handled automatically in combine_stem_ending()
			pres1_and_sub = {"o", GL_ALTVAR .. "oi"},
			irreg = true,
		}
	},
	{
		-- perder
		match = "perder",
		forms = {
			-- use 'perqu' because we're in a front environment; if we use 'perc', we'll get '#perço'
			-- we don't tag these forms GL_TYPE or PT_TYPE because both occur with both endings -ais/-ades
			pres1_and_sub = {"perd", "perqu"},
			irreg = true,
		}
	},
	{
		-- poder
		match = "poder",
		forms = {
			pres1_and_sub = {GL_TYPE .. "pod", PT_TYPE .. "poss"},
			pret_conj = "irreg", pret = "pudé", pt_pret_1s = "pude", pt_pret_3s = "pôde",
			irreg = true,
		}
	},
	{
		-- prazer, aprazer, comprazer, desprazer
		-- FIXME: comprazer also has regular preterite
		match = "prazer",
		forms = {
			pres_3s = "praz",
			pret_conj = "irreg", pret = "prouvé", pt_pret_1s = "prouve", pt_pret_3s = "prouve",
			only3sp = function(base, prefix) return prefix == "a" end,
			imp_2s = {GL_TYPE .. "praze", PT_TYPE .. "praz"},
			irreg = true,
		}
	},
	-- prover below, just below ver
	{
		-- requerer; must precede querer
		match = "requerer",
		forms = {
			pres_3s = "requer",
			pres1_and_sub = "requeir",
			imp_2s = {"requer"},
			-- regular preterite, unlike [[querer]]
			irreg = true,
		}
	},
	{
		-- querer, desquerer, malquerer
		match = "querer",
		forms = {
			pres_1s = "quero", pres_3s = "quer",
			pres1_and_sub = "queir", -- only for subjunctive as we override pres_1s
			pret_conj = "irreg", pret = {GL_TYPE .. "quigé", PT_TYPE .. "quisé"},
			pt_pret_1s = "quis", pt_pret_3s = "quis",
			irreg = true,
		}
	},
	{
		match = "reaver",
		forms = {
			pres_1s = "reei",
			pres_2s = "reás",
			pres_3s = "reá",
			pres_3p = {GL_TYPE .. "ream", PT_TYPE .. "reão"},
			pres1_and_sub = "reaj", -- only for subjunctive as we override pres_1s
			pret_conj = "irreg", pret = "reouvé", pt_pret_1s = "reouve", pt_pret_3s = "reouve",
			irreg = true,
		}
	},
	{
		-- saber, ressaber
		match = "saber",
		forms = {
			pres_1s = "sei",
			pres1_and_sub = "saib", -- only for subjunctive as we override pres_1s
			pret_conj = "irreg", pret = "soubé", pt_pret_1s = "soube", pt_pret_3s = "soube",
			irreg = true,
		}
	},
	{
		-- escrever/reescrever, circunscrever, descrever/redescrever, inscrever, prescrever, proscrever, subscrever,
		-- transcrever, others?
		match = "screver",
		forms = {
			pp = "scrito",
			irreg = true,
		}
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
			pres_1p = "somos", pres_2p = {GL_TYPE .. "sodes", PT_TYPE .. "sois"},
			pres_3p = {GL_TYPE .. "som", PT_TYPE .. "são"},
			pres1_and_sub = "sej", -- only for subjunctive as we override pres_1s
			full_impf = "ér",
			pret_conj = "irreg", pret = "fô", pret_1s = {GL_TYPE .. "fum", PT_TYPE .. "fui"}, pret_3s = "foi",
			imp_2s = "sê", imp_2p = "sede",
			pp_inv = true,
			irreg = true,
		}
	},
	{
		-- We want to match abster, conter, deter, etc. but not abater, cometer, etc. No way to avoid listing each verb.
		match = match_against_verbs("ter", {"abs", "^a", "con", "de", "entre", "man", "ob", "^re", "sus", "^"}),
		forms = {
			-- FIXME, Estraviz says 'contens', 'detens' etc. but that may be a typo
			pres_2s = function(base, prefix) return {GL_TYPE .. "tés", PT_TYPE .. (prefix == "" and "tens" or "téns")} end,
			-- FIXME, Estraviz says 'contem', 'detem' etc. but that may be a typo
			pres_3s = function(base, prefix) return prefix == "" and "tem" or "tém" end,
			pres_2p = "tendes", pres_3p = {GL_TYPE .. "tenhem", PT_TYPE .. "têm", GL_ALTVAR .. "tém"},
			pres1_and_sub = "tenh",
			full_impf = "tính",
			pret_conj = "irreg", pret = "tivé", pt_pret_1s = "tive", pt_pret_3s = "teve",
			irreg = true,
		}
	},
	{
		match = "trazer",
		forms = {
			-- use 'tragu' because we're in a front environment; if we use 'trag', we'll get '#trajo'
			pres1_and_sub = "tragu", pres_3s = "traz",
			pret_conj = "irreg", pret = "trouxé", pt_pret_1s = "trouxe", pt_pret_3s = "trouxe",
			fut = "trar",
			irreg = true,
		}
	},
	{
		match = "traguer",
		forms = {
			pret_conj = "irreg", pret = "trouxé", pt_pret_1s = "trouxe", pt_pret_3s = "trouxe",
			irreg = true,
		}
	},
	{
		-- valer, desvaler, equivaler
		match = "valer",
		forms = {
			pres1_and_sub = "valh",
			irreg = true,
		}
	},
	{
		-- We want to match antever etc. but not absolver, atrever etc. No way to avoid listing each verb.
		match = match_against_verbs("ver", {"ante", "entre", "pre", "^re", "^"}),
		forms = {
			pres_2s = "vês", pres_3s = "vê",
			pres_2p = "vedes",
			pres_3p = function(base, prefix) return {GL_TYPE .. (prefix == "" and "vem" or "vêm"), PT_TYPE .. "veem"} end,
			pres1_and_sub = "vej",
			pret_conj = "irreg", pret = "ví", pret_1s = {GL_TYPE .. "vim", PT_TYPE .. "vi"}, pret_3s = "viu",
			pp = "visto",
			irreg = true,
		}
	},
	{
		-- [[prover]] and [[desprover]] have regular preterite and past participle
		match = "prover",
		forms = {
			pres_2s = "provês", pres_3s = "provê",
			-- FIXME: Estraviz says 'provem' but that may be a typo
			pres_2p = "provedes", pres_3p = {GL_TYPE .. "provêm", PT_TYPE .. "proveem"},
			pres1_and_sub = "provej",
			irreg = true,
		}
	},
	{
		-- volver, devolver, envolver, revolver, etc.
		match = "volver",
		forms = {short_pp = "volto"},
	},

	--------------------------------------------------------------------------------------------
	--                                             -ir                                        --
	--------------------------------------------------------------------------------------------

	-- Verbs not needing entries here:
	--
	-- abolir: use <u-o>
	-- barrir: use <only3sp>
	-- carpir, colorir, demolir: use <no_pres1_and_sub>
	-- descolorir: use <no_pres1_and_sub>
	-- delir, espavorir, falir, florir, remir, renhir: use <no_pres_stressed>
	-- empedernir: use <i-e>
	-- transir: regular
	-- aspergir, despir, flectir/deflectir/genuflectir/genufletir/reflectir/refletir, mentir/desmentir,
	--   sentir/assentir/consentir/dissentir/pressentir/ressentir, convergir/divergir, aderir/adherir,
	--   ferir/auferir/conferir/deferir/desferir/diferir/differir/inferir/interferir/preferir/proferir/referir/transferir,
	--   gerir/digerir/ingerir/sugerir, preterir, competir/repetir, servir, advertir/animadvertir/divertir,
	--   vestir/investir/revestir/travestir, seguir/conseguir/desconseguir/desseguir/perseguir/prosseguir: use <i-e>
	-- inerir: use <i-e>
	-- compelir/expelir/impelir/repelir: use <i-e>
	-- dormir, engolir, tossir, subir, acudir/sacudir, fugir, sumir/consumir (NOT assumir/presumir/resumir): use <u-o>
	-- polir/repolir: use <u>
	-- premir: use <i>
	-- extorquir/retorquir: <u-o,u>
	-- agredir/progredir/regredir/transgredir: use <i>
	-- denegrir, prevenir: use <i>
	-- eclodir: use <u-o>
	-- cerzir: use <i-e>
	-- proibir/coibir: use <í>
	-- reunir: use <ú>
	-- parir/malparir: use <no_pres_stressed>
	-- explodir/implodir: use <u-o>
	--
	-- -cir alternations (aducir, ressarcir): automatically handled in combine_stem_ending()
	-- -gir alternations (agir, dirigir, exigir): automatically handled in combine_stem_ending()
	-- -guir alternations (e.g. conseguir): automatically handled in combine_stem_ending()
	-- -quir alternations (e.g. extorquir): automatically handled in combine_stem_ending()

	{
		-- verbs in -air (cair, sair, trair and derivatives: decair/descair/recair, sobres(s)air,
		-- abstrair/atrair/contrair/distrair/extrair/protrair/retrair/subtrair)
		match = "air",
		forms = {
			pres1_and_sub = "ai", pres_2s = "ais", pres_3s = "ai",
			-- all occurrences of accented í in endings handled in combine_stem_ending()
			irreg = true,
		}
	},
	{
		-- abrir/desabrir/reabrir
		match = "abrir",
		forms = {pp = "aberto"}
	},
	{
		-- cobrir/descobrir/encobrir/recobrir/redescobrir
		match = "cobrir",
		forms = {vowel_alt = "u-o", pp = "coberto"}
	},
	{
		-- conduzir, produzir, reduzir, traduzir, etc.; luzir, reluzir, tremeluzir
		match = "uzir",
		forms = {
			pres_3s = "uz",
			-- FIXME, is this correct?
			imp_2s = "uze",
			irreg = true,
		}
	},
	{
		-- pedir, desimpedir, despedir, espedir, expedir, impedir
		-- medir
		-- comedir
		match = match_against_verbs("edir", {"m", "p"}),
		forms = {
			pres1_and_sub = {GL_TYPE .. "id", PT_TYPE .. "eç"},
			irreg = true,
		}
	},
	{
		-- frigir
		match = "frigir",
		forms = {vowel_alt = "i-e", short_pp = "frito"},
	},	
	{
		-- inserir
		match = "inserir",
		forms = {vowel_alt = "i-e"},
	},
	{
		-- ir
		match = "^ir",
		forms = {
			pres_1s = "vou", pres_2s = {GL_TYPE .. "vás", PT_TYPE .. "vais"}, pres_3s = "vai",
			pres_1p = {GL_TYPE .. "imos", PT_TYPE .. "vamos"}, pres_2p = "ides",
			pres_3p = {GL_TYPE .. "vam", PT_TYPE .. "vão"},
			pres_sub_1s = {GL_TYPE .. "vaia", PT_TYPE .. "vá"},
			pres_sub_2s = {GL_TYPE .. "vaias", PT_TYPE .. "vás"},
			pres_sub_3s = {GL_TYPE .. "vaia", PT_TYPE .. "vá"},
			pres_sub_1p = {GL_TYPE .. "vaiamos", PT_TYPE .. "vamos"},
			pres_sub_2p = {GL_TYPE .. "vaiades", PT_TYPE .. "vades"},
			pres_sub_3p = {GL_TYPE .. "vaiam", PT_TYPE .. "vão"},
			pret_conj = "irreg", pret = "fô", pret_1s = {GL_TYPE .. "fum", PT_TYPE .. "fui"}, pret_3s = "foi",
			irreg = true,
		}
	},
	{
		-- emergir, imergir, submergir
		match = "mergir",
		forms = {vowel_alt = "i-e", short_pp = "merso"},
	},
	{
		match = "ouvir",
		forms = {
			pres1_and_sub = {"ouç", ALTVAR .. "oiç"},
			irreg = true,
		}
	},
	{
		-- exprimir, imprimir, comprimir (but not descomprimir per Priberam), deprimir, oprimir/opprimir (but not reprimir,
		-- suprimir/supprimir per Priberam)
		match = match_against_verbs("primir", {"^com", "ex", "im", "de", "^o", "op"}),
		forms = {short_pp = "presso"}
	},
	{
		-- rir, sorrir
		match = match_against_verbs("rir", {"^", "sor"}),
		forms = {
			pres_2s = "ris", pres_3s = "ri", pres_2p = "rides", pres_3p = {GL_TYPE .. "rim", PT_TYPE .. "riem"},
			pres1_and_sub = "ri",
			irreg = true,
		}
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
		-- verbs in -truir (construir, destruir, reconstruir) but not obstruir/desobstruir, instruir, which are handled
		-- by the default -uir handler below
		match = match_against_verbs("struir", {"con", "de"}),
		forms = {
			pres_2s = {"stróis", ALTVAR .. "struis"}, pres_3s = {"strói", ALTVAR .. "strui"},
			pres_3p = {"stroem", ALTVAR .. "struem"},
			-- all occurrences of accented í in endings handled in combine_stem_ending()
			irreg = true,
		}
	},
	{
		-- remaining verbs in -uir (concluir/excluir/incluir/concruir/concruyr, abluir/diluir, afluir/fluir/influir,
		-- aluir, anuir, atribuir/contribuir/distribuir/redistribuir/retribuir/substituir, coevoluir/evoluir,
		-- constituir/destituir/instituir/reconstituir/restituir, derruir, diminuir, estatuir, fruir/usufruir, imbuir,
		-- imiscuir, poluir, possuir, puir, pruir, ruir
		-- FIXME: old module lists short pp incluso for incluir that can't be verified, ask about this
		-- FIXME: handle -uyr verbs?
		match = function(verb)
			-- Don't match -guir verbs (e.g. [[seguir]], [[conseguir]]) or -quir verbs (e.g. [[extorquir]])
			if verb:find("guir$") or verb:find("quir$") then
				return nil
			else
				return match_against_verbs("uir", {""})(verb)
			end
		end,
		forms = {
			pres_2s = "uis", pres_3s = "ui",
			-- all occurrences of accented í in endings handled in combine_stem_ending()
			irreg = true,
		}
	},
	{
		-- We want to match advir, convir, devir, etc. but not ouvir, servir, etc. No way to avoid listing each verb.
		match = match_against_verbs("vir", {"ad", "^a", "con", "contra", "de", "^desa", "inter", "pro", "^re", "sobre", "^"}),
		forms = {
			-- FIXME, Estraviz says 'convens', 'devens' etc. but that may be a typo
			pres_2s = function(base, prefix) return {GL_TYPE .. "vés", PT_TYPE .. (prefix == "" and "vens" or "véns")} end,
			-- FIXME, Estraviz says 'convem', 'devem' etc. but that may be a typo
			pres_3s = function(base, prefix) return prefix == "" and "vem" or "vém" end,
			pres_2p = "vindes", pres_3p = {GL_TYPE .. "venhem", PT_TYPE .. "vêm", GL_ALTVAR .. "vém"},
			pres1_and_sub = "venh",
			full_impf = "vính",
			pret_conj = "irreg", pret = {GL_TYPE .. "vinhé", PT_TYPE .. "vié"},
			pret_1s = "vim", pret_3s = {GL_TYPE .. "véu", PT_TYPE .. "veio"},
			pp = "vindo",
			irreg = true,
		}
	},

	--------------------------------------------------------------------------------------------
	--                                            misc                                        --
	--------------------------------------------------------------------------------------------

	{
		-- pôr, antepor, apor, compor/decompor/descompor, contrapor, depor, dispor, expor, impor, interpor, justapor,
		-- opor, pospor, propor, repor, sobrepor, supor/pressupor, transpor, decompor, others?
		match = "p[oô]r",
		forms = {
			pres1_and_sub = "ponh",
			pres_2s = {GL_TYPE .. "pós", PT_TYPE .. "pões", GL_ALTVAR .. "pons"},
			pres_3s = {GL_TYPE .. "pom", PT_TYPE .. "põe"},
			pres_1p = "pomos", pres_2p = "pondes",
			pres_3p = {GL_TYPE .. "ponhem", PT_TYPE .. "põem", GL_ALTVAR .. "póm"},
			full_impf = "púnh",
			pret_conj = "irreg", pret = {GL_TYPE .. "pugé", PT_TYPE .. "pusé"}, pt_pret_1s = "pus", pt_pret_3s = "pôs",
			pers_inf = "po",
			gerund = "pondo", pp = "posto",
			irreg = true,
		}
	},
}

local function skip_slot(base, slot, allow_overrides)
	if not allow_overrides and (base.basic_overrides[slot] or
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


-- Apply vowel alternations to stem.
local function apply_vowel_alternations(stem, alternations)
	local alternation_stems = {}
	local saw_pres1_and_sub = false
	local saw_pres_stressed = false

	-- Process alternations other than +.
	for _, altobj in ipairs(alternations) do
		local alt = altobj.form
		local pres1_and_sub, pres_stressed, err
		-- Treat final -gu, -qu as a consonant, so the previous vowel can alternate (e.g. conseguir -> consigo).
		-- This means a verb in -guar can't have a u-ú alternation but I don't think there are any verbs like that.
		stem = rsub(stem, "([gq])u$", "%1" .. TEMPC1)
		if alt == "+" then
			-- do nothing yet
		elseif alt == "ei" then
			local before_last_vowel = rmatch(stem, "^(.*)i$")
			if not before_last_vowel then
				err = "stem should end in -i"
			else
				pres1_and_sub = nil
				pres_stressed = before_last_vowel .. "ei"
			end
		else
			local before_last_vowel, last_vowel, after_last_vowel = rmatch(stem, "^(.*)(" .. V .. ")(.-[ui])$")
			if not before_last_vowel then
				before_last_vowel, last_vowel, after_last_vowel = rmatch(stem, "^(.*)(" .. V .. ")(.-)$")
			end
			if alt == "i-e" then
				if last_vowel == "e" or last_vowel == "i" then
					pres1_and_sub = before_last_vowel .. "i" .. after_last_vowel
					if last_vowel == "i" then
						pres_stressed = before_last_vowel .. "e" .. after_last_vowel
					end
				else
					err = "should have -e- or -i- as the last vowel"
				end
			elseif alt == "i" then
				if last_vowel == "e" then
					pres1_and_sub = before_last_vowel .. "i" .. after_last_vowel
					pres_stressed = pres1_and_sub
				else
					err = "should have -e- as the last vowel"
				end
			elseif alt == "u-o" then
				if last_vowel == "o" or last_vowel == "u" then
					pres1_and_sub = before_last_vowel .. "u" .. after_last_vowel
					if last_vowel == "u" then
						pres_stressed = before_last_vowel .. "o" .. after_last_vowel
					end
				else
					err = "should have -o- or -u- as the last vowel"
				end
			elseif alt == "u" then
				if last_vowel == "o" then
					pres1_and_sub = before_last_vowel .. "u" .. after_last_vowel
					pres_stressed = pres1_and_sub
				else
					err = "should have -o- as the last vowel"
				end
			elseif alt == "í" then
				if last_vowel == "i" then
					pres_stressed = before_last_vowel .. "í" .. after_last_vowel
				else
					err = "should have -i- as the last vowel"
				end
			elseif alt == "ú" then
				if last_vowel == "u" then
					pres_stressed = before_last_vowel .. "ú" .. after_last_vowel
				else
					err = "should have -u- as the last vowel"
				end
			else
				error("Internal error: Unrecognized vowel alternation '" .. alt .. "'")
			end
		end
		if pres1_and_sub then
			pres1_and_sub = {form = pres1_and_sub:gsub(TEMPC1, "u"), footnotes = altobj.footnotes}
			saw_pres1_and_sub = true
		end
		if pres_stressed then
			pres_stressed = {form = pres_stressed:gsub(TEMPC1, "u"), footnotes = altobj.footnotes}
			saw_pres_stressed = true
		end
		table.insert(alternation_stems, {
			altobj = altobj,
			pres1_and_sub = pres1_and_sub,
			pres_stressed = pres_stressed,
			err = err
		})
	end

	-- Now do +. We check to see which stems are used by other alternations and specify those so any footnotes are
	-- properly attached.
	for _, alternation_stem in ipairs(alternation_stems) do
		if alternation_stem.altobj.form == "+" then
			local stemobj = {form = stem, footnotes = alternation_stem.altobj.footnotes}
			alternation_stem.pres1_and_sub = saw_pres1_and_sub and stemobj or nil
			alternation_stem.pres_stressed = saw_pres_stressed and stemobj or nil
		end
	end

	return alternation_stems
end


-- Add the `stem` to the `ending` for the given `slot` and apply any phonetic modifications.
-- WARNING: This function is written very carefully; changes to it can easily have unintended consequences.
local function combine_stem_ending(base, slot, prefix, stem, ending, dont_include_prefix)
	-- If the stem begins with an acute accent, this is a signal to move the accent onto the last vowel of the prefix.
	-- Cf. míngua of minguar.
	if stem:find("^" .. AC) then
		stem = rsub(stem, "^" .. AC, "")
		if dont_include_prefix then
			error("Internal error: Can't handle acute accent at beginning of stem if dont_include_prefix is given")
		end
		prefix = rsub(prefix, "([aeiouyAEIOUY])([^aeiouyAEIOUY]*)$", "%1" .. AC .. "%2")
	end

	-- Use the full stem for checking for -gui ending and such, because 'stem' is just 'u' for [[arguir]],
	-- [[delinquir]].
	local full_stem = prefix .. stem
	-- Include the prefix in the stem unless dont_include_prefix is given (used for the past participle stem).
	if not dont_include_prefix then
		stem = full_stem
	end

	-- If the ending begins with a double asterisk, this is a signal to conditionally delete the accent on the last letter
	-- of the stem. "Conditionally" means we don't do it if the last two letters would form a diphthong without the accent
	-- on the second one (e.g. in [[sair]], with stem 'saí'); but as an exception, we do delete the accent in stems
	-- ending in -guí, -quí (e.g. in [[conseguir]]) because in this case the ui isn't a diphthong.
	if ending:find("^%*%*") then
		ending = rsub(ending, "^%*%*", "")
		if rfind(full_stem, "[gq]uí$") or not rfind(full_stem, V .. "[íú]$") then
			stem = com.remove_final_accent(stem)
		end
	end

	-- If the ending begins with an asterisk, this is a signal to delete the accent on the last letter of the stem.
	-- E.g. fizé -> fizermos. Unlike for **, this removal is unconditional, so we get e.g. 'sairmos' not #'saírmos'.
	if ending:find("^%*") then
		ending = rsub(ending, "^%*", "")
		stem = com.remove_final_accent(stem)
	end

	-- If ending begins with i, it must get an accent after an unstressed vowel (in some but not all cases) to prevent
	-- the two merging into a diphthong:
	-- * cair ->
	-- *   pres: caímos, caís;
	-- *   impf: all forms (caí-);
	-- *   pret: caí (but not caim), caíste (but not caiu), caímos, caístes, caíram;
	-- *   plup: all forms (caír-);
	-- *   impf_sub: all forms (caíss-);
	-- *   fut_sub: caíres, caírem (but not cair, cairmos, cairdes)
	-- *   pp: caído (but not gerund caindo)
	-- * atribuir, other verbs in -uir -> same pattern as for cair etc.
	-- * roer ->
	-- *   pret: roí (but not roim)
	-- *   impf: all forms (roí-)
	-- *   pp: roído

	-- Don't let variant codes derail the following checks. Note that variant codes are properly added to the end of
	-- the ending, so checks against the beginning of the ending work even in their presence, but not checks against
	-- the full ending.
	local cleaned_ending = export.remove_variant_codes(ending)	
	if cleaned_ending:find("^i") and full_stem:find("[aeiou]$") and not full_stem:find("[gq]u$") and
		not cleaned_ending:find("^i[rum]$") and cleaned_ending ~= "indo" and not cleaned_ending:find("^ir[md]") then
		ending = ending:gsub("^i", "í")
	end

	-- Spelling changes in the stem; it depends on whether the stem given is the pre-front-vowel or
	-- pre-back-vowel variant, as indicated by `frontback`. We want these front-back spelling changes to happen
	-- between stem and ending, not between prefix and stem; the prefix may not have the same "front/backness"
	-- as the stem.
	local is_front = rfind(ending, "^[eiéíê]")
	if base.frontback == "front" and not is_front then
		stem = stem:gsub("c$", "ç") -- conhecer -> conheço, vencer -> venço, descer -> desço
		stem = stem:gsub("g$", "j") -- proteger -> protejo, fugir -> fujo
		stem = stem:gsub("gu$", "g") -- distinguir -> distingo, conseguir -> consigo
		stem = stem:gsub("qu$", "c") -- extorquir -> exturco
		stem = stem:gsub("([gq])ü$", "%1u") -- argüir (superseded) -> arguo, delinqüir (superseded) -> delinquo
	elseif base.frontback == "back" and is_front then
		-- The following changes are all superseded so we don't do them:
		-- averiguar -> averigüei, minguar -> mingüei; antiquar -> antiqüei, apropinquar -> apropinqüei
		-- stem = stem:gsub("([gq])u$", "%1ü")
		stem = stem:gsub("g$", "gu") -- cargar -> carguei, apagar -> apaguei
		stem = stem:gsub("c$", "qu") -- marcar -> marquei
		stem = stem:gsub("ç$", "c") -- começar -> comecei
		-- j does not go to g here; desejar -> deseje not #desege
	end

	local retval = stem .. ending
	if retval:find(GL_TYPE) and retval:find(PT_TYPE) or retval:find(GL_ONLY_TYPE) and not retval:find(GL_TYPE) then
		-- Reject clashes in "Galician"-type and "Portuguese"-type forms, e.g. '#vós dixéreis' or '#vós dissérades'.
		return nil
	end
	return retval
end


local function add3(base, slot, stems, endings, footnotes, allow_overrides)
	if skip_slot(base, slot, allow_overrides) then
		return
	end

	local function do_combine_stem_ending(stem, ending)
		return combine_stem_ending(base, slot, base.prefix, stem, ending)
	end

	iut.add_forms(base.forms, slot, stems, endings, do_combine_stem_ending, nil, nil, footnotes)
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
		add3(base, slot_pref .. "_" .. slot, stems, ending)
	end
	addit("1s", s1)
	addit("2s", s2)
	addit("3s", s3)
	addit("1p", p1)
	addit("2p", p2)
	addit("3p", p3)
end


local function construct_stems(base, vowel_alt)
	local stems = {}
	stems.pres_unstressed = base.stems.pres_unstressed or base.inf_stem
	stems.pres_stressed =
		-- If no_pres_stressed given, pres_stressed stem should be empty so no forms are generated.
		base.no_pres_stressed and {} or
		base.stems.pres_stressed or
		vowel_alt.pres_stressed or
		base.inf_stem
	stems.pres1_and_sub =
		-- If no_pres_stressed given, the entire subjunctive is missing.
		base.no_pres_stressed and {} or
		-- If no_pres1_and_sub given, pres1 and entire subjunctive are missing.
		base.no_pres1_and_sub and {} or
		base.stems.pres1_and_sub or
		vowel_alt.pres1_and_sub or
		nil
	stems.pres1 = base.stems.pres1 or stems.pres1_and_sub or stems.pres_stressed
	stems.impf = base.stems.impf or base.inf_stem
	stems.full_impf = base.stems.full_impf
	stems.pret_base = base.stems.pret_base or base.inf_stem
	stems.pret_conj = base.stems.pret_conj or base.conj
	stems.pret = base.stems.pret or iut.map_forms(iut.convert_to_general_list_form(stems.pret_base),
		function(form) return form .. base.conj_vowel end)
	stems.gl_short_pret = base.stems.gl_short_pret or iut.map_forms(iut.convert_to_general_list_form(stems.pret),
		function(form) return rsub(form, com.V .. "$", "") end)
	stems.pt_pret_1s = base.stems.pt_pret_1s
	stems.pt_pret_3s = base.stems.pt_pret_3s
	stems.fut = base.stems.fut or base.inf_stem .. base.conj
	stems.cond = base.stems.cond or stems.fut
	stems.pres_sub_stressed = base.stems.pres_sub_stressed or stems.pres1
	stems.pres_sub_unstressed = base.stems.pres_sub_unstressed or stems.pres1_and_sub or stems.pres_unstressed
	stems.sub_conj = base.stems.sub_conj or base.conj
	stems.plup = base.stems.plup or stems.pret
	stems.impf_sub = base.stems.impf_sub or stems.pret
	stems.fut_sub = base.stems.fut_sub or stems.pret
	stems.pers_inf = base.stems.pers_inf or base.inf_stem .. base.conj_vowel
	stems.pp = base.stems.pp or base.conj == "ar" and
		combine_stem_ending(base, "pp_ms", base.prefix, base.inf_stem, "ado", "dont include prefix") or
		-- use combine_stem_ending esp. so we get roído, caído, etc.
		combine_stem_ending(base, "pp_ms", base.prefix, base.inf_stem, "ido", "dont include prefix")
	stems.pp_ms = stems.pp
	local function masc_to_fem(form)
		if rfind(form, "o$") then
			return rsub(form, "o$", "a")
		else
			return form
		end
	end
	stems.pp_fs = iut.map_forms(iut.convert_to_general_list_form(stems.pp_ms), masc_to_fem)
	if base.stems.short_pp then
		stems.short_pp_ms = base.stems.short_pp
		stems.short_pp_fs = iut.map_forms(iut.convert_to_general_list_form(stems.short_pp_ms), masc_to_fem)
	end
	base.this_stems = stems
end


local function add_present_indic(base)
	local stems = base.this_stems
	local function addit(slot, stems, ending)
		add3(base, "pres_" .. slot, stems, ending)
	end
	local s2, s3, p1, p2, p3
	if base.conj == "ar" then
		s2, s3, p1, p2, p3 = "as", "a", "amos", {"ades" .. GL_TYPE, "ais" .. PT_TYPE}, "am"
	elseif base.conj == "er" or base.conj == "or" then -- verbs in -por have the present overridden
		s2, s3, p1, p2, p3 = "es", "e", "emos", {"edes" .. GL_TYPE, "eis" .. PT_TYPE}, "em"
	elseif base.conj == "ir" then
		s2, s3, p1, p2, p3 = "es", "e", "imos", {"ides" .. GL_TYPE, "is" .. PT_TYPE}, "em"
	else
		error("Internal error: Unrecognized conjugation " .. base.conj)
	end

	addit("1s", stems.pres1, "o")
	addit("2s", stems.pres_stressed, s2)
	addit("3s", stems.pres_stressed, s3)
	addit("1p", stems.pres_unstressed, p1)
	addit("2p", stems.pres_unstressed, p2)
	addit("3p", stems.pres_stressed, p3)
end


local function add_present_subj(base)
	local stems = base.this_stems
	local function addit(slot, stems, ending)
		add3(base, "pres_sub_" .. slot, stems, ending)
	end

	local s1, s2, s3, p1, p2, p3
	if stems.sub_conj == "ar" then
		s1, s2, s3, p1, p2, p3 = "e", "es", "e", "emos", {"edes" .. GL_TYPE, "eis" .. PT_TYPE}, "em"
	else
		s1, s2, s3, p1, p2, p3 = "a", "as", "a", "amos", {"ades" .. GL_TYPE, "ais" .. PT_TYPE}, "am"
	end

	addit("1s", stems.pres_sub_stressed, s1)
	addit("2s", stems.pres_sub_stressed, s2)
	addit("3s", stems.pres_sub_stressed, s3)
	addit("1p", stems.pres_sub_unstressed, p1)
	addit("2p", stems.pres_sub_unstressed, p2)
	addit("3p", stems.pres_sub_stressed, p3)
end


local function add_finite_non_present(base)
	local stems = base.this_stems
	local function add_tense(slot, stem, s1, s2, s3, p1, p2, p3)
		add_single_stem_tense(base, slot, stem, s1, s2, s3, p1, p2, p3)
	end

	-- * at the beginning of the ending means to remove an accent from the last vowel of the imperfect stem.
	if stems.full_impf then
		add_tense("impf", stems.full_impf, "*a", "*as", "*a", "amos",
			{"ades" .. GL_TYPE, "eis" .. PT_TYPE, "ais" .. GL_ALTVAR}, "*am")
	elseif base.conj == "ar" then
		add_tense("impf", stems.impf, "ava", "avas", "ava", "ávamos",
			{"ávades" .. GL_TYPE, "áveis" .. PT_TYPE, "ávais" .. GL_ALTVAR}, "avam")
	else
		add_tense("impf", stems.impf, "ia", "ias", "ia", "íamos",
			{"íades" .. GL_TYPE, "íeis" .. PT_TYPE, "íais" .. GL_ALTVAR}, "iam")
	end

	-- * at the beginning of the ending means to remove a final accent from the preterite stem.
	if stems.pret_conj == "irreg" then
		add_tense("pret", stems.gl_short_pret, "em" .. GL_TYPE, nil, "o" .. GL_TYPE)
		add_tense("pret", stems.pret, nil, {"*ste", "*che" .. GL_ALTVAR}, nil, "*mos", "*stes",
			{"rom" .. GL_TYPE, "*ram" .. PT_TYPE})
		add_tense("pret", stems.pt_pret_1s, PT_TYPE)
		add_tense("pret", stems.pt_pret_3s, nil, nil, PT_TYPE)
	elseif stems.pret_conj == "ar" then
		add_tense("pret", stems.pret_base, "ei", {"aste", "ache" .. GL_ALTVAR}, "ou", "amos", "astes",
			{"árom" .. GL_TYPE, "aram" .. PT_TYPE})
	elseif stems.pret_conj == "er" then
		add_tense("pret", stems.pret_base, {"im" .. GL_TYPE, "i" .. PT_TYPE}, {"este", "eche" .. GL_ALTVAR}, "eu",
			"emos", "estes", {"êrom" .. GL_TYPE, "eram" .. PT_TYPE})
	else
		add_tense("pret", stems.pret_base, {"im" .. GL_TYPE, "i" .. PT_TYPE}, {"iste", "iche" .. GL_ALTVAR}, "iu",
			"imos", "istes", {"írom" .. GL_TYPE, "iram" .. PT_TYPE})
	end

	-- * at the beginning of the ending means to remove a final accent from the stem.
	-- ** is similar but is "conditional" on a consonant preceding the final vowel.
	add_tense("plup", stems.plup, "**ra", "**ras", "**ra", "ramos",
		{"rades" .. GL_TYPE, "reis" .. PT_TYPE, "rais" .. GL_ALTVAR}, "**ram")
	add_tense("impf_sub", stems.impf_sub, "**sse", "**sses", "**sse", "ssemos",
		{"ssedes" .. GL_TYPE, "sseis" .. PT_TYPE}, "**ssem")
	add_tense("fut_sub", stems.fut_sub, "*r", "**res", "*r", "*rmos", "*rdes", "**rem")
	if base.refl then
		local mark = TEMP_MESOCLITIC_INSERTION_POINT
		add_tense("fut", stems.fut,
			{"ei" .. GL_TYPE, mark .. "ei" .. PT_TYPE}, {"ás" .. GL_TYPE, mark .. "ás" .. PT_TYPE},
			{"á" .. GL_TYPE, mark .. "á" .. PT_TYPE}, {"emos" .. GL_TYPE, mark .. "emos" .. PT_TYPE},
			{"edes" .. GL_TYPE, mark .. "eis" .. PT_TYPE}, {"ám" .. GL_TYPE, mark .. "ão" .. PT_TYPE}
		)
		add_tense("cond", stems.cond,
			{"ia" .. GL_TYPE, mark .. "ia" .. PT_TYPE}, {"ias" .. GL_TYPE, mark .. "ias" .. PT_TYPE},
			{"ia" .. GL_TYPE, mark .. "ia" .. PT_TYPE}, {"íamos" .. GL_TYPE, mark .. "íamos" .. PT_TYPE},
			-- FIXME, is GL_ALTVAR correct for the mesoclitic variant of -íais?
			{"íades" .. GL_TYPE, mark .. "íeis" .. PT_TYPE, "íais" .. GL_ALTVAR, mark .. "íais" .. GL_ALTVAR},
			{"iam" .. GL_TYPE, mark .. "iam" .. PT_TYPE})
	else
		-- Don't insert forms with the mesoclitic insertion point to avoid duplication in non-reflexive verbs.
		add_tense("fut", stems.fut, "ei", "ás", "á", "emos", {"edes" .. GL_TYPE, "eis" .. PT_TYPE},
			{"ám" .. GL_TYPE, "ão" .. PT_TYPE})
		add_tense("cond", stems.cond, "ia", "ias", "ia", "íamos",
			-- FIXME, is GL_ALTVAR correct for the mesoclitic variant of -íais?
			{"íades" .. GL_TYPE, "íeis" .. PT_TYPE, "íais" .. GL_ALTVAR}, "iam")
	end
	-- Different stems for different parts of the personal infinitive to correctly handle forms of [[sair]] and [[pôr]].
	add_tense("pers_inf", base.non_prefixed_verb, "", nil, "")
	add_tense("pers_inf", stems.pers_inf, nil, "**res", nil, "*rmos", "*rdes", "**rem")
end


local function add_non_finite_forms(base)
	local stems = base.this_stems
	local function addit(slot, stems, ending, footnotes)
		add3(base, slot, stems, ending, footnotes)
	end

	insert_form(base, "infinitive", {form = base.verb})
	-- Also insert "infinitive + reflexive pronoun" combinations if we're handling a reflexive verb. See comment below for
	-- "gerund + reflexive pronoun" combinations.
	if base.refl then
		for _, persnum in ipairs(person_number_list) do
			insert_form(base, "infinitive_" .. persnum, {form = base.verb})
		end
	end
	-- verbs in -por have the gerund overridden
	local ger_ending = base.conj == "ar" and "ando" or base.conj == "er" and "endo" or "indo"
	addit("gerund", stems.pres_unstressed, ger_ending)
	-- Also insert "gerund + reflexive pronoun" combinations if we're handling a reflexive verb. We insert exactly the same
	-- form as for the bare gerund; later on in add_reflexive_or_fixed_clitic_to_forms(), we add the appropriate clitic
	-- pronouns. It's important not to do this for non-reflexive verbs, because in that case, the clitic pronouns won't be
	-- added, and {{gl-reinteg-verb form of}} will wrongly consider all these combinations as possible inflections of the bare
	-- gerund. Thanks to [[User:JeffDoozan]] for this bug fix.
    if base.refl then
		for _, persnum in ipairs(person_number_list) do
			addit("gerund_" .. persnum, stems.pres_unstressed, ger_ending)
		end
	end
	-- Skip the long/short past participle footnotes if called from {{gl-reinteg-verb}} so they don't show in the headword.
	local long_pp_footnotes =
		stems.short_pp_ms and base.alternant_multiword_spec.source_template ~= "gl-reinteg-verb" and {long_pp_footnote} or nil
	addit("pp_ms", stems.pp_ms, "", long_pp_footnotes)
	if not base.pp_inv then
		addit("pp_fs", stems.pp_fs, "", long_pp_footnotes)
		addit("pp_mp", stems.pp_ms, "s", long_pp_footnotes)
		addit("pp_fp", stems.pp_fs, "s", long_pp_footnotes)
	end
	if stems.short_pp_ms then
		local short_pp_footnotes =
			stems.short_pp_ms and base.alternant_multiword_spec.source_template ~= "gl-reinteg-verb" and {short_pp_footnote} or nil
		addit("short_pp_ms", stems.short_pp_ms, "", short_pp_footnotes)
		if not base.pp_inv then
			addit("short_pp_fs", stems.short_pp_fs, "", short_pp_footnotes)
			addit("short_pp_mp", stems.short_pp_ms, "s", short_pp_footnotes)
			addit("short_pp_fp", stems.short_pp_fs, "s", short_pp_footnotes)
		end
	end
end


local function copy_forms_to_imperatives(base)
	-- Copy pres3s to imperative since they are almost always the same.
	insert_forms(base, "imp_2s", iut.map_forms(base.forms.pres_3s, function(form) return form end))
	if not skip_slot(base, "imp_2p") then
		-- Copy pres2p to imperative 2p minus -s since they are almost always the same.
		-- But not if there's an override, to avoid possibly throwing an error.
		insert_forms(base, "imp_2p", iut.map_forms(base.forms.pres_2p, function(form)
			local form_no_s, var_codes = rmatch(form, "^(.*)s(" .. var_code_c .. "*)$")
			if not form_no_s then
				error("Can't derive second-person plural imperative from second-person plural present indicative " ..
					"because form '" .. form .. "' doesn't end in -s")
			end
			return form_no_s .. var_codes
		end))
	end
	-- Copy subjunctives to imperatives, unless there's an override for the given slot (as with the imp_1p of [[ir]]).
	for _, persnum in ipairs({"3s", "1p", "3p"}) do
		local from = "pres_sub_" .. persnum
		local to = "imp_" .. persnum
		insert_forms(base, to, iut.map_forms(base.forms[from], function(form) return form end))
	end
end


local function process_slot_overrides(base, filter_slot, reflexive_only)
	local overrides = reflexive_only and base.basic_reflexive_only_overrides or base.basic_overrides
	for slot, forms in pairs(overrides) do
		if not filter_slot or filter_slot(slot) then
			add3(base, slot, forms, "", nil, "allow overrides")
		end
	end
end


-- Prefix `form` with `clitic`, adding fixed text `between` between them. Add links as appropriate unless the user
-- requested no links. Check whether form already has brackets (as will be the case if the form has a fixed clitic).
local function prefix_clitic_to_form(base, clitic, between, form)
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


-- Add the appropriate clitic pronouns in `clitics` to the forms in `base_slot`. `store_cliticized_form` is a function
-- of three arguments (clitic, formobj, cliticized_form) and should store the cliticized form for the specified clitic
-- and form object.
local function suffix_clitic_to_forms(base, base_slot, clitics, store_cliticized_form)
	if not base.forms[base_slot] then
		-- This can happen, e.g. in only3s/only3sp/only3p verbs.
		return
	end
	local autolink = not base.alternant_multiword_spec.args.noautolinkverb
	for _, formobj in ipairs(base.forms[base_slot]) do
		for _, clitic in ipairs(clitics) do
			local cliticized_form
			if formobj.form:find(TEMP_MESOCLITIC_INSERTION_POINT) then
				-- mesoclisis in future and conditional
				local infinitive, suffix = rmatch(formobj.form, "^(.*)" .. TEMP_MESOCLITIC_INSERTION_POINT .. "(.*)$")
				if not infinitive then
					error("Internal error: Can't find mesoclitic insertion point in slot '" .. base_slot .. "', form '" ..
						formobj.form .. "'")
				end
				local full_form = infinitive .. suffix
				if autolink and not infinitive:find("%[%[") then
					infinitive = "[[" .. infinitive .. "]]"
				end
				cliticized_form =
					autolink and infinitive .. "-[[" .. clitic .. "]]-[[" .. full_form .. "|" .. suffix .. "]]" or
					infinitive .. "-" .. clitic .. "-" .. suffix
			else
				local clitic_suffix = autolink and "-[[" .. clitic .. "]]" or "-" .. clitic
				local form_needs_link = autolink and not formobj.form:find("%[%[")
				if base_slot:find("1p$") then
					-- Final -s disappears: arrependíamos + nos -> arrependíamo-nos, etc.
					cliticized_form = formobj.form:gsub("s$", "")
					if form_needs_link then
						cliticized_form = "[[" .. formobj.form .. "|" .. cliticized_form .. "]]"
					end
				else
					cliticized_form = formobj.form
					if form_needs_link then
						cliticized_form = "[[" .. cliticized_form .. "]]"
					end
				end
				cliticized_form = cliticized_form .. clitic_suffix
			end
			store_cliticized_form(clitic, formobj, cliticized_form)
		end
	end
end

-- Add a reflexive pronoun or fixed clitic (FIXME: not working), as appropriate to the base forms that were generated.
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
				local slot_has_suffixed_clitic = not slot:find("_sub")
				-- Maybe generate non-reflexive parts and separated syntactic variants for use in
				-- {{gl-reinteg-verb form of}}. See comment in add_slots() above `need_special_verb_form_of_slots`.
				-- Check for do_joined so we only run this code once.
				if do_reflexive and do_joined and base.alternant_multiword_spec.source_template == "gl-reinteg-verb form of" and
					-- Skip personal variants of infinitives and gerunds so we don't think [[arrependendo]] is a
					-- non-reflexive equivalent of [[arrependendo-me]].
					not slot:find("infinitive_") and not slot:find("gerund_") then
					-- Clone the forms because we will be destructively modifying them just below, adding the reflexive
					-- pronoun.
					insert_forms(base, slot .. "_non_reflexive", mw.clone(base.forms[slot]))
					if slot_has_suffixed_clitic then
						insert_forms(base, slot .. "_variant", iut.map_forms(base.forms[slot], function(form)
							return prefix_clitic_to_form(base, clitic, " ... ", form)
						end))
					end
				end
				if slot_has_suffixed_clitic then
					if do_joined then
						suffix_clitic_to_forms(base, slot, {clitic},
							function(clitic, formobj, cliticized_form)
								formobj.form = cliticized_form
							end
						)
					end
				elseif not do_joined then
					-- Add clitic as separate word before all other forms.
					for _, form in ipairs(base.forms[slot]) do
						form.form = prefix_clitic_to_form(base, clitic, " ", form.form)
					end
				end
			end
		end
	end
end


local function handle_infinitive_linked(base)
	-- Compute linked versions of potential lemma slots, for use in {{gl-reinteg-verb}}.
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
	-- Copy subjunctives to negative imperatives, preceded by "nom".
	for _, persnum in ipairs(neg_imp_person_number_list) do
		local from = "pres_sub_" .. persnum
		local to = "neg_imp_" .. persnum
		insert_forms(base, to, iut.map_forms(base.forms[from], function(form)
			if base.alternant_multiword_spec.args.noautolinkverb then
				return "nom " .. form
			elseif form:find("%[%[") then
				-- already linked, e.g. when reflexive
				return "[[nom]] " .. form
			else
				return "[[nom]] [[" .. form .. "]]"
			end
		end))
	end
end


-- Process specs given by the user using 'addnote[SLOTSPEC][FOOTNOTE][FOOTNOTE][...]'.
local function process_addnote_specs(base)
	for _, spec in ipairs(base.addnote_specs) do
		for _, slot_spec in ipairs(spec.slot_specs) do
			slot_spec = "^" .. slot_spec .. "$"
			for slot, forms in pairs(base.forms) do
				if rfind(slot, slot_spec) then
					-- To save on memory, side-effect the existing forms.
					for _, form in ipairs(forms) do
						form.footnotes = iut.combine_footnotes(form.footnotes, spec.footnotes)
					end
				end
			end
		end
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


-- Remove special characters added to future and conditional forms to indicate mesoclitic insertion points.
local function remove_mesoclitic_insertion_points(base)
	for slot, forms in pairs(base.forms) do
		if slot:find("^fut_") or slot:find("^cond_") then
			for _, form in ipairs(forms) do
				form.form = form.form:gsub(TEMP_MESOCLITIC_INSERTION_POINT, "")
			end
		end
	end
end


-- If called from {{gl-reinteg-verb}}, remove less-recommended variants; otherwise add a footnote indicating they are
-- less recommended, and sort them last.
local function process_altvar_forms(base)
	for slot, forms in pairs(base.forms) do
		-- As an optimization, check if there are any less-recommended forms and don't do anything if not.
		local saw_altvar = false
		for _, form in ipairs(forms) do
			if form.form:find(ALTVAR) then
				saw_altvar = true
				break
			end
		end
		if saw_altvar then
			if base.alternant_multiword_spec.source_template == "gl-reinteg-verb" then
				base.forms[slot] = iut.flatmap_forms(base.forms[slot], function(form)
					if form:find(ALTVAR) then
						return {}
					else
						return {form}
					end
				end)
			else
				local existing_forms = base.forms[slot]
				base.forms[slot] = {}
				for _, formobj in ipairs(existing_forms) do
					if not formobj.form:find(ALTVAR) then
						iut.insert_form(base.forms, slot, formobj)
					end
				end
				for _, formobj in ipairs(existing_forms) do
					if formobj.form:find(ALTVAR) then
						formobj.footnotes = iut.combine_footnotes(formobj.footnotes, {"[less recommended]"})
						iut.insert_form(base.forms, slot, formobj)
					end
				end
			end
		end
	end
end


local function conjugate_verb(base)
	for _, vowel_alt in ipairs(base.vowel_alt_stems) do
		construct_stems(base, vowel_alt)
		add_present_indic(base)
		add_present_subj(base)
	end
	add_finite_non_present(base)
	add_non_finite_forms(base)
	-- do non-reflexive non-imperative slot overrides
	process_slot_overrides(base, function(slot)
		return not slot:find("^imp_") and not slot:find("^neg_imp_")
	end)
	-- This should happen after process_slot_overrides() in case a derived slot is based on an override
	-- (as with the imp_3s of [[dar]], [[estar]]).
	copy_forms_to_imperatives(base)
	-- do non-reflexive positive imperative slot overrides
	process_slot_overrides(base, function(slot)
		return slot:find("^imp_")
	end)
	-- We need to add joined reflexives, then joined and non-joined clitics, then non-joined reflexives, so we get
	-- [[arrepende-te]] but [[nom]] [[te]] [[arrependas]].
	if base.refl then
		add_reflexive_or_fixed_clitic_to_forms(base, "do reflexive", "do joined")
		process_slot_overrides(base, nil, "do reflexive") -- do reflexive-only slot overrides
		add_reflexive_or_fixed_clitic_to_forms(base, "do reflexive", false)
	end
	-- This should happen after add_reflexive_or_fixed_clitic_to_forms() so negative imperatives get the reflexive pronoun
	-- and clitic in them.
	generate_negative_imperatives(base)
	-- do non-reflexive negative imperative slot overrides
	-- FIXME: What about reflexive negative imperatives?
	process_slot_overrides(base, function(slot)
		return slot:find("^neg_imp_")
	end)
	-- This should happen before add_missing_links_to_forms() so that the comparison `form == base.lemma`
	-- in handle_infinitive_linked() works correctly and compares unlinked forms to unlinked forms.
	handle_infinitive_linked(base)
	process_addnote_specs(base)
	if not base.alternant_multiword_spec.args.noautolinkverb then
		add_missing_links_to_forms(base)
	end
	remove_mesoclitic_insertion_points(base)
	process_altvar_forms(base)
end


local function parse_indicator_spec(angle_bracket_spec)
	-- Store the original angle bracket spec so we can reconstruct the overall conj spec with the lemma(s) in them.
	local base = {
		angle_bracket_spec = angle_bracket_spec,
		user_basic_overrides = {},
		user_stems = {},
		addnote_specs = {},
	}
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
		local first_element = dot_separated_group[1]
		if first_element == "addnote" then
			local spec_and_footnotes = fetch_footnotes(dot_separated_group)
			if #spec_and_footnotes < 2 then
				parse_err("Spec with 'addnote' should be of the form 'addnote[SLOTSPEC][FOOTNOTE][FOOTNOTE][...]'")
			end
			local slot_spec = table.remove(spec_and_footnotes, 1)
			local slot_spec_inside = rmatch(slot_spec, "^%[(.*)%]$")
			if not slot_spec_inside then
				parse_err("Internal error: slot_spec " .. slot_spec .. " should be surrounded with brackets")
			end
			local slot_specs = rsplit(slot_spec_inside, ",")
			-- FIXME: Here, [[Module:it-verb]] called strip_spaces(). Generally we don't do this. Should we?
			table.insert(base.addnote_specs, {slot_specs = slot_specs, footnotes = spec_and_footnotes})
		elseif indicator_flags[first_element] then
			if #dot_separated_group > 1 then
				parse_err("No footnotes allowed with '" .. first_element .. "' spec")
			end
			if base[first_element] then
				parse_err("Spec '" .. first_element .. "' specified twice")
			end
			base[first_element] = true
		elseif rfind(first_element, ":") then
			local colon_separated_groups = iut.split_alternating_runs(dot_separated_group, "%s*:%s*")
			local first_element = colon_separated_groups[1][1]
			if #colon_separated_groups[1] > 1 then
				parse_err("Can't attach footnotes directly to '" .. first_element .. "' spec; attach them to the " ..
					"colon-separated values following the initial colon")
			end
			if overridable_stems[first_element] then
				if base.user_stems[first_element] then
					parse_err("Overridable stem '" .. first_element .. "' specified twice")
				end
				table.remove(colon_separated_groups, 1)
				base.user_stems[first_element] = overridable_stems[first_element](colon_separated_groups,
					{prefix = first_element, base = base, parse_err = parse_err, fetch_footnotes = fetch_footnotes})
			else -- assume a basic override; we validate further later when the possible slots are available
				if base.user_basic_overrides[first_element] then
					parse_err("Basic override '" .. first_element .. "' specified twice")
				end
				table.remove(colon_separated_groups, 1)
				base.user_basic_overrides[first_element] = allow_multiple_values(colon_separated_groups,
					{prefix = first_element, base = base, parse_err = parse_err, fetch_footnotes = fetch_footnotes})
			end
		else
			local comma_separated_groups = iut.split_alternating_runs(dot_separated_group, "%s*,%s*")
			for j = 1, #comma_separated_groups do
				local alt = comma_separated_groups[j][1]
				if not vowel_alternants[alt] then
					if #comma_separated_groups == 1 then
						parse_err("Unrecognized spec or vowel alternant '" .. alt .. "'")
					else
						parse_err("Unrecognized vowel alternant '" .. alt .. "'")
					end
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
		end
	end

	return base
end


-- Normalize all lemmas, substituting the pagename for blank lemmas and adding links to multiword lemmas.
local function normalize_all_lemmas(alternant_multiword_spec, head)

	-- (1) Add links to all before and after text. Remember the original text so we can reconstruct the verb spec later.
	if not alternant_multiword_spec.args.noautolinktext then
		iut.add_links_to_before_and_after_text(alternant_multiword_spec, "remember original")
	end

	-- (2) Remove any links from the lemma, but remember the original form
	--     so we can use it below in the 'lemma_linked' form.
	iut.map_word_specs(alternant_multiword_spec, function(base)
		if base.lemma == "" then
			base.lemma = head
		end

		base.user_specified_lemma = base.lemma

		base.lemma = m_links.remove_links(base.lemma)
		local refl_verb = base.lemma
		local verb, refl = rmatch(refl_verb, "^(.-)%-(se)$")
		if not verb then
			verb, refl = refl_verb, nil
		end
		base.user_specified_verb = verb
		base.refl = refl
		base.verb = base.user_specified_verb

		local linked_lemma
		if alternant_multiword_spec.args.noautolinkverb or base.user_specified_lemma:find("%[%[") then
			linked_lemma = base.user_specified_lemma
		elseif base.refl then
			-- Reconstruct the linked lemma with separate links around base verb and reflexive pronoun.
			linked_lemma = base.user_specified_verb == base.verb and "[[" .. base.user_specified_verb .. "]]" or
				"[[" .. base.verb .. "|" .. base.user_specified_verb .. "]]"
			linked_lemma = linked_lemma .. (refl and "-[[" .. refl .. "]]" or "")
		else
			-- Add links to the lemma so the user doesn't specifically need to, since we preserve
			-- links in multiword lemmas and include links in non-lemma forms rather than allowing
			-- the entire form to be a link.
			linked_lemma = iut.add_links(base.user_specified_lemma)
		end
		base.linked_lemma = linked_lemma
	end)
end


local function detect_indicator_spec(base)
	if (base.only3s and 1 or 0) + (base.only3sp and 1 or 0) + (base.only3p and 1 or 0) > 1 then
		error("Only one of 'only3s', 'only3sp' and 'only3p' can be specified")
	end

	base.forms = {}
	base.stems = {}
	base.basic_overrides = {}
	base.basic_reflexive_only_overrides = {}
	if not base.no_built_in then
		for _, built_in_conj in ipairs(built_in_conjugations) do
			if type(built_in_conj.match) == "function" then
				base.prefix, base.non_prefixed_verb = built_in_conj.match(base.verb)
			elseif built_in_conj.match:find("^%^") and rsub(built_in_conj.match, "^%^", "") == base.verb then
				-- begins with ^, for exact match, and matches
				base.prefix, base.non_prefixed_verb = "", base.verb
			else
				base.prefix, base.non_prefixed_verb = rmatch(base.verb, "^(.*)(" .. built_in_conj.match .. ")$")
			end
			if base.prefix then
				-- we found a built-in verb
				for stem, forms in pairs(built_in_conj.forms) do
					if type(forms) == "function" then
						forms = forms(base, base.prefix)
					end
					if stem:find("^refl_") then
						stem = stem:gsub("^refl_", "")
						if not base.alternant_multiword_spec.verb_slots_basic_map[stem] then
							error("Internal error: setting for 'refl_" .. stem .. "' does not refer to a basic verb slot")
						end
						base.basic_reflexive_only_overrides[stem] = forms
					elseif base.alternant_multiword_spec.verb_slots_basic_map[stem] then
						-- an individual form override of a basic form
						base.basic_overrides[stem] = forms
					else
						base.stems[stem] = forms
					end
				end
				break
			end
		end
	end

	-- Override built-in-verb stems and overrides with user-specified ones.
	for stem, values in pairs(base.user_stems) do
		base.stems[stem] = values
	end
	for override, values in pairs(base.user_basic_overrides) do
		if not base.alternant_multiword_spec.verb_slots_basic_map[override] then
			error("Unrecognized override '" .. override .. "': " .. base.angle_bracket_spec)
		end
		base.basic_overrides[override] = values
	end

	base.prefix = base.prefix or ""
	base.non_prefixed_verb = base.non_prefixed_verb or base.verb
	local inf_stem, suffix = rmatch(base.non_prefixed_verb, "^(.*)([aeioô]r)$")
	if not inf_stem then
		error("Unrecognized infinitive: " .. base.verb)
	end
	base.inf_stem = inf_stem
	suffix = suffix == "ôr" and "or" or suffix
	base.conj = suffix
	base.conj_vowel = suffix == "ar" and "á" or suffix == "ir" and "í" or "ê"
	base.frontback = suffix == "ar" and "back" or "front"

	if base.stems.vowel_alt then -- built-in verb with specified vowel alternation
		if base.vowel_alt then
			error(base.verb .. " is a recognized built-in verb, and should not have vowel alternations specified with it")
		end
		base.vowel_alt = iut.convert_to_general_list_form(base.stems.vowel_alt)
	end
	-- Propagate built-in-verb indicator flags to `base` and combine with user-specified flags.
	for indicator_flag, _ in pairs(indicator_flags) do
		base[indicator_flag] = base[indicator_flag] or base.stems[indicator_flag]
	end

	-- Convert vowel alternation indicators into stems.
	local vowel_alt = base.vowel_alt or {{form = "+"}}
	base.vowel_alt_stems = apply_vowel_alternations(base.inf_stem, vowel_alt)
	for _, vowel_alt_stems in ipairs(base.vowel_alt_stems) do
		if vowel_alt_stems.err then
			error("To use '" .. vowel_alt_stems.altobj.form .. "', present stem '" .. base.prefix .. base.inf_stem .. "' " ..
				vowel_alt_stems.err)
		end
	end
end


local function detect_all_indicator_specs(alternant_multiword_spec)
	-- Propagate some settings up; some are used internally, others by [[Module:gl-headword]].
	iut.map_word_specs(alternant_multiword_spec, function(base)
		-- Internal indicator flags. Do these before calling detect_indicator_spec() because add_slots() uses them.
		for  _, prop in ipairs { "refl", "clitic" } do
			if base[prop] then
				alternant_multiword_spec[prop] = true
			end
		end
		base.alternant_multiword_spec = alternant_multiword_spec
	end)

	add_slots(alternant_multiword_spec)

	alternant_multiword_spec.vowel_alt = {}
	iut.map_word_specs(alternant_multiword_spec, function(base)
		detect_indicator_spec(base)
		-- User-specified indicator flags. Do these after calling detect_indicator_spec() because the latter may set these
		-- indicators for built-in verbs.
		for prop, _ in pairs(indicator_flags) do
			if base[prop] then
				alternant_multiword_spec[prop] = true
			end
		end
		-- Vowel alternants. Do these after calling detect_indicator_spec() because the latter sets base.vowel_alt for
		-- built-in verbs.
		if base.vowel_alt then
			for _, altobj in ipairs(base.vowel_alt) do
				m_table.insertIfNot(alternant_multiword_spec.vowel_alt, altobj.form)
			end
		end
	end)
end


local function add_categories_and_annotation(alternant_multiword_spec, base, multiword_lemma)
	local function insert_ann(anntype, value)
		m_table.insertIfNot(alternant_multiword_spec.annotation[anntype], value)
	end

	local function insert_cat(cat, also_when_multiword)
		-- Don't place multiword terms in categories like 'Galician verbs ending in -ar' to avoid spamming the
		-- categories with such terms.
		if also_when_multiword or not multiword_lemma then
			m_table.insertIfNot(alternant_multiword_spec.categories, "Galician " .. cat)
		end
	end

	if check_for_red_links and alternant_multiword_spec.source_template == "gl-reinteg-conj" and multiword_lemma then
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
	
	if(base.conj == "or") then
		insert_cat("verbs ending in -er")
	else
		insert_cat("verbs ending in -" .. base.conj)
	end

	if base.irreg then
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

	if base.stems.short_pp then
		insert_ann("short_pp", "irregular short past participle")
		insert_cat("verbs with irregular short past participle")
	else
		insert_ann("short_pp", "regular")
	end

	if base.clitic then
		insert_cat("verbs with lexical clitics")
	end

	if base.refl then
		insert_cat("reflexive verbs")
	end

	if base.e_ei_cat then
		insert_ann("vowel_alt", "''e'' may become ''ei'' when stressed")
		insert_cat("verbs with e becoming ei when stressed")
	elseif not base.vowel_alt then
		insert_ann("vowel_alt", "non-alternating")
	else
		for _, alt in ipairs(base.vowel_alt) do
			if alt.form == "+" then
				insert_ann("vowel_alt", "non-alternating")
			else
				insert_ann("vowel_alt", vowel_alternant_to_desc[alt.form])
				insert_cat("verbs with " .. vowel_alternant_to_cat[alt.form])
			end
		end
	end

	local cons_alt = base.stems.cons_alt
	if cons_alt == nil then
		if base.conj == "ar" then
			if base.inf_stem:find("ç$") then
				cons_alt = "c-ç"
			elseif base.inf_stem:find("c$") then
				cons_alt = "c-qu"
			elseif base.inf_stem:find("g$") then
				cons_alt = "g-gu"
			end
		else
			if base.no_pres_stressed or base.no_pres1_and_sub then
				cons_alt = nil -- no e.g. c-ç alternation in this case
			elseif base.inf_stem:find("c$") then
				cons_alt = "c-ç"
			elseif base.inf_stem:find("qu$") then
				cons_alt = "c-qu"
			elseif base.inf_stem:find("g$") then
				cons_alt = "g-j"
			elseif base.inf_stem:find("gu$") then
				cons_alt = "g-gu"
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
	ann.short_pp = {}
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
	local short_pp = table.concat(ann.short_pp, " or ")
	if short_pp ~= "" and short_pp ~= "regular" then
		table.insert(ann_parts, short_pp)
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
	local lemmas = alternant_multiword_spec.forms.infinitive
	alternant_multiword_spec.lemmas = lemmas -- save for later use in make_table()

	if alternant_multiword_spec.forms.short_pp_ms then
		alternant_multiword_spec.has_short_pp = true
	end
	local reconstructed_verb_spec = iut.reconstruct_original_spec(alternant_multiword_spec)

	local function transform_accel_obj(slot, formobj, accel_obj)
		-- No accelerators for negative imperatives, which are always multiword and derived directly from the
		-- present subjunctive.
		if slot:find("^neg_imp") then
			return nil
		end
		if accel_obj then
			if slot:find("^pp_") then
				accel_obj.form = slot
			elseif slot == "gerund" then
				accel_obj.form = "reinteg-gerund-" .. reconstructed_verb_spec
			else
				accel_obj.form = "reinteg-verb-form-" .. reconstructed_verb_spec
			end
		end
		return accel_obj
	end

	-- Italicize less-recommended forms.
	local function generate_link(data)
		local formval_for_link = data.form.formval_for_link
		if formval_for_link:find(ALTVAR) then
			formval_for_link = formval_for_link:gsub(ALTVAR, "")
			return m_links.full_link({lang = lang, term = formval_for_link, tr = "-", accel = data.form.accel_obj},
				"term") .. iut.get_footnote_text(data.form.footnotes, data.footnote_obj)
		end
	end

	local props = {
		lang = lang,
		lemmas = lemmas,
		transform_accel_obj = transform_accel_obj,
		canonicalize = function(form) return export.remove_variant_codes(form, "keep altvar") end,
		generate_link = generate_link,
		slot_list = alternant_multiword_spec.verb_slots_basic,
	}
	iut.show_forms(alternant_multiword_spec.forms, props)
	alternant_multiword_spec.footnote_basic = alternant_multiword_spec.forms.footnote
end


local notes_template = [=[
<div style="width:100%;text-align:left;background:#d9ebff">
<div style="display:inline-block;text-align:left;padding-left:1em;padding-right:1em">
{footnote}
</div></div>
]=]

local basic_table = [=[
{description}<div class="NavFrame">
<div class="NavHead" align=center>&nbsp; &nbsp; Reintegrated conjugation of {title} (See [[Appendix:Reintegrationism]])</div>
<div class="NavContent" align="left">
{\op}| class="inflection-table" style="background:#F6F6F6; text-align: left; border: 1px solid #999999;" cellpadding="3" cellspacing="0"
|-
! style="border: 1px solid #999999; background:#B0B0B0" rowspan="2" |
! style="border: 1px solid #999999; background:#D0D0D0" colspan="3" | Singular
! style="border: 1px solid #999999; background:#D0D0D0" colspan="3" | Plural
|-
! style="border: 1px solid #999999; background:#D0D0D0; width:12.5%" | First-person<br />(<<eu>>)
! style="border: 1px solid #999999; background:#D0D0D0; width:12.5%" | Second-person<br />(<<ti>> / <<tu>>)
! style="border: 1px solid #999999; background:#D0D0D0; width:12.5%" | Third-person<br />(<<ele>> / <<ela>> / <<você>>)
! style="border: 1px solid #999999; background:#D0D0D0; width:12.5%" | First-person<br />(<<nós>>)
! style="border: 1px solid #999999; background:#D0D0D0; width:12.5%" | Second-person<br />(<<vós>>)
! style="border: 1px solid #999999; background:#D0D0D0; width:12.5%" | Third-person<br />(<<eles>> / <<elas>> / <<vocês>>)
|-
! style="border: 1px solid #999999; background:#c498ff" colspan="7" | ''<span title="infinitivo">Infinitive</span>''
|-
! style="border: 1px solid #999999; background:#a478df" | '''<span title="infinitivo impessoal">Impersonal</span>'''
| style="border: 1px solid #999999; vertical-align: top;" colspan="6" | {infinitive}
|-
! style="border: 1px solid #999999; background:#a478df" | '''<span title="infinitivo flexionado">Personal</span>'''
| style="border: 1px solid #999999; vertical-align: top;" | {pers_inf_1s}
| style="border: 1px solid #999999; vertical-align: top;" | {pers_inf_2s}
| style="border: 1px solid #999999; vertical-align: top;" | {pers_inf_3s}
| style="border: 1px solid #999999; vertical-align: top;" | {pers_inf_1p}
| style="border: 1px solid #999999; vertical-align: top;" | {pers_inf_2p}
| style="border: 1px solid #999999; vertical-align: top;" | {pers_inf_3p}
|-
! style="border: 1px solid #999999; background:#98ffc4" colspan="7" | ''<span title="gerúndio">Gerund</span>''
|-
| style="border: 1px solid #999999; background:#78dfa4" |
| style="border: 1px solid #999999; vertical-align: top;" colspan="6" | {gerund}
|-{pp_clause}
! style="border: 1px solid #999999; background:#d0dff4" colspan="7" | ''<span title="indicativo">Indicative</span>''
|-
! style="border: 1px solid #999999; background:#b0bfd4" | <span title="presente">Present</span>
| style="border: 1px solid #999999; vertical-align: top;" | {pres_1s}
| style="border: 1px solid #999999; vertical-align: top;" | {pres_2s}
| style="border: 1px solid #999999; vertical-align: top;" | {pres_3s}
| style="border: 1px solid #999999; vertical-align: top;" | {pres_1p}
| style="border: 1px solid #999999; vertical-align: top;" | {pres_2p}
| style="border: 1px solid #999999; vertical-align: top;" | {pres_3p}
|-
! style="border: 1px solid #999999; background:#b0bfd4" | <span title="pretérito imperfeito">Imperfect</span>
| style="border: 1px solid #999999; vertical-align: top;" | {impf_1s}
| style="border: 1px solid #999999; vertical-align: top;" | {impf_2s}
| style="border: 1px solid #999999; vertical-align: top;" | {impf_3s}
| style="border: 1px solid #999999; vertical-align: top;" | {impf_1p}
| style="border: 1px solid #999999; vertical-align: top;" | {impf_2p}
| style="border: 1px solid #999999; vertical-align: top;" | {impf_3p}
|-
! style="border: 1px solid #999999; background:#b0bfd4" | <span title="pretérito perfeito">Preterite</span>
| style="border: 1px solid #999999; vertical-align: top;" | {pret_1s}
| style="border: 1px solid #999999; vertical-align: top;" | {pret_2s}
| style="border: 1px solid #999999; vertical-align: top;" | {pret_3s}
| style="border: 1px solid #999999; vertical-align: top;" | {pret_1p}
| style="border: 1px solid #999999; vertical-align: top;" | {pret_2p}
| style="border: 1px solid #999999; vertical-align: top;" | {pret_3p}
|-
! style="border: 1px solid #999999; background:#b0bfd4" | <span title="pretérito mais-que-perfeito simples">Pluperfect</span>
| style="border: 1px solid #999999; vertical-align: top;" | {plup_1s}
| style="border: 1px solid #999999; vertical-align: top;" | {plup_2s}
| style="border: 1px solid #999999; vertical-align: top;" | {plup_3s}
| style="border: 1px solid #999999; vertical-align: top;" | {plup_1p}
| style="border: 1px solid #999999; vertical-align: top;" | {plup_2p}
| style="border: 1px solid #999999; vertical-align: top;" | {plup_3p}
|-
! style="border: 1px solid #999999; background:#b0bfd4" | <span title="futuro do presente">Future</span>
| style="border: 1px solid #999999; vertical-align: top;" | {fut_1s}
| style="border: 1px solid #999999; vertical-align: top;" | {fut_2s}
| style="border: 1px solid #999999; vertical-align: top;" | {fut_3s}
| style="border: 1px solid #999999; vertical-align: top;" | {fut_1p}
| style="border: 1px solid #999999; vertical-align: top;" | {fut_2p}
| style="border: 1px solid #999999; vertical-align: top;" | {fut_3p}
|-
! style="border: 1px solid #999999; background:#b0bfd4" | <span title="condicional">Conditional</span>
| style="border: 1px solid #999999; vertical-align: top;" | {cond_1s}
| style="border: 1px solid #999999; vertical-align: top;" | {cond_2s}
| style="border: 1px solid #999999; vertical-align: top;" | {cond_3s}
| style="border: 1px solid #999999; vertical-align: top;" | {cond_1p}
| style="border: 1px solid #999999; vertical-align: top;" | {cond_2p}
| style="border: 1px solid #999999; vertical-align: top;" | {cond_3p}
|-
! style="border: 1px solid #999999; background:#d0f4d0" colspan="7" | ''<span title="conjuntivo">Subjunctive</span>''
|-
! style="border: 1px solid #999999; background:#b0d4b0" | <span title=" presente do conjuntivo">Present</span>
| style="border: 1px solid #999999; vertical-align: top;" | {pres_sub_1s}
| style="border: 1px solid #999999; vertical-align: top;" | {pres_sub_2s}
| style="border: 1px solid #999999; vertical-align: top;" | {pres_sub_3s}
| style="border: 1px solid #999999; vertical-align: top;" | {pres_sub_1p}
| style="border: 1px solid #999999; vertical-align: top;" | {pres_sub_2p}
| style="border: 1px solid #999999; vertical-align: top;" | {pres_sub_3p}
|-
! style="border: 1px solid #999999; background:#b0d4b0" | <span title="pretérito imperfeito do conjuntivo">Imperfect</span>
| style="border: 1px solid #999999; vertical-align: top;" | {impf_sub_1s}
| style="border: 1px solid #999999; vertical-align: top;" | {impf_sub_2s}
| style="border: 1px solid #999999; vertical-align: top;" | {impf_sub_3s}
| style="border: 1px solid #999999; vertical-align: top;" | {impf_sub_1p}
| style="border: 1px solid #999999; vertical-align: top;" | {impf_sub_2p}
| style="border: 1px solid #999999; vertical-align: top;" | {impf_sub_3p}
|-
! style="border: 1px solid #999999; background:#b0d4b0" | <span title="futuro do conjuntivo">Future</span>
| style="border: 1px solid #999999; vertical-align: top;" | {fut_sub_1s}
| style="border: 1px solid #999999; vertical-align: top;" | {fut_sub_2s}
| style="border: 1px solid #999999; vertical-align: top;" | {fut_sub_3s}
| style="border: 1px solid #999999; vertical-align: top;" | {fut_sub_1p}
| style="border: 1px solid #999999; vertical-align: top;" | {fut_sub_2p}
| style="border: 1px solid #999999; vertical-align: top;" | {fut_sub_3p}
|-
! style="border: 1px solid #999999; background:#f4e4d0" colspan="7" | ''<span title="imperativo">Imperative</span>''
|-
! style="border: 1px solid #999999; background:#d4c4b0" | <span title="imperativo afirmativo">Affirmative</span>
| style="border: 1px solid #999999; vertical-align: top;" rowspan="2" |
| style="border: 1px solid #999999; vertical-align: top;" | {imp_2s}
| style="border: 1px solid #999999; vertical-align: top;" | {imp_3s}
| style="border: 1px solid #999999; vertical-align: top;" | {imp_1p}
| style="border: 1px solid #999999; vertical-align: top;" | {imp_2p}
| style="border: 1px solid #999999; vertical-align: top;" | {imp_3p}
|-
! style="border: 1px solid #999999; background:#d4c4b0" | <span title="imperativo negativo">Negative</span> (<<nom>>)
| style="border: 1px solid #999999; vertical-align: top;" | {neg_imp_2s}
| style="border: 1px solid #999999; vertical-align: top;" | {neg_imp_3s}
| style="border: 1px solid #999999; vertical-align: top;" | {neg_imp_1p}
| style="border: 1px solid #999999; vertical-align: top;" | {neg_imp_2p}
| style="border: 1px solid #999999; vertical-align: top;" | {neg_imp_3p}
|{\cl}{notes_clause}</div></div>
]=]

local double_pp_template = [=[

! style="border: 1px solid #999999; background:#ffc498" colspan="7" | ''<span title="particípio irregular">Short past participle</span>''
|-
! style="border: 1px solid #999999; background:#dfa478" | Masculine
| style="border: 1px solid #999999; vertical-align: top;" colspan="3" | {short_pp_ms}
| style="border: 1px solid #999999; vertical-align: top;" colspan="3" | {short_pp_mp}
|-
! style="border: 1px solid #999999; background:#dfa478" | Feminine
| style="border: 1px solid #999999; vertical-align: top;" colspan="3" | {short_pp_fs}
| style="border: 1px solid #999999; vertical-align: top;" colspan="3" | {short_pp_fp}
|-
! style="border: 1px solid #999999; background:#ffc498" colspan="7" | ''<span title="particípio regular">Long past participle</span>''
|-
! style="border: 1px solid #999999; background:#dfa478" | Masculine
| style="border: 1px solid #999999; vertical-align: top;" colspan="3" | {pp_ms}
| style="border: 1px solid #999999; vertical-align: top;" colspan="3" | {pp_mp}
|-
! style="border: 1px solid #999999; background:#dfa478" | Feminine
| style="border: 1px solid #999999; vertical-align: top;" colspan="3" | {pp_fs}
| style="border: 1px solid #999999; vertical-align: top;" colspan="3" | {pp_fp}
|-]=]

local single_pp_template = [=[

! style="border: 1px solid #999999; background:#ffc498" colspan="7" | ''<span title="particípio passado">Past participle</span>''
|-
! style="border: 1px solid #999999; background:#dfa478" | Masculine
| style="border: 1px solid #999999; vertical-align: top;" colspan="3" | {pp_ms}
| style="border: 1px solid #999999; vertical-align: top;" colspan="3" | {pp_mp}
|-
! style="border: 1px solid #999999; background:#dfa478" | Feminine
| style="border: 1px solid #999999; vertical-align: top;" colspan="3" | {pp_fs}
| style="border: 1px solid #999999; vertical-align: top;" colspan="3" | {pp_fp}
|-]=]

local function make_table(alternant_multiword_spec)
	local forms = alternant_multiword_spec.forms

	forms.title = link_term(alternant_multiword_spec.lemmas[1].form)
	if alternant_multiword_spec.annotation ~= "" then
		forms.title = forms.title .. " (" .. alternant_multiword_spec.annotation .. ")"
	end
	forms.description = ""

	-- Format the table.
	forms.footnote = alternant_multiword_spec.footnote_basic
	forms.notes_clause = forms.footnote ~= "" and m_string_utilities.format(notes_template, forms) or ""
	-- has_short_pp is computed in show_forms().
	local pp_template = alternant_multiword_spec.has_short_pp and double_pp_template or single_pp_template
	forms.pp_clause = m_string_utilities.format(pp_template, forms)
	local table_with_pronouns = rsub(basic_table, "<<(.-)>>", link_term)
	return m_string_utilities.format(table_with_pronouns, forms)
end


-- Externally callable function to parse and conjugate a verb given user-specified arguments.
-- Return value is WORD_SPEC, an object where the conjugated forms are in `WORD_SPEC.forms`
-- for each slot. If there are no values for a slot, the slot key will be missing. The value
-- for a given slot is a list of objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms(args, source_template, headword_head)
	local PAGENAME = mw.title.getCurrentTitle().text
	local function in_template_space()
		return mw.title.getCurrentTitle().nsText == "Template"
	end

	-- Determine the verb spec we're being asked to generate the conjugation of. This may be taken from the
	-- current page title or the value of |pagename=; but not when called from {{gl-reinteg-verb form of}}, where the
	-- page title is a non-lemma form. Note that the verb spec may omit the infinitive; e.g. it may be "<i-e>".
	-- For this reason, we use the value of `pagename` computed here down below, when calling normalize_all_lemmas().
	local pagename = source_template ~= "gl-reinteg-verb form of" and args.pagename or PAGENAME
	local head = headword_head or pagename
	local arg1 = args[1]

	if not arg1 then
		if (pagename == "gl-reinteg-conj" or pagename == "gl-reinteg-verb") and in_template_space() then
			arg1 = "traguer"
		elseif pagename == "gl-reinteg-verb form of" and in_template_space() then
			arg1 = "amar"
		else
			arg1 = "<>"
		end
	end

	-- When called from {{gl-reinteg-verb form of}}, determine the non-lemma form whose inflections we're being asked to
	-- determine. This normally comes from the page title or the value of |pagename=.
	local verb_form_of_form
	if source_template == "gl-reinteg-verb form of" then
		verb_form_of_form = args.pagename
		if not verb_form_of_form then
			if PAGENAME == "gl-reinteg-verb form of" and in_template_space() then
				verb_form_of_form = "ame"
			else
				verb_form_of_form = PAGENAME
			end
		end
	end

	local incorporated_headword_head_into_lemma = false
	if arg1:find("^<.*>$") then -- missing lemma
		if head:find(" ") then
			-- If multiword lemma, try to add arg spec after the first word.
			-- Try to preserve the brackets in the part after the verb, but don't do it
			-- if there aren't the same number of left and right brackets in the verb
			-- (which means the verb was linked as part of a larger expression).
			local refl_clitic_verb, post = rmatch(head, "^(.-)( .*)$")
			local left_brackets = rsub(refl_clitic_verb, "[^%[]", "")
			local right_brackets = rsub(refl_clitic_verb, "[^%]]", "")
			if #left_brackets == #right_brackets then
				arg1 = iut.remove_redundant_links(refl_clitic_verb) .. arg1 .. post
				incorporated_headword_head_into_lemma = true
			else
				-- Try again using the form without links.
				local linkless_head = m_links.remove_links(head)
				if linkless_head:find(" ") then
					refl_clitic_verb, post = rmatch(linkless_head, "^(.-)( .*)$")
					arg1 = refl_clitic_verb .. arg1 .. post
				else
					error("Unable to incorporate <...> spec into explicit head due to a multiword linked verb or " ..
						"unbalanced brackets; please include <> explicitly: " .. arg1)
				end
			end
		else
			-- Will be incorporated through `head` below in the call to normalize_all_lemmas().
			incorporated_headword_head_into_lemma = true
		end
	end

	local function split_bracketed_runs_into_words(bracketed_runs)
		return iut.split_alternating_runs(bracketed_runs, " ", "preserve splitchar")
	end

	local parse_props = {
		parse_indicator_spec = parse_indicator_spec,
		-- Split words only on spaces, not on hyphens, because that messes up reflexive verb parsing.
		split_bracketed_runs_into_words = split_bracketed_runs_into_words,
		allow_default_indicator = true,
		allow_blank_lemma = true,
	}
	local alternant_multiword_spec = iut.parse_inflected_text(arg1, parse_props)
	alternant_multiword_spec.pos = pos or "verbs"
	alternant_multiword_spec.args = args
	alternant_multiword_spec.source_template = source_template
	alternant_multiword_spec.verb_form_of_form = verb_form_of_form
	alternant_multiword_spec.incorporated_headword_head_into_lemma = incorporated_headword_head_into_lemma

	normalize_all_lemmas(alternant_multiword_spec, head)
	detect_all_indicator_specs(alternant_multiword_spec)
	local inflect_props = {
		slot_list = alternant_multiword_spec.all_verb_slots,
		inflect_word_spec = conjugate_verb,
		get_variants = function(form) return rsub(form, not_var_code_c, "") end,
		-- We add links around the generated verbal forms rather than allow the entire multiword
		-- expression to be a link, so ensure that user-specified links get included as well.
		include_user_specified_links = true,
	}
	iut.inflect_multiword_or_alternant_multiword_spec(alternant_multiword_spec, inflect_props)

	-- Remove redundant brackets around entire forms.
	for slot, forms in pairs(alternant_multiword_spec.forms) do
		for _, form in ipairs(forms) do
			form.form = iut.remove_redundant_links(form.form)
		end
	end

	compute_categories_and_annotation(alternant_multiword_spec)
	if args.json and source_template == "gl-reinteg-conj" then
		return export.remove_variant_codes(require("Module:JSON").toJSON(alternant_multiword_spec.forms))
	end
	return alternant_multiword_spec
end


-- Entry point for {{gl-reinteg-conj}}. Template-callable function to parse and conjugate a verb given
-- user-specified arguments and generate a displayable table of the conjugated forms.
function export.show(frame)
	local parent_args = frame:getParent().args
	local params = {
		[1] = {},
		["noautolinktext"] = {type = "boolean"},
		["noautolinkverb"] = {type = "boolean"},
		["pagename"] = {}, -- for testing/documentation pages
		["json"] = {type = "boolean"}, -- for bot use
	}
	local args = require("Module:parameters").process(parent_args, params)
	local alternant_multiword_spec = export.do_generate_forms(parent_args, "gl-reinteg-conj")
	if type(alternant_multiword_spec) == "string" then
		-- JSON return value
		return alternant_multiword_spec
	end
	show_forms(alternant_multiword_spec)
	return make_table(alternant_multiword_spec) ..
		require("Module:utilities").format_categories(alternant_multiword_spec.categories, lang, nil, nil, force_cat)
end


return export
