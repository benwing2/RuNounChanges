local decode = mw.text.decode
local u = mw.ustring.char

local data = mw.loadData("Module:utilities/data")
local notneeded = data.notneeded
local neededhassubpage = data.neededhassubpage

local export = {}

function export.require_when_needed(text)
	return setmetatable({}, {
		__index = function(t, k)
			t = require(text)
			return t[k]
		end,
		__call = function(t, ...)
			t = require(text)
			return t(...)
		end
	})
end

-- A helper function to escape magic characters in a string.
-- Magic characters: ^$()%.[]*+-?
function export.pattern_escape(text)
	if type(text) == "table" then
		text = text.args[1]
	end
	return (text:gsub("[%^$()%%.[%]*+%-?]", "%%%0"))
end

-- A helper function to resolve HTML entities into plaintext.
do
	local entities
	
	local function get_named_entity(entity)
		entities = entities or mw.loadData("Module:data/entities")
		return entities[entity]
	end
	
	-- Catches entities with capital X, which aren't supported by default.
	local function get_numbered_entity(entity)
		entity = entity:lower()
		local ret = decode(entity)
		if ret ~= entity then
			return ret
		end
	end
		
	function export.get_entities(text)
		return (text:gsub("&([^#&;]+);", get_named_entity)
			:gsub("&#[Xx]?%x+;", get_numbered_entity)
		)
	end
end

-- A helper function to convert plaintext into HTML entities where these match the characters given in set.
-- By default, this resolves any pre-existing entities into plaintext first, to allow mixed input and to avoid accidental double-conversion. This can be turned off with the raw parameter.
function export.make_entities(text, set, raw)
	text = not raw and export.get_entities(text) or text
	return mw.text.encode(text, set)
end

-- A helper function to return the content of a page section.
-- `content` is raw wikitext, `name` is the requested section, and `level` is an optional parameter that specifies the required section heading level. If `level` is not supplied, then the first section called `name` is returned.
-- `name` can either be a string or table of section names. If a table, each name represents a section that has the next as a subsection. For example, {"Spanish", "Noun"} will return the first matching section called "Noun" under a section called "Spanish". These do not have to be at adjacent levels ("Noun" might be L4, while "Spanish" is L2). If `level` is given, it refers to the last name in the table (i.e. the name of the section to be returned).
-- The returned section includes all of its subsections.
-- If no matching section is found, returns nil.
function export.get_section(content, names, level)
	local trim = mw.text.trim
	local function _section(content, name, level)
		if not (content and name) then
			return nil
		elseif level and level > 6 then
			error("Heading level cannot be greater than 6.")
		elseif name:find("[\n\r]") then
			error("Heading name cannot contain a newline.")
		end
		name = trim(name)
		local start
		for loc, lvl, sec in content:gmatch("()%f[^%z\n\r](=+)([^\n\r]+)%2[\t ]*%f[%z\n\r]") do
			lvl = #lvl
			if not start then
				if lvl > 6 then
					local ex = ("="):rep(lvl - 6)
					sec = ex .. sec .. ex
					lvl = 6
				end
				if (
					(not level or lvl == level) and
					trim(sec) == name
				) then
					start = loc
					level = lvl
				end
			elseif level == 6 or lvl <= level then
				return content:sub(start, loc - 1)
			end
		end
		return start and content:sub(start)
	end
	
	if type(names) == "string" then
		return _section(content, names, level)
	else
		local names_len = #names
		if names_len > 6 then
			error("Not possible specify more than 5 subsections: headings only go up to level 6.")
		end
		for i, name in ipairs(names) do
			if i == names_len then
				content = _section(content, name, level)
			else
				content = _section(content, name)
			end
		end
		return content
	end
end

-- A helper function to strip wiki markup, giving the plaintext of what is displayed on the page.
function export.get_plaintext(text)
	text = text
		:gsub("%[%[", "\1")
		:gsub("%]%]", "\2")
	
	-- Remove strip markers and HTML tags.
	text = mw.text.unstrip(text)
		:gsub("<[^<>\1\2]+>", "")
		
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
	
	text = text
		:gsub("\1", "[[")
		:gsub("\2", "]]")
	
	-- Any remaining square brackets aren't involved in links, but must be escaped to avoid creating new links.
	text = text:gsub("[%[%]]", mw.text.nowiki)
		
	-- Strip bold, italics and soft hyphens.
	text = text
		:gsub("('*)'''(.-'*)'''", "%1%2")
		:gsub("('*)''(.-'*)''", "%1%2")
		:gsub("­", "")
	
	-- Get any HTML entities.
	-- Note: don't decode URL percent encoding, as it shouldn't be used in display text and may cause problems if % is used.
	text = export.get_entities(text)
	
	return mw.text.trim(text)
end

function export.plain_gsub(text, pattern, replacement)
	local invoked = false
	
	if type(text) == "table" then
		invoked = true
		
		if text.args then
			local frame = text
			
			local params = {
				[1] = {},
				[2] = {},
				[3] = { allow_empty = true },
			}
			
			local args = require("Module:parameters").process(frame.args, params, nil, "utilities", "plain_gsub")
			
			text = args[1]
			pattern = args[2]
			replacement = args[3]
		else
			error("If the first argument to plain_gsub is a table, it should be a frame object.")
		end
	else
		if not ( type(pattern) == "string" or type(pattern) == "number" ) then
			error("The second argument to plain_gsub should be a string or a number.")
		end
		
		if not ( type(replacement) == "string" or type(replacement) == "number" ) then
			error("The third argument to plain_gsub should be a string or a number.")
		end
	end
	
	pattern = export.pattern_escape(pattern)
	
	local gsub = require("Module:string utilities").gsub
	if invoked then
		return (gsub(text, pattern, replacement))
	else
		return gsub(text, pattern, replacement)
	end
end

--[[
Format the categories with the appropriate sort key. CATEGORIES is a list of
categories.
	-- LANG is an object encapsulating a language; if nil, the object for
	   language code 'und' (undetermined) will be used.
	-- SORT_KEY is placed in the category invocation, and indicates how the
	   page will sort in the respective category. Normally this should be nil,
	   and a default sort key based on the subpage name (the part after the
	   colon) will be used.
	-- SORT_BASE lets you override the default sort key used when SORT_KEY is
	   nil. Normally, this should be nil, and a language-specific default sort
	   key is computed from the subpage name (e.g. for Russian this converts
	   Cyrillic ё to a string consisting of Cyrillic е followed by U+10FFFF,
	   so that effectively ё sorts after е instead of the default Wikimedia
	   sort, which (I think) is based on Unicode sort order and puts ё after я,
	   the last letter of the Cyrillic alphabet.
	-- FORCE_OUTPUT forces normal output in all namespaces. Normally, nothing
	   is output if the page isn't in the main, Appendix:, Reconstruction: or
	   Citations: namespaces.
	-- SC is a script object; if nil, the default will be used from the sort
	   base.
]]
function export.format_categories(categories, lang, sort_key, sort_base, force_output, sc)
	if type(lang) == "table" and not lang.getCode then
		error("The second argument to format_categories should be a language object.")
	end

	local title_obj = mw.title.getCurrentTitle()	
	local allowedNamespaces = {
		[0] = true, [100] = true, [110] = true, [114] = true, [118] = true -- (main), Appendix, Thesaurus, Citations, Reconstruction
	}

	if force_output or allowedNamespaces[title_obj.namespace] or title_obj.prefixedText == "Wiktionary:Sandbox" then
		local headword_data = mw.loadData("Module:headword/data")
		local pagename = headword_data.pagename
		local pagename_defaultsort = headword_data.pagename_defaultsort
		
		-- Generate a default sort key.
		if sort_key ~= "-" then
			if not lang then
				lang = require("Module:languages").getByCode("und")
			end
			sort_base = (lang:makeSortKey(sort_base or pagename, sc))
			if sort_key and sort_key ~= "" then
				-- Gather some statistics regarding sort keys
				if not no_track and sort_key:uupper() == sort_base then
					table.insert(categories, "Sort key tracking/redundant")
				end
			else
				sort_key = sort_base
			end
			-- If the sort key is empty, remove it.
			if sort_key == "" then
				sort_key = nil
			end
		-- If the sort key is "-", bypass the process of generating a sort key altogether. This is desirable when categorising (e.g.) translation requests, as the pages to be categorised are always in English/Translingual.
		else
			sort_key = sort_base and sort_base:uupper() or pagename_defaultsort
		end
		
		local out_categories = {}
		for key, cat in ipairs(categories) do
			out_categories[key] = "[[Category:" .. cat .. (sort_key and "|" .. sort_key or "") .. "]]"
		end
		
		return table.concat(out_categories, "")
	else
		return ""
	end
end

function export.catfix(lang, sc)
	if not lang then
		require("Module:debug").track("catfix/no lang")
		return nil
	elseif type(lang) ~= "table" then
		require("Module:debug").track("catfix/lang not table")
		return nil
	end
	local canonicalName = lang:getCanonicalName() or error('The first argument to the function "catfix" should be a language object from Module:languages.')
	
	if sc and not sc.getCode then
		error('The second argument to the function "catfix" should be a script object from Module:scripts.')
	end
	
	-- To add script classes to links on pages created by category boilerplate templates.
	if not sc then
		sc = data.catfix_scripts[lang:getCode()]
		if sc then
			sc = require("Module:scripts").getByCode(sc)
		end
	end
	
	return "<span id=\"catfix\" style=\"display:none;\" class=\"CATFIX-" .. mw.uri.anchorEncode(canonicalName) .. "\">" ..
		require("Module:script utilities").tag_text("&nbsp;", lang, sc, nil) ..
		"</span>"
end

function export.catfix_template(frame)
	local params = {
		[1] = {},
		[2] = { alias_of = "sc" },
		["sc"] = {},
	}
	
	local args = require("Module:parameters").process(frame:getParent().args, params, nil, "utilities", "catfix_template")
	
	local lang = require("Module:languages").getByCode(args[1]) or require("Module:languages").err(args[1], 1)
	
	local sc = args.sc
	if sc then
		sc = require("Module:scripts").getByCode(sc) or error('The script code "' .. sc .. '", provided in the second parameter, is not valid.')
	end
	
	return export.catfix(lang, sc)
end

-- Not exporting because it is not used yet.
local function getDateTense(frame) 
	local name_num_mapping = {["January"] = 1, ["February"] = 2, ["March"] = 3, ["April"] = 4, ["May"] = 5, ["June"] = 6, 
		["July"] = 7, ["August"] = 8, ["September"] = 9, ["October"] = 10, ["November"] = 11, ["December"] = 12, 
		[1] = 1, [2] = 2, [3] = 3, [4] = 4, [5] = 5, [6] = 6, [7] = 7, [8] = 8, [9] = 9, [10] = 10, [11] = 11, [12] = 12}
	local month = name_num_mapping[frame.args[2]]
	local date = os.time({year = frame.args[1], day = frame.args[3], month = month})
	local today = os.time() -- 12 AM/PM
	local diff = os.difftime(date, today)
	local daylength = 24 * 3600
	
	if diff < -daylength / 2 then return "past"
	else 
		if diff > daylength / 2  then return "future"
		else return "present" end
	end
end

function export.make_id(lang, str)
	--[[	If called with invoke, first argument is a frame object.
			If called by a module, first argument is a language object. ]]
	local invoked = false
	
	if type(lang) == "table" then
		if lang.args then
			invoked = true
			
			local frame = lang
			
			local params = {
				[1] = {},
				[2] = {},
			}
			
			local args = require("Module:parameters").process(frame:getParent().args, params, nil, "utilities", "make_id")
			
			local langCode = args[1]
			str = args[2]
			
			local m_languages = require("Module:languages")
			
			lang = m_languages.getByCode(langCode) or m_languages.err(langCode, 1)
		elseif not lang.getCanonicalName then
			error("The first argument to make_id should be a language object.")
		end
	end

	if not ( type(str) == "string" or type(str) == "number" ) then
		error("The second argument to make_id should be a string or a number.")
	end
	
	local id = require("Module:senseid").anchor(lang, str)
	
	if invoked then
		return '<li class="senseid" id="' .. id .. '">'
	else
		return id
	end
end

-- Given a type (as a string) and an arbitrary number of entities, checks whether all of those entities are language, family, script, writing system or Wikimedia language objects. Useful for error handling in functions that require one of these kinds of object.
-- If noErr is set, the function returns false instead of throwing an error, which allows customised error handling to be done in the calling function.
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
	for _, obj in ipairs{...} do
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
