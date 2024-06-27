-- Based on [[Module:es-pronunc]] by Benwing2. 
-- Adaptation by TagaSanPedroAko. Some code based on [[Module:ast-IPA]].

local export = {}

local pron_utilities_module = "Module:pron utilities"

local lang = require("Module:languages").getByCode("pam")

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
local CAR = u(0x030C) -- caron, placeholder for unstressed -- 

local vowel = "aeiouəɪʊ" -- vowel
local V = "[" .. vowel .. "]"
local W = "[jw]" -- glide
local accent = AC .. GR .. CFLEX .. CAR
local accent_c = "[" .. accent .. "]"
local stress_c = "[" .. AC .. GR .. "]"
local ipa_stress = "ˈˌ"
local ipa_stress_c = "[" .. ipa_stress .. "]"
local separator = accent .. ipa_stress .. "# ."
local separator_c = "[" .. separator .. "]"
local C = "[^" .. vowel .. separator .. "]" -- consonant

local unstressed_words = require("Module:table").listToSet({ --feel free to add more unstressed words
	"ing", "ning", "king", "si", "ni", -- case markers
	"de", "del", --particles in Spanish-derived surnames
	"na", "a"
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

-- ĵ, ɟ and ć are used internally to represent [d͡ʒ], [j] and [t͡ʃ]
--

function export.IPA(text, phonetic)
	local debug = {}

	text = ulower(text)
	-- decompose everything but ñ and ü
	text = mw.ustring.toNFD(text)
	text = rsub(text, "." .. "[" .. TILDE .. DIA .. "]", {
		["n" .. TILDE] = "ñ",
		["u" .. TILDE] = "ü",
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
	-- monosyllabic words (e.g. [[ing]], [[ning]], [[king]], [[si]], etc.) without stress marks be
	-- unstressed.
	local words = rsplit(text, " ")
	for i, word in ipairs(words) do
		if rfind(word, "%-$") and not rfind(word, accent_c) or unstressed_words[word] then
			-- add CAR to the last vowel not the first one
			-- adding the CAR after the 'u'
			words[i] = rsub(word, "^(.*" .. V .. ")", "%1" .. CAR)
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

	--determining whether "y" is a consonant or a vowel
	text = rsub(text, "y(" .. V .. ")", "ɟ%1") -- not the real sound
	text = rsub(text, "y#", "i")
	text = rsub(text, "w(" .. V .. ")","w%1")
	text = rsub(text, "w#","u")

	-- handle certain combinations; ch ng and sh handling needs to go first
	text = rsub(text, "ch", "ts") --not the real sound
	text = rsub(text, "ng", "ŋ")
	text = rsub(text, "ñg", "ŋ")
	text = rsub(text, "sh", "ʃ")

	--x
	text = rsub(text, "x", "ks")
	
	--c, g, q
	text = rsub(text, "c([ie])", "s%1")
	text = rsub(text, "gu(" .. V .. ")", "ɡw%1")
	text = rsub(text, "qu([ieë])", "k%1")
	text = rsub(text, "ü", "u") 
	
	-- double ll
	text = rsub(text, "ll", "li")
	
	-- double dd
	text = rsub(text, "dd", "d")
	
	-- double gg
	text = rsub(text, "gg", "g")

	table.insert(debug, text)

	--alphabet-to-phoneme
	text = rsub(text, "[acfgijñruvyz]",
	--["g"]="ɡ":  U+0067 LATIN SMALL LETTER G → U+0261 LATIN SMALL LETTER SCRIPT G
		{ ["a"] = "ə", ["c"] = "k", ["f"] = "p", ["g"] = "ɡ", ["i"] = "ɪ", ["j"] = "ĵ", ["ñ"] = "nj", ["q"] = "k", ["r"] = "ɾ", ["u"] = "ʊ", ["v"] = "b", ["y"] = "j", ["z"] = "s" })

	-- trill in rr
	text = rsub(text, "ɾɾ", "r")
	
	
	-- glottal stop
	text = rsub(text, "(" .. V .. ")7" , "%1" .. CFLEX )

	-- ts
	text = rsub(text, "ts", "ć") --not the real sound

	text = rsub(text, "n([# .]*[bpm])", "m%1")

	table.insert(debug, text)

	--syllable division
	local vowel_to_glide = { ["i"] = "j", ["ɪ"] = "j",  ["o"] = "w", ["u"] = "w", ["ʊ"] = "w" }
	-- i, o and u between vowels -> j and w. Usually in words spelled in Bacolor and old Guagua orthography)
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*)([iɪouʊ])(" .. V .. ")",
			function(v1, iou, v2)
				return v1 .. vowel_to_glide[iou] .. v2
			end
	)
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*)(" .. C .. W .. "?" .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. ")(" .. C .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. "+)(" .. C .. C .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. C .. ")%.s(" .. C .. ")", "%1s.%2")
	-- Any aeo, or stressed iu, should be syllabically divided from a following aeou or stressed iu.
	text = rsub_repeatedly(text, "([aeo]" .. accent_c .. "*)([aeo])", "%1.%2")
	text = rsub_repeatedly(text, "([aeo]" .. accent_c .. "*)(" .. V .. stress_c .. ")", "%1.%2")
	text = rsub(text, "([iɪuʊ]" .. stress_c .. ")([aeo])", "%1.%2")
	text = rsub_repeatedly(text, "([iu]" .. stress_c .. ")(" .. V .. stress_c .. ")", "%1.%2")
	text = rsub_repeatedly(text, "([iɪ])(" .. accent_c .. "*)([iɪ])", "%1%2.%3")
	text = rsub_repeatedly(text, "([uʊ])(" .. accent_c .. "*)([uʊ])", "%1%2.%3")
	
	table.insert(debug, text)

	local accent_to_stress_mark = { [AC] = "ˈ", [GR] = "", [CFLEX] = "", [CAR] = "" }

	local function accent_word(word, syllables, last_word)
		-- Now stress the word. If any accent exists in the word (including ^ indicating an unaccented word),
		-- put the stress mark(s) at the beginning of the indicated syllable(s). Otherwise, apply the default
		-- stress rule.
		
		-- Updated circumflex rule for Batiauan and Samson orthography, unaccented word is now ˇ
		local stress_syllable = 0
		local accent_syllable = 0
		local last_accent = ""
		
		if rfind(word, accent_c) then
			for i = 1, #syllables do
				syllables[i] = rsub(syllables[i], "^(.*)(" .. accent_c .. ")(.*)$",
						function(pre, accent, post)
							last_accent = accent
							accent_syllable = i
							accent_pre = ''
							elongation = ''
							if last_accent == AC then
								if i ~= #syllables or stress_syllable == 0 then
									 stress_syllable = i
								end
								
								if i == #syllables and phonetic then
									-- Only when the last vowel is really placed with an accent mark, commonly with words ending with /e/ or /o/ like balé
									elongation = 'ː'
								end
								
								if stress_syllable == i then
									accent_pre = accent_to_stress_mark[accent]
								end
							end
							
							return accent_pre .. pre .. elongation  .. post
						end
				)
			end
			if last_accent == CFLEX then
				if last_word then
					syllables[#syllables] = rsub(syllables[#syllables], "(.*)(" .. V .. ")([#|$]+)", "%1%2ʔ%3")
				end
				
				if stress_syllable == 0 then
					syllables[#syllables] = "ˈ" .. syllables[#syllables]
				end
			elseif last_accent == GR then
				if last_word then
					syllables[#syllables] = rsub(syllables[#syllables], "(.*)(" .. V .. ")([#|$]+)", "%1%2ʔ%3")
				end
				
				if stress_syllable ~= #syllables-1 then
					syllables[#syllables-1] = "ˈ" .. syllables[#syllables-1]
				end
			end
		else
			-- Default stress rule. Words without vowels (e.g. IPA foot boundaries) don't get stress.
			if #syllables > 1 and rfind(word, "[^ əeiouɪʊbcdfghjklmnñpqrstvwxzɡĉɟĵŋ#]#") or #syllables == 1 and rfind(word, "[əeiouɪʊ]") 		then
				syllables[#syllables] = "ˈ" .. syllables[#syllables]
			elseif #syllables > 1 then
				-- Changed to ultimate stress as default instead of penultimate in Batiauan orthography
				-- To have penultimate stress, have an acute accent to the penultimate syllable vowel
				syllables[#syllables] = "ˈ" .. syllables[#syllables]
			end
		end
	end

	local words = rsplit(text, " ")
	for j, word in ipairs(words) do
		-- accentuation
		local syllables = rsplit(word, "%.")

			accent_word(word, syllables, j == #words)

		-- Reconstruct the word.
		words[j] = table.concat(syllables, ".")
		
		-- suppress syllable mark before IPA stress indicator
		words[j] = rsub(words[j], "%.(" .. ipa_stress_c .. ")", "%1")
		--make all primary stresses but the last one be secondary
		words[j] = rsub_repeatedly(words[j], "ˈ(.+)ˈ", "ˌ%1ˈ")
	end

	text = table.concat(words, " ")
	
	table.insert(debug,text)
	
	--diphthongs
	text = rsub(text, "([iɪ])([əeiɪouʊ])", "j%2")
	text = rsub(text, "([uʊ])([əeiɪo])", "w%2")

	table.insert(debug, text)

	-- stressed vowels
    -- schwa in stressed syllable to /a/
    
	text = rsub(text,"([ˈˌ])([#]*)([bĉćdfɡhĵɟklmnŋɲpɾrsʃtw]?)([jlnɾtwɟ]?)([ə])([bdfɡiɪklmnŋpɾstuʊ]?)([bdɡklmnpɾst]?)","%1%2%3%4a%6%7")
	text = rsub(text,"([ˈˌ])([#]*)([bĉćdfɡhĵɟklmnŋɲpɾrsʃtw]?)([jlnɾtwɟ]?)([ɪ])([əabdfɡklmnŋpɾstuʊ]?)([bdɡklmnpɾst]?)","%1%2%3%4i%6%7")
	text = rsub(text,"([ˈˌ])([#]*)([bĉćdfɡhĵɟklmnŋɲpɾrsʃtw]?)([jlnɾtwɟ]?)([ʊ])([əabdfɡiɪklmnŋpɾst]?)([bdɡklmnpɾst]?)","%1%2%3%4u%6%7")

    table.insert(debug, text)

      --phonemic diphthongs
    text = rsub(text,"([aeouʊ])([iɪ])","%1j")
	text = rsub(text,"([aeiɪo])([ʊu])","%1w")
    text = rsub(text,"([ə])([iɪ])","aj")
    text = rsub(text,"([ə])([uʊ])","aw")

    table.insert(debug, text)
    
    text = rsub(text,"n([ˈˌ.]?)ɡ","ŋ%1ɡ") -- /n/ before /ɡ/ (some proper nouns and loanwords)
    
    --Final syllables of /i/ and /u/ cannot be /ɪ/ or /ʊ/
    text = rsub(text,"([ˈˌ.])([bdɡhklmnŋprɾsʃtwjɟćĵ]?)([jlɾtw]?)([iɪ])([bdfɡiklmnŋpɾstʔ]?)([bdɡklmnpɾst]?)([#])","%1%2%3i%5%6")
    text = rsub(text,"([ˈˌ.])([bdɡhklmnŋprɾsʃtwjɟćĵ]?)([jlɾtw]?)([uʊ])([bdfɡiklmnŋpɾstʔ]?)([#])","%1%2%3u%5%6")

	--phonetic transcription
	if phonetic then

        --phonemic diphthongs
		text = rsub(text, "([aeouʊ])j", "%1ɪ̯")
		text = rsub(text, "([aeiɪo])w", "%1ʊ̯")

       	table.insert(debug, text)

	    text = rsub(text,"([aəeiɪouʊ])([#]?)([ ]?)([ˈˌ#.])([k])([aəeiɪouʊ])","%1%2%3%4x%6") -- /k/ between vowels
        text = rsub(text,"d([ˈˌ]?)j","%1d͡ʒ") --/d/ before /j/
        text = rsub(text,"n([ˈˌ.]?)k","ŋ%1k") -- /n/ before /k/ (some proper nouns)
        
        -- text = rsub(text,"n([ˈˌ]?)h","ŋ%1h") -- /n/ before /h/ (some proper nouns)
        text = rsub(text,"n([ˈˌ]?)m","m%1m") -- /n/ before /m/
        text = rsub(text,"s([ˈˌ]?)j","%1ʃ") -- /s/ before /j/
        text = rsub(text,"t([ˈˌ]?)j","%1ć") -- /t/ before /j/
        text = rsub(text,"([ˈˌ]?)d([j])([aɪʊ])","%1 ĵ%3") -- /dj/ before any vowel following stress
        text = rsub(text,"([ˈˌ]?)s([j])([aɪʊ])","%1ʃ%3") -- /sj/ before any vowel following stress
        text = rsub(text,"([ˈˌ]?)t([j])([aɪʊ])","%1ć%3") -- /tj/ before any vowel following stress
        text = rsub(text,"([oʊ])([m])([ˈ]?)([pb])","u%2%3%4") -- /o/ and /ʊ/ before /mb/ or /mp/
       
        -- /j/ glide between /a/ of two words instead of glottal stop
        text = rsub_repeatedly(text,"([aəä])#([ ]+)([ˈˌ]?)#([aäə])","%1#%2%3#j%4") 
	    
        table.insert(debug, text)
        
        --Change /i/,/u/ and /ɪ/,/ʊ/ depending if final syllable
	    -- text = rsub(text,"([ˈˌ.])([bdɡhklmnŋprɾsʃtwjɟćĵ]?)([jlɾtw]?)([iɪ])([bdfɡiklmnŋpɾstʔ]?)([bdɡklmnpɾst]?)([#])","%1%2%3e%5%6")
	    -- text = rsub(text,"([ˈˌ.])([bdɡhklmnŋprɾsʃtwjɟćĵ]?)([jlɾtw]?)([uʊ])([bdfɡiklmnŋpɾstʔ]?)([#])","%1%2%3o%5%6")
	    text = rsub(text,"([ˈˌ.])([bdɡhklmnŋprɾsʃtwjɟćĵ]?)([jlɾtw]?)([iɪ])([bdfɡiklmnŋpɾstʔ]?)([bdɡklmnpɾst]?)([#])","%1%2%3i%5%6")
	    text = rsub(text,"([ˈˌ.])([bdɡhklmnŋprɾsʃtwjɟćĵ]?)([jlɾtw]?)([uʊ])([bdfɡiklmnŋpɾstʔ]?)([#])","%1%2%3u%5%6")
	    
	    -- h before i sound is replaced by /j/ on phonetic.
	    text = rsub_repeatedly(text,"([^# bdɡhklmnŋprɾsʃtwjɟćĵ])([ˈˌ.])([h])([eiɪ])","%1%2j%4") -- /j/ for /h/
	    
	    -- h before u sound is replaced by /w/ on phonetic.
	    text = rsub_repeatedly(text,"([^# bdɡhklmnŋprɾsʃtwjɟćĵ])([ˈˌ.])([h])([ouʊ])","%1%2w%4") -- /w/ for /h/
	    
	    -- h | There is no /h/ in Kapampangan, no /h/ in Spanish either, /h/ in Tagalog disappears like hangin, angin
		text = rsub(text, "h", "")
		
		 --The /a/ is a mid long vowel
	    text = rsub(text, "a", "ä")
	    
	    --The /e/ is an /ɛ/
	    text = rsub(text, "e", "ɛ")
	    
	    -- Elongate stresses
	    text = rsub_repeatedly(text,"([ˈˌ])([#]*)([bĉćdfɡhĵɟklmnŋɲpɾrsʃtwx]?)([jlnɾtwɟ]?)([äɛiɪouʊ])([^#ː]*)([.])","%1%2%3%4%5ː%6%7")
	    
	end

	table.insert(debug, text)

	-- convert fake symbols to real ones
    	local final_conversions = {
		["ć"] = "t͡ʃ", -- fake "ch" to real "ch"
		["ɟ"] =  "j", -- fake "y" to real "y"
        ["ĵ"] = "d͡ʒ" -- fake "j" to real "j"
	}

    	local final_conversions_phonetic = {
		["ć"] = "t͡ʃ", -- fake "ch" to real "ch"
		["ɟ"] =  "j", -- fake "y" to real "y"
        ["ĵ"] = "d͡ʒ" -- fake "j" to real "j"
	}

	if phonetic then
	text = rsub(text, "[ćɟĵ]", final_conversions_phonetic)
    	end
	text = rsub(text, "[ćɟĵ]", final_conversions)
	
	if not phonetic then
		text = rsub(text, "[.]", "")
	end

	-- remove # symbols at word and text boundaries
	text = rsub(text, "#", "")

	return mw.ustring.toNFC(text)
end

local function respelling_to_IPA(data)
	return ("/%s/ [%s]"):format(export.IPA(data.respelling, false), export.IPA(data.respelling, true))
end

function export.show(frame)
	local parent_args = frame:getParent().args
	return require(pron_utilities_module).format_prons {
		lang = lang,
		respelling_to_IPA = respelling_to_IPA,
		raw_args = parent_args,
		track_module = "pam-pron",
	}
end

return export
