local export = {}

-- For testing
local force_cat = false

local function term_error(terminfo)
	if terminfo.lang:hasType("family") then
		if terminfo.term and terminfo.term ~= "-" then
			require("Module:debug/track")("etymology/family/has-term")
		end
		
		terminfo.term = "-"
	end
	return terminfo
end


local function create_link(terminfo, template_name)
	local link = ""
	
	if terminfo.term == "-" then
		--[=[
		[[Special:WhatLinksHere/Wiktionary:Tracking/cognate/no-term]]
		[[Special:WhatLinksHere/Wiktionary:Tracking/derived/no-term]]
		[[Special:WhatLinksHere/Wiktionary:Tracking/borrowed/no-term]]
		[[Special:WhatLinksHere/Wiktionary:Tracking/calque/no-term]]
		]=]
		require("Module:debug/track")(template_name .. "/no-term")
	else
--		mw.log(terminfo.term)
		link = require("Module:links").full_link(terminfo, "term")
		if (link ~= "") then link = " " .. link end
	end
	
	return link
end


function export.process_and_create_link(terminfo, template_name)
	terminfo = term_error(terminfo)
	return create_link(terminfo, template_name or "derived")
end
	

function export.get_display_and_cat_name(source, raw)
	local display, cat_name
	if source:getCode() == "und" then
		display = "undetermined"
		cat_name = "other languages"
	elseif source:getCode() == "mul" then
		display = "[[w:Translingualism|translingual]]"
		cat_name = "Translingual"
	elseif source:getCode() == "mul-tax" then
		display = "[[w:taxonomic name|taxonomic name]]"
		cat_name = "taxonomic names"
	else
		display = raw and source:getCanonicalName() or source:makeWikipediaLink()
		cat_name = source:getDisplayForm()
	end

	return display, cat_name
end


function export.insert_source_cat_get_display(categories, lang, source, raw, nocat)
	local display, cat_name = export.get_display_and_cat_name(source, raw)

	if lang and not nocat then
		-- Add the category, but only if there is a current language
		if not categories then
			categories = {}
		end

		local langname = lang:getCanonicalName()
		if lang:getCode() == source:getCode() then
			table.insert(categories, langname .. " terms borrowed back into " .. langname)
		else
			table.insert(categories, langname .. " terms derived from " .. cat_name)
		end
	end

	return display, categories
end


-- FIXME: rename to format_source()
function export.format_etyl(lang, source, sort_key, categories, nocat)
	-- [[Special:WhatLinksHere/Wiktionary:Tracking/etymology/sortkey]]
	if sort_key then
		require("Module:debug/track")("etymology/sortkey")
	end

	local display
	display, categories = export.insert_source_cat_get_display(categories, lang, source, false, nocat)
	if lang and not nocat then
		-- Format categories, but only if there is a current language; {{cog}} currently gets no categories
		categories = require("Module:utilities").format_categories(categories, lang, sort_key, nil, force_cat)
	else
		categories = ""
	end
	
	return "<span class=\"etyl\">" .. display .. categories .. "</span>"
end


-- Internal implementation of {{cognate|...}} template
function export.format_cognate(terminfo, sort_key)
	return export.format_derived(nil, terminfo, sort_key, nil, "cognate")
end


-- Internal implementation of {{derived|...}} template
function export.format_derived(lang, terminfo, sort_key, nocat, template_name)
	local source = terminfo.lang
	return export.format_etyl(lang, source, sort_key, nil, nocat) .. export.process_and_create_link(terminfo, template_name)
end

do
	-- Generate the non-ancestor error message.
	local function showLanguage(lang)
		local retval = ("%s (%s)"):format(lang:makeCategoryLink(), lang:getCode())
		if lang:hasType("etymology-only") then
			retval = retval .. (" (an etymology-only language whose regular parent is %s)"):format(
				showLanguage(lang:getParent()))
		end
		return retval
	end
	
	-- Check that `lang` has `otherlang` (which may be an etymology-only language) as an ancestor. Throw an error if not.
	function export.check_ancestor(lang, otherlang)
		if lang:hasAncestor(otherlang) or mw.title.getCurrentTitle().nsText == "Template" then
			return
		end
		local ancestors, postscript = lang:getAncestors()
		local moduleLink = "[[Module:"
			.. require("Module:languages").getDataModuleName(lang:getCode())
			.. "]]"
		if not ancestors[1] then
			postscript = showLanguage(lang) .. " has no ancestors."
		else
			local ancestorList = table.concat(
				require("Module:fun").map(
					showLanguage,
					ancestors),
				" and ")
			postscript = ("The ancestor%s of %s %s %s."):format(
				ancestors[2] and "s" or "", lang:getCanonicalName(),
				ancestors[2] and "are" or "is", ancestorList)
		end
		error(("%s is not set as an ancestor of %s in %s. %s")
			:format(showLanguage(otherlang), showLanguage(lang), moduleLink, postscript))
	end
end


-- Internal implementation of {{inherited|...}} template
function export.format_inherited(lang, terminfo, sort_key, nocat)
	local source = terminfo.lang
	
	local categories = {}
	if not nocat then
		table.insert(categories, lang:getCanonicalName() .. " terms inherited from " .. source:getCanonicalName())
	end

	local link = export.process_and_create_link(terminfo, "inherited")
	
	export.check_ancestor(lang, source)

	return export.format_etyl(lang, source, sort_key, categories, nocat) .. link
end


function export.insert_borrowed_cat(categories, lang, source)
	local category
	if lang:getCode() ~= source:getCode() then
		-- If both are the same, we want e.g. [[:Category:English terms borrowed back into English]] not
		-- [[:Category:English terms borrowed from English]]; the former is inserted automatically by format_etyl().
		category = " terms borrowed from " .. source:getDisplayForm()
	end
	if category then
		table.insert(categories, lang:getCanonicalName() .. category)
	end
end


-- Internal implementation of {{borrowed|...}} template.
function export.format_borrowed(lang, terminfo, sort_key, nocat)
	local source = terminfo.lang
	
	local categories = {}
	if not nocat then
		export.insert_borrowed_cat(categories, lang, source)
	end

	return export.format_etyl(lang, source, sort_key, categories, nocat) ..
		export.process_and_create_link(terminfo, "borrowed")
end

return export
