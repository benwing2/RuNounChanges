local export = {}

local m_links = require("Module:links")
local m_languages = require("Module:languages")
local m_table = require("Module:table")


local function format_list_items(items, lang, sc)
	local result = {}

	for _, item in ipairs(items) do
		if type(item) == "table" then
			local link = m_links.full_link(item.term)
			if item.q then
				link = require("Module:qualifier").format_qualifier(item.q) .. " " .. link
			end
			item = link
		-- XXX: "<span" is an ugly hack: [[Thread:User talk:CodeCat/MewBot adding lang to column templates]]
		elseif lang and not string.find(item, "<span") then
			item = m_links.full_link {lang = lang, term = item, sc = sc} 
		end

		table.insert(result, '\n* ' .. item)
	end

	return table.concat(result)
end

local collapse_header =
	[[<div class="list-switcher" data-toggle-category="{{{toggle_category}}}">]]
local column_header = [[<div class="{{{class}}} term-list ul-column-count" ]]
	.. [[data-column-count="{{{column_count}}}" ]]
	.. [[style="background-color: {{{background_color}}};">]]
local button = [[<div class="list-switcher-element" ]]
	.. [[data-showtext="&nbsp;show more ▼&nbsp;" ]]
	.. [[data-hidetext="&nbsp;show less ▲&nbsp;" style="display: none;">&nbsp;</div>]]

function export.create_list(args)
	-- Fields in args that are used:
	-- args.column_count, args.content, args.alphabetize, args.background_color,
	-- args.collapse, args.toggle_category, args.class, args.lang
	-- Check for required fields?
	if type(args) ~= "table" then
		error("expected table, got " .. type(args))
	end

	args.class = args.class or "derivedterms"
	args.column_count = args.column_count or 1
	args.toggle_category = args.toggle_category or "derived terms"

	local output = {}

	if args.header then
		if args.format_header then
			args.header = '<div class="term-list-header">' .. args.header .. "</div>"
		end
		table.insert(output, args.header)
	end
	if args.collapse then
		table.insert(output, (collapse_header:gsub('{{{(.-)}}}', args)))
	end
	table.insert(output, (column_header:gsub('{{{(.-)}}}', args)))

    if args.alphabetize then
    	local function keyfunc(item)
    		if type(item) == "table" then
    			item = item.term.term
    		end
    		-- Remove all HTML so mixtures of raw terms and {{l|...}} sort
    		-- correctly.
    		item = item:gsub("<.->", "")
    		return item
    	end
		require("Module:collation").sort(args.content, args.lang, keyfunc)
	end
	table.insert(output, format_list_items(args.content, args.lang, args.sc))

	table.insert(output, '</div>')
	if args.collapse then
		table.insert(output, button .. '</div>')
	end

	return table.concat(output)
end


-- This function is for compatibility with earlier version of [[Module:columns]]
-- (now found in [[Module:columns/old]]).
function export.create_table(...)
	-- Earlier arguments to create_table:
	-- n_columns, content, alphabetize, bg, collapse, class, title, column_width, line_start, lang
	local args = {}
	args.column_count, args.content, args.alphabetize, args.background_color,
		args.collapse, args.class, args.header, args.column_width,
		args.line_start, args.lang = ...

	args.format_header = true

	return export.create_list(args)
end


local param_mods = {"t", "alt", "tr", "ts", "pos", "lit", "id", "sc", "g", "q"}
local param_mod_set = m_table.listToSet(param_mods)

function export.display_from(column_args, list_args)
	local iparams = {
		["class"] = {},
		-- Default for auto-collapse. Overridable by template |collapse= param.
		["collapse"] = {type = "boolean"},
		-- If specified, this specifies the number of columns, and no columns
		-- parameter is available on the template. Otherwise, the columns
		-- parameter is the first available numbered param after the language-code
		-- parameter.
		["columns"] = {type = "number"},
		-- If specified, this specifies the language code, and no language-code
		-- parameter is available on the template. Otherwise, the language-code
		-- parameter can be specified as either |lang= or |1=.
		["lang"] = {},
		-- Default for auto-sort. Overridable by template |sort= param.
		["sort"] = {type = "boolean"},
		-- The following is accepted but currently ignored, per an extended discussion in
		-- [[Wiktionary:Beer parlour/2018/November#Titles of morphological relations templates]].
		["title"] = {default = ""},
		["toggle_category"] = {},
	}

	local frame_args = require("Module:parameters").process(column_args, iparams)

	local compat = frame_args["lang"] or list_args["lang"]
	local lang_param = compat and "lang" or 1
	local columns_param = compat and 1 or 2
	local first_content_param = columns_param + (frame_args["columns"] and 0 or 1)

	local params = {
		[lang_param] = not frame_args["lang"] and {required = true, default = "und"} or nil,
		[columns_param] = not frame_args["columns"] and {required = true, default = 2} or nil,
		[first_content_param] = {list = true},

		["title"] = {},
		["collapse"] = {type = "boolean"},
		["sort"] = {type = "boolean"},
		["sc"] = {},
	}

	local args = require("Module:parameters").process(list_args, params)

	local lang = frame_args["lang"] or args[lang_param]
	lang = m_languages.getByCode(lang, lang_param)

	local sc = args["sc"]
	if sc then
		sc = require "Module:scripts".getByCode(sc)
			or error("|sc= does not contain a valid script code")
	end

	local sort = frame_args["sort"]
	if args["sort"] ~= nil then
		sort = args["sort"]
	end
	local collapse = frame_args["collapse"]
	if args["collapse"] ~= nil then
		collapse = args["collapse"]
	end

	local put
	for i, item in ipairs(args[first_content_param]) do
		-- Parse off an initial language code (e.g. 'la:minūtia' or 'grc:[[σκῶρ|σκατός]]').
		local termlang, actual_term = item:match("^([A-Za-z0-9._-]+):(.*)$")
		if termlang and termlang ~= "w" then -- special handling for w:... links to Wikipedia
			-- -1 since i is one-based
			termlang = m_languages.getByCode(termlang, first_content_param + i - 1, "allow etym")
			item = actual_term
		else
			termlang = lang
		end
		local termobj = {term = {}}
		part.lang = part.lang or termlang
		part.term = term

		-- Check for inline modifier, e.g. מרים<tr:Miryem>. But exclude HTML entry with <span ...>, <i ...>, <br/> or
		-- similar in it, caused by wrapping an argument in {{l|...}}, {{af|...}} or similar. Basically, all tags of
		-- the sort we parse here should consist of a less-than sign, plus letters, plus a colon, e.g. <tr:...>, so if
		-- we see a tag on the outer level that isn't in this format, we don't try to parse it. The restriction to the
		-- outer level is to allow generated HTML inside of e.g. qualifier tags, such as foo<q:similar to {{m|fr|bar}}>.
		if item:find("<") and not item:find("^[^<]*<[a-z]*[^a-z:]") then
			if not put then
				put = require("Module:parse utilities")
			end
			local run = put.parse_balanced_segment_run(item, "<", ">")
			local orig_param = first_content_param + i - 1
			local function parse_err(msg)
				error(msg .. ": " .. orig_param .. "= " .. table.concat(run))
			end
			local termobj = {term = {}}
			termobj.term.lang = lang
			termobj.term.term = run[1]

			for j = 2, #run - 1, 2 do
				if run[j + 1] ~= "" then
					parse_err("Extraneous text '" .. run[j + 1] .. "' after modifier")
				end
				local modtext = run[j]:match("^<(.*)>$")
				if not modtext then
					parse_err("Internal error: Modifier '" .. modtext .. "' isn't surrounded by angle brackets")
				end
				local prefix, arg = modtext:match("^([a-z]+):(.*)$")
				if not prefix then
					parse_err("Modifier " .. run[j] .. " lacks a prefix, should begin with one of '" ..
						table.concat(param_mods, ":', '") .. ":'")
				end
				if param_mod_set[prefix] then
					local obj_to_set
					if prefix == "q" then
						obj_to_set = termobj
					else
						obj_to_set = termobj.term
					end
					if prefix == "t" then
						prefix = "gloss"
					elseif prefix == "g" then
						prefix = "genders"
						arg = mw.text.split(arg, ",")
					elseif prefix == "sc" then
						arg = require("Module:scripts").getByCode(arg, orig_param .. ":sc")
					end
					if obj_to_set[prefix] then
						parse_err("Modifier '" .. prefix .. "' occurs twice, second occurrence " .. run[j])
					end
					obj_to_set[prefix] = arg
				else
					parse_err("Unrecognized prefix '" .. prefix .. "' in modifier " .. run[j])
				end
			end
			args[first_content_param][i] = termobj
		end
	end

	return export.create_list { column_count = frame_args["columns"] or args[columns_param],
		content = args[first_content_param],
		alphabetize = sort,
		header = args["title"], background_color = "#F8F8FF",
		collapse = collapse,
		toggle_category = frame_args["toggle_category"],
		class = frame_args["class"], lang = lang, sc = sc, format_header = true }
end

function export.display(frame)
	return export.display_from(frame.args, frame:getParent().args)
end

-- A version of col which substs any automatically generated forms in order to save memory (e.g. for Chinese).
function export.generated_forms(frame)
	local column_args, list_args = frame.args, frame:getParent().args

	local iparams = {
		["columns"] = {type = "number"},
		["name"] = {required = true},
		["toggle_category"] = {},
	}

	local frame_args = require("Module:parameters").process(column_args, iparams)

	local first_content_param = 2 + (frame_args["columns"] and 0 or 1)

	frame_args["name"] = frame_args["columns"] and frame_args["name"] .. frame_args["columns"] or frame_args["name"]

	local params = {
		[1] = {required = true, default = "und"},
		[2] = not frame_args["columns"] and {required = true, default = 2} or nil,
		[first_content_param] = {list = true},

		["title"] = {},
		["collapse"] = {type = "boolean"},
		["sort"] = {type = "boolean"},
		["sc"] = {},
	}

	local args = require("Module:parameters").process(list_args, params)

	local lang = args[1]
	lang = m_languages.getByCode(lang, lang_param)

	args["sc"] = args["sc"] or ""
	if sc and sc ~= "" then
		sc = require "Module:scripts".getByCode(sc)
			or error("|sc= does not contain a valid script code")
	end

	args[2] = args[2] or ""
	args["title"] = args["title"] or ""
	args["collapse"] = args["collapse"] or ""
	args["sort"] = args["sort"] or ""

	local items = {}
	for i, item in ipairs(args[first_content_param]) do
		if item:find("<") and not item:find("^[^<]*<[a-z]*[^a-z:]") then
			item = item:gsub("^([^<]*)(<[a-z]*[a-z:])", function(m1, m2)
					return table.concat(lang:generateForms(m1), "//")
			end)
		else
			item = table.concat(lang:generateForms(item), "//")
		end
		table.insert(items, item)
	end

	for k, arg in pairs(args) do
		if type(arg) == "string" then
			if arg ~= "" then
				if type(k) == "string" then
					args[k] = k .. "=" .. args[k] .. "|"
				else
					args[k] = args[k] .. "|"
				end
			end
		elseif type(arg) == "boolean" then
			args[k] = k .. "=1|"
		end
	end

	local prefix = "{{" .. frame_args["name"] .. "|" .. args[1] .. args["sc"]
	prefix = not frame_args["columns"] and prefix .. args[2] or prefix

	return prefix ..  args["title"] ..  args["collapse"] ..  args["sort"] ..  table.concat(items, "|") .. "}}"
end

return export
