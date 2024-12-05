local export = {}


--[=[

Authorship: Ben Wing <benwing2>

]=]

--[=[

TERMINOLOGY:

-- "slot" = A particular combination of case/gender/number.
	 Example slot names for adjectives are "gen_f" (genitive feminine singular) and
	 "nom_mp_an" (animate nominative masculine plural). Each slot is filled with zero or more forms.

-- "form" = The declined Icelandic form representing the value of a given slot.

-- "lemma" = The dictionary form of a given Icelandic term. Generally the nominative
     masculine singular, but may occasionally be another form if the nominative
	 masculine singular is missing.
]=]

local lang = require("Module:languages").getByCode("is")
local m_links = require("Module:links")
local m_table = require("Module:table")
local m_string_utilities = require("Module:string utilities")
local iut = require("Module:inflection utilities")
local com = require("Module:is-common")

local current_title = mw.title.getCurrentTitle()
local NAMESPACE = current_title.nsText
local PAGENAME = current_title.text

local u = mw.ustring.char
local rsplit = mw.text.split
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rgmatch = mw.ustring.gmatch
local rsubn = mw.ustring.gsub
local ulen = mw.ustring.len
local uupper = mw.ustring.upper


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


local output_adjective_slots = {
	nom_m = "nom|m|s",
	nom_m_linked = "nom|m|s", -- used in [[Module:is-noun]]?
	nom_f = "nom|f|s",
	nom_n = "nom|n|s",
	nom_mp_an = "an|nom|m|p",
	nom_fp = "in|nom|m|p|;|nom|f|p",
	nom_np = "nom|n|p",
	nom_mp = "nom|m|p",
	nom_fnp = "nom|f//n|p",
	gen_mn = "gen|m//n|s",
	gen_f = "gen|f|s",
	gen_p = "gen|p",
	dat_mn = "dat|m//n|s",
	dat_f = "dat|f|s",
	dat_p = "dat|p",
	acc_m_an = "an|acc|m|s",
	acc_m_in = "in|acc|m|s",
	acc_f = "acc|f|s",
	acc_n = "acc|n|s",
	acc_mfp = "acc|m//f|p",
	acc_np = "acc|n|p",
	acc_mp = "acc|m|p",
	acc_fnp = "acc|f//n|p",
	ins_mn = "ins|m//n|s",
	ins_f = "ins|f|s",
	ins_p = "ins|p",
	loc_mn = "loc|m//n|s",
	loc_f = "loc|f|s",
	loc_p = "loc|p",
	short_m = "short|m|s",
	short_f = "short|f|s",
	short_n = "short|n|s",
	short_mp_an = "short|an|m|p",
	short_fp = "short|in|m|p|;|short|f|p",
	short_np = "short|n|p",
}


local function get_output_adjective_slots(alternant_multiword_spec)
	return output_adjective_slots
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
-- ** `vstem`: The stem used when the ending starts with a vowel, unless overridden by a more specific variant. Defaults
--    to `stem`. Will be specified when contraction is in effect or the user specified `vstem:...`.
-- ** `umut_vstem`: The stem(s) used when the ending starts with a vowel and u-mutation is in effect. Defaults to
--    `vstem`. Note that u-mutation applies to the contracted stem if both u-mutation and contraction are in effect.
--    Will only be present when the result of u-mutation is different from the stem to which u-mutation is applied.
--    (In this case, it will be present even if `vstem` is missing, because there is no generic `umut_stem`.)
-- * Other properties:
-- ** `jinfix`: If present, either "" or "j". Inserted between the stem and ending when the ending begins with a vowel
--    other than "i". Note that j-infixes don't apply to ending overrides.
-- ** `jinfix_footnotes`: Footnotes to attach to forms where j-infixing is possible (even if it's not present).
-- ** `vinfix`: If present, either "" or "v". Inserted between the stem and ending when the ending begins with a vowel.
--    Note that v-infixes don't apply to ending overrides. `jinfix` and `vinfix` cannot both be specified.
-- ** `vinfix_footnotes`: Footnotes to attach to forms where v-infixing is possible (even if it's not present).
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
local function add(base, slot_prefix, slot, props, endings, ending_override, endings_are_full)
	if not endings then
		return
	end
	-- Call skip_slot() based on the declined number and definiteness; if the actual number is different, we correct
	-- this in decline_noun() at the end.
	if skip_slot(base.number, base.definiteness, slot) then
		return
	end
	if type(endings) == "string" then
		endings = {endings}
	end
	-- Loop over each ending.
	for _, endingobj in ipairs(endings) do
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

		-- Compute whether i-mutation or u-mutation is in effect, and compute the "mutation footnotes", which are
		-- footnotes attached to a mutation-related indicator and which may need to be added even if no mutation is
		-- in effect (specifically when dealing with an ending that would trigger a mutation if in effect). AFAIK
		-- you cannot have both mutations in effect at once, and i-mutation overrides u-mutation if both would be in
		-- effect.

		-- Single ^ at the beginning of an ending indicates that the i-mutated version of the stem should apply, and
		-- double ^^ at the beginning indicates that the u-mutated version should apply.
		local explicit_imut, explicit_umut
		ending, explicit_umut = rsubb(ending, "^%^%^", "")
		if not explicit_umut then
			ending, explicit_imut = rsubb(ending, "^%^", "")
		end
		local is_vowel_ending = rfind(ending, "^" .. com.vowel_c)
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

			-- Careful with the following logic; it is written carefully and should not be changed without a
			-- thorough understanding of its functioning.
			local has_umut = mut_in_effect == "u"
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
				local stem_in_effect_footnotes
				if type(stem_in_effect) == "table" then
					stem_in_effect_footnotes = stem_in_effect.footnotes
				end
				stem_in_effect = iut.combine_form_and_footnotes(base.actual_lemma, stem_in_effect_footnotes)
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
		-- Compute the infix (j or nothing) that goes between the stem and ending.
		if not ending_override and is_vowel_ending then
			if props.jinfix and not ending_in_i then
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

		local function combine_stem_ending(stem, ending)
			if stem == "?" then
				return "?"
			end
			local stem_with_infix = ending_is_full and "" or stem .. (infix or "")
			local stem_with_ending
			-- An initial s- of the ending drops after a cluster of cons + s (including written <x>).
			if ending:find("^s") and (stem_with_infix:find("x$") or rfind(stem_with_infix, com.cons_c .. "s$")) then
				ending = ending:sub(2)
			elseif ending:find("^r") then
				if base.assimilate_r then
					local stem_butlast, stem_last = stem_with_infix:match("^(.*)([ln])$") 
					if stem_last then
						ending = stem_last .. ending:sub(2)
					end
				elseif base.double_r then
					ending = "r" .. ending
				end
			elseif ending == "t" then
				if stem_with_infix:find("dd$") then
					stem_with_infix = stem_with_infix:gsub("dd$", "t")
				else
					local stem_butlast, stem_last = rmatch(stem_with_infix, "^(.*" .. com.cons_c .. ")([dðt])$")
					if stem_butlast then
						stem_with_infix = stem_butlast
					else
						stem_butlast = stem_with_infix:match("^(.*)ð$")
						if stem_butlast then
							
					end

			end
			return stem_with_ending = stem_with_infix .. ending
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


local function add_strong_decl_with_nom_sg(base, props,
	nom_m, nom_f, nom_n,
	acc_m, acc_f,      
	dat_m, dat_f, dat_n,
	gen_m, gen_f, gen_n,
	nom_mp, nom_fp, nom_np,
	acc_mp,
	dat_p,
	gen_p
)
	add(base, "str_nom_m", props, nom_m)
	add(base, "str_nom_f", props, nom_f)
	add(base, "str_nom_n", props, nom_n)
	add(base, "str_acc_m", props, acc_m)
	add(base, "str_acc_f", props, acc_f)
	add(base, "str_dat_m", props, dat_m)
	add(base, "str_dat_f", props, dat_f)
	add(base, "str_dat_n", props, dat_n)
	add(base, "str_gen_m", props, gen_m)
	add(base, "str_gen_f", props, gen_f)
	if gen_n == nil then -- not 'false'; use to specify no value for gen_n
		gen_n = gen_m
	end
	add(base, "str_gen_n", props, gen_n)
	add(base, "str_nom_mp", props, nom_mp)
	add(base, "str_nom_fp", props, nom_fp)
	add(base, "str_nom_np", props, nom_np)
	add(base, "str_acc_mp", props, acc_mp)
	add(base, "str_dat_p", props, dat_p)
	add(base, "str_gen_p", props, gen_p)
end


local function add_strong_decl(base, props,
	       nom_f, nom_n,
	acc_m, acc_f,      
	dat_m, dat_f, dat_n,
	gen_m, gen_f, gen_n,
	nom_mp, nom_fp, nom_np,
	acc_mp,
	dat_p,
	gen_p
)
	add_strong_decl_with_nom_sg(
		"*", nom_f, nom_n, acc_m, acc_f,      
		dat_m, dat_f, dat_n, gen_m, gen_f, gen_n,
		nom_mp, nom_fp, nom_np, acc_mp,
		dat_p, gen_p
	)
end

local function add_weak_decl(base, props,
	wk_nom_m, wk_nom_f, wk_n,
	wk_obl_m, wk_obl_f,
	wk_p
)
	add(base, "wk_nom_m", props, wk_nom_m)
	add(base, "wk_nom_f", props, wk_nom_f)
	add(base, "wk_n", props, wk_n)
	add(base, "wk_obl_m", props, wk_obl_m)
	add(base, "wk_obl_f", props, wk_obl_f)
	add(base, "wk_p", props, wk_p)
end


-- Add the declension for one of the states (strong or weak). `state` is either "str_" or "wk_", i.e. the appropriate
-- state prefix for the slot. Only 17 of the 24 possible endings are given because some are always the same as others.
-- Currently we handle this syncretism in the table itself, meaning it's not possible to override the missing endings
-- separately. (FIXME: Is there ever a situation where we need to separately control such endings? If so, we probably
-- want to distinguish between "regular" overrides, which happen before the copying of some endings to others, and
-- "late" overrides, which happen after. A similar distinction occurs the Italian verb module.) Specifically:
-- * The neuter singular and plural accusative, and the feminine plural accusative, are taken from the nominative.
-- * There is only one dative and genitive plural ending, which applies to all genders.
local function add_decl(base, props,
	       nom_f, nom_n,
	acc_m, acc_f,      
	dat_m, dat_f, dat_n,
	gen_m, gen_f, gen_n,
	nom_mp, nom_fp, nom_np,
	acc_mp,
	dat_p,
	gen_p,
	wk_nom_m, wk_nom_f, wk_n,
	wk_obl_m, wk_obl_f,
	wk_p
)
	add_strong_decl(
		nom_f, nom_n, acc_m, acc_f,      
		dat_m, dat_f, dat_n, gen_m, gen_f, gen_n,
		nom_mp, nom_fp, nom_np, acc_mp,
		dat_p, gen_p
	)
	add_weak_decl(
		wk_nom_m, wk_nom_f, wk_n,
		wk_obl_m, wk_obl_f,
		wk_p
	)
end

local decls = {}

decls["normal"] = function(base, props)
	add_decl(base, props,
		      "^^",  "t",
		"an", "a",
		"um", "ri",  "u",
		"s",  "rar", nil,
		"ir", "ar", "^^",
		"a",
		"um",
		"ra",
		"i",  "a",   "a",
		"a",  "u",
		"u",
	)
end


decls["inn"] = function(base, props)
	add_decl(base, props,
		       "in",    "ið",
		"*",   "na",
		"num", "inni",  "nu",
		"ins", "innar", nil,
		"nir", "nar",   "in",
		"na",
		"num",
		"inna",
		"ni",  "na",    "na",
		"na",  "nu",
		"nu",
	)
end


decls["irreg"] = function(base, props)
	if base.lemma == "sá" then
		add_strong_decl(base, props,
					"sú", "það",
			"þann", "þá",
			"þeim", "þeirri", {"því", "þí"},
			"þess", "þeirrar", nil,
			"þeir", "þær", "þau",
			"þá",
			"þeim",
			"þeirra",
		)
		return
	end

	if base.lemma == "hann" then
		add_strong_decl(base, props,
					"hún", "það",
			"hann", "hana",
			"honum", "henni", {"því", "þí"},
			"hans", "hennar", "þess",
			"þeir", "þær", "þau",
			"þá",
			"þeim",
			"þeirra",
		)
		return
	end

	if base.lemma == "þessi" then
		add_strong_decl(base, props,
					"þessi", {"þetta", {form = "þettað", footnotes = {"uncommon"}}},
			{"þennan", {form = "þenna", footnotes = {"archaic"}}}, "þessa",
			"þessum", "þessari", "þessu",
			"þessa", "þessarar", nil,
			"þessir", "þessar", {"þessi", {form = "þaug", footnotes = {"uncommon"}}},
			"þessa",
			"þessum",
			"þessara",
		)
		return
	end

	if base.lemma == "hinn" then
		add_strong_decl(base, props,
					"hin", base.props.article and "hið" or "hitt",
			"hinn", "hina",
			"hinum", "hinni", "hinu",
			"hins", "hinnar", nil,
			"hinir", "hinar", "hin",
			"hina",
			"hinum",
			"hinna",
		)
		return
	end

	local stem = rmatch(base.lemma, "^([mþs])inn$")
	if stem then
		add_strong_decl(base, props,
					stem .. "ín", stem .. "itt",
			stem .. "inn", stem .. "ína",
			stem .. "ínum", stem .. "inni", stem .. "ínu",
			stem .. "íns", stem .. "innar", nil,
			stem .. "ínir", stem .. "ínar", stem .. "ín",
			stem .. "ína",
			stem .. "ínum",
			stem .. "inna",
		)
		return
	end

	if base.lemma == "vor" or base.lemma == "hvor" then
		stem = base.lemma
		add_strong_decl(base, props,
					stem, stem .. "t",
			stem .. "n", stem .. "a",
			stem .. "um", stem .. "ri", stem .. "u",
			stem .. "s", stem .. "rar", nil,
			stem .. "ir", stem .. "ar", stem,
			stem .. "a",
			stem .. "um",
			stem .. "ra",
		)
		return
	end

	local neutstem
	if base.lemma == "hver" then
		stem = "hver"
		neutstem = ""
	elseif base.lemma == "sérhver" then
		stem = "sérhver"
		neutstem = "sér"
	elseif base.lemma == "einhver" then
		stem = "einhver"
		neutstem = "eitt"
	end
	if stem then
		add_strong_decl(base, props,
					stem, {
						{form = neutstem .. "hvert", footnotes = {"used with a noun"}},
						{form = neutstem .. "hvað", footnotes = {"used alone"}},
					},
			stem .. "n", stem .. "ja",
			stem .. "jum", stem .. "ri", stem .. "ju",
			stem .. "s", stem .. "rar", nil,
			stem .. "jir", stem .. "jar", stem,
			stem .. "ja",
			stem .. "jum",
			stem .. "ra",
		)
		return
	end

	if base.lemma == "nokkur" then
		stem = "nokk"
		add_strong_decl(base, props,
					stem .. "ur", {
						{form = stem .. "urt", footnotes = {"used with a noun"}},
						{form = stem .. "uð", footnotes = {"used alone"}},
					},
			stem .. "urn", stem .. "ra",
			stem .. "rum", stem .. "urri", stem .. "ru",
			stem .. "urs", stem .. "urrar", nil,
			stem .. "rir", stem .. "rar", stem .. "ur",
			stem .. "ra",
			stem .. "rum",
			stem .. "urra",
		)
		return
	end

	if base.lemma == "enginn" then
		if base.props.archaic then
			add_strong_decl(base, props,
						  "engin", "ekkert",
				"öngvan", "öngva",
				"öngvum", "öngri", "öngvu",
				"einskis", "öngrar", nil,
				"öngvir", "öngvar", "engin",
				"öngva",
				"öngvum",
				"öngra",
			)
		else
			local engi = {form = "engi", footnotes = {"poetic"}}
			add_strong_decl_with_nom_sg(base, props,
				{"*", engi}, {"engin", engi}, {"ekkert", {form = "ekki", footnotes = {"in some fixed expressions"}}},
				"engan", "enga",
				"engum", "engri", {"engu", {"einugi", {footnotes = {"in some fixed expressions"}}}},
				{"einskis", {form = "einkis", footnotes = {"occasionally"}}}, "engrar", nil,
				"engir", "engar", "engin",
				"enga",
				"engum",
				"engra",
			)
	end

	if base.lemma == "einn" then
		error("FIXME")
		return
	end

	error("FIXME")

	error("Unrecognized irregular lemma '" .. base.lemma .. "'")
end


local function fetch_footnotes(separated_group)
	local footnotes
	for j = 2, #separated_group - 1, 2 do
		if separated_group[j + 1] ~= "" then
			error("Extraneous text after bracketed footnotes: '" .. table.concat(separated_group) .. "'")
		end
		if not footnotes then
			footnotes = {}
		end
		table.insert(footnotes, separated_group[j])
	end
	return footnotes
end


local function parse_indicator_spec(angle_bracket_spec)
	local inside = rmatch(angle_bracket_spec, "^<(.*)>$")
	assert(inside)
	local base = {forms = {}}
	if inside ~= "" then
		local parts = rsplit(inside, ".", true)
		for _, part in ipairs(parts) do
			if part == "irreg" then
				base.irreg = true
			elseif part == "short" then
				base.short = {{
					base = {
						form = "+",
					},
					stem = {
						form = "+",
					}
				}}
			elseif rfind(part, "^short:") then
				part = rsub(part, "^short:%s*", "")
				base.short = {}
				local segments = iut.parse_balanced_segment_run(part, "[", "]")
				local comma_separated_groups = iut.split_alternating_runs(segments, "%s*,%s*")
				for _, comma_separated_group in ipairs(comma_separated_groups) do
					if comma_separated_group[1] == "*" then
						-- reducible
						table.insert(base.short, {
							base = {
								form = "*",
								footnotes = fetch_footnotes(comma_separated_group),
							},
							stem = {
								form = "*",
								footnotes = fetch_footnotes(comma_separated_group),
							}
						})
					else
						local slash_separated_groups = iut.split_alternating_runs(comma_separated_group, "%s*/%s*")
						if #slash_separated_groups > 2 then
							error("Too many slash-separated stems: '" .. inside .. "'")
						end
						local short_base = slash_separated_groups[1]
						local short_stem = slash_separated_groups[2]
						local short_base_obj = {
							form = short_base[1],
							footnotes = fetch_footnotes(short_base),
						}
						local short_stem_obj
						if short_stem then
							short_stem_obj = {
								form = short_stem[1],
								footnotes = fetch_footnotes(short_stem),
							}
						end
						table.insert(base.short, {
							base = short_base_obj,
							stem = short_stem_obj,
						})
					end
					iut.insert_form(forms, slot, formobj)
				end
			else
				error("Unrecognized indicator '" .. part .. "': '" .. inside .. "'")
			end
		end
	end
	return base
end


local function normalize_all_lemmas(alternant_multiword_spec, pagename)
	iut.map_word_specs(alternant_multiword_spec, function(base)
		if base.lemma == "" then
			base.lemma = pagename
		end
		base.orig_lemma = base.lemma
		base.orig_lemma_no_links = m_links.remove_links(base.lemma)
		base.lemma = base.orig_lemma_no_links
	end)
end


-- Determine the declension based on the lemma. The declension is set in base.decl. In the process, we set either
-- base.vowel_stem (if the lemma ends in a vowel) or base.nonvowel_stem (if the lemma does not end in a
-- vowel), which is used by determine_props(). In some cases (specifically with certain foreign nouns), we set
-- base.lemma to a new value; this is as if the user specified 'decllemma:'.
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
			base.decl = "normal"
			base.double_r = true
		end
	end
	if not stem then
		-- There must be at least one vowel; lemmas like [[bur]] don't count.
		stem, ending = rmatch(base.lemma, "^(.*" .. com.vowel_or_hyphen_c .. ".*)(ur)$")
		if stem then
			if base.stem == base.lemma then
				-- [[dapur]] "sad" etc. where the stem includes the final -r
				stem = base.stem
				ending = "" -- not actually used
				default_props.con = "con"
			end
			-- [[gulur]] "yellow" and lots of others
			base.decl = "m"
		end
	end
	if not stem then
		stem, ending = rmatch(base.lemma, "^(.*l)(l)$")
		if stem then
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
	if not stem then
		error("FIXME")
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
		-- Miscellaneous terms without ending
		stem = base.lemma
		base.decl = "m"
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
		-- Convert regular `umut` to `u_mut` (applying to the second-to-last syllable) when contraction is in place and
		-- we're computing the u-mutation version of the non-vowel stem. Cf. [[dapur]] "sad" with nominative feminine
		-- singular [[döpur]].
		local function map_nonvstem_umut(val)
			if val == "umut" and props.con and props.con.form == "con" then
				return "u_mut"
			else
				return val
			end
		end

		-- All adjectives have u-mutation in the feminine singular and neuter plural (among others), which triggers
		-- u-mutation, so we need to compute the u-mutation stem using "umut" if not specifically given. Set `defaulted`
		-- so an error isn't triggered if there's no special u-mutated form.
		local props_umut = props.umut
		if not props_umut then
			props_umut = {form = "umut", defaulted = true}
		end

		-- First do all the stems.
		local base_stem, base_vstem = base.stem,base.vstem
		local stem, nonvstem, umut_nonvstem, vstem, umut_vstem
		stem = base_stem
		nonvstem = stem
		umut_nonvstem = com.apply_u_mutation(nonvstem, map_nonvstem_umut(props_umut.form), not props_umut.defaulted)
		vstem = base_vstem or base_stem
		if props.con and props.con.form == "con" then
			vstem = com.apply_contraction(vstem)
		end
		umut_vstem = com.apply_u_mutation(vstem, props_umut.form, not props_umut.defaulted)

		props.stem = stem
		if nonvstem ~= stem then
			props.nonvstem = nonvstem
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
			props.umut_nonvstem = umut_nonvstem
		end
		if vstem ~= stem or props.con and props.con.footnotes then
			-- See comment above for why we need to check for props.con.footnotes (basically, to handle footnotes on
			-- -con).
			if props.con then
				vstem = iut.combine_form_and_footnotes(vstem, props.con.footnotes)
			end
			props.vstem = vstem
		end
		if umut_vstem ~= vstem or props.con and props.con.footnotes then
			-- See comment above under `umut_nonvstem ~= nonvstem`. There's no -umut so whenever there's a specific
			-- umut variant with footnote, umut_vstem will be different from vstem so we don't need to check for
			-- `or props_umut and props_umut.footnotes` above.
			local footnotes = iut.combine_footnotes(props.con and props.con.footnotes or nil,
				props_umut and props_umut.footnotes or nil)
			umut_vstem = iut.combine_form_and_footnotes(umut_vstem, footnotes)
			props.umut_vstem = umut_vstem
		end

		-- Do the j-infix property.
		if props.j then
			props.jinfix = props.j.form == "j" and "j" or ""
			props.jinfix_footnotes = props.j.footnotes
			props.j = nil
		end
	end
end


local function detect_indicator_spec(base)
	if base.short then
		if not base.lemma:find("ý$") then
			error("Short forms can only be specified for lemmas ending in -ý, but saw '" .. base.lemma .. "'")
		end
		local stem = rmatch(base.lemma, "^(.*)ý$")
		for _, short_spec in ipairs(base.short) do
			if short_spec.base.form == "+" then
				short_spec.base.form = stem
			elseif short_spec.base.form == "*" then
				short_spec.base.form = com.dereduce(base, stem)
				if not short_spec.base.form then
					error("Unable to construct non-reduced variant of stem '" .. stem .. "'")
				end
			end
			if not short_spec.stem then
				short_spec.stem = {
					form = short_spec.base.form,
					footnotes = short_spec.base.footnotes
				}
			end
			if short_spec.stem.form == "+" or short_spec.stem.form == "*" then
				short_spec.stem.form = stem
			end
		end
	end

	if base.irreg then
		base.decl = "irreg"
	else
		base.decl = "normal"
	end
end


local function detect_all_indicator_specs(alternant_multiword_spec)
	iut.map_word_specs(alternant_multiword_spec, function(base)
		detect_indicator_spec(base)
	end)
end


local function decline_adjective(base)
	if not decls[base.decl] then
		error("Internal error: Unrecognized declension type '" .. base.decl .. "'")
	end
	decls[base.decl](base)
	-- handle_derived_slots_and_overrides(base)
end


-- Process override for the arguments in `args`, storing the results into `forms`. If `do_acc`, only do accusative
-- slots; otherwise, don't do accusative slots.
local function process_overrides(forms, args, do_acc)
	for slot, _ in pairs(input_adjective_slots) do
		if args[slot] and not not do_acc == not not slot:find("^acc") then
			forms[slot] = nil
			if args[slot] ~= "-" and args[slot] ~= "—" then
				local segments = iut.parse_balanced_segment_run(args[slot], "[", "]")
				local comma_separated_groups = iut.split_alternating_runs(segments, "%s*,%s*")
				for _, comma_separated_group in ipairs(comma_separated_groups) do
					local formobj = {
						form = comma_separated_group[1],
						footnotes = fetch_footnotes(comma_separated_group),
					}
					iut.insert_form(forms, slot, formobj)
				end
			end
		end
	end
end


local function check_allowed_overrides(alternant_multiword_spec, args)
	local special = alternant_multiword_spec.special or alternant_multiword_spec.surname and "surname" or ""
	for slot, types in pairs(input_adjective_slots) do
		if args[slot] then
			local allowed = false
			for _, typ in ipairs(types) do
				if typ == special then
					allowed = true
					break
				end
			end
			if not allowed then
				error(("Override %s= not allowed for %s"):format(slot, special == "" and "regular declension" or
					"special=" .. special))
			end
		end
	end
end


local function set_accusative(alternant_multiword_spec)
	local forms = alternant_multiword_spec.forms
	local function copy_if(from_slot, to_slot)
		if not forms[to_slot] then
			iut.insert_forms(forms, to_slot, forms[from_slot])
		end
	end

	copy_if("nom_n", "acc_n")
	copy_if("gen_mn", "acc_m_an")
	copy_if("nom_m", "acc_m_in")
	copy_if("nom_fp", "acc_mfp")
	copy_if("nom_np", "acc_np")
end


local function add_categories(alternant_multiword_spec)
	local cats = {}
	local plpos = m_string_utilities.pluralize(alternant_multiword_spec.pos or "adjective")
	local function insert(cattype)
		m_table.insertIfNot(cats, "Icelandic " .. cattype .. " " .. plpos)
	end
	if not alternant_multiword_spec.manual then
		iut.map_word_specs(alternant_multiword_spec, function(base)
			if base.decl == "irreg" then
				insert("irregular")
			elseif rfind(base.lemma, "ý$") then
				insert("hard")
			elseif rfind(base.lemma, "í$") then
				insert("soft")
			else
				insert("possessive")
			end
			if base.short then
				table.insert(cats, "Icelandic " .. plpos .. " with short forms")
			end
		end)
	end
	alternant_multiword_spec.categories = cats
end


local function show_forms(alternant_multiword_spec)
	local lemmas = {}
	local lemmaform = alternant_multiword_spec.forms.nom_m or alternant_multiword_spec.forms.nom_mp or
		alternant_multiword_spec.forms.nom_mp_an
	if lemmaform then
		for _, form in ipairs(lemmaform) do
			table.insert(lemmas, form.form)
		end
	end
	local props = {
		lemmas = lemmas,
		slot_table = get_output_adjective_slots(alternant_multiword_spec),
		lang = lang,
	}
	iut.show_forms(alternant_multiword_spec.forms, props)
end


local function make_table(alternant_multiword_spec)
	local forms = alternant_multiword_spec.forms

	local function template_prelude(min_width)
		min_width = min_width or "40"
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

	local table_spec_left_rail = [=[
! class="is-left-rail" style="width:20%;" rowspan=TOTALROWS | STATE declension <br /> (DEFINITENESS)
]=]

	local table_spec_parts = {
		str_sg = [=[
! class="is-col-header" | singular
! class="is-col-header" | masculine
! class="is-col-header" | feminine
! class="is-col-header" | neuter
|-
!class="is-row-header"|nominative
| {COMPSUPstr_nom_m}
| {COMPSUPstr_nom_f}
| rowspan=2 | {COMPSUPstr_nom_n}
|-
!class="is-row-header"|accusative
| {COMPSUPstr_acc_m}
| {COMPSUPstr_acc_f}
|-
!class="is-row-header"|dative
| {COMPSUPstr_dat_m}
| {COMPSUPstr_dat_f}
| {COMPSUPstr_dat_n}
|-
!class="is-row-header"|genitive
| {COMPSUPstr_gen_m}
| {COMPSUPstr_gen_f}
| {COMPSUPstr_gen_n}
]=],

		str_pl = [=[
! class="is-col-header" | plural
! class="is-col-header" | masculine
! class="is-col-header" | feminine
! class="is-col-header" | neuter
|-
!class="is-row-header"|nominative
| {COMPSUPstr_nom_mp}
| rowspan=2 | {COMPSUPstr_nom_fp}
| rowspan=2 | {COMPSUPstr_nom_np}
|-
!class="is-row-header"|accusative
| {COMPSUPstr_acc_mp}
|-
!class="is-row-header"|dative
| colspan=3 | {COMPSUPstr_dat_p}
|-
!class="is-row-header"|genitive
| colspan=3 | {COMPSUPstr_gen_p}
]=],

		wk_sg = [=[
! class="is-col-header" | singular
! class="is-col-header" | masculine
! class="is-col-header" | feminine
! class="is-col-header" | neuter
|-
!class="is-row-header"|nominative
| {COMPSUPwk_nom_m}
| {COMPSUPwk_nom_f}
| rowspan=4 | {COMPSUPwk_n}
|-
!class="is-row-header"|accusative
| rowspan=3 | {COMPSUPwk_obl_m}
| rowspan=3 | {COMPSUPwk_obl_f}
|-
!class="is-row-header"|dative
|-
!class="is-row-header"|genitive
]=],

		wk_pl = [=[
! class="is-col-header" | plural
! class="is-col-header" | masculine
! class="is-col-header" | feminine
! class="is-col-header" | neuter
|-
!class="is-row-header"|nominative
| rowspan=4 colspan=3 | {COMPSUPwk_p}
|-
!class="is-row-header"|accusative
|-
!class="is-row-header"|dative
|-
!class="is-row-header"|genitive
]=]
}

	local function format_left_rail(state, totalrows)
		return (table_spec_left_rail:gsub("TOTALROWS", tostring(totalrows)):gsub("STATE", state == "wk" and "weak")
			:gsub("DEFINITENESS", state == "wk" and "definite" or "indefinite"))
	end

	local function construct_table(compsup, inside)
		local parts = {}
		local function ins(txt)
			table.insert(parts, txt)
		end
		ins(template_prelude())
		inside(ins)
		ins(template_postlude())
		return (table.concat(parts):gsub("COMPSUP", compsup))
	end

	local function get_table_spec_one_number_one_state(compsup, number, state, omit_state)
		return construct_table(compsup, function(ins)
			if not omit_state then
				ins(format_left_rail("wk", 5))
			end
			ins(table_spec_parts[state .. "_" .. number])
		end)
	end

	local function get_table_spec_all_number_one_state(compsup, state, omit_state)
		return construct_table(compsup, function(ins)
			if not omit_state then
				ins(format_left_rail("wk", 10))
			end
			ins(table_spec_parts[state .. "_sg"])
			ins(table_spec_parts[state .. "_pl"])
		end)
	end

	local function get_table_spec_one_number_all_state(compsup, number)
		return construct_table(compsup, function(ins)
			ins(format_left_rail("str", 5))
			ins(table_spec_parts["str_" .. number])
			ins(format_left_rail("wk", 5))
			ins(table_spec_parts["wk_" .. number])
		end)
	end

	local function get_table_spec_all_number_all_state(compsup)
		return construct_table(compsup, function(ins)
			ins(format_left_rail("str", 10))
			ins(table_spec_parts["str_sg"])
			ins(table_spec_parts["str_pl"])
			ins(format_left_rail("wk", 10))
			ins(table_spec_parts["wk_sg"])
			ins(table_spec_parts["wk_pl"])
		end)
	end

	local ital_lemma = '<i lang="is" class="Latn">' .. forms.lemma .. "</i>"

	local annotation = alternant_multiword_spec.annotation
	if annotation == "" then
		forms.annotation = ""
	else
		forms.annotation = " (<span style=\"font-size: smaller;\">" .. annotation .. "</span>)"
	end

	-- Format the positive table.
	local positive_table_spec = rsub(table_spec, "COMPSUP", "")
	forms.title = "positive forms of " .. ital_lemma
	forms.footnote = alternant_multiword_spec.footnote_positive
	forms.notes_clause = forms.footnote ~= "" and m_string_utilities.format(notes_template, forms) or ""
	local positive_table = m_string_utilities.format(positive_table_spec, forms)

	-- Maybe format the comparative table.
	local comparative_table = ""
	if alternant_multiword_spec.props.has_comp then
		local comparative_table_spec = rsub(table_spec, "COMPSUP", "comp_")
		forms.title = "comparative forms of " .. ital_lemma
		forms.footnote = alternant_multiword_spec.footnote_comparative
		forms.notes_clause = forms.footnote ~= "" and m_string_utilities.format(notes_template, forms) or ""
		comparative_table = m_string_utilities.format(comparative_table_spec, forms)
	end

	-- Maybe format the superlative table.
	local superlative_table = ""
	if alternant_multiword_spec.props.has_sup then
		local superlative_table_spec = rsub(table_spec, "COMPSUP", "sup_")
		forms.title = "superlative forms of " .. ital_lemma
		forms.footnote = alternant_multiword_spec.footnote_superlative
		forms.notes_clause = forms.footnote ~= "" and m_string_utilities.format(notes_template, forms) or ""
		superlative_table = m_string_utilities.format(superlative_table_spec, forms)
	end

	-- Paste them together.
	return positive_table .. comparative_table .. superlative_table




	local table_spec = template_prelude("55") .. table_spec_sg .. "|-\n" .. table_spec_pl .. template_postlude()

	local table_spec_plonly = template_prelude("55") .. table_spec_pl .. template_postlude()

	local table_spec_dva = template_prelude("40") .. [=[
! style="width:40%;background:#d9ebff" colspan="2" | 
! style="background:#d9ebff" colspan="2" | plural
|-
! style="width:40%;background:#d9ebff" colspan="2" | 
! style="background:#d9ebff" | masculine
! style="background:#d9ebff" | feminine/neuter
|-
! style="background:#eff7ff" colspan="2" | nominative
| {nom_mp}
| {nom_fnp}
|-
! style="background:#eff7ff" colspan="2" | genitive
| colspan="2" | {gen_p} 
|-
! style="background:#eff7ff" colspan="2" | dative
| colspan="2" | {dat_p} 
|-
! style="background:#eff7ff" colspan="2" | accusative
| {acc_mp}
| {acc_fnp}
|-
! style="background:#eff7ff" colspan="2" | locative
| colspan="2" | {loc_p} 
|-
! style="background:#eff7ff" colspan="2" | instrumental
| colspan="2" | {ins_p} 
]=] .. template_postlude()

	local short_sg_template = [=[

|-
! style="background:#eff7ff" | short
| colspan=2 | {short_m}
| {short_f}
| {short_n}
]=]

	local short_pl_template = [=[

|-
! style="background:#eff7ff" | short
| {short_mp_an}
| colspan=2 | {short_fp}
| {short_np}]=]

	local notes_template = [===[
<div style="width:100%;text-align:left;background:#d9ebff">
<div style="display:inline-block;text-align:left;padding-left:1em;padding-right:1em">
{footnote}
</div></div>
]===]

	if alternant_multiword_spec.title then
		forms.title = alternant_multiword_spec.title
	else
		forms.title = 'Declension of <i lang="is">' .. forms.lemma .. '</i>'
	end

	if alternant_multiword_spec.manual then
		forms.annotation = ""
	else
		local ann_parts = {}
		local decls = {}
		iut.map_word_specs(alternant_multiword_spec, function(base)
			if base.decl == "irreg" then
				m_table.insertIfNot(decls, "irregular")
			elseif rfind(base.lemma, "ý$") then
				m_table.insertIfNot(decls, "hard")
			elseif rfind(base.lemma, "í$") then
				m_table.insertIfNot(decls, "soft")
			else
				m_table.insertIfNot(decls, "possessive")
			end
		end)
		table.insert(ann_parts, table.concat(decls, " // "))
		forms.annotation = " (" .. table.concat(ann_parts, ", ") .. ")"
	end

	forms.notes_clause = forms.footnote ~= "" and
		m_string_utilities.format(notes_template, forms) or ""
	forms.short_sg_clause = forms.short_m and forms.short_m ~= "—" and
		m_string_utilities.format(short_sg_template, forms) or ""
	forms.short_pl_clause = forms.short_mp_an and forms.short_mp_an ~= "—" and
		m_string_utilities.format(short_pl_template, forms) or ""
	return m_string_utilities.format(
		alternant_multiword_spec.special == "plonly" and table_spec_plonly or
		alternant_multiword_spec.special == "dva" and table_spec_dva or
		table_spec, forms
	)
end

-- Externally callable function to parse and decline an adjective given
-- user-specified arguments. Return value is WORD_SPEC, an object where the
-- declined forms are in `WORD_SPEC.forms` for each slot. If there are no values
-- for a slot, the slot key will be missing. The value for a given slot is a
-- list of objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms(parent_args, pos, from_headword, def)
	local params = {
		[1] = {},
		pos = {},
		json = {type = "boolean"}, -- for use with bots
		title = {},
		pagename = {},
	}
	for slot, _ in pairs(input_adjective_slots) do
		params[slot] = {}
	end

	-- Only default param 1 when displaying the template.
	local args = require("Module:parameters").process(parent_args, params)
	local SUBPAGE = mw.title.getCurrentTitle().subpageText
	local pagename = args.pagename or SUBPAGE
	if not args[1] then
		if SUBPAGE == "is-adecl" then
			args[1] = "křepký<short:*>"
		else
			args[1] = pagename
		end
	end		
	local parse_props = {
		parse_indicator_spec = parse_indicator_spec,
		allow_default_indicator = true,
		allow_blank_lemma = true,
	}
	local alternant_multiword_spec = iut.parse_inflected_text(args[1], parse_props)
	alternant_multiword_spec.pos = args.pos
	alternant_multiword_spec.title = args.title
	alternant_multiword_spec.forms = {}
	normalize_all_lemmas(alternant_multiword_spec, pagename)
	detect_all_indicator_specs(alternant_multiword_spec)
	check_allowed_overrides(alternant_multiword_spec, args)
	local inflect_props = {
		slot_table = get_output_adjective_slots(alternant_multiword_spec),
		inflect_word_spec = decline_adjective,
	}
	iut.inflect_multiword_or_alternant_multiword_spec(alternant_multiword_spec, inflect_props)
	-- Do non-accusative overrides so they get copied to the accusative forms appropriately.
	process_overrides(alternant_multiword_spec.forms, args)
	set_accusative(alternant_multiword_spec)
	-- Do accusative overrides after copying the accusative forms.
	process_overrides(alternant_multiword_spec.forms, args, "do acc")
	add_categories(alternant_multiword_spec)
	if args.json and not from_headword then
		return require("Module:JSON").toJSON(alternant_multiword_spec)
	end
	return alternant_multiword_spec
end


-- Externally callable function to parse and decline an adjective where all
-- forms are given manually. Return value is WORD_SPEC, an object where the
-- declined forms are in `WORD_SPEC.forms` for each slot. If there are no values
-- for a slot, the slot key will be missing. The value for a given slot is a
-- list of objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms_manual(parent_args, pos, from_headword, def)
	local params = {
		pos = {},
		special = {},
		json = {type = "boolean"}, -- for use with bots
		title = {},
	}
	for slot, _ in pairs(input_adjective_slots) do
		params[slot] = {}
	end

	local args = require("Module:parameters").process(parent_args, params)
	local alternant_multiword_spec = {
		pos = args.pos,
		special = args.special,
		title = args.title, 
		forms = {},
		manual = true,
	}
	check_allowed_overrides(alternant_multiword_spec, args)
	-- Do non-accusative overrides so they get copied to the accusative forms appropriately.
	process_overrides(alternant_multiword_spec.forms, args)
	set_accusative(alternant_multiword_spec)
	-- Do accusative overrides after copying the accusative forms.
	process_overrides(alternant_multiword_spec.forms, args, "do acc")
	add_categories(alternant_multiword_spec)
	if args.json and not from_headword then
		return require("Module:JSON").toJSON(alternant_multiword_spec)
	end
	return alternant_multiword_spec
end


-- Entry point for {{is-adecl}}. Template-callable function to parse and decline 
-- an adjective given user-specified arguments and generate a displayable table
-- of the declined forms.
function export.show(frame)
	local parent_args = frame:getParent().args
	local alternant_multiword_spec = export.do_generate_forms(parent_args)
	show_forms(alternant_multiword_spec)
	return make_table(alternant_multiword_spec) .. require("Module:utilities").format_categories(alternant_multiword_spec.categories, lang)
end


-- Entry point for {{is-adecl-manual}}. Template-callable function to parse and
-- decline an adjective given manually-specified inflections and generate a
-- displayable table of the declined forms.
function export.show_manual(frame)
	local parent_args = frame:getParent().args
	local alternant_multiword_spec = export.do_generate_forms_manual(parent_args)
	show_forms(alternant_multiword_spec)
	return make_table(alternant_multiword_spec) .. require("Module:utilities").format_categories(alternant_multiword_spec.categories, lang)
end


return export
