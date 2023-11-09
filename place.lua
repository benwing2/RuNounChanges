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
-- If sentence == true, the first letter of the article is made upper-case.
local function get_placetype_article(placetype, sentence)
	local art

	local pt_data = data.get_equiv_placetype_prop(placetype, function(pt) return cat_data[pt] end)
	if pt_data and pt_data.article then
		art = pt_data.article
	elseif placetype:find("^[aeiou]") then
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
				local implication = implication_data[pt] and implication_data[pt][data.remove_links_and_html(spec[c][2])]
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
					local split_holonym = split_on_slash(holonym_to_add)
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
	local holonym_parts = split_on_slash(datum)
	if #holonym_parts == 1 then
		datum = {nil, datum}
	else
		-- Rejoin further slashes in case of slash in holonym placename, e.g. Admaston/Bromley.
		datum = {holonym_parts[1], table.concat(holonym_parts, "/", 2)}
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

		if not datum[3] then
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


-- Parse a "new-style" place spec, with placetypes and holonyms surrounded by <<...>> amid otherwise raw text.  Return
-- value is a place spec, as documented in parse_place_specs().
local function parse_new_style_place_spec(text)
	local placetypes = {}
	local segments = m_strutils.capturing_split(text, "<<(.-)>>")
	local retval = {"foobar", true, order = {}}
	for i, segment in ipairs(segments) do
		if i % 2 == 1 then
			table.insert(retval.order, {"raw", segment})
		elseif segment:find("/") then
			local holonym, is_multi = split_holonym(segment)
			if is_multi then
				for j, single_holonym in ipairs(holonym) do
					if j > 1 then
						if j == #holonym then
							table.insert(retval.order, {"raw", " and "})
						else
							table.insert(retval.order, {"raw", ", "})
						end
						-- Signal that "the" needs to be added if appropriate
						table.insert(single_holonym[4], "_art_")
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
			-- see if the placetype segment is just qualifiers
			local only_qualifiers = true
			local split_segments = rsplit(segment, " ", true)
			for _, split_segment in ipairs(split_segments) do
				if not data.placetype_qualifiers[split_segment] then
					only_qualifiers = false
					break
				end
			end
			table.insert(placetypes, {segment, only_qualifiers})
			if only_qualifiers then
				table.insert(retval.order, {"qualifier", segment})
			else
				table.insert(retval.order, {"placetype", segment})
			end
		end
	end

	local final_placetypes = {}
	for i, placetype in ipairs(placetypes) do
		if i > 1 and placetypes[i - 1][2] then
			final_placetypes[#final_placetypes] = final_placetypes[#final_placetypes] .. " " .. placetypes[i][1]
		else
			table.insert(final_placetypes, placetypes[i][1])
		end
	end
	retval[2] = final_placetypes
	return retval
end


-- Process numeric args (except for the language code in 1=). `numargs` is a list of the numeric arguments passed to
-- {{place}} starting from 2=. The return value is one or more "place specs", each one corresponding to a single
-- semicolon-separated combination of placetype + holonyms in the numeric arguments. A given place spec is a table
-- {"foobar", PLACETYPES, HOLONYM_SPEC, HOLONYM_SPEC, ..., HOLONYM_PLACETYPE={HOLONYM_PLACENAME, ...}, ...}.
-- For example, the call {{place|en|city|s/Pennsylvania|c/US}} will result in the return value
-- {{"foobar", {"city"}, {"state", "Pennsylvania"}, {"country", "United States"}, state={"Pennsylvania"}, country={"United States"}}}.
-- Here, the placetype aliases "s" and "c" have been expanded into "state" and "country" respectively, and the placename
-- alias "US" has been expanded into "United States". PLACETYPES is a list because there may be more than one (e.g. the
-- call {{place|en|city/and/county|s/California}} will result in the return value
-- {{"foobar", {"city", "and", "county"}, {"state", "California"}, state={"California"}}}) and the value in the
-- key/value pairs is likewise a list (e.g. the call {{place|en|city|s/Kansas|and|s/Missouri}} will return
-- {{"foobar", {"city"}, {"state", "Kansas"}, {nil, "and"}, {"state", "Missouri"}, state={"Kansas", "Missouri"}}}).
-- If there is an argument beginning with a semicolon, it separates multiple logical place descriptions and the returned
-- list will contain more than one value. For example, the call
-- {{place|en|city-state|cont/Europe|;|enclave|within|city/Rome|c/Italy}} will result in
-- {{"foobar", {"city-state"}, {"continent", "Europe"}, continent={"Europe"}, joiner="; "}, {"foobar", {"enclave"}, {nil, "within"}, {"city", "Rome"}, {"country", "Italy"}, city={"Rome"}, country={"Italy"}}}.
local function parse_place_specs(numargs)
	local specs = {}
	-- Index of separate (semicolon-separated) place descriptions within `specs`.
	local desc_index = 1
	-- Index of separate holonyms and placetypes within a place description. It starts at 2 because the first element of
	-- a place description is always "foobar" for historical reasons (FIXME: clean this up!). At index 2 is the
	-- placetype(s), while higher indices contain the holonym specs.
	local holonym_index = 2
	local last_was_new_style = false

	for _, arg in ipairs(numargs) do
		if arg == ";" or arg:find("^;[^ ]") then
			if not specs[desc_index] then
				error("Saw semicolon joiner without preceding place description")
			end
			if arg == ";" then
				specs[desc_index].joiner = "; "
			elseif arg == ";;" then
				specs[desc_index].joiner = " "
			else
				local joiner = arg:sub(2)
				if rfind(joiner, "^%a") then
					specs[desc_index].joiner = " " .. joiner .. " "
				else
					specs[desc_index].joiner = joiner .. " "
				end
			end
			desc_index = desc_index + 1
			holonym_index = 2
			last_was_new_style = false
		else
			if arg:find("<<") then
				if holonym_index > 2 then
					desc_index = desc_index + 1
					holonym_index = 2
				end
				specs[desc_index] = parse_new_style_place_spec(arg)
				last_was_new_style = true
				holonym_index = holonym_index + 1
			else
				if last_was_new_style then
					error("Old-style arguments cannot directly follow new-style place spec")
				end
				last_was_new_style = false
				if holonym_index == 2 then
					local entry_placetypes = split_on_slash(arg)
					specs[desc_index] = {"foobar", entry_placetypes}
					holonym_index = holonym_index + 1
				else
					local holonym, is_multi = split_holonym(arg)
					if is_multi then
						for j, single_holonym in ipairs(holonym) do
							if j > 1 then
								-- Signal that "the" needs to be added if appropriate
								table.insert(single_holonym[4], "_art_")
								if j == #holonym then
									specs[desc_index][holonym_index] = {nil, "and", nil, {}}
									holonym_index = holonym_index + 1
								end
							end
							specs[desc_index][holonym_index] = single_holonym
							key_holonym_spec_into_place_spec(specs[desc_index], specs[desc_index][holonym_index])
							holonym_index = holonym_index + 1
						end
					else
						specs[desc_index][holonym_index] = holonym
						key_holonym_spec_into_place_spec(specs[desc_index], specs[desc_index][holonym_index])
						holonym_index = holonym_index + 1
					end
				end
			end
		end
	end

	handle_implications(specs, data.implications, false)

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
	for _, spec in ipairs(specs) do
		for _, entry_placetype in ipairs(spec[2]) do
			local splits = data.split_qualifiers_from_placetype(entry_placetype, "no canon qualifiers")
			for _, split in ipairs(splits) do
				local prev_qualifier, this_qualifier, bare_placetype = unpack(split)
				track("entry-placetype/" .. bare_placetype)
				if this_qualifier then
					track("entry-qualifier/" .. this_qualifier)
				end
			end
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


-- Return the description of a holonym, with an extra article if necessary and in the
-- wikilinked display form if necessary.
-- Examples:
-- ({"country", "United States", "en", {}}, true, true) returns the template-expanded
-- equivalent of "the {{l|en|United States}}".
-- ({"region", "O'Higgins", "en", {"suf"}}, false, true) returns the template-expanded
-- equivalent of "{{l|en|O'Higgins}} region".
local function get_holonym_description(place, needs_article, display_form)
	local ps = place[2]
	local affix_type_pt_data, affix_type, affix, no_affix_strings, pt_equiv_for_affix_type, already_seen_affix

	if not needs_article then
		for _, mod in ipairs(place[4]) do
			if mod == "_art_" then
				needs_article = true
				break
			end
		end
	end

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
		local article = get_holonym_article(place[1], place[2], ps)
		if article then
			ps = article .. " " .. ps
		end
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


-- Return a string that contains the information of how `place` (a holonym spec; see parse_place_specs()) should be
-- formatted in the gloss, considering the entry's place type (specifically, the last place type if there are more than
-- one, excluding conjunctions and parenthetical items); the place preceding it in the template's parameters
-- (`prev_place`; also a holonym spec), and whether it is the first place (`first`).
local function get_contextual_holonym_description(entry_placetype, prev_place, place, first)
	local desc = ""

	-- NOTE: place[1] is the holonym placetype if the holonym was specified with a placetype, e.g. 'c/France', or nil
	-- otherwise. If it's nil, the holonym is just raw text, e.g. 'in southern'. place[2] is the actual holonym or
	-- raw text.

	-- First compute the initial delimiter.
	if first then
		if place[1] then
			desc = desc .. get_in_or_of(entry_placetype, "")
		elseif not place[2]:find("^,") then
			desc = desc .. " "
		end
	else
		if prev_place[1] and place[2] ~= "and" and place[2] ~= "in" then
			desc = desc .. ","
		end

		if place[1] or not place[2]:find("^,") then
			desc = desc .. " "
		end
	end

	return desc .. get_holonym_description(place, first, true)
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


-- Return the linked description of a placetype. This splits off any qualifiers and displays them separately.
local function get_placetype_description(placetype)
	local splits = data.split_qualifiers_from_placetype(placetype)
	local prefix = ""
	for _, split in ipairs(splits) do
		local prev_qualifier, this_qualifier, bare_placetype = split[1], split[2], split[3]
		if this_qualifier then
			prefix = (prev_qualifier and prev_qualifier .. " " .. this_qualifier or this_qualifier) .. " "
		else
			prefix = ""
		end
		local linked_version = get_linked_placetype(bare_placetype)
		if linked_version then
			return prefix .. linked_version
		end
		placetype = bare_placetype
	end
	return prefix .. placetype
end


-- Return the linked description of a qualifier (which may be multiple words).
local function get_qualifier_description(qualifier)
	local splits = data.split_qualifiers_from_placetype(qualifier .. " foo")
	local split = splits[#splits]
	local prev_qualifier, this_qualifier, bare_placetype = split[1], split[2], split[3]
	return prev_qualifier and prev_qualifier .. " " .. this_qualifier or this_qualifier
end
	

-- Return a string with extra information that is sometimes added to a
-- definition. This consists of the tag, a whitespace and the value (wikilinked
-- if it language contains a language code; if sentence == true, ". " is added
-- before the string and the first character is made upper case.
local function get_extra_info(tag, values, sentence, auto_plural, with_colon)
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

	if sentence then
		s = s .. ". " .. m_strutils.ucfirst(tag)
	else
		s = s .. "; " .. tag
	end

	return s .. " " .. require(table_module).serialCommaJoin(linked_values)
end


-- Get the full description of an old-style place spec (with separate arguments for the placetype and each holonym).
local function get_old_style_gloss(args, spec, with_article, sentence)
	-- The placetype used to determine whether "in" or "of" follows is the last placetype if there are
	-- multiple slash-separated placetypes, but ignoring "and", "or" and parenthesized notes
	-- such as "(one of 254)".
	local placetype_for_in_or_of = nil
	local placetypes = spec[2]
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

	if remaining_placetype_index < #placetypes then
		track("multiple-placetypes-without-and")
	end
	for i = remaining_placetype_index, #placetypes do
		local pt = placetypes[i]
		-- Check for placetypes beginning with a paren (so that things like "{{place|en|county/(one of 254)|s/Texas}}"
		-- work).
		if is_and_or(pt) or pt:find("^%(") then
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
				ins(get_placetype_article(pt))
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

	for c = 3, #spec do
		local first = c == 3
		local prev = first and {} or spec[c - 1]
		ins(get_contextual_holonym_description(placetype_for_in_or_of, prev, spec[c], first))
	end

	local gloss = table.concat(parts)

	if with_article then
		gloss = (args["a"] or get_placetype_article(spec[2][1], sentence)) .. " " .. gloss
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
		local segment_type, segment = order[1], order[2]
		if segment_type == "raw" then
			table.insert(parts, segment)
		elseif segment_type == "placetype" then
			table.insert(parts, get_placetype_description(segment))
		elseif segment_type == "qualifier" then
			table.insert(parts, get_qualifier_description(segment))
		elseif segment_type == "holonym" then
			table.insert(parts, get_holonym_description(spec[segment], false, true))
		else
			error("Internal error: Unrecognized segment type '" .. segment_type .. "'")
		end
	end

	return table.concat(parts)
end


-- Return a string with the gloss (the description of the place itself, as opposed to translations). If `sentence` is
-- given, the gloss's first letter is made upper case and a period is added to the end. If `drop_extra_info` is given,
-- we don't include "extra info" (modern name, capital, largest city, etc.); this is used when transcluding into
-- another language using {{transclude sense}}.
local function get_gloss(args, specs, sentence, drop_extra_info)
	if args.def == "-" then
		return ""
	elseif args.def then
		return args.def
	end

	local glosses = {}
	for n, spec in ipairs(specs) do
		if spec.order then
			table.insert(glosses, get_new_style_gloss(args, spec, n == 1))
		else
			table.insert(glosses, get_old_style_gloss(args, spec, n == 1, sentence))
		end
		if spec.joiner then
			table.insert(glosses, spec.joiner)
		end
	end

	local ret = {table.concat(glosses)}

	if not drop_extra_info then
		table.insert(ret, get_extra_info("modern", args["modern"], false, false, false))
		table.insert(ret, get_extra_info("official name", args["official"], sentence, "auto plural", "with colon"))
		table.insert(ret, get_extra_info("capital", args["capital"], sentence, "auto plural", "with colon"))
		table.insert(ret, get_extra_info("largest city", args["largest city"], sentence, "auto plural", "with colon"))
		table.insert(ret, get_extra_info("capital and largest city", args["caplc"], sentence, false, "with colon"))
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
		table.insert(ret, get_extra_info(placetype, args["seat"], sentence, "auto plural", "with colon"))
		table.insert(ret, get_extra_info("shire town", args["shire town"], sentence, "auto plural", "with colon"))
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
		holonym_placename = data.resolve_cat_aliases(holonym_placetype, holonym_placename)
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
		holonym_placename = data.resolve_cat_aliases(holonym_placetype, holonym_placename)
		holonym = {holonym_placetype, holonym_placename}

		for _, cat_spec in ipairs(cat_specs) do
			local cat
			if cat_spec == true then
				cat = get_cat_plural(entry_placetype) .. get_in_or_of(entry_placetype, holonym_placetype) .. " +++"
			else
				cat = cat_spec
			end

			cat = cat:gsub("%+%+%+", get_holonym_description(holonym, true, false))
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
local function get_cats(lang, place_specs, additional_cats, sort_key)
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
	local place_specs = parse_place_specs(args[2])

	return get_def(args, place_specs, drop_extra_info) .. get_cats(lang, place_specs, args["cat"], args["sort"])
end


function export.show(frame)
	return export.format(frame:getParent().args)
end


return export
