local export = {}

local m_links = require("Module:links")
local m_langs = require("Module:languages")
local m_strutils = require("Module:string utilities")
local m_debug = require("Module:debug")
local data = require("Module:place/data")

local rmatch = mw.ustring.match
local rsplit = mw.text.split

local cat_data = data.cat_data

local namespace = mw.title.getCurrentTitle().nsText



----------- Wikicode utility functions



-- Return a wikilink link {{l|language|text}}
local function link(text, language)
	if not language or language == "" then
		return text
	end

	return m_links.full_link({term = text, lang = m_langs.getByCode(language)}, nil, true)
end


-- Return the category link for a category, given the language code and the
-- name of the category.
local function catlink(lang, text)
	return require("Module:utilities").format_categories({lang:getCode() .. ":" .. m_links.remove_links(text)}, lang)
end



---------- Basic utility functions



-- Add the page to a tracking "category". To see the pages in the "category",
-- go to [[Template:tracking/place/PAGE]] and click on "What links here".
local function track(page)
	m_debug.track("place/" .. page)
	return true
end



-- Fetches the synergy table from cat_data, which describes the format of
-- glosses consisting of <placetype1> and <placetype2>.
-- The parameters are tables in the format {placetype, placename, langcode}.
local function get_synergy_table(place1, place2)
	if not place2 then
		return nil
	end
	local pt_data = data.get_equiv_placetype_prop(place2[1], function(pt) return cat_data[pt] end)
	if not pt_data or not pt_data.synergy then
		return nil
	end

	if not place1 then
		place1 = {}
	end

	local synergy = data.get_equiv_placetype_prop(place1[1], function(pt) return pt_data.synergy[pt] end)
	return synergy or pt_data.synergy["default"]
end


-- Return the article that is used with a word. It is fetched from the cat_data
-- table; if that doesn’t exist, "an" is given for words beginning with a vowel
-- and "a" otherwise.
-- If sentence == true, the first letter of the article is made upper-case.
local function get_article(word, sentence)
	local art = ""

	local pt_data = data.get_equiv_placetype_prop(word, function(pt) return cat_data[pt] end)
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

	local equiv_placetypes = data.get_placetype_equivs(holonym_spec[1])
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
			local imp_data = data.get_equiv_placetype_prop(spec[c][1], function(pt)
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
					local split_holonym = rsplit(holonym_to_add, "/", true)
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


-- Look up a placename in an alias table, handling links appropriately.
-- If the alias isn't found, return nil.
local function lookup_placename_alias(placename, aliases)
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


-- Split a holonym (e.g. "continent/Europe" or "country/en:Italy" or "in southern"
-- or "r:suf/O'Higgins") into its components. Return value is
-- {PLACETYPE, PLACENAME, LANGCODE, MODIFIERS}, e.g. {"country", "Italy", "en", {}} or
-- {"region", "O'Higgins", nil, {"suf"}}. If there isn't a slash (e.g. "in southern"),
-- the first element will be nil. Placetype aliases (e.g. "r" for "region") and
-- placename aliases (e.g. "US" or "USA" for "United States") will be expanded.
local function split_holonym(datum)
	-- Don't use rsplit() in case of slash in holonym placename, e.g. Admaston/Bromley.
	local holonym_placetype, holonym_placename = rmatch(datum, "^(.-)/(.*)$")
	if holonym_placetype then
		datum = {holonym_placetype, holonym_placename}
	else
		datum = {nil, datum}
	end

	-- Check for langcode before the holonym placename, but don't get tripped up by
	-- Wikipedia links, which begin "[[w:...]]" or "[[wikipedia:]]".
	local langcode, holonym_placename = rmatch(datum[2], "^([^%[%]]-):(.*)$")
	if langcode then
		datum[2] = holonym_placename
		datum[3] = langcode
	end

	-- Check for modifiers after the holonym placetype.
	if datum[1] then
		local split_holonym_placetype = rsplit(datum[1], ":", true)
		datum[1] = split_holonym_placetype[1]
		local modifiers = {}
		local i = 2
		while true do
			if split_holonym_placetype[i] then
				table.insert(modifiers, split_holonym_placetype[i])
			else
				break
			end
			i = i + 1
		end
		datum[4] = modifiers
	else
		datum[4] = {}
	end
	if datum[1] then
		datum[1] = data.placetype_aliases[datum[1]] or datum[1]
		datum[2] = data.get_equiv_placetype_prop(datum[1],
			function(pt) return data.placename_display_aliases[pt] and lookup_placename_alias(datum[2], data.placename_display_aliases[pt]) end
		) or datum[2]

		if not data.get_equiv_placetype_prop(datum[1], function(pt) return data.autolink[datum[3] and pt] end) then
			datum[3] = "en"
		end
	end
	return datum
end


-- Parse a "new-style" place spec, with placetypes and holonyms surrounded by <<...>>
-- amid otherwise raw text.  Return value is a place spec, as documented in
-- parse_place_specs().
local function parse_new_style_place_spec(text)
	local segments = m_strutils.capturing_split(text, "<<(.-)>>")
	local retval = {"foobar", {}, raw = {}, order = {}}
	for i, segment in ipairs(segments) do
		if i % 2 == 1 then
			table.insert(retval.raw, segment)
			table.insert(retval.order, {"raw", #retval.raw})
		elseif segment:find("/") then
			local holonym = split_holonym(segment)
			table.insert(retval, holonym)
			table.insert(retval.order, {"holonym", #retval})
			key_holonym_spec_into_place_spec(retval, holonym)
		else
			table.insert(retval[2], segment)
			table.insert(retval.order, {"placetype", #retval[2]})
		end
	end

	return retval
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
	local last_was_new_style = false

	while numargs[c] do
		if numargs[c] == ";" then
			cY = cY + 1
			cX = 2
			last_was_new_style = false
		else
			if numargs[c]:find("<<") then
				if cX > 2 then
					cY = cY + 1
					cX = 2
				end
				specs[cY] = parse_new_style_place_spec(numargs[c])
				last_was_new_style = true
			else
				if last_was_new_style then
					error("Old-style arguments cannot directly follow new-style place spec")
				end
				last_was_new_style = false
				if cX == 2 then
					local entry_placetypes = rsplit(numargs[c], "/", true)
					for n, ept in ipairs(entry_placetypes) do
						entry_placetypes[n] = data.placetype_aliases[ept] or ept
					end
					specs[cY] = {"foobar", entry_placetypes}
				else
					specs[cY][cX] = split_holonym(numargs[c])
					key_holonym_spec_into_place_spec(specs[cY], specs[cY][cX])
				end
			end

			cX = cX + 1
		end

		c = c + 1
	end

	handle_implications(specs, data.implications, false)

	for _, spec in ipairs(specs) do
		for _, entry_placetype in ipairs(spec[2]) do
			track("entry-placetype/" .. entry_placetype)
		end
	end
	
	return specs
end



-------- Definition-generating functions



-- Return a string with the wikilinks to the English translations of the word.
local function get_translations(transl)
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


-- Prepend the appropriate article if needed to LINKED_PLACENAME, where PLACENAME
-- is the corresponding unlinked placename and PLACETYPE its placetype.
local function prepend_article(placetype, placename, linked_placename)
	placename = m_links.remove_links(placename)
	local unlinked_placename = m_links.remove_links(linked_placename)
	if unlinked_placename:find("^the ") then
		return linked_placename
	end
	local art = data.get_equiv_placetype_prop(placetype, function(pt) return data.placename_article[pt] and data.placename_article[pt][placename] end)
	if art then
		return art .. " " .. linked_placename
	end
	art = data.get_equiv_placetype_prop(placetype, function(pt) return cat_data[pt] and cat_data[pt].holonym_article end)
	if art then
		return art .. " " .. linked_placename
	end
	local universal_res = data.placename_the_re["*"]
	for _, re in ipairs(universal_res) do
		if unlinked_placename:find(re) then
			return "the " .. linked_placename
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
		return "the " .. linked_placename
	end
	return linked_placename
end


-- Return a string containing a placename, with an extra article if necessary and in the
-- wikilinked display form if necessary.
-- Examples:
-- ({"country", "United States", "en", {}}, true, true) returns the template-expanded
-- equivalent of "the {{l|en|United States}}".
-- ({"region", "O'Higgins", "en", {"suf"}}, false, true) returns the template-expanded
-- equivalent of "{{l|en|O'Higgins}} region".
local function get_place_string(place, needs_article, display_form)
	local ps = place[2]

	if display_form then
		local display_handler = data.get_equiv_placetype_prop(place[1], function(pt) return cat_data[pt] and cat_data[pt].display_handler end)
		if display_handler then
			ps = display_handler(place[1], place[2])
		end
		ps = link(ps, place[3])
		for _, mod in ipairs(place[4]) do
			if mod == "suf" and place[1] then
				ps = ps .. " " .. place[1]
			elseif mod == "Suf" and place[1] then
				ps = ps .. " " .. m_strutils.ucfirst(place[1])
			end
		end
	end

	if needs_article then
		ps = prepend_article(place[1], place[2], ps)
	end

	if display_form then
		for _, mod in ipairs(place[4]) do
			if (mod == "pref" or mod == "Pref") and place[1] then
				ps = (mod == "Pref" and m_strutils.ucfirst(place[1]) or place[1]) .. " of " .. ps
				if needs_article then
					ps = "the " .. ps
				end
			end
		end
	end
	return ps
end

-- Return a special description generated from a synergy table fetched from
-- the data module and two place tables.
local function get_synergic_description(synergy, place1, place2)
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


-- Return the preposition that should be used between the placetypes placetype1 and
-- placetype2 (i.e. "city >in< France.", "country >of< South America"
-- If there is no placetype2, a single whitespace is returned. Otherwise, the
-- preposition is fetched from the data module. If there isn’t any, the default
-- is "in".
-- The preposition is return with a whitespace before and after.
local function get_in_or_of(placetype1, placetype2)
	if not placetype2 then
		return " "
	end

	local preposition = "in"

	local pt_data = data.get_equiv_placetype_prop(placetype1, function(pt) return cat_data[pt] end)
	if pt_data and pt_data.preposition then
		preposition = pt_data.preposition
	end

	return " " .. preposition .. " "
end


-- Return a string that contains the information of how a given place (place2)
-- should be formatted in the gloss, considering the entry’s place type, the 
-- place preceding it in the template’s parameter (place1) and following it 
-- (place3), and whether it is the first place (parameter 4 of the function).
local function get_holonym_description(entry_placetype, place1, place2, place3, first)
	local desc = ""

	local synergy = get_synergy_table(place2, place3)

	if synergy then
		return ""
	end

	synergy = get_synergy_table(place1, place2)

	if first then
		if place2[1] then
			desc = desc .. get_in_or_of(entry_placetype, "")
		elseif not place2[2]:find("^,") then
			desc = desc .. " "
		end
	else
		if not synergy then
			if place1[1] and place2[2] ~= "and" and place2[2] ~= "in" then
				desc = desc .. ","
			end

			if place2[1] or not place2[2]:find("^,") then
				desc = desc .. " "
			end
		end
	end

	if not synergy then
		desc = desc .. get_place_string(place2, first, true)
	else
		desc = desc .. get_synergic_description(synergy, place1, place2)
	end


	return desc
end


local function get_linked_placetype(placetype)
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
				return m_strutils.pluralize(linked_version)
			end
		end
	end
	
	return nil
end


-- Return the linked description of a placetype. This splits off any
-- qualifiers and displays them separately.
local function get_placetype_description(placetype)
	local linked_version = get_linked_placetype(placetype)
	if linked_version then
		return linked_version
	else
		local splits = data.split_and_canonicalize_placetype(placetype)
		local prefix = ""
		for _, split in ipairs(splits) do
			local prev_qualifier, this_qualifier, bare_placetype = split[1], split[2], split[3]
			prefix = (prev_qualifier and prev_qualifier .. " " .. this_qualifier or this_qualifier) .. " "
			local linked_version = get_linked_placetype(bare_placetype)
			if linked_version then
				return prefix .. " " .. linked_version
			end
			placetype = bare_placetype
		end
		return prefix .. placetype
	end
end


-- Return a string with extra information that is sometimes added to a
-- definition. This consists of the tag, a whitespace and the value (wikilinked
-- if it language contains a language code; if sentence == true, ". " is added
-- before the string and the first character is made upper case.
local function get_extra_info(tag, values, sentence)
	if not values then
		return ""
	end
	if type(values) ~= "table" then
		values = {values}
	end
	if #values == 0 then
		return ""
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

	if sentence then
		s = s .. ". " .. m_strutils.ucfirst(tag)
	else
		s = s .. "; " .. tag
	end

	return s .. " " .. require("Module:table").serialCommaJoin(linked_values)
end


-- Get the full description of an old-style place spec (with separate arguments for
-- the placetype and each holonym).
local function get_old_style_gloss(args, spec, with_article, sentence)
	local gloss = ""

	-- The placetype used to determine whether "in" or "of" follows is the last placetype if there are
	-- multiple slash-separated placetypes, but ignoring "and", "or" and parenthesized notes
	-- such as "(one of 254)".
	local placetype_for_in_or_of = nil
	for n2, placetype in ipairs(spec[2]) do
		if placetype == "and" then
			gloss = gloss .. " and "
		elseif placetype == "or" then
			gloss = gloss .. " or "
		elseif placetype:find("^%(") then
			-- Check for placetypes beginning with a paren (so that things
			-- like "{{place|en|county/(one of 254)|s/Texas}}" work).
			gloss = gloss .. " " .. placetype
		else
			placetype_for_in_or_of = placetype
			local pt_data, equiv_placetype_and_qualifier = data.get_equiv_placetype_prop(placetype,
				function(pt) return cat_data[pt] end)
			-- Join multiple placetypes with comma unless placetypes are already
			-- joined with "and". We allow "the" to precede the second placetype
			-- if they're not joined with "and" (so we get "city and county seat of ..."
			-- but "city, the county seat of ...").
			if n2 > 1 and spec[2][n2-1] ~= "and" and spec[2][n2-1] ~= "or" then
				gloss = gloss .. ", "

				if pt_data and pt_data.article == "the" then
					gloss = gloss .. "the "
				end
			end

			gloss = gloss .. get_placetype_description(placetype)
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

		gloss = gloss .. get_holonym_description(placetype_for_in_or_of, prev, spec[c], spec[c+1], (c == 3))
		c = c + 1
	end

	if with_article then
		gloss = (args["a"] or get_article(spec[2][1], sentence)) .. " " .. gloss
	end

	return gloss
end


-- Get the full description of a new-style place spec. New-style place specs are
-- specified with a single string containing raw text interspersed with placetypes
-- and holonyms surrounded by <<...>>.
local function get_new_style_gloss(args, spec, with_article)
	local parts = {}

	if with_article and args["a"] then
		table.insert(parts, args["a"] .. " ")
	end

	for _, order in ipairs(spec.order) do
		local segment_type, segment_num = order[1], order[2]
		if segment_type == "raw" then
			table.insert(parts, spec.raw[segment_num])
		elseif segment_type == "placetype" then
			table.insert(parts, get_placetype_description(spec[2][segment_num]))
		elseif segment_type == "holonym" then
			table.insert(parts, get_place_string(spec[segment_num], false, true))
		else
			error("Internal error: Unrecognized segment type '" .. segment_type .. "'")
		end
	end

	return table.concat(parts)
end


-- Return a string with the gloss (the description of the place itself, as
-- opposed to translations). If sentence == true, the gloss’s first letter is
-- made upper case and a period is added to the end.
local function get_gloss(args, specs, sentence)
	if args["def"] then
		return args["def"]
	end

	local glosses = {}
	for n, spec in ipairs(specs) do
		if spec.order then
			table.insert(glosses, get_new_style_gloss(args, spec, n == 1))
		else
			table.insert(glosses, get_old_style_gloss(args, spec, n == 1, sentence))
		end
	end

	local ret = {table.concat(glosses, "; ")}

	table.insert(ret, get_extra_info("modern", args["modern"], false))
	table.insert(ret, get_extra_info("official name:", args["official"], sentence))
	table.insert(ret, get_extra_info("capital:", args["capital"], sentence))
	table.insert(ret, get_extra_info("largest city:", args["largest city"], sentence))
	table.insert(ret, get_extra_info("capital and largest city:", args["caplc"], sentence))
	local placetype = specs[1][2][1]
	if placetype == "county" or placetype == "counties" then
		placetype = "county seat"
	elseif placetype == "parish" or placetype == "parishes" then
		placetype = "parish seat"
	elseif placetype == "borough" or placetype == "boroughs" then
		placetype = "borough seat"
	else
		placetype = "seat"
	end
	if #args["seat"] > 1 then
		placetype = placetype .. "s"
	end
	table.insert(ret, get_extra_info(placetype .. ":", args["seat"], sentence))
	if #args["shire town"] > 1 then
		placetype = "shire towns"
	else
		placetype = "shire town"
	end
	table.insert(ret, get_extra_info(placetype .. ":", args["shire town"], sentence))

	return table.concat(ret)
end


-- Return the definition line.
local function get_def(args, specs)
	if #args["t"] > 0 then
		return get_translations(args["t"]) .. " (" .. get_gloss(args, specs, false) .. ")"
	else
		return get_gloss(args, specs, true)
	end
end



---------- Functions for the category wikicode



-- Look up and resolve any category aliases that need to be applied to a holonym. For example,
-- "country/Republic of China" maps to "Taiwan" for use in categories like "Counties in Taiwan".
-- This also removes any links.
local function resolve_cat_aliases(holonym_placetype, holonym_placename)
	local retval
	local cat_aliases = data.get_equiv_placetype_prop(holonym_placetype, function(pt) return data.placename_cat_aliases[pt] end)
	holonym_placename = m_links.remove_links(holonym_placename)
	if cat_aliases then
		retval = cat_aliases[holonym_placename]
	end
	return retval or holonym_placename
end


-- Find the appropriate category or categories for a given place spec; e.g. for the call
-- {{place|en|city|s/Pennsylvania|c/US}} which results in the place spec
-- {"foobar", {"city"}, {"state", "Pennsylvania"}, {"country", "United States"}, state={"Pennsylvania"}, country={"United States"}},
-- the return value would likely be "city", {"Cities in Pennsylvania, USA"}, 3
-- (i.e. three values are returned; see below).
--
-- More specifically, given three arguments: (1) the entry placetype (or equivalent) used
-- to look up the category data in cat_data; (2) the value of cat_data[placetype] for this
-- placetype; (3) the full place spec as documented in parse_place_specs(); look up the
-- outer-level data (normally keyed by the holonym, e.g. "country/Italy", or by "default")
-- and the inner-level data (normally keyed by "itself" for a specific holonym and by the
-- holonym's placetype for "default"), and return the resulting value. This value is a list
-- of one of two things: (a) a category, which may have +++ in it, which is replaced by
-- the matching holonym placename; (b) 'true' to construct the category from the entry's
-- placetype and the holonym's placename. The lookup works by iterating twice through the
-- holonyms in the place spec: First to look up the outer-level data, and secondly to look
-- up the inner-level data in the outer-level data just found. Both lookups stop as soon as
-- a matching key is found, meaning that usually only the first-listed holonym of the form
-- PLACETYPE/PLACENAME (i.e. excluding bare strings like "in southern") has a corresponding
-- category returned. Three values are actually returned:
--
-- ENTRY_PLACETYPE, CATEGORIES, HOLONYM_INDEX
--
-- where ENTRY_PLACETYPE is the placetype that should be used to construct categories when
-- 'true' is returned; CATEGORIES is a list as described above; and PLACE_SPEC_INDEX is the
-- index (3 or greater) of the matching holonym in the place spec, or -1 if the outer-level
-- data was keyed by "default". More specifically, there are three cases:
--
-- 1. An outer-level key matching a specific holonym (e.g. "country/Italy") was found,
--    but an inner-level key matching the holonym's placetype (e.g. "country") wasn't
--    found. In this case, CATEGORIES is based on the inner-level key "itself" (or nil
--    if no such key exists), and PLACE_SPEC_INDEX is the index of the holonym whose
--    placetype was found among the outer-level keys.
-- 2. An outer-level key matching a specific holonym (e.g. "country/Italy") wasn't found
--    (so the outer-level key "default" was used), and an inner-level key matching the
--    holonym's placetype (e.g. "country") also wasn't found. In this case, CATEGORIES
--    is based on the inner-level key "itself" (or nil if no such key exists), and
--    PLACE_SPEC_INDEX is -1.
-- 3. An inner-level key matching the holonym's placetype (e.g. "country") was found,
--    regardless of whether an outer-level key matching a specific holonym was found.
--    In this case, CATEGORIES is based on the matching inner-level key, and PLACE_SPEC_INDEX
--    is the index of the holonym's placetype serving as the inner-level key. Note the
--    difference here in the meaning of the second parameter vs. (1) above.
local function find_cat_spec(entry_placetype, entry_placetype_data, place_spec)
	local inner_data = nil

	local c = 3

	while place_spec[c] do
		local holonym_placetype, holonym_placename = place_spec[c][1], place_spec[c][2]
		holonym_placename = resolve_cat_aliases(holonym_placetype, holonym_placename)
		inner_data = data.get_equiv_placetype_prop(holonym_placetype,
			function(pt) return entry_placetype_data[(pt or "") .. "/" .. holonym_placename] end)
		if inner_data then
			break
		end
		if entry_placetype_data.cat_handler then
			inner_data = data.get_equiv_placetype_prop(holonym_placetype,
				function(pt) return entry_placetype_data.cat_handler(pt, holonym_placename, place_spec) end)
			if inner_data then
				break
			end
		end
		c = c + 1
	end

	-- If we didn't find a matching place spec, and there's a fallback, look it up.
	-- This is used, for example, with "rural municipality", which has special cases for
	-- some provinces of Canada and otherwise behaves like "municipality".
	if not inner_data and entry_placetype_data.fallback then
		return find_cat_spec(entry_placetype_data.fallback, cat_data[entry_placetype_data.fallback], place_spec)
	end
	
	if not inner_data then
		inner_data = entry_placetype_data["default"]
		c = -1
	end

	if not inner_data then
		return entry_placetype, nil, -1
	end

	local c2 = 3

	while place_spec[c2] do
		local retval = data.get_equiv_placetype_prop(place_spec[c2][1], function(pt) return inner_data[pt] end)
		if retval then
			return entry_placetype, retval, c2
		end

		c2 = c2 + 1
	end

	return entry_placetype, inner_data["itself"], c
end


-- Return the plural of a word and makes its first letter upper case.
-- The plural is fetched from the data module; if it doesn’t find one,
-- the 'pluralize' function from [[Module:string utilities]] is called,
-- which pluralizes correctly in almost all cases.
local function get_cat_plural(word)
	local pt_data, equiv_placetype_and_qualifier = data.get_equiv_placetype_prop(word, function(pt) return cat_data[pt] end)
	if pt_data then
		word = pt_data.plural or m_strutils.pluralize(equiv_placetype_and_qualifier.placetype)
	else
		word = m_strutils.pluralize(word)
	end
	return m_strutils.ucfirst(word)
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
-- The return value is constructed by iterating over the entries in the category spec.
-- For each entry, the category is formed as follows:
-- (1) If the category spec is 'true', construct the category from the plural of the placetype +
--     the appropriate preposition ("in" or "of", as determined from the placetype category data,
--     defaulting to "in" unless key "preposition" was specified) + the string "+++". Otherwise,
--     the category spec should be a string; use it directly.
-- (2) If "+++" occurs in the resulting category string, replace it with the holonym placename.
--     The substituted placename comes from the holonym placename, possibly preceded by "the"
--     (if appropriate).
local function get_possible_cat(lang, cat_spec, entry_placetype, entry_pt_data, holonym, place_spec)
	if not cat_spec or not entry_placetype or not entry_pt_data or not holonym or not place_spec then
		return ""
	end

	local all_cats = ""

	local holonym_placetype, holonym_placename = holonym[1], holonym[2]
	holonym_placename = resolve_cat_aliases(holonym_placetype, holonym_placename)
	holonym = {holonym_placetype, holonym_placename}

	for _, name in ipairs(cat_spec) do
		local cat = ""
		if name == true then
			cat = get_cat_plural(entry_placetype) .. get_in_or_of(entry_placetype, holonym_placetype) .. " +++"
		elseif name then
			cat = name
		end

		cat = cat:gsub("%+%+%+", get_place_string(holonym, true, false))
		all_cats = all_cats .. catlink(lang, cat)
	end

	return all_cats
end


-- Return a string containing the category wikicode that should be added to the
-- entry, given the place spec (see parse_place_specs()) and the type of place
-- (e.g. "city").
local function get_cat(lang, place_spec, entry_placetype)
	-- Find the category data for a given placetype. This data is a two-level
	-- table, the outer indexed by the holonym itself (e.g. "country/Italy") or by
	-- "default", and the inner indexed by the holonym's placetype (e.g. "country")
	-- or by "itself". Note that most frequently, if the outer table is indexed by
	-- a holonym, the inner table will be indexed only by "itself", while if the
	-- outer table is indexed by "default", the inner table will be indexed by
	-- one or more holonym placetypes, meaning to generate a category for all holonyms
	-- of this placetype.
	local entry_pt_data, equiv_entry_placetype_and_qualifier = data.get_equiv_placetype_prop(entry_placetype, function(pt) return cat_data[pt] end)

	-- 1. Unrecognized placetype.
	if not entry_pt_data then
		return ""
	end

	local equiv_entry_placetype = equiv_entry_placetype_and_qualifier.placetype

	-- Find the category spec (a usually one-element list of full or partial categories,
	-- or a list {true}; see find_cat_spec()) corresponding to the holonym(s) in the place
	-- spec. See above.
	local cat_spec, c
	equiv_entry_placetype, cat_spec, c = find_cat_spec(equiv_entry_placetype, entry_pt_data, place_spec)

	-- 2. No category spec could be found. This happens if the innermost table in the category data
	--    doesn't match any holonym's placetype and doesn't have an "itself" entry.
	if not cat_spec then
		return ""
	end

	-- 3. This handles cases where either the outer or inner key matched a holonym.
	if c > 2 then
		local cat = get_possible_cat(lang, cat_spec, equiv_entry_placetype, entry_pt_data, place_spec[c], place_spec)

		if cat ~= "" then
			local c2 = 2

			while place_spec[place_spec[c][1]][c2] do
				cat = cat .. get_possible_cat(lang, cat_spec, equiv_entry_placetype, entry_pt_data, {place_spec[c][1], place_spec[place_spec[c][1]][c2]}, place_spec)
				c2 = c2 + 1
			end
		end
		return cat
	end

	-- 4. This handles the remaining case, i.e. the outer key is "default" and the inner key is "itself".
	--    In this case, there is no holonym to substitute into the category. If the category is 'true',
	--    we replace it with only the plural placetype (rather than "PLACETYPES in PLACENAME", as normal).
	--    If the category is a string, throw an error if it contains+++ (indicating a holonym substitution);
	--    otherwise, use it directly.
	local all_cats = ""
	for _, name in ipairs(cat_spec) do
		local cat
		if name == true then
			cat = get_cat_plural(equiv_entry_placetype)
		elseif name then
			cat = name
			if cat:find("%+%+%+") then
				error("Category '" .. cat .. "' contains +++ but there is no holonym to substitute")
			end
		end
		if cat then
			all_cats = all_cats .. catlink(lang, cat)
		end
	end
	return all_cats
end


-- Iterate through each type of place given in parameter 2 (a list of place specs,
-- as documented in parse_place_specs()) and return a string with the links to
-- all categories that need to be added to the entry. 
local function get_cats(lang, place_specs)
	local cats = {}

	handle_implications(place_specs, data.cat_implications, true)

	for n1, place_spec in ipairs(place_specs) do
		for n2, placetype in ipairs(place_spec[2]) do
			if placetype ~= "and" then
				table.insert(cats, get_cat(lang, place_spec, placetype))
			end
		end
		-- Also add base categories for the holonyms listed (e.g. a category like 'en:Merseyside, England').
		-- This is handled through the special placetype "*".
		table.insert(cats, get_cat(lang, place_spec, "*"))
	end

	return table.concat(cats)
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
		["seat"] = {list = true},
		["shire town"] = {list = true},
	}

	local args = require("Module:parameters").process(frame:getParent().args, params)
	local lang = require("Module:languages").getByCode(args[1]) or error("The language code \"" .. args[1] .. "\" is not valid.")
	local place_specs = parse_place_specs(args[2])

	return get_def(args, place_specs) .. get_cats(lang, place_specs)
end


return export
