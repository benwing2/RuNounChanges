--[=[

Implementation of pronunciation-generation module from spelling for German.

Author: Benwing

The following symbols can be used:
-- 'h' after a vowel to force it to be long
-- acute accent on a vowel to override the position of primary stress
--   (in a diphthong, put it over the first vowel)
-- grave accent to add secondary stress
-- circumflex to force no stress on the word or prefix (e.g. in a compound)
-- . (period) to force a syllable boundary
-- - (hyphen) to force a prefix/word or word/word boundary in a compound word;
--   the result will be displayed as a single word but the consonants on
--   either side treated as if they occurred at the beginning/end of the word
-- + (plus) is the opposite of -; it forces a prefix/word or word/word boundary
--   to *NOT* occur when it otherwise would
-- _ (underscore) to force the letters on either side to be interpreted
--   independently, when the combination of the two would normally have a
--   special meaning

FIXME:

1. Implement < and > which works like - but don't trigger secondary stress
   (< after a prefix, > before a suffix) (DONE)
2. Recognize -lēas and -l[iī][cċ] as suffixes. (DONE)
2b. Recognize -fæst, -ful, -full as suffixes (so no voicing of initial
    fricative). (DONE)
3. If explicit syllable boundary in cluster after prefix, don't recognize as
   prefix (hence ġeddung could be written ġed.dung, bedreda bed.reda) (DONE)
4. Two bugs in swīþfèrhþ: missing initial stress, front h should be back (DONE)
5. Check Urszag's code changes for /h/. (DONE)
6. Bug in wasċan; probably sċ between vowels should be ʃʃ (DONE)
7. Bug in ġeddung, doesn't have allowed onset with ġe-ddung (DONE)
8. āxiġendlīc -- x is not an allowed onset (DONE)
9. Handle prefixes/suffixes denoted with initial/final hyphen -- shouldn't
   trigger automatic stress when multisyllabic. (DONE)
10. Don't remove user-specified accents on monosyllabic words. (DONE)
11. Final -þu/-þo after a consonant should always be voiceless (but controlled
    by a param). (DONE BUT NOT YET CONTROLLED BY PARAM)
12. Fricative voiced between voiced sounds even across prefix/compound
    boundary when before (but not after) the boundary. (DONE)
13. Fricative between unstressed vowels should be voiceless (e.g. adesa);
    maybe only after the stress? (DONE)
14. Resonant after fricative/stop in a given syllable should be rendered
    as syllabic (e.g. ādl [ˈɑːdl̩], botm [botm̥], bōsm, bēacn [ˈbæːɑ̯kn̩];
	also -mn e.g stemn /ˈstemn̩/. (DONE)
15. Add aġēn- and onġēan- prefixes with secondary stress for verbs.
    (WILL NOT DO)
16. and- (and maybe all others) should be unstressed as verbal prefix.
    andswarian is an exception. (DONE)
17. Support multiple pronunciations as separate numbered params. (DONE)
17b. Additional specifiers should follow each pronun as PRONUN<K:V,K2:V2,...>.
    This includes the current pos=.
18. Double hh should be pronounced as [xː]. (DONE)
19. Add -bǣre as a suffix with secondary stress. (DONE)
20. Add -līċ(e), lī[cċ]nes(s) as suffixes with secondary stress. -lī[cċ]nes(s)
    should behave like -līċ(e) in that what's before is checked to determine
	the pos. (DONE)
21. -lēasnes should be a recognized suffix with secondary stress. (DONE)
22. Fix handling of crinċġan, dynċġe, should behave as if ċ isn't there. (DONE)
23. Rewrite to use [[Module:ang-common]]. (DONE)
24. Ignore final period/question mark/exclamation point. (DONE)
25. Implement pos=verbal for handling un-. (DONE)
26. Simplify geminate consonants within a single syllable. (DONE)

QUESTIONS:

1. Should /an/, /on/ be pronounced [ɒn]? Same for /am/, /om/. [NO]
2. Should final /ɣ/ be rendered as [x]? [NO]
3. Should word-final double consonants be simplified in phonetic representation?
   Maybe also syllable-final except obstruents before [lr]? [YES]
4. Should we use /x/ instead of /h/? [YES]
5. Should we recognize from- along with fram-? [NO]
6. Should we recognize bi- along with be-? (danger of false positives) [NO]
7. Should fricative be voiced before voicd sound across word boundary?
   (dæġes ēage [ˈdæːjez ˈæːɑ̯ɣe]?) [NO]
8. Ask about pronunciation of bræġn, is the n syllabic? It's given as
   /ˈbræjn̩/. Similarly, seġl given as /ˈsejl̩/. [NO; HUNDWINE AND URSZAG DISAGREE]
9. Ask about pronunciation of ġeond-, can it be either [eo] or [o]? [UNCLEAR]
10. Is final -ol pronounced [ul] e.g regol [ˈreɣul]? Hundwine has created
    entries this way. What about final -oc etc.? [NO]
11. Is final -ian pronounced [jan] or [ian]? Cf. sċyldigian given as
    {{IPA|/ˈʃyldiɣiɑn/|/ˈʃyldiɣjɑn/}}. What about spyrian given as /ˈspyr.jɑn/?
	[-ian in weak II verbs, -jan in weak I verbs]
12. seht given as /seçt/ but sehtlian given as /ˈsextliɑn/. Which one is
    correct? [ç]
13. Final -liċ or -līċ, with or without secondary stress?
14. Should we special-case -sian [sian]? Then we need support for [z] notation
    to override phonetics.
]=]

local strutils = require("Module:string utilities")
local m_table = require("Module:table")
local m_IPA = require("Module:IPA")
local lang = require("Module:languages").getByCode("ang")
local com = require("Module:ang-common")

local u = mw.ustring.char
local rsubn = mw.ustring.gsub
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local rgsplit = mw.text.gsplit
local ulen = mw.ustring.len
local ulower = mw.ustring.lower

local AC = u(0x0301)
local GR = u(0x0300)
local CFLEX = u(0x0302)
local TILDE = u(0x0303) -- tilde =  ̃
local MACRON = u(0x0304) -- macron =  ̄
local BREVE = u(0x0306) -- breve =  ̆
local DIA = u(0x0308) -- diaeresis = ̈
local DOTOVER = u(0x0307) -- dot over =  ̇
local DOTUNDER = u(0x0323) -- dot under =  ̣
local Inon_VBREVEBELOW = u(0x032F) -- inverted breve below =  ̯
local LINEUNDER = u(0x0331) -- line under =  ̱
local TIE = u(0x0361) -- tie =  ͡

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar, n)
	local retval = rsubn(term, foo, bar, n)
	return retval
end

-- like str:gsub() but discards all but the first return value
local function gsub(term, foo, bar, n)
	local retval = term:gsub(foo, bar, n)
	return retval
end

local export = {}

-- When auto-generating primary and secondary stress accents, we use these
-- special characters, and later convert to normal IPA accent marks, so
-- we can distinguish auto-generated stress from user-specified stress.
local AUTOACUTE = u(0xFFF0)
local AUTOGRAVE = u(0xFFF1)

-- When the user uses the "explicit allophone" notation such as [z] or [ç] to
-- force a particular allophone, we internally convert that notation into a
-- single special character.
local EXPLICIT_TH = u(0xFFF2)
local EXPLICIT_DH = u(0xFFF3)
local EXPLICIT_S = u(0xFFF4)
local EXPLICIT_Z = u(0xFFF5)
local EXPLICIT_F = u(0xFFF6)
local EXPLICIT_V = u(0xFFF7)
local EXPLICIT_G = u(0xFFF8)
local EXPLICIT_GH = u(0xFFF9)
local EXPLICIT_H = u(0xFFFA)
local EXPLICIT_X = u(0xFFFB)
local EXPLICIT_C = u(0xFFFC)
local EXPLICIT_I = u(0xFFFD)

local explicit_cons = EXPLICIT_TH .. EXPLICIT_DH .. EXPLICIT_S .. EXPLICIT_Z ..
	EXPLICIT_F .. EXPLICIT_V .. EXPLICIT_G .. EXPLICIT_GH .. EXPLICIT_H ..
	EXPLICIT_X .. EXPLICIT_C

-- Map "explicit allophone" notation into special char. See above.
local char_to_explicit_char = {
	["þ"] = EXPLICIT_TH,
	["ð"] = EXPLICIT_DH,
	["s"] = EXPLICIT_S,
	["z"] = EXPLICIT_Z,
	["f"] = EXPLICIT_F,
	["v"] = EXPLICIT_V,
	["g"] = EXPLICIT_G,
	["ɣ"] = EXPLICIT_GH,
	["h"] = EXPLICIT_H,
	["x"] = EXPLICIT_X,
	["ç"] = EXPLICIT_C,
	["i"] = EXPLICIT_I,
}

-- Map "explicit allophone" notation into normal spelling, for supporting ann=.
local char_to_spelling = {
	["þ"] = "þ",
	["ð"] = "þ",
	["s"] = "s",
	["z"] = "s",
	["f"] = "f",
	["v"] = "f",
	["g"] = "g",
	["ɣ"] = "g",
	["h"] = "h",
	["x"] = "h",
	["ç"] = "h",
	["i"] = "i",
}

-- Map "explicit allophone" notation into phonemes, for phonemic output.
local explicit_char_to_phonemic = {
	[EXPLICIT_TH] = "θ",
	[EXPLICIT_DH] = "θ",
	[EXPLICIT_S] = "s",
	[EXPLICIT_Z] = "s",
	[EXPLICIT_F] = "f",
	[EXPLICIT_V] = "f",
	[EXPLICIT_G] = "ɡ", -- IPA ɡ!
	[EXPLICIT_GH] = "ɡ", -- IPA ɡ!
	[EXPLICIT_H] = "x",
	[EXPLICIT_X] = "x",
	[EXPLICIT_C] = "x",
	[EXPLICIT_I] = "i",
}

-- Map "explicit allophone" notation into IPA phones, for phonetic output.
local explicit_char_to_phonetic = {
	[EXPLICIT_TH] = "θ",
	[EXPLICIT_DH] = "ð",
	[EXPLICIT_S] = "s",
	[EXPLICIT_Z] = "z",
	[EXPLICIT_F] = "f",
	[EXPLICIT_V] = "v",
	[EXPLICIT_G] = "ɡ", -- IPA ɡ!
	[EXPLICIT_GH] = "ɣ",
	[EXPLICIT_H] = "h",
	[EXPLICIT_X] = "x",
	[EXPLICIT_C] = "ç",
	[EXPLICIT_I] = "i",
}

local accent = com.MACRON .. com.ACUTE .. com.GRAVE .. com.CFLEX .. AUTOACUTE .. AUTOGRAVE
local accent_c = "[" .. accent .. "]"
local non_accent_c = "[^" .. accent .. "]"
local stress_accent = com.ACUTE .. com.GRAVE .. com.CFLEX .. AUTOACUTE .. AUTOGRAVE
local stress_accent_c = "[" .. stress_accent .. "]"
local back_vowel = "aɑou"
local front_vowel = "eiyæœø" .. EXPLICIT_I
local vowel = back_vowel .. front_vowel
local vowel_or_accent = vowel .. accent
local V = "[" .. vowel .. "]"
local vowel_or_accent_c = "[" .. vowel_or_accent .. "]"
local non_V = "[^" .. vowel .. "]"
local front_V = "[" .. front_vowel .. "]"
-- The following include both IPA symbols and letters (including regular g and IPA ɡ)
-- so it can be used at any step of the process.
local obstruent = "bcċçdfgɡɣhkpqstvxzþðθʃʒ" .. explicit_cons
local resonant = "lmnŋrɫ"
local glide = "ġjwƿ"
local cons = obstruent .. resonant .. glide
local cons_c = "[" .. cons .. "]"
local voiced_sound = vowel .. "lrmnwjbdɡ" -- WARNING, IPA ɡ used here

local prefixes = {
	{export.decompose("ā"), {verb = "unstressed", noun = "stressed"}},
	{"ab", {verb = "unstressed"}},
	{"an", {verb = "unstressed"}},
	{"æfter", {verb = "secstressed", noun = "stressed"}}, -- not very common
	{"and", {verb = "unstressed", noun = "stressed"}},
	{"an", {verb = "unstressed", noun = "stressed"}},
	{"be", {verb = "unstressed", noun = "unstressed", restriction = "^[^" .. accent .. "ao]"}},
	{export.decompose("bī"), {noun = "stressed"}},
	{"ed", {verb = "unstressed", noun = "stressed"}}, -- not very common
	{"fore", {verb = "unstressed", noun = "stressed", restriction = "^[^" .. accent .. "ao]"}},
	{"for[þð]", {verb = "unstressed", noun = "stressed"}},
	{"for", {verb = "unstressed", noun = "unstressed"}},
	{"fram", {verb = "unstressed", noun = "stressed"}}, -- not very common
	-- following is rare as a noun, mostly from verbal forms
	{"ġeond", {verb = "unstressed"}}, 
	{"ge", {verb = "unstressed", noun = "unstressed", restriction = "^[^" .. accent .. "ao]"}},
	{"in", {verb = "unstressed", noun = "stressed"}}, -- not very common
	{"mis", {verb = "unstressed"}},
	{"ofer", {verb = "secstressed", noun = "stressed"}},
	{"of", {verb = "unstressed", noun = "stressed"}},
	{"on", {verb = "unstressed", noun = "stressed"}},
	{"or", {noun = "stressed"}},
	{"o[þð]", {verb = "unstressed"}},
	{export.decompose("stēop"), {noun = "stressed"}},
	{export.decompose("tō"), {verb = "unstressed", noun = "stressed"}},
	{"under", {verb = "secstressed", noun = "stressed"}},
	{"un", {verb = "secstressed", noun = "stressed"}}, -- uncommon as verb
	{"up", {verb = "unstressed", noun = "stressed"}},
	{export.decompose("ūt"), {verb = "unstressed", noun = "stressed"}},
	{export.decompose("ū[þð]"), {noun = "stressed"}},
	{"[wƿ]i[þð]er", {verb = "secstressed", noun = "stressed"}},
	{"[wƿ]i[þð]", {verb = "unstressed"}},
	{"ymb", {verb = "unstressed", noun = "stressed"}},
	{"[þð]urh", {verb = "unstressed", noun = "stressed"}},
}

export.suffixes = {
	{"[ai]bel", {respell = "bàhr", pos = "a"}},
	-- Normally following consonant but there a few exceptions like [[abbaubar]], [[recyclebar]], [[unüberschaubar]].
	-- Cases like [[isobar]] will be respelled with an accent and not affected.
	{"bar", {respell = "bàhr", pos = "a"}},
	-- Without this the -i- would be long. (FIXME: Should it be long?)
	{"kirchen", {pos = "n"}},
	-- Restrict to not follow a vowel or s (except for -ss) to avoid issues with nominalized infinitives in -chen.
	-- Words with -chen after a vowel or s need to be respelled with '>chen', as in [[Frauchen]], [[Wodkachen]],
	-- [[Häuschen]], [[Bläschen]], [[Füchschen]], [[Gänschen]], etc. Occasional gerunds of verbs in -rchen may need
	-- to be respelled with '+chen' to avoid the preceding vowel being long, as in [[Schnarchen]].
	{"chen", {respell = "çen", pos = "n", restriction = {"[^" .. accent .. vowel .. "]$", "[^s]s$"}}},
	-- Avoid firing on words like [[Trend]].
	{"end", {respell = "ənd", restriction = V}},
	-- Normally following consonant but there a few exceptions like [[säurefest]]. Cases like [[manifest]] will be
	-- respelled with an accent and not affected.
	{"fest", {respell = "fèst", pos = "a"}},
	{"schaft", {respell = "schàft"}},
	{"haft", {respell = "hàft"}},
	{"([hk])eit", {respell = "%1èit", pos = "n"}},
	-- NOTE: This will get converted to secondary stress if there is a primary stress elsewhere in the word (e.g. in
	-- compound words).
	{"ie", {respell = "íe", pos = "n", restriction = cons_c .. "$"}},
	-- No restriction to not occur after a/e; [[kreieren]] does occur and noun form and verbs in -en after -aier/-eier
	-- should not occur (instead you get -aiern/-eiern). Occurs with both nouns and verbs.
	{"ieren", {respell = "íeren"}},
	-- See above. Occurs with adjectives and participles, and also [[Gefiert]].
	{"iert", {respell = "íert"}},
	-- See above. Occurs with nouns.
	{"ierung", {respell = "íerung"}},
	-- FIXME, needs style restriction/differentiation once those are implemented, as southern Germany/Austria uses
	-- respelling with -ick. Not restricted to verbs/adjectives because there are nominalized adjectives esp.
	-- numbers, e.g. [[Achtundzwanzig]], toponyms like [[Danzig]], random nouns like [[König]] and [[Essig]], etc.
	-- Don't trigger on [[Braunschweig]], [[Kuchenteig]], [[feig]], etc. Other vowels are OK, cf. [[breiig]] "mushy",
	-- [[eineiig]] "monozygotic", [[etwaig]] "possible", [[reuig]] "remorseful", as are vowel + e, as in
	-- [[schneeig]] "snowy".
	-- This needs to be handled specially.
	-- {"ig", {respell = "ich", restriction = {V .. ".*[^e]$", V .. "e$"}}},
	{"in", {respell = "inn", restriction = {V .. ".*[^e]$", V .. "e$"}},
	-- "isch" not needed here; no respelling needed and vowel-initial
	-- NOTE: This will get converted to secondary stress if there is a primary stress elsewhere in the word (e.g. in
	-- compound words like [[Abwehrmechanismus]] or [[Lügenjournalismus]]).
	{"ismus", {respell = "ísmus", pos = "n"}},
	{"ist", {respell = "íst", pos = "n"}},
	{"istisch", {respell = "ístisch", pos = "a"}},
	-- Almost all words in -tät are in -ität but a few aren't: [[Majestät]], [[Fakultät]], [[Pietät]], [[Pubertät]],
	-- [[Sozietät]], [[Varietät]].
	{"lich", {pos = "a"}},
	{"reich", {respell = "rèich", pos = "a"}},
	{"tät", {respell = "tä́t"}},
	{"tion", {respell = "zión"}},
	-- "ung" not needed here; no respelling needed and vowel-initial
	{"weise", {respell = "wèise", pos = "a"}},









	{"", {noun = "secstressed"}},
	{"full?", {noun = "unstressed"}},
	{"lēas", {noun = "secstressed"}},
	-- These can be "verbal" if following a verbal past participle or similar
	{"līċe", {noun = "secstressed", verb = "secstressed"}},
	{"l[īi][ċc]", {noun = "unstressed", verb = "unstressed"}},
	{"ness?", {noun = "unstressed", verb = "unstressed"}},
	{"n[iy]s", {noun = "unstressed", verb = "unstressed"}},
	{"sum", {noun = "unstressed"}},
}

-- These rules operate in order, and apply to the actual spelling,
-- after (1) macron decomposition, (2) syllable and prefix splitting,
-- (3) placement of primary and secondary stresses at the beginning
-- of the syllable. Each syllable will be separated either by ˈ
-- (if the following syllable is stressed), by ˌ (if the following
-- syllable has secondary stress), or by . (otherwise). In addition,
-- morpheme boundaries where the consonants on either side should be
-- treated as at the beginning/end of word (i.e. between prefix and
-- word, or between words in a compound word) will be marked with ⁀
-- before the syllable separator, and the beginning and end of text
-- will be marked by ⁀⁀. The output of this is fed into phonetic_rules,
-- and then is used to generate the displayed phonemic pronunciation
-- by removing ⁀ symbols.
local phonemic_rules = {
	{"ǝ", "ə"}, -- "Wrong" schwa (U+01DD) to correct schwa (U+0259)
	{"x", "ks"},
	{"tz", "ʦʦ"},
	{"z", "ʦ"},
	{"qu", "kv"},
	{"q", "k"},
	{"w", "v"},
	-- [[Pinguin]], [[Linguistik]], [[konsanguin]], [[Lingua franca]], [[bilingual]]
	{"ngu(" .. V .. ")", "ŋgu%1"},
	{"ng", "ŋŋ"},
	{"dt", "tt"},

	-- Handling of 'c' other than 'ch'.
	-- Italian-derived words: [[Catenaccio]], [[Stracciatella]]
	{"cci(" .. V .. ")", "ʧʧ%1"},
	-- Italian-derived words: [[Cappuccino]], [[Fibonaccizahl]]
	{"cc([ei])", "ʧʧ%1"},
	{"ck", "kk"},
	-- Mostly Romance-origin words: [[Account]], [[Alpacca]], [[Broccoli]], [[Latte macchiato]], [[Macchie]], [[Mocca]],
	-- [[Occasion]], [[Occopirmus]], [[Piccolo]], [[Rebecca]], [[staccatoartig]], [[Zucchini]], etc. This needs to
	-- go before kh -> k so that cch -> kk.
	{"cc", "kk"},
	{"c([^h])", "ʦ%1"},

	-- Handling of diphthongs and 'h'.
	-- Not ff. Compare [[Graph]] with long /a/, [[Apostrophe]] with long second /o/.
	{"ph", "f"},
	-- dh: [[Buddha]], [[Abu Dhabi]], [[Sindhi]]; [[Adhäsion]], [[adhäsiv]] are exceptions, can be written ''ad.häsív''
	--     etc.
	-- th: [[Methode]], [[Abendroth]], [[Absinth]], [[Theater]], [[Agathe]] (note long /a/ here), [[Akolyth]] (note long
	--      /y/ here), [[Algorithmus]], [[katholisch]], etc.
	-- kh: [[Dzongkha]], [[khaki]]. Fed by 'cch' above.
	-- gh: [[Afghane]], [[Afghanistan]], [[Balogh]], [[Edinburgh]], [[Ghana]], [[Ghetto]], [[Ghostwriter]], [[Joghurt]],
	--     [[maghrebinisch]], [[Sorghum]], [[Spaghetti]].
	-- bh: [[Bhutan]].
	-- rh: [[Arrhythmie]], [[Rhythmus]], [[Rhodos]], [[Rhabarber]], [[Rhapsodie]], [[Rheda]], [[Rhein]], [[Rhenium]],
	--     [[Rhetorik]], [[Rheuma]], [[rhexigen]], [[Rhone]], etc.
	{"([dtkgbr])h", "%1"},
	-- Doubled vowels as in [[Haar]], [[Boot]], [[Schnee]], [[dööfer]], etc. become long.
	{"([aeoäöü])(" .. accent_c .. "*" .. ")%1(" .. non_accent_c .. ")", "%1ː%2%3", true},
	-- 'äu', 'eu' -> /ɔɪ̯/. /ɪ̯/ is two characters so we use I to represent it and convert later.
	{"[äe](" .. accent_c .. "*" .. ")u(" .. non_accent_c .. ")", "ɔ%1I%2", true},
	-- 'au' -> /aʊ̯/. /ʊ̯/ is two characters so we use U to represent it and convert later.
	{"a(" .. accent_c .. "*" .. ")u(" .. non_accent_c .. ")", "a%1U%2", true},
	-- 'ai', 'ei' -> /aɪ̯/.
	{"[ae](" .. accent_c .. "*" .. ")i(" .. non_accent_c .. ")", "a%1I%2", true},
	-- 'ie' -> /iː/.
	{"i(" .. accent_c .. "*" .. ")e(" .. non_accent_c .. ")", "iː%1%2", true},
	-- 'h' after a vowel followed by a stressed vowel should actually be pronounced, e.g. [[Abraham]], [[abstrahieren]],
	-- [[Alkohol]], [[Kisuaheli]], [[Kontrahent]], [[Bahaitum]], [[Bahamas]], [[daheim]], [[Mudschahed]]. Other 'h'
	-- between vowels are normally not pronounced, e.g. [[bähen]], [[beinahe]], [[Bejahung]]. Other cases of pronounced
	-- 'h' between vowels should be indicated by placing a syllable divider '.' before the 'h' to make it
	-- syllable-initial, e.g. [[ahistorisch]], [[Ahorn]], [[adhäsiv]], [[Lahar]], [[Mahagoni]].
	{"h(" .. V .. accent_non_stress_c .. "*" .. stress_c .. ")", "H%1"},
	-- Remaining 'h' after a vowel (not including a glide like I or U from dipthongs) indicates vowel length.
	{"(" .. vowel_non_glide_c .. ")(" .. stress_c .. "*" .. ")h", "%1ː%2"},
	-- Remaining 'h' after a vowel is superfluous, e.g. [[Vieh]], [[ziehen]], [[rauh]], [[leihen]], [[Geweih]].
	{"(" .. V .. accent_c .. "*" .. ")h", "%1"},
	-- Convert special 'H' symbol (to indicate pronounced /h/ between vowels) back to /h/.
	{"H", "h"},

	-- Handling of 'ch'. Must follow diphthong handling so 'äu', 'eu' trigger ich-laut.
	{"tsch", "ʧʧ"},
	{"dsch", "ʤʤ"},
	{"sch", "ʃʃ"},
	{"chs", "ks"},
	{"([aɔoʊuU]" .. accent_c .. "*)ch", "%1xx"},
	{"ch", "çç"},

	-- Handling of 's'.
	{"⁀s(" .. V .. ")", "⁀z%1"},
	{"([" .. vowel .. "lrmnŋj]" .. accent_c .. "*%.?)s(" .. V .. ")", "%1z%2"},
	-- /bs/ -> [pz] before the stress as in [[absentieren]], [[Absinth]], [[absolut]], [[absorbieren]], [[absurd]],
	-- [[observieren]], [[obsessiv]], [[Obsidian]], [[Obsoleszenz]], [[subsumtiv]], but -> [ps] after the stress,
	-- as in [[Erbse]], [[Kebse]], [[obsen]], [[schubsen]]. Similarly for /ds/ -> [tz] before the stress as in
	-- [[adsorbieren]] but -> [ts] after the stress as in [[Landser]]. Note, we do not count cases like [[betriebsam]],
	-- [[beredsam]] with [pz], [tz] after the stress; -sam is treated as a separate word. In [[Trübsal]], -sal is a
	-- suffix and should be treated as if a separate word; hence, lengthened ü. [[Überbleibsel]] is given with [ps]
	-- in dewikt and Pons, consistent with the rule, but with [bz] in enwikt, which may be wrong. [[Absence]] is
	-- given with word-final stress and [ps] in dewikt, contrary to the rule, but this is an unadapted French word
	-- with a nasal vowel in it.
	--
	-- For /gs/, [[bugsieren]] is an exception with [ks]. Cf. also [[pumperlgsund]] with [ks]. All other examples with
	-- /gs/ in enwikt have a clear morpheme boundary in a compound or with a suffix.
	--
	-- No apparent examples involving /vs/, /zs/, /(d)ʒs/ that don't involve clear morpheme boundaries.
	{"([bd])s(" .. V .. ")([^⁀]*" .. stress_c .. ")", "%1z%2"},
	{"⁀s([pt])", "⁀ʃ%1"},

	-- Reduce extraneous geminate consonants (some generated above when handling digraphs etc.). Geminate consonants
	-- only have an effect directly after a vowel, and not when before a consonant other than l or r.
	{"(" .. non_V .. ")(" .. C .. ")%2", "%1%2"},
	{"(" .. C .. ")%1(" .. C_not_lr .. ")", "%1%2"},

	-- Divide into syllables.
	-- Existing potentially-relevant hyphenations/pronunciations: [[abenteuerdurstig]] -> aben|teu|er|durs|tig,
	-- [[Agraffe]] -> /aˈɡʁafə/ (but Ag|raf|fe); [[Agrarbiologie]] -> /aˈɡʁaːɐ̯bioloˌɡiː/ (but Ag|rar|bio|lo|gie);
	-- [[Anagramm]] -> (per dewikt) [anaˈɡʁam] Ana·gramm; [[Abraham]] -> /ˈaːbʁaˌha(ː)m/; [[Fabrik]] -> (per dewikt)
	-- [faˈbʁiːk] Fa·b·rik; [[administrativ]] -> /atminɪstʁaˈtiːf/; [[adjazent]] -> (per dewikt) [ˌatjaˈt͡sɛnt]
	-- ad·ja·zent; [[Adjektiv]] -> /ˈa.djɛkˌtiːf/ or /ˈat.jɛk-/, but only [ˈatjɛktiːf] per dewikt; [[Adlatus]] ->
	-- /ˌatˈlaːtʊs/ or /ˌaˈdlaːtʊs/ (same in dewikt); [[Adler]] -> /ˈʔaːdlɐ/; [[adrett]] -> /aˈdʁɛt/; [[Adstrat]] ->
	-- [atˈstʁaːt]; [[asthenisch]] -> /asˈteːnɪʃ/; [[Asthenosphäre]] -> /astenoˈsfɛːʀə/; [[Asthma]] -> [ˈast.ma];
	-- [[Astronaut]] -> /ˌas.tʁoˈnaʊ̯t/; [[asturisch]] -> [ʔasˈtuːʁɪʃ]; [[synchron]] -> /zʏnˈkʁoːn/; [[Syndrom]] ->
	-- [zʏnˈdʁoːm]; [[System]] -> /zɪsˈteːm/ or /zʏsˈteːm/.
	-- Change user-specified . into SYLDIV so we don't shuffle it around when dividing into syllables.
	{"%.", SYLDIV},
	-- Divide before the last consonant (possibly followed by a glide). We then move the syllable division marker
	-- leftwards over clusters that can form onsets.
	{"(" .. V .. accent_c .. "*" .. C .. "-)(" .. C .. V .. ")", "%1.%2", true},
	-- Cases like [[Agrobiologie]] /ˈaːɡʁobioloˌɡiː/ show that Cl or Cr where C is a non-sibilant obstruent should be
	-- kept together. It's unclear with 'dl', cf. [[Adlatus]] /ˌatˈlaːtʊs/ or /ˌaˈdlaːtʊs/; but the numerous words
	-- like [[Adler]] /ˈʔaːdlɐ/ (reduced from ''*Adeler'') suggest we should keep 'dl' together. For 'tl', we have
	-- on the one hand [[Atlas]] /ˈatlas/ and [[Detlef]] [ˈdɛtlɛf] (dewikt) but on the other hand [[Bethlehem]]
	-- /ˈbeːt.ləˌhɛm/. For simplicity we treat 'dl' and 'tl' the same.
	{"([pbfvkgtd])%.([lr])", ".%1%2"},
	-- Cf. [[Liquid]] [liˈkviːt]; [[Liquida]] [ˈliːkvida]; [[Mikwe]] /miˈkveː/; [[Taekwondo]] [tɛˈkvɔndo] (dewikt);
	-- [[Uruguayerin]] [ˈuːʁuɡvaɪ̯əʁɪn] (dewikt)
	{"([kg]).v", ".%1v"},
	-- Divide two vowels; but not if the first vowel is indicated as non-syllabic ([[Familie]], [[Ichthyologie]], etc.).
	{"(" .. V .. accent_c_no_inv_breve_below .. "*)(" .. V .. ")", "%1.%2", true},
	-- User-specified syllable divider should now be treated like regular one.
	{SYLDIV, "."},

	-- Handle vowel quality/length changes in open vs. closed syllables.
	--
	-- Convert some unstressed 'e' to schwa. It seems the following holds (excluding [[be-]] and [[ge-]] from
	-- consideration):
	-- 1. 'e' is less likely to be schwa before the stress than after.
	-- 2. Before the stress, 'e' in a closed syllable is never a schwa.
	-- 2. Initial unstressed 'e' as in [[Elektrizität]] is never a schwa.
	-- 3. Before the stress, 'e' in the first syllable is not normally a schwa, cf. [[Negativität]], [[Benefaktiv]].
	-- 4. Before the stress, 'e' in hiatus is not a schwa, cf. [[Idealisierung]].
	-- 5. In open non-initial syllables before the stress, it *MAY* be a schwa, esp. before 'r', e.g.
	--    [[Temperatur]] with /ə/; [[Generalität]] with /ə/; [[Souveränität]] with /ə/; [[Heterogenität]] with /ə/ before 'r' but /e/ later on;
	--    same for [[Kanzerogenität]]; but [[Immaterialität]] with /e/; [[Benediktiner]] optionally with /ə/ in second
	--    syllable; [[Pietät]] with /ə/; [[Sozietät]] with /ə/ but [[Varietät]] with /e/, [[abalienieren]] with /e/;
	--    [[Extremität]] with /e/; [[Illegalität]] with /e/; [[Integrität]] with /e/; [[Abbreviation]] with /e/;
	--    [[acetylieren]] with /e/; [[akkreditieren]] with /e/; [[ameliorieren]] with /e/; [[anästhesieren]] with /e/;
	--    [[degenerieren]] with /e/ /e/ /ə/; etc.
	-- 6. After the stress, 'e' is more likely to be schwa, e.g. [[zumindestens]] /t͡suˈmɪndəstəns/. But not always,
	--    e.g. [[Latex]] [ˈlaːtɛks] (dewikt); [[Index]] /ʔɪndɛks/; [[Alex]] /ˈalɛks/; [[Achilles]] [aˈxɪlɛs] (dewikt);
	--    [[Adjektiv]] /ˈa.djɛkˌtiːf/ or /ˈat.jɛk-/; [[Adstringens]] [atˈstrɪŋɡɛns]; [[Adverb]] /ˈat.vɛʁp/
	--    (or /atˈvɛʁp/); [[Agens]] /ˈaːɡɛns/; [[Ahmed]] /ˈaxmɛt/; [[Bizeps]] /ˈbiːtsɛps/; [[Borretsch]] /ˈbɔʁɛt͡ʃ/;
	--    [[Bregenz]] /ˈbʁeːɡɛnt͡s/; [[Clemens]] [ˈkleːmɛns]; [[Comeback]] /ˈkambɛk/; [[Daniel]] /ˈdaːni̯ɛl/;
	--    [[Dezibel]] /ˈdeːtsibɛl/; [[Diabetes]] /diaˈbeːtəs/ or /-tɛs/; [[Dolmetscher]] /ˈdɔlmɛtʃər/;
	--    [[Dubstep]] /ˈdapstɛp/; etc.
	-- 7. Given this analysis, we do the following:
	--    a. If before the stress, 'e' -> schwa only in an internal open syllable preceding 'r'.
	--    b. If after the stress, 'e' -> schwa only before certain clusters: [lmrn]s? or [lr]ns? or rlns? or s?t? or
	--       nds?.
	--
	-- Implement (7a) above.
	{"(" .. V .. "[^⁀]*)e(%.r[^⁀]*" .. stress_c .. ")", "%1ə%2", true},
	-- Implement (7b) above. We exclude 'e' from the 'rest' portion below so we work right-to-left and correctly
	-- convert 'e' to schwa in cases like [[Indexen]].
	{"e([^⁀" .. stress .. "e]*⁀)", function(rest)
		local rest_no_syldiv = rsub(rest, "%.", "")
		local cl = rmatch(rest_no_syldiv, "^(" .. C .. "*)")
		if rfind(cl, "^[lmrn]s?$") or rfind(cl, "^[lr]ns?$") or rfind(cl, "^rlns?$") or rfind(cl, "^s?t?$") or
			rfind(cl, "^nds?$") then
			return "ə" .. rest
		else
			return "e" .. rest
		end
	end, true},
	-- Stressed vowel in open syllable lengthens.
	{"(" .. V_unmarked_for_quality .. ")(" .. stress_c .. "[.⁀])", "%1ː%2"},
	-- Same when followed by a single consonant word-finally.
	{"(" .. V_unmarked_for_quality .. ")(" .. stress_c .. C .. "⁀)", "%1ː%2"},
	-- Unstressed vowel in open syllable takes close quality without lengthening.
	{"(" .. V_unmarked_for_quality .. ")(" .. "[.⁀])", "%1" .. CFLEX .. "%2"},
	-- Same when followed by a single consonant word-finally.
	{"(" .. V_unmarked_for_quality .. ")(" .. C .. "⁀)", "%1" .. CFLEX .. "%2"},
	-- Remaining vowel followed by a consonant becomes short in quantity and open in quality.
	{"(" .. V_unmarked_for_quality .. ")(" .. stress_c .. "?" .. C .. ")", "%1" .. BREVE .. "%2"},
	-- Vowel explicitly marked long gets close quality.
	{"(" .. V_unmarked_for_quality .. ")ː", "%1" .. CFLEX .. "ː"},
	-- Now change vowel to appropriate quality.
	{"(" .. V_unmarked_for_quality .. ")" .. CFLEX, {
		["a"] = "a",
		["e"] = "e",
		["i"] = "i",
		["o"] = "o",
		["u"] = "u",
		-- FIXME, should be split depending on "style"
		["ä"] = "ɛ",
		["ö"] = "ø",
		["ü"] = "y",
	}},
	{"(" .. V_unmarked_for_quality .. ")" .. BREVE, {
		["a"] = "a",
		["e"] = "ɛ",
		["i"] = "ɪ",
		["o"] = "ɔ",
		["u"] = "ʊ",
		["ä"] = "ɛ",
		["ö"] = "œ",
		["ü"] = "ʏ",
	}},

	-- Eliminate remaining geminate consonants within a compound part (geminates can legitimately exist across the
	-- boundary of parts of a compound). Normally such geminates will always occur across a syllable boundary, but
	-- this may not be the case in the presence of user-specified syllable boundaries.
	{"(" .. C .. ")(%.?)%1", "%1", true},

	-- Devoice consonants coda-finally. There may be more than one such consonant to devoice (cf. [[Magd]]), or the
	-- consonant to devoice may be surrounded by non-voiced or non-devoicing consonants (cf. [[Herbst]]).
	{"(" .. V .. accent_c .. "*" .. C .. "*)([bdgvzʒʤ])", function(init, voiced)
		local voiced_to_voiceless = {
			["b"] = "p",
			["d"] = "t",
			["g"] = "k",
			["v"] = "f",
			["z"] = "s",
			["ʒ"] = "ʃ",
			["ʤ"] = "ʧ",
		}
		return init .. voiced_to_voiceless[voiced]
	end, true},

	-- Add glottal stop at beginning of compound part before a vowel. FIXME: Sometimes this should not be present,
	-- I think. We need symbols to control this.
	{"⁀(" .. V .. ")", "⁀ʔ%1"},

	-- Misc symbol conversions.
	{".", {
		["I"] = "ɪ̯",
		["U"] = "ʊ̯",
		["ʧ"] = "t͡ʃ",
		["ʤ"] = "d͡ʒ",
		["ʦ"] = "t͡s",
		["g"] = "ɡ", -- map to IPA ɡ
		["r"] = "ʁ",
	}},
	{"əʁ", "ɐ"},

	-- Generate IPA stress marks.
	{AC, "ˈ"},
	{GR, "ˌ"},
	-- Move IPA stress marks to the beginning of the syllable.
	{"([.⁀])([^.⁀ˈˌ]*)([ˈˌ])", "%1%3%2"},
	-- Suppress syllable mark before IPA stress indicator.
	{"%.([ˈˌ])", "%1"},













	-- sċ between vowels when at the beginning of a syllable should be ʃ.ʃ
	{"(" .. V .. "ː?)([.ˈˌ]?)sċ(" .. V .. ")", "%1ʃ%2ʃ%3"},
	-- other sċ should be ʃ; note that sċ divided between syllables becomes s.t͡ʃ
	{"sċ", "ʃ"},
	-- x between vowels when at the beginning of a syllable should be k.s;
	-- remaining x handled below
	{"(" .. V .. "ː?)([.ˈˌ]?)x(" .. V .. ")", "%1k%2s%3"},
	-- z between vowels when at the beginning of a syllable should be t.s;
	-- remaining z handled below
	{"(" .. V .. "ː?)([.ˈˌ]?)z(" .. V .. ")", "%1t%2s%3"},
	{"nċ([.ˈˌ]?)ġ", "n%1j"},
	{"ċ([.ˈˌ]?)ġ", "j%1j"},
	{"c([.ˈˌ]?)g", "g%1g"},
	{"ċ([.ˈˌ]?)ċ", "t%1t͡ʃ"},
	{".", {
		["ċ"] = "t͡ʃ",
		["c"] = "k",
		["ġ"] = "j",
		["h"] = "x",
		["þ"] = "θ",
		["ð"] = "θ",
		["ƿ"] = "w",
		["x"] = "ks",
		["z"] = "ts",
		["g"] = "ɡ", -- map to IPA ɡ
		["a"] = "ɑ",
		["œ"] = "ø",
	}},
}

local fricative_to_voiced = {
	["f"] = "v",
	["s"] = "z",
	["θ"] = "ð",
}

local fricative_to_unvoiced = {
	["v"] = "f",
	["z"] = "s",
	["ð"] = "θ",
}

-- These rules operate in order, on the output of phonemic_rules.
-- The output of this is used to generate the displayed phonemic
-- pronunciation by removing ⁀ symbols.
local phonetic_rules = {
	-- Fricative voicing between voiced sounds. Note, the following operates
	-- across a ⁀ boundary for a fricative before the boundary but not after.
	{"([" .. voiced_sound .. "][ː.ˈˌ]*)([fsθ])([ː.ˈˌ⁀]*[" .. voiced_sound .. "])",
		function(s1, c, s2)
			return s1 .. fricative_to_voiced[c] .. s2
		end
	},
	-- Fricative between unstressed vowels should be devoiced.
	-- Note that unstressed syllables are preceded by . while stressed
	-- syllables are preceded by a stress mark.
	{"(%.[^.⁀][" .. vowel .. com.DOUBLE_BREVE_BELOW .. "ː]*%.)([vzð])",
		function(s1, c)
			return s1 .. fricative_to_unvoiced[c]
		end
	},
	-- Final unstressed -þu/-þo after a consonant should be devoiced.
	{"(" .. cons_c .. "ː?" .. "%.)ð([uo]⁀)",
		function(s1, s2)
			return s1 .. "θ" .. s2
		end
	},
	{"x[wnlr]", {
		["xw"] = "ʍ",
		["xl"] = "l̥",
		["xn"] = "n̥",
		["xr"] = "r̥",
	}},
	-- Note, the following will not operate across a ⁀ boundary.
	{"n([.ˈˌ]?[ɡk])", "ŋ%1"}, -- WARNING, IPA ɡ used here
	{"n([.ˈˌ]?)j", "n%1d͡ʒ"},
	{"j([.ˈˌ]?)j", "d%1d͡ʒ"},
	{"([^x][⁀.ˈˌ])x", "%1h"},      -- [h] occurs as a syllable-initial allophone
	{"(" .. front_V .. ")x", "%1ç"}, -- [ç] occurs after front vowels
	-- An IPA ɡ after a word/prefix boundary, after another ɡ or after n
	-- (previously converted to ŋ in this circumstance) should remain as ɡ,
	-- while all other ɡ's should be converted to ɣ except that word-final ɡ
	-- becomes x. We do this by converting the ɡ's that should remain to regular
	-- g (which should never occur otherwise), convert the remaining IPA ɡ's to ɣ
	-- or x, and then convert the regular g's back to IPA ɡ.
	{"([ŋɡ⁀][.ˈˌ]?)ɡ", "%1g"}, -- WARNING, IPA ɡ on the left, regular g on the right
	{"ɡ", "ɣ"},
	{"g", "ɡ"}, -- WARNING, regular g on the left, IPA ɡ on the right
	{"l([.ˈˌ]?)l", "ɫ%1ɫ"},
	{"r([.ˈˌ]?)r", "rˠ%1rˠ"},
	{"l([.ˈˌ]?" .. cons_c .. ")", "ɫ%1"},
	{"r([.ˈˌ]?" .. cons_c .. ")", "rˠ%1"},
	-- Geminate consonants within a single syllable are pronounced singly.
	-- Does not apply e.g. to ''ǣttren'', which will be divided as ''ǣt.tren''.
	{"(" .. cons_c .. ")%1", "%1"},
	{"rˠrˠ", "rˠ"},
	-- In the sequence vowel + obstruent + resonant in a single syllable,
	-- the resonant should become syllabic, e.g. ādl [ˈɑːdl̩], blōstm [bloːstm̩],
	-- fæþm [fæðm̩], bēacn [ˈbæːɑ̯kn̩]. We allow anything but a syllable or word
	-- boundary betweent the vowel and the obstruent.
	{"(" .. V .. "[^.ˈˌ⁀]*[" .. obstruent .. "]ː?[" .. resonant .. "])", "%1" .. com.SYLLABIC},
	-- also -mn e.g stemn /ˈstemn̩/; same for m + other resonants except m
	{"(" .. V .. "[^.ˈˌ⁀]*mː?[lnŋrɫ])", "%1" .. com.SYLLABIC},
	{".", explicit_char_to_IPA},
}

local function apply_rules(word, rules)
	for _, rule in ipairs(rules) do
		word = rsub(word, rule[1], rule[2])
	end
	return word
end

local function lookup_stress_spec(stress_spec, pos)
	return stress_spec[pos] or (pos == "verbal" and stress_spec["verb"]) or nil
end

local function split_on_word_boundaries(word, pos)
	local retparts = {}
	local parts = strutils.capturing_split(word, "([<>%-])")
	local i = 1
	local saw_primary_stress = false
	while i <= #parts do
		local split_part = false
		local insert_position = #retparts + 1
		if parts[i + 1] ~= "<" and parts[i - 1] ~= ">" then
			-- Split off any prefixes.
			while true do
				local broke_prefix = false
				for _, prefixspec in ipairs(com.prefixes) do
					local prefix_pattern = prefixspec[1]
					local stress_spec = prefixspec[2]
					local pos_stress = lookup_stress_spec(stress_spec, pos)
					local prefix, rest = rmatch(parts[i], "^(" .. prefix_pattern .. ")(.*)$")
					if prefix then
						if not pos_stress then
							-- prefix not recognized for this POS, don't split here
						elseif stress_spec.restriction and not rfind(rest, stress_spec.restriction) then
							-- restriction not met, don't split here
						elseif rfind(rest, "^%+") then
							-- explicit non-boundary here, so don't split here
						elseif not rfind(rest, V) then
							-- no vowels, don't split here
						elseif rfind(rest, "^..?$") then
							-- only two letters, unlikely to be a word, probably an ending, so don't split
							-- here
						else
							local initial_cluster, after_cluster = rmatch(rest, "^(" .. non_V .. "*)(.-)$")
							if rfind(initial_cluster, "..") and (
								not (com.onsets_2[initial_cluster] or com.secondary_onsets_2[initial_cluster] or
									com.onsets_3[initial_cluster])) then
								-- initial cluster isn't a possible onset, don't split here
							elseif rfind(initial_cluster, "^x") then
								-- initial cluster isn't a possible onset, don't split here
							elseif rfind(after_cluster, "^" .. V .. "$") then
								-- remainder is a cluster + short vowel,
								-- unlikely to be a word so don't split here
							else
								-- break the word in two; next iteration we process
								-- the rest, which may need breaking again
								parts[i] = rest
								if pos_stress == "unstressed" then
									-- don't do anything
								elseif pos_stress == "secstressed" or (saw_primary_stress and pos_stress == "stressed") then
									prefix = rsub(prefix, "(" .. V .. ")", "%1" .. AUTOGRAVE, 1)
								elseif pos_stress == "stressed" then
									prefix = rsub(prefix, "(" .. V .. ")", "%1" .. AUTOACUTE, 1)
									saw_primary_stress = true
								else
									error("Unrecognized stress spec for pos=" .. pos .. ", prefix=" .. prefix .. ": " .. pos_stress)
								end
								table.insert(retparts, insert_position, prefix)
								insert_position = insert_position + 1
								broke_prefix = true
								break
							end
						end
					end
				end
				if not broke_prefix then
					break
				end
			end

			-- Now do the same for suffixes.
			while true do
				local broke_suffix = false
				for _, suffixspec in ipairs(com.suffixes) do
					local suffix_pattern = suffixspec[1]
					local stress_spec = suffixspec[2]
					local pos_stress = lookup_stress_spec(stress_spec, pos)
					local rest, suffix = rmatch(parts[i], "^(.-)(" .. suffix_pattern .. ")$")
					if suffix then
						if not pos_stress then
							-- suffix not recognized for this POS, don't split here
						elseif stress_spec.restriction and not rfind(rest, stress_spec.restriction) then
							-- restriction not met, don't split here
						elseif rfind(rest, "%+$") then
							-- explicit non-boundary here, so don't split here
						elseif not rfind(rest, V) then
							-- no vowels, don't split here
						else
							local before_cluster, final_cluster = rmatch(rest, "^(.-)(" .. non_V .. "*)$")
							if rfind(final_cluster, "%..") then
								-- syllable division within or before final
								-- cluster, don't split here
							else
								-- break the word in two; next iteration we process
								-- the rest, which may need breaking again
								parts[i] = rest
								if pos_stress == "unstressed" then
									-- don't do anything
								elseif pos_stress == "secstressed" then
									prefix = rsub(suffix, "(" .. V .. ")", "%1" .. AUTOGRAVE, 1)
								elseif pos_stress == "stressed" then
									error("Primary stress not allowed for suffixes (suffix=" .. suffix .. ")")
								else
									error("Unrecognized stress spec for pos=" .. pos .. ", suffix=" .. suffix .. ": " .. pos_stress)
								end
								table.insert(retparts, insert_position, suffix)
								broke_suffix = true
								break
							end
						end
					end
				end
				if not broke_suffix then
					break
				end
			end
		end

		local acc = rfind(parts[i], "(" .. stress_accent_c .. ")")
		if acc == com.CFLEX then
			-- remove circumflex but don't accent
			parts[i] = gsub(parts[i], com.CFLEX, "")
		elseif acc == com.ACUTE or acc == AUTOACUTE then
			saw_primary_stress = true
		elseif not acc and parts[i + 1] ~= "<" and parts[i - 1] ~= ">" then
			-- Add primary or secondary stress on the part; primary stress if no primary
			-- stress yet, otherwise secondary stress.
			acc = saw_primary_stress and AUTOGRAVE or AUTOACUTE
			saw_primary_stress = true
			parts[i] = rsub(parts[i], "(" .. V .. ")", "%1" .. acc, 1)
		end
		table.insert(retparts, insert_position, parts[i])
		i = i + 2
	end

	-- remove any +, which has served its purpose
	for i, part in ipairs(retparts) do
		retparts[i] = gsub(part, "%+", "")
	end
	return retparts
end

local function break_vowels(vowelseq)
	local function check_empty(char)
		if char ~= "" then
			error("Something wrong, non-vowel '" .. char .. "' seen in vowel sequence '" .. vowelseq .. "'")
		end
	end

	local vowels = {}
	local chars = strutils.capturing_split(vowelseq, "(" .. V .. accent_c .. "*)")
	local i = 1
	while i <= #chars do
		if i % 2 == 1 then
			check_empty(chars[i])
			i = i + 1
		else
			if i < #chars - 1 and com.diphthongs[
				rsub(chars[i], stress_accent_c, "") .. rsub(chars[i + 2], stress_accent_c, "")
			] then
				check_empty(chars[i + 1])
				table.insert(vowels, chars[i] .. chars[i + 2])
				i = i + 3
			else
				table.insert(vowels, chars[i])
				i = i + 1
			end
		end
	end
	return vowels
end

-- Break a word into alternating C and V components where a C component is a run
-- of zero or more consonants and a V component in a single vowel or dipthong.
-- There will always be an odd number of components, where all odd-numbered
-- components (starting from 1) are C components and all even-numbered components
-- are V components.
local function break_into_c_and_v_components(word)
	local cons_vowel = strutils.capturing_split(word, "(" .. vowel_or_accent_c .. "+)")
	local components = {}
	for i = 1, #cons_vowel do
		if i % 2 == 1 then
			table.insert(components, cons_vowel[i])
		else
			local vowels = break_vowels(cons_vowel[i])
			for j = 1, #vowels do
				if j == 1 then
					table.insert(components, vowels[j])
				else
					table.insert(components, "")
					table.insert(components, vowels[j])
				end
			end
		end
	end
	return components
end

local function split_into_syllables(word)
	local cons_vowel = break_into_c_and_v_components(word)
	if #cons_vowel == 1 then
		return cons_vowel
	end
	for i = 1, #cons_vowel do
		if i % 2 == 1 then
			-- consonant
			local cluster = cons_vowel[i]
			local len = ulen(cluster)
			if i == 1 then
				cons_vowel[i + 1] = cluster .. cons_vowel[i + 1]
			elseif i == #cons_vowel then
				cons_vowel[i - 1] = cons_vowel[i - 1] .. cluster
			elseif rfind(cluster, "%.") then
				local before_break, after_break = rmatch(cluster, "^(.-)%.(.*)$")
				cons_vowel[i - 1] = cons_vowel[i - 1] .. before_break
				cons_vowel[i + 1] = after_break .. cons_vowel[i + 1]
			elseif len == 0 then
				-- do nothing
			elseif len == 1 then
				cons_vowel[i + 1] = cluster .. cons_vowel[i + 1]
			elseif len == 2 then
				local c1, c2 = rmatch(cluster, "^(.)(.)$")
				if c1 == "s" and c2 == "ċ" then
					cons_vowel[i + 1] = "sċ" .. cons_vowel[i + 1]
				else
					cons_vowel[i - 1] = cons_vowel[i - 1] .. c1
					cons_vowel[i + 1] = c2 .. cons_vowel[i + 1]
				end
			else
				-- check for onset_3 preceded by consonant(s).
				local first, last3 = rmatch(cluster, "^(.-)(...)$")
				if #first > 0 and com.onsets_3[last3] then
					cons_vowel[i - 1] = cons_vowel[i - 1] .. first
					cons_vowel[i + 1] = last3 .. cons_vowel[i + 1]
				else
					local first, last2 = rmatch(cluster, "^(.-)(..)$")
					if com.onsets_2[last2] or (com.secondary_onsets_2[last2] and not first:find("[lr]$")) then
						cons_vowel[i - 1] = cons_vowel[i - 1] .. first
						cons_vowel[i + 1] = last2 .. cons_vowel[i + 1]
					else
						local first, last = rmatch(cluster, "^(.-)(.)$")
						cons_vowel[i - 1] = cons_vowel[i - 1] .. first
						cons_vowel[i + 1] = last .. cons_vowel[i + 1]
					end
				end
			end
		end
	end

	local retval = {}
	for i = 1, #cons_vowel do
		if i % 2 == 0 then
			-- remove any stray periods.
			table.insert(retval, rsub(cons_vowel[i], "%.", ""))
		end
	end
	return retval
end

-- Combine syllables into a word, moving stress markers (acute/grave) to the
-- beginning of the syllable.
local function combine_syllables_moving_stress(syllables, no_auto_stress)
	local modified_syls = {}
	for i, syl in ipairs(syllables) do
		if syl:find(com.ACUTE) or syl:find(AUTOACUTE) and not no_auto_stress then
			syl = "ˈ" .. syl
		elseif syl:find(com.GRAVE) or syl:find(AUTOGRAVE) and not no_auto_stress then
			syl = "ˌ" .. syl
		elseif i > 1 then
			syl = "." .. syl
		end
		syl = rsub(syl, stress_accent_c, "")
		table.insert(modified_syls, syl)
	end
	return table.concat(modified_syls)
end

-- Combine word parts (split-off prefixes, suffixes or parts of a compound word)
-- into a single word. Separate parts with ⁀ and the put ⁀⁀ at word boundaries.
local function combine_parts(parts)
	local text = {}
	for i, part in ipairs(parts) do
		if i > 1 and not rfind(part, "^[ˈˌ]") then
			-- Need a syllable boundary if there isn't a stress marker.
			table.insert(text, ".")
		end
		table.insert(text, part)
	end
	return "⁀⁀" .. table.concat(text, "⁀") .. "⁀⁀"
end

local function transform_word(word, pos, no_auto_stress)
	word = com.decompose(word)
	local parts = split_on_word_boundaries(word, pos)
	for i, part in ipairs(parts) do
		local syllables = split_into_syllables(part)
		parts[i] = combine_syllables_moving_stress(syllables,
			no_auto_stress or (#parts == 1 and #syllables == 1))
	end
	return combine_parts(parts)
end

local function default_pos(word, pos)
	if not pos then
		-- verbs in -an/-ōn/-ēon, inflected infinitives in -enne
		if rfind(word, "[aāō]n$") or rfind(word, "ēon$") or rfind(word, "enne$") then
			pos = "verb"
		else
			-- adjectives in -līċ, adverbs in -līċe and nouns in -nes can follow
			-- nouns or participles (which are "verbal"); truncate the ending
			-- and check what precedes
			word = rsub(word, "^(.*" .. V .. ".*)l[iī][cċ]e?$", "%1")
			word = rsub(word, "^(.*" .. V .. ".*)n[eiy]ss?$", "%1")
			-- participles in -end(e)/-en/-ed/-od, verbal nouns in -ing/-ung
			if rfind(word, "ende?$") or rfind(word, "[eo]d$") or rfind(word, "en$")
				or rfind(word, "[iu]ng$") then
				pos = "verbal"
			else
				pos = "noun"
			end
		end
	elseif pos == "adj" or pos == "adjective" then
		pos = "noun"
	elseif pos ~= "noun" and pos ~= "verb" and pos ~= "verbal" then
		error("Unrecognized part of speech: " .. pos)
	end
	return pos
end

local function generate_phonemic_word(word, pos)
	word = gsub(word, "[.!?]$", "")
	word = rsub(word, "%[(.)%]", char_to_explicit_char)
	pos = default_pos(word, pos)
	local is_prefix_suffix
	if word:find("^%-") or word:find("%-$") then
		is_prefix_suffix = true
		word = gsub(word, "^%-?(.-)%-?$", "%1")
	end
	word = transform_word(word, pos, is_prefix_suffix)
	word = apply_rules(word, phonemic_rules)
	return word
end

function export.phonemic(text, pos)
	if type(text) == "table" then
		pos = text.args["pos"]
		text = text[1]
	end
	local result = {}
	text = ulower(text)
	for word in rgsplit(text, " ") do
		table.insert(result, generate_phonemic_word(word, pos))
	end
	result = table.concat(result, " ")
	result = rsub(result, ".", explicit_char_to_phonemic)
	result = gsub(result, "⁀", "")
end

function export.phonetic(text, pos)
	if type(text) == "table" then
		pos = text.args["pos"]
		text = text[1]
	end
	local result = {}
	text = ulower(text)
	for word in rgsplit(text, " ") do
		word = generate_phonemic_word(word, pos)
		word = apply_rules(word, phonetic_rules)
		table.insert(result, word)
	end
	return gsub(table.concat(result, " "), "⁀", "")
end

function export.show(frame)
	local parent_args = frame:getParent().args
	local params = {
		[1] = { required = true, default = "hlǣf-dīġe", list = true },
		["pos"] = {},
		["ann"] = {},
	}
	local args = require("Module:parameters").process(parent_args, params)

	local IPA_args = {}
	for _, arg in ipairs(args[1]) do
		local phonemic = export.phonemic(arg, args.pos)
		local phonetic = export.phonetic(arg, args.pos)
		table.insert(IPA_args, {pron = '/' .. phonemic .. '/'})
		if phonemic ~= phonetic then
			table.insert(IPA_args, {pron = '[' .. phonetic .. ']'})
		end
	end

	local anntext
	if args.ann == "1" then
		anntext = {}
		for _, arg in ipairs(args[1]) do
			-- remove all spelling markup except ġ/ċ and macrons
			arg = rsub(com.decompose(arg), "[%-+._<>" .. com.ACUTE .. com.GRAVE .. com.CFLEX .. "]", "")
			arg = rsub(arg, "%[(.)%]", char_to_spelling)
			m_table.insertIfNot(anntext, "'''" .. arg .. "'''")
		end
		anntext = table.concat(anntext, ", ") .. ":&#32;"
	elseif args.ann then
		anntext = "'''" .. args.ann .. "''':&#32;"
	else
		anntext = ""
	end

	return anntext .. m_IPA.format_IPA_full(lang, IPA_args)
end

return export
