local export = {}

export.lang_specific_data_list_module = "Module:labels/data/lang"
export.lang_specific_data_modules_prefix = "Module:labels/data/lang/"
local m_lang_specific_data = mw.loadData(export.lang_specific_data_list_module)
local table_module = "Module:table"
local utilities_module = "Module:utilities"

-- for testing
local force_cat = false

-- Add tracking category for PAGE. The tracking category linked to is [[Template:tracking/labels/PAGE]].
local function track(page)
	require("Module:debug/track")("labels/" ..
		-- avoid including links in pages (may cause error)
		page:gsub("%[", "("):gsub("%]", ")"):gsub("|", "!"))
	return true
end

-- Track a label:
-- [[Special:WhatLinksHere/Template:tracking/labels/label/LABEL]]
-- [[Special:WhatLinksHere/Template:tracking/labels/label/LABEL/LANGCODE]]
local function track_label(label, langcode)
	label = "label/" .. label
	track(label)
	if langcode then
		track(label .. "/" .. langcode)
	end
end

local function ucfirst(txt)
	return mw.getContentLanguage():ucfirst(txt)
end

local function fetch_categories(label, labdata, lang, term_mode, for_doc)
	local categories = {}

	local langcode, canonical_name
	if lang then
		langcode = lang:getNonEtymologicalCode()
		canonical_name = lang:getNonEtymologicalName()
	elseif for_doc then
		langcode = "<var>[langcode]</var>"
		canonical_name = "<var>[language name]</var>"
	else
		error("Internal error: Must specify `lang` unless `for_doc` is given")
	end

	local empty_list = {}
	local function canonicalize_categories(cats)
		if not cats then
			return empty_list
		end
		if type(cats) ~= "table" then
			return {cats}
		end
		return cats
	end

	local topical_categories = canonicalize_categories(labdata.topical_categories)
	local sense_categories = canonicalize_categories(labdata.sense_categories)
	local pos_categories = canonicalize_categories(labdata.pos_categories)
	local regional_categories = canonicalize_categories(labdata.regional_categories)
	local plain_categories = canonicalize_categories(labdata.plain_categories)

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
		insert_cat(langcode .. ":" .. (cat == true and ucfirst(label) or cat))
	end
	
	for _, cat in ipairs(sense_categories) do
		if cat == true then
			cat = label
		end
		cat = (term_mode and cat .. " terms" ) or "terms with " .. cat .. " senses"
		insert_cat(canonical_name .. " " .. cat, true)
	end

	for _, cat in ipairs(pos_categories) do
		insert_cat(canonical_name .. " " .. (cat == true and label or cat))
	end
	
	for _, cat in ipairs(regional_categories) do
		insert_cat((cat == true and ucfirst(label) or cat) .. " " .. canonical_name)
	end
	
	for _, cat in ipairs(plain_categories) do
		insert_cat(cat == true and ucfirst(label) or cat)
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
	local langcode = lang and lang:getNonEtymologicalCode() or nil

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
(true if the label is deprecated, otherwise the deprecation information is taken from `labdata`). Returns two values:
the displayed label form and a boolean indicating whether the label is deprecated.

'''NOTE: Under normal circumstances, do not use this.''' It is intended for internal use by
[[Module:alternative forms]]. Instead, use `get_label_info`, which searches all the data modules for a given label
and handles other complications.
]==]
function export.get_displayed_label(label, labdata, lang, deprecated)
	local displayed_label
	deprecated = deprecated or labdata.deprecated

	if labdata.special_display then
		local function add_language_name(str)
			if str == "canonical_name" then
				if lang then
					return lang:getNonEtymologicalName()
				else
					return "<code><var>[language name]</var></code>"
				end
			else
				return ""
			end
		end
		
		displayed_label = require("Module:string utilities").gsub(labdata.special_display, "<(.-)>", add_language_name)
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
			* labdata.Wiktionary specifies an arbitrary Wiktionary page or page + anchor (e.g. a separate Appendix entry).
			* labdata.Wikipedia specifies an arbitrary Wikipedia article.
		]=]
		local display = labdata.display or label
		if labdata.glossary then
			local glossary_entry = type(labdata.glossary) == "string" and labdata.glossary or label
			displayed_label = "[[Appendix:Glossary#" .. glossary_entry .. "|" .. display .. "]]"
		elseif labdata.Wiktionary then
			displayed_label = "[[" .. labdata.Wiktionary .. "|" .. display .. "]]"
		elseif labdata.Wikipedia then
			local Wikipedia_entry = type(labdata.Wikipedia) == "string" and labdata.Wikipedia or label
			displayed_label = "[[w:" .. Wikipedia_entry .. "|" .. display .. "]]"
		else
			displayed_label = display
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
  (but its categories will still be added). This must be specified even if this functionality isn't needed; use { {}}
  in that case.

The return value is an object with the following fields:
* `label`: The display form of the label.
* `canonical`: If the label is an alias, this contains the canonical name of the label.
* `categories`: A list of the categories to add the label to.
* `formatted_categories`: A string containing the formatted categories.
* `deprecated`: True if the label is deprecated.
* `data`: The data structure for the label, as fetched from the label modules.
]==]
function export.get_label_info(data)
	if not data.label then
		error("`data` must now be an object containing the params")
	end

	local ret = {categories = {}}
	local label = data.label
	local deprecated = false
	local labdata
	local submodule

	local submodules_to_check = export.get_submodules(data.lang)
	for _, submodule_to_check in ipairs(submodules_to_check) do
		submodule = mw.loadData(submodule_to_check)
		labdata = submodule[label]
		if labdata then
			-- Make sure either there's no lang restriction, or we're processing lang-independent, or our language
			-- is among the listed languages. Otherwise, continue processing (which could conceivably pick up a
			-- lang-appropriate version of the label in another label data module).
			if not labdata.langs or not data.lang then
				break
			end
			local lang_in_list = false
			for _, langcode in ipairs(labdata.langs) do
				if langcode == data.lang:getCode() then
					lang_in_list = true
					break
				end
			end
			if lang_in_list then
				break
			end
		end
	end
	labdata = labdata or {}

	if labdata.deprecated then
		deprecated = true
	end
	if type(labdata) == "string" or labdata.alias_of then
		label = labdata.alias_of or labdata
		ret.canonical = label
		labdata = submodule[label] or {}
	end

	if labdata.track then
		-- Track label (after converting aliases to canonical form). It is too expensive to track all labels.
		track_label(label, langcode)
	end

	local displayed_label
	displayed_label, deprecated = export.get_displayed_label(label, labdata, data.lang, deprecated)
	ret.deprecated = deprecated
	if deprecated then
		if not data.nocat then
			table.insert(ret.categories, "Entries with deprecated labels")
		end
	end

	local label_for_already_seen =
		(labdata.topical_categories or labdata.regional_categories
		or labdata.plain_categories or labdata.pos_categories
		or labdata.sense_categories) and displayed_label
		or nil
	
	-- Track label text. If label text was previously used, don't show it, but include the categories.
	-- For an example, see [[hypocretin]].
	if data.already_seen[label_for_already_seen] then
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
		local cats = fetch_categories(label, labdata, data.lang, data.term_mode, data.for_doc)
		for _, cat in ipairs(cats) do
			table.insert(ret.categories, cat)
		end
		local ns = mw.title.getCurrentTitle().namespace
		if #ret.categories == 0 or (ns ~= 0 and ns ~= 100 and ns ~= 118) or data.for_doc then
			-- Only allow categories in the mainspace, appendix and reconstruction namespaces.
			-- Don't try to format categories if we're doing this for documentation ({{label/doc}}), because there
			-- will be HTML in the categories.
			ret.formatted_categories = ""
		else
			ret.formatted_categories = require(utilities_module).format_categories(ret.categories, data.lang,
				data.sort, nil, force_cat)
		end
	end

	ret.data = labdata

	if label_for_already_seen then
		data.already_seen[label_for_already_seen] = true
	end

	return ret
end
	

--[==[
Format one or more labels for display and categorization. This provides the implementation of the {{tl|label}}/{{tl|lb}}
and {{tl|term label}}/{{tl|tlb}} templates, and can also be called from a module. The return value is a string to be
inserted into the generated page, including the display and categories. On input `data` is an object with the following
fields:
* `labels`: List of the labels to format.
* `lang`: The language of the labels.
* `term_mode`: If true, the label was invoked using {{tl|tlb}}; otherwise, {{tl|lb}}.
* `nocat`: If true, don't add the label to any categories.
* `sort`: Sort key for categorization.

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
	
	-- Show the labels
	local omit_preComma = false
	local omit_postComma = true
	local omit_preSpace = false
	local omit_postSpace = true
	
	data.already_seen = {}
	
	for i, label in ipairs(labels) do
		omit_preComma = omit_postComma
		omit_postComma = false
		omit_preSpace = omit_postSpace
		omit_postSpace = false

		data.label = label
		local ret = export.get_label_info(data)

		local omit_comma = omit_preComma or ret.data.omit_preComma
		omit_postComma = ret.data.omit_postComma
		local omit_space = omit_preSpace or ret.data.omit_preSpace
		omit_postSpace = ret.data.omit_postSpace
		
		if ret.label == "" then
			label = ""
		else
			label = (omit_comma and "" or '<span class="ib-comma">,</span>') ..
					(omit_space and "" or "&#32;") ..
					ret.label
		end
		labels[i] = label .. ret.formatted_categories
	end
	
	return
		"<span class=\"" .. (data.term_mode and "usage-label-term" or "usage-label-sense") .. "\"><span class=\"ib-brac\">(</span><span class=\"ib-content\">" ..
		table.concat(labels, "") ..
		"</span><span class=\"ib-brac\">)</span></span>"
end

--[==[Helper function for the data modules.]==]
function export.alias(labels, key, aliases)
	require(table_module).alias(labels, key, aliases)
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
