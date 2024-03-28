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
	Wikidata = "Q6794539", -- link for Fuguang Gan
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
	Wikidata = "Q6794539", -- link for Fuguang Gan
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
	Wikidata = "Q19855566",
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
	Wikidata = "Q16873881",
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
	Wikidata = "Q16873881", -- link for Huiyang Hakka
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
	Wikidata = "Q6703311",
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
	Wikipedia = "Beijing dialect",
	plain_categories = true,
}

labels["Central Plains Mandarin"] = {
	-- A primary branch.
	-- Dialects per Wikipedia: [[w:Dungan language]], [[w:Gangou dialect]], Kaifeng dialect (开封话),
	-- [[w:Luoyang dialect]], Nanyang dialect (南阳话), Qufu dialect (曲埠话), Tianshui dialect (天水话),
	-- [[w:Xi'an dialect]], [[w:Xuzhou dialect]], Yan'an dialect (延安话), Zhengzhou dialect (郑州话).
	aliases = {"Central Plains", "Zhongyuan Mandarin"},
	Wikipedia = true,
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
labels["Gangou Mandarin"] = {
	-- A variety of Central Plains Mandarin.
	aliases = {"Gangou"},
	Wikidata = "Q17050290",
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
	Wikipedia = "Lower Yangtze Mandarin",
	plain_categories = true,
}

labels["Jiaoliao Mandarin"] = {
	-- A primary branch.
	-- Dialects per Wikipedia: [[w:Dalian dialect]], [[w:Qingdao dialect]], [[w:Weihai dialect]], Yantai dialect
	-- (烟台话).
	aliases = {"Jiaoliao", "Jiao-Liao", "Jiao-Liao Mandarin"},
	Wikipedia = true,
	plain_categories = true,
}

labels["Jilu Mandarin"] = {
	-- A primary branch.
	-- Dialects per Wikipedia: Baoding dialect (保定话), [[w:Jinan dialect]], Shijiazhuang dialect (石家庄话),
	-- [[w:Tianjin dialect]].
	aliases = {"Jilu", "Ji-Lu", "Ji-Lu Mandarin"},
	Wikipedia = true,
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
	Wikipedia = true,
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
	Wikidata = "Q10909110",
	plain_categories = true,
}

labels["Northeastern Mandarin"] = {
	-- A primary branch.
	-- Dialects per Wikipedia: [[w:Changchun dialect]], [[w:Harbin dialect]], Qiqihar dialect (齐齐哈尔话),
	-- [[w:Shenyang dialect]].
	aliases = {"northeastern Mandarin", "NE Mandarin"},
	Wikipedia = true,
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
	Wikipedia = "Mandarin Chinese in the Philippines",
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
	Wikipedia = "Singaporean Mandarin",
	plain_categories = true,
}

labels["Southwestern Mandarin"] = {
	-- A primary branch.
	-- Dialects per Wikipedia: Changde dialect (常德话), [[w:Chengdu dialect]], [[w:Chongqing dialect]], Dali dialect
	-- (大理话), Guiyang dialect (贵阳话), [[w:Kunming dialect]], Liuzhou dialect (柳州话), [[w:Wuhan dialect]],
	-- [[w:Xichang dialect]], Yichang dialect (宜昌话), Hanzhong dialect (汉中话).
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
	Wikipedia = "Wuhan dialect",
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
	Wikipedia = "Lanyin Mandarin", -- "Yinchuan Mandarin" has its own Wikidata item Q125021069 but has no links
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

-- FIXME: Category missing.
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

-- FIXME: Category missing.
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

labels["Datian Min"] = {
	aliases = {"Datian"},
	Wikipedia = true,
	regional_categories = true,
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
	-- A primary branch; should possibly be called Northern Eastern Min?
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
	-- A primary branch; should possibly be called Southern Eastern Min?
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
	Wikidata = "Q15937822",
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
	Wikipedia = "Wu Chinese",
	regional_categories = true,
}

labels["dialectal Wu"] = {
	Wikipedia = "Wu Chinese",
	regional_categories = "Wu",
}

-- labels["Zhejiang Wu"] = {
-- 	-- several dialects of different subgroups
-- 	aliases = {"Zhejiang"},
-- 	Wikipedia = "Zhejiang",
-- 	plain_categories = true,
-- }

---------------------- Northern Wu ----------------------

labels["Changzhounese Wu"] = {
	aliases = {"Changzhou Wu", "Changzhou", "Changzhounese"},
	Wikipedia = "Changzhou dialect",
	plain_categories = true,
}

labels["Danyang Wu"] = {
	-- A variety of Northern Wu.
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
	Wikidata = "Q15901269",
	plain_categories = true,
}

labels["Linshao Wu"] = {
	-- The supervariety of Shaoxing Wu; a variety of Northern Wu.
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
	Wikidata = "Q6112340",
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

---------------------- Southern Wu ----------------------

labels["Wuzhou Wu"] = {
	aliases = {"Wuzhou"},
	Wikidata = "Q2779891",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Chuqu Wu"] = {
	aliases = {"Chuqu"},
	Wikidata = "Q5116499",
	plain_categories = true,
}

labels["Lishui Wu"] = {
	-- A variety of Chuqu Wu.
	-- FIXME: Are Chuzhou Wu and Fujian Wu really aliases, or different dialects lumped into Lishui Wu?
	-- (NOTE: Chuzhou was an ancient state established during the Sui Dynasty (589 AD), covering the city of Lishui
	-- and [[w:Wuyi County, Zhejiang]]; see [[w:zh:处州]]. Lishui is in the southwestern corner of Zhejiang and borders
	-- Fujian to the southwest, so it's possible there is a bit of Fujian that is Wu-speaking.)
	aliases = {"Lishui", "Lishuinese", "Chuzhou Wu", "Chuzhou", "Fujian Wu"},
	Wikipedia = "Lishui",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Jiangshan Wu"] = {
	-- A variety of Chuqu Wu.
	aliases = {"Jiangshan"},
	Wikidata = "Q6112693",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Jinhua Wu"] = {
	-- A variety of Wuzhou Wu.
	aliases = {"Jinhua", "Jinhuanese", "Jinhuanese Wu"},
	Wikidata = "Q13583347",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Qingtian Wu"] = {
	-- A variety of Chuqu Wu.
	aliases = {"Qingtian"},
	Wikidata = "Q2074456",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Quzhou Wu"] = {
	-- A variety of Chuqu Wu.
	aliases = {"Quzhou", "Quzhounese", "Quzhounese Wu"},
	Wikidata = "Q6112429",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Shangrao Wu"] = {
	-- A variety of Chuqu Wu.
	aliases = {"Shangrao", "Shangraonese", "Shangraonese Wu"},
	Wikipedia = "Shangrao",
	plain_categories = true,
}

labels["Southern Wu"] = {
	Wikipedia = "Wu Chinese",
	plain_categories = true,
}

labels["Wenzhounese Wu"] = {
	aliases = {"Wenzhounese", "Wenzhou Wu", "Wenzhou", "Oujiang"},
	-- FIXME: Consider removing the following exception and letting it display as 'Wenzhounese Wu'.
	display = "Wenzhounese",
	Wikipedia = "Wenzhou dialect",
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
	Wikipedia = true,
	regional_categories = true,
}

labels["dialectal Cantonese"] = {
	Wikipedia = "Cantonese",
	regional_categories = "Cantonese",
}

-- FIXME: Category missing.
labels["Dongguan Cantonese"] = {
	-- A subvariety of Guanbao Cantonese, in turn a variety of Yuehai Yue ("Cantonese").
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
	-- A variety of Siyi Yue.
	aliases = {"Toishanese", "Hoisanese"},
	Wikipedia = true,
	regional_categories = true,
}

-- FIXME: Category missing.
labels["Yangjiang Cantonese"] = {
	-- A variety of Gaoyang Yue.
	aliases = {"Yangjiang", "Yangjiang Yue"},
	Wikidata = "Q65406156",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Yulin Cantonese"] = {
	-- A variety of Goulou Yue.
	aliases = {"Yulin", "Yulin Yue"},
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
