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
local CEDILLA = u(0x0327) -- cedilla =  ̧
local DOTOVER = u(0x0307) -- dot over =  ̇
local DOTUNDER = u(0x0323) -- dot under =  ̣

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
local wordsep = accent .. "# ."
local wordsep_c = "[" .. wordsep .. "]"
local charsep = accent .. "."
local charsep_c = "[" .. charsep .. "]"
local C = "[^" .. vowel .. wordsep .. "]" -- consonant
local C_OR_WORD_BOUNDARY = "[^" .. vowel .. accent .. ".]" -- consonant or word boundary
local T = "[^" .. vowel .. "lrɾjw" .. separator .. "]" -- obstruent or nasal
local TEMP1 = u(0xFFF0)

local unstressed_words = require("Module:table").listToSet({
	"o", "a", "os", "as", -- definite articles
	"me", "te", "se", "lhe", "lhes", "nos", "vos", -- unstressed object pronouns
	"que", -- subordinating conjunctions
	"e", -- coordinating conjunctions
	"de", "do", "da", "dos", "das", -- basic prepositions + combinations with articles
})

local unstressed_full_vowel_words = require("Module:table").listToSet({
	"um", "ums", -- single-syllable indefinite articles
	"meu", "teu", "seu", "meus", "teus", "seus", -- single-syllable possessives
	"ou", -- coordinating conjunctions
	"ao", "aos", "à", "às", -- basic prepositions + combinations with articles
	"por", "em", "com", -- other prepositions
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

-- style == one of the following:
-- "distincion-lleismo": distinción + lleísmo
-- "distincion-yeismo": distinción + yeísmo
-- "seseo-lleismo": seseo + lleísmo
-- "seseo-yeismo": seseo + yeísmo
-- "rioplatense-sheismo": Rioplatense with /ʃ/ (Buenos Aires)
-- "rioplatense-zheismo": Rioplatense with /ʒ/
function export.IPA(text, style, phonetic, do_debug)
	local origtext = text

	local function err(msg)
		error(msg .. ": " .. origtext)
	end

	local brazil = style == "rio" or style == "sao-paulo"

	text = ulower(text or mw.title.getCurrentTitle().text)
	-- decompose everything but ç and ü
	text = mw.ustring.toNFD(text)
	text = rsub(text, ".[" .. CEDILLA .. DIA .. "]", {
		["c" .. CEDILLA] = "ç",
		["u" .. DIA] = "ü",
	})
	-- There can conceivably be up to three accents on a vowel: a quality mark (acute/circumflex), a mark indicating
	-- secondary stress (grave) or tertiary stress (dotunder; i.e. no stress but no vowel reduction), and a
	-- nasalization mark (tilde). Order them as follows: quality - stress - nasalization.
	text = rsub(text, TILDE .. "([" .. AC .. CFLEX .. GR .. DOTUNDER .. "]+)", "%1" .. TILDE) -- put tilde last
	text = rsub(text, "([" .. GR .. DOTUNDER .. "])([" .. AC .. CFLEX .. "]+)", "%2%1") -- put acute/circumflex first
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

	-- Make prefixes unstressed unless they have an explicit stress marker; also make certain
	-- monosyllabic words (e.g. [[el]], [[la]], [[de]], [[en]], etc.) without stress marks be
	-- unstressed.
	local words = rsplit(text, " ")
	for i, word in ipairs(words) do
		if rfind(word, "%-$") and not rfind(word, accent_c) or unstressed_words[word] then
			-- add DOTOVER to the last vowel not the first one, or we will mess up 'que' by
			-- adding the DOTOVER after the 'u'
			words[i] = rsub(word, "^(.*" .. V .. ")", "%1" .. DOTOVER)
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

	--x
	text = rsub(text, "#x", "#ʃ") -- xérox, xilofone, etc.
	text = rsub(text, "x#", "ks#") -- xérox, córtex, etc.
	text = rsub(text, "(" .. V .. charsep_c .. "*i" .. charsep_c .. "*)x", "%1ʃ") -- baixo, peixe, etc.
	if rfind(text, "x") then
		err("x must be respelled z, ch, cs, ss or similar")
	end

	-- combinations with h; needs to precede handling of c and s, and needs to precede syllabification so that
	-- the consonant isn't divided from the following h.
	text = rsub(text, "([scln])h", {["s"]="ʃ", ["c"]="ʃ", ["n"]="ɲ", ["l"]="ʎ" })

	--c, g, q
	-- This should precede syllabification especially so that the latter isn't confused by gu, qu, gü, qü
	-- also, c -> ç before front vowel ensures that cc e.g. in [[cóccix]], [[occitano]] isn't reduced to single c.
	text = rsub(text, "c([iey])", "ç%1")
	text = rsub(text, "gü([iey])", "gw%1")
	text = rsub(text, "gu([iey])", "g%1")
	text = rsub(text, "g([iey])", "j%1")
	-- following must happen before stress assignment; [[camping]], [[doping]], [[jogging]] etc. have initial stress
	text = rsub(text, "ng([^aeiouyüwhlr])", "n%1") -- [[Bangkok]], [[angstrom]], [[tungstênio]]
	text = rsub(text, "qu([iey])", "k%1")
	text = rsub(text, "ü", "u") -- [[Bündchen]], [[hübnerita]], [[freqüentemente]], etc.
	text = rsub(text, "([gq])u", "%1w") -- [[quando]], [[guarda]], etc.
	text = rsub(text, "[cq]", "k") -- [[Qatar]], [[burqa]], [[Iraq]], etc.

	-- y -> i between non-vowels, cf. [[Itamaraty]] /i.ta.ma.ɾa.ˈt(ʃ)i/, [[Sydney]] respelled 'Sýdjney' or similar
	-- /ˈsid͡ʒ.nej/ (Brazilian). Most words with y need respelling in any case, but this may help.
	text = rsub(text, "(" .. C_OR_WORD_BOUNDARY .. ")y(" .. accent_c .. "*" .. C_OR_WORD_BOUNDARY .. ")", "%1i%2")

	-- Reduce double letters to single, except for rr and ss, which map to special single sounds. Do this before
	-- syllabification so double letters don't get divided across syllables. The case of cci, cce is handled above.
	-- [[connosco]] will need respelling 'cõnôsco' or 'con.nôsco'. Examples of words with double letters
	-- (Brazilian pronunciation):
	-- * [[Accra]] no respelling needed /ˈa.kɾɐ/;
	-- * [[Aleppo]] respelled 'Aléppo' /aˈlɛpu/;
	-- * [[buffer]] respelled 'bâffer' /ˈbɐ.feʁ/;
	-- * [[cheddar]] respelled 'chéddar' /ˈʃɛ.daʁ/;
	-- * [[Hanna]] respelled 'Ranna' /ˈʁɐ.nɐ/;
	-- * [[jazz]] respelled 'djézz' /ˈd͡ʒɛs/;
	-- * [[Minnesota]] respelled 'Mìnnessôta' /ˌmi.ne.ˈso.tɐ/;
	-- * [[nutella]] respelled 'nutélla' /nuˈtɛ.lɐ/;
	-- * [[shopping]] respeled 'shópping' /ˈʃɔ.pĩ/ or 'shóppem' /ˈʃɔ.pẽj̃/;
	-- * [[Yunnan]] no respelling needed /ju.ˈnɐ̃/.
	--
	-- Note that further processing of r and s happens after syllabification and stress assignment, because we need
	-- e.g. to know the distinction between final -s and -z to assign the stress properly.
	text = rsub(text, "rr", "ʁ")
	text = rsub(text, "ss", "ç")
	text = rsub(text, "(" .. C .. ")%1", "%1")

	-- Divide words into syllables.
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*)(" .. C .. W .. "?" .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. ")(" .. C .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. "+)(" .. C .. C .. V .. ")", "%1.%2")
	text = rsub(text, "([pbktdg])%.([lr])", ".%1%2")
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
	-- primary stresses; the first one will be converted to secondary stress down below.
	local function accent_word(word, syllables, before_mente)
		-- Check if stress already marked. We check first for primary stress before checking for tilde in case both
		-- primary stress and tilde occur, e.g. [[bênção]], [[órgão]], [[hétmã]], [[connosco]] respelled 'cõnôsco'.
		-- If handling the part before -mente, check for any stress marker and do nothing if found.
		if rfind(word, "ˈ") or before_mente and rfind(word, stress_c) then
			return
		end

		-- Check for nasal vowel marked with tilde and without non-primary stress; assign stress to the last such
		-- syllable in case there's more than one tilde, e.g. [[pãozão]]. Note, this can happen in the part before
		-- -mente, cf. [[anticristãmente]], and before -zinho, cf. [[coraçãozinho]].
		for i = #syllables,1,-1 do
			local changed
			syllables[i], changed = rsub(syllables[i], "(" .. V .. quality_c .. "*)" .. TILDE, "%1ˈ" .. TILDE)
			if changed then
				return
			end
		end

		-- Apply the default stress rule.
		local sylno
		if #syllables > 1 and (rfind(word, "[aeo]s?#") or rfind(word, "[ae]m#") or rfind(word, "[ae]ns#")) then
			sylno = #syllables - 1
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

	local words = rsplit(text, " ")
	for j, word in ipairs(words) do
		-- accentuation
		local syllables = rsplit(word, "%.")

		if rfind(word, "%.men%.te#") or rfind(word, "%.zi%.ɲo#") then
			local mente_syllables
			-- Words ends in -mente or -zinho; add primary stress to the preceding portion as if stressed
			-- (e.g. [[agitadamente]] -> 'agitádamente') unless already stressed (e.g. [[rapidamente]]
			-- respelled 'rápidamente' or `ràpidamente'). The primary stress will be converted to secondary
			-- stress further below. Essentially, we rip the word apart into two words ('mente'/'zinho' and
			-- the preceding portion) and stress each one independently. Note that the effect of adding a
			-- primary stress will also be to cause an error if stressed 'e' or 'o' is not properly marked
			-- as é/ê or ó/ô; cf. [[certamente]], which must be respelled 'cértamente', and [[posteriormente]],
			-- which must be respelled 'posteriôrmente', just as with [[certa]] and [[posterior]]. To
			-- prevent this happening, you can add an accent to -mente or -zinho, e.g. [[dormente]] respelled
			-- 'dormênte', [[vizinho]] respelled 'vizínho'.
			mente_syllables = {}
			mente_syllables[2] = table.remove(syllables)
			mente_syllables[1] = table.remove(syllables)
			accent_word(table.concat(syllables, "."), syllables, "before mente")
			accent_word(table.concat(mente_syllables, "."), mente_syllables)
			table.insert(syllables, mente_syllables[1])
			table.insert(syllables, mente_syllables[2])
		else
			accent_word(word, syllables)
		end

		-- Reconstruct the word.
		words[j] = table.concat(syllables, ".")
	end

	-- Reconstruct the text from the words.
	text = table.concat(words, " ")

	-- Vowel quality handling. First convert all a -> A, e -> E, o -> O. We will then convert A -> a/ɐ, E -> e/ɛ/ɨ,
	-- O -> o/ɔ/u depending on accent marks and context. Ultimately all vowels will be one of the nine qualities
	-- aɐeɛiɨoɔu and following each vowel will either be nothing (no stress), an IPA primary stress mark (ˈ) or an
	-- IPA secondary stress mark (ˌ), in turn possibly followed by a tilde (nasalization). After doing everything
	-- that depends on the position of stress, we will move the IPA stress marks to the beginning of the syllable.
	text = rsub(text, "[aeo]", {["a"] = "A", ["e"] = "E", ["o"] = "O"})

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
	text = rsub(text, "(" .. V .. ")(ˈ%.[mnɲ])", "%1" .. CFLEX .. "%2")
	if brazil then
		-- Primary-stressed vowel + m/n across syllable boundary gets nasalized in Brazil, cf. [[cama]], [[ano]].
		text = rsub(text, "(" .. V .. quality_c .. "*)(ˈ%.[mn])", "%1" .. TILDE .. "%2")
		-- All vowels before nh (always across syllable boundary) get circumflexed and nasalized in Brazil,
		-- cf. [[ganhar]].
		text = rsub(text, "(" .. V .. ")(%.ɲ)", "%1" .. CFLEX .. "%2")
		text = rsub(text, "(" .. V .. quality_c .. "*)(%.ɲ)", "%1" .. TILDE .. "%2")
	end

	-- Nasal diphthongs.
	local nasal_termination_to_glide = {["E"] = "y", ["O"] = "w"}
	-- In ãe, ão, the second letter represents a glide.
	text = rsub(text, "(A" .. CFLEX .. stress_c .. "*" .. TILDE .. ")([EO])",
		function(v1, v2) return v1 .. nasal_termination_to_glide[v2] end)
	-- Likewise for õe.
	text = rsub(text, "(O" .. CFLEX .. stress_c .. "*" .. TILDE .. ")E", "%1y")
	-- Final -em and -ens (stressed or not) pronounced /ẽj(s)/. (Later converted to /ɐ̃j(s)/ in Portugal.)
	text = rsub(text, "(E" .. CFLEX .. stress_c .. "*" .. TILDE .. ")(s?#)", "%1y%2")

	-- Oral diphthongs.
	local vowel_termination_to_glide = {["i"] = "y", ["u"] = "w"}
	-- i/u as second part of diphthong becomes glide.
	text = rsub(text, "(" .. V .. accent_c .. "*" .. ")([iu])",
		function(v1, v2) return v1 .. vowel_termination_to_glide[v2] end)
	-- ei, eu, oi, ou -> êi, êu, ôi, ôu
	text = rsub(text, "([EO])(" .. stress_c .. "*[ywY])", "%1" .. CFLEX .. "%2")

	-- Convert A/E/O as appropriate when followed by a secondary or tertiary stress marker. If a quality is given,
	-- it takes precedence; otherwise, act as if an acute accent were given.
	text = rsub(text, "([AEO])(" .. non_primary_stress_c .. ")", "%1" .. AC .. "%2")

	-- Unstressed syllables.
	if brazil then
		-- Final unstressed -e, -o, -a -> /i/ /u/ /ɐ/
		local brazil_final_vowel = {["A"] = "ɐ", ["E"] = "i", ["O"] = "u"}
		text = rsub(text, "([AEO])#", function(v) return brazil_final_vowel[v] .. "#" end)
		-- Remaining unstressed a, e, o without quality mark -> /a/ /e/ /o/.
		local brazil_unstressed_vowel = {["A"] = "a", ["E"] = "e", ["O"] = "o"}
		text = rsub(text, "([AEO])([^" .. accent .. "])",
			function(v, after) return brazil_unstressed_vowel[v] .. after end)
	else
		-- Initial unmarked unstressed e- -> /i/
		text = rsub(text, "#E([^" .. accent .. "])", "#i%1")
		-- All other unmarked unstressed -e, -o, -a -> /ɨ/ /u/ /ɐ/
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

	-- s, z
	-- (1) s between vowels or between vowel and voiced consonant
	text = rsub(text, "(" .. V .. charsep_c .. "*)s(" .. wordsep_c .. "*h?[" .. vowel .. "bdgjlʎmnɲŋrɾʁvwyzʒ])", "%1z%2")
	-- (2) z before voiceless consonant; c and q already removed
	text = rsub(text, "(" .. V .. charsep_c .. "*)z(" .. wordsep_c .. "*[çfkpsʃt])", "%1s%2")
	-- (3) phrase final z
	text = rsub(text, "z##", "s")

	-- r
	text = rsub(text, "([#lnsz])r", "%1ʁ")
	if style == "rio" then
		text = rsub(text, "([aei])r#", "%1(ʁ)")
	elif style == "sao-paulo" then
		text = rsub(text, "([aei])r#", "%1(ɾ)")
	end
	if style == "rio" then
		text = rsub(text, "r([^" .. V .. ")", "ʁ%1")
	end
	text = rsub(text, "r", "ɾ")

	text = rsub(text, "ç", "s")
	text = rsub(text, "ç", "s")
	text = rsub(text, "[cjñrvy]",
		{["c"]="k", ["j"]="x", ["ñ"]="ɲ", ["r"]="ɾ", ["v"]="b" })

	-- voiceless stop to voiced before obstruent or nasal; but intercept -ts-, -tz-
	local voice_stop = { ["p"] = "b", ["t"] = "d", ["k"] = "g" }
	text = rsub(text, "t(" .. separator_c .. "*[szθ])", "!%1") -- temporary symbol
	text = rsub(text, "([ptk])(" .. separator_c .. "*" .. T .. ")",
		function(stop, after) return voice_stop[stop] .. after end)
	text = rsub(text, "!", "t")

	text = rsub(text, "n([# .]*[bpm])", "m%1")

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
		local voiced = "mnɲbdɟgʎ"
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
		local stop_to_fricative = {["b"] = "β", ["d"] = "ð", ["ɟ"] = "ʝ", ["g"] = "ɣ"}
		local fricative_to_stop = {["β"] = "b", ["ð"] = "d", ["ʝ"] = "ɟ", ["ɣ"] = "g"}
		text = rsub(text, "[bdɟg]", stop_to_fricative)
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
			["k"] = velar, ["x"] = velar, ["g"] = velar,
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

	-- remove silent "h" and convert fake symbols to real ones
	local final_conversions =  {
		["g"] = "ɡ",  -- U+0261 LATIN SMALL LETTER SCRIPT G
		["h"] = "",   -- silent "h"
		["ħ"] = "h",  -- fake aspirated "h" to real "h"
		["ĉ"] = "t͡ʃ", -- fake "ch" to real "ch"
		["ɟ"] = phonetic and "ɟ͡ʝ" or "ʝ", -- fake "y" to real "y"
	}
	text = rsub(text, "[ghħĉɟ]", final_conversions)

	-- remove # symbols at word and text boundaries
	text = rsub(text, "#", "")
	text = mw.ustring.toNFC(text)

	local ret = {
		text = text,
		distincion_different = distincion_different,
		lleismo_different = lleismo_different,
		need_rioplat = initial_hi or sheismo_different,
		sheismo_different = sheismo_different,
	}
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
		["debug"] = {type = "boolean"},
	}
	local iargs = require("Module:parameters").process(frame.args, iparams)
	local retval = export.IPA(iargs[1], iargs.style, iargs.phonetic, iargs.debug)
	return retval.text .. (retval.debug and " ||| " .. retval.debug or "")
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
	local phonemic = {}
	local phonetic = {}
	local expressed_styles = {}
	local text = args[1] or mw.title.getCurrentTitle().text
	local need_rioplat
	local function dostyle(style)
		phonemic[style] = export.IPA(text, style, false, args.debug)
		phonetic[style] = export.IPA(text, style, true, args.debug)
	end
	local function express_style(hidden_tag, tag, style, matching_styles)
		matching_styles = matching_styles or style
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

		if not phonemic[style] then
			dostyle(style)
		end
		local new_style = {
			tag = tag,
			phonemic = phonemic[style],
			phonetic = phonetic[style],
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
	dostyle("distincion-lleismo")
	local distincion_different = phonemic["distincion-lleismo"].distincion_different
	local lleismo_different = phonemic["distincion-lleismo"].lleismo_different
	need_rioplat = phonemic["distincion-lleismo"].need_rioplat
	local sheismo_different = phonemic["distincion-lleismo"].sheismo_different
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

	-- If only one style group, don't indicate the style.
	if #expressed_styles == 1 then
		expressed_styles[1].tag = false
		if #expressed_styles[1].styles == 1 then
			expressed_styles[1].styles[1].tag = false
		end
	end

	local lines = {}

	local function format_style(tag, expressed_style, is_first)
		local pronunciations = {}
		table.insert(pronunciations, {
			pron = "/" .. expressed_style.phonemic.text .. "/",
			qualifiers = tag and {tag} or nil,
		})
		table.insert(pronunciations, {
			pron = "[" .. expressed_style.phonetic.text .. "]",
		})
		local bullet = string.rep("*", args.bullets) .. " "
		local pre = is_first and args.pre and args.pre .. " " or ""
		local post = is_first and (args.ref or "") .. (args.post and " " .. args.post or "") or ""
		local formatted = bullet .. pre .. m_IPA.format_IPA_full(lang, pronunciations) .. post
		local formatted_for_len = bullet .. pre .. "IPA(key): " .. (tag and "(" .. tag .. ") " or "") ..
			"/" .. expressed_style.phonemic.text .. "/, [" .. expressed_style.phonetic.text .. "]" .. post
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





































local export = {}

local gsub = mw.ustring.gsub
local match = mw.ustring.match
local gmatch = mw.ustring.gmatch
local split = mw.text.split

local tokens = {
	"a", "á", "â", "ã", "à",
	"b",
	"c", "ç", "ch",
	"d",
	"e", "é", "ê",
	"f",
	"g", "gu",
	"h",
	"i", "í",
	"j",
	"k",
	"l", "lh",
	"m",
	"n", "nh",
	"ó", "ô", "õ",
	"p",
	"qu",
	"r", "rr",
	"s", "ss",
	"t",
	"u", "ú",
	"v",
	"w",
	"x",
	"y",
	"z",
}

local digraphs = {
	"ch", "gu", "lh", "nh", "qu", "rr", "ss",
}

local function spelling_to_IPA(word)
	word = gsub(word,"ch","ʃ")
	word = gsub(word,"lh","ʎ")
	word = gsub(word,"nh","ɲ")
	word = gsub(word,"rr","ʁ")
	
	-- ç vs s vs ss
	word = gsub(word,"([aáâãàeéêiíoóôõuú])s([aáâãàeéêiíoóôõuú])","%1z%2")
	word = gsub(word,"ss","s")
	word = gsub(word,"ç","s")
	
	-- c vs g vs qu vs gu
	word = gsub(word,"([cgq]u?)(.?)",function (a,b)
		if a=="cu" then
			return "ku"..b
		end
		if a=="c" then
			if match(b,"[eéêií]") then
				return "s"..b
			else
				return "k"..b
			end
		elseif a=="g" then
			if match(b,"[eéêií]") then
				return "ʒ"..b
			else
				return "ɡ"..b -- U+0261 LATIN SMALL LETTER SCRIPT G
			end
		elseif a=="qu" then
			if match(b,"[eéêií]") then
				return "k"..b
			else
				return "kw"..b
			end
		elseif a=="gu" then
			if match(b,"[eéêií]") then
				return "ɡ"..b -- U+0261 LATIN SMALL LETTER SCRIPT G
			else
				return "ɡw"..b -- U+0261 LATIN SMALL LETTER SCRIPT G
			end
		else
			error("q not followed by u")
		end
	end)
	
	word = gsub(word,"j","ʒ")
	
	-- extract semivowels from diphthongs
	word = gsub(word,"([aáâãàeéêiíoóôõuú])i","%1j")
	word = gsub(word,"([aáâãàeéêiíoóôõuú])u","%1w")
	word = gsub(word,"u([aáâãàeéêiíoóôõuú])i","w%1")
	word = gsub(word,"(^[áâãàéêíóôõú])(%.+)i([jlmnrwz][s]?)$","%1%2í%3")
	word = gsub(word,"(^[áâãàéêíóôõú])(%.+)i([aeo][s]?)$","%1%2í%3")
	word = gsub(word,"(^[áâãàéêíóôõú])(%.+)i([jlmnrwz][s]?)$","%1%2í%3")
	word = gsub(word,"(^[áâãàéêíóôõú])(%.+)e([jlmnrwz][s]?)$","%1%2ê%3")
	word = gsub(word,"(^[áâãàéêíóôõú])(%.+)e([j]?[aeo][s]?)$","%1%2ê%3")
	
	-- syllabification
	word = gsub(word,"([aáâãàeéêiíoóôõuú])([^aáâãàeéêiíoóôõuú])","%1.%2")
	word = gsub(word,"([aáâãàeéêiíoóôõuú])([aáâãàeéêiíoóôõuú])","%1.%2")
	word = gsub(word,"([aáâãàeéêiíoóôõuú])%.([^aáâãàeéêiíoóôõuú.])([^aáâãàeéêiíoóôõuú.])","%1%2.%3")
	word = gsub(word,"%.([^aáâãàeéêiíoóôõuú.]+)$","%1")
	word = gsub(word,"([pbctdɡ])%.([lr])",".%1%2")
	
	-- r vs rr
	word = gsub(word,"%.r",".ʁ")
	word = gsub(word,"^r",".ʁ")
	word = gsub(word,"r","ɾ")
	
	-- s vs x vs z (/s/ vs /z/ vs /ʃ/ vs /ʒ/)
	word = gsub(word,"[szx](%.[ckpst])","ʃ%1")
	word = gsub(word,"[szx]$","ʃ")
	word = gsub(word,"[szx](%..)","ʒ%1")
	word = gsub(word,"x","ʃ")
	
	-- stress
	-- All words that I have found that contain more than one
	-- occurrence of [áâãeéêiíóôõú] are either acute+nasal or
	-- circumflex+nasal, with the nasal being ão (or õe)
	if match(word,"[áâãeéêiíóôõú]") then
		if match(word,"[áéíóúâêô]") then
			word = gsub(word,"%.([^.]+[áéíóúâêô])","ˈ%1")
		else
			word = gsub(word,"%.([^.]+[ãõ])","ˈ%1")
		end
	else
		if match(word,"[iu][sm]?$") or match(word,"[^aáâãàeéêiíoóôõuúms]$") then
			word = gsub(word,"%.([^.]+)$",function(a)
				return "ˈ" .. gsub(a,"[aeiou]",{
					["a"] = "á",
					["e"] = "é",
					["i"] = "í",
					["o"] = "ó",
					["u"] = "ú",
				})
			end)
		else
			word = gsub(word,"%.([^.]+%.[^.]+)$","ˈ%1")
		end
	end
	
	-- ão and õe
	word = gsub(word,"ão","ɐ̃w̃")
	word = gsub(word,"õe","õȷ̃")
	
	-- nasals
	word = gsub(word,"([aeéê])m$",{
		["a"] = "ɐ̃w̃",
		["e"] = "ɐ̃j̃",
		["é"] = "ɐ̃j̃",
		["ê"] = "ɐ̃j̃",
	})
	word = gsub(word,"[eé]mʃ$","ɐ̃j̃ʃ")
	word = gsub(word,"([aâeêiíoôuú])[mn]",{
		["a"] = "ɐ̃",
		["â"] = "ɐ̃",
		["e"] = "ẽ",
		["ê"] = "ẽ",
		["i"] = "ĩ",
		["í"] = "ĩ",
		["o"] = "õ",
		["ô"] = "õ",
		["u"] = "ũ",
		["ú"] = "ũ",
	})
	
	-- vowels
	word = gsub(word,"o$","u")
	word = gsub(word,"[aáâãàeéêiíoóôuú]",{
		["a"] = "ɐ",
		["á"] = "a",
		["â"] = "ɐ",
		["ã"] = "ɐ̃",
		["à"] = "a",
		["e"] = "ɨ",
		["é"] = "ɛ",
		["ê"] = "e",
		["i"] = "i",
		["í"] = "i",
		["o"] = "o",
		["ó"] = "ɔ",
		["ô"] = "o",
		["u"] = "u",
		["ú"] = "u",
	})
	
	word = gsub(word,"l%.","ɫ")
	word = gsub(word,"l$","ɫ")
	
	return word
end

function export.show(frame)
	local text = frame.args[1]
	text = gsub(text,"-","")
	text = split(text," ")
	for i,val in ipairs(text) do
		text[i] = spelling_to_IPA(val)
	end
	return table.concat(text," ")
end

return export
