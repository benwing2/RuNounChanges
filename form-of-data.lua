--[=[

This module lists the more common recognized inflection tags, along with their
shortcut aliases, the corresponding glossary entry or page describing the
tag, and the corresponding wikidata entry. The less common tags are in
[[Module:form of/data2]]. We divide the tags this way to save memory space.
Be careful adding more tags to this module; add them to the other module
unless you're sure they are common.

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

tags["plural"] = {
	tag_type = "number",
	glossary = "plural number",
	shortcuts = {"p", "pl"},
	wikidata = "Q146786",
}

tags["single-possession"] = {
	tag_type = "number",
	glossary = "singular number",
	shortcuts = {"spos"},
	wikidata = "Q110786", -- Singular
}

tags["multiple-possession"] = {
	tag_type = "number",
	glossary = "plural number",
	shortcuts = {"mpos"},
	wikidata = "Q146786", -- Plural
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
	shortcuts = {"in", "inan"},
	wikidata = "Q51927539",
}

tags["personal"] = {
	tag_type = "animacy",
	shortcuts = {"pr", "pers"},
	wikidata = "Q63302102",
}


----------------------- Tense/aspect -----------------------

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

tags["future perfect"] = {
	tag_type = "tense-aspect",
	glossary = "future perfect",
	shortcuts = {"futp", "fperf"},
	wikidata = "Q1234617",
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
	glossary = "preterite",
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
	glossary = "pluperfect",
	shortcuts = {"plup", "pluperf"},
	wikidata = "Q623742",
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
	wikidata = "Q442485",  -- Preterite
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

shortcuts["spast"] = {"simple", "past"}
shortcuts["simple past"] = {"simple", "past"}
shortcuts["spres"] = {"simple", "present"}
shortcuts["simple present"] = {"simple", "present"}


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

tags["modal"] = {
	tag_type = "mood",
	glossary = "modality (linguistics)",
	glossary_type = "wp",
	shortcuts = {"mod"},
	wikidata = "Q1243600",
}

tags["optative"] = {
	tag_type = "mood",
	glossary = "optative mood",
	shortcuts = {"opta", "opt"},
	wikidata = "Q527205",
}

tags["jussive"] = {
	tag_type = "mood",
	glossary = "jussive mood",
	shortcuts = {"juss"},
	wikidata = "Q462367",
}

tags["hortative"] = {
	tag_type = "mood",
	glossary = "hortative",
	glossary_type = "wp",
	shortcuts = {"hort"},
	wikidata = "Q5906629",
}


----------------------- Voice/valence -----------------------

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
	shortcuts = {"mp", "mpass", "mpasv", "mpsv"},
	wikidata = "Q1601545",
}

tags["reflexive"] = {
	tag_type = "voice-valence",
	glossary = "reflexive",
	shortcuts = {"refl"},
	-- the following is for "reflexive verb"
	wikidata = "Q13475484",
}

tags["transitive"] = {
	tag_type = "voice-valence",
	glossary = "transitive verb",
	shortcuts = {"tr", "vt"},
	-- the following is for "transitive verb"
	-- wikidata = "Q1774805",
}

tags["intransitive"] = {
	tag_type = "voice-valence",
	glossary = "intransitive verb",
	shortcuts = {"intr", "vi"},
	-- the following is for "intransitive verb"
	-- wikidata = "Q1166153",
}

tags["ditransitive"] = {
	tag_type = "voice-valence",
	glossary = "ditransitive verb",
	shortcuts = {"ditr"},
	-- the following is for "ditransitive verb"
	-- wikidata = "Q2328313",
}

tags["causative"] = {
	tag_type = "voice-valence",
	glossary = "causative",
	shortcuts = {"caus"},
	-- the following is for "causative verb"
	wikidata = "Q56677011",
}


----------------------- Non-finite -----------------------

tags["infinitive"] = {
	tag_type = "non-finite",
	glossary = "infinitive",
	shortcuts = {"inf"},
	wikidata = "Q179230",
}

-- A form found in Portuguese and Galician, as well as in Hungarian
-- This is probably unnecessary and can be replaced with the regular "infinitive" tag. A personal infinitive is not a separate infinitive from the plain infinitive, just an inflection of the infinitive.
tags["personal infinitive"] = {
	glossary = "Portuguese verb conjugation",
	glossary_type = "wp",
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

tags["supine"] = {
	tag_type = "non-finite",
	glossary = "supine",
	shortcuts = {"sup"},
	wikidata = "Q548470",
}

tags["transgressive"] = {
	tag_type = "non-finite",
	glossary = "transgressive",
	wikidata = "Q904896",
}


----------------------- Case -----------------------

tags["ablative"] = {
	tag_type = "case",
	glossary = "ablative case",
	shortcuts = {"abl"},
	wikidata = "Q156986",
}

tags["accusative"] = {
	tag_type = "case",
	glossary = "accusative case",
	shortcuts = {"acc"},
	wikidata = "Q146078",
}

tags["dative"] = {
	tag_type = "case",
	glossary = "dative case",
	shortcuts = {"dat"},
	wikidata = "Q145599",
}

tags["genitive"] = {
	tag_type = "case",
	glossary = "genitive case",
	shortcuts = {"gen"},
	wikidata = "Q146233",
}

tags["instrumental"] = {
	tag_type = "case",
	glossary = "instrumental case",
	shortcuts = {"ins"},
	wikidata = "Q192997",
}

tags["locative"] = {
	tag_type = "case",
	glossary = "locative case",
	shortcuts = {"loc"},
	wikidata = "Q202142",
}

tags["nominative"] = {
	tag_type = "case",
	glossary = "nominative case",
	shortcuts = {"nom"},
	wikidata = "Q131105",
}

tags["prepositional"] = {
	tag_type = "case",
	glossary = "prepositional case",
	shortcuts = {"pre", "prep"},
	wikidata = "Q2114906",
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
	display = "construct state",
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

tags["possessive"] = {
	tag_type = "state",
	glossary = "possessive",
	glossary_type = "wp",
	shortcuts = {"poss"},
	wikidata = "Q2105891",
}

tags["strong"] = {
	tag_type = "state",
	glossary = "indefinite",
	shortcuts = {"str"},
	wikidata = "Q53997857", -- Indefinite
}

tags["weak"] = {
	tag_type = "state",
	glossary = "definite",
	shortcuts = {"wk"},
	wikidata = "Q53997851", -- Definite
}

tags["mixed"] = {
	tag_type = "state",
	glossary = "mixed",
	shortcuts = {"mix"},
	wikidata = "Q63302161",
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


----------------------- Register -----------------------

----------------------- Deixis -----------------------

----------------------- Clusivity -----------------------

----------------------- Inflectional class -----------------------

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
	shortcuts = {"aug"},
	wikidata = "Q1358239",
}

tags["diminutive"] = {
	tag_type = "attitude",
	glossary = "diminutive",
	shortcuts = {"dim"},
	wikidata = "Q108709",
}

tags["pejorative"] = {
	tag_type = "attitude",
	glossary = "pejorative",
	shortcuts = {"pej"},
	wikidata = "Q545779",
}


----------------------- Sound changes -----------------------

tags["contracted"] = {
	tag_type = "sound change",
	shortcuts = {"contr"},
	wikidata = "Q126473",
}

tags["uncontracted"] = {
	tag_type = "sound change",
	shortcuts = {"uncontr"},
}

----------------------- Misc grammar -----------------------

tags["simple"] = {
	tag_type = "grammar",
	shortcuts = {"sim"},
}

tags["short"] = {
	tag_type = "grammar",
}

tags["long"] = {
	tag_type = "grammar",
}

tags["form"] = {
	tag_type = "grammar",
}

tags["adjectival"] = {
	tag_type = "grammar",
	glossary = "adjectival",
	glossary_type = "wikt",
	shortcuts = {"adj"},
}

tags["adverbial"] = {
	tag_type = "grammar",
	glossary = "adverbial",
	shortcuts = {"adv"},
}

tags["negative"] = {
	tag_type = "grammar",
	shortcuts = {"neg"},
	glossary = "affirmation and negation",
	glossary_type = "wp",
	wikidata = "Q63302088",
}

tags["nominalized"] = {
	tag_type = "grammar",
	shortcuts = {"nomz"},
	wikidata = "Q4683152", -- entry for "nominalized adjective"
}

tags["nominalization"] = {
	tag_type = "grammar",
	shortcuts = {"nomzn"},
	wikidata = "Q1500667",
}

tags["root"] = {
	tag_type = "grammar",
	wikidata = "Q111029",
}

tags["stem"] = {
	tag_type = "grammar",
	wikidata = "Q210523",
}

tags["dependent"] = {
	tag_type = "grammar",
	shortcuts = {"dep"},
	wikidata = "Q1122094", -- entry for "dependent clause"
}

tags["independent"] = {
	tag_type = "grammar",
	shortcuts = {"indep"},
	wikidata = "Q1419215", -- entry for "independent clause"
}


----------------------- Other tags -----------------------

-- This consists of non-content words like "and" as well as
-- punctuation characters. If the punctuation characters appear
-- by themselves as tags, we special-case the handling of
-- surrounding spaces so the output looks correct.

tags["and"] = {
	tag_type = "other",
}

tags[","] = {
	tag_type = "other",
	no_space_on_left = true,
}

tags[":"] = {
	tag_type = "other",
	no_space_on_left = true,
}

tags["/"] = {
	tag_type = "other",
	no_space_on_left = true,
	no_space_on_right = true,
}

tags["("] = {
	tag_type = "other",
	no_space_on_right = true,
}

tags[")"] = {
	tag_type = "other",
	no_space_on_left = true,
}

tags["["] = {
	tag_type = "other",
	no_space_on_right = true,
}

tags["]"] = {
	tag_type = "other",
	no_space_on_left = true,
}

tags["-"] = { -- regular hyphen-minus
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
