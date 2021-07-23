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
local DIA = u(0x0308) -- diaeresis = ̈
local SYLDIV = u(0xFFF0) -- used to represent a user-specific syllable divider (.) so we won't change it
local TEMP_Z = u(0xFFF1)
local TEMP_S = u(0xFFF2)
local TEMP_H = u(0xFFF3)
local stress = "ˈˌ"
local stress_c = "[" .. stress .. "]"
local quality = AC .. GR
local quality_c = "[" .. quality .. "]"
local accent = stress .. quality .. DOTOVER .. DOTUNDER .. LINEUNDER
local accent_c = "[" .. accent .. "]"
local glide = "jw"
local liquid = "lr"
local W = "[" .. glide .. "]"
local vowel = "aeɛioɔuEOyø"
local V = "[" .. vowel .. "]"
local VW = "[" .. vowel .. "jw]"
local NV = "[^" .. vowel .. "]"
local charsep_not_tie = accent .. "." .. SYLDIV
local charsep_not_tie_c = "[" .. charsep_not_tie .. "]"
local charsep = charsep_not_tie .. "‿⁀"
local charsep_c = "[" .. charsep .. "]"
local wordsep_not_tie = charsep_not_tie .. " #"
local wordsep = charsep .. " #"
local wordsep_c = "[" .. wordsep .. "]"
local C = "[^" .. vowel .. wordsep .. "_]" -- consonant
local C_OR_EOW_NOT_GLIDE_LIQUID = "[^" .. vowel .. charsep .. " _" .. glide .. liquid .. "]" -- consonant not lrjw, or end of word
local C_OR_TIE = "[^" .. vowel .. wordsep_not_tie .. "_]" -- consonant or tie (‿)
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

function export.to_phonemic(text, pagename)
	local abbrev_text
	if rfind(text, "^%^[àéèìóòù]$") then
		if pagename:find("[ %-]") then
			error("With abbreviated vowel spec " .. text .. ", the page name should be a single word: " .. text)
		end
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

	local origwords = rsplit(text, "[ %-]+")

	text = rsub(text, CFLEX, "") -- eliminate circumflex over î, etc.
	text = rsub(text, "y", "i")
	-- French/German vowels
	text = rsub(text, "u" .. DIA, "y")
	text = rsub(text, "o" .. DIA, "ø")
	text = rsub(text, "([^ ])'([^ ])", "%1‿%2") -- apostrophe between letters is a tie
	text = rsub(text, "(" .. C .. ")'$", "%1‿") -- final apostrophe after a consonant is a tie, e.g. [[anch']]
	text = rsub(text, "(" .. C .. ")' ", "%1‿ ") -- final apostrophe in non-utterance-final word is a tie
	text = rsub(text, "'", "") -- other apostrophes just get removed, e.g. [['ndragheta]], [[ca']].
	 -- For now, use a special marker of syntactic gemination at beginning of word; later we will
	 -- convert to ‿ and remove the space.
	text = rsub(text, "%*([ %-])(" .. C .. ")", "%1⁀%2")
	if rfind(text, "%*[ %-]") then
		error("* for syntactic gemination can only be used when the next word begins with a consonant: " .. origtext)
	end
	text = rsub(text, "([" .. DOTUNDER .. LINEUNDER .. "])(" .. quality_c .. ")", "%2%1") -- acute/grave first
	text = rsub(text, "([aiu])" .. AC, "%1" .. GR) -- áíú -> àìù

	local words = require("Module:string utilities").capturing_split(text, "([ %-]+)")
	for i, word in ipairs(words) do
		if (i % 2) == 1 then -- an actual word, not a separator
			local function err(msg)
				error(msg .. ": " .. origwords[(i + 1) / 2])
			end
			local is_prefix =
			    -- utterance-final followed by a hyphen, or
				i == #words - 2 and words[i+1] == "-" and words[i+2] == "" or
			    -- non-utterance-final followed by a hyphen
				i <= #words - 2 and words[i+1] == "- "
			-- First apply abbrev spec e.g. (à) or (ó) if given.
			if abbrev_text then
				local vowel_count = ulen(rsub(word, NV, ""))
				local abbrev_sub = abbrev_text:gsub("%^", "")
				local abbrev_vowel = usub(abbrev_sub, 1, 1)
				if vowel_count == 0 then
					err("Abbreviated spec " .. abbrev_text .. " can't be used with nonsyllabic word")
				elseif vowel_count == 1 then
					local before, vow, after = rmatch(word, "^(.*)(" .. V .. ")(" .. NV .. "*)$")
					if not before then
						error("Internal error: Couldn't match monosyllabic word: " .. word)
					end
					if abbrev_vowel ~= vow then
						err("Abbreviated spec " .. abbrev_text .. " doesn't match vowel " .. ulower(vow))
					end
					word = before .. abbrev_sub .. after
				else
					local before, penultimate, after = rmatch(word,
						"^(.-)(" .. V .. ")(" .. NV .. "*" .. V .. NV .. "*)$")
					if not before then
						error("Internal error: Couldn't match multisyllabic word: " .. word)
					end
					local before2, antepenultimate, after2 = rmatch(before,
						"^(.-)(" .. V .. ")(" .. NV .. "*)$")
					if abbrev_vowel ~= penultimate and abbrev_vowel ~= antepenultimate then
						err("Abbreviated spec ".. abbrev_text .. " doesn't match penultimate vowel " ..
							ulower(penultimate) .. (antepenultimate and " or antepenultimate vowel " ..
								ulower(antepenultimate) or ""))
					end
					if penultimate == antepenultimate then
						err("Can't use abbreviated spec " .. abbrev_text .. " here because penultimate and " ..
							"antepenultimate are the same")
					end
					if abbrev_vowel == antepenultimate then
						word = before2 .. abbrev_sub .. after2 .. penultimate .. after
					elseif abbrev_vowel == penultimate then
						word = before .. abbrev_sub .. after
					else
						error("Internal error: abbrev_vowel from abbrev_text " .. abbrev_text ..
							" didn't match any vowel or glide: " .. origtext)
					end
				end
			end

			if not is_prefix then
				if not rfind(word, quality_c) then
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
				end

				-- Make known unstressed words without stress marks unstressed.
				local bare_word = rsub(word, "⁀", "") -- remove mark of syntactic gemination
				if unstressed_words[bare_word] then
					-- add DOTOVER to the first vowel for cases like [[dei]], [[sui]]
					word = rsub(word, "^(.-" .. V .. accent_c .. "*)", "%1" .. DOTOVER)
				end
			end

			-- Words marked with an acute or grave (quality marker) not followed by an indicator of secondary stress
			-- or non-stress get primary stress.
			word = rsub(word, "(" .. quality_c .. ")([^" .. DOTUNDER .. LINEUNDER .. "])", "%1ˈ%2")
			word = rsub(word, "(" .. quality_c .. ")$", "%1ˈ")
			-- Eliminate quality marker on a/i/u/y/ø, which now serves no purpose.
			word = rsub(word, "([aiuyø])" .. quality_c, "%1")
			-- LINEUNDER means secondary stress.
			word = rsub(word, LINEUNDER, "ˌ")

			-- Make prefixes unstressed. Primary stress markers become secondary.
			if is_prefix then
				word = rsub(word, "ˈ", "ˌ")
				-- add DOTOVER to the first vowel for cases like [[dei]], [[sui]]
				word = rsub(word, "^(.-" .. V .. accent_c .. "*)", "%1" .. DOTOVER)
			end
			words[i] = word
		end
	end
	text = table.concat(words, "")

	-- Convert hyphens to spaces, to handle [[Austria-Hungria]], [[franco-italiano]], etc.
	text = rsub(text, "%-", " ")
	-- canonicalize multiple spaces again, which may have been introduced by hyphens
	text = canon_spaces(text)
	-- put # at word beginning and end and double ## at text/foot boundary beginning/end
	text = rsub(text, " | ", "# | #")
	text = "##" .. rsub(text, " ", "# #") .. "##"

	-- Convert e/o unmarked for quality to E/O, and those marked for quality to e/o/ɛ/ɔ.
	local function convert_e_o(txt)
		return rsub(rsub(txt, "[eo]", {["e"] = "E", ["o"] = "O"}), "[EO]" .. quality_c, {
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
			local vowel_count = ulen(rsub(word, NV, ""))
			if vowel_count > 2 then
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
	text = rsub(text, "a(" .. accent_c .. "*)w", "o%1")

	-- Random substitutions.
	text = rsub(text, "^ex(" .. V .. ")", "eg[z]%1")
	text = text:gsub("x", "ks"):gsub("ck", "k"):gsub("sh", "ʃ")
	text = rsub(text, "%[z%]", TEMP_Z) -- [z] means /z/
	text = rsub(text, "%[s%]", TEMP_S) -- [z] means /s/
	text = rsub(text, "%[h%]", TEMP_H) -- [h] means /h/
	text = rsub(text, "%[tʃ%]", "ʧ")
	text = rsub(text, "%[dʒ%]", "ʤ")

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
	text = rsub(text, "gl(‿?i)", "ʎ%1")

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

	-- ⟨qu⟩ represents /kw/.
	text = text:gsub("qu", "kw")
	-- ⟨gu⟩ (unstressed) + vowel represents /gw/.
	text = text:gsub("gu(" .. V .. ")", "gw%1")
	text = rsub(text, "q", "k") -- [[soqquadro]], [[qatariota]], etc.

	-- Assimilate n before labial, including across word boundaries; DiPI marks pronunciations like
	-- /ʤanˈpaolo/ for [[Gian Paolo]] as wrong. To prevent this, use _ or h between n and following labial.
	text = rsub(text, "n(" .. wordsep_c .. "*[mpb])", "m%1")

	-- Unaccented u or i following vowel (with or without accent) is a semivowel. (But 'iu' should be
	-- interpreted as /ju/ not /iw/.) By preceding the conversion of glides before vowels, this works
	-- correctly in the common sequence 'aiuo' e.g. [[guerraiuola]], [[acquaiuolo]]. Note that
	-- ci, gi + vowel, gli, qu must be dealt with beforehand.
	text = rsub(text, "(" .. V .. accent_c .. "*)([iu])([^" .. accent .. "])", function(v, gl, acc)
		if v == "i" and gl == "u" then
			return v .. gl .. acc
		else
			return v .. (gl == "i" and "j" or "w") .. acc
		end
	end)

	-- Unaccented u or i before another vowel is a glide. Do it repeatedly to handle oriuolo /orjwɔlo/.
	text = rsub_repeatedly(text, "([iu])(" .. V .. ")", function(gl, v)
		return (gl == "i" and "j" or "w") .. v
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

	-- Single ⟨s⟩ between vowels is /z/.
	text = rsub(text, "(" .. VW .. stress_c .. "?" .. charsep_c .. "*)s(" .. charsep_c .. "*" .. VW .. ")", "%1z%2")

	-- ⟨s⟩ immediately before a voiced consonant is always /z/
	text = rsub(text, "s(" .. charsep_c .. "*" .. voiced_C_c .. ")", "z%1")

	text = rsub(text, TEMP_Z, "z")
	text = rsub(text, TEMP_S, "s")

	-- Double consonant followed by end of word (e.g. [[stress]], [[staff]], [[jazz]]), or followed by a consonant
	-- other than a glide or liquid (e.g. [[pullman]]), should be reduced to single. Should not affect double
	-- consonants between vowels or before glides (e.g. [[occhio]], [[acqua]]) or liquids ([[pubblico]], [[febbraio]]),
	-- or words before a tie ([[mezz']], [[tutt']]).
	text = rsub_repeatedly(text, "(" .. C .. ")%1(" .. charsep_not_tie_c .. "*" .. C_OR_EOW_NOT_GLIDE_LIQUID .. ")", "%1%2")

	-- Between vowels (including glides), /ʃ ʎ ɲ t͡s d͡z/ are doubled (unless already doubled).
	-- Not simply after a vowel; 'z' is not doubled in e.g. [[azteco]].
	text = rsub(text, "(" .. VW .. stress_c .. "?" .. charsep_c .. "*)([ʦʣʃʎɲ])(" .. charsep_c .. "*" .. VW .. ")",
		"%1%2%2%3")

	-- Change user-specified . into SYLDIV so we don't shuffle it around when dividing into syllables.
	text = rsub(text, "%.", SYLDIV)

	-- Divide into syllables.
	-- First remove 'h' and '_', which have served their purpose of preventing context-dependent changes.
	-- They should not interfere with syllabification.
	text = rsub(text, "[h_]", "")
	-- Also now convert ⁀ into a copy of the following consonant with the preceding space converted to ⁀
	-- (which we will eventually convert to a tie symbol ‿, but for awhile we need to distinguish the two
	-- because automatic syllabic gemination in final-stress words happens only in multisyllabic words,
	-- and we don't want it to happen in monosyllabic words joined to a previous word by ⁀). We want to do
	-- this after all consonants have been converted to IPA (so the correct consonant is geminated)
	-- but before syllabification, since e.g. 'va* bène' should be treated as a single word 'va⁀b.bɛne' for
	-- syllabification.
	text = rsub(text, "# #⁀(‿?)(.)", "⁀%2%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*[‿⁀]?)(" .. C .. "[‿⁀]?" .. W .. "?[‿⁀]?" .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*[‿⁀]?" .. C .. "[‿⁀]?)(" .. C .. "[‿⁀]?" .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*[‿⁀]?" .. C_OR_TIE .. "+)(" .. C .. "[‿⁀]?" .. C .. "[‿⁀]?" .. V .. ")", "%1.%2")
	text = rsub(text, "([pbktdg][‿⁀]?)%.([lr])", ".%1%2")
	text = rsub(text, "([kg][‿⁀]?)%.w", ".%1w")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*[‿⁀]?)(" .. V .. ")", "%1.%2")

	-- User-specified syllable divider should now be treated like regular one.
	text = rsub(text, SYLDIV, ".")
	text = rsub(text, TEMP_H, "h")

	local last_word_self_gemination = rfind(text, "[ʦʣʃʎɲ]" .. stress_c .."*##$")
	local first_word_self_gemination = rfind(text, "^##" .. stress_c .. "*[ʦʣʃʎɲ]")
	text = rsub(text, "([ʦʣʧʤ])(" .. charsep_c .. "*%.?)([ʦʣʧʤ]*)", function(affricate1, divider, affricate2)
		local full_affricate = full_affricates[affricate1]

		if affricate2 ~= "" then
			return usub(full_affricate, 1, 1) .. divider .. full_affricate
		end

		return full_affricate .. divider
	end)

	text = rsub(text, "g", "ɡ") -- U+0261 LATIN SMALL LETTER SCRIPT G

	local last_word_ends_in_primary_stressed_vowel = rfind(text, "ˈ##$")
	-- Last word is multisyllabic if it has a syllable marker in it. This should not happen across word boundaries
	-- (spaces) including ⁀, marking where two words were joined by syntactic gemination.
	local last_word_is_multisyllabic = rfind(text, "%.[^ ⁀]*$")
	local retval = {
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

	retval.pron = text
	return retval
end

-- For bot usage; {{#invoke:it-pronunciation|to_phonemic_bot|SPELLING}}
function export.to_phonemic_bot(frame)
	local iparams = {
		[1] = {},
	}
	local iargs = require("Module:parameters").process(frame.args, iparams)
	return export.to_phonemic(iargs[1], mw.title.getCurrentTitle().text).pron
end

-- Incomplete and currently not used by any templates.
function export.to_phonetic(word, pagename)
	local phonetic = export.to_phonemic(word, pagename).pron

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
			["qual"] = { list = true, allow_holes = true },
			["n"] = { list = true, allow_holes = true },
			pagename = {}, -- for testing
		})

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

	local pagename = args.pagename or mw.title.getCurrentTitle().text
	local respellings = args[1]
	if #respellings == 0 then
		respellings = {pagename}
	end
	local Array = require "Module:array"

	local transcriptions = Array(respellings):map(function(respelling, i)
		local qualifiers = {args.qual[i]}
		local prespec, postspec = rmatch(respelling, "^([#*°]*)(.-)([*°]*)$")
		if prespec:find("^#") then
			table.insert(qualifiers, 1, "traditional")
			prespec = prespec:gsub("^#", "")
		end
		local phonemic = export.to_phonemic(respelling, pagename)
		local pretext, posttext

		if prespec == "" and phonemic.auto_initial_self_gemination then
			prespec = "*"
		end
		if postspec == "" and (phonemic.auto_cogemination or phonemic.auto_final_self_gemination) then
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
				end
			end
			error("Unrecognized " .. (is_pre and "initial" or "final") .. " symbol " .. spec)
		end

		if prespec ~= "" then
			check_symbol_spec(prespec, initial_symbol_specs, true)
		end
		if postspec ~= "" then
			if phonemic.last_word_ends_in_vowel then
				check_symbol_spec(postspec, final_vowel_symbol_specs, false)
			elseif phonemic.last_word_ends_in_consonant then
				check_symbol_spec(postspec, final_consonant_symbol_specs, false)
			else
				error("Last word ends in neither vowel nor consonant; final symbol " .. spec .. " not allowed here")
			end
		end
		return {
			pron = "/" .. phonemic.pron .. "/",
			qualifiers = #qualifiers > 0 and qualifiers or nil,
			pretext = pretext,
			posttext = posttext,
			notes = args.n[i] and rsplit(args.n[i], "%s*!!!%s*") or nil,
		}
	end)

	return m_IPA.format_IPA_full(lang, transcriptions)
end

return export
