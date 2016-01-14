local export = {}

--[=[

FIXME:

1. If you write '''Б'''ез, it transliterates to '''B'''jez instead of '''B'''ez.
2. (DONE) Convert ъ to nothing before comma or other non-letter particle, e.g.
   in Однимъ словомъ, идешь на чтеніе.

]=]

local u = mw.ustring.char
local rfind = mw.ustring.find
local rsub = mw.ustring.gsub -- WARNING: Don't return this directly in a function, or surround in parens
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local ulower = mw.ustring.lower
local usub = mw.ustring.sub

local GR = u(0x0300) -- grave =  ̀

local function ine(x) -- if not empty
	if x == "" then return nil else return x end
end

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
-- any Cyrillic or Latin vowel, including ёЁ and composed Cyrillic vowels with grave accent;
-- not including accented Latin vowels except ě (FIXME, might want to change this)
local vowels = "аеиоуяэыюіѣѵүАЕИОУЯЭЫЮІѢѴҮѐЀѝЍёЁAEIOUYĚƐaeiouyěɛ"

-- FIXME! Doesn't work with ɣ, which gets included in this character set
local non_consonants = "[" .. vowels .. "ЪЬъьʹʺ%A]"

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

-- True if Cyrillic or decomposed Latin word has no more than one vowel;
-- includes non-syllabic stems such as льд-; copied from ru-common and modified
-- to avoid having to import that module (which would slow things down
-- significantly)
local function is_monosyllabic(word)
	return not rfind(word, "[" .. vowels .. "].*[" .. vowels .. "]")
end

-- Transliterates text, which should be a single word or phrase. It should
-- include stress marks, which are then preserved in the transliteration.
-- ё is a special case: it is rendered (j)ó in multisyllabic words and
-- monosyllabic words in multi-word phrases, but rendered (j)o without an
-- accent in isolated monosyllabic words, unless INCLUDE_MONOSYLLABIC_JO_ACCENT
-- is specified. (This is used in conjugation and declension tables.)
function export.tr(text, lang, sc, include_monosyllabic_jo_accent)
	-- Remove word-final hard sign, either utterance-finally or followed by
	-- a non-letter character such as space, comma, period, hyphen, etc.
	text = rsub(text, "[Ъъ]$", "")
	text = rsub(text, "[Ъъ]([%A])", "%1")

	 -- the if-statement below isn't necessary but may speed things up,
	 -- particularly when include_monosyllabic_jo_accent isn't set, in that
	 -- in the majority of cases where ё doesn't occur, we avoid a pattern find
	 -- (in is_monosyllabic()) and three pattern subs. The translit module needs
	 -- to be as fast as possible since it may be called hundreds or
	 -- thousands of times on some pages.
	 if rfind(text, "[Ёё]") then
		-- We need to special-case ё after a "hushing" consonant, which becomes
		-- ó (or o), without j. We also need special cases for monosyllabic ё
		-- when INCLUDE_MONOSYLLABIC_JO_ACCENT isn't set, so we don't add the
		-- accent mark that we would otherwise include.
		if not include_monosyllabic_jo_accent and is_monosyllabic(text) then
			text = rsub(text, "([жшчщЖШЧЩ])ё","%1o")
			text = text:gsub("ё", "jo")
			text = text:gsub("Ё", "Jo")
		else
			text = rsub(text, "([жшчщЖШЧЩ])ё","%1ó")
			-- conversion of remaining ё will occur as a result of 'tab'.
		end
	end

	-- ю after ж and ш becomes u (e.g. брошюра, жюри)
	text = rsub(text, "([жшЖШ])ю","%1u")

	-- decompose composed grave characters before we convert Cyrillic е to
	-- Latin e or je
	text = rsub(text, "[ѐЀѝЍ]", decompose_grave_map)

	 -- the if-statement below isn't necessary but may speed things up in that
	 -- in the majority of cases where the letters below don't occur, we avoid
	 -- six pattern subs.
	 if rfind(text, "[ЕеѢѣЭэ]") then
		-- е after a dash at the beginning of a word becomes e, and э becomes ɛ
		-- (like after a consonant)
		text = rsub(text, "^(%-)([ЕеѢѣЭэ])", map_to_plain_e)
		text = rsub(text, "(%s%-)([ЕеѢѣЭэ])", map_to_plain_e)

		-- е after a vowel or at the beginning of a word becomes je, and э becomes e
		text = rsub(text, "^([ЕеѢѣЭэ])", map_to_je)
		text = rsub(text, "(" .. non_consonants .. ")([ЕеѢѣЭэ])", map_to_je)
		-- need to do it twice in case of sequences of such vowels
		text = rsub(text, "^([ЕеѢѣЭэ])", map_to_je)
		text = rsub(text, "(" .. non_consonants .. ")([ЕеѢѣЭэ])", map_to_je)
	end

	text = rsub(text, "([МмЛл][яеё][́̀]?)г([кч])", "%1х%2")
	return (rsub(text,'.',tab))
end

-- translit with various special-case substitutions
function export.tr_sub(text, include_monosyllabic_jo_accent, adj, shto, sub)
	if type(text) == 'table' then -- called directly from a template
		include_monosyllabic_jo_accent = ine(text.args.include_monosyllabic_jo_accent)
		adj = ine(text.args.adj)
		shto = ine(text.args.shto)
		sub = ine(text.args.sub)
		text = text.args[1]
	end

	if sub then
		subs = rsplit(sub, ",")
		for _, subpair in ipairs(subs) do
			subsplit = rsplit(subpair, "/")
			text = rsub(text, subsplit[1], subsplit[2])
		end
	end

	local tr = export.tr(text, nil, nil, include_monosyllabic_jo_accent)

	if adj then
		--handle genitive/accusative endings, which are spelled -ого/-его/-аго
		-- (-ogo/-ego/-ago) but transliterated -ovo/-evo/-avo; only for adjectives
		-- and pronouns, excluding words like много, ого (-аго occurs in
		-- pre-reform spelling); \204\129 is an acute accent, \204\128 is a grave accent
		local pattern = "([oeaóéáOEAÓÉÁ][\204\129\204\128]?)([gG])([oO][\204\129\204\128]?)"
		local reflexive = "([sS][jJ][aáAÁ][\204\129\204\128]?)"
		local v = {["g"] = "v", ["G"] = "V"}
		local repl = function(e, g, o, sja) return e .. v[g] .. o .. (sja or "") end
		tr = rsub(tr, pattern .. "%f[^%a\204\129\204\128]", repl)
		tr = rsub(tr, pattern .. reflexive .. "%f[^%a\204\129\204\128]", repl)
	end

	if shto then
		-- Handle что
		tr = rsub(tr, "%f[%a\204\129\204\128]čto([\204\129\204\128]?)%f[^%a\204\129\204\128]", "što%1")
		-- Handle чтобы, чтоб
		tr = rsub(tr, "%f[%a\204\129\204\128]čto([\204\129\204\128]?by?)%f[^%a\204\129\204\128]", "što%1")
		-- Handle ничто
		tr = rsub(tr, "%f[%a\204\129\204\128]ničto([\204\129\204\128]?)%f[^%a\204\129\204\128]", "ništo%1")
	end

	return tr
end

--for adjectives, pronouns
function export.tr_adj(text, include_monosyllabic_jo_accent)
	if type(text) == 'table' then -- called directly from a template
		include_monosyllabic_jo_accent = ine(text.args.include_monosyllabic_jo_accent)
		text = text.args[1]
	end

	return export.tr_sub(text, include_monosyllabic_jo_accent, "adj")
end

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
