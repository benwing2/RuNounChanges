--[=[

Implementation of pronunciation-generation module from spelling for German.

Author: Benwing

The following symbols can be used:
-- Acute accent on a vowel to override the position of primary stress; in a diphthong, put it over the first vowel:
--   á é í ó ú ä́ ö́ ǘ ái éi áu ä́u éu
-- Grave accent to add secondary stress: à è ì ò ù ä̀ ö̀ ǜ ài èi àu ä̀u èu
-- Double grave accent to add tertiary stress: ȁ ȅ ȉ ȍ ȕ ä̏ ö̏ ü̏ ȁi ȅi ȁu ä̏u ȅu. Tertiary stress has the same effect on
--   vowels as secondary stress (e.g. they lengthen in open syllables) but is rendered without a stress mark. Under
--   normal circumstances, you do not have to explicitly add tertiary stress. Rather, secondary stresses (including
--   those generated automatically) are automatically converted to tertiary stress in certain circumstances, e.g.
--   when compounding two words that are already compounds. See the discussion on -- (double hyphen) below.
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
2. With occasional exceptions, a vowel before a single consonant (including at the end of a word or component)
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
   [[Hubschrauberabsturz]] "helicopter crash" 'Hub-schrauber--absturz' /ˈhuːpʃʁaʊ̯bɐˌʔapʃtʊʁt͡s/ (the stressed
   prefix ab- is automatically recognized) and [[Maulwurfshügel]] "molehill" /ˈmaʊ̯lvʊʁfsˌhyːɡəl/. Occasionally the
   double hyphen should be used even when no single hyphens occur. Another example of note is [[Aufenthaltsgenehmigung]]
   "residence permit". [[Aufenthalt]] by itself (without respelling) is rendered /ˈaʊ̯f(ʔ)ɛntˌhalt/, i.e. it has
   secondary stress. The respelling 'Aufenthalts-genehmigung' is rendered /ˈaʊ̯f(ʔ)ɛnthalt͡sɡəˌneːmɪɡʊŋ/ without the
   original secondary stress; the module recognizes the need to remove the secondary stress here. Essentially, if two
   words are joined by an ordinary hyphen and one of them has secondary stress due to a stressed prefix, the hyphen
   is implicitly "upgraded" to a double hyphen.

   Things may get more complex when stresses "bump up" against each other. For example, [[Abhängigkeit]] "dependency"
   with no respelling is rendered [ˈapˌhɛŋɪçkaɪ̯t]. In combination as e.g. [[Drogenabhängigkeit]] "drug dependency,
   drug addiction" respelled 'Drogen-abhängigkeit', the result is /ˈdʁoːɡənˌʔaphɛŋɪçkaɪ̯t/, which appears correct.
   In combination as e.g. [[Alkoholabhängigkeit]] respelled 'Alkohól-abhängigkeit', the result is
   /alkoˈhoːlˌʔaphɛŋɪçkaɪ̯t/, which may sound wrong to native ears because of the two stresses bumping up against each
   other. The actual pronunciation may be more like /alkoˈhoːl(ʔ)apˌhɛŋɪçkaɪ̯t/ with the secondary stress moving
   (respell 'Alkohól-abhä̀ngigkeit') or /alkoˈhoːlʔaphɛŋɪçkaɪ̯t/ with the secondary stress disappearing (respell
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
14. Implement dot-over on a vowel to prevent a given autogenerated stress mark from being displayed.
15. Check allowed onsets with prefixes.
16. Implement allowed offsets and check with suffixes.
17. Implement 'style' ala Spanish pronun to handle standard vs. northern/Eastern vs. southern:
    e.g. [[berufsunfähig]]:
	/bəˈʁuːfs(ʔ)ʊnˌfɛːɪç/ {{qualifier|standard; used naturally in western Germany and Switzerland}}
	/-ʔʊnˌfeːɪç/ {{qualifier|overall more common; particularly northern and eastern regions}}
	/-ʔʊnˌfɛːɪk/ {{qualifier|common form in southern Germany, Austria, and Switzerland}}
	e.g. [[aufrichtig]]:
	/ˈaʊf.ʁɪç.tɪç/ {{qualifier|standard}}
	/ˈaʊf.ʁɪç.tɪk/ {{qualifier|common form in southern Germany, Austria, and Switzerland}}
	e.g. [[Universität]]:
	/ˌuni.vɛʁ.ziˈtɛːt/ {{qualifier|standard; used naturally in western Germany and Switzerland}}
	/ˌuni.vɛʁ.ziˈteːt/ {{qualifier|overall more common; particularly northern and eastern regions}}
18. Implement splitting prefix/suffix pronun for -sam, with two pronunciations.
19. n before g/k in the same syllable should be ŋ. Sometimes also across syllables, cf. [[Ingrid]].
20. Written 'ts' in the same syllable should be rendered with a tie, e.g. [[aufwärts]], [[Aufenhaltsgenehmigung]].
    [[Botsuana]] is tricky as it normally would have syllable division 't.s', but maybe we should special-case it
	so we get /bɔˈtsu̯aːna/. Other examples: [[enträtseln]], [[Fietse]], [[Lotse]], [[Mitsubishi]], [[Rätsel]],
	[[Hatsa]], [[Tsatsiki]], [[Whatsapp]]. In [[Outsider]] and [[Outsourcing]], the 't' and 's' are pronounced
	separately, respelled 'Aut-[s]aider' and 'Aut-[s]ŏhßing' (or similar).
21. Implement handling of written 'y'.
22. Implement double hyphen and conversion of secondary to tertiary accents.
23. Handle unstressed words like [[und]] and [[von]] correctly.
24. Implement optional glottal stops when the following syllable isn't stressed (but only after a consonant; cf.
    [[wiederentdecken]] ˈviːdɐʔɛntˌdɛkən).
25. Use x* etc. to get EXPLICIT_X etc. instead of [x], so that [...] can be used after a word to indicate word
    properties.
26. Handle prefixes/suffixes/interfixes indicated with initial and/or final hyphen.
27. t-s- should render as t͡s e.g. [[Gleichheitszeichen]] respelled 'Gleichheit-s-zeichen' and [[Aufenthaltstitel]]
    respelled 'Aufenthalt-s-titel'.
28. Need syllable dividers at component boundaries before unstressed syllables.
29. Open syllables with secondary stress get close but not lengthened vowel if there is a following primary stress
    within the component bounadry; cf. [[iterativ]] 'ìtêratív' [ˌiteʁaˈtiːf], [[Lethargie]] 'Lèthargie' [ˌletaʁˈɡiː].
	Across a component bounadry this doesn't apply, so that e.g. [[hyperaktiv]] 'hỳper-áktihv' would be
	[ˌhyːpɐˈʔaktiːf]; if we need short /y/, either make it unstressed, e.g. 'hyper<aktihv' or use *, e.g.
	'hỳ*per-áktiv'.
30. Use [vf] after a word for "verb form" to get verbal endings -st, -t, -tet etc. recognized. Expand this to handle
    all inflectional endings.
31. Support non-initial capital O for o̯, non-initial N for nasal vowel including after lengthening h, digraphs eI and
    oU for /ɛɪ̯/ and /ɔʊ̯/.
32. Nasal vowels should be long when stressed, and use the phonemes ã ɛ̃ õ œ̃ per Wikipedia.
33. Remove primary stress from a single-syllable word.
34. -ik- in the middle of a word should have short 'i', e.g. [[Musikerin]]; not sure if also applies when stress
    follows. Cf. [[Abdikation]] /ˌapdikaˈt͡si̯oːn/, [[Partikel]] /paʁˈtɪkl̩/ or also /paʁˈtiːkl̩/, [[Affrikate]]
	/ˌafʁiˈkaːtə/, [[Afrika]] /ˈaːfʁika/ or /ˈafʁika/, [[afrikaans]] /ˌafʁiˈkaːns/, [[Agnostiker]] /aˈɡnɔstɪkɐ/,
	[[Agrikultur]] /ˌaɡʁikʊlˈtuːɐ̯/, [[Akademikerin]] /akaˈdeːmɪkəʁɪn/, [[Silikat]] /ziliˈkaːt/, [[Amerika]]
	/aˈmeːʁika/, [[amikal]] /amiˈkaːl/, [[Anabolikum]] /anaˈboːlikʊm/, [[Syndikalismus]] /zʏndikaˈlɪsmʊs/,
	[[Angelika]] /aŋˈɡeːlika/, [[Anglikaner]] /aŋɡliˈkaːnɐ/, [[Antibiotikum]] /antiˈbi̯oːtikʊm/, [[Antipyretikum]]
	/antipyˈʁeːtikʊm/, [[apikal]] /apiˈkaːl/, [[appendikuliert]] /apɛndikuˈliːɐ̯t/, [[Applikation]] /aplikaˈt͡si̯oːn/,
	[[Aprikose]] /ˌapʁiˈkoːzə/, [[Olympionikin]] /olʏmpi̯oˈniːkɪn/, [[Tsatsiki]] /t͡saˈt͡siːki/, [[Artikel]]
	/ˌaʁˈtiːkl̩/ or /ˌaʁˈtɪkl̩/, [[Batiken]] /ˈbaːtɪkn̩/. Seems to apply only to unstressed '-ik-' followed by 'e' +
	no stress.
35. 'h' between vowels should be lengthening only if no stress follows and the following vowel isn't a or o. Cf.
    [[Reha]] /ˈʁeːha/, [[Dschihadist]] /d͡ʒihaːˈdɪst/, [[Johann]] /ˈjoːhan/, [[Lahar]] /ˈlaːhaʁ/, [[Mahagoni]]
	/ˌmahaˈɡoːni/, [[Maharadscha]] /ˌmahaˈʁaːdʒa/ (prescriptive) or /ˌmahaˈʁadʒa/ (more common) or /ˌmahaˈʁatʃa/
	(usual), [[Mohammed]] /ˈmoː.(h)a.mɛt/, [[Rehabilitation]] /ˌʁehabilitaˈt͡si̯oːn/, [[stenohalin]] /ʃtenohaˈliːn/,
	[[Tomahawk]] /ˈtɔ.ma.haːk/ or /ˈtɔ.ma.hoːk/, [[Bethlehem]] /ˈbeːt.ləˌhɛm/ or /ˈbeːt.ləˌheːm/ (sometimes without
	secondary stress), [[Bohemien]] /bo.(h)eˈmjɛ̃/, [[Bohemistik]] /boheˈmɪstɪk/, [[Ahorn]] /ˈʔaːhɔʁn/, [[Alkoholismus]]
	/ˌalkohoˈlɪsmʊs/, [[Jehova]] /jeˈhoːva/, [[Kohorte]] /koˈhɔʁtə/, [[Nihonium]] /niˈhoːni̯ʊm/, [[Bahuvrihi]]
	/bahuˈvʁiːhi/, [[Marihuana]] 'Marihu.ána' /maʁihuˈaːna/ (one pronunciation per dewikt), [[abstrahieren]]
	/apstʁaˈhiːʁən/, [[ahistorisch]] /ˈahɪsˌtoːʁɪʃ/, [[Annihilation]] /anihilaˈt͡si̯oːn/, [[Antihistaminikum]]
	/antihɪstaˈmiːnikʊm/ [[Mohammedaner]] /mohameˈdaːnɐ/, [[nihilistisch]] /nihiˈlɪstɪʃ/, [[Prohibition]]
	/pʁohibiˈt͡si̯oːn/, [[Vehikel]] /veˈhiːkl̩/ vs. [[Abziehung]] /ˈaptsiːʊŋ/, [[Aufblähung]] /ˈaʊ̯fˌblɛːʊŋ/,
	[[Auferstehung]] /ˈaʊ̯f(ʔ)ɛʁˈʃteːʊŋ/, [[Bedrohung]] /bəˈdʁoːʊŋ/, [[arbeitsfähig]] /ˈaʁbaɪ̯t͡sˌfɛːɪç/, [[befähigt]]
	/bəˈfɛːɪçt/, [[Beruhigen]] /bəˈʁuːɪɡn̩/, [[Ehe]], /ˈeːə/, [[viehisch]] /ˈfiːɪʃ/.
	Exception: [[huhu]] 'hu.hu' /ˈhuːhu/, [[Tohuwabohu]] 'Tòh.huwabó.hu' /ˌtoːhuvaˈboːhu/, [[Uhu]] 'U.hu' /ˈuːhu/,
	[[Uhudler]] 'U.huhdler' /ˈuːhuːdlɐ/, [[Estomihi]] 'Estomí.hi' /ɛstoˈmiːhi/.
36. Re-parse prefix/suffix respellings for <, e.g. auseinander-.
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
local DOUBLEGRAVE = u(0x030F) -- COMBINING DOUBLE GRAVE ACCENT =  ̏
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
local function rsub_repeatedly(term, foo, bar, n)
	while true do
		local new_term = rsub(term, foo, bar, n)
		if new_term == term then
			return term
		end
		term = new_term
	end
end

-- INTERNALLY-USED SYMBOLS
--
-- We use the following internally:
-- ⁀ represents a component boundary. Two components within an orthographic word are separated by ⁀; the edge of an
--   orthographic word is denoted by ⁀⁀. The division between prefix and component, or between prefix and prefix, is
--   also denoted by ⁀.
-- ‿ represents the division between component and suffix, or suffix and suffix. We need to distinguish this from ⁀
--   for certain purposes, e.g. 'st' at the beginning of a component is /ʃt/ but 'st' at the beginning of a suffix is
--   /st/.
-- AUTOACUTE, AUTOGRAVE, ORIG_SUFFIX_GRAVE: Described below.
-- EXPLICIT_*: Described below.

-- When auto-generating primary and secondary stress accents, we use these special characters, and later convert to
-- normal IPA accent marks, so we can distinguish auto-generated stress from user-specified stress.
local AUTOACUTE = u(0xFFF0)
local AUTOGRAVE = u(0xFFF1)
-- An auto-generated secondary stress in a suffix is converted to the following if the word is not composed of
-- multiple (hyphen or double-hyphen separated) components. It is eventually converted to secondary stress (if there is
-- no preceding secondary stress, and the directly preceding syllable does not have primary stress), and otherwise
-- removed.
local ORIG_SUFFIX_GRAVE = u(0xFFF2)

-- Used to temporarily substitute capital I and U when lowercasing
local TEMP_I = u(0xFFF0)
local TEMP_U = u(0xFFF1)

-- When the user uses the "explicit allophone" notation such as [z] or [x] to force a particular allophone, we
-- internally convert that notation into a single special character.
local EXPLICIT_S = u(0xFFF3)
local EXPLICIT_Z = u(0xFFF4)
local EXPLICIT_V = u(0xFFF5)
local EXPLICIT_B = u(0xFFF6)
local EXPLICIT_D = u(0xFFF7)
local EXPLICIT_G = u(0xFFF8)
local EXPLICIT_X = u(0xFFF9)

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

local stress = ACUTE .. GRAVE .. DOUBLEGRAVE
local stress_c = "[" .. stress .. "]"
local accent_non_stress_non_invbrevebelow = BREVE .. CFLEX .. TILDE .. DOTUNDER .. MACRON .. "ː*"
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
local charsep = accent .. "." .. SYLDIV .. "‿"
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
	{"auseinander", "aus<einánder"},
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
	-- We use a separate type for unstressed -zu- because it can be followed by another unstressed prefix, e.g.
	-- [[auszubedingen]], whereas normally two unstressed prefixes cannot occur.
	{"zu", "zu", prefixtype = "unstressed-zu"},
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
	{"licherweise", "lichərwèise", pos = "b"},
	{"erweise", "ərwèise", restriction = C .. "$", pos = "b"},
	-- Normally following consonant but there a few exceptions like [[säurefest]]. Cases like [[manifest]] will be
	-- respelled with an accent and not affected.
	{"fest", "fèst", pos = "a"},
	{"barschaft", "bàhrschàft", pos = "n"},
	{"schaft", "schàft", pos = "n"},
	{"haft", "hàft", pos = "a"},
	{"heit", "hèit", pos = "n"},
	{"ie", "íe", restriction = C .. "$", pos = "n"},
	-- No restriction to not occur after a/e; [[kreieren]] does occur and noun form and verbs in -en after -aier/-eier
	-- should not occur (instead you get -aiern/-eiern). Occurs with both nouns and verbs.
	{"ieren", "íeren", pos = "v"},
	-- See above. Occurs with adjectives and participles, and also [[Gefiert]].
	{"iert", "íert", pos = "a"},
	-- See above. Occurs with nouns.
	{"ierung", "íerung", pos = "n"},
	-- "isch" not needed here; no respelling needed and vowel-initial
	{"ismus", "ísmus", pos = "n"},
	-- Restrict to not occur after -a or -e as it may form a diphthong ([[allermeist]], [[verwaist]], etc.). Words
	-- with suffix -ist after -a or -e need respelling, e.g. [[Judaist]], [[Atheist]], [[Deist]], [[Monotheist]].
	{"ist", "íst", respelling = "[^ae]$", pos = "n"},
	{"istisch", "ístisch", respelling = "[^ae]$", pos = "a"},
	{"barkeit", "bàhrkèit", pos = "n"},
	{"schaftlichkeit", "schàft.lichkèit", pos = "n"},
	{"lichkeit", "lichkèit", pos = "n"},
	{"losigkeit", "lòsigkèit", pos = "n"},
	{"samkeit", {"sahmkèit", "samkèit"}, pos = "n"},
	{"keit", "kèit", pos = "n"},
	-- See comment above about secondary stress.
	{"lein", "lèin", pos = "n"},
	{"barlich", "bàhrlich", pos = "a"},
	{"schaftlich", "schàft.lich", pos = "a"},
	{"lich", "lich", pos = "a"},
	-- Restrict to not be after -l (cf. [[Drilling]], [[Helling]], [[Marshalling]], [[Schilling]], [[Spilling]],
	-- [[Zwilling]]). Instances after vowels do occur ([[Dreiling]], [[Edeling]], [[Neuling]], [[Reling]]); words
	-- [[Feeling]], [[Homeschooling]] need respelling in any case.
	{"ling", "ling", restriction = "[^l]$", pos = "n"},
	{"los", "lòs", pos = "a"},
	-- Included because of words like [[Ergebnis]], [[Erlebnis]], [[Befugnis]], [[Begräbnis]], [[Betrübnis]],
	-- [[Gelöbnis]], [[Ödnis]], [[Verlöbnis]], [[Wagnis]], etc. Also [[Zeugnis]] with /k/ (syllable division 'g.n')
	-- instead of expected syllable division '.gn'. Only recognized when following a consonant to exclude [[Anis]],
	-- [[Denis]], [[Penis]], [[Spiritus lenis]], [[Tunis]] (although these would be excluded in any case for the
	-- pre-suffix part being too short). [[Tennis]] needs respelling 'Ten+nis'.
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
	{"nisvoll", "nisfòll", restriction = C .. "$", pos = "a"},
	{"voll", "fòll", pos = "a"},
	{"weise", "wèise", pos = "a"},
}

local function reorder_accents(text)
	-- The order should be: (1) DOTUNDER (removed early) (2) *, (3) TILDE, (4) BREVE/CFLEX, (5) MACRON/ː,
	-- (6) ACUTE/GRAVE/DOUBLEGRAVE.
	local function reorder_accent_string(accentstr)
		local accents = rsplit(accentstr, "")
		local accent_order = {
			[DOTUNDER] = 1,
			["*"] = 2,
			[TILDE] = 3,
			[BREVE] = 4,
			[CFLEX] = 4,
			[MACRON] = 5,
			["ː"] = 5,
			[ACUTE] = 6,
			[GRAVE] = 6,
			[DOUBLEGRAVE] = 6,
		}
		table.sort(accents, function(ac1, ac2)
			return accent_order[ac1] < accent_order[ac2]
		end)
		return table.concat(accents)
	end
	text = rsub(text, "(" .. accent_c .. "+)", reorder_accent_string)
	-- Remove duplicate accents.
	text = rsub_repeatedly(text, "(" .. accent_c .. ")%1", "%1")
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
	-- Capital N after a vowel (including after vowel + accent marks + possibly an h) denotes nasalization.
	text = rsub(text, "(" .. V .. accent_c .. "*)(h?)N", "%1" .. TILDE .. "%2")
	-- The user can use respelling with macrons but internally we convert to the long mark ː
	text = rsub(MACRON, "ː")
	-- Reorder so ACUTE/GRAVE/DOUBLEGRAVE go last.
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
		-- Lowercase the word and check if it was capitalized.
		local lcword = mw.getContentLanguage():lcfirst(word)
		local is_cap = lcword ~= word
		word = rsub(word, "O", "o̯")
		word = rsub(word, "I", TEMP_I)
		word = rsub(word, "U", TEMP_U)
		word = ulower(word)
		word = rsub(word, TEMP_I, "I")
		word = rsub(word, TEMP_U, "U")
		table.insert(result, {word = ulower(word), is_cap = is_cap})
	end
	return result
end


local function apply_rules(word, rules)
	for _, rule in ipairs(rules) do
		if type(rule) == "function" then
			word = rule(word)
		else
			local from, to, rept = unpack(rule)
			if rept then
				word = rsub_repeatedly(word, from, to)
			else
				word = rsub(word, from, to)
			end
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


local function split_word_on_components_and_apply_affixes(word, pos, affix_type, depth, is_compound)
	-- Make sure there aren't two primary stresses in the word.
	if rfind(word, ACUTE .. ".*" .. ACUTE) then
		error("Saw two primary stresses in word: " .. word)
	end

	depth = depth or 0
	if depth == 0 or depth == 1 then
		local parts = rsplit(word, depth == 0 and "%-%-" or "%-")
		if len(parts) == 1 then
			return split_word_on_components_and_apply_affixes(word, pos, affix_type, depth + 1)
		else
			for i, part in ipairs(parts) do
				parts[i] = split_word_on_components_and_apply_affixes(part, pos, affix_type, depth + 1, "is compound")
				parts[i] = rsub(parts[i], "[" .. AUTOGRAVE .. ORIG_SUFFIX_GRAVE .. "]", DOUBLEGRAVE)
				if i > 1 then
					parts[i] = rsub(parts[i], AUTOACUTE, AUTOGRAVE)
				end
			end
			return table.concat(parts, "⁀")
		end
	end

	local retparts = {}
	local parts = strutils.capturing_split(word, "([<>])")
	local saw_un_prefix = false
	local saw_unstressed_prefix = false
	local saw_unstressed_zu_prefix = false
	local saw_stressed_prefix = false
	local saw_primary_prefix_stress = false
	local saw_primary_suffix_stress = false

	local function has_user_specified_primary_stress(part)
		-- If there are multiple components (separated by - or --), we want to treat explicit user-specified
		-- secondary stress like primary stress because we only show the component primary stresses. The overall
		-- word primary stress shows as ˈ and other component primary stresses show as ˌ.
		return rfind(part, ACUTE) or is_compound and rfind(part, GRAVE)
	end

	-- Break off any explicitly-specified prefixes.
	local from_left = 1
	while from_left < #parts and parts[from_left + 1] == "<" do
		if has_user_specified_primary_stress(parts[from_left]) then
			saw_primary_prefix_stress = true
		end
		if rsub(parts[from_left], stress_c, "") == "un" then
			saw_un_prefix = true
		elseif rfind(parts[from_left], stress_c) then
			saw_stressed_prefix = true
		elseif parts[from_left] == "zu" then
			saw_unstressed_zu_prefix = true
		else
			saw_unstressed_prefix = true
		end
		table.insert(retparts, parts[from_left])
		from_left = from_left + 2
	end

	-- Break off any explicitly-specified suffixes.
	local insert_position = #retparts + 1
	local from_right = #parts
	while from_right > 1 and parts[from_right - 1] == ">" do
		if has_user_specified_primary_stress(parts[from_right]) then
			saw_primary_suffix_stress = true
		end
		table.insert(retparts, insert_position, parts[from_right])
		from_right = from_right - 2
	end
	if from_left ~= from_right then
		error("Saw < to the right of > in word: " .. word)
	end

	local mainpart = parts[from_left]
	local saw_primary_mainpart_stress = has_user_specified_primary_stress(mainpart)

	-- Split off any remaining prefixes.
	while true do
		local broke_prefix = false
		for _, prefixspec in ipairs(prefixes) do
			local prefix_pattern = prefixspec[1]
			local prefixtype = prefixspec.prefixtype or rfind(prefix_respell, stress_c) and "stressed" or
				"unstressed"
			local pos_stress = lookup_stress_spec(stress_spec, pos)
			local prefix, rest = rmatch(mainpart, "^(" .. prefix_pattern .. ")(.*)$")
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
					elseif prefixtype == "un" and (saw_un_prefix or saw_unstressed_prefix or saw_unstressed_zu_prefix
						or saw_stressed_prefix) then
						-- un- cannot occur after any other prefixes
					elseif prefixtype == "unstressed" and saw_unstressed_prefix then
						-- unstressed prefixes like ge- cannot occur after other unstressed prefixes
					elseif prefixtype == "unstressed-zu" and (saw_unstressed_prefix or saw_unstressed_zu_prefix) then
						-- unstressed -zu- cannot occur after unstressed prefixes
					elseif prefixtype == "stressed" and (saw_stressed_prefix or saw_unstressed_zu_prefix) then
						-- stressed prefixes like an- cannot occur after other stressed prefixes, except
						-- in certain combinations like voran- that we treat as single prefixes, and cannot occur
						-- after unstressed -zu-
					else
						-- break the word in two; next iteration we process the rest, which may need breaking
						-- again
						mainpart = rest
						if prefixtype == "un" then
							saw_un_prefix = true
						elseif prefixtype == "unstressed" then
							saw_unstressed_prefix = true
						elseif prefixtype == "unstressed-zu" then
							saw_unstressed_zu_prefix = true
						else
							saw_stressed_prefix = true
						end
						local prefix_respell = decompose(prefixspec[2])
						prefix_respell = gsub(prefix_respell, ACUTE, AUTOACUTE)
						prefix_respell = gsub(prefix_respell, GRAVE, AUTOGRAVE)
						if rfind(prefix_respell, AUTOACUTE) then
							if saw_primary_prefix_stress then
								prefix_respell = gsub(prefix_respell, AUTOACUTE, DOUBLEGRAVE)
							elseif saw_primary_mainpart_stress or saw_primary_suffix_stress then
								prefix_respell = gsub(prefix_respell, AUTOACUTE, AUTOGRAVE)
							end
							saw_primary_prefix_stress = true
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
		-- If there was a user-specified suffix with explicit stress, don't try to look for more suffixes.
		if saw_primary_suffix_stress then
			break
		end
		local broke_suffix = false
		for _, suffixspec in ipairs(suffixes) do
			local suffix_pattern = suffixspec[1]
			local pos_stress = lookup_stress_spec(stress_spec, pos)
			local rest, suffix = rmatch(mainpart, "^(.-)(" .. suffix_pattern .. ")$")
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
					local suffix_respell = decompose(suffixspec[2])
					if saw_primary_mainpart_stress and rfind(suffix_respell, ACUTE) then
						-- primary-stressed suffix like -iert but main part already has primary stress; don't split here
					else
						-- Use non_V so that we pick up things like explicit syllable divisions, which we
						-- check for below.
						local before_cluster, final_cluster = rmatch(rest, "^(.-)(" .. non_V .. "*)$")
						if rfind(final_cluster, "%..") then
							-- syllable division within or before final cluster, don't split here
						else
							-- break the word in two; next iteration we process the rest, which may need breaking
							-- again
							mainpart = rest

							-- We may remove the suffix grave entirely later on. For now, convert it to a special
							-- symbol so we can handle it properly later, after splitting on syllables.
							suffix_respell = gsub(suffix_respell, GRAVE, ORIG_SUFFIX_GRAVE)
							if rfind(suffix_respell, ACUTE) then
								saw_primary_suffix_stress = true
								if saw_primary_prefix_stress then
									-- We have already rejected cases with primary mainpart or suffix stress and
									-- acute accent in the respelling.
									suffix_respell = gsub(suffix_respell, ACUTE, AUTOGRAVE)
								else
									suffix_respell = gsub(suffix_respell, ACUTE, AUTOACUTE)
								end
							end
							table.insert(retparts, insert_position, suffix_respell)
							broke_suffix = true
							break
						end
					end
				end
			end
		end
		-- FIXME: Once we implement support for inflectional suffixes, we won't necessarily break here.
		break
	end

	if rfind(mainpart, DOTUNDER) then
		-- remove DOTUNDER but don't accent
		mainpart = gsub(mainpart, DOTUNDER, "")
	elseif saw_primary_mainpart_stress or saw_primary_suffix_stress then
		-- do nothing
	elseif rfind(mainpart, "^" .. non_V .. "*" .. V .. accent_c .. "*" .. stress_c) then
		-- first vowel already followed by a stress accent; do nothing
	else
		-- Add primary or secondary stress on the part; primary stress if no primary stress yet, otherwise secondary
		-- stress.
		local accent_to_add = saw_primary_prefix_stress and AUTOGRAVE or AUTOACUTE
		mainpart = rsub(mainpart, "^(" .. non_V .. "*" .. V .. accent_c .. "*)", "%1" .. accent_to_add)
	end
	table.insert(retparts, insert_position, mainpart)
	insert_position = insert_position + 1

	-- remove any +, which has served its purpose
	for i, part in ipairs(retparts) do
		retparts[i] = gsub(part, "%+", "")
	end

	-- Put components together. Vowel-initial suffixes join directly to preceding part; otherwise, put ⁀ before a
	-- prefix or main part, ‿ before a suffix.
	local wordparts = {}
	for i, part in ipairs(retparts) do
		if i >= insert_position then
			-- handling a suffix
			if rfind(part, "^" .. V) then
				wordparts[#wordparts] = wordparts[#wordparts] .. part
			else
				table.insert(wordparts, "‿" .. part)
			end
		else
			-- handling a prefix or main part
			table.insert(wordparts, (i > 1 and "⁀" or "") .. part)
		end
	end
	return table.concat(wordparts)
end

-- Secondary stress in a suffix disappears if there is a preceding secondary stress or if the immediately preceding
-- syllable has primary stress. If there are multiple such secondary stresses, I *think* we need to process them
-- left to right because of the way words are built up. E.g. FOObarkeit is really (FOO + -bar) + -keit, so if FOO is
-- one syllable, we get Fúbarkèit (-bar loses secondary stress because of the immediately preceding primary stress,
-- then -keit keeps it) but if FOO is two syllables, we get Fúdebàrkeit (-bar keeps stress so -keit loses it
-- because there is a preceding secondary stress).
local function handle_suffix_secondary_stress(word)
	if not rfind(word, ORIG_SUFFIX_GRAVE) then
		return word
	end
	local parts = strutils.capturing_split(word, "([.⁀‿]+)")
	local saw_secondary_stress = false
	local saw_primary_stress_preceding = false

	-- There should never be ORIG_SUFFIX_GRAVE in a compound word (i.e. multicomponent word where the components were
	-- originally separated by hyphen or double hyphen in respelling), so we should treat user-specified GRAVE as
	-- secondary stress rather than as primary stress in a non-primary component.
	local primary_stress = ACUTE .. AUTOACUTE
	local secondary_stress = AUTOGRAVE .. DOUBLEGRAVE .. ORIG_SUFFIX_GRAVE .. GRAVE
	for i, part in ipairs(parts) do
		if i % 2 == 1 then
			if saw_secondary_stress or saw_primary_stress_preceding then
				parts[i] = rsub(part, ORIG_SUFFIX_GRAVE, "")
			end
			saw_secondary_stress = saw_secondary_stress or rfind(part, secondary_stress)
			saw_primary_stress_preceding = rfind(part, primary_stress)
		end
	end

	return table.concat(parts)
end


-- These rules operate in order, and apply to the actual spelling, after (1) decomposition, (2) prefix and suffix
-- splitting, (3) addition of default primary and secondary stresses (acute and grave, respectively) after the
-- appropriate syllable, (4) addition of ⁀ or ‿ at boundaries of words, components, prefixes and suffixes. The
-- beginning and end of text is marked by ⁀⁀. Each rule is of the form {FROM, TO, REPEAT} where FROM is a Lua pattern,
-- TO is its replacement, and REPEAT is true if the rule should be executed using `rsub_repeatedly()` (which will make
-- the change repeatedly until nothing happens). The output of this is fed into phonetic_rules, and is also used to
-- generate the displayed phonemic pronunciation by removing ⁀ and ‿ symbols.
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
	-- In -ngr-, -ngl-, -ngV- with a following stress in the same component, the 'g' is usually pronounced and the 'n'
	-- is usually /ŋ/. Cf. [[Gangrän]], [[kongruent]], [[Kongruenz]], [[Kaliningrad]]/[[Leningrad]]/[[Stalingrad]],
	-- [[Kongress]], [[Mangrove]], [[Sangria]], [[Anglikaner]], [[anglikanisch]], [[Anglistik]], [[Anglizismus]],
	-- [[Bangladesch]], [[Jonglage]]/[[Jongleur]]/[[jonglieren]], [[Konglomerat]], [[Angela]], [[Angeliter]],
	-- [[Angola]], [[Angolaner]], [[evangelisch]], [[Evangelium]], [[fingieren]], [[fungieren]], [[fungibilität]],
	-- [[Gingivitis]], [[Klingonisch]], [[Kongolese]], [[Kontingenz]], [[Langobarde]], [[Languste]], [[Mangan]],
	-- [[Mongolisch]], [[rektangulär]], [[restringieren]], [[singapurisch]], [[singulär]], [[Singultus]],
	-- [[stringent]], [[tangibel]], [[tangieren]], [[triangulieren]], [[Vercingetorix]], etc. Cases without stress and
	-- with the 'g' unpronounced are [[hungrig]], [[Angler]], [[Spengler]], [[Umzinglung]], [[England]], [[Engländer]],
	-- [[Englisch]], [[Denglisch]], [[einenglischen]], etc. Some of the above optionally have /n/ instead of /ŋ/; these
	-- need respelling with 'n.gr' or 'n.gl'.
	--
	-- 'ng' followed by 'a' or 'o' also usually has pronounced 'g' and /ŋ/, e.g. [[Bungalow]], [[Ingolstadt]],
	-- [[Kongo]], [[Manga]], [[Singapur]], [[Tango]], [[Tonga]], [[Ungar]].
	--
	-- Exceptions to both rules will need respelling, e.g. [[Ingrid]] 'Inggrid', [[Ganglion]] 'Ganggli.on' (one
	-- pronunciation; unpronounced 'g' is also possible), [[Adstringens]] 'Adstrínggĕns', [[Anilingus]] 'Anilínggus',
	-- [[Ingrimm] 'Inggrimm', [[Singular]] 'Singgular' (although if spelled 'Singulàr', the first rule will take effect
	-- with the following stress).
	{"ng([lr]?" .. V .. "[^⁀‿]*" .. stress_c .. ")", "ŋ.g%1", true},
	{"ng([lr]?[ao])", "ŋ.g%1"},
	{"ng", "ŋŋ"},
	-- Cf. [[Funke]], [[Gedanke]], [[Kranker]], [[Beschränkung]], [[Erkrankung]], [[Verrenkung]], [[gelenkig]],
	-- [[stinkig]], etc. with no following stress; [[trinkbar]], [[Frankreich]], etc. within a syllable; [[Bankett]],
	-- [[bankrott]], [[Concorde]], [[Delinquent]] ('qu' respelled 'kv' above, feeding this rule), [[flankieren]],
	-- [[Frankierung]], [[Konklave]], [[Konkordia]], [[konkret]], [[melancholisch]] (respelled 'melankólisch'),
	-- etc. with following stress. Words with initial 'in-' pronounced /ɪn/ e.g. [[Inkarnation]], [[Inklusion]],
	-- [[inkohärent]], [[inkompatibel]], [[inkompetent]] will need respelling with a syllable divider 'In.karnation',
	-- 'In.klusion', 'in.ko.härent', [[in.kompatibel]], [[in.kompetent]]. (Similarly [[ingeniös]], [[Ingredienz]]
	-- respelled 'in.geniös', 'In.grêdienz'.)
	{"nk", "ŋk"},
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

	-- Handling of French and English sounds.
	{"([eo])(" .. accent_c .. "*[IU])", function(eo, iu)
		-- 'eI' as in 'SpreI' for [[Spray]]; 'eU' not in French or English but kept for parallelism
		-- 'oI' as in 'KauboI' for [[Cowboy]]; 'oU' as in 'HoUmpehdsch' for [[Homepage]]
		local lower_eo = {["e"] = "ɛ", ["o"] = "ɔ"}
		return lower_eo .. iu
	end},
	{"e" .. TILDE, "ɛ" .. TILDE},
	{"ö" .. TILDE, "œ" .. TILDE},

	-- Handling of 'ch'. Must follow diphthong handling so 'äu', 'eu' trigger ich-laut.
	{"tsch", "ʧʧ"},
	{"dsch", "ʤʤ"},
	{"sch", "ʃʃ"},
	{"chs", "ks"},
	{"([aɔoʊuU]" .. accent_c .. "*)ch", "%1xx"},
	{"ch", "çç"},

	-- Handling of 's'.
	{"([⁀‿])s(" .. V .. ")", "%1z%2"},
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
	{"([bd])s(" .. V .. ")([^⁀‿]*" .. stress_c .. ")", "%1z%2"},
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
	-- /ˌatˈlaːtʊs/ or /ˌaˈdlaːtʊs/ (same in dewikt); [[Adler]] -> /ˈaːdlɐ/; [[adrett]] -> /aˈdʁɛt/; [[Adstrat]] ->
	-- [atˈstʁaːt]; [[asthenisch]] -> /asˈteːnɪʃ/; [[Asthenosphäre]] -> /astenoˈsfɛːʁə/; [[Asthma]] -> [ˈast.ma];
	-- [[Astronaut]] -> /ˌas.tʁoˈnaʊ̯t/; [[asturisch]] -> /asˈtuːʁɪʃ/; [[synchron]] -> /zʏnˈkʁoːn/; [[Syndrom]] ->
	-- [zʏnˈdʁoːm]; [[System]] -> /zɪsˈteːm/ or /zʏsˈteːm/.
	-- Change user-specified . into SYLDIV so we don't shuffle it around when dividing into syllables.
	{"%.", SYLDIV},
	-- Divide before the last consonant. We then move the syllable division marker leftwards over clusters that can
	-- form onsets.
	{"(" .. V .. accent_c .. "*" .. C .. "-)(" .. C .. V .. ")", "%1.%2", true},
	-- Cases like [[Agrobiologie]] /ˈaːɡʁobioloˌɡiː/ show that Cl or Cr where C is a non-sibilant obstruent should be
	-- kept together. It's unclear with 'dl', cf. [[Adlatus]] /ˌatˈlaːtʊs/ or /ˌaˈdlaːtʊs/; but the numerous words
	-- like [[Adler]] /ˈaːdlɐ/ (reduced from ''*Adeler'') suggest we should keep 'dl' together. For 'tl', we have
	-- on the one hand [[Atlas]] /ˈatlas/ and [[Detlef]] [ˈdɛtlɛf] (dewikt) but on the other hand [[Bethlehem]]
	-- /ˈbeːt.ləˌhɛm/. For simplicity we treat 'dl' and 'tl' the same.
	{"(" .. obstruent_non_sibilant_c .. ")%.([lr])", ".%1%2"},
	-- Cf. [[Liquid]] [liˈkviːt]; [[Liquida]] [ˈliːkvida]; [[Mikwe]] /miˈkveː/; [[Taekwondo]] [tɛˈkvɔndo] (dewikt);
	-- [[Uruguayerin]] [ˈuːʁuɡvaɪ̯əʁɪn] (dewikt)
	{"([kg])%.v", ".%1v"},
	-- [[Signal]] [zɪˈɡnaːl] (dewikt); [[designieren]] [dezɪˈɡniːʁən] (dewikt); if split 'g.n', we'd expect [k.n].
	-- But notice the short 'i' (which we handle by a rule below). Cf. [[Kognition]] [ˌkɔɡniˈt͡si̯oːn] (dewikt) and
	-- [[Kognat]] [kɔˈɡnaːt] (dewikt) vs. [[Prognose]] [ˌpʁoˈɡnoːzə] (dewikt) with short closed 'o' (secondary stress
	-- doesn't lengthen vowel before primary stress). Cf. also [[orthognath]] [ɔʁtoˈɡnaːt] (dewikt), [[prognath]]
	-- [pʁoˈɡnaːt] (dewikt). Cf. [[Agnes]] [ˈaɡnɛs] (dewikt) but /ˈaː.ɡnəs/ (enwikt). Cf. [[regnen]] /ˈʁeː.ɡnən/
	-- "prescriptive standard" (enwikt), /ˈʁeːk.nən/ "most common" (enwikt). Similarly [[Gegner]], [[segnen]],
	-- [[Regnum]]. Also [[leugnen]], [[Leugner]] with the same /gn/ prescriptive, /kn/ more common; whereas [[Zeugnis]]
	-- always with /kn/ (because -nis is a suffix).
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
	--    e.g. [[Latex]] [ˈlaːtɛks] (dewikt); [[Index]] /ɪndɛks/; [[Alex]] /ˈalɛks/; [[Achilles]] [aˈxɪlɛs] (dewikt);
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
	{"(" .. V .. "[^⁀‿]*)e(%.r[^⁀‿]*" .. stress_c .. ")", "%1ə%2", true},
	-- Implement (7b) above. We exclude 'e' from the 'rest' portion below so we work right-to-left and correctly
	-- convert 'e' to schwa in cases like [[Indexen]].
	{"e([^⁀" .. stress .. "e]*⁀)", function(rest)
		local rest_no_syldiv = gsub(rest, "%.", "")
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
	{"i(" .. C .. "[⁀‿])", "i" .. BREVE .. "%1"},
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
	{"u([ms][⁀‿])", "u" .. BREVE .. "%1"},
	-- Unstressed final '-on' normally short, e.g. [[Aaron]], [[Abaton]], [[Natron]], [[Analogon]], [[Myon]], [[Anton]]
	-- (either long or short 'o'), [[Argon]], [[Axon]], [[Bariton]], [[Biathlon]], [[Bison]], etc. Same with unstressed
	-- '-os', e.g. [[Albatros]], [[Amos]], [[Amphiprostylos]], [[Barbados]], [[Chaos]], [[Epos]], [[Gyros]], [[Heros]],
	-- [[Kokos]], [[Kolchos]], [[Kosmos]], etc.
	{"o([ns][⁀‿])", "o" .. BREVE .. "%1"},

	-- Handle vowel quality/length changes in open vs. closed syllables, part b: Lengthen/shorten as appropriate.
	--
	-- Vowel with secondary stress in open syllable before primary stress later in the same component takes close
	-- quality without lengthening.
	{"(" .. V_unmarked_for_quality .. ")([" .. GRAVE .. DOUBLEGRAVE .. "][.‿][^⁀]*" .. ACUTE .. ")", "%1" .. CFLEX .. "%2", true},
	-- Any nasal vowel with secondary stress before primary stress later in the same component does not lengthen.
	-- Cf. [[Rendezvous]]. We signal that by inserting a circumflex before the tilde, which normally comes directly
	-- after the vowel.
	{"(" .. V .. ")" .. TILDE .. "([" .. GRAVE .. DOUBLEGRAVE .. "][^⁀]*" .. ACUTE .. ")", "%1" .. CFLEX .. TILDE .. "%2", true},
	-- Vowel with tertiary stress in open syllable before secondary stress later in the same component takes close
	-- quality without lengthening if component has no primary stress.
	{"⁀[^⁀" .. ACUTE .. "]*" .. V_unmarked_for_quality .. ")(" .. DOUBLEGRAVE .. "[.‿][^⁀" .. ACUTE .. "]*" .. GRAVE .. "[^⁀" .. ACUTE .. "]*⁀)",
		"%1" .. CFLEX .. "%2", true},
	-- Any nasal vowel with tertiary stress before secondary stress later in the same component takes does not lengthen
	-- if component has no primary stress. See above change for [[Rendezvous]].
	{"⁀[^⁀" .. ACUTE .. "]*" .. V .. ")" .. TILDE .. "(" .. DOUBLEGRAVE .. "[^⁀" .. ACUTE .. "]*" .. GRAVE .. "[^⁀" .. ACUTE .. "]*⁀)",
		"%1" .. CFLEX .. TILDE .. "%2", true},
	-- Remaining stressed vowel in open syllable lengthens.
	{"(" .. V_unmarked_for_quality .. ")(" .. stress_c .. "[.⁀‿])", "%1ː%2"},
	-- Same when followed by a single consonant word-finally or before a suffix.
	{"(" .. V_unmarked_for_quality .. ")(" .. stress_c .. C .. "[⁀‿])", "%1ː%2"},
	-- Remaining stressed nasal vowel lengthens.
	{"(" .. V .. TILDE .. ")(" .. stress_c .. "[.⁀‿])", "%1ː%2"},
	-- Now remove CFLEX before TILDE, which was inserted to prevent lengthening.
	{CFLEX .. TILDE, TILDE},
	-- Unstressed vowel in open syllable takes close quality without lengthening.
	{"(" .. V_unmarked_for_quality .. ")(" .. "[.⁀‿])", "%1" .. CFLEX .. "%2"},
	-- Same when followed by a single consonant word-finally or before a suffix.
	{"(" .. V_unmarked_for_quality .. ")(" .. C .. "[⁀‿])", "%1" .. CFLEX .. "%2"},
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
	-- Remove * that prevents vowel quality/length changes.
	{"(" .. V .. ")%*", "%1"},

	-- 'ĭg' is pronounced [ɪç] word-finally or before an obstruent (not before an approximant as in [[ewiglich]] or
	-- [[Königreich]] when divided as ''ewig.lich'', ''König.reich'').
	{"ɪg⁀", "ɪç⁀"},
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

	-- Eliminate remaining geminate consonants within a component (geminates can legitimately exist across a component
	-- boundary). These have served their purpose of keeping the preceding vowel short. Normally such geminates will
	-- always occur across a syllable boundary, but this may not be the case in the presence of user-specified syllable
	-- boundaries. We do this after coda devoicing so we eliminate the 'd' in words like [[verwandte]].
	{"(" .. C .. ")([.‿]*)%1", "%1", true},

	-- Add glottal stop at beginning of component before a vowel. FIXME: Sometimes this should not be present, I think.
	-- We need symbols to control this.
	-- If previous component ends in a vowel, glottal stop is mandatory, e.g. [[wiederentdecken]].
	{"(" .. V .. accent_c .. "*⁀)(" .. V .. ")", "%1ʔ%2"},
	-- At beginning of word, glottal stop is mandatory, but not shown in the phonemic notation.
	-- Before a stressed vowel at a component boundary, glottal stop is mandatory.
	{"⁀(" .. V .. accent_c .. "*" .. stress_c .. ")", "⁀ʔ%1"},
	-- Before an unstressed vowel at a component boundary, glottal stop is optional, e.g. [[Aufenthalt]]
	-- /ˈaʊ̯f.(ʔ)ɛntˌhalt/.
	{"⁀(" .. V .. ")", "⁀(ʔ)%1"},

	-- Remove ⁀ and ‿ (component/suffix boundaries) before non-syllabic components and suffixes. Examples where this
	-- can occur are final -t/-st inflectional suffixes (-t for third-person singular, second-person plural or past
	-- participle; -st for second-person singular or superlative) and -s- interfix between components, which may be
	-- respelled with hyphens around it (in such a case it should be grouped with the preceding syllable). Don't do
	-- this at the beginning of a word (which normally shouldn't happen but might in a dialectal word). This should
	-- precede 'ts' -> 'ʦ' just below.
	{"([^⁀‿])([⁀‿])(" .. non_V .. "*[⁀‿])", "%1%2", true},
	-- FIXME: Consider removing ⁀ and ‿ after non-syllabic component/prefix at the beginning of a word in case of
	-- dialectal spellings like 'gsund' for [[gesund]]; but to handle this properly we need additional rules to
	-- devoice the 'g' in such circumstances.

	-- -s- frequently occurs as a component by itself (really an interfix), e.g. in [[Wirtschaftswissenschaft]]
	-- respelled 'Wirtschaft-s-wissenschaft' to make it easier to identify suffixes like the -schaft in [[Wirtschaft]].
	-- Once we remove ⁀ and ‿ before non-syllabic components and suffixes, we get lots of 'ts' that should be rendered
	-- as t͡s. Handle this now. This should also apply in 'd-s-' e.g. [[Abschiedsbrief]] respelled 'Abschied-s-brief'
	-- /ˈapʃiːt͡sˌbʁiːf/, as coda 'd' gets devoiced to /t/ above.
	{"ts", "ʦ"},

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

	-- Convert ORIG_SUFFIX_GRAVE to either GRAVE or nothing. This must happen after removing ⁀ and ‿ before
	-- non-syllabic components and suffixes because it depends on being able to accurately identify syllables.
	handle_suffix_secondary_stress,

	-- Generate IPA stress marks.
	{ACUTE, "ˈ"},
	{GRAVE, "ˌ"},
	{DOUBLEGRAVE, ""},
	-- Move IPA stress marks to the beginning of the syllable.
	{"([.⁀‿])([^.⁀‿ˈˌ]*)([ˈˌ])", "%1%3%2"},
	-- Suppress syllable mark before IPA stress indicator.
	{"%.([ˈˌ])", "%1"},

	-- Convert explicit character notation to regular character.
	{".", explicit_char_to_phonemic},
}


-- These rules operate in order, on the output of phonemic_rules. Each rule is of the form {FROM, TO, REPEAT} where
-- FROM is a Lua pattern, TO is its replacement, and REPEAT is true if the rule should be executed using
-- `rsub_repeatedly()` (which will make the change repeatedly until nothing happens). The output of this is used to
-- generate the displayed phonetic pronunciation by removing ⁀ and ‿ symbols.
local phonetic_rules = {
	-- At the beginning of a word, glottal stop is mandatory before a vowel.
	{"(⁀⁀)(" .. V .. ")", "%1ʔ%2"},
	-- FIXME: Evaluate whether the following rules should apply across the ‿ symbol.
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
	{"p([.⁀]*b)", "p" .. UNRELEASED .. "%1"},
	{"t([.⁀]*d)", "t" .. UNRELEASED .. "%1"},
	{"k([.⁀]*ɡ)", "k" .. UNRELEASED .. "%1"}, -- IPA ɡ
	{"([ptk])(%.?[⁀" .. vowel .. "ʁl])", "%1ʰ%2"},
	{"(t" .. TIE .. "[sʃ])(%.?[⁀" .. vowel .. "ʁl])", "%1ʰ%2"},
	-- voiced stops/fricatives become unvoiced after unvoiced sound; cf. [[Abbildung]] [ˈʔap̚.b̥ɪl.dʊŋ]
	{"(" .. unvoiced_C .. "[.⁀]*[bdɡvzʒ])", "%1" .. UNVOICED}, -- IPA ɡ
	-- FIXME: Other possible phonemic/phonetic differences:
	-- (1) Omit syllable boundaries in phonemic notation?
	-- (2) Maybe not show some or all glottal stops in phonemic notation? Existing phonemic examples tend to omit it.
	-- (3) Maybe show -ieren as if written -iern; but this may be colloquial.
}


--[=[

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

]=]

local function generate_phonemic_word(word, is_cap)
	word = rsub(word, "(.)%*", char_to_explicit_char)
	-- local pos = default_pos(word, pos)
	local pos = nil
	local affix_type
	if word:find("^%-") and word:find("%-$") then
		affix_type = "interfix"
	elseif word:find("%-$") then
		affix_type = "prefix"
	elseif word:find("^%-") then
		affix_type = "suffix"
	end
	word = gsub(word, "^%-?(.-)%-?$", "%1")
	word = split_word_on_components_and_apply_affixes(word, pos, affix_type)
	word = rsub(word, AUTOACUTE, ACUTE)
	word = rsub(word, AUTOGRAVE, GRAVE)
	word = "⁀⁀" .. word .. "⁀⁀"
	word = apply_rules(word, phonemic_rules)
	return word
end

local function do_phonemic_phonetic(text, pos, is_phonetic)
	if type(text) == "table" then
		pos = text.args["pos"]
		text = text[1]
	end
	local result = {}
	text = canonicalize(text)
	local words = split_words(text)
	for _, wordspec in ipairs(words) do
		local word = generate_phonemic_word(wordspec.word, wordspec.is_cap)
		if is_phonetic then
			word = apply_rules(word, phonetic_rules)
		end
		table.insert(result, word)
	end
	result = table.concat(result, " ")
	result = gsub(result, "⁀", "")
	if not is_phonetic then
		-- Remove explicit syllable boundaries in phonemic notation. (FIXME: Is this the right thing to do?)
		result = gsub(result, "%.", "")
	end
	return result
end

function export.phonemic(text, pos)
	return do_phonemic_phonetic(text, pos, false)
end

function export.phonetic(text, pos)
	return do_phonemic_phonetic(text, pos, true)
end

function export.show(frame)
	local parent_args = frame:getParent().args
	local params = {
		[1] = { required = true, default = "Aufenthalt-s-genehmigung", list = true },
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
	if args.ann then
		anntext = "'''" .. args.ann .. "''':&#32;"
	else
		anntext = ""
	end

	return anntext .. m_IPA.format_IPA_full(lang, IPA_args)
end

return export
