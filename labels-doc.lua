--[=[
	This module contains functions to implement {{label/doc}}.

	Author: Benwing2
]=]

local export = {}

local labels_module = "Module:labels"
local m_labels = require(labels_module)
local m_table = require("Module:table")
local m_languages = require("Module:languages")

local function sort_by_label(labinfo1, labinfo2)
	return labinfo1.raw_label < labinfo2.raw_label
end


local function create_label_table(label_infos)
	table.sort(label_infos, sort_by_label)
	local parts = {}

	local function ins(text)
		table.insert(parts, text)
	end

	ins('{|class="wikitable sortable"')
	ins("! Label !! Canonical equivalent !! Display form !! Categories !! Defined in !! Notes")
	for _, info in ipairs(label_infos) do
		ins("|-")
		ins("| <code>" .. info.raw_label .. "</code>")
		if info.canonical then
			ins("| <code>" .. info.canonical .. "</code>")
		else
			ins("|")
		end
		ins("| " .. info.label)
		ins("| " .. table.concat(info.categories, "<br />"))
		ins(("| [[%s]]"):format(info.module))
		local notes = {}
		if info.deprecated then
			table.insert(notes, "'''deprecated'''")
		end
		if info.data.omit_preComma or info.data.omit_postComma or info.data.omit_preSpace or info.data.omit_postSpace then
			local context_labinfos = m_labels.get_label_list_info({"foo", info.raw_label, "bar"}, nil, "nocat", nil, "notrack")
			local formatted = m_labels.format_processed_labels { labels = context_labinfos }
			table.insert(notes, "in context, displays as " .. formatted)
		end
		if info.data.track then
			table.insert(notes, "tracking enabled")
		end
		if info.data.langs then
			if not info.data.langs[1] then
				table.insert(notes, "not enabled for any languages")
			else
				local langs = {}
				for _, langcode in ipairs(info.data.langs) do
					local lang = m_languages.getByCode(langcode, nil, true)
					if not lang then
						table.insert(notes,
							("<span style=\"color: #FF0000;\">'''saw invalid lang code '%s' in lang restrictions'''"):format(langcode))
						langs = nil
						break
					end
					table.insert(langs, lang:getCanonicalName())
				end
				if langs then
					table.insert(notes, "restricted to " .. table.concat(langs, ", "))
				end
			end
		end
		if #notes > 0 then
			ins("| " .. table.concat(notes, "; "))
		else
			ins("|")
		end
	end
	ins("|}")

	return table.concat(parts, "\n")
end


function export.show()
	local submodules = m_labels.get_submodules(nil)

	local label_infos = {}
	local labels_seen = {}

	local function process_module(module, lang, label_infos, labels_seen)
		local module_data = mw.loadData(module)
		for label, _ in pairs(module_data) do
			if labels_seen[label] then
				table.insert(labels_seen[label], module)
			else
				local labinfo = m_labels.get_label_info {
					label = label,
					lang = lang,
					for_doc = true,
					notrack = true,
				}
				labinfo.raw_label = label
				labinfo.module = module
				table.insert(label_infos, labinfo)
			end
		end
	end

	for _, module in ipairs(submodules) do
		process_module(module, nil, label_infos, labels_seen)
	end

	local unrecognized_langcodes = {}

	local lang_specific_data_list_module = mw.loadData(m_labels.lang_specific_data_list_module)
	local lang_specific_data_langs = {}
	for langcode, _ in pairs(lang_specific_data_list_module.langs_with_lang_specific_modules) do
		local lang = m_languages.getByCode(langcode)
		if not lang then
			table.insert(unrecognized_langcodes, langcode)
		else
			table.insert(lang_specific_data_langs,
				{ lang = lang, langcode = langcode, langname = lang:getFullName() })
		end
	end
	table.sort(lang_specific_data_langs, function(a, b) return a.langname < b.langname end)

	local parts = {}
	local function ins(text)
		table.insert(parts, text)
	end

	ins("===Language-independent===")
	ins(create_label_table(label_infos))

	for _, langobj in ipairs(lang_specific_data_langs) do
		local per_language_label_infos = {}
		local per_language_labels_seen = {}
		process_module(m_labels.lang_specific_data_modules_prefix .. langobj.langcode, langobj.lang,
			per_language_label_infos, per_language_labels_seen)
		ins(("===%s==="):format(langobj.langname))
		ins(create_label_table(per_language_label_infos))
    end

	return table.concat(parts, "\n")
end


return export
