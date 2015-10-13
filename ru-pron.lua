--[[
This module implements the template {{ru-IPA}} (FIXME, is it called elsewhere?)

Author: Primarily Wyang, with help from Atitarev and a bit from others

QUESTIONS TO ASK OF ATITAREV/CINEMANTIQUE:

1. Ask Atitarev/Cinemantique about -ьо, is it same as (possibly unstressed)
   -ьё? (DONE. YES.)
2. Ask A/C -- should стск be treated like сск or ск? (the latter is what's
   currently done) (DONE. CONVERTED TO ССК. A SAYS SOMETIMES PRONOUNCED AS СТСК
   WHEN FORMAL, NEED TO DECIDE WHAT TO DO.)
3. Ask A/C -- should we ever reduce double vowels to long vowels? (commented
   out) (DONE. NO.)
4. Ask A/C -- should сск be converted to ск (this is what's done currently)?
5, Ask A/C -- 'н[ндт]ск'] = 'нск', is this correct?

FIXME:

1. Figure out issue with фильм, сельдь.
2. Figure out issue with Амударья́ and скамья́ (pre-tonal syllables).
3. Figure out issue with та́ять.
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

local AC = u(0x0301) -- acute =  ́
local GR = u(0x0300) -- grave =  ̀

-- FIXME, should include outdated vowels in cyr_vowels_c or should
-- canonicalize them early on
local vowels, vowels_c, non_vowels, non_vowels_c, cyr_vowels_c = '[aäeëɛəiyoöuü]', '([aäeëɛəiyoöuü])', '[^aäeëɛəiyoöuü]', '([^aäeëɛəiyoöuü])', '([аяеёэиыоую])'

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

-- FIXME! These should happen *AFTER* translit so that we can specify
-- transliteration as an option and use it -- to facilitate automatically
-- generating pronunciations from headwords
local phon_respellings = {
	--['вств'] = 'ств',
	-- FIXME!!! These won't work because they have vowels_c instead of
	-- cyr_vowels_c; they also don't correctly handle accent marks
	[cyr_vowels_c .. '([шж])ю'] = '%1%2у', [cyr_vowels_c .. '([шжц])е'] = '%1%2э', [cyr_vowels_c .. '([шжц])и'] = '%1%2ы', [cyr_vowels_c .. '([шж])ё'] = '%1%2о́',
	-- FIXME!!! Shouldn't these also pay attention to ё and diaeresis instead
	-- of just acute accent?
	['́ть?ся'] = '́цца', ['([^́])ть?ся'] = '%1ца',
	['[дт](ь?)с(.?)'] = function(a, b)
		if b ~= 'я' then
			if rsub(b, cyr_vowels_c, '') == '' then
				return 'ц' .. a .. 'с' .. b
			else
				return 'ц' .. a .. b
			end
		end end,

	['[дт]з' .. cyr_vowels_c] = 'ĵз%1', ['^о[дт]с'] = 'оцс',
	['([щч])о'] = '%1ё', ['([щч])а'] = '%1я', ['([щч])у'] = '%1ю',

	['([^рн])[дт]ц'] = '%1цц', ['[тд]ч'] = 'чч',
	['йо́'] = 'ё',
	['стг'] = 'сг',

	['([шжщч])ь$'] = '%1',

	['сверхи'] = 'сверхы',
	['стьд'] = 'зд',
	['тьд'] = 'дд',

	['р[дт]ц'] = 'рц', ['р[дт]ч'] = 'рч',
	['здн'] = 'зн', ['[сз][дт]ц'] = 'сц',
	['лнц'] = 'нц',	['н[дт]ц'] = 'нц',
	['[сз]тл'] = 'сл', ['[сз]тн'] = 'сн',
	['[сзшж]ч'] = 'щ', ['[сзшж]щ'] = 'щ',
	['[зс]ш'] = 'шш', ['[зс]ж'] = 'жж',
	['н[ндт]ск'] = 'нск',
	['[сз]ск'] = 'ск',
	['с[дт]ск'] = 'сск',
	['гк'] = 'хк',
	['н[дт]г'] = 'нг',
	['э'] = 'ɛ',
}

-- FIXME: Use ut.list_to_set() here
local cons_assim_palatal = {
	compulsory = ut.list_to_set({'stʲ', 'zdʲ', 'nč', 'nǯ'}),
	optional = ut.list_to_set({'slʲ', 'zlʲ', 'snʲ', 'znʲ', 'tnʲ', 'dnʲ',
		'nsʲ', 'nzʲ', 'ntʲ', 'ndʲ'})
}

--@Wyang - they may carry the stress too, as alternatives - по́ небу/по не́бу, etc.
local accentless = {
	prep = ut.list_to_set({'без', 'близ', 'в', 'во', 'до',
		'из-под', 'из-за', 'за', 'из', 'изо',
		'к', 'ко', 'меж', 'на', 'над', 'надо', 'о', 'об', 'обо', 'от',
		'по', 'под', 'подо', 'пред', 'предо', 'при', 'про', 'перед', 'передо',
		'через', 'с', 'со', 'у', 'не'}),
	post = ut.list_to_set({'то', 'либо', 'нибудь', 'бы', 'б', 'же', 'ж',
		'ка', 'тка', 'ли'})
}

function ine(x)
	return x ~= "" and x or nil
end

function export.ipa(text, adj, gem, pal)
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

	text = com.decompose_grave(text)

	--phonetic respellings; FIXME: should happen after transliteration
	for a, b in pairs(phon_respellings) do
		text = rsub(text, a, b)
	end
	-- FIXME, should include а as well as о and е to handle old-style
	-- adjectival genitives
	-- FIXME: should happen after transliteration
	text = adj and rsub(text, '(.[ое]́?)го(' .. AC .. '?)$', '%1во%2') or text

	--make monosyllabic prepositions liaise with the following word
	-- FIXME: should happen after transliteration
	local word = rsplit(text, " ", true)
	for i = 1, #word do
		if accentless['prep'][word[i]] and i ~= #word then
			word[i+1] = word[i] .. '‿' .. word[i+1]
			word[i+1] = rsub(word[i+1], '([бдкствхзж])‿и', '%1‿ы')
			word[i] = ''
		elseif accentless['post'][word[i]] and i ~= 1 then
			word[i-1] = word[i-1] .. word[i]
			word[i] = ''
		end
	end

	text = table.concat(word, " ")
	text = rsub(text, '^ ', '')
	text = rsub(text, ' $', '')
	text = rsub(text, ' +', ' ')

	--transliterate and tidy up
	text = m_ru_translit.tr(text)
	text = rsub(text, 'šč', 'ǯː')
	-- FIXME: If we accept transliterated text from the outside, we will
	-- need to decompose all acute and grave Latin vowels
	text = rsub(text, 'ó', 'o' .. AC)
	-- ьо is pronounced as (possibly unstressed) ьё, I think
	text = rsub(text, 'ʹo', 'ʹjo')

	--rewrite iotated vowels
	text = rsub(text, 'j[aeou]', {
		['ja'] = 'ä',
		['je'] = 'ë',
		['jo'] = 'ö',
		['ju'] = 'ü'})

	--voicing/devoicing assimilations
	text = rsub(text, '([bdgzvž]+)([ %-%‿%ː]?[ptksčšǯcx])', function(a, b)
		return rsub(a, '.', devoicing) .. b end)
	text = rsub(text, '([ptksfšcčxǯ]+)([ %-%‿ʹ%ː]?[bdgzž])', function(a, b)
		return rsub(a, '.', voicing) .. b end)

	--re-notate orthographic geminate consonants
	text = rsub(text, (non_vowels_c) .. '%1', '%1ː')

	--split by word and process each word
	word = rsplit(text, " ", true)
	for i = 1, #word do
		local syllable = {} -- list of syllables
		local stress = {} -- set of 1-based indices of stressed syllables
		local pron = word[i]

		--optional iotation of 'e' in a two-vowel sequence and reduction of word-final 'e'
		pron = rsub(pron, '([aäeëɛiyoöuü]́?)ë([^́])', '%1(j)ë%2')
		pron = rsub(pron, 'e$', 'ə')
		pron = rsub(pron, '([aäeëɛəiyoöuüʹ])(́?)[äë]$', '%1%2jə')
		pron = rsub(pron, non_vowels_c .. 'ä$', '%1ʲə')
		pron = rsub(pron, '%(j%)jə', 'jə')

		--syllabify, inserting / at syllable boundaries
		pron = rsub(pron, 'ʹ([äëöü])', 'ʹ/%1')
		pron = rsub(pron, 'ʹi', 'ʹji')
		pron = rsub(pron, '([aäeëɛəiyoöuü][́̀]?)', '%1/')
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

		--remove accent marks from monosyllables
		if ulen(rsub(pron, non_vowels_c, '')) == 1 and rfind(pron, 'o' .. AC) then
			pron = rsub(pron, AC, '')
		end

		--write 1-based syllable indexes of stressed syllables (acute or grave) to
		--the list POS
		local pos = {}

		local trimmed_pron = pron
		while rfind(trimmed_pron, '[́̀]') do
			local accent_pos = rfind(trimmed_pron, '[́̀]')
			local count = count + ulen(rsub(usub(trimmed_pron, 1, accent_pos - 1), '[^%/]', ''))
			table.insert(pos, count + 1)
			trimmed_pron = usub(trimmed_pron, accent_pos + 1, -1)
		end

		--treat monosyllabic non-prepositions as if accented
		pron = rsub(pron, '(.*)' .. vowels_c .. '(.*)', function(a, b, c)
			if not rfind(a .. c, vowels) then
				table.insert(pos, 1)
			end end)

		--split by syllable
		syllable = rsplit(pron, '/', true)
		if #syllable == 1 then
			table.insert(pos, 1)
		end

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
					local de_accent = rsub(word[i], '[̀́]', '')
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
				if rfind(word[i], '[^̀́]nːyj$') then
					syl = rsub(syl, 'nːyj', 'n(ː)yj')
				end
			end

			--assimilative palatalisation of consonants when followed by front vowels
			if pal == 'y' or rfind(syl, '^[^cĵšžaäeëɛiyoöuü]*[eiəäëöüʹ]') or rfind(syl, '^[cĵšž][^cĵšžaäeëɛiyoöuüː]+[eiəäëöüʹ]') or rfind(syl, '^[cĵ][äëü]') then
				syl = rsub(syl, '^([ʺʹ]?)([äëöü])', '%1j%2')
				if not rfind(syl, 'ʺ') and not rfind(syl, 'ʹ' .. non_vowels) then
					syl = rsub(syl, non_vowels_c .. '([ʹːj]?[aäeëɛəiyoöuüʹ])', function(a, b)
						local set = '[mnpbtdkgcfvszxrl]'
						if pal == 'y' then
							set = '[mnpbtdkgcfvszxrlǯӂšž]'
						end
						set = '(' .. set .. ')'
						return rsub(a, set, '%1ʲ') .. b end)
				end
			end
			syl = rsub(syl, 'ʺ([äëöü])', 'j%1')
			syl = rsub(syl, 'ʺj', 'j')
			syl = rsub(syl, 'ʺ([aɛiouy])', 'ʔ%1')
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
			if stress[j] or (j == #syllable and rfind(syllable[j-1] .. syllable[j], '[aieäëü]́?o')) or rfind(syllable[j], GR) then
				syl = rsub(syl, '(.*)́', 'ˈ%1')
				syl = rsub(syl, '(.*)̀', 'ˌ%1')
				syl = rsub(syl, '([ʲčǰǯ]ː?)o', '%1ö')
				syl = rsub(syl, vowels_c, function(a)
					if a ~= '' then
						return allophones[a][1]
					end end)

			else
				if not rfind((syllable[j-1] or '') .. syllable[j], '[ʺʹ]') and (j ~= #syllable or (j == #syllable and not rfind(syl, 'jə$'))) then
					syl = rsub(syl, 'j' .. rsub(vowels_c, 'ü', ''), '(j)%1')
				end
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
	-- but not spaces; but we don't currently preserve hyphens this far
	-- text = rsub(text, '[ɐə]([%-]?)ɐ(%l?)ˈ', '%1ɐː%2ˈ')
	-- text = rsub(text, 'ə([%-]?)[ɐə]', '%1əː')

	-- double consonants, in words like секвойя and майя; FIXME, this won't
	-- be correct if the preceding vowel is unstressed; we need to do this
	-- check before the code that handles geminates, and then make sure that
	-- any further code involving /j/ checks for the geminate marker ː
	text = rsub(text, 'jʲ', 'jː')

	return text
end

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
