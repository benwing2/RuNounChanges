local export = {}

--[=[

FIXME:

1. If you write '''Б'''ез, it transliterates to '''B'''jez instead of '''B'''ez.

]=]

local u = mw.ustring.char
local GR = u(0x0300) -- grave =  ̀

local tab = {
	["А"]="A", ["Б"]="B", ["В"]="V", ["Г"]="G", ["Д"]="D", ["Е"]="E", ["Ё"]="Jó", ["Ж"]="Ž", ["З"]="Z", ["И"]="I", ["Й"]="J",
	["К"]="K", ["Л"]="L", ["М"]="M", ["Н"]="N", ["О"]="O", ["П"]="P", ["Р"]="R", ["С"]="S", ["Т"]="T", ["У"]="U", ["Ф"]="F",
	["Х"]="X", ["Ц"]="C", ["Ч"]="Č", ["Ш"]="Š", ["Щ"]="Šč", ["Ъ"]="ʺ", ["Ы"]="Y", ["Ь"]="ʹ", ["Э"]="Ɛ", ["Ю"]="Ju", ["Я"]="Ja",
	['а']='a', ['б']='b', ['в']='v', ['г']='g', ['д']='d', ['е']='e', ['ё']='jó', ['ж']='ž', ['з']='z', ['и']='i', ['й']='j',
	['к']='k', ['л']='l', ['м']='m', ['н']='n', ['о']='o', ['п']='p', ['р']='r', ['с']='s', ['т']='t', ['у']='u', ['ф']='f',
	['х']='x', ['ц']='c', ['ч']='č', ['ш']='š', ['щ']='šč', ['ъ']='ʺ', ['ы']='y', ['ь']='ʹ', ['э']='ɛ', ['ю']='ju', ['я']='ja',
	-- Russian style quotes
	['«']='“', ['»']='”',
	-- archaic, pre-1918 letters
	['І']='I', ['і']='i', ['Ѳ']='F', ['ѳ']='f',
	['Ѣ']='Ě', ['ѣ']='ě', ['Ѵ']='I', ['ѵ']='i',
}

-- following based on ru-common for use with is_monosyllabic()
-- any Cyrillic vowel, including ёЁ and composed Cyrillic vowels with grave accent
local cyr_vowel = "аеиоуяэыюіѣѵАЕИОУЯЭЫЮІѢѴѐЀѝЍёЁ"

-- FIXME! Doesn't work with ɣ, which gets included in this character set
-- FIXME! Integrate this with cyr_vowel
local non_consonants = "[АОУҮЫЭЯЁЮИЕЪЬІѢѴаоуүыэяёюиеъьіѣѵAEIOUYĚƐaeiouyěɛʹʺ%A]"

local map_to_plain_e_map = {["Е"] = "E", ["е"] = "e", ["Ѣ"] = "Ě", ["ѣ"] = "ě", ["Э"] = "Ɛ", ["э"] = "ɛ"}
local function map_to_plain_e(pre, e)
	return pre .. map_to_plain_e_map[e]
end

local map_to_je_map = {["Е"] = "Je", ["е"] = "je", ["Ѣ"] = "Jě", ["ѣ"] = "jě", ["Э"] = "E", ["э"] = "e"}
local function map_to_je(pre, e)
	if e == nil then
		e = pre
		pre = ""
	end
	return pre .. map_to_je_map[e]
end

-- decompose composed grave chars; they will map to uncomposed Latin letters for
-- consistency with other char+grave combinations, and we do this early to
-- avoid problems converting to e or je
local decompose_grave_map = {['ѐ'] = 'е' .. GR, ['Ѐ'] = 'Е' .. GR, ['ѝ'] = 'и' .. GR, ['Ѝ'] = 'И' .. GR}

-- True if Cyrillic word has no more than one vowel; includes non-syllabic
-- stems such as льд-; copied from ru-common to avoid having to import that
-- module (which would slow things down significantly)
local function is_monosyllabic(word)
	return not mw.ustring.find(word, "[" .. cyr_vowel .. "].*[" .. cyr_vowel .. "]")
end

-- Transliterates text, which should be a single word or phrase. It should
-- include stress marks, which are then preserved in the transliteration.
-- ё is a special case: it is rendered (j)ó in multisyllabic words and
-- monosyllabic words in multi-word phrases, but rendered (j)o without an
-- accent in isolated monosyllabic words, unless INCLUDE_MONOSYLLABIC_JO_ACCENT
-- is specified. (This is used in conjugation and declension tables.)
function export.tr(text, lang, sc, include_monosyllabic_jo_accent)
	-- Remove word-final hard sign
	text = mw.ustring.gsub(text, "[Ъъ]$", "")
	text = mw.ustring.gsub(text, "[Ъъ]([- ])", "%1")

	 -- the if-statement below isn't necessary but may speed things up,
	 -- particularly when include_monosyllabic_jo_accent isn't set, in that
	 -- in the majority of cases where ё doesn't occur, we avoid a pattern find
	 -- (in is_monosyllabic()) and three pattern subs. The translit module needs
	 -- to be as fast as possible since it may be called hundreds or
	 -- thousands of times on some pages.
	 if mw.ustring.find(text, "[Ёё]") then
		-- We need to special-case ё after a "hushing" consonant, which becomes
		-- ó (or o), without j. We also need special cases for monosyllabic ё
		-- when INCLUDE_MONOSYLLABIC_JO_ACCENT isn't set, so we don't add the
		-- accent mark that we would otherwise include.
		if not include_monosyllabic_jo_accent and is_monosyllabic(text) then
			text = mw.ustring.gsub(text, "([жшчщЖШЧЩ])ё","%1o")
			text = text:gsub("ё", "jo")
			text = text:gsub("Ё", "Jo")
		else
			text = mw.ustring.gsub(text, "([жшчщЖШЧЩ])ё","%1ó")
			-- conversion of remaining ё will occur as a result of 'tab'.
		end
	end

	-- ю after ж and ш becomes u (e.g. брошюра, жюри)
	text = mw.ustring.gsub(text, "([жшЖШ])ю","%1u")

	-- decompose composed grave characters before we convert Cyrillic е to
	-- Latin e or je
	text = mw.ustring.gsub(text, "[ѐЀѝЍ]", decompose_grave_map)

	 -- the if-statement below isn't necessary but may speed things up in that
	 -- in the majority of cases where the letters below don't occur, we avoid
	 -- six pattern subs.
	 if mw.ustring.find(text, "[ЕеѢѣЭэ]") then
		-- е after a dash at the beginning of a word becomes e, and э becomes ɛ
		-- (like after a consonant)
		text = mw.ustring.gsub(text, "^(%-)([ЕеѢѣЭэ])", map_to_plain_e)
		text = mw.ustring.gsub(text, "(%s%-)([ЕеѢѣЭэ])", map_to_plain_e)

		-- е after a vowel or at the beginning of a word becomes je, and э becomes e
		text = mw.ustring.gsub(text, "^([ЕеѢѣЭэ])", map_to_je)
		text = mw.ustring.gsub(text, "(" .. non_consonants .. ")([ЕеѢѣЭэ])", map_to_je)
		-- need to do it twice in case of sequences of such vowels
		text = mw.ustring.gsub(text, "^([ЕеѢѣЭэ])", map_to_je)
		text = mw.ustring.gsub(text, "(" .. non_consonants .. ")([ЕеѢѣЭэ])", map_to_je)
	end

	text = mw.ustring.gsub(text, "([МмЛл][яеё][́̀]?)г([кч])", "%1х%2")
	return (mw.ustring.gsub(text,'.',tab))
end

--for adjectives and pronouns
function export.tr_adj(text, include_monosyllabic_jo_accent)
	if type(text) == 'table' then -- called directly from a template
		text = text.args[1]
	end

	local tr = export.tr(text, nil, nil, include_monosyllabic_jo_accent)

	--handle genitive/accusative endings, which are spelled -ого/-его/-аго
	-- (-ogo/-ego/-ago) but transliterated -ovo/-evo/-avo; only for adjectives
	-- and pronouns, excluding words like много, ого (-аго occurs in
	-- pre-reform spelling); \204\129 is an acute accent, \204\128 is a grave accent
	local pattern = "([oeaóéáOEAÓÉÁ][\204\129\204\128]?)([gG])([oO][\204\129\204\128]?)"
	local reflexive = "([sS][jJ][aáAÁ][\204\129\204\128]?)"
	local v = {["g"] = "v", ["G"] = "V"}
	local repl = function(e, g, o, sja) return e .. v[g] .. o .. (sja or "") end
	tr = mw.ustring.gsub(tr, pattern .. "%f[^%a\204\129\204\128]", repl)
	tr = mw.ustring.gsub(tr, pattern .. reflexive .. "%f[^%a\204\129\204\128]", repl)

	return tr
end

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
