local export = {}

local collation_module = "Module:collation"
local debug_track_module = "Module:debug/track"
local headword_data_module = "Module:headword/data"
local languages_module = "Module:languages"
local links_module = "Module:links"
local pages_module = "Module:pages"
local parameter_utilities_module = "Module:parameter utilities"
local parameters_module = "Module:parameters"
local parse_interface_module = "Module:parse interface"
local pron_qualifier_module = "Module:pron qualifier"
local string_utilities_module = "Module:string utilities"
local table_module = "Module:table"
local utilities_module = "Module:utilities"

local m_str_utils = require(string_utilities_module)

local concat = table.concat
local html = mw.html.create
local is_substing = mw.isSubsting
local insert = table.insert
local rmatch = m_str_utils.match
local remove = table.remove
local sub = string.sub
local trim = m_str_utils.trim
local u = m_str_utils.char
local dump = mw.dumpObject
local ucfirst = m_str_utils.ucfirst


local function track(page)
    require(debug_track_module)("columns/" .. page)
    return true
end

local function deepEquals(...)
    deepEquals = require(table_module).deepEquals
    return deepEquals(...)
end

local function term_already_linked(term)
	-- FIXME: "<span" is an ugly hack to prevent double-linking of terms already run through {{l|...}}:
	-- [[Thread:User talk:CodeCat/MewBot adding lang to column templates]]
	return term:find("<span")
end

-- Suppress false positives in categories like [[Category:English links with redundant wikilinks]] so people won't
-- be tempted to "correct" them; terms like embedded ~ like [[Micros~1]] or embedded comma not followed by a space
-- such as [[1,6-Cleves acid]] need to have a link around them to avoid the tilde or comma being interpreted as a
-- delimiter.
local function suppress_redundant_wikilink_cat(term, alt)
	return term:find("~") or term:find(",%S")
end

local function full_link_and_track_self_links(item)
	if item.term then
		local pagename = mw.loadData(headword_data_module).pagename
		local term_is_pagename = item.term == pagename
		local term_contains_pagename = item.term:find("%[%[" .. m_str_utils.pattern_escape(pagename) .. "[|%]]")
		if term_contains_pagename or term_contains_pagename then
			local current_L2 = require(pages_module).get_current_L2()
			if current_L2 then
				local current_L2_lang = require(languages_module).getByCanonicalName(current_L2)
				if current_L2_lang and current_L2_lang:getCode() == item.lang:getCode() then
					if term_is_pagename then
						track("term-is-pagename")
					else
						track("term-contains-pagename")
					end
				end
			end
		end
	end

	item.suppress_redundant_wikilink_cat = suppress_redundant_wikilink_cat
	return require(links_module).full_link(item, face)
end
				
local function format_subitem(subitem, lang, face)
	local text = subitem.term and term_already_linked(subitem.term) and subitem.term or
		full_link_and_track_self_links(subitem, face)
	-- We could use the "show qualifiers" flag to full_link() but not when term_already_linked().
	if subitem.q and subitem.q[1] or subitem.qq and subitem.qq[1] or subitem.l and subitem.l[1] or
		subitem.ll and subitem.ll[1] or subitem.refs and subitem.refs[1] then
		text = require(pron_qualifier_module).format_qualifiers {
			lang = subitem.lang or args.lang,
			text = text,
			q = subitem.q,
			qq = subitem.qq,
			l = subitem.l,
			ll = subitem.ll,
			refs = subitem.refs,
		}
	end
	return text
end

local function format_item(item, args, face)
	local text
	if type(item) == "table" then
		if item.terms then
			local parts = {}
			local is_first = true
			for _, subitem in ipairs(item.terms) do
				if subitem == false then
					-- omitted subitem; do nothing
				else
					local separator = subitem.separator or not is_first and (args.subitem_separator or ", ")
					if separator then
						insert(parts, separator)
					end
					insert(parts, format_subitem(subitem, args.lang, face))
					is_first = false
				end
			end
			return concat(parts)
		else
			return format_subitem(item, args.lang, face)
		end
	elseif args.lang and not term_already_linked(item) then
		return full_link_and_track_self_links({lang = args.lang, term = item, sc = args.sc}, face)
	else
		return item
	end
end

-- Construct the sort base of a single item, using the display form preferentially, otherwise the term itself.
-- As a hack, sort appendices after mainspace items.
local function item_sortbase(item)
	local val = item.alt or item.term
	if not val then
		-- This should not normally happen.
		return u(0x10FFFF)
	elseif val:find("^%[*Appendix:") then
		return u(0x10FFFE) .. val
	else
		return val
	end
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
							insert(parts, ", ")
						end
						insert(parts, item_sortbase(subitem))
						first = false
					end
				end
				if parts[1] then
					return concat(parts)
				end
			else
				local subitem = item.terms[1]
				if subitem ~= false then
					return item_sortbase(subitem)
				end
			end
			return "*" -- doesn't matter, entire group will be omitted in format_list_items()
		else
			return item_sortbase(item)
		end
	else
		return item
	end
end

local function make_node_sortbase(node)
	return make_sortbase(node.item)
end

-- Sort a sublist of `list` in place, keeping the first `keepfirst` and last `keeplast` items fixed.
-- `lang` is the language of the items and `make_sortbase` creates the appropriate sort base.
local function sort_sublist(list, lang, make_sortbase, keepfirst, keeplast)
	if keepfirst == 0 and keeplast == 0 then
		require(collation_module).sort(list, lang, make_sortbase)
	else
		local sublist = {}
		for i = keepfirst + 1, #list - keeplast do
			sublist[i - keepfirst] = list[i]
		end
		require(collation_module).sort(sublist, lang, make_sortbase)
		for i = keepfirst + 1, #list - keeplast do
			list[i] = sublist[i - keepfirst]
		end
	end
end
		

local large_text_scripts = {
	["Arab"] = true,
	["Beng"] = true,
	["Deva"] = true,
	["Gujr"] = true,
	["Guru"] = true,
	["Hebr"] = true,
	["Khmr"] = true,
	["Knda"] = true,
	["Laoo"] = true,
	["Mlym"] = true,
	["Mong"] = true,
	["Mymr"] = true,
	["Orya"] = true,
	["Sinh"] = true,
	["Syrc"] = true,
	["Taml"] = true,
	["Telu"] = true,
	["Tfng"] = true,
	["Thai"] = true,
	["Tibt"] = true,
}

--[==[
Format a list of items using HTML. `args` is an object specifying the items to add and related properties, with the
following fields:
* `content`: A list of the items to format. See below for the format of the items.
* `lang`: The language object of the items to format, if the items in `content` are strings.
* `sc`: The script object of the items to format, if the items in `content` are strings.
* `raw`: If true, return the list raw, without any collapsing or columns.
* `class`: The CSS class of the surrounding <div>.
* `column_count`: Number of columns to format the list into.
* `alphabetize`: If true, sort the items in the table.
* `collapse`: If true, make the table partially collapsed by default, with a "Show more" button at the bottom.
* `toggle_category`: Value of `data-toggle-category` property grouping collapsible elements.
* `header`: If specified, Wikicode to prepend to the output.
* `format_header`: If specified and `header` given, put a <div> around the specified header text.
* `subitem_separator`: Separator used between subitems when multiple subitems occur on a line, if not specified in the
                       subitem itself (using the `separator` field). Defaults to {", "}.

Each item in `content` is in one of the following formats:
* A string. This is for compatibility and should not be used by new callers.
* An object describing an item to format, in the format expected by full_link() in [[Module:links]] but can also
  have left or right qualifiers, left or right labels, or references.
* An object describing a list of subitems to format, displayed side-by-side, separated by a comma or other separator.
  This format is identified by the presence of a key `terms` specifying the list of subitems. Each subitem is in
  the same format as for a single top-level item, except that it should also have a `separator` field specifying the
  separator to display before each item (which will typically be a blank string before the first item).
]==]
function export.create_list(args)
	if type(args) ~= "table" then
		error("expected table, got " .. type(args))
	end

	local column_count = args.column_count or 1
	local toggle_category = args.toggle_category or "derived terms"
	local header = args.header
	local keepfirst = args.keepfirst or 0
	local keeplast = args.keeplast or 0
	if keepfirst > 0 then
		track("keepfirst")
	end
	if keeplast > 0 then
		track("keeplast")
	end

	if header and args.format_header then
		header = html("div")
			:addClass("term-list-header")
			:wikitext(header)
	end

	local list

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
		local function make_node(item)
			return {
				item = item
			}
		end
		local root_node = make_node(nil)
		local node_stack = {root_node}
		local last_indent = 0
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
				local node = make_node(item)
				if this_indent == last_indent then
					append_subnode(node_stack[#node_stack], node)
				elseif this_indent > last_indent + 1 then
					error(("Element #%s (%s) has indent %s, which is more than one greater than the previous item with indent %s"):format(
						i, make_sortbase(item), this_indent, last_indent))
				elseif this_indent > last_indent then
					-- Start a new sublist attached to the last item of the sublist one level up; but we need special
					-- handling for the root node (last_indent == 0).
					if last_indent > 0 then
						local subnodes = node_stack[#node_stack].subnodes
						if not subnodes then
							error(("Internal error: Not first item and no subnodes at preceding level %s: %s"):format(
								#node_stack, dump(node_stack)))
						end
						insert(node_stack, subnodes[#subnodes])
					end
					append_subnode(node_stack[#node_stack], node)
					last_indent = this_indent
				else
					while last_indent > this_indent do
						local finished_node = table.remove(node_stack)
						if args.alphabetize then
							require(collation_module).sort(finished_node.subnodes, args.lang, make_node_sortbase)
						end
						last_indent = last_indent - 1
					end
					append_subnode(node_stack[#node_stack], node)
				end
			end
		end
		if args.alphabetize then
			while node_stack[1] do
				local finished_node = table.remove(node_stack)
				if node_stack[1] then
					-- We're sorting something other than the root node.
					require(collation_module).sort(finished_node.subnodes, args.lang, make_node_sortbase)
				else
					-- We're sorting the root node; honor `keepfirst` and `keeplast`.
					sort_sublist(finished_node.subnodes, args.lang, make_node_sortbase, keepfirst, keeplast)
				end
			end
		end

		local function format_node(node)
			local sublist
			if node.subnodes then
				sublist = html("ul")
				local prevnode = nil
				for _, subnode in ipairs(node.subnodes) do
					local thisnode = format_node(subnode)
					if not prevnode or not deepEquals(prevnode, thisnode) then
						sublist = sublist:node(thisnode)
						prevnode = thisnode
					end
				end
			end
			if not node.item then
				-- At the root.
				return sublist
			end
			local listitem = html("li"):wikitext(format_item(node.item, args))
			if sublist then
				listitem = listitem:node(sublist)
			end
			return listitem
		end

		list = format_node(root_node)
	else
		if args.alphabetize then
			sort_sublist(args.content, args.lang, make_sortbase, keepfirst, keeplast)
		end
		list = html("ul")
		local previtem = nil
		for _, item in ipairs(args.content) do
			if item == false then
				-- omitted item; do nothing
			else
				local thisitem = format_item(item, args)
				if not previtem or previtem ~= thisitem then
					list = list:node(html("li"):wikitext(thisitem))
					previtem = thisitem
				end
			end
		end
	end

	local output = html("div")
		:addClass("term-list")
		:node(list)
			
	if args.class then
		output:addClass(args.class)
	end
	
	if not args.raw then
		output:addClass("ul-column-count")
			:attr("data-column-count", column_count)

		if args.collapse then
			output = html("div")
				:addClass("list-switcher-wrapper")
				:node(
					html("div")
						:node(output)
						:addClass("list-switcher")
						:attr("data-toggle-category", toggle_category)
				)
		end

		-- identify commonly used scripts that use large text and
		-- provide a special CSS class to make the template bigger
		local sc = args.sc
		if sc == nil then
			local scripts = args.lang:getScripts()
			if #scripts > 0 then
				sc = scripts[1]
			end
		end
		if sc ~= nil then
			local scriptcode = sc:getParentCode()
			if scriptcode == "top" then
				scriptcode = sc:getCode()
			end
			if large_text_scripts[scriptcode] then
				output:addClass("list-switcher-large-text")
			end
		end
	end

	return tostring(header or "") .. tostring(output)
end


-- This function is for compatibility with earlier version of [[Module:columns]]
-- (now found in [[Module:columns/old]]).
function export.create_table(...)
	-- Earlier arguments to create_table:
	-- n_columns, content, alphabetize, bg, collapse, class, title, column_width, line_start, lang
	local args = {}
	args.column_count, args.content, args.alphabetize,
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
		["toggle_category"] = true,
		-- Minimum number of rows required to format into a multicolumn list. If below this, the list is displayed
		-- "raw" (no columns, no collapsbility).
		["minrows"] = {type = "number", default = 5},
	}

	local iargs = require(parameters_module).process(frame_args, iparams)

	local compat = iargs.lang or parent_args.lang
	local lang_param = compat and "lang" or 1
	local deprecated = lang_param == "lang"

	local ret = export.handle_display_from_or_topic_list(iargs, parent_args, {}, nil)

	return deprecated and frame:expandTemplate{title = "check deprecated lang param usage",
		args = {ret, lang = args[lang_param]}} or ret
end


function export.topic_list(frame)
	local raw_item_args = frame.args
	local frame_parent = frame:getParent()
	local raw_user_args = frame_parent.args
	local topic_list_template = frame_parent:getTitle()

	local user_params = {
		nocat = {type = "boolean"},
		sortbase = {},
	}

	local user_args = require(parameters_module).process(raw_user_args, user_params)

	return export.handle_display_from_or_topic_list({}, raw_item_args, user_args, topic_list_template)
end

local function convert_delimiter_to_separator(item, itemind)
	if itemind == 1 then
		item.separator = nil
	elseif item.delimiter == "~" then
		item.separator = " ~ "
	else
		item.separator = ", "
	end
end

-- FIXME: This needs to be implemented properly in [[Module:links]].
local function get_left_side_link(link)
	local left, right = link:match("^%[%[([^%[%]|]+)|([^%[%]|]+)%]%]$")
	if left, right then
		return left
	end
	local single_part = link:match("^%[%[([^%[%]|]+)%]%]$")
	if single_part then
		return single_part
	end
	if not link:match("%[%[") then
		return link
	end
	return nil
end

function export.handle_display_from_or_topic_list(iargs, raw_item_args, user_args, topic_list_template)
	local boolean = {type = "boolean"}
	local compat = iargs.lang or raw_item_args.lang
	local lang_param = compat and "lang" or 1
	local first_content_param = compat and 1 or 2

	local params = {
		[lang_param] =
			not iargs.lang and {required = true, type = "language", template_default = "und"} or nil,
		["n"] = not iargs.columns and {type = "number"} or nil,
		[first_content_param] = {list = true, allow_holes = true},

		["title"] = {},
		["collapse"] = boolean,
		["sort"] = boolean,
		["sc"] = {type = "script"},
		["omit"] = {list = true}, -- used when calling from [[Module:saurus]] so the page displaying the synonyms/antonyms doesn't occur in the list
		["keepfirst"] = {type = "number", default = 0},
		["keeplast"] = {type = "number", default = 0},
		["pagename"] = {}, -- for testing of topic list
	}

	if topic_list_template then
		params["cat"] = {}
		params["enhypernym"] = {}
		params["hypernym"] = {}
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
		splitchar = "[,~]",
	}

	local lang = iargs.lang or args[lang_param]
	local langcode = lang:getCode()
	local fulllangcode = lang:getFullCode()
	local sc = args.sc.default

	local sort = iargs.sort
	if args.sort ~= nil then
		if not args.sort then
			track("nosort")
		end
		sort = args.sort
	else
		-- HACK! For Japanese-script languages (Japanese, Okinawan, Miyako, etc.), sorting doesn't yet work properly, so
		-- disable it.
		for _, langsc in ipairs(lang:getScriptCodes()) do
			if langsc == "Jpan" then
				sort = false
				break
			end
		end
	end

	local collapse = iargs.collapse
	if args.collapse ~= nil then
		if not args.collapse then
			track("nocollapse")
		end
		collapse = args.collapse
	end

	local title = args.title
	local formatted_cats
	if topic_list_template then
		local cats
		-- Chop off anything after a slash. There are templates with names like
		-- [[Template:list:days of the week/cim/Luserna]] (for the Luserna dialect of Cimbrian) and
		-- [[Template:list:days of the week/cim/13]] (for the Tredici Comuni dialect of Cimbrian) so we can't just
		-- assume there will be a single slash followed by a language code.
		local default_title = topic_list_template:gsub("^Template:", ""):gsub("^list:", ""):gsub("/.*$", "")
		if not args.cat then
			local default_cat = ucfirst(default_title)
			local cat_title = mw.title.new(("Category:%s"):format(default_cat))
			if cat_title and cat_title.exists then
				cats = {fulllangcode .. ":" .. default_cat}
			end
		elseif args.cat ~= "-" then
			cats = require(parse_interface_module).split_on_comma(args.cat)
			for i, cat in ipairs(cats) do
				if cat:find("^Category:") then
					cats[i] = cat:gsub("^Category:", "")
				else
					cats[i] = fulllangcode .. ":" .. cats[i]
				end
			end
		end
		if not title then
			local titleparts = {}
			local function ins(txt)
				table.insert(titleparts, txt)
			end
			local enhypernym = args.enhypernym or default_title
			if cats and not enhypernym:find("%[%[") then
				ins(("[[:Category:%s|%s]]"):format(cats[1], enhypernym))
			else
				ins(enhypernym)
			end
			if args.hypernym then
				local function generate_obj(term, parse_err)
					local actual_term, termlang = require(parse_interface_module).parse_term_with_lang {
						term = term,
						parse_err = parse_err,
						paramname = "hypernym",
					}
					return {
						term = actual_term ~= "" and actual_term or nil,
						lang = termlang or lang,
					}
				end
				local lang_hypernyms = require(parse_interface_module).parse_inline_modifiers(args.hypernym, {
					paramname = "hypernym",
					param_mods = param_mods,
					generate_obj = generate_obj,
					splitchar = "[,~]",
					preserve_splitchar = true,
					outer_container = {},
				})
				local hypernym_is_page = false
				local pagename = args.pagename or mw.loadData("Module:headword/data").pagename
				for i, lang_hypernym in ipairs(lang_hypernyms.terms) do
					convert_delimiter_to_separator(lang_hypernym, i)
					-- Do this afterwards rather than in generate_obj() or use of <sc:...> will trigger an error
					-- because the modifier is already set.
					if not lang_hypernym.sc and sc then
						lang_hypernym.sc = sc
					end
					if lang_hypernym.term then
						local left_side = get_left_side_link(lang_hypernym.term)
						if left_side and left_side == pagename then
							hypernym_is_page = true
							break
						end
					end
				end
				if cats and not user_args.nocat and not hypernym_is_page then
					formatted_cats = require(utilities_module).format_categories(cats, lang, nil, user_args.sortbase)
				end
				local formatted_hypernyms = format_item(lang_hypernyms, {lang = lang}, "bold")
				ins(": " .. formatted_hypernyms)
			end
		end
	end

	local number_of_groups = 0
	for i, group in ipairs(groups) do
		local number_of_items = 0
		for j, item in ipairs(group.terms) do
			if j == 1 then
				if item.term then
					local extra_indent, actual_term = rmatch(item.term, "^(%*+)%s+(.-)$")
					if extra_indent then
						item.term = actual_term
						group.extra_indent = #extra_indent
					end
				end
			end

			convert_delimiter_to_separator(item, j)

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
	local raw = number_of_groups < iargs.minrows

	return export.create_list {
		column_count = column_count,
		raw = raw,
		content = groups,
		alphabetize = sort,
		header = title,
		collapse = collapse,
		toggle_category = iargs.toggle_category,
		-- columns-bg (in [[MediaWiki:Gadget-Site.css]]) provides the background color
		class = (iargs.class and iargs.class .. " columns-bg" or "columns-bg"),
		lang = lang,
		sc = sc,
		format_header = true,
		subitem_separator = ", ",
		keepfirst = args.keepfirst,
		keeplast = args.keeplast,
	} .. (formatted_cats or "")
end

function export.display(frame)
	if not is_substing() then
		return export.display_from(frame.args, frame:getParent().args, frame, false)
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
			not elem:match("^()%[%[") or
			elem:find("[[", 3, true) or
			elem:find("]]", 3, true) ~= #elem - 1 or
			elem:find("|", 3, true)
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
