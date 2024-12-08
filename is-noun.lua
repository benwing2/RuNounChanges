local export = {}


--[=[

Authorship: Ben Wing <benwing2>

]=]

--[=[

TERMINOLOGY:

-- "slot" = A particular combination of case/number. Example slot names for nouns are "acc_s" (accusative singular) and
	 "gen_p" (genitive plural). Each slot is filled with zero or more forms.

-- "form" = The declined Icelandic form representing the value of a given slot.

-- "lemma" = The dictionary form of a given Icelandic term. Generally the nominative singular, or nominative plural of
	 plural-only nouns, but may occasionally be another form if the nominative is missing.
]=]


--[=[

FIXME:

1. Support 'plstem' overrides. [DONE]
2. Support definite lemmas such as [[Bandaríkin]] "the United States". [DONE]
3. Support adjectivally-declined terms. [DONE PARTIALLY]
4. Support @ for built-in irregular lemmas. [DONE; SINCE REPLACED WITH SCRAPING SPECS]
5. Somehow if the user specifies v-infix, it should prevent default unumut from happening in strong feminines. [DONE]
6. Def acc pl should ignore -u ending in indef acc pl. [DONE]
7. Footnotes on omitted forms should be possible.
8. Remove setting of override on pl when processing plural-only terms in synthesize_singular_lemma(); interferes
   with decllemma in [[dyr]]. But then need to fix handling of masculine accusative plural. [DONE]
9. Rationalize conventions used in u-mutation types. [DONE]
10. Compute defaulted number and definiteness early so it's usable when merging built-in and user-specified
	specs. [DONE]
11. Support multiple declension specs. [DONE]
12. Support dark mode. [DONE]
13. Support scraping declension specs. [DONE]
14. Support @-d etc. for suffix scraping. [DONE]
15. Include scraped base nouns in title annotation. [DONE]
16. Support @@ for self-scraping. [DONE IN [[Module:gmq-headword]]]
17. Support scraping multiple declension specs; e.g. [[fræði]] is declared with 'n.pl|f.sg' and [[hljómfræði]]
    would like to use '@f' but you get an error.
]=]

local lang = require("Module:languages").getByCode("is")
local m_table = require("Module:table")
local m_links = require("Module:links")
local m_string_utilities = require("Module:string utilities")
local iut = require("Module:inflection utilities")
local m_para = require("Module:parameters")
local com = require("Module:is-common")
local pages_module = "Module:pages"
local template_parser_module = "Module:template parser"

local u = mw.ustring.char
local rsplit = mw.text.split
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rgmatch = mw.ustring.gmatch
local rsubn = mw.ustring.gsub
local ulen = mw.ustring.len
local usub = mw.ustring.sub
local uupper = mw.ustring.upper
local ulower = mw.ustring.lower
local dump = mw.dumpObject

local force_cat = false -- set to true to make categories appear in non-mainspace pages, for testing

local SUB_ESCAPED_PERIOD = u(0xFFF0)
local SUB_ESCAPED_COMMA = u(0xFFF1)

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end


-- version of rsubn() that returns a 2nd argument boolean indicating whether
-- a substitution was made.
local function rsubb(term, foo, bar)
	local retval, nsubs = rsubn(term, foo, bar)
	return retval, nsubs > 0
end


local function track(track_id)
	require("Module:debug/track")("is-noun/" .. track_id)
	return true
end


local potential_lemma_slots = {
	"ind_nom_s",
	"ind_nom_p",
	"def_nom_s",
	"def_nom_p",
	"ind_acc_s", -- for [[sig]]
}

local cases = {
	"nom",
	"acc",
	"dat",
	"gen",
}

local case_set = m_table.listToSet(cases)

local overridable_stems = {
	"stem",
	"vstem",
	"plstem",
	"plvstem",
	"imutval",
}

local overridable_stem_set = m_table.listToSet(overridable_stems)

local mutation_specs = {
	"umut",
	"imut",
	"unumut",
	"unimut",
	"con",
	"defcon",
	"j",
	"v",
}

local mutation_spec_set = m_table.listToSet(mutation_specs)

local clitic_articles = {
	m = {
		nom_s = "inn",
		acc_s = "inn",
		dat_s = "num",
		gen_s = "ins",
		nom_p = "nir",
		acc_p = "na",
		dat_p = "num",
		gen_p = "nna",
	},
	f = {
		nom_s = "in",
		acc_s = "ina",
		dat_s = "inni",
		gen_s = "innar",
		nom_p = "nar",
		acc_p = "nar",
		dat_p = "num",
		gen_p = "nna",
	},
	n = {
		nom_s = "ið",
		acc_s = "ið",
		dat_s = "nu",
		gen_s = "ins",
		nom_p = "in",
		acc_p = "in",
		dat_p = "num",
		gen_p = "nna",
	},
}

local gender_code_to_desc = {
	m = "masculine",
	f = "feminine",
	n = "neuter",
	none = nil,
}

local number_code_to_desc = {
	sg = "singular",
	pl = "plural",
	both = "both numbers",
	none = nil,
}

local definiteness_code_to_desc = {
	indef = "indefinite-only",
	def = "definite-only",
	bothdef = "indefinite and definite",
	none = nil,
}

-- Parse off and return a final -ur or -r nominative ending. Return the portion before the ending as well as the ending
-- itself. If the lemma ends in -aur, only the -r is stripped off. This is used by ## and by the `@l` scraping
-- indicator (so that e.g. `@r` when applied to a compound of [[réttur]] "law; court; course (of a meal)" won't get
-- confused by the final -r).
local function parse_off_final_nom_ending(lemma)
	local lemma_minus_r, final_nom_ending
	if lemma:find("[^Aa]ur$") then
		lemma_minus_r, final_nom_ending = lemma:match("^(.*)(ur)$")
	elseif lemma:find("r$") then
		lemma_minus_r, final_nom_ending = lemma:match("^(.*)(r)$")
	else
		lemma_minus_r, final_nom_ending = lemma, ""
	end
	return lemma_minus_r, final_nom_ending
end

local function get_noun_slots(alternant_multiword_spec)
	local noun_slots_list = {}
	for _, case in ipairs(cases) do
		for _, num in ipairs {"s", "p"} do
			for _, def in ipairs {"ind", "def"} do
				local slot = ("%s_%s_%s"):format(def, case, num)
				local accel = ("%s|%s"):format(def, case)
				if alternant_multiword_spec.actual_number == "both" then
					accel = accel .. "|" .. num
				end
				table.insert(noun_slots_list, {slot, accel})
			end
		end
	end
	for _, potential_lemma_slot in ipairs(potential_lemma_slots) do
		table.insert(noun_slots_list, {potential_lemma_slot .. "_linked", "-"})
	end
	return noun_slots_list
end


local function generate_list_of_possibilities_for_err(list)
	local quoted_list = {}
	for _, item in pairs(list) do
		if item == "" then
			item = "<nowiki />"
		end
		table.insert(quoted_list, "'" .. item .. "'")
	end
	table.sort(quoted_list)
	return mw.text.listToText(quoted_list)
end


local function skip_slot(number, definiteness, slot)
	return number == "sg" and rfind(slot, "_p$") or
		number == "pl" and rfind(slot, "_s$") or
		definiteness == "def" and rfind(slot, "^ind_") or
		(definiteness == "indef" or definiteness == "none") and rfind(slot, "^def_")
end

-- Return true if `stem` refers to a proper noun (first character is uppercase, second character is lowercase).
local function is_proper_noun(base, stem)
	if base.props.common or base.props.dem then
		return false
	end
	if base.props.proper then
		return true
	end
	if base.source_template == "is-noun" then
		return false
	end
	if base.source_template == "is-proper noun" then
		return true
	end
	local first_letter = usub(stem, 1, 1)
	local second_letter = usub(stem, 2, 2)
	return ulower(first_letter) ~= first_letter and ((not second_letter or second_letter == "") or
		uupper(second_letter) ~= second_letter)
end

-- Basic function to combine stem(s) and other properties with ending(s) and insert the result into the appropriate
-- slot. `base` is the object describing all the properties of the word being inflected for a single alternant (in case
-- there are multiple alternants specified using `((...))`). `slot_prefix` is either "ind_" or "def_" and is prefixed to
-- the slot value in `slot` to get the actual slot to add the resulting forms to. (`slot_prefix` is separated out
-- because the code below frequently needs to conditionalize on the value of `slot` and should not have to worry about
-- the definite and indefinite slot variants). `props` is an object containing computed stems and other information
-- (such as whether i-mutation is active). The information found in `props` cannot be stored in `base` because there may
-- be more than one set of such properties per `base` (e.g. if the user specified 'umut,uUmut' or '-j,j' or '-imut,imut'
-- or some combination of these; in such a case, the caller will iterate over all possible combinations, and ultimately
-- invoke add() multiple times, one per combination). `endings` is the ending or endings added to the appropriate stem
-- (after any j or v infix) to get the form(s) to add to the slot. Its value can be a single string, a list of strings,
-- or a list of form objects (i.e. in general list form). `clitics` is the clitic or clitics to add after the endings to
-- form the actual form value inserted into definite slots; it should be nil for indefinite slots. Its format is the
-- same as for `endings`. `ending_override`, if true, indicates that the ending(s) supplied in `endings` come from a
-- user-specified override, and hence j and v infixes should not be added as they are already included in the override
-- if needed. `endings_are_full`, if true, indicates that the supplied ending(s) are actually full words and a null stem
-- should be used.
--
-- The properties in `props` are:
-- * Stems (each stem is either a string or a form object, i.e. an object with `form` and `footnotes` properties; see
--   [[Module:inflection utilities]]; stems in general may be missing, i.e. nil, unless otherwise specified, and default
--   to more general variants):
-- ** `stem`: The basic stem. Always set. May be overridden by more specific variants.
-- ** `nonvstem`: The stem used when the ending is null or starts with a consonant, unless overridden by a more
--    specific variant. Defaults to `stem`. Not currently used, but could be if e.g. a user stem override `nonvstem:...`
--    were supported.
-- ** `umut_nonvstem`: The stem used when the ending is null or starts with a consonant and u-mutation is in effect,
--    unless overridden by a more specific variant. Defaults to `nonvstem`. Will only be present when the result of
--    u-mutation is different from the stem to which u-mutation is applied. (In this case, it will be present even if
--    `nonvstem` is missing, because there is no generic `umut_stem`.)
-- ** `imut_nonvstem`: The stem used when the ending is null or starts with a consonant and i-mutation is in effect.
--    If i-mutation is in effect, this should always be specified (otherwise an internal error will occur); hence it has
--    no default. Note that i-mutation is only in effect when either (a) `imut` or `unimut` was specified; (b) a
--    user-specified override is given that begins with a single ^ (indicating i-mutation); or (c) a declension type is
--    in effect that contains default endings beginning with a single ^ (examples are `f-long-vowel` for lemmas in -ó
--    and `f-long-umlaut-vowel-r`). Note also that this will be present even if `nonvstem` is missing, because there is
--    no generic `imut_stem`.
-- ** `vstem`: The stem used when the ending starts with a vowel, unless overridden by a more specific variant. Defaults
--    to `stem`. Will be specified when contraction is in effect or the user specified `vstem:...`.
-- ** `umut_vstem`: The stem(s) used when the ending starts with a vowel and u-mutation is in effect. Defaults to
--    `vstem`. Note that u-mutation applies to the contracted stem if both u-mutation and contraction are in effect.
--    Will only be present when the result of u-mutation is different from the stem to which u-mutation is applied.
--    (In this case, it will be present even if `vstem` is missing, because there is no generic `umut_stem`.)
-- ** `imut_vstem`: The stem(s) used when the ending starts with a vowel and i-mutation is in effect. If i-mutation is
--    in effect, this should always be specified (otherwise an internal error will occur); hence it has no default. Note
--    that i-mutation applies to the contracted stem if both i-mutation and contraction are in effect. See
--    `imut_nonvstem` for comments on when this stem will be present.
-- ** `null_defvstem`: The stem(s) used when the ending is null and is followed by a definite ending that begins with a
--    vowel, unless overridden by a more specific variant. Defaults to `nonvstem`. This is normally set when `defcon`
--    is specified.
-- ** `umut_null_defvstem`: The stem(s) used when the ending is null and is followed by a definite ending that begins
--    with a vowel, and u-mutation is in effect. Defaults to `null_defvstem`. This is normally set when `defcon` is
--    specified and u-mutation is needed, as in the nom/acc pl of neuter [[mastur]] "mast". Will only be present when
--    the result of u-mutation is different from the stem to which u-mutation is applied.
-- ** `pl_stem`: The basic stem used for plural inflections. Only set when `plstem:...` is specified by the user. If
--    this is set, the alternative plural-specific stem variants are used, where each of the above stems has a
--    plural-specific counterpart, and the identical algorithms and fallbacks are used to determine the correct stem.
-- ** `pl_nonvstem`, `pl_umut_nonvstem`, `pl_imut_nonvstem`, `pl_vstem`, `pl_umut_vstem`, `pl_imut_vstem`, 
--    `pl_null_defvstem`, `pl_umut_null_defvstem`: Plural-specific counterparts of the above stems. See the comment
--    under `pl_stem` for when these are used.
-- * Other properties:
-- ** `jinfix`: If present, either "" or "j". Inserted between the stem and ending when the ending begins with a vowel
--    other than "i". Note that j-infixes don't apply to ending overrides.
-- ** `jinfix_footnotes`: Footnotes to attach to forms where j-infixing is possible (even if it's not present).
-- ** `vinfix`: If present, either "" or "v". Inserted between the stem and ending when the ending begins with a vowel.
--    Note that v-infixes don't apply to ending overrides. `jinfix` and `vinfix` cannot both be specified.
-- ** `vinfix_footnotes`: Footnotes to attach to forms where v-infixing is possible (even if it's not present).
-- ** `imut`: If specified (i.e. not nil), either true or false. If specified, there may be associated footnotes in
--    `imut_footnotes`. If true, i-mutation and associated footnotes are in effect before endings starting with "i". If
--    false, associated footnotes still apply before endings starting with "i". Note that i-mutation is also in effect
--    if the ending has ^ prepended, but the associated footnotes don't apply here.
-- ** `imut_footnotes`: See `imut`.
-- ** `unumut`: If specified (i.e. not nil), the type of un-u-mutation requested (either "unumut" or a variant, or the
--    negation of the same using "-unumut" or a variant for no un-u-mutation; "unumut" and variants differ in which
--    slots any associated footnote are placed). If specified, there may be associated footnotes in `unumut_footnotes`.
--    If "unumut" itself, u-mutation is in effect *except* before an ending that starts with an "a" or "i" (unless
--    i-mutation is in effect, which takes precedence). If any other variant, the rules are different: when masculine,
--    u-mutation is in effect *except* in the gen sg and pl (examples are [[söfnuður]] "congregation" and [[mánuður]]
--    "month"); when feminine, u-mutation is in effect except in the nom/acc/gen pl (examples are [[verslun]] "trade,
--    business; store, shop" and [[kvörtun]] "complaint"). When u-mutation is *not* in effect, and i-mutation is also
--    not in effect, the associated footnotes in `unumut_footnotes` apply. If `unumut` is "-unumut" or a variant, there
--    is no un-u-mutation (i.e. there are no special u-mutated stems, and the basic stems, which typically have
--    u-mutation built into them, apply throughout), but the associated footnotes in `unumut_footnotes` still apply in
--    the same circumstances where they would apply if `unumut` were the non-negated counterpart.
-- ** `unumut_footnotes`: See `unumut`.
-- ** `unimut`: If specified (i.e. not nil), either true or false. If specified, there may be associated footnotes in
--    `unimut_footnotes`. If true, i-mutation is in effect *except* in certain case/num combinations that depend on the
--    gender. Specifically: (1) for masculine nouns e.g. [[ketill]] "kettle" and proper names [[Egill]] and [[Ketill]],
--    i-mutation does not apply in the dat sg and throughout the plural; (2) for feminine nouns e.g. [[kýr]] "cow",
--    [[sýr]] "sow (archaic)" and [[ær]] "ewe", i-mutation does not apply in the acc and dat sg and in the dat and gen
--    pl. Cf. also feminine pl-only [[hættur]] "bedtime, quitting time" and [[mætur]] "appreciation, liking", which use
--    'unimut' to get e.g. dat pl [[háttum]] and gen pl [[hátta]]; but these are handled by synthesizing a singular
--    without i-mutation in the lemma. Very similar are neuter pl [[læti]] "behavior, demeanor" and [[ólæti]] "noise,
--    racket", with e.g. dat pl [[látum]] and gen pl [[láta]], which are handled in the same way. When i-mutation is
--    *not* in effect, the associated footnotes in `unimut_footnotes` apply. If false, the associated footnotes in
--    `unimut_footnotes` still apply in the same circumstances where they would apply if `unimut` where true.
-- ** `unimut_footnotes`: See `unimut`.
local function add_slotval(base, slot_prefix, slot, props, endings, clitics, ending_override, endings_are_full)
	if not endings then
		return
	end
	-- Call skip_slot() based on the declined number and definiteness; if the actual number is different, we correct
	-- this in decline_noun() at the end.
	if skip_slot(base.number, base.definiteness, slot) then
		return
	end
	if not clitics then
		clitics = {""}
	elseif type(clitics) == "string" then
		clitics = {clitics}
	end
	if type(endings) == "string" then
		endings = {endings}
	end
	-- Loop over each ending and clitic.
	for _, endingobj in ipairs(endings) do
		for _, cliticobj in ipairs(clitics) do
			-- Do the following inside of the innermost loop even though it does not depend on the value of `cliticobj`,
			-- because that way we are free to mutate `ending` below.
			local ending, ending_footnotes
			if type(endingobj) == "string" then
				ending = endingobj
			else
				ending = endingobj.form
				ending_footnotes = endingobj.footnotes
			end
			-- Ending of "-" means the user used -- to indicate there should be no form here.
			if ending == "-" then
				return
			end
			local function interr(msg)
				error(("Internal error: For lemma '%s', slot '%s%s', ending '%s', %s: %s"):format(base.lemma, slot_prefix,
					slot, ending, msg, dump(props)))
			end

			local clitic, clitic_footnotes
			if type(cliticobj) == "string" then
				clitic = cliticobj
			else
				clitic = cliticobj.form
				clitic_footnotes = cliticobj.footnotes
			end

			-- Compute whether i-mutation or u-mutation is in effect, and compute the "mutation footnotes", which are
			-- footnotes attached to a mutation-related indicator and which may need to be added even if no mutation is
			-- in effect (specifically when dealing with an ending that would trigger a mutation if in effect). AFAIK
			-- you cannot have both mutations in effect at once, and i-mutation overrides u-mutation if both would be in
			-- effect.

			-- Single ^ at the beginning of an ending indicates that the i-mutated version of the stem should apply, and
			-- double ^^ at the beginning indicates that the u-mutated version should apply.
			local explicit_imut, explicit_umut
			-- % at the end of a definite ending indicates that the following i- of the clitic should drop, as with
			-- neuter [[tré]], [[kné]], [[fé]]. There's no counterpart to force irregular inclusion of an i- that would
			-- normally drop; just include it in the ending (as with acc/dat sg of [[eygló]] "eyeball???" and [[sígó]]
			-- "cig").
			local clitic_i_drops
			ending, explicit_umut = rsubb(ending, "^%^%^", "")
			if not explicit_umut then
				ending, explicit_imut = rsubb(ending, "^%^", "")
			end
			ending, clitic_i_drops = rsubb(ending, "%%$", "")
			local is_vowel_ending = rfind(ending, "^" .. com.vowel_c)
			local is_vowel_clitic = rfind(clitic, "^" .. com.vowel_c)
			local mut_in_effect, mut_not_in_effect, mut_footnotes
			local ending_in_a = not not ending:find("^a")
			local ending_in_i = not not ending:find("^i")
			local ending_in_u = not not ending:find("^u")
			if props.unimut ~= nil and props.unumut ~= nil then
				interr("Cannot have both 'unimut' and 'unumut' in effect at the same time")
			end
			if props.unimut ~= nil and props.imut ~= nil then
				interr("Cannot have both 'unimut' and 'imut' in effect at the same time")
			end
			if props.unumut ~= nil and props.umut ~= nil then
				interr("Cannot have both 'unumut' and 'umut' in effect at the same time")
			end
			if explicit_imut then
				mut_in_effect = "i"
			elseif explicit_umut then
				mut_in_effect = "u"
			else
				if props.unimut ~= nil then
					local is_unimut_slot
					if base.gender == "m" then
						is_unimut_slot = slot == "dat_s" or slot:find("_p")
					elseif base.gender == "f" then
						is_unimut_slot = slot == "acc_s" or slot == "dat_s" or slot == "dat_p" or
							slot == "gen_p"
					else
						interr("'unimut' shouldn't be specified with neuter nouns; don't know what slots would be affected; neuter pluralia tantum nouns using 'unimut' should have synthesized a singular without i-mutation")
					end
					if is_unimut_slot then
						mut_not_in_effect = "i"
						mut_footnotes = props.unimut_footnotes
					elseif props.unimut then
						mut_in_effect = "i"
					end
				elseif props.imut ~= nil then
					if ending_in_i then
						if props.imut then
							mut_in_effect = "i"
							mut_footnotes = props.imut_footnotes
						elseif props.imut == false then
							mut_not_in_effect = "i"
							mut_footnotes = props.imut_footnotes
						end
					end
				end
				if props.unumut ~= nil then
					local is_unumut_slot
					if props.unumut == "unumut" or props.unumut == "-unumut" then
						is_unumut_slot = ending_in_a or ending_in_i
					elseif base.gender == "m" then
						is_unumut_slot = slot == "gen_s" or slot == "gen_p"
					elseif base.gender == "f" then
						is_unumut_slot = slot == "nom_p" or slot == "acc_p" or slot == "gen_p"
					else
						interr("'unumut' and variants shouldn't be specified with neuter nouns; don't know what slots would be affected; neuter pluralia tantum nouns using 'unumut'and variants should have synthesized a singular without u-mutation")
					end
					if not mut_in_effect and not mut_not_in_effect then
						-- Do nothing if mut_in_effect or mut_not_in_effect because i-mut takes precedence over u-mut;
						-- FIXME: I hope this is correct in all cases.
						if is_unumut_slot then
							mut_not_in_effect = "u"
							mut_footnotes = props.unumut_footnotes
						elseif props.unumut then
							mut_in_effect = "u"
						end
					end
				end
				if ending_in_u and not mut_in_effect then
					mut_in_effect = "u"
					-- umut and uUmut footnotes are incorporated into the appropriate umut_* stems
				end
			end

			local ending_was_asterisk = ending == "*"

			-- Now compute the appropriate stem to which the ending and clitic are added. `prefix` is either an empty
			-- string or "pl_" and selects the set of stems to consider when computing the stem in effect. See the
			-- comment above for `pl_stem`.
			local function compute_stem_in_effect(prefix)
				local stem_in_effect

				if mut_in_effect == "i" then
					-- NOTE: It appears that imut and defcon never co-occur; otherwise we'd need to flesh out the set of
					-- stems to include i-mutation versions of defcon stems, similar to what we do for u-mutation.
					if is_vowel_ending then
						if not props[prefix .. "imut_vstem"] then
							interr(("i-mutation in effect and ending begins with a vowel but '.%simut_vstem' not defined"):
								format(prefix))
						end
						stem_in_effect = props[prefix .. "imut_vstem"]
					else
						if not props[prefix .. "imut_nonvstem"] then
							interr(("i-mutation in effect and ending does not begin with a vowel but '.%simut_nonvstem' not defined"):
								format(prefix))
						end
						stem_in_effect = props[prefix .. "imut_nonvstem"]
					end
				else
					-- Careful with the following logic; it is written carefully and should not be changed without a
					-- thorough understanding of its functioning.
					local has_umut = mut_in_effect == "u"
					-- First, if the ending is null (or "*", which eventually turns into a null ending; see below), and
					-- we have a vowel-initial definite-article clitic, use the special 'defcon' stem if available.
					if (ending == "" or ending == "*") and is_vowel_clitic then
						stem_in_effect = has_umut and props[prefix .. "umut_null_defvstem"] or
							props[prefix .. "null_defvstem"]
					end
					-- If the stem is still unset, then use the vowel or non-vowel stem if available. When u-mutation is
					-- active, we first check for the u-mutated version of the vowel or non-vowel stem before falling
					-- back to the regular vowel or non-vowel stem. Note that an expression like `has_umut and
					-- props[prefix .. "umut_vstem"] or props[prefix .. "vstem"]` here is NOT equivalent to an if-else
					-- or ternary operator expression because if `has_umut` is true and `umut_vstem` is missing, it will
					-- still fall back to `vstem` (which is what we want).
					if not stem_in_effect then
						if is_vowel_ending then
							stem_in_effect = has_umut and props[prefix .. "umut_vstem"] or props[prefix .. "vstem"]
						else
							stem_in_effect = has_umut and props[prefix .. "umut_nonvstem"] or
								props[prefix .. "nonvstem"]
						end
					end
					-- Finally, fall back to the basic stem, which is always defined.
					stem_in_effect = stem_in_effect or props[prefix .. "stem"]
				end
				
				-- If the ending is "*", it means to use the lemma as the form directly (before adding any definite
				-- clitic) rather than try to construct the form from a stem and ending. We need to do this for the
				-- lemma slot and especially for the nominative singular, because we don't have the nominative singular
				-- ending available and it may vary (e.g. it may be -ur, -l, -n, -a, etc. especially in the masculine).
				-- Not trying to construct the form from stem + ending also avoids complications from the nominative
				-- singular in -ur, which exceptionally does not trigger u-mutation. However, when 'defcon' is active
				-- and we're processing a definite form beginning with a vowel (i.e.  is_vowel_clitic is set), we can't
				-- do this, because the form to which the clitic is added is not the lemma but the contracted version.
				-- As it happens, this works out because in all situations where 'defcon' is active, the nominative
				-- singular has a null ending. (If this weren't the case, we'd have to change all the declension
				-- functions to pass in the nominative singular ending in addition to other endings.) An example where
				-- 'defcon' is active is neuter [[mastur]] "mast" with definite nominative singular [[mastrið]]; here,
				-- using the lemma would incorrectly produce #[[masturið]].

				-- Finally, however, if there is a footnote associated with the computed stem in effect, we need to
				-- preserve it.
				if ending == "*" then
					if not is_vowel_clitic or not props.defcon or props.defcon.form ~= "defcon" then
						local stem_in_effect_footnotes
						if type(stem_in_effect) == "table" then
							stem_in_effect_footnotes = stem_in_effect.footnotes
						end
						stem_in_effect = iut.combine_form_and_footnotes(base.actual_lemma, stem_in_effect_footnotes)
					end
					-- See comment above. When 'defcon' is not in effect, we changed the stem to be the lemma and
					-- want to use a null ending; otherwise, the ending is always null anyway, so it's safe to set
					-- it thus.
					ending = ""
				end

				return stem_in_effect
			end

			local stem_in_effect = props.pl_stem and slot:find("_p$") and compute_stem_in_effect("pl_") or
				compute_stem_in_effect("")

			local infix, infix_footnotes
			-- Compute the infix (j, v or nothing) that goes between the stem and ending.
			if not ending_override and is_vowel_ending then
				if props.vinfix and props.jinfix then
					interr("Can't have specifications for both '.vinfix' and '.jinfix'; should have been caught above")
				end
				if props.vinfix then
					infix = props.vinfix
					infix_footnotes = props.vinfix_footnotes
				elseif props.jinfix and not ending_in_i then
					infix = props.jinfix
					infix_footnotes = props.jinfix_footnotes
				end
			end

			-- If base-level footnotes specified, they go before any stem footnotes, so we need to extract any footnotes
			-- from the stem in effect and insert the base-level footnotes before. In general, we want the footnotes to
			-- be in the order [base.footnotes, stem.footnotes, mut_footnotes, infix_footnotes, ending.footnotes,
			-- clitic.footnotes].
			if base.footnotes then
				local stem_in_effect_footnotes
				if type(stem_in_effect) == "table" then
					stem_in_effect_footnotes = stem_in_effect.footnotes
					stem_in_effect = stem_in_effect.form
				end
				stem_in_effect = iut.combine_form_and_footnotes(stem_in_effect,
					iut.combine_footnotes(base.footnotes, stem_in_effect_footnotes))
			end

			local ending_is_full
			ending, ending_is_full = rsubb(ending, "^!", "")

			local function combine_stem_ending(stem, clitic)
				if stem == "?" then
					return "?"
				end
				local function drop_clitic_i()
					clitic = clitic:gsub("^i", "")
				end
				-- If we're definite-only and using the actual lemma as the stem, the clitic is already incorporated
				-- into the stem.
				if base.definiteness == "def" and ending_was_asterisk then
					return stem
				end
				-- % at the end of a definite ending indicates that the following i- of the clitic should drop; see
				-- above.
				if clitic_i_drops then
					drop_clitic_i()
				end
				local stem_with_infix = ending_is_full and "" or stem .. (infix or "")
				-- Drop final -j- of stem before an ending beginning with a consonant. This happens e.g. in [[kirkja]]
				-- "church" with genitive plural -na, producing [[kirkna]]. It does not happen with a null ending; cf.
				-- neuter [[emj]] "cries, shouting" and [[gremj]] "anger, irritation" (the latter not in BÍN).
				if stem_with_infix:find("j$") and rfind(ending, "^" .. com.cons_c) then
					stem_with_infix = stem_with_infix:gsub("j$", "")
				end
				local stem_with_ending
				-- An initial s- of the ending drops after a cluster of cons + s (including written <x>).
				if ending:find("^s") and (stem_with_infix:find("x$") or rfind(stem_with_infix, com.cons_c .. "s$")) then
					stem_with_ending = stem_with_infix .. ending:gsub("^s", "")
				else
					stem_with_ending = stem_with_infix .. ending
				end
				if clitic == "" then
					return stem_with_ending
				end
				if slot == "dat_p" then
					stem_with_ending = stem_with_ending:gsub("m$", "")
				end
				if clitic:find("^i.*[aiu]") then -- disyllabic clitics in i-
					-- in practice, fem acc_s -ina, dat_s -inni, gen_s -innar
					if rfind(stem_with_ending, com.vowel_c .. "$") then
						drop_clitic_i()
					end
				elseif clitic:find("^i") then -- monosyllabic clitics in i-
					local ending_for_clitic_dropping = ending_was_asterisk and base.lemma_ending or ending
					if ending_for_clitic_dropping:find("[aiu]$") then
						drop_clitic_i()
					end
				end
				return stem_with_ending .. clitic
			end

			local combined_footnotes = iut.combine_footnotes(
				iut.combine_footnotes(mut_footnotes, infix_footnotes),
				iut.combine_footnotes(ending_footnotes, clitic_footnotes)
			)
			local clitic_with_notes = iut.combine_form_and_footnotes(clitic, combined_footnotes)
			if not stem_in_effect then
				interr("stem_in_effect is nil")
			end
			iut.add_forms(base.forms, slot_prefix .. slot, stem_in_effect, clitic_with_notes,
				combine_stem_ending)
		end
	end
end


-- Add the definite and indefinite variants of a slot by combining the appropriate stem in `props` with (optionally) an
-- infix in `props` and the endings in `endings`, tacking on the definite article clitic in the definite slot variant.
-- This calls the underlying function add_slotval() twice, once for indefinite forms and once for definite forms, and is
-- normally called by add_decl() or similar function to add an entire declension. `endings` can be nil (no endings are
-- added), a single string, a list of strings, a list of form objects (i.e. in general list form), or a table containing
-- fields `indef` and `def` (each of which can be any of the previous formats) to add separate sets of endings for the
-- indefinite and definite slot variants. If any of the formats for `endings` is supplied other than the separate
-- indefinite/definite table, the supplied set of endings is used for both indefinite and definite slot variants.
-- `ending_override` and `endings_are_full` are as in add_slotval().
local function add(base, slot, props, endings, ending_override, endings_are_full)
	if not endings then
		return
	end
	local indef_endings, def_endings
	if type(endings) == "table" and (endings.indef or endings.def) then
		indef_endings = endings.indef
		def_endings = endings.def
	else
		indef_endings = endings
		def_endings = endings
	end
	if indef_endings and base.definiteness ~= "def" then
		add_slotval(base, "ind_", slot, props, indef_endings, nil, ending_override, endings_are_full)
	end
	if def_endings and (base.definiteness ~= "indef" and base.definiteness ~= "none") then
		local clitic
		if base.props.adj then -- FIXME: not necessary once we get adjective inflections from [[Module:is-adjective]]
			clitic = ""
		else
			clitic = clitic_articles[base.gender]
			if not clitic then
				error(("Internal error: Unrecognized value for base.gender: %s"):format(dump(base.gender)))
			end
			clitic = clitic[slot]
			if not clitic then
				error(("Internal error: Unrecognized value for `slot` in add(): %s"):format(dump(slot)))
			end
		end
		add_slotval(base, "def_", slot, props, def_endings, clitic, ending_override, endings_are_full)
	end
end


-- Generate the accusative plural ending from the nominative plural. For feminines and neuters, both are the same.
-- For masculines, drop the -r except in -ur.
local function acc_p_from_nom_p(base, nom_p)
	if base.gender == "f" or base.gender == "n" then
		return nom_p
	end
	if not nom_p then
		return nom_p -- this is correct as `nom_p` could be nil or false and we want to return the same thing
	end
	local function form_masc_acc_p(ending)
		-- Form the masculine accusative by dropping -r unless the form ends in -ur, which is kept. If the ending is *,
		-- we substitute the entire actual lemma. In that case, if the lemma is definite-only, we have to strip off
		-- the nominative plural clitic -nir before generating the accusative. We don't add the clitic -na because it
		-- will be added in add_slotval().
		if ending == "*" then
			ending = "!" .. base.actual_lemma
		end
		if base.definiteness == "def" and ending:find("^!") then
			ending = ending:match("^(.*)nir$")
			if not ending then
				error(("Masculine plural definite-only lemma '%s' does not end in expected clitic '-nir'; " ..
					"don't know how to compute the corresponding accusative plural"):format(base.actual_lemma))
			end
		end
		-- If the ending is full (begins with !), check the whole thing for -ur at the end.
		if ending:find("^%^*ur$") or ending:find("^!.*[^Aa]ur$") then
			-- as-is
		else
			ending = ending:gsub("r$", "")
		end
		return ending
	end
	if type(nom_p) == "string" then
		return form_masc_acc_p(nom_p)
	end
	local acc_p = {}
	for _, ending in ipairs(nom_p) do
		if type(ending) == "string" then
			table.insert(acc_p, form_masc_acc_p(ending))
		else
			table.insert(acc_p, {form = form_masc_acc_p(ending.form), footnotes = ending.footnotes})
		end
	end
	return acc_p
end


local function process_one_slot_override(base, slot, spec)
	-- Call skip_slot() based on the declined number and definiteness; if the actual number is different, we correct
	-- this in decline_noun() at the end.
	if skip_slot(base.number, base.definiteness, slot) then
		error(("Override specified for invalid slot '%s' due to '%s' number restriction and/or '%s' definiteness restriction"):format(
			slot, base.number, base.definiteness))
	end
	local defslot = slot:find("^def_")
	if defslot then
		base.forms[slot] = nil
	else
		if spec.indef ~= false then
			base.forms["ind_" .. slot] = nil
		end
		if spec.def ~= false then
			base.forms["def_" .. slot] = nil
		end
	end
	if defslot then
		local slot_prefix
		-- Don't call add(), like below, because it adds both indefinite and definite variants, including definite
		-- clitics in the latter. Instead, directly call add_slotval(). But we need to separate the slot into slot
		-- prefix "def_" and the remainder because add_slotval() expects slots to be missing the prefix when
		-- checking which stem to use (which may depend on the slot).
		slot_prefix, slot = slot:match("^(def_)(.*)$")
		for _, props in ipairs(base.prop_sets) do
			add_slotval(base, slot_prefix, slot, props, spec.def, nil, "ending override")
		end
	else
		local endings
		if spec.indef ~= nil and spec.def ~= nil then
			-- This could include `false` as the value of either `spec.indef` or `spec.def` to not touch those slots.
			-- Note that specifying something like 'dat/i' is allowed and will only override the definite slot, but
			-- is different from a definite-slot override 'defdatinum' because the latter includes the clitic in it.
			endings = {
				indef = spec.indef,
				def = spec.def,
			}
		elseif not spec.indef then
			error(("Internal error: Unless both `spec.indef` and `spec.def` have non-nil values (i.e. the user included a slash in the override, `spec.indef` must be defined: %s"):dump(spec))
		elseif slot == "acc_p" then
			-- As a special case, don't carry over literary acc_p ending -u to the definite.
			local def_endings = {}
			for _, ending in ipairs(spec.indef) do
				-- If the ending is full (begins with !), check the whole thing for -u at the end.
				if not ending.form:find("^%^*u$") and not ending.form:find("^!.*[^Aa]u$") then
					table.insert(def_endings, ending)
				end
			end
			endings = {
				indef = spec.indef,
				def = def_endings,
			}
		else
			endings = spec.indef
		end
		for _, props in ipairs(base.prop_sets) do
			add(base, slot, props, endings, "ending override")
		end
	end
end


local function process_slot_overrides(base)
	if base.gens then
		process_one_slot_override(base, "gen_s", base.gens)
	end
	if base.pls then
		local spec = base.pls
		process_one_slot_override(base, "nom_p", spec)
		local acc_p_spec = {
			indef = acc_p_from_nom_p(base, spec.indef),
			def = acc_p_from_nom_p(base, spec.def),
		}
		process_one_slot_override(base, "acc_p", acc_p_spec)
	end
	for slot, spec in pairs(base.overrides) do
		process_one_slot_override(base, slot, spec)
	end
end


-- Generate the full declension for the term given the endings for each slot. acc_p, dat_p and gen_p can be omitted and
-- will be defaulted: dat_p defaults to "um", gen_p defaults to "a", and acc_p defaults to the nom_p except for masculines
-- not in -ur, where the -r is dropped. Use `false` as the value of an ending to disable generating any value for that
-- slot.
local function add_decl_with_nom_sg(base, props, nom_s, acc_s, dat_s, gen_s, nom_p, acc_p, dat_p, gen_p)
	add(base, "nom_s", props, nom_s)
	add(base, "acc_s", props, acc_s)
	add(base, "dat_s", props, dat_s)
	add(base, "gen_s", props, gen_s)
	if base.number == "pl" then
		-- If this is a plurale tantum noun and we're processing the nominative plural, use the user-specified lemma
		-- rather than generating the plural from the synthesized singular, which may not match the specified lemma.
		-- This is both because we don't set a plural override to specify what the plural should look like and because
		-- of exceptional cases like [[dyr]], which is plural-only and uses 'decllemma:dyrir'.
		nom_p = "*"
	end
	add(base, "nom_p", props, nom_p)
	-- Generate defaults for acc_p, dat_p, gen_p if nil was specified; but be careful not to do so for false, which
	-- means to generate no form.
	if acc_p == nil then
		acc_p = acc_p_from_nom_p(base, nom_p)
	end
	if dat_p == nil then
		dat_p = "um"
	end
	if gen_p == nil then
		gen_p = "a"
	end
	add(base, "acc_p", props, acc_p)
	add(base, "dat_p", props, dat_p)
	add(base, "gen_p", props, gen_p)
end

-- Generate the full declension for the term given the endings for each slot except the nom_s. This is like
-- add_decl_with_nom_sg() but takes the nom sg directly from the lemma instead of trying to reconstruct it from a stem,
-- which is more correct in the vast majority of circumstances. The * below is a signal to the underlying add() function
-- to use the actual lemma (not any stem, and not the value of 'decllemma:' if given) for the nom sg. Note that add() is
-- smart enough to ignore this for the definite nom sg when the 'defcon' indicator is given, because in that case the stem
-- for the def nom sg is contracted compared with the lemma. (Specifically, it uses the correct contracted stem and a null
-- ending; AFAIK all cases of 'defcon' occur with lemmas with a null ending in the nom sg.)
local function add_decl(base, props, acc_s, dat_s, gen_s, nom_p, acc_p, dat_p, gen_p)
	add_decl_with_nom_sg(base, props, "*", acc_s, dat_s, gen_s, nom_p, acc_p, dat_p, gen_p)
end

local function add_sg_decl(base, props, acc_s, dat_s, gen_s)
	add_decl(base, props, acc_s, dat_s, gen_s, false, false, false, false)
end

local function add_pl_only_decl(base, props, acc_p, dat_p, gen_p)
	add_decl(base, props, false, false, false, "*", acc_p, dat_p, gen_p)
end


-- Table mapping declension types to functions to decline the noun. The function takes two arguments, `base` and
-- `props`; the latter specifies the computed stems (vowel vs. non-vowel, singular vs. plural) and whether the noun
-- is reducible and/or has vowel alternations in the stem. Most of the specifics of determining which stem to use
-- and how to modify it for the given ending are handled in add_decl(); the declension functions just need to generate
-- the appropriate endings.
local decls = {}


decls["indecl"] = function(base, props)
	add_decl(base, props, "", "", "", "", "", "", "")
end


decls["decl?"] = function(base, props)
	add_decl(base, props, "?", "?", "?", "?", "?", "?", "?")
end


decls["m"] = function(base, props)
	-- The default dative singular is computed below in determine_default_masc_dat_sg().
	local dat = props.default_dat_sg
	add_decl(base, props, "", dat, "s", "ar")
end


decls["m-ir"] = function(base, props)
	add_decl(base, props, "i", "i", "is", "ar")
end


decls["m-skapur"] = function(base, props)
	-- Nouns in -skapur; default gen is -ar, default dat is -/-, default num is sg.
	add_decl(base, props, "", "", "ar", "ar")
end


decls["m-naður"] = function(base, props)
	-- Nouns in -naður; default gen is -ar, default dat is dati/i:-, default nom pl is -ir, default num is sg,
	-- default u-mutation is uUmut.
	add_decl(base, props, "", {indef = "i", def = {"i", ""}}, "ar", "ir")
end


decls["m-kell"] = function(base, props)
	-- Proper nouns in -kell; [[Þorkell]], [[Grímkell]], etc.
	local alt_dat_s = base.stem:gsub("kel$", "katli")
	add_decl(base, props, "", {"i", {form = "!" .. alt_dat_s, footnotes = {"[archaic]"}}}, "s", false, false, false, false)
end


decls["m-ó"] = function(base, props)
	-- abbreviations of school names generally have null genitive: [[Kennó]] from [[Kennaraskóla]] "Teachers' College"),
	-- [[Astró]], [[Borgó]] (from [[Borgarholtsskóli]]), [[Bríó]], [[Foldó]] (from [[Foldaskóli]]), [[Hafró]] (from
	-- [[Hafrannsóknastofnun]] "Marine Research Institute" (of Norway), [[Hagó]] (from [[Hagaskóli]]), [[Húsó]],
	-- [[Kvennó]] (from [[Kvennaskóli]]), [[Meló]] (from [[Melaskóli]]), [[Menntó]] (from [[Menntaskóli]]), [[Tónó]]
	-- (from [[Tónlistarskóli]]), [[Való]] (from [[Valhúsaskóli]]), [[Versló]]/[[Verzló]] (from
	-- [[Verslunarskóli Íslands|Iceland Business School]]); but these are completely outweighed by male given names,
	-- nicknames and historical names of men in -ó (e.g. [[Bó]], [[Bóbó]], [[Brúnó]], [[Dittó]], [[Filpó]], [[Galíleó]],
	-- [[Jagó]], [[Kató]], [[Kristó]], [[Leó]], [[Leónardó]], [[Markó]], etc.) as well as common nouns in -ó (e.g.
	-- [[bóleró]] "bolero", [[evró]] "Euro (dated)", [[faraó]] "pharaoh", [[kanó]] "canoe", [[kímonó]] "kimono",
	-- [[mambó]] "mambo", [[pesó]] "peso", [[pikkóló]] "piccolo", [[róló]] "playground", [[sleikjó]] "lollipop",
	-- etc.)
	add_decl(base, props, "", "", "s", "ar")
end


decls["m-rstem"] = function(base, props)
	local imut = "^"
	add_decl(base, props, "ur", "ur", {"ur", {form = "urs", footnotes = {"[proscribed]"}}},
		imut .. "ur", nil, imut .. "rum", imut .. "ra")
end


decls["m-ndi"] = function(base, props)
	-- Words in -ndi, mostly derived from present participles and mostly in [[andi]]; but cf. [[bóndi]], [[frændi]],
	-- and [[fjandi]] with two plurals with different meanings.
	local imut
	if props.stem:find("ænd$") then
		imut = ""
	else
		imut = "^"
	end
	add_decl(base, props, "a", "a", "a", imut .. "ur", nil,
		{imut .. "um", {form = "um", footnotes = "[obsolete]"}},
		{imut .. "a", {form = "a", footnotes = "[rare]"}})
end


decls["m-weak"] = function(base, props)
	-- Words in -i like [[tími]] "time, hour"; also words in -a e.g. [[herra]] "gentleman; sir, Mr. (term of address)",
	-- [[séra]]/[[síra]] "reverend"
	add_decl(base, props, "a", "a", "a", "ar")
end


decls["f"] = function(base, props)
	-- Normal strong feminine nouns; default to genitive -ar, plural -ir.
	add_decl(base, props, "", "", "ar", "ir")
end


decls["f-ung"] = function(base, props)
	-- Strong feminine nouns in -ung, e.g. [[nýjung]] "newness, novelty; piece of news", [[nauðung]]
	-- "constraint, compulsion". Most such nouns are singular-only, e.g. [[djörfung]] "boldness, daring", [[launung]]
	-- "secrecy". Occasional nouns need overrides, e.g. [[sundrung]] "scattering; dissension, division, disunity" with
	-- acc/dat sg either - or -u (but only - in the definite acc/dat sg).
	add_decl(base, props, "", "", "ar", "ar")
end


decls["f-ing"] = function(base, props)
	-- Strong feminine nouns in -ing, e.g. [[kerling]] "old woman", [[eining]] "unity; unit". Singular-only: e.g.
	-- [[málning] "paint", [[menning]] "culture", [[örvænting]] "despair".
	add_decl(base, props, "u", "u", "ar", "ar")
end


decls["f-ur"] = function(base, props)
	add_decl(base, props, "i", "i", "ar", "ir")
end


decls["f-i"] = function(base, props)
	add_decl(base, props, "i", "i", "i", "ir")
end


decls["f-long-vowel"] = function(base, props)
	-- nouns in -á, e.g. [[á]] "river", [[gjá]] "gorge, canyon", [[skuggská]] "mirror", [[slá]] "door bolt";
	-- nouns in -ó, e.g. [[fló]] "flea", [[kónguló]] "spider", [[kló]] "claw";
	-- nouns in -ú, e.g. [[frú]] "married woman", [[trú]] "faith, belief".
	-- Each is slightly different.
	local gen, nompl
	if props.stem:find("á$") then
		gen = "r"
		nompl = "r"
	elseif props.stem:find("ó$") then
		gen = "ar"
		nompl = "^r"
	elseif props.stem:find("ú$") then
		gen = "ar"
		nompl = "r"
	else
		error(("Unrecognized stem '%s' for long-vowel feminine; should end in -á, -ó or -ú"))
	end
	add_decl(base, props, "", "", gen, nompl, nompl, "m", {indef = "a", def = ""})
end


decls["f-long-umlaut-vowel-r"] = function(base, props)
	-- nouns in long umlauted vowel + -r: [[kýr]] "cow", [[sýr]] "sow (archaic)", [[ær]] and compounds.
	add_decl(base, props, "", "", "^r", "^r", "^r", "m", {indef = "a", def = ""})
end


decls["f-acc-dat-i"] = function(base, props)
	-- Some proper female names with -i in the acc and dat sg
	add_decl(base, props, "i", "i", "ar", "ar")
end


decls["f-rstem"] = function(base, props)
	local imut
	if props.stem:find("syst$") then
		imut = ""
	else
		imut = "^"
	end
	local sg_ending = {"ur", {form = "ir", footnotes = {"[proscribed]"}}}
	add_decl(base, props, sg_ending, sg_ending, sg_ending, imut .. "ur", nil, imut .. "rum", imut .. "ra")
end


decls["f-weak"] = function(base, props)
	add_decl(base, props, "u", "u", "u", "ur")
end


decls["n"] = function(base, props)
	-- Normal (strong) neuter nouns.
	add_decl(base, props, "", "i", "s", "^^")
end


decls["n-já"] = function(base, props)
	-- [[tré]] "tree; wood"; [[hné]]/[[kné]] "knee"; [[fé]] "sheep; cattle; money"; the stem has previously been set
	-- to not include final -é; fé has genitive fjár while the others have genitive in -és.
	local gen = props.stem:find("f$") and "jár" or "és"
	add_decl_with_nom_sg(base, props, "é%", "é%", "é", gen, "é%", "é%", "jám", {indef = "jáa", def = "já"})
end


decls["n-i"] = function(base, props)
	-- Neuter nouns in -i, e.g. [[kvæði]] "poem, song". Nouns in -ki and -gi e.g. [[ríki]] "state, kingdom" and [[engi]]
	-- "meadow" have j-insertion by default, which is set elsewhere.
	add_decl(base, props, "i", "i", "is", "i")
end


decls["n-weak"] = function(base, props)
	-- "Weak" neuter nouns in -a, e.g. [[auga]] "eye", [[hjarta]] "heart". U-mutation occurs in the nom/acc/dat pl but
	-- doesn't need to be indicated explicitly because the ending begins with u-.
	add_decl(base, props, "a", "a", "a", "u")
end


decls["adj"] = function(base, props)
	local state = base.props.weak and "wk" or "str"
	if state == "str" then
		error("FIXME: Not implemented yet")
		local props = {}
		-- FIXME, write the in-between code
		local propspec = table.concat(props, ".")
		if propspec ~= "" then
			propspec = "<" .. propspec .. ">"
		end
		local adj_alternant_multiword_spec = require("Module:is-adjective").do_generate_forms({base.lemma .. propspec})
		local function copy(from_slot, to_slot, do_clone)
			local source = adj_alternant_multiword_spec.forms[from_slot]
			if do_clone then
				source = m_table.deepcopy(source)
			end
			base.forms[to_slot] = source
		end
		local function copy_gender_number_forms(gender, number, state)
			for _, case in ipairs(cases) do
				-- We want to avoid sharing form objects (although sharing footnotes is OK, but we don't avoid cloning them
				-- here) so we can later side-effect form objects as needed.
				copy(state .. "_" .. case .. "_" .. gender .. "_" .. number, "ind_" .. case .. "_" .. number)
				copy(state .. "_" .. case .. "_" .. gender .. "_" .. number, "def_" .. case .. "_" .. number, "do clone")
			end
		end

		if base.number ~= "pl" then
			copy_gender_number_forms(base.gender, "s", state)
		end
		if base.number ~= "sg" then
			copy_gender_number_forms(base.gender, "p", state)
		end
	else
		-- FIXME: this code should go away
		if base.gender == "m" then
			add_decl(base, props, "a", "a", "a", "u", "u", "u", "u")
		elseif base.gender == "f" then
			add_decl(base, props, "u", "u", "u", "u", "u", "u", "u")
		elseif base.gender == "n" then
			add_decl(base, props, "a", "a", "a", "u", "u", "u", "u")
		else
			error(("Internal error: Unrecognized gender '%s'"):format(base.gender))
		end
	end
end

local function set_pron_defaults(base)
	if base.gender or base.number or base.definiteness then
		error("Can't specify gender, number or definiteness for pronouns")
	end

	local function pron_props()
		-- Return values are GENDER, NUMBER
		if base.lemma == "ég" or base.lemma == "þú" then
			return "none", "sg"
		elseif base.lemma == "við" or base.lemma == "þið" then
			return "none", "pl"
		elseif base.lemma == "hann" then
			return "m", "sg"
		elseif base.lemma == "hún" then
			return "f", "sg"
		elseif base.lemma == "það" then
			return "n", "sg"
		elseif base.lemma == "þeir" then
			return "m", "pl"
		elseif base.lemma == "þær" then
			return "f", "pl"
		elseif base.lemma == "þau" then
			return "n", "pl"
		elseif base.lemma == "sig" then
			return "none", "none"
		else
			error(("Unrecognized pronoun '%s'"):format(base.lemma))
		end
	end

	local gender, number = pron_props()
	base.gender = gender
	base.actual_gender = gender
	base.number = number
	base.actual_number = number
	base.definiteness = "none"
end


local function determine_pronoun_props(base)
	base.prop_sets = {{stem = {form = ""}}}
	base.decl = "pron"
end


decls["pron"] = function(base, props)
	if base.lemma == "ég" then
		add_sg_decl(base, props, "mig", "mér", "mín")
	elseif base.lemma == "þú" then
		add_sg_decl(base, props, "þig", "þér", "þín")
	elseif base.lemma == "hann" then
		add_sg_decl(base, props, "hann", "honum", "hans")
	elseif base.lemma == "hún" then
		add_sg_decl(base, props, "hana", "henni", "hennar")
	elseif base.lemma == "það" then
		add_sg_decl(base, props, "það", "því", "þess")
	elseif base.lemma == "við" then
		add_pl_only_decl(base, props, "okkur", "okkur", "okkar")
	elseif base.lemma == "þið" then
		add_pl_only_decl(base, props, "ykkur", "ykkur", "ykkar")
	elseif base.lemma == "þeir" then
		add_pl_only_decl(base, props, "þá", "þeim", "þeirra")
	elseif base.lemma == "þær" then
		add_pl_only_decl(base, props, "þær", "þeim", "þeirra")
	elseif base.lemma == "þau" then
		add_pl_only_decl(base, props, "þau", "þeim", "þeirra")
	elseif base.lemma == "sig" then
		-- Underlyingly we handle [[sig]]'s slots as singular.
		add_decl_with_nom_sg(base, props, false, "*", "sér", "sín", false, false, false, false)
	else
		error(("Internal error: Unrecognized pronoun lemma '%s'"):format(base.lemma))
	end
end


-- Return the lemmas for this term. The return value is a list of {form = FORM, footnotes = FOOTNOTES}.
-- If `linked_variant` is given, return the linked variants (with embedded links if specified that way by the user),
-- otherwies return variants with any embedded links removed. If `remove_footnotes` is given, remove any
-- footnotes attached to the lemmas.
function export.get_lemmas(alternant_multiword_spec, linked_variant, remove_footnotes)
	-- FIXME: Update for Icelandic
	local slots_to_fetch = potential_lemma_slots
	local linked_suf = linked_variant and "_linked" or ""
	for _, slot in ipairs(slots_to_fetch) do
		if alternant_multiword_spec.forms[slot .. linked_suf] then
			local lemmas = alternant_multiword_spec.forms[slot .. linked_suf]
			if remove_footnotes then
				local lemmas_no_footnotes = {}
				for _, lemma in ipairs(lemmas) do
					table.insert(lemmas_no_footnotes, {form = lemma.form})
				end
				return lemmas_no_footnotes
			else
				return lemmas
			end
		end
	end
	return {}
end


local function handle_derived_slots_and_overrides(base)
	-- Process slot overrides: First slots specified after the gender, then individual slot overrides specified as
	-- separate indicators.
	process_slot_overrides(base)

	-- Compute linked versions of potential lemma slots, for use in {{is-noun}}.  We substitute the original lemma
	-- (before removing links) for forms that are the same as the lemma, if the original lemma has links.
	for _, slot in ipairs(potential_lemma_slots) do
		iut.insert_forms(base.forms, slot .. "_linked", iut.map_forms(base.forms[slot], function(form)
			if form == base.orig_lemma_no_links and rfind(base.orig_lemma, "%[%[") then
				return base.orig_lemma
			else
				return form
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


local function is_regular_noun(base)
	return not base.props.adj and not base.props.pron
end


local function process_declnumber(base)
	base.actual_number = base.number
	if base.declnumber then
		if base.declnumber == "sg" or base.declnumber == "pl" then
			base.number = base.declnumber
		else
			error(("Unrecognized value '%s' for 'declnumber', should be 'sg' or 'pl'"):format(base.declnumber))
		end
	end
end


-- Map `fn` over an override spec (either `gens`, `pls` or one of the overrides in `overrides`). `fn` is passed one
-- item (the form object of the override), which it can mutate if needed. If it ever returns non-nil, mapping stops
-- and that value is returned as the return value of `map_override`; otherwise mapping runs to completion and nil is
-- returned.
local function map_override(override, fn)
	if not override then
		return nil
	end
	local function map_one_list(list)
		if not list then
			return nil
		end
		for _, formobj in ipairs(list) do
			local retval = fn(formobj)
			if retval ~= nil then
				return retval
			end
		end
		return nil
	end
	local retval = map_one_list(override.indef)
	if retval ~= nil then
		return retval
	end
	return map_one_list(override.def)
end

-- Map `fn` over all override specs in `base` (`gens`, `pls` and the overrides in `overrides`). `fn` is passed one
-- item (the form object of the override), which it can mutate if needed. If it ever returns non-nil, mapping stops
-- and that value is returned as the return value of `map_override`; otherwise mapping runs to completion and nil is
-- returned.
local function map_all_overrides(base, fn)
	for slot, override in pairs(base.overrides) do
		local retval = map_override(override, fn)
		if retval ~= nil then
			return retval
		end
	end
	local retval = map_override(base.gens, fn)
	if retval ~= nil then
		return retval
	end
	return map_override(base.pls, fn)
end


-- Like iut.split_alternating_runs_and_strip_spaces(), but ensure that backslash-escaped commas and periods are not
-- treated as separators.
local function split_alternating_runs_with_escapes(segments, splitchar)
	for i, segment in ipairs(segments) do
		segment = rsub(segment, "\\,", SUB_ESCAPED_COMMA)
		segments[i] = rsub(segment, "\\%.", SUB_ESCAPED_PERIOD)
	end
	local separated_groups = iut.split_alternating_runs_and_strip_spaces(segments, splitchar)
	for _, separated_group in ipairs(separated_groups) do
		for i, segment in ipairs(separated_group) do
			segment = rsub(segment, SUB_ESCAPED_COMMA, ",")
			separated_group[i] = rsub(segment, SUB_ESCAPED_PERIOD, ".")
		end
	end
	return separated_groups
end


local function fetch_footnotes(separated_group, parse_err)
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


-- Fetch and parse a slot override, e.g. "ar:s" or "um:m[archaic]/um" or "i:!Þorkatli[archaic]" (where ! indicates that
-- the override is the full form including the stem); that is, everything after the slot name(s). `segments` is the
-- input in the form of a list where the footnotes have been separated out (see `parse_override` below); `spectype` is
-- used in error messages and specifies e.g. "genitive" or "dat+gen slot override"; `allow_blank` indicates that a
-- completely blank override spec is allowed (in that case, nil will be returned); `defslot`, if true, indicates that
-- we're processing a definite slot override, i.e. two slash-separated specs (indefinite and definite) are not allowed
-- and the return overrides will be stored into `def`; and `parse_err` is a function of one argument to throw a parse
-- error. The return value is an object containing fields `indef` and/or `def`, of the format described below in the
-- comment above `parse_override`.
local function fetch_slot_override(segments, spectype, allow_blank, defslot, parse_err)
	if allow_blank and #segments == 1 and segments[1] == "" then
		return nil
	end
	local slash_separated_groups = iut.split_alternating_runs_and_strip_spaces(segments, "/")
	if #slash_separated_groups > 2 then
		parse_err(("Can specify at most two slash-separated override groups for %s, but saw %s"):format(
			spectype, #slash_separated_groups))
	end
	if slash_separated_groups[2] and defslot then
		parse_err(("Can't specify two slash-separated override groups for %s; the second override group is for the definite slot variant, but the slot is already definite"):format(
			spectype))
	end
	local ret = {}
	for i, slash_separated_group in ipairs(slash_separated_groups) do
		local retfield = defslot and "def" or i == 1 and "indef" or "def"
		if #slash_separated_group == 1 and slash_separated_group[1] == "" then
			ret[retfield] = false
		else
			local colon_separated_groups = iut.split_alternating_runs_and_strip_spaces(slash_separated_group, ":")
			local specs = {}
			for _, colon_separated_group in ipairs(colon_separated_groups) do
				local form = colon_separated_group[1]
				if form == "" then
					parse_err(("Use - to indicate an empty ending for %s: '%s'"):format(spectype,
						table.concat(segments)))
				elseif form == "-" then
					form = ""
				elseif form == "--" then -- missing
					form = "-"
				end
				local new_spec = {form = form, footnotes = fetch_footnotes(colon_separated_group, parse_err)}
				for _, existing_spec in ipairs(specs) do
					if existing_spec.form == new_spec.form then
						parse_err("Duplicate " .. spectype .. " spec '" .. table.concat(colon_separated_group) .. "'")
					end
				end
				table.insert(specs, new_spec)
			end
			ret[retfield] = specs
		end
	end
	return ret
end


--[=[
Parse a single override spec (e.g. 'dat-:i/-' or 'nompl+accpl^/' or
'defnompl+defaccpl!sumrin[when referring to summers in general]:!sumurin[when referring to a specific number of summers]')
and return two values: the slot(s) the override applies to, and an object describing the override spec. The input is
actually a list where the footnotes have been separated out; for example, given the third example spec above, the input
will be a list {"defnompl+defaccpl!sumrin", "[when referring to summers in general]", ":!sumurin",
  "[when referring to a specific number of summers]", ""}.

The object returned for 'dat-:i[mostly in the context of violent actions]/-' looks like this:

{
  indef = {
	{
	  form = ""
	},
	{
	  form = "i",
	  footnotes = {"[mostly in the context of violent actions]"}
	}
  },
  def = {
    {
	  form = ""
	}
  }
}

The object returned for '!nompl+accpl^/' looks like this:

{
  indef = {
	{
	  form = "^"
	},
  },
  def = false
}

The object returned for 'defnompl+defaccpl!sumrin[when referring to summers in general]:!sumurin[when referring to a specific number of summers]'
looks like this:

{
  def = {
	{
	  form = "!sumrin",
	  footnotes = {"[when referring to summers in general]"}
	},
	{
	  form = "!sumurin",
	  footnotes = {"[when referring to a specific number of summers]"}
	}
  }
}
]=]
local function parse_override(segments, parse_err)
	local part = segments[1]
	local slots = {}
	local defslot
	while true do
		local this_defslot
		if part:find("^def") then
			this_defslot = true
			part = usub(part, 4)
		else
			this_defslot = false
		end
		if defslot == nil then
			defslot = this_defslot
		elseif defslot ~= this_defslot then
			parse_err(("When multiple slot overrides are combined with +, all must be definite or indefinite: '%s'"):
				format(table.concat(segments)))
		end
		local case = usub(part, 1, 3)
		if case_set[case] then
			-- ok
		else
			parse_err(("Unrecognized case '%s' in override: '%s'"):format(case, table.concat(segments)))
		end
		part = usub(part, 4)
		local slot = defslot and "def_" or ""
		if rfind(part, "^pl") then
			part = usub(part, 3)
			slot = slot .. case .. "_p"
		else
			slot = slot .. case .. "_s"
		end
		table.insert(slots, slot)
		if rfind(part, "^%+") then
			part = usub(part, 2)
		else
			break
		end
	end
	segments[1] = part
	local retval = fetch_slot_override(segments, ("%s slot override"):format(table.concat(slots, "+")), false, defslot,
		parse_err)
	return slots, retval
end


local function parse_inside(base, inside, is_scraped_noun)
	local function parse_err(msg)
		error((is_scraped_noun and "Error processing scraped noun spec: " or "") .. msg .. ": <" ..
			inside .. ">")
    end

	local segments = iut.parse_balanced_segment_run(inside, "[", "]")
	local dot_separated_groups = split_alternating_runs_with_escapes(segments, "%.")
	for i, dot_separated_group in ipairs(dot_separated_groups) do
		-- Parse a "mutation" spec such as "umut,uUmut[rare]" or "-unuUmut,unuUmut" or "imut". This assumes the
		-- mutation spec is contained in `dot_separated_group` (already split on brackets) and the result of parsing
		-- should go in `base[dest]`. `allowed_specs` is a list of the allowed mutation specs in this group, such
		-- as {"umut", "Umut", "uumut", "uUmut", "u_mut"} or {"imut", "-imut"}. The result of parsing is a list of
		-- structures of the form {
		--   form = "FORM",
		--   footnotes = nil or {"FOOTNOTE", "FOOTNOTE", ...},
		-- }.
		local function parse_mutation_spec(dest, allowed_specs)
			if base[dest] then
				parse_err(("Can't specify '%s'-type mutation spec twice; second such spec is '%s'"):format(
					dest, table.concat(dot_separated_group)))
			end
			base[dest] = {}
			local comma_separated_groups = split_alternating_runs_with_escapes(dot_separated_group, ",")
			for _, comma_separated_group in ipairs(comma_separated_groups) do
				local specobj = {}
				local spec = comma_separated_group[1]
				if not m_table.contains(allowed_specs, spec) then
					parse_err(("For '%s'-type mutation spec, saw unrecognized spec '%s'; valid values are %s"):
						format(dest, spec, generate_list_of_possibilities_for_err(allowed_specs)))
				else
					specobj.form = spec
				end
				specobj.footnotes = fetch_footnotes(comma_separated_group, parse_err)
				table.insert(base[dest], specobj)
			end
		end

		local part = dot_separated_group[1]
		if i == 1 and part ~= "+" and not part:find("^@") and part ~= "pron" then
			local comma_separated_groups = split_alternating_runs_with_escapes(dot_separated_group, ",")
			if #comma_separated_groups > 3 then
				parse_err(("At most three comma-separated specs are allowed but saw %s"):format(
					#comma_separated_groups))
			end
			if comma_separated_groups[1][2] then
				parse_err("Footnotes not allowed on gender indicator")
			end
			base.gender = comma_separated_groups[1][1]
			if not base.gender:find("^[mfn]$") then
				parse_err(("Unrecognized gender '%s', should be 'm', 'f' or 'n'"):format(base.gender))
			end
			if comma_separated_groups[2] then
				base.gens = fetch_slot_override(comma_separated_groups[2], "genitive", true, false, parse_err)
			end
			if comma_separated_groups[3] then
				base.pls = fetch_slot_override(comma_separated_groups[3], "nominative plural", true, false,
					parse_err)
			end
		elseif part == "" then
			if not dot_separated_group[2] then
				parse_err("Blank indicator; not allowed without attached footnotes")
			end
			base.footnotes = fetch_footnotes(dot_separated_group, parse_err)
		elseif part == "addnote" then
			local spec_and_footnotes = fetch_footnotes(dot_separated_group, parse_err)
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
		elseif ulen(part) > 3 and case_set[usub(part, 1, 3)] or (
			ulen(part) > 6 and usub(part, 1, 3) == "def" and case_set[usub(part, 4, 6)]) then
			local slots, override = parse_override(dot_separated_group, parse_err)
			for _, slot in ipairs(slots) do
				if base.overrides[slot] then
					error(("Two overrides specified for slot '%s'"):format(slot))
				else
					base.overrides[slot] = override
				end
			end
		elseif part:find("^[Uu]+_?mut") then
			parse_mutation_spec("umut", {"umut", "Umut", "uumut", "uUmut", "u_mut"})
		elseif not part:find("^imutval") and part:find("^%-?imut") then
			parse_mutation_spec("imut", {"imut", "-imut"})
		elseif part:find("^%-?un[uU]+_?mut") then
			parse_mutation_spec("unumut", {"unumut", "unUmut", "unuumut", "unuUmut", "unu_mut",
										   "-unumut", "-unUmut", "-unuumut", "-unuUmut", "-unu_mut"})
		elseif part:find("^%-?unimut") then
			parse_mutation_spec("unimut", {"unimut", "-unimut"})
		elseif part:find("^%-?con") then
			parse_mutation_spec("con", {"con", "-con"})
		elseif part:find("^%-?defcon") then
			parse_mutation_spec("defcon", {"defcon", "-defcon"})
		elseif not part:find("^já") and part:find("^%-?j") then -- don't trip over .já indicator
			parse_mutation_spec("j", {"j", "-j"})
		elseif not part:find("^vstem") and part:find("^%-?v") then
			parse_mutation_spec("v", {"v", "-v"})
		elseif #dot_separated_group > 1 then
			parse_err(
				("Footnotes only allowed with slot overrides, negatable indicators and by themselves: '%s'"):
				format(table.concat(dot_separated_group)))
		elseif part:find("^decllemma%s*:") or part:find("^declgender%s*:") or part:find("^declnumber%s*:") then
			local field, value = part:match("^(decl[a-z]+)%s*:%s*(.+)$")
			if not value then
				parse_err(("Syntax error in decllemma/declgender/declnumber indicator: '%s'"):format(part))
			end
			if base[field] then
				parse_err(("Can't specify '%s:' twice"):format(field))
			end
			base[field] = value
		elseif part:find("^q%s*:") or part:find("header%s*:") then
			local field, value = part:match("^(q)%s*:%s*(.+)$")
			if not value then
				field, value = part:match("^(header)%s*:%s*(.+)$")
			end
			if not value then
				parse_err(("Syntax error in q/header indicator: '%s'"):format(part))
			end
			if base[field] then
				parse_err(("Can't specify '%s:' twice"):format(field))
			end
			base[field] = value
		elseif part:find("^@") then
			if base.scrape_spec then
				parse_err("Can't specify scrape directive '@...' twice")
			end
			if part:find(":") then
				base.scrape_is_suffix, base.scrape_spec, base.scrape_id = part:match("^@(%-?)(.-)%s*:%s*(.+)$")
			else
				base.scrape_is_suffix, base.scrape_spec = part:match("^@(%-?)(.-)$")
			end
			-- If we saw a hyphen, set `scrape_is_suffix` to true, otherwise false
			base.scrape_is_suffix = base.scrape_is_suffix == "-"
			
			if not base.scrape_spec or base.scrape_spec == "" then
				parse_err(("Syntax error in scrape directive '%s"):format(part))
			end
			local scrape_init, scrape_rest = rmatch(base.scrape_spec, "^(.)(.*)$")
			local lower_scrape_init = ulower(scrape_init)
			if ulower(scrape_init) ~= scrape_init then
				base.scrape_is_uppercase = true
				base.scrape_spec = lower_scrape_init .. scrape_rest
			end
		elseif rfind(part, ":") then
			local spec, value = part:match("^([a-z]+)%s*:%s*(.+)$")
			if not spec then
				parse_err(("Syntax error in indicator with value, expecting alphabetic slot or stem/lemma override indicator: '%s'"):format(part))
			end
			if not overridable_stem_set[spec] then
				parse_err(("Unrecognized stem override indicator '%s', should be %s"):format(
					part, generate_list_of_possibilities_for_err(overridable_stems)))
			end
			if base[spec] then
				if spec == "stem" then
					parse_err("Can't specify spec for 'stem:' twice (including using 'stem:' along with # or ##)")
				else
					parse_err(("Can't specify '%s:' twice"):format(spec))
				end
			end
			base[spec] = value
		elseif part == "sg" or part == "pl" or part == "both" then
			if base.number then
				if base.number ~= part then
					parse_err("Can't specify '" .. part .. "' along with '" .. base.number .. "'")
				else
					parse_err("Can't specify '" .. part .. "' twice")
				end
			end
			base.number = part
		elseif part == "indef" or part == "def" or part == "bothdef" then
			if base.definiteness then
				if base.definiteness ~= part then
					parse_err(("Can't specify two conflicting definiteness values; saw '%s' (%s) when existing definiteness is %s"):
						format(part, definiteness_code_to_desc[part], definiteness_code_to_desc[base.definiteness]))
				else
					parse_err("Can't specify '" .. part .. "' twice")
				end
			end
			base.definiteness = part
		elseif part == "#" or part == "##" then
			if base.stem then
				parse_err("Can't specify a stem spec ('stem:', # or ##) twice")
			end
			base.stem = part
		elseif part == "+" then
			if base.props.adj then
				parse_err("Can't specify '+' twice")
			end
			base.props.adj = true
		elseif part == "proper" or part == "common" or part == "dem" or
			part == "weak" or part == "iending" or part == "rstem" or part == "já" or part == "pron" or
			part == "indecl" or part == "decl?" then
			if base.props[part] then
				parse_err("Can't specify '" .. part .. "' twice")
			end
			base.props[part] = true
		else
			parse_err("Unrecognized indicator '" .. part .. "'")
		end
	end

	return base
end


--[=[
Create an empty `base` object for holding the result of parsing and later the generated forms. The object is of the form

{
  overrides = {
	SLOT = OVERRIDE,
	SLOT = OVERRIDE,
	...
  }, -- where SLOT is the actual name of the slot, such as "ind_gen_s" (NOT the slot name as specified by the user,
		which would be just "gen" for "ind_gen_s") and OVERRIDE is
		{indef = {FORMOBJ, FORMOBJ, ...}, def = nil or false or {FORMOBJ, FORMOBJ, ...}}, where FORMOBJ is
		{form = FORM, footnotes = FOOTNOTES} as in the `forms` table ("-" means to suppress the slot entirely and is
		signaled by "--" as the form value; a value preceded by ! means it's a full form rather than an ending; in
		such forms you can use # to indicate the lemma and ## to indicate the lemma minus -ur or -r, as with stems);
		`indef` means the override(s) coming before a slash; `def` means the override(s) coming after a slash, or the
		overrides for definite slots, and `false` for either means that the user left the value before or after the
		slash completely blank, meaning not to override the indefinite or definite forms
  gens = nil or OVERRIDE, same form as OVERRIDE above
  pls = nil or OVERRIDE, same form as OVERRIDE above
  forms = {}, -- forms for a single spec alternant; see `forms` below
  props = {
	PROP = true,
	PROP = true,
    ...
  }, -- misc Boolean properties:
		* "dem" (a demonym, i.e. a capitalized noun such as [[Svisslendingur]] "Swiss person" that behaves like a
		  common noun);
		* "proper" (a lowercase noun that behaves like a proper noun, i.e. defaults to no plural or definite forms);
		* "rstem" (an r-stem like [[bróðir]] "brother" or [[dóttir]] "daughter");
		* "já" (a neuter in -é whose stem alternates with -já, such as [[tré]] "tree" and [[hné]]/[[kné]] "knee");
		* "weak" (the noun should decline like an ordinary weak noun; used in the declension of [[fjandi]] to disable
		  the special -ndi declension);
  number = "NUMBER", -- "sg", "pl", "both" or "none" (for certain pronouns); may be missing and if so is defaulted
  gender = "GENDER", -- "m", "f", "n" or "none" (for certain pronouns); always specified by the user
  definiteness = "DEFINITENESS", -- "def", "indef", "bothdef" or "none" (for pronouns); may be missing and if so is
									defaulted
  decllemma = nil or "DECLLEMMA", -- decline like the specified lemma
  declgender = nil or "DECLGENDER", -- decline like the specified gender
  declnumber = nil or "DECLNUMBER", -- decline like the specified number
  stem = nil or "STEM", -- override the stem; may have # (= lemma) or ## (= lemma minus -ur or -r)
  vstem = nil or "STEM", -- override the stem used before vowel-initial endings; same format as `stem`
  plstem = nil or "STEM", -- override the plural stem; same format as `stem`
  plvstem = nil or "STEM", -- override the plural stem used before vowel-initial endings; same format as `stem`
  footnotes = nil or {"FOOTNOTE", "FOOTNOTE", ...}, -- alternant-level footnotes, specified using `.[footnote]`, i.e.
													   a footnote by itself
  addnote_specs = {
	ADDNOTE_SPEC, ADDNOTE_SPEC, ...
  }, -- where ADDNOTE_SPEC is {slot_specs = {"SPEC", "SPEC", ...}, footnotes = {"FOOTNOTE", "FOOTNOTE", ...}}; SPEC is
		a Lua pattern matching slots (anchored on both sides) and FOOTNOTE is a footnote to add to those slots
  MUTATION_GROUP = {
	MUTATION_SPEC, MUTATION_SPEC, ...
  }, -- where MUTATION_GROUP is one of "umut", "imut", "unumut", "unimut", "con", "defcon", "j" or "v", and
		MUTATION_SPEC is {form = "FORM", footnotes = nil or {"FOOTNOTE", "FOOTNOTE", ...}, defaulted = BOOLEAN}, where
		FORM is as specified by the user (e.g. "uUmut", "-unumut") or set as a default by the code (in which case
		`defaulted` will be set to true for mutation groups "umut" and "unumut"); the mutation groups are as follows:
		umut (u-mutation), imut (i-mutation), unumut (reverse u-mutation), unimut (reverse i-mutation), con (stem
		contraction before vowel-initial endings), defcon (stem contraction before vowel-initial definite clitics when
		the ending itself is null), j (j-infix before vowel-initial endings not beginning with an i), v (v-infix before
		vowel-initial endings)

  -- The following additional fields are added by other functions:
  orig_lemma = "ORIGINAL-LEMMA", -- as given by the user or taken from pagename
  orig_lemma_no_links = "ORIGINAL-LEMMA-NO-LINKS", -- links removed
  lemma = "LEMMA", -- `orig_lemma_no_links`,
  forms = {
	SLOT = {
	  {
		form = "FORM",
		footnotes = nil or {"FOOTNOTE", "FOOTNOTE", ...},
	  },
	  ...
	},
	...
  },
}
]=]
local function create_base()
	return {
		forms = {},
		overrides = {},
		props = {},
		addnote_specs = {},
	}
end

-- Set some defaults (e.g. number and definiteness) now, because they (esp. the number) may be needed
-- below when determining how to merge scraped and user-specified properies.
local function set_early_base_defaults(base)
	if not base.props.adj and not base.props.pron then
		local function check_err(msg)
			error(("Lemma '%s': %s"):format(base.lemma, msg))
		end

		if not base.gender then
			check_err("Internal error: For nouns, gender must be specified")
		end
		base.number = base.number or is_proper_noun(base, base.lemma) and "sg" or base.gender == "m" and
			(base.lemma:find("skapur$") or base.lemma:find("naður$")) and not base.stem and "sg" or "both"
		base.definiteness = base.definiteness or is_proper_noun(base, base.lemma) and "indef" or "bothdef"
		process_declnumber(base)
		base.actual_gender = base.gender
		if base.declgender then
			if not base.declgender:find("^[mfn]$") then
				check_err(("Unrecognized gender '%s' for 'declgender:', should be 'm', 'f' or 'n'"):format(
					base.declgender))
			end
			base.gender = base.declgender
		end
	end
end

local function parse_inside_and_merge(inside, lemma, scrape_chain)
	local function parse_err(msg)
		error(msg .. ": <" .. inside .. ">")
	end

	if #scrape_chain >= 10 then
		local linked_scrape_chain = {}
		for _, element in ipairs(scrape_chain) do
			table.insert(linked_scrape_chain, "[[" .. element .. "]]")
		end
		parse_err(("Probable infinite loop in scraping; scrape chain is [[%s]] -> %s"):format(lemma,
			table.concat(linked_scrape_chain, " -> ")))
	end

	local base = create_base()
	base.lemma = lemma
	base.scrape_chain = scrape_chain
	parse_inside(base, inside, #scrape_chain > 0)

	if not base.scrape_spec then
		-- If we're not scraping the declension from another noun, just return the parsed `base`.
		-- But don't set early defaults if we're being scraped because it interferes with overriding the number
		-- and/or definiteness by the noun that is scraping us.
		if #scrape_chain == 0 then
			set_early_base_defaults(base)
		end
		return base
	else
		local prefix, base_noun, declspec
		prefix, base_noun, declspec = com.find_scraped_decl {
			lemma = lemma,
			scrape_spec = base.scrape_spec,
			scrape_is_suffix = base.scrape_is_suffix,
			scrape_is_uppercase = base.scrape_is_uppercase,
			infltemp = "is-ndecl",
			allow_empty_infl = false,
			inflid = base.scrape_id,
			parse_off_ending = parse_off_final_nom_ending,
		}
		if type(declspec) == "string" then
			base.prefix = prefix
			base.base_noun = base_noun
			base.scrape_error = declspec
			return base
		end

		-- Parse the inside spec from the scraped noun (merging any sub-scraping specs), and copy over the
		-- user-specified properties on top of it.
		table.insert(scrape_chain, base_noun)
		local inner_base = parse_inside_and_merge(declspec.decl, base_noun, scrape_chain)
		inner_base.lemma = lemma
		inner_base.prefix = prefix
		inner_base.base_noun = base_noun

		-- Add `prefix` to a full variant of the base noun (e.g. a stem spec or full override). We may need
		-- to adjust the variant to take into account the base noun being a suffix and/or uppercase (e.g. when
		-- we use [[-dómur]] to generate the inflection of [[vísdómur]] or [[Björn]] to generate the inflection
		-- of [[Ásbjörn]]).
		local function add_prefix(form)
			if base.scrape_is_suffix then
				form = form:gsub("^%-", "")
			end
			if base.scrape_is_uppercase then
				local first, rest = rmatch(form, "^(.)(.*)$")
				if first then
					form = ulower(first) .. rest
				end
			end
			return prefix .. form
		end

		-- If there's a prefix, add it now to all the full overrides in the scraped noun, as well as 'decllemma'
		-- and all stem overrides.
		if prefix ~= "" then
			map_all_overrides(inner_base, function(formobj)
				-- Not if the override contains # or ##, which expand to the full lemma (possibly minus -r
				-- or -ur).
				if formobj.form:find("^!") and not formobj.form:find("#") then
					formobj.form = "!" .. add_prefix(usub(formobj.form, 2))
				end
			end)
			if inner_base.decllemma then
				inner_base.decllemma = add_prefix(inner_base.decllemma)
			end
			for _, stem in ipairs(overridable_stems) do
				-- Only actual stems, not imutval; and not if the stem contains # or ##, which
				-- expand to the full lemma (possibly minus -r or -ur).
				if inner_base[stem] and stem:find("stem$") and not inner_base[stem]:find("#") then
					inner_base[stem] = add_prefix(inner_base[stem])
				end
			end
		end

		local function copy_properties(plist)
			-- Copy various properties.
			for _, prop in ipairs(plist) do
				if base[prop] ~= nil then
					inner_base[prop] = base[prop]
				end
			end
		end
		copy_properties(mutation_specs)
		copy_properties(overridable_stems)
		copy_properties { "gens", "pls", "gender", "number", "definiteness", "decllemma", "declgender", "declnumber",
			"q", "header" }
		inner_base.footnotes = iut.combine_footnotes(inner_base.footnotes, base.footnotes)
		-- Copy addnote specs.
		for _, prop_list in ipairs { "addnote_specs" } do
			for _, prop in ipairs(base[prop_list]) do
				m_table.insertIfNot(inner_base[prop_list], prop)
			end
		end
		-- Now copy remaining user-specified specs into the scraped noun `base`.
		for _, prop_table in ipairs { "overrides", "props" } do
			for slot, prop in pairs(base[prop_table]) do
				inner_base[prop_table][slot] = prop
			end
		end
		-- Now determine the defaulted number and definiteness (after copying relevant settings
		-- but before the check just below that relies on `inner_base.number` being set).
		set_early_base_defaults(inner_base)
		-- If user specified 'sg', cancel out any pl overrides, otherwise we'll get an error.
		if inner_base.number == "sg" then
			inner_base.pls = nil
			for slot, _ in pairs(inner_base.overrides) do
				if slot:find("_p$") then
					inner_base.overrides[slot] = nil
				end
			end
		end
		return inner_base
	end
end


--[=[
Parse an indicator spec (text consisting of angle brackets and zero or more dot-separated indicators within them).
Return value is an object of the form indicated in the comment above create_base().
]=]
local function parse_indicator_spec(angle_bracket_spec, lemma, pagename)
	if lemma == "" then
		lemma = pagename
	end
	local inside = rmatch(angle_bracket_spec, "^<(.*)>$")
	assert(inside)
	local orig_lemma = lemma
	local orig_lemma_no_links = m_links.remove_links(lemma)
	lemma = orig_lemma_no_links
	local base = parse_inside_and_merge(inside, lemma, {})
	base.orig_lemma = orig_lemma
	base.orig_lemma_no_links = orig_lemma_no_links
	return base
end

local function set_defaults_and_check_bad_indicators(base)
	local function check_err(msg)
		error(("Lemma '%s': %s"):format(base.lemma, msg))
	end
	-- Set default values.
	local regular_noun = is_regular_noun(base)
	if base.props.pron then
		set_pron_defaults(base)
	elseif base.props.adj then
		-- FIXME: Do adjective-specific checks then return
	elseif not base.props.adj then
		-- FIXME: Do something?
	end

	if not regular_noun then
		for _, mutation_spec in ipairs(mutation_specs) do
			if base[mutation_spec] then
				-- FIXME, maybe with adjectives
				check_err(("'%s' can only be specified with regular nouns"):format(mutation_spec))
			end
		end
		if base.declgender then
			check_err("'declgender' can only be specified with regular nouns")
		end
		return
	end

	-- Check for bad indicator combinations.
	if base.imut and base.unimut then
		check_err("'imut' and 'unimut' specs cannot be specified together")
	end
	if base.umut and base.unumut then
		check_err("'umut' and 'unumut' specs cannot be specified together")
	end
	if base.unimut and base.unumut then
		check_err("'unimut' and 'unumut' specs cannot be specified together")
	end

	if base.declnumber == "pl" and (base.gens or base.pls) then
		check_err("Cannot set genitive or plural specs after the gender in plural-only lemmas")
	end

	if base.plvstem and not base.plstem then
		check_err("When 'plvstem:' given, 'plstem:' must also be given")
	end

	-- Compute whether i-mutation stems are needed.
	
	-- First check for 'imut' set by user.
	if not base.need_imut then -- might be set by the detected declension
		if base.imut then
			for _, formobj in ipairs(base.imut) do
				if formobj.form == "imut" then
					base.need_imut = true
					break
				end
			end
		end
	end

	-- Then check for 'unimut' set by user.
	if not base.need_imut then
		if base.unimut then
			for _, formobj in ipairs(base.unimut) do
				if formobj.form == "unimut" then
					base.need_imut = true
					break
				end
			end
		end
	end

	-- Then check all overrides for any beginning with a single ^.
	if not base.need_imut then
		map_all_overrides(base, function(formobj)
			if formobj.form:find("^%^") and not formobj.form:find("^%^%^") then
				base.need_imut = true
				return true
			end
		end)
	end

	if base.imutval and not base.need_imut then
		check_err("'imutval:...' specified but 'imut' and 'unimut' not specified and no forms need i-mutation")
	end
end


local function set_all_defaults_and_check_bad_indicators(alternant_multiword_spec)
	local is_multiword = #alternant_multiword_spec.alternant_or_word_specs > 1
	iut.map_word_specs(alternant_multiword_spec, function(base)
		set_defaults_and_check_bad_indicators(base)
		for _, global_prop in ipairs { "q", "header" } do
			if base[global_prop] then
				if alternant_multiword_spec[global_prop] == nil then
					alternant_multiword_spec[global_prop] = base[global_prop]
				elseif alternant_multiword_spec[global_prop] ~= base[global_prop] then
					error(("With multiple words or alternants, set '%s' on only one of them or make them all agree"):
						format(global_prop))
				end
			end
		end
		if base.props.pron then
			alternant_multiword_spec.saw_pron = true
		else
			alternant_multiword_spec.saw_non_pron = true
		end
		if base.props.indecl then
			alternant_multiword_spec.saw_indecl = true
		else
			alternant_multiword_spec.saw_non_indecl = true
		end
		if base.props["decl?"] then
			alternant_multiword_spec.saw_unknown_decl = true
		else
			alternant_multiword_spec.saw_non_unknown_decl = true
		end
	end)
end


local function expand_property_sets(base)
	base.prop_sets = {{}}

	-- Construct the prop sets from all combinations of mutation specs, in case any given spec has more than one
	-- possibility.
	for _, mutation_spec in ipairs(mutation_specs) do
		local specvals = base[mutation_spec]
		-- Handle unspecified mutation specs.
		if not specvals then
			specvals = {false}
		end
		if #specvals == 1 then
			for _, prop_set in ipairs(base.prop_sets) do
				-- Convert 'false' back to nil
				prop_set[mutation_spec] = specvals[1] or nil
			end
		else
			local new_prop_sets = {}
			for _, prop_set in ipairs(base.prop_sets) do
				for _, specval in ipairs(specvals) do
					local new_prop_set = m_table.shallowcopy(prop_set)
					new_prop_set[mutation_spec] = specval
					table.insert(new_prop_sets, new_prop_set)
				end
			end
			base.prop_sets = new_prop_sets
		end
	end
end


-- For a plural-only lemma, synthesize a likely singular lemma. It doesn't have to be theoretically correct as long as
-- it generates all the correct plural forms.
local function synthesize_singular_lemma(base)
	local lemma_determined

	-- Loop over all property sets in case the user specified multiple ones (e.g. using different mutation specs). If
	-- we try to reconstruct different lemmas for different property sets, we'll throw an error below.
	for _, props in ipairs(base.prop_sets) do
		local function interr(msg)
			error(("Internal error: For lemma '%s', %s: %s"):format(base.lemma, msg, dump(props)))
		end

		-- `ending` refers to the plural ending but is not currently used much. Instead, in add_decl(), when we process
		-- pl-only terms, we set the nom_pl to "*" so that the lemma is used directly.
		local stem, lemma, ending, sg_ending, default_unumut
		if base.gender == "m" or base.gender == "f" then
			stem, ending = rmatch(base.lemma, "^(.*)([aiu]r)$")
			if stem then
				-- masc:
				--
				-- [[tónkeikar]] "concert"; [[feðgar]] "father and son"; [[hafrar]] "oats" (dat pl höfrum);
				-- [[fjármunir]] "goods, property"; [[Fljótsdælir]] "inhabitants of Fljótsdalur (a valley)"
				-- (occurs definite, needs 'dem', no unimut); [[Ásmegir]] "sons of the Gods" (occurs definite, dat
				-- pl Ásmögum, gen pl Ásmaga, i.e. needs 'def' and 'unimut'); similarly [[ljóðmegir]];
				-- [[buskuleggir]] "?" (has 'j' in dat pl [[buskuleggjum]], gen pl [[buskuleggja]]; [[Bekkir]]
				-- (place name; has 'j' in dat pl [[Bekkjum]], gen pl [[Bekkja]])
				--
				-- fem:
				-- [[frönskur]] "French fries" (with unumut); [[hjólbörur]] "wheelbarrow" (with unumut); [[buxur]]
				-- "trousers, pants", [[hættur]] "bedtime; quitting time" (with unimut); [[herðar]] "shoulders";
				-- [[limar]] "branches"; [[öfgar]] "exaggeration, extreme" (no unumut); [[drefjar]]
				-- "stains, traces"; [[viðjar]] "chains, fetters"; many others in -jar, but the -j- is throughout
				-- the plural; [[svalir]] "balcony; porch"; [[dyr]] "doorway" (uses decllemma:dyrir)
				if ending == "ur" then
					default_unumut = "unumut"
				end
				sg_ending = "ur"
			elseif base.lemma:find("ær$") then
				-- [[barnatær]], [[fultær]], proper name [[Tær]]
				stem = base.lemma
				sg_ending = ""
			else
				error(("Masculine or feminine plural-only lemma '%s' should end in -ar, -ir or -ur"):format(base.lemma))
			end
		elseif base.gender == "n" then
			-- Neuters in -i. Examples: [[fræði]] "branch of knowledge", [[jafndægri]] "equinox", [[meðmæli]]
			-- "recommendation", [[sannindi]] "truth", [[skæri]] "pair of scissors", [[vísindi]] "knowedge, learning".
			-- unimut is possible and occurs in [[læti]] "behavior, demeanor", [[ólæti]] "noise, racket".
			stem, ending = rmatch(base.lemma, "^(.*[^eE])(i)$")
			if stem then
				sg_ending = "i"
			end
			if not stem then
				-- Weak neuters in -u like [[gleraugu]] "glasses/spectacles".
				stem, ending = rmatch(base.lemma, "^(.*[^aA])(u)$")
				if stem then
					sg_ending = "a"
					default_unumut = "unumut"
				end
			end
			if not stem then
				-- Generally, plural will look like singular, with no ending in the plural (but there will be umut
				-- if possible). Examples: [[feðgin]] "father and daughter", [[hjón]] "married couple", [[jól]]
				-- "Christmas", [[lok]] "end"; [[jarðgöng]] "tunnel" needing 'unumut'.
				stem = base.lemma
				sg_ending = ""
				default_unumut = "unumut"
			end
		else
			interr(("unrecognized gender '%s'"):format(base.gender))
		end
		if default_unumut and not props.unumut and not props.umut and not props.unimut then
			props.unumut = {form = default_unumut, defaulted = true}
		end
		if props.unumut and props.unimut then
			interr("shouldn't see both 'unumut' and 'unimut' set in plural-only lemma")
		end
		if props.unumut and props.unumut.form:find("^un") then
			stem = com.apply_reverse_u_mutation(stem, props.unumut.form, not props.unumut.defaulted)
			if props.umut then
				interr("shouldn't see both 'unumut' and 'umut' set in plural-only lemma")
			end
			props.umut = {form = rsub(props.unumut.form, "^un", ""), footnotes = props.unumut.footnotes,
				defaulted = props.unumut.defaulted}
			props.unumut = nil
		end
		if props.unimut and props.unimut.form:find("^un") then
			stem = com.apply_reverse_i_mutation(stem, base.imutval)
			if props.imut then
				interr("shouldn't see both 'unimut' and 'imut' set in plural-only lemma")
			end
			props.imut = {form = rsub(props.unimut.form, "^un", ""), footnotes = props.unimut.footnotes}
			props.unimut = nil
		end
		lemma = stem .. sg_ending
		if lemma_determined and lemma_determined ~= lemma then
			error(("Attempt to set two different singular lemmas '%s' and '%s'"):format(lemma_determined, lemma))
		end
		lemma_determined = lemma
	end
	base.lemma = lemma_determined
	base.lemma_ending = ending or ""
end


-- For a nominative definite lemma, synthesize the corresponding indefinite lemma. Note that a plural definite lemma may
-- need to be processed twice, first to convert to plural indefinite and then to convert to singular indefinite using
-- synthesize_singular_lemma().
local function synthesize_indefinite_lemma(base)
	local lemma_determined

	-- Loop over all property sets in case the user specified multiple ones (e.g. using different mutation specs). If
	-- we try to reconstruct different lemmas for different property sets, we'll throw an error below.
	for _, props in ipairs(base.prop_sets) do
		local function interr(msg)
			error(("Internal error: For lemma '%s', %s: %s"):format(base.lemma, msg, dump(props)))
		end

		-- There are only 6 clitic articles, depending on the combination of gender and number:
		-- singular: m = -inn, f = -in, n = -ið; plural: m = -nir, f = -nar, n = -in. The two beginning in n- aren't
		-- problematic because in all cases they simply append to the actual form. The remaining four, however, drop
		-- the i- before an ending [aiu]. This means we can uniquely reconstruct the dropped vowel if we see e.g.
		-- -að or -uð in place of -ið. But if we see -ið, we don't know whether the lemma ended in -i or a consonant.
		-- And in general it's important to know because it affects some forms; e.g. compare definite neuter 'knippið'
		-- from [[knippi]] "bundle, bunch" with 'klappið' from [[klapp]] "applause; pat, stroke". The former has
		-- definite genitive 'knippisins' and the latter 'klappsins'. And in fact, all three genders commonly have
		-- both consonant-ending and i-ending nouns in the singular. This means we need an indicator to distinguish
		-- them. Probably easiest is 'iending'; reusing 'weak' won't work so well because neuters in -i, and sometimes
		-- feminines in -i, are considered strong.

		local function process_n_clitic(clitic)
			local lemma = base.lemma:match("^(.*)" .. clitic .. "$")
			if not lemma then
				error(("Lemma '%s' declared as %s %s should end in clitic '-%s'"):format(base.lemma,
					gender_code_to_desc[base.gender] or "NONE", number_code_to_desc[base.number] or "NONE",
					clitic))
			end
			return lemma
		end

		local function process_i_clitic(clitic)
			local clitic_cons_end = clitic:match("^i(.*)$")
			if not clitic_cons_end then
				interr(("clitic '%s' should begin with 'i'"):format(clitic))
			end
			local lemma_begin, ending = base.lemma:match("^(.*)([aiu])" .. clitic_cons_end .. "$")
			if not lemma_begin then
				error(("Lemma '%s' declared as %s %s should end in clitic '-%s' or in '-a%s' or '-u%s'"):format(
					base.lemma, gender_code_to_desc[base.gender] or "NONE", number_code_to_desc[base.number] or "NONE",
					clitic, clitic_cons_end, clitic_cons_end))
			end
			if ending == "a" or ending == "u" then
				if base.props.iending then
					error(("Property 'iending' cannot be specified because definite lemma '%s' does not end in '-%s'"):
						format(base.lemma, clitic))
				end
				return lemma_begin .. ending
			end
			if base.props.iending then
				return lemma_begin .. "i"
			else
				return lemma_begin
			end
		end

		local clitic = clitic_articles[base.gender]["nom_" .. (base.number == "pl" and "p" or "s")]
		local lemma
		if clitic:find("^n") then
			lemma = process_n_clitic(clitic)
		else
			lemma = process_i_clitic(clitic)
		end
		if lemma_determined and lemma_determined ~= lemma then
			error(("Attempt to set two different indefinite lemmas '%s' and '%s'"):format(lemma_determined, lemma))
		end
		lemma_determined = lemma
	end
	base.lemma = lemma_determined
	base.lemma_ending = ""
end

-- For an adjectival lemma, synthesize the masc singular form.
local function synthesize_adj_lemma(base)
	-- FIXME: Add support for strong adjectives.
	local stem, ending
	if base.props.indecl then
		base.decl = "indecl"
		stem = base.lemma
	elseif base.props["decl?"] then
		base.decl = "decl?"
		stem = base.lemma
	else
		if base.number == "pl" then
			stem, ending = rmatch(base.lemma, "^(.*[^Aa])(u)$")
			if stem then
				base.props.weak = true
				base.lemma = stem .. "ur"
				if not stem then
					error("No support for strong adjectives yet")
				end
			end
		else
			if base.gender == "m" then
				stem, ending = rmatch(base.lemma, "^(.*[^Ee])(i)$")
				if stem then
					base.props.weak = true
					base.lemma = stem .. "ur"
				end
				if not stem then
					error("No support for strong adjectives yet")
				end
			elseif base.gender == "f" or base.gender == "n" then
				stem, ending = rmatch(base.lemma, "^(.*)(a)$")
				if stem then
					base.props.weak = true
					base.lemma = stem .. "ur"
				end
				if not stem then
					error("No support for strong adjectives yet")
				end
			end
		end
		base.decl = "adj"
	end
	if base.stem then
		-- This isn't necessarily accurate but doesn't really matter. We only record the lemma ending to help with
		-- contraction of definite clitics in the nominative singular, which doesn't apply for adjectives.
		base.lemma_ending = ""
	else
		base.stem = stem
		base.lemma_ending = ending or ""
	end
end


-- Determine the declension based on the lemma, gender and number. The declension is set in base.decl.
local function determine_declension(base)
	local stem, ending
	local default_props = {}
	-- Determine declension
	if base.props.indecl then
		base.decl = "indecl"
		stem = base.lemma
	elseif base.props["decl?"] then
		base.decl = "decl?"
		stem = base.lemma
	elseif base.gender == "m" then
		if not stem then
			stem, ending = rmatch(base.lemma, "^(.*[ÁáÆæÝý])(r)$")
			if stem then
				-- in -ár:
				-- [[nár]] "corpse", [[sár]] "tub (archaic)", [[hár]] "thole, oarlock (archaic)", [[hár]]
				-- "spiny dogfish (archaic)" (with v-infix), [[kljár]] "weaving stone (archaic)", [[ljár]] "scythe",
				-- [[skjár]] "video screen, display", [[már]] "seagull", [[sjár]] "sea", [[snjár]] "snow" (with
				-- v-infix); vs. stems ending in -r: [[ár]] "? (archaic)", [[lár]] "wooden box for wool", [[klár]]
				-- "inferior horse, nag", [[pílár]] "slat, fence post; spoke (dated)", [[kentár]] "centaur"
				--
				-- in -ær:
				-- [[glær]] "sea", [[skær]] "? (obsolete)", [[blær]] "gentle breeze", [[bær]] "farm; town", [[óbær]]
				-- "?", [[sær]] "sea", [[snær]] "snow"
				--
				-- in -ýr:
				-- [[ýr]] "yew", [[býr]] "town, farm", [[gnýr]] "clash, rumble; blue wildebeest", [[týr]] "hero; god",
				-- also many proper names; vs. stems ending in -r: [[fýr]] "dude, guy", [[lýr]] "pollock", [[sýr]]
				-- "? (poetic)", [[ýr]] "? (obsolete)", [[hlýr]] "? (obsolete)", [[glýr]] "? (obsolete)"
				base.decl = "m"
			end
		end
		if not stem then
			stem = rmatch(base.lemma, "^(.*[Aa]ur)$")
			if stem then
				-- [[maur]] "ant", [[aur]] "loam, mud", [[gaur]] "ruffian", [[paur]] "devil; enmity",
				-- [[saur]] "dirt; excrement", [[staur]] "post", [[ljósastaur]] "lamp post"
				base.decl = "m"
			end
		end
		if not stem then
			-- There must be at least one vowel; lemmas like [[bur]] don't count.
			stem, ending = rmatch(base.lemma, "^(.*" .. com.vowel_or_hyphen_c .. ".*)(ur)$")
			if stem then
				if stem:find("skap$") and not base.stem then
					-- tons of words in -skapur
					base.decl = "m-skapur"
				elseif stem:find("nað$") and not base.stem then
					-- lots of words in -naður
					base.decl = "m-naður"
					default_props.umut = "uUmut"
				else
					if base.stem == base.lemma then
						-- [[akur]] "field" etc. where the stem includes the final -r
						stem = base.stem
						ending = "" -- not actually used
						default_props.con = "con"
					end
					-- [[hestur]] "horse" and lots of others
					base.decl = "m"
				end
			end
		end
		if not stem then
			stem = rmatch(base.lemma, "^(.*[Ee][iy]r)$")
			if stem then
				-- in -eir (all include -r in the stem):
				-- [[geir]] "?", [[eir]] "copper", [[leir]] "clay", [[Geir]] (male given name)
				--
				-- in -eyr, including -r in the stem:
				-- [[reyr]] "reed", [[Reyr]] (male given name)
				-- in -eyr, not including -r in the stem:
				-- [[þeyr]] "thaw, thawing wind", [[Þeyr]] (male given name), [[Freyr]] (male given name)
				base.decl = "m"
			end
		end
		if not stem then
			-- There must be at least one vowel (although there don't appear to be any single-syllable
			-- lemmas ending in -ir other than in -eir).
			stem, ending = rmatch(base.lemma, "^(.*" .. com.vowel_or_hyphen_c .. ".*)(ir)$")
			if stem then
				-- [[læknir]] "physician" and many others
				-- [[bróðir]], [[faðir]] are r-stems
				if base.props.rstem then
					base.decl = "m-rstem"
					base.need_imut = true
				else
					base.decl = "m-ir"
				end
			end
		end
		if not stem then
			stem, ending = rmatch(base.lemma, "^(.*l)(l)$")
			if stem then
				if is_proper_noun(base, stem) and stem:find("kel$") then
					base.decl = "m-kell"
				else
					if not base.stem and (rfind(stem, com.cons_c .. "[aiu]l$") or stem:find("^[aiuAIU]l$")) then
						-- [[gaffall]] "fork" (dat pl [[göfflum]]), [[þumall]] "thumb"; [[ekkill]] "widower";
						-- [[spegill]] "mirror"; [[segull]] "magnet"; [[öxull]] "axis; axle"; etc. Note that the check
						-- for a consonant preceding the a/i/u is important as there are words like [[manúall]]
						-- "manual", [[ritúall]] "ritual", [[kokteill]] "cocktail", [[feill]] "flaw, error", [[deill]]
						-- "dispute???" (rare, regional), [[haull]] "hernia", [[straull]] "? (rare, regional)" that
						-- don't have contraction. Beware of the rare word [[síill]] "sieve? strainer?" that per BÍN
						-- does contract to síl- before vowels. Currently the code to handle contraction will throw an
						-- error if you attempt to contract that word, but you can use 'vstem:...'. 
						--
						-- There are also lots of words in a vowel other than a/i/u followed by -ll, such as [[bíll]]
						-- "car", [[áll]] "eel", [[konsúll]] "consul", [[þræll]] "slave", [[hvoll]] "hill", [[stóll]]
						-- "chair", etc. In these, the final -l is the nominative singular ending, as above.
						--
						-- Note that if the user overrode the stem (e.g. using '#' as with [[Ármann]]), we don't
						-- default to contraction as it may cause an error to be thrown.
						default_props.con = "con"
					end
					base.decl = "m"
				end
			end
		end
		if not stem then
			stem, ending = rmatch(base.lemma, "^(.*n)(n)$")
			if stem then
				if not base.stem and (rfind(stem, com.cons_c .. "[aiu]n$") or stem:find("^[aiuAIU]n$")) then
					-- As with -all/-ill/-ull although there are fewer such words in -nn. Examples: [[aftann]] "evening"
					-- (dat pl öftnum), [[arinn]] "hearth, fireplace" (dat pl örnum), [[drottinn]] "lord", [[himinn]]
					-- "sky, heaven", [[morgunn]] "morning", [[jötunn]] "giant", etc.
					--
					-- There are also lots of words in a vowel other than a/i/u followed by -nn, such as [[fleinn]]
					-- "spear", [[steinn]] "rock", [[prjónn]] "knitting needle", [[daunn]] "stink", [[húnn]] "knob".
					-- In these, the final -n is the nominative singular ending, as above.
					--
					-- Note that if the user overrode the stem (e.g. using '#' as with [[Ármann]]), we don't default
					-- to contraction as it may cause an error to be thrown.
					default_props.con = "con"
				end
				base.decl = "m"
			end
		end
		if not stem and not base.props.weak then
			stem, ending = rmatch(base.lemma, "^(.*[aóæ]nd)(i)$")
			if stem then
				-- [[nemandi]] "student" and many others; terms in -jandi like [[byrjandi]]
				-- "beginner", [[seljandi]] "seller" umlaut to -jend- in the plural instead of -ind-
				-- also terms in -óndi (probably all compounds of [[bóndi]] "farmer") and in -ændi
				-- (probably all compounds of [[frændi]]). Terms like [[andi]] "breath, spirit" and
				-- [[heiðasandi]] "heath sand?" need '.weak' to disable this, as does [[fjandi]] in
				-- the meaning "devil, demon" (vs. "enemy", which has plural [[fjendur]]). Terms like
				-- [[vandi]] "trouble; responsibility; custom, habit" and compounds are singular-only.
				base.decl = "m-ndi"
				if not stem:find("ænd$") then
					base.need_imut = true
				end
				if stem:find("jand$") then
					default_props.imutval = "je"
				end
			end
		end
		if not stem then
			stem, ending = rmatch(base.lemma, "^(.*)([ia])$")
			if stem then
				-- [[tími]] "time, hour" and many others; [[herra]] "gentleman" ([[sendiherra]] "ambassador"),
				-- [[séra]]/[[síra]] "reverend"
				base.decl = "m-weak"
				-- Recognize -ingi and make automatically j-infixing, but only when a vowel precedes
				-- (not [[ingi]], [[Ingi]], [[stingi]], [[þvingi]]). Use `-j` to turn this off.
				if ending == "i" and rfind(stem, com.vowel_or_hyphen_c .. ".*ing$") then
					default_props.j = "j"
				elseif ending == "i" and rfind(stem, com.vowel_or_hyphen_c .. ".*ar$") then
					default_props.umut = "uUmut"
				end
			end
		end
		if not stem then
			stem = rmatch(base.lemma, "^(.*ó)$")
			if stem then
				-- [[kanó]] "canoe", [[pesó]] "peso", [[Plútó]] "Pluto", [[Markó]] (male given name), etc.
				base.decl = "m-ó"
			end
		end
		if not stem then
			-- Miscellaneous masculine terms without ending
			stem = base.lemma
			base.decl = "m"
		end
	elseif base.gender == "f" then
		if not stem then
			stem, ending = rmatch(base.lemma, "^(.*)(a)$")
			if stem then
				base.decl = "f-weak"
			end
		end
		if not stem then
			stem, ending = rmatch(base.lemma, "^(.*[^eE])(i)$")
			if stem then
				base.decl = "f-i"
			end
		end
		if not stem and not base.stem then
			-- Don't match when base.stem is set, e.g. [[gimbur]] "female lamb", where the -ur is part of the stem
			stem, ending = rmatch(base.lemma, "^(.*[^aA])(ur)$")
			if stem and rfind(stem, com.vowel_or_hyphen_c) then
				if is_proper_noun(base, stem) then
					-- [[Auður]], [[Heiður]], [[Ingveldur]], [[Móeiður]], [[Þórelfur]], [[-frídur]] ([[Gunnfríður]],
					-- [[Hólmfríður]], [[Málfríður]], [[Sigfríður]]), [[Gerður]] ([[Hallgerður]], [[Ingigerður]],
					-- [[Þorgerður]]), [[Gunnur]] ([[Arngunnur]], [[Hildigunnur]]), [[Heiður]] ([[Aðalheiður]],
					-- [[Arnheiður]], [[Brynheiður]], [[Ragnheiður]]), [[Hildur]] ([[Ásthildur]], [[Berghildur]],
					-- [[Brynhildur]], [[Geirhildur]], [[Gunnhildur]], [[Ragnhildur]], [[Þórhildur]]), [[Ástríður]]
					-- (related names [[Guðríður]], [[Sigríður]], [[Þuríður]]), [[Þrúður]] [also a man's name]
					-- ([[Jarþrúður]], [[Jarðþrúður]], [[Sigþrúður]])
					--
					-- also with company/organization names like [[Berghildur]], [[Gunnhildur]]; likewise place names
					-- like [[Þuríður]]
					base.decl = "f-acc-dat-i"
				else
					base.decl = "f-ur"
				end
			end
		end
		if not stem and base.props.rstem then
			stem, ending = rmatch(base.lemma, "^(.*[^eE])(ir)$")
			if stem and base.props.rstem then
				-- [[dóttir]], [[móðir]], [[systir]]
				base.decl = "f-rstem"
				if not stem:find("syst$") then
					base.need_imut = true
				end
			end
		end
		if not stem then
			stem = rmatch(base.lemma, "^(.*ung)$")
			if stem then
				base.decl = "f-ung"
			end
		end
		if not stem then
			stem = rmatch(base.lemma, "^(.*ing)$")
			if stem then
				base.decl = "f-ing"
			end
		end
		if not stem then
			stem = rmatch(base.lemma, "^(.*[áóúÁÓÚ])$")
			if stem then
				base.decl = "f-long-vowel"
				if rfind(stem, "[óÓ]$") then
					base.need_imut = true
				end
			end
		end
		if not stem and not base.stem then
			-- Not when base.stem is set, which includes [[Ýr]], following the regular endingless f declension where
			-- -r is part of the stem.
			stem, ending = rmatch(base.lemma, "^(.*[ýÝæÆ])(r)$")
			if stem then
				-- [[kýr]] "cow", [[sýr]] "sow (archaic)", [[ær]] "ewe" and compounds
				base.decl = "f-long-umlaut-vowel-r"
				default_props.unimut = "unimut"
			end
		end
		if not stem then
			stem = rmatch(base.lemma, "^(.*[^aA]un)$")
			if stem and rfind(stem, com.vowel_or_hyphen_c) then
				-- [[pöntun]] "order (in commerce)"; [[verslun]] "trade, business; store, shop"; [[efun]] "doubt";
				-- [[bötun]] "improvement"; [[örvun]] "encouragement; stimulation" (pl. örvanir); etc.
				-- Exclude words in -aun like [[baun]] "bean", [[laun]] "secret", [[raun]] "experience".
				-- Some words need a different indicator, e.g. [[örvun]] "encouragement; stimulation" (pl. örvanir),
				-- [[fjölgun]] "increase, proliferation" (pl. fjölganir), which need "unUmut".
				base.decl = "f"
				default_props.unumut = "unuUmut"
			end
		end
		if not stem then
			-- Miscellaneous feminine terms without ending
			stem = base.lemma
			base.decl = "f"
			-- A function here means we resolve it to its actual value later. We don't want to trigger
			-- unumut if the user specified v-infix or any type of u-mutation (e.g. 'uUmut' in [[ætlan]]),
			-- or if the last vowel of the term is 'a' ([[dragt]], [[aukavakt]]).
			default_props.unumut = function(base, props)
				if base.vstem or props.v and props.v.form == "v" or props.umut or
					rfind(stem, "[Aa]" .. com.cons_c .. "*$") then
					return nil
				else
					return {form = "unumut", defaulted = true}
				end
			end
		end
	elseif base.gender == "n" then
		if not stem then
			stem, ending = rmatch(base.lemma, "^(.*)(a)$")
			if stem then
				base.decl = "n-weak"
			end
		end
		if not stem then
			-- stem actually includes -é but due to the change to já we include it in the ending
			stem, ending = rmatch(base.lemma, "^(.*)(é)$")
			if stem then
				if base.props["já"] then
					-- Indicator 'já' for [[tré]], [[hné]]/[[kné]], etc.
					base.decl = "n-já"
				else
					-- [[té]] (letter T), etc.
					stem = stem .. "é"
					base.decl = "n"
				end
			end
		end
		if not stem then
			stem, ending = rmatch(base.lemma, "^(.*[kKgG])(i)$")
			if stem then
				base.decl = "n-i"
				default_props.j = "j"
			end
		end
		if not stem then
			stem, ending = rmatch(base.lemma, "^(.*[^eE])(i)$")
			if stem then
				base.decl = "n-i"
			end
		end
		if not stem then
			-- -ur preceded by a consonant and at least one vowel.
			stem = rmatch(base.lemma, "^(.*" .. com.vowel_or_hyphen_c .. ".*" .. com.cons_c .. "ur)$")
			if stem then
				base.decl = "n"
				default_props.con = "con"
				default_props.defcon = "defcon"
			end
		end
		if not stem then
			-- Miscellaneous neuter terms without ending
			stem = base.lemma
			base.decl = "n"
		end
	else
		error(("Internal error: `base.gender` is '%s' but should be 'm', 'f' or 'n'"):dump(base.gender))
	end
	if base.stem then
		-- This isn't necessarily accurate but doesn't really matter. We only record the lemma ending to help with
		-- contraction of definite clitics in the nominative singular, and in the cases where the user gives an explicit
		-- stem, it's usually with # (meaning the ending is null) or ## (meaning the ending ends in -r), and in both
		-- cases there's no contraction of initial vowels in definite clitics in any case.
		base.lemma_ending = ""
	else
		base.stem = stem
		base.lemma_ending = ending or ""
	end
	for k, v in pairs(default_props) do
		if not base[k] then
			if mutation_spec_set[k] then
				for _, props in ipairs(base.prop_sets) do
					if type(v) == "function" then
						props[k] = v(base, props)
					else
						props[k] = {form = v, defaulted = true}
					end
				end
			else
				base[k] = v
			end
		end
	end
	track("decl/" .. base.decl)
end


local function determine_default_masc_dat_sg(base, props)
	-- We only need to compute the default dative singular for regular masculines (not masculines in -ir, -ó, -i, etc.).
	-- These other types have specific defaults for the entire type.
	if base.decl ~= "m" or base.number == "pl" then
		return
	end
	local default_dat_sg
	if base.overrides.dat_s then
		-- Track explicit override.
		track("masc-dat-sg-override")
	end
	local stem = base.stem
	if props.j and props.j.form == "j" then
		-- Stems with j-infix normally have null dative even if they end in two consonants, e.g.
		-- [[belgur]] "bellows; skin", [[fengur]] "profit", [[flekkur]] "spot, fleck", [[serkur]]
		-- "shirt", [[stingur]] "sting"
		default_dat_sg = ""
	elseif stem:find(com.vowel_or_hyphen_c .. ".*[iu]ng$") then
		-- Stems in suffix -ing or -ung normally have indef dat -i, def dat null
		default_dat_sg = {indef = "i", def = ""}
	elseif stem:find("x$") or (rfind(stem, com.cons_c .. com.cons_c .. "$") and not stem:find("kk$") and not stem:find("pp$")) then
		-- Other stems in two consonants normally have dat -i, but those in -kk or -pp normally
		-- don't, so exclude them and require explicit specification
		default_dat_sg = "i"
	elseif not rfind(stem, com.vowel_c .. "$") and is_proper_noun(base, stem) then
		-- proper noun whose stem does not end in a vowel
		default_dat_sg = "i"
	elseif props.con and props.con.form == "con" then
		default_dat_sg = "i"
	elseif rfind(stem, com.vowel_c .. "r?$") then
		default_dat_sg = ""
	elseif rfind(base.lemma, "ll$") then
		-- nouns in -ll without contraction, which generally includes those not in -all/-ill/-ull plus a few in these
		-- endings such as [[panill]] "paneling" (rare variant of [[panell]]), [[kórall]] "coral", [[kristall]]
		-- "crystal", [[kanill]] "cinnamon" (also [[kanell]]); only a few exceptions, such as [[rafall]] "generator",
		-- which optionally contracts and has with dati/-:i without contraction; [[hvoll]] "hill", [[kokkáll]]
		-- "cuckold", [[páll]] "spade, pointed shovel", [[þræll]] "slave" with dat-:i/-; [[hóll]] "hill", [[hæll]]
		-- "heel", [[stóll]] "chair", which are dat-:i[footnote]/- with a footnote variously indicating that the
		-- dative in -i occurs only in fixed expressions, compounds, place names, etc.
		default_dat_sg = ""
	elseif rfind(base.lemma, "nn$") then
		-- nouns in -nn without contraction, which generally includes those not in -ann/-inn/-unn; there are fewer of
		-- these than the corresponding nouns in -ll and they have default dative i/i; only exceptions I can find are
		-- [[húnn]] "knob", [[tónn]] "tone (music)", [[dúnn]] "down (feathers)"", which have dati:-/i.
		default_dat_sg = "i"
	elseif base.overrides.def_dat_s and base.definiteness == "def" then
		-- OK; user supplied def_dat_s override for a definite-only lemma
	elseif base.overrides.dat_s and base.overrides.dat_s.indef and base.definiteness == "indef" then
		-- OK; user supplied dat_s override with indefinite setting, for an indefinite-only lemma
	elseif base.overrides.dat_s and base.overrides.dat_s.indef and base.overrides.def_dat_s then
		-- OK; user supplied dat_s override with indefinite setting and def_dat_s override, which
		-- together provide both indefinite and definite values
	elseif base.overrides.dat_s and not base.overrides.dat_s.def then
		error(("Saw masculine stem '%s' and dative singular override of just the indefinite ending, but " ..
			"requires both the indefinite and definite endings of the dative singular in the form 'datINDEF/DEF'"):
			format(stem))
	elseif not base.overrides.dat_s then
		local exceptions = "exceptions are nouns in -ir, -ó or -i; proper nouns; plural-only nouns; nouns with " ..
			"stem contraction or j-infix; nouns whose stem ends in two or more consonants, except for -kk and " ..
			"-pp; and nouns whose stem ends in a vowel or vowel + r"
		if base.definiteness == "indef" then
			error(("Saw masculine stem '%s' and no dative override: Most indefinite-only masculine nouns must " ..
				"explicitly specify the indefinite ending of the dative singular using an override of the form " ..
				"'datINDEF'; %s"):format(stem, exceptions))
		else
			error(("Saw masculine stem '%s' and no dative override: Most masculine nouns must explicitly specify " ..
				"the indefinite and definite endings of the dative singular using an override of the form " ..
				"'datINDEF/DEF'; %s"):format(stem, exceptions))
		end
	end
	props.default_dat_sg = default_dat_sg
end


-- Determine the stems to use for each stem set: vowel and nonvowel stems, for singular
-- and plural. We assume that one of base.vowel_stem or base.nonvowel_stem has been
-- set in determine_declension(), depending on whether the lemma ends in
-- a vowel. We construct all the rest given the reducibility, vowel alternation spec and
-- any explicit stems given. We store the determined stems inside of the property-set objects
-- in `base.prop_sets`, meaning that if the user gave multiple reducible or vowel-alternation
-- patterns, we will compute multiple sets of stems. The reason is that the stems may vary
-- depending on the reducibility and vowel alternation.
local function determine_props(base)
	-- Now determine all the props for each prop set.
	for _, props in ipairs(base.prop_sets) do
		-- Determine the default dative singular for masculine nouns using declension "m".
		determine_default_masc_dat_sg(base, props)

		-- Convert regular `umut` to `u_mut` (applying to the second-to-last syllable) when contraction
		-- is in place and we're computing the u-mutation or reverse u-mutation version of the non-vowel
		-- stem. Cf. neuter [[mastur]] "mast" with plural [[möstur]].
		local function map_nonvstem_umut(val)
			if val == "umut" and props.con and props.con.form == "con" then
				return "u_mut"
			elseif val == "unumut" and props.con and props.con.form == "con" then
				return "unu_mut"
			else
				return val
			end
		end

		-- Almost all nouns have dative plural -um, which triggers u-mutation, so we need to compute the u-mutation
		-- stem using "umut" if not specifically given. Set `defaulted` so an error isn't triggered if there's no
		-- special u-mutated form.
		local props_umut = props.umut
		if not props_umut and (not props.unumut or props.unumut.form:find("^%-")) then
			props_umut = {form = "umut", defaulted = true}
		end
		-- First do all the stems, handling overall and plural-specific stems separately.
		for _, prefix in ipairs {"", "pl_"} do
			local base_stem, base_vstem
			if prefix == "" then
				base_stem = base.stem
				base_vstem = base.vstem
			else
				base_stem = base.plstem
				base_vstem = base.plvstem
			end
			-- The plstem is almost never set, so don't do a lot of unnecessary computation.
			if prefix == "pl_" and not base_stem then
				break
			end
			local stem, nonvstem, umut_nonvstem, imut_nonvstem, vstem, umut_vstem, imut_vstem, null_defvstem,
				umut_null_defvstem
			if props.unumut and not props.unumut.form:find("^%-") then
				umut_nonvstem = base_stem
				nonvstem = com.apply_reverse_u_mutation(umut_nonvstem, map_nonvstem_umut(props.unumut.form),
					not props.unumut.defaulted)
				stem = nonvstem
				if base.need_imut then
					imut_nonvstem = com.apply_i_mutation(nonvstem, base.imutval)
				end
				if base_vstem then
					error(("Don't currently know how to combine '%svstem:' with 'unumut' specs"):format(
						prefix == "pl_" and "pl" or ""))
				end
				if props.con and props.con.form == "con" then
					umut_vstem = com.apply_contraction(base_stem)
				else
					umut_vstem = base_stem
				end
				vstem = com.apply_reverse_u_mutation(umut_vstem, props.unumut.form, not props.unumut.defaulted)
				if base.need_imut then
					imut_vstem = com.apply_i_mutation(vstem, base.imutval)
				end
				local props_unumut_form = props.unumut.form
				if props.defcon and props.defcon.form == "defcon" then
					umut_null_defvstem = com.apply_contraction(base_stem)
				else
					umut_null_defvstem = base_stem
					-- If contraction but not defcon is applicable, the stem we'll be applying reverse u-mutation
					-- to is the uncontracted stem so we need to apply reverse u-mutation to the second-to-last
					-- vowel.
					props_unumut_form = map_nonvstem_umut(props_unumut_form)
				end
				null_defvstem = com.apply_reverse_u_mutation(umut_null_defvstem, props_unumut_form,
					not props.unumut.defaulted)
			elseif props.unimut and not props.unimut.form:find("^%-") then
				imut_nonvstem = base_stem
				nonvstem = com.apply_reverse_i_mutation(imut_nonvstem, base.imutval)
				stem = nonvstem
				if props_umut then
					umut_nonvstem = com.apply_u_mutation(nonvstem, map_nonvstem_umut(props_umut.form),
						not props_umut.defaulted)
				end
				if base_vstem then
					error(("Don't currently know how to combine '%svstem:' with 'unimut' specs"):format(
						prefix == "pl_" and "pl" or ""))
				end
				if props.con and props.con.form == "con" then
					imut_vstem = com.apply_contraction(base_stem)
				else
					imut_vstem = base_stem
				end
				vstem = com.apply_reverse_i_mutation(imut_vstem, base.imutval)
				if props_umut then
					umut_vstem = com.apply_u_mutation(vstem, props_umut.form, not props_umut.defaulted)
				end
				if props.defcon and props.defcon.form == "defcon" then
					error("Don't currently know how to combine 'defcon' with 'unimut' specs")
				end
				base.need_imut = true
			elseif props_umut then
				stem = base_stem
				nonvstem = stem
				umut_nonvstem = com.apply_u_mutation(nonvstem, map_nonvstem_umut(props_umut.form),
					not props_umut.defaulted)
				if base.need_imut then
					imut_nonvstem = com.apply_i_mutation(nonvstem, base.imutval)
				end
				vstem = base_vstem or base_stem
				if props.con and props.con.form == "con" then
					vstem = com.apply_contraction(vstem)
				end
				umut_vstem = com.apply_u_mutation(vstem, props_umut.form, not props_umut.defaulted)
				if base.need_imut then
					imut_vstem = com.apply_i_mutation(vstem, base.imutval)
				end
				if props.defcon and props.defcon.form == "defcon" then
					null_defvstem = com.apply_contraction(base_stem)
				else
					null_defvstem = base_stem
				end
				umut_null_defvstem = com.apply_u_mutation(null_defvstem, props_umut.form, not props_umut.defaulted)
			else
				-- Normally u-mutated forms should always be available, unless 'unumut' is in effect.
				error(("Internal error: Neither 'unumut' or 'umut' specified: %s"):format(dump(props)))
			end

			props[prefix .. "stem"] = stem
			if nonvstem ~= stem then
				props[prefix .. "nonvstem"] = nonvstem
			end
			if umut_nonvstem ~= nonvstem then
				-- For 'con' and 'defcon' below, footnotes can be placed on -con or -defcon so we have to check for those
				-- footnotes as well as checking for the vstem and such being different, so the -con and -defcon footnotes
				-- are still active. However, there's no such thing as -umut, and any time that there's an explicit umut
				-- variant given, umut_nonvstem will be different from nonvstem (otherwise an error will occur in
				-- apply_u_mutation), so we don't need this extra check here.
				if props_umut then
					umut_nonvstem = iut.combine_form_and_footnotes(umut_nonvstem, props_umut.footnotes)
				end
				props[prefix .. "umut_nonvstem"] = umut_nonvstem
			end
			if base.need_imut then
				-- imut footnotes handled specially below
				props[prefix .. "imut_nonvstem"] = imut_nonvstem
			end
			if vstem ~= stem or props.con and props.con.footnotes then
				-- See comment above for why we need to check for props.con.footnotes (basically, to handle footnotes on
				-- -con).
				if props.con then
					vstem = iut.combine_form_and_footnotes(vstem, props.con.footnotes)
				end
				props[prefix .. "vstem"] = vstem
			end
			if umut_vstem ~= vstem or props.con and props.con.footnotes then
				-- See comment above under `umut_nonvstem ~= nonvstem`. There's no -umut so whenever there's a specific
				-- umut variant with footnote, umut_vstem will be different from vstem so we don't need to check for
				-- `or props_umut and props_umut.footnotes` above.
				local footnotes = iut.combine_footnotes(props.con and props.con.footnotes or nil,
					props_umut and props_umut.footnotes or nil)
				umut_vstem = iut.combine_form_and_footnotes(umut_vstem, footnotes)
				props[prefix .. "umut_vstem"] = umut_vstem
			end
			if base.need_imut then
				-- imut footnotes handled specially below
				props[prefix .. "imut_vstem"] = imut_vstem
			end
			if null_defvstem ~= nonvstem or props.defcon and props.defcon.footnotes then
				-- See comment above for why we need to check for props.defcon.footnotes (basically, to handle footnotes on
				-- -defcon).
				if props.defcon then
					null_defvstem = iut.combine_form_and_footnotes(null_defvstem, props.defcon.footnotes)
				end
				props[prefix .. "null_defvstem"] = null_defvstem
			end
			if umut_null_defvstem ~= null_defvstem or props.defcon and props.defcon.footnotes then
				-- Analogous situation to the clause above that checks for `umut_vstem ~= vstem`.
				local footnotes = iut.combine_footnotes(props.defcon and props.defcon.footnotes or nil,
					props_umut and props_umut.footnotes or nil)
				umut_null_defvstem = iut.combine_form_and_footnotes(umut_null_defvstem, footnotes)
				props[prefix .. "umut_null_defvstem"] = umut_null_defvstem
			end
		end

		-- Do the j-infix, v-infix, imut, unimut and unumut properties.
		if props.j then
			props.jinfix = props.j.form == "j" and "j" or ""
			props.jinfix_footnotes = props.j.footnotes
			props.j = nil
		end
		if props.v then
			props.vinfix = props.v.form == "v" and "v" or ""
			props.vinfix_footnotes = props.v.footnotes
			props.v = nil
		end
		if props.imut then
			props.imut_footnotes = props.imut.footnotes
			props.imut = props.imut.form == "imut" and true or false
		end
		if props.unimut then
			props.unimut_footnotes = props.unimut.footnotes
			props.unimut = props.unimut.form == "unimut" and true or false
		end
		if props.unumut then
			props.unumut_footnotes = props.unumut.footnotes
			props.unumut = props.unumut.form
		end
	end
end


local function replace_hashvals(base, val)
	if not val then
		return val
	end
	if val:find("##") then
		local lemma_minus_r, final_nom_ending = parse_off_final_nom_ending(base.lemma)
		val = val:gsub("##", m_string_utilities.replacement_escape(lemma_minus_r))
	end
	val = val:gsub("#", m_string_utilities.replacement_escape(base.lemma))
	return val
end
	

local function detect_indicator_spec(base)
	-- Replace # and ## in all overridable stems as well as all overrides.
	for _, stemkey in ipairs(overridable_stems) do
		base[stemkey] = replace_hashvals(base, base[stemkey])
	end
	map_all_overrides(base, function(formobj)
		formobj.form = replace_hashvals(base, formobj.form)
	end)

	if base.props.pron then
		determine_pronoun_props(base)
	elseif base.props.adj then
		process_declnumber(base)
		expand_property_sets(base)
		synthesize_adj_lemma(base)
		determine_props(base)
	else
		expand_property_sets(base)
		if base.definiteness == "def" then
			synthesize_indefinite_lemma(base)
		end
		if base.number == "pl" then
			synthesize_singular_lemma(base)
		end
		determine_declension(base)
		determine_props(base)
	end
end


local function detect_all_indicator_specs(alternant_multiword_spec)
	-- Keep track of all genders seen in the singular and plural so we can determine whether to add the term to
	-- [[:Category:Icelandic nouns that change gender in the plural]]. FIXME: Is this needed for Icelandic? It's copied
	-- from Czech.
	alternant_multiword_spec.sg_genders = {}
	alternant_multiword_spec.pl_genders = {}
	iut.map_word_specs(alternant_multiword_spec, function(base)
		detect_indicator_spec(base)
		if base.number ~= "pl" then
			alternant_multiword_spec.sg_genders[base.actual_gender] = true
		end
		if base.number ~= "sg" then
			alternant_multiword_spec.pl_genders[base.actual_gender] = true
		end
	end)
end


local propagate_multiword_properties


local function propagate_alternant_properties(alternant_spec, property, mixed_value, nouns_only)
	local seen_property
	for _, multiword_spec in ipairs(alternant_spec.alternants) do
		propagate_multiword_properties(multiword_spec, property, mixed_value, nouns_only)
		if seen_property == nil then
			seen_property = multiword_spec[property]
		elseif multiword_spec[property] and seen_property ~= multiword_spec[property] then
			seen_property = mixed_value
		end
	end
	alternant_spec[property] = seen_property
end


propagate_multiword_properties = function(multiword_spec, property, mixed_value, nouns_only)
	local seen_property = nil
	local last_seen_nounal_pos = 0
	local word_specs = multiword_spec.alternant_or_word_specs or multiword_spec.word_specs
	for i = 1, #word_specs do
		local is_nounal
		if word_specs[i].alternants then
			propagate_alternant_properties(word_specs[i], property, mixed_value)
			is_nounal = not not word_specs[i][property]
		elseif nouns_only then
			is_nounal = is_regular_noun(word_specs[i])
		else
			is_nounal = not not word_specs[i][property]
		end
		if is_nounal then
			if not word_specs[i][property] then
				error("Internal error: noun-type word spec without " .. property .. " set")
			end
			for j = last_seen_nounal_pos + 1, i - 1 do
				word_specs[j][property] = word_specs[j][property] or word_specs[i][property]
			end
			last_seen_nounal_pos = i
			if seen_property == nil then
				seen_property = word_specs[i][property]
			elseif seen_property ~= word_specs[i][property] then
				seen_property = mixed_value
			end
		end
	end
	if last_seen_nounal_pos > 0 then
		for i = last_seen_nounal_pos + 1, #word_specs do
			word_specs[i][property] = word_specs[i][property] or word_specs[last_seen_nounal_pos][property]
		end
	end
	multiword_spec[property] = seen_property
end


local function propagate_properties_downward(alternant_multiword_spec, property, default_propval)
	local function set_and_fetch(obj, default)
		local retval
		if obj[property] then
			retval = obj[property]
		else
			obj[property] = default
			retval = default
		end
		if not obj["actual_" .. property] then
			obj["actual_" .. property] = retval
		end
		return retval
	end
	local propval1 = set_and_fetch(alternant_multiword_spec, default_propval)
	for _, alternant_or_word_spec in ipairs(alternant_multiword_spec.alternant_or_word_specs) do
		local propval2 = set_and_fetch(alternant_or_word_spec, propval1)
		if alternant_or_word_spec.alternants then
			for _, multiword_spec in ipairs(alternant_or_word_spec.alternants) do
				local propval3 = set_and_fetch(multiword_spec, propval2)
				for _, word_spec in ipairs(multiword_spec.word_specs) do
					local propval4 = set_and_fetch(word_spec, propval3)
					if propval4 == "mixed" then
						-- FIXME, use clearer error message.
						error("Attempt to assign mixed " .. property .. " to word")
					end
					set_and_fetch(word_spec, propval4)
				end
			end
		else
			if propval2 == "mixed" then
				-- FIXME, use clearer error message.
				error("Attempt to assign mixed " .. property .. " to word")
			end
			set_and_fetch(alternant_or_word_spec, propval2)
		end
	end
end


--[=[
Propagate `property` (one of "gender", "number" or "definiteness") from nouns to adjacent adjectives. We proceed
as follows:
1. We assume the properties in question are already set on all nouns. This should happen in
   set_defaults_and_check_bad_indicators().
2. We first propagate properties upwards and sideways. We recurse downwards from the top. When we encounter a multiword
   spec, we proceed left to right looking for a noun. When we find a noun, we fetch its property (recursing if the noun
   is an alternant), and propagate it to any adjectives to its left, up to the next noun to the left. When we have
   processed the last noun, we also propagate its property value to any adjectives to the right (to handle e.g.
   [[svefninn langi]] "the long sleep", where the adjective [[langi]] should inherit the 'masculine', 'singular' and
   'definite' properties of [[svefninn]]). Finally, we set the property value for the multiword spec itself by combining
   all the non-nil properties of the individual elements. If all non-nil properties have the same value, the result is
   that value, otherwise it is `mixed_value` (which is "mixed" for gender, but "both" for number and "bothdef" for
   definiteness).
3. When we encounter an alternant spec in this process, we recursively process each alternant (which is a multiword
   spec) using the previous step, and combine any non-nil properties we encounter the same way as for multiword specs.
4. The effect of steps 2 and 3 is to set the property of each alternant and multiword spec based on its children or its
   neighbors.
]=]
local function propagate_properties(alternant_multiword_spec, property, default_propval, mixed_value)
	propagate_multiword_properties(alternant_multiword_spec, property, mixed_value, "nouns only")
	propagate_multiword_properties(alternant_multiword_spec, property, mixed_value, false)
	propagate_properties_downward(alternant_multiword_spec, property, default_propval)
end


local function determine_noun_status(alternant_multiword_spec)
	for i, alternant_or_word_spec in ipairs(alternant_multiword_spec.alternant_or_word_specs) do
		if alternant_or_word_spec.alternants then
			local is_noun = false
			for _, multiword_spec in ipairs(alternant_or_word_spec.alternants) do
				for j, word_spec in ipairs(multiword_spec.word_specs) do
					if is_regular_noun(word_spec) then
						multiword_spec.first_noun = j
						is_noun = true
						break
					end
				end
			end
			if is_noun then
				alternant_multiword_spec.first_noun = i
			end
		elseif is_regular_noun(alternant_or_word_spec) then
			alternant_multiword_spec.first_noun = i
			return
		end
	end
end


-- Set the part of speech based on properties of the individual words.
local function set_pos(alternant_multiword_spec)
	if alternant_multiword_spec.args.pos then
		alternant_multiword_spec.pos = alternant_multiword_spec.args.pos
	elseif alternant_multiword_spec.saw_pron and not alternant_multiword_spec.saw_non_pron then
		alternant_multiword_spec.pos = "pronoun"
	else
		alternant_multiword_spec.pos = "noun"
	end
	alternant_multiword_spec.plpos = require("Module:string utilities").pluralize(alternant_multiword_spec.pos)
end


local function normalize_all_lemmas(alternant_multiword_spec)
	iut.map_word_specs(alternant_multiword_spec, function(base)
		local lemma = base.orig_lemma_no_links
		base.actual_lemma = lemma
		base.lemma = base.decllemma or lemma
		base.source_template = alternant_multiword_spec.source_template
	end)
end


local function decline_noun(base)
	for _, props in ipairs(base.prop_sets) do
		if not decls[base.decl] then
			error("Internal error: Unrecognized declension type '" .. base.decl .. "'")
		end
		decls[base.decl](base, props)
	end
	handle_derived_slots_and_overrides(base)
	local function copy(from_slot, to_slot)
		base.forms["ind_" .. to_slot] = base.forms["ind_" .. from_slot]
		base.forms["def_" .. to_slot] = base.forms["def_" .. from_slot]
	end
	if base.actual_number ~= base.number then
		local source_num = base.number == "sg" and "_s" or "_p"
		local dest_num = base.number == "sg" and "_p" or "_s"
		for _, case in ipairs(cases) do
			copy(case .. source_num, case .. dest_num)
			copy("nom" .. source_num .. "_linked", "nom" .. dest_num .. "_linked")
		end
		if base.actual_number ~= "both" then
			local erase_num = base.actual_number == "sg" and "_p" or "_s"
			for _, case in ipairs(cases) do
				base.forms["ind_" .. case .. erase_num] = nil
				base.forms["def_" .. case .. erase_num] = nil
			end
			base.forms["ind_nom" .. erase_num .. "_linked"] = nil
			base.forms["def_nom" .. erase_num .. "_linked"] = nil
		end
	end
	process_addnote_specs(base)
end


local function get_variants(form)
	return nil
	--[=[
	FIXME
	return
		form:find(com.VAR1) and "var1" or
		form:find(com.VAR2) and "var2" or
		form:find(com.VAR3) and "var3" or
		nil
	]=]
end


-- Compute the categories to add the noun to, as well as the annotation to display in the
-- declension title bar. We combine the code to do these functions as both categories and
-- title bar contain similar information.
local function compute_categories_and_annotation(alternant_multiword_spec)
	-- FIXME: Update for Icelandic
	local all_cats = {}
	local function inscat(cattype)
		m_table.insertIfNot(all_cats, "Icelandic " .. cattype)
	end
	if alternant_multiword_spec.pos == "noun" then
		if alternant_multiword_spec.actual_number == "sg" then
			inscat("uncountable nouns")
		elseif alternant_multiword_spec.actual_number == "pl" then
			inscat("pluralia tantum")
		end
		if alternant_multiword_spec.saw_indecl and not alternant_multiword_spec.saw_non_indecl then
			inscat("indeclinable nouns")
		end
		if alternant_multiword_spec.saw_unknown_decl and not alternant_multiword_spec.saw_non_unknown_decl then
			inscat("nouns with unknown declension")
		end
	end
	local annotation
	local annparts = {}
	local irregs = {}
	local genderspecs = {}
	local stemspecs = {}
	local scrape_chains = {}
	local function insann(txt, joiner)
		if joiner and annparts[1] then
			table.insert(annparts, joiner)
		end
		table.insert(annparts, txt)
	end

	local function trim(text)
		text = text:gsub(" +", " ")
		return mw.text.trim(text)
	end

	local function do_word_spec(base)
		local actual_gender = gender_code_to_desc[base.actual_gender]
		local declined_gender = gender_code_to_desc[base.gender]
		local gender
		if actual_gender ~= declined_gender then
            gender = ("%s (declined as %s)"):format(actual_gender, declined_gender)
			inscat("nouns with actual gender different from declined gender")
		else
			gender = actual_gender
		end
		if gender then
			m_table.insertIfNot(genderspecs, gender)
		end
		for _, props in ipairs(base.prop_sets) do
			-- User-specified 'decllemma:' indicates irregular stem.
			if base.decllemma then
				m_table.insertIfNot(irregs, "irreg-stem")
				inscat("nouns with irregular stem")
			end
			m_table.insertIfNot(stemspecs, props.stem)
		end
	end
	local key_entry = alternant_multiword_spec.first_noun or 1
	if #alternant_multiword_spec.alternant_or_word_specs >= key_entry then
		local alternant_or_word_spec = alternant_multiword_spec.alternant_or_word_specs[key_entry]
		if alternant_or_word_spec.alternants then
			for _, multiword_spec in ipairs(alternant_or_word_spec.alternants) do
				key_entry = multiword_spec.first_noun or 1
				if #multiword_spec.word_specs >= key_entry then
					do_word_spec(multiword_spec.word_specs[key_entry])
				end
			end
		else
			do_word_spec(alternant_or_word_spec)
		end
	end
	iut.map_word_specs(alternant_multiword_spec, function(base)
		if base.scrape_chain[1] then
			local linked_scrape_chain = {}
			for _, element in ipairs(base.scrape_chain) do
				table.insert(linked_scrape_chain, ("[[%s]]"):format(element))
			end
			m_table.insertIfNot(scrape_chains, table.concat(linked_scrape_chain, " -> "))
		end
	end)
	if alternant_multiword_spec.actual_number == "sg" or alternant_multiword_spec.actual_number == "pl" then
		-- not "both" or "none" (for [[sebe]])
		insann(alternant_multiword_spec.actual_number == "sg" and "sg-only" or "pl-only", " ")
	end
    if #genderspecs > 0 then
        insann(table.concat(genderspecs, " // "), " ")
    end
	if #irregs > 0 then
		insann(table.concat(irregs, " // "), " ")
	end
	if #scrape_chains > 0 then
		insann(("based on %s"):format(m_table.serialCommaJoin(scrape_chains)), ", ")
		inscat("nouns declined using scraped base noun declensions")
	end
		
	alternant_multiword_spec.annotation = table.concat(annparts)
	if #stemspecs > 1 then
		inscat("nouns with multiple stems")
	end
	if alternant_multiword_spec.actual_number == "both" and not m_table.deepEquals(alternant_multiword_spec.sg_genders, alternant_multiword_spec.pl_genders) then
		inscat("nouns that change gender in the plural")
	end
	alternant_multiword_spec.categories = all_cats
end


local function show_forms(alternant_multiword_spec)
	local lemmas = {}
	for _, slot in ipairs(potential_lemma_slots) do
		if alternant_multiword_spec.forms[slot] then
			for _, formobj in ipairs(alternant_multiword_spec.forms[slot]) do
				-- FIXME, now can support footnotes as qualifiers in headwords?
				table.insert(lemmas, formobj.form)
			end
			break
		end
	end
	local props = {
		lemmas = lemmas,
		slot_list = alternant_multiword_spec.noun_slots,
		lang = lang,
		canonicalize = function(form)
			-- return com.remove_variant_codes(form)
			return form
		end,
	}
	iut.show_forms(alternant_multiword_spec.forms, props)
end


local function make_table(alternant_multiword_spec)
	local forms = alternant_multiword_spec.forms

	local function template_prelude(min_width)
		return rsub([=[
<div>
<div class="NavFrame" style="max-width:MINWIDTHem">
<div class="NavHead" style="background: var(--wikt-palette-lighterblue, #eff7ff);">{title}{annotation}</div>
<div class="NavContent" style="overflow:auto">
{\op}| style="min-width:MINWIDTHem" class="inflection-table is-inflection-table"
|-
]=], "MINWIDTH", min_width)
	end

	local function template_postlude()
		return [=[
|{\cl}{notes_clause}</div></div></div>]=]
	end

	local table_spec_both = template_prelude("45") .. [=[
! class="is-header" style="width:20%;" rowspan="2" |
! class="is-header" colspan="2" | singular
! class="is-header" colspan="2" | plural
|-
! class="is-header" | indefinite
! class="is-header" | definite
! class="is-header" | indefinite
! class="is-header" | definite
|-
!class="is-row"|nominative
| {ind_nom_s}
| {def_nom_s}
| {ind_nom_p}
| {def_nom_p}
|-
!class="is-row"|accusative
| {ind_acc_s}
| {def_acc_s}
| {ind_acc_p}
| {def_acc_p}
|-
!class="is-row"|dative
| {ind_dat_s}
| {def_dat_s}
| {ind_dat_p}
| {def_dat_p}
|-
!class="is-row"|genitive
| {ind_gen_s}
| {def_gen_s}
| {ind_gen_p}
| {def_gen_p}
]=] .. template_postlude()

	local function get_table_spec_one_number(number, numcode)
		local table_spec_one_number = [=[
! class="is-header" style="width:33%;" rowspan="2" |
! class="is-header" colspan="2" | NUMBER
|-
! class="is-header" | indefinite
! class="is-header" | definite
|-
!class="is-row"|nominative
| {ind_nom_NUM}
| {def_nom_NUM}
|-
!class="is-row"|accusative
| {ind_acc_NUM}
| {def_acc_NUM}
|-
!class="is-row"|dative
| {ind_dat_NUM}
| {def_dat_NUM}
|-
!class="is-row"|genitive
| {ind_gen_NUM}
| {def_gen_NUM}
]=]
		return template_prelude("30") .. table_spec_one_number:gsub("NUMBER", number):gsub("NUM", numcode) ..
			template_postlude()
	end

	local function get_table_spec_one_number_one_def(number, numcode, definiteness, defcode)
		local table_spec_one_number_one_def = [=[
! class="is-header" style="width:100%;" colspan="2" | DEFINITENESS NUMBER
|-
!class="is-row"|nominative
| {DEF_nom_NUM}
|-
!class="is-row"|accusative
| {DEF_acc_NUM}
|-
!class="is-row"|dative
| {DEF_dat_NUM}
|-
!class="is-row"|genitive
| {DEF_gen_NUM}
]=]
		return template_prelude("20") .. (table_spec_one_number_one_def:gsub("NUMBER", number):gsub("NUM", numcode)
			:gsub("DEFINITENESS", definiteness):gsub("DEF", defcode)) .. template_postlude()
	end

	local notes_template = [=[
<div class="is-footnote-outer-div" style="width:100%;">
<div class="is-footnote-inner-div">
{footnote}
</div></div>
]=]

	if alternant_multiword_spec.title then
		forms.title = alternant_multiword_spec.title
	else
		forms.title = 'Declension of <i lang="is">' .. forms.lemma .. '</i>'
	end

	local annotation = alternant_multiword_spec.annotation
	if annotation == "" then
		forms.annotation = ""
	else
		forms.annotation = " (<span style=\"font-size: smaller;\">" .. annotation .. "</span>)"
	end

	local number, numcode
	if alternant_multiword_spec.actual_number == "sg" then
		number, numcode = "singular", "s"
	elseif alternant_multiword_spec.actual_number == "pl" then
		number, numcode = "plural", "p"
	elseif alternant_multiword_spec.actual_number == "none" then -- used for [[sebe]]
		-- FIXME: Update for Icelandic
		number, numcode = "", "s"
	end

	local definiteness, defcode
	if alternant_multiword_spec.definiteness == "indef" then
		definiteness, defcode = "indefinite", "ind"
	elseif alternant_multiword_spec.definiteness == "def" then
		definiteness, defcode = "definite", "def"
	elseif alternant_multiword_spec.definiteness == "none" then
		definiteness, defcode = "", "ind"
	end

	local table_spec =
		alternant_multiword_spec.actual_number ~= "both" and alternant_multiword_spec.definiteness ~= "bothdef" and
			get_table_spec_one_number_one_def(number, numcode, definiteness, defcode) or
		alternant_multiword_spec.actual_number == "both" and table_spec_both or
		get_table_spec_one_number(number, numcode)
	forms.notes_clause = forms.footnote ~= "" and
		m_string_utilities.format(notes_template, forms) or ""
	return require("Module:TemplateStyles")("Module:is-noun/style.css") .. m_string_utilities.format(table_spec, forms)
end


local function compute_headword_genders(alternant_multiword_spec)
	local genders = {}
	local number
	if alternant_multiword_spec.actual_number == "pl" then
		number = "-p"
	else
		number = ""
	end
	iut.map_word_specs(alternant_multiword_spec, function(base)
		if base.actual_gender ~= "none" then
			m_table.insertIfNot(genders, base.actual_gender .. number)
		end
	end)
	return genders
end


-- Externally callable function to parse and decline a noun given user-specified arguments and the argument spec
-- `argspec` (specified because the user may give multiple such specs). Return value is ALTERNANT_MULTIWORD_SPEC, an
-- object where the declined forms are in `ALTERNANT_MULTIWORD_SPEC.forms` for each slot. If there are no values for a
-- slot, the slot key will be missing. The value for a given slot is a list of objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms(args, argspec, source_template)
	local from_headword = source_template == "is-noun" or source_template == "is-proper noun"
	local pagename = args.pagename or mw.loadData("Module:headword/data").pagename
	local parse_props = {
		parse_indicator_spec = function(angle_bracket_spec, lemma)
			return parse_indicator_spec(angle_bracket_spec, lemma, pagename)
		end,
		angle_brackets_omittable = true,
		allow_blank_lemma = true,
	}
	local alternant_multiword_spec = iut.parse_inflected_text(argspec, parse_props)
	alternant_multiword_spec.title = args.title
	alternant_multiword_spec.args = args
	alternant_multiword_spec.source_template = source_template

	local scrape_errors = {}
	iut.map_word_specs(alternant_multiword_spec, function(base)
		if base.scrape_error then
			table.insert(scrape_errors, base.scrape_error)
		end
	end)
	
	if scrape_errors[1] then
		alternant_multiword_spec.scrape_errors = scrape_errors
	else
		normalize_all_lemmas(alternant_multiword_spec)
		set_all_defaults_and_check_bad_indicators(alternant_multiword_spec)
		-- These need to happen before detect_all_indicator_specs() so that adjectives get their genders and number
		-- set appropriately, which are needed to correctly synthesize the adjective lemma.
		propagate_properties(alternant_multiword_spec, "number", "both", "both")
		-- FIXME, the default value (third param) used to be 'm' with a comment indicating that this applied only to
		-- plural adjectives, where it didn't matter; but in Icelandic, plural adjectives are distinguished for gender.
		-- Make sure 'mixed' works.
		propagate_properties(alternant_multiword_spec, "gender", "mixed", "mixed")
		propagate_properties(alternant_multiword_spec, "definiteness", "bothdef", "bothdef")
		detect_all_indicator_specs(alternant_multiword_spec)
		-- Propagate 'actual_number' after calling detect_all_indicator_specs(), which sets 'actual_number' for
		-- adjectives.
		propagate_properties(alternant_multiword_spec, "actual_number", "both", "both")
		determine_noun_status(alternant_multiword_spec)
		set_pos(alternant_multiword_spec)
		alternant_multiword_spec.noun_slots = get_noun_slots(alternant_multiword_spec)
		local inflect_props = {
			skip_slot = function(slot)
				return skip_slot(alternant_multiword_spec.actual_number, alternant_multiword_spec.definiteness, slot)
			end,
			slot_list = alternant_multiword_spec.noun_slots,
			get_variants = get_variants,
			inflect_word_spec = decline_noun,
		}
		iut.inflect_multiword_or_alternant_multiword_spec(alternant_multiword_spec, inflect_props)
		compute_categories_and_annotation(alternant_multiword_spec)
		alternant_multiword_spec.genders = compute_headword_genders(alternant_multiword_spec)
	end
	if args.json then
		alternant_multiword_spec.args = nil
		return require("Module:JSON").toJSON(alternant_multiword_spec)
	end
	return alternant_multiword_spec
end


-- Entry point for {{is-ndecl}}. Template-callable function to parse and decline a noun given
-- user-specified arguments and generate a displayable table of the declined forms.
function export.show(frame)
	local parent_args = frame:getParent().args
	local params = {
		[1] = {required = true, list = true, default = "akur<m.#>"},
		deriv = {list = true},
		id = {},
		title = {},
 		pagename = {},
		json = {type = "boolean"},
	}
	local args = m_para.process(parent_args, params)
	local alternant_multiword_specs = {}
	for i, argspec in ipairs(args[1]) do
		alternant_multiword_specs[i] = export.do_generate_forms(args, argspec, "is-ndecl")
	end
	if args.json then
		-- JSON return value
		if #args[1] == 1 then
			return alternant_multiword_specs[1]
		else
			return alternant_multiword_specs
		end
	end
	local parts = {}
	local function ins(txt)
		table.insert(parts, txt)
	end
	for _, alternant_multiword_spec in ipairs(alternant_multiword_specs) do
		if not alternant_multiword_spec.scrape_errors then
			show_forms(alternant_multiword_spec)
		end
		if alternant_multiword_spec.header then
			ins(("'''%s:'''\n"):format(alternant_multiword_spec.header))
		end
		if alternant_multiword_spec.q then
			ins(("''%s''\n"):format(alternant_multiword_spec.q))
		end
		local categories
		if alternant_multiword_spec.scrape_errors then
			local errmsgs = {}
			for _, scrape_error in ipairs(alternant_multiword_spec.scrape_errors) do
				table.insert(errmsgs, '<span style="font-weight: bold; color: #CC2200;">' .. scrape_error .. "</span>")
			end
			-- Surround the messages with a <div> because the table normally does that, and we want to ensure
			-- similar formatting with respect to newlines.
			ins("<div>" .. table.concat(errmsgs, "<br />") .. "</div>")
			categories = {"Icelandic scraping errors in Template:is-ndecl"}
		else
			ins(make_table(alternant_multiword_spec))
			categories = alternant_multiword_spec.categories
		end
		ins(require("Module:utilities").format_categories(categories, lang, nil, nil, force_cat))
	end
	return table.concat(parts)
end


return export
