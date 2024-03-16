local export = {}

local html = mw.html.create
local m_links = require("Module:links")
local m_languages = require("Module:languages")
local m_table = require("Module:table")
local parse_utilities_module = "Module:parse utilities"

local rsplit = mw.text.split

local function format_list_items(list, args)
	local function term_already_linked(term)
		-- FIXME: "<span" is an ugly hack to prevent double-linking of terms already run through {{l|...}}:
		-- [[Thread:User talk:CodeCat/MewBot adding lang to column templates]]
		return term:find("<span")
	end
	for _, item in ipairs(args.content) do
		if item == false then
			-- omitted item; do nothing
		else
			if type(item) == "table" then
				item = term_already_linked(item.term) and item.term or
					m_links.full_link(item, nil, nil, "show qualifiers")
			elseif args.lang and not term_already_linked(item) then
				item = m_links.full_link {lang = args.lang, term = item, sc = args.sc} 
			end
	
			list = list:node(html("li")
				:wikitext(item)
			)
		end
	end

	return list
end

function export.create_list(args)
	-- Fields in args that are used:
	-- args.column_count, args.content, args.alphabetize, args.background_color,
	-- args.collapse, args.toggle_category, args.class, args.lang
	-- Check for required fields?
	if type(args) ~= "table" then
		error("expected table, got " .. type(args))
	end

	local class = args.class or "derivedterms"
	local column_count = args.column_count or 1
	local toggle_category = args.toggle_category or "derived terms"
	local header = args.header

	if header and args.format_header then
		header = html("div")
			:addClass("term-list-header")
			:wikitext(header)
	end

	if args.alphabetize then
		local function keyfunc(item)
			if item == false then
				item = "*" -- doesn't matter, will be omitted in format_list_items()
			elseif type(item) == "table" then
				item = item.alt or item.term
			end
			return item
		end
		require("Module:collation").sort(args.content, args.lang, keyfunc)
	end

	local list = html("ul")
	list = format_list_items(list, args)

	local output = html("div")
		:addClass(class)
		:addClass("term-list")
		:addClass("ul-column-count")
		:attr("data-column-count", column_count)
		:css("background-color", args.background_color)
		:node(list)

	if args.collapse then
		local nbsp = mw.ustring.char(0xA0)
		output = html("div")
			:node(output)
			:addClass("list-switcher")
			:attr("data-toggle-category", toggle_category)
			:node(html("div")
				:addClass("list-switcher-element")
				:attr("data-showtext", nbsp .. "show more ▼" .. nbsp)
				:attr("data-hidetext", nbsp .. "show less ▲" .. nbsp)
				:css("display", "none")
				:wikitext(nbsp)
			)
	end

	return tostring(header or "") .. tostring(output)
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


local param_mods = {
	t = {
		-- We need to store the <t:...> inline modifier into the "gloss" key of the parsed part, because that is what
		-- [[Module:links]] expects.
		item_dest = "gloss",
	},
	gloss = {},
	tr = {},
	ts = {},
	g = {
		-- We need to store the <g:...> inline modifier into the "genders" key of the parsed part, because that is what
		-- [[Module:links]] expects.
		item_dest = "genders",
		convert = function(arg, parse_err)
			return rsplit(arg, ",")
		end,
	},
	id = {},
	alt = {},
	q = {},
	qq = {},
	lit = {},
	pos = {},
	sc = {
		convert = function(arg, parse_err)
			return require("Module:scripts").getByCode(arg, parse_err)
		end,
	}
}

local function parse_term_with_modifiers(paramname, val, lang, sc, lang_cache)
	local function generate_obj(term, parse_err)
		local obj = {}
		if term:find(":") then
			local actual_term, termlangs = require(parse_utilities_module).parse_term_with_lang {
				term = term,
				parse_err = parse_err,
				paramname = paramname,
				allow_multiple = true,
				allow_bad = true,
				lang_cache = lang_cache,
			}
			obj.term = actual_term
			obj.termlangs = termlangs
			obj.lang = termlangs and termlangs[1] or lang
		else
			obj.term = term
			obj.lang = lang
		end
		obj.sc = sc
		return obj
	end

	-- Check for inline modifier, e.g. מרים<tr:Miryem>. But exclude HTML entry with <span ...>, <i ...>, <br/> or
	-- similar in it, caused by wrapping an argument in {{l|...}}, {{m|...}} or similar. Basically, all tags of
	-- the sort we parse here should consist of a less-than sign, plus letters, plus a colon, e.g. <tr:...>, so if
	-- we see a tag on the outer level that isn't in this format, we don't try to parse it. The restriction to the
	-- outer level is to allow generated HTML inside of e.g. qualifier tags, such as foo<q:similar to {{m|fr|bar}}>.
	if val:find("<") and not val:find("^[^<]*<[a-z]*[^a-z:]") then
		return require(parse_utilities_module).parse_inline_modifiers(val, {
			paramname = paramname,
			param_mods = param_mods,
			generate_obj = generate_obj,
		})
	else
		return generate_obj(val)
	end
end

function export.display_from(frame_args, parent_args, frame)
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

	local iargs = require("Module:parameters").process(frame_args, iparams, nil, "columns", "display_from")

	local compat = iargs["lang"] or parent_args["lang"]
	local lang_param = compat and "lang" or 1
	local columns_param, first_content_param

	-- New-style #columns specification is through parameter n= so we can transition to the situation where
	-- omitting it results in auto-determination. Old-style #columns specification is through the first numbered
	-- parameter after the lang parameter.
	if parent_args["n"] then
		columns_param = "n"
		first_content_param = compat and 1 or 2
	else
		columns_param = compat and 1 or 2
		first_content_param = columns_param + (iargs["columns"] and 0 or 1)
	end
	local deprecated

	local params = {
		[lang_param] = not iargs["lang"] and {required = true, default = "und"} or nil,
		[columns_param] = not iargs["columns"] and {required = true, default = 2} or nil,
		[first_content_param] = {list = true},

		["title"] = {},
		["collapse"] = {type = "boolean"},
		["sort"] = {type = "boolean"},
		["sc"] = {},
		["omit"] = {list = true}, -- used when calling from [[Module:saurus]] so the page displaying the synonyms/antonyms doesn't occur in the list
	}

	if lang_param == "lang" then
		deprecated = true
	end

	local args = require("Module:parameters").process(parent_args, params, nil, "columns", "display_from")

	local langcode = iargs["lang"] or args[lang_param]
	local lang = m_languages.getByCode(langcode, lang_param)

	local sc = args["sc"] and require("Module:scripts").getByCode(sc, "sc") or nil

	local sort = iargs["sort"]
	if args["sort"] ~= nil then
		sort = args["sort"]
	end
	local collapse = iargs["collapse"]
	if args["collapse"] ~= nil then
		collapse = args["collapse"]
	end
	
	local lang_cache = {
		[langcode] = lang
	}
	for i, item in ipairs(args[first_content_param]) do
		local termobj = parse_term_with_modifiers(first_content_param + i - 1, item, lang, sc, lang_cache)
		-- If a separate language code was given for the term, display the language name as a right qualifier.
		-- Otherwise it may not be obvious that the term is in a separate language (e.g. if the main language is 'zh'
		-- and the term language is a Chinese lect such as Min Nan). But don't do this for Translingual terms, which
		-- are often added to the list of English and other-language terms.
		if termobj.termlangs then
			local qqs = {}
			for _, termlang in ipairs(termobj.termlangs) do
				local termlangcode = termlang:getCode()
				if termlanglangcode ~= langcode and termlangcode ~= "mul" then
					table.insert(qqs, termlang:getCanonicalName())
				end
				table.insert(qqs, termobj.qq)
			end
			termobj.qq = qqs
		end

		local omitted = false
		for _, omitted_item in ipairs(args.omit) do
			if omitted_item == termobj.term then
				omitted = true
				break
			end
		end
		if omitted then
			-- signal create_list() to omit this item
			args[first_content_param][i] = false
		else
			args[first_content_param][i] = termobj
		end
	end

	local ret = export.create_list { column_count = iargs["columns"] or args[columns_param],
		content = args[first_content_param],
		alphabetize = sort,
		header = args["title"], background_color = "#F8F8FF",
		collapse = collapse,
		toggle_category = iargs["toggle_category"],
		class = iargs["class"], lang = lang, sc = sc, format_header = true }

	return deprecated and frame:expandTemplate{title = "check deprecated lang param usage", args = {ret, lang = args[lang_param]}} or ret
end

function export.display(frame)
	return export.display_from(frame.args, frame:getParent().args, frame)
end

return export
