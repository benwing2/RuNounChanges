local export = {}

local u = mw.ustring.char
local rsubn = mw.ustring.gsub
local ulower = mw.ustring.lower

local m_syllables = require("Module:syllables")
local m_utils = require("Module:utilities")
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
	["‘"] = "ə",
	[AC] = "ˈ",
	["`"] = "ˈ",
	["/"] = "ˈ",
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
	text = rsub(text, "# #m#", "# #mə#")
	text = rsub(text, "#m# #", "#mə# #")
	text = rsub(text, "# #n#", "# #nə#")
	text = rsub(text, "#n# #", "#nə# #")
	text = rsub(text, "# #ɲ#", "# #ɲə#")
	text = rsub(text, "#ɲ# #", "#ɲə# #")
	text = rsub(text, "# #r#", "# #rə#")
	text = rsub(text, "#r# #", "#rə# #")
	text = rsub(text, "# #ɫ#", "# #ɫə#")
	text = rsub(text, "#ɫ# $", "#ɫə# #")
	text = rsub(text, "# #l#", "# #lə#")
	text = rsub(text, "#l# #", "#lə# #")
	text = rsub(text, "# #ʎ#", "# #ʎə#")
	text = rsub(text, "#ʎ# #", "#ʎə# #")
	text = rsub(text, "# #j#", "# #jə#")
	text = rsub(text, "#j# #", "#jə# #")
	text = rsub_repeatedly(text, "([^" .. vocalic .. "ˈ])([rɫlʎj])([^" .. vocalic .. "])", "%1%2" .. SYLLABIC .. "%3")
	text = rsub_repeatedly(text, "([^" .. vocalic .. "rɫlʎjˈ])([mnɲ])([^" .. vocalic .. "rɫlʎmnɲj])", "%1%2" .. SYLLABIC .. "%3")
	text = rsub(text, "ər", "r" .. SYLLABIC)

	-- Mark stress
	text = rsub(text, "(#[^#ˈ ]*" .. vocalic_c .. ")([^#ˈ ]*" .. vocalic_c .. "[^#ˈ ]*" .. vocalic_c .. "[^#ˈ ]*#)", "%1ˈ%2")
	text = rsub(text, "(#[^#ˈ ]*" .. vocalic_c .. ")([^#ˈ ]*" .. vocalic_c .. "[^#ˈ ]*#)", "%1ˈ%2")
	text = rsub(text, "([szʃʒ]?[ptckbdɟɡfxmɱnɲ]?[mɱnɲv]?[rɫljʎ]?" .. vocalic_c .. ")ˈ", "ˈ%1")
	text = rsub(text, "([td]" .. TIE .. "[szʃʒ]?)ˈ", "ˈ%1")
	text = rsub(text, "#([^#aɛiɔuə" .. SYLLABIC .. " ]*)ˈ", "#ˈ%1")
	text = rsub(text, "ˈbm", "bˈm")
	text = rsub(text, "ˈbn", "bˈn")
	text = rsub(text, "ˈbv", "bˈv")
	text = rsub(text, "ˈdm", "dˈm")
	text = rsub(text, "ˈdɲ", "dˈɲ")
	text = rsub(text, "ˈdvr", "dˈvr")
	text = rsub(text, "ˈdvɫ", "dˈvɫ")
	text = rsub(text, "ˈstm", "stˈm")
	text = rsub(text, "ˈfn", "fˈn")
	text = rsub(text, "ˈ[mɱn]v", "ɱˈv")
	text = rsub(text, "[ɫl]ˈj", "ˈʎ")
	text = rsub(text, "ˈzʎ", "zˈʎ")
	text = rsub(text, "ˈbj", "bˈj")
	text = rsub(text, "ˈdj", "dˈj")
	text = rsub(text, "ˈnj", "nˈj")
	text = rsub(text, "ˈnɫ", "nˈɫ")
	text = rsub(text, "ˈnr", "nˈr")
	text = rsub(text, "ˈzmj", "zˈmj")
	text = rsub(text, "ˈzmr", "zˈmr")
	text = rsub(text, "ˈzvr", "zˈvr")
	text = rsub(text, "ˈsfr", "sˈfr")
	text = rsub(text, "ˈʃx", "ʃˈx")
	text = rsub(text, "ˈxn", "xˈn")
	text = rsub(text, "#ˈiɫi#", "#ili#")
	text = rsub(text, "#p#", "#pə#")
	text = rsub(text, "#b#", "#bə#")
	text = rsub(text, "#t#", "#tə#")
	text = rsub(text, "#d#", "#də#")
	text = rsub(text, "#c#", "#cə#")
	text = rsub(text, "#ɟ#", "#ɟə#")
	text = rsub(text, "#k#", "#kə#")
	text = rsub(text, "#ɡ#", "#ɡə#")
	text = rsub(text, "#f#", "#fə#")
	text = rsub(text, "#v#", "#və#")
	text = rsub(text, "#s#", "#sə#")
	text = rsub(text, "#z#", "#zə#")
	text = rsub(text, "#ʃ#", "#ʃə#")
	text = rsub(text, "#ʒ#", "#ʒə#")
	text = rsub(text, "#x#", "#xə#")
	text = rsub(text, "#t͡s#", "#t͡sə#")
	text = rsub(text, "#d͡z#", "#d͡zə#")
	text = rsub(text, "#t͡ʃ#", "#t͡ʃə#")
	text = rsub(text, "#d͡ʒ#", "#d͡ʒə#")
	
	-- Palatalisation
	text = rsub(text, "ɫ([iɛ])", "l%1")
	text = rsub(text, "ɫ([j])", "ʎ")

	-- Voicing assimilation
	text = rsub(text, "([bdɟɡzʒv" .. TIE .. "]*)(ˈ?[ptcksʃfx])", function(a, b)
		return rsub(a, '.', devoicing) .. b end)
	text = rsub(text, "b##", "p##")
	text = rsub(text, "d##", "t##")
	text = rsub(text, "ɟ##", "c##")
	text = rsub(text, "ɡ##", "k##")
	text = rsub(text, "z##", "s##")
	text = rsub(text, "ʒ##", "ʃ##")
	text = rsub(text, "v##", "f##")
	text = rsub(text, "b# #(ˈ?)([ptcksʃfx])", "p# #%1%2")
	text = rsub(text, "b# #(ˈ?)([bdɟɡzʒvmɱnɲvrɫljʎ])", "b# #%1%2")
	text = rsub(text, "d# #(ˈ?)([ptcksʃfx])", "t# #%1%2")
	text = rsub(text, "d# #(ˈ?)([bdɟɡzʒvmɱnɲvrɫljʎ])", "d# #%1%2")
	text = rsub(text, "ɟ# #(ˈ?)([ptcksʃfx])", "c# #%1%2")
	text = rsub(text, "ɟ# #(ˈ?)([bdɟɡzʒvmɱnɲvrɫljʎ])", "ɟ# #%1%2")
	text = rsub(text, "ɡ# #(ˈ?)([ptcksʃfx])", "k# #%1%2")
	text = rsub(text, "ɡ# #(ˈ?)([bdɟɡzʒvmɱnɲvrɫljʎ])", "ɡ# #%1%2")
	text = rsub(text, "z# #(ˈ?)([ptcksʃfx])", "s# #%1%2")
	text = rsub(text, "z# #(ˈ?)([bdɟɡzʒvmɱnɲvrɫljʎ])", "z# #%1%2")
	text = rsub(text, "ʒ# #(ˈ?)([ptcksʃfx])", "ʃ# #%1%2")
	text = rsub(text, "ʒ#(ˈ?)([ptcksʃfx])", "ʃ#%1%2")
	text = rsub(text, "ʒ# #(ˈ?)([bdɟɡzʒvmɱnɲvrɫljʎ])", "ʒ# #%1%2")
	text = rsub(text, "v# #(ˈ?)([ptcksʃfx])", "f# #%1%2")
	text = rsub(text, "v# #(ˈ?)([bdɟɡzʒvmɱnɲvrɫljʎ])", "v# #%1%2")
	text = rsub(text, "(p)(ˈ?)([bdɟɡzʒ])", "b%2%3")
	text = rsub(text, "(t)(ˈ?)([bdɟɡzʒ])", "d%2%3")
	text = rsub(text, "(c)(ˈ?)([bdɟɡzʒ])", "ɟ%2%3")
	text = rsub(text, "(k)(ˈ?)([bdɟɡzʒ])", "ɡ%2%3")
	text = rsub(text, "(s)(ˈ?)([bdɟɡzʒ])", "z%2%3")
	text = rsub(text, "(ʃ)(ˈ?)([bdɟɡzʒ])", "ʒ%2%3")
	text = rsub(text, "zt##", "st##")
	text = rsub(text, "ʒt##", "ʃt##")
	text = rsub(text, "d͡ʃ", "t͡ʃ")
	text = rsub(text, "t͡ʒ", "d͡ʒ")

	-- Sibilant assimilation
	text = rsub(text, "[sz](ˈ?[td]?" .. TIE .. "?)([ʃʒ])", "%2%1%2")

	-- Nasal assimilation
	text = rsub(text, "n([ɡkx]+)", "ŋ%1")
	text = rsub(text, "nˈ([ɡkx]+)", "ŋˈ%1")
	text = rsub(text, "n̩([ɡkx]+)", "ŋ̩%1")
	text = rsub(text, "n̩ˈ([ɡkx]+)", "ŋ̩ˈ%1")
	text = rsub(text, "n([bp]+)", "m%1")
	text = rsub(text, "nˈ([bp]+)", "mˈ%1")
	text = rsub(text, "n([cɟ]+)", "ɲ%1")
	text = rsub(text, "nˈ([cɟ]+)", "ɲˈ%1")
	text = rsub(text, "[nm]([fv]+)", "ɱ%1")
	text = rsub(text, "[nm]ˈ([fv]+)", "ɱˈ%1")

	-- Epenthesis
	text = rsub(text, "(i)j([aɛɔu])", "%1(j)%2")
	text = rsub(text, "(i)([aɛɔu])", "%1(j)%2")
	text = rsub(text, "(iˈ)j([aɛɔu])", "%1j%2")
	text = rsub(text, "(iˈ)([aɛɔu])", "%1%2")

	-- /r/ allophony
	text = rsub(text, "([aɛiɔuə])r", "%1ɾ")
	text = rsub(text, "ɾ([^aɛiɔuə])", "r%1")
	
	-- Strip hashes
	text = rsub(text, "#", "")

	return text
end

function assign_stresscats(syllables)
	syllables = mw.ustring.gsub(syllables, ".*ˈ", "")
	syllables = m_syllables.getVowels(syllables, lang)
	if syllables == 1 then 
		table.insert(syllable_cats, "Macedonian oxytone terms")
	elseif syllables == 2 then 
		table.insert(syllable_cats, "Macedonian paroxytone terms")
	elseif syllables == 3 then 
		table.insert(syllable_cats, "Macedonian proparoxytone terms")
	end
end

function export.show(frame)
	local params = {
		[1] = {},
		["no_stress"] = {type = "boolean", default = false},
	}
	
	local title = mw.title.getCurrentTitle()
	
	local args = require("Module:parameters").process(frame:getParent().args, params)
	local term = args[1] or title.nsText == "Template" and "пример" or title.text

	local IPA = export.toIPA(term)
	
	syllable_cats = {}
	
	if mw.ustring.find(IPA, " ") == nil and args.no_stress == false then 
		assign_stresscats(IPA)
	end

	IPA = "[" .. IPA .. "]"
	IPA = require("Module:IPA").format_IPA_full(lang, { { pron = IPA } } )
	
	return IPA .. m_utils.format_categories(syllable_cats, lang)
end

return export
