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
-- -- (double hyphen) to indicate a word/word boundary in a compound word where one (or both) of the component words
--    itself is a compound. Here, the original secondary stresses turn into tertiary stresses (not shown) and the
--    primary stress the second component (and further components) becomes secondary. See discussion below.
-- < (less-than) to indicate a prefix/word or prefix/prefix boundary; similar to - for word/word boundary, but the
--   prefix before the < sign will be unstressed.
-- > (greater-than) to indicate a word/suffix or suffix/suffix boundary; similar to - for word/word boundary, but the
--   suffix after the > sign will be unstressed.
-- + (plus) is the opposite of -; it forces a prefix/word, word/word or word/suffix boundary to *NOT* occur when it
--   otherwise would. 
-- _ (underscore) to force the letters on either side to be interpreted independently, when the combination of the two
--   would normally have a special meaning.
--  ̣ (dot under) on any vowel in a word or component to prevent it from getting any stress.
--  ̯ (inverted breve under) to indicate a non-syllabic vowel. Most common uses: i̯ in words like [[Familie]]
--   respelled 'Famíli̯e'; o̯ in French-derived words like [[soigniert]] respelled 'so̯anjiert' (-iert automatically gets
--   primary stress); occasionally y̯ in words like [[Ichthyologie]] respelled 'Ichthy̯ologie' (-ie automatically gets
--   primary stress).  There is also u̯ but it's mostly unnecessary as a 'u' directly followed by another vowel by
--   default becomes non-syllabic. Finally, the generated phonemic notation includes /aɪ̯/ for spelled 'ei' and 'ai';
--   /ɔɪ̯/ for spelled 'eu' and 'äu'; and /aʊ̯/ for spelled 'au'; and the generated phonetic notation includes [ɐ̯] for
--   vocalized /ʁ/ (i.e. written 'r' in a syllable coda). However, you rarely if ever need to type these symbols
--   explicitly.

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
9. The double hyphen is used when joining compound words together. For example, [[Hubschrauber]] "helicopter" respelled
   'Hub-schrauber' is rendered as [ˈhuːpˌʃʁaʊ̯bɐ] while [[Landeplatz]] "landing place; airstrip; wharf, pier" respelled
   'Lande-platz' is rendered [ˈlandəˌplat͡s], and the combination [[Hubschrauberlandeplatz]] "heliport, helicopter port"
   respelled 'Hub-schrauber--lande-platz' is rendered [ˈhuːpʃʁaʊ̯bɐˌlandəplat͡s]. Here, the original secondary
   stresses turn into tertiary stresses (not shown) and the primary stress in [[Landeplatz]] becomes secondary.
   The loss of secondary stress has no other effect on the phonology. For example, consider [[Rundflug]]
   "sightseeing flight" (lit. "circular flight") respelled 'Rund-flug' and rendered [ˈʁʊntˌfluːk]. When combined
   with [[Hubschrauber]], the result [[Hubschrauberrundflug]] "helicopter sightseeing flight" respelled
   'Hub-schrauber--rund-flug' is rendered [ˈhuːpʃʁaʊ̯bɐˌʁʊntfluːk], where the last vowel is still long despite
   (apparently) losing the stress. Another example is [[Hubschrauberpilot]] "helicopter pilot", compounded of
   [[Hubschrauber]] and [[Pilot]] "pilot". The latter must be respelled 'Pilót' due to the unexpected stress.
   The combination [[Hubschrauberpilot]] should be respelled 'Hub-schrauber--pilòt', rendered as
   [ˈhupʃʁaʊ̯bɐpiˌloːt]. Here, the primary stress should be converted to secondary; otherwise the word would
   wrongly end up rendered as [ˌhupʃʁaʊ̯bɐpiˈloːt], where the module assumes that since the second word has the
   primary stress, other words (including the first one) should have secondary stress. Other similar examples:
   [[Hubschrauberabsturz]] "helicopter crash" 'Hub-schrauber--absturz' [ˈhuːpʃʁaʊ̯bɐˌʔapʃtʊʁt͡s] (the stressed
   prefix ab- is automatically recognized) and [[Maulwurfshügel]] "molehill" [ˈmaʊ̯lvʊʁfsˌhyːɡl̩]. Occasionally the
   double hyphen should be used even when no single hyphens occur. Another example of note is [[Aufenthaltsgenehmigung]]
   "residence permit". [[Aufenthalt]] by itself (without respelling) is rendered [ˈaʊ̯f(ʔ)ɛntˌhalt], i.e. it has
   secondary stress. The respelling 'Aufenthalts-genehmigung' is rendered [ˈaʊ̯fʔɛnthalt͡sɡəˌneːmɪɡʊŋ] without the
   original secondary stress; the module recognizes the need to remove the secondary stress here. Essentially, if two
   words are joined by an ordinary hyphen and one of them has secondary stress due to a stressed prefix, the hyphen
   is implicitly "upgraded" to a double hyphen.

   Things may get more complex when stresses "bump up" against each other. For example, [[Abhängigkeit]] "dependency"
   with no respelling is rendered [ˈapˌhɛŋɪçkaɪ̯t]. In combination as e.g. [[Drogenabhängigkeit]] "drug dependency,
   drug addiction" respelled 'Drogen-abhängigkeit', the result is [ˈdʁoːɡn̩ˌʔaphɛŋɪçkaɪ̯t], which appears correct.
   In combination as e.g. [[Alkoholabhängigkeit]] respelled 'Alkohól-abhängigkeit', the result is
   [alkoˈhoːlˌʔaphɛŋɪçkaɪ̯t], which may sound wrong to native ears because of the two stresses bumping up against each
   other. The actual pronunciation may be more like [alkoˈhoːlʔapˌhɛŋɪçkaɪ̯t] with the secondary stress moving
   (respell 'Alkohól-abhä̀ngigkeit') or [alkoˈhoːlʔaphɛŋɪçkaɪ̯t] with the secondary stress disappearing (respell
   'Alkohól-ȧbhängigkeit' where the dot-above suppresses the stress marker but otherwise doesn't change the
   phonology).


FIXME:

1. Implement < and > which works like - but don't trigger secondary stress (< after a prefix, > before a suffix).
2. Implement <!, -! which work with < and - but suppress the vowel-initial glottal stop; <?, -? which work similarly
   but allow for optional glottal stop.
3. Implement prefix/suffix stripping; don't do it if explicit syllable boundary in cluster after prefix, or if no
   vowel in main, or if impossible prefix/suffix onset/offset.
4. Automatically support -ge-, -zu- after stressed verbal prefixes.
5. Figure out how to support stacked suffixes like -barkeit, -samkeit, -lichkeit, -schaftlich, -licherweise. Perhaps
   there is a small enough set of common stacked suffixes to just list them all.
6. Finish entering prefixes and suffixes.
7. Add default stresses (primary stress on first syllable of first stressed component, etc.).
8. Handle inflectional suffixes: adjectival -e, -en, -em, -er, -es, also after adjectival -er, -st; nominal -(e)s,
   -(e)n; verbal -e, -(e)st, -(e)t, -(e)n, -(e)te, -(e)tst, -(e)tet, -(e)ten.
9. Ignore final period/question mark/exclamation point.
10. Implement nasal vowels.
11. Implement underscore to prevent assimilation/interpretation as a multigraph.
12. Implement [b] [d] [g] [z] [v] [s] [x].
13. Implement dot-under to prevent stress.
14. Check allowed onsets with prefixes.
15. Implement allowed offsets and check with suffixes.
16. Implement 'style' ala Spanish pronun to handle standard vs. northern/Eastern vs. southern:
    e.g. [[berufsunfähig]]:
	/bəˈʁuːfsʔʊnˌfɛːɪç/ {{qualifier|standard; used naturally in western Germany and Switzerland}}
	/-ʔʊnˌfeːɪç/ {{qualifier|overall more common; particularly northern and eastern regions}}
	/-ʔʊnˌfɛːɪk/ {{qualifier|common form in southern Germany, Austria, and Switzerland}}
	e.g. [[aufrichtig]]:
	/ˈaʊf.ʁɪç.tɪç/ {{qualifier|standard}}
	/ˈaʊf.ʁɪç.tɪk/ {{qualifier|common form in southern Germany, Austria, and Switzerland}}
	e.g. [[Universität]]:
	/ˌuni.vɛʁ.ziˈtɛːt/ {{qualifier|standard; used naturally in western Germany and Switzerland}}
	/ˌuni.vɛʁ.ziˈteːt/ {{qualifier|overall more common; particularly northern and eastern regions}}
17. Implement splitting prefix/suffix pronun for -sam, with two pronunciations.
18. n before g/k in the same syllable should be ŋ. Sometimes also across syllables, cf. [[Ingrid]].
19. Written 'ts' in the same syllable should be rendered with a tie, e.g. [[aufwärts]], [[Aufenhaltsgenehmigung]].
    [[Botsuana]] is tricky as it normally would have syllable division 't.s', but maybe we should special-case it
	so we get /bɔˈtsu̯aːna/. Other examples: [[enträtseln]], [[Fietse]], [[Lotse]], [[Mitsubishi]], [[Rätsel]],
	[[Hatsa]], [[Tsatsiki]], [[Whatsapp]]. In [[Outsider]] and [[Outsourcing]], the 't' and 's' are pronounced
	separately, respelled 'Aut-[s]aider' and 'Aut-[s]ŏhßing' (or similar).
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

local ACUTE = u(0x0301) -- COMBINING ACUTE ACCENT =  ́
local GRAVE = u(0x0300) -- COMBINING GRAVE ACCENT =  ̀
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

-- When auto-generating primary and secondary stress accents, we use these special characters, and later convert to
-- normal IPA accent marks, so we can distinguish auto-generated stress from user-specified stress.
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

local stress = ACUTE .. GRAVE
local stress_c = "[" .. stress .. "]"
local accent_non_stress_non_invbrevebelow = BREVE .. CFLEX .. MACRON .. TILDE .. "ː"
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
local schwalike = "əɐ"
local vowel = back_vowel .. front_vowel .. schwalike
local V = "[" .. vowel .. "]"
local non_V = "[^" .. vowel .. "]"
local vowel_non_glide = back_vowel_non_glide .. front_vowel_non_glide .. schwalike
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
local C_not_h = "[" .. cons_guts .. "h]" -- consonant not 'h'
local C_not_s = "[" .. cons_guts .. "s]" -- consonant not 's'
-- Include both regular g and IPA ɡ so it can be used anywhere
local obstruent_non_sibilant = "pbfvkgɡtdxç" .. EXPLICIT_B .. EXPLICIT_D .. EXPLICIT_G .. EXPLICIT_V .. EXPLICIT_X
local obstruent_non_sibilant_c = "[" .. obstruent_non_sibilant .. "]"
local unvoiced_cons = "ptkfsßʃxç" .. EXPLICIT_S .. EXPLICIT_X
local unvoiced_C = "[" .. unvoiced_cons .. "]"

local allowed_onsets = {
	"[bcdfghjklmnpqrstvwxz]",
	-- Many single consonants can be followed by j but they are all foreign terms that can't be prefixed.
	"ch[lr]?",
	"sch[lmnr]?",
	"[td]sch",
	"[kg]n",
	"[kgbpfc]l",
	"[kgbpdtfc]r",
	"[kgbpdt]h",
	"ph[lr]",
	"thr",
	"s[ckpt]r?",
	"s[pk]l",
	"s[pt]h",
	"sz",
	"vl",
	"w[lr]",
}

-- Pretty much all allowed offsets can additionally end in -s, except after ß, s, x, z.
local allowed_offsets = {
	"[bcdfghjklmnpqrstvwxz]",
	"([bfglmnprstz])%1",
	"r[bcdfgklmnptvwxz]",
	"l[bdfgkmnptz]",
	"n[cdfgktxz]",
	"m[bdlpt]", -- ml only occurs in [[Kreml]]
	"s[hklpt]", -- sp does not occur but may occur in compounds; sl is rare
	"t[hlz]", -- tl is rare
	"[kb]t",
	"g[tdhln]", -- gl, gn is rare
	"f[tzn]", -- fn is rare
	"ch[tz]", -- chz is rare
	-- FIXME
}

-- The format of the following is {PREFIX, RESPELLING, PROPS...} where PROPS are optional named properties, such as
-- 'restriction' (place additional restrictions on when the prefix can occur), 'prefixtype' (override the
-- autodetected type of prefix).
--
-- In general, there are three types of prefixes: stressed and unstressed, and un-. Stressed prefixes can be followed
-- by unstressed prefixes (e.g. [[Aufenthalt]]), and sometimes unstressed prefixes can be followed by stressed
-- prefixes (e.g. [[beabsichtigen]], [[veranlagen]]) or by un- (e.g. [[verunglücken]], [[Verunreinigung]],
-- [[verunstalten]], [[beunruhigen]]), but otherwise prefixes cannot be combined, except for un-, which can be followed
-- by either stressed or unstressed prefixes (but not another un-); cf. [[unausgegoren]], with three prefixes (un- +
-- stressed + unstressed) or [[unzerstörbar]], with two prefixes (un- + unstressed).
--
-- Some prefixes can be both stressed and unstressed, e.g. durch-, unter-, über-, wieder-. For some, e.g. miss- and
-- wider-, there are systematic alternations in stress: unstressed when functioning as a verbal prefix followed by an
-- initial-stressed verb, stressed otherwise. This is too complex and unpredictable for us to handle, so we treat all
-- these prefixes as stressed. Respell using < when unstressed, e.g. 'umfahren' "to knock down with a vehicle",
-- 'um<fahren' "to drive around, to bypass".
local prefixes = {
	{"ab", "ább"},
	{"an", "ánn"},
	{"auf", "áuf"},
	{"aus", "áus"},
	{"auseinander", "àus-einánder"},
	{"bei", "béi"},
	-- Allow be- before -u- only in beur-, beun-; cf. [[beurlauben]], [[Beunruhigung]].
	{"be", "bə", restriction = {"^[^u]", "^u[rn]"}},
	{"daher", "dahér"},
	{"dahin", "dahín"},
	{"durch", "dúrch"},
	{"ein", "éin"},
	{"emp", "emp", restriction = "^f"},
	{"ent", "ent"},
	{"er", "err"},
	{"fort", "fórt"},
	-- Most words in 'gei-' aren't past participles, cf. [[Geier]], [[Geifer]], [[geifern]], [[Geige]], [[geigen]],
	-- [[Geiger]], [[geil]], [[geilo]], [[Geisel]], [[Geiser]], [[Geisha]], [[Geiß]], [[Geißel]], [[geißeln]],
	-- [[Geist]], [[Geister]], [[geistig]], [[Geiz]], [[geizen]]. There are only a few, e.g. [[geimpft]], which need
	-- respelling, e.g. 'ge<impft'. No restriction on 'geu-' because only one non-past-participle observed:
	-- [[Geusenwort]] (which needs respelling like 'Géusen-wort'), and there are various past participles in 'geu-',
	-- especially 'geur-'.
	{"ge", "gə", restriction = "^[^i]"},
	{"herab", "herrább"},
	{"heran", "herránn"},
	{"herauf", "herráuf"},
	{"heraus", "herráus"},
	{"herbei", "herbéi"},
	{"herein", "herréin"},
	{"herüber", "herrǘber"},
	{"herum", "herrúmm"},
	{"herunter", "herrúnter"},
	{"hervor", "herfór"},
	{"her", "hérr"},
	{"hinab", "hinnább"},
	{"hinan", "hinnánn"},
	{"hinauf", "hinnáuf"},
	{"hinaus", "hinnáus"},
	-- hinbei doesn't appear to exist
	{"hinein", "hinnéin"},
	{"hinter", "hínter"},
	{"hinüber", "hinnǘber"},
	-- hinum doesn't appear to exist
	{"hinunter", "hinnúnter"},
	-- hinvor doesn't appear to exist
	{"hin", "hínn"},
	-- too many false positives for in-
	{"miss", "míss"},
	{"nieder", "níeder"},
	{"mit", "mítt"},
	{"über", "ǘber"},
	{"um", "úmm"},
	{"un", "únn", prefixtype = "un"},
	{"unter", "únter"},
	{"ver", "ferr"},
	{"voran", "foránn"},
	{"voraus", "foráus"},
	{"vorbei", "fohrbéi"}, -- respell per dewikt pronun
	{"vorher", "fohrhér"}, -- respell per dewikt pronun
	{"vorüber", "forǘber"},
	{"vor", "fór"},
	{"weg", "wéck"},
	{"weiter", "wéiter"},
	{"wider", "wíder"},
	{"wieder", "wíeder"},
	{"zer", "zerr"},
	-- Listed twice, first as stressed then as unstressed, because of zu-infinitives like [[anzufangen]]. At the
	-- beginning of a word, stressed zú- will take precedence, but after another prefix, stressed prefixes can't occur,
	-- and unstressed -zu- will occur.
	{"zu", "zú"},
	{"zu", "zu"},
	{"zurecht", "zurécht"},
	{"zurück", "zurǘck"},
}

-- Suffix stress:
-- -- Suffixes like [[-lein]] seem to take secondary stress only when the preceding syllable has no stress and there
--    is no preceding secondary stress, e.g. [[Fingerlein]], [[Schwesterlein]] or [[Müllerlein]] /ˈmʏlɐˌlaɪ̯n/. In most
--    words, this condition doesn't hold, and so -lein has no stress, e.g. [[Äuglein]] [ˈɔɪ̯klaɪ̯n] or [[Bäumlein]]
--    [ˈbɔɪ̯mlaɪ̯n]. This includes secondary stress of the type found in [[Ecklädlein]] /ˈɛkˌlɛːtlaɪn/; [[Hofkirchlein]]
--    /ˈhoːfˌkɪʁçlaɪ̯n/; [[Apfelbäumlein]] /ˈap͡fl̩ˌbɔɪ̯mlaɪ̯n/. This is contrary to the behavior of compounds-of-compounds
--    like [[Hubschrauberlandeplatz]] and [[Maulwurfshügel]] described above; by that rule, we'd expect
--    #/ˈap͡fl̩bɔɪ̯mˌlaɪ̯n/ or similar. Cf. similar behavior with -keit: [[Abhängigkeit]] [ˈapˌhɛŋɪçkaɪ̯t].
--
-- Suffix combinations:
-- -barkeit
-- -lichkeit
-- -samkeit
-- -loskeit (only [[Freudloskeit]], [[Zusammenhangloskeit]]?)
-- -barlich (only [[sichtbarlich]], [[wunderbarlich]]?)
-- -barschaft (only [[Nachtbarschaft]]?)
-- -nisreich (only [[ereignisreich]], [[erlebnisreich]], [[kenntnisreich]]?)
local suffixes = {
	{"ant", "ánt", pos = {"n", "a"}},
	{"anz", "ánz", pos = "n"},
	{"abel", "ábel", pos = "a"},
	{"ibel", "íbel", pos = "a"},
	-- I considered an exception for -mal but there are many counter-exceptions like [[normal]], [[minimal]],
	-- [[dermal]], [[dezimal]], [[prodromal]].
	{"al", "ál", pos = "a"},
	-- Normally following consonant but there a few exceptions like [[abbaubar]], [[recyclebar]], [[unüberschaubar]].
	-- Cases like [[isobar]] will be respelled with an accent and not affected.
	{"bar", "bàr", pos = "a"},
	-- Restrict to not follow a vowel or s (except for -ss) to avoid issues with nominalized infinitives in -chen.
	-- Words with -chen after a vowel or s need to be respelled with '>chen', as in [[Frauchen]], [[Wodkachen]],
	-- [[Häuschen]], [[Bläschen]], [[Füchschen]], [[Gänschen]], etc. Occasional gerunds of verbs in -rchen may need
	-- to be respelled with '+chen' to avoid the preceding vowel being long, as in [[Schnarchen]].
	{"chen", "çen", pos = "n", restriction = {C_not_s .. "$", "ss$"}},
	{"erei", "əréi", pos = "n", restriction = C .. "$"},
	{"ei", "éi", pos = "n", restriction = C .. "$"},
	{"ent", "ént", pos = {"n", "a"}},
	{"enz", "énz", pos = "n"},
	{"erweise", "ərwèise", restriction = C .. "$", pos = "b"},
	-- Normally following consonant but there a few exceptions like [[säurefest]]. Cases like [[manifest]] will be
	-- respelled with an accent and not affected.
	{"fest", "fèst", pos = "a"},
	{"barschaft", "bahrschàft", pos = "n"},
	{"schaft", "schàft", pos = "n"},
	{"haft", "hàft", pos = "a"},
	{"heit", "hèit", pos = "n"},
	-- NOTE: This will get converted to secondary stress if there is a primary stress elsewhere in the word (e.g. in
	-- compound words).
	{"ie", "íe", restriction = C .. "$", pos = "n"},
	-- No restriction to not occur after a/e; [[kreieren]] does occur and noun form and verbs in -en after -aier/-eier
	-- should not occur (instead you get -aiern/-eiern). Occurs with both nouns and verbs.
	{"ieren", "íeren", pos = "v"},
	-- See above. Occurs with adjectives and participles, and also [[Gefiert]].
	{"iert", "íert", pos = "a"},
	-- See above. Occurs with nouns.
	{"ierung", "íerung", pos = "n"},
	-- "isch" not needed here; no respelling needed and vowel-initial
	-- NOTE: This will get converted to secondary stress if there is a primary stress elsewhere in the word (e.g. in
	-- compound words like [[Abwehrmechanismus]] or [[Lügenjournalismus]]).
	{"ismus", "ísmus", pos = "n"},
	-- Restrict to not occur after -a or -e as it may form a diphthong ([[allermeist]], [[verwaist]], etc.). Words
	-- with suffix -ist after -a or -e need respelling, e.g. [[Judaist]], [[Atheist]], [[Deist]], [[Monotheist]].
	{"ist", "íst", respelling = "[^ae]$", pos = "n"},
	{"istisch", "ístisch", respelling = "[^ae]$", pos = "a"},
	{"barkeit", "bahrkèit", pos = "n"},
	{"lichkeit", "lichkèit", pos = "n"},
	{"loskeit", "lohskèit", pos = "n"},
	{"samkeit", {"sahmkèit", "samkèit"}, pos = "n"},
	{"keit", "kèit", pos = "n"},
	-- See comment above about secondary stress.
	{"lein", "lèin", pos = "n"},
	{"barlich", "bahrlìch", pos = "a"},
	{"lich", "lich", pos = "a"},
	-- Restrict to not be after -l (cf. [[Drilling]], [[Helling]], [[Marshalling]], [[Schilling]], [[Spilling]],
	-- [[Zwilling]]). Instances after vowels do occur ([[Dreiling]], [[Edeling]], [[Neuling]], [[Reling]]); words
	-- [[Feeling]], [[Homeschooling]] need respelling in any case.
	{"ling", "ling", restriction = "[^l]$", pos = "n"},
	{"los", "lòs", pos = "a"},
	-- Included because of words like [[Ergebnis]], [[Erlebnis]], [[Befugnis]], [[Begräbnis]], [[Betrübnis]],
	-- [[Gelöbnis]], [[Ödnis]], [[Verlöbnis]], [[Wagnis]], etc. Only recognized when following a consonant to exclude
	-- [[Anis]], [[Denis]], [[Penis]], [[Spiritus lenis]], [[Tunis]] (although these would be excluded in any case
	-- for the pre-suffix part being too short). [[Tennis]] needs respelling 'Ten+nis'.
	{"nis", "nis", restriction = C .. "$", pos = "n"},
	{"ös", "ö́s", pos = "a"},
	{"nisreich", "nisrèich", restriction = C .. "$", pos = "a"},
	{"reich", "rèich", pos = "a"},
	-- Two possible pronunciations (long and short). Occurs after a vowel in [[grausam]] (also false positives
	-- [[Bisam]], [[Sesam]], which will be excluded as the pre-suffix part is too short).
	{"sam", {"sahm", "sam"}, pos = "a"},
	-- schaft is further up, above [[haft]]
	-- Almost all words in -tät are in -ität but a few aren't: [[Majestät]], [[Fakultät]], [[Pietät]], [[Pubertät]],
	-- [[Sozietät]], [[Varietät]].
	{"tät", "tä́t", pos = "n"},
	{"tion", "zión", pos = "n"},
	-- This must follow -tion. Most words in -ion besides those in -tion are still end-stressed abstract nouns, e.g.
	-- [[Religion]], [[Version]], [[Union]], [[Vision]], [[Explosion]], [[Aggression]], [[Rebellion]], or other words
	-- with the same stress pattern, e.g. [[Skorpion]], [[Million]], [[Fermion]]. There are several in -ion that are
	-- various types of ions, e.g. [[Cadiumion]], [[Hydridion]], [[Gegenion]], which need respelling with a hyphen, and
	-- some miscellaneous words that aren't end-stressed, e.g. [[Amnion]], [[Champion]], [[Camion]], [[Ganglion]],
	-- needing respelling of various sorts.
	{"ion", "ión", restriction = C .. "$", pos = "n"},
	-- "ung" not needed here; no respelling needed and vowel-initial
	{"voll", "fòll", pos = "a"},
	{"weise", "wèise", pos = "a"},
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
	{MACRON, "ː"}, -- The user can use respelling with macrons but internally we convert to the long mark ː
	{"x", "ks"},
	-- WE treat written 'ts' same as 'tz', e.g. [[aufwärts]], [[Aufenhaltsgenehmigung]], [[Rätsel]] and
	-- foreign-derived words such as [[Botsuana]], [[Fietse]], [[Lotse]], [[Mitsubishi]], [[Hatsa]], [[Tsatsiki]],
	-- [[Whatsapp]]. To prevent this, insert a syllable boundary (.), a component boundary (-), a prefix or suffix
	-- boundary (< or >), etc.
	{"t[sz]", "ʦʦ"},
	{"z", "ʦ"},
	{"qu", "kv"},
	{"q", "k"},
	{"w", "v"},
	-- [[Pinguin]], [[Linguistik]], [[konsanguin]], [[Lingua franca]], [[bilingual]]
	{"ngu(" .. V .. ")", "ŋgu%1"},
	-- Most words with -ngr- without a clear component boundary pronounce the g. Examples: [[Engramm]] (arguably has a
	-- component boundary, pronounced with /n/?); [[Gangrän]] (/ŋ/); [[Ingredienz]] (arguably has a component boundary,
	-- pronounced with /n/); [[Ingrid]] (/ŋ/); [[Ingrimm]] (with component boundary but still /ŋ/); [[inkongruent]],
	-- [[kongruent]], [[Kongruenz]] (arguably has a component boundary, optionally with /ŋ/ or /n/); [[Kaliningrad]],
	-- [[Leningrad]], [[Stalingrad]] (ditto); [[Kongress]] (ditto); [[Mangrove]] (with /ŋ/); [[Sangria]] (with /ŋ/);
	-- only [[hungrig]] has /ŋr/ without /g/. Choosing this default simplifies handling the cases with /ngr/ (which
	-- should add a syllable boundary 'n.gr') and /ŋr/ (which should add a syllable boundary 'ng.r').
	--
	-- With -ngl- we have [[Angler]] /ŋl/; [[Anglikaner]], [[anglikanisch]], [[Anglistik]], [[Anglizismus]], [[Anglo-]],
	-- etc. with /ŋgl/; [[Bangladesch]] and related with /ŋl/; [[England]], [[Engländer], [[English]], [[Denglish]],
	-- [[einenglischen]] and related with /ŋl/; [[Ganglion]] with /ŋl/ or /ŋgl/; [[Jingle]] respelled 'Dschingel';
	-- [[Jonglage]], [[Jongleur]], [[jonglieren]] with /ɔ̃gl/, /ɔŋgl/ or /ɔŋl/; [[Konglomerat]] with /ŋgl/ or /ngl/;
	-- [[Ringlotte]] ?; [[Single]] respelled '[S]ingel'; [[Spengler]] with /ŋl/; [[Umzinglung]] with /ŋl/
	{"ngr", "ŋgr"},
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
	-- /gs/ in enwikt have a component boundary in the middle.
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

	-- Eliminate remaining geminate consonants within a compound part (geminates can legitimately exist across a
	-- component boundary). Normally such geminates will always occur across a syllable boundary, but this may not be
	-- the case in the presence of user-specified syllable boundaries.
	{"(" .. C .. ")(%.?)%1", "%1", true},

	-- FIXME: Should we do this across syllable boundaries? There are words where ŋ spelled 'n' occurs before 'k' or 'g'
	-- across a syllable boundary, e.g. [[Inka]], [[Ingo]], [[Ingolf]], [[Ingrid]], [[Kongo]], optionally [[kongruent]].
	-- But the words with 'ng' usually require respelling in any case as otherwise e.g. [[Kongo]] would be rendered
	-- /kɔŋo/. This way, words beginning with 'ink-' where 'in-' is a Latinate prefix don't require respelling with
	-- 'in<...', e.g. [[Inkarnation]], [[Inklusion]], [[inkohärent]], [[inkompatibel]], [[inkompetent]],
	-- [[inkremental]], etc. [[ingeniös]] and [[Ingredienz]] need a syllable divider 'in.geniös', 'In.gredienz';
	-- [[Ingrid]], [[Kongo]] need respelling 'Inggrid', 'Konggo'.
	{"n([gk])", "ŋ%1"},
	-- As an exception, 'n' -> /ŋ/ before k/g + unstressed ending to handle numerous cases like [[bedanken]], [[Denke]],
	-- [[Flanke]], [[Funke]], [[Gedanke]], [[Kranker]], [[Beschränkung]], [[Erkrankung]], [[Verrenkung]], [[gelenkig]],
	-- [[stinkig]], etc.
	{"n(%.kə)", "ŋ%1"},
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
	{ACUTE, "ˈ"},
	{GRAVE, "ˌ"},
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
	-- also not before homorganic stop across component boundary like [[Abbildung]] [ˈʔap̚.b̥ɪl.dʊŋ]
	{"p([.⁀]b)", "p" .. UNRELEASED .. "%1"},
	{"t([.⁀]d)", "t" .. UNRELEASED .. "%1"},
	{"k([.⁀]ɡ)", "k" .. UNRELEASED .. "%1"}, -- IPA ɡ
	{"([ptk])(%.?[⁀" .. vowel .. "ʁl])", "%1ʰ%2"},
	{"(t" .. TIE .. "[sʃ])(%.?[⁀" .. vowel .. "ʁl])", "%1ʰ%2"},
	-- voiced stops/fricatives become unvoiced after unvoiced sound; cf. [[Abbildung]] [ˈʔap̚.b̥ɪl.dʊŋ]
	{"(" .. unvoiced_C .. "[.⁀]*[bdɡvzʒ])", "%1" .. UNVOICED}, -- IPA ɡ
	-- FIXME: Other possible phonemic/phonetic differences:
	-- (1) Omit syllable boundaries in phonemic notation?
	-- (2) Maybe not show some or all glottal stops in phonemic notation? Existing phonemic examples tend to omit it.
	-- (3) Maybe show -ieren as if written -iern; but this may be colloquial.
}


local function reorder_accents(text)
	-- FIXME: What about order of DOTUNDER to indicate no stress? Maybe doesn't matter too much because it is
	-- removed early when generating the default stress, but maybe it should go first of all so it's easy to spot.
	-- The order should be: (1) DOTUNDER (removed early) (2) BREVE/CFLEX, (3) TILDE, (4) MACRON/ː, (5) ACUTE/GRAVE.
	-- First: Remove duplicate accents. FIXME: Possibly do this if separated by other accents.
	text = rsub_repeatedly(text, "(" .. accent_c .. ")%1", "%1")
	-- Second, DOTUNDER first among all.
	text = rsub(text, "([" .. ACUTE .. GRAVE .. BREVE .. CFLEX .. TILDE .. MACRON .. "ː]+)([" .. DOTUNDER .. "])", "%2%1")
	-- Third, ACUTE/GRAVE last among all remaining.
	text = rsub(text, "([" .. ACUTE .. GRAVE .. "])([" .. BREVE .. CFLEX .. TILDE .. MACRON .. "ː]+)", "%2%1")
	-- Fourth, put BREVE/CFLEX first among TILDE and MACRON/ː.
	text = rsub(text, "([" .. TILDE .. MACRON .. "ː]+)([" .. BREVE .. CFLEX .. "])", "%2%1")
	-- Fifth, put TILDE before MACRON/ː.
	text = rsub(text, "([" .. MACRON .. "ː]+)([" .. TILDE ..  "])", "%2%1")
	return text
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
end

-- Canonicalize multiple spaces, remove leading and trailing spaces, remove exclamation points, question marks and
-- periods at end of sentence. Convert capital N after a vowel into a tilde to mark nasalization, and macron to long
-- mark (ː).
local function canonicalize(text)
	text = decompose(text)
	text = rsub(text, "%s+", " ")
	text = rsub(text, "^ ", "")
	text = rsub(text, " $", "")
	-- Capital N after a vowel (including after vowel + accent marks) denotes nasalization.
	text = rsub(text, "(" .. V .. accent_c .. "*)N", "%1" .. TILDE)
	-- The user can use respelling with macrons but internally we convert to the long mark ː
	text = rsub(MACRON, "ː")
	-- Reorder so ACUTE and GRAVE go last.
	text = reorder_accents(text)

	-- convert commas and en/en dashes to IPA foot boundaries
	text = rsub_repeatedly(text, "%s*[–—]%s*", " | ")
	-- comma must be followed by a space; otherwise it might denote multiple respellings
	text = rsub_repeatedly(text, "%s*,%s", " | ")
	-- period, question mark, exclamation point in the middle of a sentence or end of a non-final sentence -> IPA foot
	-- boundary; there must be a space after the punctuation, as we use ! and ? in component-separation indicators to
	-- control the production of glottal stops at the beginning of the next word.
	text = rsub_repeatedly(text, "([^%s])%s*[!?.]%s([^%s])", "%1 | %2")
	text = rsub(text, "[!?.]$", "") -- eliminate absolute phrase-final punctuation

	return text
end


-- This should run on the output of canonicalize(). It splits the text into words, lowercases each word, but identifies
-- whether the word was initially capitalized.
local function split_words(text)
	local result = {}
	for word in rgsplit(text, " ") do
		-- Lowercase the word and check if it was capitalized; be careful with cases like '[X]uzpe', which we treat as
		-- capitalized and lowercase to '[x]uzpe'.
		local init_bracket, rest = rmatch(word, "^(%[)(.*)$")
		if not init_bracket then
			init_bracket = ""
			rest = text
		end
		local lcrest = mw.getContentLanguage():lcfirst(rest)
		local is_cap = lcrest ~= rest
		table.insert(result, {word = ulower(word), is_cap = is_cap})
	end
	return result
end


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


local function check_onset_offset(cluster, patterns)
	for _, pattern in ipairs(patterns) do
		if rfind(cluster, "^" .. pattern .. "$") then
			return true
		end
	end
	return false
end


-- Check text against a pattern restriction. If it matches, return true; otherwise, return false. If the restriction
-- is a list of patterns, return true if any of them matches.
local function meets_restriction(rest, restriction)
	if restriction == nil then
		-- no restriction.
		return true
	end
	if type(restriction) == "table" then
		-- If any of the restrictions pass, the affix is restricted.
		for _, restrict in ipairs(restriction) do
			if rfind(rest, restrict) then
				return true
			end
		end
	else
		if rfind(rest, restrict) then
			return true
		end
	end
	return false
end


local function lookup_stress_spec(stress_spec, pos)
	return stress_spec[pos] or (pos == "verbal" and stress_spec["verb"]) or nil
end


local function split_word_on_components_and_apply_affixes(word, pos)
	local retparts = {}
	local parts = strutils.capturing_split(word, "([<>%-])")
	local i = 1
	local saw_primary_stress = false
	while i <= #parts do
		local insert_position = #retparts + 1
		if parts[i + 1] ~= "<" and parts[i - 1] ~= ">" then
			-- Split off any prefixes.
			while true do
				local broke_prefix = false
				local saw_un = false
				local saw_unstressed = false
				local saw_stressed = false
				for _, prefixspec in ipairs(prefixes) do
					local prefix_pattern = prefixspec[1]
					local prefixtype = prefixspec.prefixtype or rfind(prefix_respell, stress_c) and "stressed" or
						"unstressed"
					local pos_stress = lookup_stress_spec(stress_spec, pos)
					local prefix, rest = rmatch(parts[i], "^(" .. prefix_pattern .. ")(.*)$")
					if prefix then
						if not pos_stress then
							-- prefix not recognized for this POS, don't split here
						elseif not meets_restriction(rest, prefixspec.restriction) then
							-- restriction not met, don't split here
						elseif rfind(rest, "^%+") then
							-- explicit non-boundary here, so don't split here
						elseif not rfind(rest, V) then
							-- no vowels, don't split here
						elseif rfind(rest, "^..?$") then
							-- only two letters, unlikely to be a word, probably an ending, so don't split
							-- here
						else
							-- Use non_V so that we pick up things like explicit syllable divisions, which will
							-- prevent the allowed-onset check from succeeding.
							local initial_cluster, after_cluster = rmatch(rest, "^(" .. non_V .. "*)(.-)$")
							if not check_onset_offset(initial_cluster, allowed_onsets) then
								-- initial cluster isn't a possible onset, don't split here
							elseif rfind(after_cluster, "^" .. V .. "?$") then
								-- remainder is a cluster + single vowel, unlikely to be a word so don't split here
								-- most such words have impermissible onsets, but cf. [[Beta]], [[Bete]], [[Bede]],
								-- [[Bethe]], [[Geste]], [[verso]], [[Verve]], [[vorne]], [[Erbe]], [[Erde]], [[ergo]],
								-- [[Erle]], [[erste]],  etc.
							elseif not rfind(prefix, stress_c) and rfind(after_cluster, "^e" .. C_not_h .. "$") then
								-- remainder is a cluster + e + single consonant after an unstressed prefix, unlikely
								-- to be a word so don't split here; most such words have impermissible onsets, but cf.
								-- [[Bebel]], [[beben]], [[Besen]], [[beten]], [[geben]], [[Geber]], [[gegen]],
								-- [[gehen]], [[geten]], [[Becher]], [[Gegner]], [[Verschen]], [[erben]], [[erden]],
								-- [[Erker]], [[erlen]], [[Erpel]], [[erzen]], [[Erster]], etc.; a few legitimate
								-- prefixed words get rejected, e.g. [[Beleg]], [[Gebet]], which need respelling
							elseif prefixtype == "un" and (saw_un or saw_unstressed or saw_stressed) then
								-- un- cannot occur after any other prefixes
							elseif prefixtype == "unstressed" and saw_unstressed then
								-- unstressed prefixes like ge- cannot occur after other unstressed prefixes
							elseif prefixtype == "stressed" and saw_stressed then
								-- stressed prefixes like an- cannot occur after other stressed prefixes, except
								-- in certain combinations like voran- that we treat as single prefixes
							else
								-- break the word in two; next iteration we process the rest, which may need breaking
								-- again
								parts[i] = rest
								if prefixtype == "un" then
									saw_un = true
								elseif prefixtype == "unstressed" then
									saw_unstressed = true
								else
									saw_stressed = true
								end
								local prefix_respell = decompose(prefixspec[2])
								prefix_respell = gsub(prefix_respell, ACUTE, AUTOACUTE)
								prefix_respell = gsub(prefix_respell, GRAVE, AUTOGRAVE)
								if rfind(prefix_respell, AUTOACUTE) then
									if saw_primary_stress then
										prefix_respell = rsub(prefix_respell, AUTOACUTE, AUTOGRAVE)
									end
									saw_primary_stress = true
								end
								table.insert(retparts, insert_position, prefix_respell)
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
				for _, suffixspec in ipairs(suffixes) do
					local suffix_pattern = suffixspec[1]
					local pos_stress = lookup_stress_spec(stress_spec, pos)
					local rest, suffix = rmatch(parts[i], "^(.-)(" .. suffix_pattern .. ")$")
					if suffix then
						if not pos_stress then
							-- suffix not recognized for this POS, don't split here
						elseif not meets_restriction(rest, suffixspec.restriction) then
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
		if acc == CFLEX then
			-- remove circumflex but don't accent
			parts[i] = gsub(parts[i], CFLEX, "")
		elseif acc == ACUTE or acc == AUTOACUTE then
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
		if syl:find(ACUTE) or syl:find(AUTOACUTE) and not no_auto_stress then
			syl = "ˈ" .. syl
		elseif syl:find(GRAVE) or syl:find(AUTOGRAVE) and not no_auto_stress then
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
	word = decompose(word)
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
	text = canon_spaces(text)
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
		[1] = { required = true, default = "Aufenthalts-genehmigung", list = true },
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
			arg = rsub(decompose(arg), "[%-+._<>" .. ACUTE .. GRAVE .. CFLEX .. "]", "")
			arg = rsub(arg, "%[(.)%]", char_to_spelling)
			m_table.insertIfNot(anntext, "'''" .. arg .. "'''")
		end
		anntext = table.concat(anntext, ", ") .. ":&#32;"
	if args.ann then
		anntext = "'''" .. args.ann .. "''':&#32;"
	else
		anntext = ""
	end

	return anntext .. m_IPA.format_IPA_full(lang, IPA_args)
end

return export
