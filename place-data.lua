local export = {}

local m_shared = require("Module:place/shared-data")
local m_links = require("Module:links")
local en_utilities_module = "Module:en-utilities"

local dump = mw.dumpObject

local function ucfirst(label)
	return mw.getContentLanguage():ucfirst(label)
end

local function lc(label)
	return mw.getContentLanguage():lc(label)
end

export.force_cat = false -- set to true for testing


------------------------------------------------------------------------------------------
--                                     Basic utilities                                  --
------------------------------------------------------------------------------------------


function export.remove_links_and_html(text)
	text = m_links.remove_links(text)
	return text:gsub("<.->", "")
end


-- Return the singular version of a maybe-plural placetype, or nil if not plural.
function export.maybe_singularize(placetype)
	if not placetype then
		return nil
	end
	local retval = require(en_utilities_module).singularize(placetype)
	if retval == placetype then
		return nil
	end
	return retval
end


-- Check for special pseudo-placetypes that should be ignored for categorization purposes.
function export.placetype_is_ignorable(placetype)
	return placetype == "and" or placetype == "or" or placetype:find("^%(")
end


function export.resolve_placetype_aliases(placetype)
	return export.placetype_aliases[placetype] or placetype
end


-- Look up and resolve any category aliases that need to be applied to a holonym. For example,
-- "country/Republic of China" maps to "Taiwan" for use in categories like "Counties in Taiwan".
-- This also removes any links.
function export.resolve_cat_aliases(holonym_placetype, holonym_placename)
	local retval
	local cat_aliases = export.get_equiv_placetype_prop(holonym_placetype, function(pt) return export.placename_cat_aliases[pt] end)
	holonym_placename = export.remove_links_and_html(holonym_placename)
	if cat_aliases then
		retval = cat_aliases[holonym_placename]
	end
	return retval or holonym_placename
end


-- Given a placetype, split the placetype into one or more potential "splits", each consisting of
-- a three-element list {PREV_QUALIFIERS, THIS_QUALIFIER, BARE_PLACETYPE}, i.e.
-- (a) the concatenation of zero or more previously-recognized qualifiers on the left, normally
--     canonicalized (if there are zero such qualifiers, the value will be nil);
-- (b) a single recognized qualifier, normally canonicalized (if there is no qualifier, the value will be nil);
-- (c) the "bare placetype" on the right.
-- Splitting between the qualifier in (b) and the bare placetype in (c) happens at each space character, proceeding from
-- left to right, and stops if a qualifier isn't recognized. All placetypes are canonicalized by checking for aliases
-- in placetype_aliases[], but no other checks are made as to whether the bare placetype is recognized. Canonicalization
-- of qualifiers does not happen if NO_CANON_QUALIFIERS is specified.
--
-- For example, given the placetype "small beachside unincorporated community", the return value will be
-- {
--   {nil, nil, "small beachside unincorporated community"},
--   {nil, "small", "beachside unincorporated community"},
--   {"small", "[[beachfront]]", "unincorporated community"},
--   {"small [[beachfront]]", "[[unincorporated]]", "community"},
-- }
-- Here, "beachside" is canonicalized to "[[beachfront]]" and "unincorporated" is canonicalized
-- to "[[unincorporated]]", in both cases according to the entry in placetype_qualifiers.
--
-- On the other hand, if given "small former haunted community", the return value will be
-- {
--   {nil, nil, "small former haunted community"},
--   {nil, "small", "former haunted community"},
--   {"small", "former", "haunted community"},
-- }
-- because "small" and "former" but not "haunted" are recognized as qualifiers.
--
-- Finally, if given "former adr", the return value will be
-- {
--   {nil, nil, "former adr"},
--   {nil, "former", "administrative region"},
-- }
-- because "adr" is a recognized placetype alias for "administrative region".
function export.split_qualifiers_from_placetype(placetype, no_canon_qualifiers)
	local splits = {{nil, nil, export.resolve_placetype_aliases(placetype)}}
	local prev_qualifier = nil
	while true do
		local qualifier, bare_placetype = placetype:match("^(.-) (.*)$")
		if qualifier then
			local canon = export.placetype_qualifiers[qualifier]
			if not canon then
				break
			end
			local new_qualifier = qualifier
			if not no_canon_qualifiers and canon ~= false then
				if canon == true then
					new_qualifier = "[[" .. qualifier .. "]]"
				else
					new_qualifier = canon
				end
			end
			table.insert(splits, {prev_qualifier, new_qualifier, export.resolve_placetype_aliases(bare_placetype)})
			prev_qualifier = prev_qualifier and prev_qualifier .. " " .. new_qualifier or new_qualifier
			placetype = bare_placetype
		else
			break
		end
	end
	return splits
end


-- Given a placetype (which may be pluralized), return an ordered list of equivalent placetypes to look under to find
-- the placetype's properties (such as the category or categories to be inserted). The return value is actually an
-- ordered list of objects of the form {qualifier=QUALIFIER, placetype=EQUIV_PLACETYPE} where EQUIV_PLACETYPE is a
-- placetype whose properties to look up, derived from the passed-in placetype or from a contiguous subsequence of the
-- words in the passed-in placetype (always including the rightmost word in the placetype, i.e. we successively chop
-- off qualifier words from the left and use the remainder to find equivalent placetypes). QUALIFIER is the remaining
-- words not part of the subsequence used to find EQUIV_PLACETYPE; or nil if all words in the passed-in placetype were
-- used to find EQUIV_PLACETYPE. (FIXME: This qualifier is not currently used anywhere.) The placetype passed in always
-- forms the first entry.
function export.get_placetype_equivs(placetype)
	local equivs = {}

	-- Look up the equivalent placetype for `placetype` in `placetype_equivs`. If `placetype` is plural, also look up
	-- the equivalent for the singularized version. Return any equivalent placetype(s) found.
	local function lookup_placetype_equiv(placetype)
		local retval = {}
		-- Check for a mapping in placetype_equivs; add if present.
		if export.placetype_equivs[placetype] then
			table.insert(retval, export.placetype_equivs[placetype])
		end
		local sg_placetype = export.maybe_singularize(placetype)
		-- Check for a mapping in placetype_equivs for the singularized equivalent.
		if sg_placetype and export.placetype_equivs[sg_placetype] then
			table.insert(retval, export.placetype_equivs[sg_placetype])
		end
		return retval
	end

	-- Insert `placetype` into `equivs`, along with any equivalent placetype listed in `placetype_equivs`. `qualifier`
	-- is the preceding qualifier to insert into `equivs` along with the placetype (see comment at top of function). We
	-- also check to see if `placetype` is plural, and if so, insert the singularized version along with its equivalent
	-- (if any) in `placetype_equivs`.
	local function do_placetype(qualifier, placetype)
		-- FIXME! The qualifier (first arg) is inserted into the table, but isn't
		-- currently used anywhere.
		local function insert(pt)
			table.insert(equivs, {qualifier=qualifier, placetype=pt})
		end

		-- First do the placetype itself.
		insert(placetype)
		-- Then check for a singularized equivalent.
		local sg_placetype = export.maybe_singularize(placetype)
		if sg_placetype then
			insert(sg_placetype)
		end
		-- Then check for a mapping in placetype_equivs, and a mapping for the singularized equivalent; add if present.
		local placetype_equiv_list = lookup_placetype_equiv(placetype)
		for _, placetype_equiv in ipairs(placetype_equiv_list) do
			insert(placetype_equiv)
		end
	end

	-- Successively split off recognized qualifiers and loop over successively greater sets of qualifiers from the left.
	local splits = export.split_qualifiers_from_placetype(placetype)

	for _, split in ipairs(splits) do
		local prev_qualifier, this_qualifier, bare_placetype = unpack(split, 1, 3)
		if this_qualifier then
			-- First see if the rightmost split-off qualifier is in qualifier_equivs (e.g. 'former' -> 'historical').
			-- If so, create a placetype from the qualifier mapping + the following bare_placetype; then, add
			-- that placetype, and any mapping for the placetype in placetype_equivs.
			local equiv_qualifier = export.qualifier_equivs[this_qualifier]
			if equiv_qualifier then
				do_placetype(prev_qualifier, equiv_qualifier .. " " .. bare_placetype)
			end
			-- Also see if the remaining placetype to the right of the rightmost split-off qualifier has a placetype
			-- equiv, and if so, create placetypes from the qualifier + placetype equiv and qualifier equiv + placetype
			-- equiv, inserting them along with any equivalents. This way, if we are given the placetype "former
			-- alliance", and we have a mapping 'former' -> 'historical' in qualifier_equivs and a mapping 'alliance'
			-- -> 'confederation' in placetype_equivs, we check for placetypes 'former confederation' and (most
			-- importantly) 'historical confederation' and their equivalents (if any) in placetype_equivs. This allows
			-- the user to specify placetypes using any combination of "former/ancient/historical/etc." and
			-- "league/alliance/confederacy/confederation" and it will correctly map to the placetype 'historical
			-- confederation' and in turn to the category [[:Category:LANG:Historical polities]]. Similarly, any
			-- combination of "former/ancient/historical/etc." and "protectorate/autonomous territory/dependent
			-- territory" will correctly map to placetype 'historical dependent territory' and in turn to the category
			-- [[:Category:LANG:Historical political subdivisions]].
			local bare_placetype_equiv_list = lookup_placetype_equiv(bare_placetype)
			for _, bare_placetype_equiv in ipairs(bare_placetype_equiv_list) do
				do_placetype(prev_qualifier, this_qualifier .. " " .. bare_placetype_equiv)
				if equiv_qualifier then
					do_placetype(prev_qualifier, equiv_qualifier .. " " .. bare_placetype_equiv)
				end
			end

			-- Then see if the rightmost split-off qualifier is in qualifier_to_placetype_equivs
			-- (e.g. 'fictional *' -> 'fictional location'). If so, add the mapping.
			if export.qualifier_to_placetype_equivs[this_qualifier] then
				table.insert(equivs, {qualifier=prev_qualifier, placetype=export.qualifier_to_placetype_equivs[this_qualifier]})
			end
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


-- Given a place desc (see top of file) and a holonym object (see top of file), add a key/value into the place desc's
-- `holonyms_by_placetype` field corresponding to the placetype and placename of the holonym. For example, corresponding
-- to the holonym "c/Italy", a key "country" with the list value {"Italy"} will be added to the place desc's
-- `holonyms_by_placetype` field. If there is already a key with that place type, the new placename will be added to the
-- end of the value's list.
function export.key_holonym_into_place_desc(place_desc, holonym)
	if not holonym.placetype then
		return
	end

	local equiv_placetypes = export.get_placetype_equivs(holonym.placetype)
	local placename = holonym.placename
	for _, equiv in ipairs(equiv_placetypes) do
		local placetype = equiv.placetype
		if not place_desc.holonyms_by_placetype then
			place_desc.holonyms_by_placetype = {}
		end
		if not place_desc.holonyms_by_placetype[placetype] then
			place_desc.holonyms_by_placetype[placetype] = {placename}
		else
			table.insert(place_desc.holonyms_by_placetype[placetype], placename)
		end
	end
end



------------------------------------------------------------------------------------------
--                              Placename and placetype data                            --
------------------------------------------------------------------------------------------


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
	["adr"] = "administrative region",
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
	["ucomm"] = "unincorporated community",
	["cont"] = "continent",
	["cpar"] = "civil parish",
	["dep"] = "dependency",
	["dept"] = "department",
	["dist"] = "district",
	["distmun"] = "district municipality",
	["div"] = "division",
	["fpref"] = "French prefecture",
	["gov"] = "governorate",
	["govnat"] = "governorate",
	["ires"] = "Indian reservation",
	["isl"] = "island",
	["lbor"] = "London borough",
	["lgarea"] = "local government area",
	["lgdist"] = "local government district",
	["metbor"] = "metropolitan borough",
	["metcity"] = "metropolitan city",
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
	["plcolony"] = "Polish colony",
	["pref"] = "prefecture",
	["prefcity"] = "prefecture-level city",
	["preflcity"] = "prefecture-level city",
	["apref"] = "autonomous prefecture",
	["rep"] = "republic",
	["arep"] = "autonomous republic",
	["riv"] = "river",
	["rcomun"] = "regional county municipality",
	["rdist"] = "regional district",
	["rmun"] = "regional municipality",
	["robor"] = "royal borough",
	["romp"] = "Roman province",
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
	["wcomm"] = "Welsh community",
	["range"] = "mountain range",
	["departmental capital"] = "department capital",
	["home-rule city"] = "home rule city",
	["home-rule municipality"] = "home rule municipality",
	["sprovcity"] = "subprovincial city",
	["sub-provincial city"] = "subprovincial city",
	["sub-provincial district"] = "subprovincial district",
	["sprefcity"] = "sub-prefectural city",
	["sub-prefecture-level city"] = "sub-prefectural city",
	["nonmetropolitan county"] = "non-metropolitan county",
	["inner-city area"] = "inner city area",
}


-- These qualifiers can be prepended onto any placetype and will be handled correctly. For example, the placetype
-- "large city" will be displayed as such but otherwise treated exactly as if "city" were specified. Links will be added
-- to the remainder of the placetype as appropriate, e.g. "small voivodeship" will display as "small [[voivoideship]]"
-- because "voivoideship" has an entry in placetype_links. If the value is a string, the qualifier will display
-- according to the string. If the value is `true`, the qualifier will be linked to its corresponding Wiktionary entry.
-- If the value is `false`, the qualifier will not be linked but will appear as-is. Note that these qualifiers do not
-- override placetypes with entries elsewhere that contain those same qualifiers. For example, the entry for "former
-- colony" in placetype_equivs will apply in preference to treating "former colony" as equivalent to "colony". Also note
-- that if an entry like "former colony" appears in either placetype_equivs or cat_data, the qualifier and non-qualifier
-- portions won't automatically be linked, so it needs to be specifically included in placetype_links if linking is
-- desired.
export.placetype_qualifiers = {
	-- generic qualifiers
	["huge"] = false,
	["tiny"] = false,
	["large"] = false,
	["small"] = false,
	["sizable"] = false,
	["important"] = false,
	["long"] = false,
	["short"] = false,
	["major"] = false,
	["minor"] = false,
	["high"] = false,
	["low"] = false,
	["left"] = false, -- left tributary
	["right"] = false, -- right tributary
	["modern"] = false, -- for use in opposition to "ancient" in another definition
	-- "former" qualifiers
	-- FIXME: None of these can be set to `true` so they link, because it currently interferes with categorization.
	-- FIXME!
	["abandoned"] = false,
	["ancient"] = false,
	["deserted"] = false,
	["extinct"] = false,
	["former"] = false,
	["historic"] = "historical",
	["historical"] = false,
	["medieval"] = false,
	["mediaeval"] = false,
	["traditional"] = false,
	-- sea qualifiers
	["coastal"] = true,
	["inland"] = true, -- note, we also have an entry in placetype_links for 'inland sea' to get a link to [[inland sea]]
	["maritime"] = true,
	["overseas"] = true,
	["seaside"] = "[[coastal]]",
	["beachfront"] = true,
	["beachside"] = "[[beachfront]]",
	["riverside"] = true,
	-- lake qualifiers
	["freshwater"] = true,
	["saltwater"] = true,
	["endorheic"] = true,
	["oxbow"] = true,
	["ox-bow"] = true,
	-- land qualifiers
	["hilly"] = true,
	["chalk"] = true,
	["karst"] = true,
	["limestone"] = true,
	-- political status qualifiers
	["autonomous"] = true,
	["incorporated"] = true,
	["special"] = true,
	["unincorporated"] = true,
	-- monetary status/etc. qualifiers
	["fashionable"] = true,
	["wealthy"] = true,
	["affluent"] = true,
	["declining"] = true,
	-- city vs. rural qualifiers
	["urban"] = true,
	["suburban"] = true,
	["outlying"] = true,
	["remote"] = true,
	["rural"] = true,
	["inner"] = false,
	["outer"] = false,
	-- land use qualifiers
	["residential"] = true,
	["agricultural"] = true,
	["business"] = true,
	["commercial"] = true,
	["industrial"] = true,
	-- business use qualifiers
	["railroad"] = true,
	["railway"] = true,
	["farming"] = true,
	["fishing"] = true,
	["mining"] = true,
	["logging"] = true,
	["cattle"] = true,
	-- religious qualifiers
	["holy"] = true,
	["sacred"] = true,
	["religious"] = true,
	["secular"] = true,
	-- qualifiers for nonexistent places
	-- FIXME: Neither of these can be set to `true` so they link, because it currently interferes with categorization.
	-- FIXME!
	["fictional"] = false,
	["mythological"] = false,
	-- directional qualifiers
	["northern"] = false,
	["southern"] = false,
	["eastern"] = false,
	["western"] = false,
	["north"] = false,
	["south"] = false,
	["east"] = false,
	["west"] = false,
	["northeastern"] = false,
	["southeastern"] = false,
	["northwestern"] = false,
	["southwestern"] = false,
	["northeast"] = false,
	["southeast"] = false,
	["northwest"] = false,
	["southwest"] = false,
	-- seasonal qualifiers
	["summer"] = true, -- e.g. for 'summer capital'
	["winter"] = true,
	-- misc. qualifiers
	["planned"] = true,
	["chartered"] = true,
	["landlocked"] = true,
	["uninhabited"] = true,

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
	["alliance"] = true,
	["archipelago"] = true,
	["arm"] = true,
	["associated province"] = "[[associated]] [[province]]",
	["atoll"] = true,
	["autonomous city"] = "w",
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
	["branch"] = true,
	["burgh"] = true,
	["caliphate"] = true,
	["canton"] = true,
	["cape"] = true,
	["capital"] = true,
	["capital city"] = true,
	["caplc"] = "[[capital]] and largest city",
	["caravan city"] = true,
	["cathedral city"] = true,
	["cattle station"] = true, -- Australia
	["census area"] = true,
	["census-designated place"] = true, -- United States
	["central business district"] = true,
	["ceremonial county"] = true,
	["channel"] = true,
	["charter community"] = "w", -- Northwest Territories, Canada
	["city-state"] = true,
	["civil parish"] = true,
	["coal town"] = "w",
	["collectivity"] = true,
	["commandery"] = true,
	["commonwealth"] = true,
	["commune"] = true,
	["community"] = true,
	["community development block"] = "w", -- India
	["comune"] = true, -- Italy, Switzerland
	["confederacy"] = true,
	["confederation"] = true,
	["constituent country"] = true,
	["contregion"] = "[[continental]] region",
	["council area"] = true,
	["county-administered city"] = "w", -- Taiwan
	["county-controlled city"] = "w", -- Taiwan
	["county-level city"] = "w", -- China
	["county borough"] = true,
	["county seat"] = true,
	["county town"] = true,
	["crater lake"] = true,
	["crown dependency"] = true,
	["Crown dependency"] = true,
	["department"] = true,
	["department capital"] = "[[department]] [[capital]]",
	["dependency"] = true,
	["dependent territory"] = "w",
	["deserted mediaeval village"] = "w",
	["deserted medieval village"] = "w",
	["direct-administered municipality"] = "[[w:direct-administered municipalities of China|direct-administered municipality]]",
	["direct-controlled municipality"] = "w",
	["distributary"] = true,
	["district"] = true,
	["district capital"] = "[[district]] [[capital]]",
	["district headquarters"] = "[[district]] [[headquarters]]",
	["district municipality"] = "w",
	["division"] = true,
	["division capital"] = "[[division]] [[capital]]",
	["dome"] = true,
	["dormant volcano"] = true,
	["duchy"] = true,
	["emirate"] = true,
	["empire"] = true,
	["enclave"] = true,
	["escarpment"] = true,
	["exclave"] = true,
	["external territory"] = "[[external]] [[territory]]",
	["federal city"] = "w",
	["federal subject"] = "w",
	["federal territory"] = "w",
	["First Nations reserve"] = "[[First Nations]] [[w:Indian reserve|reserve]]", -- Canada
	["fjord"] = true,
	["former autonomous territory"] = "former [[w:autonomous territory|autonomous territory]]",
	["former colony"] = "former [[colony]]",
	["former maritime republic"] = "former [[maritime republic]]",
	["former polity"] = "former [[polity]]",
	["former separatist state"] = "former [[separatist]] [[state]]",
	["frazione"] = "w", -- Italy
	["French prefecture"] = "[[w:Prefectures in France|prefecture]]",
	["geographic area"] = "[[geographic]] [[area]]",
	["geographical area"] = "[[geographical]] [[area]]",
	["geographic region"] = "w",
	["geographical region"] = "w",
	["geopolitical zone"] = true, -- Nigeria
	["ghost town"] = true,
	["glen"] = true,
	["governorate"] = true,
	["greater administrative region"] = "w", -- China (historical)
	["gromada"] = "w", -- Poland (historical)
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
	["hot spring"] = true,
	["housing estate"] = true,
	["hromada"] = "w", -- Ukraine
	["independent city"] = true,
	["independent town"] = "[[independent city|independent town]]",
	["Indian reservation"] = "w", -- United States
	["Indian reserve"] = "w", -- Canada
	["inactive volcano"] = "[[inactive]] [[volcano]]",
	["inland sea"] = true, -- note, we also have 'inland' as a qualifier
	["inner city area"] = "[[inner city]] area",
	["island country"] = "w",
	["island municipality"] = "w",
	["islet"] = "w",
	["Israeli settlement"] = "w",
	["judicial capital"] = "w",
	["khanate"] = true,
	["kibbutz"] = true,
	["kingdom"] = true,
	["krai"] = true,
	["league"] = true,
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
	["market city"] = "[[market town|market city]]",
	["market town"] = true,
	["massif"] = true,
	["megacity"] = true,
	["metropolitan borough"] = true,
	["metropolitan city"] = true,
	["metropolitan county"] = true,
	["metro station"] = true,
	["microdistrict"] = true,
	["microstate"] = true,
	["minster town"] = "[[minster]] town", -- England
	["moor"] = true,
	["moorland"] = true,
	["mountain"] = true,
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
	["new town"] = true,
	["non-city capital"] = "[[capital]]",
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
	["peak"] = true,
	["periphery"] = true,
	["planned community"] = true,
	["plateau"] = true,
	["Polish colony"] = "[[w:Colony (Poland)|colony]]",
	["populated place"] = "[[w:populated place|locality]]",
	["port"] = true,
	["port city"] = true,
	["port town"] = "w",
	["prefecture"] = true,
	["prefecture-level city"] = "w",
	["promontory"] = true,
	["protectorate"] = true,
	["province"] = true,
	["provincial capital"] = true,
	["new area"] = "[[w:new areas|new area]]", -- China (type of economic development zone)
	["raion"] = true,
	["regency"] = true,
	["regional capital"] = "[[regional]] [[capital]]",
	["regional county municipality"] = "w",
	["regional district"] = "w",
	["regional municipality"] = "w",
	["regional unit"] = "w",
	["registration county"] = true,
	["research base"] = "[[research]] [[base]]",
	["reservoir"] = true,
	["residental area"] = "[[residential]] area",
	["resort city"] = "w",
	["resort town"] = "w",
	["Roman province"] = "w",
	["royal borough"] = "w",
	["royal burgh"] = true,
	["royal capital"] = "w",
	["rural committee"] = "w", -- Hong Kong
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
	["special municipality"] = "[[w:Special municipality (Taiwan)|special municipality]]", -- Taiwan
	["special ward"] = true,
	["spit"] = true,
	["spring"] = true,
	["state capital"] = true,
	["state-level new area"] = "w",
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
	["subprovincial district"] = "w",
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
	["volcano"] = true,
	["ward"] = true,
	["watercourse"] = true,
	["Welsh community"] = "[[w:community (Wales)|community]]",
}


-- In this table, the key qualifiers should be treated the same as the value qualifiers for
-- categorization purposes. This is overridden by cat_data, placetype_equivs and
-- qualifier_to_placetype_equivs.
export.qualifier_equivs = {
	["abandoned"] = "historical",
	["ancient"] = "historical",
	["former"] = "historical",
	["extinct"] = "historical",
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
-- NOTE: 'coal town', 'county town', 'ghost town', 'ski resort town',
-- 'spa town', etc. aren't mapped to 'town' because they aren't necessarily towns.
export.placetype_equivs = {
	["administrative capital"] = "capital city",
	["administrative center"] = "administrative centre",
	["administrative headquarters"] = "administrative centre",
	["administrative seat"] = "administrative centre",
	["alliance"] = "confederation",
	["ancient city"] = "ancient settlement",
	["ancient hamlet"] = "ancient settlement",
	["ancient town"] = "ancient settlement",
	["ancient village"] = "ancient settlement",
	["archipelago"] = "island",
	["associated province"] = "province",
	["autonomous territory"] = "dependent territory",
	["bailiwick"] = "polity",
	["barangay"] = "neighborhood", -- not completely correct, barangays are formal administrative divisions of a city
	["barrio"] = "neighborhood", -- not completely correct, in some countries barrios are formal administrative divisions of a city
	["basin"] = "lake",
	["bishopric"] = "polity",
	["built-up area"] = "area",
	["burgh"] = "borough",
	["caliphate"] = "polity",
	["cape"] = "headland",
	["capital"] = "capital city",
	["caplc"] = "capital city",
	["caravan city"] = "city", -- should be 'former city' if we distinguish that
	["cathedral city"] = "city",
	["central business district"] = "neighborhood",
	["ceremonial county"] = "county",
	["chain of islands"] = "island",
	["charter community"] = "village",
	["colony"] = "dependent territory",
	["commandery"] = "historical political subdivision",
	["commune"] = "municipality",
	["community"] = "village",
	["comune"] = "municipality",
	["confederacy"] = "confederation",
	["contregion"] = "region",
	["county-controlled city"] = "county-administered city",
	["county-level city"] = "prefecture-level city",
	["crater lake"] = "lake",
	["crown dependency"] = "dependent territory",
	["Crown dependency"] = "dependent territory",
	["department capital"] = "capital city",
	["dependency"] = "dependent territory",
	["deserted mediaeval village"] = "ancient settlement",
	["deserted medieval village"] = "ancient settlement",
	["direct-administered municipality"] = "municipality",
	["direct-controlled municipality"] = "municipality",
	["district capital"] = "capital city",
	["district headquarters"] = "administrative centre",
	["division capital"] = "capital city",
	["dome"] = "mountain",
	["dormant volcano"] = "volcano",
	["duchy"] = "polity",
	["emirate"] = "polity",
	["empire"] = "polity",
	["escarpment"] = "mountain",
	["external territory"] = "dependent territory",
	["federal territory"] = "territory",
	["First Nations reserve"] = "Indian reserve",
	["frazione"] = "village", -- should be "hamlet" but hamlet in turn redirects to village
	["geographical area"] = "geographic area",
	["geographic region"] = "geographic area",
	["geographical region"] = "geographic area",
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
	["historical administrative region"] = "historical political subdivision",
	["historical autonomous republic"] = "historical political subdivision",
	["historical borough"] = "historical political subdivision",
	["historical canton"] = "historical political subdivision",
	["historical bailiwick"] = "historical polity",
	["historical barangay"] = "historical political subdivision",
	["historical bishopric"] = "historical polity",
	["historical caliphate"] = "historical polity",
	["historical city"] = "historical settlement",
	["historical civilisation"] = "historical polity",
	["historical civilization"] = "historical polity",
	["historical civil parish"] = "historical political subdivision",
	["historical commandery"] = "historical political subdivision",
	["historical commonwealth"] = "historical polity",
	["historical commune"] = "historical political subdivision",
	["historical confederation"] = "historical polity",
	["historical council area"] = "historical political subdivision",
	["historical county"] = "historical political subdivision",
	["historical county borough"] = "historical political subdivision",
	["historical country"] = "historical polity",
	["historical department"] = "historical political subdivision",
	["historical district"] = "historical political subdivision",
	["historical division"] = "historical political subdivision",
	["historical duchy"] = "historical polity",
	["historical emirate"] = "historical polity",
	["historical empire"] = "historical polity",
	["historical governorate"] = "historical political subdivision",
	["historical hamlet"] = "historical settlement",
	["historical khanate"] = "historical polity",
	["historical kingdom"] = "historical polity",
	["historical krai"] = "historical political subdivision",
	["historical local government area"] = "historical political subdivision", 
	["historical local government district"] = "historical political subdivision",
	["historical locality"] = "historical settlement",
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
	["historical town"] = "historical settlement",
	["historical unincorporated community"] = "historical settlement",
	["historical village"] = "historical settlement",
	["historical voivodeship"] = "historical political subdivision",
	["home rule city"] = "city",
	["home rule municipality"] = "municipality",
	["hot spring"] = "spring",
	["inactive volcano"] = "volcano",
	["independent city"] = "city",
	["independent town"] = "town",
	["inland sea"] = "sea",
	["inner city area"] = "neighborhood",
	["island country"] = "country",
	["island municipality"] = "municipality",
	["islet"] = "island",
	["judicial capital"] = "capital city",
	["khanate"] = "polity",
	["kingdom"] = "polity",
	["league"] = "confederation",
	["legislative capital"] = "capital city",
	["local authority district"] = "local government district",
	["local urban district"] = "unincorporated community",
	["locality"] = "village", -- not necessarily true, but usually is the case
	["macroregion"] = "region",
	["market city"] = "city",
	["market town"] = "town",
	["massif"] = "mountain",
	["mediaeval capital"] = "ancient capital",
	["medieval capital"] = "ancient capital",
	["mediaeval city"] = "ancient settlement",
	["medieval city"] = "ancient settlement",
	["mediaeval hamlet"] = "ancient settlement",
	["medieval hamlet"] = "ancient settlement",
	["mediaeval town"] = "ancient settlement",
	["medieval town"] = "ancient settlement",
	["mediaeval village"] = "ancient settlement",
	["medieval village"] = "ancient settlement",
	["megacity"] = "city",
	["metropolitan county"] = "county",
	["microdistrict"] = "neighborhood",
	["microstate"] = "country",
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
	["overseas territory"] = "dependent territory",
	["pass"] = "mountain pass",
	["peak"] = "mountain",
	["plateau"] = "geographic area",
	["populated place"] = "village", -- not necessarily true, but usually is the case
	["port city"] = "city",
	["port town"] = "town",
	["promontory"] = "headland",
	["protectorate"] = "dependent territory",
	["provincial capital"] = "capital city",
	["regional capital"] = "capital city",
	["regional municipality"] = "municipality",
	["reservoir"] = "lake",
	["resort city"] = "city",
	["resort town"] = "town",
	["royal burgh"] = "borough",
	["royal capital"] = "capital city",
	["seat"] = "administrative centre",
	["settlement"] = "village", -- not necessarily true, but usually is the case
	["sheading"] = "district",
	["shire"] = "county",
	["shire county"] = "county",
	["shire town"] = "county seat",
	["spa city"] = "city",
    ["special municipality"] = "city",
	["spit"] = "peninsula",
	["state capital"] = "capital city",
	["state park"] = "park",
	["statutory city"] = "city",
	["statutory town"] = "town",
	["stream"] = "river",
	["strip"] = "region",
	["strip of land"] = "region",
	["submerged ghost town"] = "ghost town",
	["sub-prefectural city"] = "subprovincial city",
	["subregion"] = "region",
	["suburban area"] = "suburb",
	["subway station"] = "metro station",
	["supercontinent"] = "continent",
	["territorial authority"] = "district",
	["town with bystatus"] = "town",
	["traditional county"] = "county",
	["treaty port"] = "city", -- should be 'former city' if we distinguish that
	["underground station"] = "metro station",
	["unincorporated territory"] = "territory",
	["unrecognised country"] = "unrecognized country",
	["urban area"] = "neighborhood",
	["urban township"] = "township",
	["urban-type settlement"] = "town",
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
		["Washington D.C."] = "Washington, D.C.",
		["Washington DC"] = "Washington, D.C.",
	},
	["country"] = {
		["Republic of Armenia"] = "Armenia",
		["Bosnia and Hercegovina"] = "Bosnia and Herzegovina",
		["Czechia"] = "Czech Republic",
		["Swaziland"] = "Eswatini",
		["Republic of Ireland"] = "Ireland",
		["Côte d'Ivoire"] = "Ivory Coast",
		["Macedonia"] = "North Macedonia",
		["Republic of North Macedonia"] = "North Macedonia",
		["Republic of Macedonia"] = "North Macedonia",
        ["State of Palestine"] = "Palestine",
        ["Türkiye"] = "Turkey",
		["UAE"] = "United Arab Emirates",
		["UK"] = "United Kingdom",
		["US"] = "United States",
		["U.S."] = "United States",
		["USA"] = "United States",
		["U.S.A."] = "United States",
		["United States of America"] = "United States",
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
	["republic"] = {
		["Kabardino-Balkarian Republic"] = "Kabardino-Balkar Republic",
		["Tyva Republic"] = "Tuva Republic",
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
	["autonomous okrug"] = {
		["Nenetsia"] = "Nenets Autonomous Okrug",
		["Khantia-Mansia"] = "Khanty-Mansi Autonomous Okrug",
		["Yugra"] = "Khanty-Mansi Autonomous Okrug",
	},
	["council area"] = {
		["Glasgow"] = "City of Glasgow",
		["Edinburgh"] = "City of Edinburgh",
		["Aberdeen"] = "City of Aberdeen",
		["Dundee"] = "City of Dundee",
		["Western Isles"] = "Na h-Eileanan Siar",
	},
	["country"] = {
		-- will categorize into e.g. "Cities in Myanmar".
		["Burma"] = "Myanmar",
		["Nagorno-Karabakh"] = "Artsakh",
		["People's Republic of China"] = "China",
		["Republic of China"] = "Taiwan",
        ["State of Palestine"] = "Palestine",
		["Bosnia"] = "Bosnia and Herzegovina",
		["Congo"] = "Democratic Republic of the Congo",
		["Congo Republic"] = "Republic of the Congo",
	},
	["county"] = {
		["Anglesey"] = "Isle of Anglesey",
	},
	["province"] = {
		["Noord-Brabant"] = "North Brabant",
		["Noord-Holland"] = "North Holland",
		["Zuid-Holland"] = "South Holland",
		["Fuchien"] = "Fujian",
	},
	["republic"] = {
		-- Only needs to include cases that aren't just shortened versions of the
		-- full federal subject name (i.e. where words like "Republic" and "Oblast"
		-- are omitted but the name is not otherwise modified). Note that a couple
		-- of minor variants are recognized as display aliases, meaning that they
		-- will be canonicalized for display as well as categorization.
		["Bashkiria"] = "Republic of Bashkortostan",
		["Chechnya"] = "Chechen Republic",
		["Chuvashia"] = "Chuvash Republic",
		["Kabardino-Balkaria"] = "Kabardino-Balkar Republic",
		["Kabardino-Balkariya"] = "Kabardino-Balkar Republic",
		["Karachay-Cherkessia"] = "Karachay-Cherkess Republic",
		["North Ossetia"] = "Republic of North Ossetia-Alania",
		["Alania"] = "Republic of North Ossetia-Alania",
		["Yakutia"] = "Sakha Republic",
		["Yakutiya"] = "Sakha Republic",
		["Republic of Yakutia (Sakha)"] = "Sakha Republic",
		["Tyva"] = "Tuva Republic",
		["Udmurtia"] = "Udmurt Republic",
	},
	["state"] = {
		["Baja California Norte"] = "Baja California",
	},
}


-- This contains placenames that should be preceded by an article (almost always "the").
-- NOTE: There are multiple ways that placenames can come to be preceded by "the":
-- 1. Listed here.
-- 2. Given in [[Module:place/shared-data]] with an initial "the". All such placenames
--    are added to this map by the code just below the map.
-- 3. The placetype of the placename has holonym_article = "the" in its cat_data.
-- 4. A regex in placename_the_re matches the placename.
-- Note that "the" is added only before the first holonym in a place description.
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
		["Russian Far East"] = "the",
		["Caribbean"] = "the",
		["Caucasus"] = "the",
		["Middle East"] = "the",
		["New Territories"] = "the",
		["North Caucasus"] = "the",
		["South Caucasus"] = "the",
		["West Bank"] = "the",
		["Gaza Strip"] = "the",
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
export.general_implications = {
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
		["South Europe"] = {"continent/Europe"},
		["Southern Europe"] = {"continent/Europe"},
		["Northern Europe"] = {"continent/Europe"},
		["Southeast Europe"] = {"continent/Europe"},
		["Southeastern Europe"] = {"continent/Europe"},
		["North Caucasus"] = {"continent/Europe"},
		["South Caucasus"] = {"continent/Asia"},
		["South Asia"] = {"continent/Asia"},
		["Southern Asia"] = {"continent/Asia"},
		["East Asia"] = {"continent/Asia"},
		["Eastern Asia"] = {"continent/Asia"},
		["Central Asia"] = {"continent/Asia"},
		["West Asia"] = {"continent/Asia"},
		["Western Asia"] = {"continent/Asia"},
		["Southeast Asia"] = {"continent/Asia"},
		["North Asia"] = {"continent/Asia"},
		["Northern Asia"] = {"continent/Asia"},
		["Asia Minor"] = {"continent/Asia"},
		["North Africa"] = {"continent/Africa"},
		["Central Africa"] = {"continent/Africa"},
		["West Africa"] = {"continent/Africa"},
		["East Africa"] = {"continent/Africa"},
		["Southern Africa"] = {"continent/Africa"},
		["Central America"] = {"continent/Central America"},
		["Caribbean"] = {"continent/North America"},
		["Polynesia"] = {"continent/Oceania"},
		["Micronesia"] = {"continent/Oceania"},
		["Melanesia"] = {"continent/Oceania"},
		["Siberia"] = {"country/Russia", "continent/Asia"},
		["Russian Far East"] = {"country/Russia", "continent/Asia"},
		["South Wales"] = {"constituent country/Wales", "continent/Europe"},
		["Balkans"] = {"continent/Europe"},
		["West Bank"] = {"country/Palestine", "continent/Asia"},
		["Gaza"] = {"country/Palestine", "continent/Asia"},
		["Gaza Strip"] = {"country/Palestine", "continent/Asia"},
	}
}


-- Call the place cat handler for a given polity `group` for a holonym `placename` with possible holonym placetypes
-- `placetypes`. The purpose of this is to check if the holonym exists in the group, and if so, return two values:
-- the key as found in the polity tables (which is the form that the holonym would take in a category of the form
-- "PLACETYPES in/of HOLONYM" e.g. [[Category:Districts of the West Midlands, England]]) and the "bare key", which is
-- the same as the key except it removes any occurrence of "the" at the beginning (and hence is suitable for bare
-- categories such as [[Category:West Midlands, England]]). This is sort of a glorified placename_to_key() for
-- subpolities in the group, but also verifies the correct placetype(s).
local function call_place_cat_handler(group, placetypes, placename)
	local handler = group.place_cat_handler or m_shared.default_place_cat_handler
	return handler(group, placetypes, placename)
end


------------------------------------------------------------------------------------------
--                              Category and display handlers                           --
------------------------------------------------------------------------------------------


local function city_type_cat_handler(placetype, holonym_placetype, holonym_placename, allow_if_holonym_is_city,
		no_containing_polity, extracats)
	local plural_placetype = require(en_utilities_module).pluralize(placetype)
	if m_shared.generic_place_types[plural_placetype] then
		for _, group in ipairs(m_shared.polities) do
			-- Find the appropriate key format for the holonym (e.g. "pref/Osaka" -> "Osaka Prefecture").
			local key, _ = call_place_cat_handler(group, holonym_placetype, holonym_placename)
			if key then
				local value = group.data[key]
				if value then
					-- Use the group's value_transformer to ensure that 'is_city', 'containing_polity'
					-- and 'british_spelling' keys are present if they should be.
					value = group.value_transformer(group, key, value)
					if not value.is_former_place and (not value.is_city or allow_if_holonym_is_city) then
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


local function capital_city_cat_handler(holonym_placetype, holonym_placename, place_desc, non_city)
	-- The first time we're called we want to return something; otherwise we will be called
	-- for later-mentioned holonyms, which can result in wrongly classifying into e.g.
	-- 'National capitals'.
	if holonym_placetype then
		-- Simulate the loop in find_cat_specs() over holonyms so we get the proper
		-- 'Cities in ...' categories as well as the capital category/categories we add below.
		local inner_data
		if not non_city and place_desc.holonyms then
			for _, holonym in ipairs(place_desc.holonyms) do
				local h_placetype, h_placename = holonym.placetype, holonym.placename
				h_placename = export.resolve_cat_aliases(h_placetype, h_placename)
				inner_data = export.get_equiv_placetype_prop(h_placetype,
					function(pt) return city_type_cat_handler("city", pt, h_placename) end)
				if inner_data then
					break
				end
			end
		end
		if not inner_data then
			inner_data = {
				["itself"] = {}
			}
		end
		-- Now find the appropriate capital-type category for the placetype of the holonym,
		-- e.g. 'State capitals'. If we recognize the holonym among the known holonyms in
		-- [[Module:place/shared-data]], also add a category like 'State capitals of the United States'.
		-- Truncate e.g. 'autonomous region' to 'region', 'union territory' to 'territory' when looking
		-- up the type of capital category, if we can't find an entry for the holonym placetype itself
		-- (there's an entry for 'autonomous community').
		local capital_cat = m_shared.placetype_to_capital_cat[holonym_placetype]
		if not capital_cat then
			capital_cat = m_shared.placetype_to_capital_cat[holonym_placetype:gsub("^.* ", "")]
		end
		if capital_cat then
			capital_cat = ucfirst(capital_cat)
			local inserted_specific_variant_cat = false
			for _, group in ipairs(m_shared.polities) do
				-- Find the appropriate key format for the holonym (e.g. "pref/Osaka" -> "Osaka Prefecture").
				local key, _ = call_place_cat_handler(group, holonym_placetype, holonym_placename)
				if key then
					local value = group.data[key]
					if value then
						-- Use the group's value_transformer to ensure that 'containing_polity'
						-- is present if it should be.
						value = group.value_transformer(group, key, value)
						if value.containing_polity and not value.no_containing_polity_cat then
							table.insert(inner_data["itself"], capital_cat .. " of " .. value.containing_polity)
							inserted_specific_variant_cat = true
							break
						end
					end
				end
			end
			if not inserted_specific_variant_cat then
				table.insert(inner_data["itself"], capital_cat)
			end
		else
			-- We didn't recognize the holonym placetype; just put in 'Capital cities'.
			table.insert(inner_data["itself"], "Capital cities")
		end
		return inner_data
	end
end

-- This is used to add pages to base holonym categories like 'en:Places in Merseyside, England'
-- (and 'en:Places in England') for any pages that have 'co/Merseyside' as their holonym.
-- It also handles cities (e.g. 'en:Places in Boston', along with 'en:Places in Massachusetts, USA'
-- and 'en:Places in the United States') for any pages that have 'city/Boston' as their holonym.
local function generic_cat_handler(holonym_placetype, holonym_placename, place_desc)
	for _, group in ipairs(m_shared.polities) do
		-- Find the appropriate key format for the holonym (e.g. "pref/Osaka" -> "Osaka Prefecture").
		local key, _ = call_place_cat_handler(group, holonym_placetype, holonym_placename)
		if key then
			local value = group.data[key]
			if value then
				-- Use the group's value_transformer to ensure that 'containing_polity' and 'no_containing_polity_cat'
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
						if not place_desc.holonyms_by_placetype[placetype] then
							return false
						end
						for _, holonym in ipairs(place_desc.holonyms_by_placetype[placetype]) do
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
					containing_polities_mismatch = export.get_equiv_placetype_prop(divtype,
						function(pt) return not not place_desc.holonyms_by_placetype[pt] end)
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


-- This is used to add pages to "bare" categories like 'en:Georgia, USA' for [[Georgia]] and any foreign-language terms
-- that are translations of the state of Georgia. We look at the page title (or its overridden value in pagename=),
-- as well as the glosses in t=/t2= etc. and the modern names in modern=. We need to pay attention to the entry
-- placetypes specified so we don't overcategorize; e.g. the US state of Georgia is [[Джорджия]] in Russian but the
-- country of Georgia is [[Грузия]], and if we just looked for matching names, we'd get both Russian terms categorized
-- into both 'ru:Georgia, USA' and 'ru:Georgia'.
function export.get_bare_categories(args, place_descs)
	local bare_cats = {}

	local possible_placetypes = {}
	for _, place_desc in ipairs(place_descs) do
		for _, placetype in ipairs(place_desc.placetypes) do
			if not export.placetype_is_ignorable(placetype) then
				local equivs = export.get_placetype_equivs(placetype)
				for _, equiv in ipairs(equivs) do
					table.insert(possible_placetypes, equiv.placetype)
				end
			end
		end
	end

	local city_in_placetypes = false
	for _, placetype in ipairs(possible_placetypes) do
		-- Check to see whether any variant of 'city' is in placetypes, e.g. 'capital city', 'subprovincial city',
		-- 'metropolitan city', 'prefecture-level city', etc.
		if placetype == "city" or placetype:find(" city$") then
			city_in_placetypes = true
			break
		end
	end

	local function check_term(term)
		-- Treat Wikipedia links like local ones.
		term = term:gsub("%[%[w:", "[["):gsub("%[%[wikipedia:", "[[")
		term = export.remove_links_and_html(term)
		term = term:gsub("^the ", "")
		for _, group in ipairs(m_shared.polities) do
			-- Try to find the term among the known polities.
			local cat, bare_cat = call_place_cat_handler(group, possible_placetypes, term)
			if bare_cat then
				table.insert(bare_cats, bare_cat)
			end
		end

		if city_in_placetypes then
			for _, city_group in ipairs(m_shared.cities) do
				local value = city_group.data[term]
				if value then
					table.insert(bare_cats, value.alias_of or term)
					-- No point in looking further as we don't (currently) have categories for two distinct cities with
					-- the same name.
					break
				end
			end
		end
	end

	-- FIXME: Should we only do the following if the language is English (requires that the lang is passed in)?
	check_term(args.pagename or mw.title.getCurrentTitle().subpageText)
	for _, t in ipairs(args.t) do
		check_term(t)
	end
	for _, modern in ipairs(args.modern) do
		check_term(modern)
	end
	
	return bare_cats
end


-- This is used to augment the holonyms associated with a place description with the containing polities. For example,
-- given the following:
-- # The {{w|City of Penrith}}, {{place|en|a=a|lgarea|in|s/New South Wales}}.
-- We auto-add Australia as another holonym so that the term gets categorized into
-- [[:Category:Local government areas in Australia]].
-- To avoid over-categorizing we need to check to make sure no other countries are specified as holonyms.
function export.augment_holonyms_with_containing_polity(place_descs)
	for _, place_desc in ipairs(place_descs) do
		if place_desc.holonyms then
			local new_holonyms = {}
			for _, holonym in ipairs(place_desc.holonyms) do
				if holonym.placetype and not export.placetype_is_ignorable(holonym.placetype) then
					local possible_placetypes = {}
					local equivs = export.get_placetype_equivs(holonym.placetype)
					for _, equiv in ipairs(equivs) do
						table.insert(possible_placetypes, equiv.placetype)
					end

					for _, group in ipairs(m_shared.polities) do
						-- Try to find the term among the known polities.
						local key, _ = call_place_cat_handler(group, possible_placetypes, holonym.placename)
						if key then
							local value = group.data[key]
							if value then
								value = group.value_transformer(group, key, value)
								if not value.no_containing_polity_cat and value.containing_polity and
										value.containing_polity_type then
									local existing_polities_of_type
									local containing_type = value.containing_polity_type
									local function get_existing_polities_of_type(placetype)
										return export.get_equiv_placetype_prop(placetype,
											function(pt) return place_desc.holonyms_by_placetype[pt] end
										)
									end
									-- Usually there's a single containing type but write as if more than one can be
									-- specified (e.g. {"administrative region", "region"}).
									if type(containing_type) == "string" then
										existing_polities_of_type = get_existing_polities_of_type(containing_type)
									else
										for _, containing_pt in ipairs(containing_type) do
											existing_polities_of_type = get_existing_polities_of_type(containing_pt)
											if existing_polities_of_type then
												break
											end
										end
									end
									if existing_polities_of_type then
										-- Don't augment. Either the containing polity is already specified as a holonym,
										-- or some other polity is, which we consider a conflict.
									else
										if type(containing_type) == "table" then
											-- If the containing type is a list, use the first element as the canonical
											-- variant.
											containing_type = containing_type[1]
										end
										-- Don't side-effect holonyms while processing them.
										table.insert(new_holonyms, {placetype = containing_type,
											placename = value.containing_polity, no_display = true})
									end
								end
							end
						end
					end
				end
			end
			for _, new_holonym in ipairs(new_holonyms) do
				table.insert(place_desc.holonyms, new_holonym)
				export.key_holonym_into_place_desc(place_desc, new_holonym)
			end
		end
	end

	-- FIXME, consider doing cities as well.
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
	else
		-- See explanation for this in find_cat_specs() in [[Module:place]].
		retval["restart_ignoring_cat_handler"] = true
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
		local key, _ = call_place_cat_handler(group, holonym_placetype, holonym_placename)
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


local function china_subcity_cat_handler(holonym_placetype, holonym_placename, place_desc)
	local spec = m_shared.china_provinces_and_autonomous_regions[holonym_placename]
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

local function county_display_handler(holonym_placetype, holonym_placename)
	local unlinked_placename = m_links.remove_links(holonym_placename)
	-- Display handler for Irish counties. Irish counties are displayed as e.g. "County [[Cork]]".
	if m_shared.ireland_counties["County " .. unlinked_placename .. ", Ireland"] or
		m_shared.northern_ireland_counties["County " .. unlinked_placename .. ", Northern Ireland"] then
		return prefix_display_handler("County", holonym_placename)
	end
	-- Display handler for Taiwanese counties. Taiwanese counties are displayed as e.g. "[[Chiayi]] County".
	if m_shared.taiwan_counties[unlinked_placename .. " County, Taiwan"] then
		return suffix_display_handler("County", holonym_placename)
	end
	-- Display handler for Romanian counties. Romanian counties are displayed as e.g. "[[Cluj]] County".
	if m_shared.romania_counties[unlinked_placename .. " County, Romania"] then
		return suffix_display_handler("County", holonym_placename)
	end
	-- FIXME, we need the same for US counties but need to key off the country, not the specific county.
	-- Others are displayed as-is.
	return holonym_placename
end


-- Display handler for prefectures. Japanese prefectures are displayed as e.g. "[[Fukushima]] Prefecture".
-- Others are displayed as e.g. "[[Fthiotida]] prefecture".
local function prefecture_display_handler(holonym_placetype, holonym_placename)
	local unlinked_placename = m_links.remove_links(holonym_placename)
	local suffix = m_shared.japan_prefectures[unlinked_placename .. " Prefecture"] and "Prefecture" or "prefecture"
	return suffix_display_handler(suffix, holonym_placename)
end

-- Display handler for provinces of North and South Korea. Korean provinces are displayed as e.g.
-- "[[Gyeonggi]] Province". Others are displayed as-is.
local function province_display_handler(holonym_placetype, holonym_placename)
	local unlinked_placename = m_links.remove_links(holonym_placename)
    if m_shared.north_korea_provinces[unlinked_placename .. " Province, North Korea"] or
       m_shared.south_korea_provinces[unlinked_placename .. " Province, South Korea"] then
		return suffix_display_handler("Province", holonym_placename)
	end
	-- Display handler for Laotian provinces. Laotian provinces are displayed as e.g. "[[Vientiane]] Province". Others
	-- are displayed as-is.
	if m_shared.laos_provinces[unlinked_placename .. " Province, Laos"] then
		return suffix_display_handler("Province", holonym_placename)
	end
	-- Display handler for Thai provinces. Thai provinces are displayed as e.g. "[[Chachoengsao]] Province". Others are
	-- displayed as-is.
    if m_shared.thailand_provinces[unlinked_placename .. " Province, Thailand"] then
		return suffix_display_handler("Province", holonym_placename)
	end
	return holonym_placename
end

-- Display handler for Nigerian states. Nigerian states are display as "[[Kano]] State". Others are displayed as-is.
local function state_display_handler(holonym_placetype, holonym_placename)
	local unlinked_placename = m_links.remove_links(holonym_placename)
	if m_shared.nigeria_states[unlinked_placename .. " State, Nigeria"] then
		return suffix_display_handler("State", holonym_placename)
	end
	return holonym_placename
end

------------------------------------------------------------------------------------------
--                                  Categorization data                                 --
------------------------------------------------------------------------------------------


export.cat_data = {
	["administrative village"] = {
		preposition = "of",

		["default"] = {
			["municipality"] = {true},
		},
	},

	["administrative centre"] = {
		article = "the",
		preposition = "of",
	},

	["administrative region"] = {
		preposition = "of",
		affix = "region",
		fallback = "region",
	},

	["airport"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["ancient capital"] = {
		article = "the",
		preposition = "of",
		["default"] = {
			["itself"] = {"Ancient settlements", "Historical capitals"},
		},
	},

	["ancient settlement"] = {
		["default"] = {
			["itself"] = {"Ancient settlements"},
		},
	},

	["area"] = {
		cat_handler = function(holonym_placetype, holonym_placename, place_desc)
			return district_cat_handler("area", holonym_placetype, holonym_placename)
		end,
		fallback = "geographic area",
	},

	["arm"] = {
		preposition = "of",
	},

	["atoll"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["autonomous city"] = {
		preposition = "of",
		fallback = "city",
	},

	["autonomous community"] = {
		preposition = "of",
	},

	["autonomous oblast"] = {
		preposition = "of",
		affix_type = "Suf",
		no_affix_strings = "oblast",
	},

	["autonomous okrug"] = {
		preposition = "of",
		affix_type = "Suf",
		no_affix_strings = "okrug",
	},

	["autonomous region"] = {
		preposition = "of",
		fallback = "administrative region",
		-- "administrative region" sets an affix of "region" but we want to display as "Tibet Autonomous Region"
		-- if the user writes 'ar:Suf/Tibet'.
		affix = "autonomous region",

		["country/Portugal"] = {
			["itself"] = {"Districts and autonomous regions of +++"},
		},
	},

	["autonomous republic"] = {
		preposition = "of",
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
		cat_handler = function(holonym_placetype, holonym_placename, place_desc)
			if holonym_placetype == "county" then
				local cat_form = holonym_placename .. ", England"
				if not m_shared.england_counties[cat_form] then
					cat_form = "the " .. cat_form
					if not m_shared.england_counties[cat_form] then
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
	},

	["branch"] = {
		preposition = "of",
		fallback = "river",
	},

	["canton"] = {
		preposition = "of",
		affix_type = "suf",
	},

	["capital city"] = {
		article = "the",
		preposition = "of",
		cat_handler = capital_city_cat_handler,

		["default"] = {
			["itself"] = {true},
		},
	},

	["census area"] = {
		affix_type = "Suf",
	},

	["census-designated place"] = {
		cat_handler = function(holonym_placetype, holonym_placename, place_desc)
			if holonym_placetype == "state" then
				return city_type_cat_handler("census-designated place", holonym_placetype, holonym_placename)
			end
		end,

		["country/United States"] = {
			["itself"] = {true},
		},
	},

	["city"] = {
		cat_handler = function(holonym_placetype, holonym_placename, place_desc)
			return city_type_cat_handler("city", holonym_placetype, holonym_placename)
		end,

		["default"] = {
			["itself"] = {true},
			["country"] = {true},
		},
	},

	["city-state"] = {
		["default"] = {
			["continent"] = {"City-states", "Cities", "Countries", "Countries in +++", "National capitals"},
			["itself"] = {"City-states", "Cities", "Countries", "National capitals"},
		},
	},

	["civil parish"] = {
		preposition = "of",
		affix_type = "suf",
	},

	["collectivity"] = {
		preposition = "of",

		["default"] = {
			["itself"] = {"Polities"},
		},
	},

	["commonwealth"] = {
		preposition = "of",
	},

	["commune"] = {
		preposition = "of",
	},

	["community development block"] = {
		affix_type = "suf",
		no_affix_strings = "block",
	},

	["constituent country"] = {
		preposition = "of",
		fallback = "country",
	},

	["continent"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["council area"] = {
		preposition = "of",
		affix_type = "suf",
	},

	["country"] = {
		["default"] = {
			["continent"] = {true, "Countries"},
			["itself"] = {true},
		},
	},

	["county"] = {
		preposition = "of",
		-- UNITED STATES
		cat_handler = function(holonym_placetype, holonym_placename, place_desc)
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

		["constituent country/Northern Ireland"] = {
			["itself"] = {"Traditional counties of +++"},
		},

		["constituent country/Scotland"] = {
			["itself"] = {"Traditional counties of +++"},
		},

		["default"] = {
			["itself"] = {"Polities"},
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
		cat_handler = function(holonym_placetype, holonym_placename, place_desc)
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
		fallback = "town",
	},

	["department"] = {
		preposition = "of",
		affix_type = "suf",
		holonym_article = "the",
	},

	["dependent territory"] = {
		preposition = "of",

		["default"] = {
			["itself"] = {"Dependent territories"},
			["country"] = {"Dependent territories of +++"},
		},
	},

	["desert"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["distributary"] = {
		preposition = "of",
		fallback = "river",
	},

	["district"] = {
		preposition = "of",
		affix_type = "suf",
		cat_handler = function(holonym_placetype, holonym_placename, place_desc)
			return district_cat_handler("district", holonym_placetype, holonym_placename)
		end,

		["country/Portugal"] = {
			["itself"] = {"Districts and autonomous regions of +++"},
		},

		-- No default. Countries for which districts are political subdivisions will get entries.
	},

	["district municipality"] = {
		preposition = "of",
		affix_type = "suf",
		no_affix_strings = {"district", "municipality"},
		fallback = "municipality",
	},

	["division"] = {
		preposition = "of",
	},

	["enclave"] = {
		preposition = "of",
	},

	["exclave"] = {
		preposition = "of",
	},

	["federal city"] = {
		preposition = "of",
	},

	["federal subject"] = {
		preposition = "of",
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

	["French prefecture"] = {
		article = "the",
		preposition = "of",

		["country/France"] = {
			["itself"] = {"Prefectures of +++", "Departmental capitals"},
		},
	},

	["geographic area"] = {
		preposition = "of",
		["default"] = {
			["itself"] = {true},
			["country"] = {true},
			["constituent country"] = {true},
		},
	},

	["geopolitical zone"] = {
		-- Nigeria
		preposition = "of",
	},

	["ghost town"] = {
		cat_handler = function(holonym_placetype, holonym_placename, place_desc)
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
				check_for_recognized(m_shared.canada_provinces_and_territories, "province") or
				check_for_recognized(m_shared.australia_states_and_territories, "state")
			)
		end,

		["default"] = {
			["country"] = {true},
			["itself"] = {true},
		},
	},

	["governorate"] = {
		preposition = "of",
		affix_type = "suf",
	},

	["greater administrative region"] = {
		-- China (historical subdivision)
		preposition = "of",
	},

	["gromada"] = {
		-- Poland (historical subdivision)
		preposition = "of",
		affix_type = "Pref",
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

	["historical capital"] = {
		article = "the",
		preposition = "of",
		["default"] = {
			["itself"] = {"Historical settlements", "Historical capitals"},
		},
	},

	["historical county"] = {
		preposition = "of",

		["constituent country/Northern Ireland"] = {
			["itself"] = {"Traditional counties of +++"},
		},

		["constituent country/Scotland"] = {
			["itself"] = {"Traditional counties of +++"},
		},

		["default"] = {
			["itself"] = {"Historical political subdivisions"},
		},
	},

	["historical dependent territory"] = {
		preposition = "of",

		["default"] = {
			["itself"] = {true},
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

	["historical settlement"] = {
		["default"] = {
			["itself"] = {"Historical settlements"},
		},
	},

	["hromada"] = {
		preposition = "of",
		affix_type = "Suf",
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
	},

	["lake"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["largest city"] = {
		article = "the",
		fallback = "city",
	},

	["local government district"] = {
		preposition = "of",
		affix_type = "suf",
		affix = "district",
		cat_handler = function(holonym_placetype, holonym_placename, place_desc)
			local key, _ = call_place_cat_handler(m_shared.england_group, holonym_placetype, holonym_placename)
			if key then
				return {
					["itself"] = {"Districts of " .. key, "Districts of England"}
				}
			end
			if (holonym_placetype == "country" or holonym_placetype == "constituent country") and
				holonym_placename == "England" then
					return {
						["itself"] = {"Districts of +++"},
					}
			end
		end,
	},

	["local government district with borough status"] = {
		preposition = "of",
		affix_type = "suf",
		affix = "district",
		cat_handler = function(holonym_placetype, holonym_placename, place_desc)
			local key, _ = call_place_cat_handler(m_shared.england_group, holonym_placetype, holonym_placename)
			if key then
				return {
					["itself"] = {"Districts of " .. key, "Districts of England"}
				}
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
		affix_type = "pref",
		affix = "borough",
		fallback = "local government district",
	},

	["marginal sea"] = {
		preposition = "of",
		fallback = "sea",
	},

	["metropolitan borough"] = {
		preposition = "of",
		affix_type = "Pref",
		no_affix_strings = {"borough", "city"},
		fallback = "local government district",
	},

	["metropolitan city"] = {
		preposition = "of",
		affix_type = "Pref",
		no_affix_strings = {"metropolitan", "city"},
		fallback = "city",
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
	},

	["municipality"] = {
		preposition = "of",
	},

	["mythological location"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["neighborhood"] = {
		preposition = "of",
		cat_handler = function(holonym_placetype, holonym_placename, place_desc)
			return city_type_cat_handler("neighborhood", holonym_placetype, holonym_placename,
				"allow if holonym is city", "no containing polity")
		end,
	},

	["new area"] = {
		-- China (type of economic development zone)
		preposition = "in",
	},

	["non-city capital"] = {
		article = "the",
		preposition = "of",
		cat_handler = function(holonym_placetype, holonym_placename, place_desc)
			return capital_city_cat_handler(holonym_placetype, holonym_placename, place_desc, "non-city")
		end,

		["default"] = {
			["itself"] = {"Capital cities"},
		},
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
	},

	["park"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["peninsula"] = {
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

	["Polish colony"] = {
		affix_type = "suf",
		affix = "colony",
		fallback = "village",

		["country/Poland"] = {
			["itself"] = {"Villages in +++"},
		}
	},

	["polity"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["prefecture"] = {
		preposition = "of",
		display_handler = prefecture_display_handler,
	},

	["prefecture-level city"] = {
		-- China
		cat_handler = china_subcity_cat_handler,
		["default"] = {
			["country"] = {"Cities in +++"},
		},
	},

	["province"] = {
		preposition = "of",
		display_handler = province_display_handler,
	},

	["raion"] = {
		preposition = "of",
		affix_type = "Suf",
	},

	["range"] = {
		holonym_article = "the",
	},

	["regency"] = {
		preposition = "of",
	},

	["region"] = {
		preposition = "of",

		["default"] = {
			["continent"] = {true},
		},
		["country/Armenia"] = {
			["country"] = {true},
		},

		["country/Greece"] = {
			["country"] = {true},
		},

		["country/Portugal"] = {
			["country"] = {true},
		},
	},

	["regional district"] = {
		preposition = "of",
		affix_type = "Pref",
		no_affix_strings = "district",
		fallback = "district",
	},

	["regional county municipality"] = {
		preposition = "of",
		affix_type = "Suf",
		no_affix_strings = {"municipality", "county"},
		fallback = "municipality",
	},

	["regional municipality"] = {
		preposition = "of",
		affix_type = "Pref",
		no_affix_strings = "municipality",
		fallback = "municipality",
	},

	["regional unit"] = {
		preposition = "of",
	},

	["republic"] = {
		preposition = "of",
	},

	["river"] = {
		holonym_article = "the",
		cat_handler = function(holonym_placetype, holonym_placename, place_desc)
			return city_type_cat_handler("river", holonym_placetype, holonym_placename)
		end,

		["default"] = {
			["itself"] = {true},
			["continent"] = {true},
		},
	},

	["Roman province"] = {
		["default"] = {
			["itself"] = {"Provinces of the Roman Empire"},
		},
	},

	["royal borough"] = {
		preposition = "of",
		affix_type = "Pref",
		no_affix_strings = {"royal", "borough"},
		fallback = "local government district",
	},

	["rural committee"] = {
		affix_type = "Suf",
	},

	["rural municipality"] = {
		preposition = "of",
		affix_type = "Pref",
		no_affix_strings = "municipality",
		fallback = "municipality",
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
	},

	["spring"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["star"] = {
		["default"] = {
			["itself"] = {true},
		},
	},

	["state"] = {
		preposition = "of",
	},

	["state-level new area"] = {
		-- China
		preposition = "in",
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
		cat_handler = function(holonym_placetype, holonym_placename, place_desc)
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
		-- China
		cat_handler = china_subcity_cat_handler,

		["default"] = {
			["country"] = {"Cities in +++"},
		},
	},

	["subprovincial district"] = {
		-- China
		preposition = "of",
	},

	["suburb"] = {
		preposition = "of",
		cat_handler = function(holonym_placetype, holonym_placename, place_desc)
			return city_type_cat_handler("suburb", holonym_placetype, holonym_placename,
				"allow if holonym is city", "no containing polity")
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
		},
	},

	["town"] = {
		cat_handler = function(holonym_placetype, holonym_placename, place_desc)
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
		preposition = "of",
		["default"] = {
			["itself"] = {"Historical and traditional regions"},
		},
	},

	["tributary"] = {
		preposition = "of",
		fallback = "river",
	},

	["unincorporated community"] = {
		cat_handler = function(holonym_placetype, holonym_placename, place_desc)
			if holonym_placetype == "state" then
				return city_type_cat_handler("unincorporated community", holonym_placetype, holonym_placename)
			end
		end,

		["country/United States"] = {
			["itself"] = {true},
		},
	},

	["union territory"] = {
		preposition = "of",
		article = "a",
	},

	["unitary authority"] = {
		article = "a",
		fallback = "local government district",
	},

	["unitary district"] = {
		article = "a",
		fallback = "local government district",
	},

	["united township municipality"] = {
		article = "a",
		fallback = "township municipality",
	},

	["university"] = {
		article = "a",
		["default"] = {
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
		cat_handler = function(holonym_placetype, holonym_placename, place_desc)
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

	["volcano"] = {
		plural = "volcanoes",
		
		["default"] = {
			["itself"] = {true, "Mountains"},
		},
	},

	["Welsh community"] = {
		preposition = "of",
		affix_type = "suf",
		affix = "community",

		["constituent country/Wales"] = {
			["itself"] = {"Communities of +++"},
		},
	},

	["*"] = {
		cat_handler = generic_cat_handler,
	},
}


-- Now augment the category data with political subdivisions extracted from the shared data.
for _, group in ipairs(m_shared.polities) do
	for key, value in pairs(group.data) do
		value = group.value_transformer(group, key, value)
		local divlists = {}
		if value.poldiv then
			table.insert(divlists, value.poldiv)
		end
		if value.miscdiv then
			table.insert(divlists, value.miscdiv)
		end
		local divtype = value.divtype or group.default_divtype
		if type(divtype) ~= "table" then
			divtype = {divtype}
		end
		for _, divlist in ipairs(divlists) do
			for _, div in ipairs(divlist) do
				if type(div) == "string" then
					div = {div}
				end
				local sgdiv = require(en_utilities_module).singularize(div[1])
				for _, dt in ipairs(divtype) do
					if not export.cat_data[sgdiv] then
						-- If there is an entry in placetype_equivs[], it will be ignored once we insert an entry in
						-- cat_data. For example, "traditional county" is listed as a miscdiv of Scotland and Northern
						-- Ireland but it's also an entry in placetype_equivs[]. Once we insert an entry here for
						-- "traditional county", it will override placetype_equivs[]. To get around that, simulate the
						-- effect of placetype_equivs[] using a fallback = "..." entry.
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
					-- If there is a difference between full and elliptical placenames, make sure we recognize both
					-- forms in holonyms.
					local full_placename, elliptical_placename = m_shared.call_key_to_placename(group, key)
					local bare_full_placename, _ = m_shared.construct_bare_and_linked_version(full_placename)
					local bare_elliptical_placename, _ = m_shared.construct_bare_and_linked_version(
						elliptical_placename)
					local placenames = bare_full_placename == bare_elliptical_placename and {bare_full_placename} or
						{bare_full_placename, bare_elliptical_placename}
					for _, placename in ipairs(placenames) do
						local itself_dest = placename == key and {true} or {ucfirst(div[1]) .. " of " .. key}
						local cat_data_spec
						if sgdiv == "district" then
							-- see comment above under district_cat_handler().
							local neighborhoods_in = value.british_spelling and "Neighbourhoods in " .. key or
								"Neighborhoods in " .. key
							cat_data_spec = district_inner_data({neighborhoods_in}, itself_dest)
						else
							cat_data_spec = {
								["itself"] = itself_dest,
							}
						end
						local cat_data_holonym = dt .. "/" .. placename
						if export.cat_data[sgdiv][cat_data_holonym] then
							-- Make sure there isn't an existing setting in `cat_data` for this placetype and holonym,
							-- which we would be overwriting. This clash occurs because there's a political or misc
							-- division listed in `countries` or one of the other entries in `polities` in
							-- [[Module:place/shared-data]], and we are trying to add categorization for toponyms that
							-- are located in that political or misc division in that country/etc., but there's already
							-- an entry in `cat_data`. If this occurs, we throw an error rather than overwrite the
							-- existing entry or do nothing (either of which options may be wrong). Sometimes the
							-- existing entry is intentional as it does something special like rename the category, e.g.
							-- 'Counties and regions of England' instead of just 'Counties of England'); in that case
							-- set `no_error_on_poldiv_clash = true` in the entry in `cat_data`; see existing examples.
							if not export.cat_data[sgdiv][cat_data_holonym].no_error_on_poldiv_clash then
								error(("Would overwrite cat_data[%s][%s] with %s; if this is intentional, set `no_error_on_poldiv_clash = true` (see comment in [[Module:place/data]])"):format(
									sgdiv, cat_data_holonym, dump(cat_data_spec)))
							end
						else
							export.cat_data[sgdiv][cat_data_holonym] = cat_data_spec
						end
					end
				end
			end
		end
	end
end

return export
