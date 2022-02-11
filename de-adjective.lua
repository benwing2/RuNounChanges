local export = {}


--[=[

Authorship: <benwing2>

]=]

--[=[

TERMINOLOGY:

-- "slot" = A particular combination of state/case/gender/number.
	 Example slot names for adjectives are "mix_nom_m" (mixed nominative masculine singular),
	 "str_gen_p" (strong genitive plural) and "pred" (predicative). Each slot is filled with zero or more forms.

-- "form" = The declined German form representing the value of a given slot.

-- "lemma" = The dictionary form of a given German term. Generally the predicative, but may be the
     strong nominative masculine singular or other form.
]=]

local lang = require("Module:languages").getByCode("de")
local m_links = require("Module:links")
local m_table = require("Module:table")
local m_string_utilities = require("Module:string utilities")
local iut = require("Module:inflection utilities")
local com = require("Module:de-common")

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


local function tag_text(text)
	return m_script_utilities.tag_text(text, lang)
end


local cases = { "nom", "gen", "dat", "acc" }
local genders = { "m", "f", "n", "p" }
local states = { "str", "wk", "mix" }
local comps = { "", "comp", "sup" }

local adjective_slot_set = {}
local adjective_slot_list = {{"pred", "-"}}
for _, comp in ipairs(comps) do
	for _, state in ipairs(states) do
		for _, case in ipairs(cases) do
			for _, gender in ipairs(genders) do
				local slot = (comp and comp .. "_" or "") .. state .. "_" .. case .. "_" .. gender
				local accel_gender = gender == "p" and "p" or gender .. "|s"
				local accel = state .. "|" .. case .. "|" .. accel_gender .. (comp and "|" .. comp or "")
				adjective_slot_set[slot] = true
				table.insert(adjective_slot_list, {slot, accel})
			end
		end
	end
end

local adjective_slot_list_with_linked = m_table.shallowcopy(adjective_slot_list)
table.insert(adjective_slot_list_with_linked, {"pred_linked", "-"})
table.insert(adjective_slot_list_with_linked, {"str_nom_m_linked", "str|nom|m|s"})


local function add(base, slot, stem, ending, footnotes)
	if not ending then
		return
	end
	local function combine_stem_ending(stem, ending)
		if base.props.ss and stem:find("ß$") and rfind(ending, "^" .. V) then
			stem = rsub(stem, "ß$", "ss")
		end
		return stem .. ending
	end

	footnotes = iut.combine_footnotes(base.footnotes, footnotes)
	local ending_obj = iut.combine_form_and_footnotes(ending, footnotes)
	iut.add_forms(base.forms, slot, stem or base.stem, ending_obj, do_combine_stem_ending)
end


local function process_spec(endings, default, footnotes, desc, process)
	for _, ending in ipairs(endings) do
		local function sub_form(form)
			return {form = form, footnotes = ending.footnotes}
		end

		if ending.form == "-" or ending.form == "--" then
			-- do nothing
		elseif ending.form == "+" then
			if not default then
				error("Form '+' found for " .. desc .. " but no default is available")
			end
			process_spec(iut.convert_to_general_list_form(default, ending.footnotes), nil, footnotes, desc, process)
		else
			local full_eform
			if rfind(ending.form, "^" .. CAP) then
				full_eform = true
			elseif rfind(ending.form, "^!") then
				full_eform = true
				ending = sub_form(rsub(ending.form, "^!", ""))
			end
			if full_eform then
				process(ending, "")
			else
				if ending.form == "-" then
					ending = sub_form("")
				end
				process(nil, ending)
			end
		end
	end
end
	

local function add_spec(base, slot, endings, default)
	local function do_add(stem, ending)
		add(base, slot, stem, ending, footnotes)
	end
	process_spec(endings, default, footnotes, "slot '" .. slot .. "'", do_add)
end


local function add_cases(base, comp, state, gender, nom, gen, dat, acc, footnotes)
	add(base, state .. "_nom_" .. gender, nil, nom, footnotes)
	add(base, state .. "_gen_" .. gender, nil, gen, footnotes)
	add(base, state .. "_dat_" .. gender, nil, dat, footnotes)
	add(base, state .. "_acc_" .. gender, nil, acc, footnotes)
end


local function decline_plural(base, comp)
	add_cases(base, comp, "str", "p", "e", "er", "en", "e")
	add_cases(base, comp, "wk", "p", "en", "en", "en", "en")
	add_cases(base, comp, "mix", "p", "en", "en", "en", "en")
end


local function decline_singular(base, comp)
	add_cases(base, comp, "str", "m", "er", "en", "em", "en")
	add_cases(base, comp, "wk", "m", "e", "en", "en", "en")
	add_cases(base, comp, "mix", "m", "er", "en", "en", "en")

	add_cases(base, comp, "str", "f", "e", "er", "er", "e")
	add_cases(base, comp, "wk", "f", "e", "en", "en", "e")
	add_cases(base, comp, "mix", "f", "e", "en", "en", "e")

	add_cases(base, comp, "str", "n", "es", "en", "em", "es")
	add_cases(base, comp, "wk", "n", "e", "en", "en", "e")
	add_cases(base, comp, "mix", "n", "es", "en", "en", "es")
end


local function decline(base)
	decline_singular(base)
	decline_plural(base)
end


local function process_slot_overrides(base)
	for slot, overrides in pairs(base.overrides) do
		local origforms = base.forms[slot]
		base.forms[slot] = nil
		add_spec(base, slot, overrides, origforms)
	end
end


local function handle_derived_slots_and_overrides(base)
	process_slot_overrides(base)

	-- Compute linked versions of potential lemma slots, for use in {{de-noun}}.
	-- We substitute the original lemma (before removing links) for forms that
	-- are the same as the lemma, if the original lemma has links.
	for _, slot in ipairs({"nom_s", "nom_p"}) do
		iut.insert_forms(base.forms, slot .. "_linked", iut.map_forms(base.forms[slot], function(form)
			if form == base.orig_lemma_no_links and rfind(base.orig_lemma, "%[%[") then
				return base.orig_lemma
			else
				return form
			end
		end))
	end
end


local function parse_indicator_spec(angle_bracket_spec)
	if lemma == "" then
		lemma = pagename
	end
	local base = {forms = {}, overrides = {}, props = {}}
	base.orig_lemma = lemma
	base.orig_lemma_no_links = m_links.remove_links(lemma)
	base.lemma = base.orig_lemma_no_links
	local inside = rmatch(angle_bracket_spec, "^<(.*)>$")
	assert(inside)

	local function parse_err(msg)
		error(msg .. ": <" .. inside .. ">")
	end

	--[=[
	Parse a single override spec and return two values: the slot the override applies to and the override specs. The
	input is a list where the footnotes have been separated out, i.e. parse_balanced_segment_run(..., "[", "]") has
	already been called.
	]=]
	local function parse_override(segments)
		local part = segments[1]
		local slot, rest = rmatch(part, "^(.-):(.*)$")
		if not adjective_slot_set[slot] then
			parse_err("Unrecognized slot '" .. slot .. "' in override: '" .. table.concat(segments) .. "'")
		end
		segments[1] = rest
		return slot, com.fetch_specs(iut, segments, ":", "override", nil, parse_err)
	end

	if inside ~= "" then
		local segments = iut.parse_balanced_segment_run(inside, "[", "]")
		local dot_separated_groups = iut.split_alternating_runs_and_strip_spaces(segments, "%.")
		for i, dot_separated_group in ipairs(dot_separated_groups) do
			local part = dot_separated_group[1]
			if part == "comp" then
				part = "comp:+"
			end
			if rfind(part, "^comp:") or rfind(part, "^sup:") or part("^stem:") then
				local spectype, rest = rmatch(part, "^(.-):(.*)$")
				if base[spectype] then
					parse_err("Can't specify value for '" .. spectype .. "' twice")
				end
				dot_separated_group[1] = rest
				base[compsup] = com.fetch_specs(iut, dot_separated_group, spectype, nil, parse_err)
			elseif part:find(":") then
				local slot, override = parse_override(dot_separated_group)
				if base.overrides[slot] then
					parse_err("Can't specify override twice for slot '" .. slot .. "'")
				else
					base.overrides[slot] = override
				end
			elseif part == "" then
				if #dot_separated_group == 1 then
					parse_err("Blank indicator")
				end
				base.footnotes = com.fetch_footnotes(dot_separated_group, parse_err)
			elseif #dot_separated_group > 1 then
				parse_err("Footnotes only allowed with slot overrides or by themselves: '" .. table.concat(dot_separated_group) .. "'")
			elseif part == "ss" then
				if base.props.ss then
					parse_err("Can't specify 'ss' twice")
				end
				base.props.ss = true
			elseif part == "-e" then
				if base.props.omitted_e then
					parse_err("Can't specify '-e' twice")
				end
				base.props.omitted_e = true
			else
				parse_err("Unrecognized indicator '" .. part .. "'")
			end
		end
	end
	return base
end


local function generate_default_stem_from_lemma(base)
	if base.props.ss then
		if not rfind(base.lemma, "ß$") then
			error("With '.ss', lemma '" .. base.lemma .. "' should end in -ß")
		end
		return rsub(base.lemma, "ß$", "ss")
	end
	if base.props.omitted_e then
		local non_ending, ending = rmatch(base.lemma, "^(.*)e([lmnr])$")
		if not non_ending then
			error("Can't use '-e' with lemma '" .. base.lemma .. "'; lemma should end in -el, -em, -en or -er")
		end
		return non_ending .. ending
	end
	if base.lemma:find("e$") then
		return rsub(base.lemma, "e$", "")
	end
	return rsub(base.lemma, "([ai])bel$", "%1bl")
end


local function process_comparative_spec(base)
end


local function generate_superlative_stem_from_lemma(base, lemma)
	if lemma:find("e$") then
		-- träge -> trägst, müde -> müdest
		lemma = rsub(lemma, "e$", "")
	end
	if rfind(lemma, "groß$") then
		return lemma .. "t"
	elseif rfind(lemma, "[szxßd]$") or rfind(lemma, "[^e]t$") then
		return lemma .. "est"
	else
		return lemma .. "st"
	end
end


local function detect_indicator_spec(alternant_multiword_spec, base)
	base.gens = base.gens or {{form = "+"}}
	base.pls = base.pls or {{form = "+"}}
	if base.props.adj then
		synthesize_adj_lemma(base)
	end
end


local function detect_all_indicator_specs(alternant_multiword_spec)
	iut.map_word_specs(alternant_multiword_spec, function(base)
		detect_indicator_spec(alternant_multiword_spec, base)
	end)
end


local function decline_adjective(base)
	decline_singular(base)
	decline_plural(base)
	handle_derived_slots_and_overrides(base)
end


local function compute_category_and_desc(base)
	local props = declprops[base.decl]
	if props then
		return props.cat, props.desc
	end
	local ind, stem = rmatch(base.decl, "^(ind%-)(.*)$")
	if not ind then
		stem = base.decl
	end
	stem = rsub(stem, "n$", TILDE)
	if ind then
		return "independent " .. stem .. "-stem ~", "ind " .. stem .. "-stem"
	else
		return stem .. "-stem ~", stem .. "-stem"
	end
end


-- Compute the categories to add the adjective to, as well as the annotation to display in the
-- declension title bar. We combine the code to do these functions as both categories and
-- title bar contain similar information.
local function compute_categories_and_annotation(alternant_multiword_spec)
	local cats = {}
	local function insert(cattype)
		cattype = rsub(cattype, "~", alternant_multiword_spec.pos)
		m_table.insertIfNot(cats, "German " .. cattype)
	end
	local annotation
	if alternant_multiword_spec.manual then
		alternant_multiword_spec.annotation = ""
	else
		local annparts = {}
		local decldescs = {}
		iut.map_word_specs(alternant_multiword_spec, function(base)
			local cat, desc = compute_category_and_desc(base)
			insert(cat)
			m_table.insertIfNot(decldescs, desc)
			if base.phon_lemma and base.lemma ~= base.phon_lemma then
				insert("~ with phonetic respelling")
			end
		end)
		if #decldescs == 0 then
			table.insert(annparts, "indecl")
		else
			table.insert(annparts, table.concat(decldescs, " // "))
		end
		alternant_multiword_spec.annotation = table.concat(annparts, " ")
		if #decldescs > 1 then
			insert("~ with multiple declensions")
		end
	end
	alternant_multiword_spec.categories = cats
end


local function show_forms(alternant_multiword_spec)
	local lemmas = alternant_multiword_spec.forms.dir_m_s or {}
	local props = {
		lang = lang,
	}
	iut.show_forms_with_translit(alternant_multiword_spec.forms, lemmas,
		adjective_slots_with_linked, props, alternant_multiword_spec.footnotes,
		"allow footnote symbols")
end


local function make_table(alternant_multiword_spec)
	local forms = alternant_multiword_spec.forms

	local table_spec = [=[
<div class="NavFrame">
<div class="NavHead" style="text-align: left">{title}{annotation}</div>
<div class="NavContent">
{\op}| border="1px solid #cdcdcd" style="border-collapse:collapse; background:#FEFEFE; width:100%" class="inflection-table"
|-
! colspan="2" rowspan="2" style="background:#C0C0C0" | number & gender
! colspan="3" style="background:#C0C0C0" | singular
! style="background:#C0C0C0" | plural
|-
! style="background:#C0C0C0" | masculine
! style="background:#C0C0C0" | feminine
! style="background:#C0C0C0" | neuter
! style="background:#C0C0C0" | all genders
|-
! colspan="2" style="background:#EEEEB0" | predicative
| {pred_m}
| {pred_f}
| {pred_n}
| {pred_p}
|-
! rowspan="4" style="background:#c0cfe4" | strong declension <br/> (without article)
! style="background:#c0cfe4" | nominative
| {str_nom_m}
| {str_nom_f}
| {str_nom_n}
| {str_nom_p}
|-
! style="background:#c0cfe4" | genitive
| {str_gen_m}
| {str_gen_f}
| {str_gen_n}
| {str_gen_p}
|-
! style="background:#c0cfe4" | dative
| {str_dat_m}
| {str_dat_f}
| {str_dat_n}
| {str_dat_p}
|-
! style="background:#c0cfe4" | accusative
| {str_acc_m}
| {str_acc_f}
| {str_acc_n}
| {str_acc_p}
|-
! rowspan="4" style="background:#c0e4c0" | weak declension <br/> (with definite article)
! style="background:#c0e4c0" | nominative
| {wk_nom_m}
| {wk_nom_f}
| {wk_nom_n}
| {wk_nom_p}
|-
! style="background:#c0e4c0" | genitive
| {wk_gen_m}
| {wk_gen_f}
| {wk_gen_n}
| {wk_gen_p}
|-
! style="background:#c0e4c0" | dative
| {wk_dat_m}
| {wk_dat_f}
| {wk_dat_n}
| {wk_dat_p}
|-
! style="background:#c0e4c0" | accusative
| {wk_acc_m}
| {wk_acc_f}
| {wk_acc_n}
| {wk_acc_p}
|-
! rowspan="4" style="background:#e4d4c0" | mixed declension <br/> (with indefinite article)
! style="background:#e4d4c0" | nominative
| {mix_nom_m}
| {mix_nom_f}
| {mix_nom_n}
| {mix_nom_p}
|-
! style="background:#e4d4c0" | genitive
| {mix_gen_m}
| {mix_gen_f}
| {mix_gen_n}
| {mix_gen_p}
|-
! style="background:#e4d4c0" | dative
| {mix_dat_m}
| {mix_dat_f}
| {mix_dat_n}
| {mix_dat_p}
|-
! style="background:#e4d4c0" | accusative
| {mix_acc_m}
| {mix_acc_f}
| {mix_acc_n}
| {mix_acc_p}
|{\cl}{notes_clause}</div></div>]=]

	local notes_template = [===[
<div style="width:100%;text-align:left;background:#d9ebff">
<div style="display:inline-block;text-align:left;padding-left:1em;padding-right:1em">
{footnote}
</div></div>
]===]

	if alternant_multiword_spec.title then
		forms.title = alternant_multiword_spec.title
	else
		forms.title = 'Declension of <i lang="de" class="Deva">' .. forms.lemma .. '</i>'
	end

	local annotation = alternant_multiword_spec.annotation
	if annotation == "" then
		forms.annotation = ""
	else
		forms.annotation = " (<span style=\"font-size: smaller;\">" .. annotation .. "</span>)"
	end

	forms.notes_clause = forms.footnote ~= "" and
		m_string_utilities.format(notes_template, forms) or ""
	return m_string_utilities.format(table_spec, forms)
end


-- Externally callable function to parse and decline an adjective given
-- user-specified arguments. Return value is ALTERNANT_MULTIWORD_SPEC, an
-- object where the declined forms are in `ALTERNANT_MULTIWORD_SPEC.forms` for
-- each slot. If there are no values for a slot, the slot key will be missing.
-- The value for a given slot is a list of objects
-- {form=FORM, translit=TRANSLIT, footnotes=FOOTNOTES}.
function export.do_generate_forms(parent_args, pos, from_headword, def)
	local params = {
		[1] = {},
		footnote = {list = true},
		title = {},
	}
	for slot, _ in ipairs(adjective_slots) do
		params[slot] = {}
	end

	local args = m_para.process(parent_args, params)

	if not args[1] then
		if mw.title.getCurrentTitle().text == "de-adecl" then
			args[1] = def or "अच्छा"
		else
			args[1] = ""
		end
	end
	local alternant_multiword_spec = iut.parse_alternant_multiword_spec(args[1],
		parse_indicator_spec, "allow default indicator", "allow blank lemma")
	alternant_multiword_spec.title = args.title
	alternant_multiword_spec.footnotes = args.footnote
	alternant_multiword_spec.pos = pos or "adjectives"
	alternant_multiword_spec.forms = {}
	com.normalize_all_lemmas(alternant_multiword_spec, "always transliterate")
	detect_all_indicator_specs(alternant_multiword_spec)
	local decline_props = {
		lang = lang,
		skip_slot = function(slot)
			return false
		end,
		slot_table = adjective_slots_with_linked,
		decline_word_spec = decline_adjective,
	}
	iut.decline_multiword_or_alternant_multiword_spec(alternant_multiword_spec, decline_props)
	process_overrides(alternant_multiword_spec.forms, args)
	compute_categories_and_annotation(alternant_multiword_spec)
	return alternant_multiword_spec
end


-- Externally callable function to parse and decline an adjective where all
-- forms are given manually. Return value is WORD_SPEC, an object where the
-- declined forms are in `WORD_SPEC.forms` for each slot. If there are no values
-- for a slot, the slot key will be missing. The value for a given slot is a
-- list of objects {form=FORM, translit=TRANSLIT, footnotes=FOOTNOTES}.
function export.do_generate_forms_manual(parent_args, pos, from_headword, def)
	local params = {
		footnote = {list = true},
		title = {},
	}
	for slot, _ in ipairs(adjective_slots) do
		params[slot] = {}
	end

	local args = m_para.process(parent_args, params)
	local alternant_spec = {
		title = args.title,
		footnotes = args.footnote,
		forms = {},
		manual = true,
	}
	process_overrides(alternant_spec.forms, args)
	set_accusative(alternant_spec)
	add_categories(alternant_spec)
	return alternant_spec
end


-- Entry point for {{de-adecl}}. Template-callable function to parse and decline 
-- an adjective given user-specified arguments and generate a displayable table
-- of the declined forms.
function export.show(frame)
	local parent_args = frame:getParent().args
	local alternant_spec = export.do_generate_forms(parent_args)
	show_forms(alternant_spec)
	return make_table(alternant_spec) .. require("Module:utilities").format_categories(alternant_spec.categories, lang)
end


-- Entry point for {{de-adecl-manual}}. Template-callable function to parse and
-- decline an adjective given manually-specified inflections and generate a
-- displayable table of the declined forms.
function export.show_manual(frame)
	local parent_args = frame:getParent().args
	local alternant_spec = export.do_generate_forms_manual(parent_args)
	show_forms(alternant_spec)
	return make_table(alternant_spec) .. require("Module:utilities").format_categories(alternant_spec.categories, lang)
end


-- Concatenate all forms of all slots into a single string of the form
-- "SLOT=FORM,FORM,...|SLOT=FORM,FORM,...|...". Each FORM is either a string in Devanagari or
-- (if manual translit is present) a specification of the form "FORM//TRANSLIT" where FORM is the
-- Devanagari representation of the form and TRANSLIT its manual transliteration. Embedded pipe symbols
-- (as might occur in embedded links) are converted to <!>. If INCLUDE_PROPS is given, also include
-- additional properties (currently, none). This is for use by bots.
local function concat_forms(alternant_spec, include_props)
	local ins_text = {}
	for slot, _ in pairs(adjective_slots) do
		local formtext = iut.concat_forms_in_slot(alternant_spec.forms[slot])
		if formtext then
			table.insert(ins_text, slot .. "=" .. formtext)
		end
	end
	return table.concat(ins_text, "|")
end

-- Template-callable function to parse and decline an adjective given user-specified arguments and
-- return the forms as a string of the same form as documented in concat_forms() above.
function export.generate_forms(frame)
	local include_props = frame.args["include_props"]
	local parent_args = frame:getParent().args
	local alternant_spec = export.do_generate_forms(parent_args)
	return concat_forms(alternant_spec, include_props)
end


return export
