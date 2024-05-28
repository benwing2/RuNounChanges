local export = {}

export.lang_specific_data_list_module = "Module:labels/data/lang"
export.lang_specific_data_modules_prefix = "Module:labels/data/lang/"
local m_lang_specific_data = mw.loadData(export.lang_specific_data_list_module)
local table_module = "Module:table"
local utilities_module = "Module:utilities"

-- for testing
local force_cat = false

-- Add tracking category for PAGE. The tracking category linked to is [[Wiktionary:Tracking/labels/PAGE]].
local function track(page, langcode)
	-- avoid including links in pages (may cause error)
	page = page:gsub("%[", "("):gsub("%]", ")"):gsub("|", "!")
	if langcode then
		require("Module:debug/track") { "labels/" .. page, "labels/" .. page .. "/" .. langcode }
	else
		require("Module:debug/track")("labels/" .. page)
	end
	return true
end

local function ucfirst(txt)
	return mw.getContentLanguage():ucfirst(txt)
end

-- HACK! For languages in any of the given families, check the specified-language Wikipedia for appropriate
-- Wikipedia articles for the language in question (esp. useful for obscure etymology-only languages that may not
-- have English articles for them, like many Chinese lects).
local families_to_wikipedia_languages = {
	{"zhx", "zh"},
	{"sem-arb", "ar"},
}

--[==[
Given language `lang` (a full language, etymology-language or family), fetch a list of Wikimedia languages to check
when converting a Wikidata item to a Wikipedia article. English is always first, followed by the Wikimedia language
code(s) of `lang` if `lang` is a language (which may or may not be the same as `lang`'s Wiktionary code), followed
by the macrolanguage of `lang` for certain languages and families (currently, only languages and families in the Chinese
and Arabic families). If `lang` is nil, only return English. Note that the same code may occur more than once in the
list. This is exported because it's also used by [[Module:category tree/poscatboiler/data/language varieties]].
]==]
function export.get_langs_to_extract_wikipedia_articles_from_wikidata(lang)
	local wikipedia_langs = {}
	table.insert(wikipedia_langs, "en")
	if lang then
		local article_lang = lang
		while article_lang do
			if article_lang:hasType("language") then
				local wmcodes = article_lang:getWikimediaLanguageCodes()
				for _, wmcode in ipairs(wmcodes) do
					table.insert(wikipedia_langs, wmcode)
				end
			end
			article_lang = article_lang:getParent()
		end
		for _, family_to_wp_lang in ipairs(families_to_wikipedia_languages) do
			local family, wp_lang = unpack(family_to_wp_lang)
			if lang:inFamily(family) then
				table.insert(wikipedia_langs, wp_lang)
			end
		end
	end
	return wikipedia_langs
end

--[==[
Fetch the categories to add to a page, given that the label whose canonical form is `canon_label` with language `lang`
has been seen. `labdata` is the label data structure for `label`, fetched from the appropriate submodule. If `term_mode`
is specified, the label was invoked using {{tl|tlb}}; otherwise, {{tl|lb}}. The return value is a list of the actual
categories, unless `for_doc` is specified, in which case the categories returned are marked up for display on a
documentation page. If `for_doc` is given, `lang` may be nil to format the categories in a language-independent fashion;
otherwise, it must be specified. If `category_types` is specified, it should be a set object (i.e. with category types
as keys and {true} as values), and only categories of the specified types will be returned.
]==]
function export.fetch_categories(canon_label, labdata, lang, term_mode, for_doc, category_types)
	local categories = {}

	local langcode, canonical_name
	if lang then
		langcode = lang:getFullCode()
		canonical_name = lang:getFullName()
	elseif for_doc then
		langcode = "<var>[langcode]</var>"
		canonical_name = "<var>[language name]</var>"
	else
		error("Internal error: Must specify `lang` unless `for_doc` is given")
	end

	local empty_list = {}
	local function get_cats(cat_type)
		if category_types and not category_types[cat_type] then
			return empty_list
		end
		local cats = labdata[cat_type]
		if not cats then
			return empty_list
		end
		if type(cats) ~= "table" then
			return {cats}
		end
		return cats
	end

	local topical_categories = get_cats("topical_categories")
	local sense_categories = get_cats("sense_categories")
	local pos_categories = get_cats("pos_categories")
	local regional_categories = get_cats("regional_categories")
	local plain_categories = get_cats("plain_categories")

	local function insert_cat(cat, sense_cat)
		if for_doc then
			cat = "<code>" .. cat .. "</code>"
			if sense_cat then
				if term_mode then
					cat = cat .. " (using {{tl|tlb}})"
				else
					cat = cat .. " (using {{tl|lb}})"
				end
				cat = mw.getCurrentFrame():preprocess(cat)
			end
		end

		table.insert(categories, cat)
	end

	for _, cat in ipairs(topical_categories) do
		insert_cat(langcode .. ":" .. (cat == true and ucfirst(canon_label) or cat))
	end
	
	for _, cat in ipairs(sense_categories) do
		if cat == true then
			cat = canon_label
		end
		cat = (term_mode and cat .. " terms" ) or "terms with " .. cat .. " senses"
		insert_cat(canonical_name .. " " .. cat, true)
	end

	for _, cat in ipairs(pos_categories) do
		insert_cat(canonical_name .. " " .. (cat == true and canon_label or cat))
	end
	
	for _, cat in ipairs(regional_categories) do
		insert_cat((cat == true and ucfirst(canon_label) or cat) .. " " .. canonical_name)
	end
	
	for _, cat in ipairs(plain_categories) do
		insert_cat(cat == true and ucfirst(canon_label) or cat)
	end

	return categories
end

--[==[
Return the list of all labels data modules for a label whose language is `lang`. The return value is a list of
module names, with overriding modules earlier in the list (that is, if a label occurs in two modules in the list,
the earlier-listed module takes precedence). If `lang` is nil, only return non-language-specific submodules.
]==]
function export.get_submodules(lang)
	local submodules = {}

	-- get language-specific labels from data module
	local langcode = lang and lang:getFullCode() or nil

	if langcode and m_lang_specific_data.langs_with_lang_specific_modules[langcode] then
		-- prefer per-language label in order to pick subvariety labels over regional ones
		table.insert(submodules, export.lang_specific_data_modules_prefix .. langcode)
	end
	table.insert(submodules, "Module:labels/data")
	table.insert(submodules, "Module:labels/data/qualifiers")
	table.insert(submodules, "Module:labels/data/regional")
	table.insert(submodules, "Module:labels/data/topical")
	return submodules
end

--[==[
Return the displayed form of a label `label`, given (a) the label data structure `labdata` from one of the data
modules; (b) the language object `lang` of the language being processed, or nil for no language; (c) `deprecated`
(true if the label is deprecated, otherwise the deprecation information is taken from `labdata`); (d) `override_display`
(always use the label in `label` as the display value, instead of any value in `labdata.display` or
`labdata.special_display`; (e) `accent_mode` (if specified, use the `accent_*` versions of properties in preference to
the bare properties, if they exist; used when handling {{tl|a}}). Returns two values: the displayed label form and a
boolean indicating whether the label is deprecated.

'''NOTE: Under normal circumstances, do not use this.''' It is intended for internal use by
[[Module:alternative forms]]. Instead, use `get_label_info`, which searches all the data modules for a given label
and handles other complications.
]==]
function export.get_displayed_label(label, labdata, lang, deprecated, override_display, accent_mode)
	local displayed_label
	deprecated = deprecated or labdata.deprecated

	if not override_display and labdata.special_display then
		local function add_language_name(str)
			if str == "canonical_name" then
				if lang then
					return lang:getFullName()
				else
					return "<code><var>[language name]</var></code>"
				end
			else
				return ""
			end
		end
		
		displayed_label = labdata.special_display:gsub("<(.-)>", add_language_name)
	else
		--[=[
			If labdata.glossary or labdata.Wikipedia are set to true, there is a glossary definition
			with an anchor identical to the label, or a Wikipedia article with a title
			identical to the label.
				For example, the code
					labels["formal"] = {
						glossary = true,
					}
				indicates that there is a glossary entry for "formal".

			Otherwise:
			* labdata.glossary specifies the anchor in [[Appendix:Glossary]].
			* labdata.Wiktionary specifies an arbitrary Wiktionary page or page + anchor (e.g. a separate Appendix
			  entry).
			* labdata.Wikipedia specifies an arbitrary Wikipedia article.
			* labdata.Wikidata specifies an arbitrary Wikidata item to retrieve a Wikipedia article from, or a list
			  of such items (in this case, we select the first one, but other modules using this info might use all
			  of them). If the item is of the form `wmcode:id`, the Wikipedia article corresponding to `wmcode` is
			  fetched if available. Otherwise, the English-language Wikipedia article is retrieved if available,
			  falling back to the Wikimedia language(s) corresponding to `lang` and then (in certain cases) to the
			  macrolanguage that `lang` is part of.

			Note that if accent_mode is set, properties prefixed by "accent_" (e.g. "accent_display",
			"accent_Wikipedia") are checked before the bare equivalent (e.g. "display", "Wikipedia").
		]=]
		local display = not override_display and (accent_mode and labdata.accent_display or labdata.display) or label
		if display:find("%[%[") then
			displayed_label = display
		else
			local function labdata_prop(prop)
				return accent_mode and labdata["accent_" .. prop] or labdata[prop]
			end
			local glossary = labdata_prop("glossary")
			local Wiktionary = labdata_prop("Wiktionary")
			local Wikipedia = labdata_prop("Wikipedia")
			local Wikidata = labdata_prop("Wikidata")
			if glossary then
				local glossary_entry = type(glossary) == "string" and glossary or label
				displayed_label = "[[Appendix:Glossary#" .. glossary_entry .. "|" .. display .. "]]"
			elseif Wiktionary then
				displayed_label = "[[" .. Wiktionary .. "|" .. display .. "]]"
			elseif Wikipedia then
				local Wikipedia_entry = type(Wikipedia) == "string" and Wikipedia or label
				displayed_label = "[[w:" .. Wikipedia_entry .. "|" .. display .. "]]"
			elseif Wikidata then
				if not mw.wikibase then
					error(("Unable to retrieve data from Wikidata ID for label '%s'; `mw.wikibase` not defined"
						):format(label))
				end
				local function make_displayed_label(wmcode, id)
					local article = mw.wikibase.sitelink(id, wmcode .. "wiki")
					if article then
						local link = wmcode == "en" and "w:" .. article or "w:" .. wmcode .. ":" .. article
						return ("[[%s|%s]]"):format(link, display)
					else
						return nil
					end
				end
				if type(Wikidata) == "table" then
					Wikidata = Wikidata[1]
				end
				local wmcode, id = Wikidata:match("^(.*):(.*)$")
				if wmcode then
					displayed_label = make_displayed_label(wmcode, id)
				else
					local langs_to_check = export.get_langs_to_extract_wikipedia_articles_from_wikidata(lang)
					for _, wmcode in ipairs(langs_to_check) do
						displayed_label = make_displayed_label(wmcode, Wikidata)
						if displayed_label then
							break
						end
					end
				end
				displayed_label = displayed_label or display
			else
				displayed_label = display
			end
		end
	end

	if deprecated then
		displayed_label = '<span class="deprecated-label">' .. displayed_label .. '</span>'
	end

	return displayed_label, deprecated
end

--[==[
Return information on a label. On input `data` is an object with the following fields:
* `label`: The label to return information on.
* `lang`: The language of the label. Must be specified unless `for_doc` is given.
* `term_mode`: If true, the label was invoked using {{tl|tlb}}; otherwise, {{tl|lb}}.
* `for_doc`: Data is being fetched for documentation purposes. This causes the raw categories returned in
  `categories` to be formatted for documentation display.
* `nocat`: If true, don't add the label to any categories.
* `already_seen`: An object used to track labels already seen, so they aren't displayed twice. Tracking is according
  to the display form of the label, so if two labels have the same display form, the second one won't be displayed
  (but its categories will still be added). If `already_seen` is {nil}, this tracking doesn't happen.

The return value is an object with the following fields:
* `raw_label`: The original label that was passed in (without any preceding exclamation point).
* `canonical`: If the label is an alias, this contains the canonical name of the label; otherwise it will be {nil}.
* `label`: The display form of the label.
* `categories`: A list of the categories to add the label to; an empty list of `nocat` was specified.
* `formatted_categories`: A string containing the formatted categories; an empty string if `nocat` or `for_doc` was
  specified or if 
* `deprecated`: True if the label is deprecated.
* `display_raw_label`: If true, the label was preceded by ! to indicate that the raw label should be displayed
  rather than the canonical form.
* `recognized`: If true, the label was found in some module.
* `data`: The data structure for the label, as fetched from the label modules. For unrecognized labels, this will
  be an empty object.
]==]
function export.get_label_info(data)
	if not data.label then
		error("`data` must now be an object containing the params")
	end

	local ret = {categories = {}}
	local label = data.label
	local display_raw_label = false
	if label:find("^!") then
		display_raw_label = true
		label = label:gsub("^!", "")
	end
	local raw_label = label
	ret.raw_label = label
	local deprecated = false
	local labdata
	local submodule
	local data_langcode = data.lang and data.lang:getCode() or nil

	local submodules_to_check = export.get_submodules(data.lang)
	for _, submodule_to_check in ipairs(submodules_to_check) do
		submodule = mw.loadData(submodule_to_check)
		local this_labdata = submodule[label]
		local resolved_label
		if type(this_labdata) == "string" then
			resolved_label = this_labdata
			this_labdata = submodule[this_labdata]
			if not this_labdata then
				error(("Internal error: Label alias '%s' points to '%s', which is undefined in module [[%s]]"):format(
					label, resolved_label, submodule_to_check))
			end
			if type(this_labdata) == "string" then
				error(("Internal error: Label alias '%s' points to '%s', which is also an alias (of '%s') in module [[%s]]"):format(
					label, resolved_label, this_labdata, submodule_to_check))
			end
		end
		if this_labdata then
			-- Make sure either there's no lang restriction, or we're processing lang-independent, or our language
			-- is among the listed languages. Otherwise, continue processing (which could conceivably pick up a
			-- lang-appropriate version of the label in another label data module).
			if not this_labdata.langs or not data_langcode then
				labdata = this_labdata
				label = resolved_label or label
				break
			end
			local lang_in_list = false
			for _, langcode in ipairs(this_labdata.langs) do
				if langcode == data_langcode then
					lang_in_list = true
					break
				end
			end
			if lang_in_list then
				labdata = this_labdata
				label = resolved_label or label
				break
			else
				-- Track use of a label that fails the lang restriction.
				-- [[Special:WhatLinksHere/Wiktionary:Tracking/labels/wrong-lang-label]]
				-- [[Special:WhatLinksHere/Wiktionary:Tracking/labels/wrong-lang-label/LANGCODE]]
				-- [[Special:WhatLinksHere/Wiktionary:Tracking/labels/wrong-lang-label/LABEL]]
				-- [[Special:WhatLinksHere/Wiktionary:Tracking/labels/wrong-lang-label/LABEL/LANGCODE]]
				track("wrong-lang-label", data_langcode)
				track("wrong-lang-label/" .. label, data_langcode)
				if resolved_label then
					track("wrong-lang-label/" .. resolved_label, data_langcode)
				end
			end
		end
	end
	if labdata then
		ret.recognized = true
	else
		labdata = {}
		ret.recognized = false
	end

	if labdata.deprecated then
		deprecated = true
	end
	if label ~= raw_label then
		-- Note that this is an alias and store the canonical version.
		ret.canonical = label
	end

	if true then -- labdata.track then -- track all labels now
		-- Track label (after converting aliases to canonical form; but also track raw label (alias) if different
		-- from canonical label). It is too expensive to track all labels.
		-- [[Special:WhatLinksHere/Wiktionary:Tracking/labels/label/LABEL]]
		-- [[Special:WhatLinksHere/Wiktionary:Tracking/labels/label/LABEL/LANGCODE]]
		track("label/" .. label, data_langcode)
		if label ~= raw_label then
			track("label/" .. raw_label, data_langcode)
		end
	end

	local displayed_label
	displayed_label, deprecated = export.get_displayed_label(display_raw_label and raw_label or label, labdata,
		data.lang, deprecated, display_raw_label, data.accent_mode)
	ret.deprecated = deprecated
	ret.display_raw_label = display_raw_label
	if deprecated then
		if not data.nocat then
			local depcat = "Entries with deprecated labels"
			if data.for_doc then
				depcat = "<code>" .. depcat .. "</code>"
			end
			table.insert(ret.categories, depcat)
		end
	end

	local label_for_already_seen =
		(labdata.topical_categories or labdata.regional_categories
		or labdata.plain_categories or labdata.pos_categories
		or labdata.sense_categories) and displayed_label
		or nil
	
	-- Track label text. If label text was previously used, don't show it, but include the categories.
	-- For an example, see [[hypocretin]].
	if data.already_seen and data.already_seen[label_for_already_seen] then
		ret.label = ""
	else
		if displayed_label:find("{") then
			displayed_label = mw.getCurrentFrame():preprocess(displayed_label)
		end
		ret.label = displayed_label
	end

	if data.nocat then
		ret.formatted_categories = ""
	else
		local cats = export.fetch_categories(label, labdata, data.lang, data.term_mode, data.for_doc)
		for _, cat in ipairs(cats) do
			table.insert(ret.categories, cat)
		end
		if #ret.categories == 0 or data.for_doc then
			-- Don't try to format categories if we're doing this for documentation ({{label/doc}}), because there
			-- will be HTML in the categories.
			ret.formatted_categories = ""
		else
			local ns = mw.title.getCurrentTitle().namespace
			if ns ~= 0 and ns ~= 100 and ns ~= 118 then
				-- Only allow categories in the mainspace, appendix and reconstruction namespaces.
				ret.formatted_categories = ""
			else
				ret.formatted_categories = require(utilities_module).format_categories(ret.categories, data.lang,
					data.sort, nil, force_cat)
			end
		end
	end

	ret.data = labdata

	if label_for_already_seen and data.already_seen then
		data.already_seen[label_for_already_seen] = true
	end

	return ret
end

--[==[
Return a list of objects corresponding to the raw label tags in `raw_tags`, where "label tags" are the tags after two
vertical bars in {{tl|alt}}. Each object is of the format returned by `get_label_info` in [[Module:labels]], as the
separate dialectal data modules have been removed.

NOTE: This function no longer does anything other than call {get_label_info()} in [[Module:labels]].
]==]
function export.get_label_list_info(raw_labels, lang, nocat, already_seen)
	local label_infos = {}

	for _, label in ipairs(raw_labels) do
		-- Pass in nocat to avoid extra work, since we won't use the categories.
		local display = export.get_label_info {
			label = label, lang = lang, nocat = nocat, already_seen = already_seen
		}
		table.insert(label_infos, display)
	end

	return label_infos
end

--[==[
Format one or more already-processed labels for display and categorization. "Already-processed" means that
{get_label_info()} or {get_label_list_info()} has been called on the raw labels to convert them into objects containing
information on how to display and categorize the labels. This is a lower-level alternative to {show_labels()} and is
meant for modules such as [[Module:alternative forms]], [[Module:quote]] and [[Module:etymology/templates/descendant]]
that support displaying labels along with some other information.

On input `data` is an object with the following fields:
* `labels`: List of the label objects to format, in the format returned by {get_label_info()}.
* `lang`: The language of the labels.
* `term_mode`: If true, the label was invoked using {{tl|tlb}}; otherwise, {{tl|lb}}. This only affects categorization.
* `sort`: Sort key for categorization.
* `already_seen`: An object used to track labels already seen, so they aren't displayed twice, as documented in
  {get_label_info()}. To enable this, set this to an empty object. If `already_seen` is {nil}, this tracking doesn't
  happen, meaning if the same label appears twice, it will be displayed twice.
* `open`: Open bracket or parenthesis to display before the concatenated labels. If specified, it is wrapped in the
  {"ib-brac"} CSS class. If {nil}, no open bracket is displayed.
* `close`: Close bracket or parenthesis to display after the concatenated labels. If specified, it is wrapped in the
  {"ib-brac"} CSS class. If {nil}, no close bracket is displayed.
* `no_ib_content`: By default, the concatenated formatted labels inside of the open/close brackets are wrapped in the
  {"ib-content"} CSS class. Specify this to suppress this wrapping.

Return value is a string containing the contenated labels, optionally surrounded by open/close brackets or parentheses.
Normally, labels are separated by comma-space sequences, but this may be suppressed for certain labels. If `nocat`
wasn't given to {get_label_info() or get_label_list_info()}, the label objects will contain formatted categories in
them, which will be inserted into the returned text. The concatenated text inside of the open/close brackets is normally
wrapped in the {"ib-content"} CSS class, but this can be suppressed, as mentioned above.

'''WARNING''': This destructively modifies the `data` structure.
]==]
function export.format_processed_labels(data)
	if not data.labels then
		error("`data` must now be an object containing the params")
	end
	local labels = data.labels
	if not labels[1] then
		error("You must specify at least one label.")
	end
	
	-- Show the labels
	local omit_preComma = false
	local omit_postComma = true
	local omit_preSpace = false
	local omit_postSpace = true
	
	for _, label in ipairs(labels) do
		omit_preComma = omit_postComma
		omit_postComma = false
		omit_preSpace = omit_postSpace
		omit_postSpace = false

		label.omit_comma = omit_preComma or label.data.omit_preComma
		omit_postComma = label.data.omit_postComma
		label.omit_space = omit_preSpace or label.data.omit_preSpace
		omit_postSpace = label.data.omit_postSpace
	end

	if data.lang then
		local lang_functions_module = export.lang_specific_data_modules_prefix .. data.lang:getCode() .. "/functions"
		local m_lang_functions = require(utilities_module).safe_require(lang_functions_module)
		if m_lang_functions and m_lang_functions.postprocess_handlers then
			for _, handler in ipairs(m_lang_functions.postprocess_handlers) do
				handler(data)
			end
		end
	end

	for i, labelinfo in ipairs(labels) do
		local label
		if labelinfo.label == "" then
			label = ""
		else
			label = (labelinfo.omit_comma and "" or '<span class="ib-comma">,</span>') ..
					(labelinfo.omit_space and "" or "&#32;") ..
					labelinfo.label
		end
		labels[i] = label .. labelinfo.formatted_categories
	end

	local function wrap_open_close(val)
		if val then
			return "<span class=\"ib-brac\">" .. val .. "</span>"
		else
			return ""
		end
	end

	local concatenated_labels = table.concat(labels, "")
	if not data.no_ib_content then
		concatenated_labels = "<span class=\"ib-content\">" .. concatenated_labels .. "</span>"
	end

	return wrap_open_close(data.open) .. concatenated_labels .. wrap_open_close(data.close)
end

--[==[
Format one or more labels for display and categorization. This provides the implementation of the
{{tl|label}}/{{tl|lb}}, {{tl|term label}}/{{tl|tlb}} and {{tl|accent}}/{{tl|a}} templates, and can also be called from a
module. The return value is a string to be inserted into the generated page, including the display and categories. On
input `data` is an object with the following fields:
* `labels`: List of the labels to format.
* `lang`: The language of the labels.
* `term_mode`: If specified, the label was invoked using {{tl|tlb}}; otherwise, {{tl|lb}} or {{tl|a}}. This only
  controls categorization. (FIXME: Consider renaming to 'categorization_mode' and making a string property.)
* `accent_mode`: If specified, the label was invoked using {{tl|a}}; otherwise, {{tl|tlb}} or {{tl|lb}}. This only
  controls display. (FIXME: Consider renaming to 'display_mode' and making a string property.)
* `nocat`: If true, don't add the label to any categories.
* `sort`: Sort key for categorization.
* `no_track_already_seen`: Don't track already-seen labels. If not specified, already-seen labels are not displayed
  again, but still categorize. See the documentation of {get_label_info()}.
* `open`: Open bracket or parenthesis to display before the concatenated labels. If {nil}, defaults to an open
  parenthesis. Set to {false} to disable.
* `close`: Close bracket or parenthesis to display after the concatenated labels. If {nil}, defaults to a close
  parenthesis. Set to {false} to disable.

Compared with {format_processed_labels()}, this function has the following differences:
# The labels specified in `labels` are raw labels (i.e. strings) rather than formatted objects.
# The open and close brackets default to parentheses ("round brackets") rather than not being displayed by default.
# Tracking of already-seen labels is enabled unless explicitly turned off using `no_track_already_seen`.
# The entire formatted result is wrapped in the {"usage-label-sense"} CSS class (or {"usage-label-term"} if `term_mode`
  is specified).

'''WARNING''': This destructively modifies the `data` structure.
]==]
function export.show_labels(data)
	if not data.labels then
		error("`data` must now be an object containing the params")
	end
	local labels = data.labels
	if not labels[1] then
		error("You must specify at least one label.")
	end

	if not data.no_track_already_seen then
		data.already_seen = {}
	end
	
	for i, label in ipairs(labels) do
		data.label = label
		local ret = export.get_label_info(data)
		labels[i] = ret
	end

	if data.open == nil then
		data.open = "("
	end
	if data.close == nil then
		data.close = ")"
	end
	local formatted = export.format_processed_labels(data)
	return
		"<span class=\"" .. (data.term_mode and "usage-label-term" or "usage-label-sense") .. "\">" .. formatted ..
			"</span>"
end

--[==[Helper function for the data modules.]==]
function export.alias(labels, key, aliases)
	require(table_module).alias(labels, key, aliases)
end

--[==[
Split the display form of a label. Returns two values: `link` and `display`. If the display form consists of a
two-part link, `link` is the first part and `display` is the second part. If the display form consists of a
single-part link, `link` and `display` are the same. Otherwise (the display form is not a link or contains an
embedded link), `link` is the same as the passed-in `label` and `display` is nil.
]==]
function export.split_display_form(label)
	if not label:find("%[%[") then
		return label, nil
	end
	local link, display = label:match("^%[%[([^%[%]|]+)|([^%[%]|]+)%]%]$")
	if link then
		return link, display
	end
	local link = label:match("^%[%[([^%[%]|])+%]%]$")
	if link then
		return link, link
	end
	return label, nil
end

--[==[
Combine the `link` and `display` parts of the display form of a label as returned by {split_display_form()}.
If `display` is nil, `link` is returned directly. Otherwise, a one-part or two-part link is constructed
depending on whether `link` and `display` are the same. (As a special case, if both consist of a blank string,
the return value is a blank string rather than a malformed link.)
]==]
function export.combine_display_form_parts(link, display)
	if not display then
		return link
	end
	if link == display then
		if link == "" then
			return ""
		else
			return ("[[%s]]"):format(link)
		end
	end
	return ("[[%s|%s]]"):format(link, display)
end

--[==[Used to finalize the data into the form that is actually returned.]==]
function export.finalize_data(labels)
	local shallowcopy = require(table_module).shallowcopy
	local aliases = {}
	for label, data in pairs(labels) do
		if type(data) == "table" then
			if data.aliases then
				for _, alias in ipairs(data.aliases) do
					aliases[alias] = label
				end
				data.aliases = nil
			end
			if data.deprecated_aliases then
				local data2 = shallowcopy(data)
				data2.deprecated = true
				data2.canonical = label
				for _, alias in ipairs(data2.deprecated_aliases) do
					aliases[alias] = data2
				end
				data.deprecated_aliases = nil
				data2.deprecated_aliases = nil
			end
		end
	end
	for label, data in pairs(aliases) do
		labels[label] = data
	end
	return labels
end

return export
