--[=[

This module lists all of the recognized inflection tags, along with their
shortcut aliases, the corresponding glossary entry or page describing the
tag, and the corresponding wikidata entry.

TAGS is a table where keys are the canonical form of an inflection tag and the
corresponding values are tables describing the tags, consisting of the
following keys:
	- tag_type: Type of the tag ("person", "number", "gender", "case",
				"animacy", "tense-aspect", "mood", "voice-valence", etc.).
	- glossary: Anchor or page describing the inflection tag. May be missing.
				If glossary_type is unspecified or is "app", this is an
				anchor in [[Appendix:Glossary]]. If glossary_type is "wikt",
				this is a page in the English Wiktionary. If glossary_type is
				"wp", this is a page in the English Wikipedia. NOTE:
				GLOSSARY ANCHORS ARE PREFERRED. Other types of entries should
				be migrated to the glossary, with links to Wikipedia and/or
				Wiktionary entries as appropriate.
	- glossary_type: Type of the glossary entry. Missing or "app" means
					 an anchor in [[Appendix:Glossary]]; "wikt" means a page
					 in the English Wiktionary; "wp" means a page in the
					 English Wikipedia.
	- shortcuts: List of shortcuts, i.e. aliases for the inflection tag. May be
				 missing.
	- display: If specified, consists of text to display in the definition line,
			   in lieu of the canonical form of the inflection tag. If there is
			   a glossary entry, the displayed text forms the right side of the
			   two-part glossary link.
	- wikidata: Wikidata identifier (see wikidata.org) for the concept most
				closely describing this tag.

SHORTCUTS is a table mapping shortcut aliases to canonical inflection tag names.
Shortcuts are of one of three types:
(1) A simple alias of a tag. These do not need to be entered explicitly into
	the table; code at the end of the module automatically fills in these
	entries based on the information in TAGS.
(2) An alias to a multipart tag. For example, the alias "mf" maps to the
	multipart tag "m//f", which will in turn be expanded into the canonical
	multipart tag {"masculine", "feminine"}, which will display as
	(approximately)
	"[[Appendix:Glossary#gender|masculine]] and [[Appendix:Glossary#gender|feminine]]"
	The number of such aliases should be liminted, and should cover only the
	most common combinations.

	Normally, multipart tags are displayed using serialCommaJoin() in
	[[Module:table]] to appropriately join the display form of the individual
	tags using commas and/or "and". However, some multipart tags are displayed
	specially; see DISPLAY_HANDLERS below. Note that aliases to multipart
	tags can themselves contain simple aliases in them.
(3) An alias to a list of multiple tags (which may themselves be simple or
	multipart aliases). Specifying the alias is exactly equivalent to
	specifying the tags in the list in order, one after another. An example is
	"1s", which maps to the list {"1", "s"}. The number of such aliases should
	be limited, and should cover only the most common combinations.


NOTE: In some cases below, multiple tags point to the same wikidata,
because Wikipedia considers them synonyms. Examples are indirect case vs.
objective case vs. oblique case, and inferential mood vs. renarrative mood.
We do this because (a) we want to allow users to choose their own terminology,
(b) we want to be able to use the terminology most common for the language
in question, (c) terms considered synonyms may or may not actually be
synonyms, as different languages may use the terms differently. For example,
although the Wikipedia page on [[w:Inferential mood]] claims that
inferential and renarrative moods are the same, the page on
[[w:Bulgarian_verbs#Evidentials]] claims that Bulgarian has both, and that
they are not the same.
]=]

local tags = {}
local shortcuts = {}


----------------------- Person -----------------------

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

shortcuts["12"] = "1//2"
shortcuts["13"] = "1//3"
shortcuts["23"] = "2//3"
shortcuts["123"] = "1//2//3"


----------------------- Number -----------------------

tags["singular"] = {
	tag_type = "number",
	glossary = "singular number",
	shortcuts = {"s", "sg"},
	wikidata = "Q110786",
}

tags["dual"] = {
	tag_type = "number",
	glossary = "dual number",
	shortcuts = {"d", "du"},
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
	shortcuts = {"p", "pl"},
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

shortcuts["1s"] = {"1", "s"}
shortcuts["2s"] = {"2", "s"}
shortcuts["3s"] = {"3", "s"}
shortcuts["1d"] = {"1", "d"}
shortcuts["2d"] = {"2", "d"}
shortcuts["3d"] = {"3", "d"}
shortcuts["1p"] = {"1", "p"}
shortcuts["2p"] = {"2", "p"}
shortcuts["3p"] = {"3", "p"}


----------------------- Gender -----------------------

tags["masculine"] = {
	tag_type = "gender",
	glossary = "gender",
	shortcuts = {"m"},
	wikidata = "Q499327",
}

-- This is useful e.g. in Swedish.
tags["natural masculine"] = {
	tag_type = "gender",
	glossary = "gender",
	shortcuts = {"natm"},
}

tags["feminine"] = {
	tag_type = "gender",
	glossary = "gender",
	shortcuts = {"f"},
	wikidata = "Q1775415",
}

tags["natural feminine"] = {
	tag_type = "gender",
	glossary = "gender",
	shortcuts = {"natf"},
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

shortcuts["mf"] = "m//f"
shortcuts["mn"] = "m//n"
shortcuts["fn"] = "f//n"
shortcuts["mfn"] = "m//f//n"


----------------------- Animacy -----------------------

-- (may be useful sometimes for [[Module:object usage]].)

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
	glossary = "animacy",
	glossary_type = "wp",
	shortcuts = {"pr"},
}


----------------------- Tense/aspect -----------------------

tags["present"] = {
	tag_type = "tense-aspect",
	glossary = "present tense",
	shortcuts = {"pres"},
	wikidata = "Q192613",
}

tags["simple present"] = {
	tag_type = "tense-aspect",
	glossary = "present tense",
	shortcuts = {"spres"},
	-- Same as present.
	wikidata = "Q192613",
}

tags["past"] = {
	tag_type = "tense-aspect",
	glossary = "past tense",
	wikidata = "Q1994301",
}

tags["simple past"] = {
	tag_type = "tense-aspect",
	glossary = "past tense",
	shortcuts = {"spast"},
	-- Same as past.
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

tags["preterite"] = {
	tag_type = "tense-aspect",
	glossary = "preterite",
	glossary_type = "wp",
	shortcuts = {"pret"},
	wikidata = "Q442485",
}

tags["perfect"] = {
	tag_type = "tense-aspect",
	glossary = "perfect",
	shortcuts = {"perf"},
	wikidata = "Q625420",
}

tags["simple perfect"] = {
	tag_type = "tense-aspect",
	glossary = "perfect",
	shortcuts = {"sperf"},
	-- Same as perfect.
	wikidata = "Q625420",
}

tags["imperfect"] = {
	tag_type = "tense-aspect",
	glossary = "imperfect",
	shortcuts = {"impf", "imperf"},
}

tags["pluperfect"] = {
	tag_type = "tense-aspect",
	glossary = "pluperfect",
	glossary_type = "wp",
	shortcuts = {"plup", "pluperf"},
	wikidata = "Q623742",
}

tags["semelfactive"] = {
	tag_type = "tense-aspect",
	glossary = "semelfactive",
	glossary_type = "wp",
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
	glossary = "past historic",
	glossary_type = "wp",
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
	glossary = "Tagalog grammar#Aspect"
	glossary_type = "wp",
	shortcuts = {"contem"},
}

-- Aspect in Tagalog; presumably similar to the perfect tense/aspect but
-- not necessarily similar enough to use the same Wikidata ID
tags["complete"] = {
	tag_type = "tense-aspect",
	glossary = "Tagalog grammar#Aspect"
	glossary_type = "wp",
	shortcuts = {"compl"},
}

-- Aspect in Tagalog; presumably similar to the perfect tense/aspect but
-- not necessarily similar enough to use the same Wikidata ID
tags["recently complete"] = {
	tag_type = "tense-aspect",
	glossary = "Tagalog grammar#Aspect"
	glossary_type = "wp",
	shortcuts = {"rcompl"},
}


----------------------- Mood -----------------------

tags["imperative"] = {
	tag_type = "mood",
	glossary = "imperative mood",
	shortcuts = {"imp", "impr", "impv"},
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
	glossary = "potential mood",
	glossary_type = "wp",
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

-- This tag type combines what is normally called "voice" (active, passive,
-- middle, mediopassive) with other tags that aren't normally called
-- voice but are similar in that they control the valence/valency (number
-- and structure of the arguments of a verb).
tags["active"] = {
	tag_type = "voice-valence",
	glossary = "active voice",
	shortcuts = {"act", "actv"},
	wikidata = "Q1317831",
}

tags["middle"] = {
	tag_type = "voice-valence",
	glossary = "middle voice",
	shortcuts = {"mid", "midl"},
}

tags["passive"] = {
	tag_type = "voice-valence",
	glossary = "passive voice",
	shortcuts = {"pass", "pasv"},
	wikidata = "Q1194697",
}

tags["mediopassive"] = {
	tag_type = "voice-valence",
	glossary = "mediopassive",
	shortcuts = {"mp", "mpass", "mpsv"},
	wikidata = "Q1601545",
}

tags["reflexive"] = {
	tag_type = "voice-valence",
	glossary = "reflexive",
	shortcuts = {"refl"},
	-- the following is for "reflexive verb"
	wikidata = "Q13475484",
}

tags["causative"] = {
	tag_type = "voice-valence",
	glossary = "causative",
	glossary_type = "wp",
	shortcuts = {"caus"},
	-- the following is for "causative verb"
	wikidata = "Q56677011",
}


----------------------- Non-finite -----------------------

tags["infinitive"] = {
	tag_type = "non-finite",
	shortcuts = {"inf"},
	wikidata = "Q179230",
}

-- A form found in Portuguese and Galician
tags["personal infinitive"] = {
	tag_type = "non-finite",
	shortcuts = {"pinf"},
}

tags["participle"] = {
	tag_type = "non-finite",
	glossary = "participle",
	shortcuts = {"part", "ptcp"},
	wikidata = "Q814722",
}

tags["verbal noun"] = {
	tag_type = "non-finite",
	glossary = "verbal noun",
	shortcuts = {"vnoun"},
	wikidata = "Q1350145",
}

tags["gerund"] = {
	tag_type = "non-finite",
	glossary = "gerund",
	shortcuts = {"ger"},
	wikidata = "Q1923028",
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

tags["supine"] = {
	tag_type = "non-finite",
	glossary = "supine",
	shortcuts = {"sup"},
	wikidata = "Q548470",
}

-- Occurs in Hindi as a type of participle used to conjoin two clauses;
-- similarly occurs in Japanese as the "te-form"
tags["conjunctive"] = {
	tag_type = "non-finite",
	--glossary = "conjunctive",
	shortcuts = {"conj"},
}

-- FIXME! Should this be a mood?
tags["debitive"] = {
	tag_type = "non-finite",
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

tags["ablative"] = {
	tag_type = "case",
	glossary = "ablative case",
	shortcuts = {"abl"},
	wikidata = "Q156986",
}

tags["absolutive"] = {
	tag_type = "case",
	glossary = "absolutive case",
	glossary_type = "wp",
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

tags["dative"] = {
	tag_type = "case",
	glossary = "dative case",
	shortcuts = {"dat"},
	wikidata = "Q145599",
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

tags["genitive"] = {
	tag_type = "case",
	glossary = "genitive case",
	shortcuts = {"gen"},
	wikidata = "Q146233",
}

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

tags["instrumental"] = {
	tag_type = "case",
	glossary = "instrumental case",
	shortcuts = {"ins"},
	wikidata = "Q192997",
}

tags["limitative"] = {
	tag_type = "case",
	glossary = "list of grammatical cases",
	glossary_type = "wp",
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

tags["prepositional"] = {
	tag_type = "case",
	glossary = "prepositional case",
	shortcuts = {"pre", "prep"},
	wikidata = "Q2114906",
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

tags["vocative"] = {
	tag_type = "case",
	glossary = "vocative case",
	shortcuts = {"voc"},
	wikidata = "Q185077",
}


----------------------- State -----------------------

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
	glossary = "predicative",
	shortcuts = {"pred"},
}


----------------------- Degrees of comparison -----------------------

tags["positive degree"] = {
	tag_type = "comparison",
	glossary = "positive",
	shortcuts = {"posd", "positive"},
	-- Doesn't exist in English; only in Czech, Estonian, Finnish and
	-- various Nordic languages.
	wikidata = "Q3482678",
}

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

tags["strong"] = {
	tag_type = "class",
	glossary = "strong declension",
	glossary_type = "wikt",
	shortcuts = {"str"},
	wikidata = "Q3481903",
}

tags["weak"] = {
	tag_type = "class",
	glossary = "weak declension",
	glossary_type = "wikt",
	shortcuts = {"wk"},
	wikidata = "Q7977953",
}

tags["mixed"] = {
	tag_type = "class",
	glossary = "mixed declension",
	glossary_type = "wikt",
	shortcuts = {"mix"},
}

tags["pronominal"] = {
	tag_type = "class",
	glossary = "pronominal",
	glossary_type = "wikt",
	shortcuts = {"pron"},
	-- the following is for "pronominal attribute", existing only in the Romanian Wikipedia
	wikidata = "Q12721180",
}


----------------------- Attitude -----------------------

-- This is a vague tag type grouping augmentative, diminutive and pejorative,
-- which generally indicate the speaker's attitude towards the object in
-- question (as well as often indicating size).

tags["augmentative"] = {
	tag_type = "attitude",
	glossary = "augmentative",
	glossary_type = "wp",
	shortcuts = {"aug"},
	wikidata = "Q1358239",
}

tags["diminutive"] = {
	tag_type = "attitude",
	glossary = "diminutive",
	glossary_type = "wp",
	shortcuts = {"dim"},
	wikidata = "Q108709",
}

tags["pejorative"] = {
	tag_type = "attitude",
	glossary = "pejorative suffix",
	glossary_type = "wp",
	shortcuts = {"pej"},
	wikidata = "Q2067740", -- entry for "pejorative suffix"
	--wikidata = "Q545779", -- Also possible: entry for "pejorative"
}


----------------------- Sound changes -----------------------

tags["contracted"] = {
	glossary = "contraction (grammar)",
	glossary_type = "wp",
	tag_type = "sound change",
}


----------------------- Misc grammar -----------------------

tags["adjectival"] = {
	tag_type = "grammar",
	glossary = "adjectival",
	glossary_type = "wikt",
	shortcuts = {"adj"},
}

tags["adverbial"] = {
	tag_type = "grammar",
	glossary = "adverbial",
	shortcuts = {"adj"},
}

tags["possessive"] = {
	tag_type = "non-finite",
	glossary = "possessive",
	glossary_type = "wp",
	shortcuts = {"poss"},
	wikidata = "Q2105891",
}

tags["affirmative"] = {
	tag_type = "grammar",
	glossary = "affirmation and negation",
	glossary_type = "wp",
	shortcuts = {"aff"},
}

tags["negative"] = {
	tag_type = "grammar",
	glossary = "affirmation and negation",
	glossary_type = "wp",
	shortcuts = {"neg"},
}

tags["possessive affix"] = {
	tag_type = "grammar",
	glossary = "possessive affix",
	glossary_type = "wp",
	display = "possessed",
	shortcuts = {"possuf", "posaf", "possessed"},
	wikidata = "Q804020",
}

tags["singular possession"] = {
	tag_type = "grammar",
	--glossary = "singular possession",
	shortcuts = {"spos"},
}

tags["plural possession"] = {
	tag_type = "grammar",
	--glossary = "plural possession",
	shortcuts = {"ppos"},
}

tags["nominalized"] = {
	tag_type = "grammar",
	glossary = "nominalized adjective",
	glossary_type = "wp",
	shortcuts = {"nomz"},
	wikidata = "Q4683152", -- entry for "nominalized adjective"
}

tags["nominalization"] = {
	tag_type = "grammar",
	glossary = "nominalization",
	glossary_type = "wp",
	shortcuts = {"nomzn"},
	wikidata = "Q1500667",
}

tags["root"] = {
	tag_type = "grammar",
	glossary = "root (linguistics)",
	glossary_type = "wp",
	wikidata = "Q111029",
}

tags["stem"] = {
	tag_type = "grammar",
	glossary = "word stem",
	glossary_type = "wp",
	wikidata = "Q210523",
}

tags["dependent"] = {
	tag_type = "grammar",
	glossary = "dependent clause",
	glossary_type = "wp",
	shortcuts = {"dep"},
	wikidata = "Q1122094", -- entry for "dependent clause"
}

tags["independent"] = {
	tag_type = "grammar",
	glossary = "independent clause",
	glossary_type = "wp",
	shortcuts = {"indep"},
	wikidata = "Q1419215", -- entry for "independent clause"
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

----------------------- Other tags -----------------------

tags["and"] = {
	tag_type = "other",
}

-- The next four are special-cased in tagged_inflections to avoid
-- inserting certain sorts of spaces so they appear correct.
tags[","] = {
	tag_type = "other",
}

tags["/"] = {
	tag_type = "other",
}

tags["("] = {
	tag_type = "other",
}

tags[")"] = {
	tag_type = "other",
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

return {tags = tags, shortcuts = shortcuts, display_handlers = display_handlers}

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
