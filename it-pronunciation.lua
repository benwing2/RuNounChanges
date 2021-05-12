local export = {}

local m_table = require("Module:table")

local u = mw.ustring.char
local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local ulower = mw.ustring.lower
local uupper = mw.ustring.upper
local usub = mw.ustring.sub
local ulen = mw.ustring.len

local lang = require("Module:languages").getByCode("it")

local AC = u(0x301)
local GR = u(0x300)
local CFLEX = u(0x302)
local DOTOVER = u(0x0307) -- dot over =  ̇ = signal unstressed word
local stress = AC .. GR
local stress_c = "[" .. stress .. "]"
local accent = stress .. DOTOVER
local accent_c = "[" .. accent .. "]"
local vowels = "aeɛioɔu"
local vowel_c = "[" .. vowels .. "]"
local vocalic_c = "[" .. vowels .. "jw]"
local not_vowel_c = "[^" .. vowels .. "]"
local front = "[eɛij]"
local FRONTED = u(0x031F)
local voiced_consonant = "[bdɡlmnrv]"

local full_affricates = { ["ʦ"] = "t͡s", ["ʣ"] = "d͡z", ["ʧ"] = "t͡ʃ", ["ʤ"] = "d͡ʒ" }

local recognized_suffixes = {
	-- -(m)ente, -(m)ento
	{"ment([eo])", "mént%2"}, -- must precede -ente/o below
	{"ent([eo])", "ènt%2"}, -- must follow -mente/o above
	-- verbs
	{"izzare", "iddzàre"}, -- must precede -are below
	{"izzarsi", "iddzàrsi"}, -- must precede -arsi below
	{"([ai])re", "%2" .. GR .. "re"}, -- must follow -izzare above
	{"([ai])rsi", "%2" .. GR .. "rsi"}, -- must follow -izzarsi above
	-- nouns
	{"izzatore", "iddzatóre"}, -- must precede -tore below
	{"([st])ore", "%2óre"}, -- must follow -izzatore above
	{"izzatrice", "iddzatrìce"}, -- must precede -trice below
	{"trice", "trìce"}, -- must follow -izzatrice above
	{"izzazione", "iddzatsióne"}, -- must precede -zione below
	{"zione", "tsióne"}, -- must precede -one below and follow -izzazione above
	{"one", "óne"}, -- must follow -zione above
	{"acchio", "àcchio"},
	{"acci([ao])", "àcci%2"},
	{"([aiu])ggine", "%2" .. GR .. "ggine"},
	{"aggio", "àggio"},
	{"[ai]gli([ao])", "%2" .. GR .. "gli%3"},
	{"ai([ao])", "ài%2"},
	{"([ae])nza", "%2" .. GR .. "ntsa"},
	{"ario", "àrio"},
	{"([st])orio", "%2òrio"},
	{"astr([ao])", "àstr%2"},
	{"ell([ao])", "èll%2"},
	{"etta", "étta"},
	-- do not include -etto, both ètto and étto are common
	{"ezza", "éttsa"},
	{"ficio", "fìcio"},
	{"ier([ao])", "ièr%2"},
	{"ifero", "ìfero"},
	{"ismo", "ìsmo"},
	{"ista", "ìsta"},
	{"izi([ao])", "ìtsi%2"},
	{"logia", "logìa"},
	-- do not include -otto, both òtto and ótto are common
	{"tudine", "tùdine"},
	{"ura", "ùra"},
	{"([^aeo])uro", "%2ùro"},
	-- adjectives
	{"izzante", "iddzànte"}, -- must precede -ante below
	{"ante", "ànte"}, -- must follow -izzante above
	{"izzando", "iddzàndo"}, -- must precede -ando below
	{"([ae])ndo", "%2" .. GR .. "ndo"}, -- must follow -izzando above
	{"([ai])bile", "%2" .. GR .. "bile"},
	{"ale", "àle"},
	{"([aeiou])nico", "%2" .. GR .. "nico"},
	{"([ai])stic([ao])", "%2" .. GR .. "stic%3"},
	-- exceptions to the following: àbato, àcato, acròbata, àgata, apòstata, àstato, cìato, fégato, omeòpata,
	-- sàb(b)ato, others?
	{"at([ao])", "àt%2"},
	{"([ae])tic([ao])", "%2" .. GR .. "tic%3"},
	{"ense", "ènse"},
	{"esc[ao]", "ésc%2"},
	{"evole", "évole"},
	-- FIXME: Systematic exceptions to the following in 3rd plural present tense verb forms
	{"ian[ao]", "iàn%2"},
	{"iv[ao]", "ìv%2"},
	{"oide", "òide"},
	{"oso", "óso"},
}

local unstressed_words = m_table.listToSet {
	"il", "lo", "la", "i", "gli", "le", -- definite articles
	"un", -- indefinite articles
	"mi", "ti", "ci", "vi", "li", -- object pronouns
	"se", "chi", "che", "non", -- misc particles
	"di", "del", "dei", -- prepositions
	"a", "al", "ai",
	"da", "dal", "dai",
	"in", "nel", "nei",
	"con", "col", "coi",
	"su", "sul", "sui",
	"per", "pei",
	"tra", "fra",
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

-- ʦ, ʣ, ʧ, ʤ used for t͡s, d͡z, t͡ʃ, d͡ʒ in body of function.
-- voiced_z must be a table of integer indices, a boolean, or nil.
function export.to_phonemic(text, voiced_z, pagename, single_character_affricates)
	local all_z_voiced
	if type(voiced_z) == "boolean" then
		all_z_voiced = voiced_z
		voiced_z = nil
	else
		require "libraryUtil".checkTypeMulti("to_IPA", 2, voiced_z,
			{ "table", "boolean", "nil" })
	end
	
	local abbrev_text
	if rfind(text, "^[àéèìóòù]$") then
		abbrev_text = mw.ustring.toNFD(text)
		text = pagename
	end
	local origtext = text
	text = ulower(text)
	
	-- Decompose combining characters: for instance, è → e + ◌̀
	text = mw.ustring.toNFD(text)

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

	-- Make prefixes unstressed unless they have an explicit stress marker; likewise for certain monosyllabic
	-- words without stress marks.
	local words = rsplit(text, " ")
	for i, word in ipairs(words) do
		if rfind(word, "%-$") and not rfind(word, accent_c) or unstressed_words[word] then
			-- add DOTOVER to the first vowel for cases like [[dei]], [[sui]]
			words[i] = rsub(word, "^(.-" .. V .. ")", "%1" .. DOTOVER)
		end
	end
	text = table.concat(words, " ")
	-- put # at word beginning and end and double ## at text/foot boundary beginning/end
	text = rsub(text, " | ", "# | #")
	text = "##" .. rsub(text, " ", "# #") .. "##"

	-- random substitutions
	text = text:gsub("'", ""):gsub("x", "ks"):gsub("y", "i"):gsub("ck", "k"):gsub("sh", "ʃ"):gsub("ng#", "ŋ#")

	local words = rsplit(text, " ")

	for i, word in ipairs(words) do
		-- Transcriptions must contain an acute or grave, to indicate stress position.
		-- This does not handle phrases containing more than one stressed word.
		-- Default to penultimate stress rather than throw error?
		local vowel_count = select(2, word:gsub("[aeiou]", "%1"))
		if not rfind(word, accent_c) then
			-- Allow monosyllabic unstressed words.
			if vowel_count > 1 then
				if abbrev_text then
					local abbrev_vowel = usub(abbrev_text, 1, 1)
					local before, penultimate, between, glide, after = rmatch(word, 
						"^(.*)(" .. vowel_c .. ")(" .. not_vowel_c .. "*)([iu]?)(" .. vowel_c .. not_vowel_c .. "*)$")
					if not before then
						error("Internal error: Couldn't match multisyllabic word: " .. word)
					end
					local before2, antepenultimate, between2, glide2 = rmatch(before, 
						"^(.-)(" .. vowel_c .. ")(" .. not_vowel_c .. "*)([iu]?)$")
					if abbrev_vowel ~= penultimate and abbrev_vowel ~= antepenultimate and abbrev_vowel ~= glide and
						abbrev_vowel ~= glide2 then
						error("Abbreviated spec '" .. abbrev_text .. "' doesn't match penultimate vowel " ..
							penultimate .. (antepenultimate and " or antepenultimate vowel " .. antepenultimate or "")
							.. ((glide ~= "" or glide2 ~= "") and ", or any glide" or "") ..
							": " .. origtext)
					end
					if penultimate == antepenultimate then
						error("Can't use abbreviated spec '" .. abbrev_text .. "' here because penultimate and " ..
							"antepenultimate are the same: " .. origtext)
					end
					if abbrev_vowel == antepenultimate then
						word = before2 .. abbrev_text .. between2 .. glide2 .. penultimate .. between .. glide .. after
					elseif abbrev_vowel == penultimate then
						word = before .. abbrev_text .. between .. glide .. after
					elseif glide == glide2 then
						error("Can't use abbreviated spec '" .. abbrev_text .. "' here because penultimate and " ..
							"antepenultimate glides are the same: " .. origtext)
					elseif abbrev_vowel == glide2 then
						word = before2 .. antepenultimate .. between2 .. abbrev_vowel .. penultimate .. between .. glide .. after
					elseif abbrev_vowel == glide then
						word = before2 .. antepenultimate .. between2 .. glide2 .. penultimate .. between .. abbrev_vowel .. after
					else
						error("Internal error: abbrev_vowel from abbrev_text '" .. abbrev_text .. "' didn't match any vowel or glide: " .. origtext)
					end
				else
					-- Add acute accent on second-to-last vowel. FIXME: Throw an error here instead.
					word = rsub(word, 
						"(" .. vowel_c .. ")(" .. not_vowel_c .. "*[iu]?" .. vowel_c .. not_vowel_c .. "*)$",
						"%1" .. AC .. "%2")
				end
			end
		end

		word = rsub(word, "([aiu])" .. AC, "%1" .. GR)

		-- Assume that aw is English.
		word = rsub(
			word,
			"a(" .. GR .. "?)w",
			{ [""] = vowel_count == 1 and "ɔ" or "o", [GR] = "ɔ"})

		words[i] = word
	end

	text = table.concat(words, " ")
	
	-- Handle è, ò.
	text = text:gsub("([eo])(" .. GR .. ")",
		function (vowel, accent)
			return ({ e = "ɛ", o = "ɔ" })[vowel] .. accent
		end) -- e or o followed by grave
	
	-- ci, gi + vowel
	-- Do ci, gi + e, é, è sometimes contain /j/?
	text = rsub(text,
		"([cg])([cg]?)i(" .. vowel_c .. ")",
		function (consonant, double, vowel)
			local out_consonant
			if consonant == "c" then
				out_consonant = "ʧ"
			else
				out_consonant = "ʤ"
			end
			
			if double ~= "" then
				if double ~= consonant then
					error("Invalid sequence " .. consonant .. double .. ".")
				end
				
				out_consonant = out_consonant .. out_consonant
			end
			
			return out_consonant .. vowel
		end)
	
	-- Handle gl and gn.
	text = rsub(text, "gn", "ɲ")
	text = rsub(text, "gli(" .. vowel_c .. ")", "ʎ%1")
	text = rsub(text, "gli", "ʎi")
	
	-- Handle other cases of c, g.
	text = rsub(text,
		"(([cg])([cg]?)(h?))(.)",
		function (consonant, first, double, h, next)
			-- Don't allow the combinations cg, gc.
			-- Or do something else?
			if double ~= "" and double ~= first then
				error("Invalid sequence " .. first .. double .. ".")
			end
			
			-- c, g is soft before e, i.
			local consonant
			if (next == "e" or next == "ɛ" or next == "i") and h ~= "h" then
				if first == "c" then
					consonant = "ʧ"
				else
					consonant = "ʤ"
				end
			else
				if first == "c" then
					consonant = "k"
				else
					consonant = "ɡ"
				end
			end
			
			if double ~= "" then
				consonant = consonant .. consonant
			end
			
			return consonant .. next
		end)
	
	-- ⟨qu⟩ represents /kw/.
	text = text:gsub("qu", "kw")
	
	-- u or i (without accent) before another vowel is a semivowel.
	-- ci, gi + vowel, gli, qu must be dealt with beforehand.
	text = rsub(text,
		"([iu])(" .. vowel_c .. ")",
		function (semivowel, vowel)
			if semivowel == "i" then
				semivowel = "j"
			else
				semivowel = "w"
			end
			
			return semivowel .. vowel
		end)
	
	-- sc before e, i is /ʃ/, doubled after a vowel.
	text = text:gsub("sʧ", "ʃ")
	
	-- ⟨z⟩ represents /t͡s/ or /d͡z/; no way to determine which.
	-- For now, /t͡s/ is the default.
	text = rsub(text, "izza" .. GR .. "?re#", "iddzàre#")

	text = rsub(text, "ddz", "ʣʣ")
	text = rsub(text, "dz", "ʣ")
	text = rsub(text, "tts", "ʦʦ")
	text = rsub(text, "ts", "ʦ")

	local z_index = 0
	text = rsub(
		text,
		"()(z+)(.)",
		function (pos, z, after)
			local length = #z
			if length > 2 then
				error("Too many z's in a row!")
			end
			
			z_index = z_index + 1
			local voiced = voiced_z and require "Module:table".contains(voiced_z, z_index)
					or all_z_voiced
			
			if usub(text, pos - 1, pos - 1) == "#" then
				if rfind(text, "^[ij]" .. GR .. "?" .. vowel_c, pos + #z) then
					voiced = false
				elseif rfind(text, "^" .. vowel_c .. stress_c .. "?" .. vowel_c, pos + #z) then
					voiced = true
				end
				-- check whether followed by two vowels
				-- check onset of next syllable
			else
				if rfind(after, vocalic_c) then
					
					local before = usub(text, pos - 2, pos - 1)
					
					if rfind(before, vocalic_c .. stress_c .. "?$") then
						if length == 1 and rfind(after, vowel_c)
						and rfind(before, vowel_c) then
							voiced = true
						end
						
						length = 2
					end
					
					if usub(text, pos + #z, pos + #z + 1) == "i" .. CFLEX then
						voiced = false
					end
				end
			end
			
			return (voiced and "ʣ" or "ʦ"):rep(length) .. after
		end)
	
	-- Replace acute and grave with stress mark.
	text = rsub(text,
		"(" .. vowel_c .. ")" .. stress_c, "ˈ%1")
	
	-- Single ⟨s⟩ between vowels is /z/.
	text = rsub(text, "(" .. vowel_c .. ")s(ˈ?" .. vocalic_c .. ")", "%1z%2")
	
	-- ⟨s⟩ immediately before a voiced consonant is always /z/
	text = rsub(text,
		"s(" .. voiced_consonant .. ")", "z%1")
	
	-- After a vowel, /ʃ ʎ ɲ/ are doubled.
	-- [[w:Italian phonology]] says word-internally, [[w:Help:IPA/Italian]] says
	-- after a vowel.
	text = rsub(text,
		"(" .. vowel_c .. ")([ʃʎɲ])", "%1%2%2")
	
	-- Move stress before syllable onset, and add syllable breaks.
	-- This rule may need refinement.
	text = rsub(text,
		"()(" .. not_vowel_c .. "?)([^" .. vowels .. "ˈ]*)(ˈ?)([jw]?" .. vowel_c .. ")",
		function (position, first, rest, syllable_divider, vowel)
			-- beginning of word, that is, at the moment, beginning of string
			if position == 1 then
				return syllable_divider .. first .. rest .. vowel
			end
			
			if syllable_divider == "" then
				syllable_divider = "."
			end
			
			if rest == "" then
				return syllable_divider .. first .. vowel
			elseif (rest == "j" or rest == "w") and first ~= rest then
				return syllable_divider .. first .. rest .. vowel
			else
				return first .. syllable_divider .. rest .. vowel
			end
		end)
	
	if not single_character_affricates then
		text = rsub(text, "([ʦʣʧʤ])([%.ˈ]*)([ʦʣʧʤ]*)",
			function (affricate1, divider, affricate2)
				local full_affricate = full_affricates[affricate1]
				
				if affricate2 ~= "" then
					return usub(full_affricate, 1, 1) .. divider .. full_affricate
				end
				
				return full_affricate .. divider
			end)
	end
	
	text = rsub(text, "[h%-" .. CFLEX .. "]", "")
	text = text:gsub("%.ˈ", "ˈ")
	
	return text
end

-- Incomplete and currently not used by any templates.
function export.to_phonetic(word, voiced_z, pagename)
	local phonetic = export.to_phonemic(word, voiced_z, pagename)
	
	-- Vowels longer in stressed, open, non-word-final syllables.
	phonetic = rsub(phonetic,
		"(ˈ" .. not_vowel_c .. "*" .. vowel_c .. ")([" .. vowels .. "%.])",
		"%1ː%2")
	
	-- /n/ before /ɡ/ or /k/ is [ŋ]
	phonetic = rsub(phonetic,
		"n([%.ˈ]?[ɡk])", "ŋ%1")

	-- Imperfect: doesn't convert geminated k, g properly.
	phonetic = rsub(phonetic,
			"([kg])(" .. front .. ")",
			"%1" .. FRONTED .. "%2")
		:gsub("a", "ä")
		:gsub("n", "n̺") -- Converts n before a consonant, which is incorrect.
	
	return phonetic
end

function export.show(frame)
	local m_IPA = require "Module:IPA"
	
	local args = require "Module:parameters".process(
		frame:getParent().args,
		{
			-- words to transcribe
			[1] = { list = true },
			
			-- each parameter a series of numbers separated by commas,
			-- or a boolean, indicating that a particular z is voiced or
			-- that all of them are
			voiced = { list = true },
			pagename = {}, -- for testing
		})
	
	local pagename = args.pagename or mw.title.getCurrentTitle().text
	local Array = require "Module:array"
	
	local voiced_z = Array(args.voiced)
		:map(function (param)
			param = Array(rsplit(param, "%s*,%s*"))
				:map(
					function (item, i)
						return tonumber(item)
							or i == 1 and require "Module:yesno"(item) -- Rejects false values.
							or error("Invalid input '" .. item .."' in |voiced= parameter. "
								.. "Expected number or boolean.")
					end)
			
			if not param[2] and type(param[1]) == "boolean" then
				param = param[1]
			end
			
			return param
		end)
	
	local respellings = args[1]
	if #respellings == 0 then
		respellings = {pagename}
	end
	local transcriptions = Array(respellings):map(function(word, i)
		return { pron = "/" .. export.to_phonemic(word, voiced_z[i], pagename) .. "/" }
	end)
	
	return m_IPA.format_IPA_full(lang, transcriptions)
end

return export
