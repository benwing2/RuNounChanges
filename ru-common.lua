--[[
This module holds some commonly used functions for the Russian language.
It's generally for use from other modules, not #invoke, although it can
be invoked from a template using export.main().

NOTE NOTE NOTE: All functions assume that transliteration (but not Russian)
has had its acute and grave accents decomposed using export.decompose().
This is the first thing that should be done to all user-specified
transliteration and any transliteration we compute that we expect to work with.
]]

local export = {}

local lang = require("Module:languages").getByCode("ru")

local strutils = require("Module:string utilities")

local u = mw.ustring.char
local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local ulower = mw.ustring.lower
local uupper = mw.ustring.upper
local usub = mw.ustring.sub

local AC = u(0x0301) -- acute =  ́
local GR = u(0x0300) -- grave =  ̀
local CFLEX = u(0x0302) -- circumflex =  ̂
local TILDE = u(0x0303) -- tilde =  ̃
local BREVE = u(0x0306) -- breve  ̆
local DIA = u(0x0308) -- diaeresis =  ̈
local CARON = u(0x030C) -- caron  ̌

-- any accent
export.accent = AC .. GR .. DIA .. BREVE .. TILDE .. CARON
-- regex for any optional accent(s)
export.opt_accent = "[" .. export.accent .. "]*"
-- any composed Cyrillic vowel with grave accent
export.composed_grave_vowel = "ѐЀѝЍ"
-- any Cyrillic vowel except ёЁ
export.vowel_no_jo = "аеиоуяэыюіѣѵАЕИОУЯЭЫЮІѢѴ" .. export.composed_grave_vowel
-- any Cyrillic vowel, including ёЁ
export.vowel = export.vowel_no_jo .. "ёЁ"
-- any vowel in transliteration
export.tr_vowel = "aeěɛiouyAEĚƐIOUY"
-- any consonant in transliteration, omitting soft/hard sign
export.tr_cons_no_sign = "bcčdfghjklmnpqrsštvwxzžBCČDFGHJKLMNPQRSŠTVWXZŽ"
-- any consonant in transliteration, including soft/hard sign
export.tr_cons = export.tr_cons_no_sign .. "ʹʺ"
-- regex for any consonant in transliteration, including soft/hard sign,
-- optionally followed by any accent
export.tr_cons_acc_re = "[" .. export.tr_cons .. "]" .. export.opt_accent
-- any Cyrillic consonant except sibilants and ц
export.cons_except_sib_c = "бдфгйклмнпрствхзьъБДФГЙКЛМНПРСТВХЗЬЪ"
-- Cyrillic sibilant consonants
export.sib = "шщчжШЩЧЖ"
-- Cyrillic sibilant consonants and ц
export.sib_c = export.sib .. "цЦ"
-- any Cyrillic consonant
export.cons = export.cons_except_sib_c .. export.sib_c
-- Cyrillic velar consonants
export.velar = "кгхКГХ"
-- uppercase Cyrillic consonants
export.uppercase = "АЕИОУЯЭЫЁЮІѢѴБДФГЙКЛМНПРСТВХЗЬЪШЩЧЖЦ"

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

-- this function enables the module to be called from a template;
-- FIXME, does this actually work?
function export.main(frame)
    if type(export[frame.args[1]]) == 'function' then
        return export[frame.args[1]](frame.args[2], frame.args[3])
    else
        return export[frame.args[1]][frame.args[2]]
    end
end

-- selects preposition о, об or обо for next phrase, which can start from
-- punctuation
function export.obo(phr)
    --Algorithm design is mainly inherited from w:ru:template:Обо
    local w = rmatch(phr,"[%p%s%c]*(.-)[%p%s%c]") or rmatch(phr,"[%p%s%c]*(.-)$")
    if not w then return nil end
    if string.find(" всей всём всех мне ",' '..ulower(w)..' ',1,true) then return 'обо' end
    local ws=usub(w,1,2)
    if ws==uupper(ws) then -- abbrev
        if rmatch(ws,"^[ЙУНФЫАРОЛЭСМИRYUIOASFHLXNMÖÜÄΑΕΟΥΩ]") then return 'об' else return 'о' end
    elseif rmatch(uupper(w),"^[АОЭИУЫAOIEÖÜÄΑΕΟΥΩ]") then
        return 'об'
    else
        return 'о'
    end
end

-- Apply Proto-Slavic iotation. This is the change that is affected by a
-- Slavic -j- after a consonant.
function export.iotation(stem, shch)
    stem = rsub(stem, "[сх]$", "ш")
    stem = rsub(stem, "ск$", "щ")
    stem = rsub(stem, "ст$", "щ")
    stem = rsub(stem, "[кц]$", "ч")

    -- normally "т" is iotated as "ч" but there are many verbs that are iotated with "щ"
    if shch == "щ" then
        stem = rsub(stem, "т$", "щ")
    else
        stem = rsub(stem, "т$", "ч")
    end

    stem = rsub(stem, "[гдз]$", "ж")

    stem = rsub(stem, "([бвмпф])$", "%1л")

    return stem
end

-- Does a set of Cyrillic words in connected text need accents? We need to
-- split by word and check each one.
function export.needs_accents(text)
	local function word_needs_accents(word)
		-- A word needs accents if it is unstressed and contains more than
		-- one vowel
		return export.is_unstressed(word) and not export.is_monosyllabic(word)
	end
	local words = rsplit(text, "%s")
	for _, word in ipairs(words) do
		if word_needs_accents(word) then
			return true
		end
	end
	return false
end

-- True if Cyrillic word is stressed (acute or diaeresis)
function export.is_stressed(word)
	-- A word that has ё in it is inherently stressed.
	-- diaeresis occurs in сѣ̈дла plural of сѣдло́
	return rfind(word, "[́̈ёЁ]")
end

-- True if Cyrillic word has no stress mark (acute or diaeresis)
function export.is_unstressed(word)
	return not export.is_stressed(word)
end

-- True if Cyrillic word is stressed on the last syllable
function export.is_ending_stressed(word)
	return rfind(word, "[ёЁ][^" .. export.vowel .. "]*$") or
		rfind(word, "[" .. export.vowel .. "][́̈][^" .. export.vowel .. "]*$")
end

-- True if a Cyrillic word has two or more stresses (acute or diaeresis)
function export.is_multi_stressed(word)
	word = rsub(word, "[ёЁ]", "е́")
	return rfind(word, "[" .. export.vowel .. "][́̈].*[" .. export.vowel .. "][́̈]")
end

-- True if Cyrillic word is stressed on the first syllable
function export.is_beginning_stressed(word)
	return rfind(word, "^[^" .. export.vowel .. "]*[ёЁ]") or
		rfind(word, "^[^" .. export.vowel .. "]*[" .. export.vowel .. "]́")
end

-- True if Cyrillic word has no vowel
function export.is_nonsyllabic(word)
	return not rfind(word, "[" .. export.vowel .. "]")
end

-- True if Cyrillic word has no more than one vowel; includes non-syllabic
-- stems such as льд-
function export.is_monosyllabic(word)
	return not rfind(word, "[" .. export.vowel .. "].*[" .. export.vowel .. "]")
end

local recomposer = {
	["и" .. BREVE] = "й",
	["И" .. BREVE] = "Й",
	["е" .. DIA] = "ё", -- WARNING: Cyrillic е and Е
	["Е" .. DIA] = "Ё",
	["e" .. CARON] = "ě", -- WARNING: Latin e and E
	["E" .. CARON] = "Ě",
	["c" .. CARON] = "č",
	["C" .. CARON] = "Č",
	["s" .. CARON] = "š",
	["S" .. CARON] = "Š",
	["z" .. CARON] = "ž",
	["Z" .. CARON] = "Ž",
	-- used in ru-pron:
	["ж" .. BREVE] = "ӂ", -- used in ru-pron
	["Ж" .. BREVE] = "Ӂ",
	["j" .. CFLEX] = "ĵ",
	["J" .. CFLEX] = "Ĵ",
	["j" .. CARON] = "ǰ",
	-- no composed uppercase equivalent of J-caron
	["ʒ" .. CARON] = "ǯ",
	["Ʒ" .. CARON] = "Ǯ",
}

-- Decompose acute, grave, etc. on letters (esp. Latin) into individivual
-- character + combining accent. But recompose Cyrillic and Latin characters
-- that we want to treat as units and get caught in the crossfire. We mostly
-- want acute and grave decomposed; perhaps should just explicitly decompose
-- those and no others.
function export.decompose(text)
	text = mw.ustring.toNFD(text)
	text = rsub(text, ".[" .. BREVE .. DIA .. CARON .. "]", recomposer)
	return text
end

function export.assert_decomposed(text)
	assert(not rfind(text, "[áéíóúýàèìòùỳäëïöüÿÁÉÍÓÚÝÀÈÌÒÙỲÄËÏÖÜŸ]"))
end

-- Transliterate text and then apply acute/grave decomposition.
function export.translit(text)
	return export.decompose(lang:transliterate(text))
end

-- Recompose acutes and graves into preceding vowels. Probably not necessary.
function export.recompose(text)
	return mw.ustring.toNFC(text)
end

local grave_decomposer = {
    ["ѐ"] = "е" .. GR,
    ["Ѐ"] = "Е" .. GR,
    ["ѝ"] = "и" .. GR,
    ["Ѝ"] = "И" .. GR,
}

-- decompose precomposed Cyrillic chars w/grave accent; not necessary for
-- acute accent as there aren't precomposed Cyrillic chars w/acute accent,
-- and undesirable for precomposed ё and Ё
function export.decompose_grave(word)
    return rsub(word, "[ѐЀѝЍ]", grave_decomposer)
end

local grave_deaccenter = {
    [GR] = "", -- grave accent
    ["ѐ"] = "е", -- composed Cyrillic chars w/grave accent
    ["Ѐ"] = "Е",
    ["ѝ"] = "и",
    ["Ѝ"] = "И",
}

local deaccenter = mw.clone(grave_deaccenter)
deaccenter[AC] = "" -- acute accent

-- remove acute and grave accents; don't affect composed diaeresis in ёЁ or
-- uncomposed diaeresis in -ѣ̈- (as in plural сѣ̈дла of сѣдло́)
function export.remove_accents(word, tr)
    local ru_removed = rsub(word, "[́̀ѐЀѝЍ]", deaccenter)
	if not tr then
		return ru_removed, nil
	end
	return ru_removed, rsub(tr, "[" .. AC .. GR .. "]", deaccenter)
end

-- remove acute and grave accents in monosyllabic words; don't affect
-- diaeresis (composed or uncomposed) because it indicates a change in vowel
-- quality, which still applies to monosyllabic words
function export.remove_monosyllabic_accents(word, tr)
	if export.is_monosyllabic(word) then
		return export.remove_accents(word, tr)
	else
		return word, tr
	end
end

local destresser = mw.clone(deaccenter)
destresser["ё"] = "е"
destresser["Ё"] = "Е"
destresser["̈"] = "" -- diaeresis

-- Subfunction of split_syllables(). On input we get sections of text
-- consisting of CONSONANT - VOWEL - CONSONANT - VOWEL ... - CONSONANT,
-- where CONSONANT consists of zero or more consonants and VOWEL consists
-- of exactly one vowel plus any following accent(s); we combine these into
-- syllables as required by split_syllables().
local function combine_captures(captures)
	if #captures == 1 then
		return captures
	end
	local combined = {}
	for i = 1,(#captures-1),2 do
		table.insert(combined, captures[i] .. captures[i+1])
	end
	combined[#combined] = combined[#combined] .. captures[#captures]
	return combined
end

-- Split Russian text and transliteration into syllables. Syllables end with
-- vowel + accent(s), except for the last syllable, which includes any
-- trailing consonants.
local function split_syllables(ru, tr)
	export.assert_decomposed(tr)
	-- Split into alternating consonant/vowel sequences, as described in
	-- combine_captures(). Uses capturing_split(), which is like rsplit()
	-- but also includes any capturing groups in the split pattern.
	local rusyllables = combine_captures(strutils.capturing_split(ru, "([" .. export.vowel .. "]" .. export.opt_accent .. ")"))
	local trsyllables = combine_captures(strutils.capturing_split(tr, "([" .. export.tr_vowel .. "]" .. export.opt_accent .. ")"))
	--error(table.concat(rusyllables, "/") .. "(" .. #rusyllables .. ") || " .. table.concat(trsyllables, "/") .. "(" .. #trsyllables .. ")")
	if #rusyllables ~= #trsyllables then
		error("Russian " .. ru .. " doesn't have same number of syllables as translit " .. tr)
	end
	return rusyllables, trsyllables
end

-- Apply j correction, converting je to e after consonants, jo to o after
-- a sibilant, ju to u after hard sibilant.
function export.j_correction(tr)
	tr = rsub(tr, "([" .. export.tr_cons_no_sign .. "]" .. export.opt_accent ..")[Jj]([EeĚě])", "%1%2")
	tr = rsub(tr, "([žščŽŠČ])[Jj]([Oo])", "%1%2")
	tr = rsub(tr, "([žšŽŠ])[Jj]([Uu])", "%1%2")
	return tr
end

local function make_unstressed_ru(ru)
	-- The following regexp has grave+acute+diaeresis after the bracket
	--
	return rsub(ru, "[̀́̈ёЁѐЀѝЍ]", destresser)
end

-- remove all stress marks (acute, grave, diaeresis)
function export.make_unstressed(ru, tr)
	if not tr then
		return make_unstressed_ru(ru), nil
	end
	-- In the presence of TR, we need to do things the hard way: Splitting
	-- into syllables and only converting Latin o to e opposite a ё.
	rusyl, trsyl = split_syllables(ru, tr)
	for i=1,#rusyl do
		if rfind(rusyl[i], "[ёЁ]") then
			trsyl[i] = rsub(trsyl[i], "[Oo]", {["O"] = "E", ["o"] = "e"})
		end
		rusyl[i] = make_unstressed_ru(rusyl[i])
		-- the following should still work as it will affect accents only
		trsyl[i] = make_unstressed_ru(trsyl[i])
	end
	-- Also need to apply j correction as otherwise we'll have je after cons, etc.
	return table.concat(rusyl, ""),
		export.j_correction(table.concat(trsyl, ""))
end

function remove_jo_ru(word)
    return rsub(word, "[̈ёЁ]", destresser)
end

-- remove diaeresis stress marks only
function export.remove_jo(ru, tr)
	if not tr then
		return remove_jo_ru(ru), nil
	end
	-- In the presence of TR, we need to do things the hard way: Splitting
	-- into syllables and only converting Latin o to e opposite a ё.
	rusyl, trsyl = split_syllables(ru, tr)
	for i=1,#rusyl do
		if rfind(rusyl[i], "[ёЁ]") then
			trsyl[i] = rsub(trsyl[i], "[Oo]", {["O"] = "E", ["o"] = "e"})
		end
		rusyl[i] = remove_jo_ru(rusyl[i])
		-- the following should still work as it will affect accents only
		trsyl[i] = make_unstressed_once_ru(trsyl[i])
	end
	-- Also need to apply j correction as otherwise we'll have je after cons, etc.
	return table.concat(rusyl, ""),
		export.j_correction(table.concat(trsyl, ""))
end

local function make_unstressed_once_ru(word)
	-- leave graves alone
    return rsub(word, "([́̈ёЁ])([^́̈ёЁ]*)$", function(x, rest) return destresser[x] .. rest; end, 1)
end

-- make last stressed syllable (acute or diaeresis) unstressed; leave
-- graves alone; if NOCONCAT, return individual syllables
function export.make_unstressed_once(ru, tr, noconcat)
	if not tr then
		return make_unstressed_once_ru(ru), nil
	end
	-- In the presence of TR, we need to do things the hard way, as with
	-- make_unstressed().
	rusyl, trsyl = split_syllables(ru, tr)
	for i=#rusyl,1,-1 do
		local stressed = export.is_stressed(rusyl[i])
		if stressed then
			if rfind(rusyl[i], "[ёЁ]") then
				trsyl[i] = rsub(trsyl[i], "[Oo]", {["O"] = "E", ["o"] = "e"})
			end
			rusyl[i] = make_unstressed_once_ru(rusyl[i])
			-- the following should still work as it will affect accents only
			trsyl[i] = make_unstressed_once_ru(trsyl[i])
			break
		end
	end
	if noconcat then
		return rusyl, trsyl
	end
	-- Also need to apply j correction as otherwise we'll have je after cons
	return table.concat(rusyl, ""),
		export.j_correction(table.concat(trsyl, ""))
end

local function make_unstressed_once_at_beginning_ru(word)
	-- leave graves alone
    return rsub(word, "^([^́̈ёЁ]*)([́̈ёЁ])", function(rest, x) return rest .. destresser[x]; end, 1)
end

-- make first stressed syllable (acute or diaeresis) unstressed; leave
-- graves alone; if NOCONCAT, return individual syllables
function export.make_unstressed_once_at_beginning(ru, tr, noconcat)
	if not tr then
		return make_unstressed_once_at_beginning_ru(ru), nil
	end
	-- In the presence of TR, we need to do things the hard way, as with
	-- make_unstressed().
	rusyl, trsyl = split_syllables(ru, tr)
	for i=1,#rusyl do
		local stressed = export.is_stressed(rusyl[i])
		if stressed then
			if rfind(rusyl[i], "[ёЁ]") then
				trsyl[i] = rsub(trsyl[i], "[Oo]", {["O"] = "E", ["o"] = "e"})
			end
			rusyl[i] = make_unstressed_once_at_beginning_ru(rusyl[i])
			-- the following should still work as it will affect accents only
			trsyl[i] = make_unstressed_once_at_beginning_ru(trsyl[i])
			break
		end
	end
	if noconcat then
		return rusyl, trsyl
	end
	-- Also need to apply j correction as otherwise we'll have je after cons
	return table.concat(rusyl, ""),
		export.j_correction(table.concat(trsyl, ""))
end

-- subfunction of make_ending_stressed(), make_beginning_stressed(), which
-- add an acute accent to a syllable that may already have a grave accent;
-- in such a case, remove the grave
function export.correct_grave_acute_clash(word, tr)
	word = rsub(word, "([̀ѐЀѝЍ])́", function(x) return grave_deaccenter[x] .. AC; end)
	word = rsub(word, AC .. GR, AC)
	if not tr then
		return word, nil
	end
	tr = rsub(tr, GR .. AC, AC)
	tr = rsub(tr, AC .. GR, AC)
	return word, tr
end

local function make_ending_stressed_ru(word)
	-- If already ending stressed, just return word so we don't mess up ё
	if export.is_ending_stressed(word) then
		return word
	end
	-- Destress the last stressed syllable
	word = make_unstressed_once_ru(word)
	-- Add an acute to the last syllable
	word = rsub(word, "([" .. export.vowel_no_jo .. "])([^" .. export.vowel .. "]*)$",
		"%1́%2")
	-- If that caused an acute and grave next to each other, remove the grave
	return export.correct_grave_acute_clash(word)
end

-- Remove the last primary stress from the word and put it on the final
-- syllable. Leave grave accents alone except in the last syllable.
-- If final syllable already has primary stress, do nothing.
function export.make_ending_stressed(ru, tr)
	if not tr then
		return make_ending_stressed_ru(ru), nil
	end
	-- If already ending stressed, just return ru/tr so we don't mess up ё
	if export.is_ending_stressed(ru) then
		return ru, tr
	end
	-- Destress the last stressed syllable; pass in "noconcat" so we get
	-- the individual syllables back
	rusyl, trsyl = export.make_unstressed_once(ru, tr, "noconcat")
	-- Add an acute to the last syllable of both Russian and translit
	rusyl[#rusyl] = rsub(rusyl[#rusyl], "([" .. export.vowel_no_jo .. "])",
		"%1" .. AC)
	trsyl[#trsyl] = rsub(trsyl[#trsyl], "([" .. export.tr_vowel .. "])",
		"%1" .. AC)
	-- If that caused an acute and grave next to each other, remove the grave
	rusyl[#rusyl], trsyl[#trsyl] =
		export.correct_grave_acute_clash(rusyl[#rusyl], trsyl[#trsyl])
	-- j correction didn't get applied in make_unstressed_once because
	-- we short-circuited it and made it return lists of syllables
	return table.concat(rusyl, ""),
		export.j_correction(table.concat(trsyl, ""))
end

local function make_beginning_stressed_ru(word)
	-- If already beginning stressed, just return word so we don't mess up ё
	if export.is_beginning_stressed(word) then
		return word
	end
	-- Destress the first stressed syllable
	word = make_unstressed_once_at_beginning_ru(word)
	-- Add an acute to the first syllable
	word = rsub(word, "^([^" .. export.vowel .. "]*)([" .. export.vowel_no_jo .. "])",
		"%1%2́")
	-- If that caused an acute and grave next to each other, remove the grave
	return export.correct_grave_acute_clash(word)
end

-- Remove the first primary stress from the word and put it on the initial
-- syllable. Leave grave accents alone except in the first syllable.
-- If initial syllable already has primary stress, do nothing.
function export.make_beginning_stressed(ru, tr)
	if not tr then
		return make_beginning_stressed_ru(ru), nil
	end
	-- If already beginning stressed, just return ru/tr so we don't mess up ё
	if export.is_beginning_stressed(ru) then
		return ru, tr
	end
	-- Destress the first stressed syllable; pass in "noconcat" so we get
	-- the individual syllables back
	rusyl, trsyl = export.make_unstressed_once_at_beginning(ru, tr, "noconcat")
	-- Add an acute to the first syllable of both Russian and translit
	rusyl[1] = rsub(rusyl[1], "([" .. export.vowel_no_jo .. "])",
		"%1" .. AC)
	trsyl[1] = rsub(trsyl[1], "([" .. export.tr_vowel .. "])",
		"%1" .. AC)
	-- If that caused an acute and grave next to each other, remove the grave
	rusyl[1], trsyl[1] = export.correct_grave_acute_clash(rusyl[1], trsyl[1])
	-- j correction didn't get applied in make_unstressed_once_at_beginning
	-- because we short-circuited it and made it return lists of syllables
	return table.concat(rusyl, ""),
		export.j_correction(table.concat(trsyl, ""))
end

-- used for tracking and categorization
trailing_letter_type = {
	["ш"] = {"sibilant", "cons"},
	["щ"] = {"sibilant", "cons"},
	["ч"] = {"sibilant", "cons"},
	["ж"] = {"sibilant", "cons"},
	["ц"] = {"c", "cons"},
	["к"] = {"velar", "cons"},
	["г"] = {"velar", "cons"},
	["х"] = {"velar", "cons"},
	["ь"] = {"soft-cons", "cons"},
	["ъ"] = {"hard-cons", "cons"},
	["й"] = {"palatal", "cons"},
	["а"] = {"vowel", "hard-vowel"},
	["я"] = {"vowel", "soft-vowel"},
	["э"] = {"vowel", "hard-vowel"},
	["е"] = {"vowel", "soft-vowel"},
	["ѣ"] = {"vowel", "soft-vowel"},
	["и"] = {"i", "vowel", "soft-vowel"},
	["і"] = {"i", "vowel", "soft-vowel"},
	["ѵ"] = {"i", "vowel", "soft-vowel"},
	["ы"] = {"vowel", "hard-vowel"},
	["о"] = {"vowel", "hard-vowel"},
	["ё"] = {"vowel", "soft-vowel"},
	["у"] = {"vowel", "hard-vowel"},
	["ю"] = {"vowel", "soft-vowel"},
}

function export.get_stem_trailing_letter_type(stem)
	local hint = ulower(usub(export.remove_accents(stem), -1))
	local hint_types = trailing_letter_type[hint] or {"hard-cons", "cons"}
	return hint_types
end

-- Reduce stem by eliminating the "epenthetic" vowel. Applies to
-- nominative singular masculine 2nd-declension hard and soft, and
-- 3rd-declension feminine in -ь (e.g. любовь). STEM should be the
-- result after calling detect_stem_type(), but with final -й if
-- present.
function export.reduce_stem(stem, tr)
	local pre, letter, post
	local pretr, lettertr, posttr

	pre, letter, post = rmatch(stem, "^(.*)([оОеЕёЁ])́?([" .. export.cons .. "]+)$")
	if not pre then
		return nil, nil
	end
	if tr then
		pretr, lettertr, posttr = rmatch(tr, "^(.*)([oOeE])́?([" .. export.tr_cons .. "][" .. export.tr_cons .. export.accent .. "]*)$")
		if not pretr then
			return nil, nil -- should not happen unless tr is really messed up
		end
	end
	if letter == "О" or letter == "о" then
		-- FIXME, what about when the accent is on the removed letter?
		if post == "й" or post == "Й" then
			-- FIXME, is this correct?
			return nil, nil
		end
		letter = ""
	else
		local is_upper = rfind(post, "[" .. export.uppercase .. "]")
		if rfind(pre, "[" .. export.vowel .. "]́?$") then
			letter = is_upper and "Й" or "й"
		elseif post == "й" or post == "Й" then
			letter = is_upper and "Ь" or "ь"
			post = ""
		elseif (rfind(post, "[" .. export.velar .. "]$") and
			 rfind(pre, "[" .. export.cons_except_sib_c .. "]$")) or
			(rfind(post, "[^йЙ" .. export.velar .. "]$") and
			 rfind(pre, "[лЛ]$")) then
			letter = is_upper and "Ь" or "ь"
		else
			letter = ""
		end
	end
	stem = pre .. letter .. post
	if tr then
		tr = pretr .. export.translit(letter) .. posttr
		-- the following is necessary to deal with cases where ё gets
		-- replaced with ь
		tr = rsub(tr, "[jJ]ʹ", "ʹ")
	end
	return stem, tr
end

-- Generate the dereduced stem given STEM and EPENTHETIC_STRESS (which
-- indicates whether the epenthetic vowel should be stressed); this is
-- without any terminating non-syllabic ending, which is added if needed by
-- the calling function. Returns nil if unable to dereduce.
function export.dereduce_stem(stem, tr, epenthetic_stress)
	if epenthetic_stress then
		stem, tr = export.make_unstressed_once(stem, tr)
	end

	local pre, letter, post
	local pretr, lettertr, posttr
	-- FIXME!!! Deal with this special case
	--if not (z.stem_type == 'soft' and _.equals(z.stress_type, {'b', 'f'}) -- we should ignore asterix for 2*b and 2*f (so to process it just like 2b or 2f)
	--		 or _.contains(z.specific, '(2)') and _.equals(z.stem_type, {'velar', 'letter-ц', 'vowel'}))  -- and also the same for (2)-specific and 3,5,6 stem-types
	--then

	-- I think this corresponds to our -ья and -ье types, which we
	-- handle separately
	--if z.stem_type == 'vowel' then  -- 1).
	--	if _.equals(z.stress_type, {'b', 'c', 'e', 'f', "f'", "b'" }) then  -- gen_pl ending stressed  -- TODO: special vars for that
	--		z.stems['gen_pl'] = _.replace(z.stems['gen_pl'], 'ь$', 'е́')
	--	else
	--		z.stems['gen_pl'] = _.replace(z.stems['gen_pl'], 'ь$', 'и')
	--	end
	--end

	pre, letter, post = rmatch(stem, "^(.*)([" .. export.cons .. "])([" .. export.cons .. "])$")
	if tr then
		pretr, lettertr, posttr = rmatch(tr, "^(.*)(" .. export.tr_cons_acc_re .. ")(" .. export.tr_cons_acc_re .. ")$")
		if pre and not pretr then
			return nil, nil -- should not happen unless tr is really messed up
		end
	end
	if pre then
		local is_upper = rfind(post, "[" .. export.uppercase .. "]")
		local epvowel
		if rfind(letter, "[ьйЬЙ]") then
			letter = ""
			lettertr = ""
			if rfind(post, "[цЦ]$") or not epenthetic_stress then
				epvowel = is_upper and "Е" or "е"
			else
				epvowel = is_upper and "Ё" or "ё"
			end
		elseif rfind(letter, "[" .. export.cons_except_sib_c .. "]") and rfind(post, "[" .. export.velar .. "]") or
				rfind(letter, "[" .. export.velar .. "]") then
			epvowel = is_upper and "О" or "о"
		elseif post == "ц" or post == "Ц" then
			epvowel = is_upper and "Е" or "е"
		elseif epenthetic_stress then
			if rfind(letter, "[" .. export.sib .. "]") then
				epvowel = is_upper and "О́" or "о́"
			else
				epvowel = is_upper and "Ё" or "ё"
			end
		else
			epvowel = is_upper and "Е" or "е"
		end
		assert(epvowel)
		stem = pre .. letter .. epvowel .. post
		if tr then
			tr = pretr .. lettertr .. export.translit(epvowel) .. posttr
			tr = export.j_correction(tr)
		end

		if epenthetic_stress then
			stem, tr = export.make_ending_stressed(stem, tr)
		end
		return stem, tr
	end
	return nil, nil
end

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
