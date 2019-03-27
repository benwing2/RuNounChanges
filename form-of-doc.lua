local export = {}

local m_template_link = require("Module:template link")
local m_languages = require("Module:languages")
local m_table = require("Module:table")
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
	local lang = m_languages.getByCode(langcode) or m_languages.err(langcode, param)
	return lang:getCanonicalName()
end

local function ucfirst(text)
	return uupper(usub(text, 1, 1)) .. usub(text, 2)
end

local function template_name()
	local PAGENAME =  mw.title.getCurrentTitle().text
	return rsub(PAGENAME, "/documentation$", "")
end

function export.introdoc(args)
	local langname = args.lang and lang_name(args.lang, "lang")
	local exlangnames = {}
	for _, exlang in ipairs(args.exlang) do
		table.insert(exlangnames, lang_name(args.exlang, "exlang"))
	end
	parts = {}
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

This template is '''not''' meant to be used in etymology sections.

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
	else
		param_and_doc("1", false, true, "The [[WT:LANGCODE|language code]] of the term linked to (which this page is " .. sgdescof .. "). See [[Wiktionary:Languages]]. <small>The parameter <code>|lang=</code> is a deprecated synonym; please do not use. If this is used, all numbered parameters move down by one.</small>")
		param_and_doc("2", false, true, "The term to link to (which this page is " .. sgdescof .. "). This should include diacritics as appropriate to the language (e.g. accents in Russian to mark the stress, vowel diacritics in Arabic, macrons in Latin to indicate vowel length, etc.). These diacritics will automatically be stripped out in a language-specific fashion in order to create the link to the page.")
	end
	param_and_doc(args.lang and "2" or "3", false, false, "The text to be shown in the link to the term. If empty or omitted, the term specified by the second parameter will be used. This parameter is normally not necessary, and should not be used solely to indicate diacritics; instead, put the diacritics in the second parameter.")
	table.insert(parts, "''Named parameters:''\n")
	param_and_doc({"t", args.lang and "3" or "4"}, false, false, "A gloss or short translation of the term linked to. <small>The parameter <code>|gloss=</code> is a deprecated synonym; please do not use.</small>")
	param_and_doc("tr", false, false, "Transliteration for non-Latin-script terms, if different from the automatically-generated one.")
	param_and_doc("ts", false, false, "Transcription for non-Latin-script terms whose transliteration is markedly different from the actual pronunciation. Should not be used for IPA pronunciations.")
	param_and_doc("sc", false, false, "Script code to use, if script detection does not work. See [[Wiktionary:Scripts]].")
	if args.withfrom then
		param_and_doc("from", true, false, "A label (see " .. m_template_link.format_link({"label"}) .. " that gives additional information on the dialect that the term belongs to, the place that it originates from, or something similar.")
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
	sub.tempname = template_name()
	
	return strutils.format([===[
==Usage==
Use in the definition line, most commonly as follows:
 # {\op}{\op}{tempname}|<var><langcode></var>|<var><primary entry goes here></var>{\cl}{\cl}
where <code><var><langcode></var></code> is the [[Wiktionary:Languages|language code]], e.g. {exlangs}.

===Parameters===
]===], sub) .. export.paramdoc(args)
end

function export.fulldoc(args)
	local docsubpage = mw.getCurrentFrame():expandTemplate{title="documentation subpage", args={}}
	local shortcuts = #args.shortcut > 0 and require("Module:shortcut box").show(args.shortcut) or ""
	local introdoc = export.introdoc(args)
	local usagedoc = export.usagedoc(args)
	return docsubpage .. "\n" .. shortcuts .. introdoc .. "\n" .. usagedoc
end

function export.infldoc(args)
	args = require("Module:table").shallowcopy(args)
	args.sgdesc = args.sgdesc or (args.art or "the") .. " " ..
		rsub(template_name(), " of$", "") .. (args.form and " " .. args.form or "")
	args.pldesc = args.sgdesc
	args.sgdescof = args.sgdescof or args.sgdesc .. " of"
	args.primaryentrytext = args.primaryentrytext or "of a primary entry"
	return export.fulldoc(args)	
end

return export
