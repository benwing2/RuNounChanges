local m_ipa = require("Module:IPA")
local m_a = require("Module:accent qualifier")

local export = {}

local lang = require("Module:languages").getByCode("ca")

local usub = mw.ustring.sub
local ufind = mw.ustring.find
local umatch = mw.ustring.match
local ugsub = mw.ustring.gsub
local ulower = mw.ustring.lower

local patut_module = "Module:pattern utilities"

local listToSet = require("Module:table").listToSet

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
		if ufind(word, "^" .. pr) then
			return word
		end
	end
	
	-- Double r in prefix + r + vowel
	for _, pr in ipairs(prefix_r) do
		word = ugsub(word, "^(" .. pr .. ")r([aàeèéiíïoòóuúü])", "%1rr%2")
	end
	word = ugsub(word, "^eradic", "erradic")
	
	-- Double s in prefix + s + vowel
	for _, pr in ipairs(prefix_s) do
		word = ugsub(word, "^(" .. pr .. ")s([aàeèéiíïoòóuúü])", "%1ss%2")
	end
	
	-- Hiatus in prefix + i
	for _, pr in ipairs(prefix_i) do
		word = ugsub(word, "^(" .. pr .. ")i(.)", "%1ï%2")
	end
	
	-- Both prefix + r/s or i/u
	for _, pr in ipairs(prefix) do
		word = ugsub(word, "^(" .. pr .. ")([rs])([aàeèéiíïoòóuúü])", "%1%2%2%3")
		word = ugsub(word, "^(" .. pr .. ")i(.)", "%1ï%2")
		word = ugsub(word, "^(" .. pr .. ")u(.)", "%1ü%2")
	end
	
	-- Voiced s in prefix roots -fons-, -dins-, -trans-
	word = ugsub(word, "^enfons([aàeèéiíoòóuú])", "enfonz%1")
	word = ugsub(word, "^endins([aàeèéiíoòóuú])", "endinz%1")
	word = ugsub(word, "tr([aà])ns([aàeèéiíoòóuúbdghlmv])", "tr%1nz%2")
	
	-- in + ex > ineks/inegz
	word = ugsub(word, "^inex", "inhex")
	
	return word
end

local function restore_diaereses(word)
	-- Some structural forms do not have diaeresis per diacritic savings, let's restore it to identify hiatus
	
	word = ugsub(word, "([iu])um(s?)$", "%1üm%2") -- Latinisms (-ius is ambiguous but rare)
	
	word = ugsub(word, "([aeiou])isme(s?)$", "%1ísme%2") -- suffix -isme
	word = ugsub(word, "([aeiou])ist([ae]s?)$", "%1íst%2") -- suffix -ista
	
	word = ugsub(word, "([aeou])ir$", "%1ír") -- verbs -ir
	word = ugsub(word, "([aeou])int$", "%1ínt") -- present participle
	word = ugsub(word, "([aeo])ir([éà])$", "%1ïr%2") -- future
	word = ugsub(word, "([^gq]u)ir([éà])$", "%1ïr%2")
	word = ugsub(word, "([aeo])iràs$", "%1ïràs")
	word = ugsub(word, "([^gq]u)iràs$", "%1ïràs")
	word = ugsub(word, "([aeo])ir(e[mu])$", "%1ïr%2")
	word = ugsub(word, "([^gq]u)ir(e[mu])$", "%1ïr%2")
	word = ugsub(word, "([aeo])iran$", "%1ïran")
	word = ugsub(word, "([^gq]u)iran$", "%1ïran")
	word = ugsub(word, "([aeo])iria$", "%1ïria") -- conditional
	word = ugsub(word, "([^gq]u)iria$", "%1ïria")
	word = ugsub(word, "([aeo])ir(ie[sn])$", "%1ïr%2")
	word = ugsub(word, "([^gq]u)ir(ie[sn])$", "%1ïr%2")
	
	return word
end

local function fix_y(word)
	-- y > vowel i else consonant /j/, except ny
	
	word = ugsub(word, "ny", "ñ")
	
	word = ugsub(word, "y([^aeiouàèéêëíòóôúïü])", "i%1") -- vowel if not next to another vowel
	word = ugsub(word, "([^aeiouàèéêëíòóôúïü·%-%.])y", "%1i") -- excluding also syllables separators
	
	return word
end

local function word_fixes(word)
	word = ugsub(word, "%-([rs]?)", "-%1%1")
	word = ugsub(word, "rç$", "rrs") -- silent r only in plurals -rs
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
		syll.onset, syll.vowel, vowels = umatch(vowels, "^([iu]?)(.)(.-)$")
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
		
		consonants, remainder = umatch(remainder, "^([^aeiouàèéêëíòóôúïü]*)(.-)$")
		vowels, remainder = umatch(remainder, "^([aeiouàèéêëíòóôúïü]*)(.-)$")
		
		if vowels == "" then
			syllables[#syllables].coda = syllables[#syllables].coda .. consonants
		else
			local onset = consonants
			local first_vowel = usub(vowels, 1, 1)
			
			if (ufind(onset, "[gq]$") and (first_vowel == "ü" or (first_vowel == "u" and vowels ~= "u")))
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
			if not ufind(letter, "[·%-%.]") then -- syllables separators
				previous.coda = previous.coda .. letter
			else
				break
			end
		end
	end
	
	-- Detect stress
	for i, syll in ipairs(syllables) do
		if ufind(syll.vowel, "^[àèéêëíòóôú]$") then
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
	cons = ugsub(cons, "ŀ", "l")
	
	cons = ugsub(cons, "r", "ɾ")
	cons = ugsub(cons, "ɾɾ", "r")
	cons = ugsub(cons, "ss", "s")
	cons = ugsub(cons, "ll", "ʎ")
	cons = ugsub(cons, "ñ", "ɲ") -- hint ny > ñ
	
	cons = ugsub(cons, "[dt]j", "d͡ʒ")
	cons = ugsub(cons, "tx", "t͡ʃ")
	cons = ugsub(cons, "[dt]z", "d͡z")
	
	cons = ugsub(cons, "ç", "s")
	cons = ugsub(cons, "[cq]", "k")
	cons = ugsub(cons, "h", "")
	cons = ugsub(cons, "g", "ɡ")
	cons = ugsub(cons, "j", "ʒ")
	cons = ugsub(cons, "x", "ʃ")
	
	cons = ugsub(cons, "i", "j") -- must be after j > ʒ
	cons = ugsub(cons, "y", "j") -- must be after j > ʒ and fix_y
	cons = ugsub(cons, "[uü]", "w")
	
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
		if i < #syllables or (i == #syllables and ufind(current.coda, "s$")) then
			current.coda = ugsub(current.coda, "m[pb]", "m")
			current.coda = ugsub(current.coda, "([ln])[td]", "%1")
			current.coda = ugsub(current.coda, "n[kɡ]", "ŋ")
		end
		
		-- Consonant assimilations
		if i > 1 then
			-- t + lateral/nasal assimilation
			local cons = umatch(current.onset, "^([lʎmn])")
			if cons then
				previous.coda = ugsub(previous.coda, "t$", cons)
			end
			
			-- n + labial > labialized assimilation
			if ufind(current.onset, "^[mbp]") then
				previous.coda = ugsub(previous.coda, "n$", "m")
			elseif ufind(current.onset, "^[fv]") then
				previous.coda = ugsub(previous.coda, "n$", "m") -- strictly ɱ
			
			-- l/n + palatal > palatalized assimilation
			elseif ufind(current.onset, "^[ʒʎʃɲ]")
			or ufind(current.onset, "^t͡ʃ")
			or ufind(current.onset, "^d͡ʒ")
			then
				previous.coda = ugsub(previous.coda, "[ln]$", {["l"] = "ʎ", ["n"] = "ɲ"})
			end
			
			-- ɡʒ > d͡ʒ
			if previous.coda == "ɡ" and current.onset == "ʒ" then
				previous.coda = ""
				current.onset = "d͡ʒ"
			end
		end
		
		current.coda = ugsub(current.coda, "n[kɡ]", "ŋk")
		current.coda = ugsub(current.coda, "n([ʃʒ])", "ɲ%1")
		current.coda = ugsub(current.coda, "n(t͡ʃ)", "ɲ%1")
		current.coda = ugsub(current.coda, "n(d͡ʒ)", "ɲ%1")
		
		current.coda = ugsub(current.coda, "l([ʃʒ])", "ʎ%1")
		current.coda = ugsub(current.coda, "l(t͡ʃ)", "ʎ%1")
		current.coda = ugsub(current.coda, "l(d͡ʒ)", "ʎ%1")
		
		current.coda = ugsub(current.coda, "ɲs", "ɲʃ")
		
		-- Voicing or devoicing
		if i > 1 then
			local coda_letter = usub(previous.coda, -1)
			local onset_letter = usub(current.onset, 1, 1)
			if voiced[onset_letter] and voicing[coda_letter] then
				previous.coda = ugsub(previous.coda, coda_letter .. "$", voicing[coda_letter])
			elseif voiceless[onset_letter] and devoicing[coda_letter] then
				previous.coda = ugsub(previous.coda, coda_letter .. "$", devoicing[coda_letter])
			else
				previous.coda = ugsub(previous.coda, "[bd]s", {["bs"] = "ps", ["ds"] = "ts"})
			end
		end
		
		-- Allophones of r
		if i == 1 then
			current.onset = ugsub(current.onset, "^ɾ", "r")
		end
		
		-- no spirants after r/z
		if i > 1 and mw.ustring.find(previous.coda, "[rz]$") then
			current.onset = mw.ustring.gsub(current.onset, "^[βðɣ]", {["β"] = "b", ["ð"] = "d", ["ɣ"] = "ɡ"})
		end
		
		if i > 1 then
			if ufind(previous.coda, "[lns]$") then
				current.onset = ugsub(current.onset, "^ɾ", "r")
			end
		end
		
		-- Double sound of letter x > ks/gz (on cultisms, ambiguous in onsets)
		current.coda = ugsub(current.coda, "^ʃs?", "ks")
		if i > 1 and previous.coda == "kz" then
			previous.coda = "ɡz" -- voicing the group
		end
		if i > 1 and current.onset == "s" then
			previous.coda = ugsub(previous.coda, "s$", "") -- reduction exs, exc(e/i) and sc(e/i)
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
	
	final = ugsub(final, "d͡ʒ", "t͡ʃ")
	final = ugsub(final, "d͡z", "t͡s")
	final = ugsub(final, "b", "p")
	final = ugsub(final, "d", "t")
	final = ugsub(final, "ɡ", "k")
	final = ugsub(final, "ʒ", "ʃ")
	final = ugsub(final, "v", "f")
	final = ugsub(final, "z", "s")
	
	-- Final loses
	final = ugsub(final, "j(t͡ʃ)", "%1")
	final = ugsub(final, "([ʃs])s", "%1") -- homophone plurals -xs, -igs, -çs
	
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
		elseif ufind(post_letters, "^ct[ae]?s?$") then
			return "è"
		elseif post_letters == "dre" or post_letters == "dres" then
			return "é"
		elseif ufind(post_consonants, "^l") and syllables.stress == #syllables then
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
		elseif ufind(post_letters, "^r[ae]?s?$") then
			return "é"
		elseif ufind(post_consonants, "^r[dfjlnrstxyz]") then -- except bilabial and velar
			return "è"
		elseif post_letters == "sos" or post_letters == "sa" or post_letters == "ses" then -- inflection of -ès
			return "ê"
		elseif ufind(post_letters, "^t[ae]?s?$") then
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
	elseif ufind(post_letters, "^u[^s]") then -- diphthong ou, ambiguous if final
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
	elseif ufind(post_letters, "^r[ae]?s?$") then
		return "ó"
	elseif ufind(post_letters, "^r[ft]s?$") then
		return "ò"
	elseif post_letters == "rme" or post_letters == "rmes" then
		return "ó"
	end
	
	return nil
end

local function to_IPA(syllables, mid_vowel_hint)
	-- Stressed vowel is ambiguous
	if ufind(syllables[syllables.stress].vowel, "[eéèoòó]") then
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
		
		if ufind(syll.vowel, "^[eèéêëií]$") then
			syll.onset = ugsub(syll.onset, "tg$", "d͡ʒ")
			syll.onset = ugsub(syll.onset, "[cg]$", {["c"] = "s", ["g"] = "ʒ"})
			syll.onset = ugsub(syll.onset, "[qg]u$", {["qu"] = "k", ["gu"] = "ɡ"})
		end
		
		syll.coda = ugsub(syll.coda, "igs?$", "id͡ʒ")
		
		syll.onset = replace_context_free(syll.onset)
		syll.coda = replace_context_free(syll.coda)
		
		syll.vowel = ugsub(syll.vowel, ".", IPA_vowels)
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
			current.vowel = ugsub(current.vowel, "[ae]", "ə")
		end
	end
	return syllables
end

local accents = {}

accents["Central Catalan"] = function(syllables)
	syllables = mw.clone(syllables)
	
	-- Reduction of unstressed vowels a,e
	syllables = reduction_ae(syllables)
	
	-- Final consonant losses
	local final = syllables[#syllables].coda
	
	final = ugsub(final, "^ɾ(s?)$", "%1") -- no loss with hint -rr
	final = ugsub(final, "m[pb]$", "m")
	final = ugsub(final, "([ln])[td]$", "%1")
	final = ugsub(final, "[nŋ][kɡ]$", "ŋ")
	
	syllables[#syllables].coda = final
	
	for i = 1, #syllables do
		local current = syllables[i]
		local previous = syllables[i-1]
		
		-- Reduction of unstressed o
		if current.vowel == "o" and not (current.stressed or current.coda == "w") then
			current.vowel = ugsub(current.vowel, "o", "u")
		end
		
		-- v > b
		current.onset = ugsub(current.onset, "v", "b")
		current.coda = ugsub(current.coda, "nb", "mb")
		if i > 1 and ufind(current.onset, "^b") then
			previous.coda = ugsub(previous.coda, "n$", "m")
		end
		
		-- allophones of r
		current.coda = ugsub(current.coda, "ɾ", "r")
		
		-- Remove j before palatal obstruents
		current.coda = ugsub(current.coda, "j([ʃʒ])", "%1")
		current.coda = ugsub(current.coda, "j(t͡ʃ)", "%1")
		current.coda = ugsub(current.coda, "j(d͡ʒ)", "%1")
		
		if i > 1 then
			if ufind(current.onset, "^[ʃʒ]") or ufind(current.onset, "^t͡ʃ") or ufind(current.onset, "^d͡ʒ") then
				previous.coda = ugsub(previous.coda, "j$", "")
			end
		end
	end
	
	return syllables
end

accents["Balearic"] = function(syllables, mid_vowel_hint)
	syllables = mw.clone(syllables)
	
	-- Reduction of unstressed vowels a,e
	syllables = reduction_ae(syllables)
	
	for i = 1, #syllables do
		local current = syllables[i]
		local previous = syllables[i-1]
		
		-- Reduction of unstressed o per vowel harmony
		if i > 1 and current.stressed and ufind(current.vowel, "[iu]") and not previous.stressed then
			previous.vowel = ugsub(previous.vowel, "o", "u")
		end
		
		-- Stressed schwa
		if i == syllables.stress and mid_vowel_hint == "ê" then -- not ë
			current.vowel = ugsub(current.vowel, "ɛ", "ə")
		end
		
		-- Remove j before palatal obstruents
		current.coda = ugsub(current.coda, "j([ʃʒ])", "%1")
		current.coda = ugsub(current.coda, "j(t͡ʃ)", "%1")
		current.coda = ugsub(current.coda, "j(d͡ʒ)", "%1")
		
		if i > 1 then
			if ufind(current.onset, "^[ʃʒ]") or ufind(current.onset, "^t͡ʃ") or ufind(current.onset, "^d͡ʒ") then
				previous.coda = ugsub(previous.coda, "j$", "")
			end
		end
		
		-- No palatal gemination ʎʎ > ll or ʎ, in Valencian and Balearic
		if i > 1 and current.onset == "ʎ" and previous.coda == "ʎ" then
			local prev_syll = previous.onset .. previous.vowel .. previous.coda
			if ufind(prev_syll, "[bpw]aʎ$")
				or ufind(prev_syll, "[mv]eʎ$")
				or ufind(prev_syll, "tiʎ$")
				or ufind(prev_syll, "m[oɔ]ʎ$")
				or (ufind(prev_syll, "uʎ$") and current.vowel == "a")
				then
				previous.coda = "l"
				current.onset = "l"
			else
				previous.coda = ""
			end
		end
		
		-- Final consonant losses
		if #syllables == 1 then
			current.coda = ugsub(current.coda, "ɾ(s?)$", "%1") -- no loss with hint -rr in monosyllables
		elseif i == #syllables then
			current.coda = ugsub(current.coda, "[rɾ](s?)$", "%1") -- including hint -rr
		end
	end
	
	return syllables
end

accents["Valencian"] = function(syllables, mid_vowel_hint)
	syllables = mw.clone(syllables)
	
	for i = 1, #syllables do
		local current = syllables[i]
		local previous = syllables[i-1]
		
		-- Variable mid vowel
		if i == syllables.stress and (mid_vowel_hint == "ê" or mid_vowel_hint == "ë" or mid_vowel_hint == "ô") then
			current.vowel = ugsub(current.vowel, "[ɛëɔ]", {["ɛ"] = "e", ["ë"] = "e", ["ɔ"] = "o"})
		end
		
		-- Fortition of palatal fricatives
		current.onset = ugsub(current.onset, "ʒ", "d͡ʒ")
		current.onset = ugsub(current.onset, "d͡d", "d")
		
		current.coda = ugsub(current.coda, "ʒ", "d͡ʒ")
		current.coda = ugsub(current.coda, "d͡d", "d")
		
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
			if ufind(prev_syll, "[bpw]aʎ$")
				or ufind(prev_syll, "[mv]eʎ$")
				or ufind(prev_syll, "tiʎ$")
				or ufind(prev_syll, "m[oɔ]ʎ$")
				or (ufind(prev_syll, "uʎ$") and current.vowel == "a")
				then
				previous.coda = "l"
				current.onset = "l"
			else
				previous.coda = ""
			end
		end
		
		-- Hint -rr only for Central
		if i == #syllables then
			current.coda = ugsub(current.coda, "r(s?)$", "ɾ%1")
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
	
	return "/" .. ugsub(table.concat(syllables, "."), ".([ˈˌ])", "%1") .. "/"
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
			table.insert(out, m_a.show(accents) .. " " .. m_ipa.format_IPA_full(lang, {{pron = ipa}}))
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
	

-- Given raw respelling, canonicalize it. This currently applies substitutions of the form e.g. [ny] or [th:t,nýz].
local function canonicalize(text, pagename)
	if text == "+" then
		text = pagename
	elseif rfind(text, "^%[.*%]$") then
		local subs = rsplit(rmatch(text, "^%[(.*)%]$"), ",")
		text = pagename
		local function err(msg)
			error(msg .. ": " .. text)
		end
		for _, sub in ipairs(subs) do
			local from, escaped_from, to, escaped_to, whole_word
			if rfind(sub, "^~") then
				-- whole-word match
				sub = rmatch(sub, "^~(.*)$")
				whole_word = true
			end
			if sub:find(":") then
				from, to = rmatch(sub, "^(.-):(.*)$")
			else
				to = sub
				from = convert_respelling_to_original(to, pagename, whole_word)
			end
			local patut = require(patut_module)
			escaped_from = patut.pattern_escape(from)
			if whole_word then
				escaped_from = "%f[%a]" .. escaped_from .. "%f[%A]"
			end
			escaped_to = patut.replacement_escape(to)
			local subbed_text, nsubs = rsubn(text, escaped_from, escaped_to)
			if nsubs == 0 then
				err(("Substitution spec %s -> %s didn't match processed pagename"):format(from, to))
			elseif nsubs > 1 then
				err(("Substitution spec %s -> %s matched multiple substrings in processed pagename, add more context"):format(from, to))
			else
				text = subbed_text
			end
		end
	end

	return text
end

local function parse_respelling(respelling, pagename, parse_err)
	local raw_phonemic, raw_phonetic = respelling:match("^/(.*)/ %[(.*)%]$")
	if not raw_phonemic then
		raw_phonemic = respelling:match("^/(.*)/$")
	end
	if not raw_phonemic then
		raw_phonetic = respelling:match("^%[(.*)%]$")
	end
	if raw_phonemic or raw_phonetic then
		return {
			raw = true,
			raw_phonemic = raw_phonemic,
			raw_phonetic = raw_phonetic,
		}
	end

	if respelling == "+" then
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
			else
				to = sub
				from = convert_respelling_to_original(to, pagename, whole_word)
			end
			if not patut then
				patut = require(patut_module)
			end
			escaped_from = patut.pattern_escape(from)
			if whole_word then
				escaped_from = "%f[%a]" .. escaped_from .. "%f[%A]"
			end
			escaped_to = patut.replacement_escape(to)
			local subbed_respelling, nsubs = rsubn(respelling, escaped_from, escaped_to)
			if nsubs == 0 then
				err(("Substitution spec %s -> %s didn't match processed pagename"):format(from, to))
			elseif nsubs > 1 then
				err(("Substitution spec %s -> %s matched multiple substrings in processed pagename, add more context"):format(from, to))
			else
				respelling = subbed_respelling
			end
		end
	end

	end
	return {term = respelling}
end


local dialects = {"bal", "cen", "val"}

function export.show(frame)
	local params = {
		[1] = {},
		indent = {},
		pagename = {} -- for testing or documentation pages
	}

	for _, dialect in ipairs(dialects) do
		params[dialect] = {}
	end

	local args = require("Module:parameters").process(frame:getParent().args, params)
	local pagename = args.pagename or mw.title.getCurrentTitle().subpageText

	-- Set inputs
	local inputs = {}
	-- If 1= specified, do all dialects.
	if args[1] then
		for _, dialect in ipairs(dialects) do
			inputs[dialect] = {input = args[1], param = 1}
		end
	end
	-- Then do individual dialect settings.
	for _, dialect in ipairs(dialects) do
		if args[dialect] then
			inputs[dialect] = {input = args[dialect], param = dialect}
		end
	end
	-- If no inputs given, set all dialects based on current pagename.
	if not next(inputs) then
		for _, dialect in ipairs(dialects) do
			inputs[dialect] = {input = "+", param = "(pagename)"}
		end
	end

	-- Parse the arguments.
	local put
	for dialect, inputspec in pairs(inputs) do
		local function generate_obj(text, parse_err_or_paramname)
			local obj = {}
			if text:find(":[^ ]") or text:find("%[%[") then
				obj.text, obj.lang, obj.link = require(parse_utilities_module).parse_term_with_lang(text,
					parse_err_or_paramname)
			else
				obj.text = text
				obj.link = text
			end
			return obj
		end

		if inputspec.input:find("[<%[]") then
			if not put then
				put = require("Module:parse utilities")
			end
			-- Parse balanced segment runs involving either [...] (substitution notation) or <...> (inline modifiers).
			-- We do this because we don't want commas inside of square or angle brackets to count as respelling
			-- delimiters. However, we need to rejoin square-bracketed segments with nearby ones after splitting
			-- alternating runs on comma. For example, if we are given
			-- "a[x]a<q:learned>,[vol:vôl;ei:éi,ei]<q:nonstandard>", after calling
			-- parse_multi_delimiter_balanced_segment_run() we get the following output:
			--
			-- {"a", "[x]", "a", "<q:learned>", ",", "[vol:vôl;ei:éi,ei]", "", "<q:nonstandard>", ""}
			--
			-- After calling split_alternating_runs(), we get the following:
			--
			-- {{"a", "[x]", "a", "<q:learned>", ""}, {"", "[vol:vôl;ei:éi,ei]", "", "<q:nonstandard>", ""}}
			--
			-- We need to rejoin stuff on either side of the square-bracketed portions.
			local segments = put.parse_multi_delimiter_balanced_segment_run(inputspec.input, {{"<", ">"}, {"[", "]"}})

			-- Not with spaces around the comma; see above for why we don't want to split off comma followed by space.
			local comma_separated_groups = put.split_alternating_runs_on_comma(segments)

			-- Process each value.
			local respellings = {}
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

				local obj
				if #group > 1 then
					-- Check for inline modifier.
					obj = put.parse_inline_modifiers_from_segments {
						group = group,
						arg = oneval,
						props = {
							paramname = inputspec.param,
							param_mods = param_mods,
							generate_obj = generate_obj,
						}
					}
				else
					obj = generate_obj(group[1], inputspec.param)
				end
				table.insert(respellings, obj)
			end

			local parsed = {terms = {}}
			for i, group in ipairs(comma_separated_groups) do
				-- Rejoin bracketed segments with nearby ones, as described above.
				local j = 2
				while j <= #group do
					if group[j]:find("^%[") then
						group[j - 1] = group[j - 1] .. group[j] .. group[j + 1]
						table.remove(group, j)
						table.remove(group, j)
					else
						j = j + 2
					end
				end
				local parsed = put.parse_inline_modifiers_from_segments {
				for j, segment in ipairs(group) do
					group[j] = rsub(segment, TEMP1, ", ")
				end

				local term = {term = group[1], ref = {}, q = {}}
				for j = 2, #group - 1, 2 do
					if group[j + 1] ~= "" then
						parse_err("Extraneous text '" .. group[j + 1] .. "' after modifier")
					end
					local modtext = group[j]:match("^<(.*)>$")
					if not modtext then
						parse_err("Internal error: Modifier '" .. group[j] .. "' isn't surrounded by angle brackets")
					end
					local prefix, arg = modtext:match("^([a-z]+):(.*)$")
					if not prefix then
						parse_err("Modifier " .. group[j] .. " lacks a prefix, should begin with one of " ..
							"'pre:', 'post:', 'ref:', 'bullets:' or 'q:'")
					end
					if prefix == "ref" or prefix == "q" then
						table.insert(term[prefix], arg)
					elseif prefix == "pre" or prefix == "post" or prefix == "bullets" then
						if i < #comma_separated_groups then
							parse_err("Modifier '" .. prefix .. "' should occur after the last comma-separated term")
						end
						if parsed[prefix] then
							parse_err("Modifier '" .. prefix .. "' occurs twice, second occurrence " .. group[j])
						end
						if prefix == "bullets" then
							if not arg:find("^[0-9]+$") then
								parse_err("Modifier 'bullets' should have a number as argument")
							end
							parsed.bullets = tonumber(arg)
						else
							parsed[prefix] = arg
						end
					else
						parse_err("Unrecognized prefix '" .. prefix .. "' in modifier " .. group[j]
							.. ", should be one of 'pre', 'post', 'ref', 'bullets' or 'q'")
					end
				end
				table.insert(parsed.terms, term)
			end
			if not parsed.bullets then
				parsed.bullets = 1
			end
			inputs[dialect] = parsed
		else
			local terms = {}
			-- We don't want to split on comma+space, which should become a foot boundary as in
			-- [[rei morto, rei posto]].
			local subbed_input = rsub(input, ", ", TEMP1)
			for _, term in ipairs(rsplit(subbed_input, ",")) do
				term = rsub(term, TEMP1, ", ")
				table.insert(terms, {term = term, ref = {}, q = {}})
			end
			inputs[dialect] = {
				terms = terms,
				bullets = 1,
			}
		end
	end

	local word = ulower(args[1])
	local mid_vowel_hint = nil
	
	if word == "é" or word == "è" or word == "ê" or word == "ë" or word == "ó" or word == "ò" or word == "ô" then
		mid_vowel_hint = word
		word = ulower(mw.title.getCurrentTitle().text)
	end
	
	word = word_fixes(word)
	
	local syllables = split_syllables(word)
	
	if mid_vowel_hint == nil then
		if ufind(syllables[syllables.stress].vowel, "[éêëòóô]") then
			mid_vowel_hint = umatch(syllables[syllables.stress].vowel, "[éêëòóô]")
		elseif ufind(syllables[syllables.stress].vowel, "[eè]") then
			mid_vowel_hint = mid_vowel_e(syllables)
		elseif syllables[syllables.stress].vowel == "o" then
			mid_vowel_hint = mid_vowel_o(syllables)
		end
	end
	syllables = to_IPA(syllables, mid_vowel_hint)
	
	local indent = (args.indent or "*") .. " "
	
	local out = table.concat(group_sort_and_format(syllables, mid_vowel_hint), "\n" .. indent)
	
	if args.indent then
		out = indent .. out
	end
	
	return out
end

-- Used by [[Module:ca-IPA/testcases]].
function export.test(word, mid_vowel_hint)
	word = word_fixes(word)
	
	local syllables = split_syllables(word)
	
	if mid_vowel_hint == nil then
		if ufind(syllables[syllables.stress].vowel, "[éêëòóô]") then
			mid_vowel_hint = umatch(syllables[syllables.stress].vowel, "[éêëòóô]")
		elseif ufind(syllables[syllables.stress].vowel, "[eè]") then
			mid_vowel_hint = mid_vowel_e(syllables)
		elseif syllables[syllables.stress].vowel == "o" then
			mid_vowel_hint = mid_vowel_o(syllables)
		end
	end
	syllables = to_IPA(syllables, mid_vowel_hint)
	
	return table.concat(group_sort_and_format(syllables, mid_vowel_hint, true), ";<br>")
end

-- on debug console use: =p.debug("your_word", "your_hint")
function export.debug(word, mid_vowel_hint)
	word = word_fixes(ulower(word))
	
	local syllables = split_syllables(word)
	if mid_vowel_hint == nil then
		if ufind(syllables[syllables.stress].vowel, "[éêëòóô]") then
			mid_vowel_hint = umatch(syllables[syllables.stress].vowel, "[éêëòóô]")
		elseif ufind(syllables[syllables.stress].vowel, "[eè]") then
			mid_vowel_hint = mid_vowel_e(syllables)
		elseif syllables[syllables.stress].vowel == "o" then
			mid_vowel_hint = mid_vowel_o(syllables)
		end
	end
	syllables = to_IPA(syllables, mid_vowel_hint)
	
	local ret = {}
	
	for _, accent in ipairs(accent_order) do
		local syllables_accented = accents[accent](syllables, mid_vowel_hint)
		table.insert(ret, accent .. " " .. join_syllables(syllables_accented))
	end
	
	return table.concat(ret, "\n")
end

return export
