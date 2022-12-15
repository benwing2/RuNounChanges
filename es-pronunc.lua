local export = {}

local m_IPA = require("Module:IPA")
local m_table = require("Module:table")

local lang = require("Module:languages").getByCode("es")

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

local SYLDIV = u(0xFFF0) -- used to represent a user-specific syllable divider (.) so we won't change it
local vowel = "aeiouy" -- vowel; include y so we get single-word y correct
local V = "[" .. vowel .. "]"
local W = "[jw]" -- glide
local accent = AC .. GR .. CFLEX
local accent_c = "[" .. accent .. "]"
local stress = AC .. GR
local stress_c = "[" .. AC .. GR .. "]"
local ipa_stress = "ˈˌ"
local ipa_stress_c = "[" .. ipa_stress .. "]"
local separator = accent .. ipa_stress .. "# ." .. SYLDIV
local separator_c = "[" .. separator .. "]"
local C = "[^" .. vowel .. separator .. "]" -- consonant
local C_NOT_H = "[^" .. vowel .. separator .. "h]" -- consonant not including h
local T = "[^" .. vowel .. "lrɾjw" .. separator .. "]" -- obstruent or nasal

local unstressed_words = m_table.listToSet({
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

local function split_on_comma(term)
	if term:find(",%s") then
		return require("Module:dialect tags").split_on_comma(term)
	else
		return rsplit(term, ",")
	end
end

local function substitute_plus(terms, pagename)
	for j, term in ipairs(terms) do
		if term == "+" then
			terms[j] = pagename
		end
	end
	return terms
end

--[=[
About styles, dialects and isoglosses:

From the standpoint of pronunciation, a given dialect is defined by isoglosses, which specify differences
in the way of pronouncing certain phonemes. You can think of a dialect as a collection of isoglosses.
For example, one isogloss is "distinción" (pronouncing written ''s'' and ''c/z'' differently) vs. "seseo"
(pronouncing them the same). Another is "lleísmo" (pronouncing written ''ll'' and ''y'' differently) vs.
"yeísmo" (pronouncing them the same). The dominant pronunciation in Spain can be described as
distinción + yeísmo, while the pronunciation in rural northern Spain can be described as distinción + lléismo
and the pronunciation across much of the Andes mountains can be described as seseo + lléismo.

Specifically, the following isoglosses are recognized (note, the isogloss specs as used in this module
dispense with written accents):
-- "distincion" = pronouncing ''s'' and ''c/z'' differently
-- "seseo" = pronouncing ''s'' and ''c/z'' the same
-- "lleismo" = pronouncing ''ll'' and ''y'' differently
-- "yeismo" = pronouncing ''ll'' and ''y'' the same
-- "rioplatense" = Rioplatense speech, i.e. seseo+yeismo with ''ll'' and ''y'' pronounced specially, and a
                   clear distinction between initial ''hi-'' vs. initial ''ll-/y-''
-- "sheismo" = a type of Rioplatense speech, characteristic of Buenos Aires, where ''ll'' and ''y'' are
               pronounced as /ʃ/
-- "zheismo" = a type of Rioplatense speech, found outside of Buenos Aires, where ''ll'' and ''y'' are
               pronounced as /ʒ/

These isoglosses can be combined to yield one of the following six dialects:
-- "distincion-lleismo": distinción + lleísmo
-- "distincion-yeismo": distinción + yeísmo
-- "seseo-lleismo": seseo + lleísmo
-- "seseo-yeismo": seseo + yeísmo
-- "rioplatense-sheismo": Rioplatense with /ʃ/ (Buenos Aires)
-- "rioplatense-zheismo": Rioplatense with /ʒ/ (non-Buenos Aires)

A "style" here is a set of dialects that pronounce a given word in a given fashion. For example, if we are only
considering the distinción/seseo and lleísmo/yeísmo isoglosses, there are four conceivable dialects (all of
which in fact exist). However, for a given word, more than one dialect may pronounce it the same. For
example, a word like [[paz]] has a ''z'' but no ''ll'', and so there are only two possible pronunciations for
the four dialects. Here, the two styles are "Spain" and "Latin America". Correspondingly, a word like [[pollo]]
with an ''ll'' but no ''z'' has two styles, which can approximately be described as "most of Spain and Latin
America" vs. "rural northern Spain, Andes Mountains".

A "style spec" (indicated by the style= parameter to {{es-IPA}}) restricts the output to certain styles.
A style spec can be one of the following:
1. An isogloss, e.g. "distincion", "rioplatense"; if specified, only styles containing this isogloss are output.
2. A negated isogloss, e.g. "-rioplatense".
3. An intersection of isoglosses ("A and B"), e.g. "distincion+lleismo". This can be used to restrict to specific
   dialects.
4. A union of isoglosses ("A or B"), e.g. "distincion,zheismo". If both plus and comma are used, plus takes
   precedence, e.g. "seseo+lleismo,zheismo" means either the "seseo+lleismo" dialect or the "rioplatense-zheismo"
   dialect.

An example where the style= parameter might be used is with the word [[bluetooth]], which has one pronunciation
in Spain/distinción (respelled "blutuz") but another in Latin America/seseo (respelled "blutud"). This might be
represented using {{es-pr}} as {{es-pr|blutuz<style:distincion>|blutud<style:seseo>}}.
]=]

-- ɟ and ĉ are used internally to represent [ʝ⁓ɟ͡ʝ] and [t͡ʃ]
--
function export.IPA(text, dialect, phonetic, do_debug)
	local debug = {}

	local distincion = dialect == "distincion-lleismo" or dialect == "distincion-yeismo"
	local lleismo = dialect == "distincion-lleismo" or dialect == "seseo-lleismo"
	local rioplat = dialect == "rioplatense-sheismo" or dialect == "rioplatense-zheismo"
	local sheismo = dialect == "rioplatense-sheismo"
	local distincion_different = false
	local lleismo_different = false
	local need_rioplat = false
	local initial_hi = false
	local sheismo_different = false

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
	text = rsub(text, "uy#", "uY#") -- a temporary symbol; replaced with i below
	text = rsub(text, "y", "i")

	--x
	text = rsub(text, "#x", "#s") -- xenofobia, xilófono, etc.
	text = rsub(text, "x", "ks")

	--c, g, q
	text = rsub(text, "c([ie])", (distincion and "θ" or "z") .. "%1") -- not the real LatAm sound
	text = rsub(text, "gü([ie])", "ɡw%1")
	text = rsub(text, "gu([ie])", "ɡ%1") -- special IPA g, not normal g
	text = rsub(text, "g([ie])", "x%1") -- must happen after handling of x above
	-- following must happen before stress assignment; [[branding]] has initial stress like 'brandin'
	text = rsub(text, "ng([^aeiouüwhlr])", "n%1") -- [[Bangkok]], [[ángstrom]], [[branding]]
	text = rsub(text, "qu([ie])", "k%1")
	text = rsub(text, "ü", "u") -- [[Düsseldorf]], [[hübnerita]], obsolete [[freqüentemente]], etc.
	text = rsub(text, "q", "k") -- [[quark]], [[Qatar]], [[burqa]], [[Iraq]], etc.
	text = rsub(text, "z", distincion and "θ" or "z") -- not the real LatAm sound
	if rfind(text, "[θz]") then
		distincion_different = true
	end

	table.insert(debug, text)

	--alphabet-to-phoneme
	text = rsub(text, "ch", "ĉ") --not the real sound
	-- We want to keep desh- ([[deshuesar]]) as-is. Converting to des- won't work because we want it syllabified as
	-- 'des.we.saɾ' not #'de.swe.saɾ' (cf. [[desuelo]] /de.swe.lo/ from [[desolar]]).
	text = rsub(text, "#desh", "!") --temporary symbol
	text = rsub(text, "sh", "ʃ")
	text = rsub(text, "!", "#desh") --restore
	text = rsub(text, "#p([st])", "#%1") -- [[psicología]], [[pterodáctilo]]
	text = rsub(text, "[cgjñrvy]",
		--["g"]="ɡ":  U+0067 LATIN SMALL LETTER G → U+0261 LATIN SMALL LETTER SCRIPT G
		{["c"]="k", ["g"]="ɡ", ["j"]="x", ["ñ"]="ɲ", ["r"]="ɾ", ["v"]="b" })
	text, initial_hi = rsubb(text, "#h?i(" .. V .. ")", rioplat and "#j%1" or "#ɟ%1")

	-- double l
	text, lleismo_different = rsubb(text, "ll", lleismo and "ʎ" or "ɟ")

	-- trill in #r, lr, nr, sr, rr
	text = rsub(text, "ɾɾ", "r")
	-- FIXME: does this also apply to /θr/ (e.g. [[Azrael]], [[cruzrojista]])?
	text = rsub(text, "([#lnsz])ɾ", "%1r")

	-- reduce any remaining double consonants ([[Addis Abeba]], [[cappa]], [[descender]] in Latin America ...);
	-- do this before handling of -nm- e.g. in [[inmigración]], which generates a double consonant, and do this
	-- before voicing stops before obstruents, to avoid problems with [[cappa]] and [[crackear]]
	text = rsub(text, "(" .. C .. ")%1", "%1")
	-- also reduce sz (Latin American in [[fascinante]], etc.)
	text = rsub(text, "sz", "s")

	-- voiceless stop to voiced before obstruent or nasal; but intercept -ts-, -tz-
	local voice_stop = { ["p"] = "b", ["t"] = "d", ["k"] = "ɡ" }
	text = rsub(text, "t(" .. separator_c .. "*[szθ])", "!%1") -- temporary symbol
	text = rsub(text, "([ptk])(" .. separator_c .. "*" .. T .. ")",
		function(stop, after) return voice_stop[stop] .. after end)
	text = rsub(text, "!", "t")

	text = rsub(text, "n([# .]*[bpm])", "m%1")

	table.insert(debug, text)

	--syllable division
	local vowel_to_glide = { ["i"] = "j", ["u"] = "w" }
	-- i and u between vowels -> consonant-like substitutions: [[paranoia]], [[baiano]], [[abreuense]], [[alauita]],
	-- [[Malaui]], etc.; also with h, as in [[marihuana]], [[parihuela]], [[antihielo]], [[pelluhuano]], [[náhuatl]],
	-- etc.
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*h?)([iu])(" .. V .. ")",
		function (v1, iu, v2) return v1 .. vowel_to_glide[iu] .. v2 end
	)
	-- Divide VCV as V.CV; but don't divide if C == h, e.g. [[prohibir]] should be prohi.bir.
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*)(" .. C_NOT_H .. W .. "?" .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. ")(" .. C .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. "+)(" .. C .. C .. V .. ")", "%1.%2")
	-- Puerto Rico + most of Spain divide tl as t.l. Mexico and the Canary Islands have .tl. Unclear what other regions
	-- do. Here we choose to go with .tl. See https://catalog.ldc.upenn.edu/docs/LDC2019S07/Syllabification_Rules_in_Spanish.pdf
	-- and https://www.spanishdict.com/guide/spanish-syllables-and-syllabification-rules.
	text = rsub(text, "([pbfktɡ])%.([lɾ])", ".%1%2")
	text = text:gsub("d%.ɾ", ".dɾ")
	-- Per https://catalog.ldc.upenn.edu/docs/LDC2019S07/Syllabification_Rules_in_Spanish.pdf, tl at the end of a word
	-- (as in nahuatl, Popocatepetl etc.) is divided .tl from the previous vowel.
	text = text:gsub("([^.#])tl#", "%1.tl")
	text = rsub_repeatedly(text, "(" .. C .. ")%.s(" .. C .. ")", "%1s.%2")
	-- Any aeo, or stressed iu, should be syllabically divided from a following aeo or stressed iu.
	text = rsub_repeatedly(text, "([aeo]" .. accent_c .. "*)(h?[aeo])", "%1.%2")
	text = rsub_repeatedly(text, "([aeo]" .. accent_c .. "*)(h?" .. V .. stress_c .. ")", "%1.%2")
	text = rsub(text, "([iu]" .. stress_c .. ")(h?[aeo])", "%1.%2")
	text = rsub_repeatedly(text, "([iu]" .. stress_c .. ")(h?" .. V .. stress_c .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(i" .. accent_c .. "*)(h?i)", "%1.%2")
	text = rsub_repeatedly(text, "(u" .. accent_c .. "*)(h?u)", "%1.%2")

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
		words[j] = table.concat(syllables, ".")
	end

	text = table.concat(words, " ")

	text = rsub(text, "Y", "i") --final -uy
	text = rsub(text, "z", "s") --real sound of LatAm Z
	-- suppress syllable mark before IPA stress indicator
	text = rsub(text, "%.(" .. ipa_stress_c .. ")", "%1")
	--make all primary stresses but the last one be secondary
	text = rsub_repeatedly(text, "ˈ(.+)ˈ", "ˌ%1ˈ")

	if not initial_hi and rfind(text, "[ʎɟ]") then
		sheismo_different = true
	end
	if rioplat then
		if sheismo then
			text = rsub(text, "ɟ", "ʃ")
		else
			text = rsub(text, "ɟ", "ʒ")
		end
	end

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
			["ʒ"] = alveolopalatal,
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
		text = rsub(text, "([βðɣ])", "%1̞")

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
		["ɟ"] = phonetic and "ɟ͡ʝ" or "ʝ", -- fake "y" to real "y"
	}
	text = rsub(text, "[hħĉɟ]", final_conversions)

	-- remove # symbols at word and text boundaries
	text = rsub(text, "#", "")
	text = mw.ustring.toNFC(text)

	-- The values in `differences` are only accurate when the dialect is 'distincion-lleismo'
	-- because we look for sounds like /θ/ and /ʎ/ that are only present in that dialect.
	-- The calling code knows to only use this structure in conjunction with this dialect.
	-- but to make sure of this we set the structure to nil for other dialects.
	local differences = nil
	if dialect == "distincion-lleismo" then
		differences = {
			distincion_different = distincion_different,
			lleismo_different = lleismo_different,
			need_rioplat = initial_hi or sheismo_different,
			sheismo_different = sheismo_different,
		}
	end
	local ret = {
		text = text,
		differences = differences,
	}
	if do_debug == "yes" then
		ret.debug = table.concat(debug, " ||| ")
	end
	return ret
end

-- For bot usage; {{#invoke:es-pronunc|IPA_string|SPELLING|style=STYLE|phonetic=PHONETIC|debug=DEBUG}}
-- where
--
--   1. SPELLING is the word or respelling to generate pronunciation for;
--   2. required parameter style= indicates the pronunciation style to generate
--      (e.g. "distincion-yeismo" for distinción+yeísmo, as is common in Spain;
--      see the comment above export.IPA() above for the full list);
--   3. phonetic=1 specifies to generate the phonetic rather than phonemic pronunciation;
--   4. debug=1 includes debug text in the output.
function export.IPA_string(frame)
	local iparams = {
		[1] = {},
		["style"] = {required = true},
		["phonetic"] = {type = "boolean"},
		["debug"] = {type = "boolean"},
	}
	local iargs = require("Module:parameters").process(frame.args, iparams)
	local retval = export.IPA(iargs[1], iargs.style, iargs.phonetic, iargs.debug)
	return retval.text .. (retval.debug and " ||| " .. retval.debug or "")
end


-- Generate all relevant dialect pronunciations and group into styles. See the comment above about dialects and styles.
-- A "pronunciation" here could be for example the IPA phonemic/phonetic representation of the term or the IPA form of
-- the rhyme that the term belongs to. If `style_spec` is nil, this generates all styles for all dialects, but
-- `style_spec` can also be a style spec such as "seseo" or "distincion+yeismo" (see comment above) to restrict the
-- output. `dodialect` is a function of two arguments, `ret` and `dialect`, where `ret` is the return-value table (see
-- below), and `dialect` is a string naming a particular dialect, such as "distincion-lleismo" or "rioplatense-sheismo".
-- `dodialect` should side-effect the `ret` table by adding an entry to `ret.pronun` for the dialect in question.
--
-- The return value is a table of the form
--
-- {
--   pronun = {DIALECT = {PRONUN, PRONUN, ...}, DIALECT = {PRONUN, PRONUN, ...}, ...},
--   expressed_styles = {STYLE_GROUP, STYLE_GROUP, ...},
-- }
--
-- where:
-- 1. DIALECT is a string such as "distincion-lleismo" naming a specific dialect.
-- 2. PRONUN is a table describing a particular pronunciation. If the dialect is "distincion-lleismo", there should be
--    a field in this table named `differences`, but where other fields may vary depending on the type of pronunciation
--    (e.g. phonemic/phonetic or rhyme). See below for the form of the PRONUN table for phonemic/phonetic pronunciation
--    vs. rhyme and the form of the `differences` field.
-- 3. STYLE_GROUP is a table of the form {tag = "HIDDEN_TAG", styles = {INNER_STYLE, INNER_STYLE, ...}}. This describes
--    a group of related styles (such as those for Latin America) that by default (the "hidden" form) are displayed as
--    a single line, with an icon on the right to "open" the style group into the "shown" form, with multiple lines
--    for each style in the group. The tag of the style group is the text displayed before the pronunciation in the
--    default "hidden" form, such as "Spain" or "Latin America". It can have the special value of `false` to indicate
--    that no tag text is to be displayed. Note that the pronunciation shown in the default "hidden" form is taken
--    from the first style in the style group.
-- 4. INNER_STYLE is a table of the form {tag = "SHOWN_TAG", pronun = {PRONUN, PRONUN, ...}}. This describes a single
--    style (such as for the Andes Mountains in the case where the seseo+lleismo accent differs from all others), to
--    be shown on a single line. `tag` is the text preceding the displayed pronunciation, or `false` if no tag text
--    is to be displayed. PRONUN is a table as described above and describes a particular pronunciation.
--
-- The PRONUN table has the following form for the full phonemic/phonetic pronunciation:
--
-- {
--   phonemic = "PHONEMIC",
--   phonetic = "PHONETIC",
--   differences = {FLAG = BOOLEAN, FLAG = BOOLEAN, ...},
-- }
--
-- Here, `phonemic` is the phonemic pronunciation (displayed as /.../) and `phonetic` is the phonetic pronunciation
-- (displayed as [...]).
--
-- The PRONUN table has the following form for the rhyme pronunciation:
--
-- {
--   rhyme = "RHYME_PRONUN",
--   num_syl = {NUM, NUM, ...},
--   differences = {FLAG = BOOLEAN, FLAG = BOOLEAN, ...},
-- }
--
-- Here, `rhyme` is a phonemic pronunciation such as "ado" for [[abogado]] or "iʝa"/"iʎa" for [[tortilla]] (depending
-- on the dialect), and `num_syl` is a list of the possible numbers of syllables for the term(s) that have this rhyme
-- (e.g. {4} for [[abogado]], {3} for [[tortilla]] and {4, 5} for [[biología]], which may be syllabified as
-- bio.lo.gí.a or bi.o.lo.gí.a). `num_syl` is used to generate syllable-count categories such as
-- [[Category:Rhymes:Spanish/ia/4 syllables]] in addition to [[Category:Rhymes:Spanish/ia]]. `num_syl` may be nil to
-- suppress the generation of syllable-count categories; this is typically the case with multiword terms.
--
-- The value of the `differences` field in the PRONUN table (which, as noted above, only needs to be present for the
-- "distincion-lleismo" dialect, and otherwise should be nil) is a table containing flags indicating whether and how
-- the per-dialect pronunciations differ. This is an optimization to avoid having to generate all six dialectal
-- pronunciations and compare them. It has the following form:
--
-- {
--   distincion_different = BOOLEAN,
--   lleismo_different = BOOLEAN,
--   need_rioplat = BOOLEAN,
--   sheismo_different = BOOLEAN,
-- }
--
-- where:
-- 1. `distincion_different` should be `true` if the "distincion" and "seseo" pronunciations differ;
-- 2. `lleismo_different` should be `true` if the "lleismo" and "yeismo" pronunciations differ;
-- 3. `need_rioplat` should be `true` if the Rioplatense pronunciations differ from the seseo+yeismo pronunciation;
-- 4. `sheismo_different` should be `true` if the "sheismo" and "zheismo" pronunciations differ.
local function express_all_styles(style_spec, dodialect)
	local ret = {
		pronun = {},
		expressed_styles = {},
	}

	local need_rioplat

	-- Add a style object (see INNER_STYLE above) that represents a particular style to `ret.expressed_styles`.
	-- `hidden_tag` is the tag text to be used when the style group containing the style is in the default "hidden"
	-- state (e.g. "Spain", "Latin America" or false if there is only one style group and no tag text should be
	-- shown), while `tag` is the tag text to be used when the individual style is shown (e.g. a description such as
	-- "most of Spain and Latin America", "Andes Mountains" or "everywhere but Argentina and Uruguay").
	-- `representative_dialect` is one of the dialects that this style represents, and whose pronunciation is stored in
	-- the style object. `matching_styles` is a hyphen separated string listing the isoglosses described by this style.
	-- For example, if the term has an ''ll'' but no ''c/z'', the `tag` text for the yeismo pronunciation will be
	-- "most of Spain and Latin America" and `matching_styles` will be "distincion-seseo-yeismo", indicating that
	-- it corresponds to both the "distincion" and "seseo" isoglosses as well as the "yeismo" isogloss. This is used
	-- when a particular style spec is given. If `matching_styles` is omitted, it takes its value from
	-- `representative_dialect`; this is used when the style contains only a single dialect.
	local function express_style(hidden_tag, tag, representative_dialect, matching_styles)
		matching_styles = matching_styles or representative_dialect
		-- If the Rioplatense pronunciation isn't distinctive, add all Rioplatense isoglosses.
		if not need_rioplat then
			matching_styles = matching_styles .. "-rioplatense-sheismo-zheismo"
		end
		-- If style specified, make sure it matches the requested style.
		local style_matches
		if not style_spec then
			style_matches = true
		else
			local style_parts = rsplit(matching_styles, "%-")
			local or_styles = rsplit(style_spec, "%s*,%s*")
			for _, or_style in ipairs(or_styles) do
				local and_styles = rsplit(or_style, "%s*%+%s*")
				local and_matches = true
				for _, and_style in ipairs(and_styles) do
					local negate
					if and_style:find("^%-") then
						and_style = and_style:gsub("^%-", "")
						negate = true
					end
					local this_style_matches = false
					for _, part in ipairs(style_parts) do
						if part == and_style then
							this_style_matches = true
							break
						end
					end
					if negate then
						this_style_matches = not this_style_matches
					end
					if not this_style_matches then
						and_matches = false
					end
				end
				if and_matches then
					style_matches = true
					break
				end
			end
		end
		if not style_matches then
			return
		end

		-- Fetch the representative dialect's pronunciation if not already present.
		if not ret.pronun[representative_dialect] then
			dodialect(ret, representative_dialect)
		end
		-- Insert the new style into the style group, creating the group if necessary.
		local new_style = {
			tag = tag,
			pronun = ret.pronun[representative_dialect],
		}
		for _, hidden_tag_style in ipairs(ret.expressed_styles) do
			if hidden_tag_style.tag == hidden_tag then
				table.insert(hidden_tag_style.styles, new_style)
				return
			end
		end
		table.insert(ret.expressed_styles, {
			tag = hidden_tag,
			styles = {new_style},
		})
	end

	-- For each type of difference, figure out if the difference exists in any of the given respellings. We do this by
	-- generating the pronunciation for the dialect "distincion-lleismo", for each respelling. In the process of
	-- generating the pronunciation for a given respelling, it computes how the other dialects for that respelling
	-- differ. Then we take the union of these differences across the respellings.
	dodialect(ret, "distincion-lleismo")
	local differences = {}
	for _, difftype in ipairs { "distincion_different", "lleismo_different", "need_rioplat", "sheismo_different" } do
		for _, pronun in ipairs(ret.pronun["distincion-lleismo"]) do
			if pronun.differences[difftype] then
				differences[difftype] = true
			end
		end
	end
	local distincion_different = differences.distincion_different
	local lleismo_different = differences.lleismo_different
	need_rioplat = differences.need_rioplat
	local sheismo_different = differences.sheismo_different

	-- Now, based on the observed differences, figure out how to combine the individual dialects into styles and
	-- style groups.
	if not distincion_different and not lleismo_different then
		if not need_rioplat then
			express_style(false, false, "distincion-lleismo", "distincion-seseo-lleismo-yeismo")
		else
			express_style(false, "everywhere but Argentina and Uruguay", "distincion-lleismo",
			"distincion-seseo-lleismo-yeismo")
		end
	elseif distincion_different and not lleismo_different then
		express_style("Spain", "Spain", "distincion-lleismo", "distincion-lleismo-yeismo")
		express_style("Latin America", "Latin America", "seseo-lleismo", "seseo-lleismo-yeismo")
	elseif not distincion_different and lleismo_different then
		express_style(false, "most of Spain and Latin America", "distincion-yeismo", "distincion-seseo-yeismo")
		express_style(false, "rural northern Spain, Andes Mountains", "distincion-lleismo", "distincion-seseo-lleismo")
	else
		express_style("Spain", "most of Spain", "distincion-yeismo")
		express_style("Latin America", "most of Latin America", "seseo-yeismo")
		express_style("Spain", "rural northern Spain", "distincion-lleismo")
		express_style("Latin America", "Andes Mountains", "seseo-lleismo")
	end
	if need_rioplat then
		local hidden_tag = distincion_different and "Latin America" or false
		if sheismo_different then
			express_style(hidden_tag, "Buenos Aires and environs", "rioplatense-sheismo", "seseo-rioplatense-sheismo")
			express_style(hidden_tag, "elsewhere in Argentina and Uruguay", "rioplatense-zheismo", "seseo-rioplatense-zheismo")
		else
			express_style(hidden_tag, "Argentina and Uruguay", "rioplatense-sheismo", "seseo-rioplatense-sheismo-zheismo")
		end
	end

	-- If only one style group, don't indicate the style.
	-- Not clear we want this in reality.
	--if #ret.expressed_styles == 1 then
	--	ret.expressed_styles[1].tag = false
	--	if #ret.expressed_styles[1].styles == 1 then
	--		ret.expressed_styles[1].styles[1].tag = false
	--	end
	--end

	return ret
end


local function format_all_styles(expressed_styles, format_style)
	for i, style_group in ipairs(expressed_styles) do
		if #style_group.styles == 1 then
			style_group.formatted, style_group.formatted_len =
				format_style(style_group.styles[1].tag, style_group.styles[1], i == 1)
		else
			style_group.formatted, style_group.formatted_len =
				format_style(style_group.tag, style_group.styles[1], i == 1)
			for j, style in ipairs(style_group.styles) do
				style.formatted, style.formatted_len =
					format_style(style.tag, style, i == 1 and j == 1)
			end
		end
	end

	local maxlen = 0
	for i, style_group in ipairs(expressed_styles) do
		local this_len = style_group.formatted_len
		if #style_group.styles > 1 then
			for _, style in ipairs(style_group.styles) do
				this_len = math.max(this_len, style.formatted_len)
			end
		end
		maxlen = math.max(maxlen, this_len)
	end

	local lines = {}

	for i, style_group in ipairs(expressed_styles) do
		if #style_group.styles == 1 then
			table.insert(lines, style_group.formatted)
		else
			local inline = '\n<div class="vsShow" style="display:none">\n' .. style_group.formatted .. "</div>"
			local full_prons = {}
			for _, style in ipairs(style_group.styles) do
				table.insert(full_prons, style.formatted)
			end
			local full = '\n<div class="vsHide">\n' .. table.concat(full_prons, "\n") .. "</div>"
			local em_length = math.floor(maxlen * 0.68) -- from [[Module:grc-pronunciation]]
			table.insert(lines, '<div class="vsSwitcher" data-toggle-category="pronunciations" style="width: ' .. em_length .. 'em; max-width:100%;"><span class="vsToggleElement" style="float: right;">&nbsp;</span>' .. inline .. full .. "</div>")
		end
	end

	-- major hack to get bullets working on the next line
	return table.concat(lines, "\n") .. "\n<span></span>"
end


local function dodialect_pronun(args, ret, dialect)
	ret.pronun[dialect] = {}
	for i, term in ipairs(args.terms) do
		local phonemic = export.IPA(term, dialect, false, args.debug)
		local phonetic = export.IPA(term, dialect, true, args.debug)
		ret.pronun[dialect][i] = {
			phonemic = phonemic.text,
			phonetic = phonetic.text,
			differences = phonemic.differences,
		}
	end
end

local function generate_pronun(args)
	local function this_dodialect_pronun(ret, dialect)
		dodialect_pronun(args, ret, dialect)
	end

	local ret = express_all_styles(args.style, this_dodialect_pronun)

	local function format_style(tag, expressed_style, is_first)
		local pronunciations = {}
		for j, pronun in ipairs(expressed_style.pronun) do
			table.insert(pronunciations, {
				-- don't display syllable division markers in phonemic
				pron = "/" .. pronun.phonemic:gsub("%.", "") .. "/",
				qualifiers = j == 1 and tag and {tag} or nil,
			})
			table.insert(pronunciations, {
				pron = "[" .. pronun.phonetic .. "]",
				separator = j > 1 and " " or nil,
			})
		end
		local bullet = string.rep("*", args.bullets) .. " "
		local pre = is_first and args.pre and args.pre .. " " or ""
		local post = is_first and (args.ref or "") .. (args.post and " " .. args.post or "") or ""
		local formatted = bullet .. pre .. m_IPA.format_IPA_full(lang, pronunciations) .. post
		local formatted_for_len_parts = {}
		table.insert(formatted_for_len_parts, bullet .. pre .. "IPA(key): " .. (tag and "(" .. tag .. ") " or ""))
		for j, pronun in ipairs(expressed_style.pronun) do
			if j > 1 then
				table.insert(formatted_for_len_parts, ", ")
			end
			-- don't display syllable division markers in phonemic
			table.insert(formatted_for_len_parts, "/" .. pronun.phonemic:gsub("%.", "") .. "/ [" ..
				pronun.phonetic .. "]")
		end
		table.insert(formatted_for_len_parts, post)
		return formatted, ulen(table.concat(formatted_for_len_parts))
	end

	ret.text = format_all_styles(ret.expressed_styles, format_style)

	return ret
end


-- External entry point for {{es-IPA}}.
function export.show(frame)
	local params = {
		[1] = {},
		["debug"] = {type = "boolean"},
		["pre"] = {},
		["post"] = {},
		["ref"] = {},
		["style"] = {},
		["bullets"] = {type = "number", default = 1},
	}
	local parargs = frame:getParent().args
	local args = require("Module:parameters").process(parargs, params)
	local text = args[1] or mw.title.getCurrentTitle().text
	args.terms = {text}
	local ret = generate_pronun(args)
	return ret.text
end


local function split_syllabified_spelling(spelling)
	return rsplit(spelling, "%.")
end

local function generate_hyph_obj(term)
	return {syllabification = term, hyph = split_syllabified_spelling(term)}
end

local function syllabify_from_spelling(text)
	-- decompose everything but ñ and ü
	text = mw.ustring.toNFD(text)
	text = rsub(text, ".[" .. TILDE .. DIA .. "]", {
		["n" .. TILDE] = "ñ",
		["N" .. TILDE] = "Ñ",
		["u" .. DIA] = "ü",
		["U" .. DIA] = "Ü",
	})
	local TEMP_I = u(0xFFF1)
	local TEMP_U = u(0xFFF2)
	local TEMP_Y_CONS = u(0xFFF3)
	local TEMP_CH = u(0xFFF4)
	local TEMP_LL = u(0xFFF5)
	local TEMP_RR = u(0xFFF6)
	local TEMP_QU = u(0xFFF7)
	local TEMP_QU_CAPS = u(0xFFF8)
	local TEMP_GU = u(0xFFF9)
	local TEMP_GU_CAPS = u(0xFFFA)
	local TEMP_SH = u(0xFFFB)
	local TEMP_DESH = u(0xFFFC)
	local vowel = "aeiouüyAEIOUÜY"
	local V = "[" .. vowel .. "]" -- vowel class
	local separator = accent .. ipa_stress .. "# %-." .. SYLDIV
	local C = "[^" .. vowel .. separator .. "]" -- consonant class including h
	local C_NOT_H = "[^" .. vowel .. separator .. "h]" -- consonant class not including h
	-- Change user-specified . into SYLDIV so we don't shuffle it around when dividing into syllables.
	text = text:gsub("%.", SYLDIV)
	text = rsub(text, "y(" .. V .. ")", TEMP_Y_CONS .. "%1")
	-- We don't want to break -sh- except in desh-, e.g. [[deshuesar]], [[deshonra]], [[deshecho]].
	text = text:gsub("^([Dd])esh", "%1" .. TEMP_DESH)
	text = text:gsub("([ %-][Dd])esh", "%1" .. TEMP_DESH)
	text = text:gsub("sh", TEMP_SH)
	text = text:gsub(TEMP_DESH, "esh")
	text = text:gsub("ch", TEMP_CH)
	text = text:gsub("ll", TEMP_LL)
	text = text:gsub("rr", TEMP_RR)
	-- qu mostly handled correctly automatically, but not in quietud
	text = rsub(text, "qu(" .. V .. ")", TEMP_QU .. "%1")
	text = rsub(text, "Qu(" .. V .. ")", TEMP_QU_CAPS .. "%1")
	text = rsub(text, "gu(" .. V .. ")", TEMP_GU .. "%1")
	text = rsub(text, "Gu(" .. V .. ")", TEMP_GU_CAPS .. "%1")
	local vowel_to_glide = { ["i"] = TEMP_I, ["u"] = TEMP_U }
	-- i and u between vowels -> consonant-like substitutions: [[paranoia]], [[baiano]], [[abreuense]], [[alauita]],
	-- [[Malaui]], etc.; also with h, as in [[marihuana]], [[parihuela]], [[antihielo]], [[pelluhuano]], [[náhuatl]],
	-- etc.
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*h?)([iu])(" .. V .. ")",
		function (v1, iu, v2) return v1 .. vowel_to_glide[iu] .. v2 end
	)
	-- Divide VCV as V.CV; but don't divide if C == h, e.g. [[prohibir]] should be prohi.bir.
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*)(" .. C_NOT_H .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. ")(" .. C .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. "+)(" .. C .. C .. V .. ")", "%1.%2")
	-- Puerto Rico + most of Spain divide tl as t.l. Mexico and the Canary Islands have .tl. Unclear what other regions
	-- do. Here we choose to go with .tl. See https://catalog.ldc.upenn.edu/docs/LDC2019S07/Syllabification_Rules_in_Spanish.pdf
	-- and https://www.spanishdict.com/guide/spanish-syllables-and-syllabification-rules.
	text = rsub(text, "([pbfvkctg])%.([lr])", ".%1%2")
	text = text:gsub("d%.r", ".dr")
	-- Per https://catalog.ldc.upenn.edu/docs/LDC2019S07/Syllabification_Rules_in_Spanish.pdf, tl at the end of a word
	-- (as in nahuatl, Popocatepetl etc.) is divided .tl from the previous vowel.
	text = text:gsub("([^. %-])tl$", "%1.tl")
	text = text:gsub("([^. %-])(tl[ %-])", "%1.%2")
	text = rsub_repeatedly(text, "(" .. C .. ")%.s(" .. C .. ")", "%1s.%2")
	-- Any aeo, or stressed iuüy, should be syllabically divided from a following aeo or stressed iuüy.
	text = rsub_repeatedly(text, "([aeoAEO]" .. accent_c .. "*)(h?[aeo])", "%1.%2")
	text = rsub_repeatedly(text, "([aeoAEO]" .. accent_c .. "*)(h?" .. V .. stress_c .. ")", "%1.%2")
	text = rsub(text, "([iuüyIUÜY]" .. stress_c .. ")(h?[aeo])", "%1.%2")
	text = rsub_repeatedly(text, "([iuüyIUÜY]" .. stress_c .. ")(h?" .. V .. stress_c .. ")", "%1.%2")
	text = rsub_repeatedly(text, "([iI]" .. accent_c .. "*)(h?i)", "%1.%2")
	text = rsub_repeatedly(text, "([uU]" .. accent_c .. "*)(h?u)", "%1.%2")
	text = text:gsub(SYLDIV, ".")
	text = text:gsub(TEMP_I, "i")
	text = text:gsub(TEMP_U, "u")
	text = text:gsub(TEMP_Y_CONS, "y")
	text = text:gsub(TEMP_CH, "ch")
	text = text:gsub(TEMP_SH, "sh")
	text = text:gsub(TEMP_LL, "ll")
	text = text:gsub(TEMP_RR, "rr")
	text = text:gsub(TEMP_QU, "qu")
	text = text:gsub(TEMP_QU_CAPS, "Qu")
	text = text:gsub(TEMP_GU, "gu")
	text = text:gsub(TEMP_GU_CAPS, "Gu")
	text = mw.ustring.toNFC(text)
	-- No qualifiers from dialect tags because we assume all dialects hyphenate the same way.
	-- FIXME: There are region-specific ways of hyphenating -tl-. See above. We don't currently handle this properly.
	return text
end


local function all_words_have_vowels(term)
	local words = rsplit(term, "[ %-]")
	for _, word in ipairs(words) do
		word = ulower(mw.ustring.toNFD(word))
		if not rfind(word, V) then
			return false
		end
	end
	return true
end


local function dodialect_specified_rhymes(rhymes, hyphs, rhyme_ret, dialect)
	rhyme_ret.pronun[dialect] = {}
	for _, rhyme in ipairs(rhymes) do
		local num_syl = {}
		for _, hyph in ipairs(hyphs) do
			if not hyph:find("[%s%-]") then
				local this_num_syl = 1 + ulen(rsub(hyph, "[^.]", ""))
				m_table.insertIfNot(num_syl, this_num_syl)
			end
		end
		if #num_syl == 0 then
			num_syl = nil
		end
		local rhyme_diffs = nil
		if dialect == "distincion-lleismo" then
			rhyme_diffs = {
				distincion_different = false,
				lleismo_different = false,
				sheismo_different = false,
				need_rioplat = false,
			}
		end
		table.insert(rhyme_ret.pronun[dialect], {
			rhyme = rhyme,
			num_syl = num_syl,
			differences = rhyme_diffs,
		})
	end
end


local function parse_rhyme_hyph_homophone(arg, put, parse_err, generate_obj, param_mods)
	local retval = {}

	if arg:find("<") then
		if not put then
			put = require("Module:parse utilities")
		end

		local function get_valid_prefixes()
			local valid_prefixes = {}
			for param_mod, _ in pairs(param_mods) do
				table.insert(valid_prefixes, param_mod)
			end
			table.insert(valid_prefixes, "q")
			table.sort(valid_prefixes)
			return valid_prefixes
		end

		local segments = put.parse_balanced_segment_run(arg, "<", ">")
		local comma_separated_groups = put.split_alternating_runs_on_comma(segments)
		for _, group in ipairs(comma_separated_groups) do
			local obj = generate_obj(group[1])
			for j = 2, #group - 1, 2 do
				if group[j + 1] ~= "" then
					parse_err("Extraneous text '" .. group[j + 1] .. "' after modifier")
				end
				local modtext = group[j]:match("^<(.*)>$")
				if not modtext then
					parse_err("Internal error: Modifier '" .. group[j] .. "' isn't surrounded by angle brackets")
				end
				local prefix, val = modtext:match("^([a-z]+):(.*)$")
				if not prefix then
					local valid_prefixes = get_valid_prefixes()
					for i, valid_prefix in ipairs(valid_prefixes) do
						valid_prefixes[i] = "'" .. valid_prefix .. ":'"
					end
					parse_err("Modifier " .. group[j] .. " lacks a prefix, should begin with one of " ..
						m_table.serialCommaJoin(valid_prefixes))
				end
				if prefix == "q" then
					if not obj.qualifiers then
						obj.qualifiers = {}
					end
					table.insert(obj.qualifiers, val)
				elseif param_mods[prefix] then
					local key = param_mods[prefix].item_dest or prefix
					if obj[key] then
						parse_err("Modifier '" .. prefix .. "' specified more than once")
					end
					local convert = param_mods[prefix].convert
					if convert then
						obj[key] = convert(val)
					else
						obj[key] = val
					end
				else
					local valid_prefixes = get_valid_prefixes()
					for i, valid_prefix in ipairs(valid_prefixes) do
						valid_prefixes[i] = "'" .. valid_prefix .. "'"
					end
					parse_err("Unrecognized prefix '" .. prefix .. "' in modifier " .. group[j]
						.. ", should be " .. m_table.serialCommaJoin(valid_prefixes))
				end
			end
			table.insert(retval, obj)
		end
	else
		for _, term in split_on_comma(arg) do
			table.insert(retval, generate_obj(term))
		end
	end

	return retval
end


local function parse_rhyme(arg, put, parse_err)
	local function generate_obj(term)
		return {rhyme = term}
	end
	local param_mods = {
		s = {
			item_dest = "num_syl",
			convert = function(arg)
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

	return parse_rhyme_hyph_homophone(arg, put, parse_err, generate_obj, param_mods)
end


local function parse_hyph(arg, put, parse_err)
	-- None other than qualifiers
	local param_mods = {}

	return parse_rhyme_hyph_homophone(arg, put, parse_err, generate_hyph_obj, param_mods)
end


local function parse_homophone(arg, put, parse_err)
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

	return parse_rhyme_hyph_homophone(arg, put, parse_err, generate_obj, param_mods)
end


-- External entry point for {{es-pr}}.
function export.show_pr(frame)
	local params = {
		[1] = {list = true},
		["rhyme"] = {},
		["hyph"] = {},
		["hmp"] = {},
		["pagename"] = {},
	}
	local parargs = frame:getParent().args
	local args = require("Module:parameters").process(parargs, params)
	local pagename = args.pagename or mw.title.getCurrentTitle().subpageText

	-- Parse the arguments.
	local respellings = #args[1] > 0 and args[1] or {"+"}
	local parsed_respellings = {}
	local function overall_parse_err(msg, arg, val)
		error(msg .. ": " .. arg .. "= " .. val)
	local overall_rhyme = args.rhyme and
		parse_rhyme(args.rhyme, nil, function(msg) overall_parse_err(msg, "rhyme", args.rhyme) end) or nil
	local overall_hyph = args.hyph and
		parse_hyph(args.hyph, nil, function(msg) overall_parse_err(msg, "hyph", args.hyph) end) or nil
	local overall_hmp = args.hmp and
		parse_homophone(args.hmp, nil, function(msg) overall_parse_err(msg, "hmp", args.hmp) end) or nil
	local put
	for i, respelling in ipairs(respellings) do
		if respelling:find("<") then
			local function parse_err(msg)
				error(msg .. ": " .. i .. "= " .. respelling)
			end
			if not put then
				put = require("Module:parse utilities")
			end
			local run = put.parse_balanced_segment_run(respelling, "<", ">")
			local terms = substitute_plus(split_on_comma(run[1]), pagename)
			local parsed = {terms = terms, audio = {}, rhyme = {}, hyph = {}}
			for j = 2, #run - 1, 2 do
				if run[j + 1] ~= "" then
					parse_err("Extraneous text '" .. run[j + 1] .. "' after modifier")
				end
				local modtext = run[j]:match("^<(.*)>$")
				if not modtext then
					parse_err("Internal error: Modifier '" .. run[j] .. "' isn't surrounded by angle brackets")
				end
				local prefix, arg = modtext:match("^([a-z]+):(.*)$")
				if not prefix then
					parse_err("Modifier " .. run[j] .. " lacks a prefix, should begin with one of " ..
						"'pre', 'post', 'ref', 'bullets', 'audio', 'rhyme', 'hyph', 'hmp' or 'style'")
				end
				if prefix == "pre" or prefix == "post" or prefix == "ref" or prefix == "bullets"
					or prefix == "style" then
					if parsed[prefix] then
						parse_err("Modifier '" .. prefix .. "' occurs twice, second occurrence " .. run[j])
					end
					if prefix == "bullets" then
						if not arg:find("^[0-9]+$") then
							parse_err("Modifier 'bullets' should have a number as argument")
						end
						parsed.bullets = tonumber(arg)
					else
						parsed[prefix] = arg
					end
				elseif prefix == "rhyme" or prefix == "hyph" or prefix == "hmp" then
					local parse_fun = prefix == "rhyme" and parse_rhyme or prefix == "hyph" and parse_hyph or
						parse_homophone
					local vals = parse_fun(arg, put, parse_err)
					for _, val in ipairs(vals) do
						table.insert(parsed[prefix], val)
					end
				elseif prefix == "audio" then
					local file, gloss = arg:match("^(.-)%s*;%s*(.*)$")
					if not file then
						file = arg
						gloss = "Audio"
					end
					table.insert(parsed.audio, {file = file, gloss = gloss})
				else
					parse_err("Unrecognized prefix '" .. prefix .. "' in modifier " .. run[j])
				end
			end
			if not parsed.bullets then
				parsed.bullets = 1
			end
			table.insert(parsed_respellings, parsed)
		else
			table.insert(parsed_respellings, {
				terms = substitute_plus(split_on_comma(respelling), pagename),
				audio = {},
				rhyme = {},
				hyph = {},
				bullets = 1,
			})
		end
	end

	if overall_hyph then
		local hyphs = {}
		for _, hyph in ipairs(overall_hyph) do
			if hyph.syllabification == "+" then
				hyph.syllabification = syllabify_from_spelling(pagename)
				hyph.hyph = split_syllabified_spelling(hyph.syllabification)
			elseif hyph.syllabification == "-" then
				overall_hyph = {}
				break
			end
		end
	end

	-- Loop over individual respellings, processing each.
	for _, parsed in ipairs(parsed_respellings) do
		parsed.pronun = generate_pronun(parsed)
		local saw_space = false
		for _, term in ipairs(parsed.terms) do
			if term:find("[%s%-]") then
				saw_space = true
				break
			end
		end

		local this_no_rhyme = m_table.contains(parsed.rhyme, "-")

		if #parsed.hyph == 0 then
			if not overall_hyph and all_words_have_vowels(pagename) then
				for _, term in ipairs(parsed.terms) do
					if term:gsub("%.", "") == pagename then
						m_table.insertIfNot(hyphs, generate_hyph_obj(syllabify_from_spelling(term)))
					end
				end
			end
		else
			for _, hyph in ipairs(parsed.hyph) do
				if hyph.syllabification == "+" then
					for _, term in ipairs(parsed.terms) do
						hyph.syllabification = syllabify_from_spelling(term)
						hyph.hyph = split_syllabified_spelling(hyph.syllabification)
						m_table.insertIfNot(hyphs, syllabify_from_spelling(term))
					end
				elseif hyph.syllabification == "-" then
					parsed.hyph = {}
					break
				end
			end
		end

		-- Generate the rhymes.
		local function dodialect_rhymes_from_pronun(rhyme_ret, dialect)
			rhyme_ret.pronun[dialect] = {}
			-- It's possible the pronunciation for a passed-in dialect was never generated. This happens e.g. with
			-- {{es-pr|cebolla<style:seseo>}}. The initial call to generate_pronun() fails to generate a pronunciation
			-- for the dialect 'distinction-yeismo' because the pronunciation of 'cebolla' differs between distincion
			-- and seseo and so the seseo style restriction rules out generation of pronunciation for distincion
			-- dialects (other than 'distincion-lleismo', which always gets generated so as to determine on which axes
			-- the dialects differ). However, when generating the rhyme, it is based only on -olla, whose pronunciation
			-- does not differ between distincion and seseo, but does differ between lleismo and yeismo, so it needs to
			-- generate a yeismo-specific rhyme, and 'distincion-yeismo' is the representative dialect for yeismo in the
			-- situation where distincion and seseo do not have distinct results (based on the following line in
			-- express_all_styles()):
			--   express_style(false, "most of Spain and Latin America", "distincion-yeismo", "distincion-seseo-yeismo")
			-- In this case we need to generate the missing overall pronunciation ourselves since we need it to generate
			-- the dialect-specific rhyme pronunciation.
			if not parsed.pronun.pronun[dialect] then
				dodialect_pronun(parsed, parsed.pronun, dialect)
			end
			for _, pronun in ipairs(parsed.pronun.pronun[dialect]) do
				if all_words_have_vowels(pronun.phonemic) then
					-- Count number of syllables by looking at syllable boundaries (including stress marks).
					local num_syl = ulen(rsub(pronun.phonemic, "[^.ˌˈ]", "")) + 1
					-- Get the rhyme by truncating everything up through the last stress mark + any following
					-- consonants, and remove syllable boundary markers.
					local rhyme = rsub(rsub(pronun.phonemic, ".*[ˌˈ]", ""), "^[^" .. vowel .. "]*", "")
						:gsub("%.", ""):gsub("t͡ʃ", "tʃ")
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
						local rhyme_diffs = nil
						if dialect == "distincion-lleismo" then
							rhyme_diffs = {}
							if rhyme:find("θ") then
								rhyme_diffs.distincion_different = true
							end
							if rhyme:find("ʎ") then
								rhyme_diffs.lleismo_different = true
							end
							if rfind(rhyme, "[ʎɟ]") then
								rhyme_diffs.sheismo_different = true
								rhyme_diffs.need_rioplat = true
							end
						end
						table.insert(rhyme_ret.pronun[dialect], {
							rhyme = rhyme,
							num_syl = {num_syl},
							differences = rhyme_diffs,
						})
					end
				end
			end
		end

		if #parsed.rhyme == 0 then
			if overall_rhyme or saw_space then
				parsed.rhyme = nil
			else
				parsed.rhyme = express_all_styles(parsed.style, dodialect_rhymes_from_pronun)
			end
		else
			local function this_dodialect(rhyme_ret, dialect)
				return dodialect_specified_rhymes(parsed.rhyme, parsed.hyph, rhyme_ret, dialect)
			end
			parsed.rhyme = express_all_styles(parsed.style, this_dodialect)
		end
	end

	if overall_rhyme then
		if m_table.contains(overall_rhyme, "-") then
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
				return dodialect_specified_rhymes(overall_rhyme, all_hyphs, rhyme_ret, dialect)
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
				table.insert(rhymes, {rhyme = pronun.rhyme, num_syl = pronun.num_syl})
			end
			local data = {
				lang = lang,
				rhymes = rhymes,
				qualifiers = tag and {tag} or nil,
			}
			local bullet = string.rep("*", num_bullets) .. " "
			local formatted = bullet .. require("Module:rhymes").format_rhymes(data)
			local formatted_for_len_parts = {}
			table.insert(formatted_for_len_parts, bullet .. "Rhymes: " .. (tag and "(" .. tag .. ") " or ""))
			for j, pronun in ipairs(expressed_style.pronun) do
				if j > 1 then
					table.insert(formatted_for_len_parts, ", ")
				end
				table.insert(formatted_for_len_parts, "-" .. pronun.rhyme)
			end
			return formatted, ulen(table.concat(formatted_for_len_parts))
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
		local hyphtext = require("Module:hyphenation").format_hyphenations { lang = lang, hyphs = hyphs }
		return string.rep("*", num_bullets) .. " " .. hyphtext
	end

	local function format_homophones(hmps, num_bullets)
		local hmptext = require("Module:homophones").format_homophones { lang = lang, homophones = hmps }
		return string.rep("*", num_bullets) .. " " .. hmptext
	end

	local function format_audio(audios, num_bullets)
		local ret = {}
		for i, audio in ipairs(audios) do
			-- FIXME! There should be a module for this.
			table.insert(ret, string.rep("*", num_bullets) .. " " .. frame:expandTemplate {
				title = "audio", args = {"es", audio.file, audio.gloss }})
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

	return table.concat(textparts)
end


return export
