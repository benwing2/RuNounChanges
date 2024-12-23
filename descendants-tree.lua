local export = {}

local alternative_forms_module = "Module:alternative forms"
local string_utilities_module = "Module:string utilities"

local remove_comments = require(string_utilities_module).remove_comments

local function track(page)
	--[[Special:WhatLinksHere/Wiktionary:Tracking/descendants tree/PAGE]]
	return require("Module:debug/track")("descendants tree/" .. page)
end


local function preview_error(what, entry_name, language_name, reason)
	mw.log("Could not retrieve " .. what .. " for " .. language_name .. " in the entry [["
			.. entry_name .. "]]: " .. reason .. ".")
	track(what .. " error")
end

local function get_content_after_senseid(content, entry_name, lang, id)
	local m_templateparser = require("Module:template parser")
	local code = lang:getFullCode()
	local t_start = nil
	local t_end = nil
	for name, args, _, index in m_templateparser.findTemplates(content) do
		if name == "senseid" and args[1] == code and args[2] == id then
			t_start = index
		elseif name == "etymid" then
			if args[1] == code and args[2] == id then
				t_start = index
			elseif t_start ~= nil and t_end == nil then
				t_end = index
			end
		elseif name == "head" and args[1] == code then
			if args["id"] == id then
				t_start = index
			elseif args["id"] ~= nil and t_start ~= nil and t_end == nil then
				t_end = index
			end
		end
	end
	
	if t_start == nil then
		error("Could not find the correct senseid template in the entry [["
		.. entry_name .. "]] (with language " .. code .. " and id '" .. id .. "')")
	end
	
	if t_end == nil then
		-- terminate on L2 or another "Etymology ..." header
		-- match L2 and remove it and everything after it
		content = string.gsub(content:sub(t_start), "\n==[^=].+$", "")
		-- match Etymology header and remove it and everything after it
		content = string.gsub(content, "\n===+%s*Etymology.+$", "")
		return content
	end
	
	return content:sub(t_start, t_end)
end

function export.get_alternative_forms(lang, entry_name, id, default_separator)
	local page = mw.title.new(entry_name)
	local content = page:getContent()

	local function alt_form_error(reason)
		preview_error("alternative forms", entry_name, lang:getFullName(), reason)
	end
	
	if not content then
		-- FIXME, should be an error
		alt_form_error("nonexistent page")
		track("alts-nonexistent-page")
		return ""
	end
	
	local _, index = string.find(content,
		"==[ \t]*" .. require(string_utilities_module).pattern_escape(lang:getFullName()) .. "[ \t]*==")
	
	if not index then
		-- FIXME, should be an error
		alt_form_error("L2 header for language not found")
		track("alts-lang-not-found")
		return ""
	end

	if id then
		content = get_content_after_senseid(content, entry_name, lang, id)
		index = 0
	end
	
	local _, next_lang = string.find(content, "\n==[^=\n]+==", index, false)
	local _, index = string.find(content, "\n(====?=?)[ \t]*Alternative forms[ \t]*%1", index, false)
	if not index then
		_, index = string.find(content, "\n(====?=?)[ \t]*Alternative reconstructions[ \t]*%1", index, false)
	end

	if not index then
		-- FIXME, should be an error
		alt_form_error("'Alternative forms' section for language not found")
		track("alts-section-not-found")
		return ""
	end

	local langCodeRegex = require(string_utilities_module).pattern_escape(lang:getFullCode())
	index = string.find(content, "{{alte?r?|" .. langCodeRegex .. "|[^|}]+", index)
	if (not index) or (next_lang and next_lang < index) then
		-- FIXME, should be an error
		alt_form_error("no 'alt' or 'alter' template in 'Alternative forms' section for language")
		track("alts-alter-not-found")
		return ""
	end
	
	local next_section = string.find(content, "\n(=+)[^=]+%1", index)
	
	local alternative_forms_section = string.sub(content, index, next_section)
	
	local terms_list = {}

	local altforms = require("Module:alternative forms")

	for name, args, _, index in require("Module:template parser").findTemplates(alternative_forms_section) do
		if name == "alter" and args[1] == lang:getFullCode() then
			saw_alter = true
			local formatted_altforms = altforms.display_alternative_forms(args, entry_name, "allow self link",
				default_separator)
			table.insert(terms_list, formatted_altforms)
		end
	end

	if #terms_list == 0 then
		-- FIXME, should be an error
		alt_form_error("no terms in 'alt' or 'alter' template in 'Alternative forms' section for language")
		track("alts-no-terms-in-alter")
		return ""
	end

	return table.concat(terms_list, default_separator or ", ")
end

function export.get_descendants(lang, entry_name, id, noerror)
	local page = mw.title.new(entry_name)
	local content = page:getContent()
	local namespace = mw.title.getCurrentTitle().nsText

	local function desc_error(reason)
		preview_error("descendants", entry_name, lang:getFullName(), reason)
	end

	if not content then
		-- FIXME, should be an error
		desc_error("nonexistent page")
		track("desctree-nonexistent-page")
		return ""
	end
	
	-- Ignore HTML comments, columns and blank lines.
	content = remove_comments(content)
		:gsub("{{top%d}}%s", "")
		:gsub("{{mid%d}}%s", "")
		:gsub("{{bottom}}%s", "")
		:gsub("\n?{{(desc?%-%l+)|?[^}]*}}",
			function (template_name)
				if template_name == "desc-top" or template_name == "desc-bottom" or template_name == "des-top" or template_name == "des-mid" or template_name == "des-bottom" then
					return ""
				end
			end)
		:gsub("\n%s*\n", "\n")
	
	local _, index = string.find(content,
		"%f[^\n%z]==[ \t]*" .. lang:getFullName() .. "[ \t]*==", nil, true)
	if not index then
		_, index = string.find(content, "%f[^\n%z]==[ \t]*"
				.. require(string_utilities_module).pattern_escape(lang:getFullName())
				.. "[ \t]*==", nil, false)
	end
	if not index then
		desc_error("L2 header for language not found")
		-- FIXME, should be an error
		track("desctree-lang-not-found")
		return ""
	end

	if id then
		content = get_content_after_senseid(content, entry_name, lang, id)
		index = 0
	end

	local _, next_lang = string.find(content, "\n==[^=\n]+==", index, false)
	local _, index = string.find(content, "\n(====*)[ \t]*Descendants[ \t]*%1", index, false)
	local function desctree_no_descendants(with_lang_in_error)
		if noerror and (namespace == "" or namespace == "Reconstruction") then
			track("desctree-no-descendants")
			return "<small class=\"error previewonly\">(" ..
				"Please either change this template to {{desc}} " ..
				"or insert a ====Descendants==== section in [[" ..
				entry_name .. "#" .. lang:getFullName() .. "]])</small>" ..
				"[[Category:" .. lang:getFullName() .. " descendants to be fixed in desctree]]"
		else
			error(("No Descendants section was found in the entry [[%s]]%s"):format(entry_name,
				with_lang_in_error and (" under the header for %s"):format(lang:getFullName()) or ""))
		end
	end
	if not index then
		return desctree_no_descendants()
	elseif next_lang and next_lang < index then
		return desctree_no_descendants("with lang in error")
	end
	
	-- Skip past final equals sign.
	index = index + 1
	
	-- Skip past spaces or tabs.
	while true do
		local new_index = string.match(content, "^[ \t]+()", index)
		if not new_index then
			break
		end
		index = new_index
	end
	
	local items = require("Module:array")()
	local frame = mw.getCurrentFrame()
	local previous_list_markers = ""
	
	-- Skip paragraphs at beginning of Descendants section.
	while true do
		local new_index = content:match("^\n[^%*:=][^\n]*()", index)
		if not new_index then
			break
		else
			index = new_index
		end
	end
	
	previous_index = 1
	
	-- Find a consecutive series of list items that begins directly after the
	-- Descendants header.
	-- start_index and previous_index are used to check that list items are
	-- consecutive.
	for start_index, list_markers, item, index in string.gmatch(content:sub(index), "()\n([%*:]+) *([^\n]+)()") do
		if start_index ~= previous_index then
			break
		end
		
		-- Preprocess, but replace recursive calls to avoid template loop errors
		item = string.gsub(item, "{{desctree|", "{{#invoke:etymology/templates/descendant|descendants_tree|")
		item = frame:preprocess(item)
		
		local difference = #list_markers - #previous_list_markers
		
		if difference > 0 then
			for i = #previous_list_markers + 1, #list_markers  do
				items:insert(list_markers:sub(i, i) == "*" and "<ul>" or "<dl>")
			end
		else
			if difference < 0 then
				for i = #previous_list_markers, #list_markers + 1, -1 do
					items:insert(previous_list_markers:sub(i, i) == "*" and "</li></ul>" or "</dd></dl>")
				end
			else
				items:insert(previous_list_markers:sub(-1, -1) == "*" and "</li>" or "</dd>")
			end
			
			if previous_list_markers:sub(#list_markers, #list_markers) ~= list_markers:sub(-1, -1) then
				items:insert(list_markers:sub(-1, -1) == "*" and "</dl><ul>" or "</ul><dl>")
			end
		end
		
		items:insert(list_markers:sub(-1, -1) == "*" and "<li>" or "<dd>")
		
		items:insert(item)
		
		previous_list_markers = list_markers
		previous_index = index
	end
	
	for i = #previous_list_markers, 1, -1 do
		items:insert(previous_list_markers:sub(i, i) == "*" and "</li></ul>" or "</dd></dl>")
	end
	
	return items:concat()
end

return export
