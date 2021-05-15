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
local DOTUNDER = u(0x0323) -- dot under =  ̣ = unstressed vowel with quality marker
local LINEUNDER = u(0x0331) -- line under =  ̱ = secondary-stressed vowel with quality marker
local TEMP1 = u(0xFFF0)
local SYLDIV = u(0xFFF1) -- used to represent a user-specific syllable divider (.) so we won't change it
local stress = "ˈˌ"
local stress_c = "[" .. stress .. "]"
local quality = AC .. GR
local quality_c = "[" .. quality .. "]"
local accent = stress .. quality .. DOTOVER .. DOTUNDER .. LINEUNDER
local accent_c = "[" .. accent .. "]"
local glides = "jw"
local W = "[" .. glides .. "]"
local vowel = "aeɛioɔuEO"
local V = "[" .. vowel .. "]"
local VW = "[" .. vowel .. "jw]"
local NV = "[^" .. vowel .. "]"
local charsep = accent .. "_." .. SYLDIV
local charsep_not_und = accent .. "." .. SYLDIV
local charsep_c = "[" .. charsep .. "]"
local wordsep = charsep .. " #"
local wordsep_not_und = charsep_not_und .. " #"
local wordsep_c = "[" .. wordsep .. "]"
local C = "[^" .. vowel .. wordsep .. "]" -- consonant
local C_OR_UND = "[^" .. vowel .. wordsep_not_und .. "]" -- consonant or underscore
local C_NOT_H = "[^h" .. vowel .. wordsep .. "]" -- consonant other than h
local front = "eɛij"
local front_c = "[" .. front .. "]"
local FRONTED = u(0x031F)
local voiced_C_c = "[bdglmnrvʣŋʎɲ]"

local full_affricates = { ["ʦ"] = "t͡s", ["ʣ"] = "d͡z", ["ʧ"] = "t͡ʃ", ["ʤ"] = "d͡ʒ" }

local recognized_suffixes = {
	-- -(m)ente, -(m)ento
	{"ment([eo])", "mént%1"}, -- must precede -ente/o below
	{"ent([eo])", "ènt%1"}, -- must follow -mente/o above
	-- verbs
	{"izzare", "iddzàre"}, -- must precede -are below
	{"izzarsi", "iddzàrsi"}, -- must precede -arsi below
	{"([ai])re", "%1" .. GR .. "re"}, -- must follow -izzare above
	{"([ai])rsi", "%1" .. GR .. "rsi"}, -- must follow -izzarsi above
	-- nouns
	{"izzatore", "iddzatóre"}, -- must precede -tore below
	{"([st])ore", "%1óre"}, -- must follow -izzatore above
	{"izzatrice", "iddzatrìce"}, -- must precede -trice below
	{"trice", "trìce"}, -- must follow -izzatrice above
	{"izzazione", "iddzatsióne"}, -- must precede -zione below
	{"zione", "tsióne"}, -- must precede -one below and follow -izzazione above
	{"one", "óne"}, -- must follow -zione above
	{"acchio", "àcchio"},
	{"acci([ao])", "àcci%1"},
	{"([aiu])ggine", "%1" .. GR .. "ggine"},
	{"aggio", "àggio"},
	{"[ai]gli([ao])", "%1" .. GR .. "gli%2"},
	{"ai([ao])", "ài%1"},
	{"([ae])nza", "%1" .. GR .. "ntsa"},
	{"ario", "àrio"},
	{"([st])orio", "%1òrio"},
	{"astr([ao])", "àstr%1"},
	{"ell([ao])", "èll%1"},
	{"etta", "étta"},
	-- do not include -etto, both ètto and étto are common
	{"ezza", "éttsa"},
	{"ficio", "fìcio"},
	{"ier([ao])", "ièr%1"},
	{"ifero", "ìfero"},
	{"ismo", "ìsmo"},
	{"ista", "ìsta"},
	{"izi([ao])", "ìtsi%1"},
	{"logia", "logìa"},
	-- do not include -otto, both òtto and ótto are common
	{"tudine", "tùdine"},
	{"ura", "ùra"},
	{"([^aeo])uro", "%1ùro"},
	-- adjectives
	{"izzante", "iddzànte"}, -- must precede -ante below
	{"ante", "ànte"}, -- must follow -izzante above
	{"izzando", "iddzàndo"}, -- must precede -ando below
	{"([ae])ndo", "%1" .. GR .. "ndo"}, -- must follow -izzando above
	{"([ai])bile", "%1" .. GR .. "bile"},
	{"ale", "àle"},
	{"([aeiou])nico", "%1" .. GR .. "nico"},
	{"([ai])stic([ao])", "%1" .. GR .. "stic%2"},
	-- exceptions to the following: àbato, àcato, acròbata, àgata, apòstata, àstato, cìato, fégato, omeòpata,
	-- sàb(b)ato, others?
	{"at([ao])", "àt%1"},
	{"([ae])tic([ao])", "%1" .. GR .. "tic%2"},
	{"ense", "ènse"},
	{"esc[ao]", "ésc%1"},
	{"evole", "évole"},
	-- FIXME: Systematic exceptions to the following in 3rd plural present tense verb forms
	{"ian[ao]", "iàn%1"},
	{"iv[ao]", "ìv%1"},
	{"oide", "òide"},
	{"oso", "óso"},
}

local unstressed_words = m_table.listToSet {
	"il", "lo", "la", "i", "gli", "le", -- definite articles
	"un", -- indefinite articles
	"mi", "ti", "ci", "vi", "li", -- object pronouns
	"e", "o", -- conjunctions
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

function export.to_phonemic(text, pagename)
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
	text = rsub(text, "[!?]", "") -- eliminate remaining punctuation

	-- canonicalize multiple spaces and remove leading and trailing spaces
	local function canon_spaces(text)
		text = rsub(text, "%s+", " ")
		text = rsub(text, "^ ", "")
		text = rsub(text, " $", "")
		return text
	end

	text = canon_spaces(text)

	local origwords = rsplit(text, " ")

	text = rsub(text, CFLEX, "") -- eliminate circumflex over î, etc.
	text = rsub("y", "i")
	text = rsub(text, "([" .. DOTUNDER .. LINEUNDER .. "])(" .. quality_c .. ")", "%2%1") -- acute/grave first
	text = rsub(text, "([aiu])" .. AC, "%1" .. GR) -- áíú -> àìù

	local words = rsplit(text, " ")
	for i, word in ipairs(words) do
		-- Apply suffix respellings.
		for _, suffix_pair in ipairs(recognized_suffixes) do
			local orig, respelling = unpack(suffix_pair)
			local replaced
			word, replaced = rsubb(word, orig .. "$", respelling)
			if replaced then
				-- Decompose again because suffix replacements may have accented chars.
				word = mw.ustring.toNFD(word)
				break
			end
		end

		-- Make monosyllabic words without stress marks unstressed.
		if unstressed_words[word] then
			-- add DOTOVER to the first vowel for cases like [[dei]], [[sui]]
			word = rsub(word, "^(.-" .. V .. ")", "%1" .. DOTOVER)
		end

		-- Words marked with an acute or grave (quality marker) not followed by an indicator of secondary stress
		-- or non-stress get primary stress.
		word = rsub(word, "(" .. quality_c .. ")([^" .. DOTUNDER .. LINEUNDER .. "])", "%1ˈ%2")
		word = rsub(word, "(" .. quality_c .. ")$", "%1ˈ")
		-- Eliminate quality marker on a/i/u, which now serves no purpose.
		word = rsub(word, "([aiu])" .. quality_c, "%1")
		-- LINEUNDER means secondary stress.
		word = rsub(word, LINEUNDER, "ˌ")

		-- Make prefixes unstressed unless they have an explicit stress marker.
		if rfind(word, "%-$") and not rfind(word, "[" .. stress .. DOTUNDER .. "]") then
			-- add DOTOVER to the first vowel for cases like [[dei]], [[sui]]
			word = rsub(word, "^(.-" .. V .. ")", "%1" .. DOTOVER)
		end
		words[i] = word
	end
	text = table.concat(words, " ")

	-- Convert hyphens to spaces, to handle [[Austria-Hungria]], [[franco-italiano]], etc.
	text = rsub(text, "%-", " ")
	-- canonicalize multiple spaces again, which may have been introduced by hyphens
	text = canon_spaces(text)
	-- put # at word beginning and end and double ## at text/foot boundary beginning/end
	text = rsub(text, " | ", "# | #")
	text = "##" .. rsub(text, " ", "# #") .. "##"

	-- Convert e/o unmarked for quality to E/O, and those marked for quality to e/o/ɛ/ɔ.
	local function convert_e_o(txt)
		return txt:gsub("[eo]", {["e"] = "E", ["o"] = "O"}):gsub("[EO]" .. quality_c, {
			["E" .. AC] = "e",
			["O" .. AC] = "o",
			["E" .. GR] = "ɛ",
			["O" .. GR] = "ɔ",
		})
	end

	text = convert_e_o(text)
	local words = rsplit(text, " ")

	for i, word in ipairs(words) do
		local function err(msg)
			error(msg .. ": " .. origwords[i])
		end
		-- Transcriptions must contain a primary stress indicator, and an e or o with primary stress must
		-- be marked for quality.
		if not rfind(word, "[ˈ" .. DOTOVER .. "]") then
			local vowel_count = select(2, word:gsub(V, "%1"))
			if abbrev_text then
				local abbrev_vowel = uupper(usub(abbrev_text, 1, 1))
				local abbrev_eo = convert_e_o(abbrev_text)
				if vowel_count == 0 then
					err("Abbreviated spec '" .. abbrev_text .. "' can't be used with nonsyllabic word")
				elseif vowel_count == 1 then
					local before, vow, after = rmatch(word, "^(.*)(" .. V .. ")(" .. NV .. "*)$")
					if not before then
						error("Internal error: Couldn't match monosyllabic word: " .. word)
					end
					if abbrev_vowel ~= vow then
						err("Abbreviated spec '" .. abbrev_text .. "' doesn't match vowel " .. ulower(vow))
					end
					word = before .. abbrev_eo .. after
				else
					local before, penultimate, after = rmatch(word,
						"^(.-)(" .. V .. ")(" .. NV .. "*" .. V .. NV .. "*)$")
					if not before then
						error("Internal error: Couldn't match multisyllabic word: " .. word)
					end
					local before2, antepenultimate, after2 = rmatch(before,
						"^(.-)(" .. V .. ")(" .. NV .. "*)$")
					if abbrev_vowel ~= penultimate and abbrev_vowel ~= antepenultimate then
						err("Abbreviated spec '" .. abbrev_text .. "' doesn't match penultimate vowel " ..
							ulower(penultimate) .. (antepenultimate and " or antepenultimate vowel " ..
								ulower(antepenultimate) or ""))
					end
					if penultimate == antepenultimate then
						err("Can't use abbreviated spec '" .. abbrev_text .. "' here because penultimate and " ..
							"antepenultimate are the same")
					end
					if abbrev_vowel == antepenultimate then
						word = before2 .. abbrev_eo .. after2 .. penultimate .. after
					elseif abbrev_vowel == penultimate then
						word = before .. abbrev_eo .. after
					else
						error("Internal error: abbrev_vowel from abbrev_text '" .. abbrev_text ..
							"' didn't match any vowel or glide: " .. origtext)
					end
				end
			elseif vowel_count > 2 then
				err("With more than two vowels and an unrecogized suffix, stress must be explicitly given")
			else
				local before, vow, after = rmatch(word, "^(.-)(" .. V .. ")(.*)$")
				if before then
					if vow == "E" or vow == "O" then
						err("When stressed vowel is e or o, it must be marked é/è or ó/ò to indicate quality")
					end
					word = before .. vow .. "ˈ" .. after
				end
			end
		end
		words[i] = word
	end

	text = table.concat(words, " ")
	-- Eliminate DOTOVER/DOTUNDER, which have served their purpose of preventing stress.
	text = rsub(text, "[" .. DOTOVER .. DOTUNDER .. "]", "")
	-- All remaining E/O are in unstressed syllables and become e/o.
	text = ulower(text)

	-- Assume that aw is English.
	text = rsub(text, "a(" .. accent_c .. "?)w", "o%1")

	-- Random substitutions.
	text = rsub(text, "^ex([" .. V .. "])", "eg[z]%1")
	text = text:gsub("x", "ks"):gsub("ck", "k"):gsub("sh", "ʃ"):gsub("ng#", "ŋ#")
	text = rsub(text, "%[z%]", TEMP1) -- [z] means /z/

	-- ci, gi + vowel
	-- Do ci, gi + e, é, è sometimes contain /j/?
	text = rsub(text,
		"([cg])([cg]?)i(" .. V .. ")", function(c, double, v)
			local out_cons
			if c == "c" then
				out_cons = "ʧ"
			else
				out_cons = "ʤ"
			end

			if double ~= "" then
				if double ~= c then
					error("Invalid sequence " .. c .. double .. ".")
				end

				out_cons = out_cons .. out_cons
			end

			return out_cons .. v
		end)

	-- Handle gl and gn.
	text = rsub(text, "gn", "ɲ")
	text = rsub(text, "gli(" .. V .. ")", "ʎ%1")
	text = rsub(text, "gli", "ʎi")

	-- Handle other cases of c, g.
	text = rsub(text, "([cg])([cg]?)(h?)(.)", function(first, double, h, after)
		-- Don't allow the combinations cg, gc. Or do something else?
		if double ~= "" and double ~= first then
			error("Invalid sequence " .. first .. double .. ".")
		end

		-- c, g is soft before e, i.
		local cons
		if rfind(front, after) and h ~= "h" then
			if first == "c" then
				cons = "ʧ"
			else
				cons = "ʤ"
			end
		else
			if first == "c" then
				cons = "k"
			else
				cons = "g"
			end
		end

		if double ~= "" then
			cons = cons .. cons
		end

		return cons .. after
	end)

	-- ⟨qu⟩ represents /kw/.
	text = text:gsub("qu", "kw")

	-- u or i (without accent) before another vowel is a glide.
	-- ci, gi + vowel, gli, qu must be dealt with beforehand.
	text = rsub(text, "([iu])(" .. V .. ")", function(glide, v)
		return (glide == "i" and "j" or "w") .. v
	end)

	-- u or i following vowel (with or without accent) is a semivowel. By following the conversion of glides
	-- before vowels, this works correctly in the common sequence 'aiuo' e.g. [[guerraiuola]], [[acquaiuolo]].
	text = rsub(text, "(" .. V .. accent_c .. "?)([iu])", function(v, glide)
		return v .. (glide == "i" and "j" or "w")
	end)

	-- sc before e, i is /ʃ/, doubled after a vowel.
	text = text:gsub("sʧ", "ʃ")

	text = rsub(text, "ddz", "ʣʣ")
	text = rsub(text, "dz", "ʣ")
	text = rsub(text, "tts", "ʦʦ")
	text = rsub(text, "ts", "ʦ")
	if rfind(text, "z") then
		error("z must be respelled (d)dz or (t)ts: " .. origtext)
	end
	text = rsub(text, TEMP1, "z")

	-- Single ⟨s⟩ between vowels is /z/.
	text = rsub(text, "(" .. VW .. stress_c .. "?)s(" .. VW .. ")", "%1z%2")

	-- ⟨s⟩ immediately before a voiced consonant is always /z/
	text = rsub(text, "s(" .. voiced_C_c .. ")", "z%1")

	-- After a vowel, /ʃ ʎ ɲ t͡s d͡z/ are doubled.
	-- [[w:Italian phonology]] says word-internally, [[w:Help:IPA/Italian]] says after a vowel.
	text = rsub(text, "(" .. VW .. ")([ʦʣʃʎɲ])", "%1%2%2")

	-- Divide into syllables.
	-- First remove 'h' and '_', which have served their purpose of preventing context-dependent changes.
	-- They should not interfere with syllabification.
	text = rsub(text, "[h_]", "")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*)(" .. C .. W .. "?" .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. ")(" .. C .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. "+)(" .. C .. C .. V .. ")", "%1.%2")
	text = rsub(text, "([pbktdg])%.([lr])", ".%1%2")
	text = rsub_repeatedly(text, "(" .. C .. ")%.s(" .. C .. ")", "%1s.%2")

	text = rsub(text, "([ʦʣʧʤ])(%.?)([ʦʣʧʤ]*)", function(affricate1, divider, affricate2)
		local full_affricate = full_affricates[affricate1]

		if affricate2 ~= "" then
			return usub(full_affricate, 1, 1) .. divider .. full_affricate
		end

		return full_affricate .. divider
	end)

	text = rsub(text, "g", "ɡ") -- U+0261 LATIN SMALL LETTER SCRIPT G

	-- Stress marks.
	-- Move IPA stress marks to the beginning of the syllable.
	text = rsub_repeatedly(text, "([#.])([^#.]*)(" .. stress_c .. ")", "%1%3%2")
	-- Suppress syllable mark before IPA stress indicator.
	text = rsub(text, "%.(" .. stress_c .. ")", "%1")
	-- Make all primary stresses but the last one in a given word be secondary. May be fed by the first rule above.
	text = rsub_repeatedly(text, "ˈ([^ #]+)ˈ", "ˌ%1ˈ")

	-- Remove # symbols at word/text boundaries and recompose.
	text = rsub(text, "#", "")
	text = mw.ustring.toNFC(text)

	return text
end

-- Incomplete and currently not used by any templates.
function export.to_phonetic(word, voiced_z, pagename)
	local phonetic = export.to_phonemic(word, voiced_z, pagename)

	-- Vowels longer in stressed, open, non-word-final syllables.
	phonetic = rsub(phonetic, "(ˈ" .. NV .. "*" .. V .. ")([" .. vowel .. "%.])", "%1ː%2")

	-- /n/ before /ɡ/ or /k/ is [ŋ]
	phonetic = rsub(phonetic, "n([%.ˈ]?[ɡk])", "ŋ%1") -- WARNING: IPA /ɡ/

	-- Imperfect: doesn't convert geminated k, g properly.
	phonetic = rsub(phonetic, "([kg])(" .. front_c .. ")", "%1" .. FRONTED .. "%2")
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
			pagename = {}, -- for testing
		})

	local pagename = args.pagename or mw.title.getCurrentTitle().text
	local Array = require "Module:array"

	local respellings = args[1]
	if #respellings == 0 then
		respellings = {pagename}
	end
	local transcriptions = Array(respellings):map(function(word, i)
		return { pron = "/" .. export.to_phonemic(word, pagename) .. "/" }
	end)

	return m_IPA.format_IPA_full(lang, transcriptions)
end

return export
