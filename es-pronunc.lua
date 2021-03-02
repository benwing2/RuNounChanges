local export = {}

local u = mw.ustring.char
local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local ulower = mw.ustring.lower
local uupper = mw.ustring.upper
local usub = mw.ustring.sub
local ulen = mw.ustring.len

local AC = u(0x0301) -- acute =  ́
local GR = u(0x0300) -- grave =  ̀
local CFLEX = u(0x0302) -- circumflex =  ̂
local TILDE = u(0x0303) -- tilde =  ̃
local DIA = u(0x0308) -- diaeresis =  ̈

local vowel = "aeiouy" -- vowel; include y so we get single-word y correct
local V = "[" .. vowel .. "]"
local W = "[jw]" -- glide
local accent = AC .. GR .. CFLEX
local accent_c = "[" .. accent .. "]"
local stress = AC .. GR
local stress_c = "[" .. AC .. GR .. "]"
local ipa_stress = "ˈˌ"
local ipa_stress_c = "[" .. ipa_stress .. "]"
local separator = accent .. ipa_stress .. "# ."
local separator_c = "[" .. separator .. "]"
local C = "[^" .. vowel .. separator .. "]" -- consonant
local T = "[^" .. vowel .. "lrɾjw" .. separator .. "]" -- obstruent or nasal

local unstressed_words = require("Module:table").listToSet({
	"el", "la", "los", "las", -- definite articles
	"un", -- single-syllable indefinite articles
	"me", "te", "se", "lo", "le", "nos", "os", -- unstressed object pronouns
	"mi", "mis", "tu", "tus", "su", "sus", -- unstressed possessive pronouns
	"que", "si", -- subordinating conjunctions
	"y", "e", "o", "u", -- coordinating conjunctions
	"de", "del", "a", "al", -- basic prepositions + combinations with articles
	"por", "en", "con", -- other prepositions
})

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
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

-- ɟ and ĉ are used internally to represent [ʝ⁓ɟ͡ʝ] and [t͡ʃ]
--
-- style == one of the following:
-- "distincion-lleismo": distinción + lleísmo
-- "distincion-yeismo": distinción + yeísmo
-- "seseo-lleismo": seseo + lleísmo
-- "seseo-yeismo": seseo + yeísmo
-- "rioplatense": Rioplatense
function export.IPA(text, style, phonetic, do_debug)
	local debug = {}

	local distincion = style == "distincion-lleismo" or style == "distinction-yeismo"
	local lleismo = style == "distinction-lleismo" or style == "sesio-lleismo"
	local rioplat = style == "rioplatense"

	text = ulower(text or mw.title.getCurrentTitle().text)
	-- decompose everything but ñ and ü
	text = mw.ustring.toNFD(text)
	text = rsub(text, ".[" .. TILDE .. DIA .. "]", {
		["n" .. TILDE] = "ñ",
		["u" .. DIA] = "ü",
	})
	-- convert commas and en/en dashes to IPA foot boundaries
	text = rsub(text, "%s*[,–—]%s*", " | ")
	-- question mark or exclamation point in the middle of a sentence -> IPA foot boundary
	text = rsub(text, "([^%s])%s*[¡!¿?]%s*([^%s])", "%1 | %2")

	-- canonicalize multiple spaces and remove leading and trailing spaces
	local function canon_spaces(text)
		text = rsub(text, "%s+", " ")
		text = rsub(text, "^ ", "")
		text = rsub(text, " $", "")
		return text
	end

	text = canon_spaces(text)

	-- Make prefixes unstressed unless they have an explicit stress marker; also make certain
	-- monosyllabic words (e.g. [[el]], [[la]], [[de]], [[en]], etc.) without stress marks be
	-- unstressed.
	local words = rsplit(text, " ")
	for i, word in ipairs(words) do
		if rfind(word, "%-$") and not rfind(word, accent_c) or unstressed_words[word] then
			-- add CFLEX to the last vowel not the first one, or we will mess up 'que' by
			-- adding the CFLEX after the 'u'
			words[i] = rsub(word, "^(.*" .. V .. ")", "%1" .. CFLEX)
		end
	end
	text = table.concat(words, " ")
	-- Convert hyphens to spaces, to handle [[Austria-Hungría]], [[franco-italiano]], etc.
	text = rsub(text, "%-", " ")
	-- canonicalize multiple spaces again, which may have been introduced by hyphens
	text = canon_spaces(text)
	-- now eliminate punctuation
	text = rsub(text, "[¡!¿?']", "")
	-- put # at word beginning and end and double ## at text/foot boundary beginning/end
	text = rsub(text, " | ", "# | #")
	text = "##" .. rsub(text, " ", "# #") .. "##"

	table.insert(debug, text)

	--determining whether "y" is a consonant or a vowel
	text = rsub(text, "y(" .. V .. ")", "ɟ%1") -- not the real sound
	text = rsub(text, "y", "i")
	text = rsub(text, "#hi(" .. V .. ")", rioplat and "#j%1" or "#ɟ%1")

	--x
	text = rsub(text, "#x", "s") -- xenofobia, xilófono, etc.
	text = rsub(text, "x", "ks")

	--c, g, q
	text = rsub(text, "c([ie])", (distincion and "θ" or "s") .. "%1")
	text = rsub(text, "gü([ie])", "ɡw%1")
	text = rsub(text, "gu([ie])", "ɡ%1") -- special IPA g, not normal g
	text = rsub(text, "g([ie])", "x%1") -- must happen after handling of x above
	-- following must happen before stress assignment; [[branding]] has initial stress like 'brandin'
	text = rsub(text, "ng([^aeiouüwhlr])", "n%1") -- [[Bangkok]], [[ángstrom]], [[branding]]
	text = rsub(text, "qu([ie])", "k%1")
	text = rsub(text, "ü", "u") -- [[Düsseldorf]], [[hübnerita]], obsolete [[freqüentemente]], etc.
	text = rsub(text, "q", "k") -- [[quark]], [[Qatar]], [[burqa]], [[Iraq]], etc.

	table.insert(debug, text)

	--alphabet-to-phoneme
	text = rsub(text, "ch", "ĉ") --not the real sound
	-- We want to keep desh- ([[deshuesar]]) as-is. Converting to des- won't work because we want it syllabified as
	-- 'des.we.saɾ' not #'de.swe.saɾ' (cf. [[desuelo]] /de.swe.lo/ from [[desolar]]).
	text = rsub(text, "#desh", "!") --temporary symbol
	text = rsub(text, "sh", "ʃ")
	text = rsub(text, "!", "#desh") --restore 
	text = rsub(text, "#p([st])", "%1") -- [[psicología]], [[pterodáctilo]]
	text = rsub(text, "[cgjñrvy]",
		--["g"]="ɡ":  U+0067 LATIN SMALL LETTER G → U+0261 LATIN SMALL LETTER SCRIPT G
		{["c"]="k", ["g"]="ɡ", ["j"]="x", ["ñ"]="ɲ", ["r"]="ɾ", ["v"]="b" })

	-- trill in #r, lr, nr, sr, rr
	text = rsub(text, "ɾɾ", "r")
	-- FIXME: does this also apply to /θr/ (e.g. [[Azrael]], [[cruzrojista]])?
	text = rsub(text, "([#lns])ɾ", "%1r")

	-- double l
	text = rsub(text, "ll", lleismo and "ʎ" or "ɟ")

	-- reduce any remaining double consonants ([[Addis Abeba]], [[cappa]], [[descender]] in Latin America ...);
	-- do this before handling of -nm- e.g. in [[inmigración]], which generates a double consonant, and do this
	-- before voicing stops before obstruents, to avoid problems with [[cappa]] and [[crackear]]
	text = rsub(text, "(" .. C .. ")%1", "%1")

	-- voiceless stop to voiced before obstruent or nasal; but intercept -ts-, -tz-
	local voice_stop = { ["p"] = "b", ["t"] = "d", ["k"] = "ɡ" }
	text = rsub(text, "t(" .. separator_c .. "*[szθ])", "!%1") -- temporary symbol
	text = rsub(text, "([ptk])(" .. separator_c .. "*" .. T .. ")",
		function(stop, after) return voice_stop[stop] .. after end)
	text = rsub(text, "!", "t")

	text = rsub(text, "z", distincion and "θ" or "z") -- not the real LatAm sound
	text = rsub(text, "n([# .]*[bpm])", "m%1")

	table.insert(debug, text)

	--syllable division
	local vowel_to_glide = { ["i"] = "j", ["u"] = "w" }
	-- i and u between vowels -> j and w ([[paranoia]], [[baiano]], [[abreuense]], [[alauita]], [[Malaui]], etc.)
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*)([iu])(" .. V .. ")",
		function (v1, iu, v2) return v1 .. vowel_to_glide[iu] .. v2 end
	)
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*)(" .. C .. W .. "?" .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. ")(" .. C .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. "+)(" .. C .. C .. V .. ")", "%1.%2")
	text = rsub(text, "([pbktdɡ])%.([lɾ])", ".%1%2")
	text = rsub(text, "(" .. C .. ")%.s(" .. C .. ")", "%1s.%2")
	-- Any aeo, or stressed iu, should be syllabically divided from a following aeo or stressed iu.
	text = rsub(text, "([aeo]" .. accent_c .. "*)([aeo])", "%1.%2")
	text = rsub(text, "([aeo]" .. accent_c .. "*)(" .. V .. stress_c .. ")", "%1.%2")
	text = rsub(text, "([iu]" .. stress_c .. ")([aeo])", "%1.%2")
	text = rsub(text, "([iu]" .. stress_c .. ")(" .. V .. stress_c .. ")", "%1.%2")
	text = rsub(text, "i(" .. accent_c .. "*)i", "i%1.i")
	text = rsub(text, "u(" .. accent_c .. "*)u", "u%1.u")

	table.insert(debug, text)

	--diphthongs
	text = rsub(text, "ih?([aeou])", "j%1")
	text = rsub(text, "uh?([aeio])", "w%1")

	table.insert(debug, text)

	local accent_to_stress_mark = { [AC] = "ˈ", [GR] = "ˌ", [CFLEX] = "" }

	local function accent_word(word, syllables)
		-- Now stress the word. If any accent exists in the word (including ^ indicating an unaccented word),
		-- put the stress mark(s) at the beginning of the indicated syllable(s). Otherwise, apply the default
		-- stress rule.
		if rfind(word, accent_c) then
			for i = 1, #syllables do
				syllables[i] = rsub(syllables[i], "^(.*)(" .. accent_c .. ")(.*)$",
					function(pre, accent, post) return accent_to_stress_mark[accent] .. pre .. post end
				)
			end
		else
			-- Default stress rule. Words without vowels (e.g. IPA foot boundaries) don't get stress.
			if #syllables > 1 and rfind(word, "[^aeiouns#]#") or #syllables == 1 and rfind(word, "[aeiou]") then
				syllables[#syllables] = "ˈ" .. syllables[#syllables]
			elseif #syllables > 1 then
				syllables[#syllables - 1] = "ˈ" .. syllables[#syllables - 1]
			end
		end
	end

	local words = rsplit(text, " ")
	for j, word in ipairs(words) do
		-- accentuation
		local syllables = rsplit(word, "%.")

		if rfind(word, "men%.te#") then
			local mente_syllables
			-- Words ends in -mente (converted above to ménte); add a stress to the preceding portion
			-- (e.g. [[agriamente]] -> 'ágriaménte') unless already stressed (e.g. [[rápidamente]]).
			-- It will be converted to secondary stress further below. Essentially, we rip the word apart
			-- into two words ('mente' and the preceding portion) and stress each one independently.
			mente_syllables = {}
			mente_syllables[2] = table.remove(syllables)
			mente_syllables[1] = table.remove(syllables)
			accent_word(table.concat(syllables, "."), syllables)
			accent_word(table.concat(mente_syllables, "."), mente_syllables)
			table.insert(syllables, mente_syllables[1])
			table.insert(syllables, mente_syllables[2])
		else
			accent_word(word, syllables)
		end

		-- Vowels are nasalized if followed by nasal in same syllable.
		if phonetic then
			for i = 1, #syllables do
				-- first check for two vowels (veinte)
				syllables[i] = rsub(syllables[i], "(" .. V .. ")(" .. V .. ")([mnɲ])",
					"%1" .. TILDE .. "%2" .. TILDE .. "%3")
				-- then for one vowel
				syllables[i] = rsub(syllables[i], "(" .. V .. ")([mnɲ])", "%1" .. TILDE .. "%2")
			end
		end

		-- Reconstruct the word.
		words[j] = table.concat(syllables, phonetic and "." or "")
	end

	text = table.concat(words, " ")

	--real sound of LatAm Z
	text = rsub(text, "z", "s")
	--make all primary stresses but the last one be secondary
	text = rsub_repeatedly(text, "ˈ(.+)ˈ", "ˌ%1ˈ")

	local variants = {}
	if rioplat then
		local sh_variant = rsub(text, "ɟ", "ʃ")
		local zh_variant = rsub(text, "ɟ", "ʒ")
		if sh_variant == zh_variant then
			table.insert(variants, sh_variant)
		else
			table.insert(variants, sh_variant)
			table.insert(variants, zh_variant)
		end
	else
		table.insert(variants, text)
	end

	for i, text in ipairs(variants) do
		--phonetic transcription
		if phonetic then
			-- θ, s, f before voiced consonants
			local voiced = "mnɲbdɟɡʎ"
			local r = "ɾr"
			local tovoiced = {
				["θ"] = "θ̬",
				["s"] = "z",
				["f"] = "v",
			}
			local function voice(sound, following)
				return tovoiced[sound] .. following
			end
			text = rsub(text, "([θs])(" .. separator_c .. "*[" .. voiced .. r .. "])", voice)
			text = rsub(text, "(f)(" .. separator_c .. "*[" .. voiced .. "])", voice)

			-- fricative vs. stop allophones; first convert stops to fricatives, then back to stops
			-- after nasals and sometimes after l
			local stop_to_fricative = {["b"] = "β", ["d"] = "ð", ["ɟ"] = "ʝ", ["ɡ"] = "ɣ"}
			local fricative_to_stop = {["β"] = "b", ["ð"] = "d", ["ʝ"] = "ɟ", ["ɣ"] = "ɡ"}
			text = rsub(text, "[bdɟɡ]", stop_to_fricative)
			text = rsub(text, "([mnɲ]" .. separator_c .. "*)([βɣ])",
				function(nasal, fricative) return nasal .. fricative_to_stop[fricative] end
			)
			text = rsub(text, "([lʎmnɲ]" .. separator_c .. "*)([ðʝ])",
				function(nasal_l, fricative) return nasal_l .. fricative_to_stop[fricative] end
			)
			text = rsub(text, "(##" .. ipa_stress_c .. "*)([βɣðʝ])",
				function(stress, fricative) return stress .. fricative_to_stop[fricative] end
			)
			text = rsub(text, "[td]", {["t"] = "t̪", ["d"] = "d̪"})

			-- nasal assimilation before consonants
			local labiodental, dentialveolar, dental, alveolopalatal, palatal, velar =
				"ɱ", "n̪", "n̟", "nʲ", "ɲ", "ŋ"
			local nasal_assimilation = {
				["f"] = labiodental,
				["t"] = dentialveolar, ["d"] = dentialveolar,
				["θ"] = dental,
				["ĉ"] = alveolopalatal,
				["ʃ"] = alveolopalatal,
				["ɟ"] = palatal, ["ʎ"] = palatal,
				["k"] = velar, ["x"] = velar, ["ɡ"] = velar,
			}
			text = rsub(text, "n(" .. separator_c .. "*)(.)",
				function(stress, following) return (nasal_assimilation[following] or "n") .. stress .. following end
			)

			-- lateral assimilation before consonants
			text = rsub(text, "l(" .. separator_c .. "*)(.)",
				function(stress, following)
					local l = "l"
					if following == "t" or following == "d" then -- dentialveolar
						l = "l̪"
					elseif following == "θ" then -- dental
						l = "l̟"
					elseif following == "ĉ" or following == "ʃ" then -- alveolopalatal
						l = "lʲ"
					end
					return l .. stress .. following
				end)

			--semivowels
			text = rsub(text, "([aeouãẽõũ][iĩ])", "%1̯")
			text = rsub(text, "([aeioãẽĩõ][uũ])", "%1̯")
			
			-- voiced fricatives are actually approximants
			text = rsub(text, "([βðɣ])", "%1̝")

			if rioplat then
				text = rsub(text, "s(" .. separator_c .. "*" .. C .. ")", "ħ%1") -- not the real symbol
				text = rsub(text, "z(" .. separator_c .. "*" .. C .. ")", "ɦ%1")
			end
		end

		table.insert(debug, text)

		-- remove silent "h" and convert fake symbols to real ones
		local final_conversions =  {
			["h"] = "",   -- silent "h"
			["ħ"] = "h",  -- fake aspirated "h" to real "h"
			["ĉ"] = "t͡ʃ", -- fake "ch" to real "ch"
			["ɟ"] = "ɟ͡ʝ", -- fake "y" to real "y"
		}
		text = rsub(text, "[hħĉɟ]", final_conversions)

		-- remove # symbols at word and text boundaries
		text = rsub(text, "#", "")

		variants[i] = text
	end

	local ret = {
		variants = variants
	}
	if do_debug == "yes" then
		ret.debug = table.concat(debug, " ||| ")
	end
	return ret
end

function export.show(frame)
	local params = {
		[1] = {required = true, default = "cebolla"},
		["debug"] = {type = "boolean"},
	}
	local parargs = frame:getParent().args
	local args = require("Module:parameters").process(parargs, params)
	...
end


function export.LatinAmerica(frame)
	return export.show(frame, true)
end

function export.phonetic(frame)
	return export.show(frame, false, true)
end

function export.phoneticLatinAmerica(frame)
	return export.show(frame, true, true)
end

return export
