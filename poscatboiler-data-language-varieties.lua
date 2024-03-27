local raw_categories = {}
local raw_handlers = {}

local m_languages = require("Module:languages")
local m_table = require("Module:table")
local parse_utilities_module = "Module:parse utilities"
local labels_module = "Module:labels"
local labels_utilities_module = "Module:labels/utilities"
local rsplit = mw.text.split

local function track(page)
	-- [[Special:WhatLinksHere/Template:tracking/poscatboiler/languages/PAGE]]
	return require("Module:debug/track")("poscatboiler/language-varieties/" .. page)
end

-- This module handles lect/variety categories of all sorts, e.g. regional lect categories such as
-- [[:Category:American English]] and [[:Category:Provençal]]; temporal lect categories such as
-- [[:Category:Early Modern English]]; sociolect categories such as [[:Category:Polari]]; and umbrella categories of the
-- form e.g. [[:Category:Varieties of English]] and [[:Category:Regional French]].

-- FIXME: Eliminate the word "dialect" here and in the {{auto cat}} parameter in favor of "lect" or "variety".


-----------------------------------------------------------------------------
--                                                                         --
--                              RAW CATEGORIES                             --
--                                                                         --
-----------------------------------------------------------------------------


raw_categories["Language varieties"] = {
	description = "Categories that group terms in varieties of various languages (regional, temporal, sociolectal, etc.).",
	additional = "{{{umbrella_meta_msg}}}",
	parents = {
		"Fundamental",
	},
}

raw_categories["Regionalisms"] = {
	description = "Categories that group terms in regional varieties of various languages.",
	additional = "{{{umbrella_meta_msg}}}",
	parents = {
		"Fundamental",
		"Language varieties",
	},
}


-----------------------------------------------------------------------------
--                                                                         --
--                                RAW HANDLERS                             --
--                                                                         --
-----------------------------------------------------------------------------


local function split_on_comma(term)
	if term:find(",%s") then
		return require(parse_utilities_module).split_on_comma(term)
	else
		return rsplit(term, ",")
	end
end

local function ucfirst(text)
	return mw.getContentLanguage():ucfirst(text)
end

local function lcfirst(text)
	return mw.getContentLanguage():lcfirst(text)
end


-- Handle categories such as [[:Category:Varieties of French]] and [[:Category:Varieties of Ancient Greek]].
table.insert(raw_handlers, function(data)
	local langname = data.category:match("^Varieties of (.*)$")
	if langname then
		local lang = require("Module:languages").getByCanonicalName(langname)
		if lang then
			return {
				lang = lang:getCode(),
				description = "Categories containing terms in varieties of " .. lang:makeCategoryLink() .. " (regional, temporal, sociolectal, etc.).",
				parents = {
					"{{{langcat}}}",
					{name = "Language varieties", sort = langname},
				},
				breadcrumb = "Varieties",
			}
		end
	end
end)


-- Handle categories such as [[:Category:Regional French]] and [[:Category:Regional Ancient Greek]].
table.insert(raw_handlers, function(data)
	local langname = data.category:match("^Regional (.*)$")
	if langname then
		local lang = require("Module:languages").getByCanonicalName(langname)
		if lang then
			return {
				lang = lang:getCode(),
				description = "Categories containing terms in regional varieties of " .. lang:makeCategoryLink() .. ".",
				additional = "This category sometimes also directly contains terms that are uncategorized regionalisms: such terms should be recategorized by the particular regional variety they belong to, or categorized as dialectal.",
				parents = {
					"Varieties of {{{langname}}}",
					{name = "Regionalisms", sort = langname},
				},
				breadcrumb = "Regional",
			}
		end
	end
end)


-- Fancy version of ine() (if-not-empty). Converts empty string to nil, but also strips leading/trailing space.
local function ine(arg)
	if not arg then return nil end
	arg = mw.text.trim(arg)
	if arg == "" then return nil end
	return arg
end


local function infer_region_from_lang(lang, pagename)
	-- Try to figure out the region (used as the default breadcrumb and region description) from the language. If the
	-- language name is an etymology-only language, try to derive a region based on a parent etymology-only or full
	-- language. For example, if the pagename is '[[:Category:British English]]', the language is 'en-GB' (British English)
	-- and the same as the pagename, but we'd like to return a region 'British'. This is also called in cases where the
	-- language is explicitly given but we need to infer the region from the parent language; e.g.
	-- [[:Category:Lucerne Alemmanic German]] is a type of High Alemannic German but we want to infer 'Lucerne' based on
	-- the parent 'Alemannic German'. If this doesn't work and the language name has a space in it, we try using
	-- progressively smaller suffixes of the language. For example, for [[:Category:Walser German]]', the language is
	-- 'wae' (Walser German), but the parent is 'Highest Alemannic German', whose parent is 'Alemannic German' (a full
	-- language), and just "German" is nowhere in the parent-child relationships but found as a suffix in the parent
	-- language. Another such case is with [[:Category:Ionic Greek]], whose parent is 'Ancient Greek'.
	local langname = lang:getCanonicalName()
	local lang_to_check = lang
	if ucfirst(langname) == pagename then
		lang_to_check = lang_to_check:getParent()
	end
	-- First check against the language name and progressively smaller suffixes; then repeat for any parents (of etymology
	-- languages). If the language name is the same as the page name, we need to start with the parent; otherwise we will
	-- always match against a suffix, but that's not what we want.
	while lang_to_check do
		local suffix = lang_to_check:getCanonicalName()
		while true do
			region = pagename:match("^(.*) " .. require("Module:pattern utilities").pattern_escape(suffix) .. "$")
			if region then
				return region
			end
			suffix = suffix:match("^.- (.*)$")
			if not suffix then
				break
			end
		end
		lang_to_check = lang_to_check:getParent()
	end

	return nil
end


-- Modeled after splitLabelLang() in [[Module:auto cat]]. Try to split off a maximally long language (full or
-- etymology-only) on the right, and return the resulting language object and the region preceding it. We need to
-- check the maximally long language because of cases like 'English' vs 'Middle English' and 'Chinese Pidgin English';
-- [[:Category:Late Middle English]] should split as 'Late' and 'Middle English', not as 'Late Middle' and 'English'.
local function split_region_lang(pagename)
	local getByCanonicalName = require("Module:languages").getByCanonicalName
	local canonical_name
	local lang
	local region

	-- Try the entire title as a language; if not, chop off a word on the left and repeat.
	local words = mw.text.split(pagename, " ")
	for i = 1, #words do
		canonical_name = table.concat(words, " ", i, #words)
		lang = getByCanonicalName(canonical_name, nil, "allow etym", "allow family")
		if not lang then
			-- Some languages have lowercase-initial names e.g. 'the BMAC substrate', but the category begins with an
			-- uppercase letter.
			lang = getByCanonicalName(lcfirst(canonical_name), nil, "allow etym", "allow family")
		end
		if lang then
			if i == 1 then
				region = nil
			else
				region = table.concat(words, " ", 1, i - 1)
			end
			break
		end
	end

	if not region and lang then
		-- The pagename is the same as a language name. Try to infer the region from the parent. See comment at function.
		region = infer_region_from_lang(lang, pagename)
	end

	return lang, region
end


local function scrape_category_for_auto_cat_args(cat)
	local cat_page = mw.title.new("Category:" .. cat)
	if cat_page then
		local contents = cat_page:getContent()
		if contents then
			for name, args in require("Module:template parser").findTemplates(contents) do
				if name == "auto cat" then
					return args
				end
			end
		end
	end
	return nil
end


-- To avoid the need to scrape every category, we keep a list of those categories that satisfy the following:
-- (a) They are a dialect category;
-- (b) They occur as the parent category of some other dialect category;
-- (c) They are not the name of a known language (including etymology-only languages) or contain a known language as a
--     suffix.
-- Condition (c) is necessary because we automatically scrape categories that have a language suffix, since they're
-- likely to be dialect categories.
local dialect_parent_cats_to_scrape = m_table.listToSet {
	"Assyrian",
	"Babylonian",
	"Limburgan-Ripuarian transitional dialects",
	"North Sea Germanic",
	"Ripuarian Franconian",
}

-- Handle dialect categories such as [[:Category:New Zealand English]], [[:Category:Late Middle English]],
-- [[:Category:Arbëresh Albanian]], [[:Category:Provençal]] or arbitrarily-named categories like
-- [[:Category:Issime Walser]]. We currently require that dialect=1 is specified to the call to {{auto cat}} to avoid
-- overfiring. However, if called from inside, we are processing the breadcrumb for the parent (or conceivably the
-- child) of a dialect category, and won't have any params set, so we can't rely on dialect=1. In that case, only fire
-- if the category is or ends in the name of a full or etymology-only language, and scrape the category's call to
-- {{auto cat}} to get the appropriate params. This means that nonstandardly-named categories like
-- [[:Category:Issime Walser]] can't be parents of other dialect categories. To work around this, either we have to
-- relax the code below to operate on all raw categories (not necessarily a good idea), or we rename the
-- nonstandardly-named categories (e.g. in the case above, to [[:Category:Issime Walser German]], since Walser German
-- is a recognized etymology-only language).
--
-- NOTE: We are able to handle categories for etymology-only families (currently only [[:Category:Middle Iranian]] and
-- [[:Category:Old Iranian]]) and for etymology-only substrate languages (e.g. [[:Category:The BMAC substrate]]).
-- There is some special "family" code for the former.
local function dialect_handler(category, raw_args, called_from_inside)
	-- Get the full language to return in the settings.
	local function get_returnable_lang(lang)
		if lang:hasType("family") then
			return "und"
		else
			return lang:getNonEtymologicalCode()
		end
	end

	-- Return the default parent cat for the given language and category. If the language and category are the same, we're
	-- dealing with the overall cat for an etymology-only language, so use the category of the parent language; otherwise
	-- we're dealing with a subcategory of a regular or etymology-only language (e.g. [[:Category:Issime Walser]], a
	-- subcategory of [[:Category:Walser German]]), so use the language's category itself. If the resulting language is an
	-- etymology-only language or a family, the parent category is that language or family's category, which for
	-- etymology-only languages is named the same as the etymology-only language, and for families is named "FAMILY
	-- languages"; otherwise, use "Regional LANG" as the category unless `noreg` is given, in which case we use
	-- "Varieties of LANG".
	local function get_default_parent_cat(lang, pagename, noreg)
		if lang:getCode():find("^qsb%-") then
			-- substrate
			return "Substrate languages"
		end
		local lang_for_cat
		if ucfirst(lang:getCanonicalName()) == pagename then
			lang_for_cat = lang:getParent()
			if not lang_for_cat then
				error(("Category '%s' has a name the same as a full language; you probably need to explicitly specify a different language using |lang="):format(pagename))
			end
		else
			lang_for_cat = lang
		end
		if lang_for_cat:hasType("etymology-only") or lang_for_cat:hasType("family") then
			return lang_for_cat:getCategoryName()
		elseif noreg then
			return "Varieties of " .. lang_for_cat:getCanonicalName()
		else
			return "Regional " .. lang_for_cat:getCanonicalName()
		end
	end

	-- Try to figure out if this variety is extinct or reconstructed, if type= not given.
	local function determine_lect_type(lang, default_parent)
		if category:find("^Proto%-") or lang:getCanonicalName():find("^Proto%-") or lang:hasType("reconstructed") then
			-- Is it reconstructed?
			return "reconstructed"
		end
		if lang:getCode():find("^qsb%-") then
			-- Substrate.
			return "unattested"
		end
		if lang:hasType("full") then
			-- If a full language, scrape the {{auto cat}} call and check for extinct=1.
			local parent_args = scrape_category_for_auto_cat_args(lang:getCategoryName())
			if parent_args and ine(parent_args.extinct) and require("Module:yesno")(parent_args.extinct, false) then
				return "extinct"
			end
		end
		-- Otherwise, call the dialect handler recursively for the parent category. This is correct e.g. for
		-- things like subvarieties of Classical Persian, where the lang itself (Persian) isn't extinct but the
		-- parent category refers to an extinct variety. If the dialect handler fails to return a type, it's because
		-- the parent category doesn't exist or isn't defined using {{auto cat}}, and doesn't have a language as a
		-- suffix. In that case, if we're dealing with an etymology-only language, check the parent language. Finally,
		-- fall back to returning "extant" if all else fails.
		local parent_type
		if default_parent then
			_, parent_type = dialect_handler(default_parent, nil, true)
		end
		if parent_type then
			return parent_type
		end
		local parent_lang = lang:getParent()
		if parent_lang then
			return determine_lect_type(parent_lang, nil)
		end
		return "extant"
	end

	if called_from_inside then
		-- Avoid infinite loops from wrongly processing non-lect categories. We have a check around line 344 below
		-- for categories whose {{auto cat}} doesn't say dialect=1, but we still need the following in case of
		-- non-existent categories we're being asked to process (e.g. [[:Category:User bcc]] ->
		-- [[:Category:Southern Balochi]] (nonexistent) -> [[:Category:Regional Baluchi]] (nonexistent), which
		-- causes an infinite loop without the check below.
		if category:find("^Regional ") or category:find("^Varieties of ") or category:find("^Rhymes:") then
			return nil
		end

		-- If called from inside we won't have any params available. See comment above about this. We scrape the category
		-- page's call to {{auto cat}} to get the appropriate params, and if that fails, we currently fall back to defaults
		-- based on the name of the category. Since the call from inside is only to get the parent category and breadcrumb,
		-- these defaults actually work in most cases but not all; e.g. in the chain [[:Category:Regional Yoruba]] ->
		-- [[:Category:Central Yoruba]] -> [[:Category:Ekiti Yoruba]] -> [[:Category:Akurẹ Yoruba]], if we are forced to use
		-- default values, we will produce the right parent for [[:Category:Central Yoruba]] but not for
		-- [[:Category:Ekiti Yoruba]], where the default parent would be [[:Category:Regional Yoruba]] instead of the correct
		-- [[:Category:Central Yoruba]].
		local lang, breadcrumb = split_region_lang(category)
		if lang or dialect_parent_cats_to_scrape[category] then
			raw_args = scrape_category_for_auto_cat_args(category)
			if raw_args and not ine(raw_args.dialect) then
				-- We are scraping something like [[:Category:American Sign Language]] that ends in a valid language but is not
				-- a dialect.
				return nil
			end
			if not raw_args then
				if not lang then
					-- We were instructed to scrape by virtue of `dialect_parent_cats_to_scrape`, but couldn't scrape
					-- anything.
					return nil
				end
				-- If we can't parse the scraped {{auto cat}} spec, return default values. This helps e.g. in converting
				-- from the old {{dialectboiler}} template and generally when adding new varieties.
				track("dialect")
				local default_parent = get_default_parent_cat(lang, category)
				return {
					-- FIXME, allow etymological codes here
					lang = get_returnable_lang(lang),
					description = "Foo",
					parents = {default_parent},
					breadcrumb = breadcrumb or lang:getCanonicalName(),
					umbrella = false,
					can_be_empty = true,
				}, determine_lect_type(lang, default_parent)
			end
		else
			return nil
		end
	end

	if not called_from_inside and not ine(raw_args.dialect) then
		return nil
	end

	local params = {
		[1] = {},
		dialect = {type = "boolean"},
		lang = {},
		verb = {},
		prep = {},
		def = {},
		fulldef = {},
		addl = {},
		nolink = {type = "boolean"},
		noreg = {type = "boolean"}, -- don't make the default parent be "Regional LANG"; instead, "Varieties of LANG"
		type = {}, -- "extinct", "extant", "reconstructed", "unattested", "constructed"
		cat = {},
		othercat = {}, -- comma-separated
		country = {}, -- comma-separated
		wp = {},
		wikidata = {},
		breadcrumb = {},
		pagename = {}, -- for testing or demonstration
	}

	local args = require("Module:parameters").process(raw_args, params)

	local allowed_type_values = {"extinct", "extant", "reconstructed", "unattested", "constructed"}
	if args.type and not m_table.contains(allowed_type_values, args.type) then
		error(("Unrecognized value '%s' for type=; should be one of %s"):format(
			args.type, table.concat(allowed_type_values, ", ")))
	end
	local lang, breadcrumb, regiondesc, langname
	local region
	local pagename = args.pagename or category
	if not args.lang then
		lang, breadcrumb = split_region_lang(pagename)
		if not lang then
			error(("lang= not given and unable to parse language from category '%s'"):format(pagename))
		end
		langname = lang:getCanonicalName()
		regiondesc = breadcrumb
	else
		lang = m_languages.getByCode(args.lang, "lang", "allow etym")
		langname = lang:getCanonicalName()
		if pagename == ucfirst(langname) then
			-- breadcrumb and regiondesc should stay nil; breadcrumb will get pagename as a default, and the lack of regiondesc
			-- will cause an error to be thrown unless the user gave it explicitly or specified def=
		else
			breadcrumb = pagename:match("^(.*) " .. require("Module:pattern utilities").pattern_escape(langname) .. "$")
			if not breadcrumb then
				-- Try to infer the region from the parent. See comment at function.
				breadcrumb = infer_region_from_lang(lang, pagename)
			end
			regiondesc = breadcrumb
		end
	end
	if args[1] then
		regiondesc = args[1]
	elseif not regiondesc and not args.def and not args.fulldef then
		-- We need regiondesc for the description unless def= or fulldef= is given, which overrides the part that needs it.
		error(("1= (region) not given and unable to infer region from category '%s' given language name '%s'"):
			format(pagename, langname))
	end
	-- If no breadcrumb, this often happens when the langname and pagename are the same (happens only with etym-only
	-- languages), and the parent category is set below to the non-etym parent, so the breadcrumb should show the language
	-- name (or equivalently, the pagename). If the langname and pagename are different, we should fall back to the
	-- pagename. E.g. for Singlish, lang=en is specified and we can't infer a breadcrumb because the dialect name doesn't
	-- end in "English"; in this case we want the breadcrumb to show "Singlish".
	breadcrumb = args.breadcrumb or breadcrumb or pagename

	local topright
	local topright_parts = {}
	-- Insert Wikipedia article `article` for Wikimedia language `wmcode` into `topright_parts`, avoiding duplication.
	local function insert_wikipedia_article(wmcode, article)
		m_table.insertIfNot(topright_parts, ("{{wp%s%s}}"):format(
			wmcode == "en" and "" or "|lang=" .. wmcode,
			article == pagename and "" or "|" .. article
		))
	end

	if args.wp or args.wikidata then
		if args.wp then
			for _, article in ipairs(split_on_comma(args.wp)) do
				local foreign_wiki
				if article:find(":[^ ]") then
					local actual_article
					foreign_wiki, actual_article = article:match("^([a-z][a-z][a-z-]*):([^ ].*)$")
					if actual_article then
						article = actual_article
					end
				end
				if article == "+" then
					article = pagename
				elseif article == "-" then
					article = nil
				else
					article = require("Module:yesno")(article, article)
					if article == true then
						article = pagename
					end
				end
				if article then
					insert_wikipedia_article(foreign_wiki or "en", article)
				end
			end
		end
		if args.wikidata then
			if not mw.wikibase then
				error(("Unable to retrieve data from Wikidata ID's '%s'; `mw.wikibase` not defined"):format(args.wikidata))
			end
			local wikipedia_langs = require(labels_module).get_langs_to_extract_wikipedia_articles_from_wikidata(lang)
			local ids = rsplit(args.wikidata, "%s*,%s*")
			for _, wmcode in ipairs(wikipedia_langs) do
				for _, id in ipairs(ids) do
					local article = mw.wikibase.sitelink(id, wmcode .. "wiki")
					if article then
						insert_wikipedia_article(wmcode, article)
					end
				end
			end
		end
	elseif pagename == ucfirst(langname) then
		local topright_parts = {}
		local wikipedia_langs = require(labels_module).get_langs_to_extract_wikipedia_articles_from_wikidata(lang)
		for _, wmcode in ipairs(wikipedia_langs) do
			local article = lang:getWikipediaArticle("no category fallback", wmcode .. "wiki")
			if article then
				insert_wikipedia_article(wmcode, article)
			end
		end
	end
	if #topright_parts > 0 then
		topright = table.concat(topright_parts)
	end

	local additional = args.addl

	local function append_addl(addl_text)
		if not addl_text then
			return
		end
		if additional then
			additional = additional .. "\n\n" .. addl_text
		else
			additional = addl_text
		end
	end

	local parents = {}
	local langname_for_desc
	local etymcodes = {}
	local function make_code(code)
		return ("<code>%s</code>"):format(code)
	end
	if lang:hasType("etymology-only") and ucfirst(langname) == pagename then
		langname_for_desc = lang:getParentName()
		local langcode = lang:getCode()
		table.insert(etymcodes, make_code(langcode))
		-- Find all alias codes for the etymology-only language.
		-- FIXME: There should be a better/easier way of doing this.
		local ety_code_to_name = mw.loadData("Module:etymology languages/code to canonical name")
		for code, canon_name in pairs(ety_code_to_name) do
			if canon_name == langname and code ~= langcode then
				table.insert(etymcodes, make_code(code))
			end
		end
		local addl_etym_codes = ("[[Module:etymology_languages/data|Etymology-only language]] code: %s."):format(
			m_table.serialCommaJoin(etymcodes, {conj = "or"}))
		append_addl(addl_etym_codes)
	else
		langname_for_desc = langname
	end

	local regional_cat_labels, plain_cat_labels
	local full_lang
	local m_labels_utilities = require(labels_utilities_module)
	if lang:hasType("language") then
		full_lang = lang:getNonEtymological()
		local regional_component = category:match("^(.-) " ..
			require("Module:pattern utilities").pattern_escape(full_lang:getCanonicalName()) .. "$")
		if regional_component then
			regional_cat_labels = m_labels_utilities.find_labels_for_category(regional_component,
				"regional", full_lang)
		end
	end
	plain_cat_labels = m_labels_utilities.find_labels_for_category(category, "plain", full_lang, "check all langs")

	local all_labels
	if regional_cat_labels and plain_cat_labels then
		all_labels = regional_cat_labels
		for k, v in pairs(plain_cat_labels) do
			all_labels[k] = v
		end
	else
		all_labels = regional_cat_labels or plain_cat_labels
	end
	local labels_msg
	if all_labels then
		append_addl(m_labels_utilities.format_labels_categorizing(all_labels, nil, full_lang))
	end

	local lang_en = m_languages.getByCode("en", true)

	local countries
	if args.country then
		countries = split_on_comma(args.country)
	end

	local orig_regiondesc = regiondesc -- for country computation below
	if regiondesc then
		if regiondesc:find("<country>") then
			if not countries then
				error(("Can't specify <country> in region description '%s' when country= not given"):format(regiondesc))
			end
			-- Link the countries individually before calling serialCommaJoin(), which inserts HTML.
			local linked_countries = {}
			for _, country in ipairs(countries) do
				-- don't try to link if HTML or = sign found in country
				if not country:find("[<=]") then
					country = require("Module:links").full_link { lang = lang_en, term = country }
				end
				table.insert(linked_countries, country)
			end
			linked_countries = m_table.serialCommaJoin(linked_countries)
			regiondesc = regiondesc:gsub("<country>", require("Module:pattern utilities").replacement_escape(linked_countries))
		elseif not args.nolink and not regiondesc:find("[<=]") then
			-- even if nolink not given, don't try to link if HTML or = sign found in regiondesc, otherwise we're likely to get
			-- an error
			regiondesc = require("Module:links").full_link { lang = lang_en, term = regiondesc }
		end
	end

	local description = args.fulldef and args.fulldef .. "." or args.def and ("Terms or senses in %s."):format(args.def) or
		("Terms or senses in %s as %s%s %s."):format(
			langname_for_desc, args.verb or "spoken",
			args.prep == "-" and "" or " " .. (args.prep or "in"), regiondesc)

	default_parent = args.cat or get_default_parent_cat(lang, pagename, args.noreg)
	table.insert(parents, default_parent)
	if args.othercat then
		for _, cat in ipairs(split_on_comma(args.othercat)) do
			if not cat:find("^Category:") then
				cat = "Category:" .. cat
			end
			table.insert(parents, cat)
		end
	end
	local countries = countries or {orig_regiondesc}
	for _, country in ipairs(countries) do
		if not country:find("[<=]") then
			country = require("Module:links").remove_links(country)
			local cat = "Category:Languages of " .. country
			local cat_page = mw.title.new(cat)
			if cat_page and cat_page.exists then
				table.insert(parents, cat)
			end
		end
	end

	-- Try to figure out if this variety is extinct or reconstructed, if type= not given.
	local lect_type = args.type
	if not lect_type then
		lect_type = determine_lect_type(lang, default_parent)
	end
	local function prefix_addl(addl_text)
		if additional then
			additional = addl_text .. "\n\n" .. additional
		else
			additional = addl_text
		end
	end
	if lect_type == "extinct" then
		prefix_addl("This language variety is [[extinct language|extinct]].")
		table.insert(parents, "Category:All extinct languages")
	elseif lect_type == "reconstructed" then
		prefix_addl("This language variety is [[reconstructed language|reconstructed]].")
		table.insert(parents, "Category:Reconstructed languages")
	elseif lect_type == "unattested" then
		prefix_addl("This language variety is {{w|unattested language|unattested}}.")
		table.insert(parents, "Category:Unattested languages")
	elseif lect_type == "constructed" then
		prefix_addl("This language variety is [[constructed language|constructed]].")
		table.insert(parents, "Category:Constructed languages")
	end

	track("dialect")
	return {
		-- FIXME, allow etymological codes here
		lang = get_returnable_lang(lang),
		topright = topright,
		description = description,
		additional = additional,
		parents = parents,
		breadcrumb = {name = breadcrumb, nocap = true},
		umbrella = false,
		can_be_empty = true,
	}, lect_type
end


-- Actual handler for dialect categories. See dialect_handler() above.
table.insert(raw_handlers, function(data)
	local settings, _ = dialect_handler(data.category, data.args, data.called_from_inside)
	return settings, not not settings
end)


return {RAW_CATEGORIES = raw_categories, RAW_HANDLERS = raw_handlers}
