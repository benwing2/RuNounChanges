local export = {}

local m_params = require("Module:parameters")
local m_IPA = require("Module:IPA")
local m_syllables = require("Module:syllables")
local m_template_link = require("Module:template link")
local patut
local patut_module = "Module:pattern utilities"

local lang = require("Module:languages").getByCode("cs")
local sc = require("Module:scripts").getByCode("Latn")

function export.tag_text(text, face)
	return require("Module:script utilities").tag_text(text, lang, sc, face)
end

function export.link(term, face)
	return require("Module:links").full_link(
		{ term = term, lang = lang, sc = sc }, face
		)
end

local U = mw.ustring.char
local usub = mw.ustring.sub
local rmatch = mw.ustring.match
local rgmatch = mw.ustring.gmatch
local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local rsplit = mw.text.split


local long = "ː"
local nonsyllabic = U(0x32F)	-- inverted breve below
local syllabic = U(0x0329)
local syllabic_below = U(0x030D)
local raised = U(0x031D)		-- uptack below
local ringabove = U(0x030A)		-- ring above
local caron = U(0x030C)			-- combining caron
local tie = U(0x0361)			-- combining double inverted breve
local AC = U(0x0301)			-- combining acute accent
local primary_stress = "ˈ"
local secondary_stress = "ˌ"

local replacements = {
	--[[	ě, i, and í indicate that the preceding consonant
			t, d, or n is palatal, as if written ť, ď, or ň.	]]
	["([tdn])ě"] = "%1" .. caron .. "e",
	["([tdn])([ií])"] = "%1" .. caron .. "%2",
	["mě"] = "mn" .. caron .. "e",
}

local data = {
	["á"] = "a" .. long,
	["c"] = "t" .. tie .. "s",
	["č"] = "t" .. tie .. "ʃ",
	["ď"] = "ɟ",
	["e"] = "ɛ",
	["é"] = "ɛ" .. long,
	["ě"] = "jɛ",
	["g"] = "ɡ",
	["h"] = "ɦ",
	["ch"] = "x",
	["i"] = "ɪ",
	["í"] = "i" .. long,
	["ň"] = "ɲ",
	["ó"] = "o" .. long,
	["q"] = "k",
	["ř"] = "r" .. raised,
	["š"] = "ʃ",
	["t"] = "t",
	["ť"] = "c",
	["ú"] = "u" .. long,
	["ů"] = "u" .. long,
	["x"] = "ks",
	["y"] = "ɪ",
	["ý"] = "i" .. long,
	["ž"] = "ʒ",
	["ou"] = "ou" .. nonsyllabic,
	["au"] = "au" .. nonsyllabic,
	["eu"] = "ɛu" .. nonsyllabic,
	["\""] = primary_stress,
	["%"] = secondary_stress,
	["?"] = "ʔ",
}

-- Add data["a"] = "a", data["b"] = "b", etc.
for character in rgmatch("abdfjklmnoprstuvz ", ".") do
	data[character] = character
end

--[[	This allows multiple-character sounds to be replaced
		with single characters to make them easier to process.	]]

local multiple_to_single = {
	["t" .. tie .. "s"			] = "ʦ",
	["t" .. tie .. "ʃ"			] = "ʧ",
	["r" .. raised .. ringabove	] = "ṙ",
	["d" .. tie .. "z"			] = "ʣ",
	["d" .. tie .. "ʒ"			] = "ʤ",
	["r" .. raised				] = "ř",
}

--[[	"voiceless" and "voiced" are obstruents only;
		sonorants are not involved in voicing assimilation.	]]

-- ʦ, ʧ, "ṙ" replace t͡s, t͡ʃ, r̝̊
local voiceless	= { "p", "t", "c", "k", "f", "s", "ʃ", "x", "ʦ", "ʧ", "ṙ", "ʔ" }
-- "ʣ", ʤ, ř replace d͡z, d͡ʒ, r̝
local voiced	= { "b", "d", "ɟ", "ɡ", "v", "z", "ʒ", "ɦ", "ʣ", "ʤ", "ř", }
local sonorants = { "m", "n", "ɲ", "r", "l", "j", }
local consonant = "[" .. table.concat(sonorants) .. "ŋ"
	.. table.concat(voiceless) .. table.concat(voiced) .. "]"
assimil_consonants = {}
assimil_consonants.voiceless = voiceless
assimil_consonants.voiced = voiced

local features = {}
local indices = {}
for index, consonant in pairs(voiceless) do
	if not features[consonant] then
		features[consonant] = {}
	end
	features[consonant]["voicing"] = "voiceless"
	indices[consonant] = index
end

for index, consonant in pairs (voiced) do
	if not features[consonant] then
		features[consonant] = {}
	end
	features[consonant]["voicing"] = "voiced"
	indices[consonant] = index
end
	
local short_vowel = "[aɛɪou]"
local long_vowel = "[aɛiou]" .. long
local diphthong ="[aɛo]u" .. nonsyllabic
local syllabic_consonant = "[mnrl]" .. syllabic

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

-- Apply canonical Unicode decomposition to text, e.g. è → e + ◌̀. But recompose characters with caron and ringabove.
local function decompose(text)
	text = mw.ustring.toNFD(text)
	text = rsub(text, ".[" .. caron .. ringabove .. "]", {
		["c" .. caron] = "č",
		["C" .. caron] = "Č",
		["s" .. caron] = "š",
		["S" .. caron] = "Š",
		["z" .. caron] = "ž",
		["Z" .. caron] = "Ž",
		["n" .. caron] = "ň",
		["N" .. caron] = "Ň",
		["d" .. caron] = "ď",
		["D" .. caron] = "Ď",
		["t" .. caron] = "ť",
		["T" .. caron] = "Ť",
		["r" .. caron] = "ř",
		["R" .. caron] = "Ř",
		["e" .. caron] = "ě",
		["E" .. caron] = "Ě",
		["u" .. ringabove] = "ů",
		["U" .. ringabove] = "Ů",
	})
	return text
end

-- Apply canonical Unicode composition to text, e.g. e + ◌̀ → è.
local function compose(text)
	return mw.ustring.toNFC(text)
end

-- all but v and r̝
local causing_assimilation =
	rsub(
		"[" .. table.concat(voiceless) .. table.concat(voiced) .. "ʔ]",
		"[vř]",
		""
	)

local assimilable = "[" .. table.concat(voiceless):gsub("ʔ", "") .. table.concat(voiced) .. "]"

local function regressively_assimilate(IPA)
	IPA = rsub(
		IPA,
		"(" .. assimilable .. "+)(" .. causing_assimilation .. ")",
		function (assimilated, assimilator)
			local voicing = features[assimilator] and features[assimilator].voicing
				or error('The consonant "' .. consonant
					.. '" is not recognized by the function "regressively_assimilate".')
			return rsub(
				assimilated,
				".",
				function (consonant)
					return assimil_consonants[voicing][indices[consonant]]
				end)
				.. assimilator
			end)
	
	IPA = rsub(IPA, "smus", "zmus")
	
	return IPA	
end

local function devoice_finally(IPA)
	local obstruent = "[" .. table.concat(voiced) .. table.concat(voiceless) .. "]"
	
	IPA = rsub(
		IPA,
		"(" .. obstruent .. "+)#",
		function (final_obstruents)
			return rsub(
				final_obstruents,
				".",
				function (obstruent)
					return voiceless[indices[obstruent]]
				end)
				.. "#"
		end)
	
	return IPA
end

local function devoice_fricative_r(IPA)
	-- all but r̝̊, which is added by this function
	local voiceless = rsub("[" .. table.concat(voiceless) .. "]", "ṙ", "")
	
	-- ř represents r̝, "ṙ" represents r̝̊
	IPA = rsub(IPA, "(" .. voiceless .. ")" .. "ř", "%1ṙ")
	IPA = rsub(IPA, "ř" .. "(" .. voiceless .. ")", "ṙ%1")
	
	return IPA
end

local function syllabicize_sonorants(IPA)
	 -- all except ɲ and j
	local sonorant = rsub("[" .. table.concat(sonorants) .. "]", "[ɲj]", "")
	local obstruent = "[" .. table.concat(voiced) .. table.concat(voiceless) .. "]"
	
	-- between a consonant and an obstruent
	IPA = rsub(
		IPA,
		"(" .. consonant .. "+" .. sonorant .. ")(" .. consonant .. ")",
		"%1" .. syllabic .. "%2"
		)
	
	-- at the end of a word after an obstruent
	IPA = rsub(IPA, "(" .. obstruent .. sonorant .. ")#", "%1" .. syllabic)
	
	return IPA
end

local function assimilate_nasal(IPA)
	local velar = "[ɡk]"
	
	IPA = rsub(IPA, "n(" .. velar .. ")", "ŋ%1")
	
	return IPA
end

local function add_stress(IPA)
	local syllable_count = m_syllables.getVowels(IPA, lang)
	
	if not ( nostress or rfind(IPA, ".#.") or rfind(IPA, primary_stress) ) then
		IPA = primary_stress .. IPA
	end
	
	return IPA
end

local function syllabify(IPA)
	local syllables = {}
	
	local working_string = IPA
	
	local noninitial_cluster = rmatch(working_string, ".(" .. consonant .. consonant .. ").")
	local has_cluster = noninitial_cluster and not rfind(noninitial_cluster, "(.)%1")
	
	if not ( has_cluster or rfind(working_string, " ") ) then
		while #working_string > 0 do
			local syllable = rmatch(working_string, "^" .. consonant .. "*" .. diphthong)
				or rmatch(working_string, "^" .. consonant .. "*" .. long_vowel)
				or rmatch(working_string, "^" .. consonant .. "*" .. short_vowel)
				or rmatch(working_string, "^" .. consonant .. "*" .. syllabic_consonant)
			if syllable then
				table.insert(syllables, syllable)
				working_string = rsub(working_string, syllable, "", 1)
			elseif rfind(working_string, "^" .. consonant .. "+$")
				or rfind(working_string, primary_stress)
				then
			
				syllables[#syllables] = syllables[#syllables] .. working_string
				working_string = ""
			else
			error('The function "syllabify" could not find a syllable '
				.. 'in the IPA transcription "' .. working_string .. '".')
			end
		end
	end
	
	if #syllables > 0 then
		IPA = table.concat(syllables, ".")
	end
	
	return IPA
end

local function apply_rules(IPA)
	--[[	Adds # at word boundaries and in place of spaces, to
			unify treatment of initial and final conditions.
			# is commonly used in phonological rule notation
			to represent word boundaries.						]]
	IPA = "#" .. IPA .. "#"
	IPA = rsub(IPA, "%s+", "#")
	
	-- Handle consonantal prepositions: v, z.
	IPA = rsub(
		IPA,
		"(#[vz])#(.)",
		function (preposition, initial_sound)
			if rfind(initial_sound, short_vowel) then
				return preposition .. "ʔ" .. initial_sound
			else
				return preposition .. initial_sound
			end
		end)
	
	for sound, character in pairs(multiple_to_single) do
		IPA = rsub(IPA, sound, character)
	end
	
	IPA = regressively_assimilate(IPA)
	IPA = devoice_finally(IPA)
	IPA = devoice_fricative_r(IPA)
	IPA = syllabicize_sonorants(IPA)
	IPA = assimilate_nasal(IPA)
	IPA = add_stress(IPA, nostress)
	
	for sound, character in pairs(multiple_to_single) do
		IPA = rsub(IPA, character, sound)
	end
	
	--[[	This replaces double (geminate) with single consonants,
			and changes a stop plus affricate to affricate:
			for instance, [tt͡s] to [t͡s].								]]
	IPA = rsub(IPA, "(" .. consonant .. ")%1", "%1")
	
	-- Replace # with space or remove it.
	IPA = rsub(IPA, "([^" .. primary_stress .. secondary_stress .. "])#(.)", "%1 %2")
	IPA = rsub(IPA, "#", "")
	
	
	return IPA
end

function export.toIPA(term, nostress)
	local IPA = {}
	
	local transcription = mw.ustring.lower(term)
	transcription = rsub(transcription, "^%-", "")
	transcription = rsub(transcription, "%-?$", "")
	transcription = rsub(transcription, "nn", "n") -- similar operation is applied to IPA above
	
	for regex, replacement in pairs(replacements) do
		transcription = rsub(transcription, regex, replacement)
	end
	transcription = mw.ustring.toNFC(transcription)	-- Recompose combining caron.
	
	local working_string = transcription
	
	while mw.ustring.len(working_string) > 0 do
		local IPA_letter
		
		local letter = usub(working_string, 1, 1)
		local twoletters = usub(working_string, 1, 2) or ""
		
		if data[twoletters] then
			IPA_letter = data[twoletters]
			working_string = usub(working_string, 3)
		else
			IPA_letter = data[letter]
				or error('The letter "' .. tostring(letter)
					.. '" is not a member of the Czech alphabet.')
			working_string = usub(working_string, 2)
		end
		
		table.insert(IPA, IPA_letter)
	end
	
	IPA = table.concat(IPA)
	IPA = apply_rules(IPA, nostress)
	
	return IPA, transcription
end

local function convert_respelling_to_original(to, pagename, whole_word)
	if not patut then
		patut = require(patut_module)
	end
	local from = to:gsub("y", "i"):gsub("z", "s"):gsub(AC, "")
	local escaped_from = patut.pattern_escape(from)
	if whole_word then
		escaped_from = "%f[%a]" .. escaped_from .. "%f[%A]"
	end
	if rfind(pagename, escaped_from) then
		return from
	end
	-- Check for partial replacement.
	escaped_from = patut.pattern_escape(to)
	escaped_from = "(" .. escaped_from:gsub("y", "[iy]"):gsub("z", "[sz]"):gsub(AC, AC .. "?") .. ")"
	if whole_word then
		escaped_from = "%f[%a]" .. escaped_from .. "%f[%A]"
	end
	local match = rmatch(pagename, escaped_from)
	if match then
		if match == to then
			error(("Single substitution spec '%s' found in pagename '%s', replacement would have no effect"):
				format(to, pagename))
		end
		return match
	end
	error(("Single substitution spec '%s' couldn't be matched to pagename '%s'"):format(to, pagename))
end
	

-- Given raw respelling, canonicalize it. This currently applies substitutions of the form e.g. [ny] or [th:t,nýz].
local function canonicalize(text, pagename)
	text = decompose(text)
	pagename = decompose(pagename)
	if text == "+" then
		text = pagename
	elseif rfind(text, "^%[.*%]$") then
		local subs = rsplit(rmatch(text, "^%[(.*)%]$"), ",")
		text = pagename
		local function err(msg)
			error(msg .. ": " .. text)
		end
		for _, sub in ipairs(subs) do
			local from, escaped_from, to, escaped_to, whole_word
			if rfind(sub, "^~") then
				-- whole-word match
				sub = rmatch(sub, "^~(.*)$")
				whole_word = true
			end
			if sub:find(":") then
				from, to = rmatch(sub, "^(.-):(.*)$")
			else
				to = sub
				from = convert_respelling_to_original(to, pagename, whole_word)
			end
			if not patut then
				patut = require(patut_module)
			end
			escaped_from = patut.pattern_escape(from)
			if whole_word then
				escaped_from = "%f[%a]" .. escaped_from .. "%f[%A]"
			end
			escaped_to = patut.replacement_escape(to)
			local subbed_text, nsubs = rsubn(text, escaped_from, escaped_to)
			if nsubs == 0 then
				err(("Substitution spec %s -> %s didn't match processed pagename"):format(from, to))
			elseif nsubs > 1 then
				err(("Substitution spec %s -> %s matched multiple substrings in processed pagename, add more context"):format(from, to))
			else
				text = subbed_text
			end
		end
	end

	return compose(text)
end

function export.show(frame)
	local params = {
		[1] = {list = true},
		["nostress"] = { type = "boolean" },
		["pagename"] = {}, -- for testing
	}

	local parargs = frame:getParent().args
	local args = m_params.process(parargs, params)
	local title = mw.title.getCurrentTitle()
	local pagename = args.pagename or title.subpageText

	-- Parse the arguments.
	local respellings = #args[1] > 0 and args[1] or title.namespace == "Template" and pagename == "cs-IPA" and "příklad" or {"+"}
	local prons = {}
	for i, respelling in ipairs(respellings) do
		respelling = canonicalize(respelling, pagename)
		local IPA = export.toIPA(respelling, nostress)
		IPA = "[" .. IPA .. "]"
		IPA = m_IPA.format_IPA_full(lang, { { pron = IPA } } )
		table.insert(prons, IPA)
	end

	return table.concat(prons, "\n* ")
end

function export.example(frame)
	local output = {
[[
{| class="wikitable"
]]
	}
	local row
	
	local namespace = mw.title.getCurrentTitle().nsText
	
	if namespace == "Template" then
		table.insert(
			output, 
[[
! headword !! code !! result
]]
		)
		row =
[[
|-
| link || template_code || IPA
]]
	else
		table.insert(
			output, 
[[
! headword !! result
]]
		)
		row =
[[
|-
| link || IPA
]]
	end
	
	local params = {
		[1] = { required = true },
	}
	
	local args = m_params.process(frame:getParent().args, params)
	local terms = mw.text.split(args[1] or "příklad", ", ")
	
	for _, term in ipairs(terms) do
		local template_parameter
		local respelling_regex = "[%a\"%?%% ]+"
		local respelling = rmatch(term, "(" .. respelling_regex .. ") %(")
			or rmatch(term, respelling_regex)
		local entry = rmatch(term, "%(([%a ]+)%)") or respelling
		local link = export.link(entry)
		
		local IPA, transcribable = export.toIPA(respelling)
		IPA = m_IPA.format_IPA_full(lang, { { pron = "[" .. IPA .. "]" } } )
		
		if term ~= respelling then
			template_parameter = respelling
		end
		
		if term ~= transcribable then
			link = link .. " (" .. export.tag_text(transcribable) .. ")"
		end
		
		template_code = m_template_link.format_link{ "cs-IPA", template_parameter }
		
		local content = {
			link = link,
			template_code = template_code,
			IPA = IPA
		}
		
		local function add_content(name)
			if content[name] then
				return content[name]
			else
				error('No content for "' .. name .. '".')
			end
		end
		
		local current_row = rsub(row, "[%a_]+", add_content)
		
		table.insert(output, current_row)
	end
	
	table.insert(output, "|}")
	
	return table.concat(output)
end

return export
