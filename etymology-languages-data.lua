local m = {}

-- Akan varieties

m["tw"] = {
	"Twi Akan",
	36850,
	"ak",
	aliases = {"Twi"},
}

m["tw-abr"] = {
	"Bono Twi",
	34831,
	"tw",
	aliases = {"Bono", "Abron", "Brong"},
}

m["tw-asa"] = {
	"Asante Twi",
	19261685,
	"tw",
	aliases = {"Asante", "Ashanti", "Ashante"},
}

m["tw-aku"] = {
	"Akuapem Twi",
	31150449,
	"tw",
	aliases = {"Akuapem", "Akuapim", "Akwapem Twi", "Akwapi"},
}

m["fat"] = {
	"Fante Akan",
	35570,
	"ak",
	aliases = {"Fante", "Fanti", "Fantse", "Mfantse"},
}

-- Albanian varieties

m["aln"] = {
	"Gheg Albanian",
	181037,
	"sq",
	aliases = {"Gheg"},
}

m["aae"] = {
	"Arbëresh Albanian",
	1075302,
	"als",
	aliases = {"Arbëreshë", "Arbëresh"},
}

m["aat"] = {
	"Arvanitika Albanian",
	29347,
	"als",
	aliases = {"Arvanitika"},
}

m["als"] = {
	"Tosk Albanian",
	180937,
	"sq",
	aliases = {"Tosk"},
}

-- Bantu varieties

m["bnt-cmn"] = {
	"Common Bantu",
	nil,
	"bnt-pro",
}

-- Semitic varieties

-- Akkadian varieties

m["akk-old"] = {
	"Old Akkadian",
	nil,
	"akk",
}

m["akk-obb"] = {
	"Old Babylonian",
	nil,
	"akk",
}

m["akk-oas"] = {
	"Old Assyrian",
	nil,
	"akk",
}

m["akk-mbb"] = {
	"Middle Babylonian",
	nil,
	"akk",
}

m["akk-mas"] = {
	"Middle Assyrian",
	nil,
	"akk",
}

m["akk-nbb"] = {
	"Neo-Babylonian",
	nil,
	"akk",
}

m["akk-nas"] = {
	"Neo-Assyrian",
	nil,
	"akk",
}

m["akk-lbb"] = {
	"Late Babylonian",
	nil,
	"akk",
}

m["akk-stb"] = {
	"Standard Babylonian",
	nil,
	"akk",
}

-- Arabic varieties

m["jrb"] = {
	"Judeo-Arabic",
	37733,
	"ar",
}

-- Aramaic varieties

m["arc-bib"] = {
	"Biblical Aramaic",
	843235,
	"arc",
	family = "sem-are",
}

m["arc-cpa"] = {
	"Christian Palestinian Aramaic",
	60790119,
	"arc",
	family = "sem-arw",
	aliases = {"Melkite Aramaic", "Palestinian Syriac", "Syropalestinian Aramaic"},
}

m["arc-imp"] = {
	"Imperial Aramaic",
	7079491,
	"arc",
	aliases = {"Official Aramaic"},
}

m["arc-hat"] = {
	"Hatran Aramaic",
	3832926,
	"arc",
	family = "sem-are",
}

m["arc-jla"] = {
	"Jewish Literary Aramaic",
	105952842,
	"arc",
}

m["arc-nab"] = {
	"Nabataean Aramaic",
	36178,
	"arc",
}

m["arc-old"] = {
	"Old Aramaic",
	3398392,
	"arc",
}

m["arc-pal"] = {
	"Palmyrene Aramaic",
	1510113,
	"arc",
	family = "sem-arw",
}

m["tmr"] = {
	"Jewish Babylonian Aramaic",
	33407,
	"arc",
	family = "sem-ase",
}

m["jpa"] = {
	"Jewish Palestinian Aramaic",
	948909,
	"arc",
	family = "sem-arw",
	aliases = {"Galilean Aramaic"},
}

-- Catalan varieties

m["ca-val"] = {
	"Valencian",
	32641,
	"ca",
}

-- Central Nicobarese varieties

m["ncb-cam"] = {
	"Camorta",
	5026908,
	"ncb",
	aliases = {"Kamorta"},
}

m["ncb-kat"] = {
	"Katchal",
	17064263,
	"ncb",
	aliases = {"Tehnu"},
}

m["ncb-nan"] = {
	"Nancowry",
	6962504,
	"ncb",
	aliases = {"Nankwari"},
}

-----------------------------------------------------
--                Chinese varieties                --
-----------------------------------------------------

------------- Old Chinese, Middle Chinese -------------

m["och-ear"] = {
	"Early Old Chinese",
	nil,
	"och",
}

m["och-lat"] = {
	"Late Old Chinese",
	nil,
	"och",
}

m["ltc-ear"] = {
	"Early Middle Chinese",
	nil,
	"ltc",
}

m["ltc-lat"] = {
	"Late Middle Chinese",
	nil,
	"ltc",
}

------------- Classical/Literary varieties -------------

-- FIXME: Temporary.
m["lzh-cip"] = {
	"Ci",
	1091366,
	"lzh",
}

-- FIXME: Temporary.
m["lzh-yue"] = {
	"Classical Cantonese",
	nil,
	"lzh",
}

-- FIXME: Temporary.
m["lzh-cmn"] = {
	"Classical Mandarin",
	nil,
	"lzh",
}

-- FIXME: Temporary.
m["lzh-tai"] = {
	"Classical Taishanese",
	nil,
	"lzh",
}

-- FIXME: Temporary.
m["lzh-cmn-TW"] = {
	"Classical Taiwanese Mandarin",
	nil,
	"lzh-cmn",
}

-- FIXME: Temporary. FIXME: Do we need this? How does it differ from Old Chinese?
m["lzh-pre"] = {
	"Pre-Classical Chinese",
	nil,
	"lzh",
}

------------- Written Vernacular varieties -------------

-- FIXME: Temporary.
m["cmn-wvc"] = {
	"Written vernacular Mandarin",
	783605,
	"cmn",
}

-- FIXME: Temporary. FIXME: How does this differ from "Literary Cantonese"?
m["yue-wvc"] = {
	"Written vernacular Cantonese",
	nil,
	"yue",
}

-- FIXME: Temporary.
m["zhx-tai-wvc"] = {
	"Written vernacular Taishanese",
	nil,
	"zhx-tai",
}

------------- Mandarin varieties -------------

-- FIXME: Temporary. NOTE: The Linguist List assigns the "w:Beijing dialect" (Wikidata 1147606) the code "cmn-bej" and the
-- larger "w:Beijing Mandarin (division of Mandarin)" (Wikidata 2169652) dialect group the code "cmn-bei". We may need to
-- split this at some point to account for this.
m["cmn-bei"] = {
	"Beijing Mandarin",
	1147606,
	"cmn",
}

-- FIXME: Temporary. NOTE: The Linguist List uses the code cmn-zho.
m["cmn-cep"] = {
	"Central Plains Mandarin",
	3048775,
	"cmn",
	aliases = {"Zhongyuan Mandarin"},
}

m["cmn-ear"] = {
	"Early Mandarin",
	837169,
	"cmn",
	ancestors = "ltc",
}

-- FIXME: Temporary.
m["cmn-gua"] = {
	"Guanzhong Mandarin",
	3431648,
	"cmn-cep",
}

-- FIXME: Temporary. Appears to be a subdialect of Guiliu Mandarin, which in turn is a subdialect of Southwestern Mandarin.
m["cmn-gui"] = {
	"Guilin Mandarin",
	11111636,
	"cmn",
}

m["cmn-jhu"] = {
	"Jianghuai Mandarin",
	2128953,
	"cmn",
	aliases = {"Lower Yangtze Mandarin"},
}

-- FIXME: Temporary.
m["cmn-lan"] = {
	"Lanyin Mandarin",
	662754,
	"cmn",
}

-- FIXME: Temporary.
m["cmn-MY"] = {
	"Malaysian Mandarin",
	13646143,
	"cmn",
}

-- FIXME: Temporary.
m["cmn-nan"] = {
	"Nanjing Mandarin",
	2681098,
	"cmn-jhu",
}

-- FIXME: Temporary.
m["cmn-noe"] = {
	"Northeastern Mandarin",
	1064504,
	"cmn",
}

-- FIXME: Temporary.
m["cmn-PH"] = {
	"Philippine Mandarin",
	7185155,
	"cmn",
}

-- FIXME: Temporary.
m["cmn-SG"] = {
	"Singapore Mandarin",
	1048980,
	"cmn",
}

-- FIXME: Temporary.
m["cmn-sow"] = {
	"Southwestern Mandarin",
	2609239,
	"cmn",
}

-- FIXME: Temporary. Appears to be a subdialect of Jilu Mandarin.
m["cmn-tia"] = {
	"Tianjin Mandarin",
	7800220,
	"cmn",
}

-- FIXME: Temporary. NOTE: Wikidata also has Q4380827 "Taiwanese Mandarin", defined as "rare dialect of Standard Chinese
-- (Mandarin) used in Taiwan, which is strongly influenced by Taiwanese Hokkien; mostly used by elderlies" and having no
-- English Wikipedia article (but see w:zh:臺灣國語).
m["cmn-TW"] = {
	"Taiwanese Mandarin",
	262828,
	"cmn",
}

-- FIXME: Temporary. Appears to be a subdialect of Wu-Tian Mandarin, in turn a subdialect of Southwestern Mandarin.
-- Given the code cmn-xwu in the Linguist List.
m["cmn-wuh"] = {
	"Wuhan Mandarin",
	11124731,
	"cmn-sow",
	aliases = {"Wuhanese"},
}

-- FIXME: Temporary. Appears to be a subdialect of Lanyin Mandarin.
m["cmn-xin"] = {
	"Xining Mandarin",
	nil,
	"cmn-lan",
}

-- FIXME: Temporary.
m["cmn-yan"] = {
	"Yangzhou Mandarin",
	nil,
	"cmn-jhu",
}

------------- Cantonese varieties -------------

-- FIXME: Temporary.
m["yue-gua"] = {
	"Guangzhou Cantonese",
	nil,
	"yue",
}

-- FIXME: Temporary. Given the codes yue-yue or yue-can in the Linguist List.
m["yue-HK"] = {
	"Hong Kong Cantonese",
	5894342,
	"yue",
}

-- FIXME: Temporary. FIXME: How does this differ from "Written vernacular Cantonese"?
m["yue-lit"] = {
	"Literary Cantonese",
	2472605,
	"yue",
}

------------- Wu varieties -------------

m["wuu-han"] = {
	"Hangzhounese",
	5648144,
	"wuu",
}

m["wuu-nin"] = {
	"Ningbonese",
	3972199,
	"wuu",
}

-- FIXME: Temporary.
m["wuu-nor"] = {
	"Northern Wu",
	7675988,
	"wuu",
	aliases = {"Taihu Wu"},
}

-- FIXME: Temporary? Subvariety of Taihu Wu. NOTE: "chm" stands for Chongming, the main dialect, to avoid a conflict
-- with Shanghainese.
m["wuu-chm"] = {
	"Shadi Wu",
	6112340,
	"wuu-nor",
}

m["wuu-sha"] = {
	"Shanghainese",
	36718,
	"wuu-nor",
}

m["wuu-suz"] = {
	"Suzhounese",
	831744,
	"wuu-nor",
}

-- FIXME: Temporary. May be converted into a full language and/or split.
m["wuu-wen"] = {
	"Wenzhounese",
	710218,
	"wuu",
}

------------- Xiang varieties -------------

m["hsn-lou"] = {
	"Loudi Xiang",
	10943823,
	"hsn-old",
}

m["hsn-hya"] = {
	"Hengyang Xiang",
	20689035,
	"hsn-hzh",
}

m["hsn-hzh"] = {
	"Hengzhou Xiang",
	nil,
	"hsn",
}

m["hsn-new"] = {
	"New Xiang",
	7012696,
	"hsn",
	aliases = {"Chang-Yi"},
}

m["hsn-old"] = {
	"Old Xiang",
	7085453,
	"hsn",
	aliases = {"Lou-Shao"},
}

------------- Hakka varieties -------------

-- FIXME: Temporary.
m["hak-dab"] = {
	"Dabu Hakka",
	19855566,
	"hak", -- formerly hak-TW but seems to be spoken primary in Dabu County in Guangdong
}

-- FIXME: Temporary.
m["hak-eam"] = {
	"Early Modern Hakka",
	nil,
	"hak",
}

-- FIXME: Temporary.
m["hak-hai"] = {
	"Hailu Hakka",
	17038519,
	"hak", -- often considered a Taiwanese lect but also spoken in [[Shanwei]], [[Guangdong]]
}

-- FIXME: Temporary.
m["hak-hui"] = {
	"Huiyang Hakka",
	16873881,
	"hak",
}

-- FIXME: Temporary.
m["hak-hui-MY"] = {
	"Malaysian Huiyang Hakka",
	nil,
	"hak-hui",
}

-- FIXME: Temporary. Similar to and possibly the parent of Sixian Hakka in Taiwan.
m["hak-mei"] = {
	"Meixian Hakka",
	839295,
	"hak",
	aliases = {"Moiyan Hakka", "Meizhou Hakka"},
}

-- FIXME: Temporary.
m["hak-six"] = {
	"Sixian Hakka",
	9668261,
	"hak-TW",
}

-- FIXME: Temporary.
m["hak-TW"] = {
	"Taiwanese Hakka",
	2391532,
	"hak",
}

-- FIXME: Temporary.
m["hak-zha"] = {
	"Zhao'an Hakka",
	6703311,
	"hak",
	aliases = {"Zhangzhou Hakka"},
}

------------- Southern Min varieties -------------

-- FIXME: Temporary. May be converted into a full language.
m["nan-hlh"] = {
	"Haklau Min",
	120755728,
	"nan",
}

-- Hokkien varieties --

m["nan-jin"] = {
	"Jinjiang Hokkien",
	nil,
	"nan-qua",
}

m["nan-hbl-MY"] = {
	"Malaysian Hokkien",
	7570322,
	"nan-qua",
}

m["nan-pen"] = {
	"Penang Hokkien",
	11120689,
	"nan-zha",
}

m["nan-hbl-PH"] = {
	"Philippine Hokkien",
	3236692,
	"nan-qua",
}

m["nan-qua"] = {
	"Quanzhou Hokkien",
	nil,
	"nan-hbl",
}

-- FIXME: Temporary? Derived from both Quanzhou and Zhangzhou Hokkien.
m["nan-hbl-SG"] = {
	"Singapore Hokkien",
	3846528,
	"nan-hbl",
}

m["nan-hbl-TW"] = {
	"Taiwanese Hokkien",
	36778,
	"nan-hbl",
}

m["nan-xia"] = {
	"Xiamen Hokkien",
	68744,
	"nan-hbl",
	aliases = {"Amoy", "Amoyese", "Amoynese", "Xiamenese"},
}

m["nan-zha"] = {
	"Zhangzhou Hokkien",
	nil,
	"nan-hbl",
}

------------- Other Min varieties -------------

-- FIXME: Temporary. Affiliation within Min uncertain; some combination of Eastern and Southern.
m["zhx-zho"] = {
	"Zhongshan Min",
	8070958,
	"zhx",
}

------------- Other Chinese varieties -------------

-- FIXME: Temporary. Affiliation within Chinese uncertain; possibly Yue.
m["zhx-dan"] = {
	"Danzhou Chinese",
	2578935,
	"zhx",
}

------------- Chinese romanization varieties -------------

-- [[Wiktionary:Information desk/2022/June#Etymology Coding Issue]]
-- [[Wiktionary:Grease pit/2022/June#Transliteration Systems in Etymologies 2]]

m["cmn-pinyin"] = {
	"Hanyu Pinyin",
	42222,
	"cmn",
	aliases = {"Pinyin"},
}

m["cmn-tongyong"] = {
	"Tongyong Pinyin",
	700739,
	"cmn",
}

m["cmn-wadegiles"] = {
	"Wade–Giles",
	208442,
	"cmn",
	aliases = {"Wade-Giles", "Wade Giles"},
}

-- Chinese cyrillization

m["cmn-palladius"] = {
	"Palladius",
	1234239,
	"cmn",
	aliases = {"Palladius system"},
}

-----------------------------------------------------
--                 Coptic varieties                --
-----------------------------------------------------

m["cop-akh"] = {
	"Akhmimic Coptic",
	nil,
	"cop",
	aliases = {"Akhmimic"},
}

m["cop-boh"] = {
	"Bohairic Coptic",
	890733,
	"cop",
	aliases = {"Bohairic", "Memphitic Coptic", "Memphitic"},
}

m["cop-ggg"] = {
	"Coptic Dialect G",
	nil,
	"cop",
	aliases = {"Dialect G", "Mansuric Coptic", "Mansuric"},
}

m["cop-jjj"] = {
	"Coptic Dialect J",
	nil,
	"cop",
}

m["cop-kkk"] = {
	"Coptic Dialect K",
	nil,
	"cop",
}

m["cop-ppp"] = {
	"Coptic Dialect P",
	nil,
	"cop",
	aliases = {"Proto-Theban Coptic", "Palaeo-Theban Coptic"},
}

m["cop-fay"] = {
	"Fayyumic Coptic",
	1399115,
	"cop",
	aliases = {"Fayyumic", "Faiyumic Coptic", "Faiyumic", "Fayumic Coptic", "Fayumic",
		"Bashmuric Coptic", "Bashmuric"},
}

m["cop-her"] = {
	"Hermopolitan Coptic",
	nil,
	"cop",
	aliases = {"Hermopolitan", "Coptic Dialect H", "Ashmuninic", "Ashmuninic Coptic"},
}

m["cop-lyc"] = {
	"Lycopolitan Coptic",
	nil,
	"cop",
	aliases = {
		"Lycopolitan",
		"Assiutic Coptic", "Asyutic Coptic", "Assiutic", "Asyutic",
		"Lyco-Diospolitan Coptic", "Lyco-Diospolitan",
		"Subakhmimic Coptic", "Subakhmimic"
	},
}

m["cop-old"] = {
	"Old Coptic",
	nil,
	"cop",
}

m["cop-oxy"] = {
	"Oxyrhynchite Coptic",
	nil,
	"cop",
	aliases = {"Oxyrhynchite", "Mesokemic Coptic", "Mesokemic", "Middle Egyptian Coptic"},
}

m["cop-ply"] = {
	"Proto-Lycopolitan Coptic",
	nil,
	"cop",
	aliases = {"Coptic Dialect i", "Proto-Lyco-Diospolitan Coptic"},
}

m["cop-sah"] = {
	"Sahidic Coptic",
	2645851,
	"cop",
	aliases = {"Sahidic", "Saidic Coptic", "Saidic", "Thebaic Coptic", "Thebaic"},
}

-----------------------------------------------------
--                 Dutch varieties                 --
-----------------------------------------------------

m["nl-BE"] = {
	"Belgian Dutch",
	34147,
	"nl",
	aliases = { "Flemish", "Flemish Dutch", "Southern Dutch"},
}

-----------------------------------------------------
--               Egyptian varieties                --
-----------------------------------------------------

m["egy-old"] = {
	"Old Egyptian",
	447117,
	"egy",
}

m["egy-mid"] = {
	"Middle Egyptian",
	657330,
	"egy",
	aliases = {"Classical Egyptian"},
}

m["egy-nmi"] = {
	"Neo-Middle Egyptian",
	123735278,
	"egy",
	aliases = {"Égyptien de tradition", "Traditional Egyptian"},
}

m["egy-lat"] = {
	"Late Egyptian",
	1852329,
	"egy",
}

-----------------------------------------------------
--                Elamite varieties                --
-----------------------------------------------------

m["elx-old"] = {
	"Old Elamite",
	nil,
	"elx",
}

m["elx-mid"] = {
	"Middle Elamite",
	nil,
	"elx",
}

m["elx-neo"] = {
	"Neo-Elamite",
	nil,
	"elx",
}

m["elx-ach"] = {
	"Achaemenid Elamite",
	nil,
	"elx",
}

-----------------------------------------------------
--            English and Scots varieties          --
-----------------------------------------------------

-- English varieties

m["en-AU"] = {
	"Australian English",
	44679,
	"en",
}

m["en-GB"] = {
	"British English",
	7979,
	"en",
}

m["en-GB-SCT"] = {
	"Scottish English",
	44676,
	"en-GB",
}

m["en-GB-WLS"] = {
	"Welsh English",
	44676,
	"en-GB",
}

m["en-IM"] = {
	"Manx English",
	6753295,
	"en-GB",
}

m["en-ear"] = {
	"Early Modern English",
	1472196,
	"en",
	ancestors = "enm",
	aliases = {"Early New English"},
}

m["en-geo"] = {
	"Geordie English",
	653421,
	"en",
	ancestors = "enm-nor",
}

m["en-IE"] = {
	"Irish English",
	665624,
	"en",
}

m["en-uls"] = {
	"Ulster English",
	6840826,
	"en-IE",
}

m["en-GB-NIR"] = {
	"Northern Irish English",
	6840826, -- actually the code for Ulster English
	"en-uls",
}

m["en-NNN"] = { -- NA = Namibia; NNN is NATO 3-letter code for North America
	"North American English",
	7053766,
	"en"
}

m["en-US"] = {
	"American English",
	7976,
	"en-NNN",
}

m["en-US-CA"] = {
	"California English",
	1026812,
	"en-US",
}

m["en-CA"] = {
	"Canadian English",
	44676,
	"en-US",
}

m["en-HK"] = {
	"Hong Kong English",
	1068863,
	"en",
}

m["pld"] = {
	"Polari",
	1359130,
	"en",
}

-- Scots varieties

m["sco-osc"] = {
	"Early Scots",
	5326738,
	"enm",
	ancestors = "enm-nor",
	aliases = {"Old Scots"},
}

m["sco-smi"] = {
	"Middle Scots",
	3327000,
	"sco",
	ancestors = "sco-osc",
}

m["sco-ins"] = {
	"Insular Scots",
	16919205,
	"sco",
}

m["sco-uls"] = {
	"Ulster Scots",
	201966,
	"sco",
}

m["sco-nor"] = {
	"Northern Scots",
	16928150,
	"sco",
}

m["sco-sou"] = {
	"South Scots",
	7570457,
	"sco",
	aliases = {"Southern Scots", "Borders Scots"},
}

-- Middle English varieties

m["enm-nor"] = {
	"Northern Middle English",
	nil,
	"enm",
	ancestors = "ang-nor",
	aliases = {"Northumbrian Middle English"},
}

-- Old English varieties

-- Includes both Mercian and Northumbrian.
m["ang-ang"] = {
	"Anglian Old English",
	nil,
	"ang",
}

m["ang-ken"] = {
	"Kentish Old English",
	11687485,
	"ang",
}

m["ang-mer"] = {
	"Mercian Old English",
	602072,
	"ang-ang",
}

m["ang-nor"] = {
	"Northumbrian Old English",
	1798915,
	"ang-ang",
}

--[[
m["ang-wsx"] = {
	"West Saxon Old English",
	nil,
	"ang",
}
]]

-----------------------------------------------------
--     French and French-based creole varieties    --
-----------------------------------------------------

m["fro-nor"] = {
	"Old Northern French",
	2044917,
	"fro",
	aliases = {"Old Norman", "Old Norman French"},
}

m["fro-pic"] = {
	"Picard Old French",
	nil,
	"fro",
}

m["xno"] = {
	"Anglo-Norman",
	35214,
	"fro-nor",
}

m["xno-law"] = {
	"Law French",
	2044323,
	"xno",
}

m["fr-CA"] = {
	"Canadian French",
	1450506,
	"fr",
}

m["fr-CH"] = {
	"Switzerland French",
	1480152,
	"fr",
}

m["fr-aca"] = {
	"Acadian French",
	415109,
	"fr",
}

m["frc"] = {
	"Cajun French",
	880301,
	"fr",
	aliases = {"Louisiana French"},
}

m["ht-sdm"] = {
	"Saint Dominican Creole French",
	nil,
	"ht",
	ancestors = "fr",
}

-- Norman varieties

m["nrf-grn"] = {
	"Guernsey Norman",
	56428,
	"nrf",
	aliases = {"Guernsey"},
}

m["nrf-jer"] = {
	"Jersey Norman",
	56430,
	"nrf",
	aliases = {"Jersey"},
}

-----------------------------------------------------
--                Brythonic varieties              --
-----------------------------------------------------

m["bry-ear"] = {
	"Early Brythonic",
	nil,
	"cel-bry-pro",
}

m["bry-lat"] = {
	"Late Brythonic",
	nil,
	"cel-bry-pro",
}

-----------------------------------------------------
--                 Gaulish varieties               --
-----------------------------------------------------

m["xcg"] = {
	"Cisalpine Gaulish",
	3832927,
	"cel-gau",
}

m["xtg"] = {
	"Transalpine Gaulish",
	29977,
	"cel-gau",
}

-----------------------------------------------------
--                Portuguese varieties             --
-----------------------------------------------------

m["pt-BR"] = {
	"Brazilian Portuguese",
	750553,
	"pt",
}

m["pt-PT"] = {
	"European Portuguese",
	922399,
	"pt",
}

-----------------------------------------------------
--                  Spanish varieties              --
-----------------------------------------------------

m["es-AR"] = {
	"Rioplatense Spanish",
	509780,
	"es",
}

m["es-CO"] = {
	"Colombian Spanish",
	1115875,
	"es",
}

m["es-CU"] = {
	"Cuban Spanish",
	824909,
	"es",
}

m["es-MX"] = {
	"Mexican Spanish",
	616620,
	"es",
}

m["es-US"] = {
	"United States Spanish",
	2301077,
	"es",
	aliases = {"US Spanish"},
}
--use label "US Spanish" to put Spanish terms in this category

m["es-PR"] = {
	"Puerto Rican Spanish",
	7258609,
	"es",
}

-----------------------------------------------------
--                   Fula varieties                --
-----------------------------------------------------

m["fuc"] = {
	"Pulaar",
	1420205,
	"ff",
}

m["fuf"] = {
	"Pular",
	3915357,
	"ff",
}

m["ffm"] = {
	"Maasina Fulfulde",
	3915322,
	"ff",
}

m["fue"] = {
	-- no enwiki entry as of yet but frwiki and pmswiki have one
	"Borgu Fulfulde",
	12952426,
	"ff",
}

m["fuh"] = {
	-- no enwiki entry as of yet but frwiki and pmswiki have one
	"Western Niger Fulfulde",
	12952430,
	"ff",
}

m["fuq"] = {
	-- no enwiki entry as of yet but frwiki, hrwiki and pmswiki have one
	"Central-Eastern Niger Fulfulde",
	12628799,
	"ff",
}

m["fuv"] = {
	-- no enwiki entry as of yet but dewiki, frwiki, hrwiki, pmswiki and swwiki have one
	"Nigerian Fulfulde",
	36129,
	"ff",
}

m["fub"] = {
	-- no enwiki entry as of yet but dewiki, frwiki, hrwiki, pmswiki, ptwiki, swwiki and yowiki have one
	"Adamawa Fulfulde",
	34776,
	"ff",
}

m["fui"] = {
	-- no enwiki entry as of yet but pmswiki and swwiki have one
	"Bagirmi Fulfulde",
	11003859,
	"ff",
}

-----------------------------------------------------
--               German(ic) varieties              --
-----------------------------------------------------

-- (modern) German varieties

m["de-AT"] = {
	"Austrian German",
	306626,
	"de",
}

m["de-AT-vie"] = {
	"Viennese German",
	56474,
	"de-AT",
}

m["de-CH"] = {
	"Switzerland German",
	1366643,
	"de",
	aliases = {"Schweizer Hochdeutsch", "Swiss Standard German", "Swiss High German"},
}

m["ksh"] = {
	"Kölsch",
	4624,
	"gmw-cfr",
}

m["pfl"] = {
	"Palatine German",
	23014,
	"gmw-rfr",
	aliases = {"Pfälzisch", "Pälzisch", "Palatinate German"},
}

m["sli"] = {
	"Silesian East Central German",
	152965,
	"gmw-ecg",
	aliases = {"Silesian"},
}

m["sxu"] = {
	"Upper Saxon German",
	699284,
	"gmw-ecg",
}

-- Old High German varieties

m["lng"] = {
	"Lombardic",
	35972,
	"goh",
}

-- Proto-West Germanic varieties

m["frk"] = {
	"Frankish",
	10860505,
	"gmw-pro",
	aliases = {"Old Frankish"},
}

-- Alemannic German varieties

m["gsw-low"] = {
	"Low Alemannic German",
	503724,
	"gsw",
}

m["gsw-FR"] = {
	"Alsatian",
	8786,
	"gsw-low",
}

m["gsw-hig"] = {
	"High Alemannic German",
	503728,
	"gsw",
}

m["gsw-hst"] = {
	"Highest Alemannic German",
	687538,
	"gsw",
}

m["wae"] = {
	"Walser German",
	680517,
	"gsw-hst",
}

-----------------------------------------------------
--               Old Norse varieties               --
-----------------------------------------------------

m["non-grn"] = {
	"Greenlandic Norse",
	855236,
	"non-own",
}

m["non-oen"] = {
	"Old East Norse",
	10498031,
	"non",
	ancestors = "non",
}

m["non-own"] = {
	"Old West Norse",
	10498026,
	"non",
	ancestors = "non",
}

-----------------------------------------------------
--               Old Swedish varieties             --
-----------------------------------------------------

m["gmq-osw-lat"] = {
	"Late Old Swedish",
	10723594,
	"gmq-osw",
	ancestors = "gmq-osw",
}

-----------------------------------------------------
--                  Greek varieties                --
-----------------------------------------------------

m["qsb-grc"] = {
	"Pre-Greek",
	965052,
	"und",
	family = "qfa-sub",
}

m["grc-aeo"] = {
	"Aeolic Greek",
	406373,
	"grc",
	aliases = {"Lesbic Greek", "Lesbian Greek", "Aeolian Greek"},
}

m["grc-arc"] = {
	"Arcadian Greek",
	nil,
	"grc-arp",
}

m["grc-arp"] = {
	"Arcadocypriot Greek",
	499602,
	"grc",
}

m["grc-att"] = {
	"Attic Greek",
	506588,
	"grc",
}

m["grc-boi"] = {
	"Boeotian Greek",
	406373,
	"grc-aeo",
}

m["grc-dor"] = {
	"Doric Greek",
	285494,
	"grc",
}

m["grc-ela"] = {
	"Elean Greek",
	nil,
	"grc",
}

m["grc-epc"] = {
	"Epic Greek",
	990062,
	"grc",
	aliases = {"Homeric Greek"},
}

m["grc-ion"] = {
	"Ionic Greek",
	504165,
	"grc",
}

m["grc-koi"] = {
	"Koine Greek",
	107358,
	"grc",
	ancestors = "grc-att",
	aliases = {"Hellenistic Greek"},
}

m["grc-kre"] = { -- code used elsewhere: see [[Module:grc:Dialects]]
	"Cretan Ancient Greek", -- to distinguish from Cretan Greek below
	nil,
	"grc-dor",
}

m["grc-opl"] = {
	"Opuntian Locrian",
	nil,
	"grc",
}

m["grc-ozl"] = {
	"Ozolian Locrian",
	nil,
	"grc",
}

m["grc-pam"] = {
	"Pamphylian Greek",
	2271793,
	"grc",
}

m["grc-ths"] = {
	"Thessalian Greek",
	406373,
	"grc-aeo",
}

m["gkm"] = {
	"Byzantine Greek",
	36387,
	"grc",
	ancestors = "grc-koi",
	aliases = {"Medieval Greek"},
}

m["el-cyp"] = {
	"Cypriot Greek",
	245899,
	"el",
	aliases = {"Cypriotic Greek"},
}

m["el-pap"] = {
	"Paphian Greek",
	nil,
	"el",
}

m["el-crt"] = {
	"Cretan Greek",
	588306,
	"el",
}

m["el-kth"] = {
	"Katharevousa",
	35961,
	"el",
	ancestors = "gkm",
	aliases = {"Katharevousa Greek"},
}

m["el-kal"] = {
	"Kaliarda",
	nil,
	"el",
}


-----------------------------------------------------
--                 Hebrew varieties                --
-----------------------------------------------------

m["hbo"] = {
	"Biblical Hebrew",
	1982248,
	"he",
	aliases = {"Classical Hebrew"},
}

m["he-mis"] = {
	"Mishnaic Hebrew",
	1649362,
	"he",
	ancestors = "hbo",
}

m["he-med"] = {
	"Medieval Hebrew",
	2712572,
	"he",
	ancestors = "he-mis",
}

m["he-IL"] = {
	"Israeli Hebrew",
	8141,
	"he",
}

m["bsh-kat"] = {
	"Kativiri",
	2605045,
	"bsh",
	aliases = {"Katə́viri"},
}

m["xvi"] = {
	"Kamviri",
	1193495,
	"bsh",
	aliases = {"Kamvíri"},
}

m["bsh-mum"] = {
	"Mumviri",
	nil,
	aliases = {"Mumvíri"},
	"bsh"
}

-----------------------------------------------------
--                 Inuit varieties                 --
-----------------------------------------------------

m["esi"] = {
	"North Alaskan Inupiatun",
	nil,
	"ik"
}

m["esk"] = {
	"Northwest Alaskan Inupiatun",
	25559714,
	"ik"
}

-----------------------------------------------------
--                 Iranian varieties               --
-----------------------------------------------------

m["qsb-bma"] = {
	"the BMAC substrate",
	1054850,
	"und",
	family = "qfa-sub",
}

-- Historical and current Iranian dialects

m["ae-old"] = {
	"Old Avestan",
	29572,
	"ae",
	aliases = {"Gathic Avestan"},
}

m["ae-yng"] = {
	"Younger Avestan",
	29572,
	"ae-old",
	aliases = {"Young Avestan"},
}

m["bcc"] = {
	"Southern Balochi",
	33049,
	"bal",
	aliases = {"Southern Baluchi"},
}

m["bgp"] = {
	"Eastern Balochi",
	33049,
	"bal",
	aliases = {"Eastern Baluchi"},
}

m["bgn"] = {
	"Western Balochi",
	33049,
	"bal",
	aliases = {"Western Baluchi"},
}

m["bsg-ban"] = {
	"Bandari",
	nil,
	"bsg",
}

m["bsg-hor"] = {
	"Hormozi",
	nil,
	"bsg",
}

m["bsg-min"] = {
	"Minabi",
	nil,
	"bsg",
}

m["kho-old"] = {
	"Old Khotanese",
	nil,
	"kho",
}

m["kho-lat"] = {
	"Late Khotanese",
	nil,
	"kho-old",
}

m["peo-ear"] = {
	"Early Old Persian",
	nil,
	"peo",
}

m["peo-lat"] = {
	"Late Old Persian",
	nil,
	"peo",
}

m["pal-ear"] = {
	"Early Middle Persian",
	nil,
	"pal",
}

m["pal-lat"] = {
	"Late Middle Persian",
	nil,
	"pal",
	ancestors = "pal-ear",
}

m["ps-nwe"] = {
	"Northwestern Pashto",
	nil,
	"ps",
}

m["ps-cgi"] = {
	"Central Ghilzay",
	nil,
	"ps-nwe",
}

m["ps-mah"] = {
	"Mahsudi",
	nil,
	"ps-nwe",
}

m["ps-nea"] = {
	"Northeastern Pashto",
	nil,
	"ps",
}

m["ps-afr"] = {
	"Afridi",
	nil,
	"ps-nea",
}

m["ps-bng"] = {
	"Bangash",
	nil,
	"ps-nea",
}


m["ps-xat"] = {
	"Khatak",
	nil,
	"ps-nea",
}

m["ps-pes"] = {
	"Peshawari",
	nil,
	"ps-nea",
}

m["ps-sea"] = {
	"Southeastern Pashto",
	nil,
	"ps",
}

m["ps-ban"] = {
	"Bannu",
	nil,
	"ps-sea",
}

m["ps-kak"] = {
	"Kakari",
	nil,
	"ps-sea",
}

m["ps-ser"] = {
	"Sher",
	nil,
	"ps-sea",
}

m["ps-waz"] = {
	"Waziri",
	12274473,
	"ps-sea",
}

m["ps-swe"] = {
	"Southwestern Pashto",
	nil,
	"ps",
}

m["ps-kan"] = {
	"Kandahari",
	nil,
	"ps-swe",
}

m["ps-jad"] = {
	"Jadrani",
	nil,
	"ps",
	ancestors = "ira-pat-pro"
}

m["xme-azr"] = {
	"Old Azari",
	nil,
	"xme-ott",
	aliases = {"Old Azeri", "Azari", "Azeri", "Āḏarī", "Adari", "Adhari"},
}

m["xme-ttc-cen"] = {
	"Central Tati",
	nil,
	"xme-ott",
}

m["xme-ttc-eas"] = {
	"Eastern Tati",
	nil,
	"xme-ott",
}

m["xme-ttc-nor"] = {
	"Northern Tati",
	nil,
	"xme-ott",
}

m["xme-ttc-sou"] = {
	"Southern Tati",
	nil,
	"xme-ott",
}

m["xme-ttc-wes"] = {
	"Western Tati",
	nil,
	"xme-ott",
}

m["xmn"] = {
	"Manichaean Middle Persian",
	nil,
	"pal-lat",
}

m["fa-ira"] = {
	"Iranian Persian",
	3513637,
	"fa",
	aliases = {"Modern Persian", "Western Persian"},
	translit = "fa-ira-translit",
}

m["fa-cls"] = {
	"Classical Persian",
	9168,
	"fa",
	ancestors = "pal-lat",
	translit = "fa-cls-translit",
}

m["prs"] = {
	"Dari",
	178440,
	"fa",
	aliases = {"Dari Persian", "Central Persian", "Eastern Persian", "Afghan Persian"},
	translit = "fa-cls-translit",
}

m["haz"] = {
	"Hazaragi",
	33398,
	"prs",
	translit = "fa-cls-translit",
}

m["os-dig"] = {
	"Digor Ossetian",
	3027861,
	"os",
	aliases = {"Digoron", "Digor"},
}

m["os-iro"] = {
	"Iron Ossetian",
	nil,
	"os",
	aliases = {"Iron"},
}

m["sog-ear"] = {
	"Early Sogdian",
	nil,
	"sog",
}

m["sog-lat"] = {
	"Late Sogdian",
	nil,
	"sog-ear",
}

m["oru-kan"] = {
	"Kaniguram",
	6363164,
	"oru",
}

m["oru-log"] = {
	"Logar",
	nil,
	"oru",
}

m["oos-ear"] = {
	"Early Old Ossetic",
	nil,
	"oos",
}

m["oos-lat"] = {
	"Late Old Ossetic",
	nil,
	"oos",
}

m["xln"] = {
	"Alanic",
	3658580,
	"oos",
}

m["rdb-jir"] = {
	"Jirofti",
	nil,
	"rdb",
}

m["rdb-kah"] = {
	"Kahnuji",
	nil,
	"rdb",
}

-- Southwestern Fars lects

m["fay-bur"] = {
	"Burenjani",
	nil,
	"fay",
}

m["fay-bsh"] = {
	"Bushehri",
	nil,
	"fay",
}

m["fay-dsh"] = {
	"Dashtaki",
	nil,
	"fay",
}

m["fay-dav"] = {
	"Davani",
	5228140,
	"fay",
}

m["fay-eze"] = {
	"Emamzada Esma’ili",
	nil,
	"fay",
}

m["fay-gav"] = {
	"Gavkoshaki",
	nil,
	"fay",
}

m["fay-kho"] = {
	"Khollari",
	nil,
	"fay",
}

m["fay-kon"] = {
	"Kondazi",
	nil,
	"fay",
}

m["fay-kzo"] = {
	"Old Kazeruni",
	nil,
	"fay",
}

m["fay-mas"] = {
	"Masarami",
	nil,
	"fay",
}

m["fay-pap"] = {
	"Papuni",
	nil,
	"fay",
}

m["fay-sam"] = {
	"Samghani",
	nil,
	"fay",
}

m["fay-shr"] = {
	"Shirazi",
	nil,
	"fay",
}

m["fay-sho"] = {
	"Old Shirazi",
	nil,
	"fay",
}

m["fay-sam"] = {
	"Samghani",
	nil,
	"fay",
}

m["fay-kar"] = {
	"Khargi",
	nil,
	"fay",
}

m["fay-sor"] = {
	"Sorkhi",
	nil,
	"fay",
}

-- Talysh lects

m["tly-cen"] = {
	"Central Talysh",
	nil,
	"tly",
}

m["tly-asa"] = {
	"Asalemi",
	nil,
	"tly-cen",
}

m["tly-kar"] = {
	"Karganrudi",
	nil,
	"tly-cen",
}

m["tly-tul"] = {
	"Tularudi",
	nil,
	"tly-cen",
}

m["tly-tal"] = {
	"Taleshdulabi",
	nil,
	"tly-cen",
}

m["tly-nor"] = {
	"Northern Talysh",
	nil,
	"tly",
}

m["tly-aze"] = {
	"Azerbaijani Talysh",
	nil,
	"tly-nor",
}

m["tly-anb"] = {
	"Anbarani",
	nil,
	"tly-nor",
}

m["tly-sou"] = {
	"Southern Talysh",
	nil,
	"tly",
}

m["tly-fum"] = {
	"Fumani",
	nil,
	"tly-sou",
}

m["tly-msu"] = {
	"Masulei",
	nil,
	"tly-sou",
}

m["tly-msa"] = {
	"Masali",
	nil,
	"tly-sou",
}

m["tly-san"] = {
	"Shandarmani",
	nil,
	"tly-sou",
}

-- Tafreshi lects

m["xme-amo"] = {
	"Amorehi",
	nil,
	"xme-taf",
}

m["atn"] = {
	"Ashtiani",
	3436590,
	"xme-taf",
	wikipedia_article = "Ashtiani language",
}

m["xme-bor"] = {
	"Borujerdi",
	nil,
	"xme-taf",
}

m["xme-ham"] = {
	"Hamadani",
	6302426,
	"xme-taf",
}

m["xme-kah"] = {
	"Kahaki",
	nil,
	"xme-taf",
}

m["vaf"] = {
	"Vafsi",
	32611,
	"xme-taf",
}

-- Kermanic lects

m["kfm"] = {
	"Khunsari",
	6403030,
	"xme-ker",
	wikipedia_article = "Khunsari language",
}

m["xme-mah"] = {
	"Mahallati",
	nil,
	"xme-ker",
}

m["xme-von"] = {
	"Vonishuni",
	nil,
	"xme-ker",
}

m["xme-bdr"] = {
	"Badrudi",
	nil,
	"xme-ker",
}

m["xme-del"] = {
	"Delijani",
	nil,
	"xme-ker",
}

m["xme-kas"] = {
	"Kashani",
	nil,
	"xme-ker",
}

m["xme-kes"] = {
	"Kesehi",
	nil,
	"xme-ker",
}

m["xme-mey"] = {
	"Meymehi",
	nil,
	"xme-ker",
}

m["ntz"] = {
	"Natanzi",
	6968399,
	"xme-ker",
	wikipedia_article = "Natanzi language",
}

m["xme-abz"] = {
	"Abuzeydabadi",
	nil,
	"xme-ker",
}

m["xme-aby"] = {
	"Abyanehi",
	nil,
	"xme-ker",
}

m["xme-far"] = {
	"Farizandi",
	nil,
	"xme-ker",
}

m["xme-jow"] = {
	"Jowshaqani",
	nil,
	"xme-ker",
}

m["xme-nas"] = {
	"Nashalji",
	nil,
	"xme-ker",
}

m["xme-qoh"] = {
	"Qohrudi",
	nil,
	"xme-ker",
}

m["xme-yar"] = {
	"Yarandi",
	nil,
	"xme-ker",
}

m["soj"] = {
	"Soi",
	7930463,
	"xme-ker",
	aliases = {"Sohi"},
	wikipedia_article = "Soi language",
}

m["xme-tar"] = {
	"Tari",
	nil,
	"xme-ker",
}

m["gzi"] = {
	"Gazi",
	5529130,
	"xme-ker",
	wikipedia_article = "Gazi language",
}

m["xme-sed"] = {
	"Sedehi",
	nil,
	"xme-ker",
}

m["xme-ard"] = {
	"Ardestani",
	nil,
	"xme-ker",
}

m["xme-zef"] = {
	"Zefrehi",
	nil,
	"xme-ker",
}

m["xme-isf"] = {
	"Isfahani",
	nil,
	"xme-ker",
}

m["xme-kaf"] = {
	"Kafroni",
	nil,
	"xme-ker",
}

m["xme-vrz"] = {
	"Varzenehi",
	nil,
	"xme-ker",
}

m["xme-xur"] = {
	"Khuri",
	nil,
	"xme-ker",
}

m["nyq"] = {
	"Nayini",
	6983146,
	"xme-ker",
	wikipedia_article = "Nayini language",
}

m["xme-ana"] = {
	"Anaraki",
	nil,
	"xme-ker",
}

m["gbz"] = {
	"Zoroastrian Dari",
	32389,
	"xme-ker",
	aliases = {"Behdināni", "Gabri", "Gavrŭni", "Gabrōni"},
	wikipedia_article = "Zoroastrian Dari language",
}

m["xme-krm"] = {
	"Kermani",
	nil,
	"xme-ker",
}

m["xme-yaz"] = {
	"Yazdi",
	nil,
	"xme-ker",
}

m["xme-bid"] = {
	"Bidhandi",
	nil,
	"xme-ker",
}

m["xme-bij"] = {
	"Bijagani",
	nil,
	"xme-ker",
}

m["xme-cim"] = {
	"Chimehi",
	nil,
	"xme-ker",
}

m["xme-han"] = {
	"Hanjani",
	nil,
	"xme-ker",
}

m["xme-kom"] = {
	"Komjani",
	nil,
	"xme-ker",
}

m["xme-nar"] = {
	"Naraqi",
	nil,
	"xme-ker",
}

m["xme-nus"] = {
	"Nushabadi",
	nil,
	"xme-ker",
}

m["xme-qal"] = {
	"Qalhari",
	nil,
	"xme-ker",
}

m["xme-trh"] = {
	"Tarehi",
	nil,
	"xme-ker",
}

m["xme-val"] = {
	"Valujerdi",
	nil,
	"xme-ker",
}

m["xme-var"] = {
	"Varani",
	nil,
	"xme-ker",
}

m["xme-zor"] = {
	"Zori",
	nil,
	"xme-ker",
}

-- Ramandi lects

m["tks-ebr"] = {
	"Ebrahimabadi",
	nil,
	"tks",
}

m["tks-sag"] = {
	"Sagzabadi",
	nil,
	"tks",
}

m["tks-esf"] = {
	"Esfarvarini",
	nil,
	"tks",
}

m["tks-tak"] = {
	"Takestani",
	nil,
	"tks",
}

m["tks-cal"] = {
	"Chali Tati",
	nil,
	"tks",
	aliases = {"Chāli"},
	wikipedia_article = "Tati language (Iran)",
}

m["tks-dan"] = {
	"Danesfani",
	nil,
	"tks",
}

m["tks-xia"] = {
	"Khiaraji",
	nil,
	"tks",
}

m["tks-xoz"] = {
	"Khoznini",
	nil,
	"tks",
}

-- Shughni dialects

m["sgh-bro"] = {
	"Bartangi-Oroshori",
	nil,
	"sgh",
}

m["sgh-bar"] = {
	"Bartangi",
	nil,
	"sgh-bro",
}

m["sgh-oro"] = {
	"Oroshori",
	nil,
	"sgh-bro",
	aliases = {"Roshorvi"},
}

m["sgh-rsx"] = {
	"Roshani-Khufi",
	nil,
	"sgh",
}

m["sgh-xuf"] = {
	"Khufi",
	2562249,
	"sgh-rsx",
	aliases = {"Xufi", "Xūfī"},
	wikipedia_article = "Khufi language",
}

m["sgh-ros"] = {
	"Roshani",
	2597566,
	"sgh-rsx",
	aliases = {"Rushani", "Rōšāni"},
	wikipedia_article = "Rushani language",
}

m["sgh-xgb"] = {
	"Khughni-Bajui",
	nil,
	"sgh",
}

m["sgh-xug"] = {
	"Khughni",
	nil,
	"sgh-xgb",
}

m["sgh-baj"] = {
	"Bajui",
	nil,
	"sgh-xgb",
}

-- Indo-Aryan varieties

m["inc-mit"] = {
	"Mitanni",
	1986700,
	"inc-pro",
}

m["awa-old"] = {
	"Old Awadhi",
	nil,
	"awa",
}

m["bra-old"] = {
	"Old Braj",
	nil,
	"bra",
}

m["gu-kat"] = {
	"Kathiyawadi",
	nil,
	"gu",
	aliases = {"Kathiyawadi Gujarati", "Kathiawadi"},
}

m["gu-lda"] = {
	"Lisan ud-Dawat Gujarati",
	nil,
	"gu",
	aliases = {"Lisan ud-Dawat", "LDA"},
}

m["hi-mum"] = {
	"Bombay Hindi",
	3543151,
	"hi",
	aliases = {"Mumbai Hindi", "Bambaiyya Hindi"},
}

m["hi-mid"] = {
	"Middle Hindi",
	nil,
	"inc-ohi",
	ancestors = "inc-ohi",
}

m["sa-bhs"] = {
	"Buddhist Hybrid Sanskrit",
	248758,
	"sa",
}

m["sa-bra"] = {
	"Brahmanic Sanskrit",
	36858,
	"sa",
}

m["sa-cls"] = {
	"Classical Sanskrit",
	11059,
	"sa",
}

m["sa-neo"] = {
	"New Sanskrit",
	11059,
	"sa",
}

m["sa-ved"] = {
	"Vedic Sanskrit",
	36858,
	"sa",
}

m["si-med"] = {
	"Medieval Sinhalese",
	nil,
	"si",
	aliases = {"Medieval Sinhala"},
}

m["kok-mid"] = {
	"Middle Konkani",
	nil,
	"kok",
	aliases = {"Medieval Konkani"},
}

m["kok-old"] = {
	"Old Konkani",
	nil,
	"kok",
	aliases = {"Early Konkani"},
}


-- Indian subcontinent languages


-- Dhivehi varieties

m["dv-mul"] = {
	"Mulaku Dhivehi",
	nil,
	"dv",
	aliases = {"Mulaku Divehi", "Mulaku Bas"},
}

m["dv-huv"] = {
	"Huvadhu Dhivehi",
	nil,
	"dv",
	aliases = {"Huvadhu Divehi", "Huvadhu Bas"},
}

m["dv-add"] = {
	"Addu Dhivehi",
	nil,
	"dv",
	aliases = {"Addu Divehi", "Addu Bas"},
}


-- Dravidian varieties


m["ta-mid"] = {
	"Middle Tamil",
	20987434,
	"ta",
}

m["kn-hav"] = {
	"Havigannada",
	24276369,
	"kn",
}

m["kn-kun"] = {
	"Kundagannada",
	6444255,
	"kn",
}

-- Prakrits

m["pra-ard"] = {
	"Ardhamagadhi Prakrit",
	35217,
	"inc-pra",
	aliases = {"Ardhamagadhi"},
}

m["pra-hel"] = {
	"Helu Prakrit",
	15080869,
	"inc-pra",
	aliases = {"Elu", "Elu Prakrit", "Helu"},
}

m["pra-kha"] = {
	"Khasa Prakrit",
	nil,
	"inc-pra",
	aliases = {"Khasa"},
}

m["pra-mag"] = {
	"Magadhi Prakrit",	
	2652214,
	"inc-pra",
	aliases = {"Magadhi"},
}

m["pra-mah"] = {
	"Maharastri Prakrit",
	2586773,
	"inc-pra",
	aliases = {"Maharashtri Prakrit", "Maharastri", "Maharashtri"},
}

m["pra-pai"] = {
	"Paisaci Prakrit",
	2995607,
	"pra-sau",
	aliases = {"Paisaci", "Paisachi"},
	ancestors = "pra-sau"
}

m["pra-sau"] = {
	"Sauraseni Prakrit",
	2452885,
	"inc-pra",
	aliases = {"Sauraseni", "Shauraseni"},
}

m["pra-ava"] = {
	"Avanti",
	nil,
	"inc-pra",
	aliases = {"Avanti Prakrit"},
}

m["pra-pra"] = {
	"Pracya",
	nil,
	"inc-pra",
	aliases = {"Pracya Prakrit"},
}

m["pra-bah"] = {
	"Bahliki",
	nil,
	"inc-pra",
	aliases = {"Bahliki Prakrit"},
}

m["pra-dak"] = {
	"Daksinatya",
	nil,
	"inc-pra",
	aliases = {"Daksinatya Prakrit"},
}

m["pra-sak"] = {
	"Sakari",
	nil,
	"inc-pra",
	aliases = {"Sakari Prakrit"},
}

m["pra-can"] = {
	"Candali",
	nil,
	"inc-pra",
	aliases = {"Candali Prakrit"},
}

m["pra-sab"] = {
	"Sabari",
	nil,
	"inc-pra",
	aliases = {"Sabari Prakrit"},
}

m["pra-abh"] = {
	"Abhiri",
	nil,
	"inc-pra",
	aliases = {"Abhiri Prakrit"},
}

m["pra-dra"] = {
	"Dramili",
	nil,
	"inc-pra",
	aliases = {"Dramili Prakrit"},
}

m["pra-odr"] = {
	"Odri",
	nil,
	"inc-pra",
	aliases = {"Odri Prakrit"},
}


-- Italian, Latin and other Italic varieties

m["roa-oit"] = {
	"Old Italian",
	652,
	"it",
}

m["it-CH"] = {
	"Switzerland Italian",
	672147,
	"it",
}

-- Latin varieties by period

m["itc-ola"] = {
	"Old Latin",
	12289,
	"la",
}

m["la-cla"] = {
	"Classical Latin",
	253854,
	"la",
}

m["la-lat"] = {
	"Late Latin",
	1503113,
	"la",
	ancestors = "la-cla",
}

m["la-vul"] = {
	"Vulgar Latin",
	37560,
	"la",
	ancestors = "la-cla",
}

m["la-med"] = {
	"Medieval Latin",
	1163234,
	"la",
	ancestors = "la-lat",
}

m["la-eme"] = {
	"Early Medieval Latin",
	nil,
	"la-med",
	wikipedia_article = "Medieval Latin",
}

m["la-ecc"] = {
	"Ecclesiastical Latin",
	1247932,
	"la",
	aliases = {"Church Latin"},
	ancestors = "la-lat",
}

m["la-ren"] = {
	"Renaissance Latin",
	499083,
	"la",
	ancestors = "la-med",
}

m["la-new"] = {
	"New Latin",
	1248221,
	"la",
	aliases = {"Modern Latin"},
	ancestors = "la-ren",
}

m["la-con"] = {
	"Contemporary Latin",
	1246397,
	"la-new",
}

-- other Italic lects

m["osc-luc"] = {
	"Lucanian",
	nil,
	"osc",
}

m["osc-sam"] = {
	"Samnite",
	nil,
	"osc",
}

m["xum-her"] = {
	"Hernician",
	nil,
	"xum",
}


-- Malay and related varieties

m["ms-old"] = {
	"Old Malay",
	nil,
	"ms",
}

m["ms-cla"] = {
	"Classical Malay",
	nil,
	"ms",
	ancestors = "ms-old",
}

m["pse-bsm"] = {
	"Besemah",
	nil,
	"pse",
}

m["bew-kot"] = {
	"Betawi Kota",
	nil,
	"bew",
}

m["bew-ora"] = {
	"Betawi Ora",
	nil,
	"bew",
}

m["bew-udi"] = {
	"Betawi Udik",
	nil,
	"bew",
}


-- Mongolic lects

m["xng-ear"] = {
	"Early Middle Mongol",
	nil,
	"xng",
}

m["xng-lat"] = {
	"Late Middle Mongol",
	nil,
	"xng",
	ancestors = "xng-ear",
}

m["mn-kha"] = {
	"Khalkha Mongolian",
	6399808,
	"mn",
	aliases = {"Khalkha"},
}

m["mn-ord"] = {
	"Ordos Mongolian",
	716904,
	"mn",
	aliases = {"Ordos"},
}

m["mn-cha"] = {
	"Chakhar Mongolian",
	907425,
	"mn",
	aliases = {"Chakhar"},
}

m["mn-khr"] = {
	"Khorchin Mongolian",
	3196210,
	"mn",
	aliases = {"Khorchin"},
}

-- Japanese varieties

m["ja-mid"] = {
	"Middle Japanese",
	6841474,
	"ojp",
	ancestors = "ojp",
}

m["ja-mid-ear"] = {
	"Early Middle Japanese",
	182695,
	"ja-mid",
}

m["ja-mid-lat"] = {
	"Late Middle Japanese",
	1816184,
	"ja-mid",
	ancestors = "ja-mid-ear",
}

m["ja-ear"] = {
	"Early Modern Japanese",
	5326692,
	"ja",
	ancestors = "ja-mid-lat",
}

m["ojp-eas"] = {
	"Eastern Old Japanese",
	65247957,
	"ojp",
}

-- Kartvelian varieties


m["ka-mid"] = {
	"Middle Georgian",
	nil,
	"ka",
	ancestors = "oge",
}

-- Korean varieties

m["oko-lat"] = {
	"Late Old Korean",
	nil,
	"oko",
}

m["okm-ear"] = {
	"Early Middle Korean",
	nil,
	"okm",
}

m["ko-cen"] = {
	"Central Korean",
	nil,
	"ko",
}

m["ko-gyg"] = {
	"Gyeonggi Korean",
	485492,
	"ko-cen",
	aliases = {"Seoul Korean"},
}

m["ko-chu"] = {
	"Chungcheong Korean",
	625800,
	"ko-cen",
	aliases = {"Hoseo Korean"},
}

m["ko-hwa"] = {
	"Hwanghae Korean",
	16183706,
	"ko-cen",
}

m["ko-gan"] = {
	"Gangwon Korean",
	11260444,
	"ko-cen",
	aliases = {"Yeongdong Korean"},
}

m["ko-gys"] = {
	"Gyeongsang Korean",
	488002,
	"ko",
	aliases = {"Southeastern Korean"},
}

m["ko-jeo"] = {
	"Jeolla Korean",
	11250166,
	"ko",
	aliases = {"Southwestern Korean"},
}

m["ko-pyo"] = {
	"Pyongan Korean",
	7263142,
	"ko",
	aliases = {"Northwestern Korean"},
}

m["ko-ham"] = {
	"Hamgyong Korean",
	860702,
	"ko",
	aliases = {"Northeastern Korean"},
}

m["ko-yuk"] = {
	"Yukjin Korean",
	16171275,
	"ko",
	aliases = {"Yukchin Korean", "Ryukjin Korean", "Ryukchin Korean"},
}

-- Occitan varieties

m["oc-auv"] = {
	"Auvergnat",
	35359,
	"oc",
	aliases = {"Auvernhat", "Auvergnese"},
}

m["oc-gas"] = {
	"Gascon",
	35735,
	"oc",
}

-- standardized dialect of Gascon
m["oc-ara"] = {
	"Aranese",
	10196,
	"oc-gas",
}

m["oc-lan"] = {
	"Languedocien",
	942602,
	"oc",
	aliases = {"Lengadocian"},
}

m["oc-lim"] = {
	"Limousin",
	427614,
	"oc",
}

m["oc-pro"] = {
	"Provençal",
	241243,
	"oc",
	aliases = {"Provencal"},
}

m["oc-pro-old"] = {
	"Old Provençal",
	2779185,
	"pro",
}

m["oc-viv"] = {
	"Vivaro-Alpine",
	1649613,
	"oc",
}

m["oc-jud"] = {
	"Shuadit",
	56472,
	"oc",
	aliases = {
		"Chouhadite", "Chouhadit", "Chouadite", "Chouadit", "Shuhadit",
		"Judeo-Occitan", "Judæo-Occitan", "Judaeo-Occitan",
		"Judeo-Provençal", "Judæo-Provençal", "Judaeo-Provençal",
		"Judeo-Provencal", "Judaeo-Provencal",
		"Judeo-Comtadin", "Judæo-Comtadin", "Judaeo-Comtadin",
	},
}

-- Oromo varieties

m["hae"] = {
	"Harar Oromo",
	5330355,
	"om",
	aliases = {"Eastern Oromo"},
}

m["gax"] = {
	"Borana",
	2910610,
	"om",
	aliases = {"Southern Oromo"},
}

m["orc"] = {
	"Orma",
	2919128,
	"om",
}

m["ssn"] = {
	"Waata",
	3501553,
	"om",
}

-- Phillipine varieties

m["tl-old"] = {
	"Old Tagalog",
	12967437,
	"tl",
}

m["tl-cls"] = {
	"Classical Tagalog",
	nil,
	"tl",
}


-- Pre-Roman substrates

m["qsb-ibe"] = {
	"a pre-Roman substrate of Iberia",
	530799,
	"und",
	family = "qfa-sub",
}

m["qsb-bal"] = {
	"Paleo-Balkan",
	1815070,
	"und",
	family = "qfa-sub",
}

-- Sardinian varieties

m["sc-src"] = {
	"Logudorese",
	777974,
	"sc",
	aliases = {"Logudorese Sardinian"},
}

m["sc-nuo"] = {
	"Nuorese",
	nil,
	"sc-src",
	aliases = {"Nuorese Sardinian"},
}

m["sc-sro"] = {
	"Campidanese",
	35348,
	"sc",
	aliases = {"Campidanese Sardinian"},
}

-- Rwanda-Rundi varieties

m["rw-kin"] = {
	"Kinyarwanda",
	33573,
	"rw",
	aliases = {"Rwanda"},
}

m["rw-run"] = {
	"Kirundi",
	33583,
	"rw",
	aliases = {"Rundi"},
}

-- Slavic varieties

m["cs-ear"] = {
	"Early Modern Czech",
	nil,
	"cs",
	ancestors = "zlw-ocs"
}

m["cu-bgm"] = {
	"Middle Bulgarian",
	12294897,
	"cu",
	ancestors = "cu"
}

m["zle-mru"] = {
	"Middle Russian",
	35228,
	"ru",
	"Cyrs",
	ancestors = "orv",
	translit = "ru-translit",
}

m["zle-obe"] = {
	"Old Belarusian",
	13211,
	"zle-ort",
}

m["zle-ouk"] = {
	"Old Ukrainian",
	13211,
	"zle-ort",
}

m["zlw-mpl"] = {
	"Middle Polish",
	402878,
	"pl",
	ancestors = "zlw-opl",
}

-- Serbo-Croatian varieties

m["ckm"] = {
	"Chakavian Serbo-Croatian",
	337565,
	"sh",
	aliases = {"Čakavian"},
}

m["kjv"] = {
	"Kajkavian Serbo-Croatian",
	838165,
	"sh",
}

m["sh-tor"] = { -- Linguist code srp-tor
	"Torlakian Serbo-Croatian",
	1078803,
	"sh",
	aliases = {"Torlak"},
}

-- Tibetic lects

m["adx"] = {
	"Amdo Tibetan",
	56509,
	"bo",
}

m["kbg"] = {
	"Khamba",
	12952626,
	"bo",
}

m["khg"] = {
	"Khams Tibetan",
	56601,
	"bo",
}

m["tsk"] = {
	"Tseku",
	11159532,
	"bo",
}

-- Tuareg lects

m["thv"] = {
	"Tamahaq",
	56703,
	"tmh",
}

m["ttq"] = {
	"Tawellemmet",
	56390,
	"tmh",
}

m["taq"] = {
	"Tamasheq",
	4670066,
	"tmh",
}

m["thz"] = {
	"Tayert",
	56388,
	"tmh",
}

m["tmh-ght"] = {
	"Ghat",
	47012900,
	"tmh",
	wikipedia_article = "Tamahaq language",
}

-- Turkic lects

m["trk-cmn"] = {
	"Common Turkic",
	1126028,
	"trk-pro",
}

m["trk-ogz-pro"] = {
	"Proto-Oghuz",
	494600,
	"trk-pro",
	family = "trk-ogz",
	aliases = {"Southwestern Common Turkic"},
}

m["crh-dbj"] = {
	"Dobrujan Tatar",
	12811566,
	"crh",
	aliases = {"Romanian Tatar"},
}

m["cv-ana"] = {
	"Anatri",
	nil,
	"cv",
	aliases = {"Anatri Chuvash"},
}

m["cv-mid"] = {
	"Middle Chuvash",
	nil,
	"cv",
	ancestors = "xbo",
}

m["cv-vir"] = {
	"Viryal",
	4278332,
	"cv",
	aliases = {"Viryal Chuvash"},
}

m["kjh-fyu"] = {
	"Fuyu Kyrgyz",
	2598963,
	"kjh",
	aliases = {"Fuyu Kirgiz", "Fuyu Kirghiz", "Manchurian Kyrgyz", "Manchurian Kirgiz", "Manchurian Kirghiz"},
}

m["klj-arg"] = {
	"Arghu",
	33455,
	"klj",
}

m["otk-kir"] = {
	"Old Kirghiz",
	83142,
	"otk",
}

m["qwm-arm"] = {
	"Armeno-Kipchak",
	2027503,
	"qwm",
}

m["qwm-mam"] = {
	"Mamluk-Kipchak",
	4279942,
	"qwm",
}

m["az-cls"] = {
	"Classical Azerbaijani",
	nil,
	"az",
	aliases = {"Classical Azeri"},
}

m["qxq"] = {
	"Qashqai",
	13192,
	"az",
	aliases = {"Qaşqay", "Qashqayi", "Kashkai", "Kashkay"},
}

m["tr-CY"] = {
	"Cypriot Turkish",
	7917392,
	"tr",
}

-- Uralic lects

m["mns-eas"] = {
	"Eastern Mansi",
	30311755,
	"mns-cen",
}

m["mns-wes"] = {
	"Western Mansi",
	30311756,
	"mns-cen",
}

-- Other lects

m["alv-kro"] = {
	"Kromanti",
	1093206,
	"crp-mar",
}

m["bat-pro"] = {
	"Proto-Baltic",
	1703347,
	"ine-bsl-pro",
}

m["es-lun"] = {
	"Lunfardo",
	1401612,
	"es",
}

m["fiu-pro"] = {
	"Proto-Finno-Ugric",
	79890,
	"urj-pro",
}

m["gem-sue"] = {
	"Suevic",
	155085,
	"gmw-pro",
	aliases = {"Suebian"},
}

m["iro-ohu"] = {
	"Old Wendat",
	nil,
	"wdt",
	wikipedia_article = "Huron language",
}

m["iro-omo"] = {
	"Old Mohawk",
	nil,
	"moh",
}

m["iro-oon"] = {
	"Old Onondaga",
	nil,
	"ono",
}

m["okz-ang"] = {
	"Angkorian Old Khmer",
	9205,
	"okz",
	wikipedia_article = "Khmer language#Historical periods",
}

m["okz-pre"] = {
	"Pre-Angkorian Old Khmer",
	9205,
	"okz",
	wikipedia_article = "Khmer language#Historical periods",
}

m["mul-tax"] = {
	"taxonomic name",
	nil,
	"mul",
}

m["qsb-pyg"] = {
	"a substrate language originally spoken by the Pygmies",
	nil,
	"und",
	family = "qfa-sub",
	wikipedia_article = "Classification of Pygmy languages#Original Pygmy language(s)",
}

m["tai-shz"] = {
	"Shangsi Zhuang",
	13216,
	"za",
}

m["tbq-pro"] = {
	"Proto-Tibeto-Burman",
	7251864,
	"sit-pro",
}

m["und-idn"] = {
	"Idiom Neutral",
	35847,
	"und", -- or "vo"
	wikipedia_article = "Idiom Neutral",
}

m["und-tdl"] = {
	"Turduli",
	nil,
	"und",
	wikipedia_article = "Turduli",
}

m["und-tdt"] = {
	"Turdetani",
	nil,
	"und",
	wikipedia_article = "Turdetani",
}

m["und-xnu"] = {
	"Xiongnu",
	10901674,
	"und",
	wikipedia_article = "Xiongnu",
}

m["urj-fpr-pro"] = {
	"Proto-Finno-Permic",
	nil,
	"urj-pro",
}

m["woy"] = {
	"Weyto",
	3915918,
	"und",
}

m["th-new"] = {
	"Hacked Thai", -- temporary for testing new translit/display methods
	nil,
	"th",
	translit = "User:Benwing2/th-scraping-translit",
	display_text = "User:Benwing2/th-scraping-translit",
	entry_name = "User:Benwing2/th-scraping-translit",
	preprocess_links = "User:Benwing2/th-scraping-translit",
}

m = require("Module:languages").addDefaultTypes(m, false, "etymology-only")
return require("Module:languages").finalizeEtymologyData(m)
