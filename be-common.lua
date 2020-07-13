local export = {}

local u = mw.ustring.char
local rsplit = mw.text.split
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsubn = mw.ustring.gsub
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


local AC = u(0x0301) -- acute =  ́
local GR = u(0x0300) -- acute =  ̀
local DOTBELOW = u(0x0323) -- dot below =  ̣

export.vowel = "аеіоуяэыёюАЕІОУЯЭЫЁЮ"
export.vowel_c = "[" .. export.vowel .. "]"
export.non_vowel_c = "[^" .. export.vowel .. "]"
export.velar = "кгґх"
export.velar_c = "[" .. export.velar .. "]"
export.always_hard = "ршчж"
export.always_hard_c = "[" .. export.always_hard .. "]"
export.cons = "бцдфгґйклмнпрствхзчшжўь'БЦДФГҐЙКЛМНПРСТВХЗЧШЖЎЬ"
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
	["а"] = ["э"],
	["я"] = ["е"],
}

local ao_stresser = {
	["а"] = ["о"],
	["я"] = ["ё"],
}

-- Remove acute and grave accents; don't affect ёЁ.
function export.remove_accents(word)
	return rsub(word, "[́̀ѐЀѝЍ]", deaccenter)
end


function export.remove_variant_codes(word)
	return rsub(word, export.var_code_c, "")
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
	return rfind(word, export.vowel_c .. AC .. "?$")
end


-- Check if word ends in an always-hard consonant.
function export.ends_always_hard(word)
	return rfind(word, export.always_hard_c .. "$")
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

-- Apply a vowel_alternant specification ("ao", "ae" or nil) to the vowel directly
-- preceding the stress.
function export.apply_vowel_alternation(word, vowel_alternant)
	if vowel_alternant == "ao" then
		local new_word = rsub(word, "([ая])(" .. export.non_vowel_c .. "*" .. export.vowel_c .. AC .. ")",
			function(a_vowel, rest)
				return ao_stresser[a_vowel] .. rest
			end
		)
		if new_word == word then
			error("Indicator 'ao' can't be applied because word '" .. orig_word .. "' doesn't have an а or я as its last vowel")
		end
		return new_word
	elseif vowel_alternant == "ae" then
		local new_word = rsub(word, "([ая])(" .. export.non_vowel_c .. "*" .. export.vowel_c .. AC .. ")",
			function(a_vowel, rest)
				return ae_stresser[a_vowel] .. rest
			end
		)
		if new_word == word then
			error("Indicator 'ae' can't be applied because word '" .. orig_word .. "' doesn't have an а or я as its last vowel")
		end
		return new_word
	elseif vowel_alternant then
		error("Unrecognized vowel alternant '" .. vowel_alternant .. "'")
	else
		return word
	end
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


-- Undo extra diacritics added by `mark_stressed_vowels_in_unstressed_syllables`.
function export.undo_mark_stressed_vowels_in_unstressed_syllables(word)
	word = rsub(word, DOTBELOW, "")
	word = rsub(word, "([ёЁ])́", "%1")
	return word
end


-- Destress vowels in unstressed syllables. Vowels followed by DOTBELOW are unchanged;
-- otherwise, о -> а; э -> а; ё -> я directly before the stress, otherwise е;
-- е -> я directly before the stress. After that, remove extra diacritics added by
-- mark_stressed_vowels_in_unstressed_syllables().
function export.destress_vowels_after_stress_movement(word)
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
	return export.undo_mark_stressed_vowels_in_unstressed_syllables(word)
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


-- Move the stress notionally left one syllable from an unspecified syllable to
-- the right of the given stem to the last syllable of the stem. Doing this
-- stresses the last syllable and may cause a vowel alternation. If
-- `vowel_alternant` is given, it should be "ao" (in Latin letters) to indicate
-- a change from Cyrillic а -> о or я —> ё, and "ae" (in Latin letters) to
-- indicate a change from Cyrillic а -> э or я -> е.
function export.move_stress_left_onto_last_syllable(stem, vowel_alternant)
	local orig_stem = stem
	if rfind(stem, AC) then
		error("Stem '" .. stem .. "' already has stress on it")
	end
	stem = rsub(stem, "(" .. export.vowel_c .. ")(" .. export.non_vowel_c .. "-)$", "%1" .. AC .. "%2")
	if vowel_alternant == "ao" then
		local new_stem = rsub(stem, "([ая]́)", {["а́"] = "о́", ["я́"] = "ё"})
		if new_stem == stem then
			error("Indicator 'ao' can't be applied because stem '" .. orig_stem .. "' doesn't have an а or я as its last vowel")
		end
		stem = new_stem
	elseif vowel_alternant == "ae" then
		local new_stem = rsub(stem, "([ая]́)", {["а́"] = "э́", ["я́"] = "е́"})
		if new_stem == stem then
			error("Indicator 'ae' can't be applied because stem '" .. orig_stem .. "' doesn't have an а or я as its last vowel")
		end
		stem = new_stem
	elseif vowel_alternant then
		error("Unrecognized vowel alternant '" .. vowel_alternant .. "'")
	end
	-- An е that was two syllables to the left of the stress must turn into я.
	stem = rsub(stem, "е(" .. export.non_vowel_c .. "*" .. export.vowel_c ..
		export.non_vowel_c .. "*)$", "я%1")
	return stem
end


-- Move the stress notionally left one syllable from the last syllable to the
-- preceding one. Doing this may cause a vowel alternation. If `vowel_alternant`
-- is given, it should be "ao" (in Latin letters) to indicate a change from
-- Cyrillic а -> о or я —> ё, and "ae" (in Latin letters) to indicate a change
-- from Cyrillic а -> э or я -> е.
function export.move_stress_left_off_of_last_syllable(stem, vowel_alternant)
	local non_last_syllable, last_syllable = rmatch(stem, "^(.*)(" .. export.vowel_c .. export.non_vowel_c .. "*)$")
	non_last_syllable = export.move_stress_left_onto_last_syllable(non_last_syllable, vowel_alternant)
	last_syllable = export.make_unstressed(last_syllable)
	return non_last_syllable .. last_syllable
end


-- Move the stress notionally from the last syllable of the given stem to an
-- unspecified syllable directly to its right. Doing this destresses the last
-- syllable and may cause a vowel alternation. If `vowel_alternant` is given,
-- it should be have the value "ae" (in Latin letters) to indicate a change
-- from Cyrillic я -> underlying е in the syllable preceding the last syllable.
function export.move_stress_right_off_of_last_syllable(stem, vowel_alternant)
	local orig_stem = stem
	if not rfind(stem, "[́ёЁ]" .. export.non_vowel_c .. "*$") then
		error("Stem '" .. stem .. "' doesn't have stress on the last syllable")
	end
	if rfind(stem, AC .. ".*" .. export.vowel_c) then
		error("Stem '" .. stem .. "' has stress on a syllable other than the last")
	end
	stem = export.make_unstressed(stem, "pre-tonic")
	if vowel_alternant == "ae" then
		local new_stem = rsub(stem, "я(" .. export.non_vowel_c .. "*" .. export.vowel_c ..
			export.non_vowel_c .. "*)$", "е%1")
		if new_stem == stem then
			error("Indicator 'ae' can't be applied because stem '" .. orig_stem .. "' doesn't have a я as its next-to-last vowel")
		end
		stem = new_stem
	elseif vowel_alternant then
		error("Unrecognized vowel alternant '" .. vowel_alternant .. "'")
	end
	return stem
end


-- Move the stress notionally from the last syllable of the given stem to an
-- unspecified syllable two positions to its right. Doing this destresses the
-- last syllable and may cause a vowel alternation.
function export.move_stress_right_twice_off_of_last_syllable(stem)
	local orig_stem = stem
	if not rfind(stem, "[́ёЁ]" .. export.non_vowel_c .. "*$") then
		error("Stem '" .. stem .. "' doesn't have stress on the last syllable")
	end
	if rfind(stem, AC .. ".*" .. export.vowel_c) then
		error("Stem '" .. stem .. "' has stress on a syllable other than the last")
	end
	return export.make_unstressed(stem)
end


-- Move the stress notionally from an unspecified syllable directly to the
-- right of the last syllable of the stem to a position one syllable farther
-- to the right. This has no effect except when `vowel_alternant` is given.
-- In this case it should be have the value "ae" (in Latin letters) to indicate
-- a change from Cyrillic я -> underlying е in the last syllable of the stem.
function export.move_stress_right_when_stem_unstressed(stem, vowel_alternant)
	if vowel_alternant == "ae" then
		if not rfind(stem, "[яа](" .. export.non_vowel_c .. "*)$") then
			error("Indicator 'ae' can't be applied because stem '" .. stem .. "' doesn't have an а or я as its last vowel")
		end
		return rsub(stem, "я(" .. export.non_vowel_c .. "*)$", "е%1")
	elseif vowel_alternant then
		error("Unrecognized vowel alternant '" .. vowel_alternant .. "'")
	end
	return stem
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


-- If word is monosyllabic, add an accent mark to the vowel. Don't affect ёЁ.
function export.add_monosyllabic_accent(word)
	if export.is_monosyllabic(word) and not rfind(word, "^%-") and not rfind(word, "%-$") and
		not export.is_stressed(word) then
		word = rsub(word, "(" .. export.vowel_c .. ")", "%1" .. AC)
	end
	return word
end


function export.add_monosyllabic_stress(word)
	return export.add_monosyllabic_accent(word)
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


-- Handles the alternation between initial і/у and й/ў.
function export.initial_alternation(word, previous)
	if type(word) == "table" then
		word, previous = word.args[1], word.args[2]
	end
	if rfind(word, "^[іІ]") or rfind(word, "^[йЙ]" .. export.non_vowel_c) then
		if rfind(previous, export.vowel_c .. AC .. "?$") then
			return rsub(word, "^[іІ]", {["і"] = "й", ["І"] = "Й"})
		else
			return rsub(word, "^[йЙ]", {["й"] = "і", ["Й"] = "І"})
		end
	elseif rfind(word, "^[уУ]") or rfind(word, "^[ўЎ]" .. export.non_vowel_c) then
		if rfind(previous, export.vowel_c .. AC .. "?$") then
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
