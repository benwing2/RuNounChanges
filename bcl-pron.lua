-- Based on [[module:tl-pron]] by TagaSanPedroAko, in turn based on [[module:es-pronunc]] by Benwing2. 
-- Adaptation by Mar vin kaiser and TagaSanPedroAko.

local export = {}

local m_IPA = require("Module:IPA")

local lang = require("Module:languages").getByCode("bcl")

local u = require("Module:string/char")
local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local rsplit = mw.text.split
local ulower = mw.ustring.lower

local AC = u(0x0301) -- acute =  ́
local GR = u(0x0300) -- grave =  ̀
local CFLEX = u(0x0302) -- circumflex =  ̂
local TILDE = u(0x0303) -- tilde =  ̃
local DIA = u(0x0308) -- diaeresis =  ̈
local MACRON = u(0x0304) -- macron 

local vowel = "aeəiouàèìòù" -- vowel
local V = "[" .. vowel .. "]"
local accent = AC .. GR .. CFLEX .. MACRON 
local accent_c = "[" .. accent .. "]"
local stress_c = "[" .. AC .. GR .. "]"
local ipa_stress = "ˈˌ"
local ipa_stress_c = "[" .. ipa_stress .. "]"
local separator = accent .. ipa_stress .. "# ."
local separator_c = "[" .. separator .. "]"
local C = "[^" .. vowel .. separator .. "]" -- consonant

local unstressed_words = require("Module:table").listToSet({
	"ang", "an", "sa", "nin", "si", "ni", "kay", -- case markers. "Nang" here is for written "ng", but can also work with nang as in the contraction na'ng and the conjunction "nang"
	"a", "ar", "ba", "bi", "da", "di", "e", "ef", "eks", "dyi", "i",  "jey", "key", "em", "ma", "en", "pi", "ra", "es", "ta", "ti", "u", "vi", "wa", "way", "ya", "yu", "zey", "zi", -- letter names (abakada and modern Filipino)
	"ko", "ta", "mi", "mo", "ka", --single-syllable personal pronouns
	"na", "nga", -- also temporal particle
    "daw", "ga", "ha", "pa", -- particles
	"di7", "de7", -- negation words
	"pag", "kung", "kung", -- subordinating conjunctions
	"at", "o", -- coordinating conjunctions
	"hay", -- interjections
	"de", "del", "el", "la", "las", "los", "sur", -- in some Spanish-derived terms and names
	"-an", "-han", "hi-", "-hin", "hin-", "hing-", "-in", "-in-", "mag-", "mang-", "-on", "pa-", "pag-", "pang-"-- affixes
})

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

function export.IPA(text, phonetic)
	local debug = {}

	text = ulower(text or mw.title.getCurrentTitle().text)
	-- decompose everything but ñ and ü
	text = mw.ustring.toNFD(text)
	text = rsub(text, "." .. "[" .. TILDE .. DIA .. GR .."]", {
		["a" .. GR] = "à",
		["e" .. GR] = "è",
		["i" .. GR] = "ì",
		["o" .. GR] = "ò",
		["u" .. GR] = "ù",
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
	-- monosyllabic words (e.g. [[ang]], [[nin]], [[si]], [[nga]], etc.) without stress marks be
	-- unstressed.
	local words = rsplit(text, " ")
	for i, word in ipairs(words) do
		if rfind(word, "%-$") and not rfind(word, accent_c) or unstressed_words[word] then
			-- add macron to the last vowel not the first one
			-- adding the macron after the 'u'
			words[i] = rsub(word, "^(.*" .. V .. ")", "%1" .. MACRON)
		end
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

	table.insert(debug, text)

	-- handle certain combinations; ch, ly ng and sh handling needs to go first
	text = rsub(text, "([t]?)ch", "ts") --not the real sound
	text = rsub(text, "([n]?)g̃", "ŋ") -- Spanish spelling support
    text = rsub(text, "ly", "ʎ")
	text = rsub(text, "ng", "ŋ")
	text = rsub(text, "sh", "ʃ")

	--x
	text = rsub(text, "([#])x([aeëiou])", "%1s%2")
	text = rsub(text, "x", "ks")
	
	--ll
	text = rsub(text, "ll([i]?)([aeëiou])", "ʎ%2")

	--c, gü/gu+e or i, q
	text = rsub(text, "c([iey])", "s%1")
	text = rsub(text, "([aeëiou])gü([ie])", "%1ɡw%2")
	text = rsub(text, "gü([ie])", "ɡuw%1")
	text = rsub(text, "gu([ie])", "ɡ%1")
	text = rsub(text, "qu([ie])", "k%1")
	text = rsub(text, "ü", "u") 
	text = rsub(text, "ë", "ə") 
	
	--alphabet-to-phoneme
	text = rsub(text, "[cfgjñqrvz7]",
	--["g"]="ɡ":  U+0067 LATIN SMALL LETTER G → U+0261 LATIN SMALL LETTER SCRIPT G
		{ ["c"] = "k", ["f"] = "p", ["g"] = "ɡ", ["j"] = "ĵ", ["ñ"] = "ɲ", ["q"] = "k", ["r"] = "ɾ", ["v"] = "b", ["z"] = "s", ["7"] = "ʔ"})

	-- trill in rr
	text = rsub(text, "ɾɾ", "r")

    -- ts
	text = rsub(text, "ts", "ĉ") --not the real sound

	table.insert(debug, text)

	--determining whether "y" is a consonant or a vowel
	text = rsub(text, "y(" .. V .. ")", "ɟ%1") -- not the real sound
	text = rsub(text,"y([ˈˌ.]*)([bćĉdfɡhjĵklmnɲŋpɾrsʃtvwɟzʔ" .. vowel .. "])","i%1%2")
	text = rsub(text, "y#", "i")
	text = rsub(text, "w(" .. V .. ")","w%1")
	text = rsub(text,"w([ˈˌ]?)([bćĉdfɡjĵklmnɲŋpɾrsʃtvwɟzʔ])","u%1%2")
	text = rsub(text, "w#","u")

	table.insert(debug, text)
	
	-- Add glottal stop for words starting with vowel
	text = rsub(text, "([#])([aeëiou])", "%1ʔ%2")

	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*)(" .. C .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. ")(" .. C .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. "+)(" .. C .. C .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. C .. ")%.s(" .. C .. ")", "%1s.%2")
	-- Any aeo, or stressed iu, should be syllabically divided from a following aeo or stressed iu.
	text = rsub_repeatedly(text, "([aeo]" .. accent_c .. "*)([aeo])", "%1.%2")
	text = rsub_repeatedly(text, "([aeo]" .. accent_c .. "*)(" .. V .. stress_c .. ")", "%1.%2")
	text = rsub(text, "([iuə]" .. stress_c .. ")([aeo])", "%1.%2")
	text = rsub_repeatedly(text, "([iuə]" .. stress_c .. ")(" .. V .. stress_c .. ")", "%1.%2")
	text = rsub_repeatedly(text, "i(" .. accent_c .. "*)i", "i%1.i")
	text = rsub_repeatedly(text, "u(" .. accent_c .. "*)u", "u%1.u")

	table.insert(debug, text)

	local accent_to_stress_mark = { [AC] = "ˈ", [CFLEX] = "ˈʔ", [MACRON] = ""}

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
			if #syllables > 1 and rfind(word, "[^aeiouəàèìòùʔbcĉdfɡghjɟĵklmnñŋpqrɾstvwxz#]#") or #syllables == 1 and rfind(word, "[aeiouàèìòù]") 		then
				syllables[#syllables] = "ˈ" .. syllables[#syllables]
			elseif #syllables >= 2 then
				syllables[#syllables - 1] = "ˈ" .. syllables[#syllables - 1]
			end
		end
	end

	local words = rsplit(text, " ")
	for j, word in ipairs(words) do
		-- accentuation
		local syllables = rsplit(word, "%.")

			accent_word(word, syllables)

		-- Reconstruct the word.
		words[j] = table.concat(syllables, phonetic and "." or "")
	end

	text = table.concat(words, " ")

	-- suppress syllable mark before IPA stress indicator
	text = rsub(text, "%.(" .. ipa_stress_c .. ")", "%1")
	--make all primary stresses but the last one be secondary
	text = rsub_repeatedly(text, "ˈ(.+)ˈ", "ˌ%1ˈ")

    table.insert(debug,text)
    
    --"ph" digraph be "f"
    text = rsub(text,"ph([aeiouəàèìòù])","f%1")
   
    --correct final glottal stop placement
    text = rsub(text,"([ˈˌ])ʔ([#]*)([ʔbĉćdfɡhĵɟklmnŋɲpɾrsʃtvwz])([aeiouə])","%1%2%3%4ʔ")

    --vowels with grave to vowel+glottal stop
    text = rsub(text,"à","aʔ")
    text = rsub(text,"è","eʔ")
    text = rsub(text,"ì","iʔ")
    text = rsub(text,"ò","oʔ")
    text = rsub(text,"ù","uʔ")

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

    table.insert(debug, text)

	--phonetic transcription
	if phonetic then

       	table.insert(debug, text)

        --Turn phonemic diphthongs to phonetic diphthongs

		text = rsub(text, "([aāeəouū])j", "%1ɪ̯")
		text = rsub(text, "([aāeəiīo])w", "%1ʊ̯")

        table.insert(debug, text)

        --Combine consonants (except H) followed by I/U and certain stressed vowels
	    text = rsub(text,"([bkdfɡlmnpɾstvz])i([ˈˌ])([āeəoū])","%2%1ɟ%3")
	    text = rsub(text,"([bkdfɡlmnpɾstvz])u([ˈˌ])([āeəīo])","%2%1w%3")
	    text = rsub(text,"([h])u([ˈˌ])([eəī])","%2%1w%3") -- only for hu with (ei) combination

       	table.insert(debug, text)
       	
       	-- foreign s consonant clusters
	    text = rsub(text,"([ˈˌ.]?)([#]*)([.]?)([s])([ʔbćĉdfɡhĵklmnŋpɾrt])([ɟlnɾst]?)([aāeəiɪ̯īouʊ̯ū])","%2.ʔi%4%1%5%6%7")
	    
	    text = rsub(text,"([ˈˌ])([ʔbćĉdfɡhĵɟklmnŋpɾrstwvz]?)([ɟlnɾst]?)([a])","%1%2%3ā")
		text = rsub(text,"([ˈˌ])([ʔbćĉdfɡhĵɟklmnŋpɾrstwvz]?)([ɟlnɾst]?)([i])","%1%2%3ī")
		text = rsub(text,"([ˈˌ])([ʔbćĉdfɡhĵɟklmnŋpɾrstwvz]?)([ɟlnɾst]?)([u])","%1%2%3ū")
	    
	    table.insert(debug, text)

    	text = rsub(text,"([nŋ])([ˈˌ# .]*[bfpv])","m%2")
    	text = rsub(text,"([ŋ])([ˈˌ# .]*[dlstz])","n%2")
        text = rsub(text,"d([ˈˌ.])ɟ","%1ĵ") --/d/ before /j/
        text = rsub(text,"dɟ([aāeəɪ̯iīoʊ̯uū])","ĵ%1") --/d/ before /j/
        text = rsub(text,"n([ˈˌ.])k","ŋ%1k") -- /n/ before /k/ (some proper nouns)
        text = rsub(text,"n([ˈˌ.])ɡ","ŋ%1ɡ") -- /n/ before /ɡ/ (some proper nouns and loanwords)
        --text = rsub(text,"n([ˈˌ.])h","ŋ%1h") -- /n/ before /h/ (some proper nouns)
        --text = rsub(text,"n([ˈˌ.])m","m%1m") -- /n/ before /m/
        text = rsub(text,"n([ˈˌ.])ɟ","%1ɲ") -- /n/ before /j/
        text = rsub(text,"s([ˈˌ.])ɟ","%1ʃ") -- /s/ before /j/
        text = rsub(text,"t([ˈˌ.])ɟ","%1ĉ") -- /t/ before /j/
        text = rsub(text,"t([ˈˌ.])s([aāeəiīouū])","%1ć%2") -- /t/ before /s/
        text = rsub(text,"t([.])s","ts") -- /t/ before /s/
        text = rsub(text,"([ˈˌ.])d([ɟj])([aāeəiīouū])","%1ĵ%3") -- /dj/ before any vowel following stress
        text = rsub(text,"([ˈˌ.])n([ɟj])([aāeəiīouū])","%1ɲ%3") -- /nj/ before any vowel following stress
        text = rsub(text,"([ˈˌ.])s([ɟj])([aāeəiīouū])","%1ʃ%3") -- /sj/ before any vowel following stress
        text = rsub(text,"([ˈˌ.])t([ɟj])([aāeəiīouū])","%1ĉ%3") -- /tj/ before any vowel following stress
        -- text = rsub(text,"([o])([m])([.]?)([ˈ]?)([pb])","u%2%3%4%5") -- /o/ before /mb/ or /mp/

 --turn phonemic consonants to Bikol Central dental consonants

       	table.insert(debug, text)

	    text = rsub(text,"d","d̪")
	    text = rsub(text,"l","l̪")
	    text = rsub(text,"n","n̪")

       	table.insert(debug, text)

        --delete temporary macron in /a/, /i/ and /u/

	    text = rsub(text,"ā","a")
	    text = rsub(text,"ī","i")
	    text = rsub(text,"ū","u")

    end

	table.insert(debug, text)

    --delete temporary macron in /a/, /i/ and /u/

	    text = rsub(text,"ā","a")
	    text = rsub(text,"ī","i")
	    text = rsub(text,"ū","u")

	-- convert fake symbols to real ones
    local final_conversions = {
		["ĉ"] = "t͡ʃ", -- fake "ch" to real "ch"
		["ɟ"] =  "j", -- fake "y" to real "y"
        ["ĵ"] = "d͡ʒ" -- fake "j" to real "j"
	}

    local final_conversions_phonetic = {
		["ĉ"] = "t͡ʃ", -- fake "ch" to real "ch"
		["ć"] = "t͡s", -- fake "t.s" to real "t.s"
		["ɟ"] =  "j", -- fake "y" to real "y"
        ["ĵ"] = "d͡ʒ" -- fake "j" to real "j"
	}

	if phonetic then
	text = rsub(text, "[ĉćɟĵ]", final_conversions_phonetic)
    	end
	text = rsub(text, "[ĉɟĵ]", final_conversions)

	-- remove # symbols at word and text boundaries
	text = rsub(text, "#([.]?)", "")
	
	-- resuppress syllable mark before IPA stress indicator
	text = rsub(text, "%.(" .. ipa_stress_c .. ")", "%1")

	-- Do not have multiple syllable break consecutively
	text = rsub_repeatedly(text, "([.]+)", ".")
	text = rsub_repeatedly(text, "([.]?)(" .. ipa_stress_c .. ")([.]?)", "%2")

	return mw.ustring.toNFC(text)
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

	table.insert(results, { pron = "/" .. export.IPA(text, false) .. "/" })
	table.insert(results, { pron = "[" .. export.IPA(text, true) .. "]" })
	
	local pre = args.pre and args.pre .. " " or ""
	local bullet = (args.bullets ~= 0) and "* " or ""
	
	return bullet .. pre .. m_IPA.format_IPA_full { lang = lang, items = results }
end

return export
