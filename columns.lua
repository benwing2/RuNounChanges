local export = {}

local html = mw.html.create
local m_str_utils = require("Module:string utilities")
local links_module = "Module:links"
local parameter_utilities_module = "Module:parameter utilities"
local parameters_module = "Module:parameters"
local pron_qualifier_module = "Module:pron qualifier"

local u = m_str_utils.char

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
			local text
			if type(item) == "table" then
				text = item.term and term_already_linked(item.term) and item.term or require(links_module).full_link(item)
				-- We could use the "show qualifiers" flag to full_link() but not when term_already_linked().
				if item.q and item.q[1] or item.qq and item.qq[1] or item.l and item.l[1] or item.ll and item.ll[1] or
					item.refs and item.refs[1] then
					text = require(pron_qualifier_module).format_qualifiers {
						lang = item.lang or args.lang,
						text = text,
						q = item.q,
						qq = item.qq,
						l = item.l,
						ll = item.ll,
						refs = item.refs,
					}
				end
			elseif args.lang and not term_already_linked(item) then
				text = require(links_module).full_link {lang = args.lang, term = item, sc = args.sc} 
			else
				text = item
			end

			list = list:node(html("li")
				:wikitext(text)
			)
		end
	end

	return list
end

local function make_sortbase(item)
	if item == false then
		return "*" -- doesn't matter, will be omitted in format_list_items()
	elseif type(item) == "table" then
		return item.alt or item.term
	end
	return item
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
		require("Module:collation").sort(args.content, args.lang, make_sortbase)
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
		local nbsp = u(0xA0)
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
		["lang"] = {type = "language", etym_lang = true},
		-- Default for auto-sort. Overridable by template |sort= param.
		["sort"] = {type = "boolean"},
		-- The following is accepted but currently ignored, per an extended discussion in
		-- [[Wiktionary:Beer parlour/2018/November#Titles of morphological relations templates]].
		["title"] = {default = ""},
		["toggle_category"] = {},
	}

	local iargs = require(parameters_module).process(frame_args, iparams)

	local compat = iargs.lang or parent_args.lang
	local lang_param = compat and "lang" or 1
	local offset = compat and 0 or 1
	local columns_param, first_content_param

	-- New-style #columns specification is through parameter n= so we can transition to the situation where
	-- omitting it results in auto-determination. Old-style #columns specification is through the first numbered
	-- parameter after the lang parameter.
	if parent_args.n then
		columns_param = "n"
		first_content_param = compat and 1 or 2
	else
		columns_param = compat and 1 or 2
		first_content_param = columns_param + (iargs.columns and 0 or 1)
	end
	local deprecated

	local params = {
		[lang_param] =
			not iargs.lang and {required = true, type = "language", etym_lang = true, default = "und"} or nil,
		[columns_param] = not iargs.columns and {required = true, default = 2} or nil,
		[first_content_param] = {list = true, allow_holes = true},

		["title"] = {},
		["collapse"] = {type = "boolean"},
		["sort"] = {type = "boolean"},
		["sc"] = {type = "script"},
		["omit"] = {list = true}, -- used when calling from [[Module:saurus]] so the page displaying the synonyms/antonyms doesn't occur in the list
	}

	if lang_param == "lang" then
		deprecated = true
	end

	local m_param_utils = require(parameter_utilities_module)

	local param_mods = m_param_utils.construct_param_mods {
		{default = true, require_index = true},
		{set = "link"}, -- sc has separate_no_index = true; that's the only one
		-- It makes no sense to have overall l=, ll=, q= or qq= params for columnar display.
		{set = {"ref", "l", "q"}, require_index = true},
	}
	m_param_utils.augment_params_with_modifiers(params, param_mods)

	local args = require(parameters_module).process(parent_args, params)

	local lang = iargs.lang or args[lang_param]
	local langcode = lang:getCode()
	local sc = args.sc.default

	local sort = iargs.sort
	if args.sort ~= nil then
		sort = args.sort
	end
	local collapse = iargs.collapse
	if args.collapse ~= nil then
		collapse = args.collapse
	end
	
	local items = m_param_utils.process_list_arguments {
		args = args,
		param_mods = param_mods,
		termarg = first_content_param,
		parse_lang_prefix = true,
		allow_multiple_lang_prefixes = true,
		disallow_custom_separators = true,
		track_module = "columns",
		lang = lang,
		sc = sc,
	}

	for i, item in ipairs(items) do
		-- If a separate language code was given for the term, display the language name as a right qualifier.
		-- Otherwise it may not be obvious that the term is in a separate language (e.g. if the main language is 'zh'
		-- and the term language is a Chinese lect such as Min Nan). But don't do this for Translingual terms, which
		-- are often added to the list of English and other-language terms.
		if item.termlangs then
			local qqs = {}
			for _, termlang in ipairs(item.termlangs) do
				local termlangcode = termlang:getCode()
				if termlanglangcode ~= langcode and termlangcode ~= "mul" then
					table.insert(qqs, termlang:getCanonicalName())
				end
				if item.qq then
					for _, qq in ipairs(item.qq) do
						table.insert(qqs, qq)
					end
				end
			end
			item.qq = qqs
		end
		local omitted = false
		for _, omitted_item in ipairs(args.omit) do
			if omitted_item == item.term then
				omitted = true
				break
			end
		end
		if omitted then
			-- signal create_list() to omit this item
			items[i] = false
		end
	end

	local ret = export.create_list { column_count = iargs.columns or args[columns_param],
		content = items,
		alphabetize = sort,
		header = args.title,
		background_color = "#F8F8FF",
		collapse = collapse,
		toggle_category = iargs.toggle_category,
		class = iargs.class,
		lang = lang,
		sc = sc,
		format_header = true
	}

	return deprecated and frame:expandTemplate{title = "check deprecated lang param usage", args = {ret, lang = args[lang_param]}} or ret
end

function export.display(frame)
	return export.display_from(frame.args, frame:getParent().args, frame)
end

return export
