--[=[

This module lists the less common recognized inflection tags, in the same
format as for [[Module:form of/data]] (which contains the more common tags).
We split the tags this way to save memory, so we avoid loading the less common
tags in the majority of cases.
]=]

local tags = {}
local shortcuts = {}


----------------------- Person -----------------------

----------------------- Number -----------------------

tags["trial"] = {
	tag_type = "number",
	glossary = "trial number",
	shortcuts = {"tri"},
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

tags["habitual"] = {
	tag_type = "tense-aspect",
	glossary = "habitual aspect",
	glossary_type = "wp",
	shortcuts = {"hab"},
	wikidata = "Q5636904",
}

tags["continuous"] = {
	tag_type = "tense-aspect",
	glossary = "continuous aspect",
	glossary_type = "wp",
	shortcuts = {"cont"},
	wikidata = "Q12721117",
}

tags["semelfactive"] = {
	tag_type = "tense-aspect",
	glossary = "semelfactive",
	glossary_type = "wp",
	shortcuts = {"semf"},
	wikidata = "Q7449203",
}

tags["anterior"] = {
	tag_type = "tense-aspect",
	glossary = "relative and absolute tense",
	glossary_type = "wp",
	shortcuts = {"ant"},
}

tags["posterior"] = {
	tag_type = "tense-aspect",
	glossary = "relative and absolute tense",
	glossary_type = "wp",
	shortcuts = {"post"},
}

tags["frequentative"] = {
	tag_type = "tense-aspect",
	glossary = "frequentative",
	glossary_type = "wp",
	shortcuts = {"freq"},
	wikidata = "Q467562",
}

tags["iterative"] = {
	tag_type = "tense-aspect",
	glossary = "iterative aspect",
	glossary_type = "wp",
	shortcuts = {"iter"},
	wikidata = "Q2866772",
}

-- Type of participle in Hindi; also called agentive or agentive-prospective
tags["prospective"] = {
	tag_type = "tense-aspect",
	glossary = "prospective aspect",
	glossary_type = "wp",
	shortcuts = {"pros"},
}

-- Aspect in Tagalog
tags["contemplative"] = {
	tag_type = "tense-aspect",
	glossary = "Tagalog grammar#Aspect",
	glossary_type = "wp",
	shortcuts = {"contem"},
}

-- Aspect in Tagalog; presumably similar to the perfect tense/aspect but
-- not necessarily similar enough to use the same Wikidata ID
tags["complete"] = {
	tag_type = "tense-aspect",
	glossary = "Tagalog grammar#Aspect",
	glossary_type = "wp",
	shortcuts = {"compl"},
}

-- Aspect in Tagalog; presumably similar to the perfect tense/aspect but
-- not necessarily similar enough to use the same Wikidata ID
tags["recently complete"] = {
	tag_type = "tense-aspect",
	glossary = "Tagalog grammar#Aspect",
	glossary_type = "wp",
	shortcuts = {"rcompl"},
}


----------------------- Mood -----------------------

tags["potential"] = {
	tag_type = "mood",
	glossary = "potential mood",
	glossary_type = "wp",
	shortcuts = {"potn"},
	wikidata = "Q2296856",
}

tags["cohortative"] = {
	tag_type = "mood",
	glossary = "cohortative mood",
	glossary_type = "wp",
	shortcuts = {"coho", "cohort"},
}

tags["energetic"] = {
	tag_type = "mood",
	glossary = "energetic mood",
	glossary_type = "wp",
	shortcuts = {"ener"},
}

tags["volitive"] = {
	tag_type = "mood",
	glossary = "volitive mood",
	glossary_type = "wp",
	shortcuts = {"voli"},
	wikidata = "Q10716592",
}

-- It's not clear that this is exactly a mood, but I'm not sure where
-- else to group it
tags["desiderative"] = {
	tag_type = "mood",
	glossary = "desiderative",
	glossary_type = "wp",
	shortcuts = {"des", "desid"},
	wikidata = "Q1200631",
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

-- Exists at least in Estonian
tags["quotative"] = {
	tag_type = "mood",
	glossary = "quotative evidential mood",
	glossary_type = "wp",
	shortcuts = {"quot"},
	-- wikidata = "Q7272884", this is for "quotative" morphemes, not the same
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


----------------------- Voice -----------------------

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

tags["reciprocal"] = {
	tag_type = "voice-valence",
	glossary = "reciprocal (grammar)",
	glossary_type = "wp",
	shortcuts = {"recp", "recip"},
	wikidata = "Q1964083",
}


----------------------- Non-finite -----------------------

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

tags["converb"] = {
	tag_type = "non-finite",
	glossary = "converb",
	glossary_type = "wikt",
	wikidata = "Q149761",
}

tags["connegative"] = {
	tag_type = "non-finite",
	glossary = "connegative",
	glossary_type = "wp",
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
	shortcuts = {"abs"},
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

tags["allative"] = {
	tag_type = "case",
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

tags["terminative"] = {
	tag_type = "case",
	glossary = "terminative case",
	glossary_type = "wp",
	shortcuts = {"ter", "term"},
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

tags["equative degree"] = {
	tag_type = "comparison",
	glossary = "equative",
	glossary_type = "wp",
	shortcuts = {"equd", "equative"},
	wikidata = "Q5384239",
}


----------------------- Levels of politness -----------------------

tags["intimate"] = {
	tag_type = "politeness",
	glossary = "T–V distinction",
	glossary_type = "wp",
	shortcuts = {"intim"},
}

tags["familiar"] = {
	tag_type = "politeness",
	glossary = "T–V distinction",
	glossary_type = "wp",
	shortcuts = {"fam"},
}

tags["polite"] = {
	tag_type = "politeness",
	glossary = "T–V distinction",
	glossary_type = "wp",
	shortcuts = {"pol"},
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


----------------------- Inflection classes -----------------------

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


----------------------- Sound changes -----------------------

----------------------- Misc grammar -----------------------

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

tags["aspect"] = {
	tag_type = "grammar",
	glossary = "aspect",
	shortcuts = {"asp"},
	wikidata = "Q208084",
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
