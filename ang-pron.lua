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
2. Recognize -lēas and -l[iī][cċ] as suffixes (so no voicing of preceding fricatives)
2b. Recognize -fæst, -ful, -full as suffixes (so no voicing of initial fricative)
3. If explicit syllable boundary in cluster after prefix, don't recognize as prefix
   (hence ġeddung could be written ġed.dung, bedreda bed.reda) (DONE)
4. Two bugs in swīþfèrhþ: missing initial stress, front h should be back (DONE MISSING
   STRESS, NOT SURE ABOUT H)
5. Bug in wasċan; probably sċ between vowels should be ʃʃ (DONE)
6. Bug in ġeddung, doesn't have allowed onset with ġe-ddung (DONE)
7. āxiġendlīc -- x is not an allowed onset (DONE)
]=]

local strutils = require("Module:string utilities")
local m_table = require("Module:table")
-- local com = require("Module:ang-common")

local u = mw.ustring.char
local rsubn = mw.ustring.gsub
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local ulen = mw.ustring.len

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

local ACUTE = u(0x0301)
local GRAVE = u(0x0300)
local CFLEX = u(0x0302)
local MACRON = u(0x0304)
local DOTABOVE = u(0x0307)

local accent = MACRON .. ACUTE .. GRAVE .. CFLEX
local accent_c = "[" .. accent .. "]"
local stress_accent = ACUTE .. GRAVE .. CFLEX
local stress_accent_c = "[" .. stress_accent .. "]"
local vowel = "aɑeiouyæœø"
local vowel_or_accent = vowel .. accent
local back_vowel = "aɑou"
local front_vowel = "eiyæœø"
local vowel_c = "[" .. vowel .. "]"
local vowel_or_accent_c = "[" .. vowel_or_accent .. "]"
local non_vowel_c = "[^" .. vowel .. "]"
-- The following includes both IPA symbols and letters (including regular g and IPA ɡ)
-- so it can be used at any step of the process.
local cons = "bcċçdfgġɡhjklmnŋpqrstvwxzþðƿθʃʒɫ"
local cons_c = "[" .. cons .. "]"
local voiced_sound = vowel .. "lrmnwjbdɡ" -- WARNING, IPA ɡ used here

local recomposer = {
	["g" .. DOTABOVE] = "ġ",
	["G" .. DOTABOVE] = "Ġ",
	["c" .. DOTABOVE] = "ċ",
	["C" .. DOTABOVE] = "Ċ",
}

-- Decompose macron, acute, grave, circumflex, but leave alone ġ, ċ and uppercase equiv
local function decompose(text)
	text = mw.ustring.toNFD(text)
	text = rsub(text, ".[" .. DOTABOVE .. "]", recomposer)
	return text
end

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
	{MACRON, "ː"},
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
		["g"] = "ɡ", -- map to IPA ɡ
		["a"] = "ɑ",
		["œ"] = "ø",
	}},
}

-- These rules operate in order, on the output of phonemic_rules.
-- The output of this is used to generate the displayed phonemic
-- pronunciation by removing ⁀ symbols.
local phonetic_rules = {
	-- Note, the following will not operate across a ⁀ boundary.
	{"([" .. voiced_sound .. "][ː.ˈˌ]*)([fsθ])([ː.ˈˌ]*[" .. voiced_sound .. "])",
		function(s1, c, s2)
			local fricative_to_voiced = {
				["f"] = "v",
				["s"] = "z",
				["θ"] = "ð",
			}
			return s1 .. fricative_to_voiced[c] .. s2
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
	-- For h between vowels, there should be a syllable break before the h,
	-- and the following two won't match.
	{"(" .. back_vowel .. "ː?[lr]?)h", "%1x"},
	{"([" .. front_vowel .. cons .. "]ː?)h", "%1ç"},
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
	-- FIXME, word-final double consonants should be pronounced single, maybe
	-- also syllable-final except obstruents before [lr]
}

local function apply_rules(word, rules)
	for _, rule in ipairs(rules) do
		word = rsub(word, rule[1], rule[2])
	end
	return word
end

-- We use the following syllable-splitting algorithm.
-- (1) A single consonant goes with the following syllable.
-- (2) Two consonants are split down the middle.
-- (3) For three or more consonants, check for clusters ending in
--     onsets_3 then onsets_2, with at least one preceding consonant.
--     If so, split between the onset and the preceding consonant(s).
-- (4) Check similarly for secondary_onsets_2. If seen, then check
--     the preceding consonant; if it's not an l or r, split before
--     the onset.
-- (5) Otherwise, split before the last consonant (i.e. the last
--     consonant goes with the following syllable, and all preceding
--     consonants go with the preceding syllable).
local onsets_2 = m_table.listToSet({
	"pr", "pl",
	"br", "bl",
	"tr", "tw",
	"dr", "dw",
	"cr", "cl", "cw", --skip "cn"
	"kr", "kl", "kw", --skip "kn"
	"gr", "gl", -- skip "gn"
	"sm", "sn", "sl", "sw",
	"sp",
	"st",
	"sc", "sk", "sċ",
	"fr", "fl", --skip "fn",
	"þr", "þw",
	"ðr", "ðw",
	"hr", "hl", "hw", -- skip "hn"
	"wr", "wl",
})

local secondary_onsets_2 = m_table.listToSet({
	"cn", "kn",
	"gn",
	"fn",
	"hn",
})

local onsets_3 = m_table.listToSet({
	"spr", "spl",
	"str",
	"scr", "skr", "sċr",
})

local diphthongs = m_table.listToSet({
	"ea", decompose("ēa"), decompose("eā"),
	"eo", decompose("ēo"), decompose("eō"),
	"io", decompose("īo"), decompose("iō"),
	"ie", decompose("īe"), decompose("iē"),
})

local prefixes = {
	{decompose("ā"), {verb = "unstressed", noun = "stressed"}},
	{"æt", {verb = "unstressed"}},
	{"æfter", {verb = "secstressed", noun = "stressed"}}, -- not very common
	{"and", {verb = "stressed", noun = "stressed"}},
	{"an", {verb = "unstressed", non = "stressed"}},
	{"be", {verb = "unstressed", noun = "unstressed", restriction = "^[^" .. accent .. "ao]"}},
	{decompose("bī"), {noun = "stressed"}},
	-- {"ed", }, -- should include? not very common
	{"fore", {verb = "unstressed", noun = "stressed", restriction = "^[^" .. accent .. "ao]"}},
	{"for[þð]", {verb = "unstressed", noun = "stressed"}},
	{"for", {verb = "unstressed", noun = "unstressed"}},
	{"fram", {verb = "unstressed", noun = "stressed"}}, -- should include? not very common
	-- following is rare as a noun, mostly from verbal forms
	{"ġeond", {verb = "unstressed"}}, 
	{"ġe", {verb = "unstressed", noun = "unstressed", restriction = "^[^" .. accent .. "ao]"}},
	-- {"in", },-- should include? not very common, unclear if stressed or unstressed as verb
	{"mis", {verb = "unstressed"}},
	{"ofer", {verb = "secstressed", noun = "stressed"}},
	{"on", {verb = "unstressed", noun = "stressed"}},
	{"or", {noun = "stressed"}},
	{"o[þð]", {verb = "unstressed"}},
	{decompose("tō"), {verb = "unstressed", noun = "stressed"}},
	{"under", {verb = "secstressed", noun = "stressed"}},
	{"un", {verb = "secstressed", noun = "stressed"}}, --uncommon as verb
	{decompose("ūt"), {verb = "unstressed", noun = "stressed"}},
	{"[wƿ]i[þð]er", {verb = "secstressed", noun = "stressed"}},
	{"[wƿ]i[þð]", {verb = "unstressed"}},
	{"ymb", {verb = "unstressed", noun = "stressed"}},
	{"[þð]urh", {verb = "unstressed", noun = "stressed"}},
	-- noun "prefixes"
	{decompose("dēa[þð]"), {noun = "stressed"}},
	{"dæġ", {noun = "stressed"}},
	{"efen", {noun = "stressed"}},
	{"eor[þð]", {noun = "stressed"}},
	{"god", {noun = "stressed"}},
	{decompose("gū[þð]"), {noun = "stressed"}},
	{"hand", {noun = "stressed"}},
	{decompose("hēafod"), {noun = "stressed"}},
	{"niht", {noun = "stressed"}},
	{decompose("stēop"), {noun = "stressed"}},
	{"[wƿ]inter", {noun = "stressed"}},
	{"[wƿ]uldor", {noun = "stressed"}},
}

local suffixes = {
	{"lēas", {noun = "secstressed"}},
	{"l[īi][ċc]", {noun = "unstressed"}},
	{"full?", {noun = "unstressed"}},
	{"fæst", {noun = "secstressed"}},
	{"ness", {noun = "unstressed"}},
	{"nis", {noun = "unstressed"}},
	{"sum", {noun = "unstressed"}},
}

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
				for _, prefixspec in ipairs(prefixes) do
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
								not (onsets_2[initial_cluster] or secondary_onsets_2[initial_cluster] or
									onsets_3[initial_cluster])) then
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
									prefix = rsub(prefix, "(" .. vowel_c .. ")", "%1" .. GRAVE, 1)
								elseif stress_spec[pos] == "stressed" then
									prefix = rsub(prefix, "(" .. vowel_c .. ")", "%1" .. ACUTE, 1)
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
				for _, suffixspec in ipairs(suffixes) do
					local suffix_pattern = prefixspec[1]
					local stress_spec = prefixspec[2]
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
									prefix = rsub(suffix, "(" .. vowel_c .. ")", "%1" .. GRAVE, 1)
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
		if acc == CFLEX then
			-- remove circumflex but don't accent
			parts[i] = gsub(parts[i], CFLEX, "")
		elseif acc == ACUTE then
			saw_primary_stress = true
		elseif not acc and parts[i + 1] ~= "<" and parts[i - 1] ~= ">" then
			-- Add primary or secondary stress on the part; primary stress if no primary
			-- stress yet, otherwise secondary stress.
			acc = saw_primary_stress and GRAVE or ACUTE
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
			if i < #chars - 1 and diphthongs[
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
				if #first > 0 and onsets_3[last3] then
					cons_vowel[i - 1] = cons_vowel[i - 1] .. first
					cons_vowel[i + 1] = last3 .. cons_vowel[i + 1]
				else
					local first, last2 = rmatch(cluster, "^(.-)(..)$")
					if onsets_2[last2] or (secondary_onsets_2[last2] and not first:find("[lr]$")) then
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
		if syl:find(ACUTE) then
			syl = "ˈ" .. gsub(syl, ACUTE, "")
		elseif syl:find(GRAVE) then
			syl = "ˌ" .. gsub(syl, GRAVE, "")
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
	word = decompose(word)
	local parts = split_on_word_boundaries(word, pos)
	for i, part in ipairs(parts) do
		local syllables = split_into_syllables(part)
		parts[i] = combine_syllables_moving_stress(syllables)
	end
	return combine_parts(parts)
end

local function default_pos(word, pos)
	if not pos then
		-- adjectives in -līċ can follow nouns or verbs; truncate the ending and
		-- check what precedes
		local prefword = rsub(word, "^(.* .. vowel_c .. .*)l[iī][cċ]$", "%1")
		word = prefword or word
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

local function generate_phonemic(word, pos)
	pos = default_pos(word, pos)
	word = transform_word(word, pos)
	word = apply_rules(word, phonemic_rules)
	-- remove stress from single-syllable words
	word = rsub(word, "^(⁀*)[ˈˌ]([^.ˈˌ]*)$", "%1%2")
	return word
end

function export.phonemic(word, pos)
	if type(word) == "table" then
		pos = word.args["pos"]
		word = word[1]
	end
	return gsub(generate_phonemic(word, pos), "⁀", "")
end

function export.phonetic(word, pos)
	if type(word) == "table" then
		pos = word.args["pos"]
		word = word[1]
	end
	word = generate_phonemic(word, pos)
	word = apply_rules(word, phonetic_rules)
	word = gsub(word, "⁀", "")
	return word
end

function export.show(frame)
	local parent_args = frame:getParent().args
	local params = {
		[1] = { required = true, default = "ġegangan" },
		["pos"] = { default = "verb" },
	}
	local args = require("Module:parameters").process(parent_args, params)

	local phonemic = export.phonemic(args[1], args.pos)
	local phonetic = export.phonetic(args[1], args.pos)
	if phonemic == phonetic then
		return "/" .. phonemic .. "/"
	else
		return "/" .. phonemic .. "/ [" .. phonetic .. "]"
	end
end

return export
