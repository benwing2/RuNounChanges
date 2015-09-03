--[[
This module holds some commonly used functions for Russian language. It's for use from other modules, not #invoke.
]]

local export = {}

local u = mw.ustring.char
local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local ulower = mw.ustring.lower
local uupper = mw.ustring.upper
local usub = mw.ustring.sub

local AC = u(0x0301) -- acute =  ́

export.vowel = "аеиоуяэыёюіѣѵАЕИОУЯЭЫЁЮІѢѴ"
export.vowel_no_jo = "аеиоуяэыюіѣѵАЕИОУЯЭЫЮІѢѴ" -- omit ёЁ
export.cons_except_sib_c = "бдфгйклмнпрствхзьъБДФГЙКЛМНПРСТВХЗЬЪ"
export.sib = "шщчжШЩЧЖ"
export.sib_c = export.sib .. "цЦ"
export.cons = export.cons_except_sib_c .. export.sib_c
export.velar = "кгхКГХ"
export.uppercase = "АЕИОУЯЭЫЁЮІѢѴБДФГЙКЛМНПРСТВХЗЬЪШЩЧЖЦ"

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

-- this function enables the module to be called from a template
function export.main(frame)
    if type(export[frame.args[1]]) == 'function' then
        return export[frame.args[1]](frame.args[2], frame.args[3])
    else
        return export[frame.args[1]][frame.args[2]]
    end
end

function export.obo(phr) -- selects preposition о, об or обо for next phrase, which can start from punctuation
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

-- Apply Proto-Slavic iotation. This is the change that is affected by a Slavic -j- after a consonant.
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

function export.needs_accents(word)
	-- A word that has ё in it doesn't need an accent, as this vowel is inherently accented.
	if rfind(word, "\204\129") or rfind(word, "[ёЁ]") then
		return false
	-- A word needs accents if it contains more than one vowel
	elseif rfind(word, "[" .. export.vowel .. "].*[" .. export.vowel .. "]") then
		return true
	else
		return false
	end
end

function export.is_unstressed(word)
	return not rfind(word, "[ёЁ́]")
end

local deaccenter = {
    ["́"] = "", -- acute accent
    ["̀"] = "", -- grave accent
    ["̈"] = "", -- diaeresis
    ["ѐ"] = "е", -- composed Cyrillic chars w/grave accent
    ["Ѐ"] = "Е",
    ["ѝ"] = "и",
    ["Ѝ"] = "И",
}

function export.remove_accents(word)
	-- remove acute, grave and diaeresis (but not affecting composed ёЁ)
    return rsub(word, "[̀́̈ѐЀѝЍ]", deaccenter)
end

local destresser = mw.clone(deaccenter)
destresser["ё"] = "е"
destresser["Ё"] = "Е"

function export.make_unstressed(word)
    return rsub(word, "[̀́̈ёЁѐЀѝЍ]", destresser)
end

function export.make_unstressed_once(word)
    return rsub(word, "([̀́̈ёЁѐЀѝЍ])([^́̀̈ёЁѐЀѝЍ]*)$", function(x, rest) return destresser[x] .. rest; end, 1)
end

function export.make_ending_stressed(word)
	-- If already ending stressed, just return word so we don't mess up ё 
	if rfind(word, "[ёЁ][^" .. export.vowel .. "]*$") or
		rfind(word, "[" .. export.vowel .. "]́[^" .. export.vowel .. "]*$") then
		return word
	end
	word = export.make_unstressed_once(word)
	return rsub(word, "([" .. export.vowel_no_jo .. "])([^" .. export.vowel .. "]*)$",
		"%1́%2")
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
function export.reduce_stem(stem)
	local pre, letter, post

	pre, letter, post = rmatch(stem, "^(.*)([оОеЕёЁ])́?([" .. export.cons .. "]+)$")
	if not pre then
		return nil
	end
	if letter == "О" or letter == "о" then
		-- FIXME, what about when the accent is on the removed letter?
		if post == "й" or post == "Й" then
			-- FIXME, is this correct?
			return nil
		end
		return pre .. post
	end
	local is_upper = rfind(post, "[" .. export.uppercase .. "]")
	if rfind(pre, "[" .. export.vowel .. "]́?$") then
		return pre .. (is_upper and "Й" or "й") .. post
	end
	if post == "й" or post == "Й" then
		return pre .. (is_upper and "Ь" or "ь")
	end
	if	(rfind(post, "[" .. export.velar .. "]$") and
		 rfind(pre, "[" .. export.cons_except_sib_c .. "]$")) or
		(rfind(post, "[^йЙ" .. export.velar .. "]$") and
		 rfind(pre, "[лЛ]$")) then
		return pre .. (is_upper and "Ь" or "ь") .. post
	end
	return pre .. post
end

-- Generate the unreduced stem given STEM and EPENTHETIC_STRESS (which
-- indicates whether the epenthetic vowel should be stressed); this is
-- without any terminating non-syllabic ending, which is added if needed by
-- the calling function. Returns nil if unable to unreduce.
function export.unreduce_stem(stem, epenthetic_stress)
	if epenthetic_stress then
		stem = export.make_unstressed_once(stem)
	end

	local pre, letter, post
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
	if pre then
		local is_upper = rfind(post, "[" .. export.uppercase .. "]")
		local ret = nil
		if rfind(letter, "[ьйЬЙ]") then
			if rfind(post, "[цЦ]$") or not epenthetic_stress then
				ret = pre .. (is_upper and "Е" or "е") .. post
			else
				ret = pre .. (is_upper and "Ё" or "ё") .. post
			end
		elseif rfind(letter, "[" .. export.cons_except_sib_c .. "]") and rfind(post, "[" .. export.velar .. "]") or
				rfind(letter, "[" .. export.velar .. "]") then
			ret = pre .. letter .. (is_upper and "О" or "о") .. post
		elseif post == "ц" or post == "Ц" then
			ret = pre .. letter .. (is_upper and "Е" or "е") .. post
		elseif epenthetic_stress then
			if rfind(letter, "[" .. export.sib .. "]") then
				ret = pre .. letter .. (is_upper and "О́" or "о́") .. post
			else
				ret = pre .. letter .. (is_upper and "Ё" or "ё") .. post
			end
		else
			ret = pre .. letter .. (is_upper and "Е" or "е") .. post
		end
		assert ret
		if epenthetic_stress then
			ret = export.make_ending_stressed(ret)
		end
		return ret
	end
	return nil
end

return export
