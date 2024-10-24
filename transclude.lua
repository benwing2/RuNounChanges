local m_str_utils = require("Module:string utilities")
local m_templateparser = require("Module:template parser")

local remove_comments = m_str_utils.remove_comments
local replacement_escape = m_str_utils.replacement_escape
local split = m_str_utils.split
local u = m_str_utils.char

local export = {}

-- From [[Template:gloss]]
local gloss_left = "<span class=\"gloss-brac\">(</span><span class=\"gloss-content\">"
local gloss_right = "</span><span class=\"gloss-brac\">)</span>"

local place_extra_info = {
	["modern"] = true,
	["official"] = true,
	["capital"] = true,
	["largest city"] = true,
	["caplc"] = false,
	["seat"] = true,
	["shire town"] = true,
}

local pattern_escape = require("Module:string utilities").pattern_escape

-- Ensure that Wikicode (template calls, bracketed links, HTML, bold/italics, etc.) displays literally in error messages
-- by inserting a Unicode word-joiner symbol after all characters that may trigger Wikicode interpretation. Replacing
-- with equivalent HTML escapes doesn't work because they are displayed literally. I could not get this to work using
-- <nowiki>...</nowiki> (those tags display literally), using using {{#tag:nowiki|...}} (same thing) or using
-- mw.getCurrentFrame():extensionTag("nowiki", ...) (everything gets converted to a strip marker
-- `UNIQ--nowiki-00000000-QINU` or similar). FIXME: This is a massive hack; there must be a better way.
local function escape_wikicode(text)
	text = text:gsub("([%[<'{])", "%1" .. u(0x2060))
	return text
end

local function preprocess(frame, text)
	if text:find("{") then
		return frame:preprocess(text)
	else
		return text
	end
end
	
local function discard(offset, iter, obj, index)
	return iter, obj, index + offset
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

local function copy_unnamed_args_maybe_except_code(to, from, deny_list, first_argument)
	first_argument = first_argument or 2
	for _, value in discard(first_argument - 1, ipairs(from)) do
		if not deny_list or not require("Module:table").contains(deny_list, value) then
			table.insert(to, value)
		end
	end
end

local function handle_definition_template(name, args, transclude_args)
	if name == "place" then
		return {
			should_remove = true,
			must_be_first = true,
			generate = function(data)
				if data.formatted_to and data.formatted_to ~= "" then
					error("{{place}} cannot be used in conjunction with 'to'.")
				end
				local place_args = {}
				local langcode = data.lang:getCode()
				local include_place_extra_info = transclude_args.include_place_extra_info
				local drop_extra = include_place_extra_info == false or include_place_extra_info == nil and langcode ~= "en"
				local saw_tcl_t
				-- Copy the arguments but drop translations and maybe the "extra info"
				for key, val in pairs(args) do
					local base, num = tostring(key):match("^(.-)([0-9]*)$")
					if base == "tcl_t" or base == "tcl_tid" then
						saw_tcl_t = true -- otherwise ignore
					elseif base == "tcl_nolb" then
						data.nolb = val -- otherwise ignore
					elseif base == "t" or base == "tid" or drop_extra and place_extra_info[base] ~= nil then
						-- ignore it
					else
						place_args[key] = val
					end
				end

				local function sub_plus(t)
					if t:find("+") then
						t = t:gsub("+", replacement_escape(data.source))
					end
					return t
				end
					
				place_args[1] = langcode
				if #transclude_args.t > 0 then
					local argno = 1
					for _, t in ipairs(transclude_args.t) do
						if t ~= "-" then
							place_args["t" .. (argno == 1 and "" or argno)] = sub_plus(t)
							argno = argno + 1
						end
					end
				elseif saw_tcl_t then
					for key, val in pairs(args) do
						local base, num = tostring(key):match("^(.-)([0-9]*)$")
						if base == "tcl_t" then
							place_args["t" .. num] = sub_plus(val)
						elseif base == "tcl_tid" then
							place_args["tid" .. num] = val
						end
					end
				elseif langcode ~= "en" then
					place_args["t"] = data.source
					place_args["tid"] = data.id
				end
				place_args["sort"] = data.sort
				if data.no_gloss then
					place_args["def"] = "-"
				else
					local gloss = data.gloss

					for extra_info_arg, is_list in pairs(place_extra_info) do
						if is_list then
							for i, v in ipairs(transclude_args["place_" .. extra_info_arg]) do
								place_args[extra_info_arg .. (i == 1 and "" or i)] = v
							end
						elseif transclude_args[extra_info_arg] then
							place_args[extra_info_arg] = transclude_args[extra_info_arg]
						end
					end
					
					if gloss ~= "" then
						local first_free = 2
						while place_args[first_free] ~= nil do first_free = first_free + 1 end
						if place_args[first_free - 1]:find("<<") then
							-- new-style argument; concatenate to end of argument
							if not gloss:find("^[,;.]") then
								gloss = " " .. gloss
							end
							place_args[first_free - 1] = args[first_free - 1] .. gloss
						else
							-- old-style argument; add as separate argument
							gloss = gloss:gsub("^[,;] *", "")
							place_args[first_free] = gloss
						end
					end
				end
				return require("Module:place").format(place_args)
			end,
		}
	elseif name == "abbreviation of" or name == "abbr of" or name == "abbrev of"
		or name == "acronym of"
		or name == "contraction of" or name == "contr of"
		or name == "initialism of" or name == "init of"
		or name == "short for" then
		return {
			should_remove = true,
			must_be_first = true,
			generate = function(data)
				local formatted_gloss = ""
				if not data.no_gloss then
					local formatted_link = require("Module:links").full_link {
						term = args[2], alt = args[3], lang = data.source_lang, id = args["id"]
					}
					local after_link = ""
					if data.gloss ~= "" then
						local separator = (args["nodot"] and "") or ((args["dot"] or ";") .. " ")
						after_link = separator .. data.gloss
					end
					formatted_gloss = " " .. gloss_left .. formatted_link .. after_link .. gloss_right
				end
				return data.formatted_to .. require("Module:links").full_link {
					term = data.source, lang = data.source_lang, id = data.id
				} .. formatted_gloss
			end,
		}
	end
	return nil
end

function export.show(frame)
   	local params = {
		[1] = { required = true }, -- langcode of target language (the current entry's language)
		[2] = { required = true }, -- source English term to transclude from
		["id"] = {}, -- can have multiple comma-separated ID's
		["sort"] = {},
		["nogloss"] = { default = false, type = "boolean" },
		["no_truncate_gloss"] = { type = "boolean" },
		-- Normally, we ignore extra info (capital, largest city, modern name, etc.) when transcluding {{place}}
		-- because the given terms are in English and will likely differ from language to language.
		["include_place_extra_info"] = { type = "boolean" },
		["lb"] = {}, -- can have multiple semicolon-separated labels
		["nolb"] = {}, -- can have multiple semicolon-separated labels
		["to"] = { type = "boolean" },
		["t"] = { list = true },
		["indent"] = {},
	}
	for k, is_list in pairs(place_extra_info) do
		params["place_" .. k] = { list = is_list }
	end

   	local args = require("Module:parameters").process(frame:getParent().args, params)

	local language_code = args[1]
	local language = require("Module:languages").getByCode(language_code)
	local source = args[2]
	local source_langcode = "en"
	local source_lang = require("Module:languages").getByCode(source_langcode)
	local source_langname = source_lang:getFullName()
	local ids = args.id and split(args.id, ",") or {"-"}
	local sort = args["sort"]
	local copy_sortkey = (sort == nil) and (mw.title.getCurrentTitle() == source)
	local no_gloss = args["nogloss"]
	local labels = args["lb"] and split(args["lb"], ";") or {}
	local nolb
	local found_labels = {}
	local to = args["to"]

	local content = mw.title.new(source):getContent()
	if content == nil then
		error("Couldn't find the entry [[" .. source .. "]].")
	end

	-- Remove HTML comments.
	content = remove_comments(content)
	-- Remove.<ref></ref>
	content = content:gsub("< *[rR][eE][fF][^%a>/]*[^>/]*>.-< */ *[rR][eE][fF] *>", "")
	-- Remove <ref/>.
	content = content:gsub("< *[rR][eE][fF][^%a>/]*[^>/]*/ *>", "")
	-- TODO: Handle <nowiki> (it's more complex than just cutting it out too).

	local retlines = {}

	for _, id in ipairs(ids) do
		local line_start, line
		if id ~= "-" then
			local senseid_start, senseid_end = content:find("{{ *senseid *| *" .. pattern_escape(source_langcode) .. " *| *" .. pattern_escape(id) .. " *}}")
			if senseid_start == nil then
				senseid_start, senseid_end = content:find("{{ *sid *| *" .. pattern_escape(source_langcode) .. " *| *" .. pattern_escape(id) .. " *}}")
			end
			if senseid_start == nil then
				local alternatives = nil
				for id in content:gmatch("{{ *senseid *| *" .. pattern_escape(source_langcode) .. " *| *([^}]*)}}") do
					alternatives = alternatives and alternatives .. ", " .. id or id
				end
				for id in content:gmatch("{{ *sid *| *" .. pattern_escape(source_langcode) .. " *| *([^}]*)}}") do
					alternatives = alternatives and alternatives .. ", " .. id or id
				end
				if alternatives then
					alternatives = " Alternatives for |id= are: " .. alternatives
				else
					alternatives = ""
				end
				error("Couldn't find the template {{[[Template:senseid|senseid]]|" .. source_langcode .. "|" .. id .. "}} within entry [[" .. source .. "]]." .. alternatives)
			end

			-- Do the following manually instead of using regex or iterators in hopes of saving memory.
			local newline = string.byte("\n")
			local pound = string.byte("#")
			line_start = senseid_start
			while line_start > 0 and content:byte(line_start - 1) ~= newline do line_start = line_start - 1 end
			local def_start = line_start
			while content:byte(def_start) == pound do def_start = def_start + 1 end
			local line_end = senseid_end
			while line_end < content:len() and content:byte(line_end + 1) ~= newline do line_end = line_end + 1 end
			line = content:sub(def_start, senseid_start - 1) .. content:sub(senseid_end + 1, line_end)
		else
			local _, start_source = string.find(content, "==[ \t]*" .. pattern_escape(source_langname) .. "[ \t]*==")
			if not start_source then
				error(("Couldn't find L2 header for source language '%s' on page [[%s]]"):format(source_langname,
					source))
			end
			-- Find index of start of next language; may be nil if no language follows.
			local _, start_next_lang = string.find(content, "\n==[^=\n]+==", start_source, false)
			content = content:sub(start_source, start_next_lang)
			while true do
				local next_line_start
				_, next_line_start = string.find(content, "\n#+[^:*]", line_start, false)
				if not next_line_start then
					break
				end
				if line_start then
					local first_line = string.match(content, "(.-)%f[\n%z]", line_start)
					local next_line = string.match(content, "(.-)%f[\n%z]", next_line_start + 1)
					error(("No id specified and saw two definition lines '%s' and '%s' for source language '%s' on page [[%s]]"):format(
						escape_wikicode(first_line), escape_wikicode(next_line), source_langname, source))
				end
				line_start = next_line_start + 1
			end
			if not line_start then
				error(("Couldn't find any definition lines for source language '%s' on page [[%s]]"):format(
					source_langname, source))
			end
			line = string.match(content, "(.-)%f[\n%z]", line_start)
		end

		if to == nil then
			local i = line_start
			while i > 1 do
				i = i - 1 -- i is now the index of the newline
				while i > 1 and content:byte(i - 1) ~= newline do i = i - 1 end
				local header = content:match("^===+([^=\n]+)===+ *\n", i)
				if header then
					to = (header:match("[Vv]erb") ~= nil)
					break
				end
			end
		end

		-- TODO: Remove this error once <nowiki> is handled correctly (see above TODO).
		if line:find("< *nowiki%W") or line:find("< */ *nowiki%W") then
			error("Cannot handle <nowiki>.")
		end

		-- Quick'n'dirty templatization of manual cats so that the below code also works for them.
		for _, v in ipairs({{source_langcode .. ":", "c"}, {source_lang:getCanonicalName() .. " ", "cln"}, {"", "cat"}}) do
			line = line:gsub("%[%[ *Category *: *" .. v[1] .. "([^%]|]*)%]%]", "{{" .. v[2] .. "|" .. source_langcode .. "|%1}}")
			line = line:gsub("%[%[ *Category *%: *" .. v[1] .. "([^%]|]*)%|([^%]|]*)%]%]", "{{" .. v[2] .. "|" .. source_langcode .. "|%1|sort=%2}}")
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
		local function process_template(name, tempargs, is_at_the_start)
			-- Expand any nested templates in template arguments.
			for k, v in pairs(tempargs) do
				tempargs[k] = preprocess(frame, v)
			end
			local supports_sortkey = false
			local should_remove = true -- If set, removes the template from the line after processing.
			local must_be_first = false -- If set, ensures that nothing (except for removed templates) preceeds this template.
			local definition_template_handler = handle_definition_template(name, tempargs, args)
			if definition_template_handler ~= nil then
				if generator ~= nil then
					error("Encountered {{[[Template:" .. name .. "|" .. name .. "]]}} even though a full definition template has already been processed.")
				end
				should_remove = definition_template_handler.should_remove
				must_be_first = definition_template_handler.must_be_first
				generator = definition_template_handler.generate
			elseif name == "categorize" or name == "cat" then
				copy_unnamed_args_maybe_except_code(cats, tempargs)
				supports_sortkey = true
			elseif name == "catlangname" or name == "cln" then
				copy_unnamed_args_maybe_except_code(cats, tempargs)
				supports_sortkey = true
			elseif name == "catlangcode" or name == "topics" or name == "top" or name == "C" or name == "c" then
				copy_unnamed_args_maybe_except_code(cats_top, tempargs)
				supports_sortkey = true
			elseif name == "label" or name == "lbl" or name == "lb" then
				if encountered_label then
					error("Encountered multiple {{[[Template:label|label]]}} templates in the definition line.")
				end
				encountered_label = true
				copy_unnamed_args_maybe_except_code(found_labels, tempargs)
				supports_sortkey = true
				must_be_first = true
			elseif name == "defdate" or name == "defdt" or name == "ref" or name == "refn" or name == "senseid" or name == "sid" then
				-- Remove and do nothing.
			else
				-- We are dealing with a template other than the above hard-coded ones.
				-- If it contains the language code, we cannot handle it.
				if tempargs[1] == source_langcode then
					error("Cannot handle template {{[[Template:" .. name .. "|" .. name .. "]]}}.")
				end
				supports_sortkey = tempargs["sort"] or tempargs["sort1"] -- TODO: This doesn't handle the case where there is only sortn but not sort1/sort.
				should_remove = false -- Leave the template in and just copy it, e.g. [[Template:,]], [[Template:gloss]], [[Template:qualifier]], [[Template:w]] etc.
			end
			if supports_sortkey then
				if tempargs["sort1"] ~= nil then
					error("Cannot handle multiple sort keys.")
				end
				local sortkey = tempargs["sort"]
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
		local gloss = line
		if not args.no_truncate_gloss then
			-- Truncate full sentences after a period, as they won't be formatted well as a gloss. Require a space after
			-- the period as a possible way of reducing false positives with abbreviations.
			gloss = gloss:gsub("%s*%. .*$", "")
		end
		gloss = gloss:gsub("^%u", string.lower):gsub("%.$", "")
		gloss = gloss:gsub("^{{1|([^}|]*)}}", "%1") -- Remove [[Template:1]]
		local _, link_end, link_dest_head, link_dest_tail, link_face_head, link_face_tail = gloss:find("^%[%[(.)([^|%]]*)|(.)([^%]]*)%]%]") -- Remove [[foo|Foo]]
		if link_end ~= nil and link_dest_tail == link_face_tail and link_face_head:lower() == link_dest_head then
			gloss = "[[" .. link_dest_head .. link_dest_tail .. gloss:sub(link_end - 1)
		end
		gloss = preprocess(frame, gloss)

		if copy_sortkey then
			sort = sortkey_most_frequent
		end

		local formatted_senseid = require("Module:senseid").senseid(language, id, "span")

		local formatted_categories =
			((next(cats    ) == nil) and "" or frame:expandTemplate({ title = "cat", args = { language_code, unpack(cats    ) } })) ..
			((next(cats_cln) == nil) and "" or frame:expandTemplate({ title = "cln", args = { language_code, unpack(cats_cln) } })) ..
			((next(cats_top) == nil) and "" or frame:expandTemplate({ title = "top", args = { language_code, unpack(cats_top) } }))

		local formatted_to = to and "to " or ""
		local formatted_definition
		if generator ~= nil then
			local data = {
				frame = frame, lang = language, source = source, source_lang = source_lang, id = id,
				sort = sort, no_gloss = no_gloss, gloss = gloss, formatted_to = formatted_to,
			}
			formatted_definition = generator(data)
			nolb = data.nolb or nolb
		else
			local formatted_link = require("Module:links").full_link { term = source, lang = source_lang, id = id }
			local formatted_gloss = no_gloss and "" or (" " .. gloss_left .. gloss .. gloss_right)
			formatted_definition = formatted_to .. formatted_link .. formatted_gloss
		end

		nolb = args["nolb"] or nolb
		local labels_to_ignore = nil
		local ignore_all_labels = false
		if nolb then
			if nolb == "+" or nolb == "1" or nolb == "*" then
				ignore_all_labels = true
			else
				labels_to_ignore = split(nolb, ";")
			end
		end
		if not ignore_all_labels then
			copy_unnamed_args_maybe_except_code(labels, found_labels, labels_to_ignore, 1)
		end
		local formatted_labels = (next(labels) == nil) and "" or (require("Module:labels").show_labels { labels = labels, lang = language, sort = sort} .. " ")

		table.insert(retlines, formatted_senseid .. formatted_categories .. formatted_labels .. formatted_definition)
	end

	return table.concat(retlines, "\n" .. (args.indent or "#") .. " ")
end

return export
