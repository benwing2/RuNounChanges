--Based on [[module:id-pron]] by Rex Aurorum (see module history for attribution).

local export = {}

local pron_utilities_module = "Module:pron utilities"

local lang = require("Module:languages").getByCode("ms")

local u = mw.ustring.char
local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local rsplit = mw.text.split
local ulower = mw.ustring.lower

local AC = u(0x0301) -- acute =  ́
local CFLEX = u(0x0302) -- circumflex =  ̂ 
local GR = u(0x0300) -- grave =  ̀
local MAC = u(0x0304) -- macron
local TILDE = u(0x0303) -- tilde =  ̃
local DIA = u(0x0308) -- diaeresis =  ̈
local BR = u(0x0306) -- breve = ˘

local vowel = "aeéèëẽiouəâêîôû" -- vowel
local V = "[" .. vowel .. "]"
local W = "[jw]" -- glide

local accent = AC .. MAC .. BR
local accent_c = "[" .. accent .. "]"
local stress_c = "[" .. MAC .. BR .. "]"
local ipa_stress = "ˈ"
local ipa_stress_c = "[" .. ipa_stress .. "]"

local separator =  "# ." 
local separator_c = "[" .. separator .. "]"
local C = "[^" .. vowel .. separator .. "]" -- consonant

local unstressed_words = require("Module:table").listToSet({ --feel free to add more unstressed words
	"di", "ké", -- prepositions
	"dan", -- conjunctions
	"dia", "-ku", "-mu", "-nya", "-nye", -- pronouns. "dia" should be respelled to "di.a" for Bahasa Baku pronunciation. "nye" is for Johor pronunciation.
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
	text = ulower(text or mw.title.getCurrentTitle().text)
	-- decompose everything but é and circumflexed letters (used in Johor-Riau pronunciations to indicate length due to elision of final R)
	text = mw.ustring.toNFD(text)
	text = rsub(text, "." .. "[" .. AC .. CFLEX .. DIA .. GR .. TILDE .. "]", {
		["e" .. AC] = "é", -- e taling
		["e" .. GR] = "è", -- used for long /e/
        ["e" .. DIA] = "ë", -- pseudo-letter for Kelantan [ɛ]
        ["e" .. TILDE] = "ẽ", -- pseudo-letter for Kelantan reflex of /ia/
		["a" .. CFLEX] = "â", -- use for Kelantan reflex of standard /a/ + nasal
		["e" .. CFLEX] = "ê",
		["i" .. CFLEX] = "î",
		["o" .. CFLEX] = "ô",
		["u" .. CFLEX] = "û",
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
	-- monosyllabic words (e.g. [[di]], [[ke]], [[se-]], etc.) without stress marks be
	-- unstressed.
	local words = rsplit(text, " ")
	for i, word in ipairs(words) do
		if rfind(word, "%-$") and not rfind(word, accent_c) or unstressed_words[word] then
			-- add BR to the last vowel not the first one
			-- adding the BR after the 'u'
			words[i] = rsub(word, "^(.*" .. V .. ")", "%1" .. BR)
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

	--"i" or "u" to glide (in between vowels or is part of a diphthong)
	text = rsub(text, "(" .. V ..")i([.#])", "%1ɟ%2")
	text = rsub(text, "("..V..")u([.#])", "%1w%2")

    -- syllable-initial X (e.g. in [[xenofobia]], [[xenon]], [[xilofon]])
	text = rsub(text, "x("..V..")", "z%1")

	-- handle certain combinations; gh, kh, ng, ny and sy handling needs to go first
	text = rsub(text, "gh", "ɣ")
	text = rsub(text, "kh", "x")
	text = rsub(text, "ng", "ŋ")
	text = rsub(text, "ny", "ɲ")
	text = rsub(text, "sy", "ʃ")
	
	table.insert(debug, text)

	--alphabet-to-phoneme
	text = rsub(text, "[ceégjy]",
	--["g"]="ɡ":  U+0067 LATIN SMALL LETTER G → U+0261 LATIN SMALL LETTER SCRIPT G
		{ ["c"] = "ć", ["e"] = "ə", ["é"] = "e", ["ë"] = "ɛ", ["g"] = "ɡ", ["j"] = "ĵ", ["y"] = "j" })	
	
	-- glottal stop.
	text = rsub(text, "7", "ʔ")

	table.insert(debug, text)

	--syllable division
	local vowel_to_glide = { ["i"] = "j", ["u"] = "w" }
	-- i, o and u between vowels -> j and e.g. [[rangkaian]])
	text = rsub_repeatedly(text, "(" .. V .. "*)([iu])(" .. V .. ")",
			function(v1, iu, v2)
				return v1 .. vowel_to_glide[iu] .. v2
			end
	)

	text = rsub_repeatedly(text, "(" .. V .. accent_c .."*)(" .. C .. W .. "?" .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .."*" .. C .. ")(" .. C .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .."*" .. C .. "+)(" .. C .. C .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. C .. ")%.s(" .. C .. ")", "%1s.%2")
	text = rsub_repeatedly(text, "([aeiou]" .. accent_c .. "*)([aeiou])", "%1.%2")

	table.insert(debug, text)

	--diphthongs
	text = rsub(text, "i([aeiouâêîôû])", "j%1")
	text = rsub(text, "u([aeiouâêîôû])", "w%1")

	table.insert(debug, text)

	local accent_to_stress_mark = { [MAC] = "ˈ", [BR] = "" }

	local function accent_word(word, syllables)
		-- Now stress the word. If any accent exists in the word (including breves indicating an unaccented word),
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
			if #syllables > 1 and (rfind(word, "[^aəeéẽɛiouâêîôûʔbcdfgɡhjɟĵklmnŋɲpqrstvwxz#]#")) or #syllables == 1 and rfind(word, V) then
				syllables[#syllables] = "ˈ" .. syllables[#syllables]
			elseif #syllables <= 2 and rfind(word, "[ə]") then
				syllables[#syllables] = "ˈ" .. syllables[#syllables]
			elseif #syllables >= 3 and rfind(word, "[ə]") then
				syllables[#syllables - 1] = "ˈ" .. syllables[#syllables - 1]
			elseif #syllables > 1 then
				syllables[#syllables - 1] = "ˈ" .. syllables[#syllables - 1]
			end
		end
	end

	local words = rsplit(text, " ")
	for j, word in ipairs(words) do

		local syllables = rsplit(word, "%.")

			accent_word(word, syllables)

		-- Reconstruct the word.
		words[j] = table.concat(syllables, phonetic and "." or "")
	end

	text = table.concat(words, " ")

	-- suppress syllable mark before IPA stress indicator
	text = rsub(text, "%.(" .. ipa_stress_c .. ")", "%1")

table.insert(debug,text)

    --vowels with circumflex to vowel+(r)
    text = rsub(text,"â","a(r)")
    text = rsub(text,"ê","ə(r)")
    text = rsub(text,"è","e(r)")
    text = rsub(text,"î","i(r)")
    text = rsub(text,"ô","o(r)")
    text = rsub(text,"û","u(r)")

	table.insert(debug, text)

	--phonetic transcription
	if phonetic then

       	table.insert(debug, text)

        --phonemic diphthongs
		text = rsub(text, "([aeou])([ɟj])([#.ˈ])", "%1i̯%3")
		text = rsub(text, "([a])w([#.ˈ])", "%1u̯%2")

       	table.insert(debug, text)

	    --devoice B and D as coda
	    text = rsub(text, "b([#.ˈ])","p%1")
	    text = rsub(text, "d([#.ˈ])","t%1")

        --/n/ and /ŋ/ sandhi
	    text = rsub(text,"([nŋ])([ˈˌ# .]*[bpm])", "m%2")
	    text = rsub(text,"([ŋ])([ˈˌ# .]*[dlstz])","n%2")
	    text = rsub(text,"([n])([ˈˌ# .]*[ćĵʃ])","ɲ%2")

	    --final K to glottal stop
	    text = rsub(text, "k([#.ˈ])","ʔ%1")

	    --dental T
	    text = rsub(text, "t","t̪")

	    mw.log(text)
	end

	table.insert(debug, text)

	-- convert fake symbols to real ones
    	local final_conversions = {
		["ć"] = "t͡ʃ", -- fake "c" to real "c"
        ["ĵ"] = "d͡ʒ", -- fake "j" to real "j"
        ["ɟ"] = "j" -- fake "y" to real "y"
	}

    	local final_conversions_phonetic = {
		["ć"] = "t͡ʃ", -- fake "c" to real "c"
        ["ĵ"] = "d͡ʒ" -- fake "j" to real "j"
	}

	if phonetic then
	text = rsub(text, "[ćĵ]", final_conversions_phonetic)
    	end
	text = rsub(text, "[ćĵɟ]", final_conversions)
	
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
		track_module = "ms-pron",
		include_bullet = true, -- FIXME: temporary
	}
end

return export
