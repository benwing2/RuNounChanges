-- Based on [[Module:es-pronunc]] by Benwing2. 
-- Adaptation by TagaSanPedroAko, Improved by Ysrael214.

local export = {}

local m_IPA = require("Module:IPA")
local m_str_utils = require("Module:string utilities")
local m_table = require("Module:table")

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

-- ĵ, ɟ and ĉ are used internally to represent [d͡ʒ], [j] and [t͡ʃ]
--

function export.IPA(text)
	local debug = {}

	text = ulower(text or mw.title.getCurrentTitle().text)
	-- decompose everything but ñ and ü
	text = toNFD(text)
	text = rsub(text, "." .. "[" .. TILDE .. DIA .. "]", {
		["n" .. TILDE] = "ñ",
		["u" .. DIA] = "ü",
		["e" .. DIA] = "ë",
	})
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

function export.show_full(frame)
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
	local multiple_hyph = false
	
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
		
		if (#hyph_args == 1 and hyph_args[1] == mw.title.getCurrentTitle().text) or 
			(#hyph_args > 1 and m_table.deepEquals(text, hyph_args)) then
				table.insert(categories, ("%s terms with redundant hyphenations"):format(lang:getCanonicalName()))
		elseif #hyph_args > 1 then
			text = hyph_args
		end
		
		local max_hyph_ct = 0
		for key, syllable in pairs(text) do
			if type(key) == "number" then
				hyph_data[tonumber(key)+1] = removeAccents(syllable)
				if tonumber(key)+1 > max_hyph_ct then
					max_hyph_ct = tonumber(key)+1
				end
			end
		end
		
		-- Hyphenation Error Checking
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
		
		output.syll = require("Module:hyphenation").hyphenate(hyph_data)
	end

	--IPA pronunciations--
	local IPA_args = args["IPA"]
	local IPA_data = {}
	local IPA_accent_list = {}
	local IPA_q_list = {}

	-- Accent group processing
	local accent_data = mw.loadData("Module:accent qualifier/data")
	local a_args = args["a"]

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

	for i, qual in pairs(q_args) do
		if(tonumber(i)) then
			IPA_q_list[i] = rsplit(trim(qual), "%s*,%s*")
		end
	end
	
	-- Either use the first parameter or the entry title if no IPA1 arg given.
	if not IPA_args[1] and #args[1] <= 1 and not multiple_hyph then
		IPA_args[1] = args[1][1] or mw.title.getCurrentTitle().text	
	end

	-- Start IPA processing
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
	
	---Convert to IPA object
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
		
		-- Sort accent order
		table.sort(IPA_object.accent, 	
			function(a, b)
				-- 100 is an arbitrary high number for sorting
				local acc_a = accent_order[a] or 100
				local acc_b = accent_order[b] or 100
				return acc_a < acc_b
			end		
		)
		
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
	
	-- Automatic additional IPA
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
	
	-- Order by group
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

	for idx, ag_ordered in ipairs(IPA_group_names) do
		local accent_group_data = IPA_object_groups[ag_ordered]
		local accent_row = {}
		local row_bullet = "*"
		table.insert(accent_row, "* " .. (frame:expandTemplate { title = "accent", args = rsplit(ag_ordered, ",")} or ""))
		
		if (#accent_group_data ~= 1) then
			row_bullet = "**"
		end
		
		for _, a_obj in ipairs(accent_group_data) do
			-- Get syllable count	
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
			
			if type(a_obj.syll_count) == "boolean" and a_obj.syll_count == true then
				one_syllable = true
			end
			
			a_obj.data = m_IPA.format_IPA_full(lang, a_obj.data, nil, nil, nil, not a_obj.syll_count)
			a_obj_q = require("Module:qualifier").format_qualifier(a_obj.qualifier)
			if (#accent_group_data == 1) then
				accent_row[#accent_row] = accent_row[#accent_row] .. " " .. a_obj.data
			else
				table.insert(accent_row, row_bullet .. " " .. a_obj.data)	
			end
			
			if(a_obj.qualifier) then
				accent_row[#accent_row] = accent_row[#accent_row] .. " " .. a_obj_q
			end
				
			if(a_obj.audio) then
				table.insert(accent_row, row_bullet .. " " ..  a_obj.audio)
			end
			
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
