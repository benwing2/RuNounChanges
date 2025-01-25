local export = {}

local columns_module = "Module:User:Benwing2/columns"
local languages_module = "Module:languages"
local parameters_module = "Module:parameters"
local parameter_utilities_module = "Module:parameter utilities"
local parse_interface_module = "Module:parse interface"
local string_utilities_module = "Module:string utilities"
local utilities_module = "Module:utilities"

local m_str_utils = require(string_utilities_module)
local rfind = m_str_utils.find
local ucfirst = m_str_utils.ucfirst

local html = mw.html.create


local force_cat = false -- for testing


local function letter_like_category(data)
	return ("Category:%s letters"):format(data.lang:getCanonicalName())
end

local function page_exists(page)
	local title = mw.title.new(page)
	return title and title.exists
end

local function letter_like_appendix(data)
	local appendices = {}
	local alphabet_appendix = ("Appendix:%s alphabet"):format(data.lang:getCanonicalName())
	if page_exists(alphabet_appendix) then
		table.insert(appendices, ("[[%s|alphabet appendix]]"):format(alphabet_appendix))
	end
	local script_name = data.list_name:match("^(.* script) .*$")
	if not script_name then
		error(("Internal error: Can't pull out script name from list name '%s'"):format(data.list_name))
	end
	local script_appendix = "Appendix:" .. script_name
	if page_exists(script_appendix) then
		table.insert(appendices, ("[[%s|script appendix]]"):format(script_appendix))
	end
	if appendices[1] then
		return table.concat(appendices, ",")
	else
		return nil
	end
end

local letter_like_properties = {
	horiz = "comma",
	sort = false,
	cat = letter_like_category,
	appendix = letter_like_appendix,
	notr = true,
	allow_space_delim = true, -- allow space as a delimiter
	tilde_delim = "~", -- use a tilde without spaces around it
}

local function letter_name_category(data)
	local script_name = data.list_name:match("^(.*) script .*$")
	if not script_name then
		error(("Internal error: Can't pull out script name from list name '%s'"):format(data.list_name))
	end
	return ("%s letter names"):format(script_name)
end

local function calendar_month_adjectives_category(data)
	local calendar = data.list_name:match("^(.*) calendar month ajdectives$")
	if not calendar then
		error(("Internal error: Can't pull out calendar type from list name '%s'"):format(data.list_name))
	end
	return calendar .. "calendar months"
end

local function countries_of_category(data)
	local region = data.list_name:match("^countries of (.*)$")
	if not region then
		error(("Internal error: Can't pull out region from list name '%s'"):format(data.list_name))
	end
	return "Countries in " .. region
end

local topic_list_properties = {
	{".* calendar months", {sort = false}},
	{".* calendar month adjectives", {sort = false, cat = calendar_month_adjectives_category}},
	{".* script letters", letter_like_properties},
	{".* script vowels", letter_like_properties},
	{".* script consonants", letter_like_properties},
	{".* script diacritics", letter_like_properties},
	{".* script digraphs", letter_like_properties},
	-- FIXME: We may need to be smarter, and use a regular columnar display in some cases (e.g. when translit is
	-- present)
	{".* script letter names", {horiz = "bullet", sort = false, cat = letter_name_category}},
	{"books of the.* Testament", {sort = false, cat = "Books of the Bible"}},
	-- FIXME: Use the following instead of the previous when we create 'Books of the Old Testament' and
	-- 'Books of the New Testament'
	--{"books of the Old Testament", {sort = false}},
	--{"books of the .*New Testament", {sort = false, cat = "Books of the New Testament"}},
	{"canids", {horiz = "bullet"}}, -- only 5 items on most lists
	{"countries in .*", {appendix = "Appendix:Countries of the world"}},
	-- FIXME: Delete the following once we rename these categories to 'countries in ...'
	{"countries of .*", {appendix = "Appendix:Countries of the world", cat = countries_of_category}},
	{"days of the week", {horiz = "bullet", sort = false, appendix = "Appendix:Days of the week"}},
	{"dentistry location adjectives", {cat = "Dentistry"}},
	-- FIXME: Delete the following once we rename these categories to 'electromagnetic spectrum'
	{"electromagnetic radiation", {sort = false, cat = "Electromagnetic spectrum"}}, -- FIXME, add category
	{"electromagnetic spectrum", {sort = false}},
	-- FIXME: Delete the following once we rename these categories to 'terms for fingers'
	{"fingers", {sort = false, cat = "Terms for fingers"}},
	{"terms for fingers", {sort = false, cat = "Terms for fingers"}},
	{"fundamental interactions", {cat = "Physics"}},
	{"geological time units", {sort = false, cat = "Units of time,Geology"}},
	{"human anatomy location adjectives", {cat = "Medicine"}},
	{"Islamic prophets", {sort = false}},
	{"leptons", {sort = false, horiz = "bullet"}},
	{"antileptons", {sort = false, horiz = "bullet", cat = "Leptons"}},
	{"oceans", {horiz = "bullet"}},
	{"planets of the Solar System", {horiz = "bullet", sort = false}},
	{"quarks", {sort = false, horiz = "bullet"}},
	{"squarks", {sort = false, horiz = "bullet", cat = "Quarks"}},
	{"antiquarks", {sort = false, horiz = "bullet", cat = "Quarks"}},
	{"religions", {cat = "Religion"}}, -- FIXME, add and use category 'Religions'
	{"religious adherents", {cat = "Religion"}},
	{"religious texts", {cat = "Religion"}}, -- FIXME, add and use category 'Religious texts'
	{"seasons", {horiz = "bullet", sort = false}},
	{"sexual orientation adjectives", {cat = "Sexual orientations"}},
	{"taxonomic ranks", {sort = false}},
	{"times of day", {sort = false}},
	{"units of time", {sort = false}},
}

local function parse_topic_list_user_args(raw_user_args)
	local user_params = {
		nocat = {type = "boolean"},
		sortbase = {},
	}

	return require(parameters_module).process(raw_user_args, user_params)
end

local function add_topic_list_params(params)
	params["cat"] = {}
	params["enhypernym"] = {}
	params["hypernym"] = {}
	params["appendix"] = {}
	params["pagename"] = {} -- for testing of topic list
end

local function make_horiz_edit_button(topic_list_template)
	return tostring(html("small"):node(html("sup")
		:wikitext("&nbsp;&#91;[" .. mw.title.new(topic_list_template):fullUrl{action = "edit"} ..
			" edit]&#93;")
	))
end

local function analyze_template_name(topic_list_template)
	-- Analyze template name for list name and language. Note that there are templates with names like
	-- [[Template:list:days of the week/cim/Luserna]] (for the Luserna dialect of Cimbrian) and
	-- [[Template:list:days of the week/cim/13]] (for the Tredici Comuni dialect of Cimbrian) so we can't just
	-- assume there will be a single slash followed by a language code.
	local list_name_plus_lang = topic_list_template:gsub("^Template:", ""):gsub("^list:", "")
	local list_name, langcode_and_variant = list_name_plus_lang:match("^(.-)/(.*)$")
	local lang, variant
	if langcode_and_variant then
		local langcode
		langcode, variant = langcode_and_variant:match("^(.-)/(.*)$")
		langcode = langcode or langcode_and_variant
		lang = require(languages_module).getByCode(langcode, nil, "allow etym")
		if not lang then
			error(("Unrecognized language code '%s' in topic list template name [[%s]]"):format(
				langcode, topic_list_template))
		end
	else
		error(("Can't parse language code out of topic list template name [[%s]]; it should be of the form " ..
			"'Template:list:LISTNAME/LANGCODE' or 'Template:list:LISTNAME/LANGCODE/VARIETY'"):format(
			topic_list_template))
	end

	return list_name, lang, variant
end

-- FIXME: This needs to be implemented properly in [[Module:links]].
local function get_left_side_link(link)
	local left, right = link:match("^%[%[([^%[%]|]+)|([^%[%]|]+)%]%]$")
	if left then
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

local term_param_mods = require(parameter_utilities_module).construct_param_mods {
	{group = "link"}, -- sc has separate_no_index = true; that's the only one
	-- It makes no sense to have overall l=, ll=, q= or qq= params for columnar display.
	{group = {"ref", "l", "q"}, require_index = true},
}

local function parse_term_with_delimiters(data)
	local term, paramname, lang, sc, pagename = data.term, data.paramname, data.lang, data.sc, data.pagename
	local function generate_obj(term, parse_err)
		local actual_term, termlang = require(parse_interface_module).parse_term_with_lang {
			term = term,
			parse_err = parse_err,
			paramname = paramname,
		}
		return {
			term = actual_term ~= "" and actual_term or nil,
			lang = termlang or lang,
		}
	end
	local items = require(parse_interface_module).parse_inline_modifiers(term, {
		paramname = paramname,
		param_mods = term_param_mods,
		generate_obj = generate_obj,
		splitchar = "[,~]",
		preserve_splitchar = true,
		outer_container = {},
	})
	local item_is_page = false
	for i, item in ipairs(items.terms) do
		if i == 1 then
			item.separator = nil
		elseif item.delimiter == "~" then
			item.separator = data.tilde_delim or " ~ "
		else
			item.separator = data.comma_delim or ", "
		end
		-- Do this afterwards rather than in generate_obj() or use of <sc:...> will trigger an error
		-- because the modifier is already set.
		if not item.sc and sc then
			item.sc = sc
		end
		if data.notr then
			item.tr = "-"
		end
		if item.term and pagename then
			local left_side = get_left_side_link(item.term)
			if left_side and left_side == pagename then
				item_is_page = true
			end
		end
	end
	return items, item_is_page
end

local function get_title_and_formatted_cats(args, lang, sc, topic_list_data)
	local title = args.title
	local formatted_cats
	local cats
	local default_title = topic_list_data.list_name
	local user_args = topic_list_data.user_args
	local fulllangcode = lang:getFullCode()
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
	local hypernym_is_page
	if not title then
		local titleparts = {}
		local function ins(txt)
			table.insert(titleparts, txt)
		end
		local enhypernym
		if args.enhypernym then
			enhypernym = args.enhypernym:gsub("%+", m_str_utils.replacement_escape(default_title))
		else
			enhypernym = default_title
			if topic_list_data.variant then
				enhypernym = ("%s (%s)"):format(enhypernym, topic_list_data.variant)
			end
		end
		if cats and not enhypernym:find("%[%[") then
			ins(("[[:Category:%s|%s]]"):format(cats[1], enhypernym))
		else
			ins(enhypernym)
		end
		if args.hypernym then
			local lang_hypernyms
			local pagename = args.pagename or mw.loadData("Module:headword/data").pagename
			lang_hypernyms, hypernym_is_page = parse_term_with_delimiters {
				term = args.hypernym,
				paramname = "hypernym",
				lang = lang,
				sc = sc,
				pagename = pagename,
				-- Don't set notr= here; we still want to transliterate the hypernym if given
			}
			local formatted_hypernyms = require(columns_module).format_item(lang_hypernyms, {lang = lang}, "bold")
			ins(": " .. formatted_hypernyms)
		end
		if args.appendix then
			local appendices = require(parse_interface_module).split_on_comma(args.appendix)
			for i, appendix in ipairs(appendices) do
				if not appendix:find("%[%[") then
					appendices[i] = ("[[%s|appendix]]"):format(appendix)
				end
			end
			ins((" (<small>%s</small>)"):format(table.concat(appendices, ", ")))
		end
		title = table.concat(titleparts)
	end

	if not args.horiz and not topic_list_data.suppress_edit_button then
		-- append edit button to title
		local edit_link = html("span")
			:addClass("plainlinks list-switcher-edit")
			:wikitext("[" .. mw.title.new(topic_list_data.topic_list_template):fullUrl{action = "edit"} .. " edit]")
		title = title .. tostring(edit_link)
	end

	if cats and not user_args.nocat and not hypernym_is_page then
		formatted_cats = require(utilities_module).format_categories(cats, lang, nil, user_args.sortbase, force_cat)
	end
	return title, formatted_cats
end

--[==[
This implements topic lists. A given topic list template must directly invoke this function rather than
going through a wrapping template. A sample template implementation (e.g. for {{tl|list:continents/sw}}) is
{
{{#invoke:topic list|show|sw
|hypernym=[[bara|mabara]]
|Afrika<t:Africa>
|Antaktika~Antaktiki<t:Antarctica>
|Asia<t:Asia>
|Ulaya,Uropa<t:Europe>
|Amerika ya Kaskazini<t:North America>
|Amerika ya Kusini<t:South America>
|Australia<t:Australia>
}}
}

The syntax of the params is largely the same as for {{tl|col}}, but the following additional params supported:
* {{para|cat}}: Comma-separated list of categories to add the page to. The categories should specify bare topic
  categories without the preceding language code, e.g. `Islamic calendar months` for a category
  `LANGCODE:Islamic calendar months`. If you need to specify a different type of category, prefix the full category name
  with `Category:`. There must not be any spaces after the comma delimiter for it to be recognized as such. By default,
  the category comes from the template name, minus the initial `list:` and anything starting with a slash, and with the
  first letter capitalized; but only if the top-level language-agnostic category exists. Hence a template like
  {{tl|list:prefectures of Japan/ja}} will automatically categorize into [[:Category:ja:Prefectures of Japan]] (and
  likewise {{tl|list:prefectures of Japan/sq}} will still categorize into [[:Category:sq:Prefectures of Japan]] whether
  or not it exists, because the top-level [[:Category:Prefectures of Japan]] exists), but a template like
  {{tl|list:human anatomy direction adjectives/en}} will not categorize anywhere by default because there is no
  top-level [[:Category:Human anatomy direction adjectives]]. Use {{para|cat|-}} to disable categorization. Note that no
  categorization takes place if {{para|nocat|1}} is specified in the invocation of the list template or if the page is
  the same as any of the pages linked to by the language-specific hypernym(s) given in {{para|hypernym}}.
* {{para|hypernym}}: The language-specific plural form of the hypernym category (e.g. in the above example, the word for
  "continents" in Swahili). Generally this should be linked to the corresponding singular, if they are different. If
  specified, it is displayed after the English hypernym, following a colon. This parameter can be omitted to not display
  a hypernym, and you can also specify multiple comma-separated or tilde-separated hypernyms with inline modifiers
  attached to each one (essentially, following the format of a given item in {{tl|col}}).
* {{para|enhypernym}}: The English-language hypernym, e.g. `continents` in the above example. If omitted, this is
  derived from the template name by chopping off the initial `list:` and anything starting with a slash. This will be
  hyperlinked to the first category that the page categorizes into, if such a category exists.
* {{para|appendix}}: One or more comma-separated appendices to display after the hypernym, in parens. The appendix
  should be a full pagename including the namespace `Appendix:`, or a two-part link giving a pagename and display form.
  If a link is not specified, the display form will be `appendix`.
* {{para|pagename}}: Override the pagename, which should normally be a template of the form
  `Template:list:<var>list name</var>/<var>langcode</var>` or
  `Template:list:<var>list name</var>/<var>langcode</var>/<var>variant</var>`. The list name and language code are
  parsed out of the pagename and used as the default title and language, and various other defaults are set based on the
  list name.
]==]
function export.show(frame)
	local raw_item_args = frame.args
	local frame_parent = frame:getParent()
	local raw_user_args = frame_parent.args
	local topic_list_template = raw_item_args.pagename or frame_parent:getTitle()

	local user_args = parse_topic_list_user_args(raw_user_args)

	local list_name, lang, variant = analyze_template_name(topic_list_template)

	local default_props
	for _, pattern_and_props in ipairs(topic_list_properties) do
		local pattern, props = unpack(pattern_and_props)
		if rfind(list_name, "^" .. pattern .. "$") then
			default_props = props
			break
		end
	end
	if default_props then
		-- Make sure to make a copy of the default props as it will be overwritten with user-specified arguments in
		-- [[Module:columns]].
		local default_props_copy = {}
		for k, v in pairs(default_props) do
			if type(v) == "function" then
				default_props_copy[k] = v {
					topic_list_template = topic_list_template,
					list_name = list_name,
					lang = lang,
					variant = variant,
				}
			else
				default_props_copy[k] = v
			end
		end
		default_props = default_props_copy
	end

	return require(columns_module).handle_display_from_or_topic_list(
		{minrows = 2, sort = true, collapse = true, lang = lang}, raw_item_args, {
			topic_list_template = topic_list_template,
			list_name = list_name,
			variant = variant,
			default_props = default_props,
			get_title_and_formatted_cats = get_title_and_formatted_cats,
			add_topic_list_params = add_topic_list_params,
			make_horiz_edit_button = make_horiz_edit_button,
			user_args = user_args,
		}
	)
end

function export.compass(frame)
	local raw_item_args = frame.args
	local frame_parent = frame:getParent()
	local raw_user_args = frame_parent.args
	local topic_list_template = raw_item_args.pagename or frame_parent:getTitle()

	local user_args = parse_topic_list_user_args(raw_user_args)

	local list_name, lang, variant = analyze_template_name(topic_list_template)

	local params = {
		["lang"] = {type = "language"},
		["sc"] = {type = "script"},
		["notr"] = boolean,
		["title"] = {},

		["n"] = {},
		["s"] = {},
		["e"] = {},
		["w"] = {},
		["ne"] = {},
		["nw"] = {},
		["se"] = {},
		["sw"] = {},
	}
	add_topic_list_params(params)

	local args = require(parameters_module).process(raw_item_args, params)

	local title, formatted_cats = get_title_and_formatted_cats(args, lang, sc, {
		topic_list_template = topic_list_template,
		list_name = list_name,
		variant = variant,
		user_args = user_args,
		suppress_edit_button = true,
	})

	local m_columns = require(columns_module)

	local function parse_and_format_direction(paramname)
		if not args[paramname] then
			return ""
		end
		local terms = parse_term_with_delimiters {
			term = args[paramname],
			paramname = paramname,
			lang = lang,
			sc = sc,
			comma_delim = "<br />",
			notr = args.notr,
		}
		return m_columns.format_item(terms, {lang = lang})
	end

	local parts = {}
	local function ins(txt)
		table.insert(parts, txt)
	end
	ins(m_columns.construct_old_style_header(title, "horiz"))
	ins(make_horiz_edit_button(topic_list_template))
	ins("\n")
	ins('{| frame=void border=0 rules=none style="background:var(--wikt-palette-paleblue, #f9f9f9);"')
	ins('\n| style="text-align: left"   | ')
	ins(parse_and_format_direction("nw"))
	ins('\n| style="text-align: center" | ')
	ins(parse_and_format_direction("n"))
	ins('\n| style="text-align: right"  | ')
	ins(parse_and_format_direction("ne"))
	ins("\n|-")
	ins('\n| style="text-align: left"   | ')
	ins(parse_and_format_direction("w"))
	ins("\n| [[File:Compass rose simple plain.svg|upright=0.31]] ")
	ins('\n| style="text-align: right"  | ')
	ins(parse_and_format_direction("e"))
	ins("\n|-")
	ins('\n| style="text-align: left"   | ')
	ins(parse_and_format_direction("sw"))
	ins('\n| style="text-align: center" | ')
	ins(parse_and_format_direction("s"))
	ins('\n| style="text-align: right"  | ')
	ins(parse_and_format_direction("se"))
	ins("\n|}")
	return table.concat(parts)
end

return export
