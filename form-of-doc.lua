--[=[
	This module contains functions to implement {{form of/*doc}} templates.
	The module contains the actual implementation, meant to be called from other
	Lua code. See [[Module:form of doc/templates]] for the function meant to be
	called directly from templates.

	Author: Benwing2
]=]

local export = {}

local m_template_link = require("Module:template link")
local m_languages = require("Module:languages")
local m_table = require("Module:table")
local form_of_module = "Module:form of"
local m_form_of = require(form_of_module)
local strutils = require("Module:string utilities")

local usub = mw.ustring.sub
local uupper = mw.ustring.upper
local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

local function lang_name(langcode, param)
	local lang = m_languages.getByCode(langcode, param)
	return lang:getCanonicalName()
end

local function ucfirst(text)
	return uupper(usub(text, 1, 1)) .. usub(text, 2)
end

local function template_name(preserve_lang_code)
	-- Fetch the template name, minus the '/documentation' suffix that may follow
	-- and without any language-specific prefixes (e.g. 'el-' or 'bsl-ine-pro-')
	-- (unless `preserve_lang_code` is given).
	local PAGENAME =  mw.title.getCurrentTitle().text
	local tempname = rsub(PAGENAME, "/documentation$", "")
	if not preserve_lang_code then
		while true do
			-- Repeatedly strip off language code prefixes, in case there are multiple.
			local newname = rsub(tempname, "^[a-z][a-z][a-z]?%-", "")
			if newname == tempname then
				break
			end
			tempname = newname
		end
	end
	return tempname
end

function export.introdoc(args)
	local langname = args.lang and lang_name(args.lang, "lang")
	local exlangnames = {}
	for _, exlang in ipairs(args.exlang) do
		table.insert(exlangnames, lang_name(exlang, "exlang"))
	end
	parts = {}
	table.insert(parts, mw.getCurrentFrame():expandTemplate{title="Lua", args={form_of_module .. "/templates"}})
	table.insert(parts, "This template creates a definition line for ")
	table.insert(parts, args.pldesc or rsub(template_name(), " of$", "") .. "s")
	table.insert(parts, " ")
	table.insert(parts, args.primaryentrytext or "of primary entries")
	if args.lang then
		table.insert(parts, " in " .. langname)
	elseif #args.exlang > 0 then
		table.insert(parts, ", e.g. in " .. m_table.serialCommaJoin(exlangnames, {conj = "or"}))
	end
	table.insert(parts, ".")
	if #args.cat > 0 then
		table.insert(parts, " It also categorizes the page into ")
		local catparts = {}
		for _, cat in ipairs(args.cat) do
			if args.lang then
				table.insert(catparts, "[[:Category:" .. langname .. " " .. cat .. "]]")
			else
				table.insert(catparts, "the proper language-specific subcategory of [[:Category:" .. ucfirst(cat) .. " by language]] (e.g. [[:Category:" .. (exlangnames[1] or "English") .. " " .. cat .. "]])")
			end
		end
		table.insert(parts, m_table.serialCommaJoin(catparts))
		table.insert(parts, ".")
	end
	if args.addlintrotext then
		table.insert(parts, " ")
		table.insert(parts, args.addlintrotext)
	end
	table.insert(parts, "\n")
	if args.withcap and args.withdot then
		table.insert(parts, [===[

By default, this template displays its output as a full sentence, with an initial capital letter and a trailing period (full stop). This can be overridden using <code>|nocap=1</code> and/or <code>|nodot=1</code> (see below).
]===])
	elseif args.withcap then
		table.insert(parts, [===[

By default, this template displays its output with an initial capital letter. This can be overridden using <code>|nocap=1</code> (see below).
]===])
	end
	table.insert(parts, [===[

This template is '''not''' meant to be used in etymology sections.]===])
	if args.etymtemp then
		table.insert(parts, " For those sections, use <code>{{[[Template:" .. args.etymtemp .. "|" .. args.etymtemp .. "]]}}</code> instead.")
	end
	table.insert(parts, [===[


Note that users can customize how the output of this template displays by modifying their monobook.css files. See [[:Category:Form-of templates|“Form of” templates]] for details.
]===])
	return table.concat(parts)
end

local function param(params, list, required)
	local paramparts = {}
	if type(params) ~= "table" then
		params = {params}
	end
	for _, p in ipairs(params) do
		local listparts = {}
		table.insert(listparts, "<code>|" .. p .. "=</code>")
		if list then
			table.insert(listparts, ", <code>|" .. p .. "2=</code>")
			table.insert(listparts, ", <code>|" .. p .. "3=</code>")
			table.insert(listparts, ", etc.")
		end
		table.insert(paramparts, table.concat(listparts))
	end
	local reqtext = required and "'''(required)'''" or "''(optional)''"
	return table.concat(paramparts, " or ") .. " " .. reqtext
end

function export.paramdoc(args)
	local parts = {}

	local function param_and_doc(params, list, required, doc)
		table.insert(parts, "; ")
		table.insert(parts, param(params, list, required))
		table.insert(parts, "\n")
		table.insert(parts, ": ")
		table.insert(parts, doc)
		table.insert(parts, "\n")
	end

	local tempname = template_name()
	local art = args.art or rfind(tempname, "^[aeiouAEIOU]") and "an" or "a"
	local sgdescof = args.sgdescof or art .. " " .. tempname
	table.insert(parts, "''Positional (unnamed) parameters:''\n")
	if args.lang then
		param_and_doc("1", false, true, "The term to link to (which this page is " .. sgdescof .. "). This should include any needed diacritics as appropriate to " .. lang_name(args.lang, "lang") .. ". These diacritics will automatically be stripped out in the appropriate fashion in order to create the link to the page.")
		param_and_doc("2", false, false, "The text to be shown in the link to the term. If empty or omitted, the term specified by the first parameter will be used. This parameter is normally not necessary, and should not be used solely to indicate diacritics; instead, put the diacritics in the first parameter.")
	else
		param_and_doc("1", false, true, "The [[WT:LANGCODE|language code]] of the term linked to (which this page is " .. sgdescof .. "). See [[Wiktionary:List of languages]]. <small>The parameter <code>|lang=</code> is a deprecated synonym; please do not use. If this is used, all numbered parameters move down by one.</small>")
		param_and_doc("2", false, true, "The term to link to (which this page is " .. sgdescof .. "). This should include diacritics as appropriate to the language (e.g. accents in Russian to mark the stress, vowel diacritics in Arabic, macrons in Latin to indicate vowel length, etc.). These diacritics will automatically be stripped out in a language-specific fashion in order to create the link to the page.")
		param_and_doc("3", false, false, "The text to be shown in the link to the term. If empty or omitted, the term specified by the second parameter will be used. This parameter is normally not necessary, and should not be used solely to indicate diacritics; instead, put the diacritics in the second parameter.")
	end
	table.insert(parts, "''Named parameters:''\n")
	if args.etymtemp == 'contraction' then
		param_and_doc("mandatory", false, false, "If <code>|mandatory=1</code>, indicates that the contraction is mandatory.")
		param_and_doc("optional", false, false, "If <code>|optional=1</code>, indicates that the contraction is optional.")
	end
	param_and_doc({"t", args.lang and "3" or "4"}, false, false, "A gloss or short translation of the term linked to. <small>The parameter <code>|gloss=</code> is a deprecated synonym; please do not use.</small>")
	param_and_doc("tr", false, false, "Transliteration for non-Latin-script terms, if different from the automatically-generated one.")
	param_and_doc("ts", false, false, "Transcription for non-Latin-script terms whose transliteration is markedly different from the actual pronunciation. Should not be used for IPA pronunciations.")
	param_and_doc("sc", false, false, "Script code to use, if script detection does not work. See [[Wiktionary:Scripts]].")
	if args.withfrom then
		param_and_doc("from", true, false, "A label (see " .. m_template_link.format_link({"label"}) .. ") that gives additional information on the dialect that the term belongs to, the place that it originates from, or something similar.")
	end
	if args.withdot then
		param_and_doc("dot", false, false, "A character to replace the final dot that is normally shown automatically.")
		param_and_doc("nodot", false, false, "If <code>|nodot=1</code>, then no automatic dot will be shown.")
	end
	if args.withcap then
		param_and_doc("nocap", false, false, "If <code>|nocap=1</code>, then the first letter will be in lowercase.")
	end
	param_and_doc("id", false, false, "A sense id for the term, which links to anchors on the page set by the " .. m_template_link.format_link({"senseid"}) .. " template.")
	return table.concat(parts)
end

function export.usagedoc(args)
	local exlangs = {}
	for _, exlang in ipairs(args.exlang) do
		table.insert(exlangs, exlang)
	end
	table.insert(exlangs, 'en')
	table.insert(exlangs, 'de')
	table.insert(exlangs, 'ja')
	exlangs = m_table.removeDuplicates(exlangs)
	local sub = {}
	local langparts = {}
	for i, langcode in ipairs(exlangs) do
		table.insert(langparts, '<code>' .. langcode .. '</code> for ' .. lang_name(langcode, "exlang"))
	end
	sub.exlangs = m_table.serialCommaJoin(langparts, {conj = "or"})
	sub.tempname = template_name("preserve lang code")

	if args.lang then
		return strutils.format([===[
==Usage==
Use in the definition line, most commonly as follows:
 # {\op}{\op}{tempname}|<var><primary entry goes here></var>{\cl}{\cl}

===Parameters===
]===], sub) .. export.paramdoc(args)
	else
		return strutils.format([===[
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
	local shortcuts = #args.shortcut > 0 and require("Module:shortcut box").show(args.shortcut) or ""
	local introdoc = export.introdoc(args)
	local usagedoc = export.usagedoc(args)
	return docsubpage .. "\n" .. shortcuts .. introdoc .. "\n" .. usagedoc
end

function export.infldoc(args)
	args = m_table.shallowcopy(args)
	args.sgdesc = args.sgdesc or (args.art or "the") .. " " ..
		rsub(template_name(), " of$", "") .. (args.form and " " .. args.form or "")
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
	return tag_type_to_description[tag_type] or strutils.ucfirst(tag_type)
end

local function sort_by_first(namedata1, namedata2)
	return namedata1[1] < namedata2[1]
end

local function get_display_form(tag_set, lang)
	local norm_tag_sets = m_form_of.normalize_tag_set(tag_set, lang)
	if #norm_tag_sets == 1 then
		return m_form_of.get_tag_set_display_form(norm_tag_sets[1], lang)
	end
	-- If we have a conjoined shortcut that expands to multiple tag sets, display them using a numbered list.
	-- In order to do that inside a table we need a newline before the list.
	local display_forms = {}
	for _, norm_tag_set in ipairs(norm_tag_sets) do
		table.insert(display_forms, "\n# " .. m_form_of.get_tag_set_display_form(norm_tag_set, lang))
	end
	return table.concat(display_forms)
end

local function organize_tag_data(data_module)
	local tab = {}
	for name, data in pairs(data_module.tags) do
		if not data.tag_type then
			-- Throw an error because hopefully it will get noticed and fixed. If we just skip it, it may never get
			-- fixed.
			error("Tag '" .. name .. "' has no tag_type")
		end
		if not tab[data.tag_type] then
			tab[data.tag_type] = {}
		end
		table.insert(tab[data.tag_type], {name, data})
	end
	local tag_type_order_set = m_table.listToSet(tag_type_order)
	for tag_type, tags_of_type in pairs(tab) do
		if not tag_type_order_set[tag_type] then
			-- See justification above for throwing an error.
			error("Tag type '" .. tag_type .. "' not listed in tag_type_order")
		end
		table.sort(tags_of_type, sort_by_first)
	end

	return tab
end

function export.tagtable()
	local data_tab = organize_tag_data(mw.loadData(m_form_of.form_of_data_module))
	local data2_tab = organize_tag_data(mw.loadData(m_form_of.form_of_data2_module))

	local parts = {}

	local function ins(text)
		table.insert(parts, text)
	end

	local function insert_group(group)
		for _, namedata in ipairs(group) do
			local sparts = {}
			local name, data = unpack(namedata)
			table.insert(sparts, "| <code>" .. name .. "</code> || ")
			if data.shortcuts then
				local ssparts = {}
				for _, shortcut in ipairs(data.shortcuts) do
					table.insert(ssparts, "<code>" .. shortcut .. "</code>")
				end
				table.insert(sparts, table.concat(ssparts, ", ") .. " ")
			end
			table.insert(sparts, "|| " .. m_form_of.get_tag_display_form(name))
			ins("|-")
			ins(table.concat(sparts))
		end
	end

	ins('{|class="wikitable"')
	ins("! Canonical tag !! Shortcut(s) !! Display form")
	for _, tag_type in ipairs(tag_type_order) do
		local group_tab = data_tab[tag_type]
		if group_tab then
			ins("|-")
			ins('! colspan="3" style="text-align: center; background: #dddddd;" | ' ..  tag_type_desc(tag_type) ..
				" (more common)")
			insert_group(group_tab)
		end
		group_tab = data2_tab[tag_type]
		if group_tab then
			ins("|-")
			ins('! colspan="3" style="text-align: center; background: #dddddd;" | ' ..  tag_type_desc(tag_type) ..
				" (less common)")
			insert_group(group_tab)
		end
	end
	ins("|}")

	return table.concat(parts, "\n")
end

local function organize_non_alias_shortcut_data(data_module, lang)
	local non_alias_shortcuts = {}
	for shortcut, full in pairs(data_module.shortcuts) do
		if type(full) == "table" or m_form_of.is_link_or_html(full) or full:find("//") or full:find(":") then
			table.insert(non_alias_shortcuts, {shortcut, full, get_display_form({shortcut}, lang)})
		end
	end

	table.sort(non_alias_shortcuts, sort_by_first)

	return non_alias_shortcuts
end

function export.non_alias_shortcut_table()
	local non_alias_shortcuts = organize_non_alias_shortcut_data(mw.loadData(m_form_of.form_of_data_module))
	local non_alias_shortcuts2 = organize_non_alias_shortcut_data(mw.loadData(m_form_of.form_of_data2_module))

	local parts = {}

	local function ins(text)
		table.insert(parts, text)
	end

	local function insert_shortcut_group(shortcuts)
		for _, spec in ipairs(shortcuts) do
			local shortcut, full, display = unpack(spec)
			ins("|-")
			if type(full) == "table" then
				-- Grrr. table.concat() doesn't work on a table that comes from loadData(); use shallowcopy() to convert to
				-- regular table.
				full = "{" .. table.concat(m_table.shallowcopy(full), " ") .. "}"
			end
			ins(("| <code>%s</code> || <code>%s</code> || %s"):format(shortcut, full, display))
		end
	end

	ins('{|class="wikitable"')
	ins("! Shortcut !! Expansion !! Display form")
	if #non_alias_shortcuts > 0 then
		ins("|-")
		ins('! colspan="3" style="text-align: center; background: #dddddd;" | More common:')
		insert_shortcut_group(non_alias_shortcuts)
	end
	if #non_alias_shortcuts2 > 0 then
		ins("|-")
		ins('! colspan="3" style="text-align: center; background: #dddddd;" | Less common:')
		insert_shortcut_group(non_alias_shortcuts2)
	end
	ins("|}")

	return table.concat(parts, "\n")
end


function export.lang_specific_tables()
	local parts = {}

	local function ins(text)
		table.insert(parts, text)
	end

	local data_by_lang = {}

	for langcode, _ in pairs(m_form_of.langs_with_lang_specific_tags) do
		local lang = m_languages.getByCode(langcode, true)
		local data_module = mw.loadData(m_form_of.form_of_lang_data_module_prefix .. langcode)

		-- First do inflection tags.
		local data_tab = organize_tag_data(data_module)
		local tag_parts = {}
		local function ins(text)
			table.insert(tag_parts, text)
		end
		ins('{|class="wikitable"')
		ins("! Canonical tag !! Shortcut(s) !! Tag type !! Display form")
		local saw_any_tag = false
		for _, tag_type in ipairs(tag_type_order) do
			local group_tab = data_tab[tag_type]
			if group_tab then
				for _, namedata in ipairs(group_tab) do
					local sparts = {}
					local name, data = unpack(namedata)
					table.insert(sparts, "| <code>" .. name .. "</code> || ")
					if data.shortcuts then
						local ssparts = {}
						for _, shortcut in ipairs(data.shortcuts) do
							table.insert(ssparts, "<code>" .. shortcut .. "</code>")
						end
						table.insert(sparts, table.concat(ssparts, ", ") .. " ")
					end
					table.insert(sparts, "|| " .. tag_type_desc(tag_type) .. " || " ..
						m_form_of.get_tag_display_form(name, lang))
					ins("|-")
					ins(table.concat(sparts))
					saw_any_tag = true
				end
			end
		end
		ins("|}")

		local tag_table = saw_any_tag and table.concat(tag_parts, "\n") or nil

		-- Then do non-alias shortcuts.
		local non_alias_shortcut_table
		local non_alias_shortcuts = organize_non_alias_shortcut_data(data_module, lang)
		if #non_alias_shortcuts > 0 then
			local non_alias_shortcut_parts = {}
			local function ins(text)
				table.insert(non_alias_shortcut_parts, text)
			end
			ins('{|class="wikitable"')
			ins("! Shortcut !! Expansion !! Display form")
			for _, spec in ipairs(non_alias_shortcuts) do
				local shortcut, full, display = unpack(spec)
				ins("|-")
				if type(full) == "table" then
					-- Grrr. table.concat() doesn't work on a table that comes from loadData(); use shallowcopy() to
					-- convert to regular table.
					full = "{" .. table.concat(m_table.shallowcopy(full), " ") .. "}"
				end
				ins(("| <code>%s</code> || <code>%s</code> || %s"):format(shortcut, full, display))
			end
			ins("|}")
			non_alias_shortcut_table = table.concat(non_alias_shortcut_parts, "\n")
		end

		if tag_table or non_alias_shortcut_table then
			local langname = lang:getCanonicalName()
			local lang_parts = {}
			local function ins(text)
				table.insert(lang_parts, text)
			end
			ins("===" .. langname .. "===")
			if tag_table then
				ins(("%s-specific inflection tags:"):format(langname))
				ins(tag_table)
			end
			if non_alias_shortcut_table then
				ins(("%s-specific non-alias shortcuts:"):format(langname))
				ins(non_alias_shortcut_table)
			end
			table.insert(data_by_lang, {langname, table.concat(lang_parts, "\n")})
		end
	end

	local function sort_by_first_english_first(langdata1, langdata2)
		if langdata1[1] == "English" then
			-- English is "less than" (goes before) all other languages
			return true
		elseif langdata2[1] == "English" then
			-- All other languages are not "less than" (do not go before) English
			return false
		else
			return langdata1[1] < langdata2[1]
		end
	end

	table.sort(data_by_lang, sort_by_first_english_first)

	local parts = {}
	for _, lang_and_data in ipairs(data_by_lang) do
		table.insert(parts, lang_and_data[2])
	end
	return table.concat(parts, "\n")
end

function export.postable()
	m_pos = mw.loadData(m_form_of.form_of_pos_module)
	local shortcut_tab = {}
	for shortcut, full in pairs(m_pos) do
		if not shortcut_tab[full] then
			shortcut_tab[full] = {}
		end
		table.insert(shortcut_tab[full], shortcut)
	end
	local shorcut_list = {}
	for full, shortcuts in pairs(shortcut_tab) do
		table.sort(shortcuts)
		table.insert(shorcut_list, {full, shortcuts})
	end
	table.sort(shorcut_list, function(fs1, fs2) return fs1[1] < fs2[1] end)

	local parts = {}
	table.insert(parts, '{|class="wikitable"')
	table.insert(parts, "! Canonical part of speech !! Shortcut(s)")
	for _, full_shortcuts in ipairs(shorcut_list) do
		local full = full_shortcuts[1]
		local shortcuts = full_shortcuts[2]
		table.insert(parts, "|-")
		local sparts = {}
		for _, shortcut in ipairs(shortcuts) do
			table.insert(sparts, "<code>" .. shortcut .. "</code>")
		end
		table.insert(parts, "| <code>" .. full .. "</code> || " .. table.concat(sparts, ", "))
	end
	table.insert(parts, "|}")
	return table.concat(parts, "\n")
end

function export.cattable()
	local m_cats = mw.loadData(m_form_of.form_of_cats_module)
	local cats_by_lang = {}
	local function find_categories(catstruct)
		local cats = {}

		local function process_spec(spec)
			if type(spec) == "string" then
				table.insert(cats, spec)
				return
			elseif not spec or spec == true or spec.labels then
				-- Ignore labels, etc.
				return
			elseif type(spec) ~= "table" then
				error("Wrong type of condition " .. spec .. ": " .. type(spec))
			end
			local predicate = spec[1]
			if predicate == "multi" or predicate == "cond" then
				-- WARNING! #spec doesn't work for objects loaded from loadData()
				for i, sp in ipairs(spec) do
					if i > 1 then
						process_spec(sp)
					end
				end
			elseif predicate == "pexists" then
				process_spec(spec[2])
				process_spec(spec[3])
			elseif predicate == "has" or predicate == "hasall" or predicate == "hasany" or
				predicate == "tags=" or predicate == "p=" or predicate == "pany" or
				predicate == "not" then
				process_spec(spec[3])
				process_spec(spec[4])
			elseif predicate == "and" or predicate == "or" then
				process_spec(spec[3])
				process_spec(spec[4])
			elseif predicate == "call" then
				return
			else
				error("Unrecognized predicate: " .. predicate)
			end
		end

		for _, spec in ipairs(catstruct) do
			process_spec(spec)
		end
		return cats
	end

	for lang, catspecs in pairs(m_cats) do
		local cats = find_categories(catspecs)
		table.insert(cats_by_lang, {lang, cats})
	end
	table.sort(cats_by_lang, sort_by_first)

	local lang_independent_cat_index = nil
	for i, langcats in ipairs(cats_by_lang) do
		local lang = langcats[1]
		if lang == "und" then
			lang_independent_cat_index = i
			break
		end
	end
	if lang_independent_cat_index then
		local lang_independent_cats = table.remove(cats_by_lang, lang_independent_cat_index)
		table.insert(cats_by_lang, 1, lang_independent_cats)
	end

	local parts = {}	
	table.insert(parts, '{|class="wikitable"')

	for i, langcats in ipairs(cats_by_lang) do
		local langcode = langcats[1]
		local cats = langcats[2]
		if #cats > 0 then
			if i > 1 then
				table.insert(parts, "|-")
			end
			if langcode == "und" then
				table.insert(parts, '! style="text-align: center; background: #dddddd;" | Language-independent')
			else
				local lang = m_languages.getByCode(langcode) or error("Unrecognized language code: " .. langcode)
				table.insert(parts, '! style="text-align: center; background: #dddddd;" | ' .. lang:getCanonicalName())
			end
			for _, cat in ipairs(cats) do
				table.insert(parts, "|-")
				table.insert(parts, "| <code>" .. cat .. "</code>")
			end
		end
	end
	table.insert(parts, "|}")
	return table.concat(parts, "\n")
end

return export
