--[=[
	This module contains functions to implement {{form of/*doc}} templates.
	The module contains the actual implementation, meant to be called from other
	Lua code. See [[Module:form of doc/templates]] for the function meant to be
	called directly from templates.

	Author: Benwing2
]=]
local export = {}

local en_utilities_module = "Module:en-utilities"
local form_of_module = "Module:form of"
local form_of_data_module = "Module:form of/data"
local function_module = "Module:fun"
local labels_module = "Module:labels"
local languages_module = "Module:languages"
local load_module = "Module:load"
local shortcut_box_module = "Module:shortcut box"
local string_utilities_module = "Module:string utilities"
local table_module = "Module:table"
local template_parser_module = "Module:template parser"

local require = require

local m_form_of = require(form_of_module)
local m_form_of_data = require(form_of_data_module)
local m_cats = require(m_form_of.form_of_cats_module)
local m_str_utils = require(string_utilities_module)
local m_table = require(table_module)

local concat = table.concat
local format_shortcuts = require(shortcut_box_module).format_shortcuts
local get_indefinite_article = require(en_utilities_module).get_indefinite_article
local get_label_info = require(labels_module).get_label_info
local get_lang = require(languages_module).getByCode
local get_tag_display_form = m_form_of.get_tag_display_form
local get_tag_set_display_form = m_form_of.get_tag_set_display_form
local insert = table.insert
local ipairs = ipairs
local is_link_or_html = m_form_of.is_link_or_html
local iterate_from = require(function_module).iterateFrom
local list_to_set = m_table.listToSet
local normalize_tag_set = m_form_of.normalize_tag_set
local pairs = pairs
local remove_duplicates = m_table.removeDuplicates
local safe_require = require(load_module).safe_require
local serial_comma_join = m_table.serialCommaJoin
local shallow_copy = m_table.shallowCopy
local sort = table.sort
local str_utils_format = m_str_utils.format
local table_extend = m_table.extend
local template_link = require(template_parser_module).templateLink
local tostring = tostring
local ucfirst = m_str_utils.ucfirst

local form_of_lang_data_module_prefix = m_form_of.form_of_lang_data_module_prefix
local form_of_data1 = require(m_form_of.form_of_data1_module)
local form_of_data2 = require(m_form_of.form_of_data2_module)
local form_of_pos = require(m_form_of.form_of_pos_module)

local SHORTCUTS = m_form_of_data.SHORTCUTS
local TAG_TYPE = m_form_of_data.TAG_TYPE

local function lang_name(langcode, param)
	return get_lang(langcode, param):getCanonicalName()
end

local function link_box(content)
	return "<div class=\"noprint plainlinks\" style=\"float: right; clear: both; margin: 0 0 .5em 1em; background: #f9f9f9; border: 1px #aaaaaa solid; margin-top: -1px; padding: 5px; font-weight: bold; font-size: small;\">"
		.. content .. "</div>"
end

local function show_editlink(page)
	return link_box("[" .. tostring(mw.uri.fullUrl(page, "action=edit")) .. " Edit]")
end

local function template_name(preserve_lang_code)
	-- Fetch the template name, minus the '/documentation' suffix that may follow
	-- and without any language-specific prefixes (e.g. 'el-' or 'ine-bsl-pro-')
	-- (unless `preserve_lang_code` is given).
	local PAGENAME = mw.title.getCurrentTitle().text
	local tempname = PAGENAME:gsub("/documentation$", "")
	if not preserve_lang_code then
		while true do
			-- Repeatedly strip off language code prefixes, in case there are multiple.
			local newname = tempname:gsub("^%l%l%l?%-", "")
			if newname == tempname then
				break
			end
			tempname = newname
		end
	end
	return tempname
end

function export.introdoc(args)
	local lang = args.lang
	local langname = lang and lang_name(lang, "lang")
	local exlangnames = {}
	for _, exlang in ipairs(args.exlang) do
		insert(exlangnames, lang_name(exlang, "exlang"))
	end
	local parts = {}
	insert(parts, mw.getCurrentFrame():expandTemplate {title="uses lua", args={form_of_module .. "/templates"}})
	insert(parts, "This template creates a definition line for ")
	insert(parts, args.pldesc or template_name():gsub(" of$", "") .. "s")
	insert(parts, " ")
	insert(parts, args.primaryentrytext or "of primary entries")
	if lang then
		insert(parts, " in " .. langname)
	elseif #args.exlang > 0 then
		insert(parts, ", e.g. in " .. serial_comma_join(exlangnames, {conj = "or"}))
	end
	insert(parts, ".")
	local cats = args.cat
	if #cats > 0 then
		insert(parts, " It also categorizes the page into ")
		local catparts = {}
		if lang then
			for _, cat in ipairs(cats) do
				insert(catparts, "[[:Category:" .. langname .. " " .. cat .. "]]")
			end
		else
			for _, cat in ipairs(cats) do
				insert(catparts, "the proper language-specific subcategory of [[:Category:" .. ucfirst(cat) .. " by language]] (e.g. [[:Category:" .. (exlangnames[1] or "English") .. " " .. cat .. "]])")
			end
		end
		insert(parts, serial_comma_join(catparts))
		insert(parts, ".")
	end
	if args.addlintrotext then
		insert(parts, " ")
		insert(parts, args.addlintrotext)
	end
	insert(parts, "\n")
	if args.withcap and args.withdot then
		insert(parts, [===[

By default, this template displays its output as a full sentence, with an initial capital letter and a trailing period (full stop). This can be overridden using <code>|nocap=1</code> and/or <code>|nodot=1</code> (see below).
]===])
	elseif args.withcap then
		insert(parts, [===[

By default, this template displays its output with an initial capital letter. This can be overridden using <code>|nocap=1</code> (see below).
]===])
	end
	insert(parts, [===[

This template is '''not''' meant to be used in etymology sections.]===])
	local etymtemp = args.etymtemp
	if etymtemp then
		insert(parts, " For those sections, use <code>{{[[Template:" .. etymtemp .. "|" .. etymtemp .. "]]}}</code> instead.")
	end
	insert(parts, [===[


Note that users can customize how the output of this template displays by modifying their Custom CSS files. See [[:Category:Form-of templates|“Form of” templates]] for details.
]===])
	return concat(parts)
end

local function param(params, list, required)
	local paramparts = {}
	if type(params) ~= "table" then
		params = {params}
	end
	for _, p in ipairs(params) do
		local listparts = {}
		insert(listparts, "<code>|" .. p .. "=</code>")
		if list then
			insert(listparts, ", <code>|" .. p .. "2=</code>")
			insert(listparts, ", <code>|" .. p .. "3=</code>")
			insert(listparts, ", etc.")
		end
		insert(paramparts, concat(listparts))
	end
	local reqtext = required and "'''(required)'''" or "''(optional)''"
	return concat(paramparts, " or ") .. " " .. reqtext
end

local function param_and_doc(parts, params, list, required, doc)
	insert(parts, "; ")
	insert(parts, param(params, list, required))
	insert(parts, "\n")
	insert(parts, ": ")
	insert(parts, doc)
	insert(parts, "\n")
end

function export.paramdoc(args)
	local parts = {}

	local tempname = template_name()
	local art = args.art or get_indefinite_article(tempname)
	local sgdescof = args.sgdescof or art .. " " .. tempname
	insert(parts, "''Positional (unnamed) parameters:''\n")
	local lang = args.lang
	if args.lang then
		param_and_doc(parts, "1", false, true, "The term to link to (which this page is " .. sgdescof .. "). This should include any needed diacritics as appropriate to " .. lang_name(lang, "lang") .. ". These diacritics will automatically be stripped out in the appropriate fashion in order to create the link to the page.")
		param_and_doc(parts, "2", false, false, "The text to be shown in the link to the term. If empty or omitted, the term specified by the first parameter will be used. This parameter is normally not necessary, and should not be used solely to indicate diacritics; instead, put the diacritics in the first parameter.")
	else
		param_and_doc(parts, "1", false, true, "The [[WT:LANGCODE|language code]] of the term linked to (which this page is " .. sgdescof .. "). See [[Wiktionary:List of languages]]. <small>The parameter <code>|lang=</code> is a deprecated synonym; please do not use. If this is used, all numbered parameters move down by one.</small>")
		param_and_doc(parts, "2", false, true, "The term to link to (which this page is " .. sgdescof .. "). This should include diacritics as appropriate to the language (e.g. accents in Russian to mark the stress, vowel diacritics in Arabic, macrons in Latin to indicate vowel length, etc.). These diacritics will automatically be stripped out in a language-specific fashion in order to create the link to the page.")
		param_and_doc(parts, "3", false, false, "The text to be shown in the link to the term. If empty or omitted, the term specified by the second parameter will be used. This parameter is normally not necessary, and should not be used solely to indicate diacritics; instead, put the diacritics in the second parameter.")
	end
	insert(parts, "''Named parameters:''\n")
	if args.etymtemp == 'contraction' then
		param_and_doc(parts, "mandatory", false, false, "If <code>|mandatory=1</code>, indicates that the contraction is mandatory.")
		param_and_doc(parts, "optional", false, false, "If <code>|optional=1</code>, indicates that the contraction is optional.")
	end
	param_and_doc(parts, {"t", lang and "3" or "4"}, false, false, "A gloss or short translation of the term linked to. <small>The parameter <code>|gloss=</code> is a deprecated synonym; please do not use.</small>")
	param_and_doc(parts, "tr", false, false, "Transliteration for non-Latin-script terms, if different from the automatically-generated one.")
	param_and_doc(parts, "ts", false, false, "Transcription for non-Latin-script terms whose transliteration is markedly different from the actual pronunciation. Should not be used for IPA pronunciations.")
	param_and_doc(parts, "sc", false, false, "Script code to use, if script detection does not work. See [[Wiktionary:Scripts]].")
	if args.withfrom then
		param_and_doc(parts, "from", true, false, "A label (see " .. template_link("label") .. ") that gives additional information on the dialect that the term belongs to, the place that it originates from, or something similar.")
	end
	if args.withdot then
		param_and_doc(parts, "dot", false, false, "A character to replace the final dot that is normally shown automatically.")
		param_and_doc(parts, "nodot", false, false, "If <code>|nodot=1</code>, then no automatic dot will be shown.")
	end
	if args.withcap then
		param_and_doc(parts, "nocap", false, false, "If <code>|nocap=1</code>, then the first letter will be in lowercase.")
	end
	param_and_doc(parts, "id", false, false, "A sense id for the term, which links to anchors on the page set by the " .. template_link("senseid") .. " template.")
	return concat(parts)
end

function export.usagedoc(args)
	local exlangs = {}
	for _, exlang in ipairs(args.exlang) do
		insert(exlangs, exlang)
	end
	insert(exlangs, 'en')
	insert(exlangs, 'de')
	insert(exlangs, 'ja')
	exlangs = remove_duplicates(exlangs)
	local sub = {}
	local langparts = {}
	for _, langcode in ipairs(exlangs) do
		insert(langparts, '<code>' .. langcode .. '</code> for ' .. lang_name(langcode, "exlang"))
	end
	sub.exlangs = serial_comma_join(langparts, {conj = "or"})
	sub.tempname = template_name("preserve lang code")

	if args.lang then
		return str_utils_format([===[
==Usage==
Use in the definition line, most commonly as follows:
 # {\op}{\op}{tempname}|<var><primary entry goes here></var>{\cl}{\cl}

===Parameters===
]===], sub) .. export.paramdoc(args)
	else
		return str_utils_format([===[
==Usage==
Use in the definition line, most commonly as follows:
 # {\op}{\op}{tempname}|<var><langcode></var>|<var><primary entry goes here></var>{\cl}{\cl}
where <code><var><langcode></var></code> is the [[Wiktionary:Languages|language code]], e.g. {exlangs}.

===Parameters===
]===], sub) .. export.paramdoc(args)
	end
end

function export.fulldoc(args)
	local docsubpage = mw.getCurrentFrame():expandTemplate{title="documentation subpage", args={}}
	local shortcuts = #args.shortcut > 0 and format_shortcuts(args.shortcut) or ""
	local introdoc = export.introdoc(args)
	local usagedoc = export.usagedoc(args)
	return docsubpage .. "\n" .. shortcuts .. introdoc .. "\n" .. usagedoc
end

function export.infldoc(args)
	args = shallow_copy(args)
	args.sgdesc = args.sgdesc or (args.art or "the") .. " " ..
		template_name():gsub(" of$", "") .. (args.form and " " .. args.form or "")
	args.pldesc = args.sgdesc
	args.sgdescof = args.sgdescof or args.sgdesc .. " of"
	args.primaryentrytext = args.primaryentrytext or "of a primary entry"
	return export.fulldoc(args)
end

local tag_type_to_description = {
	-- If not listed, we just capitalize the first letter
	["tense-aspect"] = "Tense/aspect",
	["voice-valence"] = "Voice/valence",
	["comparison"] = "Degrees of comparison",
	["class"] = "Inflectional class",
	["sound change"] = "Sound changes",
	["grammar"] = "Misc grammar",
	["other"] = "Other tags",
}

local tag_type_order = {
	"person",
	"number",
	"gender",
	"animacy",
	"tense-aspect",
	"mood",
	"voice-valence",
	"non-finite",
	"case",
	"state",
	"comparison",
	"register",
	"deixis",
	"clusivity",
	"class",
	"attitude",
	"sound change",
	"grammar",
	"other",
}

local function tag_type_desc(tag_type)
	return tag_type_to_description[tag_type] or ucfirst(tag_type)
end

local function sort_by_first(a, b)
	return a[1] < b[1]
end

local function get_display_form(tag_set, lang)
	local norm_tag_sets = normalize_tag_set(tag_set, lang)
	if #norm_tag_sets == 1 then
		return get_tag_set_display_form(norm_tag_sets[1], lang)
	end
	-- If we have a conjoined shortcut that expands to multiple tag sets, display them using a numbered list.
	-- In order to do that inside a table we need a newline before the list.
	local display_forms = {}
	for _, norm_tag_set in ipairs(norm_tag_sets) do
		insert(display_forms, "\n# " .. get_tag_set_display_form(norm_tag_set, lang))
	end
	return concat(display_forms)
end

local function organize_tag_data(data_module)
	local tab = {}
	for name, data in pairs(data_module.tags) do
		local tag_type = data[TAG_TYPE]
		if not tag_type then
			-- Throw an error because hopefully it will get noticed and fixed. If we just skip it, it may never get
			-- fixed.
			error("Tag '" .. name .. "' has no tag_type")
		end
		if not tab[tag_type] then
			tab[tag_type] = {}
		end
		insert(tab[tag_type], {name, data})
	end
	local tag_type_order_set = list_to_set(tag_type_order)
	for tag_type, tags_of_type in pairs(tab) do
		if not tag_type_order_set[tag_type] then
			-- See justification above for throwing an error.
			error("Tag type '" .. tag_type .. "' not listed in tag_type_order")
		end
		sort(tags_of_type, sort_by_first)
	end

	return tab
end

local function insert_group(parts, group)
	for _, namedata in ipairs(group) do
		local sparts = {}
		local name, data = unpack(namedata)
		insert(sparts, "| <code>" .. name .. "</code> || ")
		local shortcuts = data[SHORTCUTS]
		if shortcuts then
			local ssparts = {}
			if type(shortcuts) == "string" then
				shortcuts = {shortcuts}
			end
			for _, shortcut in ipairs(shortcuts) do
				insert(ssparts, "<code>" .. shortcut .. "</code>")
			end
			insert(sparts, concat(ssparts, ", ") .. " ")
		end
		insert(sparts, "|| " .. get_tag_display_form(name))
		insert(parts, "|-")
		insert(parts, concat(sparts))
	end
end

function export.tagtable()
	local data1_tab = organize_tag_data(form_of_data1)
	local data2_tab = organize_tag_data(form_of_data2)

	local parts = {}

	insert(parts, '{|class="wikitable"')
	insert(parts, "! Canonical tag !! Shortcut(s) !! Display form")
	for _, tag_type in ipairs(tag_type_order) do
		local group_tab = data1_tab[tag_type]
		if group_tab then
			insert(parts, "|-")
			insert(parts, '! colspan="3" style="text-align: center; background: var(--wikt-palette-lightergrey);" | ' .. tag_type_desc(tag_type) ..
				" (more common)")
			insert_group(parts, group_tab)
		end
		group_tab = data2_tab[tag_type]
		if group_tab then
			insert(parts, "|-")
			insert(parts, '! colspan="3" style="text-align: center; background: var(--wikt-palette-lightergrey);" | ' .. tag_type_desc(tag_type) ..
				" (less common)")
			insert_group(parts, group_tab)
		end
	end
	insert(parts, "|}")

	return concat(parts, "\n")
end

local function organize_non_alias_shortcut_data(data_module, lang)
	local non_alias_shortcuts = {}
	for shortcut, full in pairs(data_module.shortcuts) do
		if type(full) == "table" or is_link_or_html(full) or full:find("//") or full:find(":") then
			insert(non_alias_shortcuts, {shortcut, full, get_display_form({shortcut}, lang)})
		end
	end

	sort(non_alias_shortcuts, sort_by_first)

	return non_alias_shortcuts
end

local function insert_shortcut_group(parts, shortcuts)
	for _, spec in ipairs(shortcuts) do
		local shortcut, full, display = unpack(spec)
		insert(parts, "|-")
		if type(full) == "table" then
			full = "{" .. concat(full, " ") .. "}"
		end
		insert(parts, ("| <code>%s</code> || <code>%s</code> || %s"):format(shortcut, full, display))
	end
end

function export.non_alias_shortcut_table()
	local non_alias_shortcuts1 = organize_non_alias_shortcut_data(form_of_data1)
	local non_alias_shortcuts2 = organize_non_alias_shortcut_data(form_of_data2)

	local parts = {}

	insert(parts, '{|class="wikitable"')
	insert(parts, "! Shortcut !! Expansion !! Display form")
	if #non_alias_shortcuts1 > 0 then
		insert(parts, "|-")
		insert(parts, '! colspan="3" style="text-align: center; background: #dddddd;" | More common:')
		insert_shortcut_group(parts, non_alias_shortcuts1)
	end
	if #non_alias_shortcuts2 > 0 then
		insert(parts, "|-")
		insert(parts, '! colspan="3" style="text-align: center; background: #dddddd;" | Less common:')
		insert_shortcut_group(parts, non_alias_shortcuts2)
	end
	insert(parts, "|}")

	return concat(parts, "\n")
end

local function process_spec(spec, cats, labels)
	if type(spec) == "string" then
		insert(cats, spec)
		return
	elseif not spec or spec == true then
		-- Ignore labels, etc.
		return
	elseif type(spec) ~= "table" then
		error("Wrong type of condition " .. spec .. ": " .. type(spec))
	elseif spec.labels then
		table_extend(labels, spec.labels)
		return
	end
	local predicate = spec[1]
	if predicate == "multi" or predicate == "cond" then
		for _, sp in iterate_from(2, ipairs(spec)) do -- Iterate from 2.
			process_spec(sp, cats, labels)
		end
	elseif predicate == "pexists" then
		process_spec(spec[2], cats, labels)
		process_spec(spec[3], cats, labels)
	elseif predicate == "has" or predicate == "hasall" or predicate == "hasany" or
		predicate == "tags=" or predicate == "p=" or predicate == "pany" or
		predicate == "not" then
		process_spec(spec[3], cats, labels)
		process_spec(spec[4], cats, labels)
	elseif predicate == "and" or predicate == "or" then
		process_spec(spec[3], cats, labels)
		process_spec(spec[4], cats, labels)
	elseif predicate == "call" then
		return
	else
		error("Unrecognized predicate: " .. predicate)
	end
end

local function find_categories_and_labels(catstruct)
	local cats, labels = {}, {}
	for _, spec in ipairs(catstruct) do
		process_spec(spec, cats, labels)
	end
	return cats, labels
end

local function construct_category_table(cats)
	local category_parts = {}
	insert(category_parts, '{|class="wikitable"')
	insert(category_parts, "! Category")
	for _, cat in ipairs(cats) do
		insert(category_parts, "|-")
		insert(category_parts, "| <code>" .. cat .. "</code>")
	end
	insert(category_parts, "|}")
	return concat(category_parts, "\n")
end

local function construct_label_table(labels, lang, replace_und)
	local label_parts = {}
	insert(label_parts, '{|class="wikitable"')
	insert(label_parts, "! Label !! Display form !! Associated categories")
	for _, label in ipairs(labels) do
		insert(label_parts, "|-")
		local label_data = get_label_info{
			label = label,
			lang = lang,
		}
		local coded_categories = {}
		for _, cat in ipairs(label_data.categories) do
			if replace_und then
				cat = cat:gsub("^und:", "LANGCODE:")
				cat = cat:gsub("^Undetermined ", "LANG ")
			end
			insert(coded_categories, "<code>" .. cat .. "</code>")
		end
		insert(label_parts, ("| <code>%s</code> || %s || %s"):format(label, label_data.label,
			concat(coded_categories, ",")))
	end
	insert(label_parts, "|}")
	return concat(label_parts, "\n")
end

local function iterate_languages(langcodes_module, data_by_lang)
	for langcode in pairs(require(langcodes_module)) do
		local data_module_name = form_of_lang_data_module_prefix .. langcode
		local data_module = safe_require(data_module_name)
		if data_module or m_cats[langcode] and langcode ~= "und" then
			local lang = get_lang(langcode, nil, true)
			-- First do base-lemma params.
			local base_lemma_param_table
			if data_module and data_module.base_lemma_params and #data_module.base_lemma_params > 0 then
				local base_lemma_param_parts = {}
				insert(base_lemma_param_parts, '{|class="wikitable"')
				insert(base_lemma_param_parts, "! Parameter !! Display form")
				for _, base_lemma_param in ipairs(data_module.base_lemma_params) do
					insert(base_lemma_param_parts, "|-")
					insert(base_lemma_param_parts, ("| <code>%s</code> || %s"):format(base_lemma_param.param,
						get_display_form(base_lemma_param.tags, lang)))
				end
				insert(base_lemma_param_parts, "|}")
				base_lemma_param_table = concat(base_lemma_param_parts, "\n")
			end
			-- Then do inflection tags.
			local data1_tab = data_module and organize_tag_data(data_module) or {}
			local tag_parts = {}
			insert(tag_parts, '{|class="wikitable"')
			insert(tag_parts, "! Canonical tag !! Shortcut(s) !! Tag type !! Display form")
			local saw_any_tag = false
			for _, tag_type in ipairs(tag_type_order) do
				local group_tab = data1_tab[tag_type]
				if group_tab then
					for _, namedata in ipairs(group_tab) do
						local sparts = {}
						local name, data = unpack(namedata)
						insert(sparts, "| <code>" .. name .. "</code> || ")
						if data.shortcuts then
							local ssparts = {}
							for _, shortcut in ipairs(data.shortcuts) do
								insert(ssparts, "<code>" .. shortcut .. "</code>")
							end
							insert(sparts, concat(ssparts, ", ") .. " ")
						end
						insert(sparts, "|| " .. tag_type_desc(tag_type) .. " || " ..
							get_tag_display_form(name, lang))
						insert(tag_parts, "|-")
						insert(tag_parts, concat(sparts))
						saw_any_tag = true
					end
				end
			end
			insert(tag_parts, "|}")
			local tag_table = saw_any_tag and concat(tag_parts, "\n") or nil
			-- Then do non-alias shortcuts.
			local non_alias_shortcut_table
			local non_alias_shortcuts = data_module and organize_non_alias_shortcut_data(data_module, lang) or {}
			if #non_alias_shortcuts > 0 then
				local non_alias_shortcut_parts = {}
				insert(non_alias_shortcut_parts, '{|class="wikitable"')
				insert(non_alias_shortcut_parts, "! Shortcut !! Expansion !! Display form")
				for _, spec in ipairs(non_alias_shortcuts) do
					local shortcut, full, display = unpack(spec)
					insert(non_alias_shortcut_parts, "|-")
					if type(full) == "table" then
						full = "{" .. concat(full, " ") .. "}"
					end
					insert(non_alias_shortcut_parts, ("| <code>%s</code> || <code>%s</code> || %s"):format(shortcut, full, display))
				end
				insert(non_alias_shortcut_parts, "|}")
				non_alias_shortcut_table = concat(non_alias_shortcut_parts, "\n")
			end
			-- Then do categories and labels.
			local category_table, label_table
			if m_cats[langcode] then
				local cats, labels = find_categories_and_labels(m_cats[langcode])
				if #cats > 0 then
					category_table = construct_category_table(cats)
				end
				if #labels > 0 then
					label_table = construct_label_table(labels, lang)
				end
			end
			-- Concatenate all the tables together, with appropriate explanatory text.
			if base_lemma_param_table or tag_table or non_alias_shortcut_table or category_table or label_table then
				local langname, lang_parts = lang:getCanonicalName(), {}
				insert(lang_parts, "===" .. langname .. "===")
				insert(lang_parts, show_editlink(data_module_name))
				if base_lemma_param_table then
					insert(lang_parts, ("%s-specific base lemma parameters:"):format(langname))
					insert(lang_parts, base_lemma_param_table)
				end
				if tag_table then
					insert(lang_parts, ("%s-specific inflection tags:"):format(langname))
					insert(lang_parts, tag_table)
				end
				if non_alias_shortcut_table then
					insert(lang_parts, ("%s-specific non-alias shortcuts:"):format(langname))
					insert(lang_parts, non_alias_shortcut_table)
				end
				if category_table then
					insert(lang_parts, ("%s-specific categories (the exact conditions under which these are added are described in [[Module:form of/cats]]):"):
						format(langname))
					insert(lang_parts, category_table)
				end
				if label_table then
					insert(lang_parts, ("%s-specific labels (the exact conditions under which these are added are described in [[Module:form of/cats]]):"):
						format(langname))
					insert(lang_parts, label_table)
				end
				insert(data_by_lang, {langname, concat(lang_parts, "\n")})
			end
		end
	end
end

local function sort_by_first_english_first(langdata1, langdata2)
	if langdata1[1] == "English" then
		-- English is "less than" (goes before) all other languages
		return true
	elseif langdata2[1] == "English" then
		-- All other languages are not "less than" (do not go before) English
		return false
	end
	return langdata1[1] < langdata2[1]
end

function export.lang_specific_tables()
	
	local data_by_lang = {}
	iterate_languages("Module:languages/code to canonical name", data_by_lang)
	iterate_languages("Module:etymology languages/code to canonical name", data_by_lang)

	sort(data_by_lang, sort_by_first_english_first)

	local parts = {}
	for _, lang_and_data in ipairs(data_by_lang) do
		insert(parts, lang_and_data[2])
	end
	return concat(parts, "\n")
end

function export.postable()
	local shortcut_tab = {}
	for shortcut, full in pairs(form_of_pos) do
		if not shortcut_tab[full] then
			shortcut_tab[full] = {}
		end
		insert(shortcut_tab[full], shortcut)
	end
	local shorcut_list = {}
	for full, shortcuts in pairs(shortcut_tab) do
		sort(shortcuts)
		insert(shorcut_list, {full, shortcuts})
	end
	sort(shorcut_list, sort_by_first)

	local parts = {}
	insert(parts, '{|class="wikitable"')
	insert(parts, "! Canonical part of speech !! Shortcut(s)")
	for _, full_shortcuts in ipairs(shorcut_list) do
		local full = full_shortcuts[1]
		local shortcuts = full_shortcuts[2]
		insert(parts, "|-")
		local sparts = {}
		for _, shortcut in ipairs(shortcuts) do
			insert(sparts, "<code>" .. shortcut .. "</code>")
		end
		insert(parts, "| <code>" .. full .. "</code> || " .. concat(sparts, ", "))
	end
	insert(parts, "|}")
	return concat(parts, "\n")
end

function export.lang_independent_category_table()
	if m_cats["und"] then
		local cats = find_categories_and_labels(m_cats["und"])
		if #cats > 0 then
			return construct_category_table(cats)
		end
	end
	return "(no language-independent categories currently)"
end

function export.lang_independent_label_table()
	if m_cats["und"] then
		local labels = select(2, find_categories_and_labels(m_cats["und"]))
		if #labels > 0 then
			return construct_label_table(labels, get_lang("und"), "replace und")
		end
	end
	return "(no language-independent labels currently)"
end


return export
