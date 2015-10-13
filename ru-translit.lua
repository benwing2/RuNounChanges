local export = {}

local u = mw.ustring.char
local GR = u(0x0300) -- grave =  ̀

local tab = {
	["А"]="A", ["Б"]="B", ["В"]="V", ["Г"]="G", ["Д"]="D", ["Е"]="E", ["Ё"]="Jó", ["Ж"]="Ž", ["З"]="Z", ["И"]="I", ["Й"]="J",
	["К"]="K", ["Л"]="L", ["М"]="M", ["Н"]="N", ["О"]="O", ["П"]="P", ["Р"]="R", ["С"]="S", ["Т"]="T", ["У"]="U", ["Ф"]="F",
	["Х"]="X", ["Ц"]="C", ["Ч"]="Č", ["Ш"]="Š", ["Щ"]="Šč", ["Ъ"]="ʺ", ["Ы"]="Y", ["Ь"]="ʹ", ["Э"]="E", ["Ю"]="Ju", ["Я"]="Ja",
	['а']='a', ['б']='b', ['в']='v', ['г']='g', ['д']='d', ['е']='e', ['ё']='jó', ['ж']='ž', ['з']='z', ['и']='i', ['й']='j',
	['к']='k', ['л']='l', ['м']='m', ['н']='n', ['о']='o', ['п']='p', ['р']='r', ['с']='s', ['т']='t', ['у']='u', ['ф']='f',
	['х']='x', ['ц']='c', ['ч']='č', ['ш']='š', ['щ']='šč', ['ъ']='ʺ', ['ы']='y', ['ь']='ʹ', ['э']='e', ['ю']='ju', ['я']='ja',
	-- Russian style quotes
	['«']='“', ['»']='”',
	-- archaic, pre-1918 letters
	['І']='I', ['і']='i', ['Ѳ']='F', ['ѳ']='f',
	['Ѣ']='Ě', ['ѣ']='ě', ['Ѵ']='I', ['ѵ']='i',
	-- composed combinations with grave accents map to uncomposed letters
	-- for consistency with other char+grave combinations
	['ѐ'] = 'e' .. GR, ['Ѐ'] = 'E' .. GR, ['ѝ'] = 'i' .. GR, ['Ѝ'] = 'I' .. GR,
}

local function replace_e(pre, e)
	if e == nil then
		e = pre
		pre = ""
	end
	e = mw.ustring.gsub(e, '.', {["Е"] = "Je", ["е"] = "je", ["Ѣ"] = "Jě", ["ѣ"] = "jě"})
	if pre == "" or mw.ustring.find(pre, "[АОУҮЫЭЯЁЮИЕЪЬІѢѴаоуүыэяёюиеъьіѣѵAEIOUYĚƐaeiouyěɛʹʺ%A]") then
		return pre .. e
	else
		return pre .. mw.ustring.sub(e, 2)
	end
end

-- Transliterates text, which should be a single word or phrase. It should
-- include stress marks, which are then preserved in the transliteration.
function export.tr(text, lang, sc)
	-- Remove word-final hard sign
	text = mw.ustring.gsub(text, "[Ъъ]$", "")
	text = mw.ustring.gsub(text, "[Ъъ]([- ])", "%1")

	-- Ё needs converting if is decomposed
	-- won't have any effect
	-- text = text:gsub("ё","ё"):gsub("Ё","Ё")

	-- ё after a "hushing" consonant becomes ó (ё is mostly stressed)
	text = mw.ustring.gsub(text, "([жшчщЖШЧЩ])ё","%1ó")
	-- ю after ж and ш becomes u (e.g. брошюра, жюри)
	text = mw.ustring.gsub(text, "([жшЖШ])ю","%1u")

	-- е after a vowel or at the beginning of a word becomes je
	text = mw.ustring.gsub(text, "^([ЕеѢѣ]+)", replace_e)
	text = mw.ustring.gsub(text, "(.)([ЕеѢѣ]+)", replace_e)

	return (mw.ustring.gsub(text,'.',tab))
end

--for adjectives and pronouns
function export.tr_adj(text)
	if type(text) == 'table' then -- called directly from a template
		text = text.args[1]
	end

	local tr = export.tr(text)

	--handle genitive/accusative endings, which are spelled -ого/-его (-ogo/-ego) but transliterated -ovo/-evo
	-- only for adjectives and pronouns, excluding words like много, ого
	local pattern = "([oeóéOEÓÉ][\204\129\204\128]?)([gG])([oO][\204\129\204\128]?)"
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
