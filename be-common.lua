local export = {}

local u = mw.ustring.char
local rsplit = mw.text.split
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsubn = mw.ustring.gsub
local ulen = mw.ustring.len
local ulower = mw.ustring.lower
local uupper = mw.ustring.upper
local usub = mw.ustring.sub

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


local AC = u(0x0301) -- acute =  ́
local GR = u(0x0300) -- acute =  ̀
local CFLEX = u(0x0302) -- circumflex =  ̂
local DOTBELOW = u(0x0323) -- dot below =  ̣
export.accents = AC .. CFLEX .. DOTBELOW
export.accents_c = "[" .. export.accents .. "]"

export.vowel = "аеіоуяэыёюАЕІОУЯЭЫЁЮ"
export.vowel_c = "[" .. export.vowel .. "]"
export.non_vowel_c = "[^" .. export.vowel .. "]"
export.velar = "кгґхКГҐХ"
export.velar_c = "[" .. export.velar .. "]"
export.always_hard = "ршчжРШЧЖ"
export.always_hard_c = "[" .. export.always_hard .. "]"
export.always_hard_or_ts = export.always_hard .. "цЦ"
export.always_hard_or_ts_c = "[" .. export.always_hard_or_ts .. "]"
export.cons_except_always_hard_or_ts = "бдфгґйклмнпствхзўьБДФГҐЙКЛМНПСТВХЗЎЬ'"
export.cons_except_always_hard_or_ts_c = "[" .. export.cons_except_always_hard_or_ts .. "]"
export.cons = export.always_hard .. export.cons_except_always_hard_or_ts .. "цЦ"
export.cons_c = "[" .. export.cons .. "]"


export.VAR1 = u(0xFFF0)
export.VAR2 = u(0xFFF1)
export.VAR3 = u(0xFFF2)
export.var_code_c = "[" .. export.VAR1 .. export.VAR2 .. export.VAR3 .. "]"


local grave_deaccenter = {
	[GR] = "", -- grave accent
	["ѐ"] = "е", -- composed Cyrillic chars w/grave accent
	["Ѐ"] = "Е",
	["ѝ"] = "и",
	["Ѝ"] = "И",
}

local deaccenter = mw.clone(grave_deaccenter)
deaccenter[AC] = "" -- acute accent

local destresser = mw.clone(deaccenter)
destresser["ё"] = "е"
destresser["Ё"] = "Е"
destresser["о"] = "а"
destresser["О"] = "А"
destresser["э"] = "а"
destresser["Э"] = "А"

local pre_tonic_destresser = mw.clone(destresser)
pre_tonic_destresser["ё"] = "я"
pre_tonic_destresser["Ё"] = "Я"
pre_tonic_destresser["е"] = "я"
pre_tonic_destresser["Е"] = "Я"

local ae_stresser = {
	["а"] = "э",
	["я"] = "е",
}

local ao_stresser = {
	["а"] = "о",
	["я"] = "ё",
}

local first_palatalization = {
	["к"] = "ч",
	["г"] = "ж",
	["ґ"] = "ж",
	["х"] = "ш",
	["ц"] = "ч",
}


local second_palatalization = {
	["к"] = "ц",
	["г"] = "з",
	["ґ"] = "з",
	["х"] = "с",
}


local function get_variants(form)
	return
		form:find(export.VAR1) and "var1" or
		form:find(export.VAR2) and "var2" or
		form:find(export.VAR3) and "var3" or
		nil
end


function export.remove_variant_codes(word)
	return rsub(word, export.var_code_c, "")
end


-- Remove acute and grave accents; don't affect ёЁ.
function export.remove_accents(word)
	return rsub(word, "[́̀ѐЀѝЍ]", deaccenter)
end


function export.needs_accents(text)
	for _, word in ipairs(rsplit(text, "%s+")) do
		-- A word needs accents if it contains no accent or ё and has more than one vowel
		if not export.is_stressed(word) and not export.is_monosyllabic(word) then
			return true
		end
	end
	return false
end


function export.is_stressed(word)
	return rfind(word, "[́ёЁ]")
end


-- Return whether the word has an acute accent. Use this in preference to is_stressed()
-- once mark_stressed_vowels_in_unstressed_syllables() has been called, because
-- is_accented() will correctly ignore ё/Ё in unstressed syllables (those in stressed
-- syllables are marked with an acute accent).
function export.is_accented(word)
	return rfind(word, AC)
end


function export.is_initial_stressed(word)
	return rfind(word, "^" .. export.non_vowel_c .. "*" .. export.vowel_c .. AC) or
		not rfind(word, AC) and rfind(word, "^" .. export.non_vowel_c .. "*[ёЁ]")
end


function export.is_final_stressed(word)
	return rfind(word, AC .. export.non_vowel_c .. "*$") or
		not rfind(word, AC) and rfind(word, "[ёЁ]" .. export.non_vowel_c .. "*$")
end


-- Check if word ends in a vowel.
function export.ends_in_vowel(word)
	return rfind(word, export.vowel_c .. export.accents_c .. "*$")
end

-- Check if word ends in a velar.
function export.ends_in_velar(word)
	return rfind(word, export.velar_c .. "$")
end

-- Check if word ends in an always-hard consonant.
function export.ends_always_hard(word)
	return rfind(word, export.always_hard_c .. "$")
end

-- Check if word ends in an always-hard consonant or ц.
function export.ends_always_hard_or_ts(word)
	return rfind(word, export.always_hard_or_ts_c .. "$")
end

--[=[

HANDLING BELARUSIAN VOWEL ALTERNATIONS:

We proceed as follows:

1. Call mark_stressed_vowels_in_unstressed_syllables() to attach a stress mark
   (acute accent) to monosyllabic vowels and to stressed ё vowels, and attach
   a special signal (DOTBELOW) to vowels that are in positions they should not be
   (о э ё in unstressed syllables, е directly before the stress), so that they
   are never converted to their destressed equivalent.
2. Attempt to reconstruct, as much as possible, the underlying vowels of the word.
   This is normally done using apply_vowel_alternation().
3. Move the stress mark elsewhere in the word (e.g. by removing the stress mark and
   appending a stressed suffix).
4. Call destress_vowels_after_stress_movement() to convert the word to its final
   form. This turns о э ё in unstressed syllables and е directly before the stress
   into other vowels, taking care not to do this if DOTBELOW follows the vowel.
   After that, it undoes the changes made in mark_stressed_vowels_in_unstressed_syllables().
]=]

-- Apply one or more vowel alternant specifications ("ao"/"ao2"/"ao3", "ae"/"ae2"/"ae3",
-- "avo"/"avo2"/"avo3", "yo"/"yo2"/"yo3", "oy" or "voa") to the given word.
function export.apply_vowel_alternation(word, vowel_alternants)
	if not vowel_alternants then
		return word
	end
	for _, valt in ipairs(vowel_alternants) do
		if rfind(valt, "^av?[eo][23]?$") or rfind(valt, "^yo[23]?$") then
			local re, errmsg
			if rfind(valt, "[^23]$") then
				re = export.non_vowel_c .. "*" .. export.vowel_c .. AC
				errmsg = "directly before the stress"
			elseif rfind(valt, "2$") then
				re = export.non_vowel_c .. "*" .. export.vowel_c .. export.non_vowel_c .. "*" .. export.vowel_c .. AC
				errmsg = "two syllables before the stress"
			elseif rfind(valt, "3$") then
				re = export.non_vowel_c .. "*" .. export.vowel_c .. export.non_vowel_c .. "*" .. export.vowel_c .. export.non_vowel_c .. "*" .. export.vowel_c
				errmsg = "three syllables before the stress"
			else
				error("Unrecognized vowel alternant '" .. valt .. "'")
			end
			local new_word, req_vowel
			if rfind(valt, "^a[eo]") then
				new_word = rsub(word, "([аАяЯ])(" .. re .. ")",
					function(a_vowel, rest)
						local stresser = rfind(valt, "^ao") and ao_stresser or ae_stresser
						return stresser[a_vowel] .. rest
					end
				)
				req_vowel = "а or я"
			elseif rfind(valt, "^avo") then
				new_word = rsub(word, "([аА])(" .. re .. ")",
					function(a_vowel, rest)
						return (a_vowel == "а" and "в" or "В") .. CFLEX .. "о" .. rest
					end
				)
				req_vowel = "а"
			elseif rfind(valt, "^yo") then
				new_word = rsub(word, "([ыЫ])(" .. re .. ")",
					function(y_vowel, rest)
						return (y_vowel == "ы" and "о" or "О") .. CFLEX .. rest
					end
				)
				req_vowel = "ы"
			else
				error("Unrecognized vowel alternant '" .. valt .. "'")
			end
			if new_word == word then
				error("Indicator '" .. valt .. "' can't be applied because word '" .. word .. "' doesn't have an " .. req_vowel .. " " .. errmsg)
			end
			word = new_word
		elseif valt == "oy" then
			local new_word = rsub(word, "([оО]́)", "%1" .. CFLEX)
			if new_word == word then
				error("Indicator 'oy' can't be applied because word '" .. word .. "' doesn't have a stressed о")
			end
			word = new_word
		elseif valt == "voa" then
			local new_word = rsub(word, "([вВ])о́", "%1" .. CFLEX .. "о́")
			if new_word == word then
				error("Indicator 'voa' can't be applied because word '" .. word .. "' doesn't have a stressed во")
			end
			word = new_word
		else
			error("Unrecognized vowel alternant '" .. valt .. "'")
		end
	end
	return word
end


-- Mark vowels that should only occur in stressed syllables (э, о, ё) but
-- actually occur in unstressed syllables with a dot-below. Also mark е
-- that occurs directly before the stress in this fashion, and add an acute
-- accent to stressed ё. We determine whether an ё is stressed as follows:
-- (1) If an acute accent already occurs, an ё isn't marked with an acute
--     accent (e.g. ра́дыё).
-- (2) Otherwise, mark only the last ё with an acute, as multiple ё sounds
--     can occur (at least, in Russian this is the case, as in трёхколёсный).
function export.mark_stressed_vowels_in_unstressed_syllables(word)
	if export.is_nonsyllabic(word) then
		return word
	end
	if export.is_multi_stressed(word) then
		error("Word " .. word .. " has multiple accent marks")
	end
	if export.has_grave_accents(word) then
		error("Word " .. word .. " has grave accents")
	end
	word = export.add_monosyllabic_accent(word)
	if not rfind(word, AC) then
		if rfind(word, "[ёЁ]") then
			word = rsub(word, "([ёЁ])(.-)$", "%1" .. AC .. "%2")
		else
			error("Multisyllabic word " .. word .. "missing an accent")
		end
	end

	word = rsub(word, "([эоёЭОЁ])([^́])", "%1" .. DOTBELOW .. "%2")
	word = rsub(word, "([эоёЭОЁ])$", "%1" .. DOTBELOW)
	word = rsub(word, "([еЕ])(" .. export.non_vowel_c .. "*" .. export.vowel_c .. AC .. ")",
		"%1" .. DOTBELOW .. "%2")
	return word
end


-- Undo extra diacritics added by `mark_stressed_vowels_in_unstressed_syllables` or
-- otherwise (e.g. CFLEX).
function export.undo_mark_stressed_vowels_in_unstressed_syllables(word)
	word = rsub(word, DOTBELOW, "")
	word = rsub(word, CFLEX, "")
	word = rsub(word, "([ёЁ])́", "%1")
	return word
end


-- Destress vowels in unstressed syllables. Vowels followed by DOTBELOW are unchanged;
-- otherwise, о -> а; э -> а; ё -> я directly before the stress or when followed by
-- CFLEX, otherwise е; е -> я directly before the stress. After that, remove extra
-- diacritics added by mark_stressed_vowels_in_unstressed_syllables().
function export.destress_vowels_after_stress_movement(word)
	-- Handle ё + CFLEX. This assumes that a stress mark comes between ё and CFLEX,
	-- which will normally be the case if maybe_accent_initial_syllable() or
	-- maybe_accent_final_syllable() is used to add stress. We remove the CFLEX after
	-- destressing the syllable; a CFLEX after a stressed syllable will get removed by
	-- undo_mark_stressed_vowels_in_unstressed_syllables().
	word = rsub(word, "([ёЁ])" .. CFLEX, pre_tonic_destresser)
	-- Handle о + CFLEX; same idea as above.
	word = rsub(word, "([оО])" .. CFLEX, function(o_vowel) return o_vowel == "о" and "ы" or "Ы" end)
	word = rsub_repeatedly(word, "([эоёЭОЁ])([^" .. AC .. DOTBELOW .. "])",
		function(vowel, rest)
			return destresser[vowel] .. rest
		end
	)
	word = rsub(word, "([эоёЭОЁ])$", destresser)
	word = rsub(word, "([еЕ])(" .. export.non_vowel_c .. "*" .. export.vowel_c .. AC .. ")",
		function(vowel, rest)
			if not rfind(rest, "^" .. DOTBELOW) then
				return pre_tonic_destresser[vowel] .. rest
			else
				return vowel .. rest
			end
		end)
	-- Handle в + CFLEX + non-о, which loses the в. Do this after converting unstressed о to а.
	word = rsub_repeatedly(word, "([вВ])" .. CFLEX .. "([^оО])", "%2")
	return export.undo_mark_stressed_vowels_in_unstressed_syllables(word)
end


-- If word is lacking an accent, add it onto the initial syllable.
-- This assumes the word has been processed by mark_stressed_vowels_in_unstressed_syllables(),
-- so that even the ё vowel gets stress.
function export.maybe_accent_initial_syllable(word)
	if not rfind(word, AC) then
		-- accent first syllable
		word = rsub(word, "^(.-" .. export.vowel_c .. ")", "%1" .. AC)
	end
	return word
end


-- If word is lacking an accent, add it onto the final syllable.
-- This assumes the word has been processed by mark_stressed_vowels_in_unstressed_syllables(),
-- so that even the ё vowel gets stress.
function export.maybe_accent_final_syllable(word)
	if not rfind(word, AC) then
		-- accent last syllable
		word = rsub(word, "(.*" .. export.vowel_c .. ")", "%1" .. AC)
	end
	return word
end


-- Make a word unstressed, appropriately handling akanye and yakanye on the
-- stressed syllable. PRE_TONIC indicates whether ё should be converted to я
-- (PRE_TONIC is true) or е (otherwise). This has no effect on unstressed
-- syllables, although in some cases they need to change (in particular,
-- я in the pre-tonic syllabic might need to change to underlying е, and
-- other changes might be necessary if the stress is going to be moved onto
-- a different syllable of the word).
function export.make_unstressed(word, pre_tonic)
	local destresser = pre_tonic and pre_tonic_destresser or destresser
	-- ё may occur in unstressed syllables, e.g. ра́дыё "radio". э may occur in
	-- unstressed syllables, e.g. тэлеві́зар "television". Possibly the same
	-- with о. In this case, we don't want to modify the ё/э/о. But we do want to
	-- modify stressed ё́/э́/о́ appropriately.
	if rfind(word, AC) then
		word = rsub(word, "([ёЁэЭоО])́", function(vowel)
			return destresser[vowel]
		end)
		return rsub(word, AC, "")
	end
	return rsub(word, "[̀ёЁэЭоОѐЀѝЍ]", destresser)
end


function export.is_multi_stressed(text)
	for _, word in ipairs(rsplit(text, "[%s%-]+")) do
		if ulen(rsub(word, "[^́]", "")) > 1 then
			return true
		end
	end
	return false
end


-- Check if word is nonsyllabic.
function export.is_nonsyllabic(word)
	return not rfind(word, export.vowel_c)
end


-- Check if word is monosyllabic (also includes words without vowels).
function export.is_monosyllabic(word)
	local num_syl = ulen(rsub(word, export.non_vowel_c, ""))
	return num_syl <= 1
end


-- Check if word has grave accents.
function export.has_grave_accents(word)
	return rfind(word, "[̀ѐЀѝЍ]")
end


-- If word is monosyllabic, add an accent mark to the vowel. Don't affect ёЁ
-- unless `even_yo` is specified.
function export.add_monosyllabic_stress(word, even_yo)
	if export.is_monosyllabic(word) and not rfind(word, "^%-") and not rfind(word, "%-$") and
		not (even_yo and export.is_accented(word) or export.is_stressed(word)) then
		word = rsub(word, "(" .. export.vowel_c .. ")", "%1" .. AC)
	end
	return word
end	


-- If word is monosyllabic, add an accent mark to the vowel. Unlike
-- add_monosyllabic_stress(), even add an accent to ёЁ.
function export.add_monosyllabic_accent(word)
	return export.add_monosyllabic_stress(word, "even yo")
end


-- If word is monosyllabic, remove accent marks from the vowel.
function export.remove_monosyllabic_accents(word)
	if export.is_monosyllabic(word) and not rfind(word, "^%-") and not rfind(word, "%-$") then
		return export.remove_accents(word)
	end
	return word
end


function export.iotate(stem)
	stem = rsub(stem, "с[ктц]$", "шч")
	stem = rsub(stem, "[ктц]$", "ч")
	stem = rsub(stem, "[сх]$", "ш")
	stem = rsub(stem, "[гґз]$", "ж")
	stem = rsub(stem, "дз?$", "дж")
	stem = rsub(stem, "([бўмпф])$", "%1л")
	stem = rsub(stem, "в$", "ўл")
	return stem
end


function export.apply_first_palatalization(word)
	return rsub(word, "^(.*)([кгґхц])$",
		function(prefix, lastchar) return prefix .. first_palatalization[lastchar] end
	)
end


function export.apply_second_palatalization(word)
	return rsub(word, "^(.*)([кгґх])$",
		function(prefix, lastchar) return prefix .. second_palatalization[lastchar] end
	)
end


function export.palatalize_td(stem)
	stem = rsub(stem, "т$", "ц")
	stem = rsub(stem, "д$", "дз")
	return stem
end


function export.combine_stem_ending(stem, ending)
	if stem == "?" then
		return "?"
	end
	if export.is_accented(ending) then
		stem = export.remove_accents(stem)
	end
	if rfind(ending, "^[яеіёюь]") then
		stem = export.palatalize_td(stem)
	end
	return stem .. ending
end


function export.combine_stem_ending_into_external_form(stem, ending)
	return export.destress_vowels_after_stress_movement(
		export.combine_stem_ending(stem, ending)
	)
end


-- Remove the vowel between the last two consonants of a stem.
-- Used especially in masculine and third-declension feminine nouns to
-- generate the stem that is used before endings beginning with a vowel.
-- This is based on the corresponding function in [[Module:ru-common]],
-- adapted for Belarusian phonology and orthography.
function export.reduce(stem)
	local pre, letter, post = rmatch(stem, "^(.+)([оОёЁаАэЭеЕ])́?(" .. export.cons_c .. "+)$")
	if not pre then
		return nil
	end
	if rfind(letter, "[оОаАэЭ]") then
		-- FIXME, what about when the accent is on the removed letter?
		if rfind(post, "^[йЙ]$") then
			-- FIXME, is this correct?
			return nil
		end
		-- аўто́рак -> аўто́рк-, вы́нятак -> вы́нятк-, ло́жак -> ло́жк-
		-- алжы́рац -> алжы́рц-
		-- міні́стар -> міні́стр-
		letter = ""
	else
		local is_upper = rfind(post, "%u")
		if export.ends_in_vowel(pre) then
			-- аўстралі́ец -> аўстралі́йц-
			-- аўстры́ец -> аўстры́йц-
			-- еўрапе́ец -> еўрапе́йц
			letter = is_upper and "Й" or "й"
		elseif rfind(post, "[йЙ]") then
			if rfind(pre, "[вВ]$") then
				-- салаве́й -> салаў-
				letter = ""
			elseif rfind(pre, "[uбБпПфФмМ]$") then
				-- верабе́й -> вераб'-
				letter = "'"
			elseif is_upper then
				letter = usub(pre, -1)
			else
				-- вуле́й -> вулл-
				letter = ulower(usub(pre, -1))
			end
			post = ""
		elseif rfind(post, export.velar_c .. "$") and rfind(pre, export.cons_except_always_hard_or_ts_c .. "$") or
			rfind(post, "[^йЙ" .. export.velar .. "]$") and rfind(pre, "[лЛ]$") then
			-- For the first part: князёк -> князьк-
			-- For the second part: алёс -> альс-, відэ́лец -> відэ́льц-
			-- Both at once: матылёк -> матыльк-
			letter = is_upper and "Ь" or "ь"
		else
			-- пёс -> пс-
			-- асёл -> асл-, бу́сел -> бу́сл-
			-- бабёр -> бабр-, шва́гер -> шва́гр-
			-- італья́нец -> італья́нц-
			letter = ""
		end
		-- адзёр -> адр-
		-- ірла́ндзец -> ірла́ндц-
		pre = rsub(pre, "([Дд])[Зз]$", "%1")
		-- кацёл -> катл-, ве́цер -> ве́тр-
		pre = rsub(pre, "ц$", "т")
		pre = rsub(pre, "Ц$", "Т")
	end
	-- ало́вак -> ало́ўк-, авёс -> аўс-, чо́вен -> чо́ўн-, ядло́вец -> ядло́ўц-
	-- NOTE: любо́ў -> любв- but we need to handle this elsewhere as it also applies
	-- to non-reduced nouns, e.g. во́страў -> во́страв-
	pre = rsub(pre, "в$", "ў")
	pre = rsub(pre, "В$", "Ў")
	return pre .. letter .. post
end


-- Add an epenthetic vowel between the last two consonants of the stem.
-- Used especially in feminine and neuter nouns to generate the genitive
-- plural. `epenthetic_stress` is true if the inserted vowel should bear
-- the stress according to the accent pattern of the noun. This is based
-- on the corresponding function in [[Module:ru-common]], adapted for
-- Belarusian phonology and orthography.
function export.dereduce(stem, epenthetic_stress)
	if epenthetic_stress then
		stem = export.remove_accents(stem)
	end
	-- FIXME, any cases where we have to dereduce a sequence Cдз -> CVдз?
	local pre, letter, post = rmatch(stem, "^(.*)(" .. export.cons_c .. ")(" .. export.cons_c .. ")$")
	if not pre then
		return nil
	end
	local epvowel
	local is_upper = rfind(post, "%u")
	if post == "'" then
		-- сям'я́ "family" -> сяме́й
		post = "й"
		epvowel = "е"
	elseif rfind(letter, "[ьйЬЙ]") then
		-- аўстралі́йка "Australian woman" -> аўстралі́ек
		letter = ""
		if rfind(post, "[цЦ]") or not epenthetic_stress then
			epvowel = "е"
		else
			epvowel = "ё"
		end
	elseif rfind(letter, export.cons_except_always_hard_or_ts_c) and rfind(post, export.velar_c) or rfind(letter, export.velar_c) then
		if epenthetic_stress then
			epvowel = "о"
		else
			epvowel = "а"
		end
	elseif rfind(post, "[цЦ]") then
		if export.ends_always_hard(letter) then
			if epenthetic_stress then
				-- FIXME, is this right?
				epvowel = "э"
			else
				epvowel = "а"
			end
		else
			epvowel = "е"
		end
	elseif epenthetic_stress then
		if export.ends_always_hard_or_ts(letter) then
			epvowel = "о"
		else
			epvowel = "ё"
		end
	elseif export.ends_always_hard_or_ts(letter) then
		epvowel = "а"
	else
		epvowel = "е"
	end
	if letter == "ў" then
		letter = "в"
	elseif letter == "Ў" then
		letter = "В"
	end
	if rfind(epvowel, "[её]") then
		if letter == "т" then
			letter = "ц"
		elseif letter == "Т" then
			letter = "Ц"
		elseif letter == "д" then
			letter = "дз"
		elseif letter == "Д" then
			letter = is_upper and "ДЗ" or "Дз"
		end
	end
	if is_upper then
		epvowel = upper(epvowel)
	end
	if epenthetic_stress then
		epvowel = epvowel .. AC
	end
	return pre .. letter .. epvowel .. post
end


-- Handles the alternation between initial і/у and й/ў.
function export.initial_alternation(word, previous)
	if type(word) == "table" then
		word, previous = word.args[1], word.args[2]
	end
	local prev_ends_in_vowel = export.ends_in_vowel(previous)
	if rfind(word, "^[іІ][лр]" .. export.cons_c) and prev_ends_in_vowel then
		if rfind(word, "^І") then
			return rsub(word, "^І(.)", function(letter) return uupper(letter) end)
		else
			return rsub(word, "^і", "")
		end
	elseif rfind(word, "^[ЛРлр]" .. export.cons_c) and not prev_ends_in_vowel then
		if rfind(word, "^[ЛР]") then
			return "І" .. rsub(word, "^(.)", function(letter) return ulower(letter) end)
		else
			return "і" .. word
		end
	elseif rfind(word, "^[іІ]") or rfind(word, "^[йЙ]" .. export.non_vowel_c) then
		if prev_ends_in_vowel then
			return rsub(word, "^[іІ]", {["і"] = "й", ["І"] = "Й"})
		else
			return rsub(word, "^[йЙ]", {["й"] = "і", ["Й"] = "І"})
		end
	elseif rfind(word, "^[уУ]") or rfind(word, "^[ўЎ]" .. export.non_vowel_c) then
		if prev_ends_in_vowel then
			return rsub(word, "^[уУ]", {["у"] = "ў", ["У"] = "Ў"})
		else
			return rsub(word, "^[ўЎ]", {["ў"] = "у", ["Ў"] = "У"})
		end
	end
	
	return word
end


function export.u_v_alternation_msg(frame)
	local m_links = require("Module:links")
	local lang = require("Module:languages").getByCode("be")
	local params = {
		[1] = {}
	}
	local parargs = frame:getParent().args
	local args = require("Module:parameters").process(parargs, params)
	local alternant = args[1] or mw.title.getCurrentTitle().text
	local ualt, valt, ufirst
	if rfind(alternant, "^[ўЎ]") then
		valt = alternant
		ualt = rsub(export.add_monosyllabic_stress(valt), "^([ўЎ])", {["ў"] = "у", ["Ў"] = "У"})
		ufirst = false
	else
		ualt = alternant
		valt = export.remove_monosyllabic_accents(rsub(ualt, "^([уУ])", {["у"] = "ў", ["У"] = "Ў"}))
		ufirst = true
	end
	ualt = m_links.full_link({lang = lang, term = ualt}, "term") .. " (used after consonants or at the beginning of a clause)"
	valt = m_links.full_link({lang = lang, term = valt}, "term") .. " (used after vowels)"
	local first, second
	if ufirst then
		first, second = ualt, valt
	else
		first, second = valt, ualt
	end
	return "The forms " .. first .. " and " .. second .. " differ in pronunciation but are considered variants of the same word."
end


return export
