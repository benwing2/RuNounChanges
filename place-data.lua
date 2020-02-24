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
	["carea"] = "council area",
	["cdblock"] = "community development block",
	["cdep"] = "Crown dependency",
	["cdp"] = "census-designated place",
	["CDP"] = "census-designated place",
	["co"] = "county",
	["cobor"] = "county borough",
	["colcity"] = "county-level city",
	["coll"] = "collectivity",
	["comm"] = "community",
	["acomm"] = "autonomous community",
	["cont"] = "continent",
	["cpar"] = "civil parish",
	["dep"] = "dependency",
	["dept"] = "department",
	["dist"] = "district",
	["distmun"] = "district municipality",
	["div"] = "division",
	["govnat"] = "governorate",
	["ires"] = "Indian reservation",
	["isl"] = "island",
	["lbor"] = "London borough",
	["lgarea"] = "local government area",
	["lgdist"] = "local government district",
	["metbor"] = "metropolitan borough",
	["mtn"] = "mountain",
	["mun"] = "municipality",
	["mundist"] = "municipal district",
	["obl"] = "oblast",
	["aobl"] = "autonomous oblast",
	["okr"] = "okrug",
	["aokr"] = "autonomous okrug",
	["par"] = "parish",
	["parmun"] = "parish municipality",
	["pen"] = "peninsula",
	["pref"] = "prefecture",
	["preflcity"] = "prefecture-level city",
	["apref"] = "autonomous prefecture",
	["rep"] = "republic",
	["arep"] = "autonomous republic",
	["riv"] = "river",
	["rcomun"] = "regional county municipality",
	["rdist"] = "regional district",
	["rmun"] = "regional municipality",
	["runit"] = "regional unit",
	["rurmun"] = "rural municipality",
	["terrauth"] = "territorial authority",
	["terr"] = "territory",
	["aterr"] = "autonomous territory",
	["uterr"] = "union territory",
	["tjarea"] = "tribal jurisdictional area",
	["twp"] = "township",
	["twpmun"] = "township municipality",
	["utwpmun"] = "united township municipality",
	["val"] = "valley",
	["voi"] = "voivodeship",
	["range"] = "mountain range",
	["departmental capital"] = "department capital",
	["home-rule city"] = "home rule city",
	["home-rule municipality"] = "home rule municipality",
	["sub-provincial city"] = "subprovincial city",
	["sub-prefecture-level city"] = "sub-prefectural city",
	["nonmetropolitan county"] = "non-metropolitan county",
	["inner-city area"] = "inner city area",
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
	-- generic qualifiers
	["huge"] = true,
	["tiny"] = true,
	["large"] = true,
	["small"] = true,
	["sizable"] = true,
	["important"] = true,
	["long"] = true,
	["short"] = true,
	["major"] = true,
	["minor"] = true,
	["high"] = true,
	["low"] = true,
	-- "former" qualifiers
	["ancient"] = true,
	["former"] = true,
	["historic"] = "historical",
	["historical"] = true,
	["medieval"] = true,
	["mediaeval"] = true,
	["traditional"] = true,
	-- sea qualifiers
	["coastal"] = true,
	["inland"] = true,
	["maritime"] = true,
	["overseas"] = "[[overseas]]",
	["seaside"] = "coastal",
	["beachfront"] = "[[beachfront]]",
	["beachside"] = "[[beachfront]]",
	["riverside"] = true,
	-- political status qualifiers
	["autonomous"] = "[[autonomous]]",
	["incorporated"] = "[[incorporated]]",
	["special"] = "[[special]]",
	["unincorporated"] = "[[unincorporated]]",
	-- monetary status/etc. qualifiers
	["fashionable"] = true,
	["wealthy"] = true,
	["affluent"] = "[[affluent]]",
	-- city vs. rural qualifiers
	["urban"] = true,
	["suburban"] = "[[suburban]]",
	["outlying"] = true,
	["remote"] = true,
	["rural"] = true,
	["inner"] = true,
	["outer"] = true,
	-- land use qualifiers
	["residential"] = "[[residential]]",
	["agricultural"] = "[[agricultural]]",
	["business"] = true,
	["commercial"] = "[[commercial]]",
	["industrial"] = "[[industrial]]",
	-- business use qualifiers
	["railroad"] = "[[railroad]]",
	["railway"] = "[[railway]]",
	["farming"] = "[[farming]]",
	["fishing"] = "[[fishing]]",
	["mining"] = "[[mining]]",
	["cattle"] = "[[cattle]]",
	-- religious qualifiers
	["holy"] = true,
	["sacred"] = true,
	["religious"] = true,
	["secular"] = true,
	-- qualifiers for nonexistent places
	["fictional"] = true,
	["mythological"] = true,
	-- directional qualifiers
	["northern"] = true,
	["southern"] = true,
	["eastern"] = true,
	["western"] = true,
	["north"] = true,
	["south"] = true,
	["east"] = true,
	["west"] = true,
	["northeastern"] = true,
	["southeastern"] = true,
	["northwestern"] = true,
	["southwestern"] = true,
	["northeast"] = true,
	["southeast"] = true,
	["northwest"] = true,
	["southwest"] = true,
	-- misc. qualifiers
	["hilly"] = true,
	["planned"] = true,
	["chartered"] = true,
}


-- If there's an entry here, the corresponding placetype will use the text of the
-- value, which should be used to add links. If the value is true, a simple link
-- will be added around the whole placetype. If the value is "w", a link to
-- Wikipedia will be added around the whole placetype.
export.placetype_links = {
	["administrative capital"] = "w",
	["administrative center"] = "w",
	["administrative centre"] = "w",
	["administrative county"] = "w",
	["administrative district"] = "w",
	["administrative headquarters"] = "[[administrative]] [[headquarters]]",
	["administrative region"] = true,
	["administrative seat"] = "w",
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
	["barangay"] = true, -- Philippines
	["barrio"] = true, -- Spanish-speaking countries; Philippines
	["bay"] = true,
	["beach resort"] = "w",
	["bishopric"] = true,
	["borough"] = true,
	["borough seat"] = true,
	["burgh"] = true,
	["canton"] = true,
	["cape"] = true,
	["caravan city"] = true,
	["cathedral city"] = true,
	["cattle station"] = true, -- Australia
	["census area"] = true,
	["census-designated place"] = true, -- United States
	["central business district"] = true,
	["ceremonial county"] = true,
	["channel"] = true,
	["charter community"] = "w", -- Northwest Territories, Canada
	["civil parish"] = true,
	["coal town"] = "w",
	["collectivity"] = true,
	["commandery"] = true,
	["commonwealth"] = true,
	["commune"] = true,
	["community"] = true,
	["community development block"] = "w", -- India
	["constituent country"] = true,
	["contregion"] = "[[continental]] region",
	["council area"] = true,
	["county-administered city"] = "w", -- Taiwan
	["county-controlled city"] = "w", -- Taiwan
	["county-level city"] = "w", -- China
	["county borough"] = true,
	["county seat"] = true,
	["county town"] = true,
	["crown dependency"] = "w",
	["department"] = true,
	["department capital"] = "[[department]] [[capital]]",
	["dependency"] = true,
	["dependent territory"] = "w",
	["direct-administered municipality"] = "[[w:direct-administered municipalities of China|direct-administered municipality]]",
	["direct-controlled municipality"] = "w",
	["distributary"] = true,
	["district"] = true,
	["district capital"] = "[[district]] [[capital]]",
	["district headquarters"] = "[[district]] [[headquarters]]",
	["district municipality"] = "w",
	["division"] = true,
	["duchy"] = true,
	["empire"] = true,
	["external territory"] = "[[external]] [[territory]]",
	["federal city"] = "w",
	["federal subject"] = "w",
	["federal territory"] = "w",
	["First Nations reserve"] = "[[First Nations]] [[w:Indian reserve|reserve]]", -- Canada
	["former autonomous territory"] = "former [[w:autonomous territory|autonomous territory]]",
	["former colony"] = "former [[colony]]",
	["former maritime republic"] = "former [[maritime republic]]",
	["former polity"] = "former [[polity]]",
	["former separatist state"] = "former [[separatist]] [[state]]",
	["geographical region"] = "w",
	["ghost town"] = true,
	["glen"] = true,
	["governorate"] = true,
	["gulf"] = true,
	["hamlet"] = true,
	["harbor city"] = "[[harbor]] [[city]]",
	["harbour city"] = "[[harbour]] [[city]]",
	["harbor town"] = "[[harbor]] [[town]]",
	["harbour town"] = "[[harbour]] [[town]]",
	["headland"] = true,
	["headquarters"] = "w",
	["heath"] = true,
	["hill station"] = "w",
	["hill town"] = "w",
	["historical region"] = "w",
	["home rule city"] = "w",
	["home rule municipality"] = "w",
	["housing estate"] = true,
	["independent city"] = true,
	["Indian reservation"] = "w", -- United States
	["Indian reserve"] = "w", -- Canada
	["inner city area"] = "[[inner city]] area",
	["island country"] = "w",
	["island municipality"] = "w",
	["judicial capital"] = "w",
	["kibbutz"] = true,
	["krai"] = true,
	["legislative capital"] = "[[legislative]] [[capital]]",
	["lieutenancy area"] = "w",
	["local authority district"] = "w",
	["local government area"] = "w",
	["local government district"] = "w",
	["local government district with borough status"] = "[[w:local government district|local government district]] with [[w:borough status|borough status]]",
	["local urban district"] = "w",
	["locality"] = "[[w:locality (settlement)|locality]]",
	["London borough"] = "w",
	["macroregion"] = true,
	["marginal sea"] = true,
	["market town"] = true,
	["metropolitan borough"] = true,
	["metropolitan county"] = true,
	["metro station"] = true,
	["minster town"] = "[[minster]] town", -- England
	["moor"] = true,
	["moorland"] = true,
	["mountain indigenous district"] = "[[w:district (Taiwan)|mountain indigenous district]]", -- Taiwan
	["mountain indigenous township"] = "[[w:township (Taiwan)|mountain indigenous township]]", -- Taiwan
	["mountain pass"] = true,
	["mountain range"] = true,
	["mountainous region"] = "[[mountainous]] [[region]]",
	["municipal district"] = "w",
	["municipality"] = true,
	["municipality with city status"] = "[[municipality]] with [[w:city status|city status]]",
	["national capital"] = "w",
	["national park"] = true,
	["non-metropolitan county"] = "w",
	["non-metropolitan district"] = "w",
	["oblast"] = true,
	["overseas collectivity"] = "w",
	["overseas department"] = "w",
	["overseas territory"] = "w",
	["parish"] = true,
	["parish municipality"] = "[[w:parish municipality (Quebec)|parish municipality]]",
	["parish seat"] = true,
	["pass"] = "[[mountain pass|pass]]",
	["periphery"] = true,
	["planned community"] = true,
	["populated place"] = "[[w:populated place|locality]]",
	["port"] = true,
	["port city"] = true,
	["port town"] = "w",
	["prefecture"] = true,
	["prefecture-level city"] = "w",
	["province"] = true,
	["provincial capital"] = true,
	["regency"] = true,
	["regional capital"] = "[[regional]] [[capital]]",
	["regional county municipality"] = "w",
	["regional district"] = "w",
	["regional municipality"] = "w",
	["regional unit"] = "w",
	["registration county"] = true,
	["research base"] = "[[research]] [[base]]",
	["residental area"] = "[[residential]] area",
	["resort city"] = "w",
	["resort town"] = "w",
	["royal burgh"] = true,
	["rural community"] = "w",
	["rural municipality"] = "w",
	["rural township"] = "[[w:rural township (Taiwan)|rural township]]", -- Taiwan
	["satrapy"] = true,
	["seaport"] = true,
	["settlement"] = true,
	["sheading"] = true, -- Isle of Man
	["sheep station"] = true, -- Australia
	["shire"] = true,
	["shire county"] = "w",
	["shire town"] = true,
	["ski resort town"] = "[[ski resort]] town",
	["spa city"] = "[[w:spa town|spa city]]",
	["spa town"] = "w",
	["special administrative region"] = "w", -- China; North Korea; Indonesia; East Timor
	["special collectivity"] = "w",
	["spit"] = true,
	["state capital"] = true,
	["state park"] = true,
	["statutory city"] = "w",
	["statutory town"] = "w",
	["strait"] = true,
	["subdistrict"] = true,
	["subdivision"] = true,
	["submerged ghost town"] = "[[submerged]] [[ghost town]]",
	["subprefecture"] = true,
	["subprovince"] = true,
	["subprovincial city"] = "w",
	["sub-prefectural city"] = "w",
	["subregion"] = true,
	["suburb"] = true,
	["subway station"] = "w",
	["supercontinent"] = true,
	["tehsil"] = true,
	["territorial authority"] = "w",
	["township"] = true,
	["township municipality"] = "[[w:township municipality (Quebec)|township municipality]]",
	-- can't use templates in this code
	["town with bystatus"] = "[[town]] with [[bystatus#Norwegian Bokmål|bystatus]]",
	["traditional county"] = true,
	["traditional region"] = "w",
	["treaty port"] = "w",
	["tribal jurisdictional area"] = "w",
	["tributary"] = true,
	["underground station"] = "w",
	["unincorporated territory"] = "w",
	["unitary authority"] = true,
	["unitary district"] = "w",
	["united township municipality"] = "[[w:united township municipality (Quebec)|united township municipality]]",
	["unrecognised country"] = "w",
	["unrecognized country"] = "w",
	["urban area"] = "[[urban]] area",
	["urban township"] = "w",
	["urban-type settlement"] = "w",
	["village municipality"] = "[[w:village municipality (Quebec)|village municipality]]",
	["voivodeship"] = true, -- Poland
	["ward"] = true,
	["watercourse"] = true,
}


-- In this table, the key qualifiers should be treated the same as the value qualifiers for
-- categorization purposes. This is overridden by cat_data, placetype_equivs and
-- qualifier_to_placetype_equivs.
export.qualifier_equivs = {
	["ancient"] = "historical",
	["former"] = "historical",
	["historic"] = "historical",
	-- This needs to be here. If we take it out, 'historic province' won't properly
	-- map to 'historical political subdivision'.
	["historical"] = "historical",
	["medieval"] = "historical",
	["mediaeval"] = "historical",
	["traditional"] = "historical",
}

-- In this table, any placetypes containing these qualifiers that do not occur in placetype_equivs
-- or cat_data should be mapped to the specified placetypes for categorization purposes. Entries here
-- are overridden by cat_data and placetype_equivs.
export.qualifier_to_placetype_equivs = {
	["fictional"] = "fictional location",
	["mythological"] = "mythological location",
}

-- In this table, the key placetypes should be treated the same as the value placetypes for
-- categorization purposes. Entries here are overridden by cat_data.
-- NOTE: 'coal town', 'county town', 'ghost town', 'resort town', 'ski resort town',
-- 'spa town', etc. aren't mapped to 'town' because they aren't necessarily towns.
export.placetype_equivs = {
	["administrative center"] = "administrative centre",
	["administrative headquarters"] = "administrative centre",
	["administrative seat"] = "administrative centre",
	["archipelago"] = "island",
	["associated province"] = "province",
	["autonomous prefecture"] = "prefecture",
	["autonomous province"] = "province",
	["autonomous territory"] = "dependent territory",
	["bailiwick"] = "polity",
	["barangay"] = "neighborhood", -- not completely correct, barangays are formal administrative divisions of a city
	["barrio"] = "neighborhood", -- not completely correct, in some countries barrios are formal administrative divisions of a city
	["bishopric"] = "polity",
	["built-up area"] = "area",
	["burgh"] = "borough",
	["cape"] = "peninsula",
	["capital"] = "capital city",
	["caravan city"] = "city", -- should be 'former city' if we distinguish that
	["cathedral city"] = "city",
	["central business district"] = "neighborhood",
	["ceremonial county"] = "county",
	["chain of islands"] = "island",
	["charter community"] = "village",
	["commandery"] = "historical political subdivision",
	["community"] = "village",
	["constituent country"] = "country",
	["contregion"] = "region",
	["county-controlled city"] = "county-administered city",
	["county-level city"] = "prefecture-level city",
	["crown dependency"] = "dependency",
	["direct-administered municipality"] = "municipality",
	["direct-controlled municipality"] = "municipality",
	["distributary"] = "river",
	["district headquarters"] = "administrative centre",
	["duchy"] = "polity",
	["empire"] = "polity",
	["external territory"] = "dependent territory",
	["federal territory"] = "territory",
	["First Nations reserve"] = "Indian reserve",
	["geographical region"] = "region",
	["glen"] = "valley",
	["group of islands"] = "island",
	["hamlet"] = "village",
	["harbor city"] = "city",
	["harbour city"] = "city",
	["harbor town"] = "town",
	["harbour town"] = "town",
	["headquarters"] = "administrative centre",
	["heath"] = "moor",
	["hill station"] = "town",
	["hill town"] = "town",
	-- We try to list all top-level polities and political subdivisions here and classify them
	-- accordingly. (Note that the following entries also apply to anything preceded by "former",
	-- "ancient", "historic", "medieval", etc., according to qualifier_equivs.) Anything we don't
	-- list will be categorized as if the qualifier were absent, e.g. "ancient city" will be
	-- categorized as a city and "former sea" as a sea.
	["historical autonomous republic"] = "historical political subdivision",
	["historical autonomous territory"] = "historical political subdivision",
	["historical borough"] = "historical political subdivision",
	["historical canton"] = "historical political subdivision",
	["historical bailiwick"] = "historical polity",
	["historical barangay"] = "historical political subdivision",
	["historical bishopric"] = "historical polity",
	["historical civilisation"] = "historical polity",
	["historical civilization"] = "historical polity",
	["historical civil parish"] = "historical political subdivision",
	["historical colony"] = "historical polity",
	["historical commandery"] = "historical political subdivision",
	["historical commonwealth"] = "historical polity",
	["historical commune"] = "historical political subdivision",
	["historical council area"] = "historical political subdivision",
	["historical county"] = "historical political subdivision",
	["historical county borough"] = "historical political subdivision",
	["historical country"] = "historical polity",
	["historical crown dependency"] = "historical polity",
	["historical department"] = "historical political subdivision",
	["historical dependency"] = "historical polity",
	["historical district"] = "historical political subdivision",
	["historical division"] = "historical political subdivision",
	["historical duchy"] = "historical polity",
	["historical empire"] = "historical polity",
	["historical governorate"] = "historical political subdivision",
	["historical kingdom"] = "historical polity",
	["historical krai"] = "historical political subdivision",
	["historical maritime republic"] = "historical polity",
	["historical metropolitan borough"] = "historical political subdivision",
	["historical municipality"] = "historical political subdivision",
	["historical oblast"] = "historical political subdivision",
	["historical okrug"] = "historical political subdivision",
	["historical parish"] = "historical political subdivision",
	["historical periphery"] = "historical political subdivision",
	["historical prefecture"] = "historical political subdivision",
	["historical province"] = "historical political subdivision",
	["historical regency"] = "historical political subdivision",
	["historical regional unit"] = "historical political subdivision",
	["historical republic"] = "historical polity",
	["historical satrapy"] = "historical polity",
	["historical separatist state"] = "historical polity",
	-- The following could refer either to a state of a country (a subdivision)
	-- or a state = sovereign entity. The latter appears more common (e.g. in
	-- various "ancient states" of East Asia).
	["historical state"] = "historical polity",
	["historical subdistrict"] = "historical political subdivision",
	["historical subdivision"] = "historical political subdivision",
	["historical subprefecture"] = "historical political subdivision",
	["historical voivodeship"] = "historical political subdivision",
	["home rule city"] = "city",
	["home rule municipality"] = "municipality",
	["independent city"] = "city",
	["inner city area"] = "neighborhood",
	["island country"] = "country",
	["island municipality"] = "municipality",
	["judicial capital"] = "capital city",
	["kingdom"] = "polity",
	["legislative capital"] = "capital city",
	["local authority district"] = "local government district",
	["local government district with borough status"] = "local government district",
	["local urban district"] = "unincorporated community",
	["locality"] = "village", -- not necessarily true
	["market town"] = "town",
	["mediaeval city"] = "ancient city",
	["medieval city"] = "ancient city",
	["metropolitan county"] = "county",
	["minster town"] = "town",
	["moorland"] = "moor",
	["mountain indigenous district"] = "district",
	["mountain indigenous township"] = "township",
	["mountain range"] = "mountain",
	["mountainous region"] = "region",
	["municipality with city status"] = "municipality",
	["national capital"] = "capital city",
	["national park"] = "park",
	["neighbourhood"] = "neighborhood",
	["new town"] = "town",
	["non-metropolitan county"] = "county",
	["non-metropolitan district"] = "local government district",
	["overseas collectivity"] = "collectivity",
	["overseas department"] = "department",
	["overseas territory"] = "territory",
	["pass"] = "mountain pass",
	["populated place"] = "village", -- not necessarily true
	["port city"] = "city",
	["port town"] = "town",
	["regional municipality"] = "municipality",
	["resort city"] = "city",
	["royal burgh"] = "borough",
	["royal capital"] = "capital city",
	["settlement"] = "village",
	["sheading"] = "district",
	["shire"] = "county",
	["shire county"] = "county",
	["shire town"] = "county seat",
	["spa city"] = "city",
	["spit"] = "peninsula",
	["state park"] = "park",
	["statutory city"] = "city",
	["statutory town"] = "town",
	["stream"] = "river",
	["submerged ghost town"] = "ghost town",
	["sub-prefectural city"] = "subprovincial city",
	["suburban area"] = "suburb",
	["subway station"] = "metro station",
	["supercontinent"] = "continent",
	["traditional county"] = "county",
	["treaty port"] = "city", -- should be 'former city' if we distinguish that
	["territorial authority"] = "district",
	["underground station"] = "metro station",
	["unincorporated territory"] = "territory",
	["unitary authority"] = "local government district",
	["unitary district"] = "local government district",
	["united township municipality"] = "township municipality",
	["unrecognised country"] = "unrecognized country",
	["urban area"] = "neighborhood",
	["urban township"] = "township",
	["urban-type settlement"] = "town",
	["town with bystatus"] = "town",
	["tributary"] = "river",
	["ward"] = "neighborhood", -- not completely correct, wards are formal administrative divisions of a city
}


-- These contain transformations applied to certain placenames to convert them
-- into displayed form. For example, if any of "country/US", "country/USA" or
-- "country/United States of America" (or "c/US", etc.) are given, the result
-- will be displayed as "United States".
export.placename_display_aliases = {
	["autonomous community"] = {
		["Valencian Community"] = "Valencia",
	},
	["city"] = {
		["New York"] = "New York City",
		["Washington, DC"] = "Washington, D.C.",
	},
	["country"] = {
		["US"] = "United States",
		["U.S."] = "United States",
		["USA"] = "United States",
		["U.S.A."] = "United States",
		["United States of America"] = "United States",
		["UK"] = "United Kingdom",
		["UAE"] = "United Arab Emirates",
		["Republic of North Macedonia"] = "North Macedonia",
		["Republic of Macedonia"] = "North Macedonia",
		["Republic of Ireland"] = "Ireland",
		["Republic of Armenia"] = "Armenia",
		["Congo"] = "Democratic Republic of the Congo",
		["Côte d'Ivoire"] = "Ivory Coast",
		["Czechia"] = "Czech Republic",
		["Vatican"] = "Vatican City",
	},
	["region"] = {
		["Northern Ostrobothnia"] = "North Ostrobothnia",
		["Southern Ostrobothnia"] = "South Ostrobothnia",
		["North Savo"] = "Northern Savonia",
		["South Savo"] = "Southern Savonia",
		["Päijät-Häme"] = "Päijänne Tavastia",
		["Kanta-Häme"] = "Tavastia Proper",
		["Åland"] = "Åland Islands",
	},
	["state"] = {
		["Mecklenburg-Western Pomerania"] = "Mecklenburg-Vorpommern",
		["Mexico"] = "State of Mexico",
	},
	["territory"] = {
		["U.S. Virgin Islands"] = "United States Virgin Islands",
		["US Virgin Islands"] = "United States Virgin Islands",
	},
}


-- These contain transformations applied to the displayed form of certain
-- placenames to convert them into the form they will appear in categories.
-- For example, either of "country/Myanmar" and "country/Burma" will be
-- categorized into categories with "Burma" in them (but the displayed form
-- will respect the form as input). (NOTE, the choice of names here should not
-- be taken to imply any political position; it is just this way because it has
-- always been this way.)
export.placename_cat_aliases = {
	["council area"] = {
		["Glasgow"] = "City of Glasgow",
		["Edinburgh"] = "City of Edinburgh",
		["Aberdeen"] = "City of Aberdeen",
		["Dundee"] = "City of Dundee",
		["Western Isles"] = "Na h-Eileanan Siar",
	},
	["country"] = {
		-- will categorize into e.g. "Cities in Burma".
		["Myanmar"] = "Burma",
		["Nagorno-Karabakh"] = "Artsakh",
		["People's Republic of China"] = "China",
		["Republic of China"] = "Taiwan",
	},
	["county"] = {
		["Anglesey"] = "Isle of Anglesey",
	},
}


-- This contains placenames that should be preceded by an article (almost always "the").
-- NOTE: There are multiple ways that placenames can come to be preceded by "the":
-- 1. Listed here.
-- 2. Given in [[Module:place/shared-data]] with an initial "the". All such placenames
--    are added to this map by the code just below the map.
-- 3. The placetype of the placename has holonym_article = "the" in its cat_data.
-- 4. A regex in placename_the_re matches the placename.
-- Note that "the" is added only before the first holonym in a place spec.
export.placename_article = {
	-- This should only contain info that can't be inferred from [[Module:place/shared-data]].
	["archipelago"] = {
		["Cyclades"] = "the",
		["Dodecanese"] = "the",
	},
	["borough"] = {
		["Bronx"] = "the",
	},
	["country"] = {
		["Holy Roman Empire"] = "the",
	},
	["island"] = {
		["North Island"] = "the",
		["South Island"] = "the",
	},
	["region"] = {
		["Balkans"] = "the",
		["Caribbean"] = "the",
		["Caucasus"] = "the",
		["North Caucasus"] = "the",
		["South Caucasus"] = "the",
	},
	["valley"] = {
		["San Fernando Valley"] = "the",
	},
}

-- Regular expressions to apply to determine whether we need to put 'the' before
-- a holonym. The key "*" applies to all holonyms, otherwise only the regexes
-- for the holonym's placetype apply.
export.placename_the_re = {
	-- We don't need entries for peninsulas, seas, oceans, gulfs or rivers
	-- because they have holonym_article = "the".
	["*"] = {"^Isle of ", " Islands$", " Mountains$", " Empire$", " Country$", " Region$", " District$", "^City of "},
	["bay"] = {"^Bay of "},
	["lake"] = {"^Lake of "},
	["country"] = {"^Republic of ", " Republic$"},
	["republic"] = {"^Republic of ", " Republic$"},
	["region"] = {" [Rr]egion$"},
	["river"] = {" River$"},
	["local government area"] = {"^Shire of "},
	["county"] = {"^Shire of "},
	["Indian reservation"] = {" Reservation", " Nation"},
	["tribal jurisdictional area"] = {" Reservation", " Nation"},
}

-- Now extract from the shared place data all the other places that need "the"
-- prefixed.
for _, group in ipairs(m_shared.polities) do
	for key, value in pairs(group.data) do
		key = key:gsub(", .*$", "") -- Chop off ", England" and such from the end
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


-- If any of the following holonyms are present, the associated holonyms are automatically added
-- to the end of the list of holonyms for display and categorization purposes.
-- FIXME: There are none here currently and the mechanism is broken in that it doesn't properly
-- check for the presence of the holonym already. Don't add any without fixing this, or we'll
-- get redundantly-displayed holonyms in the common case where e.g. "Alabama, USA" is specified.
-- See below under cat_implications.
-- FIXME: Consider implementing a handler to automatically add implications for all political
-- subdivisions listed in the groups in [[Module:place/shared-data]], with the containing polity
-- as the implicand. That way, if someone writes e.g. {{place|en|village|s/Thuringia}}, it will
-- automatically display as if written {{place|en|village|s/Thuringia|c/Germany}}.
export.implications = {
}


-- If any of the following holonyms are present, the associated holonyms are automatically added
-- to the end of the list of holonyms for categorization (but not display) purposes.
-- FIXME: We should implement an implication handler to add cat_implications for all political
-- subdivisions listed in the groups in [[Module:place/shared-data]], with the containing polity
-- as the implicand. (This should be a handler not a preprocessing step to save memory.) Before
-- doing that, we should fix the implication mechanism to not add a holonym if the holonym
-- already exists or a conflicting holonym exists, where "conflicting" means a different holonym
-- of the same placetype as the holonym being added. Hence, if e.g. two countries have a province of
-- the same name, and we have an entry for one of the provinces, we won't add that province's country
-- if the other country is already specified.
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


export.cat_implication_handlers = {}

table.insert(export.cat_implication_handlers,
	function(placetype, holonym_placetype, holonym_placename)
		for _, group in ipairs(m_shared.polities) do
			-- Find the appropriate key format for the holonym (e.g. "pref/Osaka" -> "Osaka Prefecture").
			local key = group.place_cat_handler(group, placetype, holonym_placetype, holonym_placename)
			if key then
				local value = group.data[key]
				if value and value.containing_polity and value.containing_polity_type then
					local bare_containing_polity, linked_containing_polity =
						m_shared.construct_bare_and_linked_version(value.containing_polity)
					return {value.containing_polity_type, bare_containing_polity}
				end
			end
		end
	end
)

----------- Basic utilities -----------

-- Return the singular version of a maybe-plural placetype, or nil if not plural.
function export.maybe_singularize(placetype)
	if not placetype then
		return nil
	end
	local retval = m_strutils.singularize(placetype)
	if retval == placetype then
		return nil
	end
	return retval
end


-- Given a placetype, split the placetype into one or more potential "splits", each consisting
-- of (a) a recognized qualifier (e.g. "small", "former"), which we canonicalize
-- (e.g. "historic" -> "historical", "seaside" -> "coastal"); (b) the concatenation of any
-- previously recognized qualifiers on the left; and (c) the "bare placetype" to the right of
-- the rightmost recognized qualifier. Return a list of pairs of
-- {PREV_CANON_QUALIFIERS, THIS_CANON_QUALIFIER, BARE_PLACETYPE}, as above. There may be
-- more than one element in the list in cases like "small unincorporated town". If no recognized
-- qualifier could be found, the list will be empty. PREV_CANON_QUALIFIERS will be nil if there
-- are no previous qualifiers.
function export.split_and_canonicalize_placetype(placetype)
	local splits = {}
	local prev_qualifier = nil
	while true do
		local qualifier, bare_placetype = placetype:match("^(.-) (.*)$")
		if qualifier then
			local canon = export.placetype_qualifiers[qualifier]
			local new_qualifier
			if canon == true then
				new_qualifier = qualifier
			elseif canon then
				new_qualifier = canon
			else
				break
			end
			table.insert(splits, {prev_qualifier, new_qualifier, bare_placetype})
			prev_qualifier = prev_qualifier and prev_qualifier .. " " .. new_qualifier or new_qualifier
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
function export.get_placetype_equivs(placetype)
	local equivs = {}

	local function do_placetype(qualifier, placetype)
		-- FIXME! The qualifier (first arg) is inserted into the table, but isn't
		-- currently used anywhere.

		-- First do the placetype itself.
		table.insert(equivs, {qualifier=qualifier, placetype=placetype})
		-- Then check for a singularized equivalent.
		local sg_placetype = export.maybe_singularize(placetype)
		if sg_placetype then
			table.insert(equivs, {qualifier=qualifier, placetype=sg_placetype})
		end
		-- Then check for a mapping in placetype_equivs; add if present.
		if export.placetype_equivs[placetype] then
			table.insert(equivs, {qualifier=qualifier, placetype=export.placetype_equivs[placetype]})
		end
		-- Then check for a mapping in placetype_equivs for the singularized equivalent.
		if sg_placetype and export.placetype_equivs[sg_placetype] then
			table.insert(equivs, {qualifier=qualifier, placetype=export.placetype_equivs[sg_placetype]})
		end
	end

	do_placetype(nil, placetype)

	-- Then successively split off recognized qualifiers and loop over successively greater sets of
	-- qualifiers from the left.
	local splits = export.split_and_canonicalize_placetype(placetype)
	for _, split in ipairs(splits) do
		local prev_qualifier, this_qualifier, bare_placetype = split[1], split[2], split[3]
		-- First see if the rightmost split-off qualifier is in qualifier_to_placetype_equivs
		-- (e.g. 'fictional *' -> 'fictional location'). If so, add the mapping.
		if export.qualifier_to_placetype_equivs[this_qualifier] then
			table.insert(equivs, {qualifier=prev_qualifier, placetype=export.qualifier_to_placetype_equivs[this_qualifier]})
		end
		-- Then see if the rightmost split-off qualifier is in qualifier_equivs (e.g. 'former' -> 'historical').
		-- If so, create a placetype from the qualifier mapping + the following bare_placetype; then, add
		-- that placetype, and any mapping for the placetype in placetype_equivs.
		if export.qualifier_equivs[this_qualifier] then
			do_placetype(prev_qualifier, export.qualifier_equivs[this_qualifier] .. " " .. bare_placetype)
		end
		-- Finally, join the rightmost split-off qualifier to the previously split-off qualifiers to form a
		-- combined qualifier, and add it along with bare_placetype and any mapping in placetype_equivs for
		-- bare_placetype.
		local qualifier = prev_qualifier and prev_qualifier .. " " .. this_qualifier or this_qualifier
		do_placetype(qualifier, bare_placetype)
	end
	return equivs
end


function export.get_equiv_placetype_prop(placetype, fun)
	if not placetype then
		return fun(nil), nil
	end
	local equivs = export.get_placetype_equivs(placetype)
	for _, equiv in ipairs(equivs) do
		local retval = fun(equiv.placetype)
		if retval then
			return retval, equiv
		end
	end
	return nil, nil
end

------------------------------------------------------

local function city_type_cat_handler(placetype, holonym_placetype, holonym_placename, ignore_nocities, no_containing_polity,
		extracats)
	local plural_placetype = m_strutils.pluralize(placetype)
	if m_shared.generic_place_types[plural_placetype] then
		for _, group in ipairs(m_shared.polities) do
			-- Find the appropriate key format for the holonym (e.g. "pref/Osaka" -> "Osaka Prefecture").
			local key = group.place_cat_handler(group, placetype, holonym_placetype, holonym_placename)
			if key then
				local value = group.data[key]
				if value then
					-- Use the group's value_transformer to ensure that 'nocities', 'containing_polity'
					-- and 'british_spelling' keys are present if they should be.
					value = group.value_transformer(group, key, value)
					if ignore_nocities or not value.nocities then
						-- Categorize both in key, and in the larger polity that the key is part of,
						-- e.g. [[Hirakata]] goes in both "Cities in Osaka Prefecture" and
						-- "Cities in Japan". (But don't do the latter if no_containing_polity_cat is set.)
						if plural_placetype == "neighborhoods" and value.british_spelling then
							plural_placetype = "neighbourhoods"
						end
						local retcats = {ucfirst(plural_placetype) .. " in " .. key}
						if value.containing_polity and not value.no_containing_polity_cat and not no_containing_polity then
							table.insert(retcats, ucfirst(plural_placetype) .. " in " .. value.containing_polity)
						end
						if extracats then
							for _, cat in ipairs(extracats) do
								table.insert(retcats, cat)
							end
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


-- This is used to add pages to base holonym categories like 'en:Places in Merseyside, England'
-- (and 'en:Places in England') for any pages that have 'co/Merseyside' as their holonym.
-- It also handles cities (e.g. 'en:Places in Boston', along with 'en:Places in Massachusetts, USA'
-- and 'en:Places in the United States') for any pages that have 'city/Boston' as their holonym.
local function generic_cat_handler(holonym_placetype, holonym_placename, place_spec)
	for _, group in ipairs(m_shared.polities) do
		-- Find the appropriate key format for the holonym (e.g. "pref/Osaka" -> "Osaka Prefecture").
		local key = group.place_cat_handler(group, "*", holonym_placetype, holonym_placename)
		if key then
			local value = group.data[key]
			if value then
				-- Use the group's value_transformer to ensure that 'nocities' and 'containing_polity'
				-- keys are present if they should be.
				value = group.value_transformer(group, key, value)
				-- Categorize both in key, and in the larger polity that the key is part of,
				-- e.g. [[Hirakata]] goes in both "Places in Osaka Prefecture" and "Places in Japan".
				local retcats = {"Places in " .. key}
				if value.containing_polity and not value.no_containing_polity_cat then
					table.insert(retcats, "Places in " .. value.containing_polity)
				end
				return {
					["itself"] = retcats
				}
			end
		end
	end
	-- Check for cities mentioned as holonyms.
	if holonym_placetype == "city" then
		for _, city_group in ipairs(m_shared.cities) do
			local value = city_group.data[holonym_placename]
			if value and value.alias_of then
				local new_value = city_group.data[value.alias_of]
				if not new_value then
					error("City '" .. holonym_placename .. "' has an entry with non-existent alias_of='" .. value.alias_of .. "'")
				end
				holonym_placename = value.alias_of
				value = new_value
			end
			if value then
				-- Check if any of the city's containing polities are explicitly mentioned. If not, make sure
				-- that no other polities of the same sort are mentioned.
				local containing_polities = m_shared.get_city_containing_polities(city_group, holonym_placename, value)
				local containing_polities_match = false
				local containing_polities_mismatch = false
				for _, polity in ipairs(containing_polities) do
					local bare_polity, linked_polity = m_shared.construct_bare_and_linked_version(polity[1])
					local divtype = polity.divtype or city_group.default_divtype
					local function holonym_matches_polity(placetype)
						if not place_spec[placetype] then
							return false
						end
						for _, holonym in ipairs(place_spec[placetype]) do
							if holonym == bare_polity then
								return true
							end
						end
						return false
					end
					containing_polities_match = export.get_equiv_placetype_prop(divtype, holonym_matches_polity)
					if containing_polities_match then
						break
					end
					containing_polities_mismatch = export.get_equiv_placetype_prop(divtype, function(pt) return not not place_spec[pt] end)
					if containing_polities_mismatch then
						break
					end
				end
				-- No mismatching containing polities, so add categories for the city and
				-- its containing polities.
				if not containing_polities_mismatch then
					local retcats = {"Places in " .. holonym_placename}
					for _, polity in ipairs(containing_polities) do
						local divtype = polity.divtype or city_group.default_divtype
						local drop_dead_now = false
						-- Find the group and key corresponding to the polity.
						for _, polity_group in ipairs(m_shared.polities) do
							local key = polity[1]
							if polity_group.placename_to_key then
								key = polity_group.placename_to_key(key)
							end
							local value = polity_group.data[key]
							if value then
								value = polity_group.value_transformer(polity_group, key, value)
								local key_divtype = value.divtype or polity_group.default_divtype
								if key_divtype == divtype or type(key_divtype) == "table" and key_divtype[1] == divtype then
									table.insert(retcats, "Places in " .. key)
									if value.no_containing_polity_cat then
										-- Stop adding containing polities if no_containing_polity_cat
										-- is found. (Used for 'United Kingdom'.)
										drop_dead_now = true
									end
									break
								end
							end
						end
						if drop_dead_now then
							break
						end
					end
					return {
						["itself"] = retcats
					}
				end
			end
		end
	end
end


-- Inner data returned by cat handler for districts, neighborhoods, etc.
local function district_inner_data(value, itself_dest)
	local retval = {
		["city"] = value,
		["town"] = value,
		["township"] = value,
		["municipality"] = value,
		["borough"] = value,
		["London borough"] = value,
		["census-designated place"] = value,
		["village"] = value,
	}
	if itself_dest then
		retval["itself"] = itself_dest
	end
	return retval
end


-- Cat handler for districts and areas. Districts are tricky because they can
-- either be political subdivisions or city neighborhoods. We handle this as follows:
-- (1) For countries etc. where they can be political subdivisions, an entry under
-- "district" will be inserted for the country with something similar to the following:
--
-- {
--		["itself"] = {"Districts of Foo"},
--		["city"] = {"Neighborhoods in Foo"},
--		["town"] = {"Neighborhoods in Foo"},
--		["borough"] = {"Neighborhoods in Foo"},
--		...
-- }
--
-- This way, a district in a city will categorize under "Neighborhoods in Foo"
-- while some other district will categorize under "Districts of Foo".
-- (2) For the remaining countries, we have a cat_handler that returns the following
-- for all known countries and primary subdivisions:
--
-- {
--		["city"] = {"Neighborhoods in Foo"},
--		["town"] = {"Neighborhoods in Foo"},
--		["borough"] = {"Neighborhoods in Foo"},
--		...
-- }
--
-- This way, a district under a city will still categorize under "Neighborhoods in Foo"
-- while other districts won't categorize.
local function district_cat_handler(placetype, holonym_placetype, holonym_placename)
	for _, group in ipairs(m_shared.polities) do
		-- Find the appropriate key format for the holonym (e.g. "pref/Osaka" -> "Osaka Prefecture").
		local key = group.place_cat_handler(group, placetype, holonym_placetype, holonym_placename)
		if key then
			local value = group.data[key]
			if value then
				value = group.value_transformer(group, key, value)
				if value.british_spelling then
					return district_inner_data({"Neighbourhoods in " .. key})
				else
					return district_inner_data({"Neighborhoods in " .. key})
				end
			end
		end
	end
end


local function chinese_subcity_cat_handler(holonym_placetype, holonym_placename, place_spec)
	local spec = m_shared.chinese_provinces_and_autonomous_regions[holonym_placename]
	if spec and holonym_placetype == (spec.divtype or "province") then
		return {
			["itself"] = {"Cities in " .. holonym_placename}
		}
	end
end


function export.check_already_seen_string(holonym_placename, already_seen_strings)
	local canon_placename = lc(m_links.remove_links(holonym_placename))
	if type(already_seen_strings) ~= "table" then
		already_seen_strings = {already_seen_strings}
	end
	for _, already_seen_string in ipairs(already_seen_strings) do
		if canon_placename:find(already_seen_string) then
			return true
		end
	end
	return false
end


-- Prefix display handler that adds a prefix such as "Metropolitan Borough of " to the display
-- form of holonyms. We make sure the holonym doesn't contain the prefix or some variant already.
-- We do this by checking if any of the strings in ALREADY_SEEN_STRINGS, either a single string or
-- a list of strings, or the prefix if ALREADY_SEEN_STRINGS is omitted, are found in the holonym
-- placename, ignoring case and links. If the prefix isn't already present, we create a link that
-- uses the raw form as the link destination but the prefixed form as the display form, unless the
-- holonym already has a link in it, in which case we just add the prefix.
local function prefix_display_handler(prefix, holonym_placename, already_seen_strings)
	if export.check_already_seen_string(holonym_placename, already_seen_strings or lc(prefix)) then
		return holonym_placename
	end
	if holonym_placename:find("%[%[") then
		return prefix .. " " .. holonym_placename
	end
	return prefix .. " [[" .. holonym_placename .. "]]"
end


-- Suffix display handler that adds a suffix such as " parish" to the display form of holonyms.
-- Works identically to prefix_display_handler but for suffixes instead of prefixes.
local function suffix_display_handler(suffix, holonym_placename, already_seen_strings)
	if export.check_already_seen_string(holonym_placename, already_seen_strings or lc(suffix)) then
		return holonym_placename
	end
	if holonym_placename:find("%[%[") then
		return holonym_placename .. " " .. suffix
	end
	return "[[" .. holonym_placename .. "]] " .. suffix
end


-- Display handler for counties. Irish counties are displayed as e.g. "County [[Cork]]".
-- Others are displayed as-is.
local function county_display_handler(holonym_placetype, holonym_placename)
	local unlinked_placename = m_links.remove_links(holonym_placename)
	if m_shared.irish_counties["County " .. unlinked_placename .. ", Ireland"] or
		m_shared.northern_irish_counties["County " .. unlinked_placename .. ", Northern Ireland"] then
		return prefix_display_handler("County", holonym_placename)
	end
	return holonym_placename
end


-- Display handler for boroughs. New York City boroughs are display as-is. Others are suffixed
-- with "borough".
local function borough_display_handler(holonym_placetype, holonym_placename)
	local unlinked_placename = m_links.remove_links(holonym_placename)
	if m_shared.new_york_boroughs[unlinked_placename] then
		-- Hack: don't display "borough" after the names of NYC boroughs
		return holonym_placename
	end
	return suffix_display_handler("borough", holonym_placename)
end


-- Display handler for prefectures. Japanese prefectures are displayed as e.g. "[[Fukushima]] Prefecture".
-- Others are displayed as e.g. "[[Fthiotida]] prefecture".
local function prefecture_display_handler(holonym_placetype, holonym_placename)
	local unlinked_placename = m_links.remove_links(holonym_placename)
	local suffix = m_shared.japanese_prefectures[unlinked_placename .. " Prefecture"] and "Prefecture" or "prefecture"
	return suffix_display_handler(suffix, holonym_placename)
end


export.cat_data = {
	["administrative village"] = {
		preposition = "of",

		["default"] = {
			["municipality"] = {true},
		},
	},

	["administrative capital"] = {
		article = "the",
		preposition = "of",

		["default"] = {
			["municipality"] = {true},
		},
	},

	["administrative centre"] = {
		article = "the",
		preposition = "of",
	},

	["airport"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["area"] = {
		cat_handler = function(holonym_placetype, holonym_placename, place_spec)
			return district_cat_handler("area", holonym_placetype, holonym_placename)
		end,
	},

	["atoll"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["autonomous community"] = {
		preposition = "of",

		["default"] = {
			["country"] = {true},
		},
	},

	["autonomous oblast"] = {
		preposition = "of",
	},

	["autonomous okrug"] = {
		preposition = "of",
	},

	["autonomous region"] = {
		preposition = "of",

		["country/Portugal"] = {
			["itself"] = {"Districts and autonomous regions of +++"},
		},

		["country/China"] = {
			["country"] = {true},
		},
	},

	["autonomous republic"] = {
		preposition = "of",

		["country/Soviet Union"] = {
			["country"] = {true},
		},
	},

	["bay"] = {
		preposition = "of",

		["default"] = {
			["itself"] = {true},
		},
	},

	["beach"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["borough"] = {
		preposition = "of",
		display_handler = borough_display_handler,
		cat_handler = function(holonym_placetype, holonym_placename, place_spec)
			if holonym_placetype == "county" then
				local cat_form = holonym_placename .. ", England"
				if not m_shared.english_counties[cat_form] then
					cat_form = "the " .. cat_form
					if not m_shared.english_counties[cat_form] then
						cat_form = nil
					end
				end
				if cat_form then
					return {
						["itself"] = {"Districts of " .. cat_form, "Districts of England"}
					}
				end
			end
			if (holonym_placetype == "country" or holonym_placetype == "constituent country") and
				holonym_placename == "England" then
					return {
						["itself"] = {"Districts of +++"},
					}
			end
		end,

		["state/Alaska"] = {
			["itself"] = {"Boroughs of +++, USA"},
		},

		["city/New York City"] = {
			["itself"] = {"Boroughs in +++"},
		},

		["state/Pennsylvania"] = {
			["itself"] = {"Boroughs in +++, USA"},
		},

		["state/New Jersey"] = {
			["itself"] = {"Boroughs in +++, USA"},
		},
	},

	["borough seat"] = {
		article = "the",
		preposition = "of",

		["state/Alaska"] = {
			["itself"] = {"Borough seats of +++, USA"},
		},
	},

	["canton"] = {
		preposition = "of",

		["default"] = {
			["country"] = {true},
		},
	},

	["capital city"] = {
		article = "the",
		preposition = "of",
		cat_handler = function(holonym_placetype, holonym_placename, place_spec)
			return city_type_cat_handler("city", holonym_placetype, holonym_placename,
				nil, nil, {"Capital cities"})
		end,

		["default"] = {
			["itself"] = {true},
		},
	},

	["census area"] = {
		affix_type = "Suf",
	},

	["census-designated place"] = {
		cat_handler = function(holonym_placetype, holonym_placename, place_spec)
			if holonym_placetype == "state" then
				return city_type_cat_handler("census-designated place", holonym_placetype, holonym_placename)
			end
		end,

		["country/United States"] = {
			["itself"] = {true},
		},
	},

	["civil parish"] = {
		preposition = "of",
		affix_type = "suf",

		["country/England"] = {
			["itself"] = {"Civil parishes of +++"},
		},
	},

	["city"] = {
		cat_handler = function(holonym_placetype, holonym_placename, place_spec)
			return city_type_cat_handler("city", holonym_placetype, holonym_placename)
		end,

		["prefecture/Hokkaido"] = {
			["itself"] = {"Cities in +++"},
		},

		["default"] = {
			["itself"] = {true},
			["country"] = {true},
		},
	},

	["collectivity"] = {
		preposition = "of",

		["default"] = {
			["itself"] = {"Polities"},
			["country"] = {true},
		},
	},

	["colony"] = {
		preposition = "of",
	},

	["commonwealth"] = {
		preposition = "of",
	},

	["community development block"] = {
		affix_type = "suf",
		no_affix_strings = "block",
	},

	["continent"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["council area"] = {
		preposition = "of",
		affix_type = "suf",

		["default"] = {
			["itself"] = {true},
			["country"] = {true},
		},
	},

	["country"] = {
		synergy = {
			["macroregion"] = {
				before = "in the",
				between = "of",
			}
		},

		["default"] = {
			["continent"] = {true, "Countries"},
			["itself"] = {true},
		},
	},

	["county"] = {
		preposition = "of",
		-- UNITED STATES
		cat_handler = function(holonym_placetype, holonym_placename, place_spec)
			local spec = m_shared.us_states[holonym_placename .. ", USA"]
			if spec and holonym_placetype == "state" and not spec.county_type then
				return {
					["itself"] = {"Counties of " .. holonym_placename .. ", USA"}
				}
			end
		end,
		display_handler = county_display_handler,

		["country/Holy Roman Empire"] = {
		},

		["country/Northern Ireland"] = {
			["itself"] = {"Traditional counties of +++"},
		},

		["country/Scotland"] = {
			["itself"] = {"Traditional counties of +++"},
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
		preposition = "of",
		affix_type = "suf",
		fallback = "borough",
	},

	["county seat"] = {
		article = "the",
		preposition = "of",
		-- UNITED STATES
		cat_handler = function(holonym_placetype, holonym_placename, place_spec)
			local spec = m_shared.us_states[holonym_placename .. ", USA"]
			if spec and holonym_placetype == "state" and not spec.county_type then
				return {
					["itself"] = {"County seats of " .. holonym_placename .. ", USA"}
				}
			end
		end,
	},

	["county town"] = {
		article = "the",
		preposition = "of",
	},

	["department"] = {
		preposition = "of",
		affix_type = "suf",

		["default"] = {
			["country"] = {true},
		},
	},

	["department capital"] = {
		article = "the",
		preposition = "of",
	},

	["dependency"] = {
		preposition = "of",

		["default"] = {
			["itself"] = {true},
			["country"] = {"Dependencies of +++"},
		},
	},

	["dependent territory"] = {
		preposition = "of",

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
		preposition = "of",
		affix_type = "suf",
		cat_handler = function(holonym_placetype, holonym_placename, place_spec)
			return district_cat_handler("district", holonym_placetype, holonym_placename)
		end,

		["country/Portugal"] = {
			["itself"] = {"Districts and autonomous regions of +++"},
		},

		-- No default. Countries for which districts are political subdivisions will get entries.
	},

	["district capital"] = {
		article = "the",
		preposition = "of",
	},

	["district municipality"] = {
		preposition = "of",
		affix_type = "suf",
		no_affix_strings = {"district", "municipality"},
		fallback = "municipality",
	},

	["division"] = {
		preposition = "of",

		["default"] = {
			["country"] = {true},
		},
	},

	["federal city"] = {
		preposition = "of",

		["default"] = {
			["country"] = {true},
		},
	},

	["federal subject"] = {
		preposition = "of",

		["default"] = {
			["country"] = {true},
		},
	},

	["fictional location"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["forest"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["ghost town"] = {
		cat_handler = function(holonym_placetype, holonym_placename, place_spec)
			local function check_for_recognized(divlist, default_divtype, placename_to_key)
				local key = placename_to_key and placename_to_key(holonym_placename) or holonym_placename
				local spec = divlist[key]
				if not spec then
					key = "the " .. key
					spec = divlist[key]
				end
				if spec and holonym_placetype == (spec.divtype or default_divtype) then
					return {
						["itself"] = {"Ghost towns in " .. key}
					}
				end
			end
			return (
				check_for_recognized(m_shared.us_states, "state", function(placename) return placename .. ", USA" end) or
				check_for_recognized(m_shared.canadian_provinces_and_territories, "province") or
				check_for_recognized(m_shared.australian_states_and_territories, "state")
			)
		end,

		["default"] = {
			["itself"] = {true},
		},
	},

	["governorate"] = {
		preposition = "of",
	},

	["gulf"] = {
		preposition = "of",
		holonym_article = "the",

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

	["historical county"] = {
		preposition = "of",

		["country/Northern Ireland"] = {
			["itself"] = {"Traditional counties of +++"},
		},

		["country/Scotland"] = {
			["itself"] = {"Traditional counties of +++"},
		},

		["default"] = {
			["itself"] = {"Historical political subdivisions"},
		},
	},

	["historical polity"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["historical political subdivision"] = {
		preposition = "of",

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
		plural = "kibbutzim",

		["default"] = {
			["itself"] = {true},
		},
	},

	["krai"] = {
		preposition = "of",
		affix_type = "Suf",

		["default"] = {
			["country"] = {true},
		},
	},

	["lake"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["local government district"] = {
		preposition = "of",
		affix_type = "suf",
		affix = "district",
		cat_handler = function(holonym_placetype, holonym_placename, place_spec)
			if holonym_placetype == "county" then
				local cat_form = holonym_placename .. ", England"
				if not m_shared.english_counties[cat_form] then
					cat_form = "the " .. cat_form
					if not m_shared.english_counties[cat_form] then
						cat_form = nil
					end
				end
				if cat_form then
					return {
						["itself"] = {"Districts of " .. cat_form, "Districts of England"}
					}
				end
			end
			if (holonym_placetype == "country" or holonym_placetype == "constituent country") and
				holonym_placename == "England" then
					return {
						["itself"] = {"Districts of +++"},
					}
			end
		end,
	},

	["London borough"] = {
		preposition = "of",
		affix_type = "suf",
		affix = "borough",
		fallback = "local government district",
	},

	["macroregion"] = {
		preposition = "of",

		["country/Brazil"] = {
			["country"] = {"Regions of +++"},
		},
	},

	["marginal sea"] = {
		preposition = "of",

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
	},

	["metropolitan borough"] = {
		preposition = "of",
		affix_type = "Pref",
		no_affix_strings = {"borough", "city"},
		fallback = "local government district",
	},

	["moor"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["mountain"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["mountain pass"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["municipal district"] = {
		preposition = "of",
		affix_type = "Pref",
		no_affix_strings = "district",
		fallback = "municipality",

		["province/Alberta"] = {
			["itself"] = {"Municipal districts of +++"},
		},
	},

	["municipality"] = {
		preposition = "of",

		["country/Austria"] = {
			["state"] = {true, "Municipalities of Austria"},
			["country"] = {true},
		},

		["country/Brazil"] = {
			["state"] = {"Municipalities of +++, Brazil", "Municipalities of Brazil"},
			["country"] = {true},
		},

		["country/Finland"] = {
			["region"] = {"Municipalities of +++, Finland", "Municipalities of Finland"},
			["country"] = {true},
		},

		["country/Philippines"] = {
			["province"] = {"Municipalities of +++, Philippines", "Municipalities of the Philippines"},
			["country"] = {true},
		},

		["default"] = {
			["country"] = {true},
		},
	},

	["mythological location"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["neighborhood"] = {
		preposition = "of",
		cat_handler = function(holonym_placetype, holonym_placename, place_spec)
			return city_type_cat_handler("neighborhood", holonym_placetype, holonym_placename,
				"ignore nocities", "no containing polity")
		end,
	},

	["oblast"] = {
		preposition = "of",
		affix_type = "Suf",
	},

	["ocean"] = {
		holonym_article = "the",

		["default"] = {
			["itself"] = {true},
		},
	},

	["okrug"] = {
		preposition = "of",
		affix_type = "Suf",
	},

	["parish"] = {
		preposition = "of",
		affix_type = "suf",

		["state/Louisiana"] = {
			["itself"] = {"Parishes of +++, USA"},
		},

	},

	["parish municipality"] = {
		preposition = "of",
		fallback = "municipality",

		["province/Quebec"] = {
			["itself"] = {"Parishes of +++", "Municipalities of Canada"},
		},
	},

	["parish seat"] = {
		article = "the",
		preposition = "of",

		["state/Louisiana"] = {
			["itself"] = {"Parish seats of +++, USA"},
		},

	},

	["park"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["peninsula"] = {
		holonym_article = "the",
		affix_type = "suf",
		["default"] = {
			["itself"] = {true},
		},
	},

	["periphery"] = {
		preposition = "of",

		["country/Greece"] = {
			["itself"] = {"Regions of +++"},
		},
	},

	["planned community"] = {
		-- Include this empty so we don't categorize 'planned community' into
		-- villages, as 'community' does.
	},

	["polity"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["prefecture"] = {
		preposition = "of",
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
		preposition = "of",

		["default"] = {
			["itself"] = {true},
			["country"] = {true},
		},
	},

	["provincial capital"] = {
		article = "the",
		preposition = "of",

		cat_handler = function(holonym_placetype, holonym_placename, place_spec)
			if holonym_placetype == "province" then
				return city_type_cat_handler("city", holonym_placetype, holonym_placename)
			end
		end,

		["default"] = {
			["country"] = {"Cities in +++"},
		},
	},

	["regency"] = {
		preposition = "of",

		["default"] = {
			["country"] = {true},
		},
	},

	["region"] = {
		preposition = "of",

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
	},

	["regional district"] = {
		preposition = "of",
		affix_type = "Pref",
		no_affix_strings = "district",
		fallback = "district",

		["province/British Columbia"] = {
			["itself"] = {"Regional districts of +++"},
		},
	},

	["regional capital"] = {
		article = "the",
		preposition = "of",
	},

	["regional county municipality"] = {
		preposition = "of",
		affix_type = "Suf",
		no_affix_strings = {"municipality", "county"},
		fallback = "municipality",

		["province/Quebec"] = {
			["itself"] = {"Regional county municipalities of +++"},
		},
	},

	["regional municipality"] = {
		preposition = "of",
		affix_type = "Pref",
		no_affix_strings = "municipality",
		fallback = "municipality",

		["province/British Columbia"] = {
			["itself"] = {"Regional municipalities of +++"},
		},
		["province/Nova Scotia"] = {
			["itself"] = {"Regional municipalities of +++"},
		},
		["province/Ontario"] = {
			["itself"] = {"Regional municipalities of +++"},
		},
	},

	["regional unit"] = {
		preposition = "of",
	},

	["republic"] = {
		preposition = "of",

		["default"] = {
			["country"] = {true},
		},
	},

	["river"] = {
		holonym_article = "the",
		cat_handler = function(holonym_placetype, holonym_placename, place_spec)
			return city_type_cat_handler("river", holonym_placetype, holonym_placename)
		end,

		["default"] = {
			["itself"] = {true},
			["continent"] = {true},
		},
	},

	["rural municipality"] = {
		preposition = "of",
		affix_type = "Pref",
		no_affix_strings = "municipality",
		fallback = "municipality",

		["province/Saskatchewan"] = {
			["itself"] = {true, "Rural municipalities of +++", "Municipalities of Canada"},
		},

		["province/Manitoba"] = {
			["itself"] = {true, "Rural municipalities of +++", "Municipalities of Canada"},
		},

		["province/Prince Edward Island"] = {
			["itself"] = {true, "Rural municipalities of +++", "Municipalities of Canada"},
		},
	},

	["satrapy"] = {
		preposition = "of",
	},

	["sea"] = {
		holonym_article = "the",

		["default"] = {
			["itself"] = {true},
		},
	},

	["special administrative region"] = {
		preposition = "of",

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
		preposition = "of",

		["default"] = {
			["country"] = {true},
		},
	},

	["state capital"] = {
		article = "the",
		preposition = "of",

		cat_handler = function(holonym_placetype, holonym_placename, place_spec)
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
	},

	["strait"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["subdistrict"] = {
		preposition = "of",

		["country/Indonesia"] = {
			["municipality"] = {true},
		},

		["default"] = {
			["itself"] = {true},
		},
	},

	["subdivision"] = {
		preposition = "of",
		affix_type = "suf",
		cat_handler = function(holonym_placetype, holonym_placename, place_spec)
			return district_cat_handler("subdivision", holonym_placetype, holonym_placename)
		end,
	},

	["subprefecture"] = {
		preposition = "of",
	},

	["subprovince"] = {
		preposition = "of",
	},

	["subprovincial city"] = {
		-- CHINA
		cat_handler = chinese_subcity_cat_handler,

		["default"] = {
			["country"] = {"Cities in +++"},
		},
	},

	["subregion"] = {
		preposition = "of",
	},

	["suburb"] = {
		preposition = "of",
		cat_handler = function(holonym_placetype, holonym_placename, place_spec)
			return city_type_cat_handler("suburb", holonym_placetype, holonym_placename,
				"ignore nocities", "no containing polity")
		end,
	},

	["tehsil"] = {
		affix_type = "suf",
		no_affix_strings = {"tehsil", "tahsil"},
	},

	["territory"] = {
		preposition = "of",

		["default"] = {
			["itself"] = {"Polities"},
			["country"] = {true},
		},
	},

	["town"] = {
		cat_handler = function(holonym_placetype, holonym_placename, place_spec)
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

	["township municipality"] = {
		preposition = "of",
		fallback = "municipality",

		["province/Quebec"] = {
			["itself"] = {"Townships in +++", "Townships in Canada", "Municipalities of Canada"},
		},
	},

	["traditional region"] = {
		["default"] = {
			["itself"] = {"Historical and traditional regions"},
		},
	},

	["tributary"] = {
		preposition = "of",
		cat_handler = function(holonym_placetype, holonym_placename, place_spec)
			return city_type_cat_handler("river", holonym_placetype, holonym_placename)
		end,

		["default"] = {
			["itself"] = {"Rivers"},
			["continent"] = {"Rivers in +++"},
		},
	},

	["unincorporated community"] = {
		cat_handler = function(holonym_placetype, holonym_placename, place_spec)
			if holonym_placetype == "state" then
				return city_type_cat_handler("unincorporated community", holonym_placetype, holonym_placename)
			end
		end,

		["country/United States"] = {
			["itself"] = {true},
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
		cat_handler = function(holonym_placetype, holonym_placename, place_spec)
			return city_type_cat_handler("village", holonym_placetype, holonym_placename)
		end,

		["default"] = {
			["itself"] = {true},
			["country"] = {true},
		},
	},

	["village municipality"] = {
		preposition = "of",

		["province/Quebec"] = {
			["itself"] = {"Villages in +++", "Villages in Canada", "Municipalities of Canada"},
		},
	},

	["voivodeship"] = {
		preposition = "of",
		holonym_article = "the",
	},

	["*"] = {
		cat_handler = generic_cat_handler,
	},
}


-- Now augment the category data with political subdivisions extracted from the
-- shared data. We don't need to do this if there's already an entry under "default"
-- for the divtype of the containing polity.
for _, group in ipairs(m_shared.polities) do
	for key, value in pairs(group.data) do
		value = group.value_transformer(group, key, value)
		if value.poldiv or value.miscdiv then
			local bare_key, linked_key = m_shared.construct_bare_and_linked_version(key)
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
						if type(div) == "string" then
							div = {div}
						end
						local sgdiv = m_strutils.singularize(div[1])
						for _, dt in ipairs(divtype) do
							if not export.cat_data[sgdiv] then
								-- If there is an entry in placetype_equivs[], it will be ignored once
								-- we insert an entry in cat_data. For example, "traditional county" is
								-- listed as a miscdiv of Scotland and Northern Ireland but it's also
								-- an entry in placetype_equivs[]. Once we insert an entry here for
								-- "traditional county", it will override placetype_equivs[]. To get
								-- around that, simulate the effect of placetype_equivs[] using a
								-- fallback = "..." entry.
								if export.placetype_equivs[sgdiv] then
									export.cat_data[sgdiv] = {
										preposition = "of",
										fallback = export.placetype_equivs[sgdiv],
									}
								else
									export.cat_data[sgdiv] = {
										preposition = "of",

										["default"] = {
										},
									}
								end
							end
							if not export.cat_data[sgdiv]["default"] or not export.cat_data[sgdiv]["default"][dt] then
								local itself_dest = bare_key == key and {true} or {ucfirst(div[1]) .. " of " .. key}
								if sgdiv == "district" then
									-- see comment above under district_cat_handler().
									local neighborhoods_in = value.british_spelling and "Neighbourhoods in " .. key or "Neighborhoods in " .. key
									local inner_data = district_inner_data({neighborhoods_in}, itself_dest)
									export.cat_data[sgdiv][dt .. "/" .. bare_key] = inner_data
								else
									export.cat_data[sgdiv][dt .. "/" .. bare_key] = {
										["itself"] = itself_dest,
									}
								end
							end
						end
					end
				end
			end
		end
	end
end


return export
