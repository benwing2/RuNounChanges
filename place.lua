local export = {}

local m_links = require("Module:links")
local m_langs = require("Module:languages")
local m_strutils = require("Module:string utilities")
local data = require("Module:place/data")

local cat_data = data.cat_data

local catlink, find_cat_spec, get_cat, get_cats, get_def, get_description, get_extra_info,
	get_gloss, get_in_or_of, get_place_string, get_possible_cat, get_synergic_description,
	get_translations


local namespace = mw.title.getCurrentTitle().nsText



----------- Wikicode utility functions



-- returns a wikilink link {{l|language|text}}
local function link(text, language)
	if not language or language == "" then
		return text
	end
	
	return m_links.full_link({term = text, lang = m_langs.getByCode(language)}, nil, true)
end




---------- Basic utility functions




-- Given a placetype, split the placetype into one or more potential "splits", each consisting
-- of (a) a recognized qualifier (e.g. "small", "former"), which we canonicalize
-- (e.g. "historical" -> "historic", "seaside" -> "coastal"); and (b) a "bare placetype".
-- Return a list of pairs of {CANON_QUALIFIER, BARE_PLACETYPE}, as above. There may be
-- more than one element in the list in cases like "small unincorporated town". If no recognized
-- qualifier could be found, the list will be empty.
local function split_and_canonicalize_placetype(placetype)
	local splits = {}
	local prev_qualifier = nil
	while true do
		local qualifier, bare_placetype = placetype:match("^(.-) (.*)$")
		if qualifier then
			local canon = data.placetype_qualifiers[qualifier]
			local new_qualifier
			if canon == true then
				new_qualifier = qualifier
			elseif canon then
				new_qualifier = canon
			else
				break
			end
			prev_qualifier = prev_qualifier and prev_qualifier .. " " .. new_qualifier or new_qualifier
			table.insert(splits, {prev_qualifier, bare_placetype})
			placetype = bare_placetype
		else
			break
		end
	end
	return splits
end


-- Given a placetype, return an ordered list of equivalent placetypes to look under
-- to find the placetype's properties (actually, an ordered list of objects of the
-- form {qualifier=QUALIFIER, placetype=PLACETYPE} where QUALIFIER is a descriptive
-- qualifier to prepend, or nil). The placetype itself always forms the first entry.
local function get_placetype_equivs(placetype)
	local equivs = {}
	table.insert(equivs, {placetype=placetype})
	if data.placetype_equivs[placetype] then
		table.insert(equivs, {placetype=data.placetype_equivs[placetype]})
	end
	local splits = split_and_canonicalize_placetype(placetype)
	for _, split in ipairs(splits) do
		local qualifier, bare_placetype = split[1], split[2]
		table.insert(equivs, {qualifier=qualifier, placetype=bare_placetype})
		if data.placetype_equivs[bare_placetype] then
			table.insert(equivs, {qualifier=qualifier, placetype=data.placetype_equivs[bare_placetype]})
		end
	end
	return equivs
end


local function get_equiv_placetype_prop(placetype, fun)
	if not placetype then
		return fun(nil), nil
	end
	local equivs = get_placetype_equivs(placetype)
	for _, equiv in ipairs(equivs) do
		local retval = fun(equiv.placetype)
		if retval then
			return retval, equiv
		end
	end
	return nil, nil
end

 
-- Fetches the synergy table from cat_data, which describes the format of
-- glosses consisting of <placetype1> and <placetype2>.
-- The parameters are tables in the format {placetype, placename, langcode}.
local function get_synergy_table(place1, place2)
	if not place2 then
		return nil
	end
	local pt_data = get_equiv_placetype_prop(place2[1], function(pt) return cat_data[pt] end)
	if not pt_data or not pt_data.synergy then
		return nil
	end
	
	if not place1 then
		place1 = {}
	end
	
	local synergy = get_equiv_placetype_prop(place1[1], function(pt) return pt_data.synergy[pt] end)
	return synergy or pt_data.synergy["default"]
end


-- Returns the article that is used with a word. It is fetched from the cat_data
-- table; if that doesn’t exist, "an" is given for words beginning with a vowel
-- and "a" otherwise.
-- If sentence == true, the first letter of the article is made upper-case.
local function get_article(word, sentence)
	local art = ""

	local pt_data = get_equiv_placetype_prop(word, function(pt) return cat_data[pt] end)
	if pt_data and pt_data.article then
		art = pt_data.article
	elseif word:find("^[aeiou]") then
		art = "an"
	else
		art = "a"
	end
	
	if sentence then
		art = m_strutils.ucfirst(art)
	end
	
	return art
end



---------- Argument parsing functions and utilities



-- Given a place spec (see parse_place_specs()) and a holonym spec (the return value
-- of split_holonym()), add a key/value into the place spec corresponding to the
-- placetype and placename of the holonym spec. For example, corresponding to the
-- holonym "country/Italy", a key "country" with the list value {"Italy"} will be
-- added to the place spec. If there is already a key with that place type, the new
-- placename will be added to the end of the value's list.
local function key_holonym_spec_into_place_spec(place_spec, holonym_spec)
	if not holonym_spec[1] then
		return place_spec
	end
	
	local equiv_placetypes = get_placetype_equivs(holonym_spec[1])
	local placename = holonym_spec[2]
	for _, equiv in ipairs(equiv_placetypes) do
		local placetype = equiv.placetype
		if not place_spec[placetype] then
			place_spec[placetype] = {placename}
		else
			place_spec[placetype][table.getn(place_spec[placetype]) + 1] = placename
		end
	end
	
	return place_spec
end

-- Implement "implications", i.e. where the presence of a given holonym causes additional
-- holonym(s) to be added. There are two types of implications, general implications
-- (which apply to both display and categorization) and category implications (which apply
-- only to categorization). PLACE_SPECS is the return value of parse_place_specs(), i.e.
-- one or more place specs, collectively describing the data passed to {{place}}.
-- IMPLICATION_DATA is the data used to implement the implications, i.e. a table indexed
-- by holonym placetype, each value of which is a table indexed by holonym place name,
-- each value of which is a list of "PLACETYPE/PLACENAME" holonyms to be added to the
-- end of the list of holonyms. SHOULD_CLONE specifies whether to clone a given place spec
-- before modifying it.
local function handle_implications(place_specs, implication_data, should_clone)
	-- handle category implications
	for n, spec in ipairs(place_specs) do
		local lastarg = table.getn(spec)
		local cloned = false
		
		for c = 3, lastarg do
			local imp_data = get_equiv_placetype_prop(spec[c][1], function(pt)
				local implication = implication_data[pt] and implication_data[pt][m_links.remove_links(spec[c][2])]
				if implication then
					return implication
				end
			end)
			if imp_data then
				if should_clone and not cloned then
					spec = mw.clone(spec)
					cloned = true
					place_specs[n] = spec
				end
				for i, holonym_to_add in ipairs(imp_data) do
					local split_holonym = mw.text.split(holonym_to_add, "/", true)
					if #split_holonym ~= 2 then
						error("Invalid holonym in implications: " .. holonym_to_add)
					end
					local holonym_placetype, holonym_placename = split_holonym[1], split_holonym[2]
					local new_holonym = {holonym_placetype, holonym_placename}
					spec[table.getn(spec) + i] = new_holonym
					key_holonym_spec_into_place_spec(spec, new_holonym)
				end
			end
		end
	end
end

	
-- Split a holonym (e.g. "continent/Europe" or "country/en:Italy" or "in southern")
-- into its components. Return value is {PLACETYPE, PLACENAME, LANGCODE}, e.g.
-- {"country", "Italy", "en"}. If there isn't a slash (e.g. "in southern"), the
-- first element will be nil. Placetype aliases (e.g. "c" for "country") and
-- placename aliases (e.g. "US" or "USA" for "United States") will be expanded.
local function split_holonym(datum)
	datum = mw.text.split(datum, "/", true)
	
	if table.getn(datum) < 2 then
		datum = {nil, datum[1]}
	end

	-- HACK! Check for Wikipedia links, which contain an embedded colon.
	-- There should be a better way.
	if not datum[2]:find("%[%[w:") and not datum[2]:find("%[%[wikipedia:") then
		local links = mw.text.split(datum[2], ":", true)
		
		if table.getn(links) > 1 then
			datum[2] = links[2]
			datum[3] = links[1]
		end
	end

	if datum[1] then	
		datum[1] = data.placetype_aliases[datum[1]] or datum[1]
		datum[2] = get_equiv_placetype_prop(datum[1],
			function(pt) return data.placename_display_aliases[pt] and data.placename_display_aliases[pt][datum[2]] end
		) or datum[2]

		if not get_equiv_placetype_prop(datum[1], function(pt) return data.autolink[datum[3] and pt] end) then
			datum[3] = "en"
		end
	end
	return datum
end


-- Process numeric args (except for the language code in 1=). The return value is one or
-- more "place specs", each one corresponding to a single semicolon-separated combination of
-- placetype + holonyms in the numeric arguments. A given place spec is a table
-- {"foobar", PLACETYPES, HOLONYM_SPEC, HOLONYM_SPEC, ..., HOLONYM_PLACETYPE={HOLONYM_PLACENAME, ...}, ...}.
-- For example, the call {{place|en|city|s/Pennsylvania|c/US}} will result in a place spec
-- {"foobar", {"city"}, {"state", "Pennsylvania"}, {"country", "United States"}, state={"Pennsylvania"}, country={"United States"}}.
-- Here, the placetype aliases "s" and "c" have been expanded into "state" and "country"
-- respectively, and the placename alias "US" has been expanded into "United States".
-- PLACETYPES is a list because there may be more than one (e.g. the call
-- {{place|en|city/and/county|s/California}} will result in a place spec
-- {"foobar", {"city", "and", "county"}, {"state", "California"}, state={"California"}})
-- and the value in the key/value pairs is likewise a list (e.g. the call
-- {{place|en|city|s/Kansas|and|s/Missouri}} will result in a place spec
-- {"foobar", {"city"}, {"state", "Kansas"}, {nil, "and"}, {"state", "Missouri"}, state={"Kansas", "Missouri"}}).
local function parse_place_specs(numargs)
	local specs = {}
	local c = 1
	local cY = 1
	local cX = 2

	while numargs[c] do
		if numargs[c] == ";" then
			cY = cY + 1
			cX = 2
		else
			if cX == 2 then
				local entry_placetypes = mw.text.split(numargs[c], "/", true)
				for n, ept in ipairs(entry_placetypes) do
					entry_placetypes[n] = data.placetype_aliases[ept] or ept
				end
				specs[cY] = {"foobar", entry_placetypes}
			else
				specs[cY][cX] = split_holonym(numargs[c])
				key_holonym_spec_into_place_spec(specs[cY], specs[cY][cX])
			end
			
			cX = cX + 1
		end
		
		c = c + 1
	end

	handle_implications(specs, data.implications, false)
	
	return specs
end




-------- Definition-generating functions


-- Returns the definition line.
function get_def(args, specs)
	if #args["t"] > 0 then
		return get_translations(args["t"]) .. " (" .. get_gloss(args, specs, false) .. ")"
	else
		return get_gloss(args, specs, true)
	end
end


local function get_linked_placetype(placetype, use_default)
	local linked_version = data.placetype_links[placetype]
	if not linked_version then
		return use_default and placetype or nil
	elseif linked_version == true then
		return "[[" .. placetype .. "]]"
	elseif linked_version == "w" then
		return "[[w:" .. placetype .. "|" .. placetype .. "]]"
	else
		return linked_version
	end
end


-- Returns a string with the gloss (the description of the place itself, as
-- opposed to translations). If sentence == true, the gloss’s first letter is
-- made upper case and a period is added to the end.
function get_gloss(args, specs, sentence)
	if args["def"] then
		return args["def"]
	end
	
	local glosses = {}
	
	for n1, spec in ipairs(specs) do
		local gloss = ""
		
		for n2, placetype in ipairs(spec[2]) do
			if placetype == "and" then
				gloss = gloss .. " and "
			elseif placetype:find("^%(") then
				-- Check for placetypes beginning with a paren (so that things
				-- like "{{place|en|county/(one of 254)|s/Texas}}" work).
				gloss = gloss .. " " .. placetype
			else
				local pt_data, equiv_placetype_and_qualifier = get_equiv_placetype_prop(placetype,
					function(pt) return cat_data[pt] end)
				-- Join multiple placetypes with comma unless placetypes are already
				-- joined with "and". We allow "the" to precede the second placetype
				-- if they're not joined with "and" (so we get "city and county seat of ..."
				-- but "city, the county seat of ...").
				if n2 > 1 and spec[2][n2-1] ~= "and" then
					gloss = gloss .. ", "
					
					if pt_data and pt_data.article == "the" then
						gloss = gloss .. "the "
					end
				end
				
				local linked_version = get_linked_placetype(placetype)
				if linked_version then
					gloss = gloss .. linked_version
				else
					local splits = split_and_canonicalize_placetype(placetype)
					local did_add = false
					for _, split in ipairs(splits) do
						local qualifier, bare_placetype = split[1], split[2]
						local linked_version = get_linked_placetype(bare_placetype)
						if linked_version then
							gloss = gloss .. qualifier .. " " .. linked_version
							did_add = true
							break
						end
					end
					if not did_add then
						gloss = gloss .. placetype
					end
				end
			end
		end
		
		if args["also"] then
			gloss = gloss .. " and " .. args["also"]
		end
		
		local c = 3
		
		while spec[c] do
			local prev = nil
			
			if c > 3 then
				prev = spec[c-1]
			else
				prev = {}
			end
			
			gloss = gloss .. get_description(spec[2][table.getn(spec[2])], prev, spec[c], spec[c+1], (c == 3))
			c = c + 1
		end
		
		table.insert(glosses, gloss)
	end
	
	local ret = {(args["a"] or get_article(specs[1][2][1], sentence)) .. " " .. table.concat(glosses, "; ")}
	
	table.insert(ret, get_extra_info("modern", args["modern"], false))
	table.insert(ret, get_extra_info("official name:", args["official"], sentence))
	table.insert(ret, get_extra_info("capital:", args["capital"], sentence))
	table.insert(ret, get_extra_info("largest city:", args["largest city"], sentence))
	table.insert(ret, get_extra_info("capital and largest city:", args["caplc"], sentence))
	local placetype = specs[1][2][1]
	if placetype == "county" or placetype == "parish" or placetype == "borough" then
		placetype = placetype .. " seat"
	else
		placetype = "seat"
	end
	table.insert(ret, get_extra_info(placetype .. ":", args["seat"], sentence))

	return table.concat(ret)
end


-- Returns a string with extra information that is sometimes added to a
-- definition. This consists of the tag, a whitespace and the value (wikilinked
-- if it language contains a language code; if sentence == true, ". " is added
-- before the string and the first character is made upper case.
function get_extra_info(tag, value, sentence)
	if not value then
		return ""
	end

	-- HACK! Check for Wikipedia links, which contain an embedded colon.
	-- There should be a better way.
	if not value:find("%[%[w:") and not value:find("%[%[wikipedia:") then
		value = mw.text.split(value, ":", true)

		if table.getn(value) < 2 then
			value = {nil, value[1]}
		end

		value = link(value[2], value[1] or "en")
	end
	
	local s = ""
	
	if sentence then
		s = s .. ". " .. m_strutils.ucfirst(tag)
	else
		s = s .. "; " .. tag
	end
	
	return s .. " " .. value
end


-- returns a string containing a placename, with an extra article if necessary
-- and in the wikilinked display form if necessary.
-- Example: ({"country", "United States", "en"}, true, true) returns "the {{l|en|United States}}"
function get_place_string(place, needs_article, display_form)
	local ps = place[2]
	
	if display_form then
		local display_handler = get_equiv_placetype_prop(place[1], function(pt) return cat_data[pt] and cat_data[pt].display_handler end)
		if display_handler then
			ps = display_handler(place[1], place[2])
		end
		ps = link(ps, place[3])
	end
	
	if needs_article then
		local art = get_equiv_placetype_prop(place[1], function(pt) return data.placename_article[pt] and data.placename_article[pt][place[2]] end)
		if art then
			ps = art .. " " .. ps
		else
			art = get_equiv_placetype_prop(place[1], function(pt) return cat_data[pt] and cat_data[pt].holonym_article end)
			if art then
				ps = art .. " " .. ps
			end
		end
	end
	
	return ps
end

-- Returns a special description generated from a synergy table fetched from
-- the data module and two place tables.
function get_synergic_description(synergy, place1, place2)
	local desc = ""

	if place1 then
		
		if synergy.before then
			desc = desc .. " " .. synergy.before
		end
		
		desc = desc .. " " .. get_place_string(place1, true, true)
	end
	
	if synergy.between then
		desc = desc .. " " .. synergy.between
	end
	
	desc = desc .. " "  .. get_place_string(place2, true, true)
	
	if synergy.after then
		desc = desc .. " " .. synergy.after
	end
	
	return desc
end


-- Returns a string that contains the information of how a given place (place2)
-- should be formatted in the gloss, considering the entry’s place type, the 
-- place preceding it in the template’s parameter (place1) and following it 
-- (place3), and whether it is the first place (parameter 4 of the function).
function get_description(entry_placetype, place1, place2, place3, first)
	local desc = ""
	
	local synergy = get_synergy_table(place2, place3)
	
	if synergy then
		return ""
	end
	
	synergy = get_synergy_table(place1, place2)
	
	if first then
		if place2[1] then
			desc = desc .. get_in_or_of(entry_placetype, "")
		else
			desc = desc .. " "
		end
	else
		if not synergy then
			if place1[1] and place2[2] ~= "and" and place2[2] ~= "in" then
				desc = desc .. ","
			end
			
			desc = desc .. " "
		end
	end
	
	if not synergy then
		desc = desc .. get_place_string(place2, first, true)
	else
		desc = desc .. get_synergic_description(synergy, place1, place2)
	end
	

	return desc
end


-- Returns a string with the wikilinks to the English translations of the word.
function get_translations(transl)
	local ret = {}
	
	for _, t in ipairs(transl) do
		if t:find("[[", nil, true) then
			table.insert(ret, t)
		elseif t == mw.title.getCurrentTitle().prefixedText then
			table.insert(ret, "[[#English|" .. t .. "]]")
		else
			table.insert(ret, "[[" .. t .. "]]")
		end
	end
	
	return table.concat(ret, "; ")
end


-- Returns the preposition that should be used between the placetypes placetype1 and
-- placetype2 (i.e. "city >in< France.", "country >of< South America"
-- If there is no placetype2, a single whitespace is returned. Otherwise, the
-- preposition is fetched from the data module. If there isn’t any, the default
-- is "in".
-- The preposition is return with a whitespace before and after.
function get_in_or_of(placetype1, placetype2)
	if not placetype2 then
		return " "
	end
	
	local preposition = "in"

	local pt_data = get_equiv_placetype_prop(placetype1, function(pt) return cat_data[pt] end)
	if pt_data and pt_data.preposition then
		preposition = pt_data.preposition
	end
	
	return " " .. preposition .. " "
end



---------- Functions for the category wikicode



-- Iterate through each type of place given in parameter 2 (a list of place specs,
-- as documented in parse_place_specs()) and returns a string with the links to
-- all categories that need to be added to the entry. 
function get_cats(lang, place_specs)
	local cats = ""

	handle_implications(place_specs, data.cat_implications, true)
	
	for n1, place_spec in ipairs(place_specs) do
		for n2, placetype in ipairs(place_spec[2]) do
			if placetype ~= "and" then
				cats = cats .. get_cat(lang, place_spec, placetype)
			end
		end
	end
	
	return cats
end


-- Returns the plural of a word and makes its first letter upper case.
-- The plural is fetched from the data module; if it doesn’t find one,
-- the 'pluralize' function from [[Module:string utilities]] is called,
-- which pluralizes correctly in almost all cases.
function get_cat_plural(word)
	local pt_data, equiv_placetype_and_qualifier = get_equiv_placetype_prop(word, function(pt) return cat_data[pt] end)
	if pt_data then
		word = pt_data.plural or m_strutils.pluralize(equiv_placetype_and_qualifier.placetype)
	else
		word = m_strutils.pluralize(word)
	end
	return m_strutils.ucfirst(word)
end

-- Return a string containing the category wikicode that should be added to the
-- entry, given the place spec (see parse_place_specs()) and the type of place
-- (e.g. "city").
function get_cat(lang, place_spec, entry_placetype)
	-- Find the category data for a given placetype. This data is a two-level
	-- table, the outer indexed by the holonym itself (e.g. "country/Italy") or by
	-- "default", and the inner indexed by the holonym's placetype (e.g. "country")
	-- or by "itself". Note that most frequently, if the outer table is indexed by
	-- a holonym, the inner table will be indexed only by "itself", while if the
	-- outer table is indexed by "default", the inner table will be indexed by
	-- one or more holonym placetypes, meaning to generate a category for all holonyms
	-- of this placetype.
	local entry_pt_data, equiv_entry_placetype_and_qualifier = get_equiv_placetype_prop(entry_placetype, function(pt) return cat_data[pt] end)
	
	-- 1. Unrecognized placetype.
	if not entry_pt_data then
		return ""
	end

	local equiv_entry_placetype = equiv_entry_placetype_and_qualifier.placetype

	-- Find the category spec (a usually one-element list of full or partial categories,
	-- or a list {true}; see find_cat_spec()) corresponding to the holonym(s) in the place
	-- spec. See above.
	local cat_spec, c, itself = find_cat_spec(entry_pt_data, place_spec)
	
	-- 2. No category spec could be found. This happens if the innermost table in the category data
	--    doesn't match any holonym's placetype and doesn't have an "itself" entry.
	if not cat_spec then
		return ""
	end

	-- 3. The inner placetype category data was keyed by "itself", and the returned category spec
	--    is a (usually one-element) list of full category strings. Construct and return the
	--    category wikicode, e.g. for the category string "Cities in Fujian", the wikicode
	--    [[Category:fr:Cities in Fujian]] might be returned (if the language of LANG is French).
	if itself and type(cat_spec[1]) == "string" then
		return catlink(lang, cat_spec[1])
	end
	
	-- 4. This handles cases where either the outer or inner key matched a holonym.
	if c > 2 then
		local cat = get_possible_cat(lang, cat_spec, equiv_entry_placetype, entry_pt_data, place_spec[c], place_spec, itself)
		
		if cat ~= "" then
			local c2 = 2
			
			while place_spec[place_spec[c][1]][c2] do
				cat = cat .. get_possible_cat(lang, cat_spec, equiv_entry_placetype, entry_pt_data, {place_spec[c][1], place_spec[place_spec[c][1]][c2]}, place_spec, itself)
				c2 = c2 + 1
			end
		end
		return cat
	end

	-- 5. This handles the case where the outer key is "default", the inner key is "itself",
	--    and the category spec is {true}.
	return catlink(lang, get_cat_plural(equiv_entry_placetype))
end


-- Look up and resolve any category aliases that need to be applied to a
-- holonym. For example, "country/United States" maps to "United States of America"
-- for use in categories like "Cities in the United States of America".
local function resolve_cat_aliases(holonym_placetype, holonym_placename)
	local retval
	local cat_aliases = get_equiv_placetype_prop(holonym_placetype, function(pt) return data.placename_cat_aliases[pt] end)
	if cat_aliases then
		retval = cat_aliases[holonym_placename]
	end
	return retval or holonym_placename
end


-- Find the appropriate category or categories for a given place spec; e.g. for the call
-- {{place|en|city|s/Pennsylvania|c/US}} which results in the place spec
-- {"foobar", {"city"}, {"state", "Pennsylvania"}, {"country", "United States"}, state={"Pennsylvania"}, country={"United States"}},
-- the return value would likely be {"Cities in Pennsylvania, USA"}, 3, false
-- (i.e. three values are returned; see below).
--
-- More specifically, given two arguments: (1) the value of cat_data[placetype] for the
-- placetype of the place in question, i.e. 2=; (2) the full place spec as documented in
-- parse_place_specs(); look up the outer-level data (normally keyed by the holonym, e.g.
-- "country/Italy", or by "default") and the inner-level data (normally keyed by "itself"
-- for a specific holonym and by the holonym's placetype for "default"), and return the
-- resulting value. This value is one or two things: (a) a list of categories or partial
-- categories (usually with only one element), where full categories (minus the initial
-- language code) are used when the inner key is "itself", and partial categories such as
-- "Cities in " (with the holonym's placename attached to form the full category) are used
-- otherwise; (b) {true} to construct the category from the place's placetype and the holonym's
-- placename. The lookup works by iterating twice through the holonyms in the place spec:
-- First to look up the outer-level data, and secondly to look up the inner-level data in
-- the outer-level data just found. Both lookups stop as soon as a matching key is found,
-- meaning that usually only the first-listed holonym of the form PLACETYPE/PLACENAME (i.e.
-- excluding bare strings like "in southern") has a corresponding category returned. Three
-- values are actually returned:
--
-- CATEGORIES, HOLONYM_INDEX, IS_ITSELF
--
-- where CATEGORIES is a list as described above; PLACE_SPEC_INDEX is the index (3 or
-- greater) of the matching holonym in the place spec, or -1 if the outer-level data
-- was keyed by "default"; and IS_ITSELF is true if the inner-level data was keyed by
-- "itself", otherwise false. More specifically, there are three cases:
--
-- 1. An outer-level key matching a specific holonym (e.g. "country/Italy") was found,
--    but an inner-level key matching the holonym's placetype (e.g. "country") wasn't
--    found. In this case, CATEGORIES is based on the inner-level key "itself" (or nil
--    if no such key exists), PLACE_SPEC_INDEX is the index of the holonym whose
--    placetype was found among the outer-level keys, and IS_ITSELF is true.
-- 2. An outer-level key matching a specific holonym (e.g. "country/Italy") wasn't found
--    (so the outer-level key "default" was used), and an inner-level key matching the
--    holonym's placetype (e.g. "country") also wasn't found. In this case, CATEGORIES
--    is based on the inner-level key "itself" (or nil if no such key exists),
--    PLACE_SPEC_INDEX is -1, and IS_ITSELF is true.
-- 3. An inner-level key matching the holonym's placetype (e.g. "country") was found,
--    regardless of whether an outer-level key matching a specific holonym was found.
--    In this case, CATEGORIES is based on the matching inner-level key, PLACE_SPEC_INDEX
--    is the index of the holonym's placetype serving as the inner-level key, and
--    IS_ITSELF is false. Note the difference here in the meaning of the second parameter
--    vs. (1) above.
function find_cat_spec(entry_placetype_data, place_spec)
	local inner_data = nil
	
	local c = 3
	
	while place_spec[c] do
		local holonym_placetype, holonym_placename = place_spec[c][1], place_spec[c][2]
		holonym_placename = resolve_cat_aliases(holonym_placetype, holonym_placename)
		inner_data = get_equiv_placetype_prop(holonym_placetype,
			function(pt) return entry_placetype_data[(pt or "") .. "/" .. holonym_placename] end)
		if inner_data then
			break
		end
		if entry_placetype_data.cat_handler then
			inner_data = get_equiv_placetype_prop(holonym_placetype,
				function(pt) return entry_placetype_data.cat_handler(pt, holonym_placename) end)
			if inner_data then
				break
			end
		end
		c = c + 1
	end
	
	if not inner_data then
		inner_data = entry_placetype_data["default"]
		c = -1
	end
	
	local c2 = 3
	
	while place_spec[c2] do
		local retval = get_equiv_placetype_prop(place_spec[c2][1], function(pt) return inner_data[pt] end)
		if retval then
			return retval, c2, false
		end
		
		c2 = c2 + 1
	end
	
	return inner_data["itself"], c, true
end


-- Turn a category spec (a list of partial or full categories, or {true}) into the wikicode of
-- one or more actual categories. It is given the following arguments:
-- (1) the language object (param 1=)
-- (2) the category spec retrieved using find_cat_spec()
-- (3) the placetype of the place (param 2=)
-- (4) the value of cat_data for this placetype
-- (5) the holonym for which the category spec was fetched (in the format of indices 3, 4, ...
--     of the place spec data, as described in parse_place_specs())
-- (6) the place spec itself
-- (7) true if the inner key of the placetype category data was "itself" (the IS_ITSELF
--     return value of find_cat_spec()); this means the category spec contains full categories,
--     rather than partial ones
-- The return value is constructed by iterating over the entries in the category spec.
-- For each entry, we concatenate following:
-- (1) the category from the category spec; or, if == true, the plural of the placetype + the
--     appropriate preposition ("in" or "of", as determined from the placetype category data,
--     defaulting to "in" unless key "preposition" was specified);
-- (2) if a partial category such as "Cities in " was given (i.e. the inner key of the
--     placetype category data was not "itself"), the holonym's placename;
-- (3) if the holonym's placetype is "state", "province" or "region" and another holonym
--     was given with placetype "country", that holonym's placename, following a comma.
function get_possible_cat(lang, cat_spec, entry_placetype, entry_pt_data, holonym, place_spec, itself)
	if not cat_spec or not entry_placetype or not entry_pt_data or not holonym or not place_spec then
		return ""
	end
	
	local all_cats = ""

	local holonym_placetype = holonym[1]
	
	for _, name in ipairs(cat_spec) do
		local cat = ""
		if name == true then
			cat = get_cat_plural(entry_placetype) .. get_in_or_of(entry_placetype, holonym_placetype)
		elseif name then
			cat = name
		end
		
		if not itself or name == true then
			-- Normally, explicit categories given to "itself" are full categories and those given to
			-- some other placetype are partial categories (missing the holonym); but when true is
			-- given instead of an explicit category, we always construct a partial category above,
			-- so we always have to complete the category here even if true was given to "itself".
			-- (Note that the combination of "default" + "itself" + true isn't handled here; it's
			-- handled in condition (5) of get_cat().)
			cat = cat .. get_place_string(holonym, true, false)
		end

		local is_state_province_region = get_equiv_placetype_prop(holonym_placetype,
			function(pt) return pt == "state" or pt == "province" or pt == "region" end)
		if is_state_province_region and place_spec["country"] then
			-- If a holonym was specified as "cc/England" for "constituent country", there
			-- will automatically be a "country" entry here due to the way that
			-- key_holonym_spec_into_place_spec[] works.
			local country_append_format = data.country_append_format[place_spec["country"][1]]
			if country_append_format then
				cat = cat .. ", " .. (country_append_format == true and place_spec["country"][1] or country_append_format)
			end
		end
		
		all_cats = all_cats .. catlink(lang, cat)
	end
	
	return all_cats
end


-- Returns the category link for a category, given the language code and the
-- name of the category.
function catlink(lang, text)
	return require("Module:utilities").format_categories({lang:getCode() .. ":" .. m_links.remove_links(text)}, lang)
end



----------- Main entry point



function export.show(frame)
	local params = {
		[1] = {required = true},
		[2] = {required = true, list = true},
		["t"] = {list = true},

		["a"] = {},
		["also"] = {},
		["def"] = {},
		
		["modern"] = {},
		["official"] = {},
		["capital"] = {},
		["largest city"] = {},
		["caplc"] = {},
		["seat"] = {},
	}
	
	local args = require("Module:parameters").process(frame:getParent().args, params)
	local lang = require("Module:languages").getByCode(args[1]) or error("The language code \"" .. args[1] .. "\" is not valid.")
	local place_specs = parse_place_specs(args[2])
	
	return get_def(args, place_specs) .. get_cats(lang, place_specs)
end


return export
