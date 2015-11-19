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
   Should work with gem=y (see FIXME #1). Words with йе: фойе́, колба Эрленмейера,
   скала Айерс, Айерс-Рок, йети, Кайенна, конвейер, конвейерный, сайентология,
   фейерверк, Гава́йев. Note also Гава́йи with йи.
3. In асунсьо́н and Вьентья́н, put a syllable break after the н and before
   consonant + /j/. Use the perm_sym_onset mechanism or at least the code
   that accesses that mechanism. Should possibly do this also in VCʲj and
   V‿Cʲj and VCj and V‿Cj sequences; ask Cinemantique if this makes sense.
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
15a. Add test cases: фуррь, по абе́д (for assimilation of schwas across ‿,
    CHECK THIS IS A WORD)
15b. Add test case англо-норма́ннский (to make sure degemination of нн occurs
    not between vowels), multi-syllable word ending in a geminate: ато́лл
	(not so good because лл always degeminated), коло́сс, Иоа́нн (good because
	of нн), ха́ос, эвфеми́зм, хору́гвь (NOTE: ruwikt claims гв is voiced, I
	doubt it, ask Cinemantique), наря́д на ку́хню (non-devoicing of д before
	н in next word, ask Cinemantique about this, does it also apply to мрл?),
	ко̀е-кто́
16. Caused a change in ко̀е-кто́, perhaps because I rewrote code that accepted
    an acute or circumflex accent to also take a grave accent. See how
	кое is actually pronounced here and take action if needed. (ruwiki claims
	кое is indeed pronounced like кои, ask Cinemantique what the rule for
	final -е is and why different in кое vs. мороженое, anything to do with
	secondary stress on о?)
17. (DONE, NEEDS CHECKING, CHECK эвфеми́зм) Rewrote voicing/devoicing
    assimilation; should make assimilation of эвфеми́зм automatic and not
	require phon=.
18. (DONE, NEEDS TESTING) Removed redundant fronting-of-a code near end;
    make sure this doesn't change anything.
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
local CFLEX = u(0x0302) -- circumflex =  ̂
local TILDE = u(0x0303) -- tilde  ̃

local vow = 'aeiouyɛəäëöü'
local ipa_vow = vow .. 'ɐɪʊɨæɵʉ'
local vowels, vowels_c = '[' .. vow .. ']', '([' .. vow .. '])'
local non_vowels, non_vowels_c = '[^' .. vow .. ']', '([^' .. vow .. '])'
local acc = AC .. GR .. CFLEX .. TILDE
local accents = '[' .. acc .. ']'
local non_accents = '[^' .. acc .. ']'

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
	['ä'] = { 'æ', 'ɪ', 'ɪ' },
	['ë'] = { 'e', 'ɪ', 'ɪ' },
	['ö'] = { 'ɵ', 'ɪ', 'ɪ' },
	['ü'] = { 'ʉ', 'ʉ', 'ʉ' },
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
	{'[szšž]ː', 's'},
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
	-- vowel changes after always-hard or always-soft consonants
	{vowels_c .. '([šž])j([ou])', '%1%2%3'},
	{vowels_c .. '([šžc])e', '%1%2ɛ'},
	{vowels_c .. '([šžc])i', '%1%2y'},
	{'([čǰӂ])([aou])', '%1j%2'},

	-- the following eight are ordered before changes that affect ts
	-- FIXME!!! Should these next fouralso pay attention to grave accents?
	{'́tʹ?sja$', '́cca'},
	{'́tʹ?sja([ %-‿])', '́cca%1'},
	{'([^́])tʹ?sja$', '%1ca'},
	{'([^́])tʹ?sja([ %-‿])', '%1ca%2'},
	{'n[dt]sk', 'n(t)sk'},
	{'s[dt]sk', 'sck'},
	-- the following is ordered before the next one, which applies assimilation
	-- of [тд] to щ
	{'n[dt]šč', 'nšč'},
	-- the following is for отсчи́тываться and подсчёт
	{'[cdt][sš]č', 'čšč'},

	-- main changes for affricate assimilation of [dt] + sibilant, including ts;
	-- we either convert to "short" variants t͡s, d͡z, etc. or to "long" variants
	-- t͡ss, d͡zz, etc.
	-- 1. т с, д з across word boundary, also т/с, д/з with explicitly written
	--    slash, use long variants.
	{'[dt](ʹ?[ %-‿/])s', 'c%1s'},
	{'[dt](ʹ?[ %-‿/])z', 'ĵ%1z'},
	-- 2. тс, дз + vowel use long variants.
	{'[dt](ʹ?)s(j?' .. vowels .. ')', 'c%1s%2'},
	{'[dt](ʹ?)z(j?' .. vowels .. ')', 'ĵ%1z%2'},
	-- 3. тьс, дьз use long variants.
	{'[dt]ʹs', 'cʹs'},
	{'[dt]ʹz', 'ĵʹz'},
	-- 4. word-initial от[сз]-, под[сз]- use long variants because there is
	--    a morpheme boundary.
	{'^(o' .. accents .. '?)t([sz])', ot_pod_sz},
	{'([ %-‿]o' .. accents .. '?)t([sz])', ot_pod_sz},
	{'^(po' .. accents .. '?)d([sz])', ot_pod_sz},
	{'([ %-‿]po' .. accents .. '?)d([sz])', ot_pod_sz},
	-- 5. other тс, дз use short variants.
	{'[dt]s', 'c'},
	{'[dt]z', 'ĵ'},
	-- 6. тш, дж always use long variants (FIXME, may change)
	{'[dt](ʹ?[ %-‿/]?)š', 'ĉ%1š'},
	{'[dt](ʹ?[ %-‿/]?)ž', 'ĝ%1ž'},

	-- changes for assimilation of [dt] + affricate
	{'[sz][dt]c', 'sc'},
	{'([rn])[dt]([cč])', '%1%2'},
	{'[dt]([cč])', '%1%1'},

	{'stg', 'sg'},

	{'sverxi', 'sverxy'},
	{'stʹd', 'zd'},
	{'tʹd', 'dd'},

	{'zdn', 'zn'},
	{'lnc', 'nc'},
	{'[sz]t([ln])', 's%1'},
	{'ščč', 'ɕč'},
	-- зч and жч become щ, as does сч at the beginning of a word and
	-- in the sequence счёт; else сч becomes ɕč, as щч always does
	{'[zž]č', 'šč'},
 	{'[szšž]šč', 'šč'},
 	{'^sč', 'šč'},
	{'([ %-‿])sč', '%1šč'},
 	{'sčjo(' .. accents .. '?)t', 'ščjo%1t'},
 	{'sč', 'ɕč'},
	{'[zs]([ %-‿/]?)š', 'š%1š'},
	{'[zs]([ %-‿/]?)ž', 'ž%1ž'},
	{'nnsk', 'nsk'},
	{'gk', 'xk'},
	{'n[dt]g', 'ng'},

	{'šč', 'ɕː'}, -- conversion of šč to geminate
	{'([bdkstvxzž])‿i', '%1‿y'}, -- backing of /i/ after certain prepositions
	{'ʹo', 'ʹjo'}, -- ьо is pronounced as (possibly unstressed) ьё
}

local cons_assim_palatal = {
	-- assimilation of tn, dn, nč, nɕ is handled specially
	compulsory = ut.list_to_set({'stʲ', 'zdʲ', 'ntʲ', 'ndʲ', 'csʲ', 'ĵzʲ',
		'ncʲ', 'nĵʲ'}),
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

local function ine(x)
	return x ~= "" and x or nil
end

local function track(page)
	local m_debug = require("Module:debug")
	m_debug.track("ru-pron/" .. page)
	return true
end

function export.ipa(text, adj, gem)
	local new_module_result
	-- Test code to compare existing module to new one.
	if test_new_ru_pron_module then
		local m_new_ru_pron = require("Module:User:Benwing2/ru-pron")
		new_module_result = m_new_ru_pron.ipa(text, adj, gem)
	end

	if type(text) == 'table' then
		text, adj, gem = (ine(text.args.phon) or ine(text.args[1])), ine(text.args.adj), ine(text.args.gem)
		if not text then
			text = mw.title.getCurrentTitle().text
		end
	end
	gem = usub(gem or '', 1, 1)
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

	-- translit doesn't always convert э to ɛ (depends on whether a consonant
	-- precedes), so do it ourselves before translit
	text = rsub(text, 'э', 'ɛ')
	-- vowel + йе should have double jj, but the translit module will translit
	-- it the same as vowel + е, so do it ourselves before translit
	text = rsub(text, '([' .. com.vowel .. ']' .. com.opt_accent .. ')йе', '%1jje')
	-- transliterate and decompose acute, grave, circumflex, tilde Latin vowels
	text = com.translit(text)

	-- handle old ě (e.g. сѣдло́), and ě̈ from сѣ̈дла
	text = rsub(text, 'ě̈', 'jo' .. AC)
	text = rsub(text, 'ě', 'e')
	-- handle sequences of accents (esp from ё with secondary/tertiary stress)
	text = rsub(text, accents .. '+(' .. accents .. ')', '%1')

	text = adj and rsub(text, '(.[aoe]́?)go(' .. AC .. '?)$', '%1vo%2') or text
	text = adj and rsub(text, '(.[aoe]́?)go(' .. AC .. '?)sja$', '%1vo%2sja') or text
	text = adj and rsub(text, '(.[aoe]́?)go(' .. AC .. '?) ', '%1vo%2 ') or text
	text = adj and rsub(text, '(.[aoe]́?)go(' .. AC .. '?)sja ', '%1vo%2sja ') or text

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
			ulen(rsub(word[i], non_vowels, '')) == 1 and
			rsub(word[i], non_accents, '') == '' then
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
			word[i-1] = ''
		end
	end

	-- rejoin words, convert hyphens to spaces and eliminate stray spaces
	-- resulting from this
	text = table.concat(word, "")
	text = rsub(text, '[%-%s]+', ' ')
	text = rsub(text, '^ ', '')
	text = rsub(text, ' $', '')

	-- eliminate tildes, which have served their purpose of preventing any
	-- sort of stress
	text = rsub(text, TILDE, '')

	-- convert commas and en/en dashes to IPA foot boundaries
	text = rsub(text, '%s*[,–—]%s*', ' | ')

	-- save original word spelling before respellings, (de)voicing changes,
	-- geminate changes, etc. for implementation of geminate_pref
	local orig_word = rsplit(text, " ", true)

	--phonetic respellings
	for _, respell in ipairs(phon_respellings) do
		text = rsub(text, respell[1], respell[2])
	end

	--voicing, devoicing
	--1. absolutely final devoicing
	text = rsub(text, '([bdgvɣzžĝĵǰӂ])(ʹ?)$', function(a, b)
		return devoicing[a] .. b end)
	--2. word-final devoicing before another word
	text = rsub(text, '([bdgvɣzžĝĵǰӂ])(ʹ? [^bdgvɣzžĝĵǰӂn])', function(a, b)
		return devoicing[a] .. b end)
	--3. voicing/devoicing assimilation; repeat to handle recursive assimilation
	while true do
		local new_text = rsub(text, '([bdgvɣzžĝĵǰӂ])([ %-%‿ʹ%ː()/]*[ptkfxsščɕcĉ])', function(a, b)
			return devoicing[a] .. b end)
		new_text = rsub(new_text, '([ptkfxsščɕcĉ])([ %-%‿ʹ%ː()/]*[bdgɣzžĝĵǰӂ])', function(a, b)
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
	text = rsub(text, '([^' .. vowel .. acc .. 'ʹʺ‿ ]/?)j([äëöü])', '%1%2')

	--split by word and process each word
	word = rsplit(text, " ", true)
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
				if rfind(orig_deac, '^' .. oldspell) and rfind(deac, '^' .. newspell) or
					rfind(orig_deac, '^ne' .. oldspell) and rfind(deac, '^ne' .. newspell) then
					pron = rsub(pron, '^([^‿ː]*)ː', '%1ˑ')
				end
				-- FIXME! Here we check across joined ‿ boundaries; but the rsub below
				-- could be incorrect if there is gemination in a joined preposition
				-- or particle
				if rfind(orig_deac, '‿' .. oldspell) and rfind(deac, '‿' .. newspell) or
					rfind(orig_deac, '‿ne' .. oldspell) and rfind(deac, '‿ne' .. newspell) then
					pron = rsub(pron, '‿([^‿ː]*)ː', '‿%1ˑ')
				end
			end
		end

		--degemination, optional gemination
		if gem == 'y' then
			-- leave geminates alone, convert ˑ to regular gemination; ˑ is a
			-- special gemination symbol used at prefix boundaries that we
			-- remove only when gem=n, else we convert it to regular gemination
			pron = rsub(pron, 'ˑ', 'ː')
		elif gem == 'o' then
			-- make geminates optional, except for ɕӂ, also ignore left paren
			-- in (ː) sequence
			pron = rsub(pron, '([^ɕӂ%(%)])[ːˑ]', '%1(ː)')
		elif gem == 'n' then
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
			pron = rsub(pron, '(' .. vowels .. accents .. 's)ːk', '%1ˑk')
			-- 5. eliminate remaining gemination
			pron = rsub(pron, '([^ɕӂ%(%)])ː', '%1')
			-- 6. convert special gemination symbol ˑ to regular gemination
			pron = rsub(pron, 'ˑ', 'ː')
		end

		-- assimilative palatalization of consonants when followed by
		-- front vowels or soft sign; we include ə here because it should
		-- occur only word-finally from front äeë; note that retraction of
		-- е and и before цшж was done above in phon_respellings
		pron = rsub(pron, '([mnpbtdkgcĵfvszxɣrl])([ː()]*[eiəäëöüʹ])', '%1ʲ%2')

		-- FIXME! There was some more complex logic here that may cause
		-- final e, ë after a vowel in certain cases to be left as is,
		-- eventually resulting in ɪ, e.g. in ко̀е with secondary stress.
		-- We may need something here if this is correct.

		-- reduction of word-final a, e
		pron = rsub(pron, '[äeë]$', 'ə')
		-- insert j before i when required
		pron = rsub(pron, 'ʹi', 'ʹji')
		-- insert glottal stop after hard sign if required
		pron = rsub(pron, 'ʺ([aɛiouy])', 'ʔ%1')

		--syllabify, inserting @ at syllable boundaries
		--1. insert @ after each vowel
		pron = rsub(pron, '(' .. vowels .. accents .. '?)', '%1@')
		--2. eliminate word-final @
		pron = rsub(pron, '@+$', '')
		--3. in a consonant cluster, move @ forward so it's before the
		--   last consonant
		pron = rsub(pron, '@([^@' .. vow .. ']*)([^‿@' .. vow .. 'ʹːˑ()ʲ])(ʹ?ʲ?[ːˑ()]*‿?[' .. vow .. '])', '%1@%2%3')
		--4. move @ backward if in the middle of a "permanent onset" cluster,
		--   e.g. sk, str, that comes before a vowel, putting the @ before
		--   the permanent onset cluster
		pron = rsub(pron, '([^‿@' .. vow .. ']?)([^‿@' .. vow .. '])@([^‿@' .. vow .. 'ʹːˑ()ʲ])(ʹ?ʲ?[ːˑ()]*‿?[' .. vow .. '])', function(a, b, c, d)
			if perm_syl_onset[a .. b .. c] then
				return '@' .. a .. b .. c .. d
			elseif perm_syl_onset[b .. c] then
				return a .. '@' .. b .. c .. d
			end end)
		--5. remove @ followed by a final consonant cluster
		pron = rsub(pron, '@([^‿@' .. vow .. ']+)$', '%1')
		--6. make sure @ isn't directly before linking ‿
		pron = rsub(pron, '@‿', '‿@')

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

			--vowel allophony
			-- second clause in if-statement handles words like Токио and хаос
			if stress[j] or (j == #syllable and j > 1 and rfind(syllable[j-1] .. syllable[j], '[aieäëü]' .. accents .. '?o')) then
				-- convert acute/grave/circumflex accent to appropriate
				-- IPA marker of primary/secondary/unmarked stress
				syl = rsub(syl, '(.*)́', 'ˈ%1')
				syl = rsub(syl, '(.*)̀', 'ˌ%1')
				syl = rsub(syl, '(.*)̂', '%1')
				syl = rsub(syl, '([ʲčǰɕӂ][ː()]*)o', '%1ö')
				syl = rsub(syl, vowels_c, function(a)
					if a ~= '' then
						return allophones[a][1]
					end end)

			else
				if stress[j+1] or (j == 1 and rfind(syl, '^' .. vowels)) then
					syl = rsub(syl, vowels_c, function(a)
						if a ~= '' then
							return allophones[a][2]
						end end)

				else
					syl = rsub(syl, vowels_c, function(a)
						if a ~= '' then
							return allophones[a][3]
						end end)
				end
			end
			syl_conv[j] = syl
		end

		pron = table.concat(syl_conv, "")

		pron = rsub(pron, "[ʹʺ]", "")

		-- Optional (j) before ɪ
		pron = rsub(pron, "^jɪ", "(j)ɪ")
		pron = rsub(pron, '([' .. ipa_vow .. '][‿%-]?)jɪ', "%1(j)ɪ")

		--consonant assimilative palatalization of tn/dn, depending on
		--whether [rl] precedes
		pron = rsub(pron, '([rl]?)([ˈˌ]?[dt])([ˈˌ]?nʲ)', function(a, b, c)
			if a == '' then
				return a .. b .. 'ʲ' .. c
			else
				return a .. b .. '⁽ʲ⁾' .. c
			end end)

		--general consonant assimilative palatalization
		pron = rsub_repeatedly(pron, '([szntdpbmfcĵ])([ˈˌ]?)([lszntdpbmfcĵ]ʲ)', function(a, b, c)
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
		pron = rsub(pron, '^([ˈˌ]?[fv])([ˈˌ]?[pb]ʲ)', '%1⁽ʲ⁾%2')

		-- optional palatal assimilation of бв but not in обв-
		pron = rsub(pron, 'b([ˈˌ]?vʲ)', 'b⁽ʲ⁾%1')
		if rfind(word[i], '^o' .. accents .. '?bv') then
			-- exclude ^abv- (if it occurs)
			pron = rsub(pron, '^([ˈˌ]?[ɐo][ˈˌ]?)b⁽ʲ⁾([ˈˌ]?vʲ)', '%1b%2')
		end

		if rfind(word[i], 'sä$') then
			pron = rsub(pron, 'sʲə$', 's⁽ʲ⁾ə')
		end

		word[i] = pron
	end

	text = table.concat(word, " ")

	-- convert special symbols to IPA
	text = rsub(text, '[cĵ]ʲ', translit_conv_j)
	text = rsub(text, '[cčgĉĝĵǰšžɕӂ]', translit_conv)

	-- Assimilation involving hiatus of ɐ and ə
	text = rsub(text, 'ə([‿%-]?)[ɐə]', 'ɐ%1ɐ')

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
