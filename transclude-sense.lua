local export = {}

local m_templateparser = require("Module:templateparser")

-- From [[Template:gloss]]
local gloss_left = "<span class=\"gloss-brac\">(</span><span class=\"gloss-content\">"
local gloss_right = "</span><span class=\"gloss-brac\">)</span>"

-- From [[Module:senseno]]
local function escape_pattern(text)
    return text:gsub("([^%w])", "%%%1")
end

local function discard(offset, iter, obj, index)
	return iter, obj, index + offset
end

local function parts(str, separator)
    local pattern = "([^" .. escape_pattern(separator) .. "]*)"
	local unprocessed_start = 1
	return function ()
	    if unprocessed_start >= str:len() then return nil end
		local _, match_end, match = str:find(pattern, unprocessed_start)
		unprocessed_start = match_end + 2
		return match
	end
end

local function split(str, separator)
	local array = {}
	for part in parts(str, separator) do
		table.insert(array, part)
	end
	return array
end

local function remove_templates_if(haystack, predicate)
	local remaining = {}
	local last_start = 1
	for name, args, text, index in m_templateparser.findTemplates(haystack) do
		local remove = predicate(name, args, next(remaining) == nil)
		if remove then
			if last_start < index then
				local chunk = haystack:sub(last_start, index - 1)
				if chunk:find("%S") then
					table.insert(remaining, chunk)
				end
			end
			last_start = index + text:len()
		end
	end
	if last_start == 1 then
		return haystack
	else
		table.insert(remaining, haystack:sub(last_start))
		return table.concat(remaining)
	end
end

local function copy_unnamed_args_except_code(to, from)
	for _, value in discard(1, ipairs(from)) do
		table.insert(to, value)
	end
end

local function handle_definition_template(name, args)
	if name == "place" then
		return {
			should_remove = true,
			must_be_first = true,
			generate = function (frame, language, target, target_language, id, sort, no_gloss, gloss, formatted_to)
				if formatted_to and formatted_to ~= "" then error("{{place}} cannot be used in conjunction with 'to'.") end
				args[1] = language:getCode()
				args["t"] = target
				args["tid"] = id
				args["sort"] = sort
				if no_gloss then
					args["def"] = ""
				else
					if gloss ~= "" then
						gloss = gloss:gsub("^[%,%;] *", "")
						local first_free = 2
						while args[first_free] ~= nil do first_free = first_free + 1 end
						args[first_free] = gloss
					end
				end
				return require("Module:place").format(args)
			end
		}
	elseif name == "abbreviation of" or name == "abbr of" or name == "abbrev of"
		or name == "acronym of"
		or name == "contraction of" or name == "contr of"
		or name == "initialism of" or name == "init of"
		or name == "short for" then
		return {
			should_remove = true,
			must_be_first = true,
			generate = function (frame, language, target, target_language, id, sort, no_gloss, gloss, formatted_to)
				local formatted_gloss = ""
				if not no_gloss then
					local formatted_link = require("Module:links").full_link({ term = args[2], alt = args[3], lang = target_language, id = args["id"] })
					local after_link = ""
					if gloss ~= "" then
						local separator = (args["nodot"] and "") or ((args["dot"] or ";") .. " ")
						after_link = separator .. gloss
					end
					formatted_gloss = " " .. gloss_left .. formatted_link .. after_link .. gloss_right
				end
				return formatted_to .. require("Module:links").full_link({ term = target, lang = target_language, id = id }) .. formatted_gloss
			end
		}
	end
	return nil
end

function export.show(frame)
   	local args = require "Module:parameters".process(frame:getParent().args, {
		[1] = { required = true },
		[2] = { required = true },
		["id"] = {}, -- Despite technically being required, we're not declaring this as required in order to be able to provide a more helpful error message below.
		["sort"] = {},
		["nogloss"] = { default = false, type = "boolean" },
		["lb"] = {},
		["to"] = { type = "boolean" },
	})

	local language_code = args[1]
	local language = require("Module:languages").getByCode(language_code)
	local target = args[2]
	local target_language_code = "en"
	local target_language = require("Module:languages").getByCode(target_language_code)
	local id = args["id"] or ""
	local sort = args["sort"]
	local copy_sortkey = (sort == nil) and (mw.title.getCurrentTitle() == target)
	local no_gloss = args["nogloss"]
	local labels = args["lb"] and split(args["lb"], ";") or {}
	local to = args["to"]
	
	local content = mw.title.new(target):getContent()
	if content == nil then
		error("Could not find the entry [[" .. target .. "]].")
	end
	
	-- Remove HTML comments.
	content = content:gsub("%<%!%-%-.-%-%-%>", "")
	-- Remove <ref></ref>.
	content = content:gsub("%< *[rR][eE][fF][^%a%>%/]*[^%>%/]*%>.-%< *%/ *[rR][eE][fF] *%>", "")
	-- Remove <ref/>.
	content = content:gsub("%< *[rR][eE][fF][^%a%>%/]*[^%>%/]*%/ *%>", "")
	-- TODO: Handle <nowiki> (it's more complex than just cutting it out too).
	
	local senseid_start, senseid_end = content:find("%{%{ *senseid *%| *" .. escape_pattern(target_language_code) .. " *%| *" .. escape_pattern(id) .. " *%}%}")
	if senseid_start == nil then
		local alternatives = nil
		for id in content:gmatch("%{%{ *senseid *%| *" .. escape_pattern(target_language_code) .. " *%| *([^%}]*)%}%}") do
			alternatives = alternatives and alternatives .. ", " .. id or id
		end
		error("Could not find the template {{[[Template:senseid|senseid]]|" .. target_language_code .. "|" .. id .. "}} within entry [[" .. target .. "]]. Alternatives for |id= are: " .. alternatives)
	end
	
	-- Do the following manually instead of using regex or iterators in hopes of saving memory.
	local newline = string.byte("\n")
	local pound = string.byte("#")
	local line_start = senseid_start
	while line_start > 0 and content:byte(line_start - 1) ~= newline do line_start = line_start - 1 end
	local def_start = line_start
	while content:byte(def_start) == pound do def_start = def_start + 1 end
	local line_end = senseid_end
	while line_end < content:len() and content:byte(line_end + 1) ~= newline do line_end = line_end + 1 end
	local line = content:sub(def_start, senseid_start - 1) .. content:sub(senseid_end + 1, line_end)
	
	if to == nil then
		local i = line_start
		while i > 1 do
			i = i - 1 -- i is now the index of the newline
			while i > 1 and content:byte(i - 1) ~= newline do i = i - 1 end
			local header = content:match("^%=%=%=+([^%=\n]+)%=%=%=+ *\n", i)
			if header then
				to = (header:match("[Vv]erb") ~= nil)
				break
			end
		end
	end
	
	-- TODO: Remove this error once <nowiki> is handled correctly (see above TODO).
	if line:find("%< *nowiki%W") or line:find("%< *%/ *nowiki%W") then
		error("Cannot handle <nowiki>.")
	end
	
	-- Quick'n'dirty templatization of manual cats so that the below code also works for them.
	for _, v in ipairs({{target_language_code .. "%:", "c"}, {target_language:getCanonicalName() .. " ", "cln"}, {"", "cat"}}) do
		line = line:gsub("%[%[ *Category *%: *" .. v[1] .. "([^%]%|]*)%]%]", "{{" .. v[2] .. "|" .. target_language_code .. "|%1}}")
		line = line:gsub("%[%[ *Category *%: *" .. v[1] .. "([^%]%|]*)%|([^%]%|]*)%]%]", "{{" .. v[2] .. "|" .. target_language_code .. "|%1|sort=%2}}")
	end
	
	-- Extract template information.
	local cats = {}
	local cats_cln = {}
	local cats_top = {}
	local encountered_label = false
	local generator = nil
	local sortkeys = {}
	local sortkey_most_frequent = nil
	local sortkey_most_frequent_n = 0
	local function process_template(name, args, is_at_the_start)
		local supports_sortkey = false
		local should_remove = true -- If set, removes the template from the line after processing.
		local must_be_first = false -- If set, ensures that nothing (except for removed templates) preceeds this template.
		local definition_template_handler = handle_definition_template(name, args)
		if definition_template_handler ~= nil then
			if generator ~= nil then
				error("Encountered {{[[Template:" .. name .. "|" .. name .. "]]}} even though a full definition template has already been processed.")
			end
			should_remove = definition_template_handler.should_remove
			must_be_first = definition_template_handler.must_be_first
			generator = definition_template_handler.generate
		elseif name == "categorize" or name == "cat" then
			copy_unnamed_args_except_code(cats, args)
			supports_sortkey = true
		elseif name == "catlangname" or name == "cln" then
			copy_unnamed_args_except_code(cats, args)
			supports_sortkey = true
		elseif name == "catlangcode" or name == "topics" or name == "top" or name == "C" or name == "c" then
			copy_unnamed_args_except_code(cats_top, args)
			supports_sortkey = true
		elseif name == "label" or name == "lbl" or name == "lb" then
			if encountered_label then
				error("Encountered multiple {{[[Template:label|label]]}} templates in the definition line.")
			end
			encountered_label = true
			copy_unnamed_args_except_code(labels, args)
			supports_sortkey = true
			must_be_first = true
		elseif name == "defdate" or name == "defdt"
			or name == "ref" or name == "refn" then
			-- Remove and do nothing.
		else
			-- We are dealing with a template other than the above hard-coded ones.
			-- If it contains the language code, we cannot handle it.
			if args[1] == target_language_code then
				error("Cannot handle template {{[[Template:" .. name .. "|" .. name .. "]]}}.")
			end
			supports_sortkey = (args["sort"] ~= args or args["sort1"] ~= nil) -- TODO: This doesn't handle the case where there is only sortn but not sort1/sort.
			should_remove = false -- Leave the template in and just copy it, e.g. [[Template:,]], [[Template:gloss]], [[Template:qualifier]], [[Template:w]] etc.
		end
		if supports_sortkey then
			if args["sort1"] ~= nil then
				error("Cannot handle multiple sort keys.")
			end
			local sortkey = args["sort"]
			if sortkey ~= nil then
				if sortkeys[sortkey] == nil then
					sortkeys[sortkey] = 1
				else
					sortkeys[sortkey] = sortkeys[sortkey] + 1
				end
				if sortkeys[sortkey] > sortkey_most_frequent_n then
					sortkey_most_frequent = sortkey
					sortkey_most_frequent_n = sortkeys[sortkey]
				end
			end
		end
		if must_be_first and not is_at_the_start then
			error("The template {{[[Template:" .. name .. "|" .. name .. "]]}} should occur to the front of the definition line.")
		end
		return should_remove
	end
	line = remove_templates_if(line, process_template)
	line = line:gsub("^%s+", ""):gsub("%s+$", "") -- Prune ends.
	
	-- Tidy up the remaining definition (to be used as a gloss).
	local gloss = line:gsub("^%u", string.lower):gsub("%.$", "")
	gloss = gloss:gsub("^%{%{1%|([^%}%|]*)%}%}", "%1") -- Remove [[Template:1]]
	local _, link_end, link_dest_head, link_dest_tail, link_face_head, link_face_tail = gloss:find("^%[%[(.)([^%|%]]*)%|(.)([^%]]*)%]%]") -- Remove [[foo|Foo]]
	if link_end ~= nil and link_dest_tail == link_face_tail and link_face_head:lower() == link_dest_head then
		gloss = "[[" .. link_dest_head .. link_dest_tail .. gloss:sub(link_end - 1)
	end
	gloss = frame:preprocess(gloss)
	
	if copy_sortkey then
		sort = sortkey_most_frequent
	end
	
	local formatted_senseid = frame:expandTemplate({ title = "senseid", args = { language_code, id } })
	local formatted_categories =
		((next(cats    ) == nil) and "" or frame:expandTemplate({ title = "cat", args = { language_code, unpack(cats    ) } })) ..
		((next(cats_cln) == nil) and "" or frame:expandTemplate({ title = "cln", args = { language_code, unpack(cats_cln) } })) ..
		((next(cats_top) == nil) and "" or frame:expandTemplate({ title = "top", args = { language_code, unpack(cats_top) } }))
	local formatted_labels = (next(labels) == nil) and "" or (require("Module:labels").show_labels { labels = labels, lang = language, sort = sort} .. " ")

	local formatted_to = to and "to " or ""
	local formatted_definition
	if generator ~= nil then
		formatted_definition = generator(frame, language, target, target_language, id, sort, no_gloss, gloss, formatted_to)
	else
		local formatted_link = require("Module:links").full_link({ term = target, lang = target_language, id = id })
		local formatted_gloss = no_gloss and "" or (" " .. gloss_left .. gloss .. gloss_right)
		formatted_definition = formatted_to .. formatted_link .. formatted_gloss
	end
	return formatted_senseid .. formatted_categories .. formatted_labels .. formatted_definition
end

return export
