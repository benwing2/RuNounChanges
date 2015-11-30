--[[
This module implements the template {{ru-IPA}} (FIXME, is it called elsewhere?)

Author: Originally Wyang; largely rewritten by Benwing, additional contributions
        from Atitarev and a bit from others

FIXME:

1. (DONE, NEEDS TESTING) Geminated /j/ from -йя-: treat as any other gemination,
   meaning it may not always be pronounced geminated. Currently we geminate it
   very late, after all the code that reduces geminates. Should be done earlier
   and places that include regexps with /j/ should be modified to also include
   the gemination marker ː. Words with йя: аллилу́йя, ауйяма, ва́йя, ма́йя,
   папа́йя, парано́йя, пира́йя, ра́йя, секво́йя, Гава́йям.
2. (DONE, NEEDS TESTING) Should have geminated jj in йе (occurs in e.g. фойе́).
   Should work with gem=y (see FIXME #1). Words with йе: фойе́,
   колба Эрленмейера, скала Айерс, Айерс-Рок, йети, Кайенна, конве́йер,
   конвейерный, сайентология, фейерверк, Гава́йев. Note also Гава́йи with йи.
3. (FIXME, DONE BUT NEEDS RETHINKING -- currently done both in CCʲj and VCʲj,
   maybe should only be done in CCʲj) In Асунсьо́н and Вьентья́н, put a syllable
   break after the н and before consonant + /j/. Use the perm_sym_onset
   mechanism or at least the code that accesses that mechanism. Should
   possibly do this also in VCʲj and V‿Cʲj and VCj and V‿Cj sequences;
   ask Cinemantique if this makes sense.
4. (DONE, NEED TO RUN IT BY CINEMANTIQUE, NEED TO EDIT льстец AND REMOVE
   MANUAL TRANSLIT, EDIT львёнок, львица) Fix non-palatal е in льстец.
   Other words that will be affected (and probably wrong): льви́ца, львя́тник,
   льняно́й, льстить, льди́на, львиный, manual pronunciation given as lʲvʲit͡sə
   and lʲvʲɵnək. Ask Cinemantique.
5. (DONE, NEED TO RUN IT BY CINEMANTIQUE) In львёнок, rendered as ˈlʲvɵnək
   instead of ˈlʲvʲɵnək. Apparently same issue as льстец, having to do with
   ь in beginning. This apparently has to do with the "assimilative
   palatalization of consonants when followed by front vowels" code, which
   blocks palatalization when the syllable begins with a cluster with a hard
   sign, or a soft sign followed by a consonant. Then "retraction of front
   vowels in syllables blocking assimilative palatalization" converts e to ɛ
   and i to y in such cases of blocked palatalization (not needed for žcš,
   which are handled by phon_respellings). Ask Cinemantique if this whole
   business makes any sense.
6. (DONE) In prefixes/suffixes like -ин, treat single syllable word as
   unstressed. Also support tilde to force unstressed syllable.
7. (DONE) In ни́ндзя, дз becomes palatal and н should palatal-assimilate to it.
8. (DONE) In под сту́лом, should render as pɐt͡s‿ˈstuləm when actually renders as
   pɐˈt͡s‿stuləm. Also occurs in без ша́пки (bʲɪˈʂ‿ʂapkʲɪ instead of
   bʲɪʂ‿ˈʂapkʲɪ); has something to do with ‿. Similarly occurs in
   не к ме́сту, which should render as nʲɪ‿k‿ˈmʲestʊ, and от я́блони, which
   should render as ɐt‿ˈjæblənʲɪ.
9. In собра́ние, Anatoli renders it as sɐˈbranʲɪ(j)ə with optional (j).
   Ask him when this exactly applies. Does it apply in all ɪjə sequences?
   Only word-finally? Also ijə?
10. (DONE, BUT I SUSPECT THE OFFENDING CLAUSE, LABELED 10a, CAN BE REWRITTEN
   MUCH MORE SIMPLY, SEE COMMENT AT CLAUSE; FIX THIS UP) (DONE, NEEDS TESTING)
   убе́жищa renders as ʊˈbʲeʐɨɕːʲə instead of ʊˈbʲeʐɨɕːə; уда́ча similarly
   becomes ʊˈdat͡ɕʲə instead of ʊˈdat͡ɕə.
10a. (DONE, NEEDS TESTING) Remove the "offending clause" just mentioned,
   labeled FIXME (10a), and fix it as the comment above it describes.
10b. (DONE, NEEDS TESTING) Remove the clause labeled "FIXME (10b)".
10c. (DONE, NEEDS TESTING) Investigate the clause labeled "FIXME (10c)".
   This relates to FIXME #9 above concerning собра́ние.
10d. (DONE, NEEDS TESTING) Investigate the clause labeled "FIXME (10d)"
   and apply the instructions there about removing a line and seeing
   whether anything changes.
11. (DONE, NEEDS TESTING) тро́лль renders with geminated final l, and
   with ʲ on wrong side of gemination (ːʲ instead of ʲː); note how this
   also occurs above in -ɕːʲə from убе́жищa. (This issue with тро́лль
   will be masked by the change to generally degeminate l; use фуррь; note
   also галльский.)
12. (DONE, NEEDS TESTING) May be additional errors with gemination in
    combination with explicit / syllable boundary, because of the code
	expecting that syllable breaks occur in certain places; should probably
	rewrite the whole gemination code to be less fragile and not depend on
	exactly where syllable breaks occur in consonant clusters, which it does
	now (might want to rewrite to avoid the whole business of breaking by
	syllable and processing syllable-by-syllable).
13. Many assimilations won't work properly with an explicit / syllable
   boundary.
14. (DONE, ASK WYANG FOR ITS PURPOSE) Eliminate pal=y. Consider first asking
   Wyang why this was put in originally.
15. (DONE) Add test cases: Цю́рих, от а́ба, others.
15a. (DONE) Add test cases: фуррь, по абази́ну (for assimilation of schwas
    across ‿)
15b. (DONE) Add test case англо-норма́ннский (to make sure degemination of нн
    occurs when not between vowels), multi-syllable word ending in a geminate:
	ато́лл (not so good because лл always degeminated), коло́сс, Иоа́нн (good
	because of нн), ха́ос, эвфеми́зм, хору́гвь (NOTE: ruwikt claims гв is voiced,
	I doubt it, ask Cinemantique), наря́д на ку́хню (non-devoicing of д before
	н in next word, ask Cinemantique about this, does it also apply to мрл?),
	ко̀е-кто́
16. (DONE, ADDED SPECIAL HACK; THEN REMOVED IT, SHOULD HANDLE THROUGH pos=pro)
    Caused a change in ко̀е-кто́, perhaps because I rewrote code that accepted
	an acute or circumflex accent to also take a grave accent. See how кое is
	actually pronounced here and take action if needed. (ruwiki claims кое is
	indeed pronounced like кои, ask Cinemantique what the rule for final -е
	is and why different in кое vs. мороженое, anything to do with secondary
	stress on о?)
17. (DONE, NEEDS CHECKING, CHECK эвфеми́зм) Rewrote voicing/devoicing
    assimilation; should make assimilation of эвфеми́зм automatic and not
	require phon=.
18. (DONE, NEEDS TESTING) Removed redundant fronting-of-a code near end;
    make sure this doesn't change anything.
19. (DONE, ANSWER IS YES) do сь and зь assimilate before шж, and
    if so do they become ɕʑ? Ask Cinemantique.
20. (DONE) Add pos= to handle final -е. Possibilities appear to be neut
    (neuter noun), adj (adjective, autodetected whether singular or plural),
	comp (comparative), pre (prepositional case), adv (adverb), verb or v (2nd
	plural verb forms).
21. (DONE, DEVOICE UNLESS NEXT WORD BEGINS WITH VOICED OBSTRUENT OR V+VOICED
    OBSTRUENT) Figure out what to do with devoicing or non-devoicing before
	mnrlv vowel. Apparently non-devoicing before vowel is only in fast speech
	with a close juncture and Anatoli doesn't want that; but what about before
	the consonants?
22. (DONE) (DONE, NEEDS TESTING, NEED TO REMOVE ADDITION OF BRACKETS FROM
    ru-IPA) Figure out what to do with fronting of a and u after or between
	soft consonants, esp. when triggered by a following soft consonant with
	optional or compulsory assimilation. Probably the correct thing to do
	in the case of optional assimilation is to give two pronunciations
	separated by commas, one with non-front vowel + hard consonant, the
	other with front vowel + soft consonant.
23. (DONE, OK) Implement compulsory assimilation of xkʲ; ask Cinemantique to
    make sure this is correct.
]]

local ut = require("Module:utils")
local com = require("Module:ru-common")
local m_ru_translit = require("Module:ru-translit")
local strutils = require("Module:string utilities")

local export = {}
local u = mw.ustring.char
local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local ulower = mw.ustring.lower
local uupper = mw.ustring.upper
local usub = mw.ustring.sub
local ulen = mw.ustring.len

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
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

-- If enabled, compare this module with new version of module to make
-- sure all pronunciations are the same. Eventually consider removing this;
-- but useful as new code is created.
local test_new_ru_pron_module = false

local AC = u(0x0301) -- acute =  ́
local GR = u(0x0300) -- grave =  ̀
local DUBGR = u(0x030F) -- double grave =  ̏
local DOTABOVE = u(0x0307) -- dot above =  ̇
local CFLEX = u(0x0302) -- circumflex =  ̂

local vow = 'aeiouyɛəäëöü'
local ipa_vow = vow .. 'ɐɪʊɨæɵʉ'
local vowels, vowels_c = '[' .. vow .. ']', '([' .. vow .. '])'
local acc = AC .. GR .. CFLEX .. DOTABOVE
local accents = '[' .. acc .. ']'

local perm_syl_onset = ut.list_to_set({
	'str', 'sp', 'st', 'sk', 'sf', 'sx', 'sc',
	'pr', 'kr', 'fr', 'xr',
	'pl', 'tl', 'kl', 'gl', 'fl', 'xl',
	'ml', 'mn',
	'šč', 'dž',
})

-- FIXME: Consider changing ӂ internally to ʑ to match ɕ (it is used externally
-- in e.g. дроӂӂи (pronunciation spelling of дрожжи)
local translit_conv = {
	['c'] = 't͡s', ['č'] = 't͡ɕ', ['ĉ'] = 't͡ʂ',
	['g'] = 'ɡ', ['ĝ'] = 'd͡ʐ',
	['ĵ'] = 'd͡z', ['ǰ'] = 'd͡ʑ', ['ӂ'] = 'ʑ',
	['š'] = 'ʂ', ['ž'] = 'ʐ'
}

local translit_conv_j = {
	['cʲ'] = 'tʲ͡sʲ',
	['ĵʲ'] = 'dʲ͡zʲ'
}

local allophones = {
	['a'] = { 'a', 'ɐ', 'ə' },
	['e'] = { 'e', 'ɪ', 'ɪ' },
	['i'] = { 'i', 'ɪ', 'ɪ' },
	['o'] = { 'o', 'ɐ', 'ə' },
	['u'] = { 'u', 'ʊ', 'ʊ' },
	['y'] = { 'ɨ', 'ɨ', 'ɨ' },
	['ɛ'] = { 'ɛ', 'ɨ', 'ɨ' },
	['ä'] = { 'a', 'ɪ', 'ɪ' },
	['ë'] = { 'e', 'ɪ', 'ɪ' },
	['ö'] = { 'ɵ', 'ɪ', 'ɪ' },
	['ü'] = { 'u', 'ʊ', 'ʊ' },
	['ə'] = { 'ə', 'ə', 'ə' },
}

local devoicing = {
	['b'] = 'p', ['d'] = 't', ['g'] = 'k',
	['z'] = 's', ['v'] = 'f',
	['ž'] = 'š', ['ɣ'] = 'x',
	['ĵ'] = 'c', ['ǰ'] = 'č', ['ĝ'] = 'ĉ',
	['ӂ'] = 'ɕ',
}

local voicing = {
	['p'] = 'b', ['t'] = 'd', ['k'] = 'g',
	['s'] = 'z', ['f'] = 'v',
	['š'] = 'ž', ['c'] = 'ĵ', ['č'] = 'ǰ', ['ĉ'] = 'ĝ',
	['x'] = 'ɣ', ['ɕ'] = 'ӂ'
}

local iotating = {
	['a'] = 'ä',
	['e'] = 'ë',
	['o'] = 'ö',
	['u'] = 'ü'
}

local retracting = {
	['e'] = 'ɛ',
	['i'] = 'y',
}

local fronting = {
	['a'] = 'æ',
	['u'] = 'ʉ',
	['ʊ'] = 'ʉ',
}

-- Prefixes that we recognize specially when they end in a geminated
-- consonant. The first element is the result after applying voicing/devoicing,
-- gemination and other changes. The second element is the original spelling,
-- so that we don't overmatch and get cases like Поттер. We check for these
-- prefixes at the beginning of words and also preceded by ne-, po- and nepo-.
local geminate_pref = {
	--'abː', --'adː',
	{'be[szšž]ː', 'be[sz]'},
	--'braomː',
	{'[vf]ː', 'v'},
	{'vo[szšž]ː', 'vo[sz]'},
	{'i[szšž]ː', 'i[sz]'},
	--'^inː',
	{'kontrː', 'kontr'},
	{'superː', 'super'},
	{'tran[szšž]ː', 'trans'},
	{'na[tdcč]ː', 'nad'},
	{'ni[szšž]ː', 'ni[sz]'},
	{'o[tdcč]ː', 'ot'}, --'^omː',
	{'o[bp]ː', 'ob'},
	{'obe[szšž]ː', 'obe[sz]'},
    {'po[tdcč]ː', 'pod'},
	{'pre[tdcč]ː', 'pred'}, --'^paszː', '^pozː',
	{'ra[szšž]ː', 'ra[sz]'},
	{'[szšž]ː', '[szšž]'}, -- ž on right side for жжёт etc.
	{'me[žš]ː', 'mež'},
	{'če?re[szšž]ː', 'če?re[sz]'},
	-- certain double prefixes involving ra[zs]-
	{'predra[szšž]ː', 'predra[sz]'},
	{'bezra[szšž]ː', 'bezra[sz]'},
	{'nara[szšž]ː', 'nara[sz]'},
	{'vra[szšž]ː', 'vra[sz]'},
	{'dora[szšž]ː', 'dora[sz]'},
	-- '^sverxː', '^subː', '^tröxː', '^četyröxː',
}

local sztab = { s='cs', z='ĵz' }
local function ot_pod_sz(pre, sz)
	return pre .. sztab[sz]
end

local phon_respellings = {
	{'h', 'ɣ'},
	-- vowel changes after always-hard or always-soft consonants
	{'([šž])j([ou])', '%2%3'},
	-- the following will also affect šč = ɕː, and do it before
	-- converting šč -> ɕː just below
	{'([čǰӂ])([aou])', '%1j%2'},

	{'šč', 'ɕː'}, -- conversion of šč to geminate

	-- the following six are ordered before changes that affect ts
	-- FIXME!!! Should these next fouralso pay attention to grave accents?
	{'́tʹ?sja⁀', '́cca⁀'},
	{'([^́])tʹ?sja⁀', '%1ca⁀'},
	{'n[dt]sk', 'n(t)sk'},
	{'s[dt]sk', 'sck'},

	-- main changes for affricate assimilation of [dt] + sibilant, including ts;
	-- we either convert to "short" variants t͡s, d͡z, etc. or to "long" variants
	-- t͡ss, d͡zz, etc.
	-- 1. т с, д з across word boundary, also т/с, д/з with explicitly written
	--    slash, use long variants.
	{'[dt](ʹ?[ ‿⁀/]+)s', 'c%1s'},
	{'[dt](ʹ?[ ‿⁀/]+)z', 'ĵ%1z'},
	-- 2. тс, дз + vowel use long variants.
	{'[dt](ʹ?)s(j?' .. vowels .. ')', 'c%1s%2'},
	{'[dt](ʹ?)z(j?' .. vowels .. ')', 'ĵ%1z%2'},
	-- 3. тьс, дьз use long variants.
	{'[dt]ʹs', 'cʹs'},
	{'[dt]ʹz', 'ĵʹz'},
	-- 4. word-initial от[сз]-, под[сз]- use long variants because there is
	--    a morpheme boundary.
	{'(⁀o' .. accents .. '?)t([sz])', ot_pod_sz},
	{'(⁀po' .. accents .. '?)d([sz])', ot_pod_sz},
	-- 5. other тс, дз use short variants.
	{'[dt]s', 'c'},
	{'[dt]z', 'ĵ'},
	-- 6. тш, дж always use long variants (FIXME, may change)
	{'[dt](ʹ?[ %-‿⁀/]*)š', 'ĉ%1š'},
	{'[dt](ʹ?[ %-‿⁀/]*)ž', 'ĝ%1ž'},
	-- 7. soften palatalized hard hushing affricates resulting from the previous
	{'ĉʹ', 'č'},
	{'ĝʹ', 'ǰ'},

	-- changes that generate ɕː and ɕč through assimilation:
	-- зч and жч become ɕː, as does сч at the beginning of a word and in the
	-- sequence счёт when not following [цдт] (подсчёт); else сч becomes ɕč
	-- (отсчи́тываться), as щч always does (рассчитáть written ращчита́ть)
	{'[cdt]sč', 'čɕː'},
	{'ɕːč', 'ɕč'},
	{'[zž]č', 'ɕː'},
	{'[szšž]ɕː?', 'ɕː'},
	{'⁀sč', '⁀ɕː'},
	{'sčjo(' .. accents .. '?)t', 'ɕːjo%1t'},
	{'sč', 'ɕč'},

	-- misc. changes for assimilation of [dtsz] + sibilants and affricates
	{'[sz][dt]c', 'sc'},
	{'([rn])[dt]([cč])', '%1%2'},
	{'[dt]([cč])', '%1%1'},
	-- the following is ordered before the next one, which applies assimilation
	-- of [тд] to щ (including across word boundaries)
	{'n[dt]ɕ', 'nɕ'},
	-- [сз] and [сз]ь before soft affricates [щч], including across word
	-- boundaries; note that the common sequence сч has already been handled
	{'[zs]ʹ?([ ‿⁀/]*[ɕč])', 'ɕ%1'},
	-- reduction of too many ɕ's, which can happen from the previous
	{'ɕɕː', 'ɕː'},
	-- assimilation before [тдц] and [тдц]ь before щ
	{'[cdt]ʹ?([ ‿⁀/]*)ɕ', 'č%1ɕ'},
	-- assimilation of [сз] and [сз]ь before [шж]
	{'[zs]([ ‿⁀/]*)š', 'š%1š'},
	{'[zs]([ ‿⁀/]*)ž', 'ž%1ž'},
	{'[zs]ʹ([ ‿⁀/]*)š', 'ɕ%1š'},
	{'[zs]ʹ([ ‿⁀/]*)ž', 'ӂ%1ž'},

	{'sverxi', 'sverxy'},
	{'stʹd', 'zd'},
	{'tʹd', 'dd'},

	-- loss of consonants in certain clusters
	{'([ns])[dt]g', '%1g'},
	{'zdn', 'zn'},
	{'lnc', 'nc'},
	{'[sz]t([ln])', 's%1'},
	
	 -- backing of /i/ after hard consonants in close juncture
	{'([mnpbtdkgfvszxɣrlšžcĵĉĝ])⁀‿⁀i', '%1⁀‿⁀y'},
	{'ʹo', 'ʹjo'}, -- ьо is pronounced as (possibly unstressed) ьё
}

local cons_assim_palatal = {
	-- assimilation of tn, dn, nč, nɕ is handled specially
	compulsory = ut.list_to_set({'stʲ', 'zdʲ', 'ntʲ', 'ndʲ', 'xkʲ',
	    'csʲ', 'ĵzʲ', 'ncʲ', 'nĵʲ'}),
	optional = ut.list_to_set({'slʲ', 'zlʲ', 'snʲ', 'znʲ', 'nsʲ', 'nzʲ',
		'mpʲ', 'mbʲ', 'mfʲ', 'fmʲ'})
}

--@Wyang - they may carry the stress too, as alternatives - по́ небу/по не́бу, etc.
local accentless = {
	prep = ut.list_to_set({'bez', 'bliz', 'v', 'vo', 'do',
       'iz-pod', 'iz-za', 'za', 'iz', 'izo',
       'k', 'ko', 'mež', 'na', 'nad', 'nado', 'o', 'ob', 'obo', 'ot',
       'po', 'pod', 'podo', 'pred', 'predo', 'pri', 'pro', 'pered', 'peredo',
       'čerez', 's', 'so', 'u', 'ne'}),
	posthyphen = ut.list_to_set({'to'}),
	post = ut.list_to_set({'libo', 'nibudʹ', 'by', 'b', 'že', 'ž',
       'ka', 'tka', 'li'})
}

-- Pronunciation of final unstressed -е, depending on the part of speech and
--   exact ending.
--
-- Endings:
--   oe = -ое
--   ve = any other vowel plus -е (FIXME, may have to split out -ее)
--   je = -ье
--   softpaired = soft paired consonant + -е
--   hardsib = hard sibilant (ц, ш, ж) + -е
--   softsib = soft sibilant (ч, щ) + -е
--
-- Parts of speech:
--   def = default used in absence of pos
--   n/noun = neuter noun in the nominative/accusative
--   inv = invariable noun
--   a/adj = adjective (typically either neuter in -ое or -ее, or plural in
--                    -ие, -ые, or -ье)
--   c/com = comparative (typically either in -ее or sibilant + -е)
--   pre = prepositional case
--   dat = dative case (treated same as prepositional)
--   adv = adverb
--   voc = vocative case
--   v/vb/verb = verbal ending (usually 2nd-plural in -те)
--   pro = pronoun (кое-, какие-)
--   hi/high = force high values ([ɪ] or [ɨ])
--   mid = force mid values ([e] or [ɨ])
--   lo/low/schwa = force low, really schwa, values ([ə])
--
-- Possible values:
--   1. ə [ə], e [e], i [ɪ] after a vowel or soft consonant
--   2. ə [ə] or y [ɨ] after a hard sibilant
--
-- If a part of speech doesn't have an entry for a given type of ending,
--   it receives the default value. If a part of speech's entry is a string,
--   it's an alias for another way of specifying the same part of speech
--   (e.g. n=noun).
local final_e = {
	def={oe='ə', ve='e', je='e', softpaired='e', hardsib='y', softsib='e'}
	noun={oe='ə', ve='e', je='e', softpaired='e', hardsib='ə', softsib='e'},
	n='noun',
	adj={oe='ə', ve='e', je='ə'}, -- FIXME: Not sure about -ее, e.g. neut adj си́нее
	a='adj',
	com={ve='e', hardsib='y', softsib='e'},
	c='com',
	pre={oe='e', ve='e', softpaired='e', hardsib='y', softsib='e'},
	dat='pre',
	adv={softpaired='e', hardsib='y', softsib='e'},
	voc='mid',
	inv='mid',
	verb={softpaired='e'},
	v='verb',
	vb='verb'
	pro={oe='i', ve='i'},
	-- forced values
	high={oe='i', ve='i', je='i', softpaired='i', hardsib='y', softsib='i'},
	hi='high',
	mid={oe='e', ve='e', je='e', softpaired='e', hardsib='y', softsib='e'},
	low={oe='ə', ve='ə', je='ə', softpaired='ə', hardsib='ə', softsib='ə'},
	lo='low',
	schwa='low'
}

local function ine(x)
	return x ~= "" and x or nil
end

local function track(page)
	local m_debug = require("Module:debug")
	m_debug.track("ru-pron/" .. page)
	return true
end

function export.ipa(text, adj, gem, bracket, pos)
	local new_module_result
	-- Test code to compare existing module to new one.
	if test_new_ru_pron_module then
		local m_new_ru_pron = require("Module:User:Benwing2/ru-pron")
		new_module_result = m_new_ru_pron.ipa(text, adj, gem, bracket, pos)
	end

	if type(text) == 'table' then
		text, adj, gem, bracket, pos = (ine(text.args.phon) or ine(text.args[1])), ine(text.args.adj), ine(text.args.gem), ine(text.args.bracket), ine(text.args.pos)
		if not text then
			text = mw.title.getCurrentTitle().text
		end
	end
	gem = usub(gem or '', 1, 1)

	pos = pos or "def"
	-- If a multipart part of speech, split into components, and convert
	-- each blank component to the default.
	if rfind(pos, "/") then
		pos = rsplit(pos, "/")
		for i=1,#pos do
			if pos[i] == "" then
				pos[i] = "def"
			end
		end
	end
	-- Verify that pos (or each part of multipart pos) is recognized
	for _, p in ipairs(type(pos) == "table" and pos or {pos}) do
		if not final_e[pos] then
			error("Unrecognized part of speech '" .. pos .. "': Should be n/noun/neut, a/adj, c/com, pre, dat, adv, inv, voc, v/verb, pro, hi/high, mid, lo/low/schwa or omitted")
		end
	end

	text = ulower(text)

	if gem ~= '' then
		track("gem")
		track("gem/" .. gem)
	end
	if adj then
		track("adj")
	end
	if rfind(text, "[a-zščžáéíóúýàèìòùỳ]") then
		track("latin-text")
	end
	if rfind(text, "[сз]ч") then
		track("sch")
	end
	if rfind(text, "[шж]ч") then
		track("shch")
	end
	if rfind(text, CFLEX) then
		track("cflex")
	end
	if rfind(text, DUBGR) then
		track("dubgr")
	end

	text = rsub(text, "``", DUBGR)
	text = rsub(text, "`", GR)
	text = rsub(text, "@", DOTABOVE)
	text = rsub(text, "%^", CFLEX)
	text = rsub(text, DUBGR, CFLEX)

	-- translit doesn't always convert э to ɛ (depends on whether a consonant
	-- precedes), so do it ourselves before translit
	text = rsub(text, 'э', 'ɛ')
	-- vowel + йе should have double jj, but the translit module will translit
	-- it the same as vowel + е, so do it ourselves before translit
	text = rsub(text, '([' .. com.vowel .. ']' .. com.opt_accent .. ')й([еѐ])',
		'%1йй%2')
	-- transliterate and decompose Latin vowels with accents, recomposing
	-- certain key combinations
	text = com.translit(text)

	-- handle old ě (e.g. сѣдло́), and ě̈ from сѣ̈дла
	text = rsub(text, 'ě̈', 'jo' .. AC)
	text = rsub(text, 'ě', 'e')
	-- handle sequences of accents (esp from ё with secondary/tertiary stress)
	text = rsub(text, accents .. '+(' .. accents .. ')', '%1')

	-- canonicalize multiple spaces
	text = rsub(text, '%s+', ' ')

	-- Add primary stress to single-syllable words preceded or followed by
	-- unstressed particle or preposition. Make remaining single-syllable
	-- words that aren't a particle or preposition or have an accent mark
	-- or begin or end with a hyphen have "tertiary" stress (treated as
	-- stressed but without a primary or secondary stress marker; we
	-- repurpose a circumflex for this purpose). We need to preserve the
	-- distinction between spaces and hyphens because we only recognize
	-- certain post-accentless particles following a dash (to distinguish e.g.
	-- 'то' from '-то') and we recognize hyphens for the purpose of marking
	-- unstressed prefixes and suffixes.
	local word = strutils.capturing_split(text, "([ %-]+)")
	for i = 1, #word do
		if not accentless['prep'][word[i]] and not (i > 2 and accentless['post'][word[i]]) and not (i > 2 and accentless['posthyphen'][word[i]] and word[i-1] == "-") and
			ulen(rsub(word[i], '[^' .. vow .. ']', '')) == 1 and
			not rfind(word[i], accents) then
			if (i == 3 and word[2] == "-" and word[1] == "" or
				i >= 3 and word[i-1] == " -" or
				i == #word - 2 and word[i+1] == "-" and word[i+2] == "" or
				i <= #word - 2 and word[i+1] == "- ") then
				-- prefix or suffix, leave unstressed
			elseif (i > 2 and accentless['prep'][word[i-2]] or i < #word - 1 and accentless['post'][word[i+2]] or i < #word - 1 and word[i+1] == "-" and accentless['posthyphen'][word[i+2]]) then
				-- preceded by a preposition, or followed by an unstressed
				-- particle or by -то; add primary stress
				word[i] = rsub(word[i], vowels_c, '%1' .. AC)
			else
				-- add tertiary stress
				word[i] = rsub(word[i], vowels_c, '%1' .. CFLEX)
			end
		end
	end


	-- make prepositions and particles liaise with the following or
	-- preceding word
	for i = 1, #word do
		if i < #word - 1 and accentless['prep'][word[i]] then
			word[i+1] = '‿'
		elseif i > 2 and (accentless['post'][word[i]] or accentless['posthyphen'][word[i]] and word[i-1] == "-") then
			word[i-1] = '‿'
		end
	end

	-- rejoin words, convert hyphens to spaces and eliminate stray spaces
	-- resulting from this
	text = table.concat(word, "")
	text = rsub(text, '[%-%s]+', ' ')
	text = rsub(text, '^ ', '')
	text = rsub(text, ' $', '')

	-- convert commas and en/en dashes to IPA foot boundaries
	text = rsub(text, '%s*[,–—]%s*', ' | ')

	-- add a ⁀ at the beginning and end of every word and at close juncture
	-- boundaries; we will remove this later but it makes it easier to do
	-- word-beginning and word-end rsubs
	text = rsub(text, ' ', '⁀ ⁀')
	text = '⁀' .. text .. '⁀'
	text = rsub(text, '‿', '⁀‿⁀')

	-- add tertiary stress to final -о after vowels, e.g. То́кио;
	-- this needs to be done before eliminating dot-above
	text = rsub(text, '(' .. vowels .. accents .. '?o)⁀', '%1' .. CFLEX .. '⁀')

	-- eliminate dot-above, which has served its purpose of preventing any
	-- sort of stress
	text = rsub(text, DOTABOVE, '')

	text = adj and rsub(text, '(.[aoe]́?)go(' .. AC .. '?)⁀', '%1vo%2⁀') or text
	text = adj and rsub(text, '(.[aoe]́?)go(' .. AC .. '?)⁀', '%1vo%2sja⁀') or text

	-- save original word spelling before respellings, (de)voicing changes,
	-- geminate changes, etc. for implementation of geminate_pref
	local orig_word = rsplit(text, " ", true)

	--phonetic respellings
	for _, respell in ipairs(phon_respellings) do
		text = rsub(text, respell[1], respell[2])
	end

	--voicing, devoicing
	--1. absolutely final devoicing
	text = rsub(text, '([bdgvɣzžĝĵǰӂ])(ʹ?⁀)$', function(a, b)
		return devoicing[a] .. b end)
	--2. word-final devoicing before another word
	text = rsub(text, '([bdgvɣzžĝĵǰӂ])(ʹ?⁀ ⁀[^bdgɣzžĝĵǰӂ])', function(a, b)
		return devoicing[a] .. b end)
	--3. voicing/devoicing assimilation; repeat to handle recursive assimilation
	while true do
		local new_text = rsub(text, '([bdgvɣzžĝĵǰӂ])([ ‿⁀ʹː()/]*[ptkfxsščɕcĉ])', function(a, b)
			return devoicing[a] .. b end)
		new_text = rsub(new_text, '([ptkfxsščɕcĉ])([ ‿⁀ʹː()/]*v?[ ‿⁀ʹː()/]*[bdgɣzžĝĵǰӂ])', function(a, b)
			return voicing[a] .. b end)
		if new_text == text then
			break
		end
		text = new_text
	end

	--re-notate orthographic geminate consonants
	text = rsub(text, '([^' .. vow .. '.%-_])' .. '%1', '%1ː')
	text = rsub(text, '([^' .. vow .. '.%-_])' .. '%(%1%)', '%1(ː)')

	--rewrite iotated vowels
	text = rsub(text, '(j[%(ː%)]*)([aeou])', function(a, b)
		return a .. iotating[b] end)
	-- eliminate j after consonant and before iotated vowel
	text = rsub(text, '([^' .. vow .. acc .. 'ʹʺ‿⁀ ]/?)j([äëöü])', '%1%2')

	--split by word and process each word
	word = rsplit(text, " ", true)

	if type(pos) == "table" and #pos ~= #word then
		error("Number of parts of speech (" .. #pos .. ") should match number of combined words (" .. #word .. ")")
	end
	for i = 1, #word do
		local pron = word[i]

		-- Check for gemination at prefix boundaries; if so, convert the
		-- regular gemination symbol ː to a special symbol ˑ that indicates
		-- we always preserve the gemination unless gem=n. We look for
		-- certain sequences at the beginning of a word, but make sure that
		-- the original spelling is appropriate as well (see comment above
		-- for geminate_pref).
		if rfind(pron, 'ː') then
			local orig_pron = orig_word[i]
			local deac = rsub(pron, accents, '')
			local orig_deac = rsub(orig_pron, accents, '')
			for _, gempref in ipairs(geminate_pref) do
				local newspell = gempref[1]
				local oldspell = gempref[2]
				-- FIXME! The rsub below will be incorrect if there is
				-- gemination in a joined preposition or particle
				if rfind(orig_deac, '⁀' .. oldspell) and rfind(deac, '⁀' .. newspell) or
					rfind(orig_deac, '⁀ne' .. oldspell) and rfind(deac, '⁀ne' .. newspell) then
					pron = rsub(pron, '(⁀[^‿⁀ː]*)ː', '%1ˑ')
				end
			end
		end

		--degemination, optional gemination
		if gem == 'y' then
			-- leave geminates alone, convert ˑ to regular gemination; ˑ is a
			-- special gemination symbol used at prefix boundaries that we
			-- remove only when gem=n, else we convert it to regular gemination
			pron = rsub(pron, 'ˑ', 'ː')
		elseif gem == 'o' then
			-- make geminates optional, except for ɕӂ, also ignore left paren
			-- in (ː) sequence
			pron = rsub(pron, '([^ɕӂ%(%)])[ːˑ]', '%1(ː)')
		elseif gem == 'n' then
			-- remove gemination, except for ɕӂ
			pron = rsub(pron, '([^ɕӂ%(%)])[ːˑ]', '%1')
		else
			-- degeminate l's
			pron = rsub(pron, '(l)ː', '%1')
			-- preserve gemination between vowels immediately after the stress,
			-- special gemination symbol ˑ also remains, ɕӂ remain geminated,
			-- žn remain geminated between vowels even not immediately after
			-- the stress, n becomes optionally geminated when after but not
			-- immediately after the stress, ssk and zsk remain geminated
			-- immediately after the stress, else degeminate; we signal that
			-- gemination should remain by converting to special symbol ˑ,
			-- then removing remaining ː not after ɕӂ and left paren; do
			-- various subs repeatedly in case of multiple geminations in a word
			-- 1. immediately after the stress
			pron = rsub_repeatedly(pron, '(' .. vowels .. accents .. '[^ɕӂ%(%)])ː(' .. vowels .. ')', '%1ˑ%2')
			-- 2. remaining geminate n after the stress between vowels
			pron = rsub_repeatedly(pron, '(' .. AC .. '.-' .. vowels .. accents .. '?n)ː(' .. vowels .. ')', '%1(ː)%2')
			-- 3. remaining ž and n between vowels
			pron = rsub_repeatedly(pron, '(' .. vowels .. accents .. '?[žn])ː(' .. vowels .. ')', '%1ˑ%2')
			-- 4. ssk (and zsk, already normalized) immediately after the stress
			pron = rsub(pron, '(' .. vowels .. accents .. '[^' .. vow .. ']*s)ː(k)', '%1ˑ%2')
			-- 5. eliminate remaining gemination
			pron = rsub(pron, '([^ɕӂ%(%)])ː', '%1')
			-- 6. convert special gemination symbol ˑ to regular gemination
			pron = rsub(pron, 'ˑ', 'ː')
		end

		-- handle soft and hard signs, assimilative palatalization
		-- 1. insert j before i when required
		pron = rsub(pron, 'ʹi', 'ʹji')
		-- 2. insert glottal stop after hard sign if required
		pron = rsub(pron, 'ʺ([aɛiouy])', 'ʔ%1')
		-- 3. assimilative palatalization of consonants when followed by
		--    front vowels or soft sign
		pron = rsub(pron, '([mnpbtdkgfvszxɣrl])([ː()]*[eiäëöüʹ])', '%1ʲ%2')
		pron = rsub(pron, '([cĵ])([ː()]*[äöüʹ])', '%1ʲ%2')
		-- 4. remove hard and soft signs
		pron = rsub(pron, "[ʹʺ]", "")

		-- reduction of unstressed word-final -я, -е; but special-case
		-- unstressed не, же. Final -я always becomes [ə]; final -е may
		-- become [ə], [e], [ɪ] or [ɨ] depending on the part of speech and
		-- the preceding consonants/vowels.
		pron = rsub(pron, 'ä⁀', 'ə⁀')
		pron = rsub(pron, '⁀ne⁀', '⁀ni⁀')
		pron = rsub(pron, '⁀že⁀', '⁀žy⁀')
		-- function to fetch the appropriate value for ending and part of
		-- speech, handling aliases and defaults and converting 'e' to 'ê'
		-- so that the unstressed [e] sound is preserved
		function fetch_e_sub(ending)
			local thispos = type(pos) == "table" and pos[i] or pos
			local chart = final_e[thispos]
			while type(chart) == "string" do -- handle aliases
				chart = final_e[chart]
			end
			assert(type(chart) == "table")
			local sub = chart[ending] or final_e['def'][ending]
			assert(sub)
			if sub == 'e' then
				-- add CFLEX to preserve the unstressed [e] sound, which
				-- will otherwise be converted to [ɪ]; NOTE: DO NOT use ê
				-- here directly because it's a single composed char, when
				-- we need the e and accent to be separate
				return 'e' .. CFLEX
			else
				return sub
			end
		end
		-- handle substitutions in two parts, one for vowel+j+e sequences
		-- and the other for cons+e sequences
		pron = rsub(pron, vowels_c .. '(' .. accents .. '?j)ë⁀', function(v, ac)
			 local ty = v == 'o' and 'oe' or 've'
			 return v .. ac .. fetch_e_sub(ty)
		end)
		-- consonant may palatalized, geminated or optional-geminated
		pron = rsub(pron, '(.)(ʲ?[ː()]*)[eë]⁀', function(ch, mod)
			 local ty = ch == 'j' and 'je' or
				rfind(ch, '[cĵšžĉĝ]') and 'hardsib' or
				rfind(ch, '[čǰɕӂ]') and 'softsib' or
				'softpaired'
			 return ch ..modc .. fetch_e_sub(ty)
		end)

		-- retraction of е and и after цшж; FIXME, this is partly done
		-- above in phon_respellings, should be cleaned up
		pron = rsub(pron, '([cĵšžĉĝ][ː()]*)([ei])', function(a, b)
			return a .. retracting[b] end)

		--syllabify, inserting @ at syllable boundaries
		--1. insert @ after each vowel
		pron = rsub(pron, '(' .. vowels .. accents .. '?)', '%1@')
		--2. eliminate word-final @
		pron = rsub(pron, '@+⁀$', '⁀')
		--3. move @ forward directly before any ‿⁀, as long as at least
		--   one consonant follows that; we will move it across ‿⁀ later
		pron = rsub(pron, '@([^@' .. vow .. acc .. ']*)([‿⁀]+[^‿⁀@' .. vow .. acc .. '])', '%1@%2')
		--4. in a consonant cluster, move @ forward so it's before the
		--   last consonant
		pron = rsub(pron, '@([^‿⁀@' .. vow .. acc .. ']*)([^‿⁀@' .. vow .. acc .. 'ːˑ()ʲ]ʲ?[ːˑ()]*‿?[' .. vow .. acc .. '])', '%1@%2')
		--5. move @ backward if in the middle of a "permanent onset" cluster,
		--   e.g. sk, str, that comes before a vowel, putting the @ before
		--   the permanent onset cluster
		pron = rsub(pron, '([^‿⁀@' .. vow .. acc .. ']?)([^‿⁀@' .. vow .. acc .. '])@([^‿⁀@' .. vow .. acc .. 'ːˑ()ʲ])(ʲ?[ːˑ()]*[‿⁀]*[' .. vow .. acc .. '])', function(a, b, c, d)
			if perm_syl_onset[a .. b .. c] or c == 'j' and rfind(b, '[čǰɕӂʲ]') then
				return '@' .. a .. b .. c .. d
			elseif perm_syl_onset[b .. c] then
				return a .. '@' .. b .. c .. d
			end end)
		--6. remove @ followed by a final consonant cluster
		pron = rsub(pron, '@([^‿⁀@' .. vow .. ']+⁀)$', '%1')
		--7. make sure @ isn't directly before linking ‿⁀
		pron = rsub(pron, '@([‿⁀]+)', '%1@')

		--if / is present (explicit syllable boundary), remove any @
		--(automatic boundary) and convert / to @
		if rfind(pron, '/') then
			pron = rsub(pron, '[^' .. vow .. acc .. ']+', function(x)
				if rfind(x, '/') then
					x = rsub(x, '@', '')
					x = rsub(x, '/', '@')
				end
				return x
			end)
		end

		-- handle word-initial unstressed o and a; note, vowels always
		-- followed by at least one char because of word-final ⁀
		-- do after syllabification because syllabification doesn't know
		-- about ɐ as a vowel
		pron = rsub(pron, '^⁀[ao]([^' .. acc .. '])', '⁀ɐ%1')

		--split by syllable
		local syllable = rsplit(pron, '@', true)

		--create set of 1-based syllable indexes of stressed syllables
		--(acute, grave, circumflex)
		local stress = {}
		for j = 1, #syllable do
			if rfind(syllable[j], accents) then
				stress[j] = true
			end
		end

		-- iterate syllable by syllable to handle stress marks, vowel allophony
		local syl_conv = {}
		for j = 1, #syllable do
			local syl = syllable[j]

			local alnum

			--vowel allophony
			if stress[j] then
				-- convert acute/grave/circumflex accent to appropriate
				-- IPA marker of primary/secondary/unmarked stress
				alnum = 1
				syl = rsub(syl, '(.*)́', 'ˈ%1')
				syl = rsub(syl, '(.*)̀', 'ˌ%1')
				syl = rsub(syl, CFLEX, '')
			elseif stress[j+1] then
				alnum = 2
			else
				alnum = 3
			end
			syl = rsub(syl, vowels_c, function(a)
				if a ~= '' then
					return allophones[a][alnum]
				end end)
			syl_conv[j] = syl
		end

		pron = table.concat(syl_conv, "")

		-- Optional (j) before ɪ, which is always unstressed
		pron = rsub(pron, "⁀jɪ", "⁀(j)ɪ")
		pron = rsub(pron, '([' .. ipa_vow .. '])jɪ', "%1(j)ɪ")

		--consonant assimilative palatalization of tn/dn, depending on
		--whether [rl] precedes
		pron = rsub(pron, '([rl]?)([ˈˌ]?[dt])([ˈˌ]?nʲ)', function(a, b, c)
			if a == '' then
				return a .. b .. 'ʲ' .. c
			else
				return a .. b .. '⁽ʲ⁾' .. c
			end end)

		--general consonant assimilative palatalization
		pron = rsub_repeatedly(pron, '([szntdpbmfcĵx])([ˈˌ]?)([szntdpbmfcĵlk]ʲ)', function(a, b, c)
			if cons_assim_palatal['compulsory'][a..c] then
				return a .. 'ʲ' .. b .. c
			elseif cons_assim_palatal['optional'][a..c] then
				return a .. '⁽ʲ⁾' .. b .. c
			else
				return a .. b .. c
			end end)

		-- further assimilation before alveolopalatals
		pron = rsub(pron, 'n([ˈˌ]?)([čǰɕӂ])', 'nʲ%1%2')

		-- optional palatal assimilation of вп, вб only word-initially
		pron = rsub(pron, '⁀([ˈˌ]?[fv])([ˈˌ]?[pb]ʲ)', '⁀%1⁽ʲ⁾%2')

		-- optional palatal assimilation of бв but not in обв-
		pron = rsub(pron, 'b([ˈˌ]?vʲ)', 'b⁽ʲ⁾%1')
		if rfind(word[i], '⁀o' .. accents .. '?bv') then
			-- ə in case of a word with a preceding preposition
			pron = rsub(pron, '⁀([ˈˌ]?[ɐəo][ˈˌ]?)b⁽ʲ⁾([ˈˌ]?vʲ)', '⁀%1b%2')
		end

		if rfind(word[i], 'sä⁀') then
			pron = rsub(pron, 'sʲə⁀', 's⁽ʲ⁾ə⁀')
		end

		word[i] = pron
	end

	text = table.concat(word, " ")
	if bracket then
		text = '[' .. text .. ']'
	end

	-- Front a and u between soft consonants. If between a soft and
	-- optionally soft consonant (should only occur in that order, shouldn't
	-- ever have a or u preceded by optionally soft consonant),
	-- split the result into two. We only split into two even if there
	-- happen to be multiple optionally fronted a's and u's to avoid
	-- excessive numbers of possibilities (and it simplifies the code).
	-- 1. First, temporarily add soft symbol to inherently soft consonants.
	text = rsub(text, '([čǰɕӂj])', '%1ʲ')
	-- 2. Handle case of au between two soft consonants
	text = rsub(text, '(ʲ[ː()]*)([auʊ])([ˈˌ]?.ʲ)', function(a, b, c)
		return a .. fronting[b] .. c end)
	-- 3. Handle case of au between soft and optionally soft consonant
	if rfind(text, 'ʲ[ː()]*[auʊ][ˈˌ]?.⁽ʲ⁾') or rfind(text, 'ʲ[ː()]*[auʊ][ˈˌ]?%(jʲ%)') then
		opt_hard = rsub(text, '(ʲ[ː()]*)([auʊ])([ˈˌ]?.)⁽ʲ⁾', '%1%2%3')
		opt_hard = rsub(opt_hard, '(ʲ[ː()]*)([auʊ])([ˈˌ]?)%(jʲ%)', '%1%2%3')
		opt_soft = rsub(text, '(ʲ[ː()]*)([auʊ])([ˈˌ]?.)⁽ʲ⁾', function(a, b, c)
			return a .. fronting[b] .. c .. 'ʲ' end)
		opt_soft = rsub(opt_soft, '(ʲ[ː()]*)([auʊ])([ˈˌ]?)%(jʲ%)', function(a, b, c)
			return a .. fronting[b] .. c .. 'jʲ' end)
		text = opt_hard .. ', ' .. opt_soft
	end
	-- 4. Undo addition of soft symbol to inherently soft consonants.
	text = rsub(text, '([čǰɕӂj])ʲ', '%1')

	-- convert special symbols to IPA
	text = rsub(text, '[cĵ]ʲ', translit_conv_j)
	text = rsub(text, '[cčgĉĝĵǰšžɕӂ]', translit_conv)

	-- Assimilation involving hiatus of ɐ and ə
	text = rsub(text, 'ə([‿⁀]*)[ɐə]', 'ɐ%1ɐ')

	-- eliminate ⁀ symbol at word boundaries
	text = rsub(text, '⁀', '')

	if test_new_ru_pron_module then
		if new_module_result ~= text then
			--error(text .. " || " .. new_module_result)
			track("different-pron")
		end
	end

	return text
end

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
