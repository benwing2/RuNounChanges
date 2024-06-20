local export = {}

local debug_force_cat = false -- set to true for testing

local m_affix = require("Module:affix")

local pseudo_loan_by_source = {
	["ar"] = "Arabism",
	["de"] = "Germanism",
	["en"] = "anglicism",
	["es"] = "Hispanism",
	["fr"] = "Gallicism",
	["it"] = "Italianism",
	["ja"] = "Japonism",
	["la"] = "Latinism",
}

local function get_pseudo_loan_text(lang, source, has_parts, nocap)
	local langcode = lang:getCode()
	local sourcecode = source:getCode()
	local function glossary_pseudo_loan_link(display)
		return "[[Appendix:Glossary#pseudo-loan|" .. display .. "]]"
	end
	local text
	if langcode == "ja" and sourcecode == "en" then
		local ja_link = require("Module:links").full_link({
			term = "和製英語",
			lang = require("Module:languages").getByCode("ja"),
			tr = "-"
		}, "term")
		text = "[[Appendix:Japanese glossary#wasei eigo|" .. (nocap and "w" or "W") .. "asei eigo]] (" .. ja_link .. "; " .. glossary_pseudo_loan_link("pseudo-anglicism") .. ")"
	elseif pseudo_loan_by_source[sourcecode] then
		text = glossary_pseudo_loan_link((nocap and "p" or "P") .. "seudo-" .. pseudo_loan_by_source[sourcecode])
	else
		text = glossary_pseudo_loan_link((nocap and "p" or "P") .. "seudo-loan") .. " from " .. source:getCanonicalName()
	end
	if has_parts then
		text = text .. ", derived from "
	end
	return text
end


function export.show_pseudo_loan(data)
	local parts_formatted = {}
	local categories = {}

	data.force_cat = data.force_cat or debug_force_cat

	if not data.nocat then
		table.insert(categories, "pseudo-loans from " .. data.source:getCanonicalName())
		table.insert(categories, "terms derived from " .. data.source:getCanonicalName())
	end

	-- Make links out of all the parts
	for i, part in ipairs(data.parts) do
		part.part_lang = part.lang
		-- When the part is in the source language, we need to use `source` so the part gets linked correctly. Otherwise,
		-- `data.lang` will be used, which is correct, because the value is used as the destination language in
		-- derived-from categories. An example is [[Ego-Shooter]], a German pseudo-loan from English but where the
		-- first part is from Latin.
		part.lang = part.lang or data.source
		part.sc = part.sc or data.sc
		table.insert(parts_formatted, m_affix.link_term(part, data))
	end

	local text_sections = {}
	if not data.notext then
		table.insert(text_sections, get_pseudo_loan_text(data.lang, data.source, #data.parts > 0, data.nocap))
	end
	table.insert(text_sections, m_affix.join_formatted_parts {
		data = data, parts_formatted = parts_formatted, categories = categories}
	)
	return table.concat(text_sections)
end


return export
