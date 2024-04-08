local require_when_needed = require("Module:utilities/require when needed")

local concat = table.concat
local format_categories = require_when_needed("Module:utilities", "format_categories")
local html_create = mw.html.create
local insert = table.insert
local require = require
local load_data = mw.loadData
local process_params = require_when_needed("Module:parameters", "process")

local export = {}

do
	local function interwiki(terminfo, lang, langcode, term, m_links, m_data)
		-- Don't show interwiki link if the term contains links (for SOP translations)
		if term:find("[[", nil, true) then
			terminfo.interwiki = false
			return
		end
		
		local wmlangs
		local interwiki_langcode = m_data.interwiki_langs[langcode]
		if interwiki_langcode then
			wmlangs = {require("Module:wikimedia languages").getByCode(interwiki_langcode)}
		else
			wmlangs = lang:getWikimediaLanguages()
		end
		
		-- Don't show the interwiki link if the language is not recognised by Wikimedia.
		if #wmlangs == 0 then
			terminfo.interwiki = false
			return
		end
		
		local sc = terminfo.sc
		
		local target_page = m_links.get_link_page(term, lang, sc)
		local split = m_links.split_on_slashes(target_page)
		if not split[1] then
			terminfo.interwiki = false
			return
		end
		target_page = split[1]
		
		local wmlangcode = wmlangs[1]:getCode()
		local interwiki_link = m_links.language_link{
			lang = lang,
			sc = sc,
			term = wmlangcode .. ":" .. target_page,
			alt = "(" .. wmlangcode .. ")",
			tr = "-"
		}
		
		terminfo.interwiki = tostring(mw.html.create("span")
			:addClass("tpos")
			:wikitext("&nbsp;" .. interwiki_link))
	end
	
	function export.show_terminfo(terminfo, check)
		local m_data = load_data("Module:translations/data")
		local lang = terminfo.lang
		local langcode, langname = lang:getCode(), lang:getCanonicalName()
		-- Translations must be for mainspace languages
		if not lang:hasType("regular") then
			error("Translations must be for attested and approved main-namespace languages.")
		else
			local err_msg = m_data.disallowed[langcode]
			if err_msg then
				error("Translations not allowed in " .. langname .. " (" .. langcode .. "). " .. langname .. " translations should " .. err_msg)
			end
		end
		
		local term = terminfo.term
		local m_links = require("Module:links")
		
		-- Check if there is a term. Don't show the interwiki link if there is nothing to link to.
		if not term then
			-- Track entries that don't provide a term.
			-- FIXME: This should be a category.
			local track = require("Module:debug/track")
			track("translations/no term")
			track("translations/no term/" .. langcode)
		elseif terminfo.interwiki then
			interwiki(terminfo, lang, langcode, term, m_links, m_data)
		end
		
		langcode = lang:getFullCode()
		
		if m_data.need_super[langcode] then
			local tr = terminfo.tr
			terminfo.tr = tr and tr:gsub("%d[%d%*%-]*%f[^%d%*]", "<sup>%0</sup>") or nil
		end
		
		local link = m_links.full_link(terminfo, "translation")
		local categories = {}
		
		if m_data.categorize[langcode] then
			insert(categories, lang:getFullName() .. " translations")
		end
		
		if check then
			link = tostring(html_create("span")
				:addClass("ttbc")
				:tag("sup")
					:addClass("ttbc")
					:wikitext("(please [[WT:Translations#Translations to be checked|verify]])")
					:done()
				:wikitext(" " .. link)
				:allDone())
			insert(categories, "Requests for review of " .. langname .. " translations")
		end
		
		categories = #categories > 0 and format_categories(
			categories,
			require("Module:languages").getByCode("en"),
			nil,
			(load_data("Module:headword/data").page.encoded_pagename
				:gsub("/translations$", ""))
		) or ""
		
		return link .. categories
	end
end

-- Implements {{t}}, {{t+}}, {{t-check}} and {{t+check}}.
do
	local function get_args(frame)
		local plain = {}
		return process_params(frame:getParent().args, {
			[1] = {required = true, type = "language", etym_lang = true, default = "und"},
			[2] = plain,
			[3] = {list = true},
			["alt"] = plain,
			["id"] = plain,
			["sc"] = {type = "script"},
			["tr"] = plain,
			["ts"] = plain,
			["lit"] = plain,
		})
	end
	
	function export.show(frame)
		local args = get_args(frame)
		local check = frame.args["check"]
		return export.show_terminfo({
			lang = args[1],
			sc = args["sc"],
			track_sc = true,
			term = args[2] or mw.title.getCurrentTitle().namespace == 10 and "term" or nil,
			alt = args["alt"],
			id = args["id"],
			genders = args[3],
			tr = args["tr"],
			ts = args["ts"],
			lit = args["lit"],
			interwiki = frame.args["interwiki"],
		}, check and check ~= "")
	end
end

-- Implements {{trans-top}} and part of {{trans-top-also}}.
local function top(args, title, navhead)
	local column_width = (args["column-width"] == "wide" or args["column-width"] == "narrow") and "-" .. args["column-width"] or ""
	
	local div = html_create("div")
		:addClass("NavFrame")
		:node(navhead)
		:tag("div")
			:addClass("NavContent")
			:tag("table")
				:addClass("translations")
				:attr("role", "presentation")
				:css("width", "100%")
				:attr("data-gloss", title or "")
				:tag("tr")
					:tag("td")
						:addClass("translations-cell")
						:addClass("multicolumn-list" .. column_width)
						:css("background-color", "#ffffe0")
						:css("vertical-align", "top")
						:css("text-align", "left")
						:attr("colspan", "3")
		:allDone()
	
	local id = args.id or title
	div = id and div:attr("id", "Translations-" .. id) or div
	div = tostring(div)
	
	local categories = {}
	
	if not title and mw.title.getCurrentTitle().namespace == 0 then
		insert(categories, "Translation table header lacks gloss")
	end
	
	local pagename, subpage = load_data("Module:headword/data").page.encoded_pagename
		:gsub("/translations$", "")
	
	if subpage == 1 then
		insert(categories, "Translation subpages")
	end
	
	categories = #categories > 0 and format_categories(
		categories,
		require("Module:languages").getByCode("en"),
		nil,
		pagename
	) or ""
	
	return (div:gsub("</td></tr></table></div></div>$", "")) .. categories
end

-- Entry point for {{trans-top}}.
do
	local function get_args(frame)
		local plain = {}
		return process_params(frame:getParent().args, {
			[1] = plain,
			["id"] = plain,
			["column-width"] = plain,
		})
	end
	
	function export.top(frame)
		local args = get_args(frame)
		local title = args[1]
		title = title and require("Module:links").remove_links(title)
		return top(args, title, html_create("div")
			:addClass("NavHead")
			:css("text-align", "left")
			:css("cursor", "pointer")
			:wikitext(title or "Translations")
			:allDone()
		)
	end
end

-- Entry point for {{checktrans-top}}.
function export.check_top(frame)
	local args = process_params(frame:getParent().args, {
		[1] = {}
	})
	
	local text = "\n:''The translations below need to be checked and inserted above into the appropriate translation tables. See instructions at " ..
		frame:expandTemplate{
			title = "section link",
			args = {"Wiktionary:Entry layout#Translations"}
		} ..
		".''\n"
	
	local header = html_create("div")
		:addClass("checktrans")
		:wikitext(text)
		:allDone()
		
	local title = "Translations to be checked"
	if args[1] then
		title = title .. "&zwnj;: \"" .. args[1] .. "\""
	end
	
	return tostring(header) .. "\n" .. top(args, title, html_create("div")
		:addClass("NavHead")
		:css("text-align", "left")
		:css("cursor", "pointer")
		:wikitext(title or "Translations")
		:allDone()
	)
end

-- Implements {{trans-bottom}}.
function export.bottom(frame)
	-- Check nothing is being passed as a parameter.
	process_params(frame:getParent().args, {})
	return "</table></div></div>"
end

-- Implements {{trans-see}} and part of {{trans-top-also}}.
local function see(args, see_text)
	local navhead = html_create("div")
		:addClass("NavHead")
		:css("text-align", "left")
		:wikitext(args[1] .. " ")
		:tag("span")
			:css("font-weight", "normal")
			:wikitext("— ")
			:tag("i")
				:wikitext(see_text)
		:allDone()
	local raw_terms = args[2]
	local data = {
		id = args["id"] and "Translations-" .. args["id"]
	}
	
	local terms = {}
	if #raw_terms == 0 then
		insert(raw_terms, args[1])
	end
	
	local plain_link = require("Module:links").plain_link
	for i = 1, #raw_terms do
		data.term = raw_terms[i]
		insert(terms, plain_link(data))
	end
	
	return navhead:wikitext(concat(terms, ",&lrm; "))
end

-- Entry point for {{trans-see}}.
function export.see(frame)
	local args = process_params(frame:getParent().args, {
		[1] = {required = true},
		[2] = {list = true},
		["id"] = {}
	})
	local navhead = see(args, "see ")
	return tostring(html_create("div")
		:addClass("pseudo")
		:addClass("NavFrame")
		:node(navhead)
		:allDone())
end

-- Entry point for {{trans-top-also}}.
do
	local function get_args(frame)
		local plain = {}
		return process_params(frame:getParent().args, {
			[1] = {required = true},
			[2] = {list = true},
			["id"] = plain,
			["column-width"] = plain
		})
	end
	
	function export.top_also(frame)
		local args = get_args(frame)
		local title = args[1]
		title = title and require("Module:links").remove_links(title)
		return top(args, title, see(args, "see also "))
	end
end

-- Implements {{t-needed}}.
function export.needed(frame)
	local args = process_params(frame:getParent().args, {
		[1] = {required = true, type = "language", etym_lang = true, default = "und"},
		[2] = {set = {"usex", "quote"}},
		["nocat"] = {type = "boolean"},
		["sort"] = {}
	})
	local lang, category = args[1], ""
	local span = html_create("span")
		:addClass("trreq")
		:attr("data-lang", lang:getCode())
		:tag("i")
			:wikitext("please add this translation if you can")
		:allDone()
		
	if not args["nocat"] then
		local langname = lang:getCanonicalName()
		local type = args[2]
		if type == "quote" then
			category = format_categories(
				{"Requests for translations of " .. langname .. " quotations"},
				lang,
				args["sort"]
			)
		elseif type == "usex" then
			category = format_categories(
				{"Requests for translations of " .. langname .. " usage examples"},
				lang,
				args["sort"]
			)
		else
			local sort = args["sort"]
			category = format_categories(
				{"Requests for translations into " .. langname},
				require("Module:languages").getByCode("en"),
				sort or nil,
				not sort and (load_data("Module:headword/data").page.encoded_pagename
					:gsub("/translations$", "")) or nil
			)
		end
	end
		
	return tostring(span) .. category
end

-- Implements {{no equivalent translation}}.
function export.no_equivalent(frame)
	local args = process_params(frame:getParent().args, {
		[1] = {required = true, type = "language", etym_lang = true, default = "und"},
		["noend"] = {type = "boolean"},
	})
	
	local text = "no equivalent term in " .. args[1]:getCanonicalName()
	if not args["noend"] then
		text = text .. ", but see"
	end
	
	return tostring(html_create("i")
		:wikitext(text))
end

-- Implements {{no attested translation}}.
function export.no_attested(frame)
	local args = process_params(frame:getParent().args, {
		[1] = {required = true, type = "language", etym_lang = true, default = "und"},
		["noend"] = {type = "boolean"},
	})
	
	local langname = args[1]:getCanonicalName()
	local text = "no [[WT:ATTEST|attested]] term in " .. langname
	local category = ""
	
	if not args["noend"] then
		text = text .. ", but see"
		category = format_categories(
			{langname .. " unattested translations"},
			require("Module:languages").getByCode("en"),
			sort or nil,
			(load_data("Module:headword/data").page.encoded_pagename
				:gsub("/translations$", ""))
		)
	end
	
	return tostring(html_create("i")
		:wikitext(text)) .. category
end

-- Implements {{not used}}.
function export.not_used(frame)
	local args = process_params(frame:getParent().args, {
		[1] = {required = true, type = "language", etym_lang = true, default = "und"},
		[2] = {},
	})
	return tostring(html_create("i")
		:wikitext((args[2] or "not used") .. " in " .. args[1]:getCanonicalName()))
end

return export
