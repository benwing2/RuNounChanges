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


local output_noun_slots = {
	nom_s = "nom|s",
	nom_s_linked = "nom|s",
	gen_s = "gen|s",
	gen_s_linked = "gen|s",
	dat_s = "dat|s",
	acc_s = "acc|s",
	nom_p = "nom|p",
	nom_p_linked = "nom|p",
	gen_p = "gen|p",
	dat_p = "dat|p",
	acc_p = "acc|p",
}


local function get_output_noun_slots(alternant_multiword_spec)
	-- FIXME: To save memory we modify the table in-place. This won't work if we ever end up with multiple calls to
	-- this module in the same Lua invocation, and we would need to clone the table.
	if alternant_multiword_spec.actual_number ~= "both" then
		for slot, accel_form in pairs(output_noun_slots) do
			output_noun_slots[slot] = accel_form:gsub("|[sp]$", "")
		end
	end
	return output_noun_slots
end


local potential_lemma_slots = {"nom_s", "nom_p", "gen_s"}


local cases = {
	nom = true,
	gen = true,
	dat = true,
	acc = true,
}


local function skip_slot(number, slot)
	return number == "sg" and rfind(slot, "_p$") or
		number == "pl" and rfind(slot, "_s$")
end


-- Basic function to combine stem(s) and other properties with ending(s) and insert the result into the appropriate
-- slot. `base` is the object describing all the properties of the word being inflected for a single alternant (in case
-- there are multiple alternants specified using `((...))`). `slot` is the slot to add the resulting forms to. `props`
-- is an object containing computed stems and other information (such as whether i-mutation is active). The information
-- found in `props` cannot be stored in `base` because there may be more than one set of such properties per `base`
-- (e.g. if the user specified 'umut,uumut' or '-j,j' or '-imut,imut' or some combination of these; in such a case, the
-- caller will iterate over all possible combinations, and ultimately invoke add() multiple times, one per combination).
-- `indef_endings` is the ending or endings added to the appropriate stem (after any j or v infix) to get the indefinite
-- form. Its value can be a single string, a list of strings, or a list of form objects (i.e. in general list form).
-- `def_endings` is similar to `indef_endings` but for definite forms (not including the definite clitics added
-- afterwards). Most of the time (but not always), `indef_endings` and `def_endings` will be the same. `def_clitics` is
-- the clitic or clitics to add after the definite ending(s) to form the actual definite form value inserted into the
-- slot, in the same format as `def_endings` and `indef_endings`. `ending_override`, if true, indicates that the
-- ending(s) supplied in `indef_endings` and `def_endings` come from a user-specified override, and hence j and v
-- infixes should not be added as they are already included in the override if needed.
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
-- ** `unumut`: If specified (i.e. not nil), either true or false. If specified, there may be associated footnotes in
--    `unumut_footnotes`. If true, u-mutation is in effect *except* before an ending that starts with an "a" or "i"
--    (unless i-mutation is in effect, which takes precedence). When u-mutation is *not* in effect, and i-mutation is
--    also not in effect, the associated footnotes in `unumut_footnotes` apply. If false, the associated footnotes in
--    `unumut_footnotes` still apply in the same circumstances where they would apply if `unumut` where true.
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
local function add(base, slot, props, indef_endings, def_endings, def_clitics, ending_override)
	if not indef_endings and not def_endings then
		return
	end
	-- Call skip_slot() based on the declined number; if the actual number is different, we correct this in
	-- decline_noun() at the end.
	if skip_slot(base.number, slot) then
		return
	end
	footnotes = iut.combine_footnotes(base.footnotes, footnotes)
	-- Do both indefinite and definite endings. They behave very similarly except that definite endings have non-empty
	-- clitics to append after them. Most but not all of the time the definite and indefinite endings are the same (and
	-- will be set this way by the calling function), and again, most but not all of the time there is only one definite
	-- clitic per slot.
	for _, endtype in ipairs { "indef", "def" } do
		local endings, clitics
		if endtype == "indef" then
			endings = indef_endings
			clitics = {""}
		else
			endings = def_endings
			clitics = def_clitics
			if type(clitics) == "string" then
				clitics = {clitics}
			end
		end
		-- If `endings` is nil, it means to entirely skip adding any endings of this sort (indefinite or definite).
		if endings then
			if type(endings) == "string" then
				endings = {endings}
			end
			-- Loop over each ending and clitic.
			for _, endingobj in ipairs(endings) do
				local ending, ending_footnotes
				if type(endingobj) == "string" then
					ending = endingobj
				else
					ending = endingobj.form
					ending_footnotes = endingobj.footnotes
				end
				local function interr(msg)
					error(("Internal error: For slot '%s', ending '%s', %s: %s"):format(slot, ending, msg,
						dump(props)))
				end

				for _, cliticobj in ipairs(clitics) do
					local clitic, clitic_footnotes
					if type(cliticobj) == "string" then
						clitic = cliticobj
					else
						clitic = cliticobj.form
						clitic_footnotes = cliticobj.footnotes
					end

					-- Compute whether i-mutation or u-mutation is in effect, and compute the "mutation footnotes",
					-- which are footnotes attached to a mutation-related indicator and which may need to be added even
					-- if no mutation is in effect (specifically when dealing with an ending that would trigger a
					-- mutation if in effect). AFAIK you cannot have both mutations in effect at once, and i-mutation
					-- overrides u-mutation if both would be in effect.
					local explicit_imut, explicit_umut
					ending, explicit_umut = rsubb(ending, "^%^%^", "")
					if not explicit_umut then
						ending, explicit_imut = rsubb(ending, "^%^", "")
					end
					local is_vowel_ending = rfind(ending, "^" .. com.vowel_c)
					local is_vowel_clitic = rfind(clitic, "^" .. com.vowel_c)
					local mut_in_effect, mut_footnotes
					local ending_in_a = not not ending:find("^a")
					local ending_in_i = not not ending:find("^i")
					local ending_in_u = not not ending:find("^u")
					if explicit_imut then
						mut_in_effect = "i"
					elseif explicit_umut then
						mut_in_effect = "u"
					elseif props.unimut ~= nil then
						local is_unimut_slot
						if base.gender == "m" then
							is_unimut_slot = slot == "dat_s" or slot:find("_p")
						elseif base.gender == "f" then
							is_unimut_slot = slot == "acc_s" or slot == "dat_s" or slot == "dat_p" or slot == "gen_p"
						else
							interr("'unimut' shouldn't be specified with neuter nouns; don't know what slots would be affected; neuter pluralia tantum nouns using 'unimut' should have synthesized a singular without i-mutation")
						end
						if is_unimut_slot then
							mut_footnotes = props.unimut_footnotes
						elseif props.unimut then
							mut_in_effect = "i"
						end
					elseif ending_in_i then
						if props.imut then
							mut_in_effect = "i"
							mut_footnotes = props.imut_footnotes
						elseif props.imut == false then
							mut_footnotes = props.imut_footnotes
						elseif props.unumut ~= nil then
							mut_footnotes = props.unumut_footnotes
						end
					elseif ending_in_a then
						if props.unumut ~= nil then
							mut_footnotes = props.unumut_footnotes
						end
					elseif ending_in_u then
						mut_in_effect = "u"
						-- umut and uumut footnotes are incorporated into the appropriate umut_* stems
					elseif props.unumut then
						mut_in_effect = "u"
					end

					-- Now compute the appropriate stems to which the ending and clitic are added.
					if mut_in_effect == "i" then
						-- NOTE: It appears that imut and defcon never co-occur; otherwise we'd need to flesh out the
						-- set of stems to include i-mutation versions of defcon stems, similar to what we do for
						-- u-mutation.
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
						-- Careful with the following logic; it is written carefully and should not be changed without
						-- a thorough understanding of its functioning.
						local has_umut = mut_in_effect == "u"
						-- First, if the ending is null, and we have a vowel-initial definite-article clitic, use the
						-- special 'defcon' stems if available. We do this even if the ending is "-", which normally
						-- means to use the lemma regardless (which avoids problems with e.g. thinking that the
						-- masculine singular nominative ending -ur would trigger u-mutation, which will happen if we
						-- construct the nominative singular from the stem instead of just using the lemma directly).
						-- The reason for this is that when 'defcon' is active, it applies to the nominative singular,
						-- producing e.g. definite [[mastrið]] of neuter lemma [[mastur]] "mast"; here, using the
						-- lemma would incorrectly produce #[[masturið]].
						if (ending == "" or ending == "-") and is_vowel_clitic then
							if has_umut then
								stems = stems.umut_null_defvstems
							else
								stems = stems.null_defvstems
							end
						end
						-- If the stems were not set above and the ending is "-", it means to use the lemma as the form
						-- directly (before adding any definite clitic) rather than try to construct the form from a
						-- stem and ending. See the comment above for why we want to do this.
						if not stems and ending == "-" then
							stems = base.actual_lemma
							ending = ""
						end
						-- If the stems are still unset, then use the vowel or non-vowel stems if available. When
						-- u-mutation is active, we first check for u-mutated versions of the vowel or non-vowel stems
						-- before falling back to the regular vowel or non-vowel stems. Note that an expression like
						-- `has_umut and stems.umut_vstems or stems.vstems` here is NOT equivalent to an if-else or
						-- ternary operator expression because if `has_umut` is true and `umut_vstems` is missing, it
						-- will still fall back to `vstems` (which is what we want).
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

					-- If base-level footnotes specified, they go before any stem footnotes, so we need to clone the
					-- stems an insert the base-level footnotes appropriately. In general, we want the footnotes to be
					-- in the order [base.footnotes, stem.footnotes, mut_footnotes, infix_footnotes, ending.footnotes,
					-- clitic.footnotes].
					if base.footnotes then
						local stems_with_footnotes = {}
						for _, stem in ipairs(stems) do
							stem = m_table.shallowcopy(stem)
							stem.footnotes = iut.combine_footnotes(base.footnotes, stem.footnotes)
							table.insert(stems_with_footnotes, stem)
						end
						stems = stems_with_footnotes
					end

					-- Now combine stems, infix, ending and clitic. [FIXME: Not done coding]
					local stem_and_ending = foo
					clitic = iut.combine_form_and_footnotes(ending, iut.combine_footnotes(footnotes))
					local function combine_stem_ending(stems, ending)
						return com.combine_stem_ending(base, slot, stems, ending)
					end
					iut.add_forms(base.forms, slot, stems, ending, combine_stem_ending)
				end
			end
		end
	end
end


local function process_slot_overrides(base, do_slot)
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
						-- Convert a null ending to "-" in the acc/voc sg slots so that e.g. [[Kerberos]] declared as
						-- <m.sg.foreign.gena:u.acc-:a> works correctly and generates accusative 'Kerberos/Kerbera' not
						-- #'Kerber/Kerbera'.
						if (slot == "acc_s" or slot == "voc_s") and form == "" then
							form = "-"
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


local function add_decl(base, stems,
	acc_s, dat_s, gen_s, nom_p, acc_p, dat_p, gen_p, footnotes
)
	add(base, "nom_s", stems, "-", footnotes)
	add(base, "acc_s", stems, acc_s, footnotes)
	add(base, "dat_s", stems, dat_s, footnotes)
	add(base, "gen_s", stems, gen_s, footnotes)
	if base.number == "pl" then
		-- If this is a plurale tantum noun and we're processing the nominative plural, use the user-specified lemma
		-- rather than generating the plural from the synthesized singular, which may not match the specified lemma
		-- (e.g. [[tvargle]] "Olomouc cheese" using <m.pl.mixed> would try to generate 'tvargle/tvargly', and [[peníze]]
		-- "money" using <m.pl.#ě.genpl-> would try to generate 'peněze').
		local acc_p_like_nom = m_table.deepEquals(nom_p, acc_p)
		nom_p = "-"
		if acc_p_like_nom then
			acc_p = "-"
		end
	end
	add(base, "nom_p", stems, nom_p, footnotes)
	add(base, "acc_p", stems, acc_p, footnotes)
	add(base, "dat_p", stems, dat_p, footnotes)
	add(base, "gen_p", stems, gen_p, footnotes)
end

local function add_sg_decl(base, stems,
	gen_s, dat_s, acc_s, voc_s, loc_s, ins_s, footnotes
)
	add_decl(base, stems, gen_s, dat_s, acc_s, voc_s, loc_s, ins_s,
		nil, nil, nil, nil, nil, nil, footnotes)
end

local function add_pl_only_decl(base, stems,
	gen_p, dat_p, acc_p, loc_p, ins_p, footnotes
)
	add_decl(base, stems, nil, nil, nil, nil, nil, nil, 
		"-", gen_p, dat_p, acc_p, loc_p, ins_p, footnotes)
end

local function handle_derived_slots_and_overrides(base)
	local function is_non_derived_slot(slot)
		return slot ~= "voc_p" and slot ~= "acc_s"
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
-- `stems`; the latter specifies the computed stems (vowel vs. non-vowel, singular vs. plural) and whether the noun
-- is reducible and/or has vowel alternations in the stem. Most of the specifics of determining which stem to use
-- and how to modify it for the given ending are handled in add_decl(); the declension functions just need to generate
-- the appropriate endings.
local decls = {}
-- Table specifying additional properties for declension types. Every declension type must have such a table, which
-- specifies which category or categories to add and what annotation to show in the title bar of the declension table.
--
-- * Only the `cat` property of this table is mandatory; there is also a `desc` property to specify the annotation, but
--   this can be omitted and the annotation will then be computed from the `cat` property. The `cat` property is either
--   a string, a list of strings or a function (of two arguments, `base` and `stems` as above) returning a string or
--   list of strings. The string can contain the keywords GENDER to substitute the gender (and animacy for masculine
--   nouns) and POS (to substitute the pluralized part of speech). The keyword GENPOS is equivalent to 'GENDER POS'. If
--   no keyword is present, ' GENPOS' is added onto the end. If only GENDER is present, ' POS' is added onto the end.
--   In all cases, the language name is added onto the beginning to form the full category name.
-- * The `desc` property is of the same form as the `cat` property and specifies the annotation to display in the title
--   bar (which may have the same format as the category minus the part of speech, or may be abbreviated). The value
--   may not be a list of strings, as only one annotation is displayed. If omitted, it is derived from the category
--   spec(s) by taking the last category (if more than one is given) and removing ' POS' before keyword substitution.
local declprops = {}

-- Return the default masculine animate nominative plural ending(s) given `base` and `stems`. This is called for hard
-- and soft masculines ending in a consonant, but not for nouns ending in a vowel, which have their own defaults
-- (particularly nouns in -a, where -ista/-ita/-asta behave differently from other nouns in -a).
local function default_masc_animate_nom_pl(base, stems)
	return
		-- [monosyllabic words: Dánové, Irové, králové, mágové, Rusové, sokové, synové, špehové, zběhové, zeťové, manové, danové
		-- (but Žid → Židé, Čech → Češi).] -- There are too many exceptions to this to make a special rule. It is better to use
		-- the overall default of -i and require that cases with -ove, -ove/-i, -i/-ove, etc. use overrides.
		-- com.is_monosyllabic(base.lemma) and "ové" or
		-- reducible terms in -Cek; order of -ové vs. -i sometimes varies:
		-- [[fracek]] (ové/i), [[klacek]] (i/ové), [[macek]] (ové/i), [[nácek]] (i/ové), [[prcek]] (ové/i), [[racek]] (ové/i);
		-- [[bazilišek]] (i/ové), [[černoušek]] (i/ové), [[drahoušek]] (ové/i), [[fanoušek]] (i/ové), [[františek]] (an/inan,
		-- ends in -i/-y but not -ové), [[koloušek]] (-i only), [[kulíšek]] (i/ové), [[oříšek]] (i/ové), [[papoušek]] (-i only),
		-- [[prášek]] (i/ové), [[šašek]] (i/ové).
		-- make sure to check `stems` as we don't want to include non-reducible words in -Cek (but do want to include
		-- [[quarterback]], with -i/-ové)
		rfind(stems.vowel_stem, "^" .. com.lowercase_c .. ".*" .. com.cons_c .. "k$") and {"i", "ové"} or
		-- [[stoik]], [[neurotik]], [[logik]], [[fyzik]], etc.
		rfind(base.lemma, "^" .. com.lowercase_c .. ".ik$") and {"i", "ové"} or
		-- barmani, gentlemani, jazzmani, kameramani, narkomani, ombudsmani, pivotmani, rekordmani, showmani, supermani, toxikomani
		rfind(base.lemma, "^" .. com.lowercase_c .. ".*man$") and "i" or
		-- terms ending in -an after a palatal or a consonant that doesn't change when palatalized, i.e. labial or l (but -man
		-- forms -mani unless in a proper noun): Brňan → Brňané, křesťan → křesťané, měšťan → měšťané, Moravan → Moravané,
		-- občan → občané, ostrovan → ostrované, Pražan → Pražané, Slovan → Slované, svatebčan → svatebčané, venkovan → venkované,
		-- Australan → Australané; also s, because there are many demonyms in -san e.g. [[Andalusan]], [[Barbadosan]], [[Oděsan]],
		-- and few proper nouns in -san; similarly z because of [[Belizan]], [[Gazan]], [[Kavkazan]], etc.; also w, which isn't a
		-- normal consonant in Icelandic but occurs in [[Glasgowan]] and [[Zimbabwan]]; NOTE: a few misc words like [[pohan]] also
		-- work this way but need manual overrides
		rfind(base.lemma, "[" .. com.inherently_soft .. com.labial .. "wlsz]an$") and {"é", "i"} or -- most now can also take -i
		-- proper names: Baťové, Novákové, Petrové, Tomášové, Vláďové; exclude demonyms (but include surnames)
		rfind(base.lemma, "^" .. com.uppercase_c) and (base.surname or not rfind(base.lemma, "[eě]c$")) and "ové" or
		-- demonyms: [[Albánec]], [[Gruzínec]], [[Izraelec]], [[Korejec]], [[Libyjec]], [[Litevec]], [[Němec]], [[Portugalec]]
		rfind(base.lemma, "^" .. com.uppercase_c .. ".*[eě]c$") and "i" or
		-- From here on down, we're dealing only with lowercase terms.
		-- buditelé, budovatelé, čekatelé, činitelé, hostitelé, jmenovatelé, pisatelé, ručitelé, velitelé, živitelé
		rfind(base.lemma, ".*tel$") and "é" or
		-- nouns in -j: čaroděj → čarodějové, lokaj → lokajové, patricij → patricijové, plebej → plebejové, šohaj → šohajové, žokej → žokejové
		-- nouns in -l: apoštol → apoštolové, břídil → břídilové, fňukal → fňukalové, hýřil → hýřilové, kutil → kutilové,
		--   loudal → loudalové, mazal → mazalové, škrabal → škrabalové, škudlil → škudlilové, vyvrhel → vyvrhelové, žvanil → žvanilové
		--   (we excluded those in -tel above)
		rfind(base.lemma, ".*[jl]$") and "ové" or
		-- archeolog → archeologové, biolog → biologové, geolog → geologové, meteorolog → meteorologové
		rfind(base.lemma, ".*log$") and "ové" or
		-- dramaturg → dramaturgové, chirurg → chirurgové
		rfind(base.lemma, ".*urg$") and "ové" or
		-- fotograf → fotografové, geograf → geografové, lexikograf → lexikografové
		rfind(base.lemma, ".*graf$") and "ové" or
		-- bibliofil → bibliofilové, germanofil → germanofilové
		rfind(base.lemma, ".*fil$") and "ové" or
		-- rusofob → rusofobové
		rfind(base.lemma, ".*fob$") and "ové" or
		-- agronom → agronomové, ekonom → ekonomové
		rfind(base.lemma, ".*nom$") and "ové" or
		"i"
end


decls["strong-m"] = function(base, stems)
	-- [[kádí]] "qadi (Islamic judge)", [[mahdí]] "Mahdi (Islamic prophet)", [[muftí]] "mufti (Islamic scholar)",
	-- [[sipáhí]] "sipahi (Algerian cavalryman in the French army)"
	--
	-- No obvious examples in -ý, but the support is there.
	--
	-- NOTE: The stem ends in -í/-ý.
	add_decl(base, stems, "ho", "mu", nil, "-", "m", "m",
		{"ové", ""}, {"ů", "ch"}, {"ům", "m"}, {"e", ""}, "ích", "mi")
end

declprops["í-m"] = {
	cat = "GENPOS in -í/-ý"
}


decls["hard-m"] = function(base, stems)
	-- Nouns ending in hard -c, e.g. [[hec]] "joke", [[kibuc]] "kibbutz", don't palatalize.
	base.palatalize_voc = not rfind(stems.vowel_stem, "c$")
	base.hard_c = true
	local velar = base.velar or not base["-velar"] and rfind(stems.vowel_stem, com.velar_c .. "$")
	-- See [https://prirucka.ujc.cas.cz/en/?id=360] on declension of toponyms.
	local toponym = base.animacy == "inan" and rfind(base.lemma, "^" .. com.uppercase_c)
	-- Some toponyms take -a in the genitive singular, e.g. toponyms in -ín ([[Zlín]], [[Jičín]], [[Berlín]]);
	-- -ýn ([[Hostýn]], [[Londýn]]); -ov ([[Havířov]]); and -ev ([[Bezdrev]]), as do some others, e.g. domestic
	-- [[Beroun]], [[Brandýs]], [[Náchod]], [[Tábor]] and foreign [[Betlém]] "Bethlehem", [[Egypt]],
	-- [[Jeruzalém]] "Jerusalem", [[Milán]] "Milan", [[Řím]] "Rome", [[Rýn]] "Rhine". Also some transferred from
	-- common nouns e.g. ([[Nový]]) [[Kostel]], ([[Starý]]) [[Rybník]].
	local toponym_gen_a = toponym and (rfind(base.lemma, "[íý]n$") or rfind(base.lemma, "[oe]v$"))
	-- Toponyms in -ík (Mělník, Braník, Rakovník, Lipník) seem to fluctuate between gen -a and -u. Also some in
	-- ‑štejn, ‑berg, ‑perk, ‑burk, ‑purk (Rabštejn, Heidelberg, Kašperk, Hamburk, Prešpurk) and some others:
	-- Zbiroh, Kamýk, Příbor, Zábřeh, Žebrák, Praděd.
	local toponym_gen_a_u = toponym and rfind(base.lemma, "ík$")
	-- Toponyms that take -a in the genitive singular tend to take -ě in the locative singular; so do those in
	-- -štejn (Rabštejn), -hrad (Petrohrad), -grad (Volgograd).
	local toponym_loc_e = toponym and (toponym_gen_a or rfind(base.lemma, "štejn$") or rfind(base.lemma, "[gh]rad$"))
	-- Toponyms in -ík seem to fluctuate between loc -ě and -u.
	local toponym_loc_e_u = toponym_gen_a_u
	-- Inanimate gen_s in -a other than toponyms in -ín/-ýn/-ev/-ov (e.g. [[zákon]] "law", [[oběd]] "lunch", [[kostel]] "church",
	-- [[dnešek]] "today", [[leden]] "January", [[trujúhelník]] "triangle") needs to be given manually, using '<gena>'.
	local gen_s = toponym_gen_a and "a" or toponym_gen_a_u and {"a", "u"} or base.animacy == "inan" and "u" or "a"
	-- Animates with dat_s only in -u (e.g. [[člověk]] "person", [[Bůh]] "God") need to give this manually,
	-- using '<datu>'.
	local dat_s = base.animacy == "inan" and "u" or base.surname and "ovi" or {"ovi", "u"}
	-- Inanimates with loc_s in -e/ě other than certain toponyms (see above) need to give this manually, using <locě>, but
	-- it will trigger the second palatalization automatically.
	local loc_s = toponym_loc_e and "ě" or toponym_loc_e_u and {"ě", "u"} or dat_s
	-- Velar-stem animates with voc_s in -e (e.g. [[Bůh]] "God", voc_s 'Bože'; [[člověk]] "person", voc_s 'člověče')
	-- need to give this manually using <voce>; it will trigger the first palatalization automatically.
	local voc_s = velar and "u" or "e" -- 'e' will trigger first palatalization in apply_special_cases()
	-- Nom_p in -i will trigger second palatalization in apply_special_cases().
	local nom_p = base.animacy == "inan" and "y" or default_masc_animate_nom_pl(base, stems)
	-- Per IJP and Janda and Townsend:
	-- * loc_p in -ích is currently the default for velars but not otherwise; it will automatically trigger the second
	--   palatalization (e.g. [[práh]] "threshold", loc_p 'prazích'). Otherwise, -ích needs to be given manually using
	--   <locplích>, e.g. [[les]] "forest"; [[hotel]] "hotel"; likewise for loc_p in -ách (e.g. [[plech]]
	--   "metal plate"), using <locplách>.
	-- * Inanimate hard nouns in -c normally have -ech: [[hec]] "joke", [[tác]] "tray", [[truc]], [[kec]], [[frc]],
	--   [[flanc]], [[kibuc]] "kibbutz", [[pokec]] "chat".
	-- In the IJP tables, inanimate reducible nouns in -ček (and most in -cek, although there are many fewer; also some
	-- in -žek, but in this case it's too inconsistent to make the default) regularly have both -ích and -ách in the
	-- locative plural, while similar animate nouns only have -ích. This applies even to nouns like [[háček]] and
	-- [[koníček]] that can be either animate or inanimate. Make sure to exclude nouns in -ck such as [[comeback]] and
	-- [[joystick]], which have only -ích.
	local loc_p =
		base.animacy == "inan" and rfind(base.lemma, "[cč]ek$") and rfind(stems.vowel_stem, "[cč]k$") and {"ích", "ách"} or
		velar and "ích" or "ech"
	add_decl(base, stems, gen_s, dat_s, nil, voc_s, loc_s, "em",
		-- loc_p in -ích not after velar stems (e.g. [[les]] "forest"; [[hotel]] "hotel") needs to be given manually
		-- using <locplích>; it will automatically trigger the second palatalization; loc_p in -ách (e.g. [[plech]]
		-- "metal plate") also needs to be given manually using <locplách>
		nom_p, "ů", "ům", "y", loc_p, "y")
end

declprops["hard-m"] = {
	desc = function(base, stems)
		if base.velar or not base["-velar"] and rfind(stems.vowel_stem, com.velar_c .. "$") then
			return "velar GENDER"
		else
			return "hard GENDER"
		end
	end,
	cat = function(base, stems)
		if base.velar or not base["-velar"] and rfind(stems.vowel_stem, com.velar_c .. "$") then
			return "velar-stem"
		else
			return "hard"
		end
	end
}


decls["semisoft-m"] = function(base, stems)
	-- Examples:
	-- * Animate in -ius: génius, nuncius, nonius (breed of horse), notárius, ordinárius, patricius, primárius,
	--   pronuncius, various names
	-- * Animate in -eus: farizeus, basileus, pygmeus ([[skarabeus]] inflects hard in the plural), various names
	-- * Inanimate in -ius: nonius (measuring device), rádius, sestercius
	-- NOTE: Inanimate nouns in -eus (nukleus, choreus) inflect hard in the plural
	local dat_s = base.animacy == "inan" and "u" or base.surname and "ovi" or {"ovi", "u"}
	local loc_s = dat_s
	local nom_p = base.animacy == "inan" and "e" or "ové"
	add_decl(base, stems, "a", dat_s, nil, "e", loc_s, "em",
		nom_p, "ů", "ům", "e", "ích", "i")
end

declprops["semisoft-m"] = {
	cat = "semisoft"
}


decls["soft-m"] = function(base, stems)
	base.palatalize_voc = true
	-- animates with dat_s only in -i need to give this manually, using '<dati>'
	local dat_s = base.animacy == "inan" and "i" or base.surname and "ovi" or {"ovi", "i"}
	local loc_s = dat_s
	-- Per IJP, the vast majority of soft masculine animates take -i in the voc_s, but those in -ec/-ěc take -e with first
	-- palatalization to -če, e.g. [[otec]] "father", [[lovec]] "hunter", [[blbec]] "fool, idiot", [[horolezec]]
	-- "mountaineer", [[znalec]] "expert", [[chlapec]] "boy", [[nadšenec]] "enthusiast", [[luněc]] (type of bird).
	-- Demonyms but not surnames ending in -ec but beginning with a capital letter take either -e or -i (only the former
	-- triggers the first palatalization). Examples: [[Portugalec]], [[Slovinec]] "Slovenian", [[Japonec]], [[Vietnamec]].
	-- Not [[Kadlec]] (surname).
	local voc_s = base.animacy == "an" and rfind(base.lemma, "[eě]c$") and stems.reducible and
		(not base.surname and rfind(base.lemma, "^" .. com.uppercase_c) and {"e", "i"} or "e") or "i"
	local nom_p = base.animacy == "inan" and "e" or default_masc_animate_nom_pl(base, stems)
	-- nouns with loc_p in -ech (e.g. [[cíl]] "goal") need to give this manually, using <locplech>
	add_decl(base, stems, "e", dat_s, nil, voc_s, loc_s, "em",
		nom_p, "ů", "ům", "e", "ích", "i")
end

declprops["soft-m"] = {
	cat = "soft"
}


decls["mixed-m"] = function(base, stems)
	-- NOTE: IJP tends to list the soft endings first, but per their section on this
	-- (https://prirucka.ujc.cas.cz/en/?id=220), the hard endings tend to predominate in modern use, so we list them
	-- first.
	if base.animacy == "an" then
		if rfind(base.lemma, "l$") then
			-- [[anděl]] "angel", [[manžel]] "husband", [[strašpytel]] "coward"; 'strašpytel' has a different declension
			-- from the other two, with more soft forms. [[manžel]] has plural in -é or -ové and needs an override.
			local dat_s = base.surname and "ovi" or {"ovi", "u"}
			local loc_s = dat_s
			add_decl(base, stems, "a", dat_s, nil, "i", loc_s, "em",
				"é", "ů", "ům", {"y", "e"}, {"ech", "ích"}, {"y", "i"})
		else
			-- -s/-z: rorýs, platýs, pilous, markýz, všekaz, stávkokaz, penězokaz, listokaz, dřevokaz, zrnokaz, boss.
			-- Others recently moving towards this declension: primas, karas, kalous, konipas, ibis, chabrus, chuďas,
			-- kakabus, kliďas, kandrdas, morous, vágus.
			-- Some names: Alois, Mánes.
			-- Both hard and soft endings throughout. Most have -i and -ové in the nominative plural.
			local dat_s = base.surname and "ovi" or {"u", "i", "ovi"}
			local loc_s = dat_s
			add_decl(base, stems, {"a", "e"}, dat_s, nil, {"e", "i"}, loc_s, "em",
				{"i", "ové"}, "ů", "ům", {"y", "e"}, {"ech", "ích"}, {"y", "i"})
		end
	else
		-- Given in IJP: burel, hnědel, chmel, krevel, kužel, námel, plevel, tmel, zádrhel, apríl, artikul, koukol, rubl,
		-- úběl, plus reducible nouns cumel, chrchel, [[kotel]] "cauldron", sopel, uhel. Also [[městys]]. Many of them are listed in the
		-- IJP tables with only hard or with fewer soft forms, so need to be investigated individually.
		if rfind(base.lemma, "[ls]$") then
			add_decl(base, stems, {"u", "e"}, {"u", "i"}, nil, {"e", "i"}, {"u", "e", "i"}, "em",
				{"y", "e"}, "ů", "ům", {"y", "e"}, {"ech", "ích"}, {"y", "i"})
		else
			-- -n/-t; hard in the plural: hřeben, ječmen, [[kámen]] "stone", kmen, kořen, křemen, plamen,
			-- [[pramen]] "source", [[řemen]] "strap", den, týden, [[loket]] "elbow".
			-- There may be deviations (e.g. soft plural forms for [[den]]), so need to be investigated individually.
			add_decl(base, stems, {"u", "e"}, {"u", "i"}, nil, "i", {"u", "i"}, "em",
				"y", "ů", "ům", "y", "ech", "y")
		end
	end
end

declprops["mixed-m"] = {
	cat = "mixed"
}


decls["a-m"] = function(base, stems)
	-- husita → husité, izraelita → izraelité, jezuita → jezuité, kosmopolita → kosmopolité, táborita → táborité
	-- fašista → fašisté, filatelista → filatelisté, fotbalista → fotbalisté, kapitalista → kapitalisté,
	-- marxista → marxisté, šachista → šachisté, terorista → teroristé. NOTE: most these words actually appear in
	-- the IJP tables with -é/-i, so we go accordingly.
	--
	-- gymnasta → gymnasté, fantasta → fantasté; also chiliasta, orgiasta, scholiasta, entuziasta, dynasta, ochlasta,
	-- sarkasta, vymasta; NOTE: Only 'gymnasta' actually given with just -é; 'fantasta' with -ové/-é, 'dynasta' and
	-- 'ochlasta' with just -ové, vymasta not in IJP (no plural given in SSJC), and the rest with -é/-i. So we go
	-- accordingly.
	local it_ist = rfind(stems.vowel_stem, "is?t$") or rfind(stems.vowel_stem, "ast$")
	-- Velar nouns (e.g. [[sluha]] "servant") have -ích in the loc_p (which triggers the second palatalization)
	-- instead of -ech. Nouns whose stem ends in a soft consonant ([[rikša]], [[paša]], [[bača]], [[mahárádža]],
	-- [[paňáca]], etc.) behave likewise.
	-- FIXME: [[pária]] "pariah", [[Maria]] etc.
	local loc_p =
		(base.velar or not base["-velar"] and rfind(stems.vowel_stem, com.velar_c .. "$") or rfind(stems.vowel_stem, com.inherently_soft_c .. "$")) and
		"ích" or "ech"
	add_decl(base, stems, "y", "ovi", "u", "o", "ovi", "ou",
		it_ist and {"é", "i"} or "ové", "ů", "ům", "y", loc_p, "y")
end

declprops["a-m"] = {
	cat = "GENPOS in -a"
}


decls["e-m"] = function(base, stems)
	-- [[zachránce]] "savior"; [[soudce]] "judge"; etc.
	-- At least two inanimates: [[průvodce]] "guide, guidebook; computing wizard"; [[správce]] "manager (software program), configuration program"
	local dat_s = base.animacy == "inan" and "i" or base.surname and "ovi" or {"ovi", "i"}
	local loc_s = dat_s
	add_decl(base, stems, "e", dat_s, nil, "-", loc_s, "em",
		-- nouns with -ové as well (e.g. [[soudce]] "judge") will need to specify that manually, e.g. <nompli:ové>
		base.animacy == "inan" and "e" or "i", "ů", "ům", "e", "ích", "i")
end

declprops["e-m"] = {
	cat = "GENPOS in -e"
}


decls["i-m"] = function(base, stems)
	-- [[kivi]] "kiwi (bird)"; [[kuli]] "coolie"; [[lori]] "lory, lorikeet (bird)" (loc_pl 'loriech/loriích/lorich');
	-- [[vini]] "parrot of the genus Vini"; [[yetti]]/[[yeti]] "yeti". other examples: [[aguti]], [[efendi]], [[hadži]],
	-- [[pekari]], [[regenschori]], [[yetti]]/[[yeti]].
	--
	-- [[grizzly]]/[[grizly]] "grizzly bear"; [[pony]] "pony"; [[husky]] "husky"; [[dandy]] "dandy"; [[Billy]] "billy".
	--
	-- NOTE: Some nouns in -y are regular soft stems, e.g. [[gay]] "gay person"; [[gray]] "gray (unit of absorbed
	--   radiation)"; [[Nagy]] (surname).
	--
	-- NOTE: The stem ends in -i/-y.
	add_decl(base, stems, "ho", "mu", nil, "-", "m", "m",
		-- ins_pl 'kivii/kivimi'
		{"ové", ""}, {"ů", "ch"}, {"ům", "m"}, {"e", ""}, {"ích", "ch"}, {"i", "mi"})
end

declprops["i-m"] = {
	cat = "GENPOS in -i/-y"
}


decls["ie-m"] = function(base, stems)
	-- [[zombie]] "zombie" (also fem/neut), [[hippie]] "hippie", [[yuppie]] "yuppie", [[rowdie]] "rowdy/hooligan"
	--
	-- NOTE: The stem ends in -i (not -ie, because of the plural).
	add_decl(base, stems, "eho", "emu", nil, "-", "em", "em",
		{"ové", "es"}, {"ů", "es"}, {"ům", "es"}, {"e", "es"}, {"ích", "es"}, {"i", "es"})
end

declprops["ie-m"] = {
	cat = "GENPOS in -ie"
}


decls["ee-m"] = function(base, stems)
	-- [[Yankee]] "Yankee"
	--
	-- NOTE: The stem ends in -ee.
	add_decl(base, stems, "ho", "mu", nil, "-", "m", "m",
		"ové", "ů", "ům", "e", "ích", "i")
end

declprops["ee-m"] = {
	cat = "GENPOS in -ee"
}


decls["o-m"] = function(base, stems)
	-- [[kápo]] "head, leader"; [[lamželezo]] "strongman"; [[torero]] "bullfighter"; [[žako]] "African gray parrot";
	-- [[dingo]] "dingo"; [[kakapo]] "kakapo" (given in Wiktionary with dat_s/loc_s in -ovi only not -ovi/-u; probably
	-- wrong but not in IJP); [[maestro]] "maestro"; [[Bruno]] "Bruno", [[Hugo]] "Hugo"; [[Ivo]] "Yves" (these names
	-- are singular-only per IJP); [[Kvido]] "Guido, Guy" (per IJP has accusative in -a or -ona); [[Oto]] "Otto" (per
	-- IJP also declinable like virile -a masculines; singular-only); [[Kuřátko]] (a surname; how declined?);
	-- [[Picasso]] (surname; how declined?); [[Pluto]] "Pluto (God)", also "Pluto (planet)", which is inanimate;
	-- [[Samo]]/[[Sámo]] "Samo (7th century Slavic ruler)" (dat_s/loc_s only in -ovi, needs override); [[Tomio]]
	-- "Tomio (Japanese male given name)" (how declined?); [[nemakačenko]] "idler, loafer" (given in Wiktionary with
	-- dat_s/loc_s in -ovi only, as for [[kakapo]]); [[nefachčenko]] "idler, loafer"; note also [[gadžo]] "gadjo",
	-- which has a unique declension.
	--
	-- Velar nouns ([[žako]], [[dingo]], etc.) have -ích in the loc_p (which triggers the second palatalization)
	-- instead of -ech.
	local velar = base.velar or not base["-velar"] and rfind(stems.vowel_stem, com.velar_c .. "$")
	-- inanimates e.g. [[Pluto]] (planet) have -u only, like for normal hard masculines.
	local dat_s = base.animacy == "inan" and "u" or base.surname and "ovi"or {"ovi", "u"}
	local loc_s = dat_s
	local loc_p = velar and "ích" or "ech"
	add_decl(base, stems, "a", dat_s, nil, "-", loc_s, "em",
		"ové", "ů", "ům", "y", loc_p, "y")
end

declprops["o-m"] = {
	cat = "GENPOS in -o"
}


decls["u-m"] = function(base, stems)
	-- [[emu]] "emu", [[guru]] "guru", [[kakadu]] "cockatoo", [[marabu]] "marabou" (declined the same way)
	-- [[Osamu]] "Osamu (Japanese male given name)" [how declined?]
	-- [[Višnu]] "Vishnu" (declined like [[guru]] but singular-only)
	-- [[budižkničemu]] "good-for-nothing, ne'er-do-well" (indeclinable in the singular, declinable as masculine hard stem
	-- budižkničemové etc. in the plural, declinable as feminine hard stem budižkničemy etc. in the plural when feminine).
	--
	-- NOTE: The stem ends in -u.
	add_decl(base, stems, "a", "ovi", nil, "-", "ovi", "em",
		"ové", "ů", "ům", "y", "ech", "y")
end

declprops["u-m"] = {
	cat = "GENPOS in -u"
}


decls["tstem-m"] = function(base, stems)
	-- E.g. [[kníže]] "prince", [[hrabě]] "earl", [[markrabě]] "margrave".
	add_decl(base, stems, "ete", "eti", "ete", "-", "eti", "etem",
		"ata", "at", "atům", "ata", "atech", "aty")
end

declprops["tstem-m"] = {
	cat = "t-stem"
}


decls["hard-f"] = function(base, stems)
	base.no_palatalize_c = true
	if base.c_as_k then
		-- forms like 'ayahuascy' are allowed.
		base.hard_c = true
	end
	-- [[skica]] "sketch", [[gejša]] "geisha", [[rikša]] "rickshaw (vehicle)"; [[arakača]], [[čača]], [[čiča]] (drink),
	-- [[dača]] "dacha", [[gutaperča]] "guttapercha", [[viskača]]; [[babča]], [[číča]], [[káča]], [[mamča]], [[úča]].
	-- Also appears to apply to ď (e.g. [[Naďa]]) and ť, as well as certain words with stems in -ň and -j (e.g. [[doňa]],
	-- and personal names such as [[Táňa]] and [[Darja]]), which normally have a mixed declension.
	local soft_cons = rfind(base.vowel_stem, "[cčšžďťjň]$") and not base.c_as_k
	local dat_s = soft_cons and {"ě", "i"} or "ě"
	local loc_s = dat_s
	add_decl(base, stems, "y", dat_s, "u", "o", loc_s, "ou",
		"y", "", "ám", "y", "ách", "ami")
end

declprops["hard-f"] = {
	cat = "hard"
}


decls["soft-f"] = function(base, stems)
	-- This also includes feminines in -ie, e.g. [[belarie]], [[signorie]], [[uncie]], and feminines in -oe, e.g.
	-- [[kánoe]], [[aloe]] and medical terms like [[dyspnoe]], [[apnoe]], [[hemoptoe]], [[kalanchoe]].

	-- Nouns in -ice like [[ulice]] "street" have null genitive plural e.g. 'ulic'; nouns in -yně e.g. [[přítelkyně]]
	-- "girlfriend" have gen pl 'přítelkyň' or 'přítelkyní' with two possible endings; otherwise -í. (Alternation between
	-- -ň and -n and between -e and -ě handled automatically by combine_stem_ending().)
	local gen_p = rfind(base.lemma, "ice$") and "" or rfind(base.lemma, "yně$") and {"", "í"} or "í"
	-- Vocative really ends in -e, not just a copy of the nominative; cf. [[sinfonia]], which is soft-f except for
	-- the nominative and has -e in the vocative singular.
	add_decl(base, stems, "e", "i", "i", "e", "i", "í",
		"e", gen_p, "ím", "e", "ích", "emi")
end

declprops["soft-f"] = {
	cat = "soft"
}


decls["mixed-f"] = function(base, stems)
	-- Lowercase nouns in -ňa (e.g. bárišňa/báryšňa, doňa, dueňa, piraňa, vikuňa) and -ja (e.g. maracuja, papája, sója).
	-- Also non-personal proper nouns in -ňa (e.g. [[Keňa]] "Kenya") and -ja (e.g. [[Troja]]/[[Trója]] "Troy",
	-- [[Amudarja]] "Amu Darya"). Does not appear to apply to personal proper nouns (e.g. [[Táňa]] "Tanya", [[Darja]] "Daria"),
	-- which usually decline like [[gejša]], [[dača]], [[skica]]).
	add_decl(base, stems, {"i", "e"}, {"e", "i"}, "u", "o", {"e", "i"}, "ou",
			{"i", "e"}, {"", "í"}, {"ám", "ím"}, {"i", "e"}, {"ách", "ích"}, {"ami", "emi"})
end

declprops["mixed-f"] = {
	cat = "mixed"
}


decls["cons-f"] = function(base, stems)
	-- e.g. [[dlaň]] "palm (of the hand)"
	add_decl(base, stems, "e", "i", "-", "i", "i", "í",
		"e", "í", "ím", "e", "ích", "emi")
end

declprops["cons-f"] = {
	cat = "soft zero-ending"
}


decls["istem-f"] = function(base, stems)
	add_decl(base, stems, "i", "i", "-", "i", "i", "í",
		-- See above under apply_special_cases(); -E causes depalatalization of ť/ď/ň.
		"i", "í", "Em", "i", "Ech", "mi")
end

declprops["istem-f"] = {
	cat = "i-stem"
}


decls["mixed-istem-f"] = function(base, stems)
	local gen_s, nom_p, dat_p, loc_p, ins_p
	-- Use of ě vs E below is intentional. Contrast [[oběť]] dat pl 'obětem' (depalatalizing) with [[nit]] ins pl
	-- 'nitěmi' (palatalizing). See comment above under apply_special_cases().
	if base.mixedistem == "pěst" then
		-- pěst, past, mast, lest [reducible; ins pl 'lstmi'], pelest, propust, plst, oběť, zeď [reducible; ins pl
		-- 'zdmi'], paměť [ins pl 'pamětmi/paměťmi]
		gen_s, nom_p, dat_p, loc_p, ins_p = "i", "i", {"ím", "Em"}, {"ích", "Ech"}, "mi"
	elseif base.mixedistem == "moc" then
		-- moc, nemoc, pomoc, velmoc; NOTE: pravomoc has -i/-e alternation in gen_s, nom_p
		gen_s, nom_p, dat_p, loc_p, ins_p = "i", "i", {"Em", "ím"}, {"Ech", "ích"}, "ěmi"
	elseif base.mixedistem == "myš" then
		-- myš, veš [reducible, ins pl vešmi], hruď, měď, pleť, spleť, směs, smrt, step, odpověď [ins pl 'odpověď'mi/odpovědmi'], šeď,
		-- závěť [ins pl 'závěťmi/závětmi'], plsť [ins pl 'plstmi']
		gen_s, nom_p, dat_p, loc_p, ins_p = "i", "i", "ím", "ích", "mi"
	elseif base.mixedistem == "noc" then
		-- lež [reducible], noc, mosaz, rez [reducible], ves [reducible], mysl, sůl, běl, žluť
		gen_s, nom_p, dat_p, loc_p, ins_p = "i", "i", "ím", "ích", "ěmi"
	elseif base.mixedistem == "žluč" then
		-- žluč, moč, modř, čeleď, kapraď, záď, žerď, čtvrť/čtvrt, drť, huť, chuť, nit, pečeť, závrať, pouť, stať, ocel
		gen_s, nom_p, dat_p, loc_p, ins_p = {"i", "ě"}, {"i", "ě"}, "ím", "ích", "ěmi"
	elseif base.mixedistem == "loď" then
		-- loď, suť
		gen_s, nom_p, dat_p, loc_p, ins_p = {"i", "ě"}, {"i", "ě"}, "ím", "ích", {"ěmi", "mi"}
	else
		error(("Unrecognized value '%s' for 'mixedistem', should be one of 'pěst', 'moc', 'myš', 'noc', 'žluč' or 'loď'"):
			format(base.mixedistem))
	end
	add_decl(base, stems, gen_s, "i", "-", "i", "i", "í",
		nom_p, "í", dat_p, nom_p, loc_p, ins_p)
end

declprops["mixed-istem-f"] = {
	-- Include subtype in the table description but not in the category to avoid too many categories.
	desc = function(base, stems)
		return ("mixed i-stem [type '%s'] GENDER"):format(base.mixedistem)
	end,
	cat = function(base, stems)
		return {"mixed i-stem", ("mixed i-stem GENPOS (type '%s')"):format(base.mixedistem)}
	end,
}


decls["i-f"] = function(base, stems)
	-- [[máti]] "mother" (singular-only), [[pramáti]] "foremother"; very similar to the 'noc' mixed i-stem type
	add_decl(base, stems, "i", "i", "-", "i", "i", "í",
		"i", "í", "ím", "i", "ích", "ěmi")
end

declprops["i-f"] = {
	cat = "GENPOS in -i"
}


decls["ea-f"] = function(base, stems)
	-- Stem ends in -e.
	if base.tech then
		-- diarea, gonorea, chorea, nauzea, paleogea, seborea, trachea
		add_decl(base, stems, "y", "i", "u", "o", "i", "ou",
			"y", "í", {"ám", "ím"}, "y", {"ách", "ích"}, "ami")
	elseif base.persname then
		-- Medea, Andrea, etc.
		add_decl(base, stems, {"y", "je", "ji"}, {"e", "je", "ji"}, "u", "o", {"e", "je", "ji"}, "ou",
			-- this is a guess, based on the same as below; plural of personal names not attested in IJP
			{"y", "je"}, "jí", {"ám", "jím"}, {"y", "je"}, {"ách", "jích"}, {"ami", "jemi"})
	else
		-- idea, odysea ("wandering pilgrimage"), orchidea, palea, spirea
		-- proper names Galilea, Judea, Caesarea, Korea, Odyssea ("epic poem")
		add_decl(base, stems, {"y", "je"}, "ji", "u", "o", "ji", {"ou", "jí"},
			{"y", "je"}, "jí", {"ám", "jím"}, {"y", "je"}, {"ách", "jích"}, {"ami", "jemi"})
	end
end

declprops["ea-f"] = {
	cat = function(base, stems)
		if base.tech then
			return {"GENPOS in -ea", "technical GENPOS in -ea"}
		else
			return "GENPOS in -ea"
		end
	end
}


decls["oa-f"] = function(base, stems)
	-- Stem ends in -o/-u.
	-- stoa, kongrua; proper names Samoa, Managua, Nikaragua, Capua
	add_decl(base, stems, "y", "i", "u", "o", "i", "ou",
		"y", "í", "ám", "y", "ách", "ami")
end

declprops["oa-f"] = {
	cat = "GENPOS in -oa/-ua"
}


decls["ia-f"] = function(base, stems)
	-- Stem ends in -i.
	-- belaria, signoria, uncia; paranoia, sinfonia;
	-- proper names Alexandria, Alexia, Livia, Monrovia, Olympia, Sofia
	-- Identical to soft declension except for nom sg.
	decls["soft-f"](base, stems)
end

declprops["ia-f"] = {
	cat = "GENPOS in -ia"
}


decls["hard-n"] = function(base, stems)
	local velar = base.velar or not base["-velar"] and rfind(stems.vowel_stem, com.velar_c .. "$")
	-- NOTE: Per IJP it appears the meaning of the preceding preposition makes a difference: 'o' = "about" takes
	-- '-u' or '-ě', while 'na/v' = "in, on" normally takes '-ě'.
	local loc_s =
		-- Exceptions: [[mléko]] "milk" ('mléku' or 'mléce'), [[břicho]] "belly" ('břiše' or (less often) 'břichu'),
		-- [[roucho]] ('na rouchu' or 'v rouše'; why the difference in preposition?).
		velar and "u" or
		-- IJP says nouns in -dlo take only -e but the declension tables show otherwise. It appears -u is possible
		-- but significantly less common. Other nouns in -lo usually take just -e ([[čelo]] "forehead",
		-- [[kolo]] "wheel", [[křeslo]] "armchair", [[máslo]] "butter", [[peklo]] "hell", [[sklo]] "glass",
		-- [[světlo]] "light", [[tělo]] "body"; but [[číslo]] "number' with -e/-u; [[zlo]] "evil" and [[kouzlo]] "spell"
		-- with -u/-e).
		rfind(base.lemma, "dlo$") and {"ě", "u"} or
		rfind(base.lemma, "lo$") and "ě" or
		(rfind(base.lemma, "[sc]tvo$") or rfind(base.lemma, "ivo$")) and "u" or
		-- Per IJP: Borrowed words and abstracts take -u (e.g. [[banjo]]/[[bendžo]]/[[benžo]] "banjo", [[depo]] "depot",
		-- [[chladno]] "cold", [[mokro]] "damp, dampness", [[právo]] "law, right", [[šeru]] "twilight?",
		-- [[temno]] "dark, darkness", [[tempo]] "rate, tempo", [[ticho]] "quiet, silence", [[vedro]] "heat") and others
		-- often take -ě/-u. Formerly we defaulted to -ě/-u but it seems better to default to just -u, similarly to hard
		-- masculines.
		-- {"ě", "u"}
		"u"
	local loc_p =
		-- Note, lemmas in -isko also have mixed-reducible as default, handled in determine_default_reducible().
		-- Note also, ending -ích triggers the second palatalization.
		rfind(base.lemma, "isko$") and {"ích", "ách"} or
		-- Diminutives in -ko, -čko, -tko; also [[lýtko]], [[děcko]], [[vrátka]], [[dvířka]], [[jho]], [[roucho]],
		-- [[tango]], [[mango]], [[sucho]], [[blaho]], [[víko]], [[echo]], [[embargo]], [[largo]], [[jericho]] (from
		-- IJP). Also foreign nouns in -kum: [[antibiotikum]], [[narkotikum]], [[afrodiziakum]], [[analgetikum]], etc.
		-- [[jablko]] "apple" has '-ách' or '-ích' and needs an override; likewise for [[vojsko]] "troop"; [[riziko]]
		-- "risk" normally has '-ích' and needs and override.
		velar and "ách" or
		"ech"
	add_decl(base, stems, "a", "u", "-", "-", loc_s, "em",
		"a", "", "ům", "a", loc_p, "y")
	-- FIXME: paired body parts e.g. [[rameno]] "shoulder" (gen_p/loc_p 'ramenou/ramen'), [[koleno]] "knee"
	-- (gen_p/loc_p 'kolenou/kolen'), [[prsa]] "chest, breasts" (plurale tantum; gen_p/loc_p 'prsou').
	-- FIXME: Nouns with both neuter and feminine forms in the plural, e.g. [[lýtko]] "calf (of the leg)",
	-- [[bedro]] "hip", [[vrátka]] "gate".
end

declprops["hard-n"] = {
	desc = function(base, stems)
		if base.velar or not base["-velar"] and rfind(stems.vowel_stem, com.velar_c .. "$") then
			return "velar GENDER"
		else
			return "hard GENDER"
		end
	end,
	cat = function(base, stems)
		if base.velar or not base["-velar"] and rfind(stems.vowel_stem, com.velar_c .. "$") then
			return "velar-stem"
		else
			return "hard"
		end
	end
}


decls["semisoft-n"] = function(base, stems)
	-- Examples:
	-- * In -ao: [[kakao]] "cacao", [[makao]] "Macao (gambling card game, see Wikipedia)", [[curaçao]] "curaçao (liqueur)"
	--   (IJP gives gen pl 'curaç' but ASSC [https://slovnikcestiny.cz/heslo/cura%C3%A7ao/0/9967] says 'curaçí' as expected),
	--   [[farao]] "faro (card game)"; also [[Makao]], [[Pathet Lao]], but these are sg-only
	-- * In -eo: [[stereo]], [[rodeo]], [[video]], [[solideo]]; also [[Borneo]], [[Montevideo]], but these are sg-only
	-- * In -io: [[rádio]] "radio", [[gramorádio]], [[studio]], [[scenário]], [[trio]], [[ážio]] (also spelled [[agio]]),
	--   [[disážio]], [[folio]], [[vibrio]]; also [[arpeggio]], [[adagio]], [[capriccio]], [[solfeggio]] although
	--   pronounced the Italian way without /i/; also [[Ohio]], [[Ontario]], [[Tokio]], but these are sg-only
	-- * In -uo: only [[duo]]
	-- * In -yo: only [[embryo]]
	-- * In -eum: [[muzeum]], [[lyceum]], [[linoleum]], [[ileum]], etc.
	-- * In -ium: [[atrium]] "atrium", most chemical elements, etc.
	-- * In -uum: [[individuum]], [[kontinuum]], [[premenstruum]], [[residuum]], [[vakuum]]/[[vacuum]]
	-- * In -yum: only [[baryum]] "barium" (none others in SSJC)
	-- * In -ion: [[enkómion]] "encomium", [[eufonion]] (variant of [[eufonium]]), [[amnion]], [[ganglion]], [[gymnasion]],
	--   [[scholion]], [[kritérion]] (rare for [[kritérium]]), [[onomatopoion]] (variant of [[onomatopoie]]),
	--   [[symposion]], [[synedrion]]; also [[Byzantion]], but this is sg-only; most words in -ion are masculine
	-- Hard in the singular, mostly soft in the plural. Those in -eo and -uo have alternative hard endings in the
	-- dat/loc/ins pl, but not those in -eum or -uum. Those in -ao have only hard endings except in the gen pl. (There are
	-- apparently no neuters in -eon; those in -eon or -yon e.g. [[akordeon]], [[neon]], [[nukleon]], [[karyon]], [[Lyon]]
	-- are masculine.)
	local dat_p, loc_p, ins_p
	if rfind(base.actual_lemma, "ao$") then
		dat_p, loc_p, ins_p = "ům", "ech", "y"
	elseif rfind(base.actual_lemma, "[eu]o$") then
		dat_p, loc_p, ins_p = {"ím", "ům"}, {"ích", "ech"}, {"i", "y"}
	else
		dat_p, loc_p, ins_p = "ím", "ích", "i"
	end
	add_decl(base, stems, "a", "u", "-", "-", "u", "em",
		"a", "í", dat_p, "a", loc_p, ins_p)
end

declprops["semisoft-n"] = {
	cat = "semisoft"
}


decls["soft-n"] = function(base, stems)
	-- Examples: [[moře]] "sea", [[slunce]] "sun", [[srdce]] "heart", [[citoslovce]] "interjection", 
	-- [[dopoledne]] "late morning", [[odpoledne]] "afternoon", [[hoře]] "sorrow, grief" (archaic or literary),
	-- [[inhalace]] "inhalation", [[kafe]] "coffee", [[kanape]] "sofa", [[kutě]] "bed", [[Labe]] "Elbe (singular only)",
	-- [[líce]] "cheek", [[lože]] "bed", [[nebe]] "sky; heaven", [[ovoce]] "fruit", [[pole]] "field", [[poledne]]
	-- "noon", [[příslovce]] "adverb", [[pukrle]] "curtsey" (also t-n), [[vejce]] "egg" (NOTE: gen pl 'vajec').
	--
	-- Many nouns in -iště, with null genitive plural.
	local gen_p = rfind(base.vowel_stem, "išť$") and "" or "í"
	add_decl(base, stems, "e", "i", "-", "-", "i", "em",
		"e", gen_p, "ím", "e", "ích", "i")
	-- NOTE: Some neuter words in -e indeclinable, e.g. [[Belize]], [[Chile]], [[garde]] "chaperone", [[karaoke]],
	-- [[karate]], [[re]] "double raise (card games)", [[ukulele]], [[Zimbabwe]], [[zombie]] (pl. 'zombie' or
	-- 'zombies')
	-- some nearly indeclinable, e.g. [[finále]], [[chucpe]]; see mostly-indecl below
end

declprops["soft-n"] = {
	cat = "soft"
}


decls["í-n"] = function(base, stems)
	-- [[nábřeží]] "waterfront" and a zillion others; also [[úterý]] "Tuesday".
	-- NOTE: The stem ends in -í/-ý.
	add_decl(base, stems, "", "", "-", "-", "", "m",
		"", "", "m", "", "ch", "mi")
end

declprops["í-n"] = {
	cat = "GENPOS in -í/-ý"
}


decls["n-n"] = function(base, stems)
	-- E.g. [[břemeno]] "burden" (also [[břímě]], use 'decllemma:'); [[písmeno]] "letter"; [[plemeno]] "breed";
	-- [[rameno]] "shoulder" (also [[rámě]], use 'decllemma:'); [[semeno]] "seed" (also [[sémě]], [[símě]], use
	-- 'decllemma:'); [[temeno]] "crown (of the head)"; [[vemeno]] "udder"
	add_decl(base, stems, {"a", "e"}, {"i", "u"}, "-", "-", {"ě", "i", "u"}, "em",
		"a", "", "ům", "a", "ech", "y")
end

declprops["n-n"] = {
	cat = "n-stem"
}


decls["tstem-n"] = function(base, stems)
	-- E.g. [[batole]] "toddler", [[čuně]] "pig", [[daňče]] "fallow deer fawn", [[děvče]] "girl", [[ďouče]] "girl"
	-- (dialectal), [[dítě]] "child" (NOTE: feminine in the plural [[děti]], declined as a feminine i-stem), [[dvojče]]
	-- "twin", [[hádě]] "young snake", [[house]] "gosling", [[hříbě]] "foal" (pl. hříbata), [[jehně]] "lamb", [[kavče]]
	-- "young jackdaw; chough", [[káče]] "duckling", [[káně]] "buzzard chick" (NOTE: also feminine meaning "buzzard"),
	-- [[klíště]] "tick", [[kose]] "blackbird chick" (rare), [[kuře]] "chick (young chicken)", [[kůzle]]
	-- "kid (young goat)", [[lišče]] "fox cub", [[lvíče]] "lion cub", [[medvídě]] "bear cub", [[mládě]] "baby animal",
	-- [[morče]] "guinea pig", [[mrně]] "toddler", [[nemluvně]] "infant", [[novorozeně]] "newborn", [[orle]] "eaglet",
	-- [[osle]] "donkey foal", [[pachole]] "boy (obsolete); page, squire", [[páže]] "page, squire", [[podsvinče]]
	-- "suckling pig", [[prase]] "pig", [[prtě]] "toddler", [[ptáče]] "chick (young bird)",
	-- [[robě]] "baby, small child", [[saranče]] "locust" (NOTE: also feminine), [[sele]] "piglet",
	-- [[slůně]] "baby elephant", [[škvrně]] "toddler", [[štěně]] "puppy", [[tele]] "calf", [[velbloudě]] "camel colt",
	-- [[vlče]] "wolf cub", [[vnouče]] "grandchild", [[vyžle]] "small hunting dog; slender person",
	-- [[zvíře]] "animal, beast".
	--
	-- Some referring to inanimates, e.g. [[doupě]] "lair" (pl. doupata), [[koště]]/[[chvoště]] "broom", [[paraple]]
	-- "umbrella", [[poupě]] "bud", [[pukrle]] "curtsey" (also soft-n), [[rajče]] "tomato", [[šuple]] "drawer",
	-- [[varle]] "testicle", [[vole]] "craw (of a bird); goiter".
	add_decl(base, stems, "ete", "eti", "-", "-", "eti", "etem",
		"ata", "at", "atům", "ata", "atech", "aty")
end

declprops["tstem-n"] = {
	cat = "t-stem"
}


decls["ma-n"] = function(base, stems)
	-- E.g. [[drama]] "drama", [[dogma]] "dogma", [[aneurysma]]/[[aneuryzma]] "aneurysm", [[dilema]] "dilemma",
	-- [[gumma]] "gumma" (non-cancerous syphilitic growth), [[klima]] "climate", [[kóma]] "coma", [[lemma]] "lemma",
	-- [[melisma]] "melisma", [[paradigma]] "paradigm", [[plasma]]/[[plazma]] "plasma [partly ionized gas]"
	-- (note [[plasma]]/[[plazma]] "blood plasma" is feminine), [[revma]] "rheumatism", [[schéma]] "schema, diagram",
	-- [[schisma]]/[[schizma]] "schism", [[smegma]] "smegma", [[sofisma]]/[[sofizma]] "sophism", [[sperma]] "sperm",
	-- [[stigma]] "stigma", [[téma]] "theme", [[trauma]] "trauma", [[trilema]] "trilemma", [[zeugma]] "zeugma".
	add_decl(base, stems, "atu", "atu", "-", "-", "atu", "atem",
		"ata", "at", "atům", "ata", "atech", "aty")
end

declprops["ma-n"] = {
	cat = "ma-stem"
}


decls["adj"] = function(base, stems)
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

declprops["adj"] = {
	cat = function(base, stems)
		return {"adjectival POS", get_stemtype(base) .. " GENDER adjectival POS"}
	end,
}


decls["mostly-indecl"] = function(base, stems)
	-- Several neuters: E.g. [[finále]] "final (sports)", [[čtvrtfinále]] "quarterfinal", [[chucpe]] "chutzpah",
	-- [[penále]] "fine, penalty", [[promile]] "" (NOTE: loc pl also promilech), [[rande]] "rendezvous", [[semifinále]]
	-- "semifinal", [[skóre]] "score".
	-- At least one masculine animate: [[kamikaze]]/[[kamikadze]], where IJP says only -m in the ins sg.
	local ins_s = base.gender == "m" and "m" or {"-", "m"}
	add_decl(base, stems, "-", "-", "-", "-", "-", ins_s,
		"-", "-", "-", "-", "-", "-")
end

declprops["mostly-indecl"] = {
	cat = "mostly indeclinable"
}


decls["indecl"] = function(base, stems)
	-- Indeclinable. Note that fully indeclinable nouns should not have a table at all rather than one all of whose forms
	-- are the same; but having an indeclinable declension is useful for nouns that may or may not be indeclinable, e.g.
	-- [[desatero]] "group of ten" or the plural of [[peso]], which may be indeclinable 'pesos'.
	add_decl(base, stems, "-", "-", "-", "-", "-", "-",
		"-", "-", "-", "-", "-", "-")
end

declprops["indecl"] = {
	cat = function(base, stems)
		if base.adj then
			return {"adjectival POS", "indeclinable adjectival POS", "indeclinable GENDER adjectival POS"}
		else
			return {"indeclinable POS", "indeclinable GENPOS"}
		end
	end
}


decls["manual"] = function(base, stems)
	-- Anything declined manually using overrides. We don't set any declensions except the nom_s (or nom_p if plurale
	-- tantum).
	add(base, base.number == "pl" and "nom_p" or "nom_s", stems, "-")
end

declprops["manual"] = {
	desc = "GENDER",
	cat = {},
}


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

	local gender, number, animacy, has_clitic = pron_props()
	base.gender = gender
	base.actual_gender = gender
	base.number = number
	base.actual_number = number
	base.animacy = animacy
	base.actual_animacy = animacy
	base.has_clitic = has_clitic
end


local function determine_pronoun_stems(base)
	if base.stem_sets then
		error("Reducible and vowel alternation specs cannot be given with pronouns")
	end
	base.stem_sets = {{reducible = false, vowel_stem = "", nonvowel_stem = ""}}
	base.decl = "pron"
end


decls["pron"] = function(base, stems)
	local after_prep_footnote =	"[after a preposition]"
	local animate_footnote = "[animate]"
	if base.lemma == "kdo" then
		add_decl(base, stems, "koho", "komu", nil, nil, "kom", "kým")
	elseif base.lemma == "co" then
		add_decl(base, stems, "čeho", "čemu", nil, nil, "čem", "čím")
	elseif base.lemma == "já" then
		add_sg_decl_with_clitic(base, stems, "mne", "mě", "mně", "mi", nil, nil, nil, "mně", "mnou")
	elseif base.lemma == "ty" then
		add_sg_decl_with_clitic(base, stems, "tebe", "tě", "tobě", "ti", nil, nil, nil, "tobě", "tebou")
	elseif base.lemma == "my" then
		add_pl_only_decl(base, stems, "nás", "nám", "nás", "nás", "námi")
	elseif base.lemma == "vy" then
		add_pl_only_decl(base, stems, "vás", "vám", "vás", "vás", "vámi")
	elseif base.lemma == "on" or base.lemma == "ono" then
		local acc_s = base.lemma == "on" and "jej" or {"jej", "je"}
		local clitic_acc_s = base.lemma == "on" and {"jej", "ho"} or {"jej", "ho", "je"}
		local prep_acc_s = base.lemma == "on" and "něj" or {"něj", "ně"}
		local prep_clitic_acc_s = base.lemma == "on" and "-ň" or nil
		add_sg_decl_with_clitic(base, stems, {"jeho", "jej"}, {"ho", "jej"}, "jemu", "mu", acc_s, clitic_acc_s, nil, nil, "jím")
		add_sg_decl_with_clitic(base, stems, {"něho", "něj"}, nil, "němu", nil, prep_acc_s, prep_clitic_acc_s, nil, "něm", "ním",
			after_prep_footnote)
		if base.lemma == "on" then
		add_sg_decl_with_clitic(base, stems, nil, nil, nil, nil, "jeho", nil, nil, nil, nil,
			animate_footnote)
		add_sg_decl_with_clitic(base, stems, nil, nil, nil, nil, "něho", nil, nil, nil, nil,
			after_prep_footnote and animate_footnote)
		end
	elseif base.lemma == "ona" and base.number == "sg" then
		add_sg_decl(base, stems, "jí", "jí", "ji", nil, nil, "jí")
		add_sg_decl(base, stems, "ní", "ní", "ni", nil, "ní", "ní", after_prep_footnote)
	elseif base.lemma == "oni" or base.lemma == "ony" or base.lemma == "ona" then
		add_pl_only_decl(base, stems, "jich", "jim", "je", nil, "jimi")
		add_pl_only_decl(base, stems, "nich", "nim", "ně", "nich", "nimi", after_prep_footnote)
	elseif base.lemma == "sebe" then
		-- Underlyingly we handle [[sebe]]'s slots as singular.
		add_sg_decl_with_clitic(base, stems, "sebe", "sebe", "sobě", "si", "sebe", "se", nil, "sobě", "sebou",
			nil, "no nom_s")
	else
		error(("Internal error: Unrecognized pronoun lemma '%s'"):format(base.lemma))
	end
end

declprops["pron"] = {
	desc = "GENDER pronoun",
	cat = {},
}


local function set_num_defaults(base)
	if base.gender or base.number or base.animacy then
		error("Can't specify gender, number or animacy for numeral")
	end

	local function num_props()
		-- Return values are GENDER, NUMBER, ANIMACY, HAS_CLITIC.
		return "none", "pl", "none", false
	end

	local gender, number, animacy, has_clitic = num_props()
	base.gender = gender
	base.actual_gender = gender
	base.number = number
	base.actual_number = number
	base.animacy = animacy
	base.actual_animacy = animacy
	base.has_clitic = has_clitic
end


local function determine_numeral_stems(base)
	if base.stem_sets then
		error("Reducible and vowel alternation specs cannot be given with numerals")
	end
	local stem = rmatch(base.lemma, "^(.*)" .. com.vowel_c .. "$") or base.lemma
	base.stem_sets = {{reducible = false, vowel_stem = stem, nonvowel_stem = stem}}
	base.decl = "num"
end


decls["num"] = function(base, stems)
	local after_prep_footnote =	"[after a preposition]"
	if base.lemma == "dva" or base.lemma == "dvě" then
		-- in compound numbers; stem is dv-
		add_pl_only_decl(base, stems, "ou", "ěma", "-", "ou", "ěma")
	elseif base.lemma == "tři" or base.lemma == "čtyři" then
		-- stem is without -i
		local is_three = base.lemma == "tři"
		add_pl_only_decl(base, stems, is_three and "í" or "", "em", "-", "ech", is_three and "emi" or "mi")
		add_pl_only_decl(base, stems, "ech", nil, nil, nil, nil, "[colloquial]")
		add_pl_only_decl(base, stems, nil, nil, nil, nil, is_three and "ema" or "ma",
			"[when modifying a form ending in ''-ma'']")
	elseif base.lemma == "devět" then
		add_pl_only_decl(base, "", "devíti", "devíti", "-", "devíti", "devíti", stems.footnotes)
	elseif base.lemma == "sta" or base.lemma == "stě" or base.lemma == "set" then
		add_pl_only_decl(base, "", "set", "stům", "-", "stech", "sty", stems.footnotes)
	elseif rfind(base.lemma, "[is]et$") then
		-- [[deset]] and all numbers ending in -cet ([[dvacet]], [[třicet]], [[čtyřicet]] and inverted compound
		-- numerals such as [[pětadvacet]] "25" and [[dvaatřicet]] "32")
		local begin = rmatch(base.lemma, "^(.*)et$")
		add_pl_only_decl(base, stems, "i", "i", "-", "i", "i")
		add_pl_only_decl(base, begin, "íti", "íti", "-", "íti", "íti", stems.footnotes)
	elseif rfind(base.lemma, "oje$") then
		-- [[dvoje]], [[troje]]
		-- stem is without -e
		add_pl_only_decl(base, stems, "ích", "ím", "-", "ích", "ími")
	elseif rfind(base.lemma, "ery$") then
		-- [[čtvery]], [[patery]], [[šestery]], [[sedmery]], [[osmery]], [[devatery]], [[desatery]]
		-- stem is without -y
		add_pl_only_decl(base, stems, "ých", "ým", "-", "ých", "ými")
	else
		add_pl_only_decl(base, stems, "i", "i", "-", "i", "i")
	end
end

declprops["num"] = {
	desc = "GENDER numeral",
	cat = {},
}


local function set_det_defaults(base)
	if base.gender or base.number or base.animacy then
		error("Can't specify gender, number or animacy for determiner")
	end

	local function det_props()
		-- Return values are GENDER, NUMBER, ANIMACY, HAS_CLITIC.
		return "none", "none", "none", false
	end

	local gender, number, animacy, has_clitic = det_props()
	base.gender = gender
	base.actual_gender = gender
	base.number = number
	base.actual_number = number
	base.animacy = animacy
	base.actual_animacy = animacy
	base.has_clitic = has_clitic
end


local function determine_determiner_stems(base)
	if base.stem_sets then
		error("Reducible and vowel alternation specs cannot be given with determiners")
	end
	local stem = rmatch(base.lemma, "^(.*)" .. com.vowel_c .. "$") or base.lemma
	base.stem_sets = {{reducible = false, vowel_stem = stem, nonvowel_stem = stem}}
	base.decl = "det"
end


decls["det"] = function(base, stems)
	add_sg_decl(base, stems, "a", "a", "-", nil, "a", "a")
end

declprops["det"] = {
	desc = "GENDER determiner",
	cat = {},
}


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


--[=[
Parse a single override spec (e.g. 'nomplé:ové' or 'ins:autodráhou:autodrahou[rare]') and return
two values: the slot(s) the override applies to, and an object describing the override spec.
The input is actually a list where the footnotes have been separated out; for example,
given the spec 'inspl:čobotami:čobotámi[rare]:čobitmi[archaic]', the input will be a list
{"inspl:čobotami:čobotámi", "[rare]", ":čobitmi", "[archaic]", ""}. The object returned
for 'ins:autodráhou:autodrahou[rare]' looks like this:

{
  full = true,
  values = {
	{
	  form = "autodráhou"
	},
	{
	  form = "autodrahou",
	  footnotes = {"[rare]"}
	}
  }
}

The object returned for 'nomplé:ové' looks like this:

{
  values = {
	{
	  form = "é",
	},
	{
	  form = "ové",
	}
  }
}
]=]
local function parse_override(segments)
	local retval = {values = {}}
	local part = segments[1]
	local slots = {}
	while true do
		local case = usub(part, 1, 3)
		if cases[case] then
			-- ok
		else
			error(("Unrecognized case '%s' in override: '%s'"):format(case, table.concat(segments)))
		end
		part = usub(part, 4)
		local slot
		if rfind(part, "^pl") then
			part = usub(part, 3)
			slot = case .. "_p"
		elseif rfind(part, "^cl") then
			-- No plural clitic cases at this point.
			part = usub(part, 3)
			if clitic_cases[case] then
				slot = "clitic_" .. case .. "_s"
			else
				error(("Unrecognized clitic case '%s' in override: '%s'"):format(case, table.concat(segments)))
			end
		else
			slot = case .. "_s"
		end
		table.insert(slots, slot)
		if rfind(part, "^%+") then
			part = usub(part, 2)
		else
			break
		end
	end
	if rfind(part, "^:") then
		retval.full = true
		part = usub(part, 2)
	end
	segments[1] = part
	local colon_separated_groups = iut.split_alternating_runs_and_strip_spaces(segments, ":")
	for i, colon_separated_group in ipairs(colon_separated_groups) do
		local value = {}
		local form = colon_separated_group[1]
		if form == "" then
			error(("Use - to indicate an empty ending for slot%s '%s': '%s'"):format(#slots > 1 and "s" or "", table.concat(slots), table.concat(segments)))
		elseif form == "-" then
			value.form = ""
		else
			value.form = form
		end
		value.footnotes = fetch_footnotes(colon_separated_group)
		table.insert(retval.values, value)
	end
	return slots, retval
end


--[=[
Parse an indicator spec (text consisting of angle brackets and zero or more
dot-separated indicators within them). Return value is an object of the form

{
  overrides = {
	SLOT = {OVERRIDE, OVERRIDE, ...}, -- as returned by parse_override()
	...
  },
  forms = {}, -- forms for a single spec alternant; see `forms` below
  footnotes = {"FOOTNOTE", "FOOTNOTE", ...}, -- may be missing
  stems = { -- may be missing
	{
	  reducible = TRUE_OR_FALSE,
	  footnotes = {"FOOTNOTE", "FOOTNOTE", ...}, -- may be missing
	  -- The following fields are filled in by determine_stems()
	  vowel_stem = "STEM",
	  nonvowel_stem = "STEM",
	  oblique_slots = one of {nil, "gen_p", "all", "all-oblique"},
	  oblique_vowel_stem = "STEM" or nil (only needs to be set if oblique_slots is non-nil),
	  oblique_nonvowel_stem = "STEM" or nil (only needs to be set if oblique_slots is non-nil),
	},
	...
  },
  gender = "GENDER", -- "m", "f", "n"
  number = "NUMBER", -- "sg", "pl"; may be missing
  animacy = "ANIMACY", -- "inan", "an"; may be missing
  hard = true, -- may be missing
  soft = true, -- may be missing
  mixed = true, -- may be missing
  surname = true, -- may be missing
  istem = true, -- may be missing
  ["-istem"] = true, -- may be missing
  tstem = true, -- may be missing
  nstem = true, -- may be missing
  tech = true, -- may be missing
  foreign = true, -- may be missing
  mostlyindecl = true, -- may be missing
  indecl = true, -- may be missing
  manual = true, -- may be missing
  adj = true, -- may be missing
  decllemma = "DECLENSION-LEMMA", -- may be missing
  declgender = "DECLENSION-GENDER", -- may be missing
  declnumber = "DECLENSION-NUMBER", -- may be missing

  -- The following additional fields are added by other functions:
  orig_lemma = "ORIGINAL-LEMMA", -- as given by the user
  orig_lemma_no_links = "ORIGINAL-LEMMA-NO-LINKS", -- links removed
  lemma = "LEMMA", -- `orig_lemma_no_links`, converted to singular form if plural and lowercase if all-uppercase
  forms = {
	SLOT = {
	  {
		form = "FORM",
		footnotes = {"FOOTNOTE", "FOOTNOTE", ...} -- may be missing
	  },
	  ...
	},
	...
  },
  decl = "DECL", -- declension, e.g. "hard-m"
  vowel_stem = "VOWEL-STEM", -- derived from vowel-ending lemmas
  nonvowel_stem = "NONVOWEL-STEM", -- derived from non-vowel-ending lemmas
}
]=]
local function parse_indicator_spec(angle_bracket_spec)
	local inside = rmatch(angle_bracket_spec, "^<(.*)>$")
	assert(inside)
	local base = {overrides = {}, forms = {}}
	if inside ~= "" then
		local segments = iut.parse_balanced_segment_run(inside, "[", "]")
		local dot_separated_groups = iut.split_alternating_runs_and_strip_spaces(segments, "%.")
		for i, dot_separated_group in ipairs(dot_separated_groups) do
			local part = dot_separated_group[1]
			local case_prefix = usub(part, 1, 3)
			if cases[case_prefix] then
				local slots, override = parse_override(dot_separated_group)
				for _, slot in ipairs(slots) do
					if base.overrides[slot] then
						error(("Two overrides specified for slot '%s'"):format(slot))
					else
						base.overrides[slot] = {override}
					end
				end
			elseif part == "" then
				if #dot_separated_group == 1 then
					error("Blank indicator: '" .. inside .. "'")
				end
				base.footnotes = fetch_footnotes(dot_separated_group)
			elseif rfind(part, "^[-*#ě]*$") or rfind(part, "^[-*#ě]*,") then
				if base.stem_sets then
					error("Can't specify reducible/vowel-alternant indicator twice: '" .. inside .. "'")
				end
				local comma_separated_groups = iut.split_alternating_runs_and_strip_spaces(dot_separated_group, ",")
				local stem_sets = {}
				for i, comma_separated_group in ipairs(comma_separated_groups) do
					local pattern = comma_separated_group[1]
					local orig_pattern = pattern
					local reducible, vowelalt, oblique_slots
					if pattern == "-" then
						-- default reducible, no vowel alt
					else
						local before, after
						before, reducible, after = rmatch(pattern, "^(.-)(%-?%*)(.-)$")
						if before then
							pattern = before .. after
							reducible = reducible == "*"
						end
						if pattern ~= "" then
							if not rfind(pattern, "^##?ě?$") then
								error("Unrecognized vowel-alternation pattern '" .. pattern .. "', should be one of #, ##, #ě or ##ě: '" .. inside .. "'")
							end
							if pattern == "#ě" or pattern == "##ě" then
								vowelalt = "quant-ě"
							else
								vowelalt = "quant"
							end
							-- `oblique_slots` will be later changed to "all" if the lemma ends in a consonant.
							if pattern == "##" or pattern == "##ě" then
								oblique_slots = "all-oblique"
							else
								oblique_slots = "gen_p"
							end
						end
					end
					table.insert(stem_sets, {
						reducible = reducible,
						vowelalt = vowelalt,
						oblique_slots = oblique_slots,
						footnotes = fetch_footnotes(comma_separated_group)
					})
				end
				base.stem_sets = stem_sets
			elseif #dot_separated_group > 1 then
				error("Footnotes only allowed with slot overrides, reducible or vowel alternation specs or by themselves: '" .. table.concat(dot_separated_group) .. "'")
			elseif part == "m" or part == "f" or part == "n" then
				if base.gender then
					error("Can't specify gender twice: '" .. inside .. "'")
				end
				base.gender = part
			elseif part == "sg" or part == "pl" then
				if base.number then
					error("Can't specify number twice: '" .. inside .. "'")
				end
				base.number = part
			elseif part == "an" or part == "inan" then
				if base.animacy then
					error("Can't specify animacy twice: '" .. inside .. "'")
				end
				base.animacy = part
			elseif part == "hard" or part == "soft" or part == "mixed" or part == "surname" or part == "istem" or
				part == "-istem" or part == "tstem" or part == "nstem" or part == "tech" or part == "foreign" or
				part == "mostlyindecl" or part == "indecl" or part == "pron" or part == "det" or part == "num" or
				-- Use 'velar' with words like [[petanque]] and [[Braque]] that end with a pronounced velar (and hence are declined
				-- like velars) but not with a spelled velar; use '-velar' with words like [[hadíth]] that end with a spelled but
				-- silent velar.
				part == "collapse_ee" or part == "persname" or part == "c_as_k" or part == "velar" or part == "-velar" then
				if base[part] then
					error("Can't specify '" .. part .. "' twice: '" .. inside .. "'")
				end
				base[part] = true
				-- Allow 'hard' to signal that -y is allowed after -c, as in hard masculine nouns such as [[hec]]
				-- "joke", and also feminines in -ca where the c is pronounced as /k/, e.g. [[ayahuasca]], [[pororoca]],
				-- [[Petrarca]], [[Mallorca]], [[Casablanca]]. (Contrast [[mangalica]], [[Kusturica]], [[Bjelica]],
				-- where the c is pronounced as /ts/ and -y is disallowed.)
				if part == "hard" then
					base.hard_c = true
				end
			elseif part == "+" then
				if base.adj then
					error("Can't specify '+' twice: '" .. inside .. "'")
				end
				base.adj = true
			elseif part == "!" then
				if base.manual then
					error("Can't specify '!' twice: '" .. inside .. "'")
				end
				base.manual = true
			elseif rfind(part, "^mixedistem:") then
				if base.mixedistem then
					error("Can't specify 'mixedistem:' twice: '" .. inside .. "'")
				end
				base.mixedistem = rsub(part, "^mixedistem:", "")
			elseif rfind(part, "^decllemma:") then
				if base.decllemma then
					error("Can't specify 'decllemma:' twice: '" .. inside .. "'")
				end
				base.decllemma = rsub(part, "^decllemma:", "")
			elseif rfind(part, "^declgender:") then
				if base.declgender then
					error("Can't specify 'declgender:' twice: '" .. inside .. "'")
				end
				base.declgender = rsub(part, "^declgender:", "")
			elseif rfind(part, "^declnumber:") then
				if base.declnumber then
					error("Can't specify 'declnumber:' twice: '" .. inside .. "'")
				end
				base.declnumber = rsub(part, "^declnumber:", "")
			else
				error("Unrecognized indicator '" .. part .. "': '" .. inside .. "'")
			end
		end
	end
	return base
end


local function is_regular_noun(base)
	return not base.adj and not base.pron and not base.det and not base.num
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
			if base.manual then
				base.gender = "none"
			else
				error("For nouns, gender must be specified")
			end
		end
		base.number = base.number or "both"
		process_declnumber(base)
		base.animacy = base.animacy or "inan"
		base.actual_gender = base.gender
		base.actual_animacy = base.animacy
		if base.declgender then
			if base.declgender == "m-an" then
				base.gender = "m"
				base.animacy = "an"
			elseif base.declgender == "m-in" then
				base.gender = "m"
				base.animacy = "inan"
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
		alternant_multiword_spec.has_clitic = alternant_multiword_spec.has_clitic or base.has_clitic
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


local function undo_second_palatalization(base, word, is_adjective)
	local function try(from, to)
		local stem = rmatch(word, "^(.*)" .. from .. "$")
		if stem then
			return stem .. to
		end
		return nil
	end
	return is_adjective and try("št", "sk") or
		is_adjective and try("čt", "ck") or
		try("c", "k") or -- FIXME, this could be wrong and c correct
		try("ř", "r") or
		try("z", "h") or -- FIXME, this could be wrong and z or g correct
		try("š", "ch") or
		word
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
				if stems.reducible == nil then
					if rfind(lemma, com.cons_c .. "[ck]$") and not com.is_monosyllabic(base.lemma) then
						stems.reducible = true
					end
					if stems.reducible then
						lemma = dereduce(base, lemma)
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
        -- Now set the stem sets if not given.
	if not base.stem_sets then
		base.stem_sets = {{reducible = false}}
	end
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
	local stem, contracted
	-- Determine declension
	if base.gender == "m" then
		stem = rmatch(base.lemma, "^(.*)ir$")
		if stem then
			-- [[maur]] "ant", [[aur]] "loam, mud", [[gaur]] "ruffian", [[paur]] "devil; enmity",
			-- [[saur]] "dirt; excrement", [[staur]] "post", [[ljósastaur]] "lamp post"
			base.decl = "strong-m-ir"
		end
		if not stem then
			stem = rmatch(base.lemma, "^(.*aur)$")
			if stem then
				-- [[maur]] "ant", [[aur]] "loam, mud", [[gaur]] "ruffian", [[paur]] "devil; enmity",
				-- [[saur]] "dirt; excrement", [[staur]] "post", [[ljósastaur]] "lamp post"
				base.decl = "strong-m"
			end
		end
		-- FIXME
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


-- Determine the default value for the 'reducible' flag.
local function determine_default_reducible(base)
	-- Nouns in vowels other than -a/o as well as masculine nouns ending in all vowels don't have null endings so not
	-- reducible. Note, we are never called on adjectival nouns.
	if rfind(base.lemma, "[iyuíeě]$") or base.gender == "m" and rfind(base.lemma, "[ao]$") or base.tstem then
		base.default_reducible = false
		return
	end

	local stem
	stem = rmatch(base.lemma, "^(.*" .. com.cons_c .. ")$")
	if stem then
		-- When analyzing existing manual declensions in -ec and -ek, 290 were reducible vs. 23 non-reducible. Of these
		-- 23, 15 were monosyllabic (and none of the 290 reducible nouns were monosyllabic) -- and two of these were
		-- actually reducible but irregularly: [[švec]] "shoemaker" (gen sg 'ševce') and [[žnec]] "reaper (person)"
		-- (gen sg. 'žence'). Of the remaining 8 multisyllabic non-reducible words, two were actually reducible but
		-- irregularly: [[stařec]] "old man" (gen sg 'starce') and [[tkadlec]] "weaver" (gen sg 'tkalce'). The remaining
		-- six consisted of 5 compounds of monosyllabic words: [[dotek]], [[oblek]], [[kramflek]], [[pucflek]],
		-- [[pokec]], plus [[česnek]], which should be reducible but would lead to an impossible consonant cluster.
		if base.gender == "m" and rfind(stem, "[eě][ck]$") and not com.is_monosyllabic(stem) then
			base.default_reducible = true
		elseif base.gender == "f" and rfind(stem, "[eě]ň$") then
			-- [[pochodeň]] "torch", [[píseň]] "leather", [[žeň]] "harvest"; not [[reveň]] "rhubarb" or [[dřeň]] "pulp",
			-- which need an override.
			base.default_reducible = true
		else
			base.default_reducible = false
		end
		return
	end
	if base.number == "sg" then
		base.default_reducible = false
		return
	end
	if rfind(base.lemma, "isko$") then
		-- e.g. [[středisko]]
		base.default_reducible = "mixed"
		return
	end
	stem = rmatch(base.lemma, "^(.*)" .. com.vowel_c .. "$")
	if not stem then
		error(("Internal error: Something wrong, lemma '%s' doesn't end in consonant or vowel"):format(base.lemma))
	end
	-- Substitute 'ch' with a single character to make the following code simpler.
	stem = stem:gsub("ch", com.TEMP_CH)
	if rfind(stem, com.cons_c .. "[lr]" .. com.cons_c .. "$") then
		-- [[vrba]], [[vlha]]; not reducible. (But note [[jablko]], reducible; needs override.)
		base.default_reducible = false
	elseif not base.foreign and (rfind(stem, com.cons_c .. "[bkhlrmnv]$") or base.c_as_k and rfind(stem, com.cons_c .. "c$")) then
		-- [[ayahuasca]] has gen pl 'ayahuasek'
		base.default_reducible = true
	elseif base.foreign and rfind(stem, com.cons_c .. "r$") then
		-- Foreign nouns in -CCum seem generally non-reducible in the gen pl except for those in -Crum like [[centrum]],
		-- Examples: [[album]], [[verbum]], [[signum]], [[interregnum]], [[sternum]]. [[infernum]] has gen pl 'infern/inferen'.
		base.default_reducible = true
	else
		base.default_reducible = false
	end
end


-- Determine the stems to use for each stem set: vowel and nonvowel stems, for singular
-- and plural. We assume that one of base.vowel_stem or base.nonvowel_stem has been
-- set in determine_declension(), depending on whether the lemma ends in
-- a vowel. We construct all the rest given the reducibility, vowel alternation spec and
-- any explicit stems given. We store the determined stems inside of the stem-set objects
-- in `base.stem_sets`, meaning that if the user gave multiple reducible or vowel-alternation
-- patterns, we will compute multiple sets of stems. The reason is that the stems may vary
-- depending on the reducibility and vowel alternation.
local function determine_stems(base)
	if not base.stem_sets then
		base.stem_sets = {{}}
	end
	-- Set default reducible and check for default mixed reducible, which needs to be expanded into two entries.
	local default_mixed_reducible = false
	for _, stems in ipairs(base.stem_sets) do
		if stems.reducible == nil then
			stems.reducible = base.default_reducible
		end
		if stems.reducible == "mixed" then
			default_mixed_reducible = true
		end
	end
	if default_mixed_reducible then
		local new_stem_sets = {}
		for _, stems in ipairs(base.stem_sets) do
			if stems.reducible == "mixed" then
				local non_reducible_copy = m_table.shallowcopy(stems)
				non_reducible_copy.reducible = false
				stems.reducible = true
				table.insert(new_stem_sets, stems)
				table.insert(new_stem_sets, non_reducible_copy)
			else
				table.insert(new_stem_sets, stems)
			end
		end
		base.stem_sets = new_stem_sets
	end

	-- Now determine all the stems for each stem set.
	for _, stems in ipairs(base.stem_sets) do
		local lemma_is_vowel_stem = not not base.vowel_stem
		if base.vowel_stem then
			stems.vowel_stem = base.vowel_stem
			stems.nonvowel_stem = stems.vowel_stem
			-- Apply vowel alternation first in cases like jádro -> jader; apply_vowel_alternation() will throw an error
			-- if the vowel being modified isn't the last vowel in the stem.
			stems.oblique_nonvowel_stem = com.apply_vowel_alternation(stems.vowelalt, stems.nonvowel_stem)
			if stems.reducible then
				stems.nonvowel_stem = dereduce(base, stems.nonvowel_stem)
				stems.oblique_nonvowel_stem = dereduce(base, stems.oblique_nonvowel_stem)
			end
		else
			stems.nonvowel_stem = base.nonvowel_stem
			-- The user specified #, #ě, ## or ##ě and we're dealing with a term like masculine [[bůh]] or feminine
			-- [[sůl]] that ends in a consonant. In this case, all slots except the nom_s and maybe acc_s have vowel
			-- alternation.
			if stems.oblique_slots then
				stems.oblique_slots = "all"
			end
			stems.oblique_nonvowel_stem = com.apply_vowel_alternation(stems.vowelalt, stems.nonvowel_stem)
			if stems.reducible then
				stems.vowel_stem = com.reduce(base.nonvowel_stem)
				if not stems.vowel_stem then
					error("Unable to reduce stem '" .. base.nonvowel_stem .. "'")
				end
			else
				stems.vowel_stem = base.nonvowel_stem
			end
		end
		stems.oblique_vowel_stem = com.apply_vowel_alternation(stems.vowelalt, stems.vowel_stem)
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
	elseif base.manual then
		if base.stem_sets then
			-- FIXME, maybe this should be allowed?
			error("Reducible and vowel alternation specs cannot be given with manual declensions")
		end
		base.stem_sets = {{reducible = false, vowel_stem = "", nonvowel_stem = ""}}
		base.decl = "manual"
	else
		if base.number == "pl" then
			synthesize_singular_lemma(base)
		end
		determine_declension(base)
		determine_default_reducible(base)
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
		decls[base.decl](base, stems)
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
	local reducible = nil
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
				cats = cats(base, stems)
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
				desc = desc(base, stems)
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
			if reducible == nil then
				reducible = stems.reducible
			elseif reducible ~= stems.reducible then
				reducible = "mixed"
			end
			if stems.reducible then
				insert("nouns with reducible stem")
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
	if reducible == "mixed" then
		table.insert(annparts, "mixed-reducible")
	elseif reducible then
		table.insert(annparts, "reducible")
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
! style="width:33%;background:#d9ebff" |
! style="background:#d9ebff" | singular
! style="background:#d9ebff" | plural
|-
!style="background:#eff7ff"|nominative
| {nom_s}
| {nom_p}
|-
!style="background:#eff7ff"|genitive
| {gen_s}
| {gen_p}
|-
!style="background:#eff7ff"|dative
| {dat_s}
| {dat_p}
|-
!style="background:#eff7ff"|accusative
| {acc_s}
| {acc_p}
|-
!style="background:#eff7ff"|vocative
| {voc_s}
| {voc_p}
|-
!style="background:#eff7ff"|locative
| {loc_s}
| {loc_p}
|-
!style="background:#eff7ff"|instrumental
| {ins_s}
| {ins_p}
]=] .. template_postlude()

	local function get_table_spec_one_number(number, numcode)
		local table_spec_one_number = [=[
! style="width:33%;background:#d9ebff" |
! style="background:#d9ebff" | NUMBER
|-
!style="background:#eff7ff"|nominative
| {nom_CODE}
|-
!style="background:#eff7ff"|genitive
| {gen_CODE}
|-
!style="background:#eff7ff"|dative
| {dat_CODE}
|-
!style="background:#eff7ff"|accusative
| {acc_CODE}
|-
!style="background:#eff7ff"|vocative
| {voc_CODE}
|-
!style="background:#eff7ff"|locative
| {loc_CODE}
|-
!style="background:#eff7ff"|instrumental
| {ins_CODE}
]=]
		return template_prelude("30") .. table_spec_one_number:gsub("NUMBER", number):gsub("CODE", numcode) ..
			template_postlude()
	end

	local function get_table_spec_one_number_clitic(number, numcode)
		local table_spec_one_number_clitic = [=[
! rowspan=2 style="width:33%;background:#d9ebff"|
! colspan=2 style="background:#d9ebff" | NUMBER
|-
! style="width:33%;background:#d9ebff" | stressed
! style="background:#d9ebff" | clitic
|-
!style="background:#eff7ff"|nominative
| colspan=2 | {nom_CODE}
|-
!style="background:#eff7ff"|genitive
| {gen_CODE}
| {clitic_gen_CODE}
|-
!style="background:#eff7ff"|dative
| {dat_CODE}
| {clitic_dat_CODE}
|-
!style="background:#eff7ff"|accusative
| {acc_CODE}
| {clitic_acc_CODE}
|-
!style="background:#eff7ff"|vocative
| colspan=2 | {voc_CODE}
|-
!style="background:#eff7ff"|locative
| colspan=2 | {loc_CODE}
|-
!style="background:#eff7ff"|instrumental
| colspan=2 | {ins_CODE}
]=]
		return template_prelude("40") .. table_spec_one_number_clitic:gsub("NUMBER", number):gsub("CODE", numcode) ..
			template_postlude()
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
		alternant_multiword_spec.has_clitic and get_table_spec_one_number_clitic(number, numcode) or
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
