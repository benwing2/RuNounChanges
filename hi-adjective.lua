local export = {}


--[=[

Authorship: Ben Wing <benwing2>

]=]

--[=[

TERMINOLOGY:

-- "slot" = A particular combination of case/gender/number.
	 Example slot names for adjectives are "dir_m_s" (direct masculine singular) and
	 "voc_f_p" (vocative feminine plural). Each slot is filled with zero or more forms.

-- "form" = The declined Hindi form representing the value of a given slot.

-- "lemma" = The dictionary form of a given Hindi term. Generally the nominative
     masculine singular, but may occasionally be another form if the nominative
	 masculine singular is missing.
]=]

local lang = require("Module:languages").getByCode("hi")
local m_links = require("Module:links")
local m_table = require("Module:table")
local m_string_utilities = require("Module:string utilities")
local iut = require("Module:inflection utilities")
local m_para = require("Module:parameters")
local com = require("Module:User:Benwing2/hi-common")

local u = mw.ustring.char
local rsplit = mw.text.split
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rgmatch = mw.ustring.gmatch
local rsubn = mw.ustring.gsub
local ulen = mw.ustring.len
local uupper = mw.ustring.upper


-- vowel diacritics; don't display nicely on their own
local M = u(0x0901)
local N = u(0x0902)
local AA = u(0x093e)
local AAM = AA .. M
local E = u(0x0947)
local EN = E .. N
local I = u(0x093f)
local II = u(0x0940)
local IIN = II .. N
local TILDE = u(0x0303)


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


local adjective_slots = {
	dir_m_s = "dir|m|s",
	obl_m_s = "obl|m|s",
	voc_m_s = "voc|m|s",
	dir_m_p = "dir|m|p",
	obl_m_p = "obl|m|p",
	voc_m_p = "voc|m|p",
	dir_f_s = "dir|f|s",
	obl_f_s = "obl|f|s",
	voc_f_s = "voc|f|s",
	dir_f_p = "dir|f|p",
	obl_f_p = "obl|f|p",
	voc_f_p = "voc|f|p",
}

local adjective_slots_with_linked = m_table.shallowcopy(adjective_slots)
adjective_slots_with_linked["dir_m_s_linked"] = "dir|m|s"


local function add(base, stem, translit_stem, slot, ending, footnotes)
	com.add_form(base, stem, translit_stem, slot, ending, footnotes)
end


local function add_decl(base, stem, translit_stem,
	dir_m_s, obl_m_s, voc_m_s, dir_m_p, obl_m_p, voc_m_p,
	dir_f_s, obl_f_s, voc_f_s, dir_f_p, obl_f_p, voc_f_p,
	footnotes)
	assert(stem)
	add(base, stem, translit_stem, "dir_m_s", dir_m_s, footnotes)
	add(base, stem, translit_stem, "obl_m_s", obl_m_s, footnotes)
	add(base, stem, translit_stem, "voc_m_s", voc_m_s, footnotes)
	add(base, stem, translit_stem, "dir_m_p", dir_m_p, footnotes)
	add(base, stem, translit_stem, "obl_m_p", obl_m_p, footnotes)
	add(base, stem, translit_stem, "voc_m_p", voc_m_p, footnotes)
	add(base, stem, translit_stem, "dir_f_s", dir_f_s, footnotes)
	add(base, stem, translit_stem, "obl_f_s", obl_f_s, footnotes)
	add(base, stem, translit_stem, "voc_f_s", voc_f_s, footnotes)
	add(base, stem, translit_stem, "dir_f_p", dir_f_p, footnotes)
	add(base, stem, translit_stem, "obl_f_p", obl_f_p, footnotes)
	add(base, stem, translit_stem, "voc_f_p", voc_f_p, footnotes)
end


local decls = {}
local declprops = {}

decls["ā"] = function(base)
	if rfind(base.lemma, "या$") then
		local stem, translit_stem = com.strip_ending(base, "या")
		add_decl(base, stem, translit_stem, "या", "ए", "ए", "ए", "ए", "ए", "ई", "ई", "ई", "ई", "ई", "ई")
		add_decl(base, stem, translit_stem, nil, "ये", "ये", "ये", "ये", "ये", "यी", "यी", "यी", "यी", "यी", "यी")
	else
		local stem, translit_stem = com.strip_ending(base, AA)
		add_decl(base, stem, translit_stem, AA, E, E, E, E, E, II, II, II, II, II, II)
	end
end

decls["ind-ā"] = function(base)
	local stem, translit_stem = com.strip_ending(base, "आ")
	add_decl(base, stem, translit_stem, "आ", "ए", "ए", "ए", "ए", "ए", "ई", "ई", "ई", "ई", "ई", "ई")
end

decls["ān"] = function(base)
	if rfind(base.lemma, "याँ$") then
		local stem, translit_stem = com.strip_ending(base, "याँ")
		add_decl(base, stem, translit_stem, "याँ", "एँ", "एँ", "एँ", "एँ", "एँ", "ईं", "ईं", "ईं", "ईं", "ईं", "ईं")
		add_decl(base, stem, translit_stem, nil, "यें", "यें", "यें", "यें", "यें", "यीं", "यीं", "यीं", "यीं", "यीं", "यीं")
	else
		local stem, translit_stem = com.strip_ending(base, AAM)
		add_decl(base, stem, translit_stem, AAM, EN, EN, EN, EN, EN, IIN, IIN, IIN, IIN, IIN, IIN)
	end
end

decls["ind-ān"] = function(base)
	local stem, translit_stem = com.strip_ending(base, "आँ")
	add_decl(base, stem, translit_stem, "आँ", "एँ", "एँ", "एँ", "एँ", "एँ", "ईं", "ईं", "ईं", "ईं", "ईं", "ईं")
end

decls["indecl"] = function(base)
	local stem, translit_stem = base.lemma, base.lemma_translit
	add_decl(base, stem, translit_stem, "", "", "", "", "", "", "", "", "", "", "", "")
end

declprops["indecl"] = {
	desc = "indecl",
	cat = "indeclinable ~",
}


local function parse_indicator_spec(angle_bracket_spec)
	local inside = rmatch(angle_bracket_spec, "^<(.*)>$")
	assert(inside)
	local base = {forms = {}}
	if inside ~= "" then
		local parts = rsplit(inside, ".", true)
		for _, part in ipairs(parts) do
			if part == "$" then
				if base.indecl then
					error("Can't specify '$' twice: '" .. inside .. "'")
				end
				base.indecl = true
			else
				error("Unrecognized indicator '" .. part .. "': '" .. inside .. "'")
			end
		end
	end
	return base
end


local function detect_indicator_spec(base)
	if base.indecl == "$" then
		base.decl = "indecl"
	elseif rfind(base.lemma, AA .. "$") then
		base.decl = "ā"
	elseif rfind(base.lemma, "अ$") then
		base.decl = "ind-ā"
	elseif rfind(base.lemma, AAM .. "$") then
		base.decl = "ān"
	elseif rfind(base.lemma, "अँ$") then
		base.decl = "ind-ān"
	else
		error("Unrecognized adjective lemma: " .. base.lemma)
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


local function process_overrides(forms, args)
	for slot, _ in pairs(adjective_slots) do
		if args[slot] then
			forms[slot] = nil
			if args[slot] ~= "-" and args[slot] ~= "—" then
				for _, form in ipairs(rsplit(args[slot], "%s*,%s*")) do
					iut.insert_form(forms, slot, {form=form})
				end
			end
		end
	end
end


local function compute_category_and_desc(base)
	local props = declprops[base.decl]
	if props then
		return props.cat, props.desc
	end
	local ind, stem = rmatch(base.decl, "^(ind%-)(.*)$")
	if not ind then
		stem = basel.decl
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
		m_table.insertIfNot(cats, "Hindi " .. cattype)
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
<div class="NavFrame" style="display: inline-block;min-width: 50em">
<div class="NavHead" style="background:#eff7ff" >{title}{annotation}</div>
<div class="NavContent">
{\op}| style="background:#F9F9F9;text-align:center;min-width:50em" class="inflection-table"
|-
! rowspan="2" style="width:20%;background:#d9ebff" |
! colspan="2" style="background:#d9ebff" | masculine
! colspan="2" style="background:#d9ebff" | feminine
|-
! style="background:#d9ebff" | singular
! style="background:#d9ebff" | plural
! style="background:#d9ebff" | singular
! style="background:#d9ebff" | plural
|-
!style="background:#eff7ff" | direct
| {dir_m_s}
| {dir_m_p}
| {dir_f_s}
| {dir_f_p}
|-
!style="background:#eff7ff" | oblique
| {obl_m_s}
| {obl_m_p}
| {obl_f_s}
| {obl_f_p}
|-
!style="background:#eff7ff" | vocative
| {voc_m_s}
| {voc_m_p}
| {voc_f_s}
| {voc_f_p}
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
		forms.title = 'Declension of <i lang="hi" class="Deva">' .. forms.lemma .. '</i>'
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



export.adj_decl_endings = {
	["ā-stem"] = {AA, E, II},
	["independent ā-stem"] = {"अ", "ए", "ई"},
	["ā̃-stem"] = {AAM, EN, IIN},
	["independent ā̃-stem"] = {"अँ", "एँ", "ईं"},
}


-- Implementation of template 'hi-adj cat'.
function export.catboiler(frame)
	local SUBPAGENAME = mw.title.getCurrentTitle().subpageText
	local params = {
		[1] = {},
	}
	local args = m_para.process(frame:getParent().args, params)

	local function get_pos()
		local pos = rmatch(SUBPAGENAME, "^Hindi.- ([^ ]*)s ")
		if not pos then
			pos = rmatch(SUBPAGENAME, "^Hindi.- ([^ ]*)s$")
		end
		if not pos then
			error("Invalid category name, should be e.g. \"Hindi adjectives with ...\" or \"Hindi ... adjectives\"")
		end
		return pos
	end

	local function get_sort_key()
		local pos, sort_key = rmatch(SUBPAGENAME, "^Hindi.- ([^ ]*)s with (.*)$")
		if sort_key then
			return sort_key
		end
		pos, sort_key = rmatch(SUBPAGENAME, "^Hindi ([^ ]*)s (.*)$")
		if sort_key then
			return sort_key
		end
		return rsub(SUBPAGENAME, "^Hindi ", "")
	end

	local cats = {}, pos

	-- Insert the category CAT (a string) into the categories. String will
	-- have "Hindi " prepended and ~ substituted for the plural part of speech.
	local function insert(cat, atbeg)
		local fullcat = "Hindi " .. rsub(cat, "~", pos .. "s")
		if atbeg then
			table.insert(cats, 1, fullcat)
		else
			table.insert(cats, fullcat)
		end
	end

	local maintext
	local stem, gender, stress, ending
	while true do
		if args[1] then
			maintext = "~ " .. args[1]
			pos = get_pos()
			break
		end

		local stem
		stem, pos = rmatch(SUBPAGENAME, "^Hindi (independent [^ %-]*%-stem) (.*)s$")
		if not stem then
			stem, pos = rmatch(SUBPAGENAME, "^Hindi ([^ %-]*%-stem) (.*)s$")
		end
		if stem then
			if not export.adj_decl_endings[stem] then
				error("Unrecognized adjective stem type in category name: '" .. stem .. "'")
			end
			local mdir, mop, f = unpack(export.adj_decl_endings[stem])
			local endingtext = "ending in " .. mdir .. " in the direct masculine singular, in " .. mop .. " in the remaining masculine forms, and in " .. f .. " in all feminine forms."

			maintext = stem .. " ~, " .. endingtext
			if rfind(stem, "independent") then
				maintext = maintext .. " Here, 'independent' means that the stem ending directly " ..
				"follows a vowel and so uses the independent Devanagari form of the vowel that begins the ending."
			end
			insert("~ by stem type|" .. rsub(stem, "independent ", ""))
			break
		end
		error("Unrecognized Hindi adjective category name")
	end

	insert("~|" .. get_sort_key(), "at beginning")

	local categories = {}
	for _, cat in ipairs(cats) do
		table.insert(categories, "[[Category:" .. cat .. "]]")
	end

	return "This category contains Hindi " .. rsub(maintext, "~", pos .. "s")
		.. "\n" ..
		mw.getCurrentFrame():expandTemplate{title="hi-categoryTOC", args={}}
		.. table.concat(categories, "")
end


-- Externally callable function to parse and decline an adjective given
-- user-specified arguments. Return value is ALTERNANT_MULTIWORD_SPEC, an
-- object where the declined forms are in `ALTERNANT_MULTIWORD_SPEC.forms` for
-- each slot. If there are no values for a slot, the slot key will be missing.
-- The value for a given slot is a list of objects
-- {form=FORM, translit=TRANSLIT, footnotes=FOOTNOTES}.
function export.do_generate_forms(parent_args, pos, from_headword, def)
	local params = {
		[1] = {required = true, default = def or "अच्छा"},
		footnote = {list = true},
		title = {},
	}
	for slot, _ in ipairs(adjective_slots) do
		params[slot] = {}
	end

	local args = m_para.process(parent_args, params)
	local alternant_multiword_spec = iut.parse_alternant_multiword_spec(args[1],
		parse_indicator_spec, "allow default indicator")
	alternant_multiword_spec.title = args.title
	alternant_multiword_spec.footnotes = args.footnote
	alternant_multiword_spec.pos = pos or "adjectives"
	alternant_multiword_spec.forms = {}
	com.normalize_all_lemmas(alternant_multiword_spec)
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


-- Entry point for {{hi-adecl}}. Template-callable function to parse and decline 
-- an adjective given user-specified arguments and generate a displayable table
-- of the declined forms.
function export.show(frame)
	local parent_args = frame:getParent().args
	local alternant_spec = export.do_generate_forms(parent_args)
	show_forms(alternant_spec)
	return make_table(alternant_spec) .. require("Module:utilities").format_categories(alternant_spec.categories, lang)
end


-- Entry point for {{hi-adecl-manual}}. Template-callable function to parse and
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
