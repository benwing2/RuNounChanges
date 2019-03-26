local export = {}

local m_template_link = require("Module:template link")
local m_languages = require("Module:languages")

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

local function join_list_with_comma_plus_and(els)
	if #els == 1 then
		return els[1]
	elseif #els == 2 then
		return els[1] .. " and " .. els[2]
	else
		local retval = {}
		for i, el in ipairs(els) do
			table.insert(retval, el)
			if i <= #els - 2 then
				table.insert(retval, ", ")
			elseif i == #els - 1 then
				table.insert(retval, "<span class=\"serial-comma\">,</span><span class=\"serial-and\"> and</span> ")
			end
		end
		return table.concat(retval, "")
	end
end

function export.introdoc(args)
	local langname = args.lang and lang_name(args.lang, "lang")
	local exlangname = args.exlang and lang_name(args.exlang, "exlang")
	parts = {}
	parts.append("This template creates a definition line for ")
	parts.append(args.pldesc or rsub(template_name(), " of$", "") .. "s")
	parts.append(" ")
	parts.append(args.primaryentrytext or "of primary entries")
	if args.lang then
		parts.append(" in " .. langname)
	elseif args.exlang then
		parts.append(", e.g. in " .. exlangname)
	end
	parts.append(".")
	if #args.cat > 0 then
		parts.append(" It also categorizes the page into ")
		local catparts = {}
		for _, cat in ipairs(args.cat) do
			if args.lang then
				catparts.append("[[:Category:" .. langname .. " " .. cat .. "]]")
			else
				catparts.append("the proper language-specific subcategory of [[:Category:" .. ucfirst(cat) .. " by language]] (e.g. [[:Category:" .. (exlangname or "English") .. " " .. cat .. "]])")
			end
		end
		parts.append(join_list_with_comma_plus_and(catparts))
		parts.append(".")
	end
	if args.addlintrotext then
		parts.append(" ")
		parts.append(args.addlintrotext)
	end
	parts.append("\n")
	parts.append([===[

This template is '''not''' meant to be used in etymology sections.

Note that users can customize how the output of this template displays by modifying their monobook.css files. See [[:Category:Form-of templates|“Form of” templates]] for details.
]===]
	return table.concat(parts)
end

local function param(params, list, required)
	local paramparts = {}
	if type(params) ~= "table" then
		params = {params}
	end
	for _, p in ipairs(params) do
		local listparts = {}
		listparts.append("<code>|" .. p .. "=</code>")
		if list then
			listparts.append(", <code>|" .. p .. "2=</code>")
			listparts.append(", <code>|" .. p .. "3=</code>")
			listparts.append(", etc.")
		end
		paramparts.append(table.concat(listparts))
	end
	local reqtext = required and "'''required'''" or "''(optional)''"
	return table.concat(paramparts, " or ") .. " " .. reqtext
end

function export.paramdoc(args)
	local parts = {}
	
	local function param_and_doc(params, list, required, doc)
		parts.append(": ")
		parts.append(param(params, list, required))
		parts.append("\n")
		parts.append("; ")
		parts.append(doc)
		parts.append("\n")
	end

	local art = args.art or rfind(PAGENAME, "^[aeiouAEIOU]") and "an" or "a"
	local sgdescwithart = args.sgdescwithart or art .. " " .. template_name()
	parts.append("''Positional (unnamed) parameters:''\n")
	param_and_doc("1", false, true, "The language code of the term linked to (which this page is " .. sgdescwithart .. "). See [[Wiktionary:Languages]].")
	param_and_doc("2", false, true, "The term to link to (which this page is " .. sgdescwithart .. "). This should include diacritics as appropriate to the language (e.g. accents in Russian to mark the stress, vowel diacritics in Arabic, macrons in Latin to indicate vowel length, etc.). These diacritics will automatically be stripped out in a language-specific fashion in order to create the link to the page.")
	param_and_doc("3", false, false, "The text to be shown in the link to the term. If empty or omitted, the term specified by the second parameter will be used. This parameter is normally not necessary, and should not be used solely to indicate diacritics; instead, put the diacritics in the second parameter.")
	parts.append("''Named parameters:''")
	param_and_doc({"t", "4"}, false, false, "A gloss or short translation of the term linked to.")
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
	if args.exlang then
		table.insert(exlangs, args.exlang)
	end
	ut.insert_if_not(exlangs, 'en')
	ut.insert_if_not(exlangs, 'de')
	ut.insert_if_not(exlangs, 'ja')
	local sub = {}
	local langparts = {}
	for i, langcode in ipairs(exlangs) do
		table.insert(langparts, '<code>' .. langcode .. '</code> for ' .. lang_name(langcode, "exlang"))
	end
	sub.exlangs = join_list_with_comma_plus_and(langparts)
	sub.tempname = template_name()
	
	return [===[
==Usage==
Use in the definition line, most commonly as follows:
 <nowiki># {\op}{\op}</nowiki>{tempname}|<var><langcode></var>|<var><primary entry goes here></var>{\cl}{\cl}
where <code><var><langcode></var></code> is the [[Wiktionary:Languages|language code]], e.g. {exlangs}.

===Parameters===
]===]] .. export.paramdoc(args)
end

function export.fulldoc(args)
	local docsubpage = mw.getCurrentFrame():expandTemplate{title="documentation subpage", args={}}
	local shortcuts = #args.shortcuts > 0 and require("Module:shortcut box").show(args.shortcuts) or ""
	local introdoc = export.introdoc(args)
	local usagedoc = export.usagedoc(args)
	return docsubpage .. "\n" .. shortcuts .. introdoc .. "\n\n" .. usagedoc
end

function export.infldoc(args)


return export