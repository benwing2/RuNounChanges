local labels = {}

------------------------------------------ Generic ------------------------------------------

--not sure where to put this
labels["Classical"] = {
	aliases = {"classical"},
	langs = {"ar", "az", "ca", "fa", "id", "ja", "jv", "kum", "la", "ms", "quc", "sa", "tl", "zh"},
	special_display = "[[Classical <canonical_name>]]",
	regional_categories = true,
}

labels["Epigraphic"] = {
	langs = {"grc", "inc-pra", "pgd", "sa"},
	special_display = "[[w:Epigraphy|Epigraphic <canonical_name>]]",
	regional_categories = true,
}

labels["regional"] = {
	display = "[[regional#English|regional]]",
	regional_categories = true,
}


------------------------------------------ Africa ------------------------------------------

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Burundi"] = {
	aliases = {"Burundian"},
	langs = {},
	Wikipedia = true,
	regional_categories = "Burundian",
}

labels["Congo"] = {
	aliases = {"Democratic Republic of the Congo", "Democratic Republic of Congo", "DR Congo", "Congo-Kinshasa", "Republic of the Congo", "Republic of Congo", "Congo-Brazzaville", "Congolese"}, -- these could be split if need be
	langs = {"avu", "fr", "yom"},
	Wikipedia = true,
	regional_categories = "Congolese",
}

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Durban"] = {
	langs = {},
	Wikipedia = true,
	regional_categories = true,
}

labels["Nigeria"] = {
	aliases = {"Nigerian"},
	langs = {"ar", "en", "ff", "guw", "ha", "yo"},
	Wikipedia = true,
	regional_categories = "Nigerian",
}

labels["South Africa"] = {
	aliases = {"South African"},
	langs = {"af", "de", "en", "nl", "pt", "st", "te", "yi", "zu"},
	Wikipedia = true,
	regional_categories = "South African",
}

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Zululand"] = {
	langs = {},
	Wikipedia = true,
	regional_categories = true,
}


------------------------------------------ North America ------------------------------------------

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Alabama"] = {
	aliases = {"Alabaman", "Alabamian"},
	langs = {},
	Wikipedia = true,
	regional_categories = true,
}

labels["Cajun"] = {
	langs = {"en", "es", "fr", "vi"},
	display = "[[w:Cajun|Louisiana]]",
	track = true,
	regional_categories = "Louisiana",
}

labels["Canada"] = {
	aliases = {"Canadian"},
	langs = {"en", "fr", "gd", "haa", "is", "ko", "ru", "tli", "uk", "vi", "zh"},
	Wikipedia = true,
	regional_categories = "Canadian",
}

labels["Indiana"] = {
	aliases = {"Indianan", "Indianian"},
	langs = {"de", "en"},
	Wikipedia = true,
	regional_categories = true,
}

labels["Louisiana"] = {
	aliases = {"New Orleans"},
	langs = {"en", "es", "fr", "vi"},
	Wikipedia = true,
	regional_categories = true,
}

labels["Missouri"] = {
	aliases = {"Missourian", "St Louis, Missouri", "St. Louis, Missouri"},
	langs = {"en", "fr"},
	Wikipedia = true,
	regional_categories = true,
}

labels["New York City"] = {
	aliases = {"NYC", "New York city"},
	langs = {"en", "es"},
	Wikipedia = true,
	regional_categories = true,
}

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Nunavut"] = {
	langs = {},
	Wikipedia = true,
	track = true,
}

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Oklahoma"] = {
	aliases = {"Oklahoman", "OK"},
	langs = {},
	Wikipedia = true,
	regional_categories = true,
}

-- can be split off if enough entries in it arise; group with PA for now
-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Philadelphia"] = {
	langs = {},
	Wikipedia = true,
}

-- can be split off if enough entries in it arise; group with PA for now
-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Pittsburgh"] = {
	langs = {},
	Wikipedia = true,
}

labels["Texas"] = {
	aliases = {"TX", "Texan"},
	langs = {"de", "en", "es", "szl"},
	Wikipedia = true,
	regional_categories = true,
}

labels["US"] = {
	aliases = {"U.S.", "United States", "United States of America", "USA", "America", "American"}, -- America/American: should these be aliases of 'North America'?
	langs = {"de", "en", "hi", "is", "it", "ja", "ko", "nl", "pt", "ru", "tli", "ur", "vi", "yi", "zh"},
	Wikipedia = "United States",
	regional_categories = "American",
}


------------------------------------------ Central America ------------------------------------------


------------------------------------------ South America ------------------------------------------

labels["Brazil"] = {
	aliases = {"Brazilian"},
	langs = {"ja", "mch", "pt", "vec", "yi"},
	Wikipedia = true,
	regional_categories = "Brazilian",
}

labels["Suriname"] = {
	aliases = {"Surinamese"},
	langs = {"car", "hns", "jv", "nl", "zh"},
	Wikipedia = true,
	regional_categories = "Surinamese",
}


------------------------------------------ Asia ------------------------------------------

-- Asia A

labels["Arapgir"] = {
	aliases = {"Arapkir", "Arabkir"},
	langs = {"hy", "tr"},
	Wikipedia = true,
	regional_categories = true,
}

labels["Ardanuç"] = {
	aliases = {"Artanuj", "Ardanuji"},
	langs = {"hy", "tr"},
	Wikipedia = true,
	regional_categories = true,
}

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Azad Kashmir"] = {
	aliases = {"Pakistani Kashmir", "Azad Jammu and Kashmir", "Azad Jammu & Kashmir", "AJK", "AJ&K", "ajk"},
	langs = {},
	Wikipedia = true,
	regional_categories = "Azad Kashmiri",
}

-- Asia B

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Balochistan"] = {
	langs = {},
	Wikipedia = "Balochistan, Pakistan",
	regional_categories = "Balochi",
}

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Bogor"] = {
	langs = {},
	Wikipedia = true,
	regional_categories = true,
}

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Brebes"] = {
	aliases = {"Brebian"},
	langs = {},
	Wikipedia = "Brebes Regency",
	regional_categories = true,
}

-- Asia C

labels["China"] = {
	langs = {"en", "ja", "khb", "kk", "ko", "mhx", "mn", "ug"},
	Wikipedia = true,
	regional_categories = "Chinese",
}

labels["Cyprus"] = {
	aliases = {"cypriot", "Cypriot"},
	langs = {"ar", "el", "tr"},
	Wikipedia = true,
	regional_categories = "Cypriot",
}

-- Asia D


labels["Diyarbakır"] = {
	aliases = {"Diyarbakir", "Diyarbekir", "Tigranakert"},
	langs = {"hy", "tr"},
	Wikipedia = true,
	regional_categories = true,
}

-- Asia E

labels["Erciş"] = {
	aliases = {"Ercis", "Archesh", "Artchesh", "Erdîş"},
	langs = {"hy", "tr"},
	Wikipedia = true,
	regional_categories = true,
}

labels["Erzincan"] = {
	aliases = {"Yerznka", "Erznka", "Erzinjan"},
	langs = {"hy", "tr"},
	Wikipedia = true,
	regional_categories = true,
}

labels["Erzurum"] = {
	aliases = {"Karin", "Erzrum"},
	langs = {"hy", "tr"},
	Wikipedia = true,
	regional_categories = true,
}

-- Asia F
-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Faisalabad"] = {
	aliases = {"Faisalabadi", "Lyallpur", "Lyallpuri"},
	langs = {},
	display = "[[w:Faisalabad|Lyallpuri]]",
	regional_categories = "Lyallpuri",
}

-- Asia G

labels["Ganja"] = {
	aliases = {"Gandzak", "Gəncə"},
	langs = {"az", "hy"},
	Wikipedia = "Ganja, Azerbaijan",
	regional_categories = true,
}

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Gilgit-Baltistan"] = {
	aliases = {"Gilgit Baltistan"},
	langs = {},
	Wikipedia = true,
	regional_categories = "Gilgit-Baltistani",
}

-- Asia H

labels["Hong Kong"] = {
	langs = {"en", "zh"},
	Wikipedia = true,
	regional_categories = true,
}

-- Asia I

labels["India"] = {
	aliases = {"Indian"},
	langs = {"bn", "dv", "en", "fa", "ml", "pa", "pt", "ta", "ur"},
	Wikipedia = true,
	regional_categories = "Indian",
}

labels["Indonesia"] = {
	aliases = {"Indonesian"},
	langs = {"en", "id", "jv", "ms", "nl", "zh"},
	Wikipedia = true,
	regional_categories = "Indonesian",
}

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Islamabad"] = {
	langs = {},
	Wikipedia = true,
	regional_categories = "Islamabadi",
}

labels["Israel"] = {
	aliases = {"Israeli"},
	langs = {"ajp", "ar", "en", "he", "ru", "yi"},
	Wikipedia = true,
	regional_categories = "Israeli",
}

labels["İzmit"] = {
	aliases = {"Izmit", "Nicomedia", "Nikomedia"},
	langs = {"hy", "tr"},
	Wikipedia = true,
	regional_categories = true,
}

-- Asia J

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Jammu Kashmir"] = {
	aliases = {"Jammu and Kashmir", "Indian Kashmir", "Jammu & Kashmir", "J&K"},
	langs = {},
	Wikipedia = "Jammu and Kashmir (union territory)",
	regional_categories = "Jammu Kashmiri",
}

labels["Japan"] = {
	langs = {"en", "ko", "ru", "zh"},
	Wikipedia = true,
	regional_categories = "Japanese",
}

-- Asia K

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Kathiyawadi"] = {
	aliases = {"Kathiawadi", "Sorathi", "Bhawnagari", "Gohilwadi", "Holadi", "Jhalawadi"},
	langs = {},
	Wikipedia = "Kathiawar",
	regional_categories = true,
}

labels["Kazakhstan"] = {
	aliases = {"Kazakhstani", "Kazakh"},
	langs = {"ru", "ug"},
	Wikipedia = true,
	regional_categories = "Kazakhstani",
}

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Kazym"] = {
	langs = {},
	Wikipedia = true,
	regional_categories = true,
}

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Kemaliye"] = {
	langs = {},
	Wikipedia = true,
	regional_categories = true,
}

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Khyber Pakhtunkhwa"] = {
	aliases = {"Pakhtunkhwa", "KPK"},
	langs = {},
	Wikipedia = true,
	regional_categories = true,
}

-- Asia L


-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Lahore"] = {
	aliases = {"Lahori"},
	langs = {},
	Wikipedia = true,
	regional_categories = "Lahori",
}

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Lucknow"] = {
	langs = {},
	Wikipedia = true,
	regional_categories = true,
}

-- Asia M
labels["Macau"] = {
	aliases = {"Macao", "Macanese"},
	langs = {"en", "pt", "zh"},
	Wikipedia = true,
	regional_categories = "Macanese",
}

labels["Mainland China"] = {
	aliases = {"Mainland", "mainland", "mainland China"},
	langs = {"en", "zh"},
	Wikipedia = true,
	regional_categories = true,
}

labels["Malaysia"] = {
	aliases = {"Malaysian"},
	langs = {"en", "ms", "ta", "zh"},
	Wikipedia = true,
	regional_categories = "Malaysian",
}

labels["Moks"] = {
	aliases = {"Müküs", "Miks"},
	langs = {"hy", "kmr"},
	Wikipedia = "Bahçesaray (District), Van",
	regional_categories = true,
}

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Muş"] = {
	aliases = {"Mush"},
	langs = {},
	Wikipedia = true,
	regional_categories = true,
}

labels["Myanmar"] = {
	aliases = {"Myanmarese", "Burma", "Burmese"},
	langs = {"en", "ksw", "mnw", "my", "zh"},
	Wikipedia = true,
	regional_categories = true,
}

-- Asia N

labels["Nepal"] = {
	aliases = {"Nepali", "Nepalese"},
	langs = {"en", "hi"},
	Wikipedia = true,
	regional_categories = "Nepali",
}

labels["Nor Bayazet"] = {
	aliases = {"Novo-Bayazet", "Gavar"},
	langs = {"hy", "kmr"},
	Wikipedia = true,
	regional_categories = true,
}

-- Asia O

-- Asia P

labels["Palestine"] = {
	aliases = {"Palestinian"},
	langs = {"ajp", "ar", "arc", "en"},
	Wikipedia = true,
	regional_categories = "Palestinian",
}

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Peshawar"] = {
	aliases = {"Peshawari"},
	langs = {},
	Wikipedia = true,
	regional_categories = "Peshawari",
}

labels["Philippines"] = {
	aliases = {"Philippine"},
	langs = {"en", "es", "zh"},
	Wikipedia = true,
	regional_categories = "Philippine",
}

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Priangan"] = {
	langs = {},
	Wikipedia = "Parahyangan",
	regional_categories = true,
}

labels["Pontianak"] = {
	langs = {"id", "ms", "zh"},
	Wikipedia = true,
	regional_categories = true,
}

-- Asia Q

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Quetta"] = {
	aliases = {"Quettan", "Quettawal", "Quettawali"},
	langs = {},
	Wikipedia = true,
	regional_categories = "Quettan",
}

-- Asia R

-- Asia S

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Sindh"] = {
	aliases = {"Sind", "Sindhi"},
	langs = {},
	Wikipedia = true,
	regional_categories = "Sindhi",
}

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Shuryshkar"] = {
	aliases = {"Shurishkar"},
	langs = {},
	Wikipedia = "Shuryshkarsky District",
	regional_categories = true,
}

labels["Singapore"] = {
	aliases = {"Singaporean"},
	langs = {"en", "ms", "ta", "zh"},
	Wikipedia = true,
	regional_categories = true,
}

labels["Sivas"] = {
	aliases = {"Sebastia", "Sebastea"},
	langs = {"hy", "tr"},
	Wikipedia = true,
	regional_categories = true,
}

labels["Southeast Asia"] = {
	aliases = {"Southeast Asian", "SEA"},
	langs = {"en", "zh"},
	Wikipedia = true,
	regional_categories = "Southeast Asian",
}

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Surati"] = {
	langs = {},
	Wikipedia = "Surat district",
	regional_categories = true,
}

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Surgut"] = {
	langs = {},
	Wikipedia = true,
	regional_categories = true,
}

-- Asia T

labels["Taiwan"] = {
	aliases = {"Taiwanese"},
	langs = {"en", "ja", "zh"},
	Wikipedia = true,
	regional_categories = "Taiwanese",
}

labels["Thailand"] = {
	aliases = {"Thai"},
	langs = {"en", "khb", "mnw", "th", "zh"},
	Wikipedia = true,
	regional_categories = "Thai",
}

-- Asia U

labels["Urmia"] = {
	aliases = {"Urmu", "Urmiya"},
	langs = {"az", "hy"},
	Wikipedia = true,
	regional_categories = true,
}

-- Asia V

-- Asia W

-- Asia X

-- Asia Y

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Special Region of Yogyakarta"] = {
	aliases = {"SR Yogyakarta"},
	langs = {},
	Wikipedia = true,
	regional_categories = true,
}

-- Asia Z


------------------------------------------ Europe ------------------------------------------

labels["Europe"] = {
	langs = {"en", "es", "fr", "pt", "ur"},
	Wikipedia = true,
	regional_categories = "European",
}

-- Europe A

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Anatri"] = {
	aliases = {"Lower Chuvash"},
	langs = {},
	Wikipedia = true,
	regional_categories = true,
}

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Viryal"] = {
	aliases = {"Upper Chuvash"},
	langs = {},
	Wikipedia = true,
	regional_categories = true,
}

labels["Andalusia"] = {
	aliases = {"Andalucía", "Andalucia"},
	langs = {"ar", "es"},
	Wikipedia = true,
	regional_categories = "Andalusian",
}

-- Europe B

labels["Belgium"] = {
	aliases = {"Belgian"},
	langs = {"de", "fr", "gmw-cfr", "nl"},
	Wikipedia = true,
	regional_categories = "Belgian",
}

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Black Isle"] = {
	langs = {},
	Wikipedia = true,
	regional_categories = true,
}

labels["Britain"] = {
	aliases = {"Brit", "British", "Great Britain"},
	langs = {"bn", "en", "ur", "vi", "zh"},
	Wikipedia = "Great Britain",
	regional_categories = "British",
}

labels["Bukovina"] = {
	aliases = {"Bucovina", "Bukovinian", "Bukowina"},
	langs = {"pl", "ro", "uk"},
	Wikipedia = true,
	regional_categories = "Bukovinian",
}

-- Europe C

labels["Carinthia"] = {
	aliases = {"Carinthian", "Kärnten"},
	langs = {"bar", "sl"},
	Wikipedia = true,
	regional_categories = "Carinthian",
}

labels["Cornwall"] = {
	aliases = {"Cornish", "Cornish dialect"},
	langs = {"en", "enm"},
	Wikipedia = true,
	regional_categories = "Cornish",
}

-- can be split off if enough entries in it arise; group with Cumbria for now
-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["West Cumbria"] = {
	aliases = {"West Cumbrian"},
	langs = {},
	Wikipedia = "Cumbria",
}

-- Europe D

labels["Dobruja"] = {
	aliases = {"Dobrogea", "Dobrujan"},
	langs = {"crh", "ro"},
	Wikipedia = true,
	regional_categories = "Dobrujan",
}

-- Europe E
labels["East Anglia"] = {
	aliases = {"East Anglian", "East Anglian dialect"},
	langs = {"en", "enm"},
	Wikipedia = true,
	regional_categories = "East Anglian",
}

labels["England and Wales"] = {
	aliases = {"England & Wales", "E&W", "E+W"},
	langs = {"en", "la"},
	Wikipedia = true,
	regional_categories = {"English", "Welsh"},
}

-- Europe F

labels["France"] = {
	aliases = {"French"},
	langs = {"ca", "fr", "la", "lad", "nrf", "vi", "yi", "zh"},
	Wikipedia = true,
	regional_categories = "French",
}

-- Europe G

-- Europe H

labels["Hungary"] = {
	aliases = {"Hungarian"},
	langs = {"de", "en", "la", "rom"},
	Wikipedia = true,
	regional_categories = "Hungarian",
}

-- Europe I

labels["Istanbul"] = {
	aliases = {"İstanbul", "Polis"},
	langs = {"hy", "tr"},
	Wikipedia = true,
	regional_categories = true,
}

-- Europe J

-- Europe K
-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Kalix"] = {
	langs = {},
	Wikipedia = true,
	regional_categories = true,
}

labels["Kent"] = {
	aliases = {"Kentish", "Kentish dialect", "Kent dialect"},
	langs = {"ang", "en", "enm"},
	Wikipedia = true,
	regional_categories = "Kentish",
}

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Kukkuzi"] = {
	langs = {},
	Wikipedia = true,
	regional_categories = true,
}

-- Europe L

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Luleå"] = {
	aliases = {"Lulea"},
	langs = {},
	Wikipedia = true,
	regional_categories = true,
}

labels["Luxembourg"] = {
	aliases = {"Luxembourgish", "Luxemburg", "Luxemburgish"},
	langs = {"de", "fr"},
	Wikipedia = true,
	regional_categories = "Luxembourgish",
}

labels["Lviv"] = {
	aliases = {"Lvov", "Lwow", "Lwów"},
	langs = {"pl", "uk"},
	Wikipedia = true,
	regional_categories = true,
}

-- Europe M


-- Europe N

labels["Northumbria"] = {
	aliases = {"Northumbrian", "Northumberland", "Northeast England", "North-East England", "North East England"},
	langs = {"ang", "en"},
	Wikipedia = "Northumbria (modern)",
	regional_categories = "Northumbrian",
}

-- Europe O

labels["Ostrobothnia"] = {
	aliases = {"Ostrobothnian", "Österbotten"},
	langs = {"fi", "sv"},
	Wikipedia = true,
	regional_categories = "Ostrobothnian",
}

-- Europe P

-- Europe Q

-- Europe R

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Rome"] = {
	aliases = {"Roma", "Romano", "More Romano"},
	langs = {},
	Wikipedia = true,
	regional_categories = "Roman",
}

-- Europe S

labels["Scania"] = {
	aliases = {"Scanian", "Skanian", "Skåne"},
	langs = {"gmq-oda", "sv"},
	Wikipedia = true,
	regional_categories = "Scanian",
}

labels["Shetland"] = {
	aliases = {"Shetland islands", "Shetland Islands", "Shetlandic", "Shetlands"},
	langs = {"en", "nrn", "sco"},
	Wikipedia = true,
	regional_categories = true,
}

--Silesia German, Silesia Polish; for differentiation between sli "Silesian East Central German"
-- don't add Silesian as alias
-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Silesia"] = {
	langs = {},
	Wikipedia = true,
}

labels["Spain"] = {
	aliases = {"Spanish", "ES"},
	langs = {"ca", "es", "la"},
	Wikipedia = true,
	regional_categories = "Spanish",
}

labels["Switzerland"] = {
	aliases = {"Swiss", "Swiss German"}, -- some German entries use this alias; let -sche know if it causes problems
	langs = {"de", "fr", "gsw", "it", "ru"},
	Wikipedia = true,
	regional_categories = true,
}

-- Europe T

labels["Transylvania"] = {
	aliases = {"Transilvania", "Transylvanian"},
	langs = {"hu", "ro"},
	Wikipedia = true,
	regional_categories = "Transylvanian",
}

-- Europe U

labels["UK"] = {
	aliases = {"United Kingdom"},
	langs = {"bn", "en", "ur", "vi", "zh"},
	Wikipedia = "United Kingdom",
	regional_categories = "British",
}

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Old Ukrainian"] = {
	langs = {},
	Wikipedia = true,
	plain_categories = true,
}

-- Europe V

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Vilhelmina"] = {
	langs = {},
	Wikipedia = true,
	regional_categories = true,
}

-- Europe W

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Wallonia"] = {
	aliases = {"Wallonian"},
	langs = {},
	Wikipedia = true,
	regional_categories = "Wallonian",
}

-- Europe X

-- Europe Y

-- Europe Z
-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Zakarpattia"] = {
	langs = {},
	Wikipedia = "Zakarpattia Oblast",
	regional_categories = true,
}


------------------------------------------ Australia and Oceania ------------------------------------------

-- AO A
labels["Australia"] = {
	aliases = {"AU", "Australian"},
	langs = {"de", "el", "en", "it", "ko", "mt", "ru", "zh"},
	Wikipedia = true,
	regional_categories = "Australian",
}

-- AO B
-- AO C


-- AO D
-- AO E
-- AO F
-- AO G

labels["Guam"] = {
	aliases = {"Guåhan", "Guamanian"},
	langs = {"ch", "en"},
	Wikipedia = true,
	regional_categories = true,
}

-- AO H

-- AO I
-- AO J

-- AO K
-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Kauaʻi"] = {
	aliases = {"Kauai", "Kaua'i"},
	langs = {},
	Wikipedia = true,
	regional_categories = true,
}

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Kitti"] = {
	langs = {},
	Wikipedia = "Kitti, Federated States of Micronesia",
	regional_categories = true,
}

-- AO L

-- AO M
-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Maui"] = {
	langs = {},
	Wikipedia = true,
	regional_categories = true,
}

-- WARNING: No existing languages or categories associated with label; add to `langs` as needed
labels["Molokaʻi"] = {
	aliases = {"Molokai", "Moloka'i"},
	langs = {},
	Wikipedia = true,
	regional_categories = true,
}

-- AO N

-- AO O
-- AO P
-- AO Q
-- AO R
-- AO S
-- AO T
labels["Tasmania"] = {
	langs = {"de", "el", "en", "it", "ko", "mt", "ru", "zh"},
	Wikipedia = true,
	track = true,
	regional_categories = "Australian",
}

-- AO U
-- AO V
-- AO W
-- AO X
-- AO Y
-- AO Z


------------------------------------------ Chinese romanizations ------------------------------------------

labels["Hanyu Pinyin"] = {
	aliases = {"Hanyu pinyin", "Pinyin", "pinyin"},
	Wikidata = "Q42222",
	plain_categories = true,
}

labels["Postal Romanization"] = {
	aliases = {"Postal romanization", "postal romanization", "Postal", "postal"},
	Wikidata = "Q151868",
	plain_categories = true,
}

labels["Tongyong Pinyin"] = {
	aliases = {"Tongyong pinyin"},
	Wikidata = "Q700739",
	plain_categories = true,
}

labels["Wade–Giles"] = {
	aliases = {"Wade-Giles"},
	Wikidata = "Q208442",
	plain_categories = true,
}


return require("Module:labels").finalize_data(labels)
