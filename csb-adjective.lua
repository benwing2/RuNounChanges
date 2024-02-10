local export = {}


--[=[

Authorship: Ben Wing <benwing2>

]=]

--[=[

TERMINOLOGY:

-- "slot" = A particular combination of case/gender/number.
	 Example slot names for adjectives are "gen_f" (genitive feminine singular) and
	 "nom_mp_pers" (nominative masculine personal plural). Each slot is filled with zero or more forms.

-- "form" = The declined Kashubian form representing the value of a given slot.

-- "lemma" = The dictionary form of a given Kashubian term. Generally the nominative
     masculine singular, but may occasionally be another form if the nominative
	 masculine singular is missing.
]=]

local lang = require("Module:languages").getByCode("csb")
local m_links = require("Module:links")
local m_table = require("Module:table")
local m_string_utilities = require("Module:string utilities")
local iut = require("Module:inflection utilities")

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


-- All slots that are used by any of the different tables. The key is the slot and the value is a list of the tables
-- that use the slot. "regular" = regular, "plonly" = indicator 'plonly', "dva" = [[dwa]] and [[òba]].
local input_adjective_slots = {
	nom_m = {"regular"},
	nom_f = {"regular"},
	nom_n = {"regular"},
	nom_mp_pers = {"regular", "dva", "plonly"},
	nom_p_not_mp_pers = {"regular", "plonly"},
	nom_mp_npers = {"dva"},
	nom_fp = {"dva"},
	nom_np = {"dva"},
	gen_mn = {"regular"},
	gen_f = {"regular"},
	gen_p = {"regular", "plonly", "dva"},
	dat_mn = {"regular"},
	dat_f = {"regular"},
	dat_p = {"regular", "plonly", "dva"},
	acc_m_an = {"regular"},
	acc_m_in = {"regular"},
	acc_f = {"regular"},
	acc_n = {"regular"},
	acc_mp_pers = {"regular", "dva", "plonly"},
	acc_p_not_mp_pers = {"regular", "plonly"},
	acc_mp_npers = {"dva"},
	acc_fp = {"dva"},
	acc_np = {"dva"},
	ins_mn = {"regular"},
	ins_f = {"regular"},
	ins_p = {"regular", "plonly", "dva"},
	loc_mn = {"regular"},
	loc_f = {"regular"},
	loc_p = {"regular", "plonly", "dva"},
	short = {"regular"},
}


local output_adjective_slots = {
	nom_m = "nom|m|s",
	nom_m_linked = "nom|m|s", -- used in [[Module:csb-noun]]?
	nom_f = "nom|f|s",
	nom_n = "nom|n|s",
	nom_mp_pers = "pr|nom|m|p",
	nom_mp_pers_linked = "pr|nom|m|p", -- used in [[Module:csb-noun]]?
	nom_p_not_mp_pers = "np|nom|p",
	nom_mp_npers = "np|nom|m|p",
	nom_mp_npers_linked = "pr|nom|m|p", -- used in [[Module:csb-noun]]?
	nom_fp = "nom|f|p",
	nom_np = "nom|n|p",
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
	acc_mp_pers = "pr|acc|m|p",
	acc_p_not_mp_pers = "np|acc|p",
	acc_mp_npers = "np|acc|m|p",
	acc_fp = "acc|f|p",
	acc_np = "acc|n|p",
	ins_mn = "ins|m//n|s",
	ins_f = "ins|f|s",
	ins_p = "ins|p",
	loc_mn = "loc|m//n|s",
	loc_f = "loc|f|s",
	loc_p = "loc|p",
	short = "short",
}


local potential_lemma_slots = {"nom_m", "nom_mp_npers", "nom_mp_pers"}


local function get_output_adjective_slots(alternant_multiword_spec)
	return output_adjective_slots
end


local function combine_stem_ending(stem, ending)
	if stem == "?" then
		return "?"
	else
		return stem .. ending
	end
end


local function add(base, slot, stems, endings, footnote)
	if stems then
		stems = iut.combine_form_and_footnotes(stems, footnote)
	end
	iut.add_forms(base.forms, slot, stems, endings, combine_stem_ending)
end


local function add_normal_decl(base, stems,
	nom_m, nom_f, nom_n, nom_mp_pers, nom_p_not_mp_pers,
	gen_mn, gen_f, gen_p,
	dat_mn, dat_f, dat_p,
	acc_f,
	ins_mn, ins_f, ins_p,
	loc_mn, loc_f, loc_p,
	footnote)
	if stems then
		stems = iut.combine_form_and_footnotes(stems, footnote)
	end
	add(base, "nom_m", stems, nom_m)
	add(base, "nom_f", stems, nom_f)
	add(base, "nom_n", stems, nom_n)
	add(base, "nom_mp_pers", stems, nom_mp_pers)
	add(base, "nom_p_not_mp_pers", stems, nom_p_not_mp_pers)
	add(base, "gen_mn", stems, gen_mn)
	add(base, "gen_f", stems, gen_f)
	add(base, "gen_p", stems, gen_p)
	add(base, "dat_mn", stems, dat_mn)
	add(base, "dat_f", stems, dat_f)
	add(base, "dat_p", stems, dat_p)
	add(base, "acc_f", stems, acc_f)
	add(base, "ins_mn", stems, ins_mn)
	add(base, "ins_f", stems, ins_f)
	add(base, "ins_p", stems, ins_p)
	add(base, "loc_mn", stems, loc_mn)
	add(base, "loc_f", stems, loc_f)
	add(base, "loc_p", stems, loc_p)
end

local function add_normal_oblique_hard_y_decl(base, stem)
	add_normal_decl(base, stem,
		nil, "ô", "é", "y", "é",
		"égò", "y", "ëch",
		"émù", "y", "ym",
		"ą",
		"ym", "ą", "yma",
		"ym", "y", "ëch"
	)
end

local decls = {}

local function stem_is_soft(stem)
	return rfind(stem, "[ńż]$") or rfind(stem, "[cs]z$")
end

decls["normal"] = function(base)
	local stem, suffix

	-- hard in -y
	stem, suffix = rmatch(base.lemma, "^(.*)(y)$")
	if stem then
		add_normal_decl(base, stem, "y")
		add_normal_oblique_hard_y_decl(base, stem)
		return
	end

	-- hard or soft in -i
	stem, suffix = rmatch(base.lemma, "^(.*)(i)$")
	if stem then
		local soft = stem_is_soft(stem)
		if base.unsoften then
			hard_stem = rsub(rsub(stem, "cz$", "k"), "dż$", "g")
		else
			hard_stem = stem
		end
		-- Because there may be two stems, do them separately.
		add_normal_decl(base, stem,
			"i", nil, "é", "i", "é",
			"égò", "i", soft and "ich" or "ëch",
			"émù", "i", "im",
			nil,
			"im", nil, "ima",
			"im", "i", soft and "ich" or "ëch"
		)
		add_normal_decl(base, hard_stem,
			nil, "ô", nil, nil, nil,
			nil, nil, nil,
			nil, nil, nil,
			"ą",
			nil, "ą", nil,
			nil, nil, nil
		)
		return
	end

	-- possessive in -ův
	stem, suffix = rmatch(base.lemma, "^(.*)(ów)$")
	if stem then
		add_normal_decl(base, stem,
			"ów", "owa", {"owò", "owé"}, "owi", "owé",
			"owégò", "owi", "owëch",
			"owémù", "owi", "owim",
			"ową",
			"owim", "ową", "owima",
			"owim", "owi", "owëch"
		)
		return
	end

	-- possessive in -in
	stem, suffix = rmatch(base.lemma, "^(.*)(in)$")
	if stem then
		add_normal_decl(base, stem, "in", nil, "ino")
		add_normal_oblique_hard_y_decl(base, stem .. "in")
		return
	end

	error("Unrecognized adjective lemma, should end in '-y', '-i', '-ów' or '-in': '" .. base.lemma .. "'")
end


decls["irreg"] = function(base)
	local lemma = base.lemma

	if lemma == "dwa" or lemma == "òba" then
		for _, slot_value in ipairs {
			{"nom_mp_pers", {"aj", "aji"}},
			{"nom_mp_npers", "a"},
			{"nom_fp", "ie"},
			{"nom_np", "a"},
			{"gen_p", "ùch"},
			{"dat_p", {"ùma", "ùm"}},
			{"ins_p", "ùm"},
			{"loc_p", "ùch"},
		} do
			local slot, value = unpack(slot_value)
			add(base, slot, lemma == "dwa" and "dw" or "òb", value)
		end
		return
	end

	local stem = lemma:match("^([st]w)ój$")
	if not stem then
		stem = lemma:match("^(m)ój$")
	end
	if stem then
		add_normal_decl(base, stem,
			"ój", "òja", "òje", "òji", "òje",
			"òjégò", "òji", "òjich",
			"òjémù", "òji", "òjim",
			"òjã",
			"òjim", "òją", "òjima",
			"òjim", "òji", "òjich"
		)
		add_normal_decl(base, stem,
			nil, "a", nil, nil, nil,
			"égò", "i", {"ich", "ëch"},
			"émù", "i", "im",
			"ã",
			"im", "ą", "ima",
			"im", "i", {"ich", "ëch"},
			"[rare]"
		)
		return
	end

	local stem1, stem2
	if lemma == "naj" or lemma == "naji" or lemma == "nasz" then
		stem1 = "naj"
		stem2 = "nasz"
	elseif lemma == "waj" or lemma == "waji" or lemma == "wasz" then
		stem1 = "waj"
		stem2 = "wasz"
	elseif lemma == "Wasz" then
		stem2 = "Wasz"
	end
	local function add_plural_pron_endings(stem)
		add_normal_decl(base, stem,
			"", "a", "e", "i", "e",
			"égò", "i", "ich",
			"émù", "i", "im",
			"ã",
			"im", "ą", "ima",
			"im", "i", "ich"
		)
	end
	if stem1 then
		add_plural_pron_endings(stem1)
		add_normal_decl(base, stem1, "i")
	end
	if stem2 then
		add_plural_pron_endings(stem2)
		return
	end

	stem = lemma:match("^(jed)en$")
	if stem then
		add_normal_decl(base, stem, "en")
		add_normal_decl(base, stem .. "n",
			nil, "a", "o", "y", "e",
			"égò", "y", "ëch",
			"émù", "y", "ym",
			"ã",
			"ym", "ą", "yma",
			"ym", "y", "ëch"
		)
		return
	end

	stem = lemma:match("^(.*)en$")
	if stem then
		add_normal_decl(base, stem, "en")
		add_normal_oblique_hard_y_decl(base, stem .. "n")
		return
	end

	stem = lemma:match("^(.*)ek$")
	if stem then
		-- Because there may be two stems, do them separately.
		add_normal_decl(base, stem,
			"ek", "kô", "czé", "cë", "czé",
			"czégò", "czi", "czich",
			"czémù", "czi", "czim",
			"ką",
			"czim", "ką", "czima",
			"czim", "czi", "czich"
		)
		return
	end

	error(("Unrecognized irregular lemma '%s'"):format(lemma))
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


--[=[
Parse a single override spec (e.g. 'ins_mn:autodráhou:autodrahou[rare]' or 'gen_p+loc_p:čobotyx') and return two values:
the slot(s) the override applies to, and an object describing the override spec. The input is actually a list where the
footnotes have been separated out; for example, given the spec 'ins_p:čobotami:čobotámi[rare]:čobitmi[archaic]', the
input will be a list {"ins_p:čobotami:čobotámi", "[rare]", ":čobitmi", "[archaic]", ""}. The object returned for
'ins_mn:autodráhou:autodrahou[rare]' looks like this:

{
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
]=]
local function parse_override(segments)
	local retval = {values = {}}
	local slots = {}
	local colon_separated_groups = iut.split_alternating_runs_and_strip_spaces(segments, ":")
	for i, colon_separated_group in ipairs(colon_separated_groups) do
		if i == 1 then
			if #colon_separated_group > 1 then
				error(("Footnotes not allowed after slot name: '%s'"):format(table.concat(segments)))
			end
			local slotspec = colon_separated_group[1]
			for _, slot in ipairs(rsplit(slotspec, "%+")) do
				if not input_adjective_slots[slot] then
					error(("Unrecognized slot '%s': '%s'"):format(slot, table.concat(segments)))
				end
				table.insert(slots, slot)
			end
		else
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
	end
	return slots, retval
end


local function parse_indicator_spec(angle_bracket_spec)
	local inside = rmatch(angle_bracket_spec, "^<(.*)>$")
	assert(inside)
	local base = {overrides = {}, forms = {}}
	if inside ~= "" then
		local segments = iut.parse_balanced_segment_run(inside, "[", "]")
		local dot_separated_groups = iut.split_alternating_runs_and_strip_spaces(segments, "%.")
		for i, dot_separated_group in ipairs(dot_separated_groups) do
			local part = dot_separated_group[1]
			if rfind(part, ":") then
				local slots, override = parse_override(dot_separated_group)
				for _, slot in ipairs(slots) do
					if base.overrides[slot] then
						error(("Two overrides specified for slot '%s'"):format(slot))
					else
						base.overrides[slot] = {override}
					end
				end
			elseif part == "unsoften" or part == "irreg" or part == "dva" or part == "plonly" then
				if #dot_separated_group > 1 then
					error("Footnotes only allowed with slot overrides or by themselves: '" ..
						table.concat(dot_separated_group) .. "'")
				end
				if base[part] then
					error("Can't specify '" .. part .. "' twice: '" .. inside .. "'")
				end
				base[part] = true
			elseif part == "" then
				if #dot_separated_group == 1 then
					error("Blank indicator: '" .. inside .. "'")
				end
				base.footnotes = fetch_footnotes(dot_separated_group)
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


local function detect_indicator_spec(base)
	if base.irreg then
		base.decl = "irreg"
		if base.lemma == "dwa" or base.lemma == "òba" then
			base.dva = true
		end
	else
		base.decl = "normal"
	end
	if base.unsoften and not base.lemma:find("czi$") and not base.lemma:find("dżi") then
		error(("Indicator 'unsoften' can only be specified with lemmas ending in -czi or -dżi, but saw '%s'")
			:format(base.lemma))
	end
end


local function detect_all_indicator_specs(alternant_multiword_spec)
	iut.map_word_specs(alternant_multiword_spec, function(base)
		detect_indicator_spec(base)
		local special = base.plonly and "plonly" or base.dva and "dva" or "regular"
		if alternant_multiword_spec.special == nil then
			alternant_multiword_spec.special = special
		elseif alternant_multiword_spec.special ~= special then
			-- We do this because we have a special table with its own slots for each of these special variants.
			if special == "dva" then
				error("If some alternants are irregular [[dva]] or [[òba]], all must be")
			elseif special == "plonly" then
				error("If some alternants use indicator 'plonly', all must")
			else
				error("Can't mix regular declension with 'plonly' indicator or with irregular [[dva]] or [[òba]]")
			end
		end
	end)
end


local function process_slot_overrides(base, do_slot)
	for slot, overrides in pairs(base.overrides) do
		local special = base.plonly and "plonly" or base.dva and "dva" or "regular"
		local allowed_specials = input_adjective_slots[slot]
		if not allowed_specials then
			error(("Internal error: Encountered unrecognized slot '%s' not caught during parse_indicator_spec()"):format(
				slot))
		end
		if not m_table.contains(allowed_specials, special) then
			error(("Override specified for slot '%s' not compatible with table type '%s'"):format(slot, special))
		end
		if do_slot(slot) then
			base.slot_overridden[slot] = true
			base.forms[slot] = nil
			for _, override in ipairs(overrides) do
				for _, value in ipairs(override.values) do
					local form = value.form
					local combined_notes = iut.combine_footnotes(base.footnotes, value.footnotes)
					iut.insert_form(base.forms, slot, {form = form, footnotes = combined_notes})
				end
			end
		end
	end
end


local function handle_derived_slots_and_overrides(base)
	local function is_derived_slot(slot)
		return slot:find("^acc")
	end

	local function is_non_derived_slot(slot)
		return not is_derived_slot(slot)
	end

	base.slot_overridden = {}
	-- Handle overrides for the non-derived slots. Do this before generating the derived
	-- slots so overrides of the source slots (e.g. nom_p) propagate to the derived slots.
	process_slot_overrides(base, is_non_derived_slot)

	local function copy_if(from_slot, to_slot)
		if not base.forms[to_slot] then
			iut.insert_forms(base.forms, to_slot, base.forms[from_slot])
		end
	end

	copy_if("nom_n", "acc_n")
	copy_if("gen_mn", "acc_m_an")
	copy_if("nom_m", "acc_m_in")
	copy_if("gen_p", "acc_mp_pers")
	copy_if("nom_p_not_mp_pers", "acc_p_not_mp_pers")
	copy_if("nom_mp_npers", "acc_mp_npers")
	copy_if("nom_fp", "acc_fp")
	copy_if("nom_np", "acc_np")

	-- Handle overrides for derived slots, to allow them to be overridden.
	process_slot_overrides(base, is_derived_slot)

	-- Compute linked versions of potential lemma slots, for use in {{cs-noun}}.
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


local function decline_adjective(base)
	if not decls[base.decl] then
		error("Internal error: Unrecognized declension type '" .. base.decl .. "'")
	end
	decls[base.decl](base)
	handle_derived_slots_and_overrides(base)
end


local function get_decl_from_lemma(base)
	if base.decl == "irreg" then
		return "irregular"
	elseif rfind(base.lemma, "y$") then
		return "hard"
	elseif rfind(base.lemma, "i$") then
		local stem = rmatch(base.lemma, "^(.*)i$")
		return stem_is_soft(stem) and "soft" or "hard"
	else
		return "possessive"
	end
end


local function add_categories(alternant_multiword_spec)
	local cats = {}
	local plpos = m_string_utilities.pluralize(alternant_multiword_spec.pos or "adjective")
	local function insert(cattype)
		m_table.insertIfNot(cats, "Kashubian " .. cattype .. " " .. plpos)
	end
	iut.map_word_specs(alternant_multiword_spec, function(base)
		insert(get_decl_from_lemma(base))
		if base.overrides.short then
			table.insert(cats, "Kashubian " .. plpos .. " with short forms")
		end
	end)
	alternant_multiword_spec.categories = cats
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
		slot_table = get_output_adjective_slots(alternant_multiword_spec),
		lang = lang,
	}
	iut.show_forms(alternant_multiword_spec.forms, props)
end


local function make_table(alternant_multiword_spec)
	local forms = alternant_multiword_spec.forms

	local function template_prelude(min_width)
		return rsub([===[
<div>
<div class="NavFrame" style="display: inline-block; min-width: MINWIDTHem">
<div class="NavHead" style="background:#eff7ff">{title}{annotation}</div>
<div class="NavContent">
{\op}| border="1px solid #000000" style="border-collapse:collapse;background:#F9F9F9;text-align:center; min-width:MINWIDTHem" class="inflection-table"
|-
]===], "MINWIDTH", min_width)
	end

	local function template_postlude()
		return [=[
|{\cl}{notes_clause}</div></div></div>]=]
	end

	local table_spec_both = template_prelude("75") .. [=[
! style="background:#d9ebff" colspan=5 | singular
! style="background:#d9ebff" colspan=2 | plural
|-
! style="background:#d9ebff" |
! style="background:#d9ebff" | masculine animate
! style="background:#d9ebff" | masculine inanimate
! style="background:#d9ebff" | feminine
! style="background:#d9ebff" | neuter
! style="background:#d9ebff" | virile (= masculine personal)
! style="background:#d9ebff" | non-virile
|-
! style="background:#eff7ff" | nominative
| colspan=2 | {nom_m}
| {nom_f}
| {nom_n}
| {nom_mp_pers}
| {nom_p_not_mp_pers}
|-
! style="background:#eff7ff" | genitive
| colspan=2 | {gen_mn}
| {gen_f}
| {gen_mn}
| colspan=2 | {gen_p}
|-
! style="background:#eff7ff" | dative
| colspan=2 | {dat_mn}
| {dat_f}
| {dat_mn}
| colspan=2 | {dat_p}
|-
! style="background:#eff7ff" | accusative
| {acc_m_an}
| {acc_m_in}
| {acc_f}
| {acc_n}
| {acc_mp_pers}
| {acc_p_not_mp_pers}
|-
! style="background:#eff7ff" | instrumental
| colspan=2 | {ins_mn}
| {ins_f}
| {ins_mn}
| colspan=2 | {ins_p}
|-
! style="background:#eff7ff" | locative
| colspan=2 | {loc_mn}
| {loc_f}
| {loc_mn}
| colspan=2 | {loc_p}{short_clause}
]=] .. template_postlude()

	local table_spec_plonly = template_prelude("40") .. [=[
! style="background:#d9ebff" colspan=5 | plural
|-
! style="background:#d9ebff" | 
! style="background:#d9ebff" | virile (= masculine personal)
! style="background:#d9ebff" colspan=3 | non-virile
|-
! style="background:#eff7ff" | nominative
| {nom_mp_pers}
| colspan=3 | {nom_p_not_mp_pers}
|-
! style="background:#eff7ff" | genitive
| colspan=4 | {gen_p}
|-
! style="background:#eff7ff" | dative
| colspan=4 | {dat_p}
|-
! style="background:#eff7ff" | accusative
| {acc_mp_pers}
| colspan=3 | {acc_p_not_mp_pers}
|-
! style="background:#eff7ff" | instrumental
| colspan=4 | {ins_p}
|-
! style="background:#eff7ff" | locative
| colspan=4 | {loc_p}
]=] .. template_postlude()

	local table_spec_dva = template_prelude("55") .. [=[
! style="width:40%;background:#d9ebff" colspan="2" | 
! style="background:#d9ebff" colspan="4" | plural
|-
! style="width:40%;background:#d9ebff" colspan="2" | 
! style="background:#d9ebff" | masculine personal
! style="background:#d9ebff" | masculine nonpersonal
! style="background:#d9ebff" | feminine
! style="background:#d9ebff" | neuter
|-
! style="background:#eff7ff" colspan="2" | nominative
| {nom_mp_pers}
| {nom_mp_npers}
| {nom_fp}
| {nom_np}
|-
! style="background:#eff7ff" colspan="2" | genitive
| colspan="4" | {gen_p} 
|-
! style="background:#eff7ff" colspan="2" | dative
| colspan="4" | {dat_p} 
|-
! style="background:#eff7ff" colspan="2" | accusative
| {acc_mp_pers}
| {acc_mp_npers}
| {acc_fp}
| {acc_np}
|-
! style="background:#eff7ff" colspan="2" | instrumental
| colspan="4" | {ins_p} 
|-
! style="background:#eff7ff" colspan="2" | locative
| colspan="4" | {loc_p} 
]=] .. template_postlude()

	local short_template = [=[

|-
! style="background:#eff7ff" | short
| colspan=4 | {short}
]=]

	local notes_template = [===[
<div style="width:100%;text-align:left;background:#d9ebff">
<div style="display:inline-block;text-align:left;padding-left:1em;padding-right:1em">
{footnote}
</div></div>
]===]

	if alternant_multiword_spec.title then
		forms.title = alternant_multiword_spec.title
	else
		forms.title = 'Declension of <i lang="csb">' .. forms.lemma .. '</i>'
	end

	local ann_parts = {}
	local decls = {}
	iut.map_word_specs(alternant_multiword_spec, function(base)
		m_table.insertIfNot(decls, get_decl_from_lemma(base))
	end)
	table.insert(ann_parts, table.concat(decls, " // "))
	forms.annotation = " (" .. table.concat(ann_parts, ", ") .. ")"

	forms.notes_clause = forms.footnote ~= "" and
		m_string_utilities.format(notes_template, forms) or ""
	forms.short_clause = forms.short and forms.short ~= "—" and
		m_string_utilities.format(short_template, forms) or ""
	return m_string_utilities.format(
		alternant_multiword_spec.special == "plonly" and table_spec_plonly or
		alternant_multiword_spec.special == "dva" and table_spec_dva or
		table_spec_both, forms
	)
end

-- Externally callable function to parse and decline an adjective given user-specified arguments. Return value is
-- ALTERNANT_MULTIWORD_SPEC, an object where the declined forms are in `ALTERNANT_MULTIWORD_SPEC.forms` for each slot.
-- If there are no values for a slot, the slot key will be missing. The value for a given slot is a list of objects
-- {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms(parent_args, pos, from_headword)
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
		if SUBPAGE == "csb-adecl" then
			args[1] = "bëlny<>"
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
	local inflect_props = {
		slot_table = get_output_adjective_slots(alternant_multiword_spec),
		inflect_word_spec = decline_adjective,
	}
	iut.inflect_multiword_or_alternant_multiword_spec(alternant_multiword_spec, inflect_props)
	add_categories(alternant_multiword_spec)
	if args.json and not from_headword then
		return require("Module:JSON").toJSON(alternant_multiword_spec)
	end
	return alternant_multiword_spec
end


-- Entry point for {{csb-adecl}}. Template-callable function to parse and decline an adjective given user-specified
-- arguments and generate a displayable table of the declined forms.
function export.show(frame)
	local parent_args = frame:getParent().args
	local alternant_multiword_spec = export.do_generate_forms(parent_args)
	show_forms(alternant_multiword_spec)
	return make_table(alternant_multiword_spec) .. require("Module:utilities").format_categories(alternant_multiword_spec.categories, lang)
end


return export
