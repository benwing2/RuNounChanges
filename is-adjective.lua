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
local m_links = require("Module:links")
local m_table = require("Module:table")
local m_string_utilities = require("Module:string utilities")
local iut = require("Module:inflection utilities")
local com = require("Module:is-common")
local parse_utilities_module = "Module:parse utilities"

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


local function make_quoted_slot_list(slot_list)
	local quoted_list = {}
	for _, slot_accel in ipairs(slot_list) do
		local slot, accel = unpack(slot_list)
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
	"compstem",
	"compvstem",
	"supstem",
	"supvstem",
}

local overridable_stem_set = m_table.listToSet(overridable_stems)

local mutation_specs = {
	"umut",
	"con",
	"j",
	"v",
	"pp",
	"ppdent",
}

local mutation_spec_set = m_table.listToSet(mutation_specs)

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
	{"str_acc_np", "str|acc|m|p"},
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


local adjective_slot_set = {}
local adjective_slot_list = {}

local function add_list_slots(prefix, slot_list)
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
		table.insert(adjective_slot_list, {slot, accel})
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
add_slots("", true, true)
add_slots("comp_", false, true) -- comparatives are weak-only
add_slots("sup_", true, true)


-- Basic function to combine stem(s) and other properties with ending(s) and insert the result into the appropriate
-- slot. `base` is the object describing all the properties of the word being inflected for a single alternant (in case
-- there are multiple alternants specified using `((...))`). `slot_prefix` is either "ind_" or "def_" and is prefixed to
-- the slot value in `slot` to get the actual slot to add the resulting forms to. (`slot_prefix` is separated out
-- because the code below frequently needs to conditionalize on the value of `slot` and should not have to worry about
-- the definite and indefinite slot variants). `props` is an object containing computed stems and other information
-- (such as whether i-mutation is active). The information found in `props` cannot be stored in `base` because there may
-- be more than one set of such properties per `base` (e.g. if the user specified 'umut,uUmut' or '-j,j' or some
-- combination of these; in such a case, the caller will iterate over all possible combinations, and ultimately invoke
-- add() multiple times, one per combination). `endings` is the ending or endings added to the appropriate stem (after
-- any j or v infix) to get the form(s) to add to the slot. Its value can be a single string, a list of strings,
-- or a list of form objects (i.e. in general list form). `clitics` is the clitic or clitics to add after the endings to
-- form the actual form value inserted into definite slots; it should be nil for indefinite slots. Its format is the
-- same as for `endings`. `ending_override`, if true, indicates that the ending(s) supplied in `endings` come from a
-- user-specified override, and hence j and v infixes should not be added as they are already included in the override
-- if needed. `endings_are_full`, if true, indicates that the supplied ending(s) are actually full words and a null stem
-- should be used.
local function add(base, slot, degree, props, endings, ending_override, endings_are_full)
	if not endings then
		return
	end
	-- Call skip_slot() based on the declined number and state; if the actual number is different, we correct
	-- this in decline_adj() at the end.
	if skip_slot(degree.number, degree.state, slot) then
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
		-- Ending of "-" means the user used - to indicate there should be no form here.
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

		-- Double ^^ at the beginning indicates that the u-mutated version should apply. (Single ^ would indicate that
		-- i-mutation should apply, but it doesn't seem relevant to adjectives.)
		local explicit_umut
		ending, explicit_umut = rsubb(ending, "^%^%^", "")
		local is_vowel_ending = rfind(ending, "^" .. com.vowel_c)
		local mut_in_effect, mut_not_in_effect, mut_footnotes
		local ending_in_a = not not ending:find("^a")
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
							if 
							
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
	add_strong_decl(base, props,
		nom_f, nom_n, acc_m, acc_f,      
		dat_m, dat_f, dat_n, gen_m, gen_f, gen_n,
		nom_mp, nom_fp, nom_np, acc_mp,
		dat_p, gen_p
	)
	add_weak_decl(base, props,
		wk_nom_m, wk_nom_f, wk_n,
		wk_obl_m, wk_obl_f,
		wk_p
	)
end

local decls = {}

decls["normal"] = function(base, props)
	add_decl(base, props,
		      "^^",  "t",
		base.inn and "*" or "an", "a",
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


decls["comp"] = function(base, props)
	add_weak_decl(base, props,
		"i",  "i",   "a",
		"i",  "i",
		"i",
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
				if not adjective_slot_set[slot] then
					parse_err(("Unrecognized slot '%s' in override; expected strong slot %s; weak slot %s; " ..
						"comparative slot preceded by 'comp_'; superlative slot preceded by 'sup_'; or " ..
						"stem '%s': %s"):format(make_quoted_slot_list(strong_adjective_slots),
						make_quoted_slot_list(weak_adjective_slots), make_quoted_list(overridable_stems),
						require(parse_utilities_module).escape_wikicode(table.concat(segments))))
				end
			end
		else
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
	end
	return slots, specs
end


local function parse_inside(base, inside, is_scraped_noun)
	local function parse_err(msg)
		error((is_scraped_noun and "Error processing scraped noun spec: " or "") .. msg .. ": <" ..
			inside .. ">")
    end

	local segments = iut.parse_balanced_segment_run(inside, "[", "]")
	local dot_separated_groups = split_alternating_runs_with_escapes(segments, "%.")
	for i, dot_separated_group in ipairs(dot_separated_groups) do
		-- Parse a "mutation" spec such as "umut,uUmut[rare]". This assumes the mutation spec is contained in
		-- `dot_separated_group` (already split on brackets) and the result of parsing should go in `base[dest]`.
		-- `allowed_specs` is a list of the allowed mutation specs in this group, such as
		-- {"umut", "Umut", "uumut", "uUmut", "u_mut"} or {"pp", "-pp"}. The result of parsing is a list of structures
		-- of the form {
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
		elseif part:find("^[Uu]+_?mut") then
			parse_mutation_spec("umut", {"umut", "Umut", "uumut", "uUmut", "u_mut"})
		elseif part:find("^%-?con") then
			parse_mutation_spec("con", {"con", "-con"})
		elseif part:find("^%-?pp") then
			parse_mutation_spec("pp", {"pp", "-pp"})
		elseif part:find("^%-?j") then
			parse_mutation_spec("j", {"j", "-j"})
		elseif not part:find("^vstem") and part:find("^%-?v") then
			parse_mutation_spec("v", {"v", "-v"})
		elseif part:find("^decllemma%s*:") or part:find("^declgender%s*:") or part:find("^declnumber%s*:") then
			local field, value = part:match("^(decl[a-z]+)%s*:%s*(.+)$")
			if not value then
				parse_err(("Syntax error in decllemma/declgender/declnumber indicator: '%s'"):format(part))
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
		elseif rfind(part, ":") then
			local spec, value = part:match("^([a-z_+]+)%s*:%s*(.+)$")
			if not spec then
				parse_err(("Syntax error in indicator with value, expecting alphabetic slot or stem/lemma override indicator: '%s'"):format(part))
			end
			if overridable_stem_set[spec] then
				if base[spec] then
					if spec == "stem" then
						parse_err("Can't specify spec for 'stem:' twice (including using 'stem:' along with # or ##)")
					else
						parse_err(("Can't specify '%s:' twice"):format(spec))
					end
				end
				base[spec] = value
			else
				local slots, override = parse_override(dot_separated_group, parse_err)
				for _, slot in ipairs(slots) do
					if base.overrides[slot] then
						error(("Two overrides specified for slot '%s'"):format(slot))
					else
						base.overrides[slot] = override
					end
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
			if base.stem then
				parse_err("Can't specify a stem spec ('stem:', # or ##) twice")
			end
			base.stem = part
		elseif part == "det" or part == "num" or part == "archaic" or part == "article" or part == "indecl" or
			part == "decl?" then
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
  -- comparative and/or superlative degree objects. Multiple such objects generally happens because the user specifies
  -- multiple comparatives or superlatives (e.g. for [[fagur]], using the spec '#.comp:^:fegurri.sup:^', which specifies
  -- comparative lemmas [[fegri]] and [[fegurri]]), but occasionally the default superlative operation generates more
  -- than one superlative; e.g. for [[förull]] the spec is 'con,-con.comp:+:~~ari' which explicitly mentions two
  -- comparatives, but two superlatives are also generated because of the 'con,-con' portion of the spec. There will
  -- always be a `pos` slot filled, but if the user didn't explicitly either specify that a comparative is present or
  -- specify no comparative using '-comp', there will be no `comp` slot (likewise for `sup`). If the user specified
  -- '-comp', there will be a `comp` slot mapping to an empty list.
  degree = {
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
		-- # (= lemma) or ## (= lemma minus -ur or -r) as the value; after determine_declension(), filled in with the
		-- actual stem
		stem = "STEM",
		-- override the stem used before vowel-initial endings; after parse_indicator_spec(), either nil or a
		-- user-specified stem override in the same format as `stem`
		vstem = nil or "STEM",
		-- alternant-level footnotes, specified using `.[footnote]`, i.e. a footnote by itself; apply to all degrees
		footnotes = nil or {"FOOTNOTE", "FOOTNOTE", ...},
		-- where MUTATION_GROUP is one of "umut", "con", "pp", "j" or "v", and MUTATION_SPEC is {form = "FORM",
		-- footnotes = nil or {"FOOTNOTE", "FOOTNOTE", ...}, defaulted = BOOLEAN}, where FORM is as specified by the
		-- user (e.g. "uUmut", "-pp") or set as a default by the code (in which case `defaulted` will be set to true for
		-- mutation group "umut"); the mutation groups are as follows:
		-- * umut (u-mutation);
		-- * con (stem contraction before vowel-initial endings);
		-- * j (j-infix before vowel-initial endings not beginning with an i);
		-- * v (v-infix before vowel-initial endings);
		-- * pp (past-participle-like inflection, with -ð in the nominative/accusative neuter singular instead of -t);
		-- * ppdent (dental infix in past participles before vowel-initial endings);
		MUTATION_GROUP = {
		  MUTATION_SPEC, MUTATION_SPEC, ...
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
  -- where SLOT is the actual name of the slot, such as "str_nom_n" and OVERRIDE is a list of form objects, where a
  -- form object is {form = FORM, footnotes = FOOTNOTES} as in the `forms` table ("-" means to suppress the slot
  -- entirely)
  overrides = {
	SLOT = OVERRIDE,
	SLOT = OVERRIDE,
	...
  },
  -- misc Boolean properties:
  -- * "irreg" (an irregular term such as a number or determiner);
  props = {
	PROP = true,
	PROP = true,
    ...
  },
  decllemma = nil or "DECLLEMMA", -- decline like the specified lemma
  declnumber = nil or "DECLNUMBER", -- decline like the specified number
  declstate = nil or "DECLSTATE", -- decline like the specified state
  -- alternant-level footnotes, specified using `.[footnote]`, i.e. a footnote by itself; apply to all degrees
  footnotes = nil or {"FOOTNOTE", "FOOTNOTE", ...},
  -- ADDNOTE_SPEC is {slot_specs = {"SPEC", "SPEC", ...}, footnotes = {"FOOTNOTE", "FOOTNOTE", ...}}; SPEC is a Lua
  -- pattern matching slots (anchored on both sides) and FOOTNOTE is a footnote to add to those slots
  addnote_specs = {
	ADDNOTE_SPEC, ADDNOTE_SPEC, ...
  },
}

There is one PROPSET (property set) for each combination of mutation specs; in the lower limit, there is a single
property set. There may be more than one property set e.g. if the user specified 'umut,uUmut' or '-j,j' or some
combination of these. The properties in a given property set specify the values themselves of each mutation group, as
well as stems (derived from the mutation specs) that are used to construct the various forms and populate the slots in
`forms` with these values. The information found in the property sets cannot be stored in `base` because it depends on a
particular combination of mutation specs, of which there may be more than one (see above). The decline_adj() function
iterates over all property sets and calls the appropriate declension function on each one in turn, which adds forms to
each slot in `base.forms`, automatically deduplicating.

The properties in each property set are:
* Stems (each stem is either a string or a form object, i.e. an object with `form` and `footnotes` properties; see
  [[Module:inflection utilities]]; stems in general may be missing, i.e. nil, unless otherwise specified, and default
  to more general variants):
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
		props = {},
		addnote_specs = {},
		degrees = {pos = {{}}},
	}
end

-- Set some defaults (e.g. number and definiteness) now, because they (esp. the number) may be needed
-- below when determining how to merge scraped and user-specified properies.
local function set_early_base_defaults(base)
	if not base.props.det and not base.props.num then
		local function check_err(msg)
			error(("Lemma '%s': %s"):format(base.lemma, msg))
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
		-- and/or state by the noun that is scraping us.
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
			infltemp = "is-adecl",
			allow_empty_infl = true,
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
		copy_properties { "number", "state", "decllemma", "declnumber", "q", "header" }
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


local function expand_property_sets(degree)
	degree.prop_sets = {{}}

	-- Construct the prop sets from all combinations of mutation specs, in case any given spec has more than one
	-- possibility.
	for _, mutation_spec in ipairs(mutation_specs) do
		local specvals = degree[mutation_spec]
		-- Handle unspecified mutation specs.
		if not specvals then
			specvals = {false}
		end
		if #specvals == 1 then
			for _, prop_set in ipairs(degree.prop_sets) do
				-- Convert 'false' back to nil
				prop_set[mutation_spec] = specvals[1] or nil
			end
		else
			local new_prop_sets = {}
			for _, prop_set in ipairs(degree.prop_sets) do
				for _, specval in ipairs(specvals) do
					local new_prop_set = m_table.shallowcopy(prop_set)
					new_prop_set[mutation_spec] = specval
					table.insert(new_prop_sets, new_prop_set)
				end
			end
			degree.prop_sets = new_prop_sets
		end
	end
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
	local pos = base.degrees.pos[1]
	local default_props = {}
	-- Determine declension
	if base.props.indecl then
		pos.decl = "indecl"
		stem = pos.lemma
	elseif base.props["decl?"] then
		pos.decl = "decl?"
		stem = pos.lemma
	if not stem then
		-- There must be at least one vowel; lemmas like [[bur]] don't count.
		stem, ending = rmatch(pos.lemma, "^(.*" .. com.vowel_or_hyphen_c .. ".*)(ur)$")
		if stem then
			if pos.stem == pos.lemma then
				-- [[dapur]] "sad" etc. where the stem includes the final -r
				stem = pos.stem
				ending = "" -- not actually used
				default_props.con = "con"
				default_props.defcomp = com.apply_contraction(stem) .. "ari"
			elseif not pos.stem and (stem:find("leg$") or stem:find("ug$")) then
				-- [[fallegur]] "beautiful" and others in -legur; [[auðugur]] "rich" and others in -ugur; note that
				-- this includes words like [[lóugur]] and [[snjóugur]] with a vowel preeding the -ugur (there are no
				-- adjectives in -augur).
				default_props.defcomp = stem .. "ri"
			else
				-- [[gulur]] "yellow" and lots of others
				-- defcomp, defsup computed later
			end
		end
	end
	if not stem then
		stem, ending = rmatch(pos.lemma, "^(.*[ÁáÆæ])(r)$")
		if stem then
			if (not pos.stem or pos.stem == stem) then
				-- The default for these lemmas is to not include the -r in the stem.
				pos.double_r = true
				default_props.defcomp = stem .. "rri"
				if rfind(stem, "[Ææ]$") then
					default_props.j = "j"
					default_props.defsup = stem .. "jastur"
				else
					-- defsup computed later
				end
			else
				-- Process later on in the null-ending arm.
				stem = nil
				ending = nil
			end
		end
	end
	if not stem then
		stem, ending = rmatch(pos.lemma, "^(.*[Ýý])(r)$")
		if stem then
			if pos.stem == stem then
				-- The default for these lemmas is to include the -r in the stem. This includes lemmas like
				-- [[nýr]] "new" and [[hlýr]] "warm".
				pos.double_r = true
				default_props.j = "j"
				default_props.defcomp = stem .. "rri"
				default_props.defsup = stem .. "jastur"
			else
				-- Process later on in the null-ending arm.
				stem = nil
				ending = nil
			end
		end
	end
	if not stem then
		stem, ending = rmatch(pos.lemma, "^(.*l)(l)$")
		if stem then
			-- [[heill]] "whole; healthy", [[fúll]] "foul", [[þögull]] "taciturn" (with or without contraction), etc.
			default_props.defcomp = stem .. "li"
			-- defsup computed later, depending on the value of 'con'
		end
	end
	if not stem then
		stem, ending = rmatch(pos.lemma, "^(.*n)(n)$")
		if stem then
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
				default_props.defcomp = function(base, pos, props)
					if props.ppdent and props.ppdent.form == "ppdent" then
						-- Chop off final -in
						props.dental_stem = com.add_dental_ending(usub(stem, 1, -3))





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
		base.decl = "normal"
		base.
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


local function process_spec(base, destforms, slot, specs, base_stem, form_default)
	local function do_form_default(form)
		local retval = form_default(base, form)
		if type(retval) ~= "table" then
			retval = {retval}
		end
		return retval
	end
	specs = specs or {{form = "+"}}
	for _, spec in ipairs(specs) do
		local forms
		if spec.form == "-" then
			-- Skip "-"; effectively, no forms get inserted into output.comp.
		elseif spec.form == "+" then
			forms = iut.flatmap_forms(base_stem, do_form_default)
		elseif rfind(spec.form, "^~") then
			local ending = rsub(spec.form, "^~", "")
			forms = iut.map_forms(base_stem, function(form) return form .. ending end)
		elseif spec.form == "^" then
			forms = iut.flatmap_forms(base_stem, function(form) return do_form_default(com.apply_umlaut(form)) end)
		elseif rfind(spec.form, "^%^") then
			local ending = rsub(spec.form, "^%^", "")
			forms = iut.map_forms(base_stem, function(form) return com.apply_umlaut(form) .. ending end)
		else
			iut.insert_form(destforms, slot, spec)
		end
		if forms then
			forms = iut.convert_to_general_list_form(forms, spec.footnotes)
			iut.insert_forms(destforms, slot, forms)
		end
	end
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
	-- First generate the stem(s), substituting + with the default formed from the lemma.
	process_spec(base, base.stems, "stem", base.stem, {{form = generate_default_stem(base)}},
	   function(base, stem) return stem end)

	-- Next process the superative, if specified. We do this first so that if there is a superative and no
	-- comparative specified, we add a comparative; but if sup:- is given, we don't add a comparative.
	if base.sup then
		process_spec(base, base.stems, "sup", base.sup, base.stems.stem, generate_default_sup)
		if base.stems.sup and not base.comp then
			base.comp = {{form = "+"}}
		end
	end
	-- Next process the comparative, if specified (or defaulted because a superlative was specified).
	if base.comp then
		process_spec(base, base.stems, "comp", base.comp, base.stems.stem, generate_default_comp)
	end
	-- Next, if comparative specified but not superlative, derive the superlative(s) from the comparative(s).
	if base.stems.comp and not base.sup then
		local sups = iut.flatmap_forms(base.stems.comp, function(form)
			if not rfind(form, "er$") then
				error("Don't know how to derive superlative from comparative '" .. form .. "' because it doesn't end in -er; specify the superlative explicitly using sup:...")
			end
			local retval = generate_default_sup(base, rsub(form, "er$", ""))
			if type(retval) ~= "table" then
				retval = {retval}
			end
			return retval
		end)
		iut.insert_forms(base.stems, "sup", sups)
	end

	-- Make sure all alternants agree in having a comparative and/or superlative.
	for _, compsup in ipairs { {"comp", "has_comp", "comparative"}, {"sup", "has_sup", "superlative"} } do
		local stem, altprop, desc = unpack(compsup)
		local has_stem = not not base.stems[stem]
		if alternant_multiword_spec.props[altprop] == nil then
			alternant_multiword_spec.props[altprop] = has_stem
		elseif alternant_multiword_spec.props[altprop] ~= has_stem then
			error("If one alternant has a " .. desc .. ", all must")
		end
	end

	if base.props.predonly then
		base.props.indecl = true
	end
	if base.overrides.pred and base.overrides.pred[1].form == "-" then
		base.props.nopred = true
	end
	if base.props.predonly and base.props.nopred then
		error("Can't be both 'predonly' and 'pred:-'")
	end

	-- Make sure all alternants agree in 'state' if specified.
	local stateval = base.state or false
	if alternant_multiword_spec.state == nil then
		alternant_multiword_spec.state = stateval
	elseif alternant_multiword_spec.state ~= stateval then
		error("All alternants must agree in the value of 'state', if specified")
	end

	-- Make sure all alternants agree in various properties.
	for _, propdesc in ipairs { {"indecl"}, {"nopred", "pred:-"}, {"predonly"} } do
		local prop, desc = unpack(propdesc)
		desc = desc or prop
		local val = not not base.props[prop]
		if alternant_multiword_spec.props[prop] == nil then
			alternant_multiword_spec.props[prop] = val
		elseif alternant_multiword_spec.props[prop] ~= val then
			error("If one alternant specifies '" .. desc .. "', all must")
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
		slot_list = adjective_slot_list,
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
		slot_list = adjective_slot_list,
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
