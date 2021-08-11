local export = {}

local gsub = mw.ustring.gsub
local U = mw.ustring.char

local acute = U(0x301)
local stress = U(0x2C8)
local syllabic = U(0x329)
local tie = U(0x361)

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
	["ѕ"] = "d" .. tie .. "z",
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
	["ц"] = "t" .. tie .. "s",
	["ч"] = "t" .. tie .. "ʃ",
	["џ"] = "d" .. tie .. "ʒ",
	["ш"] = "ʃ",

	["’"] = "ə",
	[acute] = stress,
	["`"] = "ˈ"
}

local devoicing = {
	['b'] = 'p', ['d'] = 't', ['ɟ'] = 'c', ['ɡ'] = 'k',
	['z'] = 's', ['ʒ'] = 'ʃ',
	['v'] = 'f', [tie] = tie
}

local peak = "[aɛiɔuə" .. syllabic .. "]"

function export.toIPA(word)
	IPA = mw.ustring.toNFC(mw.ustring.lower(word))

	IPA = mw.ustring.gsub(IPA, '.', phonetic_chars_map)

	-- Mark word boundaries
	IPA = mw.ustring.gsub(IPA, "(%s+)", "#%1#")
	IPA = "#" .. IPA .. "#"

	-- Syllabic sonorants
	IPA = mw.ustring.gsub(IPA, "([^aɛiɔuə" .. stress .. "])([rɫl])([^aɛiɔuə])", "%1%2" .. syllabic .. "%3")
	IPA = mw.ustring.gsub(IPA, "([^aɛiɔuə" .. stress .. "])([nmɲ])([^aɛiɔuərɫlmn])", "%1%2" .. syllabic .. "%3")
	IPA = mw.ustring.gsub(IPA, "ər", "r" .. syllabic)

	-- Mark stress
	IPA = mw.ustring.gsub(IPA, "(#[^#" .. stress .. "]*" .. peak .. ")([^#" .. stress .. "]*" .. peak .. "[^#" .. stress .. "]*" .. peak .. "[^#" .. stress .. "]*#)", "%1" .. stress .. "%2")
	IPA = mw.ustring.gsub(IPA, "(#[^#" .. stress .. "]*" .. peak .. ")([^#" .. stress .. "]*" .. peak .. "[^#" .. stress .. "]*#)", "%1" .. stress .. "%2")
	IPA = mw.ustring.gsub(IPA, "([szʃʒ]?[ptckbdɟɡfxmnɲ]?[mnɲv]?[rɫljʎ]?" .. peak .. ")" .. stress, stress .. "%1")
	IPA = mw.ustring.gsub(IPA, "([td]" .. tie .. "[szʃʒ]?)" .. stress, stress .. "%1")
	IPA = mw.ustring.gsub(IPA, "#([^#aɛiɔuə" .. syllabic .. "]*)" .. stress, "#" .. stress .. "%1")

	-- Palatalisation
	IPA = mw.ustring.gsub(IPA, "ɫ([iɛ])", "l%1")
	IPA = mw.ustring.gsub(IPA, "ɫ([j])", "ʎ")

	-- Voicing assimilation
	IPA = gsub(IPA, "([bdɟɡzʒv" .. tie .. "]*)(" .. stress .. "?[ptcksʃfx#])", function(a, b)
		return gsub(a, '.', devoicing) .. b end)

	-- Sibilant assimilation
	IPA = gsub(IPA, "[sz](" .. stress .. "?[td]?" .. tie .. "?)([ʃʒ])", "%2%1%2")

	-- Nasal assimilation
	IPA = mw.ustring.gsub(IPA, "n([ɡk]+)", "ŋ%1")
	IPA = mw.ustring.gsub(IPA, "n([bp]+)", "m%1")
	IPA = mw.ustring.gsub(IPA, "[nm]([fv]+)", "ɱ%1")

	-- Epenthesis
	IPA = mw.ustring.gsub(IPA, "(i" .. stress .."?)j?([aɛɔu])", "%1(j)%2")

	-- /r/ allophony
	IPA = mw.ustring.gsub(IPA, "([aɛiɔuə])r", "%1ɾ")
	IPA = mw.ustring.gsub(IPA, "ɾ([^aɛiɔuə])", "r%1")

	-- Strip hashes
	IPA = gsub(IPA, "#", "")

	return IPA
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
	IPA = require("Module:IPA").format_IPA_full(require("Module:languages").getByCode("mk"), { { pron = IPA } } )
	
	return IPA
end

return export
