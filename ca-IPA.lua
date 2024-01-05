local export = {}

local lang = require("Module:languages").getByCode("ca")

local m_IPA = require("Module:IPA")
local m_a = require("Module:accent qualifier")
local m_table = require("Module:table")

local parse_utilities_module = "Module:parse utilities"
local patut_module = "Module:pattern utilities"

local listToSet = require("Module:table").listToSet


local usub = mw.ustring.sub
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local rsubn = mw.ustring.gsub
local ulower = mw.ustring.lower

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

local function split_on_comma(term)
	if term:find(",%s") or term:find("\\") then
		return require(parse_utilities_module).split_on_comma(term)
	else
		return rsplit(term, ",")
	end
end


export.dialects = {"bal", "cen", "val"}
export.dialects_to_names = {
	bal = "Balearic",
	cen = "Central Catalan",
	val = "Valencian",
}
export.dialect_groups = {
	east = {"bal", "cen"},
}

export.mid_vowel_hints = "éèêëóòô"
export.mid_vowel_hint_c = "[" .. export.mid_vowel_hints .. "]"

local valid_onsets = listToSet {
	"b", "bl", "br",
	"c", "cl", "cr",
	"ç",
	"d", "dj", "dr",
	"f", "fl", "fr",
	"g", "gl", "gr", "gu", "gü",
	"h",
	"i",
	"j",
	"k", "kl", "kr",
	"l", "ll",
	"m",
	"n", "ny", "ñ",
	"p", "pl", "pr",
	"qu", "qü",
	"r", "rr",
	"s", "ss",
	"t", "tg", "tj", "tr", "tx", "tz",
	"u",
	"v", "vl",
	"w",
	"x",
	"z",
} 

local function fix_prefixes(word)
	-- Orthographic fixes for unassimilated prefixes
	local prefix = {
		"a[eè]ro", "ànte", "[aà]nti", "[aà]rxi", "[aà]uto", -- a- is ambiguous as prefix
		"bi", "b[ií]li", "bio",
		"c[oò]ntra", -- ambiguous co-
		"dia", "dodeca",
		"[eé]ntre", "equi", "estereo", -- ambiguous e-(radic)
		"f[oó]to",
		"g[aà]stro", "gr[eé]co",
		"hendeca", "hepta", "hexa", "h[oò]mo",
		"[ií]nfra", "[ií]ntra",
		"m[aà]cro", "m[ií]cro", "mono", "morfo", "m[uú]lti",
		"n[eé]o",
		"octo", "orto",
		"penta", "p[oòô]li", "pol[ií]tico", "pr[oòô]to", "ps[eèêë]udo", "psico", -- ambiguous pre-(s), pro-
		"qu[aà]si", "qu[ií]mio",
		"r[aà]dio", -- ambiguous re-
		"s[eèêë]mi", "s[oó]bre", "s[uú]pra",
		"termo", "tetra", "tri", -- ambiguous tele-(r)
		"[uú]ltra", "[uu]n[ií]",
		"v[ií]ce"
	}
	local prefix_r = {"[eèéêë]xtra", "pr[eé]"}
	local prefix_s = {"antropo", "centro", "deca", "d[ií]no", "eco", "[eèéêë]xtra",
		"hetero", "p[aà]ra", "post", "pré", "s[oó]ta", "tele"}
	local prefix_i = {"pr[eé]", "pr[ií]mo", "pro", "tele"}
	local no_prefix = {"autoic", "autori", "biret", "biri", "bisa", "bisell", "bisó", "biur", "contrari", "contrau",
		"diari", "equise", "heterosi", "monoi", "parasa", "parasit", "preix", "psicosi", "sobrera", "sobreri"}
	
	-- False prefixes
	for _, pr in ipairs(no_prefix) do
		if rfind(word, "^" .. pr) then
			return word
		end
	end
	
	-- Double r in prefix + r + vowel
	for _, pr in ipairs(prefix_r) do
		word = rsub(word, "^(" .. pr .. ")r([aàeèéiíïoòóuúü])", "%1rr%2")
	end
	word = rsub(word, "^eradic", "erradic")
	
	-- Double s in prefix + s + vowel
	for _, pr in ipairs(prefix_s) do
		word = rsub(word, "^(" .. pr .. ")s([aàeèéiíïoòóuúü])", "%1ss%2")
	end
	
	-- Hiatus in prefix + i
	for _, pr in ipairs(prefix_i) do
		word = rsub(word, "^(" .. pr .. ")i(.)", "%1ï%2")
	end
	
	-- Both prefix + r/s or i/u
	for _, pr in ipairs(prefix) do
		word = rsub(word, "^(" .. pr .. ")([rs])([aàeèéiíïoòóuúü])", "%1%2%2%3")
		word = rsub(word, "^(" .. pr .. ")i(.)", "%1ï%2")
		word = rsub(word, "^(" .. pr .. ")u(.)", "%1ü%2")
	end
	
	-- Voiced s in prefix roots -fons-, -dins-, -trans-
	word = rsub(word, "^enfons([aàeèéiíoòóuú])", "enfonz%1")
	word = rsub(word, "^endins([aàeèéiíoòóuú])", "endinz%1")
	word = rsub(word, "tr([aà])ns([aàeèéiíoòóuúbdghlmv])", "tr%1nz%2")
	
	-- in + ex > ineks/inegz
	word = rsub(word, "^inex", "inhex")
	
	return word
end

local function restore_diaereses(word)
	-- Some structural forms do not have diaeresis per diacritic savings, let's restore it to identify hiatus
	
	word = rsub(word, "([iu])um(s?)$", "%1üm%2") -- Latinisms (-ius is ambiguous but rare)
	
	word = rsub(word, "([aeiou])isme(s?)$", "%1ísme%2") -- suffix -isme
	word = rsub(word, "([aeiou])ist([ae]s?)$", "%1íst%2") -- suffix -ista
	
	word = rsub(word, "([aeou])ir$", "%1ír") -- verbs -ir
	word = rsub(word, "([aeou])int$", "%1ínt") -- present participle
	word = rsub(word, "([aeo])ir([éà])$", "%1ïr%2") -- future
	word = rsub(word, "([^gq]u)ir([éà])$", "%1ïr%2")
	word = rsub(word, "([aeo])iràs$", "%1ïràs")
	word = rsub(word, "([^gq]u)iràs$", "%1ïràs")
	word = rsub(word, "([aeo])ir(e[mu])$", "%1ïr%2")
	word = rsub(word, "([^gq]u)ir(e[mu])$", "%1ïr%2")
	word = rsub(word, "([aeo])iran$", "%1ïran")
	word = rsub(word, "([^gq]u)iran$", "%1ïran")
	word = rsub(word, "([aeo])iria$", "%1ïria") -- conditional
	word = rsub(word, "([^gq]u)iria$", "%1ïria")
	word = rsub(word, "([aeo])ir(ie[sn])$", "%1ïr%2")
	word = rsub(word, "([^gq]u)ir(ie[sn])$", "%1ïr%2")
	
	return word
end

local function fix_y(word)
	-- y > vowel i else consonant /j/, except ny
	
	word = rsub(word, "ny", "ñ")
	
	word = rsub(word, "y([^aeiouàèéêëíòóôúïü])", "i%1") -- vowel if not next to another vowel
	word = rsub(word, "([^aeiouàèéêëíòóôúïü·%-%.])y", "%1i") -- excluding also syllables separators
	
	return word
end

local function word_fixes(word)
	word = rsub(word, "%-([rs]?)", "-%1%1")
	word = rsub(word, "rç$", "rrs") -- silent r only in plurals -rs
	word = fix_prefixes(word) -- internal pause after a prefix
	word = restore_diaereses(word) -- no diaeresis saving
	word = fix_y(word) -- ny > ñ else y > i vowel or consonant
	
	return word
end

local function split_vowels(vowels)
	local syllables = {{onset = "", vowel = usub(vowels, 1, 1), coda = ""}}
	vowels = usub(vowels, 2)
	
	while vowels ~= "" do
		local syll = {onset = "", vowel = "", coda = ""}
		syll.onset, syll.vowel, vowels = rmatch(vowels, "^([iu]?)(.)(.-)$")
		table.insert(syllables, syll)
	end
	
	local count = #syllables
	
	if count >= 2 and (syllables[count].vowel == "i" or syllables[count].vowel == "u") then
		syllables[count - 1].coda = syllables[count].vowel
		syllables[count] = nil
	end
	
	return syllables
end

-- Split the word into syllables
local function split_syllables(remainder)
	local syllables = {}
	
	while remainder ~= "" do
		local consonants, vowels
		
		consonants, remainder = rmatch(remainder, "^([^aeiouàèéêëíòóôúïü]*)(.-)$")
		vowels, remainder = rmatch(remainder, "^([aeiouàèéêëíòóôúïü]*)(.-)$")
		
		if vowels == "" then
			syllables[#syllables].coda = syllables[#syllables].coda .. consonants
		else
			local onset = consonants
			local first_vowel = usub(vowels, 1, 1)
			
			if (rfind(onset, "[gq]$") and (first_vowel == "ü" or (first_vowel == "u" and vowels ~= "u")))
			or ((onset == "" or onset == "h") and #syllables == 0 and first_vowel == "i" and vowels ~= "i")
			then
				onset = onset .. usub(vowels, 1, 1)
				vowels = usub(vowels, 2)
			end
			
			local vsyllables = split_vowels(vowels)
			vsyllables[1].onset = onset .. vsyllables[1].onset
			
			for _, s in ipairs(vsyllables) do
				table.insert(syllables, s)
			end
		end
	end
	
	-- Shift over consonants from the onset to the preceding coda,
	-- until the syllable onset is valid
	for i = 2, #syllables do
		local current = syllables[i]
		local previous = syllables[i-1]
		
		while not (current.onset == "" or valid_onsets[current.onset]) do
			local letter = usub(current.onset, 1, 1)
			current.onset = usub(current.onset, 2)
			if not rfind(letter, "[·%-%.]") then -- syllables separators
				previous.coda = previous.coda .. letter
			else
				break
			end
		end
	end
	
	-- Detect stress
	for i, syll in ipairs(syllables) do
		if rfind(syll.vowel, "^[àèéêëíòóôú]$") then
			syllables.stress = i -- primary stress: the last one stressed
			syll.stressed = true
		end
	end
	
	if not syllables.stress then
		local count = #syllables
		
		if count == 1 then
			syllables.stress = 1
		else
			local final = syllables[count]
			
			if final.coda == "" or final.coda == "s" or (final.coda == "n" and (final.vowel == "e" or final.vowel == "i")) then
				syllables.stress = count - 1
			else
				syllables.stress = count
			end
		end
		syllables[syllables.stress].stressed = true
	end
	
	return syllables
end

local IPA_vowels = {
	["a"] = "a", ["à"] = "a",
	["e"] = "e", ["è"] = "ɛ", ["ê"] = "ɛ", ["ë"] = "ɛ", ["é"] = "e",
	["i"] = "i", ["í"] = "i", ["ï"] = "i",
	["o"] = "o", ["ò"] = "ɔ", ["ô"] = "ɔ", ["ó"] = "o",
	["u"] = "u", ["ú"] = "u", ["ü"] = "u",
}

local function replace_context_free(cons)
	cons = rsub(cons, "ŀ", "l")
	
	cons = rsub(cons, "r", "ɾ")
	cons = rsub(cons, "ɾɾ", "r")
	cons = rsub(cons, "ss", "s")
	cons = rsub(cons, "ll", "ʎ")
	cons = rsub(cons, "ñ", "ɲ") -- hint ny > ñ
	
	cons = rsub(cons, "[dt]j", "d͡ʒ")
	cons = rsub(cons, "tx", "t͡ʃ")
	cons = rsub(cons, "[dt]z", "d͡z")
	
	cons = rsub(cons, "ç", "s")
	cons = rsub(cons, "[cq]", "k")
	cons = rsub(cons, "h", "")
	cons = rsub(cons, "g", "ɡ")
	cons = rsub(cons, "j", "ʒ")
	cons = rsub(cons, "x", "ʃ")
	
	cons = rsub(cons, "i", "j") -- must be after j > ʒ
	cons = rsub(cons, "y", "j") -- must be after j > ʒ and fix_y
	cons = rsub(cons, "[uü]", "w")
	
	return cons
end

local function postprocess_general(syllables)
	syllables = mw.clone(syllables)
	
	local voiced = listToSet {"b", "ð", "d", "ɡ", "m", "n", "ɲ", "l", "ʎ", "r", "ɾ", "v", "z", "ʒ"}
	local voiceless = listToSet {"p", "t", "k", "f", "s", "ʃ", ""}
	local voicing = {["k"]="ɡ", ["f"]="v", ["p"]="b", ["t"]="d", ["s"]="z"}
	local devoicing = {["b"]="p", ["d"]="t", ["ɡ"]="k"}
	
	for i = 1, #syllables do
		local current = syllables[i]
		local previous = syllables[i - 1]
		
		-- Coda consonant losses
		if i < #syllables or (i == #syllables and rfind(current.coda, "s$")) then
			current.coda = rsub(current.coda, "m[pb]", "m")
			current.coda = rsub(current.coda, "([ln])[td]", "%1")
			current.coda = rsub(current.coda, "n[kɡ]", "ŋ")
		end
		
		-- Consonant assimilations
		if i > 1 then
			-- t + lateral/nasal assimilation
			local cons = rmatch(current.onset, "^([lʎmn])")
			if cons then
				previous.coda = rsub(previous.coda, "t$", cons)
			end
			
			-- n + labial > labialized assimilation
			if rfind(current.onset, "^[mbp]") then
				previous.coda = rsub(previous.coda, "n$", "m")
			elseif rfind(current.onset, "^[fv]") then
				previous.coda = rsub(previous.coda, "n$", "m") -- strictly ɱ
			
			-- l/n + palatal > palatalized assimilation
			elseif rfind(current.onset, "^[ʒʎʃɲ]")
			or rfind(current.onset, "^t͡ʃ")
			or rfind(current.onset, "^d͡ʒ")
			then
				previous.coda = rsub(previous.coda, "[ln]$", {["l"] = "ʎ", ["n"] = "ɲ"})
			end
			
			-- ɡʒ > d͡ʒ
			if previous.coda == "ɡ" and current.onset == "ʒ" then
				previous.coda = ""
				current.onset = "d͡ʒ"
			end
		end
		
		current.coda = rsub(current.coda, "n[kɡ]", "ŋk")
		current.coda = rsub(current.coda, "n([ʃʒ])", "ɲ%1")
		current.coda = rsub(current.coda, "n(t͡ʃ)", "ɲ%1")
		current.coda = rsub(current.coda, "n(d͡ʒ)", "ɲ%1")
		
		current.coda = rsub(current.coda, "l([ʃʒ])", "ʎ%1")
		current.coda = rsub(current.coda, "l(t͡ʃ)", "ʎ%1")
		current.coda = rsub(current.coda, "l(d͡ʒ)", "ʎ%1")
		
		current.coda = rsub(current.coda, "ɲs", "ɲʃ")
		
		-- Voicing or devoicing
		if i > 1 then
			local coda_letter = usub(previous.coda, -1)
			local onset_letter = usub(current.onset, 1, 1)
			if voiced[onset_letter] and voicing[coda_letter] then
				previous.coda = rsub(previous.coda, coda_letter .. "$", voicing[coda_letter])
			elseif voiceless[onset_letter] and devoicing[coda_letter] then
				previous.coda = rsub(previous.coda, coda_letter .. "$", devoicing[coda_letter])
			else
				previous.coda = rsub(previous.coda, "[bd]s", {["bs"] = "ps", ["ds"] = "ts"})
			end
		end
		
		-- Allophones of r
		if i == 1 then
			current.onset = rsub(current.onset, "^ɾ", "r")
		end
		
		-- no spirants after r/z
		if i > 1 and mw.ustring.find(previous.coda, "[rz]$") then
			current.onset = mw.ustring.gsub(current.onset, "^[βðɣ]", {["β"] = "b", ["ð"] = "d", ["ɣ"] = "ɡ"})
		end
		
		if i > 1 then
			if rfind(previous.coda, "[lns]$") then
				current.onset = rsub(current.onset, "^ɾ", "r")
			end
		end
		
		-- Double sound of letter x > ks/gz (on cultisms, ambiguous in onsets)
		current.coda = rsub(current.coda, "^ʃs?", "ks")
		if i > 1 and previous.coda == "kz" then
			previous.coda = "ɡz" -- voicing the group
		end
		if i > 1 and current.onset == "s" then
			previous.coda = rsub(previous.coda, "s$", "") -- reduction exs, exc(e/i) and sc(e/i)
		end
		
		if i > 1 and previous.onset == "" and (previous.vowel == "e" or previous.vowel == "ɛ")
		and ((previous.coda == "" and current.onset == "ʃ") or (previous.coda == "ks" and current.onset == ""))
		then
			-- ex + (h) vowel > egz
			previous.coda = "ɡ"
			current.onset = "z"
		end
	end

	-- Final devoicing
	local final = syllables[#syllables].coda
	
	final = rsub(final, "d͡ʒ", "t͡ʃ")
	final = rsub(final, "d͡z", "t͡s")
	final = rsub(final, "b", "p")
	final = rsub(final, "d", "t")
	final = rsub(final, "ɡ", "k")
	final = rsub(final, "ʒ", "ʃ")
	final = rsub(final, "v", "f")
	final = rsub(final, "z", "s")
	
	-- Final loses
	final = rsub(final, "j(t͡ʃ)", "%1")
	final = rsub(final, "([ʃs])s", "%1") -- homophone plurals -xs, -igs, -çs
	
	syllables[#syllables].coda = final
	
	return syllables
end

local function mid_vowel_e(syllables)
	-- most common cases, other ones are supposed ambiguous
	post_consonants = syllables[syllables.stress].coda
	post_vowel = ""
	post_letters = post_consonants
	if syllables.stress == #syllables - 1 then
		post_consonants = post_consonants .. syllables[#syllables].onset
		post_vowel = syllables[#syllables].vowel
		post_letters = post_consonants .. post_vowel .. syllables[#syllables].coda
	end
	
	if syllables[syllables.stress].vowel == "e" then
		if post_vowel == "i" or post_vowel == "u" then
			return "è"
		elseif rfind(post_letters, "^ct[ae]?s?$") then
			return "è"
		elseif post_letters == "dre" or post_letters == "dres" then
			return "é"
		elseif rfind(post_consonants, "^l") and syllables.stress == #syllables then
			return "è"
		elseif post_consonants == "l" or post_consonants == "ls" or post_consonants == "l·l" then
			return "è"
		elseif (post_letters == "ma" or post_letters == "mes") and #syllables > 2 then
			return "ê"
		elseif post_letters == "ns" or post_letters == "na" or post_letters == "nes" then -- inflection of -è
			require("Module:debug/track")("ca-IPA/ens-ena-enes") -- checking ê or ë
			return "ê"
		elseif post_letters == "nse" or post_letters == "nses" then
			return "ê"
		elseif post_letters == "nt" or post_letters == "nts" then
			return "é"
		elseif rfind(post_letters, "^r[ae]?s?$") then
			return "é"
		elseif rfind(post_consonants, "^r[dfjlnrstxyz]") then -- except bilabial and velar
			return "è"
		elseif post_letters == "sos" or post_letters == "sa" or post_letters == "ses" then -- inflection of -ès
			return "ê"
		elseif rfind(post_letters, "^t[ae]?s?$") then
			return "ê"
		end
	elseif syllables[syllables.stress].vowel == "è" then
		if post_letters == "s" or post_letters == "" then -- -ès, -è
			return "ê"
		end
	end
	
	return nil
end

local function mid_vowel_o(syllables)
	-- most common cases, other ones are supposed ambiguous
	post_consonants = syllables[syllables.stress].coda
	post_vowel = ""
	post_letters = post_consonants
	if syllables.stress == #syllables - 1 then
		post_consonants = post_consonants .. syllables[#syllables].onset
		post_vowel = syllables[#syllables].vowel
		post_letters = post_consonants .. post_vowel .. syllables[#syllables].coda
	end
	
	if post_vowel == "i" or post_vowel == "u" then
		return "ò"
	elseif usub(post_letters, 1, 1) == "i" and usub(post_letters, 1, 2) ~= "ix" then -- diphthong oi
		return "ò"
	elseif rfind(post_letters, "^u[^s]") then -- diphthong ou, ambiguous if final
		return "ò"
	elseif #syllables == 1 and (post_letters == "" or post_letters == "s" or post_letters == "ns") then -- monosyllable
		return "ò"
	elseif post_letters == "fa" or post_letters == "fes" then
		return "ò"
	elseif post_consonants == "fr" then
		return "ó"
	elseif post_letters == "ldre" then
		return "ò"
	elseif post_letters == "ma" or post_letters == "mes" then
		return "ó"
	elseif post_letters == "ndre" then
		return "ò"
	elseif rfind(post_letters, "^r[ae]?s?$") then
		return "ó"
	elseif rfind(post_letters, "^r[ft]s?$") then
		return "ò"
	elseif post_letters == "rme" or post_letters == "rmes" then
		return "ó"
	end
	
	return nil
end

local function to_IPA(syllables, mid_vowel_hint)
	-- Stressed vowel is ambiguous
	if rfind(syllables[syllables.stress].vowel, "[eéèoòó]") then
		if mid_vowel_hint then
			syllables[syllables.stress].vowel = mid_vowel_hint
		elseif syllables[syllables.stress].vowel == "e" or syllables[syllables.stress].vowel == "o" then
			local marks = {["e"] = mw.ustring.char(0x0301, 0x0300, 0x0302, 0x0308), ["o"] = mw.ustring.char(0x0301, 0x0300, 0x0302)}
			error("The stressed vowel \"" .. syllables[syllables.stress].vowel
				.. "\" is ambiguous. Please mark it with an acute, grave, or combined accent: "
				.. table.concat(
					require("Module:fun").map(
						function (accent)
							return syllables[syllables.stress].vowel .. accent
						end,
						marks[syllables[syllables.stress].vowel]),
					", "):gsub("^(.+), ", "%1, or ")
				.. ".")
		end
	end
	
	local syllables_IPA = {stress = syllables.stress}
	
	for key, val in ipairs(syllables) do
		syllables_IPA[key] = {onset = val.onset, vowel = val.vowel, coda = val.coda, stressed = val.stressed}
	end
	
	-- Replace letters with IPA equivalents
	for i, syll in ipairs(syllables_IPA) do
		-- Voicing of s
		if syll.onset == "s" and i > 1 and (syllables[i-1].coda == "" or syllables[i-1].coda == "i" or syllables[i-1].coda == "u") then
			syll.onset = "z"
		end
		
		if rfind(syll.vowel, "^[eèéêëií]$") then
			syll.onset = rsub(syll.onset, "tg$", "d͡ʒ")
			syll.onset = rsub(syll.onset, "[cg]$", {["c"] = "s", ["g"] = "ʒ"})
			syll.onset = rsub(syll.onset, "[qg]u$", {["qu"] = "k", ["gu"] = "ɡ"})
		end
		
		syll.coda = rsub(syll.coda, "igs?$", "id͡ʒ")
		
		syll.onset = replace_context_free(syll.onset)
		syll.coda = replace_context_free(syll.coda)
		
		syll.vowel = rsub(syll.vowel, ".", IPA_vowels)
	end
	
	syllables_IPA = postprocess_general(syllables_IPA)
	
	return syllables_IPA
end

-- Reduction of unstressed a,e in Central and Balearic (Eastern Catalan)
local function reduction_ae(syllables)
	for i = 1, #syllables do
		local current = syllables[i]
		local previous = syllables[i - 1] or {onset = "", vowel = "", coda = ""}
		local posterior = syllables[i + 1] or {onset = "", vowel = "", coda = ""}
		
		local pre_vowel_pair = previous.vowel .. previous.coda .. current.onset .. current.vowel
		local post_vowel_pair = current.vowel .. current.coda .. posterior.onset .. posterior.vowel
		local reduction = true
		
		if current.stressed then
			reduction = false
		elseif pre_vowel_pair == "əe" then
			reduction = false
		elseif post_vowel_pair == "ea" or post_vowel_pair == "eɔ" then
			reduction = false
		elseif i < syllables.stress -1 and post_vowel_pair == "ee" then
			posterior.vowel = "ə"
		elseif i > syllables.stress and post_vowel_pair == "ee" then
			reduction = false
		elseif pre_vowel_pair == "oe" or pre_vowel_pair == "ɔe" then
			reduction = false
		end
		
		if reduction then
			current.vowel = rsub(current.vowel, "[ae]", "ə")
		end
	end
	return syllables
end

local accents = {}

accents.cen = function(syllables)
	syllables = mw.clone(syllables)
	
	-- Reduction of unstressed vowels a,e
	syllables = reduction_ae(syllables)
	
	-- Final consonant losses
	local final = syllables[#syllables].coda
	
	final = rsub(final, "^ɾ(s?)$", "%1") -- no loss with hint -rr
	final = rsub(final, "m[pb]$", "m")
	final = rsub(final, "([ln])[td]$", "%1")
	final = rsub(final, "[nŋ][kɡ]$", "ŋ")
	
	syllables[#syllables].coda = final
	
	for i = 1, #syllables do
		local current = syllables[i]
		local previous = syllables[i-1]
		
		-- Reduction of unstressed o
		if current.vowel == "o" and not (current.stressed or current.coda == "w") then
			current.vowel = rsub(current.vowel, "o", "u")
		end
		
		-- v > b
		current.onset = rsub(current.onset, "v", "b")
		current.coda = rsub(current.coda, "nb", "mb")
		if i > 1 and rfind(current.onset, "^b") then
			previous.coda = rsub(previous.coda, "n$", "m")
		end
		
		-- allophones of r
		current.coda = rsub(current.coda, "ɾ", "r")
		
		-- Remove j before palatal obstruents
		current.coda = rsub(current.coda, "j([ʃʒ])", "%1")
		current.coda = rsub(current.coda, "j(t͡ʃ)", "%1")
		current.coda = rsub(current.coda, "j(d͡ʒ)", "%1")
		
		if i > 1 then
			if rfind(current.onset, "^[ʃʒ]") or rfind(current.onset, "^t͡ʃ") or rfind(current.onset, "^d͡ʒ") then
				previous.coda = rsub(previous.coda, "j$", "")
			end
		end
	end
	
	return syllables
end

accents.bal = function(syllables, mid_vowel_hint)
	syllables = mw.clone(syllables)
	
	-- Reduction of unstressed vowels a,e
	syllables = reduction_ae(syllables)
	
	for i = 1, #syllables do
		local current = syllables[i]
		local previous = syllables[i-1]
		
		-- Reduction of unstressed o per vowel harmony
		if i > 1 and current.stressed and rfind(current.vowel, "[iu]") and not previous.stressed then
			previous.vowel = rsub(previous.vowel, "o", "u")
		end
		
		-- Stressed schwa
		if i == syllables.stress and mid_vowel_hint == "ê" then -- not ë
			current.vowel = rsub(current.vowel, "ɛ", "ə")
		end
		
		-- Remove j before palatal obstruents
		current.coda = rsub(current.coda, "j([ʃʒ])", "%1")
		current.coda = rsub(current.coda, "j(t͡ʃ)", "%1")
		current.coda = rsub(current.coda, "j(d͡ʒ)", "%1")
		
		if i > 1 then
			if rfind(current.onset, "^[ʃʒ]") or rfind(current.onset, "^t͡ʃ") or rfind(current.onset, "^d͡ʒ") then
				previous.coda = rsub(previous.coda, "j$", "")
			end
		end
		
		-- No palatal gemination ʎʎ > ll or ʎ, in Valencian and Balearic
		if i > 1 and current.onset == "ʎ" and previous.coda == "ʎ" then
			local prev_syll = previous.onset .. previous.vowel .. previous.coda
			if rfind(prev_syll, "[bpw]aʎ$")
				or rfind(prev_syll, "[mv]eʎ$")
				or rfind(prev_syll, "tiʎ$")
				or rfind(prev_syll, "m[oɔ]ʎ$")
				or (rfind(prev_syll, "uʎ$") and current.vowel == "a")
				then
				previous.coda = "l"
				current.onset = "l"
			else
				previous.coda = ""
			end
		end
		
		-- Final consonant losses
		if #syllables == 1 then
			current.coda = rsub(current.coda, "ɾ(s?)$", "%1") -- no loss with hint -rr in monosyllables
		elseif i == #syllables then
			current.coda = rsub(current.coda, "[rɾ](s?)$", "%1") -- including hint -rr
		end
	end
	
	return syllables
end

accents.val = function(syllables, mid_vowel_hint)
	syllables = mw.clone(syllables)
	
	for i = 1, #syllables do
		local current = syllables[i]
		local previous = syllables[i-1]
		
		-- Variable mid vowel
		if i == syllables.stress and (mid_vowel_hint == "ê" or mid_vowel_hint == "ë" or mid_vowel_hint == "ô") then
			current.vowel = rsub(current.vowel, "[ɛëɔ]", {["ɛ"] = "e", ["ë"] = "e", ["ɔ"] = "o"})
		end
		
		-- Fortition of palatal fricatives
		current.onset = rsub(current.onset, "ʒ", "d͡ʒ")
		current.onset = rsub(current.onset, "d͡d", "d")
		
		current.coda = rsub(current.coda, "ʒ", "d͡ʒ")
		current.coda = rsub(current.coda, "d͡d", "d")
		
		if i > 1 and previous.vowel == "i" and previous.coda == "" and current.onset == "d͡z" then
			current.onset = "z"
		elseif (i == 1 and current.onset == "ʃ")
			or (i > 1 and current.onset == "ʃ" and previous.coda ~= "" and previous.coda ~= "j")
			then
			current.onset = "t͡ʃ"
		end
		
		-- No palatal gemination ʎʎ > ll or ʎ, in Valencian and Balearic
		if i > 1 and current.onset == "ʎ" and previous.coda == "ʎ" then
			local prev_syll = previous.onset .. previous.vowel .. previous.coda
			if rfind(prev_syll, "[bpw]aʎ$")
				or rfind(prev_syll, "[mv]eʎ$")
				or rfind(prev_syll, "tiʎ$")
				or rfind(prev_syll, "m[oɔ]ʎ$")
				or (rfind(prev_syll, "uʎ$") and current.vowel == "a")
				then
				previous.coda = "l"
				current.onset = "l"
			else
				previous.coda = ""
			end
		end
		
		-- Hint -rr only for Central
		if i == #syllables then
			current.coda = rsub(current.coda, "r(s?)$", "ɾ%1")
		end
	end
	
	return syllables
end


local accent_order = {}

for accent, _ in pairs(accents) do
	table.insert(accent_order, accent)
end

table.sort(accent_order)


local function join_syllables(syllables)
	syllables = mw.clone(syllables)
	
	for i, syll in ipairs(syllables) do
		syll = syll.onset .. syll.vowel .. syll.coda
	
		if i == syllables.stress then -- primary stress
			syll = "ˈ" .. syll
		elseif syllables[i].stressed then -- secondary stress
			syll = "ˌ" .. syll
		end
		
		syllables[i] = syll
	end
	
	return rsub(table.concat(syllables, "."), ".([ˈˌ])", "%1")
end

local function group_sort_and_format(syllables, mid_vowel_hint, test)
	local grouped = {}

	for _, accent in pairs(accent_order) do
		local ipa = join_syllables(accents[accent](syllables, mid_vowel_hint))
		if grouped[ipa] then
			table.insert(grouped[ipa], accent)
		else
			grouped[ipa] = {accent}
		end
	end
	
	local out = {}
	
	if test then
		for ipa, accents in pairs(grouped) do
			table.insert(out, table.concat(accents, ", ") .. ": " .. ipa)
		end
	else
		for ipa, accents in pairs(grouped) do
			table.insert(out, m_a.show(accents) .. " " .. m_IPA.format_IPA_full(lang, {{pron = ipa}}))
		end
	end
	
	table.sort(out)
	return out
end


local function convert_respelling_to_original(to, pagename, whole_word)
	local patut = require(patut_module)
	local from = rsub(to, "ks", "x")
	local escaped_from = patut.pattern_escape(from)
	if whole_word then
		escaped_from = "%f[%a]" .. escaped_from .. "%f[%A]"
	end
	if rfind(pagename, escaped_from) then
		return from
	end
	error(("Single substitution spec '%s' couldn't be matched to pagename '%s'"):format(to, pagename))
end
	

-- Parse a respelling given by the user, allowing for '+' for pagename, mid vowel hints in place of a respelling
-- and substitution specs like '[ks]' or [val:vol,ê,ks]. Return an object
-- {term = PARSED_RESPELLING, mid_vowel_hint = MID_VOWEL_HINT}.
local function parse_respelling(respelling, pagename, parse_err)
	local saw_raw
	local remaining_respelling = respelling:match("^raw:(.*)$")
	if remaining_respelling then
		saw_raw = true
		respelling = remaining_respelling
	end
	local raw_phonemic, raw_phonetic = respelling:match("^/(.*)/ %[(.*)%]$")
	if not raw_phonemic then
		raw_phonemic = respelling:match("^/(.*)/$")
	end
	if not raw_phonemic and saw_raw then
		raw_phonetic = respelling:match("^%[(.*)%]$")
	end
	if raw_phonemic or raw_phonetic then
		return {
			raw_phonemic = raw_phonemic,
			raw_phonetic = raw_phonetic,
		}
	end

	local mid_vowel_hint
	if respelling == "+" then
		respelling = pagename
	elseif rfind(respelling, "^" .. export.mid_vowel_hint_c .. "$") then
		mid_vowel_hint = respelling
		respelling = pagename
	elseif rfind(respelling, "^%[.*%]$") then
		local subs = rsplit(rmatch(respelling, "^%[(.*)%]$"), ",")
		respelling = pagename
		for _, sub in ipairs(subs) do
			local from, escaped_from, to, escaped_to, whole_word
			if rfind(sub, "^~") then
				-- whole-word match
				sub = rmatch(sub, "^~(.*)$")
				whole_word = true
			end
			if sub:find(":") then
				from, to = rmatch(sub, "^(.-):(.*)$")
			elseif rfind(sub, "^" .. export.mid_vowel_hint_c .. "$") then
				if mid_vowel_hint then
					parse_err(("Specified mid vowel hint twice, '%s' and '%s'"):format(
						mid_vowel_hint, sub))
				end
				mid_vowel_hint = sub
			else
				to = sub
				from = convert_respelling_to_original(to, pagename, whole_word)
			end
			if from then
				local patut = require(patut_module)
				escaped_from = patut.pattern_escape(from)
				if whole_word then
					escaped_from = "%f[%a]" .. escaped_from .. "%f[%A]"
				end
				escaped_to = patut.replacement_escape(to)
				local subbed_respelling, nsubs = rsub(respelling, escaped_from, escaped_to)
				if nsubs == 0 then
					parse_err(("Substitution spec %s -> %s didn't match processed pagename"):format(from, to))
				elseif nsubs > 1 then
					parse_err(("Substitution spec %s -> %s matched multiple substrings in processed pagename, add more context"):format(from, to))
				else
					respelling = subbed_respelling
				end
			end
		end
	end

	return {term = respelling, mid_vowel_hint = mid_vowel_hint}
end


-- Parse a list of comma-split runs containing one or more respellings, i.e. after calling parse_balanced_segment_run()
-- or the like followed by split_alternating_runs() or the like (see [[Module:parse utilities]]). `pagename` is the
-- pagename, for use when a respelling is just '+', a mid-vowel hint like 'ê' or a substitution spec like '[ks]'.
-- `original_input` is the raw input and `input_param` the name of the param containing the raw input; both are used
-- only in error messages. Return an object specifying the respellings, currently with a single field 'terms' (this
-- format is used in case other outer properties exist in the future), where 'terms' is a list of term objects. Each
-- term object contains either a field 'term' with the respelling and an optional field 'mid_vowel_hint' with the
-- extracted mid-vowel hint (e.g. "ê"), or fields 'raw_phonemic' and/or 'raw_phonetic' (if the user specified raw IPA
-- using "/.../" or "/.../ [...]" or "raw:[...]"). In addition, there may be fields 'q', 'qq', 'a', 'aa', and/or 'ref'
-- corresponding to inline modifiers. Each such field is a list; all are lists of strings except for 'ref', which is
-- a list of objects as returned by parse_references() in [[Module:references]].
function export.parse_comma_separated_groups(comma_separated_groups, pagename, original_input, input_param)
	local function generate_obj(respelling, parse_err)
		return parse_respelling(respelling, pagename == true and respelling or pagename, parse_err)
	end
	local put = require(parse_utilities_module)

	local outer_container = {terms = {}}
	for _, group in ipairs(comma_separated_groups) do
		-- Rejoin runs that don't involve <...>.
		local j = 2
		while j <= #group do
			if not group[j]:find("^<.*>$") then
				group[j - 1] = group[j - 1] .. group[j] .. group[j + 1]
				table.remove(group, j)
				table.remove(group, j)
			else
				j = j + 2
			end
		end

		local param_mods = {
			-- pre = { overall = true },
			-- post = { overall = true },
			ref = { store = "insert", convert = function(arg, parse_err)
				return require("Module:references").parse_references(arg)
			end },
			q = { store = "insert" },
			qq = { store = "insert" },
			a = { store = "insert" },
			aa = { store = "insert" },
		}

		table.insert(outer_container.terms, put.parse_inline_modifiers_from_segments {
			group = group,
			arg = original_input,
			props = {
				paramname = input_param,
				param_mods = param_mods,
				generate_obj = generate_obj,
				splitchar = ",",
				outer_container = outer_container,
			},
		})
	end

	return outer_container
end


-- Generate the pronunciation of `word` (a string, the respelling), where `mid_vowel_hint` specifies how to handle
-- stressed mid vowels. Return two values: the phonemic pronunciation along with the mid vowel hint, determined from
-- the respelling itself if `mid_vowel_hint` isn't passed in.
local function generate_pronun_syllables(word, mid_vowel_hint)
	word = word_fixes(word)
	
	local syllables = split_syllables(word)
	if mid_vowel_hint == nil then
		if rfind(syllables[syllables.stress].vowel, "[éêëòóô]") then
			mid_vowel_hint = rmatch(syllables[syllables.stress].vowel, "[éêëòóô]")
		elseif rfind(syllables[syllables.stress].vowel, "[eè]") then
			mid_vowel_hint = mid_vowel_e(syllables)
		elseif syllables[syllables.stress].vowel == "o" then
			mid_vowel_hint = mid_vowel_o(syllables)
		end
	end
	return to_IPA(syllables, mid_vowel_hint), mid_vowel_hint
end


-- Generate the phonemic and phonetic pronunciations of the respellings in `parsed_respellings`, which is a table whose
-- keys are dialect identifiers (e.g. "cen" for Central Catalan, "val" for Valencian) and whose values are objects of
-- the format returned by parse_comma_separated_groups() (see comment above that function). This destructively modifies
-- `parsed_respellings`, adding fields `phonemic` and `phonetic` containing the generated pronunciations and removing
-- the input fields used to generate those output fields. (FIXME: Currently only phonemic pronunciation is generated.)
function export.generate_phonemic_phonetic(parsed_respellings)
	-- Convert each canonicalized respelling to phonemic/phonetic IPA.
	for dialect, respelling_spec in pairs(parsed_respellings) do
		for _, termobj in ipairs(respelling_spec.terms) do
			if termobj.raw_phonemic or termobj.raw_phonetic then
				termobj.phonemic = termobj.raw_phonemic
				termobj.phonetic = termobj.raw_phonetic
				-- set to nil so by-value comparisons respect only the resulting phonemic/phonetic and qualifiers
				termobj.raw_phonemic = nil
				termobj.raw_phonetic = nil
			else
				local word = ulower(termobj.term)
				local mid_vowel_hint = termobj.mid_vowel_hint
				local syllables, mid_vowel_hint = generate_pronun_syllables(word, mid_vowel_hint)
				termobj.phonemic = join_syllables(accents[dialect](syllables, mid_vowel_hint))
				-- set to nil so by-value comparisons respect only the resulting phonemic/phonetic and qualifiers
				termobj.term = nil
				termobj.mid_vowel_hint = nil
			end
		end
	end
end


-- Group pronunciations by dialect, i.e. grouping pronunciations that are identical in every way (including both the
-- pronunciation(s) and any qualifiers and other inline modifiers). `parsed_respellings` contains the output from
-- generate_phonemic_phonetic(), and the return value is a list of grouped pronunciations, where each object in the list
-- contains fields 'dialects' (a list of dialects containing the pronunciations) and 'pronuns' (a list of
-- pronunciations, where each pronunciation is specified by an object containing fields 'phonemic' and 'phonetic', as
-- generated by generate_phonemic_phonetic(), along with any inline modifier fields 'q', 'qq', 'a', 'aa' and/or 'ref').
function export.group_pronuns_by_dialect(parsed_respellings)
	local grouped_pronuns = {}
	for dialect, pronun_spec in pairs(parsed_respellings) do
		local saw_existing = false
		for _, group in ipairs(grouped_pronuns) do
			if m_table.deepEquals(group.pronuns, pronun_spec.terms) then
				table.insert(group.dialects, dialect)
				saw_existing = true
				break
			end
		end
		if not saw_existing then
			table.insert(grouped_pronuns, {dialects = {dialect}, pronuns = pronun_spec.terms})
		end
	end
	return grouped_pronuns
end


-- Format pronunciations grouped by dialect. `grouped_pronuns` contains the output of group_pronuns_by_dialect().
-- This destructively modifies `grouped_pronuns`, adding a field 'formatted' to the first-level values of
-- `grouped_pronuns` containing the formatted pronunciation(s) for a given set of dialects.
function export.format_grouped_pronunciations(grouped_pronuns)
	for _, grouped_pronun_spec in pairs(grouped_pronuns) do
		local pronunciations = {}

		-- Loop through each pronunciation. For each one, add the phonemic and phonetic versions to `pronunciations`,
		-- for formatting by [[Module:IPA]] or raw (for use in [[Module:ca-headword]]).
		for j, pronun in ipairs(grouped_pronun_spec.pronuns) do
			-- Add dialect tags to left accent qualifiers if first one
			local as = pronun.a
			if j == 1 then
				if as then
					as = m_table.deepcopy(as)
				else
					as = {}
				end
				for _, dialect in ipairs(grouped_pronun_spec.dialects) do
					table.insert(as, export.dialects_to_names[dialect])
				end
			end

			local first_pronun = #pronunciations + 1

			if not pronun.phonemic and not pronun.phonetic then
				error("Internal error: Saw neither phonemic nor phonetic pronunciation")
			end

			if pronun.phonemic then -- missing if 'raw:[...]' given
				local slash_pron = "/" .. pronun.phonemic .. "/"
				table.insert(pronunciations, {
					pron = slash_pron,
				})
			end

			if pronun.phonetic then -- missing if '/.../' given
				local bracket_pron = "[" .. pronun.phonetic .. "]"
				table.insert(pronunciations, {
					pron = bracket_pron,
				})
			end

			local last_pronun = #pronunciations

			if pronun.q then
				pronunciations[first_pronun].q = pronun.q
			end
			if as then
				pronunciations[first_pronun].a = as
			end
			if j > 1 then
				pronunciations[first_pronun].separator = ", "
			end
			if pronun.qq then
				pronunciations[last_pronun].qq = pronun.qq
			end
			if pronun.aa then
				pronunciations[last_pronun].aa = pronun.aa
			end
			if pronun.refs then
				pronunciations[last_pronun].refs = pronun.refs
			end
			if first_pronun ~= last_pronun then
				pronunciations[last_pronun].separator = " "
			end
		end

		grouped_pronun_spec.formatted = m_IPA.format_IPA_full(lang, pronunciations, nil, "")
	end
end


function export.show(frame)
	local params = {
		[1] = {},
		indent = {},
		pagename = {} -- for testing or documentation pages
	}

	for _, dialect in ipairs(export.dialects) do
		params[dialect] = {}
	end
	for dialect_group, _ in pairs(export.dialect_groups) do
		params[dialect_group] = {}
	end

	local args = require("Module:parameters").process(frame:getParent().args, params)
	local pagename = args.pagename or mw.title.getCurrentTitle().subpageText

	-- Set inputs
	local inputs = {}
	-- If 1= specified, do all dialects.
	if args[1] then
		for _, dialect in ipairs(export.dialects) do
			inputs[dialect] = {input = args[1], param = 1}
		end
	end
	-- Then do dialect groups.
	for dialect_group, group_dialects in pairs(export.dialect_groups) do
		if args[dialect_group] then
			for _, dialect in ipairs(group_dialects) do
				inputs[dialect] = {input = args[dialect_group], param = dialect_group}
			end
		end
	end
	-- Then do individual dialect settings.
	for _, dialect in ipairs(export.dialects) do
		if args[dialect] then
			inputs[dialect] = {input = args[dialect], param = dialect}
		end
	end
	-- If no inputs given, set all dialects based on current pagename.
	if not next(inputs) then
		for _, dialect in ipairs(export.dialects) do
			inputs[dialect] = {input = "+", param = "(pagename)"}
		end
	end

	-- Parse the arguments.
	local parsed_respellings = {}
	for dialect, inputspec in pairs(inputs) do
		local function generate_obj(respelling, parse_err)
			return parse_respelling(respelling, pagename, parse_err)
		end

		if inputspec.input:find("[<%[]") then
			local put = require(parse_utilities_module)
			-- Parse balanced segment runs involving either [...] (substitution notation) or <...> (inline modifiers).
			-- We do this because we don't want commas inside of square or angle brackets to count as respelling
			-- delimiters. However, we need to rejoin square-bracketed segments with nearby ones after splitting
			-- alternating runs on comma. For example, if we are given
			-- "a[x]a<q:learned>,[vol:vôl,ks]<q:nonstandard>", after calling
			-- parse_multi_delimiter_balanced_segment_run() we get the following output:
			--
			-- {"a", "[x]", "a", "<q:learned>", ",", "[vol:vôl,ks]", "", "<q:nonstandard>", ""}
			--
			-- After calling split_alternating_runs(), we get the following:
			--
			-- {{"a", "[x]", "a", "<q:learned>", ""}, {"", "[vol:vôl,ks]", "", "<q:nonstandard>", ""}}
			--
			-- We need to rejoin stuff on either side of the square-bracketed portions.
			local segments = put.parse_multi_delimiter_balanced_segment_run(inputspec.input, {{"<", ">"}, {"[", "]"}})

			local comma_separated_groups = put.split_alternating_runs_on_comma(segments)

			-- Process each value.
			local outer_container = export.parse_comma_separated_groups(comma_separated_groups, pagename,
				inputspec.input, inputspec.param)
			parsed_respellings[dialect] = outer_container
		else
			local termobjs = {}
			local function parse_err(msg)
				error(msg .. ": " .. inputspec.param .. "=" .. inputspec.input)
			end
			for _, term in ipairs(split_on_comma(inputspec.input)) do
				table.insert(termobjs, generate_obj(term, parse_err))
			end
			parsed_respellings[dialect] = {
				terms = termobjs,
			}
		end
	end

	-- Convert each canonicalized respelling to phonemic/phonetic IPA.
	export.generate_phonemic_phonetic(parsed_respellings)

	-- Group the results.
	local grouped_pronuns = export.group_pronuns_by_dialect(parsed_respellings)

	-- Format the results.
	export.format_grouped_pronunciations(grouped_pronuns)

	-- Concatenate formatted results.
	local formatted = {}
	for _, grouped_pronun_spec in ipairs(grouped_pronuns) do
		table.insert(formatted, grouped_pronun_spec.formatted)
	end
	local indent = (args.indent or "*") .. " "
	local out = table.concat(formatted, "\n" .. indent)
	if args.indent then
		out = indent .. out
	end

	return out
end

-- Used by [[Module:ca-IPA/testcases]].
function export.test(word, mid_vowel_hint)
	local syllables, mid_vowel_hint = generate_pronun_syllables(word, mid_vowel_hint)

	return table.concat(group_sort_and_format(syllables, mid_vowel_hint, true), ";<br>")
end

-- on debug console use: =p.debug("your_word", "your_hint")
function export.debug(word, mid_vowel_hint)
	local syllables, mid_vowel_hint = generate_pronun_syllables(ulower(word), mid_vowel_hint)

	local ret = {}

	for _, accent in ipairs(accent_order) do
		local syllables_accented = accents[accent](syllables, mid_vowel_hint)
		table.insert(ret, accent .. " " .. join_syllables(syllables_accented))
	end
	
	return table.concat(ret, "\n")
end

return export
