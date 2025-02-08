local export = {}

-- For testing
local force_cat = false

local require_when_needed = require("Module:utilities/require when needed")

local debug_track_module = "Module:debug/track"
local languages_module = "Module:languages"
local links_module = "Module:links"
local pron_qualifier_module = "Module:pron qualifier"
local table_module = "Module:table"
local utilities_module = "Module:utilities"

local m_links = require_when_needed(links_module)
local m_table = require_when_needed(table_module)
local m_utilities = require_when_needed(utilities_module)

local function create_one_link(termobj, template_name)
	if termobj.lang:hasType("family") then
		if termobj.term and termobj.term ~= "-" then
			require(debug_track_module)(template_name .. "/family-with-term")
		end
		
		termobj.term = "-"
	end
	template_name = template_name or "derived"
	local link = ""
	if termobj.term == "-" then
		--[=[
		[[Special:WhatLinksHere/Wiktionary:Tracking/cognate/no-term]]
		[[Special:WhatLinksHere/Wiktionary:Tracking/derived/no-term]]
		[[Special:WhatLinksHere/Wiktionary:Tracking/borrowed/no-term]]
		[[Special:WhatLinksHere/Wiktionary:Tracking/calque/no-term]]
		]=]
		require(debug_track_module)(template_name .. "/no-term")
	else
		link = m_links.full_link(termobj, "term", nil, "show qualifiers")
	end
	
	return link
end


local function join_segs(segs, conj)
	if segs[2] then
		if conj == "and" or conj == "or" then
			return m_table.serialCommaJoin(segs, {conj = conj})
		else
			local sep
			if conj == "," then
				sep = ", "
			elseif conj == "/" then
				sep = "/"
			elseif conj == "~" then
				sep = " ~ "
			elseif conj == ";" then
				sep = "; "
			elseif conj then
				error(("Internal error: Unrecognized conjunction '%s'"):format(conj))
			else
				error(("Internal error: No value supplied for conjunction"):format(conj))
			end
			return table.concat(segs, sep)
		end
	else
		return segs[1]
	end
end	


-- Format one or more links as specified in `termobjs`, a list of term objects of the format accepted by full_link() in
-- [[Module:links]], additionally with optional qualifiers, labels and references. `conj` is used to join multiple
-- terms and must be specified if there is more than one term. `template_name` is the template name used in debug
-- tracking and must be specified. The return value begins with a space if there is anything to display (which is always
-- the case unless there is a single term with the value "-").
function export.format_links(termobjs, conj, template_name)
	for i, termobj in ipairs(termobjs) do
		termobjs[i] = create_one_link(termobj, template_name)
	end

	local retval = join_segs(termobjs, conj)
	if retval ~= "" then
		retval = " " .. retval
	end
	return retval
end
	

function export.get_display_and_cat_name(source, raw)
	local display, cat_name
	if source:getCode() == "und" then
		display = "undetermined"
		cat_name = "other languages"
	elseif source:getCode() == "mul" then
		display = raw and "translingual" or "[[w:Translingualism|translingual]]"
		cat_name = "Translingual"
	elseif source:getCode() == "mul-tax" then
		display = raw and "taxonomic name" or "[[w:Biological nomenclature|taxonomic name]]"
		cat_name = "taxonomic names"
	else
		display = raw and source:getCanonicalName() or source:makeWikipediaLink()
		cat_name = source:getDisplayForm()
	end
	return display, cat_name
end


function export.insert_source_cat_get_display(data)
	local categories, lang, source = data.categories, data.lang, data.source
	local display, cat_name = export.get_display_and_cat_name(source, data.raw)

	if lang and not data.nocat then
		-- Add the category, but only if there is a current language
		if not categories then
			categories = {}
		end

		local langname = lang:getFullName()
		-- If `lang` is an etym-only language, we need to check both it and its parent full language against `source`.
		-- Otherwise if e.g. `lang` is Medieval Latin and `source` is Latin, we'll end up wrongly constructing a
		-- category 'Latin terms derived from Latin'.
		if lang:getCode() == source:getCode() or lang:getFullCode() == source:getCode() then
			table.insert(categories, langname .. " terms borrowed back into " .. langname)
		else
			table.insert(categories, langname .. " " .. (data.borrowing_type or "terms derived") .. " from " ..
				cat_name)
		end
	end

	return display, categories
end


function export.format_source(data)
	local lang, sort_key = data.lang, data.sort_key
	-- [[Special:WhatLinksHere/Wiktionary:Tracking/etymology/sortkey]]
	if sort_key then
		require(debug_track_module)("etymology/sortkey")
	end

	local display, categories = export.insert_source_cat_get_display(data)
	if lang and not data.nocat then
		-- Format categories, but only if there is a current language; {{cog}} currently gets no categories
		categories = m_utilities.format_categories(categories, lang, sort_key, nil,
			data.force_cat or force_cat)
	else
		categories = ""
	end
	
	return "<span class=\"etyl\">" .. display .. categories .. "</span>"
end


--[==[
Format sources for etymology templates such as {{tl|bor}}, {{tl|der}}, {{tl|inh}} and {{tl|cog}}. There may potentially
be more than one source language (except currently {{tl|inh}}, which doesn't support it because it doesn't really
make sense). In that case, all but the last source language is linked to the first term, but only if there is such a
term and this linking makes sense, i.e. either (1) the term page exists after stripping diacritics according to the
source language in question, or (2) the result of stripping diacritics according to the source language in question
results in a different page from the same process applied with the last source language. For example, {{m|ru|соля́нка}}
will link to [[солянка]] but {{m|en|соля́нка}} will link to [[соля́нка]] with an accent, and since they are different
pages, the use of English as a non-final source with term 'соля́нка' will link to [[соля́нка]] even though it doesn't
exist, on the assumption that it is merely a redlink that might exist. If none of the above criteria apply, a non-final
source language will be linked to the Wikipedia entry for the language, just as final source languages always are.

`data` contains the following fields:
* `lang`: The destination language object into which the terms were borrowed, inherited or otherwise derived. Used for
          categorization and can be nil, as with {{tl|cog}}.
* `sources`: List of source objects. Most commonly there is only one. If there are multiple, the non-final ones are
             handled specially; see above.
* `terms`: List of term objects. Most commonly there is only one. If there are multiple source objects as well as
           multiple term objects, the non-final source objects link to the first term object.
* `sort_key`: Sort key for categories. Usually nil.
* `categories`: Categories to add to the page. Additional categories may be added to `categories` based on the source
                languages ('''in which case `categories` is destructively modified'''). If `lang` is nil, no categories
				will be added.
* `nocat`: Don't add any categories to the page.
* `sourceconj`: Conjunction used to separate multiple source languages. Defaults to {"and"}.
* `borrowing_type`: Borrowing type used in categories, such as {"learned borrowings"}. Defaults to {"terms derived"}.
* `force_cat`: Force category generation on non-mainspace pages.
]==]
function export.format_sources(data)
	local lang, sources, terms, sort_key, categories, nocat, sourceconj =
		data.lang, data.sources, data.terms, data.sort_key, data.categories, data.nocat, data.sourceconj
	
	local source_segs = {}
	final_link_page = sources[2] and terms[1].term and terms[1].term ~= "-" and
		m_links.get_link_page(terms[1].term, sources[#sources], terms[1].sc) or nil
	for i, source in ipairs(sources) do
		local seg
		local display_term
		if i < #sources and terms[1].term and terms[1].term ~= "-" then
			local link_page = m_links.get_link_page(terms[1].term, source, terms[1].sc)
			local exists = link_page and mw.title.new(link_page).exists
			local different = link_page ~= final_link_page
			display_term = exists or different
		end
		if display_term then
			local display, this_cats = export.insert_source_cat_get_display {
				categories = categories,
				lang = lang,
				source = source,
				raw = true,
				nocat = nocat,
				borrowing_type = data.borrowing_type,
			}
			seg = m_links.language_link {
				lang = source, term = terms[1].term, alt = display, tr = "-"
			}
			if lang and not nocat then
				-- Format categories, but only if there is a current language; {{cog}} currently gets no categories
				this_cats = m_utilities.format_categories(this_cats, lang, sort_key, nil, data.force_cat or force_cat)
			else
				this_cats = ""
			end
			seg = "<span class=\"etyl\">" .. seg .. this_cats .. "</span>"
		else
			seg = export.format_source {
				lang = lang,
				source = source,
				sort_key = sort_key,
				categories = categories,
				nocat = nocat,
				borrowing_type = borrowing_type,
			}
		end
		table.insert(source_segs, seg)
	end
	return join_segs(source_segs, sourceconj or "and")
end


-- Internal implementation of {{cognate}}/{{cog}} template.
function export.format_cognate(data)
	return export.format_derived {
		sources = data.sources,
		terms = data.terms,
		sort_key = data.sort_key,
		sourceconj = data.sourceconj,
		conj = data.conj,
		template_name = "cognate",
		force_cat = data.force_cat,
	}
end


-- Internal implementation of {{derived}}/{{der}} template. This is called externally from [[Module:affix]],
-- [[Module:affixusex]] and [[Module:see]] and needs to support qualifiers, labels and references on the outside
-- of the sources for use by those modules.
function export.format_derived(data)
	local result = export.format_sources(data) .. export.format_links(data.terms, data.conj, data.template_name)
	local q, qq, l, ll, refs = data.q, data.qq, data.l, data.ll, data.refs
	if q and q[1] or qq and qq[1] or l and l[1] or ll and ll[1] or refs and refs[1] then
		result = require(pron_qualifier_module).format_qualifiers {
			lang = data.terms[1].lang,
			text = result,
			q = q,
			qq = qq,
			l = l,
			ll = ll,
			refs = refs,
		}
	end
	return result
end


function export.insert_borrowed_cat(categories, lang, source)
	local category
	-- Do the same check as in insert_source_cat_get_display() (inverted).
	if not (lang:getCode() == source:getCode() or lang:getFullCode() == source:getCode()) then
		-- If both are the same, we want e.g. [[:Category:English terms borrowed back into English]] not
		-- [[:Category:English terms borrowed from English]]; the former is inserted automatically by format_source().
		-- The second parameter here doesn't matter as it only affects `display`, which we don't use.
		local display, cat_name = export.get_display_and_cat_name(source, "raw")
		category = " terms borrowed from " .. cat_name
	end
	if category then
		table.insert(categories, lang:getFullName() .. category)
	end
end


-- Internal implementation of {{borrowed}}/{{bor}} template.
function export.format_borrowed(data)
	data = m_table.shallowCopy(data)
	data.categories = {}

	if not data.nocat then
		for _, source in ipairs(data.sources) do
			export.insert_borrowed_cat(data.categories, data.lang, source)
		end
	end

	return export.format_sources(data) .. export.format_links(data.terms, data.conj, "borrowed")
end


do
	-- Generate the non-ancestor error message.
	local function show_language(lang)
		local retval = ("%s (%s)"):format(lang:makeCategoryLink(), lang:getCode())
		if lang:hasType("etymology-only") then
			retval = retval .. (" (an etymology-only language whose regular parent is %s)"):format(
				show_language(lang:getParent()))
		end
		return retval
	end
	
	-- Check that `lang` has `otherlang` (which may be an etymology-only language) as an ancestor. Throw an error if
	-- not.
	function export.check_ancestor(lang, otherlang)
		-- FIXME: I don't know if this function works correctly with etym-only languages in `lang`. I have fixed up
		-- the module link code appropriately (June 2024) but the remaining logic is untouched.
		if lang:hasAncestor(otherlang) or mw.title.getCurrentTitle().nsText == "Template" then
			return
		end
		local ancestors, postscript = lang:getAncestors()
		local etym_module_link = lang:hasType("etymology-only") and "[[Module:etymology languages/data]] or " or ""
		local module_link = "[[Module:"
			.. require(languages_module).getDataModuleName(lang:getFullCode())
			.. "]]"
		if not ancestors[1] then
			postscript = show_language(lang) .. " has no ancestors."
		else
			local ancestor_list = {}
			for _, ancestor in ipairs(ancestors) do
				table.insert(ancestor_list, show_language(ancestor))
			end
			postscript = ("The ancestor%s of %s %s %s."):format(
				ancestors[2] and "s" or "", lang:getCanonicalName(),
				ancestors[2] and "are" or "is", table.concat(ancestor_list, " and "))
		end
		error(("%s is not set as an ancestor of %s in %s%s. %s")
			:format(show_language(otherlang), show_language(lang), etym_module_link, module_link, postscript))
	end
end


-- Internal implementation of {{inherited}}/{{inh}} template.
function export.format_inherited(data)
	local lang, terms, sort_key, nocat = data.lang, data.terms, data.sort_key, data.nocat
	local source = terms[1].lang
	
	local categories = {}
	if not nocat then
		table.insert(categories, lang:getFullName() .. " terms inherited from " .. source:getCanonicalName())
	end

	export.check_ancestor(lang, source)

	return export.format_source {
		lang = lang,
		source = source,
		sort_key = sort_key,
		categories = categories,
		nocat = nocat,
		force_cat = data.force_cat,
	} .. export.format_links(terms, data.conj, "inherited")
	
end


-- Internal implementation of "misc variant" templates such as {{abbrev}}, {{clipping}}, {{reduplication}} and the like.
function export.format_misc_variant(data)
	local lang, notext, text, oftext, terms, conj, nocat, cats =
		data.lang, data.notext, data.text, data.oftext, data.terms, data.conj, data.nocat, data.cats

	local parts = {}

	local function ins(txt)
		table.insert(parts, txt)
	end

	if not notext then
		ins(text)
	end
	if terms[1] then
		if not notext then
			ins(" ")
			ins(oftext or "of")
			ins(" ")
		end
		ins(export.format_links(terms, conj, "misc_variant"))
	end

	local categories = {}
	if not nocat and cats then
		for _, cat in ipairs(cats) do
			table.insert(categories, lang:getFullName() .. " " .. cat)
		end
	end
	if #categories > 0 then
		ins(m_utilities.format_categories(categories, lang, data.sort_key, nil, data.force_cat or force_cat))
	end

	return table.concat(parts)
end

-- Implementation of miscellaneous templates such as {{unknown}} and {{onomatopoeia}} that have no associated terms.
function export.format_misc_variant_no_term(data)
	local lang = data.lang

	local parts = {}
	if not data.notext then
		table.insert(parts, data.title)
	end
	if not data.nocat and data.cat then
		local categories = {}
		table.insert(categories, lang:getFullName() .. " " .. data.cat)
		table.insert(parts, m_utilities.format_categories(categories, lang, data.sort_key, nil, data.force_cat or force_cat))
	end

	return table.concat(parts)
end

return export
