TODO:

1. 'central business district'
2. 'county town' is not necessarily a town (e.g. Chester is a city)
3. 'spa town', 'resort town' not necessarily towns
3a. 'coal town', not necessarily a town
4. If two e.g. countries are mentioned as holonyms, categories should be generated for both. Cf.
   Colorado (river), which should be a river both in the US and Mexico.
5. 'harbor city', 'harbour city'
6. 'watercourse'
7. 'township municipality' (of Quebec)
8. 'sea area'
9. 'townland'
10. split slash only once to correctly handle twp/Admaston/Bromley.
11. make sure district -> neighborhood handles municipality and lgarea correctly.
11. 'rumun' -> 'rural municipality' and should render as 'the Rural Municipality of ...'.
12. Not properly categorizing Places in the Northwest Territories? Or remove_redundant_place_cats.py not working.
13. Should add categories for 'neighborhoods of CITY' and 'suburbs of CITY'.
14. Should add 'Places in Brooklyn, Places in the Bronx', etc. Requires several changes, e.g.
    handling 'the' in city/borough names.
15. South Caucasus implies Eurasia, which implies Europe and Asia.
16. 'leper colony'
17. Make sure the following includes an article after the semicolon: ## {{place|en|town|s/Tasmania|c/Australia|;|suburb|city/Tasmania}}.
18. In {{place|en|suburb|in|lgarea/City of Joondalup|near|city/Perth|s/Western Australia}}., "in" shouldn't be necessary.
19. Similarly, "on" before islands shouldn't be necessary.
20. 'independent city'
21. 'unrecognized territory'
22. 'crossroads'
23. Fix Midway, Washington County, Oregon; revert vandalism
24. 'mining', 'farming', 'logging' as qualifiers
25. 'abandoned', 'extinct' as qualifiers that should be treated like 'former'
26. 'community' and 'unincorporated community' should categorize as neighborhood if inside a city, town, village, etc.
27. 'sound', 'mouth'
28. 'ski resort town'
29. 'statutory town'
30. 'barangay' is a type of neighborhood.
31. 'beach resort', 'ski resort', 'resort'
32. 'metarea' = 'metropolitan area'
33. 'rcomun' = 'regional county municipality' (Quebec)
34. qualifier 'declining'
35. 'adr' = administrative region
36. 'municipal seat'
37. 'cdiv' = census division
38. 'coal town'
39. 'planned community'
40. {{place|en|A <<river>> in northwestern <<p/British Columbia>> and southeast <<s/Alaska>>}}: Should put in both "Places in British Columbia" and "Places in Alaska, USA".
41. 'railroad town'
42. 'metropolitan area'
43. 'railroad junction'
44. 'volcano', 'inactive volcano', 'dormant volcano'
45. 'rmun' = 'regional municipality', output 'regional municipality' as suffix, but correctly handle 'Region of Queens Municipality'
46. 'distmun' = 'district municipality', output 'district municipality' as suffix
47. {{place|en|community|rmun/Halifax|p/Nova Scotia|c/Canada|;|suburb|city/Halifax}} should put in "Suburbs in Nova Scotia".
48. 'larea' = 'lieutenancy area', display 'lieutenancy area' as suffix
48. 'robor' = 'royal borough', display 'Royal Borough of' as prefix
49. 'gated community'


place-shared-data.lua:

local m_table = require("Module:table")

function export.get_city_containing_polities(group, key, value)
	local containing_polities = group.containing_polities
	if type(containing_polities[1]) == "string" then
		containing_polities = {containing_polities}
	elseif value[1] then
		containing_polities = m_table.shallowcopy(containing_polities)
	end
	local this_containing_polities = value
	if type(value[1]) == "string" then
		this_containing_polities = {this_containing_polities}
	end
	for n, polity in ipairs(this_containing_polities) do
		table.insert(containing_polities, n, polity)
	end
	return containing_polities
end

topic-cat-data-places.lua:

-- Generate bare labels in 'label' for all cities.
for _, group in ipairs(m_shared.cities) do
	for key, value in pairs(group.data) do
		-- The purpose of all the following code is to construct the description. It's written in
		-- a general way to allow any number of containing polities, each larger than the previous one,
		-- so that e.g. for Birmingham, the description will read "{{{langname}}} terms related to the city of
		-- [[Birmingham]], in the county of the [[West Midlands]], in the [[constituent country]] of [[England]],
		-- in the [[United Kingdom]]."
		local bare_key, linked_key = m_shared.construct_bare_and_linked_version(key)
		local descparts = {}
		table.insert(descparts, "{{{langname}}} terms related to the city of " .. linked_key)
		local city_containing_polities = m_shared.get_city_containing_polities(group, key, value)
		local label_parent -- parent of the label, from the immediate containing polity
		for n, polity in ipairs(containing_polities) do
			local bare_polity, linked_polity = m_shared.construct_bare_and_linked_version(polity[1])
			if n == 1 then
				label_parent = bare_polity
			end
			table.insert(descparts, ", in ")
			if n < #containing_polities then
				local divtype = polity.divtype or group.default_divtype
				local pl_divtype = m_strutils.pluralize(divtype)
				local pl_linked_divtype = m_shared.political_subdivisions[pl_divtype]
				if not pl_linked_divtype then
					error("When creating city description for " .. key .. ", encountered divtype '" .. divtype .. "' not in m_shared.political_subdivisions")
				end
				local linked_divtype = m_strutils.singularize(pl_linked_divtype)
				table.insert(descparts, "the " .. m_strutils.add_indefinite_article(linked_divtype) .. " of ")
			end
			table.insert(descparts, linked_polity)
		end
		table.insert(descparts, ".")
		local desc = table.concat(descparts)

		local parents = value.parents or label_parent
		if not parents then
			error("When creating city bare label for " .. key .. ", at least one containing polity must be specified or an explicit parent must be given")
		end
		if type(parent) ~= "table" then
			parent = {parent}
		end
		labels[bare_key] = {
			description = desc,
			parents = parents,
		}
	end
end



place-data.lua:

-- This is used to add pages to base holonym categories like 'en:Merseyside, England' (and 'en:England' and
-- 'en:United Kingdom') for any pages that have 'co/Merseyside' as their holonym.
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
	if holonym_placetype == "city" then
		for _, city_group in ipairs(m_shared.cities) do
			local value = city_group.data[holonym_placename]
			if value then
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
					containing_polities_match = get_equiv_placetype_prop(divtype, holonym_matches_polity)
					if containing_polities_match then
						break
					end
					containing_polities_mismatch = get_equiv_placetype_prop(divtype, function(pt) return not not place_spec[pt] end)
					if containing_polities_mismatch then
						break
					end
				end
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


place-shared-data.lua:

export.cities = {
	{
		default_divtype = "state",
		containing_polities = {"Brazil", divtype="country"},
		data = {
			-- This only lists cities, not metro areas, over 1,000,000 inhabitants.
			["São Paulo"] = {"São Paulo"},
			["Rio de Janeiro"] = {"Rio de Janeiro"},
			["Brasília"] = {"Distrito Federal"},
			["Salvador"] = {"Bahia"},
			["Fortaleza"] = {"Ceará"},
			["Belo Horizonte"] = {"Minas Gerais"},
			["Manaus"] = {"Amazonas"},
			["Curitiba"] = {"Paraná"},
			["Recife"] = {"Pernambuco"},
			["Goiânia"] = {"Goiás"},
			["Belém"] = {"Pará"},
			["Porto Alegre"] = {"Rio Grande do Sul"},
			["Guarulhos"] = {"São Paulo"},
			["Campinas"] = {"São Paulo"},
		},
	},
	{
		default_divtype = "province",
		containing_polities = {"Canada", divtype="country"},
		data = {
			["Toronto"] = {"Ontario"},
			["Montreal"] = {"Quebec"},
			["Vancouver"] = {"British Columbia"},
			["Calgary"] = {"Alberta"},
			["Edmonton"] = {"Alberta"},
			["Ottawa"] = {"Ontario"},
			["Winnipeg"] = {"Manitoba"},
			["Quebec City"] = {"Quebec"},
			["Hamilton"] = {"Ontario"},
			["Kitchener"] = {"Ontario"},
		},
	},
	{
		default_divtype = "province",
		containing_polities = {"China", divtype="country"},
		data = {
			-- This only lists the top 50. Per [[w:List of cities in China by population]], there
			-- are 102 cities over 1,000,000 inhabitants, not to mention metro areas. Our coverage
			-- of China is fairly sparse; when it increases, add to this list.
			["Shanghai"] = {},
			["Beijing"] = {},
			["Guangzhou"] = {"Guangdong"},
			["Shenzhen"] = {"Guangdong"},
			["Tianjin"] = {},
			["Wuhan"] = {"Hubei"},
			["Dongguan"] = {"Guangdong"},
			["Chengdu"] = {"Sichuan"},
			["Foshan"] = {"Guangdong"},
			["Chongqing"] = {},
			["Nanjing"] = {"Jiangsu"},
			["Shenyang"] = {"Liaoning"},
			["Hangzhou"] = {"Zhejiang"},
			["Xi'an"] = {"Shaanxi"},
			["Harbin"] = {"Heilongjiang"},
			["Suzhou"] = {"Jiangsu"},
			["Qingdao"] = {"Shandong"},
			["Dalian"] = {"Liaoning"},
			["Zhengzhou"] = {"Henan"},
			["Shantou"] = {"Guangdong"},
			["Jinan"] = {"Shandong"},
			["Changchun"] = {"Jilin"},
			["Kunming"] = {"Yunnan"},
			["Changsha"] = {"Hunan"},
			["Taiyuan"] = {"Shanxi"},
			["Xiamen"] = {"Fujian"},
			["Hefei"] = {"Anhui"},
			["Shijiazhuang"] = {"Hebei"},
			["Ürümqi"] = {"Xinjiang", divtype="autonomous region"},
			["Fuzhou"] = {"Fujian"},
			["Wuxi"] = {"Jiangsu"},
			["Zhongshan"] = {"Guangdong"},
			["Wenzhou"] = {"Zhejiang"},
			["Nanning"] = {"Guangxi", divtype="autonomous region"},
			["Nanchang"] = {"Jiangxi"},
			["Ningbo"] = {"Zhejiang"},
			["Guiyang"] = {"Guizhou"},
			["Lanzhou"] = {"Gansu"},
			["Zibo"] = {"Shandong"},
			["Changzhou"] = {"Jiangsu"},
			["Xuzhou"] = {"Jiangsu"},
			["Tangshan"] = {"Hebei"},
			["Baotou"] = {"Inner Mongolia", divtype="autonomous region"},
			["Huizhou"] = {"Guangdong"},
			["Yantai"] = {"Shandong"},
			["Shaoxing"] = {"Zhejiang"},
			["Liuzhou"] = {"Guangxi", divtype="autonomous region"},
			["Nantong"] = {"Jiangsu"},
			["Luoyang"] = {"Henan"},
			["Yangzhou"] = {"Jiangsu"},
		},
	},
	{
		default_divtype = "region",
		containing_polities = {"France", divtype="country"},
		data = {
			["Paris"] = {"Île-de-France"},
			["Lyon"] = {"Auvergne-Rhône-Alpes"},
			["Marseille"] = {"Provence-Alpes-Côte d'Azur"},
			["Toulouse"] = {"Occitanie"},
			["Lille"] = {"Hauts-de-France"},
			["Bordeaux"] = {"Nouvelle-Aquitaine"},
			["Nice"] = {"Provence-Alpes-Côte d'Azur"},
			["Nantes"] = {"Pays de la Loire"},
			["Strasbourg"] = {"Grand Est"},
			["Rennes"] = {"Brittany"},
		},
	},
	{
		default_divtype = "state",
		containing_polities = {"Germany", divtype="country"},
		data = {
			["Berlin"] = {},
			["Dortmund"] = {"North Rhine-Westphalia"},
			["Essen"] = {"North Rhine-Westphalia"},
			["Duisberg"] = {"North Rhine-Westphalia"},
			["Hamburg"] = {},
			["Munich"] = {"Bavaria"},
			["Stuttgart"] = {"Baden-Württemberg"},
			["Frankfurt"] = {"Hesse"},
			["Cologne"] = {"North Rhine-Westphalia"},
			["Düsseldorf"] = {"North Rhine-Westphalia"},
			["Dusseldorf"] = {alias_of="Düsseldorf"},
			["Nuremberg"] = {"Bavaria"},
			["Bremen"] = {},
		},
	},
	{
		default_divtype = "state",
		containing_polities = {"India", divtype="country"},
		data = {
			-- This only lists the top 20. Per [[w:List of cities in India by population]], there
			-- are 46 cities over 1,000,000 inhabitants, not to mention metro areas. Our coverage
			-- of India is fairly sparse; when it increases, add to this list.
			["Mumbai"] = {"Maharashtra"},
			["Delhi"] = {},
			["Bangalore"] = {"Karnataka"},
			["Hyderabad"] = {"Telangana"},
			["Ahmedabad"] = {"Gujarat"},
			["Chennai"] = {"Tamil Nadu"},
			["Kolkata"] = {"West Bengal"},
			["Surat"] = {"Gujarat"},
			["Pune"] = {"Maharashtra"},
			["Jaipur"] = {"Rajasthan"},
			["Lucknow"] = {"Uttar Pradesh"},
			["Kanpur"] = {"Uttar Pradesh"},
			["Nagpur"] = {"Maharashtra"},
			["Indore"] = {"Madhya Pradesh"},
			["Thane"] = {"Maharashtra"},
			["Bhopal"] = {"Madhya Pradesh"},
			["Visakhapatnam"] = {"Andhra Pradesh"},
			["Pimpri-Chinchwad"] = {"Maharashtra"},
			["Patna"] = {"Bihar"},
			["Vadodara"] = {"Gujarat"},
		},
	},
	{
		default_divtype = "prefecture",
		containing_polities = {"Japan", divtype="country"},
		data = {
			-- Population figures from [[w:List of cities in Japan]]. Metro areas from
			-- [[w:List of metropolitan areas in Japan]].
			["Tokyo"] = {}, -- no single figure given for Tokyo as a whole.
			["Yokohama"] = {"Kanagawa"}, -- 3,697,894
			["Osaka"] = {"Osaka"}, -- 2,668,586
			["Nagoya"] = {"Aichi"}, -- 2,283,289
			-- FIXME, Hokkaido is handled specially.
			["Sapporo"] = {"Hokkaidō"}, -- 1,918,096
			["Fukuoka"] = {"Fukuoka"}, -- 1,581,527
			["Kobe"] = {"Hyōgo"}, -- 1,530,847
			["Kyoto"] = {"Kyoto"}, -- 1,474,570
			["Kawasaki"] = {"Kanagawa"}, -- 1,373,630
			["Saitama"] = {"Saitama"}, -- 1,192,418
			["Hiroshima"] = {"Hiroshima"}, -- 1,163,806
			["Sendai"] = {"Miyagi"}, -- 1,029,552
			-- the remaining cities are considered "central cities" in a 1,000,000+ metro area
			-- (sometimes there is more than one central city in the area).
			["Kitakyushu"] = {"Fukuoka"}, -- 986,998
			["Chiba"] = {"Chiba"}, -- 938,695
			["Sakai"] = {"Osaka"}, -- 835,333
			["Niigata"] = {"Niigata"}, -- 813,053
			["Hamamatsu"] = {"Shizuoka"}, -- 811,431
			["Shizuoka"] = {"Shizuoka"}, -- 710,944
			["Sagamihara"] = {"Kanagawa"}, -- 706,342
			["Okayama"] = {"Okayama"}, -- 701,293
			["Kumamoto"] = {"Kumamoto"}, -- 670,348
			["Kagoshima"] = {"Kagoshima"}, -- 605,196
			-- skipped 6 cities (Funabashi, Hachiōji, Kawaguchi, Himeji, Matsuyama, Higashiōsaka)
			-- with population in the range 509k - 587k because not central cities in any
			-- 1,000,000+ metro area.
			["Utsunomiya"] = {"Tochigi"}, -- 507,833
		},
	},
	{
		default_divtype = "oblast",
		containing_polities = {"Russia", divtype="country"},
		data = {
			-- This only lists cities, not metro areas, over 1,000,000 inhabitants.
			["Moscow"] = {},
			["Saint Petersburg"] = {},
			["Novosibirsk"] = {"Novosibirsk Oblast"},
			["Yekaterinburg"] = {"Sverdlovsk Oblast"},
			["Nizhny Novgorod"] = {"Nizhny Novgorod Oblast"},
			["Kazan"] = {"the Republic of Tatarstan", divtype="republic"},
			["Chelyabinsk"] = {"Chelyabinsk Oblast"},
			["Omsk"] = {"Omsk Oblast"},
			["Samara"] = {"Samara Oblast"},
			["Ufa"] = {"the Republic of Bashkortostan", divtype="republic"},
			["Rostov-on-Don"] = {"Rostov Oblast"},
			["Krasnoyarsk"] = {"Krasnoyarsk Krai", divtype="krai"},
			["Voronezh"] = {"Voronezh Oblast"},
			["Perm"] = {"Perm Krai", divtype="krai"},
			["Volgograd"] = {"Volgograd Oblast"},
			["Krasnodar"] = {"Krasnodar Krai", divtype="krai"},
		},
	},
	{
		default_divtype = "autonomous community",
		containing_polities = {"Spain", divtype="country"},
		data = {
			["Madrid"] = {"the Community of Madrid"},
			["Barcelona"] = {"Catalonia"},
			["Valencia"] = {"Valencia"},
			["Seville"] = {"Andalusia"},
			["Bilbao"] = {"the Basque Country"},
		},
	},
	{
		default_divtype = "county",
		containing_polities = {"the United Kingdom", divtype="country"},
		data = {
			["London"] = {{"Greater London"}, {"England", divtype="constituent country"}},
			["Manchester"] = {{"Greater Manchester"}, {"England", divtype="constituent country"}},
			["Birmingham"] = {{"the West Midlands"}, {"England", divtype="constituent country"}},
			["Liverpool"] = {{"Merseyside"}, {"England", divtype="constituent country"}},
			["Glasgow"] = {{"the City of Glasgow"}, {"Scotland", divtype="constituent country"}},
			["Leeds"] = {{"West Yorkshire"}, {"England", divtype="constituent country"}},
			["Newcastle upon Tyne"] = {{"Tyne and Wear"}, {"England", divtype="constituent country"}},
			["Newcastle"] = {alias_of="Newcastle upon Tyne"},
			["Bristol"] = {{"England", divtype="constituent country"}},
			["Cardiff"] = {{"South Glamorgan"}, {"Wales", divtype="constituent country"}},
			["Portsmouth"] = {{"Hampshire"}, {"England", divtype="constituent country"}},
			["Edinburgh"] = {{"the City of Edinburgh"}, {"Scotland", divtype="constituent country"}},
		},
	},
	-- cities in the US
	{
		default_divtype = "state",
		containing_polities = {"the United States", divtype="country"},
		data = {
			-- top 50 CSA's by population, with the top and sometimes 2nd or 3rd city listed
			["New York City"] = {"New York"},
			["Newark"] = {"New Jersey"},
			["Los Angeles"] = {"California"},
			["Long Beach"] = {"California"},
			["Riverside"] = {"California"},
			["Chicago"] = {"Illinois"},
			["Washington, D.C."] = {},
			["Baltimore"] = {"Maryland"},
			["San Jose"] = {"California"},
			["San Francisco"] = {"California"},
			["Oakland"] = {"California"},
			["Boston"] = {"Massachusetts"},
			["Providence"] = {"Rhode Island"},
			["Dallas"] = {"Texas"},
			["Fort Worth"] = {"Texas"},
			["Philadelphia"] = {"Pennsylvania"},
			["Houston"] = {"Texas"},
			["Miami"] = {"Florida"},
			["Atlanta"] = {"Georgia"},
			["Detroit"] = {"Michigan"},
			["Phoenix"] = {"Arizona"},
			["Mesa"] = {"Arizona"},
			["Seattle"] = {"Washington"},
			["Orlando"] = {"Florida"},
			["Minneapolis"] = {"Minnesota"},
			["Cleveland"] = {"Ohio"},
			["Denver"] = {"Colorado"},
			["San Diego"] = {"California"},
			["Portland"] = {"Oregon"},
			["Tampa"] = {"Florida"},
			["St. Louis"] = {"Missouri"},
			["Charlotte"] = {"North Carolina"},
			["Sacramento"] = {"California"},
			["Pittsburgh"] = {"Pennsylvania"},
			["Salt Lake City"] = {"Utah"},
			["San Antonio"] = {"Texas"},
			["Columbus"] = {"Ohio"},
			["Kansas City"] = {"Missouri"},
			["Indianapolis"] = {"Indiana"},
			["Las Vegas"] = {"Nevada"},
			["Cincinnati"] = {"Ohio"},
			["Austin"] = {"Texas"},
			["Milwaukee"] = {"Wisconsin"},
			["Raleigh"] = {"North Carolina"},
			["Nashville"] = {"Tennessee"},
			["Virginia Beach"] = {"Virginia"},
			["Norfolk"] = {"Virginia"},
			["Greensboro"] = {"North Carolina"},
			["Winston-Salem"] = {"North Carolina"},
			["Jacksonville"] = {"Florida"},
			["New Orleans"] = {"Louisiana"},
			["Louisville"] = {"Kentucky"},
			["Greenville"] = {"South Carolina"},
			["Hartford"] = {"Connecticut"},
			["Oklahoma City"] = {"Oklahoma"},
			["Grand Rapids"] = {"Michigan"},
			["Memphis"] = {"Tennessee"},
			["Birmingham"] = {"Alabama"},
			["Fresno"] = {"California"},
			["Richmond"] = {"Virginia"},
			["Harrisburg"] = {"Pennsylvania"},
			-- any major city of top 50 MSA's that's missed by previous
			["Buffalo"] = {"New York"},
			-- any of the top 50 city by city population that's missed by previous
			["El Paso"] = {"Texas"},
			["Albuquerque"] = {"New Mexico"},
			["Tucson"] = {"Arizona"},
			["Colorado Springs"] = {"Colorado"},
			["Omaha"] = {"Nebraska"},
			["Tulsa"] = {"Oklahoma"},
			-- skip Arlington, Texas; too obscure and likely to be interpreted as Arlington, Virginia
		}
	},
	{
		default_divtype = "country",
		containing_polities = {},
		data = {
			["Vienna"] = {"Austria"},
			["Minsk"] = {"Belarus"},
			["Brussels"] = {"Belgium"},
			["Antwerp"] = {"Belgium"},
			["Sofia"] = {"Bulgaria"},
			["Zagreb"] = {"Croatia"},
			["Prague"] = {"the Czech Republic"},
			["Copenhagen"] = {"Denmark"},
			["Helsinki"] = {{"Uusimaa", divtype="region"}, {"Finland"}},
			["Athens"] = {"Greece"},
			["Thessaloniki"] = {"Greece"},
			["Budapest"] = {"Hungary"},
			-- FIXME, per Wikipedia "County Dublin" is now the "Dublin Region"
			["Dublin"] = {{"Dublin", divtype="county"}, {"Ireland"}},
			["Rome"] = {{"Lazio", divtype="region"}, {"Italy"}},
			["Milan"] = {{"Lombardy", divtype="region"}, {"Italy"}},
			["Naples"] = {{"Campania", divtype="region"}, {"Italy"}},
			["Turin"] = {{"Piedmont", divtype="region"}, {"Italy"}},
			["Riga"] = {"Latvia"},
			["Amsterdam"] = {"the Netherlands"},
			["Rotterdam"] = {"the Netherlands"},
			["The Hague"] = {"the Netherlands"},
			["Oslo"] = {"Norway"},
			["Warsaw"] = {"Poland"},
			["Katowice"] = {"Poland"},
			["Kraków"] = {"Poland"},
			["Krakow"] = {alias_of="Kraków"},
			["Gdańsk"] = {"Poland"},
			["Gdansk"] = {alias_of="Gdańsk"},
			["Poznań"] = {"Poland"},
			["Poznan"] = {alias_of="Poznań"},
			["Łódź"] = {"Poland"},
			["Lodz"] = {alias_of="Łódź"},
			["Lisbon"] = {"Portugal"},
			["Porto"] = {"Portugal"},
			["Bucharest"] = {"Romania"},
			["Belgrade"] = {"Serbia"},
			["Stockholm"] = {"Sweden"},
			["Zürich"] = {"Switzerland"},
			["Zurich"] = {alias_of="Zürich"},
			["Istanbul"] = {"Turkey"},
			["Kiev"] = {"Ukraine"},
			["Kharkiv"] = {"Ukraine"},
			["Odessa"] = {"Ukraine"},
		},
	},
}
