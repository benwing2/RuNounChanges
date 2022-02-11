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


local function link_term(term, face)
	return m_links.full_link({ lang = lang, term = term }, face)
end


local cases = { "nom", "gen", "dat", "acc" }
local genders = { "m", "f", "n", "p" }
local states = { "str", "wk", "mix" }
local comps = { "", "comp", "sup" }

local adjective_slot_list_positive = {
	{"the_lemma", "-"},
}
local adjective_slot_list_comparative = {
}
local adjective_slot_list_superlative = {
}
for _, comp in ipairs(comps) do
	local slot_list = comp == "" and adjective_slot_list_positive or
		comp == "comp" and adjective_slot_list_comparative or
		adjective_slot_list_superlative
	local compsup = comp ~= "" and comp .. "_" or ""
	for _, state in ipairs(states) do
		for _, case in ipairs(cases) do
			for _, gender in ipairs(genders) do
				local slot = compsup .. state .. "_" .. case .. "_" .. gender
				local accel_gender = gender == "p" and "p" or gender .. "|s"
				local accel = state .. "|" .. case .. "|" .. accel_gender .. (comp and "|" .. comp or "")
				table.insert(slot_list, {slot, accel})
			end
		end
	end
	table.insert(slot_list, {compsup .. "pred", "-"})
	for _, gender in ipairs(genders) do
		table.insert(slot_list, {compsup .. "pred_" .. gender, "-"})
	end
end

local adjective_slot_set = {}
local all_adjective_slot_list = {}
local function add_slots(slot_list)
	for _, slot_accel in ipairs(slot_list) do
		table.insert(all_adjective_slot_list, slot_accel)
		local slot, accel = unpack(slot_accel)
		if slot ~= "the_lemma" then
			adjective_slot_set[slot] = true
		end
	end
end
add_slots(adjective_slot_list_positive)
add_slots(adjective_slot_list_comparative)
add_slots(adjective_slot_list_superlative)

local function add(base, slot, stem, ending, footnotes)
	if not ending then
		return
	end
	local function do_combine_stem_ending(stem, ending)
		return stem .. ending
	end

	footnotes = iut.combine_footnotes(base.footnotes, footnotes)
	local ending_obj = iut.combine_form_and_footnotes(ending, footnotes)
	iut.add_forms(base.forms, slot, stem, ending_obj, do_combine_stem_ending)
end


local function add_cases(base, stem, prefix, gender, nom, gen, dat, acc, footnotes)
	add(base, prefix .. "_nom_" .. gender, stem, nom, footnotes)
	add(base, prefix .. "_gen_" .. gender, stem, gen, footnotes)
	add(base, prefix .. "_dat_" .. gender, stem, dat, footnotes)
	add(base, prefix .. "_acc_" .. gender, stem, acc, footnotes)
end


local function decline_plural(base, stem, compsup)
	add_cases(base, stem, compsup .. "str", "p", "e", "er", "en", "e")
	add_cases(base, stem, compsup .. "wk", "p", "en", "en", "en", "en")
	add_cases(base, stem, compsup .. "mix", "p", "en", "en", "en", "en")
end


local function decline_singular(base, stem, compsup)
	add_cases(base, stem, compsup .. "str", "m", "er", "en", "em", "en")
	add_cases(base, stem, compsup .. "wk", "m", "e", "en", "en", "en")
	add_cases(base, stem, compsup .. "mix", "m", "er", "en", "en", "en")

	add_cases(base, stem, compsup .. "str", "f", "e", "er", "er", "e")
	add_cases(base, stem, compsup .. "wk", "f", "e", "en", "en", "e")
	add_cases(base, stem, compsup .. "mix", "f", "e", "en", "en", "e")

	add_cases(base, stem, compsup .. "str", "n", "es", "en", "em", "es")
	add_cases(base, stem, compsup .. "wk", "n", "e", "en", "en", "e")
	add_cases(base, stem, compsup .. "mix", "n", "es", "en", "en", "es")
end


local function process_slot_overrides(base)
	for slot, overrides in pairs(base.overrides) do
		local origforms = base.forms[slot]
		base.forms[slot] = nil
		add_spec(base, slot, overrides, origforms)
	end
end


local function parse_indicator_spec(angle_bracket_spec, lemma, pagename)
	if lemma == "" then
		lemma = pagename
	end
	local base = {forms = {}, stems = {}, overrides = {}, props = {}}
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
			if rfind(part, "^comp:") or rfind(part, "^sup:") or rfind(part, "^stem:") then
				local spectype, rest = rmatch(part, "^(.-):(.*)$")
				if base[spectype] then
					parse_err("Can't specify value for '" .. spectype .. "' twice")
				end
				dot_separated_group[1] = rest
				base[spectype] = com.fetch_specs(iut, dot_separated_group, ":", spectype, nil, parse_err)
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


local function generate_default_stem(base)
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


local function generate_default_comp(base, stem)
	return stem .. "er"
end


local function generate_default_sup(base, stem)
	if rfind(stem, "gr[oö]ß$") then
		return stem .. "t"
	elseif rfind(stem, "[szxßd]$") or rfind(stem, "[^e]t$") then
		return stem .. "est"
	elseif base.props.omitted_e and rfind(stem, com.NV .. "[lmnr]$") then
		-- If we omitted -e- in the stem, try to put it back. E.g. [[simpel]], stem ''simpl-'', comparative
		-- ''simpler'', superlative ''simpelst-''.
		return rsub(stem, "([lmnr])$", "e%1st")
	else
		return stem .. "st"
	end
end


local function process_comp_sup_spec(base, destforms, slot, specs, form_default)
	local function do_form_default(form)
		return form_default(base, form)
	end
	specs = specs or {{form = "+"}}
	for _, spec in ipairs(specs) do
		local forms
		if spec.form == "-" then
			-- Skip "-"; effectively, no forms get inserted into output.comp.
		elseif spec.form == "+" then
			forms = iut.map_forms(base.stems.stem, do_form_default)
		elseif rfind(spec.form, "^%+") then
			local ending = rsub(spec.form, "^%+", "")
			forms = iut.map_forms(base.stems.stem, function(form) return form .. ending end)
		elseif spec.form == "^" then
			forms = iut.map_forms(base.stems.stem, function(form) return do_form_default(com.apply_umlaut(form)) end)
		elseif rfind(spec.form, "^%^") then
			local ending = rsub(spec.form, "^%^", "")
			forms = iut.map_forms(base.stems.stem, function(form) return com.apply_umlaut(form) .. ending end)
		else
			iut.insert_form(destforms, slot, spec)
		end
		if forms then
			forms = iut.convert_to_general_list_form(forms, spec.footnotes)
			iut.insert_forms(destforms, slot, forms)
		end
	end
end


local function detect_indicator_spec(alternant_multiword_spec, base)
	-- First generate the stem(s), substituting + with the default formed from the lemma.
	local stems = base.stem or {{form = "+"}}
	stems = iut.map_forms(stems, function(form)
		if form == "+" then
			return generate_default_stem(base)
		else
			return form
		end
	end)
	iut.insert_forms(base.stems, "stem", stems)

	-- Next process the superative, if specified. We do this first so that if there is a superative and no
	-- comparative specified, we add a comparative; but if sup:- is given, we don't add a comparative.
	if base.sup then
		process_comp_sup_spec(base, base.stems, "sup", base.sup, generate_default_sup)
		if base.stems.sup and not base.comp then
			base.comp = {{form = "+"}}
		end
	end
	-- Next process the comparative, if specified (or defaulted because a superlative was specified).
	if base.comp then
		process_comp_sup_spec(base, base.stems, "comp", base.comp, generate_default_comp)
	end
	-- Next, if comparative specified but not superlative, derive the superlative(s) from the comparative(s).
	if base.stems.comp and not base.sup then
		local sups = iut.map_forms(base.stems.comp, function(form)
			if not rfind(form, "er$") then
				error("Don't know how to derive superlative from comparative '" .. form .. "' because it doesn't end in -er; specify the superlative explicitly using sup:...")
			end
			return generate_default_sup(base, rsub(form, "er$", ""))
		end)
		iut.insert_forms(base.stems, "sup", sups)
	end

	-- Make sure all alternants agree in having a comparative and/or superlative.
	local has_comp = not not base.stems.comp
	if alternant_multiword_spec.props.has_comp == nil then
		alternant_multiword_spec.props.has_comp = has_comp
	elseif alternant_multiword_spec.props.has_comp ~= has_comp then
		error("If one alternant has a comparative, all must")
	end

	local has_sup = not not base.stems.sup
	if alternant_multiword_spec.props.has_sup == nil then
		alternant_multiword_spec.props.has_sup = has_sup
	elseif alternant_multiword_spec.props.has_sup ~= has_sup then
		error("If one alternant has a superlative, all must")
	end
end


local function detect_all_indicator_specs(alternant_multiword_spec)
	iut.map_word_specs(alternant_multiword_spec, function(base)
		detect_indicator_spec(alternant_multiword_spec, base)
	end)
end


local function decline_adjective(base)
	decline_singular(base, base.stems.stem, "")
	decline_plural(base, base.stems.stem, "")
	if base.stems.comp then
		decline_singular(base, base.stems.comp, "comp_")
		decline_plural(base, base.stems.comp, "comp_")
	end
	if base.stems.sup then
		decline_singular(base, base.stems.sup, "sup_")
		decline_plural(base, base.stems.sup, "sup_")
	end
	add(base, "the_lemma", base.orig_lemma, "")
	add(base, "pred", base.lemma, "")
	if base.stems.comp then
		add(base, "comp_pred", base.stems.comp, "")
	end
	if base.stems.sup then
		add(base, "sup_pred", iut.map_forms(base.stems.sup, function(form)
			if not rfind(form, "[%[%]]") then
				form = "[[" .. form .. "en]]"
			elseif rfind(form, "%]%]$") then
				form = rsub(form, "%]%]$", "en]]")
			else
				form = form .. "en"
			end
			return "[[am]] " .. form
		end), "")
	end
	process_slot_overrides(base)
end


-- Compute the categories to add the adjective to, as well as the annotation to display in the
-- declension title bar. We combine the code to do these functions as both categories and
-- title bar contain similar information.
local function compute_categories_and_annotation(alternant_multiword_spec)
	alternant_multiword_spec.categories = {}
	local function insert(cattype)
		cattype = rsub(cattype, "~", alternant_multiword_spec.pos)
		m_table.insertIfNot(alternant_multiword_spec.categories, "German " .. cattype)
	end
	local annotation
	local annparts = {}
	if not alternant_multiword_spec.props.has_comp then
		table.insert(annparts, "uncomparable")
		insert("uncomparable ~")
	end
	if not alternant_multiword_spec.forms.pred then
		table.insert(annparts, "no predicate")
		insert("~ without predicate")
	end
	alternant_multiword_spec.annotation = table.concat(annparts, ", ")
end


local function show_forms(alternant_multiword_spec)
	local lemmas = alternant_multiword_spec.forms.the_lemma or {}

	local function add_pronouns_and_articles(slot, link)
		if slot == "pred_m" then
			return link_term("[[er]] [[ist]]") .. " " .. link
		elseif slot == "pred_f" then
			return link_term("[[sie]] [[ist]]") .. " " .. link
		elseif slot == "pred_n" then
			return link_term("[[es]] [[ist]]") .. " " .. link
		elseif slot == "pred_p" then
			return link_term("[[sie]] [[sind]]") .. " " .. link
		elseif rfind(slot, "wk_") then
			local case, gender = rmatch(slot, ".*wk_(.*)_([mfnp])$")
			return link_term(com.articles[gender]["def_" .. case]) .. " " .. link
		elseif rfind(slot, "mix_") then
			local case, gender = rmatch(slot, ".*mix_(.*)_([mfnp])$")
			return link_term(com.articles[gender]["ind_" .. case]) .. " " .. link
		else
			return link
		end
	end

	local function join_spans(slot, spans)
		return table.concat(spans, "<br />")
	end

	local function copy_predicate_forms(compsup)
		for _, gender in ipairs(genders) do
			alternant_multiword_spec.forms[compsup .. "pred_" .. gender] = alternant_multiword_spec.forms[compsup .. "pred"]
		end
	end
	copy_predicate_forms("")
	copy_predicate_forms("comp_")
	copy_predicate_forms("sup_")

	local props = {
		lang = lang,
		lemmas = lemmas,
		transform_link = add_pronouns_and_articles,
		join_spans = join_spans,
	}
	props.slot_list = adjective_slot_list_positive
	iut.show_forms(alternant_multiword_spec.forms, props)
	alternant_multiword_spec.footnote_positive = alternant_multiword_spec.forms.footnote
	if alternant_multiword_spec.props.has_comp then
		props.slot_list = adjective_slot_list_comparative
		iut.show_forms(alternant_multiword_spec.forms, props)
		alternant_multiword_spec.footnote_comparative = alternant_multiword_spec.forms.footnote
	end
	if alternant_multiword_spec.props.has_sup then
		props.slot_list = adjective_slot_list_superlative
		iut.show_forms(alternant_multiword_spec.forms, props)
		alternant_multiword_spec.footnote_superlative = alternant_multiword_spec.forms.footnote
	end
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
| {COMPSUPpred_m}
| {COMPSUPpred_f}
| {COMPSUPpred_n}
| {COMPSUPpred_p}
|-
! rowspan="4" style="background:#c0cfe4" | strong declension <br/> (without article)
! style="background:#c0cfe4" | nominative
| {COMPSUPstr_nom_m}
| {COMPSUPstr_nom_f}
| {COMPSUPstr_nom_n}
| {COMPSUPstr_nom_p}
|-
! style="background:#c0cfe4" | genitive
| {COMPSUPstr_gen_m}
| {COMPSUPstr_gen_f}
| {COMPSUPstr_gen_n}
| {COMPSUPstr_gen_p}
|-
! style="background:#c0cfe4" | dative
| {COMPSUPstr_dat_m}
| {COMPSUPstr_dat_f}
| {COMPSUPstr_dat_n}
| {COMPSUPstr_dat_p}
|-
! style="background:#c0cfe4" | accusative
| {COMPSUPstr_acc_m}
| {COMPSUPstr_acc_f}
| {COMPSUPstr_acc_n}
| {COMPSUPstr_acc_p}
|-
! rowspan="4" style="background:#c0e4c0" | weak declension <br/> (with definite article)
! style="background:#c0e4c0" | nominative
| {COMPSUPwk_nom_m}
| {COMPSUPwk_nom_f}
| {COMPSUPwk_nom_n}
| {COMPSUPwk_nom_p}
|-
! style="background:#c0e4c0" | genitive
| {COMPSUPwk_gen_m}
| {COMPSUPwk_gen_f}
| {COMPSUPwk_gen_n}
| {COMPSUPwk_gen_p}
|-
! style="background:#c0e4c0" | dative
| {COMPSUPwk_dat_m}
| {COMPSUPwk_dat_f}
| {COMPSUPwk_dat_n}
| {COMPSUPwk_dat_p}
|-
! style="background:#c0e4c0" | accusative
| {COMPSUPwk_acc_m}
| {COMPSUPwk_acc_f}
| {COMPSUPwk_acc_n}
| {COMPSUPwk_acc_p}
|-
! rowspan="4" style="background:#e4d4c0" | mixed declension <br/> (with indefinite article)
! style="background:#e4d4c0" | nominative
| {COMPSUPmix_nom_m}
| {COMPSUPmix_nom_f}
| {COMPSUPmix_nom_n}
| {COMPSUPmix_nom_p}
|-
! style="background:#e4d4c0" | genitive
| {COMPSUPmix_gen_m}
| {COMPSUPmix_gen_f}
| {COMPSUPmix_gen_n}
| {COMPSUPmix_gen_p}
|-
! style="background:#e4d4c0" | dative
| {COMPSUPmix_dat_m}
| {COMPSUPmix_dat_f}
| {COMPSUPmix_dat_n}
| {COMPSUPmix_dat_p}
|-
! style="background:#e4d4c0" | accusative
| {COMPSUPmix_acc_m}
| {COMPSUPmix_acc_f}
| {COMPSUPmix_acc_n}
| {COMPSUPmix_acc_p}
|{\cl}{notes_clause}</div></div>]=]

	local notes_template = [===[
<div style="width:100%;text-align:left;background:#d9ebff">
<div style="display:inline-block;text-align:left;padding-left:1em;padding-right:1em">
{footnote}
</div></div>
]===]

	local ital_lemma = '<i lang="de" class="Latn">' .. forms.lemma .. "</i>"

	local annotation = alternant_multiword_spec.annotation
	if annotation == "" then
		forms.annotation = ""
	else
		forms.annotation = " (<span style=\"font-size: smaller;\">" .. annotation .. "</span>)"
	end

	-- Format the positive table.
	local positive_table_spec = rsub(table_spec, "COMPSUP", "")
	forms.title = "Positive forms of " .. ital_lemma
	forms.footnote = alternant_multiword_spec.footnote_positive
	forms.notes_clause = forms.footnote ~= "" and m_string_utilities.format(notes_template, forms) or ""
	local positive_table = m_string_utilities.format(positive_table_spec, forms)

	-- Maybe format the comparative table.
	local comparative_table = ""
	if alternant_multiword_spec.props.has_comp then
		local comparative_table_spec = rsub(table_spec, "COMPSUP", "comp_")
		forms.title = "Comparative forms of " .. ital_lemma
		forms.footnote = alternant_multiword_spec.footnote_comparative
		forms.notes_clause = forms.footnote ~= "" and m_string_utilities.format(notes_template, forms) or ""
		comparative_table = m_string_utilities.format(comparative_table_spec, forms)
	end

	-- Maybe format the superlative table.
	local superlative_table = ""
	if alternant_multiword_spec.props.has_comp then
		local superlative_table_spec = rsub(table_spec, "COMPSUP", "sup_")
		forms.title = "Superlative forms of " .. ital_lemma
		forms.footnote = alternant_multiword_spec.footnote_superlative
		forms.notes_clause = forms.footnote ~= "" and m_string_utilities.format(notes_template, forms) or ""
		superlative_table = m_string_utilities.format(superlative_table_spec, forms)
	end

	-- Paste them together.
	return positive_table .. comparative_table .. superlative_table
end


-- Externally callable function to parse and decline a noun given user-specified arguments.
-- Return value is ALTERNANT_MULTIWORD_SPEC, an object where the declined forms are in `ALTERNANT_MULTIWORD_SPEC.forms`
-- for each slot. If there are no values for a slot, the slot key will be missing. The value for a given slot is a
-- list of objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms(parent_args, pos, from_headword, def)
	local params = {
		[1] = {},
		pagename = {},
	}
	if from_headword or pretend_from_headword then
		params["head"] = {list = true}
		params["id"] = {}
		params["sort"] = {}
		params["splithyph"] = {type = "boolean"}
	end

	local args = require("Module:parameters").process(parent_args, params)

	if not args[1] then
		if mw.title.getCurrentTitle().text == "de-adecl" then
			args[1] = def or "lang<comp:^>"
		else
			args[1] = ""
		end
	end
	local arg1 = args[1]
	local need_surrounding_angle_brackets = true
	-- Check whether we need to add <...> around the argument. If the
	-- argument has no < in it, we definitely do. Otherwise, we need to
	-- parse the balanced [...] and <...> and add <...> only if there isn't
	-- a top-level <...>. We check for [...] because there might be angle
	-- brackets inside of them (HTML tags in qualifiers or <<name:...>> and
	-- such in references).
	if arg1:find("<") then
		local segments = iut.parse_multi_delimiter_balanced_segment_run(arg1, {{"<", ">"}, {"[", "]"}})
		for i = 2, #segments, 2 do
			if segments[i]:find("^<.*>$") then
				need_surrounding_angle_brackets = false
				break
			end
		end
	end
	if need_surrounding_angle_brackets then
		arg1 = "<" .. arg1 .. ">"
	end

	local function do_parse_indicator_spec(angle_bracket_spec, lemma)
		local pagename = args.pagename or mw.title.getCurrentTitle().text
		return parse_indicator_spec(angle_bracket_spec, lemma, pagename)
	end

	local parse_props = {
		parse_indicator_spec = do_parse_indicator_spec,
		allow_default_indicator = true,
		allow_blank_lemma = true,
	}
	local alternant_multiword_spec = iut.parse_inflected_text(arg1, parse_props)
	alternant_multiword_spec.pos = pos or "adjectives"
	alternant_multiword_spec.forms = {}
	alternant_multiword_spec.props = {}
	detect_all_indicator_specs(alternant_multiword_spec)
	local inflect_props = {
		lang = lang,
		skip_slot = function(slot)
			return false
		end,
		slot_list = all_adjective_slot_list,
		inflect_word_spec = decline_adjective,
	}
	iut.inflect_multiword_or_alternant_multiword_spec(alternant_multiword_spec, inflect_props)
	compute_categories_and_annotation(alternant_multiword_spec)
	return alternant_multiword_spec
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


-- Concatenate all forms of all slots into a single string of the form "SLOT=FORM,FORM,...|SLOT=FORM,FORM,...|...".
-- Embedded pipe symbols (as might occur in embedded links) are converted to <!>. If INCLUDE_PROPS is given, also
-- include additional properties (currently, none). This is for use by bots.
local function concat_forms(alternant_spec, include_props)
	local ins_text = {}
	for _, slotaccel in pairs(adjective_slot_list) do
		local slot, accel = unpack(slotaccel)
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
