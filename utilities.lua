local mw = mw
local mw_text = mw.text
local package = package
local table = table

local require = require
local concat = table.concat
local decode_entities = require("Module:string utilities").decode_entities
local get_current_frame = mw.getCurrentFrame
local insert = table.insert
local ipairs = ipairs
local maxn = table.maxn
local tonumber = tonumber
local trim = mw_text.trim
local type = type
local unstrip = mw_text.unstrip
local unstripNoWiki = mw_text.unstripNoWiki

local export = {}

do
	local loaded = package.loaded
	local loader = package.loaders[2]
	
	--[==[
	Like require, but return false if a module does not exist instead of throwing an error.
	Outputs are cached in {package.loaded}, which is faster for all module types, but much faster for nonexistent modules since require will attempt to use the full loader each time (since they don't get cached in {package.loaded}).
	Note: although nonexistent modules are cached as {false} in {package.loaded}, they still won't work with conventional require, since it uses a falsy check instead of checking the return value is not {nil}.
	]==]
	function export.safe_require(modname)
		local module = loaded[modname]
		if module ~= nil then
			return module
		end
		-- The loader returns a function if the module exists, or nil if it doesn't, and checking this is faster than using pcall with require. If found, we still use require instead of loading and caching directly, because require contains safety checks against infinite loading loops (and we do want those to throw an error).
		module = loader(modname)
		if module then
			return require(modname)
		end
		loaded[modname] = false
		return false
	end
end

--[==[
Convert decimal to hexadecimal.

Note: About three times as fast as the hex library.
]==]
function export.dec_to_hex(dec)
	dec = tonumber(dec)
	if not dec or dec % 1 ~= 0 then
		error("Input should be a decimal integer.")
	end
	return ("%x"):format(dec):upper()
end

do
	local function check_level(lvl)
		if type(lvl) ~= "number" then
			error("Heading levels must be numbers.")
		elseif lvl < 1 or lvl > 6 or lvl % 1 ~= 0 then
			error("Heading levels must be integers between 1 and 6.")
		end
		return lvl
	end
	
	--[==[
	A helper function which iterates over the headings in `text`, which should be the content of a page or (main) section.
	
	Each iteration returns three values: `sec` (the section title), `lvl` (the section level) and `loc` (the index of the section in the given text, from the first equals sign). The section title will be automatically trimmed, and any HTML entities will be resolved.
	The optional parameter `a` (which should be an integer between 1 and 6) can be used to ensure that only headings of the specified level are iterated over. If `b` is also given, then they are treated as a range.
	The optional parameters `a` and `b` can be used to specify a range, so that only headings with levels in that range are returned. If only `a` is given ...
	]==]
	function export.find_headings(text, a, b)
		a = a and check_level(a) or nil
		b = b and check_level(b) or a or nil
		local start, loc, lvl, sec = 1
		
		return function()
			repeat
				loc, lvl, sec, start = text:match("()%f[^%z\n](==?=?=?=?=?)([^\n]+)%2[\t ]*%f[%z\n]()", start)
				lvl = lvl and #lvl
			until not (sec and a) or (lvl >= a and lvl <= b)
			return sec and trim(decode_entities(sec)) or nil, lvl, loc
		end
	end
	
	local function get_section(content, name, level)
		if not (content and name) then
			return nil
		elseif name:find("\n", 1, true) then
			error("Heading name cannot contain a newline.")
		end
		level = level and check_level(level) or nil
		name = trim(decode_entities(name))
		local start
		for sec, lvl, loc in export.find_headings(content, level and 1 or nil, level) do
			if start and lvl <= level then
				return content:sub(start, loc - 1)
			elseif not start and (not level or lvl == level) and sec == name then
				start, level = loc, lvl
			end
		end
		return start and content:sub(start)
	end
	
	--[==[
	A helper function to return the content of a page section.
	
	`content` is raw wikitext, `name` is the requested section, and `level` is an optional parameter that specifies
	the required section heading level. If `level` is not supplied, then the first section called `name` is returned.
	`name` can either be a string or table of section names. If a table, each name represents a section that has the
	next as a subsection. For example, { {"Spanish", "Noun"}} will return the first matching section called "Noun"
	under a section called "Spanish". These do not have to be at adjacent levels ("Noun" might be L4, while "Spanish"
	is L2). If `level` is given, it refers to the last name in the table (i.e. the name of the section to be returned).
	
	The returned section includes all of its subsections. If no matching section is found, return {nil}.
	]==]
	function export.get_section(content, names, level)
		if type(names) == "string" then
			return get_section(content, names, level)
		end
		local names_len = maxn(names)
		if names_len > 6 then
			error("Not possible specify more than 5 subsections: headings only go up to level 6.")
		end
		for i, name in ipairs(names) do
			content = get_section(content, name, i == names_len and level or nil)
		end
		return content
	end
end

--[==[
A function which returns the number of the page section which contains the current {#invoke}.
]==]
function export.get_current_section()
	local frame = get_current_frame()
	-- We determine the section via the heading strip marker count, since they're numbered sequentially, but the only way to do this is to generate a fake heading via frame:preprocess(). The native parser assigns each heading a unique marker, but frame:preprocess() will return copies of older markers if the heading is identical to one further up the page, so the fake heading has to be unique to the page. The best way to do this is to feed it a heading containing a nowiki marker (which we will need later), since those are always unique.
	local nowiki_marker = frame:extensionTag("nowiki")
	-- Note: heading strip markers have a different syntax to the ones used for tags.
	local h = tonumber(frame:preprocess("=" .. nowiki_marker .. "=")
		:match("\127'\"`UNIQ%-%-h%-(%d+)%-%-QINU`\"'\127"))
	-- For some reason, [[Special:ExpandTemplates]] doesn't generate a heading strip marker, so if that happens we simply abort early.
	if not h then
		return 0
	end
	-- The only way to get the section number is to increment the heading count, so we store the offset in nowiki strip markers which can be retrieved by procedurally unstripping nowiki markers, counting backwards until we find a match.
	local n, offset = tonumber(nowiki_marker:match("\127'\"`UNIQ%-%-nowiki%-([%dA-F]+)%-QINU`\"'\127"), 16)
	while not offset and n > 0 do
		n = n - 1
		offset = unstripNoWiki(("\127'\"`UNIQ--nowiki-%08X-QINU`\"'\127"):format(n))
			:match("^HEADING\1(%d+)") -- Prefix "HEADING\1" prevents collisions.
	end
	offset = offset and (offset + 1) or 0
	frame:extensionTag("nowiki", "HEADING\1" .. offset)
	return h - offset
end

do
	local page_L2s
	
	--[==[
	A function which returns the name of the L2 language section which contains the current {#invoke}.
	]==]
	function export.get_current_L2()
		local section = export.get_current_section()
		if section == 0 then
			return nil
		end
		page_L2s = page_L2s or mw.loadData("Module:headword/data").page.page_L2s
		local L2 = page_L2s[section]
		while not L2 and section > 0 do
			section = section - 1
			L2 = page_L2s[section]
		end
		return L2
	end
end

--[==[
A helper function to strip wiki markup, giving the plaintext of what is displayed on the page.
]==]
function export.get_plaintext(text)
	text = text
		:gsub("%[%[", "\1")
		:gsub("%]%]", "\2")
	
	-- Remove strip markers and HTML tags.
	text = unstrip(text):gsub("<[^<>\1\2]+>", "")
		
	-- Parse internal links for the display text, and remove categories.
	text = require("Module:links").remove_links(text)
	
	-- Remove files.
	for _, falsePositive in ipairs({"File", "Image"}) do
		text = text:gsub("\1" .. falsePositive .. ":[^\1\2]+\2", "")
	end

	-- Parse external links for the display text.
	text = text:gsub("%[(https?://[^%[%]]+)%]",
		function(capture)
			return capture:match("https?://[^%s%]]+%s([^%]]+)") or ""
		end)
		-- Any remaining square brackets aren't involved in links, but must be escaped to avoid creating new links.
		:gsub("\1", "&#91;&#91;")
		:gsub("\2", "&#93;&#93;")
		:gsub("%[", "&#91;")
		:gsub("]", "&#93;")
		-- Strip bold, italics and soft hyphens.
		:gsub("('*)'''(.-'*)'''", "%1%2")
		:gsub("('*)''(.-'*)''", "%1%2")
		:gsub("­", "")
	
	-- Get any HTML entities.
	-- Note: don't decode URL percent encoding, as it shouldn't be used in display text and may cause problems if % is used.
	text = decode_entities(text)
	
	return trim(text)
end

do
	local title_obj, category_namespaces, page_data, pagename, pagename_defaultsort
	--[==[
	Format the categories with the appropriate sort key.
	* `categories` is a list of categories.
	* `lang` is an object encapsulating a language; if {nil}, the object for language code {"und"} (undetermined) will
	  be used.
	* `sort_key` is placed in the category invocation, and indicates how the page will sort in the respective category.
	  Normally this should be {nil}, and a default sort key based on the subpage name (the part after the colon) will
	  be used.
	* `sort_base` lets you override the default sort key used when `sort_key` is {nil}. Normally, this should be {nil},
	  and a language-specific default sort key is computed from the subpage name. For example, for Russian this converts
	  Cyrillic ё to a string consisting of Cyrillic е followed by U+10FFFF, so that effectively ё sorts after е instead
	  of the default Wikimedia sort, which (I think) is based on Unicode sort order and puts ё after я, the last letter
	  of the Cyrillic alphabet.
	* `force_output` forces normal output in all namespaces. Normally, nothing is output if the page isn't in the main,
	  Appendix:, Thesaurus:, Reconstruction: or Citations: namespaces.
	* `sc` is a script object; if nil, the default will be used from the sort base.
	]==]
	function export.format_categories(categories, lang, sort_key, sort_base, force_output, sc)
		if type(lang) == "table" and not lang.getCode then
			error("The second argument to format_categories should be a language object.")
		end
		
		title_obj = title_obj or mw.title.getCurrentTitle()
		category_namespaces = category_namespaces or mw.loadData("Module:utilities/data").category_namespaces
		
		if not (
			force_output or
			category_namespaces[title_obj.namespace] or
			title_obj.prefixedText == "Wiktionary:Sandbox"
		) then
			return ""
		elseif not page_data then
			page_data = mw.loadData("Module:headword/data").page
			pagename = page_data.encoded_pagename
			pagename_defaultsort = page_data.pagename_defaultsort
		end
		
		-- Generate a default sort key.
		-- If the sort key is "-", bypass the process of generating a sort key altogether. This is desirable when categorising (e.g.) translation requests, as the pages to be categorised are always in English/Translingual.
		if sort_key == "-" then
			sort_key = sort_base and sort_base:uupper() or pagename_defaultsort
		else
			lang = lang or require("Module:languages").getByCode("und")
			sort_base = lang:makeSortKey(sort_base or pagename, sc) or pagename_defaultsort
			if not sort_key or sort_key == "" then
				sort_key = sort_base
			elseif lang:getCode() ~= "und" then
				insert(categories, lang:getFullName() .. " terms with " .. (
					sort_key:uupper() == sort_base and "redundant" or
					"non-redundant non-automated"
				) .. " sortkeys")
			end
		end
		
		local ret = {}
		for key, cat in ipairs(categories) do
			ret[key] = "[[Category:" .. cat .. "|" .. sort_key .. "]]"
		end
		
		return concat(ret)
	end
end

do
	local catfix_scripts

	--[==[
	Add a "catfix", which is used on language-specific category pages to add language attributes and often script
	classes to all entry names. The addition of language attributes and script classes makes the entry names display
	better (using the language- or script-specific styles specified in [[MediaWiki:Common.css]]), which is particularly
	important for non-English languages that do not have consistent font support in browsers.

	Language attributes are added for all languages, but script classes are only added for languages with one script
	listed in their data file, or for languages that have a default script listed in the {catfix_script} list in
	[[Module:utilities/data]]. Some languages clearly have a default script, but still have other scripts listed in
	their data file and therefore need their default script to be specified. Others do not have a default script.

	* Serbo-Croatian is regularly written in both the Latin and Cyrillic scripts. Because it uses two scripts,
	  Serbo-Croatian cannot have a script class applied to entries in its category pages, as only one script class
	  can be specified at a time.
	* Russian is usually written in the Cyrillic script ({{cd|Cyrl}}), but Braille ({{cd|Brai}}) is also listed in
	  its data file. So Russian needs an entry in the {catfix_script} list, so that the {{cd|Cyrl}} (Cyrillic) script
	  class will be applied to entries in its category pages.

	To find the scripts listed for a language, go to [[Module:languages]] and use the search box to find the data file
	for the language. To find out what a script code means, search the script code in [[Module:scripts/data]].
	]==]
	function export.catfix(lang, sc)
		if not lang or not lang.getCanonicalName then
			error('The first argument to the function "catfix" should be a language object from [[Module:languages]] or [[Module:etymology languages]].')
		end
		if sc and not sc.getCode then
			error('The second argument to the function "catfix" should be a script object from [[Module:scripts]].')
		end
		local canonicalName = lang:getCanonicalName()
		local nonEtymologicalName = lang:getFullName()
	
		-- To add script classes to links on pages created by category boilerplate templates.
		if not sc then
			catfix_scripts = catfix_scripts or mw.loadData("Module:utilities/data").catfix_scripts
			sc = catfix_scripts[lang:getCode()] or catfix_scripts[lang:getFullCode()]
			if sc then
				sc = require("Module:scripts").getByCode(sc)
			end
		end
		
		local catfix_class = "CATFIX-" .. mw.uri.anchorEncode(canonicalName)
		if nonEtymologicalName ~= canonicalName then
			catfix_class = catfix_class .. " CATFIX-" .. mw.uri.anchorEncode(nonEtymologicalName)
		end
		return "<span id=\"catfix\" style=\"display:none;\" class=\"" .. catfix_class .. "\">" ..
			require("Module:script utilities").tag_text("&nbsp;", lang, sc, nil) ..
			"</span>"
	end
end

--[==[
Implementation of the {{tl|catfix}} template.
]==]
function export.catfix_template(frame)
	local params = {
		[1] = {},
		[2] = { alias_of = "sc" },
		["sc"] = {},
	}
	
	local args = require("Module:parameters").process(frame:getParent().args, params, nil, "utilities", "catfix_template")
	
	local lang = require("Module:languages").getByCode(args[1], 1, "allow etym")
	
	local sc = args.sc
	if sc then
		sc = require("Module:scripts").getByCode(sc, "sc")
	end
	
	return export.catfix(lang, sc)
end

--[==[
Given a type (as a string) and an arbitrary number of entities, checks whether all of those entities are language,
family, script, writing system or Wikimedia language objects. Useful for error handling in functions that require
one of these kinds of object.

If `noErr` is set, the function returns false instead of throwing an error, which allows customised error handling to
be done in the calling function.
]==]
function export.check_object(typ, noErr, ...)
	local function fail(message)
		if noErr then
			return false
		else
			error(message, 3)
		end
	end
	
	local objs = {...}
	if #objs == 0 then
		return fail("Must provide at least one object to check.")
	end
	for _, obj in ipairs(objs) do
		if type(obj) ~= "table" or type(obj.hasType) ~= "function" then
			return fail("Function expected a " .. typ .. " object, but received a " .. type(obj) .. " instead.")
		elseif not (typ == "object" or obj:hasType(typ)) then
			for _, wrong_type in ipairs{"family", "language", "script", "Wikimedia language", "writing system"} do
				if obj:hasType(wrong_type) then
					return fail("Function expected a " .. typ .. " object, but received a " .. wrong_type .. " object instead.")
				end
			end
			return fail("Function expected a " .. typ .. " object, but received another type of object instead.")
		end
	end
	return true
end

return export
