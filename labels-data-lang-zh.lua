local labels = {}

-- NOTE: The labels below are grouped by "lect group" (e.g. Mandarin, Wu, Yue) and then alphabetized within each
-- lect group. Hokkien is under "Min". If you don't find a given lect group, look under the "Other groups" below;
-- also keep in mind the "Miscellaneous" at the bottom for labels that don't refer to a topolect.

------------------------------------------ Gan ------------------------------------------

labels["Gan"] = {
	Wikidata = "Q33475",
	regional_categories = true,
	parent = true,
}

labels["dialectal Gan"] = {
	Wikidata = "Q33475", -- article for Gan Chinese
	regional_categories = "Gan",
}

-- FIXME: Category missing.
labels["Changdu Gan"] = {
	-- A primary branch. Principal dialect: Nanchang.
	region = "northwestern [[Jiangxi]] Province and northeastern [[Hunan]] Province, in south-central [[China]]",
	addl = "A primary branch of Gan.",
	aliases = {"Changdu"},
	Wikidata = {"Q3497239", "Q6789768"}, -- the first ID is for English, the second for Chinese; they need to be merged
	plain_categories = true,
	parent = true,
}

-- FIXME: Category missing.
labels["Datong Gan"] = {
	-- A primary branch. Principal dialect: Daye.
	region = "southeastern [[Hubei]] Province and eastern [[Hunan]] Province, in south-central [[China]]",
	addl = "A primary branch of Gan.",
	aliases = {"Datong"},
	Wikidata = {"Q5207168", "Q6830838"}, -- the first ID is for English, the second for Chinese; they need to be merged
	plain_categories = true,
	parent = true,
}

-- FIXME: Category missing.
labels["Dongsui Gan"] = {
	-- A primary branch. Principal dialect: Dongkou.
	region = "southwestern [[Hunan]] Province, in south-central [[China]]",
	addl = "A primary branch of Gan.",
	aliases = {"Dongsui"},
	Wikidata = "Q6762652",
	plain_categories = true,
	parent = true,
}

-- FIXME: Category missing.
labels["Fuguang Gan"] = {
	-- A primary branch. Principal dialect: Fuzhou (撫州) in Jiangsi.
	region = "central and eastern [[Jiangxi]] Province and southwestern [[Fujian]] Province, in south-central [[China]]",
	addl = "A primary branch of Gan.",
	aliases = {"Fuguang"},
	Wikidata = "Q6794539",
	plain_categories = true,
	parent = true,
}

-- FIXME: Category missing.
labels["Huaiyue Gan"] = {
	-- A primary branch. Principal dialect: Huaining.
	region = "southwestern [[Anhui]] Province, in south-central [[China]]",
	addl = "A primary branch of Gan.",
	aliases = {"Huaiyue"},
	Wikidata = "Q6797985",
	plain_categories = true,
	parent = true,
}

-- FIXME: Category missing.
labels["Jicha Gan"] = {
	-- A primary branch. Principal dialect: Ji'an.
	region = "central and southern [[Jiangxi]] Province and eastern [[Hunan]] Province, in south-central [[China]]",
	addl = "A primary branch of Gan.",
	aliases = {"Jicha"},
	Wikidata = "Q6844561",
	plain_categories = true,
	parent = true,
}

-- FIXME: Category missing.
labels["Leizi Gan"] = {
	-- A primary branch. Principal dialect: Leiyang.
	region = "eastern [[Hunan]] Province, in south-central [[China]]",
	addl = "A primary branch of Gan.",
	aliases = {"Leizi"},
	Wikidata = "Q7212943",
	plain_categories = true,
	parent = true,
}

labels["Lichuan Gan"] = {
	region = "[[Lichuan]] County, under the jurisdiction of the [[prefecture-level city]] of [[Fuzhou]] ({{m|cmn|撫州}}) in northeastern [[Jiangxi]] Province (not to be confused with the Fuzhou city in [[Fujian]] Province)",
	aliases = {"Lichuan"}, -- FIXME: Correct?
	Wikidata = "Q6794539", -- article for Fuguang Gan
	plain_categories = true,
	parent = "Fuguang Gan",
}

labels["Nanchang Gan"] = {
	-- This is thA variety of Changdu Gan (where it is the principal dialect).
	region = "[[Nanchang]], capital of [[Jiangxi]] Province in south-central [[China]]",
	aliases = {"Nanchang"}, -- FIXME: Correct?
	Wikidata = "Q3497239", -- article for Changdu Gan in English, Nanchang Gan in Chinese
	plain_categories = true,
	parent = "Changdu Gan",
}

labels["Pingxiang Gan"] = {
	region = "[[Pingxiang]], a [[prefecture-level city]] in [[Jiangxi]] Province in south-central [[China]]",
	aliases = {"Pingxiang"}, -- FIXME: Correct?
	Wikidata = "Q8053438", -- article for Yiliu Gan
	plain_categories = true,
	parent = "Yiliu Gan",
}

labels["Taining Gan"] = {
	region = "{{w|Taining County}}, under the jurisdiction of the [[prefecture-level city]] of [[Sanming]] in northwastern [[Fujian]] Province in southeast [[China]]",
	aliases = {"Taining"}, -- FIXME: Correct?
	Wikidata = "Q6794539", -- article for Fuguang Gan
	plain_categories = true,
	parent = "Fuguang Gan",
}

-- FIXME: Category missing.
labels["Yiliu Gan"] = {
	-- A primary branch. Principal dialect: Yichun.
	region = "central and western [[Jiangxi]] Province and eastern [[Hunan]] Province, in south-central [[China]]",
	addl = "A primary branch of Gan.",
	aliases = {"Yiliu"},
	Wikidata = {"Q8053438", "Q6820035"}, -- the first ID is for English, the second for Chinese; they need to be merged
	plain_categories = true,
	parent = true,
}

-- FIXME: Category missing.
labels["Yingyi Gan"] = {
	-- A primary branch. Principal dialect: Yingtan.
	region = "northeastern [[Jiangxi]] Province, in south-central [[China]]",
	addl = "A primary branch of Gan.",
	aliases = {"Yingyi"},
	Wikidata = {"Q3443012", "Q6654505"}, -- the first ID is for English, the second for Chinese; they need to be merged
	plain_categories = true,
	parent = true,
}

------------------------------------------ Hakka ------------------------------------------

labels["Hakka"] = {
	def = "the {{w|Hakka Chinese}} branch of {{w|Sinitic languages|Sinitic}}",
	Wikidata = "Q33375",
	regional_categories = true,
	parent = true,
}

labels["dialectal Hakka"] = {
	Wikidata = "Q33375", -- article for Hakka Chinese
	regional_categories = "Hakka",
}

labels["Dabu Hakka"] = {
	region = "{{w|Dabu County}} in eastern [[Guangdong]] Province in southern [[China]], and in [[Taiwan]]",
	aliases = {"Dabu"},
	Wikidata = "Q19855566",
	plain_categories = true,
	parent = true,
	othercat = "Taiwanese Hakka",
}

-- FIXME: Category missing.
labels["Early Modern Hakka"] = {
	noreg = true,
	nolink = true,
	extinct = true,
	region = "the 19th century, especially in Bible translations",
	Wikidata = "Q33375", -- article for Hakka Chinese
	plain_categories = true,
	parent = true,
}

labels["Hailu Hakka"] = {
	region = "[[Shanwei]] in [[Guangdong]] Province in southern [[China]], as well as in [[Taiwan]] and [[West Kalimantan]], [[Indonesia]]",
	aliases = {"Hailu"},
	Wikidata = "Q19855025", -- see also Q17038519 "Hailu Hakka" in Wikidata, which duplicates Q19855025 and redirects to it in Chinese Wikipedia
	plain_categories = true,
	parent = true,
	othercat = "Taiwanese Hakka,Overseas Hakka",
}

labels["Hong Kong Hakka"] = {
	region = "Hong Kong",
	Wikidata = "Q2675834",
	plain_categories = true,
	parent = "non-Mainland Hakka",
	othercat = "Hong Kong Chinese",
}

labels["Huiyang Hakka"] = {
	region = "[[Huizhou]], [[Dongguan]] and [[Shenzhen]], in east-central [[Guangdong]] Province in southern [[China]], with Danshui Subdistrict ({{m|cmn|淡水街道}}) in {{w|Huiyang District}}, [[Huizhou]] as its representative dialect",
	aliases = {"Huiyang"},
	Wikidata = "Q16873881",
	plain_categories = true,
	parent = true,
}

-- FIXME: Category missing.
--labels["Jiangxi Hakka"] = {
--	-- Multiple dialects; possibly referring to Tonggu County dialect.
--	plain_categories = true,
--}

-- FIXME: Category missing.
labels["Malaysian Huiyang Hakka"] = {
	region = "[[Malaysia]], originating in {{w|Huiyang District}}, [[Huizhou]] in east-central [[Guangdong]] Province in southern [[China]]",
	aliases = {"Malaysia Huiyang Hakka"},
	Wikidata = "Q16873881", -- article for Huiyang Hakka
	plain_categories = true,
	parent = "Southeast Asian Hakka",
	othercat = "Huiyang Hakka",
}

labels["Meixian Hakka"] = {
	region = "[[Meixian]] District (similar to a county and surrounding the urban core of [[Meizhou]]), located in northeastern [[Guangdong]] Province; additionally, in numerous overseas countries",
	addl = "Meixian Hakka is the prestige dialect of Hakka.",
	aliases = {"Meixian", "Moiyan", "Moiyan Hakka", "Meizhou", "Meizhou Hakka"},
	Wikidata = "Q839295",
	plain_categories = true,
	parent = true,
	othercat = "Overseas Hakka",
}

labels["non-Mainland Hakka"] = {
	prep = "by",
	region = "ethnic Chinese outside of [[mainland China]], including in [[Hong Kong]] and [[Macau]] due to their special history",
	display = "non-[[w:Mainland China|Mainland]] [[w:Hakka Chinese|Hakka]]",
	aliases = {"Non-Mainland Hakka", "non-mainland Hakka"},
	plain_categories = true,
	parent = true,
	othercat = "non-Mainland Chinese",
}

labels["Northern Sixian Hakka"] = {
	region = "[[Taoyuan]] and [[Miaoli]] in the north of [[Taiwan]]",
	aliases = {"Northern Sixian"},
	Wikidata = "Q9668261", -- article for Sixian Hakka
	plain_categories = true,
	parent = "Sixian Hakka",
}

labels["Overseas Hakka"] = {
	prep = "outside of",
	region = "[[mainland China]], [[Taiwan]], [[Hong Kong]] and [[Macau]]",
	Wikipedia = "Hakka people#Hakkas elsewhere",
	plain_categories = true,
	parent = "non-Mainland Hakka",
	othercat = "Overseas Chinese",
}

labels["Raoping Hakka"] = {
	region = "{{w|Raoping County}} in [[Guangdong]] as well as [[Taoyuan]], [[Hsinchu]], [[Miaoli]] and [[Taichung]] in [[Taiwan]]",
	-- No Raoping alias because Chaoshan Min is also spoken.
	Wikidata = "Q19854038",
	plain_categories = true,
	parent = true,
	othercat = "Taiwanese Hakka",
}

labels["Sixian Hakka"] = {
	region = "several parts of [[Taiwan]], especially [[Taoyuan]] and [[Miaoli]] in the north, as well as the [[Liudui]] Region in [[Kaohsiung]] and [[Pingtung]] in the south",
	aliases = {"Sixian"},
	Wikidata = "Q9668261",
	plain_categories = true,
	parent = "Taiwanese Hakka",
}

labels["Southeast Asian Hakka"] = {
	region = "[[Southeast Asia]], stretching from [[Myanmar]] ([[Burma]]) in the northwest, to the [[Philippines]] in the northeast, to [[Indonesia]] in the south",
	Wikipedia = {"Hakka people#Hakkas elsewhere", "Southeast Asia"},
	plain_categories = true,
	parent = "Overseas Hakka",
	othercat = "Southeast Asian Chinese",
}

labels["Southern Sixian Hakka"] = {
	region = "the [[Liudui]] Region in [[Kaohsiung]] and [[Pingtung]] in the south of [[Taiwan]]",
	aliases = {"Southern Sixian"},
	Wikidata = {"Q98095139", "Q9668261"}, -- second is article for Sixian Hakka; Q98095139 is "Southern Sixian dialect" but has no articles linked
	parent = "Sixian Hakka",
}

labels["Shangyou Hakka"] = {
	region = "{{w|Shangyou County}} in southwestern [[Jiangxi]] Province, in southeast [[China]]",
	aliases = {"Shangyou"},
	Wikidata = "Q1282613", -- article for Shangyou County
	plain_categories = true,
	parent = true,
}

labels["Taiwanese Hakka"] = {
	region = "Taiwan",
	aliases = {"Taiwan Hakka"},
	Wikidata = "Q2391532",
	plain_categories = true,
	parent = "non-Mainland Hakka",
	othercat = "Taiwanese Chinese",
}

-- Skipped: Wuluo Hakka; appears to originate in Pingtung County, Taiwan and be part of Southern Sixian Hakka, maybe
-- related to the Wuluo River, but extremely obscure; can't find anything about the dialect in Google.

labels["Yudu Hakka"] = {
	region = "{{w|Yudu County}} in southern [[Jiangxi]] Province, in southeast [[China]]",
	aliases = {"Yudu"},
	Wikidata = "Q1816748", -- article for Yudu County
	plain_categories = true,
	parent = true,
}

labels["Yunlin Hakka"] = {
	region = "[[Yunlin]] County in western [[Taiwan]]",
	parent = "Taiwanese Hakka",
	aliases = {"Yunlin"},
	Wikidata = "Q153221", -- article for Yunlin County
	plain_categories = true,
	parent = "Taiwanese Hakka",
}

labels["Zhao'an Hakka"] = {
	verb = "spoken originally",
	region = "{{w|Zhao'an County}} in the [[prefecture-level city]] of [[Zhangzhou]] in southernmost [[Fujian]] Province in southeast [[China]]; now also in [[Yunlin]] County and the city of [[Taoyuan]], in [[Taiwan]]",
	Wikidata = "Q6703311",
	plain_categories = true,
	parent = true,
	othercat = "Taiwanese Hakka",
}

------------------------------------------ Jin ------------------------------------------

labels["Jin"] = {
	Wikidata = "Q56479",
	regional_categories = true,
	parent = true,
}

labels["dialectal Jin"] = {
	Wikidata = "Q56479", -- article for Jin Chinese
	regional_categories = "Jin",
}

labels["Xinzhou Jin"] = {
	-- no "Xinzhou" alias; Xinzhou Wu (different Xinzhou) also exists
	Wikidata = "Q73119", -- article for Xinzhou (city in Shanxi)
	plain_categories = true,
	parent = true, -- actually in the Wutai subgroup; FIXME: add parent label
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
	parent = true,
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
	region = "areas surrounding [[Beijing]] in northeastern [[China]], including [[Beijing]] as well as parts of [[Hebei]] Province, [[Inner Mongolia]] Autonomous Region, [[Liaoning]] Province and [[Tianjin]] Municipality",
	addl = "A primary branch of Mandarin.",
	aliases = {"Beijingic"},
	Wikidata = "Q2169652",
	plain_categories = true,
	parent = true,
}

labels["Beijing Mandarin"] = {
	region = "urban [[Beijing]]",
	aliases = {"Beijing", "Peking", "Pekingese"},
	Wikidata = "Q1147606",
	plain_categories = true,
	parent = "Beijingic Mandarin",
}

labels["Central Plains Mandarin"] = {
	-- A primary branch.
	-- Dialects per Wikipedia: [[w:Dungan language]], [[w:Gangou dialect]], Kaifeng dialect (开封话),
	-- [[w:Luoyang dialect]], Nanyang dialect (南阳话), Qufu dialect (曲埠话), Tianshui dialect (天水话),
	-- [[w:Xi'an dialect]], [[w:Xuzhou dialect]], Yan'an dialect (延安话), Zhengzhou dialect (郑州话).
	region = "central [[China]], specifically in [[Henan]] Province, the central parts of [[Shaanxi]] Province in the [[Yellow River]] valley and eastern [[Gansu]] Province, as well as in southern [[Xinjiang]] Autonomous Region in far western [[China]], due to recent migration",
	addl = "A primary branch of Mandarin.",
	aliases = {"Central Plains", "Zhongyuan Mandarin"},
	Wikidata = "Q3048775",
	plain_categories = true,
	parent = true,
}

-- FIXME: Category missing.
labels["Changchun Mandarin"] = {
	region = "[[Changchun]], the capital of [[Jilin]] Province in northeastern [[China]]",
	aliases = {"Changchun"},
	Wikidata = "Q17030513",
	plain_categories = true,
	parent = "Northeastern Mandarin",
}

-- FIXME: Category missing.
labels["Dalian Mandarin"] = {
	prep = "on",
	region = "the [[Liaodong]] Peninsula in coastal eastern [[China]] in the city of [[Dalian]], as well as in parts of [[Dandong]] and {{w|Yikou}}",
	aliases = {"Dalian"},
	Wikidata = "Q1375036",
	plain_categories = true,
	parent = "Jiaoliao Mandarin",
}

-- FIXME: Category missing.
labels["Fenhe Mandarin"] = {
	region = "[[Linfen]] and [[Yuncheng]] in the lower reaches of the {{w|Fen River}} in [[Shanxi]] Province, as well as in [[Hancheng]] in [[Shaanxi]] Province",
	aliases = {"Fenhe"},
	Wikidata = "Q10379509",
	plain_categories = true,
	parent = "Central Plains Mandarin",
}

-- FIXME: Category missing.
labels["Gangou Mandarin"] = {
	region = "{{w|Minhe Hui and Tu Autonomous County}} in far eastern [[Qinghai]] Province; strongly influenced by the {{catlink|Monguor languages}} (Mongolic) and [[Amdo Tibetan]]",
	aliases = {"Gangou"},
	Wikidata = "Q17050290",
	plain_categories = true,
	parent = "Central Plains Mandarin",
}

labels["Guangxi Mandarin"] = {
	-- No Guangxi alias; seems unlikely to be correct
	Wikidata = "Q2609239", -- article for Southwestern Mandarin
	plain_categories = true,
	parent = "Southwestern Mandarin",
}

labels["Guanzhong Mandarin"] = {
	region = "the {{w|Guanzhong}} region of central [[Shaanxi]] Province, including the capital city [[Xi'an]]",
	aliases = {"Guanzhong"},
	Wikidata = "Q3431648",
	plain_categories = true,
	parent = "Central Plains Mandarin",
}

labels["Guilin Mandarin"] = {
	-- No Guilin alias; also Guilin Pinghua, Guilin Southern Min
	region = "[[Guilin]] in [[Guangxi]] Autonomous Region in southern [[China]]",
	Wikidata = "Q11111636",
	plain_categories = true,
	parent = "Guiliu Mandarin", -- a variety of Southwestern Mandarin
}

labels["Guiliu Mandarin"] = {
	region = "northern [[Guangxi]] Autonomous Region in southern [[China]], especially in the cities of [[Guilin]] and [[Liuzhou]]",
	Wikidata = "Q11111664",
	plain_categories = true,
	parent = "Southwestern Mandarin",
}

labels["Guiyang Mandarin"] = {
	region = "[[Guiyang]], the capital of [[Guizhou]] Province in southwestern [[China]]",
	aliases = {"Guiyang"},
	Wikidata = "Q15911623",
	plain_categories = true,
	parent = "Southwestern Mandarin",
}

labels["Harbin Mandarin"] = {
	region = "[[Harbin]], the capital of [[Heilongjiang]] Province in northeastern [[China]]",
	aliases = {"Harbin"},
	Wikidata = "Q1006919",
	plain_categories = true,
	parent = "Northeastern Mandarin",
}

-- FIXME: Category missing.
labels["Hefei Mandarin"] = {
	region = "[[Hefei]], the capital of [[Anhui]] Province in central [[China]]",
	aliases = {"Hefei"},
	Wikidata = "Q10916956",
	plain_categories = true,
	parent = "Jianghuai Mandarin",
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
	region = "parts of [[Jiangsu]] and [[Anhui]] Provinces on the north bank of the [[Yangtze]] in east-central [[China]], as well as some areas on the south bank, such as [[Nanjing]] in [[Jiangsu]] Province and [[Jiujiang]] in [[Jiangxi]] Province",
	addl = "A primary branch of Mandarin.",
	aliases = {"Jianghuai", "Jiang-Huai", "Jiang-Huai Mandarin", "Lower Yangtze Mandarin", "Huai"},
	Wikidata = "Q2128953",
	plain_categories = true,
	parent = true,
}

labels["Jiaoliao Mandarin"] = {
	-- A primary branch.
	-- Dialects per Wikipedia: [[w:Dalian dialect]], Dandong dialect, [[w:Qingdao dialect]], Rizhao dialect,
	-- Weifang dialect, [[w:Weihai dialect]], Yantai dialect (烟台话).
	region = "coastal eastern [[China]], specifically: on the {{w|Jiaodong Peninsula}} (from [[Yantai]] to [[Qingdao]]); in {{w|Ganyu District}} in northeastern [[Jiangsu]] Province; on the [[Liaodong]] Peninsula (from [[Dalian]] to [[Dandong]]); and in parts of [[Heilongjiang]] Province, due to migration",
	addl = "A primary branch of Mandarin.",
	aliases = {"Jiaoliao", "Jiao-Liao", "Jiao-Liao Mandarin"},
	Wikidata = "Q2597550",
	plain_categories = true,
	parent = true,
}

labels["Jilu Mandarin"] = {
	-- A primary branch.
	-- Dialects per Wikipedia: Baoding dialect (保定话), [[w:Jinan dialect]], Shijiazhuang dialect (石家庄话),
	-- [[w:Tianjin dialect]].
	region = "coastal eastern [[China]], specifically: [[Hebei]] Province; the western part of [[Shandong]] Province; and parts of [[Heilongjiang]], due to migration",
	addl = "A primary branch of Mandarin.",
	aliases = {"Jilu", "Ji-Lu", "Ji-Lu Mandarin"},
	Wikidata = "Q516721",
	plain_categories = true,
	parent = true,
}

-- FIXME: Category missing.
labels["Jinan Mandarin"] = {
	region = "[[Jinan]], the capital of [[Shandong]] Province in eastern [[China]]",
	aliases = {"Jinan"},
	Wikidata = "Q6202017",
	plain_categories = true,
	parent = "Jilu Mandarin",
}

-- FIXME: Category missing.
labels["Kunming Mandarin"] = {
	region = "[[Kunming]], the capital of [[Yunnan]] Province in southwestern [[China]]",
	aliases = {"Kunming"},
	Wikidata = "Q3372400",
	plain_categories = true,
	parent = "Southwestern Mandarin",
}

labels["Lanyin Mandarin"] = {
	-- A primary branch.
	-- Dialects per Wikipedia: Lanzhou dialect (兰州话), Xining dialect (西宁话), Yinchuan dialect (银川话).
	region = "[[Lanzhou]] and elsewhere in [[Gansu]] Province; [[Yinchuan]] and generally in the northern part of [[Ningxia]] Autonomous Region; and more recently in northern [[Xinjiang]] Autonomous Region",
	addl = "A primary branch of Mandarin.",
	aliases = {"Lanyin", "Lan-Yin Mandarin"},
	Wikidata = "Q662754",
	plain_categories = true,
	parent = true,
}

labels["Lanzhou Mandarin"] = {
	region = "[[Lanzhou]], the capital of [[Gansu]] Province in central [[China]]",
	aliases = {"Lanzhou"},
	Wikidata = "Q10893628",
	plain_categories = true,
	parent = "Lanyin Mandarin",
}

labels["Liuzhou Mandarin"] = {
	region = "[[Liuzhou]] in north-central [[Guangxi]] Autonomous Region in southern [[China]]",
	Wikidata = "Q7224853",
	plain_categories = true,
	parent = "Guiliu Mandarin", -- a variety of Southwestern Mandarin
}

labels["Luoyang Mandarin"] = {
	region = "[[Luoyang]] and nearby parts of [[Henan]] Province, in central-eastern [[China]]",
	aliases = {"Luoyang"},
	Wikidata = "Q3431347",
	plain_categories = true,
	parent = "Central Plains Mandarin",
}

labels["Malaysian Mandarin"] = {
	prep = "by",
	region = "ethnic Chinese in [[Malaysia]]",
	aliases = {"Malaysia Mandarin"},
	Wikidata = "Q13646143",
	plain_categories = true,
	parent = "Southeast Asian Mandarin",
	othercat = "Malaysian Chinese",
}

labels["Muping Mandarin"] = {
	region = "[[Muping]] District in the prefecture-level city of [[Yantai]] in northeastern [[Shandong]] Province, in northeastern [[China]]",
	aliases = {"Muping"}, -- there is also a Muping in Sichuan but it's not clear if it has a dialect
	Wikidata = {"Q281015", "Q15914589"}, -- articles for Muping District and for Denglian Mandarin (which includes Yantai and Muping varieties)
	plain_categories = true,
	parent = "Jiaoliao Mandarin",
}

labels["Nanjing Mandarin"] = {
	region = "[[Nanjing]], capital of [[Jiangsu]] Province in eastern [[China]]",
	aliases = {"Nanjing"},
	Wikidata = "Q2681098",
	plain_categories = true,
	parent = "Jianghuai Mandarin",
}

labels["Nantong Mandarin"] = {
	-- A subvariety of Tongtai (Tairu) Mandarin, which is a variety of Jianghuai (Lower Yangtze) Mandarin.
	-- On the English Wikipedia, 'Nantong dialect' redirects to [[w:Tong-Tai Mandarin]].
	-- no Nantong alias; Nantong Wu also exists
	region = "[[Nantong]] in southeastern [[Jiangsu]] Province in eastern [[China]]",
	Wikidata = "Q10909110",
	plain_categories = true,
	parent = "Tongtai Mandarin",
}

labels["Northeastern Mandarin"] = {
	-- A primary branch.
	-- Dialects per Wikipedia: [[w:Changchun dialect]], [[w:Harbin dialect]], Qiqihar dialect (齐齐哈尔话),
	-- [[w:Shenyang dialect]].
	region = "{{w|Northeast China}}, including the provinces of [[Liaoning]], [[Jilin]] and [[Heilongjiang]] but excluding the [[Liaodong]] Peninsula",
	addl = "A primary branch of Mandarin.",
	aliases = {"northeastern Mandarin", "NE Mandarin"},
	Wikidata = "Q1064504",
	plain_categories = true,
	parent = true,
}

labels["non-Mainland Mandarin"] = {
	prep = "by",
	region = "ethnic Chinese outside of [[mainland China]], including in [[Hong Kong]] and [[Macau]] due to their special history",
	display = "non-[[w:Mainland China|Mainland]] [[w:Mandarin Chinese|Mandarin]]",
	aliases = {"Non-Mainland Mandarin", "non-mainland Mandarin"},
	plain_categories = true,
	parent = true,
	othercat = "non-Mainland Chinese",
}

labels["Overseas Mandarin"] = {
	prep = "outside of",
	region = "[[mainland China]], [[Taiwan]], [[Hong Kong]] and [[Macau]]",
	Wikipedia = "Overseas Chinese",
	plain_categories = true,
	parent = "non-Mainland Mandarin",
	othercat = "Overseas Chinese",
}

-- FIXME: Category missing.
labels["Philippine Mandarin"] = {
	prep = "by",
	region = "{{w|Chinese Filipino}}s in the [[Philippines]]",
	aliases = {"Philippines Mandarin"},
	Wikidata = "Q7185155",
	plain_categories = true,
	parent = "Southeast Asian Mandarin",
	othercat = "Philippine Chinese",
}

-- FIXME: Category missing.
labels["Qingdao Mandarin"] = {
	region = "[[Qingdao]] and nearby towns, in [[Shandong]] Province in coastal eastern [[China]]",
	aliases = {"Qingdao"},
	Wikidata = "Q7267815",
	plain_categories = true,
	parent = "Jiaoliao Mandarin",
}

-- FIXME: Category missing.
labels["Shenyang Mandarin"] = {
	region = "[[Shenyang]], the capital of [[Liaoning]] Province in northeastern [[China]]",
	aliases = {"Shenyang"},
	Wikidata = "Q7494349",
	plain_categories = true,
	parent = "Northeastern Mandarin",
}

-- We use 'Singapore Mandarin' not 'Singaporean Mandarin' despite the Wikipedia article both to match all the other
-- Singapore language varieties (which say 'Singapore' not 'Singaporean') and because the form with 'Singapore' seeems
-- actually more common in Google Scholar.
labels["Singapore Mandarin"] = {
	prep = "by",
	region = "{{w|Chinese Singaporeans}}s in [[Singapore]]",
	aliases = {"Singaporean Mandarin"},
	Wikidata = "Q1048980",
	plain_categories = true,
	parent = "Southeast Asian Mandarin",
	othercat = "Singapore Chinese",
}

labels["Southeast Asian Mandarin"] = {
	region = "[[Southeast Asia]], stretching from [[Myanmar]] ([[Burma]]) in the northwest, to the [[Philippines]] in the northeast, to [[Indonesia]] in the south",
	Wikipedia = {"Overseas Chinese", "Southeast Asia"},
	plain_categories = true,
	parent = "Overseas Mandarin",
	othercat = "Southeast Asian Chinese",
}

labels["Southwestern Mandarin"] = {
	-- A primary branch.
	-- Dialects per Wikipedia: Changde dialect (常德话), [[w:Chengdu dialect]], [[w:Chongqing dialect]], Dali dialect
	-- (大理话), Guiyang dialect (贵阳话), [[w:Kunming dialect]], Liuzhou dialect (柳州话), [[w:Wuhan dialect]],
	-- [[w:Xichang dialect]], Yichang dialect (宜昌话), Hanzhong dialect (汉中话).
	region = "the provinces of [[Hubei]], [[Sichuan]], [[Guizhou]], [[Yunnan]], and the Mandarin-speaking areas of [[Hunan]], [[Guangxi]] Autonomous Region and southern [[Shaanxi]]",
	addl = "A primary branch of Mandarin.",
	aliases = {"southwestern Mandarin", "Upper Yangtze Mandarin", "Southwest Mandarin"},
	Wikidata = "Q2609239",
	plain_categories = true,
	parent = true,
}

labels["Taiwanese Mandarin"] = {
	region = "[[Taiwan]]",
	aliases = {"Taiwan Mandarin"},
	Wikidata = "Q262828",
	plain_categories = true,
	parent = "non-Mainland Mandarin",
	othercat = "Taiwanese Chinese",
}

labels["Tianjin Mandarin"] = {
	region = "[[Tianjin]] in coastal eastern [[China]] as well as [[Sabah]] in [[Malaysia]]",
	aliases = {"Tianjin", "Tianjinese", "Tianjinese Mandarin"},
	Wikidata = "Q7800220",
	plain_categories = true,
	parent = "Jilu Mandarin",
}

-- FIXME: Category missing.
labels["Tongtai Mandarin"] = {
	region = "east-central [[Jiangsu]] Province in [[Nantong]] and [[Taizhou]]",
	aliases = {"Tongtai", "Tairu Mandarin", "Tairu"},
	Wikidata = "Q7820911",
	plain_categories = true,
	parent = "Jianghuai Mandarin",
}

labels["Ürümqi Mandarin"] = {
	region = "[[Ürümqi]], the capital of [[Xinjiang]] Autonomous Region in far northwestern [[China]]",
	aliases = {"Ürümqi", "Urumqi Mandarin", "Urumqi"},
	Wikidata = "Q10878256",
	plain_categories = true,
	parent = "Lanyin Mandarin",
}

labels["Wanrong Mandarin"] = {
	region = "[[Wanrong]] County in southern [[Shanxi]] Province in central [[China]]",
	aliases = {"Wanrong"}, -- Wanrong County in Shanxi; there is a Wanrong Township (mountain indigenous township)
						   -- in Hualien County, Taiwan, mostly inhabited by Taiwan Aborigines
	Wikidata = "Q10379509", -- article on Fenhe Mandarin
	plain_categories = true,
	parent = "Fenhe Mandarin", -- a variety of Central Plains Mandarin
}

-- FIXME: Category missing.
labels["Weihai Mandarin"] = {
	region = "[[Weihai]] and environs, in eastern [[Shandong]] Province in coastal eastern [[China]]",
	aliases = {"Weihai"},
	Wikidata = "Q3025951",
	plain_categories = true,
	parent = "Jiaoliao Mandarin",
}

labels["Wuhan Mandarin"] = {
	region = "[[Wuhan]], the capital of [[Hubei]] Province in central [[China]]",
	aliases = {"Wuhan", "Hankou", "Hankow"},
	Wikidata = "Q11124731",
	plain_categories = true,
	parent = "Southwestern Mandarin", -- actually belongs to the Wutian variety of Southwestern Mandarin
}

labels["Xi'an Mandarin"] = {
	region = "[[Xi'an]], the capital of [[Shaanxi]] Province in central [[China]]",
	aliases = {"Xi'an"},
	Wikidata = "Q123700130", -- currently a redirect to [[w:Guanzhong dialect]]
	plain_categories = true,
	parent = "Guanzhong Mandarin", -- a variety of Central Plains Mandarin
}

-- FIXME: Category missing.
labels["Xichang Mandarin"] = {
	region = "[[Xichang]], in far southern [[Sichuan]] Province in southwestern [[China]]",
	aliases = {"Xichang"},
	Wikidata = "Q17067030",
	plain_categories = true,
	parent = "Southwestern Mandarin",
}

labels["Xining Mandarin"] = {
	region = "[[Xining]], the capital of [[Qinghai]] Province in northwestern [[China]]",
	aliases = {"Xining"},
	Wikidata = "Q662754", -- article on Lanyin Mandarin
	plain_categories = true,
	parent = "Lanyin Mandarin",
}

labels["Xinjiang Mandarin"] = {
	-- Depending on where in Xinjiang, either a variety of Lanyin Mandarin or Central Plains Mandarin.
	region = "[[Xinjiang]] Autonomous Region; in the north, including varieties of {{catlink|Lanyin Mandarin}} and in the south, including varieties of {{catlink|Central Plains Mandarin}}",
	aliases = {"Xinjiang"},
	Wikidata = "Q93684068",
	plain_categories = true,
	parent = true,
}

labels["Xuzhou Mandarin"] = {
	region = "[[Xuzhou]] in northwestern [[Jiangsu]] Province in eastern [[China]]",
	aliases = {"Xuzhou"},
	Wikidata = "Q8045307",
	plain_categories = true,
	parent = "Central Plains Mandarin",
}

labels["Yangzhou Mandarin"] = {
	region = "[[Yangzhou]] in central [[Jiangsu]] Province in eastern [[China]]",
	aliases = {"Yangzhou"},
	Wikidata = "Q11076194",
	plain_categories = true,
	parent = "Jianghuai Mandarin",
}

labels["Yinchuan Mandarin"] = {
	region = "[[Yinchuan]], capital of [[Ningxia]] Hui Autonomous Region in north-central [[China]]",
	aliases = {"Yinchuan"},
	Wikidata = {"Q125021069", "Q662754"}, -- second is article on Lanyin Mandarin; "Yinchuan Mandarin" has its own Wikidata item Q125021069 but has no links
	plain_categories = true,
	parent = "Lanyin Mandarin",
}

-- FIXME: Category missing.
labels["Yunnan Mandarin"] = {
	region = "[[Yunnan]] Province in southwestern [[China]]",
	-- "Yunnan" as alias seems unlikely to be correct
	Wikidata = "Q10881055",
	plain_categories = true,
	parent = "Southwestern Mandarin",
}

---------------------- Sichuanese ----------------------

-- The following violates normal conventions, which would use "Sichuan Mandarin". But it matches the 'Sichuanese'
-- language.
labels["Sichuanese"] = {
	def = "[[Sichuanese]], a variety of {{catlink|Southwestern Mandarin]] spoken in [[Sichuan]] Province and [[Chongqing]] (a {{w|direct-administered municipality), as well as the adjacent regions of neighboring provinces, such as [[Hubei]], [[Guizhou]], [[Yunnan]], [[Hunan]] and [[Shaanxi]]",
	aliases = {"Sichuan"},
	Wikidata = "Q2278732",
	regional_categories = true,
	parent = "Southwestern Mandarin",
}

labels["Chengdu Sichuanese"] = {
	region = "[[Chengdu]], the capital of [[Sichuan]] Province in southwestern [[China]]",
	aliases = {"Chengdu", "Chengdu Mandarin"},
	Wikidata = "Q11074683",
	plain_categories = true,
	parent = "Chengyu Sichuanese",
}

-- FIXME: Category missing.
labels["Chengyu Sichuanese"] = {
	region = "northern and eastern [[Sichuan]] Province, the northeastern part of the {{w|Chengdu Plain}}, several cities or counties in southwestern [[Sichuan]] ([[Panzhihua]], {{w|Dechang}}, {{w|Yanyuan}}, {{w|Huili}} and {{w|Ningnan}}), southern [[Shaanxi]] Province and western [[Hubei]] Province",
	addl = "It is a primary branch of Sichuanese and is named after the principal cities of [[Chengdu]] and [[Chongqing]] (based on the former {{w|Yu Prefecture}}).",
	aliases = {"Chengyu", "Chengyu Mandarin", "Chengdu-Chongqing", "Chengdu-Chongqing Mandarin"},
	Wikidata = "Q5091311",
	plain_categories = true,
	parent = true,
}

labels["Chongqing Sichuanese"] = {
	region = "[[Chonqing]], a {{w|direct-administered municipality}} in western [[China]]",
	aliases = {"Chongqing", "Chongqing Mandarin"},
	Wikidata = "Q15902531",
	plain_categories = true,
	parent = "Chengyu Sichuanese",
}

-- FIXME: Category missing.
labels["Leshan Sichuanese"] = {
	region = "[[Leshan]] in [[Sichuan]] Province, in southwestern [[China]]",
	aliases = {"Leshan", "Leshan Mandarin"},
	Wikidata = "Q6530337",
	plain_categories = true,
	parent = "Minjiang Sichuanese",
}

-- FIXME: Category missing.
labels["Minjiang Sichuanese"] = {
	region = "the [[Min]] River in [[Sichuan]] Province or along the [[Yangtze]] in the southern and western parts of the {{w|Sichuan Basin}}, in southwestern [[China]]",
	addl = "It is a primary branch of Sichuanese.",
	aliases = {"Minjiang", "Minjiang Mandarin"},
	Wikidata = "Q6867767",
	plain_categories = true,
	parent = true,
}

-- FIXME: Category missing.
labels["Renfu Sichuanese"] = {
	region = "the lower reaches of the {{w|Tuo River|Tuo}} and [[Min]] Rivers in the {{w|Sichuan Basin}} in central-southern [[Sichuan]] Province",
	addl = "It is a primary branch of Sichuanese and is named after {{w|Renshou County}} and {{w|Fushun County, Sichuan|Fushun County}}.",
	-- Jianggong is used by zhwiki.
	aliases = {"Renfu", "Renfu Mandarin", "Renshou-Fushun", "Renshou-Fushun Mandarin", "Renshou-Fushun Sichuanese", "Jianggong", "Jianggong Mandarin", "Jianggong Sichuanese"},
	Wikidata = "Q10883781",
	plain_categories = true,
	parent = true,
}

-- FIXME: Category missing.
labels["Yamian Sichuanese"] = {
	region = "an area surrounding and to the southwest of [[Ya'an]] in central [[Sichuan]] Province in southwestern [[China]]",
	addl = "It is a primary branch of Sichuanese and named after the city of [[Ya'an]] and {{w|Shimian County}} to the southwest.",
	aliases = {"Yamian", "Yamian Mandarin"},
	Wikidata = "Q56243639",
	plain_categories = true,
	parent = true,
}

-- FIXME: Category missing.
labels["Zigong Sichuanese"] = {
	region = "[[Zigong]] in southeastern [[Sichuan]] Province in southwestern [[China]]",
	aliases = {"Zigong", "Zigong Mandarin"},
	Wikidata = "Q8071810",
	plain_categories = true,
	parent = "Renfu Sichuanese",
}

------------------------------------------ Min ------------------------------------------

labels["Min"] = {
	def = "a broad group of {{w|Sinitic languages}} spoken in most of [[Fujian]] Province in southeast [[China]]; in nearly all of coastal [[Taiwan]]; in coastal eastern [[Guangdong]] Province; on the [[Leizhou]] Peninsula in southernmost [[Guangdong]] Province; on [[Hainan]] Island south of [[Guangdong]]; in isolated pockets in southern [[Zhejiang]] Province; and in overseas communities across [[Southeast Asia]] as well as [[Japan]], the [[United States]] and [[Canada]]",
	Wikidata = "Q56504",
	regional_categories = true,
	parent = true,
}

labels["Central Min"] = {
	region = "the {{w|Sha River}} valley in the [[prefecture-level city]] of [[Sanming]] in central mountainous [[Fujian]] Province in southeastern [[China]], consisting of the [[county-level city]] of [[Yong'an]], the urban {{w|Sanyuan District|Sanyuan}} and {{w|Meilie District}}s of [[Sanming]], and the {{w|Shaxian District}} (formerly {{w|Sha County}})",
	aliases = {"Min Zhong"},
	Wikidata = "Q56435",
	regional_categories = true,
	parent = "Inland Min",
}

labels["Coastal Min"] = {
	def = "a family of {{w|Sinitic languages}} spoken in coastal [[Fujian]] Province in southeast [[China]]; in nearly all of coastal [[Taiwan]]; in coastal eastern [[Guangdong]] Province; on the [[Leizhou]] Peninsula in southernmost [[Guangdong]] Province; on [[Hainan]] Island south of [[Guangdong]]; in isolated pockets in southern [[Zhejiang]] Province; and in overseas communities across [[Southeast Asia]] as well as [[Japan]], the [[United States]] and [[Canada]]",
	addl = "The vast majority of {{catlink|Min Chinese}} speakers are Coastal Min speakers, but the {{catlink|Inland Min Chinese}} languages show much greater variety.",
	aliases = {"coastal Min"},
	Wikidata = "Q20667215",
	parent = "Min",
}

-- The following violates normal conventions, which would use "Hainanese Min' or 'Hainan Min'. But it matches the
-- 'Hainanese' language and Wikipedia.
labels["Hainanese"] = {
	region = "the coastal parts of [[Hainan]] Island south of [[Guangdong]] Province in southern [[China]], as well as by {{w|Overseas Chinese}} in [[Singapore]], [[Malaysia]], [[Thailand]], [[Indonesia]], [[Cambodia]] and [[Vietnam]]",
	addl = "The phylogeny of Hainanese is debated, with some classifying it as part of [[:Category:Southern Min Chinese|Southern Min]] but others leaving it as a separate primary branch of [[:Category:Coastal Min Chinese|Coastal Min]] or grouping it with [[:Category:Leizhou Min Chinese|Leizhou Min]] into a Qiong-Lei group.",
	aliases = {"Hainan Min", "Hainanese Min", "Hainan Min Chinese"},
	Wikidata = "Q934541",
	regional_categories = true,
	parent = "Coastal Min",
}

labels["Inland Min"] = {
	def = "a family of {{w|Sinitic languages}} spoken in inland [[Fujian]] Province in southeast [[China]]",
	addl = "Although the Inland Min languages represent less than 10% of {{catlink|Min Chinese}} speakers, they show much greater variety compared with {{catlink|Coastal Min Chinese}}.",
	aliases = {"inland Min"},
	Wikidata = "Q20667237",
	parent = "Min",
}

labels["Leizhou Min"] = {
	region = "the {{w|Leizhou Penisula}}, particularly the [[county-level city]] of [[Leizhou]]; {{w|Mazhang}} District and parts of [[Xiashan District]] of the [[prefecture-level city]] of [[Zhanjiang]]; {{w|Xuwen County}} and most parts of [[Suixi County, Guangdong|Suixi County]] in [[Zhanjiang]]; as well as by migrants in [[Hong Kong]], [[Macau]], [[Taiwan]], [[Singapore]], [[Malaysia]], [[Indonesia]] and the [[United States]]",
	aliases = {"Leizhou"},
	Wikidata = "Q1988433",
	regional_categories = true,
	parent = "Coastal Min",
}

labels["Puxian Min"] = {
	prep = "between",
	region = "[[:Category:Southern Min Chinese|Southern Min]] and [[:Category:Eastern Min Chinese|Eastern Min]] territory in coastal [[Fujian]] Province in southeastern [[China]], especially in the urban parts of the [[prefecture-level city]] of [[Putian]] and in {{w|Xianyou County}}; in some parts of [[Fuzhou]] and [[Quanzhou]]; in {{w|Wuqiu Township, Kinmen County}}, under the jurisdiction of [[Taiwan]]; and {{w|Overseas Chinese|overseas}} in [[Malayia]], [[Indonesia]] and [[Singapore]]",
	aliases = {"Puxian", "Pu-Xian Min", "Pu-Xian", "Xinghua", "Hinghwa"},
	Wikidata = "Q56583",
	regional_categories = true,
	parent = "Coastal Min",
}

-- FIXME: Category missing.
labels["Shaojiang Min"] = {
	region = "an area centered on the western part of the [[prefecture-level city]] of [[Nanping]] in northwest [[Fujian]] Province, specifically in {{w|Guangze County}}, western {{w|Shunchang County}} and the [[county-level city]] of [[Shaowu]], as well as {{w|Jiangle County}} under the jurisdiction of the [[prefecture-level city]] of [[Sanming]]",
	addl = "The classification of Shaojiang Min is disputed, as it is transitional between {{catlink|Northern Min Chinese}} and {{catlink|Gan Chinese}}.",
	aliases = {"Shaojiang"},
	Wikidata = "Q3431451",
	regional_categories = true,
	parent = "Inland Min",
}

labels["Zhongshan Min"] = {
	def = "a group of three {{catlink|Coastal Min Chinese}} dialect islands in the [[prefecture-level city]] of [[Zhongshan]] in southern [[Guangdong]] Province in southern [[China]]",
	addl = "The three dialects may not form a [[clade]]. Some researchers, e.g. {{w|Nicholas Bodman}}, believe that the [[:Category:Longdu Zhongshan Min|Longdu]] and [[:Category:Nanlang Zhongshan Min|Nanlang]] dialects belong to {{catlink|Eastern Min Chinese}} while the [[:Category:Sanxiang Zhongshan Min|Sanxiang]] dialect belongs to {{catlink|Southern Min Chinese}}.",
	aliases = {"Zhongshan"},
	Wikidata = "Q8070958",
	regional_categories = true,
	parent = "Coastal Min",
}

---------------------- Eastern Min ----------------------

labels["Eastern Min"] = {
	def = "a branch of the {{w|Sinitic languages}} spoken in eastern [[Fujian]] Province in southeast [[China]], as well as in parts of extreme southern [[Zhejiang]] Province to the north of Fujian and in the [[Matsu]] Islands (belonging to [[Taiwan]])",
	aliases = {"Min Dong"},
	Wikidata = "Q36455",
	regional_categories = true,
	parent = "Coastal Min",
}

labels["dialectal Eastern Min"] = {
	aliases = {"dialectal Min Dong"},
	Wikidata = "Q36455", -- article for Eastern Min
	regional_categories = "Eastern Min",
}

-- FIXME: Category missing.
labels["Changle Eastern Min"] = {
	region = "[[Changle]] District, an urban district of the [[prefecture-level city]] of [[Fuzhou]], the capital of [[Fujian]] Province in southeast [[China]]",
	aliases = {"Changle"},
	Wikidata = "Q19856351",
	plain_categories = true,
	parent = "Fuzhou Eastern Min",
}

-- FIXME: Category missing.
labels["Fu'an Eastern Min"] = {
	-- The representative variety of Funing Eastern Min.
	region = "the urban part of the [[county-level city]] of [[Fu'an]] in northeastern [[Fujian]] Province in southeast [[China]]",
	aliases = {"Fu'an"},
	Wikidata = "Q7216573",
	plain_categories = true,
	parent = "Funing Eastern Min",
}

-- FIXME: Category missing.
labels["Fuding Eastern Min"] = {
	region = "most parts of the [[county-level city]] of {{w|Fuding}} in far northeastern [[Fujian]] Province in southeast [[China]]",
	aliases = {"Fuding", "Tongshan", "Tongshan Eastern Min"},
	Wikidata = "Q19853248",
	plain_categories = true,
	parent = "Funing Eastern Min",
}

-- FIXME: Category missing.
labels["Funing Eastern Min"] = {
	-- A primary branch; should possibly be called North Eastern Min.
	region = "most parts of the [[prefecture-level city]] of [[Ningde]] in northeastern [[Fujian]] Province in southeast [[China]] (except for {{w|Gutian County}} and {{w|Pingnan County, Fujian|Pingnan County}})",
	aliases = {"Funing"},
	Wikidata = "Q18943896",
	plain_categories = true,
	parent = "Eastern Min",
}

-- FIXME: Category missing.
labels["Fuqing Eastern Min"] = {
	region = "the [[county-level city]] of [[Fuqing]] in eastern [[Fujian]] Province in southeast [[China]]",
	aliases = {"Fuqing"},
	Wikidata = "Q15895753",
	plain_categories = true,
	parent = "Fuzhou Eastern Min",
}

-- FIXME: Category missing.
labels["Fuzhou Eastern Min"] = {
	-- A primary branch; should possibly be called South Eastern Min.
	-- Other varieties of Fuzhou (Houguan) Eastern Min not given entries here because they have no associated Wikipedia
	-- articles or Wikidata entries:
	  -- Minhou Eastern Min
	  -- Youxi Eastern Min
	  -- Dai Yunshan Eastern Min
	  -- Yongtai Eastern Min
	  -- Pingnan Eastern Min
	  -- Pingtan Eastern Min
	  -- Luoyuan Eastern Min
	region = "the [[prefecture-level city]] of [[Fuzhou]] and environs, in eastern [[Fujian]] Province in southeast [[China]]; also the offshore [[Matsu]] Islands (belonging to [[Taiwan]]), and overseas in [[Thailand]], [[Singapore]], [[Malaysia]] and [[Indonesia]]",
	addl = "Here, ''Fuzhou'' is used in the broad sense, corresponding to the Wikipedia article on {{w|Fuzhou dialect}} and sometimes given the technical name of ''Houguan Eastern Min''. The prestige form, spoken in central urban Fuzhou, can be found under {{catlink|Urban Fuzhou Eastern Min}}.",
	aliases = {"Fuzhou", "Houguan Eastern Min", "Houguan"},
	-- Of the following two, the first one is for [[w:Fuzhou dialect]], which describes the broad sense of the
	-- "Fuzhou dialect", which is the same as Houguan; the second one is for [[w:zh:侯官片]] = "Houguan subgroup".
	-- The narrow sense of "Fuzhou dialect" uses the label "Urban Fouzhou Eastern Min".
	Wikidata = {"Q35571", "Q18943758"},
	plain_categories = true,
	parent = "Eastern Min",
}

-- FIXME: Category missing.
labels["Gutian Eastern Min"] = {
	region = "{{w|Gutian County}} in northeastern [[Fujian]] Province in southeast [[China]]; also found overseas in the city of {{w|Sibu}} and the town of {{w|Sitiawan}} in [[Malaysia]]",
	aliases = {"Gutian"},
	Wikidata = "Q18944085",
	plain_categories = true,
	parent = "Fuzhou Eastern Min",
}

-- FIXME: Category missing.
labels["Lianjiang Eastern Min"] = {
	region = "{{w|Lianjiang County}} in northeastern [[Fujian]] Province in southeast [[China]]",
	aliases = {"Lianjiang"},
	Wikidata = "Q19856291",
	plain_categories = true,
	parent = "Fuzhou Eastern Min",
}

-- FIXME: Category missing.
labels["Manjiang Eastern Min"] = {
	-- A primary branch. Has some influences from Wu, but usually classified as Eastern Min.
	-- Chinese Wikipedia distinguishes between "Manjiang" (蛮讲) and "Manhua" (蛮话) and claims they are two
	-- distinct varieties, but I think this is based on confusion; for example, they both have the same ISO 639-6
	-- code "maua", and the English Wikipedia specifically asserts that both 蛮讲 and 蛮话 are the same.
	region = "parts of far southeastern [[Zhejiang]] Province bordering [[Fujian]] Province; specifically, {{w|Taishun County}} and {{w|Cangnan County}} (part of the [[prefecture-level city]] of [[Wenzhou]]) and parts of {{w|Qingyuan County, Zhejiang|Qingyuan County}} (part of the [[prefecture-level city]] of [[Lishui]])",
	addl = "The Manjiang varieties show significant influence from {{catlink|Wu Chinese}}, to the extent that some researchers have classified them as Wu. They also have significant subtratal influences, perhaps from a formerly spoken [[Austronesian]] or [[Kra-Dai]] language.",
	aliases = {"Manjiang", "Manhua Eastern Min", "Manhua", "Mango Eastern Min", "Mango"},
	Wikidata = "Q3431721",
	plain_categories = true,
	parent = "Eastern Min",
}

-- FIXME: Category missing.
labels["Matsu Eastern Min"] = {
	region = "the [[Matsu]] Islands, under the jurisdiction of [[Taiwan]] but offshore from {{w|Lianjiang County}} in northeastern [[Fujian]] Province in southeast [[China]]",
	addl = "The Matsu variety is close to the {{catlink|Lianjiang Eastern Min}} variety.",
	aliases = {"Matsu"},
	Wikidata = "Q19599280",
	plain_categories = true,
	parent = "Fuzhou Eastern Min",
}

-- FIXME: Category missing.
labels["Minqing Eastern Min"] = {
	region = "{{w|Minqing County}} in eastern [[Fujian]] Province in southeast [[China]]",
	aliases = {"Minqing"},
	Wikidata = "Q48897247",
	plain_categories = true,
	parent = "Fuzhou Eastern Min",
}

-- FIXME: Category missing.
labels["Ningde Eastern Min"] = {
	region = "urban areas of the [[prefecture-level city]] of [[Ningde]] in northeastern [[Fujian]] Province in southeast [[China]]",
	aliases = {"Ningde"},
	Wikidata = "Q18941249",
	plain_categories = true,
	parent = "Funing Eastern Min",
}

-- FIXME: Category missing.
labels["Shouning Eastern Min"] = {
	region = "{{w|Shouning County}} in northeastern [[Fujian]] Province in southeast [[China]]",
	aliases = {"Shouning"},
	Wikidata = "Q19852223",
	plain_categories = true,
	parent = "Funing Eastern Min",
}

-- FIXME: Category missing.
labels["Urban Fuzhou Eastern Min"] = {
	-- The representative variety of Fuzhou (Houguan) Eastern Min.
	region = "urban areas of the [[prefecture-level city]] of [[Fuzhou]] in eastern [[Fujian]] Province in southeast [[China]]",
	aliases = {"Urban Fuzhou"},
	Wikidata = "Q35571",
	plain_categories = true,
	parent = "Fuzhou Eastern Min",
}

-- FIXME: Category missing.
labels["Xiapu Eastern Min"] = {
	region = "[[Xiapu]] County in coastal northeastern [[Fujian]] Province in southeast [[China]]",
	aliases = {"Xiapu"},
	Wikidata = "Q15899756",
	plain_categories = true,
	parent = "Funing Eastern Min",
}

-- FIXME: Category missing.
labels["Zherong Eastern Min"] = {
	region = "{{w|Zherong County}} in northeastern [[Fujian]] Province in southeast [[China]]",
	aliases = {"Zherong"},
	Wikidata = "Q19852850",
	plain_categories = true,
	parent = "Funing Eastern Min",
}

-- FIXME: Category missing.
labels["Zhouning Eastern Min"] = {
	region = "{{w|Zhouning County}} in northeastern [[Fujian]] Province in southeast [[China]]",
	aliases = {"Zhouning", "Zhoudun", "Zhoudun Eastern Min"},
	Wikidata = "Q19852132",
	plain_categories = true,
	parent = "Funing Eastern Min",
}

---------------------- Northern Min ----------------------

labels["Northern Min"] = {
	def = "a branch of the {{catlink|Inland Min}} languages spoken in the [[prefecture-level city]] of [[Nanping]] in northwestern [[Fujian]] Province in southeast [[China]]",
	aliases = {"Min Bei"},
	Wikidata = "Q36457",
	regional_categories = true,
	parent = "Inland Min",
}

-- FIXME: Category missing.
labels["Chong'an Northern Min"] = {
	region = "the [[county-level city]] of {{w|Wuyishan, Fujian|Wuyishan}} (formerly Chong'an County) in northwestern [[Fujian]] Province in southeast [[China]]",
	aliases = {"Chong'an", "Wuyishan Northern Min", "Wuyishan"},
	Wikidata = "Q19855654",
	plain_categories = true,
	parent = "Xixi Northern Min",
}

-- FIXME: Category missing.
labels["Dongxi Northern Min"] = {
	-- A primary branch. Maybe should be called East Northern Min. Note here that Dongxi is 東溪 (dōngxī); here dōng
	-- means "east", but the second xī does not mean "west" but more like "stream" or "creek".
	-- No Wikidata link or Wikipedia entry for this
	plain_categories = true,
	parent = "Northern Min",
}

-- FIXME: Category missing.
labels["Xixi Northern Min"] = {
	-- A primary branch. Maybe should be called West Northern Min. Note here that Xixi is 西溪 (xīxī); here the first
	-- xī means "west", but the second xī does not mean "west" but more like "stream" or "creek".
	-- No Wikidata link or Wikipedia entry for this
	plain_categories = true,
	parent = "Northern Min",
}

-- FIXME: Category missing.
labels["Jian'ou Northern Min"] = {
	-- The representative variety of Dongxi Northern Min.
	region = "the [[county-level city]] of [[Jian'ou]] in northern [[Fujian]] Province in southeast [[China]]",
	aliases = {"Jian'ou"},
	Wikidata = "Q6191447",
	plain_categories = true,
	parent = "Dongxi Northern Min",
}

-- FIXME: Category missing.
labels["Jianyang Northern Min"] = {
	-- The representative variety of Xixi Northern Min.
	region = "[[Jianyang]] District of the [[prefecture-level city]] of [[Nanping]] in northwestern [[Fujian]] Province in southeast [[China]]",
	aliases = {"Jianyang"},
	Wikidata = "Q16930647",
	plain_categories = true,
	parent = "Xixi Northern Min",
}

-- FIXME: Category missing.
labels["Nanping Northern Min"] = {
	aliases = {"Nanping"},
	Wikidata = "Q68534", -- the entry for the city of Nanping; currently no article for the lect
	plain_categories = true,
	parent = "Dongxi Northern Min",
}

-- FIXME: Category missing.
labels["Songxi Northern Min"] = {
	region = "{{w|Songxi County}} in northern [[Fujian]] Province in southeast [[China]]",
	aliases = {"Songxi"},
	Wikidata = "Q19855892",
	plain_categories = true,
	parent = "Dongxi Northern Min",
}

-- FIXME: Category missing.
labels["Zhenghe Northern Min"] = {
	region = "{{w|Zhenghe County}} in northern [[Fujian]] Province in southeast [[China]]",
	aliases = {"Zhenghe"},
	Wikidata = "Q19855758",
	plain_categories = true,
	parent = "Dongxi Northern Min",
}

---------------------- Southern Min ----------------------

labels["Southern Min"] = {
	aliases = {"Min Nan"},
	Wikidata = "Q36495",
	regional_categories = true,
	track = true,
	parent = "Coastal Min",
}

labels["dialectal Southern Min"] = {
	aliases = {"dialectal Min Nan"},
	Wikidata = "Q36495", -- article for Eastern Min
	regional_categories = "Southern Min",
}

labels["Datian Min"] = {
	aliases = {"Datian"},
	Wikidata = "Q19855572",
	regional_categories = true,
	parent = "Southern Min",
}

-- FIXME: Category missing.
labels["Haklau Min"] = {
	aliases = {"Hoklo Min", "Haklau", "Hoklo"},
	Wikidata = "Q120755728",
	regional_categories = true,
	parent = "Southern Min",
}

-- FIXME: Category missing.
labels["Zhenan Min"] = {
	aliases = {"Zhenan"},
	Wikidata = "Q3846710",
	regional_categories = true,
	parent = "Southern Min",
}

---------------- Hokkien ----------------

labels["Hokkien"] = {
	region = "[[Fujian]] Province in southeastern [[mainland China]]; [[Taiwan]]; and {{w|Overseas Chinese|overseas}} in various countries",
	country = "China,Taiwan,Singapore,Malaysia,the Philippines,Indonesia,Cambodia,Myanmar,Hong Kong,Thailand,Brunei",
	Wikidata = "Q1624231",
	regional_categories = true,
	parent = "Southern Min",
	othercat = "Hokkien lemmas",
}

labels["Anxi Hokkien"] = {
	region = "{{w|Anxi County}} in the prefecture-level city of [[Quanzhou]] in southern [[Fujian]] Province in southeastern [[China]]",
	aliases = {"Anxi"},
	Wikipedia = "zh:安溪县#語言文化",
	Wikidata = "Q613673", -- Anxi County
	plain_categories = true,
	parent = "Quanzhou Hokkien",
}

labels["Changtai Hokkien"] = {
	region = "[[Changtai]] District in the prefecture-level city of [[Zhangzhou]] in southeastern [[Fujian]] Province in southeastern [[China]]",
	aliases = {"Changtai"},
	Wikipedia = "Changtai, Zhangzhou#Local Dialect",
	Wikidata = "Q1062148", -- [[w:Changtai, Zhangzhou]]
	plain_categories = true,
	parent = "Zhangzhou Hokkien",
}

labels["Hsinchu Hokkien"] = {
	region = "[[Hsinchu]] in northwestern [[Taiwan]]",
	-- Following info from [[w:Taiwanese_Hokkien#Quanzhou–Zhangzhou inclinations]].
	addl = "It is a mixed [[:Category:Quanzhou Hokkien|Quanzhou]]-[[:Category:Zhangzhou Hokkien|Zhangzhou]] variety similar to {{catlink|Tong'an Hokkien}}.",
	aliases = {"Hsinchu"},
	Wikipedia = "zh:新竹市#語言",
	plain_categories = true,
	parent = "Taiwanese Hokkien",
}

labels["Hui'an Hokkien"] = {
	region = "[[Hui'an]] County in southern [[Fujian]] Province in southeastern [[China]]",
	aliases = {"Hui'an"},
	Wikidata = "Q16241797",
	plain_categories = true,
	parent = true,
}

-- FIXME: Same as Medan Hokkien?
labels["Indonesian Hokkien"] = {
	region = "[[Indonesia]], especially in the city of [[Medan]] in [[North Sumatra]]",
	country = "Indonesia",
	aliases = {"Indonesia Hokkien"},
	Wikidata = "Q6805114", -- article for Medan Hokkien
	plain_categories = true,
	parent = "Southeast Asian Hokkien",
	othercat = "Indonesian Chinese",
}

labels["Jinjiang Hokkien"] = {
	region = "the city of [[Jinjiang]], near [[Quanzhou]] in the southern part of [[Fujian]] Province in southeastern [[China]]",
	aliases = {"Jinjiang"},
	Wikidata = "Q2251677", -- article for Quanzhou Hokkien
	plain_categories = true,
	parent = true, -- or Quanzhou Hokkien?
}

labels["Kaohsiung Hokkien"] = {
	-- Taiwanese. Per [[w:Taiwanese_Hokkien#Quanzhou–Zhangzhou inclinations]], mixed Quanzhou-Zhangzhou dialect
	-- similar to Amoy accent.
	region = "[[Kaohsiung]] in southern [[Taiwan]]",
	aliases = {"Kaohsiung"},
	Wikipedia = "Kaohsiung#Languages",
	plain_categories = true,
	parent = "Taiwanese Hokkien",
}

labels["Kinmen Hokkien"] = {
	region = "[[Kinmen]] County, a group of [[Taiwanese]] islands off the coast of [[Mainland China]], near [[Xiamen]] (although in {{w|Wuqiu, Kinmen|Wuqiu Township}}, {{catlink|Puxian Min}} is spoken)",
	addl = "Mostly derived from {{catlink|Quanzhou Hokkien}}.",
	aliases = {"Kinmen"},
	Wikipedia = "Kinmen#Language",
	plain_categories = true,
	parent = "Taiwanese Hokkien",
}

labels["Longyan Hokkien"] = {
	region = "urban [[Longyan]] in southwestern [[Fujian]] Province in southeastern [[China]]",
	aliases = {"Longyan"},
	Wikidata = "Q6674568",
	plain_categories = true,
	parent = true,
}

labels["Lukang Hokkien"] = {
	region = "[[Lukang]] Township in [[Changhua]] County, [[Taiwan]]",
	Wikidata = "Q701693", -- article on Lukang Township
	plain_categories = true,
	parent = "Taiwanese Hokkien",
	-- Following info from [[w:Taiwanese_Hokkien#Quanzhou–Zhangzhou inclinations]].
	othercat = "Quanzhou Hokkien",
}

labels["Malaysian Hokkien"] = {
	region = "Malaysia",
	addl = "There are two markedly different varieties: {{catlink|Southern Malaysian Hokkien}} (based on {{catlink|Quanzhou Hokkien}}) and {{catlink|Penang Hokkien}} (based on {{catlink|Zhangzhou Hokkien}}).",
	aliases = {"Malaysia Hokkien"},
	plain_categories = true,
	parent = "Southeast Asian Hokkien",
	othercat = "Malaysian Chinese",
}

labels["Magong Hokkien"] = {
	region = "[[Magong]], the seat of [[Penghu]] County (the [[Pescadores]] Islands) in [[Taiwan]])",
	aliases = {"Magong"},
	Wikidata = "Q701428", -- article on Magong city in Penghu County
	plain_categories = true,
	parent = "Penghu Hokkien",
}

labels["Medan Hokkien"] = {
	region = "[[Medan]], the capital city of [[North Sumatra]] province in [[Indonesia]]",
	Wikidata = "Q6805114",
	plain_categories = true,
	parent = "Indonesian Hokkien",
	othercat = "Zhangzhou Hokkien",
}

labels["non-Mainland Hokkien"] = {
	prep = "by",
	region = "ethnic Chinese outside of [[mainland China]], including in [[Hong Kong]] and [[Macau]] due to their special history",
	display = "non-[[w:Mainland China|Mainland]] [[w:Hokkien Chinese|Hokkien]]",
	aliases = {"Non-Mainland Hokkien", "non-mainland Hokkien"},
	plain_categories = true,
	parent = true,
	othercat = "non-Mainland Chinese",
}

labels["Overseas Hokkien"] = {
	prep = "outside of",
	region = "[[mainland China]], [[Taiwan]], [[Hong Kong]] and [[Macau]]",
	Wikipedia = "Hoklo people#Diaspora",
	plain_categories = true,
	parent = "non-Mainland Hokkien",
	othercat = "Overseas Chinese",
}

labels["Penang Hokkien"] = {
	region = "the state of [[Penang]] in northwestern {{w|Peninsular Malaysia}}",
	aliases = {"Penang"},
	Wikidata = "Q11120689",
	plain_categories = true,
	parent = "Malaysian Hokkien",
	othercat = "Zhangzhou Hokkien",
}

labels["Penghu Hokkien"] = {
	region = "[[Penghu]] County in [[Taiwan]], also known as the [[Pescadores]] Islands",
	addl = "Mostly derived from {{catlink|Tong'an Hokkien}}.",
	aliases = {"Penghu"},
	Wikipedia = "Penghu#Language",
	plain_categories = true,
	parent = "Taiwanese Hokkien",
}

labels["Philippine Hokkien"] = {
	region = "[[Manila]] in the [[Philippines]]",
	country = "the Philippines",
	aliases = {"PH Hokkien", "Ph Hokkien", "PH", "PHH", "Philippines Hokkien"},
	Wikidata = "Q3236692",
	plain_categories = true,
	parent = "Southeast Asian Hokkien",
	othercat = "Quanzhou Hokkien,Philippine Chinese",
}

labels["Quanzhou Hokkien"] = {
	region = "the city of [[Quanzhou]] and surrounding area, in the southern part of [[Fujian]] Province in southeastern [[China]]",
	aliases = {"Quanzhou", "Chinchew", "Choanchew"},
	Wikidata = "Q2251677",
	plain_categories = true,
	parent = true,
}

labels["Sanxia Hokkien"] = {
	region = "{{w|Sanxia District}}, in the southwestern part of [[New Taipei]], [[Taiwan]]",
	aliases = {"Sanxia"},
	Wikidata = "Q570349", -- article on Sanxia District (in New Taipei City)
	plain_categories = true,
	parent = "Taiwanese Hokkien",
}

-- We use 'Singapore Hokkien' not 'Singaporean Hokkien' despite the Wikipedia article both to match all the other
-- Singapore language varieties (which say 'Singapore' not 'Singaporean') and because the form with 'Singapore' seeems
-- actually more common in Google Scholar.
labels["Singapore Hokkien"] = {
	region = "Singapore",
	aliases = {"Singaporean Hokkien"},
	Wikidata = "Q3846528",
	plain_categories = true,
	parent = "Southeast Asian Hokkien",
	othercat = "Singapore Chinese",
}

labels["Southeast Asian Hokkien"] = {
	region = "[[Southeast Asia]], stretching from [[Myanmar]] ([[Burma]]) in the northwest, to the [[Philippines]] in the northeast, to [[Indonesia]] in the south",
	Wikipedia = {"Hoklo people#Diaspora", "Southeast Asia"},
	plain_categories = true,
	parent = "Overseas Hokkien",
	othercat = "Southeast Asian Chinese",
}

labels["Southern Malaysian Hokkien"] = {
	region = "central and southern {{w|Peninsular Malaysia}}",
	aliases = {"Southern Malaysia Hokkien", "Southern Peninsular Malaysian Hokkien", "Southern Peninsular Malaysia Hokkien"},
	Wikidata = "Q7570322",
	plain_categories = true,
	parent = "Malaysian Hokkien",
	othercat = "Quanzhou Hokkien",
}

labels["Taichung Hokkien"] = {
	region = "[[Taichung]], in central [[Taiwan]]",
	-- No alias for Taichung because there's also Taichung Mandarin ([[w:zh:台中腔]]).
	addl = "Mostly derived from {{catlink|Zhangzhou Hokkien}}.", -- per [[w:Taiwanese_Hokkien#Quanzhou–Zhangzhou inclinations]]
	Wikidata = "Q245023", -- article on Taichung
	plain_categories = true,
	parent = "Taiwanese Hokkien",
	othercat = "Zhangzhou Hokkien",
}

labels["Tainan Hokkien"] = {
	-- Per [[w:zh:臺灣話#方言差]], part of "臺南混合腔" = "Tainan mixed dialect".
	region = "[[Tainan]], in southern [[Taiwan]]",
	aliases = {"Tainan"},
	Wikipedia = "zh:臺南市#語言",
	Wikidata = "Q140631", -- article on Tainan
	plain_categories = true,
	parent = "Taiwanese Hokkien",
}

labels["Taipei Hokkien"] = {
	region = "[[Taipei]], the capital of [[Taiwan]], in the north",
	addl = "It is a mixed [[:Category:Quanzhou Hokkien|Quanzhou]]-[[:Category:Zhangzhou Hokkien|Zhangzhou]] variety similar to {{catlink|Tong'an Hokkien}}.", -- per [[w:Taiwanese_Hokkien#Quanzhou–Zhangzhou inclinations]]
	Wikidata = "Q1867", -- article on Taipei
	plain_categories = true,
	parent = "Taiwanese Hokkien",
}

labels["Taiwanese Hokkien"] = {
	region = "Taiwan",
	aliases = {"Taiwanese Southern Min", "Taiwanese Min Nan", "Taiwan Hokkien", "Taiwan Southern Min", "Taiwan Min Nan"},
	Wikidata = "Q36778",
	plain_categories = true,
	track = true,
	parent = "non-Mainland Hokkien",
	othercat = "Taiwanese Chinese",
}

labels["Tong'an Hokkien"] = {
	-- Per [[zh:同安区#語言]], one of four main dialects of Hokkien in the southern Fujian region,
	-- along with Quanzhou, Zhangzhou and Xiamen. But that doesn't quite make sense, as Tong'an is part of Xiamen.
	region = "[[Tong'an]] District of the [[prefecture-level city]] of [[Xiamen]] in southeastern [[Fujian]] Province in southeastern [[China]]",
	aliases = {"Tong'an"},
	Wikipedia = "zh:同安区#語言",
	Wikidata = "Q1025342",
	plain_categories = true,
	parent = "Xiamen Hokkien",
}

labels["Xiamen Hokkien"] = {
	region = "the [[prefecture-level city]] of [[Xiamen]] and surrounding area, in southeastern [[Fujian]] Province in southeastern [[China]]",
	aliases = {"Xiamen", "Amoy"},
	Wikidata = "Q2705752",
	plain_categories = true,
	parent = true,
}

labels["Yilan Hokkien"] = {
	region = "[[Yilan]] County in northeastern [[Taiwan]]",
	addl = "It is relatively pure {{catlink|Zhangzhou Hokkien}}.", -- per [[w:zh:臺灣話]]
	aliases = {"Yilan"},
	Wikipedia = "zh:漳州话#與其他閩南語方言的比較",
	Wikidata = "Q237258", -- Yilan County, Taiwan
	plain_categories = true,
	parent = "Taiwanese Hokkien",
	othercat = "Zhangzhou Hokkien",
}

labels["Yongchun Hokkien"] = {
	region = "[[Yongchun]] County in the [[prefecture-level city]] of [[Quanzhou]] in southeastern [[Fujian]] Province in southeastern [[China]]; also {{w|Overseas Chinese|overseas}} in [[Taiwan]], [[Malaysia]], [[Singapore]], [[Indonesia]], [[Philippines]], [[Brunei]] and [[Myanmar]]",
	aliases = {"Yongchun"},
	Wikidata = "Q65118728",
	plain_categories = true,
	parent = "Quanzhou Hokkien",
}

labels["Zhao'an Hokkien"] = {
	region = "{{w|Zhao'an County}} in southernmost [[Fujian]] Province in southeastern [[China]]",
	Wikipedia = "zh:詔安縣#詔安閩南語",
	plain_categories = true,
	parent = "Zhangzhou Hokkien",
}

labels["Zhangping Hokkien"] = {
	region = "the [[county-level city]] of {{w|Zhangping}} in southwestern [[Fujian]] Province in southeastern [[China]]",
	aliases = {"Zhangping"},
	Wikidata = "Q15937822",
	plain_categories = true,
	parent = "Zhangzhou Hokkien",
}

labels["Zhangzhou Hokkien"] = {
	region = "the [[prefecture-level city]] of [[Zhangzhou]] and surrounding areas, in southern [[Fujian]] Province in southeastern [[China]]",
	aliases = {"Zhangzhou", "Changchew"},
	Wikidata = "Q8070492",
	plain_categories = true,
	parent = true,
}

---------------- Teochew ----------------

-- The following violates normal conventions, which would use "Teochew Southern Min" or possibly "Teochew Min". But it
-- matches the 'Teochew' full language.
labels["Teochew"] = {
	Wikidata = "Q24841591", -- article for [[w:Chaoshan Min]]; not [[w:Teochew dialect]], which is a dialect of this language
	regional_categories = true,
	track = true,
}

labels["Chaozhou Teochew"] = {
	aliases = {"Chaozhou"},
	Wikidata = "Q36759",
	plain_categories = true,
}

labels["Jieyang Teochew"] = {
	aliases = {"Jieyang"},
	Wikidata = "Q26323", -- article for Jieyang in Guangdong, China
	plain_categories = true,
}

labels["non-Mainland Teochew"] = {
	prep = "by",
	region = "ethnic Chinese outside of [[mainland China]], including in [[Hong Kong]] and [[Macau]] due to their special history",
	display = "non-[[w:Mainland China|Mainland]] [[w:Teochew Chinese|Teochew]]",
	aliases = {"Non-Mainland Teochew", "non-mainland Teochew"},
	plain_categories = true,
	parent = true,
	othercat = "non-Mainland Chinese",
}

labels["Overseas Teochew"] = {
	prep = "outside of",
	region = "[[mainland China]], [[Taiwan]], [[Hong Kong]] and [[Macau]]",
	Wikipedia = "Teochew people",
	plain_categories = true,
	parent = "non-Mainland Teochew",
	othercat = "Overseas Chinese",
}

labels["Pontianak Teochew"] = {
	-- spoken in West Kalimantan, Indonesia
	Wikidata = "Q14168", -- article for Pontianak; "Pontianak Teochew" has its own Wikidata entry Q106560423, but it has no links
	plain_categories = true,
	parent = "Southeast Asian Teochew",
	othercat = "Pontianak Chinese",
}

labels["Singapore Teochew"] = {
	aliases = {"Singaporean Teochew"},
	Wikipedia = "Teochew people#Teochew immigration to Singapore",
	plain_categories = true,
	parent = "Southeast Asian Teochew",
	othercat = "Singapore Chinese",
}

labels["Southeast Asian Teochew"] = {
	region = "[[Southeast Asia]], stretching from [[Myanmar]] ([[Burma]]) in the northwest, to the [[Philippines]] in the northeast, to [[Indonesia]] in the south",
	Wikipedia = {"Teochew people", "Southeast Asia"},
	plain_categories = true,
	parent = "Overseas Teochew",
	othercat = "Southeast Asian Chinese",
}

labels["Thai Teochew"] = {
	aliases = {"Thailand Teochew"},
	Wikipedia = "Thai Chinese#Language",
	plain_categories = true,
	parent = "Southeast Asian Teochew",
	othercat = "Thai Chinese",
}

------------------------------------------ Pinghua ------------------------------------------

labels["Pinghua"] = {
	aliases = {"Ping"},
	Wikidata = "Q2735715",
	regional_categories = true,
}

labels["Guilin Pinghua"] = {
	Wikidata = "Q84302463", -- article for Northern Pinghua; redirects in both English and Chinese to Pinghua article
	plain_categories = true,
	parent = "Northern Pinghua",
}

labels["Nanning Pinghua"] = {
	Wikidata = "Q84302019", -- article for Southern Pinghua; redirects in both English and Chinese to Pinghua article
	plain_categories = true,
	parent = "Southern Pinghua",
}

-- FIXME: Category missing.
labels["Northern Pinghua"] = {
	-- Spoken in northern Guangxi, around the city of Guilin.
	-- English Wikipedia article redirects to Pinghua; Chinese Wikipedia article similarly redirects but contains
	-- more information on Northern Pinghua.
	Wikidata = "Q84302463",
	plain_categories = true,
	parent = true,
}

-- FIXME: Category missing.
labels["Southern Pinghua"] = {
	-- Spoken in southern Guangxi, around the city of Nanning.
	-- English Wikipedia article redirects to Pinghua; Chinese Wikipedia article similarly redirects but contains
	-- more information on Southern Pinghua.
	Wikidata = "Q84302019",
	plain_categories = true,
	parent = true,
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
	region = "{{w|Anji County}} in northwestern [[Zhejiang]] Province in eastern [[China]]",
	aliases = {"Anji"},
	Wikidata = "Q111270089",
	plain_categories = true,
	parent = "Tiaoxi Wu",
}

-- FIXME: Category missing.
labels["Changxing Wu"] = {
	region = "[[Changxing]] County in northwestern [[Zhejiang]] Province in eastern [[China]]",
	aliases = {"Changxing"},
	Wikidata = "Q11126990",
	plain_categories = true,
	parent = "Tiaoxi Wu",
}

-- FIXME: Category missing.
labels["Changzhounese Wu"] = {
	region = "the city of [[Changzhou]] in southern [[Jiangsu]] Province in eastern [[China]], along with surrounding areas",
	aliases = {"Changzhou Wu", "Changzhou", "Changzhounese"},
	-- FIXME: Consider removing the following exception and letting it display as 'Changzhounese Wu'.
	display = "Changzhounese",
	Wikidata = "Q1021819",
	plain_categories = true,
	parent = "Piling Wu",
}

labels["Danyang Wu"] = {
	region = "the [[county-level city]] of {{w|Danyang}} in southern [[Jiangsu]] Province in eastern [[China]]",
	addl = "It is on the border between Wu Chinese (to the south) and Mandarin Chinese (to the north).",
	aliases = {"Danyang"},
	Wikidata = "Q925293", -- article for Danyang, Jiangsu
	plain_categories = true,
	parent = "Piling Wu",
}

-- FIXME: Category missing.
labels["Deqing Wu"] = {
	region = "[[Deqing]] County in northwestern [[Zhejiang]] Province in eastern [[China]]",
	aliases = {"Deqing"},
	Wikidata = "Q109343820",
	plain_categories = true,
	parent = "Tiaoxi Wu",
}

-- FIXME: Category missing.
labels["Fuyang Wu"] = {
	region = "parts of {{w|Fuyang District}} in the city of [[Hangzhou]], the capital of [[Zhejiang]] Province, in eastern [[China]]; located in the northwest part of the province",
	addl = "The dialect geography in Fuyang District is complex, with multiple dialects from distinct groupings spoken in close proximity and several dialect islands.",
	aliases = {"Fuyang"},
	Wikipedia = "zh:富阳话", -- no Wikidata item yet
	plain_categories = true,
	parent = "Linshao Wu",
}

-- FIXME: Category missing.
labels["Haining Wu"] = {
	region = "{{w|Haining}}, a [[county-level city]] in northern [[Zhejiang]] Province in eastern [[China]]",
	aliases = {"Xiashi", "Xiashi Wu", "Haining"},
	Wikidata = "Q286266", -- article for Haining city
	plain_categories = true,
	parent = "Sujiahu Wu",
}

-- FIXME: Category missing.
labels["Haiyan Wu"] = {
	region = "{{w|Haiyang County, Zhejiang|Haiyang County}} in northern [[Zhejiang]] Province in eastern [[China]]",
	aliases = {"Haiyan"},
	Wikidata = "Q1334198", -- article for Haiyan prefecture
	plain_categories = true,
	parent = "Sujiahu Wu",
}

labels["Hangzhounese Wu"] = {
	region = "the city of [[Hangzhou]] in northwestern [[Zhejiang]] Province in eastern [[China]], and its immediate suburbs",
	addl = "It is an isolated variety of Northern Wu with heavy influence from Northern Mandarin lects due to migration during the {{w|Southern Song dynasty}}, but without significant influence from the nearby {{catlink|Jianghuai Mandarin}} lects.",
	aliases = {"Hangzhou", "Hangzhounese", "Hangzhou Wu"},
	-- FIXME: Consider removing the following exception and letting it display as 'Hangzhounese Wu'.
	display = "Hangzhounese",
	Wikidata = "Q5648144",
	plain_categories = true,
	parent = "Northern Wu",
}

labels["Huzhounese Wu"] = {
	region = "the urban ({{w|Wuxing District}}) and suburban ({{w|Nanxun District}}) parts of [[Huzhou]] in northwestern [[Zhejiang]] Province in eastern [[China]]",
	aliases = {"Huzhou", "Huzhou Wu", "Huzhounese"},
	-- FIXME: Consider removing the following exception and letting it display as 'Huzhounese Wu'.
	display = "Huzhounese",
	Wikidata = "Q15901269",
	plain_categories = true,
	parent = "Tiaoxi Wu",
}

-- FIXME: Category missing.
labels["Jiangyin Wu"] = {
	region = "the [[county-level city]] of [[Jiangyin]] in southeast [[Jiangsu]] Province in eastern [[China]]",
	aliases = {"Jiangyin"},
	Wikidata = "Q6191803",
	plain_categories = true,
	parent = "Piling Wu", -- but transitional to Sujiahu Wu
}

-- FIXME: Category missing.
labels["Jiaxing Wu"] = {
	region = "the urban {{w|Xiuzhou District|Xiuzhou}} and {{Nanhu District}}s of the [[prefecture-level city]] of [[Jiaxing]] in far northern [[Zhejiang]] Province in eastern [[China]]",
	aliases = {"Jiaxing"},
	Wikidata = "Q30130993",
	plain_categories = true,
	parent = "Sujiahu Wu",
}

-- FIXME: Category missing.
labels["Jinhui Wu"] = {
	region = "the town of {{w|lang=zh|金汇镇|Jinhui}} in the suburban [[Fengxian]] District of [[Shanghai]], in eastern [[China]]",
	aliases = {"Jinhui", "Dangdai Wu", "Dangdai", "Dônđäc"},
	Wikidata = "Q16259341",
	plain_categories = true,
	parent = "Shanghainese Wu",
}

-- FIXME: Category missing.
labels["Jintan Wu"] = {
	region = "{{w|Jintan District}} of the [[prefecture-level city]] of [[Changzhou]] in southern [[Jiangsu]] Province in eastern [[China]]",
	aliases = {"Jintan"},
	Wikidata = "Q15904190",
	plain_categories = true,
	parent = "Piling Wu",
}

-- FIXME: Category missing.
labels["Jinxiang Wu"] = {
	region = "[[Cangnan]] County in far southern [[Zhejiang]] Province in eastern [[China]]",
	addl = "It is an exclave of Northern Wu surrounded by [[:Category:Southern Min languages|Southern Min]] varieties.",
	aliases = {"Jinxiang"},
	Wikidata = "Q2427960",
	plain_categories = true,
	parent = "Northern Wu",
}

-- FIXME: Category missing.
labels["Jingjiang Wu"] = {
	region = "the [[county-level city]] of [[Jingjiang]] in southeast [[Jiangsu]] Province in eastern [[China]]",
	addl = "The current urban center of Jingjiang uses a {{catlink|Jianghuai Mandarin}} variety, but the Wu variety is still spoken in the rural coastal parts, thus gaining the nickname {{lang|zh|老岸話}} ('Old Coast Speech')",
	aliases = {"Lao'an", "Jingjiang", "Lao'an"},
	Wikipedia = "zh:老岸话", -- no Wikidata item yet
	plain_categories = true,
	parent = "Piling Wu",
}

-- FIXME: Category missing.
labels["Lin'an Wu"] = {
	region = "{{w|Lin'an District}}, an urban district of the [[prefecture-level city]] of [[Hangzhou]], the capital of [[Zhejiang]] Province, in eastern [[China]]; located in the northwest part of the province",
	aliases = {"Lin'an"},
	Wikidata = "Q1022464", -- article for Lin'an District (part of the prefecture-level city of Hangzhou)
	plain_categories = true,
	parent = "Linshao Wu",
}

labels["Linshao Wu"] = {
	region = "much of north-central [[Zhejiang]] Province in eastern [[China]], including especially the central part of the city of [[Shaoxing]] as well as parts of [[Hangzhou]] south of the [[Qiantang]] River.",
	aliases = {"Linshao", "Lin-Shao Wu", "Lin-Shao"},
	Wikidata = "Q7489194", -- article for Shaoxing dialect, the representative variety
	plain_categories = true,
	parent = "Northern Wu",
}

labels["Ningbonese Wu"] = {
	region = "the [[prefecture-level city]] of [[Ningbo]] in northeastern [[Zhejiang]] Province in eastern [[China]]",
	aliases = {"Ningbonese", "Ningbo Wu", "Ningbo", "Ningponese"},
	-- FIXME: Consider removing the following exception and letting it display as 'Ningbonese Wu'.
	display = "Ningbonese",
	Wikidata = "Q3972199",
	plain_categories = true,
	parent = "Yongjiang Wu",
}

labels["Northern Wu"] = {
	region = "the city of [[Shanghai]] as well as southern [[Jiangsu]] Province, northern [[Zhejiang]] Province and southeastern [[Anhui]] Province",
	addl = "It is a primary branch of {{w|Wu Chinese}}. Notable cities where Northern Wu is spoken include [[Shanghai]], [[Suzhou]], [[Hangzhou]], [[Shaoxing]], [[Ningbo]], [[Zhoushan]], [[Wuxi]] and [[Changzhou]].",
	aliases = {"Taihu", "Taihu Wu"},
	Wikidata = "Q7675988",
	plain_categories = true,
	parent = true,
}

-- FIXME: Category missing.
labels["Old Guangde Wu"] = {
	region = "southeastern {{w|Guangde}}, a [[county-level city]] in the southeastern portion of [[Anhui]] Province, bordering northwestern [[Zhejiang]] Province in eastern [[China]]",
	addl = "It is an exclave of {{catlink|Northern Wu}}, surrounded by New Guangde (a {{catlink|Jianghuai Mandarin}} variety) and {{catlink|Xuanzhou Wu}}.",
	aliases = {"Old Guangde", "Southeast Guangde Wu", "Southeast Guangde"},
	Wikidata = "Q7084146",
	plain_categories = true,
	parent = "Tiaoxi Wu",
}

-- FIXME: Category missing.
labels["Old Langxi Wu"] = {
	region = "parts of northern and northwestern {{w|Langxi County}} and northwen {{w|Guangde}}, in southeastern [[Anhui]] Province, in eastern [[China]]",
	aliases = {"Old Langxi", "Lao Langxi Wu", "Lao Langxi"},
	Wikidata = "Q15911930",
	plain_categories = true,
	parent = "Piling Wu",
}

-- FIXME: Category missing.
labels["Piling Wu"] = {
	region = "much of southern [[Jiangsu]] Province (including especially the city of [[Changzhou]]) as well as a few parts of southeastern [[Anhui]] Province, in eastern [[China]]",
	addl = "It is noteworthy for acting as a transitional area between {{catlink|Jianghuai Mandarin}} and Northern Wu.",
	aliases = {"Piling"},
	Wikidata = "Q1021819", -- article for Changzhou dialect
	plain_categories = true,
	parent = "Northern Wu",
}

labels["Shadi Wu"] = {
	region = "[[Chongming]] Island, [[Haimen]] District of the city of [[Nantong]], and the city of {{w|Qidong, Jiangsu|Qidong}} in southeastern [[Jiangsu]] Province in eastern [[China]], as well as in some areas of the city of {{w|Zhangjiagang}}",
	aliases = {"Shadi", "Chongming", "Chongming Wu", "Qihai", "Qihai Wu"},
	Wikidata = "Q6112340",
	plain_categories = true,
	parent = "Sujiahu Wu",
}

-- FIXME: Category missing.
labels["Shanghainese Wu"] = {
	region = "much of [[Shanghai]] in eastern [[China]], including suburban and rural regions",
	addl = "Entries here include terms used in urban Shanghai.",
	aliases = {"Shanghai Wu", "Shanghainese"},
	-- FIXME: Consider removing the following exception and letting it display as 'Shanghainese Wu'.
	display = "Shanghainese",
	Wikidata = "Q36718",
	plain_categories = true,
	parent = "Sujiahu Wu",
}

-- FIXME: Category missing.
labels["Shangyu Wu"] = {
	region = "{{w|Shangyu District}} in northeastern [[Zhejiang]] Province, in eastern [[China]]",
	aliases = {"Shangyu"},
	Wikipedia = "zh:上虞話", -- no Wikidata item yet
	plain_categories = true,
	parent = "Linshao Wu",
}

-- FIXME: Category missing.
labels["Shaoxing Wu"] = {
	region = "the central {{w|Yuecheng District}} of the [[prefecture-level city]] of [[Shaoxing]] in northeastern [[Zhejiang]] Province, in eastern [[China]]",
	aliases = {"Shaoxing", "Shaoxingnese", "Shaoxingnese Wu", "Shaoxingese", "Shaoxingese Wu"},
	Wikidata = "Q7489194",
	plain_categories = true,
	parent = "Linshao Wu",
}

-- FIXME: Category missing.
labels["Shengzhou Wu"] = {
	region = "{{w|Shengzhou}}, a [[county-level city]] in eastern [[Zhejiang]] Province, in eastern [[China]]",
	aliases = {"Shengzhou"},
	Wikidata = "Q11054430",
	plain_categories = true,
	parent = "Linshao Wu",
}

-- FIXME: Category missing.
labels["Songjiang Wu"] = {
	region = "[[Songjiang]] District, a suburban district of [[Shanghai]], in eastern [[China]]",
	aliases = {"Songjiang"},
	Wikidata = "Q662380", -- article for Songjiang district
	plain_categories = true,
	parent = "Shanghainese Wu",
}

-- FIXME: Category missing.
labels["Sujiahu Wu"] = {
	region = "the city of [[Shanghai]] as well as adjacent areas to the north (in southern [[Jiangsu]] Province) and the south (in northern [[Zhejiang]] Province)",
	addl = "It is named after the cities of [[Suzhou]]  (''Su''), [[Jiaxing]] (''Jia'') and [[Shanghai]] (''Hu''). It also encompasses the varieties spoken in [[Wuxi]], [[Changshu]] and [[Nantong]].",
	aliases = {"Sujiahu", "Su-Jia-Hu Wu", "Su-Jia-Hu", "Suhujia Wu", "Suhujia", "Su-Hu-Jia Wu", "Su-Hu-Jia"}, -- not Suzhou-Jiaxing-Huzhou
	Wikidata = "Q17036256",
	-- display = "[[w:Suzhou dialect|Su]][[w:zh:嘉興話|jia]][[w:Shanghainese|hu]] [[w:Wu Chinese|Wu]]",
	plain_categories = true,
	parent = "Northern Wu",
}

labels["Suzhounese Wu"] = {
	region = "the city of [[Suzhou]] and adjacent parts of southeastern [[Jiangsu]] Province and parts of [[Shanghai]], in eastern [[China]]",
	aliases = {"Suzhou", "Suzhounese", "Suzhou Wu"},
	-- FIXME: Consider removing the following exception and letting it display as 'Suzhounese Wu'.
	display = "Suzhounese",
	Wikidata = "Q831744",
	plain_categories = true,
	parent = "Sujiahu Wu",
}

-- FIXME: Category missing.
labels["Tiaoxi Wu"] = {
	region = "nearly all of the [[prefecture-level city]] of [[Huzhou]] in northwestern [[Zhejiang]] Province in eastern [[China]], as well as parts of [[Jiaxing]], [[Hangzhou]] (in [[Zhejiang]] Province) and [[Suzhou]] (in [[Jiangsu]] Province)",
	aliases = {"Tiaoxi"},
	Wikidata = "Q110104620",
	plain_categories = true,
	parent = "Northern Wu",
}

-- FIXME: Category missing.
labels["Tonglu Wu"] = {
	region = "{{w|Tonglu County}} in northwestern [[Zhejiang]] Province, in eastern [[China]]",
	aliases = {"Tonglu"},
	Wikidata = "Q18654008",
	plain_categories = true,
	parent = "Linshao Wu",
}

-- FIXME: Category missing.
labels["Tongxiang Wu"] = {
	region = "{{w|Tongxiang}}, a [[county-level city]] in northern [[Zhejiang]] Province, bordering [[Jiangsu]] Province to the north, in eastern [[China]]",
	aliases = {"Tongxiang", "Tongxiang dialect"},
	Wikidata = "Q1204548", -- article for Tongxiang prefecture
	plain_categories = true,
	parent = "Tiaoxi Wu",
}

-- FIXME: Category missing.
labels["Urban Shanghainese Wu"] = {
	region = "the city center of [[Shanghai]] in eastern [[China]]; generally on the west bank of the [[Huangpu]] River in the area known as [[Puxi]]",
	addl = "Urban Shanghainese is changing rapidly and can be further subdivided into Old, Middle, New and Newest periods.",
	aliases = {"Urban Shanghai Wu", "Urban Shanghainese", "Urban Shanghai"},
	Wikipedia = "Shanghainese#Classification",
	plain_categories = true,
	parent = "Shanghainese Wu",
}

-- FIXME: Category missing.
labels["Wuxi Wu"] = {
	region = "the city of [[Wuxi]] in southern [[Jiangsu]] Province in eastern [[China]]",
	aliases = {"Wuxi"},
	Wikidata = "Q2325035",
	plain_categories = true,
	parent = "Sujiahu Wu",
}

-- FIXME: Category missing.
labels["Xiaoshan Wu"] = {
	region = "{{w|Xiaoshan District}}, an urban district of [[Hangzhou]] in northwestern [[Zhejiang]] Province in eastern [[China]], and in the village of Jiangdong in {{w|Qiantang District}} of [[Hangzhou]]",
	aliases = {"Xiaoshan"},
	Wikidata = "Q60993472",
	plain_categories = true,
	parent = "Linshao Wu",
}

-- FIXME: Category missing.
labels["Xinchang Wu"] = {
	region = "{{w|Xinchang County}} in east-central [[Zhejiang]] Province, in eastern [[China]]",
	aliases = {"Xinchang"},
	Wikidata = "Q11082821",
	plain_categories = true,
	parent = "Linshao Wu",
}

-- FIXME: Category missing.
labels["Yixing Wu"] = {
	region = "the [[county-level city]] of {{w|Yixing}} in southern [[Jiangsu]] Province in eastern [[China]]",
	aliases = {"Yixing"},
	Wikipedia = "zh:宜興話", -- no Wikidata item yet
	plain_categories = true,
	parent = "Piling Wu",
}

-- FIXME: Category missing.
labels["Yongjiang Wu"] = {
	region = "most areas of the [[prefecture-level city]] of [[Ningbo]] as well as the entire [[Zhoushan]] archipelago, in northeastern [[Zhejiang]] Province in eastern [[China]]",
	aliases = {"Yongjiang"},
	Wikidata = "Q15503785",
	plain_categories = true,
	parent = "Northern Wu",
}

-- FIXME: Category missing.
labels["Yuhang Wu"] = {
	region = "{{w|Yuhang District}} of the city of [[Hangzhou]], the capital of [[Zhejiang]] Province in eastern [[China]]",
	aliases = {"Yuhang"},
	Wikidata = "Q109414979",
	plain_categories = true,
	parent = "Tiaoxi Wu",
}

-- FIXME: Category missing.
labels["Zhoushan Wu"] = {
	region = "the [[Zhoushan]] archipelago in northeastern [[Zhejiang]] Province in eastern [[China]]",
	aliases = {"Zhoushan"},
	Wikidata = "Q58324", -- article on the prefecture-level city of Zhoushan
	plain_categories = true,
	parent = "Yongjiang Wu",
}

-- FIXME: Category missing.
labels["Zhuji Wu"] = {
	region = "{{w|Zhuji}}, a [[county-level city]] in north-central [[Zhejiang]] Province, in eastern [[China]]",
	aliases = {"Zhuji"},
	Wikidata = "Q18119187",
	plain_categories = true,
	parent = "Linshao Wu",
}

---------------------- Southern Wu ----------------------

-- FIXME: Category missing.
labels["Baizhang Wu"] = {
	region = "{{w|lang=zh|百丈镇_(泰顺县)|Baizhang Township}} in [[Taishun]] County in southern [[Zhejiang]] Province, in eastern [[China]]",
	addl = "It is a [[dialect island]] surrounded by {{catlink|Jujiang Wu}} speakers and is increasingly endangered, with less than 1,000 speakers remaining.",
	aliases = {"Baizhang", "Xialu Wu", "Xialu"},
	Wikipedia = "zh:百丈口话", -- no Wikidata item yet
	plain_categories = true,
	parent = "Oujiang Wu",
}

-- FIXME: Category missing.
labels["Changbei Wu"] = {
	region = "{{w|Lin'an District}} (formerly the northern part of {{w|lang=zh|昌化县_(浙江省)|Changhua County}}, hence the name) in [[Hangzhou]], the capital of [[Zhejiang]] Province in the northern part, in eastern [[China]]",
	addl = "It is a divergent subvariety of {{catlink|Xuanzhou Wu}} with significant vocabulary influences from the {{w|Jixi County}} variety of {{w|Huizhou Chinese}} and from Mandarin.",
	aliases = {"Changbei"},
	Wikipedia = "zh:昌北话", -- no Wikidata item yet
	plain_categories = true,
	parent = "Xuanzhou Wu", -- per zhwiki, in the Taigao Wu cluster
}

-- FIXME: Category missing.
labels["Chuqu Wu"] = {
	region = "the [[prefecture-level city|prefecture-level cities]] of [[Quzhou]] and [[Lishui]] in southwestern [[Zhejiang]] Province in eastern [[China]]; some parts of southern [[Wenzhou]] in southern Zhejiang; [[Shangrao]] and [[Yushan]] Counties in northeastern {{w|Jiangxi}} Province, bordering [[Zhejiang]]; and the northern part of the [[prefecture-level city|prefecture-level cities]] of [[Ningde]] and [[Nanping]] in northern [[Fujian]] Province, bordering [[Zhejiang]]",
	addl = "It is a primary branch of Wu Chinese and is named after the component lects {{catlink|Quzhou Wu}} (spoken in [[Quzhou]]) and {{catlink|Chuzhou Wu}} (spoken in [[Lishui]]).",
	aliases = {"Chuqu"},
	Wikidata = "Q5116499",
	plain_categories = true,
	parent = "Southern Wu",
}

-- FIXME: Category missing.
labels["Chuzhou Wu"] = {
	region = "the [[prefecture-level city]] of [[Lishui]] in southwestern [[Zhejiang]] Province and {{w|Wuyi County}} to the north, as well as {{w|Pucheng County, Fujian|Pucheng County}} in far northern [[Fujian]] Province",
	addl = "It is named after the historical {{m|zh|處州|tr=Chǔzhōu}} Prefecture (see {{w|lang=zh|處州}}), which largely coincided with the modern-day boundaries of Lishui.",
	aliases = {"Chuzhou"},
	-- Undefined in Chinese Wikipedia
	plain_categories = true,
	parent = "Chuqu Wu",
}

-- FIXME: Category missing.
labels["Dongyang Wu"] = {
	region = "the [[county-level city]] of {{w|Dongyang}} in central [[Zhejiang]] Province in eastern [[China]]",
	aliases = {"Dongyang"},
	Wikidata = "Q109417928",
	plain_categories = true,
	parent = "Wuzhou Wu", -- per zhwiki, in the Yiyong Wu cluster
}

-- FIXME: Category missing.
labels["Duze Wu"] = {
	region = "{{w|Qujiang, Quzhou|Qujiang District}} of the city of [[Quzhou]] in western [[Zhejiang]] Province in eastern [[China]]",
	addl = "It is named after the town of Duze ({{m|zh|杜泽}}).",
	aliases = {"Duze"},
	Wikipedia = "zh:杜泽话", -- no Wikidata item yet
	plain_categories = true,
	parent = "Longqu Wu", -- a variety of Chuqu Wu
}

-- FIXME: Category missing.
labels["Gaochun Wu"] = {
	region = "{{w|Gaochun District}} in southernmost [[Nanjing]] in southwestern [[Jiangsu]] Province in eastern [[China]]",
	aliases = {"Gaochun"},
	Wikidata = "Q17035529",
	plain_categories = true,
	parent = "Xuanzhou Wu", -- per zhwiki, in the Taigao Wu cluster
}

-- FIXME: Category missing.
labels["Hongqiao Wu"] = {
	region = "central [[Yueqing]] in southeastern [[Zhejiang]] Province in eastern [[China]]",
	aliases = {"Hongqiao"},
	Wikidata = "Q15933359",
	plain_categories = true,
	parent = "Oujiang Wu",
}

-- FIXME: Category missing.
labels["Hou'an Wu"] = {
	region = "the western countryside of {{w|Jing County, Anhui|Jing County}} (including, for example, the town of {{w|Taohuatan}}) in southern [[Anhui]] Province in eastern [[China]]",
	aliases = {"Hou'an"},
	Wikidata = "Q10911034",
	plain_categories = true,
	parent = "Xuanzhou Wu", -- per zhwiki, in the Shiling Wu cluster
}

-- FIXME: Category missing.
labels["Jiangshan Wu"] = {
	region = "{{w|Jiangshan}}, a [[county-level city]] in western [[Zhejiang]] Province in eastern [[China]]",
	aliases = {"Jiangshan"},
	Wikidata = "Q6112693",
	plain_categories = true,
	parent = "Shangshan Wu", -- a variety of Chuqu Wu
}

-- FIXME: Category missing.
labels["Jingxian Wu"] = {
	region = "rural parts of {{w|Jing County, Anhui|Jing County}} (including, for example, the town of {{w|lang=zh|茂林镇_(泾县)|Maolin}}) in southern [[Anhui]] Province in eastern [[China]]",
	addl = "The majority of Jing County speaks {{catlink|Jianghuai Mandarin}}, while the western countryside instead speaks {{catlink|Hou'an Wu}}.",
	aliases = {"Jingxian"},
	Wikidata = "Q11151690",
	plain_categories = true,
	parent = "Xuanzhou Wu", -- per zhwiki, in the Tongjing Wu cluster
}

-- One of the clusters (xiǎopiàn) of Wuzhou Wu, which aren't well-established.
---- FIXME: Category missing.
--labels["Jinlan Wu"] = {
--	aliases = {"Jinlan"},
--	-- Undefined in Chinese Wikipedia
--	plain_categories = true,
--	parent = "Wuzhou Wu",
--}

-- FIXME: Category missing.
labels["Jinhua Wu"] = {
	region = "[[Jinhua]] (especially the eastern {{w|Wucheng District|Wucheng}} and {{w|Jindong District|Jindong}} Districts), in central [[Zhejiang]] Province in eastern [[China]]",
	aliases = {"Jinhua", "Jinhuanese", "Jinhuanese Wu"},
	Wikidata = "Q13583347",
	plain_categories = true,
	parent = "Wuzhou Wu", -- per zhwiki, in the Jinlan Wu cluster
}

-- FIXME: Category missing.
labels["Jiuhua Wu"] = {
	region = "{{w|lang=zh|九华乡_(衢州市)|Jiuhua Township}} in {{w|Kecheng District}} in [[Quzhou]] in western [[Zhejiang]] Province in eastern [[China]]",
	aliases = {"Jiuhua"},
	Wikipedia = "zh:九华话", -- no Wikidata item yet
	plain_categories = true,
	parent = "Longqu Wu", -- a variety of Chuqu Wu
}

-- FIXME: Category missing.
labels["Jujiang Wu"] = {
	region = "northeastern {{w|Taishun County}} in far southern [[Zhejiang]] Province in eastern [[China]]",
	addl = "It has characteristics of both {{catlink|Oujiang Wu}} and {{catlink|Chuqu Wu}} and is only provisionally assigned to Oujiang Wu.",
	aliases = {"Jujiang"},
	Wikipedia = "zh:莒江话", -- no Wikidata item yet
	plain_categories = true,
	parent = "Oujiang Wu", -- possibly? also has characteristics of Chuqu Wu
}

-- FIXME: Category missing.
labels["Lanxi Wu"] = {
	region = "urban [[Lanxi]], a [[county-level city]] in west-central [[Zhejiang]] Province in eastern [[China]]",
	aliases = {"Lanxi"},
	Wikidata = "Q17059873",
	plain_categories = true,
	parent = "Wuzhou Wu", -- per zhwiki, in the Jinlan Wu cluster
}

-- FIXME: Category missing.
labels["Lishui Wu"] = {
	-- NOTE: Chuzhou was a historical administrative division that includes modern day Lishui & Wuyi,
	-- and is a proposed top-level division of Wu. Pucheng, Fujian is majority Wu-speaking.
	region = "parts of the [[prefecture-level city]] of [[Lishui]] in southern [[Zhejiang]] Province in eastern [[China]], including the central {{w|Liandu, Lishui|Liandu District}}, {{w|Jingning She Autonomous County}}, {{w|Qingtian County}} and {{w|Yunhe County}}",
	aliases = {"Lishui", "Lishuinese"},
	Wikidata = "Q58294", -- article on the prefecture-level city of Lishui in Zhejiang
	plain_categories = true,
	parent = "Chuzhou Wu", -- a variety of Chuqu Wu
}

-- FIXME: Category missing.
labels["Longqu Wu"] = {
	region = "{{w|Kecheng District}}, {{w|Qujiang District}} and {{w|Longyou County}}, in the [[prefecture-level city]] of [[Quzhou]] in southwestern [[Zhejiang]] Province in eastern [[China]]",
	aliases = {"Longqu"},
	Wikipedia = "zh:龙衢小片", -- no Wikidata item yet
	plain_categories = true,
	parent = "Chuqu Wu",
}

-- FIXME: Category missing.
labels["Longyou Wu"] = {
	region = "{{w|Longyou County}} in west-central [[Zhejiang]] Province in eastern [[China]]",
	aliases = {"Longyou"},
	Wikidata = "Q15908274",
	plain_categories = true,
	parent = "Longqu Wu", -- a variety of Chuqu Wu
}

-- FIXME: Category missing.
labels["Nanji Wu"] = {
	region = "{{w|lang=zh|南极乡|Nanji Township}} and nearby areas, in the [[county-level city]] of {{w|Ningguo}} in southeastern [[Anhui]] Province in eastern [[China]]",
	aliases = {"Nanji"},
	Wikidata = "Q10908223",
	plain_categories = true,
	parent = "Xuanzhou Wu", -- per zhwiki, in the Taigao Wu cluster
}

-- One of the clusters (xiǎopiàn) of Taizhou Wu, which aren't well-established.
---- FIXME: Category missing.
--labels["Nantai Wu"] = {
--	aliases = {"Nantai"},
--	-- Undefined in Chinese Wikipedia
--	plain_categories = true,
--	parent = "Taizhou Wu",
--}

-- FIXME: Category missing.
labels["Old Xuanzhou Wu"] = {
	region = "parts of northern, western and southern {{w|Xuanzhou District}} (e.g. the town of {{w|lang=zh|溪口镇 (宣城市)|Xikou}}) in the [[prefecture-level city]] of [[Xuancheng]] in southeastern [[Anhui]] Province in eastern [[China]]",
	addl = "This variety only remains in certain scattered parts of Xuanzhou District, which is majority {{catlink|Jianghuai Mandarin}}-speaking.",
	aliases = {"Old Xuanzhou"},
	Wikidata = "Q15914865",
	plain_categories = true,
	parent = "Xuanzhou Wu", -- per zhwiki, in the Tongjing Wu cluster
}

-- FIXME: Category missing.
labels["Oujiang Wu"] = {
	-- A primary branch.
	region = "the lower reaches of the {{w|Oujiang River|Oujiang}}, {{w|Feiyun River|Feiyun}} and {{w|Aojiang River}} basins in the [[prefecture-level city]] of [[Wenzhou]] in southeastern [[Zhejiang]] Province in eastern [[China]], as well as in some towns in [[Lishui]] and [[Taizhou]]",
	addl = "It is a primary branch of Wu Chinese.",
	aliases = {"Oujiang"},
	Wikidata = "Q710218", -- article for Wenzhounese
	plain_categories = true,
	parent = "Southern Wu",
}

-- FIXME: Category missing.
labels["Pan'an Wu"] = {
	region = "{{w|Pan'an County}} in central [[Zhejiang]] Province in eastern [[China]]",
	aliases = {"Yiwu"},
	Wikidata = "Q55695855",
	plain_categories = true,
	parent = "Wuzhou Wu", -- per zhwiki, in the Yiyong Wu cluster
}

-- FIXME: Category missing.
labels["Pucheng Oujiang Wu"] = {
	region = "four villages in the walled {{w|lang=zh|蒲壮所城|Puzhuangsuo City}} in Pucheng Township, {{w|Cangnan County}} in the southernmost part of the [[prefecture-level city]] of [[Wenzhou]] in southeastern [[Zhejiang]] Province in eastern [[China]]",
	addl = "It is a dialect island of Wu Chinese surrounded by {{w|Zhenan Min}} speakers, and is not to be confused with {{catlink|Pucheng Wu}}, a variety of {{catlink|Chuqu Wu}} (rather than {{catlink|Oujiang Wu}}) spoken in a different Pucheng ({{w|Pucheng County, Fujian|Pucheng County}} in [[Fujian]] Province).",
	aliases = {"Pucheng Ou", "Pucheng Auish"},
	Wikipedia = "zh:蒲城瓯语", -- no Wikidata item yet
	plain_categories = true,
	parent = "Oujiang Wu",
}

-- FIXME: Category missing.
labels["Pucheng Wu"] = {
	-- no "Pucheng" alias because per Wikipedia, Northern Min (Shibei dialect) is also spoken
	region = "the northern part of {{w|Pucheng County, Fujian|Pucheng County}} in far northern [[Fujian]] Province, bordering [[Zhejiang]] Province, in eastern [[China]]",
	addl = "Not to be confused with {{catlink|Pucheng Oujiang Wu}}, a variety of {{catlink|Oujiang Wu}} (rather than {{catlink|Chuqu Wu}}) spoken in a different Pucheng (Pucheng Township, {{w|Cangnan County}}, in [[Zhejiang]] Province).",
	Wikipedia = "zh:浦城话", -- no Wikidata item yet
	Wikidata = "Q1338032", -- article on Pucheng County, Fujian
	plain_categories = true,
	parent = "Chuzhou Wu", -- a variety of Chuqu Wu
}

-- FIXME: Category missing.
labels["Qingtian Wu"] = {
	region = "{{w|Qingtian County}} in southeastern [[Zhejiang]] Province in eastern [[China]]",
	aliases = {"Qingtian"},
	Wikidata = "Q2074456",
	plain_categories = true,
	parent = "Chuzhou Wu", -- a variety of Chuqu Wu
}

-- FIXME: Category missing.
labels["Quzhou Wu"] = {
	region = "[[Quzhou]] in southwestern [[Zhejiang]] Province in eastern [[China]]",
	aliases = {"Quzhou", "Quzhounese", "Quzhounese Wu"},
	Wikidata = "Q6112429",
	Wikipedia = "zh:处衢片", -- no Wikidata item for this and not connected to Q6112429
	plain_categories = true,
	parent = "Longqu Wu", -- a variety of Chuqu Wu
}

-- FIXME: Category missing.
labels["Rui'an Wu"] = {
	region = "the [[county-level city]] of [[Rui'an]] in southeastern [[Zhejiang]] Province in eastern [[China]]",
	aliases = {"Rui'an"},
	Wikidata = "Q4415352",
	plain_categories = true,
	parent = "Oujiang Wu",
}

-- FIXME: Category missing.
labels["Shangrao Wu"] = {
	region = "{{w|Yushan County}} and {{w|Guangfeng District}} of the [[prefecture-level city]] of [[Shangrao]] in northeastern [[Jiangxi]] Province",
	aliases = {"Shangrao", "Shangraonese", "Shangraonese Wu"},
	Wikidata = "Q363479", -- Shangrao, a prefecture-level city in Jiangxi
	plain_categories = true,
	parent = "Shangshan Wu", -- a variety of Chuqu Wu
}

-- FIXME: Category missing.
labels["Shangshan Wu"] = {
	region = "parts of western [[Zhejiang]] Province and northeastern [[Jiangxi]] Province in eastern [[China]], including the [[county-level city]] of {{w|Jiangshan}}, {{w|Changshan County}} and {{w|Kaihua County}} in the [[prefecture-level city]] of [[Quzhou]]; {{w|Suichang County|Suichang}}, {{w|Songyang County|Songyang}} and {{w|Qingyuan County, Zhejiang|Qingyuan Counties}} and the [[county-level city]] of {{w|Longquan}} in the prefecture-level city of [[Lishui]]; and {{w|Yushan County}} and {{w|Guangfeng District}} in the [[prefecture-level city]] of [[Shangrao]]",
	aliases = {"Shangshan"},
	-- Undefined in Chinese Wikipedia
	plain_categories = true,
	parent = "Chuqu Wu",
}

-- One of the clusters (xiǎopiàn) of Xuanzhou Wu, which aren't well-established.
---- FIXME: Category missing.
--labels["Shiling Wu"] = {
--	aliases = {"Shiling"},
--	Wikidata = "Q15923670",
--	plain_categories = true,
--	parent = "Xuanzhou Wu",
--}

labels["Southern Wu"] = {
	Wikipedia = "Wu Chinese#Southern Wu",
	plain_categories = true,
}

-- One of the clusters (xiǎopiàn) of Xuanzhou Wu, which aren't well-established.
---- FIXME: Category missing.
--labels["Taigao Wu"] = {
--	aliases = {"Taigao"},
--	Wikipedia = "zh:宣州片#太高小片",
--	plain_categories = true,
--	parent = "Xuanzhou Wu",
--}

-- FIXME: Category missing.
labels["Taiping Wu"] = {
	region = "the eastern and southern countryside of {{w|Huangshan District}} (the former {{w|lang=zh|太平县_(安徽省)|Taiping County}}) in the northern part of the [[prefecture-level city]] of [[Huangshan]] in southern [[Anhui]] Province in eastern [[China]]",
	aliases = {"Taiping", "Old Taiping Wu", "Old Taiping"},
	Wikidata = "Q10941478",
	plain_categories = true,
	parent = "Xuanzhou Wu", -- per zhwiki, in the Taigao Wu cluster
}


-- Per [[User:ND381]], there is not a single Urban Taizhou Wu lect. Who knows, then, what Wikidata item Q3972406
-- ([[w:Taizhou dialect]]) corresponds to, if anything.
-- -- FIXME: Category missing.
--labels["Urban Taizhou Wu"] = {
--	aliases = {"Urban Taizhou"},
--	Wikidata = "Q3972406",
--	plain_categories = true,
--	parent = "Nantai Wu", -- a variety of Taizhou Wu
--}

-- FIXME: Category missing.
labels["Taizhou Wu"] = {
	-- A primary branch. Called "Taizhou Wu" in Wikipedia, distinct from "Taizhou dialect"; but these names are too
	-- ambiguous. We have provisionally adopted "Taizhou Wu" for the larger group and "Urban Taizhou Wu" for the dialect
	-- of the urban area of Taizhou city. Per English Wikipedia, has the following varieties:
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
	region = "the [[prefecture-level city]] of [[Taizhou]] and environs, in eastern [[Zhejiang]] Province in eastern [[China]]",
	addl = "It is a primary branch of Wu Chinese.",
	aliases = {"Taizhou"},
	Wikidata = "Q7676678",
	plain_categories = true,
	parent = "Southern Wu",
}

-- FIXME: Category missing.
labels["Tangxi Wu"] = {
	region = "the western part of {{w|Wucheng District}} in [[Jinhua]] in central [[Zhejiang]] Province in eastern [[China]] (including the town of {{w|Tangxi, Jinhua|Tangxi}}), as well as in the southwest corner of the [[county-level city]] of {{w|Lanxi, Zhejiang|Lanxi}}",
	aliases = {"Tangxi"},
	Wikidata = "Q11136233",
	plain_categories = true,
	parent = "Wuzhou Wu",
}

-- FIXME: Category missing.
labels["Tiantai Wu"] = {
	region = "{{w|Tiantai County}} in eastern [[Zhejiang]] in eastern [[China]]",
	aliases = {"Tiantai"},
	Wikidata = "Q85809509",
	plain_categories = true,
	parent = "Taizhou Wu", -- per zhwiki, in the Beitai Wu cluster
}

-- One of the clusters (xiǎopiàn) of Xuanzhou Wu, which aren't well-established.
---- FIXME: Category missing.
--labels["Tongjing Wu"] = {
--	aliases = {"Tongjing"},
--	Wikidata = "Q17028746",
--	plain_categories = true,
--	parent = "Xuanzhou Wu",
--}

-- FIXME: Category missing.
labels["Tongling Wu"] = {
	region = "the urban area of the [[prefecture-level city]] of [[Tongling]] in southern [[Anhui]] Province in eastern [[China]], and in suburban {{w|lang=zh|大通镇_(郊区)|Datong Town}}", 
	aliases = {"Tongling"},
	Wikidata = "Q15909611",
	plain_categories = true,
	parent = "Xuanzhou Wu", -- per zhwiki, in the Tongjing Wu cluster
}

-- FIXME: Category missing.
labels["Wencheng Wu"] = {
	region = "{{w|Wencheng County}} in the southwestern part of the [[prefecture-level city]] of [[Wenzhou]] in southern [[Zhejiang]] Province in eastern [[China]]",
	aliases = {"Wencheng"},
	Wikidata = "Q7982335",
	plain_categories = true,
	parent = "Oujiang Wu",
}

labels["Wenzhounese Wu"] = {
	region = "urban {{w|Lucheng, Wenzhou|Lucheng District}} in the [[prefecture-level city]] of [[Wenzhou]] in southeastern [[Zhejiang]] Province in eastern [[China]]",
	aliases = {"Wenzhounese", "Wenzhou Wu", "Wenzhou"},
	-- FIXME: Consider removing the following exception and letting it display as 'Wenzhounese Wu'.
	display = "Wenzhounese",
	Wikidata = "Q710218",
	plain_categories = true,
	parent = "Oujiang Wu",
}

-- FIXME: Category missing.
labels["Wuhu Wu"] = {
	-- Jianghuai Mandarin is also spoken in the city of Wuhu.
	region = "the former {{w|Wuhu County}} (now {{w|Wanzhi District}}) in the [[prefecture-level city]] of [[Wuhu]] in southeastern [[Anhui]] Province in eastern [[China]]",
	aliases = {"Wuhu County", "Wuhu County Wu"},
	Wikidata = "Q15911448",
	plain_categories = true,
	parent = "Xuanzhou Wu", -- per zhwiki, in the Tongjing Wu cluster
}

-- FIXME: Category missing.
labels["Wuyi Wu"] = {
	region = "the northern part of {{w|Wuyi County, Zhejiang|Wuyi County}} in central [[Zhejiang]] Province in eastern [[China]]",
	aliases = {"Wuyi"},
	Wikidata = "Q11124837",
	plain_categories = true,
	parent = "Wuzhou Wu", -- per zhwiki, in the Yiyong Wu cluster
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
	region = "the [[prefecture-level city]] of [[Jinhua]] and environs, in central [[Zhejiang]] Province in eastern [[China]]",
	addl = "It is a primary branch of Wu Chinese.",
	aliases = {"Wuzhou"},
	Wikidata = "Q2779891",
	plain_categories = true,
	parent = "Southern Wu",
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
	region = "the [[prefecture-level city]] of [[Xuancheng]] and environs, in southeastern [[Anhui]] Province in eastern [[China]]",
	addl = "It is a primary branch of Wu Chinese.",
	aliases = {"Xuanzhou"},
	Wikidata = "Q1939756",
	plain_categories = true,
	parent = true,
}

-- FIXME: Category missing.
labels["Yiwu Wu"] = {
	region = "the [[county-level city]] of [[Yiwu]] in central [[Zhejiang]] Province in eastern [[China]]",
	aliases = {"Yiwu"},
	Wikidata = "Q15898526",
	plain_categories = true,
	parent = "Wuzhou Wu", -- per zhwiki, in the Yiyong Wu cluster
}

-- One of the clusters (xiǎopiàn) of Wuzhou Wu, which aren't well-established.
---- FIXME: Category missing.
--labels["Yiyong Wu"] = {
--	aliases = {"Yiyong"},
--	-- Undefined in Chinese Wikipedia
--	plain_categories = true,
--	parent = "Wuzhou Wu",
--}

-- FIXME: Category missing.
labels["Yongkang Wu"] = {
	region = "the [[county-level city]] of {{w|Yongkang}} in central [[Zhejiang]] Province in eastern [[China]]",
	aliases = {"Yongkang"},
	Wikidata = "Q11132026",
	plain_categories = true,
	parent = "Wuzhou Wu", -- per zhwiki, in the Yiyong Wu cluster
}

-- FIXME: Category missing.
labels["Yushan Wu"] = {
	region = "{{w|Yushan County}} in northeastern [[Jiangxi]] Province in eastern [[China]]",
	aliases = {"Yushan"},
	Wikidata = "Q17040715",
	plain_categories = true,
	parent = "Shangshan Wu", -- a variety of Chuqu Wu
}

------------------------------------------ Xiang ------------------------------------------

labels["Xiang"] = {
	Wikidata = "Q13220",
	regional_categories = true,
}

labels["dialectal Xiang"] = {
	Wikidata = "Q13220", -- article on Xiang Chinese
	regional_categories = "Xiang",
}

-- FIXME: Category missing.
labels["Changsha Xiang"] = {
	aliases = {"Changsha"},
	Wikidata = "Q3044809",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Hengyang Xiang"] = {
	aliases = {"Hengyang"},
	Wikidata = "Q20689035",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["Hengzhou Xiang"] = {
	aliases = {"Hengzhou"},
	Wikidata = "Q20689035", -- article on Hengyang Xiang
	plain_categories = true,
}

labels["Loudi Xiang"] = {
	aliases = {"Loudi"},
	Wikidata = "Q10943823",
	plain_categories = true,
}

-- FIXME: Category missing.
labels["New Xiang"] = {
	Wikidata = "Q7012696",
	plain_categories = true,
}

labels["Old Xiang"] = {
	Wikidata = "Q7085453",
	plain_categories = true,
}

labels["Shuangfeng Xiang"] = {
	aliases = {"Shuangfeng"},
	Wikidata = "Q10911980",
	plain_categories = true,
}

------------------------------------------ Yue ------------------------------------------

labels["Cantonese"] = {
	-- A variety of Yuehai Yue.
	Wikidata = "Q9186",
	regional_categories = true,
}

labels["dialectal Cantonese"] = {
	Wikidata = "Q9186", -- article on Cantonese
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
	parent = true,
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
	parent = true,
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
	parent = "non-Mainland Cantonese",
	othercat = "Hong Kong Chinese",
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
	parent = true,
}

-- FIXME: Category missing.
labels["Macau Cantonese"] = {
	-- A subvariety of Cantonese (in the narrow sense), a variety of Yuehai Yue.
	aliases = {"Macao Cantonese", "Macanese Cantonese"},
	Wikidata = "Q113659847",
	plain_categories = true,
	parent = "non-Mainland Cantonese",
	othercat = "Macau Chinese",
}

-- FIXME: Category missing.
labels["Malaysian Cantonese"] = {
	-- A subvariety of Cantonese (in the narrow sense), a variety of Yuehai Yue.
	aliases = {"Malaysia Cantonese"},
	Wikidata = "Q56272241",
	parent = "Southeast Asian Cantonese",
	othercat = "Malaysian Chinese",
}

-- FIXME: Category missing.
labels["Nantou Cantonese"] = {
	-- A subvariety of Guanbao Cantonese, which is a variety of Yuehai Yue (the primary branch that includes standard
	-- Cantonese). Formerly spoken by residents of [[w:Nantou (historic town)]], a former walled city in Shenzhen.
	aliases = {"Nantou Yue"}, -- no "Nantou" alias because Nantou is also a city in Taiwan
	Wikidata = "Q110110348",
	plain_categories = true,
}

labels["non-Mainland Cantonese"] = {
	prep = "by",
	region = "ethnic Chinese outside of [[mainland China]], including in [[Hong Kong]] and [[Macau]] due to their special history",
	display = "non-[[w:Mainland China|Mainland]] [[w:Cantonese Chinese|Cantonese]]",
	aliases = {"Non-Mainland Cantonese", "non-mainland Cantonese"},
	plain_categories = true,
	parent = true,
	othercat = "non-Mainland Chinese",
}

labels["Overseas Cantonese"] = {
	prep = "outside of",
	region = "[[mainland China]], [[Taiwan]], [[Hong Kong]] and [[Macau]]",
	Wikipedia = "Cantonese people#19th–20th century: Turmoil and migration",
	plain_categories = true,
	parent = "non-Mainland Cantonese",
	othercat = "Overseas Chinese",
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
	parent = true,
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
	parent = "Southeast Asian Cantonese",
	othercat = "Singapore Chinese",
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
	parent = true,
}

labels["Southeast Asian Cantonese"] = {
	region = "[[Southeast Asia]], stretching from [[Myanmar]] ([[Burma]]) in the northwest, to the [[Philippines]] in the northeast, to [[Indonesia]] in the south",
	Wikipedia = {"Cantonese people#19th–20th century: Turmoil and migration", "Southeast Asia"},
	plain_categories = true,
	parent = "Overseas Cantonese",
	othercat = "Southeast Asian Chinese",
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
	parent = true,
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
	-- A primary branch, or possibly a subvariety of Yuehai Yue (Cantonese proper).
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
	parent = true,
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
	parent = true,
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
	Wikidata = "Q2578935",
	plain_categories = true,
}

labels["Dungan"] = {
	Wikidata = "Q33050",
	regional_categories = true,
}

labels["Gansu Dungan"] = {
	display = "[[Gansu]] [[w:Dungan language|Dungan]]",
	plain_categories = true,
}

labels["Huizhou"] = {
	aliases = {"Huizhou Chinese"},
	Wikidata = "Q56546",
	regional_categories = true,
}

labels["Shehua"] = {
	aliases = {"She Chinese", "She"},
	Wikidata = "Q24841605",
	regional_categories = true,
}

labels["Waxiang"] = {
	Wikidata = "Q2252191",
	regional_categories = true,
}

------------------------------------------ Miscellaneous ------------------------------------------

labels["American (&ndash;1980)"] = {
	aliases = {"America 1", "United States 1", "USA 1", "US 1"},
	Wikidata = "Q1516704", -- article on History of Chinese Americans
	regional_categories = true,
	parent = "US",
}

labels["American (1980&ndash;)"] = {
	aliases = {"America 2", "United States 2", "USA 2", "US 2"},
	Wikidata = "Q1516704", -- article on History of Chinese Americans
	regional_categories = true,
	parent = "US",
}

labels["North America"] = {
	aliases = {"North American"},
	display = "[[Canada]], [[American English|US]]",
	regional_categories = {"Canadian", "American"},
	parent = "Overseas",
}

-- the remaining labels moved from [[Module:labels/data/regional]]

labels["Australia"] = {
	aliases = {"AU", "Australian"},
	Wikipedia = "Chinese Australians",
	regional_categories = "Australian",
	parent = "Overseas",
}

labels["Britain"] = {
	aliases = {"Brit", "British", "Great Britain"},
	Wikipedia = "British Chinese",
	regional_categories = "British",
	parent = "Overseas",
}

labels["UK"] = {
	aliases = {"United Kingdom"},
	Wikipedia = "British Chinese",
	regional_categories = "British",
	parent = "Overseas",
}

labels["Brunei"] = {
	Wikipedia = "Ethnic Chinese in Brunei",
	regional_categories = "Bruneian",
	parent = "Southeast Asia",
}

labels["Canada"] = {
	aliases = {"Canadian"},
	Wikipedia = "Chinese Canadians",
	regional_categories = {"Canadian"},
	parent_label = "North America",
}

labels["Classical"] = {
	noreg = true,
	aliases = {"classical"},
	Wikipedia = "Classical Chinese",
	regional_categories = true,
}

labels["Cuba"] = {
	aliases = {"Cuban"},
	Wikipedia = "Chinese Cubans",
	regional_categories = "Cuban",
	parent = "Overseas",
}

labels["France"] = {
	aliases = {"French"},
	Wikipedia = "Chinese diaspora in France",
	regional_categories = "French",
	parent = "Overseas",
}

labels["Hong Kong"] = {
	Wikipedia = "Hong Kong Chinese",
	regional_categories = true,
	parent = "non-Mainland",
}

labels["Indonesia"] = {
	aliases = {"Indonesian"},
	Wikipedia = {"Language and overseas Chinese communities#Indonesia", "Chinese Indonesians"},
	regional_categories = "Indonesian",
	parent = "Southeast Asia",
}

labels["Japan"] = {
	langs = {"en", "ru", "zh"},
	Wikipedia = "Chinese people in Japan",
	regional_categories = "Japanese",
	parent = "Overseas",
}

labels["Macau"] = {
	aliases = {"Macao", "Macanese"},
	Wikipedia = true,
	regional_categories = "Macanese",
	parent = "non-Mainland",
}

labels["Mainland China"] = {
	aliases = {"Mainland", "mainland", "mainland China"},
	Wikipedia = true,
	regional_categories = true,
}

labels["Malaysia"] = {
	aliases = {"Malaysian"},
	Wikipedia = "Malaysian Chinese",
	regional_categories = "Malaysian",
	parent = "Southeast Asia",
}

labels["Mexico"] = {
	aliases = {"Mexican"},
	Wikipedia = "Mexican Chinese",
	regional_categories = "Mexican",
	parent = "Overseas",
}

labels["Dandong"] = {
	Wikipedia = true,
	regional_categories = true,
}

labels["Gansu"] = {
	Wikipedia = "Gansu, China",
	regional_categories = true,
}

labels["Mongolia"] = {
	Wikipedia = "Ethnic Chinese in Mongolia",
	regional_categories = "Mongolian",
	parent = "Overseas",
}

labels["Myanmar"] = {
	aliases = {"Myanmarese", "Burma", "Burmese"},
	Wikipedia = "Chinese people in Myanmar",
	regional_categories = true,
	parent = "Southeast Asia",
}

labels["non-Mainland"] = {
	prep = "by",
	region = "ethnic Chinese outside of [[mainland China]], including in [[Hong Kong]] and [[Macau]] due to their special history",
	display = "non-[[w:Mainland China|Mainland]] [[w:Chinese language|Chinese]]",
	aliases = {"Non-Mainland Chinese", "non-mainland Chinese"},
	regional_categories = true,
	parent = true,
}

labels["Overseas"] = {
	prep = "outside of",
	region = "[[mainland China]], [[Taiwan]], [[Hong Kong]] and [[Macau]]",
	Wikipedia = "Overseas Chinese",
	regional_categories = true,
	parent = "non-Mainland",
}

labels["Philippines"] = {
	aliases = {"Philippine"},
	Wikipedia = "Chinese Filipino",
	regional_categories = "Philippine",
	parent = "Southeast Asia",
}

labels["Pontianak"] = {
	Wikipedia = {"Language and overseas Chinese communities#Indonesia", "Chinese Indonesians"},
	regional_categories = true,
	parent = "Indonesia",
}

labels["Singapore"] = {
	aliases = {"Singaporean"},
	Wikipedia = "Singaporean Chinese",
	regional_categories = true,
	parent = "Southeast Asia",
}

labels["South Korea"] = {
	aliases = {"South Korean"},
	Wikipedia = "Chinese people in Korea",
	regional_categories = "South Korean",
	parent = "Overseas",
}

labels["Southeast Asia"] = {
	aliases = {"Southeast Asian", "SEA"},
	Wikipedia = "Overseas Chinese",
	regional_categories = "Southeast Asian",
	parent = "Overseas",
}

labels["Taiwan"] = {
	aliases = {"Taiwanese"},
	Wikipedia = true,
	regional_categories = "Taiwanese",
	parent = "non-Mainland",
}

labels["Thailand"] = {
	aliases = {"Thai"},
	Wikipedia = "Thai Chinese",
	regional_categories = "Thai",
	parent = "Southeast Asia",
}

labels["US"] = {
	aliases = {"U.S.", "United States", "United States of America", "USA", "America", "American"}, -- America/American: should these be aliases of 'North America'?
	Wikipedia = "History of Chinese Americans",
	regional_categories = "American",
	parent = "North America",
}

labels["Vietnam"] = {
	aliases = {"Vietnamese"},
	Wikipedia = "Hoa people",
	regional_categories = "Vietnamese",
	parent = "Southeast Asia",
}

return require("Module:labels").finalize_data(labels)
