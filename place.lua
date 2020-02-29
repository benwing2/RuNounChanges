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



local function remove_links_and_html(text)
	text = m_links.remove_links(text)
	return text:gsub("<.->", "")
end


-- Return a wikilink link {{l|language|text}}
local function link(text, language)
	if not language or language == "" then
		return text
	end

	return m_links.full_link({term = text, lang = m_langs.getByCode(language)}, nil, true)
end


-- Return the category link for a category, given the language code and the
-- name of the category.
local function catlink(lang, text, sort_key)
	return require("Module:utilities").format_categories({lang:getCode() .. ":" .. remove_links_and_html(text)}, lang, sort_key)
end



---------- Basic utility functions



-- Add the page to a tracking "category". To see the pages in the "category",
-- go to [[Template:tracking/place/PAGE]] and click on "What links here".
local function track(page)
	m_debug.track("place/" .. page)
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
				local implication = implication_data[pt] and implication_data[pt][remove_links_and_html(spec[c][2])]
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

	if datum[1] and datum[2]:find(",") then
		local placenames = split_holonym_placename(datum[2])
		local retval = {}
		for _, placename in ipairs(placenames) do
			local holonym = {datum[1], placename, datum[3], datum[4]}
			table.insert(retval, holonym)
		end
		return retval, true
	else
		return datum, false
	end
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
			local holonym, is_multi = split_holonym(segment)
			if is_multi then
				for j, single_holonym in ipairs(holonym) do
					if j > 1 then
						if j == #holonym then
							table.insert(retval.raw, " and ")
							table.insert(retval.order, {"raw", #retval.raw})
						else
							table.insert(retval.raw, ", ")
							table.insert(retval.order, {"raw", #retval.raw})
						end
					end
					table.insert(retval, single_holonym)
					table.insert(retval.order, {"holonym", #retval})
					key_holonym_spec_into_place_spec(retval, single_holonym)
				end
			else
				table.insert(retval, holonym)
				table.insert(retval.order, {"holonym", #retval})
				key_holonym_spec_into_place_spec(retval, holonym)
			end
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
				cX = cX + 1
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
					cX = cX + 1
				else
					local holonym, is_multi = split_holonym(numargs[c])
					if is_multi then
						for j, single_holonym in ipairs(holonym) do
							if j > 1 and j == #holonym then
								specs[cY][cX] = {nil, "and", nil, {}}
								cX = cX + 1
							end
							specs[cY][cX] = single_holonym
							key_holonym_spec_into_place_spec(specs[cY], specs[cY][cX])
							cX = cX + 1
						end
					else
						specs[cY][cX] = holonym
						key_holonym_spec_into_place_spec(specs[cY], specs[cY][cX])
						cX = cX + 1
					end
				end
			end
		end

		c = c + 1
	end

	handle_implications(specs, data.implications, false)

	for _, spec in ipairs(specs) do
		for _, entry_placetype in ipairs(spec[2]) do
			track("entry-placetype/" .. entry_placetype)
		end
		cY = 3
		while spec[cY] do
			if spec[cY][1] then
				track("holonym-placetype/" .. spec[cY][1])
			end
			cY = cY + 1
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

	return table.concat(ret, ", ")
end


-- Prepend the appropriate article if needed to LINKED_PLACENAME, where PLACENAME
-- is the corresponding unlinked placename and PLACETYPE its placetype.
local function prepend_article(placetype, placename, linked_placename)
	placename = remove_links_and_html(placename)
	local unlinked_placename = remove_links_and_html(linked_placename)
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
	local affix_type_pt_data, affix_type, affix, no_affix_strings, pt_equiv_for_affix_type, already_seen_affix

	if display_form then
		-- Implement display handlers.
		local display_handler = data.get_equiv_placetype_prop(place[1], function(pt) return cat_data[pt] and cat_data[pt].display_handler end)
		if display_handler then
			ps = display_handler(place[1], place[2])
		end
		-- Implement adding an affix (prefix or suffix) based on the place type. The affix will be
		-- added either if the place type's cat_data spec says so (by setting 'affix_type'), or if the
		-- user explicitly called for this (e.g. by using 'r:suf/O'Higgins'). Before adding the affix,
		-- however, we check to see if the affix is already present (e.g. the place type is "district"
		-- and the place name is "Mission District"). If the place type explicitly calls for adding
		-- an affix, it can override the affix to add (by setting 'affix') and/or override the strings
		-- used for checking if the affix is already presen (by setting 'no_affix_strings').
		affix_type_pt_data, pt_equiv_for_affix_type = data.get_equiv_placetype_prop(place[1],
			function(pt) return cat_data[pt] and cat_data[pt].affix_type and cat_data[pt] end
		)
		if affix_type_pt_data then
			affix_type = affix_type_pt_data.affix_type
			affix = affix_type_pt_data.affix or pt_equiv_for_affix_type.placetype
			no_affix_strings = affix_type_pt_data.no_affix_strings or lc(affix)
		end
		for _, mod in ipairs(place[4]) do
			if (mod == "pref" or mod == "Pref" or mod == "suf" or mod == "Suf") and place[1] then
				affix_type = mod
				affix = place[1]
				no_affix_strings = lc(affix)
				break
			end
		end
		already_seen_affix = no_affix_strings and data.check_already_seen_string(ps, no_affix_strings)
		ps = link(ps, place[3])
		if (affix_type == "suf" or affix_type == "Suf") and not already_seen_affix then
			ps = ps .. " " .. (affix_type == "Suf" and ucfirst_all(affix) or affix)
		end
	end

	if needs_article then
		ps = prepend_article(place[1], place[2], ps)
	end

	if display_form then
		if (affix_type == "pref" or affix_type == "Pref") and not already_seen_affix then
			ps = (affix_type == "Pref" and ucfirst_all(affix) or affix) .. " of " .. ps
			if needs_article then
				ps = "the " .. ps
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
			-- Join multiple placetypes with comma unless placetypes are already
			-- joined with "and". We allow "the" to precede the second placetype
			-- if they're not joined with "and" (so we get "city and county seat of ..."
			-- but "city, the county seat of ...").
			if n2 > 1 and spec[2][n2-1] ~= "and" and spec[2][n2-1] ~= "or" then
				local article = get_article(placetype)
				if article ~= "the" then
					-- Temporary tracking. Formerly we didn't insert an article in this case.
					track("multiple-placetypes-no-the")
				end
				gloss = gloss .. ", " .. article .. " "
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

--[=[

The code in this section finds the categories to which a given place belongs. The algorithm
works off of a place spec (which specifies the entry placetype(s) and holonym(s); see
parse_place_specs()). Iterating over each entry placetype, it proceeds as follows:
(1) Look up the placetype in the `cat_data`, which comes from [[Module:place/data]]. Note that
    the entry in `cat_data` that specifies the category or categories to add may directly
	correspond to the entry placetype as specified in the place spec. For example, if the
	entry placetype is "small town", the placetype whose data is fetched will be "town" since
	"small" is a recognized qualifier and there is no entry in `cat_data` for "small town".
	As another example, if the entry placetype is "administrative capital", the placetype
	whose data will be fetched will be "capital city" because there's no entry in `cat_data`
	for "administrative capital" but there is an entry in `placetype_equivs` in
	[[Module:place/data]] that maps "administrative capital" to "capital city" for
	categorization purposes.
(2) The value in `cat_data` is a two-level table. The outer table is indexed by the holonym
    itself (e.g. "country/Brazil") or by "default", and the inner indexed by the holonym's
    placetype (e.g. "country") or by "itself". Note that most frequently, if the outer table
	is indexed by a holonym, the inner table will be indexed only by "itself", while if the
	outer table is indexed by "default", the inner table will be indexed by one or more holonym
	placetypes, meaning to generate a category for all holonyms of this placetype. But this
	is not necessarily the case.
(3) Iterate through the holonyms, from left to right, finding the first holonym that matches
    (in both placetype and placename) a key in the outer table. If no holonym matches any key,
	then if a key "default" exists, use that; otherwise, if a key named "fallback" exists,
	specifying a placetype, use that placetype to fetch a new `cat_data` entry, and start over
	with step (1); otherwise, don't categorize.
(4) Iterate again through the holonyms, from left to right, finding the first holonym whose
    placetype matches a key in the inner table. If no holonym matches any key, then if a key
	"itself" exists, use that; otherwise, check for a key named "fallback" at the top level of
	the `cat_data` entry and, if found, proceed as in step (3); otherwise don't categorize.
(5) The resulting value found is a list of category specs. Each category spec specifies a
    category to be added. In order to understand how category specs are processed, you have to
	understand the concept of the 'triggering holonym'. This is the holonym that matched an
	inner key in step (4), if any; else, the holonym that matched an outer key in step (3),
	if any; else, there is no triggering holonym. (The only time this happens when there are
	category specs is when the outer key is "default" and the inner key is "itself".)
(6) Iterate through the category specs and construct a category from each one. Each category
    spec is one of the following:
	(a) A string, such as "Seas", Districts of England" or "Cities in +++". If "+++" is
	    contained in the string, it will be substituted with the placename of the triggering
		holonym. If there is no triggering holonym, an error is thrown. This is then prefixed
		with the language code specified in the first argument to the call to {{place}}.
		For example, if the triggering holonym is "country/Brazil", the category spec is
		"Cities in +++" and the template invocation was {{place|en|...}}, the resulting
		category will be [[:Category:en:Cities in Brazil]].
	(b) The value 'true'. If there is a triggering holonym, the spec "PLACETYPES in +++" or
        "PLACETYPES of +++" is constructed. (Here, PLACETYPES is the plural of the entry
        placetype whose cat_data is being used, which is not necessarily the same as the entry
        placetype specified by the user; see the discussion above. The choice of "in" or "of"
        is based on the value of the "preposition" key at the top level of the entry in
		`cat_data`, defaulting to "in".) This spec is then processed as above. If there is no
		triggering holonym, the simple spec "PLACETYPES" is constructed (where PLACETYPES is as
		above).

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

If the user uses a template call {{place|pt|municipality|s/Amazonas|c/Brazil}}, the
categories [[:Category:pt:Municipalities of Amazonas, Brazil]] and
[[:Category:pt:Municipalities of Brazil]] will be generated. This is because the outer key
"country/Brazil" matches the second holonym "c/Brazil" (by this point, the alias "c" has
been expanded to "country"), and the inner key "state" matches the first holonym "s/Amazonas",
which serves as the triggering holonym and is used to replace the +++ in the first category
spec.

Now imagine the user uses the template call {{place|en|small municipality|c/Brazil}}. There
is no entry in `cat_data` for "small municipality", but "small" is a recognized qualifier,
and there is an entry in `cat_data` for "municipality", so that entry's data is used. Now,
the second holonym "c/Brazil" will match the outer key "country/Brazil" as before, but in
this case the second holonym will also match the inner key "country" and will serve as the
triggering holonym. The cat spec 'true' will be expanded to "Municipalities of +++", using
the placetype "municipality" corresponding to the entry in `cat_data` (not the user-specified
placetype "small municipality"), and the preposition "of", as specified in the `cat_data`
entry. The +++ will then be expanded to "Brazil" based on the triggering holonym, the language
code "en" will be prepended, and the final category will be
[[:Category:en:Municipalities of Brazil]].
]=]

-- Look up and resolve any category aliases that need to be applied to a holonym. For example,
-- "country/Republic of China" maps to "Taiwan" for use in categories like "Counties in Taiwan".
-- This also removes any links.
local function resolve_cat_aliases(holonym_placetype, holonym_placename)
	local retval
	local cat_aliases = data.get_equiv_placetype_prop(holonym_placetype, function(pt) return data.placename_cat_aliases[pt] end)
	holonym_placename = remove_links_and_html(holonym_placename)
	if cat_aliases then
		retval = cat_aliases[holonym_placename]
	end
	return retval or holonym_placename
end


-- Find the appropriate category specs for a given place spec; e.g. for the call
-- {{place|en|city|s/Pennsylvania|c/US}} which results in the place spec
-- {"foobar", {"city"}, {"state", "Pennsylvania"}, {"country", "United States"}, state={"Pennsylvania"}, country={"United States"}},
-- the return value might be be "city", {"Cities in +++, USA"}, {"state", "Pennsylvania"}, "outer"
-- (i.e. four values are returned; see below). See the comment at the top of the section for a
-- description of category specs and the overall algorithm.
--
-- More specifically, given the following arguments:
-- (1) the entry placetype (or equivalent) used to look up the category data in cat_data;
-- (2) the value of cat_data[placetype] for this placetype;
-- (3) the full place spec as documented in parse_place_specs() (used only for its holonyms);
-- (4) an optional overriding holonym to use, in place of iterating through the holonyms;
-- (5) if an overriding holonym was specified, either "inner" or "outer" to indicate which loop to override;
-- find the holonyms that match the outer-level and inner-level keys in the `cat_data` entry
-- according to the algorithm described in the top-of-section comment, and return the resulting
-- category specs. Four values are actually returned:
--
-- CATEGORY_SPECS, ENTRY_PLACETYPE, TRIGGERING_HOLONYM, INNER_OR_OUTER
--
-- where
--
-- (1) CATEGORY_SPECS is a list of category specs as described above;
-- (2) ENTRY_PLACETYPE is the placetype that should be used to construct categories when 'true'
--     is one of the returned category specs (normally the same as the `entry_placetype` passed
--     in, but will be different when a "fallback" key exists and is used);
-- (3) TRIGGERING_HOLONYM is the triggering holonym (see the comment at the top of the section), in the
--     standard {PLACETYPE, PLACENAME} format, or nil if there was no triggering holonym;
-- (4) INNER_OR_OUTER is "inner" if the triggering holonym matched in the inner loop (whether or not a
--     holonym matched the outer loop), or "outer" if the triggering holonym matched in the outer loop
--     only, or nil if no triggering holonym.
local function find_cat_specs(entry_placetype, entry_placetype_data, place_spec, overriding_holonym, override_inner_outer)
	local inner_data = nil
	local outer_triggering_holonym

	local function fetch_inner_data(holonym_to_match)
		local holonym_placetype, holonym_placename = holonym_to_match[1], holonym_to_match[2]
		holonym_placename = resolve_cat_aliases(holonym_placetype, holonym_placename)
		local inner_data = data.get_equiv_placetype_prop(holonym_placetype,
			function(pt) return entry_placetype_data[(pt or "") .. "/" .. holonym_placename] end)
		if inner_data then
			return inner_data
		end
		if entry_placetype_data.cat_handler then
			local inner_data = data.get_equiv_placetype_prop(holonym_placetype,
				function(pt) return entry_placetype_data.cat_handler(pt, holonym_placename, place_spec) end)
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
		local c = 3
		while place_spec[c] do
			inner_data = fetch_inner_data(place_spec[c])
			if inner_data then
				outer_triggering_holonym = place_spec[c]
				break
			end
			c = c + 1
		end
	end

	if not inner_data then
		inner_data = entry_placetype_data["default"]
	end

	-- If we didn't find a matching place spec, and there's a fallback, look it up.
	-- This is used, for example, with "rural municipality", which has special cases for
	-- some provinces of Canada and otherwise behaves like "municipality".
	if not inner_data and entry_placetype_data.fallback then
		return find_cat_specs(entry_placetype_data.fallback, cat_data[entry_placetype_data.fallback], place_spec, overriding_holonym, override_inner_outer)
	end
	
	if not inner_data then
		return nil, entry_placetype, nil, nil
	end

	local function fetch_cat_specs(holonym_to_match)
		return data.get_equiv_placetype_prop(holonym_to_match[1], function(pt) return inner_data[pt] end)
	end

	if overriding_holonym and override_inner_outer == "inner" then
		local cat_specs = fetch_cat_specs(overriding_holonym)
		if cat_specs then
			return cat_specs, entry_placetype, overriding_holonym, "inner"
		end
	else
		local c2 = 3

		while place_spec[c2] do
			local cat_specs = fetch_cat_specs(place_spec[c2])
			if cat_specs then
				return cat_specs, entry_placetype, place_spec[c2], "inner"
			end

			c2 = c2 + 1
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
		return find_cat_specs(entry_placetype_data.fallback, cat_data[entry_placetype_data.fallback], place_spec, overriding_holonym, override_inner_outer)
	end

	return nil, entry_placetype, nil, nil
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


-- Turn a list of category specs (see comment at section top) into the corresponding wikicode.
-- It is given the following arguments:
-- (1) the language object (param 1=)
-- (2) the category specs retrieved using find_cat_specs()
-- (3) the entry placetype used to fetch the entry in `cat_data`
-- (4) the triggering holonym used to fetch the category specs (see top-of-section comment), in
--     the format of indices 3, 4, ... of the place spec data, as described in
--     parse_place_specs()); or nil if no triggering holonym
-- The return value is constructed as described in the top-of-section comment.
local function cat_specs_to_category_wikicode(lang, cat_specs, entry_placetype, holonym, sort_key)
	local all_cats = ""

	if holonym then
		local holonym_placetype, holonym_placename = holonym[1], holonym[2]
		holonym_placename = resolve_cat_aliases(holonym_placetype, holonym_placename)
		holonym = {holonym_placetype, holonym_placename}

		for _, cat_spec in ipairs(cat_specs) do
			local cat
			if cat_spec == true then
				cat = get_cat_plural(entry_placetype) .. get_in_or_of(entry_placetype, holonym_placetype) .. " +++"
			else
				cat = cat_spec
			end

			cat = cat:gsub("%+%+%+", get_place_string(holonym, true, false))
			all_cats = all_cats .. catlink(lang, cat, sort_key)
		end
	else
		for _, cat_spec in ipairs(cat_specs) do
			local cat
			if cat_spec == true then
				cat = get_cat_plural(entry_placetype)
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


-- Return a string containing the category wikicode that should be added to the entry, given the
-- place spec (which specifies the entry placetype(s) and holonym(s); see parse_place_specs()) and
-- a particular entry placetype (e.g. "city"). Note that only the holonyms from the place spec are
-- looked at, not the entry placetypes in the place spec.
local function get_cat(lang, place_spec, entry_placetype, sort_key)
	local entry_pt_data, equiv_entry_placetype_and_qualifier = data.get_equiv_placetype_prop(entry_placetype, function(pt) return cat_data[pt] end)

	-- Check for unrecognized placetype.
	if not entry_pt_data then
		return ""
	end

	local equiv_entry_placetype = equiv_entry_placetype_and_qualifier.placetype

	-- Find the category specs (see top-of-file comment) corresponding to the holonym(s) in the place spec.
	local cat_specs, returned_entry_placetype, triggering_holonym, inner_outer =
		find_cat_specs(equiv_entry_placetype, entry_pt_data, place_spec)

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
		local c2 = 2

		local other_holonyms_of_same_placetype = place_spec[triggering_holonym[1]]
		while other_holonyms_of_same_placetype[c2] do
			local overriding_holonym = {triggering_holonym[1], other_holonyms_of_same_placetype[c2]}
			local other_cat_specs, other_returned_entry_placetype, other_triggering_holonym, other_inner_outer =
				find_cat_specs(equiv_entry_placetype, entry_pt_data, place_spec, overriding_holonym, inner_outer)
			if other_cat_specs then
				cat = cat .. cat_specs_to_category_wikicode(lang, other_cat_specs, other_returned_entry_placetype,
					other_triggering_holonym, sort_key)
			end
			c2 = c2 + 1
		end
	end

	return cat
end


-- Iterate through each type of place given in parameter 2 (a list of place specs, as documented
-- in parse_place_specs()) and return a string with the links to all categories that need to be
-- added to the entry.
local function get_cats(lang, place_specs, sort_key)
	local cats = {}

	handle_implications(place_specs, data.cat_implications, true)

	for n1, place_spec in ipairs(place_specs) do
		for n2, placetype in ipairs(place_spec[2]) do
			if placetype ~= "and" then
				table.insert(cats, get_cat(lang, place_spec, placetype, sort_key))
			end
		end
		-- Also add base categories for the holonyms listed (e.g. a category like
		-- 'en:Places in Merseyside, England'). This is handled through the special placetype "*".
		table.insert(cats, get_cat(lang, place_spec, "*", sort_key))
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
		["sort"] = {},
	}

	local args = require("Module:parameters").process(frame:getParent().args, params)
	local lang = require("Module:languages").getByCode(args[1]) or error("The language code \"" .. args[1] .. "\" is not valid.")
	local place_specs = parse_place_specs(args[2])

	return get_def(args, place_specs) .. get_cats(lang, place_specs, args["sort"])
end


return export
