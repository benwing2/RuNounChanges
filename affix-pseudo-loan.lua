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
		text = "[[Appendix:Japanese glossary#wasei eigo|" .. (nocap and "w" or "W") .. "asei eigo]] ({{m|ja|和製英語}}; " ..
			glossary_pseudo_loan_link("pseudo-anglicism") .. ")"
		text = mw.getCurrentFrame():preprocess(text)
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

	if not data.nocat then
		table.insert(categories, "pseudo-loans from " .. data.source:getCanonicalName())
		table.insert(categories, "terms derived from " .. data.source:getCanonicalName())
	end

	-- Make links out of all the parts
	for i, part in ipairs(data.parts) do
		table.insert(parts_formatted, m_affix.link_term(part,
			-- If the part is in a language other than the source, we need to pass `lang` here and not `source`,
			-- because the value is used as the destination language in derived-from categories. For example, in
			-- [[Ego-Shooter]], a German pseudo-loan from English but where the first part is from Latin, we'll wrongly
			-- get the page placed in 'English terms derived from Latin' if we always pass `source`. When the part is in
			-- the source language, we do need to pass `source` so the part gets linked correctly.
			part.lang and data.lang or data.source, data.sc, data.sort_key, data.force_cat or debug_force_cat,
			data.nocat))
	end

	local text_sections = {}
	if not data.notext then
		table.insert(text_sections, get_pseudo_loan_text(data.lang, data.source, #data.parts > 0, data.nocap))
	end
	table.insert(text_sections, m_affix.concat_parts(data.lang, parts_formatted, categories, data.nocat, data.sort_key,
		data.lit, data.force_cat or debug_force_cat))
	return table.concat(text_sections)
end


return export
