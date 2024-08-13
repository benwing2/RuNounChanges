local export = {}

local m_etymology = require("Module:etymology")

-- For testing
local force_cat = false

function export.format_sources(lang, sc, sources, terminfo, sort_key, categories, nocat, conj)
	local m_utilities
	if lang and not nocat then
		m_utilities = require("Module:utilities")
	end
	local m_links = require("Module:links")
	
	local source_segs = {}
	final_link_page = terminfo.term and terminfo.term ~= "-" and m_links.get_link_page(terminfo.term, sources[#sources], sc) or nil
	for i, source in ipairs(sources) do
		local seg
		local display_term
		if i < #sources and terminfo.term and terminfo.term ~= "-" then
			local link_page = m_links.get_link_page(terminfo.term, source, sc)
			local exists = link_page and mw.title.new(link_page).exists
			local different = link_page ~= final_link_page
			display_term = exists or different
		end
		if display_term then
			local display, this_cats = m_etymology.insert_source_cat_get_display(categories, lang, source, true, nocat)
			seg = m_links.language_link{
				lang = source, term = terminfo.term, alt = display, tr = "-"
			}
			if lang and not nocat then
				-- Format categories, but only if there is a current language; {{cog}} currently gets no categories
				this_cats = m_utilities.format_categories(this_cats, lang, sort_key, nil, force_cat)
			else
				this_cats = ""
			end
			seg = "<span class=\"etyl\">" .. seg .. this_cats .. "</span>"
		else
			seg = m_etymology.format_etyl(lang, source, sort_key, categories, nocat)
		end
		table.insert(source_segs, seg)
	end
	return require("Module:table").serialCommaJoin(source_segs, conj and {conj = conj})
end


-- Internal implementation of {{cognate|...}} template with multiple source languages
function export.format_multi_cognate(sources, terminfo, sort_key, conj)
	local sc = require("Module:scripts").findBestScriptWithoutLang(terminfo.term)
	return export.format_multi_derived(nil, sc, sources, terminfo, sort_key, nil, conj, "cognate")
end


-- Internal implementation of {{derived|...}} template with multiple source languages
function export.format_multi_derived(lang, sc, sources, terminfo, sort_key, nocat, conj, template_name)
	return export.format_sources(lang, sc, sources, terminfo, sort_key, nil, nocat, conj) ..
		m_etymology.process_and_create_link(terminfo, template_name)
end


function export.format_multi_borrowed(lang, sc, sources, terminfo, sort_key, nocat, conj)
	local categories = {}

	if not nocat then
		for _, source in ipairs(sources) do
			m_etymology.insert_borrowed_cat(categories, lang, source)
		end
	end

	return export.format_sources(lang, sc, sources, terminfo, sort_key, categories, nocat, conj) ..
		m_etymology.process_and_create_link(terminfo, "borrowed")
end


return export
