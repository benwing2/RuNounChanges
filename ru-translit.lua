local export = {}

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

-- FIXME! Doesn't work with ɣ, which gets included in this character set
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

-- Transliterates text, which should be a single word or phrase. It should
-- include stress marks, which are then preserved in the transliteration.
function export.tr(text, lang, sc)
	-- Remove word-final hard sign
	text = mw.ustring.gsub(text, "[Ъъ]$", "")
	text = mw.ustring.gsub(text, "[Ъъ]([- ])", "%1")

	-- ё after a "hushing" consonant becomes ó (ё is mostly stressed)
	text = mw.ustring.gsub(text, "([жшчщЖШЧЩ])ё","%1ó")
	-- ю after ж and ш becomes u (e.g. брошюра, жюри)
	text = mw.ustring.gsub(text, "([жшЖШ])ю","%1u")

	-- decompose composed grave characters before we convert Cyrillic е to
	-- Latin e or je
	text = mw.ustring.gsub(text, "[ѐЀѝЍ]", decompose_grave_map)

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

	text = mw.ustring.gsub(text, "([МмЛл][яеё][́̀]?)г([кч])", "%1х%2")
	return (mw.ustring.gsub(text,'.',tab))
end

--for adjectives and pronouns
function export.tr_adj(text)
	if type(text) == 'table' then -- called directly from a template
		text = text.args[1]
	end

	local tr = export.tr(text)

	--handle genitive/accusative endings, which are spelled -ого/-его/-аго
	-- (-ogo/-ego/-ago) but transliterated -ovo/-evo/-avo; only for adjectives
	-- and pronouns, excluding words like много, ого (-аго occurs in
	-- pre-reform spelling)
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
