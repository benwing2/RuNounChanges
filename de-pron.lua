--[=[

Implementation of pronunciation-generation module from spelling for German.

Author: Benwing

The following symbols can be used:
-- Acute accent on a vowel to override the position of primary stress; in a diphthong, put it over the first vowel:
--   á é í ó ú ä́ ö́ ǘ ái éi áu ä́u éu
-- Grave accent to add secondary stress: à è ì ò ù ä̀ ö̀ ǜ ài èi àu ä̀u èu
-- 'h' or ː after a vowel to force it to be long.
-- Circumflex on a vowel (â ê î ô û ä̂ ö̂ ü̂) to force it to have closed quality.
-- Breve on a vowel, including a stressed vowel (ă ĕ ĭ ŏ ŭ ä̆ ö̆ ü̆) to force it to have open quality.
-- Tilde on a vowel or capital N afterwards to indicate nasalization.
-- For an unstressed 'e', force its quality using schwa (ə) to indicate a schwa, breve (ĕ) to indicate open quality /ɛ/,
--   circumflex (ê) to indicate closed quality /e/.
-- . (period) to force a syllable boundary.
-- - (hyphen) to indicate a word/word boundary in a compound word; the result will be displayed as a single word but
--   the consonants on either side treated as if they occurred at the beginning/end of the word, and each part of the
--   compound gets its own stress (primary stress on the first part unless another part has primary stress, secondary
--   stress on the remaining parts unless stress is explicitly included).
-- < (less-than) to indicate a prefix/word or prefix/prefix boundary; similar to - for word/word boundary, but the
--   prefix before the < sign will be unstressed.
-- > (greater-than) to indicate a word/suffix or suffix/suffix boundary; similar to - for word/word boundary, but the
--   suffix after the > sign will be unstressed.
-- + (plus) is the opposite of -; it forces a prefix/word, word/word or word/suffix boundary to *NOT* occur when it
--   otherwise would. 
-- _ (underscore) to force the letters on either side to be interpreted independently, when the combination of the two
--   would normally have a special meaning.
--  ̣ (dot under) on any vowel in a word or component to prevent it from getting any stress.

Notes:

1. Doubled consonants, as well as digraphs/trigraphs etc. like 'ch', 'ng', 'tz', 'sch', 'tsch', etc. cause a
   preceding vowel to be short and open (/ɛ ɪ ɔ ʊ œ ʏ/) unless lengthened with h or ː.
2. With occasional exceptions, a vowel before a single consonant (including at the end of a word or compound part)
   is closed (/e i o u ø y/), and long if stressed (primary or secondary). 
3. The vowel 'e' is rendered by default as schwa (/ə/) in the following circumstances:
   a. The prefixes 'ge-', 'be-' are recognized specially and rendered with a schwa and without stress. This doesn't
      apply if the 'e' is respelled with an accent, e.g. 'Génitiev' for [[Genitiv]] "genitive" or 'géstern' for
	  [[gestern]] "yesterday".
	  It also doesn't happen if a + is placed at the putative prefix boundary, hence [[Geograf]] "geographer" could be
	  respelled 'Ge+ográf' to prevent 'Ge' from being interpreted as a prefix. Finally, it doesn't happen if the
	  cluster following the 'ge-' or 'be-' cannot be the start of a German word, e.g. [[bellen]] "to bark" ('ll' cannot
	  start a word) or [[bengalisch]] "Bengal" ('ng' cannot start a word).
   a. If there is a following stress in the word, only in an internal (non-initial) open unstressed syllable (i.e.
      followed by only a single consonant) when 'r' follows, as in Temp̱e̱ratur, Gene̱ralität, Souve̱ränität, Hete̱rogenität,
      degene̱rieren, where the underlined vowels are by default rendered as a schwa. Other cases with schwa like
	  [[Sozietät]] or [[Pietät]] need to be respelled with a schwa, e.g. 'Soziǝtät', 'Pìǝtät'.
   b. If there is no following stress, any 'e' word-finally or followed by consonants that might form part of an
      inflectional ending is rendered as a schwa, e.g. Lage̱, zuminde̱ste̱ns, verschiede̱ne̱n, verwende̱t. Examples where
	  this does not happen are Late̱x, Ahme̱d, Bize̱ps, Borre̱tsch, Brege̱nz, which would be rendered by default with /ɛ/ or
	  /e/. Cases like [[Achilles]] and [[Agens]] that have /ɛ/ but end in what looks like an inflectional ending should
	  be respelled with ĕ.
4. Obstruents 'b' 'd' 'g' 'v' 'ʒ' are normally rendered as voiceless /p t k f ʃ/ at the end of a word or syllable.
   To cause them to be voiced, one way is to move the syllable boundary before the consonant by inserting a . before
   the consonant. If that isn't appropriate, put brackets around the sound, as in '[b]', '[d]', '[z]', etc.
5. 'v' is normally rendered as underlying /v/ (which becomes /f/ at the end of a word or syllable). Words like [[vier]],
   [[viel]], [[Vater]], etc. need respelling using 'f'. Note that prefixes ver-, vor-, voraus-, vorher-, etc. are
   recognized specially.
6. French-derived words often need respelling and may have sounds in them that don't have standard spellings in
   German. For example, [[Orange]] can be spelled 'Orã́ʒe' or 'OráNʒe'; use a tilde or a following capital N to
   indicate a nasal vowel, and use a 'ʒ' character to render the sound /ʒ/.
7. Rendering of 'ch' using ich-laut /ç/ or ach-laut /x/ is automatic. To force one or the other, use 'ç' explicitly
   (as in 'Açilles-ferse' for one pronunciation of [[Achillesferse]] "Achilles heel") or 'x' explicitly (as in
   '[X]uzpe' for [[Chuzpe]] "chutzpah").
8. Vowels 'i' and 'u' in hiatus (i.e. directly before another vowel) are normally converted into glides, i.e. /i̯ u̯/,
   as in [[effizient]] (no respelling needed as '-ent' is recognized as a stressed suffix), [[Antigua]] (respelled
   'Antíguah'). To preven this, add a '.' between the vowels to force a syllable boundary, as in [[aktualisieren]]
   'àktu.alisieren'. An exception to the glide conversion is the digraph 'ie'; to force glide conversion, as in
   [[Familie]], use 'i̯' explicitly (respelled 'Famíli̯e'). Occasionally the  ̯ symbol needs to be added to other vowels,
   e.g. in [[Ichthyologie]] respelled 'Ichthy̯ologie' (note that '-ie' is a recognized stressed suffix) and
   [[soigniert]] respelled 'so̯anjiert' ('-iert' is a recognized stressed suffix).

FIXME:

1. Implement < and > which works like - but don't trigger secondary stress (< after a prefix, > before a suffix).
2. Implement prefix/suffix stripping; don't do it if explicit syllable boundary in cluster after prefix, or if no
   vowel in main, or if impossible prefix/suffix onset/offset.
3. Finish entering prefixes and suffixes.
4. Add default stresses.
5. Handle inflectional suffixes: adjectival -e, -en, -em, -er, -es, also after adjectival -er, -st; nominal -(e)s,
   -(e)n; verbal -e, -(e)st, -(e)t, -(e)n, -(e)te, -(e)tst, -(e)tet, -(e)ten.
6. Ignore final period/question mark/exclamation point.
7. Implement nasal vowels.
8. Implement underscore to prevent assimilation/interpretation as a multigraph.
9. Implement [b] [d] [g] [z] [v] [ʒ] [x].
10. Implement dot-under to prevent stress.
]=]

local export = {}

local force_cat = false -- for testing

local strutils = require("Module:string utilities")
local m_table = require("Module:table")
local m_IPA = require("Module:IPA")
local lang = require("Module:languages").getByCode("de")

local u = mw.ustring.char
local rsubn = mw.ustring.gsub
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local rgsplit = mw.text.gsplit
local ulen = mw.ustring.len
local ulower = mw.ustring.lower

local AC = u(0x0301) -- COMBINING ACUTE ACCENT =  ́
local GR = u(0x0300) -- COMBINING GRAVE ACCENT =  ̀
local CFLEX = u(0x0302) -- COMBINING CIRCUMFLEX ACCENT =  ̂
local TILDE = u(0x0303) -- COMBINING TILDE =  ̃
local MACRON = u(0x0304) -- COMBINING MACRON =  ̄
local BREVE = u(0x0306) -- COMBINING BREVE =  ̆
local DIA = u(0x0308) -- COMBINING DIAERESIS =  ̈
local DOTOVER = u(0x0307) -- COMBINING DOT ABOVE =  ̇
local UNRELEASED = u(0x031A) -- COMBINING LEFT ANGLE ABOVE =  ̚
local DOTUNDER = u(0x0323) -- COMBINING DOT BELOW =  ̣
local UNVOICED = u(0x0325) -- COMBINING RING BELOW =  ̥
local SYLLABIC = u(0x0329) -- COMBINING VERTICAL LINE BELOW =  ̩
local INVBREVEBELOW = u(0x032F) -- COMBINING INVERTED BREVE BELOW =  ̯
local LINEUNDER = u(0x0331) -- COMBINING MACRON BELOW =  ̱
local TIE = u(0x0361) -- COMBINING DOUBLE INVERTED BREVE =  ͡

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

-- apply rsub() repeatedly until no change
local function rsub_repeatedly(term, foo, bar)
	while true do
		local new_term = rsub(term, foo, bar)
		if new_term == term then
			return term
		end
		term = new_term
	end
end

-- Apply canonical Unicode decomposition to text, e.g. è → e + ◌̀. But recompose ä ö ü so we can treat them as single
-- vowels, and put stress accents (acute/grave) after indicators of length and quality.
local function decompose(text)
	text = mw.ustring.toNFD(text)
	text = rsub(text, "." .. DIA, {
		["a" .. DIA] = "ä",
		["A" .. DIA] = "Ä",
		["o" .. DIA] = "ö",
		["O" .. DIA] = "Ö",
		["u" .. DIA] = "ü",
		["U" .. DIA] = "Ü",
	})
	text = rsub(text, "([" .. AC .. GR .. "])([" .. BREVE .. CFLEX .. MACRON .. "ː]+)", "%2%1")
	return text
end

-- Canonicalize multiple spaces and remove leading and trailing spaces.
local function canon_spaces(text)
	text = rsub(text, "%s+", " ")
	text = rsub(text, "^ ", "")
	text = rsub(text, " $", "")
	return text
end

-- When auto-generating primary and secondary stress accents, we use these
-- special characters, and later convert to normal IPA accent marks, so
-- we can distinguish auto-generated stress from user-specified stress.
local AUTOACUTE = u(0xFFF0)
local AUTOGRAVE = u(0xFFF1)

-- When the user uses the "explicit allophone" notation such as [z] or [x] to force a particular allophone, we
-- internally convert that notation into a single special character.
local EXPLICIT_S = u(0xFFF2)
local EXPLICIT_Z = u(0xFFF3)
local EXPLICIT_V = u(0xFFF4)
local EXPLICIT_B = u(0xFFF5)
local EXPLICIT_D = u(0xFFF6)
local EXPLICIT_G = u(0xFFF7)
local EXPLICIT_X = u(0xFFF8)

-- Map "explicit allophone" notation into special char. See above.
local char_to_explicit_char = {
	["s"] = EXPLICIT_S,
	["z"] = EXPLICIT_Z,
	["v"] = EXPLICIT_V,
	["b"] = EXPLICIT_B,
	["d"] = EXPLICIT_D,
	["g"] = EXPLICIT_G,
	["x"] = EXPLICIT_X,
}

-- Map "explicit allophone" notation into normal spelling, for supporting ann=.
local char_to_spelling = {
	["s"] = "s",
	["z"] = "s",
	["v"] = "v",
	["b"] = "b",
	["d"] = "d",
	["g"] = "g",
	["x"] = "ch",
}

-- Map "explicit allophone" notation into phonemes.
local explicit_char_to_phonemic = {
	[EXPLICIT_S] = "s",
	[EXPLICIT_Z] = "z",
	[EXPLICIT_V] = "v",
	[EXPLICIT_B] = "b",
	[EXPLICIT_D] = "d",
	[EXPLICIT_G] = "ɡ", -- IPA ɡ!
	[EXPLICIT_X] = "x",
}

local stress = AC .. GR
local stress_c = "[" .. stress .. "]"
local accent_non_stress_non_invbrevebelow = BREVE .. CFLEX .. MACRON .. "ː"
local accent_non_stress = accent_non_stress_non_invbrevebelow .. INVBREVEBELOW
local accent_non_stress_c = "[" .. accent_non_stress .. "]"
local accent = stress .. accent_non_stress
local accent_c = "[" .. accent .. "]"
local accent_non_invbrevebelow = stress .. accent_non_stress_non_invbrevebelow
local accent_non_invbrevebelow_c = "[" .. accent_non_invbrevebelow .. "]"
local non_accent_c = "[^" .. accent .. "]"
-- Use both IPA symbols and letters so it can be used at any step of the process.
local back_vowel_non_glide = "aɑoɔuʊ"
local back_vowel = back_vowel_non_glide .. "U"
local back_vowel_c = "[" .. back_vowel .. "]"
local front_vowel_non_glide = "eɛiɪyʏøœäöü"
local front_vowel = front_vowel_non_glide .. "I"
local vowel = back_vowel .. front_vowel .. "ə"
local V = "[" .. vowel .. "]"
local non_V = "[^" .. vowel .. "]"
local vowel_non_glide = back_vowel_non_glide .. front_vowel_non_glide .. "ə"
local V_non_glide = "[" .. vowel_non_glide .. "]"
local vowel_unmarked_for_quality = "aeiouäöü"
local V_unmarked_for_quality = "[" .. vowel_unmarked_for_quality .. "]"
local charsep = accent .. "." .. SYLDIV
local charsep_c = "[" .. charsep .. "]"
local wordsep = charsep .. " ⁀"
local wordsep_c = "[" .. wordsep .. "]"
local cons_guts = "^" .. vowel .. wordsep .. "_" -- guts of consonant class
local C = "[" .. cons_guts .. "]" -- consonant
local C_not_lr = "[" .. cons_guts .. "lr]" -- consonant not 'l' or 'r'
-- Include both regular g and IPA ɡ so it can be used anywhere
local obstruent_non_sibilant = "pbfvkgɡtdxç" .. EXPLICIT_B .. EXPLICIT_D .. EXPLICIT_G .. EXPLICIT_V .. EXPLICIT_X
local obstruent_non_sibilant_c = "[" .. obstruent_non_sibilant .. "]"
local unvoiced_cons = "ptkfsßʃxç" .. EXPLICIT_S .. EXPLICIT_X
local unvoiced_cons_c = "[" .. unvoiced_cons .. "]"


-- FIXME: -ge- and -zu- can occur after any stressed prefix.
local prefixes = {
	{"ab", {respelling = "ább"}},
	{"an", {respelling = "ánn"}},
	{"auf", {respelling = "áuf"}},
	{"aus", {respelling = "áus"}},
	{"auseinander", {respelling = "àus-einánder"}},
	{"bei", {respelling = "béi"}},
	{"be", {respelling = "bə", restriction = "^[^u]"}},
	{"durch", {respelling = "dúrch"}},
	{"ein", {respelling = "éin"}},
	{"emp", {restriction = "^f"}},
	{"ent"},
	{"fort", {respelling = "fórt"}},
	-- Most words in 'gei-' aren't past participles. There are only a few, e.g. [[geimpft]].
	-- No restriction on 'geu-' because only one non-past-participle observed: [[Geusenwort]], and there are
	-- various past participles in 'geu-', especially 'geur-'.
	{"ge", {respelling = "gə", restriction = "^[^i]"}},
	{"herab", {respelling = "herrább"}},
	{"heran", {respelling = "herránn"}},
	{"herauf", {respelling = "herráuf"}},
	{"heraus", {respelling = "herráus"}},
	{"herbei", {respelling = "herbéi"}},
	{"herein", {respelling = "herréin"}},
	{"herüber", {respelling = "herrǘber"}},
	{"herum", {respelling = "herrúmm"}},
	{"herunter", {respelling = "herrúnter"}},
	{"hervor", {respelling = "herfór"}},
	{"her", {respelling = "hérr"}},
	{"hinab", {respelling = "hinnább"}},
	{"hinan", {respelling = "hinnánn"}},
	{"hinauf", {respelling = "hinnáuf"}},
	{"hinaus", {respelling = "hinnáus"}},
	{"hinbe", {respelling = "hínbe"}}, --barely exists
	-- hinbei doesn't appear to exist
	{"hinein", {respelling = "hinnéin"}},
	{"hinter", {respelling = "hínter"}},
	{"hinüber", {respelling = "hinnǘber"}},
	-- hinum doesn't appear to exist
	{"hinunter", {respelling = "hinnúnter"}},
	-- hinvor doesn't appear to exist
	{"hin", {respelling = "hínn"}},
	-- too many false positives for in-
	{"miss"},
	{"mit", {respelling = "mítt"}},
	{"über", {respelling = "ǘber"}},
	{"um", {respelling = "úmm"}},
	{"un", {respelling = "únn", combinable = true}},
	{"unter", {respelling = "únter"}},
	{"ver", {respelling = "ferr"}},
	{"voran", {respelling = "foránn"}},
	{"voraus", {respelling = "foráus"}},
	{"vorbei", {respelling = "fohrbéi"}}, -- respelling per dewikt pronun
	{"vorbe", {respelling = "fóhrbe", restriction = "^[^u]"}}, -- respelling per dewikt pronun
	{"vorder", {respelling = "fórder"}},
	{"vorher", {respelling = "fohrhér"}}, -- respelling per dewikt pronun
	{"vorüber", {respelling = "forǘber"}},
	{"vorver", {respelling = "fóhrfer"}}, -- respelling per dewikt pronun
	{"vor", {respelling = "fór"}},
	{"wider", {respelling = {n = "wíder", v = "wìder"}}},
	{"wieder", {respelling = "wíeder"}},
	{"wiederver", {respelling = "wíeder-ferr<"}},
	{"zer", {respelling = "zerr"}},
}

export.suffixes = {
	{"([ae])nt", {respell = "%1́nt", pos = {"n", "a"}}},
	{"([ai])bel", {respell = "%1́bel", pos = "a"}},
	-- Normally following consonant but there a few exceptions like [[abbaubar]], [[recyclebar]], [[unüberschaubar]].
	-- Cases like [[isobar]] will be respelled with an accent and not affected.
	{"bar", {respell = "bàr", pos = "a"}},
	-- Restrict to not follow a vowel or s (except for -ss) to avoid issues with nominalized infinitives in -chen.
	-- Words with -chen after a vowel or s need to be respelled with '>chen', as in [[Frauchen]], [[Wodkachen]],
	-- [[Häuschen]], [[Bläschen]], [[Füchschen]], [[Gänschen]], etc. Occasional gerunds of verbs in -rchen may need
	-- to be respelled with '+chen' to avoid the preceding vowel being long, as in [[Schnarchen]].
	{"chen", {respell = "çen", pos = "n", restriction = {"[^" .. accent .. vowel .. "]$", "[^s]s$"}}},
	{"ei", {respell = "éi", pos = "n", restriction = cons_c .. "$"}},
	-- Normally following consonant but there a few exceptions like [[säurefest]]. Cases like [[manifest]] will be
	-- respelled with an accent and not affected.
	{"fest", {respell = "fèst", pos = "a"}},
	{"schaft", {respell = "schàft", pos = "n"}},
	{"haft", {respell = "hàft", pos = "a"}},
	{"([hk])eit", {respell = "%1èit", pos = "n"}},
	-- NOTE: This will get converted to secondary stress if there is a primary stress elsewhere in the word (e.g. in
	-- compound words).
	{"ie", {respell = "íe", pos = "n", restriction = cons_c .. "$"}},
	-- No restriction to not occur after a/e; [[kreieren]] does occur and noun form and verbs in -en after -aier/-eier
	-- should not occur (instead you get -aiern/-eiern). Occurs with both nouns and verbs.
	{"ieren", {respell = "íeren", pos = "v"}},
	-- See above. Occurs with adjectives and participles, and also [[Gefiert]].
	{"iert", {respell = "íert", pos = "a"}},
	-- See above. Occurs with nouns.
	{"ierung", {respell = "íerung", pos = "n"}},
	-- "isch" not needed here; no respelling needed and vowel-initial
	-- NOTE: This will get converted to secondary stress if there is a primary stress elsewhere in the word (e.g. in
	-- compound words like [[Abwehrmechanismus]] or [[Lügenjournalismus]]).
	{"ismus", {respell = "ísmus", pos = "n"}},
	{"ist", {respell = "íst", pos = "n"}},
	{"istisch", {respell = "ístisch", pos = "a"}},
	-- Almost all words in -tät are in -ität but a few aren't: [[Majestät]], [[Fakultät]], [[Pietät]], [[Pubertät]],
	-- [[Sozietät]], [[Varietät]].
	{"lich", {pos = "a"}},
	{"los", {respell = "lòs", pos = "a"}},
	-- Included because of words like [[Ergebnis]], [[Erlebnis]], [[Befugnis]], [[Begräbnis]], [[Betrübnis]],
	-- [[Gelöbnis]], [[Ödnis]], [[Verlöbnis]], [[Wagnis]], etc. A few words in -nis don't belong, e.g. [[Anis]],
	-- [[Denis]], [[Penis]], [[Tennis]], [[Spiritus lenis]], [[Tunis]], and may need respelling.
	{"nis", {pos = "n"}},
	{"reich", {respell = "rèich", pos = "a"}},
	{"sam", {respell = {"sahm", "sam"}, pos = "a"}},
	{"tät", {respell = "tä́t", pos = "n"}},
	{"tion", {respell = "zión", pos = "n"}},
	-- This must follow -tion. Most words in -ion besides those in -tion are still end-stressed abstract nouns, e.g.
	-- [[Religion]], [[Version]], [[Union]], [[Vision]], [[Explosion]], [[Aggression]], [[Rebellion]], or other words
	-- with the same stress pattern, e.g. [[Skorpion]], [[Million]], [[Fermion]]. There are several in -ion that are
	-- various types of ions, e.g. [[Cadiumion]], [[Hydridion]], [[Gegenion]], which need respelling with a hyphen, and
	-- some miscellaneous words that aren't end-stressed, e.g. [[Amnion]], [[Champion]], [[Camion]], [[Ganglion]],
	-- needing respelling of various sorts.
	{"ion", {respell = "ión", pos = "n", restriction = cons_c .. "$"}},
	-- "ung" not needed here; no respelling needed and vowel-initial
	{"voll", {respell = "fòll", pos = "a"}},
	{"weise", {respell = "wèise", pos = "a"}},
}

-- These rules operate in order, and apply to the actual spelling, after (1) decomposition, (2) prefix and suffix
-- splitting, (3) addition of default primary and secondary stresses (acute and grave, respectively) after the
-- appropriate syllable, (4) addition of ⁀ at boundaries of words, compound parts, prefixes and suffixes. The beginning
-- and end of text is marked by ⁀⁀. Each rule is of the form {FROM, TO, REPEAT} where FROM is a Lua pattern, TO is
-- its replacement, and REPEAT is true if the rule should be executed using `rsub_repeatedly()` (which will make the
-- change repeatedly until nothing happens). The output of this is fed into phonetic_rules, and is also used to
-- generate the displayed phonemic pronunciation by removing ⁀ symbols.
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
	{"(" .. V_non_glide .. ")(" .. stress_c .. "*" .. ")h", "%1ː%2"},
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

	-- 'i' and 'u' in hiatus should be nonsyllabic by default; add '.' afterwards to prevent this.
	{"(" .. C .. "[iu])(" .. V .. ")", "%1" .. INVBREVEBELOW .. "%2"},

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
	{"(" .. obstruent_non_sibilant_c .. ")%.([lr])", ".%1%2"},
	-- Cf. [[Liquid]] [liˈkviːt]; [[Liquida]] [ˈliːkvida]; [[Mikwe]] /miˈkveː/; [[Taekwondo]] [tɛˈkvɔndo] (dewikt);
	-- [[Uruguayerin]] [ˈuːʁuɡvaɪ̯əʁɪn] (dewikt)
	{"([kg])%.v", ".%1v"},
	-- [[Signal]] [zɪˈɡnaːl] (dewikt); [[designieren]] [dezɪˈɡniːʁən] (dewikt); if split 'g.n', we'd expect [k.n].
	-- But notice the short 'i'. Cf. [[Kognition]] [ˌkɔɡniˈt͡si̯oːn] (dewikt) and [[Kognat]] [kɔˈɡnaːt] (dewikt) vs.
	-- [[Prognose]] [ˌpʁoˈɡnoːzə] (dewikt) with short closed 'o' despite secondary stress. Cf. also [[orthognath]]
	-- [ɔʁtoˈɡnaːt] (dewikt), [[prognath]] [pʁoˈɡnaːt] (dewikt). Cf. [[Agnes]] [ˈaɡnɛs] (dewikt) but /ˈaː.ɡnəs/
	-- (enwikt). Cf. [[regnen]] /ˈʁeː.ɡnən/ "prescriptive standard" (enwikt), /ˈʁeːk.nən/ "most common" (enwikt).
	-- Similarly [[Gegner]], [[segnen]], [[Regnum]]. Also [[leugnen]], [[Leugner]] with the same /gn/ prescriptive,
	-- /kn/ more common; whereas [[Zeugnis]] always with /kn/ (suggests -nis is a suffix we need to handle).
	-- FIXME: Handle this all.
	{"g%.n", ".gn"},
	-- Divide two vowels; but not if the first vowel is indicated as non-syllabic ([[Familie]], [[Ichthyologie]], etc.).
	{"(" .. V .. accent_non_invbrevebelow_c .. "*)(" .. V .. ")", "%1.%2", true},
	-- User-specified syllable divider should now be treated like regular one.
	{SYLDIV, "."},

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

	-- Handle vowel quality/length changes in open vs. closed syllables, part a: Some vowels that would be
	-- expected to be long (particularly before a single consonant word-finally) are actually short.
	-- Unstressed final 'i' before a single consonant is short: especially in -in, -is, -ig, but also -ik as in
	-- [[Organik]], [[Linguistik]], etc.; -im as in [[Interim]], [[Isegrim]], [[Joachim]], [[Muslim]] (one
	-- pronunciation), [[privatim]], [[Achim]] (one pronunciation), etc. Those in -il are usually end-stressed
	-- with long 'i', e.g. [[Automobil]], [[fragil]], [[Fossil]], [[grazil]], [[hellenophil]], [[stabil]], [[imbezil]],
	-- [[mobil]], [[fertil]], etc. Those in -it are usually end-stressed and refer to minerals, where the 'i' can be
	-- long or short. Those in -id are usually end-stressed and refer to chemicals, with long 'i'; but cf. [[David]]
	-- /ˈdaːvɪt/; [[Ingrid]] [ˈɪŋɡʁɪt] or [ˈɪŋɡʁiːt] (dewikt).
	{"i(" .. C .. "⁀)", "i" .. BREVE .. "%1"},
	-- 'i' before 'g' is short including across syllable boundaries without a following stress ([[Entschuldigung]],
	-- [[verständigen]], [[Königin]], [[ängstigend]]; [[ewiglich]] with voiced [g]).
	{"i(%.?g[^⁀" .. stress .. "]*⁀)", "i" .. BREVE .. "%1", true},
	-- 'i' before 'gn' is short including across syllable boundaries, even with a following stress ([[Signal]],
	-- [[designieren]], [[indigniert]], [[Lignin]] with voiced [g]). Not commonly before gl + stress, e.g.
	-- [[Diglossie]], [[Triglyph]], [[Epiglottis]] or gr + stress, e.g. [[Digraph]], [[Emigrant]], [[Epigramm]],
	-- [[filigran]], [[Kalligraphie]], [[Migräne]], [[Milligramm]]. [[ewiglich]], [[königlich]] etc. with short 'i'
	-- handled by previous entry.
	{"i(%.?gn)", "i" .. BREVE .. "%1"},
	-- Unstressed final '-us', '-um' normally short, e.g. [[Kaktus]], [[Museum]].
	{"u([ms]⁀)", "u" .. BREVE .. "%1"},
	-- Unstressed final '-on' normally short, e.g. [[Aaron]], [[Abaton]], [[Natron]], [[Analogon]], [[Myon]], [[Anton]]
	-- (either long or short 'o'), [[Argon]], [[Axon]], [[Bariton]], [[Biathlon]], [[Bison]], etc. Same with unstressed
	-- '-os', e.g. [[Albatros]], [[Amos]], [[Amphiprostylos]], [[Barbados]], [[Chaos]], [[Epos]], [[Gyros]], [[Heros]],
	-- [[Kokos]], [[Kolchos]], [[Kosmos]], etc.
	{"o([ns]⁀)", "o" .. BREVE .. "%1"},
	--
	-- Handle vowel quality/length changes in open vs. closed syllables, part b: Lengthen/shorten as appropriate.
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

	-- 'ĭg' is pronounced [ɪç] word-finally or before an obstruent (not before an approximant as in [[ewiglich]] or
	-- [[Königreich]] when divided as ''ewig.lich'', ''König.reich'').
	{"ɪg⁀", "ɪç"},
	{"ɪg(%.?" .. C_not_approximant .. ")", "ɪç%1"},
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
		["ß"] = "s",
	}},
	{"əʁ", "ɐ"},

	-- Generate IPA stress marks.
	{AC, "ˈ"},
	{GR, "ˌ"},
	-- Move IPA stress marks to the beginning of the syllable.
	{"([.⁀])([^.⁀ˈˌ]*)([ˈˌ])", "%1%3%2"},
	-- Suppress syllable mark before IPA stress indicator.
	{"%.([ˈˌ])", "%1"},

	-- Convert explicit character notation to regular character.
	{".", explicit_char_to_phonemic},
}

-- These rules operate in order, on the output of phonemic_rules. Each rule is of the form {FROM, TO, REPEAT} where
-- FROM is a Lua pattern, TO is its replacement, and REPEAT is true if the rule should be executed using
-- `rsub_repeatedly()` (which will make the change repeatedly until nothing happens). The output of this is used to
-- generate the displayed phonetic pronunciation by removing ⁀ symbols.
local phonetic_rules = {
	-- -ken, -gen at end of word have syllabic ŋ
	{"([kɡ]ə)n⁀", "%1" .. "ŋ⁀"}, -- IPA ɡ
	-- schwa + resonant becomes syllabic (written over ŋ, otherwise under)
	{"ə([lmn])", "%1" .. SYLLABIC},
	{"əŋ", "ŋ̍"},
	-- coda r /ʁ/ becomes a semivowel
	{"(" .. V .. "ː?)ʁ", "%1ɐ̯"},
	-- unvoiced stops and affricates become affricated word-finally and before vowel, /ʁ/ or /l/ (including syllabic
	-- /l/), but not before syllabic nasal; cf. [[zurücktreten]], with aspirated 'z', 'ck' and first 't' but not second;
	-- also not before homorganic stop across prefix/compound boundary like [[Abbildung]] [ˈʔap̚.b̥ɪl.dʊŋ]
	{"p([.⁀]b)", "p" .. UNRELEASED .. "%1"},
	{"t([.⁀]d)", "t" .. UNRELEASED .. "%1"},
	{"k([.⁀]ɡ)", "k" .. UNRELEASED .. "%1"}, -- IPA ɡ
	{"([ptk])(%.?[⁀" .. vowel .. "ʁl])", "%1ʰ%2"},
	{"(t" .. TIE .. "[sʃ])(%.?[⁀" .. vowel .. "ʁl])", "%1ʰ%2"},
	-- voiced stops/fricatives become unvoiced after unvoiced sound; cf. [[Abbildung]] [ˈʔap̚.b̥ɪl.dʊŋ]
	{"(" .. unvoiced_cons_c .. "[.⁀]*[bdɡvzʒ])", "%1" .. UNVOICED}, -- IPA ɡ
	-- FIXME: Other possible phonemic/phonetic differences:
	-- (1) Omit syllable boundaries in phonemic notation?
	-- (2) Maybe not show some or all glottal stops in phonemic notation? Existing phonemic examples tend to omit it.
}

local function apply_rules(word, rules)
	for _, rule in ipairs(rules) do
		local from, to, rept = unpack(rule)
		if rept then
			word = rsub_repeatedly(word, from, to)
		else
			word = rsub(word, from, to)
		end
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
