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

1. Support 'plstem' overrides.
2. Support definite lemmas such as [[Bandaríkin]] "the United States".
3. Support adjectivally-declined terms.
4. Support @ for built-in irregular lemmas.
5. Somehow if the user specifies v-infix, it should prevent default unumut from happening in strong feminines.
]=]

local lang = require("Module:languages").getByCode("is")
local m_table = require("Module:table")
local m_links = require("Module:links")
local m_string_utilities = require("Module:string utilities")
local iut = require("Module:inflection utilities")
local m_para = require("Module:parameters")
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
local usub = mw.ustring.sub
local uupper = mw.ustring.upper
local ulower = mw.ustring.lower
local dump = mw.dumpObject

local force_cat = false -- set to true to make categories appear in non-mainspace pages, for testing

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
	nom = true,
	acc = true,
	dat = true,
	gen = true,
}

local overridable_stems = {
	stem = true,
	vstem = true,
	plstem = true,
}

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


local function get_output_noun_slots(alternant_multiword_spec)
	local output_noun_slots = {}
	for _, def in ipairs {"ind", "def"} do
		for _, case in ipairs(cases) do
			for _, num in {"s", "p"} do
				local slot = ("%s_%s_%s"):format(def, case, num)
				local accel = ("%s|%s"):format(def, case)
				if alternant_multiword_spec.actual_number == "both" then
					accel = accel .. "|" .. num
				end
				output_noun_slots[slot] = accel
			end
		end
	end
	for _, potential_lemma_slot in ipairs(potential_lemma_slots) do
		output_noun_slots[potential_lemma_slot .. "_linked"] = output_noun_slots[potential_lemma_slot]
	end
	return output_noun_slots
end


local function generate_list_of_possibilities_for_err(list)
	local quoted_list = {}
	for _, item in pairs(list) do
		table.insert(quoted_list, "'" .. item .. "'")
	end
	table.sort(quoted_list)
	return m_table.serialCommaJoin(quoted_list, {dontTag = true})
end


local function skip_slot(number, slot)
	return number == "sg" and rfind(slot, "_p$") or
		number == "pl" and rfind(slot, "_s$")
end


-- Basic function to combine stem(s) and other properties with ending(s) and insert the result into the appropriate
-- slot. `base` is the object describing all the properties of the word being inflected for a single alternant (in case
-- there are multiple alternants specified using `((...))`). `slot_prefix` is either "ind_" or "def_" and is prefixed to
-- the slot value in `slot` to get the actual slot to add the resulting forms to. (`slot_prefix` is separated out
-- because the code below frequently needs to conditionalize on the value of `slot` and should not have to worry about
-- the definite and indefinite slot variants). `props` is an object containing computed stems and other information
-- (such as whether i-mutation is active). The information found in `props` cannot be stored in `base` because there may
-- be more than one set of such properties per `base` (e.g. if the user specified 'umut,uumut' or '-j,j' or '-imut,imut'
-- or some combination of these; in such a case, the caller will iterate over all possible combinations, and ultimately
-- invoke add() multiple times, one per combination). `endings` is the ending or endings added to the appropriate stem
-- (after any j or v infix) to get the form(s) to add to the slot. Its value can be a single string, a list of strings,
-- or a list of form objects (i.e. in general list form). `clitics` is the clitic or clitics to add after the endings to
-- form the actual form value inserted into definite slots; it should be nil for indefinite slots. Its format is the
-- same as for `endings`. `ending_override`, if true, indicates that the ending(s) supplied in `endings` come from a
-- user-specified override, and hence j and v infixes should not be added as they are already included in the override
-- if needed.
--
-- The properties in `props` are:
-- * Stems (each stem should be in general list form; see [[Module:inflection utilities]]);
-- ** `stems`: The basic stem(s). May be overridden by more specific variants.
-- ** `nonvstems`: The stem(s) used when the ending is null or starts with a consonant, unless overridden by a more
--    specific variant. Defaults to `stems`.
-- ** `umut_nonvstems`: The stem(s) used when the ending is null or starts with a consonant and u-mutation is in effect,
--    unless overridden by a more specific variant. Defaults to `nonvstems`.
-- ** `imut_nonvstems`: The stem(s) used when the ending is null or starts with a consonant and i-mutation is in effect.
--    If i-mutation is in effect, this should always be specified (otherwise an internal error will occur); hence it has
--    no default.
-- ** `vstems`: The stem(s) used when the ending starts with a vowel, unless overridden by a more specific variant.
--    Defaults to `stems`.
-- ** `umut_vstems`: The stem(s) used when the ending starts with a vowel and u-mutation is in effect. Defaults to
--    `vstems`.
-- ** `imut_vstems`: The stem(s) used when the ending starts with a vowel and i-mutation is in effect. If i-mutation is
--    in effect, this should always be specified (otherwise an internal error will occur); hence it has no default.
-- ** `null_defvstems`: The stem(s) used when the ending is null and is followed by a definite ending that begins with a
--    vowel, unless overridden by a more specific variant. Defaults to `nonvstems`. This is normally set when `defcon`
--    is specified.
-- ** `umut_null_defvstems`: The stem(s) used when the ending is null and is followed by a definite ending that begins
--    with a vowel, and u-mutation is in effect. Defaults to `umut_nonvstems`. This is normally set when `defcon` is
--    specified and u-mutation is needed, as in the nom/acc pl of neuter [[mastur]] "mast".
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
-- ** `unumut`: If specified (i.e. not nil), the type of un-u-mutation requested (either "unumut" or "unuumut", or the
--    negation of the same using "-unumut" or "-unuumut" for no un-u-mutation; the two differ in which slots any
--    associated footnote are placed). If specified, there may be associated footnotes in `unumut_footnotes`. If
--    "unumut", u-mutation is in effect *except* before an ending that starts with an "a" or "i" (unless i-mutation is
--    in effect, which takes precedence). If "unuumut", the rules are different: when masculine, u-mutation is in effect
--    *except* in the gen sg and pl (examples are [[söfnuður]] "congregation" and [[mánuður]] "month"); when feminine,
--    u-mutation is in effect except in the nom/acc/gen pl (examples are [[verslun]] "trade, business; store, shop" and
--    [[kvörtun]] "complaint"; also note [[örvun]] "encouragement; stimulation" where the un-u-mutated form is 'örvan-'
--    rather than expected #'arvan-', because the -v- blocks the un-u-mutation of ö). When u-mutation is *not* in
--    effect, and i-mutation is also not in effect, the associated footnotes in `unumut_footnotes` apply. If `unumut` is
--    "-unumut" or "-unuumut", there is no un-u-mutation (i.e. there are no special u-mutated stems, and the basic
--    stems, which typically have u-mutation built into them, apply throughout), but the associated footnotes in
--    `unumut_footnotes` still apply in the same circumstances where they would apply if `unumut` were "unumut" or
--    "unuumut".
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
local function add_slotval(base, slot_prefix, slot, props, endings, clitics, ending_override)
	if not endings then
		return
	end
	-- Call skip_slot() based on the declined number; if the actual number is different, we correct this in
	-- decline_noun() at the end.
	if skip_slot(base.number, slot) then
		return
	end
	footnotes = iut.combine_footnotes(base.footnotes, footnotes)
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
			local function interr(msg)
				error(("Internal error: For slot '%s%s', ending '%s', %s: %s"):format(slot_prefix, slot, ending, msg,
				dump(props)))
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
						interr("'unumut' and 'unuumut' shouldn't be specified with neuter nouns; don't know what slots would be affected; neuter pluralia tantum nouns using 'unumut'/'unuumut' should have synthesized a singular without u-mutation")
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
				if ending_in_u and not mut_in_effect and not mut_not_in_effect then
					-- FIXME: I hope the `not mut_not_in_effect` is correct here.
					mut_in_effect = "u"
					-- umut and uumut footnotes are incorporated into the appropriate umut_* stems
				end
			end

			-- Now compute the appropriate stems to which the ending and clitic are added.
			if mut_in_effect == "i" then

				-- NOTE: It appears that imut and defcon never co-occur; otherwise we'd need to flesh out the set of
				-- stems to include i-mutation versions of defcon stems, similar to what we do for u-mutation.
				if is_vowel_ending then
					if not stems.imut_vstems then
						interr("i-mutation in effect and ending begins with a vowel but '.imut_vstems' not defined")
					end
					stems = stems.imut_vstems
				else
					if not stems.imut_nonvstems then
						interr("i-mutation in effect and ending does not begin with a vowel but '.imut_nonvstems' not defined")
					end
					stems = stems.imut_nonvstems
				end
			else
				-- Careful with the following logic; it is written carefully and should not be changed without a
				-- thorough understanding of its functioning.
				local has_umut = mut_in_effect == "u"
				-- First, if the ending is null, and we have a vowel-initial definite-article clitic, use the special
				-- 'defcon' stems if available. We do this even if the ending is "*", which normally means to use the
				-- lemma regardless (which avoids problems with e.g. thinking that the masculine singular nominative
				-- ending -ur would trigger u-mutation, which will happen if we construct the nominative singular from
				-- the stem instead of just using the lemma directly).  The reason for this is that when 'defcon' is
				-- active, it applies to the nominative singular, producing e.g. definite [[mastrið]] of neuter lemma
				-- [[mastur]] "mast"; here, using the lemma would incorrectly produce #[[masturið]].
				if (ending == "" or ending == "*") and is_vowel_clitic then
					if has_umut then
						stems = stems.umut_null_defvstems
					else
						stems = stems.null_defvstems
					end
				end
				-- If the stems were not set above and the ending is "*", it means to use the lemma as the form directly
				-- (before adding any definite clitic) rather than try to construct the form from a stem and ending. See
				-- the comment above for why we want to do this.
				if not stems and ending == "*" then
					stems = base.actual_lemma
					ending = ""
				end
				-- If the stems are still unset, then use the vowel or non-vowel stems if available. When u-mutation is
				-- active, we first check for u-mutated versions of the vowel or non-vowel stems before falling back to
				-- the regular vowel or non-vowel stems. Note that an expression like `has_umut and stems.umut_vstems or
				-- stems.vstems` here is NOT equivalent to an if-else or ternary operator expression because if
				-- `has_umut` is true and `umut_vstems` is missing, it will still fall back to `vstems` (which is what
				-- we want).
				if not stems then
					if is_vowel_ending then
						stems = has_umut and stems.umut_vstems or stems.vstems
					else
						stems = has_umut and stems.umut_nonvstems or stems.nonvstems
					end
				end
				-- Finally, fall back to the basic stems, which are always defined.
				stems = stems or stems.stems
			end

			local infix, infix_footnotes
			-- Compute the infix (j, v or nothing) that goes between the stem and ending.
			if not ending_override and is_vowel_ending then
				if props.vinfix and props.jinfix then
					interr("can't have specifications for both '.vinfix' and '.jinfix'; should have been caught above")
				end
				if props.vinfix then
					infix = props.vinfix
					infix_footnotes = props.vinfix_footnotes
				elseif props.jinfix and not ending_in_i then
					infix = props.jinfix
					infix_footnotes = props.jinfix_footnotes
				end
			end

			-- If base-level footnotes specified, they go before any stem footnotes, so we need to clone the stems an
			-- insert the base-level footnotes appropriately. In general, we want the footnotes to be in the order
			-- [base.footnotes, stem.footnotes, mut_footnotes, infix_footnotes, ending.footnotes, clitic.footnotes].
			if base.footnotes then
				local stems_with_footnotes = {}
				for _, stem in ipairs(stems) do
					stem = m_table.shallowcopy(stem)
					stem.footnotes = iut.combine_footnotes(base.footnotes, stem.footnotes)
					table.insert(stems_with_footnotes, stem)
				end
				stems = stems_with_footnotes
			end

			local function combine_stem_ending(stem, clitic)
				if stem == "?" then
					return "?"
				end
				local function drop_clitic_i()
					clitic = clitic:gsub("^i", "")
				end
				-- % at the end of a definite ending indicates that the following i- of the clitic should drop; see above.
				if clitic_i_drops then
					drop_clitic_i()
				end
				local stem_with_infix = stem .. (infix or "")
				-- Drop final -j- of stem before an ending beginning with a consonant. This happens e.g. in [[kirkja]]
				-- "church" with genitive plural -na, producing [[kirkna]]. It does not happen with a null ending; cf.
				-- neuter [[emj]] "cries, shouting" and [[gremj]] "anger, irritation" (the latter not in BÍN).
				if stem_with_infix:find("j$") and rfind(ending, "^" .. com.c) then
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
					if ending:find("[aiu]$") then
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
			iut.add_forms(base.forms, slot_prefix .. slot, stems, clitic_with_notes, combine_stem_ending)
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
local function add(base, slot, props, endings)
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
	if indef_endings then
		add_slotval(base, "ind_", slot, props, indef_endings)
	end
	if def_endings then
		local clitic = clitic_articles[base.gender]
		if not clitic then
			error(("Internal error: Unrecognized value for base.gender: %s"):format(dump(base.gender)))
		end
		clitic = clitic[slot]
		if not clitic then
			error(("Internal error: Unrecognized value for `slot` in add(): %s"):format(dump(slot)))
		end
		add_slotval(base, "def_", slot, props, def_endings, clitic)
	end
end


-- Generate the accusative plural ending from the nominative plural. For feminines and neuters, both are the same.
-- For masculines, drop the -r except in -ur.
local function acc_p_from_nom_p(base, nom_p)
	if base.gender == "f" or base.gender == "n" then
		return nom_p
	end
	if not nom_p then
		return nom_p
	end
	local function form_masc_acc_p(ending)
		if ending:find("^%^*ur$") then
			return ending
		else
			return (ending:gsub("r$", ""))
		end
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


local function process_slot_overrides(base, do_slot)
	-- FIXME: Rewrite for Icelandic
	for slot, overrides in pairs(base.overrides) do
		-- Call skip_slot() based on the declined number; if the actual number is different, we correct this in
		-- decline_noun() at the end.
		if skip_slot(base.number, slot) then
			error("Override specified for invalid slot '" .. slot .. "' due to '" .. base.number .. "' number restriction")
		end
		if do_slot(slot) then
			base.slot_overridden[slot] = true
			base.forms[slot] = nil
			for _, override in ipairs(overrides) do
				for _, value in ipairs(override.values) do
					local form = value.form
					local combined_notes = iut.combine_footnotes(base.footnotes, value.footnotes)
					if override.full then
						if form ~= "" then
							iut.insert_form(base.forms, slot, {form = form, footnotes = combined_notes})
						end
					else
						-- Convert a null ending to "*" in the acc slot so that e.g. [[Kerberos]] declared as
						-- <m.sg.foreign.gena:u.acc-:a> works correctly and generates accusative 'Kerberos/Kerbera' not
						-- #'Kerber/Kerbera'. FIXME: This is from the Czech module; does this still apply in Icelandic?
						if slot == "acc_s" and form == "" then
							form = "*"
						end
						for _, stems in ipairs(base.stem_sets) do
							add(base, slot, stems, form, combined_notes)
						end
					end
				end
			end
		end
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
		-- rather than generating the plural from the synthesized singular, which may not match the specified lemma
		-- (e.g. [[tvargle]] "Olomouc cheese" using <m.pl.mixed> would try to generate 'tvargle/tvargly', and [[peníze]]
		-- "money" using <m.pl.#ě.genpl-> would try to generate 'peněze'). FIXME: Rewrite for Icelandic.
		local acc_p_like_nom = m_table.deepEquals(nom_p, acc_p)
		nom_p = "*"
		if acc_p_like_nom then
			acc_p = "*"
		end
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

local function handle_derived_slots_and_overrides(base)
	-- FIXME: Rewrite for Icelandic
	local function is_non_derived_slot(slot)
		return slot ~= "acc_s"
	end

	local function is_derived_slot(slot)
		return not is_non_derived_slot(slot)
	end

	base.slot_overridden = {}
	-- Handle overrides for the non-derived slots. Do this before generating the derived
	-- slots so overrides of the source slots (e.g. nom_p) propagate to the derived slots.
	process_slot_overrides(base, is_non_derived_slot)

	-- Generate the remaining slots that are derived from other slots.
	if not base.pron and not base.det then
		-- Pronouns don't have a vocative (singular or plural).
		iut.insert_forms(base.forms, "voc_p", base.forms.nom_p)
	end
	if not base.forms.acc_s and not base.slot_overridden.acc_s then
		iut.insert_forms(base.forms, "acc_s", base.forms[base.animacy == "inan" and "nom_s" or "gen_s"])
	end

	-- Handle overrides for derived slots, to allow them to be overridden.
	process_slot_overrides(base, is_derived_slot)

	-- Compute linked versions of potential lemma slots, for use in {{is-noun}}.
	-- We substitute the original lemma (before removing links) for forms that
	-- are the same as the lemma, if the original lemma has links.
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


-- Table mapping declension types to functions to decline the noun. The function takes two arguments, `base` and
-- `props`; the latter specifies the computed stems (vowel vs. non-vowel, singular vs. plural) and whether the noun
-- is reducible and/or has vowel alternations in the stem. Most of the specifics of determining which stem to use
-- and how to modify it for the given ending are handled in add_decl(); the declension functions just need to generate
-- the appropriate endings.
local decls = {}


decls["m"] = function(base, props)
	local gen = ...
	add_decl(base, props, "", dat, "s", "ar")
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
	add_decl(base, props, "i", "i", "ar", "ir")
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


decls["weak-f"] = function(base, props)
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


decls["weak-n"] = function(base, props)
	-- "Weak" neuter nouns in -a, e.g. [[auga]] "eye", [[hjarta]] "heart". U-mutation occurs in the nom/acc/dat pl but
	-- doesn't need to be indicated explicitly because the ending begins with u-.
	add_decl(base, props, "a", "a", "a", "u", nil, nil, "na")
end


decls["adj"] = function(base, props)
	local props = {}
	local propspec = table.concat(props, ".")
	if propspec ~= "" then
		propspec = "<" .. propspec .. ">"
	end
	local adj_alternant_multiword_spec = require("Module:is-adjective").do_generate_forms({base.lemma .. propspec})
	local function copy(from_slot, to_slot)
		base.forms[to_slot] = adj_alternant_multiword_spec.forms[from_slot]
	end
	if base.number ~= "pl" then
		if base.gender == "m" then
			copy("nom_m", "nom_s")
			copy("gen_mn", "gen_s")
			copy("dat_mn", "dat_s")
			copy("loc_mn", "loc_s")
			copy("ins_mn", "ins_s")
		elseif base.gender == "f" then
			copy("nom_f", "nom_s")
			copy("gen_f", "gen_s")
			copy("dat_f", "dat_s")
			copy("acc_f", "acc_s")
			copy("loc_f", "loc_s")
			copy("ins_f", "ins_s")
		else
			copy("nom_n", "nom_s")
			copy("gen_mn", "gen_s")
			copy("dat_mn", "dat_s")
			copy("acc_n", "acc_s")
			copy("loc_mn", "loc_s")
			copy("ins_mn", "ins_s")
		end
		if not base.forms.voc_s then
			iut.insert_forms(base.forms, "voc_s", base.forms.nom_s)
		end
	end
	if base.number ~= "sg" then
		if base.gender == "m" then
			if base.animacy == "an" then
				copy("nom_mp_an", "nom_p")
			else
				copy("nom_fp", "nom_p")
			end
			copy("acc_mfp", "acc_p")
		elseif base.gender == "f" then
			copy("nom_fp", "nom_p")
			copy("acc_mfp", "acc_p")
		else
			copy("nom_np", "nom_p")
			copy("acc_np", "acc_p")
		end
		copy("gen_p", "gen_p")
		copy("dat_p", "dat_p")
		copy("ins_p", "ins_p")
		copy("loc_p", "loc_p")
	end
end

local function get_stemtype(base)
	if rfind(base.lemma, "ý$") then
		return "hard"
	elseif rfind(base.lemma, "í$") then
		return "soft"
	else
		return "possessive"
	end
end


decls["mostly-indecl"] = function(base, props)
	-- Several neuters: E.g. [[finále]] "final (sports)", [[čtvrtfinále]] "quarterfinal", [[chucpe]] "chutzpah",
	-- [[penále]] "fine, penalty", [[promile]] "" (NOTE: loc pl also promilech), [[rande]] "rendezvous", [[semifinále]]
	-- "semifinal", [[skóre]] "score".
	-- At least one masculine animate: [[kamikaze]]/[[kamikadze]], where IJP says only -m in the ins sg.
	local ins_s = base.gender == "m" and "m" or {"*", "m"}
	add_decl(base, props, "*", "*", "*", "*", "*", ins_s,
		"*", "*", "*", "*", "*", "*")
end


decls["indecl"] = function(base, props)
	-- Indeclinable. Note that fully indeclinable nouns should not have a table at all rather than one all of whose forms
	-- are the same; but having an indeclinable declension is useful for nouns that may or may not be indeclinable, e.g.
	-- [[desatero]] "group of ten" or the plural of [[peso]], which may be indeclinable 'pesos'.
	add_decl(base, props, "*", "*", "*", "*", "*", "*",
		"*", "*", "*", "*", "*", "*")
end


local function set_pron_defaults(base)
	if base.gender or base.lemma ~= "ona" and base.number or base.animacy then
		error("Can't specify gender, number or animacy for pronouns")
	end

	local function pron_props()
		-- Return values are GENDER, NUMBER, ANIMACY, HAS_CLITIC.
		if base.lemma == "kdo" then
			return "none", "sg", "an", false
		elseif base.lemma == "co" then
			return "none", "sg", "inan", false
		elseif base.lemma == "já" or base.lemma == "ty" then
			return "none", "sg", "an", true
		elseif base.lemma == "my" or base.lemma == "vy" then
			return "none", "pl", "an", false
		elseif base.lemma == "on" then
			return "m", "sg", "none", true
		elseif base.lemma == "ono" then
			return "n", "sg", "inan", true
		elseif base.lemma == "oni" then
			return "m", "pl", "an", false
		elseif base.lemma == "ony" then
			return "none", "pl", "none", false
		elseif base.lemma == "ona" then
			if base.number ~= "sg" and base.number ~= "pl" then
				error("Must specify '.sg' or '.pl' with lemma 'ona'")
			end
			if base.number == "sg" then
				return "f", "sg", "none", false
			else
				return "n", "pl", "inan", false
			end
		elseif base.lemma == "sebe" then
			return "none", "none", "none", true
		else
			error(("Unrecognized pronoun '%s'"):format(base.lemma))
		end
	end

	local gender, number = pron_props()
	base.gender = gender
	base.actual_gender = gender
	base.number = number
	base.actual_number = number
end


local function determine_pronoun_stems(base)
	if base.stem_sets then
		error("Reducible and vowel alternation specs cannot be given with pronouns")
	end
	base.stem_sets = {{vowel_stem = "", nonvowel_stem = ""}}
	base.decl = "pron"
end


decls["pron"] = function(base, props)
	local after_prep_footnote =	"[after a preposition]"
	local animate_footnote = "[animate]"
	if base.lemma == "kdo" then
		add_decl(base, props, "koho", "komu", nil, nil, "kom", "kým")
	elseif base.lemma == "co" then
		add_decl(base, props, "čeho", "čemu", nil, nil, "čem", "čím")
	elseif base.lemma == "já" then
		add_sg_decl_with_clitic(base, props, "mne", "mě", "mně", "mi", nil, nil, nil, "mně", "mnou")
	elseif base.lemma == "ty" then
		add_sg_decl_with_clitic(base, props, "tebe", "tě", "tobě", "ti", nil, nil, nil, "tobě", "tebou")
	elseif base.lemma == "my" then
		add_pl_only_decl(base, props, "nás", "nám", "nás", "nás", "námi")
	elseif base.lemma == "vy" then
		add_pl_only_decl(base, props, "vás", "vám", "vás", "vás", "vámi")
	elseif base.lemma == "on" or base.lemma == "ono" then
		local acc_s = base.lemma == "on" and "jej" or {"jej", "je"}
		local clitic_acc_s = base.lemma == "on" and {"jej", "ho"} or {"jej", "ho", "je"}
		local prep_acc_s = base.lemma == "on" and "něj" or {"něj", "ně"}
		local prep_clitic_acc_s = base.lemma == "on" and "-ň" or nil
		add_sg_decl_with_clitic(base, props, {"jeho", "jej"}, {"ho", "jej"}, "jemu", "mu", acc_s, clitic_acc_s, nil, nil, "jím")
		add_sg_decl_with_clitic(base, props, {"něho", "něj"}, nil, "němu", nil, prep_acc_s, prep_clitic_acc_s, nil, "něm", "ním",
			after_prep_footnote)
		if base.lemma == "on" then
		add_sg_decl_with_clitic(base, props, nil, nil, nil, nil, "jeho", nil, nil, nil, nil,
			animate_footnote)
		add_sg_decl_with_clitic(base, props, nil, nil, nil, nil, "něho", nil, nil, nil, nil,
			after_prep_footnote and animate_footnote)
		end
	elseif base.lemma == "ona" and base.number == "sg" then
		add_sg_decl(base, props, "jí", "jí", "ji", nil, nil, "jí")
		add_sg_decl(base, props, "ní", "ní", "ni", nil, "ní", "ní", after_prep_footnote)
	elseif base.lemma == "oni" or base.lemma == "ony" or base.lemma == "ona" then
		add_pl_only_decl(base, props, "jich", "jim", "je", nil, "jimi")
		add_pl_only_decl(base, props, "nich", "nim", "ně", "nich", "nimi", after_prep_footnote)
	elseif base.lemma == "sebe" then
		-- Underlyingly we handle [[sebe]]'s slots as singular.
		add_sg_decl_with_clitic(base, props, "sebe", "sebe", "sobě", "si", "sebe", "se", nil, "sobě", "sebou",
			nil, "no nom_s")
	else
		error(("Internal error: Unrecognized pronoun lemma '%s'"):format(base.lemma))
	end
end


local function set_num_defaults(base)
	if base.gender or base.number or base.animacy then
		error("Can't specify gender, number or animacy for numeral")
	end

	local function num_props()
		-- Return values are GENDER, NUMBER, ANIMACY, HAS_CLITIC.
		return "none", "pl", "none", false
	end

	local gender, number = num_props()
	base.gender = gender
	base.actual_gender = gender
	base.number = number
	base.actual_number = number
end


local function determine_numeral_stems(base)
	if base.stem_sets then
		error("Reducible and vowel alternation specs cannot be given with numerals")
	end
	local stem = rmatch(base.lemma, "^(.*)" .. com.vowel_c .. "$") or base.lemma
	base.stem_sets = {{vowel_stem = stem, nonvowel_stem = stem}}
	base.decl = "num"
end


decls["num"] = function(base, props)
	local after_prep_footnote =	"[after a preposition]"
	if base.lemma == "dva" or base.lemma == "dvě" then
		-- in compound numbers; stem is dv-
		add_pl_only_decl(base, props, "ou", "ěma", "*", "ou", "ěma")
	elseif base.lemma == "tři" or base.lemma == "čtyři" then
		-- stem is without -i
		local is_three = base.lemma == "tři"
		add_pl_only_decl(base, props, is_three and "í" or "", "em", "*", "ech", is_three and "emi" or "mi")
		add_pl_only_decl(base, props, "ech", nil, nil, nil, nil, "[colloquial]")
		add_pl_only_decl(base, props, nil, nil, nil, nil, is_three and "ema" or "ma",
			"[when modifying a form ending in ''-ma'']")
	elseif base.lemma == "devět" then
		add_pl_only_decl(base, "", "devíti", "devíti", "*", "devíti", "devíti", stems.footnotes)
	elseif base.lemma == "sta" or base.lemma == "stě" or base.lemma == "set" then
		add_pl_only_decl(base, "", "set", "stům", "*", "stech", "sty", stems.footnotes)
	elseif rfind(base.lemma, "[is]et$") then
		-- [[deset]] and all numbers ending in -cet ([[dvacet]], [[třicet]], [[čtyřicet]] and inverted compound
		-- numerals such as [[pětadvacet]] "25" and [[dvaatřicet]] "32")
		local begin = rmatch(base.lemma, "^(.*)et$")
		add_pl_only_decl(base, props, "i", "i", "*", "i", "i")
		add_pl_only_decl(base, begin, "íti", "íti", "*", "íti", "íti", stems.footnotes)
	elseif rfind(base.lemma, "oje$") then
		-- [[dvoje]], [[troje]]
		-- stem is without -e
		add_pl_only_decl(base, props, "ích", "ím", "*", "ích", "ími")
	elseif rfind(base.lemma, "ery$") then
		-- [[čtvery]], [[patery]], [[šestery]], [[sedmery]], [[osmery]], [[devatery]], [[desatery]]
		-- stem is without -y
		add_pl_only_decl(base, props, "ých", "ým", "*", "ých", "ými")
	else
		add_pl_only_decl(base, props, "i", "i", "*", "i", "i")
	end
end


local function set_det_defaults(base)
	if base.gender or base.number or base.animacy then
		error("Can't specify gender, number or animacy for determiner")
	end

	local function det_props()
		-- Return values are GENDER, NUMBER, ANIMACY, HAS_CLITIC.
		return "none", "none", "none", false
	end

	local gender, number = det_props()
	base.gender = gender
	base.actual_gender = gender
	base.number = number
	base.actual_number = number
end


local function determine_determiner_stems(base)
	if base.stem_sets then
		error("Reducible and vowel alternation specs cannot be given with determiners")
	end
	local stem = rmatch(base.lemma, "^(.*)" .. com.vowel_c .. "$") or base.lemma
	base.stem_sets = {{vowel_stem = stem, nonvowel_stem = stem}}
	base.decl = "det"
end


decls["det"] = function(base, props)
	add_sg_decl(base, props, "a", "a", "*", nil, "a", "a")
end


-- Return the lemmas for this term. The return value is a list of {form = FORM, footnotes = FOOTNOTES}.
-- If `linked_variant` is given, return the linked variants (with embedded links if specified that way by the user),
-- otherwies return variants with any embedded links removed. If `remove_footnotes` is given, remove any
-- footnotes attached to the lemmas.
function export.get_lemmas(alternant_multiword_spec, linked_variant, remove_footnotes)
	local slots_to_fetch = get_lemma_slots(alternant_multiword_spec.props)
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
	process_slot_overrides(base)

	-- Compute linked versions of potential lemma slots, for use in {{de-noun}}.
	-- We substitute the original lemma (before removing links) for forms that
	-- are the same as the lemma, if the original lemma has links.
	for _, slot in ipairs(get_lemma_slots(base.props)) do
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


-- Like iut.split_alternating_runs_and_strip_spaces(), but ensure that backslash-escaped commas and periods are not
-- treated as separators.
local function split_alternating_runs_with_escapes(segments, splitchar)
	for i, segment in ipairs(segments) do
		segments[i] = rsub(segment, "\\,", SUB_ESCAPED_COMMA)
		segments[i] = rsub(segment, "\\%.", SUB_ESCAPED_PERIOD)
	end
	local separated_groups = iut.split_alternating_runs_and_strip_spaces(segments, splitchar)
	for _, separated_group in ipairs(separated_groups) do
		for i, segment in ipairs(separated_group) do
			separated_group[i] = rsub(segment, SUB_ESCAPED_COMMA, ",")
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


-- Fetch and parse a slot override, e.g. "ar:s" or "um:m[archaic]/um" or ":~i:Þorkatli[archaic]"; that is, everything
-- after the slot name(s), including the initial colon. `segments` is the input in the form of a list where the
-- footnotes have been separated out (see `parse_override` below); `spectype` is used in error messages and specifies
-- e.g. "genitive" or "dat+gen slot override"; `allow_blank` indicates that a completely blank override spec is allowed
-- (in that case, nil will be returned); `allow_slash` indicates that two slash-separated specs (indefinite and
-- definite) are allowed; and `parse_err` is a function of one argument to throw a parse error. The return value is an
-- object containing fields `full`, `bare` and `def`, of the format described below in the comment above
-- `parse_override`.
local function fetch_slot_override(segments, spectype, allow_blank, allow_slash, parse_err)
	if allow_blank and #segments == 1 and segments[1] == "" then
		return nil
	end
	local full = false
	if segments[1]:find("^:") then
		full = true
		segments[1] = segments[1]:gsub("^:", "")
	end
	local slash_separated_groups = iut.split_alternating_runs_and_strip_spaces(segments, "/")
	if #slash_separated_groups > 2 then
		parse_err(("Can specify at most two slash-separated override groups for %s, but saw %s"):format(
			spectype, #slash_separated_groups))
	end
	if slash_separated_groups[2] and not allow_slash then
		parse_err(("Can't specify two slash-separated override groups for %s; the second override group is for the definite slot variant, but the slot is already definite"):format(
			spectype))
	end
	local ret
	for i, slash_separated_group in ipairs(slash_separated_groups) do
		local retfield = i == 1 and "bare" or "def"
		local colon_separated_groups = iut.split_alternating_runs_and_strip_spaces(slash_separated_groups, ":")
		local specs = {}
		for _, colon_separated_group in ipairs(colon_separated_groups) do
			local form = colon_separated_group[1]
			if form == "" then
				parse_err(("Use - to indicate an empty ending for %s: '%s'"):format(spectype, table.concat(segments)))
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
	ret.full = full
	return ret
end


--[=[
Parse a single override spec (e.g. 'dat-:i/-' or 'defnompl+defaccpl:sumrin[when referring to summers in general]:sumurin[when referring to a specific number of summers]')
and return two values: the slot(s) the override applies to, and an object describing the override spec. The input is
actually a list where the footnotes have been separated out; for example, given the second example spec above, the input
will be a list {"defnompl+defaccpl:sumrin", "[when referring to summers in general]", ":sumurin",
  "[when referring to a specific number of summers]", ""}.

The object returned for 'dat-:i[mostly in the context of violent actions]/-' looks like this:

{
  bare = {
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

The object returned for 'defnompl+defaccpl:sumrin[when referring to summers in general]:sumurin[when referring to a specific number of summers]'
looks like this:

{
  full = true,
  bare = {
	{
	  form = "sumrin",
	  footnotes = {"[when referring to summers in general]"}
	},
	{
	  form = "sumurin",
	  footnotes = {"[when referring to a specific number of summers]"}
	}
  }
}
]=]
local function parse_override(segments, parse_err)
	local part = segments[1]
	local slots = {}
	local slot_def
	while true do
		local this_slot_def
		if part:find("^def") then
			this_slot_def = true
			part = usub(part, 4)
		else
			this_slot_def = false
		end
		if slot_def == nil then
			slot_def = this_slot_def
		elseif slot_def ~= this_slot_def then
			parse_err(("When multiple slot overrides are combined with +, all must be definite or indefinite: '%s'"):
				format(table.concat(segments)))
		end
		local case = usub(part, 1, 3)
		if cases[case] then
			-- ok
		else
			parse_err(("Unrecognized case '%s' in override: '%s'"):format(case, table.concat(segments)))
		end
		part = usub(part, 4)
		local slot = slot_def and "def_" or "ind_"
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
	local retval = fetch_slot_override(segments, ("%s slot override"):format(table.concat(slots)), false,
		not slot_def, parse_err)
	return slots, retval
end


--[=[
Parse an indicator spec (text consisting of angle brackets and zero or more dot-separated indicators within them).
Return value is an object of the form

{
  overrides = {
	SLOT = {OVERRIDE, OVERRIDE, ...},
	...
  }, -- where SLOT is the actual name of the slot, such as "ind_gen_s" (NOT the slot name as specified by the user,
		which would be just "gen" for "ind_gen_s") and OVERRIDE is
		{full = BOOLEAN, bare = {FORMOBJ, FORMOBJ, ...}, def = nil or {FORMOBJ, FORMOBJ, ...}}, where `full` is true if
		the override began with a colon (indicating that the values are full forms rather than endings); FORMOBJ is
		{form = FORM, footnotes = FOOTNOTES} as in the `forms` table ("-" means to suppress the slot entirely and is
		signaled by "--" as the form value); `bare` means the override(s) coming before a slash; `def` means the
		override(s) coming after a slash, which are not allowed for definite slots
  gens = {GEN_SG_SPEC, GEN_SG_SPEC, ...}, same form as OVERRIDE above
  pls = {PL_SPEC, PL_SPEC, ...}, same form as OVERRIDE above
  forms = {}, -- forms for a single spec alternant; see `forms` below
  props = {
	PROP = true,
	PROP = true,
    ...
  }, -- misc Boolean properties: "dem" (a demonym, i.e. a capitalized noun such as [[Svisslendingur]] "Swiss person"
		that behaves like a common noun); "pers" (a personal name; has special declension properties); "rstem" (an
		r-stem like [[bróðir]] "brother" or [[dóttir]] "daughter")
  number = "NUMBER", -- "sg", "pl", "both"; may be missing
  gender = "GENDER", -- "m", "f" or "n"; always specified by the user
  adj = true, -- may be missing; indicates that the term declines like an adjective (NOT IMPLEMENTED YET)
  decllemma = nil or "DECLLEMMA", -- decline like the specified lemma
  declgender = nil or "DECLGENDER", -- decline like the specified gender
  stem = {FORMOBJ, FORMOBJ, ...}, -- override the stem(s); see above for FORMOBJ
  vstem = {FORMOBJ, FORMOBJ, ...}, -- override the stem(s) used before vowel-initial endings; see above for FORMOBJ
  plstem = {FORMOBJ, FORMOBJ, ...}, -- override the plural stem(s); see above for FORMOBJ
  footnotes = nil or {"FOOTNOTE", "FOOTNOTE", ...}, -- alternant-level footnotes, specified using `.[footnote]`, i.e.
													   a footnote by itself
  addnote_specs = {
	ADDNOTE_SPEC, ADDNOTE_SPEC, ...
  }, -- where ADDNOTE_SPEC is {slot_specs = {"SPEC", "SPEC", ...}, footnotes = {"FOOTNOTE", "FOOTNOTE", ...}}; SPEC is
		a Lua pattern matching slots (anchored on both sides) and FOOTNOTE is a footnote to add to those slots
  MUTATION_GROUP = {
	MUTATION_SPEC, MUTATION_SPEC, ...
  }, -- where MUTATION_GROUP is one of "umut", "imut", "unumut", "unimut", "con", "defcon", "def", "j" or "v", and
		MUTATION_SPEC is {key = "KEY", value = "VALUE" or true, footnotes = nil or {"FOOTNOTE", "FOOTNOTE", ...}}; the
		mutation groups are as follows: umut (u-mutation), imut (i-mutation), unumut (reverse u-mutation), unimut
		(reverse i-mutation), con (stem contraction before vowel-initial endings), defcon (stem contraction before
		vowel-initial definite clitics when the ending itself is null), def (definite forms are/aren't present), j
		(j-infix before vowel-initial endings not beginning with an i), v (v-infix before vowel-initial endings)

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
local function parse_indicator_spec(angle_bracket_spec, lemma, pagename, proper_noun)
	if lemma == "" then
		lemma = pagename
	end
	local base = {
		forms = {},
		overrides = {},
		props = {prop = proper_noun},
		addnote_specs = {},
	}
	base.orig_lemma = lemma
	base.orig_lemma_no_links = m_links.remove_links(lemma)
	base.lemma = base.orig_lemma_no_links
	local inside = rmatch(angle_bracket_spec, "^<(.*)>$")
	assert(inside)

	local function parse_err(msg)
		error(msg .. ": <" .. inside .. ">")
	end

	if inside ~= "" then
		local segments = iut.parse_balanced_segment_run(inside, "[", "]")
		local dot_separated_groups = split_alternating_runs_with_escapes(segments, "%.")
		for i, dot_separated_group in ipairs(dot_separated_groups) do
			-- Parse a "mutation" spec such as "umut,uumut[rare]" or "-unuumut,unuumut" or "imut:y". This assumes the
			-- mutation spec is contained in `dot_separated_group` (already split on brackets) and the result of parsing
			-- should go in `base[dest]`. `allowed_specs` is a list of the allowed mutation specs in this group, such
			-- as {"umut", "uumut", "u_umut"} or {"-imut", "imut"}, and `allowed_specs_with_values` is a list of the
			-- specs that can have an associated value, as in "imut:y", or nil if no specs can have such values. The
			-- result of parsing is a list of structures of the form {
			--   key = "KEY",
			--   value = "VALUE" or true,
			--   footnotes = nil or {"FOOTNOTE", "FOOTNOTE", ...},
			-- }.
			local function parse_mutation_spec(dest, allowed_specs, allowed_specs_with_values)
				if base[dest] then
					parse_err(("Can't specify '%s'-type mutation spec twice; second such spec is '%s'"):format(
						dest, table.concat(dot_separated_group)))
				end
				base[dest] = {}
				local comma_separated_groups = split_alternating_runs_with_escapes(dot_separated_group, ",")
				for _, comma_separated_group in ipairs(comma_separated_groups) do
					local specobj = {}
					local spec = comma_separated_group[1]
					if spec:find(":") then
						if not allowed_specs_with_values then
							parse_err(("'%s'-type mutation spec cannot have an associated value, but saw '%s'"):format(
								dest, spec))
						end
						local key, value = spec:match("^(.-)%s*:%s*(.-)$")
						if not m_table.contains(allowed_specs_with_values, key) then
							parse_err(("For '%s'-type mutation spec, only %s can have an associated value, but saw '%s'"):format(
								dest, generate_list_of_possibilities_for_err(allowed_specs_with_values), key))
						end
						specobj.key = key
						specobj.value = value
					elseif not m_table.contains(allowed_specs, spec) then
						parse_err(("For '%s'-type mutation spec, saw unrecognized spec '%s'; valid values are %s"):
							format(dest, generate_list_of_possibilities_for_err(allowed_specs), spec))
					else
						specobj.key = spec
						specobj.value = true
					end
					specobj.footnotes = fetch_footnotes(comma_separated_group, parse_err)
					table.insert(base[dest], specobj)
				end
			end

			local part = dot_separated_group[1]
			if i == 1 then
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
					base.gens = fetch_slot_override(comma_separated_groups[2], "genitive", true, true, parse_err)
				end
				if comma_separated_groups[3] then
					base.pls = fetch_slot_override(comma_separated_groups[3], "nominative plural", true, true,
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
			elseif ulen(part) > 3 and cases[usub(part, 1, 3)] or (
				ulen(part) > 6 and usub(part, 1, 3) == "def" and cases[usub(part, 4, 6)]) then
				local slots, overrides = parse_override(dot_separated_group, parse_err)
				for _, slot in ipairs(slots) do
					if base.overrides[slot] then
						error(("Two overrides specified for slot '%s'"):format(slot))
					else
						base.overrides[slot] = overrides
					end
				end
			elseif part:find("^u[u_]*mut") then
				parse_mutation_spec("umut", {"umut", "uumut", "u_umut"}, {"umut"})
			elseif part:find("^%-?imut") then
				parse_mutation_spec("imut", {"imut", "-imut"}, {"imut"})
			elseif part:find("^%-?unu+mut") then
				parse_mutation_spec("unumut", {"unumut", "-unumut", "unuumut", "-unuumut"})
			elseif part:find("^%-?unimut") then
				parse_mutation_spec("unimut", {"unimut", "-unimut"})
			elseif part:find("^%-?con") then
				parse_mutation_spec("con", {"con", "-con"})
			elseif part:find("^%-?defcon") then
				parse_mutation_spec("defcon", {"defcon", "-defcon"})
			elseif part:find("^%-?def") then
				parse_mutation_spec("def", {"def", "-def"})
			elseif not part:find("^já") and part:find("^%-?j") then -- don't trip over .já indicator
				parse_mutation_spec("j", {"j", "-j"})
			elseif part:find("^%-?v") then
				parse_mutation_spec("v", {"v", "-v"})
			elseif part:find("^decllemma%s*:") or part:find("^declgender%s*:") then
				local field, value = part:match("^(decl[a-z]+)%s*:%s*(.+)$")
				if not value then
					parse_err(("Syntax error in decllemma/declgender indicator: '%s'"):format(part))
				end
				if base[field] then
					parse_err(("Can't specify '%s:' twice"):format(field))
				end
				if dot_separated_group[2] then
					parse_err(("Footnotes not allowed with '%s': '%s'"):format(
						field, table.concat(dot_separated_group)))
				end
				base[field] = value
			elseif rfind(part, ":") then
				local spec, value = part:match("^([a-z]+)%s*:%s*(.+)$")
				if not spec then
					parse_err(("Syntax error in indicator with value, expecting alphabetic slot or stem/lemma override indicator: '%s'"):format(part))
				end
				if not overridable_stems[spec] then
					local overridable_stem_list = {}
					for k, _ in pairs(overridable_stems) do
						table.insert(overridable_stem_list, k)
					end
					parse_err(("Unrecognized stem override indicator '%s', should be %s"):format(
						part, generate_list_of_possibilities_for_err(overridable_stem_list)))
				end
				if base[spec] then
					if spec == "stem" then
						parse_err("Can't specify spec for 'stem:' twice (including using 'stem:' along with # or ##)")
					else
						parse_err(("Can't specify '%s:' twice"):format(spec))
					end
				end
				base[spec] = {}
				dot_separated_group[1] = value
				local colon_separated_groups = iut.split_alternating_runs_and_strip_spaces(dot_separated_group, ":")
				for _, colon_separated_group in ipairs(colon_separated_groups) do
					local form = colon_separated_group[1]
					if form == "" then
						parse_err("Blank stem not allowed")
					end
					local new_spec = {form = form, footnotes = fetch_footnotes(colon_separated_group, parse_err)}
					for _, existing_spec in ipairs(base[specs]) do
						if existing_spec.form == new_spec.form then
							parse_err(("Duplicate stem '%s' for '%s:'"):format(new_spec.form, spec))
						end
					end
					table.insert(base[spec], new_spec)
				end
			elseif #dot_separated_group > 1 then
				parse_err(
					("Footnotes only allowed with slot/stem overrides, negatable indicators and by themselves: '%s'"):
					format(table.concat(dot_separated_group)))
			elseif part == "sg" or part == "pl" or part == "both" then
				if base.number then
					if base.number ~= part then
						parse_err("Can't specify '" .. part .. "' along with '" .. base.number .. "'")
					else
						parse_err("Can't specify '" .. part .. "' twice")
					end
				end
				base.number = part
			elseif part == "#" or part == "##" then
				if base.stem then
					parse_err("Can't specify a stem spec ('stem:', # or ##) twice")
				end
				base.stem = part
			elseif part == "+" then
				if base.adj then
					parse_err("Can't specify '+' twice")
				end
				base.adj = true
				parse_err("Adjectival indicator '+' not implemented yet")
			elseif part == "@" then
				if base.builtin then
					parse_err("Can't specify '@' twice")
				end
				base.builtin = true
				parse_err("Built-in indicator '@' not implemented yet")
			elseif part == "dem" or part == "pers" or part == "rstem" or part == "já" then
				if base.props[part] then
					parse_err("Can't specify '" .. part .. "' twice")
				end
				base.props[part] = true
			else
				parse_err("Unrecognized indicator '" .. part .. "'")
			end
		end
	end
	return base
end


local function is_regular_noun(base)
	return not base.adj and not base.pron and not base.det and not base.num
end


local function set_defaults_and_check_bad_indicators(base)
	-- Set default values.
	local regular_noun = is_regular_noun(base)
	if base.pron then
		set_pron_defaults(base)
	elseif base.det then
		set_det_defaults(base)
	elseif base.num then
		set_num_defaults(base)
	elseif not base.adj then
		if not base.gender then
			error("For nouns, gender must be specified")
		end
		base.number = base.number or "both"
		process_declnumber(base)
		base.animacy = base.animacy or "inan"
		base.actual_gender = base.gender
		base.actual_animacy = base.animacy
		if base.declgender then
			if base.declgender == "m-an" then
				base.gender = "m"
			elseif base.declgender == "m-in" then
				base.gender = "m"
			elseif base.declgender == "f" or base.declgender == "n" then
				base.gender = base.declgender
			else
				error(("Unrecognized value '%s' for 'declgender', should be 'm-an', 'm-in', 'f' or 'n'"):format(base.declgender))
			end
		end
	end
	-- Check for bad indicator combinations.
	if (base.hard and 1 or 0) + (base.soft and 1 or 0) + (base.mixed and 1 or 0) > 1 then
		error("At most one of 'hard', 'soft' and 'mixed' can be specified")
	end
	if base.istem and base["-istem"] then
		error("'istem' and '-istem' cannot be specified together")
	end
	if (base.istem or base["-istem"]) then
		if base.gender ~= "f" then
			error("'istem' and '-istem' can only be specified with the feminine gender")
		end
		if not regular_noun then
			error("'istem' and '-istem' can only be specified with regular nouns")
		end
	end
	if base.declgender and not regular_noun then
		error("'declgender' can only be specified with regular nouns")
	end
end


local function set_all_defaults_and_check_bad_indicators(alternant_multiword_spec)
	local is_multiword = #alternant_multiword_spec.alternant_or_word_specs > 1
	iut.map_word_specs(alternant_multiword_spec, function(base)
		set_defaults_and_check_bad_indicators(base)
		base.multiword = is_multiword -- FIXME: not currently used; consider deleting
		if base.pron then
			alternant_multiword_spec.saw_pron = true
		else
			alternant_multiword_spec.saw_non_pron = true
		end
		if base.det then
			alternant_multiword_spec.saw_det = true
		else
			alternant_multiword_spec.saw_non_det = true
		end
		if base.num then
			alternant_multiword_spec.saw_num = true
		else
			alternant_multiword_spec.saw_non_num = true
		end
	end)
end


-- For a plural-only lemma, synthesize a likely singular lemma. It doesn't have to be
-- theoretically correct as long as it generates all the correct plural forms.
local function synthesize_singular_lemma(base)
	if not base.stem_sets then
		base.stem_sets = {{}}
	end

	local lemma_determined
	-- Loop over all stem sets in case the user specified multiple ones (e.g. '*,-*'). If we try to reconstruct
	-- different lemmas for different stem sets, we'll throw an error below.
	for _, stems in ipairs(base.stem_sets) do
		local stem, lemma
		while true do
			if base.indecl then
				-- If specified as indeclinable, leave it alone; e.g. 'pesos' indeclinable plural of [[peso]].
				lemma = base.lemma
				break
			elseif base.gender == "m" then
				if base.animacy == "an" then
					stem = rmatch(base.lemma, "^(.*)i$")
					if stem then
						if base.soft then
							-- [[Blíženci]] "Gemini"
							-- Since the nominative singular has no ending.
							lemma = com.convert_paired_plain_to_palatal(stem, ending)
						else
							lemma = undo_second_palatalization(base, stem)
						end
					else
						stem = rmatch(base.lemma, "^(.*)ové$") or rmatch(base.lemma, "^(.*)é$")
						if stem then
							-- [[manželé]] "married couple", [[Velšané]] "Welsh people"
							lemma = stem
						else
							error(("Animate masculine plural-only lemma '%s' should end in -i, -ové or -é"):format(base.lemma))
						end
					end
				else
					stem = rmatch(base.lemma, "^(.*)y$")
					if stem then
						-- [[droby]] "giblets"; [[tvarůžky]] "Olomouc cheese"; [[alimenty]] "alimony"; etc.
						lemma = stem
					else
						local ending
						stem, ending = rmatch(base.lemma, "^(.*)([eě])$")
						if stem then
							-- [[peníze]] "money", [[tvargle]] "Olomouc cheese" (mixed declension), [[údaje]] "data",
							-- [[Lazce]] (a village), [[lováče]] "money", [[Krkonoše]] "Giant Mountains", [[kříže]] "clubs"
							lemma = com.convert_paired_plain_to_palatal(stem, ending)
							if not base.mixed then
								base.soft = true
							end
						else
							error(("Inanimate masculine plural-only lemma '%s' should end in -y, -e or -ě"):format(base.lemma))
						end
					end
				end
				break
			elseif base.gender == "f" then
				stem = rmatch(base.lemma, "^(.*)y$")
				if stem then
					lemma = stem .. "a"
					break
				end
				stem = rmatch(base.lemma, "^(.*)[eě]$")
				if stem then
					-- Singular like the plural. Cons-stem feminines like [[dlaň]] "palm (of the hand)" have identical
					-- plurals to soft-stem feminines like [[růže]] (modulo e/ě differences), so we don't need to
					-- reconstruct the former type.
					lemma = base.lemma
					break
				end
				stem = rmatch(base.lemma, "^(.*)i$")
				if stem then
					-- i-stems.
					lemma = stem
					base.istem = true
					break
				end
				error(("Feminine plural-only lemma '%s' should end in -y, -ě, -e or -i"):format(base.lemma))
			elseif base.gender == "n" then
				-- -ata nouns like [[slůně]] "baby elephant" nom pl 'slůňata' are declined in the plural same as if
				-- the singular were 'slůňato' so we don't have to worry about them.
				stem = rmatch(base.lemma, "^(.*)a$")
				if stem then
					lemma = stem .. "o"
					break
				end
				stem = rmatch(base.lemma, "^(.*)[eěí]$")
				if stem then
					-- singular lemma also in -e, -ě or -í; e.g. [[věčná loviště]] "[[happy hunting ground]]"
					lemma = base.lemma
					break
				end
				error(("Neuter plural-only lemma '%s' should end in -a, -í, -ě or -e"):format(base.lemma))
			else
				error(("Internal error: Unrecognized gender '%s'"):format(base.gender))
			end
		end
		if lemma_determined and lemma_determined ~= lemma then
			error(("Attempt to set two different singular lemmas '%s' and '%s'"):format(lemma_determined, lemma))
		end
		lemma_determined = lemma
	end
	base.lemma = lemma_determined
end


-- For an adjectival lemma, synthesize the masc singular form.
local function synthesize_adj_lemma(base)
	local stem
	if base.indecl then
		base.decl = "indecl"
		stem = base.lemma
	else
		local gender, number
		local function sub_ov(stem)
			stem = stem:gsub("ov$", "ův")
			return stem
		end
		while true do
			if base.number == "pl" then
				if base.gender == "m" then
					stem = rmatch(base.lemma, "^(.*)í$")
					if stem then
						if base.soft then
							-- nothing to do
						else
							if base.animacy ~= "an" then
								error(("Masculine plural-only adjectival lemma '%s' ending in -í can only be animate unless '.soft' is specified"):
									format(base.lemma))
							end
							base.lemma = undo_second_palatalization(base, stem, "is adjective") .. "ý"
						end
						break
					end
					stem = rmatch(base.lemma, "^(.*)é$")
					if stem then
						if base.animacy == "an" then
							error(("Masculine plural-only adjectival lemma '%s' ending in -é must be inanimate"):
								format(base.lemma))
						end
						base.lemma = stem .. "ý"
						break
					end
					stem = rmatch(base.lemma, "^(.*ov)i$") or rmatch(base.lemma, "^(.*in)i$")
					if stem then
						if base.animacy ~= "an" then
							error(("Masculine plural-only possessive adjectival lemma '%s' ending in -i must be animate"):
								format(base.lemma))
						end
						base.lemma = sub_ov(stem)
						break
					end
					stem = rmatch(base.lemma, "^(.*ov)y$") or rmatch(base.lemma, "^(.*in)y$")
					if stem then
						if base.animacy == "an" then
							error(("Masculine plural-only possessive adjectival lemma '%s' ending in -y must be inanimate"):
								format(base.lemma))
						end
						base.lemma = sub_ov(stem)
						break
					end
					if base.animacy == "an" then
						error(("Animate masculine plural-only adjectival lemma '%s' should end in -í, -ovi or -ini"):
							format(base.lemma))
					elseif base.soft then
						error(("Soft masculine plural-only adjectival lemma '%s' should end in -í"):format(base.lemma))
					else
						error(("Inanimate masculine plural-only adjectival lemma '%s' should end in -é, -ovy or -iny"):
							format(base.lemma))
					end
				elseif base.gender == "f" then
					stem = rmatch(base.lemma, "^(.*)é$") -- hard adjective
					if stem then
						base.lemma = stem .. "ý"
						break
					end
					stem = rmatch(base.lemma, "^(.*)í$") -- soft adjective
					if stem then
						break
					end
					stem = rmatch(base.lemma, "^(.*ov)y$") or rmatch(base.lemma, "^(.*in)y$") -- possessive adjective
					if stem then
						base.lemma = sub_ov(stem)
						break
					end
					error(("Feminine plural-only adjectival lemma '%s' should end in -é, -í, -ovy or -iny"):format(base.lemma))
				else
					stem = rmatch(base.lemma, "^(.*)á$") -- hard adjective
					if stem then
						base.lemma = stem .. "ý"
						break
					end
					stem = rmatch(base.lemma, "^(.*)í$") -- soft adjective
					if stem then
						break
					end
					stem = rmatch(base.lemma, "^(.*ov)a$") or rmatch(base.lemma, "^(.*in)a$") -- possessive adjective
					if stem then
						base.lemma = sub_ov(stem)
						break
					end
					error(("Neuter plural-only adjectival lemma '%s' should end in -á, -í, -ova or -ina"):format(base.lemma))
				end
			else
				if base.gender == "m" then
					stem = rmatch(base.lemma, "^(.*)[ýí]$") or rmatch(base.lemma, "^(.*)ův$") or rmatch(base.lemma, "^(.*)in$")
					if stem then
						break
					end
					error(("Masculine adjectival lemma '%s' should end in -ý, -í, -ův or -in"):format(base.lemma))
				elseif base.gender == "f" then
					stem = rmatch(base.lemma, "^(.*)á$")
					if stem then
						base.lemma = stem .. "ý"
						break
					end
					stem = rmatch(base.lemma, "^(.*)í$")
					if stem then
						break
					end
					stem = rmatch(base.lemma, "^(.*ov)a$") or rmatch(base.lemma, "^(.*in)a$")
					if stem then
						base.lemma = sub_ov(stem)
						break
					end
					error(("Feminine adjectival lemma '%s' should end in -á, -í, -ova or -ina"):format(base.lemma))
				else
					stem = rmatch(base.lemma, "^(.*)é$")
					if stem then
						base.lemma = stem .. "ý"
						break
					end
					stem = rmatch(base.lemma, "^(.*)í$")
					if stem then
						break
					end
					stem = rmatch(base.lemma, "^(.*ov)o$") or rmatch(base.lemma, "^(.*in)o$")
					if stem then
						base.lemma = sub_ov(stem)
						break
					end
					error(("Neuter adjectival lemma '%s' should end in -é, -í, -ovo or -ino"):format(base.lemma))
				end
			end
		end
		base.decl = "adj"
	end

	-- Now set the stem sets if not given.
	for _, stems in ipairs(base.stem_sets) do
		-- Set the stems.
		stems.vowel_stem = stem
		stems.nonvowel_stem = stem
	end
end


-- Determine the declension based on the lemma, gender and number. The declension is set in base.decl. In the process,
-- we set either base.vowel_stem (if the lemma ends in a vowel) or base.nonvowel_stem (if the lemma does not end in a
-- vowel), which is used by determine_stems(). In some cases (specifically with certain foreign nouns), we set
-- base.lemma to a new value; this is as if the user specified 'decllemma:'.
local function determine_declension(base)
	local stem
	local default_mutations = {}
	-- Determine declension
	if base.gender == "m" then
		stem = rmatch(base.lemma, "^(.*á)r$")
		if stem then
			-- [[nár]] "corpse", [[aur]] "loam, mud", [[gaur]] "ruffian", [[paur]] "devil; enmity",
			-- [[saur]] "dirt; excrement", [[staur]] "post", [[ljósastaur]] "lamp post"
			base.decl = "m"
		end
		stem = rmatch(base.lemma, "^(.*)ir$")
		if stem then
			-- [[maur]] "ant", [[aur]] "loam, mud", [[gaur]] "ruffian", [[paur]] "devil; enmity",
			-- [[saur]] "dirt; excrement", [[staur]] "post", [[ljósastaur]] "lamp post"
			base.decl = "m-ir"
		end
		if not stem then
			stem = rmatch(base.lemma, "^(.*aur)$")
			if stem then
				-- [[maur]] "ant", [[aur]] "loam, mud", [[gaur]] "ruffian", [[paur]] "devil; enmity",
				-- [[saur]] "dirt; excrement", [[staur]] "post", [[ljósastaur]] "lamp post"
				base.decl = "m"
			end
		end
		-- FIXME
	elseif base.gender == "f" then
		stem = rmatch(base.lemma, "^(.*)a$")
		if stem then
			base.decl = "weak-f"
		end
		if not stem then
			stem = rmatch(base.lemma, "^(.*)i$")
			if stem then
				base.decl = "f-i"
			end
		end
		if not stem then
			stem = rmatch(base.lemma, "^(.*)ur$")
			if stem then
				base.decl = "f-ur"
			end
		end
		if not stem then
			stem = rmatch(base.lemma, "^(.*)ung$")
			if stem then
				base.decl = "f-ung"
			end
		end
		if not stem then
			stem = rmatch(base.lemma, "^(.*)ung$")
			if stem then
				base.decl = "f-ing"
			end
		end
		if not stem then
			stem = rmatch(base.lemma, "^(.*[áóúÁÓÚ])$")
			if stem then
				base.decl = "f-long-vowel"
			end
		end
		if not stem then
			stem = rmatch(base.lemma, "^(.*[ýæÝÆ])r$")
			if stem then
				-- [[kýr]] "cow", [[sýr]] "sow (archaic)", [[ær]] "ewe" and compounds
				base.decl = "f-long-umlaut-vowel-r"
			end
		end
		if not stem then
			stem = rmatch(base.lemma, "^(.*[^aA]un)$")
			if stem then
				-- [[pöntun]] "order (in commerce)"; [[verslun]] "trade, business; store, shop"; [[efun]] "doubt";
				-- [[bötun]] "improvement"; [[örvun]] "encouragement; stimulation" (pl. örvanir); etc.
				base.decl = "f"
				default_mutations.unumut = "unuumut"
			end
		end
		if not stem then
			stem = base.lemma
			base.decl = "f"
			-- FIXME! Somehow if the user specifies v-infix, it should prevent unumut from happening.
			default_mutations.unumut = "unumut"
		end



	if stem then
		if base.gender == "m" then
			if base.animacy ~= "an" then
				error("Masculine lemma in -a must be animate")
			end
			base.decl = "a-m"
		elseif base.gender == "f" then
			if base.hard then
				-- e.g. [[doňa]], which seems not to have soft alternates as [[piraňa]] does (despite IJP; but see the note at the
				-- bottom)
				base.decl = "hard-f"
			elseif rfind(stem, "e$") then
				-- [[idea]], [[diarea]] (subtype '.tech'), [[Korea]], etc.
				base.decl = "ea-f"
			elseif rfind(stem, "i$") then
				-- [[signoria]], [[sinfonia]], [[paranoia]], etc.
				base.decl = "ia-f"
			elseif rfind(stem, "[ou]$") then
				-- [[stoa]], [[kongrua]], [[Samoa]], [[Nikaragua]], etc.
				base.decl = "oa-f"
			elseif not base.persname and rfind(stem, "^.*[ňj]$") then
				-- [[maracuja]], [[papája]], [[sója]]; [[piraňa]] etc. Also [[Keňa]], [[Troja]]/[[Trója]], [[Amudarja]].
				-- Not [[Táňa]], [[Darja]], which decline like [[gejša]], [[skica]], etc. (subtype of hard feminines).
				base.decl = "mixed-f"
			else
				base.decl = "hard-f"
			end
		elseif base.gender == "n" then
			if rfind(stem, "m$") then
				base.decl = "ma-n"
			else
				error("Lemma ending in -a and neuter must end in -ma")
			end
		end
		base.vowel_stem = stem
		return
	end
	local ending
	stem, ending = rmatch(base.lemma, "^(.*)([eě])$")
	if stem then
		if ending == "ě" then
			stem = com.convert_paired_plain_to_palatal(stem)
		end
		if base.gender == "m" then
			if base.foreign then
				-- [[software]] and similar English-derived nouns with silent -e; set the lemma here as if decllemma: were given
				base.lemma = stem
				base.nonvowel_stem = stem
				base.decl = "hard-m"
				return
			end
			if base.hard then
				-- -e be damned; e.g. [[Sofokles]] with hard stem 'Sofokle-' (genitive 'Sofoklea', dative 'Sofokleovi', etc.)
				base.nonvowel_stem = base.lemma
				base.decl = "hard-m"
				return
			end
			if base.tstem then
				if base.animacy ~= "an" then
					error("T-stem masculine lemma in -e must be animate")
				end
				base.decl = "tstem-m"
			elseif rfind(stem, "i$") then
				-- [[zombie]], [[hippie]], [[yuppie]], [[rowdie]]
				base.decl = "ie-m"
			elseif rfind(stem, "e$") then
				-- [[Yankee]]
				base.nonvowel_stem = base.lemma
				base.decl = "ee-m"
				return
			else
				base.decl = "e-m"
			end
		elseif base.gender == "f" then
			base.decl = "soft-f"
		else
			if base.tstem then
				base.decl = "tstem-n"
			else
				base.decl = "soft-n"
			end
		end
		base.vowel_stem = stem
		return
	end
	stem = rmatch(base.lemma, "^(.*)o$")
	if stem then
		if base.gender == "m" then
			-- Cf. [[maestro]] m.
			base.decl = "o-m"
		elseif base.gender == "f" then
			-- [[zoo]]; [[Žemaitsko]]?
			error("Feminine nouns in -o are indeclinable; use '.indecl' if needed")
		elseif base.nstem then
			base.decl = "n-n"
		elseif base.hard then
			base.decl = "hard-n"
		elseif rfind(stem, "[aeiuy]$") then
			-- These have gen pl in -í and often other soft plural endings.
			base.decl = "semisoft-n"
		else
			base.decl = "hard-n"
		end
		base.vowel_stem = stem
		return
	end
	stem = rmatch(base.lemma, "^(.*[iy])$")
	if stem then
		if base.gender == "m" then
			if base.soft then
				-- [[gay]] "gay man", [[gray]] "gray (scientific unit)", [[Nagy]] (surname)
				base.decl = "soft-m"
			else
				-- Cf. [[kivi]] "kiwi (bird)", [[husky]] "kusky", etc.
				base.decl = "i-m"
			end
		elseif base.gender == "f" then
			if base.soft then
				-- [[Uruguay]], [[Paraguay]]
				base.decl = "soft-f"
			else
				-- [[máti]], [[pramáti]]; note also indeclinable [[tsunami]]/[[cunami]], [[okapi]]
				base.decl = "i-f"
				if stem:find("i$") then
					stem = stem:gsub("i$", "")
				else
					error("Feminine nouns in -y are either soft or indeclinable; use '.soft' or '.indecl' as needed")
				end
			end
		else
			error("Neuter nouns in -i are indeclinable; use '.indecl' if needed")
		end
		base.vowel_stem = stem
		return
	end
	stem = rmatch(base.lemma, "^(.*u)$")
	if stem then
		if base.gender == "m" then
			-- Cf. [[emu]], [[guru]], etc.
			base.decl = "u-m"
		elseif base.gender == "f" then
			-- Only one I know is [[budižkničemu]], which is indeclinable in the singular and declines in the plural as
			-- if written 'budižkničema'.
			error("Feminine nouns in -u are indeclinable; use '.indecl' if needed")
		else
			error("Neuter nouns in -u are indeclinable; use '.indecl' if needed")
		end
		base.vowel_stem = stem
		return
	end
	stem = rmatch(base.lemma, "^(.*[íý])$")
	if stem then
		if base.gender == "m" then
			base.decl = "í-m"
		elseif base.gender == "f" then
			-- FIXME: Do any exist? If not, update this message.
			error("Support for non-adjectival non-indeclinable feminine nouns in -í/-ý not yet implemented")
		else
			base.decl = "í-n"
		end
		base.vowel_stem = stem
		return
	end
	stem = rmatch(base.lemma, "^(.*" .. com.cons_c .. ")$")
	if stem then
		if base.gender == "m" then
			if base.foreign then
				-- [[komunismus]] "communism", [[kosmos]] "cosmos", [[hádes]] "Hades"
				stem = rmatch(base.lemma, "^(.*)[ueoaéá]s$")
				if not stem then
					error("Unrecognized masculine foreign ending, should be -us, -es, -os, -as, -és or -ás")
				end
				if not base.hard and (rfind(stem, "[ei]$") and base.animacy == "an" or
					rfind(stem, "i$") and base.animacy == "inan") then
					-- [[genius]], [[basileus]], [[rádius]]; not [[nukleus]], [[choreus]] (inanimate); not
					-- [[skarabeus]] (animate), which should specify 'hard'
					base.decl = "semisoft-m"
				else
					base.decl = "hard-m"
				end
				-- set the lemma here as if decllemma: were given
				base.lemma = stem
			elseif base.hard then
				base.decl = "hard-m"
			elseif base.soft then
				base.decl = "soft-m"
			elseif base.mixed then
				base.decl = "mixed-m"
			elseif rfind(base.lemma, com.inherently_soft_c .. "$") or rfind(base.lemma, "tel$") then
				base.decl = "soft-m"
			else
				base.decl = "hard-m"
			end
		elseif base.gender == "f" then
			if base.mixedistem then
				base.decl = "mixed-istem-f"
			elseif base.istem then
				base.decl = "istem-f"
			elseif base["-istem"] then
				base.decl = "cons-f"
			elseif rfind(base.lemma, "st$") then
				-- Numerous abstracts in -ost; also [[kost]], [[část]], [[srst]], [[bolest]]
				base.decl = "istem-f"
			else
				base.decl = "cons-f"
			end
		elseif base.gender == "n" then
			if base.foreign then
				stem = rmatch(base.lemma, "^(.*)um$") or rmatch(base.lemma, "^(.*)on$")
				if not stem then
					error("Unrecognized neuter foreign ending, should be -um or -on")
				end
				if base.hard then
					base.decl = "hard-n"
				elseif rfind(stem, "[eiuy]$") then
					base.decl = "semisoft-n"
				else
					base.decl = "hard-n"
				end
				-- set the lemma here as if decllemma: were given
				base.lemma = stem .. "o"
				base.vowel_stem = stem
				return
			else
				error("Neuter nouns ending in a consonant should use '.foreign' or '.decllemma:...'")
			end
		end
		base.nonvowel_stem = stem
		return
	end
	error("Unrecognized ending for lemma: '" .. base.lemma .. "'")
end


-- Determine the stems to use for each stem set: vowel and nonvowel stems, for singular
-- and plural. We assume that one of base.vowel_stem or base.nonvowel_stem has been
-- set in determine_declension(), depending on whether the lemma ends in
-- a vowel. We construct all the rest given the reducibility, vowel alternation spec and
-- any explicit stems given. We store the determined stems inside of the stem-set objects
-- in `base.stem_sets`, meaning that if the user gave multiple reducible or vowel-alternation
-- patterns, we will compute multiple sets of stems. The reason is that the stems may vary
-- depending on the reducibility and vowel alternation.
local function determine_props(base)
	if not base.prop_sets then
		base.prop_sets = {{}}
	end

	-- Now determine all the props for each stem set.
	for _, props in ipairs(base.prop_sets) do
		local lemma_is_vowel_stem = not not base.vowel_stem
		if base.vowel_stem then
			props.vowel_stem = base.vowel_stem
			props.nonvowel_stem = props.vowel_stem
			-- Apply vowel alternation first in cases like jádro -> jader; apply_vowel_alternation() will throw an error
			-- if the vowel being modified isn't the last vowel in the stem.
			props.oblique_nonvowel_stem = com.apply_vowel_alternation(props.vowelalt, props.nonvowel_stem)
		else
			props.nonvowel_stem = base.nonvowel_stem
			-- The user specified #, #ě, ## or ##ě and we're dealing with a term like masculine [[bůh]] or feminine
			-- [[sůl]] that ends in a consonant. In this case, all slots except the nom_s and maybe acc_s have vowel
			-- alternation.
			if props.oblique_slots then
				props.oblique_slots = "all"
			end
			props.oblique_nonvowel_stem = com.apply_vowel_alternation(props.vowelalt, props.nonvowel_stem)
			props.vowel_stem = base.nonvowel_stem
		end
		props.oblique_vowel_stem = com.apply_vowel_alternation(props.vowelalt, props.vowel_stem)
	end
end


local function detect_indicator_spec(base)
	if base.pron then
		determine_pronoun_stems(base)
	elseif base.det then
		determine_determiner_stems(base)
	elseif base.num then
		determine_numeral_stems(base)
	elseif base.adj then
		process_declnumber(base)
		synthesize_adj_lemma(base)
	else
		if base.number == "pl" then
			synthesize_singular_lemma(base)
		end
		determine_declension(base)
		determine_stems(base)
	end
end


local function detect_all_indicator_specs(alternant_multiword_spec)
	-- Keep track of all genders seen in the singular and plural so we can determine whether to add the term to
	-- [[:Category:Icelandic nouns that change gender in the plural]].
	alternant_multiword_spec.sg_genders = {}
	alternant_multiword_spec.pl_genders = {}
	iut.map_word_specs(alternant_multiword_spec, function(base)
		detect_indicator_spec(base)
		if base.number ~= "pl" then
			alternant_multiword_spec.sg_genders[base.actual_gender] = true
		end
		if base.number ~= "sg" then
			-- All t-stem masculines are neuter in the plural.
			local plgender
			if base.decl == "tstem-m" then
				plgender = "n"
			else
				plgender = base.actual_gender
			end
			alternant_multiword_spec.pl_genders[plgender] = true
		end
	end)
	if (alternant_multiword_spec.saw_pron and 1 or 0) + (alternant_multiword_spec.saw_det and 1 or 0) + (alternant_multiword_spec.saw_num and 1 or 0) > 1 then
		error("Can't combine pronouns, determiners and/or numerals")
	end
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
Propagate `property` (one of "animacy", "gender" or "number") from nouns to adjacent
adjectives. We proceed as follows:
1. We assume the properties in question are already set on all nouns. This should happen in
   set_defaults_and_check_bad_indicators().
2. We first propagate properties upwards and sideways. We recurse downwards from the top. When we encounter a multiword
   spec, we proceed left to right looking for a noun. When we find a noun, we fetch its property (recursing if the noun
   is an alternant), and propagate it to any adjectives to its left, up to the next noun to the left. When we have
   processed the last noun, we also propagate its property value to any adjectives to the right (to handle e.g.
   [[anděl strážný]] "guardian angel", where the adjective [[strážný]] should inherit the 'masculine' and 'animate'
   properties of [[anděl]]). Finally, we set the property value for the multiword spec itself by combining all the
   non-nil properties of the individual elements. If all non-nil properties have the same value, the result is that
   value, otherwise it is `mixed_value` (which is "mixed" for animacy and gender, but "both" for number).
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
	elseif alternant_multiword_spec.saw_det and not alternant_multiword_spec.saw_non_det then
		alternant_multiword_spec.pos = "determiner"
	elseif alternant_multiword_spec.saw_num and not alternant_multiword_spec.saw_non_num then
		alternant_multiword_spec.pos = "numeral"
	else
		alternant_multiword_spec.pos = "noun"
	end
	alternant_multiword_spec.plpos = require("Module:string utilities").pluralize(alternant_multiword_spec.pos)
end


local function normalize_all_lemmas(alternant_multiword_spec, pagename)
	iut.map_word_specs(alternant_multiword_spec, function(base)
		if base.lemma == "" then
			base.lemma = pagename
		end
		base.orig_lemma = base.lemma
		base.orig_lemma_no_links = m_links.remove_links(base.lemma)
		local lemma = base.orig_lemma_no_links
		-- If the lemma is all-uppercase, lowercase it but note this, so that later in combine_stem_ending() we convert it
		-- back to uppercase. This allows us to handle all-uppercase acronyms without a lot of extra complexity.
		-- FIXME: This may not make sense at all.
		if uupper(lemma) == lemma then
			base.all_uppercase = true
			lemma = ulower(lemma)
		end
		base.actual_lemma = lemma
		base.lemma = base.decllemma or lemma
	end)
end


local function decline_noun(base)
	for _, stems in ipairs(base.stem_sets) do
		if not decls[base.decl] then
			error("Internal error: Unrecognized declension type '" .. base.decl .. "'")
		end
		decls[base.decl](base, props)
	end
	handle_derived_slots_and_overrides(base)
	local function copy(from_slot, to_slot)
		base.forms[to_slot] = base.forms[from_slot]
	end
	if base.actual_number ~= base.number then
		local source_num = base.number == "sg" and "_s" or "_p"
		local dest_num = base.number == "sg" and "_p" or "_s"
		for case, _ in pairs(cases) do
			copy(case .. source_num, case .. dest_num)
			copy("nom" .. source_num .. "_linked", "nom" .. dest_num .. "_linked")
		end
		if base.actual_number ~= "both" then
			local erase_num = base.actual_number == "sg" and "_p" or "_s"
			for case, _ in pairs(cases) do
				base.forms[case .. erase_num] = nil
			end
			base.forms["nom" .. erase_num .. "_linked"] = nil
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
	local all_cats = {}
	local function insert(cattype)
		m_table.insertIfNot(all_cats, "Icelandic " .. cattype)
	end
	if alternant_multiword_spec.pos == "noun" then
		if alternant_multiword_spec.actual_number == "sg" then
			insert("uncountable nouns")
		elseif alternant_multiword_spec.actual_number == "pl" then
			insert("pluralia tantum")
		end
	end
	local annotation
	local annparts = {}
	local decldescs = {}
	local vowelalts = {}
	local foreign = {}
	local irregs = {}
	local stemspecs = {}
	local function get_genanim(gender, animacy)
		local gender_code_to_desc = {
			m = "masculine",
			f = "feminine",
			n = "neuter",
			none = nil,
		}
		local animacy_code_to_desc = {
			an = "animate",
			inan = "inanimate",
			none = nil,
		}
		local descs = {}
		table.insert(descs, gender_code_to_desc[gender])
		if gender ~= "f" and gender ~= "n" then
			-- masculine or "none" (e.g. certain pronouns and numerals)
			table.insert(descs, animacy_code_to_desc[animacy])
		end
		return table.concat(descs, " ")
	end

	local function trim(text)
		text = text:gsub(" +", " ")
		return mw.text.trim(text)
	end

	local function do_word_spec(base)
		local actual_genanim = get_genanim(base.actual_gender, base.actual_animacy)
		local declined_genanim = get_genanim(base.gender, base.animacy)
		local genanim
		if actual_genanim ~= declined_genanim then
			genanim = ("%s (declined as %s)"):format(actual_genanim, declined_genanim)
			insert("nouns with actual gender different from declined gender")
		else
			genanim = actual_genanim
		end
		if base.actual_gender == "m" then
			-- Insert a category for 'Icelandic masculine animate nouns' or 'Icelandic masculine inanimate nouns'; the base categories
			-- [[:Category:Icelandic masculine nouns]], [[:Icelandic animate nouns]] are auto-inserted.
			insert(actual_genanim .. " " .. alternant_multiword_spec.plpos)
		end
		for _, stems in ipairs(base.stem_sets) do
			local props = declprops[base.decl]
			local cats = props.cat
			if type(cats) == "function" then
				cats = cats(base, props)
			end
			if type(cats) == "string" then
				cats = {cats}
			end
			local default_desc
			for i, cat in ipairs(cats) do
				if not cat:find("GENDER") and not cat:find("GENPOS") and not cat:find("POS") then
					cat = cat .. " GENPOS"
				end
				cat = cat:gsub("GENPOS", "GENDER POS")
				if not cat:find("POS") then
					cat = cat .. " POS"
				end
				if i == #cats then
					default_desc = cat:gsub(" POS", "")
				end
				cat = cat:gsub("GENDER", actual_genanim)
				cat = cat:gsub("POS", alternant_multiword_spec.plpos)
				-- Need to trim `cat` because actual_genanim may be an empty string.
				insert(trim(cat))
			end

			local desc = props.desc
			if type(desc) == "function" then
				desc = desc(base, props)
			end
			desc = desc or default_desc
			desc = desc:gsub("GENDER", genanim)
			-- Need to trim `desc` because genanim may be an empty string.
			m_table.insertIfNot(decldescs, trim(desc))

			local vowelalt
			if stems.vowelalt == "quant" then
				vowelalt = "quant-alt"
				insert("nouns with quantitative vowel alternation")
			elseif stems.vowelalt == "quant-ě" then
				vowelalt = "í-ě-alt"
				insert("nouns with í-ě alternation")
			end
			if vowelalt then
				m_table.insertIfNot(vowelalts, vowelalt)
			end
			if base.foreign then
				m_table.insertIfNot(foreign, "foreign")
				if not base.decllemma then
					-- NOTE: there are nouns that use both 'foreign' and 'decllemma', e.g. [[Zeus]].
					insert("nouns with regular foreign declension")
				end
			end
			-- User-specified 'decllemma:' indicates irregular stem. Don't consider foreign nouns in -us/-os/-es, -um/-on or
			-- silent -e (e.g. [[software]]) where this ending is simply dropped in oblique and plural forms as irregular;
			-- there are too many of these and they are already categorized above as 'nouns with regular foreign declension'.
			if base.decllemma then
				m_table.insertIfNot(irregs, "irreg-stem")
				insert("nouns with irregular stem")
			end
			m_table.insertIfNot(stemspecs, stems.vowel_stem)
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
	if alternant_multiword_spec.actual_number == "sg" or alternant_multiword_spec.actual_number == "pl" then
		-- not "both" or "none" (for [[sebe]])
		table.insert(annparts, alternant_multiword_spec.actual_number == "sg" and "sg-only" or "pl-only")
	end
	if #decldescs == 0 then
		table.insert(annparts, "indecl")
	else
		table.insert(annparts, table.concat(decldescs, " // "))
	end
	if #vowelalts > 0 then
		table.insert(annparts, table.concat(vowelalts, "/"))
	end
	if #foreign > 0 then
		table.insert(annparts, table.concat(foreign, " // "))
	end
	if #irregs > 0 then
		table.insert(annparts, table.concat(irregs, " // "))
	end
	alternant_multiword_spec.annotation = table.concat(annparts, " ")
	if #stemspecs > 1 then
		insert("nouns with multiple stems")
	end
	if alternant_multiword_spec.actual_number == "both" and not m_table.deepEquals(alternant_multiword_spec.sg_genders, alternant_multiword_spec.pl_genders) then
		insert("nouns that change gender in the plural")
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
		slot_table = alternant_multiword_spec.output_noun_slots,
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
<div class="NavHead" style="background:#eff7ff">{title}{annotation}</div>
<div class="NavContent" style="overflow:auto">
{\op}| style="background:#F9F9F9;text-align:center;min-width:MINWIDTHem" class="inflection-table"
|-
]=], "MINWIDTH", min_width)
	end

	local function template_postlude()
		return [=[
|{\cl}{notes_clause}</div></div></div>]=]
	end

	local table_spec_both = template_prelude("45") .. [=[
! style="width:20%;background:#d9ebff" |
! style="background:#d9ebff" colspan="2" | singular
! style="background:#d9ebff" colspan="2" | plural
|-
! style="background:#d9ebff" | indefinite
! style="background:#d9ebff" | definite
! style="background:#d9ebff" | indefinite
! style="background:#d9ebff" | definite
|-
!style="background:#eff7ff"|nominative
| {ind_nom_s}
| {def_nom_s}
| {ind_nom_p}
| {def_nom_p}
|-
!style="background:#eff7ff"|accusative
| {ind_acc_s}
| {def_acc_s}
| {ind_acc_p}
| {def_acc_p}
|-
!style="background:#eff7ff"|dative
| {ind_dat_s}
| {def_dat_s}
| {ind_dat_p}
| {def_dat_p}
|-
!style="background:#eff7ff"|genitive
| {ind_gen_s}
| {def_gen_s}
| {ind_gen_p}
| {def_gen_p}
]=] .. template_postlude()

	local function get_table_spec_one_number(number, numcode)
		local table_spec_one_number = [=[
! style="width:33%;background:#d9ebff" |
! style="background:#d9ebff" colspan="2" | NUMBER
|-
! style="background:#d9ebff" | indefinite
! style="background:#d9ebff" | definite
|-
!style="background:#eff7ff"|nominative
| {ind_nom_NUM}
| {def_nom_NUM}
|-
!style="background:#eff7ff"|accusative
| {ind_acc_NUM}
| {def_acc_NUM}
|-
!style="background:#eff7ff"|dative
| {ind_dat_NUM}
| {def_dat_NUM}
|-
!style="background:#eff7ff"|genitive
| {ind_gen_NUM}
| {def_gen_NUM}
]=]
		return template_prelude("30") .. table_spec_one_number:gsub("NUMBER", number):gsub("NUM", numcode) ..
			template_postlude()
	end

	local function get_table_spec_one_number_one_def(number, numcode, definiteness, defcode)
		local table_spec_one_number_one_def = [=[
! style="width:50%;background:#d9ebff" |
! style="background:#d9ebff" | NUMBER
|-
! style="background:#d9ebff" | DEFINITENESS
|-
!style="background:#eff7ff"|nominative
| {DEF_nom_NUM}
|-
!style="background:#eff7ff"|accusative
| {DEF_acc_NUM}
|-
!style="background:#eff7ff"|dative
| {DEF_dat_NUM}
|-
!style="background:#eff7ff"|genitive
| {DEF_gen_NUM}
]=]
		return template_prelude("20") .. (table_spec_one_number_one_def:gsub("NUMBER", number):gsub("NUM", numcode)
			:gsub("DEFINITENESS", definiteness):gsub("DEF", defcode)) .. template_postlude()
	end

	local notes_template = [=[
<div style="width:100%;text-align:left;background:#d9ebff">
<div style="display:inline-block;text-align:left;padding-left:1em;padding-right:1em">
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
		number, numcode = "", "s"
	end

	local table_spec =
		alternant_multiword_spec.actual_number == "both" and table_spec_both or
		get_table_spec_one_number(number, numcode)
	forms.notes_clause = forms.footnote ~= "" and
		m_string_utilities.format(notes_template, forms) or ""
	return m_string_utilities.format(table_spec, forms)
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
		local animacy = base.animacy
		if animacy == "inan" then
			animacy = "in"
		end
		m_table.insertIfNot(genders, base.gender .. "-" .. animacy .. number)
	end)
	return genders
end


-- Externally callable function to parse and decline a noun given user-specified arguments.
-- Return value is ALTERNANT_MULTIWORD_SPEC, an object where the declined forms are in
-- `ALTERNANT_MULTIWORD_SPEC.forms` for each slot. If there are no values for a slot, the
-- slot key will be missing. The value for a given slot is a list of objects
-- {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms(parent_args, from_headword)
	local params = {
		[1] = {required = true, default = "bůh<m.an.#.voce>"},
		title = {},
		pagename = {},
		json = {type = "boolean"},
		pos = {},
	}

	if from_headword then
		params["head"] = {list = true}
		params["lemma"] = {list = true}
		params["g"] = {list = true}
		params["f"] = {list = true}
		params["m"] = {list = true}
		params["adj"] = {list = true}
		params["dim"] = {list = true}
		params["id"] = {}
	end

	local args = m_para.process(parent_args, params)
	local parse_props = {
		parse_indicator_spec = parse_indicator_spec,
		angle_brackets_omittable = true,
		allow_blank_lemma = true,
	}
	local alternant_multiword_spec = iut.parse_inflected_text(args[1], parse_props)
	alternant_multiword_spec.title = args.title
	alternant_multiword_spec.args = args
	local pagename = args.pagename or from_headword and args.head[1] or mw.title.getCurrentTitle().subpageText
	normalize_all_lemmas(alternant_multiword_spec, pagename)
	set_all_defaults_and_check_bad_indicators(alternant_multiword_spec)
	-- These need to happen before detect_all_indicator_specs() so that adjectives get their genders and numbers set
	-- appropriately, which are needed to correctly synthesize the adjective lemma.
	propagate_properties(alternant_multiword_spec, "animacy", "inan", "mixed")
	propagate_properties(alternant_multiword_spec, "number", "both", "both")
	-- FIXME, the default value (third param) used to be 'm' with a comment indicating that this applied only to
	-- plural adjectives, where it didn't matter; but in Icelandic, plural adjectives are distinguished for gender and
	-- animacy. Make sure 'mixed' works.
	propagate_properties(alternant_multiword_spec, "gender", "mixed", "mixed")
	detect_all_indicator_specs(alternant_multiword_spec)
	-- Propagate 'actual_number' after calling detect_all_indicator_specs(), which sets 'actual_number' for adjectives.
	propagate_properties(alternant_multiword_spec, "actual_number", "both", "both")
	determine_noun_status(alternant_multiword_spec)
	set_pos(alternant_multiword_spec)
	alternant_multiword_spec.output_noun_slots = get_output_noun_slots(alternant_multiword_spec)
	local inflect_props = {
		skip_slot = function(slot)
			return skip_slot(alternant_multiword_spec.actual_number, slot)
		end,
		slot_table = alternant_multiword_spec.output_noun_slots,
		get_variants = get_variants,
		inflect_word_spec = decline_noun,
	}
	iut.inflect_multiword_or_alternant_multiword_spec(alternant_multiword_spec, inflect_props)
	compute_categories_and_annotation(alternant_multiword_spec)
	alternant_multiword_spec.genders = compute_headword_genders(alternant_multiword_spec)
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
	local alternant_multiword_spec = export.do_generate_forms(parent_args)
	if type(alternant_multiword_spec) == "string" then
		-- JSON return value
		return alternant_multiword_spec
	end
	show_forms(alternant_multiword_spec)
	return make_table(alternant_multiword_spec) ..
		require("Module:utilities").format_categories(alternant_multiword_spec.categories, lang, nil, nil, force_cat)
end


return export
