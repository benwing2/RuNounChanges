local export = {}


--[=[

Authorship: Ben Wing <benwing2>

]=]

--[=[

TERMINOLOGY:

-- "slot" = A particular combination of case/gender/number. Example slot names for adjectives are "str_gen_f" (strong
	 genitive feminine singular), "comp_wk_n" (comparative weak neuter singular, all cases) and "sup_str_nom_np"
	 (superlative strong nominative/accusative neuter plural). Each slot is filled with zero or more forms.

-- "form" = The declined Icelandic form representing the value of a given slot.

-- "lemma" = The dictionary form of a given Icelandic term. Generally taken from the strong nominative masculine
	 singular positive-degree, but may occasionally be from another form if the specified slot is missing.
]=]

local lang = require("Module:languages").getByCode("is")
local m_table = require("Module:table")
local m_links = require("Module:links")
local m_string_utilities = require("Module:string utilities")
local iut = require("Module:inflection utilities")
local m_para = require("Module:parameters")
local com = require("Module:User:Benwing2/is-common")
local parse_utilities_module = "Module:parse utilities"

local u = mw.ustring.char
local rsplit = mw.text.split
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rgmatch = mw.ustring.gmatch
local rsubn = mw.ustring.gsub
local ulen = mw.ustring.len
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
	require("Module:debug/track")("is-adjective/" .. track_id)
	return true
end


local function make_quoted_list(list)
	local quoted_list = {}
	for _, item in ipairs(list) do
		table.insert(quoted_list, "'" .. item .. "'")
	end
	return mw.text.listToText(quoted_list)
end


local function make_quoted_keys(dict)
	local quoted_list = {}
	for key, _ in pairs(dict) do
		table.insert(quoted_list, "'" .. key .. "'")
	end
	table.sort(quoted_list)
	return mw.text.listToText(quoted_list)
end


local function make_quoted_slot_list(slot_list)
	local quoted_list = {}
	for _, slot_accel in ipairs(slot_list) do
		local slot, accel = unpack(slot_accel)
		table.insert(quoted_list, "'" .. slot .. "'")
	end
	return mw.text.listToText(quoted_list)
end


local potential_lemma_slots = {
	"str_nom_m",
	"str_nom_mp", -- for plural-only numerals and such
	"wk_nom_m", -- for weak-only adjectives
	"comp_wk_nom_m", -- for adjectives existing only in comparative and superlative forms
	"sup_str_nom_m", -- for adjectives existing only in superlative forms
	"sup_wk_nom_m", -- for adjectives existing only in superlative weak forms (e.g. [[einasti]])
}

local compsup_degrees = {
	{"pos", "positive"},
	{"comp", "comparative"},
	{"sup", "superlative"},
}

-- Export some of these below for use by [[Module:is-noun]].

export.overridable_stems = {
	"stem",
	"vstem",
	-- "imutval", FIXME: do we need this?
}

export.overridable_stem_set = m_table.listToSet(export.overridable_stems)

export.control_specs = {
	"umut",
	"con",
	"j",
	"v",
	"pp",
	"ppdent",
}

export.control_spec_set = m_table.listToSet(export.control_specs)

local function slot_to_degfield(slot)
	local degfield = slot:match("^(comp)_")
	if not degfield then
		degfield = slot:match("^(sup)_")
	end
	return degfield or "pos"
end


local function degfield_to_slot_prefix(degfield)
	if degfield == "pos" then
		return ""
	else
		return degfield .. "_"
	end
end

local strong_adjective_slots = {
	{"str_nom_m", "str|nom|m|s"},
	{"str_nom_f", "str|nom|f|s"},
	{"str_nom_n", "str|nom//acc|n|s"},
	{"str_acc_m", "str|acc|m|s"},
	{"str_acc_f", "str|acc|f|s"},
	{"str_dat_m", "str|dat|m|s"},
	{"str_dat_f", "str|dat|f|s"},
	{"str_dat_n", "str|dat|n|s"},
	{"str_gen_m", "str|gen|m|s"},
	{"str_gen_f", "str|gen|f|s"},
	{"str_gen_n", "str|gen|n|s"},
	{"str_nom_mp", "str|nom|m|p"},
	{"str_nom_fp", "str|nom//acc|f|p"},
	{"str_nom_np", "str|nom//acc|n|p"},
	{"str_acc_mp", "str|acc|m|p"},
	{"str_gen_p", "str|gen|p"},
	{"str_dat_p", "str|dat|p"},
}

local weak_adjective_slots = {
	{"wk_nom_m", "wk|nom|m|s"},
	{"wk_nom_f", "wk|nom|f|s"},
	{"wk_n", "wk|n|s"},
	{"wk_obl_m", "wk|acc//dat//gen|m|s"},
	{"wk_obl_f", "wk|acc//dat//gen|f|s"},
	{"wk_p", "wk|p"},
}

-- Abbreviations for use in addnote specs and overrides. Key is the abbreviation, value is a Lua pattern matching the
-- slots to select, or a list of such patterns. Patterns are anchored at both ends.
local adjective_slot_abbrs = {
	wk_m = "wk_.*m",
	wk_f = "wk_.*f",
	comp_wk_m = "comp_wk_.*m",
	comp_wk_f = "comp_.*f",
	sup_wk_m = "sup_wk_.*m",
	sup_wk_f = "sup_.*_f",
	str_s = "str_.*[mfn]",
	wk_s = "wk_.*[mfn]",
	str_p = "str_.*p",
	comp_wk_s = "comp_wk_.*[mfn]",
	sup_str_s = "sup_str_.*[mfn]",
	sup_wk_s = "sup_wk_.*[mfn]",
	sup_str_p = "sup_str_.*p",
	wk = "wk_.*",
	str = "str_.*",
	sup_wk = "sup_wk_.*",
	sup_str = "sup_str_.*",
}

local adjective_slot_set = {}
local adjective_slot_list = {}

local adjective_slot_list_by_degree = {}
local adjective_slot_list_linked_slots = {}

local function add_list_slots(degfield, slot_list)
	local prefix = degfield_to_slot_prefix(degfield)
	-- Initialize by-degree list, but don't overwrite.
	adjective_slot_list_by_degree[degfield] = adjective_slot_list_by_degree[degfield] or {}
	for _, slot_accel in ipairs(slot_list) do
		local slot, accel = unpack(slot_accel)
		local accel_suffix = ""
		if prefix == "comp_" then
			accel_suffix = "|comd"
		elseif prefix == "sup_" then
			accel_suffix = "|supd"
		end
		slot = prefix .. slot
		accel = accel .. accel_suffix
		slot_accel = {slot, accel}
		table.insert(adjective_slot_list, slot_accel)
		table.insert(adjective_slot_list_by_degree[degfield], slot_accel)
		adjective_slot_set[slot] = true
	end
end

local function add_slots(prefix, do_strong, do_weak)
	if do_strong then
		add_list_slots(prefix, strong_adjective_slots)
	end
	if do_weak then
		add_list_slots(prefix, weak_adjective_slots)
	end
end
add_slots("pos", true, true)
add_slots("comp", false, true) -- comparatives are weak-only
add_slots("sup", true, true)
for _, potential_lemma_slot in ipairs(potential_lemma_slots) do
	local slot_accel = {potential_lemma_slot .. "_linked", "-"}
	table.insert(adjective_slot_list, slot_accel)
	table.insert(adjective_slot_list_linked_slots, slot_accel)
end


local function skip_slot(number, state, slot)
	return number == "sg" and slot:find("p$") or
		number == "pl" and not slot:find("p$") or
		state == "strong" and slot:find("wk_") or
		state == "weak" and slot:find("str_")
end


--[=[
Create an empty `base` object for holding the result of parsing and later the generated forms. The object (including
fields later filled out by other functions) is of the form

{
  -- The original lemma as specified by the user in the declension spec, or taken from the pagename. May have
  -- double-bracket links in it.
  orig_lemma = "ORIGINAL_LEMMA",
  -- Same as `orig_lemma` but with double-bracket links removed and two-part links resolved to the right side.
  orig_lemma_no_links = "ORIGINAL_LEMMA_NO_LINKS",
  -- Per-degree structures (`pos` = positive, `comp` = comparative, `sup` = superlative). Each slot (`pos`, `comp` or
  -- `sup`) maps to a list of degree objects, one for each per-degree lemma. There will only be one positive degree
  -- object (different positive lemmas will be handled as alternants at a higher level), but there may be multiple
  -- comparative and/or superlative degree objects. (Conversely, there may be multiple property sets per positive-degree
  -- object, e.g. if the user specifies 'con,-con', but only one property set per comparative and superlative degree
  -- object.) Multiple degree objects generally happen because the user specifies multiple comparatives or superlatives
  -- (e.g. for [[fagur]], using the spec '#.comp:^ri:^!i.sup:^stur', which specifies comparative lemmas [[fegurri]] and
  -- [[fagri]] and superlative [[fegurstur]]), but occasionally the default superlative operation generates more than
  -- one superlative; e.g. for [[förull]] the spec is 'con,-con.comp:+:~~ari' which explicitly mentions two
  -- comparatives, and '+' itself generates two superlatives because of the 'con,-con' portion of the spec. There will
  -- always be a `pos` slot filled, but if the user didn't explicitly either specify that a comparative is present or
  -- specify no comparative using '-comp', there will be no `comp` slot (likewise for `sup`). If the user specified
  -- '-comp', there will be a `comp` slot mapping to an empty list.
  degrees = {
    pos = {
	  {
		-- The actual lemma, without any links. For the positive degree, same as `base.orig_lemma_no_links`. For the
		-- comparative and superlative degrees, as specified by the user or defaulted.
		actual_lemma = "ACTUAL_LEMMA",
		-- The lemma to use for declension. Will differ from `actual_lemma` if `decllemma:...` is given, in which case
		-- the value of `decllemma` will be here.
		lemma = "LEMMA",
		number = "NUMBER", -- "sg", "pl" or "both"; may be missing and if so is defaulted
		state = "STATE", -- "strong", "weak" or "bothstates"; may be missing and if so is defaulted
		-- computed stem; after parse_indicator_spec(), either nil or a user-specified stem override, which may have
		-- # (= lemma) or ## (= lemma minus -ur or -r) as the value; after determine_positive_declension(), filled in
		-- with the actual stem
		stem = "STEM",
		-- override the stem used before vowel-initial endings; after parse_indicator_spec(), either nil or a
		-- user-specified stem override in the same format as `stem`
		vstem = nil or "STEM",
		-- degree-level footnotes, specified using `LEMMA[footnote]`, where `LEMMA` is the comparative or superlative
		-- lemma, + for the default, or a shortened version using ~, ^ or the like
		footnotes = nil or {"FOOTNOTE", "FOOTNOTE", ...},
		-- CONTROL_GROUP is one of "umut", "con", "pp", "ppdent", "j" or "v", and CONTROL_SPEC is {form = "FORM",
		-- footnotes = nil or {"FOOTNOTE", "FOOTNOTE", ...}, defaulted = BOOLEAN}, where FORM is as specified by the
		-- user (e.g. "uUmut", "-pp") or set as a default by the code (in which case `defaulted` will be set to true for
		-- control group "umut"); the control groups are as follows:
		-- * umut (u-mutation);
		-- * con (stem contraction before vowel-initial endings);
		-- * j (j-infix before vowel-initial endings not beginning with an i);
		-- * v (v-infix before vowel-initial endings);
		-- * pp (past-participle-like inflection, with -ð in the nominative/accusative neuter singular instead of -t);
		-- * ppdent (dental infix in past participles before vowel-initial endings);
		CONTROL_GROUP = {
		  CONTROL_SPEC, CONTROL_SPEC, ...
		},
		prop_sets = {
		  PROPSET, -- see below
		  ...,
		},
	  },
	  ...
	},
	comp = { { ... }, { ... }, ... },
	sup = { { ... }, { ... }, ... },
  },
  -- forms for a single spec alternant
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
  -- SLOT is the actual name of the slot, such as "str_nom_n", and OVERRIDE is a list of form objects, where a
  -- form object is {form = FORM, footnotes = FOOTNOTES} as in the `forms` table ("-" means to suppress the slot
  -- entirely)
  overrides = {
	SLOT = OVERRIDE,
	SLOT = OVERRIDE,
	...
  },
  -- Used to track duplicate slot overrides.
  override_slots_seen = {
	SLOT = true,
	SLOT = true,
	...
  },
  -- Positive specs as given by the user, currently only if the user specifies '-pos'.
  posspec = nil or { {form = "-"} },
  -- Comparative specs as given by the user, consisting of a list of form objects.
  compspec = nil or { {form = "FORM", footnotes = nil or {"FOOTNOTE", "FOOTNOTE", ...}}, ...},
  -- Superlative specs as given by the user, consisting of a list of form objects.
  supspec = nil or { {form = "FORM", footnotes = nil or {"FOOTNOTE", "FOOTNOTE", ...}}, ...},
  -- misc Boolean properties:
  -- * "irreg" (an irregular term such as a number or determiner);
  -- * "decl?" (unknown declension);
  -- * "comp?" (unknown if comparative exists);
  -- * "indecl" (indeclinable);
  -- * "pred" (predicate-only);
  -- * "article" (requests the article variant of [[hinn]]);
  -- * "archaic" (requests the archaic variant of [[enginn]]);
  props = {
	PROP = true,
	PROP = true,
    ...
  },
  decllemma = nil or "DECLLEMMA", -- decline like the specified lemma
  -- alternant-level footnotes, specified using `.[footnote]`, i.e. a footnote by itself; apply to all degrees
  footnotes = nil or {"FOOTNOTE", "FOOTNOTE", ...},
  -- ADDNOTE_SPEC is {slot_specs = {"SPEC", "SPEC", ...}, footnotes = {"FOOTNOTE", "FOOTNOTE", ...}}; SPEC is a Lua
  -- pattern matching slots (anchored on both sides) and FOOTNOTE is a footnote to add to those slots
  addnote_specs = {
	ADDNOTE_SPEC, ADDNOTE_SPEC, ...
  },
}

There is one PROPSET (property set) for each combination of control specs; in the lower limit, there is a single
property set. There may be more than one property set e.g. if the user specified 'umut,uUmut' or '-j,j' or some
combination of these. The properties in a given property set specify the values themselves of each control group, as
well as stems (derived from the control specs) that are used to construct the various forms and populate the slots in
`forms` with these values. The information found in the property sets cannot be stored in `base` because it depends on a
particular combination of control specs, of which there may be more than one (see above). The decline_adjective()
function iterates over all property sets and calls the appropriate declension function on each one in turn, which adds
forms to each slot in `base.forms`, automatically deduplicating.

The properties in each property set are:
* Mutation specs: These are copied from the control specs at the degree object level. The key is one of the possible
  control groups ("umut", "con", etc.), but the value is a single form object {form = "FORM", footnotes = nil or
  {"FOOTNOTE", "FOOTNOTE", ...}}. These are set by expand_property_sets() for the positive degree, and by
  process_comp_sup_spec() or derive_sup_from_comp() for the comparative and superlative degrees.
* Stems (each stem is either a string or a form object; stems in general may be missing, i.e. nil, unless otherwise
  specified, and default to more general variants):
** `stem`: The basic stem. Always set. May be overridden by more specific variants.
** `nonvstem`: The stem used when the ending is null or starts with a consonant, unless overridden by a more
   specific variant. Defaults to `stem`. Not currently used, but could be if e.g. a user stem override `nonvstem:...`
   were supported.
** `umut_nonvstem`: The stem used when the ending is null or starts with a consonant and u-mutation is in effect,
   unless overridden by a more specific variant. Defaults to `nonvstem`. Will only be present when the result of
   u-mutation is different from the stem to which u-mutation is applied. (In this case, it will be present even if
   `nonvstem` is missing, because there is no generic `umut_stem`.)
** `vstem`: The stem used when the ending starts with a vowel, unless overridden by a more specific variant. Defaults
   to `stem`. Will be specified when contraction is in effect or the user specified `vstem:...`.
** `umut_vstem`: The stem(s) used when the ending starts with a vowel and u-mutation is in effect. Defaults to
   `vstem`. Note that u-mutation applies to the contracted stem if both u-mutation and contraction are in effect.
   Will only be present when the result of u-mutation is different from the stem to which u-mutation is applied.
   (In this case, it will be present even if `vstem` is missing, because there is no generic `umut_stem`.)
* Other properties:
** `jinfix`: If present, either "" or "j". Inserted between the stem and ending when the ending begins with a vowel
   other than "i". Note that j-infixes don't apply to ending overrides.
** `jinfix_footnotes`: Footnotes to attach to forms where j-infixing is possible (even if it's not present).
** `vinfix`: If present, either "" or "v". Inserted between the stem and ending when the ending begins with a vowel.
   Note that v-infixes don't apply to ending overrides. `jinfix` and `vinfix` cannot both be specified.
** `vinfix_footnotes`: Footnotes to attach to forms where v-infixing is possible (even if it's not present).
** `pp`: If present, either `true` or `false`. Indicates how to assimilate neuter ending -t to a previous final -ð
   after a vowel. If true, the result is -ð, as in past participles; otherwise, the result is -tt.
** `pp_footnotes`: Footnotes to attach to forms where `pp`-influenced assimilation happens.
}
]=]
local function create_base()
	return {
		forms = {},
		overrides = {},
		override_slots_seen = {},
		props = {},
		addnote_specs = {},
		degrees = {},
	}
end


-- Basic function to combine stem(s) and other properties with ending(s) and insert the result into the appropriate
-- slot. `base` is the object describing all the properties of the word being inflected for a single alternant (in case
-- there are multiple alternants specified using `((...))`). `slot` is the slot to add the form(s) to, without the
-- degree prefix ("", "comp_" or "sup_"). (The degree prefix is separated out because the code below sometimes needs to
-- conditionalize on the value of `slot` and should not have to worry about the degree variants.) `degree` is an object
-- describing the particular degree (positive, comparative or superlative) and associated base lemma. `props` is an
-- object containing computed stems and other information (such as what type of u-mutation is active). The information
-- found in `props` cannot be stored in `degree` because there may be more than one set of such properties per `degree`
-- (e.g. if the user specified 'umut,uUmut' or '-j,j' or some combination of these; in such a case, the caller will
-- iterate over all possible combinations, and ultimately invoke add() multiple times, one per combination). `endings`
-- is the ending or endings added to the appropriate stem (after any j or v infix) to get the form(s) to add to the
-- slot. Its value can be a single string, a list of strings, or a list of form objects (i.e. in general list form).
local function add(base, slot, degree, props, endings)
	if not endings then
		return
	end
	-- Call skip_slot() based on the declined number and state.
	if skip_slot(degree.number, degree.state, slot) then
		return
	end
	if type(endings) == "string" then
		endings = {endings}
	end
	local slot_prefix = degree.slot_prefix
	-- Loop over each ending.
	for _, endingobj in ipairs(endings) do
		local ending, ending_footnotes
		if type(endingobj) == "string" then
			ending = endingobj
		else
			ending = endingobj.form
			ending_footnotes = endingobj.footnotes
		end
		-- Ending of "-" means the user used - to indicate there should be no form here.
		if ending == "-" then
			return
		end
		local function interr(msg)
			error(("Internal error: For lemma '%s', slot '%s%s', ending '%s', %s: %s"):format(degree.lemma, slot_prefix,
				slot, ending, msg, dump(base)))
		end

		-- Compute whether i-mutation or u-mutation is in effect, and compute the "mutation footnotes", which are
		-- footnotes attached to a mutation-related indicator and which may need to be added even if no mutation is
		-- in effect (specifically when dealing with an ending that would trigger a mutation if in effect). AFAIK
		-- you cannot have both mutations in effect at once, and i-mutation overrides u-mutation if both would be in
		-- effect.

		-- Double ^^ at the beginning indicates that the u-mutated version should apply. (Single ^ would indicate that
		-- i-mutation should apply, but it doesn't seem relevant to adjectives.)
		local explicit_umut
		ending, explicit_umut = rsubb(ending, "^%^%^", "")
		local is_vowel_ending = rfind(ending, "^" .. com.vowel_c)
		local mut_in_effect, mut_not_in_effect, mut_footnotes
		local ending_in_i = not not ending:find("^i")
		local ending_in_u = not not ending:find("^u")
		if explicit_umut then
			mut_in_effect = "u"
		else
			if ending_in_u and not mut_in_effect then
				mut_in_effect = "u"
				-- umut and uUmut footnotes are incorporated into the appropriate umut_* stems
			end
		end

		local ending_was_asterisk = ending == "*"

		-- Now compute the appropriate stem to which the ending is added.
		local stem_in_effect

		-- Careful with the following logic; it is written carefully and should not be changed without a thorough
		-- understanding of its functioning.
		local has_umut = mut_in_effect == "u"
		-- If the stem is still unset, then use the vowel or non-vowel stem if available. When u-mutation is active, we
		-- first check for the u-mutated version of the vowel or non-vowel stem before falling back to the regular vowel
		-- or non-vowel stem. Note that an expression like `has_umut and props.umut_vstem or props.vstem` here is NOT
		-- equivalent to an if-else or ternary operator expression because if `has_umut` is true and `umut_vstem` is
		-- missing, it will still fall back to `vstem` (which is what we want).
		if not stem_in_effect then
			if is_vowel_ending then
				stem_in_effect = has_umut and props.umut_vstem or props.vstem
			else
				stem_in_effect = has_umut and props.umut_nonvstem or props.nonvstem
			end
		end
		-- Finally, fall back to the basic stem, which is always defined.
		stem_in_effect = stem_in_effect or props.stem

		-- If the ending is "*", it means to use the lemma as the form directly rather than try to construct the form
		-- from a stem and ending. We need to do this for the lemma slot and especially for the nominative singular,
		-- because we don't have the nominative singular ending available and it may vary (e.g. it may be -ur, -l, -n,
		-- etc. especially in the masculine). Not trying to construct the form from stem + ending also avoids
		-- complications from the nominative singular in -ur, which exceptionally does not trigger u-mutation.

		-- Finally, if there is a footnote associated with the computed stem in effect, we need to preserve it.
		if ending == "*" then
			local stem_in_effect_footnotes
			if type(stem_in_effect) == "table" then
				stem_in_effect_footnotes = stem_in_effect.footnotes
			end
			stem_in_effect = iut.combine_form_and_footnotes(degree.actual_lemma, stem_in_effect_footnotes)
			ending = ""
		end

		local infix, infix_footnotes
		-- Compute the infix (j, v or nothing) that goes between the stem and ending.
		if is_vowel_ending then
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

		-- If base-level footnotes or degree-level footnotes specified, they go before any stem footnotes, so we
		-- need to extract any footnotes from the stem in effect and insert the base-level footnotes before. In
		-- general, we want the footnotes to be in the order [base.footnotes, degree.footnotes, stem.footnotes,
		-- mut_footnotes, infix_footnotes, ending.footnotes].
		if base.footnotes or degree.footnotes then
			local stem_in_effect_footnotes
			if type(stem_in_effect) == "table" then
				stem_in_effect_footnotes = stem_in_effect.footnotes
				stem_in_effect = stem_in_effect.form
			end
			stem_in_effect = iut.combine_form_and_footnotes(stem_in_effect,
				iut.combine_footnotes(base.footnotes, iut.combine_footnotes(degree.footnotes,
					stem_in_effect_footnotes)))
		end

		local ending_is_full
		ending, ending_is_full = rsubb(ending, "^!", "")

		local function combine_stem_ending(stem, ending)
			if stem == "?" then
				return "?"
			end
			local stem_with_infix = ending_is_full and "" or stem .. (infix or "")
			-- An initial s- of the ending drops after a cluster of cons + s (including written <x>).
			if ending:find("^s") and (stem_with_infix:find("x$") or rfind(stem_with_infix, com.cons_c .. "s$")) then
				ending = ending:sub(2)
			elseif ending:find("^r") then
				if degree.assimilate_r then
					local stem_butlast, stem_last = stem_with_infix:match("^(.*)([ln])$")
					if stem_last then
						ending = stem_last .. ending:sub(2)
					end
				elseif degree.double_r_and_t then
					ending = "r" .. ending
				elseif rfind(stem_with_infix, com.cons_c .. "r$") then
					ending = ending:sub(2)
				end
			elseif ending == "t" then
				if degree.double_r_and_t then
					ending = "tt"
				elseif stem_with_infix:find("dd$") then
					stem_with_infix = stem_with_infix:gsub("dd$", "t")
				else
					local stem_butlast, stem_last = rmatch(stem_with_infix, "^(.*" .. com.cons_c .. ")([dðt])$")
					if stem_butlast then
						stem_with_infix = stem_butlast
					else
						stem_butlast = stem_with_infix:match("^(.*)ð$")
						if stem_butlast then
							if props.pp then
								stem_with_infix = stem_butlast
								ending = "ð"
							else
								stem_with_infix = stem_butlast .. "t"
							end
						elseif degree.inn then
							stem_butlast = stem_with_infix:match("^(.*)n$")
							if stem_butlast then
								stem_with_infix = stem_butlast
								ending = "ð"
							end
						end
					end
				end
			end
			return stem_with_infix .. ending
		end

		local combined_footnotes = iut.combine_footnotes(iut.combine_footnotes(mut_footnotes, infix_footnotes),
			ending_footnotes)
		local ending_with_notes = iut.combine_form_and_footnotes(ending, combined_footnotes)
		if not stem_in_effect then
			interr("stem_in_effect is nil")
		end
		iut.add_forms(base.forms, slot_prefix .. slot, stem_in_effect, ending_with_notes, combine_stem_ending)
	end
end


local function do_slot_abbreviation(base, abbr, fn)
	local patterns = adjective_slot_abbrs[abbr]
	if not patterns then
		error(("Internal error: Invalid abbreviation '%s' passed into do_slot_abbreviation()"):format(abbr))
	end
	if type(patterns) ~= "table" then
		patterns = {patterns}
	end
	for _, pattern in ipairs(patterns) do
		pattern = "^" .. pattern .. "$"
		for single_slot, forms in pairs(base.forms) do
			if rfind(single_slot, pattern) then
				fn(single_slot)
			end
		end
	end
end


local function process_slot_overrides(base)
	-- Set a single slot. Check to make sure we're not hitting a degree, number or state restriction.
	local function do_slot(slot, spec)
		local degfield = slot_to_degfield(slot)
		if not base.degrees[degfield] or not base.degrees[degfield][1] then
			error(("Override specified for invalid slot '%s' because degree '%s' doesn't exist"):format(slot, degfield))
		end
		for _, degree in ipairs(base.degrees[degfield]) do
			if skip_slot(degree.number, degree.state, slot) then
				error(("Override specified for invalid slot '%s' due to '%s' number restriction and/or '%s' state " ..
					"restriction of degree '%s'"):format(slot, degree.number, degree.state, degfield))
			end
		end
		if spec[1].form ~= "-" then
			-- Make sure distinct slots don't share forms.
			base.forms[slot] = m_table.deepCopy(spec)
		else
			base.forms[slot] = nil
		end
	end

	for slot, spec in pairs(base.overrides) do
		if adjective_slot_abbrs[slot] then
			do_slot_abbreviation(base, slot, function(slot) do_slot(slot, spec) end)
		else
			do_slot(slot, spec)
		end
	end
end


-- Add all strong state forms. Normally, use add_strong_decl(), which defaults the nom_s, instead of this. Only 17 of
-- the 24 possible endings are given because some are always the same as others. Currently we handle this syncretism in
-- the table itself, meaning it's not possible to override the missing endings separately. (FIXME: Is there ever a
-- situation where we need to separately control such endings? If so, we probably want to distinguish between "regular"
-- overrides, which happen before the copying of some endings to others, and "late" overrides, which happen after. A
-- similar distinction occurs the Italian verb module.) Specifically:
-- * The neuter singular and plural accusative, and the feminine plural accusative, are taken from the nominative.
-- * There is only one dative and genitive plural ending, which applies to all genders.
-- In addition, if `gen_n` is nil, it is copied from `gen_m`.
local function add_strong_decl_with_nom_sg(base, degree, props,
	nom_m, nom_f, nom_n,
	acc_m, acc_f,
	dat_m, dat_f, dat_n,
	gen_m, gen_f, gen_n,
	nom_mp, nom_fp, nom_np,
	acc_mp,
	dat_p,
	gen_p
)
	add(base, "str_nom_m", degree, props, nom_m)
	add(base, "str_nom_f", degree, props, nom_f)
	add(base, "str_nom_n", degree, props, nom_n)
	add(base, "str_acc_m", degree, props, acc_m)
	add(base, "str_acc_f", degree, props, acc_f)
	add(base, "str_dat_m", degree, props, dat_m)
	add(base, "str_dat_f", degree, props, dat_f)
	add(base, "str_dat_n", degree, props, dat_n)
	add(base, "str_gen_m", degree, props, gen_m)
	add(base, "str_gen_f", degree, props, gen_f)
	if gen_n == nil then -- not 'false'; use to specify no value for gen_n
		gen_n = gen_m
	end
	add(base, "str_gen_n", degree, props, gen_n)
	add(base, "str_nom_mp", degree, props, nom_mp)
	add(base, "str_nom_fp", degree, props, nom_fp)
	add(base, "str_nom_np", degree, props, nom_np)
	add(base, "str_acc_mp", degree, props, acc_mp)
	add(base, "str_dat_p", degree, props, dat_p)
	add(base, "str_gen_p", degree, props, gen_p)
end


-- Add all strong state forms other than the nominative singular. This should normally be used in preference to
-- add_strong_decl_with_nom_sg(), because the nominative singular should usually be specified as "*" so that it is
-- taken directly from the lemma.
local function add_strong_decl(base, degree, props,
	       nom_f, nom_n,
	acc_m, acc_f,
	dat_m, dat_f, dat_n,
	gen_m, gen_f, gen_n,
	nom_mp, nom_fp, nom_np,
	acc_mp,
	dat_p,
	gen_p
)
	add_strong_decl_with_nom_sg(base, degree, props,
		"*", nom_f, nom_n, acc_m, acc_f,
		dat_m, dat_f, dat_n, gen_m, gen_f, gen_n,
		nom_mp, nom_fp, nom_np, acc_mp,
		dat_p, gen_p
	)
end

-- Add all plural strong state forms other than the nominative plural.
local function add_strong_decl_pl_only(base, degree, props,
			nom_fp, nom_np,
	acc_mp,
	dat_p,
	gen_p
)
	add_strong_decl_with_nom_sg(base, degree, props,
		false, false, false, false, false,
		false, false, false, false, false, false,
		"*", nom_fp, nom_np, acc_mp,
		dat_p, gen_p
	)
end

-- Add all weak state forms. Only 6 of the 24 possible endings are given because some are always the same as others.
local function add_weak_decl(base, degree, props,
	wk_nom_m, wk_nom_f, wk_n,
	wk_obl_m, wk_obl_f,
	wk_p
)
	add(base, "wk_nom_m", degree, props, wk_nom_m)
	add(base, "wk_nom_f", degree, props, wk_nom_f)
	add(base, "wk_n", degree, props, wk_n)
	add(base, "wk_obl_m", degree, props, wk_obl_m)
	add(base, "wk_obl_f", degree, props, wk_obl_f)
	add(base, "wk_p", degree, props, wk_p)
end

-- Add all plural weak state forms.
local function add_weak_decl_pl_only(base, degree, props, wk_p)
	add_weak_decl(base, degree, props,
		false, false, false,
		false, false,
		wk_p
	)
end


local decls = {}


decls["indecl"] = function(base, degree, props)
	add_strong_decl(base, degree, props,
		      "",  "",
		"", "",
		"", "", "",
		"", "", nil,
		"", "", "",
		"",
		"",
		""
	)
	add_weak_decl(base, degree, props,
		"", "", "",
		"", "",
		""
	)
end


decls["decl?"] = function(base, degree, props)
	add_strong_decl(base, degree, props,
		      "?",  "?",
		"?", "?",
		"?", "?", "?",
		"?", "?", nil,
		"?", "?", "?",
		"?",
		"?",
		"?"
	)
	add_weak_decl(base, degree, props,
		"?", "?", "?",
		"?", "?",
		"?"
	)
end



decls["normal"] = function(base, degree, props)
	add_strong_decl(base, degree, props,
		      "^^",  "t",
		degree.inn and "*" or "an", "a",
		"um", "ri",  "u",
		"s",  "rar", nil,
		"ir", "ar", "^^",
		"a",
		"um",
		"ra"
	)
	add_weak_decl(base, degree, props,
		"i",  "a",   "a",
		"a",  "u",
		"u"
	)
end


decls["comp"] = function(base, degree, props)
	add_weak_decl(base, degree, props,
		"i",  "i",   "a",
		"i",  "i",
		"i"
	)
end


local function set_irreg_defaults(base)
	local number, state
	local basedeg = base.base_degree
	local lemma = basedeg.lemma
	if lemma == "einn" then
		state = "bothstates"
		base.sup = {{form = "einastur"}}
	elseif lemma == "tveir" or lemma == "þrír" or lemma == "fjórir" or lemma == "báðir" or lemma == "fáeinir" then
		number = "pl"
	end
	basedeg.number = number or "both"
	basedeg.state = state or "strong"
end


decls["irreg"] = function(base, degree, props)
	if degree.lemma == "sá" then
		add_strong_decl(base, degree, props,
					"sú", "það",
			"þann", "þá",
			"þeim", "þeirri", "því",
			"þess", "þeirrar", nil,
			"þeir", "þær", "þau",
			"þá",
			"þeim",
			"þeirra"
		)
		return
	end

	if degree.lemma == "hann" then
		add_strong_decl(base, degree, props,
					"hún", "það",
			"hann", "hana",
			"honum", "henni", "því",
			"hans", "hennar", "þess",
			"þeir", "þær", "þau",
			"þá",
			"þeim",
			"þeirra"
		)
		return
	end

	if degree.lemma == "þessi" then
		add_strong_decl(base, degree, props,
					"þessi", {"þetta", {form = "þettað", footnotes = {"[uncommon]"}}},
			{"þennan", {form = "þenna", footnotes = {"[archaic]"}}}, "þessa",
			"þessum", "þessari", "þessu",
			"þessa", "þessarar", nil,
			"þessir", "þessar", {"þessi", {form = "þaug", footnotes = {"[uncommon]"}}},
			"þessa",
			"þessum",
			"þessara"
		)
		return
	end

	if degree.lemma == "hinn" then
		add_strong_decl(base, degree, props,
					"hin", base.props.article and "hið" or "hitt",
			"hinn", "hina",
			"hinum", "hinni", "hinu",
			"hins", "hinnar", nil,
			"hinir", "hinar", "hin",
			"hina",
			"hinum",
			"hinna"
		)
		return
	end

	local stem = rmatch(degree.lemma, "^([mþs])inn$")
	if stem then
		add_strong_decl(base, degree, props,
					stem .. "ín", stem .. "itt",
			stem .. "inn", stem .. "ína",
			stem .. "ínum", stem .. "inni", stem .. "ínu",
			stem .. "íns", stem .. "innar", nil,
			stem .. "ínir", stem .. "ínar", stem .. "ín",
			stem .. "ína",
			stem .. "ínum",
			stem .. "inna"
		)
		return
	end

	if degree.lemma == "vor" or degree.lemma == "hvor" then
		stem = degree.lemma
		add_strong_decl(base, degree, props,
					stem, stem .. "t",
			stem .. "n", stem .. "a",
			stem .. "um", stem .. "ri", stem .. "u",
			stem .. "s", stem .. "rar", nil,
			stem .. "ir", stem .. "ar", stem,
			stem .. "a",
			stem .. "um",
			stem .. "ra"
		)
		return
	end

	local neutstem
	if degree.lemma == "hver" then
		stem = "hver"
		neutstem = ""
	elseif degree.lemma == "sérhver" then
		stem = "sérhver"
		neutstem = "sér"
	elseif degree.lemma == "einhver" then
		stem = "einhver"
		neutstem = "eitt"
	end
	if stem then
		add_strong_decl(base, degree, props,
					stem, {
						{form = neutstem .. "hvert", footnotes = {"[used with a noun]"}},
						{form = neutstem .. "hvað", footnotes = {"[used alone]"}},
					},
			stem .. "n", stem .. "ja",
			stem .. "jum", stem .. "ri", stem .. "ju",
			stem .. "s", stem .. "rar", nil,
			stem .. "jir", stem .. "jar", stem,
			stem .. "ja",
			stem .. "jum",
			stem .. "ra"
		)
		return
	end

	if degree.lemma == "nokkur" then
		stem = "nokk"
		add_strong_decl(base, degree, props,
					stem .. "ur", {
						{form = stem .. "urt", footnotes = {"[used with a noun]"}},
						{form = stem .. "uð", footnotes = {"[used alone]"}},
					},
			stem .. "urn", stem .. "ra",
			stem .. "rum", stem .. "urri", stem .. "ru",
			stem .. "urs", stem .. "urrar", nil,
			stem .. "rir", stem .. "rar", stem .. "ur",
			stem .. "ra",
			stem .. "rum",
			stem .. "urra"
		)
		return
	end

	if degree.lemma == "enginn" then
		if base.props.archaic then
			add_strong_decl(base, degree, props,
						  "engin", "ekkert",
				"öngvan", "öngva",
				"öngvum", "öngri", "öngvu",
				"einskis", "öngrar", nil,
				"öngvir", "öngvar", "engin",
				"öngva",
				"öngvum",
				"öngra"
			)
		else
			local engi = {form = "engi", footnotes = {"[poetic]"}}
			add_strong_decl_with_nom_sg(base, degree, props,
				{"*", engi}, {"engin", engi}, {"ekkert", {form = "ekki", footnotes = {"[in some fixed expressions]"}}},
				"engan", "enga",
				"engum", "engri", {"engu", {form = "einugi", footnotes = {"[in some fixed expressions]"}}},
				{"einskis", {form = "einkis", footnotes = {"[occasionally]"}}}, "engrar", nil,
				"engir", "engar", "engin",
				"enga",
				"engum",
				"engra"
			)
		end
		return
	end

	if degree.lemma == "fáeinir" then
		stem = "fáein"
		add_strong_decl_pl_only(base, degree, props,
					stem .. "ar", stem,
			stem .. "a",
			stem .. "um",
			stem .. "na"
		)
		add_weak_decl_pl_only(base, degree, props,
			stem .. "u"
		)
		return
	end

	if degree.lemma == "tveir" then
		add_strong_decl_pl_only(base, degree, props,
					"tvær", "tvö",
			"tvo",
			{"tveimur", "tveim"},
			"tveggja"
		)
		return
	end

	if degree.lemma == "þrír" then
		add_strong_decl_pl_only(base, degree, props,
					"þrjár", "þrjú",
			"þrjá",
			{"þremur", "þrem"},
			"þriggja"
		)
		return
	end

	if degree.lemma == "fjórir" then
		add_strong_decl_pl_only(base, degree, props,
					"fjórar", "fjögur",
			"fjóra",
			"fjórum",
			{"fjögurra", {form = "fjögra", footnotes = {"[rare in writing]"}}}
		)
		return
	end

	if degree.lemma == "báðir" then
		add_strong_decl_pl_only(base, degree, props,
					"báðar", "bæði",
			"báða",
			"báðum",
			"beggja"
		)
		return
	end

	if degree.lemma == "annar" then
		add_strong_decl(base, degree, props,
					"önnur", "annað",
			"annan", "aðra",
			"öðrum", "annarri", "öðru",
			"annars", "annarrar", "annars",
			"aðrir", "aðrar", "önnur",
			"aðra",
			"öðrum",
			"annarra"
		)
		return
	end

	error("Unrecognized irregular lemma '" .. degree.lemma .. "'")
end


-- Return the lemmas for this term. The return value is a list of {form = FORM, footnotes = FOOTNOTES}.
-- If `linked_variant` is given, return the linked variants (with embedded links if specified that way by the user),
-- otherwies return variants with any embedded links removed. If `remove_footnotes` is given, remove any
-- footnotes attached to the lemmas.
function export.get_lemmas(alternant_multiword_spec, linked_variant, remove_footnotes)
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
			if form == base.orig_lemma_no_links and base.orig_lemma:find("%[%[") then
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
		local function do_one(slot_spec)
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
	
		for _, slot_spec in ipairs(spec.slot_specs) do
			slot_spec = adjective_slot_abbrs[slot_spec] or slot_spec
			if type(slot_spec) == "table" then
				for _, ss in ipairs(slot_spec) do
					do_one(ss)
				end
			else
				do_one(slot_spec)
			end
		end
	end
end


-- Map `fn` over all override specs in `override_list`. `fn` is passed two items (the slot and form object of the
-- override), which it can mutate if needed. If it ever returns non-nil, mapping stops and that value is returned
-- as the return value of `map_override`; otherwise mapping runs to completion and nil is returned.
local function map_override(slot, override_list, fn)
	for _, formobj in ipairs(override_list) do
		local retval = fn(slot, formobj)
		if retval ~= nil then
			return retval
		end
	end
	return nil
end


-- Map `fn` over all override specs in `base.overrides` and the positive/comparative/superlative specs. `fn` is passed
-- two items (the slot and form object of the override), which it can mutate if needed. If it ever returns non-nil,
-- mapping stops and that value is returned as the return value of `map_all_overrides`; otherwise mapping runs to
-- completion and nil is returned.
local function map_all_overrides(base, fn)
	for slot, override in pairs(base.overrides) do
		local retval = map_override(slot, override, fn)
		if retval ~= nil then
			return retval
		end
	end
	for _, degspec in ipairs(compsup_degrees) do
		local degfield, desc = unpack(degspec)
		local field = degfield .. "spec"
		if base[field] then
			local retval = map_override(field, base[field], fn)
			if retval ~= nil then
				return retval
			end
		end
	end
	return nil
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


-- Return true if the given spec of one of the degrees (pos/comp/sup) explicitly disabled through -pos, -comp or -sup.
-- Also return true if `also_if_unspecified` given and the spec was left unspecified (this doesn't make sense for 'pos').
local function degree_disabled(spec, also_if_unspecified)
	if not spec then
		return also_if_unspecified
	end
	for _, formval in ipairs(spec) do
		if formval.form == "-" then
			return true
		end
	end
	return false
end


local function parse_slot_override_or_comp_sup_spec(colon_separated_group, segments, specs, spectype, parse_err)
	local form = colon_separated_group[1]
	if form == "" then
		parse_err(("Empty overrides not allowed for %s: '%s'"):format(spectype, table.concat(segments)))
	end
	local new_spec = {form = form, footnotes = fetch_footnotes(colon_separated_group, parse_err)}
	for _, existing_spec in ipairs(specs) do
		if existing_spec.form == new_spec.form then
			parse_err("Duplicate " .. spectype .. " spec '" .. table.concat(colon_separated_group) .. "'")
		end
	end
	table.insert(specs, new_spec)
end


--[=[
Parse a comparative/superlative spec (e.g. 'comp:^ri:+') and return the list of lemmas. Each lemma is a form object,
i.e. an object containing 'form' and 'footnotes' fields.
]=]
local function parse_comp_sup_spec(segments, parse_err)
	local specs = {}
	local colon_separated_groups = iut.split_alternating_runs_and_strip_spaces(segments, ":")
	for i, colon_separated_group in ipairs(colon_separated_groups) do
		if i == 1 then
			if colon_separated_group[2] then
				parse_err(("Footnotes not allowed directly on comparative/superlative spec '%s'; put them on the " ..
					"value following the colon"):format(colon_separated_group[1]))
			end
		else
			parse_slot_override_or_comp_sup_spec(colon_separated_group, segments, specs, "comparative/superlative spec",
				parse_err)
		end
	end
	return specs
end


--[=[
Parse a single override spec (e.g. 'str_nom_n:gott') and return two values: the slot(s) the override applies to, and a
list of override values. Each override value is a form object, i.e. an object containing 'form' and 'footnotes' fields.
]=]
local function parse_override(segments, parse_err)
	local slots = {}
	local specs = {}
	local colon_separated_groups = iut.split_alternating_runs_and_strip_spaces(segments, ":")
	for i, colon_separated_group in ipairs(colon_separated_groups) do
		if i == 1 then
			if colon_separated_group[2] then
				parse_err(("Footnotes not allowed directly on slot override '%s'; put them on the value following " ..
					"the colon"):format(colon_separated_group[1]))
			end
			slots = rsplit(colon_separated_group[1], "%+")
			for _, slot in ipairs(slots) do
				if not adjective_slot_set[slot] and not adjective_slot_abbrs[slot] then
					parse_err(("Unrecognized slot '%s' in override; expected strong slot %s; weak slot %s; " ..
						"comparative slot preceded by 'comp_'; superlative slot preceded by 'sup_'; " ..
						"abbreviation %s; or stem %s: %s"):format(slot, make_quoted_slot_list(strong_adjective_slots),
						make_quoted_slot_list(weak_adjective_slots), make_quoted_keys(adjective_slot_abbrs),
						make_quoted_list(export.overridable_stems),
						require(parse_utilities_module).escape_wikicode(table.concat(segments))))
				end
			end
		else
			parse_slot_override_or_comp_sup_spec(colon_separated_group, segments, specs, "slot override", parse_err)
		end
	end
	return slots, specs
end


-- Export for use by [[Module:is-noun]].
function export.parse_for_control_specs(part, parse_control_spec)
	if part:find("^[Uu]+_?mut") then
		parse_control_spec("umut", com.umut_types)
	elseif part:find("^%-?con") then
		parse_control_spec("con", {"con", "-con"})
	elseif part:find("^%-?ppdent") then
		parse_control_spec("ppdent", {"ppdent", "-ppdent"})
	elseif part:find("^%-?pp") then
		parse_control_spec("pp", {"pp", "-pp"})
	elseif part:find("^%-?j") then
		parse_control_spec("j", {"j", "-j"})
	elseif not part:find("^vstem") and part:find("^%-?v") then
		parse_control_spec("v", {"v", "-v"})
	else
		return false
	end
	return true
end


local function parse_inside(base, inside, is_scraped_noun)
	local function parse_err(msg)
		error((is_scraped_noun and "Error processing scraped noun spec: " or "") .. msg .. ": <" ..
			inside .. ">")
    end

	local base_degree = {}
	local segments = iut.parse_balanced_segment_run(inside, "[", "]")
	local dot_separated_groups = split_alternating_runs_with_escapes(segments, "%.")
	for i, dot_separated_group in ipairs(dot_separated_groups) do
		-- Parse a control spec such as "umut,uUmut[rare]". This assumes the control spec is contained in
		-- `dot_separated_group` (already split on brackets) and the result of parsing should go in `base[dest]`.
		-- `allowed_specs` is a list of the allowed control specs in this group, such as
		-- {"umut", "Umut", "uumut", "uUmut", "uUUmut", "u_mut"} or {"pp", "-pp"}. The result of parsing is a list of
		-- structures of the form {
		--   form = "FORM",
		--   footnotes = nil or {"FOOTNOTE", "FOOTNOTE", ...},
		-- }.
		local function parse_control_spec(dest, allowed_specs)
			if base_degree[dest] then
				parse_err(("Can't specify '%s'-type control spec twice; second such spec is '%s'"):format(
					dest, table.concat(dot_separated_group)))
			end
			base_degree[dest] = {}
			local comma_separated_groups = split_alternating_runs_with_escapes(dot_separated_group, ",")
			for _, comma_separated_group in ipairs(comma_separated_groups) do
				local specobj = {}
				local spec = comma_separated_group[1]
				if not m_table.contains(allowed_specs, spec) then
					parse_err(("For '%s'-type control spec, saw unrecognized spec '%s'; valid values are %s"):
						format(dest, spec, generate_list_of_possibilities_for_err(allowed_specs)))
				else
					specobj.form = spec
				end
				specobj.footnotes = fetch_footnotes(comma_separated_group, parse_err)
				table.insert(base_degree[dest], specobj)
			end
		end

		local part = dot_separated_group[1]
		if part == "" then
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
		elseif export.parse_for_control_specs(part, parse_control_spec) then
			-- nothing more to do
		elseif part:find("^decllemma%s*:") then -- or part:find("^declstate%s*:") or part:find("^declnumber%s*:") then
			local field, value = part:match("^(decl[a-z]+)%s*:%s*(.+)$")
			if not value then
				parse_err(("Syntax error in decllemma indicator: '%s'"):format(part))
			end
			if #dot_separated_group > 1 then
				parse_err(
					("Footnotes not allowed with '%s:' specs: '%s'"):format(field, table.concat(dot_separated_group)))
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
			if #dot_separated_group > 1 then
				parse_err(
					("Footnotes not allowed with '%s:' specs: '%s'"):format(field, table.concat(dot_separated_group)))
			end
			if base[field] then
				parse_err(("Can't specify '%s:' twice"):format(field))
			end
			base[field] = value
		elseif part:find("^@") then
			if #dot_separated_group > 1 then
				parse_err(
					("Footnotes not allowed with scrape specs: '%s'"):format(table.concat(dot_separated_group)))
			end
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
		elseif part == "-pos" then
			if base.posspec then
				parse_err("Can't specify '-pos' twice")
			end
			base.posspec = {{form = "-"}}
		elseif part == "comp" or part == "sup" or part == "-comp" or part == "-sup" then
			if dot_separated_group[2] then
				parse_err(("Footnotes not allowed directly on '%s'; put them on the value following the colon"):format(
					part))
			end
			local compsup_val
			if part:find("^%-") then
				part = part:sub(2)
				compsup_val = {{form = "-"}}
			else
				compsup_val = {{form = "+"}}
			end
			base[part .. "spec"] = compsup_val
		elseif part:find(":") then
			local spec, value = part:match("^([a-z_+]+)%s*:%s*(.+)$")
			if not spec then
				parse_err(("Syntax error in indicator with value, expecting alphabetic slot, stem/lemma override " ..
					"or comparative/superlative override indicator: '%s'"):format(part))
			end
			if export.overridable_stem_set[spec] then
				if base_degree[spec] then
					if spec == "stem" then
						parse_err("Can't specify spec for 'stem:' twice (including using 'stem:' along with # or ##)")
					else
						parse_err(("Can't specify '%s:' twice"):format(spec))
					end
				end
				base_degree[spec] = value
			elseif spec == "comp" or spec == "sup" then
				if base[spec .. "spec"] then
					parse_err(("Two spec sets specified for '%s'"):format(spec))
				else
					base[spec .. "spec"] = parse_comp_sup_spec(dot_separated_group, parse_err)
				end
			else
				local slots, override = parse_override(dot_separated_group, parse_err)
				local function check_duplication(slot)
					if base.override_slots_seen[slot] then
						parse_err(("Two overrides specified for slot '%s'"):format(slot))
					else
						base.override_slots_seen[slot] = true
					end
				end
				for _, slot in ipairs(slots) do
					if adjective_slot_abbrs[slot] then
						do_slot_abbreviation(base, slot, check_duplication)
					else
						check_duplication(slot)
					end
					base.overrides[slot] = override
				end
			end
		elseif #dot_separated_group > 1 then
			parse_err(
				("Footnotes only allowed with slot overrides, negatable indicators and by themselves: '%s'"):
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
		elseif part == "strong" or part == "weak" or part == "bothstates" then
			if base.state then
				if base.state ~= part then
					parse_err("Can't specify '" .. part .. "' along with '" .. base.state .. "'")
				else
					parse_err("Can't specify '" .. part .. "' twice")
				end
			end
			base.state = part
		elseif part == "#" or part == "##" then
			if base_degree.stem then
				parse_err("Can't specify a stem spec ('stem:', # or ##) twice")
			end
			base_degree.stem = part
		elseif part == "irreg" or part == "archaic" or part == "article" or part == "indecl" or part == "decl?"
				or part == "pred" or part == "comp?" then
			if base.props[part] then
				parse_err("Can't specify '" .. part .. "' twice")
			end
			base.props[part] = true
		else
			parse_err("Unrecognized indicator '" .. part .. "'")
		end
	end

	local base_degfield
	if not degree_disabled(base.posspec) then
		base_degfield = "pos"
		base_degree.slot_prefix = ""
	elseif not degree_disabled(base.compspec) then
		base_degfield = "comp"
		base_degree.slot_prefix = "comp_"
	elseif not degree_disabled(base.supspec) then
		base_degfield = "sup"
		base_degree.slot_prefix = "sup_"
	else
		parse_err("Cannot disable all three degrees (positive/comparative/superlative)")
	end
	base.base_degfield = base_degfield
	base.base_degree = base_degree
	base.degrees[base_degfield] = {base_degree}
	if base_degfield ~= "pos" then
		-- Indicate that the positive degree is explicitly disabled.
		base.degrees.pos = {}
	else
		if degree_disabled(base.compspec) and not base.supspec then
			-- If we're in the positive degree and the comparative was explicitly disabled, the superlative should be
			-- explicitly disable if unspecified.
			base.supspec = {{form = "-"}}
		end
		if not base.compspec and not base.supspec and not base.props["comp?"] and not base.props.indecl and
			not base.props["decl?"] and not base.props.irreg and not base.scrape_spec then
			parse_err("Must either specify a comparative, specify '-comp' to indicate no comparative, or " ..
				"specify 'comp?' to indicate that the comparative status is unknown")
		end
	end

	return base
end


-- Set some defaults (e.g. number and state) now, because they (esp. the number) may be needed below when determining
-- how to merge scraped and user-specified properies.
local function set_early_base_defaults(base)
	if not base.props.irreg then
		local basedeg = base.base_degree
		basedeg.number = base.number or "both"
		basedeg.state = base.state or base.base_degfield == "comp" and "weak" or "bothstates"
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
	base.scrape_chain = scrape_chain
	parse_inside(base, inside, #scrape_chain > 0)
	local basedeg = base.base_degree
	basedeg.lemma = lemma

	if not base.scrape_spec then
		-- If we're not scraping the declension from another noun, just return the parsed `base`.
		-- But don't set early defaults if we're being scraped because it interferes with overriding the number
		-- and/or state by the noun that is scraping us.
		if #scrape_chain == 0 then
			set_early_base_defaults(base)
		end
		return base
	else
		local prefix, base_adj, declspec
		prefix, base_adj, declspec = com.find_scraped_infl {
			lemma = lemma,
			scrape_spec = base.scrape_spec,
			scrape_is_suffix = base.scrape_is_suffix,
			scrape_is_uppercase = base.scrape_is_uppercase,
			infltemp = "is-adecl",
			allow_empty_infl = false,
			inflid = base.scrape_id,
			parse_off_ending = com.parse_off_final_nom_ending,
		}
		if type(declspec) == "string" then
			base.prefix = prefix
			base.base_adj = base_adj
			base.scrape_error = declspec
			return base
		end

		-- Parse the inside spec from the scraped noun (merging any sub-scraping specs), and copy over the
		-- user-specified properties on top of it.
		table.insert(scrape_chain, base_adj)
		local inner_base = parse_inside_and_merge(declspec.infl, base_adj, scrape_chain)
		local inner_basedeg = inner_base.base_degree
		inner_basedeg.lemma = lemma
		inner_base.prefix = prefix
		inner_base.base_adj = base_adj

		-- Add `prefix` to a full variant of the base noun (e.g. a stem spec or override). We may need
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

		-- If there's a prefix, add it now to all the overrides in the scraped noun, as well as 'decllemma'
		-- and all stem overrides.
		if prefix ~= "" then
			map_all_overrides(inner_base, function(slot, formobj)
				local formval = formobj.form
				-- Not if the override contains # or ##, which expand to the full lemma (possibly minus -r
				-- or -ur); or if the override begins with ~ or ^, indicating the stem or its i-mutated variant;
				-- or if the override is + or - (as may happen with positive/comparative/superlative specs).
				if not formval:find("#") and not formval:find("^[~^]") and formval ~= "+" and formval ~= "-" then
					formobj.form = add_prefix(formval)
				end
			end)
			if inner_base.decllemma then
				inner_base.decllemma = add_prefix(inner_base.decllemma)
			end
			for _, stem in ipairs(export.overridable_stems) do
				-- Only actual stems, not imutval; and not if the stem contains # or ##, which
				-- expand to the full lemma (possibly minus -r or -ur).
				if inner_basedeg[stem] and stem:find("stem$") and not inner_basedeg[stem]:find("#") then
					inner_basedeg[stem] = add_prefix(inner_basedeg[stem])
				end
			end
		end

		local function copy_base_properties(plist)
			for _, prop in ipairs(plist) do
				if base[prop] ~= nil then
					inner_base[prop] = base[prop]
				end
			end
		end
		local function copy_basedeg_properties(plist)
			for _, prop in ipairs(plist) do
				if basedeg[prop] ~= nil then
					inner_basedeg[prop] = basedeg[prop]
				end
			end
		end
		copy_basedeg_properties(export.control_specs)
		copy_basedeg_properties(export.overridable_stems)
		copy_basedeg_properties { "number", "state" }
		copy_base_properties { "decllemma", "q", "header" }
		for _, degspec in ipairs(compsup_degrees) do
			local degfield, desc = unpack(degspec)
			copy_base_properties { degfield .. "spec" }
		end
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
		if inner_basedeg.number == "sg" then
			for slot, _ in pairs(inner_base.overrides) do
				if slot:find("p$") then
					inner_base.overrides[slot] = nil
				end
			end
		end
		-- If user specified '-comp' or '-sup', cancel out any comparative/superlative overrides,
		-- otherwise we'll get an error.
		for _, degfield in ipairs { "comp", "sup" } do
			if degree_disabled(base[degfield .. "spec"]) then
				for slot, _ in pairs(inner_base.overrides) do
					if slot:find("^" .. degfield) then
						inner_base.overrides[slot] = nil
					end
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
		error(("Lemma '%s': %s"):format(base.base_degree.lemma, msg))
	end
	-- Set default values.
	if base.props.irreg then
		set_irreg_defaults(base)
		for _, control_spec in ipairs(export.control_specs) do
			if base[control_spec] then
				check_err(("'%s' can only be specified with regular adjectives"):format(control_spec))
			end
		end
		return
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
		if base.props.pred then
			alternant_multiword_spec.saw_pred = true
		else
			alternant_multiword_spec.saw_non_pred = true
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
		if base.props["comp?"] then
			alternant_multiword_spec.saw_unknown_comp = true
		else
			alternant_multiword_spec.saw_non_unknown_comp = true
		end
	end)
end


local function expand_property_sets(degree)
	degree.prop_sets = {{}}

	-- Construct the prop sets from all combinations of control specs, in case any given spec has more than one
	-- possibility.
	for _, control_spec in ipairs(export.control_specs) do
		local specvals = degree[control_spec]
		-- Handle unspecified control specs.
		if not specvals then
			specvals = {false}
		end
		if #specvals == 1 then
			for _, prop_set in ipairs(degree.prop_sets) do
				-- Convert 'false' back to nil
				prop_set[control_spec] = specvals[1] or nil
			end
		else
			local new_prop_sets = {}
			for _, prop_set in ipairs(degree.prop_sets) do
				for _, specval in ipairs(specvals) do
					local new_prop_set = m_table.shallowCopy(prop_set)
					new_prop_set[control_spec] = specval
					table.insert(new_prop_sets, new_prop_set)
				end
			end
			degree.prop_sets = new_prop_sets
		end
	end
end


local function normalize_all_lemmas(alternant_multiword_spec)
	iut.map_word_specs(alternant_multiword_spec, function(base)
		local lemma = base.orig_lemma_no_links
		local basedeg = base.base_degree
		basedeg.actual_lemma = lemma
		basedeg.lemma = base.decllemma or lemma
		base.source_template = alternant_multiword_spec.source_template
	end)
end


-- Determine the declension of the positive degree based on the lemma. The declension is set in pos.decl and the stem in
-- pos.stem (which will come from the user if explicitly set, otherwise computed from the lemma).
local function determine_positive_declension(base)
	local stem
	local pos = base.degrees.pos[1]
	if not pos then
		error("Internal error: Positive degree doesn't exist")
	end
	local default_props = {}
	local defcomp, defsup
	-- Determine declension
	if base.props.indecl then
		pos.decl = "indecl"
		stem = pos.lemma
	elseif base.props["decl?"] then
		pos.decl = "decl?"
		stem = pos.lemma
	elseif base.props.irreg then
		pos.decl = "irreg"
		stem = pos.lemma
	elseif not stem then
		-- There must be at least one vowel; lemmas like [[bur]] don't count.
		stem = rmatch(pos.lemma, "^(.*" .. com.vowel_or_hyphen_c .. ".*)ur$")
		if stem then
			if pos.stem == pos.lemma then
				-- [[dapur]] "sad" etc. where the stem includes the final -r; default vowel stem has contraction and
				-- so do the default comparatives and superlatives, but many of these have alternative comparatives
				-- and/or superlatives that need to be given explicitly
				stem = pos.stem
				default_props.con = "con"
				-- defcomp, defsup computed later
			elseif not pos.stem and (stem:find("leg$") or stem:find("ug$")) then
				-- [[fallegur]] "beautiful" and others in -legur; [[auðugur]] "rich" and others in -ugur; note that
				-- this includes words like [[lóugur]] and [[snjóugur]] with a vowel preeding the -ugur (there are no
				-- adjectives in -augur).
				defcomp = stem .. "ri"
				-- defsup computed later
			elseif rfind(stem, com.vowel_or_hyphen_c .. ".*að$") then
				-- [[gáfaður]] "gifted", [[saltaður]] "salty", etc.; but beware of compounds of [[glaður]] such as
				-- [[fjörglaður]] "cheerful"
				default_props.pp = "pp"
				default_props.umut = function(base, props)
					-- PP-type adjectives like [[gáfaður]] and [[saltaður]] and have uUmut, leading to feminine singular
					-- 'gáfuð' and 'söltuð', but non-PP-type adjectives like [[fjörglaður]] have feminine singular
					-- 'fjörglöð' with regular umut.
					local umut_val
					if props.pp and props.pp.form == "-pp" then
						umut_val = "umut"
					else
						umut_val = "uUmut"
					end
					return {form = umut_val, defaulted = true}
				end
				defcomp = function(base, props)
					if props.pp and props.pp.form == "-pp" then
						-- compounds of [[glaður]] etc.; see above
						return stem .. "ari"
					else
						return stem .. "ri"
					end
				end
				-- defsup computed later
			else
				-- [[gulur]] "yellow" and lots of others
				-- defcomp, defsup computed later
			end
		end
	end
	if not stem then
		stem = rmatch(pos.lemma, "^(.*" .. com.vowel_c .. ")r$")
		if stem then
			-- The default for these lemmas is to include the -r in the stem, except for lemmas ending in -ár and -ær.
			-- If the user doesn't want the -r in the stem they need to explicitly specify this using e.g. '##' (or
			-- conversely, for -ár/-ær lemmas, use '#' to include the -r in the stem).
			if pos.stem == stem or (not pos.stem and rfind(stem, "[ÁáÆæ]$")) then
				pos.double_r_and_t = true
				defcomp = stem .. "rri"
				if rfind(stem, "[ÆæÝý]$") then
					-- Lemmas like [[nýr]] "new", [[hlýr]] "warm", [[langær]] "long-lasting"
					default_props.j = "j"
					defsup = stem .. "jastur"
				else
					-- defsup computed later
				end
			else
				-- Process later on in the null-ending arm.
				stem = nil
			end
		end
	end
	if not stem and not pos.stem then
		-- Beware of [[snjall]] "masterly, excellent, clever", where both l's are part of the stem.
		stem = rmatch(pos.lemma, "^(.*l)l$")
		if stem then
			-- [[heill]] "whole; healthy", [[fúll]] "foul", [[þögull]] "taciturn" (with or without contraction), etc.
			pos.assimilate_r = true
			defcomp = stem .. "li"
			-- defsup computed later, depending on the value of 'con'
		end
	end
	if not stem and not pos.stem then
		stem = rmatch(pos.lemma, "^(.*n)n$")
		if stem then
			pos.assimilate_r = true
			if stem:find("[^e]in$") then
				-- [[boginn]] "curved, crooked"; [[heiðinn]] "heathen"; [[fyndinn]] "witty"; also [[náinn]] "near" and
				-- others in -Vinn other than -einn; also [[söngvinn]] "fond of singing, musical" and [[höggvinn]]
				-- "chopped" where the -v- disappears before contracted -n-. These adjectives have contraction before
				-- vowel endings where stem -in becomes -n (except in past participles with the 'ppdent' property,
				-- where the -n is replaced with a dental, either -d- (after l/m/n), -t- (after a voiceless consonant)
				-- or -ð- (otherwise). They also have a couple of special endings: acc masc sg is in -inn not expected
				-- #-nan, and nom/acc neut sg is in -ið. We signal this by setting `pos.inn`. In addition, if 'ppdent'
				-- applies and there is a comparative and superlative, the dental stem applies, as in [[vantalinn]]
				-- "not included, omitted, understated (of assets/money)" with comparative [[vantaldari]] and
				-- superlative [[vantaldastur]].
				pos.inn = true
				local function compute_vowel_stem(props)
					local vowel_stem = stem:sub(1, -3) -- chop off final -in
					-- [[söngvinn]] -> 'söngn-', [[höggvinn]] -> 'höggn-'
					vowel_stem = vowel_stem:gsub("gv$", "g")
					if props.ppdent and props.ppdent.form == "ppdent" then
						vowel_stem = com.add_dental_ending(vowel_stem)
					else
						if not rfind(vowel_stem, com.cons_c .. "n$") then
							vowel_stem = vowel_stem .. "n"
						end
					end
					return vowel_stem
				end
				defcomp = function(base, props)
					-- Save for later stem computation.
					props.vowel_stem = compute_vowel_stem(props)
					return props.vowel_stem .. "ari"
				end
				defsup = function(base, props)
					-- props.vowel_stem stored in defcomp
					return compute_vowel_stem(props) .. "astur"
				end
			else
				defcomp = stem .. "ni"
				-- defsup computed later
			end
		end
	end
	if not stem then
		stem = rmatch(pos.lemma, "^(.*)i$")
		if stem then
			-- weak-only, e.g. [[þriðji]] "third"
			default_props.state = "weak"
			-- defcomp and defsup computed later (although there may be no such adjectives with comparatives)
		end
	end
	if not stem then
		-- Miscellaneous terms without ending
		stem = pos.lemma
		-- defcomp and defsup computed later (although there may be no such adjectives with comparatives)
	end

	-- Set the stem to the computed stem if not explicitly set by the user.
	pos.stem = pos.stem or stem
	-- Set the default props in `pos` unless explicitly set by the user; but some default props are specific to each
	-- property set and need to be set on each one.
	for k, v in pairs(default_props) do
		if not pos[k] then
			if export.control_spec_set[k] then
				for _, props in ipairs(pos.prop_sets) do
					if type(v) == "function" then
						props[k] = v(base, props)
					else
						props[k] = {form = v, defaulted = true}
					end
				end
			else
				pos[k] = v
			end
		end
	end
	-- Set the default comparative and superlative, which are specific to each property set. Do this after processing
	-- the other default properties because the default comparative/superlative functions frequently depend on other
	-- properties (e.g. 'con').
	local function compute_comp_sup_stem(props)
		local comp_sup_stem = stem
		if props.con and props.con.form == "con" then
			comp_sup_stem = com.apply_contraction(stem)
		end
		return comp_sup_stem
	end
	defcomp = defcomp or function(base, props)
		return compute_comp_sup_stem(props) .. "ari"
	end
	defsup = defsup or function(base, props)
		return compute_comp_sup_stem(props) .. "astur"
	end
	for k, v in pairs { defcomp = defcomp, defsup = defsup } do
		for _, props in ipairs(pos.prop_sets) do
			if type(v) == "function" then
				props[k] = v(base, props)
			else
				props[k] = v
			end
		end
	end
	pos.decl = pos.decl or "normal"
	track("decl/" .. pos.decl)
end


-- Initialize the stem and declension of a comparative or superlative degree object given various properties. This is
-- broken out of insert_forms() for use in initializing the base degree object of comparative/superlative-only lemmas,
-- which are otherwise already initialized.
local function initialize_degree_object_stem_and_decl(degree, degfield, lemma)
	local stem
	if degfield == "sup" then
		local ending = degree.state == "weak" and "i" or "ur"
		stem = lemma:match("^(.*)" .. ending .. "$")
		if not stem then
			error(("Superlative lemma '%s' doesn't end in -%s, as expected"):format(lemma, ending))
		end
	elseif degfield == "comp" then
		stem = lemma:match("^(.*)i$")
		if not stem then
			error(("Comparative lemma '%s' doesn't end in -i, as expected"):format(lemma))
		end
	else
		error(("Internal error: Unrecognized degree field value %s"):format(dump(degfield)))
	end
	degree.stem = degree.stem or stem
	degree.decl = degfield == "sup" and "normal" or "comp"
end


-- Get the default superlative u-mutation. If the superlative ends in -astur, it should be "one up" from the positive
-- u-mutation value (umut -> uUmut, uUmut -> uUUmut); else (superlative ends in -stur) it should be the same.
local function default_superlative_umut(lemma, pos_umut)
	pos_umut = pos_umut or "umut"
	if lemma:find("astur$") or lemma:find("asti$") then
		pos_umut = pos_umut:gsub("mut$", "Umut")
	end
	return pos_umut
end


-- Insert a comparative/superlative degree object, typically based on a user-specified or defaulted spec.
local function insert_degree_object(base, degfield, lemma, footnotes, umut)
	local degree = {
		lemma = lemma,
		actual_lemma = lemma,
		slot_prefix = degfield .. "_",
		footnotes = footnotes,
		state = degfield == "sup" and "bothstates" or "weak",
		number = "both",
		prop_sets = {{
			umut = umut or {form = degfield == "sup" and default_superlative_umut(lemma) or "umut", defaulted = true}
		}},
	}
	initialize_degree_object_stem_and_decl(degree, degfield, lemma)
	table.insert(base.degrees[degfield], degree)
end


-- Construct appropriate comparative/superlative property sets based on the default comparative/superlative, and insert
-- into the appropriated degrees structure. `degfield` is "comp" or "sup" and `spec_footnotes` gives the footnotes
-- specified along with the "+" spec that triggered this function.
local function insert_default_comp_sup_specs(base, degfield, spec_footnotes)
	for _, props in ipairs(base.base_degree.prop_sets) do
		-- This fetches the "defcomp" or "defsup" field.
		local default = props["def" .. degfield]
		local umut = m_table.shallowCopy(props.umut) or {form = "umut", defaulted = true}
		if degfield == "sup" then
			umut.form = default_superlative_umut(default, umut.form)
		end
		insert_degree_object(base, degfield, default, spec_footnotes, umut)
	end
end

local function generate_umlauted_comp_sup(stem, spec)
	if spec == "^" then
		stem = com.apply_i_mutation(stem)
	elseif spec == "^!" then
		stem = com.apply_i_mutation(com.apply_contraction(stem))
	end
	local gencomp, gensup
	if rfind(stem, com.vowel_c .. "$") then
		gencomp = stem .. "rri"
	elseif rfind(stem, com.vowel_c .. "[ln]$") then
		gencomp = stem .. usub(stem, -1) .. "i"
	elseif rfind(stem, com.cons_c .. "r$") then
		gencomp = stem .. "i"
	else
		gencomp = stem .. "ri"
	end
	gensup = stem .. "stur"
	return gencomp, gensup
end

-- Process the `comp:...` or `sup:...` spec given by the user and construct the appropriate property sets, one per stem.
-- `degfield` is either "comp" or "sup", and `specs` gives the user-specified specs. Note that the default u-mutation
-- for superlatives in -astur is uUmut, but if the spec was given (implicity or explicitly) as "+", we use the default
-- comparative or superlative, and in that case the u-mutation for superlatives in -astur is constructed from the
-- corresponding positive-degree u-mutation by adding U to the end, so that umut -> uUmut but uUmut -> uUUmut (cf.
-- [[saltaður]] "salty" with u-mutation uUmut and feminine singular/neuter plural [[söltuð]], and superlative
-- [[saltaðastur]] with u-mutation uUUmut and feminine singular/neuter plural [[söltuðust]]).
local function process_comp_sup_spec(base, degfield, specs)
	local basedeg = base.base_degree
	specs = specs or {{form = "+"}}
	if base.degrees[degfield] then
		error(("Internal error: Attempt to create `degrees` list for field `%s` when it already exists: %s"):format(
			degfield, dump(base.degrees)))
	end
	base.degrees[degfield] = {}
	for _, spec in ipairs(specs) do
		local forms
		if spec.form == "-" then
			-- Skip "-"; effectively, no forms get inserted.
		elseif spec.form == "+" then
			insert_default_comp_sup_specs(base, degfield, spec.footnotes)
		else
			local formval
			if spec.form:find("^~!") then
				formval = com.apply_contraction(basedeg.stem) .. spec.form:sub(3)
			elseif spec.form:find("^~") then
				formval = basedeg.stem .. spec.form:sub(2)
			elseif spec.form == "^" or spec.form == "^!" then
				local gencomp, gensup = generate_umlauted_comp_sup(basedeg.stem, spec.form)
				if degfield == "comp" then
					formval = gencomp
					spec.gensup = gensup
				else
					formval = gensup
				end
			else
				formval = spec.form
			end
			spec.resolved_form = formval
			insert_degree_object(base, degfield, formval, spec.footnotes)
		end
	end
end


local function derive_sup_lemma_from_comp_lemma(comp_lemma)
	local sup_lemma = comp_lemma:gsub("[rln]i$", "stur")
	if not sup_lemma:find("stur$") then
		error(("Don't know how to derive superlative lemma from comparative lemma '%s'; specify " ..
			"superlative lemma explicitly"):format(comp_lemma))
	end
	return sup_lemma
end


-- If the `comp:...` spec is given but not the `sup:...` spec, derive the superlative from the comparative.
local function derive_sup_from_comp(base, compspecs)
	if base.degrees.sup then
		error(("Internal error: Attempt to create `degrees` list for field `sup` when it already exists: %s"):format(
			degfield, dump(base.degrees)))
	end
	base.degrees.sup = {}
	for _, spec in ipairs(compspecs) do
		local forms
		if spec.form == "-" then
			-- Skip "-"; effectively, no forms get inserted.
		elseif spec.form == "+" then
			insert_default_comp_sup_specs(base, "sup", spec.footnotes)
		elseif spec.form == "^" or spec.form == "^!" then
			insert_degree_object(base, "sup", spec.gensup, spec.footnotes)
		else
			insert_degree_object(base, "sup", derive_sup_lemma_from_comp_lemma(spec.resolved_form), spec.footnotes)
		end
	end
end


-- Determine the stems and other properties to use for each property set for each `degree` structure. The list of such
-- properties is given in the comment above create_base(), along with the explanation of what a degree structure and
-- property set is and why we have multiple such degree structures (generally, one per base lemma, where there may be
-- multiple such comparative and/or superlative base lemmas) and property sets (generally, one per combination of
-- control specs such as 'con,-con' and 'umut,uUmut').
local function determine_props(base, degree)
	-- Now determine all the props for each prop set.
	for _, props in ipairs(degree.prop_sets) do
		-- All adjectives have u-mutation in the feminine singular and neuter plural (among others), which triggers
		-- u-mutation, so we need to compute the u-mutation stem using "umut" if not specifically given. Set `defaulted`
		-- so an error isn't triggered if there's no special u-mutated form.
		local props_umut = props.umut
		if not props_umut then
			props_umut = {form = "umut", defaulted = true}
		end

		-- First do all the stems.
		local stem, nonvstem, umut_nonvstem, vstem, umut_vstem
		stem = degree.stem
		nonvstem = stem
		umut_nonvstem = com.apply_u_mutation(nonvstem, props_umut.form, not props_umut.defaulted)
		-- For -inn adjectives, we already computed the correct vowel stem, so just use it.
		vstem = props.vowel_stem or degree.vstem or degree.stem
		local is_contracted = props.con and props.con.form == "con"
		if is_contracted then
			if degree.inn then
				error("Internal error: 'con' cannot be specified for adjectives ending in -inn; it's handled automatically internally and should have been caught earlier")
			end
			vstem = com.apply_contraction(vstem)
		end
		-- Contracted stems should use regular u-mutation even if the uncontracted stem uses uUmut. Otherwise we either
		-- get an error because uUmut can't be applied to a single-syllable word (e.g. in [[gamall]]) or we get the
		-- wrong result (e.g. in [[einsamall]] with strong dative plural #einsumlum). In those same circumstances, we
		-- should allow the u-mutation to have no effect, necessary e.g. for [[yðar]] with uUmut producing feminine
		-- 'yður' but contracted stem 'yðr-' not undergoing u-mutation.
		umut_vstem = com.apply_u_mutation(vstem, is_contracted and "umut" or props_umut.form,
			not is_contracted and not props_umut.defaulted)

		props.stem = stem
		if nonvstem ~= stem then
			props.nonvstem = nonvstem
		end
		if umut_nonvstem ~= nonvstem then
			-- For 'con' and 'ppdent' below, footnotes can be placed on -con or -ppdent so we have to check for those
			-- footnotes as well as checking for the vstem and such being different, so the -con and -ppdent footnotes
			-- are still active. However, there's no such thing as -umut, and any time that there's an explicit umut
			-- variant given, umut_nonvstem will be different from nonvstem (otherwise an error will occur in
			-- apply_u_mutation), so we don't need this extra check here.
			if props_umut then
				umut_nonvstem = iut.combine_form_and_footnotes(umut_nonvstem, props_umut.footnotes)
			end
			props.umut_nonvstem = umut_nonvstem
		end
		if vstem ~= stem or props.con and props.con.footnotes or props.ppdent and props.ppdent.footnotes then
			-- See comment above for why we need to check for props.con.footnotes and props.ppdent.footnotes (basically,
			-- to handle footnotes on -con and -ppdent).
			local footnotes = iut.combine_footnotes(props.con and props.con.footnotes or nil,
				props.ppdent and props.ppdent.footnotes or nil)
			vstem = iut.combine_form_and_footnotes(vstem, footnotes)
			props.vstem = vstem
		end
		if umut_vstem ~= vstem or props.con and props.con.footnotes or props.ppdent and props.ppdent.footnotes then
			-- See comment above under `umut_nonvstem ~= nonvstem`. There's no -umut so whenever there's a specific
			-- umut variant with footnote, umut_vstem will be different from vstem so we don't need to check for
			-- `or props_umut and props_umut.footnotes` above.
			local footnotes = iut.combine_footnotes(iut.combine_footnotes(props.con and props.con.footnotes or nil,
				props_umut and props_umut.footnotes or nil), props.ppdent and props.ppdent.footnotes or nil)
			umut_vstem = iut.combine_form_and_footnotes(umut_vstem, footnotes)
			props.umut_vstem = umut_vstem
		end

		-- Do the j-infix, v-infix and pp properties.
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
		if props.pp then
			props.pp_footnotes = props.pp.footnotes
			props.pp = props.pp.form == "pp" and true or false
		end
	end
end


local function detect_indicator_spec(alternant_multiword_spec, base)
	local basedeg = base.base_degree
	-- Replace # and ## in all overridable stems as well as all overrides.
	for _, stemkey in ipairs(export.overridable_stems) do
		basedeg[stemkey] = com.replace_hashvals(basedeg[stemkey], basedeg.lemma)
	end
	map_all_overrides(base, function(slot, formobj)
		formobj.form = com.replace_hashvals(formobj.form, basedeg.lemma)
	end)

	if base.props.irreg then
		expand_property_sets(basedeg)
		basedeg.stem = ""
		basedeg.decl = "irreg"
	else
		if base.base_degfield == "sup" then
			-- Superlative-only lemmas (like other superlatives) default to uUmut unless explicitly specified otherwise.
			basedeg.umut = basedeg.umut or {{form = default_superlative_umut(basedeg.lemma), defaulted = true}}
		end
		expand_property_sets(basedeg)
		if base.base_degfield == "pos" then
			determine_positive_declension(base)
			-- Next process the superative, if specified. We do this first so that if there is a superative and no
			-- comparative specified, we add a comparative; but if sup:- is given, we don't add a comparative.
			if base.supspec then
				process_comp_sup_spec(base, "sup", base.supspec)
				if not base.compspec then
					base.compspec = base.degrees.sup[1] and {{form = "+"}} or {{form = "-"}}
				end
			end
			-- Next process the comparative, if specified (or defaulted because a superlative was specified).
			if base.compspec then
				process_comp_sup_spec(base, "comp", base.compspec)
			end
			-- Next, if comparative specified but not superlative, derive the superlative(s) from the comparative(s).
			if base.compspec and not base.supspec then
				derive_sup_from_comp(base, base.compspec)
			end
		else
			initialize_degree_object_stem_and_decl(basedeg, base.base_degfield, basedeg.lemma)
			if base.base_degfield == "comp" then
				for _, prop_set in ipairs(basedeg.prop_sets) do
					prop_set.defsup = derive_sup_lemma_from_comp_lemma(basedeg.lemma)
				end
				process_comp_sup_spec(base, "sup", base.supspec or {{form = "+"}})
			end
		end
	end

	for _, degspec in ipairs(compsup_degrees) do
		local degfield, desc = unpack(degspec)
		if base.degrees[degfield] then
			for _, degree in ipairs(base.degrees[degfield]) do
				determine_props(base, degree)
			end
		end
	end

	-- Make sure all alternants agree in having a positive, comparative and/or superlative.
	for _, degspec in ipairs(compsup_degrees) do
		local degfield, desc = unpack(degspec)
		local hasprop = "has" .. degfield
		local has_deg = base.degrees[degfield] and (base.degrees[degfield][1] and "has" or "hasnot") or "unspec"
		if alternant_multiword_spec[hasprop] == nil then
			alternant_multiword_spec[hasprop] = has_deg
		elseif alternant_multiword_spec[hasprop] ~= has_deg then
			error(("All alternants must agree in whether they have a %s, but saw one alternant with value '%s' " ..
				"and another with value '%s'"):format(alternant_multiword_spec[hasprop], has_deg))
		end
	end

	-- Make sure all alternants agree in 'number' and 'state' for each degree if specified.
	for _, degspec in ipairs(compsup_degrees) do
		local degfield, desc = unpack(degspec)
		if base.degrees[degfield] then
			for _, degree in ipairs(base.degrees[degfield]) do
				for _, prop in ipairs { "number", "state" } do
					local val = degree[prop] or false
					if alternant_multiword_spec[prop][degfield] == nil then
						alternant_multiword_spec[prop][degfield] = val
					elseif alternant_multiword_spec[prop][degfield] ~= val then
						error(("All %s alternants must agree in the value of '%s', if specified"):format(
							desc, prop))
					end
				end
			end
		end
	end

	-- Make sure all alternants agree in various properties.
	for _, prop in ipairs { "decl?", "indecl", "irreg" } do
		local val = not not base.props[prop]
		if alternant_multiword_spec[prop] == nil then
			alternant_multiword_spec[prop] = val
		elseif alternant_multiword_spec[prop] ~= val then
			error(("If one alternant specifies '%s', all must"):format(prop))
		end
	end
end


local function detect_all_indicator_specs(alternant_multiword_spec)
	iut.map_word_specs(alternant_multiword_spec, function(base)
		detect_indicator_spec(alternant_multiword_spec, base)
	end)
end


local function decline_adjective(base)
	for degfield, degree_list in pairs(base.degrees) do
		for _, degree in ipairs(degree_list) do
			for _, props in ipairs(degree.prop_sets) do
				if not decls[degree.decl] then
					error(("Internal error: Unrecognized declension type '%s': %s"):format(degree.decl or "(nil)", dump(degree)))
				end
				decls[degree.decl](base, degree, props)
			end
		end
	end
	handle_derived_slots_and_overrides(base)
	process_addnote_specs(base)
end


-- Compute the categories to add the noun to, as well as the annotation to display in the declension title bar. We
-- combine the code to do these functions as both categories and title bar contain similar information.
local function compute_categories_and_annotation(alternant_multiword_spec)
	local all_cats = {}
	local function inscat(cattype)
		-- Don't insert categories with determiners/pronouns; all are irregular in various ways.
		if not alternant_multiword_spec.irreg then
			m_table.insertIfNot(all_cats, "Icelandic " .. cattype)
		end
	end
	local plpos = m_string_utilities.pluralize(alternant_multiword_spec.pos or "adjective")
	if alternant_multiword_spec.saw_indecl and not alternant_multiword_spec.saw_non_indecl then
		inscat("indeclinable " .. plpos)
	end
	if alternant_multiword_spec.saw_unknown_decl and not alternant_multiword_spec.saw_non_unknown_decl then
		inscat(plpos .. " with unknown declension")
	end
	local annotation
	local annparts = {}
	local irregs = {}
	local stemspecs = {}
	local scrape_chains = {}
	local umlauted_comparison = false
	local function insann(txt, joiner)
		if joiner and annparts[1] then
			table.insert(annparts, joiner)
		end
		table.insert(annparts, txt)
	end

	local function do_word_spec(base)
		-- User-specified 'decllemma:' indicates irregular stem.
		if base.decllemma then
			m_table.insertIfNot(irregs, "irreg-stem")
			if plpos == "adjectives" then
				inscat("adjectives with irregular stem")
			end
		end
		for _, props in ipairs(base.base_degree.prop_sets) do
			m_table.insertIfNot(stemspecs, props.stem)
		end
	end

	iut.map_word_specs(alternant_multiword_spec, function(base)
		do_word_spec(base)
		if base.scrape_chain[1] then
			local linked_scrape_chain = {}
			for _, element in ipairs(base.scrape_chain) do
				table.insert(linked_scrape_chain, ("[[%s]]"):format(element))
			end
			m_table.insertIfNot(scrape_chains, table.concat(linked_scrape_chain, " -> "))
		end
		local function check_umlauted(spec)
			if spec then
				for _, formobj in ipairs(spec) do
					if formobj.form:find("^%^") then
						umlauted_comparison = true
						return
					end
				end
			end
		end
		if alternant_multiword_spec.haspos == "has" then
			check_umlauted(base.compspec)
			check_umlauted(base.supspec)
		elseif alternant_multiword_spec.hascomp == "has" then
			check_umlauted(base.supspec)
		end
	end)
	-- NOTE: Fields `haspos`, `hascomp` and `hassup` are set by generic code that iterates over degree fields; look
	-- for `"has" .. degfield`.
	if alternant_multiword_spec.haspos == "has" then
		if alternant_multiword_spec.number.pos == "sg" or alternant_multiword_spec.number.pos == "pl" then
			-- not "both" or "none"
			insann(alternant_multiword_spec.number.pos .. "-only", " ")
		end
		if alternant_multiword_spec.state.pos == "strong" or alternant_multiword_spec.state.pos == "weak" then
			-- not "both" or "none"
			insann(alternant_multiword_spec.state.pos .. "-only", " ")
		end
		if plpos == "adjectives" then
			if alternant_multiword_spec.hascomp == "has" and alternant_multiword_spec.hassup == "has" then
				inscat("comparable adjectives")
			elseif alternant_multiword_spec.hascomp == "hasnot" and alternant_multiword_spec.hassup == "hasnot" then
				inscat("uncomparable adjectives")
			end
		end
		if alternant_multiword_spec.numcomp > 1 then
			inscat(plpos .. " with multiple comparatives")
		end
		if alternant_multiword_spec.numsup > 1 then
			inscat(plpos .. " with multiple superlatives")
		end
	elseif alternant_multiword_spec.hascomp == "has" then
		insann("comparative-only", " ")
		if plpos == "adjectives" then
			inscat("comparative-only adjectives")
		end
		if alternant_multiword_spec.numsup > 1 then
			inscat(plpos .. " with multiple superlatives")
		end
	else
		insann("superlative-only", " ")
		if plpos == "adjectives" then
			inscat("superlative-only adjectives")
		end
	end
	if #irregs > 0 then
		insann(table.concat(irregs, " // "), " ")
	end
	if umlauted_comparison then
		insann("umlauted-comp", " ")
		inscat(plpos .. " with umlauted comparative or superlative")
	end
	if #scrape_chains > 0 then
		insann(("based on %s"):format(m_table.serialCommaJoin(scrape_chains)), ", ")
		inscat(plpos .. " declined using scraped base declensions")
	end

	alternant_multiword_spec.annotation = table.concat(annparts)
	if #stemspecs > 1 then
		inscat(plpos .. " with multiple stems")
	end
	if alternant_multiword_spec.saw_unknown_comp then
		inscat(plpos .. " with unknown comparative status")
	end
	alternant_multiword_spec.categories = all_cats
end


local function show_forms(alternant_multiword_spec)
	local lemmas = {}
	for _, slot in ipairs(potential_lemma_slots) do
		if alternant_multiword_spec.forms[slot] then
			for _, formobj in ipairs(alternant_multiword_spec.forms[slot]) do
				table.insert(lemmas, formobj)
			end
			break
		end
	end
	-- Make sure it's OK to use the compressed comparative singular table; this won't be OK for e.g. [[innri]], which has
	-- an alternative oblique masculine singular [[innra]]. This must be done before calling `iut.show_forms()` because
	-- that code encodes accelerator information about the slot in question into the string, which makes comparisons fail.
	alternant_multiword_spec.use_compressed_comp_table =
		m_table.deepEquals(alternant_multiword_spec.forms.comp_wk_nom_m, alternant_multiword_spec.forms.comp_wk_obl_m) and
		m_table.deepEquals(alternant_multiword_spec.forms.comp_wk_nom_f, alternant_multiword_spec.forms.comp_wk_obl_f)
	local props = {
		lemmas = lemmas,
		lang = lang,
	}
	for _, degspec in ipairs(compsup_degrees) do
		local degfield, desc = unpack(degspec)
		if alternant_multiword_spec["has" .. degfield] == "has" then
			props.slot_list = adjective_slot_list_by_degree[degfield]
			iut.show_forms(alternant_multiword_spec.forms, props)
			alternant_multiword_spec["footnote_" .. degfield] = alternant_multiword_spec.forms.footnote
		end
	end
	-- This isn't strictly necessary but ensures that all slots including the *_linked ones get converted to strings.
	props.slot_list = adjective_slot_list_linked_slots
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
{\op}| style="min-width:MINWIDTHem" class="is-inflection-table" data-toggle-category="inflection"
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
		strong_sg = [=[
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

		strong_pl = [=[
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

		comp_weak_sg = [=[
! class="is-col-header" |
! class="is-col-header" | masculine
! class="is-col-header" | feminine
! class="is-col-header" | neuter
|-
! class="is-col-header" | singular (all-case)
| {COMPSUPwk_nom_m}
| {COMPSUPwk_nom_f}
| {COMPSUPwk_n}
]=],

		weak_sg = [=[
! class="is-col-header" | singular
! class="is-col-header" | masculine
! class="is-col-header" | feminine
! class="is-col-header" | neuter
|-
!class="is-row-header"|nominative
| {COMPSUPwk_nom_m}
| {COMPSUPwk_nom_f}
| rowspan=2 | {COMPSUPwk_n}
|-
!class="is-row-header"|acc/dat/gen
| {COMPSUPwk_obl_m}
| {COMPSUPwk_obl_f}
]=],

		weak_pl = [=[
! class="is-col-header" | plural (all-case)
| rowspan=4 colspan=3 | {COMPSUPwk_p}
]=]
}

	local function format_left_rail(state, totalrows)
		return (table_spec_left_rail:gsub("TOTALROWS", tostring(totalrows))
			:gsub("STATE", state)
			:gsub("DEFINITENESS", state == "weak" and "definite" or "indefinite"))
	end

	local function get_table_spec(slot_prefix, number, state)
		return slot_prefix == "comp_" and number == "sg" and state == "weak" and
			alternant_multiword_spec.use_compressed_comp_table and
			table_spec_parts.comp_weak_sg or table_spec_parts[state .. "_" .. number]
	end

	local function construct_table(slot_prefix, inside)
		local parts = {}
		local function ins(txt)
			table.insert(parts, txt)
		end
		ins(template_prelude())
		inside(ins)
		ins(template_postlude())
		return (table.concat(parts):gsub("COMPSUP", slot_prefix))
	end

	local function get_table_spec_one_number_one_state(slot_prefix, number, state, omit_state)
		return construct_table(slot_prefix, function(ins)
			if not omit_state then
				ins(format_left_rail(state, 5))
			end
			ins(get_table_spec(slot_prefix, number, state))
		end)
	end

	local function get_table_spec_all_number_one_state(slot_prefix, state, omit_state)
		return construct_table(slot_prefix, function(ins)
			if not omit_state then
				ins(format_left_rail(state, 10))
			end
			ins(get_table_spec(slot_prefix, "sg", state))
			ins("|-\n")
			ins(get_table_spec(slot_prefix, "pl", state))
		end)
	end

	local function get_table_spec_one_number_all_state(slot_prefix, number)
		return construct_table(slot_prefix, function(ins)
			ins(format_left_rail("strong", 5))
			ins(get_table_spec(slot_prefix, number, "strong"))
			ins("|-\n")
			ins(format_left_rail("weak", 5))
			ins(get_table_spec(slot_prefix, number, "weak"))
		end)
	end

	local function get_table_spec_all_number_all_state(slot_prefix)
		return construct_table(slot_prefix, function(ins)
			ins(format_left_rail("strong", 10))
			ins(get_table_spec(slot_prefix, "sg", "strong"))
			ins("|-\n")
			ins(get_table_spec(slot_prefix, "pl", "strong"))
			ins("|-\n")
			ins(format_left_rail("weak", 10))
			ins(get_table_spec(slot_prefix, "sg", "weak"))
			ins("|-\n")
			ins(get_table_spec(slot_prefix, "pl", "weak"))
		end)
	end

	local notes_template = [=[
<div class="is-footnote-outer-div" style="width:100%;">
<div class="is-footnote-inner-div">
{footnote}
</div></div>
]=]

	local ital_lemma = '<i lang="is" class="Latn">' .. forms.lemma .. "</i>"

	local annotation = alternant_multiword_spec.annotation
	if annotation == "" then
		forms.annotation = ""
	else
		forms.annotation = " (<span style=\"font-size: smaller;\">" .. annotation .. "</span>)"
	end

	-- Format the per-degree tables.
	local computed_tables = {}
	for _, degspec in ipairs(compsup_degrees) do
		local degfield, desc = unpack(degspec)
		local hasprop = "has" .. degfield
		local computed_table = ""
		local slot_prefix = degfield_to_slot_prefix(degfield)
		if alternant_multiword_spec[hasprop] == "has" then
			local table_spec =
				alternant_multiword_spec.state[degfield] == "bothstates" and
					alternant_multiword_spec.number[degfield] == "both" and
					get_table_spec_all_number_all_state(slot_prefix) or
				alternant_multiword_spec.number[degfield] == "both" and
					get_table_spec_all_number_one_state(slot_prefix, alternant_multiword_spec.state[degfield],
						alternant_multiword_spec.irreg) or
				alternant_multiword_spec.state[degfield] == "bothstates" and
					get_table_spec_one_number_all_state(slot_prefix, alternant_multiword_spec.number[degfield]) or
				get_table_spec_one_number_one_state(slot_prefix, alternant_multiword_spec.number[degfield],
					alternant_multiword_spec.state[degfield], alternant_multiword_spec.irreg)
			forms.title = ("%s forms of %s"):format(desc, ital_lemma)
			forms.footnote = alternant_multiword_spec["footnote_" .. degfield]
			forms.notes_clause = forms.footnote ~= "" and m_string_utilities.format(notes_template, forms) or ""
			computed_table = m_string_utilities.format(table_spec, forms)
		end
		table.insert(computed_tables, computed_table)
	end

	-- Paste them together.
	return require("Module:TemplateStyles")("Module:is-adjective/style.css") .. table.concat(computed_tables)
end

-- Externally callable function to parse and decline an adjective given user-specified arguments and the argument spec
-- `argspec` (specified because the user may give multiple such specs). Return value is ALTERNANT_MULTIWORD_SPEC, an
-- object where the declined forms are in `ALTERNANT_MULTIWORD_SPEC.forms` for each slot. If there are no values for a
-- slot, the slot key will be missing. The value for a given slot is a list of objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms(args, argspec, source_template)
	local from_headword = source_template == "is-adj"
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
	alternant_multiword_spec.pos = args.pos
	alternant_multiword_spec.source_template = source_template
	alternant_multiword_spec.number = {}
	alternant_multiword_spec.state = {}

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
		detect_all_indicator_specs(alternant_multiword_spec)
		local inflect_props = {
			skip_slot = function(slot)
				local degfield = slot_to_degfield(slot)
				return skip_slot(alternant_multiword_spec.number[degfield], alternant_multiword_spec.state[degfield],
					slot)
			end,
			slot_list = adjective_slot_list,
			inflect_word_spec = decline_adjective,
		}
		iut.inflect_multiword_or_alternant_multiword_spec(alternant_multiword_spec, inflect_props)
		local forms = alternant_multiword_spec.forms
		alternant_multiword_spec.numcomp = forms.comp_wk_nom_m and #forms.comp_wk_nom_m or 0
		local supforms = forms.sup_str_nom_m or forms.sup_wk_nom_m
		alternant_multiword_spec.numsup = supforms and #supforms or 0
		compute_categories_and_annotation(alternant_multiword_spec)
	end
	if args.json then
		return require("Module:JSON").toJSON(alternant_multiword_spec)
	end
	return alternant_multiword_spec
end


-- Entry point for {{is-adecl}}. Template-callable function to parse and decline an adjective given
-- user-specified arguments and generate a displayable table of the declined forms.
function export.show(frame)
	local parent_args = frame:getParent().args
	local params = {
		[1] = {required = true, list = true, default = "glaður<comp>"},
		deriv = {list = true},
		id = {},
		pos = {},
		title = {},
 		pagename = {},
		json = {type = "boolean"},
	}
	local args = m_para.process(parent_args, params)
	local alternant_multiword_specs = {}
	for i, argspec in ipairs(args[1]) do
		alternant_multiword_specs[i] = export.do_generate_forms(args, argspec, "is-adecl")
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
			categories = {"Icelandic scraping errors in Template:is-adecl"}
		else
			ins(make_table(alternant_multiword_spec))
			categories = alternant_multiword_spec.categories
		end
		ins(require("Module:utilities").format_categories(categories, lang, nil, nil, force_cat))
	end
	return table.concat(parts)
end


return export
