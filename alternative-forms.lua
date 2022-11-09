local export = {}
local m_link = require("Module:links")
local m_languages = require("Module:languages")
local m_debug = require("Module:debug")

-- See if the language's dialectal data module has a label corresponding to the dialect argument.
function export.getLabel(dialect, dialect_data)
	local data = dialect_data[dialect] or ( dialect_data.labels and dialect_data.labels[dialect] )
	local alias_of = ( dialect_data.aliases and dialect_data.aliases[dialect] )
	if not data then
		if alias_of then
			data = dialect_data[alias_of] or ( dialect_data.labels and dialect_data.labels[alias_of] )
		end
	end
	if data then
		local display = data.display or dialect
		if data.appendix then
			dialect = '[[Appendix:' .. data.appendix .. '|' .. display .. ']]'
		else
			local target = data.link
			dialect = target and '[[w:'.. target .. '|' .. display .. ']]' or display
		end
	end
	return dialect
end

function export.make_dialects(raw, lang)
	local dialect_page = 'Module:'.. lang:getCode() ..':Dialects'
	local dialect_info
	if raw[1] then
		dialect_info = mw.title.new(dialect_page).exists and mw.loadData(dialect_page) or false
	end
		
	local dialects = {}
	
	for _, dialect in ipairs(raw) do
		table.insert(dialects, dialect_info and export.getLabel(dialect, dialect_info) or dialect)
	end
	
	return dialects
end

local function track(args, arg, number)
	if args and args[arg] and args[arg][number] then
		m_debug.track("alter/" .. arg)
	end
end

local function maxindex_of_args(args, arg_keys)
	return math.max(unpack(require "Module:fun".map(
		function (arg)
			return args[arg].maxindex
		end,
		arg_keys)))
end

local function any_arg_at_index(args, arg_keys, i)
	return require "Module:fun".some(
		function (arg)
			return args[arg][i]
		end,
		arg_keys)
end

function export.create(frame)
	local title = mw.title.getCurrentTitle()
	local NAMESPACE = title.nsText
	local PAGENAME = title.text
	
	local list_with_holes = { list = true, allow_holes = true }
	local params = {
		[1] = { required = true, default = "und" },
		[2] = list_with_holes,
		["alt"] = list_with_holes,
		["id"] = list_with_holes,
		["sc"] = {},
		
		["g"] = list_with_holes,
		["tr"] = list_with_holes,
		["ts"] = list_with_holes,
		["t"] = list_with_holes,
		["lit"] = list_with_holes,
		["pos"] = list_with_holes,
		["gloss"] = { alias_of = "t" },
	}
	
	local args = require("Module:parameters").process(frame:getParent().args, params)
	local lang = m_languages.getByCode(args[1], 1)
	local sc = require("Module:scripts").getByCode(args["sc"], "sc")
	
	local rawDialects = {}
	local links = {}
	
	local term_args = { 2, "alt", "id", "tr", "ts", "t", "lit", "pos", "g" }
	local maxindex = maxindex_of_args(args, term_args)
	if maxindex == 0 then
		error("Either a positional parameter, alt parameter, id parameter, tr parameter, or ts parameter is required.")
	end
	
	-- Is set to true if there is a term (entry link, alt text,
	-- transliteration, transcription) at the previous index.
	local prev = false
	local use_semicolon = false

	for i = 1, maxindex do
		-- If the previous parameter was empty and we're not on the first parameter,
		-- this parameter and any others contain dialect or other labels.
		if i > 1 and not prev then
			rawDialects = {unpack(args[2], i, maxindex)}
			break
		-- If any of the arguments used for formatting a term is present, create
		-- a term and add it to the list.
		elseif any_arg_at_index(args, term_args, i) then
			track(args, "alt", i) -- [[Special:WhatLinksHere/Template:tracking/alter/alt]]
			track(args, "id", i) -- [[Special:WhatLinksHere/Template:tracking/alter/id]]
			track(args, "tr", i) -- [[Special:WhatLinksHere/Template:tracking/alter/tr]]
			track(args, "ts", i) -- [[Special:WhatLinksHere/Template:tracking/alter/ts]]
			track(args, "t", i) -- [[Special:WhatLinksHere/Template:tracking/alter/t]]
			track(args, "lit", i) -- [[Special:WhatLinksHere/Template:tracking/alter/lit]]
			track(args, "pos", i) -- [[Special:WhatLinksHere/Template:tracking/alter/pos]]
			track(args, "g", i) -- [[Special:WhatLinksHere/Template:tracking/alter/g]]
			
			local term = args[2][i]
			local alt = args.alt[i]
			local term_text = term or alt
			if not use_semicolon and term_text then
				if term_text:find(",", 1, true) then
					use_semicolon = true
				end
			end

			if term and lang:makeEntryName(term) == PAGENAME then -- Unlink if term is pagename.
				require "Module:debug".track("alter/term is pagename")
				alt = alt or term
				term = nil
			end
			term = m_link.full_link{
				lang = lang,
				sc = sc,
				term = term,
				alt = alt,
				id = args.id[i],
				tr = args.tr[i],
				ts = args.ts[i],
				gloss = args.t[i],
				lit = args.lit[i],
				pos = args.pos[i],
				genders = args.g[i] and mw.text.split(args.g[i], ",") or {},
			}
			table.insert(links, term)
			prev = true
		else
			if maxindex_of_args(args, { "alt", "id", "tr", "ts" }) >= i then
				require("Module:debug").track("alter/too few terms")
			end
			
			prev = false
		end
	end
	
	-- The template must have either links or dialect labels.
	if links[1] == nil and rawDialects[1] == nil then error("No terms found!") end

	local dialects  = export.make_dialects(rawDialects, lang)
	
	local output = { table.concat(links, use_semicolon and '; ' or ', ') }
	if #dialects > 0 then
		local dialect_label
		if lang:hasTranslit() then
			dialect_label = " &ndash; ''" .. table.concat(dialects, ", ") .. "''" 
		else
			dialect_label = " (''" .. table.concat(dialects, ", ") .. "'')"
		end
		
		-- Fixes the problem of '' being added to '' at the end of last dialect parameter
		dialect_label = mw.ustring.gsub(dialect_label, "''''", "")
		table.insert(output, dialect_label)
	end
	
	return table.concat(output)
end

function export.categorize(frame)
	local content = {}
	
	local title = mw.title.getCurrentTitle()
	local titletext = title.text
	local namespace = title.nsText
	local subpagename = title.subpageText
	
	-- subpagename ~= titletext if it is a documentation page
	if namespace == "Module" and subpagename == titletext then
		local langCode = mw.ustring.match(titletext, "^([^:]+):")
		local lang = m_languages.getByCode(langCode) or error('"' .. langCode .. '" is not a valid language code.')
		content.canonicalName = lang:getCanonicalName()
		
		local categories =
[=[
[[Category:<canonicalName> modules|dialects]]
[[Category:Dialectal data modules|<canonicalName>]]
]=]
		
		categories = mw.ustring.gsub(categories, "<([^>]+)>", content)
		return categories
	end
end

return export
