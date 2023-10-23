local export = {}

local m_lang_specific_data = mw.loadData("Module:labels/data/lang")
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

local function fetch_categories(label, labdata, lang, term_mode)
	local categories = {}

	local langcode = lang:getNonEtymologicalCode()
	local canonical_name = lang:getNonEtymologicalName()

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

	local function insert_cat(cat)
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
		insert_cat(canonical_name .. " " .. cat)
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

function export.get_submodules(lang)
	local submodules = {}

	-- get language-specific labels from data module
	local langcode = data.lang and data.lang:getNonEtymologicalCode() or nil

	if langcode and m_lang_specific_data.langs_with_lang_specific_modules[langcode] then
		-- prefer per-language label in order to pick subvariety labels over regional ones
		table.insert(submodules, "Module:labels/data/lang/" .. langcode)
	end
	table.insert(submodules, "Module:labels/data")
	table.insert(submodules, "Module:labels/data/qualifiers")
	table.insert(submodules, "Module:labels/data/regional")
	table.insert(submodules, "Module:labels/data/topical")
	return submodules
end

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
			break
		end
	end
	labdata = labdata or {}

	if labdata.deprecated then
		deprecated = true
	end
	if type(labdata) == "string" or labdata.alias_of then
		label = labdata.alias_of or labdata
		labdata = submodule[label] or {}
	end
	if labdata.deprecated then
		deprecated = true
	end

	if labdata.track then
		-- Track label (after converting aliases to canonical form). It is too expensive to track all labels.
		track_label(label, langcode)
	end

	local displayed_label

	if labdata.special_display then
		local function add_language_name(str)
			if str == "canonical_name" then
				return data.lang:getNonEtymologicalName()
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

	ret.deprecated = deprecated
	if deprecated then
		displayed_label = '<span class="deprecated-label">' .. displayed_label .. '</span>'
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
		local cats = fetch_categories(label, labdata, data.lang, data.term_mode)
		for _, cat in ipairs(cats) do
			table.insert(ret.categories, cat)
		end
		if #ret.categories == 0 then
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
	

function export.show_labels(data)
	if not data.labels then
		error("`data` must now be an object containing the params")
	end
	local labels = data.labels
	if not labels[1] then
		if mw.title.getCurrentTitle().nsText == "Template" then
			labels = {"example"}
		else
			error("You must specify at least one label.")
		end
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
		"<span class=\"ib-brac\">(</span><span class=\"ib-content\">" ..
		table.concat(labels, "") ..
		"</span><span class=\"ib-brac\">)</span>"
end

-- Helper function for the data modules.
function export.alias(labels, key, aliases)
	require(table_module).alias(labels, key, aliases)
end

-- Used to finalize the data into the form that is actually returned.
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
