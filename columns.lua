local links_module = "Module:links"
local parameter_utilities_module = "Module:parameter utilities"
local parameters_module = "Module:parameters"
local pron_qualifier_module = "Module:pron qualifier"
local string_utilities_module = "Module:string utilities"

local m_str_utils = require(string_utilities_module)

local concat = table.concat
local html = mw.html.create
local is_substing = mw.isSubsting
local find = string.find
local insert = table.insert
local match = string.match
local remove = table.remove
local sub = string.sub
local trim = m_str_utils.trim
local u = m_str_utils.char

local export = {}


-- Format a list of items using HTML. `list` is an HTML object (as created by `mw.html.create`), to which the formatted
-- items are added. `args` is an object specifying the items to add and related properties, with the following fields:
-- * `content`: A list of the items to format. See below for the format of the items.
-- * `lang`: The language object of the items to format, if the items in `content` are strings.
-- * `sc`: The script object of the items to format, if the items in `content` are strings.
-- There may be other fields in `args` for use by `create_list` (the caller), but they are ignored.
--
-- Each item on `content` is in one of the following formats:
-- * A string. This is for compatibility and should not be used by new callers.
-- * An object describing an item to format, in the format expected by full_link() in [[Module:links]] but can also
--   have left or right qualifiers, left or right labels, or references.
-- * An object describing a list of subitems to format, displayed side-by-side, separated by a comma or other separator.
--   This format is identified by the presence of a key `terms` specifying the list of subitems. Each subitem is in
--   the same format as for a single top-level item, except that it should also have a `separator` field specifying the
--   separator to display before each item (which will typically be a blank string before the first item).
local function format_list_items(list, args)
	local function term_already_linked(term)
		-- FIXME: "<span" is an ugly hack to prevent double-linking of terms already run through {{l|...}}:
		-- [[Thread:User talk:CodeCat/MewBot adding lang to column templates]]
		return find(term, "<span")
	end
	local function format_single_item(item)
		local text = item.term and term_already_linked(item.term) and item.term or require(links_module).full_link(item)
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
		return text
	end
	for _, item in ipairs(args.content) do
		if item == false then
			-- omitted item; do nothing
		else
			local text
			if type(item) == "table" then
				if item.terms then
					local parts = {}
					local is_first = true
					for _, subitem in ipairs(item.terms) do
						if subitem == false then
							-- omitted subitem; do nothing
						else
							local separator = subitem.separator or not is_first and args.subitem_separator
							if separator then
								insert(parts, separator)
							end
							insert(parts, format_single_item(subitem))
							is_first = false
						end
					end
					text = concat(parts)
				else
					text = format_single_item(item)
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
		if item.terms then
			-- Optimize for the common case of only a single term
			if item.terms[2] then
				local parts = {}
				-- multiple terms
				local first = true
				for _, subitem in ipairs(item.terms) do
					if subitem ~= false then
						if not first then
							insert(", ")
						end
						insert(subitem.alt or subitem.term)
						first = false
					end
				end
				if parts[1] then
					return concat(parts)
				end
			else
				local subitem = item.terms[1]
				if subitem ~= false then
					return subitem.alt or subitem.term
				end
			end
			return "*" -- doesn't matter, entire group will be omitted in format_list_items()
		else
			return item.alt or item.term
		end
	else
		return item
	end
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

	local any_extra_indented_item = false
	for _, item in ipairs(args.content) do
		if item == false then
			-- do nothing
		elseif type(item) == "table" and item.extra_indent and item.extra_indent > 0 then
			any_extra_indented_item = true
			break
		end
	end

	-- If any extra indented item, convert the items to a nested structure, which is necessary both for sorting and
	-- for converting to HTML.
	if any_extra_indented_item then
		local node_stack = {}
		local last_indent = 0
		local function make_node(item)
			return {
				item = item
			}
		end
		local function append_subnode(node, subnode)
			if not node.subnodes then
				node.subnodes = {}
			end
			insert(node.subnodes, subnode)
		end
		for i, item in ipairs(args.content) do
			if item == false then
				-- do nothing
			else
				local this_indent
				if type(item) ~= "table" then
					this_indent = 1
				else
					this_indent = (item.extra_indent or 0) + 1
				end
				if this_indent == last_indent then
					append_subitem(node_stack[#node_stack], make_node(item))
				elseif this_indent > last_indent + 1 then
					error(("Element #%s (%s) has indent %s, which is more than one greater than the previous item with indent %s"):format(
						i, make_sortbase(item), this_indent, last_indent))
				elseif this_indent > last_indent then
					insert(item_stack[#item_stack].subitems, {
						item = item,


			if item.terms then
				for _, subitem in ipairs(item.terms) do
					if subitem ~= false then
						return subitem.alt or subitem.term
					end
				end
				return "*" -- doesn't matter, entire group will be omitted in format_list_items()
			else
				return item.alt or item.term
			end
		end
	return item
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
	local boolean = {type = "boolean"}
	local iparams = {
		["class"] = true,
		-- Default for auto-collapse. Overridable by template |collapse= param.
		["collapse"] = boolean,
		-- If specified, this specifies the number of columns, and no columns
		-- parameter is available on the template. Otherwise, the columns
		-- parameter is the first available numbered param after the language-code
		-- parameter.
		["columns"] = {type = "number"},
		-- If specified, this specifies the language code, and no language-code
		-- parameter is available on the template. Otherwise, the language-code
		-- parameter can be specified as either |lang= or |1=.
		["lang"] = {type = "language"},
		-- Default for auto-sort. Overridable by template |sort= param.
		["sort"] = boolean,
		-- The following is accepted but currently ignored, per an extended discussion in
		-- [[Wiktionary:Beer parlour/2018/November#Titles of morphological relations templates]].
		["title"] = {default = ""},
		["toggle_category"] = true,
	}

	local iargs = require(parameters_module).process(frame_args, iparams)

	local compat = iargs.lang or parent_args.lang
	local lang_param = compat and "lang" or 1
	local first_content_param = compat and 1 or 2
	local deprecated

	local params = {
		[lang_param] =
			not iargs.lang and {required = true, type = "language", default = "und"} or nil,
		["n"] = not iargs.columns and {type = "number"} or nil,
		[first_content_param] = {list = true, allow_holes = true},

		["title"] = {},
		["collapse"] = boolean,
		["sort"] = boolean,
		["sc"] = {type = "script"},
		["omit"] = {list = true}, -- used when calling from [[Module:saurus]] so the page displaying the synonyms/antonyms doesn't occur in the list
	}

	if lang_param == "lang" then
		deprecated = true
	end

	local m_param_utils = require(parameter_utilities_module)

	local param_mods = m_param_utils.construct_param_mods {
		{default = true, require_index = true},
		{group = "link"}, -- sc has separate_no_index = true; that's the only one
		-- It makes no sense to have overall l=, ll=, q= or qq= params for columnar display.
		{group = {"ref", "l", "q"}, require_index = true},
	}

	local groups, args = m_param_utils.process_list_arguments {
		params = params,
		param_mods = param_mods,
		raw_args = parent_args,
		termarg = first_content_param,
		parse_lang_prefix = true,
		allow_multiple_lang_prefixes = true,
		disallow_custom_separators = true,
		track_module = "columns",
		lang = iargs.lang or lang_param,
		sc = "sc.default",
		splitchar = ",",
	}

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

	local number_of_groups = 0
	for i, group in ipairs(groups) do
		local number_of_items = 0
		for j, item in ipairs(group.terms) do
			if j == 1 then
				local extra_indent, actual_term = item.term and item.term:match("^(%*+) +(.-)$")
				if extra_indent then
					item.term = actual_term
					group.extra_indent = #extra_indent
				end
			end
			-- If a separate language code was given for the term, display the language name as a right qualifier.
			-- Otherwise it may not be obvious that the term is in a separate language (e.g. if the main language is
			-- 'zh' and the term language is a Chinese lect such as Min Nan). But don't do this for Translingual terms,
			-- which are often added to the list of English and other-language terms.
			if item.termlangs then
				local qqs = {}
				for _, termlang in ipairs(item.termlangs) do
					local termlangcode = termlang:getCode()
					if termlangcode ~= langcode and termlangcode ~= "mul" then
						insert(qqs, termlang:getCanonicalName())
					end
					if item.qq then
						for _, qq in ipairs(item.qq) do
							insert(qqs, qq)
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
				group.terms[j] = false
			else
				number_of_items = number_of_items + 1
			end
		end
		if number_of_items == 0 then
			-- omit the whole group
			groups[i] = false
		else
			number_of_groups = number_of_groups + 1
		end
	end

	local column_count = iargs.columns or args.n
	-- FIXME: This needs a total rewrite.
	if column_count == nil then
		column_count = number_of_groups <= 3 and 1 or
			number_of_groups <= 9 and 2 or
			number_of_groups <= 27 and 3 or
			number_of_groups <= 81 and 4 or
			5
	end

	local ret = export.create_list {
		column_count = column_count,
		content = groups,
		alphabetize = sort,
		header = args.title,
		collapse = collapse,
		toggle_category = iargs.toggle_category,
		-- columns-bg (in [[MediaWiki:Gadget-Site.css]]) provides the background color
		class = (iargs.class and iargs.class .. " columns-bg" or "columns-bg"),
		lang = lang,
		sc = sc,
		format_header = true,
		subitem_separator = ", ",
	}

	return deprecated and frame:expandTemplate{title = "check deprecated lang param usage", args = {ret, lang = args[lang_param]}} or ret
end

function export.display(frame)
	if not is_substing() then
		return export.display_from(frame.args, frame:getParent().args, frame)
	end

	-- If substed, unsubst template with newlines between each term, redundant wikilinks removed, and remove duplicates + sort terms if sort is enabled.
	local m_table = require("Module:table")
	local m_template_parser = require("Module:template parser")

	local parent = frame:getParent()
	local elems = m_table.shallowCopy(parent.args)
	local code = remove(elems, 1)
	code = code and trim(code)
	local lang = require("Module:languages").getByCode(code, 1)

	local i = 1
	while true do
		local elem = elems[i]
		while elem do
			elem = trim(elem, "%s")
			if elem ~= "" then
				break
			end
			remove(elems, i)
			elem = elems[i]
		end
		if not elem then
			break
		elseif not ( -- Strip redundant wikilinks.
			not match(elem, "^()%[%[") or
			find(elem, "[[", 3, true) or
			find(elem, "]]", 3, true) ~= #elem - 1 or
			find(elem, "|", 3, true)
		) then
			elem = sub(elem, 3, -3)
			elem = trim(elem, "%s")
		end
		elems[i] = elem .. "\n"
		i = i + 1
	end

	-- If sort is enabled, remove duplicates then sort elements.
	if require("Module:yesno")(frame.args.sort) then
		elems = m_table.removeDuplicates(elems)
		require("Module:collation").sort(elems, lang)
	end

	-- Readd the langcode.
	insert(elems, 1, code .. "\n")

	-- TODO: Place non-numbered parameters after 1 and before 2.
	local template = m_template_parser.getTemplateInvocationName(mw.title.new(parent:getTitle()))

	return "{{" .. concat(m_template_parser.buildTemplate(template, elems), "|") .. "}}"
end

return export
