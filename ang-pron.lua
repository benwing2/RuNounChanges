--[=[

Implementation of pronunciation-generation module from spelling for
Old English.

Author: Benwing

Generally, the user should supply the spelling, properly marked up with
macrons for long vowels, and ċ ġ ċġ sċ for soft versions of these consonants.
In addition, the following symbols can be used:

-- acute accent on a vowel to override the position of primary stress
--   (in a diphthong, put it over the first vowel)
-- grave accent to add secondary stress
-- circumflex to force no stress on the word or prefix (e.g. in a compound)
-- . (period) to force a syllable boundary
-- - (hyphen) to force a prefix/word or word/word boundary in a compound word;
--   the result will be displayed as a single word but the consonants on
--   either side treated as if they occurred at the beginning/end of the word
-- + (plus) is the opposite of -; it forces a prefix/word or word/word boundary
--   to *NOT* occur when it otherwise would
-- _ (underscore) to force the letters on either side to be interpreted
--   independently, when the combination of the two would normally have a
--   special meaning

FIXME:

1. Implement < and > which works like - but don't trigger secondary stress
   (< after a prefix, > before a suffix) (DONE)
2. Recognize -lēas and -l[iī][cċ] as suffixes. (DONE)
2b. Recognize -fæst, -ful, -full as suffixes (so no voicing of initial
    fricative). (DONE)
3. If explicit syllable boundary in cluster after prefix, don't recognize as
   prefix (hence ġeddung could be written ġed.dung, bedreda bed.reda) (DONE)
4. Two bugs in swīþfèrhþ: missing initial stress, front h should be back (DONE)
5. Check Urszag's code changes for /h/. (DONE)
6. Bug in wasċan; probably sċ between vowels should be ʃʃ (DONE)
7. Bug in ġeddung, doesn't have allowed onset with ġe-ddung (DONE)
8. āxiġendlīc -- x is not an allowed onset (DONE)
9. Handle prefixes/suffixes denoted with initial/final hyphen -- shouldn't
   trigger automatic stress when multisyllabic.
10. Don't remove user-specified accents on monosyllabic words if there are
    multiple words in the text.
11. Final -þu/-þo after a consonant should always be voiceless (but controlled
    by a param). (DONE BUT NOT YET CONTROLLED BY PARAM)
12. Fricative voiced between voiced sounds even across prefix/compound
    boundary when before (but not after) the boundary. (DONE)
13. Fricative between unstressed vowels should be voiceless (e.g. adesa);
    maybe only after the stress? (DONE)
14. Resonant after fricative/stop in a given syllable should be rendered
    as syllabic (e.g. ādl [ˈɑːdl̩], botm [botm̥], bōsm, bēacn [ˈbæːɑ̯kn̩];
	also -mn e.g stemn /ˈstemn̩/. (DONE)
15. Add aġēn- and onġēan- prefixes with secondary stress for verbs.
    (WILL NOT DO)
16. and- (and maybe all others) should be unstressed as verbal prefix.
    andswarian is an exception. (DONE)
17. Support multiple pronunciations as separate numbered params. (DONE)
17b. Additional specifiers should follow each pronun as PRONUN<K:V,K2:V2,...>.
    This includes the current pos=.
18. Double hh should be pronounced as [xː]. (DONE)
19. Add -bǣre as a suffix with secondary stress. (DONE)
20. Add -līċ(e), lī[cċ]nes(s) as suffixes with secondary stress. -lī[cċ]nes(s)
    should behave like -līċ(e) in that what's before is checked to determine
	the pos. (DONE)
21. -lēasnes should be a recognized suffix with secondary stress. (DONE)
22. Fix handling of crinċġan, dynċġe, should behave as if ċ isn't there. (DONE)
23. Rewrite to use [[Module:ang-common]]. (DONE)
24. Ignore final period/question mark/exclamation point. (DONE)

QUESTIONS:

1. Should /an/, /on/ be pronounced [ɒn]? Same for /am/, /om/.
2. Should final /ɣ/ be rendered as [x]?
3. Should word-final double consonants be simplified in phonetic representation?
   Maybe also syllable-final except obstruents before [lr]?
4. Should we use /x/ instead of /h/?
5. Should we recognize from- along with fram-?
6. Should we recognize bi- along with be-? (danger of false positives)
7. Should fricative be voiced before voicd sound across word boundary?
   (dæġes ēage [ˈdæːjez ˈæːɑ̯ɣe]?)
8. Ask about pronunciation of bræġn, is the n syllabic? It's given as
   /ˈbræjn̩/. Similarly, seġl given as /ˈsejl̩/.
9. Ask about pronunciation of ġeond-, can it be either [eo] or [o]?
10. Is final -ol pronounced [ul] e.g regol [ˈreɣul]? Hundwine has created
    entries this way. What about final -oc etc.?
11. Is final -ian pronounced [jan] or [ian]? Cf. sċyldigian given as
    {{IPA|/ˈʃyldiɣiɑn/|/ˈʃyldiɣjɑn/}}. What about spyrian given as /ˈspyr.jɑn/?
12. seht given as /seçt/ but sehtlian given as /ˈsextliɑn/. Which one is
    correct?
13. Final -liċ or -līċ, with or without secondary stress?
14. Should we special-case -sian [sian]? Then we need support for [z] notation
    to override phonetics.
]=]

local strutils = require("Module:string utilities")
local m_table = require("Module:table")
local m_IPA = require("Module:IPA")
local lang = require("Module:languages").getByCode("ang")
local com = require("Module:ang-common")

local u = mw.ustring.char
local rsubn = mw.ustring.gsub
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local rgsplit = mw.text.gsplit
local ulen = mw.ustring.len
local ulower = mw.ustring.lower

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar, n)
	local retval = rsubn(term, foo, bar, n)
	return retval
end

-- like str:gsub() but discards all but the first return value
local function gsub(term, foo, bar, n)
	local retval = term:gsub(foo, bar, n)
	return retval
end

local export = {}

local accent = com.MACRON .. com.ACUTE .. com.GRAVE .. com.CFLEX
local accent_c = "[" .. accent .. "]"
local stress_accent = com.ACUTE .. com.GRAVE .. com.CFLEX
local stress_accent_c = "[" .. stress_accent .. "]"
local vowel = "aɑeiouyæœø"
local vowel_or_accent = vowel .. accent
local back_vowel = "aɑou"
local front_vowel = "eiyæœø"
local vowel_c = "[" .. vowel .. "]"
local vowel_or_accent_c = "[" .. vowel_or_accent .. "]"
local non_vowel_c = "[^" .. vowel .. "]"
local front_vowel_c = "[" .. front_vowel .. "]"
-- The following include both IPA symbols and letters (including regular g and IPA ɡ)
-- so it can be used at any step of the process.
local obstruent = "bcċçdfgɡɣhkpqstvxzþðθʃʒ"
local resonant = "lmnŋrɫ"
local glide = "ġjwƿ"
local cons = obstruent .. resonant .. glide
local cons_c = "[" .. cons .. "]"
local voiced_sound = vowel .. "lrmnwjbdɡ" -- WARNING, IPA ɡ used here

-- These rules operate in order, and apply to the actual spelling,
-- after (1) macron decomposition, (2) syllable and prefix splitting,
-- (3) placement of primary and secondary stresses at the beginning
-- of the syllable. Each syllable will be separated either by ˈ
-- (if the following syllable is stressed), by ˌ (if the following
-- syllable has secondary stress), or by . (otherwise). In addition,
-- morpheme boundaries where the consonants on either side should be
-- treated as at the beginning/end of word (i.e. between prefix and
-- word, or between words in a compound word) will be marked with ⁀
-- before the syllable separator, and the beginning and end of text
-- will be marked by ⁀⁀. The output of this is fed into phonetic_rules,
-- and then is used to generate the displayed phonemic pronunciation
-- by removing ⁀ symbols.
local phonemic_rules = {
	{com.MACRON, "ː"},
	{"eoː", "oː"}, -- e.g. ġeōmor
	{"eaː", "aː"},
	{"[ei]ː?[aeo]", {
		-- Alternative notation for short diphthongs: iu̯, eo̯, æɑ̯
		-- Alternative notation for long diphthongs: iːu̯, eːo̯, æːɑ̯
		["ea"] = "æ͜ɑ",
		["eːa"] = "æ͜ɑː",
		["eo"] = "e͜o",
		["eːo"] = "e͜oː",
		["io"] = "i͜u",
		["iːo"] = "i͜uː",
		["ie"] = "i͜y",
		["iːe"] = "i͜yː",
	}},
	-- sċ between vowels when at the beginning of a syllable should be ʃ.ʃ
	{"(" .. vowel_c .. "ː?)([.ˈˌ]?)sċ(" .. vowel_c .. ")", "%1ʃ%2ʃ%3"},
	-- other sċ should be ʃ; note that sċ divided between syllables becomes s.t͡ʃ
	{"sċ", "ʃ"},
	-- x between vowels when at the beginning of a syllable should be k.s;
	-- remaining x handled below
	{"(" .. vowel_c .. "ː?)([.ˈˌ]?)x(" .. vowel_c .. ")", "%1k%2s%3"},
	-- z between vowels when at the beginning of a syllable should be t.s;
	-- remaining z handled below
	{"(" .. vowel_c .. "ː?)([.ˈˌ]?)z(" .. vowel_c .. ")", "%1t%2s%3"},
	{"nċ([.ˈˌ]?)ġ", "n%1j"},
	{"ċ([.ˈˌ]?)ġ", "j%1j"},
	{"c([.ˈˌ]?)g", "g%1g"},
	{"ċ([.ˈˌ]?)ċ", "t%1t͡ʃ"},
	{".", {
		["ċ"] = "t͡ʃ",
		["c"] = "k",
		["ġ"] = "j",
		["þ"] = "θ",
		["ð"] = "θ",
		["ƿ"] = "w",
		["x"] = "ks",
		["z"] = "ts",
		["g"] = "ɡ", -- map to IPA ɡ
		["a"] = "ɑ",
		["œ"] = "ø",
	}},
}

local fricative_to_voiced = {
	["f"] = "v",
	["s"] = "z",
	["θ"] = "ð",
}

local fricative_to_unvoiced = {
	["v"] = "f",
	["z"] = "s",
	["ð"] = "θ",
}

-- These rules operate in order, on the output of phonemic_rules.
-- The output of this is used to generate the displayed phonemic
-- pronunciation by removing ⁀ symbols.
local phonetic_rules = {
	-- Fricative voicing between voiced sounds. Note, the following operates
	-- across a ⁀ boundary for a fricative before the boundary but not after.
	{"([" .. voiced_sound .. "][ː.ˈˌ]*)([fsθ])([ː.ˈˌ⁀]*[" .. voiced_sound .. "])",
		function(s1, c, s2)
			return s1 .. fricative_to_voiced[c] .. s2
		end
	},
	-- Fricative between unstressed vowels should be devoiced.
	-- Note that unstressed syllables are preceded by . while stressed
	-- syllables are preceded by a stress mark.
	{"(%.[^.⁀][" .. vowel .. com.DOUBLE_BREVE_BELOW .. "ː]*%.)([vzð])",
		function(s1, c)
			return s1 .. fricative_to_unvoiced[c]
		end
	},
	-- Final unstressed -þu/-þo after a consonant should be devoiced.
	{"(" .. cons_c .. "ː?" .. "%.)ð([uo]⁀)",
		function(s1, s2)
			return s1 .. "θ" .. s2
		end
	},
	{"h[wnlr]", {
		["hw"] = "ʍ",
		["hl"] = "l̥",
		["hn"] = "n̥",
		["hr"] = "r̥",
	}},
	-- Note, the following will not operate across a ⁀ boundary.
	{"n([.ˈˌ]?[ɡkx])", "ŋ%1"}, -- WARNING, IPA ɡ used here
	{"n([.ˈˌ]?)j", "n%1d͡ʒ"},
	{"j([.ˈˌ]?)j", "d%1d͡ʒ"},
	{"h", "x"},                    -- [x] is the most general allophone
	{"([^x][⁀.ˈˌ])x", "%1h"},      -- [h] occurs as a syllable-initial allophone
	{"(" .. front_vowel_c .. ")x", "%1ç"}, -- [ç] occurs after front vowels
	-- An IPA ɡ after a word/prefix boundary, after another ɡ or after n
	-- (previously converted to ŋ in this circumstance) should remain as ɡ,
	-- while all other ɡ's should be converted to ɣ except that word-final ɡ
	-- becomes x. We do this by converting the ɡ's that should remain to regular
	-- g (which should never occur otherwise), convert the remaining IPA ɡ's to ɣ
	-- or x, and then convert the regular g's back to IPA ɡ.
	{"([ŋɡ⁀][.ˈˌ]?)ɡ", "%1g"}, -- WARNING, IPA ɡ on the left, regular g on the right
	{"ɡ⁀", "x⁀"},
	{"ɡ", "ɣ"},
	{"g", "ɡ"}, -- WARNING, regular g on the left, IPA ɡ on the right
	{"l([.ˈˌ]?)l", "ɫ%1ɫ"},
	{"r([.ˈˌ]?)r", "rˠ%1rˠ"},
	{"l([.ˈˌ]?" .. cons_c .. ")", "ɫ%1"},
	{"r([.ˈˌ]?" .. cons_c .. ")", "rˠ%1"},
	-- In the sequence vowel + obstruent + resonant in a single syllable,
	-- the resonant should become syllabic, e.g. ādl [ˈɑːdl̩], blōstm [bloːstm̩],
	-- fæþm [fæðm̩], bēacn [ˈbæːɑ̯kn̩]. We allow anything but a syllable or word
	-- boundary betweent the vowel and the obstruent.
	{"(" .. vowel_c .. "[^.ˈˌ⁀]*[" .. obstruent .. "]ː?[" .. resonant .. "])", "%1" .. com.SYLLABIC},
	-- also -mn e.g stemn /ˈstemn̩/; same for m + other resonants except m
	{"(" .. vowel_c .. "[^.ˈˌ⁀]*mː?[lnŋrɫ])", "%1" .. com.SYLLABIC},
}

local function apply_rules(word, rules)
	for _, rule in ipairs(rules) do
		word = rsub(word, rule[1], rule[2])
	end
	return word
end

local function split_on_word_boundaries(word, pos)
	local retparts = {}
	local parts = strutils.capturing_split(word, "([<>%-])")
	local i = 1
	local saw_primary_stress = false
	while i <= #parts do
		local split_part = false
		local insert_position = #retparts + 1
		if parts[i + 1] ~= "<" and parts[i - 1] ~= ">" then
			-- Split off any prefixes.
			while true do
				local broke_prefix = false
				for _, prefixspec in ipairs(com.prefixes) do
					local prefix_pattern = prefixspec[1]
					local stress_spec = prefixspec[2]
					local prefix, rest = rmatch(parts[i], "^(" .. prefix_pattern .. ")(.*)$")
					if prefix then
						if not stress_spec[pos] then
							-- prefix not recognized for this POS, don't split here
						elseif stress_spec.restriction and not rfind(rest, stress_spec.restriction) then
							-- restriction not met, don't split here
						elseif rfind(rest, "^%+") then
							-- explicit non-boundary here, so don't split here
						elseif not rfind(rest, vowel_c) then
							-- no vowels, don't split here
						elseif rfind(rest, "^..?$") then
							-- only two letters, unlikely to be a word, probably an ending, so don't split
							-- here
						else
							local initial_cluster, after_cluster = rmatch(rest, "^(" .. non_vowel_c .. "*)(.-)$")
							if rfind(initial_cluster, "..") and (
								not (com.onsets_2[initial_cluster] or com.secondary_onsets_2[initial_cluster] or
									com.onsets_3[initial_cluster])) then
								-- initial cluster isn't a possible onset, don't split here
							elseif rfind(initial_cluster, "^x") then
								-- initial cluster isn't a possible onset, don't split here
							elseif rfind(after_cluster, "^" .. vowel_c .. "$") then
								-- remainder is a cluster + short vowel,
								-- unlikely to be a word so don't split here
							else
								-- break the word in two; next iteration we process
								-- the rest, which may need breaking again
								parts[i] = rest
								if stress_spec[pos] == "unstressed" then
									-- don't do anything
								elseif stress_spec[pos] == "secstressed" or (saw_primary_stress and stress_spec[pos] == "stressed") then
									prefix = rsub(prefix, "(" .. vowel_c .. ")", "%1" .. com.GRAVE, 1)
								elseif stress_spec[pos] == "stressed" then
									prefix = rsub(prefix, "(" .. vowel_c .. ")", "%1" .. com.ACUTE, 1)
									saw_primary_stress = true
								else
									error("Unrecognized stress spec for pos=" .. pos .. ", prefix=" .. prefix .. ": " .. stress_spec[pos])
								end
								table.insert(retparts, insert_position, prefix)
								insert_position = insert_position + 1
								broke_prefix = true
								break
							end
						end
					end
				end
				if not broke_prefix then
					break
				end
			end

			-- Now do the same for suffixes.
			while true do
				local broke_suffix = false
				for _, suffixspec in ipairs(com.suffixes) do
					local suffix_pattern = suffixspec[1]
					local stress_spec = suffixspec[2]
					local rest, suffix = rmatch(parts[i], "^(.-)(" .. suffix_pattern .. ")$")
					if suffix then
						if not stress_spec[pos] then
							-- suffix not recognized for this POS, don't split here
						elseif stress_spec.restriction and not rfind(rest, stress_spec.restriction) then
							-- restriction not met, don't split here
						elseif rfind(rest, "%+$") then
							-- explicit non-boundary here, so don't split here
						elseif not rfind(rest, vowel_c) then
							-- no vowels, don't split here
						else
							local before_cluster, final_cluster = rmatch(rest, "^(.-)(" .. non_vowel_c .. "*)$")
							if rfind(final_cluster, "%..") then
								-- syllable division within or before final
								-- cluster, don't split here
							else
								-- break the word in two; next iteration we process
								-- the rest, which may need breaking again
								parts[i] = rest
								if stress_spec[pos] == "unstressed" then
									-- don't do anything
								elseif stress_spec[pos] == "secstressed" then
									prefix = rsub(suffix, "(" .. vowel_c .. ")", "%1" .. com.GRAVE, 1)
								elseif stress_spec[pos] == "stressed" then
									error("Primary stress not allowed for suffixes (suffix=" .. suffix .. ")")
								else
									error("Unrecognized stress spec for pos=" .. pos .. ", suffix=" .. suffix .. ": " .. stress_spec[pos])
								end
								table.insert(retparts, insert_position, suffix)
								broke_suffix = true
								break
							end
						end
					end
				end
				if not broke_suffix then
					break
				end
			end
		end

		local acc = rfind(parts[i], "(" .. stress_accent_c .. ")")
		if acc == com.CFLEX then
			-- remove circumflex but don't accent
			parts[i] = gsub(parts[i], com.CFLEX, "")
		elseif acc == com.ACUTE then
			saw_primary_stress = true
		elseif not acc and parts[i + 1] ~= "<" and parts[i - 1] ~= ">" then
			-- Add primary or secondary stress on the part; primary stress if no primary
			-- stress yet, otherwise secondary stress.
			acc = saw_primary_stress and com.GRAVE or com.ACUTE
			saw_primary_stress = true
			parts[i] = rsub(parts[i], "(" .. vowel_c .. ")", "%1" .. acc, 1)
		end
		table.insert(retparts, insert_position, parts[i])
		i = i + 2
	end

	-- remove any +, which has served its purpose
	for i, part in ipairs(retparts) do
		retparts[i] = gsub(part, "%+", "")
	end
	return retparts
end

local function break_vowels(vowelseq)
	local function check_empty(char)
		if char ~= "" then
			error("Something wrong, non-vowel '" .. char .. "' seen in vowel sequence '" .. vowelseq .. "'")
		end
	end

	local vowels = {}
	local chars = strutils.capturing_split(vowelseq, "(" .. vowel_c .. accent_c .. "*)")
	local i = 1
	while i <= #chars do
		if i % 2 == 1 then
			check_empty(chars[i])
			i = i + 1
		else
			if i < #chars - 1 and com.diphthongs[
				rsub(chars[i], stress_accent_c, "") .. rsub(chars[i + 2], stress_accent_c, "")
			] then
				check_empty(chars[i + 1])
				table.insert(vowels, chars[i] .. chars[i + 2])
				i = i + 3
			else
				table.insert(vowels, chars[i])
				i = i + 1
			end
		end
	end
	return vowels
end

-- Break a word into alternating C and V components where a C component is a run
-- of zero or more consonants and a V component in a single vowel or dipthong.
-- There will always be an odd number of components, where all odd-numbered
-- components (starting from 1) are C components and all even-numbered components
-- are V components.
local function break_into_c_and_v_components(word)
	local cons_vowel = strutils.capturing_split(word, "(" .. vowel_or_accent_c .. "+)")
	local components = {}
	for i = 1, #cons_vowel do
		if i % 2 == 1 then
			table.insert(components, cons_vowel[i])
		else
			local vowels = break_vowels(cons_vowel[i])
			for j = 1, #vowels do
				if j == 1 then
					table.insert(components, vowels[j])
				else
					table.insert(components, "")
					table.insert(components, vowels[j])
				end
			end
		end
	end
	return components
end

local function split_into_syllables(word)
	local cons_vowel = break_into_c_and_v_components(word)
	if #cons_vowel == 1 then
		return cons_vowel
	end
	for i = 1, #cons_vowel do
		if i % 2 == 1 then
			-- consonant
			local cluster = cons_vowel[i]
			local len = ulen(cluster)
			if i == 1 then
				cons_vowel[i + 1] = cluster .. cons_vowel[i + 1]
			elseif i == #cons_vowel then
				cons_vowel[i - 1] = cons_vowel[i - 1] .. cluster
			elseif rfind(cluster, "%.") then
				local before_break, after_break = rmatch(cluster, "^(.-)%.(.*)$")
				cons_vowel[i - 1] = cons_vowel[i - 1] .. before_break
				cons_vowel[i + 1] = after_break .. cons_vowel[i + 1]
			elseif len == 0 then
				-- do nothing
			elseif len == 1 then
				cons_vowel[i + 1] = cluster .. cons_vowel[i + 1]
			elseif len == 2 then
				local c1, c2 = rmatch(cluster, "^(.)(.)$")
				if c1 == "s" and c2 == "ċ" then
					cons_vowel[i + 1] = "sċ" .. cons_vowel[i + 1]
				else
					cons_vowel[i - 1] = cons_vowel[i - 1] .. c1
					cons_vowel[i + 1] = c2 .. cons_vowel[i + 1]
				end
			else
				-- check for onset_3 preceded by consonant(s).
				local first, last3 = rmatch(cluster, "^(.-)(...)$")
				if #first > 0 and com.onsets_3[last3] then
					cons_vowel[i - 1] = cons_vowel[i - 1] .. first
					cons_vowel[i + 1] = last3 .. cons_vowel[i + 1]
				else
					local first, last2 = rmatch(cluster, "^(.-)(..)$")
					if com.onsets_2[last2] or (com.secondary_onsets_2[last2] and not first:find("[lr]$")) then
						cons_vowel[i - 1] = cons_vowel[i - 1] .. first
						cons_vowel[i + 1] = last2 .. cons_vowel[i + 1]
					else
						local first, last = rmatch(cluster, "^(.-)(.)$")
						cons_vowel[i - 1] = cons_vowel[i - 1] .. first
						cons_vowel[i + 1] = last .. cons_vowel[i + 1]
					end
				end
			end
		end
	end

	local retval = {}
	for i = 1, #cons_vowel do
		if i % 2 == 0 then
			-- remove any stray periods.
			table.insert(retval, rsub(cons_vowel[i], "%.", ""))
		end
	end
	return retval
end

-- Combine syllables into a word, moving stress markers (acute/grave) to the
-- beginning of the syllable.
local function combine_syllables_moving_stress(syllables)
	local modified_syls = {}
	for i, syl in ipairs(syllables) do
		if syl:find(com.ACUTE) then
			syl = "ˈ" .. gsub(syl, com.ACUTE, "")
		elseif syl:find(com.GRAVE) then
			syl = "ˌ" .. gsub(syl, com.GRAVE, "")
		elseif i > 1 then
			syl = "." .. syl
		end
		table.insert(modified_syls, syl)
	end
	return table.concat(modified_syls)
end

-- Combine word parts (split-off prefixes, suffixes or parts of a compound word)
-- into a single word. Separate parts with ⁀ and the put ⁀⁀ at word boundaries.
local function combine_parts(parts)
	local text = {}
	for i, part in ipairs(parts) do
		if i > 1 and not rfind(part, "^[ˈˌ]") then
			-- Need a syllable boundary if there isn't a stress marker.
			table.insert(text, ".")
		end
		table.insert(text, part)
	end
	return "⁀⁀" .. table.concat(text, "⁀") .. "⁀⁀"
end

local function transform_word(word, pos)
	word = com.decompose(word)
	word = gsub(word, "[.!?]$", "")
	local parts = split_on_word_boundaries(word, pos)
	for i, part in ipairs(parts) do
		local syllables = split_into_syllables(part)
		parts[i] = combine_syllables_moving_stress(syllables)
	end
	return combine_parts(parts)
end

local function default_pos(word, pos)
	if not pos then
		-- adjectives in -līċ, adverbs in -līċe and nouns in -nes can follow
		-- nouns or verbs; truncate the ending and check what precedes
		word = rsub(word, "^(.*" .. vowel_c .. ".*)l[iī][cċ]e?$", "%1")
		word = rsub(word, "^(.*" .. vowel_c .. ".*)n[eiy]ss?$", "%1")
		-- verbs in -an/-ōn/-ēon, inflected infintives in -enne,
		-- participles in -end(e)/-en/-ed/-od, verbal nouns in -ing/-ung
		if rfind(word, "[aāō]n$") or rfind(word, "ēon$") or rfind(word, "enne$")
			or rfind(word, "ende?$") or rfind(word, "[eo]d$") or rfind(word, "en$")
			or rfind(word, "[iu]ng$") then
			pos = "verb"
		else
			pos = "noun"
		end
	elseif pos == "adj" or pos == "adjective" then
		pos = "noun"
	elseif pos ~= "noun" and pos ~= "verb" then
		error("Unrecognized part of speech: " .. pos)
	end
	return pos
end

local function generate_phonemic_word(word, pos)
	pos = default_pos(word, pos)
	word = transform_word(word, pos)
	word = apply_rules(word, phonemic_rules)
	-- remove stress from single-syllable words
	word = rsub(word, "^(⁀*)[ˈˌ]([^.ˈˌ]*)$", "%1%2")
	return word
end

local function generate_phonemic_text(text, pos)
	local result = {}
	text = ulower(text)
	for word in rgsplit(text, " ") do
		table.insert(result, generate_phonemic_word(word, pos))
	end
	return table.concat(result, " ")
end

function export.phonemic(text, pos)
	if type(text) == "table" then
		pos = text.args["pos"]
		text = text[1]
	end
	return gsub(generate_phonemic_text(text, pos), "⁀", "")
end

function export.phonetic(text, pos)
	if type(text) == "table" then
		pos = text.args["pos"]
		text = text[1]
	end
	local result = {}
	text = ulower(text)
	for word in rgsplit(text, " ") do
		word = generate_phonemic_word(word, pos)
		word = apply_rules(word, phonetic_rules)
		table.insert(result, word)
	end
	return gsub(table.concat(result, " "), "⁀", "")
end

function export.show(frame)
	local parent_args = frame:getParent().args
	local params = {
		[1] = { required = true, default = "hlǣf-dīġe", list = true },
		["pos"] = {},
		["ann"] = {},
	}
	local args = require("Module:parameters").process(parent_args, params)

	local IPA_args = {}
	for _, arg in ipairs(args[1]) do
		local phonemic = export.phonemic(arg, args.pos)
		local phonetic = export.phonetic(arg, args.pos)
		table.insert(IPA_args, {pron = '/' .. phonemic .. '/'})
		if phonemic ~= phonetic then
			table.insert(IPA_args, {pron = '[' .. phonetic .. ']'})
		end
	end

	local anntext
	if args.ann == "1" then
		anntext = {}
		for _, arg in ipairs(args[1]) do
			-- remove all spelling markup except ġ/ċ and macrons
			m_table.insertIfNot(anntext, "'''" .. rsub(com.decompose(arg), "[%-+._<>" .. com.ACUTE .. com.GRAVE .. com.CFLEX .. "]", "") .. "'''")
		end
		anntext = table.concat(anntext, ", ") .. ":&#32;" 
	elseif args.ann then
		anntext = "'''" .. args.ann .. "''':&#32;"
	else
		anntext = ""
	end

	return anntext .. m_IPA.format_IPA_full(lang, IPA_args)
end

return export
