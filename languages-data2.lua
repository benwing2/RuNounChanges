local u = mw.ustring.char

-- UTF-8 encoded strings for some commonly-used diacritics
local GRAVE     = u(0x0300)
local ACUTE     = u(0x0301)
local CIRC      = u(0x0302)
local TILDE     = u(0x0303)
local MACRON    = u(0x0304)
local BREVE     = u(0x0306)
local DOTABOVE  = u(0x0307)
local DIAER     = u(0x0308)
local RINGABOVE = u(0x030A)
local CARON     = u(0x030C)
local DGRAVE    = u(0x030F)
local INVBREVE  = u(0x0311)
local DOTBELOW  = u(0x0323)
local RINGBELOW = u(0x0325)
local CEDILLA   = u(0x0327)
local OGONEK    = u(0x0328)
local DOUBLEINVBREVE = u(0x0361)

-- Punctuation to be used for standardChars field
local PUNCTUATION = ' !#%&*+,-./:;<=>?@^_`|~\'()'

local Cyrl = {"Cyrl"}
local Latn = {"Latn"}
local LatnArab = {"Latn", "Arab"}

local m = {}

m["aa"] = {
	"Afar",
	"Q27811",
	"cus",
	aliases = {"Qafar"},
	scripts = Latn,
	entry_name = { remove_diacritics = ACUTE},
}

m["ab"] = {
	"Abkhaz",
	"Q5111",
	"cau-abz",
	aliases = {"Abkhazian", "Abxazo"},
	scripts = {"Cyrl", "Geor", "Latn"},
	translit_module = "ab-translit",
	override_translit = true,
	entry_name = {
		from = {GRAVE, ACUTE},
		to   = {}} ,
}

m["ae"] = {
	"Avestan",
	"Q29572",
	"ira-cen",
	aliases = {"Zend", "Old Bactrian"},
	scripts = {"Avst", "Gujr"},
	translit_module = "Avst-translit",
	wikipedia_article = "Avestan",
}

m["af"] = {
	"Afrikaans",
	"Q14196",
	"gmw",
	scripts = LatnArab,
	ancestors = {"nl"},
	sort_key = {
		from = {"[äáâà]", "[ëéêè]", "[ïíîì]", "[öóôò]", "[üúûù]", "[ÿýŷỳ]", "^-", "'"},
		to   = {"a"	 , "e"	, "i"	, "o"	, "u"  , "y" }} ,
}

m["ak"] = {
	"Akan",
	"Q28026",
	"alv-ctn",
	varieties = {"Twi-Fante", "Twi", {"Fante", "Fanti"}, "Asante", "Akuapem"},
	scripts = Latn,
}

m["am"] = {
	"Amharic",
	"Q28244",
	"sem-eth",
	scripts = {"Ethi"},
	translit_module = "Ethi-translit",
}

m["an"] = {
	"Aragonese",
	"Q8765",
	"roa-ibe",
	scripts = Latn,
	ancestors = {"roa-oan"},
}

m["ar"] = {
	"Arabic",
	"Q13955",
	"sem-arb",
	-- FIXME, some of the following are varieties but it's not clear which ones
	aliases = {"Standard Arabic", "Literary Arabic", "High Arabic"},
	varieties = {"Modern Standard Arabic", "Classical Arabic", "Judeo-Arabic"},
	scripts = {"Arab", "Hebr", "Brai"},
	-- replace alif waṣl with alif
	-- remove tatweel and diacritics: fathatan, dammatan, kasratan, fatha,
	-- damma, kasra, shadda, sukun, superscript (dagger) alef
	entry_name = {
		from = {u(0x0671), u(0x0640), "[" .. u(0x064B) .. "-" .. u(0x0652) .. "]", u(0x0670)},
		to   = {u(0x0627)}},
	translit_module = "ar-translit",
	standardChars = "ء-غف-ْٰٱ" .. PUNCTUATION .. "٠-٩،؛؟٫٬ـ",
}

m["as"] = {
	"Assamese",
	aliases = {"Asamiya"},
	"Q29401",
	"inc-eas",
	scripts = {"as-Beng"},
	ancestors = {"inc-mas"},
	translit_module = "as-translit",
}

m["av"] = {
	"Avar",
	"Q29561",
	"cau-nec",
	aliases = {"Avaric"},
	scripts = Cyrl,
	ancestors = {"oav"},
	translit_module = "av-translit",
	override_translit = true,
	entry_name = {
		from = {GRAVE, ACUTE},
		to   = {}} ,
}

m["ay"] = {
	"Aymara",
	"Q4627",
	"sai-aym",
	varieties = {"Southern Aymara", "Central Aymara"},
	scripts = Latn,
}

m["az"] = {
	"Azerbaijani",
	"Q9292",
	"trk-ogz",
	aliases = {"Azeri", "Azari", "Azeri Turkic", "Azerbaijani Turkic"},
	varieties = {"North Azerbaijani", "South Azerbaijani",
		{"Afshar", "Afshari", "Afshar Azerbaijani", "Afchar"},
		{"Qashqa'i", "Qashqai", "Kashkay"},
		"Sonqor"
	},
	scripts = {"Latn", "Cyrl", "fa-Arab"},
	ancestors = {"trk-oat"},
}

m["ba"] = {
	"Bashkir",
	"Q13389",
	"trk-kbu",
	scripts = Cyrl,
	translit_module = "ba-translit",
	override_translit = true,
}

m["be"] = {
	"Belarusian",
	"Q9091",
	"zle",
	aliases = {"Belorussian", "Belarusan", "Bielorussian", "Byelorussian", "Belarussian", "White Russian"},
	scripts = Cyrl,
	ancestors = {"orv"},
	translit_module = "be-translit",
	sort_key = {
		from = {"Ё", "ё"},
		to   = {"Е" , "е"}},
	entry_name = {
		from = {"Ѐ", "ѐ", GRAVE, ACUTE},
		to   = {"Е", "е"}},
}

m["bg"] = {
	"Bulgarian",
	"Q7918",
	"zls",
	scripts = {"Cyrl"},
	ancestors = {"cu"},
	translit_module = "bg-translit",
	entry_name = {
		from = {"Ѐ", "ѐ", "Ѝ", "ѝ", GRAVE, ACUTE},
		to   = {"Е", "е", "И", "и"}},
}

m["bh"] = {
	"Bihari",
	"Q135305",
	"inc-eas",
	scripts = {"Deva"},
	ancestors = {"inc-mgd"},
}

m["bi"] = {
	"Bislama",
	"Q35452",
	"crp",
	scripts = Latn,
	ancestors = {"en"},
}

m["bm"] = {
	"Bambara",
	"Q33243",
	"dmn-emn",
	aliases = {"Bamanankan"},
	scripts = Latn,
}

m["bn"] = {
	"Bengali",
	"Q9610",
	"inc-eas",
	aliases = {"Bangla"},
	scripts = {"Beng", "Newa"},
	ancestors = {"inc-mbn"},
	translit_module = "bn-translit",
}

m["bo"] = {
	"Tibetan",
	"Q34271",
	"sit-tib",
	varieties = {
		{"Amdo Tibetan", "Amdo"},
		"Dolpo",
		{"Khams", "Khams Tibetan"}, "Khamba",
		"Gola",
		"Humla",
		"Limi", {"Lhasa", "Lhasa Tibetan"}, "Lhomi", "Loke", "Lowa",
		"Mugom", "Mugu", "Mustang",
		"Nubri",
		"Panang",
		"Shing Saapa",
		"Thudam", "Tichurong", "Tseku",
		{"Ü", "Dbus"},
		"Walungge"}, -- and "Gyalsumdo", "Lower Manang"? "Kyirong"?
	scripts = {"Tibt"}, -- sometimes Deva?
	ancestors = {"xct"},
	translit_module = "bo-translit",
	override_translit = true,
}

m["br"] = {
	"Breton",
	"Q12107",
	"cel-bry",
	varieties = {{"Gwenedeg", "Vannetais"}, {"Kerneveg", "Cornouaillais"}, {"Leoneg", "Léonard"}, {"Tregerieg", "Trégorrois"}},
	scripts = Latn,
	ancestors = {"xbm"},
}

m["ca"] = {
	"Catalan",
	"Q7026",
	"roa",
	-- don't list varieties here that are in [[Module:etymology languages/data]]
	scripts = Latn,
	ancestors = {"roa-oca"},
	sort_key = {
		from = {"à", "[èé]", "[íï]", "[òó]", "[úü]", "ç", "l·l"},
		to   = {"a", "e"   , "i"   , "o"   , "u"   , "c", "ll" }} ,
}

m["ce"] = {
	"Chechen",
	"Q33350",
	"cau-vay",
	scripts = Cyrl,
	translit_module = "ce-translit",
	override_translit = true,
	entry_name = {
		from = {MACRON},
		to   = {}},
}

m["ch"] = {
	"Chamorro",
	"Q33262",
	"poz-sus",
	aliases = {"Chamoru"},
	scripts = Latn,
}

m["co"] = {
	"Corsican",
	"Q33111",
	"roa-itd",
	aliases = {"Corsu"},
	scripts = Latn,
}

m["cr"] = {
	"Cree",
	"Q33390",
	"alg",
	scripts = {"Cans", "Latn"},
	translit_module = "translit-redirect",
}

m["cs"] = {
	"Czech",
	"Q9056",
	"zlw",
	scripts = Latn,
	ancestors = {"zlw-ocs"},
	sort_key = {
		from = {"á", "é", "í", "ó", "[úů]", "ý"},
		to   = {"a", "e", "i", "o", "u"   , "y"}} ,
}

m["cu"] = {
	"Old Church Slavonic",
	"Q35499",
	"zls",
	aliases = {"Old Church Slavic"},
	scripts = {"Cyrs", "Glag"},
	translit_module = "Cyrs-Glag-translit",
	entry_name = {
		from = {u(0x0484)}, -- kamora
		to   = {}},
	sort_key = {
		from = {"оу", "є"},
		to   = {"у" , "е"}} ,
}

m["cv"] = {
	"Chuvash",
	"Q33348",
	"trk-ogr",
	scripts = Cyrl,
	translit_module = "cv-translit",
	override_translit = true,
}

m["cy"] = {
	"Welsh",
	"Q9309",
	"cel-bry",
	varieties = {"Cofi Welsh", {"Dyfedeg", "Dyfed Welsh", "Demetian"}, {"Gwenhwyseg", "Gwent Welsh", "Gwentian"}, {"Gwyndodeg", "Gwynedd Welsh", "Venedotian"}, "North Wales Welsh", {"Powyseg", "Powys Welsh", "Powysian"}, "South Wales Welsh", "Patagonian Welsh"},
	scripts = Latn,
	ancestors = {"wlm"},
	sort_key = {
		remove_diacritics = DIAER .. ACUTE .. GRAVE .. CIRC,
		from = {"ch", "dd", "ff", "ngh", "ll", "ph", "rh", "th", "'"},
		to   = {"c~", "d~", "f~", "g~h", "l~", "p~", "r~", "t~",    },
	} ,
	standardChars = "A-IL-PR-UWYa-il-pr-uwy0-9ÂâÊêÎîÔôÛûŴŵŶŷ" .. PUNCTUATION,
}

m["da"] = {
	"Danish",
	"Q9035",
	"gmq",
	scripts = Latn,
	ancestors = {"gmq-oda"},
}

m["de"] = {
	"German",
	"Q188",
	"gmw",
	aliases = {"High German", "New High German", "Deutsch"},
	varieties = {"Alsatian German", "American German",
		"Bavarian German", "Belgian German",
		"Central German",
		"DDR German",
		"East African German",
		"German German",
		"Hessian German",
		"Indiana German",
		"Liechtenstein German", "Lorraine German", "Luxembourgish German",
		"Namibian German", "Northern German",
		"Prussian German",
		"Silesia German", "South African German", "Southern German", "South Tyrolean German", "Switzerland German",
		"Texan German"},
	scripts = {"Latn", "Latf"},
	ancestors = {"gmh"},
	sort_key = {
		remove_diacritics = DIAER .. ACUTE .. GRAVE .. CIRC .. RINGABOVE,
		from = { "ß" },
		to   = { "ss"},
	} ,
	standardChars = "A-Za-z0-9ÄäÖöÜüß" .. PUNCTUATION,
}

m["dv"] = {
	"Dhivehi",
	"Q32656",
	"inc-ins",
	aliases = {"Divehi", "Maldivian"},
	varieties = {{"Mahal", "Mahl"}},
	scripts = {"Thaa"},
	ancestors = {"elu-prk"},
	translit_module = "dv-translit",
	override_translit = true,
}

m["dz"] = {
	"Dzongkha",
	"Q33081",
	"sit-tib",
	scripts = {"Tibt"},
	ancestors = {"xct"},
	translit_module = "bo-translit",
	override_translit = true,
}

m["ee"] = {
	"Ewe",
	"Q30005",
	"alv-gbe",
	scripts = Latn,
}

m["el"] = {
	"Greek",
	"Q9129",
	"grk",
	aliases = {"Modern Greek", "Neo-Hellenic"},
	scripts = {"Grek", "Brai"},
	ancestors = {"grc"},
	translit_module = "el-translit",
	override_translit = true,
	sort_key = {  -- Keep this synchronized with grc, cpg, pnt, tsd
		from = {"[ᾳάᾴὰᾲᾶᾷἀᾀἄᾄἂᾂἆᾆἁᾁἅᾅἃᾃἇᾇ]", "[έὲἐἔἒἑἕἓ]", "[ῃήῄὴῂῆῇἠᾐἤᾔἢᾒἦᾖἡᾑἥᾕἣᾓἧᾗ]", "[ίὶῖἰἴἲἶἱἵἳἷϊΐῒῗ]", "[όὸὀὄὂὁὅὃ]", "[ύὺῦὐὔὒὖὑὕὓὗϋΰῢῧ]", "[ῳώῴὼῲῶῷὠᾠὤᾤὢᾢὦᾦὡᾡὥᾥὣᾣὧᾧ]", "ῥ", "ς"},
		to   = {"α"						, "ε"		 , "η"						, "ι"				, "ο"		 , "υ"				, "ω"						, "ρ", "σ"}} ,
	standardChars = "ͺ;΄-ώϜϝ" .. PUNCTUATION,
}

m["en"] = {
	"English",
	"Q1860",
	"gmw",
	aliases = {"Modern English", "New English"},
	varieties = {"Polari", "Yinglish"},
	scripts = {"Latn", "Brai", "Shaw", "Dsrt"}, -- entries in Shaw or Dsrt might require prior discussion
	ancestors = {"enm"},
	sort_key = {
		from = {"[äàáâåā]", "[ëèéêē]", "[ïìíîī]", "[öòóôō]", "[üùúûū]", "æ" , "œ" , "[çč]", "ñ", "'"},
		to   = {"a"       , "e"      , "i"      , "o"      , "u"      , "ae", "oe", "c"   , "n"}},
	wikimedia_codes = {"en", "simple"},
	standardChars = "A-Za-z0-9" .. PUNCTUATION .. u(0x2800) .. "-" .. u(0x28FF),
}

m["eo"] = {
	"Esperanto",
	"Q143",
	"art",
	scripts = Latn,
	sort_key = {
		remove_diacritics = ACUTE .. GRAVE,
		from = {"[ĉ]", "[ĝ]", "[ĥ]", "[ĵ]", "[ŝ]", "[ŭ]"},
		to   = {"cĉ", "gĉ", "hĉ", "jĉ", "sĉ", "uĉ"}} ,
	standardChars = "A-PRSTUVZa-prstuvzĉĈĝĜĵĴŝŜŭŬ0-9" .. PUNCTUATION,
}

m["es"] = {
	"Spanish",
	"Q1321",
	"roa-ibe",
	aliases = {"Castilian"},
	varieties = {{"Amazonian Spanish", "Amazonic Spanish"}, "Loreto-Ucayali Spanish"},
	scripts = {"Latn", "Brai"},
	ancestors = {"osp"},
	sort_key = {
		from = {"á", "é", "í", "ó", "[úü]", "ç", "ñ"},
		to   = {"a", "e", "i", "o", "u"   , "c", "n"}},
	standardChars = "A-VXYZa-vxyz0-9ÁáÉéÍíÓóÚúÑñ¿¡" .. PUNCTUATION,
}

m["et"] = {
	"Estonian",
	"Q9072",
	"fiu-fin",
	scripts = Latn,
}

m["eu"] = {
	"Basque",
	"Q8752",
	"euq",
	aliases = {"Euskara"},
	scripts = Latn,
}

m["fa"] = {
	"Persian",
	"Q9168",
	"ira-swi",
	aliases = {"Farsi", "New Persian", "Modern Persian"},
	varieties = {{"Western Persian", "Iranian Persian"}, {"Eastern Persian", "Dari"}, {"Aimaq", "Aimak", "Aymaq", "Eimak"}},
	scripts = {"fa-Arab"},
	ancestors = {"pal"}, -- "ira-mid"
	entry_name = {
		from = {u(0x064E), u(0x0640), u(0x064F), u(0x0650), u(0x0651), u(0x0652)},
		to   = {}} ,
}

m["ff"] = {
	"Fula",
	"Q33454",
	"alv-fwo",
	aliases = {"Fulani"},
	varieties = {"Adamawa Fulfulde", "Bagirmi Fulfulde", "Borgu Fulfulde", "Central-Eastern Niger Fulfulde", "Fulfulde", "Maasina Fulfulde", "Nigerian Fulfulde", "Pular", "Pulaar", "Western Niger Fulfulde"}, -- Maasina, etc are dialects, subsumed into this code; Pular and Pulaar are distinct
	scripts = {"Latn", "Adlm"},
}

m["fi"] = {
	"Finnish",
	"Q1412",
	"fiu-fin",
	aliases = {"Suomi"},
	scripts = Latn,
	entry_name = {
		from = {"ˣ"},  -- Used to indicate gemination of the next consonant
		to   = {}},
	sort_key = {
		from = {"[áàâã]", "[éèêẽ]", "[íìîĩ]", "[óòôõ]", "[úùûũ]", "[ýỳŷüű]", "[øõő]", "æ" , "œ" , "[čç]", "š", "ž", "ß" , "[':]"},
		to   = {"a"	 , "e"	 , "i"	 , "o"	 , "u"	 ,  "y"	 , "ö"	, "ae", "oe", "c"   , "s", "z", "ss"}} ,
}

m["fj"] = {
	"Fijian",
	"Q33295",
	"poz-occ",
	scripts = Latn,
}

m["fo"] = {
	"Faroese",
	"Q25258",
	"gmq",
	aliases = {"Faeroese"},
	scripts = Latn,
	ancestors = {"non"},
}

m["fr"] = {
	"French",
	"Q150",
	"roa-oil",
	aliases = {"Modern French"},
	varieties = {"African French", "Algerian French", "Alsatian French", "Antilles French", "Atlantic Canadian French",
		"Belgian French",
		"Congolese French",
		"European French",
		"French French",
		"Haitian French",
		"Ivorian French",
		"Lorraine French", "Louisiana French", "Luxembourgish French",
		"Malian French", "Marseille French", "Missourian French", "Moroccan French",
		"Newfoundland French", "North American French",
		"Picard French", "Provençal French",
		"Quebec French",
		"Réunion French", "Rwandan French",
		"Tunisian French",
		"West African French"},
	scripts = {"Latn", "Brai"},
	ancestors = {"frm"},
	sort_key = {
		remove_diacritics = ACUTE .. GRAVE .. CIRC .. DIAER,
		from = {"ç", "æ" , "œ" , "'"},
		to   = {"c", "ae", "oe"},
	},
	standardChars = "A-Za-z0-9ÀÂÇÉÈÊËÎÏÔŒÛÙÜàâçéèêëîïôœûùü«»" .. PUNCTUATION,
}

m["fy"] = {
	"West Frisian",
	"Q27175",
	"gmw-fri",
	aliases = {"Western Frisian"},
	scripts = Latn,
	ancestors = {"ofs"},
	sort_key = {
		from = {"[àáâä]", "[èéêë]", "[ìíîïyỳýŷÿ]", "[òóôö]", "[ùúûü]", "æ", "[ /.-]"},
		to   = {"a"	 , "e"	, "i"	, "o"	, "u", "ae"}} ,
	standardChars = "A-PR-WYZa-pr-wyz0-9Ææâäàéêëèïìôöòúûüùỳ" .. PUNCTUATION,
}

m["ga"] = {
	"Irish",
	"Q9142",
	"cel-gae",
	aliases = {"Irish Gaelic", "Gaelic"}, -- calling it simply "Gaelic" is rare in Ireland, but relatively common in the Irish diaspora
	varieties = {{"Cois Fharraige Irish", "Cois Fhairrge Irish"}, {"Connacht Irish", "Connaught Irish"}, "Cork Irish", "Donegal Irish", "Galway Irish", "Kerry Irish", "Mayo Irish", "Munster Irish", "Ulster Irish", "Waterford Irish", "West Muskerry Irish"},
	scripts = Latn,
	ancestors = {"mga"},
	sort_key = {
		from = {"á", "é", "í", "ó", "ú", "ý", "ḃ" , "ċ" , "ḋ" , "ḟ" , "ġ" , "ṁ" , "ṗ" , "ṡ" , "ṫ" },
		to   = {"a", "e", "i", "o", "u", "y", "bh", "ch", "dh", "fh", "gh", "mh", "ph", "sh", "th"}} ,
	standardChars = "A-IL-PR-Ua-il-pr-u0-9ÁáÉéÍíÓóÚú" .. PUNCTUATION,
}

m["gd"] = {
	"Scottish Gaelic",
	"Q9314",
	"cel-gae",
	aliases = {"Gaelic", "Gàidhlig", "Scots Gaelic", "Scottish"},
	varieties = {"Argyll Gaelic", "Arran Scottish Gaelic", {"Canadian Gaelic", "Canadian Scottish Gaelic", "Cape Breton Gaelic"}, "East Sutherland Gaelic", {"Galwegian Gaelic", "Gallovidian Gaelic", "Gallowegian Gaelic", "Galloway Gaelic"}, "Hebridean Gaelic", "Highland Gaelic"},
	scripts = Latn,
	ancestors = {"mga"},
	sort_key = {
		remove_diacritics = ACUTE .. GRAVE,
	},
	standardChars = "A-IL-PR-Ua-il-pr-u0-9ÀàÈèÌìÒòÙù" .. PUNCTUATION,
}

m["gl"] = {
	"Galician",
	"Q9307",
	"roa-ibe",
	scripts = Latn,
	ancestors = {"roa-opt"},
	sort_key = {
		remove_diacritics = ACUTE,
	},
}

m["gn"] = {
	"Guaraní",
	"Q35876",
	"tup-gua",
	scripts = Latn,
}

m["gu"] = {
	"Gujarati",
	"Q5137",
	"inc-wes",
	scripts = {"Gujr"},
	ancestors = {"inc-mgu"},
	translit_module = "gu-translit",
}

m["gv"] = {
	"Manx",
	"Q12175",
	"cel-gae",
	aliases = {"Manx Gaelic"},
	varieties = {"Northern Manx", "Southern Manx"},
	scripts = Latn,
	ancestors = {"mga"},
	sort_key = {
		from = {"ç", "-"},
		to   = {"c"}} ,
	standardChars = "A-WYÇa-wyç0-9" .. PUNCTUATION,
}

m["ha"] = {
	"Hausa",
	"Q56475",
	"cdc-wst",
	scripts = LatnArab,
	sort_key = {
		from = {"ɓ",   "ɗ",   "ƙ",  "'y", "ƴ",  "'" },
		to   = {"b~" , "d~"	, "k~", "y~", "y~", ""  }},
	entry_name = {
		remove_diacritics = GRAVE .. ACUTE .. CIRC .. TILDE .. MACRON,
	},
}

m["he"] = {
	"Hebrew",
	"Q9288",
	"sem-can",
	aliases = {"Ivrit"},
	scripts = {"Hebr", "Phnx", "Brai"},
	entry_name = {
		from = {"[" .. u(0x0591) .. "-" .. u(0x05BD) .. u(0x05BF) .. "-" .. u(0x05C5) .. u(0x05C7) .. "]"},
		to   = {}} ,
}

m["hi"] = {
	"Hindi",
	"Q1568",
	"inc-hnd",
	otherNames = {"Hindavi"},
	scripts = {"Deva", "Kthi", "Newa"},
	ancestors = {"inc-ohi"},
	translit_module = "hi-translit",
	standardChars = "ँंअ-ऊएऐओ-घच-झट-नप-रलवशसहा-ूेैो-◌्।-॰ड़ढ़" .. PUNCTUATION,
}

m["ho"] = {
	"Hiri Motu",
	"Q33617",
	"crp",
	aliases = {"Pidgin Motu", "Police Motu"},
	scripts = Latn,
	ancestors = {"meu"},
}

m["ht"] = {
	"Haitian Creole",
	"Q33491",
	"crp",
	aliases = {"Creole", "Haitian", "Kreyòl"},
	scripts = Latn,
	ancestors = {"fr"},
}

m["hu"] = {
	"Hungarian",
	"Q9067",
	"urj-ugr",
	aliases = {"Magyar"},
	scripts = {"Latn", "Hung"},
	ancestors = {"ohu"},
	sort_key = {
		from = {"á", "é", "í", "ó", "ú", "[öő]", "[üű]", "cs", "dzs", "gy", "ly", "ny", "zs"},
		to   = {"a", "e", "i", "o", "u", "o~", "u~", "c~", "dz~", "g~", "l~", "n~", "z~"},
	},
}

m["hy"] = {
	"Armenian",
	"Q8785",
	"hyx",
	aliases = {"Modern Armenian"},
	varieties = {"Eastern Armenian", "Western Armenian"},
	scripts = {"Armn", "Brai"},
	ancestors = {"axm"},
	translit_module = "Armn-translit",
	override_translit = true,
	sort_key = {
		from = {"ու", "և", "եւ"},
		to   = {"ւ", "եվ", "եվ"}},
	entry_name = {
		from = {"՞", "՜", "՛", "՟", "և", "<sup>յ</sup>", "<sup>ի</sup>", "<sup>է</sup>"},
		to   = {"", "", "", "", "եւ", "յ", "ի", "է"}} ,
}

m["hz"] = {
	"Herero",
	"Q33315",
	"bnt-swb",
	scripts = Latn,
}

m["ia"] = {
	"Interlingua",
	"Q35934",
	"art",
	scripts = Latn,
}

m["id"] = {
	"Indonesian",
	"Q9240",
	"poz-mly",
	scripts = Latn,
	ancestors = {"ms"},
}

m["ie"] = {
	"Interlingue",
	"Q35850",
	"art",
	aliases = {"Occidental"},
	scripts = Latn,
	type = "appendix-constructed",
}

m["ig"] = {
	"Igbo",
	"Q33578",
	"alv-igb",
	scripts = Latn,
		sort_key = {
		from = {"ụ", "ị",  "ọ", "gb", "gh", "gw", "kp", "kw", "ṅ", "nw", "ny", "sh"},
		to   = {"u~" , "i~", "o~", "gy", "gz", "g~", "kz", "k~", "ny", "nz", "n~", "s~"}},
	entry_name = { remove_diacritics = ACUTE .. GRAVE .. MACRON },
}

m["ii"] = {
	"Sichuan Yi",
	"Q34235",
	"tbq-lol",
	aliases = {"Nuosu", "Nosu", "Northern Yi", "Liangshan Yi"},
	scripts = {"Yiii"},
	translit_module = "ii-translit",
}

m["ik"] = {
	"Inupiaq",
	"Q27183",
	"esx-inu",
	aliases = {"Inupiak", "Iñupiaq", "Inupiatun"},
	scripts = Latn,
}

m["io"] = {
	"Ido",
	"Q35224",
	"art",
	scripts = Latn,
}

m["is"] = {
	"Icelandic",
	"Q294",
	"gmq",
	scripts = Latn,
	ancestors = {"non"},
}

m["it"] = {
	"Italian",
	"Q652",
	"roa-itd",
	scripts = Latn,
	sort_key = {
		remove_diacritics = GRAVE .. ACUTE .. CIRC .. DIAER .. RINGABOVE,
	},
	standardChars = "A-IL-VZa-il-vz0-9" .. PUNCTUATION,
}

m["iu"] = {
	"Inuktitut",
	"Q29921",
	"esx-inu",
	varieties = {
		"Aivilimmiut",
		{"Eastern Canadian Inuktitut", "Eastern Canadian Inuit"},
		{"Inuinnaq", "Inuinnaqtun"},
		{"Inuvialuktun", "Inuvialuk", "Western Canadian Inuktitut", "Western Canadian Inuit", "Western Canadian Inuktun"},
		"Kivallirmiut",
		"Natsilingmiut", "Nunavimmiutit", "Nunatsiavummiut",
		{"Siglitun", "Siglit"}},
	scripts = {"Cans", "Latn"},
	translit_module = "translit-redirect",
	override_translit = true,
}

m["ja"] = {
	"Japanese",
	"Q5287",
	"jpx",
	aliases = {"Modern Japanese", "Nipponese", "Nihongo"},
	scripts = {"Jpan", "Brai"},
	ancestors = {"ojp"},
	--[=[
	-- Handled by jsort function in [[Module:ja]].
	sort_key = {
		from = {"[ぁァア]", "[ぃィイ]", "[ぅゔゥウヴ]", "[ぇェエ]", "[ぉォオ]", "[がゕカガヵ]", "[ぎキギ]", "[ぐクグㇰ]", "[げゖケゲヶ]", "[ごコゴ]", "[ざサザ]", "[じシジㇱ]", "[ずスズㇲ]", "[ぜセゼ]", "[ぞソゾ]", "[だタダ]", "[ぢチヂ]", "[っづッツヅ]", "[でテデ]", "[どトドㇳ]", "ナ", "ニ", "[ヌㇴ]", "ネ", "ノ", "[ばぱハバパㇵ]", "[びぴヒビピㇶ]", "[ぶぷフブプㇷ]", "[べぺヘベペㇸ]", "[ぼぽホボポㇹ]", "マ", "ミ", "[ムㇺ]", "メ", "モ", "[ゃャヤ]", "[ゅュユ]", "[ょョヨ]", "[ラㇻ]", "[リㇼ]", "[ルㇽ]", "[レㇾ]", "[ロㇿ]", "[ゎヮワヷ]", "[ヰヸ]", "[ヱヹ]", "[ヲヺ]", "ン", "[゙゚゛゜ゝゞ・ヽヾ]", "𛀀"},
		to   = {"あ", "い", "う", "え", "お", "か", "き", "く", "け", "こ", "さ", "し", "す", "せ", "そ", "た", "ち", "つ", "て", "と", "な", "に", "ぬ", "ね", "の", "は", "ひ", "ふ", "へ", "ほ", "ま", "み", "む", "め", "も", "や", "ゆ", "よ", "ら", "り", "る", "れ", "ろ", "わ", "ゐ", "ゑ", "を", "ん", "", "え"}},
	--]=]
}

m["jv"] = {
	"Javanese",
	"Q33549",
	"poz-sus",
	scripts = {"Latn", "Java"},
	translit_module = "jv-translit",
	ancestors = {"kaw"},
	link_tr = true,
}

m["ka"] = {
	"Georgian",
	"Q8108",
	"ccs-gzn",
	varieties = {{"Judeo-Georgian", "Kivruli", "Gruzinic"}},
	scripts = {"Geor", "Geok", "Hebr"}, -- Hebr is used to write Judeo-Georgian
	ancestors = {"oge"},
	translit_module = "Geor-translit",
	override_translit = true,
	entry_name = {
		from = {"̂"},
		to   = {""}},
}

m["kg"] = {
	"Kongo",
	"Q33702",
	"bnt-kng",
	aliases = {"Kikongo"},
	varieties = {"Koongo", "Laari", "San Salvador Kongo", "Yombe"},
	scripts = Latn,
}

m["ki"] = {
	"Kikuyu",
	"Q33587",
	"bnt-kka",
	aliases = {"Gikuyu", "Gĩkũyũ"},
	scripts = Latn,
}

m["kj"] = {
	"Kwanyama",
	"Q1405077",
	"bnt-ova",
	aliases = {"Kuanyama", "Oshikwanyama"},
	scripts = Latn,
}

m["kk"] = {
	"Kazakh",
	"Q9252",
	"trk-kno",
	scripts = {"Cyrl", "Latn", "kk-Arab"},
	translit_module = "kk-translit",
	override_translit = true,
}

m["kl"] = {
	"Greenlandic",
	"Q25355",
	"esx-inu",
	aliases = {"Kalaallisut"},
	scripts = Latn,
}

m["km"] = {
	"Khmer",
	"Q9205",
	"mkh-kmr",
	aliases = {"Cambodian"},
	scripts = {"Khmr"},
	ancestors = {"mkh-mkm"},
	translit_module = "km-translit",
}

m["kn"] = {
	"Kannada",
	"Q33673",
	"dra",
	scripts = {"Knda"},
	ancestors = {"dra-mkn"},
	translit_module = "kn-translit",
}

m["ko"] = {
	"Korean",
	"Q9176",
	"qfa-kor",
	aliases = {"Modern Korean"},
	scripts = {"Kore", "Brai"},
	ancestors = {"okm"},
	-- 20210122 idea: strip parenthesized hanja from entry link
	-- Hani regex is a reasonable subset of Hani from [[Module:scripts/data]],
	-- last updated on 20210214.
	entry_name = {
		from = {
			" *%([一-鿿㐀-䶿𠀀-𮯯𰀀-𱍏﨎﨏﨑﨓﨔﨟﨡﨣﨤﨧﨨﨩]+%)",
		},
		to   = {
			"",
		}},
	translit_module = "ko-translit",
}

m["kr"] = {
	"Kanuri",
	"Q36094",
	"ssa-sah",
	varieties = {"Kanembu", "Bilma Kanuri", "Central Kanuri", "Manga Kanuri", "Tumari Kanuri"},
	scripts = LatnArab,
	sort_key = {
		from = {"ny", "ǝ", "sh"},
		to   = {"n~", "e~", "s~"}} , -- the sortkey and entry_name are only for standard Kanuri; when dialectal entries get added, someone will have to work out how the dialects should be represented orthographically
	entry_name = {
		remove_diacritics = GRAVE .. ACUTE .. CIRC .. BREVE,
	},
}

m["ks"] = {
	"Kashmiri",
	aliases = {"Koshur"},
	"Q33552",
	"inc-dar",
	scripts = {"ks-Arab", "Deva", "Shrd", "Latn"},
	translit_module = "translit-redirect",
	ancestors = {"inc-dar-pro"},
}

-- "kv" IS TREATED AS "koi", "kpv", SEE WT:LT

m["kw"] = {
	"Cornish",
	"Q25289",
	"cel-bry",
	scripts = Latn,
	ancestors = {"cnx"},
}

m["ky"] = {
	"Kyrgyz",
	"Q9255",
	"trk-kip",
	aliases = {"Kirghiz", "Kirgiz"},
	scripts = {"Cyrl", "Latn", "Arab"},
	translit_module = "ky-translit",
	override_translit = true,
}

m["la"] = {
	"Latin",
	"Q397",
	"itc",
	scripts = Latn,
	ancestors = {"itc-ola"},
	entry_name = {remove_diacritics = MACRON .. BREVE .. DIAER .. DOUBLEINVBREVE},
	standardChars = "A-Za-z0-9ÆæŒœĀ-ăĒ-ĕĪ-ĭŌ-ŏŪ-ŭȲȳ" .. MACRON .. BREVE .. PUNCTUATION,
}

m["lb"] = {
	"Luxembourgish",
	"Q9051",
	"gmw",
	scripts = Latn,
	ancestors = {"gmh"},
}

m["lg"] = {
	"Luganda",
	"Q33368",
	"bnt-nyg",
	aliases = {"Ganda", "Oluganda"},
	scripts = Latn,
	entry_name = {
		remove_diacritics = ACUTE .. CIRC,
	},
	sort_key = {
		from = {"ŋ"},
		to   = {"n"}} ,
}

m["li"] = {
	"Limburgish",
	"Q102172",
	"gmw",
	aliases = {"Limburgan", "Limburgian", "Limburgic"},
	scripts = Latn,
	ancestors = {"dum"},
}

m["ln"] = {
	"Lingala",
	"Q36217",
	"bnt-bmo",
	aliases = {"Ngala"},
	scripts = Latn,
}

m["lo"] = {
	"Lao",
	"Q9211",
	"tai-swe",
	aliases = {"Laotian"},
	scripts = {"Laoo"},
	translit_module = "lo-translit",
	sort_key = {
		from = {"[%pໆ]", "[່-ໍ]", "ຼ", "ຽ", "ໜ", "ໝ", "([ເແໂໃໄ])([ກ-ຮ])"},
		to   = {"", "", "ລ", "ຍ", "ຫນ", "ຫມ", "%2%1"}},
	standardChars = "0-9ກຂຄງຈຊຍດຕຖທນບປຜຝພຟມຢຣລວສຫອຮຯ-ໝ" .. PUNCTUATION,
}

m["lt"] = {
	"Lithuanian",
	"Q9083",
	"bat",
	scripts = Latn,
	ancestors = {"olt"},
	entry_name = {
		remove_diacritics = ACUTE .. GRAVE .. TILDE,
	},
}

m["lu"] = {
	"Luba-Katanga",
	"Q36157",
	"bnt-lub",
	scripts = Latn,
}

m["lv"] = {
	"Latvian",
	"Q9078",
	"bat",
	aliases = {"Lettish", "Lett"},
	scripts = Latn,
	entry_name = {
		-- This attempts to convert vowels with tone marks to vowels either with
		-- or without macrons. Specifically, there should be no macrons if the
		-- vowel is part of a diphthong (including resonant diphthongs such
		-- pìrksts -> pirksts not #pīrksts). What we do is first convert the
		-- vowel + tone mark to a vowel + tilde in a decomposed fashion,
		-- then remove the tilde in diphthongs, then convert the remaining
		-- vowel + tilde sequences to macroned vowels, then delete any other
		-- tilde. We leave already-macroned vowels alone: Both e.g. ar and ār
		-- occur before consonants. FIXME: This still might not be sufficient.
		from = {"Ȩ", "ȩ", "[ÂÃÀ]", "[âãà]", "[ÊẼÈ]", "[êẽè]", "[ÎĨÌ]", "[îĩì]", "[ÔÕÒ]", "[ôõò]", "[ÛŨÙ]", "[ûũù]", "[ÑǸ]", "[ñǹ]", "[" .. CIRC .. TILDE ..GRAVE .."]", "([aAeEiIoOuU])" .. TILDE .."?([lrnmuiLRNMUI])" .. TILDE .. "?([^aAeEiIoOuUāĀēĒīĪūŪ])", "([aAeEiIoOuU])" .. TILDE .."?([lrnmuiLRNMUI])" .. TILDE .."?$", "([iI])" .. TILDE .. "?([eE])" .. TILDE .. "?", "A" .. TILDE, "a" .. TILDE, "E" .. TILDE, "e" .. TILDE, "I" .. TILDE, "i" .. TILDE, "U" .. TILDE, "u" .. TILDE, TILDE},
		to   = {"E", "e", "A" .. TILDE, "a" .. TILDE, "E" .. TILDE, "e" .. TILDE, "I" .. TILDE, "i" .. TILDE, "O", "o", "U" .. TILDE, "u" .. TILDE, "N", "n", TILDE, "%1%2%3", "%1%2", "%1%2", "Ā", "ā", "Ē", "ē", "Ī", "ī", "Ū", "ū", ""}},
}

m["mg"] = {
	"Malagasy",
	"Q7930",
	"poz-bre",
	varieties = {
		{"Antankarana", "Antankarana Malagasy"},
		{"Bara Malagasy", "Bara"}, {"Betsimisaraka Malagasy", "Betsimisaraka"}, {"Northern Betsimisaraka Malagasy", "Northern Betsimisaraka"}, {"Southern Betsimisaraka Malagasy", "Southern Betsimisaraka"}, {"Bushi", "Shibushi", "Kibushi"},
		{"Masikoro Malagasy", "Masikoro"},
		"Plateau Malagasy",
		"Sakalava",
		{"Tandroy Malagasy", "Tandroy"}, {"Tanosy", "Tanosy Malagasy"}, "Tesaka", {"Tsimihety", "Tsimihety Malagasy"}},
	scripts = Latn,
}

m["mh"] = {
	"Marshallese",
	"Q36280",
	"poz-mic",
	scripts = Latn,
	sort_key = {
		from = {"ā" , "ļ" , "m̧" , "ņ" , "n̄"  , "o̧" , "ō"  , "ū" },
		to   = {"a~", "l~", "m~", "n~", "n~~", "o~", "o~~", "u~"}} ,
}

m["mi"] = {
	"Maori",
	"Q36451",
	"poz-pep",
	aliases = {"Māori"},
	scripts = Latn,
}

m["mk"] = {
	"Macedonian",
	"Q9296",
	"zls",
	scripts = Cyrl,
	translit_module = "mk-translit",
	entry_name = {
		from = {ACUTE},
		to   = {}},
}

m["ml"] = {
	"Malayalam",
	"Q36236",
	"dra",
	scripts = {"Mlym"},
	translit_module = "ml-translit",
	override_translit = true,
}

m["mn"] = {
	"Mongolian",
	"Q9246",
	"xgn",
	varieties = {"Khalkha Mongolian"},
	scripts = {"Cyrl", "Mong", "Soyo", "Zanb"}, -- entries in Soyo or Zanb might require prior discussion
	ancestors = {"cmg"},
	translit_module = "mn-translit",
	override_translit = true,
}

-- "mo" IS TREATED AS "ro", SEE WT:LT

m["mr"] = {
	"Marathi",
	"Q1571",
	"inc-sou",
	scripts = {"Deva", "Modi"},
	ancestors = {"omr"},
	translit_module = "mr-translit",
}

m["ms"] = {
	"Malay",
	"Q9237",
	"poz-mly",
	aliases = {"Malaysian", "Standard Malay"},
	scripts = {"Latn", "ms-Arab"},
}

m["mt"] = {
	"Maltese",
	"Q9166",
	"sem-arb",
	scripts = Latn,
	ancestors = {"sqr"},
    sort_key = {
        from = {"ċ", "ġ", "ħ"},
        to = {"c", "g", "h"}
    }
}

m["my"] = {
	"Burmese",
	"Q9228",
	"tbq-brm",
	aliases = {"Myanmar"},
	varieties = {"Mandalay Burmese", "Myeik Burmese", "Palaw Burmese", {"Rangoon Burmese", "Yangon Burmese"}, "Yaw Burmese"},
	scripts = {"Mymr"},
	ancestors = {"obr"},
	translit_module = "my-translit",
	override_translit = true,
	sort_key = {
		from = {"ျ", "ြ", "ွ", "ှ", "ဿ"},
		to   = {"္ယ", "္ရ", "္ဝ", "္ဟ", "သ္သ"}},
}

m["na"] = {
	"Nauruan",
	"Q13307",
	"poz-mic",
	aliases = {"Nauru"},
	scripts = Latn,
}

m["nb"] = {
	"Norwegian Bokmål",
	"Q25167",
	"gmq",
	aliases = {"Bokmål"},
	scripts = Latn,
	ancestors = {"gmq-mno"},
	wikimedia_codes = {"no"},
}

m["nd"] = {
	"Northern Ndebele",
	"Q35613",
	"bnt-ngu",
	aliases = {"North Ndebele"},
	scripts = Latn,
	entry_name = {
		remove_diacritics = MACRON .. ACUTE .. GRAVE .. CIRC .. CARON,
	},
}

m["ne"] = {
	"Nepali",
	"Q33823",
	"inc-pah",
	aliases = {"Nepalese"},
	varieties = {"Palpa"}, -- "Q3832956", former "plp", retired by ISO as spurious
	scripts = {"Deva", "Newa"},
	translit_module = "ne-translit",
}

m["ng"] = {
	"Ndonga",
	"Q33900",
	"bnt-ova",
	scripts = Latn,
}

m["nl"] = {
	"Dutch",
	"Q7411",
	"gmw",
	varieties = {"Netherlandic", "Flemish"}, -- FIXME, check this
	scripts = Latn,
	ancestors = {"dum"},
	sort_key = {
		from = {"[äáâå]", "[ëéê]", "[ïíî]", "[öóô]", "[üúû]", "ç", "ñ", "^-"},
		to   = {"a"	 , "e"	, "i"	, "o"	, "u"	, "c", "n"}} ,
	standardChars = "A-Za-z0-9" .. PUNCTUATION .. u(0x2800) .. "-" .. u(0x28FF),
}

m["nn"] = {
	"Norwegian Nynorsk",
	"Q25164",
	"gmq",
	aliases = {"New Norwegian", "Nynorsk"},
	scripts = Latn,
	ancestors = {"gmq-mno"},
}

m["no"] = {
	"Norwegian",
	"Q9043",
	"gmq",
	scripts = Latn,
	ancestors = {"gmq-mno"},
}

m["nr"] = {
	"Southern Ndebele",
	"Q36785",
	"bnt-ngu",
	aliases = {"South Ndebele"},
	scripts = Latn,
	entry_name = {
		remove_diacritics = MACRON .. ACUTE .. GRAVE .. CIRC .. CARON,
	},
}

m["nv"] = {
	"Navajo",
	"Q13310",
	"apa",
	aliases = {"Navaho", "Diné bizaad"},
	scripts = Latn,
	sort_key = {
		from = {"[áą]", "[éę]", "[íį]", "[óǫ]", "ń", "^n([djlt])", "ł" , "[ʼ’']", ACUTE},
		to   = {"a"   , "e"   , "i"   , "o"   , "n", "ni%1"	  , "l~"}}, -- the tilde is used to guarantee that ł will always be sorted after all other words with l
}

m["ny"] = {
	"Chichewa",
	"Q33273",
	"bnt-nys",
	aliases = {"Chicheŵa", "Chinyanja", "Nyanja", "Chewa", "Cicewa", "Cewa", "Cinyanja"},
	scripts = Latn,
	entry_name = {
		from = {"ŵ", "Ŵ", "á", "Á", "é", "É", "í", "Í", "ó", "Ó", "ú", "Ú", "ń", "Ń", "ḿ", "Ḿ" },
		to   = {"w", "W", "a", "A", "e", "E", "i", "I", "o", "O", "u", "U", "n", "N", "m", "M"}},
	sort_key = {
		from = {"ng'"},
		to   = {"ng"}} ,
}

m["oc"] = {
	"Occitan",
	"Q14185",
	"roa",
	-- don't list varieties here that are in [[Module:etymology languages/data]]
	scripts = {"Latn", "Hebr"},
	ancestors = {"pro"},
	sort_key = {
		from = {"[àá]", "[èé]", "[íï]", "[òó]", "[úü]", "ç", "([lns])·h"},
		to   = {"a"   , "e"   , "i"   , "o"   , "u"   , "c", "%1h"	  }} ,
}

m["oj"] = {
	"Ojibwe",
	"Q33875",
	"alg",
	aliases = {"Ojibway", "Ojibwa"},
	varieties = {{"Chippewa", "Ojibwemowin", "Southwestern Ojibwa"}},
	scripts = {"Cans", "Latn"},
	sort_key = {
		from = {"aa", "ʼ",  "ii", "oo", "sh", "zh"},
		to   = {"a~", "h~", "i~", "o~", "s~", "z~"}} ,
}

m["om"] = {
	"Oromo",
	"Q33864",
	"cus",
	varieties = {"Orma", "Borana-Arsi-Guji Oromo", "West Central Oromo"},
	scripts = {"Latn", "Ethi"},
}

m["or"] = {
	"Oriya",
	"Q33810",
	"inc-eas",
	aliases = {"Odia", "Oorya"},
	scripts = {"Orya"},
	ancestors = {"inc-mor"},
	translit_module = "or-translit",
}

m["os"] = {
	"Ossetian",
	"Q33968",
	"xsc",
	aliases = {"Ossete", "Ossetic"},
	varieties = {"Digor", "Iron"},
	scripts = {"Cyrl", "Geor", "Latn"},
	ancestors = {"oos"},
	translit_module = "os-translit",
	override_translit = true,
	entry_name = {
		from = {GRAVE, ACUTE},
		to   = {}} ,
}

m["pa"] = {
	"Punjabi",
	"Q58635",
	"inc-pan",
	aliases = {"Panjabi"},
	scripts = {"Guru", "pa-Arab"},
	ancestors = {"inc-opa"},
	translit_module = "translit-redirect",
	entry_name = {
		from = {u(0x064B), u(0x064C), u(0x064D), u(0x064E), u(0x064F), u(0x0650), u(0x0651), u(0x0652)},
		to   = {}} ,
}

m["pi"] = {
	"Pali",
	"Q36727",
	"pra",
	scripts = {"Latn", "Brah", "Deva", "Beng", "Sinh", "Mymr", "Thai", "Lana", "Laoo", "Khmr"},
	ancestors = {"sa"},
	translit_module = "translit-redirect",
	sort_key = {
		from = {"ā", "ī", "ū", "ḍ", "ḷ", "[ṁṃ]", "ṅ", "ñ", "ṇ", "ṭ", "([เโ])([ก-ฮ])", "([ເໂ])([ກ-ຮ])", "ᩔ", "ᩕ", "ᩖ", "ᩘ", "([ᨭ-ᨱ])ᩛ", "([ᨷ-ᨾ])ᩛ", "ᩤ", u(0xFE00), u(0x200D)},
		to   = {"a~", "i~", "u~", "d~", "l~", "m~", "n~", "n~~", "n~~~", "t~", "%2%1", "%2%1", "ᩈ᩠ᩈ", "᩠ᩁ", "᩠ᩃ", "ᨦ᩠", "%1᩠ᨮ", "%1᩠ᨻ", "ᩣ"}} ,
	entry_name = {
		from = {u(0xFE00)},
		to   = {}},
}

m["pl"] = {
	"Polish",
	"Q809",
	"zlw-lch",
	scripts = Latn,
	ancestors = {"zlw-opl"},
	sort_key = {
		from = {"[Ąą]", "[Ćć]", "[Ęę]", "[Łł]", "[Ńń]", "[Óó]", "[Śś]", "[Żż]", "[Źź]"},
		to   = {
			"a" .. u(0x10FFFF),
			"c" .. u(0x10FFFF),
			"e" .. u(0x10FFFF),
			"l" .. u(0x10FFFF),
			"n" .. u(0x10FFFF),
			"o" .. u(0x10FFFF),
			"s" .. u(0x10FFFF),
			"z" .. u(0x10FFFF),
			"z" .. u(0x10FFFE)}} ,
}

m["ps"] = {
	"Pashto",
	"Q58680",
	"ira-pat",
	aliases = {"Pashtun", "Pushto", "Pashtu", "Afghani"},
	varieties = {"Central Pashto", "Northern Pashto", "Southern Pashto", {"Pukhto", "Pakhto", "Pakkhto"}},
	scripts = {"ps-Arab"},
	ancestors = {"ira-pat-pro"},
}

m["pt"] = {
	"Portuguese",
	"Q5146",
	"roa-ibe",
	aliases = {"Modern Portuguese"},
	scripts = {"Latn", "Brai"},
	ancestors = {"roa-opt"},
	sort_key = {
		remove_diacritics = GRAVE .. TILDE .. ACUTE .. CIRC .. DIAER .. CEDILLA,
	},
}

m["qu"] = {
	"Quechua",
	"Q5218",
	"qwe",
	scripts = Latn,
}

m["rm"] = {
	"Romansch",
	"Q13199",
	"roa-rhe",
	aliases = {"Romansh", "Rumantsch", "Romanche"},
	scripts = Latn,
}

m["ro"] = {
	"Romanian",
	"Q7913",
	"roa-eas",
	aliases = {"Daco-Romanian", "Roumanian", "Rumanian"},
	scripts = {"Latn", "Cyrl"},
	sort_key = {
		from = {"ă" , "â"  , "î" , "ș" , "ț" },
		to   = {"a~", "a~~", "i~", "s~", "t~"}},
}

m["ru"] = {
	"Russian",
	"Q7737",
	"zle",
	scripts = {"Cyrl", "Brai"},
	translit_module = "ru-translit",
	sort_key = {
		from = {"ё"},
		to   = {"е" .. mw.ustring.char(0x10FFFF)}},
	entry_name = {
		from = {"Ѐ", "ѐ", "Ѝ", "ѝ", GRAVE, ACUTE, DIAER},
		to   = {"Е", "е", "И", "и"}},
	standardChars = "ЁА-яё0-9—" .. PUNCTUATION,
}

m["rw"] = {
	"Rwanda-Rundi",
	"Q3217514",
	"bnt-glb",
	-- don't list varieties here that are in [[Module:etymology languages/data]]
	varieties = {{"Ha", "Giha"}, "Hangaza", "Vinza", "Shubi"}, -- Deleted "Subi", which normally refers to a different language
	scripts = Latn,
	entry_name = {
		remove_diacritics = ACUTE .. MACRON .. CIRC .. CARON,
	},
}

m["sa"] = {
	"Sanskrit",
	"Q11059",
	"inc-old",
	scripts = {"Deva", "Bali", "as-Beng", "Beng", "Bhks", "Brah", "Gran", "Gujr", "Guru", "Java", "Khar", "Khmr", "Knda", "Lana", "Laoo", "Mlym", "Modi", "Mymr", "Newa", "Orya", "Saur", "Shrd", "Sidd", "Sinh", "Taml", "Telu", "Thai", "Tibt", "Tirh"},
	sort_key = {
		from = {"ā", "ī", "ū", "ḍ", "ḷ", "ḹ", "[ṁṃ]", "ṅ", "ñ", "ṇ", "ṛ", "ṝ", "ś", "ṣ", "ṭ", "([เโไ])([ก-ฮ])", "([ເໂໄ])([ກ-ຮ])", "ᩔ", "ᩕ", "ᩖ", "ᩘ", "([ᨭ-ᨱ])ᩛ", "([ᨷ-ᨾ])ᩛ", "ᩤ", u(0xFE00), u(0x200D)},
		to   = {"a~", "i~", "u~", "d~", "l~", "l~~", "m~", "n~", "n~~", "n~~~", "r~", "r~~", "s~", "s~~", "t~", "%2%1", "%2%1", "ᩈ᩠ᩈ", "᩠ᩁ", "᩠ᩃ", "ᨦ᩠", "%1᩠ᨮ", "%1᩠ᨻ", "ᩣ"}} ,
	entry_name = {
		from = {u(0xFE00)},
		to   = {}},
	translit_module = "translit-redirect",
}

m["sc"] = {
	"Sardinian",
	"Q33976",
	"roa",
	-- don't list varieties here that are in [[Module:etymology languages/data]]
	scripts = Latn,
}

m["sd"] = {
	"Sindhi",
	"Q33997",
	"inc-snd",
	scripts = {"sd-Arab", "Deva", "Sind", "Khoj"},
	entry_name = {
		from = {u(0x0671), u(0x064B), u(0x064C), u(0x064D), u(0x064E), u(0x064F), u(0x0650), u(0x0651), u(0x0652), u(0x0670), u(0x0640)},
		to   = {u(0x0627)}},
	ancestors = {"inc-vra"},
}

m["se"] = {
	"Northern Sami",
	"Q33947",
	"smi",
	aliases = {"North Sami", "Northern Saami", "North Saami"},
	scripts = Latn,
	entry_name = {
		from = {"ạ", "[ēẹ]", "ī", "[ōọ]", "ū", "ˈ"},
		to   = {"a", "e"   , "i", "o"   , "u"} },
	sort_key = {
		from = {"á" , "č" , "đ" , "ŋ" , "š" , "ŧ" , "ž" },
		to   = {"a²", "c²", "d²", "n²", "s²", "t²", "z²"} },
	standardChars = "A-PR-VZa-pr-vz0-9ÁáČčĐđŊŋŠšŦŧŽž" .. PUNCTUATION,
}

m["sg"] = {
	"Sango",
	"Q33954",
	"crp",
	scripts = Latn,
	ancestors = {"ngb"},
}

m["sh"] = {
	"Serbo-Croatian",
	"Q9301",
	"zls",
	aliases = {"BCS", "Croato-Serbian", "Serbocroatian"},
	-- don't list varieties here that are in [[Module:etymology languages/data]]
	varieties = {"Bosnian", "Croatian", "Montenegrin", "Serbian", "Shtokavian"},
	scripts = {"Latn", "Cyrl", "Glag"},
	entry_name = {
		remove_diacritics = GRAVE .. ACUTE .. DGRAVE .. INVBREVE .. MACRON .. TILDE,
	},
	wikimedia_codes = {"sh", "bs", "hr", "sr"},
}

m["si"] = {
	"Sinhalese",
	"Q13267",
	"inc-ins",
	aliases = {"Singhalese", "Sinhala"},
	scripts = {"Sinh"},
	ancestors = {"elu-prk"},
	translit_module = "si-translit",
	override_translit = true,
}

m["sk"] = {
	"Slovak",
	"Q9058",
	"zlw",
	scripts = Latn,
	sort_key = {
		remove_diacritics = DIAER .. ACUTE .. CIRC,
	},
}

m["sl"] = {
	"Slovene",
	"Q9063",
	"zls",
	aliases = {"Slovenian"},
	scripts = Latn,
	entry_name = {
		remove_diacritics = GRAVE .. ACUTE .. CIRC .. MACRON .. DGRAVE .. INVBREVE .. DOTBELOW,
		from = {"ł"},
		to   = {"l"},
	},
	sort_key = {
		from = {"č" , "š" , "ž" },
		to   = {"c²", "s²", "z²"},
	},
}

m["sm"] = {
	"Samoan",
	"Q34011",
	"poz-pnp",
	scripts = Latn,
}

m["sn"] = {
	"Shona",
	"Q34004",
	"bnt-sho",
	scripts = Latn,
	entry_name = {remove_diacritics = ACUTE},
}

m["so"] = {
	"Somali",
	"Q13275",
	"cus",
	scripts = {"Latn", "Arab", "Osma"},
	entry_name = { remove_diacritics = ACUTE .. GRAVE .. CIRC },
}

m["sq"] = {
	"Albanian",
	"Q8748",
	"sqj",
	-- don't list varieties here that are in [[Module:etymology languages/data]]
	scripts = {"Latn", "Grek", "Elba"},
	entry_name = {remove_diacritics = ACUTE},
	sort_key = {
		from = { '[âãä]', '[ÂÃÄ]', '[êẽë]', '[ÊẼË]', 'ĩ', 'Ĩ', 'õ', 'Õ', 'ũ', 'Ũ', 'ỹ', 'Ỹ', 'ç', 'Ç' },
		to   = {     'a',     'A',     'e',     'E', 'i', 'I', 'o', 'O', 'u', 'U', 'y', 'Y', 'c', 'C' } } ,
}

m["ss"] = {
	"Swazi",
	"Q34014",
	"bnt-ngu",
	aliases = {"Swati"},
	scripts = Latn,
	entry_name = { remove_diacritics = MACRON .. ACUTE .. GRAVE .. CIRC .. CARON },
}

m["st"] = {
	"Sotho",
	"Q34340",
	"bnt-sts",
	aliases = {"Sesotho", "Southern Sesotho", "Southern Sotho"},
	scripts = Latn,
	entry_name = { remove_diacritics = MACRON .. ACUTE .. GRAVE .. CIRC .. CARON },
}

m["su"] = {
	"Sundanese",
	"Q34002",
	"poz-msa",
	scripts = {"Latn", "Sund"},
	translit_module = "su-translit",
}

m["sv"] = {
	"Swedish",
	"Q9027",
	"gmq",
	scripts = Latn,
	ancestors = {"gmq-osw"},
}

m["sw"] = {
	"Swahili",
	"Q7838",
	"bnt-swh",
	varieties = {{"Settler Swahili", "KiSetla", "KiSettla", "Setla", "Settla", "Kitchen Swahili"}, {"Kihindi", "Indian Swahili"}, {"KiShamba", "Kishamba", "Field Swahili"}, {"Kibabu", "Asian Swahili"}, {"Kimanga", "Arab Swahili"}, {"Kitvita", "Army Swahili"}},
	scripts = LatnArab,
	sort_key = {
		from = {"ng'", "^-"},
		to   = {"ngz"}} ,
}

m["ta"] = {
	"Tamil",
	"Q5885",
	"dra",
	scripts = {"Taml"},
	ancestors = {"oty"},
	translit_module = "ta-translit",
	override_translit = true,
}

m["te"] = {
	"Telugu",
	"Q8097",
	"dra",
	scripts = {"Telu"},
	translit_module = "te-translit",
	override_translit = true,
}

m["tg"] = {
	"Tajik",
	"Q9260",
	"ira-swi",
	aliases = {"Eastern Persian", "Tadjik", "Tadzhik", "Tajiki", "Tajik Persian", "Tajiki Persian"},
	scripts = {"Cyrl", "fa-Arab", "Latn"},
	ancestors = {"pal"}, -- same as "fa", see WT:T:AFA
	translit_module = "tg-translit",
	override_translit = true,
	sort_key = {
		from = {"Ё", "ё"},
		to   = {"Е" , "е"}} ,
	entry_name = {
		from = {ACUTE},
		to   = {}} ,
}

m["th"] = {
	"Thai",
	"Q9217",
	"tai-swe",
	aliases = {"Central Thai", "Siamese"},
	scripts = {"Thai", "Brai"},
	translit_module = "th-translit",
	sort_key = {
		from = {"[%pๆ]", "[็-๎]", "([เแโใไ])([ก-ฮ])"},
		to   = {"", "", "%2%1"}},
}

m["ti"] = {
	"Tigrinya",
	"Q34124",
	"sem-eth",
	aliases = {"Tigrigna"},
	scripts = {"Ethi"},
	translit_module = "Ethi-translit",
}

m["tk"] = {
	"Turkmen",
	"Q9267",
	"trk-ogz",
	scripts = {"Latn", "Cyrl", "Arab"},
	entry_name = { remove_diacritics = MACRON },
	ancestors = {"trk-ogz-pro"},
}

m["tl"] = {
	"Tagalog",
	"Q34057",
	"phi",
	scripts = {"Latn", "Tglg"},
	entry_name = { remove_diacritics = ACUTE .. GRAVE .. CIRC },
}

m["tn"] = {
	"Tswana",
	"Q34137",
	"bnt-sts",
	aliases = {"Setswana"},
	scripts = Latn,
}

m["to"] = {
	"Tongan",
	"Q34094",
	"poz-pol",
	scripts = Latn,
	sort_key = { remove_diacritics = MACRON },
	entry_name = { remove_diacritics = ACUTE },
}

m["tr"] = {
	"Turkish",
	"Q256",
	"trk-ogz",
	scripts = Latn,
	ancestors = {"ota"},
}

m["ts"] = {
	"Tsonga",
	"Q34327",
	"bnt-tsr",
	aliases = {"Xitsonga"},
	scripts = Latn,
}

m["tt"] = {
	"Tatar",
	"Q25285",
	"trk-kbu",
	scripts = {"Cyrl", "Latn", "tt-Arab"},
	translit_module = "tt-translit",
	override_translit = true,
}

-- "tw" IS TREATED AS "ak", SEE WT:LT

m["ty"] = {
	"Tahitian",
	"Q34128",
	"poz-pep",
	scripts = Latn,
}

m["ug"] = {
	"Uyghur",
	"Q13263",
	"trk-kar",
	aliases = {"Uigur", "Uighur", "Uygur"},
	scripts = {"ug-Arab", "Latn", "Cyrl"},
	ancestors = {"chg"},
	translit_module = "ug-translit",
	override_translit = true,
}

m["uk"] = {
	"Ukrainian",
	"Q8798",
	"zle",
	scripts = Cyrl,
	ancestors = {"orv"},
	translit_module = "uk-translit",
	entry_name = {
		from = {"Ѐ", "ѐ", "Ѝ", "ѝ", GRAVE, ACUTE},
		to   = {"Е", "е", "И", "и"}},
	standardChars = "ЄІЇА-ЩЬЮ-щьюяєії" .. PUNCTUATION,
} 
m["ur"] = {
	"Urdu",
	"Q1617",
	"inc-hnd",
	scripts = {"ur-Arab"},
	ancestors = {"inc-ohi"},
	entry_name = {
		from = {u(0x064B), u(0x064C), u(0x064D), u(0x064E), u(0x064F), u(0x0650), u(0x0651), u(0x0652), u(0x0658)},
		to   = {}} ,
}

m["uz"] = {
	"Uzbek",
	"Q9264",
	"trk-kar",
	varieties = {"Northern Uzbek", "Southern Uzbek"},
	scripts = {"Latn", "Cyrl", "fa-Arab"},
	ancestors = {"chg"},
}

m["ve"] = {
	"Venda",
	"Q32704",
	"bnt-bso",
	scripts = Latn,
}

m["vi"] = {
	"Vietnamese",
	"Q9199",
	"mkh-vie",
	aliases = {"Annamese", "Annamite"},
	scripts = {"Latn", "Hani"},
	ancestors = {"mkh-mvi"},
	sort_key = "vi-sortkey",
}

m["vo"] = {
	"Volapük",
	"Q36986",
	"art",
	scripts = Latn,
}

m["wa"] = {
	"Walloon",
	"Q34219",
	"roa-oil",
	varieties = {"Liégeois", "Namurois", "Wallo-Picard", "Wallo-Lorrain"},
	scripts = Latn,
	ancestors = {"fro"},
	sort_key = {
		from = {"[áàâäå]", "[éèêë]", "[íìîï]", "[óòôö]", "[úùûü]", "[ýỳŷÿ]", "ç", "'"},
		to   = {"a"	  , "e"	 , "i"	 , "o"	 , "u"	 , "y"	 , "c"}} ,
}

m["wo"] = {
	"Wolof",
	"Q34257",
	"alv-fwo",
	varieties = {"Gambian Wolof"}, -- the subsumed dialect 'wof'
	scripts = LatnArab,
}

m["xh"] = {
	"Xhosa",
	"Q13218",
	"bnt-ngu",
	scripts = Latn,
	entry_name = { remove_diacritics = ACUTE .. GRAVE .. MACRON .. CIRC .. CARON},
}

m["yi"] = {
	"Yiddish",
	"Q8641",
	"gmw",
	varieties = {"American Yiddish", "Daytshmerish Yiddish", "Mideastern Yiddish", "Galitzish",
		{"Northeastern Yiddish", "Litvish", "Lithuanian Yiddish"},
		{"Northwestern Yiddish", "Netherlandic Yiddish"},
		{"Polish Yiddish", "Poylish"},
		"South African Yiddish",
		{"Southeastern Yiddish", "Ukrainian Yiddish", "Ukrainish"},
		{"Southwestern Yiddish", "Judeo-Alsatian"},
		"Udmurtish"
	},
	scripts = {"Hebr"},
	ancestors = {"gmh"},
	sort_key = {
		from = {"[אַאָ]", "בּ", "[וֹוּ]", "יִ", "ײַ", "פֿ"},
		to = {"א", "ב", "ו", "י",	"יי", "פ"}} ,
	translit_module = "yi-translit",
}

m["yo"] = {
	"Yoruba",
	"Q34311",
	"alv-yor",
	scripts = Latn,
	sort_key = {
		from = {"ẹ",   "ọ", "gb", "ṣ"},
		to   = {"e~" , "o~", "g~", "s~"}},
	entry_name = { remove_diacritics = ACUTE .. GRAVE .. MACRON },
}

m["za"] = {
	"Zhuang",
	"Q13216",
	"tai",
	-- FIXME, are all of the following distinct?
	varieties = {
		"Chongzuo Zhuang",
		"Guibei Zhuang", "Guibian Zhuang",
		"Central Hongshuihe Zhuang", "Eastern Hongshuihe Zhuang",
		"Lianshan Zhuang", "Liujiang Zhuang", "Liuqian Zhuang",
		{"Min Zhuang", "Minz Zhuang"},
		"Nong Zhuang", -- see zhn
		"Qiubei Zhuang",
		"Shangsi Zhuang",
		{"Dai Zhuang", "Wenma", "Wenma Thu", "Wenma Zhuang"},
		"Yang Zhuang",
		{"Yongbei Zhuang", "Wuming Zhuang", "Standard Zhuang"},
		"Yongnan Zhuang", "Youjiang Zhuang",
		"Zuojiang Zhuang"},
	scripts = {"Latn", "Hani"},
	sort_key = {
		from = {"%p"},
		to   = {""}},
}

m["zh"] = {
	"Chinese",
	"Q7850",
	"zhx",
	scripts = {"Hani", "Brai", "Nshu"},
	ancestors = {"ltc"},
	sort_key = "zh-sortkey",
}

m["zu"] = {
	"Zulu",
	"Q10179",
	"bnt-ngu",
	aliases = {"isiZulu"},
	scripts = Latn,
	entry_name = { remove_diacritics = ACUTE .. GRAVE .. MACRON .. CIRC .. CARON},
}

return m
