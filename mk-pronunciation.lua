local export = {}

local u = mw.ustring.char
local rsubn = mw.ustring.gsub
local ulower = mw.ustring.lower

local lang = require("Module:languages").getByCode("mk")

local AC = u(0x301)
local SYLLABIC = u(0x329)
local TIE = u(0x361)

local phonetic_chars_map = {
	["а"] = "a",
	["е"] = "ɛ", ["ѐ"] = "ɛ",
	["и"] = "i", ["ѝ"] = "i",
	["о"] = "ɔ",
	["у"] = "u",
	
	["б"] = "b",
	["в"] = "v",
	["г"] = "ɡ",
	["д"] = "d",
	["ѓ"] = "ɟ",
	["ж"] = "ʒ",
	["з"] = "z",
	["ѕ"] = "d" .. TIE .. "z",
	["ј"] = "j",
	["к"] = "k",
	["л"] = "ɫ",
	["љ"] = "ʎ",
	["м"] = "m",
	["н"] = "n",
	["њ"] = "ɲ",
	["п"] = "p",
	["р"] = "r",
	["с"] = "s",
	["т"] = "t",
	["ќ"] = "c",
	["ф"] = "f",
	["х"] = "x",
	["ц"] = "t" .. TIE .. "s",
	["ч"] = "t" .. TIE .. "ʃ",
	["џ"] = "d" .. TIE .. "ʒ",
	["ш"] = "ʃ",

	["’"] = "ə",
	[AC] = "ˈ",
	["`"] = "ˈ"
}

local devoicing = {
	['b'] = 'p', ['d'] = 't', ['ɟ'] = 'c', ['ɡ'] = 'k',
	['z'] = 's', ['ʒ'] = 'ʃ',
	['v'] = 'f', [TIE] = TIE
}

local vowel = "aɛiɔuə"
local vocalic = vowel .. SYLLABIC
local vocalic_c = "[" .. vocalic .. "]"

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

-- version of rsubn() that returns a 2nd argument boolean indicating whether
-- a substitution was made.
local function rsubb(term, foo, bar)
	local retval, nsubs = rsubn(term, foo, bar)
	return retval, nsubs > 0
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

function export.toIPA(text)
	text = mw.ustring.toNFC(ulower(text))

	-- convert commas and en/en dashes to text foot boundaries
	text = rsub(text, "%s*[,–—]%s*", " | ")
	-- question mark or exclamation point in the middle of a sentence -> text foot boundary
	text = rsub(text, "([^%s])%s*[!?]%s*([^%s])", "%1 | %2")
	text = rsub(text, "[!?]", "") -- eliminate remaining punctuation

	-- canonicalize multiple spaces and remove leading and trailing spaces
	local function canon_spaces(text)
		text = rsub(text, "%s+", " ")
		text = rsub(text, "^ ", "")
		text = rsub(text, " $", "")
		return text
	end

	-- Convert hyphens to spaces. FIXME: Prefixes and suffixes should be unstressed unless explicitly marked for stress.
	text = rsub(text, "%-", " ")
	-- canonicalize multiple spaces, which may have been introduced by hyphens.
	text = canon_spaces(text)
	-- Put # at word beginning and end and double ## at text/foot boundary beginning/end.
	text = rsub(text, " | ", "# | #")
	text = "##" .. rsub(text, " ", "# #") .. "##"

	text = rsub(text, ".", phonetic_chars_map)

	-- Syllabic sonorants
	text = rsub_repeatedly(text, "([^" .. vocalic .. "ˈ])([rɫlʎ])([^" .. vowel .. "])", "%1%2" .. SYLLABIC .. "%3")
	text = rsub_repeatedly(text, "([^" .. vocalic .. "rɫlʎˈ])([nmɲɲ])([^" .. vowel .. "rɫlʎmnɲ])", "%1%2" .. SYLLABIC .. "%3")
	text = rsub(text, "ər", "r" .. SYLLABIC)

	-- Mark stress
	text = rsub(text, "(#[^#ˈ ]*" .. vocalic_c .. ")([^#ˈ ]*" .. vocalic_c .. "[^#ˈ ]*" .. vocalic_c .. "[^#ˈ ]*#)", "%1ˈ%2")
	text = rsub(text, "(#[^#ˈ ]*" .. vocalic_c .. ")([^#ˈ ]*" .. vocalic_c .. "[^#ˈ ]*#)", "%1ˈ%2")
	text = rsub(text, "([szʃʒ]?[ptckbdɟɡfxmnɲ]?[mnɲv]?[rɫljʎ]?" .. vocalic_c .. ")ˈ", "ˈ%1")
	text = rsub(text, "([td]" .. TIE .. "[szʃʒ]?)ˈ", "ˈ%1")
	text = rsub(text, "#([^#aɛiɔuə" .. SYLLABIC .. " ]*)ˈ", "#ˈ%1")

	-- Palatalisation
	text = rsub(text, "ɫ([iɛ])", "l%1")
	text = rsub(text, "ɫ([j])", "ʎ")

	-- Voicing assimilation
	text = rsub(text, "([bdɟɡzʒv" .. TIE .. "]*)(ˈ?[ptcksʃfx#])", function(a, b)
		return rsub(a, '.', devoicing) .. b end)

	-- Sibilant assimilation
	text = rsub(text, "[sz](ˈ?[td]?" .. TIE .. "?)([ʃʒ])", "%2%1%2")

	-- Nasal assimilation
	text = rsub(text, "n([ɡk]+)", "ŋ%1")
	text = rsub(text, "n([bp]+)", "m%1")
	text = rsub(text, "[nm]([fv]+)", "ɱ%1")

	-- Epenthesis
	text = rsub(text, "(iˈ?)j?([aɛɔu])", "%1(j)%2")

	-- /r/ allophony
	text = rsub(text, "([aɛiɔuə])r", "%1ɾ")
	text = rsub(text, "ɾ([^aɛiɔuə])", "r%1")

	-- Strip hashes
	text = rsub(text, "#", "")

	return text
end

function export.show(frame)
	local params = {
		[1] = {}
	}
	
	local title = mw.title.getCurrentTitle()
	
	local args = require("Module:parameters").process(frame:getParent().args, params)
	local term = args[1] or title.nsText == "Template" and "пример" or title.text

	local IPA = export.toIPA(term)
	
	IPA = "[" .. IPA .. "]"
	IPA = require("Module:IPA").format_IPA_full(lang, { { pron = IPA } } )
	
	return IPA
end

return export
