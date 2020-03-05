local export = {}
--[=[
This module contains data shared between [[Module:place/data]] and [[Module:category tree/topic cat/data/Places]].
You must load this module using require(), not using mw.loadData().
]=]

local m_table = require("Module:table")

-----------------------------------------------------------------------------------
--                              Placetype Tables                                 --
-----------------------------------------------------------------------------------

-- Recognized political and misc. subdivisions. The key is the plural
-- subdivision and the value is the equivalent description, with links.
export.political_subdivisions = {
	["administrative atolls"] = "[[administrative]] [[atoll]]s",
	["areas"] = "[[area]]s",
	["arrondissements"] = "[[arrondissement]]s",
	["atolls"] = "[[atoll]]s",
	["autonomous communities"] = "[[w:autonomous communities|autonomous communities]]",
	["autonomous islands"] = "[[autonomous]] [[island]]s",
	["autonomous oblasts"] = "[[autonomous oblast]]s",
	["autonomous okrugs"] = "[[autonomous okrug]]s",
	["autonomous regions"] = "[[autonomous]] [[region]]s",
	["autonomous republics"] = "[[w:autonomous republic|autonomous republic]]s",
	["boroughs"] = "[[borough]]s",
	["borough seats"] = "[[borough seat]]s",
	["cantons"] = "[[canton]]s",
	["census divisions"] = "[[w:census division|census division]]s",
	["cercles"] = "[[cercle]]s",
	["civil parishes"] = "[[civil parish]]es",
	["collectivities"] = "[[collectivity|collectivities]]",
	["constituencies"] = "[[constituency|constituencies]]",
	["constituent countries"] = "[[constituent]] [[country|countries]]",
	["council areas"] = "[[council area]]s",
	["counties"] = "[[county|counties]]",
	["county boroughs"] = "[[county borough]]s",
	["county seats"] = "[[county seat]]s",
	["countries"] = "[[country|countries]]",
	["delegations"] = "[[delegation]]s",
	["departments"] = "[[department]]s",
	["dependencies"] = "[[dependency|dependencies]]",
	["districts"] = "[[district]]s",
	["districts and autonomous regions"] = "[[district]]s and [[autonomous region]]s",
	["divisions"] = "[[division]]s",
	["emirates"] = "[[emirate]]s",
	["entities"] = "[[entity|entities]]",
	["ethnographic regions"] = "[[ethnographic]] [[region]]s",
	["federal cities"] = "[[federal]] [[city|cities]]",
	["federal territories"] = "[[federal]] [[territory|territories]]",
	["gewogs"] = "[[gewog]]s",
	["governorates"] = "[[governorate]]s",
	["krais"] = "[[krai]]s",
	["local councils"] = "[[w:local council|local council]]s",
	["local government areas"] = "[[w:local government area|local government area]]s",
	["mukims"] = "[[mukim]]s",
	["municipal districts"] = "[[w:municipal district|municipal district]]s",
	["municipalities"] = "[[municipality|municipalities]]",
	["oblasts"] = "[[oblast]]s",
	["parishes"] = "[[parish]]es",
	["parish seats"] = "[[parish seat]]s",
	["prefectures"] = "[[prefecture]]s",
	["provinces"] = "[[province]]s",
	["quarters"] = "[[quarter]]s",
	["raions"] = "[[raion]]s",
	["regencies"] = "[[regency|regencies]]",
	["regional county municipalities"] = "[[w:regional county municipality|regional county municipalities]]",
	["regional districts"] = "[[w:regional district|regional district]]s",
	["regional municipalities"] = "[[w:regional municipality|regional municipalities]]",
	["regions"] = "[[region]]s",
	["regional units"] = "[[regional unit]]s",
	["republics"] = "[[republic]]s",
	["rural municipalities"] = "[[w:rural municipality|rural municipalities]]",
	["self-administered divisions"] = "[[w:self-administered division|self-administered division]]s",
	["self-administered zones"] = "[[w:self-administered zone|self-administered zone]]s",
	["special administrative regions"] = "[[w:Special administrative regions of China|special administrative regions]]",
	["special wards"] = "[[special ward]]s",
	["state capitals"] = "[[state capital]]s",
	["states"] = "[[state]]s",
	["subprefectures"] = "[[subprefecture]]s",
	["subregions"] = "[[subregion]]s",
	["territorial authorities"] = "[[w:territorial authority|territorial authorities]]",
	["territories"] = "[[territory|territories]]",
	["traditional counties"] = "[[w:traditional county|traditional counties]]",
	["unincorporated areas"] = "[[w:unincorporated area|unincorporated area]]s",
	["voivodeships"] = "[[voivodeship]]s",
	["zones"] = "[[zone]]s",
}

-- Place types for which categories can be constructed for all the places listed
-- below other than cities. The key should be the plural place type and the value
-- should be the description.
export.generic_place_types = {
	["cities"] = "cities",
	["ghost towns"] = "[[ghost town]]s",
	["towns"] = "towns",
	["villages"] = "villages, hamlets, and other small communities and settlements",
	["neighborhoods"] = "[[neighborhood]]s, [[district]]s and other subportions of cities",
	["neighbourhoods"] = "[[neighbourhood]]s, [[district]]s and other subportions of cities",
	["suburbs"] = "[[suburb]]s",
	["rivers"] = "rivers",
	["census-designated places"] = "[[census-designated place]]s",
	["unincorporated communities"] = "[[w:unincorporated community|unincorporated communities]]",
	["places"] = "places of all sorts",
}

-- Place types for which categories can be constructed for cities listed below.
-- The key should be the plural place type and the value should be the description.
export.generic_place_types_for_cities = {
	["neighborhoods"] = "[[neighborhood]]s, [[district]]s and other subportions of cities",
	["neighbourhoods"] = "[[neighbourhood]]s, [[district]]s and other subportions of cities",
	["suburbs"] = "[[suburb]]s",
	["places"] = "places of all sorts",
}

export.placetype_to_capital_cat = {
	["canton"] = "cantonal capitals",
	["country"] = "national capitals",
	["department"] = "departmental capitals",
	["prefecture"] = "prefectural capitals",
	["province"] = "provincial capitals",
	["region"] = "regional capitals",
	["republic"] = "republic capitals",
	["state"] = "state capitals",
}

export.capital_cat_to_placetype = {}
for placetype, capital_cat in pairs(export.placetype_to_capital_cat) do
	export.capital_cat_to_placetype[capital_cat] = placetype
end

-----------------------------------------------------------------------------------
--                              Placename Tables                                 --
-----------------------------------------------------------------------------------

--[=[

Each of the following tables specifies a group of polities with common properties (e.g. the
states of the US). Each table is associated with a polity "group" (an entry in 'export.polities'),
which contains handlers specifying how to process the data tables and also a pointer to the
relevant table. The data is used as follows:

1. To generate the text of topical categories for cities/towns/rivers/etc. in a given polity,
   e.g. 'fr:Cities in Alabama, USA' for French terms for cities in Alabama. Note that each
   such category (this in fact applies to all topical categories) has a parent category such as
   'Cities in Alabama, USA' that groups all language-specific topic categories together.
2. To generate the text of topical categories for political subdivisions of a given polity,
   e.g. 'de:Provinces of the Netherlands', 'es:Counties of Alabama', or
   'pt:Municipalities of Amazonas, Brazil'.
3. To generate the text of a "bare label" topical category directly associated with the polity,
   such as 'de:Netherlands', 'es:Alabama, USA', or 'pt:Amazonas, Brazil'.
4. To add pages to all the above types of categories when a call to {{place}} on that page
   references the polity, such as by a template call {{place|en|city|state/Alabama}} (which will
   add the page to 'en:Cities in Alabama, USA'.

Uses #1, #2 and #3 are controlled by [[Module:category tree/topic cat/data/Places]].
Use #4 is controlled by [[Module:place/data]].

The keys of each table are the polity names in the form they will appear in a category like
'de:Provinces of the Netherlands' or 'fr:Cities in Alabama, USA' (hence, they should include
prefixes such as "the" and suffixes such as ", USA"). Transforming these keys to the form that
appears in the bare label category (e.g. 'de:Netherlands'), in category parents and/or in
descriptions can be done using the 'bare_label_setter' and 'value_transformer' keys (see
'export.polities' below).
	 
The value of an item in each table is itself a table. This table contains properties describing
the polity in question. Note that before being used (e.g. to generate the contents of a category
page like '[[:Category:en:Cities in Ireland]]' or '[[:Category:de:Provinces of the Netherlands]]'
of to specify how to add the relevant categories to a page with a call to {{place}})', the table
is passed through the associated polity group's 'value_transformer' function (see 'export.polities').
That function generally augments the property table with additional properties that are common to
the group or derivable from group-specific properties. The following are the properties most
commonly specified (additional properties are sometimes attached to entries in specific groups):

- 'divtype': String specifying the type of polity or subpolity (e.g. "country", "state", province").
  This can also be a table of such types; in this case, the first listed type is the canonical type
  that will be used in descriptions, but the polity will be recognized (e.g. in {{place}} arguments)
  when tagged with any of the specified types. This value overrides the group-level 'default_divtype'
  value, and only needs to be specified if it disagrees with that value.

- 'poldiv': List of recognized political subdivisions; e.g. for the Netherlands, a specification of
  the form 'poldiv = {"provinces", "municipalities"}' will allow categories such as 'de:Provinces of
  the Netherlands' and 'pt:Municipalities of the Netherlands' to be created. These categories have a
  primary parent "Political subdivisions" (i.e. this is the parent that appears in the breadcrumbs at
  the top of the category page), and have the containing polity, if any (see 'containing_polity' below)
  as an additional parent. Any political subdivision that appears here must also be listed in the
  'political_subdivisions' list, which tells how to convert the pluralized political subdivision into
  the equivalent linked description. (If not listed, an error occurs.)

- 'miscdiv': List of recognized historical/popular subdivisions; e.g. for Ireland, a specification of
  the form 'miscdiv = {"provinces"}' will allow categories such as 'pl:Provinces of Ireland' to be
  created. These categories differ from political subdivision categories in that their primary parent
  is the country name rather than "Political subdivisions".

- 'nocities': If 'true', don't recognize categories such as 'en:Cities in Monaco' or 'fr:Rivers in the
  Soviet Union'. NOTE: This key is often added automatically by the 'value_transformer' function.

- 'keydesc': String directly specifying a description of the polity, for use in generating the contents
  of category pages related to the polity. descriptions. This property is only rarely present, and is
  normally generated automatically by the 'value_transformer' function from the key and (for subpolities)
  the value of 'divtype'.

- 'parents': List of parents of the bare label category. For example, if 'parents = {"Europe", "Asia"}'
  is specified for "Turkey", bare label categories such as 'en:Turkey' will have parent categories
  'en:Europe' and 'en:Asia'. The first listed category is used for the primary parent (i.e. this is the
  parent that appears in the breadcrumbs at the top of the category page). In this case, for example,
  "Europe" (not "Asia") is used as the breadcrumb. This property only needs to be specified for
  top-level polities (countries and such), not for subpolities (states, provinces, etc.), which use the
  value of 'containing_polity' (see below) as the parent.

- 'bare_label_desc': String specifying the description used in the bare label category. If not given, a
   default description is constructed by the 'bare_label_setter' function.

- 'containing_polity': This property does not need to be specified explicitly. It is automatically added
  by the 'value_transformer' function for subpolities, and left off for top-level polities. It specifies
  the larger polity in which the subpolity is contained, and is used to construct the primary parent of
  'Cities in ...', 'Rivers in ...', and similar categories. For example, the subpolity Guangdong (a province
  of China) will have "China" as the containing_polity, so that a category of the form
  'en:Cities in Guangdong" will have its primary parent (i.e. the parent that appears in the breadcrumbs at
  the top of the category page) as "Cities in China". If containing_polity is omitted, as in top-level
  polities, the primary parent will simply be "Cities" (or "Towns", "Rivers", etc. as appropriate).
]=]

export.countries = {
	["Afghanistan"] = {parents = {"Asia"}, poldiv = {"provinces", "districts"}, miscdiv = {"regions"}},
	["Albania"] = {parents = {"Europe"}, poldiv = {"counties", "municipalities"}, british_spelling = true},
	["Algeria"] = {parents = {"Africa"}, poldiv = {"provinces", "communes", "districts", "municipalities"}},
	["Andorra"] = {parents = {"Europe"}, poldiv = {"parishes"}, british_spelling = true},
	["Angola"] = {parents = {"Africa"}, poldiv = {"provinces", "municipalities"}},
	["Antigua and Barbuda"] = {parents = {"North America"}, poldiv = {"provinces"}, british_spelling = true},
	["Argentina"] = {parents = {"South America"}, poldiv = {"provinces", "departments", "municipalities"}},
	["Armenia"] = {parents = {"Europe", "Asia"}, poldiv = {"regions", "provinces"}, british_spelling = true},
	-- Both a country and continent
	["Australia"] = {parents = {"Earth", "Oceania"}, poldiv = {"states", "territories", "local government areas"}, british_spelling = true},
	["Austria"] = {parents = {"Europe"}, poldiv = {"states", "districts", "municipalities"}, british_spelling = true},
	["Azerbaijan"] = {parents = {"Europe", "Asia"}, poldiv = {"districts", "municipalities"}, british_spelling = true},
	["the Bahamas"] = {parents = {"North America"}, poldiv = {"districts"}, british_spelling = true},
	["Bahrain"] = {parents = {"Asia"}, poldiv = {"governorates"}},
	["Bangladesh"] = {parents = {"Asia"}, poldiv = {"divisions", "districts", "municipalities"}, british_spelling = true},
	["Barbados"] = {parents = {"North America"}, poldiv = {"parishes"}, british_spelling = true},
	["Belarus"] = {parents = {"Europe"}, poldiv = {"regions", "districts"}, british_spelling = true},
	["Belgium"] = {parents = {"Europe"}, poldiv = {"regions", "provinces", "municipalities"}, british_spelling = true},
	["Belize"] = {parents = {"Central America"}, poldiv = {"districts"}, british_spelling = true},
	["Benin"] = {parents = {"Africa"}, poldiv = {"departments", "communes"}},
	["Bhutan"] = {parents = {"Asia"}, poldiv = {"districts", "gewogs"}},
	["Bolivia"] = {parents = {"South America"}, poldiv = {"provinces", "departments", "municipalities"}},
	["Bosnia and Herzegovina"] = {parents = {"Europe"}, poldiv = {"entities", "cantons", "municipalities"}, british_spelling = true},
	["Botswana"] = {parents = {"Africa"}, poldiv = {"districts", "subdistricts"}, british_spelling = true},
	["Brazil"] = {parents = {"South America"}, poldiv = {"states", "state capitals", "municipalities"}, miscdiv = {"regions"}},
	["Brunei"] = {parents = {"Asia"}, poldiv = {"districts", "mukims"}, british_spelling = true},
	["Bulgaria"] = {parents = {"Europe"}, poldiv = {"provinces", "municipalities"}, british_spelling = true},
	["Burkina Faso"] = {parents = {"Africa"}, poldiv = {"regions", "departments", "provinces"}},
	["Burma"] = {parents = {"Asia"}, poldiv = {"regions", "states", "union territories", "self-administered zones", "self-administered divisions", "districts"}},
	["Burundi"] = {parents = {"Africa"}, poldiv = {"provinces", "communes"}},
	["Cambodia"] = {parents = {"Asia"}, poldiv = {"provinces", "districts"}},
	["Cameroon"] = {parents = {"Africa"}, poldiv = {"regions", "departments"}},
	["Canada"] = {parents = {"North America"}, poldiv = {"provinces", "territories", "counties", "districts", "municipalities"},
		miscdiv = {"regions", "census divisions"}, british_spelling = true},
	["Cape Verde"] = {parents = {"Africa"}, poldiv = {"municipalities", "parishes"}},
	["the Central African Republic"] = {parents = {"Africa"}, poldiv = {"prefectures", "subprefectures"}},
	["Chad"] = {parents = {"Africa"}, poldiv = {"regions", "departments"}},
	["Chile"] = {parents = {"South America"}, poldiv = {"regions", "provinces"}},
	["China"] = {parents = {"Asia"}, poldiv = {"provinces", "autonomous regions",
		"special administrative regions", "prefectures", "counties", "districts", "municipalities"},
		miscdiv = {"regions"}},
	["Colombia"] = {parents = {"South America"}, poldiv = {"departments", "municipalities"}},
	["the Comoros"] = {parents = {"Africa"}, poldiv = {"autonomous islands"}},
	["Costa Rica"] = {parents = {"Central America"}, poldiv = {"provinces", "cantons"}},
	["Croatia"] = {parents = {"Europe"}, poldiv = {"counties", "municipalities"}, british_spelling = true},
	["Cuba"] = {parents = {"North America"}, poldiv = {"provinces", "municipalities"}},
	["Cyprus"] = {parents = {"Europe", "Asia"}, poldiv = {"districts"}, british_spelling = true},
	["the Czech Republic"] = {parents = {"Europe"}, poldiv = {"regions", "districts"}, british_spelling = true},
	["the Democratic Republic of the Congo"] = {parents = {"Africa"}, poldiv = {"provinces", "territories"}},
	["Denmark"] = {parents = {"Europe"}, poldiv = {"regions", "municipalities", "territories"}, british_spelling = true},
	["Djibouti"] = {parents = {"Africa"}, poldiv = {"regions", "districts"}},
	["Dominica"] = {parents = {"North America"}, poldiv = {"parishes"}, british_spelling = true},
	["the Dominican Republic"] = {parents = {"North America"}, poldiv = {"provinces", "municipalities"},
		keydesc = "the [[Dominican Republic]], the country that shares the [[Caribbean]] island of [[Hispaniola]] with [[Haiti]]"},
	["East Timor"] = {parents = {"Africa"}, poldiv = {"municipalities"}},
	["Ecuador"] = {parents = {"South America"}, poldiv = {"provinces", "cantons"}},
	["Egypt"] = {parents = {"Africa"}, poldiv = {"governorates", "regions"}},
	["El Salvador"] = {parents = {"Central America"}, poldiv = {"departments", "municipalities"}},
	["Equatorial Guinea"] = {parents = {"Africa"}, poldiv = {"provinces"}},
	["Eritrea"] = {parents = {"Africa"}, poldiv = {"regions", "subregions"}},
	["Estonia"] = {parents = {"Europe"}, poldiv = {"counties", "municipalities"}, british_spelling = true},
	["Ethiopia"] = {parents = {"Africa"}, poldiv = {"regions", "zones"}},
	["the Federated States of Micronesia"] = {parents = {"Micronesia"}, poldiv = {"states"}},
	["Fiji"] = {parents = {"Melanesia"}, poldiv = {"divisions", "provinces"}, british_spelling = true},
	["Finland"] = {parents = {"Europe"}, poldiv = {"regions", "municipalities"}, british_spelling = true},
	["France"] = {parents = {"Europe"}, poldiv = {"regions", "departments", "collectivities", "municipalities",
		"territories"}, miscdiv = {"provinces"}, british_spelling = true},
	["Gabon"] = {parents = {"Africa"}, poldiv = {"provinces", "departments"}},
	["the Gambia"] = {parents = {"Africa"}, poldiv = {"divisions", "districts"}, british_spelling = true},
	["Georgia"] = {parents = {"Europe", "Asia"}, poldiv = {"regions", "districts"}, keydesc = "the country of [[Georgia]], in [[Eurasia]]", british_spelling = true},
	["Germany"] = {parents = {"Europe"}, poldiv = {"states", "municipalities", "districts"}, british_spelling = true},
	["Ghana"] = {parents = {"Africa"}, poldiv = {"regions", "districts"}, british_spelling = true},
	["Greece"] = {parents = {"Europe"}, poldiv = {"regional units", "municipalities"}, british_spelling = true},
	["Grenada"] = {parents = {"North America"}, poldiv = {"parishes"}, british_spelling = true},
	["Guatemala"] = {parents = {"Central America"}, poldiv = {"departments", "municipalities"}},
	["Guinea"] = {parents = {"Africa"}, poldiv = {"regions", "prefectures"}},
	["Guinea-Bissau"] = {parents = {"Africa"}, poldiv = {"regions"}},
	["Guyana"] = {parents = {"South America"}, poldiv = {"regions"}, british_spelling = true},
	["Haiti"] = {parents = {"North America"}, poldiv = {"departments", "arrondissements"}},
	["Honduras"] = {parents = {"Central America"}, poldiv = {"departments", "municipalities"}},
	["Hungary"] = {parents = {"Europe"}, poldiv = {"counties", "districts"}, british_spelling = true},
	["Iceland"] = {parents = {"Europe"}, poldiv = {"regions", "municipalities", "counties"}, british_spelling = true},
	["India"] = {parents = {"Asia"}, poldiv = {"states", "union territories", "divisions", "districts", "municipalities"}, british_spelling = true},
	["Indonesia"] = {parents = {"Asia"}, poldiv = {"regencies", "provinces"}},
	["Iran"] = {parents = {"Asia"}, poldiv = {"provinces", "counties"}},
	["Iraq"] = {parents = {"Asia"}, poldiv = {"governorates", "districts"}},
	["Ireland"] = {parents = {"Europe", "British Isles"}, poldiv = {"counties", "districts"}, miscdiv = {"provinces"}, british_spelling = true},
	["Israel"] = {parents = {"Asia"}, poldiv = {"districts"}},
	["Italy"] = {parents = {"Europe"}, poldiv = {"regions", "provinces"}, miscdiv = {"regions"}, british_spelling = true},
	["Ivory Coast"] = {parents = {"Africa"}, poldiv = {"districts", "regions"}},
	["Jamaica"] = {parents = {"North America"}, poldiv = {"parishes"}, british_spelling = true},
	["Japan"] = {parents = {"Asia"}, poldiv = {"prefectures", "subprefectures", "municipalities"}},
	["Jordan"] = {parents = {"Asia"}, poldiv = {"governorates"}},
	["Kazakhstan"] = {parents = {"Europe", "Asia"}, poldiv = {"regions", "districts"}},
	["Kenya"] = {parents = {"Africa"}, poldiv = {"counties"}, british_spelling = true},
	["Kiribati"] = {parents = {"Micronesia"}, british_spelling = true},
	["Kosovo"] = {parents = {"Europe"}, british_spelling = true},
	["Kuwait"] = {parents = {"Asia"}, poldiv = {"governorates", "areas"}},
	["Kyrgyzstan"] = {parents = {"Asia"}, poldiv = {"regions", "districts"}},
	["Laos"] = {parents = {"Asia"}, poldiv = {"provinces", "districts"}},
	["Latvia"] = {parents = {"Europe"}, poldiv = {"municipalities"}, miscdiv = {"regions"}, british_spelling = true},
	["Lebanon"] = {parents = {"Asia"}, poldiv = {"governorates", "districts"}},
	["Lesotho"] = {parents = {"Africa"}, poldiv = {"districts"}, british_spelling = true},
	["Liberia"] = {parents = {"Africa"}, poldiv = {"counties", "districts"}},
	["Libya"] = {parents = {"Africa"}, poldiv = {"districts", "municipalities"}},
	["Liechtenstein"] = {parents = {"Europe"}, poldiv = {"municipalities"}, british_spelling = true},
	["Lithuania"] = {parents = {"Europe"}, poldiv = {"counties", "municipalities"},
		miscdiv = {"ethnographic regions"}, british_spelling = true},
	["Luxembourg"] = {parents = {"Europe"}, poldiv = {"cantons"}, miscdiv = {"districts"}, british_spelling = true},
	["Madagascar"] = {parents = {"Africa"}, poldiv = {"regions", "districts"}},
	["Malawi"] = {parents = {"Africa"}, poldiv = {"regions", "districts"}, british_spelling = true},
	["Malaysia"] = {parents = {"Asia"}, poldiv = {"states", "federal territories", "districts"}, british_spelling = true},
	["the Maldives"] = {parents = {"Asia"}, poldiv = {"provinces", "administrative atolls"}, british_spelling = true},
	["Mali"] = {parents = {"Africa"}, poldiv = {"regions", "cercles"}},
	["Malta"] = {parents = {"Europe"}, poldiv = {"local councils"}, british_spelling = true},
	["the Marshall Islands"] = {parents = {"Micronesia"}, poldiv = {"municipalities"}},
	["Mauritania"] = {parents = {"Africa"}, poldiv = {"regions", "departments"}},
	["Mauritius"] = {parents = {"Africa"}, poldiv = {"districts"}, british_spelling = true},
	["Mexico"] = {parents = {"North America", "Central America"}, poldiv = {"states", "municipalities"}},
	["Moldova"] = {parents = {"Europe"}, poldiv = {"districts"}, british_spelling = true},
	["Monaco"] = {parents = {"Europe"}, nocities = true, british_spelling = true},
	["Mongolia"] = {parents = {"Asia"}, poldiv = {"provinces", "districts"}},
	["Montenegro"] = {parents = {"Europe"}, poldiv = {"municipalities"}},
	["Morocco"] = {parents = {"Africa"}, poldiv = {"regions", "prefectures", "provinces"}},
	["Mozambique"] = {parents = {"Africa"}, poldiv = {"provinces", "districts"}},
	["Namibia"] = {parents = {"Africa"}, poldiv = {"regions", "constituencies"}, british_spelling = true},
	["Nauru"] = {parents = {"Micronesia"}, poldiv = {"districts"}, british_spelling = true},
	["Nepal"] = {parents = {"Asia"}, poldiv = {"provinces", "districts"}},
	["the Netherlands"] = {parents = {"Europe"}, poldiv = {"provinces", "municipalities"}, british_spelling = true},
	["New Zealand"] = {parents = {"Polynesia"}, poldiv = {"regions", "territorial authorities"}, british_spelling = true},
	["Nicaragua"] = {parents = {"Central America"}, poldiv = {"departments", "municipalities"}},
	["Niger"] = {parents = {"Africa"}, poldiv = {"regions", "departments"}},
	["Nigeria"] = {parents = {"Africa"}, poldiv = {"states", "local government areas"}, british_spelling = true},
	["North Korea"] = {parents = {"Asia", "Korea"}, poldiv = {"provinces", "counties"}},
	["North Macedonia"] = {parents = {"Europe"}, poldiv = {"municipalities"}, british_spelling = true},
	["Norway"] = {parents = {"Europe"}, poldiv = {"counties", "municipalities", "dependencies"},
		miscdiv = {"districts", "unincorporated areas"}, british_spelling = true},
	["Oman"] = {parents = {"Asia"}, poldiv = {"governorates", "provinces"}},
	["Pakistan"] = {parents = {"Asia"}, poldiv = {"provinces", "districts"}, british_spelling = true},
	["Palestine"] = {parents = {"Asia"}},
	["Palau"] = {parents = {"Micronesia"}, poldiv = {"states"}},
	["Panama"] = {parents = {"Central America"}, poldiv = {"provinces", "districts"}},
	["Papua New Guinea"] = {parents = {"Melanesia"}, poldiv = {"provinces", "districts"}, british_spelling = true},
	["Paraguay"] = {parents = {"South America"}, poldiv = {"departments", "districts"}},
	["Peru"] = {parents = {"South America"}, poldiv = {"regions", "provinces", "districts"}},
	["the Philippines"] = {parents = {"Asia"}, poldiv = {"regions", "provinces", "provincial capitals", "districts", "municipalities"}},
	["Poland"] = {poldiv = {"voivodeships", "counties"}, parents = {"Europe"}, british_spelling = true},
	["Portugal"] = {parents = {"Europe"}, poldiv = {"districts and autonomous regions", "provinces", "municipalities"}, british_spelling = true},
	["Qatar"] = {parents = {"Asia"}, poldiv = {"municipalities", "zones"}},
	["the Republic of the Congo"] = {parents = {"Africa"}, poldiv = {"departments", "districts"}},
	["Romania"] = {parents = {"Europe"}, poldiv = {"regions", "counties"}, british_spelling = true},
	["Russia"] = {parents = {"Europe", "Asia"}, poldiv = {"republics", "autonomous oblasts", "autonomous okrugs", "oblasts", "krais", "federal cities", "districts"}, british_spelling = true},
	["Rwanda"] = {parents = {"Africa"}, poldiv = {"provinces", "districts"}},
	["Saint Kitts and Nevis"] = {parents = {"North America"}, poldiv = {"parishes"}, british_spelling = true},
	["Saint Lucia"] = {parents = {"North America"}, poldiv = {"quarters"}, british_spelling = true},
	["Saint Vincent and the Grenadines"] = {parents = {"North America"}, poldiv = {"parishes"}, british_spelling = true},
	["Samoa"] = {parents = {"Polynesia"}, poldiv = {"districts"}, british_spelling = true},
	["San Marino"] = {parents = {"Europe"}, poldiv = {"municipalities"}, british_spelling = true},
	["São Tomé and Príncipe"] = {parents = {"Africa"}, poldiv = {"districts"}},
	["Saudi Arabia"] = {parents = {"Asia"}, poldiv = {"provinces", "governorates"}},
	["Senegal"] = {parents = {"Africa"}, poldiv = {"regions", "departments"}},
	["Serbia"] = {parents = {"Europe"}, poldiv = {"districts", "municipalities"}}, 
	["Seychelles"] = {parents = {"Africa"}, poldiv = {"districts"}, british_spelling = true},
	["Sierra Leone"] = {parents = {"Africa"}, poldiv = {"provinces", "districts"}, british_spelling = true},
	["Singapore"] = {parents = {"Asia"}, poldiv = {"districts"}, british_spelling = true},
	["Slovakia"] = {parents = {"Europe"}, poldiv = {"regions", "districts"}, british_spelling = true},
	["Slovenia"] = {parents = {"Europe"}, poldiv = {"municipalities"}, british_spelling = true},
	-- Note: the official name does not include "the" at the beginning, but it sounds strange in
	-- English to leave it out and it's commonly included, so we include it.
	["the Solomon Islands"] = {parents = {"Melanesia"}, poldiv = {"provinces"}, british_spelling = true},
	["Somalia"] = {parents = {"Africa"}, poldiv = {"regions", "districts"}},
	["South Africa"] = {parents = {"Africa"}, poldiv = {"provinces", "districts"}, british_spelling = true},
	["South Korea"] = {parents = {"Asia", "Korea"}, poldiv = {"provinces", "counties", "districts"}},
	["South Sudan"] = {parents = {"Africa"}, poldiv = {"regions", "states"}, british_spelling = true},
	["Spain"] = {parents = {"Europe"}, poldiv = {"autonomous communities", "provinces", "municipalities"}, british_spelling = true},
	["Sri Lanka"] = {parents = {"Asia"}, poldiv = {"provinces", "districts"}, british_spelling = true},
	["Sudan"] = {parents = {"Africa"}, poldiv = {"states", "districts"}, british_spelling = true},
	["Suriname"] = {parents = {"South America"}, poldiv = {"districts"}},
	["Swaziland"] = {parents = {"Africa"}, british_spelling = true},
	["Sweden"] = {parents = {"Europe"}, poldiv = {"provinces", "counties", "municipalities"}, british_spelling = true},
	["Switzerland"] = {parents = {"Europe"}, poldiv = {"cantons", "municipalities", "districts"}, british_spelling = true},
	["Syria"] = {parents = {"Asia"}, poldiv = {"governorates", "districts"}},
	["Taiwan"] = {parents = {"Asia"}, poldiv = {"counties", "districts"}},
	["Tajikistan"] = {parents = {"Asia"}, poldiv = {"provinces"}, miscdiv = {"regions", "districts"}},
	["Tanzania"] = {parents = {"Africa"}, poldiv = {"provinces", "districts"}, british_spelling = true},
	["Thailand"] = {parents = {"Asia"}, poldiv = {"provinces", "districts"}},
	["Togo"] = {parents = {"Africa"}, poldiv = {"provinces", "prefectures"}},
	["Tonga"] = {parents = {"Polynesia"}, poldiv = {"divisions"}, british_spelling = true},
	["Trinidad and Tobago"] = {parents = {"North America"}, poldiv = {"regions", "municipalities"}, british_spelling = true},
	["Tunisia"] = {parents = {"Africa"}, poldiv = {"governorates", "delegations"}},
	["Turkey"] = {parents = {"Europe", "Asia"}, poldiv = {"provinces", "districts"}},
	["Turkmenistan"] = {parents = {"Asia"}, poldiv = {"regions", "districts"}},
	["Tuvalu"] = {parents = {"Polynesia"}, poldiv = {"atolls"}, british_spelling = true},
	["Uganda"] = {parents = {"Africa"}, poldiv = {"districts", "counties"}, british_spelling = true},
	["Ukraine"] = {parents = {"Europe"}, poldiv = {"oblasts", "municipalities", "raions"}, british_spelling = true},
	["the United Arab Emirates"] = {parents = {"Asia"}, poldiv = {"emirates"}},
	["the United Kingdom"] = {parents = {"Europe", "British Isles"},
		poldiv = {"countries", "territories", "dependencies"},
		keydesc = "the [[United Kingdom]] of Great Britain and Northern Ireland", british_spelling = true},
	["the United States"] = {parents = {"North America"},
		poldiv = {"counties", "county seats", "states", "state capitals", "territories",
			"municipalities", -- these exist politically at least in Colorado and Connecticut
		}, miscdiv = {"regions"}},
	["Uruguay"] = {parents = {"South America"}, poldiv = {"departments", "municipalities"}},
	["Uzbekistan"] = {parents = {"Asia"}, poldiv = {"regions", "districts"}},
	["Vanuatu"] = {parents = {"Melanesia"}, poldiv = {"provinces"}, british_spelling = true},
	["Vatican City"] = {parents = {"Europe", "Rome"}, nocities = true, british_spelling = true},
	["Venezuela"] = {parents = {"South America"}, poldiv = {"states", "municipalities"}},
	["Vietnam"] = {parents = {"Asia"}, poldiv = {"provinces", "districts", "municipalities"}},
	["Western Sahara"] = {parents = {"Africa"}},
	["Yemen"] = {parents = {"Asia"}, poldiv = {"governorates", "districts"}},
	["Zambia"] = {parents = {"Africa"}, poldiv = {"provinces", "districts"}, british_spelling = true},
	["Zimbabwe"] = {parents = {"Africa"}, poldiv = {"provinces", "districts"}, british_spelling = true},
}

export.pseudo_countries = {
	-- British Overseas Territory
	["Akrotiri and Dhekelia"] = {divtype = {"overseas territory", "territory"}, parents = {"Cyprus", "Europe", "United Kingdom"}, british_spelling = true},
	-- unincorporated territory of the United States
	["American Samoa"] = {divtype = {"unincorporated territory", "overseas territory", "territory"}, parents = {"Polynesia", "United States"}},
	-- British Overseas Territory
	["Anguilla"] = {divtype = {"overseas territory", "territory"}, parents = {"North America", "United Kingdom"}, british_spelling = true},
	-- de-facto independent state, internationally recognized as part of Georgia
	["Abkhazia"] = {divtype = {"unrecognized state", "country"}, parents = {"Georgia", "Europe", "Asia"},
		poldiv = {"districts"},
		keydesc = "the de-facto independent state of [[Abkhazia]], internationally recognized as part of the country of [[Georgia]]"},
	-- de-facto independent state of Armenian ethnicity, internationally recognized as part of Azerbaijan
	-- (also known as Nagorno-Karabakh)
	-- NOTE: Formerly listed Armenia as a parent; this seems politically non-neutral
	-- so I've taken it out.
	["Artsakh"] = {divtype = {"unrecognized state", "country"}, parents = {"Azerbaijan", "Europe", "Asia"},
		keydesc = "the de-facto independent state of [[Artsakh]], internationally recognized as part of [[Azerbaijan]]", british_spelling = true},
	-- British Overseas Territory
	["Ascension Island"] = {divtype = {"overseas territory", "territory"}, parents = {"United Kingdom", "Atlantic Ocean"}, british_spelling = true},
	-- constituent country of the Netherlands
	["Aruba"] = {divtype = {"constituent country", "country"}, parents = {"Netherlands", "North America"}},
	-- British Overseas Territory
	["Bermuda"] = {divtype = {"overseas territory", "territory"}, parents = {"United Kingdom", "North America"}, british_spelling = true},
	-- British Overseas Territory
	["the British Indian Ocean Territory"] = {divtype = {"overseas territory", "territory"}, parents = {"United Kingdom", "North America"}, british_spelling = true},
	-- British Overseas Territory
	["the British Virgin Islands"] = {divtype = {"overseas territory", "territory"}, parents = {"United Kingdom", "North America"}, british_spelling = true},
	-- British Overseas Territory
	["the Cayman Islands"] = {divtype = {"overseas territory", "territory"}, parents = {"United Kingdom", "North America"}, british_spelling = true},
	-- Australian external territory
	["Christmas Island"] = {divtype = {"external territory", "territory"}, parents = {"Australia", "Asia"}, british_spelling = true},
	-- Australian external territory; also called the Keeling Islands or (officially) the Cocos (Keeling) Islands
	["the Cocos Islands"] = {divtype = {"external territory", "territory"}, parents = {"Australia", "Asia"}, british_spelling = true},
	-- self-governing but in free association with New Zealand
	["the Cook Islands"] = {divtype = {"country"}, parents = {"Polynesia", "New Zealand"}, british_spelling = true},
	-- constituent country of the Netherlands
	["Curaçao"] = {divtype = {"constituent country", "country"}, parents = {"Netherlands", "North America"}},
	-- special territory of Chile
	["Easter Island"] = {divtype = {"special territory", "territory"}, parents = {"Chile", "Polynesia"}},
	-- British Overseas Territory
	["the Falkland Islands"] = {divtype = {"overseas territory", "territory"}, parents = {"United Kingdom", "South America"}, british_spelling = true},
	-- autonomous territory of Denmark
	["the Faroe Islands"] = {divtype = {"autonomous territory", "territory"}, parents = {"Denmark", "Europe"}},
	-- overseas department of France
	["French Guiana"] = {divtype = {"overseas department", "department"}, parents = {"France", "South America"}},
	-- overseas collectivity of France
	["French Polynesia"] = {divtype = {"overseas collectivity", "collectivity"}, parents = {"France", "Polynesia"}},
	-- British Overseas Territory
	["Gibraltar"] = {divtype = {"overseas territory", "territory"}, parents = {"United Kingdom", "North America"}, british_spelling = true},
	-- autonomous territory of Denmark
	["Greenland"] = {divtype = {"autonomous territory", "territory"}, parents = {"Denmark", "North America"}, poldiv = {"municipalities"}},
	-- overseas department of France
	["Guadeloupe"] = {divtype = {"overseas department", "department"}, parents = {"France", "North America"}},
	-- unincorporated territory of the United States
	["Guam"] = {divtype = {"unincorporated territory", "overseas territory", "territory"}, parents = {"United States", "Micronesia"}},
	-- self-governing British Crown dependency; technically called the Bailiwick of Guernsey
	["Guernsey"] = {divtype = {"crown dependency", "dependency", "bailiwick", "territory"}, parents = {"British Isles", "Europe"}, british_spelling = true},
	-- special administrative region of China
	["Hong Kong"] = {divtype = "special administrative region", parents = {"China"}},
	-- self-governing British Crown dependency
	["the Isle of Man"] = {divtype = {"crown dependency", "dependency", "territory"}, parents = {"British Isles", "Europe"}, british_spelling = true},
	-- self-governing British Crown dependency; technically called the Bailiwick of Jersey
	["Jersey"] = {divtype = {"crown dependency", "dependency", "bailiwick", "territory"}, parents = {"British Isles", "Europe"}, british_spelling = true},
	-- special administrative region of China
	["Macau"] = {divtype = "special administrative region", parents = {"China"}},
	-- overseas department of France
	["Martinique"] = {divtype = {"overseas department", "department"}, parents = {"France", "North America"}},
	-- British Overseas Territory
	["Montserrat"] = {divtype = {"overseas territory", "territory"}, parents = {"United Kingdom", "North America"}, british_spelling = true},
	-- special collectivity of France
	["New Caledonia"] = {divtype = {"special collectivity", "collectivity"}, parents = {"France", "Melanesia"}},
	-- self-governing but in free association with New Zealand
	["Niue"] = {divtype = {"country"}, parents = {"Polynesia", "New Zealand"}, british_spelling = true},
	-- Australian external territory
	["Norfolk Island"] = {divtype = {"external territory", "territory"}, parents = {"Australia", "Polynesia"}, british_spelling = true},
	-- commonwealth, unincorporated territory of the United States
	["the Northern Mariana Islands"] = {divtype = {"commonwealth", "unincorporated territory", "overseas territory", "territory"}, parents = {"United States", "Micronesia"}},
	-- British Overseas Territory
	["the Pitcairn Islands"] = {divtype = {"overseas territory", "territory"}, parents = {"United Kingdom", "Polynesia"}, british_spelling = true},
	-- commonwealth of the United States
	["Puerto Rico"] = {divtype = {"commonwealth", "overseas territory", "territory"}, parents = {"United States", "North America"}},
	-- overseas collectivity of France
	["Saint Barthélemy"] = {divtype = {"overseas collectivity", "collectivity"}, parents = {"France", "North America"}},
	-- British Overseas Territory
	["Saint Helena"] = {divtype = {"overseas territory", "territory"}, parents = {"United Kingdom", "Atlantic Ocean"}, british_spelling = true},
	-- overseas collectivity of France
	["Saint Martin"] = {divtype = {"overseas collectivity", "collectivity"}, parents = {"France", "North America"}},
	-- overseas collectivity of France
	["Saint Pierre and Miquelon"] = {divtype = {"overseas collectivity", "collectivity"}, parents = {"France", "North America"}},
	-- de-facto independent state, internationally recognized as part of Georgia
	["South Ossetia"] = {divtype = {"unrecognized state", "country"}, parents = {"Georgia", "Europe", "Asia"},
		keydesc = "the de-facto independent state of [[South Ossetia]], internationally recognized as part of the country of [[Georgia]]", british_spelling = true},
	-- constituent country of the Netherlands
	["Sint Maarten"] = {divtype = {"constituent country", "country"}, parents = {"Netherlands", "North America"}},
	-- British Overseas Territory
	["South Georgia"] = {divtype = {"overseas territory", "territory"}, parents = {"United Kingdom", "Atlantic Ocean"}, british_spelling = true},
	-- British Overseas Territory
	["the South Sandwich Islands"] = {divtype = {"overseas territory", "territory"}, parents = {"United Kingdom", "Atlantic Ocean"}, british_spelling = true},
	-- dependent territory of New Zealnd
	["Tokelau"] = {divtype = {"dependent territory", "territory"}, parents = {"New Zealand", "Polynesia"}, british_spelling = true},
	-- de-facto independent state, internationally recognized as part of Moldova
	["Transnistria"] = {divtype = {"unrecognized state", "country"}, parents = {"Moldova", "Europe"},
		keydesc = "the de-facto independent state of [[Transnistria]], internationally recognized as part of [[Moldova]]", british_spelling = true},
	-- British Overseas Territory
	["Tristan da Cunha"] = {divtype = {"overseas territory", "territory"}, parents = {"United Kingdom", "Atlantic Ocean"}, british_spelling = true},
	-- British Overseas Territory
	["the Turks and Caicos Islands"] = {divtype = {"overseas territory", "territory"}, parents = {"United Kingdom", "North America"}, british_spelling = true},
	-- unincorporated territory of the United States
	["the United States Virgin Islands"] = {divtype = {"unincorporated territory", "overseas territory", "territory"}, parents = {"United States", "North America"}},
	-- unincorporated territory of the United States
	["Wake Island"] = {divtype = {"unincorporated territory", "overseas territory", "territory"}, parents = {"United States", "North America"}},
	-- overseas collectivity of France
	["Wallis and Futuna"] = {divtype = {"overseas collectivity", "collectivity"}, parents = {"France", "Polynesia"}},
}

export.former_countries = {
	["Czechoslovakia"] = {parents = {"Europe"}, british_spelling = true},
	["East Germany"] = {parents = {"Europe", "Germany"}, british_spelling = true},
	["North Vietnam"] = {parents = {"Asia", "Vietnam"}},
	["Persia"] = {parents = {"Asia"}, poldiv = {"provinces"}},
	["the Roman Empire"] = {divtype = {"empire", "country"}, parents = {"Europe", "Africa", "Asia", "Rome"}, poldiv = {"provinces"}},
	["South Vietnam"] = {parents = {"Asia", "Vietnam"}},
	["the Soviet Union"] = {parents = {"Europe", "Asia"}, poldiv = {"republics", "autonomous republics"}, british_spelling = true},
	["West Germany"] = {parents = {"Europe", "Germany"}, british_spelling = true},
	["Yugoslavia"] = {parents = {"Europe"}, poldiv = {"districts"},
		keydesc = "the former [[Kingdom of Yugoslavia]] (1918-1943) or the former [[Socialist Federal Republic of Yugoslavia]] (1943-1992)", british_spelling = true},
}

export.australian_states_and_territories = {
	["New South Wales"] = {},
	["the Northern Territory"] = {divtype = "territory"},
	["Queensland"] = {},
	["South Australia"] = {},
	["Tasmania"] = {},
	["Victoria"] = {},
	["Western Australia"] = {},
}

export.austrian_states = {
	["Vienna"] = {},
	["Lower Austria"] = {},
	["Upper Austria"] = {},
	["Styria"] = {},
	["Tyrol"] = {},
	["Carinthia"] = {},
	["Salzburg"] = {},
	["Vorarlberg"] = {},
	["Burgenland"] = {},
}

export.brazilian_states = {
	["Acre, Brazil"] = {},
	["Alagoas, Brazil"] = {},
	["Amapá, Brazil"] = {},
	["Amazonas, Brazil"] = {},
	["Bahia, Brazil"] = {},
	["Ceará, Brazil"] = {},
	["Distrito Federal, Brazil"] = {},
	["Espírito Santo, Brazil"] = {},
	["Goiás, Brazil"] = {},
	["Maranhão, Brazil"] = {},
	["Mato Grosso, Brazil"] = {},
	["Mato Grosso do Sul, Brazil"] = {},
	["Minas Gerais, Brazil"] = {},
	["Pará, Brazil"] = {},
	["Paraíba, Brazil"] = {},
	["Paraná, Brazil"] = {},
	["Pernambuco, Brazil"] = {},
	["Piauí, Brazil"] = {},
	["Rio de Janeiro, Brazil"] = {},
	["Rio Grande do Norte, Brazil"] = {},
	["Rio Grande do Sul, Brazil"] = {},
	["Rondônia, Brazil"] = {},
	["Roraima, Brazil"] = {},
	["Santa Catarina, Brazil"] = {},
	["São Paulo, Brazil"] = {},
	["Sergipe, Brazil"] = {},
	["Tocantins, Brazil"] = {},
}

local rural_municipalities = {"rural municipalities", parent="rural municipalities"}
local canadian_counties = {"counties", parent="counties of Canada"}
export.canadian_provinces_and_territories = {
	["Alberta"] = {poldiv = {"municipal districts"}},
	["British Columbia"] = {poldiv = {"regional districts", "regional municipalities"}},
	["Manitoba"] = {poldiv = {rural_municipalities}},
	["New Brunswick"] = {poldiv = {canadian_counties}},
	["Newfoundland and Labrador"] = {},
	["the Northwest Territories"] = {divtype = "territory"},
	["Nova Scotia"] = {poldiv = {canadian_counties, "regional municipalities"}},
	["Nunavut"] = {divtype = "territory"},
	["Ontario"] = {poldiv = {canadian_counties, "regional municipalities"}},
	["Prince Edward Island"] = {poldiv = {canadian_counties, rural_municipalities}},
	["Saskatchewan"] = {poldiv = {rural_municipalities}},
	["Quebec"] = {poldiv = {canadian_counties, "regional county municipalities"}},
	["Yukon"] = {divtype = "territory"},
}

-- table of Chinese provinces and autonomous regions; interpolated into the main 'places' table, but also needed separately
export.chinese_provinces_and_autonomous_regions = {
	["Anhui"] = {},
	["Fujian"] = {},
	["Gansu"] = {},
	["Guangdong"] = {},
	["Guangxi"] = {divtype = "autonomous region"},
	["Guizhou"] = {},
	["Hainan"] = {},
	["Hebei"] = {},
	["Heilongjiang"] = {},
	["Henan"] = {},
	["Hubei"] = {},
	["Hunan"] = {},
	["Inner Mongolia"] = {divtype = "autonomous region"},
	["Jiangsu"] = {},
	["Jiangxi"] = {},
	["Jilin"] = {},
	["Liaoning"] = {},
	["Ningxia"] = {divtype = "autonomous region"},
	["Qinghai"] = {},
	["Shaanxi"] = {},
	["Shandong"] = {},
	["Shanxi"] = {},
	["Sichuan"] = {},
	["Tibet"] = {divtype = "autonomous region"},
	["Xinjiang"] = {divtype = "autonomous region"},
	["Yunnan"] = {},
	["Zhejiang"] = {},
}

export.finnish_regions = {
	["Lapland, Finland"] = {},
	["North Ostrobothnia, Finland"] = {},
	["Kainuu, Finland"] = {},
	["North Karelia, Finland"] = {},
	["Northern Savonia, Finland"] = {},
	["Southern Savonia, Finland"] = {},
	["South Karelia, Finland"] = {},
	["Central Finland, Finland"] = {},
	["South Ostrobothnia, Finland"] = {},
	["Ostrobothnia, Finland"] = {},
	["Central Ostrobothnia, Finland"] = {},
	["Pirkanmaa, Finland"] = {},
	["Satakunta, Finland"] = {},
	["Päijänne Tavastia, Finland"] = {},
	["Tavastia Proper, Finland"] = {},
	["Kymenlaakso, Finland"] = {},
	["Uusimaa, Finland"] = {},
	["Southwest Finland, Finland"] = {},
	["the Åland Islands, Finland"] = {},
}

export.french_regions = {
	["Auvergne-Rhône-Alpes"] = {},
	["Bourgogne-Franche-Comté"] = {},
	["Brittany"] = {},
	["Centre-Val de Loire"] = {},
	["Corsica"] = {},
	["French Guiana"] = {},
	["Grand Est"] = {},
	["Guadeloupe"] = {},
	["Hauts-de-France"] = {},
	["Île-de-France"] = {},
	["Martinique"] = {},
	["Mayotte"] = {},
	["Normandy"] = {},
	["Nouvelle-Aquitaine"] = {},
	["Occitanie"] = {},
	["Pays de la Loire"] = {},
	["Provence-Alpes-Côte d'Azur"] = {},
	["Réunion"] = {},
}

export.german_states = {
	["Baden-Württemberg"] = {},
	["Bavaria"] = {},
	["Berlin"] = {},
	["Brandenburg"] = {},
	["Bremen"] = {},
	["Hamburg"] = {},
	["Hesse"] = {},
	["Lower Saxony"] = {},
	["Mecklenburg-Vorpommern"] = {},
	["North Rhine-Westphalia"] = {},
	["Rhineland-Palatinate"] = {},
	["Saarland"] = {},
	["Saxony"] = {},
	["Saxony-Anhalt"] = {},
	["Schleswig-Holstein"] = {},
	["Thuringia"] = {},
}

-- Indian states and union territories. Only some of them are divided into
-- divisions.
export.indian_states_and_union_territories = {
	["Andaman and Nicobar Islands"] = {divtype = "union territory"},
	["Andhra Pradesh"] = {},
	["Arunachal Pradesh"] = {poldiv = {"divisions"}},
	["Assam"] = {poldiv = {"divisions"}},
	["Bihar"] = {poldiv = {"divisions"}},
	["Chandigarh"] = {divtype = "union territory"},
	["Chhattisgarh"] = {poldiv = {"divisions"}},
	["Dadra and Nagar Haveli"] = {divtype = "union territory"},
	["Daman and Diu"] = {divtype = "union territory"},
	["Delhi"] = {divtype = "union territory", poldiv = {"divisions"}},
	["Goa"] = {},
	["Gujarat"] = {},
	["Haryana"] = {poldiv = {"divisions"}},
	["Himachal Pradesh"] = {poldiv = {"divisions"}},
	["Jammu and Kashmir"] = {divtype = "union territory", poldiv = {"divisions"}},
	["Jharkhand"] = {poldiv = {"divisions"}},
	["Karnataka"] = {poldiv = {"divisions"}},
	["Kerala"] = {},
	["Ladakh"] = {divtype = "union territory", poldiv = {"divisions"}},
	["Lakshadweep"] = {divtype = "union territory"},
	["Madhya Pradesh"] = {poldiv = {"divisions"}},
	["Maharashtra"] = {poldiv = {"divisions"}},
	["Manipur"] = {},
	["Meghalaya"] = {poldiv = {"divisions"}},
	["Mizoram"] = {},
	["Nagaland"] = {poldiv = {"divisions"}},
	["Odisha"] = {poldiv = {"divisions"}},
	["Puducherry"] = {divtype = "union territory"},
	["Punjab"] = {poldiv = {"divisions"}},
	["Rajasthan"] = {poldiv = {"divisions"}},
	["Sikkim"] = {},
	["Tamil Nadu"] = {},
	["Telangana"] = {},
	["Tripura"] = {},
	["Uttar Pradesh"] = {poldiv = {"divisions"}},
	["Uttarakhand"] = {poldiv = {"divisions"}},
	["West Bengal"] = {poldiv = {"divisions"}},
}

export.irish_counties = {
	["County Carlow, Ireland"] = {},
	["County Cavan, Ireland"] = {},
	["County Clare, Ireland"] = {},
	["County Cork, Ireland"] = {},
	["County Donegal, Ireland"] = {},
	["County Dublin, Ireland"] = {},
	["County Galway, Ireland"] = {},
	["County Kerry, Ireland"] = {},
	["County Kildare, Ireland"] = {},
	["County Kilkenny, Ireland"] = {},
	["County Laois, Ireland"] = {},
	["County Leitrim, Ireland"] = {},
	["County Limerick, Ireland"] = {},
	["County Longford, Ireland"] = {},
	["County Louth, Ireland"] = {},
	["County Mayo, Ireland"] = {},
	["County Meath, Ireland"] = {},
	["County Monaghan, Ireland"] = {},
	["County Offaly, Ireland"] = {},
	["County Roscommon, Ireland"] = {},
	["County Sligo, Ireland"] = {},
	["County Tipperary, Ireland"] = {},
	["County Waterford, Ireland"] = {},
	["County Westmeath, Ireland"] = {},
	["County Wexford, Ireland"] = {},
	["County Wicklow, Ireland"] = {},
}

export.italian_regions = {
	["Abruzzo"] = {},
	["Aosta Valley"] = {},
	["Apulia"] = {},
	["Basilicata"] = {},
	["Calabria"] = {},
	["Campania"] = {},
	["Emilia-Romagna"] = {},
	["Friuli-Venezia Giulia"] = {},
	["Lazio"] = {},
	["Liguria"] = {},
	["Lombardy"] = {},
	["Marche"] = {},
	["Molise"] = {},
	["Piedmont"] = {},
	["Sardinia"] = {},
	["Sicily"] = {},
	["Trentino-Alto Adige"] = {},
	["Tuscany"] = {},
	["Umbria"] = {},
	["Veneto"] = {},
}

-- table of Japanese prefectures; interpolated into the main 'places' table, but also needed separately
export.japanese_prefectures = {
	["Aichi Prefecture"] = {},
	["Akita Prefecture"] = {},
	["Aomori Prefecture"] = {},
	["Chiba Prefecture"] = {},
	["Ehime Prefecture"] = {},
	["Fukui Prefecture"] = {},
	["Fukuoka Prefecture"] = {},
	["Fukushima Prefecture"] = {},
	["Gifu Prefecture"] = {},
	["Gunma Prefecture"] = {},
	["Hiroshima Prefecture"] = {},
	["Hokkaido"] = {poldiv = {{"subprefectures", parent="subprefectures of Japan"}}}, -- just "Hokkaido" not "Hokkaido Prefecture"
	["Hyōgo Prefecture"] = {},
	["Ibaraki Prefecture"] = {},
	["Ishikawa Prefecture"] = {},
	["Iwate Prefecture"] = {},
	["Kagawa Prefecture"] = {},
	["Kagoshima Prefecture"] = {},
	["Kanagawa Prefecture"] = {},
	["Kōchi Prefecture"] = {},
	["Kumamoto Prefecture"] = {},
	["Kyoto Prefecture"] = {},
	["Mie Prefecture"] = {},
	["Miyagi Prefecture"] = {},
	["Miyazaki Prefecture"] = {},
	["Nagano Prefecture"] = {},
	["Nagasaki Prefecture"] = {},
	["Nara Prefecture"] = {},
	["Niigata Prefecture"] = {},
	["Ōita Prefecture"] = {},
	["Okayama Prefecture"] = {},
	["Okinawa Prefecture"] = {},
	["Osaka Prefecture"] = {},
	["Saga Prefecture"] = {},
	["Saitama Prefecture"] = {},
	["Shiga Prefecture"] = {},
	["Shimane Prefecture"] = {},
	["Shizuoka Prefecture"] = {},
	["Tochigi Prefecture"] = {},
	["Tokushima Prefecture"] = {},
	["Tokyo"] = {keydesc = "[[Tokyo]] Metropolis", poldiv = {"special wards", {"subprefectures", parent="subprefectures of Japan"}}}, -- just "Tokyo" not "Tokyo Prefecture" or "Tokyo Metropolis"
	["Tottori Prefecture"] = {},
	["Toyama Prefecture"] = {},
	["Wakayama Prefecture"] = {},
	["Yamagata Prefecture"] = {},
	["Yamaguchi Prefecture"] = {},
	["Yamanashi Prefecture"] = {},
}

local function japanese_placename_to_key(placename)
	if placename == "Hokkaido" or placename == "Tokyo" then
		return placename
	end
	return placename .. " Prefecture"
end

export.mexican_states = {
	["Aguascalientes"] = {},
	["Baja California Norte"] = {},
	["Baja California Sur"] = {},
	["Campeche"] = {},
	["Chiapas"] = {},
	["Mexico City"] = {},
	["Chihuahua"] = {},
	["Coahuila"] = {},
	["Colima"] = {},
	["Durango"] = {},
	["Guanajuato"] = {},
	["Guerrero"] = {},
	["Hidalgo"] = {},
	["Jalisco"] = {},
	["the State of Mexico"] = {},
	["Michoacán"] = {},
	["Morelos"] = {},
	["Nayarit"] = {},
	["Nuevo León"] = {},
	["Oaxaca"] = {},
	["Puebla"] = {},
	["Querétaro"] = {},
	["Quintana Roo"] = {},
	["San Luis Potosí"] = {},
	["Sinaloa"] = {},
	["Sonora"] = {},
	["Tabasco"] = {},
	["Tamaulipas"] = {},
	["Tlaxcala"] = {},
	["Veracruz"] = {},
	["Yucatán"] = {},
	["Zacatecas"] = {},
}

export.norwegian_counties = {
	["Østfold"] = {},
	["Akershus"] = {},
	["Oslo"] = {},
	["Hedmark"] = {},
	["Oppland"] = {},
	["Buskerud"] = {},
	["Vestfold"] = {},
	["Telemark"] = {},
	["Aust-Agder"] = {},
	["Vest-Agder"] = {},
	["Rogaland"] = {},
	["Hordaland"] = {},
	["Sogn og Fjordane"] = {},
	["Møre og Romsdal"] = {},
	["Nordland"] = {},
	["Troms"] = {},
	["Finnmark"] = {},
	["Trøndelag"] = {},
}

export.philippine_provinces = {
	["Abra, Philippines"] = {},
	["Agusan del Norte, Philippines"] = {},
	["Agusan del Sur, Philippines"] = {},
	["Aklan, Philippines"] = {},
	["Albay, Philippines"] = {},
	["Antique, Philippines"] = {},
	["Apayao, Philippines"] = {},
	["Aurora, Philippines"] = {},
	["Basilan, Philippines"] = {},
	["Bataan, Philippines"] = {},
	["Batanes, Philippines"] = {},
	["Batangas, Philippines"] = {},
	["Benguet, Philippines"] = {},
	["Biliran, Philippines"] = {},
	["Bohol, Philippines"] = {},
	["Bukidnon, Philippines"] = {},
	["Bulacan, Philippines"] = {},
	["Cagayan, Philippines"] = {},
	["Camarines Norte, Philippines"] = {},
	["Camarines Sur, Philippines"] = {},
	["Camiguin, Philippines"] = {},
	["Capiz, Philippines"] = {},
	["Catanduanes, Philippines"] = {},
	["Cavite, Philippines"] = {},
	["Cebu, Philippines"] = {},
	["Cotabato, Philippines"] = {},
	["Davao de Oro, Philippines"] = {},
	["Davao del Norte, Philippines"] = {},
	["Davao del Sur, Philippines"] = {},
	["Davao Occidental, Philippines"] = {},
	["Davao Oriental, Philippines"] = {},
	["Dinagat Islands, Philippines"] = {},
	["Eastern Samar, Philippines"] = {},
	["Guimaras, Philippines"] = {},
	["Ifugao, Philippines"] = {},
	["Ilocos Norte, Philippines"] = {},
	["Ilocos Sur, Philippines"] = {},
	["Iloilo, Philippines"] = {},
	["Isabela, Philippines"] = {},
	["Kalinga, Philippines"] = {},
	["La Union, Philippines"] = {},
	["Laguna, Philippines"] = {},
	["Lanao del Norte, Philippines"] = {},
	["Lanao del Sur, Philippines"] = {},
	["Leyte, Philippines"] = {},
	["Maguindanao, Philippines"] = {},
	["Marinduque, Philippines"] = {},
	["Masbate, Philippines"] = {},
	["Misamis Occidental, Philippines"] = {},
	["Misamis Oriental, Philippines"] = {},
	["Mountain Province, Philippines"] = {},
	["Negros Occidental, Philippines"] = {},
	["Negros Oriental, Philippines"] = {},
	["Northern Samar, Philippines"] = {},
	["Nueva Ecija, Philippines"] = {},
	["Nueva Vizcaya, Philippines"] = {},
	["Occidental Mindoro, Philippines"] = {},
	["Oriental Mindoro, Philippines"] = {},
	["Palawan, Philippines"] = {},
	["Pampanga, Philippines"] = {},
	["Pangasinan, Philippines"] = {},
	["Quezon, Philippines"] = {},
	["Quirino, Philippines"] = {},
	["Rizal, Philippines"] = {},
	["Romblon, Philippines"] = {},
	["Samar, Philippines"] = {},
	["Sarangani, Philippines"] = {},
	["Siquijor, Philippines"] = {},
	["Sorsogon, Philippines"] = {},
	["South Cotabato, Philippines"] = {},
	["Southern Leyte, Philippines"] = {},
	["Sultan Kudarat, Philippines"] = {},
	["Sulu, Philippines"] = {},
	["Surigao del Norte, Philippines"] = {},
	["Surigao del Sur, Philippines"] = {},
	["Tarlac, Philippines"] = {},
	["Tawi-Tawi, Philippines"] = {},
	["Zambales, Philippines"] = {},
	["Zamboanga del Norte, Philippines"] = {},
	["Zamboanga del Sur, Philippines"] = {},
	["Zamboanga Sibugay, Philippines"] = {},
	["Metro Manila, Philippines"] = {},
}

export.russian_federal_subjects = {
	-- autonomous oblasts
	["the Jewish Autonomous Oblast"] = {divtype = {"autonomous oblast", "oblast"}},
	-- autonomous okrugs
	["Chukotka Autonomous Okrug"] = {divtype = "autonomous okrug"},
	["Khanty-Mansi Autonomous Okrug"] = {divtype = "autonomous okrug"},
	["Nenets Autonomous Okrug"] = {divtype = "autonomous okrug"},
	["Yamalo-Nenets Autonomous Okrug"] = {divtype = "autonomous okrug"},
	-- krais
	["Altai Krai"] = {divtype = "krai"},
	["Kamchatka Krai"] = {divtype = "krai"},
	["Khabarovsk Krai"] = {divtype = "krai"},
	["Krasnodar Krai"] = {divtype = "krai"},
	["Krasnoyarsk Krai"] = {divtype = "krai"},
	["Perm Krai"] = {divtype = "krai"},
	["Primorsky Krai"] = {divtype = "krai"},
	["Stavropol Krai"] = {divtype = "krai"},
	["Zabaykalsky Krai"] = {divtype = "krai"},
	-- oblasts
	["Amur Oblast"] = {},
	["Arkhangelsk Oblast"] = {},
	["Astrakhan Oblast"] = {},
	["Belgorod Oblast"] = {},
	["Bryansk Oblast"] = {},
	["Chelyabinsk Oblast"] = {},
	["Irkutsk Oblast"] = {},
	["Ivanovo Oblast"] = {},
	["Kaliningrad Oblast"] = {},
	["Kaluga Oblast"] = {},
	["Kemerovo Oblast"] = {},
	["Kirov Oblast"] = {},
	["Kostroma Oblast"] = {},
	["Kurgan Oblast"] = {},
	["Kursk Oblast"] = {},
	["Leningrad Oblast"] = {},
	["Lipetsk Oblast"] = {},
	["Magadan Oblast"] = {},
	["Moscow Oblast"] = {},
	["Murmansk Oblast"] = {},
	["Nizhny Novgorod Oblast"] = {},
	["Novgorod Oblast"] = {},
	["Novosibirsk Oblast"] = {},
	["Omsk Oblast"] = {},
	["Orenburg Oblast"] = {},
	["Oryol Oblast"] = {},
	["Penza Oblast"] = {},
	["Pskov Oblast"] = {},
	["Rostov Oblast"] = {},
	["Ryazan Oblast"] = {},
	["Sakhalin Oblast"] = {},
	["Samara Oblast"] = {},
	["Saratov Oblast"] = {},
	["Smolensk Oblast"] = {},
	["Sverdlovsk Oblast"] = {},
	["Tambov Oblast"] = {},
	["Tomsk Oblast"] = {},
	["Tula Oblast"] = {},
	["Tver Oblast"] = {},
	["Tyumen Oblast"] = {},
	["Ulyanovsk Oblast"] = {},
	["Vladimir Oblast"] = {},
	["Volgograd Oblast"] = {},
	["Vologda Oblast"] = {},
	["Voronezh Oblast"] = {},
	["Yaroslavl Oblast"] = {},
	-- republics
	["the Republic of Adygea"] = {divtype = "republic"},
	["the Republic of Bashkortostan"] = {divtype = "republic"},
	["the Republic of Buryatia"] = {divtype = "republic"},
	["the Republic of Dagestan"] = {divtype = "republic"},
	["the Republic of Ingushetia"] = {divtype = "republic"},
	["the Republic of Kalmykia"] = {divtype = "republic"},
	["the Republic of Karelia"] = {divtype = "republic"},
	["the Republic of Khakassia"] = {divtype = "republic"},
	["the Republic of Mordovia"] = {divtype = "republic"},
	["the Republic of North Ossetia-Alania"] = {divtype = "republic"},
	["the Republic of Tatarstan"] = {divtype = "republic"},
	["the Altai Republic"] = {divtype = "republic"},
	["the Chechen Republic"] = {divtype = "republic"},
	["the Chuvash Republic"] = {divtype = "republic"},
	["the Kabardino-Balkar Republic"] = {divtype = "republic"},
	["the Karachay-Cherkess Republic"] = {divtype = "republic"},
	["the Komi Republic"] = {divtype = "republic"},
	["the Mari El Republic"] = {divtype = "republic"},
	["the Sakha Republic"] = {divtype = "republic"},
	["the Tuva Republic"] = {divtype = "republic"},
	["the Udmurt Republic"] = {divtype = "republic"},
	-- Not sure what to do about this one from a neutrality perspective
	-- ["the Republic of Crimea"] = {divtype = "republic"},
	-- There are also federal cities (not included because they're cities):
	-- Moscow, Saint Petersburg, Sevastopol (not sure what to do about the
	-- last one if we were to include federal cities, see "Republic of Crimea"
	-- above)
}

local function russian_placename_to_key(placename)
	-- We allow the user to say e.g. "obl/Samara" and "rep/Tatarstan" in place of
	-- "obl/Samara Oblast" and "rep/Republic of Tatarstan".
	if export.russian_federal_subjects[placename] or export.russian_federal_subjects["the " .. placename] then
		return placename
	end
	for _, suffix in ipairs({"Autonomous Okrug", "Krai", "Oblast"}) do
		local suffixed_placename = placename .. " " .. suffix
		if export.russian_federal_subjects[suffixed_placename] then
			return suffixed_placename
		end
	end
	local republic_placename = "Republic of " .. placename
	if export.russian_federal_subjects["the " .. republic_placename] then
		return republic_placename
	end
	local republic_placename = placename .. " Republic"
	if export.russian_federal_subjects["the " .. republic_placename] then
		return republic_placename
	end
	return placename
end

export.spanish_autonomous_communities = {
	["Andalusia"] = {},
	["Aragon"] = {},
	["Asturias"] = {},
	["the Balearic Islands"] = {},
	["the Basque Country"] = {},
	["the Canary Islands"] = {},
	["Cantabria"] = {},
	["Castile and León"] = {},
	["Castilla-La Mancha"] = {},
	["Catalonia"] = {},
	["the Community of Madrid"] = {},
	["Extremadura"] = {},
	["Galicia"] = {},
	["La Rioja"] = {},
	["Murcia"] = {},
	["Navarre"] = {},
	["Valencia"] = {},
}

export.uk_constituent_countries = {
	["England"] = {poldiv = {"regions", "counties", "districts", "civil parishes"}},
	["Northern Ireland"] = {divtype = "province", parents = {"United Kingdom", "Ireland"},
		poldiv = {"districts"}, miscdiv = {"traditional counties"}},
	["Scotland"] = {poldiv = {"council areas"}, miscdiv = {"regions", "districts", "traditional counties"}},
	["Wales"] = {poldiv = {"counties", "county boroughs"}},
}

-- table of US states; interpolated into the main 'places' table, but also needed separately
export.us_states = {
	["Alabama, USA"] = {},
	["Alaska, USA"] = {poldiv = {
		{"boroughs", parent="counties of the United States"},
		{"borough seats", parent="county seats of the United States"},
	}},
	["Arizona, USA"] = {},
	["Arkansas, USA"] = {},
	["California, USA"] = {},
	["Colorado, USA"] = {},
	["Connecticut, USA"] = {},
	["Delaware, USA"] = {},
	["Florida, USA"] = {},
	["Georgia, USA"] = {},
	["Hawaii, USA"] = {parents = {"United States", "Polynesia"}},
	["Idaho, USA"] = {},
	["Illinois, USA"] = {},
	["Indiana, USA"] = {},
	["Iowa, USA"] = {},
	["Kansas, USA"] = {},
	["Kentucky, USA"] = {},
	["Louisiana, USA"] = {poldiv = {
		{"parishes", parent="counties of the United States"},
		{"parish seats", parent="county seats of the United States"},
	}},
	["Maine, USA"] = {},
	["Maryland, USA"] = {},
	["Massachusetts, USA"] = {},
	["Michigan, USA"] = {},
	["Minnesota, USA"] = {},
	["Mississippi, USA"] = {},
	["Missouri, USA"] = {},
	["Montana, USA"] = {},
	["Nebraska, USA"] = {},
	["Nevada, USA"] = {},
	["New Hampshire, USA"] = {},
	["New Jersey, USA"] = {},
	["New Mexico, USA"] = {},
	["New York, USA"] = {},
	["North Carolina, USA"] = {},
	["North Dakota, USA"] = {},
	["Ohio, USA"] = {},
	["Oklahoma, USA"] = {},
	["Oregon, USA"] = {},
	["Pennsylvania, USA"] = {},
	["Rhode Island, USA"] = {},
	["South Carolina, USA"] = {},
	["South Dakota, USA"] = {},
	["Tennessee, USA"] = {},
	["Texas, USA"] = {},
	["Utah, USA"] = {},
	["Vermont, USA"] = {},
	["Virginia, USA"] = {},
	["Washington, USA"] = {},
	["West Virginia, USA"] = {},
	["Wisconsin, USA"] = {},
	["Wyoming, USA"] = {},
}

export.english_counties = {
	-- ["Avon, England"] = {}, -- no longer
	["Bedfordshire, England"] = {},
	["Berkshire, England"] = {},
	-- ["Brighton and Hove, England"] = {}, -- city
	-- ["Bristol, England"] = {}, -- city
	["Buckinghamshire, England"] = {},
	["Cambridgeshire, England"] = {},
	-- ["Cambridgeshire and Isle of Ely, England"] = {}, -- no longer
	["Cheshire, England"] = {},
	-- ["Cleveland, England"] = {}, -- no longer
	["Cornwall, England"] = {},
	-- ["Cumberland, England"] = {}, -- no longer
	["Cumbria, England"] = {},
	["Derbyshire, England"] = {},
	["Devon, England"] = {},
	["Dorset, England"] = {},
	["County Durham, England"] = {},
	-- ["East Suffolk, England"] = {}, -- no longer
	["East Sussex, England"] = {},
	["Essex, England"] = {},
	["Gloucestershire, England"] = {},
	["Greater London, England"] = {},
	["Greater Manchester, England"] = {},
	["Hampshire, England"] = {},
	-- ["Hereford and Worcester, England"] = {}, -- no longer
	["Herefordshire, England"] = {}, 
	["Hertfordshire, England"] = {},
	-- ["Humberside, England"] = {}, -- no longer
	-- ["Huntingdon and Peterborough, England"] = {}, -- no longer
	-- ["Huntingdonshire, England"] = {}, -- no longer
	-- ["the Isle of Ely, England"] = {}, -- no longer
	["the Isle of Wight, England"] = {},
	["Kent, England"] = {},
	["Lancashire, England"] = {},
	["Leicestershire, England"] = {},
	["Lincolnshire, England"] = {},
	-- ["the County of London, England"] = {}, -- no longer
	["Merseyside, England"] = {},
	-- ["Middlesex, England"] = {}, -- no longer
	["Norfolk, England"] = {},
	["Northamptonshire, England"] = {},
	["Northumberland, England"] = {},
	-- ["North Humberside, England"] = {}, -- no longer
	["North Yorkshire, England"] = {},
	["Nottinghamshire, England"] = {},
	["Oxfordshire, England"] = {},
	-- ["the Soke of Peterborough, England"] = {}, -- no longer
	["Rutland, England"] = {},
	["Shropshire, England"] = {},
	["Somerset, England"] = {},
	["South Humberside, England"] = {},
	["South Yorkshire, England"] = {},
	["Staffordshire, England"] = {},
	["Suffolk, England"] = {},
	["Surrey, England"] = {},
	-- ["Sussex, England"] = {}, -- no longer
	["Tyne and Wear, England"] = {},
	["Warwickshire, England"] = {},
	["the West Midlands, England"] = {},
	-- ["Westmorland, England"] = {}, -- no longer
	-- ["West Suffolk, England"] = {}, -- no longer
	["West Sussex, England"] = {},
	["West Yorkshire, England"] = {},
	["Wiltshire, England"] = {},
	["Worcestershire, England"] = {},
	-- ["Yorkshire, England"] = {}, -- no longer
	["the East Riding of Yorkshire, England"] = {},
	-- ["the North Riding of Yorkshire, England"] = {}, -- no longer
	-- ["the West Riding of Yorkshire, England"] = {}, -- no longer
}

export.northern_irish_counties = {
	["County Antrim, Northern Ireland"] = {},
	["County Armagh, Northern Ireland"] = {},
	["the City of Belfast, Northern Ireland"] = {nocities = true},
	["County Down, Northern Ireland"] = {},
	["County Fermanagh, Northern Ireland"] = {},
	["County Londonderry, Northern Ireland"] = {},
	["the City of Derry, Northern Ireland"] = {nocities = true},
	["County Tyrone, Northern Ireland"] = {},
}

export.scottish_council_areas = {
	["the City of Glasgow, Scotland"] = {},
	["the City of Edinburgh, Scotland"] = {},
	["Fife, Scotland"] = {},
	["North Lanarkshire, Scotland"] = {},
	["South Lanarkshire, Scotland"] = {},
	["Aberdeenshire, Scotland"] = {},
	["Highland, Scotland"] = {},
	["the City of Aberdeen, Scotland"] = {},
	["West Lothian, Scotland"] = {},
	["Renfrewshire, Scotland"] = {},
	["Falkirk, Scotland"] = {},
	["Perth and Kinross, Scotland"] = {},
	["Dumfries and Galloway, Scotland"] = {},
	["the City of Dundee, Scotland"] = {},
	["North Ayrshire, Scotland"] = {},
	["East Ayrshire, Scotland"] = {},
	["Angus, Scotland"] = {},
	["the Scottish Borders, Scotland"] = {},
	["South Ayrshire, Scotland"] = {},
	["East Dunbartonshire, Scotland"] = {},
	["East Lothian, Scotland"] = {},
	["Moray, Scotland"] = {},
	["East Renfrewshire, Scotland"] = {},
	["Stirling, Scotland"] = {},
	["Midlothian, Scotland"] = {},
	["West Dunbartonshire, Scotland"] = {},
	["Argyll and Bute, Scotland"] = {},
	["Inverclyde, Scotland"] = {},
	["Clackmannanshire, Scotland"] = {},
	["Na h-Eileanan Siar, Scotland"] = {},
	["the Shetland Islands, Scotland"] = {},
	["the Orkney Islands, Scotland"] = {},
}

export.welsh_principal_areas = {
	["Blaenau Gwent, Wales"] = {},
	["Bridgend, Wales"] = {},
	["Caerphilly, Wales"] = {},
	-- ["Cardiff, Wales"] = {divtype = "city"},
	["Carmarthenshire, Wales"] = {divtype = "county"},
	["Ceredigion, Wales"] = {divtype = "county"},
	["Conwy, Wales"] = {},
	["Denbighshire, Wales"] = {divtype = "county"},
	["Flintshire, Wales"] = {divtype = "county"},
	["Gwynedd, Wales"] = {divtype = "county"},
	["the Isle of Anglesey, Wales"] = {divtype = "county"},
	["Merthyr Tydfil, Wales"] = {},
	["Monmouthshire, Wales"] = {divtype = "county"},
	["Neath Port Talbot, Wales"] = {},
	-- ["Newport, Wales"] = {divtype = "city"},
	["Pembrokeshire, Wales"] = {divtype = "county"},
	["Powys, Wales"] = {divtype = "county"},
	["Rhondda Cynon Taf, Wales"] = {},
	-- ["Swansea, Wales"] = {divtype = "city"},
	["Torfaen, Wales"] = {},
	["the Vale of Glamorgan, Wales"] = {},
	["Wrexham, Wales"] = {},
}

export.new_york_boroughs = {
	["Bronx"] = true,
	["Brooklyn"] = true,
	["Manhattan"] = true,
	["Queens"] = true,
	["Staten Island"] = true,
}

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
			["Sapporo"] = {}, -- {"Hokkaido"}, -- 1,918,096
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
			-- this causes recursion errors.
			-- ["Valencia"] = {"Valencia"},
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
			["Glasgow"] = {{"the City of Glasgow", divtype="council area"}, {"Scotland", divtype="constituent country"}},
			["Leeds"] = {{"West Yorkshire"}, {"England", divtype="constituent country"}},
			["Newcastle upon Tyne"] = {{"Tyne and Wear"}, {"England", divtype="constituent country"}},
			["Newcastle"] = {alias_of="Newcastle upon Tyne"},
			["Bristol"] = {{"England", divtype="constituent country"}},
			["Cardiff"] = {{"Wales", divtype="constituent country"}},
			["Portsmouth"] = {{"Hampshire"}, {"England", divtype="constituent country"}},
			["Edinburgh"] = {{"the City of Edinburgh", divtype="council area"}, {"Scotland", divtype="constituent country"}},
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

-----------------------------------------------------------------------------------
--                              Helper functions                                 --
-----------------------------------------------------------------------------------

local function ucfirst(label)
	return mw.getContentLanguage():ucfirst(label)
end

local function add_indefinite_article(label)
	if label:find("^[aeiouAEIOU]") then
		return "an " .. label
	else
		return "a " .. label
	end
end

function export.construct_bare_and_linked_version(key)
	local bare_key = key:match("^the (.*)$")
	local linked_key
	if bare_key then
		linked_key = "the [[" .. bare_key .. "]]"
	else
		linked_key = "[[" .. key .. "]]"
		bare_key = key
	end
	return bare_key, linked_key
end

local function simple_polity_bare_label_setter()
	return function(labels, group, key, value)
		local bare_key, linked_key = export.construct_bare_and_linked_version(key)
		local keydesc = value.keydesc or linked_key
		labels[bare_key] = {
			description = value.bare_label_desc or "{{{langname}}} terms related to the people, culture, or territory of " .. keydesc .. ".",
			parents = value.parents,
		}
	end
end

local function subpolity_keydesc(key, value, containing_polity, default_divtype)
	local divtype = value.divtype or default_divtype
	divtype = type(divtype) == "table" and divtype[1] or divtype
	divtype = add_indefinite_article(divtype)
	local bare_key, linked_key = export.construct_bare_and_linked_version(key)
	local bare_containing_polity, linked_containing_polity = export.construct_bare_and_linked_version(containing_polity)
	return value.keydesc or linked_key .. ", " .. divtype .. " of " .. linked_containing_polity
end

local function apply_key_to_placename(key, key_to_placename)
	local placename = key
	if key_to_placename then
		placename = key_to_placename(key)
		if type(placename) == "table" then
			placename = placename[1]
		end
	end
	return placename
end

local function subpolity_bare_label_setter(containing_polity)
	return function(labels, group, key, value)
		local placename = apply_key_to_placename(key, group.key_to_placename)
		local keydesc = subpolity_keydesc(placename, value, containing_polity, group.default_divtype)
		local bare_key, linked_key = export.construct_bare_and_linked_version(key)
		local bare_containing_polity, linked_containing_polity = export.construct_bare_and_linked_version(containing_polity)
		labels[bare_key] = {
			description = value.bare_label_desc or "{{{langname}}} terms related to the people, culture, or territory of " .. keydesc .. ".",
			parents = value.parents or {bare_containing_polity},
		}
	end
end

local function subpolity_value_transformer(containing_polity)
	local containing_polity_type = "country"
	if type(containing_polity) == "table" then
		containing_polity_type, containing_polity = containing_polity[1], containing_polity[2]
	end
	return function(group, key, value)
		local placename = apply_key_to_placename(key, group.key_to_placename)
		value.keydesc = subpolity_keydesc(placename, value, containing_polity, group.default_divtype)
		value.containing_polity = containing_polity
		value.containing_polity_type = containing_polity_type
		value.poldiv = value.poldiv or group.default_poldiv
		value.british_spelling = value.british_spelling or group.british_spelling
		return value
	end
end

local function default_place_cat_handler()
	return function(group, placetype, holonym_placetype, holonym_placename)
		if group.placename_to_key then
			holonym_placename = group.placename_to_key(holonym_placename)
		end
		local spec = group.data[holonym_placename]
		if not spec then
			holonym_placename = "the " .. holonym_placename
			spec = group.data[holonym_placename]
		end
		if not spec then
			return nil
		end
		local divtype = spec.divtype or group.default_divtype
		if type(divtype) == "table" then
			for _, dt in ipairs(divtype) do
				if dt == holonym_placetype then
					return holonym_placename
				end
			end
			return nil
		else
			return divtype == holonym_placetype and holonym_placename or nil
		end
	end
end

-- This is typically used to define key_to_placename. It generates a function that chops off
-- part of a string using the regex TO_CHOP. To chop at the end, add $ at the end of the regex;
-- to chop at the beginning, add ^ at the beginning. It is normally used for subpolities (e.g.
-- states of the US or counties of England) when the placename of the polity as found in
-- categories includes the larger containing polity in it (e.g. "Georgia, USA" or
-- "Hampshire, England"). Typical usage is like this:
--
-- ...
-- key_to_placename = chop(", England$"),
-- ...
local function chop(to_chop)
	return function(key) return key:gsub(to_chop, "") end
end

-- This is typically used to define placename_to_key. It generates a function that appends a
-- string to the end of a given string. It does the opposite operation of chop() and is used
-- along with that function. It is normally used for subpolities (e.g. states of the US or
-- counties of England) when the placename of the polity as found in categories includes the
-- larger containing polity in it (e.g. "Georgia, USA" or "Hampshire, England"). Typical usage
-- is like this:
--
-- ...
-- placename_to_key = append(", England"),
-- ...
local function append(to_append)
	return function(placename) return placename .. to_append end
end

local function construct_russian_federal_subject_keydesc(linked_key, divtype)
	if divtype == "oblast" then
		-- Hack: Oblasts generally don't have entries under "Foo Oblast"
		-- but just under "Foo", so fix the linked key appropriately;
		-- doesn't apply to the Jewish Autonomous Oblast
		linked_key = linked_key:gsub(" Oblast%]%]", "%]%] Oblast")
	end
	return linked_key .. ", a federal subject ([[" .. divtype .. "]]) of [[Russia]]"
end

local function northern_ireland_key_to_placename(key)
	key = key:gsub(", Northern Ireland$", "")
	local bare_key = key:gsub("^County ", "")
	if key == bare_key then
		return key
	else
		return {key, bare_key}
	end
end

local function northern_ireland_placename_to_key(placename)
	if not placename:find("^County ") and not placename:find("^City ") then
		placename = "County " .. placename
	end
	return placename .. ", Northern Ireland"
end

local function ireland_key_to_placename(key)
	key = key:gsub(", Ireland$", "")
	local bare_key = key:gsub("^County ", "")
	if key == bare_key then
		return key
	else
		return {key, bare_key}
	end
end

local function ireland_placename_to_key(placename)
	if not placename:find("^County ") and not placename:find("^City ") then
		placename = "County " .. placename
	end
	return placename .. ", Ireland"
end

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

-- Given a containing polity of a city, possibly with preceding "the" removed,
-- find the group and key in 'export.polities'.
function export.city_containing_polity_to_group_and_key(polity)
	for _, polity_group in ipairs(export.polities) do
		local key_polity = polity
		if polity_group.placename_to_key then
			key_polity = polity_group.placename_to_key(key_polity)
		end
		if polity_group.data[key_polity] then
			return polity_group, key_polity
		end
		key_polity = "the " .. key_polity
		if polity_group.data[key_polity] then
			return polity_group, key_polity
		end
	end
	return nil
end

-----------------------------------------------------------------------------------
--                                  Polities                                     --
-----------------------------------------------------------------------------------

--[=[

The following table consists of one or more groups, each of which contains several
items (places) that are handled similarly. Each group contains a list of all the places
contained in that group along with their properties, as well as group-specific handlers that
specify common properties of all items in the group. These items are used to construct labels
for the following types of categories:

1. A bare label category, e.g. 'en:Netherlands'. Labels for these are created by the
   'bare_label_setter' handler of a given group.
2. Normally, several categories of the form 'fr:Cities in the Netherlands',
   'es:Rivers in New Mexico, USA', etc., for the place types listed above in 'generic_place_types'.
   There is a top-level handler that will automatically create labels for such categories,
   although it can be disabled by specifying 'nocities = true' in the data for a given item.
   (This is used for city-states such as Monaco and Vatican City.) One of the groups below,
   the one for former countries and empires, has a handler that specifies 'nocities = true'
   for all items in the group. The reason for this is that former states such as Persia,
   East Germany, the Soviet Union and the Roman Empire will have their cities, towns, rivers
   and such will be listed under the current entities occupying the same area.
3. Optionally, one or more categories of the form 'de:Provinces of the Netherlands',
   'pt:Counties of Wales', etc. These are for political subdivisions, and for historic/popular
   subdivisions that have no current political significance (e.g. 'nl:Provinces of Ireland',
   'zh:Regions of the United States'). These are controlled by the 'poldiv' (for political
   subdivisions) and 'miscdiv' (for historic/popular subdivisions) keys in the data for a
   given item.

NOTE: Second-level political subdivisions (e.g. counties of states of the US) could be handled
here but normally aren't. Instead, there are special handlers below for US counties and
Brazilian and Philippine municipalities, and manually-created labels for certain other countries
(e.g. Canadian counties). The reason for this is that all political and historic/popular subdivisions
handled here have a category like "en:Political subdivisions" as their primary parent, whereas
we often want a different primary parent for second-level political subdivisions, such as
"en:Counties of the United States" for US counties. FIXME: We should allow the parents
to be specified for political subdivisions. This will probably necessitate another type of
group-specific handler, similar to 'value_transformer' and 'bare_label_setter' (see below).

NOTE: Some of the above categories are added automatically to pages that use the {{place}}
template with the appropriate values. Currently, whether or not such categories are added
is controlled by [[Module:place/data]], which is independent of the data here but in many
ways duplicates it. FIXME: The two should be merged.

NOTE: There is also some duplication in [[Module:category tree/topic cat/data/Earth]],
particularly for continents and supranational regions (e.g. "the British Isles").
FIXME: Consolidate the data there into here.

Each group consists of a table with the following keys:

   * 'data': This is a table listing the polities in the group. The keys are polities in the form
     that they appear in a category like 'de:Provinces of the Netherlands' or 'fr:Cities in Alabama, USA'
	 (hence, they should include prefixes such as "the" and suffixes such as ", USA"). The value of a
	 key is a property table. Its format is described above under "Placename Tables". Note that the
	 property table is transformed using the group's 'value_transformer' handler before being used.

   * 'value_transformer': This function is used to transform the value of an item in 'data'
     (an object containing properties of a place; see above) to the final form used by the handlers
	 in [[Module:category tree/topic cat/data/Places]] that handle city-type and
	 political-subdivision-type categories. It is passed three arguments (the group and the key and
	 value of the data item). Its normal purpose is to add extra properties to the data item value,
	 such as 'containing_polity' (see above) and 'keydesc' (the appropriate description of the place,
	 which often includes the type of division and the country).  Some groups (in particular,
	 the one for former polities, such as Persia and the Roman Empire) also add 'nocities = true'.
	 The reason these extra properties are added by a function like this instead of included directly
	 is that they are typically the same or similar for all items in a group, and including them
	 directly would be duplicative. Note that there is a preconstructed function
	 subpolity_bare_label_setter() (for subpolities of top-level polities) to help.

   * 'bare_label_setter': This function adds an entry in the 'labels' table for bare label
     categories such as 'en:Netherlands', 'fr:Alabama, USA' or 'ru:Republic of Tatarstan'.
	 It is passed four arguments (the 'labels' table, the group and the key and value of the
	 data item). There are preconstructed functions to help here, such as
	 simple_polity_bare_label_setter() (for top-level polities) and subpolity_bare_label_setter()
	 (for subpolities of top-level polities). This function often makes use of the 'parents'
	 and/or 'description' keys in the data item's value (see above).

   * 'place_cat_handler': Used in conjunction with {{place}} to properly categorize placenames.
     Given four arguments (GROUP, the spec for a given group; PLACENAME, the placename for
	 a given place; HOLONYM_PLACETYPE, the placetype of a holonym of a place [e.g. "country" for
	 a location in a country]; and HOLONYM_PLACENAME, the name of a holonym of a place [e.g.
	 "France" for a location in France]), return the key in DATA correponding to HOLONYM_PLACENAME,
	 but only if the placetype of that key matches HOLONYM_PLACETYPE.

   * 'default_divtype': The default entity type for entities in this group, if not overidden at the
     entity level. See 'divtype' above under "Placename Tables".
]=]

export.polities = {
	-- countries
	{
		bare_label_setter = simple_polity_bare_label_setter(),
		value_transformer = function(group, key, value)
			value.british_spelling = value.british_spelling or group.british_spelling
			return value
		end,
		place_cat_handler = default_place_cat_handler(),
		default_divtype = "country",
		data = export.countries,
	},

	-- pseudo-countries: typically overseas territories or de-facto independent countries, which in both cases
	-- are not internationally recognized as sovereign nations but which we treat similarly to countries.
	{
		bare_label_setter = simple_polity_bare_label_setter(),
		value_transformer = function(group, key, value)
			value.british_spelling = value.british_spelling or group.british_spelling
			return value
		end,
		place_cat_handler = default_place_cat_handler(),
		default_divtype = "country",
		data = export.pseudo_countries,
	},

	-- former countries and such; we don't create "Cities in ..." categories because they don't exist anymore
	{
		bare_label_setter = simple_polity_bare_label_setter(),
		value_transformer = function(group, key, value)
			value.british_spelling = value.british_spelling or group.british_spelling
			value.nocities = true
			return value
		end,
		place_cat_handler = default_place_cat_handler(),
		default_divtype = "country",
		data = export.former_countries,
	},

	-- states and territories of Australia
	{
		bare_label_setter = subpolity_bare_label_setter("Australia"),
		value_transformer = subpolity_value_transformer("Australia"),
		place_cat_handler = default_place_cat_handler(),
		default_divtype = "state",
		british_spelling = true,
		data = export.australian_states_and_territories,
	},

	-- states of Austria
	{
		bare_label_setter = subpolity_bare_label_setter("Austria"),
		value_transformer = subpolity_value_transformer("Austria"),
		place_cat_handler = default_place_cat_handler(),
		default_divtype = "state",
		british_spelling = true,
		default_poldiv = {{"municipalities", parent="municipalities of Austria"}},
		data = export.austrian_states,
	},

	-- states of Brazil
	{
		key_to_placename = chop(", Brazil$"),
		placename_to_key = append(", Brazil"),
		bare_label_setter = subpolity_bare_label_setter("Brazil"),
		value_transformer = subpolity_value_transformer("Brazil"),
		place_cat_handler = default_place_cat_handler(),
		default_divtype = "state",
		default_poldiv = {{"municipalities", parent="municipalities of Brazil"}},
		data = export.brazilian_states,
	},

	-- provinces and territories of Canada
	{
		bare_label_setter = subpolity_bare_label_setter("Canada"),
		value_transformer = subpolity_value_transformer("Canada"),
		place_cat_handler = default_place_cat_handler(),
		default_divtype = "province",
		british_spelling = true,
		data = export.canadian_provinces_and_territories,
	},

	-- provinces and autonomous regions of China
	{
		bare_label_setter = subpolity_bare_label_setter("China"),
		value_transformer = subpolity_value_transformer("China"),
		place_cat_handler = default_place_cat_handler(),
		default_divtype = "province",
		data = export.chinese_provinces_and_autonomous_regions,
	},

	-- regions of Finland
	{
		key_to_placename = chop(", Finland$"),
		placename_to_key = append(", Finland"),
		bare_label_setter = subpolity_bare_label_setter("Finland"),
		value_transformer = subpolity_value_transformer("Finland"),
		place_cat_handler = default_place_cat_handler(),
		default_divtype = "region",
		default_poldiv = {{"municipalities", parent="municipalities of Finland"}},
		british_spelling = true,
		data = export.finnish_regions,
	},

	-- regions of France
	{
		bare_label_setter = subpolity_bare_label_setter("France"),
		value_transformer = subpolity_value_transformer("France"),
		place_cat_handler = default_place_cat_handler(),
		default_divtype = "region",
		british_spelling = true,
		data = export.french_regions,
	},

	-- states of Germany
	{
		bare_label_setter = subpolity_bare_label_setter("Germany"),
		value_transformer = subpolity_value_transformer("Germany"),
		place_cat_handler = default_place_cat_handler(),
		default_divtype = "state",
		british_spelling = true,
		data = export.german_states,
	},

	-- states and union territories of India
	{
		bare_label_setter = subpolity_bare_label_setter("India"),
		value_transformer = subpolity_value_transformer("India"),
		place_cat_handler = default_place_cat_handler(),
		default_divtype = "state",
		british_spelling = true,
		data = export.indian_states_and_union_territories,
	},

	-- counties of Ireland
	{
		key_to_placename = ireland_key_to_placename,
		placename_to_key = ireland_placename_to_key,
		bare_label_setter = subpolity_bare_label_setter("Ireland"),
		value_transformer = subpolity_value_transformer("Ireland"),
		place_cat_handler = default_place_cat_handler(),
		default_divtype = "county",
		british_spelling = true,
		data = export.irish_counties,
	},

	-- regions of Italy
	{
		bare_label_setter = subpolity_bare_label_setter("Italy"),
		value_transformer = subpolity_value_transformer("Italy"),
		place_cat_handler = default_place_cat_handler(),
		default_divtype = "region",
		british_spelling = true,
		data = export.italian_regions,
	},

	-- prefectures of Japan
	{
		key_to_placename = chop(" Prefecture$"),
		placename_to_key = japanese_placename_to_key,
		-- We can't use the normal subpolity_bare_label_setter() because we set a special parent
		-- (normally the parent would just be "Japan"). FIXME: Do we want this difference?
		-- Or do we want e.g. provinces in China to have a parent "Provinces of China" instead of
		-- just "China"?
		bare_label_setter = function(labels, group, key, value)
			labels[key] = {
				description = "{{{langname}}} terms related to [[" .. key:gsub(" Prefecture$", "") .. "]], a [[prefecture]] of [[Japan]].",
				parents = {"Prefectures of Japan"},
			}
		end,
		value_transformer = subpolity_value_transformer("Japan"),
		place_cat_handler = default_place_cat_handler(),
		default_divtype = "prefecture",
		data = export.japanese_prefectures,
	},

	-- Mexican states
	{
		bare_label_setter = subpolity_bare_label_setter("Mexico"),
		value_transformer = subpolity_value_transformer("Mexico"),
		place_cat_handler = default_place_cat_handler(),
		default_divtype = "state",
		data = export.mexican_states,
	},

	-- counties of Norway
	{
		bare_label_setter = subpolity_bare_label_setter("Norway"),
		value_transformer = subpolity_value_transformer("Norway"),
		place_cat_handler = default_place_cat_handler(),
		default_divtype = "county",
		british_spelling = true,
		data = export.norwegian_counties,
	},

	-- provinces of the Philippines
	{
		key_to_placename = chop(", Philippines$"),
		placename_to_key = append(" Philippines"),
		bare_label_setter = subpolity_bare_label_setter("the Philippines"),
		value_transformer = subpolity_value_transformer("the Philippines"),
		place_cat_handler = default_place_cat_handler(),
		default_divtype = "province",
		default_poldiv = {{"municipalities", parent="municipalities of the Philippines"}},
		data = export.philippine_provinces,
	},

	-- federal subjects of Russia
	{
		-- No current need for key_to_placename because it's only used in subpolity_bare_label_setter
		-- and subpolity_value_transformer, and we override both handlers.
		placename_to_key = russian_placename_to_key,
		bare_label_setter = function(labels, group, key, value)
			local divtype = value.divtype or group.default_divtype
			if type(divtype) == "table" then
				divtype = divtype[1]
			end
			local bare_key, linked_key = export.construct_bare_and_linked_version(key)
			labels[bare_key] = {
				description = "{{{langname}}} terms related to " .. construct_russian_federal_subject_keydesc(linked_key, divtype) .. ".",
				parents = {ucfirst(divtype) .. "s of Russia"},
			}
		end,
		value_transformer = function(group, key, value)
			value.containing_polity = "Russia"
			local divtype = value.divtype or group.default_divtype
			if type(divtype) == "table" then
				divtype = divtype[1]
			end
			local bare_key, linked_key = export.construct_bare_and_linked_version(key)
			value.keydesc = construct_russian_federal_subject_keydesc(linked_key, divtype)
			return value
		end,
		place_cat_handler = default_place_cat_handler(),
		default_divtype = "oblast",
		british_spelling = true,
		data = export.russian_federal_subjects,
	},

	-- autonomous communities of Spain
	{
		bare_label_setter = subpolity_bare_label_setter("Spain"),
		value_transformer = subpolity_value_transformer("Spain"),
		place_cat_handler = default_place_cat_handler(),
		default_divtype = "autonomous community",
		british_spelling = true,
		data = export.spanish_autonomous_communities,
	},

	-- states of the United States
	{
		key_to_placename = chop(", USA$"),
		placename_to_key = append(", USA"),
		bare_label_setter = subpolity_bare_label_setter("the United States"),
		value_transformer = subpolity_value_transformer("the United States"),
		place_cat_handler = default_place_cat_handler(),
		default_divtype = "state",
		default_poldiv = {
			{"counties", parent="counties of the United States"},
			{"county seats", parent="county seats of the United States"},
		},
		data = export.us_states,
	},

	-- constituent countries and provinces of the United Kingdom
	{
		bare_label_setter = subpolity_bare_label_setter("the United Kingdom"),
		value_transformer = function(group, key, value)
			value = subpolity_value_transformer("the United Kingdom")(group, key, value)
			-- Don't create categories like 'Category:en:Towns in the United Kingdom'
			-- or 'Category:en:Places in the United Kingdom'.
			value.no_containing_polity_cat = true
			return value
		end,
		place_cat_handler = default_place_cat_handler(),
		default_divtype = {"constituent country", "country"},
		british_spelling = true,
		data = export.uk_constituent_countries,
	},

	-- counties of England
	{
		key_to_placename = chop(", England$"),
		placename_to_key = append(", England"),
		bare_label_setter = subpolity_bare_label_setter("England"),
		value_transformer = subpolity_value_transformer({"constituent country", "England"}),
		place_cat_handler = default_place_cat_handler(),
		default_divtype = "county",
		default_poldiv = {{"districts", parent="districts of England"}},
		british_spelling = true,
		data = export.english_counties,
	},

	-- counties of Northern Ireland
	{
		key_to_placename = northern_ireland_key_to_placename,
		placename_to_key = northern_ireland_placename_to_key,
		bare_label_setter = subpolity_bare_label_setter("Northern Ireland"),
		value_transformer = subpolity_value_transformer({"constituent country", "Northern Ireland"}),
		place_cat_handler = default_place_cat_handler(),
		default_divtype = "county",
		british_spelling = true,
		data = export.northern_irish_counties,
	},

	-- council areas of Scotland
	{
		key_to_placename = chop(", Scotland$"),
		placename_to_key = append(", Scotland"),
		bare_label_setter = subpolity_bare_label_setter("Scotland"),
		value_transformer = subpolity_value_transformer({"constituent country", "Scotland"}),
		place_cat_handler = default_place_cat_handler(),
		default_divtype = "council area",
		british_spelling = true,
		data = export.scottish_council_areas,
	},

	-- principal areas (cities, counties and county boroughs) of Wales
	{
		key_to_placename = chop(", Wales$"),
		placename_to_key = append(", Wales"),
		bare_label_setter = subpolity_bare_label_setter("Wales"),
		value_transformer = subpolity_value_transformer({"constituent country", "Wales"}),
		place_cat_handler = default_place_cat_handler(),
		default_divtype = "county borough",
		british_spelling = true,
		data = export.welsh_principal_areas,
	},

}

return export
