--[[
This module implements the template {{ru-IPA}} (FIXME, is it called elsewhere?)

Author: Wyang; significantly modified by Benwing, with help from Atitarev and a bit from others

FIXME:

1. Geminated /j/ from -йя-: treat as any other gemination, meaning it may
   not always be pronounced geminated. Currently we geminate it very late,
   after all the code that reduces geminates. Should be done earlier and
   places that include regexps with /j/ should be modified to also include
   the gemination marker ː.
2. In асунсьо́н and Вьентья́н, put a syllable break after the н and before
   consonant + /j/. Use the perm_sym_onset mechanism or at least the code
   that accesses that mechanism.
3. Should have geminated jj in йе (occurs in e.g. фойе́). Should work with
   gem=y (seee FIXME #1).
4. Fix non-palatal е in льстец.
5. In львёнок, rendered as ˈlʲvɵnək instead of ˈlʲvʲɵnək. Might be same
   issue as льстец, having to do with ь in beginning.
6. In prefixes/suffixes like -ин, treat single syllable as unstressed.
7. (DONE) In ни́ндзя, дз becomes palatal and н should palatal-assimilate to it.
8. In собра́ние, Anatoli renders it as sɐˈbranʲɪ(j)ə with optional (j).
   Ask him when this exactly applies.
9. In под сту́лом, should render as pɐt͡s‿ˈstuləm when actually renders as
   pɐˈt͡s‿stuləm. Also occurs in без ша́пки (bʲɪˈʂ‿ʂapkʲɪ instead of
   bʲɪʂ‿ˈʂapkʲɪ); has something to do with ‿. Similarly occurs in
   не к ме́сту, which should render as nʲɪ‿k‿ˈmʲestʊ.
10. убе́жищa renders as ʊˈbʲeʐɨɕːʲə instead of ʊˈbʲeʐɨɕːə;
   уда́ча similarly becomes ʊˈdat͡ɕʲə instead of ʊˈdat͡ɕə.
11. тро́лль renders with geminated final l, and with ʲ on wrong side of
   gemination (ːʲ instead of ʲː); note how this also occurs above in -ɕːʲə
   from убе́жищa. (This issue with тро́лль will be masked by the change to
   generally degeminate l; might need example with final -ннь, if it exists.)
12. May be additional errors with gemination in combination with explicit
    / syllable boundary, because of the code expecting that syllable breaks
	occur in certain places; should probably rewrite the whole gemination code
	to be less fragile and not depend on exactly where syllable breaks
	occur in consonant clusters, which it does now (might want to rewrite
	to avoid the whole business of breaking by syllable and processing
	syllable-by-syllable).
13. Many assimilations won't work properly with an explicit / syllable
   boundary.
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

local vow = 'aeiouyɛəäëöü'
local ipa_vow = vow .. 'ɐɪʊɨæɵʉ'
local vowels, vowels_c = '[' .. vow .. ']', '([' .. vow .. '])'
local non_vowels, non_vowels_c = '[^' .. vow .. ']', '([^' .. vow .. '])'
local ipa_vowels, ipa_vowels_c = '[' .. ipa_vow .. ']', '([' .. ipa_vow .. '])'
local acc = AC .. GR .. CFLEX
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

	['bʲ'] = 'pʲ', ['dʲ'] = 'tʲ',
	['zʲ'] = 'sʲ', ['vʲ'] = 'fʲ',
	['žʲ'] = 'šʲ'
}

local voicing = {
	['p'] = 'b', ['t'] = 'd', ['k'] = 'g',
	['s'] = 'z', ['f'] = 'v',
	['š'] = 'ž', ['c'] = 'ĵ', ['č'] = 'ǰ', ['ĉ'] = 'ĝ',
	['x'] = 'ɣ', ['ɕ'] = 'ӂ'
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
	-- 4. word-initial отс-, подс- use long variants because there is
	--    a morpheme boundary.
	{'^ots', 'ocs'},
	{'([ %-‿])ots', '%1ocs'},
	{'^pods', 'pocs'},
	{'([ %-‿])pods', '%1pocs'},
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

function export.ipa(text, adj, gem, pal)
	local new_module_result
	-- Test code to compare existing module to new one.
	if test_new_ru_pron_module then
		local m_new_ru_pron = require("Module:User:Benwing2/ru-pron")
		new_module_result = m_new_ru_pron.ipa(text, adj, gem, pal)
	end

	if type(text) == 'table' then
		text, adj, gem, pal = (ine(text.args.phon) or ine(text.args[1])), ine(text.args.adj), ine(text.args.gem), ine(text.args.pal)
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
	if pal == 'y' then
		track("pal")
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

	-- translit will not respect э vs. е difference so we have to
	-- do it ourselves before translit
	text = rsub(text, 'э', 'ɛ')
	-- transliterate and decompose acute and grave Latin vowels
	text = com.translit(text)

	-- handle old ě (e.g. сѣдло́), and ě̈ from сѣ̈дла
	text = rsub(text, 'ě̈', 'jo' .. AC)
	text = rsub(text, 'ě', 'e')
	-- handle ё with secondary/tertiary stress
	text = rsub(text, AC .. '([̀̂])', '%1')

	text = adj and rsub(text, '(.[aoe]́?)go(' .. AC .. '?)$', '%1vo%2') or text
	text = adj and rsub(text, '(.[aoe]́?)go(' .. AC .. '?)sja$', '%1vo%2sja') or text
	text = adj and rsub(text, '(.[aoe]́?)go(' .. AC .. '?) ', '%1vo%2 ') or text
	text = adj and rsub(text, '(.[aoe]́?)go(' .. AC .. '?)sja ', '%1vo%2sja ') or text

	-- Add primary stress to single-syllable words preceded or followed by
	-- unstressed particle or preposition. Make remaining single-syllable
	-- words that aren't a particle or preposition have "unmarked" stress
	-- (treated as stressed but without a primary or secondary stress marker;
	-- we repurpose a circumflex for this purpose). We need to preserve the
	-- distinction between spaces and hyphens because we only recognize
	-- certain post-accentless particles following a dash (to distinguish e.g.
	-- 'то' from '-то').
	local word = strutils.capturing_split(text, "([ %-]+)")
	for i = 1, #word do
		if not accentless['prep'][word[i]] and not (i > 2 and accentless['post'][word[i]]) and not (i > 2 and accentless['posthyphen'][word[i]] and word[i-1] == "-") and
			ulen(rsub(word[i], non_vowels, '')) == 1 and
			rsub(word[i], non_accents, '') == '' then
			if (i > 2 and accentless['prep'][word[i-2]] or i < #word - 1 and accentless['post'][word[i+2]] or i < #word - 1 and word[i+1] == "-" and accentless['posthyphen'][word[i+2]]) then
				word[i] = rsub(word[i], vowels_c, '%1' .. AC)
			else
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
	text = table.concat(word, "")
	text = rsub(text, '%-', ' ')
	text = rsub(text, '%s+', ' ')
	text = rsub(text, '^ ', '')
	text = rsub(text, ' $', '')
	
	-- convert commas to IPA foot boundaries
	text = rsub(text, '%s*,%s+', ' | ')

	-- save original word spelling before respellings, (de)voicing changes,
	-- geminate changes, etc. for implementation of geminate_pref
	local orig_word = rsplit(text, " ", true)

	--phonetic respellings
	for _, respell in ipairs(phon_respellings) do
		text = rsub(text, respell[1], respell[2])
	end

	-- conversion of šč to geminate
	text = rsub(text, 'šč', 'ɕː')
	-- backing of /i/ after certain prepositions
	text = rsub(text, '([bdkstvxzž])‿i', '%1‿y')
	-- ьо is pronounced as (possibly unstressed) ьё, I think
	text = rsub(text, 'ʹo', 'ʹjo')

	--rewrite iotated vowels
	text = rsub(text, 'j[aeou]', {
		['ja'] = 'ä',
		['je'] = 'ë',
		['jo'] = 'ö',
		['ju'] = 'ü'})

	--voicing/devoicing assimilations
	text = rsub(text, '([bdgvɣzžĝĵǰӂ]+)([ %-%‿%ː()]*[ptkxsščɕcĉ])', function(a, b)
		return rsub(a, '.', devoicing) .. b end)
	text = rsub(text, '([ptkfxsščɕcĉ]+)([ %-%‿ʹ%ː()]*[bdgɣzžĝĵǰӂ])', function(a, b)
		return rsub(a, '.', voicing) .. b end)

	--re-notate orthographic geminate consonants
	text = rsub(text, '([^' .. vow .. '.%-_])' .. '%1', '%1ː')
	text = rsub(text, '([^' .. vow .. '.%-_])' .. '%(%1%)', '%1(ː)')

	--split by word and process each word
	word = rsplit(text, " ", true)
	for i = 1, #word do
		local syllable = {} -- list of syllables
		local stress = {} -- set of 1-based indices of stressed syllables
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

		--optional iotation of 'e' in a two-vowel sequence and reduction of
		--word-final 'e'; FIXME: Should this also include grave accent?
		pron = rsub(pron, '([' .. vow .. '][́̂]?)ë([^́̂])', '%1(j)ë%2')
		pron = rsub(pron, 'e$', 'ə')
		pron = rsub(pron, '([' .. vow .. 'ʹ])([́̂]?)[äë]$', '%1%2jə')
		pron = rsub(pron, non_vowels_c .. 'ä$', '%1ʲə')
		pron = rsub(pron, '%(j%)jə', 'jə')

		-- insert /j/ before front vowels when required
		pron = rsub(pron, '([ʹʺ])([äëöü])', '%1j%2')
		pron = rsub(pron, 'ʹi', 'ʹji')
		pron = rsub(pron, '‿([äëöü])', '‿j%1')
		pron = rsub(pron, '^([äëöü])', 'j%1')
		pron = rsub(pron, '(' .. vowels .. accents .. '?)([äëöü])', '%1j%2')
		-- need to do this twice in words like вою́ю where two j's need to be
		-- inserted in successive syllables
		pron = rsub(pron, '(' .. vowels .. accents .. '?)([äëöü])', '%1j%2')
		-- insert glottal stop after hard sign if required
		pron = rsub(pron, 'ʺ([aɛiouy])', 'ʔ%1')

		--syllabify, inserting @ at syllable boundaries
		pron = rsub(pron, '(' .. vowels .. accents .. '?)', '%1@')
		pron = rsub(pron, '@+$', '')
		pron = rsub(pron, '@([^‿@' .. vow .. ']*)([^‿@' .. vow .. 'ʹːˑ()ʲ])(ʹ?ʲ?[ːˑ()]*[' .. vow .. '])', '%1@%2%3')
		pron = rsub(pron, '([^‿@' .. vow .. ']?)([^‿@' .. vow .. '])@([^‿@' .. vow .. 'ʹːˑ()ʲ])(ʹ?ʲ?[ːˑ()]*[' .. vow .. '])', function(a, b, c, d)
			if perm_syl_onset[a .. b .. c] then
				return '@' .. a .. b .. c .. d
			elseif perm_syl_onset[b .. c] then
				return a .. '@' .. b .. c .. d
			end end)
		pron = rsub(pron, '@([^‿@' .. vow .. ']+)$', '%1')
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

		--write 1-based syllable indexes of stressed syllables (acute or grave) to
		--the list POS
		local pos = {}

		local trimmed_pron = pron
		local count = 0
		while rfind(trimmed_pron, accents) do
			local accent_pos = rfind(trimmed_pron, accents)
			count = count + ulen(rsub(usub(trimmed_pron, 1, accent_pos - 1), '[^%@]', ''))
			table.insert(pos, count + 1)
			trimmed_pron = usub(trimmed_pron, accent_pos + 1, -1)
		end

		--split by syllable
		syllable = rsplit(pron, '@', true)

		--convert list of stress positions to set; equivalent to ut.list_to_set()
		for _, pos in ipairs(pos) do
			stress[pos] = true
		end

		local syl_conv = {}
		for j = 1, #syllable do
			local syl = syllable[j]

			--remove consonant geminacy if non-initial and non-post-tonic
			if rfind(syl, 'ː') and not rfind(syl, '%(ː%)') and gem ~= 'y' then
				-- logic to determine whether to apply changes
				local no_replace = false
				local replace_opt = false
				if (j == 1 and not rfind(syl, 'ː$')) or stress[j-1] then
					no_replace = true
				elseif stress[j] and rfind(syl, 'sː$') and j < #syllable and rfind(syllable[j+1], 'k' .. vowels) then
					-- special case for ssk and zsk
					no_replace = true
				end
				if gem == 'n' then
					no_replace = false
				elseif gem == 'o' then
					no_replace = false
					replace_opt = true
				end
				-- if changes need applying, then apply; but don't affect
				-- ɕɕ or ӂӂ under any circumstances, and only affect žž and nn
				-- if gem=n or gem=opt
				if not no_replace then
					syl = rsub(syl, '([^ɕӂžn])ː', replace_opt and '%1(ː)' or '%1')
					if gem == 'n' then
						syl = rsub(syl, '([žn])ː', '%1')
					elseif gem == 'o' then
						syl = rsub(syl, '([žn])ː', '%1(ː)')
					end
				end
			end
			-- ˑ is a special gemination symbol used at prefix boundaries that
			-- we remove only when gem=n, else we convert it to regular
			-- gemination
			if rfind(syl, 'ˑ') then
				syl = rsub(syl, 'ˑ', gem == 'n' and '' or gem == 'o' and '(ː)' or 'ː')
			end
			-- remove all geminacy of l unless gem=y or gem=opt
			if gem ~= 'y' and gem ~= 'o' then
				syl = rsub(syl, 'lː', 'l')
			end

			--assimilative palatalisation of consonants when followed by front vowels
			-- FIXME: I don't understand this code very well (Benwing)
			if pal == 'y' or rfind(syl, '^[^cĵĉĝšžaäeëɛiyoöuü]*[eiəäëöüʹ]') or rfind(syl, '^[cĵĉĝšž][^cĵĉĝšžaäeëɛiyoöuüː()]+[eiəäëöüʹ]') or rfind(syl, '^[cĵ][äëü]') then
				if not rfind(syl, 'ʺ.*' .. vowels) and not rfind(syl, 'ʹ' .. non_vowels .. '.*' .. vowels) then
					syl = rsub(syl, non_vowels_c .. '([ʹː()j]*[' .. vow .. 'ʹ])', function(a, b)
						local set = '[mnpbtdkgcfvszxrl]'
						if pal == 'y' then
							set = '[mnpbtdkgcfvszxrlɕӂšž]'
						end
						set = '(' .. set .. ')'
						return rsub(a, set, '%1ʲ') .. b end)
				end
			end

			-- palatalization by soft sign
			syl = rsub(syl, '(.?[ː()]*)ʹ', function(a)
				if rfind(a, '[čǰšžɕ]') then
					return a
				elseif a ~= 'ʲ' then
					return a .. 'ʲ'
				else
					return 'ʲ'
				end end)

			--retraction of front vowels in syllables blocking assimilative palatalisation
			if not rfind(syl, 'ʲ[ː()]*' .. vowels) and not rfind(syl, '[čǰɕӂ][ː()]*[ei]') and not rfind(syl, '^j?i') then
				syl = rsub(syl, '[ei]', {['e'] = 'ɛ', ['i'] = 'y'})
			end

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
		pron = rsub(pron, ipa_vowels_c .. "([‿%-]?)jɪ", "%1%2(j)ɪ")

		--consonant assimilative palatalisation of tn/dn, depending on
		--whether [rl] precedes
		pron = rsub(pron, '([rl]?)([ˈˌ]?[dt])([ˈˌ]?nʲ)', function(a, b, c)
			if a == '' then
				return a .. b .. 'ʲ' .. c
			else
				return a .. b .. '⁽ʲ⁾' .. c
			end end)

		--general consonant assimilative palatalisation
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

		--fronting of stressed 'a' between soft consonants
		--FIXME: This doesn't look correct, should actually check for non-vowels
		pron = rsub(pron, 'ˈ(..?.?)a(.?.?.?)', function(a, b)
			if rfind(a, '[ʲčǰɕӂ]') and (b == '' or rfind(b, '[ʲčǰɕӂ]')) then
				return 'ˈ' .. a .. 'æ' .. b
			end end)

		--final devoicing and devoicing assimilation
		--FIXME: This seems partly duplicative of assimilations above
		pron = rsub(pron, '([bdgvɣzžĝĵǰӂ]ʲ?)$', function(a)
			if not rfind(word[i+1] or '', '^[bdgvɣzžĝĵǰӂn]') then
				return devoicing[a]
			end end)
		pron = rsub(pron, '([bdgvɣzžĝĵǰӂ])(ʲ?[ %-%‿]?[ptkxsščɕcĉ])', function(a, b)
			return devoicing[a] .. b end)

		--make geminated n optional when after but not immediately after
		--the stress, unless gemination should be preserved; do the sub
		--repeatedly as long as we make changes, in case of multiple nn's
		if gem ~= 'y' then
			pron = rsub_repeatedly(pron, '(ˈ.-' .. ipa_vowels .. '.-' .. ipa_vowels .. '.-)nː', '%1n(ː)')
		end

		if rfind(word[i], 'sä$') then
			pron = rsub(pron, 'sʲə$', 's⁽ʲ⁾ə')
		end

		pron = rsub(pron, '[cĵ]ʲ', translit_conv_j)
		pron = rsub(pron, '[cčgĉĝĵǰšžɕӂ]', translit_conv)

		word[i] = pron
	end

	text = table.concat(word, " ")

	-- long vowels; FIXME, may not apply at all; might apply across hyphens
	-- but not spaces; but we don't currently preserve hyphens this far;
	-- FIXME: Test cases are inconsistent about whether to apply this
	--text = rsub(text, '[ɐə]([%-]?)ɐ(%l?)ˈ', '%1ɐː%2ˈ')
	--text = rsub(text, 'ə([%-]?)[ɐə]', '%1əː')

	-- Assimilation involving hiatus of ɐ and ə
	text = rsub(text, 'ə([%-]?)[ɐə]', 'ɐ%1ɐ')

	-- double consonants, in words like секвойя and майя; FIXME, this won't
	-- be correct if the preceding vowel is unstressed; we need to do this
	-- check before the code that handles geminates, and then make sure that
	-- any further code involving /j/ checks for the geminate marker ː
	text = rsub(text, 'jʲ', 'jː')

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
