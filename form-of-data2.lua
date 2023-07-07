--[=[

This module lists the less common recognized inflection tags, in the same
format as for [[Module:form of/data]] (which contains the more common tags).
We split the tags this way to save memory, so we avoid loading the less common
tags in the majority of cases.
]=]

local tags = {}
local shortcuts = {}


----------------------- Person -----------------------

tags["fourth-person"] = {
	tag_type = "person",
	glossary = "fourth person",
	glossary_type = "wikt",
	shortcuts = {"4"},
	wikidata = "Q3348541",
}

tags["second-person-object form"] = {
	tag_type = "person",
	glossary = "second-person-object form",
	shortcuts = {"2o"},
}

----------------------- Number -----------------------

tags["associative plural"] = {
	tag_type = "number",
	glossary = "associative plural",
	glossary_type = "wikt",
	shortcuts = {"ass p", "ass pl", "assoc p", "assoc pl"},
}

tags["collective"] = {
	tag_type = "number",
	glossary = "collective number",
	shortcuts = {"col"},
	wikidata = "Q694268",
}

tags["collective-possession"] = {
	tag_type = "number",
	glossary = "collective number",
	shortcuts = {"cpos", "colpos"},
}

tags["distributive paucal"] = {
	tag_type = "number",
	glossary = "distributive paucal",
	glossary_type = "wikt",
	shortcuts = {"dpau"},
}

tags["paucal"] = {
	tag_type = "number",
	glossary = "paucal",
	glossary_type = "wikt",
	shortcuts = {"pau"},
	wikidata = "Q489410",
}

tags["singulative"] = {
	tag_type = "number",
	glossary = "singulative number",
	shortcuts = {"sgl"},
	wikidata = "Q1450795",
}

tags["transnumeral"] = {
	tag_type = "number",
	display = "singular or plural",
	glossary = "transnumeral",
	shortcuts = {"trn"},
	wikidata = "Q113631596",
}

tags["trial"] = {
	tag_type = "number",
	glossary = "trial number",
	shortcuts = {"tri"},
	wikidata = "Q2142560",
}


----------------------- Gender -----------------------

tags["natural feminine"] = {
	tag_type = "gender",
	glossary = "gender",
	shortcuts = {"natf"},
}

tags["virile"] = {
	tag_type = "gender",
	glossary = "virile",
	shortcuts = {"vr"},
}


----------------------- Animacy -----------------------


----------------------- Tense/aspect -----------------------

tags["abtemporal"] = {
	tag_type = "tense-aspect",
	glossary = "abtemporal",
	glossary_type = "wikt",
	shortcuts = {"abtemp"},
}

tags["anterior"] = {
	tag_type = "tense-aspect",
	glossary = "relative and absolute tense",
	glossary_type = "wp",
	shortcuts = {"ant"},
}

tags["cessative"] = {
	tag_type = "tense-aspect",
	glossary = "cessative",
	glossary_type = "wp",
	shortcuts = {"cess"},
	wikidata = "Q17027342",
}

-- Aspect in Tagalog; presumably similar to the perfect tense/aspect but
-- not necessarily similar enough to use the same Wikidata ID
tags["complete"] = {
	tag_type = "tense-aspect",
	glossary = "Tagalog grammar#Aspect",
	glossary_type = "wp",
	shortcuts = {"compl"},
}

tags["concomitant"] = {
	tag_type = "tense-aspect",
	glossary = "concomitant",
	glossary_type = "wikt",
	shortcuts = {"concom"},
}

tags["confirmative"] = {
	tag_type = "tense-aspect",
	glossary = "confirmative",
	glossary_type = "wikt",
	shortcuts = {"conf"},
}

-- Aspect in Tagalog
tags["contemplative"] = {
	tag_type = "tense-aspect",
	glossary = "Tagalog grammar#Aspect",
	glossary_type = "wp",
	shortcuts = {"contem"},
}

tags["contemporal"] = {
	tag_type = "tense-aspect",
	glossary = "contemporal",
	glossary_type = "wikt",
	shortcuts = {"contemp"},
}

tags["continuative"] = {
	tag_type = "tense-aspect",
	glossary = "continuative",
	glossary_type = "wp",
	wikidata = "Q28130104",
}

tags["continuous"] = {
	tag_type = "tense-aspect",
	glossary = "continuous aspect",
	glossary_type = "wp",
	shortcuts = {"cont"},
	wikidata = "Q12721117",
}

tags["delimitative"] = {
	tag_type = "tense-aspect",
	glossary = "Delimitative aspect",
	glossary_type = "wp",
	shortcuts = {"delim"},
	wikidata = "Q5316270",
}

tags["durative"] = {
	tag_type = "tense-aspect",
	glossary = "Durative",
	glossary_type = "wp",
	shortcuts = {"dur"},
}

tags["futuritive"] = {
	tag_type = "tense-aspect",
	glossary = "futuritive",
	glossary_type = "wp",
	shortcuts = {"futv", "futrv"},
}

tags["frequentative"] = {
	tag_type = "tense-aspect",
	glossary = "frequentative",
	glossary_type = "wp",
	shortcuts = {"freq"},
	wikidata = "Q467562",
}

tags["habitual"] = {
	tag_type = "tense-aspect",
	glossary = "habitual aspect",
	glossary_type = "wp",
	shortcuts = {"hab"},
	wikidata = "Q5636904",
}

-- same as the habitual; used in Mongolian linguistics
tags["habitive"] = {
	tag_type = "tense-aspect",
	glossary = "habitive",
	glossary_type = "wp",
	shortcuts = {"habv"},
}

tags["immediative"] = {
	tag_type = "tense-aspect",
	glossary = "immediative",
	glossary_type = "wikt",
	shortcuts = {"imm", "immed"},
}

tags["incidental"] = {
	tag_type = "tense-aspect",
	glossary = "incidental",
	glossary_type = "wikt",
	shortcuts = {"incid"},
}

tags["iterative"] = {
	tag_type = "tense-aspect",
	glossary = "iterative aspect",
	glossary_type = "wp",
	shortcuts = {"iter"},
	wikidata = "Q2866772",
}

tags["momentane"] = {
	tag_type = "tense-aspect",
	glossary = "momentane",
	glossary_type = "wp",
	wikidata = "Q6897160",
}

tags["momentaneous"] = {
	tag_type = "tense-aspect",
	glossary = "momentaneous",
	glossary_type = "wikt",
	shortcuts = {"mom"},
	wikidata = "Q115110791",
}

tags["posterior"] = {
	tag_type = "tense-aspect",
	glossary = "relative and absolute tense",
	glossary_type = "wp",
	shortcuts = {"post"},
}

tags["preconditional"] = {
	tag_type = "tense-aspect",
	glossary = "preconditional",
	glossary_type = "wikt",
	shortcuts = {"precond"},
}

-- Type of participle in Hindi; also called agentive or agentive-prospective
tags["prospective"] = {
	tag_type = "tense-aspect",
	glossary = "prospective aspect",
	glossary_type = "wp",
	shortcuts = {"pros"},
}

tags["purposive"] = {
	tag_type = "tense-aspect",
	glossary = "purposive",
	glossary_type = "wikt",
	shortcuts = {"purp"},
}

-- Aspect in Tagalog; presumably similar to the perfect tense/aspect but
-- not necessarily similar enough to use the same Wikidata ID
tags["recently complete"] = {
	tag_type = "tense-aspect",
	glossary = "Tagalog grammar#Aspect",
	glossary_type = "wp",
	shortcuts = {"rcompl"},
}

tags["resultative"] = {
	tag_type = "tense-aspect",
	glossary = "resultative",
	glossary_type = "wp",
	shortcuts = {"res"},
	wikidata = "Q7316356",
}

tags["semelfactive"] = {
	tag_type = "tense-aspect",
	glossary = "semelfactive",
	glossary_type = "wp",
	shortcuts = {"semf"},
	wikidata = "Q7449203",
}

tags["serial"] = {
	tag_type = "tense-aspect",
	glossary = "serial",
	glossary_type = "wikt",
	shortcuts = {"ser"},
}

tags["successive"] = {
	tag_type = "tense-aspect",
	glossary = "successive",
	glossary_type = "wikt",
	shortcuts = {"succ"},
}

-- be careful not to clash with terminative case tag
tags["terminative aspect"] = {
	tag_type = "tense-aspect",
	display = "terminative",
	glossary = "Cessative aspect",
	glossary_type = "wp",
	shortcuts = {"term"},
}

----------------------- Mood -----------------------

tags["benedictive"] = {
	tag_type = "mood",
	glossary = "benedictive",
	glossary_type = "wp",
	shortcuts = {"bened"},
	wikidata = "Q4887358",
}

tags["cohortative"] = {
	tag_type = "mood",
	glossary = "cohortative mood",
	glossary_type = "wp",
	shortcuts = {"coho", "cohort"},
}

tags["concessive"] = {
	tag_type = "mood",
	glossary = "concessive",
	glossary_type = "wikt",
	shortcuts = {"conc"},
}

tags["contrafactual"] = {
	tag_type = "mood",
	glossary = "contrafactual",
	glossary_type = "wikt",
	shortcuts = {"cfact"},
	wikidata = "Q110323459"
}

-- Same as the contrafactual, but terminology depends on language.
tags["counterfactual"] = {
	tag_type = "mood",
	glossary = "counterfactual",
	glossary_type = "wp",
	shortcuts = {"counterf"},
	-- the following is for "counterfactual conditional"
	wikidata = "Q1783264",
}

tags["desiderative"] = {
	tag_type = "mood",
	glossary = "desiderative",
	glossary_type = "wp",
	shortcuts = {"des", "desid"},
	wikidata = "Q1200631",
}

tags["dubitative"] = {
	tag_type = "mood",
	glossary = "dubitative mood",
	glossary_type = "wp",
	shortcuts = {"dub"},
	wikidata = "Q1263049",
}

tags["energetic"] = {
	tag_type = "mood",
	glossary = "energetic mood",
	glossary_type = "wp",
	shortcuts = {"ener"},
}

tags["inferential"] = {
	tag_type = "mood",
	glossary = "inferential mood",
	glossary_type = "wp",
	shortcuts = {"infer", "infr"},
	-- Per [[w:Inferential mood]], also called "renarrative mood" or
	-- (in Estonian) "oblique mood" (but "renarrative mood" may be different,
	-- see its entry).
	wikidata = "Q3332616",
}

-- It's not clear that this is exactly a mood, but I'm not sure where
-- else to group it
tags["intensive"] = {
	tag_type = "mood",
	glossary = "intensive",
	glossary_type = "wp",
	shortcuts = {"inten"},
	-- the following is for "intensive word form"
	wikidata = "Q10965321",
}

tags["intentional"] = {
	tag_type = "mood",
	glossary = "intentional",
	glossary_type = "wikt",
	shortcuts = {"intent"},
}

tags["interrogative"] = {
	tag_type = "mood",
	glossary = "interrogative",
	glossary_type = "wp",
	shortcuts = {"interr", "interrog"},
	wikidata = "Q12021746",
}

tags["necessitative"] = {
	tag_type = "mood",
	glossary = "necessitative",
	glossary_type = "wikt",
	shortcuts = {"nec"},
}

tags["permissive"] = {
	tag_type = "mood",
	glossary = "permissive mood",
	glossary_type = "wp",
	shortcuts = {"perm"},
	wikidata = "Q4351483",
}

tags["potential"] = {
	tag_type = "mood",
	glossary = "potential mood",
	glossary_type = "wp",
	shortcuts = {"potn"},
	wikidata = "Q2296856",
}

tags["precative"] = {
	tag_type = "mood",
	glossary = "precative",
	glossary_type = "wikt",
	shortcuts = {"prec"},
}

tags["prescriptive"] = {
	tag_type = "mood",
	glossary = "prescriptive",
	glossary_type = "wikt",
	shortcuts = {"prescr"},
}

tags["presumptive"] = {
	tag_type = "mood",
	glossary = "presumptive mood",
	glossary_type = "wp",
	shortcuts = {"presump"},
	wikidata = "Q25463575",
}

-- Exists at least in Estonian
tags["quotative"] = {
	tag_type = "mood",
	glossary = "quotative evidential mood",
	glossary_type = "wp",
	shortcuts = {"quot"},
	-- wikidata = "Q7272884", this is for "quotative" morphemes, not the same
}

tags["renarrative"] = {
	tag_type = "mood",
	glossary = "renarrative mood",
	glossary_type = "wp",
	shortcuts = {"renarr"},
	-- Per [[w:Inferential mood]], renarrative and inferential mood are the
	-- same; but per [[w:Bulgarian verbs#Evidentials]], they are different,
	-- and Bulgarian has both.
	wikidata = "Q3332616",
}

tags["volitive"] = {
	tag_type = "mood",
	glossary = "volitive mood",
	glossary_type = "wp",
	shortcuts = {"voli"},
	wikidata = "Q10716592",
}

tags["voluntative"] = {
	tag_type = "mood",
	glossary = "voluntative",
	glossary_type = "wikt",
	shortcuts = {"voln", "volun"},
}


----------------------- Voice/valence -----------------------

tags["antipassive"] = {
	tag_type = "voice-valence",
	glossary = "antipassive voice",
	glossary_type = "wp",
	shortcuts = {"apass", "apasv", "apsv"},
	wikidata = "Q287232",
}

tags["applicative"] = {
	tag_type = "voice-valence",
	glossary = "applicative voice",
	glossary_type = "wp",
	shortcuts = {"appl"},
	wikidata = "Q621634",
}

tags["cooperative"] = { -- ("all together") used in Mongolian
	tag_type = "voice-valence",
	glossary = "cooperative voice",
	glossary_type = "wikt",
	shortcuts = {"coop"},
	wikidata = "Q114033228",
}

tags["pluritative"] = { -- ("many together") used in Mongolian
	tag_type = "voice-valence",
	glossary = "pluritative voice",
	glossary_type = "wikt",
	shortcuts = {"plur"},
	wikidata = "Q114033289",
}

tags["reciprocal"] = {
	tag_type = "voice-valence",
	glossary = "reciprocal (grammar)",
	glossary_type = "wp",
	shortcuts = {"recp", "recip"},
	wikidata = "Q1964083",
}

-- Specific to Modern Irish, similar to impersonal
tags["autonomous"] = {
	tag_type = "voice-valence",
	glossary = "autonomous",
	glossary_type = "wikt",
	shortcuts = {"auton"},
}


----------------------- Non-finite -----------------------

-- be careful not to clash with agentive case tag
tags["agentive"] = {
	tag_type = "non-finite",
	glossary = "Agent noun",
	glossary_type = "wp",
	shortcuts = {"ag", "agent"},
}

-- Latin etc.
tags["gerundive"] = {
	tag_type = "non-finite",
	glossary = "gerundive",
	glossary_type = "wp",
	shortcuts = {"gerv"},
	-- Wikidata claims this is a grammatical mood, which is
	-- not really correct
	wikidata = "Q731298",
}

-- Lithuanian etc.
tags["participle of necessity"] = {
	tag_type = "non-finite",
	glossary = "gerundive",
	glossary_type = "wp",
	shortcuts = {"partnec"},
	wikidata = "Q731298", -- gerundive
}

-- Old Irish etc.
tags["verbal of necessity"] = {
	tag_type = "non-finite",
	glossary = "gerundive",
	glossary_type = "wp",
	shortcuts = {"verbnec"},
	wikidata = "Q731298", -- gerundive
}

-- Lithuanian-specific adverbial participle type; native term normally
-- used in English
tags["būdinys"] = {
	tag_type = "non-finite",
	glossary = "būdinys",
	glossary_type = "wikt",
	shortcuts = {"budinys"},
}

-- Lithuanian-specific adverbial participle type; native term normally
-- used in English
tags["padalyvis"] = {
	tag_type = "non-finite",
	glossary = "padalyvis",
	glossary_type = "wikt",
}

-- Lithuanian-specific adverbial participle type; native term normally
-- used in English
tags["pusdalyvis"] = {
	tag_type = "non-finite",
	glossary = "pusdalyvis",
	glossary_type = "wikt",
}

tags["l-participle"] = {
	tag_type = "non-finite",
	glossary = "participle",
	shortcuts = {"l-ptcp", "lptcp"},
	wikidata = "Q814722",  -- "participle"
}

-- Finnish agent participle
tags["agent participle"] = {
	tag_type = "non-finite",
	glossary = "Finnish grammar#Agent participle",
	glossary_type = "wp",
	shortcuts = {"agentpart"},
}

-- Hungarian participle
tags["verbal participle"] = {
	tag_type = "non-finite",
	glossary = "verbal participle",
	glossary_type = "wikt",
	wikidata = "Q2361676", -- attributive verb, aka verbal participle
}

tags["converb"] = {
	tag_type = "non-finite",
	glossary = "converb",
	glossary_type = "wp",
	shortcuts = {"conv"},
	wikidata = "Q149761",
}

tags["connegative"] = {
	tag_type = "non-finite",
	glossary = "connegative",
	shortcuts = {"conn", "conneg"},
	wikidata = "Q5161718",
}

-- Occurs in Hindi as a type of participle used to conjoin two clauses;
-- similarly occurs in Japanese as the "te-form"
tags["conjunctive"] = {
	tag_type = "non-finite",
	-- FIXME! No good link for "conjunctive"; another possibility is "converb"
	glossary = "serial verb construction",
	glossary_type = "wp",
	shortcuts = {"conj"},
}

tags["absolutive verb form"] = {
	tag_type = "non-finite",
	display = "absolutive",
	glossary = "absolutive#Noun",
	glossary_type = "wikt",
	shortcuts = {"absvf"},
}

-- FIXME! Should this be a mood?
tags["debitive"] = {
	tag_type = "non-finite",
	glossary = "debitive",
	glossary_type = "wp",
	shortcuts = {"deb"},
	wikidata = "Q17119041",
}


----------------------- Case -----------------------

tags["abessive"] = {
	tag_type = "case",
	glossary = "abessive case",
	glossary_type = "wp",
	shortcuts = {"abe"},
	wikidata = "Q319822",
}

tags["absolutive"] = {
	tag_type = "case",
	glossary = "absolutive case",
	glossary_type = "wp",
	-- FIXME, find uses of "abs" = absolutive
	shortcuts = {"absv"},
	wikidata = "Q332734",
}

tags["adessive"] = {
	tag_type = "case",
	glossary = "adessive case",
	glossary_type = "wp",
	shortcuts = {"ade"},
	wikidata = "Q281954",
}

-- be careful not to clash with adverbial grammar tag
tags["adverbial case"] = {
	tag_type = "case",
	display = "adverbial",
	glossary = "adverbial case",
	glossary_type = "wp",
	shortcuts = {"advc"},
}

-- be careful not to clash with agentive non-finite tag
tags["agentive case"] = {
	tag_type = "case",
	display = "agentive",
	glossary = "agentive case",
	glossary_type = "wp",
	shortcuts = {"agc"},
}

tags["allative"] = {
	tag_type = "case",
	glossary = "allative case",
	glossary_type = "wikt",
	shortcuts = {"all"},
	wikidata = "Q655020",
}

--No evidence of the existence of this case on the web, and the
--shortcuts are better used elsewhere.
--tags["anterior"] = {
--	tag_type = "case",
--	shortcuts = {"ant"},
--}

tags["associative"] = {
	tag_type = "case",
	glossary = "associative case",
	glossary_type = "wp",
	shortcuts = {"ass", "assoc"},
	wikidata = "Q15948746",
}

tags["benefactive"] = {
	tag_type = "case",
	glossary = "benefactive case",
	glossary_type = "wp",
	shortcuts = {"ben", "bene"},
	wikidata = "Q664905",
}

tags["causal"] = {
	tag_type = "case",
	glossary = "causal case",
	glossary_type = "wp",
	shortcuts = {"cauc", "causc"},
	wikidata = "Q2943136",
}

tags["causal-final"] = {
	tag_type = "case",
	glossary = "causal-final case",
	glossary_type = "wp",
	shortcuts = {"cfi", "cfin"},
	wikidata = "Q18012653",
}

tags["comitative"] = {
	tag_type = "case",
	glossary = "comitative case",
	glossary_type = "wp",
	shortcuts = {"com"},
	wikidata = "Q838581",
}

-- be careful not to clash with comparative degree
tags["comparative case"] = {
	tag_type = "case",
	display = "comparative",
	glossary = "comparative case",
	glossary_type = "wp",
	shortcuts = {"comc"},
	wikidata = "Q5155633",
}

tags["delative"] = {
	tag_type = "case",
	glossary = "delative case",
	glossary_type = "wp",
	shortcuts = {"del"},
	wikidata = "Q1183901",
}

tags["direct"] = {
	tag_type = "case",
	glossary = "direct case",
	glossary_type = "wp",
	shortcuts = {"dir"},
	wikidata = "Q1751855",
}

tags["directive"] = {
	tag_type = "case",
	glossary = "directive case",
	glossary_type = "wikt",
	shortcuts = {"dirc"},
	wikidata = "Q56526905",
}

tags["distributive"] = {
	tag_type = "case",
	glossary = "distributive case",
	glossary_type = "wp",
	shortcuts = {"dis", "dist", "distr"},
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

-- be careful not to clash with equative degree tag
tags["equative"] = {
	tag_type = "case",
	glossary = "equative case",
	glossary_type = "wp",
	shortcuts = {"equc"},
	wikidata = "Q3177653"
}

tags["essive-formal"] = {
	tag_type = "case",
	glossary = "essive-formal case",
	glossary_type = "wp",
	shortcuts = {"esf", "efor"},
	wikidata = "Q3827688",
}

tags["essive-modal"] = {
	tag_type = "case",
	glossary = "essive-modal case",
	glossary_type = "wp",
	shortcuts = {"esm", "emod"},
	wikidata = "Q3827703",
}

tags["essive"] = {
	tag_type = "case",
	glossary = "essive case",
	glossary_type = "wp",
	shortcuts = {"ess"},
	wikidata = "Q148465",
}

--No evidence of the existence of this case on the web, and the
--shortcuts are better used elsewhere.
--tags["exclusive"] = {
--	tag_type = "case",
--	shortcuts = {"exc", "excl"},
--}

tags["illative"] = {
	tag_type = "case",
	glossary = "illative case",
	glossary_type = "wp",
	shortcuts = {"ill"},
	wikidata = "Q474668",
}

tags["indirect"] = {
	tag_type = "case",
	glossary = "direct case",
	glossary_type = "wp",
	shortcuts = {"indir"},
	-- Same as oblique.
	wikidata = "Q1233197",
}

tags["inessive"] = {
	tag_type = "case",
	glossary = "inessive case",
	glossary_type = "wp",
	shortcuts = {"ine"},
	wikidata = "Q282031",
}

tags["instructive"] = {
	tag_type = "case",
	glossary = "instructive case",
	glossary_type = "wp",
	shortcuts = {"ist"},
	wikidata = "Q1665275",
}

tags["lative"] = {
	tag_type = "case",
	glossary = "lative case",
	glossary_type = "wp",
	shortcuts = {"lat"},
	wikidata = "Q260425",
}

tags["limitative"] = {
	tag_type = "case",
	glossary = "list of grammatical cases",
	glossary_type = "wp",
	shortcuts = {"lim"},
	wikidata = "Q35870079",
}

tags["locative-qualitative"] = {
	tag_type = "case",
	glossary = "locative-qualitative case",
	shortcuts = {"lqu", "lqua"},
}

tags["objective"] = {
	tag_type = "case",
	glossary = "objective case",
	shortcuts = {"objv"}, -- obj used for "object"
	-- Same as oblique.
	wikidata = "Q1233197",
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
	glossary_type = "wp",
	shortcuts = {"ptv", "par"},
	wikidata = "Q857325",
}
--certain languages use this term for the abessive
tags["privative"] = {
	tag_type = "case",
	glossary = "privative case",
	glossary_type = "wp",
	shortcuts = {"priv"},
	wikidata = "Q319822",
}

tags["prolative"] = {
	tag_type = "case",
	glossary = "prolative case",
	glossary_type = "wp",
	shortcuts = {"pro", "prol"},
	wikidata = "Q952933",
}

tags["sociative"] = {
	tag_type = "case",
	glossary = "sociative case",
	glossary_type = "wp",
	shortcuts = {"soc"},
	wikidata = "Q3773161",
}

tags["subjective"] = {
	tag_type = "case",
	glossary = "subjective case",
	glossary_type = "wp",
	-- "sub" and "subj" used for subjunctive, "sbj" for "subject"
	shortcuts = {"subjv", "sbjv"},
	-- Same as nominative.
	wikidata = "Q131105",
}

tags["sublative"] = {
	tag_type = "case",
	glossary = "sublative case",
	glossary_type = "wp",
	shortcuts = {"sbl", "subl"},
	wikidata = "Q2120615",
}

tags["superessive"] = {
	tag_type = "case",
	glossary = "superessive case",
	glossary_type = "wp",
	shortcuts = {"spe", "supe"},
	wikidata = "Q222355",
}

tags["temporal"] = {
	tag_type = "case",
	glossary = "temporal case",
	glossary_type = "wp",
	shortcuts = {"tem", "temp"},
	wikidata = "Q3235219",
}

-- be careful not to clash with terminative aspect tag
tags["terminative case"] = {
	tag_type = "case",
	display = "terminative",
	glossary = "terminative case",
	glossary_type = "wp",
	shortcuts = {"ter"},
	wikidata = "Q747019",
}

tags["translative"] = {
	tag_type = "case",
	glossary = "translative case",
	glossary_type = "wp",
	shortcuts = {"tra", "tran"},
	wikidata = "Q950170",
}


----------------------- State -----------------------

tags["independent genitive"] = {
	tag_type = "state",
	glossary = "independent genitive",
	glossary_type = "wikt",
	shortcuts = {"indgen"},
}

tags["possessor"] = {
	tag_type = "state",
	glossary = "possessor",
	glossary_type = "wikt",
	shortcuts = {"posr", "possr"},
}

tags["reflexive possessive"] = {
	tag_type = "state",
	glossary = "reflexive possessive",
	glossary_type = "wikt",
	shortcuts = {"reflposs", "refl poss"},
}

tags["substantive"] = {
	tag_type = "state",
	glossary = "substantive",
	shortcuts = {"subs", "subst"},
}


----------------------- Degrees of comparison -----------------------

tags["absolute superlative degree"] = {
	tag_type = "comparison",
	glossary = "absolute superlative",
	glossary_type = "wikt",
	shortcuts = {"asupd", "absolute superlative"},
}

tags["relative superlative degree"] = {
	tag_type = "comparison",
	glossary = "relative superlative",
	glossary_type = "wikt",
	shortcuts = {"rsupd", "relative superlative"},
}

tags["elative degree"] = {
	tag_type = "comparison",
	glossary = "elative",
	shortcuts = {"elad"},  -- Can't use "elative" as shortcut because that's already used for the elative case
	wikidata = "Q1555419",
}

-- be careful not to clash with equative case tag
tags["equative degree"] = {
	tag_type = "comparison",
	glossary = "equative",
	glossary_type = "wp",
	shortcuts = {"equd"},
	wikidata = "Q5384239",
}

tags["excessive degree"] = {
	tag_type = "comparison",
	shortcuts = {"excd"},
}


----------------------- Register -----------------------

tags["familiar"] = {
	tag_type = "register",
	glossary = "T–V distinction",
	glossary_type = "wp",
	shortcuts = {"fam"},
}

tags["polite"] = {
	tag_type = "register",
	glossary = "T–V distinction",
	glossary_type = "wp",
	shortcuts = {"pol"},
}

tags["intimate"] = {
	tag_type = "register",
	-- "intimate" is also a possible formality level in the sociolinguistic
	-- register sense.
	glossary = "T–V distinction",
	glossary_type = "wp",
	shortcuts = {"intim"},
}

tags["formal"] = {
	tag_type = "register",
	glossary = "register (sociolinguistics)",
	glossary_type = "wp",
}

tags["informal"] = {
	tag_type = "register",
	glossary = "register (sociolinguistics)",
	glossary_type = "wp",
	shortcuts = {"inform"},
}

tags["colloquial"] = {
	tag_type = "register",
	glossary = "colloquialism",
	glossary_type = "wp",
	shortcuts = {"colloq"},
}

tags["slang"] = {
	tag_type = "register",
	glossary = "slang",
	glossary_type = "wp",
}

tags["contemporary"] = {
	tag_type = "register",
	glossary = "contemporary",
	glossary_type = "wikt",
	shortcuts = {"conty"},
}

tags["literary"] = {
	tag_type = "register",
	glossary = "literary language",
	glossary_type = "wp",
	shortcuts = {"lit"},
}

tags["dated"] = {
	tag_type = "register",
	glossary = "dated",
	glossary_type = "wikt",
}

tags["archaic"] = {
	tag_type = "register",
	glossary = "archaism",
	glossary_type = "wp",
	shortcuts = {"arch"},
}

tags["obsolete"] = {
	tag_type = "register",
	glossary = "obsolete",
	glossary_type = "wikt",
	shortcuts = {"obs"},
}

tags["emphatic"] = {
	tag_type = "register",
	glossary = "emphatic",
	glossary_type = "wikt",
	shortcuts = {"emph"},
}


----------------------- Deixis -----------------------

tags["proximal"] = {
	tag_type = "deixis",
	glossary = "deixis",
	glossary_type = "wp",
	shortcuts = {"prox", "prxl"},
}

tags["medial"] = {
	tag_type = "deixis",
	glossary = "deixis",
	glossary_type = "wp",
	shortcuts = {"medl"},
}

tags["distal"] = {
	tag_type = "deixis",
	glossary = "deixis",
	glossary_type = "wp",
	shortcuts = {"dstl"},
}


----------------------- Clusivity -----------------------

tags["inclusive"] = {
	tag_type = "clusivity",
	glossary = "clusivity",
	glossary_type = "wp",
	shortcuts = {"incl"},
}

tags["exclusive"] = {
	tag_type = "clusivity",
	glossary = "clusivity",
	glossary_type = "wp",
	shortcuts = {"excl"},
}

tags["obviative"] = {
	tag_type = "clusivity",
	glossary = "clusivity",
	glossary_type = "wp",
	shortcuts = {"obv"},
}


----------------------- Inflectional class -----------------------

tags["absolute"] = {
	tag_type = "grammar",
	glossary = "absolute",
	glossary_type = "wikt",
	shortcuts = {"abs"},
}

tags["conjunct"] = {
	tag_type = "grammar",
	glossary = "conjunct",
	glossary_type = "wp",
	shortcuts = {"conjt"},
}

tags["deuterotonic"] = {
	tag_type = "grammar",
	glossary = "dependent and independent verb forms",
	glossary_type = "wp",
	shortcuts = {"deut"},
}

tags["prototonic"] = {
	tag_type = "grammar",
	glossary = "dependent and independent verb forms",
	glossary_type = "wp",
	shortcuts = {"prot"},
}


----------------------- Attitude -----------------------

tags["endearing"] = {
	tag_type = "attitude",
	-- FIXME! No good glossary entry for this; the entry for "hypocoristic"
	-- refers specifically to proper names.
	glossary = "hypocoristic",
	glossary_type = "wp",
	shortcuts = {"end"},
	wikidata = "Q1130279", -- entry for "hypocorism"
}

tags["moderative"] = {
	tag_type = "attitude",
	glossary = "moderative",
	glossary_type = "wikt",
	shortcuts = {"moder"},
}


----------------------- Sound changes -----------------------

tags["alliterative"] = {
    tag_type = "sound change",
    glossary = "Alliteration",
    glossary_type = "wp",
    wikidata = "Q484495",
}

tags["back"] = {
    tag_type = "sound change",
    glossary = "Back vowel",
    glossary_type = "wp",
    wikidata = "Q853589",
}

tags["front"] = {
    tag_type = "sound change",
    glossary = "Front vowel",
    glossary_type = "wp",
    wikidata = "Q5505949",
}

tags["rounded"] = {
    tag_type = "sound change",
    glossary = "Roundedness",
    glossary_type = "wp",
    shortcuts = {"round"},
}

tags["sigmatic"] = {
    tag_type = "sound change",
    glossary = "sigmatic",
    glossary_type = "wikt",
    shortcuts = {"sigm"},
}

tags["unrounded"] = {
    tag_type = "sound change",
    glossary = "Roundedness",
    glossary_type = "wp",
    shortcuts = {"unround"},
}

tags["vowel harmonic"] = {
    tag_type = "sound change",
    glossary = "vowel harmony",
    glossary_type = "wp",
    shortcuts = {"vharm"},
	wikidata = "Q147137",
}


----------------------- Misc grammar -----------------------

tags["relative"] = {
	tag_type = "grammar",
	glossary = "relative",
	glossary_type = "wikt",
	shortcuts = {"rel"},
}

tags["direct relative"] = {
	tag_type = "grammar",
	glossary = "Relative_clause#Celtic_languages",
	glossary_type = "wp",
	shortcuts = {"dirrel"},
}

tags["indirect relative"] = {
	tag_type = "grammar",
	glossary = "Relative_clause#Celtic_languages",
	glossary_type = "wp",
	shortcuts = {"indrel"},
}

tags["synthetic"] = {
	tag_type = "grammar",
	glossary = "synthetic",
	glossary_type = "wikt",
	shortcuts = {"synth"},
}

tags["analytic"] = {
	tag_type = "grammar",
	glossary = "analytic",
	glossary_type = "wikt",
	shortcuts = {"anal", "analytical"},
}

tags["periphrastic"] = {
	tag_type = "grammar",
	glossary = "periphrastic",
	glossary_type = "wikt",
	shortcuts = {"peri"},
}

tags["affirmative"] = {
	tag_type = "grammar",
	glossary = "affirmation and negation",
	glossary_type = "wp",
	shortcuts = {"aff"},
}

tags["possessed"] = {
	tag_type = "grammar",
	glossary = "possessive affix",
	glossary_type = "wp",
	shortcuts = {"possd", "possed"}, -- posd = positive degree
	wikidata = "Q804020", -- for possessive affix
}

tags["non-possessed"] = {
	tag_type = "grammar",
	glossary = "possessive affix",
	glossary_type = "wp",
	shortcuts = {"npossd", "npossed", "nonpossessed"},
}

tags["possessive affix"] = {
	tag_type = "grammar",
	glossary = "possessive affix",
	glossary_type = "wp",
	shortcuts = {"posaf", "possaf"},
	wikidata = "Q804020",
}

tags["possessive suffix"] = {
	tag_type = "grammar",
	glossary = "possessive affix",
	glossary_type = "wp",
	shortcuts = {"possuf"},
	wikidata = "Q804020",
}

tags["possessive prefix"] = {
	tag_type = "grammar",
	glossary = "possessive affix",
	glossary_type = "wp",
	shortcuts = {"pospref", "posspref"},
	wikidata = "Q804020",
}

tags["prefix"] = {
	tag_type = "grammar",
	glossary = "prefix",
	shortcuts = {"pref"}, -- pre = prepositional
	wikidata = "Q134830",
}

tags["prefixal"] = {
	tag_type = "grammar",
	glossary = "prefixal",
	glossary_type = "wikt",
	shortcuts = {"prefl"}, -- pre = prepositional
	wikidata = "Q134830",
}

tags["suffix"] = {
	tag_type = "grammar",
	glossary = "suffix",
	shortcuts = {"suf", "suff"},
	wikidata = "Q102047",
}

tags["suffixal"] = {
	tag_type = "grammar",
	glossary = "suffixal",
	glossary_type = "wikt",
	shortcuts = {"sufl", "suffl"},
	wikidata = "Q102047",
}

tags["affix"] = {
	tag_type = "grammar",
	glossary = "affix",
	glossary_type = "wp",
	shortcuts = {"af"}, -- aff = affirmative
	wikidata = "Q62155",
}

tags["affixal"] = {
	tag_type = "grammar",
	glossary = "affixal",
	glossary_type = "wikt",
	shortcuts = {"afl"}, -- aff = affirmative
	wikidata = "Q62155",
}

tags["circumfix"] = {
	tag_type = "grammar",
	glossary = "circumfix",
	glossary_type = "wp",
	shortcuts = {"circ", "cirf", "circf"},
	wikidata = "Q124939",
}

tags["circumfixal"] = {
	tag_type = "grammar",
	glossary = "circumfixal",
	glossary_type = "wikt",
	shortcuts = {"circl", "cirfl", "circfl"},
	wikidata = "Q124939",
}

tags["infix"] = {
	tag_type = "grammar",
	glossary = "infix",
	glossary_type = "wp",
	shortcuts = {"infx"},
	wikidata = "Q201322",
}

tags["infixal"] = {
	tag_type = "grammar",
	glossary = "infixal",
	glossary_type = "wikt",
	shortcuts = {"infxl"},
	wikidata = "Q201322",
}

tags["subject"] = {
	tag_type = "grammar",
	glossary = "subject",
	shortcuts = {"sbj"}, -- sub and subj used for subjunctive
}

tags["object"] = {
	tag_type = "grammar",
	glossary = "object",
	shortcuts = {"obj"},
}

tags["nonfinite"] = {
	tag_type = "grammar",
	glossary = "nonfinite",
	shortcuts = {"nonfin"},
	wikidata = "Q1050494", -- entry for "non-finite verb"
}

tags["tense"] = {
	tag_type = "grammar",
	glossary = "tense",
	wikidata = "Q177691",
}

tags["tenseless"] = {
	tag_type = "grammar",
	glossary = "tenseless",
	glossary_type = "wikt",
}

tags["aspect"] = {
	tag_type = "grammar",
	glossary = "aspect",
	shortcuts = {"asp"},
	wikidata = "Q208084",
}

tags["augmented"] = {
	tag_type = "grammar",
	glossary = "augment",
	wikidata = "Q760437",
}

tags["unaugmented"] = {
	tag_type = "grammar",
	glossary = "augment",
	wikidata = "Q760437",
}


----------------------- Other tags -----------------------

tags["–"] = { -- Unicode en-dash
	tag_type = "other",
	no_space_on_left = true,
	no_space_on_right = true,
}

tags["—"] = { -- Unicode em-dash
	tag_type = "other",
	no_space_on_left = true,
	no_space_on_right = true,
}




----------------------- Create the shortcuts list -----------------------

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

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
