local labels = {}
local handlers = {}

local m_shared = require("Module:place/shared-data")
local m_strutils = require("Module:string utilities")

--[=[

This module contains specifications that are used to create labels that allow {{auto cat}} and
{{topic cat}} to create the appropriate definitions for topic categories for places (e.g.re
'en:Waterfalls', 'de:Hokkaido', 'es:Cities in France', 'pt:Municipalities of Tocantins, Brazil',
etc.). Note that this module doesn't actually create the categories; that must be done manually,
with the text "{{auto cat}}" as the definition of the category. (This process should automatically
happen periodically for non-empty categories, because they will appear in [[Special:WantedCategories]]
and a bot will periodically examine that list and create any needed category.)

There are two ways that such labels are created: (1) by manually adding an entry to the 'labels'
table, keyed by the label (minus the language code) with a value consisting of a Lua table
specifying the description text and the category's parents; (2) through handlers (pieces of
Lua code) added to the 'handlers' list, which recognize labels of a specific type (e.g.
'Cities in France') and generate the appropriate specification for that label on-the-fly.
]=]

local function lcfirst(label)
	return mw.getContentLanguage():lcfirst(label)
end

labels["places"] = {
	description = "{{{langname}}} names for geographical [[place]]s; [[toponym]]s.",
	parents = {"names", "list of sets"},
}

-- Generate bare labels in 'label' for all political subdivisions.
-- Do this before handling 'general_labels' so the latter can override if necessary.
for subdiv, desc in pairs(m_shared.political_subdivisions) do
	labels[subdiv] = {
		description = "{{{langname}}} names of " .. desc .. ".",
		parents = {"political subdivisions", "list of sets"},
	}
end

-- General labels. These are intended for places of all sorts that are not qualified
-- by a holonym (e.g. it does not include 'regions in Africa'). These also do not need
-- to include any political subdivisions listed in 'political_subdivisions' in
-- [[Module:place-data/shared]]. Each entry is {LABEL, DESCRIPTION, PARENTS, WPCAT, COMMONSCAT}.
-- PARENTS should not include "list of sets", which is added automatically.
-- OTHERPROPS is optional and is a table of 'additional', 'preceding', 'topright', 'umbrella', etc. fields.
local general_labels = {
	{"airports", "[[airport]]s", {"places"}},
	{"ancient settlements", "former [[city|cities]], [[town]]s and [[village]]s that existed in [[antiquity]]", {"historical settlements"}},
	{"atolls", "[[atoll]]s", {"islands"}},
	{"bays", "[[bay]]s", {"places", "water"}},
	{"beaches", "[[beach]]es", {"places", "water"}},
	{"bodies of water", "[[body of water|bodies of water]]", {"landforms", "water"}},
	{"boroughs", "[[borough]]s", {"polities"}},
	{"capital cities", "[[capital]] [[city|cities]]: the [[seat of government|seats of government]] for a country or [[political]] [[subdivision]] of a country", {"cities"}},
	{"census-designated places", "[[census-designated place]]s", {"places"}},
	{"cities", "[[city|cities]]", {"polities"}},
	{"city-states", "[[sovereign]] [[microstate]]s consisting of a single [[city]] and [[w:dependent territory|dependent territories]]", {"polities"}},
	{"communities", "[[community|communities]] of all sizes", {"polities"}},
	{"continents", "the [[continent]]s of the world", {"places"}},
	{"countries", "[[country|countries]]", {"polities"}},
	{"dependent territories", "[[w:dependent territory|dependent territories]]", {"polities"}},
	{"deserts", "[[desert]]s", {"places"}},
	{"forests", "[[forest]]s", {"places"}},
	{"ghost towns", "[[ghost town]]s", {"historical settlements"}},
	{"gulfs", "[[gulf]]s", {"places", "water"}},
	{"headlands", "[[headland]]s", {"places"}},
	{"historical and traditional regions", "regions that have no administrative significance", {"places"}},
	{"historical capitals", "former [[capital]] [[city|cities]] and [[town]]s", {"historical settlements"}},
	{"historical dependent territories", "[[w:dependent territory|dependent territories]] (colonies, dependencies, protectorates, etc.) that no longer exist", {"dependent territories"}},
	{"historical political subdivisions", "[[political]] [[subdivision]]s (states, provinces, counties, etc.) that no longer exist", {"polities"}},
	{"historical polities", "[[polity|polities]] (countries, kingdoms, empires, etc.) that no longer exist", {"polities"}},
	{"historical settlements", "[[city|cities]], [[town]]s and [[village]]s that no longer exist or have been merged or reclassified", {"historical polities"}},
	{"hills", "[[hill]]s", {"places"}},
	{"islands", "[[island]]s", {"places"}},
	{"kibbutzim", "[[kibbutz]]im", {"places"}},
	{"lakes", "[[lake]]s", {"places", "bodies of water"}},
	{"landforms", "[[landform]]s", {"places", "Earth"}},
	{"micronations", "[[micronation]]s", {"places"}},
	{"mountain passes", "[[mountain pass]]es", {"places"}},
	{"mountains", "[[mountain]]s", {"places"}},
	{"moors", "[[moor]]s", {"places"}},
	{"neighborhoods", "[[neighborhood]]s, [[district]]s and other subportions of a [[city]]", {"places"}},
	-- FIXME, is the following parent correct?
	{"oceans", "[[ocean]]s", {"Seas"}},
	{"parks", "[[park]]s", {"places"}},
	{"peninsulas", "[[peninsula]]s", {"places"}},
	{"plateaus", "[[plateau]]s", {"places"}},
	{"political subdivisions", "[[political]] [[subdivision]]s, such as [[province]]s, [[state]]s or [[region]]s", {"polities"}},
	{"polities", "[[polity|polities]] or [[political]] [[division]]s", {"places"}},
	{"rivers", "[[river]]s", {"places", "bodies of water"}},
	{"seas", "[[sea]]s", {"places", "bodies of water"}},
	{"straits", "[[strait]]s", {"places", "bodies of water"}},
	{"subdistricts", "[[subdistrict]]s", {"polities"}},
	{"suburbs", "[[suburb]]s of a [[city]]", {"places"}},
	{"towns", "[[town]]s", {"polities"}},
	{"townships", "[[township]]s", {"polities"}},
	{"unincorporated communities", "[[unincorporated]] [[community|communities]]", {"places"}},
	{"valleys", "[[valley]]s", {"places", "water"}},
	{"villages", "[[village]]s", {"polities"}},
	{"volcanoes", "[[volcano]]es", {"landforms"}},
	{"waterfalls", "[[waterfall]]s", {"landforms", "water"}},
	{"wetlands", "[[wetland]]s", {"places", "bodies of water"}},
}

-- Generate bare labels in 'label' for all "general labels" (see above).
for _, label_spec in ipairs(general_labels) do
	local label, desc, parents, commonscat, wpcat = unpack(label_spec)
	table.insert(parents, "list of sets")
	labels[label] = {
		description = "{{{langname}}} names of " .. desc .. ".",
		parents = parents,
		commonscat = commonscat == nil and true or commonscat,
		wpcat = wpcat == nil and true or wpcat,
	}
end

labels["city nicknames"] = {
	-- special-cased description
	description = "{{{langname}}} informal alternative names for [[city|cities]] (e.g., [[Big Apple]] for [[New York City]]).",
	parents = {"cities", "nicknames", "list of sets"},
}

labels["exonyms"] = {
	-- special-cased description
	description = "{{{langname}}} [[exonym]]s.",
	parents = {"places", "list of sets"},
}

-- Generate bare labels in 'label' for all polities (countries, states, etc.).
for _, group in ipairs(m_shared.polities) do
	for key, value in pairs(group.data) do
		group.bare_label_setter(labels, group, key, value)
	end
end

local function city_description(group, key, value)
	-- The purpose of all the following code is to construct the description. It's written in
	-- a general way to allow any number of containing polities, each larger than the previous one,
	-- so that e.g. for Birmingham, the description will read "{{{langname}}} terms related to the city of
	-- [[Birmingham]], in the county of the [[West Midlands]], in the [[constituent country]] of [[England]],
	-- in the [[United Kingdom]]."
	local bare_key, linked_key = m_shared.construct_bare_and_linked_version(key)
	local descparts = {}
	table.insert(descparts, "the city of " .. linked_key)
	local city_containing_polities = m_shared.get_city_containing_polities(group, key, value)
	local label_parent -- parent of the label, from the immediate containing polity
	for n, polity in ipairs(city_containing_polities) do
		local bare_polity, linked_polity = m_shared.construct_bare_and_linked_version(polity[1])
		if n == 1 then
			label_parent = bare_polity
		end
		table.insert(descparts, ", in ")
		if n < #city_containing_polities then
			local divtype = polity.divtype or group.default_divtype
			local pl_divtype = m_strutils.pluralize(divtype)
			local pl_linked_divtype = m_shared.political_subdivisions[pl_divtype]
			if not pl_linked_divtype then
				error("When creating city description for " .. key .. ", encountered divtype '" .. divtype .. "' not in m_shared.political_subdivisions")
			end
			local linked_divtype = m_strutils.singularize(pl_linked_divtype)
			table.insert(descparts, "the " .. linked_divtype .. " of ")
		end
		table.insert(descparts, linked_polity)
	end
	return table.concat(descparts), label_parent
end

-- Generate bare labels in 'label' for all cities.
for _, group in ipairs(m_shared.cities) do
	for key, value in pairs(group.data) do
		if not value.alias_of then
			local desc, label_parent = city_description(group, key, value)
			desc = "{{{langname}}} terms related to " .. desc .. "."
			local parents = value.parents or label_parent
			if not parents then
				error("When creating city bare label for " .. key .. ", at least one containing polity must be specified or an explicit parent must be given")
			end
			if type(parents) ~= "table" then
				parents = {parents}
			end
			local key_parents = {}
			for _, parent in ipairs(parents) do
				local polity_group, key_parent = m_shared.city_containing_polity_to_group_and_key(parent)
				if key_parent then
					local bare_key_parent, linked_key_parent =
						m_shared.construct_bare_and_linked_version(key_parent)
					table.insert(key_parents, bare_key_parent)
				else
					error("Couldn't find entry for city '" .. key .."' parent '" .. parent .. "'")
				end
			end

			labels[key] = {
				description = desc,
				parents = key_parents,
			}
		end
	end
end

-- Handler for "cities in the Bahamas", "rivers in Western Australia", etc.
-- Places that begin with "the" are recognized and handled specially.
table.insert(handlers, function(label)
	label = lcfirst(label)
	local place_type, place = label:match("^([a-z%- ]-) in (.*)$")
	if place_type and m_shared.generic_place_types[place_type] then
		for _, group in ipairs(m_shared.polities) do
			local placedata = group.data[place]
			if placedata then
				placedata = group.value_transformer(group, place, placedata)
				local allow_cat = true
				if place_type == "neighborhoods" and placedata.british_spelling or
					place_type == "neighbourhoods" and not placedata.british_spelling then
					allow_cat = false
				end
				if placedata.is_former_place and place_type ~= "places" then
					allow_cat = false
				end
				if placedata.is_city and not m_shared.generic_place_types_for_cities[place_type] then
					allow_cat = false
				end
				if allow_cat then
					local parent
					if placedata.containing_polity then
						parent = place_type .. " in " .. placedata.containing_polity
					elseif place_type == "neighbourhoods" then
						parent = "neighborhoods"
					else
						parent = place_type
					end
					local bare_place, linked_place = m_shared.construct_bare_and_linked_version(place)
					local keydesc = placedata.keydesc or linked_place
					local parents
					if place_type == "places" then
						parents = {{name = parent, sort = bare_place}, bare_place, "list of sets"}
					else
						parents = {{name = parent, sort = bare_place}, bare_place, "list of sets", "places in " .. place}
					end
					return {
						description = "{{{langname}}} names of " .. m_shared.generic_place_types[place_type] .. " in " .. keydesc .. ".",
						parents = parents
					}
				end
			end
		end
	end
end)

-- Handler for "places in Paris", "neighbourhoods of Paris", etc.
table.insert(handlers, function(label)
	label = lcfirst(label)
	local place_type, in_of, city = label:match("^(places) (in) (.*)$")
	if not place_type then
		place_type, in_of, city = label:match("^([a-z%- ]-) (of) (.*)$")
	end
	if place_type and m_shared.generic_place_types_for_cities[place_type] then
		for _, group in ipairs(m_shared.cities) do
			local city_data = group.data[city]
			if city_data then
				local spelling_matches = true
				if place_type == "neighborhoods" or place_type == "neighbourhoods" then
					local containing_polities = m_shared.get_city_containing_polities(group, city, city_data)
					local polity_group, polity_key = m_shared.city_containing_polity_to_group_and_key(
						containing_polities[1])
					if not polity_key then
						error("Can't find polity data for city '" .. place ..
							"' containing polity '" .. containing_polities[1] .. "'")
					end
					local polity_value = polity_group.value_transformer(polity_group, polity_key, polity_group[polity_key])

					if place_type == "neighborhoods" and polity_value.british_spelling or
						place_type == "neighbourhoods" and not polity_value.british_spelling then
						spelling_matches = false
					end
				end
				if spelling_matches then
					local parents
					if place_type == "places" then
						parents = {city, "list of sets"}
					else
						parents = {city, "list of sets", "places in " .. city}
					end
					local desc = city_description(group, city, city_data)
					return {
						description = "{{{langname}}} names of " .. m_shared.generic_place_types_for_cities[place_type] .. " " .. in_of .. " " .. desc .. ".",
						parents = parents
					}
				end
			end
		end
	end
end)

-- Handler for "political subdivisions of the Philippines" and other "political subdivisions of X" categories.
table.insert(handlers, function(label)
	label = lcfirst(label)
	local place = label:match("^political subdivisions of (.*)$")
	if place then
		for _, group in ipairs(m_shared.polities) do
			local placedata = group.data[place]
			if placedata then
				placedata = group.value_transformer(group, place, placedata)
				local bare_place, linked_place = m_shared.construct_bare_and_linked_version(place)
				local keydesc = placedata.keydesc or linked_place
				local desc = "{{{langname}}} names of [[political]] [[subdivision]]s of " .. keydesc .. "."
				return {
					description = desc,
					breadcrumb = "political subdivisions",
					parents = {bare_place, {name = "political subdivisions", sort = bare_place}, "list of sets"},
				}
			end
		end
	end
end)

-- Handler for "provinces of the Philippines", "counties of Wales", "municipalities of Tocantins, Brazil", etc.
-- Places that begin with "the" are recognized and handled specially.
table.insert(handlers, function(label)
	label = lcfirst(label)
	local place_type, place = label:match("^([a-z%- ]-) of (.*)$")
	if place then
		for _, group in ipairs(m_shared.polities) do
			local placedata = group.data[place]
			if placedata then
				placedata = group.value_transformer(group, place, placedata)
				local divcat = nil
				local poldiv_parent = nil
				if placedata.poldiv then
					for _, div in ipairs(placedata.poldiv) do
						if type(div) == "string" then
							div = {div}
						end
						if place_type == div[1] then
							divcat = "poldiv"
							poldiv_parent = div.parent
							break
						end
					end
				end
				if not divcat and placedata.miscdiv then
					for _, div in ipairs(placedata.miscdiv) do
						if type(div) == "string" then
							div = {div}
						end
						if place_type == div[1] then
							divcat = "miscdiv"
							break
						end
					end
				end
				if divcat then
					local linkdiv = m_shared.political_subdivisions[place_type]
					if not linkdiv then
						error("Saw unknown place type '" .. place_type .. "' in label '" .. label .. "'")
					end
					local bare_place, linked_place = m_shared.construct_bare_and_linked_version(place)
					local keydesc = placedata.keydesc or linked_place
					local desc = "{{{langname}}} names of " .. linkdiv .. " of " .. keydesc .. "."
					if divcat == "poldiv" then
						return {
							description = desc,
							breadcrumb = place_type,
							parents = poldiv_parent and
								{{name = poldiv_parent, sort = bare_place}, bare_place, "list of sets"} or
								{"political subdivisions of " .. place, {name = place_type, sort = bare_place}, "list of sets"},
						}
					else
						return {
							description = desc,
							breadcrumb = place_type,
							parents = {bare_place, "list of sets"},
						}
					end
				end
			end
		end
	end
end)

-- Generate bare labels in 'label' for all types of capitals.
for capital_cat, placetype in pairs(m_shared.capital_cat_to_placetype) do
	local pl_placetype = m_strutils.pluralize(placetype)
	local linkdiv = m_shared.political_subdivisions[pl_placetype]
	if not linkdiv then
		error("Saw unknown place type '" .. pl_placetype .. "' in label '" .. label .. "'")
	end
	labels[capital_cat] = {
		description = "{{{langname}}} names of [[capital]]s of " .. linkdiv .. ".",
		parents = {"capital cities", "list of sets"},
	}
end

-- Handler for "state capitals of the United States", "provincial capitals of Canada", etc.
-- Places that begin with "the" are recognized and handled specially.
table.insert(handlers, function(label)
	label = lcfirst(label)
	local capital_cat, place = label:match("^([a-z%- ]- capitals) of (.*)$")
	-- Make sure we recognize the type of capital.
	if place and m_shared.capital_cat_to_placetype[capital_cat] then
		local placetype = m_shared.capital_cat_to_placetype[capital_cat]
		local pl_placetype = m_strutils.pluralize(placetype)
		-- Locate the containing polity, fetch its known political subdivisions, and make sure
		-- the placetype corresponding to the type of capital is among the list.
		for _, group in ipairs(m_shared.polities) do
			local placedata = group.data[place]
			if placedata then
				placedata = group.value_transformer(group, place, placedata)
				if placedata.poldiv then
					local saw_match = false
					local variant_matches = {}
					for _, div in ipairs(placedata.poldiv) do
						if type(div) == "string" then
							div = {div}
						end
						-- HACK. Currently if we don't find a match for the placetype, we map e.g.
						-- 'autonomous region' -> 'regional capitals' and 'union territory' -> 'territorial capitals'.
						-- When encountering a political subdivision like 'autonomous region' or
						-- 'union territory', chop off everything up through a space to make things match.
						-- To make this clearer, we record all such "variant match" cases, and down below we
						-- insert a note into the category text indicating that such "variant matches"
						-- are included among the category.
						if pl_placetype == div[1] or pl_placetype == div[1]:gsub("^.* ", "") then
							saw_match = true
							if pl_placetype ~= div[1] then
								table.insert(variant_matches, div[1])
							end
						end
					end
					if saw_match then
						-- Everything checks out, construct the category description.
						local linkdiv = m_shared.political_subdivisions[pl_placetype]
						if not linkdiv then
							error("Saw unknown place type '" .. pl_placetype .. "' in label '" .. label .. "'")
						end
						local bare_place, linked_place = m_shared.construct_bare_and_linked_version(place)
						local keydesc = placedata.keydesc or linked_place
						local variant_match_text = ""
						if #variant_matches > 0 then
							for i, variant_match in ipairs(variant_matches) do
								variant_matches[i] = m_shared.political_subdivisions[variant_match]
								if not variant_matches[i] then
									error("Saw unknown place type '" .. variant_match .. "' in label '" .. label .. "'")
								end
							end
							variant_match_text = " (including " .. require("Module:table").serialCommaJoin(variant_matches) .. ")"
						end
						local desc = "{{{langname}}} names of [[capital]]s of " .. linkdiv .. variant_match_text .. " of " .. keydesc .. "."
						return {
							description = desc,
							parents = {{name = capital_cat, sort = bare_place}, bare_place, "list of sets"},
						}
					end
				end
			end
		end
	end
end)

-- "regions in (continent)", esp. for regions that span multiple countries

labels["regions in the world"] = { -- for multinational regions which do not fit neatly within one continent
	description = "{{{langname}}} names of [[region]]s in the world (which do not fit neatly within one country or continent).",
	parents = {"places", "list of sets"},
}

labels["regions in Africa"] = {
	description = "{{{langname}}} names of [[region]]s in Africa.",
	parents = {"Africa", "list of sets"},
}

labels["regions in the Americas"] = {
	description = "{{{langname}}} names of [[region]]s in the Americas.",
	parents = {"America", "list of sets"},
}

labels["regions in Asia"] = {
	description = "{{{langname}}} names of [[region]]s in Asia.",
	parents = {"Asia", "list of sets"},
}

labels["regions in Europe"] = { 
	description = "{{{langname}}} names of [[region]]s in Europe.",
	parents = {"Europe", "list of sets"},
}

-- "countries in (continent)", "rivers in (continent)"

for _, continent in ipairs({"Africa", "Asia", "Central America", "Europe", "North America", "Oceania", "South America"}) do
	labels["countries in " .. continent] = {
		description = "{{{langname}}} names of [[country|countries]] in [[" .. continent .. "]].",
		parents = {{name = "countries", sort = " "}, continent, "list of sets"},
	}
	labels["rivers in " .. continent] = {
		description = "{{{langname}}} names of [[river]]s in [[" .. continent .. "]].",
		parents = {{name = "rivers", sort = " "}, continent, "list of sets"},
	}
end

-- autonomous communities, oblasts, etc

labels["autonomous communities of Spain"] = {
	-- special-cased description
	description = "{{{langname}}} names of the [[w:Autonomous communities of Spain|autonomous communities of Spain]].",
	parents = {{name = "political subdivisions", sort = "Spain"}, "Spain", "list of sets"},
}

labels["autonomous cities of Spain"] = {
	-- special-cased description
	description = "{{{langname}}} names of the [[w:Autonomous communities of Spain#Autonomous_cities|autonomous cities of Spain]].",
	parents = {{name = "political subdivisions", sort = "Spain"}, "Spain", "list of sets"},
}

-- boroughs

labels["boroughs in England"] = {
	description = "{{{langname}}} names of boroughs, local government districts and unitary authorities in [[England]].", 
	parents = {{name = "boroughs", sort = "England"}, "England", "list of sets"},
}

labels["boroughs in Pennsylvania, USA"] = {
	description = "{{{langname}}} names of boroughs in [[Pennsylvania]], USA.",
	parents = {{name = "boroughs in the United States", sort = "Pennsylvania"}, "Pennsylvania, USA", "list of sets"},
}

labels["boroughs in New Jersey, USA"] = {
	description = "{{{langname}}} names of boroughs in [[New Jersey]], USA.",
	parents = {{name = "boroughs in the United States", sort = "New Jersey"}, "New Jersey, USA", "list of sets"},
}

labels["boroughs in New York City"] = {
	description = "{{{langname}}} names of boroughs in [[New York City]].",
	parents = {{name = "boroughs in the United States", sort = "New York City"}, "New York City", "list of sets"},
}

labels["boroughs in the United States"] = {
	description = "{{{langname}}} names of [[borough]]s in the [[United States]].",
	-- parent is "boroughs" not "political subdivisions" and category says "in"
	-- not "of", because boroughs aren't really political subdivisions in the US
	-- (more like cities)
	parents = {{name = "boroughs", sort = "United States"}, "United States", "list of sets"},
}

-- census-designated places

labels["census-designated places in the United States"] = {
	description = "{{{langname}}} names of [[census-designated place]]s in the [[United States]].",
	-- parent is just United States; census-designated places have no political
	-- status and exist only in the US, so no need for a top-level
	-- "census-designated places" category
	parents = {"United States", "list of sets"},
}

-- counties

labels["counties of Northern Ireland"] = {
	description = "{{{langname}}} names of the counties of [[Northern Ireland]].",
	-- has two parents: "political subdivisions" and "counties of Ireland"
	parents = {{name = "political subdivisions", sort = "Northern Ireland"}, {name = "counties of Ireland", sort = "Northern Ireland"}, "Northern Ireland", "list of sets"},
}

-- nomes

labels["nomes of Ancient Egypt"] = {
	-- special-cased description
	description = "{{{langname}}} names of the nomes of [[Ancient Egypt]].",
	parents = {{name = "political subdivisions", sort = "Egypt"}, "Ancient Egypt", "list of sets"},
}

-- regions and "regional units"

labels["regions of Albania"] = {
	-- special-cased description
	description = "{{{langname}}} names of the regions (peripheries) of [[Albania]].",
	parents = {{name = "political subdivisions", sort = "Albania"}, "Albania", "list of sets"},
}

labels["regions of Greece"] = {
	-- special-cased description
	description = "{{{langname}}} names of the regions (peripheries) of [[Greece]].",
	parents = {{name = "political subdivisions", sort = "Greece"}, "Greece", "list of sets"},
}

labels["regions of North Macedonia"] = {
	-- special-cased description
	description = "{{{langname}}} names of the regions (peripheries) of [[North Macedonia]].",
	parents = {{name = "political subdivisions", sort = "North Macedonia"}, "North Macedonia", "list of sets"},
}

-- subdistricts and subprefectures

labels["subdistricts of Jakarta"] = {
	description = "default-set",
	-- not listed in the normal place because no categories like "cities in Jakarta"
	parents = {{name = "political subdivisions", sort = "Jakarta"}, "Indonesia", "list of sets"},
}

labels["subprefectures of Japan"] = {
	-- special-cased description
	description = "{{{langname}}} names of subprefectures of Japanese prefectures.",
	parents = {{name = "political subdivisions", sort = "Japan"}, "Japan", "list of sets"},
}

-- towns and townships

labels["townships in Canada"] = {
	description = "{{{langname}}} names of townships in [[Canada]].",
	parents = {{name = "townships", sort = "Canada"}, "Canada", "list of sets"},
}

labels["townships in Ontario"] = {
	description = "{{{langname}}} names of townships in [[Ontario]]. Municipalities in Ontario can be called as a city, a town, a township, or a village.",
	parents = {{name = "townships in Canada", sort = "Ontario"}, "Ontario", "list of sets"},
}

labels["townships in Quebec"] = {
	description = "{{{langname}}} names of townships in [[Quebec]].",
	parents = {{name = "townships in Canada", sort = "Quebec"}, "Quebec", "list of sets"},
}

-- temporary while users adjust to recent changes, also kept in case of desire to use for its topical purpose, see description; can be removed later if unused

labels["place names"] = {
	description = "{{{langname}}} terms like ''hydronym'', for names for geographical [[place]]s.",
	parents = {"names", "list of sets"},
}

return {LABELS = labels, HANDLERS = handlers}
