local labels = {}
local handlers = {}

local m_shared = require("Module:place/shared-data")
local m_strutils = require("Module:string utilities")

--[=[

This module contains specifications that are used to create labels that allow {{auto cat}} and
{{topic cat}} to create the appropriate definitions for topic categories for places (e.g.
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


-- general labels

-- Each entry is {LABEL, DESCRIPTION, PARENTS}.
local general_labels = {
	{"atolls", "[[atoll]]s", {"islands"}},
	{"bays", "[[bay]]s", {"places", "water"}},
	{"boroughs", "[[borough]]s", {"polities"}},
	{"capital cities", "[[capital]] [[city|cities]]: the [[seat of government|seats of government]] for a country", {"cities"}},
	{"census-designated places", "[[census-designated place]]s", {"places"}},
	{"cities", "[[city|cities]], [[town]]s and [[village]]s of all sizes", {"polities"}},
	{"communities", "[[community|communities]] of all sizes", {"polities"}},
	{"continents", "the [[continents]] of the world", {"places"}},
	{"countries", "[[country|countries]]", {"polities"}},
	{"dependencies", "[[dependency|dependencies]]", {"polities"}},
	{"deserts", "[[desert]]s", {"places"}},
	{"forests", "[[forest]]s", {"places"}},
	{"gulfs", "[[gulf]]s", {"places", "water"}},
	{"headlands", "[[headland]]s", {"places"}},
	{"historical and traditional regions", "regions that have no administrative significance", {"places"}},
	{"historical political subdivisions", "[[political]] [[subdivision]]s (states, provinces, counties, etc.) that no longer exist", {"polities"}},
	{"historical polities", "[[polity|polities]] (countries, kingdoms, empires, etc.) that no longer exist", {"polities"}},
	{"hills", "[[hill]]s", {"places"}},
	{"islands", "[[island]]s", {"places"}},
	{"kibbutzim", "[[kibbutz]]im", {"places"}},
	{"lakes", "[[lake]]s", {"places", "water"}},
	{"landforms", "[[landform]]s", {"Earth"}},
	{"mountains", "[[mountain]]s", {"places"}},
	-- FIXME, is the following parent correct?
	{"oceans", "[[ocean]]s", {"Seas"}},
	{"peninsulas", "[[peninsula]]s", {"places"}},
	{"plateaus", "[[plateau]]s", {"places"}},
	{"political subdivisions", "[[political]] [[subdivision]]s, such as [[province]]s, [[state]]s or [[region]]s", {"polities"}},
	{"polities", "[[polity|polities]] or [[political]] [[division]]s", {"places"}},
	{"provinces", "[[province]]s", {"political subdivisions"}},
	{"rivers", "[[river]]s", {"places", "water"}},
	{"seas", "[[sea]]s", {"places", "water"}},
	{"straits", "[[strait]]s", {"places", "water"}},
	{"subdistricts", "[[subdistrict]]s", {"polities"}},
	{"towns", "[[town]]s", {"polities"}},
	{"townships", "[[township]]s", {"polities"}},
	{"unincorporated communities", "[[unincorporated]] [[community|communities]]", {"places"}},
	{"valleys", "[[valley]]s", {"places", "water"}},
	{"villages", "[[village]]s", {"polities"}},
	{"waterfalls", "[[waterfall]]s", {"landforms", "water"}},
}

for _, label_spec in ipairs(general_labels) do
	local label, desc, parents = unpack(label_spec)
	table.insert(parents, "list of sets")
	labels[label] = {
		description = "{{{langname}}} names of " .. desc .. ".",
		parents = parents,
	}
end

labels["city nicknames"] = {
	-- special-cased description
	description = "{{{langname}}} informal alternative names for [[city|cities]] (e.g., [[Big Apple]] for [[New York City]]).",
	parents = {"cities", "list of sets"},
}

labels["exonyms"] = {
	-- special-cased description
	description = "{{{langname}}} [[exonym]]s.",
	parents = {"places", "list of sets"},
}

for _, group in ipairs(m_shared.places) do
	for key, value in pairs(group.data) do
		group.bare_label_setter(labels, group, key, value)
	end
end

-- Handler for "cities in the Bahamas", "rivers in Western Australia", etc.
-- Places that begin with "the" are recognized and handled specially.
table.insert(handlers, function(label)
	label = lcfirst(label)
	local place_type, place = label:match("^([a-z%- ]-) in (.*)$")
	if place_type and m_shared.generic_place_types[place_type] then
		for _, group in ipairs(m_shared.places) do
			local placedata = group.data[place]
			if placedata then
				placedata = group.value_transformer(group, place, placedata)
				if not placedata.nocities then
					local parent = not placedata.containing_polity and place_type or place_type .. " in " .. placedata.containing_polity
					local bare_place, linked_place = m_shared.construct_bare_and_linked_version(place)
					local keydesc = placedata.keydesc or linked_place
					return {
						description = "{{{langname}}} names of " .. m_shared.generic_place_types[place_type] .. " in " .. keydesc .. ".",
						parents = {{name = parent, sort = bare_place}, bare_place, "list of sets"},
					}
				end
			end
		end
	end
end)

-- Handler for "provinces of the Philippines", "counties of Wales", etc.
-- Places that begin with "the" are recognized and handled specially.
table.insert(handlers, function(label)
	label = lcfirst(label)
	local place_type, place = label:match("^([a-z%- ]-) of (.*)$")
	if place then
		for _, group in ipairs(m_shared.places) do
			local placedata = group.data[place]
			if placedata then
				placedata = group.value_transformer(group, place, placedata)
				local divcat = nil
				if placedata.poldiv then
					for _, div in ipairs(placedata.poldiv) do
						if place_type == div then
							divcat = "poldiv"
							break
						end
					end
				end
				if not divcat and placedata.miscdiv then
					for _, div in ipairs(placedata.miscdiv) do
						if place_type == div then
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
							parents = {{name = "political subdivisions", sort = bare_place}, bare_place, "list of sets"},
						}
					else
						return {
							description = desc,
							parents = {bare_place, "list of sets"},
						}
					end
				end
			end
		end
	end
end)

-- Handler for "counties of Alabama", "parishes of Louisiana", etc.
table.insert(handlers, function(label)
	label = lcfirst(label)
	local county_type, state = label:match("^([a-z ]-) of (.*)$")
	if state then
		local state_desc = m_shared.US_states[state .. ", USA"]
		if state_desc then
			local expected_county_type = state_desc.county_type or "counties"
			local linked_county_type = m_shared.political_subdivisions[expected_county_type]
			if county_type == expected_county_type then
				return {
					description = "{{{langname}}} names of " .. linked_county_type .. " of [[" .. state .. "]], a state of the [[United States]].",
					parents = {{name = "counties of the United States",
						sort = state}, state .. ", USA", "list of sets"},
				}
			end
		end
	end
end)

-- Handler for "county seats of Alabama", "parish seats of Louisiana", etc.
table.insert(handlers, function(label)
	label = lcfirst(label)
	local seat_type, state = label:match("^([a-z ]-) of (.*)$")
	if state then
		local state_desc = m_shared.US_states[state .. ", USA"]
		if state_desc then
			local expected_county_type = state_desc.county_type or "counties"
			local expected_seat_type = m_strutils.singularize(expected_county_type) .. " seats"
			local linked_seat_type = m_shared.political_subdivisions[expected_seat_type]
			if seat_type == expected_seat_type then
				return {
					description = "{{{langname}}} names of " .. linked_seat_type .. " of [[" .. state .. "]], a state of the [[United States]].",
					parents = {{name = "county seats of the United States",
						sort = state}, state .. ", USA", "list of sets"},
				}
			end
		end
	end
end)

-- Handler for "municipalities of Tocantins, Brazil", etc.
table.insert(handlers, function(label)
	label = lcfirst(label)
	local state = label:match("^municipalities of (.*), Brazil$")
	if state and m_shared.brazilian_states[state .. ", Brazil"] then
		return {
			description = "{{{langname}}} names of [[municipality|municipalities]] of [[" .. state .. "]], a state of [[Brazil]].",
			parents = {{name = "municipalities of Brazil", sort = state}, state .. ", Brazil", "list of sets"},
		}
	end
end)

-- Handler for "municipalities of Cebu, Philippines", etc.
table.insert(handlers, function(label)
	label = lcfirst(label)
	local province = label:match("^municipalities of (.*), Philippines$")
	if province and m_shared.philippine_provinces[province .. ", Philippines"] then
		return {
			description = "{{{langname}}} names of [[municipality|municipalities]] of [[" .. province .. "]], a province of the [[Philippines]].",
			parents = {{name = "municipalities of the Philippines", sort = province}, province .. ", Philippines", "list of sets"},
		}
	end
end)

-- Handler for "municipalities of Upper Austria" and other Austrian states.
table.insert(handlers, function(label)
	label = lcfirst(label)
	local state = label:match("^municipalities of (.*)$")
	if state and m_shared.austrian_states[state] then
		return {
			description = "{{{langname}}} names of [[municipality|municipalities]] of [[" .. state .. "]], a state of [[Austria]].",
			parents = {{name = "municipalities of Austria", sort = state}, state, "list of sets"},
		}
	end
end)

-- Handler for "municipalities of Ostrobothnia, Finland", etc.
table.insert(handlers, function(label)
	label = lcfirst(label)
	local region = label:match("^municipalities of (.*), Finland$")
	if region and m_shared.finnish_regions[region .. ", Finland"] then
		return {
			description = "{{{langname}}} names of [[municipality|municipalities]] of [[" .. region .. "]], a region of [[Finland]].",
			parents = {{name = "municipalities of Finland", sort = region}, region .. ", Finland", "list of sets"},
		}
	end
end)

labels["Hokkaido"] = {
	description = "{{{langname}}} terms related to [[Hokkaido]], a [[prefecture]] of [[Japan]].",
	parents = {"Prefectures of Japan"},
}

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
		parents = {{name = "countries", sort = continent}, continent, "list of sets"},
	}
	labels["rivers in " .. continent] = {
		description = "{{{langname}}} names of [[river]]s in [[" .. continent .. "]].",
		parents = {{name = "rivers", sort = continent}, continent, "list of sets"},
	}
end

-- autonomous communities, oblasts, etc

labels["autonomous communities of Spain"] = {
	-- special-cased description
	description = "{{{langname}}} names of the [[w:Autonomous communities of Spain|autonomous communities of Spain]].",
	parents = {{name = "political subdivisions", sort = "Spain"}, "Spain", "list of sets"},
}

-- boroughs

labels["boroughs in England"] = {
	description = "{{{langname}}} names of boroughs, local government districts and unitary authorities in [[England]].", 
	parents = {{name = "boroughs", sort = "England"}, "England", "list of sets"},
}

labels["boroughs in Pennsylvania"] = {
	description = "{{{langname}}} names of boroughs in [[Pennsylvania]].",
	parents = {{name = "boroughs in the United States", sort = "Pennsylvania"}, "Pennsylvania, USA", "list of sets"},
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

-- cities

labels["cities in Hokkaido"] = {
	-- special-cased description
	description = "{{{langname}}} names of cities in [[Hokkaido]] Prefecture.",
	parents = {{name = "cities in Japan", sort = "Hokkaido"}, "Hokkaido", "list of sets"},
}

labels["cities in Tokyo"] = {
	-- special-cased description
	description = "{{{langname}}} names of cities in [[Tokyo]] Metropolis.",
	parents = {{name = "cities in Japan", sort = "Tokyo"}, "Tokyo", "list of sets"},
}

-- counties

labels["counties of Northern Ireland"] = {
	description = "{{{langname}}} names of the counties of [[Northern Ireland]]",
	-- has two parents: "political subdivisions" and "counties of Ireland"
	parents = {{name = "political subdivisions", sort = "Northern Ireland"}, {name = "counties of Ireland", sort = "Northern Ireland"}, "Northern Ireland", "list of sets"},
}

--Canadian counties
-- only these five provinces have counties
for _, province in ipairs({"New Brunswick", "Nova Scotia", "Ontario", "Prince Edward Island", "Quebec"}) do
	labels["counties of " .. province] = {
		description = "default-set",
		parents = {{name ="counties of Canada", sort = province}, province, "list of sets"},
	}
end

-- places (that defy categorization as villages, towns, etc)
-- is this useful?

for _, place in ipairs({"Greece", "England", {"Ireland", "the republic of [[Ireland]]"}, "Scotland", "Wales"}) do
	local linked_place
	if type(place) == "table" then
		place, linked_place = unpack(place)
	else
		linked_place = "[[" .. place .. "]]"
	end
	labels["places in " .. place] = {
		description = "{{{langname}}} names of places in " .. linked_place .. " that are not readily classifiable as villages, towns, cities, counties, regions, etc.",
		parents = {place, "list of sets"},
	}
end

-- regions and "regional units"

labels["regions of Greece"] = {
	-- special-cased description
	description = "{{{langname}}} names of the regions (peripheries) of [[Greece]]",
	parents = {{name = "political subdivisions", sort = "Greece"}, "Greece", "list of sets"},
}

-- subdistricts and subprefectures

labels["subdistricts of Jakarta"] = {
	description = "default-set",
	-- not listed in the normal place because no categories like "cities in Jakarta"
	parents = {{name = "political subdivisions", sort = "Jakarta"}, "Indonesia", "list of sets"},
}

labels["subprefectures of Hokkaido"] = {
	description = "{{{langname}}} names of subprefectures of [[Hokkaido]] Prefecture.",
	parents = {{name = "subprefectures of Japan", sort = "Hokkaido"}, "Hokkaido", "list of sets"},
}

labels["subprefectures of Japan"] = {
	-- special-cased description
	description = "{{{langname}}} names of subprefectures of Japanese prefectures.",
	parents = {{name = "political subdivisions", sort = "Japan"}, "Japan", "list of sets"},
}

labels["subprefectures of Tokyo"] = {
	description = "{{{langname}}} names of subprefectures of [[Tokyo]] Metropolis.",
	parents = {{name = "subprefectures of Japan", sort = "Tokyo"}, "Tokyo", "list of sets"},
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

-- misc to be sorted; putting here so old module can be deleted

labels["special wards of Tokyo, Japan"] = {
	description = "{{{langname}}} names of special wards of [[Tokyo]] Metropolis, [[Japan]].",
	parents = {{name = "political subdivisions", sort = "Tokyo"}, "Tokyo", "list of sets"},
}

-- temporary while users adjust to recent changes, also kept in case of desire to use for its topical purpose, see description; can be removed later if unused

labels["place names"] = {
	description = "{{{langname}}} terms like ''hydronym'', for names for geographical [[place]]s.",
	parents = {"names", "list of sets"},
}

return {LABELS = labels, HANDLERS = handlers}
