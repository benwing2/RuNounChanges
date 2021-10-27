local export = {}

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
local TEMP_Z = u(0xFFF1)
local TEMP_S = u(0xFFF2)
local TEMP_H = u(0xFFF3)
local TEMP_X = u(0xFFF4)
local stress = "ˈˌ"
local stress_c = "[" .. stress .. "]"
local quality = AC .. GR
local quality_c = "[" .. quality .. "]"
local accent = stress .. quality .. CFLEX .. DOTOVER .. DOTUNDER .. LINEUNDER
local accent_c = "[" .. accent .. "]"
local glide = "jw"
local liquid = "lr"
local W = "[" .. glide .. "]"
-- We include both phonemic and spelling forms of vowels and both lowercase and uppercase
-- because we use some code e.g. expand_abbrevs_handle_recognized_suffixes() for both the
-- phonemic and spelling forms of words.
local vowel = "aeɛioɔuyøöüAEƐIOƆUYØÖÜ"
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

-- Apply canonical Unicode decomposition to text but recompose ö and ü so we can treat them as single vowels,
-- and put LINEUNDER/DOTUNDER/DOTOVER after acute/grave (canonical decomposition puts LINEUNDER and DOTUNDER first). 
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

-- canonicalize multiple spaces and remove leading and trailing spaces
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

-- Remove secondary stress on words with primary stress. If the word has only secondary stress, convert it to
-- primary stress.
local function remove_secondary_stress(text)
	local words = split_but_rejoin_affixes(text)
	for i, word in ipairs(words) do
		if (i % 2) == 1 then -- an actual word, not a separator
			-- Remove secondary stresses marked with LINEUNDER if there's a previously stressed vowel. Otherwise, just
			-- remove the LINEUNDER, leaving the accent mark, which will be removed below if there's a following stressed
			-- vowel.
			word = rsub_repeatedly(word, "(" .. quality_c .. ".*)" .. quality_c .. LINEUNDER, "%1")
			word = word:gsub(LINEUNDER, "")
			word = rsub_repeatedly(word, quality_c .. "(.*" .. quality_c .. ")", "%1")
			words[i] = word
		end
	end
	return table.concat(words)
end

-- Remove all accents.
local function remove_accents(text)
	return rsub(text, accent_c, "")
end

-- Remove non-word-final accents.
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

-- Remove word-final accents on monosyllabic words.
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

local function all_words_have_vowels(term)
	local words = split_but_rejoin_affixes(term)
	for i, word in ipairs(words) do
		if (i % 2) == 1 and not rfind(word, V) then -- an actual word, not a separator; check for a vowel
			return false
		end
	end
	return true
end

local function expand_abbrevs_handle_recognized_suffixes(text, abbrev_text, origwords, for_pronun)
	local words = m_strutil.capturing_split(text, "([ %-]+)")
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
						err("Internal error: Couldn't match monosyllabic word: " .. word)
					end
					if abbrev_vowel ~= vow then
						err("Abbreviated spec " .. abbrev_text .. " doesn't match vowel " .. ulower(vow))
					end
					word = before .. abbrev_sub .. after
				else
					local before, penultimate, after = rmatch(word,
						"^(.-)(" .. V .. ")(" .. NV .. "*" .. V .. NV .. "*)$")
					if not before then
						err("Internal error: Couldn't match multisyllabic word: " .. word)
					end
					local before2, antepenultimate, after2 = rmatch(before,
						"^(.-)(" .. V .. ")(" .. NV .. "*)$")
					if abbrev_vowel ~= penultimate and abbrev_vowel ~= antepenultimate then
						err("Abbreviated spec " .. abbrev_text .. " doesn't match penultimate vowel " ..
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
						err("Internal error: abbrev_vowel from abbrev_text " .. abbrev_text ..
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
							word = decompose(word)
							break
						end
					end
				end

				if for_pronun then
					-- Make known unstressed words without stress marks unstressed.
					local bare_word = rsub(word, "⁀", "") -- remove mark of syntactic gemination
					if unstressed_words[bare_word] then
						-- add DOTOVER to the first vowel for cases like [[dei]], [[sui]]
						word = rsub(word, "^(.-" .. V .. accent_c .. "*)", "%1" .. DOTOVER)
					end
				end
			end

			if for_pronun then
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
			end

			words[i] = word
		end
	end

	return words
end


function export.to_phonemic(text, pagename)
	local abbrev_text
	if rfind(text, "^%^[àéèìóòù]$") then
		if pagename:find("[ %-]") then
			error("With abbreviated vowel spec " .. text .. ", the page name should be a single word: " .. pagename)
		end
		abbrev_text = decompose(text)
		text = pagename
	end
	local origtext = text
	text = ulower(text)

	-- Decompose combining characters: for instance, è → e + ◌̀
	text = decompose(text)

	-- convert commas and en/en dashes to IPA foot boundaries
	text = rsub_repeatedly(text, "%s*[,–—]%s*", " | ")
	-- question mark or exclamation point in the middle of a sentence -> IPA foot boundary
	text = rsub_repeatedly(text, "([^%s])%s*[!?]%s*([^%s])", "%1 | %2")
	text = rsub(text, "[!?]", "") -- eliminate remaining punctuation

	text = canon_spaces(text)

	local origwords = rsplit(text, "[ %-]+")

	text = rsub(text, CFLEX, "") -- eliminate circumflex over î, etc.
	text = rsub(text, "y", "i")
	-- French/German vowels
	text = rsub(text, "ü", "y")
	text = rsub(text, "ö", "ø")
	text = rsub_repeatedly(text, "([^ ])'([^ ])", "%1‿%2") -- apostrophe between letters is a tie
	text = rsub(text, "(" .. C .. ")'$", "%1‿") -- final apostrophe after a consonant is a tie, e.g. [[anch']]
	text = rsub(text, "(" .. C .. ")' ", "%1‿ ") -- final apostrophe in non-utterance-final word is a tie
	text = rsub(text, "'", "") -- other apostrophes just get removed, e.g. [['ndragheta]], [[ca']].
	 -- For now, use a special marker of syntactic gemination at beginning of word; later we will
	 -- convert to ‿ and remove the space.
	text = rsub(text, "%*([ %-])(" .. C .. ")", "%1⁀%2")
	if rfind(text, "%*[ %-]") then
		error("* for syntactic gemination can only be used when the next word begins with a consonant: " .. origtext)
	end
	text = rsub(text, "([aiu])" .. AC, "%1" .. GR) -- áíú -> àìù

	local words = expand_abbrevs_handle_recognized_suffixes(text, abbrev_text, origwords, "for pronun")
	text = table.concat(words)

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
		-- Transcriptions must contain a primary or second stress indicator or must explicitly be
		-- marked as unstressed, and an e or o with primary stress must be marked for quality.
		if not rfind(word, "[ˈˌ" .. DOTOVER .. "]") then
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

	-- Random substitutions.
	text = rsub(text, "%[x%]", TEMP_X) -- [x] means /x/
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
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*)([iu])([^" .. accent .. "])", function(v, gl, acc)
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
	text = rsub_repeatedly(text, "(" .. VW .. stress_c .. "?" .. charsep_c .. "*)s(" .. charsep_c .. "*" .. VW .. ")", "%1z%2")

	-- ⟨s⟩ immediately before a voiced consonant is always /z/
	text = rsub(text, "s(" .. charsep_c .. "*" .. voiced_C_c .. ")", "z%1")

	text = rsub(text, TEMP_Z, "z")
	text = rsub(text, TEMP_S, "s")
	text = rsub(text, TEMP_X, "x")

	-- Double consonant followed by end of word (e.g. [[stress]], [[staff]], [[jazz]]), or followed by a consonant
	-- other than a glide or liquid (e.g. [[pullman]]), should be reduced to single. Should not affect double
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


-- Entry point to construct the arguments to a call to m_IPA.format_IPA_full() and return the value of the call.
-- This formats one line of pronunciation, potentially including multiple individual pronunciations (representing
-- differing pronunciations of the same underlying term), potentialy along with attached qualifiers and/or references.
-- `data` is a table currently containing two fields, as follows:
--
-- {
--   terms = {{term = RESPELLING, qual = {QUALIFIER, QUALIFIER, ...}, ref = {REFSPEC, REFSPEC, ...}}, ...},
--   pagename = PAGENAME,
-- }
--
-- Here:
--
-- * RESPELLING is a pronunciation respelling of the term in question and may contain initial and/or final specs
--   indicating the presence, absence and nature of self-gemination and co-gemination along with initial specs
--   indicating the register of the pronunciation (traditional, careful style, elevated style).
-- * QUALIFIER is an arbitrary string to be displayed as a qualifier before the pronunciation in question; multiple
--   qualifiers will be comma-separated. `qual` should always be given as a table even if it's empty.
-- * REFSPEC is a string of the same format as is passed to {{IPA}}; see the documentation of [[Template:IPA]] for more
--   info. `ref`, as with `qual`, should always be given as a table even if it's empty.
-- * PAGENAME is the name of the page, used when an abbreviated spec like '^ò' is given.
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

	local phonemic_output = {}
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
		local phonemic = export.to_phonemic(respelling, data.pagename)
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
					return
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
		local refs
		if #terms.ref == 0 then
			refs = nil
		elseif #terms.ref == 1 then
			refs = require("Module:references").parse_references(terms.ref[1])
		else
			refs = {}
			for _, refspec in ipairs(term.ref) do
				local this_refs = require("Module:references").parse_references(refspec)
				for _, this_ref in ipairs(this_refs) do
					table.insert(refs, this_ref)
				end
			end
		end

		table.insert(phonemic_output, phonemic)
		table.insert(transcriptions, {
			pron = "/" .. phonemic.pron .. "/",
			qualifiers = #qualifiers > 0 and qualifiers or nil,
			pretext = pretext,
			posttext = posttext,
			refs = refs,
		})
	end

	return require("Module:IPA").format_IPA_full(lang, transcriptions), phonemic_output
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

	local IPA_full, _ = export.show_IPA_full(data)
	return IPA_full
end


-- Given the phonemic output from show_IPA_full (a list of objects of the form returned by to_phonemic), generate
-- a list of rhyme objects. The resulting list can be directly passed in as the `rhymes` field of the data object
-- passed into format_rhymes() in [[Module:rhymes]].
local function generate_rhymes_from_phonemic_output(phonemic_output)
	local rhymes = {}
	for _, phonemic in ipairs(phonemic_output) do
		local rhyme_pronun = rsub(rsub(pronun, ".*[ˌˈ]", ""), "^[^aeiouɛɔ]*", ""):gsub(TIE, ""):gsub("%.", "")
		local nsyl = ulen(pronun:gsub("[^.ˌˈ]", "")) + 1
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
			table.insert(rhymes, {rhyme = rhyme_pronun, num_syl = {nsyl}})
		end
	end
	return rhymes
end


-- Syllabify text based on its spelling. The text should be decomposed using decompose() and have extraneous
-- characters (e.g. initial *) removed.
local function syllabify_from_spelling(text)
	local TEMP_I = u(0xFFF1)
	local TEMP_U = u(0xFFF2)
	local TEMP_Y_CONS = u(0xFFF3)
	local TEMP_CH = u(0xFFF4)
	local TEMP_GH = u(0xFFF5)
	local TEMP_GN = u(0xFFF6)
	local TEMP_GL = u(0xFFF7)
	local TEMP_QU = u(0xFFF8)
	local TEMP_QU_CAPS = u(0xFFF9)
	local TEMP_GU = u(0xFFFA)
	local TEMP_GU_CAPS = u(0xFFFB)
	-- Change user-specified . into SYLDIV so we don't shuffle it around when dividing into syllables.
	text = text:gsub("%.", SYLDIV)
	text = rsub(text, "y(" .. V .. ")", TEMP_Y_CONS .. "%1")
	-- Digraphs that should never be split. We don't need to include digraphs beginning with s (sh, sc[ei]) because
	-- we always syllabify as V.sCV unless C = [srz].
	text = text:gsub("ch", TEMP_CH)
	text = text:gsub("gh", TEMP_GH)
	text = text:gsub("gn", TEMP_GN)
	text = text:gsub("gl", TEMP_GL)
	-- qu mostly handled correctly automatically, but not in quieto etc. See below.
	text = rsub(text, "qu(" .. V .. ")", TEMP_QU .. "%1")
	text = rsub(text, "Qu(" .. V .. ")", TEMP_QU_CAPS .. "%1")
	text = rsub(text, "gu(" .. V .. ")", TEMP_GU .. "%1")
	text = rsub(text, "Gu(" .. V .. ")", TEMP_GU_CAPS .. "%1")
	-- i and u between vowels -> consonant-like substitutions: [[paranoia]], [[febbraio]], [[abbaiare]], [[aiutare]],
	-- [[portauovo]], [[schopenhaueriano]], [[Malaui]], [[oltreuomo]], [[palauano]], [[tauone]], [etc.; also with h,
	-- as in [[nahuatl]], [[ahia]], etc. But in the common sequence -Ciuo- ([[figliuolo]], [[begliuomini]], [[giuoco]],
	-- [[nocciuola]], [[stacciuolo]], [[oriuolo]], [[guerricciuola]], [[ghiaggiuolo]], etc.), both i and u are glides.
	-- In the sequence -quiV- ([[quieto]], [[reliquia]], etc.), both u and i are glides, and probably also in -guiV-,
	-- but not in other -CuiV- sequences such as [[buio]], [[abbuiamento]], [[gianduia]], [[cuiusso]], [[alleluia]], etc.).
	-- Special cases are French-origin words like [[feuilleton]], [[rousseauiano]], [[gargouille]]; it's unlikely we
	-- can handle these correctly automatically. Note also examples of h not dividing diphthongs: [[ahi]], [[ehi]],
	-- [[ahimè]], [[ehilà]], [[ohimè]], [[ohilà]], etc.
	--
	-- We handle these cases as follows:
	-- 1. TEMP_QU, TEMP_GU etc. replace sequences of qu and gu with consonant-type codes. This allows us to distinguish
	--    -quiV-/-guiV- from other -CuiV-.
	-- 2. We convert i in -ViV- sequences to consonant-type TEMP_I, but similarly for u in -VuV- sequences only if the
	--    first V isn't i, so -CiuV- remains with two vowels.
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*h?)i(" .. V .. ")",
			function(v1, v2) return v1 .. TEMP_I .. v2 end)
	text = rsub_repeatedly(text, "(" .. V_NOT_I .. accent_c .. "*h?)u(" .. V .. ")",
			function(v1, v2) return v1 .. TEMP_U .. v2 end)
	-- Divide VCV as V.CV; but don't divide if C == h, e.g. [[ahimè]] should be ahi.mè.
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*)(" .. C_NOT_H .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. ")(" .. C .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. "+)(" .. C .. C .. V .. ")", "%1.%2")
	-- Existing hyphenations of [[atlante]], [[Betlemme]], [[genetliaco]], [[betlemita]] all divide as .tl,
	-- and none divide as t.l. No examples of -dl- but it should be the same per
	-- http://www.italianlanguageguide.com/pronunciation/syllabication.asp.
	text = rsub(text, "([pbfvkcgqtd])%.([lr])", ".%1%2")
	-- Italian appears to divide VsCV as V.sCV e.g. pé.sca for [[pesca]]. Exceptions are ss, sr, sz and possibly others.
	text = rsub(text, "s%.(" .. C_NOT_SRZ .. V .. ")", ".s%1")
	-- Also V.sCrV, C.sCrV and similarly V.sClV, V.sClV e.g. in.stru.mén.to for [[instrumento]], fi.nè.stra for
	-- [[finestra]].
	text = rsub(text, "s%.(" .. C .. "[lr])", ".s%1")
	-- Any aeoö, or stressed iuüy, should be syllabically divided from a following aeoö or stressed iuüy.
	-- A stressed vowel might be followed by another accent such as LINEUNDER (which we put after the acute/grave in
	-- decompose()).
	text = rsub_repeatedly(text, "([aeoöAEOÖ]" .. accent_c .. "*)(h?[aeoö])", "%1.%2")
	text = rsub_repeatedly(text, "([aeoöAEOÖ]" .. accent_c .. "*)(h?" .. V .. quality_c .. ")", "%1.%2")
	text = rsub(text, "([iuüyIUÜY]" .. quality_c .. accent_c .. "*)(h?[aeoö])", "%1.%2")
	text = rsub_repeatedly(text, "([iuüyIUÜY]" .. quality_c .. accent_c .. "*)(h?" .. V .. quality_c .. ")", "%1.%2")
	text = rsub_repeatedly(text, "([iI]" .. accent_c .. "*)(h?i)", "%1.%2")
	text = rsub_repeatedly(text, "([uüUÜ]" .. accent_c .. "*)(h?[uü])", "%1.%2")
	text = text:gsub(SYLDIV, ".")
	text = text:gsub(TEMP_I, "i")
	text = text:gsub(TEMP_U, "u")
	text = text:gsub(TEMP_Y_CONS, "y")
	text = text:gsub(TEMP_CH, "ch")
	text = text:gsub(TEMP_GH, "gh")
	text = text:gsub(TEMP_GN, "gn")
	text = text:gsub(TEMP_GL, "gl")
	text = text:gsub(TEMP_QU, "qu")
	text = text:gsub(TEMP_QU_CAPS, "Qu")
	text = text:gsub(TEMP_GU, "gu")
	text = text:gsub(TEMP_GU_CAPS, "Gu")
	return text
end


local function normalize_for_syllabification(text, pagename)
	if text == "+" then
		text = pagename
	end
	text = rsub(text, pron_sign_or_punc_c, " ")
	text = canon_spaces(text)
	local abbrev_text
	if rfind(text, "^%^[àéèìóòù]$") then
		if pagename:find("[ %-]") then
			error("With abbreviated vowel spec " .. text .. ", the page name should be a single word: " .. pagename)
		end
		abbrev_text = decompose(text)
		text = pagename
	end
	local origwords = rsplit(text, "[ %-]+")
	text = decompose(text)
	text = rsub(text, "([aiu])" .. AC, "%1" .. GR) -- áíú -> àìù
	local words = expand_abbrevs_handle_recognized_suffixes(text, abbrev_text, origwords, false)

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

			-- Auto-stress some monosyllabic and bisyllabic words.
			if not is_prefix and not unstressed_words[word] and not rfind(word, "[" .. AC .. GR .. DOTOVER .. "]") then
				vowel_count = ulen(rsub(word, NV, ""))
				if vowel_count > 2 then
					err("With more than two vowels and an unrecogized suffix, stress must be explicitly given")
				else
					local before, vow, after = rmatch(word, "^(.-)(" .. V .. ")(.*)$")
					if before then
						before, vow, after = m.groups()
						if rfind(vow, "^[eoEO]$") then
							err("When stressed vowel is e or o, it must be marked é/è or ó/ò to indicate quality")
						word = before .. vow .. GR .. after
					end
				end
			end

			words[i] = word
		end
	end

	text = table.concat(words)
	text = text:gsub("ddz", "zz"):gsub("tts", "zz"):gsub("dz", "z"):gsub("ts", "z"):gsub("Dz", "Z"):gsub("Ts", "Z")
		:gsub("%[([sz])%]", "%1"):gsub("_", "")
	return text
end


local function spelling_normalized_for_syllabification_matches_pagename(text, pagename)
	text = text:gsub("%.", "")
	text = remove_non_final_accents(remove_secondary_stress(text))
	-- Check if the normalized pronunciation is the same as the page name. If a word in the page name is a single
	-- syllable, it may or may not have an accent on it, so also remove final monosyllabic accents from the normalized
	-- pronunciation when comparing. (Don't remove from both normalized pronunciation and page name because we don't want
	-- pronunciation rè to match page name ré or vice versa.)
	return text == pagename or remove_final_monosyllabic_accents(text) == pagename
end


-- External entry point for {{it-pr}}.
function export.show_pr(frame)
	local params = {
		[1] = {list = true},
		["rhyme"] = {},
		["hyph"] = {},
		["pagename"] = {}, -- for testing
	}
	local parargs = frame:getParent().args
	local args = require("Module:parameters").process(parargs, params)
	local pagename = args.pagename or mw.title.getCurrentTitle().subpageText

	-- Parse the arguments.
	local respellings = #args[1] > 0 and args[1] or {"+"}
	local parsed_respellings = {}
	local overall_rhyme = args.rhyme and rsplit(args.rhyme, "%s*,%s*") or nil
	local overall_hyph = args.hyph and rsplit(args.hyph, "%s*,%s*") or nil
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
			local parsed = {terms = {}, audio = {}, rhyme = {}, hyph = {}}
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
							"'pre', 'post', 'ref', 'bullets', 'audio', 'rhyme', 'hyph' or 'qual'")
					end
					if prefix == "ref" or prefix == "qual" then
						table.insert(term[prefix], arg)
					elseif prefix == "pre" or prefix == "post" or prefix == "bullets" or prefix == "rhyme"
						or prefix == "hyph" or prefix == "audio" then
						if i < #comma_separated_groups then
							parse_err("Modifier '" .. prefix .. "' should occur after the last comma-separated term")
						end
						if prefix == "rhyme" then
							local rhyme_segments = iut.parse_balanced_segment_run(arg, "<", ">")
							local comma_separated_rhyme_runs = iut.split_alternating_runs(rhyme_segments, "%s*,%s*")
							for _, rhyme_run in ipairs(comma_separated_rhyme_runs) do
								local rhyme = rhyme_run[1]
								local num_syl
								if #rhyme_run > 1 then
									if rhyme_run[3] ~= "" then
										parse_err("Extraneous text '" .. rhyme_run[3] .. "' after rhyme")
									end
									if #rhyme_run > 3 then
										parse_err("Only one modifier allowed after rhyme")
									end 
									local rhyme_modtext = rhyme_run[2]:match("^<(.*)>$")
									if not rhyme_modtext then
										parse_err("Internal error: Rhyme modifier '" .. rhyme_run[2] .. "' isn't surrounded by angle brackets")
									end
									local rhyme_prefix, rhyme_arg = rhyme_modtext:match("^([a-z]+):(.*)$")
									if not rhyme_prefix then
										parse_err("Rhyme modifier " .. rhyme_run[2] .. " lacks a prefix, should be 's'")
									end
									if rhyme_prefix ~= "s" then
										parse_err("Unrecognized prefix '" .. rhyme_prefix .. "' in modifier " .. rhyme_run[2] .. ", should be 's'")
									end
									local nsyls = rsplit(rhyme_arg, "%s*,%s*")
									for _, nsyl in ipairs(nsyls) do
										if not nsyl:find("^[0-9]+$") then
											parse_err("Number of syllables '" .. nsyl .. "' in rhyme " ..
												table.concat(rhyme_run) .. " should be numeric")
										end
										if not num_syl then
											num_syl = {}
										end
										table.insert(num_syl, tonumber(nsyl))
									end
								end
								table.insert(parsed.rhyme, {rhyme = rhyme, num_syl = num_syl})
							end
						elseif prefix == "hyph" then
							local vals = rsplit(arg, "%s*,%s*")
							for _, val in ipairs(vals) do
								table.insert(parsed.hyph, val)
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
						parse_err("Unrecognized prefix '" .. prefix .. "' in modifier " .. group[j])
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
			for _, term in rsplit(respelling, "%s*,%s*") do
				table.insert(terms, {term = term, ref = {}, qual = {}})
			end
			table.insert(parsed_respellings, {
				terms = terms,
				audio = {},
				rhyme = {},
				hyph = {},
				bullets = 1,
			})
		end
		end
	end

	if overall_hyph then
		local hyphs = {}
		for _, hyph in ipairs(overall_hyph) do
			if hyph == "-" then
				hyphs = {}
				break
			else
				m_table.insertIfNot(hyphs, hyph)
			end
		end
		overall_hyph = hyphs
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

		local hyphs = {}
		if #parsed.hyph == 0 then
			if not overall_hyph and all_words_have_vowels(pagename) then
				for _, term in ipairs(parsed.terms) do
					if normalize_spelling_for_comparison(term) == pagename then
						m_table.insertIfNot(hyphs, normalize_and_syllabify_from_spelling(term, pagename))
					end
				end
			end
		else
			for _, hyph in ipairs(parsed.hyph) do
				if hyph == "+" then
					for _, term in ipairs(parsed.terms) do
						m_table.insertIfNot(hyphs, syllabify_from_spelling(term))
					end
				elseif hyph == "-" then
					hyphs = {}
					break
				else
					m_table.insertIfNot(hyphs, hyph)
				end
			end
		end
		parsed.hyph = hyphs

		-- Generate the rhymes.
		local function dodialect(rhyme_ret, dialect)
			rhyme_ret.pronun[dialect] = {}
			for _, pronun in ipairs(parsed.pronun.pronun[dialect]) do
				if all_words_have_vowels(pronun) then
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
							num_syl = num_syl,
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
				parsed.rhyme = express_all_styles(parsed.style, dodialect)
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

		return format_all_styles(rhyme_ret.expressed_styles, format_style)
	end

	-- If all sets of pronunciations have the same hyphenations, display them only once at the bottom.
	-- Otherwise, display hyphenations beneath each set, indented.
	local first_hyphs
	local all_hyph_sets_eq = true
	for j, parsed in ipairs(parsed_respellings) do
		if j == 1 then
			first_hyphs = parsed.hyphs
		elseif not m_table.deepEquals(first_hyphs, parsed.hyphs) then
			all_hyph_sets_eq = false
			break
		end
	end

	local function format_hyphenation(hyphs, num_bullets)
		local hyphtext = require("Module:hyphenation").format_hyphenation { lang = lang, hyphs = hyphs }
		return string.rep("*", num_bullets) .. " " .. hyphtext
	end

	local function format_audio(audio, num_bullets)
		local ret = {}
		for i, a in ipairs(audio) do
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
		if not all_hyph_sets_eq and #parsed.hyphs > 0 then
			table.insert(textparts, "\n")
			table.insert(textparts, format_hyphenation(parsed.hyph, parsed.bullets + 1))
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
		table.insert(textparts, format_hyphenation(first_hyphs, min_num_bullets))
	end
	if overall_hyph and #overall_hyph > 0 then
		table.insert(textparts, "\n")
		table.insert(textparts, format_hyphenation(overall_hyph, min_num_bullets))
	end

	return table.concat(textparts)
end


return export
