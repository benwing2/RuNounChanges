--[=[
This module implements the templates {{it-pr}} and {{it-IPA}}.

Author: benwing2

FIXME:

1. Support raw pronunciations in {{it-pr}}. (DONE)
2. ahimè should generate aj.mɛ not a.i.mɛ. (DONE)
3. oriuòlo should divide as o.riuò.lo, both in phonemic and hyphenation. (DONE)
4. Handle <hmp:...> for homophones. (DONE)
5. Raw pronunciations need to use raw:, esp. for [...] phonetic pronunciation. (DONE)
6. Handle hyphenation of Uppsala, massmediale correctly. (DONE)
7. Homophone may end up before rhyme/hyphenation when it should come after, e.g. in [[hanno]].
8. Cases like [[Katmandu]] with respelling ''Katmandù'' should auto-hyphenate.
]=]

local export = {}

local force_cat = false -- for testing

local m_table = require("Module:table")
local m_strutil = require("Module:string utilities")

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
local DIA = u(0x0308) -- diaeresis = ̈
local TIE = u(0x0361) -- tie =  ͡
local SYLDIV = u(0xFFF0) -- used to represent a user-specific syllable divider (.) so we won't change it
local WORDDIV = u(0xFFF1) -- used to represent a user-specific word divider (.) so we won't change it
local TEMP_Z = u(0xFFF2)
local TEMP_S = u(0xFFF3)
local TEMP_H = u(0xFFF4)
local TEMP_X = u(0xFFF5)
local stress = "ˈˌ"
local stress_c = "[" .. stress .. "]"
local quality = AC .. GR
local quality_c = "[" .. quality .. "]"
local accent = stress .. quality .. CFLEX .. DOTOVER .. DOTUNDER .. LINEUNDER
local accent_c = "[" .. accent .. "]"
local glide = "jw"
local liquid = "lr"
local tie = "‿⁀'"
local W = "[" .. glide .. "]"
local W_OR_TIE = "[" .. glide .. tie .. "]"
-- We include both phonemic and spelling forms of vowels and both lowercase and uppercase
-- for flexibility in applying at various stages of the transformation from spelling -> phonemes.
local vowel_not_high = "aeɛoɔøöüAEƐOƆØÖÜ"
local vowel_not_i = vowel_not_high .. "uU"
local vowel_not_u = vowel_not_high .. "iyIY"
local vowel = vowel_not_high .. "iuyIUY"
local V = "[" .. vowel .. "]"
local V_NOT_HIGH = "[" .. vowel_not_high .. "]"
local V_NOT_I = "[" .. vowel_not_i .. "]"
local V_NOT_U = "[" .. vowel_not_u .. "]"
local VW = "[" .. vowel .. "jw]"
local NV = "[^" .. vowel .. "]"
local charsep_not_tie = accent .. "." .. SYLDIV
local charsep_not_tie_c = "[" .. charsep_not_tie .. "]"
local charsep = charsep_not_tie .. tie
local charsep_c = "[" .. charsep .. "]"
local wordsep_not_tie = charsep_not_tie .. " #"
local wordsep = charsep .. " #"
local wordsep_c = "[" .. wordsep .. "]"
local cons_guts = "^" .. vowel .. wordsep .. "_" -- guts of consonant class
local C = "[" .. cons_guts .. "]" -- consonant
local C_NOT_SRZ = "[" .. cons_guts .. "srzSRZ]" -- consonant not including srz
local C_NOT_SIBILANT_OR_R = "[" .. cons_guts .. "rszʃʒʦʣʧʤRSZ" .. TEMP_S .. TEMP_Z .. "]" -- consonant not including r or sibilant
local C_NOT_H = "[" .. cons_guts .. "hH]" -- consonant not including h
local C_OR_EOW_NOT_GLIDE_LIQUID = "[^" .. vowel .. charsep .. " _" .. glide .. liquid .. "]" -- consonant not lrjw, or end of word
local C_OR_TIE = "[^" .. vowel .. wordsep_not_tie .. "_]" -- consonant or tie (‿⁀')
local front = "eɛij"
local front_c = "[" .. front .. "]"
local voiced_C_c = "[bdglmnrvʣʤŋʎɲ]"
local pron_sign = "#!*°"
local pron_sign_c = "[" .. pron_sign .. "]"
local pron_sign_or_punc = pron_sign .. "?|,"
local pron_sign_or_punc_c = "[" .. pron_sign_or_punc .. "]"

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
	{"([ai])gli([ao])", "%1" .. GR .. "gli%2"},
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
	{"esc([ao])", "ésc%1"},
	{"evole", "évole"},
	-- FIXME: Systematic exceptions to the following in 3rd plural present tense verb forms
	{"ian([ao])", "iàn%1"},
	{"iv([ao])", "ìv%1"},
	{"oide", "òide"},
	{"oso", "óso"},
}

local unstressed_words = m_table.listToSet {
	"il", "lo", "la", "i", "gli", "le", -- definite articles
	"un", -- indefinite articles
	"mi", "ti", "si", "ci", "vi", "li", -- object pronouns
	"me", "te", "se", "ce", "ve", "ne", -- conjunctive object pronouns
	"e", "ed", "o", "od", -- conjunctions
	"ho", "hai", "ha", -- forms of [[avere]]
	"chi", "che", "non", -- misc particles
	"di", "del", "dei", -- prepositions
	"a", "ad", "al", "ai",
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

-- Apply canonical Unicode decomposition to text, e.g. è → e + ◌̀. But recompose ö and ü so we can treat them as single
-- vowels, and put LINEUNDER/DOTUNDER/DOTOVER after acute/grave (canonical decomposition puts LINEUNDER and DOTUNDER
-- first).
local function decompose(text)
	text = mw.ustring.toNFD(text)
	text = rsub(text, "." .. DIA, {
		["o" .. DIA] = "ö",
		["O" .. DIA] = "Ö",
		["u" .. DIA] = "ü",
		["U" .. DIA] = "Ü",
	})
	text = rsub(text, "([" .. LINEUNDER .. DOTUNDER .. DOTOVER .. "])(" .. quality_c .. ")", "%2%1")
	return text
end

-- Canonicalize multiple spaces and remove leading and trailing spaces.
local function canon_spaces(text)
	text = rsub(text, "%s+", " ")
	text = rsub(text, "^ ", "")
	text = rsub(text, " $", "")
	return text
end

-- Split into words. Hyphens separate words but not when used to denote affixes, i.e. hyphens between non-spaces
-- separate words. Return value includes alternating words and separators. Use table.concat(words) to reconstruct
-- the initial text.
local function split_but_rejoin_affixes(text)
	if not rfind(text, "[%s%-]") then
		return {text}
	end
	-- First replace hyphens separating words with a special character. Remaining hyphens denote affixes and don't
	-- get split. After splitting, replace the special character with a hyphen again.
	local TEMP_HYPH = u(0xFFF0)
	text = rsub_repeatedly(text, "([^%s])%-([^%s])", "%1" .. TEMP_HYPH .. "%2")
	local words = m_strutil.capturing_split(text, "([%s" .. TEMP_HYPH .. "]+)")
	for i, word in ipairs(words) do
		if word == TEMP_HYPH then
			words[i] = "-"
		end
	end
	return words
end

local function remove_secondary_stress(text)
	local words = split_but_rejoin_affixes(text)
	for i, word in ipairs(words) do
		if (i % 2) == 1 then -- an actual word, not a separator
			-- Remove unstressed quality marks.
			word = rsub(word, quality_c .. DOTUNDER, "")
			-- Remove secondary stresses. Specifically:
			-- (1) Remove secondary stresses marked with LINEUNDER if there's a previously stressed vowel.
			-- (2) Otherwise, just remove the LINEUNDER, leaving the accent mark, which will then be removed if there's
			--     a following stressed vowel, but left if it's the only stress in the word, as in có̱lle = con le.
			--     (In the process, we remove other non-stress marks.)
			-- (3) Remove stress mark if there's a following stressed vowel.
			word = rsub_repeatedly(word, "(" .. quality_c .. ".*)" .. quality_c .. LINEUNDER, "%1")
			word = rsub(word, "[" .. CFLEX .. DOTOVER .. DOTUNDER .. LINEUNDER .. "]", "")
			word = rsub_repeatedly(word, quality_c .. "(.*" .. quality_c .. ")", "%1")
			words[i] = word
		end
	end
	return table.concat(words)
end

-- Remove all accents. NOTE: `text` on entry must be decomposed using decompose().
local function remove_accents(text)
	return rsub(text, accent_c, "")
end

-- Remove non-word-final accents. NOTE: `text` on entry must be decomposed using decompose().
local function remove_non_final_accents(text)
	local words = split_but_rejoin_affixes(text)
	for i, word in ipairs(words) do
		if (i % 2) == 1 then -- an actual word, not a separator
			word = rsub_repeatedly(word, accent_c .. "(.)", "%1")
			words[i] = word
		end
	end
	return table.concat(words)
end

-- Remove word-final accents on monosyllabic words. NOTE: `text` on entry must be decomposed using decompose().
local function remove_final_monosyllabic_accents(text)
	local words = split_but_rejoin_affixes(text)
	for i, word in ipairs(words) do
		if (i % 2) == 1 then -- an actual word, not a separator
			word = rsub(word, "^(" .. NV .. "*" .. V .. ")" .. accent_c .. "$", "%1")
			words[i] = word
		end
	end
	return table.concat(words)
end

-- Return true if all words in `term` have vowels. NOTE: `term` on entry must be decomposed using decompose().
local function all_words_have_vowels(term)
	local words = split_but_rejoin_affixes(term)
	for i, word in ipairs(words) do
		if (i % 2) == 1 and not rfind(word, V) then -- an actual word, not a separator; check for a vowel
			return false
		end
	end
	return true
end

-- Given raw respelling, canonicalize it and apply auto-accenting where warranted. This does the following:
-- (1) Convert abbreviated specs like ^à to the appropriate accented page name (hence the page name must be passed in).
-- (2) Decompose the text, normalize áíú and similar to àìù, convert commas and em/en dashes to foot boundaries and
--     similarly with other punctuation.
-- (3) Apply suffix respellings as appropriate, e.g -zione -> -tsióne.
-- (4) Auto-accent monosyllabic and bisyllabic words when possible.
-- (5) Throw an error if non-unstressed words remain without accents on them.
local function canonicalize_and_auto_accent(text, pagename)
	-- First apply abbrev spec e.g. ^à or ^Ó if given.
	if text == "+" then
		text = pagename
	elseif rfind(text, "^%^[àéèìóòùÀÉÈÌÓÒÙ]$") then
		local abbrev_text = decompose(text)
		text = decompose(pagename)
		local function err(msg)
			error(msg .. ": " .. pagename)
		end
		if text:find(" ") or text:find("[^ ]%-[^ ]") then
			err("With abbreviated vowel spec " .. abbrev_text .. ", the page name should be a single word")
		end
		if rfind(text, quality_c) then
			err("With abbreviated vowel spec " .. abbrev_text .. ", the page name should not already have an accent")
		end

		local vowel_count = ulen(rsub(text, NV, ""))
		local abbrev_sub = abbrev_text:gsub("%^", "")
		local abbrev_vowel = usub(abbrev_sub, 1, 1)
		if vowel_count == 0 then
			err("Abbreviated spec " .. abbrev_text .. " can't be used with nonsyllabic word")
		elseif vowel_count == 1 then
			local before, vow, after = rmatch(text, "^(.*)(" .. V .. ")(" .. NV .. "*)$")
			if not before then
				err("Internal error: Couldn't match monosyllabic word: " .. text)
			end
			if abbrev_vowel ~= vow then
				err("Abbreviated spec " .. abbrev_text .. " doesn't match vowel " .. vow)
			end
			text = before .. abbrev_sub .. after
		else
			local before, penultimate, after = rmatch(text, "^(.-)(" .. V .. ")(" .. NV .. "*" .. V .. NV .. "*)$")
			if not before then
				err("Internal error: Couldn't match multisyllabic word: " .. text)
			end
			local before2, antepenultimate, after2 = rmatch(before, "^(.-)(" .. V .. ")(" .. NV .. "*)$")
			if abbrev_vowel ~= penultimate and abbrev_vowel ~= antepenultimate then
				err("Abbreviated spec " .. abbrev_text .. " doesn't match penultimate vowel " ..
					penultimate .. (antepenultimate and " or antepenultimate vowel " ..
						antepenultimate or ""))
			end
			if penultimate == antepenultimate then
				err("Can't use abbreviated spec " .. abbrev_text .. " here because penultimate and " ..
					"antepenultimate are the same")
			end
			if abbrev_vowel == antepenultimate then
				text = before2 .. abbrev_sub .. after2 .. penultimate .. after
			elseif abbrev_vowel == penultimate then
				text = before .. abbrev_sub .. after
			else
				err("Internal error: abbrev_vowel from abbrev_text " .. abbrev_text ..
					" didn't match any vowel or glide")
			end
		end
	end

	text = decompose(text)
	text = rsub(text, "([aiuöüAIUÖÜ])" .. AC, "%1" .. GR) -- áíú -> àìù

	-- convert commas and en/en dashes to IPA foot boundaries
	text = rsub_repeatedly(text, "%s*[,–—]%s*", " | ")
	-- question mark or exclamation point in the middle of a sentence -> IPA foot boundary
	text = rsub_repeatedly(text, "([^%s])%s*[!?]%s*([^%s])", "%1 | %2")
	text = rsub(text, "[!?]", "") -- eliminate remaining punctuation

	text = canon_spaces(text)

	local words = split_but_rejoin_affixes(text)
	for i, word in ipairs(words) do
		if (i % 2) == 1 then -- an actual word, not a separator
			local function err(msg)
				error(msg .. ": " .. words[i])
			end
			local is_prefix = word:find("%-$")
			local is_suffix = word:find("^%-")

			if not is_prefix then
				if not rfind(word, quality_c) then
					-- Apply suffix respellings.
					for _, suffix_pair in ipairs(recognized_suffixes) do
						local orig, respelling = unpack(suffix_pair)
						local replaced
						word, replaced = rsubb(word, orig .. "$", respelling)
						if replaced then
							-- Decompose again because suffix replacements may have accented chars.
							word = decompose(word)
							break
						end
					end
				end

				-- Auto-stress some monosyllabic and bisyllabic words. Don't auto-stress inherently unstressed words
				-- (including those with a * at the end of them indicating syntactic gemination).
				if not unstressed_words[rsub(word, "%*$", "")] and not rfind(word, "[" .. AC .. GR .. DOTOVER .. "]") then
					vowel_count = ulen(rsub(word, NV, ""))
					if vowel_count > 2 then
						err("With more than two vowels and an unrecognized suffix, stress must be explicitly given")
					elseif not is_suffix or vowel_count == 2 then -- don't try to stress suffixes with only one vowel
						local before, vow, after = rmatch(word, "^(.-)(" .. V .. ")(.*)$")
						if before then
							if rfind(vow, "^[eoEO]$") then
								err("When stressed vowel is e or o, it must be marked é/è or ó/ò to indicate quality")
							end
							word = before .. vow .. GR .. after
						end
					end
				end
			end

			words[i] = word
		end
	end

	return words
end


function export.to_phonemic(text, pagename)
	local orig_respelling = text
	local words = canonicalize_and_auto_accent(text, pagename)
	text = table.concat(words)
	local canon_respelling = text

	text = ulower(text)
	text = rsub(text, CFLEX, "") -- eliminate circumflex over î, etc.
	text = rsub(text, "y", "i")
	text = rsub_repeatedly(text, "([^ ])'([^ ])", "%1‿%2") -- apostrophe between letters is a tie
	text = rsub(text, "(" .. C .. ")'$", "%1‿") -- final apostrophe after a consonant is a tie, e.g. [[anch']]
	text = rsub(text, "(" .. C .. ")' ", "%1‿ ") -- final apostrophe in non-utterance-final word is a tie
	text = rsub(text, "'", "") -- other apostrophes just get removed, e.g. [['ndragheta]], [[ca']].
	 -- For now, use a special marker of syntactic gemination at beginning of word; later we will
	 -- convert to ‿ and remove the space.
	text = rsub(text, "%*([ %-])(" .. C .. ")", "%1⁀%2")
	if rfind(text, "%*[ %-]") then
		error("* for syntactic gemination can only be used when the next word begins with a consonant: " .. canon_respelling)
	end

	local words = split_but_rejoin_affixes(text)
	for i, word in ipairs(words) do
		if (i % 2) == 1 then -- an actual word, not a separator
			-- Words marked with an acute or grave (quality marker) not followed by an indicator of secondary stress
			-- or non-stress, and not marked with DOTOVER (unstressed word), get primary stress.
			if not word:find(DOTOVER) then
				word = rsub(word, "(" .. quality_c .. ")([^" .. DOTUNDER .. LINEUNDER .. "])", "%1ˈ%2")
				word = rsub(word, "(" .. quality_c .. ")$", "%1ˈ")
			end
			-- Apply quality markers: è -> ɛ, ò -> ɔ
			word = rsub(word, "[eo]" .. GR, {
				["e" .. GR] = "ɛ",
				["o" .. GR] = "ɔ",
			})
			-- Eliminate quality markers and DOTOVER/DOTUNDER, which have served their purpose.
			word = rsub(word, "[" .. quality .. DOTOVER .. DOTUNDER .. "]", "")

			-- LINEUNDER means secondary stress.
			word = rsub(word, LINEUNDER, "ˌ")

			-- Make prefixes unstressed. Primary stress markers become secondary.
			if word:find("%-$") then
				word = rsub(word, "ˈ", "ˌ")
			end

			words[i] = word
		end
	end
	text = table.concat(words)

	-- Convert hyphens to spaces, to handle [[Austria-Hungria]], [[franco-italiano]], etc.
	text = rsub(text, "%-", " ")
	-- canonicalize multiple spaces again, which may have been introduced by hyphens
	text = canon_spaces(text)
	-- put # at word beginning and end and double ## at text/foot boundary beginning/end
	text = rsub(text, " | ", "# | #")
	text = "##" .. rsub(text, " ", "# #") .. "##"

	-- Random consonant substitutions.
	text = rsub(text, "%[w%]", "w") -- [w] means /w/ when the spelling is ⟨u⟩, esp. in ⟨ui⟩ sequences. This helps with hyphenation.
	text = rsub(text, "%[x%]", TEMP_X) -- [x] means /x/
	text = rsub(text, "#ex(" .. V .. ")", "eg[z]%1")
	text = text:gsub("x", "ks"):gsub("ck", "k"):gsub("sh", "ʃ")
	text = rsub(text, TEMP_X, "x")
	text = rsub(text, "%[z%]", TEMP_Z) -- [z] means /z/
	text = rsub(text, "%[s%]", TEMP_S) -- [z] means /s/
	text = rsub(text, "%[h%]", TEMP_H) -- [h] means /h/

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
	-- The vast majority of words beginning with gli- have /ɡl/ not /ʎ/ so don't substitute here, although we special-case
	-- [[gli]]. Use ʎ exlicitly to get it in [[glielo]] and such.
	text = rsub(text, "#gli#", "ʎi")
	text = rsub_repeatedly(text, "([^#])gli(" .. V .. ")", "%1ʎ%2")
	text = rsub_repeatedly(text, "([^#])gl(‿?i)", "%1ʎ%2")

	-- Handle other cases of c, g.
	text = rsub(text, "([cg])([cg]?)(h?)(" .. charsep_c .. "*.)", function(first, double, h, after)
		-- Don't allow the combinations cg, gc. Or do something else?
		if double ~= "" and double ~= first then
			error("Invalid sequence " .. first .. double .. ".")
		end

		-- c, g is soft before e, i.
		local cons
		if rfind(after, front_c) and not rfind(h, "h") then
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

	-- sc before e, i is /ʃ/, doubled after a vowel.
	text = text:gsub("sʧ", "ʃ")

	text = rsub(text, "%[tʃ%]", "ʧ")
	text = rsub(text, "%[dʒ%]", "ʤ")

	text = rsub(text, "ddz", "ʣʣ")
	text = rsub(text, "dz", "ʣ")
	text = rsub(text, "tts", "ʦʦ")
	text = rsub(text, "ts", "ʦ")
	if rfind(text, "z") then
		error("z must be respelled (d)dz or (t)ts: " .. canon_respelling)
	end

	-- ⟨qu⟩ represents /kw/.
	text = text:gsub("qu", "kw")
	-- ⟨gu⟩ (unstressed) + vowel represents /gw/.
	text = text:gsub("gu(" .. V .. ")", "gw%1")
	text = rsub(text, "q", "k") -- [[soqquadro]], [[qatariota]], etc.

	-- Assimilate n before labial, including across word boundaries; DiPI marks pronunciations like
	-- /ʤanˈpaolo/ for [[Gian Paolo]] as wrong. To prevent this, use _ or h between n and following labial.
	text = rsub(text, "n(" .. wordsep_c .. "*[mpb])", "m%1")

	-- Remove 'h' before converting vowels to glides; h should not block e.g. ahimè -> aj.mɛ.
	text = text:gsub("h", "")

	-- Unaccented u or i following a non-high vowel (with or without accent) is a semivowel. Exclude high vowels because
	-- 'iu' should be interpreted as /ju/ not /iw/, and 'ii' (as in [[sii]]) and ''uu'' (as in [[duumvirato]]), should
	-- remain as vowels. We handle ui specially. By preceding the conversion of glides before vowels, this works
	-- correctly in the common sequence 'aiuo' e.g. [[guerraiuola]], [[acquaiuolo]]. Note that ci, gi + vowel, gli, qu
	-- must be dealt with beforehand.
	text = rsub_repeatedly(text, "(" .. V_NOT_HIGH .. accent_c .. "*)([iu])([^" .. accent .. "])", function(v, gl, acc)
		return v .. (gl == "i" and "j" or "w") .. acc
	end)
	text = rsub_repeatedly(text, "(u" .. accent_c .. "*)i([^" .. accent .. "])", "%1j%2")

	-- Unaccented i or u before another vowel is a glide. Separate into i and u cases to avoid converting ii or uu
	-- except in the sequences iiV or uuV. Do i first so [[oriuolo]] -> or.jwɔ.lo.
	text = rsub(text, "i(" .. V_NOT_I .. ")", "j%1")
	text = rsub(text, "u(" .. V_NOT_U .. ")", "w%1")

	-- Double consonant followed by end of word (e.g. [[stress]], [[staff]], [[jazz]]), or followed by a consonant
	-- other than a glide or liquid (e.g. [[pullman]], [[Uppsala]]), should be reduced to single. Should not affect double
	-- consonants between vowels or before glides (e.g. [[occhio]], [[acqua]]) or liquids ([[pubblico]], [[febbraio]]),
	-- or words before a tie ([[mezz']], [[tutt']]).
	text = rsub_repeatedly(text, "(" .. C .. ")%1(" .. charsep_not_tie_c .. "*" .. C_OR_EOW_NOT_GLIDE_LIQUID .. ")", "%1%2")

	-- Between vowels (including glides), /ʃ ʎ ɲ t͡s d͡z/ are doubled (unless already doubled).
	-- Not simply after a vowel; 'z' is not doubled in e.g. [[azteco]].
	text = rsub_repeatedly(text, "(" .. VW .. stress_c .. "?" .. charsep_c .. "*)([ʦʣʃʎɲ])(" .. charsep_c .. "*" .. VW .. ")",
		"%1%2%2%3")

	-- Change user-specified . into SYLDIV so we don't shuffle it around when dividing into syllables.
	text = rsub(text, "%.", SYLDIV)

	-- Divide into syllables.
	-- First remove '_', which has served its purpose of preventing context-dependent changes.
	-- It should not interfere with syllabification.
	text = text:gsub("_", "")
	-- Also now convert ⁀ into a copy of the following consonant with the preceding space converted to ⁀
	-- (which we will eventually convert to a tie symbol ‿, but for awhile we need to distinguish the two
	-- because automatic syllabic gemination in final-stress words happens only in multisyllabic words,
	-- and we don't want it to happen in monosyllabic words joined to a previous word by ⁀). We want to do
	-- this after all consonants have been converted to IPA (so the correct consonant is geminated)
	-- but before syllabification, since e.g. 'va* bène' should be treated as a single word 'va⁀b.bɛne' for
	-- syllabification.
	text = rsub(text, "# #⁀(‿?)(.)", "⁀%2%2")
	-- Divide before the last consonant (possibly followed by a glide). We then move the syllable division marker
	-- leftwards over clusters that can form onsets.
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*[‿⁀]?" .. C_OR_TIE .. "-)(" .. C .. W_OR_TIE .. "*" .. V .. ")", "%1.%2")
	-- Existing hyphenations of [[atlante]], [[Betlemme]], [[genetliaco]], [[betlemita]] all divide as .tl,
	-- and none divide as t.l. No examples of -dl- but it should be the same per
	-- http://www.italianlanguageguide.com/pronunciation/syllabication.asp.
	text = rsub(text, "([pbfvkgtd][‿⁀]?)%.([lr])", ".%1%2")
	-- Italian appears to divide sCV as .sCV e.g. pé.sca for [[pesca]], and similarly for sCh, sCl, sCr. Exceptions are
	-- ss, sr, sz and possibly others.
	text = rsub(text, "(s[‿⁀]?)%.(" .. C_NOT_SIBILANT_OR_R .. ")", ".%1%2")
	-- Several existing hyphenations divide .pn and .ps and Olivetti agrees. We do this after moving across s so that
	-- dispnea is divided dis.pnea. Olivetti has tec.no.lo.gì.a for [[tecnologia]], showing that cn divides as c.n, and
	-- clàc.son, fuc.sì.na, ric.siò for [[clacson]], [[fucsina]], [[ricsiò]], showing that cs divides as c.s.
	text = rsub(text, "(p[‿⁀]?)%.([ns])", ".%1%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*[‿⁀]?)(" .. V .. ")", "%1.%2")

	-- User-specified syllable divider should now be treated like regular one.
	text = rsub(text, SYLDIV, ".")
	text = rsub(text, TEMP_H, "h")

	-- Do the following after syllabification so we can distinguish written s from z, e.g. u.sbè.co but uz.bè.co per Olivetti.
	-- Single ⟨s⟩ between vowels is /z/.
	text = rsub_repeatedly(text, "(" .. VW .. stress_c .. "?" .. charsep_c .. "*)s(" .. charsep_c .. "*" .. VW .. ")", "%1z%2")
	-- ⟨s⟩ immediately before a voiced consonant is always /z/
	text = rsub(text, "s(" .. charsep_c .. "*" .. voiced_C_c .. ")", "z%1")
	text = rsub(text, TEMP_Z, "z")
	text = rsub(text, TEMP_S, "s")

	-- French/German vowels
	text = rsub(text, "ü", "y")
	text = rsub(text, "ö", "ø")
	text = rsub(text, "g", "ɡ") -- U+0261 LATIN SMALL LETTER SCRIPT G

	local last_word_self_gemination = rfind(text, "[ʦʣʃʎɲ]" .. stress_c .."*##$") and not
		-- In case the user used t͡ʃ explicitly
		rfind(text, "t͡ʃ" .. stress_c .."*##$")
	local first_word_self_gemination = rfind(text, "^##" .. stress_c .. "*[ʦʣʃʎɲ]")
	text = rsub(text, "([ʦʣʧʤ])(" .. charsep_c .. "*%.?)([ʦʣʧʤ]*)", function(affricate1, divider, affricate2)
		local full_affricate = full_affricates[affricate1]

		if affricate2 ~= "" then
			return usub(full_affricate, 1, 1) .. divider .. full_affricate
		end

		return full_affricate .. divider
	end)

	local last_word_ends_in_primary_stressed_vowel = rfind(text, "ˈ##$")
	-- Last word is multisyllabic if it has a syllable marker in it. This should not happen across word boundaries
	-- (spaces) including ⁀, marking where two words were joined by syntactic gemination.
	local last_word_is_multisyllabic = rfind(text, "%.[^ ⁀]*$")
	local retval = {
		orig_respelling = orig_respelling,
		canon_respelling = canon_respelling,
		-- Automatic co-gemination (syntactic gemination of the following consonant in a multisyllabic word ending in
		-- a stressed vowel)
		auto_cogemination = last_word_ends_in_primary_stressed_vowel and last_word_is_multisyllabic,
		-- Last word ends in a vowel (an explicit * indicates co-gemination, i.e. syntactic gemination of the
		-- following consonant)
		last_word_ends_in_vowel = rfind(text, V .. stress_c .. "*" .. "##$"),
		-- Last word ends in a consonant (an explicit * indicates self-gemination of this consonant, i.e. the
		-- consonant doubles before a following vowel)
		last_word_ends_in_consonant = rfind(text, C .. "##$"),
		-- Last word ends in a consonant (ts dz ʃ ʎ ɲ) that triggers self-gemination before a following vowel
		auto_final_self_gemination = last_word_self_gemination,
		-- First word begins in a consonant (ts dz ʃ ʎ ɲ) that triggers self-gemination after a preceding vowel
		auto_initial_self_gemination = first_word_self_gemination,
	}

	-- Now that ⁀ has served its purpose, convert to a regular tie ‿.
	text = rsub(text, "⁀", "‿")

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

	retval.phonemic = text
	return retval
end

-- For bot usage; {{#invoke:it-pronunciation|to_phonemic_bot|SPELLING}}
function export.to_phonemic_bot(frame)
	local iparams = {
		[1] = {},
	}
	local iargs = require("Module:parameters").process(frame.args, iparams)
	return export.to_phonemic(iargs[1], mw.title.getCurrentTitle().text).phonemic
end


--[=[
Entry point to construct the arguments to a call to m_IPA.format_IPA_full() and make a call to this function.
This formats one line of pronunciation, potentially including multiple individual pronunciations (representing
differing pronunciations of the same underlying term), potentialy along with attached qualifiers and/or references.
`data` is a table currently containing two fields, as follows:

{
  terms = {{term = RESPELLING, qual = {QUALIFIER, QUALIFIER, ...}, ref = {REFSPEC, REFSPEC, ...}}, ...},
  pagename = PAGENAME,
}

Here:

* RESPELLING is a pronunciation respelling of the term in question and may contain initial and/or final specs
  indicating the presence, absence and nature of self-gemination and co-gemination along with initial specs
  indicating the register of the pronunciation (traditional, careful style, elevated style).
* QUALIFIER is an arbitrary string to be displayed as a qualifier before the pronunciation in question; multiple
  qualifiers will be comma-separated. `qual` should always be given as a table even if it's empty.
* REFSPEC is a string of the same format as is passed to {{IPA}}; see the documentation of [[Template:IPA]] for more
  info. `ref`, as with `qual`, should always be given as a table even if it's empty.
* PAGENAME is the name of the page, used when an abbreviated spec like '^ò' is given.

The return value is an object with the following structure:

{
  formatted = FORMATTED_IPA_LINE,
  terms = {
	{phonemic = PHONEMIC_PRON,
	 raw = "phonemic" or "phonetic",
	 auto_cogemination = BOOLEAN,
	 last_word_ends_in_vowel = BOOLEAN,
	 last_word_ends_in_consonant = BOOLEAN,
	 auto_final_self_gemination = BOOLEAN,
	 auto_initial_self_gemination = BOOLEAN,
	 orig_respelling = ORIG_RESPELLING,
	 canon_respelling = CANON_RESPELLING,
	 prespec = nil or PRESPEC,
	 pretext = nil or PRETEXT,
	 postspec = nil or POSTSPEC,
	 posttext = nil or POSTTEXT,
	 qualifiers = {QUALIFIER, QUALIFIER, ...},
	 refs = nil or {{text = TEXT, name = nil or NAME, group = nil or GROUP}, ...},
	}, ...
  }
}

Here:

* FORMATTED_IPA_LINE is the output of format_IPA_full(), a string.
* `terms` contains one entry per term in the input object to show_IPA_full().
* PHONEMIC_PRON is the phonemic IPA pronunciation of the respelling passed in, generated by to_phonemic().
* RAW is "phonemic" if the user specified a raw pronunciation using /.../, "phonetic" if using [...]. In such a case,
  PHONEMIC_PRON is the user-specified pronunciation without the surrounding slashes or brackets.
* `last_word_ends_in_vowel` and the other boolean properties are documented in the source code of to_phonemic().
* ORIG_RESPELLING is the respelling for which the phonemic IPA pronunciation was generated. This is the same as was
  passed in to show_IPA_full(), but stripped of initial and final spec symbols such as *, **, °, °°, #, !, !!.
* CANON_RESPELLING is the canonicalized, Unicode-decomposed version of ORIG_RESPELLING, as output by
  canonicalize_and_auto_accent(). This includes expansion of abbreviations such as ^à, suffix application such as
  -zione -> tsióne, and other auto-accenting.
* PRESPEC is a string containing the raw symbol(s) added before the phonemic output, currently one or *, **, ° or °°.
  These may be explicitly specified by the user or added automatically based on the properties in the `phonemic`
  structure described above.
* PRETEXT is the actual text added before the phonemic output, based on the prespec symbols annotated with HTML that
  causes a tooltip to be displayed when the cursor hovers over the symbol.
* POSTSPEC is like PRESPEC but contains the raw symbol(s) added after the phonemic output rather than before.
* POSTTEXT is like PRETEXT but based on POSTSPEC.
* `qualifiers` are the actual qualifiers passed to format_IPA_full() for this term. The qualifiers come from the
  qualifiers passed in the per-term input and/or qualifiers added based on symbols preceding the respelling such as
  #, ! or !!.
* `refs` is either nil or a list of objects describing parsed references, as returned by parse_references() in
  [[Module:references]].
]=]

function export.show_IPA_full(data)
	local final_cogemination = "triggers final cogemination (syntactic gemination of the initial consonant of the following word)"
	local final_non_cogemination = "does not trigger final cogemination (syntactic gemination of the initial consonant of the following word)"
	local final_self_cogemination = "triggers final self-gemination (syntactic gemination of the final consonant before a vowel)"
	local final_non_self_cogemination = "does not trigger final self-gemination (syntactic gemination of the final consonant before a vowel)"
	local initial_self_gemination = "triggers initial self-gemination (syntactic gemination of the initial consonant following a vowel)"
	local initial_non_cogemination = "blocks initial cogemination (syntactic gemination of the initial consonant when it would normally occur, i.e. following a stressed final vowel)"
	local initial_symbol_specs = {
		{"**", "optionally " .. initial_self_gemination},
		{"*", initial_self_gemination},
		{"°°", "optionally " .. initial_non_cogemination},
		{"°", initial_non_cogemination},
	}
	local final_vowel_symbol_specs = {
		{"**", "optionally " .. final_cogemination},
		{"*", final_cogemination},
		{"°", final_non_cogemination},
	}
	local final_consonant_symbol_specs = {
		{"**", "optionally " .. final_self_cogemination},
		{"*", final_self_cogemination},
		{"°", final_non_self_cogemination},
	}

	local retval = {terms = {}}
	local transcriptions = {}
	for _, term in ipairs(data.terms) do
		local respelling = term.term
		local qualifiers = term.qual
		local prespec, actual_respelling, postspec = rmatch(respelling, "^(" .. pron_sign_c .. "*)(.-)([*°]*)$")
		respelling = actual_respelling
		if prespec:find("!!") then
			table.insert(qualifiers, 1, "elevated style")
			prespec = prespec:gsub("!!", "")
		end
		if prespec:find("!") then
			table.insert(qualifiers, 1, "careful style")
			prespec = prespec:gsub("!", "")
		end
		if prespec:find("#") then
			table.insert(qualifiers, 1, "traditional")
			prespec = prespec:gsub("#", "")
		end
		local pron, pretext, posttext

		local raw, raw_type
		raw = rmatch(respelling, "^raw:/(.*)/$")
		if raw then
			raw_type = "phonemic"
		else
			raw = rmatch(respelling, "^raw:%[(.*)%]$")
			if raw then
				raw_type = "phonetic"
			end
		end
		if raw then
			pron = {
				orig_respelling = respelling,
				canon_respelling = decompose(respelling),
				phonemic = raw,
				raw = raw_type,
			}
		else
			pron = export.to_phonemic(respelling, data.pagename)
		end

		if prespec == "" and pron.auto_initial_self_gemination then
			prespec = "*"
		end
		if postspec == "" and (pron.auto_cogemination or pron.auto_final_self_gemination) then
			postspec = "*"
		end

		local function check_symbol_spec(spec, recognized_specs, is_pre)
			for _, symbol_spec in ipairs(recognized_specs) do
				local symbol, text = unpack(symbol_spec)
				if symbol == spec then
					local abbr = '<abbr title="' .. text .. '"><sup>' .. symbol .. "</sup></abbr>"
					if is_pre then
						pretext = abbr
					else
						posttext = abbr
					end
					return
				end
			end
			error("Unrecognized " .. (is_pre and "initial" or "final") .. " symbol " .. spec)
		end

		if prespec ~= "" then
			check_symbol_spec(prespec, initial_symbol_specs, true)
		end
		if postspec ~= "" then
			if pron.last_word_ends_in_vowel then
				check_symbol_spec(postspec, final_vowel_symbol_specs, false)
			elseif pron.last_word_ends_in_consonant then
				check_symbol_spec(postspec, final_consonant_symbol_specs, false)
			else
				error("Last word ends in neither vowel nor consonant; final symbol " .. spec .. " not allowed here")
			end
		end
		local refs
		if #term.ref == 0 then
			refs = nil
		elseif #term.ref == 1 then
			refs = require("Module:references").parse_references(term.ref[1])
		else
			refs = {}
			for _, refspec in ipairs(term.ref) do
				local this_refs = require("Module:references").parse_references(refspec)
				for _, this_ref in ipairs(this_refs) do
					table.insert(refs, this_ref)
				end
			end
		end

		pron.prespec = prespec
		pron.pretext = pretext
		pron.postspec = postspec
		pron.posttext = posttext
		pron.qualifiers = qualifiers
		pron.refs = refs
		table.insert(retval.terms, pron)
		table.insert(transcriptions, {
			pron = pron.raw == "phonetic" and "[" .. pron.phonemic .. "]" or "/" .. pron.phonemic .. "/",
			qualifiers = #qualifiers > 0 and qualifiers or nil,
			pretext = pretext,
			posttext = posttext,
			refs = refs,
		})
	end

	retval.formatted = require("Module:IPA").format_IPA_full(lang, transcriptions)
	return retval
end


-- External entry point for {{it-IPA}}.
function export.show(frame)
	local args = require("Module:parameters").process(
		frame:getParent().args,
		{
			-- terms to transcribe
			[1] = { list = true },
			["qual"] = { list = true, allow_holes = true },
			["ref"] = { list = true, allow_holes = true },
			["pagename"] = {}, -- for testing
		})

	local pagename = args.pagename or mw.title.getCurrentTitle().subpageText
	local respellings = args[1]
	if #respellings == 0 then
		respellings = {pagename}
	end

	local data = {terms = {}, pagename = pagename}

	for i, respelling in ipairs(respellings) do
		table.insert(data.terms, {term = respelling, qual = {args.qual[i]}, ref = {args.ref[i]}})
	end

	local retval_IPA_full = export.show_IPA_full(data)
	return retval_IPA_full.formatted
end


-- Return the number of syllables of a phonemic representation, which should have syllable dividers in it but no
-- hyphens.
local function get_num_syl_from_phonemic(phonemic)
	-- Maybe we should just count vowels instead of the below code.
	phonemic = rsub(phonemic, "|", " ") -- remove IPA foot boundaries
	local words
	if not phonemic:find(" ") then
		words = {phonemic}
	else
		words = m_strutil.capturing_split(phonemic, "( +)")
	end
	for i, word in ipairs(words) do
		if (i % 2) == 1 then -- an actual word, not a separator
			-- IPA stress marks are syllable divisions if between characters; otherwise just remove.
			word = rsub(word, "(.)[ˌˈ](.)", "%1.%2")
			word = rsub(word, "[ˌˈ]", "")
			words[i] = word
		else
			-- Convert spaces and word-separating hyphens into syllable divisions.
			words[i] = "."
		end
	end
	phonemic = table.concat(words)
	return ulen(rsub(phonemic, "[^.]", "")) + 1
end


-- Given the output structure from show_IPA_full, generate a list of rhyme objects. The resulting list can be directly
-- passed in as the `rhymes` field of the data object passed into format_rhymes() in [[Module:rhymes]].
local function generate_rhymes_from_phonemic_output(ipa_full_output, always_rhyme)
	local rhymes = {}
	for _, termobj in ipairs(ipa_full_output.terms) do
		local pronun = termobj.phonemic
		local no_rhyme
		if always_rhyme then
			if termobj.raw == "phonetic" then
				error("Can't generate rhyme for raw phonetic output")
			else
				no_rhyme = false
			end
		else
			local words = split_but_rejoin_affixes(termobj.canon_respelling)
			-- Figure out if we should not generate a rhyme for this term.
			no_rhyme =
				termobj.raw -- raw phonemic or phonetic output given
				or #words > 1 -- more than one word
				or words[1]:find("%-$") -- a prefix
				or words[1]:find("^%-") and ( -- an unstressed suffix:
					-- (1): DOTOVER explicitly indicates unstressed suffix
					words[1]:find(DOTOVER)
					-- (2): DOTUNDER directly after acute or grave indicates unstressed vowel; after discounting
					--      such vowels, we see no stressed words.
					or not rfind(rsub(words[1], quality_c .. DOTUNDER, ""), quality_c)
				)
		end
		if not no_rhyme then
			local rhyme_pronun = rsub(rsub(pronun, ".*[ˌˈ]", ""), "^[^aeiouɛɔ]*", ""):gsub(TIE, ""):gsub("%.", "")
			if rhyme_pronun ~= "" then
				local nsyl = get_num_syl_from_phonemic(pronun)
				local saw_rhyme = false
				for _, rhyme in ipairs(rhymes) do
					if rhyme.rhyme == rhyme_pronun then
						-- already saw rhyme
						local saw_nsyl = false
						for _, this_nsyl in ipairs(rhyme.num_syl) do
							if this_nsyl == nsyl then
								saw_nsyl = true
								break
							end
						end
						if not saw_nsyl then
							table.insert(rhyme.num_syl, nsyl)
						end
						saw_rhyme = true
						break
					end
				end
				if not saw_rhyme then
					-- Only show pronunciation qualifiers with rhymes if there's more than one pronunciation given.
					-- Otherwise the qualifier is just redundant since it's already specified before the pronunciation
					-- and doesn't serve to distinguish rhymes. Also, only set the qualifier for new rhymes; don't
					-- combine qualifiers from different pronunciations with the same rhyme. For example, for
					-- {{it-pr|scandìnavo,#!scandinàvo}} we want to see
					--
					-- Rhymes: -inavo, ''(traditional, careful style)'' -avo
					--
					-- but for {{it-pr|quàlche°,#quàlche*}} we do *NOT* want to see ''(traditional)'' by the rhyme -alke,
					-- which would be incorrect as the same rhyme applies to both pronunciations and only one of the
					-- pronunciations is traditional.
					local quals = #ipa_full_output.terms > 1 and termobj.qualifiers and #termobj.qualifiers > 0 and termobj.qualifiers or nil
					table.insert(rhymes, {rhyme = rhyme_pronun, qualifiers = quals, num_syl = {nsyl}})
				end
			end
		end
	end
	return rhymes
end


-- Syllabify a single word based on its spelling. The text should be decomposed using decompose() and have extraneous
-- characters (e.g. initial or final *) removed.
local function syllabify_word_from_spelling(text)
	-- NOTE: In all of the following, we have to be careful to allow for apostrophes between letters and for capital
	-- letters in the middle of words, as in [[anch'io]], [[all'osso]], [[altr'ieri]], [[cardellino dell'Himalaya]],
	-- [[UEFA]], etc.
	local TEMP_I = u(0xFFF2)
	local TEMP_I_CAPS = u(0xFFF3)
	local TEMP_U = u(0xFFF4)
	local TEMP_U_CAPS = u(0xFFF5)
	local TEMP_Y = u(0xFFF6)
	local TEMP_Y_CAPS = u(0xFFF7)
	local TEMP_G = u(0xFFF8)
	local TEMP_G_CAPS = u(0xFFF9)
	-- Change user-specified . into SYLDIV so we don't shuffle it around when dividing into syllables.
	text = text:gsub("%.", SYLDIV)
	-- We propagate underscore this far specifically so we can distinguish g_n ([[wagneriano]]) from gn.
	-- g_n should end up as g.n but gn should end up as .gn.
	local g_to_temp_g = {["g"] = TEMP_G, ["G"] = TEMP_G_CAPS}
	text = rsub(text, "([gG])('?)_('?[nN])", function (g, sep, n) return g_to_temp_g[g] .. sep .. n end)
	-- Now remove underscores before any further processing.
	text = text:gsub("_", "")
	-- i, u, y between vowels -> consonant-like substitutions:
	-- With i: [[paranoia]], [[febbraio]], [[abbaiare]], [[aiutare]], etc.
	-- With u: [[portauovo]], [[schopenhaueriano]], [[Malaui]], [[oltreuomo]], [[palauano]], [[tauone]], etc.
	-- With y: [[ayatollah]], [[coyote]], [[hathayoga]], [[kayak]], [[uruguayano]], etc. [[kefiyyah]] needs special
	-- handling.
	-- Also with h, as in [[nahuatl]], [[ahia]], etc.
	-- With h not dividing diphthongs: [[ahi]], [[ehi]], [[ahimè]], [[ehilà]], [[ohimè]], [[ohilà]], etc.
	-- But in the common sequence -Ciuo- ([[figliuolo]], [[begliuomini]], [[giuoco]], [[nocciuola]], [[stacciuolo]],
	-- [[oriuolo]], [[guerricciuola]], [[ghiaggiuolo]], etc.), both i and u are glides. In the sequence -quiV-
	-- ([[quieto]], [[reliquia]], etc.), both u and i are glides, and probably also in -guiV-, but not in other -CuiV-
	-- sequences such as [[buio]], [[abbuiamento]], [[gianduia]], [[cuiusso]], [[alleluia]], etc.). Special cases are
	-- French-origin words like [[feuilleton]], [[rousseauiano]], [[gargouille]]; it's unlikely we can handle these
	-- correctly automatically.
	--
	-- We handle these cases as follows:
	-- 1. q+TEMP_U etc. replace sequences of qu and gu with consonant-type codes. This allows us to distinguish
	--    -quiV-/-guiV- from other -CuiV-.
	-- 2. We convert i in -ViV- sequences to consonant-type TEMP_I, but similarly for u in -VuV- sequences only if the
	--    first V isn't i, so -CiuV- remains with two vowels. The syllabification algorithm below will not divide iu
	--    or uV unless in each case the first vowel is stressed, so -CiuV- remains in a single syllable.
	-- 3. As soon as we convert i to TEMP_I, we undo the u -> TEMP_U change for -quiV-/-guiV-, before u -> TEMP_U in
	--    -VuV- sequences.
	local u_to_temp_u = {["u"] = TEMP_U, ["U"] = TEMP_U_CAPS}
	text = rsub(text, "([qQgG])([uU])('?" .. V .. ")", function(qg, u, v) return qg .. u_to_temp_u[u] .. v end)
	local i_to_temp_i = {["i"] = TEMP_I, ["I"] = TEMP_I_CAPS, ["y"] = TEMP_Y, ["Y"] = TEMP_Y_CAPS}
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*[hH]?)([iIyY])(" .. V .. ")",
			function(v1, iy, v2) return v1 .. i_to_temp_i[iy] .. v2 end)
	text = text:gsub(TEMP_U, "u")
	text = text:gsub(TEMP_U_CAPS, "U")
	text = rsub_repeatedly(text, "(" .. V_NOT_I .. accent_c .. "*[hH]?)([uU])(" .. V .. ")",
			function(v1, u, v2) return v1 .. u_to_temp_u[u] .. v2 end)
	-- Divide VCV as V.CV; but don't divide if C == h, e.g. [[ahimè]] should be ahi.mè.
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*'?)(" .. C_NOT_H .. "'?" .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*'?" .. C .. C_OR_TIE .. "*)(" .. C .. "'?" .. V .. ")", "%1.%2")
	-- Examples in Olivetti like [[hathayoga]], [[telethon]], [[cellophane]], [[skyphos]], [[piranha]], [[bilharziosi]]
	-- divide as .Ch. Exceptions are [[wahhabismo]], [[amharico]], [[kinderheim]], [[schopenhaueriano]] but the latter
	-- three seem questionable as the pronunciation puts the first consonant in the following syllable and makes the h
	-- silent.
	text = rsub(text, "(" .. C_NOT_H .. "'?)%.([hH])", ".%1%2")
	-- gn represents a single sound so it should not be divided.
	text = rsub(text, "([gG])%.([nN])", ".%1%2")
	-- Existing hyphenations of [[atlante]], [[Betlemme]], [[genetliaco]], [[betlemita]] all divide as .tl,
	-- and none divide as t.l. No examples of -dl- but it should be the same per
	-- http://www.italianlanguageguide.com/pronunciation/syllabication.asp.
	text = rsub(text, "([pbfvkcgqtdPBFVKCGQTD]'?)%.([lrLR])", ".%1%2")
	-- Italian appears to divide sCV as .sCV e.g. pé.sca for [[pesca]], and similarly for sCh, sCl, sCr. Exceptions are
	-- ss, sr, sz and possibly others. We are careful not to move across s in [[massmediale]], [[password]], etc.
	text = rsub(text, "([^sS])([sS]'?)%.(" .. C_NOT_SRZ .. ")", "%1.%2%3")
	-- Several existing hyphenations divide .pn and .ps and Olivetti agrees. We do this after moving across s so that
	-- dispnea is divided dis.pnea. We are careful not to move across p in [[Uppsala]]. Olivetti has tec.no.lo.gì.a for
	-- [[tecnologia]], showing that cn divides as c.n, and clàc.son, fuc.sì.na, ric.siò for [[clacson]], [[fucsina]],
	-- [[ricsiò]], showing that cs divides as c.s.
	text = rsub(text, "([^pP])([pP]'?)%.([nsNS])", "%1.%2%3")
	-- Any aeoö, or stressed iuüy, should be syllabically divided from a following aeoö or stressed iuüy.
	-- A stressed vowel might be followed by another accent such as LINEUNDER (which we put after the acute/grave in
	-- decompose()).
	text = rsub_repeatedly(text, "([aeoöAEOÖ]" .. accent_c .. "*'?)([hH]?'?[aeoöAEOÖ])", "%1.%2")
	text = rsub_repeatedly(text, "([aeoöAEOÖ]" .. accent_c .. "*'?)([hH]?'?" .. V .. quality_c .. ")", "%1.%2")
	text = rsub(text, "([iuüyIUÜY]" .. quality_c .. accent_c .. "*'?)([hH]?'?[aeoöAEOÖ])", "%1.%2")
	text = rsub_repeatedly(text, "([iuüyIUÜY]" .. quality_c .. accent_c .. "*'?)([hH]?'?" .. V .. quality_c .. ")", "%1.%2")
	-- We divide ii as i.i ([[sii]]), but not iy or yi, which should hopefully cause [[kefiyyah]] to be handled
	-- correctly as ke.fiy.yah. Only example with Cyi is [[dandyismo]], which may be exceptional.
	text = rsub_repeatedly(text, "([iI]" .. accent_c .. "*'?)([hH]?'?[iI])", "%1.%2")
	text = rsub_repeatedly(text, "([uüUÜ]" .. accent_c .. "*'?)([hH]?'?[uüUÜ])", "%1.%2")
	text = text:gsub(SYLDIV, ".")
	text = text:gsub(TEMP_I, "i")
	text = text:gsub(TEMP_I_CAPS, "I")
	text = text:gsub(TEMP_U, "u")
	text = text:gsub(TEMP_U_CAPS, "U")
	text = text:gsub(TEMP_Y, "y")
	text = text:gsub(TEMP_Y_CAPS, "Y")
	text = text:gsub(TEMP_G, "g")
	text = text:gsub(TEMP_G_CAPS, "G")
	return text
end


-- Syllabify text based on its spelling. The text should be decomposed using decompose() and have extraneous
-- characters (e.g. initial *) removed.
local function syllabify_from_spelling(text)
	-- Convert spaces and word-separating hyphens into syllable divisions.
	local words = split_but_rejoin_affixes(text)
	for i, word in ipairs(words) do
		if (i % 2) == 0 then -- a separator
			words[i] = WORDDIV
		else
			words[i] = syllabify_word_from_spelling(word)
		end
	end
	text = table.concat(words)

	-- Convert word divisions into periods, but first into spaces so we can call remove_secondary_stress().
	-- We have to call remove_secondary_stress() after syllabification so we correctly syllabify words like
	-- bìobibliografìa.
	text = text:gsub(WORDDIV, " ")
	text = remove_secondary_stress(text)
	text = text:gsub(" ", ".")
	return text
end


-- Given the canon_respelling field in the structure output by show_IPA_full(), normalize it into the form that can
-- (a) be passed to syllabify_from_spelling() to produce the syllabification that is used to generate hyphenation
-- output, (b) be further processed to determine whether to generate hyphenation at all (by comparing the
-- further-processed result to the original pagename). NOTE: canon_respelling must be decomposed using decompose().
local function normalize_for_syllabification(respelling)
	-- Remove IPA foot boundaries.
	respelling = respelling:gsub("|", " ")
	respelling = canon_spaces(respelling)
	-- Convert respelling conventions back to the original spelling.
	respelling = respelling:gsub("ddz", "zz"):gsub("tts", "zz"):gsub("dz", "z"):gsub("ts", "z")
		:gsub("Dz", "Z"):gsub("Ts", "Z"):gsub("%[([szh])%]", "%1"):gsub("%[w%]", "u")
		:gsub("ʎi", "gli"):gsub("ʎ", "gli")
	return respelling
end


-- Given the output of normalize_for_syllabification() (which should be decomposed using decompose()), see if it
-- matches the page name. If so, we auto-generate hyphenation output based on the respelling.
local function spelling_normalized_for_syllabification_matches_pagename(text, pagename)
	pagename = decompose(pagename)
	text = remove_secondary_stress(text)
	text = text:gsub("_", "")
	if text == pagename then
		return true
	end
	text = text:gsub("%.", "")
	if text == pagename then -- e.g. [[Abraàm]], [[piùe]] with non-final accent in the page name
		return true
	end
	text = remove_non_final_accents(text)
	-- Check if the normalized pronunciation is the same as the page name. If a word in the page name is a single
	-- syllable, it may or may not have an accent on it, so also remove final monosyllabic accents from the normalized
	-- pronunciation when comparing. (Don't remove from both normalized pronunciation and page name because we don't
	-- want pronunciation rè to match page name ré or vice versa.)
	return text == pagename or remove_final_monosyllabic_accents(text) == pagename
end


-- Given the output structure from show_IPA_full, generate a list of hyphenation objects. The resulting list can be
-- directly passed in as the `hyphs` field of the data object passed into format_hyphenation() in
-- [[Module:hyphenation]].
local function generate_hyphenation_from_phonemic_output(ipa_full_output, pagename)
	local hyphs = {}
	for _, termobj in ipairs(ipa_full_output.terms) do
		local normtext
		-- Figure out if we should not generate a hyphenation for this term.
		local no_hyph
		if termobj.raw then
			no_hyph = true
		else
			normtext = normalize_for_syllabification(termobj.canon_respelling)
			no_hyph = not all_words_have_vowels(normtext)
				or not spelling_normalized_for_syllabification_matches_pagename(normtext, pagename)
		end
		if not no_hyph then
			local syllabification = syllabify_from_spelling(normtext)
			local saw_hyph = false
			for _, hyph in ipairs(hyphs) do
				if hyph.syllabification == syllabification then
					-- already saw hyphenation
					saw_hyph = true
					break
				end
			end
			if not saw_hyph then
				-- Only show pronunciation qualifiers with hyphenations if there's more than one pronunciation given,
				-- and only set the qualifier for new hyphenations. See generate_rhymes_from_phonemic_output().
				local quals = #ipa_full_output.terms > 1 and termobj.qualifiers and #termobj.qualifiers > 0 and termobj.qualifiers or nil
				table.insert(hyphs, {syllabification = syllabification, hyph = rsplit(syllabification, "%."),
					qualifiers = quals})
			end
		end
	end
	return hyphs
end


local function parse_rhyme(arg, iut, parse_err)
	if not iut then
		iut = require("Module:inflection utilities")
	end
	local retval = {}
	local rhyme_segments = iut.parse_balanced_segment_run(arg, "<", ">")
	local comma_separated_groups = iut.split_alternating_runs(rhyme_segments, "%s*,%s*")
	for _, group in ipairs(comma_separated_groups) do
		local rhyme_obj = {rhyme = group[1]}
		for j = 2, #group - 1, 2 do
			if group[j + 1] ~= "" then
				parse_err("Extraneous text '" .. group[j + 1] .. "' after modifier")
			end
			local modtext = group[j]:match("^<(.*)>$")
			if not modtext then
				parse_err("Internal error: Rhyme modifier '" .. group[j] .. "' isn't surrounded by angle brackets")
			end
			local prefix, arg = modtext:match("^([a-z]+):(.*)$")
			if not prefix then
				parse_err("Modifier " .. group[j] .. " lacks a prefix, should begin with one of 's:' or 'qual:'")
			end
			if prefix == "s" then
				local nsyls = rsplit(arg, "%s*,%s*")
				for _, nsyl in ipairs(nsyls) do
					if not nsyl:find("^[0-9]+$") then
						parse_err("Number of syllables '" .. nsyl .. "' in rhyme " ..
							table.concat(group) .. " should be numeric")
					end
					if not rhyme_obj.num_syl then
						rhyme_obj.num_syl = {}
					end
					table.insert(rhyme_obj.num_syl, tonumber(nsyl))
				end
			elseif prefix == "qual" then
				if not rhyme_obj.qualifiers then
					rhyme_obj.qualifiers = {}
				end
				table.insert(rhyme_obj.qualifiers, arg)
			else
				parse_err("Unrecognized prefix '" .. prefix .. "' in modifier " .. group[j]
					.. ", should be 's' or 'qual'")
			end
		end
		table.insert(retval, rhyme_obj)
	end

	return retval
end


local function parse_hyph(arg, iut, parse_err)
	if not iut then
		iut = require("Module:inflection utilities")
	end
	local retval = {}
	local hyph_segments = iut.parse_balanced_segment_run(arg, "<", ">")
	local comma_separated_groups = iut.split_alternating_runs(hyph_segments, "%s*,%s*")
	for _, group in ipairs(comma_separated_groups) do
		local hyph_obj = {syllabification = group[1], hyph = rsplit(group[1], "%.")}
		for j = 2, #group - 1, 2 do
			if group[j + 1] ~= "" then
				parse_err("Extraneous text '" .. group[j + 1] .. "' after modifier")
			end
			local modtext = group[j]:match("^<(.*)>$")
			if not modtext then
				parse_err("Internal error: Modifier '" .. group[j] .. "' isn't surrounded by angle brackets")
			end
			local prefix, arg = modtext:match("^([a-z]+):(.*)$")
			if not prefix then
				parse_err("Modifier " .. group[j] .. " lacks a prefix, should begin with 'qual:'")
			end
			if prefix == "qual" then
				if not hyph_obj.qualifiers then
					hyph_obj.qualifiers = {}
				end
				table.insert(hyph_obj.qualifiers, arg)
			else
				parse_err("Unrecognized prefix '" .. prefix .. "' in modifier " .. group[j] .. ", should be 'qual'")
			end
		end
		table.insert(retval, hyph_obj)
	end

	return retval
end


local function parse_homophone(arg, iut, parse_err)
	if not iut then
		iut = require("Module:inflection utilities")
	end
	local retval = {}
	local hmp_segments = iut.parse_balanced_segment_run(arg, "<", ">")
	local comma_separated_groups = iut.split_alternating_runs(hmp_segments, "%s*,%s*")
	for _, group in ipairs(comma_separated_groups) do
		local hmp_obj = {term = group[1]}
		for j = 2, #group - 1, 2 do
			if group[j + 1] ~= "" then
				parse_err("Extraneous text '" .. group[j + 1] .. "' after modifier")
			end
			local modtext = group[j]:match("^<(.*)>$")
			if not modtext then
				parse_err("Internal error: Modifier '" .. group[j] .. "' isn't surrounded by angle brackets")
			end
			local prefix, arg = modtext:match("^([a-z]+):(.*)$")
			if not prefix then
				parse_err("Modifier " .. group[j] .. " lacks a prefix, should begin with one of 'qual:', 't:', 'alt:' or 'pos:'")
			end
			if prefix == "qual" then
				if not hmp_obj.qualifiers then
					hmp_obj.qualifiers = {}
				end
				table.insert(hmp_obj.qualifiers, arg)
			elseif prefix == "t" or prefix == "alt" or prefix == "pos" then
				local key = prefix == "t" and "gloss" or prefix
				if hmp_obj[key] then
					parse_err("Modifier '" .. prefix .. "' specified more than once")
				end
				hmp_obj[key] = arg
			else
				parse_err("Unrecognized prefix '" .. prefix .. "' in modifier " .. group[j]
					.. ", should be 'qual', 't', 'alt' or 'pos'")
			end
		end
		table.insert(retval, hmp_obj)
	end

	return retval
end


-- External entry point for {{it-pr}}.
function export.show_pr(frame)
	local params = {
		[1] = {list = true},
		["pagename"] = {}, -- for testing
	}
	local parargs = frame:getParent().args
	local args = require("Module:parameters").process(parargs, params)
	local pagename = args.pagename or mw.title.getCurrentTitle().subpageText

	-- Parse the arguments.
	local respellings = #args[1] > 0 and args[1] or {"+"}
	local parsed_respellings = {}
	local iut
	for i, respelling in ipairs(respellings) do
		if respelling:find("<") then
			local function parse_err(msg)
				error(msg .. ": " .. i .. "= " .. respelling)
			end
			if not iut then
				iut = require("Module:inflection utilities")
			end
			local segments = iut.parse_balanced_segment_run(respelling, "<", ">")
			local comma_separated_groups = iut.split_alternating_runs(segments, "%s*,%s*")
			local parsed = {terms = {}, audio = {}}
			for i, group in ipairs(comma_separated_groups) do
				local term = {term = group[1], ref = {}, qual = {}}
				for j = 2, #group - 1, 2 do
					if group[j + 1] ~= "" then
						parse_err("Extraneous text '" .. group[j + 1] .. "' after modifier")
					end
					local modtext = group[j]:match("^<(.*)>$")
					if not modtext then
						parse_err("Internal error: Modifier '" .. group[j] .. "' isn't surrounded by angle brackets")
					end
					local prefix, arg = modtext:match("^([a-z]+):(.*)$")
					if not prefix then
						parse_err("Modifier " .. group[j] .. " lacks a prefix, should begin with one of " ..
							"'pre:', 'post:', 'ref:', 'bullets:', 'audio:', 'rhyme:', 'hyph:', 'hmp:' or 'qual:'")
					end
					if prefix == "ref" or prefix == "qual" then
						table.insert(term[prefix], arg)
					elseif prefix == "pre" or prefix == "post" or prefix == "bullets" or prefix == "rhyme"
						or prefix == "hyph" or prefix == "hmp" or prefix == "audio" then
						if i < #comma_separated_groups then
							parse_err("Modifier '" .. prefix .. "' should occur after the last comma-separated term")
						end
						if prefix == "rhyme" then
							local parsed_rhymes = parse_rhyme(arg, iut, parse_err)
							if not parsed.rhyme then
								parsed.rhyme = parsed_rhymes
							else
								for _, parsed_rhyme in ipairs(parsed_rhymes) do
									table.insert(parsed.rhyme, parsed_rhyme)
								end
							end
						elseif prefix == "hyph" then
							local parsed_hyphs = parse_hyph(arg, iut, parse_err)
							if not parsed.hyph then
								parsed.hyph = parsed_hyphs
							else
								for _, parsed_hyph in ipairs(parsed_hyphs) do
									table.insert(parsed.hyph, parsed_hyph)
								end
							end
						elseif prefix == "hmp" then
							local parsed_homophones = parse_homophone(arg, iut, parse_err)
							if not parsed.hmp then
								parsed.hmp = parsed_homophones
							else
								for _, parsed_homophone in ipairs(parsed_homophones) do
									table.insert(parsed.hmp, parsed_homophone)
								end
							end
						elseif prefix == "audio" then
							local file, gloss = arg:match("^(.-)%s*;%s*(.*)$")
							if not file then
								file = arg
								gloss = "Audio"
							end
							table.insert(parsed.audio, {file = file, gloss = gloss})
						else
							if parsed[prefix] then
								parse_err("Modifier '" .. prefix .. "' occurs twice, second occurrence " .. group[j])
							end
							if prefix == "bullets" then
								if not arg:find("^[0-9]+$") then
									parse_err("Modifier 'bullets' should have a number as argument")
								end
								parsed.bullets = tonumber(arg)
							else
								parsed[prefix] = arg
							end
						end
					else
						parse_err("Unrecognized prefix '" .. prefix .. "' in modifier " .. group[j]
							.. ", should be one of 'pre', 'post', 'ref', 'bullets', 'audio', 'rhyme', 'hyph', 'hmp'"
							.. " or 'qual'")
					end
				end
				table.insert(parsed.terms, term)
			end
			if not parsed.bullets then
				parsed.bullets = 1
			end
			table.insert(parsed_respellings, parsed)
		else
			local terms = {}
			for _, term in ipairs(rsplit(respelling, "%s*,%s*")) do
				table.insert(terms, {term = term, ref = {}, qual = {}})
			end
			table.insert(parsed_respellings, {
				terms = terms,
				audio = {},
				bullets = 1,
			})
		end
	end

	-- Loop over individual respellings, processing each.
	for _, parsed in ipairs(parsed_respellings) do
		-- Generate the phonemic pronunciation.
		parsed.ipa_full = export.show_IPA_full {terms = parsed.terms, pagename = pagename}

		-- Generate the rhymes.
		local rhymes = {}
		if not parsed.rhyme or #parsed.rhyme == 0 then
			rhymes = generate_rhymes_from_phonemic_output(parsed.ipa_full)
		else
			for _, rhyme in ipairs(parsed.rhyme) do
				if rhyme.rhyme == "-" then
					rhymes = {}
					break
				elseif rhyme.rhyme == "+" then
					local auto_rhymes = generate_rhymes_from_phonemic_output(parsed.ipa_full, "always rhyme")
					for _, auto_rhyme in ipairs(auto_rhymes) do
						table.insert(rhymes, auto_rhyme)
					end
				else
					-- If user specified the rhyme explicitly but not the number of syllables, get this from the
					-- phonemic representation of the terms.
					if not rhyme.num_syl then
						rhyme.num_syl = {}
						for _, term in ipairs(parsed.ipa_full.terms) do
							local nsyl = get_num_syl_from_phonemic(term.phonemic)
							m_table.insertIfNot(rhyme.num_syl, nsyl)
						end
					end
					table.insert(rhymes, rhyme)
				end
			end
		end
		parsed.rhyme = rhymes

		-- Generate the hyphenations.
		local hyphs = {}
		if not parsed.hyph or #parsed.hyph == 0 then
			hyphs = generate_hyphenation_from_phonemic_output(parsed.ipa_full, pagename)
		else
			for _, hyph in ipairs(parsed.hyph) do
				if hyph.syllabification == "-" then
					hyphs = {}
					break
				else
					m_table.insertIfNot(hyphs, hyph)
				end
			end
		end
		parsed.hyph = hyphs

		-- Generate the homophones.
		parsed.hmp = parsed.hmp or {}
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

	local function format_phonemic(parsed)
		local pre = parsed.pre and parsed.pre .. " " or ""
		local post = parsed.post and " " .. parsed.post or ""
		return string.rep("*", parsed.bullets) .. pre .. parsed.ipa_full.formatted .. post
	end

	local function format_rhymes(rhymes, num_bullets)
		local rhymetext = require("Module:rhymes").format_rhymes { lang = lang, rhymes = rhymes, force_cat = force_cat }
		return string.rep("*", num_bullets) .. " " .. rhymetext
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
				title = "audio", args = {"it", audio.file, audio.gloss }})
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
		table.insert(textparts, format_phonemic(parsed))
		if #parsed.audio > 0 then
			table.insert(textparts, "\n")
			-- If only one pronunciation set, add the audio with the same number of bullets, otherwise
			-- indent audio by one more bullet.
			table.insert(textparts, format_audio(parsed.audio,
				#parsed_respellings == 1 and parsed.bullets or parsed.bullets + 1))
		end
		if not all_rhyme_sets_eq and #parsed.rhyme > 0 then
			table.insert(textparts, "\n")
			table.insert(textparts, format_rhymes(parsed.rhyme, parsed.bullets + 1))
		end
		if not all_hyph_sets_eq and #parsed.hyph > 0 then
			table.insert(textparts, "\n")
			table.insert(textparts, format_hyphenations(parsed.hyph, parsed.bullets + 1))
		end
		if #parsed.hmp > 0 then
			table.insert(textparts, "\n")
			-- If only one pronunciation set, add the homophones with the same number of bullets, otherwise
			-- indent homophones by one more bullet.
			table.insert(textparts, format_homophones(parsed.hmp,
				#parsed_respellings == 1 and parsed.bullets or parsed.bullets + 1))
		end
	end
	if all_rhyme_sets_eq and #first_rhyme_ret > 0 then
		table.insert(textparts, "\n")
		table.insert(textparts, format_rhymes(first_rhyme_ret, min_num_bullets))
	end
	if all_hyph_sets_eq and #first_hyphs > 0 then
		table.insert(textparts, "\n")
		table.insert(textparts, format_hyphenations(first_hyphs, min_num_bullets))
	end

	return table.concat(textparts)
end


return export
