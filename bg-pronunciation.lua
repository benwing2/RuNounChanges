local export = {}

local gsub = mw.ustring.gsub
local U = mw.ustring.char

local grave = U(0x300)
local acute = U(0x301)
local stress = U(0x2C8)
local secondary_stress = U(0x2CC)
local tie = U(0x361)
local fronted = U(0x31F)
local dotunder = U(0x323)
local vowels = "aæɐəɤeɛioɔuʊʉ"
local vowels_c = "[" .. vowels .. "]"
local non_vowels_c = "[^" .. vowels .. "]"

-- single characters that map to IPA sounds
local phonetic_chars_map = {
	["а"] = "a",
	["б"] = "b",
	["в"] = "v",
	["г"] = "ɡ",
	["д"] = "d",
	["е"] = "ɛ",
	["ж"] = "ʒ",
	["з"] = "z",
	["и"] = "i",
	["й"] = "j",
	["к"] = "k",
	["л"] = "l",
	["м"] = "m",
	["н"] = "n",
	["о"] = "ɔ",
	["п"] = "p",
	["р"] = "r",
	["с"] = "s",
	["т"] = "t",
	["у"] = "u",
	["ф"] = "f",
	["х"] = "x",
	["ц"] = "t" .. tie .. "s",
	["ч"] = "t" .. tie .. "ʃ",
	["ш"] = "ʃ",
	["щ"] = "ʃt",
	["ъ"] = "ɤ",
	["ь"] = "ʲ",
	["ю"] = "ʲu",
	["я"] = "ʲa",

	[grave] = secondary_stress,
	[acute] = stress
}

local accent = "[" .. stress .. secondary_stress .. "]"

local devoicing = {
	['b'] = 'p', ['d'] = 't', ['ɡ'] = 'k',
	['z'] = 's', ['ʒ'] = 'ʃ',
	['v'] = 'f'
}

local voicing = {
	['p'] = 'b', ['t'] = 'd', ['k'] = 'ɡ',
	['s'] = 'z', ['ʃ'] = 'ʒ', ['x'] = 'ɣ',
	['f'] = 'v'
}


function export.remove_pron_notations(text, remove_grave)
	text = gsub(text, '[' .. dotunder .. ']', '')
	-- Remove grave accents from annotations but maybe not from phonetic respelling
	if remove_grave then
		text = mw.ustring.toNFC(gsub(mw.ustring.toNFD(text), grave, ""))
	end
	return text
end

	
function export.toIPA(term, endschwa)
	if type(term) == "table" then -- called from a template or a bot
		endschwa = term.args.endschwa
		term = term.args[1]
	end
		
	local origterm = term
	
	term = mw.ustring.toNFC(term):gsub("й", "j")
	term = mw.ustring.toNFD(mw.ustring.lower(term))

	if term:find(grave) and not term:find(acute) then
		error("Use acute accent, not grave accent, for primary stress: " .. origterm)
	end

	-- allow dotunder to signal same as endschwa=1	
	term = gsub(term, "а(" .. accent .. "?)" .. dotunder, "ъ%1")
	term = gsub(term, "я(" .. accent .. "?)" .. dotunder, "ʲɤ%1")
	term = gsub(term, '.', phonetic_chars_map)

	-- Mark word boundaries
	term = gsub(term, "(%s+)", "#%1#")
	term = "#" .. term .. "#"

	-- Convert verbal and definite endings
	if endschwa then
		term = gsub(term, "a(" .. stress .. "t?#)", "ɤ%1")
	end

	-- Change ʲ to j after vowels or word-initially
	term = gsub(term, "([" .. vowels .. "#]" .. accent .. "?)ʲ", "%1j")

	-- Move stress
	term = gsub(term, "([szʃʒ]?[bdɡptkxf]?[rlmnvj]?ʲ?" .. vowels_c .. ")(" .. accent .. ")", "%2%1")
	-- Don't understand the point of this and it can't possibly work.
	-- term = gsub(term, "([td]" .. tie .. " [szʃʒ]ʲ?)(" .. vowels_c .. ")(" .. accent .. ")", "%2%1")
	term = gsub(term, "([td]" .. tie .. "?)(" .. accent .. ")([szʃʒ])", "%2%1%3")
	term = gsub(term, "#([^#" .. vowels .. "]*)(" .. accent .. ")", "#%2%1")

	-- Vowel reduction
	term = gsub(term, "a(" .. non_vowels_c .. "*" .. accent .. ")", "ɐ%1")
	term = gsub(term, "(#[^#" .. stress .. secondary_stress .. "]*)(.)", function(a, b)
			if b == '#' then return a .. b else return gsub(a, "[aɔɤu]", { ['a'] = 'ə', ['ɔ'] = 'o', ['ɤ'] = 'ə', ['u'] = 'ʊ' }) .. b end end)
	term = gsub(term, "(" .. accent .. "[^aɛiɔuɤ#]*[aɛiɔuɤ])([^#" .. stress .. secondary_stress .. "]*)", function(a, b)
			return a .. gsub(b, "[aɔɤu]", { ['a'] = 'ə', ['ɔ'] = 'o', ['ɤ'] = 'ə', ['u'] = 'ʊ' }) end)
	term = gsub(term, "ʊ(" .. non_vowels_c .. "*" .. accent .. ")", "u%1")

	-- Vowel accommodation
	term = gsub(term, "([ʲj])[aɐə](" .. non_vowels_c .. "-[ʲj])", "%1æ%2")
	-- Do twice in case the fronting is required in two successive syllables
	term = gsub(term, "([ʲj])[aɐə](" .. non_vowels_c .. "-[ʲj])", "%1æ%2")
	term = gsub(term, "([ʲj])u(" .. non_vowels_c .. "-[ʲj])", "%1ʉ%2")
	-- Do twice in case the fronting is required in two successive syllables
	term = gsub(term, "([ʲj])u(" .. non_vowels_c .. "-[ʲj])", "%1ʉ%2")
	term = gsub(term, "([ʃʒʲj])([aouɤ])", "%1%2" .. fronted)
	term = gsub(term, "([ʃʒ])ɛ", "%1e")

	-- Palatalisation
	term = gsub(term, "([kɡxl])([ieɛ])", "%1ʲ%2")

	-- Hard l
	term = gsub(term, "l([^ʲ])", "ɫ%1")

	-- Voicing assimilation
	term = gsub(term, "([bdɡzʒv" .. tie .. "]*)(" .. accent .. "?[ptksʃfx#])", function(a, b)
		return gsub(a, '.', devoicing) .. b end)
	term = gsub(term, "([ptksʃfx" .. tie .. "]*)(" .. accent .. "?[bdɡzʒ])", function(a, b)
		return gsub(a, '.', voicing) .. b end)
	term = gsub(term, "n(" .. accent .. "?[ɡk]+)", "ŋ%1")
	term = gsub(term, "m(" .. accent .. "?[fv]+)", "ɱ%1")

	-- Sibilant assimilation
	term = gsub(term, "[sz](" .. accent .. "?[td]?" .. tie .. "?)([ʃʒ])", "%2%1%2")

	-- Reduce consonant clusters
	term = gsub(term, "([szʃʒ])[td](" .. accent .. "?)([tdknml])", "%2%1%3")
	term = gsub(term, "([sʃ])t#", "%1(t)#")

	-- ijC -> iːC, ij# -> iː#
	term = gsub(term, "ij(" .. non_vowels_c .. ")", "iː%1")

	-- Strip hashes
	term = gsub(term, "#", "")

	return term
end

function export.show(frame)
	local params = {
		[1] = {},
		["endschwa"] = { type = "boolean" },
		["ann"] = {},
	}
	
	local title = mw.title.getCurrentTitle()
	
	local args = require("Module:parameters").process(frame:getParent().args, params)
	local term = args[1] or title.nsText == "Template" and "при́мер" or title.text

	local ipa = export.toIPA(term, args.endschwa)
	
	ipa = "[" .. ipa .. "]"
	ipa = require("Module:IPA").format_IPA_full(require("Module:languages").getByCode("bg"), { { pron = ipa } } )

	local anntext
	if args.ann == "1" or args.ann == "y" then
		-- remove secondary stress annotations
		anntext = "'''" .. export.remove_pron_notations(term, true) .. "''':&#32;"
	elseif args.ann then
		anntext = "'''" .. args.ann .. "''':&#32;"
	else
		anntext = ""
	end

	return anntext .. ipa
end

return export
