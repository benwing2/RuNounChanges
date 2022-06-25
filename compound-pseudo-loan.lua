local export = {}

local debug_force_cat = false -- set to true for testing

local m_compound = require("Module:compound")

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
		text = "[[w:Wasei-eigo|" .. (nocap and "w" or "W") .. "asei eigo]] ({{m|ja|和製英語}}; " ..
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


function export.show_pseudo_loan(lang, source, sc, parts, sort_key, nocap, notext, nocat, lit, force_cat)
	local parts_formatted = {}
	local categories = {}

	if not nocat then
		table.insert(categories, "pseudo-loans from " .. source:getCanonicalName())
		table.insert(categories, "terms derived from " .. source:getCanonicalName())
	end

	-- Make links out of all the parts
	for i, part in ipairs(parts) do
		table.insert(parts_formatted, m_compound.link_term(part, part.term, source, sc, sort_key, force_cat or debug_force_cat, nocat))
	end

	local text_sections = {}
	table.insert(text_sections, get_pseudo_loan_text(lang, source, #parts > 0, nocap))
	table.insert(text_sections, m_compound.concat_parts(lang, parts_formatted, categories, nocat, sort_key, lit, force_cat or debug_force_cat))
	return table.concat(text_sections)
end


return export
