local export = {}

local m_shared = require("Module:place/shared-data")

local function ucfirst(label)
	return mw.getContentLanguage():ucfirst(label)
end


export.placetype_aliases = {
	["c"] = "country",
	["cc"] = "constituent country",
	["p"] = "province",
	["ap"] = "autonomous province",
	["r"] = "region",
	["ar"] = "autonomous region",
	["sar"] = "special administrative region",
	["s"] = "state",
	["bor"] = "borough",
	["co"] = "county",
	["cobor"] = "county borough",
	["coll"] = "collectivity",
	["comm"] = "community",
	["acomm"] = "autonomous community",
	["cont"] = "continent",
	["dist"] = "district",
	["div"] = "division",
	["metbor"] = "metropolitan borough",
	["mun"] = "municipality",
	["obl"] = "oblast",
	["aobl"] = "autonomous oblast",
	["par"] = "parish",
	["pref"] = "prefecture",
	["apref"] = "autonomous prefecture",
	["rep"] = "republic",
	["arep"] = "autonomous republic",
	["terr"] = "territory",
	["aterr"] = "autonomous territory",
	["uterr"] = "union territory",
	["voi"] = "voivodeship",
	["mountain range"] = "range",
}


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
	["coastal"] = true,
	["inland"] = true,
	["historical"] = "historic",
	["maritime"] = "coastal",
	["seaside"] = "coastal",
}


-- In this table, the key placetypes should be treated the same as the value placetypes
-- in all respects but the actual display text.
export.placetype_equivs = {
	["hamlet"] = "village",
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
	["constituent country"] = "country",
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
	},
}


export.place_article = {
	-- This should only contain info that can't be inferred from [[Module:place/shared-data]].
	["country"] = {
		["Congo"] = "the",
		["Holy Roman Empire"] = "the",
		["Vatican"] = "the",
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
			if type(divtype) ~= "table" then
				divtype = {divtype}
				for _, dt in ipairs(divtype) do
					if not export.place_article[dt] then
						export.place_article[dt] = {}
					end
					export.place_article[dt][base] = "the"
				end
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
	}
}


local function city_type_handler(placetype, holonym_placetype, holonym_placename)
	local plural_placetype = m_shared.generic_place_types_singular[placetype]
	if plural_placetype then
		for _, group in ipairs(m_shared.places) do
			local key = group.place_handler(group, placetype, holonym_placetype, holonym_placename)
			if key then
				return {
					["itself"] = {ucfirst(plural_placetype) .. " in " .. key}
				}
			end
		end
	end
end


local function chinese_subcity_handler(holonym_placetype, holonym_placename)
	local spec = m_shared.chinese_provinces_and_autonomous_regions[holonym_placename]
	if spec and holonym_placetype == (spec.divtype or "province") then
		return {
			["itself"] = {"Cities in " .. holonym_placename}
		}
	end
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

	["ancient civilisation"] = {		
		["default"] = {
			["itself"] = {"Historical polities"},
		},
	},

	["ancient civilization"] = {		
		["default"] = {
			["itself"] = {"Historical polities"},
		},
	},

	["ancient empire"] = {		
		["default"] = {
			["itself"] = {"Historical polities"},
		},
	},

	["ancient kingdom"] = {		
		["default"] = {
			["itself"] = {"Historical polities"},
		},
	},
	
	["archipelago"] = {
		["default"] = {
			["itself"] = {"Islands"},
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

	["autonomous prefecture"] = {
		preposition="of",
	
		["default"] = {
			["country"] = {"Prefectures of "},
		},
	},
	
	["autonomous region"] = {
		preposition="of",
		
		["country/Portugal"] = {
			["itself"] = {"Districts and autonomous regions of Portugal"},
		},
		
		["country/China"] = {
			["country"] = {true}
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

	["autonomous territory"] = {
		preposition="of",

		["default"] = {
			["itself"] = {"Dependencies"},
			["country"] = {"Territories of"},
		},
	},
	
	["bailiwick"] = {
		["default"] = {
			["itself"] = {"Polities"},
		},
	},
	
	["bishopric"] = {
		["default"] = {
			["itself"] = {"Polities"},
		},
	},
	
	["borough"] = {
		preposition="of",
		
		["default"] = {
		},
	
		["state/Alaska"] = {
			["itself"] = {"Boroughs of Alaska"},
		},
	
		["country/England"] = {
			["itself"] = {"Boroughs in England"},
		},
	
		["city/New York City"] = {
			["itself"] = {"Boroughs in New York City"},
		},

		["city/Pennsylvania"] = {
			["itself"] = {"Boroughs in Pennsylvania"},
		},
	},

	["canton"] = {
		preposition="of",
		
		["default"] = {
			["country"] = {true},
		},
	},
		
	["cape"] = {
		["default"] = {
			["itself"] = {"Peninsulas"},
		},
	},
	
	["capital"] = {
		article="the",
		preposition="of",
	
		["default"] = {
		},
	},
	
	["capital city"] = {
		article="the",
		preposition="of",
		
		["default"] = {
			["itself"] = {true},
		},
	},
	
	["city"] = {
		handler = function(holonym_placetype, holonym_placename)
			return city_type_handler("city", holonym_placetype, holonym_placename)
		end,

		["prefecture/Hokkaido"] = {
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
			["continent"] = {true},
			["itself"] = {true},
		},
	},

	["county"] = {
		preposition="of",

		-- UNITED STATES
		handler = function(holonym_placetype, holonym_placename)
			local spec = m_shared.US_states[holonym_placename .. ", USA"]
			if spec and holonym_placetype == "state" and not spec.count_type then
				return {
					["itself"] = {"Counties of " .. holonym_placename}
				}
			end
		end,

		["country/England"] = {
			["itself"] = {"Counties of England"},
		},
		
		["country/Holy Roman Empire"] = {
		},
		
		["country/People's Republic of China"] = {
			["itself"] = {"Counties of China"},
		},
	
		["country/Republic of China"] = {
			["itself"] = {"Counties of Taiwan"},
		},

		["default"] = {
			["itself"] = {"Polities"},
			["country"] = {true},
		},
	},

	["county-administered city"] = {
		["default"] = {
			["country"] = {"Cities in "},
		},
	},

	["county-level city"] = {
		-- CHINA
		handler = chinese_subcity_handler,

		["default"] = {
			["country"] = {"Cities in "},
		},
	},

	["county seat"] = {
		article="the",
		preposition="of",

		["default"] = {
		},
	},

	["crown dependency"] = {
		preposition="of",

		["default"] = {
			["itself"] = {true},
			["country"] = {"Dependencies of "},
		},
	},

	["department"] = {
		preposition="of",
		
		["default"] = {
			["country"] = {true},
		},
	},
	
	["departmental capital"] = {
		article="the",
		preposition="of",
	
		["default"] = {
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
			["country"] = {"Dependencies of "},
		},
	},

	["dependent territory"] = {
		preposition="of",

		["default"] = {
			["itself"] = {"Dependencies"},
			["country"] = {"Territories of"},
		},
	},
	
	["desert"] = {
		["default"] = {
			["itself"] = {true},
		},
	},
	
	["district"] = {
		preposition="of",
		
		["country/Portugal"] = {
			["itself"] = {"Districts and autonomous regions of Portugal"},
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

	["duchy"] = {
		["default"] = {
			["itself"] = {"Polities"},
		},
	},

	["empire"] = {
		["default"] = {
			["itself"] = {"Polities"},
		},
	},

	["external territory"] = {
		preposition="of",

		["default"] = {
			["itself"] = {"Dependencies"},
			["country"] = {"Territories of"},
		},
	},
	
	["federal city"] = {
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

	["former region"] = {
		preposition="of",
		["default"] = {
			["country"] = {"Regions of "},
		},
	},
	
	["former state"] = {
		preposition="of",
		["default"] = {
			["country"] = {"States of "},
		},
	},

	["governorate"] = {
		preposition = "of",

		["default"] = {
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
	
	["judicial capital"] = {
		article="the",
		preposition="of",
	
		["default"] = {
			["itself"] = {"Capital cities"},
		},
	},

	["kibbutz"] = {
		plural="kibbutzim",
		
		["default"] = {
			["itself"] = {true},
		},
	},
	
	["kingdom"] = {
		["default"] = {
			["itself"] = {"Polities"},
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
	
	["legislative capital"] = {
		article="the",
		preposition="of",
	
		["default"] = {
			["itself"] = {"Capital cities"},
		},
	},

	["macroregion"] = {
		real_name="region",
		preposition="of",
		
		["country/Brazil"] = {
			["country"] = {true},
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
	
	["mediaeval city"] = {
		["default"] = {
			["itself"] = {"Cities"},
		},
	},

	["medieval city"] = {
		["default"] = {
			["itself"] = {"Cities"},
		},
	},

	["mediaeval kingdom"] = {		
		["default"] = {
			["itself"] = {"Historical polities"},
		},
	},

	["medieval kingdom"] = {		
		["default"] = {
			["itself"] = {"Historical polities"},
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

	["mountain"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["mountain indigenous township"] = {
		["default"] = {
			["itself"] = {"Townships"},
		},
	},
	
	["municipality"] = {
		preposition="of",

		["country/Brazil"] = {
			["state"] = {true},
			["country"] = {true},
		},
		
		["default"] = {
			["country"] = {true},
		},
	},

	["mythological city"] = {
		["default"] = {
			["itself"] = {"Mythological locations"},
		},
	},

	["mythological island"] = {
		["default"] = {
			["itself"] = {"Mythological locations"},
		},
	},

	["mythological kingdom"] = {
		["default"] = {
			["itself"] = {"Mythological locations"},
		},
	},

	["mythological region"] = {
		["default"] = {
			["itself"] = {"Mythological locations"},
		},
	},

	["mythological river"] = {
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
		["default"] = {
			["itself"] = {true},
		},
	},

	["overseas collectivity"] = {
		preposition="of",

		["default"] = {
			["itself"] = {"Polities"},
			["country"] = {"Collectivities of "},
		},
	},

	["overseas department"] = {
		preposition="of",
		
		["default"] = {
			["itself"] = {"Polities"},
		},
	},

	["overseas territory"] = {
		preposition="of",

		["default"] = {
			["itself"] = {"Polities"},
			["country"] = {"Territories of "},
		},
	},
	
	["parish"] = {
		preposition="of",
	
		["default"] = {
		},
	
		["state/Louisiana"] = {
			["itself"] = {"Parishes of Louisiana"},
		},
	
	},

	["peninsula"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["periphery"] = {
		preposition="of",
		
		["country/Greece"] = {
			["itself"] = {"Regions of Greece"},
		},
	
		["default"] = {
		},
	},

	["prefecture"] = {
		preposition="of",

		["default"] = {
			["country"] = {true},
		},
	},

	["prefecture-level city"] = {
		-- CHINA

		handler = chinese_subcity_handler,

		["default"] = {
			["country"] = {"Cities in "},
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
	
		handler = function(holonym_placetype, holonym_placename)
			if holonym_placetype == "province" then
				return city_type_handler("city", holonym_placetype, holonym_placename)
			end
		end,
		
		["default"] = {
			["country"] = {"Cities in "},
		},
	},
	
	["range"] = {
		real_name = "mountain range",
		
		["default"] = {
			["itself"] = {"Mountains"},
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
			["itself"] = {"Counties and regions of England"},
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
		handler = function(holonym_placetype, holonym_placename)
			return city_type_handler("river", holonym_placetype, holonym_placename)
		end,

		["default"] = {
			["itself"] = {true},
			["country"] = {true},
		},
	},

	["rural township"] = {
		["default"] = {
			["itself"] = {"Townships"},
		},
	},

	["satrapy"] = {
		preposition="of",

		["default"] = {
		},
	},

	["sea"] = {
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
	
	["special collectivity"] = {
		preposition="of",

		["default"] = {
			["itself"] = {"Polities"},
			["country"] = {"Collectivities of "},
		},
	},

	["special territory"] = {
		preposition="of",

		["default"] = {
			["itself"] = {"Polities"},
			["country"] = {"Territories of "},
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
	
		handler = function(holonym_placetype, holonym_placename)
			if holonym_placetype == "state" then
				return city_type_handler("city", holonym_placetype, holonym_placename)
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

	["subprovincial city"] = {
		-- CHINA
		handler = chinese_subcity_handler,

		["default"] = {
			["country"] = {"Cities in "},
		},
	},
	
	["supercontinent"] = {
		["default"] = {
			["itself"] = {"Continents"},
		},
	},

	["territory"] = {
		preposition="of",

		["country/Canada"] = {
			["country"] = {true},
		},
		["country/Australia"] = {
			["country"] = {true},
		},
		["default"] = {
		},
	},

	["town"] = {
		handler = function(holonym_placetype, holonym_placename)
			return city_type_handler("town", holonym_placetype, holonym_placename)
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

	["unincorporated territory"] = {
		preposition="of",
		
		["default"] = {
			["country"] = {"Territories of "},
		},
	},

	["unrecognised country"] = {
		["default"] = {
			["itself"] = {"Countries"},
		},
	},

	["unrecognized country"] = {
		["default"] = {
			["itself"] = {"Countries"},
		},
	},

	["urban township"] = {
		["default"] = {
			["itself"] = {"Townships"},
		},
	},
	
	["valley"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["village"] = {
		handler = function(holonym_placetype, holonym_placename)
			return city_type_handler("village", holonym_placetype, holonym_placename)
		end,
		
		["default"] = {
			["itself"] = {true},
			["country"] = {true},
		},
	},
	
	["voivodeship"] = {
		preposition="of",
		
		["default"] = {
		},
	},
}

return export
