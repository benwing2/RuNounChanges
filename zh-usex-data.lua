local data = {}

-- List of varieties. Each entry is a list of the following:
-- {"OLD_CODE", "LANG_CODE", "NORM_CODE", "DESCRIPTION", "TRANSLITERATION"} where "OLD_CODE" is the old-style bespoke
-- code used for this variety (which will be going away) and "LANG_CODE" is the Wiktionary language code (possibly an
-- etym-only code) used for this variety. "NORM_CODE" is the normalizezd language code used for handling varieties that
-- should be treated the same for transliteration purposes. For example, all Hokkien varieties use Pe̍h-ōe-jī and should
-- behave the same for pron_correction and other purposes. Similarly, many
-- Mandarin varieties use standard Pinyin, etc.
data.variety_list = {
	{"MSC", "cmn", false, "[[w:Standard Chinese|MSC]]", "Pinyin"},
		{"M-BJ", "cmn-bei", "cmn", "[[w:Beijing dialect|Beijing Mandarin]]", "Pinyin"},
		{"M-TW", "cmn-TW", "cmn", "[[w:Taiwanese Mandarin|Taiwanese Mandarin]]", "Pinyin"},
		{"M-MY", "cmn-MY", "cmn", "[[w:Malaysian Mandarin|Malaysian Mandarin]]", "Pinyin"},
		{"M-SG", "cmn-SG", "cmn", "[[w:Singaporean Mandarin|Singaporean Mandarin]]", "Pinyin"},
		{"M-PH", "cmn-PH", "cmn", "[[w:Mandarin Chinese in the Philippines|Philippine Mandarin]]", "Pinyin"},
		{"M-TJ", "cmn-tia", "cmn", "[[w:Tianjin dialect|Tianjin Mandarin]]", "Pinyin"},
		{"M-NE", "cmn-noe", "cmn", "[[w:Northeastern Mandarin|Northeastern Mandarin]]", "Pinyin"},
		{"M-CP", "cmn-cep", "cmn", "[[w:Central Plains Mandarin|Central Plains Mandarin]]", "Pinyin"},
		{"M-GZ", "cmn-gua", "cmn", "[[w:Xi'an dialect|Guanzhong Mandarin]]", "Pinyin"}, --Guanzhong
		{"M-LY", "cmn-lan", "cmn", "[[w:Lanyin Mandarin|Lanyin Mandarin]]", "Pinyin"},
		{"M-S", "zhx-sic", false, "[[w:Sichuanese dialects|Sichuanese]]", "Sichuanese Pinyin"},
		{"M-NJ", "cmn-nan", false, "[[w:Nanjing dialect|Nanjing Mandarin]]", "Nankinese Pinyin"},
		{"M-YZ", "cmn-yan", false, "[[w:Yangzhou dialect|Yangzhou Mandarin]]", "IPA"}, --IPA as a placeholder
		{"M-W", "cmn-wuh", false, "[[w:Wuhan dialect|Wuhanese]]", "IPA"},
		{"M-GL", "cmn-gui", false, "[[w:zh:桂林話|Guilin Mandarin]]", "IPA"}, --IPA as a placeholder
		{"M-XN", "cmn-xin", false, "Xining Mandarin", "IPA"}, --IPA as a placeholder
		{"M-UIB", "cmn-bec", "cmn", "[[w:Mandarin Chinese|dialectal Mandarin]]", "Pinyin"}, -- UIB stands for "unidentified Beijingesque"; this is only used for dialects with similar phonology to one of Beijing dialect or MSC
		{"M-DNG", "dng", false, "[[w:Dungan language|Dungan]]", "Cyrillic"},
	
	{"CL", "lzh", "cmn", "[[w:Classical Chinese|Classical Chinese]]", "Pinyin"},
		{"CL-TW", "lzh-cmn-TW", "cmn", "[[w:Classical Chinese|Classical Chinese]]", "Pinyin ([[w:Taiwanese Mandarin|Taiwanese Mandarin]])"},
		{"CL-C", "lzh-yue", "yue", "[[w:Classical Chinese|Classical Chinese]]", "Jyutping"},
		{"CL-C-T", "lzh-tai", "zhx-tai", "[[w:Classical Chinese|Classical Chinese]]", "Wiktionary"},
		{"CL-VN", "lzh-VI", "vi", "[[w:Literary Chinese in Vietnam|Vietnamese Literary Sinitic]]", "[[w:Sino-Vietnamese vocabulary|Sino-Vietnamese]]"},
		{"CL-KR", "lzh-KO", "ko", "[[w:Chinese-language literature of Korea|Korean Literary Sinitic]]", "[[w:Sino-Korean vocabulary|Sino-Korean]]"},
		{"CL-PC", "lzh-pre", "cmn", "[[w:Old Chinese|Pre-Classical Chinese]]", "Pinyin"},
		{"CL-L", "lzh-lit", "cmn", "[[w:Literary Chinese|Literary Chinese]]", "Pinyin"},

	{"CI", "lzh-cii", "cmn", "[[w:Ci (poetry)|Ci]]", "Pinyin"},
	
	{"WVC", "cmn-wvc", "cmn", "[[w:Written vernacular Chinese|Written Vernacular Chinese]]", "Pinyin"},
		{"WVC-C", "yue-wvc", "yue", "[[w:Written vernacular Chinese|Written Vernacular Chinese]]", "Jyutping"},
		{"WVC-C-T", "zhx-tai-wvc", "zhx-tai", "[[w:Written vernacular Chinese|Written Vernacular Chinese]]", "Wiktionary"},

	{"C", "yue", false, "[[w:Cantonese|Cantonese]]", "Jyutping"},
		{"C-GZ", "yue-gua", "yue", "[[w:Cantonese|Guangzhou Cantonese]]", "Jyutping"},
		{"C-LIT", "yue-lit", "yue", "[[w:Cantonese|Literary Cantonese]]", "Jyutping"},
		{"C-HK", "yue-HK", "yue", "[[w:Hong Kong Cantonese|Hong Kong Cantonese]]", "Jyutping"},
		{"C-T", "zhx-tai", false, "[[w:Taishanese|Taishanese]]", "Wiktionary"},
		{"C-DZ", "zhx-dan", false, "[[w:Danzhou dialect|Danzhou dialect]]", "IPA"}, --IPA as a placeholder

	{"J", "cjy", false, "[[w:Jin Chinese|Jin]]", "[[Wiktionary:About Chinese/Jin|Wiktionary]]"},
		
	{"MB", "mnp", false, "[[w:Northern Min|Northern Min]]", "[[w:Kienning Colloquial Romanized|Kienning Colloquial Romanized]]"},
	
	{"MD", "cdo", false, "[[w:Eastern Min|Eastern Min]]", "[[w:Bàng-uâ-cê|Bàng-uâ-cê]] / IPA"},
	
	{"MN", "nan-hbl", false, "[[w:Hokkien|Hokkien]]", "[[w:Pe̍h-ōe-jī|Pe̍h-ōe-jī]]"},
		{"TW", "nan-hbl-TW", "nan-hbl", "[[w:Taiwanese Hokkien|Taiwanese Hokkien]]", "[[w:Pe̍h-ōe-jī|Pe̍h-ōe-jī]]"},
		{"MN-PN", "nan-pen", "nan-hbl", "[[w:Penang Hokkien|Penang Hokkien]]", "[[w:Pe̍h-ōe-jī|Pe̍h-ōe-jī]]"},
		{"MN-PH", "nan-hbl-PH", "nan-hbl", "[[w:Philippine Hokkien|Philippine Hokkien]]", "[[w:Pe̍h-ōe-jī|Pe̍h-ōe-jī]]"},
		{"MN-T", "nan-tws", false, "[[w:Teochew dialect|Teochew]]", "[[w:Peng\'im|Peng\'im]]"},
		{"MN-L", "nan-luh", false, "[[w:Leizhou Min|Leizhou Min]]", "Leizhou Pinyin"},
		{"MN-HLF", "nan-hlh", false, "[[w:Haklau Min|Haklau Min]]", "IPA"}, --IPA as a placeholder
		{"MN-H", "nan-hnm", false, "[[w:Hainanese|Hainanese]]", "[[w:Guangdong Romanization|Guangdong Romanization]]"},
		
	{"W", "wuu", false, "[[w:Wu Chinese|Wu]]", "[[Wiktionary:About Chinese/Wu|Wugniu]]"},
		{"SH", "wuu-sha", "wuu", "[[w:Shanghainese|Shanghainese]]", "[[Wiktionary:About Chinese/Wu|Wugniu]]"},
		{"W-SZ", "wuu-suz", "wuu", "[[w:Suzhounese|Suzhounese]]", "[[Wiktionary:About Chinese/Wu|Wugniu]]"}, -- wuu-sz?
		{"W-HZ", "wuu-han", "wuu", "[[w:Hangzhounese|Hangzhounese]]", "[[Wiktionary:About Chinese/Wu|Wugniu]]"}, -- wuu-hz?
		{"W-CM", "wuu-chm", "wuu", "[[w:Shadi dialect|Shadi Wu]]", "[[Wiktionary:About Chinese/Wu|Wugniu]]"}, -- wuu-cm? including Chongming, Haimen, Changyinsha etc
		{"W-NB", "wuu-nin", "wuu", "[[w:Ningbo dialect|Ningbonese]]", "[[Wiktionary:About Chinese/Wu|Wugniu]]"},
		{"W-N", "wuu-nor", "wuu", "[[w:Northern Wu|Northern Wu]]", "[[Wiktionary:About Chinese/Wu|Wugniu]]"}, -- general northern wu, incl. transitionary varieties
		{"W-WZ", "wuu-wen", "wuu", "[[w:Wenzhou dialect|Wenzhounese]]", "[[Wiktionary:About Chinese/Wu|Wugniu]]"}, -- wuu-wz?
		
	{"G", "gan", false, "[[w:Gan Chinese|Gan]]", "[[Wiktionary:About Chinese/Gan|Wiktionary]]"},

	{"X", "hsn", false, "[[w:Xiang Chinese|Xiang]]", "[[Wiktionary:About Chinese/Xiang|Wiktionary]]"},
		
	{"H", "hak-six", "hak", "[[w:Sixian dialect|Sixian Hakka]]", "[[w:Pha̍k-fa-sṳ|Pha̍k-fa-sṳ]]"},
		{"H-HL", "hak-hai", "hak-TW", "[[w:Hailu dialect|Hailu Hakka]]", "[[w:Taiwanese Hakka Romanization System|Taiwanese Hakka Romanization System]]"},
		{"H-DB", "hak-dab", "hak-TW", "[[w:zh:臺灣客家語#大埔腔|Dabu Hakka]]", "[[w:Taiwanese Hakka Romanization System|Taiwanese Hakka Romanization System]]"},
        {"H-MX", "hak-mei", false, "[[w:Meixian dialect|Meixian Hakka]]", "[[w:Pinfa|Hakka Transliteration Scheme]]"},
		{"H-MY-HY", "hak-hui-MY", false, "Malaysian Huiyang Hakka", "IPA"}, --IPA as a placeholder
		{"H-EM", "hak-eam", false, "[[w:Hakka Chinese|Early Modern Hakka]]", "IPA"}, --Early Modern Hakka, IPA as a placeholder
		{"H-ZA", "hak-zha", "hak-TW", "[[w:zh:詔安客語|Zhao'an Hakka]]", "[[w:Taiwanese Hakka Romanization System|Taiwanese Hakka Romanization System]]"},
	
	{"WX", "wxa", false, "[[w:Waxiang Chinese|Waxiang]]", "IPA"},
}

data.varieties_by_code = {}
data.varieties_by_old_code = {}
for _, variety_spec in ipairs(data.variety_list) do
	local old_code, code, norm_code, desc, tr_desc = unpack(variety_spec)
	data.varieties_by_code[code] = variety_spec
	data.varieties_by_old_code[old_code] = variety_spec
end

data.punctuation = {
	["，"] = ",",	["。"] = ".",	["、"] = ",",
	["？"] = "?",	["！"] = "!",
	
	["《"] = "“",	["》"] = "”",
	["〈"] = "‘",	["〉"] = "’",
	["『"] = "‘",	["』"] = "’",
	["「"] = "“",	["」"] = "”",
	["“"] = "“",	["”"] = "”",
	
	["（"] = "(",	["）"] = ")",
	["；"] = ";",	["："] = ":",
	["|"] = "|",	["—"] = "-",	["～"] = "~",	["——"] = "—",
	["·"] = " ",	["…"] = "...",
	["．"] = ".",

	["　"] = ",",
	["⋯"] = "...",  ["⋯⋯"] = "...",
	
	["<br>"] = "<br>", ["<br/>"] = "<br>",
}

local CE = '<small class="ce-date">[[Appendix:Glossary#CE|<span title="Glossary and display preference">CE</span>]]</small>'
local BCE = '<small class="ce-date">[[Appendix:Glossary#BCE|<span title="Glossary and display preference">BCE</span>]]</small>'
local circa = "''[[Appendix:Glossary#c.|c.]]''"

local function format_mao(year, chinese_title, english_title, volume, number) -- volume and number are used to generate links to the Marxists Internet Archive
	return { "cmn",  "'''" .. year .. "''', <span lang=\"zh\" class=\"Hani\">[[w:zh:毛澤東|毛澤東]]</span> ([[w:Mao Zedong|Mao Zedong]]), <span lang=\"zh\" class=\"Hani\">《" .. chinese_title .. "》</span> (" .. english_title .. "), <span lang=\"zh\" class=\"Hani\">《[[w:zh:毛澤東選集|毛澤東選集]]》</span>. English translation based on [https://www.marxists.org/reference/archive/mao/selected-works/volume-" .. volume .. "/mswv" .. volume .. "_" .. number .. ".htm the Foreign Languages Press edition]" }
end

data.ref_list = {
	['Analects']     =  { "lzh",  "The ''[[w:Analects|Analects]] of Confucius'', " .. circa .. " 475 – 221 " .. BCE .. ", translated based on [[w:James Legge|James Legge]]'s version" },
	['Analects-W']   =  { "lzh",  "The ''[[w:Analects|Analects]] of Confucius'', " .. circa .. " 475 – 221 " .. BCE .. ", Wiktionary translation" },
	['Baihutong']    =  { "lzh-lit",  "[[w:Ban Gu|Ban Gu]], ''[[w:Bai Hu Tong|The Comprehensive Discussions in the White Tiger Hall]]'', 79 " .. CE },
	['Baihutong-T']    =  { "lzh-lit",  "[[w:Ban Gu|Ban Gu]], ''[[w:Bai Hu Tong|The Comprehensive Discussions in the White Tiger Hall]]'', 79 " .. CE .. ", translated based on [[w:Tjan Tjoe Som|Tjan Tjoe Som]]'s version" },
	['Baopuzi']    =  { "lzh-lit",  "[[w:Ge Hong|Ge Hong]], ''[[w:Baopuzi|Baopuzi]]'', 4<sup>th</sup> century " .. CE },
	['Beiji Qianjin Yaofang']  =  { "lzh-lit",  "[[w:Sun Simiao|Sun Simiao]], ''[[w:Beiji qianjin yaofang|Essential Formulas Worth a Thousand Weights in Gold to Prepare for Emergencies]]'', 652 " .. CE },
	['Beiqishu']     =  { "lzh-lit",  "The ''[[w:Book of Northern Qi|Book of Northern Qi]]'', by [[w:Li Baiyao|Li Baiyao]], 636 " .. CE },
	['Beishi']       =  { "lzh",  circa .. " '''659''' " .. CE .. ", Li Yanshou, ''[[w:History of the Northern Dynasties|History of the Northern Dynasties]]''" },
	['Bencao Gangmu']=  { "lzh-lit",  "The ''[[w:Compendium of Materia Medica|Compendium of Materia Medica]]'' [Bencao Gangmu], by [[w:Li Shizhen|Li Shizhen]], 1578 " .. CE },
	['Changhenge']   =  { "lzh-lit",  "'''806''' " .. CE .. ", [[w:Bai Juyi|Bai Juyi]], ''[[wikisource:Song of Everlasting Regret|Song of Everlasting Regret]]''" },
	['Chuci']        =  { "lzh",  "The ''[[w:Chu Ci|Verses of Chu]]'', 4<sup>th</sup> century " .. BCE .." – 2<sup>nd</sup> century " .. CE },
	['Chuci-H']      =  { "lzh",  "The ''[[w:Chu Ci|Verses of Chu]]'', 4<sup>th</sup> century " .. BCE .." – 2<sup>nd</sup> century " .. CE .. ", translated based on [[w:David Hawkes (sinologist)|David Hawkes']] version" },
	['Chunqiu Fanlu']=  { "lzh",  "The ''[[w:Luxuriant Dew of the Spring and Autumn Annals|Luxuriant Dew of the Spring and Autumn Annals]]''" },
	['Daodejing']    =  { "lzh",  "''[[w:Tao Te Ching|Tao Te Ching]]'', 4<sup>th</sup> century " .. BCE },
	['Daodejing-L']  =  { "lzh",  "''[[w:Tao Te Ching|Tao Te Ching]]'', 4<sup>th</sup> century " .. BCE .. ", translated based on [[w:James Legge|James Legge]]'s version" },
	['Datang Xiyuji']=  { "lzh-lit",  "[[w:Xuanzang|Xuanzang]], ''[[w:Great Tang Records on the Western Regions|Great Tang Records on the Western Regions]]'', 646 " .. CE },
	['Datang Xiyuji-B']=  { "lzh-lit",  "[[w:Xuanzang|Xuanzang]], ''[[w:Great Tang Records on the Western Regions|Great Tang Records on the Western Regions]]'', 646 " .. CE .. ", translated based on [[w:Samuel Beal|Samuel Beal]]'s version" },
	['Datang Xiyuji-L']=  { "lzh-lit",  "[[w:Xuanzang|Xuanzang]], ''[[w:Great Tang Records on the Western Regions|Great Tang Records on the Western Regions]]'', 646 " .. CE .. ", translated based on Li Rongxi's version" },
	['Dongguan Han Ji']=  { "lzh",  "''[[w:zh:東觀漢記|Dongguan Han Ji]]'', 1<sup>st</sup> century " .. CE .."– 2<sup>nd</sup> century " .. CE },
	['Dou E Yuan']=  { "cmn-wvc",  "'''Yuan Dynasty''', [[w:Guan Hanqing|Guan Hanqing]], ''[[w:The Injustice to Dou E|The Injustice to Dou E]]''" },
	['Erya']         =  { "lzh",  "''[[w:Erya|Erya]]'', 5<sup>th</sup> – 2<sup>nd</sup> century " .. BCE },
	['Ernv Yingxiongzhuan'] = { "cmn-wvc", "Wenkang, ''[[w:Ernü Yingxiong Zhuan|Ernü Yingxiongzhuan]]'', 1878 " .. CE },
	['Fangyan']      =  { "lzh",  "[[w:Yang Xiong (author)|Yang Xiong]], ''[[w:Fangyan|Fangyan]]'', " .. circa .. " 1<sup>st</sup> century " .. BCE },
	['Fangyu Shenglan']      =  { "lzh-lit",  "''[[w:zh:方輿勝覽|Fangyu Shenglan]]'', " .. circa .. " 13<sup>th</sup> century " .. CE },
	['Fayan']        =  { "lzh",  "[[w:Yang Xiong (author)|Yang Xiong]], ''[[w:Fayan (book)|Fa Yan]]'' (''Exemplary Sayings''), 9 " .. CE },
	['Fayan-B']      =  { "lzh",  "[[w:Yang Xiong (author)|Yang Xiong]], ''[[w:Fayan (book)|Fa Yan]]'' (''Exemplary Sayings''), 9 " .. CE .. ", translated based on Jeffrey S. Bullock's version" },
	['Fengsu Tongyi']      =  { "lzh",  "[[w:Ying Shao|Ying Shao]], ''[[w:Fengsu Tongyi|Fengsu Tongyi]]'' (''Comprehensive Meaning of Customs and Mores''), 195 " .. CE },
    ['Gaosengzhuan']=  { "lzh",  "Shi Huijiao, ''[[w:Memoirs of Eminent Monks|Memoirs of Eminent Monks]]'', circa 530 " .. CE },
    ['Gongyangzhuan']=  { "lzh",  "''[[w:Gongyang Zhuan|Commentary of Gongyang]]'', " .. circa .. " 206 " .. BCE .. "– 9 " .. CE },
	['Guanyinzi']    =  { "lzh",  "''[[w:zh:關尹子|Guanyinzi]]'', time unknown" },
	['Guanzi']       =  { "lzh",  "''[[w:Guanzi (text)|Guanzi]]'', 5<sup>th</sup> century " .. BCE .. " to 220 " .. CE  },
	['Gujin Xiaoshuo']=  { "cmn-wvc", "[[w:Feng Menglong|Feng Menglong]], ''[[w:Stories Old and New|Stories Old and New]]'', 1620 " .. CE },
    ['Guliangzhuan'] =  { "lzh",  "''[[w:Guliang Zhuan|Commentary of Guliang]]'', circa 206 " .. BCE .. "– 9 " .. CE },
	['Guoyu']        =  { "lzh",  "''[[w:Guoyu (book)|Guoyu]]'', circa 4<sup>th</sup> century " .. BCE },
	['Hanfeizi']     =  { "lzh",  "''[[w:Han Feizi (book)|Han Feizi]]'', circa 2<sup>nd</sup> century " .. BCE },
	['Hanfeizi-L']   =  { "lzh",  "''[[w:Han Feizi (book)|Han Feizi]]'', circa 2<sup>nd</sup> century " .. BCE .. ", translated based on [[w:zh:廖文奎|W. K. Liao]]'s version" },
	['Hanshi Waizhuan']    =  { "lzh",  "''[[w:Han shi waizhuan|Han shi waizhuan]]'', 1<sup>nd</sup> century " .. BCE },
	['Hanshi Waizhuan-H']  =  { "lzh",  "''[[w:Han shi waizhuan|Han shi waizhuan]]'', 1<sup>nd</sup> century " .. BCE .. ", translated based on [[w:James Robert Hightower|James R. Hightower]]'s version" },
	['Hanshu']       =  { "lzh",  "The ''[[w:Book of Han|Book of Han]]'', circa 1<sup>st</sup> century " .. CE },
	['Houhanshu']    =  { "lzh-lit",  "The ''[[w:Book of the Later Han|Book of the Later Han]]'', circa 5<sup>th</sup> century " .. CE },
	['Hongloumeng']  =  { "cmn-wvc", "[[w:Cao Xueqin|Cao Xueqin]], ''[[w:Dream of the Red Chamber|Dream of the Red Chamber]]'', mid-18<sup>th</sup> century " .. CE },
	['Huainanzi']    =  { "lzh",  "''[[w:Huainanzi|Huainanzi]]'', 2<sup>nd</sup> century " .. BCE },
	['Huangdi Neijing']={ "lzh",  "''[[w:Huangdi Neijing|Huangdi Neijing]]'', 4<sup>th</sup> century " .. BCE .. " to 3<sup>rd</sup> century " .. CE },
	['Jinpingmei']   =  { "cmn-wvc",  "''[[w:The Plum in the Golden Vase|The Plum in the Golden Vase]]'', circa 1610 " .. CE },
    ['Jinpingmei-R']   =  { "cmn-wvc",  "''[[w:The Plum in the Golden Vase|The Plum in the Golden Vase]]'', circa 1610 " .. CE .. ", translated based on [[w:David Tod Roy|David Tod Roy]]'s version" },
	['Jinshi']       =  { "lzh-lit",  "'''1344''' " .. CE .. ", [[w:Toqto'a (Yuan dynasty)|Toqto'a]] (lead editor), ''[[w:History of Jin|History of Jin]]''" },
	['Jinshu']       =  { "lzh-lit",  "'''648''' " .. CE .. ", [[w:Fang Xuanling|Fang Xuanling]] (lead editor), ''[[w:Book of Jin|Book of Jin]]''" },
	['Jiutangshu']   =  { "lzh-lit",  "The ''[[w:Old Book of Tang|Old Book of Tang]]'', 945 " .. CE },
    ['Kongzi Jiayu'] =  { "lzh",  "The ''[[w:Kongzi Jiayu|School Sayings of Confucius]]'', " .. circa .. " 206 " .. BCE .. "– 220 " .. CE },
	['Lantingjixu']  =  { "lzh-lit",  "'''353''' " .. CE .. ", [[w:Wang Xizhi|Wang Xizhi]], ''[[:s:Preface to the Poems Composed at the Orchid Pavilion|Preface to the Poems Composed at the Orchid Pavilion]]''" },
	['Laocan Youji']  =  { "cmn-wvc",  "'''1907''' " .. CE .. ", [[w:Liu E|Liu E]], ''[[w:The Travels of Lao Can|The Travels of Lao Can]]''" },
	['Liaozhai']  =  { "lzh-lit",  "'''1740''' " .. CE .. ", [[w:Pu Songling|Pu Songling]], ''[[:s:Strange Stories from a Chinese Studio|Strange Stories from a Chinese Studio]]''" },
    ['Lienvzhuan']   =  { "lzh",  "The ''[[w:Biographies of Exemplary Women|Biographies of Exemplary Women]]'', 2<sup>nd</sup> century " .. BCE },
	['Liezi']        =  { "lzh",  "''[[w:Liezi|Liezi]]'', 1<sup>st</sup> – 5<sup>th</sup> century " .. CE },
	['Liezi-C']      =  { "lzh",  "''[[w:Liezi|Liezi]]'', 1<sup>st</sup> – 5<sup>th</sup> century " .. CE .. ", translated based on [[w:Thomas Cleary|Thomas Cleary]]'s version" },
	['Liezi-G']      =  { "lzh",  "''[[w:Liezi|Liezi]]'', 1<sup>st</sup> – 5<sup>th</sup> century " .. CE .. ", translated based on [[w:A. C. Graham|A. C. Graham]]'s version" },
	['Liji']         =  { "lzh",  "The ''[[w:Book of Rites|Book of Rites]]'', " .. circa .. " 4<sup>th</sup> – 2<sup>nd</sup> century " .. BCE },
	['Liji-L']       =  { "lzh",  "The ''[[w:Book of Rites|Book of Rites]]'', " .. circa .. " 4<sup>th</sup> – 2<sup>nd</sup> century " .. BCE .. ", translated based on [[w:James Legge|James Legge]]'s version" },
	['Lingqijing']   =  { "lzh",  "''[[w:Lingqijing|The Divine Chess Classic]]''" },
    ['Lingwai Daida']   =  { "lzh",  "[[w:zh:周去非|Zhou Qufei]], ''[[w:Lingwai Daida|Representative Answers from the Region beyond the Mountains]]'', 12<sup>th</sup> century " .. CE },
	['Liutao']       =  { "lzh",  "''[[w:Six Secret Teachings|Six Secret Teachings]]'', " .. circa .. " 475 – 221 " .. BCE },
	['Liutao-S']     =  { "lzh",  "''[[w:Six Secret Teachings|Six Secret Teachings]]'', " .. circa .. " 475 – 221 " .. BCE .. ", translated based on Ralph D. Sawyer's version" },
	['Lunyu']        =  { "lzh",  "The ''[[w:Analects|Analects]] of Confucius'', " .. circa .. " 475 – 221 " .. BCE },
	['Lvshi Chunqiu']=  { "lzh",  "[[w:Lü Buwei|Lü Buwei]], ''[[w:Lüshi Chunqiu|Master Lü's Spring and Autumn Annals]]'', 239 " .. BCE },
	['Lunheng']      =  { "lzh",  "[[w:Wang Chong|Wang Chong]], ''[[w:Lunheng|Lun Heng]]'' (''Discussive Weighing''), 80 " .. CE },
	['Lunheng-F']      =  { "lzh",  "[[w:Wang Chong|Wang Chong]], ''[[w:Lunheng|Lun Heng]]'' (''Discussive Weighing''), 80 " .. CE .. ", translated based on Alfred Forke's version" },
	['Mencius']      =  { "lzh",  "''[[w:Mencius (book)|Mencius]]'', " .. circa .. " 4<sup>th</sup> century " .. BCE },
	['Mencius-L']    =  { "lzh",  "''[[w:Mencius (book)|Mencius]]'', " .. circa .. " 4<sup>th</sup> century " .. BCE .. ", translated based on [[w:James Legge|James Legge]]'s version" },
	['Mengxi Bitan']    =  { "lzh-lit", "'''1088''' " .. CE ..  ", [[w:Shen Kuo|Shen Kuo]], ''[[w:Dream Pool Essays|Dream Pool Essays]]''" },
	['Mengzi']       =  { "lzh",  "''[[w:Mencius (book)|Mencius]]'', " .. circa .. " 4<sup>th</sup> century " .. BCE },
	['Mengzi-L']     =  { "lzh",  "''[[w:Mencius (book)|Mencius]]'', " .. circa .. " 4<sup>th</sup> century " .. BCE .. ", translated based on [[w:James Legge|James Legge]]'s version" },
	['Mingshi']         =  { "lzh-lit",  "'''17<sup>th</sup>-18<sup>th</sup> century''', ''[[w:History of Ming|History of Ming]]''" },
	['Mozi']         =  { "lzh",  "''[[w:Mozi (book)|Mozi]]'', " .. circa .. " 4<sup>th</sup> century " .. BCE },
	['Mozi-M']       =  { "lzh",  "''[[w:Mozi (book)|Mozi]]'', " .. circa .. " 4<sup>th</sup> century " .. BCE .. ", translated based on [[w:zh:梅貽寶|Y. P. Mei]]'s version" },
    ['Mutianzizhuan']=  { "lzh",  "The ''[[w:Tale of King Mu, Son of Heaven|Tale of King Mu, Son of Heaven]]'', " .. circa .. " 370 – 330 " .. BCE },
    ['Mutianzizhuan-E']=  { "lzh",  "The ''[[w:Tale of King Mu, Son of Heaven|Tale of King Mu, Son of Heaven]]'', " .. circa .. " 370 – 330 " .. BCE .. ", translated based on [[w:Ernst Johann Eitel|E. J. Eitel]]'s version" },
    ['Mutianzizhuan-Z']=  { "lzh",  "The ''[[w:Tale of King Mu, Son of Heaven|Tale of King Mu, Son of Heaven]]'', " .. circa .. " 370 – 330 " .. BCE .. ", translated based on Zheng Dekun's version" },
	['Nanqishu']     =  { "lzh-lit",  "The ''[[w:Book of Qi|Book of Southern Qi]]'', by [[w:Xiao Zixian|Xiao Zixian]], 6<sup>th</sup> century " .. CE },
	['Nanshi']       =  { "lzh-lit",  "'''659''' " .. CE .. ", [[w:Li Dashi|Li Dashi]] and Li Yanshou, ''[[w:History of the Southern Dynasties|History of the Southern Dynasties]]''" },
	['Paian Jingqi 1'] = { "cmn-wvc", "'''1628''' " .. CE .. ", [[w:Ling Mengchu|Ling Mengchu]], ''[[w:Slapping the Table in Amazement|Slapping the Table in Amazement]]'' I" },
	['Paian Jingqi 2'] = { "cmn-wvc", "'''1632''' " .. CE .. ", [[w:Ling Mengchu|Ling Mengchu]], ''[[w:Slapping the Table in Amazement|Slapping the Table in Amazement]]'' II" },
	['Peizhu']       =  { "lzh-lit",  "[[w:Pei Songzhi|Pei Songzhi]], ''[[w:Annotations to Records of the Three Kingdoms|Annotations to Records of the Three Kingdoms]]'', circa 5<sup>th</sup> century " .. CE },
	['Qianfu Lun']    =  { "lzh",  "[[w:Wang Fu (Han dynasty)|Wang Fu]], ''[[w:Qianfu Lun|Comments of a Recluse]]'', " .. circa .. " 2<sup>nd</sup> century " .. CE },
	['Qianfu Lun-P']  =  { "lzh",  "[[w:Wang Fu (Han dynasty)|Wang Fu]], ''[[w:Qianfu Lun|Comments of a Recluse]]'', " .. circa .. " 2<sup>nd</sup> century " .. CE .. ", translated based on Margaret Pearson's version" },
	['Qianjin Yaofang']  =  { "lzh-lit",  "[[w:Sun Simiao|Sun Simiao]], ''[[w:Beiji qianjin yaofang|Essential Formulas Worth a Thousand Weights in Gold to Prepare for Emergencies]]'', 652 " .. CE },
	['Qianziwen'] =  { "lzh-lit",  "Zhou Xingsi, ''[[w:Thousand Character Classic|Thousand Character Classic]]'', circa 6<sup>th</sup> century " .. CE  },
	['Qimin Yaoshu'] =  { "lzh-lit",  "'''544''' " .. CE .. ", Jia Sixie, ''[[w:Qimin Yaoshu|Qimin Yaoshu]]''" },
	['Qingshigao']   =  { "lzh-lit",  "'''1929''', [[w:Zhao Erxun|Zhao Erxun]] (lead editor), ''[[w:Draft History of Qing|Draft History of Qing]]''" },
	['Rulin Waishi'] =  { "cmn-wvc",  "[[w:Wu Jingzi|Wu Jingzi]], ''[[w:The Scholars (novel)|The Scholars]]'', 1750 " .. CE },
    ['Rulin Waishi-Y'] =  { "cmn-wvc",  "[[w:Wu Jingzi|Wu Jingzi]], ''[[w:The Scholars (novel)|The Scholars]]'', 1750 " .. CE .. ", translated based on [[w:Yang Xianyi|Yang Xianyi]] and [[w:Gladys Yang|Gladys Yang]]'s version" },
	['Sanlve']         =  { "lzh",  "''[[w:Three Strategies of Huang Shigong|Three Strategies of Huang Shigong]]]'', 3<sup>th</sup> century " .. BCE .." – 1<sup>nd</sup> century " .. CE },
	['Sanlve-S']       =  { "lzh",  "''[[w:Three Strategies of Huang Shigong|Three Strategies of Huang Shigong]]]'', 3<sup>th</sup> century " .. BCE .." – 1<sup>nd</sup> century " .. CE .. ", translated based on Ralph D. Sawyer's version" },
	['Sanguozhi']    =  { "lzh-lit",  "[[w:Chen Shou|Chen Shou]], ''[[w:Records of the Three Kingdoms|Records of the Three Kingdoms]]'', circa 3<sup>rd</sup> century " .. CE },
	['Sanguo Yanyi'] =  { "cmn-wvc",  "''[[w:Romance of the Three Kingdoms|Romance of the Three Kingdoms]]'', circa 14<sup>th</sup> century " .. CE },
	['Sanxia Wuyi']  =  { "cmn-wvc",  "''[[w:The Seven Heroes and Five Gallants|The Three Heroes and Five Gallants]]'', 1883 " .. CE },
	['Sanzijing']    =  { "lzh-lit",  "''[[w:Three Character Classic|Three Character Classic]]'', circa 13<sup>th</sup> century " .. CE },
	['Shangjunshu']  =  { "lzh",  "The ''[[w:The Book of Lord Shang|Book of Lord Shang]]'', circa 3<sup>rd</sup> century " .. BCE },
	['Shangjunshu-D']  =  { "lzh",  "The ''[[w:The Book of Lord Shang|Book of Lord Shang]]'', circa 3<sup>rd</sup> century " .. BCE .. ", translated based on [[w:J.J.L. Duyvendak|J.J.L. Duyvendak]]'s version" },
	['Shangshu']     =  { "lzh",  "The ''[[w:Book of Documents|Book of Documents]]'', circa 4<sup>th</sup> – 3<sup>rd</sup> century " .. BCE },
	['Shangshu-K']   =  { "lzh",  "The ''[[w:Book of Documents|Book of Documents]]'', circa 4<sup>th</sup> – 3<sup>rd</sup> century " .. BCE .. ", translated based on [[w:Bernhard Karlgren|Bernhard Karlgren]]'s version" },
	['Shangshu-L']   =  { "lzh",  "The ''[[w:Book of Documents|Book of Documents]]'', circa 4<sup>th</sup> – 3<sup>rd</sup> century " .. BCE .. ", translated based on [[w:James Legge|James Legge]]'s version" },
	['Shanhaijing']  =  { "lzh",  "The ''[[w:Classic of Mountains and Seas|Classic of Mountains and Seas]]''" },
	['Shanhaijing-B']  =  { "lzh",  "The ''[[w:Classic of Mountains and Seas|Classic of Mountains and Seas]]'', translation from ''The Classic of Mountains and Seas'' (1999), by Anne Birrell" },
	['Shennong Ben Cao Jing']  =  { "lzh",  "''[[w:Shennong Ben Cao Jing|The Divine Farmer's Materia Medica]]]'', 206 " .. BCE .." – 220 " .. CE },
	['Shennong Ben Cao Jing-Y']  =  { "lzh",  "''[[w:Shennong Ben Cao Jing|The Divine Farmer's Materia Medica]]]'', 206 " .. BCE .." – 220 " .. CE .. ", translated based on Yang Shou-zhong's version" },
	['Shiji']        =  { "lzh",  "The ''[[w:Records of the Grand Historian|Records of the Grand Historian]]'', by [[w:Sima Qian|Sima Qian]], " .. circa .. " 91 " .. BCE },
	['Shiji-A']      =  { "lzh",  "The ''[[w:Records of the Grand Historian|Records of the Grand Historian]]'', by [[w:Sima Qian|Sima Qian]], " .. circa .. " 91 " .. BCE .. ", translated based on Herbert J. Allen's version" },
	['Shiji-W']      =  { "lzh",  "The ''[[w:Records of the Grand Historian|Records of the Grand Historian]]'', by [[w:Sima Qian|Sima Qian]], " .. circa .. " 91 " .. BCE .. ", translated based on [[w:Burton Watson|Burton Watson]]'s version" },
	['Shijing']      =  { "lzh-pre",  "The ''[[w:Classic of Poetry|Classic of Poetry]]'', " .. circa .. " 11<sup>th</sup> – 7<sup>th</sup> centuries " .. BCE .. ", translated based on [[w:James Legge|James Legge]]'s version" },
	['Shijing-K']      =  { "lzh-pre",  "The ''[[w:Classic of Poetry|Classic of Poetry]]'', " .. circa .. " 11<sup>th</sup> – 7<sup>th</sup> centuries " .. BCE .. ", translated based on [[w:Bernhard Karlgren|Bernhard Karlgren]]'s version" },
	['Shijing-Xu']   =  { "lzh",  "''Preface to Mao's Odes'' (Commentary on the ''[[w:Classic of Poetry|Classic of Poetry]]''), mid 2<sup>nd</sup> century " .. BCE  },
	['Shishuo Xinyu']=  { "lzh-lit",  "[[w:zh:劉義慶|Liu Yiqing]] (editor), ''[[w:A New Account of the Tales of the World|A New Account of the Tales of the World]]'', 5<sup>th</sup> century " .. CE },
	['Shitong']     =  { "lzh-lit",  "[[w:Liu Zhiji|Liu Zhiji]], ''[[w:Shitong|Shitong]]'', circa 708 – 710 " .. CE },
	['Shuihuzhuan']  =  { "cmn-wvc", "[[w:Shi Nai'an|Shi Nai'an]], ''[[w:Water Margin|Water Margin]]'', circa 14<sup>th</sup> century " .. CE },
	['Shuijingzhu']  =  { "lzh-lit", "[[w:Li Daoyuan|Li Daoyuan]], ''[[w:Commentary on the Water Classic|Commentary on the Water Classic]]'', 386-534 " .. CE },
	['Shujing']      =  { "lzh",  "The ''[[w:Book of Documents|Book of Documents]]'', circa 7<sup>th</sup> – 4<sup>th</sup> centuries " .. BCE },
	['Shujing-L']    =  { "lzh",  "The ''[[w:Book of Documents|Book of Documents]]'', circa 7<sup>th</sup> – 4<sup>th</sup> centuries " .. BCE .. ", translated based on [[w:James Legge|James Legge]]'s version" },
	['Shuowen']      =  { "lzh",  "''[[w:Shuowen Jiezi|Shuowen Jiezi]]'', circa 2<sup>nd</sup> century " .. CE },
    ['Shuoyuan']     =  { "lzh",  "''[[w:Shuoyuan|Shuoyuan]]'', circa 1<sup>st</sup> century " .. BCE },
	['Simafa']      =  { "lzh",  "''[[w:The Methods of the Sima|The Methods of the Sima]]'', circa 4<sup>th</sup> century " .. BCE },
	['Simafa-S']    =  { "lzh",  "''[[w:The Methods of the Sima|The Methods of the Sima]]'', circa 4<sup>th</sup> century " .. BCE .. ", translated based on Ralph D. Sawyer's version" },
	['Songshi']      =  { "lzh-lit",  "'''1345''' " .. CE .. ", [[w:Toqto'a (Yuan dynasty)|Toqto'a]] (lead editor), ''[[w:History of Song (book)|History of Song]]''" },
    ['Songshu']      =  { "lzh-lit",  "[[w:Shen Yue|Shen Yue]], ''[[w:Book of Song|Book of Song]]'', 492-493 " .. CE},
    ['Soushenji']    =  { "lzh",  "''[[w:Soushen Ji|In Search of the Sacred]]'', circa 3<sup>rd</sup> century " .. CE },
    ['Suishu']       =  { "lzh-lit",  "The ''[[w:Book of Sui|Book of Sui]]'', 636 " .. CE },
	['Sunzi']        =  { "lzh",  "''[[w:The Art of War|The Art of War]]'', circa 5<sup>th</sup> century " .. BCE },
	['Sunzi-G']      =  { "lzh",  "''[[w:The Art of War|The Art of War]]'', circa 5<sup>th</sup> century " .. BCE .. ", translated based on [[w:Lionel Giles|Lionel Giles]]'s version" },
	['Sunzi-S']      =  { "lzh",  "''[[w:The Art of War|The Art of War]]'', circa 5<sup>th</sup> century " .. BCE .. ", translated based on Ralph D. Sawyer's version" },
	['Taiping Guangji']={ "lzh-lit",  "''[[w:Taiping Guangji|Taiping Guangji]]'' (''Extensive Records of the Taiping Era''), 978 " .. CE },
	['Taiping Yulan']=  { "lzh-lit",	 "''[[w:Taiping Yulan|Taiping Yulan]]'' (''Readings of the Taiping Era''), 977 – 983 " .. CE },
	['Taixuanjing']  =  { "lzh",  "[[w:Yang Xiong (author)|Yang Xiong]], ''[[w:Taixuanjing|The Canon of Supreme Mystery]]'', 2 " .. BCE },
	['Tingxun Geyan']=  { "lzh", "[[w:Kangxi Emperor|Qing Emperor Kangxi]], ''Guidelines for Families''" },
	['Tongdian']     =  { "lzh-lit",	 "[[w:Du You|Du You]], ''[[w:Tongdian|Tongdian]]'', 766 – 801 " .. CE },
	['UM']           =  { "cmn", "[http://nlp2ct.cis.umac.mo/um-corpus/ UM-Corpus: A Large English-Chinese Parallel Corpus] by NLP2CT" },
	['Weiliaozi']       =  { "lzh",  "''[[w:Wei Liaozi|Wei Liaozi]]'', " .. circa .. " 4<sup>th</sup> – 3<sup>rd</sup> centuries " .. BCE },
	['Weiliaozi-S']     =  { "lzh",  "''[[w:Wei Liaozi|Wei Liaozi]]'', " .. circa .. " 4<sup>th</sup> – 3<sup>rd</sup> centuries " .. BCE .. ", translated based on Ralph D. Sawyer's version" },
    ['Weilve']       =  { "lzh",  "[[w:Yu Huan|Yu Huan]], ''[[w:Weilüe|Weilüe]]'', 239  – 265 " .. CE },
	['Weishu']       =  { "lzh-lit",  "[[w:Wei Shou|Wei Shou]], ''[[w:Book of Wei|Book of Wei]]'', 551 – 554 " .. CE },
	['Wenxin Diaolong'] =  { "lzh",  "[[w:Liu Xie|Liu Xie]], ''[[w:The Literary Mind and the Carving of Dragons|The Literary Mind and the Carving of Dragons]]'', " .. circa .. " 5<sup>th</sup> century " .. CE  },
	['Wenzi']        =  { "lzh",  "''[[w:Wenzi|Wenzi]]''" },
	['WGWSS']        =  { "lzh",  "Forged Old Text of the ''[[w:Book of Documents|Book of Documents]]'', circa 3<sup>rd</sup> – 4<sup>th</sup> century " .. CE },
	['Wuzi']         =  { "lzh",  "''[[w:Wuzi|Wuzi]]]'', 5<sup>th</sup> – 4<sup>th</sup> century " .. BCE },
	['Wuzi-S']       =  { "lzh",  "''[[w:Wuzi|Wuzi]]]'', 5<sup>th</sup> – 4<sup>th</sup> century " .. BCE .. ", translated based on Ralph D. Sawyer's version" },
    ['Xiaojing']     =  { "lzh",  "''[[w:Classic of Filial Piety|Classic of Filial Piety]]'',  circa 475 – 221 " .. BCE },
	['Xingshi Hengyan']={ "cmn-wvc", "[[w:Feng Menglong|Feng Menglong]], ''[[w:Stories to Awaken the World|Stories to Awaken the World]]'', 1627 " .. CE },
	['Xingshi Yinyuan Zhuan']={ "cmn-wvc", "Xizhou Sheng, ''[[w:Xingshi Yinyuan Zhuan|Marriage Destinies to Awaken the World]]'', 17<sup>th</sup> century " .. CE },
	['Xishuangji']   =  { "cmn-wvc", "[[w:Wang Shifu|Wang Shifu]], ''[[w:The Story of the Western Wing|The Story of the Western Wing]]'', 13<sup>th</sup> – 14<sup>th</sup> centuries " .. CE },
	['Xiyouji']      =  { "cmn-wvc", "[[w:Wu Cheng'en|Wu Cheng'en]], ''[[w:Journey to the West|Journey to the West]]'', 16<sup>th</sup> century " .. CE },
	['Xiyouji-Y']    =  { "cmn-wvc", "[[w:Wu Cheng'en|Wu Cheng'en]], ''[[w:Journey to the West|Journey to the West]]'', 16<sup>th</sup> century " .. CE .. ", translation from ''The Journey to the West'' (2012), by [[w:Anthony C. Yu|Anthony C. Yu]]" },
	['Xintangshu']   =  { "lzh-lit",  "The ''[[w:New Book of Tang|New Book of Tang]]'', 1060 " .. CE },
	['Xinyu']        =  { "lzh",  "[[w:Lu Jia (Western Han)|Lu Jia]], ''[[w:zh:新語 (中國古籍)|Xinyu]]'' (''A New Discourse''), " .. circa .. " 197 " .. BCE },
	['Xunzi']        =  { "lzh",  "''[[w:Xunzi (book)|Xunzi]]'', " .. circa .. " 3<sup>rd</sup> century " .. BCE },
	['Yantielun']    =  { "lzh",  "[[w:zh:桓寬|Huan Kuan]], ''[[w:Discourses on Salt and Iron|Discourses on Salt and Iron]]'', " .. circa .. " 1<sup>st</sup> century " .. BCE },
	['Yanshi Jiaxun']=  { "lzh-lit",  "[[w:Yan Zhitui|Yan Zhitui]], ''The Family Instructions of Master Yan'', 6<sup>th</sup> century " .. CE },
	['Yanzi Chunqiu']=  { "lzh",  "''[[w:Yanzi Chunqiu|Annals of Master Yan]]'', " .. circa .. " 3<sup>rd</sup> century " .. BCE },
	['Yijing']       =  { "lzh-pre",  "''[[w:I Ching|I Ching]]'', 11<sup>th</sup> – 8<sup>th</sup> century " .. BCE },
	['Yijing-L']     =  { "lzh-pre",  "''[[w:I Ching|I Ching]]'', 11<sup>th</sup> – 8<sup>th</sup> century " .. BCE .. ", translated based on [[w:James Legge|James Legge]]'s version" },
    ['Yili']         =  { "lzh",  "''[[w:Yili|Etiquette and Ceremonial]]'', circa 475 – 221 " .. BCE },
    ['Yili-S']       =  { "lzh",  "''[[w:Yili|Etiquette and Ceremonial]]'', circa 475 – 221 " .. BCE .. ", translated based on John Steele's version" },
	['Yilin']        =  { "lzh",  "[[w:zh:焦贛|Jiao Gong]], ''[[w:Jiaoshi Yilin|Yilin]]'', 1<sup>st</sup> century " .. BCE },
	['Yiwen Leiju']    =  { "lzh-lit",  "''[[w:Yiwen Leiju|Yiwen Leiju]]'', 624 " .. CE },
	['Yizhoushu']    =  { "lzh",  "''[[w:Yi Zhou Shu|Lost Book of Zhou]]'', circa 4<sup>th</sup> – 1<sup>st</sup> centuries " .. BCE },
	['Yuandianzhang']=  { "lzh-lit",  "''[[w:zh:元典章|Statutes of the Yuan dynasty]]'', 1322–1323 " .. CE },
	['Zhanguoce']    =  { "lzh",  "''[[w:Zhan Guo Ce|Zhanguo Ce]]'', circa 5<sup>th</sup> – 3<sup>rd</sup> centuries " .. BCE },
	['Zhanguoce-C']    =  { "lzh",  "''[[w:Zhan Guo Ce|Zhanguo Ce]]'', circa 5<sup>th</sup> – 3<sup>rd</sup> centuries " .. BCE .. ", translated based on J. I. Crump's version" },
	["Zhaoshi Gu'er"]=  { "cmn-wvc",  "'''Yuan Dynasty''', [[w:zh:紀君祥|Ji Junxiang]], ''[[w:The Orphan of Zhao|The Orphan of Zhao]]''" },
	['Zhouli']       =  { "lzh",  "''[[w:Rites of Zhou|Rites of Zhou]]'', circa 3<sup>rd</sup> century " .. BCE },
	['Zhoushu']       =  { "lzh-lit",  "'''636''' " .. CE .. ", [[w:Linghu Defen|Linghu Defen]], ''[[w:Book of Zhou|Book of Zhou]]''" },
	['Zhuangzi']     =  { "lzh",  "''[[w:Zhuangzi (book)|Zhuangzi]]'', circa 3<sup>rd</sup> – 2<sup>nd</sup> centuries " .. BCE },
	['Zhuangzi-L']   =  { "lzh",  "''[[w:Zhuangzi (book)|Zhuangzi]]'', circa 3<sup>rd</sup> – 2<sup>nd</sup> centuries " .. BCE .. ", translated based on [[w:James Legge|James Legge]]'s version" },
	['Zhuangzi-W']   =  { "lzh",  "''[[w:Zhuangzi (book)|Zhuangzi]]'', circa 3<sup>rd</sup> – 2<sup>nd</sup> centuries " .. BCE .. ", translation from ''The Complete Works Of Chuang Tzu'' (2013), by [[w:Burton Watson|Burton Watson]]" },
    ['Zhushu Jinian'] =  { "lzh",  "''[[w:Bamboo Annals|Bamboo Annals]]'',  circa 475 – 221 " .. BCE },
	['Zhuzi Jiaxun'] =  { "lzh-lit",  "[[w:zh:朱用純|Zhu Yongchun]], ''[[w:zh:朱柏廬治家格言|Zhu Zi's Family Maxims]]'', 17<sup>th</sup> century " .. CE },
	['Zhuzi Yulei'] = {"cmn-wvc", "Various editors, ''[[w:Zhuzi yulei|Collected Conversations of Master Zhu]]'', " .. circa .. " 13<sup>th</sup> century " .. CE},
	['Zibuyu']       =  { "lzh-lit",  "[[w:Yuan Mei|Yuan Mei]], ''[[w:What the Master Would Not Discuss|What the Master Would Not Discuss]]'', 1788 " .. CE },
	['Zizhi Tongjian']       =  { "lzh-lit",  "'''1084''' " .. CE .. ", [[w:Sima Guang|Sima Guang]], ''[[w:Comprehensive Mirror to Aid in Government|Comprehensive Mirror to Aid in Government]]''" },
	['Zuozhuan']     =  { "lzh",  "''[[w:Zuo zhuan|Commentary of Zuo]]'', " .. circa .. " 4<sup>th</sup> century " .. BCE },
	['Zuozhuan-D']   =  { "lzh",  "''[[w:Zuo zhuan|Commentary of Zuo]]'', " .. circa .. " 4<sup>th</sup> century " .. BCE .. ", translation from ''Zuozhuan: Commentary on the \"Spring and Autumn Annals\"'' (2017), by Stephen Durrant, Wai-yee Li and David Schaberg" },
	['Zuozhuan-L']   =  { "lzh",  "''[[w:Zuo zhuan|Commentary of Zuo]]'', " .. circa .. " 4<sup>th</sup> century " .. BCE .. ", translated based on [[w:James Legge|James Legge]]'s version" },
	
	['Mao25']      =  format_mao("1925", "中國社會各階級的分析", "Analysis of the Classes in Chinese Society", "1", "1"),
	['Mao27']      =  format_mao("1927", "[[w:zh:湖南农民运动考察报告|湖南農民運動考察報告]]", "[[w:Report on an Investigation of the Peasant Movement in Hunan|Report on an Investigation of the Peasant Movement in Hunan]]", "1", "2"),
	['Mao35']      =  format_mao("1935", "論反對日本帝國主義的策略", "On Tactics Against Japanese Imperialism", "1", "11"),
	['Mao36']      =  format_mao("1936", "中國革命戰爭的戰略問題", "Problems of Strategy in China's Revolutionary War", "1", "12"),
	['MaoSJL']     =  format_mao("1937", "[[w:zh:實踐論|實踐論]]", "[[w:On Practice|On Practice]]", "1", "16"),
	['MaoMDL']     =  format_mao("1937", "[[w:zh:矛盾論|矛盾論]]", "[[w:On Contradiction|On Contradiction]]", "1", "17"),
	['MaoZYZY']    =  format_mao("1937", "反對自由主義", "Combat Liberalism", "2", "03"),
	['Mao38']      =  format_mao("1938", "[[w:zh:論持久戰|論持久戰]]", "[[w:On Protracted War|On Protracted War]]", "2", "09"),
	['MaoZGGM']    =  format_mao("1939", "中國革命和中國共產黨", "The Chinese Revolution and the Chinese Communist Party", "2", "23"),
	['MaoXMZZY']   =  format_mao("1940", "[[w:zh:新民主主義論|新民主主義論]]", "On New Democracy", "2", "26"),
	['MaoRectify'] =  format_mao("1942", "整頓黨的作風", "Rectify the Party's Style of Work", "3", "06"),
	['MaoYanan']   =  format_mao("1942", "[[w:zh:在延安文藝座談會上的講話|在延安文藝座談會上的講話]]", "[[w:Yan'an Forum|Talks at the Yenan Forum on Literature and Art]]", "3", "08"),
	['Mao45']      =  format_mao("1945", "[[s:zh:論聯合政府|論聯合政府]]", "On Coalition Government", "3", "25"),
	['Mao56']      =  format_mao("1956", "[[w:zh:論十大關係|論十大關係]]", "[[w:Ten Major Relationships|On the Ten Major Relationships]]", "5", "51"),
	['Mao57']      =  format_mao("1957", "關於正確處理人民內部矛盾的問題", "On the Correct Handling of Contradictions Among the People", "5", "58"),
}

data.pron_correction = {
	["cmn"] = {},
	["yue"] = {
		["錢"] = "cin4",
		["道"] = "dou6",
		["稱"] = "cing1",
		["噏"] = "ngap1",
	},
	["hak"] = {
		["阿"] = "-â-",
		["媸"] = "-ché-", ["獎"] = "-chióng-", ["竹"] = "-chuk-",
		["茶"] = "chhà", ["蚻"] = "-chha̍t-", ["曾"] = "-chhèn-", ["千"] = "-chhiên-", ["竄"] = "-chhon-", ["捽"] = "-chhu̍t-",
		["仔"] = "-é-", ["𫣆"] = "-ên-",
		["客"] = "-hak-",
		["機"] = "-kî-", ["𥘹"] = "-kì-", ["溝"] = "-kiêu-", ["稿"] = "-kó-",
		["罅"] = "-la-", ["壢"] = "-lak-", ["摎"] = "-lâu-", ["㧯"] = "-lâu-", ["恅"] = "-láu-", ["俚"] = "-lî-", ["羅"] = "-lò-", ["擂"] = "-lùi-",
		["閩"] = "-mén-", ["美"] = "-mî-", ["忘"] = "-mong-", ["蚊"] = "-mûn-",
		["腦"] = "-nó-", ["濃"] = "-nùng-",
		["𠊎"] = "-ngài-", ["祢"] = "-ngì-",
		["孲"] = "-ò-", ["𡟓"] = "-ôi-",
		["錶"] = "-péu-", ["輩"] = "-pi-", ["𡜵"] = "-pû-",
		["婆"] = "-phò-",
		["使"] = "-sṳ́-", ["史"] = "-sṳ́-", ["視"] = "sṳ", ["脣"] = "-sùn-",
		["點"] = "-tiám-",
		["𢯭"] = "-then-", ["電"] = "-thien-", ["唐"] = "-thòng-", ["筒"] = "-thùng",
		["裕"] = "-yi-",
	},
	["nan-hbl"] = {
		["阿"] = "-a-", ["仔"] = "-á-", ["矣"] = "-ah-", ["啊"] = "-ah-",
		["䆀"] = "-bái-", ["袂"] = "-bē-", ["欲"] = "-beh-", ["覕"] = "-bih-", ["盟"] = "-bêng-", ["務"] = "-bū-",
		["欉"] = "-châng-", ["十"] = "-cha̍p-", ["誌"] = "-chì-", ["遮"] = "-chiah-", ["針"] = "-chiam-", ["窒"] = "-chit-", ["鯽"] = "-chit-", ["一"] = "-chi̍t-", ["睭"] = "-chiu-", ["慈"] = "-chû-", ["𠞩"] = "-chûi-",
		["𨑨"] = "-chhit-", ["𤆬"] = "-chhōa-", ["攢"] = "-chhoân-",
		["的"] = "-ê-", ["个"] = "-ê-", ["憶"] = "-ek-",
		["𠢕"] = "-gâu-", ["偌"] = "-gōa-", ["囡"] = "-gín-",
		["耳"] = "-hīⁿ-", ["予"] = "-hō͘-",
		["已"] = "-í-", ["也"] = "-iā-", ["𪜶"] = "-in-",
		["字"] = "-jī-", ["然"] = "-jiân-", ["日"] = "-ji̍t-",
		["共"] = "-kā-", ["佮"] = "-kah-", ["甲"] = "-kah-", ["矸"] = "-kan-", ["到"] = "-kàu-", ["竟"] = "kèng", ["行"] = "-kiâⁿ-", ["勼"] = "-kiu-", ["閣"] = "-koh-", ["擱"] = "-koh-", ["講"] = "-kóng-",
		["跤"] = "-kha-", ["較"] = "-khah-", ["徛"] = "-khiā-", ["課"] = "-khò",
		["人"] = "-lâng-", ["汝"] = "-lí-", ["旅"] = "-lí-", ["啉"] = "-lim-", ["暖"] = "-loán-", ["戀"] = "-loân-", ["攏"] = "-lóng-",
		["毋"] = "-m̄-", ["嬤"] = "-má-",
		["喔"] = "-o͘h-",
		["爸"] = "-pē-", ["悲"] = "-pi-",
		["麭"] = "-pháng-",
		["三"] = "-saⁿ-", ["捨"] = "-siá-", ["閃"] = "-siám-", ["雙"] = "-siang-", ["啥"] = "-siáⁿ-", ["心"] = "-sim-", ["俗"] = "-sio̍k-", ["傷"] = "-siong-", ["商"] = "-siong-", ["受"] = "-siū-", ["煞"] = "-soah-", ["士"] = "-sū-", ["雖"] = "-sui-", ["媠"] = "-súi-", ["遂"] = "-sūi-",
		["臺"] = "-tâi-", ["塊"] = "-tè-", ["咧"] = "-teh-", ["豬"] = "-ti-", ["戴"] = "-tì-", ["佇"] = "-tī-", ["典"] = "-tián-", ["躊"] = "-tiû-", ["斷"] = "-tn̄g-", ["多"] = "-to-", ["倒"] = "tó", ["拄"] = "-tú-", ["盹"] = "-tuh-", ["脣"] = "-tûn-",
		["太"] = "-thài-", ["刣"] = "-thâi-", ["讀"] = "-tha̍k-", ["窗"] = "-thang-", ["迌"] = "-thô-",
		["揻"] = "-ui-",
	},
	["wuu"] = {},
}

data.polysyllable_pron_correction = {
	["cmn"] = {
		["覺得"] = "juéde",
		["個中"] = "gèzhōng", ["個人"] = "gèrén", ["個個"] = "gègè", ["個兒"] = "gèr", ["個別"] = "gèbié", ["個子"] = "gèzi", ["個展"] = "gèzhǎn", ["個性"] = "gèxìng", ["個數"] = "gèshù", ["個案"] = "gè'àn",["個頭"] = "gètóu",  ["個體"] = "gètǐ"
	},
	["yue"] = {
		["屋企"] = "uk1 kei2", ["返屋企"] = "faan1 uk1 kei2",
		["知道"] = "zi1 dou3"
	},
	["hak"] = {
		["老鼠"] = "-lo-chhú-",
		["敗勢"] = "-phài-se-",
		["癩𰣻"] = "-thái-kô-",
		["台灣"] = "-Thòi-vàn-",
		["臺灣"] = "-Thòi-vàn-"
	},
	["nan-hbl"] = {
		["愛人"] = "-ài-jîn-",
		["饅頭"] = "-bán-thô-", ["門徒"] = "-bûn-tô͘-",
		["情批"] = "-chêng-phoe-", ["遮爾"] = "-chiah-nī-", ["這馬"] = "-chit-má-", ["作用"] = "-chok-iōng-",
		["請假"] = "-chhéng-ká-", ["親像"] = "-chhin-chhiūⁿ-",
		["偌爾"] = "-gōa-nī-",
		["一切"] = "-it-chhè-", ["一般"] = "-it-poaⁿ-", ["一直"] = "-it-ti̍t-",
		["人海"] = "-jîn-hái-", ["人生"] = "-jîn-seng-",
		["卡拉OK"] = "-kha-lá-ó͘-khe-",
		["旅行"] = "-lí-hêng-",
		["歐巴桑"] = "-o͘-bá-sáng-",
		["歹勢"] = "-pháiⁿ-sè-",
		["山珍海味"] = "-san-tin-hái-bī-", ["漩渦"] = "-soân-o-",
		["臺灣"] = "-Tâi-oân-", ["第一"] = "-tē-it-", ["的確"] = "-tek-khak-",
		["癩𰣻"] = "-thái-ko-",
	},
	["wuu"] = {},
}

return data
