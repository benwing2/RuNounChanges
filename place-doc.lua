local export = {}

local data = require("Module:place/data")
local m_shared = require("Module:place/shared-data")

function export.placetype_table()
	-- We combine all placetype data into objects of the following form:
	-- {aliases={ALIASES}, categorizes=true, equiv=PLACETYPE_EQUIVALENT,
	--  display=DISPLAY_FORM, article=ARTICLE, preposition=FOLLOWING_PREPOSITION}
	local alldata = {}

	local function ensure_key(key)
		if not alldata[key] then
			alldata[key] = {}
		end
	end

	-- Does it categorize? Yes if there is a key other than "article", "preposition", "synergy"
	-- or "default", or if there is a non-empty "default" key.
	for key, value in pairs(data.cat_data) do
		ensure_key(key)
		for k, v in pairs(value) do
			if k ~= "article" and k ~= "preposition" and k ~= "synergy" and k ~= "default" or
				k == "default" and next(v) then
				alldata[key].categorizes = true
				break
			end
		end
		alldata[key].article = value.article
		alldata[key].preposition = value.preposition
	end

	-- Handle equivalents
	for key, value in pairs(data.placetype_equivs) do
		ensure_key(key)
		alldata[key].equiv = value
		if alldata[value] and alldata[value].categorizes then
			alldata[key].categorizes = true
		end
		if alldata[value] and alldata[value].article then
			alldata[key].article = alldata[value].article
		end
		if alldata[value] and alldata[value].preposition then
			alldata[key].preposition = alldata[value].preposition
		end
	end

	-- Handle aliases
	for key, value in pairs(data.placetype_aliases) do
		ensure_key(value)
		if not alldata[value].aliases then
			alldata[value].aliases = {key}
		else
			table.insert(alldata[value].aliases, key)
		end
	end

	-- Handle display forms
	for key, value in pairs(data.placetype_links) do
		ensure_key(key)
		if value == true then
			alldata[key].display = "[[" .. key .. "]]"
		elseif value == "w" then
			alldata[key].display = "[[w:" .. key .. "|" .. key .. "]]"
		else
			alldata[key].display = value
		end
	end

	-- Convert to list and sort
	local alldata_list = {}
	for key, value in pairs(alldata) do
		table.insert(alldata_list, {key, value})
		if value.aliases then
			table.sort(value.aliases)
		end
	end
	table.sort(alldata_list, function(fs1, fs2) return fs1[1] < fs2[1] end)

	-- Convert to wikitable
	local parts = {}
	table.insert(parts, '{|class="wikitable"')
	table.insert(parts, "! Placetype !! Article !! Display form !! Following preposition !! Aliases !! Equivalent for categorization !! Categorizes?")
	for _, placetype_data in ipairs(alldata_list) do
		local placetype = placetype_data[1]
		local data = placetype_data[2]
		table.insert(parts, "|-")
		local sparts = {}
		table.insert(sparts, placetype)
		table.insert(sparts, data.article or placetype:find("^[aeiou]") and "an" or "a")
		table.insert(sparts, data.display or placetype)
		table.insert(sparts, data.preposition or "in")
		table.insert(sparts, data.aliases and table.concat(data.aliases, ", ") or "")
		table.insert(sparts, data.equiv or "")
		table.insert(sparts, data.categorizes and "yes" or "no")
		table.insert(parts, "| " .. table.concat(sparts, " || "))
	end
	table.insert(parts, "|}")
	return table.concat(parts, "\n")
end


function export.placename_table()
	-- We combine all placetype data into objects of the following form:
	-- {display=DISPLAY_AS, cat=CATEGORIZE_AS, article=ARTICLE}
	local alldata = {}

	local function ensure_key(key)
		if not alldata[key] then
			alldata[key] = {}
		end
	end

	-- Handle display aliases
	for placetype, names in pairs(data.placename_display_aliases) do
		for name, alias in pairs(names) do
			local place = placetype .. "/" .. name
			ensure_key(place)
			alldata[place].display = placetype .. "/" .. alias
		end
	end

	-- Handle category aliases
	for placetype, names in pairs(data.placename_cat_aliases) do
		for name, alias in pairs(names) do
			local place = placetype .. "/" .. name
			ensure_key(place)
			alldata[place].cat = placetype .. "/" .. alias
		end
	end

	-- Handle places with article
	for placetype, names in pairs(data.placename_article) do
		for name, alias in pairs(names) do
			local place = placetype .. "/" .. name
			ensure_key(place)
			alldata[place].article = alias
		end
	end

	-- Handle categorization for cities/etc.
	for _, group in ipairs(m_shared.places) do
		for key, value in pairs(group.data) do
			-- Use the group's value_transformer to ensure that 'nocities' and 'containing_polity'
			-- keys are present if they should be.
			value = group.value_transformer(group, key, value)
			local placename = key:gsub("^the ", "")
			placename = group.key_to_placename and group.key_to_placename(placename) or placename
			if not value.nocities then
				-- We categorize both in key, and in the larger polity that the key is part of,
				-- e.g. [[Hirakata]] goes in both "Cities in Osaka Prefecture" and
				-- "Cities in Japan".
				local divtype = value.divtype or group.default_divtype
				if type(divtype) ~= "table" then
					divtype = {divtype}
				end
				if type(placename) ~= "table" then
					placename = {placename}
				end
				for _, dt in ipairs(divtype) do
					for _, pn in ipairs(placename) do
						local place = dt .. "/" .. pn
						ensure_key(place)
						local retcats = {"Cities in " .. key}
						if value.containing_polity then
							table.insert(retcats, "Cities in " .. value.containing_polity)
						end
						alldata[place].city_cats = retcats
					end
				end
			end
		end
	end

	-- Convert to list and sort
	local alldata_list = {}
	for key, value in pairs(alldata) do
		table.insert(alldata_list, {key, value})
		if value.aliases then
			table.sort(value.aliases)
		end
	end
	table.sort(alldata_list, function(fs1, fs2) return fs1[1] < fs2[1] end)

	-- Convert to wikitable
	local parts = {}
	table.insert(parts, '{|class="wikitable"')
	table.insert(parts, "! Placename !! Article !! Display as !! Categorize as !! City categories")
	for _, placename_data in ipairs(alldata_list) do
		local placename = placename_data[1]
		local data = placename_data[2]
		table.insert(parts, "|-")
		local sparts = {}
		table.insert(sparts, placename)
		table.insert(sparts, data.article or "")
		table.insert(sparts, data.display and "'''" .. data.display .. "'''" or placename)
		table.insert(sparts, data.cat and "'''" .. data.cat .. "'''"  or placename)
		table.insert(sparts, data.city_cats and table.concat(data.city_cats, "; ") or "")
		table.insert(parts, "| " .. table.concat(sparts, " || "))
	end
	table.insert(parts, "|}")
	return table.concat(parts, "\n")
end


function export.qualifier_table()
	local alldata_list = {}

	-- Create list
	for qualifier, display in pairs(data.placetype_qualifiers) do
		table.insert(alldata_list, {qualifier, display})
	end
	table.sort(alldata_list, function(fs1, fs2) return fs1[1] < fs2[1] end)

	-- Convert to wikitable
	local parts = {}
	table.insert(parts, '{|class="wikitable"')
	table.insert(parts, "! Qualifier !! Display as")
	for _, qualifier_data in ipairs(alldata_list) do
		local qualifier = qualifier_data[1]
		local display_as = qualifier_data[2]
		table.insert(parts, "|-")
		local sparts = {}
		table.insert(sparts, qualifier)
		table.insert(sparts, display_as == true and qualifier or "'''" .. display_as .. "'''")
		table.insert(parts, "| " .. table.concat(sparts, " || "))
	end
	table.insert(parts, "|}")
	return table.concat(parts, "\n")
end


return export
