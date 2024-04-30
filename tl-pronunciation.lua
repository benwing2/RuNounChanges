-- Based on [[Module:es-pronunc]] by Benwing2. 
-- Adaptation by TagaSanPedroAko, Improved by Ysrael214.

local export = {}

local m_IPA = require("Module:IPA")
local m_str_utils = require("Module:string utilities")
local m_table = require("Module:table")
local put_module = "Module:parse utilities"
local headword_data_module = "Module:headword/data"
local accent_qualifier_data_module = "Module:accent qualifier/data"

local lang = require("Module:languages").getByCode("tl")

local maxn = table.maxn
local rfind = m_str_utils.find
local rsubn = m_str_utils.gsub
local rsplit = m_str_utils.split
local toNFC = mw.ustring.toNFC
local toNFD = mw.ustring.toNFD
local trim = mw.text.trim
local u = m_str_utils.char
local ulower = m_str_utils.lower

local AC = u(0x0301) -- acute =  ́
local GR = u(0x0300) -- grave =  ̀
local CFLEX = u(0x0302) -- circumflex =  ̂
local TILDE = u(0x0303) -- tilde =  ̃
local DIA = u(0x0308) -- diaeresis =  ̈
local MACRON = u(0x0304) -- macron 

local vowel = "aeëəiou" -- vowel
local V = "[" .. vowel .. "]"
local accent = AC .. GR .. CFLEX .. MACRON
local accent_c = "[" .. accent .. "]"
local ipa_stress = "ˈˌ"
local ipa_stress_c = "[" .. ipa_stress .. "]"
local separator = accent .. ipa_stress .. "# ."
local C = "[^" .. vowel .. separator .. "]" -- consonant

local unstressed_words = m_table.listToSet({
	"ang", "sa", "nang", "si", "ni", "kay", -- case markers. "Nang" here is for written "ng", but can also work with nang as in the contraction na'ng and the conjunction "nang"
	"a", "ar", "ay", "ba", "bi", "da", "di", "e", "ef", "eks", "dyi", "i",  "jey", "key", "em", "ma", "en", "pi", "ra", "es", "ta", "ti", "u", "vi", "wa", "way", "ya", "yu", "zey", "zi", -- letter names (abakada and modern Filipino)
	"ko", "mo", "ka", --single-syllable personal pronouns
	"na",-- linker, also temporal particle
    "daw", "ga", "ha", "pa", -- particles
	"di7", "de7", -- negation words
	"may", -- single-syllable existential
	"pag", "kung", -- subordinating conjunctions
	"at", "o", -- coordinating conjunctions
	"hay", -- interjections
	"de", "del", "el", "la", "las", "los", "y", -- in some Spanish-derived terms and names
	"-an", "-en", "-han", "hi-", "-hin", "hin-", "hing-", "-in", "mag-", "mang-", "pa-", "pag-", "pang-", -- affixes
	"-ay", "-i", "-nin", "-ng", "-oy", "-s"
})

local special_words = {
	["ng"] = "nang", ["ng̃"] = "nang", ["ñ̃g"] = "nang",
	["mga"] = "manga" .. AC, ["mg̃a"] = "manga" .. AC
}

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

-- Combine two sets of qualifiers, either of which may be nil or a list of qualifiers. Remove duplicate qualifiers.
-- Return value is nil or a list of qualifiers.
local function combine_qualifiers(qual1, qual2)
	if not qual1 then
		return qual2
	end
	if not qual2 then
		return qual1
	end
	local qualifiers = m_table.deepcopy(qual1)
	for _, qual in ipairs(qual2) do
		m_table.insertIfNot(qualifiers, qual)
	end
	return qualifiers
end


local function decompose(text)
	-- decompose everything but ñ and ü
	text = toNFD(text)
	text = rsub(text, ".[" .. TILDE .. DIA .. "]", {
		["n" .. TILDE] = "ñ",
		["N" .. TILDE] = "Ñ",
		["u" .. DIA] = "ü",
		["U" .. DIA] = "Ü",
		["e" .. DIA] = "ë",
		["E" .. DIA] = "Ë",
	})
	return text
end

local function remove_accents(str)
	str = decompose(str)
	str = rsub(str, "(.)" .. accent_c, "%1")
	return str
end

local function split_on_comma(term)
	if term:find(",%s") then
		return require(put_module).split_on_comma(term)
	else
		return rsplit(term, ",")
	end
end

-- ĵ, ɟ and ĉ are used internally to represent [d͡ʒ], [j] and [t͡ʃ]
--

function export.IPA(text)
	local debug = {}

	text = ulower(text)
	text = decompose(text)
	-- convert commas and en/en dashes to IPA foot boundaries
	text = rsub(text, "%s*[,–—]%s*", " | ")
	-- question mark or exclamation point in the middle of a sentence -> IPA foot boundary
	text = rsub(text, "([^%s])%s*[!?]%s*([^%s])", "%1 | %2")

	-- canonicalize multiple spaces and remove leading and trailing spaces
	local function canon_spaces(text)
		text = rsub(text, "%s+", " ")
		text = rsub(text, "^ ", "")
		text = rsub(text, " $", "")
		return text
	end

	text = canon_spaces(text)

	-- Make prefixes unstressed unless they have an explicit stress marker; also make certain
	-- monosyllabic words (e.g. [[ang]], [[ng]], [[si]], [[na]], etc.) without stress marks be
	-- unstressed.
	local words = rsplit(text, " ")
	for i=1, #words do
		words[i] = special_words[words[i]] or words[i]
		if rfind(words[i], "%-$") and not rfind(words[i], accent_c) or unstressed_words[words[i]] then
			-- add macron to the last vowel not the first one
			-- adding the macron after the 'u'
			words[i] = rsub(words[i], "^(.*" .. V .. ")", "%1" .. MACRON)
		end
		words[i] = rsub(words[i], "^%-(" .. V .. ")", "◌%1") -- suffix/infix if vowel, remove glottal stop at start
		words[i] = rsub(words[i], "^%-([7ʔ])(" .. V .. ")", "-%1%2" .. MACRON)	-- affix that requires glottal stop
		words[i] = rsub(words[i], "^(de%-)", "de" .. MACRON .. '-')	-- de-<word> fix
		words[i] = rsub(words[i], "%-(na)%-", '-' .. "na" .. MACRON .. '-')	-- -na-<word> fix
		words[i] = rsub(words[i], "%-(mga)%-", '-' .. special_words["mga"] .. '-')	-- -mga-<word> fix
		words[i] = rsub(words[i], "%-(mga)%-", '-' .. special_words["mga"] .. '-')	-- -mga-<word> fix
		words[i] = rsub(words[i], "^y$", "i" .. MACRON)	-- Spanish y fix
	end
	text = table.concat(words, " ")
	-- Convert hyphens to spaces
	text = rsub(text, "%-", " ")
	-- canonicalize multiple spaces again, which may have been introduced by hyphens
	text = canon_spaces(text)
	-- now eliminate punctuation
	text = rsub(text, "[!?']", "")
	-- put # at word beginning and end and double ## at text/foot boundary beginning/end
	text = rsub(text, " | ", "# | #")
	text = "##" .. rsub(text, " ", "# #") .. "##"
	text = rsub_repeatedly(text, "([.]?)#([.]?)", "#")

	table.insert(debug, text)

	-- handle certain combinations; ch ng and sh handling needs to go first
	text = rsub(text, "([t]?)ch", "ts") --not the real sound
	text = rsub(text, "([n]?)g̃", "ng") -- Spanish spelling support
	text = rsub(text, "ng", "ŋ")
	text = rsub(text, "sh", "ʃ")

	--x
	text = rsub(text, "([#])x(" .. V .. ")", "%1s%2")
	text = rsub(text, "x", "ks")

	--ll
	text = rsub(text, "ll([i]?)(".. V.. ")", "ly%2")

	--c, gü/gu+e or i, q
	text = rsub(text, "c([iey])", "s%1")
	text = rsub(text, "(" .. V .. ")gü([ie])", "%1ɡw%2")
	text = rsub(text, "gü([ie])", "ɡuw%1")
	text = rsub(text, "gui([aeëo])", "ɡy%1")
	text = rsub(text, "gu([ie])", "ɡ%1")
	text = rsub(text, "qu([ie])", "k%1")
	text = rsub(text, "ü", "u") 
	text = rsub(text, "ë", "ə") 

	--alphabet-to-phoneme
	text = rsub(text, "[cfgjñqrvz7]",
	--["g"]="ɡ":  U+0067 LATIN SMALL LETTER G → U+0261 LATIN SMALL LETTER SCRIPT G
		{ ["c"] = "k", ["g"] = "ɡ", ["j"] = "ĵ", ["ñ"] = "ny", ["q"] = "k", ["r"] = "ɾ", ["7"] = "ʔ"})

	-- trill in rr
	text = rsub(text, "[ɾ]+", "ɾ")
	text = rsub(text, "ɾ[.]ɾ", "r")

    -- ts
	text = rsub(text, "ts", "ĉ") --not the real sound

	table.insert(debug, text)

	text = rsub_repeatedly(text, "([^" .. vowel ..  "])([u])([" .. AC .. MACRON .. "]?)([aeio])("  .. accent_c .. "?)","%1%2%3.w%4%5")
	text = rsub_repeatedly(text, "(" .. V ..  ")([u])([" .. AC .. MACRON .. "]?)([aeio])("  .. accent_c .. "?)","%1.w%3%4%5")
	text = rsub_repeatedly(text, "(" .. V ..  ")([o])([" .. AC .. MACRON .. "]?)([aei])("  .. accent_c .. "?)","%1.w%3%4%5")
	text = rsub(text, "([i])([" .. AC .. MACRON .. "])([aeou])("  .. accent_c .. "?)","%1%2.y%3%4")
	text = rsub(text, "([i])([aeou])(" .. accent_c .. "?)","y%2%3")
	text = rsub(text, "a([".. AC .."]*)o([#.])","a%1w%2")

	--determining whether "y" is a consonant or a vowel
	text = rsub(text, "y(" .. accent_c .. ")", "i%1")
	text = rsub(text, "y(" .. V .. ")", "ɟ%1") -- not the real sound
	text = rsub(text,"y([ˈˌ.]*)([bćĉdfɡhjĵklmnɲŋpɾrsʃtvwɟzʔ#" .. vowel .. "])","i%1%2")
	text = rsub(text, "w(" .. V .. ")","w%1")
	text = rsub(text,"w([ˈˌ]?)([bćĉdfɡjĵklmnɲŋpɾrsʃtvwɟzʔ#])","u%1%2")

	table.insert(debug, text)

	--vowels with grave/circumflex to vowel+glottal stop
	text = rsub(text, CFLEX, AC .. GR)
	text = rsub(text, "(" .. V .. ")([" .. AC .. "]?)" .. GR .. "([#" .. vowel .. "])", "%1%2ʔ%3")
	text = rsub(text, "(" .. V .. ")([" .. AC .. "]?)" .. GR, "%1%2")

	-- Add glottal stop for words starting with vowel
	text = rsub(text, "([#])(" .. V .. ")", "%1ʔ%2")
	text = rsub(text, "◌", "")

	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*)(" .. C .. V .. ")", "%1.%2")

	-- "mb", "mp", "nd", "nk", "nt" combinations
	text = rsub_repeatedly(text, "(m)([bp])([^hlɾrɟw" .. vowel .. separator .."])", "%1%2.%3")
	text = rsub_repeatedly(text, "(n)([dkt])([^hlɾrɟw" .. vowel .. separator .. "])", "%1%2.%3")
	text = rsub_repeatedly(text, "(ŋ)([k])([^hlɾrɟw" .. vowel .. separator ..  "])", "%1%2.%3")
	text = rsub_repeatedly(text, "([ɾr])([bkdfɡklmnpsʃtvz])([^hlɾrɟyw" .. vowel .. separator ..  "])", "%1%2.%3")

	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. "+)(" .. C .. C .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. ")(" .. C .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. "+)(" .. C .. C .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. C .. ")%.s(" .. C .. ")", "%1s.%2")
	-- Any aeo, or stressed iu, should be syllabically divided from a following aeo or stressed iu.
	text = rsub_repeatedly(text, "([aeo]" .. accent_c .. "*)([aeo])", "%1.%2")
	text = rsub_repeatedly(text, "([aeo]" .. accent_c .. "*)(" .. V .. AC .. ")", "%1.%2")
	text = rsub(text, "([iuə]" .. AC .. ")([aeo])", "%1.%2")
	text = rsub_repeatedly(text, "([iuə]" .. AC .. ")(" .. V .. AC .. ")", "%1.%2")
	text = rsub_repeatedly(text, "i(" .. accent_c .. "*)i", "i%1.i")
	text = rsub_repeatedly(text, "u(" .. accent_c .. "*)u", "u%1.u")

	table.insert(debug, text)

	local accent_to_stress_mark = { [AC] = "ˈ", [MACRON] = "" }

	local function accent_word(word, syllables)
		-- Now stress the word. If any accent exists in the word (including macron indicating an unaccented word),
		-- put the stress mark(s) at the beginning of the indicated syllable(s). Otherwise, apply the default
		-- stress rule.
		if rfind(word, accent_c) then
			for i = 1, #syllables do
				syllables[i] = rsub(syllables[i], "^(.*)(" .. accent_c .. ")(.*)$",
					function(pre, accent, post)
						return accent_to_stress_mark[accent] .. pre .. post
					end
				)
			end
		else
			-- Default stress rule. Words without vowels (e.g. IPA foot boundaries) don't get stress.
			if #syllables > 1 and rfind(word, "[^aeiouəʔbcĉdfɡghjɟĵklmnñɲŋpqrɾsʃtvwxz#]#") or #syllables == 1 and rfind(word, V) then
				syllables[#syllables] = "ˈ" .. syllables[#syllables]
			elseif #syllables >= 2 then
				local vowel_find = false
				local stress_find = false
				for i=0, #syllables-1 do
					if rfind(syllables[#syllables - i], V) then
						if vowel_find then
							syllables[#syllables - i] = "ˈ" .. syllables[#syllables - i]
							stress_find = true
							break
						end
						vowel_find = true
					end
				end
				if vowel_find and not stress_find then
					syllables[#syllables - 1] = "ˈ" .. syllables[#syllables - 1]
				end
			end
		end
	end

	local words = rsplit(text, " ")
	for j, word in ipairs(words) do
		-- accentuation
		local syllables = rsplit(word, "%.")
		accent_word(word, syllables)
		-- Reconstruct the word.
		words[j] = table.concat(syllables, ".")
	end

	text = table.concat(words, " ")

	-- suppress syllable mark before IPA stress indicator
	text = rsub(text, "%.(" .. ipa_stress_c .. ")", "%1")
	--make all primary stresses but the last one be secondary
	text = rsub_repeatedly(text, "ˈ(.+)ˈ", "ˌ%1ˈ")

    table.insert(debug,text)
    
    --"ph" digraph be "f"
    text = rsub(text,"ph(" .. V .. ")","f%1")
   
    --correct final glottal stop placement
    text = rsub(text,"([ˈˌ])ʔ([#]*)([ʔbĉćdfɡhĵɟklmnŋɲpɾrsʃtvwz])(" .. V .. ")","%1%2%3%4ʔ")

    table.insert(debug,text)

    --add temporary macron for /a/, /i/ and /u/ in stressed syllables so they don't get replaced by unstressed form

	text = rsub(text,"([ˈˌ])([#]*)([ʔbćĉdfɡhĵɟklmnŋpɾrstvwz]?)([ɟlnɾst]?)([a])([ʔbdfɡiklmnŋpɾstu]?)([bdɡklmnpɾst]?)","%1%2%3%4ā%6%7")
	text = rsub(text,"([ˈˌ])([#]*)([ʔbćĉdfɡhĵɟklmnŋpɾrstvwz]?)([ɟlnɾst]?)([i])([ʔbdfɡklmnŋpɾstu]?)([bdɡklmnpɾst]?)","%1%2%3%4ī%6%7")
	text = rsub(text,"([ˈˌ])([#]*)([ʔbćĉdfɡhĵɟklmnŋpɾrstvwz]?)([ɟlnɾst]?)([u])([ʔbdfɡiklmnŋpɾst]?)([bdɡklmnpɾst]?)","%1%2%3%4ū%6%7")

    table.insert(debug, text)

      --Corrections for diphthongs
    text = rsub(text,"([aāeəouū])i","%1j") --ay
    text = rsub(text,"([aāeəiīo])u","%1w") --aw

    table.insert(debug, text)
    
    --remove "ɟ" and "w" inserted on vowel pair starting with "i" and "u"
    text = rsub(text,"([i])([ˈˌ]?)ɟ([aāeəouū])","%1%2%3")
    text = rsub(text,"([u])([ˈˌ]?)w([aāeəiī])","%1%2%3")
    
    table.insert(debug,text)
    
    --/z/ changes
    text = rsub(text,"([aāeəoiīuū])z([ˈˌ.#])([^bdfɡĵjɟŋɾrvz])","%1s%2%3") -- /z/ turn to /s/ before some unvoiced sounds
    text = rsub(text,"([^#bdfɡĵjɟnŋɾrvzaāeəoiīuū])([ˈˌ.#])z","%1%2s") -- /z/ turn to /s/ after some unvoiced sounds
    text = rsub(text,"([bćĉdfɡhĵjɟklmnŋptvwz])([ˈˌ.]?)([ɟlɾst])([aāeəoiīuū])([.]?)([z])","%1%2%3%4%5s") -- consonant cluster before /z/ turn to /s/
    text = rsub_repeatedly(text, "([^z]*)z([^z]*)([^#bdfɡĵjɟnŋɾrvzˈˌ.#][ˈˌ.#]?)z", "%1z%2%3s") -- /z/ turn to /s/ if /z/ already said earlier
    
    local tl_IPA_table = {
    	["phonetic"] = text,
    	["phonemic"] = text
    }

	for key, value in pairs(tl_IPA_table) do
		text = tl_IPA_table[key]

		--phonetic transcription
		if key == "phonetic" then
	       	table.insert(debug, text)

	        --Turn phonemic diphthongs to phonetic diphthongs
			text = rsub(text, "([aāeəouū])j", "%1ɪ̯")
			text = rsub(text, "([aāeəiīo])w", "%1ʊ̯")

	        table.insert(debug, text)

	        --change a, i, u to unstressed equivalents (certain forms to restore)
		    text = rsub(text,"a","ɐ")
		    text = rsub(text,"i","ɪ")
		    text = rsub(text,"u","ʊ")

	        table.insert(debug, text)
	        
	        text = rsub(text,"n([ˈˌ.])ɟ","%1ɲ") -- /n/ before /j/
	        text = rsub(text,"n[ɟj]([ɐāeəɪɪ̯īoʊʊ̯ū])", "ɲ%1") -- /n/ before /j/

	        --Combine consonants (except H) followed by I/U and certain stressed vowels
		    text = rsub(text,"([bćĉdfɡĵklmnɲŋpɾrstvz])([ɟlnɾst]?)ɪ([ˈˌ.])ɟ?([āɐeəoūʊ])","%3%1%2ɟ%4")
		    text = rsub(text,"([bćĉdfɡĵklmnɲŋpɾrstvz])([ɟlnɾst]?)ʊ([ˈˌ.])w?([āɐeəīɪo])","%3%1%2w%4")
		    text = rsub(text,"([h])ʊ([ˈˌ.])w?([āɐeəīɪ])","%2%1w%3") -- only for hu with (ei) combination
			text = rsub_repeatedly(text, "([.]+)", ".")

	       	table.insert(debug, text)
	       
	       	-- foreign s consonant clusters
		    text = rsub(text,"([ˈˌ.]?)([#]*)([.]?)([s])([ʔbćĉdfɡhĵklmnŋpɾrt])([ɟlnɾst]?)([ɐāeəɪɪ̯īoʊʊ̯ū])",
		    	function(stress, boundary, syllable, s, cons1, cons2, vowel)
		    		if stress == "" then stress = "." end
		    		return boundary .. "ʔɪ" .. s .. stress .. cons1 .. cons2 .. vowel
		    	end
		    )
		    
		    text = rsub(text,"([ˈˌ])([ʔbćĉdfɡhĵɟklmnŋpɾrstwvz]?)([ɟlnɾst]?)([ɐ])","%1%2%3ā")
			text = rsub(text,"([ˈˌ])([ʔbćĉdfɡhĵɟklmnŋpɾrstwvz]?)([ɟlnɾst]?)([ɪ])","%1%2%3ī")
			text = rsub(text,"([ˈˌ])([ʔbćĉdfɡhĵɟklmnŋpɾrstwvz]?)([ɟlnɾst]?)([ʊ])","%1%2%3ū")
		    
		    table.insert(debug, text)

	    	text = rsub(text,"([nŋ])([ˈˌ# .]*[bfpv])","m%2")
	    	text = rsub(text,"([ŋ])([ˈˌ# .]*[dlstz])","n%2")
		    text = rsub_repeatedly(text,"([ɐāeəɪɪ̯īoʊʊ̯ū])([#]?)([ ]?)([ˈˌ#.])([k])([ɐāeəɪīoʊū])","%1%2%3%4x%6") -- /k/ between vowels
		    text = rsub_repeatedly(text,"([ɐāeəɪɪ̯īoʊʊ̯ū])([#]?)([ ]?)([ˈˌ#.])([ɡ])([ɐāeəɪīoʊū])", "%1%2%3%4ɣ%6") -- /ɡ/ between vowels
	        text = rsub(text,"d([ˈˌ.])ɟ","%1ĵ") --/d/ before /j/
	        text = rsub(text,"d[ɟj]([ɐāeəɪɪ̯īoʊʊ̯ū])","ĵ%1") --/d/ before /j/
	        text = rsub(text,"s[ɟj]([ɐāeəɪɪ̯īoʊʊ̯ū])","ʃ%1") --/s/ before /j/
	        text = rsub(text,"([n])([ˈ ˌ# .]*[ɡk])","ŋ%2") -- /n/ before /k/ and /g/ (some proper nouns and loanwords)
	        --text = rsub(text,"n([ˈˌ.])ɟ","%1ɲ") -- /n/ before /j/
	        text = rsub(text,"s([ˈˌ.])ɟ","%1ʃ") -- /s/ before /j/
	        text = rsub(text,"z([ˈˌ.])ɟ","%1ʒ") -- /z/ before /j/
	        text = rsub(text,"t([ˈˌ.])ɟ","%1ĉ") -- /t/ before /j/
	        text = rsub(text,"t([ˈˌ.])s([ɐāeəɪīoʊū])","%1ć%2") -- /t/ before /s/
	        text = rsub(text,"t([.])s","ts") -- /t/ before /s/
	        text = rsub(text,"([ˈˌ.])d([ɟj])([ɐāeəɪīoʊū])","%1ĵ%3") -- /dj/ before any vowel following stress
	        text = rsub(text,"([ˈˌ.])n([ɟj])([ɐāeəɪīoʊū])","%1ɲ%3") -- /nj/ before any vowel following stress
	        text = rsub(text,"([ˈˌ.])s([ɟj])([ɐāeəɪīoʊū])","%1ʃ%3") -- /sj/ before any vowel following stress
	        text = rsub(text,"([ˈˌ.])t([ɟj])([ɐāeəɪīoʊū])","%1ĉ%3") -- /tj/ before any vowel following stress
	        -- text = rsub(text,"([oʊ])([m])([.]?)([ˈ]?)([pb])","u%2%3%4%5") -- /o/ and /ʊ/ before /mb/ or /mp/
	        text = rsub(text,"([ɐāeəɪīoʊū])(ɾ)([bćĉdfɡĵklmnŋpstvz])([s]?)([#.])","%1ɹ%3%4%5") -- /ɾ/ becoming /ɹ/ before consonants not part of another syllable
	        
	        -- fake "t.s" to real "t.s"
		    text = rsub(text, "[ć]", "t͡s")

	        --final fix for phonetic diphthongs
		    text = rsub(text,"([ɐ])ɪ̯","aɪ̯") --ay
		    text = rsub(text,"([ɐ])ʊ̯","aʊ̯") --aw
		    text = rsub(text,"([ɪ])ʊ̯","iʊ̯") --iw

	       	table.insert(debug, text)

		    --Change /e/ closer to native pronunciation.
		    text = rsub(text, "e", "ɛ")
		else
			text = rsub(text,"%.","")
			text = rsub(text,"‿", " ")
		end

		table.insert(debug, text)

	    --delete temporary macron in /a/, /i/ and /u/
	    text = rsub(text,"ā","a")
	    text = rsub(text,"ī","i")
	    text = rsub(text,"ū","u")

		-- Final fix for "iy" and "uw" combination
		text = rsub(text,"([iɪ])([ˈˌ.]*)ɟ([aɐeɛəouʊ])","%1%2%3")
		text = rsub(text,"([uʊ])([ˈˌ.]*)w([aɐeɛəiɪo])","%1%2%3")
		text = rsub(text,"([ɪ])([ˈˌ.]*)ɟ([i])","%1%2%3")
		text = rsub(text,"([i])([.]*)ɟ([ɪ])","%1%2%3")
		text = rsub(text,"([ʊ])([ˈˌ.]*)w([u])","%1%2%3")
		text = rsub(text,"([u])([.]*)w([ʊ])","%1%2%3")

		--remove "ɟ" and "w" inserted on vowel pair starting with "e" and "o"
	    text = rsub(text,"([ɛe])([ˈˌ.]*)[ɟj]([aɐo])","%1%2%3")
	    text = rsub(text,"([o])([ˈˌ.]*)w([aɐeɛə])","%1%2%3")

		-- convert fake symbols to real ones
	    local final_conversions = {
			["ĉ"] = "t͡ʃ", -- fake "ch" to real "ch"
			["ɟ"] =  "j", -- fake "y" to real "y"
	        ["ĵ"] = "d͡ʒ" -- fake "j" to real "j"
		}

		text = rsub(text, "[ĉɟĵ]", final_conversions)

		-- Do not have multiple syllable break consecutively
		text = rsub_repeatedly(text, "([.]+)", ".")
    	text = rsub_repeatedly(text, "([.]?)(‿)([.]?)", "%2")
    
    	-- remove # symbols at word and text boundaries
		text = rsub_repeatedly(text, "([.]?)#([.]?)", "")

		-- resuppress syllable mark before IPA stress indicator
		text = rsub(text, "%.(" .. ipa_stress_c .. ")", "%1")
		text = rsub_repeatedly(text, "([.]?)(" .. ipa_stress_c .. ")([.]?)", "%2")
    
    	tl_IPA_table[key] = toNFC(text)
	end

	return tl_IPA_table
end

function export.show(frame)
	local params = {
		[1] = {},
		["pre"] = {},
		["bullets"] = {type = "number", default = 1},
	}

	local parargs = frame:getParent().args
	local args = require("Module:parameters").process(parargs, params)

	local results = {}

	local text = args[1] or mw.title.getCurrentTitle().text

	local IPA_result = export.IPA(text)
	table.insert(results, { pron = "/" .. IPA_result["phonemic"] .. "/" })
	table.insert(results, { pron = "[" .. IPA_result["phonetic"] .. "]" })

	local pre = args.pre and args.pre .. " " or ""
	local bullet = (args.bullets ~= 0) and "* " or ""

	return bullet .. pre .. m_IPA.format_IPA_full(lang, results)
end


local function parse_gloss(arg)
	local pos, gloss
	if arg:find("%^") then
		pos, gloss = arg:match("^(.-)%^(.*)$")
	else
		gloss = arg
	end
	if pos then
		pos = mw.loadData(headword_data_module).pos_aliases[pos] or pos
	end
	return {
		pos = pos,
		gloss = gloss,
	}
end


-- Parse a raw accent spec, which is one or more comma-separated accents, each of which may be aliases listed in the
-- accent data in [[Module:accent qualifier/data]]. FIXME: The separate accent qualifier data will be going away and
-- merged into label data, at which point we'll have to rewrite this.
local function parse_accents(arg)
	-- Accent group processing
	local accent_data = mw.loadData(accent_qualifier_data_module)

	-- Split on commas and canonicalize aliases.
	local accents = rsplit(arg, "%s*,%s*")
	for i, alias in ipairs(accents) do
		if accent_data.aliases[alias] then
			accents[i] = accent_data.aliases[alias]
		end
	end

	return accents
end


-- Return the number of syllables of a phonemic representation, which should have syllable dividers in it but no
-- hyphens.
local function get_num_syl_from_phonemic(phonemic)
	-- Maybe we should just count vowels instead of the below code.
	phonemic = rsub(phonemic, "|", " ") -- remove IPA foot boundaries
	local words = rsplit(phonemic, " +")
	for i, word in ipairs(words) do
		-- IPA stress marks are syllable divisions if between characters; otherwise just remove.
		word = rsub(word, "(.)[ˌˈ](.)", "%1.%2")
		word = rsub(word, "[ˌˈ]", "")
		words[i] = word
	end
	-- There should be a syllable boundary between words.
	phonemic = table.concat(words, ".")
	return ulen(rsub(phonemic, "[^.]", "")) + 1
end


-- Get the rhyme by truncating everything up through the last stress mark + any following consonants, and remove
-- syllable boundary markers.
local function convert_phonemic_to_rhyme(phonemic)
	-- NOTE: This works because the phonemic vowels are just [aeiou] possibly with diacritics that are separate
	-- Unicode chars. If we want to handle things like ɛ or ɔ we need to add them to `vowel`.
	return rsub(rsub(phonemic, ".*[ˌˈ]", ""), "^[^" .. vowel .. "]*", ""):gsub("%.", ""):gsub("t͡ʃ", "tʃ")
end


local function split_syllabified_spelling(spelling)
	return rsplit(spelling, "%.")
end


-- "Align" syllabification to original spelling by matching character-by-character, allowing for extra syllable and
-- accent markers in the syllabification. If we encounter an extra syllable marker (.), we allow and keep it. If we
-- encounter an extra accent marker in the syllabification, we drop it. In any other case, we return nil indicating
-- the alignment failed.
local function align_syllabification_to_spelling(syllab, spelling)
	local result = {}
	local syll_chars = rsplit(decompose(syllab), "")
	local spelling_chars = rsplit(decompose(spelling), "")
	local i = 1
	local j = 1
	while i <= #syll_chars or j <= #spelling_chars do
		local ci = syll_chars[i]
		local cj = spelling_chars[j]
		if ci == cj then
			table.insert(result, ci)
			i = i + 1
			j = j + 1
		elseif ci == "." then
			table.insert(result, ci)
			i = i + 1
		elseif ci == AC or ci == GR or ci == CFLEX then
			-- skip character
			i = i + 1
		else
			-- non-matching character
			return nil
		end
	end
	if i <= #syll_chars or j <= #spelling_chars then
		-- left-over characters on one side or the other
		return nil
	end
	return unfc(table.concat(result))
end


local function generate_hyph_obj(term)
	return {syllabification = term, hyph = split_syllabified_spelling(term)}
end


-- Word should already be decomposed.
local function word_has_vowels(word)
	return rfind(word, V)
end


local function all_words_have_vowels(term)
	local words = rsplit(decompose(term), "[ %-]")
	for i, word in ipairs(words) do
		-- Allow empty word; this occurs with prefixes and suffixes.
		if word ~= "" and not word_has_vowels(word) then
			return false
		end
	end
	return true
end


local function should_generate_rhyme_from_respelling(term)
	local words = rsplit(decompose(term), " +")
	return #words == 1 and -- no if multiple words
		not words[1]:find(".%-.") and -- no if word is composed of hyphenated parts (e.g. [[Austria-Hungría]])
		not words[1]:find("%-$") and -- no if word is a prefix
		not (words[1]:find("^%-") and words[1]:find(CFLEX)) and -- no if word is an unstressed suffix
		word_has_vowels(words[1]) -- no if word has no vowels (e.g. a single letter)
end


local function should_generate_rhyme_from_ipa(ipa)
	return not ipa:find("%s") and word_has_vowels(decompose(ipa))
end


local function parse_pron_modifier(arg, parse_err, generate_obj, param_mods, no_split_on_comma)
	local retval = {}

	if arg:find("<") then
		local insert = { store = "insert" }
		param_mods.q = insert
		param_mods.qq = insert
		param_mods.a = insert
		param_mods.aa = insert
		return require(put_module).parse_inline_modifiers(arg, {
			param_mods = param_mods,
			generate_obj = generate_obj,
			parse_err = parse_err,
			splitchar = not no_split_on_comma and "," or nil,
		})
	elseif no_split_on_comma then
		table.insert(retval, generate_obj(arg))
	else
		for _, term in ipairs(split_on_comma(arg)) do
			table.insert(retval, generate_obj(term))
		end
	end

	return retval
end


local function parse_rhyme(arg, parse_err)
	local function generate_obj(term)
		return {rhyme = term}
	end
	local param_mods = {
		s = {
			item_dest = "num_syl",
			convert = function(arg, parse_err)
				local nsyls = rsplit(arg, ",")
				for i, nsyl in ipairs(nsyls) do
					if not nsyl:find("^[0-9]+$") then
						parse_err("Number of syllables '" .. nsyl .. "' should be numeric")
					end
					nsyls[i] = tonumber(nsyl)
				end
				return nsyls
			end,
		},
	}

	return parse_pron_modifier(arg, parse_err, generate_obj, param_mods)
end


local function parse_hyph(arg, parse_err)
	-- None other than qualifiers
	local param_mods = {}

	return parse_pron_modifier(arg, parse_err, generate_hyph_obj, param_mods)
end


local function parse_homophone(arg, parse_err)
	local function generate_obj(term)
		return {term = term}
	end
	local param_mods = {
		t = {
			-- We need to store the <t:...> inline modifier into the "gloss" key of the parsed term,
			-- because that is what [[Module:links]] (called from [[Module:homophones]]) expects.
			item_dest = "gloss",
		},
		gloss = {},
		pos = {},
		alt = {},
		lit = {},
		id = {},
		g = {
			-- We need to store the <g:...> inline modifier into the "genders" key of the parsed term,
			-- because that is what [[Module:links]] (called from [[Module:homophones]]) expects.
			item_dest = "genders",
			convert = function(arg)
				return rsplit(arg, ",")
			end,
		},
	}

	return parse_pron_modifier(arg, parse_err, generate_obj, param_mods)
end


local function generate_audio_obj(arg)
	local file, gloss
	if arg:find("#") then
		file, gloss = arg:match("^(.-)%s*#%s*(.*)$")
	else
		file, gloss = arg:match("^(.-)%s*;%s*(.*)$")
	end
	if not file then
		file = arg
		gloss = "Audio"
	end
	return {file = file, gloss = gloss}
end


local function parse_audio(arg, parse_err)
	-- None other than qualifiers
	local param_mods = {}

	-- Don't split on comma because some filenames have embedded commas not followed by a space
	-- (typically followed by an underscore).
	return parse_pron_modifier(arg, parse_err, generate_audio_obj, param_mods, "no split on comma")
end


local function syllabify_from_spelling(text, pagename)
	-- Auto hyphenation start --
	local vowel = vowel .. "ẃý" -- vowel 
	local V = "[" .. vowel .. "]"
	local C = "[^" .. vowel .. separator .. "]" -- consonant

	text = remove_accents(text)

	origtext = text
	text = string.lower(text)

	-- put # at word beginning and end and double ## at text/foot boundary beginning/end
	text = rsub(text, " | ", "# | #")
	text = "##" .. rsub(text, " ", "# #") .. "##"
	text = rsub_repeatedly(text, "([.]?)#([.]?)", "#")

	text = rsub(text, "ng", "ŋ")
	text = rsub(text, "ch", "ĉ")
	text = rsub(text, "sh", "ʃ")
	text = rsub(text, "gui([aeëo])", "gui.%1")
	text = rsub(text, "r", "ɾ")
	text = rsub(text, "ɾɾ", "r")

	text = rsub_repeatedly(text, "([^" .. vowel ..  "])([u])([" .. AC .. MACRON .. "]?)([aeio])("  .. accent_c .. "?)","%1%2%3.%4%5")
	text = rsub_repeatedly(text, "(" .. V ..  ")([u])([" .. AC .. MACRON .. "]?)([aeio])("  .. accent_c .. "?)","%1.u%3%4%5")
	text = rsub_repeatedly(text, "(" .. V ..  ")([o])([" .. AC .. MACRON .. "]?)([aei])("  .. accent_c .. "?)","%1.o%3%4%5")
	text = rsub(text, "([i])([" .. AC .. MACRON .. "])([aeou])("  .. accent_c .. "?)","%1%2#í%3%4")
	text = rsub(text, "([i])([aeou])(" .. accent_c .. "?)","í%2%3")
	text = rsub(text, "a([".. AC .."]*)o([#.])","a%1ó%2")

	text = rsub(text, "y([ˈˌ.]*)([bćĉdfɡhjĵklmnɲŋpɾrsʃtvwɟzʔ#" .. vowel .. "])","ý%1%2")
	text = rsub(text, "ý(" .. V .. ")", "y%1")
	text = rsub(text, "w([ˈˌ]?)([bćĉdfɡjĵklmnɲŋpɾrsʃtvwɟzʔ#" .. vowel .. "])","ẃ%1%2")
	text = rsub(text, "ẃ(" .. V .. ")","w%1")

	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*)(" .. C .. V .. ")", "%1.%2")

	-- "mb", "mp", "nd", "nk", "nt" combinations
	text = rsub_repeatedly(text, "(m)([bp])([^lɾrɟyw" .. vowel .. separator .."])", "%1%2.%3")
	text = rsub_repeatedly(text, "(n)([dkt])([^lɾrɟyw" .. vowel .. separator .. "])", "%1%2.%3")
	text = rsub_repeatedly(text, "(ŋ)([k])([^lɾrɟyw" .. vowel .. separator ..  "])", "%1%2.%3")
	text = rsub_repeatedly(text, "([ɾr])([bkdfɡklmnpsʃtvz])([^lɾrɟyw" .. vowel .. separator ..  "])", "%1%2.%3")

	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. ")(" .. C .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. "+)(" .. C .. C .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. C .. ")%.s(" .. C .. ")", "%1s.%2")

	-- Any aeo, or stressed iu, should be syllabically divided from a following aeo or stressed iu.
	text = rsub_repeatedly(text, "([aeo]" .. accent_c .. "*)([aeo])", "%1.%2")
	text = rsub_repeatedly(text, "([aeo]" .. accent_c .. "*)(" .. V .. AC .. ")", "%1.%2")
	text = rsub(text, "([iuə]" .. AC .. ")([aeo])", "%1.%2")
	text = rsub_repeatedly(text, "([iuə]" .. AC .. ")(" .. V .. AC .. ")", "%1.%2")
	text = rsub_repeatedly(text, "i(" .. accent_c .. "*)i", "i%1.i")
	text = rsub_repeatedly(text, "u(" .. accent_c .. "*)u", "u%1.u")

	text = rsub(text, "ĉ", "ch")
	text = rsub(text, "ŋ", "ng")
	text = rsub(text, "ʃ", "sh")
	text = rsub(text, "r", "rr")
	text = rsub(text, "ɾ", "r")
	text = remove_accents(text)

	text = rsub_repeatedly(text, "([.]+)", ".")
	text = rsub(text, "[.]?-[.]?", "-")
	text = rsub(text, "[‿]([^ ])", "|%1")
	text = rsub(text, "[.]([^ ])", "|%1")

	text = rsub(text, "([gq])([u])|([ei])", "%1%2%3")
	text = rsub(text, "([^ 0-9]?)([7])([^ 0-9]?)", "%1%3")
	text = rsub(text, "([|])+", "%1")

	-- remove # symbols at word and text boundaries
	text = rsub_repeatedly(text, "([.]?)#([.]?)", "")

	-- Fix Capitalization --
	local syllbreak = 0
	for i=1, #text do
		if text:sub(i,i) == "|" and origtext:sub(i-syllbreak, i-syllbreak) ~= "." and origtext:sub(i-syllbreak, i-syllbreak) ~= "7" then
			syllbreak = syllbreak + 1
		elseif origtext:sub(i-syllbreak, i-syllbreak) == text:sub(i,i):upper() then
			text = table.concat({text:sub(1, i-1), text:sub(i,i):upper(), text:sub(i+1)}) 
		end
	end

	-- Fix hyphens --
	-- FIXME!!! Why are we relying on looking at the pagename here? This should not be happening.
	origtext = pagename

	if (table.concat(rsplit(origtext, "-")) ==  table.concat(rsplit(table.concat(rsplit(text, "|")), "-"))) then
		syllbreak = 0
		for i=1, #text do
			if text:sub(i,i) == "|" then
				if origtext:sub(i-syllbreak, i-syllbreak) == "-" then
					text = table.concat({text:sub(1, i-1), "-", text:sub(i+1)}) 
				else
					syllbreak = syllbreak + 1
				end
			end
		end
	end

	-- FIXME! Hack -- up above we changed periods to vertical bars. The rest of the code expects periods so change
	-- them back. We should clean up the code above to leave the periods alone.
	return (text:gsub("|", "%."))
end

local function css_wrap(text, classes)
	return ('<span class="%s">%s</span>'):format(classes, text)
end

local function format_glosses(glosses)
	if #glosses == 0 then
		return ""
	end

	local formatted_glosses = {}
	for _, glossobj in ipairs(glosses) do
		local gloss_parts = {}
		if glossobj.gloss then
			table.insert(gloss_parts, css_wrap("“", "mention-gloss-double-quote") ..
				css_wrap(glossobj.gloss, "mention-gloss") .. css_wrap("”", "mention-gloss-double-quote"))
		end
		if glossobj.pos then
			table.insert(gloss_parts, css_wrap(glossobj.pos, "ann-pos"))
		end
		table.insert(formatted_glosses, table.concat(gloss_parts, css_wrap(",", "mention-gloss-comma") .. " "))
	end

	return " " .. css_wrap("(", "mention-gloss-paren annotation-paren") ..
		table.concat(formatted_glosses, css_wrap(";", "mention-gloss-semicolon") .. " ") ..
		css_wrap(")", "mention-gloss-paren annotation-paren")
end

local function format_pronuns(parsed)
	local pronunciations = {}

	-- Loop through each pronunciation. For each one, add the phonemic and phonetic versions to `pronunciations`,
	-- for formatting by [[Module:IPA]].
	for j, pronun in ipairs(parsed.pronun) do
		local qs = pronun.q

		local first_pronun = #pronunciations + 1

		if not pronun.phonemic and not pronun.phonetic then
			error("Internal error: Saw neither phonemic nor phonetic pronunciation")
		end

		if pronun.phonemic then -- missing if 'raw:[...]' given
			-- don't display syllable division markers in phonemic
			local slash_pron = "/" .. pronun.phonemic:gsub("%.", "") .. "/"
			table.insert(pronunciations, {
				pron = slash_pron,
			})
		end

		if pronun.phonetic then -- missing if 'raw:/.../' given
			local bracket_pron = "[" .. pronun.phonetic .. "]"
			table.insert(pronunciations, {
				pron = bracket_pron,
			})
		end

		local last_pronun = #pronunciations

		if pronun.q then
			pronunciations[first_pronun].q = pronun.q
		end
		if j > 1 then
			pronunciations[first_pronun].separator = ", "
		end
		if pronun.qq then
			pronunciations[last_pronun].qq = pronun.qq
		end

		if pronun.refs then
			pronunciations[last_pronun].refs = pronun.refs
		end
		if first_pronun ~= last_pronun then
			pronunciations[last_pronun].separator = " "
		end
	end

	local bullet = string.rep("*", parsed.bullets) .. " "
	-- Here we construct the formatted line in `formatted`, and also try to construct the equivalent without HTML
	-- and wiki markup in `formatted_for_len`, so we can compute the approximate textual length for use in sizing
	-- the toggle box with the "more" button on the right.
	local pre = is_first and parsed.pre and parsed.pre .. " " or ""
	local post = is_first and parsed.post and " " .. parsed.post or ""
	local formatted = bullet .. pre .. m_IPA.format_IPA_full(lang, pronunciations, nil, "") ..
		format_glosses(parsed.t) .. post
	return formatted
end


local function parse_respelling(respelling, pagename, parse_err)
	local raw_respelling = respelling:match("^raw:(.*)$")
	if raw_respelling then
		local raw_phonemic, raw_phonetic = raw_respelling:match("^/(.*)/ %[(.*)%]$")
		if not raw_phonemic then
			raw_phonemic = raw_respelling:match("^/(.*)/$")
		end
		if not raw_phonemic then
			raw_phonetic = raw_respelling:match("^%[(.*)%]$")
		end
		if not raw_phonemic and not raw_phonetic then
			parse_err(("Unable to parse raw respelling '%s', should be one of /.../, [...] or /.../ [...]")
				:format(raw_respelling))
		end
		return {
			raw = true,
			raw_phonemic = raw_phonemic,
			raw_phonetic = raw_phonetic,
		}
	end
	if respelling == "+" then
		respelling = pagename
	end
	return {term = respelling}
end


-- External entry point for {{tl-pr}}.
function export.show_full(frame)
	local params = {
		[1] = {list = true},
		["rhyme"] = {},
		["hyph"] = {},
		["hmp"] = {},
		["audio"] = {list = true},
		["pagename"] = {},
		["hyphcap"] = {default = "Syllabification"},
	}
	local parargs = frame:getParent().args
	local args = require("Module:parameters").process(parargs, params)
	local pagename = args.pagename or mw.title.getCurrentTitle().subpageText

	-- Parse the arguments.
	local respellings = #args[1] > 0 and args[1] or {"+"}
	local parsed_respellings = {}
	local function overall_parse_err(msg, arg, val)
		error(msg .. ": " .. arg .. "=" .. val)
	end
	local overall_rhyme = args.rhyme and
		parse_rhyme(args.rhyme, function(msg) overall_parse_err(msg, "rhyme", args.rhyme) end) or nil
	local overall_hyph = args.hyph and
		parse_hyph(args.hyph, function(msg) overall_parse_err(msg, "hyph", args.hyph) end) or nil
	local overall_hmp = args.hmp and
		parse_homophone(args.hmp, function(msg) overall_parse_err(msg, "hmp", args.hmp) end) or nil
	local overall_audio
	if args.audio then
		overall_audio = {}
		for _, audio in ipairs(args.audio) do
			local parsed_audio = parse_audio(audio, function(msg) overall_parse_err(msg, "audio", audio) end)
			if #parsed_audio > 1 then
				error("Internal error: Saw more than one object returned from parse_audio")
			end
			table.insert(overall_audio, parsed_audio[1])
		end
	end

	-- Parse each respelling. Individual arguments in 1=, 2=, etc. can consist of one or more comma-separated
	-- respellings, each of which can have inline modifiers <q:...>, <qq:...>, <a:...>, <aa:...> or <ref:...>.
	-- In addition, the respellings as a whole of a given argument can be followed by various inline modifiers,
	-- such as <t:...>, <rhyme:...>, <hyph:...>, etc. The result of parsing goes into `parsed_respellings`, which
	-- is a list of objects (one per numbered argument), each of which is a table of the form
	--
	-- {
	--   terms = {TERM, TERM, ...},
	--   audio = {AUDIO, AUDIO, ...},
	--   rhyme = {RHYME, RHYME, ...},
	--   hyph = {HYPH, HYPH, ...},
	--   hmp = {HMP, HMP, ...},
	--   t = {GLOSS, GLOSS, ...},
	--   pre = "PRE-TEXT" or nil,
	--   post = "POST-TEXT" or nil,
	--   bullets = NUM_BULLETS,
	--   accents = {"ACCENT", "ACCENT", ...},
	-- }
	--
	-- In this structure, TERM is an object that usually has the form
	--
	-- {
	--   term = "RESPELLING",
	--   ref = {"REF-SPEC", "REF-SPEC", ...},
	--   q = {"QUALIFIER", "QUALIFIER", ...},
	--   qq = {"QUALIFIER", "QUALIFIER", ...},
	-- }
	--
	-- Note that in this structure, "REF-SPEC" of the form parsable by parse_references() in [[Module:references]].
	--
	-- Alternatively, if phonemic or phonetic IPA is given in place of a respelling, TERM will have the form
	--
	-- {
	--   raw = true,
	--   phonemic = "PHONEMIC",
	--   phonetic = "PHONETIC",
	--   ref = {"REF-SPEC", "REF-SPEC", ...},
	--   q = {"QUALIFIER", "QUALIFIER", ...},
	--   qq = {"QUALIFIER", "QUALIFIER", ...},
	-- }
	--
	-- AUDIO is a table of the form
	--
	-- {
	--   file = "FILE",
	--   gloss = "GLOSS",
	--   q = {"QUALIFIER", "QUALIFIER", ...},
	--   qq = {"QUALIFIER", "QUALIFIER", ...},
	--   a = {"ACCENT-QUALIFIER", "ACCENT-QUALIFIER", ...},
	--   aa = {"ACCENT-QUALIFIER", "ACCENT-QUALIFIER", ...},
	-- }
	--
	-- RHYME is a table of the form
	--
	-- {
	--   rhyme = "RHYME",
	--   num_syl = {NUM_SYL, NUM_SYL, ...},
	--   q, qq, a, aa = (as for AUDIO),
	-- }
	--
	-- HYPH is a table of the form
	--
	-- {
	--   syllabification = "SYL.LAB.LES",
	--   hyph = {"SYL", "LAB", "LES"},
	--   q, qq, a, aa = (as for AUDIO),
	-- }
	--
	-- HMP is a table of the form
	--
	-- {
	--   term = "HOMOPHONE",
	--   gloss = "GLOSS" or nil,
	--   pos = "POS" or nil,
	--   alt = "ALT" or nil,
	--   lit = "LIT" or nil,
	--   id = "ID" or nil,
	--   g = {"G", "G", ...},
	--   q, qq, a, aa = (as for AUDIO),
	-- }
	--
	-- GLOSS is a table of the form
	--
	-- {
	--   pos = "POS" or nil,
	--   gloss = "GLOSS" or nil,
	-- }
	for i, respelling in ipairs(respellings) do
		if respelling:find("<") then
			local param_mods = {
				pre = { overall = true },
				post = { overall = true },
				bullets = {
					overall = true,
					convert = function(arg, parse_err)
						if not arg:find("^[0-9]+$") then
							parse_err("Modifier 'bullets' should have a number as argument, but saw '" .. arg .. "'")
						end
						return tonumber(arg)
					end,
				},
				t = {
					overall = true,
					store = "insert",
					convert = parse_gloss,
				},
				rhyme = {
					overall = true,
					store = "insert-flattened",
					convert = parse_rhyme,
				},
				hyph = {
					overall = true,
					store = "insert-flattened",
					convert = parse_hyph,
				},
				hmp = {
					overall = true,
					store = "insert-flattened",
					convert = parse_homophone,
				},
				audio = {
					overall = true,
					store = "insert-flattened",
					convert = parse_audio,
				},
				ref = { store = "insert" },
				q = { store = "insert" },
				qq = { store = "insert" },
				a = {
					item_dest = "accents",
					overall = true,
					convert = parse_accents, 
				},
			}

			local parsed = require(put_module).parse_inline_modifiers(respelling, {
				paramname = i,
				param_mods = param_mods,
				generate_obj = function(term, parse_err)
					return parse_respelling(term, pagename, parse_err)
				end,
				pre_normalize_modifiers = function(data)
					local modtext = data.modtext
					if modtext:find("%^") and not modtext:find("^t:") then
						modtext = "t:" .. modtext
					end
					return modtext
				end,
				splitchar = ",",
				outer_container = {
					-- FIXME, don't require that these structures always exist
					audio = {}, rhyme = {}, hyph = {}, hmp = {}, t = {}
				}
			})
			if not parsed.bullets then
				parsed.bullets = 1
			end
			table.insert(parsed_respellings, parsed)
		else
			local termobjs = {}
			local function parse_err(msg)
				error(msg .. ": " .. i .. "=" .. respelling)
			end
			for _, term in ipairs(split_on_comma(respelling)) do
				table.insert(termobjs, parse_respelling(term, pagename, parse_err))
			end
			table.insert(parsed_respellings, {
				terms = termobjs,
				-- FIXME, don't require that these structures always exist
				audio = {},
				rhyme = {},
				hyph = {},
				hmp = {},
				t = {},
				bullets = 1,
			})
		end
	end

	if overall_hyph then
		local hyphs = {}
		for _, hyph in ipairs(overall_hyph) do
			if hyph.syllabification == "+" then
				hyph.syllabification = syllabify_from_spelling(pagename, pagename)
				hyph.hyph = split_syllabified_spelling(hyph.syllabification)
			elseif hyph.syllabification == "-" then
				overall_hyph = {}
				break
			end
		end
	end

	local accent_no_count = {"colloquial", "obsolete", "relaxed"}
	local accent_order = m_table.invert {
		"Standard Tagalog",
		"dialectal",
		"Bataan", 
		"Bulacan", 
		"Nueva Ecija", 
		"Southern Tagalog", 
		"Cavite", 
		"Laguna",
		"Batangas",
		"Teresa-Morong", 
		"Tayabas", 
		"Marinduque", 
		"Old Tagalog"
	}

	local function doesnt_count_for_rhyme(list)
		if not list then
			return false
		end
		for _, item in ipairs(list) do
			for _, word_no_count in ipairs(accent_no_count) do
				if item:find("%f[%w]" .. word_no_count .. "%f[%W]") then
					return true
				end
			end
		end
		return false
	end

	-- Loop over individual respellings, processing each.
	for _, parsed in ipairs(parsed_respellings) do
		-- First, sort the specified accents and default to "Standard Tagalog".
		if not parsed.accents then
			parsed.accents = {"Standard Tagalog"}
		end

		-- If multiple accents given, sort according to the accent order listed above. Unrecognized accents go
		-- at the end.
		table.sort(parsed.accents, 
			function(a, b)
				-- 100 is an arbitrary high number for sorting
				local acc_a = accent_order[a] or 100
				local acc_b = accent_order[b] or 100
				if acc_a == acc_b then
					-- Fall back to lexical sort.
					return a < b
				else
					return acc_a < acc_b
				end
			end
		)
		-- If more than one respelling given, then if any accent or qualifier has the words 'colloquial', 'obsolete' or
		-- 'relaxed' in them, don't generate a rhyme or a '#-syllable word' category.
		local more_than_one_respelling = #parsed.terms > 1 or #parsed_respellings > 1
		local is_standard_tagalog = m_table.contains(parsed.accents, "Standard Tagalog")
		local all_terms_no_rhyme = more_than_one_respelling and doesnt_count_for_rhyme(parsed.accents)

		local pronuns = {}
		for i, term in ipairs(parsed.terms) do
			-- Same check as above for colloquial/obsolete/relaxed but check the qualifiers, which are attached to
			-- individual respellings rather than a single-line set of respellings.
			if all_terms_no_rhyme or more_than_one_respelling and (
				doesnt_count_for_rhyme(term.q) or doesnt_count_for_rhyme(term.qq)
			) then
				term.no_rhyme = true
			end

			local phonemic, phonetic
			if term.raw then
				phonemic = term.raw_phonemic
				phonetic = term.raw_phonetic
			else
				local ret = export.IPA(term.term)
				phonemic = ret.phonemic
				phonetic = ret.phonetic
			end
			local refs
			if not term.ref then
				refs = nil
			else
				refs = {}
				for _, refspec in ipairs(term.ref) do
					local this_refs = require("Module:references").parse_references(refspec)
					for _, this_ref in ipairs(this_refs) do
						table.insert(refs, this_ref)
					end
				end
			end

			local pronobj = {
				raw = term.raw,
				phonemic = phonemic,
				phonetic = phonetic,
				refs = refs,
				q = term.q,
				qq = term.qq,
			}

			table.insert(pronuns, pronobj)

			-- If [fvz] present in phonemic pronunciation, generate a "more native-sounding" variant with [pbs] in
			-- place.
			local fvz_pronobj
			if pronobj.phonemic:find("[fvz]") then
				local fvz_charmap = { ["f"] = "p", ["v"] = "b", ["z"] = "s"}
				fvz_pronobj = {
					raw = pronobj.raw,
					phonemic = pronobj.phonemic:gsub("[fvz]", fvz_charmap),
					phonetic = pronobj.phonetic:gsub("[fvz]", fvz_charmap),
					refs = pronobj.refs,
					q = combine_qualifiers(pronobj.q, {"more native-sounding"}),
					qq = pronobj.qq,
				}
				table.insert(pronuns, fvz_pronobj)
			end

			-- If the phonemic form of any generated IPA contains a non-final word ending in a glottal stop, augment the
			-- IPA's with an additional entry where the phonemic glottal stop becomes optional and the phonetic glottal
			-- stop is converted to a long vowel.
			local pronobj_for_ipa_check = fvz_pronobj or pronobj
			if is_standard_tagalog and pronobj_for_ipa_check.phonemic:find("ʔ ") then
				local glottal_stop_pronobj = {
					raw = pronobj_for_ipa_check.raw,
					phonemic = pronobj_for_ipa_check:gsub("ʔ ", "(ʔ) "),
					phonetic = pronobj_for_ipa_check:gsub("ʔ ", "ː "),
					refs = pronobj_for_ipa_check.refs,
					q = combine_qualifiers(pronobj_for_ipa_check.q, {"with glottal stop elision"}),
					qq = pronobj_for_ipa_check.qq,
				}
				table.insert(pronuns, glottal_stop_pronobj)
			end
		end
		parsed.pronuns = pronuns

		local no_auto_rhyme = false
		for _, term in ipairs(parsed.terms) do
			if term.raw then
				if not should_generate_rhyme_from_ipa(term.raw_phonemic or term.raw_phonetic) then
					no_auto_rhyme = true
					break
				end
			elseif not should_generate_rhyme_from_respelling(term.term) then
				no_auto_rhyme = true
				break
			end
		end

		if #parsed.hyph == 0 then
			if not overall_hyph and all_words_have_vowels(pagename) then
				for _, term in ipairs(parsed.terms) do
					if not term.raw then
						local syllabification = syllabify_from_spelling(term.term, pagename)
						local aligned_syll = align_syllabification_to_spelling(syllabification, pagename)
						if aligned_syll then
							m_table.insertIfNot(parsed.hyph, generate_hyph_obj(aligned_syll))
						end
					end
				end
			end
		else
			for _, hyph in ipairs(parsed.hyph) do
				if hyph.syllabification == "+" then
					hyph.syllabification = syllabify_from_spelling(pagename, pagename)
					hyph.hyph = split_syllabified_spelling(hyph.syllabification)
				elseif hyph.syllabification == "-" then
					parsed.hyph = {}
					break
				end
			end
		end

		-- Generate the rhymes.
		for _, pronun in ipairs(parsed.pronuns) do
			-- We should have already excluded multiword terms and terms without vowels from rhyme generation (see
			-- `no_auto_rhyme` below). But make sure to check that pronun.phonemic exists (it may not if raw
			-- phonetic-only pronun is given).
			if pronun.phonemic then
				-- Count number of syllables by looking at syllable boundaries (including stress marks).
				local num_syl = get_num_syl_from_phonemic(pronun.phonemic)
				-- Get the rhyme by truncating everything up through the last stress mark + any following
				-- consonants, and remove syllable boundary markers.
				local rhyme = convert_phonemic_to_rhyme(pronun.phonemic)
				local saw_already = false
				for _, existing in ipairs(rhyme_ret.pronun[dialect]) do
					if existing.rhyme == rhyme then
						saw_already = true
						-- We already saw this rhyme but possibly with a different number of syllables,
						-- e.g. if the user specified two pronunciations 'biología' (4 syllables) and
						-- 'bi.ología' (5 syllables), both of which have the same rhyme /ia/.
						m_table.insertIfNot(existing.num_syl, num_syl)
						break
					end
				end
				if not saw_already then
					table.insert(rhyme_ret.pronun[dialect], {
						rhyme = rhyme,
						num_syl = {num_syl},
					})
				end
			end
		end

		if #parsed.rhyme == 0 then
			if overall_rhyme or no_auto_rhyme then
				parsed.rhyme = nil
			else
				parsed.rhyme = express_all_styles(parsed.style, dodialect_rhymes_from_pronun)
			end
		else
			local no_rhyme = false
			for _, rhyme in ipairs(parsed.rhyme) do
				if rhyme.rhyme == "-" then
					no_rhyme = true
					break
				end
			end
			if no_rhyme then
				parsed.rhyme = nil
			else
				local function this_dodialect(rhyme_ret, dialect)
					return dodialect_specified_rhymes(parsed.rhyme, parsed.hyph, {parsed}, rhyme_ret, dialect)
				end
				parsed.rhyme = express_all_styles(parsed.style, this_dodialect)
			end
		end
	end

	if overall_rhyme then
		local no_overall_rhyme = false
		for _, orhyme in ipairs(overall_rhyme) do
			if orhyme.rhyme == "-" then
				no_overall_rhyme = true
				break
			end
		end
		if no_overall_rhyme then
			overall_rhyme = nil
		else
			local all_hyphs
			if overall_hyph then
				all_hyphs = overall_hyph
			else
				all_hyphs = {}
				for _, parsed in ipairs(parsed_respellings) do
					for _, hyph in ipairs(parsed.hyph) do
						m_table.insertIfNot(all_hyphs, hyph)
					end
				end
			end
			local function dodialect_overall_rhyme(rhyme_ret, dialect)
				return dodialect_specified_rhymes(overall_rhyme, all_hyphs, parsed_respellings, rhyme_ret, dialect)
			end
			overall_rhyme = express_all_styles(parsed.style, dodialect_overall_rhyme)
		end
	end

	-- If all sets of pronunciations have the same rhymes, display them only once at the bottom.
	-- Otherwise, display rhymes beneath each set, indented.
	local first_rhyme_ret
	local all_rhyme_sets_eq = true
	for j, parsed in ipairs(parsed_respellings) do
		if j == 1 then
			first_rhyme_ret = parsed.rhyme
		elseif not m_table.deepEquals(first_rhyme_ret, parsed.rhyme) then
			all_rhyme_sets_eq = false
			break
		end
	end

	local function format_rhyme(rhyme_ret, num_bullets)
		local function format_rhyme_style(tag, expressed_style, is_first)
			local pronunciations = {}
			local rhymes = {}
			for _, pronun in ipairs(expressed_style.pronun) do
				table.insert(rhymes, pronun)
			end
			local data = {
				lang = lang,
				rhymes = rhymes,
				qualifiers = tag and {tag} or nil,
				force_cat = force_cat,
			}
			local bullet = string.rep("*", num_bullets) .. " "
			local formatted = bullet .. require("Module:rhymes").format_rhymes(data)
			local formatted_for_len_parts = {}
			table.insert(formatted_for_len_parts, bullet .. "Rhymes: " .. (tag and "(" .. tag .. ") " or ""))
			for j, pronun in ipairs(expressed_style.pronun) do
				if j > 1 then
					table.insert(formatted_for_len_parts, ", ")
				end
				if pronun.qualifiers then
					table.insert(formatted_for_len_parts, "(" .. table.concat(pronun.qualifiers, ", ") .. ") ")
				end
				table.insert(formatted_for_len_parts, "-" .. pronun.rhyme)
			end
			return formatted, textual_len(table.concat(formatted_for_len_parts))
		end

		return format_all_styles(rhyme_ret.expressed_styles, format_rhyme_style)
	end

	-- If all sets of pronunciations have the same hyphenations, display them only once at the bottom.
	-- Otherwise, display hyphenations beneath each set, indented.
	local first_hyphs
	local all_hyph_sets_eq = true
	for j, parsed in ipairs(parsed_respellings) do
		if j == 1 then
			first_hyphs = parsed.hyph
		elseif not m_table.deepEquals(first_hyphs, parsed.hyph) then
			all_hyph_sets_eq = false
			break
		end
	end

	local function format_hyphenations(hyphs, num_bullets)
		local hyphtext = require("Module:hyphenation").format_hyphenations { lang = lang, hyphs = hyphs, caption = "Syllabification" }
		return string.rep("*", num_bullets) .. " " .. hyphtext
	end

	-- If all sets of pronunciations have the same homophones, display them only once at the bottom.
	-- Otherwise, display homophones beneath each set, indented.
	local first_hmps
	local all_hmp_sets_eq = true
	for j, parsed in ipairs(parsed_respellings) do
		if j == 1 then
			first_hmps = parsed.hmp
		elseif not m_table.deepEquals(first_hmps, parsed.hmp) then
			all_hmp_sets_eq = false
			break
		end
	end

	local function format_homophones(hmps, num_bullets)
		local hmptext = require("Module:homophones").format_homophones { lang = lang, homophones = hmps }
		return string.rep("*", num_bullets) .. " " .. hmptext
	end

	local function format_audio(audios, num_bullets)
		local ret = {}
		for i, audio in ipairs(audios) do
			local text = require("Module:audio").format_audios (
				{
				  lang = lang,
				  audios = {{file = audio.file, qualifiers = nil }, },
				  caption = audio.gloss
				}
			)
			
			if audio.q and audio.q[1] or audio.qq and audio.qq[1]
				or audio.a and audio.a[1] or audio.aa and audio.aa[1] then
				text = require("Module:pron qualifier").format_qualifiers(audio, text)
			end
			table.insert(ret, string.rep("*", num_bullets) .. " " .. text)
		end
		return table.concat(ret, "\n")
	end

	local textparts = {}
	local min_num_bullets = 9999
	for j, parsed in ipairs(parsed_respellings) do
		if parsed.bullets < min_num_bullets then
			min_num_bullets = parsed.bullets
		end
		if j > 1 then
			table.insert(textparts, "\n")
		end
		table.insert(textparts, parsed.pronun.text)
		if #parsed.audio > 0 then
			table.insert(textparts, "\n")
			-- If only one pronunciation set, add the audio with the same number of bullets, otherwise
			-- indent audio by one more bullet.
			table.insert(textparts, format_audio(parsed.audio,
				#parsed_respellings == 1 and parsed.bullets or parsed.bullets + 1))
		end
		if not all_rhyme_sets_eq and parsed.rhyme then
			table.insert(textparts, "\n")
			table.insert(textparts, format_rhyme(parsed.rhyme, parsed.bullets + 1))
		end
		if not all_hyph_sets_eq and #parsed.hyph > 0 then
			table.insert(textparts, "\n")
			table.insert(textparts, format_hyphenations(parsed.hyph, parsed.bullets + 1))
		end
		if not all_hmp_sets_eq and #parsed.hmp > 0 then
			table.insert(textparts, "\n")
			table.insert(textparts, format_homophones(parsed.hmp, parsed.bullets + 1))
		end
	end
	if overall_audio and #overall_audio > 0 then
		table.insert(textparts, "\n")
		table.insert(textparts, format_audio(overall_audio, min_num_bullets))
	end
	if all_rhyme_sets_eq and first_rhyme_ret then
		table.insert(textparts, "\n")
		table.insert(textparts, format_rhyme(first_rhyme_ret, min_num_bullets))
	end
	if overall_rhyme then
		table.insert(textparts, "\n")
		table.insert(textparts, format_rhyme(overall_rhyme, min_num_bullets))
	end
	if all_hyph_sets_eq and #first_hyphs > 0 then
		table.insert(textparts, "\n")
		table.insert(textparts, format_hyphenations(first_hyphs, min_num_bullets))
	end
	if overall_hyph and #overall_hyph > 0 then
		table.insert(textparts, "\n")
		table.insert(textparts, format_hyphenations(overall_hyph, min_num_bullets))
	end
	if all_hmp_sets_eq and #first_hmps > 0 then
		table.insert(textparts, "\n")
		table.insert(textparts, format_homophones(first_hmps, min_num_bullets))
	end
	if overall_hmp and #overall_hmp > 0 then
		table.insert(textparts, "\n")
		table.insert(textparts, format_homophones(overall_hmp, min_num_bullets))
	end

	return table.concat(textparts)
end


-- Old entry point for {{tl-pr}}, using old parameters.
function export.show_full_old(frame)
	---Process parameters---
	local parargs = frame:getParent().args
	local params = {
		[1] = {list = true, allow_holes = true},
		["IPA"] = {list = true, allow_holes = true},
		["audio"] = {list = true, allow_holes = true},
		["audioq"] = {list = true, allow_holes = true},
		["hmp"] = {list = true},
		["hmpq"] = {list = true},
		["a"] = {list = true, allow_holes = true},
		["q"] = {list = true, allow_holes = true},
		["hyphcap"] = {default = "Syllabification"},
		["nohyph"] = {type = "number", default = 0},
		["norhymes"] = {type = "number", default = 0}
	}
	local args = require("Module:parameters").process(parargs, params)
	local output = {}
	local categories = {}
	local hyph_data = { 
		[1] = lang:getCode(),
		caption = args["hyphcap"]
	}

	---Hyphenation---
	if args.nohyph == 0 then
		local hyph_args = args[1]
		
		local function removeAccents(str)
			str = toNFD(str)
			str = rsub(str, ".[" .. TILDE .. DIA .. "]", {
				["n" .. TILDE] = "ñ",
				["u" .. DIA] = "ü",
				["e" .. DIA] = "ë",
			})
			str = rsub(str, "(.)" .. accent_c, "%1")
			return str
		end
		
		local text = hyph_args[1] or mw.title.getCurrentTitle().text
		
		local function hyphenate(text)
			-- Auto hyphenation start --
			local vowel = vowel .. "ẃý" -- vowel 
			local V = "[" .. vowel .. "]"
			local C = "[^" .. vowel .. separator .. "]" -- consonant
			
			text = removeAccents(text)
			
			origtext = text
			text = string.lower(text)
			
			-- put # at word beginning and end and double ## at text/foot boundary beginning/end
			text = rsub(text, " | ", "# | #")
			text = "##" .. rsub(text, " ", "# #") .. "##"
			text = rsub_repeatedly(text, "([.]?)#([.]?)", "#")
			
			text = rsub(text, "ng", "ŋ")
			text = rsub(text, "ch", "ĉ")
			text = rsub(text, "sh", "ʃ")
			text = rsub(text, "gui([aeëo])", "gui.%1")
			text = rsub(text, "r", "ɾ")
			text = rsub(text, "ɾɾ", "r")
			
			text = rsub_repeatedly(text, "([^" .. vowel ..  "])([u])([" .. AC .. MACRON .. "]?)([aeio])("  .. accent_c .. "?)","%1%2%3.%4%5")
			text = rsub_repeatedly(text, "(" .. V ..  ")([u])([" .. AC .. MACRON .. "]?)([aeio])("  .. accent_c .. "?)","%1.u%3%4%5")
			text = rsub_repeatedly(text, "(" .. V ..  ")([o])([" .. AC .. MACRON .. "]?)([aei])("  .. accent_c .. "?)","%1.o%3%4%5")
			text = rsub(text, "([i])([" .. AC .. MACRON .. "])([aeou])("  .. accent_c .. "?)","%1%2#í%3%4")
			text = rsub(text, "([i])([aeou])(" .. accent_c .. "?)","í%2%3")
			text = rsub(text, "a([".. AC .."]*)o([#.])","a%1ó%2")
		
			text = rsub(text, "y([ˈˌ.]*)([bćĉdfɡhjĵklmnɲŋpɾrsʃtvwɟzʔ#" .. vowel .. "])","ý%1%2")
			text = rsub(text, "ý(" .. V .. ")", "y%1")
			text = rsub(text, "w([ˈˌ]?)([bćĉdfɡjĵklmnɲŋpɾrsʃtvwɟzʔ#" .. vowel .. "])","ẃ%1%2")
			text = rsub(text, "ẃ(" .. V .. ")","w%1")
		
			text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*)(" .. C .. V .. ")", "%1.%2")
			
			-- "mb", "mp", "nd", "nk", "nt" combinations
			text = rsub_repeatedly(text, "(m)([bp])([^lɾrɟyw" .. vowel .. separator .."])", "%1%2.%3")
			text = rsub_repeatedly(text, "(n)([dkt])([^lɾrɟyw" .. vowel .. separator .. "])", "%1%2.%3")
			text = rsub_repeatedly(text, "(ŋ)([k])([^lɾrɟyw" .. vowel .. separator ..  "])", "%1%2.%3")
			text = rsub_repeatedly(text, "([ɾr])([bkdfɡklmnpsʃtvz])([^lɾrɟyw" .. vowel .. separator ..  "])", "%1%2.%3")
			
			text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. ")(" .. C .. V .. ")", "%1.%2")
			text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. "+)(" .. C .. C .. V .. ")", "%1.%2")
			text = rsub_repeatedly(text, "(" .. C .. ")%.s(" .. C .. ")", "%1s.%2")
			
			-- Any aeo, or stressed iu, should be syllabically divided from a following aeo or stressed iu.
			text = rsub_repeatedly(text, "([aeo]" .. accent_c .. "*)([aeo])", "%1.%2")
			text = rsub_repeatedly(text, "([aeo]" .. accent_c .. "*)(" .. V .. AC .. ")", "%1.%2")
			text = rsub(text, "([iuə]" .. AC .. ")([aeo])", "%1.%2")
			text = rsub_repeatedly(text, "([iuə]" .. AC .. ")(" .. V .. AC .. ")", "%1.%2")
			text = rsub_repeatedly(text, "i(" .. accent_c .. "*)i", "i%1.i")
			text = rsub_repeatedly(text, "u(" .. accent_c .. "*)u", "u%1.u")
		
			text = rsub(text, "ĉ", "ch")
			text = rsub(text, "ŋ", "ng")
			text = rsub(text, "ʃ", "sh")
			text = rsub(text, "r", "rr")
			text = rsub(text, "ɾ", "r")
			text = removeAccents(text)
			
			text = rsub_repeatedly(text, "([.]+)", ".")
			text = rsub(text, "[.]?-[.]?", "-")
			text = rsub(text, "[‿]([^ ])", "|%1")
			text = rsub(text, "[.]([^ ])", "|%1")
		
			text = rsub(text, "([gq])([u])|([ei])", "%1%2%3")
			text = rsub(text, "([^ 0-9]?)([7])([^ 0-9]?)", "%1%3")
			text = rsub(text, "([|])+", "%1")
			
			-- remove # symbols at word and text boundaries
			text = rsub_repeatedly(text, "([.]?)#([.]?)", "")
			
			-- Fix Capitalization --
			local syllbreak = 0
			for i=1, #text do
			    if text:sub(i,i) == "|" and origtext:sub(i-syllbreak, i-syllbreak) ~= "." and origtext:sub(i-syllbreak, i-syllbreak) ~= "7" then
			    	syllbreak = syllbreak + 1
			    elseif origtext:sub(i-syllbreak, i-syllbreak) == text:sub(i,i):upper() then
			    	text = table.concat({text:sub(1, i-1), text:sub(i,i):upper(), text:sub(i+1)}) 
			    end
			end
			
			-- Fix hyphens --
			origtext = mw.title.getCurrentTitle().text
			
			if (table.concat(rsplit(origtext, "-")) ==  table.concat(rsplit(table.concat(rsplit(text, "|")), "-"))) then
				syllbreak = 0
				for i=1, #text do
				    if text:sub(i,i) == "|" then
				    	if origtext:sub(i-syllbreak, i-syllbreak) == "-" then
					    	text = table.concat({text:sub(1, i-1), "-", text:sub(i+1)}) 
					    else
					    	syllbreak = syllbreak + 1
					    end	
				    end
				end
			end
			
			text = rsplit(text, "|")
			return text
		end
		
		text = hyphenate(text)
		
		-- Determine whether manual hyphenation is given (more than one numbered argument is present), and
		-- categorize redundant hyphenations.
		if (#hyph_args == 1 and hyph_args[1] == mw.title.getCurrentTitle().text) or 
			(#hyph_args > 1 and m_table.deepEquals(text, hyph_args)) then
				table.insert(categories, ("%s terms with redundant hyphenations"):format(lang:getCanonicalName()))
		elseif #hyph_args > 1 then
			text = hyph_args
		end
		
		-- Store hyphenation(s) in hyph_data (passed to [[Module:hyphenation]]) and compute maximum hyph_data
		-- argument.
		local max_hyph_ct = 0
		for key, syllable in pairs(text) do
			if type(key) == "number" then
				hyph_data[tonumber(key)+1] = removeAccents(syllable)
				if tonumber(key)+1 > max_hyph_ct then
					max_hyph_ct = tonumber(key)+1
				end
			end
		end
		
		-- Separate the hyphenations and concatenate each one to form a word. Below, we check that each
		-- hyphenation matches the pagename and categorize into an error category if not.
		local hyph_check = {}
		for i=2, max_hyph_ct do
			if (hyph_data[i]) then
				if(hyph_check[#hyph_check] == nil) then
					table.insert(hyph_check, hyph_data[i])
				else
					hyph_check[#hyph_check] = hyph_check[#hyph_check] .. hyph_data[i]
				end
			else
				table.insert(hyph_check, "")
			end
		end
		
		for _, hyph_word in ipairs(hyph_check) do
			if (hyph_word ~= mw.title.getCurrentTitle().text) then
				table.insert(categories, ("%s terms with hyphenation errors"):format(lang:getCanonicalName()))	
			end
		end
		
		-- Actually hyphenate.
		output.syll = require("Module:hyphenation").hyphenate(hyph_data)
	end

	--IPA pronunciations--
	local IPA_args = args["IPA"]
	local IPA_data = {}
	local IPA_accent_list = {}
	local IPA_q_list = {}

	-- Accent group processing
	local accent_data = mw.loadData(accent_qualifier_data_module)
	local a_args = args["a"]

	-- Each accent parameter in a1=, a2= etc. is one or more comma-separated accents. Split on commas and
	-- canonicalize aliases.
	for i, accent in pairs(a_args) do
		if(tonumber(i)) then
			IPA_accent_list[i] = rsplit(trim(accent), "%s*,%s*")
			for j, alias in ipairs(IPA_accent_list[i]) do
				if accent_data.aliases[alias] then
					IPA_accent_list[i][j] = accent_data.aliases[alias]
				end
			end
		end
	end

	-- Qualifier processing
	local q_args = args["q"]

	-- Split qualifiers on commas and store in IPA_q_list[].
	for i, qual in pairs(q_args) do
		if(tonumber(i)) then
			IPA_q_list[i] = rsplit(trim(qual), "%s*,%s*")
		end
	end

	-- Either use the first parameter or the entry title if no IPA1 arg given.
	if not IPA_args[1] and #args[1] <= 1 then
		IPA_args[1] = args[1][1] or mw.title.getCurrentTitle().text
	end

	-- Process each respelling, convert to IPA and store the phonemic and phonetic pronunciations in a two-element list.
	for i=1, #IPA_args do
		local input = IPA_args[i]
		local IPA_format = {}

		if input == "+" then
			input = mw.title.getCurrentTitle().text
		end

		--Allows copy of //, [] format
		if input:match("/([^/]+)/%s*,%s*%[([^%[%]]+)%]") then
			rsub(input, "/([^/]+)/%s*,%s*%[([^%[%]]+)%]", 
			function(phonemic, phonetic)
				table.insert(IPA_format, { pron = "/" .. phonemic .. "/" })
				table.insert(IPA_format, { pron = "[" .. phonetic .. "]" })
			end)
		else
			local IPA_result = export.IPA(input)
			table.insert(IPA_format, { pron = "/" .. IPA_result["phonemic"] .. "/" })
			table.insert(IPA_format, { pron = "[" .. IPA_result["phonetic"] .. "]" })
		end

		table.insert(IPA_data, IPA_format)
	end

	output.IPA = IPA_data

	-- Audio processing
	local audio_args = args["audio"]
	local audioq_args = args["audioq"]
	local audio_output = {}

	-- Format each specified audio file using [[Module:audio]].
	for i, audio in pairs(audio_args) do
		if(tonumber(i)) then
			audio_output[i] = require("Module:audio").format_audios({
				lang=lang, 
				audios = {{
					file = audio_args[i],
					qualifiers = audioq_args[i] and {audioq_args[i]} or nil
				}},
				caption = "Audio"
			})
		end
	end

	local final_pron_output = {}
	local IPA_object_list = {}
	local IPA_object_groups = {}
	local one_syllable = false
	local accent_no_count = {"colloquial", "obsolete", "relaxed"}
	local accent_order = m_table.invert({
		"Standard Tagalog",
		"dialectal",
		"Bataan", 
		"Bulacan", 
		"Nueva Ecija", 
		"Southern Tagalog", 
		"Cavite", 
		"Laguna",
		"Batangas",
		"Teresa-Morong", 
		"Tayabas", 
		"Marinduque", 
		"Old Tagalog"
	})

	output.rhymes = {}

	-- Gather pronunciation properties for each respelling. 
	for i=1, #output.IPA do
		local IPA_object = {
			data = output.IPA[i],
			audio = audio_output[i],
			accent = IPA_accent_list[i],
			qualifier = IPA_q_list[i],
			syll_count = true,
			exclude_rhyme = false
		}

		if not IPA_object.accent then
			IPA_object.accent = {"Standard Tagalog"}
		end

		-- If multiple accents given, sort according to the accent order listed above. Unrecognized accents go
		-- at the end.
		table.sort(IPA_object.accent, 
			function(a, b)
				-- 100 is an arbitrary high number for sorting
				local acc_a = accent_order[a] or 100
				local acc_b = accent_order[b] or 100
				return acc_a < acc_b
			end
		)

		-- If more than one respelling given, then if any accent or qualifier has the words 'colloquial',
		-- 'obsolete' or 'relaxed' in them, don't generate a rhyme or a '#-syllable word' category.
		-- FIXME: This check should be more stringent as it will wrongly catch cases where the qualifier specifies
		-- a definition, which includes one of the above words.
		if #output.IPA > 1 then
			for _, accent in ipairs(IPA_object.accent) do
				for _, uncounted in ipairs(accent_no_count) do
					if accent:match(uncounted) then
						IPA_object.syll_count = false
						IPA_object.exclude_rhyme = true
						break
					end
				end
			end

			if IPA_object.qualifier then
				for _, qual in ipairs(IPA_object.qualifier) do
					for _, uncounted in ipairs(accent_no_count) do
						if qual:match(uncounted) then
							IPA_object.syll_count = false
							IPA_object.exclude_rhyme = true
							break
						end
					end
				end
			end
		end
		table.insert(IPA_object_list, IPA_object)
	end

	-- If the phonemic form of any generated IPA contains /f/, /v/ or /z/, augment the IPA's with an additional
	-- entry where /f/ -> /p/, /v/ -> /b/ and /z/ -> /s/, with a qualifier "more native-sounding" appended to the
	-- existing qualifiers.
	local IPA_count = 1
	while IPA_count <= #IPA_object_list do
		local skip = 0
		-- F, V, Z
		if IPA_object_list[IPA_count].data[1]["pron"]:find("[fvz]") then
			if not (IPA_object_list[IPA_count].qualifier) then
				IPA_object_list[IPA_count].qualifier = {}
			end

			local fvz_qual = m_table.shallowcopy(IPA_object_list[IPA_count].qualifier)
			local fvz_caption = "more native-sounding"
			if not (m_table.tableContains(fvz_qual, fvz_caption)) then
				table.insert(fvz_qual, fvz_caption)
			end
			local fvz_charmap = { ["f"] = "p", ["v"] = "b", ["z"] = "s"}
			table.insert(IPA_object_list, IPA_count+1, {
				data = {
					{["pron"] = rsub(IPA_object_list[IPA_count].data[1]["pron"], "[fvz]", fvz_charmap)},
					{["pron"] = rsub(IPA_object_list[IPA_count].data[2]["pron"], "[fvz]", fvz_charmap)}
				},
				audio = nil,
				accent = IPA_object_list[IPA_count].accent,
				qualifier = fvz_qual,
				syll_count = true,
				exclude_rhyme = false
			})
			skip = skip + 1
		end
		IPA_count = IPA_count + 1 + skip
	end

	-- If the phonemic form of any generated IPA contains a non-final word ending in a glottal stop (FIXME: do
	-- we want to restrict this to non-final words and only to word-final glottal stops?), augment the IPA's with
	-- an additional entry where the phonemic glottal stop becomes optional and the phonetic glottal stop is
	-- converted to a long vowel.
	local IPA_count = 1
	while IPA_count <= #IPA_object_list do
		local skip = 0
		-- Manila glottal stop elision
		if IPA_object_list[IPA_count].data[1]["pron"]:find("ʔ ") and m_table.contains(IPA_object_list[IPA_count].accent, "Standard Tagalog") then
			if not (IPA_object_list[IPA_count].qualifier) then
				IPA_object_list[IPA_count].qualifier = {}
			end

			local gl_qual = m_table.shallowcopy(IPA_object_list[IPA_count].qualifier)
			local gl_caption = "with glottal stop elision"
			if not (m_table.tableContains(gl_qual, gl_caption)) then
				table.insert(gl_qual, gl_caption)
			end
			table.insert(IPA_object_list, IPA_count+1, {
				data = {
					{["pron"] = rsub(IPA_object_list[IPA_count].data[1]["pron"], "ʔ ", "(ʔ) ")},
					{["pron"] = rsub(IPA_object_list[IPA_count].data[2]["pron"], "ʔ ", "ː ")}
				},
				audio = nil,
				accent = IPA_object_list[IPA_count].accent,
				qualifier = gl_qual,
				syll_count = false,
				exclude_rhyme = true
			})
			skip = skip + 1
		end
		IPA_count = IPA_count + 1 + skip
	end

	IPA_object_list = m_table.removeDuplicates(IPA_object_list)

	-- Group pronunciations by the associated accent set (concatenated accents), and then sort the groups by
	-- accent according to the order specified above in accent_order, where differences in earlier accents count
	-- more than differences in later accents.
	for _, IPA_obj in ipairs(IPA_object_list) do
		local group_index = table.concat(IPA_obj.accent, ",")
		if IPA_object_groups[group_index] == nil then
			IPA_object_groups[group_index] = {}
		end
		table.insert(IPA_object_groups[group_index], IPA_obj)
	end

	local IPA_group_names = m_table.keysToList(IPA_object_groups)
	table.sort(IPA_group_names, 
		function(a,b)
			local accents_a = rsplit(a, ",")
			local accents_b = rsplit(b, ",")
			local count = math.max(#accents_a, #accents_b)
			for i=1, count do
				if(accents_a[i] ~= accents_b[i]) then
					-- 100 is an arbitrary high number for sorting
					local acc_a = accents_a[i] and (accent_order[accents_a[i]] or 100) or 0
					local acc_b = accents_b[i] and (accent_order[accents_b[i]] or 100) or 0
					return acc_a < acc_b
				end
			end
		end
	)

	-- Get the rhyme by truncating everything up through the last stress mark + any following consonants, and remove
	-- syllable boundary markers.
	-- NOTE: This works because the phonemic vowels are just [aeiou] possibly with diacritics that are separate
	-- Unicode chars. If we want to handle things like ɛ or ɔ we need to add them to `vowel`.
	local function convert_phonemic_to_rhyme(rhyme)
		rhyme = rsplit(rhyme, " ")
		rhyme = rhyme[#rhyme]
		rhyme = rsub(rhyme, "[%[%]/.]", "")
		rhyme = rsub(rhyme, ".*[ˌˈ]", "")
		rhyme = rsub(rhyme, "^[^" .. vowel .. "]*", "")
		return rhyme
	end

	local clean_up_rhyme = {}
	local rhyme_order = 1

	local m_data = mw.loadData('Module:IPA/data')
	m_syllables = require('Module:syllables')
	local langcode = lang:getCode()

	-- Loop over the sorted accent groups (see above).
	for idx, ag_ordered in ipairs(IPA_group_names) do
		local accent_group_data = IPA_object_groups[ag_ordered]
		local accent_row = {}
		local row_bullet = "*"
		table.insert(accent_row, "* " .. (frame:expandTemplate { title = "accent", args = rsplit(ag_ordered, ",")} or ""))

		if (#accent_group_data ~= 1) then
			row_bullet = "**"
		end

		-- Loop over the pronunciations in an accent group.
		for _, a_obj in ipairs(accent_group_data) do
			-- Determine the pronunciation to use for rhyme determination and get the number of syllables by counting
			-- vowels, according to the Tagalog specs in [[Module:IPA/data]]. Store in `syll_count` (used later on when
			-- generating a rhymes category). Set `one_syllable` if only one syllable. FIXME: This is duplicating the
			-- logic in [[Module:syllable]] and [[Module:IPA]] that computes the syllable count for generating a
			-- 'Tagalog #-syllable words' category.
			local rhymes_use = ""
			if m_data.langs_to_generate_syllable_count_categories[langcode] then
				if m_data.langs_to_use_phonetic_notation[langcode] then
					rhymes_use = a_obj.data[2]["pron"]
				else
					rhymes_use = a_obj.data[1]["pron"]
				end
				if rhymes_use and a_obj.syll_count and not require("Module:string utilities").find(rhymes_use, "[ ‿]") then
					local syllable_count = m_syllables.getVowels(rhymes_use, lang)
					if syllable_count then
						a_obj.syll_count = syllable_count
						if a_obj.syll_count <= 1 then
							one_syllable = true
						end
					end
				end
			end

			-- If we couldn't set `one_syllable`, presumably this means there aren't any vowels (?); assume true if
			-- we've been instructed to determine the syllable count.
			if type(a_obj.syll_count) == "boolean" and a_obj.syll_count == true then
				one_syllable = true
			end

			-- Format generated phonemic and phonetic IPA using [[Module:IPA]].
			a_obj.data = m_IPA.format_IPA_full(lang, a_obj.data, nil, nil, nil, not a_obj.syll_count)
			-- Format qualifier.
			a_obj_q = require("Module:qualifier").format_qualifier(a_obj.qualifier)
			-- If there's only one pronunciation in this accent group, it goes on the same line as the accent text;
			-- otherwise it goes on a separate line, indented (with two bullets, as the accent text line has one
			-- bullet).
			if (#accent_group_data == 1) then
				accent_row[#accent_row] = accent_row[#accent_row] .. " " .. a_obj.data
			else
				table.insert(accent_row, row_bullet .. " " .. a_obj.data)
			end

			-- Add qualifier to output.
			if(a_obj.qualifier) then
				accent_row[#accent_row] = accent_row[#accent_row] .. " " .. a_obj_q
			end

			-- Add audio line to output.
			if(a_obj.audio) then
				table.insert(accent_row, row_bullet .. " " ..  a_obj.audio)
			end

			-- Generate the arguments to pass to [[Module:rhymes]].
			local get_rhyme = convert_phonemic_to_rhyme(rhymes_use)
			local combined_qual = m_table.shallowcopy(a_obj.accent)
			if #IPA_group_names == 1 then
				combined_qual = {}
			elseif combined_qual[1] == "Standard Tagalog" then
				table.remove(combined_qual,1)
			end
			if(a_obj.qualifier) then
				m_table.extendList(combined_qual, a_obj.qualifier)
				combined_qual = m_table.removeDuplicates(combined_qual or {})
			end

			if not a_obj.exclude_rhyme then
				if not (clean_up_rhyme[get_rhyme]) then
					clean_up_rhyme[get_rhyme] = {
						num_syl = tonumber(a_obj.syll_count) and {a_obj.syll_count} or nil,
						qualifiers = combined_qual,
						order = rhyme_order
					}
					rhyme_order = rhyme_order + 1
				else
					if (clean_up_rhyme[get_rhyme].num_syl) and tonumber(a_obj.syll_count) then
						table.insert(clean_up_rhyme[get_rhyme]["num_syl"], a_obj.syll_count)
					elseif not (clean_up_rhyme[get_rhyme].num_syl) and tonumber(a_obj.syll_count) then
						clean_up_rhyme[get_rhyme].num_syl = {a_obj.syll_count}
					end

					if (clean_up_rhyme[get_rhyme].qualifiers) and #clean_up_rhyme[get_rhyme].qualifiers > 0 then
						if not (combined_qual) or (#combined_qual == 0) then
							clean_up_rhyme[get_rhyme].qualifiers = nil
						else
							m_table.extendList(clean_up_rhyme[get_rhyme].qualifiers, combined_qual )
						end
					end
				end
			end
		end

		table.insert(final_pron_output, table.concat(accent_row, "\n"))
	end

	-- Cleanup Rhymes --
	for rhy, rhyval in pairs(clean_up_rhyme) do
		if rhy ~= "" then
			table.insert(output.rhymes, {
				rhyme=rhy,
				num_syl = rhyval["num_syl"],
				qualifiers = rhyval["qualifiers"] and m_table.removeDuplicates(rhyval["qualifiers"]) or nil,
				order = rhyval["order"]
			})
		end
	end

	if #output.rhymes > 0 then
		output.rhymes = m_table.removeDuplicates(output.rhymes)
		table.sort(output.rhymes, function(a,b)
			return a.order < b.order
		end)

		for _, pron_rhym in ipairs(output.rhymes) do
			local penult = false
			local glottal = false
			local pron_cat = ""
			if(m_syllables.getVowels(pron_rhym.rhyme, lang) == 2) then
				penult = true
			end
			if(pron_rhym.rhyme:find("ʔ$")) then
				glottal = true
			end

			if penult and glottal then
				pron_cat = "malumi"
			elseif penult then
				pron_cat = "malumay"
			elseif glottal then
				pron_cat = "maragsa"
			else
				pron_cat = "mabilis"
			end
			table.insert(categories, ("%s terms with %s pronunciation"):format(lang:getCanonicalName(), pron_cat))
		end

		categories = m_table.removeDuplicates(categories)

		if (args["norhymes"] == 0) then
			table.insert(final_pron_output, "*" .. require("Module:rhymes").format_rhymes{
				lang=lang,
				rhymes=output.rhymes
			})
		end
	end

	-- Homophone processing
	local hmp_list = {}
	local hmp_args = args["hmp"]
	local hmpq_args = args["hmpq"]

	for i, hmp in ipairs(hmp_args) do
		if(tonumber(i)) then
			table.insert(hmp_list, {
				term = hmp_args[i],
				qualifiers = hmpq_args[i] and {hmpq_args[i]} or nil
			}) 
		end
	end

	if #hmp_list > 0 then
		table.insert(final_pron_output, "*" .. 	require("Module:homophones").format_homophones({
			lang=lang, 
			homophones=hmp_list
		}))
	end

	if (args["nohyph"] == 0) then
		if maxn(hyph_data) > #hyph_data or not ( 
			(maxn(hyph_data) <= 2 and not mw.title.getCurrentTitle().text:find("[-]")) or
			(one_syllable and not mw.title.getCurrentTitle().text:find("[ -]"))
		) then
			table.insert(final_pron_output, "* " .. output.syll) 
		end
	end

	table.insert(final_pron_output, require("Module:utilities").format_categories(categories, lang))

	-- Trim final spaces
	while(final_pron_output[#final_pron_output] == "") do
		table.remove(final_pron_output, #final_pron_output)
	end

	return table.concat(final_pron_output, "\n")
end

return export
