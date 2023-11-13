local export = {}

local m_links = require("Module:links")
local m_langs = require("Module:languages")
local m_strutils = require("Module:string utilities")
local m_debug_track = require("Module:debug/track")
local data = require("Module:place/data")
local table_module = "Module:table"
local put_module = "Module:parse utilities"

local rmatch = mw.ustring.match
local rfind = mw.ustring.find
local rsplit = mw.text.split
local ulen = mw.ustring.len

local cat_data = data.cat_data

local namespace = mw.title.getCurrentTitle().nsText

local force_cat = false -- set to true for testing

--[=[
About the data structures:

* A ''place'' (or ''location'') is a geographic feature (either natural or geopolitical), either on the surface of the
  Earth or elsewhere. Examples of types of natural places are rivers, mountains, seas and moons; examples of types of
  geopolitical places are cities, countries, neighborhoods and roads. Specific places are identified by names (referred
  to as ''toponyms'' or ''placenames'', see below). A given place will often have multiple names, with each language
  that has an opportunity to refer to the place using its own name and some languages having multiple names for the
  same place.
* A ''toponym'' (or ''placename'') is a term that refers to a specific place, i.e. a name for that place. Examples are
  [[Tucson]] (a city in Arizona); [[New York]] (ambiguous; either a city or a state); [[Georgia]] (ambiguous; either a
  state of the US or an independent country in the Caucasus Mountains); [[Paris]] (ambiguous; either the capital of
  France or various small cities and towns in the US); [[Tethys]] (one of the moons of Saturn); [[Pão de Açucar]] (a
  mountain in Rio de Janeiro); [[Willamette]] (a river in Oregon); etc. Some placenames have aliases; when encountered,
  the placenames are mapped to their canonical form before further processing. For example, "US", "U.S.", "USA",
  "U.S.A." and "United States of America" are all canonicalized to "United States" (if identified as a country).
  Similarly, "[[Macedonia]]" and "[[Republic of Macedonia]]" when identified as countries are canonicalized to
  [[North Macedonia]] (but any usage of the term "Macedonia" to refer to other than a country is left as-is). Likewise,
  "[[Mexico]]" identified as a state is canonicalized to [[State of Mexico]] (but any other usage, e.g. as a country or
  city, if left as-is).
* A ''placetype'' is the (or a) type that a toponym belongs to (e.g. "city", "state", "river", "administrative region",
  "[[regional county municipality]]", etc.). Some placetypes themselves are ambiguous; e.g. a [[prefecture]] in the
  context of Japan is similar to a province, but a [[prefecture]] in France is the capital of a [[department]] (which
  is similar to a county). This is generally handled by giving one of the senses a qualifier; e.g. to refer to a
  French prefecture, use the placetype "French prefecture" instead of just "prefecture". Placetypes support aliases,
  like placenames, and the mapping to canonical form happens early on in the processing. For example, "state" can be
  abbreviated as "s"; "administrative region" as "adr"; "regional county municipality" as "rcomun"; etc. Some placetype
  aliases handle alternative spellings rather than abbreviations. For example, "departmental capital" maps to
  "department capital", and "home-rule city" maps to "home rule city".
* A ''placetype qualifier'' is an adjective prepended to the placetype to give additional information about the
  place being described. For example, a given place may be described as a "small city"; logically this is still a city,
  but the qualifier "small" gives additional information about the place. Multiple qualifiers can be stacked, e.g.
  "small affluent beachfront unincorporated community", where "unincorporated community" is a recognized placetype and
  "small", "affluent" and "beachfront" are qualifiers. (As shown here, it may not always be obvious where the qualifiers
  end and the placetype begins.) For the most part, placetype qualifiers do not affect categorization; a "small city"
  is still a city and an "affluent beachfront" unincorporated community is still an unincorporated community, and both
  should still be categorized as such. But some qualifiers do change the categorization. In particular, a "former
  province" is no longer a province and should not be categorized in e.g. [[:Category:Provinces of Italy]], but instead
  in a different set of categories, e.g. [[:Category:Historical political subdivisions]]. There are several terms
  treated as equivalent for this purpose: "abandoned" "ancient", "extinct", "historic(al)", "medi(a)eval" and
  "traditional". Another set of qualifiers that change categorization are "fictional" and "mythological", which cause
  any term using the qualifier to be categorized respectively into [[:Category:Fictional locations]] and
  [[:Category:Mythological locations]].
* A ''holonym'' is a placename that refers to a larger-sized entity that contains the toponym being described. For
  example, "Arizona" and "United States" are holonyms of "Tucson", and "United States' is a holonym of "Arizona".
* A ''place description'' consists of the description of a place, including its placetype or types, any holonyms, and
  any additional raw text needed to properly explain the place in context. Some places have more than one place
  description. For example, [[Vatican City]] is defined both as a city-state in Southern Europe and as an enclave within
  the city of Rome. This is done as follows:
  : {{place|en|city-state|r/Southern Europe|;,|an <<enclave>> within the city of <<city/Rome>>, <<c/Italy>>|cat=Cities in Italy|official=Vatican City State}}.
  The use of two place descriptions allows for proper categorization. Similar things need to be done for places like
  [[Crimea]] that are claimed by two different countries with different definitions and administrative structures.
* A ''full place description'' consists of all the information known about the place. It consists of one or more place
  descriptions, zero or more English glosses (for foreign-language toponyms) and any attached ''extra information''
  such as the capital, largest city, official name or modern name.
* Inside a place description, there are two types of placetypes. The ''entry placetypes'' are the placetypes of the
  place being described, while the ''holonym placetypes'' are the placetypes of the holonyms that the place being
  described is located within. Currently, a given place can have multiple placetypes specified (e.g. [[Normandy]] is
  specified as being simultaneously an administrative region, a historic province and a medieval kingdom) while a given
  holonym can have only one placetype associated with it.

A given place description is defined internally in a table of the following form:
{
  placetypes = {"STRING", "STRING", ...},
  holonyms = {
	{ -- holonym object; see below
	  placetype = "PLACETYPE" or nil,
	  placename = "PLACENAME",
	  langcode = "LANGCODE" or nil,
	  no_display = BOOLEAN,
	  needs_article = BOOLEAN,
	  affix_type = "AFFIX_TYPE" or nil,
	  pluralize_affix = BOOLEAN,
	  suppress_affix = BOOLEAN,
	},
	...
  },
  order = { ORDER_ITEM, ORDER_ITEM, ... }, -- (only for new-style place descriptions),
  joiner = "JOINER STRING" or nil,
  holonyms_by_placetype = {
	HOLONYM_PLACETYPE = {"PLACENAME", "PLACENAME", ...},
	HOLONYM_PLACETYPE = {"PLACENAME", "PLACENAME", ...},
	...
  },
}

Holonym objects have the following fields:
* `placetype`: The canonicalized placetype of specified as e.g. "c/Australia"; nil if no slash is present.
* `placename`: The placename or raw text.
* `langcode`: The language code prefix if specified as e.g. "c/fr:Australie"; otherwise nil.
* `no_display`: If true (holonym prefixed with !), don't display the holonym but use it for categorization.
* `needs_article`: If true, prepend an article if the placename needs one (e.g. "United States").
* `affix_type`: Type of affix to prepend (values "pref" or "Pref") or append (values "suf" or "Suf"). The actual affix
				added is the placetype (capitalized if values "Pref" or "Suf" are given), or its plural if
				`pluralize_affix` is given. Note that some placetypes (e.g. "district" and "department") have inherent
				affixes displayed after (or sometimes before) them.
* `pluralize_affix`: Pluralize any displayed affix. Used for holonyms like "c:pref/Canada,US", which displays as
					 "the countries of Canada and the United States".
* `suppress_affix`: Don't display any affix even if the placetype has an inherent affix. Used for the non-last
					placenames when there are multiple and a suffix is present, and for the non-first placenames when
					there are multiple and a prefix is present.

Note that new-style place descs (those specified as a single argument using <<...>> to denote placetypes, placetype
qualifiers and holonyms) have an additional `order` field to properly capture the raw text surrounding the items
denoted in double angle brackets. The ORDER_ITEM items in the `order` field are objects of the following form:
{
  type = "STRING",
  value = "STRING" or INDEX,
}
Here, the `type` field is one of "raw", "qualifier", "placetype" or "holonym":
* "raw" is used for raw text surrounding <<...>> specs.
* "qualifier" is used for <<...>> specs without slashes in them that consist only of qualifiers (e.g. the spec
  <<former>> in '<<former>> French <<colony>>'). 
* "placetype" is used for <<...>> specs without slashes that do not consist only of qualifiers.
* "holonym" is used for holonyms, i.e. <<...>> specs with a slash in them.
For all types but "holonym", the value is a string, specifying the text in question. For "holonym", the value is a
numeric index into the `holonyms` field.

It should be noted that placetypes and placenames occurring inside the holonyms structure are canonicalized, but
placetypes inside the placetypes structure are as specified by the user. Stripping off of qualifiers and
canonicalization of qualifiers and bare placetypes happens later.

The information under `holonyms_by_placetype` is redundant to the information in holonyms but makes categorization
easier.

For example, the call {{place|en|city|s/Pennsylvania|c/US}} will result in the return value
{
  placetypes = {"city"},
  holonyms = {
	{ placetype = "state", placename = "Pennsylvania" },
	{ placetype = "country", placename = "United States" },
  },
  holonyms_by_placetype = {
	state = {"Pennsylvania"},
	country = {"United States"},
  },
}
Here, the placetype aliases "s" and "c" have been expanded into "state" and "country" respectively, and the placename
alias "US" has been expanded into "United States". PLACETYPES is a list because there may be more than one. For example,
the call {{place|en|city/and/county|s/California}} will result in the return value
{
  placetypes = {"city", "and", "county"},
  holonyms = {
	{ placetype = "state", placename = "California" },
  },
  holonyms_by_placetype = {
	state = {"California"},
  },
}
The value in the key/value pairs is likewise a list; e.g. the call {{place|en|city|s/Kansas|and|s/Missouri}} will return
{
  placetypes = {"city"},
  holonyms = {
	{ placetype = "state", placename = "Kansas" },
	{ placename = "and" },
	{ placetype = "state", placename = "Missouri" },
  },
  holonyms_by_placetype = {
	state = {"Kansas", "Missouri"},
  },
}
]=]

----------- Wikicode utility functions



-- Return a wikilink link {{l|language|text}}
local function link(text, langcode, id)
	if not langcode then
		return text
	end

	return m_links.full_link({term = text, lang = m_langs.getByCode(langcode, true, "allow etym"), id = id}, nil, true)
end


-- Return the category link for a category, given the language code and the name of the category.
local function catlink(lang, text, sort_key)
	return require("Module:utilities").format_categories({lang:getNonEtymologicalCode() .. ":" ..
		data.remove_links_and_html(text)}, lang, sort_key, nil, force_cat or data.force_cat)
end



---------- Basic utility functions



-- Add the page to a tracking "category". To see the pages in the "category",
-- go to [[Template:tracking/place/PAGE]] and click on "What links here".
local function track(page)
	m_debug_track("place/" .. page)
	return true
end


local function ucfirst_all(text)
	if text:find(" ") then
		local parts = rsplit(text, " ", true)
		for i, part in ipairs(parts) do
			parts[i] = m_strutils.ucfirst(part)
		end
		return table.concat(parts, " ")
	else
		return m_strutils.ucfirst(text)
	end
end


local function lc(text)
	return mw.getContentLanguage():lc(text)
end


-- Return the article that is used with a place type. It is fetched from the cat_data
-- table; if that doesn’t exist, "an" is given for words beginning with a vowel
-- and "a" otherwise.
-- If ucfirst == true, the first letter of the article is made upper-case.
local function get_placetype_article(placetype, ucfirst)
	local art

	local pt_data = data.get_equiv_placetype_prop(placetype, function(pt) return cat_data[pt] end)
	if pt_data and pt_data.article then
		art = pt_data.article
	elseif placetype:find("^[aeiou]") then
		art = "an"
	else
		art = "a"
	end

	if ucfirst then
		art = m_strutils.ucfirst(art)
	end

	return art
end


-- Return the correct plural of a placetype, and (if `ucfirst` is given) make the first letter uppercase. We first look
-- up the plural in [[Module:place/data]], falling back to pluralize() in [[Module:string utilities]], which is almost
-- always correct.
local function get_placetype_plural(placetype, ucfirst)
	local pt_data, equiv_placetype_and_qualifier = data.get_equiv_placetype_prop(placetype,
		function(pt) return cat_data[pt] end)
	if pt_data then
		placetype = pt_data.plural or m_strutils.pluralize(equiv_placetype_and_qualifier.placetype)
	else
		placetype = m_strutils.pluralize(placetype)
	end
	if ucfirst then
		return m_strutils.ucfirst(placetype)
	else
		return placetype
	end
end



---------- Argument parsing functions and utilities


-- Split an argument on slash, but not slash occurring inside of HTML tags like </span> or <br />.
local function split_on_slash(arg)
	if arg:find("<") then
		local put = require(put_module)
		-- We implement this by parsing balanced segment runs involving <...>, and splitting on slash in the remainder.
		-- The result is a list of lists, so we have to rejoin the inner lists by concatenating.
		local segments = put.parse_balanced_segment_run(arg, "<", ">")
		local slash_separated_groups = put.split_alternating_runs(segments, "/")
		for i, group in ipairs(slash_separated_groups) do
			slash_separated_groups[i] = table.concat(group)
		end
		return slash_separated_groups
	else
		return rsplit(arg, "/", true)
	end
end


-- Implement "implications", i.e. where the presence of a given holonym causes additional holonym(s) to be added. There
-- are two types of implications, general implications (which apply to both display and categorization) and category
-- implications (which apply only to categorization). `place_descriptions` is a list of place descriptions (see top of
-- file, collectively describing the data passed to {{place}}. `implication_data` is the data used to implement the
-- implications, i.e. a table indexed by holonym placetype, each value of which is a table indexed by holonym place
-- name, each value of which is a list of "PLACETYPE/PLACENAME" holonyms to be added to the end of the list of holonyms.
-- `should_clone` specifies whether to clone a given place desc before modifying it.
local function handle_implications(place_descriptions, implication_data, should_clone)
	for i, desc in ipairs(place_descriptions) do
		if desc.holonyms then
			local imps_to_add = {}

			for _, holonym in ipairs(desc.holonyms) do
				local imp_data = data.get_equiv_placetype_prop(holonym.placetype, function(pt)
					local implication = implication_data[pt] and implication_data[pt][data.remove_links_and_html(holonym.placename)]
					if implication then
						return implication
					end
				end)
				if imp_data then
					table.insert(imps_to_add, imp_data)
				end
			end

			if #imps_to_add > 0 then
				if should_clone and not cloned then
					desc = mw.clone(desc)
					place_descriptions[i] = desc
				end
				for _, imp_data in ipairs(imps_to_add) do
					for _, holonym_to_add in ipairs(imp_data) do
						local split_holonym = split_on_slash(holonym_to_add)
						if #split_holonym ~= 2 then
							error("Invalid holonym in implications: " .. holonym_to_add)
						end
						local holonym_placetype, holonym_placename = unpack(split_holonym)
						local new_holonym = {placetype = holonym_placetype, placename = holonym_placename}
						table.insert(desc.holonyms, new_holonym)
						data.key_holonym_into_place_desc(desc, new_holonym)
					end
				end
			end
		end
	end
end


-- Look up a placename in an alias table, handling links appropriately. If the alias isn't found, return nil.
local function lookup_placename_in_alias_table(placename, aliases)
	-- If the placename is a link, apply the alias inside the link.
	-- This pattern matches both piped and unpiped links. If the link is not
	-- piped, the second capture (linktext) will be empty.
	local link, linktext = rmatch(placename, "^%[%[([^|%]]+)%|?(.-)%]%]$")
	if link then
		if linktext ~= "" then
			local alias = aliases[linktext]
			return alias and "[[" .. link .. "|" .. alias .. "]]" or nil
		else
			local alias = aliases[link]
			return alias and "[[" .. alias .. "]]" or nil
		end
	else
		return aliases[placename]
	end
end


-- If `placename` of type `placetype` is an alias, convert it to its canonical form; otherwise, return unchanged.
local function resolve_placename_aliases(placetype, placename)
	return data.get_equiv_placetype_prop(placetype,
		function(pt) return data.placename_display_aliases[pt] and lookup_placename_in_alias_table(
			placename, data.placename_display_aliases[pt]) end
	) or placename
end


-- Split a holonym placename on commas but don't split on comma+space. This way, we split on
-- "Poland,Belarus,Ukraine" but keep "Tucson, Arizona" together.
local function split_holonym_placename(placename)
	if placename:find(", ") then
		local placenames = rsplit(placename, ",", true)
		local retval = {}
		for i, placename in ipairs(placenames) do
			if i > 1 and placename:find("^ ") then
				retval[#retval] = retval[#retval] .. "," .. placename
			else
				table.insert(retval, placename)
			end
		end
		return retval
	else
		return rsplit(placename, ",", true)
	end
end


-- Split a holonym (e.g. "continent/Europe" or "country/en:Italy" or "in southern" or "r:suf/O'Higgins" or
-- "c/Austria,Germany,Czech Republic") into its components. Return a list of holonym objects (see top of file). Note
-- that if there isn't a slash in the holonym (e.g. "in southern"), the `placetype` field of the holonym will be nil.
-- Placetype aliases (e.g. "r" for "region") and placename aliases (e.g. "US" or "USA" for "United States") will be
-- expanded.
local function split_holonym(raw)
	local no_display, combined_holonym = raw:match("^(!)(.*)$")
	no_display = not not no_display
	combined_holonym = combined_holonym or raw
	local holonym_parts = split_on_slash(combined_holonym)
	if #holonym_parts == 1 then
		-- FIXME, remove this when we've verified there are no cases.
		if rfind(combined_holonym, "^([^%[%]]-):([^ ].*)$") then
			error("Language code in raw-text {{place}} argument no longer supported: " .. raw)
		end
		return {{placename = combined_holonym, no_display = no_display}}
	end

	-- Rejoin further slashes in case of slash in holonym placename, e.g. Admaston/Bromley.
	local placetype = holonym_parts[1]
	local placename = table.concat(holonym_parts, "/", 2)

	-- Check for modifiers after the holonym placetype.
	local split_holonym_placetype = rsplit(placetype, ":", true)
	placetype = split_holonym_placetype[1]
	local affix_type
	if #split_holonym_placetype > 2 then
		error("Saw more than one modifier attached to holonym placetype: " .. raw)
	end
	if #split_holonym_placetype == 2 then
		affix_type = split_holonym_placetype[2]
		if affix_type ~= "pref" and affix_type ~= "Pref" and affix_type ~= "suf" and affix_type ~= "Suf"
			and affix_type ~= "noaff" then
			error(("Unrecognized affix type '%s', should be one of 'pref', 'Pref', 'suf', 'Suf' or 'noaff'"):format(affix_type))
		end
	end

	placetype = data.resolve_placetype_aliases(placetype)
	local holonyms = split_holonym_placename(placename)
	local pluralize_affix = #holonyms > 1
	local affix_holonym_index = (affix_type == "pref" or affix_type == "Pref") and 1 or affix_type == "noaff" and 0 or #holonyms
	for i, placename in ipairs(holonyms) do
		-- Check for langcode before the holonym placename, but don't get tripped up by Wikipedia links, which begin
		-- "[[w:...]]" or "[[wikipedia:]]".
		local langcode, bare_placename = rmatch(placename, "^([^%[%]]-):(.*)$")
		if langcode then
			placename = bare_placename
		end

		holonyms[i] = {
			placetype = placetype,
			placename = resolve_placename_aliases(placetype, placename),
			langcode = langcode,
			affix_type = i == affix_holonym_index and affix_type or nil,
			pluralize_affix = i == affix_holonym_index and pluralize_affix,
			suppress_affix = i ~= affix_holonym_index,
			no_display = no_display,
		}
	end

	return holonyms
end


-- Apply a function to the non-HTML (including <<...>> segments) and non-Wikilink parts of `text`. We need to do
-- this especially so that we correctly handle holonyms (e.g. 'c/Italy') without getting confused by </span> and
-- similar HTML tags. The Wikilink exclusion is a bit less important but may still occur e.g. in links to
-- [[Admaston/Bromley]]. This is based on munge_text() in [[Module:munge text]].
--
-- FIXME: I added this as part of correctly handling embedded HTML in holonyms and placetypes, but I ended up not
-- using this in favor of [[Module:parse utilities]]. Delete if we likely won't need it in the future.
local function process_excluding_html_and_links(text, fn)
	local has_html = text:find("<")
	local has_link = text:find("%[%[")
	if not has_html and not has_link then
		return fn(text)
	end

	local function do_munge(text, pattern, functor)
		local index = 1
		local length = ulen(text)
		local result = ""
		pattern = "(.-)(" .. pattern .. ")"
		while index <= length do
			local first, last, before, match = rfind(text, pattern, index)
			if not first then
				result = result .. functor(mw.ustring.sub(text, index))
				break
			end
			result = result .. functor(before) .. match
			index = last + 1
		end
		return result
	end
	
	local function munge_text_with_html(txt)
		return do_munge(txt, "<[^<>]->", fn)
	end

	if has_link then -- contains wikitext links
		return do_munge(text, "%[%[[^%[%]]-%]%]", has_html and munge_text_with_html or fn)
	else -- HTML tags only
		return munge_text_with_html(text)
	end
end


-- Parse a "new-style" place description, with placetypes and holonyms surrounded by <<...>> amid otherwise raw text.
-- Return value is an object as documented at the top of the file.
local function parse_new_style_place_desc(text)
	local placetypes = {}
	local segments = m_strutils.capturing_split(text, "<<(.-)>>")
	local retval = {holonyms = {}, order = {}}
	for i, segment in ipairs(segments) do
		if i % 2 == 1 then
			table.insert(retval.order, {type = "raw", value = segment})
		elseif segment:find("/") then
			local holonyms = split_holonym(segment)
			for j, holonym in ipairs(holonyms) do
				if j > 1 then
					if not holonym.no_display then
						if j == #holonyms then
							table.insert(retval.order, {type = "raw", value = " and "})
						else
							table.insert(retval.order, {type = "raw", value = ", "})
						end
					end
					-- All but the first in a multi-holonym need an article. For the first one, the article is
					-- specified in the raw text if needed. (Currently, needs_article is only used when displaying the
					-- holonym, so it wouldn't matter when no_display is set, but we set it anyway in case we need it
					-- for something else.)
					holonym.needs_article = true
				end
				table.insert(retval.holonyms, holonym)
				if not holonym.no_display then
					table.insert(retval.order, {type = "holonym", value = #retval.holonyms})
				end
				data.key_holonym_into_place_desc(retval, holonym)
			end
		else
			-- see if the placetype segment is just qualifiers
			local only_qualifiers = true
			local split_segments = rsplit(segment, " ", true)
			for _, split_segment in ipairs(split_segments) do
				if not data.placetype_qualifiers[split_segment] then
					only_qualifiers = false
					break
				end
			end
			table.insert(placetypes, {placetype = segment, only_qualifiers = only_qualifiers})
			if only_qualifiers then
				table.insert(retval.order, {type = "qualifier", value = segment})
			else
				table.insert(retval.order, {type = "placetype", value = segment})
			end
		end
	end

	local final_placetypes = {}
	for i, placetype in ipairs(placetypes) do
		if i > 1 and placetypes[i - 1].only_qualifiers then
			final_placetypes[#final_placetypes] = final_placetypes[#final_placetypes] .. " " .. placetypes[i].placetype
		else
			table.insert(final_placetypes, placetypes[i].placetype)
		end
	end
	retval.placetypes = final_placetypes
	return retval
end

--[=[
Process numeric args (except for the language code in 1=). `numargs` is a list of the numeric arguments passed to
{{place}} starting from 2=. The return value is a list of one or more place description objects, as described in the
long comment at the top of the file.
]=]
local function parse_place_descriptions(numargs)
	local descs = {}
	local this_desc
	-- Index of separate (semicolon-separated) place descriptions within `descs`.
	local desc_index = 1
	-- Index of separate holonyms within a place description. 0 means we've seen no holonyms and have yet to process
	-- the placetypes that precede the holonyms. 1 means we've seen no holonyms but have already processed the
	-- placetypes.
	local holonym_index = 0
	local last_was_new_style = false

	for _, arg in ipairs(numargs) do
		if arg == ";" or arg:find("^;[^ ]") then
			if not this_desc then
				error("Saw semicolon joiner without preceding place description")
			end
			if arg == ";" then
				this_desc.joiner = "; "
			elseif arg == ";;" then
				this_desc.joiner = " "
			else
				local joiner = arg:sub(2)
				if rfind(joiner, "^%a") then
					this_desc.joiner = " " .. joiner .. " "
				else
					this_desc.joiner = joiner .. " "
				end
			end
			desc_index = desc_index + 1
			holonym_index = 0
			last_was_new_style = false
		else
			if arg:find("<<") then
				if holonym_index > 0 then
					desc_index = desc_index + 1
					holonym_index = 0
				end
				this_desc = parse_new_style_place_desc(arg)
				descs[desc_index] = this_desc
				last_was_new_style = true
				holonym_index = holonym_index + 1
			else
				if last_was_new_style then
					error("Old-style arguments cannot directly follow new-style place description")
				end
				last_was_new_style = false
				if holonym_index == 0 then
					local entry_placetypes = split_on_slash(arg)
					this_desc = {placetypes = entry_placetypes, holonyms = {}}
					descs[desc_index] = this_desc
					holonym_index = holonym_index + 1
				else
					local holonyms = split_holonym(arg)
					for j, holonym in ipairs(holonyms) do
						if j > 1 then
						-- All but the first in a multi-holonym need an article. Not for the first one because e.g.
						-- {{place|en|city|s/Arizona|c/United States}} should not display as "a city in Arizona, the
						-- United States". The first holonym given gets an article if needed regardless of our setting
						-- here.
							holonym.needs_article = true
							-- Insert "and" before the last holonym.
							if j == #holonyms then
								this_desc.holonyms[holonym_index] = {
									-- Use the no_display value from the first holonym; it should be the same for all
									-- holonyms.
									placename = "and", no_display = holonyms[1].no_display
								}
								holonym_index = holonym_index + 1
							end
						end
						this_desc.holonyms[holonym_index] = holonym
						data.key_holonym_into_place_desc(this_desc, this_desc.holonyms[holonym_index])
						holonym_index = holonym_index + 1
					end
				end
			end
		end
	end

	handle_implications(descs, data.general_implications, false)

	-- Tracking code. This does nothing but add tracking for seen placetypes and qualifiers. The place will be linked to
	-- [[Template:tracking/place/entry-placetype/PLACETYPE]] for all entry placetypes seen; in addition, if PLACETYPE
	-- has qualifiers (e.g. 'small city'), there will be links for the bare placetype minus qualifiers and separately
	-- for the qualifiers themselves:
	--   [[Special:WhatLinksHere/Template:tracking/place/entry-placetype/BARE_PLACETYPE]]
	--   [[Special:WhatLinksHere/Template:tracking/place/entry-qualifier/QUALIFIER]]
	-- Note that if there are multiple qualifiers, there will be links for each possible split. For example, for
	-- 'small maritime city'), there will be the following links:
	--   [[Special:WhatLinksHere/Template:tracking/place/entry-placetype/small maritime city]]
	--   [[Special:WhatLinksHere/Template:tracking/place/entry-placetype/maritime city]]
	--   [[Special:WhatLinksHere/Template:tracking/place/entry-placetype/city]]
	--   [[Special:WhatLinksHere/Template:tracking/place/entry-qualifier/small]]
	--   [[Special:WhatLinksHere/Template:tracking/place/entry-qualifier/maritime]]
	-- Finally, there are also links for holonym placetypes, e.g. if the holonym 'c/Italy' occurs, there will be the
	-- following link:
	--   [[Special:WhatLinksHere/Template:tracking/place/holonym-placetype/country]]
	for _, desc in ipairs(descs) do
		for _, entry_placetype in ipairs(desc.placetypes) do
			local splits = data.split_qualifiers_from_placetype(entry_placetype, "no canon qualifiers")
			for _, split in ipairs(splits) do
				local prev_qualifier, this_qualifier, bare_placetype = unpack(split)
				track("entry-placetype/" .. bare_placetype)
				if this_qualifier then
					track("entry-qualifier/" .. this_qualifier)
				end
			end
		end
		for _, holonym in ipairs(desc.holonyms) do
			if holonym.placetype then
				track("holonym-placetype/" .. holonym.placetype)
			end
		end
	end

	return descs
end



-------- Definition-generating functions



-- Return a string with the wikilinks to the English translations of the word.
local function get_translations(transl, ids)
	local ret = {}

	for i, t in ipairs(transl) do
		table.insert(ret, link(t, "en", ids[i]))
	end

	return table.concat(ret, ", ")
end


-- Prepend the appropriate article if needed to LINKED_PLACENAME, where PLACENAME
-- is the corresponding unlinked placename and PLACETYPE its placetype.
local function get_holonym_article(placetype, placename, linked_placename)
	placename = data.remove_links_and_html(placename)
	local unlinked_placename = data.remove_links_and_html(linked_placename)
	if unlinked_placename:find("^the ") then
		return nil
	end
	local art = data.get_equiv_placetype_prop(placetype, function(pt) return data.placename_article[pt] and data.placename_article[pt][placename] end)
	if art then
		return art
	end
	art = data.get_equiv_placetype_prop(placetype, function(pt) return cat_data[pt] and cat_data[pt].holonym_article end)
	if art then
		return art
	end
	local universal_res = data.placename_the_re["*"]
	for _, re in ipairs(universal_res) do
		if unlinked_placename:find(re) then
			return "the"
		end
	end
	local matched = data.get_equiv_placetype_prop(placetype, function(pt)
		local res = data.placename_the_re[pt]
		if not res then
			return nil
		end
		for _, re in ipairs(res) do
			if unlinked_placename:find(re) then
				return true
			end
		end
		return nil
	end)
	if matched then
		return "the"
	end
	return nil
end


-- Return the description of a holonym, with an extra article if necessary and in the wikilinked display form if
-- necessary.
--
-- Examples:
-- ({placetype = "country", placename = "United States"}, true, true) returns the template-expanded equivalent of
-- "the {{l|en|United States}}".
-- ({placetype = "region", placename = "O'Higgins", affix_type = "suf"}, false, true) returns the template-expanded
-- equivalent of "{{l|en|O'Higgins}} region".
-- ({placename = "in the southern"}, false, true) returns "in the southern" (without wikilinking because .placetype
-- and .langcode are both nil).
local function get_holonym_description(holonym, needs_article, display_form)
	local output = holonym.placename
	local placetype = holonym.placetype
	local affix_type_pt_data, affix_type, affix, no_affix_strings, pt_equiv_for_affix_type, already_seen_affix

	if display_form and holonym.no_display then
		return ""
	end

	local orig_needs_article = needs_article
	needs_article = needs_article or holonym.needs_article

	if display_form then
		-- Implement display handlers.
		local display_handler = data.get_equiv_placetype_prop(placetype,
			function(pt) return cat_data[pt] and cat_data[pt].display_handler end)
		if display_handler then
			output = display_handler(placetype, output)
		end
		if not holonym.suppress_affix then
			-- Implement adding an affix (prefix or suffix) based on the holonym's placetype. The affix will be
			-- added either if the placetype's cat_data spec says so (by setting 'affix_type'), or if the
			-- user explicitly called for this (e.g. by using 'r:suf/O'Higgins'). Before adding the affix,
			-- however, we check to see if the affix is already present (e.g. the placetype is "district"
			-- and the placename is "Mission District"). If the placetype explicitly calls for adding
			-- an affix, it can override the affix to add (by setting 'affix') and/or override the strings
			-- used for checking if the affix is already presen (by setting 'no_affix_strings').
			affix_type_pt_data, pt_equiv_for_affix_type = data.get_equiv_placetype_prop(placetype,
				function(pt) return cat_data[pt] and cat_data[pt].affix_type and cat_data[pt] end
			)
			if affix_type_pt_data then
				affix_type = affix_type_pt_data.affix_type
				affix = affix_type_pt_data.affix or pt_equiv_for_affix_type.placetype
				no_affix_strings = affix_type_pt_data.no_affix_strings or lc(affix)
			end
			if holonym.affix_type and placetype then
				affix_type = holonym.affix_type
				affix = placetype
				no_affix_strings = lc(affix)
			end
			if affix and holonym.pluralize_affix then
				affix = get_placetype_plural(affix)
			end
			already_seen_affix = no_affix_strings and data.check_already_seen_string(output, no_affix_strings)
		end
		output = link(output, holonym.langcode or placetype and "en" or nil)
		if (affix_type == "suf" or affix_type == "Suf") and not already_seen_affix then
			output = output .. " " .. (affix_type == "Suf" and ucfirst_all(affix) or affix)
		end
	end

	if needs_article then
		local article = get_holonym_article(placetype, holonym.placename, output)
		if article then
			output = article .. " " .. output
		end
	end

	if display_form then
		if (affix_type == "pref" or affix_type == "Pref") and not already_seen_affix then
			output = (affix_type == "Pref" and ucfirst_all(affix) or affix) .. " of " .. output
			if orig_needs_article then
				-- Put the article before the added affix if we're the first holonym in the place description. This is
				-- distinct from the article added above for the holonym itself; cf. "c:pref/United States,Canada" ->
				-- "the countries of the United States and Canada". We need to use the value of `needs_article` passed
				-- in from the function, which indicates whether we're processing the first holonym.
				output = "the " .. output
			end
		end
	end
	return output
end


-- Return the preposition that should be used after `placetype` (e.g. "city >in< France." but
-- "country >of< South America"). The preposition is fetched from the data module, defaulting to "in".
local function get_in_or_of(placetype)
	local preposition = "in"

	local pt_data = data.get_equiv_placetype_prop(placetype, function(pt) return cat_data[pt] end)
	if pt_data and pt_data.preposition then
		preposition = pt_data.preposition
	end

	return preposition
end


-- Return a string that contains the information of how `holonym` (a holonym object; see top of file) should be
-- formatted in the gloss, considering the entry's placetype (specifically, the last placetype if there are more than
-- one, excluding conjunctions and parenthetical items); the holonym preceding it in the template's parameters
-- (`prev_holonym`), and whether it is the first holonym (`first`).
local function get_contextual_holonym_description(entry_placetype, prev_holonym, holonym, first)
	local desc = ""

	-- If holonym.placetype is nil, the holonym is just raw text, e.g. 'in southern'.

	if not holonym.no_display then
		-- First compute the initial delimiter.
		if first then
			if holonym.placetype then
				desc = desc .. " " .. get_in_or_of(entry_placetype) .. " "
			elseif not holonym.placename:find("^,") then
				desc = desc .. " "
			end
		else
			if prev_holonym.placetype and holonym.placename ~= "and" and holonym.placename ~= "in" then
				desc = desc .. ","
			end
	
			if holonym.placetype or not holonym.placename:find("^,") then
				desc = desc .. " "
			end
		end
	end

	return desc .. get_holonym_description(holonym, first, true)
end


-- Get the display form of a placetype by looking it up in `placetype_links` in [[Module:place/data]]. If the placetype
-- is recognized, or is the plural if a recognized placetype, the corresponding linked display form is returned (with
-- plural placetypes displaying as plural but linked to the singular form of the placetype). Otherwise, return nil.
local function get_placetype_display_form(placetype)
	local linked_version = data.placetype_links[placetype]
	if linked_version then
		if linked_version == true then
			return "[[" .. placetype .. "]]"
		elseif linked_version == "w" then
			return "[[w:" .. placetype .. "|" .. placetype .. "]]"
		else
			return linked_version
		end
	end
	local sg_placetype = data.maybe_singularize(placetype)
	if sg_placetype then
		local linked_version = data.placetype_links[sg_placetype]
		if linked_version then
			if linked_version == true then
				return "[[" .. sg_placetype .. "|" .. placetype .. "]]"
			elseif linked_version == "w" then
				return "[[w:" .. sg_placetype .. "|" .. placetype .. "]]"
			else
				-- An explicit display form was specified. It will be singular, so we need to pluralize it to match
				-- the pluralization of the passed-in placetype.
				return m_strutils.pluralize(linked_version)
			end
		end
	end
	
	return nil
end


-- Return the linked description of a placetype. This splits off any qualifiers and displays them separately.
local function get_placetype_description(placetype)
	local splits = data.split_qualifiers_from_placetype(placetype)
	local prefix = ""
	for _, split in ipairs(splits) do
		local prev_qualifier, this_qualifier, bare_placetype = unpack(split)
		if this_qualifier then
			prefix = (prev_qualifier and prev_qualifier .. " " .. this_qualifier or this_qualifier) .. " "
		else
			prefix = ""
		end
		local display_form = get_placetype_display_form(bare_placetype)
		if display_form then
			return prefix .. display_form
		end
		placetype = bare_placetype
	end
	return prefix .. placetype
end


-- Return the linked description of a qualifier (which may be multiple words).
local function get_qualifier_description(qualifier)
	local splits = data.split_qualifiers_from_placetype(qualifier .. " foo")
	local split = splits[#splits]
	local prev_qualifier, this_qualifier, bare_placetype = unpack(split)
	return prev_qualifier and prev_qualifier .. " " .. this_qualifier or this_qualifier
end
	

-- Return a string with extra information that is sometimes added to a
-- definition. This consists of the tag, a whitespace and the value (wikilinked
-- if it language contains a language code; if ucfirst == true, ". " is added
-- before the string and the first character is made upper case.
local function get_extra_info(tag, values, ucfirst, auto_plural, with_colon)
	if not values then
		return ""
	end
	if type(values) ~= "table" then
		values = {values}
	end
	if #values == 0 then
		return ""
	end

	if auto_plural and #values > 1 then
		tag = m_strutils.pluralize(tag)
	end

	if with_colon then
		tag = tag .. ":"
	end

	local linked_values = {}

	for _, value in ipairs(values) do
		-- Check for langcode before the holonym placename, but don't get tripped up by
		-- Wikipedia links, which begin "[[w:...]]" or "[[wikipedia:]]".
		local langcode, holonym_placename = rmatch(value, "^([^%[%]]-):(.*)$")
		if langcode then
			value = link(holonym_placename, langcode)
		else
			value = link(value, "en")
		end
		table.insert(linked_values, value)
	end

	local s = ""

	if ucfirst then
		s = s .. ". " .. m_strutils.ucfirst(tag)
	else
		s = s .. "; " .. tag
	end

	return s .. " " .. require(table_module).serialCommaJoin(linked_values)
end


-- Get the full gloss (English description) of an old-style place description (with separate arguments for the
-- placetype and each holonym).
local function get_old_style_gloss(args, place_desc, with_article, ucfirst)
	-- The placetype used to determine whether "in" or "of" follows is the last placetype if there are
	-- multiple slash-separated placetypes, but ignoring "and", "or" and parenthesized notes
	-- such as "(one of 254)".
	local placetype_for_in_or_of = nil
	local placetypes = place_desc.placetypes
	local function is_and_or(item)
		return item == "and" or item == "or"
	end
	local parts = {}
	local function ins(txt)
		table.insert(parts, txt)
	end
	local function ins_space()
		if #parts > 0 then
			ins(" ")
		end
	end

	local and_or_pos
	for i, placetype in ipairs(placetypes) do
		if is_and_or(placetype) then
			and_or_pos = i
			-- no break here; we want the last in case of more than one
		end
	end

	local remaining_placetype_index
	if and_or_pos then
		track("multiple-placetypes-with-and")
		if and_or_pos == #placetypes then
			error("Conjunctions 'and' and 'or' cannot occur last in a set of slash-separated placetypes: " ..
				table.concat(placetypes, "/"))
		end
		local items = {}
		for i = 1, and_or_pos + 1 do
			local pt = placetypes[i]
			if is_and_or(pt) then
				-- skip
			elseif i > 1 and pt:find("^%(") then
				-- append placetypes beginning with a paren to previous item
				items[#items] = items[#items] .. " " .. pt
			else
				placetype_for_in_or_of = pt
				table.insert(items, get_placetype_description(pt))
			end
		end
		ins(require(table_module).serialCommaJoin(items, {conj = placetypes[and_or_pos]}))
		remaining_placetype_index = and_or_pos + 2
	else
		remaining_placetype_index = 1
	end

	for i = remaining_placetype_index, #placetypes do
		local pt = placetypes[i]
		-- Check for and, or and placetypes beginning with a paren (so that things like
		-- "{{place|en|county/(one of 254)|s/Texas}}" work).
		if data.placetype_is_ignorable(pt) then
			ins_space()
			ins(pt)
		else
			placetype_for_in_or_of = pt
			-- Join multiple placetypes with comma unless placetypes are already
			-- joined with "and". We allow "the" to precede the second placetype
			-- if they're not joined with "and" (so we get "city and county seat of ..."
			-- but "city, the county seat of ...").
			if i > 1 then
				ins(", ")
				local article = get_placetype_article(pt)
				if article ~= "the" and i > remaining_placetype_index then
					-- Track cases where we are comma-separating multiple placetypes without the second one starting
					-- with "the", as they may be mistakes. The occurrence of "the" is usually intentional, e.g.
					-- {{place|zh|municipality/state capital|s/Rio de Janeiro|c/Brazil|t1=Rio de Janeiro}}
					-- for the city of [[Rio de Janeiro]], which displays as "a municipality, the state capital of ...".
					track("multiple-placetypes-without-and-or-the")
				end
				ins(article)
				ins(" ")
			end

			ins(get_placetype_description(pt))
		end
	end

	if args["also"] then
		ins_space()
		ins("and ")
		ins(args["also"])
	end

	if place_desc.holonyms then
		for i, holonym in ipairs(place_desc.holonyms) do
			local first = i == 1
			local prev_desc = first and {} or place_desc.holonyms[i - 1]
			ins(get_contextual_holonym_description(placetype_for_in_or_of, prev_desc, place_desc.holonyms[i], first))
		end
	end

	local gloss = table.concat(parts)

	if with_article then
		gloss = (args["a"] or get_placetype_article(place_desc.placetypes[1], ucfirst)) .. " " .. gloss
	end

	return gloss
end


-- Get the full gloss (English description) of a new-style place description. New-style place descriptions are
-- specified with a single string containing raw text interspersed with placetypes and holonyms surrounded by <<...>>.
local function get_new_style_gloss(args, place_desc, with_article)
	local parts = {}

	if with_article and args["a"] then
		table.insert(parts, args["a"] .. " ")
	end

	for _, order in ipairs(place_desc.order) do
		local segment_type, segment = order.type, order.value
		if segment_type == "raw" then
			table.insert(parts, segment)
		elseif segment_type == "placetype" then
			table.insert(parts, get_placetype_description(segment))
		elseif segment_type == "qualifier" then
			table.insert(parts, get_qualifier_description(segment))
		elseif segment_type == "holonym" then
			table.insert(parts, get_holonym_description(place_desc.holonyms[segment], false, true))
		else
			error("Internal error: Unrecognized segment type '" .. segment_type .. "'")
		end
	end

	return table.concat(parts)
end


-- Return a string with the gloss (the description of the place itself, as opposed to translations). If `ucfirst` is
-- given, the gloss's first letter is made upper case and a period is added to the end. If `drop_extra_info` is given,
-- we don't include "extra info" (modern name, capital, largest city, etc.); this is used when transcluding into
-- another language using {{transclude sense}}.
local function get_gloss(args, descs, ucfirst, drop_extra_info)
	if args.def == "-" then
		return ""
	elseif args.def then
		return args.def
	end

	local glosses = {}
	for n, desc in ipairs(descs) do
		if desc.order then
			table.insert(glosses, get_new_style_gloss(args, desc, n == 1))
		else
			table.insert(glosses, get_old_style_gloss(args, desc, n == 1, ucfirst))
		end
		if desc.joiner then
			table.insert(glosses, desc.joiner)
		end
	end

	local ret = {table.concat(glosses)}

	if not drop_extra_info then
		table.insert(ret, get_extra_info("modern", args["modern"], false, false, false))
		table.insert(ret, get_extra_info("official name", args["official"], ucfirst, "auto plural", "with colon"))
		table.insert(ret, get_extra_info("capital", args["capital"], ucfirst, "auto plural", "with colon"))
		table.insert(ret, get_extra_info("largest city", args["largest city"], ucfirst, "auto plural", "with colon"))
		table.insert(ret, get_extra_info("capital and largest city", args["caplc"], ucfirst, false, "with colon"))
		local placetype = descs[1].placetypes[1]
		if placetype == "county" or placetype == "counties" then
			placetype = "county seat"
		elseif placetype == "parish" or placetype == "parishes" then
			placetype = "parish seat"
		elseif placetype == "borough" or placetype == "boroughs" then
			placetype = "borough seat"
		else
			placetype = "seat"
		end
		table.insert(ret, get_extra_info(placetype, args["seat"], ucfirst, "auto plural", "with colon"))
		table.insert(ret, get_extra_info("shire town", args["shire town"], ucfirst, "auto plural", "with colon"))
	end

	return table.concat(ret)
end


-- Return the definition line.
local function get_def(args, specs, drop_extra_info)
	if #args["t"] > 0 then
		local gloss = get_gloss(args, specs, false, drop_extra_info)
		return get_translations(args["t"], args["tid"]) .. (gloss == "" and "" or " (" .. gloss .. ")")
	else
		return get_gloss(args, specs, true, drop_extra_info)
	end
end



---------- Functions for the category wikicode

--[=[

The code in this section finds the categories to which a given place belongs. The algorithm works off of a place
description (which specifies the entry placetype(s) and holonym(s); see comment at top of file). Iterating over each
entry placetype, it proceeds as follows:
(1) Look up the placetype in the `cat_data`, which comes from [[Module:place/data]]. Note that the entry in `cat_data`
	that specifies the category or categories to add may directly correspond to the entry placetype as specified in the
	place description. For example, if the entry placetype is "small town", the placetype whose data is fetched will be
	"town" since "small" is a recognized qualifier and there is no entry in `cat_data` for "small town". As another
	example, if the entry placetype is "administrative capital", the placetype whose data will be fetched will be
	"capital city" because there's no entry in `cat_data` for "administrative capital" but there is an entry in
	`placetype_equivs` in [[Module:place/data]] that maps "administrative capital" to "capital city" for categorization
	purposes.
(2) The value in `cat_data` is a two-level table. The outer table is indexed by the holonym itself (e.g.
	"country/Brazil") or by "default", and the inner indexed by the holonym's placetype (e.g. "country") or by "itself".
	Note that most frequently, if the outer table is indexed by a holonym, the inner table will be indexed only by
	"itself", while if the outer table is indexed by "default", the inner table will be indexed by one or more holonym
	placetypes, meaning to generate a category for all holonyms of this placetype. But this is not necessarily the case.
(3) Iterate through the holonyms, from left to right, finding the first holonym that matches (in both placetype and
	placename) a key in the outer table. If no holonym matches any key, then if a key "default" exists, use that;
	otherwise, if a key named "fallback" exists, specifying a placetype, use that placetype to fetch a new `cat_data`
	entry, and start over with step (1); otherwise, don't categorize.
(4) Iterate again through the holonyms, from left to right, finding the first holonym whose placetype matches a key in
	the inner table. If no holonym matches any key, then if a key "itself" exists, use that; otherwise, check for a key
	named "fallback" at the top level of the `cat_data` entry and, if found, proceed as in step (3); otherwise don't
	categorize.
(5) The resulting value found is a list of category specs. Each category spec specifies a category to be added. In order
	to understand how category specs are processed, you have to understand the concept of the 'triggering holonym'. This
	is the holonym that matched an inner key in step (4), if any; else, the holonym that matched an outer key in step
	(3), if any; else, there is no triggering holonym. (The only time this happens when there are category specs is
	when the outer key is "default" and the inner key is "itself".)
(6) Iterate through the category specs and construct a category from each one. Each category spec is one of the
	following:
	(a) A string, such as "Seas", "Districts of England" or "Cities in +++". If "+++" is contained in the string, it
		will be substituted with the placename of the triggering holonym. If there is no triggering holonym, an error is
		thrown. This is then prefixed with the language code specified in the first argument to the call to {{place}}.
		For example, if the triggering holonym is "country/Brazil", the category spec is "Cities in +++" and the
		template invocation was {{place|en|...}}, the resulting category will be [[:Category:en:Cities in Brazil]].
	(b) The value 'true'. If there is a triggering holonym, the spec "PLACETYPES in +++" or "PLACETYPES of +++" is
		constructed. (Here, PLACETYPES is the plural of the entry placetype whose cat_data is being used, which is not
		necessarily the same as the entry placetype specified by the user; see the discussion above. The choice of "in"
		or "of" is based on the value of the "preposition" key at the top level of the entry in `cat_data`, defaulting
		to "in".) This spec is then processed as above. If there is no triggering holonym, the simple spec "PLACETYPES"
		is constructed (where PLACETYPES is as above).

For example, consider the following entry in cat_data:
	["municipality"] = {
		preposition = "of",

		...

		["country/Brazil"] = {
			["state"] = {"Municipalities of +++, Brazil", "Municipalities of Brazil"},
			["country"] = {true},
		},

		...
	}

If the user uses a template call {{place|pt|municipality|s/Amazonas|c/Brazil}}, the categories
[[:Category:pt:Municipalities of Amazonas, Brazil]] and [[:Category:pt:Municipalities of Brazil]] will be generated.
This is because the outer key "country/Brazil" matches the second holonym "c/Brazil" (by this point, the alias "c" has
been expanded to "country"), and the inner key "state" matches the first holonym "s/Amazonas", which serves as the
triggering holonym and is used to replace the +++ in the first category spec.

Now imagine the user uses the template call {{place|en|small municipality|c/Brazil}}. There is no entry in `cat_data`
for "small municipality", but "small" is a recognized qualifier, and there is an entry in `cat_data` for "municipality",
so that entry's data is used. Now, the second holonym "c/Brazil" will match the outer key "country/Brazil" as before,
but in this case the second holonym will also match the inner key "country" and will serve as the triggering holonym.
The cat spec 'true' will be expanded to "Municipalities of +++", using the placetype "municipality" corresponding to the
entry in `cat_data` (not the user-specified placetype "small municipality"), and the preposition "of", as specified in
the `cat_data` entry. The +++ will then be expanded to "Brazil" based on the triggering holonym, the language code "en"
will be prepended, and the final category will be [[:Category:en:Municipalities of Brazil]].
]=]


--[=[
Find the appropriate category specs for a given place description; e.g. for the call
{{place|en|city|s/Pennsylvania|c/US}} which results in the place description
{
  placetypes = {"city"},
  holonyms = {
	{placetype = "state", placename = "Pennsylvania"},
	{placetype = "country", "placename" = "United States"},
  },
  holonyms_by_placetype = {
	state = {"Pennsylvania"},
	country = {"United States"},
  }
},
the return value might be be "city", {"Cities in +++, USA"}, {"state", "Pennsylvania"}, "outer"
(i.e. four values are returned; see below). See the comment at the top of the section for a description of category
specs and the overall algorithm.

More specifically, given the following arguments:
(1) the entry placetype (or equivalent) used to look up the category data in cat_data;
(2) the value of cat_data[placetype] for this placetype;
(3) the full place description as documented at the top of the file (used only for its holonyms);
(4) an optional overriding holonym to use, in place of iterating through the holonyms;
(5) if an overriding holonym was specified, either "inner" or "outer" to indicate which loop to override;
find the holonyms that match the outer-level and inner-level keys in the `cat_data` entry
according to the algorithm described in the top-of-section comment, and return the resulting
category specs. Four values are actually returned:

CATEGORY_SPECS, ENTRY_PLACETYPE, TRIGGERING_HOLONYM, INNER_OR_OUTER

where

(1) CATEGORY_SPECS is a list of category specs as described above;
(2) ENTRY_PLACETYPE is the placetype that should be used to construct categories when 'true'
	is one of the returned category specs (normally the same as the `entry_placetype` passed
	in, but will be different when a "fallback" key exists and is used);
(3) TRIGGERING_HOLONYM is the triggering holonym (see the comment at the top of the section), or nil if there was no
	triggering holonym;
(4) INNER_OR_OUTER is "inner" if the triggering holonym matched in the inner loop (whether or not a
	holonym matched the outer loop), or "outer" if the triggering holonym matched in the outer loop
	only, or nil if no triggering holonym.
]=]
local function find_cat_specs(entry_placetype, entry_placetype_data, place_desc, overriding_holonym, override_inner_outer)
	local inner_data = nil
	local outer_triggering_holonym

	local function fetch_inner_data(holonym_to_match)
		local holonym_placetype = holonym_to_match.placetype
		local holonym_placename = holonym_to_match.placename
		holonym_placename = data.resolve_cat_aliases(holonym_placetype, holonym_placename)
		local inner_data = data.get_equiv_placetype_prop(holonym_placetype,
			function(pt) return entry_placetype_data[(pt or "") .. "/" .. holonym_placename] end)
		if inner_data then
			return inner_data
		end
		if entry_placetype_data.cat_handler then
			local inner_data = data.get_equiv_placetype_prop(holonym_placetype,
				function(pt) return entry_placetype_data.cat_handler(pt, holonym_placename, place_desc) end)
			if inner_data then
				return inner_data
			end
		end
		return nil
	end

	if overriding_holonym and override_inner_outer == "outer" then
		inner_data = fetch_inner_data(overriding_holonym)
		outer_triggering_holonym = overriding_holonym
	else
		for _, holonym in ipairs(place_desc.holonyms) do
			inner_data = fetch_inner_data(holonym)
			if inner_data then
				outer_triggering_holonym = holonym
				break
			end
		end
	end

	if not inner_data then
		inner_data = entry_placetype_data["default"]
	end

	-- If we didn't find a matching spec, and there's a fallback, look it up. This is used, for example, with "rural
	-- municipality", which has special cases for some provinces of Canada and otherwise behaves like "municipality".
	if not inner_data and entry_placetype_data.fallback then
		return find_cat_specs(entry_placetype_data.fallback, cat_data[entry_placetype_data.fallback], place_desc,
			overriding_holonym, override_inner_outer)
	end
	
	if not inner_data then
		return nil, entry_placetype, nil, nil
	end

	local function fetch_cat_specs(holonym_to_match)
		return data.get_equiv_placetype_prop(holonym_to_match.placetype, function(pt) return inner_data[pt] end)
	end

	if overriding_holonym and override_inner_outer == "inner" then
		local cat_specs = fetch_cat_specs(overriding_holonym)
		if cat_specs then
			return cat_specs, entry_placetype, overriding_holonym, "inner"
		end
	else
		for _, holonym in ipairs(place_desc.holonyms) do
			local cat_specs = fetch_cat_specs(holonym)
			if cat_specs then
				return cat_specs, entry_placetype, holonym, "inner"
			end
		end
	end

	local cat_specs = inner_data["itself"]
	if cat_specs then
		return cat_specs, entry_placetype, outer_triggering_holonym, "outer"
	end
	
	-- If we didn't find a matching key in the inner data, and there's a fallback, look it up, as above.
	-- This is used, for example, with "rural municipality", which has special cases for
	-- some provinces of Canada and otherwise behaves like "municipality".
	if entry_placetype_data.fallback then
		return find_cat_specs(entry_placetype_data.fallback, cat_data[entry_placetype_data.fallback], place_desc, overriding_holonym, override_inner_outer)
	end

	return nil, entry_placetype, nil, nil
end


-- Turn a list of category specs (see comment at section top) into the corresponding wikicode.
-- It is given the following arguments:
-- (1) the language object (param 1=)
-- (2) the category specs retrieved using find_cat_specs()
-- (3) the entry placetype used to fetch the entry in `cat_data`
-- (4) the triggering holonym (a holonym object; see comment at top of file) used to fetch the category specs
--     (see top-of-section comment); or nil if no triggering holonym
-- The return value is constructed as described in the top-of-section comment.
local function cat_specs_to_category_wikicode(lang, cat_specs, entry_placetype, holonym, sort_key)
	local all_cats = ""

	if holonym then
		local holonym_placetype, holonym_placename = holonym.placetype, holonym.placename
		holonym_placename = data.resolve_cat_aliases(holonym_placetype, holonym_placename)

		for _, cat_spec in ipairs(cat_specs) do
			local cat
			if cat_spec == true then
				cat = get_placetype_plural(entry_placetype, "ucfirst") .. " " .. get_in_or_of(entry_placetype)
					.. " +++"
			else
				cat = cat_spec
			end

			if cat:find("%+%+%+") then
				local equiv_holonym = require(table_module).shallowcopy(holonym)
				equiv_holonym.placetype = holonym_placetype
				cat = cat:gsub("%+%+%+", get_holonym_description(equiv_holonym, true, false))
			end
			all_cats = all_cats .. catlink(lang, cat, sort_key)
		end
	else
		for _, cat_spec in ipairs(cat_specs) do
			local cat
			if cat_spec == true then
				cat = get_placetype_plural(entry_placetype, "ucfirst")
			else
				cat = cat_spec
				if cat:find("%+%+%+") then
					error("Category '" .. cat .. "' contains +++ but there is no holonym to substitute")
				end
			end

			all_cats = all_cats .. catlink(lang, cat, sort_key)
		end
	end

	return all_cats
end


-- Return a string containing the category wikicode that should be added to the entry, given the place description
-- (which specifies the entry placetype(s) and holonym(s); see top of file) and a particular entry placetype (e.g.
-- "city"). Note that only the holonyms from the place description are looked at, not the entry placetypes in the place
-- description.
local function get_cat(lang, place_desc, entry_placetype, sort_key)
	local entry_pt_data, equiv_entry_placetype_and_qualifier = data.get_equiv_placetype_prop(entry_placetype, function(pt) return cat_data[pt] end)

	-- Check for unrecognized placetype.
	if not entry_pt_data then
		return ""
	end

	local equiv_entry_placetype = equiv_entry_placetype_and_qualifier.placetype

	-- Find the category specs (see top-of-file comment) corresponding to the holonym(s) in the place description.
	local cat_specs, returned_entry_placetype, triggering_holonym, inner_outer =
		find_cat_specs(equiv_entry_placetype, entry_pt_data, place_desc)

	-- Check if no category spec could be found. This happens if the innermost table in the category data
	-- doesn't match any holonym's placetype and doesn't have an "itself" entry.
	if not cat_specs then
		return ""
	end

	-- Generate categories for the category specs found.
	local cat = cat_specs_to_category_wikicode(lang, cat_specs, returned_entry_placetype, triggering_holonym, sort_key)

	-- If there's a triggering holonym (see top-of-file comment), also generate categories for other holonyms
	-- of the same placetype, so that e.g. {{place|en|city|s/Kansas|and|s/Missouri|c/USA}} generates both
	-- [[:Category:en:Cities in Kansas, USA]] and [[:Category:en:Cities in Missouri, USA]].
	if triggering_holonym then
		for _, other_placename_of_same_type in ipairs(place_desc.holonyms_by_placetype[triggering_holonym.placetype]) do
			if other_placename_of_same_type ~= triggering_holonym.placename then
				local overriding_holonym = {
					placetype = triggering_holonym.placetype, placename = other_placename_of_same_type
				}
				local other_cat_specs, other_returned_entry_placetype, other_triggering_holonym, other_inner_outer =
					find_cat_specs(equiv_entry_placetype, entry_pt_data, place_desc, overriding_holonym, inner_outer)
				if other_cat_specs then
					cat = cat .. cat_specs_to_category_wikicode(lang, other_cat_specs, other_returned_entry_placetype,
						other_triggering_holonym, sort_key)
				end
			end
		end
	end

	return cat
end


-- Iterate through each type of place given `place_descriptions` (a list of place descriptions, as documented at the
-- top of the file) and return a string with the links to all categories that need to be added to the entry.
local function get_cats(lang, args, place_descriptions, additional_cats, sort_key)
	local cats = {}

	handle_implications(place_descriptions, data.cat_implications, true)
	data.augment_holonyms_with_containing_polity(place_descriptions)

	local bare_categories = data.get_bare_categories(args, place_descriptions)
	for _, bare_cat in ipairs(bare_categories) do
		table.insert(cats, catlink(lang, bare_cat, sort_key))
	end

	for _, place_desc in ipairs(place_descriptions) do
		for _, placetype in ipairs(place_desc.placetypes) do
			if not data.placetype_is_ignorable(placetype) then
				table.insert(cats, get_cat(lang, place_desc, placetype, sort_key))
			end
		end
		-- Also add base categories for the holonyms listed (e.g. a category like
		-- 'en:Places in Merseyside, England'). This is handled through the special placetype "*".
		table.insert(cats, get_cat(lang, place_desc, "*", sort_key))
	end

	for _, addl_cat in ipairs(additional_cats) do
		table.insert(cats, catlink(lang, addl_cat, sort_key))
	end

	return table.concat(cats)
end



----------- Main entry point


-- Meant to be callable from another module (specifically, [[Module:transclude/sense]]). `drop_extra_info` means to
-- not include "extra info" (modern name, capital, largest city, etc.); this is used when transcluding into another
-- language using {{transclude sense}}.
function export.format(template_args, drop_extra_info)
	local params = {
		[1] = {required = true},
		[2] = {required = true, list = true},
		["t"] = {list = true},
		["tid"] = {list = true, allow_holes = true},
		["cat"] = {list = true},
		["sort"] = {},
		["pagename"] = {}, -- for testing or documentation purposes

		["a"] = {},
		["also"] = {},
		["def"] = {},

		["modern"] = {list = true},
		["official"] = {list = true},
		["capital"] = {list = true},
		["largest city"] = {list = true},
		["caplc"] = {},
		["seat"] = {list = true},
		["shire town"] = {list = true},
	}

	-- FIXME, once we've flushed out any uses, delete the following clause. That will cause def= to be ignored.
	if template_args.def == "" then
		error("Cannot currently pass def= as an empty parameter; use def=- if you want to suppress the definition display")
	end
	local args = require("Module:parameters").process(template_args, params)
	local lang = require("Module:languages").getByCode(args[1], 1, "allow etym")
	local place_descriptions = parse_place_descriptions(args[2])

	return get_def(args, place_descriptions, drop_extra_info) ..
		get_cats(lang, args, place_descriptions, args["cat"], args["sort"])
end


function export.show(frame)
	return export.format(frame:getParent().args)
end


return export
