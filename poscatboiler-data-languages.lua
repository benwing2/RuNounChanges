local raw_categories = {}
local raw_handlers = {}

local m_languages = require("Module:languages")
local m_sc_getByCode = require("Module:scripts").getByCode
local m_table = require("Module:table")
local parse_utilities_module = "Module:parse utilities"
local rsplit = mw.text.split

local Hang = m_sc_getByCode("Hang")
local Hani = m_sc_getByCode("Hani")
local Hira = m_sc_getByCode("Hira")
local Hrkt = m_sc_getByCode("Hrkt")
local Kana = m_sc_getByCode("Kana")

local function track(page)
	-- [[Special:WhatLinksHere/Template:tracking/poscatboiler/languages/PAGE]]
	return require("Module:debug/track")("poscatboiler/languages/" .. page)
end

-- This handles language categories of the form e.g. [[Category:French language]] and
-- [[:Category:British Sign Language]]; variant umbrella categories of the form e.g.
-- [[:Category:Varieties of English]]; regional variant umbrella categories of the form
-- e.g. [[Category:Regional French]]; and dialectal variant categories such as
-- [[Category:American English]] and [[:Category:Provençal]].


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

raw_categories["All languages"] = {
	intro = "{{sisterlinks|Category:Languages}}\n[[File:Languages world map-transparent background.svg|thumb|right|250px|Rough world map of language families]]",
	description = "This category contains the categories for every language on Wiktionary.",
	additional = "Not all languages that Wiktionary recognises may have a category here yet. There are many that have " ..
	"not yet received any attention from editors, mainly because not all Wiktionary users know about every single " ..
	"language. See [[Wiktionary:List of languages]] for a full list.",
	parents = {
		"Fundamental",
	},
}

raw_categories["All extinct languages"] = {
	description = "This category contains the categories for every [[extinct language]] on Wiktionary.",
	additional = "Do not confuse this category with [[:Category:Extinct languages]], which is an umbrella category for the names of extinct languages in specific other languages (e.g. {{m+|de|Langobardisch}} for the ancient [[Lombardic]] language).",
	parents = {
		"All languages",
	},
}


raw_categories["Languages by country"] = {
	intro = "{{commonscat|Languages by continent}}",
	description = "Categories that group languages by country.",
	additional = "{{{umbrella_meta_msg}}}",
	parents = {
		"All languages",
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

local function makeCategoryLink(object)
	return "[[:Category:" .. object:getCategoryName() .. "|" .. object:getCanonicalName() .. "]]"
end

local function ucfirst(text)
	return mw.getContentLanguage():ucfirst(text)
end

local function lcfirst(text)
	return mw.getContentLanguage():lcfirst(text)
end

local function linkbox(lang, setwiki, setwikt, setsister, entryname)
	local wiktionarylinks = "''None.''"
	
	local canonicalName = lang:getCanonicalName()
	local wikimediaLanguages = lang:getWikimediaLanguages()
	local nameWithLanguage = lang:getCategoryName("nocap")
	local categoryName = lang:getCategoryName()
	local wikipediaArticle = setwiki or lang:getWikipediaArticle()
	setsister = setsister and ucfirst(setsister) or nil
	
	if setwikt then
		track("setwikt")
		if setwikt == "-" then
			track("setwikt/hyphen")
		end
	end
	
	if setwikt ~= "-" and wikimediaLanguages and wikimediaLanguages[1] then
		wiktionarylinks = {}
		
		for _, wikimedialang in ipairs(wikimediaLanguages) do
			table.insert(wiktionarylinks,
				(wikimedialang:getCanonicalName() ~= canonicalName and "(''" .. wikimedialang:getCanonicalName() .. "'') " or "") ..
				"'''[[:" .. wikimedialang:getCode() .. ":|" .. wikimedialang:getCode() .. ".wiktionary.org]]'''")
		end
		
		wiktionarylinks = table.concat(wiktionarylinks, "<br/>")
	end
	
	local plural = wikimediaLanguages[2] and "s" or ""
	
	return table.concat{
[=[<div style="clear: right; border: solid #aaa 1px; margin: 1 1 1 1; background: #f9f9f9; width: 270px; padding: 5px; margin: 5px; text-align: left; float: right">
<div style="text-align: center; margin-bottom: 10px; margin-top: 5px">''']=], nameWithLanguage, [=['''</div>

{| style="font-size: 90%; background: #f9f9f9;"
|-
| style="vertical-align: middle; height: 35px; width: 35px;" | [[File:Wiktionary-logo-v2.svg|35px|none|Wiktionary]]
|| '']=], nameWithLanguage, [=[ edition]=], plural, [=[ of Wiktionary''
|-
| colspan="2" style="padding-left: 10px; border-bottom: 1px solid lightgray;" | ]=], wiktionarylinks, [=[

|-
| style="vertical-align: middle; height: 35px" | [[File:Wikipedia-logo.png|35px|none|Wikipedia]]
|| ''Wikipedia article about ]=], nameWithLanguage, [=[''
|-
| colspan="2" style="padding-left: 10px; border-bottom: 1px solid lightgray;" | ]=], (setwiki == "-" and "''None.''" or "'''[[w:" .. wikipediaArticle .. "|" .. wikipediaArticle .. "]]'''"), [=[

|-
| style="vertical-align: middle; height: 35px" | [[File:Wikimedia-logo.svg|35px|none|Wikimedia Commons]]
|| ''Links related to ]=], nameWithLanguage, [=[ in sister projects at Wikimedia Commons''
|-
| colspan="2" style="padding-left: 10px; border-bottom: 1px solid lightgray;" | ]=], (setsister == "-" and "''None.''" or "'''[[commons:Category:" .. (setsister or categoryName) .. "|" .. (setsister or categoryName) .. "]]'''"), [=[

|-
| style="vertical-align: middle; height: 35px" | [[File:Crystal kfind.png|35px|none|Considerations]]
|| ]=], nameWithLanguage, [=[ considerations
|-
| colspan="2" style="padding-left: 10px; border-bottom: 1px solid lightgray;" | '''[[Wiktionary:About ]=], canonicalName, [=[]]'''<br>'''[[:Category:]=], canonicalName, [=[ reference templates|Reference templates]] ({{PAGESINCAT:]=], canonicalName, [=[ reference templates}})'''<br>'''[[Appendix:]=], canonicalName, [=[ bibliography|Bibliography]]'''
|-
| style="vertical-align: middle; height: 35px" | [[File:Open book nae 02.svg|35px|none|Entry]]
|| ]=], nameWithLanguage, [=[ entry
|-
| colspan="2" style="padding-left: 10px;" | ''']=], require("Module:links").full_link({lang = m_languages.getByCode("en"), term = entryname or canonicalName}), [=['''
|}
</div>]=]
}
end

local function edit_link(title, text)
	return '<span class="plainlinks">['
		.. tostring(mw.uri.fullUrl(title, { action = "edit" }))
		.. ' ' .. text .. ']</span>'
end

-- Should perhaps use wiki syntax.
local function infobox(lang)
	local ret = {}
	
	table.insert(ret, '<table class="wikitable language-category-info"')
	
	if type(lang.getRawData) == "function" then
		local raw_data = lang:getRawData()
		if raw_data then
			local replacements = {
				[1] = "canonical-name",
				[2] = "wikidata-item",
				[3] = "family",
			}
			local function replacer(letter1, letter2)
				return letter1:lower() .. "-" .. letter2:lower()
			end
			-- For each key in the language data modules, returns a descriptive
			-- kebab-case version (containing ASCII lowercase words separated
			-- by hyphens).
			local function kebab_case(key)
				key = replacements[key] or key
				key = key:gsub("(%l)(%u)", replacer):gsub("(%l)_(%l)", replacer)
				return key
			end
			local function html_attribute_encode(str)
				str = mw.text.jsonEncode(str)
					:gsub('"', "&quot;")
					-- & in attributes is automatically escaped.
					-- :gsub("&", "&amp;")
					:gsub("<", "&lt;")
					:gsub(">", "&gt;")
				return str
			end
			pcall(function ()
				table.insert(ret, ' data-code="' .. lang:getCode() .. '"')
				for k, v in m_table.sortedPairs(lang:getRawData()) do
					table.insert(ret, " data-" .. kebab_case(k)
						.. '="'
						.. html_attribute_encode(v)
						.. '"')
				end
			end)
		end
	end
	table.insert(ret, '>\n')
	table.insert(ret, '<tr class="language-category-data">\n<th colspan="2">'
		.. edit_link("Module:" .. m_languages.getDataModuleName(lang:getCode()),
			"Edit language data")
		.. "</th>\n</tr>\n")
	table.insert(ret, "<tr>\n<th>Canonical name</th><td>" .. lang:getCanonicalName() .. "</td>\n</tr>\n")

	local otherNames = lang:getOtherNames(true)
	if otherNames then
		local names = {}
		
		for _, name in ipairs(otherNames) do
			table.insert(names, "<li>" .. name .. "</li>")
		end
		
		if #names > 0 then
			table.insert(ret, "<tr>\n<th>Other names</th><td><ul>" .. table.concat(names, "\n") .. "</ul></td>\n</tr>\n")
		end
	end
	
	local aliases = lang:getAliases()
	if aliases then
		local names = {}
		
		for _, name in ipairs(aliases) do
			table.insert(names, "<li>" .. name .. "</li>")
		end
		
		if #names > 0 then
			table.insert(ret, "<tr>\n<th>Aliases</th><td><ul>" .. table.concat(names, "\n") .. "</ul></td>\n</tr>\n")
		end
	end

	local varieties = lang:getVarieties()
	if varieties then
		local names = {}
		
		for _, name in ipairs(varieties) do
			if type(name) == "string" then
				table.insert(names, "<li>" .. name .. "</li>")
			else
				assert(type(name) == "table")
				local first_var
				local subvars = {}
				for i, var in ipairs(name) do
					if i == 1 then
						first_var = var
					else
						table.insert(subvars, "<li>" .. var .. "</li>")
					end
				end
				if #subvars > 0 then
					table.insert(names, "<li><dl><dt>" .. first_var .. "</dt>\n<dd><ul>" .. table.concat(subvars, "\n") .. "</ul></dd></dl></li>")
				elseif first_var then
					table.insert(names, "<li>" .. first_var .. "</li>")
				end
			end
		end
		
		if #names > 0 then
			table.insert(ret, "<tr>\n<th>Varieties</th><td><ul>" .. table.concat(names, "\n") .. "</ul></td>\n</tr>\n")
		end
	end

	table.insert(ret, "<tr>\n<th>[[Wiktionary:Languages|Language code]]</th><td><code>" .. lang:getCode() .. "</code></td>\n</tr>\n")
	table.insert(ret, "<tr>\n<th>[[Wiktionary:Families|Language family]]</th>\n")
	
	local fam = lang:getFamily()
	local famCode = fam and fam:getCode()
	
	if not fam then
		table.insert(ret, "<td>unclassified</td>")
	elseif famCode == "qfa-iso" then
		table.insert(ret, "<td>[[:Category:Language isolates|language isolate]]</td>")
	elseif famCode == "qfa-mix" then
		table.insert(ret, "<td>[[:Category:Mixed languages|mixed language]]</td>")
	elseif famCode == "sgn" then
		table.insert(ret, "<td>[[:Category:Sign languages|sign language]]</td>")
	elseif famCode == "crp" then
		table.insert(ret, "<td>[[:Category:Creole or pidgin languages|creole or pidgin]]</td>")
	elseif famCode == "art" then
		table.insert(ret, "<td>[[:Category:Constructed languages|constructed language]]</td>")
	else
		table.insert(ret, "<td>" .. makeCategoryLink(fam) .. "</td>")
	end
	
	table.insert(ret, "\n</tr>\n<tr>\n<th>Ancestors</th>\n")
	
	local ancestors, ancestorChain = lang:getAncestors(), lang:getAncestorChain()
	if ancestors[2] then
		local ancestorList = {}
		
		for i, anc in ipairs(ancestors) do
			ancestorList[i] = "<li>" .. makeCategoryLink(anc) .. "</li>"
		end
		
		table.insert(ret, "<td><ul>\n" .. table.concat(ancestorList, "\n") .. "</ul></td>\n")
	elseif ancestorChain[1] then
		table.insert(ret, "<td><ul>\n")
		
		local chain = {}
		
		for i, anc in ipairs(ancestorChain) do
			chain[i] = "<li>" .. makeCategoryLink(anc) .. "</li>"
		end
		
		table.insert(ret, table.concat(chain, "\n<ul>\n"))
		
		for _, _ in ipairs(chain) do
			table.insert(ret, "</ul>")
		end
		
		table.insert(ret, "</td>\n")
	else
		table.insert(ret, "<td>unknown</td>\n")
	end
	
	table.insert(ret, "</tr>\n")
	
	local scripts = lang:getScripts()
	
	if scripts[1] then
		local script_text = {}
		
		local function makeScriptLine(sc)
			local code = sc:getCode()
			local url = tostring(mw.uri.fullUrl('Special:Search', {
				search = 'contentmodel:css insource:"' .. code
					.. '" insource:/\\.' .. code .. '/',
				ns8 = '1'
			}))
			return makeCategoryLink(sc)
				.. ' (<span class="plainlinks" title="Search for stylesheets referencing this script">[' .. url .. ' <code>' .. code .. '</code>]</span>)'
		end
		
		local function add_Hrkt(text)
			table.insert(text, "<li>" .. makeScriptLine(Hrkt))
			table.insert(text, "<ul>")
			table.insert(text, "<li>" .. makeScriptLine(Hira) .. "</li>")
			table.insert(text, "<li>" .. makeScriptLine(Kana) .. "</li>")
			table.insert(text, "</ul>")
			table.insert(text, "</li>")
		end
		
		for _, sc in ipairs(scripts) do
			local text = {}
			local code = sc:getCode()
			
			if code == "Hrkt" then
				add_Hrkt(text)
			else
				table.insert(text, "<li>" .. makeScriptLine(sc))
				if code == "Jpan" then
					table.insert(text, "<ul>")
					table.insert(text, "<li>" .. makeScriptLine(Hani) .. "</li>")
					add_Hrkt(text)
					table.insert(text, "</ul>")
				elseif code == "Kore" then
					table.insert(text, "<ul>")
					table.insert(text, "<li>" .. makeScriptLine(Hang) .. "</li>")
					table.insert(text, "<li>" .. makeScriptLine(Hani) .. "</li>")
					table.insert(text, "</ul>")
				end
				table.insert(text, "</li>")
			end
			
			table.insert(script_text, table.concat(text, "\n"))
		end
		
		table.insert(ret, "<tr>\n<th>[[Wiktionary:Scripts|Scripts]]</th>\n<td><ul>\n" .. table.concat(script_text, "\n") .. "</ul></td>\n</tr>\n")
	else
		table.insert(ret, "<tr>\n<th>[[Wiktionary:Scripts|Scripts]]</th>\n<td>not specified</td>\n</tr>\n")
	end
	
	local function add_module_info(raw_data, heading)
		if raw_data then
			local scripts = lang:getScriptCodes()
			local module_info, n, add = {}, 0, false
			if type(raw_data) == "string" then
				table.insert(module_info,
					("[[Module:%s]]"):format(raw_data))
				add = true
			elseif type(raw_data) == "table" and m_table.size(scripts) == 1 and type(raw_data[scripts[1]]) == "string" then
				table.insert(module_info,
					("[[Module:%s]]"):format(raw_data[scripts[1]]))
				add = true
			elseif type(raw_data) == "table" then
				table.insert(module_info, "<ul>")
				for script, data in m_table.sortedPairs(raw_data) do
					local script_info
					if m_sc_getByCode(script) then
						if type(data) == "string" then
							script_info = ("[[Module:%s]]</li>"):format(data)
						else
							n = n + 1
							script_info = "(none)\n"
						end
						table.insert(module_info, ("<li><code>%s</code>: %s"):format(script, script_info))
					end
				end
				table.insert(module_info, "</ul>")
				if m_table.size(module_info) > 2 and n < (m_table.size(module_info) - 2) then add = true end
			end
			
			if add then
				table.insert(ret, [=[
<tr>
<th>]=] .. heading .. [=[</th>
<td>]=] .. table.concat(module_info) .. [=[</td>
</tr>
]=])
			end
		end
	end
	
	add_module_info(lang._rawData.generate_forms, "Form-generating<br>module")
	add_module_info(lang._rawData.translit, "[[Wiktionary:Transliteration and romanization|Transliteration<br>module]]")
	add_module_info(lang._rawData.display_text, "Display text<br>module")
	add_module_info(lang._rawData.entry_name, "Entry name<br>module")
	add_module_info(lang._rawData.sort_key, "[[sortkey|Sortkey]]<br>module")
	
	local wikidataItem = lang:getWikidataItem()
	if lang:getWikidataItem() and mw.wikibase then
		local URL = mw.wikibase.getEntityUrl(wikidataItem)
		local link
		if URL then
			link = '[' .. URL .. ' ' .. wikidataItem .. ']'
		else
			link = '<span class="error">Invalid Wikidata item: <code>' .. wikidataItem .. '</code></span>'
		end
		table.insert(ret, "<tr><th>Wikidata</th><td>" .. link .. "</td></tr>")
	end
	
	table.insert(ret, "</table>")
	
	return table.concat(ret)
end

local function NavFrame(content, title)
	return '<div class="NavFrame"><div class="NavHead">'
		.. (title or '{{{title}}}') .. '</div>'
		.. '<div class="NavContent" style="text-align: left;">'
		.. content
		.. '</div></div>'
end


local function get_description_intro_additional(lang, countries, extinct, setwiki, setwikt, setsister, entryname)
	local nameWithLanguage = lang:getCategoryName("nocap")
	if lang:getCode() == "und" then
		local description =
			"This is the main category of the '''" .. nameWithLanguage .. "''', represented in Wiktionary by the [[Wiktionary:Languages|code]] '''" .. lang:getCode() .. "'''. " ..
			"This language contains terms in historical writing, whose meaning has not yet been determined by scholars."
		return description, nil, nil
	end
	
	local canonicalName = lang:getCanonicalName()
	
	local intro = linkbox(lang, setwiki, setwikt, setsister, entryname)

	local the_prefix
	if canonicalName:find(" Language$") then
		the_prefix = ""
	else
		the_prefix = "the "
	end
	local description = "This is the main category of " .. the_prefix .. "'''" .. nameWithLanguage .. "'''."

	local country_links = {}
	for _, country in ipairs(countries) do
		if country ~= "UNKNOWN" then
			local country_without_the = country:match("^the (.*)$")
			if country_without_the then
				table.insert(country_links, "the [[" .. country_without_the .. "]]")
			else
				table.insert(country_links, "[[" .. country .. "]]")
			end
		end
	end
	local country_desc
	if #country_links > 0 then
		local country_link_text = m_table.serialCommaJoin(country_links)
		if extinct then
			country_desc = "It is an [[extinct language]] that was formerly spoken in " .. country_link_text .. ".\n\n"
		else
			country_desc = "It is spoken in " .. country_link_text .. ".\n\n"
		end
	elseif extinct then
		country_desc = "It is an [[extinct language]]."
	else
		country_desc = ""
	end

	local add = country_desc .. "Information about " .. canonicalName .. ":\n\n" .. infobox(lang)
	
	if lang:hasType("reconstructed") then
		add = add .. "\n\n" ..
			ucfirst(canonicalName) .. " is a reconstructed language. Its words and roots are not directly attested in any written works, but have been reconstructed through the ''comparative method'', " ..
			"which finds regular similarities between languages that cannot be explained by coincidence or word-borrowing, and extrapolates ancient forms from these similarities.\n\n" ..
			"According to our [[Wiktionary:Criteria for inclusion|criteria for inclusion]], terms in " .. canonicalName ..
			" should '''not''' be present in entries in the main namespace, but may be added to the Reconstruction: namespace."
	elseif lang:hasType("appendix-constructed") then
		add = add .. "\n\n" ..
			ucfirst(canonicalName) .. " is a constructed language that is only in sporadic use. " ..
			"According to our [[Wiktionary:Criteria for inclusion|criteria for inclusion]], terms in " .. canonicalName ..
			" should '''not''' be present in entries in the main namespace, but may be added to the Appendix: namespace. " ..
			"All terms in this language may be available at [[Appendix:" .. ucfirst(canonicalName) .. "]]."
	end
	
	local about = mw.title.new("Wiktionary:About " .. canonicalName)
	
	if about.exists then
		add = add .. "\n\n" ..
			"Please see '''[[Wiktionary:About " .. canonicalName .. "]]''' for information and special considerations for creating " .. nameWithLanguage .. " entries."
	end
	
	local ok, tree_of_descendants = pcall(
		require("Module:family tree").print_children,
		lang:getCode(), {
			protolanguage_under_family = true,
			must_have_descendants = true
		})
	
	if ok then
		if tree_of_descendants then
			add = add .. NavFrame(
				tree_of_descendants,
				"Family tree")
		else
			add = add .. "\n\n" .. ucfirst(lang:getCanonicalName())
				.. " has no descendants or varieties listed in Wiktionary's language data modules."
		end
	else
		mw.log("error while generating tree: " .. tostring(tree_of_descendants))
	end

	return description, intro, add
end


local function get_parents(lang, countries, extinct)
	local canonicalName = lang:getCanonicalName()
	
	local ret = {{name = "All languages", sort = canonicalName}}
	
	local fam = lang:getFamily()
	local famCode = fam and fam:getCode()
	
	-- FIXME: Some of the following categories should be added to this module.
	if not fam then
		table.insert(ret, {name = "Category:Unclassified languages", sort = canonicalName})
	elseif famCode == "qfa-iso" then
		table.insert(ret, {name = "Category:Language isolates", sort = canonicalName})
	elseif famCode == "qfa-mix" then
		table.insert(ret, {name = "Category:Mixed languages", sort = canonicalName})
	elseif famCode == "sgn" then
		table.insert(ret, {name = "Category:All sign languages", sort = canonicalName})
	elseif famCode == "crp" then
		table.insert(ret, {name = "Category:Creole or pidgin languages", sort = canonicalName})
		for _, anc in ipairs(lang:getAncestors()) do
			-- Avoid Haitian Creole being categorised in [[:Category:Haitian Creole-based creole or pidgin languages]], as one of its ancestors is an etymology-only variety of it.
			-- Use that ancestor's ancestors instead.
			if anc:getNonEtymologicalCode() == lang:getCode() then
				for _, anc_extra in ipairs(anc:getAncestors()) do
					table.insert(ret, {name = "Category:" .. ucfirst(anc_extra:getNonEtymologicalName()) .. "-based creole or pidgin languages", sort = canonicalName})
				end
			else
				table.insert(ret, {name = "Category:" .. ucfirst(anc:getNonEtymologicalName()) .. "-based creole or pidgin languages", sort = canonicalName})
			end
		end
	elseif famCode == "art" then
		if lang:hasType("appendix-constructed") then
			table.insert(ret, {name = "Category:Appendix-only constructed languages", sort = canonicalName})
		else
			table.insert(ret, {name = "Category:Constructed languages", sort = canonicalName})
		end
		for _, anc in ipairs(lang:getAncestors()) do
			if anc:getNonEtymologicalCode() == lang:getCode() then
				for _, anc_extra in ipairs(anc:getAncestors()) do
					table.insert(ret, {name = "Category:" .. ucfirst(anc_extra:getNonEtymologicalName()) .. "-based constructed languages", sort = canonicalName})
				end
			else
				table.insert(ret, {name = "Category:" .. ucfirst(anc:getNonEtymologicalName()) .. "-based constructed languages", sort = canonicalName})
			end
		end
	else
		table.insert(ret, {name = "Category:" .. fam:getCategoryName(), sort = canonicalName})
		if lang:hasType("reconstructed") then
			table.insert(ret, {name = "Category:Reconstructed languages", sort = (mw.ustring.gsub(canonicalName, "^Proto%-", ""))})
		end
	end
	
	local function add_sc_cat(sc)
		table.insert(ret, {name = "Category:" .. sc:getCategoryName() .. " languages", sort = canonicalName})
	end
	
	local function add_Hrkt()
		add_sc_cat(Hrkt)
		add_sc_cat(Hira)
		add_sc_cat(Kana)
	end
	
	for _, sc in ipairs(lang:getScripts()) do
		if sc:getCode() == "Hrkt" then
			add_Hrkt()
		else
			add_sc_cat(sc)
			if sc:getCode() == "Jpan" then
				add_sc_cat(Hani)
				add_Hrkt()
			elseif sc:getCode() == "Kore" then
				add_sc_cat(Hang)
				add_sc_cat(Hani)
			end
		end
	end
	
	if lang:hasTranslit() then
		table.insert(ret, {name = "Category:Languages with automatic transliteration", sort = canonicalName})
	end
	
	local saw_country = false
	for _, country in ipairs(countries) do
		if country ~= "UNKNOWN" then
			table.insert(ret, {name = "Category:Languages of " .. country, sort = canonicalName})
			saw_country = true
		end
	end

	if extinct then
		table.insert(ret, {name = "Category:All extinct languages", sort = canonicalName})
	end

	if not saw_country then
		table.insert(ret, {name = "Category:Languages not sorted into a country category", sort = canonicalName})
	end

	return ret
end


local function get_children(lang)
	local ret = {}

	-- FIXME: We should work on the children mechanism so it isn't necessary to manually specify these.
	for _, label in ipairs({"appendices", "entry maintenance", "lemmas", "names", "phrases", "rhymes", "symbols", "templates", "terms by etymology", "terms by usage"}) do
		table.insert(ret, {name = label, is_label = true})
	end

	table.insert(ret, {name = "terms derived from {{{langname}}}", is_label = true, lang = false})
	table.insert(ret, {module = "topic cat", args = {code = "{{{langcode}}}", label = "all topics"}, sort = "all topics"})
	table.insert(ret, {name = "Varieties of {{{langname}}}"})
	table.insert(ret, {name = "Requests concerning {{{langname}}}"})
	table.insert(ret, {name = "Category:Rhymes:{{{langname}}}", description = "Lists of {{{langname}}} words by their rhymes."})
	table.insert(ret, {name = "Category:User {{{langcode}}}", description = "Wiktionary users categorized by fluency levels in {{{langname}}}."})
	return ret
end


-- Handle language categories of the form e.g. [[:Category:French language]] and
-- [[:Category:British Sign Language]].
table.insert(raw_handlers, function(data)
	local lang
	local langname = data.category:match("^(.*) language$")
	if langname then
		lang = m_languages.getByCanonicalName(langname)
	elseif data.category:find(" Language$") then
		lang = m_languages.getByCanonicalName(data.category)
	end
	if not lang then
		return nil
	end
	local params = {
		[1] = {list = true},
		["setwiki"] = {},
		["setwikt"] = {},
		["setsister"] = {},
		["entryname"] = {},
		["extinct"] = {type = "boolean"},
	}
	local args = require("Module:parameters").process(data.args, params)
	-- If called from inside, don't require any arguments, as they can't be known
	-- in general and aren't needed just to generate the first parent (used for
	-- breadcrumbs).
	if #args[1] == 0 and not data.called_from_inside then
		-- At least one country must be specified unless the language is constructed (e.g. Esperanto) or reconstructed (e.g. Proto-Indo-European).
		local fam = lang:getFamily()
		if not (lang:hasType("reconstructed") or (fam and fam:getCode() == "art")) then
			error("At least one country (param 1=) must be specified for language '" .. lang:getCanonicalName() .. "' (code '" .. lang:getCode() .. "'). " ..
				"Use the value UNKNOWN if the language's location is truly unknown.")
		end
	end
	local description, intro, additional = "", "", ""
	-- If called from inside the category tree system, it's called when generating
	-- parents or children, and we don't need to generate the description or additional
	-- text (which is very expensive in terms of memory because it calls [[Module:family tree]],
	-- which calls [[Module:languages/data/all]]).
	if not data.called_from_inside then
		description, intro, additional = get_description_intro_additional(
			lang, args[1], args.extinct, args.setwiki, args.setwikt, args.setsister, args.entryname
		)
	end
	return {
		description = description,
		lang = lang:getCode(),
		intro = intro,
		additional = additional,
		breadcrumb = lang:getCanonicalName(),
		parents = get_parents(lang, args[1], args.extinct),
		extra_children = get_children(lang),
		umbrella = false,
		can_be_empty = true,
	}, true
end)


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
			for name, args, _, _ in require("Module:templateparser").findTemplates(contents) do
				if name == "auto cat" or name == "autocat" then
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
			return "unattested"
		end
		if lang:hasType("family") then
			-- FIXME: Correct? I think this can only happen with etymology-only languages with families as parents,
			-- which are substrate or other extinct languages.
			return "extinct"
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
		-- Avoid infinite loops from wrongly processing non-lect categories.
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

	local intro
	if args.wp then
		local intro_parts = {}
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
				table.insert(intro_parts, ("{{wp%s%s}}"):format(article == pagename and "" or "|" .. article,
					foreign_wiki and "|lang=" .. foreign_wiki or ""))
			end
		end
		intro = table.concat(intro_parts)
	elseif pagename == ucfirst(langname) then
		local article = lang:getWikipediaArticle("no category fallback")
		if article then
			if article == pagename then
				intro = "{{wp}}"
			else
				intro = ("{{wp|%s}}"):format(article)
			end
		end
	end

	local additional

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
		local addl_etym_codes = ("[[Module:etymology_languages/data|Etymology-only language]] code: %s"):format(
			m_table.serialCommaJoin(etymcodes, {conj = "or"}))
		if additional then
			additional = additional .. "\n\n" .. addl_etym_codes
		else
			additional = addl_etym_codes
		end
	else
		langname_for_desc = langname
	end
	
	if args.addl then
		if additional then
			additional = additional .. "\n\n" .. args.addl
		else
			additional = args.addl
		end
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
		intro = intro,
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


-- Handle categories such as [[:Category:Languages of Indonesia]].
table.insert(raw_handlers, function(data)
	local country = data.category:match("^Languages of (.*)$")
	if country then
		local params = {
			flagfile = {},
			commonscat = {},
		}

		local intro

		local args = require("Module:parameters").process(data.args, params)
		if args.flagfile ~= "-" then
			local flagfile = args.flagfile and "File:" .. args.flagfile or ("File:Flag of %s.svg"):format(country)
			local flagfile_page = mw.title.new(flagfile)
			if flagfile_page and flagfile_page.file.exists then
				intro = ("[[%s|right|100px|border]]"):format(flagfile)
			elseif args.flagfile then
				error(("Explicit flagfile '%s' doesn't exist"):format(flagfile))
			end
		end

		if args.commonscat then
			local commonscat = require("Module:yesno")(args.commonscat, "+")
			if commonscat == "+" or commonscat == true then
				commonscat = data.category
			end
			if commonscat then
				local commons_intro_text = ("{{commonscat|%s}}"):format(commonscat)
				if intro then
					intro = intro .. "\n" .. commons_intro_text
				else
					intro = commons_intro_text
				end
			end
		end

		if intro then
			intro = intro .. "\n{{-}}"
		end

		local country_no_the = country:match("^the (.*)$")
		local base_country = country_no_the or country
		local country_link
		if country_no_the then
			country_link = ("the [[%s]]"):format(country_no_the)
		else
			country_link = ("[[%s]]"):format(country)
		end

		local parents = {{name = "Languages by country", sort = base_country}}
		local country_cat = ("Category:%s"):format(base_country)
		local country_page = mw.title.new(country_cat)
		if country_page and country_page.exists then
			table.insert(parents, {name = country_cat, sort = "Languages"})
		end

		return {
			intro = intro,
			description = ("Categories for languages of %s (including sublects)."):format(country_link),
			parents = parents,
			breadcrumb = country,
			additional = "{{{umbrella_msg}}}",
		}, true
	end
end)


-- Handle categories such as [[:Category:English-based creole or pidgin languages]].
table.insert(raw_handlers, function(data)
	local langname = data.category:match("(.*)%-based creole or pidgin languages$")
	if langname then
		local lang = require("Module:languages").getByCanonicalName(langname)
		if lang then
			return {
				lang = lang:getCode(),
				description = "Languages which developed as a [[creole]] or [[pidgin]] from " .. lang:makeCategoryLink() .. ".",
				parents = {{name = "Creole or pidgin languages", sort = "*" .. langname}},
				breadcrumb = lang:getCanonicalName() .. "-based",
			}
		end
	end
end)


-- Handle categories such as [[:Category:English-based constructed languages]].
table.insert(raw_handlers, function(data)
	local langname = data.category:match("(.*)%-based constructed languages$")
	if langname then
		local lang = require("Module:languages").getByCanonicalName(langname)
		if lang then
			return {
				lang = lang:getCode(),
				description = "Constructed languages which are based on " .. lang:makeCategoryLink() .. ".",
				parents = {{name = "Constructed languages", sort = "*" .. langname}},
				breadcrumb = lang:getCanonicalName() .. "-based",
			}
		end
	end
end)


return {RAW_CATEGORIES = raw_categories, RAW_HANDLERS = raw_handlers}
