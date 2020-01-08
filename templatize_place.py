#!/usr/bin/env python
# -*- coding: utf-8 -*-

# FIXME:
#
# 1. Check L2 header for language and use in place of 'en'. [DONE]
# 2. Need to preserve some links, e.g. probably at least in the translation (t1=). E.g.
#    Replaced <# {{zh-div|縣}} {{w|Li County, Hunan|Li County}} {{gloss|county in Hunan}}> with <# {{zh-div|縣}} {{place|zh|county|p/Hunan|t1=Li County}}>
#    There is no Wiktionary article "Li County". [DONE]
# 3. Restrict translation to the same form as that preceding County, district, etc.,
#    additionally allowing an initial "the". [DONE]
# 4. Add . to allowed chars preceding County, district, etc. (St. Louis County). [DONE]
# 5. Generalize proper noun regex to non-ASCII Latin chars. [PARTLY DONE; NOT FOR INITIAL CAP]
# 6. If "Indian state of" or "US state of" appears, add the respective country to the holonym.
# 7. If "[Pp]refecture", "[Pp]rovince", etc. appears, consider including that text in the
#    holonym (perhaps always for certain cases, e.g. Japanese prefectures)? If so, consider
#    adding logic to this effect in [[Module:place]].
# 8. If all holonyms can't be recognized, back off one word (or holonym?) at a time until
#    something (including at least one holonym) is recognized. FIXME: Unclear what to do when
#    a translation is available. [DONE]
# 9. Holonyms like {{l|en|Egypt|id=Q79}} aren't handled properly because of the id=.
# 10. Add "de" and "upon" as allowed words in proper nouns. DONE]
# 11. Strip {{wtorw}}.
# 12. The following shouldn't happen:
#     Replaced <# {{wtorw|Martvili}} {{gloss|a town in western Georgia}}> with <# {{wtorw|Martvili}} {{place|en|town|western|s/Georgia}}>
#     Page 3052010 Cochin: Replaced <# {{alternative form of|en|Kochi}} (city in India)> with <# {{alternative form of|en|Kochi}} {{place|en|city|c/India}}>
# 13. Things that occur frequently in toponyms:
# 13a. "Cilicia mentioned by Pliny", "Assyria mentioned by Pliny", "Asia mentioned by Pliny", etc.; Roman provinces? [DONE; REGIONS]
# 13b. "Clackmannanshire council area", "East Lothian council area", etc. [DONE]
# 13c. "Alpes-Maritimes department", "Moselle department", "Haut-Rhin département", etc. [DONE]
# 13d. "Haut-Rhin department of Alsace", "Pyrénées-Orientales department of France", "Seine-et-Marne department of Île-de-France", etc.
# 13e. "and one of the two county seats of Prairie County", "which is one of the two county seats of St. Clair County", etc.
# 13f. "Borough of Croydon", "Borough of Kingston upon Thames", "Borough of Tower Hamlets", etc. [DONE]
# 13g. "city of Aberdeen", "city of Newcastle upon Tyne", "city of Coventry", etc. [DONE]
# 13h. "interior of Liguria", "interior of Calabria", "interior of Samnium", "interior of Sicily", etc.
# 13i. "metropolitan borough of North Tyneside", "metropolitan borough of Kirklees", "metropolitan borough of Wakefield", etc. [DONE]
# 13j. "province Dalarna", "province Södermanland", "province Östergötland", etc. [DONE]
# 13k. "{{m|ja|中部|tr=Chūbu}} region of Japan", "{{m|ja|関東|tr=Kantō}} region of Japan facing the Pacific Ocean", etc.
# 14. "[[w = 24" unrecognized toponym; should only recognize : when followed by a space. Probably same for ,
#     (otherwise separate numbers like 200,000). [DONE]
# 15. Should at least try to handle the following:
#     Page 824348 Nukus: Replaced <# A city in [[Uzbekistan]], the capital of [[Karakalpakstan]].> with <# {{place|en|city|c/Uzbekistan}}, the capital of [[Karakalpakstan]].>
#     Page 38297 Schwyz: Replaced <# A town in [[Switzerland]], the capital of the canton of Schwyz.> with <# {{place|de|town|c/Switzerland}}, the capital of the canton of Schwyz.>
#     Page 47576 Cebu: Replaced <# A city in the Philippines, the capital of Cebu province.> with <# {{place|en|city|c/Philippines}}, the capital of Cebu province.>
# 16. Try to fill out official=, modern=, capital=, largest city=, caplc=
# 17. Fix the following: [DONE]
#     Page 3052017 Asansol: WARNING: Unable to recognize stripped holonym 'West Bengal province': <from> # A [[city]] in [[West Bengal]] province, [[eastern]] [[India]].
#     Page 3052024 Virginia Beach: WARNING: Unable to recognize stripped holonym 'state of Virginia': <from> # An [[independent city]] in the state of [[Virginia]] in the [[eastern]] [[United States]].
# 18. Fix the following (probably by disallowing zero holonyms): [DONE]
#     Page 5432682 Putnam County: Replaced <# a county in {{l|en|Georgia}}, USA, county seat {{l|en|Eatonton}}.> with <# {{place|en|county|s/Georgia|c/USA|;|county seat}} {{l|en|Eatonton}}.>
# 19. Consider fixing the following (probably by putting countries and constituent countries after states, provinces, districts, prefectures, cantons, boroughs, counties, islands, etc. but not regions or seas): [DONE]
#     Page 1622093 Visakhapatnam: Replaced <# A large [[city]] and [[district]] in [[India]], in the state of [[Andhra Pradesh]].> with <# {{place|en|large city/district|c/India|s/Andhra Pradesh}}
#     Page 81124 Bean: Replaced <# A [[village]] in [[Kent]], [[England]], in [[Dartford]] district.> with <# {{place|en|village|co/Kent|cc/England|dist/Dartford}}>
# 20. Fix the following:
#     Page 143442 Galicia: Replaced <# [[#English|Galicia]] {{gloss|region in NW Spain, north of Portugal}}> with <# {{place|fi|region|in northwestern|c/Spain|in northern|c/Portugal|t1=Galicia}}>
# 21. Fix the following (probably by disallowing two consecutive countries): [DONE]
#     Page 1063838 Araks: Replaced <# A river that flows in [[Turkey]], [[Armenia]], [[Iran]] and [[Azerbaijan]] and empties into [[Kura]] river.> with <# {{place|en|river|c/Turkey|c/Armenia}}, [[Iran]] and [[Azerbaijan]] and empties into [[Kura]] river.>
# 22. Fix the following (probably by putting "in" after countries followed by regions or seas, or regions followed by seas): [DONE]
#     Page 955656 Opole: Replaced <# A city in southern [[Poland]], in the region of [[Silesia]]> with <# {{place|en|city|in southern|c/Poland|r/Silesia}}>
#     Page 6639682 Kimitoön: Replaced <# A [[municipality]] in the region of {{w|Southwest Finland}} in the {{w|Archipelago Sea}}> with <# {{place|en|municipality|r/Southwest Finland|sea/Archipelago Sea}}>
# 23. Fix the following (probably by removing Macedonia as an alias of North Macedonia): [DONE]
#     Page 3065170 Philippi: Replaced <# An ancient town in [[Macedonia]], [[Greece]]> with <# {{place|en|ancient town|c/North Macedonia|c/Greece}}>
#     Page 6506818 Arnissa: Replaced <# An ancient town of [[Macedonia]] in the province of [[Eordaea]]> with <# {{place|la|ancient town|c/North Macedonia|p/Eordaea}}>
# 24. Fix the following (by moving preceding "in ..." qualifiers along with the country): [DONE BUT NEEDS CHECKING]
#     Page 2265176 Karlsborg: Replaced <# a small town in central Sweden, in the province [[Västergötland]]> with <# {{place|sv|small town|in central|p/Västergötland|c/Sweden}}>
# 25. Consider adding module support for seat= for county seats of counties and parsing them out. [DONE]

# FIXME for module:
# 1. Make links use {{wtorw}}?
# 2. Handle place qualifiers (small, historic, former, etc.). [DONE]
# 3. Support holonym qualifiers (central, northeastern, etc.). [NOT DONE;
#    JUST PUT "in" BEFORE QUALIFIER]

from collections import defaultdict

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

blib.getData()

place_qualifiers = [
  "small",
  "large",
  "major",
  "minor",
  "tiny",
  "short",
  "long",
  "important",
  "former",
  "ancient",
  "historic",
  "coastal",
  "maritime",
  "inland",
  "incorporated",
  "unincorporated",
]

aliased_place_qualifiers = {
  "historical": "historic",
  "seaside": "coastal",
}

place_qualifiers_with_aliases = {x: x for x in place_qualifiers}
place_qualifiers_with_aliases.update(aliased_place_qualifiers)

place_types = [
  # city
  "city",
  "prefecture-level city",
  "county-level city",
  "sub-provincial city",
  "independent city",
  "home rule city",
  "port city",
  "resort city",
  # town
  "town",
  "ghost town",
  "submerged ghost town",
  "market town",
  "town with bystatus",
  "harbour town",
  "harbor town",
  "port town",
  "statutory town",
  "suburban town",
  "spa town",
  "resort town",
  "township",
  "rural township",
  # village
  "village",
  # hamlet
  "hamlet",
  # settlement
  "settlement",
  # municipality
  "municipality",
  "home rule municipality",
  "rural municipality",
  "island municipality",
  "municipality with city status",
  # census-designated place
  "census-designated place",
  # community
  "community",
  "rural community",
  "autonomous community",
  # district
  "district",
  "subdistrict",
  "local government district",
  "local government district with borough status",
  "municipal district",
  "administrative district",
  # borough
  "borough",
  "metropolitan borough",
  "county borough",
  # area
  "area",
  "residential area",
  "suburban area",
  "inner-city area",
  "urban area",
  "council area",
  # neighborhood
  "neighborhood",
  "neighbourhood",
  # seat
  "county seat",
  "parish seat",
  "borough seat",
  # capital
  "capital",
  "capital city",
  "state capital",
  "provincial capital",
  # misc. cities
  "port",
  "seaport",
  "civil parish",
  "suburb",
  "unitary authority",
  "commune",
  # river
  "river",
  "tributary",
  "distributary",
  # misc. landforms
  "lake",
  "bay",
  "mountain",
  "mountain range",
  "valley",
  # larger divisions
  "county",
  "administrative county",
  "traditional county",
  "parish",
  "canton",
  "state",
  "province",
  "associated province",
  "autonomous province",
  "subprovince",
  "department",
  "prefecture",
  "subprefecture",
  "federal subject",
  "island",
  "group of islands",
  "chain of islands",
  "archipelago",
  "peninsula",
  "region",
  "subregion",
  "geographical region",
  "mountainous region",
  "administrative region",
  "autonomous region",
  "division",
  "territory",
  "federal territory",
  "overseas territory",
  "collectivity",
  "country",
  "island country",
  "republic",
]

aliased_place_types = {
  "CDP": "census-designated place",
  "home-rule municipality": "home rule municipality",
  "home-rule city": "home rule city",
  "home-rule class city": "home rule city",
  "home-rule-class city": "home rule city",
  "home rule class city": "home rule city",
  "home rule-class city": "home rule city",
  "town (with bystatus)": "town with bystatus",
  "city located": "city",
  "extinct town": "former town",
  "inner city area": "inner-city area",
  "earlier municipality": "former municipality",
  "river that flows": "river",
  "comune": "commune",
  "historical region": "historic region",
  "tributary river": "tributary",
  "port-town": "port town",
}

place_types_with_aliases = {x: x for x in place_types}
place_types_with_aliases.update(aliased_place_types)

place_types_to_codes = {
  "country": "c",
  "province": "p",
  "region": "r",
  "state": "s",
  "borough": "bor",
  "county borough": "cobor",
  "metropolitan borough": "metbor",
  "canton": "can",
  "county": "co",
  "district": "dist",
  "division": "div",
  "department": "dept",
  u"département": "dept",
  "island": "isl",
  "municipality": "mun",
  "prefecture": "pref",
  "city": "city",
  "town": "town",
}

continents = {
  "Europe",
  "Asia",
  "Africa",
  "North America",
  "Central America",
  "South America",
  "Oceania",
  "Antarctica",
}

regions = {
  "Middle East",
  "Caucasus",
  "Eastern Europe",
  "Central Europe",
  "Western Europe",
  "Southern Europe",
  "Southeast Asia",
  "South Asia",
  "East Asia",
  "Central Asia",
  "Western Asia",
  "Asia Minor",
  "Caribbean",
  "Polynesia",
  "Micronesia",
  "Melanesia",
  "Siberia",
  "North Africa",
  "Central Africa",
  "West Africa",
  "East Africa",
  "Southern Africa",
}

aliased_regions = {
  "central Asia": "Central Asia",
  "southern Asia": "South Asia",
  "southern Asia": "South Asia",
  "SE Asia": "Southeast Asia",
  "central Africa": "Central Africa",
  "Northern Africa": "North Africa",
  "northern Africa": "North Africa",
  "Eastern Africa": "East Africa",
  "eastern Africa": "East Africa",
  "Western Africa": "West Africa",
  "western Africa": "West Africa",
  "southern Africa": "Southern Africa",
}

regions_with_aliases = {x: x for x in regions}
regions_with_aliases.update(aliased_regions)

compass_points = {
  "eastern",
  "western",
  "northern",
  "southern",
  "northwestern",
  "northeastern",
  "southwestern",
  "southeastern",
  "central",
  "east-central",
  "west-central",
  "north-central",
  "south-central",
}

aliased_compass_points = {
  "northwest": "northwestern",
  "north-west": "northwestern",
  "north-western": "northwestern",
  "NW": "northwestern",
  "northeast": "northeastern",
  "north-east": "northeastern",
  "north-eastern": "northeastern",
  "NE": "northeastern",
  "southwest": "southwestern",
  "south-west": "southwestern",
  "south-western": "southwestern",
  "SW": "southwestern",
  "southeast": "southeastern",
  "south-east": "southeastern",
  "south-eastern": "southeastern",
  "SE": "southeastern",
  "north of": "northern",
  "south of": "southern",
  "east of": "eastern",
  "west of": "western",
  "north": "northern",
  "south": "southern",
  "east": "eastern",
  "west": "western",
  "east central": "east-central",
  "west central": "west-central",
  "north central": "north-central",
  "south central": "south-central",
}

compass_points_with_aliases = {x: x for x in compass_points}
compass_points_with_aliases.update(aliased_compass_points)

countries = {
  "Afghanistan",
  "Albania",
  "Algeria",
  "Andorra",
  "Angola",
  "Antigua and Barbuda",
  "Argentina",
  "Armenia",
  "Australia",
  "Austria",
  "Azerbaijan",
  "Bahamas",
  "Bahrain",
  "Bangladesh",
  "Barbados",
  "Belarus",
  "Belgium",
  "Belize",
  "Benin",
  "Bhutan",
  "Bolivia",
  "Bosnia and Herzegovina",
  "Botswana",
  "Brazil",
  "Brunei",
  "Bulgaria",
  "Burkina Faso",
  "Burma",
  "Burundi",
  "Cambodia",
  "Cameroon",
  "Canada",
  "Cape Verde",
  "Central African Republic",
  "Chad",
  "Chile",
  "China",
  "Colombia",
  "Comoros",
  "Costa Rica",
  "Croatia",
  "Cuba",
  "Cyprus",
  "Czech Republic",
  "Czechia",
  "Democratic Republic of the Congo",
  "Denmark",
  "Djibouti",
  "Dominica",
  "Dominican Republic",
  "East Timor",
  "Ecuador",
  "Egypt",
  "El Salvador",
  "Equatorial Guinea",
  "Eritrea",
  "Estonia",
  "Ethiopia",
  "Federated States of Micronesia",
  "Fiji",
  "Finland",
  "France",
  "Gabon",
  "Gambia",
  "Georgia",
  "Germany",
  "Ghana",
  "Greece",
  "Grenada",
  "Guatemala",
  "Guinea",
  "Guinea-Bissau",
  "Guyana",
  "Haiti",
  "Honduras",
  "Hungary",
  "Iceland",
  "India",
  "Indonesia",
  "Iran",
  "Iraq",
  "Ireland",
  "Israel",
  "Italy",
  "Ivory Coast",
  "Jamaica",
  "Japan",
  "Jordan",
  "Kazakhstan",
  "Kenya",
  "Kiribati",
  "Kosovo",
  "Kuwait",
  "Kyrgyzstan",
  "Laos",
  "Latvia",
  "Lebanon",
  "Lesotho",
  "Liberia",
  "Libya",
  "Liechtenstein",
  "Lithuania",
  "Luxembourg",
  "Madagascar",
  "Malawi",
  "Malaysia",
  "Maldives",
  "Mali",
  "Malta",
  "Marshall Islands",
  "Mauritania",
  "Mauritius",
  "Mexico",
  "Moldova",
  "Monaco",
  "Mongolia",
  "Montenegro",
  "Morocco",
  "Mozambique",
  "Namibia",
  "Nauru",
  "Nepal",
  "Netherlands",
  "New Zealand",
  "Nicaragua",
  "Niger",
  "Nigeria",
  "North Korea",
  "Norway",
  "Oman",
  "Pakistan",
  "Palestine",
  "Palau",
  "Panama",
  "Papua New Guinea",
  "Paraguay",
  "Peru",
  "Philippines",
  "Poland",
  "Portugal",
  "Qatar",
  "Republic of the Congo",
  "Romania",
  "Russia",
  "Rwanda",
  "Saint Kitts and Nevis",
  "Saint Lucia",
  "Saint Vincent and the Grenadines",
  "Samoa",
  "San Marino",
  u"São Tomé and Príncipe",
  "Saudi Arabia",
  "Senegal",
  "Serbia",
  "Seychelles",
  "Sierra Leone",
  "Singapore",
  "Slovakia",
  "Slovenia",
  "Solomon Islands",
  "Somalia",
  "South Africa",
  "South Korea",
  "South Sudan",
  "Spain",
  "Sri Lanka",
  "Sudan",
  "Suriname",
  "Swaziland",
  "Sweden",
  "Switzerland",
  "Syria",
  "Taiwan",
  "Tajikistan",
  "Tanzania",
  "Thailand",
  "Togo",
  "Tonga",
  "Trinidad and Tobago",
  "Tunisia",
  "Turkey",
  "Turkmenistan",
  "Tuvalu",
  "Uganda",
  "Ukraine",
  "United Arab Emirates",
  "United Kingdom",
  "Uruguay",
  "Uzbekistan",
  "Vanuatu",
  "Vatican City",
  "Venezuela",
  "Vietnam",
  "Western Sahara",
  "Yemen",
  "Zambia",
  "Zimbabwe",
}

aliased_countries = {
  "US": "USA",
  "U.S.": "USA",
  "U.S": "USA",
  "USA": "USA",
  "U.S.A.": "USA",
  "United States": "USA",
  "United States of America": "USA",
  "UK": "United Kingdom",
  "UAE": "United Arab Emirates",
  "North Macedonia": "North Macedonia",
  "Republic of North Macedonia": "North Macedonia",
  "Republic of Macedonia": "North Macedonia",
  "Congo": "Democratic Republic of the Congo",
  "Republic of Ireland": "Ireland",
  "Republic of Armenia": "Armenia",
}

countries_with_aliases = {x: x for x in countries}
countries_with_aliases.update(aliased_countries)

us_states = {
  "Alabama",
  "Alaska",
  "Arizona",
  "Arkansas",
  "California",
  "Colorado",
  "Connecticut",
  "Delaware",
  "Florida",
  "Georgia",
  "Hawaii",
  "Idaho",
  "Illinois",
  "Indiana",
  "Iowa",
  "Kansas",
  "Kentucky",
  "Louisiana",
  "Maine",
  "Maryland",
  "Massachusetts",
  "Michigan",
  "Minnesota",
  "Mississippi",
  "Missouri",
  "Montana",
  "Nebraska",
  "Nevada",
  "New Hampshire",
  "New Jersey",
  "New Mexico",
  "New York",
  "North Carolina",
  "North Dakota",
  "Ohio",
  "Oklahoma",
  "Oregon",
  "Pennsylvania",
  "Rhode Island",
  "South Carolina",
  "South Dakota",
  "Tennessee",
  "Texas",
  "Utah",
  "Vermont",
  "Virginia",
  "Washington",
  "West Virginia",
  "Wisconsin",
  "Wyoming",
}

canadian_provinces_and_territories = {
  "Alberta": "p",
  "British Columbia": "p",
  "Manitoba": "p",
  "New Brunswick": "p",
  "Newfoundland and Labrador": "p",
  "Northwest Territories": "terr",
  "Nova Scotia": "p",
  "Nunavut": "terr",
  "Ontario": "p",
  "Prince Edward Island": "p",
  "Saskatchewan": "p",
  "Quebec": "p",
  "Yukon": "terr",
}

australian_states_and_territories = {
  "New South Wales": "s",
  "Northern Territory": "terr",
  "Queensland": "s",
  "South Australia": "s",
  "Tasmania": "s",
  "Victoria": "s",
  "Western Australia": "s",
}

chinese_provinces_and_autonomous_regions = {
  "Anhui": "p",
  "Fujian": "p",
  "Gansu": "p",
  "Guangdong": "p",
  "Guangxi": "ar",
  "Guizhou": "p",
  "Hainan": "p",
  "Hebei": "p",
  "Heilongjiang": "p",
  "Henan": "p",
  "Hubei": "p",
  "Hunan": "p",
  "Inner Mongolia": "ar",
  "Jiangsu": "p",
  "Jiangxi": "p",
  "Jilin": "p",
  "Liaoning": "p",
  "Ningxia": "ar",
  "Qinghai": "p",
  "Shaanxi": "p",
  "Shandong": "p",
  "Shanxi": "p",
  "Sichuan": "p",
  "Tibet": "ar",
  "Xinjiang": "ar",
  "Yunnan": "p",
  "Zhejiang": "p",
}

japanese_prefectures = {
  "Aichi",
  "Akita",
  "Aomori",
  "Chiba",
  "Ehime",
  "Fukui",
  "Fukuoka",
  "Fukushima",
  "Gifu",
  "Gunma",
  "Hiroshima",
  "Hokkaido",
  u"Hyōgo",
  "Ibaraki",
  "Ishikawa",
  "Iwate",
  "Kagawa",
  "Kagoshima",
  "Kanagawa",
  u"Kōchi",
  "Kumamoto",
  "Kyoto",
  "Mie",
  "Miyagi",
  "Miyazaki",
  "Nagano",
  "Nagasaki",
  "Nara",
  "Niigata",
  u"Ōita",
  "Okayama",
  "Okinawa",
  "Osaka",
  "Saga",
  "Saitama",
  "Shiga",
  "Shimane",
  "Shizuoka",
  "Tochigi",
  "Tokushima",
  "Tottori",
  "Toyama",
  "Wakayama",
  "Yamagata",
  "Yamaguchi",
  "Yamanashi",
}

german_states = {
  u"Baden-Württemberg",
  "Bavaria",
  "Berlin",
  "Brandenburg",
  "Bremen",
  "Hamburg",
  "Hesse",
  "Lower Saxony",
  "Mecklenburg-Vorpommern",
  "North Rhine-Westphalia",
  "Rhineland-Palatinate",
  "Saarland",
  "Saxony",
  "Saxony-Anhalt",
  "Schleswig-Holstein",
  "Thuringia",
}

norwegian_counties = {
  u"Østfold",
  "Akershus",
  "Oslo",
  "Hedmark",
  "Oppland",
  "Buskerud",
  "Vestfold",
  "Telemark",
  "Aust-Agder",
  "Vest-Agder",
  "Rogaland",
  "Hordaland",
  "Sogn og Fjordane",
  u"Møre og Romsdal",
  "Nordland",
  "Troms",
  "Finnmark",
  u"Trøndelag",
}

finnish_regions = {
  "Lapland",
  "North Ostrobothnia",
  "Kainuu",
  "North Karelia",
  "Northern Savonia",
  "Southern Savonia",
  "South Karelia",
  "Central Finland",
  "South Ostrobothnia",
  "Ostrobothnia",
  "Central Ostrobothnia",
  "Pirkanmaa",
  "Satakunta",
  u"Päijänne Tavastia",
  "Tavastia Proper",
  "Kymenlaakso",
  "Uusimaa",
  "Southwest Finland",
  u"Åland Islands",
}

aliased_finnish_regions = {
  "Northern Ostrobothnia": "North Ostrobothnia",
  "Southern Ostrobothnia": "South Ostrobothnia",
  "North Savo": "Northern Savonia",
  "South Savo": "Southern Savonia",
  u"Päijät-Häme": u"Päijänne Tavastia",
  u"Kanta-Häme": "Tavastia Proper",
  u"Åland": u"Åland Islands",
}

finnish_regions_with_aliases = {x: x for x in finnish_regions}
finnish_regions_with_aliases.update(aliased_finnish_regions)

uk_constituents = {
  "England": "cc",
  "Scotland": "cc",
  "Wales": "cc",
  "Northern Ireland": "p",
}

english_counties = {
  "Avon", # no longer
  "Bedfordshire",
  "Berkshire",
  "Brighton and Hove", # city
  "Bristol", # city
  "Buckinghamshire",
  "Cambridgeshire",
  "Cambridgeshire and Isle of Ely", # no longer
  "Cheshire",
  "Cleveland", # no longer
  "Cornwall",
  "Cumberland",
  "Cumbria",
  "Derbyshire",
  "Devon",
  "Dorset",
  "County Durham",
  "Durham",
  "East Suffolk", # no longer
  "East Sussex",
  "Essex",
  "Gloucestershire",
  "Greater London",
  "Greater Manchester",
  "Hampshire",
  "Hereford and Worcester", # no longer
  "Herefordshire", 
  "Hertfordshire",
  "Humberside", # no longer
  "Huntingdon and Peterborough", # no longer
  "Huntingdonshire", # no longer
  "Isle of Ely", # no longer
  "Isle of Wight",
  "Kent",
  "Lancashire",
  "Leicestershire",
  "Lincolnshire",
  "County of London",
  "Merseyside",
  "Middlesex", # no longer
  "Norfolk",
  "Northamptonshire",
  "Northumberland",
  "North Humberside", # no longer
  "North Yorkshire",
  "Nottinghamshire",
  "Oxfordshire",
  "Soke of Peterborough", # no longer
  "Rutland",
  "Shropshire",
  "Somerset",
  "South Humberside",
  "South Yorkshire",
  "Staffordshire",
  "Suffolk",
  "Surrey",
  "Sussex", # no longer
  "Tyne and Wear",
  "Warwickshire",
  "West Midlands",
  "Westmorland", # no longer
  "West Suffolk", # no longer
  "West Sussex",
  "West Yorkshire",
  "Wiltshire",
  "Worcestershire",
  "Yorkshire", # no longer
  "East Riding of Yorkshire",
  "North Riding of Yorkshire", # no longer
  "West Riding of Yorkshire", # no longer
}

northern_ireland_counties = {
  "Antrim",
  "Armagh",
  "City of Belfast",
  "Down",
  "Fermanagh",
  "Londonderry",
  "City of Derry",
  "Tyrone",
}

scotland_council_areas = {
  "City of Glasgow",
  "City of Edinburgh",
  "Fife",
  "North Lanarkshire",
  "South Lanarkshire",
  "Aberdeenshire",
  "Highland",
  "City of Aberdeen",
  "West Lothian",
  "Renfrewshire",
  "Falkirk",
  "Perth and Kinross",
  "Dumfries and Galloway",
  "City of Dundee",
  "North Ayrshire",
  "East Ayrshire",
  "Angus",
  "Scottish Borders",
  "South Ayrshire",
  "East Dunbartonshire",
  "East Lothian",
  "Moray",
  "East Renfrewshire",
  "Stirling",
  "Midlothian",
  "West Dunbartonshire",
  "Argyll and Bute",
  "Inverclyde",
  "Clackmannanshire",
  "Na h-Eileanan Siar",
  "Shetland Islands",
  "Orkney Islands",
}

austrian_states = {
  "Vienna",
  "Lower Austria",
  "Upper Austria",
  "Styria",
  "Tyrol",
  "Carinthia",
  "Salzburg",
  "Vorarlberg",
  "Burgenland",
}

italian_regions = {
  "Abruzzo": "r",
  "Aosta Valley": "r",
  "Apulia": "r",
  "Basilicata": "r",
  "Calabria": "r",
  "Campania": "r",
  "Emilia-Romagna": "r",
  "Friuli-Venezia Giulia": "r",
  "Lazio": "r",
  "Liguria": "r",
  "Lombardy": "r",
  "Marche": "r",
  "Molise": "r",
  "Piedmont": "r",
  "Sardinia": "r",
  "Sicily": "r",
  "Trentino-Alto Adige": "r",
  "South Tyrol": "p",
  "Tuscany": "r",
  "Umbria": "r",
  "Veneto": "r",
}

indian_states_and_union_territories = {
  "Andaman and Nicobar Islands": "uterr",
  "Andhra Pradesh": "s",
  "Arunachal Pradesh": "s",
  "Assam": "s",
  "Bihar": "s",
  "Chandigarh": "uterr",
  "Chhattisgarh": "s",
  "Dadra and Nagar Haveli": "uterr",
  "Daman and Diu": "uterr",
  "Delhi": "uterr",
  "Goa": "s",
  "Gujarat": "s",
  "Haryana": "s",
  "Himachal Pradesh": "s",
  "Jammu and Kashmir": "uterr",
  "Jharkhand": "s",
  "Karnataka": "s",
  "Kerala": "s",
  "Ladakh": "uterr",
  "Lakshadweep": "uterr",
  "Madhya Pradesh": "s",
  "Maharashtra": "s",
  "Manipur": "s",
  "Meghalaya": "s",
  "Mizoram": "s",
  "Nagaland": "s",
  "Odisha": "s",
  "Puducherry": "uterr",
  "Punjab": "s",
  "Rajasthan": "s",
  "Sikkim": "s",
  "Tamil Nadu": "s",
  "Telangana": "s",
  "Tripura": "s",
  "Uttar Pradesh": "s",
  "Uttarakhand": "s",
  "West Bengal": "s",
}

philippine_provinces = {
  "Abra",
  "Agusan del Norte",
  "Agusan del Sur",
  "Aklan",
  "Albay",
  "Antique",
  "Apayao",
  "Aurora",
  "Basilan",
  "Bataan",
  "Batanes",
  "Batangas",
  "Benguet",
  "Biliran",
  "Bohol",
  "Bukidnon",
  "Bulacan",
  "Cagayan",
  "Camarines Norte",
  "Camarines Sur",
  "Camiguin",
  "Capiz",
  "Catanduanes",
  "Cavite",
  "Cebu",
  "Cotabato",
  "Davao de Oro",
  "Davao del Norte",
  "Davao del Sur",
  "Davao Occidental",
  "Davao Oriental",
  "Dinagat Islands",
  "Eastern Samar",
  "Guimaras",
  "Ifugao",
  "Ilocos Norte",
  "Ilocos Sur",
  "Iloilo",
  "Isabela",
  "Kalinga",
  "La Union",
  "Laguna",
  "Lanao del Norte",
  "Lanao del Sur",
  "Leyte",
  "Maguindanao",
  "Marinduque",
  "Masbate",
  "Misamis Occidental",
  "Misamis Oriental",
  "Mountain Province",
  "Negros Occidental",
  "Negros Oriental",
  "Northern Samar",
  "Nueva Ecija",
  "Nueva Vizcaya",
  "Occidental Mindoro",
  "Oriental Mindoro",
  "Palawan",
  "Pampanga",
  "Pangasinan",
  "Quezon",
  "Quirino",
  "Rizal",
  "Romblon",
  "Samar",
  "Sarangani",
  "Siquijor",
  "Sorsogon",
  "South Cotabato",
  "Southern Leyte",
  "Sultan Kudarat",
  "Sulu",
  "Surigao del Norte",
  "Surigao del Sur",
  "Tarlac",
  "Tawi-Tawi",
  "Zambales",
  "Zamboanga del Norte",
  "Zamboanga del Sur",
  "Zamboanga Sibugay",
  "Metro Manila",
}

irish_counties = {
  "Carlow",
  "Cavan",
  "Clare",
  "Cork",
  "Donegal",
  "Dublin",
  "Galway",
  "Kerry",
  "Kildare",
  "Kilkenny",
  "Laois",
  "Leitrim",
  "Limerick",
  "Longford",
  "Louth",
  "Mayo",
  "Meath",
  "Monaghan",
  "Offaly",
  "Roscommon",
  "Sligo",
  "Tipperary",
  "Waterford",
  "Westmeath",
  "Wexford",
  "Wicklow",
}

spanish_autonomous_communities = {
  "Andalusia",
  "Aragon",
  "Asturias",
  "Balearic Islands",
  "Basque Country",
  "Canary Islands",
  "Cantabria",
  u"Castile and León",
  "Castilla-La Mancha",
  "Catalonia",
  "Community of Madrid",
  "Extremadura",
  "Galicia",
  "La Rioja",
  "Murcia",
  "Navarre",
  "Valencia",
}

roman_provinces = {
  # only include cases that are more or less unambiguously provinces rather than regions
  "Hispania Baetica",
  "Hispania Tarraconensis",
  "Lusitania",
  "Gallia Narbonensis",
  "Gallia Cisalpina",
  "Gallia Belgica",
  "Britannia",
  "Aquitania",
  "Latium",
  "Pannonia",
}

# "mentioned by Pliny", "mentioned by Arrian" etc.
ancient_mentioned_regions = {
  "Arabia",
  "Bithynia",
  "Mauritania",
  "Caria",
  "Mysia",
  "India",
  "Pontus",
  "Cilicia",
  "Aeolis",
  "Syria",
  "Asia",
  "Lycia",
  "Ionia",
  "Mesopotamia",
  "Phoenicia",
  "Thrace",
  "Africa",
  # "Ganges",
  # "Iazyges",
  "Gedrosia",
  "Carmania",
  "Numidia",
  "Phrygia",
  "Sarmatia",
  "Hyrcania",
  "India",
  # "Elymais",
  "Persia",
  "Cyrenaica",
  "Albania",
  "Cyprus",
  "Armenia",
  "Crete",
  "Ariana",
  "Tauric Chersonesus",
  "Macedonia",
  "Aetolia",
  "Assyria",
  "Germany",
  "Paphlagonia",
  "Susiana",
  "Dalmatia",
}

aliased_ancient_mentioned_regions = {
  "Lybia": "Libya",
  "Mauritania": "Mauretania",
  "Asian Scythia": "Scythia",
  "Bactriana": "Bactria",
}

ancient_mentioned_regions_with_aliases = {x: x for x in ancient_mentioned_regions}
ancient_mentioned_regions_with_aliases.update(aliased_ancient_mentioned_regions)

misc_places = {
  "London": "city",
  "Sydney": "city",
  "Melbourne": "city",
  "Perth": "city",
  "Beijing": "city",
  "Calgary": "city",
  "Liverpool": "city",
  "New York City": "city",
  "Glasgow": "city",
  "San Francisco": "city",
  "Edmonton": "city",
  "Manhattan": "bor",
  "Oaxaca": "s",
  "Scandinavia": "r",
  "Bohemia": "r",
  "Moravia": "r",
  # ancient and historical regions
  "Lucania": "r",
  "Cilicia": "r",
  "Cappadocia": "r",
  "Phoenicia": "r",
  "Anatolia": "r",
  "Mesopotamia": "r",
  "Aetolia": "r",
  "Etruria": "r",
  "Mysia": "r",
  "Dalmatia": "r", # also a Roman province
  "Slavonia": "r",
  "Istria": "r", # also a peninsula
  # "Attica": ambiguously ancient region/peninsula, modern administrative region of Greece
  # "Thessaly": ambiguously ancient region, modern administrative region of Greece
  # "Epirus": ambiguously ancient region, modern administrative region of Greece
  # "Crete": ambiguously ancient island, modern administrative region of Greece
  # "Peloponnese": ambiguously ancient island, modern administrative region of Greece
  # "Boeotia": ambiguously ancient region, modern regional unit of Greece
  # "Euboea": ambiguously ancient island, modern regional unit of Greece
  # "Arcadia": ambiguously ancient region, modern regional unit of Greece
  # "Laconia": ambiguously ancient region, modern regional unit of Greece
  # "Crimea": ambiguously ancient region/peninsula, modern autonomous republic of Ukraine, modern republic of Russia
  # "Numidia": ambiguously ancient kingdom, Roman province
  # "Bithynia": ambiguously ancient region and kingdom, later part of the Roman province of Bithynia et Pontus
  # "Pontus": ambiguously ancient region and kingdom, later part of the Roman province of Bithynia et Pontus
}

unrecognized_place_types = defaultdict(int)
recognized_place_types = defaultdict(int)
unrecognized_holonyms = defaultdict(int)
recognized_holonyms = defaultdict(int)
recognized_lines = 0
unparsable_lines = 0
unrecognized_placetype_lines = 0
unrecognized_holonym_lines = 0
multiple_repls_lines = 0
total_lines = 0
total_parsable_lines = 0

def output_stats(num_counts):
  msg("Recognized lines: %s (%.2f%% of parsable)" % (recognized_lines, (100.0 * recognized_lines) / total_parsable_lines))
  msg("Unrecognized placetype lines: %s (%.2f%% of parsable)" % (unrecognized_placetype_lines, (100.0 * unrecognized_placetype_lines) / total_parsable_lines))
  msg("Unrecognized holonym lines: %s (%.2f%% of parsable)" % (unrecognized_holonym_lines, (100.0 * unrecognized_holonym_lines) / total_parsable_lines))
  msg("Lines with multiple repls the same: %s (%.2f%% of parsable)" % (multiple_repls_lines, (100.0 * multiple_repls_lines) / total_parsable_lines))
  msg("Unparsable lines: %s (%.2f%% of total)" % (unparsable_lines, (100.0 * unparsable_lines) / total_lines))
  def output_counts(dic):
    by_count = sorted(dic.items(), key=lambda x:-x[1])
    by_count = by_count[0:num_counts]
    for k, v in by_count:
      msg("%s = %s" % (k, v))
  msg("Unrecognized place types:")
  msg("-------------------------")
  output_counts(unrecognized_place_types)
  msg("Unrecognized holonyms:")
  msg("----------------------")
  output_counts(unrecognized_holonyms)
  msg("Recognized place types:")
  msg("-------------------------")
  output_counts(recognized_place_types)
  msg("Recognized holonyms:")
  msg("----------------------")
  output_counts(recognized_holonyms)

proper_noun_word_regex = r"(?u)[A-Z][\w'.-]*"
# The following regex requires that the first word of a county/parish/borough name be capitalized
# and contain only letters, hyphens (Stratford-on-Avon), apostrophes (King's Lynn) and periods
# (St. Louis), and remaining words must either be of the same format or be "and" (Tyne and Wear,
# Lewis and Clark), "of" (Isle of Wight), or "of the". This should catch cases like
# -- co/Missouri which is one of the two county seats of Jackson County
# -- co/Han dynasty southwest of Xiyang County
proper_noun_regex = "(?:%s)(?: %s| and| of| of the| de| upon)*" % (proper_noun_word_regex, proper_noun_word_regex)

def parse_holonym(holonym):
  # US
  m = re.search("^%s (County|Parish|Borough)$" % proper_noun_regex, holonym)
  if m:
    placetype = {"County": "co", "Parish": "par", "Borough": "bor"}[m.group(1)]
    return "%s/%s" % (placetype, m.group(0))
  if holonym in us_states:
    # Do states before countries because of Georgia.
    return "s/" + holonym
  normalized_holonym = re.sub(" [Ss]tate$", "", holonym)
  if normalized_holonym in us_states:
    return "s/" + normalized_holonym
  # UK
  if holonym in uk_constituents:
    return "%s/%s" % (uk_constituents[holonym], holonym)
  if holonym in english_counties:
    return "co/" + holonym
  if holonym in northern_ireland_counties:
    return "co/" + holonym
  normalized_holonym = re.sub("^[Cc]ounty ", "", holonym)
  if normalized_holonym in northern_ireland_counties:
    return "co/" + normalized_holonym
  if holonym in scotland_council_areas:
    return "council area/" + holonym
  normalized_holonym = re.sub(" [Cc]ouncil [Aa]rea$", "", holonym)
  if normalized_holonym in scotland_council_areas:
    return "council area/" + normalized_holonym
  normalized_holonym = re.sub(" [Cc]ouncil [Aa]rea of Scotland$", "", holonym)
  if normalized_holonym in scotland_council_areas:
    return ["council area/" + normalized_holonym, "cc/Scotland"]
  coded_place_type_regex = "|".join(re.escape(x) for x in place_types_to_codes.keys())
  m = re.search("^(%s) (%s)$" % (proper_noun_regex, coded_place_type_regex), holonym)
  if m:
    bare_holonym, placetype = m.groups()
    return "%s/%s" % (place_types_to_codes[placetype], bare_holonym)
  m = re.search("^(%s) (?:of +)?(%s)$" % (coded_place_type_regex, proper_noun_regex), holonym)
  if m:
    placetype, bare_holonym = m.groups()
    return "%s/%s" % (place_types_to_codes[placetype], bare_holonym)
  # Borough of Ealing, Borough of Slough, Borough of Tower Hamlets, Borough of Hinckley and Bosworth,
  # borough of Chesterfield, borough of North Tyneside, etc.
  m = re.search("^[Bb]orough of (%s)$" % proper_noun_regex, holonym)
  if m:
    return "bor/%s" % m.group(1)
  m = re.search("^[Mm]etropolitan [Bb]orough of (%s)$" % proper_noun_regex, holonym)
  if m:
    return "metbor/%s" % m.group(1)
  # city of Manchester, city of Sydney, city of Fremont (California), city of Thunder Bay (Ontario), etc.
  # NOTE: capitalized City can refer to other things, e.g. City of Melville (local government area)
  m = re.search("^city of (%s)$" % proper_noun_regex, holonym)
  if m:
    return "city/%s" % m.group(1)
  # countries
  if holonym in countries_with_aliases:
    return "c/" + countries_with_aliases[holonym]
  # continents
  if holonym in continents:
    return "cont/" + holonym
  # regions
  if holonym in regions_with_aliases:
    return "r/" + regions_with_aliases[holonym]
  # Australia
  if holonym in australian_states_and_territories:
    return "%s/%s" % (australian_states_and_territories[holonym], holonym)
  # Austria
  if holonym in austrian_states:
    return "s/%s" % holonym
  # Canada
  if holonym in canadian_provinces_and_territories:
    return "%s/%s" % (canadian_provinces_and_territories[holonym], holonym)
  # China
  if holonym in chinese_provinces_and_autonomous_regions:
    return "%s/%s" % (chinese_provinces_and_autonomous_regions[holonym], holonym)
  normalized_holonym = re.sub(" ([Pp]rovince|[Aa]utonomous [Rr]egion)$", "", holonym)
  if normalized_holonym in chinese_provinces_and_autonomous_regions:
    return "%s/%s" % (chinese_provinces_and_autonomous_regions[normalized_holonym], normalized_holonym)
  # Finland
  if holonym in finnish_regions_with_aliases:
    return "r/" + finnish_regions_with_aliases[holonym]
  normalized_holonym = re.sub("^region of ", "", holonym)
  if normalized_holonym in finnish_regions_with_aliases:
    return "r/" + finnish_regions_with_aliases[normalized_holonym]
  # France
  if m:
    return "dept/%s" % m.group(1)
  m = re.search(u"^(%s) (?:department|département) of France$" % proper_noun_regex, holonym)
  if m:
    return ["dept/%s" % m.group(1), "c/France"]
  # Germany
  if holonym in german_states:
    return "s/%s" % holonym
  # India
  if holonym in indian_states_and_union_territories:
    return "%s/%s" % (indian_states_and_union_territories[holonym], holonym)
  normalized_holonym = re.sub("^(Indian )?state of ", "", holonym)
  if normalized_holonym in indian_states_and_union_territories:
    return "%s/%s" % (indian_states_and_union_territories[normalized_holonym], normalized_holonym)
  # Ireland
  if holonym in irish_counties:
    return "co/" + holonym
  normalized_holonym = re.sub("^[Cc]ounty ", "", holonym)
  if normalized_holonym in irish_counties:
    return "co/" + normalized_holonym
  # Italy
  if holonym in italian_regions:
    return "%s/%s" % (italian_regions[holonym], holonym)
  # Check for "Perugia province of Umbria". Allow "the" before region name because of "the Veneto".
  m = re.search("^(%s) province of (?:the )?(%s)$" % (proper_noun_regex, proper_noun_regex), holonym)
  if m and m.group(2) in italian_regions:
    return ["p/%s" % m.group(1), "%s/%s" % (italian_regions[m.group(2)], m.group(2))]
  # Japan
  if holonym in japanese_prefectures:
    return "pref/%s" % holonym
  normalized_holonym = re.sub(" ([Pp]refecture)$", "", holonym)
  if normalized_holonym in japanese_prefectures:
    return "pref/%s" % normalized_holonym
  # Norway
  if holonym in norwegian_counties:
    return "co/%s" % holonym
  normalized_holonym = re.sub(" county$", "", holonym)
  if normalized_holonym in norwegian_counties:
    return "co/%s" % normalized_holonym
  # Philippines
  if holonym in philippine_provinces:
    return "p/%s" % holonym
  # Spain
  if holonym in spanish_autonomous_communities:
    return "acomm/%s" % holonym
  # Ancient Rome, etc.
  if holonym in roman_provinces:
    return "p/%s" % holonym
  m = re.search("^(%s) (mentioned by .*)$" % proper_noun_regex, holonym)
  if m:
    normalized_holonym, mentioned_by = m.groups()
    if normalized_holonym in ancient_mentioned_regions_with_aliases:
      return ["r/%s" % ancient_mentioned_regions_with_aliases[normalized_holonym], mentioned_by]
  # Misc places
  if holonym in misc_places:
    return "%s/%s" % (misc_places[holonym], holonym)
  m = re.search("^(%s) Sea$" % proper_noun_regex, holonym)
  if m:
    return "sea/%s" % holonym
  m = re.search("^(%s) (district|region|canton|borough|province) of (?:the )?(%s)$" % (proper_noun_regex, proper_noun_regex),
    holonym)
  if m:
    subdiv, subdiv_type, div = m.groups()
    div_holonym = parse_holonym(div)
    if div_holonym:
      if type(div_holonym) is not list:
        div_holonym = [div_holonym]
      return ["%s/%s" % (place_types_to_codes[subdiv_type], subdiv)] + div_holonym
  return None

class DoubleReplException(Exception):
  pass

def strip_wikicode(text, record_links_dict, pagemsg):
  def record_link(m, replnum):
    orig = m.group(0)
    repl = m.group(replnum)
    if record_links_dict is not None:
      if repl in record_links_dict:
        pagemsg("WARNING: Saw holonym %s twice with links (original %s)" % (repl, orig))
        raise DoubleReplException
      record_links_dict[repl] = orig
    return repl
  def record_link_1(m):
    return record_link(m, 1)
  def record_link_2(m):
    return record_link(m, 2)
  try:
    text = re.sub(r"(''+)(.*?)\1", record_link_2, text)
    text = re.sub(r"\{\{l\|(?:en|n[bno])\|(?:[^{}|\[\]]*?\|)?([^{}|\[\]]+?)\}\}", record_link_1, text)
    text = re.sub(r"\{\{w\|(?:[^{}|\[\]]*?\|)?([^{}|\[\]]+?)\}\}", record_link_1, text)
    text = re.sub(r"\[\[w:(?:[^{}|\[\]]*?\|)?([^{}|\[\]]+?)\]\]", record_link_1, text)
    text = re.sub(r"\[\[(?:[^{}|\[\]]*?\|)?([^{}|\[\]]+?)\]\]", record_link_1, text)
  except DoubleReplException:
    return None
  return text

def restore_links(text, record_links_dict, pagemsg, wikipedia_only=False):
  # Put back original links. Abort if anything goes wrong (e.g. two replacements when one expected).
  for repl, orig in record_links_dict.iteritems():
    if repl in text and (not wikipedia_only or re.search(r"^\{\{w\||\[\[w:", orig)):
      text, did_replace = blib.replace_in_text(text, repl, orig, pagemsg, abort_if_warning=True)
      if not did_replace:
        return None
  return text

def remove_links_from_topics(text):
  def remove_links(m):
    return blib.remove_links(m.group(0))
  return re.sub(r"\{\{(topics|topic|top|C|c)\|.*?\}\}", remove_links, text)

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  origtext = text
  notes = []
  if index % 250000 == 0:
    output_stats(100)
  if re.search("^[a-z]", pagetitle):
    return text, notes
  def templatize_place_line(m, langcode):
    global recognized_lines
    global unparsable_lines
    global unrecognized_placetype_lines
    global unrecognized_holonym_lines
    global multiple_repls_lines
    global total_lines
    global total_parsable_lines
    total_lines += 1
    origline = m.group(0)
    linelen = len(origline)
    if linelen > 5000:
      # Page 4967143 [[Module:User:IsomorphycSandbox/testmodule/reverse index]] is over 1,000,000 chars in length,
      # and the script gets stuck as the loop below that successively chops off endings is O(N^2) in the number
      # of segments.
      pagemsg("Skipping overly long line (%s chars): %s..." % (linelen, origline[0:5000]))
      return origline
    line = origline
    postline = ""
    status = None
    badlines = []
    def append_pagemsg(txt):
      newline = "Page %s %s: %s: <from> %s <to> %s <end>" % (
          index, pagetitle, txt, origline, origline)
      if newline not in badlines:
        badlines.append(newline)
    this_unrecognized_place_types = set()
    this_recognized_place_types = set()
    this_unrecognized_holonyms = set()
    this_recognized_holonyms = set()
    def add_this_to_all():
      for pt in this_unrecognized_place_types:
        unrecognized_place_types[pt] += 1
      for pt in this_recognized_place_types:
        recognized_place_types[pt] += 1
      for h in this_unrecognized_holonyms:
        unrecognized_holonyms[h] += 1
      for h in this_recognized_holonyms:
        recognized_holonyms[h] += 1
    while True: # Loop over smaller sections of the line, chopping from the right
      while True: # "Loop" to simulate goto with break
        record_links_dict = {}
        cap_officials = []

        # Check for and strip off capital, official name, county/parish/borough seat
        chopped_line = strip_wikicode(line, record_links_dict, append_pagemsg)
        if chopped_line is None:
          status = "multiple repls"
          multiple_repls_lines += 1
          break
        while True:
          m = re.search(r"^(.*[^,.;: ])[,.;:] *(?:[Tt]he +|[Ii]t'?s +)?([Cc]apital|[Oo]fficial [Nn]ame|[Cc]ounty [Ss]eat|[Pp]arish [Ss]eat|[Bb]orough [Ss]eat)(?: +[Ii]s(?: +in)?)?:? *(?:[Tt]he +)?(%s)(?<!\.) *[,.;:]? *$" % proper_noun_regex, chopped_line)
          if m:
            chopped_line, cap_official_type, cap_official_name = m.groups()
            cap_official_type = cap_official_type.lower()
            if cap_official_type == "capital":
              cap_official_param = "capital"
            elif cap_official_type == "official name":
              cap_official_param = "official"
            else:
              cap_official_param = "seat"
            cap_officials.append((cap_official_param, cap_official_name))
          else:
            break

        m = re.search(r"^(#+ *(?:\{\{.*?\}\})? *)[Aa]n? +([^{}|\n]*?) +(?:located in|situated in|in|of) +(?:the +)?(.*?)((?: *\{\{q\|[^{}]*?\}\})?) *[,.;:]? *$", chopped_line)
        if m:
          pretext, placetype, holonyms, postq = m.groups()
          trans = None
        else:
          m = re.search(r"^(#+ *(?:\{\{(?:[^lw]|[lw][^|])[^{}]*?\}\} *)*)([^()]+?) *(?:\(|\{\{gloss\|)(?:[Tt]he |[Aa]n? )?([^{}|\n]*?) +(?:located in|situated in|in|of) +(?:the +)?(.*?)(?:\)|\}\})((?: *\{\{q\|[^{}]*?\}\})?)\.?$", chopped_line)
          if m:
            pretext, trans, placetype, holonyms, postq = m.groups()
          else:
            status = status or "unparsable"
            #append_pagemsg("WARNING: Unable to parse line")
            break
        pretext = restore_links(pretext, record_links_dict, append_pagemsg)
        if pretext is None:
          status = "multiple repls"
          multiple_repls_lines += 1
          break
        # restore_links may wrongly add bare links inside of {{topics}} etc. if the same bare links occur elsewhere.
        # The following hack corrects this.
        pretext = remove_links_from_topics(pretext)
        postq = restore_links(postq, record_links_dict, append_pagemsg)
        if postq is None:
          status = "multiple repls"
          multiple_repls_lines += 1
          break
        postq = remove_links_from_topics(postq)
        if trans:
          if not re.search("^(?:the )?%s$" % proper_noun_regex, trans):
            status = status or "unparsable"
            append_pagemsg("WARNING: Bad format for translation '%s'" % trans)
            break
        split_placetype = re.split("(?:/| and (?:the |an? )?)", placetype)
        split_placetype_with_qual = []
        outer_break = False
        for pt in split_placetype:
          pt_qual = None
          if pt not in place_types_with_aliases:
            m = re.search("^(%s) (.*)$" % "|".join(re.escape(x) for x in place_qualifiers_with_aliases.keys()), pt)
            if m:
              pt_qual, pt = m.groups()
              pt_qual = place_qualifiers_with_aliases[pt_qual]
            if pt not in place_types_with_aliases:
              this_unrecognized_place_types.add(pt)
              append_pagemsg("WARNING: Unable to recognize stripped placetype '%s'" % pt)
              status = status or "bad placetype"
              outer_break = True
              break
          split_placetype_with_qual.append((pt_qual, pt))
          this_recognized_place_types.add(pt)
          if pt_qual:
            this_recognized_place_types.add("%s %s" % (pt_qual, pt))
        if outer_break:
          break
        holonyms = re.sub(",? *(?:and |(?:that|which) is )?(?:the )?(county|parish|borough) seat of ", r", \1 seat, ", holonyms)
        # Handle "A city in and the county seat of ...".
        m = re.search("^, (county|parish|borough) seat, (.*)$", holonyms)
        if m:
          split_placetype_with_qual.append((None, "%s seat" % m.group(1)))
          holonyms = m.group(2)
        holonyms = re.sub(",? in (?:the )?", ", ", holonyms)
        holonyms = re.split(", *", holonyms)
        parsed_holonyms = []

        def add_to_parsed_holonyms(parsed_holonym):
          if type(parsed_holonym) is list:
            parsed_holonyms.extend(parsed_holonym)
            for ph in parsed_holonym:
              this_recognized_holonyms.add(ph)
          else:
            parsed_holonyms.append(parsed_holonym)
            this_recognized_holonyms.add(parsed_holonym)

        outer_break = False
        for holonym in holonyms:
          if holonym in ["county seat", "parish seat", "borough seat"]:
            add_to_parsed_holonyms(";")
            add_to_parsed_holonyms(holonym)
          else:
            parsed_holonym = parse_holonym(holonym)
            if parsed_holonym:
              add_to_parsed_holonyms(parsed_holonym)
            else:
              m = re.search("^(%s) (?:the )?(.*)$" % "|".join(re.escape(x) for x in compass_points_with_aliases.keys()), holonym)
              if m:
                compass_point, base_holonym = m.groups()
                parsed_holonym = parse_holonym(base_holonym)
                if parsed_holonym:
                  add_to_parsed_holonyms("in " + compass_points_with_aliases[compass_point])
                  add_to_parsed_holonyms(parsed_holonym)
                else:
                  status = status or "bad holonym"
                  this_unrecognized_holonyms.add(base_holonym)
                  append_pagemsg("WARNING: Unable to recognize stripped holonym '%s'" % base_holonym)
                  outer_break = True
                  break
              else:
                status = status or "bad holonym"
                this_unrecognized_holonyms.add(holonym)
                append_pagemsg("WARNING: Unable to recognize stripped holonym '%s'" % holonym)
                outer_break = True
                break
        if outer_break:
          break

        def normalize_placetype(pt_qual, pt):
          pt_qual_text = pt_qual + " " if pt_qual else ""
          return pt_qual_text + place_types_with_aliases[pt]
        normalized_placetype = "/".join(normalize_placetype(pt_qual, pt) for pt_qual, pt in split_placetype_with_qual)
        if not normalized_placetype or not parsed_holonyms:
          break

        placeargs = [normalized_placetype] + parsed_holonyms
        # Now, split place args by semicolon-separated "runs".
        place_args_runs = []
        place_args_run = []
        for arg in placeargs:
          if arg == ";":
            if place_args_run:
              place_args_runs.append(place_args_run)
            place_args_run = []
          else:
            place_args_run.append(arg)
        if place_args_run:
          place_args_runs.append(place_args_run)

        # Loop over runs.
        outer_break = False
        for run in place_args_runs:
          # Check for missing holonym. Currently can only happen with special code
          # that converts "county seat" holonyms into placetypes.
          if len(run) == 1:
            append_pagemsg("WARNING: Missing holonym")
            status = status or "bad holonym"
            outer_break = True
            break

          # Check for same holonym placetype occurring twice (e.g. due to a "foo, bar and baz" list).
          seen_holonym_placetypes = {}
          inner_break = False
          for holonym in run[1:]:
            if "/" not in holonym:
              continue
            holonym_placetype, holonym_placename = holonym.split("/")
            if holonym_placetype in seen_holonym_placetypes:
              append_pagemsg("WARNING: Saw holonym placetype twice in %s and %s" % (
                seen_holonym_placetypes[holonym_placetype], holonym))
              status = status or "bad holonym"
              inner_break = True
              outer_break = True
              break
            seen_holonym_placetypes[holonym_placetype] = holonym
          if inner_break:
            break

          # If country occurs before country subdivision, switch them. If multiple country subdivisions
          # follow, the country will bubble to the end.
          for i in xrange(2, len(run)):
            if re.search("^(c|cc)/", run[i - 1]) and (
              re.search("^(p|s|bor|cobor|metbor|can|co|dist|div|dept|isl|mun|pref|city|town)/", run[i])
            ) or run[i - 1].startswith("c/") and run[i].startswith("cc/"):
              # Look for "in ..." preceding the country and swap it too.
              if i > 2 and run[i - 2].startswith("in "):
                temp = run[i]
                run[i] = run[i - 1]
                run[i - 1] = run[i - 2]
                run[i - 2] = temp
              else:
                temp = run[i]
                run[i] = run[i - 1]
                run[i - 1] = temp

          # If country is followed by region or sea, insert "in".
          if len(run) >= 3 and re.search("^(c|cc)/", run[-2]) and re.search("^(r|sea)/", run[-1]):
            run[-1:-1] = ["in"]

        if outer_break:
          break

        # Now rejoin runs into place_args.
        place_args = []
        outer_break = False
        for run in place_args_runs:
          placetype = run[0]
          holonyms = "|".join(run[1:])
          holonyms = restore_links(holonyms, record_links_dict, append_pagemsg, wikipedia_only=True)
          if holonyms is None:
            status = "multiple repls"
            multiple_repls_lines += 1
            outer_break = True
            break
          if place_args:
            place_args.append(";")
          place_args.append(placetype)
          place_args.append(holonyms)
        if outer_break:
          break

        # Construct new place template.
        joined_place_args = "|".join(place_args)
        cap_official_params = []
        for param, val in cap_officials:
          cap_official_params.append("|%s=%s" % (param, val))
        cap_official_str = "".join(cap_official_params)
        cap_official_str = restore_links(cap_official_str, record_links_dict, append_pagemsg,
            wikipedia_only=True)
        if cap_official_str is None:
          status = "multiple repls"
          multiple_repls_lines += 1
          break
        if trans:
          trans = restore_links(trans, record_links_dict, append_pagemsg, wikipedia_only=True)
          if trans is None:
            status = "multiple repls"
            multiple_repls_lines += 1
            break
        new_place_template = "{{place|%s|%s%s%s}}" % (langcode, joined_place_args, cap_official_str,
            "|t1=%s" % trans if trans else "")

        # Construct entire line and return it.
        retval = "%s%s%s%s" % (pretext, new_place_template, postq, postline)
        notes.append("templatize %s place spec into {{place}}" % placetype)
        pagemsg("Replaced <%s> with <%s>" % (origline, retval))
        recognized_lines += 1
        total_parsable_lines += 1
        add_this_to_all()
        return retval

      m = re.search("^(.*[^ ])( *[,.:;] +.+?| *\{\{[^{}]*\}\}.*?)$", line)
      if m:
        line, this_postline = m.groups()
        postline = this_postline + postline
      else:
        if status == "unparsable":
          unparsable_lines += 1
        else:
          total_parsable_lines += 1
          if status == "bad placetype":
            unrecognized_placetype_lines += 1
          elif status == "bad holonym":
            unrecognized_holonym_lines += 1
          elif status == "multiple repls":
            multiple_repls_lines += 1
          else:
            assert False
        add_this_to_all()
        for m in badlines:
          msg(m)
        return origline

  sections = re.split("(^==[^\n=]*==\n)", text, 0, re.M)
  for j in xrange(2, len(sections), 2):
    m = re.search("^==(.*)==\n$", sections[j - 1])
    assert m
    langname = m.group(1)
    if langname not in blib.languages_byCanonicalName:
      pagemsg("WARNING: Unrecognized language %s" % langname)
    else:
      langcode = blib.languages_byCanonicalName[langname]["code"]
      def do_templatize_place_line(m):
        return templatize_place_line(m, langcode)
      sections[j] = re.sub(r"^.*(%s).*$" % "|".join(re.escape(x) for x in place_types_with_aliases.keys()),
        do_templatize_place_line, sections[j], 0, re.M)
  return "".join(sections), notes

parser = blib.create_argparser("Templatize place specs into {{place}}",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--linefile", help="File containing lines output by find_regex.py")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.linefile:
  linefile = args.linefile.decode("utf-8")
  lines = codecs.open(linefile, "r", encoding="utf-8")
  for index, line in blib.iter_items(lines, start, end):
    m = re.search("^Page [0-9]+ (.*): Found match for regex: (.*\n)$", line)
    if not m:
      msg("Can't parse line: %s" % line.strip())
    else:
      process_text_on_page(index, m.group(1), m.group(2))
else:
  blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
output_stats(5000)
