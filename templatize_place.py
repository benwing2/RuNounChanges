#!/usr/bin/env python
# -*- coding: utf-8 -*-

# FIXME:
#
# 1. Check L2 header for language and use in place of 'en'.
# 2. Need to preserve some links, e.g. probably at least in the translation.

from collections import defaultdict

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

blib.getData()

place_types = [
  # city
  "city",
  "small city",
  "large city",
  "major city",
  "tiny city",
  "prefecture-level city",
  "county-level city",
  "sub-provincial city",
  "former city",
  "ancient city",
  "independent city",
  "home-rule city",
  "port city",
  "coastal city",
  "resort city",
  # town
  "town",
  "small town",
  "large town",
  "ghost town",
  "submerged ghost town",
  "former town",
  "incorporated town",
  "unincorporated town",
  "market town",
  "small market town",
  "town with bystatus",
  "coastal town",
  "small coastal town",
  "seaside town",
  "harbour town",
  "harbor town",
  "ancient town",
  "statutory town",
  "suburban town",
  "spa town",
  "resort town",
  "township",
  "rural township",
  # village
  "village",
  "small village",
  "large village",
  "former village",
  "unincorporated village",
  # hamlet
  "hamlet",
  # settlement
  "settlement",
  "former settlement",
  "small settlement",
  # municipality
  "municipality",
  "home-rule municipality",
  "rural municipality",
  "former municipality",
  "island municipality",
  "municipality with city status",
  # census-designated place
  "census-designated place",
  "unincorporated census-designated place",
  # community
  "community",
  "small community",
  "former community",
  "unincorporated community",
  "small unincorporated community",
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
  "small borough",
  "large borough",
  "metropolitan borough",
  "county borough",
  # area
  "area",
  "unincorporated area",
  "residential area",
  "suburban area",
  "inner-city area",
  "urban area",
  # neighborhood
  "neighborhood",
  "neighbourhood",
  # seat
  "county seat",
  "parish seat",
  "borough seat",
  # capital
  "capital",
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
  "small river",
  "large river",
  "major river",
  "minor river",
  "short river",
  "long river",
  # misc. water
  "lake",
  "small lake",
  "large lake",
  "bay",
  # larger divisions
  "county",
  "former county",
  "ancient county",
  "administrative county",
  "parish",
  "state",
  "former state",
  "ancient state",
  "province",
  "former province",
  "associated province",
  "country",
  "small country",
  "large country",
  "former country",
  "island country",
  "historic county",
  "prefecture",
  "subprefecture",
  "inland prefecture",
  "island",
  "small island",
  "large island",
  "group of islands",
  "chain of islands",
  "peninsula",
  "region",
  "geographical region",
  "historical region",
  "mountainous region",
  "ancient region",
]

aliased_place_types = {
  "CDP": "census-designated place",
  "home rule municipality": "home-rule municipality",
  "home rule city": "home-rule city",
  "home rule class city": "home-rule city",
  "home rule-class city": "home-rule city",
  "home-rule class city": "home-rule city",
  "home-rule-class city": "home-rule city",
  "town (with bystatus)": "town with bystatus",
  "city located": "city",
  "extinct town": "former town",
  "inner city area": "inner-city area",
  "earlier municipality": "former municipality",
  "river that flows": "river",
  "small river that flows": "small river",
  "comune": "commune",
}

place_types_with_aliases = {x: x for x in place_types}
place_types_with_aliases.update(aliased_place_types)

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
  "USA": "USA",
  "U.S.A.": "USA",
  "United States": "USA",
  "United States of America": "USA",
  "UK": "United Kingdom",
  "UAE": "United Arab Emirates",
  "North Macedonia": "North Macedonia",
  "Republic of North Macedonia": "North Macedonia",
  "Macedonia": "North Macedonia",
  "Congo": "Democratic Republic of the Congo",
  "Republic of Ireland": "Ireland",
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

roman_provinces = {
  "Hispania Baetica",
  "Gallia Narbonensis",
  "Hispania Tarraconensis",
  "Latium",
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
  "Andra Pradesh": "s",
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

unrecognized_place_types = defaultdict(int)
unrecognized_holonyms = defaultdict(int)
recognized_lines = 0
unparsable_lines = 0
unrecognized_placetype_lines = 0
unrecognized_holonym_lines = 0
total_lines = 0
total_parsable_lines = 0

def output_stats(num_counts):
  msg("Recognized lines: %s (%.2f%% of parsable)" % (recognized_lines, (100.0 * recognized_lines) / total_parsable_lines))
  msg("Unrecognized placetype lines: %s (%.2f%% of parsable)" % (unrecognized_placetype_lines, (100.0 * unrecognized_placetype_lines) / total_parsable_lines))
  msg("Unrecognized holonym lines: %s (%.2f%% of parsable)" % (unrecognized_holonym_lines, (100.0 * unrecognized_holonym_lines) / total_parsable_lines))
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

def parse_holonym(holonym):
  # US
  # The following regex requires that the first word of a county/parish/borough name be capitalized
  # and contain only letters, hyphens (Stratford-on-Avon) and apostrophes (King's Lynn), and
  # remaining words must either be of the same format or be "and" (Tyne and Wear, Lewis and Clark),
  # "of" (Isle of Wight), or "of the". Ths should catch cases like
  # -- co/Missouri which is one of the two county seats of Jackson County
  # -- co/Han dynasty southwest of Xiyang County
  m = re.search("^(?:[A-Z][A-Za-z'-]*)(?: [A-Z][A-Za-z'-]*| and| of| of the)* (County|Parish|Borough)$", holonym)
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
  # Same regex as above for counties.
  m = re.search("^((?:[A-Z][A-Za-z'-]*)(?: [A-Z][A-Za-z'-]*| and| of| of the)*) (district|county borough|borough)$", holonym)
  if m:
    placetype = {"district": "dist", "county borough": "cobor", "borough": "bor"}[m.group(2)]
    return "%s/%s" % (placetype, m.group(1))
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
  # Germany
  if holonym in german_states:
    return "s/%s" % holonym
  # India
  if holonym in indian_states_and_union_territories:
    return "%s/%s" % (indian_states_and_union_territories[holonym], holonym)
  normalized_holonym = re.sub("^(Indian )?state of ", "", holonym)
  if normalized_holonym in indian_states_and_union_territories:
    return "%s/%s" % (indian_states_and_union_territories[normalized_holonym], normalized_holonym)
  # Italy
  if holonym in italian_regions:
    return "%s/%s" % (italian_regions[holonym], holonym)
  # Check for "province of Perugia". Usually in the form "province of Perugia in Umbria",
  # which is already converted to two distinct holonyms.
  m = re.search("^province of ((?:[A-Z][A-Za-z'-]*)(?: [A-Z][A-Za-z'-]*| and| of| of the)*)$", holonym)
  if m:
    return "p/%s" % m.group(1)
  # Check for "Perugia province of Umbria".
  m = re.search("^((?:[A-Z][A-Za-z'-]*)(?: [A-Z][A-Za-z'-]*| and| of| of the)*) province of (?:the )?((?:[A-Z][A-Za-z'-]*)(?: [A-Z][A-Za-z'-]*| and| of| of the)*)$", holonym)
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
  # Ancient Rome
  if holonym in roman_provinces:
    return "p/%s" % holonym
  return None

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
  def templatize_place_line(m):
    global recognized_lines
    global unparsable_lines
    global unrecognized_placetype_lines
    global unrecognized_holonym_lines
    global total_lines
    global total_parsable_lines
    total_lines += 1
    origline = m.group(0)
    def strip_wikicode(text):
      text = re.sub(r"\{\{l\|(?:en|n[bno])\|(?:[^{}|\[\]]*?\|)?([^{}|\[\]]+?)\}\}", r"\1", text)
      text = re.sub(r"\{\{w\|(?:[^{}|\[\]]*?\|)?([^{}|\[\]]+?)\}\}", r"\1", text)
      text = re.sub(r"\[\[w:(?:[^{}|\[\]]*?\|)?([^{}|\[\]]+?)\]\]", r"\1", text)
      text = re.sub(r"\[\[(?:[^{}|\[\]]*?\|)?([^{}|\[\]]+?)\]\]", r"\1", text)
      return text
    m = re.search(r"^(#+ *(?:\{\{.*?\}\})? *)[Aa]n? +(.*?) +(?:in|of) +(?:the +)?(.*?)((?: *\{\{q\|[^{}]*?\}\})?)\.?$", origline)
    if m:
      pretext, placetype, holonyms, postq = m.groups()
      trans = None
    else:
      m = re.search(r"^(#+ *(?:\{\{(?:[^lw]|[lw][^|])[^{}]*?\}\} *)*)([^()]*?) *(?:\(|\{\{gloss\|)(?:[Tt]he |[Aa]n? )?(.*?) +(?:in|of) +(?:the +)?(.*?)(?:\)|\}\})((?: *\{\{q\|[^{}]*?\}\})?)\.?$", origline)
      if m:
        pretext, trans, placetype, holonyms, postq = m.groups()
      else:
        unparsable_lines += 1
        #pagemsg("WARNING: Unable to parse line: <from> %s <to> %s <end>" % (origline, origline))
        return origline
    total_parsable_lines += 1
    placetype = strip_wikicode(placetype)
    if trans:
      trans = strip_wikicode(trans)
    split_placetype = re.split("(?:/| and (?:the |an? )?)", placetype)
    for pt in split_placetype:
      if pt not in place_types_with_aliases:
        unrecognized_place_types[pt] += 1
        unrecognized_placetype_lines += 1
        pagemsg("WARNING: Unable to recognize stripped placetype '%s': <from> %s <to> %s <end>" % (pt, origline, origline))
        return origline
    holonyms = strip_wikicode(holonyms)
    holonyms = re.sub(",? *(?:and |(?:that|which) is )?(?:the )?(county|parish|borough) seat of ", r", \1 seat, ", holonyms)
    # Handle "A city in and the county seat of ...".
    m = re.search("^, (county|parish|borough) seat, (.*)$", holonyms)
    if m:
      split_placetype.append("%s seat" % m.group(1))
      holonyms = m.group(2)
    holonyms = re.sub(",? in (?:the )?", ", ", holonyms)
    holonyms = re.split(", *", holonyms)
    parsed_holonyms = []
    for holonym in holonyms:
      if holonym in ["county seat", "parish seat", "borough seat"]:
        parsed_holonyms.append(";")
        parsed_holonyms.append(holonym)
      else:
        parsed_holonym = parse_holonym(holonym)
        if parsed_holonym:
          if type(parsed_holonym) is list:
            parsed_holonyms.extend(parsed_holonym)
          else:
            parsed_holonyms.append(parsed_holonym)
        else:
          m = re.search("^(%s) (.*)$" % "|".join(re.escape(x) for x in compass_points_with_aliases.keys()), holonym)
          if m:
            compass_point, base_holonym = m.groups()
            parsed_holonym = parse_holonym(base_holonym)
            if parsed_holonym:
              parsed_holonyms.append(compass_points_with_aliases[compass_point])
              if type(parsed_holonym) is list:
                parsed_holonyms.extend(parsed_holonym)
              else:
                parsed_holonyms.append(parsed_holonym)
            else:
              unrecognized_holonyms[base_holonym] += 1
              unrecognized_holonym_lines += 1
              pagemsg("WARNING: Unable to recognize stripped holonym '%s': <from> %s <to> %s <end>" % (base_holonym, origline, origline))
              return origline
          else:
            unrecognized_holonyms[holonym] += 1
            unrecognized_holonym_lines += 1
            pagemsg("WARNING: Unable to recognize stripped holonym '%s': <from> %s <to> %s <end>" % (holonym, origline, origline))
            return origline

    notes.append("templatize %s place spec into {{place}}" % placetype)
    normalized_placetype = "/".join(place_types_with_aliases[pt] for pt in split_placetype)
    retval = "%s{{place|en|%s|%s%s}}%s" % (pretext, normalized_placetype, "|".join(parsed_holonyms),
        "|t1=%s" % trans if trans else "", postq)
    pagemsg("Replaced <%s> with <%s>" % (origline, retval))
    recognized_lines += 1
    return retval

  text = re.sub(r"^.*(%s).*$" % "|".join(re.escape(x) for x in place_types_with_aliases.keys()), templatize_place_line, text, 0, re.M)
  return text, notes

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
output_stats(1000)
