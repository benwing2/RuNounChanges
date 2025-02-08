local export = {}

export.force_cat = false -- for testing; set to true to display categories even on non-mainspace pages

local debug_track_module = "Module:debug/track"
local form_of_cats_module = "Module:form of/cats"
local form_of_data_module = "Module:form of/data"
local form_of_data1_module = "Module:form of/data/1"
local form_of_data2_module = "Module:form of/data/2"
local form_of_functions_module = "Module:form of/functions"
local form_of_lang_data_module_prefix = "Module:form of/lang-data/"
local form_of_pos_module = "Module:form of/pos"
local function_module = "Module:fun"
local headword_data_module = "Module:headword/data"
local json_module = "Module:JSON"
local labels_module = "Module:labels"
local links_module = "Module:links"
local load_module = "Module:load"
local parse_utilities_module = "Module:parse utilities"
local string_utilities_module = "Module:string utilities"
local table_module = "Module:table"
local utilities_module = "Module:utilities"

local anchor_encode = mw.uri.anchorEncode
local concat = table.concat
local dump = mw.dumpObject
local fetch_categories_and_labels -- Defined below.
local format_form_of -- Defined below.
local get_tag_display_form -- Defined below.
local get_tag_set_display_form -- Defined below.
local insert = table.insert
local ipairs = ipairs
local is_link_or_html -- Defined below.
local list_to_text = mw.text.listToText
local lookup_shortcut -- Defined below.
local lookup_tag -- Defined below.
local normalize_tag_set -- Defined below.
local parse_tag_set_properties -- Defined below.
local require = require
local sort = table.sort
local split_tag_set -- Defined below.
local tagged_inflections -- Defined below.
local type = type

--[==[
Loaders for functions in other modules, which overwrite themselves with the target function when called. This ensures modules are only loaded when needed, retains the speed/convenience of locally-declared pre-loaded functions, and has no overhead after the first call, since the target functions are called directly in any subsequent calls.]==]
local function append(...)
	append = require(table_module).append
	return append(...)
end

local function contains(...)
	contains = require(table_module).contains
	return contains(...)
end

local function debug_track(...)
	debug_track = require(debug_track_module)
	return debug_track(...)
end

local function deep_copy(...)
	deep_copy = require(table_module).deepCopy
	return deep_copy(...)
end

local function deep_equals(...)
	deep_equals = require(table_module).deepEquals
	return deep_equals(...)
end

local function extend(...)
	extend = require(table_module).extend
	return extend(...)
end

local function format_categories(...)
	format_categories = require(utilities_module).format_categories
	return format_categories(...)
end

local function full_link(...)
	full_link = require(links_module).full_link
	return full_link(...)
end

local function insert_if_not(...)
	insert_if_not = require(table_module).insertIfNot
	return insert_if_not(...)
end

local function is_subset_list(...)
	is_subset_list = require(table_module).isSubsetList
	return is_subset_list(...)
end

local function iterate_from(...)
	iterate_from = require(function_module).iterateFrom
	return iterate_from(...)
end

local function join_multiparts(...)
	join_multiparts = require(form_of_functions_module).join_multiparts
	return join_multiparts(...)
end

local function load_data(...)
	load_data = require(load_module).load_data
	return load_data(...)
end

local function parse_inline_modifiers(...)
	parse_inline_modifiers = require(parse_utilities_module).parse_inline_modifiers
	return parse_inline_modifiers(...)
end

local function safe_load_data(...)
	safe_load_data = require(load_module).safe_load_data
	return safe_load_data(...)
end

local function safe_require(...)
	safe_require = require(load_module).safe_require
	return safe_require(...)
end

local function serial_comma_join(...)
	serial_comma_join = require(table_module).serialCommaJoin
	return serial_comma_join(...)
end

local function shallow_copy(...)
	shallow_copy = require(table_module).shallowCopy
	return shallow_copy(...)
end

local function show_labels(...)
	show_labels = require(labels_module).show_labels
	return show_labels(...)
end

local function slice(...)
	slice = require(table_module).slice
	return slice(...)
end

local function split(...)
	split = require(string_utilities_module).split
	return split(...)
end

local function ucfirst(...)
	ucfirst = require(string_utilities_module).ucfirst
	return ucfirst(...)
end

--[==[
Loaders for objects, which load data (or some other object) into some variable, which can then be accessed as "foo or get_foo()", where the function get_foo sets the object to "foo" and then returns it. This ensures they are only loaded when needed, and avoids the need to check for the existence of the object each time, since once "foo" has been set, "get_foo" will not be called again.]==]
local cat_functions
local function get_cat_functions()
	cat_functions, get_cat_functions = require(form_of_functions_module).cat_functions, nil
	return cat_functions
end

local default_pagename
local function get_default_pagename()
	default_pagename, get_default_pagename = load_data(headword_data_module).pagename, nil
	return default_pagename
end

local display_handlers
local function get_display_handlers()
	display_handlers, get_display_handlers = require(form_of_functions_module).display_handlers, nil
	return display_handlers
end

local m_cats_data
local function get_m_cats_data()
	m_cats_data, get_m_cats_data = load_data(form_of_cats_module), nil
	return m_cats_data
end

local m_data
local function get_m_data()
	-- Needs require.
	m_data, get_m_data = require(form_of_data_module), nil
	return m_data
end

local m_data1
local function get_m_data1()
	m_data1, get_m_data1 = load_data(form_of_data1_module), nil
	return m_data1
end

local m_data2
local function get_m_data2()
	m_data2, get_m_data2 = load_data(form_of_data2_module), nil
	return m_data2
end

local m_pos_data
local function get_m_pos_data()
	m_pos_data, get_m_pos_data = load_data(form_of_pos_module), nil
	return m_pos_data
end

--[==[ intro:

This module implements the underlying processing of {{tl|form of}}, {{tl|inflection of}} and specific variants such as
{{tl|past participle of}} and {{tl|alternative spelling of}}. Most of the logic in this file is to handle tags in
{{tl|inflection of}}. Other related files:

* [[Module:form of/templates]] contains the majority of the logic that implements the templates themselves.
* [[Module:form of/data/1]] is a data-only file containing information on the more common inflection tags, listing the
  tags, their shortcuts, the category they belong to (tense-aspect, case, gender, voice-valence, etc.), the appropriate
  glossary link and the wikidata ID.
* [[Module:form of/data/2]] is a data-only file containing information on the less common inflection tags, in the same
  format as [[Module:form of/data/1]].
* [[Module:form of/lang-data/LANGCODE]] is a data-only file containing information on the language-specific inflection
  tags for the language with code LANGCODE, in the same format as [[Module:form of/data/1]]. Language-specific tags
  override general tags.
* [[Module:form of/cats]] is a data-only file listing the language-specific categories that are added when the
  appropriate combinations of tags are seen for a given language.
* [[Module:form of/pos]] is a data-only file listing the recognized parts of speech and their abbreviations, used for
  categorization. FIXME: This should be unified with the parts of speech listed in [[Module:links]].
* [[Module:form of/functions]] contains functions for use with [[Module:form of/data/1]] and [[Module:form of/cats]].
  They are contained in this module because data-only modules can't contain code. The functions in this file are of two
  types:
*# Display handlers allow for customization of the display of multipart tags (see below). Currently there is only
   one such handler, for handling multipart person tags such as `1//2//3`.
*# Cat functions allow for more complex categorization logic, and are referred to by name in [[Module:form of/cats]].
   Currently no such functions exist.

The following terminology is used in conjunction with {{tl|inflection of}}:

* A ''tag'' is a single grammatical item, as specified in a single numbered parameter of {{tl|inflection of}}. Examples
  are `masculine`, `nominative`, or `first-person`. Tags may be abbreviated, e.g. `m` for `masculine`, `nom` for
  `nominative`, or `1` for `first-person`. Such abbreviations are called ''aliases'', and some tags have multiple
  equivalent aliases (e.g. `p` or `pl` for `plural`). The full, non-abbreviated form of a tag is called its
  ''canonical form''.
* The ''display form'' of a tag is the way it's displayed to the user. Usually the displayed text of the tag is the same
  as its canonical form, and it normally functions as a link to a glossary entry explaining the tag. Usually the link is
  to an entry in [[Appendix:Glossary]], but sometimes the tag is linked to an individual dictionary entry or to a
  Wikipedia entry. Occasionally, the display text differs from the canonical form of the tag. An example is the tag
  `comparative case`, which has the display text read as simply `comparative`. Normally, tags referring to cases don't
  have the word "case" in them, but in this case the tag `comparative` was already used as an alias for the tag
  `comparative degree`, so the tag was named `comparative case` to avoid clashing. A similar situation occurs with
  `adverbial case` vs. the grammar tag `adverbial` (as in `adverbial participle`).
* A ''tag set'' is an ordered list of tags, which together express a single inflection, for example, `1|s|pres|ind`,
  which can be expanded to canonical-form tags as `first-person|singular|present|indicative`.
* A ''conjoined tag set'' is a tag set that consists of multiple individual tag sets separated by a semicolon, e.g.
  `1|s|pres|ind|;|2|s|imp`, which specifies two tag sets, `1|s|pres|ind` as above and `2|s|imp` (in canonical form,
  `second-person|singular|imperative`). Multiple tag sets specified in a single call to {{tl|inflection of}} are
  specified in this fashion. Conjoined tag sets can also occur in list-tag shortcuts.
* A ''multipart tag'' is a tag that embeds multiple tags within it, such as `f//n` or `nom//acc//voc`. These are used in
  the case of [[syncretism]], when the same form applies to multiple inflections. Examples are the Spanish present
  subjunctive, where the first-person and third-person singular have the same form (e.g. {{m|es|siga}} from
  {{m|es|seguir|t=to follow}}), or Latin third-declension adjectives, where the dative and ablative plural of all
  genders have the same form (e.g. {{m|la|omnibus}} from {{m|la|omnis|t=all}}). These would be expressed respectively as
  `1//3|s|pres|sub` and `dat//abl|m//f//n|p`, where the use of the multipart tag compactly encodes the syncretism and
  avoids the need to individually list out all of the inflections. Multipart tags currently display as a list separated
  by a slash, e.g.  ''dative/ablative'' or ''masculine/feminine/neuter'' where each individual word is linked
  appropriately. As a special case, multipart tags involving persons display specially; for example, the multipart tag
  `1//2//3` displays as ''first-, second- and third-person'', with the word "person" occurring only once.
* A ''two-level multipart tag'' is a special type of multipart tag that joins two or more tag sets instead of joining
  individual tags. The tags within the tag set are joined by a colon, e.g. `1:s//3:p`, which is displayed as
  ''first-person singular and third-person plural'', e.g. for use with the form {{m|grc|μέλλον}} of the verb
  {{m|grc|μέλλω|t=to intend}}, which uses the tag set `1:s//3:p|impf|actv|indc|unaugmented` to express the syncretism
  between the first singular and third plural forms of the imperfect active indicative unaugmented conjugation.
  Two-level multipart tags should be used sparingly; if in doubt, list out the inflections separately. [FIXME: Make
  two-level multipart tags obsolete.]
* A ''shortcut'' is a tag that expands to any type of tag described above, or to any type of tag set described above.
  Aliases are a particular type of shortcut whose expansion is a single non-multipart tag.
* A ''multipart shortcut'' is a shortcut that expands into a multipart tag, for example `123`, which expands to the
  multipart tag `1//2//3`. Only the most common such combinations exist as shortcuts.
* A ''list shortcut'' is a special type of shortcut that expands to a list of tags instead of a single tag. For example,
  the shortcut `1s` expands to `1|s` (first-person singular). Only the most common such combinations exist as shortcuts.
* A ''conjoined shortcut'' is a special type of list shortcut that consists of a conjoined tag set (multiple logical tag
  sets). For example, the English language-specific shortcut `ed-form` expands to `spast|;|past|part`, expressing the
  common syncretism between simple past and past participle in English (and in this case, `spast` is itself a list
  shortcut that expands to `simple|past`).]==]

-- Add tracking category for PAGE when called from {{inflection of}} or
-- similar TEMPLATE. The tracking category linked to is
-- [[Wiktionary:Tracking/inflection of/PAGE]].
local function track(page)
	debug_track("inflection of/" ..
		-- avoid including links in pages (may cause error)
		page:gsub("%[", "("):gsub("%]", ")"):gsub("|", "!")
	)
end

local function wrap_in_span(text, classes)
	return ("<span class='%s'>%s</span>"):format(classes, text)
end

--[==[
Lowest-level implementation of form-of templates, including the general {{tl|form of}} as well as those that deal with
inflection tags, such as the general {{tl|inflection of}}, semi-specific variants such as {{tl|participle of}}, and
specific variants such as {{tl|past participle of}}. `data` contains all the information controlling the display, with
the following fields:

* `.text`: Text to insert before the lemmas. Wrapped in the value of `.text_classes`, or its default; see below.
* `.lemmas`: List of objects describing the lemma(s) of which the term in question is a non-lemma form. These are passed
   directly to {full_link()} in [[Module:links]]. Each object should have at minimum a `.lang` field containing the
   language of the lemma and a `.term` field containing the lemma itself. Each object is formatted using {full_link()}
   and then if there are more than one, they are joined using {serialCommaJoin()} in [[Module:table]]. Alternatively,
   `.lemmas` can be a string, which is displayed directly, or omitted, to show no lemma links and omit the connecting
   text.
* `.lemma_face`: "Face" to use when displaying the lemma objects. Usually should be set to {"term"}.
* `.enclitics`: List of enclitics to display after the lemmas, in parens.
* `.base_lemmas`: List of base lemmas to display after the lemmas, in the case where the lemmas in `.lemmas` are
   themselves forms of another lemma (the base lemma), e.g. a comparative, superlative or participle. Each object is of
   the form { { paramobj = PARAM_OBJ, lemmas = {LEMMA_OBJ, LEMMA_OBJ, ...} }} where PARAM_OBJ describes the properties
   of the base lemma parameter (i.e. the relationship between the intermediate and base lemmas) and LEMMA_OBJ is an
   object suitable to be passed to {full_link()} in [[Module:links]]. PARAM_OBJ is of the format
   { { param = "PARAM", tags = {"TAG", "TAG", ...} } where PARAM is the name of the parameter to {{tl|inflection of}}
   etc. that holds the base lemma(s) of the specified relationship and the tags describe the relationship, such as
   { {"comd"}} or { {"past", "part"}}.
* `.text_classes`: CSS classes used to wrap the tag text and lemma links. Default is {"form-of-definition use-with-mention"}
   for the tag text and lemma links, and additionally {"form-of-definition-link"} specifically for the lemma links.
   (FIXME: Should separate out the lemma links into their own field.)
* `.posttext`: Additional text to display after the lemma links.]==]
function export.format_form_of(data)
	if type(data) ~= "table" then
		error("Internal error: First argument must now be a table of arguments")
	end
	local text_classes = data.text_classes or "form-of-definition use-with-mention"
	local lemma_classes = data.text_classes or "form-of-definition-link"
	local parts = {}
	insert(parts, "<span class='" .. text_classes .. "'>")
	insert(parts, data.text)
	if data.text ~= "" and data.lemmas then
		insert(parts, " ")
	end
	if data.lemmas then
		if type(data.lemmas) == "string" then
			insert(parts, wrap_in_span(data.lemmas, lemma_classes))
		else
			local formatted_terms = {}
			for _, lemma in ipairs(data.lemmas) do
				insert(formatted_terms, wrap_in_span(
					full_link(lemma, data.lemma_face, nil, "show qualifiers"), lemma_classes
				))
			end
			insert(parts, serial_comma_join(formatted_terms))
		end
	end
	if data.enclitics and #data.enclitics > 0 then
		-- The outer parens need to be outside of the text_classes span so they show in upright instead of italic, or
		-- they will clash with upright parens generated by link annotations such as transliterations and pos=.
		insert(parts, "</span>")
		local formatted_terms = {}
		for _, enclitic in ipairs(data.enclitics) do
			-- FIXME, should we have separate clitic face and/or classes?
			insert(formatted_terms, wrap_in_span(
				full_link(enclitic, data.lemma_face, nil, "show qualifiers"), lemma_classes
			))
		end
		insert(parts, " (")
		insert(parts, wrap_in_span("with enclitic" .. (#data.enclitics > 1 and "s" or "") .. " ", text_classes))
		insert(parts, serial_comma_join(formatted_terms))
		insert(parts, ")")
		insert(parts, "<span class='" .. text_classes .. "'>")
	end
	if data.base_lemmas and #data.base_lemmas > 0 then
		for _, base_lemma in ipairs(data.base_lemmas) do
			insert(parts, ", the </span>")
			insert(parts, (tagged_inflections{
				lang = base_lemma.lemmas[1].lang,
				tags = base_lemma.paramobj.tags,
				lemmas = base_lemma.lemmas,
				lemma_face = data.lemma_face,
				no_format_categories = true,
				nocat = true,
				text_classes = data.text_classes,
			}))
			insert(parts, "<span class='" .. text_classes .. "'>")
		end
	end
	-- FIXME, should posttext go before enclitics? If so we need to have separate handling for the
	-- final colon when there are multiple tag sets in tagged_inflections().
	if data.posttext then
		insert(parts, data.posttext)
	end
	insert(parts, "</span>")
	return concat(parts)
end
format_form_of = export.format_form_of

--[==[
Return true if `tag` contains an internal link or HTML.]==]
function export.is_link_or_html(tag)
	return tag:find("[[", nil, true) or tag:find("|", nil, true) or tag:find("<", nil, true)
end
is_link_or_html = export.is_link_or_html

--[==[
Look up a tag (either a shortcut of any sort of a canonical long-form tag) and return its expansion. The expansion
will be a string unless the shortcut is a list-tag shortcut such as `1s`; in that case, the expansion will be a
list. The caller must handle both cases. Only one level of expansion happens; hence, `acc` expands to {"accusative"},
`1s` expands to { {"1", "s"}} (not to { {"first", "singular"}}) and `123` expands to {"1//2//3"}. The expansion will be
the same as the passed-in tag in the following circumstances:

# The tag is `;` (this is special-cased, and no lookup is done).
# The tag is a multipart tag such as `nom//acc` (this is special-cased, and no lookup is done).
# The tag contains a raw link (this is special-cased, and no lookup is done).
# The tag contains HTML (this is special-cased, and no lookup is done).
# The tag is already a canonical long-form tag.
# The tag is unrecognized.

This function first looks up in the lang-specific data module [[Module:form of/lang-data/LANGCODE]], then in
[[Module:form of/data/1]] (which includes more common non-lang-specific tags) and finally (only if the tag is not
recognized as a shortcut or canonical tag, and is not of types 1-4 above) in [[Module:form of/data/2]].

If the expansion is a string and is different from the tag, track it if `do_track` is true.]==]
function export.lookup_shortcut(tag, lang, do_track)
	-- If there is HTML or a link in the tag, return it directly; don't try
	-- to look it up, which will fail.
	if tag == ";" or tag:find("//", nil, true) or is_link_or_html(tag) then
		return tag
	end
	local expansion
	while lang do
		local langdata = safe_load_data(form_of_lang_data_module_prefix .. lang:getCode())
		-- If this is a canonical long-form tag, just return it, and don't check for shortcuts. This is an
		-- optimization; see below.
		if langdata then
			if langdata.tags[tag] then
				return tag
			end
			expansion = langdata.shortcuts[tag]
			if expansion then
				break
			end
		end
		-- If the language has a parent (i.e. a superordinate variety), try again with that.
		lang = lang:getParent()
	end
	if not expansion then
		-- If this is a canonical long-form tag, just return it, and don't check for shortcuts (which will cause
		-- [[Module:form of/data/2]] to be loaded, because there won't be a shortcut entry in [[Module:form of/data/1]] --
		-- or, for that matter, in [[Module:form of/data/2]]). This is an optimization; the code will still work without
		-- it, but will use up more memory.
		if (m_data1 or get_m_data1()).tags[tag] then
			return tag
		end
		expansion = m_data1.shortcuts[tag]
	end
	if not expansion then
		expansion = (m_data2 or get_m_data2()).shortcuts[tag]
	end
	if not expansion then
		return tag
	end
	-- Maybe track the expansion if it's not the same as the raw tag.
	if do_track and expansion ~= tag and type(expansion) == "string" then
		track("tag/" .. tag)
	end
	return expansion
end
lookup_shortcut = export.lookup_shortcut

--[==[
Look up a normalized/canonicalized tag and return the data object associated with it. If the tag isn't found, return
nil. This first looks up in the lang-specific data module [[Module:form of/lang-data/LANGCODE]], then in
[[Module:form of/data/1]] (which includes more common non-lang-specific tags) and then finally in
[[Module:form of/data/2]].]==]
function export.lookup_tag(tag, lang)
	while lang do
		local langdata = safe_load_data(form_of_lang_data_module_prefix .. lang:getCode())
		local tag = langdata and langdata.tags[tag]
		if tag then
			return tag
		end
		-- If the language has a parent (i.e. a superordinate variety), try again with that.
		lang = lang:getParent()
	end
	local tagobj = (m_data1 or get_m_data1()).tags[tag]
	if tagobj then
		return tagobj
	end
	local tagobj2 = (m_data2 or get_m_data2()).tags[tag]
	if tagobj2 then
		return tagobj2
	end
	return nil
end
lookup_tag = export.lookup_tag

-- Normalize a single tag, which may be a shortcut but should not be a multipart tag, a multipart shortcut or a list
-- shortcut.
local function normalize_single_tag(tag, lang, do_track)
	local expansion = lookup_shortcut(tag, lang, do_track)
	if type(expansion) ~= "string" then
		error("Tag '" .. tag .. "' is a list shortcut, which is not allowed here")
	end
	tag = expansion
	if not lookup_tag(tag, lang) and do_track then
		-- If after all expansions and normalizations we don't recognize the canonical tag, track it.
		track("unknown")
		track("unknown/" .. tag)
	end
	return tag
end

--[=[
Normalize a component of a multipart tag. This should not have any // in it, but may join multiple individual tags with
a colon, and may be a single list-tag shortcut, which is treated as if colon-separated. The return value may be a list
of tags.
]=]
local function normalize_multipart_component(tag, lang, do_track)
	-- If there is HTML or a link in the tag, don't try to split on colon. A colon may legitimately occur in either one,
	-- and we don't want these things parsed. Note that we don't do this check before splitting on //, which we don't
	-- expect to occur in links or HTML; see comment in normalize_tag().
	if is_link_or_html(tag) then
		return tag
	end
	local components = split(tag, ":", true)
	if #components == 1 then
		-- We allow list-tag shortcuts inside of multipart tags, e.g.
		-- '1s//3p'. Check for this now.
		tag = lookup_shortcut(tag, lang, do_track)
		if type(tag) == "table" then
			-- Temporary tracking as we will disallow this.
			track("list-tag-inside-of-multipart")
			-- We found a list-tag shortcut; treat as if colon-separated.
			components = tag
		else
			return normalize_single_tag(tag, lang, do_track)
		end
	end
	local normtags = {}
	-- Temporary tracking as we will disallow this.
	track("two-level-multipart")
	for _, component in ipairs(components) do
		if do_track then
			-- There are multiple components; track each of the individual
			-- raw tags.
			track("tag/" .. component)
		end
		insert(normtags, normalize_single_tag(component, lang, do_track))
	end

	return normtags
end

--[=[
Normalize a single tag. The return value may be a list (in the case of multipart tags), which will contain nested lists
in the case of two-level multipart tags.
]=]
local function normalize_tag(tag, lang, do_track)
	-- We don't check for links or HTML before splitting on //, which we don't expect to occur in links or HTML. Doing
	-- it this way allows for a tag like '{{lb|grc|Epic}}//{{lb|grc|Ionic}}' to function correctly (the template calls
	-- will be expanded before we process the tag, and will contain links and HTML). The only check we do is for a URL,
	-- which shouldn't normally occur, but might if the user tries to put an external link into the tag. URL's with //
	-- normally have the sequence ://, which should never normally occur when // and : are used in their normal ways.
	if tag:find("://", nil, true) then
		return tag
	end
	local split_tags = split(tag, "//", true)
	if #split_tags == 1 then
		local retval = normalize_multipart_component(tag, lang, do_track)
		if type(retval) == "table" then
			-- The user gave a tag like '1:s', i.e. with colon but without //. Allow this, but we need to return a
			-- nested list.
			return {retval}
		end
		return retval
	end
	local normtags = {}
	for _, single_tag in ipairs(split_tags) do
		if do_track then
			-- If the tag was a multipart tag, track each of individual raw tags.
			track("tag/" .. single_tag)
		end
		insert(normtags, normalize_multipart_component(single_tag, lang, do_track))
	end
	return normtags
end

--[==[
Normalize a tag set (a list of tags) into its canonical-form tags. The return value is a list of normalized tag sets
(a list because of there may be conjoined shortcuts among the input tags). A normalized tag set is a list of tag
elements, where each element is either a string (the canonical form of a tag), a list of such strings (in the case of
multipart tags) or a list of lists of such strings (in the case of two-level multipart tags). For example, the multipart
tag `nom//acc//voc` will be represented in canonical form as { {"nominative", "accusative", "vocative"}}, and the
two-level multipart tag `1:s//3:p` will be represented as { {{"first-person", "singular"}, {"third-person", "plural"}}}.

Example 1:

{normalize_tag_set({"nom//acc//voc", "n", "p"})} = { {{{"nominative", "accusative", "vocative"}, "masculine", "plural"}}}

Example 2:

{normalize_tag_set({"ed-form"}, ENGLISH)} = { {{"simple", "past"}, {"past", "participle"}}}

Example 3:

{normalize_tag_set({"archaic", "ed-form"}, ENGLISH)} = { {{"archaic", "simple", "past"}, {"archaic", "past", "participle"}}}]==]
function export.normalize_tag_set(tag_set, lang, do_track)
	-- We track usage of shortcuts, normalized forms and (in the case of multipart tags or list tags) intermediate
	-- forms. For example, if the tags 1s|mn|gen|indefinite are passed in, we track the following:
	-- [[Wiktionary:Tracking/inflection of/tag/1s]]
	-- [[Wiktionary:Tracking/inflection of/tag/1]]
	-- [[Wiktionary:Tracking/inflection of/tag/s]]
	-- [[Wiktionary:Tracking/inflection of/tag/first-person]]
	-- [[Wiktionary:Tracking/inflection of/tag/singular]]
	-- [[Wiktionary:Tracking/inflection of/tag/mn]]
	-- [[Wiktionary:Tracking/inflection of/tag/m//n]]
	-- [[Wiktionary:Tracking/inflection of/tag/m]]
	-- [[Wiktionary:Tracking/inflection of/tag/n]]
	-- [[Wiktionary:Tracking/inflection of/tag/masculine]]
	-- [[Wiktionary:Tracking/inflection of/tag/neuter]]
	-- [[Wiktionary:Tracking/inflection of/tag/gen]]
	-- [[Wiktionary:Tracking/inflection of/tag/genitive]]
	-- [[Wiktionary:Tracking/inflection of/tag/indefinite]]
	local output_tag_set = {}
	local saw_semicolon = false

	for _, tag in ipairs(tag_set) do
		if do_track then
			-- Track the raw tag.
			track("tag/" .. tag)
		end
		-- Expand the tag, which may generate a new tag (either a fully canonicalized tag, a multipart tag, or a list
		-- of tags).
		tag = lookup_shortcut(tag, lang, do_track)
		if type(tag) == "table" then
			if contains(tag, ";") then
				-- If we saw a conjoined shortcut, we need to use a more general algorithm that can expand a single
				-- tag set into multiple.
				saw_semicolon = true
				break
			end

			for _, t in ipairs(tag) do
				if do_track then
					-- If the tag expands to a list of raw tags, track each of those.
					track("tag/" .. t)
				end
				insert(output_tag_set, normalize_tag(t, lang, do_track))
			end
		else
			insert(output_tag_set, normalize_tag(tag, lang, do_track))
		end
	end

	if not saw_semicolon then
		return {output_tag_set}
	end

	-- Use a more general algorithm that handles conjoined shortcuts.
	output_tag_set = {}
	for i, tag in ipairs(tag_set) do
		if do_track then
			-- Track the raw tag.
			track("tag/" .. tag)
		end
		-- Expand the tag, which may generate a new tag (either a fully canonicalized tag, a multipart tag, or a list
		-- of tags).
		tag = lookup_shortcut(tag, lang, do_track)
		if type(tag) == "table" then
			local output_tag_sets = {}
			local shortcut_tag_sets = split_tag_set(tag)
			local normalized_shortcut_tag_sets = {}
			for _, shortcut_tag_set in ipairs(shortcut_tag_sets) do
				extend(normalized_shortcut_tag_sets,
					normalize_tag_set(shortcut_tag_set, lang, do_track))
			end
			local after_tags = slice(tag_set, i + 1)
			local normalized_after_tags_sets = normalize_tag_set(after_tags, lang, do_track)
			for _, normalized_shortcut_tag_set in ipairs(normalized_shortcut_tag_sets) do
				for _, normalized_after_tags_set in ipairs(normalized_after_tags_sets) do
					insert(output_tag_sets, append(output_tag_set, normalized_shortcut_tag_set,
						normalized_after_tags_set))
				end
			end
			return output_tag_sets
		else
			insert(output_tag_set, normalize_tag(tag, lang, do_track))
		end
	end

	error("Internal error: Should not get here")
end
normalize_tag_set = export.normalize_tag_set

--[==[
Split a tag set that may consist of multiple semicolon-separated tag sets into the component tag sets.]==]
function export.split_tag_set(tag_set)
	local split_tag_sets = {}
	local cur_tag_set = {}
	for _, tag in ipairs(tag_set) do
		if tag == ";" then
			if #cur_tag_set > 0 then
				insert(split_tag_sets, cur_tag_set)
			end
			cur_tag_set = {}
		else
			insert(cur_tag_set, tag)
		end
	end
	if #cur_tag_set > 0 then
		insert(split_tag_sets, cur_tag_set)
	end
	return split_tag_sets
end
split_tag_set = export.split_tag_set

local tag_set_param_mods = {
	lb = {
		item_dest = "labels",
		convert = function(arg, parse_err)
			return split(arg, "//", true)
		end,
	}
}

--[==[
Parse tag set properties from a tag set (list of tags). Currently no per-tag properties are recognized, and the only
per-tag-set property recognized is `<lb:...>` for specifing label(s) for the tag set. Per-tag-set properties must be
attached to the last tag.]==]
function export.parse_tag_set_properties(tag_set)
	local function generate_tag_set_obj(last_tag)
		tag_set[#tag_set] = last_tag
		return {tags = tag_set}
	end
	local last_tag = tag_set[#tag_set]
	-- Check for inline modifier, e.g. מרים<tr:Miryem>. But exclude HTML entry with <span ...>, <i ...>, <br/> or
	-- similar in it, caused by wrapping an argument in {{l|...}}, {{af|...}} or similar. Basically, all tags of
	-- the sort we parse here should consist of a less-than sign, plus letters, plus a colon, e.g. <lb:...>, so if
	-- we see a tag on the outer level that isn't in this format, we don't try to parse it. The restriction to the
	-- outer level is to allow generated HTML inside of e.g. qualifier tags, such as foo<q:similar to {{m|fr|bar}}>.
	if last_tag:find("<", nil, true) and not last_tag:find("^[^<]*<%l*[^%l:]") then
		return parse_inline_modifiers(last_tag, {
			param_mods = tag_set_param_mods,
			generate_obj = generate_tag_set_obj,
		})
	else
		return generate_tag_set_obj(last_tag)
	end
end
parse_tag_set_properties = export.parse_tag_set_properties

local function normalize_pos(pos)
	if not pos then
		return nil
	end
	return (m_pos_data or get_m_pos_data())[pos] or pos
end

-- Return the display form of a single canonical-form tag. The value
-- passed in must be a string (i.e. it cannot be a list describing a
-- multipart tag). To handle multipart tags, use get_tag_display_form().
local function get_single_tag_display_form(normtag, lang)
	local data = lookup_tag(normtag, lang)
	local display = normtag

	-- If the tag has a special display form, use it
	if data and data.display then
		display = data.display
	end

	-- If there is a nonempty glossary index, then show a link to it
	local glossary = data and data[(m_data or get_m_data()).GLOSSARY]
	if glossary ~= nil then
		if glossary == m_data.WIKT then
			display = "[[" .. normtag .. "|" .. display .. "]]"
		elseif glossary == m_data.WP then
			display = "[[w:" .. normtag .. "|" .. display .. "]]"
		elseif glossary == m_data.APPENDIX then
			display = "[[Appendix:Glossary#" .. anchor_encode(normtag) .. "|" .. display .. "]]"
		elseif type(glossary) ~= "string" then
			error(("Internal error: Wrong type %s for glossary value %s for tag %s"):format(
				type(glossary), dump(glossary), normtag))
		else
			local link = glossary:match("^wikt:(.*)")
			if link then
				display = "[[" .. link .. "|" .. display .. "]]"
			end
			if not link then
				link = glossary:match("^w:(.*)")
				if link then
					display = "[[w:" .. link .. "|" .. display .. "]]"
				end
			end
			if not link then
				display = "[[Appendix:Glossary#" .. anchor_encode(glossary) .. "|" .. display .. "]]"
			end
		end
	end
	return display
end

--[==[
Turn a canonicalized tag spec (which describes a single, possibly multipart tag) into the displayed form. The tag spec
may be a string (a canonical-form tag); a list of canonical-form tags (in the case of a simple multipart tag); or a
list of mixed canonical-form tags and lists of such tags (in the case of a two-level multipart tag). `joiner` indicates
how to join the parts of a multipart tag, and can be either {"and"} ("foo and bar", or "foo, bar and baz" for 3 or
more), {"slash"} ("foo/bar"), {"en-dash"} ("foo–bar") or {nil}, which uses the global default found in
{multipart_join_strategy()} in [[Module:form of/functions]]. (NOTE: The global default is {"slash"} and this seems
unlikely to change.)]==]
function export.get_tag_display_form(tagspec, lang, joiner)
	if type(tagspec) == "string" then
		return get_single_tag_display_form(tagspec, lang)
	end
	-- We have a multipart tag. See if there's a display handler to display them specially.
	for _, handler in ipairs(display_handlers or get_display_handlers()) do
		local displayval = handler(tagspec, joiner)
		if displayval then
			return displayval
		end
	end
	-- No display handler.
	local displayed_tags = {}
	for _, first_level_tag in ipairs(tagspec) do
		if type(first_level_tag) == "string" then
			insert(displayed_tags, get_single_tag_display_form(first_level_tag, lang))
		else
			-- A first-level element of a two-level multipart tag. Currently we just separate the individual components
			-- with spaces, but other ways are possible, e.g. using an underscore, colon, parens or braces.
			local components = {}
			for _, component in ipairs(first_level_tag) do
				insert(components, get_single_tag_display_form(component, lang))
			end
			insert(displayed_tags, concat(components, " "))
		end
	end
	return join_multiparts(displayed_tags, joiner)
end
get_tag_display_form = export.get_tag_display_form

--[==[
Given a normalized tag set (i.e. as output by {normalize_tag_set()}; all tags are in canonical form, multipart tags are
represented as lists, and two-level multipart tags as lists of lists), convert to displayed form (a string). See
{get_tag_display_form()} for the meaning of `joiner`.]==]
function export.get_tag_set_display_form(normalized_tag_set, lang, joiner)
	local parts = {}

	for _, tagspec in ipairs(normalized_tag_set) do
		local to_insert = get_tag_display_form(tagspec, lang, joiner)
		-- Maybe insert a space before inserting the display form of the tag. We insert a space if
		-- (a) we're not the first tag; and
		-- (b) the tag we're about to insert doesn't have the "no_space_on_left" property; and
		-- (c) the preceding tag doesn't have the "no_space_on_right" property.
		-- NOTE: We depend here on the fact that
		-- (1) all tags with either of the above properties set have the same display form as canonical form, and
		-- (2) all tags with either of the above properties set are single-character tags.
		-- The second property is an optimization to avoid looking up display forms resulting from multipart tags,
		-- which won't be found and which will trigger loading of [[Module:form of/data/2]]. If multichar punctuation is
		-- added in the future, it's ok to change the == 1 below to <= 2 or <= 3.
		--
		-- If the first property above fails to hold in the future, we need to track the canonical form of each tag
		-- (including the previous one) as well as the display form. This would also avoid the need for the == 1 check.
		if #parts > 0 then
			local most_recent_tagobj = parts[#parts]:match("^.[\128-\191]*$") and lookup_tag(parts[#parts], lang)
			local to_insert_tagobj = to_insert:match("^.[\128-\191]*$") and lookup_tag(to_insert, lang)
			if (
				(not most_recent_tagobj or not most_recent_tagobj.no_space_on_right) and
				(not to_insert_tagobj or not to_insert_tagobj.no_space_on_left)
			) then
				insert(parts, " ")
			end
		end
		insert(parts, to_insert)
	end

	return concat(parts)
end
get_tag_set_display_form = export.get_tag_set_display_form

--[==[
Split a tag set containing two-level multipart tags into one or more tag sets not containing such tags.
Single-level multipart tags are left alone. (If we need to, a slight modification of the following code
will also split single-level multipart tags.) This assumes that multipart tags are represented as lists
and two-level multipart tags are represented as lists of lists, as is output by {normalize_tag_set()}.
NOTE: We have to be careful to properly handle imbalanced two-level multipart tags such as
`def:s//p` (or the reverse, `s//def:p`).]==]
local function split_two_level_multipart_tag_set(tag_set)
	for i, tag in ipairs(tag_set) do
		if type(tag) == "table" then
			-- We saw a multipart tag. Check if any of the parts are two-level.
			local saw_two_level_tag = false
			for _, first_level_tag in ipairs(tag) do
				if type(first_level_tag) == "table" then
					saw_two_level_tag = true
					break
				end
			end
			if saw_two_level_tag then
				-- We found a two-level multipart tag.
				-- (1) Extract the preceding tags.
				local pre_tags = slice(tag_set, 1, i - 1)
				-- (2) Extract the following tags.
				local post_tags = slice(tag_set, i + 1)
				-- (3) Loop over each tag set alternant in the two-level multipart tag.
				-- For each alternant, form the tag set consisting of pre_tags + alternant + post_tags,
				-- and recursively split that tag set.
				local resulting_tag_sets = {}
				for _, first_level_tag_set in ipairs(tag) do
					local expanded_tag_set = {}
					extend(expanded_tag_set, pre_tags)
					-- The second level may have a string or a list.
					if type(first_level_tag_set) == "table" then
						extend(expanded_tag_set, first_level_tag_set)
					else
						insert(expanded_tag_set, first_level_tag_set)
					end
					extend(expanded_tag_set, post_tags)
					extend(resulting_tag_sets, split_two_level_multipart_tag_set(expanded_tag_set))
				end
				return resulting_tag_sets
			end
		end
	end
	return {tag_set}
end

local function try_lang_specific_module(langcode, modules_tried, name, data)
	local lang_specific_module = form_of_lang_data_module_prefix .. langcode .. "/functions"
	local langdata = safe_require(lang_specific_module)
	if langdata then
		insert(modules_tried, lang_specific_module)
		if langdata.cat_functions then
			local fn = langdata.cat_functions[name]
			if fn then
				return fn(data), true
			end
		end
	end
	return nil, false
end

-- Call a named function, either from the lang-specific data in
-- [[Module:form of/lang-specific/LANGCODE/functions]] or in [[Module:form of/functions]].
local function call_named_function(name, funtype, normalized_tag_set, lang, POS, pagename, lemmas)
	local data = {
		pagename = pagename or default_pagename or get_default_pagename(),
		lemmas = lemmas,
		tag_set = normalized_tag_set,
		lang = lang,
		POS = POS
	}
	local modules_tried = {}
	-- First try lang-specific.
	while lang do
		local retval, found_it = try_lang_specific_module(lang:getCode(), modules_tried, name, data)
		if found_it then
			return retval
		end
		-- If the language has a parent (i.e. a superordinate variety), try again with that.
		lang = lang:getParent()
	end
	-- Try lang-independent.
	insert(modules_tried, form_of_functions_module)
	local fn = (cat_functions or get_cat_functions())[name]
	if fn then
		return fn(data)
	end
	for i, modname in ipairs(modules_tried) do
		modules_tried[i] = "[[" .. modname .. "]]"
	end
	error(("No %s function named '%s' in %s"):format(funtype, name, list_to_text(modules_tried, nil, " or ")))
end

-- Given a tag from the current tag set (which may be a list in case of a multipart tag),
-- and a tag from a categorization spec, check that the two match.
-- (1) If both are strings, we just check for equality.
-- (2) If the spec tag is a string and the tag set tag is a list (i.e. it originates from a
-- multipart tag), we check that the spec tag is in the list. This is because we want to treat
-- multipart tags in user-specified tag sets as if the user had specified multiple tag sets.
-- For example, if the user said "1//3|s|pres|ind" and the categorization spec says {"has", "1"},
-- we want this to match, because "1//3|s|pres|ind" should be treated equivalently to two tag
-- sets "1|s|pres|ind" and "3|s|pres|ind", and the former matches the categorization spec.
-- (3) If the spec tag is a list (i.e. it originates from a multipart tag), we check that the
-- tag set tag is also a list and is a superset of the spec tag. For example, if the categorization
-- spec says {"has", "1//3"}, then the tag set tag must be a multipart tag that has both "1" and "3"
-- in it. "1//3" works, as does "1//2//3".
local function tag_set_tag_matches_spec_tag(tag_set_tag, spec_tag)
	if type(spec_tag) == "table" then
		if type(tag_set_tag) == "table" and is_subset_list(spec_tag, tag_set_tag) then
			return true
		end
	elseif type(tag_set_tag) == "table" then
		if contains(tag_set_tag, spec_tag) then
			return true
		end
	elseif tag_set_tag == spec_tag then
		return true
	end
	return false
end

-- Check that the current tag set matches the given spec tag. This means that any of the tags
-- in the current tag set match, according to tag_set_tag_matches_spec_tag(); see above. If the
-- current tag set contains only string tags (i.e. no multipart tags), and the spec tag is a
-- string (i.e. not a multipart tag), this boils down to list containment, but it gets more
-- complex when multipart tags are present.
local function tag_set_matches_spec_tag(spec_tag, tag_set, lang)
	spec_tag = normalize_tag(spec_tag, lang)
	for _, tag_set_tag in ipairs(tag_set) do
		if tag_set_tag_matches_spec_tag(tag_set_tag, spec_tag) then
			return true
		end
	end
	return false
end

-- Check whether the given spec matches the current tag set. Two values are returned:
-- (1) whether the spec matches the tag set; (2) the index of the category to add if
-- the spec matches.
local function check_condition(spec, tag_set, normalized_tag_set, lang, POS, pagename, lemmas)
	if type(spec) == "boolean" then
		return spec
	elseif type(spec) ~= "table" then
		error("Wrong type of condition " .. spec .. ": " .. type(spec))
	end
	local predicate = spec[1]
	if predicate == "has" then
		return tag_set_matches_spec_tag(spec[2], tag_set, lang), 3
	elseif predicate == "hasall" then
		for _, tag in ipairs(spec[2]) do
			if not tag_set_matches_spec_tag(tag, tag_set, lang) then
				return false, 3
			end
		end
		return true, 3
	elseif predicate == "hasany" then
		for _, tag in ipairs(spec[2]) do
			if tag_set_matches_spec_tag(tag, tag_set, lang) then
				return true, 3
			end
		end
		return false, 3
	elseif predicate == "tags=" then
		local normalized_spec_tag_sets = normalize_tag_set(spec[2], lang)
		if #normalized_spec_tag_sets > 1 then
			error("Internal error: No support for conjoined shortcuts in category/label specs in "
				.. "[[Module:form of/cats]] when processing spec tag set " .. concat(spec[2], "|"))
		end
		local normalized_spec_tag_set = normalized_spec_tag_sets[1]
		-- Check for and disallow two-level multipart tags in the specs. FIXME: Remove this when we remove
		-- support for two-level multipart tags.
		for _, tag in ipairs(normalized_spec_tag_set) do
			if type(tag) == "table" then
				for _, subtag in ipairs(tag) do
					if type(subtag) == "table" then
						error("Internal error: No support for two-level multipart tags in category/label specs"
							.. "[[Module:form of/cats]] when processing spec tag set "
							.. concat(spec[2], "|"))
					end
				end
			end
		end
		-- Allow tags to be in different orders, and multipart tags to be in different orders. To handle this,
		-- we first check that both tag set tags and spec tags have the same length. If so, we sort the
		-- multipart tags in the tag set tags and spec tags, and then check that all tags in the spec tags are
		-- in the tag set tags.
		if #tag_set ~= #normalized_spec_tag_set then
			return false, 3
		end
		local tag_set_tags = deep_copy(tag_set)
		for i=1,#tag_set_tags do
			if type(tag_set_tags[i]) == "table" then
				sort(tag_set_tags[i])
			end
			if type(normalized_spec_tag_set[i]) == "table" then
				sort(normalized_spec_tag_set[i])
			end
		end
		for i=1,#tag_set_tags do
			if not contains(tag_set_tags, normalized_spec_tag_set[i]) then
				return false, 3
			end
		end
		return true, 3
	elseif predicate == "p=" then
		return POS == normalize_pos(spec[2]), 3
	elseif predicate == "pany" then
		for _, specpos in ipairs(spec[2]) do
			if POS == normalize_pos(specpos) then
				return true, 3
			end
		end
		return false, 3
	elseif predicate == "pexists" then
		return POS ~= nil, 2
	elseif predicate == "not" then
		local condval = check_condition(spec[2], tag_set, normalized_tag_set, lang, POS, pagename, lemmas)
		return not condval, 3
	elseif predicate == "and" then
		local condval = check_condition(spec[2], tag_set, normalized_tag_set, lang, POS, pagename, lemmas)
		if condval then
			condval = check_condition(spec[3], tag_set, normalized_tag_set, lang, POS, pagename, lemmas)
		end
		return condval, 4
	elseif predicate == "or" then
		local condval = check_condition(spec[2], tag_set, normalized_tag_set, lang, POS, pagename, lemmas)
		if not condval then
			condval = check_condition(spec[3], tag_set, normalized_tag_set, lang, POS, pagename, lemmas)
		end
		return condval, 4
	elseif predicate == "call" then
		return call_named_function(spec[2], "condition", normalized_tag_set, lang, POS, pagename, lemmas), 3
	else
		error("Unrecognized predicate: " .. predicate)
	end
end

-- Process a given spec. This checks any conditions in the spec against the
-- tag set, and insert any resulting categories into `categories`. Return value
-- is true if the outermost condition evaluated to true and a category was inserted
-- (this is used in {"cond" ...} conditions, which stop when a subcondition evaluates
-- to true).
local function process_spec(spec, tag_set, normalized_tag_set, lang, POS, pagename, lemmas, categories, labels)
	if not spec then
		return false
	elseif type(spec) == "string" then
		-- A category. Substitute POS request with user-specified part of speech or default.
		spec = spec:gsub("<<p=(.-)>>", function(default)
			return POS or normalize_pos(default)
		end)
		insert(categories, lang:getFullName() .. " " .. spec)
		return true
	elseif type(spec) == "table" and spec.labels then
		-- A label spec.
		for _, label in ipairs(spec.labels) do
			insert_if_not(labels, label)
		end
		return true
	elseif type(spec) ~= "table" then
		error("Wrong type of specification " .. spec .. ": " .. type(spec))
	end
	local predicate = spec[1]
	if predicate == "multi" then
		for _, sp in iterate_from(2, ipairs(spec)) do -- Iterate from 2.
			process_spec(sp, tag_set, normalized_tag_set, lang, POS, pagename, lemmas, categories, labels)
		end
		return true
	elseif predicate == "cond" then
		for _, sp in iterate_from(2, ipairs(spec)) do -- Iterate from 2.
			if process_spec(sp, tag_set, normalized_tag_set, lang, POS, pagename, lemmas, categories, labels) then
				return true
			end
		end
		return false
	elseif predicate == "call" then
		return process_spec(
			call_named_function(spec[2], "spec", normalized_tag_set, lang, POS, pagename, lemmas),
			tag_set, normalized_tag_set, lang, POS, pagename, lemmas, categories, labels
		)
	else
		local condval, ifspec = check_condition(spec, tag_set, normalized_tag_set, lang, POS, pagename, lemmas)
		if condval then
			process_spec(spec[ifspec], tag_set, normalized_tag_set, lang, POS, pagename, lemmas, categories, labels)
			return true
		else
			process_spec(spec[ifspec + 1], tag_set, normalized_tag_set, lang, POS, pagename, lemmas, categories, labels)
			-- FIXME: Are we sure this is correct?
			return false
		end
	end
end

--[==[
Given a normalized tag set (i.e. as output by {normalize_tag_set()}; all tags are in canonical form, multipart tags are
represented as lists, and two-level multipart tags as lists of lists), fetch the associated categories and labels.
Return two values, a list of categories and a list of labels. `lang` is the language of term represented by the tag set,
and `POS` is the user-provided part of speech (which may be {nil}).]==]
function export.fetch_categories_and_labels(normalized_tag_set, lang, POS, pagename, lemmas)
	local categories, labels = {}, {}
	POS = normalize_pos(POS)
	-- First split any two-level multipart tags into multiple sets, to make our life easier.
	for _, tag_set in ipairs(split_two_level_multipart_tag_set(normalized_tag_set)) do
		local langcode = lang:getCode()
		local langspecs = (m_cats_data or get_m_cats_data())[langcode]
		if langspecs then
			for _, spec in ipairs(langspecs) do
				process_spec(spec, tag_set, normalized_tag_set, lang, POS, pagename, lemmas, categories, labels)
			end
		end
		local full_code = lang:getFullCode()
		if full_code ~= langcode then
			local langspecs = (m_cats_data or get_m_cats_data())[full_code]
			if langspecs then
				for _, spec in ipairs(langspecs) do
					process_spec(spec, tag_set, normalized_tag_set, lang, POS, pagename, lemmas, categories, labels)
				end
			end
		end
		if full_code ~= "und" then
			local langspecs = (m_cats_data or get_m_cats_data())["und"]
			if langspecs then
				for _, spec in ipairs(langspecs) do
					process_spec(spec, tag_set, normalized_tag_set, lang, POS, pagename, lemmas, categories, labels)
				end
			end
		end
	end
	return categories, labels
end
fetch_categories_and_labels = export.fetch_categories_and_labels

local function format_labels(labels, data, notext)
	if labels and #labels > 0 then
		return show_labels{
			labels = labels,
			lang = data.lang,
			sort = data.sort,
			nocat = data.nocat
		} .. (notext and (data.pretext or "") == "" and "" or " ")
	else
		return ""
	end
end

--[==[
Implementation of templates that display inflection tags, such as the general {{tl|inflection of}}, semi-specific
variants such as {{tl|participle of}}, and specific variants such as {{tl|past participle of}}. `data` contains all the
information controlling the display, with the following fields:

* `.lang`: ('''''required''''') Language to use when looking up language-specific inflection tags, categories and
  labels, and for displaying categories and labels.
* `.tags`: ('''''required''' unless `.tag_sets` is given'') List of non-canonicalized inflection tags. Multiple tag sets
  can be indicated by a {";"} as one of the tags, and tag-set properties may be attached to the last tag of a tag set.
  The tags themselves may come directly from the user (as in {{tl|inflection of}}); come partly from the user (as in
  {{tl|participle of}}, which adds the tag `part` to user-specified inflection tags); or be entirely specified by the
  template (as in {{tl|past participle of}}).
* `.tag_sets`: ('''''required''' unless `.tags` is given'') List of non-canonicalized tag sets and associated
  per-tag-set properties. Each element of the list is an object of the form
  { {tags = {"TAG", "TAG", ...}, labels = {"LABEL", "LABEL", ...}}. If `.tag_sets` is specified, `.tags` should not be
  given and vice-versa. Specifying `.tag_sets` in place of tags allowed per-tag set labels to be specified; otherwise,
  there is no advantage. [[Module:pt-gl-inflections]] uses this functionality to supply labels like {"Brazil"} and
  {"Portugal"} associated with specific tag sets.
* `.lemmas`: ('''''recommended''''') List of objects describing the lemma(s) of which the term in question is a
  non-lemma form. These are passed directly to {full_link()} in [[Module:links]]. Each object should have at minimum a
  `.lang` field containing the language of the lemma and a `.term` field containing the lemma itself. Each object is
  formatted using {full_link()} and then if there are more than one, they are joined using {serialCommaJoin()} in
  [[Module:table]]. Alternatively, `.lemmas` can be a string, which is displayed directly. If omitted entirely, no lemma
  links are shown and the connecting "of" is also omitted.
* `.lemma_face`: ('''''recommended''''') "Face" to use when displaying the lemma objects. Usually should be set to
  {"term"}.
* `.POS`: ('''''recommended''''') Categorizing part-of-speech tag. Comes from the {{para|p}} or {{para|POS}} argument of
  {{tl|inflection of}}.
* `.pagename`: Page name of "current" page or nil to use the actual page title; for testing purposes.
* `.enclitics`: List of enclitics to display after the lemmas, in parens.
* `.no_format_categories`: If true, don't format the categories derived from the inflection tags; just return them.
* `.sort`: Sort key for formatted categories. Ignored when `.no_format_categories` = {true}.
* `.nocat`: Suppress computation of categories (even if `.no_format_categories` is not given).
* `.notext`: Disable display of all tag text and `inflection of` text. (FIXME: Maybe not implemented correctly.)
* `.capfirst`: Capitalize the first word displayed.
* `.pretext`: Additional text to display before the inflection tags, but after any top-level labels.
* `.posttext`: Additional text to display after the lemma links.
* `.text_classes`: CSS classes used to wrap the tag text and lemma links. Default is
  {"form-of-definition use-with-mention"} for the tag text, {"form-of-definition-link"} for the lemma links. (FIXME:
  Should separate out the lemma links into their own field.)
`.joiner`: Override the joiner (normally a slash) used to join multipart tags. You should normally not specify this.

A typical call might look like this (for {{m+|es|amo}}): {
	local lang = require("Module:languages").getByCode("es")

	local lemma_obj = {
		lang = lang,
		term = "amar",
	}

	return m_form_of.tagged_inflections({
		lang = lang, tags = {"1", "s", "pres", "ind"}, lemmas = {lemma_obj}, lemma_face = "term", POS = "verb"
	})
}

Normally, one value is returned, the formatted text, which has appended to it the formatted categories derived from the
tag-set-related categories generated by the specs in [Module:form of/cats]]. To suppress this, set
`data.no_format_categories` = {true}, in which case two values are returned, the formatted text without any formatted
categories appended and a list of the categories to be formatted.

NOTE: There are two sets of categories that may be generated: (1) categories derived directly from the tag sets, as
specified in [[Module:form of/cats]]; (2) categories derived from tag-set labels, either (a) set explicitly by the
caller in `data.tag_sets`, (b) specified by the user using `<lb:...>` attached to the last tag in a tag set, or
(c) specified in [[Module:form of/cats]]. The second type (label-related categories) are currently not returned in
the second return value of {tagged_inflections()}, and are currently inserted into the output text even if
`data.no_format_categories` is set to {true}; but they can be suppressed by setting `data.nocat` = {true} (which also
suppresses the first type of categories, those derived directly from tag sets, even if `data.no_format_categories` is
set to {true}).]==]
function export.tagged_inflections(data)
	if not data.tags and not data.tag_sets then
		error("First argument must be a table of arguments, and `.tags` or `.tag_sets` must be specified")
	end
	if data.tags and data.tag_sets then
		error("Both `.tags` and `.tag_sets` cannot be specified")
	end
	local tag_sets = data.tag_sets
	if not tag_sets then
		tag_sets = split_tag_set(data.tags)
		for i, tag_set in ipairs(tag_sets) do
			tag_sets[i] = parse_tag_set_properties(tag_set)
		end
	end

	local inflections = {}
	local categories = {}
	for _, tag_set in ipairs(tag_sets) do
		local normalized_tag_sets = normalize_tag_set(tag_set.tags, data.lang, "do-track")

		for _, normalized_tag_set in ipairs(normalized_tag_sets) do
			local this_categories, this_labels = fetch_categories_and_labels(normalized_tag_set, data.lang,
				data.POS, data.pagename, type(data.lemmas) == "table" and data.lemmas or nil)
			if not data.nocat then
				extend(categories, this_categories)
			end
			local cur_infl = get_tag_set_display_form(normalized_tag_set, data.lang, data.joiner)
			if #cur_infl > 0 then
				if tag_set.labels then
					this_labels = append(tag_set.labels, this_labels)
				end
				insert(inflections, {infl_text = cur_infl, labels = this_labels})
			end
		end
	end

	local overall_labels, need_per_tag_set_labels
	for _, inflection in ipairs(inflections) do
		if overall_labels == nil then
			overall_labels = inflection.labels
		elseif not deep_equals(overall_labels, inflection.labels) then
			need_per_tag_set_labels = true
			overall_labels = nil
			break
		end
	end

	if not need_per_tag_set_labels then
		for _, inflection in ipairs(inflections) do
			inflection.labels = nil
		end
	end

	local format_data = shallow_copy(data)

	local of_text = data.lemmas and " of" or ""
	local formatted_text
	if #inflections == 1 then
		if need_per_tag_set_labels then
			error("Internal error: need_per_tag_set_labels should not be set with one inflection")
		end
		format_data.text = format_labels(overall_labels, data, data.notext) .. (data.pretext or "") .. (data.notext and "" or
			((data.capfirst and ucfirst(inflections[1].infl_text) or inflections[1].infl_text) .. of_text))
		formatted_text = format_form_of(format_data)
	else
		format_data.text = format_labels(overall_labels, data, data.notext) .. (data.pretext or "") .. (data.notext and "" or
			((data.capfirst and "Inflection" or "inflection") .. of_text))
		format_data.posttext = (data.posttext or "") .. ":"
		local link = format_form_of(format_data)
		local text_classes = data.text_classes or "form-of-definition use-with-mention"
		for i, inflection in ipairs(inflections) do
			inflections[i] = "\n## " .. format_labels(inflection.labels, data, false) ..
				"<span class='" .. text_classes .. "'>" .. inflection.infl_text .. "</span>"
		end
		formatted_text = link .. concat(inflections)
	end

	if not data.no_format_categories then
		if #categories > 0 then
			formatted_text = formatted_text .. format_categories(categories, data.lang,
				data.sort, nil, export.force_cat)
		end
		return formatted_text
	end
	return formatted_text, categories
end
tagged_inflections = export.tagged_inflections

function export.dump_form_of_data(frame)
	local data = {
		require(form_of_data1_module),
		require(form_of_data2_module)
	}
	return require(json_module).toJSON(data)
end

export.form_of_cats_module = form_of_cats_module
export.form_of_data1_module = form_of_data1_module
export.form_of_data2_module = form_of_data2_module
export.form_of_functions_module = form_of_functions_module
export.form_of_lang_data_module_prefix = form_of_lang_data_module_prefix
export.form_of_pos_module = form_of_pos_module

return export
