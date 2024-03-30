local labels = {}

-- NOTE: The labels below are grouped by "lect group" (e.g. Mandarin, Wu, Yue) and then alphabetized within each
-- lect group. Hokkien is under "Min". If you don't find a given lect group, look under the "Other groups" below;
-- also keep in mind the "Miscellaneous" at the bottom for labels that don't refer to a topolect.

------------------------------------------ Gan ------------------------------------------

labels["Gan"] = {
	Wikidata = "Q33475",
	regional_categories = true,
}

labels["dialectal Gan"] = {
	Wikidata = "Q33475", -- article for Gan Chinese
	regional_categories = "Gan",
}

labels["Lichuan Gan"] = {
	-- A variety of Fuguang Gan
	Wikidata = "Q6794539", -- article for Fuguang Gan
	plain_categories = true,
}

labels["Nanchang Gan"] = {
	-- A variety of Changdu Gan (where it is the principal dialect).
	Wikidata = "Q3497239", -- article for Changdu Gan
	plain_categories = true,
}

labels["Pingxiang Gan"] = {
	-- A variety of Yiliu Gan.
	Wikidata = "Q8053438", -- article for Yiliu Gan
	plain_categories = true,
}

labels["Taining Gan"] = {
	-- A variety of Fuguang Gan.
	Wikidata = "Q6794539", -- article for Fuguang Gan
	plain_categories = true,
}

------------------------------------------ Hakka ------------------------------------------

labels["Hakka"] = {
	Wikidata = "Q33375",
	regional_categories = true,
}

labels["dialectal Hakka"] = {
	Wikidata = "Q33375", -- article for Hakka Chinese
	regional_categories = "Hakka",
}

labels["Dabu Hakka"] = {
	aliases = {"Dabu"},
	Wikidata = "Q19855566",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Early Modern Hakka"] = {
	Wikidata = "Q33375", -- article for Hakka Chinese
	plain_categories = true,
}

labels["Hailu Hakka"] = {
	aliases = {"Hailu"},
	Wikidata = "Q19855025", -- see also Q17038519 "Hailu Hakka" in Wikidata, which duplicates Q19855025 and redirects to it in Chinese Wikipedia
	plain_categories = true,
}

labels["Hong Kong Hakka"] = {
	Wikidata = "Q2675834",
	plain_categories = true,
}

labels["Huiyang Hakka"] = {
	aliases = {"Huiyang"},
	Wikidata = "Q16873881",
	plain_categories = true,
}

-- FIXME: Category missing.
--labels["Jiangxi Hakka"] = {
--	-- Multiple dialects; possibly referring to Tonggu County dialect.
--	plain_categories = true,
--}

-- FIXME: Category missing.
labels["Malaysian Huiyang Hakka"] = {
	aliases = {"Malaysia Huiyang Hakka"},
	Wikidata = "Q16873881", -- article for Huiyang Hakka
	plain_categories = true,
}

labels["Meixian Hakka"] = {
	aliases = {"Meixian", "Moiyan", "Moiyan Hakka", "Meizhou", "Meizhou Hakka"},
	Wikidata = "Q839295",
	plain_categories = true,
}

labels["Northern Sixian Hakka"] = {
	aliases = {"Northern Sixian"},
	Wikidata = "Q9668261", -- article for Sixian Hakka
	plain_categories = true,
}

labels["Raoping Hakka"] = {
	-- No Raoping alias because Chaoshan Min is also spoken.
	Wikidata = "Q19854038",
	plain_categories = true,
}

labels["Sixian Hakka"] = {
	aliases = {"Sixian"},
	Wikidata = "Q9668261",
	plain_categories = true,
}

labels["Southern Sixian Hakka"] = {
	aliases = {"Southern Sixian"},
	Wikidata = "Q9668261", -- article for Sixian Hakka; Q98095139 is "Southern Sixian dialect" but has no articles linked
	plain_categories = true,
}

labels["Shangyou Hakka"] = {
	-- In southwestern Jiangxi.
	aliases = {"Shangyou"},
	Wikidata = "Q1282613", -- article for Shangyou County
	plain_categories = true,
}

labels["Taiwanese Hakka"] = {
	aliases = {"Taiwan Hakka"},
	Wikidata = "Q2391532",
	plain_categories = true,
}

-- Skipped: Wuluo Hakka; appears to originate in Pingtung County, Taiwan and be part of Southern Sixian Hakka, maybe
-- related to the Wuluo River, but extremely obscure; can't find anything about the dialect in Google.

labels["Yudu Hakka"] = {
	aliases = {"Yudu"},
	Wikidata = "Q1816748", -- article for Yudu County
	plain_categories = true,
}

labels["Yunlin Hakka"] = {
	-- A type of Taiwanese Hakka.
	aliases = {"Yunlin"},
	Wikidata = "Q153221", -- article for Yunlin County
	plain_categories = true,
}

labels["Zhao'an Hakka"] = {
	Wikidata = "Q6703311",
	plain_categories = true,
}

------------------------------------------ Jin ------------------------------------------

labels["Jin"] = {
	Wikidata = "Q56479",
	regional_categories = true,
}

labels["dialectal Jin"] = {
	Wikidata = "Q56479", -- article for Jin Chinese
	regional_categories = "Jin",
}

labels["Xinzhou Jin"] = {
	-- no "Xinzhou" alias; Xinzhou Wu (different Xinzhou) also exists
	-- In the Wutai subgroup
	Wikidata = "Q73119", -- article for Xinzhou (city in Shanxi)
	plain_categories = true,
}

------------------------------------------ Literary Chinese ------------------------------------------

labels["Korean Classical Chinese"] = {
	Wikidata = "Q10496257",
	plain_categories = true,
}

labels["Standard Written Chinese"] = {
	aliases = {"SWC", "WVC", "Written vernacular Chinese", "Written Vernacular Chinese"},
	Wikidata = "Q783605",
}

labels["Vietnamese Classical Chinese"] = {
	Wikidata = "Q17034227",
	plain_categories = true,
}

------------------------------------------ Mandarin ------------------------------------------

labels["Mandarin"] = {
	Wikidata = "Q9192",
	regional_categories = true,
}

labels["dialectal Mandarin"] = {
	Wikidata = "Q9192", -- article for Mandarin Chinese
	regional_categories = "Mandarin",
}

-- FIXME: Category missing.
labels["Beijingic Mandarin"] = {
	-- A primary branch. "Beijingic" is the term used by Glottolog. Wikipedia calls this
	-- [[w:Beijing Mandarin (division of Mandarin)]] as opposed to [[w:Beijing dialect]] for Beijing Mandarin itself,
	-- but this is excessively ambiguous.
	-- Dialects per Wikipedia: [[w:Beijing dialect]] (with [[w:Standard Chinese]] as a child),
	-- [[w:Philippine Mandarin]], [[w:Malaysian Mandarin]], Chengde dialect (承德话), Chifeng dialect (赤峰话), Hailar
	-- dialect (海拉尔话).
	aliases = {"Beijingic"},
	Wikidata = "Q2169652",
	plain_categories = true,
}

labels["Beijing Mandarin"] = {
	-- A variety of Beijingic Mandarin.
	aliases = {"Beijing", "Peking", "Pekingese"},
	Wikidata = "Q1147606",
	plain_categories = true,
}

labels["Central Plains Mandarin"] = {
	-- A primary branch.
	-- Dialects per Wikipedia: [[w:Dungan language]], [[w:Gangou dialect]], Kaifeng dialect (开封话),
	-- [[w:Luoyang dialect]], Nanyang dialect (南阳话), Qufu dialect (曲埠话), Tianshui dialect (天水话),
	-- [[w:Xi'an dialect]], [[w:Xuzhou dialect]], Yan'an dialect (延安话), Zhengzhou dialect (郑州话).
	aliases = {"Central Plains", "Zhongyuan Mandarin"},
	Wikidata = "Q3048775",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Changchun Mandarin"] = {
	-- A variety of Northeastern Mandarin.
	aliases = {"Changchun"},
	Wikidata = "Q17030513",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Dalian Mandarin"] = {
	-- A variety of Jiaoliao Mandarin.
	aliases = {"Dalian"},
	Wikidata = "Q1375036",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Gangou Mandarin"] = {
	-- A variety of Central Plains Mandarin.
	aliases = {"Gangou"},
	Wikidata = "Q17050290",
	plain_categories = true,
}

labels["Guangxi Mandarin"] = {
	-- No Guangxi alias; seems unlikely to be correct
	Wikidata = "Q2609239", -- article for Southwestern Mandarin
	plain_categories = true,
}

labels["Guanzhong Mandarin"] = {
	-- A variety of Central Plains Mandarin.
	aliases = {"Guanzhong"},
	Wikidata = "Q3431648",
	plain_categories = true,
}

labels["Guilin Mandarin"] = {
	-- No Guilin alias; also Guilin Pinghua, Guilin Southern Min
	-- A subvariety of Guiliu Mandarin, which is a variety of Southwestern Mandarin.
	Wikidata = "Q11111636",
	plain_categories = true,
}

labels["Guiliu Mandarin"] = {
	-- A variety of Southwestern Mandarin.
	Wikidata = "Q11111664",
	plain_categories = true,
}

labels["Guiyang Mandarin"] = {
	-- A variety of Southwestern Mandarin.
	aliases = {"Guiyang"},
	Wikidata = "Q15911623",
	plain_categories = true,
}

labels["Harbin Mandarin"] = {
	-- A variety of Northeastern Mandarin.
	aliases = {"Harbin"},
	Wikidata = "Q1006919",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Hefei Mandarin"] = {
	-- A variety of Jianghuai Mandarin.
	aliases = {"Hefei"},
	Wikidata = "Q10916956",
	plain_categories = true,
}

-- FIXME: Category missing.
--labels["Hui Mandarin"] = {
--	-- Hui is an ethnic group; multiple dialects depending on the city in question.
--	Wikipedia = "???",
--	plain_categories = true,
--}

labels["Jianghuai Mandarin"] = {
	-- A primary branch.
	-- Dialects per Wikipedia: [[w:Hefei dialect]], Hainan Junjiahua (军家话), [[w:Nanjing dialect]],
	-- [[w:Nantong dialect]], Xiaogan dialect (孝感话), Yangzhou dialect (扬州话).
	aliases = {"Jianghuai", "Jiang-Huai", "Jiang-Huai Mandarin", "Lower Yangtze Mandarin", "Huai"},
	Wikidata = "Q2128953",
	plain_categories = true,
}

labels["Jiaoliao Mandarin"] = {
	-- A primary branch.
	-- Dialects per Wikipedia: [[w:Dalian dialect]], [[w:Qingdao dialect]], [[w:Weihai dialect]], Yantai dialect
	-- (烟台话).
	aliases = {"Jiaoliao", "Jiao-Liao", "Jiao-Liao Mandarin"},
	Wikidata = "Q2597550",
	plain_categories = true,
}

labels["Jilu Mandarin"] = {
	-- A primary branch.
	-- Dialects per Wikipedia: Baoding dialect (保定话), [[w:Jinan dialect]], Shijiazhuang dialect (石家庄话),
	-- [[w:Tianjin dialect]].
	aliases = {"Jilu", "Ji-Lu", "Ji-Lu Mandarin"},
	Wikidata = "Q516721",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Jinan Mandarin"] = {
	-- A variety of Jilu Mandarin.
	aliases = {"Jinan"},
	Wikidata = "Q6202017",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Kunming Mandarin"] = {
	-- A variety of Southwestern Mandarin.
	aliases = {"Kunming"},
	Wikidata = "Q3372400",
	plain_categories = true,
}

labels["Lanyin Mandarin"] = {
	-- A primary branch.
	-- Dialects per Wikipedia: Lanzhou dialect (兰州话), Xining dialect (西宁话), Yinchuan dialect (银川话).
	aliases = {"Lanyin", "Lan-Yin Mandarin"},
	Wikidata = "Q662754",
	plain_categories = true,
}

labels["Lanzhou Mandarin"] = {
	-- A variety of Lanyin Mandarin.
	aliases = {"Lanzhou"},
	Wikidata = "Q10893628",
	plain_categories = true,
}

labels["Liuzhou Mandarin"] = {
	-- A subvariety of Guiliu Mandarin, which is a variety of Southwestern Mandarin.
	Wikidata = "Q7224853",
	plain_categories = true,
}

labels["Luoyang Mandarin"] = {
	-- A variety of Central Plains Mandarin.
	aliases = {"Luoyang"},
	Wikidata = "Q3431347",
	plain_categories = true,
}

labels["Malaysian Mandarin"] = {
	aliases = {"Malaysia Mandarin"},
	Wikidata = "Q13646143",
	plain_categories = true,
}

labels["Muping Mandarin"] = {
	-- A subvariety of the Yantai dialect of Jiaoliao Mandarin.
	aliases = {"Muping"}, -- there is also a Muping in Sichuan but it's not clear if it has a dialect
	Wikidata = "Q281015", -- article for Muping District
	plain_categories = true,
}

labels["Nanjing Mandarin"] = {
	-- A variety of Jianghuai Mandarin.
	aliases = {"Nanjing"},
	Wikidata = "Q2681098",
	plain_categories = true,
}

labels["Nantong Mandarin"] = {
	-- A subvariety of Tongtai (Tairu) Mandarin, which is a variety of Jianghuai (Lower Yangtze) Mandarin.
	-- On the English Wikipedia, 'Nantong dialect' redirects to [[w:Tong-Tai Mandarin]].
	-- no Nantong alias; Nantong Wu also exists
	Wikidata = "Q10909110",
	plain_categories = true,
}

labels["Northeastern Mandarin"] = {
	-- A primary branch.
	-- Dialects per Wikipedia: [[w:Changchun dialect]], [[w:Harbin dialect]], Qiqihar dialect (齐齐哈尔话),
	-- [[w:Shenyang dialect]].
	aliases = {"northeastern Mandarin", "NE Mandarin"},
	Wikidata = "Q1064504",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Qingdao Mandarin"] = {
	-- A variety of Jiaoliao Mandarin.
	aliases = {"Qingdao"},
	Wikidata = "Q7267815",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Philippine Mandarin"] = {
	aliases = {"Philippines Mandarin"},
	Wikidata = "Q7185155",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Shenyang Mandarin"] = {
	-- A variety of Northeastern Mandarin.
	aliases = {"Shenyang"},
	Wikidata = "Q7494349",
	plain_categories = true,
}

-- We use 'Singapore Mandarin' not 'Singaporean Mandarin' despite the Wikipedia article both to match all the other
-- Singapore language varieties (which say 'Singapore' not 'Singaporean') and because the form with 'Singapore' seeems
-- actually more common in Google Scholar.
labels["Singapore Mandarin"] = {
	aliases = {"Singaporean Mandarin"},
	Wikidata = "Q1048980",
	plain_categories = true,
}

labels["Southwestern Mandarin"] = {
	-- A primary branch.
	-- Dialects per Wikipedia: Changde dialect (常德话), [[w:Chengdu dialect]], [[w:Chongqing dialect]], Dali dialect
	-- (大理话), Guiyang dialect (贵阳话), [[w:Kunming dialect]], Liuzhou dialect (柳州话), [[w:Wuhan dialect]],
	-- [[w:Xichang dialect]], Yichang dialect (宜昌话), Hanzhong dialect (汉中话).
	aliases = {"southwestern Mandarin", "Upper Yangtze Mandarin", "Southwest Mandarin"},
	Wikidata = "Q2609239",
	plain_categories = true,
}

labels["Taiwanese Mandarin"] = {
	aliases = {"Taiwan Mandarin"},
	Wikidata = "Q262828",
	plain_categories = true,
}

labels["Tianjin Mandarin"] = {
	aliases = {"Tianjin", "Tianjinese", "Tianjinese Mandarin"},
	Wikidata = "Q7800220",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Tongtai Mandarin"] = {
	-- A variety of Jianghuai Mandarin.
	aliases = {"Tongtai", "Tairu Mandarin", "Tairu"},
	Wikidata = "Q7820911",
	plain_categories = true,
}

labels["Ürümqi Mandarin"] = {
	-- A variety of Lanyin Mandarin.
	aliases = {"Ürümqi", "Urumqi Mandarin", "Urumqi"},
	Wikidata = "Q10878256",
	plain_categories = true,
}

labels["Wanrong Mandarin"] = {
	-- A subvariety of Fenhe Mandarin, which is a variety of Central Plains Mandarin.
	aliases = {"Wanrong"}, -- Wanrong County in Shanxi; there is a Wanrong Township (mountain indigenous township)
						   -- in Hualien County, Taiwan, mostly inhabited by Taiwan Aborigines
	Wikidata = "Q10379509", -- article on Fenhe Mandarin
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Weihai Mandarin"] = {
	-- A variety of Jiaoliao Mandarin.
	aliases = {"Weihai"},
	Wikidata = "Q3025951",
	plain_categories = true,
}

labels["Wuhan Mandarin"] = {
	aliases = {"Wuhan", "Hankou", "Hankow"},
	Wikidata = "Q11124731",
	plain_categories = true,
}

labels["Xi'an Mandarin"] = {
	-- A subvariety of Guanzhong Mandarin, which is a variety of Central Plains Mandarin.
	aliases = {"Xi'an"},
	Wikidata = "Q123700130", -- currently a redirect to [[w:Guanzhong dialect]]
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Xichang Mandarin"] = {
	-- A variety of Southwestern Mandarin.
	aliases = {"Xichang"},
	Wikidata = "Q17067030",
	plain_categories = true,
}

labels["Xining Mandarin"] = {
	-- A variety of Lanyin Mandarin.
	aliases = {"Xining"},
	Wikidata = "Q662754", -- article on Lanyin Mandarin
	plain_categories = true,
}

labels["Xinjiang Mandarin"] = {
	-- Depending on where in Xinjiang, either a variety of Lanyin Mandarin or Central Plains Mandarin.
	aliases = {"Xinjiang"},
	Wikidata = "Q93684068",
	plain_categories = true,
}

labels["Xuzhou Mandarin"] = {
	-- A variety of Central Plains Mandarin.
	aliases = {"Xuzhou"},
	Wikidata = "Q8045307",
	plain_categories = true,
}

labels["Yangzhou Mandarin"] = {
	-- A variety of Jianghuai Mandarin.
	aliases = {"Yangzhou"},
	Wikidata = "Q11076194",
	plain_categories = true,
}

labels["Yinchuan Mandarin"] = {
	-- A variety of Lanyin Mandarin.
	aliases = {"Yinchuan"},
	Wikidata = "Q662754", -- article on Lanyin Mandarin; "Yinchuan Mandarin" has its own Wikidata item Q125021069 but has no links
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Yunnan Mandarin"] = {
	-- A (strange) variety of Southwestern Mandarin.
	-- "Yunnan" as alias seems unlikely to be correct
	Wikidata = "Q10881055",
	plain_categories = true,
}

---------------------- Sichuanese ----------------------

-- The following violates normal conventions, which would use "Sichuan Mandarin". But it matches the 'Sichuanese'
-- language.
labels["Sichuanese"] = {
	-- A variety of Southwestern Mandarin.
	aliases = {"Sichuan"},
	Wikidata = "Q2278732",
	regional_categories = true,
}

labels["Chengdu Sichuanese"] = {
	-- A variety of Chengyu Sichuanese.
	aliases = {"Chengdu", "Chengdu Mandarin"},
	Wikidata = "Q11074683",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Chengyu Sichuanese"] = {
	aliases = {"Chengyu", "Chengyu Mandarin", "Chengdu-Chongqing", "Chengdu-Chongqing Mandarin"},
	Wikidata = "Q5091311",
	plain_categories = true,
}

labels["Chongqing Sichuanese"] = {
	-- A variety of Chengyu Sichuanese.
	aliases = {"Chongqing", "Chongqing Mandarin"},
	Wikidata = "Q15902531",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Leshan Sichuanese"] = {
	-- A variety of Minjiang Sichuanese.
	aliases = {"Leshan", "Leshan Mandarin"},
	Wikidata = "Q6530337",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Minjiang Sichuanese"] = {
	aliases = {"Minjiang", "Minjiang Mandarin"},
	Wikidata = "Q6867767",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Renfu Sichuanese"] = {
	-- Jianggong is used by zhwiki.
	aliases = {"Renfu", "Renfu Mandarin", "Renshou-Fushun", "Renshou-Fushun Mandarin", "Renshou-Fushun Sichuanese", "Jianggong", "Jianggong Mandarin", "Jianggong Sichuanese"},
	Wikidata = "Q10883781",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Yamian Sichuanese"] = {
	aliases = {"Yamian", "Yamian Mandarin"},
	Wikidata = "Q56243639",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Zigong Sichuanese"] = {
	-- A variety of Renfu Sichuanese.
	aliases = {"Zigong", "Zigong Mandarin"},
	Wikidata = "Q8071810",
	plain_categories = true,
}

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

-- The following violates normal conventions, which would use "Hainanese Min' or 'Hainan Min'. But it matches the
-- 'Hainanese' language and Wikipedia.
labels["Hainanese"] = {
	aliases = {"Hainan Min", "Hainanese Min", "Hainan Min Chinese"},
	Wikipedia = true,
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

labels["Zhongshan Min"] = {
	Wikipedia = true,
	regional_categories = true,
}

---------------------- Eastern Min ----------------------

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

-- FIXME: Category missing.
labels["Changle Eastern Min"] = {
	-- A subvariety of Fuzhou Eastern Min, which is a subvariety of Houguan Eastern Min.
	aliases = {"Changle"},
	Wikidata = "Q19856351",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Fu'an Eastern Min"] = {
	-- A subvariety of Funing Eastern Min; the representative variety.
	aliases = {"Fu'an"},
	Wikidata = "Q7216573",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Fuding Eastern Min"] = {
	-- A subvariety of Funing Eastern Min.
	aliases = {"Fuding", "Tongshan", "Tongshan Eastern Min"},
	Wikidata = "Q19853248",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Funing Eastern Min"] = {
	-- A primary branch; should possibly be called North Eastern Min.
	aliases = {"Funing"},
	Wikidata = "Q18943896",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Fuqing Eastern Min"] = {
	-- A subvariety of Houguan Eastern Min.
	aliases = {"Fuqing"},
	Wikidata = "Q15895753",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Fuzhou Eastern Min"] = {
	-- A subvariety of Houguan Eastern Min; the representative variety.
	aliases = {"Fuzhou"},
	Wikidata = "Q35571",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Gutian Eastern Min"] = {
	-- A subvariety of Houguan Eastern Min.
	aliases = {"Gutian"},
	Wikidata = "Q18944085",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Houguan Eastern Min"] = {
	-- A primary branch; should possibly be called South Eastern Min.
	-- Other varieties of Houguan Eastern Min not given entries here because they have no associated Wikipedia
	-- articles or Wikidata entries:
	  -- Minhou Eastern Min
	  -- Youxi Eastern Min
	  -- Dai Yunshan Eastern Min
	  -- Yongtai Eastern Min
	  -- Pingnan Eastern Min
	  -- Pingtan Eastern Min
	  -- Luoyuan Eastern Min
	aliases = {"Houguan"},
	Wikidata = "Q18943758",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Lianjiang Eastern Min"] = {
	-- A subvariety of Fuzhou Eastern Min, which is a subvariety of Houguan Eastern Min.
	aliases = {"Lianjiang"},
	Wikidata = "Q19856291",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Manjiang Eastern Min"] = {
	-- A primary branch. Has some influences from Wu, but usually classified as Eastern Min.
	-- Chinese Wikipedia distinguishes between "Manjiang" (蛮讲) and "Manhua" (蛮话) and claims they are two
	-- distinct varieties, but I think this is based on confusion; for example, they both have the same ISO 639-6
	-- code "maua", and the English Wikipedia specifically asserts that both 蛮讲 and 蛮话 are the same.
	aliases = {"Manjiang", "Manhua Eastern Min", "Manhua", "Mango Eastern Min", "Mango"},
	Wikidata = "Q3431721",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Matsu Eastern Min"] = {
	-- A subvariety of Fuzhou Eastern Min, which is a subvariety of Houguan Eastern Min.
	aliases = {"Matsu"},
	Wikidata = "Q19599280",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Minqing Eastern Min"] = {
	-- A subvariety of Houguan Eastern Min.
	aliases = {"Minqing"},
	Wikidata = "Q48897247",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Ningde Eastern Min"] = {
	-- A subvariety of Funing Eastern Min.
	aliases = {"Ningde"},
	Wikidata = "Q18941249",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Shouning Eastern Min"] = {
	-- A subvariety of Funing Eastern Min.
	aliases = {"Shouning"},
	Wikidata = "Q19852223",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Xiapu Eastern Min"] = {
	-- A subvariety of Funing Eastern Min.
	aliases = {"Xiapu"},
	Wikidata = "Q15899756",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Zherong Eastern Min"] = {
	-- A subvariety of Funing Eastern Min.
	aliases = {"Zherong"},
	Wikidata = "Q19852850",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Zhouning Eastern Min"] = {
	-- A subvariety of Funing Eastern Min.
	aliases = {"Zhouning", "Zhoudun", "Zhoudun Eastern Min"},
	Wikidata = "Q19852132",
	plain_categories = true,
}

---------------------- Northern Min ----------------------

labels["Northern Min"] = {
	aliases = {"Min Bei"},
	Wikipedia = true,
	regional_categories = true,
}

-- FIXME: Category missing.
labels["Chong'an Northern Min"] = {
	-- A subvariety of Xixi Northern Min.
	aliases = {"Chong'an", "Wuyishan Northern Min", "Wuyishan"},
	Wikidata = "Q19855654",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Dongxi Northern Min"] = {
	-- A primary branch. Maybe should be called East Northern Min. Note here that Dongxi is 東溪 (dōngxī); here dōng
	-- means "east", but the second xī does not mean "west" but more like "stream" or "creek".
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Xixi Northern Min"] = {
	-- A primary branch. Maybe should be called West Northern Min. Note here that Xixi is 西溪 (xīxī); here the first
	-- xī means "west", but the second xī does not mean "west" but more like "stream" or "creek".
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Jian'ou Northern Min"] = {
	-- A subvariety of Dongxi Northern Min; the representative variety.
	aliases = {"Jian'ou"},
	Wikidata = "Q6191447",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Jianyang Northern Min"] = {
	-- A subvariety of Xixi Northern Min; the representative variety.
	aliases = {"Jianyang"},
	Wikidata = "Q16930647",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Nanping Northern Min"] = {
	-- A subvariety of Dongxi Northern Min.
	aliases = {"Nanping"},
	Wikidata = "Q68534", -- the entry for the city of Nanping; currently no article for the lect
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Songxi Northern Min"] = {
	-- A subvariety of Dongxi Northern Min.
	aliases = {"Songxi"},
	Wikidata = "Q19855892",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Zhenghe Northern Min"] = {
	-- A subvariety of Dongxi Northern Min.
	aliases = {"Zhenghe"},
	Wikidata = "Q19855758",
	plain_categories = true,
}

---------------------- Southern Min ----------------------

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

labels["Datian Min"] = {
	aliases = {"Datian"},
	Wikipedia = true,
	regional_categories = true,
}

-- FIXME: Category missing.
labels["Haklau Min"] = {
	aliases = {"Hoklo Min", "Haklau", "Hoklo"},
	Wikipedia = "Hoklo Min",
	regional_categories = true,
}

---------------- Hokkien ----------------

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
	Wikidata = "Q15937822",
	plain_categories = true,
}

labels["Zhangzhou Hokkien"] = {
	aliases = {"Zhangzhou", "Changchew"},
	Wikipedia = "Zhangzhou dialect",
	plain_categories = true,
}

---------------- Teochew ----------------

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
	Wikidata = "Q84302463", -- the Northern Pinghua redirect
	plain_categories = true,
}

labels["Nanning Pinghua"] = {
	-- A variety of Southern Pinghua.
	Wikidata = "Q84302019", -- the Southern Pinghua redirect
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Northern Pinghua"] = {
	-- Spoken in northern Guangxi, around the city of Guilin.
	-- English Wikipedia article redirects to Pinghua; Chinese Wikipedia article similarly redirects but contains
	-- more information on Northern Pinghua.
	Wikidata = "Q84302463",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Southern Pinghua"] = {
	-- Spoken in southern Guangxi, around the city of Nanning.
	-- English Wikipedia article redirects to Pinghua; Chinese Wikipedia article similarly redirects but contains
	-- more information on Southern Pinghua.
	Wikidata = "Q84302019",
	plain_categories = true,
}

------------------------------------------ Wu ------------------------------------------

labels["Wu"] = {
	Wikidata = "Q34290",
	regional_categories = true,
}

labels["dialectal Wu"] = {
	Wikidata = "Q34290", -- article for Wu Chinese
	regional_categories = "Wu",
}

-- labels["Zhejiang Wu"] = {
-- 	-- several dialects of different subgroups
-- 	aliases = {"Zhejiang"},
-- 	Wikipedia = "Zhejiang",
-- 	plain_categories = true,
-- }

---------------------- Northern Wu ----------------------

-- FIXME: Category missing.
labels["Anji Wu"] = {
	-- A subvariety of Tiaoxi Wu, which is a variety of Northern Wu.
	aliases = {"Anji"},
	Wikidata = "Q111270089",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Changxing Wu"] = {
	-- A subvariety of Tiaoxi Wu, which is a variety of Northern Wu.
	aliases = {"Changxing"},
	Wikidata = "Q11126990",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Changzhounese Wu"] = {
	-- A subvariety of Piling Wu, which is a variety of Northern Wu.
	aliases = {"Changzhou Wu", "Changzhou", "Changzhounese"},
	-- FIXME: Consider removing the following exception and letting it display as 'Hangzhounese Wu'.
	display = "Changzhounese",
	Wikidata = "Q1021819",
	plain_categories = true,
}

labels["Danyang Wu"] = {
	-- Apparently a subvariety of Piling Wu, which is a variety of Northern Wu.
	aliases = {"Danyang"},
	Wikidata = "Q925293", -- article for Danyang, Jiangsu
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Deqing Wu"] = {
	-- A subvariety of Tiaoxi Wu, which is a variety of Northern Wu.
	aliases = {"Deqing"},
	Wikidata = "Q109343820",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Fuyang Wu"] = {
	-- A subvariety of Linshao Wu, which is a variety of Northern Wu.
	aliases = {"Fuyang"},
	Wikipedia = "zh:富阳话", -- no Wikidata item yet
	plain_categories = true,
}

labels["Hangzhounese Wu"] = {
	-- An isolate variety of Northern Wu with heavy Northern Mandarinic (ie. not
	-- Huai) influence from the Southern Song Dyansty
	aliases = {"Hangzhou", "Hangzhounese", "Hangzhou Wu"},
	-- FIXME: Consider removing the following exception and letting it display as 'Hangzhounese Wu'.
	display = "Hangzhounese",
	Wikidata = "Q5648144",
	plain_categories = true,
}

labels["Huzhounese Wu"] = {
	-- A subvariety of Tiaoxi Wu, which is a variety of Northern Wu.
	aliases = {"Huzhou", "Huzhou Wu", "Huzhounese"},
	-- FIXME: Consider removing the following exception and letting it display as 'Hangzhounese Wu'.
	display = "Huzhounese",
	Wikidata = "Q15901269",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Jiangyin Wu"] = {
	-- A subvariety of Piling Wu, which is a variety of Northern Wu; but
	-- transitional to Sujiahu Wu.
	aliases = {"Jiangyin"},
	Wikidata = "Q6191803",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Jiaxing Wu"] = {
	-- A subvariety of Sujiahu Wu, which is a variety of Northern Wu.
	aliases = {"Jiaxing"},
	Wikidata = "Q30130993",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Jinhui Wu"] = {
	-- A subvariety of Sujiahu Wu, which is a variety of Northern Wu.
	aliases = {"Jinhui", "Dangdai Wu", "Dangdai", "Dônđäc"},
	Wikidata = "Q16259341",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Jintan Wu"] = {
	-- A subvariety of Piling Wu, which is a variety of Northern Wu.
	aliases = {"Jintan"},
	Wikidata = "Q15904190",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Jinxiang Wu"] = {
	-- An isolated variety of Northern Wu from Zhejiang.
	aliases = {"Jinxiang"},
	Wikidata = "Q2427960",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Jingjiang Wu"] = {
	-- A subvariety of Piling Wu, which is a variety of Northern Wu.
	aliases = {"Lao'an", "Jingjiang", "Lao'an"},
	Wikipedia = "zh:老岸话", -- no Wikidata item yet
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Lin'an Wu"] = {
	-- A subvariety of Linshao Wu, which is a variety of Northern Wu.
	aliases = {"Lin'an"},
	Wikidata = "Q1022464", -- article for Lin'an District (part of the prefecture-level city of Hangzhou)
	plain_categories = true,
}

labels["Linshao Wu"] = {
	-- A variety of Northern Wu.
	aliases = {"Linshao", "Lin-Shao Wu", "Lin-Shao"},
	Wikidata = "Q7489194", -- article for Shaoxing dialect, the representative variety
	plain_categories = true,
}

labels["Ningbonese Wu"] = {
	-- A subvariety of Yongjiang Wu, which is a variety of Northern Wu.
	aliases = {"Ningbonese", "Ningbo Wu", "Ningbo"},
	-- FIXME: Consider removing the following exception and letting it display as 'Hangzhounese Wu'.
	display = "Ningbonese",
	Wikidata = "Q3972199",
	plain_categories = true,
}

labels["Northern Wu"] = {
	-- A primary branch.
	aliases = {"Taihu", "Taihu Wu"},
	Wikidata = "Q7675988",
	plain_categories = true,
}

-- FIXME: Category missing.
-- why is this a thing??
labels["Northern Zhejiang Wu"] = {
	-- A variety of Northern Wu.
	aliases = {"Northern Zhejiang"},
	plain_categories = true,
}

-- FIXME: Category missing.
-- this too why was this added ??
labels["Northwestern Wu"] = {
	-- A variety of Northern Wu.
	aliases = {"Northern Zhejiang"}, -- if Piling is under "Northwestern" then. why is it Northern ZHEJIANG?
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Old Guangde Wu"] = {
	-- A subvariety of Tiaoxi Wu, which is a variety of Northern Wu.
	aliases = {"Old Guangde", "Southeast Guangde Wu", "Southeast Guangde"},
	Wikidata = "Q7084146",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Old Langxi Wu"] = {
	-- A subvariety of Piling Wu, which is a variety of Northern Wu.
	aliases = {"Old Langxi", "Lao Langxi Wu", "Lao Langxi"},
	Wikidata = "Q15911930",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Piling Wu"] = {
	-- A variety of Northern Wu.
	aliases = {"Piling"},
	Wikidata = "Q1021819", -- article for Changzhou dialect
	plain_categories = true,
}

labels["Shadi Wu"] = {
	-- A subvariety of Sujiahu Wu, which is a variety of Northern Wu.
	aliases = {"Shadi", "Chongming", "Chongming Wu", "Qihai", "Qihai Wu"},
	Wikidata = "Q6112340",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Shanghainese Wu"] = {
	-- A subvariety of Sujiahu Wu, which is a variety of Northern Wu.
	aliases = {"Shanghai Wu", "Shanghainese"},
	-- FIXME: Consider removing the following exception and letting it display as 'Shanghainese Wu'.
	display = "Shanghainese",
	Wikidata = "Q36718",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Shangyu Wu"] = {
	-- A subvariety of Linshao Wu, which is a variety of Northern Wu.
	aliases = {"Shangyu"},
	Wikipedia = "zh:上虞話", -- no Wikidata item yet
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Shaoxing Wu"] = {
	-- A subvariety of Linshao Wu, which is a variety of Northern Wu.
	aliases = {"Shaoxing", "Shaoxingnese", "Shaoxingnese Wu", "Shaoxingese", "Shaoxingese Wu"},
	Wikidata = "Q7489194",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Shengzhou Wu"] = {
	-- A subvariety of Linshao Wu, which is a variety of Northern Wu.
	aliases = {"Shengzhou"},
	Wikidata = "Q11054430",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Sujiahu Wu"] = {
	-- A variety of Northern Wu.
	aliases = {"Sujiahu", "Su-Jia-Hu Wu", "Su-Jia-Hu", "Suhujia Wu", "Suhujia", "Su-Hu-Jia Wu", "Su-Hu-Jia"}, -- not Suzhou-Jiaxing-Huzhou
	Wikidata = "Q17036256",
	-- display = "[[w:Suzhou dialect|Su]][[w:zh:嘉興話|jia]][[w:Shanghainese|hu]] [[w:Wu Chinese|Wu]]",
	plain_categories = true,
}

labels["Suzhounese Wu"] = {
	-- A subvariety of Sujiahu Wu, which is a variety of Northern Wu.
	aliases = {"Suzhou", "Suzhounese", "Suzhou Wu"},
	-- FIXME: Consider removing the following exception and letting it display as 'Suzhounese Wu'.
	display = "Suzhounese",
	Wikidata = "Q831744",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Tiaoxi Wu"] = {
	-- A variety of Northern Wu.
	aliases = {"Tiaoxi"},
	Wikidata = "Q11010462",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Tonglu Wu"] = {
	-- A subvariety of Linshao Wu, which is a variety of Northern Wu.
	aliases = {"Tonglu"},
	Wikidata = "Q18654008",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Urban Shanghainese Wu"] = {
	-- A subvariety of Shanghainese Wu, which is a subvariety of Sujiahu Wu, which is a variety of Northern Wu.
	aliases = {"Urban Shanghai Wu", "Urban Shanghainese", "Urban Shanghai"},
	Wikipedia = "Shanghainese#Classification",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Wuxi Wu"] = {
	-- A subvariety of Sujiahu Wu, which is a variety of Northern Wu.
	aliases = {"Wuxi"},
	Wikidata = "Q2325035",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Xiaoshan Wu"] = {
	-- A subvariety of Linshao Wu, which is a variety of Northern Wu.
	aliases = {"Xiaoshan"},
	Wikidata = "Q60993472",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Xinchang Wu"] = {
	-- A subvariety of Linshao Wu, which is a variety of Northern Wu.
	aliases = {"Xinchang"},
	Wikidata = "Q11082821",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Yixing Wu"] = {
	-- A subvariety of Piling Wu, which is a variety of Northern Wu.
	aliases = {"Yixing"},
	Wikipedia = "zh:宜興話", -- no Wikidata item yet
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Yongjiang Wu"] = {
	-- A variety of Northern Wu.
	aliases = {"Yongjiang"},
	Wikidata = "Q15503785",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Yuhang Wu"] = {
	-- A subvariety of Tiaoxi Wu, which is a variety of Northern Wu.
	aliases = {"Yuhang"},
	Wikidata = "Q109414979",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Zhoushan Wu"] = {
	-- A subvariety of Yongjiang Wu, which is a variety of Northern Wu.
	aliases = {"Zhoushan"},
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Zhuji Wu"] = {
	-- A subvariety of Linshao Wu, which is a variety of Northern Wu.
	aliases = {"Zhuji"},
	Wikidata = "Q18119187",
	plain_categories = true,
}

---------------------- Southern Wu ----------------------

-- FIXME: Category missing.
labels["Baizhang Wu"] = {
	-- A variety of Oujiang Wu.
	aliases = {"Baizhang", "Xialu Wu", "Xialu"},
	Wikipedia = "zh:百丈口话", -- no Wikidata item yet
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Beitai Wu"] = {
	-- A variety of Taizhouic Wu.
	aliases = {"Beitai"},
	-- Undefined in Chinese Wikipedia
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Changbei Wu"] = {
	-- A divergent subvariety of Taigao Wu, which is a variety of Xuanzhou Wu.
	aliases = {"Changbei"},
	Wikipedia = "zh:昌北话", -- no Wikidata item yet
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Chuqu Wu"] = {
	-- A primary branch.
	aliases = {"Chuqu"},
	Wikidata = "Q5116499",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Chuzhou Wu"] = {
	-- A variety of Chuqu Wu.
	aliases = {"Chuzhou"},
	-- Undefined in Chinese Wikipedia
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Dongyang Wu"] = {
	-- A subvariety of Yiyong Wu, which is a variety of Wuzhou Wu.
	aliases = {"Dongyang"},
	Wikidata = "Q109417928",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Duze Wu"] = {
	-- A subvariety of Longqu Wu, which is a variety of Chuqu Wu.
	aliases = {"Duze"},
	Wikipedia = "zh:杜泽话", -- no Wikidata item yet
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Gaochun Wu"] = {
	-- A subvariety of Taigao Wu, which is a variety of Xuanzhou Wu.
	aliases = {"Gaochun"},
	Wikidata = "Q17035529",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Hongqiao Wu"] = {
	-- A variety of Oujiang Wu.
	aliases = {"Hongqiao"},
	Wikidata = "Q15933359",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Hou'an Wu"] = {
	-- A subvariety of Shiling Wu, which is a variety of Xuanzhou Wu.
	aliases = {"Hou'an"},
	Wikidata = "Q10911034",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Jiangshan Wu"] = {
	-- A subvariety of Shangshan Wu, which is a variety of Chuqu Wu.
	aliases = {"Jiangshan"},
	Wikidata = "Q6112693",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Jingxian Wu"] = {
	-- A subvariety of Tongjing Wu, which is a variety of Xuanzhou Wu.
	aliases = {"Jingxian"},
	Wikidata = "Q11151690",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Jinhua Wu"] = {
	-- A subvariety of Jinlan Wu, which is a variety of Wuzhou Wu.
	aliases = {"Jinhua", "Jinhuanese", "Jinhuanese Wu"},
	Wikidata = "Q13583347",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Jinlan Wu"] = {
	-- A variety of Wuzhou Wu.
	aliases = {"Jinlan"},
	-- Undefined in Chinese Wikipedia
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Jiuhua Wu"] = {
	-- A subvariety of Longqu Wu, which is a variety of Chuqu Wu.
	aliases = {"Jiuhua"},
	Wikipedia = "zh:九华话", -- no Wikidata item yet
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Jujiang Wu"] = {
	-- Possibly a variety of Oujiang Wu. Also has characteristics of Chuqu Wu.
	aliases = {"Jujiang"},
	Wikipedia = "zh:莒江话", -- no Wikidata item yet
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Lanxi Wu"] = {
	-- A subvariety of Jinlan Wu, which is a variety of Wuzhou Wu.
	aliases = {"Lanxi"},
	Wikidata = "Q17059873",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Lishui Wu"] = {
	-- A subvariety of Chuzhou Wu, which is a variety of Chuqu Wu.
	-- FIXME: Chuzhou Wu and Fujian Wu are not really aliases, but it's just more convenient ngl
	-- NOTE: Chuzhou was a historical administrative division that includes modern day Lishui & Wuyi,
	-- and is a proposed top-level division of Wu. Pucheng, Fujian is majority Wu-speaking.
	aliases = {"Lishui", "Lishuinese", "Fujian Wu"},
	Wikidata = "Q58294", -- article on the prefecture-level city of Lishui in Zhejiang
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Longqu Wu"] = {
	-- A variety of Chuqu Wu.
	aliases = {"Longqu"},
	Wikipedia = "zh:龙衢小片", -- no Wikidata item yet
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Longyou Wu"] = {
	-- A subvariety of Longqu Wu, which is a variety of Chuqu Wu.
	aliases = {"Longyou"},
	Wikidata = "Q15908274",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Nanji Wu"] = {
	-- A subvariety of Taigao Wu, which is a variety of Xuanzhou Wu.
	aliases = {"Nanji"},
	Wikidata = "Q10908223",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Nantai Wu"] = {
	-- A variety of Taizhouic Wu.
	aliases = {"Nantai"},
	-- Undefined in Chinese Wikipedia
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Old Xuanzhou Wu"] = {
	-- A subvariety of Tongjing Wu, which is a variety of Xuanzhou Wu.
	aliases = {"Old Xuanzhou"},
	Wikidata = "Q15914865",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Oujiang Wu"] = {
	-- A primary branch.
	aliases = {"Oujiang"},
	Wikidata = "Q710218", -- article for Wenzhounese
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Pan'an Wu"] = {
	-- A subvariety of Yiyong Wu, which is a variety of Wuzhou Wu.
	aliases = {"Yiwu"},
	Wikidata = "Q55695855",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Pucheng Ou Wu"] = {
	-- A variety of Oujiang Wu.
	aliases = {"Pucheng Ou"},
	Wikipedia = "zh:蒲城瓯语", -- no Wikidata item yet
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Pucheng Wu"] = {
	-- A subvariety of Chuzhou Wu, which is a variety of Chuqu Wu.
	aliases = {"Pucheng"},
	Wikipedia = "zh:浦城话", -- no Wikidata item yet
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Qingtian Wu"] = {
	-- A subvariety of Chuzhou Wu, which is a variety of Chuqu Wu.
	aliases = {"Qingtian"},
	Wikidata = "Q2074456",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Quzhou Wu"] = {
	-- A subvariety of Longqu Wu, which is a variety of Chuqu Wu.
	aliases = {"Quzhou", "Quzhounese", "Quzhounese Wu"},
	Wikidata = "Q6112429",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Rui'an Wu"] = {
	-- A variety of Oujiang Wu.
	aliases = {"Rui'an"},
	Wikidata = "Q4415352",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Shangrao Wu"] = {
	-- A variety of Chuqu Wu.
	aliases = {"Shangrao", "Shangraonese", "Shangraonese Wu"},
	Wikidata = "Q363479", -- Shangrao, a prefecture-level city in Jiangxi
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Shangshan Wu"] = {
	-- A variety of Chuqu Wu.
	aliases = {"Shangshan"},
	-- Undefined in Chinese Wikipedia
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Shiling Wu"] = {
	-- A variety of Xuanzhou Wu.
	aliases = {"Shiling"},
	Wikidata = "Q15923670",
	plain_categories = true,
}

labels["Southern Wu"] = {
	Wikipedia = "Wu Chinese#Southern Wu",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Taigao Wu"] = {
	-- A variety of Xuanzhou Wu.
	aliases = {"Taigao"},
	Wikipedia = "zh:宣州片#太高小片",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Taiping Wu"] = {
	-- A subvariety of Taigao Wu, which is a variety of Xuanzhou Wu.
	aliases = {"Taiping", "Old Taiping Wu", "Old Taiping"},
	Wikidata = "Q10941478",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Taizhou Wu"] = {
	-- A subvariety of Nantai Wu, which is a variety of Taizhouic Wu.
	aliases = {"Taizhou"},
	Wikidata = "Q3972406",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Taizhouic Wu"] = {
	-- A primary branch. Called "Taizhou Wu" in Wikipedia whereas our "Taizhou Wu" is "Taizhou dialect"; but these names
	-- are too ambiguous (cf. our "Beijingic Mandarin" vs. "Beijing Mandarin"). Per English Wikipedia, has the following
	-- varieties:
	  -- Taizhou dialect
	  -- Linhai dialect
	  -- Sanmen dialect
	  -- Tiantai dialect
	  -- Xianju dialect
	  -- Huangyan dialect
	  -- Jiaojiang dialect
	  -- Wenling dialect
	  -- Yuhuan dialect
	  -- Yueqing dialect
	  -- Ninghai dialect
	aliases = {"Taizhouic"},
	Wikidata = "Q7676678",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Tangxi Wu"] = {
	-- A variety of Wuzhou Wu.
	aliases = {"Tangxi"},
	Wikidata = "Q11136233",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Tiantai Wu"] = {
	-- A subvariety of Beitai Wu, which is a variety of Taizhouic Wu.
	aliases = {"Tiantai"},
	Wikidata = "Q85809509",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Tongjing Wu"] = {
	-- A variety of Xuanzhou Wu.
	aliases = {"Tongjing"},
	Wikidata = "Q17028746",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Tongling Wu"] = {
	-- A subvariety of Tongjing Wu, which is a variety of Xuanzhou Wu.
	aliases = {"Tongling"},
	Wikidata = "Q15909611",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Wencheng Wu"] = {
	-- A variety of Oujiang Wu.
	aliases = {"Wencheng"},
	Wikidata = "Q7982335",
	plain_categories = true,
}

labels["Wenzhounese Wu"] = {
	-- A variety of Oujiang Wu.
	aliases = {"Wenzhounese", "Wenzhou Wu", "Wenzhou", "Oujiang"},
	-- FIXME: Consider removing the following exception and letting it display as 'Wenzhounese Wu'.
	display = "Wenzhounese",
	Wikidata = "Q710218",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Wuhu County Wu"] = {
	-- A subvariety of Tongjing Wu, which is a variety of Xuanzhou Wu.
	aliases = {"Wuhu County"},
	Wikidata = "Q15911448",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Wuyi Wu"] = {
	-- A subvariety of Yiyong Wu, which is a variety of Wuzhou Wu.
	aliases = {"Yiwu"},
	Wikidata = "Q11124837",
	plain_categories = true,
}

labels["Wuzhou Wu"] = {
	-- A primary branch. Per English Wikipedia, has the following varieties:
	  -- Jinhua dialect
	  -- Lanxi dialect
	  -- Pujiang dialect
	  -- Yiwu dialect
	  -- Dongyang dialect
	  -- Pan'an dialect
	  -- Yongkang dialect
	  -- Wuyi dialect
	  -- Jiande dialect
	aliases = {"Wuzhou"},
	Wikidata = "Q2779891",
	plain_categories = true,
}

labels["Xuanzhou Wu"] = {
	-- A primary branch. Per English Wikipedia, has the following varieties:
	  -- Xuancheng
	  -- Tong–Jing
		  -- Tongling dialect
		  -- Jing County dialect
		  -- Fanchang dialect
		  -- etc.
	  -- Shi–Ling
		  -- Shitai dialect
		  -- Lingyang (陵阳) dialect
		  -- etc.
	  -- Tai–Gao
		  -- Taiping dialect
		  -- Gaochun dialect
		  -- etc.
	aliases = {"Xuanzhou"},
	Wikidata = "Q1939756",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Yiwu Wu"] = {
	-- A subvariety of Yiyong Wu, which is a variety of Wuzhou Wu.
	aliases = {"Yiwu"},
	Wikidata = "Q15898526",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Yiyong Wu"] = {
	-- A variety of Wuzhou Wu.
	aliases = {"Yiyong"},
	-- Undefined in Chinese Wikipedia
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Yongkang Wu"] = {
	-- A subvariety of Yiyong Wu, which is a variety of Wuzhou Wu.
	aliases = {"Yongkang"},
	Wikidata = "Q11132026",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Yushan Wu"] = {
	-- A subvariety of Shangshan Wu, which is a variety of Chuqu Wu.
	aliases = {"Yushan"},
	Wikidata = "Q17040715",
	plain_categories = true,
}

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
	Wikidata = "Q10943823",
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
	-- A variety of Yuehai Yue.
	Wikidata = "Q9186",
	regional_categories = true,
}

labels["dialectal Cantonese"] = {
	Wikipedia = "Cantonese",
	regional_categories = "Cantonese",
}

-- FIXME: Category missing.
labels["Bobai Yue"] = {
	-- A subvariety of Yulin Yue, a variety of Goulou Yue.
	aliases = {"Bobai"},
	Wikidata = "Q4934549",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Dapeng Cantonese"] = {
	-- A subvariety of Guanbao Cantonese, a variety of Yuehai Yue (the primary branch that includes standard Cantonese).
	aliases = {"Dapeng Yue", "Dapeng"},
	Wikidata = "Q1939845",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Dongguan Cantonese"] = {
	-- A subvariety of Guanbao Cantonese, which is a variety of Yuehai Yue (the primary branch that includes standard
	-- Cantonese).
	aliases = {"Dongguan Yue"},
	-- no alias for Dongguan, as Hakka is also spoken.
	Wikidata = "Q97351966",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Fangcheng Yue"] = {
	-- A variety of Qinlian Yue.
	aliases = {"Fangcheng"},
	Wikidata = "Q111949144",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Gaoyang Yue"] = {
	-- A primary branch.
	-- Per English Wikipedia, has the following lects:
	  -- Gaozhou dialect
	  -- Yangjiang dialect
	aliases = {"Gaoyang"},
	Wikidata = "Q2812583",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Goulou Yue"] = {
	-- A primary branch.
	-- Per English Wikipedia, has the following lects:
	  -- Yulin dialect
	    -- Bobai dialect
	  -- Guangning dialect
	  -- Huaiji dialect
	  -- Fengkai dialect
	  -- Deqing dialect
	  -- Yunan dialect
	  -- Shanglin dialect
	  -- Binyang dialect
	  -- Tengxian dialect
	aliases = {"Goulou"},
	Wikidata = "Q5588322",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Guanbao Cantonese"] = {
	-- A variety of Yuehai Yue (the primary branch including standard Cantonese).
	aliases = {"Guanbao Yue", "Guanbao"},
	Wikidata = "Q13530474",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Guangfu Cantonese"] = {
	-- A variety of Yuehai Yue (the primary branch including standard Cantonese). This variety includes standard
	-- Guangzhou Cantonese as a subvariety.
	aliases = {"Guangfu", "Guangfu Yue"},
	plain_categories = true,
}

-- FIXME: Category missing.
-- labels["Guangxi Yue"] = {
--  -- Multiple Yue subgroups spoken in Guangxi
-- 	-- Guangxi alias not correct as there are multiple languages spoken in Guangxi
-- 	Wikipedia = "Guangxi",
-- 	plain_categories = true,
-- }

labels["Guangzhou Cantonese"] = {
	-- A subvariety of Guangfu Cantonese, a variety of Yuehai Yue. The prestige variety of Cantonese.
	aliases = {"Guangzhou"},
	Wikidata = "Q9186", -- article for "Cantonese"
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Guixian Yue"] = {
	-- A variety of Goulou Yue.
	aliases = {"Guixian"},
	Wikidata = "Q15926547",
	plain_categories = true,
}

labels["Hong Kong Cantonese"] = {
	-- A subvariety of Cantonese (in the narrow sense), a variety of Yuehai Yue.
	aliases = {"HKC"},
	Wikidata = "Q5894342",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Huizhou Yue"] = {
	-- A variety of Wuhua Yue.
	-- No Huizhou alias because of Huizhou Cantonese (a different lect).
	Wikidata = "Q9484916",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Jiujiang Cantonese"] = {
	-- A subvariety of Sanyi Cantonese, which is a variety of Yuehai Yue (the primary branch that includes standard
	-- Cantonese).
	aliases = {"Jiujiang Yue", "Jiujiang"},
	Wikidata = "Q6203399",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Luoguang Yue"] = {
	-- A primary branch.
	-- Per English Wikipedia, has the following lects:
	  -- Luoding dialect
	  -- Zhaoqing dialect
	  -- Sihui dialect
	  -- Yangshan dialect
	  -- Lianzhou dialect
	  -- Lianshan dialect
	  -- Qingyuan dialect
	aliases = {"Luoguang"},
	Wikidata = "Q6704497",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Macau Cantonese"] = {
	-- A subvariety of Cantonese (in the narrow sense), a variety of Yuehai Yue.
	aliases = {"Macao Cantonese", "Macanese Cantonese"},
	Wikidata = "Q113659847",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Malaysian Cantonese"] = {
	-- A subvariety of Cantonese (in the narrow sense), a variety of Yuehai Yue.
	aliases = {"Malaysia Cantonese"},
	Wikidata = "Q56272241",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Nantou Cantonese"] = {
	-- A subvariety of Guanbao Cantonese, which is a variety of Yuehai Yue (the primary branch that includes standard
	-- Cantonese). Formerly spoken by residents of [[w:Nantou (historic town)]], a former walled city in Shenzhen.
	aliases = {"Nantou Yue"}, -- no "Nantou" alias because Nantou is also a city in Taiwan
	Wikidata = "Q110110348",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Qinlian Yue"] = {
	-- A primary branch.
	-- Per English Wikipedia, has the following lects:
	  -- Plain Speech
		  -- Beihai dialect
		  -- Qinzhou dialect
		  -- Fangcheng dialect
		  -- Lingshan downtown dialect
	  -- Transitional dialets
		  -- Naamhong dialect
		  -- Tanka dialect (not the same as Tanka Cantonese given above as a Yuehai Yue variety; per Wikipedia, Tanka
		  --   Cantonese is the "absolute Tanka accent" spoken by the elderly, while young and middle aged people speak
		  --   a Tanka dialect that is mixed with Beihai Plain Speech)
		  -- Overseas-Chinese Plain Speech
		  -- Saanhau dialect
	  -- Lianzhou dialect
	  -- Nga dialect
	  -- Coastal dialects (possibly a Min Chinese variety?)
	  -- Lingshan dialect
	  -- Xiaojiang dialect
	  -- Slanlap dialect
	aliases = {"Qinlian"},
	Wikidata = "Q7267753",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Sanyi Cantonese"] = {
	-- A variety of Yuehai Yue (the primary branch including standard Cantonese).
	aliases = {"Sanyi Yue", "Sanyi", "Nanpanshun Cantonese", "Nanpanshun Yue", "Nanpanshun"},
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Shiqi Cantonese"] = {
	-- A subvariety of Xiangshan Cantonese, which is a variety of Yuehai Yue (the primary branch that includes standard
	-- Cantonese).
	aliases = {"Shiqi Yue", "Shiqi"},
	Wikidata = "Q836038",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Singapore Cantonese"] = {
	-- A subvariety of Cantonese (in the narrow sense), a variety of Yuehai Yue.
	aliases = {"Singaporean Cantonese"},
	Wikipedia = "Chinese Singaporeans#Cantonese",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Siyi Yue"] = {
	-- A primary branch.
	-- Per English Wikipedia, has the following lects:
	  -- Taishanese
	  -- Xinhui dialect
	  -- Siqian dialect
	  -- Guzhen dialect
	  -- Enping dialect
	  -- Kaiping dialect
	aliases = {"Siyi"},
	Wikidata = "Q2391679",
	plain_categories = true,
}

-- The following violates normal conventions, which would use "Taishan Yue" or "Taishanese Yue". But it matches the
-- current 'Taishanese' full language. If (as proposed by [[User:Wpi]]) we demote Taishanese to an etym-only variety
-- of Siyi Yue, we should consider renaming to Taishan Yue or Taishanese Yue.
labels["Taishanese"] = {
	-- A variety of Siyi Yue.
	aliases = {"Toishanese", "Toisanese", "Hoisanese"},
	Wikidata = "Q2208940",
	regional_categories = true,
}

-- FIXME: Category missing.
labels["Tanka Cantonese"] = {
	-- A subvariety of Guangfu Cantonese, a variety of Yuehai Yue (the primary branch that includes standard Cantonese).
	-- Spoken by the [[w:Tanka people]], an ethnic group traditionally living on junks in coastal parts of southern
	-- China.
	aliases = {"Tanka Yue", "Tanka", "Danjia Cantonese", "Danjia Yue", "Danjia", "Shuishang Cantonese", "Shuishang Yue",
		"Shuishang"},
	Wikidata = "Q7211307",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Weitou Cantonese"] = {
	-- A subvariety of Guanbao Cantonese, which is a variety of Yuehai Yue (the primary branch that includes standard
	-- Cantonese). Spoken by older residents of Shenzhen.
	aliases = {"Weitou Yue", "Weitou", "Bao'an Cantonese", "Bao'an Yue", "Bao'an"},
	Wikidata = "Q846599",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Wuhua Yue"] = {
	-- A primary branch.
	-- Per English Wikipedia, has the following lects:
	  -- Wuchuan dialect
	  -- Huazhou dialect
	aliases = {"Wuhua"},
	Wikidata = "Q8038858",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Xiangshan Cantonese"] = {
	-- A variety of Yuehai Yue (the primary branch including standard Cantonese).
	aliases = {"Xiangshan Yue", "Xiangshan"},
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Xiguan Cantonese"] = {
	-- A subvariety of Guangfu Cantonese (the variety of Yuehai Yue that includes standard Cantonese).
	aliases = {"Xiguan Yue", "Xiguan"},
	Wikidata = "Q8044409",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Xinhui Yue"] = {
	-- A variety of Siyi Yue.
	aliases = {"Xinhui"},
	Wikidata = "Q97168096",
	plain_categories = true,
}

labels["Yangjiang Yue"] = {
	-- A variety of Gaoyang Yue.
	-- no alias for Yangjiang as Yangjiang Hakka also exists.
	Wikidata = "Q65406156",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Yongxun Yue"] = {
	-- A primary branch.
	-- Per English Wikipedia, has the following lects:
	  -- Nanning dialect
	  -- Yongning dialect
	  -- Guiping dialect
	  -- Chongzuo dialect
	  -- Ningmin dialect
	  -- Hengxian dialect
	  -- Baise dialect
	aliases = {"Yongxun"},
	Wikidata = "Q8054950",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Yuehai Yue"] = {
	-- A primary branch, which includes standard Cantonese. Per English Wikipedia, has the following lects:
	  -- Guangfu dialects
		  -- Guangzhou dialect
		  -- Hong Kong dialect
		  -- Macau dialect
		  -- Xiguan dialect
		  -- Wuzhou dialect
		  -- Tanka dialect
	  -- Sanyi / Nanpanshun dialects
		  -- Nanhai dialect
		  -- Jiujiang dialect
		  -- Xiqiao dialect
		  -- Shunde dialect
	  -- Xiangshan dialect
		  -- Shiqi dialect
		  -- Sanjiao dialect
	  -- Guanbao dialect
		  -- Dongguan dialect
		  -- Bao'an dialect (Waitau)
	aliases = {"Yuehai"},
	Wikidata = "Q8060260",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Yulin Yue"] = {
	-- A variety of Goulou Yue.
	aliases = {"Yulin"},
	Wikidata = "zh:Q15942798", -- [[w:Yulin dialect]] also exists but redirects to [[w:Goulou Yue]].
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
