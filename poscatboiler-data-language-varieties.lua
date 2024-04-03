local raw_categories = {}
local raw_handlers = {}

local m_languages = require("Module:languages")
local m_table = require("Module:table")
local parse_utilities_module = "Module:parse utilities"
local pattern_utilities_module = "Module:pattern utilities"
local labels_module = "Module:labels"
local labels_utilities_module = "Module:labels/utilities"
local rsplit = mw.text.split

local function track(page)
	-- [[Special:WhatLinksHere/Template:tracking/poscatboiler/languages/PAGE]]
	return require("Module:debug/track")("poscatboiler/language-varieties/" .. page)
end

local function pattern_escape(pattern)
	return require(pattern_utilities_module).pattern_escape(pattern)
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


-- Get the full language to use e.g. in the settings.
local function get_returnable_lang(lang)
	if lang:hasType("family") then
		return nil
	else
		return lang:getNonEtymological()
	end
end


-- Get the full language code to return in the settings.
local function get_returnable_lang_code(lang)
	if lang:hasType("family") then
		return "und"
	else
		return lang:getNonEtymologicalCode()
	end
end


local memoizing_dialect_handler


local function category_to_lang_name(category)
	local getByCanonicalName = require("Module:languages").getByCanonicalName
	local lang
	lang = getByCanonicalName(category, nil, "allow etym", "allow family")
	if not lang then
		-- Some languages have lowercase-initial names e.g. 'the BMAC substrate', but the category begins with an
		-- uppercase letter.
		lang = getByCanonicalName(lcfirst(category), nil, "allow etym", "allow family")
	end
	return lang
end


-- Given a category (without the "Category:" prefix), look up the page defining the category, find the call to
-- {{auto cat}} (if any), and return a table of its arguments. If the category page doesn't exist or doesn't have
-- an {{auto cat}} invocation, return nil.
local function scrape_category_for_auto_cat_args(cat)
	local cat_page = mw.title.new("Category:" .. cat)
	if cat_page then
		local contents = cat_page:getContent()
		if contents then
			for name, args in require("Module:template parser").findTemplates(contents) do
				-- The template parser automatically handles redirects and canonicalizes them, so uses of {{autocat}}
				-- will also be found.
				if name == "auto cat" then
					return args
				end
			end
		end
	end
	return nil
end


-- Try to figure out if this variety is extinct or reconstructed, if type= not given.
local function determine_lect_type(category, lang, default_parent_cat)
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
	if default_parent_cat then
		_, parent_type = memoizing_dialect_handler(default_parent_cat, nil, true)
	end
	if parent_type then
		return parent_type
	end
	local parent_lang = lang:getParent()
	if parent_lang then
		return determine_lect_type(category, parent_lang, nil)
	end
	return "extant"
end


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
local function infer_region_from_lang(pagename, lang)
	local langname = lang:getCanonicalName()
	local lang_to_check = lang
	if ucfirst(langname) == pagename then
		lang_to_check = lang_to_check:getParent()
	end
	-- First check against the language name and progressively smaller suffixes; then repeat for any parents (of
	-- etymology languages). If the language name is the same as the page name, we need to start with the parent;
	-- otherwise we will always match against a suffix, but that's not what we want.
	while lang_to_check do
		local suffix = lang_to_check:getCanonicalName()
		while true do
			region = pagename:match("^(.*) " .. pattern_escape(suffix) .. "$")
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
	local lang
	local region

	-- Try the entire title as a language; if not, chop off a word on the left and repeat.
	local words = mw.text.split(pagename, " ")
	for i = 1, #words do
		lang = category_to_lang_name(table.concat(words, " ", i, #words))
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
		-- The pagename is the same as a language name. Try to infer the region from the parent. See comment at
		-- function.
		region = infer_region_from_lang(pagename, lang)
	end

	return lang, region
end


-- Return the default parent cat for the given language and category. If the language and category are the same, we're
-- dealing with the overall cat for an etymology-only language, so use the category of the parent language; otherwise
-- we're dealing with a subcategory of a regular or etymology-only language (e.g. [[:Category:Issime Walser]], a
-- subcategory of [[:Category:Walser German]]), so use the language's category itself. If the resulting language is an
-- etymology-only language or a family, the parent category is that language or family's category, which for
-- etymology-only languages is named the same as the etymology-only language, and for families is named
-- "FAMILY languages"; otherwise, use "Regional LANG" as the category unless `noreg` is given, in which case we use
-- "Varieties of LANG".
local function get_default_parent_cat_from_category(category, lang, noreg)
	if lang:getCode():find("^qsb%-") then
		-- substrate
		return "Substrate languages"
	end
	local lang_for_cat
	if ucfirst(lang:getCanonicalName()) == category then
		lang_for_cat = lang:getParent()
		if not lang_for_cat then
			error(("Category '%s' has a name the same as a full language; you probably need to explicitly specify a different language using |lang="):format(category))
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


-- Find the labels that categorize into `category`. Only categories specified using the `regional_categories` and
-- `plain_categories` fields will be returned. `lang` is the language object to use when looking up categories specified
-- using the `regional_categories` field, which append the language onto the specified category prefix. If `lang` is a
-- family or is omitted, no categories specified using `regional_categories` will be returned. Lang-specific modules for
-- all languages will be checked for matching labels that specify `category` as their category using `plain_categories`;
-- this helps e.g. with varieties of Chinese, whose labels are found in [[Module:labels/data/lang/zh]]. The return value
-- is a table in the same format as returned by `find_labels_for_category` in [[Module:labels/utilities]].
local function find_labels_for_category(category, lang)
	local regional_cat_labels, plain_cat_labels
	local full_lang
	local m_labels_utilities = require(labels_utilities_module)
	if lang and lang:hasType("language") then
		full_lang = lang:getNonEtymological()
		local regional_component = category:match("^(.-) " .. pattern_escape(full_lang:getCanonicalName()) .. "$")
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

	return all_labels
end


-- Find the labels for category `category` and language object `lang`. Then filter them down to those that are specified
-- using a lang-specific module and sort them for use in checking properties such as parent and description. We filter
-- down to only lang-specific labels because those specified in a general module (especially
-- [[Module:labels/data/regional]]) won't be able to have proper descriptions and especially parents, which tend to be
-- language-specific. The sort order prioritizes labels that match the category exactly (either through the canonical
-- version or any alias); this is followed by labels that are a prefix of the category (again, either through the
-- canonical version or any alias), so that labels whose categories are specified using `regional_categories` are
-- prioritized. Any other labels are sorted last, so that e.g. if both the label "Alberta" and "Canada" (with alias
-- "Canadian") for lang=en categorize into [[:Category:Canadian English]], we prefer the label "Canada". For cases where
-- e.g. both labels match the category as prefixes, ties are broken by prioritizing the labels found in the
-- lang-specific module whose language matches `lang`.
--
-- Returns two items. The first is a table of all labels categorizing into `category` (subject to the provisos described
-- in `find_labels_for_category()`), in the same format as returned by `find_labels_for_category` in
-- [[Module:labels/utilities]]. (Specifically, the values are objects containing all relevant information on a given
-- label, and the keys are less important.) The second is a list of label objects after filtering and sorting, in the
-- same format as the values in the `all_labels` table. The first return value will be nil if no labels could be found
-- categorizing into `category`, and the second return value will be nil if no labels remain after filtering.
local function get_sorted_labels(category, lang)
	local all_labels = find_labels_for_category(category, lang)
	if not all_labels then
		return nil
	end

	local m_labels = require(labels_module)
	local lang_specific_pattern = "^" .. pattern_escape(m_labels.lang_specific_data_modules_prefix)
	local sorted_labels = {}
	for _, labelobj in pairs(all_labels) do
		if labelobj.module:find(lang_specific_pattern) then
			table.insert(sorted_labels, labelobj)
		end
	end

	local function sort_labelobj(a, b)
		local function matches_exactly(labelobj)
			if labelobj.canonical == category then
				return true
			end
			for _, alias in ipairs(labelobj.aliases) do
				if alias == category then
					return true
				end
			end
			return false
		end

		local function matches_as_prefix(labelobj)
			if category:find("^" .. pattern_escape(labelobj.canonical) .. " ") then
				return true
			end
			for _, alias in ipairs(labelobj.aliases) do
				if category:find("^" .. pattern_escape(alias) .. " ") then
					return true
				end
			end
			return false
		end

		local function tiebreak()
			local a_matches_lang = lang and a.lang:getNonEtymologicalCode() == lang:getNonEtymologicalCode()
			local b_matches_lang = lang and b.lang:getNonEtymologicalCode() == lang:getNonEtymologicalCode()
			if a_matches_lang and not b_matches_lang then
				return true
			elseif b_matches_lang and not a_matches_lang then
				return false
			else
				return a.canonical < b.canonical
			end
		end

		local a_matches_exactly = matches_exactly(a)
		local b_matches_exactly = matches_exactly(b)
		if a_matches_exactly and not b_matches_exactly then
			return true
		elseif b_matches_exactly and not a_matches_exactly then
			return false
		elseif a_matches_exactly and b_matches_exactly then
			return tiebreak()
		end

		local a_matches_as_prefix = matches_as_prefix(a)
		local b_matches_as_prefix = matches_as_prefix(b)
		if a_matches_as_prefix and not b_matches_as_prefix then
			return true
		elseif b_matches_as_prefix and not a_matches_as_prefix then
			return false
		else
			return tiebreak()
		end
	end

	table.sort(sorted_labels, sort_labelobj)
	if #sorted_labels > 0 then
		return all_labels, sorted_labels
	else
		return all_labels, nil
	end
end


-- Find the categories (only of type `regional_categories` and `plain_categories`) that label `label` categorizes into.
-- Return value is nil if the label couldn't be located at all, otherwise a list of categories (which may be empty).
local function get_categories_for_label(label, lang)
	local m_labels = require(labels_module)
	local labret = m_labels.get_label_info { label = label, lang = lang }
	if not labret then
		return nil
	end
	local categories = m_labels.fetch_categories(labret.canonical or label, labret.data, lang, nil, nil,
		{["plain_categories"] = true})
	local reg_cats = m_labels.fetch_categories(labret.canonical or label, labret.data, lang, nil, nil,
		{["regional_categories"] = true})
	if #reg_cats > 0 then
		for _, cat in ipairs(reg_cats) do
			table.insert(categories, cat)
		end
	end
	return categories
end


local function get_default_parent_cat_from_sorted_labels(sorted_labels, category)
	for _, labobj in ipairs(sorted_labels) do
		local parent = labobj.labdata.parent
		if parent then
			if parent == true then
				-- use default parent
				return nil, labobj
			end
			local cats = get_categories_for_label(parent, labobj.lang)
			if not cats then
				error(("Label '%s' for category '%s' (defined in module [[%s]]) specified parent label '%s' but that parent label couldn't be located"):format(
					labobj.canonical, category, labobj.module, parent))
			end
			if #cats > 0 then
				return cats[1], labobj
			end
			-- FIXME: If the parent doesn't specify any categories, should we try the next parent or fall back
			-- to the parent determined through get_default_parent_cat_from_category() (which is what we currently
			-- do)?
			return nil, labobj
		end
	end
	return nil, nil
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
	if called_from_inside then
		-- Avoid infinite loops from wrongly processing non-lect categories. We have a check around line 344 below
		-- for categories whose {{auto cat}} doesn't say dialect=1, but we still need the following in case of
		-- non-existent categories we're being asked to process (e.g. [[:Category:User bcc]] ->
		-- [[:Category:Southern Balochi]] (nonexistent) -> [[:Category:Regional Baluchi]] (nonexistent), which
		-- causes an infinite loop without the check below.
		if category:find("^Regional ") or category:find("^Varieties of ") or category:find("^Rhymes:") then
			return nil
		end

		-- If called from inside we won't have any params available. See comment above about this. We scrape the
		-- category page's call to {{auto cat}} to get the appropriate params, and if that fails, we currently fall back
		-- to defaults based on the name of the category. Since the call from inside is only to get the parent category
		-- and breadcrumb, these defaults actually work in most cases but not all; e.g. in the chain
		-- [[:Category:Regional Yoruba]] -> [[:Category:Central Yoruba]] -> [[:Category:Ekiti Yoruba]] ->
		-- [[:Category:Akurẹ Yoruba]], if we are forced to use default values, we will produce the right parent for
		-- [[:Category:Central Yoruba]] but not for [[:Category:Ekiti Yoruba]], where the default parent would be
		-- [[:Category:Regional Yoruba]] instead of the correct [[:Category:Central Yoruba]].
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
				local default_parent_cat
				local all_labels, sorted_labels = get_sorted_labels(category, lang)
				if sorted_labels then
					default_parent_cat = get_default_parent_cat_from_sorted_labels(sorted_labels, category)
				end
				if not default_parent_cat then
					default_parent_cat = get_default_parent_cat_from_category(category, lang)
				end
				-- NOTE: When called from inside, the description doesn't matter; nor do any parents other than the
				-- first. This is because called_from_inside is only set when computing the breadcrumb trail, which
				-- only needs the language, first parent and breadcrumb.
				return {
					-- FIXME, allow etymological codes here
					lang = get_returnable_lang_code(lang),
					description = "Foo",
					parents = {default_parent_cat},
					breadcrumb = breadcrumb or lang:getCanonicalName(),
					umbrella = false,
					can_be_empty = true,
				}, determine_lect_type(category, lang, default_parent_cat)
			end
		else
			return nil
		end
	end

	if not called_from_inside and not ine(raw_args.dialect) then
		return nil
	end

	-------------------- 1. Process parameters. -------------------

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

	-------------------- 2. Initialize breadcrumb and regiondesc from category. -------------------

	-- They may be overridden later.

	local lang, breadcrumb, regiondesc, langname
	local region
	category = args.pagename or category
	if not args.lang then
		lang, breadcrumb = split_region_lang(category)
		if not lang then
			error(("lang= not given and unable to parse language from category '%s'"):format(category))
		end
		langname = lang:getCanonicalName()
		regiondesc = breadcrumb
	else
		lang = m_languages.getByCode(args.lang, "lang", "allow etym")
		langname = lang:getCanonicalName()
		if category == ucfirst(langname) then
			-- breadcrumb and regiondesc should stay nil; breadcrumb will get `category` as a default, and the lack of
			-- regiondesc will cause an error to be thrown unless the user gave it explicitly or specified def=.
		else
			breadcrumb = category:match("^(.*) " .. pattern_escape(langname) .. "$")
			if not breadcrumb then
				-- Try to infer the region from the parent. See comment at function.
				breadcrumb = infer_region_from_lang(category, lang)
			end
			regiondesc = breadcrumb
		end
	end

	-------------------- 3. Determine labels categorizing into this category. -------------------

	local all_labels, sorted_labels = get_sorted_labels(category, lang)

	-------------------- 4. Determine parent categories and initialize additional properties. -------------------

	-- The first label with a parent is used to fetch additional properties, such as region= and addl=.

	local parents = {}

	local first_parent_cat = args.cat
	local label_with_parent

	local function getprop(prop)
		return args[prop] or label_with_parent and label_with_parent.labdata[prop]
	end

	if not first_parent_cat and sorted_labels then
		first_parent_cat, label_with_parent = get_default_parent_cat_from_sorted_labels(sorted_labels, category)
	end
	if not first_parent_cat then
		first_parent_cat = get_default_parent_cat_from_category(category, lang, getprop("noreg"))
	end

	table.insert(parents, first_parent_cat)

	local othercat = getprop("othercat")
	if othercat and type(othercat) == "string" then
		othercat = split_on_comma(othercat)
	end
	if othercat then
		for _, cat in ipairs(othercat) do
			if not cat:find("^Category:") then
				cat = "Category:" .. cat
			end
			table.insert(parents, cat)
		end
	end

	local countries = getprop("country")
	if countries and type(countries) == "string" then
		countries = split_on_comma(countries)
	end

	-- If no breadcrumb, this often happens when the langname and category are the same (happens only with etym-only
	-- languages), and the parent category is set below to the non-etym parent, so the breadcrumb should show the
	-- language name (or equivalently, the category). If the langname and category are different, we should fall back to
	-- the category. E.g. for Singlish, lang=en is specified and we can't infer a breadcrumb because the dialect name
	-- doesn't end in "English"; in this case we want the breadcrumb to show "Singlish".
	breadcrumb = getprop("breadcrumb") or breadcrumb or category

	if args[1] then
		regiondesc = args[1]
	else
		local regionprop = getprop("region")
		if regionprop then
			regiondesc = regionprop
		end
	end

	countries = countries or {regiondesc}
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

	-------------------- 5. Refine the language to an etymology-only child if possible. -------------------
	
	-- Now that we've determined the parent, we look up the parent hierarchy until we find a category naming an
	-- etymology-only language. If we find one and it's a child of the language we've determined, use it.

	local ancestral_cat = first_parent_cat

	local refined_lang
	while true do
		refined_lang = category_to_lang_name(ancestral_cat)
		if refined_lang then
			break
		end
		local settings, _ = memoizing_dialect_handler(ancestral_cat, nil, true)
		if not settings then
			break
		end
		ancestral_cat = settings.parents[1]
	end

	if refined_lang and refined_lang:hasParent(lang) then
		lang = refined_lang
		langname = lang:getCanonicalName()
	end

	-------------------- 6. Initialize `additional` with user-specified text and info about labels. -------------------

	local additional = getprop("addl")

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

	if all_labels then
		local m_labels_utilities = require(labels_utilities_module)
		append_addl(m_labels_utilities.format_labels_categorizing(all_labels, nil,
			get_returnable_lang(lang)))
	end

	-------------------- 7. Augment `additional` with information about etymology-only codes. -------------------

	local langname_for_desc
	local etymcodes = {}
	local function make_code(code)
		return ("<code>%s</code>"):format(code)
	end
	if lang:hasType("etymology-only") and ucfirst(langname) == category then
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

	-------------------- 8. Try to figure out if this variety is extinct or reconstructed. -------------------

	local lect_type = getprop("type")
	if not lect_type then
		lect_type = determine_lect_type(category, lang, first_parent_cat)
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

	-------------------- 9. Compute `description`. -------------------

	local description

	local fulldef = getprop("fulldef")
	if fulldef then
		description = fulldef .. "."
	end

	if not description then
		local def = getprop("def")
		if def then
			description = ("Terms or senses in %s."):format(def)
		end
	end

	if not description then
		if not regiondesc then
			-- We need regiondesc for the description unless def= or fulldef= is given, which overrides the part that needs it.
			error(("1= (region) not given and unable to infer region from category '%s' given language name '%s'"):
				format(category, langname))
		end

		local lang_en = m_languages.getByCode("en", true)

		local linked_regiondesc = regiondesc
		if linked_regiondesc then
			-- Don't try to link if HTML, = sign, template call or embedded link found in text. Embedded links will
			-- automatically be converted to English links by JavaScript.
			local function linkable(text)
				return not text:find("[<={}%[%]]")
			end
			if linked_regiondesc:find("<country>") then
				if not countries then
					error(("Can't specify <country> in region description '%s' when country= not given"):format(linked_regiondesc))
				end
				-- Link the countries individually before calling serialCommaJoin(), which inserts HTML.
				local linked_countries = {}
				for _, country in ipairs(countries) do
					if linkable(country) then
						country = require("Module:links").full_link { lang = lang_en, term = country }
					end
					table.insert(linked_countries, country)
				end
				linked_countries = m_table.serialCommaJoin(linked_countries)
				linked_regiondesc = linked_regiondesc:gsub("<country>", require(pattern_utilities_module).replacement_escape(linked_countries))
			elseif not getprop("nolink") and linkable(linked_regiondesc) then
				-- Even if nolink not given, don't try to link if HTML or = sign found in linked_regiondesc, otherwise we're
				-- likely to get an error.
				linked_regiondesc = require("Module:links").full_link { lang = lang_en, term = linked_regiondesc }
			end
		end
		local verb = getprop("verb") or "spoken"
		local prep = getprop("prep")

		description = ("Terms or senses in %s as %s%s %s."):format(
			langname_for_desc, verb, prep == "-" and "" or " " .. (prep or "in"), linked_regiondesc)
	end

	-------------------- 10. Compute the Wikipedia articles that go into `topright`. -------------------

	local topright_parts = {}
	-- Insert Wikipedia article `article` for Wikimedia language `wmcode` into `topright_parts`, avoiding duplication.
	local function insert_wikipedia_article(wmcode, article)
		m_table.insertIfNot(topright_parts, ("{{wp%s%s}}"):format(
			wmcode == "en" and "" or "|lang=" .. wmcode,
			article == category and "" or "|" .. article
		))
	end

	local function insert_wikipedia_articles_for_wikipedia_specs(specs, default)
		for _, article in ipairs(specs) do
			local foreign_wiki
			if article == true then
				article = default
			else
				if article:find(":[^ ]") then
					local actual_article
					foreign_wiki, actual_article = article:match("^([a-z][a-z][a-z-]*):([^ ].*)$")
					if actual_article then
						article = actual_article
					end
				end
				if article == "+" then
					article = default
				elseif article == "-" then
					article = nil
				else
					article = require("Module:yesno")(article, article)
					if article == true then
						article = default
					end
				end
			end
			if article then
				insert_wikipedia_article(foreign_wiki or "en", article)
			end
		end
	end

	local function insert_wikipedia_articles_for_wikidata_specs(specs, lang)
		if not mw.wikibase then
			error(("Unable to retrieve data from Wikidata ID's '%s'; `mw.wikibase` not defined"):format(args.wikidata))
		end
		local wikipedia_langs = require(labels_module).get_langs_to_extract_wikipedia_articles_from_wikidata(lang)
		local ids_without_wmcodes = {}
		local ids_with_wmcodes = {}
		for _, id in ipairs(specs) do
			if id:find(":") then
				table.insert(ids_with_wmcodes, id)
			else
				table.insert(ids_without_wmcodes, id)
			end
		end
		for _, wmcode in ipairs(wikipedia_langs) do
			for _, id in ipairs(ids_without_wmcodes) do
				local article = mw.wikibase.sitelink(id, wmcode .. "wiki")
				if article then
					insert_wikipedia_article(wmcode, article)
				end
			end
		end
		for _, id in ipairs(ids_with_wmcodes) do
			local wmcode, wikidata_id = id:match("^(.-):(.*)$")
			local article = mw.wikibase.sitelink(wikidata_id, wmcode .. "wiki")
			if article then
				insert_wikipedia_article(wmcode, article)
			end
		end
	end

	if args.wp or args.wikidata then
		if args.wp then
			insert_wikipedia_articles_for_wikipedia_specs(split_on_comma(args.wp), category)
		end
		if args.wikidata then
			insert_wikipedia_articles_for_wikidata_specs(rsplit(args.wikidata, "%s*,%s*"), lang)
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
	if #topright_parts == 0 and sorted_labels then
		for _, labobj in pairs(all_labels) do
			local wp_specs = labobj.labdata.Wikipedia
			if wp_specs then
				if type(wp_specs) ~= "table" then
					wp_specs = {wp_specs}
				end
				insert_wikipedia_articles_for_wikipedia_specs(wp_specs, labobj.canonical)
			end
			local wikidata_specs = labobj.labdata.Wikidata
			if wikidata_specs then
				if type(wikidata_specs) ~= "table" then
					wikidata_specs = {wikidata_specs}
				end
				insert_wikipedia_articles_for_wikidata_specs(wikidata_specs, labobj.lang)
			end
		end
	end

	local topright
	if #topright_parts > 0 then
		topright = table.concat(topright_parts)
	end

	-------------------- 11. Return the combined structure of all information. -------------------

	track("dialect")
	return {
		-- FIXME, allow etymological codes here
		lang = get_returnable_lang_code(lang),
		topright = topright,
		description = description,
		additional = additional,
		parents = parents,
		breadcrumb = {name = breadcrumb, nocap = true},
		umbrella = false,
		can_be_empty = true,
	}, lect_type
end


local memoized_responses = {}

memoizing_dialect_handler = function(category, raw_args, called_from_inside)
	local retval = memoized_responses[category]
	if not retval then
		retval = {dialect_handler(category, raw_args, called_from_inside)}
		memoized_responses[category] = retval
	end
	local obj, lect_type = retval[1], retval[2]
	return obj, lect_type
end

-- Actual handler for dialect categories. See dialect_handler() above.
table.insert(raw_handlers, function(data)
	local settings, _ = memoizing_dialect_handler(data.category, data.args, data.called_from_inside)
	return settings, not not settings
end)


return {RAW_CATEGORIES = raw_categories, RAW_HANDLERS = raw_handlers}
