local labels = {}

-- NOTE: The labels below are grouped by "lect group" (e.g. Mandarin, Wu, Yue) and then alphabetized within each
-- lect group. Hokkien is under "Min". If you don't find a given lect group, look under the "Other groups" below;
-- also keep in mind the "Miscellaneous" at the bottom for labels that don't refer to a topolect.

------------------------------------------ Gan ------------------------------------------

labels["Gan"] = {
	Wikipedia = "Gan Chinese",
	regional_categories = true,
}

labels["dialectal Gan"] = {
	Wikipedia = "Gan Chinese",
	regional_categories = "Gan",
}

labels["Lichuan Gan"] = {
	-- A variety of Fuguang Gan
	Wikipedia = "zh:撫廣片", -- link for Fuguang Gan
	plain_categories = true,
}

labels["Nanchang Gan"] = {
	-- A variety of Chang–Du Gan (where it is the principal dialect).
	Wikipedia = "Chang–Du Gan",
	plain_categories = true,
}

labels["Pingxiang Gan"] = {
	-- A variety of Yiliu Gan.
	Wikipedia = "Yi–Liu Gan",
	plain_categories = true,
}

labels["Taining Gan"] = {
	-- A variety of Fuguang Gan.
	Wikipedia = "zh:撫廣片", -- link for Fuguang Gan
	plain_categories = true,
}

------------------------------------------ Hakka ------------------------------------------

labels["Hakka"] = {
	Wikipedia = "Hakka Chinese",
	regional_categories = true,
}

labels["dialectal Hakka"] = {
	Wikipedia = "Hakka Chinese",
	regional_categories = "Hakka",
}

labels["Dabu Hakka"] = {
	aliases = {"Dabu"},
	Wikipedia = "zh:大埔話",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Early Modern Hakka"] = {
	Wikipedia = "Hakka Chinese",
	plain_categories = true,
}

labels["Hailu Hakka"] = {
	aliases = {"Hailu"},
	Wikipedia = "Hailu dialect",
	plain_categories = true,
}

labels["Hong Kong Hakka"] = {
	Wikipedia = "Hakka language",
	plain_categories = true,
}

labels["Huiyang Hakka"] = {
	aliases = {"Huiyang"},
	Wikipedia = "zh:惠阳话",
	plain_categories = true,
}

-- FIXME: Category missing.
--labels["Jiangxi Hakka"] = {
--	-- Multiple dialects; possibly referring to Tonggu County dialect.
--	Wikipedia = true,
--	plain_categories = true,
--}

-- FIXME: Category missing.
labels["Malaysian Huiyang Hakka"] = {
	aliases = {"Malaysia Huiyang Hakka"},
	Wikipedia = "zh:惠阳话",
	plain_categories = true,
}

labels["Meixian Hakka"] = {
	aliases = {"Meixian", "Moiyan", "Moiyan Hakka", "Meizhou", "Meizhou Hakka"},
	Wikipedia = "Meixian dialect",
	plain_categories = true,
}

labels["Northern Sixian Hakka"] = {
	aliases = {"Northern Sixian"},
	Wikipedia = "Sixian dialect",
	plain_categories = true,
}

labels["Raoping Hakka"] = {
	-- No Raoping alias because Chaoshan Min is also spoken.
	Wikipedia = true,
	plain_categories = true,
}

labels["Sixian Hakka"] = {
	aliases = {"Sixian"},
	Wikipedia = "Sixian dialect",
	plain_categories = true,
}

labels["Southern Sixian Hakka"] = {
	aliases = {"Southern Sixian"},
	Wikipedia = "Sixian dialect",
	plain_categories = true,
}

labels["Shangyou Hakka"] = {
	-- In southwestern Jiangxi.
	aliases = {"Shangyou"},
	Wikipedia = "Shangyou County",
	plain_categories = true,
}

labels["Taiwanese Hakka"] = {
	aliases = {"Taiwan Hakka"},
	Wikipedia = true,
	plain_categories = true,
}

-- Skipped: Wuluo Hakka; appears to originate in Pingtung County, Taiwan and be part of Southern Sixian Hakka, maybe
-- related to the Wuluo River, but extremely obscure; can't find anything about the dialect in Google.

labels["Yudu Hakka"] = {
	aliases = {"Yudu"},
	Wikipedia = "Yudu County",
	plain_categories = true,
}

labels["Yunlin Hakka"] = {
	-- A type of Taiwanese Hakka.
	aliases = {"Yunlin"},
	Wikipedia = "Yunlin County",
	plain_categories = true,
}

labels["Zhao'an Hakka"] = {
	Wikipedia = "zh:詔安客語",
	plain_categories = true,
}

------------------------------------------ Jin ------------------------------------------

labels["Jin"] = {
	Wikipedia = "Jin Chinese",
	regional_categories = true,
}

labels["dialectal Jin"] = {
	Wikipedia = "Jin Chinese",
	regional_categories = "Jin",
}

labels["Xinzhou Jin"] = {
	-- no "Xinzhou" alias; Xinzhou Wu (different Xinzhou) also exists
	-- In the Wutai subgroup
	Wikipedia = "Xinzhou",
	plain_categories = true,
}

------------------------------------------ Literary Chinese ------------------------------------------

labels["Korean Classical Chinese"] = {
	Wikipedia = "Chinese-language literature of Korea",
	plain_categories = true,
}

labels["Standard Written Chinese"] = {
	aliases = {"SWC", "WVC", "Written vernacular Chinese", "Written Vernacular Chinese"},
	Wikipedia = "Written vernacular Chinese",
}

labels["Vietnamese Classical Chinese"] = {
	Wikipedia = "Literary Chinese in Vietnam",
	plain_categories = true,
}

------------------------------------------ Mandarin ------------------------------------------

labels["Mandarin"] = {
	Wikipedia = "Mandarin Chinese",
	regional_categories = true,
}

labels["dialectal Mandarin"] = {
	Wikipedia = "Mandarin Chinese",
	regional_categories = "Mandarin",
}

labels["Beijing Mandarin"] = {
	aliases = {"Beijing", "Peking", "Pekingese"},
	Wikipedia = "Beijing dialect",
	plain_categories = true,
}

labels["Central Plains Mandarin"] = {
	aliases = {"Central Plains", "Zhongyuan Mandarin"},
	Wikipedia = true,
	plain_categories = true,
}

labels["Guangxi Mandarin"] = {
	-- No Guangxi alias; seems unlikely to be correct
	Wikipedia = "Southwestern Mandarin",
	plain_categories = true,
}

labels["Guanzhong Mandarin"] = {
	aliases = {"Guanzhong"},
	Wikipedia = "Guanzhong dialect",
	plain_categories = true,
}

labels["Guilin Mandarin"] = {
	-- No Guilin alias; also Guilin Pinghua, Guilin Southern Min
	-- A subvariety of Guiliu Mandarin, which is a variety of Southwestern Mandarin.
	Wikipedia = "Southwestern Mandarin",
	plain_categories = true,
}

labels["Guiyang Mandarin"] = {
	-- A variety of Southwestern Mandarin
	aliases = {"Guiyang"},
	Wikipedia = "zh:貴陽話", -- Q15911623
	plain_categories = true,
}

labels["Harbin Mandarin"] = {
	-- A variety of Northeastern Mandarin
	aliases = {"Harbin"},
	Wikipedia = "Harbin dialect", -- Q1006919
	plain_categories = true,
}

-- FIXME: Category missing.
--labels["Hui Mandarin"] = {
--	-- Hui is an ethnic group; multiple dialects depending on the city in question.
--	Wikipedia = "???",
--	plain_categories = true,
--}

labels["Jianghuai Mandarin"] = {
	aliases = {"Jianghuai", "Jiang-Huai", "Jiang-Huai Mandarin", "Lower Yangtze Mandarin", "Huai"},
	Wikipedia = "Lower Yangtze Mandarin",
	plain_categories = true,
}

labels["Jiaoliao Mandarin"] = {
	aliases = {"Jiaoliao", "Jiao-Liao", "Jiao-Liao Mandarin"},
	Wikipedia = true,
	plain_categories = true,
}

labels["Jilu Mandarin"] = {
	aliases = {"Jilu", "Ji-Lu", "Ji-Lu Mandarin"},
	Wikipedia = true,
	plain_categories = true,
}

labels["Lanyin Mandarin"] = {
	aliases = {"Lanyin", "Lan-Yin Mandarin"},
	Wikipedia = true,
	plain_categories = true,
}

labels["Lanzhou Mandarin"] = {
	-- A variety of Lanyin Mandarin.
	aliases = {"Lanzhou"},
	Wikipedia = "zh:兰州话", -- Q10893628
	plain_categories = true,
}

labels["Liuzhou Mandarin"] = {
	-- A subvariety of Guiliu Mandarin, which is a variety of Southwestern Mandarin.
	Wikipedia = "zh:柳州话", -- Q7224853
	plain_categories = true,
}

labels["Luoyang Mandarin"] = {
	-- A variety of Central Plains Mandarin.
	aliases = {"Luoyang"},
	Wikipedia = "Luoyang dialect", -- Q3431347
	plain_categories = true,
}

labels["Malaysian Mandarin"] = {
	aliases = {"Malaysia Mandarin"},
	Wikipedia = true,
	plain_categories = true,
}

labels["Muping Mandarin"] = {
	-- A subvariety of the Yantai dialect of Jiaoliao Mandarin.
	aliases = {"Muping"}, -- there is also a Muping in Sichuan but it's not clear if it has a dialect
	Wikipedia = "Muping, Yantai",
	plain_categories = true,
}

labels["Nanjing Mandarin"] = {
	aliases = {"Nanjing"},
	Wikipedia = "Nanjing dialect",
	plain_categories = true,
}

labels["Nantong Mandarin"] = {
	-- A subvariety of Tongtai (Tairu) Mandarin, which is a variety of Jianghuai (Lower Yangtze) Mandarin.
	-- On the English Wikipedia, 'Nantong dialect' redirects to [[w:Tong-Tai Mandarin]].
	-- no Nantong alias; Nantong Wu also exists
	Wikipedia = "zh:南通话", -- Q10909110
	plain_categories = true,
}

labels["Northeastern Mandarin"] = {
	aliases = {"northeastern Mandarin", "NE Mandarin"},
	Wikipedia = true,
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Philippine Mandarin"] = {
	aliases = {"Philippines Mandarin"},
	Wikipedia = "Mandarin Chinese in the Philippines",
	plain_categories = true,
}

-- The following violates normal conventions, which would use "Sichuan Mandarin". But it matches the 'Sichuanese'
-- language.
labels["Sichuanese"] = {
	aliases = {"Sichuan"},
	Wikipedia = "Sichuanese dialect",
	regional_categories = true,
}

-- We use 'Singapore Mandarin' not 'Singaporean Mandarin' despite the Wikipedia article both to match all the other
-- Singapore language varieties (which say 'Singapore' not 'Singaporean') and because the form with 'Singapore' seeems
-- actually more common in Google Scholar.
labels["Singapore Mandarin"] = {
	aliases = {"Singaporean Mandarin"},
	Wikipedia = "Singaporean Mandarin",
	plain_categories = true,
}

labels["Southwestern Mandarin"] = {
	aliases = {"southwestern Mandarin", "Upper Yangtze Mandarin", "Southwest Mandarin"},
	Wikipedia = true,
	plain_categories = true,
}

labels["Taiwanese Mandarin"] = {
	aliases = {"Taiwan Mandarin"},
	Wikipedia = true,
	plain_categories = true,
}

labels["Tianjin Mandarin"] = {
	aliases = {"Tianjin", "Tianjinese", "Tianjinese Mandarin"},
	Wikipedia = "Tianjin dialect",
	plain_categories = true,
}

labels["Ürümqi Mandarin"] = {
	-- A variety of Lanyin Mandarin.
	aliases = {"Ürümqi", "Urumqi Mandarin", "Urumqi"},
	Wikipedia = "zh:乌鲁木齐话", -- Q10878256
	plain_categories = true,
}

labels["Wanrong Mandarin"] = {
	-- A subvariety of Fenhe Mandarin, which is a variety of Central Plains Mandarin.
	aliases = {"Wanrong"}, -- Wanrong County in Shanxi; there is a Wanrong Township (mountain indigenous township)
						   -- in Hualien County, Taiwan, mostly inhabited by Taiwan Aborigines
	Wikipedia = "zh:汾河片", -- Q10379509; article on Fenhe Mandarin
	plain_categories = true,
}

labels["Wuhan Mandarin"] = {
	aliases = {"Wuhan", "Hankou", "Hankow"},
	Wikipedia = "Wuhan dialect",
	plain_categories = true,
}

labels["Xi'an Mandarin"] = {
	-- A subvariety of Guanzhong Mandarin, which is a variety of Central Plains Mandarin.
	aliases = {"Xi'an"},
	Wikipedia = "Xi'an dialect", -- Q123700130; currently a redirect to [[w:Guanzhong dialect]]
	plain_categories = true,
}

labels["Xining Mandarin"] = {
	-- A variety of Lanyin Mandarin.
	aliases = {"Xining"},
	Wikipedia = "Lanyin Mandarin",
	plain_categories = true,
}

labels["Xinjiang Mandarin"] = {
	aliases = {"Xinjiang"},
	Wikipedia = true,
	plain_categories = true,
}

labels["Xuzhou Mandarin"] = {
	-- A variety of Central Plains Mandarin.
	aliases = {"Xuzhou"},
	Wikipedia = "Xuzhou dialect", -- Q8045307
	plain_categories = true,
}

labels["Yangzhou Mandarin"] = {
	aliases = {"Yangzhou"},
	Wikipedia = "Lower Yangtze Mandarin",
	plain_categories = true,
}

labels["Yinchuan Mandarin"] = {
	-- A variety of Lanyin Mandarin.
	aliases = {"Yinchuan"},
	Wikipedia = "Lanyin Mandarin", -- "Yinchuan Mandarin" has its own Wikidata item Q125021069 but has no links
	plain_categories = true,
}

-- FIXME: Category missing.
--labels["Yunnan Mandarin"] = {
--	-- Multiple dialects: Kunming dialect (Central Yunnan), Gejiu dialect (Southern Yunnan), Baoshan dialect
--	(Western Yunnan).
--	-- "Yunnan" as alias seems unlikely to be correct
--	Wikipedia = "???",
--	plain_categories = true,
--}

------------------------------------------ Min ------------------------------------------

labels["Min"] = {
	Wikipedia = "Min Chinese",
	regional_categories = true,
}

labels["Central Min"] = {
	aliases = {"Min Zhong"},
	Wikipedia = true,
	regional_categories = true,
}

labels["Coastal Min"] = {
	aliases = {"coastal Min"},
	Wikipedia = true,
}

labels["Datian Min"] = {
	aliases = {"Datian"},
	Wikipedia = true,
	regional_categories = true,
}

labels["Eastern Min"] = {
	aliases = {"Min Dong"},
	Wikipedia = true,
	regional_categories = true,
}

labels["dialectal Eastern Min"] = {
	aliases = {"dialectal Min Dong"},
	Wikipedia = "Eastern Min",
	regional_categories = "Eastern Min",
}

-- The following violates normal conventions, which would use "Hainanese Min' or 'Hainan Min'. But it matches the
-- 'Hainanese' language and Wikipedia.
labels["Hainanese"] = {
	aliases = {"Hainan Min", "Hainanese Min", "Hainan Min Chinese"},
	Wikipedia = true,
	regional_categories = true,
}

-- FIXME: Category missing.
labels["Haklau Min"] = {
	aliases = {"Hoklo Min", "Haklau", "Hoklo"},
	Wikipedia = "Hoklo Min",
	regional_categories = true,
}

labels["Inland Min"] = {
	aliases = {"inland Min"},
	Wikipedia = true,
}

labels["Leizhou Min"] = {
	aliases = {"Leizhou"},
	Wikipedia = true,
	regional_categories = true,
}

labels["Northern Min"] = {
	aliases = {"Min Bei"},
	Wikipedia = true,
	regional_categories = true,
}

labels["Puxian Min"] = {
	aliases = {"Puxian", "Pu-Xian Min", "Pu-Xian", "Xinghua", "Hinghwa"},
	Wikipedia = "Pu-Xian Min",
	regional_categories = true,
}

-- FIXME: Category missing.
labels["Shaojiang Min"] = {
	aliases = {"Shaojiang"},
	Wikipedia = "Shao–Jiang Min",
	regional_categories = true,
}

labels["Southern Min"] = {
	aliases = {"Min Nan"},
	Wikipedia = true,
	regional_categories = true,
	track = true,
}

labels["dialectal Southern Min"] = {
	aliases = {"dialectal Min Nan"},
	Wikipedia = "Southern Min",
	regional_categories = "Southern Min",
}

labels["Zhongshan Min"] = {
	Wikipedia = true,
	regional_categories = true,
}

---------------------- Hokkien ----------------------

labels["Hokkien"] = {
	Wikipedia = true,
	regional_categories = true,
}

labels["Anxi Hokkien"] = {
	-- A type of Quanzhou Hokkien.
	aliases = {"Anxi"},
	Wikipedia = "zh:安溪县#語言文化",
	plain_categories = true,
}

labels["Changtai Hokkien"] = {
	-- A type of Zhangzhou Hokkien.
	aliases = {"Changtai"},
	Wikipedia = "Changtai, Zhangzhou#Local Dialect",
	plain_categories = true,
}

labels["Hsinchu Hokkien"] = {
	-- Taiwanese. Per [[w:Taiwanese_Hokkien#Quanzhou–Zhangzhou inclinations]], mixed Quanzhou-Zhangzhou dialect
	-- similar to Tong'an accent.
	aliases = {"Hsinchu"},
	Wikipedia = "zh:新竹市#語言",
	plain_categories = true,
}

labels["Hui'an Hokkien"] = {
	-- Mostly spoken in Hui'an in southern Fujian.
	aliases = {"Hui'an"},
	Wikipedia = "Hui'an dialect",
	plain_categories = true,
}

-- FIXME: Same as Medan Hokkien?
labels["Indonesian Hokkien"] = {
	aliases = {"Indonesia Hokkien"},
	Wikipedia = "Medan Hokkien",
	plain_categories = true,
}

labels["Jinjiang Hokkien"] = {
	aliases = {"Jinjiang"},
	Wikipedia = "Quanzhou dialect",
	plain_categories = true,
}

labels["Kaohsiung Hokkien"] = {
	-- Taiwanese. Per [[w:Taiwanese_Hokkien#Quanzhou–Zhangzhou inclinations]], mixed Quanzhou-Zhangzhou dialect
	-- similar to Amoy accent.
	aliases = {"Kaohsiung"},
	Wikipedia = "Kaohsiung#Languages",
	plain_categories = true,
}

labels["Kinmen Hokkien"] = {
	-- Taiwanese. Per [[w:Kinmen#Language]], mostly Quanzhou dialect (but in Wuchiu/Wuqiu Township, Puxian Min is
	-- spoken).
	aliases = {"Kinmen"},
	Wikipedia = "Kinmen#Language",
	plain_categories = true,
}

labels["Longyan Hokkien"] = {
	aliases = {"Longyan"},
	Wikipedia = "Longyan dialect",
	plain_categories = true,
}

labels["Lukang Hokkien"] = {
	-- Taiwanese. Per [[w:Taiwanese_Hokkien#Quanzhou–Zhangzhou inclinations]], based on Quanzhou accent.
	Wikipedia = "Lukang",
	plain_categories = true,
}

labels["Malaysian Hokkien"] = {
	aliases = {"Malaysia Hokkien"},
	Wikipedia = "Southern Peninsular Malaysian Hokkien",
	plain_categories = true,
}

labels["Magong Hokkien"] = {
	-- Taiwanese. Apparently a subdialect of Penghu Hokkien.
	aliases = {"Magong"},
	Wikipedia = "Magong",
	plain_categories = true,
}

labels["Medan Hokkien"] = {
	-- Spoken in Indonesia.
	Wikipedia = "Medan dialect",
	plain_categories = true,
}

labels["Penang Hokkien"] = {
	-- Malaysian.
	aliases = {"Penang"},
	Wikipedia = true,
	plain_categories = true,
}

labels["Penghu Hokkien"] = {
	-- Taiwanese. Per [[w:Penghu#Language]], mostly Tong'an dialect.
	aliases = {"Penghu"},
	Wikipedia = "Penghu#Language",
	plain_categories = true,
}

labels["Philippine Hokkien"] = {
	aliases = {"PH Hokkien", "Ph Hokkien", "PH", "PHH", "Philippines Hokkien"},
	Wikipedia = true,
	plain_categories = true,
}

labels["Quanzhou Hokkien"] = {
	aliases = {"Quanzhou", "Chinchew", "Choanchew"},
	Wikipedia = "Quanzhou dialect",
	plain_categories = true,
}

labels["Sanxia Hokkien"] = {
	-- Taiwanese.
	Wikipedia = "Sanxia District",
	plain_categories = true,
}

-- We use 'Singapore Hokkien' not 'Singaporean Hokkien' despite the Wikipedia article both to match all the other
-- Singapore language varieties (which say 'Singapore' not 'Singaporean') and because the form with 'Singapore' seeems
-- actually more common in Google Scholar.
labels["Singapore Hokkien"] = {
	aliases = {"Singaporean Hokkien"},
	Wikipedia = "Singaporean Hokkien",
	plain_categories = true,
}

labels["Taichung Hokkien"] = {
	-- Taiwanese. Per [[w:Taiwanese_Hokkien#Quanzhou–Zhangzhou inclinations]], mostly Zhangzhou dialect.
	-- No alias for Taichung because there's also Taichung Mandarin ([[w:zh:台中腔]]).
	Wikipedia = "Taichung",
	plain_categories = true,
}

labels["Tainan Hokkien"] = {
	-- Taiwanese. Per [[w:zh:臺灣話#方言差]], part of "臺南混合腔" = "Tainan mixed dialect".
	aliases = {"Tainan"},
	Wikipedia = "zh:臺南市#語言",
	plain_categories = true,
}

labels["Taipei Hokkien"] = {
	-- Taiwanese. Per [[w:Taiwanese_Hokkien#Quanzhou–Zhangzhou inclinations]], mixed Quanzhou-Zhangzhou dialect
	-- similar to Tong'an accent.
	Wikipedia = "Taipei",
	plain_categories = true,
}

labels["Taiwanese Hokkien"] = {
	aliases = {"Taiwanese Southern Min", "Taiwanese Min Nan", "Taiwan Hokkien", "Taiwan Southern Min", "Taiwan Min Nan"},
	Wikipedia = true,
	plain_categories = true,
	track = true,
}

labels["Tong'an Hokkien"] = {
	-- Taiwanese. Per [[zh:同安区#語言]], one of four main dialects of Hokkien in the southern Fujian region,
	-- along with Quanzhou, Zhangzhou and Xiamen.
	aliases = {"Tong'an"},
	Wikipedia = "zh:同安区#語言",
	plain_categories = true,
}

labels["Xiamen Hokkien"] = {
	aliases = {"Xiamen", "Amoy"},
	Wikipedia = "Amoy dialect",
	plain_categories = true,
}

labels["Yilan Hokkien"] = {
	-- Taiwanese. Per [[w:zh:臺灣話]], relatively pure Zhangzhou Hokkien.
	aliases = {"Yilan"},
	Wikipedia = "zh:漳州话#與其他閩南語方言的比較",
	plain_categories = true,
}

labels["Yongchun Hokkien"] = {
	aliases = {"Yongchun"},
	Wikipedia = "Yongchun dialect",
	plain_categories = true,
}

labels["Zhao'an Hokkien"] = {
	Wikipedia = "zh:詔安縣#詔安閩南語",
	plain_categories = true,
}

labels["Zhangping Hokkien"] = {
	-- A type of Zhangzhou Hokkien.
	aliases = {"Zhangping"},
	Wikipedia = "zh:漳平话",
	plain_categories = true,
}

labels["Zhangzhou Hokkien"] = {
	aliases = {"Zhangzhou", "Changchew"},
	Wikipedia = "Zhangzhou dialect",
	plain_categories = true,
}

---------------------- Teochew ----------------------

-- The following violates normal conventions, which would use "Teochew Southern Min" or possibly "Teochew Min". But it
-- matches the 'Teochew' full language.
labels["Teochew"] = {
	Wikipedia = "Chaoshan Min", -- not [[w:Teochew dialect]], which is a dialect of this language
	regional_categories = true,
	track = true,
}

labels["Chaozhou Teochew"] = {
	aliases = {"Chaozhou"},
	Wikipedia = "Teochew dialect",
	plain_categories = true,
}

labels["Jieyang Teochew"] = {
	aliases = {"Jieyang"},
	Wikipedia = "Jieyang",
	plain_categories = true,
}

labels["Pontianak Teochew"] = {
	-- spoken in West Kalimantan, Indonesia
	aliases = {"Pontianak"},
	Wikipedia = "Pontianak", -- "Pontianak Teochew" has its own Wikidata entry Q106560423, but it has no links
	plain_categories = true,
}

labels["Singapore Teochew"] = {
	aliases = {"Singaporean Teochew"},
	Wikipedia = "Teochew people#Teochew immigration to Singapore",
	plain_categories = true,
}

labels["Thai Teochew"] = {
	aliases = {"Thailand Teochew"},
	Wikipedia = "Thai Chinese#Language",
	plain_categories = true,
}

------------------------------------------ Pinghua ------------------------------------------

labels["Pinghua"] = {
	Wikipedia = true,
	regional_categories = true,
}

labels["Guilin Pinghua"] = {
	-- A variety of Northern Pinghua.
	Wikipedia = "zh:桂北平话", -- Q84302463; the Northern Pinghua redirect
	plain_categories = true,
}

labels["Nanning Pinghua"] = {
	-- A variety of Southern Pinghua.
	Wikipedia = "zh:桂南平话", -- Q84302019; the Southern Pinghua redirect
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Northern Pinghua"] = {
	-- Spoken in northern Guangxi, around the city of Guilin.
	-- English Wikipedia article redirects to Pinghua; Chinese Wikipedia article similarly redirects but contains
	-- more information on Northern Pinghua.
	Wikipedia = "zh:桂北平话", -- Q84302463
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Southern Pinghua"] = {
	-- Spoken in southern Guangxi, around the city of Nanning.
	-- English Wikipedia article redirects to Pinghua; Chinese Wikipedia article similarly redirects but contains
	-- more information on Southern Pinghua.
	Wikipedia = "zh:桂南平话", -- Q84302019
	plain_categories = true,
}

------------------------------------------ Wu ------------------------------------------

labels["Wu"] = {
	Wikipedia = "Wu Chinese",
	regional_categories = true,
}

labels["dialectal Wu"] = {
	Wikipedia = "Wu Chinese",
	regional_categories = "Wu",
}

labels["Changzhounese Wu"] = {
	aliases = {"Changzhou Wu", "Changzhou", "Changzhounese"},
	Wikipedia = "Changzhou dialect",
	plain_categories = true,
}

labels["Chuzhou Wu"] = {
	aliases = {"Chuzhou", "Lishuinese", "Fujian Wu", "Lishui Wu"},
	Wikipedia = "Lishui dialect",
	plain_categories = true,
}

labels["Danyang Wu"] = {
	aliases = {"Danyang"},
	Wikipedia = "Danyang, Jiangsu",
	plain_categories = true,
}

labels["Hangzhounese Wu"] = {
	aliases = {"Hangzhou", "Hangzhounese", "Hangzhou Wu"},
	-- FIXME: Consider removing the following exception and letting it display as 'Hangzhounese Wu'.
	display = "Hangzhounese",
	Wikipedia = "Hangzhou dialect",
	plain_categories = true,
}

labels["Huzhounese Wu"] = {
	aliases = {"Huzhou", "Huzhou Wu", "Huzhounese"},
	Wikipedia = "zh:湖州話",
	plain_categories = true,
}

labels["Linshao Wu"] = {
	aliases = {"Linshao", "Lin-Shao Wu", "Lin-Shao"},
	Wikipedia = "Shaoxing dialect",
	plain_categories = true,
}

labels["Ningbonese Wu"] = {
	aliases = {"Ningbonese", "Ningbo Wu", "Ningbo"},
	Wikipedia = "Ningbo dialect",
	plain_categories = true,
}

labels["Northern Wu"] = {
	aliases = {"Taihu", "Taihu Wu"},
	Wikipedia = true,
	plain_categories = true,
}

labels["Shadi Wu"] = {
	aliases = {"Shadi", "Chongming", "Chongming Wu", "Qihai", "Qihai Wu"},
	Wikipedia = "Shadi dialect", -- Q6112340
	plain_categories = true,
}

labels["Shanghainese Wu"] = {
	aliases = {"Shanghai Wu", "Shanghainese"},
	-- FIXME: Consider removing the following exception and letting it display as 'Shanghainese Wu'.
	display = "Shanghainese",
	Wikipedia = "Shanghainese",
	plain_categories = true,
}

labels["Shaoxing Wu"] = {
	aliases = {"Shaoxing", "Shaoxingnese", "Shaoxingnese Wu", "Shaoxingese", "Shaoxingese Wu"},
	Wikipedia = "Shaoxing dialect",
	plain_categories = true,
}

labels["Southern Wu"] = {
	Wikipedia = "Wu Chinese",
	plain_categories = true,
}

labels["Sujiahu Wu"] = {
	aliases = {"Su-Jia-Hu Wu", "Sujiahu", "Su-Jia-Hu"}, -- not Suzhou-Jiaxing-Huzhou
	display = "[[w:Suzhou dialect|Su]][[w:zh:嘉興話|jia]][[w:Shanghainese|hu]] [[w:Wu Chinese|Wu]]",
	plain_categories = "Northern Wu",
}

labels["Suzhounese Wu"] = {
	aliases = {"Suzhou", "Suzhounese", "Suzhou Wu"},
	-- FIXME: Consider removing the following exception and letting it display as 'Suzhounese Wu'.
	display = "Suzhounese",
	Wikipedia = "Suzhou dialect",
	plain_categories = true,
}

labels["Wenzhounese Wu"] = {
	aliases = {"Wenzhounese", "Wenzhou Wu", "Wenzhou", "Oujiang"},
	-- FIXME: Consider removing the following exception and letting it display as 'Wenzhounese Wu'.
	display = "Wenzhounese",
	Wikipedia = "Wenzhou dialect",
	plain_categories = true,
}

labels["Wuzhou Wu"] = {
	aliases = {"Jinhua Wu", "Jinhuanese", "Jinhuanese Wu", "Wuzhou"},
	Wikipedia = "Jinhua dialect",
	plain_categories = true,
}

labels["Xinqu Wu"] = {
	aliases = {"Xinqu", "Quzhou Wu", "Quzhounese", "Quzhounese Wu", "Shangrao", "Shangrao Wu", "Shangraonese", "Shangraonese Wu", "Xinzhou Wu"},
	Wikipedia = "Quzhou dialect",
	plain_categories = true,
}

-- labels["Zhejiang Wu"] = {
-- 	-- several dialects of different subgroups
-- 	aliases = {"Zhejiang"},
-- 	Wikipedia = "Zhejiang",
-- 	plain_categories = true,
-- }

------------------------------------------ Xiang ------------------------------------------

labels["Xiang"] = {
	Wikipedia = "Xiang Chinese",
	regional_categories = true,
}

labels["dialectal Xiang"] = {
	Wikipedia = "Xiang Chinese",
	regional_categories = "Xiang",
}

-- FIXME: Category missing.
labels["Changsha Xiang"] = {
	aliases = {"Changsha"},
	Wikipedia = "Changsha dialect", -- New Xiang
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Hengyang Xiang"] = {
	aliases = {"Hengyang"},
	Wikipedia = "Hengyang dialect",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Hengzhou Xiang"] = {
	aliases = {"Hengzhou"},
	Wikipedia = "Hengyang dialect",
	plain_categories = true,
}

labels["Loudi Xiang"] = {
	aliases = {"Loudi"},
	Wikipedia = "zh:娄底话",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["New Xiang"] = {
	Wikipedia = true,
	plain_categories = true,
}

labels["Old Xiang"] = {
	Wikipedia = true,
	plain_categories = true,
}

labels["Shuangfeng Xiang"] = {
	aliases = {"Shuangfeng"},
	Wikipedia = "Shuangfeng dialect",
	plain_categories = true,
}

------------------------------------------ Yue ------------------------------------------

labels["Cantonese"] = {
	Wikipedia = true,
	regional_categories = true,
}

labels["dialectal Cantonese"] = {
	Wikipedia = "Cantonese",
	regional_categories = "Cantonese",
}

-- FIXME: Category missing.
labels["Dongguan Cantonese"] = {
	-- A subvariety of Guanbao Cantonese.
	aliases = {"Dongguan"},
	Wikipedia = "Dongguan",
	plain_categories = true,
}

-- FIXME: Category missing.
-- labels["Guangxi Cantonese"] = {
--  -- Multiple Yue subgroups spoken in Guangxi
-- 	-- Guangxi alias not correct as there are multiple languages spoken in Guangxi
-- 	Wikipedia = "Guangxi",
-- 	plain_categories = true,
-- }

labels["Guangzhou Cantonese"] = {
	aliases = {"Guangzhou"},
	Wikipedia = "Cantonese",
	plain_categories = true,
}

labels["Hong Kong Cantonese"] = {
	aliases = {"HKC"},
	Wikipedia = true,
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Malaysian Cantonese"] = {
	aliases = {"Malaysia Cantonese"},
	Wikipedia = true,
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Singapore Cantonese"] = {
	aliases = {"Singaporean Cantonese"},
	Wikipedia = "Chinese Singaporeans#Cantonese",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Siyi Yue"] = {
	aliases = {"Siyi"},
	Wikipedia = true,
	plain_categories = true,
}

-- The following violates normal conventions, which would use "Taishan Yue" or "Taishanese Yue". But it matches the
-- current 'Taishanese' full language. If (as proposed by [[User:Wpi]]) we demote Taishanese to an etym-only variety
-- of Siyi Yue, we should consider renaming to Taishan Yue or Taishanese Yue.
labels["Taishanese"] = {
	aliases = {"Toishanese", "Hoisanese"},
	Wikipedia = true,
	regional_categories = true,
}

-- FIXME: Category missing.
labels["US 1 Cantonese"] = {
	Wikipedia = "Chinese language and varieties in the United States",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Yangjiang Cantonese"] = {
	aliases = {"Yangjiang"}, -- FIXME: Correct?
	Wikipedia = "zh:陽江話",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Yulin Cantonese"] = {
	aliases = {"Yulin"}, -- FIXME: Correct?
	Wikipedia = "zh:玉林話",
	plain_categories = true,
}

------------------------------------------ Other groups ------------------------------------------

-- FIXME: Category missing.
labels["Danzhou Chinese"] = {
	aliases = {"Danzhou"},
	Wikipedia = "Danzhou dialect",
	plain_categories = true,
}

labels["Dungan"] = {
	Wikipedia = "Dungan language",
	regional_categories = true,
}

labels["Gansu Dungan"] = {
	display = "[[Gansu]] [[w:Dungan language|Dungan]]",
	plain_categories = true,
}

labels["Huizhou"] = {
	aliases = {"Huizhou Chinese"},
	Wikipedia = "Huizhou Chinese",
	regional_categories = true,
}

labels["Shehua"] = {
	Wikipedia = true,
	regional_categories = true,
}

labels["Waxiang"] = {
	Wikipedia = "Waxiang Chinese",
	regional_categories = true,
}

------------------------------------------ Miscellaneous ------------------------------------------

labels["American (&ndash;1980)"] = {
	aliases = {"America 1", "United States 1", "USA 1", "US 1"},
	Wikipedia = "History of Chinese Americans",
	regional_categories = true,
}

labels["American (1980&ndash;)"] = {
	aliases = {"America 2", "United States 2", "USA 2", "US 2"},
	Wikipedia = "History of Chinese Americans",
	regional_categories = true,
}

labels["North America"] = {
	aliases = {"North American"},
	display = "[[Canada]], [[American English|US]]",
	regional_categories = {"Canadian", "American"},
}

return require("Module:labels").finalize_data(labels)
