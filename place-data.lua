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
	["distmun"] = "district municipality",
	["div"] = "division",
	["ires"] = "Indian reservation",
	["isl"] = "island",
	["lbor"] = "London borough",
	["lgarea"] = "local government area",
	["lgdist"] = "local government district",
	["metbor"] = "metropolitan borough",
	["mtn"] = "mountain",
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
	["runit"] = "regional unit",
	["terr"] = "territory",
	["aterr"] = "autonomous territory",
	["uterr"] = "union territory",
	["tjarea"] = "tribal jurisdictional area",
	["twp"] = "township",
	["val"] = "valley",
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
	-- generic qualifiers
	["huge"] = true,
	["important"] = true,
	["large"] = true,
	["long"] = true,
	["major"] = true,
	["minor"] = true,
	["short"] = true,
	["small"] = true,
	["tiny"] = true,
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
	-- political status qualifiers
	["autonomous"] = "[[autonomous]]",
	["incorporated"] = "[[incorporated]]",
	["special"] = "[[special]]",
	["unincorporated"] = "[[unincorporated]]",
	-- misc qualifiers
	["urban"] = true,
	["suburban"] = "[[suburban]]",
	["rural"] = true,
	["residential"] = "[[residential]]",
	["agricultural"] = "[[agricultural]]",
	["hilly"] = true,
	["business"] = true,
	["commercial"] = "[[commercial]]",
	["fashionable"] = true,
	["outlying"] = true,
	["planned"] = true,
	["fictional"] = true,
	["mythological"] = true,
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
	["district municipality"] = "w",
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
	["housing estate"] = true,
	["independent city"] = true,
	["Indian reservation"] = "w",
	["inner-city area"] = "[[inner-city]] area",
	["island country"] = "w",
	["island municipality"] = "w",
	["judicial capital"] = "w",
	["kibbutz"] = true,
	["krai"] = true,
	["legislative capital"] = "[[legislative]] [[capital]]",
	["lieutenancy area"] = "w",
	["local government area"] = "w",
	["local government district"] = "w",
	["local government district with borough status"] = "[[w:local government district|local government district]] with [[w:borough status|borough status]]",
	["locality"] = "[[w:locality (settlement)|locality]]",
	["London borough"] = "w",
	["macroregion"] = true,
	["marginal sea"] = true,
	["market town"] = true,
	["metropolitan borough"] = true,
	["metro station"] = true,
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
	["regional municipality"] = "w",
	["regional unit"] = "w",
	["registration county"] = true,
	["residental area"] = "[[residential]] area",
	["resort city"] = "w",
	["resort town"] = "w",
	["rural community"] = "w",
	["rural municipality"] = "w",
	["rural township"] = "[[w:rural township (Taiwan)|rural township]]",
	["satrapy"] = true,
	["seaport"] = true,
	["settlement"] = true,
	["shire"] = true,
	["shire town"] = true,
	["ski resort town"] = "[[ski resort]] town",
	["spa town"] = "w",
	["special administrative region"] = "w",
	["special collectivity"] = "w",
	["spit"] = true,
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
	["subway station"] = "w",
	["supercontinent"] = true,
	["township"] = true,
	-- can't use templates in this code
	["town with bystatus"] = "[[town]] with [[bystatus#Norwegian Bokmål|bystatus]]",
	["traditional county"] = true,
	["traditional region"] = "w",
	["tribal jurisdictional area"] = "w",
	["tributary"] = true,
	["underground station"] = "w",
	["unincorporated territory"] = "w",
	["unitary authority"] = true,
	["unrecognised country"] = "w",
	["unrecognized country"] = "w",
	["urban area"] = "[[urban]] area",
	["urban township"] = "w",
	["village municipality"] = "[[w:village municipality (Quebec)|village municipality]]",
	["voivodeship"] = true,
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
export.placetype_equivs = {
	["administrative center"] = "administrative centre",
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
	["commandery"] = "historical political subdivision",
	["community"] = "village",
	["constituent country"] = "country",
	["contregion"] = "region",
	["county-level city"] = "prefecture-level city",
	["crown dependency"] = "dependency",
	["distributary"] = "tributary",
	["district municipality"] = "municipality",
	["duchy"] = "polity",
	["empire"] = "polity",
	["external territory"] = "dependent territory",
	["federal territory"] = "territory",
	["geographical region"] = "region",
	["ghost town"] = "town",
	["group of islands"] = "island",
	["hamlet"] = "village",
	["harbor town"] = "town",
	["harbour town"] = "town",
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
	["inner suburb"] = "suburb",
	["island country"] = "country",
	["island municipality"] = "municipality",
	["judicial capital"] = "capital city",
	["kingdom"] = "polity",
	["legislative capital"] = "capital city",
	["locality"] = "village", -- not necessarily true
	["market town"] = "town",
	["mediaeval city"] = "ancient city",
	["medieval city"] = "ancient city",
	["mountain indigenous township"] = "township",
	["mountain range"] = "mountain",
	["mountainous region"] = "region",
	["municipality with city status"] = "municipality",
	["neighbourhood"] = "neighborhood",
	["new town"] = "town",
	["outer suburb"] = "suburb",
	["overseas collectivity"] = "collectivity",
	["overseas department"] = "department",
	["overseas territory"] = "territory",
	["populated place"] = "village", -- not necessarily true
	["port city"] = "city",
	["port town"] = "town",
	["regional municipality"] = "municipality",
	["resort city"] = "city",
	["resort town"] = "town",
	["settlement"] = "village",
	["shire"] = "county",
	["shire town"] = "county seat",
	["ski resort town"] = "town",
	["spa town"] = "town",
	["spit"] = "peninsula",
	["statutory town"] = "town",
	["submerged ghost town"] = "town",
	["suburban area"] = "suburb",
	["subway station"] = "metro station",
	["supercontinent"] = "continent",
	["underground station"] = "metro station",
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
--
-- FIXME: It's unclear if we should have such a distinction between display
-- form and category form.
export.placename_cat_aliases = {
	["council area"] = {
		["Glasgow"] = "City of Glasgow",
		["Edinburgh"] = "City of Edinburgh",
		["Aberdeen"] = "City of Aberdeen",
		["Dundee"] = "City of Dundee",
	},
	["country"] = {
		-- will categorize into e.g. "Cities in Burma".
		["Myanmar"] = "Burma",
		["Nagorno-Karabakh"] = "Artsakh",
		["People's Republic of China"] = "China",
		["Republic of China"] = "Taiwan",
	},
}


-- This contains placenames that should be preceded by an article (almost always "the").
-- NOTE: There are multiple ways that placenames can come to be preceded by "the":
-- 1. Listed here.
-- 2. Given in [[Module:place/shared-data]] with an initial "the". All such placenames
--    are added to this map by the code just below the map.
-- 3. The placetype of the placename has holonym_article="the" in its cat_data.
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
	-- because the have holonym_article="the".
	["*"] = {"^Isle of ", " Islands$", " Mountains$", " Empire$", " Country$", " Region$", "^City of "},
	["bay"] = {"^Bay of "},
	["lake"] = {"^Lake of "},
	["country"] = {"^Republic of ", " Republic$"},
	["republic"] = {"^Republic of ", " Republic$"},
	["region"] = {" [Rr]egion$"},
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


local function city_type_cat_handler(placetype, holonym_placetype, holonym_placename, ignore_nocities, no_containing_polity)
	local plural_placetype = m_strutils.pluralize(placetype)
	if m_shared.generic_place_types[plural_placetype] then
		for _, group in ipairs(m_shared.polities) do
			-- Find the appropriate key format for the holonym (e.g. "pref/Osaka" -> "Osaka Prefecture").
			local key = group.place_cat_handler(group, placetype, holonym_placetype, holonym_placename)
			if key then
				local value = group.data[key]
				if value then
					-- Use the group's value_transformer to ensure that 'nocities' and 'containing_polity'
					-- keys are present if they should be.
					value = group.value_transformer(group, key, value)
					if ignore_nocities or not value.nocities then
						-- Categorize both in key, and in the larger polity that the key is part of,
						-- e.g. [[Hirakata]] goes in both "Cities in Osaka Prefecture" and
						-- "Cities in Japan". (But don't do the latter if no_city_containing_polity is set.)
						local retcats = {ucfirst(plural_placetype) .. " in " .. key}
						if value.containing_polity and not value.no_city_containing_polity and not no_containing_polity then
							table.insert(retcats, ucfirst(plural_placetype) .. " in " .. value.containing_polity)
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


-- Inner data returned by cat handler for districts.
local function district_inner_data(value)
	return {
		["city"] = value,
		["town"] = value,
		["township"] = value,
		["municipality"] = value,
		["borough"] = value,
		["census-designated place"] = value,
		["village"] = value,
	}
end
	

-- Cat handler for districts and areas. Districts are tricky because they can
-- either be political subdivisions or city neighborhoods. We handle this as follows:
-- (1) For countries etc. where they can be political subdivisions, an entry under
-- "district" will be inserted for the country with the following:
--
-- {
--		["itself"] = "true"
--		["city"] = "Neighborhoods in Foo"
-- }
--
-- This way, a district in a city will categorize under "Neighborhoods in Foo"
-- while some other district will categorize under "Districts of Foo".
-- (2) For the remaining countries, we have a cat_handler that returns the following
-- for all known countries and primary subdivisions:
--
-- {
--		["city"] = "Neighborhoods in Foo"
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
				return district_inner_data({"Neighborhoods in " .. key})
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
	if m_shared.irish_counties["County " .. unlinked_placename .. ", Ireland"] then
		if holonym_placename:find("%[%[") then
			return "County " .. holonym_placename
		end
		return "County [[" .. holonym_placename .. "]]"
	end
	return holonym_placename
end


local function borough_display_handler(holonym_placetype, holonym_placename)
	if m_shared.new_york_boroughs[holonym_placename] then
		-- Hack: don't display "borough" after the names of NYC boroughs
		return holonym_placename
	end
	return suffix_display_handler("borough", holonym_placename)
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

	["administrative centre"] = {
		article="the",
		preposition="of",
	},

	["area"] = {
		cat_handler = function(holonym_placetype, holonym_placename)
			return district_cat_handler("area", holonym_placetype, holonym_placename)
		end,
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
	},

	["autonomous republic"] = {
		preposition="of",

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

	["borough"] = {
		preposition="of",
		display_handler = borough_display_handler,

		["state/Alaska"] = {
			-- We intentionally do not add ", USA" here because that's the way it was done before.
			["itself"] = {"Boroughs of +++"},
		},

		["country/England"] = {
			["itself"] = {"Boroughs in +++"},
		},

		["city/New York City"] = {
			["itself"] = {"Boroughs in +++"},
		},

		["state/Pennsylvania"] = {
			-- We intentionally do not add ", USA" here because that's the way it was done before.
			["itself"] = {"Boroughs in +++"},
		},

		["state/New Jersey"] = {
			-- We intentionally do not add ", USA" here because that's the way it was done before.
			["itself"] = {"Boroughs in +++"},
		},
	},

	["borough seat"] = {
		article="the",
		preposition="of",

		["state/Alaska"] = {
			-- We intentionally do not add ", USA" here because that's the way it was done before.
			["itself"] = {"Borough seats of +++"},
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
	},

	["civil parish"] = {
		preposition="of",
		display_handler = function(holonym_placetype, holonym_placename)
			return suffix_display_handler("civil parish", holonym_placename)
		end,

		["country/England"] = {
			["itself"] = {"Civil parishes of +++"},
		},
	},

	["city"] = {
		cat_handler = function(holonym_placetype, holonym_placename)
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
		preposition="of",

		["default"] = {
			["itself"] = {"Polities"},
			["country"] = {true},
		},
	},

	["colony"] = {
		preposition="of",
	},

	["commonwealth"] = {
		preposition="of",
	},

	["continent"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["council area"] = {
		preposition="of",
		display_handler = function(holonym_placetype, holonym_placename)
			return suffix_display_handler("council area", holonym_placename)
		end,

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
			local spec = m_shared.us_states[holonym_placename .. ", USA"]
			if spec and holonym_placetype == "state" and not spec.county_type then
				return {
					-- We intentionally do not add ", USA" here because that's the way it was done before.
					["itself"] = {"Counties of " .. holonym_placename}
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
		preposition="of",
		display_handler = function(holonym_placetype, holonym_placename)
			return suffix_display_handler("county borough", holonym_placename)
		end,
	},

	["county seat"] = {
		article="the",
		preposition="of",
		-- UNITED STATES
		cat_handler = function(holonym_placetype, holonym_placename)
			local spec = m_shared.us_states[holonym_placename .. ", USA"]
			if spec and holonym_placetype == "state" and not spec.county_type then
				return {
					-- We intentionally do not add ", USA" here because that's the way it was done before.
					["itself"] = {"County seats of " .. holonym_placename}
				}
			end
		end,
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
		cat_handler = function(holonym_placetype, holonym_placename)
			return district_cat_handler("district", holonym_placetype, holonym_placename)
		end,

		["country/Portugal"] = {
			["itself"] = {"Districts and autonomous regions of +++"},
		},

		-- No default. Countries for which districts are political subdivisions will get entries.
	},

	["district capital"] = {
		article="the",
		preposition="of",
	},

	["division"] = {
		preposition="of",

		["default"] = {
			["country"] = {true},
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
			["itself"] = {true},
		},
	},

	["forest"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["governorate"] = {
		preposition = "of",
	},

	["gulf"] = {
		preposition = "of",
		holonym_article="the",

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
		preposition="of",

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
		preposition="of",

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

		["country/England"] = {
			["itself"] = {"Boroughs in +++"},
		},
	},

	["macroregion"] = {
		preposition="of",

		["country/Brazil"] = {
			["country"] = {"Regions of +++"},
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
	},

	["metropolitan borough"] = {
		preposition="of",
		display_handler = function(holonym_placetype, holonym_placename)
			return prefix_display_handler("Metropolitan Borough of", holonym_placename)
		end,

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
		preposition="of",
		cat_handler = function(holonym_placetype, holonym_placename)
			return city_type_cat_handler("neighborhood", holonym_placetype, holonym_placename,
				"ignore nocities", "no containing polity")
		end,
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

		["state/Louisiana"] = {
			-- We intentionally do not add ", USA" here because that's the way it was done before.
			["itself"] = {"Parishes of +++"},
		},

	},

	["parish seat"] = {
		article="the",
		preposition="of",

		["state/Louisiana"] = {
			-- We intentionally do not add ", USA" here because that's the way it was done before.
			["itself"] = {"Parish seats of +++"},
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
	},

	["polity"] = {
		["default"] = {
			["itself"] = {true},
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
	},

	["regional capital"] = {
		article="the",
		preposition="of",
	},

	["regional unit"] = {
		preposition="of",
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
			["continent"] = {true},
		},
	},

	["rural municipality"] = {
		preposition="of",
		fallback="municipality",

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
		preposition="of",
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
	},

	["subprovince"] = {
		preposition="of",
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
	},

	["suburb"] = {
		preposition="of",
		cat_handler = function(holonym_placetype, holonym_placename)
			return city_type_cat_handler("suburb", holonym_placetype, holonym_placename,
				"ignore nocities", "no containing polity")
		end,
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

	["traditional region"] = {
		["default"] = {
			["itself"] = {"Historical and traditional regions"},
		},
	},

	["tributary"] = {
		preposition="of",
		cat_handler = function(holonym_placetype, holonym_placename)
			return city_type_cat_handler("river", holonym_placetype, holonym_placename)
		end,

		["default"] = {
			["itself"] = {"Rivers"},
			["continent"] = {"Rivers in +++"},
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

	["village municipality"] = {
		preposition="of",

		["province/Quebec"] = {
			["itself"] = {"Villages in +++", "Villages in Canada", "Municipalities of Canada"},
		},
	},

	["voivodeship"] = {
		preposition="of",
		holonym_article="the",
	},
}


-- Now augment the category data with political subdivisions extracted from the
-- shared data. We don't need to do this if there's already an entry under "default"
-- for the divtype of the containing polity.
for _, group in ipairs(m_shared.polities) do
	for key, value in pairs(group.data) do
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
						local sgdiv = m_strutils.singularize(div)
						for _, dt in ipairs(divtype) do
							if not export.cat_data[sgdiv] then
								export.cat_data[sgdiv] = {
									preposition="of",

									["default"] = {
									},
								}
							end
							if not export.cat_data[sgdiv]["default"] or not export.cat_data[sgdiv]["default"][dt] then
								local itself_dest = bare_key == key and {true} or {ucfirst(div) .. " of " .. key}
								if sgdiv == "district" then
									-- see comment above under district_cat_handler().
									local inner_data = district_inner_data({"Neighborhoods in " .. key})
									inner_data["itself"] = itself_dest
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
