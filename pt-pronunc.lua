--[[
This module implements the template {{pt-IPA}}.

Author: Benwing

]]

local export = {}

local m_IPA = require("Module:IPA")
local m_table = require("Module:table")
local m_strutils = require("Module:string utilities")

local lang = require("Module:languages").getByCode("pt")

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
local CEDILLA = u(0x0327) -- cedilla =  ̧
local DOTOVER = u(0x0307) -- dot over =  ̇
local DOTUNDER = u(0x0323) -- dot under =  ̣
local TEMP1 = u(0xFFF0)
local SYLDIV = u(0xFFF1) -- used to represent a user-specific syllable divider (.) so we won't change it

local vowel = "aɐeɛiɨoɔuAEO"
local V = "[" .. vowel .. "]"
local W = "[yw]" -- glide
local ipa_stress = "ˈˌ"
local ipa_stress_c = "[" .. ipa_stress .. "]"
local quality = AC .. CFLEX
local quality_c = "[" .. quality .. "]"
local stress = GR .. DOTOVER .. DOTUNDER .. ipa_stress
local stress_c = "[" .. stress .. "]"
local non_primary_stress = GR .. DOTOVER .. DOTUNDER .. "ˌ"
local non_primary_stress_c = "[" .. non_primary_stress .. "]"
local accent = quality .. stress .. TILDE
local accent_c = "[" .. accent .. "]"
local charsep = accent .. "_." .. SYLDIV
local charsep_c = "[" .. charsep .. "]"
local wordsep = charsep .. " #"
local wordsep_c = "[" .. wordsep .. "]"
local C = "[^" .. vowel .. wordsep .. "]" -- consonant
local C_NOT_H = "[^h" .. vowel .. wordsep .. "]" -- consonant other than h
local C_OR_WORD_BOUNDARY = "[^" .. vowel .. charsep .. "]" -- consonant or word boundary
local voiced_cons = "bdgjlʎmnɲŋrɾʁvwyzʒ" -- voiced sound

-- Unstressed words with vowel reduction in Brazil and Portugal.
local unstressed_words = require("Module:table").listToSet({
	"o", "os", -- definite articles
	"me", "te", "se", "lhe", "lhes", "nos", "vos", -- unstressed object pronouns
	"que", -- subordinating conjunctions
	"e", -- coordinating conjunctions
	"de", "do", "dos", "no", "por", -- basic prepositions + combinations with articles; [[nos]] above as object pronoun
})

-- Unstressed words with vowel reduction in Portugal only.
local unstressed_full_vowel_words_brazil = require("Module:table").listToSet({
	"a", "as", -- definite articles
	"da", "das", "na", "nas", -- basic prepositions + combinations with articles
})

-- Unstressed words without vowel reduction.
local unstressed_full_vowel_words = require("Module:table").listToSet({
	"um", "ums", -- single-syllable indefinite articles
	"meu", "teu", "seu", "meus", "teus", "seus", -- single-syllable possessives
	"ou", -- coordinating conjunctions
	"ao", "aos", "a" .. GR, "a" .. GR .. "s", -- basic prepositions + combinations with articles
	"em", "com", -- other prepositions
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

export.all_styles = {"rio", "sp", "lisbon", "cpt"}
export.all_style_descs = {
	rio = "Rio",
	sp = "São Paulo",
	lisbon = "Lisbon",
	cpt = "non-Lisbon Portugal"
}

-- style == one of the following:
-- "rio": Carioca accent (of Rio de Janeiro)
-- "sp": Paulistano accent (of São Paulo)
-- "lisbon": Lisbon accent
-- "cpt": Central Portugal accent outside of Lisbon
function export.IPA(text, style, phonetic)
	local origtext = text

	local function err(msg)
		error(msg .. ": " .. origtext)
	end

	local brazil = style == "rio" or style == "sp"

	text = ulower(text or mw.title.getCurrentTitle().text)
	-- decompose everything but ç and ü
	text = mw.ustring.toNFD(text)
	text = rsub(text, ".[" .. CEDILLA .. DIA .. "]", {
		["c" .. CEDILLA] = "ç",
		["u" .. DIA] = "ü",
	})
	-- There can conceivably be up to three accents on a vowel: a quality mark (acute/circumflex); a mark indicating
	-- secondary stress (grave), tertiary stress (dotunder; i.e. no stress but no vowel reduction) or forced vowel
	-- reduction (dotover); and a nasalization mark (tilde). Order them as follows: quality - stress - nasalization.
	text = rsub(text, TILDE .. "([" .. AC .. CFLEX .. GR .. DOTUNDER .. DOTOVER .. "]+)", "%1" .. TILDE) -- tilde last
	text = rsub(text, "([" .. GR .. DOTUNDER .. DOTOVER .. "])([" .. AC .. CFLEX .. "]+)", "%2%1") -- acute/cflex first
	if rfind(text, "[^aeo]" .. CFLEX) then
		err("Circumflex can only follow a/e/o")
	end

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

	-- Make prefixes unstressed with vowel reduction unless they have an explicit stress marker;
	-- likewise for certain monosyllabic words (e.g. [[o]], [[se]], [[de]], etc.; also [[a]], [[das]], etc.
	-- in Portugal) without stress marks.
	local words = rsplit(text, " ")
	for i, word in ipairs(words) do
		if rfind(word, "%-$") and not rfind(word, accent_c) or unstressed_words[word] or
			not brazil and unstressed_full_vowel_words_brazil[word] then
			-- add DOTOVER to the last vowel not the first one, or we will mess up 'que' by
			-- adding the DOTOVER after the 'u'
			words[i] = rsub(word, "^(.*" .. V .. ")", "%1" .. DOTOVER)
		end
	end
	-- Make certain monosyllabic words (e.g. [[meu]], [[com]]; also [[a]], [[das]], etc. in Brazil)
	-- without stress marks be unstressed without vowel reduction.
	for i, word in ipairs(words) do
		if rfind(word, "%-$") and not rfind(word, accent_c) or unstressed_full_vowel_words[word] or
			brazil and unstressed_full_vowel_words_brazil[word] then
			-- add DOTUNDER to the first vowel not the last one, or we will mess up 'meu' by
			-- adding the DOTUNDER after the 'u'
			words[i] = rsub(word, "^(.-" .. V .. ")", "%1" .. DOTUNDER)
		end
	end

	text = table.concat(words, " ")
	-- Convert hyphens to spaces, to handle [[Austria-Hungría]], [[franco-italiano]], etc.
	text = rsub(text, "%-", " ")
	-- canonicalize multiple spaces again, which may have been introduced by hyphens
	text = canon_spaces(text)
	-- now eliminate punctuation
	text = rsub(text, "[!?']", "")
	-- put # at word beginning and end and double ## at text/foot boundary beginning/end
	text = rsub(text, " | ", "# | #")
	text = "##" .. rsub(text, " ", "# #") .. "##"

	-- [[à]], [[às]]; remove grave accent
	text = rsub(text, "(#a" .. DOTUNDER .. "?)" .. GR .. "(s?#)", "%1%2")

	-- x
	text = rsub(text, "#x", "#ʃ") -- xérox, xilofone, etc.
	text = rsub(text, "x#", "kç#") -- xérox, córtex, etc.
	text = rsub(text, "(" .. V .. charsep_c .. "*i" .. charsep_c .. "*)x", "%1ʃ") -- baixo, peixe, etc.
	if rfind(text, "x") then
		err("x must be respelled z, ch, sh, cs, ss or similar")
	end

	-- combinations with h; needs to precede handling of c and s, and needs to precede syllabification so that
	-- the consonant isn't divided from the following h.
	text = rsub(text, "([scln])h", {["s"]="ʃ", ["c"]="ʃ", ["n"]="ɲ", ["l"]="ʎ" })

	-- c, g, q
	-- This should precede syllabification especially so that the latter isn't confused by gu, qu, gü, qü
	-- also, c -> ç before front vowel ensures that cc e.g. in [[cóccix]], [[occitano]] isn't reduced to single c.
	text = rsub(text, "c([iey])", "ç%1")
	text = rsub(text, "g([iey])", "j%1")
	text = rsub(text, "gu([iey])", "g%1")
	-- [[camping]], [[doping]], [[jogging]], [[Bangkok]], [[angstrom]], [[tungstênio]]
	text = rsub(text, "ng([^aeiouyüwhlr])", "n%1")
	text = rsub(text, "qu([iey])", "k%1")
	text = rsub(text, "ü", "u") -- [[agüentar]], [[freqüentemente]], [[Bündchen]], [[hübnerita]], etc.
	text = rsub(text, "([gq])u(" .. V .. ")", "%1w%2") -- [[quando]], [[guarda]], etc.
	text = rsub(text, "[cq]", "k") -- [[Qatar]], [[burqa]], [[Iraq]], etc.

	-- y -> i between non-vowels, cf. [[Itamaraty]] /i.ta.ma.ɾa.ˈt(ʃ)i/, [[Sydney]] respelled 'Sýdjney' or similar
	-- /ˈsid͡ʒ.nej/ (Brazilian). Most words with y need respelling in any case, but this may help.
	text = rsub(text, "(" .. C_OR_WORD_BOUNDARY .. ")y(" .. accent_c .. "*" .. C_OR_WORD_BOUNDARY .. ")", "%1i%2")

	-- Reduce double letters to single, except for rr, mm, nn and ss, which map to special single sounds. Do this
	-- before syllabification so double letters don't get divided across syllables. The case of cci, cce is handled
	-- above. nn always maps to /n/ and mm to /m/ and can be used to force a coda /n/ or /m/. As a result,
	-- [[connosco]] will need respelling 'comnôsco', 'cõnôsco' or 'con.nôsco', and [[comummente]] will similarly
	-- need respelling e.g. as 'comum.mente' or 'comũmente'. Examples of words with double letters (Brazilian
	-- pronunciation):
	-- * [[Accra]] no respelling needed /ˈa.kɾɐ/;
	-- * [[Aleppo]] respelled 'Aléppo' /aˈlɛ.pu/;
	-- * [[buffer]] respelled 'bâfferh' /ˈbɐ.feʁ/;
	-- * [[cheddar]] respelled 'chéddarh' /ˈʃɛ.daʁ/;
	-- * [[Hanna]] respelled 'Ranna' /ˈʁɐ̃.nɐ/;
	-- * [[jazz]] respelled 'djézz' /ˈd͡ʒɛs/;
	-- * [[Minnesota]] respelled 'Mìnnessôta' /ˌmi.neˈso.tɐ/;
	-- * [[nutella]] respelled 'nutélla' /nuˈtɛ.lɐ/;
	-- * [[shopping]] respeled 'shópping' /ˈʃɔ.pĩ/ or 'shóppem' /ˈʃɔ.pẽj̃/;
	-- * [[Stonehenge]] respelled 'Stòwnn.rrendj' /ˌstownˈʁẽd͡ʒ/;
	-- * [[Yunnan]] no respelling needed /juˈnɐ̃/.
	--
	-- Note that further processing of r and s happens after syllabification and stress assignment, because we need
	-- e.g. to know the distinction between final -s and -z to assign the stress properly.
	text = rsub(text, "rr", "ʁ")
	text = rsub(text, "nn", "N")
	text = rsub(text, "mm", "M")
	text = rsub(text, "ss", "ç")
	text = rsub(text, "(" .. C .. ")%1", "%1")

	-- Divide words into syllables.
	-- First, change user-specified . into a special character so we won't move it around. We need to keep this
	-- going forward until after we place the stress, so we can correctly handle initial i- + vowel, as in [[ia]],
	-- [[iate]] and [[Iaundé]]. We need to divide [[ia]] as 'i.a' but [[iate]] as 'ia.te' and [[Iaundé]] as 'Ia.un.dé'.
	-- In the former case, the stress goes on i but in the latter cases not; so we always divide <ia> as 'i.a',
	-- and then after stress assignment remove the syllable divider if the <i> isn't stressed. The tricky thing is
	-- that we want to allow the user to override this by explicitly adding a . between the <i> and <a>. So we need
	-- to keep the distinction between user-specified . and auto-determined . until after stress assignment.
	text = rsub(text, "%.", SYLDIV)
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*)(" .. C .. W .. "?" .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. ")(" .. C .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. "+)(" .. C .. C .. V .. ")", "%1.%2")
	text = rsub(text, "([pbktdg])%.([lr])", ".%1%2")
	-- /tʃ/, /dʒ/ are normally single sounds, but adj- in [[adjetivo]], [[adjunto]] etc. should be 'ad.j'
	text = rsub(text, "t%.ʃ", ".tʃ")
	text = rsub(text, "d%.j", ".dj")
	text = rsub(text, "#a.dj", "#ad.j")
	text = rsub_repeatedly(text, "(" .. C .. ")%.s(" .. C .. ")", "%1s.%2")
	-- All vowels should be separated from adjacent vowels by a syllable division except
	-- (1) aeo + unstressed i/u, ([[saiba]], [[peixe]], [[noite]], [[Paulo]], [[deusa]], [[ouro]]), except when
	-- followed by nh or m/n/r/l + (non-vowel or word end), e.g. Bom.ba.im, ra.i.nha, Co.im.bra, sa.ir, but Jai.me,
	-- a.mai.nar, bai.le, ai.ro.so, quei.mar, bei.ra;
	-- (2) iu(s), ui(s) at end of word, e.g. fui, Rui, a.zuis, pa.riu, viu, sa.iu;
	-- (3) ão, ãe, õe.
	--
	-- The easiest way to handle this is to put a special symbol between vowels that should not have a syllable
	-- division between them.
	--
	-- First, put a syllable divider between [aeo].[iu][mnlr], as in [[Bombaim]], [[Coimbra]], [[saindo]], [[sair]],
	-- [[Iaundé]], [[Raul]]. Note that in cases like [[Jaime]], [[queimar]], [[fauna]], [[baile]], [[Paulo]], [[beira]],
	-- where a vowel follows the m/n/l/r, there will already be a syllable division between i.m, u.n, etc., which will
	-- block the following substitution.
	text = rsub(text, "([aeo]" .. accent_c .. "*)([iu][mnlr])", "%1.%2")
	-- Also put a syllable divider between [aeo].[iu].ɲ coming from 'nh' ([[rainha]], [[moinho]]).
	text = rsub(text, "([aeo]" .. accent_c .. "*)([iu]%.ɲ)", "%1.%2")
	-- Prevent syllable division between final -ui(s), -iu(s). This should precede the following rule that prevents
	-- syllable division between ai etc., so that [[saiu]] "he left" gets divided as sa.iu.
	text = rsub(text, "(u" .. accent_c .. "*)(is?#)", "%1" .. TEMP1 .. "%2")
	text = rsub(text, "(i" .. accent_c .. "*)(us?#)", "%1" .. TEMP1 .. "%2")
	-- Prevent syllable division between ai, ou, etc. unless either the second vowel is accented [[saído]]) or there's
	-- a TEMP1 marker already after the second vowel (which will occur e.g. in [[saiu]] divided as 'sa.iu').
	text = rsub_repeatedly(text, "([aeo]" .. accent_c .. "*)([iu][^" .. accent .. TEMP1 .. "])", "%1" .. TEMP1 .. "%2")
	-- Prevent syllable division between nasal diphthongs unless somehow the second vowel is accented.
	text = rsub_repeatedly(text, "(a" .. TILDE .. ")([eo][^" .. accent .. "])", "%1" .. TEMP1 .. "%2")
	text = rsub_repeatedly(text, "(o" .. TILDE .. ")(e[^" .. accent .. "])", "%1" .. TEMP1 .. "%2")
	-- All other sequences of vowels get divided.
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*)(" .. V .. ")", "%1.%2")
	-- Remove the marker preventing syllable division.
	text = rsub(text, TEMP1, "")

	-- An acute or circumflex not followed by a stress marker has primary stress, so indicate it.
	text = rsub_repeatedly(text, "(" .. V .. quality_c .. ")([^" .. stress .. "])", "%1ˈ%2")
	-- All graves indicate secondary stress.
	text = rsub(text, GR, "ˌ")

	-- Add primary stress to the word if not already present. If the word ends in -mente or -zinho, we add two
	-- primary stresses; the first one will be converted to secondary stress down below. Note that `syllables` is
	-- a list that includes the syllable dividers as separate items (either SYLDIV if user-specified, or . if
	-- auto-added), so the actual syllables are found at indices 1, 3, 5, etc.
	local function accent_word(word, syllables)
		-- Check if stress already marked. We check first for primary stress before checking for tilde in case both
		-- primary stress and tilde occur, e.g. [[bênção]], [[órgão]], [[hétmã]], [[connosco]] respelled 'cõnôsco'.
		if rfind(word, "ˈ") then
			return
		end

		-- Check for nasal vowel marked with tilde and without non-primary stress; assign stress to the last such
		-- syllable in case there's more than one tilde, e.g. [[pãozão]]. Note, this can happen in the part before
		-- -mente, cf. [[anticristãmente]], and before -zinho, cf. [[coraçãozinho]].
		for i = #syllables,1,-2 do -- -2 because of the syllable dividers; see above.
			local changed
			syllables[i], changed = rsubb(syllables[i], "(" .. V .. quality_c .. "*)" .. TILDE, "%1ˈ" .. TILDE)
			if changed then
				return
			end
		end

		-- Apply the default stress rule.
		local sylno
		if #syllables > 1 and (rfind(word, "[aeo]s?#") or rfind(word, "[ae]m#") or rfind(word, "[ae]ns#")) then
			-- Stress the last syllable but one. The -2 is because of the syllable dividers; see above.
			sylno = #syllables - 2
		else
			sylno = #syllables
		end
		if rfind(syllables[sylno], stress_c) then
			-- Don't do anything if stress mark already present.
			return
		end
		-- Add stress mark after first vowel (and any quality mark).
		syllables[sylno] = rsub(syllables[sylno], "^(.-" .. V .. quality_c .. "*)", "%1ˈ")
	end

	-- Split the text into words and the words into syllables so we can correctly add stress to words without it.
	local words = rsplit(text, " ")
	for j, word in ipairs(words) do
		-- Preserve the syllable divider, which may be auto-added or user-specified.
		local syllables = m_strutils.capturing_split(word, "([." .. SYLDIV .. "])")

		if rfind(word, "[%." .. SYLDIV .. "]men%.te#") or rfind(word, "[%." .. SYLDIV .. "]zi%.ɲo#") then
			local mente_syllables
			-- Words ends in -mente or -zinho; add primary stress to the preceding portion as if stressed
			-- (e.g. [[agitadamente]] -> 'agitádamente') unless already stressed (e.g. [[rapidamente]]
			-- respelled 'rápidamente'). The primary stress will be converted to secondary stress further below.
			-- Essentially, we rip the word apart into two words ('mente'/'zinho' and the preceding portion) and
			-- stress each one independently. Note that the effect of adding a primary stress will also be to cause
			-- an error if stressed 'e' or 'o' is not properly marked as é/ê or ó/ô; cf. [[certamente]], which must
			-- be respelled 'cértamente', and [[posteriormente]], which must be respelled 'posteriôrmente', just as
			-- with [[certa]] and [[posterior]]. To prevent this happening, you can add an accent to -mente or
			-- -zinho, e.g. [[dormente]] respelled 'dormênte', [[vizinho]] respelled 'vizínho'.
			mente_syllables = {}
			mente_syllables[3] = table.remove(syllables)
			mente_syllables[2] = table.remove(syllables) -- this will be a syllable divider
			mente_syllables[1] = table.remove(syllables)
			table.remove(syllables) -- this will be a syllable divider
			accent_word(table.concat(syllables, "") .. "#", syllables)
			accent_word("#" .. table.concat(mente_syllables, ""), mente_syllables)
			-- Reconstruct the word. Put a # instead of . between the two parts so e.g. the vowel at the end
			-- of the first part is treated as word-final. Don't cache the concat() before accent_word() changes
			-- the syllables.
			words[j] = table.concat(syllables, "") .. "#" .. table.concat(mente_syllables, "")
		else
			accent_word(word, syllables)
			-- Reconstruct the word.
			words[j] = table.concat(syllables, "")
		end
	end

	-- Reconstruct the text from the words.
	text = table.concat(words, " ")

	-- Remove hiatus between initial <i> and following vowel ([[Iasmim]]) unless the <i> is stressed ([[ia]]) or the
	-- user explicitly added a . (converted to SYLDIV above).
	text = rsub(text, "#i%.(" .. V .. ")", "#y%1")

	-- Convert user-specified syllable division back to period. See comment above when we add SYLDIV.
	text = rsub(text, SYLDIV, ".")

	-- Vowel quality handling. First convert all a -> A, e -> E, o -> O. We will then convert A -> a/ɐ, E -> e/ɛ/ɨ,
	-- O -> o/ɔ/u depending on accent marks and context. Ultimately all vowels will be one of the nine qualities
	-- aɐeɛiɨoɔu and following each vowel will either be nothing (no stress), an IPA primary stress mark (ˈ) or an
	-- IPA secondary stress mark (ˌ), in turn possibly followed by a tilde (nasalization). After doing everything
	-- that depends on the position of stress, we will move the IPA stress marks to the beginning of the syllable.
	text = rsub(text, "[aeo]", {["a"] = "A", ["e"] = "E", ["o"] = "O"})
	text = rsub(text, DOTOVER, "") -- eliminate DOTOVER; it served its purpose of preventing stress

	-- Nasal vowel handling.

	-- Final unstressed -am (in third-person plural verbs) pronounced like unstressed -ão.
	text = rsub(text, "Am#", "A" .. TILDE .. "O#")
	-- Acute accent on final -em ([[além]], [[também]]) and final -ens ([[parabéns]]) does not indicate an open
	-- pronunciation.
	text = rsub(text, "E" .. AC .. "(ˈ[mn]s?#)", "E" .. CFLEX .. "%1")
	-- Vowel + m/n within a syllable gets converted to tilde.
	text = rsub(text, "(" .. V .. quality_c .. "*" .. stress_c .. "*)[mn]", "%1" .. TILDE)
	-- Vowel without quality mark + tilde needs to get the circumflex (possibly fed by the previous change).
	text = rsub(text, "(" .. V .. ")(" .. stress_c .. "*)" .. TILDE, "%1" .. CFLEX .. "%2" .. TILDE)
	-- Primary-stressed vowel without quality mark + m/n/nh across syllable boundary gets a circumflex, cf. [[cama]],
	-- [[ano]], [[banho]].
	text = rsub(text, "(" .. V .. ")(ˈ%.[mnɲMN])", "%1" .. CFLEX .. "%2")
	if brazil then
		-- Primary-stressed vowel + m/n across syllable boundary gets nasalized in Brazil, cf. [[cama]], [[ano]].
		text = rsub(text, "(" .. V .. quality_c .. "*)(ˈ%.[mnMN])", "%1" .. TILDE .. "%2")
		-- All vowels before nh (always across syllable boundary) get circumflexed and nasalized in Brazil,
		-- cf. [[ganhar]].
		text = rsub(text, "(" .. V .. stress_c .. "*)(%.ɲ)", "%1" .. CFLEX .. "%2")
		text = rsub(text, "(" .. V .. quality_c .. "*" .. stress_c .. "*)(%.ɲ)", "%1" .. TILDE .. "%2")
		-- Initial unstressed em-/en- before consonant raises to /ĩ/.
		text = rsub(text, "#E" .. CFLEX .. TILDE, "#i" .. TILDE)
	end

	-- Nasal diphthongs.
	local nasal_termination_to_glide = {["E"] = "y", ["O"] = "w"}
	-- In ãe, ão, the second letter represents a glide.
	text = rsub(text, "(A" .. CFLEX .. stress_c .. "*" .. TILDE .. ")([EO])",
		function(v1, v2) return v1 .. nasal_termination_to_glide[v2] .. TILDE end)
	-- Likewise for õe.
	text = rsub(text, "(O" .. CFLEX .. stress_c .. "*" .. TILDE .. ")E", "%1y" .. TILDE)
	-- Final -em and -ens (stressed or not) pronounced /ẽj̃(s)/. (Later converted to /ɐ̃j̃(s)/ in Portugal.)
	text = rsub(text, "(E" .. CFLEX .. stress_c .. "*" .. TILDE .. ")(s?#)", "%1y" .. TILDE .. "%2")

	-- Oral diphthongs.
	-- ei, eu, oi, ou -> êi, êu, ôi, ôu
	text = rsub(text, "([EO])(" .. stress_c .. "*[iuywY])", "%1" .. CFLEX .. "%2")

	-- Convert A/E/O as appropriate when followed by a secondary or tertiary stress marker. If a quality is given,
	-- it takes precedence; otherwise, act as if an acute accent were given.
	text = rsub(text, "([AEO])(" .. non_primary_stress_c .. ")", "%1" .. AC .. "%2")

	-- Unstressed syllables.
	if brazil then
		-- Final unstressed -e(s), -o(s) -> /i/ /u/ (including before -mente)
		local brazil_final_vowel = {["E"] = "i", ["O"] = "u"}
		text = rsub(text, "([EO])(s?#)", function(v, after) return brazil_final_vowel[v] .. after end)
		-- Word-final unstressed -a(s) -> /ɐ/ (not before -mente)
		text = rsub(text, "A(s?#[# ])", function(after) return "ɐ" .. after end)
		-- Remaining unstressed a, e, o without quality mark -> /a/ /e/ /o/.
		local brazil_unstressed_vowel = {["A"] = "a", ["E"] = "e", ["O"] = "o"}
		text = rsub(text, "([AEO])([^" .. accent .. "])",
			function(v, after) return brazil_unstressed_vowel[v] .. after end)
	else
		-- Initial unmarked unstressed non-nasal e- -> /i/
		text = rsub(text, "#E([^" .. accent .. "])", "#i%1")
		-- All other unmarked unstressed non-nasal e, o, a -> /ɨ/ /u/ /ɐ/
		local portugal_unstressed_vowel = {["A"] = "ɐ", ["E"] = "ɨ", ["O"] = "u"}
		text = rsub(text, "([AEO])([^" .. accent .. "])",
			function(v, after) return portugal_unstressed_vowel[v] .. after end)
	end

	-- Remaining vowels.
	-- All remaining a -> /a/ (should always be stressed).
	text = rsub(text, "A([^" .. quality .. "])", "a%1")
	-- Ignore quality markers on i, u; only one quality.
	text = rsub(text, "([iu])" .. quality_c, "%1")
	-- Convert a/e/o + quality marker appropriately.
	local vowel_quality = {
		["A" .. AC] = "a", ["A" .. CFLEX] = "ɐ",
		["E" .. AC] = "ɛ", ["E" .. CFLEX] = "e",
		["O" .. AC] = "ɔ", ["O" .. CFLEX] = "o",
	}
	text = rsub(text, "([AEO]" .. quality_c .. ")", vowel_quality)
	-- Any remaining E or O (always without quality marker) is an error.
	if rfind(text, "[EO]") then
		err("Stressed e or o not occurring nasalized or in a diphthong must be marked for quality using é/ê or ó/ô")
	end

	-- Finally, eliminate DOTUNDER, now that we have done all vowel reductions.
	text = rsub(text, DOTUNDER, "")

	-- s, z
	-- s in trans + V -> z: [[transação]], [[intransigência]]
	text = rsub(text, "(trɐ" .. stress_c .. "*" .. TILDE .. ".)s(" .. V .. ")", "%1z%2")
	-- word final z -> s
	text = rsub(text, "z#", "s#")
	-- s between vowels (not nasalized) or between vowel and voiced consonant, including across word boundaries;
	-- may be fed by previous rule
	text = rsub(text, "(" .. V .. stress_c .. "*%.?)s(" .. wordsep_c .. "*h?[" .. vowel .. voiced_cons .. "])", "%1z%2")
	-- z before voiceless consonant, e.g. [[Nazca]]; c and q already removed
	text = rsub(text, "z(" .. wordsep_c .. "*[çfkpsʃt])", "%1s%2")
	if style == "rio" or not brazil then
		-- Rio or Portugal; s/z before consonant (including across word boundaries) or end of utterance -> ʃ/ʒ
		local shibilant = {["s"] = "ʃ", ["z"] = "j"}
		text = rsub(text, "([sz])(##)", function(sz, after) return shibilant[sz] .. after end)
		text = rsub(text, "([sz])(" .. wordsep_c .. "*" .. C_NOT_H .. ")",
			function(sz, after) return shibilant[sz] .. after end)
	end
	text = rsub(text, "ç", "s")
	text = rsub(text, "j", "ʒ")
	-- Reduce identical sibilants, including across word boundaries.
	text = rsub(text, "([szʃʒ])(" .. wordsep_c .. "*)(%1)", "%2%1")
	if style == "rio" then
		-- Also reduce shibilant + sibilant ([[descer]], [[as]] [[zonas]]); not in Portugal.
		text = rsub(text, "ʃ(" .. wordsep_c .. "*s)", "%2")
		text = rsub(text, "ʒ(" .. wordsep_c .. "*z)", "%2")
	end

	-- N/M from double n/m
	text = rsub(text, "[NM]", {["N"] = "n", ["M"] = "m"})

	-- r
	-- Double rr -> ʁ already handled above.
	-- Initial r or l/n/s/z + r -> strong r (ʁ).
	text = rsub(text, "([#" .. TILDE .. "lszʃʒ]%.?)r", "%1ʁ")
	if brazil then
		-- Coda r before vowel in verbs is /(ɾ)/. FIXME: Verify this.
		text = rsub(text, "([aɛei]ˈ)r(#" .. wordsep_c .. "*h?" .. V .. ")", "%1(ɾ)%2")
		-- Coda r before vowel is /ɾ/.
		text = rsub(text, "r(" .. C .. "*[.#]" .. wordsep_c .. "*h?" .. V .. ")", "%1ɾ%2")
	end
	-- Word-final r in Brazil in verbs (not [[pôr]]) is usually dropped. Use a spelling like 'marh' for [[mar]]
	-- to prevent this.
	if style == "sp" then
		text = rsub(text, "([aɛei]ˈ)r#", "%1(ɾ)#")
	elseif brazil then
		text = rsub(text, "([aɛei]ˈ)r#", "%1(ʁ)#")
		-- Coda r outside of São Paulo is /ʁ/.
		text = rsub(text, "r(" .. C .. "*[.#])", "ʁ%1")
	end
	-- All other r -> /ɾ/.
	text = rsub(text, "r", "ɾ")
	if brazil and phonetic then
		-- "Strong" ʁ is [ɦ] in much of Brazil, [ʁ] in Rio. Use R as a temporary symbol.
		text = rsub(text, "ʁ(" .. wordsep_c .. "*[" .. voiced_cons .. "])", style == "rio" and "R" or "ɦ")
		-- "Strong" ʁ is [h] in much of Brazil, [χ] in Rio.
		-- Use H because later we remove all <h>.
		text = rsub(text, "ʁ", style == "rio" and "χ" or "H")
		text = rsub(text, "R", "ʁ")
	end

	if style == "lisbon" then
		-- In Lisbon, lower e -> ɐ before i in <ei>.
		text = rsub(text, "e(" .. accent_c .. "*i)", "ɐ%1")
		-- In Lisbon, lower e -> ɐ before j, including when nasalized.
		text = rsub(text, "e(" .. accent_c .. "*%.?y)", "ɐ%1")
		-- In Lisbon, lower e -> ɐ(j) before other palatals.
		text = rsub(text, "e(" .. stress_c .. "*)(%.?[ʒʃɲʎ])", phonetic and "ɐ%1(ɪ̯)%2" or "ɐ%1(j)%2")
	end

	-- Glides. This must precede coda l -> w in Brazil, because <ol> /ow/ cannot be reduced to /o/.
	-- ou -> o(w) before conversion of remaining diphthongs to vowel-glide combinations so <ow> can be used to
	-- indicate a non-reducible glide.
	text = rsub(text, "o(" .. accent_c .. "*)u", phonetic and "o%1(ʊ̯)" or "o%1(w)")
	local vowel_termination_to_glide = phonetic and {["i"] = "ɪ̯", ["u"] = "ʊ̯"} or {["i"] = "y", ["u"] = "w"}
	-- i/u as second part of diphthong becomes glide.
	text = rsub(text, "(" .. V .. accent_c .. "*" .. ")([iu])",
		function(v1, v2) return v1 .. vowel_termination_to_glide[v2] end)
	text = rsub(text, "y", "j")
	text = rsub(text, "Y", phonetic and "(ɪ̯)" or "(j)") -- epenthesized in [[faz]], [[tres]], etc.

	-- l
	if brazil then
		-- Coda l -> /w/ in Brazil.
		text = rsub(text, "l(" .. C .. "*[.#])", "w%1")
	elseif phonetic then
		-- Coda l -> [ɫ] in Portugal.
		text = rsub(text, "l(" .. C .. "*[.#])", "ɫ%1")
	end

	-- nh
	if brazil and phonetic then
		-- [[unha]] pronounced [ˈũ.j̃ɐ]; nasalization of previous vowel handled above.
		-- But initial nh- e.g. [[nhaca]], [[nheengatu]], [[nhoque]] is [ɲ].
		text = rsub(text, "([^#])ɲ", "%1j" .. TILDE)
	end

	-- Stop consonants.
	if brazil then
		-- Palatalize t/d + i -> affricates in Brazil.
		local palatalize_td = {["t"] = "t͡ʃ", ["d"] = "d͡ʒ"}
		text = rsub(text, "([td])([ij])", function(td, high_vocalic) return palatalize_td[td] .. high_vocalic end)
	elseif phonetic then
		-- Fricativize voiced stops in Portugal when not utterance-initial or after a nasal; also not in /ld/.
		-- Easiest way to do this is to convert all voiced stops to fricative and then back to stop in the
		-- appropriate contexts.
		local fricativize_stop = { ["b"] = "β", ["d"] = "ð", ["g"] = "ɣ" }
		local occlude_fricative = { ["β"] = "b", ["ð"] = "d", ["ɣ"] = "g" }
		text = rsub(text, "[bdg]", fricativize_stop)
		text = rsub(text, "##([βðɣ])", function(bdg) return "##" .. occlude_fricative[bdg] end)
		text = rsub(text, "(" .. TILDE .. "%.?)([βðɣ])", function(before, bdg) return before .. occlude_fricative[bdg] end)
		text = rsub(text, "([lɫ]%.?)ð", "%1d")
	end
	text = rsub(text, "g", "ɡ") -- U+0261 LATIN SMALL LETTER SCRIPT G
	text = rsub(text, "tʃ", "t͡ʃ")
	text = rsub(text, "dʒ", "d͡ʒ")
	text = rsub(text, "h", "")
	text = rsub(text, "H", "h")

	-- Stress marks.
	-- Change # in the middle of a word (words ending in -mente/-zinho) back to period.
	text = rsub_repeatedly(text, "([^ #])#([^ #])", "%1.%2")
	-- Move IPA stress marks to the beginning of the syllable.
	text = rsub_repeatedly(text, "([#.])([^#.]*)(" .. ipa_stress_c .. ")", "%1%3%2")
	-- Suppress syllable mark before IPA stress indicator.
	text = rsub(text, "%.(" .. ipa_stress_c .. ")", "%1")
	-- Make all primary stresses but the last one in a given word be secondary. May be fed by the first rule above.
	text = rsub_repeatedly(text, "ˈ([^ #]+)ˈ", "ˌ%1ˈ")

	-- Remove # symbols at word/text boundaries, as well as _ to force separate interpretation, and recompose.
	text = rsub(text, "[#_]", "")
	text = mw.ustring.toNFC(text)

	return text
end

-- For bot usage; {{#invoke:pt-pronunc|IPA_string|SPELLING|style=STYLE|phonetic=PHONETIC}}
-- where
--
--   1. SPELLING is the word or respelling to generate pronunciation for;
--   2. required parameter style= indicates the pronunciation style to generate
--      (e.g. "rio" for Rio/Carioca pronunciation, "lisbon" for Lisbon pronunciation;
--      see the comment above export.IPA() above for the full list);
--   3. phonetic=1 specifies to generate the phonetic rather than phonemic pronunciation;
function export.IPA_string(frame)
	local iparams = {
		[1] = {},
		["style"] = {required = true},
		["phonetic"] = {type = "boolean"},
	}
	local iargs = require("Module:parameters").process(frame.args, iparams)
	return export.IPA(iargs[1], iargs.style, iargs.phonetic)
end


function export.express_styles(inputs, args_style)
	local phonetic = {}
	local phonemic_phonetic = {}
	local expressed_styles = {}

	local function dostyle(style)
		phonetic[style] = {}
		phonemic_phonetic[style] = {}
		for _, val in ipairs(inputs[style]) do
			local phonem = export.IPA(val, style, false)
			local phonet = export.IPA(val, style, true)
			table.insert(phonetic[style], phonet)
			table.insert(phonemic_phonetic[style], {phonemic=phonem, phonetic=phonet})
		end
	end

	local function all_available(styles)
		local available_styles = {}
		for _, style in ipairs(styles) do
			if phonetic[style] then
				table.insert(available_styles, style)
			end
		end
		return available_styles
	end

	local function express_style(hidden_tag, tag, styles)
		if hidden_tag == true then
			hidden_tag = tag
		end
		if type(styles) == "string" then
			styles = {styles}
		end
		styles = all_available(styles)
		if #styles == 0 then
			return
		end
		local style = styles[1]

		-- If style specified, make sure it matches the requested style.
		local style_matches
		if not args_style then
			style_matches = true
		else
			local or_styles = rsplit(args_style, "%s*,%s*")
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
					for _, part in ipairs(styles) do
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

		local new_style = {
			tag = tag,
			represented_styles = styles,
			phonemic_phonetic = phonemic_phonetic[style],
		}
		for _, hidden_tag_style in ipairs(expressed_styles) do
			if hidden_tag_style.tag == hidden_tag then
				table.insert(hidden_tag_style.styles, new_style)
				return
			end
		end
		table.insert(expressed_styles, {
			tag = hidden_tag,
			styles = {new_style},
		})
	end

	for style, _ in pairs(inputs) do
		dostyle(style)
	end

	local function diff(style1, style2)
		if not phonetic[style1] or not phonetic[style2] then
			return true
		end
		return not m_table.deepEqualsList(phonetic[style1], phonetic[style2])
	end
	local rio_sp_different = diff("rio", "sp")
	local lisbon_cpt_different = diff("lisbon", "cpt")
	local sp_lisbon_different = diff("sp", "lisbon")
	local rio_lisbon_different = diff("rio", "lisbon")
	local rio_cpt_different = diff("rio", "cpt")

	if not sp_lisbon_different and not rio_sp_different and not lisbon_cpt_different then
		-- All the same
		express_style(false, false, export.all_styles)
	elseif not rio_sp_different and not lisbon_cpt_different and rio_lisbon_different then
		-- Brazil vs. Portugal
		express_style(true, "Brazil", {"rio", "sp"})
		express_style(true, "Portugal", {"lisbon", "cpt"})
	elseif not rio_lisbon_different and rio_sp_different and not lisbon_cpt_different then
		-- All except São Paulo the same (relates to coda-final -s/z, e.g. [[posto]])
		express_style(true, "Rio and Portugal", {"rio", "lisbon", "cpt"})
		express_style(true, "São Paulo", "sp")
	elseif not rio_cpt_different and not rio_sp_different and lisbon_cpt_different then
		-- All except Lisbon the same (e.g. in [[bem]])
		express_style(true, "Brazil and non-Lisbon Portugal", {"rio", "sp", "cpt"})
		express_style(true, "Lisbon", "lisbon")
	elseif rio_sp_different and not lisbon_cpt_different then
		-- São Paulo vs. Rio vs. Portugal
		express_style("Brazil", "São Paulo", "sp")
		express_style("Brazil", "Rio", "rio")
		express_style("Portugal", "Portugal", {"lisbon", "cpt"})
	elseif lisbon_cpt_different and not rio_sp_different then
		-- Brazil vs. Lisbon vs. non-Lisbon
		express_style("Brazil", "Brazil", {"rio", "sp"})
		express_style("Portugal", "Lisbon", "lisbon")
		express_style("Portugal", "non-Lisbon Portugal", "cpt")
	else
		-- all four different
		express_style("Brazil", "São Paulo", "sp")
		express_style("Portugal", "Lisbon", "lisbon")
		express_style("Brazil", "Rio", "rio")
		express_style("Portugal", "non-Lisbon Portugal", "cpt")
	end

	return expressed_styles
end


function export.show(frame)
	local params = {
		[1] = {},
		["br"] = {},
		["pt"] = {},
		["rio"] = {},
		["sp"] = {},
		["lisbon"] = {},
		["cpt"] = {},
		["pre"] = {},
		["post"] = {},
		["ref"] = {},
		["style"] = {},
		["bullets"] = {type = "number", default = 1},
	}

	local parargs = frame:getParent().args
	local args = require("Module:parameters").process(parargs, params)
	local inputs = {}
	if args.br then
		inputs.rio = args.br
		inputs.sp = args.br
	end
	if args.pt then
		inputs.lisbon = args.pt
		inputs.cpt = args.pt
	end
	for _, style in ipairs(export.all_styles) do
		if args[style] then
			inputs[style] = args[style]
		end
	end
	if not next(inputs) then
		local text = args[1] or mw.title.getCurrentTitle().text
		for _, style in ipairs(export.all_styles) do
			inputs[style] = text
		end
	end

	for style, input in pairs(inputs) do
		inputs[style] = rsplit(input, ",")
	end
	local expressed_styles = export.express_styles(inputs, args.style)

	local lines = {}

	local function format_style(tag, expressed_style, is_first)
		local pronunciations = {}
		local formatted_pronuns = {}
		for _, phonem_phonet in ipairs(expressed_style.phonemic_phonetic) do
			table.insert(pronunciations, {
				pron = "/" .. phonem_phonet.phonemic .. "/",
				qualifiers = tag and {tag} or nil,
			})
			table.insert(formatted_pronuns, "/" .. phonem_phonet.phonemic .. "/")
			table.insert(pronunciations, {
				pron = "[" .. phonem_phonet.phonetic .. "]",
			})
			table.insert(formatted_pronuns, "[" .. phonem_phonet.phonetic .. "]")
		end
		local bullet = string.rep("*", args.bullets) .. " "
		local pre = is_first and args.pre and args.pre .. " " or ""
		local post = is_first and (args.ref or "") .. (args.post and " " .. args.post or "") or ""
		local formatted = bullet .. pre .. m_IPA.format_IPA_full(lang, pronunciations) .. post
		local formatted_for_len = bullet .. pre .. "IPA(key): " .. (tag and "(" .. tag .. ") " or "") ..
			table.concat(formatted_pronuns, ", ") .. post
		return formatted, formatted_for_len
	end

	for i, style_group in ipairs(expressed_styles) do
		if #style_group.styles == 1 then
			style_group.formatted, style_group.formatted_for_len =
				format_style(style_group.styles[1].tag, style_group.styles[1], i == 1)
		else
			style_group.formatted, style_group.formatted_for_len =
				format_style(style_group.tag, style_group.styles[1], i == 1)
			for j, style in ipairs(style_group.styles) do
				style.formatted, style.formatted_for_len =
					format_style(style.tag, style, i == 1 and j == 1)
			end
		end
	end

	local maxlen = 0
	for i, style_group in ipairs(expressed_styles) do
		local this_len = ulen(style_group.formatted_for_len)
		if #style_group.styles > 1 then
			for _, style in ipairs(style_group.styles) do
				this_len = math.max(this_len, ulen(style.formatted_for_len))
			end
		end
		maxlen = math.max(maxlen, this_len)
	end

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


return export
