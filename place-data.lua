local export = {}

local m_shared = require("Module:place/shared-data")
local m_links = require("Module:links")
local m_strutils = require("Module:string utilities")

local function ucfirst(label)
	return mw.getContentLanguage():ucfirst(label)
end

local function lc(label)
	return mw.getContentLanguage():lc(label)
end


-- This is a map from aliases to their canonical forms. Any placetypes appearing
-- as keys here will be mapped to their canonical forms in all respects, including
-- the display form. Contrast 'placetype_equivs', which apply to categorization and
-- other processes but not to display.
export.placetype_aliases = {
	["c"] = "country",
	["cc"] = "constituent country",
	["p"] = "province",
	["ap"] = "autonomous province",
	["r"] = "region",
	["ar"] = "autonomous region",
	["sar"] = "special administrative region",
	["s"] = "state",
	["arch"] = "archipelago",
	["bor"] = "borough",
	["can"] = "canton",
	["cdp"] = "census-designated place",
	["CDP"] = "census-designated place",
	["co"] = "county",
	["cobor"] = "county borough",
	["coll"] = "collectivity",
	["comm"] = "community",
	["acomm"] = "autonomous community",
	["cont"] = "continent",
	["dept"] = "department",
	["dist"] = "district",
	["div"] = "division",
	["isl"] = "island",
	["lbor"] = "London borough",
	["metbor"] = "metropolitan borough",
	["mun"] = "municipality",
	["obl"] = "oblast",
	["aobl"] = "autonomous oblast",
	["okr"] = "okrug",
	["aokr"] = "autonomous okrug",
	["par"] = "parish",
	["pen"] = "peninsula",
	["pref"] = "prefecture",
	["apref"] = "autonomous prefecture",
	["rep"] = "republic",
	["arep"] = "autonomous republic",
	["riv"] = "river",
	["terr"] = "territory",
	["aterr"] = "autonomous territory",
	["uterr"] = "union territory",
	["twp"] = "township",
	["voi"] = "voivodeship",
	["range"] = "mountain range",
	["departmental capital"] = "department capital",
	["home-rule city"] = "home rule city",
	["home-rule municipality"] = "home rule municipality",
	["sub-provincial city"] = "subprovincial city",
}


-- These qualifiers can be prepended onto any placetype and will be handled correctly.
-- For example, the placetype "large city" will be displayed as such but otherwise
-- treated exactly as if "city" were specified. Links will be added to the remainder
-- of the placetype as appropriate, e.g. "small voivodeship" will display as
-- "small [[voivoideship]]" because "voivoideship" has an entry in placetype_links.
-- If the value is a string, the qualifier will display according to the string.
-- Note that these qualifiers do not override placetypes with entries elsewhere that
-- contain those same qualifiers. For example, the entry for "former colony" in
-- placetype_equivs will apply in preference to treating "former colony" as equivalent
-- to "colony". Also note that if an entry like "former colony" appears in either
-- placetype_equivs or cat_data, the non-qualifier portion won't automatically be
-- linked, so it needs to be specifically included in placetype_links if linking is
-- desired.
export.placetype_qualifiers = {
	["small"] = true,
	["large"] = true,
	["major"] = true,
	["minor"] = true,
	["tiny"] = true,
	["short"] = true,
	["long"] = true,
	["important"] = true,
	["former"] = true,
	["ancient"] = true,
	["historic"] = true,
	["historical"] = "historic",
	["maritime"] = true,
	["coastal"] = true,
	["seaside"] = "coastal",
	["inland"] = true,
	["incorporated"] = "[[incorporated]]",
	["unincorporated"] = "[[unincorporated]]",
}


-- If there's an entry here, the corresponding placetype will use the text of the
-- value, which should be used to add links. If the value is true, a simple link
-- will be added around the whole placetype. If the value is "w", a link to
-- Wikipedia will be added around the whole placetype.
export.placetype_links = {
	["administrative capital"] = "w",
	["administrative county"] = "w",
	["administrative district"] = "w",
	["administrative region"] = true,
	["administrative village"] = "w",
	["archipelago"] = true,
	["associated province"] = "[[associated]] [[province]]",
	["atoll"] = true,
	["autonomous community"] = true,
	["autonomous oblast"] = true,
	["autonomous okrug"] = true,
	["autonomous prefecture"] = true,
	["autonomous province"] = "w",
	["autonomous region"] = "w",
	["autonomous republic"] = "w",
	["autonomous territory"] = "w",
	["bailiwick"] = true,
	["bay"] = true,
	["bishopric"] = true,
	["borough"] = true,
	["borough seat"] = true,
	["canton"] = true,
	["cape"] = true,
	["census-designated place"] = true,
	["civil parish"] = true,
	["collectivity"] = true,
	["commandery"] = true,
	["commonwealth"] = true,
	["commune"] = true,
	["community"] = true,
	["constituent country"] = true,
	["contregion"] = "[[continental]] region",
	["council area"] = true,
	["county-administered city"] = "w",
	["county-level city"] = "w",
	["county borough"] = true,
	["county seat"] = true,
	["crown dependency"] = "w",
	["department"] = true,
	["department capital"] = "[[department]] [[capital]]",
	["dependency"] = true,
	["dependent territory"] = "w",
	["distributary"] = true,
	["district"] = true,
	["district capital"] = "[[district]] [[capital]]",
	["division"] = true,
	["duchy"] = true,
	["empire"] = true,
	["external territory"] = "[[external]] [[territory]]",
	["federal city"] = "w",
	["federal subject"] = "w",
	["federal territory"] = "w",
	["former autonomous territory"] = "former [[w:autonomous territory|autonomous territory]]",
	["former colony"] = "former [[colony]]",
	["former maritime republic"] = "former [[maritime republic]]",
	["former polity"] = "former [[polity]]",
	["former separatist state"] = "former [[separatist]] [[state]]",
	["geographical region"] = "w",
	["ghost town"] = true,
	["governorate"] = true,
	["gulf"] = true,
	["hamlet"] = true,
	["harbor town"] = "[[harbor]] [[town]]",
	["harbour town"] = "[[harbour]] [[town]]",
	["headland"] = true,
	["historical region"] = "w",
	["home rule city"] = "w",
	["home rule municipality"] = "w",
	["independent city"] = true,
	["inner-city area"] = "[[inner-city]] area",
	["island country"] = "w",
	["island municipality"] = "w",
	["judicial capital"] = "w",
	["kibbutz"] = true,
	["krai"] = true,
	["legislative capital"] = "[[legislative]] [[capital]]",
	["local government district"] = "w",
	["local government district with borough status"] = "[[w:local government district|local government district]] with [[w:borough status|borough status]]",
	["London borough"] = "w",
	["macroregion"] = true,
	["marginal sea"] = true,
	["market town"] = true,
	["metropolitan borough"] = true,
	["mountain indigenous township"] = "[[mountain]] [[indigenous]] [[township]]",
	["mountain range"] = true,
	["mountainous region"] = "[[mountainous]] [[region]]",
	["municipal district"] = "w",
	["municipality"] = true,
	["municipality with city status"] = "[[municipality]] with [[w:city status|city status]]",
	["oblast"] = true,
	["overseas collectivity"] = "w",
	["overseas department"] = "w",
	["overseas territory"] = "w",
	["parish"] = true,
	["parish seat"] = true,
	["periphery"] = true,
	["port"] = true,
	["port city"] = true,
	["port town"] = "w",
	["prefecture"] = true,
	["prefecture-level city"] = "w",
	["province"] = true,
	["provincial capital"] = true,
	["regency"] = true,
	["regional capital"] = "[[regional]] [[capital]]",
	["regional unit"] = "w",
	["residental area"] = "[[residential]] area",
	["resort city"] = "w",
	["resort town"] = "w",
	["rural community"] = "w",
	["rural municipality"] = "w",
	["rural township"] = "[[w:rural township (Taiwan)|rural township]]",
	["satrapy"] = true,
	["seaport"] = true,
	["settlement"] = true,
	["spa town"] = "w",
	["special administrative region"] = "w",
	["special collectivity"] = "w",
	["special territory"] = "[[special]] [[territory]]",
	["state capital"] = true,
	["statutory town"] = "w",
	["strait"] = true,
	["subdistrict"] = true,
	["submerged ghost town"] = "[[submerged]] [[ghost town]]",
	["subprefecture"] = true,
	["subprovince"] = true,
	["subprovincial city"] = "w",
	["subregion"] = true,
	["suburb"] = true,
	["suburban area"] = "[[suburban]] area",
	["suburban town"] = "[[suburban]] [[town]]",
	["supercontinent"] = true,
	["township"] = true,
	-- can't use templates in this code
	["town with bystatus"] = "[[town]] with [[bystatus#Norwegian Bokmål|bystatus]]",
	["traditional county"] = true,
	["traditional region"] = "w",
	["tributary"] = true,
	["unincorporated territory"] = "w",
	["unitary authority"] = true,
	["unrecognised country"] = "w",
	["unrecognized country"] = "w",
	["urban area"] = "[[urban]] area",
	["urban township"] = "w",
	["voivodeship"] = true,
}


-- In this table, the key placetypes should be treated the same as the value placetypes
-- in all respects but the actual display text.
export.placetype_equivs = {
	["administrative county"] = "county",
	["administrative region"] = "region",
	["ancient civilisation"] = "historical polity",
	["ancient civilization"] = "historical polity",
	["ancient empire"] = "historical polity",
	["ancient kingdom"] = "historical polity",
	["archipelago"] = "island",
	["associated province"] = "province",
	["autonomous prefecture"] = "prefecture",
	["autonomous province"] = "province",
	["autonomous territory"] = "dependent territory",
	["bailiwick"] = "polity",
	["bishopric"] = "polity",
	["cape"] = "peninsula",
	["capital"] = "capital city",
	["chain of islands"] = "island",
	["civil parish"] = "parish",
	["constituent country"] = "country",
	["county-level city"] = "prefecture-level city",
	["crown dependency"] = "dependency",
	["distributary"] = "river",
	["duchy"] = "polity",
	["empire"] = "polity",
	["external territory"] = "dependent territory",
	["federal territory"] = "territory",
	["fictional city"] = "fictional location",
	["fictional island"] = "fictional location",
	["fictional kingdom"] = "fictional location",
	["fictional region"] = "fictional location",
	["former autonomous territory"] = "former polity",
	["former colony"] = "former polity",
	["former country"] = "former polity",
	["former empire"] = "former polity",
	["former kingdom"] = "former polity",
	["former maritime republic"] = "former polity",
	["former republic"] = "former polity",
	["former separatist state"] = "former polity",
	["geographical region"] = "region",
	["ghost town"] = "town",
	["group of islands"] = "island",
	["hamlet"] = "village",
	["harbor town"] = "town",
	["harbour town"] = "town",
	["home rule city"] = "city",
	["home rule municipality"] = "municipality",
	["independent city"] = "city",
	["island country"] = "country",
	["island municipality"] = "municipality",
	["judicial capital"] = "capital city",
	["kingdom"] = "polity",
	["legislative capital"] = "capital city",
	["mediaeval city"] = "ancient city",
	["medieval city"] = "ancient city",
	["mediaeval kingdom"] = "historical polity",
	["medieval kingdom"] = "historical polity",
	["mountain indigenous township"] = "township",
	["mountain range"] = "mountain",
	["mountainous region"] = "region",
	["municipality with city status"] = "municipality",
	["mythological city"] = "mythological location",
	["mythological island"] = "mythological location",
	["mythological kingdom"] = "mythological location",
	["mythological region"] = "mythological location",
	["mythological river"] = "mythological location",
	["neighbourhood"] = "neighborhood",
	["overseas collectivity"] = "collectivity",
	["overseas department"] = "department",
	["overseas territory"] = "territory",
	["port city"] = "city",
	["port town"] = "town",
	["resort city"] = "city",
	["resort town"] = "town",
	["rural community"] = "community",
	["rural municipality"] = "municipality",
	["rural township"] = "township",
	["spa town"] = "town",
	["special collectivity"] = "collectivity",
	["special territory"] = "territory",
	["statutory town"] = "town",
	["submerged ghost town"] = "town",
	["supercontinent"] = "continent",
	["unincorporated territory"] = "territory",
	["unrecognised country"] = "unrecognized country",
	["urban township"] = "township",
	["town with bystatus"] = "town",
	["tributary"] = "river",
}


-- These contain transformations applied to certain placenames to convert them
-- into displayed form. For example, if any of "country/US", "country/USA" or
-- "country/United States of America" (or "c/US", etc.) are given, the result
-- will be displayed as "United States".
export.placename_display_aliases = {
	["country"] = {
		["US"] = "United States",
		["USA"] = "United States",
		["United States of America"] = "United States",
		["UK"] = "United Kingdom",
	},
	["city"] = {
		["New York"] = "New York City",
	},
}


-- These contain transformations applied to the displayed form of certain
-- placenames to convert them into the form they will appear in categories.
-- For example, either of "country/Myanmar" and "country/Burma" will be
-- categorized into categories with "Burma" in them (but the displayed form
-- will respect the form as input). (NOTE, the choice of names here should not
-- be taken to imply any political position; it is just this way because it has
-- always been this way.)
--
-- FIXME: It's unclear if we should have such a distinction between display
-- form and category form.
export.placename_cat_aliases = {
	["country"] = {
		-- will categorize into e.g. "Cities in Burma".
		["Myanmar"] = "Burma",
		["People's Republic of China"] = "China",
		["Republic of China"] = "Taiwan",
	},
}


export.placename_article = {
	-- This should only contain info that can't be inferred from [[Module:place/shared-data]].
	["country"] = {
		["Congo"] = "the",
		["Holy Roman Empire"] = "the",
		["Vatican"] = "the",
	},

	["region"] = {
		["Balkans"] = "the",
	},

	["autonomous community"] = {
		["Basque Country"] = "the",
		["Valencian Community"] = "the",
	},
}

-- Now extract all the other places that need "the" prefixed from the shared
-- place data by looking for places prefixed by "the".
for _, group in ipairs(m_shared.places) do
	for key, value in pairs(group.data) do
		local base = key:match("^the (.*)$")
		if base then
			local divtype = value.divtype or group.default_divtype
			if not divtype then
				error("Group in [[Module:place/shared-data]] is missing a default_divtype key")
			end
			if type(divtype) ~= "table" then
				divtype = {divtype}
			end
			for _, dt in ipairs(divtype) do
				if not export.placename_article[dt] then
					export.placename_article[dt] = {}
				end
				export.placename_article[dt][base] = "the"
			end
		end
	end
end


export.autolink = {
	["continent"] = true,
	["country"] = true,
}


export.implications = {
}


export.cat_implications = {
	["region"] = {
		["Eastern Europe"] = {"continent/Europe"},
		["Central Europe"] = {"continent/Europe"},
		["Western Europe"] = {"continent/Europe"},
		["Southern Europe"] = {"continent/Europe"},
		["South Asia"] = {"continent/Asia"},
		["East Asia"] = {"continent/Asia"},
		["Central Asia"] = {"continent/Asia"},
		["Western Asia"] = {"continent/Asia"},
		["Asia Minor"] = {"continent/Asia"},
		["North Africa"] = {"continent/Africa"},
		["Central Africa"] = {"continent/Africa"},
		["West Africa"] = {"continent/Africa"},
		["East Africa"] = {"continent/Africa"},
		["Southern Africa"] = {"continent/Africa"},
		["Caribbean"] = {"continent/North America"},
		["Polynesia"] = {"continent/Oceania"},
		["Micronesia"] = {"continent/Oceania"},
		["Melanesia"] = {"continent/Oceania"},
		["Siberia"] = {"country/Russia", "continent/Asia"},
		["South Wales"] = {"constituent country/Wales", "continent/Europe"},
		["Balkans"] = {"continent/Europe"},
	}
}


-- Used in get_possible_cat() in [[Module:place]]. When constructing a category
-- for a state, province or region, append a comma + the country name if it is
-- in this table. If the value of the table is true, use the actual country name,
-- else use the value of the table. NOTE: This only applies to cat_data entries
-- with "state", "province" or "region" as a key in the inner table and {true}
-- occurs as the value. Currently this only occurs with municipalities. It
-- doesn't currently apply to categories like "Cities in Alabama, USA", which
-- are handled by the city_type_cat_handler(), which uses a key of "itself" and
-- directly specifies the category.
export.country_append_format = {
	["United States"] = "USA",
	["Philippines"] = true,
	["Brazil"] = true,
	["England"] = true,
	["Northern Ireland"] = true,
	["Scotland"] = true,
	["Wales"] = true,
}


local function city_type_cat_handler(placetype, holonym_placetype, holonym_placename)
	local plural_placetype = m_strutils.pluralize(placetype)
	if m_shared.generic_place_types[plural_placetype] then
		for _, group in ipairs(m_shared.places) do
			-- Find the appropriate key format for the holonym (e.g. "pref/Osaka" -> "Osaka Prefecture").
			local key = group.place_cat_handler(group, placetype, holonym_placetype, holonym_placename)
			if key then
				local value = group.data[key]
				if value then
					-- Use the group's value_transformer to ensure that 'nocities' and 'city_parent'
					-- keys are present if they should be.
					value = group.value_transformer(group, key, value)
					if not value.nocities then
						-- Categorize both in key, and in the larger polity that the key is part of,
						-- e.g. [[Hirakata]] goes in both "Cities in Osaka Prefecture" and
						-- "Cities in Japan".
						local retcats = {ucfirst(plural_placetype) .. " in " .. key}
						if value.city_parent then
							table.insert(retcats, ucfirst(plural_placetype) .. " in " .. value.city_parent)
						end
						return {
							["itself"] = retcats
						}
					end
				end
			end
		end
	end
end


local function chinese_subcity_cat_handler(holonym_placetype, holonym_placename)
	local spec = m_shared.chinese_provinces_and_autonomous_regions[holonym_placename]
	if spec and holonym_placetype == (spec.divtype or "province") then
		return {
			["itself"] = {"Cities in " .. holonym_placename}
		}
	end
end


-- Suffix display handler that adds a suffix such as " parish" to the display form of holonyms.
-- We make sure the holonym doesn't contain the suffix already (taking into account the fact
-- that the holonym might contain links and might have the suffix capitalized). If it doesn't,
-- we create a link that uses the raw form as the link destination but the suffixed form as the
-- display form, unless the holonym already has a link in it, in which case we just add the suffix.
local function suffix_display_handler(suffix, holonym_placename)
	local canon_placename = lc(m_links.remove_links(holonym_placename))
	if canon_placename:find(" " .. lc(suffix) .. "$") then
		return holonym_placename
	end
	if holonym_placename:find("%[%[") then
		return holonym_placename .. " " .. suffix
	end
	return "[[" .. holonym_placename .. "]] " .. suffix
end


-- Prefix display handler that works similarly to suffix_display_handler().
local function prefix_display_handler(prefix, holonym_placename)
	local canon_placename = lc(m_links.remove_links(holonym_placename))
	if canon_placename:find("^" .. lc(prefix) .. " ") then
		return holonym_placename
	end
	if holonym_placename:find("%[%[") then
		return holonym_placename .. " " .. prefix
	end
	return prefix .. " [[" .. holonym_placename .. "]]"
end


-- Display handler for counties. Irish counties are displayed as e.g. "County [[Cork]]".
-- Others are displayed as-is.
local function county_display_handler(holonym_placetype, holonym_placename)
	local unlinked_placename = m_links.remove_links(holonym_placename)
	local canon_placename = lc(unlinked_placename)
	if canon_placename:find("^county $") then
		return holonym_placename
	end
	if m_shared.irish_counties[unlinked_placename] then
		if holonym_placename:find("%[%[") then
			return "County " .. holonym_placename
		end
		return "County [[" .. holonym_placename .. "]]"
	end
	return holonym_placename
end


-- Display handler for prefectures. Japanese prefectures are displayed as e.g. "[[Fukushima Prefecture]]".
-- Others are displayed as e.g. "[[Fthiotida]] prefecture"
local function prefecture_display_handler(holonym_placetype, holonym_placename)
	local unlinked_placename = m_links.remove_links(holonym_placename)
	local canon_placename = lc(unlinked_placename)
	if canon_placename:find(" prefecture$") then
		return holonym_placename
	end
	local suffix = m_shared.japanese_prefectures[unlinked_placename .. " Prefecture"] and "Prefecture" or "prefecture"
	if holonym_placename:find("%[%[") then
		return holonym_placename .. " " .. suffix
	end
	return "[[" .. holonym_placename .. "]] " .. suffix
end


export.cat_data = {
	["administrative village"] = {
		preposition="of",

		["default"] = {
			["municipality"] = {true},
		},
	},

	["administrative capital"] = {
		preposition="of",

		["default"] = {
			["municipality"] = {true},
		},
	},

	["ancient city"] = {
		["default"] = {
			["itself"] = {"Cities"},
		},
	},

	["atoll"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["autonomous community"] = {
		preposition="of",

		["default"] = {
			["country"] = {true},
		},
	},

	["autonomous oblast"] = {
		preposition="of",

		["default"] = {
			["country"] = {true},
		},
	},

	["autonomous okrug"] = {
		preposition="of",

		["default"] = {
			["country"] = {true},
		},
	},

	["autonomous region"] = {
		preposition="of",

		["country/Portugal"] = {
			["itself"] = {"Districts and autonomous regions of +++"},
		},

		["country/China"] = {
			["country"] = {true},
		},

		["default"] = {
		},
	},

	["autonomous republic"] = {
		preposition="of",

		["country/Soviet Union"] = {
			["country"] = {true},
		},

		["default"] = {
		},
	},

	["bay"] = {
		preposition = "of",

		["default"] = {
			["itself"] = {true},
		},
	},

	["borough"] = {
		preposition="of",
		display_handler = function(holonym_placetype, holonym_placename)
			return suffix_display_handler("borough", holonym_placename)
		end,

		["default"] = {
		},

		["state/Alaska"] = {
			-- Don't use +++ or we may get "Boroughs of Alaska, USA".
			["itself"] = {"Boroughs of Alaska"},
		},

		["country/England"] = {
			["itself"] = {"Boroughs in +++"},
		},

		["city/New York City"] = {
			["itself"] = {"Boroughs in +++"},
		},

		["state/Pennsylvania"] = {
			-- Don't use +++ or we may get "Boroughs in Pennsylvania, USA".
			["itself"] = {"Boroughs in Pennsylvania"},
		},
	},

	["borough seat"] = {
		article="the",
		preposition="of",

		["default"] = {
		},

		["state/Alaska"] = {
			-- Don't use +++ or we may get "Borough seats of Alaska, USA".
			["itself"] = {"Borough seats of Alaska"},
		},

	},

	["canton"] = {
		preposition="of",

		["default"] = {
			["country"] = {true},
		},
	},

	["capital city"] = {
		article="the",
		preposition="of",

		["default"] = {
			["country"] = {"Capital cities", "Cities in +++"},
			["itself"] = {true},
		},
	},

	["census-designated place"] = {
		cat_handler = function(holonym_placetype, holonym_placename)
			if holonym_placetype == "state" then
				return city_type_cat_handler("census-designated place", holonym_placetype, holonym_placename)
			end
		end,

		["country/United States"] = {
			["itself"] = {true},
		},

		["default"] = {
		},
	},

	["city"] = {
		cat_handler = function(holonym_placetype, holonym_placename)
			return city_type_cat_handler("city", holonym_placetype, holonym_placename)
		end,

		["prefecture/Hokkaido"] = {
			-- Don't use +++ or true, or we may get "Cities in Hokkaido Prefecture".
			["itself"] = {"Cities in Hokkaido"},
		},

		["default"] = {
			["itself"] = {true},
			["country"] = {true},
		},
	},

	["collectivity"] = {
		preposition="of",

		["default"] = {
			["itself"] = {"Polities"},
			["country"] = {true},
		},
	},

	["colony"] = {
		preposition="of",

		["default"] = {
		},
	},

	["commandery"] = {
		preposition="of",

		["default"] = {
			["itself"] = {true},
			["country"] = {true},
		},
	},

	["commonwealth"] = {
		preposition="of",

		["default"] = {
		},
	},

	["continent"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["contregion"] = {
		["default"] = {
		},
	},

	["council area"] = {
		preposition="of",

		["default"] = {
			["itself"] = {true},
			["country"] = {true},
		},
	},

	["country"] = {
		synergy = {
			["macroregion"] = {
				before="in the",
				between="of",
			}
		},

		["default"] = {
			["continent"] = {true, "Countries"},
			["itself"] = {true},
		},
	},

	["county"] = {
		preposition="of",
		-- UNITED STATES
		cat_handler = function(holonym_placetype, holonym_placename)
			local spec = m_shared.US_states[holonym_placename .. ", USA"]
			if spec and holonym_placetype == "state" and not spec.county_type then
				return {
					["itself"] = {"Counties of " .. holonym_placename}
				}
			end
		end,
		display_handler = county_display_handler,

		["country/Holy Roman Empire"] = {
		},

		["default"] = {
			["itself"] = {"Polities"},
			["country"] = {true},
		},
	},

	["county-administered city"] = {
		["default"] = {
			["country"] = {"Cities in +++"},
		},
	},

	["county borough"] = {
		preposition="of",
		display_handler = function(holonym_placetype, holonym_placename)
			return suffix_display_handler("county borough", holonym_placename)
		end,

		["default"] = {
		},
	},

	["county seat"] = {
		article="the",
		preposition="of",
		-- UNITED STATES
		cat_handler = function(holonym_placetype, holonym_placename)
			local spec = m_shared.US_states[holonym_placename .. ", USA"]
			if spec and holonym_placetype == "state" and not spec.county_type then
				return {
					["itself"] = {"County seats of " .. holonym_placename}
				}
			end
		end,

		["default"] = {
		},
	},

	["department"] = {
		preposition="of",
		display_handler = function(holonym_placetype, holonym_placename)
			return suffix_display_handler("department", holonym_placename)
		end,

		["default"] = {
			["country"] = {true},
		},
	},

	["department capital"] = {
		article="the",
		preposition="of",

		["default"] = {
		},
	},

	["dependency"] = {
		preposition="of",

		["default"] = {
			["itself"] = {true},
			["country"] = {"Dependencies of +++"},
		},
	},

	["dependent territory"] = {
		preposition="of",

		["default"] = {
			["itself"] = {"Dependencies"},
			["country"] = {"Territories of +++"},
		},
	},

	["desert"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["district"] = {
		preposition="of",
		display_handler = function(holonym_placetype, holonym_placename)
			return suffix_display_handler("district", holonym_placename)
		end,

		["country/Portugal"] = {
			["itself"] = {"Districts and autonomous regions of +++"},
		},

		["default"] = {
			["country"] = {true},
		},
	},

	["district capital"] = {
		article="the",
		preposition="of",

		["default"] = {
		},
	},

	["division"] = {
		preposition="of",

		["default"] = {
			["country"] = {true},
		},
	},

	["polity"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["federal city"] = {
		preposition="of",

		["default"] = {
			["country"] = {true},
		},
	},

	["federal subject"] = {
		preposition="of",

		["default"] = {
			["country"] = {true},
		},
	},

	["fictional location"] = {
		["default"] = {
			["itself"] = {"Fictional locations"},
		},
	},

	["forest"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["former county"] = {
		preposition="of",

		["default"] = {
		},
	},

	["former polity"] = {
		["default"] = {
			["itself"] = {"Historical polities"},
		},
	},

	["governorate"] = {
		preposition = "of",

		["default"] = {
		},
	},

	["gulf"] = {
		preposition = "of",

		["default"] = {
			["itself"] = {true},
		},
	},

	["headland"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["hill"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["historical polity"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["historical region"] = {
		["default"] = {
			["itself"] = {"Historical and traditional regions"},
		},
	},

	["island"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["kibbutz"] = {
		plural="kibbutzim",

		["default"] = {
			["itself"] = {true},
		},
	},

	["krai"] = {
		preposition="of",

		["default"] = {
			["country"] = {true},
		},
	},

	["lake"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["London borough"] = {
		preposition="of",
		display_handler = function(holonym_placetype, holonym_placename)
			return suffix_display_handler("borough", holonym_placename)
		end,

		["default"] = {
		},

		["country/England"] = {
			["itself"] = {"Boroughs in +++"},
		},
	},

	["macroregion"] = {
		preposition="of",

		["country/Brazil"] = {
			["country"] = {"Regions of +++"},
		},

		["default"] = {
		},
	},

	["marginal sea"] = {
		preposition="of",

		["default"] = {
			["itself"] = {"Seas"},
		},
	},

	["mention capital"] = {
		synergy = {
			["country"] = {
				before = "of",
				between = "where the country’s capital",
				after = "is located"
			}
		},

		["default"] = {
		},
	},

	["metropolitan borough"] = {
		preposition="of",
		display_handler = function(holonym_placetype, holonym_placename)
			return prefix_display_handler("Metropolitan Borough of", holonym_placename)
		end,

		["default"] = {
		},

		["country/England"] = {
			["itself"] = {"Boroughs in +++"},
		},
	},

	["mountain"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["municipality"] = {
		preposition="of",

		["country/Austria"] = {
			["state"] = {true, "Municipalities of Austria"},
			["country"] = {true},
		},

		["country/Brazil"] = {
			["state"] = {true, "Municipalities of Brazil"},
			["country"] = {true},
		},

		["country/Philippines"] = {
			["province"] = {true, "Municipalities of the Philippines"},
			["country"] = {true},
		},

		["default"] = {
			["country"] = {true},
		},
	},

	["mythological location"] = {
		["default"] = {
			["itself"] = {"Mythological locations"},
		},
	},

	["oblast"] = {
		preposition="of",

		["default"] = {
			["country"] = {true},
		},
	},

	["ocean"] = {
		holonym_article="the",

		["default"] = {
			["itself"] = {true},
		},
	},

	["parish"] = {
		preposition="of",
		display_handler = function(holonym_placetype, holonym_placename)
			return suffix_display_handler("parish", holonym_placename)
		end,

		["default"] = {
		},

		["state/Louisiana"] = {
			-- Don't use +++ or we may get "Parishes of Louisiana, USA".
			["itself"] = {"Parishes of Louisiana"},
		},

	},

	["parish seat"] = {
		article="the",
		preposition="of",

		["default"] = {
		},

		["state/Louisiana"] = {
			-- Don't use +++ or we may get "Parish seats of Louisiana, USA".
			["itself"] = {"Parish seats of Louisiana"},
		},

	},

	["peninsula"] = {
		holonym_article="the",
		display_handler = function(holonym_placetype, holonym_placename)
			return suffix_display_handler("peninsula", holonym_placename)
		end,

		["default"] = {
			["itself"] = {true},
		},
	},

	["periphery"] = {
		preposition="of",

		["country/Greece"] = {
			["itself"] = {"Regions of +++"},
		},

		["default"] = {
		},
	},

	["prefecture"] = {
		preposition="of",
		display_handler = prefecture_display_handler,

		["default"] = {
			["country"] = {true},
		},
	},

	["prefecture-level city"] = {
		-- CHINA
		cat_handler = chinese_subcity_cat_handler,

		["default"] = {
			["country"] = {"Cities in +++"},
		},
	},

	["province"] = {
		preposition="of",

		["default"] = {
			["itself"] = {true},
			["country"] = {true},
		},
	},

	["provincial capital"] = {
		article="the",
		preposition="of",

		cat_handler = function(holonym_placetype, holonym_placename)
			if holonym_placetype == "province" then
				return city_type_cat_handler("city", holonym_placetype, holonym_placename)
			end
		end,

		["default"] = {
			["country"] = {"Cities in +++"},
		},
	},

	["regency"] = {
		preposition="of",

		["default"] = {
			["country"] = {true},
		},
	},

	["region"] = {
		preposition="of",

		["country/Armenia"] = {
			["country"] = {true},
		},

		["country/Brazil"] = {
			["country"] = {true},
		},

		["country/England"] = {
			["itself"] = {"Counties and regions of +++"},
		},

		["country/Finland"] = {
			["country"] = {true},
		},

		["country/France"] = {
			["country"] = {true},
		},

		["country/Georgia"] = {
			["country"] = {true},
		},

		["country/Greece"] = {
			["country"] = {true},
		},

		["country/Italy"] = {
			["country"] = {true},
		},

		["country/Latvia"] = {
			["country"] = {true},
		},

		["country/Peru"] = {
			["country"] = {true},
		},

		["country/Portugal"] = {
			["country"] = {true},
		},

		["country/Romania"] = {
			["country"] = {true},
		},

		["default"] = {
		},
	},

	["regional capital"] = {
		article="the",
		preposition="of",

		["default"] = {
		},
	},

	["regional unit"] = {
		preposition="of",

		["default"] = {
		},
	},

	["republic"] = {
		preposition="of",

		["default"] = {
			["country"] = {true},
		},
	},

	["river"] = {
		holonym_article="the",
		cat_handler = function(holonym_placetype, holonym_placename)
			return city_type_cat_handler("river", holonym_placetype, holonym_placename)
		end,

		["default"] = {
			["itself"] = {true},
			["country"] = {true},
			["continent"] = {true},
		},
	},

	["satrapy"] = {
		preposition="of",

		["default"] = {
		},
	},

	["sea"] = {
		holonym_article="the",

		["default"] = {
			["itself"] = {true},
		},
	},

	["special administrative region"] = {
		preposition="of",

		["default"] = {
			["country"] = {true},
		},
	},

	["star"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["state"] = {
		preposition="of",

		["default"] = {
			["country"] = {true},
		},
	},

	["state capital"] = {
		article="the",
		preposition="of",

		cat_handler = function(holonym_placetype, holonym_placename)
			if holonym_placetype == "state" then
				return city_type_cat_handler("city", holonym_placetype, holonym_placename)
			end
		end,

		["country/Brazil"] = {
			["country"] = {true},
		},
		["country/United States"] = {
			["country"] = {true},
		},
		["default"] = {
		},
	},

	["strait"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["subdistrict"] = {
		preposition="of",

		["country/Indonesia"] = {
			["municipality"] = {true},
		},

		["default"] = {
			["itself"] = {true},
		},
	},

	["subprefecture"] = {
		preposition="of",

		["default"] = {
		},
	},

	["subprovince"] = {
		preposition="of",

		["default"] = {
		},
	},

	["subprovincial city"] = {
		-- CHINA
		cat_handler = chinese_subcity_cat_handler,

		["default"] = {
			["country"] = {"Cities in +++"},
		},
	},

	["subregion"] = {
		preposition="of",

		["default"] = {
		},
	},

	["territory"] = {
		preposition="of",

		["default"] = {
			["itself"] = {"Polities"},
			["country"] = {true},
		},
	},

	["town"] = {
		cat_handler = function(holonym_placetype, holonym_placename)
			return city_type_cat_handler("town", holonym_placetype, holonym_placename)
		end,

		["default"] = {
			["itself"] = {true},
			["country"] = {true},
		},
	},

	["township"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["traditional county"] = {
		preposition="of",

		["default"] = {
		},
	},

	["traditional region"] = {
		["default"] = {
			["itself"] = {"Historical and traditional regions"},
		},
	},

	["unincorporated community"] = {
		cat_handler = function(holonym_placetype, holonym_placename)
			if holonym_placetype == "state" then
				return city_type_cat_handler("unincorporated community", holonym_placetype, holonym_placename)
			end
		end,

		["country/United States"] = {
			["itself"] = {true},
		},

		["default"] = {
		},
	},

	["unrecognized country"] = {
		["default"] = {
			["itself"] = {"Countries"},
		},
	},

	["valley"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["village"] = {
		cat_handler = function(holonym_placetype, holonym_placename)
			return city_type_cat_handler("village", holonym_placetype, holonym_placename)
		end,

		["default"] = {
			["itself"] = {true},
			["country"] = {true},
		},
	},

	["voivodeship"] = {
		preposition="of",
		holonym_article="the",

		["default"] = {
		},
	},
}


-- Now augment the category data with political subdivisions extracted from the
-- shared data. We don't need to do this if there's already an entry under "default"
-- for the divtype of the containing polity.
for _, group in ipairs(m_shared.places) do
	for key, value in pairs(group.data) do
		if value.poldiv or value.miscdiv then
			local divtype = value.divtype or group.default_divtype
			if type(divtype) ~= "table" then
				divtype = {divtype}
			end
			for pass=1,2 do
				local list
				if pass == 1 then
					list = value.poldiv
				else
					list = value.miscdiv
				end
				if list then
					for _, div in ipairs(list) do
						local sgdiv = m_strutils.singularize(div)
						for _, dt in ipairs(divtype) do
							if not export.cat_data[sgdiv] then
								export.cat_data[sgdiv] = {
									preposition="of",

									["default"] = {
									},
								}
							end
							if not export.cat_data[sgdiv]["default"] then
								error("Placetype '" .. sgdiv .. "' is missing default key in cat_data")
							end
							if not export.cat_data[sgdiv]["default"][dt] then
								export.cat_data[sgdiv][dt .. "/" .. key] = {
									["itself"] = {true}
								}
							end
						end
					end
				end
			end
		end
	end
end


return export
