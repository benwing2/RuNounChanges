local export = {}

local m_utilities_format_categories = require("Module:utilities").format_categories
local m_lang_specific_data = mw.loadData("Module:labels/data/lang")

-- for testing
local force_cat = false

-- Add tracking category for PAGE. The tracking category linked to is [[Template:tracking/labels/PAGE]].
local function track(page)
	require("Module:debug/track")("labels/" .. page)
end

local function show_categories(data, lang, script, sort_key, script2, sort_key2, term_mode)
	local categories = {}
	local categories2 = {}

	if script then
		track("show-categories-script")
	end
	if sort_key then
		track("show-categories-sort-key")
	end
	if script2 then
		track("show-categories-script2")
	end
	if sort_key2 then
		track("show-categories-sort-key2")
	end
	local lang_code = lang:getCode()
	local canonical_name = lang:getCanonicalName()
	
	local topical_categories = data.topical_categories or {}
	local sense_categories = data.sense_categories or {}
	local pos_categories = data.pos_categories or {}
	local regional_categories = data.regional_categories or {}
	local plain_categories = data.plain_categories or {}

	local function insert_cat(cat)
		table.insert(categories, cat)
		
		if script then
			table.insert(categories, cat .. " in " .. script .. " script")
		end
		
		if script2 then
			table.insert(categories2, cat .. " in " .. script2 .. " script")
		end
	end

	for i, cat in ipairs(topical_categories) do
		insert_cat(lang_code .. ":" .. cat)
	end
	
	for i, cat in ipairs(sense_categories) do
		cat = (term_mode and cat .. " terms" ) or "terms with " .. cat .. " senses"
		insert_cat(canonical_name .. " " .. cat)
	end

	for i, cat in ipairs(pos_categories) do
		insert_cat(canonical_name .. " " .. cat)
	end
	
	for i, cat in ipairs(regional_categories) do
		insert_cat(cat .. " " .. canonical_name)
	end
	
	for i, cat in ipairs(plain_categories) do
		insert_cat(cat)
	end
	
	return	m_utilities_format_categories(categories, lang, sort_key, nil, force_cat) ..
			m_utilities_format_categories(categories2, lang, sort_key2, nil, force_cat)
end

function export.get_label_info(data, lang, already_seen, script, script2, sort_key, sort_key2, nocat, term_mode)
	if not data.label then
		-- old-style multi-arg
		track("get-label-info-old-style")
		data = {
			label = data,
			lang = lang,
			already_seen = already_seen,
			script = script,
			script2 = script2,
			sort = sort_key,
			sort2 = sort_key2,
			nocat = nocat,
			term_mode = term_mode
		}
	end

	local ret = {}
	local label = data.label
	local deprecated = false
	local categories = ""
	local alias
	local labdata
	local submodule

	-- get language-specific labels from data module
	local langcode = data.lang:getCode()
	
	if langcode and m_lang_specific_data.langs_with_lang_specific_modules[langcode] then
		-- prefer per-language label in order to pick subvariety labels over regional ones
		submodule = mw.loadData("Module:labels/data/lang/" .. langcode)
		labdata = submodule[label]
	end
	if not labdata then
		submodule = mw.loadData("Module:labels/data")
		labdata = submodule[label]
	end
	if not labdata then
		submodule = mw.loadData("Module:labels/data/regional")
		labdata = submodule[label]
	end
	if not labdata then
		submodule = mw.loadData("Module:labels/data/topical")
		labdata = submodule[label]
	end
	labdata = labdata or {}

	if labdata.deprecated then
		deprecated = true
	end
	if type(labdata) == "string" or labdata.alias_of then
		alias = label
		label = labdata.alias_of or labdata
		labdata = submodule[label] or {}
	end
	if labdata.deprecated then
		deprecated = true
	end

	if labdata.track then
		require("Module:debug").track("labels/label/" .. label)
	end
	
	if labdata.special_display then
		local function add_language_name(str)
			if str == "canonical_name" then
				return data.lang:getCanonicalName()
			else
				return ""
			end
		end
		
		label = require("Module:string utilities").gsub(labdata.special_display, "<(.-)>", add_language_name)
	else
		--[[
			If labdata.glossary or labdata.Wikipedia are set to true, there is a glossary definition
			with an anchor identical to the label, or a Wikipedia article with a title
			identical to the label.
				For example, the code
					labels["formal"] = {
						glossary = true,
					}
				indicates that there is a glossary entry for "formal".
				
			
			Otherwise, labdata.glossary and labdata.Wikipedia specify the title or the anchor.
		]]
		if labdata.glossary then
			local glossary_entry = type(labdata.glossary) == "string" and labdata.glossary or label
			label = "[[Appendix:Glossary#" .. glossary_entry .. "|" .. ( labdata.display or label ) .. "]]"
		elseif labdata.Wikipedia then
			local Wikipedia_entry = type(labdata.Wikipedia) == "string" and labdata.Wikipedia or label
			label = "[[w:" .. Wikipedia_entry .. "|" .. ( labdata.display or label ) .. "]]"
		else
			label = labdata.display or label
		end
	end
	
	if deprecated then
		label = '<span class="deprecated-label">' .. label .. '</span>'
		if not data.nocat then
			categories = categories .. m_utilities_format_categories({ "Entries with deprecated labels" }, data.lang, data.sort, nil, force_cat)
		end
	end
	
	local label_for_already_seen =
		(labdata.topical_categories or labdata.regional_categories
		or labdata.plain_categories or labdata.pos_categories
		or labdata.sense_categories) and label
		or nil
	
	-- Track label text. If label text was previously used, don't show it,
	-- but include the categories.
	-- For an example, see [[hypocretin]].
	if data.already_seen[label_for_already_seen] then
		ret.label = ""
	else
		if label:find("{") then
			label = mw.getCurrentFrame():preprocess(label)
		end
		ret.label = label
	end
	
	if nocat then
		ret.categories = ""
	else
		ret.categories = categories .. show_categories(labdata, data.lang, data.script, data.sort, data.script2, data.sort2, data.term_mode)
	end

	ret.data = labdata

	if label_for_already_seen then
		data.already_seen[label_for_already_seen] = true
	end

	return ret
end
	

function export.show_labels(data, lang, script, script2, sort_key, sort_key2, nocat, term_mode)
	if not data.labels then
		-- old-style multi-arg
		data = {
			labels = data,
			lang = lang,
			script = script,
			script2 = script2,
			sort = sort_key,
			sort2 = sort_key2,
			nocat = nocat,
			term_mode = term_mode
		}
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
	
	local already_seen = {}
	
	for i, label in ipairs(labels) do
		omit_preComma = omit_postComma
		omit_postComma = false
		omit_preSpace = omit_postSpace
		omit_postSpace = false

		local ret = export.get_label_info(label, lang, already_seen, script, script2, sort_key, sort_key2, nocat, term_mode)
		
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
		labels[i] = label .. ret.categories
	end
	
	return
		"<span class=\"ib-brac\">(</span><span class=\"ib-content\">" ..
		table.concat(labels, "") ..
		"</span><span class=\"ib-brac\">)</span>"
end

-- Helper function for the data modules.
function export.alias(labels, key, aliases)
	require("Module:table").alias(labels, key, aliases)
end

-- Used to finalize the data into the form that is actually returned.
function export.finalize_data(labels)
	local shallowcopy = require("Module:table").shallowcopy
	local aliases = {}
	for label, data in pairs(labels) do
		if type(data) == "table" then
			if data.aliases then
				data.display = data.display or label
				for _, alias in ipairs(data.aliases) do
					aliases[alias] = data
				end
				data.aliases = nil
			end
			if data.deprecated_aliases then
				local data2 = shallowcopy(data)
				data2.display = data2.display or label
				data2.deprecated = true
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