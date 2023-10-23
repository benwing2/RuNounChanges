local raw_categories = {}
local raw_handlers = {}

local m_languages = require("Module:languages")
local m_sc_getByCode = require("Module:scripts").getByCode
local m_table = require("Module:table")

local Hang = m_sc_getByCode("Hang")
local Hani = m_sc_getByCode("Hani")
local Hira = m_sc_getByCode("Hira")
local Hrkt = m_sc_getByCode("Hrkt")
local Kana = m_sc_getByCode("Kana")

local function track(page)
	-- [[Special:WhatLinksHere/Template:tracking/poscatboiler/languages/PAGE]]
	return require("Module:debug/track")("poscatboiler/languages/" .. page)
end

-- This handles language categories of the form e.g. [[:Category:French language]] and
-- [[:Category:British Sign Language]]; categories like [[:Category:Languages of Indonesia]]; categories like
-- [[:Category:English-based creole or pidgin languages]]; and categories like
-- [[:Category:English-based constructed languages]].


-----------------------------------------------------------------------------
--                                                                         --
--                              RAW CATEGORIES                             --
--                                                                         --
-----------------------------------------------------------------------------


raw_categories["All languages"] = {
	topright = "{{commonscat|Languages}}\n[[File:Languages world map-transparent background.svg|thumb|right|250px|Rough world map of language families]]",
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
	topright = "{{commonscat|Languages by continent}}",
	description = "Categories that group languages by country.",
	additional = "{{{umbrella_meta_msg}}}",
	parents = {
		"All languages",
	},
}

raw_categories["Language isolates"] = {
	topright = "{{wikipedia|Language isolate}}\n{{commonscat|Language isolates}}",
	description = "Languages with no known relatives.",
	parents = {
		{name = "Languages by family", sort = "*Isolates"},
		{name = "All language families", sort = "Isolates"},
	},
}


-----------------------------------------------------------------------------
--                                                                         --
--                                RAW HANDLERS                             --
--                                                                         --
-----------------------------------------------------------------------------


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
		table.insert(ret, "<td>" .. fam:makeCategoryLink() .. "</td>")
	end
	
	table.insert(ret, "\n</tr>\n<tr>\n<th>Ancestors</th>\n")
	
	local ancestors, ancestorChain = lang:getAncestors(), lang:getAncestorChain()
	if ancestors[2] then
		local ancestorList = {}
		
		for i, anc in ipairs(ancestors) do
			ancestorList[i] = "<li>" .. anc:makeCategoryLink() .. "</li>"
		end
		
		table.insert(ret, "<td><ul>\n" .. table.concat(ancestorList, "\n") .. "</ul></td>\n")
	elseif ancestorChain[1] then
		table.insert(ret, "<td><ul>\n")
		
		local chain = {}
		
		for i, anc in ipairs(ancestorChain) do
			chain[i] = "<li>" .. anc:makeCategoryLink() .. "</li>"
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


local function get_description_topright_additional(lang, countries, extinct, setwiki, setwikt, setsister, entryname)
	local nameWithLanguage = lang:getCategoryName("nocap")
	if lang:getCode() == "und" then
		local description =
			"This is the main category of the '''" .. nameWithLanguage .. "''', represented in Wiktionary by the [[Wiktionary:Languages|code]] '''" .. lang:getCode() .. "'''. " ..
			"This language contains terms in historical writing, whose meaning has not yet been determined by scholars."
		return description, nil, nil
	end
	
	local canonicalName = lang:getCanonicalName()
	
	local topright = linkbox(lang, setwiki, setwikt, setsister, entryname)

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

	return description, topright, add
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
	local description, topright, additional = "", "", ""
	-- If called from inside the category tree system, it's called when generating
	-- parents or children, and we don't need to generate the description or additional
	-- text (which is very expensive in terms of memory because it calls [[Module:family tree]],
	-- which calls [[Module:languages/data/all]]).
	if not data.called_from_inside then
		description, topright, additional = get_description_topright_additional(
			lang, args[1], args.extinct, args.setwiki, args.setwikt, args.setsister, args.entryname
		)
	end
	return {
		description = description,
		lang = lang:getCode(),
		topright = topright,
		additional = additional,
		breadcrumb = lang:getCanonicalName(),
		parents = get_parents(lang, args[1], args.extinct),
		extra_children = get_children(lang),
		umbrella = false,
		can_be_empty = true,
	}, true
end)


-- Handle categories such as [[:Category:Languages of Indonesia]].
table.insert(raw_handlers, function(data)
	local country = data.category:match("^Languages of (.*)$")
	if country then
		local params = {
			flagfile = {},
			commonscat = {},
			wp = {},
		}

		local topright

		local args = require("Module:parameters").process(data.args, params)
		if args.flagfile ~= "-" then
			local flagfile = args.flagfile and "File:" .. args.flagfile or ("File:Flag of %s.svg"):format(country)
			local flagfile_page = mw.title.new(flagfile)
			if flagfile_page and flagfile_page.file.exists then
				topright = ("[[%s|right|100px|border]]"):format(flagfile)
			elseif args.flagfile then
				error(("Explicit flagfile '%s' doesn't exist"):format(flagfile))
			end
		end

		if args.wp then
			local wp = require("Module:yesno")(args.wp, "+")
			if wp == "+" or wp == true then
				wp = data.category
			end
			if wp then
				local wp_topright = ("{{wikipedia|%s}}"):format(wp)
				if topright then
					topright = topright .. wp_topright
				else
					topright = wp_topright
				end
			end
		end

		if args.commonscat then
			local commonscat = require("Module:yesno")(args.commonscat, "+")
			if commonscat == "+" or commonscat == true then
				commonscat = data.category
			end
			if commonscat then
				local commons_topright = ("{{commonscat|%s}}"):format(commonscat)
				if topright then
					topright = topright .. commons_topright
				else
					topright = commons_topright
				end
			end
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
		local description = (flagdesc or "") .. ("Categories for languages of %s (including sublects)."):format(country_link)

		return {
			topright = topright,
			description = description,
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
