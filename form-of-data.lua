local tags = {}

-- Person
tags["first-person"] = {
	tag_type = "person",
	glossary = "first person",
	shortcuts = {"1"},
	wikidata = "Q21714344",
}

tags["second-person"] = {
	tag_type = "person",
	glossary = "second person",
	shortcuts = {"2"},
	wikidata = "Q51929049",
}

tags["third-person"] = {
	tag_type = "person",
	glossary = "third person",
	shortcuts = {"3"},
	wikidata = "Q51929074",
}

tags["impersonal"] = {
	tag_type = "person",
	glossary = "impersonal",
	shortcuts = {"impers"},
}

-- Number
tags["singular"] = {
	tag_type = "number",
	glossary = "singular number",
	shortcuts = {"s"},
	wikidata = "Q110786",
}

tags["dual"] = {
	tag_type = "number",
	glossary = "dual number",
	shortcuts = {"d"},
	wikidata = "Q110022",
}

tags["trial"] = {
	tag_type = "number",
	glossary = "trial number",
	shortcuts = {"tr"},
	wikidata = "Q2142560",
}

tags["paucal"] = {
	tag_type = "number",
	glossary = "paucal number",
	shortcuts = {"pau"},
	wikidata = "Q489410",
}

tags["distributive paucal"] = {
	tag_type = "number",
	glossary = "distributive paucal number",
	shortcuts = {"dpau"},
}

tags["plural"] = {
	tag_type = "number",
	glossary = "plural number",
	shortcuts = {"p"},
	wikidata = "Q146786",
}

tags["singulative"] = {
	tag_type = "number",
	glossary = "singulative number",
	shortcuts = {"sgl"},
	wikidata = "Q1450795",
}

tags["collective"] = {
	tag_type = "number",
	glossary = "collective number",
	shortcuts = {"col"},
	wikidata = "Q694268",
}

-- Gender
tags["masculine"] = {
	tag_type = "gender",
	glossary = "gender",
	shortcuts = {"m"},
	wikidata = "Q499327",
}

tags["feminine"] = {
	tag_type = "gender",
	glossary = "gender",
	shortcuts = {"f"},
	wikidata = "Q1775415",
}

tags["neuter"] = {
	tag_type = "gender",
	glossary = "gender",
	shortcuts = {"n"},
	wikidata = "Q1775461",
}

tags["common"] = {
	tag_type = "gender",
	glossary = "gender",
	shortcuts = {"c"},
	wikidata = "Q1305037",
}

tags["virile"] = {
	tag_type = "gender",
	glossary = "virile",
	shortcuts = {"vr"},
}

tags["nonvirile"] = {
	tag_type = "gender",
	glossary = "nonvirile",
	shortcuts = {"nv"},
}

-- Animacy (may be useful sometimes for [[Module:object usage]].)
tags["animate"] = {
	tag_type = "animacy",
	glossary = "animate",
	shortcuts = {"an"},
	wikidata = "Q51927507",
}

tags["inanimate"] = {
	tag_type = "animacy",
	glossary = "inanimate",
	shortcuts = {"in"},
	wikidata = "Q51927539",
}

tags["personal"] = {
	tag_type = "animacy",
	shortcuts = {"pr"},
}

-- Tense/aspect
tags["present"] = {
	tag_type = "tense-aspect",
	glossary = "present tense",
	shortcuts = {"pres"},
	wikidata = "Q192613",
}

tags["past"] = {
	tag_type = "tense-aspect",
	glossary = "past tense",
	wikidata = "Q1994301",
}

tags["future"] = {
	tag_type = "tense-aspect",
	glossary = "future tense",
	shortcuts = {"fut", "futr"},
	wikidata = "Q501405",
}

tags["non-past"] = {
	tag_type = "tense-aspect",
	glossary = "non-past tense",
	shortcuts = {"npast"},
	wikidata = "Q16916993",
}

tags["progressive"] = {
	tag_type = "tense-aspect",
	glossary = "progressive",
	shortcuts = {"prog"},
	wikidata = "Q56653945",
}

tags["preterite"] = {
	tag_type = "tense-aspect",
	shortcuts = {"pret"},
	wikidata = "Q442485",
}

tags["perfect"] = {
	tag_type = "tense-aspect",
	glossary = "perfect",
	shortcuts = {"perf"},
	wikidata = "Q625420",
}

tags["imperfect"] = {
	tag_type = "tense-aspect",
	glossary = "imperfect",
	shortcuts = {"impf", "imperf"},
}

tags["pluperfect"] = {
	tag_type = "tense-aspect",
	shortcuts = {"plup", "pluperf"},
	wikidata = "Q623742",
}

tags["semelfactive"] = {
	tag_type = "tense-aspect",
	shortcuts = {"semf"},
	wikidata = "Q7449203",
}

tags["aorist"] = {
	tag_type = "tense-aspect",
	glossary = "aorist tense",
	shortcuts = {"aor", "aori"},
	wikidata = "Q216497",
}

tags["past historic"] = {
	tag_type = "tense-aspect",
	shortcuts = {"phis"},
}

tags["imperfective"] = {
	tag_type = "tense-aspect",
	glossary = "imperfective",
	shortcuts = {"impfv", "imperfv"},
	wikidata = "Q371427",
}

tags["perfective"] = {
	tag_type = "tense-aspect",
	glossary = "perfective",
	shortcuts = {"pfv", "perfv"},
	wikidata = "Q1424306",
}

tags["iterative"] = {
	tag_type = "tense-aspect",
	shortcuts = {"iter"},
	wikidata = "Q2866772",
}

-- Mood
tags["imperative"] = {
	tag_type = "mood",
	glossary = "imperative mood",
	shortcuts = {"imp", "impr"},
	wikidata = "Q22716",
}

tags["indicative"] = {
	tag_type = "mood",
	glossary = "indicative mood",
	shortcuts = {"ind", "indc", "indic"},
	wikidata = "Q682111",
}

tags["subjunctive"] = {
	tag_type = "mood",
	glossary = "subjunctive mood",
	shortcuts = {"sub", "subj"},
	wikidata = "Q473746",
}

tags["conditional"] = {
	tag_type = "mood",
	glossary = "conditional mood",
	shortcuts = {"cond"},
	wikidata = "Q625581",
}

tags["optative"] = {
	tag_type = "mood",
	glossary = "optative mood",
	shortcuts = {"opta", "opt"},
	wikidata = "Q527205",
}

tags["potential"] = {
	tag_type = "mood",
	shortcuts = {"potn"},
	wikidata = "Q2296856",
}

tags["jussive"] = {
	tag_type = "mood",
	glossary = "jussive mood",
	shortcuts = {"juss"},
	wikidata = "Q462367",
}

tags["cohortative"] = {
	tag_type = "mood",
	shortcuts = {"coho", "cohort"},
}

tags["volitive"] = {
	tag_type = "mood",
	shortcuts = {"voli"},
	wikidata = "Q10716592",
}

-- Exists at least in Estonian
tags["quotative"] = {
	tag_type = "mood",
	glossary = "quotative mood",
	shortcuts = {"quot"},
	wikidata = "Q7272884",
}

-- Voice
tags["active"] = {
	tag_type = "voice",
	glossary = "active voice",
	shortcuts = {"act", "actv"},
	wikidata = "Q1317831",
}

tags["middle"] = {
	tag_type = "voice",
	glossary = "middle voice",
	shortcuts = {"mid", "midl"},
}

tags["passive"] = {
	tag_type = "voice",
	glossary = "passive voice",
	shortcuts = {"pass", "pasv"},
	wikidata = "Q1194697",
}

tags["mediopassive"] = {
	tag_type = "voice",
	glossary = "mediopassive",
	shortcuts = {"mp", "mpsv"},
	wikidata = "Q1601545",
}

-- Non-finite
tags["infinitive"] = {
	tag_type = "non-finite",
	shortcuts = {"inf"},
	wikidata = "Q179230",
}

tags["participle"] = {
	tag_type = "non-finite",
	glossary = "participle",
	shortcuts = {"part", "ptcp"},
	wikidata = "Q814722",
}

tags["converb"] = {
	tag_type = "non-finite",
	wikidata = "Q149761",
}

tags["possessive"] = {
	tag_type = "non-finite",
	shortcuts = {"poss"},
	wikidata = "Q2105891",
}

tags["negative"] = {
	tag_type = "non-finite",
	shortcuts = {"neg"},
}

tags["connegative"] = {
	tag_type = "non-finite",
	shortcuts = {"conn", "conneg"},
	wikidata = "Q5161718",
}

tags["supine"] = {
	tag_type = "non-finite",
	glossary = "supine",
	shortcuts = {"sup"},
	wikidata = "Q548470",
}

-- Cases
tags["abessive"] = {
	tag_type = "case",
	shortcuts = {"abe"},
	wikidata = "Q319822",
}

tags["ablative"] = {
	tag_type = "case",
	glossary = "ablative case",
	shortcuts = {"abl"},
	wikidata = "Q156986",
}

tags["absolutive"] = {
	tag_type = "case",
	shortcuts = {"abs"},
	wikidata = "Q332734",
}

tags["accusative"] = {
	tag_type = "case",
	glossary = "accusative case",
	shortcuts = {"acc"},
	wikidata = "Q146078",
}

tags["adessive"] = {
	tag_type = "case",
	shortcuts = {"ade"},
	wikidata = "Q281954",
}

tags["adjectival"] = {
	tag_type = "case",
	shortcuts = {"adj"},
}

tags["adverbial"] = {
	tag_type = "case",
	glossary = "adverbial",
	shortcuts = {"adv"},
}

tags["allative"] = {
	tag_type = "case",
	shortcuts = {"all"},
	wikidata = "Q655020",
}

tags["anterior"] = {
	tag_type = "case",
	shortcuts = {"ant"},
}

tags["associative"] = {
	tag_type = "case",
	shortcuts = {"ass", "assoc"},
	wikidata = "Q15948746",
}

tags["causal-final"] = {
	tag_type = "case",
	shortcuts = {"cfi", "cfin"},
	wikidata = "Q18012653",
}

tags["comitative"] = {
	tag_type = "case",
	shortcuts = {"com"},
	wikidata = "Q838581",
}

-- be careful not to clash with comparative degree
tags["comparative case"] = {
	tag_type = "case",
	display = "comparative",
	shortcuts = {"comc"},
	wikidata = "Q5155633",
}

tags["dative"] = {
	tag_type = "case",
	glossary = "dative case",
	shortcuts = {"dat"},
	wikidata = "Q145599",
}

tags["delative"] = {
	tag_type = "case",
	shortcuts = {"del"},
	wikidata = "Q1183901",
}

tags["direct"] = {
	tag_type = "case",
	shortcuts = {"dir"},
	wikidata = "Q1751855",
}

tags["distributive"] = {
	tag_type = "case",
	shortcuts = {"dis", "dist"},
	wikidata = "Q492457",
}

tags["elative"] = {
	tag_type = "case",
	glossary = "elative case",
	shortcuts = {"ela"},
	wikidata = "Q394253",
}

tags["ergative"] = {
	tag_type = "case",
	glossary = "ergative case",
	shortcuts = {"erg"},
	wikidata = "Q324305",
}

tags["essive-formal"] = {
	tag_type = "case",
	shortcuts = {"esf", "efor"},
	wikidata = "Q3827688",
}

tags["essive-modal"] = {
	tag_type = "case",
	shortcuts = {"esm", "emod"},
	wikidata = "Q3827703",
}

tags["essive"] = {
	tag_type = "case",
	shortcuts = {"ess"},
	wikidata = "Q148465",
}

tags["exclusive"] = {
	tag_type = "case",
	shortcuts = {"exc", "excl"},
}

tags["genitive"] = {
	tag_type = "case",
	glossary = "genitive case",
	shortcuts = {"gen"},
	wikidata = "Q146233",
}

tags["illative"] = {
	tag_type = "case",
	shortcuts = {"ill"},
	wikidata = "Q474668",
}

tags["inessive"] = {
	tag_type = "case",
	shortcuts = {"ine"},
	wikidata = "Q282031",
}

tags["instructive"] = {
	tag_type = "case",
	shortcuts = {"ist"},
	wikidata = "Q1665275",
}

tags["instrumental"] = {
	tag_type = "case",
	glossary = "instrumental case",
	shortcuts = {"ins"},
	wikidata = "Q192997",
}

tags["limitative"] = {
	tag_type = "case",
	glossary = "limitative case",
	shortcuts = {"lim"},
	wikidata = "Q35870079",
}

tags["locative"] = {
	tag_type = "case",
	glossary = "locative case",
	shortcuts = {"loc"},
	wikidata = "Q202142",
}

tags["locative-qualitative"] = {
	tag_type = "case",
	glossary = "locative-qualitative case",
	shortcuts = {"lqu", "lqua"},
}

tags["nominative"] = {
	tag_type = "case",
	glossary = "nominative case",
	shortcuts = {"nom"},
	wikidata = "Q131105",
}

tags["objective"] = {
	tag_type = "case",
	glossary = "objective case",
	shortcuts = {"obj"},
	wikidata = "Q1233197",  -- Same as oblique. Wikipedia considers them the same thing, but we want to allow users to choose their own terminology.
}

tags["oblique"] = {
	tag_type = "case",
	glossary = "oblique case",
	shortcuts = {"obl"},
	wikidata = "Q1233197",
}

tags["partitive"] = {
	tag_type = "case",
	glossary = "partitive case",
	shortcuts = {"par"},
	wikidata = "Q857325",
}

tags["prolative"] = {
	tag_type = "case",
	shortcuts = {"pro"},
	wikidata = "Q952933",
}

tags["prepositional"] = {
	tag_type = "case",
	glossary = "prepositional case",
	shortcuts = {"pre", "prep"},
	wikidata = "Q2114906",
}

tags["sociative"] = {
	tag_type = "case",
	glossary = "sociative case",
	shortcuts = {"soc"},
	wikidata = "Q3773161",
}

tags["sublative"] = {
	tag_type = "case",
	shortcuts = {"sbl"},
	wikidata = "Q2120615",
}

tags["superessive"] = {
	tag_type = "case",
	shortcuts = {"spe"},
	wikidata = "Q222355",
}

tags["temporal"] = {
	tag_type = "case",
	shortcuts = {"tem", "temp"},
	wikidata = "Q3235219",
}

tags["terminative"] = {
	tag_type = "case",
	shortcuts = {"ter", "term"},
	wikidata = "Q747019",
}

tags["translative"] = {
	tag_type = "case",
	shortcuts = {"tra", "tran"},
	wikidata = "Q950170",
}

tags["vocative"] = {
	tag_type = "case",
	glossary = "vocative case",
	shortcuts = {"voc"},
	wikidata = "Q185077",
}

-- State
tags["construct"] = {
	tag_type = "state",
	glossary = "construct state",
	shortcuts = {"cons", "construct state"},
	wikidata = "Q1641446",
}

tags["definite"] = {
	tag_type = "state",
	glossary = "definite",
	shortcuts = {"def", "defn", "definite state"},
	wikidata = "Q53997851",
}

tags["indefinite"] = {
	tag_type = "state",
	glossary = "indefinite",
	shortcuts = {"indef", "indf", "indefinite state"},
	wikidata = "Q53997857",
}

tags["attributive"] = {
	tag_type = "state",
	glossary = "attributive",
	shortcuts = {"attr"},
}

tags["predicative"] = {
	tag_type = "state",
	shortcuts = {"pred"},
}

-- Degrees of comparison
tags["comparative degree"] = {
	tag_type = "comparison",
	glossary = "comparative",
	shortcuts = {"comd", "comparative"},
	wikidata = "Q14169499",
}

tags["superlative degree"] = {
	tag_type = "comparison",
	glossary = "superlative",
	shortcuts = {"supd", "superlative"},
	wikidata = "Q1817208",
}

tags["elative degree"] = {
	tag_type = "comparison",
	glossary = "elative",
	shortcuts = {"elad"},  -- Can't use "elative" as shortcut because that's already used for the elative case
	wikidata = "Q1555419",
}

tags["equative degree"] = {
	tag_type = "comparison",
	shortcuts = {"equd", "equative"},
	wikidata = "Q5384239",
}

-- Sound changes
tags["contracted"] = {
	tag_type = "sound change",
}

-- Other tags
tags["and"] = {
	tag_type = "other",
}

local shortcuts = {}

-- Create the shortcuts list
for name, data in pairs(tags) do
	if data.shortcuts then
		for _, shortcut in ipairs(data.shortcuts) do
			-- If the shortcut is already in the list, then there is a duplicate.
			if shortcuts[shortcut] then
				error("The shortcut \"" .. shortcut .. "\" (for the grammar tag \"" .. name .. "\") conflicts with an existing shortcut for the tag \"" .. shortcuts[shortcut] .. "\".")
			elseif tags[shortcut] then
				error("The shortcut \"" .. shortcut .. "\" (for the grammar tag \"" .. name .. "\") conflicts with an existing tag with that name.")
			end
			
			shortcuts[shortcut] = name
		end
	end
end

return {tags = tags, shortcuts = shortcuts}
