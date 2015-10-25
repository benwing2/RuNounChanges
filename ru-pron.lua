--[[
This module implements the template {{ru-IPA}} (FIXME, is it called elsewhere?)

Author: Primarily Wyang, with help from Atitarev, Benwing and a bit from others

FIXME:

1. Geminated /j/ from -йя-: treat as any other gemination, meaning it may
   not always be pronounced geminated. Currently we geminate it very late,
   after all the code that reduces geminates. Should be done earlier and
   places that include regexps with /j/ should be modified to also include
   the gemination marker ː.
2. In асунсьо́н and Вьентья́н, put a syllable break after the н and before
   consonant + /j/. Use the perm_sym_onset mechanism or at least the code
   that accesses that mechanism.
3. Handling сск - it should reduce to ск in all cases except when gem=y;
   currently we always reduce it to ск

]]

local ut = require("Module:utils")
local com = require("Module:ru-common")
local m_ru_translit = require("Module:ru-translit")

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

-- If enabled, compare this module with new version of module to make
-- sure all pronunciations are the same. Eventually consider removing this;
-- but useful as new code is created.
local test_new_ru_pron_module = false

local AC = u(0x0301) -- acute =  ́
local GR = u(0x0300) -- grave =  ̀
local CFLEX = u(0x0302) -- circumflex =  ̂

local vowel_list = 'aeiouyɛəäëöü'
local ipa_vowel_list = vowel_list .. 'ɐɪʊɨæɵʉ'
local vowels, vowels_c = '[' .. vowel_list .. ']', '([' .. vowel_list .. '])'
local ipa_vowels, ipa_vowels_c = '[' .. ipa_vowel_list .. ']', '([' .. ipa_vowel_list .. '])'
local non_vowels, non_vowels_c = '[^' .. vowel_list .. ']', '([^' .. vowel_list .. '])'
local accents = '[' .. AC .. GR .. CFLEX .. ']'
local non_accents = '[^' .. AC .. GR .. CFLEX .. ']'

local perm_syl_onset = ut.list_to_set({
	'str', 'sp', 'st', 'sk', 'sf', 'sx', 'sc',
	'pr', 'kr', 'fr', 'xr',
	'pl', 'tl', 'kl', 'gl', 'fl', 'xl',
	'ml', 'mn',
	'šč', 'dž',
})

-- FIXME: It is strange to use ǯ to stand for ɕ and χ to stand for ɣ
-- (voiced/voiceless mismatch); should use ɣ for ɣ and use ɕ or ś for ɕ;
-- should at least support ɣ for external use for ɣ (NOTE: changing these
-- may be tricky because the current forms may be used externally, e.g.
-- ӂ is definitely used externally in дроӂӂи (pronunciation spelling of
-- дрожжи)
local translit_conv = {
	['c'] = 't͡s', ['č'] = 't͡ɕ', ['g'] = 'ɡ', ['ĵ'] = 'd͡z', ['ǰ'] = 'd͡ʑ', ['ǯ'] = 'ɕ', ['ӂ'] = 'ʑ', ['š'] = 'ʂ', ['ž'] = 'ʐ', ['χ'] = 'ɣ'
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
	['ž'] = 'š', ['χ'] = 'x',

	['bʲ'] = 'pʲ', ['dʲ'] = 'tʲ',
	['zʲ'] = 'sʲ', ['vʲ'] = 'fʲ',
	['žʲ'] = 'šʲ'
}

local voicing = {
	['p'] = 'b', ['t'] = 'd', ['k'] = 'g',
	['s'] = 'z', ['f'] = 'v',
	['š'] = 'ž', ['c'] = 'ĵ', ['č'] = 'ǰ', ['x'] = 'χ', ['ǯ'] = 'ӂ'
}

local geminate_pref = {
	--'^abː',
	'^adː', '^bezː', '^braomː', '^vː', '^voszː', '^izː', '^inː', '^kontrː', '^nadː', '^niszː',
	'^o[cdmtč]ː', '^podː', '^predː', '^paszː', '^pozː', '^sː', '^sverxː', '^subː', '^tröxː', '^čeresː', '^četyröxː', '^črezː',
}

local phon_respellings = {
	--['vstv'] = 'stv',
	[vowels_c .. '([šž])j([ou])'] = '%1%2%3', [vowels_c .. '([šžc])e'] = '%1%2ɛ', [vowels_c .. '([šžc])i'] = '%1%2y',
	-- FIXME!!! Should these also pay attention to grave accents?
	['́tʹ?sja'] = '́cca', ['([^́])tʹ?sja'] = '%1ca',
	['[dt](ʹ?)s(.?)(.?)'] = function(a, b, c)
		if not (b == 'j' and c == 'a') then
			if rsub(b, vowels_c, '') ~= '' or b == 'j' and rsub(c, vowels_c, '') ~= '' then
				-- s was followed by a vowel
				return 'c' .. a .. b .. c
			else
				return 'c' .. a .. 's' .. b .. c
			end
		end end,

	['[dt]z(j?)' .. vowels_c] = 'ĵz%1%2', ['^o[dt]s'] = 'ocs',
	['([čǰӂ])([aou])'] = '%1j%2',

	['([^rn])[dt]c'] = '%1cc', ['[td]č'] = 'čč',
	['stg'] = 'sg',

	-- FIXME, are these necessary? It seems they are handled elsewhere as well
	-- even without these two present
	['([šžč])ʹ$'] = '%1',
	['([šžč])ʹ([ %-])'] = '%1%2',

	['sverxi'] = 'sverxy',
	['stʹd'] = 'zd',
	['tʹd'] = 'dd',

	['r[dt]c'] = 'rc', ['r[dt]č'] = 'rč',
	['zdn'] = 'zn', ['[sz][dt]c'] = 'sc',
	['lnc'] = 'nc',	['n[dt]c'] = 'nc',
	['[sz]tl'] = 'sl', ['[sz]tn'] = 'sn',
	['[szšž]č'] = 'šč', ['[szšž]šč'] = 'šč',
	['[zs]š'] = 'šš', ['[zs]ž'] = 'žž',
	['nnsk'] = 'nsk',
	['n[dt]sk'] = 'n(t)sk',
	['[sz]sk'] = 'sk',
	['s[dt]sk'] = 'sck',
	['gk'] = 'xk',
	['n[dt]g'] = 'ng',
}

local cons_assim_palatal = {
	compulsory = ut.list_to_set({'stʲ', 'zdʲ', 'nč', 'nǯ'}),
	optional = ut.list_to_set({'slʲ', 'zlʲ', 'snʲ', 'znʲ', 'tnʲ', 'dnʲ',
		'nsʲ', 'nzʲ', 'ntʲ', 'ndʲ'})
}

--@Wyang - they may carry the stress too, as alternatives - по́ небу/по не́бу, etc.
local accentless = {
	prep = ut.list_to_set({'bez', 'bliz', 'v', 'vo', 'do',
       'iz-pod', 'iz-za', 'za', 'iz', 'izo',
       'k', 'ko', 'mež', 'na', 'nad', 'nado', 'o', 'ob', 'obo', 'ot',
       'po', 'pod', 'podo', 'pred', 'predo', 'pri', 'pro', 'pered', 'peredo',
       'čerez', 's', 'so', 'u', 'ne'}),
	post = ut.list_to_set({'to', 'libo', 'nibudʹ', 'by', 'b', 'že', 'ž',
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
	--replace hyphens with spaces; FIXME: needs handling for prefixes,
	--e.g. по-, suffixes, e.g. -то, which are reduced (although we do
	--handle these as separate words, see 'accentless')
	text = rsub(text, '-', ' ')

	-- translit will not respect э vs. е difference so we have to
	-- do it ourselves before translit
	text = rsub(text, 'э', 'ɛ')
	-- transliterate and decompose acute and grave Latin vowels
	text = com.translit(text)

	-- handle old ě (e.g. сѣдло́), and ě̈ from сѣ̈дла
	text = rsub(text, 'ě̈', 'jo' .. AC)
	text = rsub(text, 'ě', 'e')
	-- handle secondarily-stressed ё
	text = rsub(text, AC .. GR, GR)

	--phonetic respellings
	for a, b in pairs(phon_respellings) do
		text = rsub(text, a, b)
	end

	text = adj and rsub(text, '(.[aoe]́?)go(' .. AC .. '?)$', '%1vo%2') or text

	-- add primary stress to single-syllable words preceded or followed by
	-- unstressed particle or preposition; make remaining single-syllable
	-- words have "unmarked" stress (treated as stressed but without a
	-- primary or secondary stress marker; we repurpose a circumflex for
	-- this purpose)
	local word = rsplit(text, " ", true)
	for i = 1, #word do
		if not accentless['prep'][word[i]] and not (i > 1 and accentless['post'][word[i]]) and
			ulen(rsub(word[i], non_vowels, '')) == 1 and
			rsub(word[i], non_accents, '') == '' then
			if (i > 1 and accentless['prep'][word[i-1]] or i < #word and accentless['post'][word[i+1]]) then
				word[i] = rsub(word[i], vowels_c, '%1' .. AC)
			else
				word[i] = rsub(word[i], vowels_c, '%1' .. CFLEX)
			end
		end
	end

	-- make prepositions and particles liaise with the following or
	-- preceding word
	for i = 1, #word do
		if i < #word and accentless['prep'][word[i]] then
			word[i+1] = word[i] .. '‿' .. word[i+1]
			word[i+1] = rsub(word[i+1], '([bdkstvxzž])‿i', '%1‿y')
			word[i] = ''
		elseif i > 1 and accentless['post'][word[i]] then
			word[i-1] = word[i-1] .. word[i]
			word[i] = ''
		end
	end

	-- rejoin words and eliminate stray spaces from blanking out words
	text = table.concat(word, " ")
	text = rsub(text, '^ ', '')
	text = rsub(text, ' $', '')
	text = rsub(text, ' +', ' ')

	-- some tidying up after transliteration
	text = rsub(text, 'šč', 'ǯː')
	-- ьо is pronounced as (possibly unstressed) ьё, I think
	text = rsub(text, 'ʹo', 'ʹjo')

	--rewrite iotated vowels
	text = rsub(text, 'j[aeou]', {
		['ja'] = 'ä',
		['je'] = 'ë',
		['jo'] = 'ö',
		['ju'] = 'ü'})

	--voicing/devoicing assimilations
	text = rsub(text, '([bdgzvž]+)([ %-%‿%ː]*[ptksčšǯcx])', function(a, b)
		return rsub(a, '.', devoicing) .. b end)
	text = rsub(text, '([ptksfšcčxǯ]+)([ %-%‿ʹ%ː]*[bdgzž])', function(a, b)
		return rsub(a, '.', voicing) .. b end)

	--re-notate orthographic geminate consonants
	text = rsub(text, (non_vowels_c) .. '%1', '%1ː')

	--split by word and process each word
	word = rsplit(text, " ", true)
	for i = 1, #word do
		local syllable = {} -- list of syllables
		local stress = {} -- set of 1-based indices of stressed syllables
		local pron = word[i]

		--optional iotation of 'e' in a two-vowel sequence and reduction of
		--word-final 'e'; FIXME: Should this also include grave accent?
		pron = rsub(pron, '([aäeëɛiyoöuü][́̂]?)ë([^́̂])', '%1(j)ë%2')
		pron = rsub(pron, 'e$', 'ə')
		pron = rsub(pron, '([aäeëɛəiyoöuüʹ])([́̂]?)[äë]$', '%1%2jə')
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

		--syllabify, inserting / at syllable boundaries
		pron = rsub(pron, '([aäeëɛəiyoöuü]' .. accents .. '?)', '%1/')
		pron = rsub(pron, '/+$', '')
		pron = rsub(pron, '/([^‿/aäeëɛəiyoöuü]*)([^‿/aäeëɛəiyoöuüʹːʲ])(ʹ?ʲ?ː?[aäeëɛəiyoöuü])', '%1/%2%3')
		pron = rsub(pron, '([^‿/aäeëɛəiyoöuü]?)([^‿/aäeëɛəiyoöuü])/([^‿/aäeëɛəiyoöuüʹːʲ])(ʹ?ʲ?ː?[aäeëɛəiyoöuü])', function(a, b, c, d)
			if perm_syl_onset[a .. b .. c] then
				return '/' .. a .. b .. c .. d
			elseif perm_syl_onset[b .. c] then
				return a .. '/' .. b .. c .. d
			end end)
		pron = rsub(pron, '/([^‿/aäeëɛəiyoöuü]+)$', '%1')
		pron = rsub(pron, '/‿', '‿/')

		--write 1-based syllable indexes of stressed syllables (acute or grave) to
		--the list POS
		local pos = {}

		local trimmed_pron = pron
		local count = 0
		while rfind(trimmed_pron, accents) do
			local accent_pos = rfind(trimmed_pron, accents)
			count = count + ulen(rsub(usub(trimmed_pron, 1, accent_pos - 1), '[^%/]', ''))
			table.insert(pos, count + 1)
			trimmed_pron = usub(trimmed_pron, accent_pos + 1, -1)
		end

		--split by syllable
		syllable = rsplit(pron, '/', true)

		--convert list of stress positions to set; equivalent to ut.list_to_set()
		for _, pos in ipairs(pos) do
			stress[pos] = true
		end

		local syl_conv = {}
		for j = 1, #syllable do
			local syl = syllable[j]

			--remove consonant geminacy if non-initial and non-post-tonic
			if rfind(syl, 'ː') and gem ~= 'y' then
				local no_replace = false
				if (j == 1 and not rfind(syl, 'ː$')) or stress[j-1] then
					no_replace = true
				else
					local de_accent = rsub(word[i], accents, '')
					for i = 1, #geminate_pref do
						if not no_replace and rfind(de_accent, geminate_pref[i]) then
							no_replace = true
						end
					end
				end
				if gem == 'n' then
					no_replace = false
				end
				if not no_replace then
					syl = rsub(syl, '([^ǯӂn])ː', '%1')
					if gem == 'n' then
						syl = rsub(syl, 'nː', 'n')
					end
				end
				if rfind(word[i], non_accents .. 'nːyj$') then
					syl = rsub(syl, 'nːyj', 'n(ː)yj')
				end
			end

			--assimilative palatalisation of consonants when followed by front vowels
			-- FIXME: I don't understand this code very well (Benwing)
			if pal == 'y' or rfind(syl, '^[^cĵšžaäeëɛiyoöuü]*[eiəäëöüʹ]') or rfind(syl, '^[cĵšž][^cĵšžaäeëɛiyoöuüː]+[eiəäëöüʹ]') or rfind(syl, '^[cĵ][äëü]') then
				if not rfind(syl, 'ʺ.*' .. vowels) and not rfind(syl, 'ʹ' .. non_vowels .. '.*' .. vowels) then
					syl = rsub(syl, non_vowels_c .. '([ʹːj]?[aäeëɛəiyoöuüʹ])', function(a, b)
						local set = '[mnpbtdkgcfvszxrl]'
						if pal == 'y' then
							set = '[mnpbtdkgcfvszxrlǯӂšž]'
						end
						set = '(' .. set .. ')'
						return rsub(a, set, '%1ʲ') .. b end)
				end
			end

			-- palatalization by soft sign
			syl = rsub(syl, '(.?ː?)ʹ', function(a)
				if rfind(a, '[čǰšžǯ]') then
					return a
				elseif a ~= 'ʲ' then
					return a .. 'ʲ'
				else
					return 'ʲ'
				end end)

			--retraction of front vowels in syllables blocking assimilative palatalisation
			if not rfind(syl, 'ʲː?' .. vowels) and not rfind(syl, '[čǰǯӂ]ː?[ei]') and not rfind(syl, '^j?i') then
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
				syl = rsub(syl, '([ʲčǰǯӂ]ː?)o', '%1ö')
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

		--consonant assimilative palatalisation
		pron = rsub(pron, '([szntd])(ˈ?)([tdčǰǯlnsz]ʲ?)', function(a, b, c)
			if cons_assim_palatal['compulsory'][a..c] then
				return a .. 'ʲ' .. b .. c
			elseif cons_assim_palatal['optional'][a..c] then
				return a .. '⁽ʲ⁾' .. b .. c
			end end)

		--fronting of stressed 'a' between soft consonants
		pron = rsub(pron, 'ˈ(..?.?)a(.?.?.?)', function(a, b)
			if rfind(a, '[ʲčǰǯӂ]') and (b == '' or rfind(b, '[ʲčǰǯӂ]')) then
				return 'ˈ' .. a .. 'æ' .. b
			end end)

		--final devoicing and devoicing assimilation
		pron = rsub(pron, '([bdgzvžχ]ʲ?)$', function(a)
			if not rfind(word[i+1] or '', '^[bdgzvžn]') then
				return devoicing[a]
			end end)

		pron = rsub(pron, '([bdgzvž])(ʲ?[ %-%‿]?[ptksčšǯcx])', function(a, b)
			return devoicing[a] .. b end)

		if rfind(word[i], 'sä$') then
			pron = rsub(pron, 'sʲə$', 's⁽ʲ⁾ə')
		end

		pron = rsub(pron, '[cčgĵǰšžǯӂχ]', translit_conv)
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
