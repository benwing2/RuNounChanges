local export = {}

local m_IPA = require("Module:IPA")

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


-- ɟ and ĉ are used internally to represent [ʝ⁓ɟ͡ʝ] and [t͡ʃ]
--
-- dialect == one of the following:
-- "distincion-lleismo": distinción + lleísmo
-- "distincion-yeismo": distinción + yeísmo
-- "seseo-lleismo": seseo + lleísmo
-- "seseo-yeismo": seseo + yeísmo
-- "rioplatense-sheismo": Rioplatense with /ʃ/ (Buenos Aires)
-- "rioplatense-zheismo": Rioplatense with /ʒ/
function export.IPA(text, dialect, phonetic, include_syllable_markers, do_debug)
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
	-- i and u between vowels -> j and w ([[paranoia]], [[baiano]], [[abreuense]], [[alauita]], [[Malaui]], etc.)
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*)([iu])(" .. V .. ")",
		function (v1, iu, v2) return v1 .. vowel_to_glide[iu] .. v2 end
	)
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*)(" .. C .. W .. "?" .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. ")(" .. C .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. "+)(" .. C .. C .. V .. ")", "%1.%2")
	text = rsub(text, "([pbktdɡ])%.([lɾ])", ".%1%2")
	text = rsub_repeatedly(text, "(" .. C .. ")%.s(" .. C .. ")", "%1s.%2")
	-- Any aeo, or stressed iu, should be syllabically divided from a following aeo or stressed iu.
	text = rsub_repeatedly(text, "([aeo]" .. accent_c .. "*)([aeo])", "%1.%2")
	text = rsub_repeatedly(text, "([aeo]" .. accent_c .. "*)(" .. V .. stress_c .. ")", "%1.%2")
	text = rsub(text, "([iu]" .. stress_c .. ")([aeo])", "%1.%2")
	text = rsub_repeatedly(text, "([iu]" .. stress_c .. ")(" .. V .. stress_c .. ")", "%1.%2")
	text = rsub_repeatedly(text, "i(" .. accent_c .. "*)i", "i%1.i")
	text = rsub_repeatedly(text, "u(" .. accent_c .. "*)u", "u%1.u")

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
		["include-syllable-markers"] = {type = "boolean"},
		["debug"] = {type = "boolean"},
	}
	local iargs = require("Module:parameters").process(frame.args, iparams)
	local retval = export.IPA(iargs[1], iargs.style, iargs.phonetic,
		iargs["include-syllable-markers"], iargs.debug)
	return retval.text .. (retval.debug and " ||| " .. retval.debug or "")
end


local function express_all_styles(args, dodialect)
	local ret = {
		pronun = {},
		expressed_styles = {},
	}

	local need_rioplat

	local function express_style(hidden_tag, tag, representative_dialect, matching_styles)
		matching_styles = matching_styles or representative_dialect
		if not need_rioplat and not matching_styles:find("rioplatense") then
			matching_styles = matching_styles .. "-rioplatense-sheismo-zheismo"
		end
		-- If style specified, make sure it matches the requested style.
		local style_matches
		if not args.style then
			style_matches = true
		else
			local style_parts = rsplit(matching_styles, "%-")
			local or_styles = rsplit(args.style, "%s*,%s*")
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

		if not ret.pronun[representative_dialect] then
			dodialect(ret, representative_dialect)
		end
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
	for _, difftype in ipairs("distincion_different", "lleismo_different", "need_rioplat", "sheismo_different") do
		for _, pronun in ipairs(ret.pronun["distincion-lleismo"]) do
			if pronun.differences[difftype] then
				pronun[difftype] = true
			end
		end
	end
	local distincion_different = differences.distincion_different
	local lleismo_different = differences.lleismo_different
	need_rioplat = differences.need_rioplat
	local sheismo_different = differences.sheismo_different

	-- Now, based on the observed differences, figure out how to combine the individual styles into
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

	return table.concat(lines, "\n")
end


local function generate_pronun(args)
	-- About styles, dialects and isoglosses:
	--
	-- From the standpoint of pronunciation, a given dialect is defined by isoglosses, which specify differences
	-- in the way of pronouncing certain phonemes. You can think of a dialect as a collection of isoglosses.
	-- For example, one isogloss is "distinción" (pronouncing written ''s'' and ''c/z'' differently) vs. "seseo"
	-- (pronouncing them the same). Another is "lleísmo" (pronouncing written ''ll'' and ''y'' differently) vs.
	-- "yeísmo" (pronouncing them the same). The dominant pronunciation in Spain can be described as
	-- distinción + yeísmo, while the pronunciation in rural northern Spain can be described as distinción + lléismo
	-- and the pronunciation across much of the Andes mountains can be described as seseo + lléismo.
	--
	-- A "style" here is a set of dialects that pronounce a given word in a given fashion. For example, if we are only
	-- considering the distinción/seseo and lleísmo/yeísmo isoglosses, there are four conceivable dialects (all of
	-- which in fact exist). However, for a given word, more than one dialect may pronounce it the same. For
	-- example, a word like [[paz]] has a ''z'' but no ''ll'', and so there are only two possible pronunciations for
	-- the four dialects. Here, the two styles are "Spain" and "Latin America". Correspondingly, a word like [[pollo]]
	-- with an ''ll'' but no ''z'' has two styles, which can approximately be described as "most of Spain and Latin
	-- America" vs. "rural northern Spain, Andes Mountains".
	local function dodialect(ret, dialect)
		ret.pronun[dialect] = {}
		for i, term in ipairs(args.terms) do
			local phonemic = export.IPA(term, dialect, false, true, args.debug)
			local phonetic = export.IPA(term, dialect, true, true, args.debug)
			ret.pronun[dialect][i] = {
				phonemic = phonemic.text,
				phonetic = phonetic.text,
				differences = phonemic.differences,
			}
		end
	end

	local ret = express_all_styles(args, dodialect)

	-- If only one style group, don't indicate the style.
	if #ret.expressed_styles == 1 then
		ret.expressed_styles[1].tag = false
		if #ret.expressed_styles[1].styles == 1 then
			ret.expressed_styles[1].styles[1].tag = false
		end
	end

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


local function divide_syllables_on_spelling(text)
	-- decompose everything but ñ and ü
	text = mw.ustring.toNFD(text)
	text = rsub(text, ".[" .. TILDE .. DIA .. "]", {
		["n" .. TILDE] = "ñ",
		["u" .. DIA] = "ü",
	}
	local TEMP_I = u(0xFFF1)
	local TEMP_U = u(0xFFF2)
	local TEMP_Y_CONS = u(0xFFF3)
	local TEMP_CH = u(0xFFF4)
	local TEMP_LL = u(0xFFF5)
	local TEMP_RR = u(0xFFF6)
	-- Change user-specified . into SYLDIV so we don't shuffle it around when dividing into syllables.
	text = text:gsub("%.", SYLDIV)
	text = rsub(text, "y(" .. V .. ")", TEMP_Y_CONS .. "%1")
	text = text:gsub("ch", TEMP_CH)
	text = text:gsub("ll", TEMP_LL)
	text = text:gsub("rr", TEMP_RR)
	--syllable division
	local vowel_to_glide = { ["i"] = TEMP_I, ["u"] = TEMP_U }
	-- i and u between vowels -> j and w ([[paranoia]], [[baiano]], [[abreuense]], [[alauita]], [[Malaui]], etc.)
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*)([iu])(" .. V .. ")",
		function (v1, iu, v2) return v1 .. vowel_to_glide[iu] .. v2 end
	)
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*)(" .. C .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. ")(" .. C .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. "+)(" .. C .. C .. V .. ")", "%1.%2")
	text = rsub(text, "([pbvkctdg])%.([lr])", ".%1%2")
	text = rsub_repeatedly(text, "(" .. C .. ")%.s(" .. C .. ")", "%1s.%2")
	-- Any aeo, or stressed iuy, should be syllabically divided from a following aeo or stressed iuy.
	text = rsub_repeatedly(text, "([aeo]" .. accent_c .. "*)([aeo])", "%1.%2")
	text = rsub_repeatedly(text, "([aeo]" .. accent_c .. "*)(" .. V .. stress_c .. ")", "%1.%2")
	text = rsub(text, "([iuy]" .. stress_c .. ")([aeo])", "%1.%2")
	text = rsub_repeatedly(text, "([iuy]" .. stress_c .. ")(" .. V .. stress_c .. ")", "%1.%2")
	text = rsub_repeatedly(text, "i(" .. accent_c .. "*)i", "i%1.i")
	text = rsub_repeatedly(text, "u(" .. accent_c .. "*)u", "u%1.u")
	text = text:gsub(SYLDIV, ".")
	text = text:gsub(TEMP_I, "i")
	text = text:gsub(TEMP_U, "u")
	text = text:gsub(TEMP_Y_CONS, "y")
	text = text:gsub(TEMP_CH, "ch")
	text = text:gsub(TEMP_LL, "ll")
	text = text:gsub(TEMP_RR, "rr")
	return text
end


function export.show_pr(frame)
	local params = {
		[1] = {list = true},
	}
	local parargs = frame:getParent().args
	local args = require("Module:parameters").process(parargs, params)
	local respellings = #args[1] > 0 and args[1] or {"+"}
	local parsed_respellings = {}
	local iut
	for i, respelling in ipairs(respellings) do
		if respelling:find("<") then
			if not iut then
				iut = require("Module:inflection utilities")
			end
			local run = iut.parse_balanced_segment_run(item, "<", ">")
			local function parse_err(msg)
				error(msg .. ": " .. i .. "= " .. table.concat(run))
			end
			local terms = rsplit(run[1], "%s*,%s*")
			for j, term in ipairs(terms) do
				if term == "+" then
					terms[j] = mw.title.getCurrentTitle().text
				end
			end
			local parsed = {terms = rsplit(run[1], "%s*,%s*"), audio = {}, rhymes = {}, hyph = {}}
			for j = 2, #run - 1, 2 do
				if run[j + 1] ~= "" then
					parse_err("Extraneous text '" .. run[j + 1] .. "' after modifier")
				end
				local modtext = run[j]:match("^<(.*)>$")
				if not modtext then
					parse_err("Internal error: Modifier '" .. modtext .. "' isn't surrounded by angle brackets")
				end
				if modtext == "norhyme" then
					if parsed.norhyme then
						parse_err("Can't specify <norhyme> twice")
					end
					parsed.norhyme = true
				else
					local prefix, arg = modtext:match("^([a-z]+):(.*)$")
					if not prefix then
						parse_err("Modifier " .. run[j] .. " lacks a prefix, should begin with one of " ..
							"'pre', 'post', 'ref', 'bullets', 'audio', 'rhyme', 'hyph' or 'style'")
					end
					if prefix == "pre" or prefix == "post" or prefix == "ref" or prefix == "bullets"
						or prefix == "style" then
						if parsed[prefix] then
							parse_err("Modifier '" .. prefix .. "' occurs twice, second occurrence " .. run[j])
						end
						if prefix == "bullets" then
							if not arg:find("^[0-9]$") then
								parse_err("Modifier 'bullets' should have a number as argument")
							end
							parsed.bullets = tonumber(arg)
						else
							parsed[prefix] = arg
						end
					elseif prefix == "rhyme" or prefix == "hyph" then
						local vals = rsplit(arg, "%s*,%s*")
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
			end
			if not parsed.bullets then
				parsed.bullets = 1
			end
			table.insert(parsed_respellings, parsed)
		end
	end

	for _, parsed in ipairs(parsed_respellings) do
		parsed.pronun = generate_pronun(parsed)
		local saw_space = false
		for _, term in ipairs(parsed.terms) do
			if term:find("[%s%-]") then
				saw_space = true
				break
			end
		end
		if saw_space then
			parsed.norhyme = true
		end

		-- Generate the rhymes 
		local function dodialect(rhyme_ret, dialect)
			rhyme_ret.pronun[dialect] = {}
			for _, pronun in ipairs(parsed.pronun.pronun[dialect]) do
				-- Count number of syllables by looking at syllable boundaries (including stress marks).
				local num_syl = ulen(rsub(pronun.phonemic, "[^.ˌˈ]", "")) + 1
				-- Get the rhyme by truncating everything up through the last stress mark + any following
				-- consonants, and remove syllable boundary markers.
				local rhyme = rsub(rsub(pronun.phonemic, ".*[ˌˈ]", ""), "^[^" .. vowel .. "]", ""):gsub("%.", "")
				local saw_already = false
				for _, existing in ipairs(rhyme_ret.pronun[dialect]) do
					if existing.rhyme == rhyme then
						saw_already = true
						-- We already saw this rhyme but possibly with a different number of syllables,
						-- e.g. if the user specified two pronunciations 'biología' (4 syllables) and
						-- 'bi.ología' (5 syllables), both of which have the same rhyme /ia/.
						require("Module:table").insertIfNot(existing.num_syl, num_syl)
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

		if #parsed.rhymes == 0 and not parsed.norhyme then
			parsed.rhymes = express_all_styles(parsed, dodialect)
		end
	end

	-- If all sets of pronunciations have the same rhymes, display them only once at the bottom.
	-- Otherwise, display rhymes beneath each set, indented.
	local first_rhyme_ret
	local all_rhyme_sets_eq = true
	for j, parsed in ipairs(parsed_respellings) do
		if j == 1 then
			first_rhyme_ret = parsed.rhymes
		elseif not require("Module:table").deepEquals(first_rhyme_ret, parsed.rhymes) then
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

		return format_all_styles(rhyme_ret.expressed_styles, format_style)
	end

	local textparts = {}
	if all_rhyme_sets_eq then
		local num_bullets = 9999
		for j, parsed in ipairs(parsed_respellings) do
			if parsed.bullets < num_bullets then
				num_bullets = parsed.bullets
			end
			if j > 1 then
				table.insert(textparts, "\n")
			end
			table.insert(textparts, parsed.pronun.text)
		end
		table.insert(textparts, "\n")
		table.insert(textparts, format_rhyme(first_rhyme_ret, num_bullets))
	else
		for j, parsed in ipairs(parsed_respellings) do
			if j > 1 then
				table.insert(textparts, "\n")
			end
			table.insert(textparts, parsed.pronun.text)
			table.insert(textparts, "\n")
			table.insert(textparts, format_rhyme(parsed.rhymes, parsed.bullets + 1))
		end
	end

	return table.concat(textparts)
end


return export
