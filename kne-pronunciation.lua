-- Forked from [[Module:tl-pronunciation]] by Yivan000.
-- This is still a complete fork, without any Kankanaey-specific changes.
-- TODO: Check if stresses and other particularities are different in Kankanaey

--    Based on [[Module:es-pronunc]] by Benwing2.
--    Adaptation by TagaSanPedroAko, Improved by Ysrael214.
--    Partly rewritten by Benwing2, merging code from [[Module:es-pronunc]] back into this module; {{tl-pr}} restructured
--      to take inline modifiers, like {{es-pr}}.

local export = {}

--[==[
FIXME:

1. Review should_generate_rhyme_from_respelling(), e.g. the check for CFLEX. [DONE; use MACRON]
2. Update align_syllabification_to_spelling(). [DONE]
3. Look into how syllabify_from_spelling() works; needs rewriting. [DONE BUT COULD USE MORE WORK]
4. Delete old {{tl-pr}} code when new code ready. [DONE]
5. Group by accent in adjacent lines, and display accent on a separate line if more than one line with that accent.
   [DONE]
6. Restore 'Tagalog terms with malumi pronunciation' and similar rhyme categories; also restore 'Tagalog terms with
   syllabification not matching pagename' (formerly 'Tagalog terms with hyphenation errors'). [DONE]
7. Use "syllabification" everywhere internally in place of "hyphenation" and in abbrevs. [DONE]
8. Change handling of forcing dot. Currently t.s forces /ts/ instead of /tʃ/ (and interferes with syllabification);
   this should be t_s. [DONE]
8b. Currently you have to write si..yasa with double dot to get /sijasa/ not /ʃasa/; this should be single dot, and no
    dot should indicate the palatalized pronunciation.
9. If there are auto-generated pronunciations, they should go on a separate line. If there are other pronunciations
   on the line, indent the auto-generated ones on a separate line under the pronunciation line; otherwise, at the same
   bullet level. Good test cases: [[F]], [[General Mariano Alvarez]]. [DONE]
10. Fix bug involving [[Evangelista]] respelled 'Evanghelista' and [[barangay]] respelled 'baranggay'; should recognize
    for syllabification purposes. [DONE]
11. Rhymes should be displayed even if multiword based on the last word, but just not categorize. [DONE]
12. DOTOVER should be used to indicate an unstressed word or suffix, e.g. -ȧ to indicate unstressed [[a]] phoneme.
    [NOT DONE; USE MACRON, ALREADY SUPPORTED]
13. Move hyphen-restoring code in syllabify_from_spelling() to align_syllabification_to_spelling().
14. Allow h against nothing esp. at beginning of word e.g. in [[Hermogenes]] respelled 'Ermógenes' or 'Ermogenes'.
    Also [[adhan]] respelled 'adán' syllabified 'a.dhan', [[Abdurahman]] respelled 'Abduramán' syllabified
	'Ab.du.rah.man', [[Agatha]] respelled 'Ágata' syllabified 'A.ga.tha'. [DONE]
15. Unstressed words should not have rhymes, e.g. 'ba' is a letter that isn't normally stressed but is getting a rhyme.
16. Shouldn't be necessary to write raw: before /.../.
17. Allow w against u e.g. [[Zulueta]] respelled 'Zulweta', [[Aguado]] respelled 'agwado', syllabified 'Ag.ua.do' (and y
    against i). [DONE]
18. Allow l against ll e.g. [[Allan]] respelled 'Alan', syllabified 'A.llan', likewise [[Allahu akbar]] respelled
    'Alahu akbár' syllabified 'A.lla.hu ak.bar'. [DONE]
19. Allow s against ss e.g. [[assalamu alaikum]] respelled 'asalamu alaikum', syllabified 'a.ssa.la.mu a.lai.kum'.
    [DONE]
20. Allow f against ff e.g. [[Jefferson]] respelled 'Jéferson', syllabified 'Je.ffer.son' and [[Gaffud]] respelled
    'Gafud', syllabified 'Ga.ffud'. [DONE]
21. Allow m against mm e.g. [[Gemma]] respelled 'Jema', syllabified 'Ge.mma', and [[ummah]] respelled 'uma', syllabified
    'u.mmah', and [[nagko-comment]] respelled 'nagko-coment', syllabified 'nag.ko-co.mment'. [DONE]
22. Allow n against nn e.g. [[sunna]] respelled 'suna', syllabified 'su.nna', and [[Hannah]] respelled 'Hana',
    syllabified 'Ha.nnah'. [DONE]
23. Allow b against bb e.g. [[Abby]] respelled 'aby', syllabified 'A.bby'. [DONE]
24. [[Buendia]] respelled 'Buendía' syllabifies wrong (as 'Bu.end.ia' when it should be 'Bu.en.di.a'). Likewise
    [[María]] (as Mar.ia instead of Ma.ri.a). [DONE]
25. [[Arguelles]] respelled 'Argu.elles' generates correct pronunciation with /gw/ but incorrect syllabification
    'Ar.guel.les' instead of 'Ar.gu.el.les'. [DONE]
26. [[Caguiat]] respelled 'Caguiát' generates correct pronunciation with /gj/ but incorrect syllabification 'Ca.gui.at'
    instead of 'Ca.guiat' ("hyphenation") or maybe 'Cagu.iat'. [DONE]
27. Allow 7 against ' e.g. [[Jumu'ah]] respelled 'Jumu7á' with syllabificaiton 'Ju.mu.'ah'. [DONE]
28. Allow f against ph e.g. [[Sophia]] respelled 'Sofi.a' with syllabificaiton 'So.phi.a'. [NOT DONE; ONLY TWO CASES]
29. Correctly handle [[gaan]] respelled 'ga7án', and other terms with doubled vowels in them against a glottal stop.
    [DONE]
30. Allow syllabification when only some words have vowels, e.g. [[bawian ng buhay]]. [DONE]
31. Don't treat periods in pagename (esp. when occurring at the end of a word) as syllable breaks.
]==]

local force_cat = false -- enable for testing

local m_IPA = require("Module:IPA")
local m_str_utils = require("Module:string utilities")
local m_table = require("Module:table")
local accent_qualifier_module = "Module:accent qualifier"
local audio_module = "Module:audio"
local headword_data_module = "Module:headword/data"
local hyphenation_module = "Module:hyphenation"
local labels_module = "Module:labels"
local parse_utilities_module = "Module:parse utilities"
local rhymes_module = "Module:rhymes"
local set_utilities_module = "Module:set utilities"

local lang = require("Module:languages").getByCode("kne")

local maxn = table.maxn
local rfind = m_str_utils.find
local rsubn = m_str_utils.gsub
local rsplit = m_str_utils.split
local toNFC = mw.ustring.toNFC
local toNFD = mw.ustring.toNFD
local trim = mw.text.trim
local u = m_str_utils.char
local ulen = m_str_utils.len
local ulower = m_str_utils.lower

local AC = u(0x0301) -- acute =  ́
local GR = u(0x0300) -- grave =  ̀
local CFLEX = u(0x0302) -- circumflex =  ̂
local TILDE = u(0x0303) -- tilde =  ̃
local DIA = u(0x0308) -- diaeresis =  ̈
local MACRON = u(0x0304) -- macron =  ̄
local DOTOVER = u(0x0307) -- dot over =  ̇

local vowel = "aeëəiou" -- vowel
local V = "[" .. vowel .. "]"
local NV = "[^" .. vowel .. "]"
local accent = AC .. GR .. CFLEX .. MACRON
local accent_c = "[" .. accent .. "]"
local ipa_stress = "ˈˌ"
local ipa_stress_c = "[" .. ipa_stress .. "]"
local separator = accent .. ipa_stress .. "# ."
local C = "[^" .. vowel .. separator .. "]" -- consonant

local unstressed_words = m_table.listToSet {
	-- case markers; "nang" here is for written "ng", but can also work with nang as in the contraction na'ng and the
	-- conjunction "nang"
	"ang", "sa", "nang", "si", "ni", "kay",
	-- letter names (abakada and modern Filipino)
	"a", "ar", "ay", "ba", "bi", "da", "di", "e", "ef", "eks", "dyi", "i",  "jey", "key", "em", "ma", "en", "pi", "ra",
	"es", "ta", "ti", "u", "vi", "wa", "way", "ya", "yu", "zey", "zi",
	"ko", "mo", "ka",--single-syllable personal pronouns

	-- in some Spanish-derived terms and names; also de- prefix in compound words
	"de", "del", "el", "la", "las", "los", "y"
}
local unstressed_affixes = m_table.listToSet {
	-- NOTE: prefixes here aren't currently used with prefixes themselves because they are all assumed unstressed
	-- in the absence of an explicit accent marker.
	"mang-", "nang-", "man-", "nan-", "-om-", "-inom-", "-inm-", "-ën", "-en", "-in-",
	"-an", "in-", "ma-", "na-", "-in", "ini-", "mai-", "nai-"
}

-- local nang_macron = "na" .. MACRON .. "ng"
-- local manga_acute = "manga" .. AC
local special_words = {
	-- ["ng"] = nang_macron, ["ng̃"] = nang_macron, ["ñ̃g"] = nang_macron,
	-- ["mga"] = manga_acute, ["mg̃a"] = manga_acute,
	["y"] = "i" .. MACRON -- Spanish [[y]]
}

local function track(page)
	require("Module:debug/track")("kne-pronunciation/" .. page)
	return true
end

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

-- Combine two sets of qualifiers, either of which may be nil or a list of qualifiers. Remove duplicate qualifiers.
-- Return value is nil or a list of qualifiers.
local function combine_qualifiers(qual1, qual2)
	if not qual1 then
		return qual2
	end
	if not qual2 then
		return qual1
	end
	local qualifiers = m_table.deepcopy(qual1)
	for _, qual in ipairs(qual2) do
		m_table.insertIfNot(qualifiers, qual)
	end
	return qualifiers
end


local function decompose(text, recompose_e_dia)
	-- decompose everything but ñ and ü
	text = toNFD(text)
	text = rsub(text, ".[" .. TILDE .. DIA .. "]", {
		["n" .. TILDE] = "ñ",
		["N" .. TILDE] = "Ñ",
		["u" .. DIA] = "ü",
		["U" .. DIA] = "Ü",
	})
	if recompose_e_dia then
		text = rsub(text, ".[" .. DIA .. "]", {
			["e" .. DIA] = "ë",
			["E" .. DIA] = "Ë",
		})
	end
	return text
end

local function remove_accents(str)
	str = decompose(str, "recompose e-dia")
	str = rsub(str, "(.)" .. accent_c, "%1")
	return str
end

local function split_on_comma(term)
	if term:find(",%s") then
		return require(parse_utilities_module).split_on_comma(term)
	else
		return rsplit(term, ",")
	end
end

-- ĵ, ɟ and ĉ are used internally to represent [d͡ʒ], [j] and [t͡ʃ]
--

function export.IPA(text, include_phonemic_syllable_boundaries)
	local debug = {}

	text = ulower(text)
	text = decompose(text, "recompose e-dia")
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

	-- Make prefixes unstressed unless they have an explicit stress marker; also make certain monosyllabic words (e.g.
	-- [[ang]], [[ng]], [[si]], [[na]], etc.) without stress marks be unstressed. We want to do this in most cases as
	-- well with hyphenated compounds, e.g. [[bato-sa-rinyon]] and [[kalahatian-ng-buwan]]. To do this, we use a
	-- capturing split on space or hyphen; in this situation, the actual words are at odd positions, and the separators
	-- (always a single space or hyphen) are at even positions.
	local words = rsplit(text, "([ %-])")
	local function make_unstressed(word)
		-- add macron to the last vowel not the first one, in case of affixes with qui/que/gui/gue (which don't
		-- currently exist)
		return rsub(word, "^(.*" .. V .. ")", "%1" .. MACRON)
	end
	local function signal_no_initial_glottal_stop(word)
		return rsub(word, "^(" .. V .. ")", "◌%1")
	end

	for i=1, #words do
		if i % 2 == 1 then -- a word, not a hyphen or space
			if words[i - 1] == "-" and (not words[i - 2] or words[i - 2] == "" and words[i - 3] ~= "-") and
				words[i + 1] ~= "-" then
				-- a suffix
				if unstressed_affixes["-" .. words[i]] then
					words[i] = make_unstressed(words[i])
				end
				words[i] = signal_no_initial_glottal_stop(words[i])
			elseif words[i + 1] == "-" and (not words[i + 2] or words[i + 2] == "" and words[i + 3] ~= "-") and
				words[i - 1] ~= "-" then
				-- a prefix
				if not rfind(words[i], accent_c) then
					-- an unstressed prefix
					words[i] = make_unstressed(words[i])
				end
			elseif words[i + 1] == "-" and (not words[i + 2] or words[i + 2] == "" and words[i + 3] ~= "-") and
				words[i - 1] == "-" and (not words[i - 2] or words[i - 2] == "" and words[i - 3] ~= "-") then
				-- an interfix or infix
				if not rfind(words[i], accent_c) then
					-- an unstressed interfix or infix
					words[i] = make_unstressed(words[i])
				end
				words[i] = signal_no_initial_glottal_stop(words[i])
			else
				-- a space-delimited word or a word in a hyphen-delimited compound
				words[i] = special_words[words[i]] or words[i]
				if unstressed_words[words[i]] then
					words[i] = make_unstressed(words[i])
				elseif words[i + 1] == "-" and (not words[i - 1] or words[i - 1] == " ") and
					-- e.g. 'mag-' in [[mag-post]]
					unstressed_affixes[words[i] .. "-"] then
					words[i] = make_unstressed(words[i])
				end
			end
		end
		-- old code that I didn't port because I don't understand why it's being done; the purpose is to make suffixes
		-- and infixes with explicit initial glottal stop be unstressed, which seems a weird exception
		-- words[i] = rsub(words[i], "^%-([7ʔ])(" .. V .. ")", "-%1%2" .. MACRON)	-- affix that requires glottal stop
	end
	text = table.concat(words, "")
	-- Convert hyphens to spaces
	text = rsub(text, "%-", " ")
	-- canonicalize multiple spaces again, which may have been introduced by hyphens
	text = canon_spaces(text)
	-- now eliminate punctuation
	text = rsub(text, "[!?']", "")
	-- put # at word beginning and end and double ## at text/foot boundary beginning/end
	text = rsub(text, " | ", "# | #")
	text = "##" .. rsub(text, " ", "# #") .. "##"
	text = rsub_repeatedly(text, "([.]?)#([.]?)", "#")

	table.insert(debug, text)

	-- handle certain combinations; ch ng and sh handling needs to go first
	text = rsub(text, "([t]?)ch", "ts") --not the real sound
	text = rsub(text, "([n]?)g̃", "ng") -- Spanish spelling support
	text = rsub(text, "ng", "ŋ")
	text = rsub(text, "sh", "ʃ")

	--x
	text = rsub(text, "([#])x(" .. V .. ")", "%1s%2")
	text = rsub(text, "x", "ks")

	--ll
	text = rsub(text, "ll([i]?)(".. V.. ")", "ly%2")

	--c, gü/gu+e or i, q
	text = rsub(text, "c([iey])", "s%1")
	text = rsub(text, "(" .. V .. ")gü([ie])", "%1ɡw%2")
	text = rsub(text, "gü([ie])", "ɡuw%1")
	text = rsub(text, "gui([aeëo])", "ɡy%1")
	text = rsub(text, "gu([ie])", "ɡ%1")
	text = rsub(text, "qu([ie])", "k%1")
	text = rsub(text, "ü", "u")
	text = rsub(text, "ë", "ə")

	--alphabet-to-phoneme
	text = rsub(text, "[cfgjñqrvz7]",
	--["g"]="ɡ":  U+0067 LATIN SMALL LETTER G → U+0261 LATIN SMALL LETTER SCRIPT G
		{ ["c"] = "k", ["g"] = "ɡ", ["j"] = "ĵ", ["ñ"] = "ny", ["q"] = "k", ["r"] = "ɾ", ["7"] = "ʔ"})

	-- trill in rr
	text = rsub(text, "[ɾ]+", "ɾ")
	text = rsub(text, "ɾ[.]ɾ", "r")

    -- ts
	text = rsub(text, "t_s", "ć") --not the real sound
	text = rsub(text, "ts", "ĉ") --not the real sound

	table.insert(debug, text)

	text = rsub_repeatedly(text, "(" .. NV .. ")([u])([" .. AC .. MACRON .. "]?)([aeio])("  .. accent_c .. "?)","%1%2%3.w%4%5")
	text = rsub_repeatedly(text, "(" .. V ..  ")([u])([aeio])("  .. accent_c .. "?)","%1.w%3%4")
	text = rsub_repeatedly(text, "(" .. V ..  ")([o])([aei])("  .. accent_c .. "?)","%1.w%3%4")
	text = rsub(text, "([i])([" .. AC .. MACRON .. "])([aeou])("  .. accent_c .. "?)","%1%2.y%3%4")
	text = rsub(text, "([i])([aeou])(" .. accent_c .. "?)","y%2%3")
	text = rsub(text, "a([".. AC .."]*)o([#.ʔ])","a%1w%2")

	-- eu rules
	text = rsub_repeatedly(text, "([#])([e])([u])("  .. accent_c .. "?)","%1y%3%4")
	text = rsub_repeatedly(text, "(" .. NV .. ")([e])([" .. AC .. MACRON .. "]?)([u])("  .. accent_c .. "?)","%1%2%3.%4%5")

	--determining whether "y" is a consonant or a vowel
	text = rsub(text, "y(" .. accent_c .. ")", "i%1")
	text = rsub(text, "y(" .. V .. ")", "ɟ%1") -- not the real sound
	text = rsub(text,"(" .. NV ..  ")y([ˈˌ.]*)([bćĉdfɡhjĵklmnɲŋpɾrsʃtvwɟzʔ#" .. vowel .. "])","%1i%2%3")
	text = rsub(text,"(" .. V ..  ")y([ˈˌ.]*)([bćĉdfɡhjĵklmnɲŋpɾrsʃtvwɟzʔ#" .. vowel .. "])","%1j%2%3")
	text = rsub(text, "w(" .. V .. ")","w%1")
	text = rsub(text,"(" .. NV ..  ")w([ˈˌ]?)([bćĉdfɡjĵklmnɲŋpɾrsʃtvwɟzʔ#])","%1u%2%3")

	table.insert(debug, text)

	--vowels with grave/circumflex to vowel+glottal stop
	text = rsub(text, CFLEX, AC .. GR)
	text = rsub(text, "(" .. V .. ")([" .. AC .. "]?)" .. GR .. "([#" .. vowel .. "])", "%1%2ʔ%3")
	text = rsub(text, "(" .. V .. ")([" .. AC .. "]?)" .. GR, "%1%2")

	-- Add glottal stop for words starting with vowel
	text = rsub(text, "([#])(" .. V .. ")", "%1ʔ%2")
	text = rsub(text, "◌", "")

	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*)(" .. C .. V .. ")", "%1.%2")

	-- "mb", "mp", "nd", "nk", "nt" combinations
	text = rsub_repeatedly(text, "(m)([bp])([^hlɾrɟ" .. vowel .. separator .."])(" .. V .. ")", "%1%2.%3%4")
	text = rsub_repeatedly(text, "(n)([dkt])([^hlɾrɟ" .. vowel .. separator .. "])(" .. V .. ")", "%1%2.%3%4")
	text = rsub_repeatedly(text, "(n)([s])([^ɟ" .. vowel .. separator .. "])(" .. V .. ")", "%1%2.%3%4")
	text = rsub_repeatedly(text, "(ŋ)([k])([^hlɾrɟ" .. vowel .. separator ..  "])(" .. V .. ")", "%1%2.%3%4")
	text = rsub_repeatedly(text, "([ɾr])([bćĉdfɡklmnpsʃvz])([^hlɾrɟ" .. vowel .. separator ..  "])(" .. V .. ")", "%1%2.%3%4")
	text = rsub_repeatedly(text, "([ɾr])([t])([sz]?)([^hlɾrɟsʃ" .. vowel .. separator ..  "])(" .. V .. ")", "%1%2%3.%4%5")

	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. "+)(" .. C .. C .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. ")(" .. C .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. "+)(" .. C .. C .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. C .. ")%.s(" .. C .. ")", "%1s.%2")
	-- Any aeo, or stressed iu, should be syllabically divided from a following aeo or stressed iu.
	text = rsub_repeatedly(text, "([aeo]" .. accent_c .. "*)([aeo])", "%1.%2")
	text = rsub_repeatedly(text, "([aeo]" .. accent_c .. "*)(" .. V .. AC .. ")", "%1.%2")
	text = rsub(text, "([iuə]" .. AC .. ")([aeo])", "%1.%2")
	text = rsub_repeatedly(text, "([iuə]" .. AC .. ")(" .. V .. AC .. ")", "%1.%2")
	text = rsub_repeatedly(text, "i(" .. accent_c .. "*)i", "i%1.i")
	text = rsub_repeatedly(text, "u(" .. accent_c .. "*)u", "u%1.u")

	table.insert(debug, text)

	local accent_to_stress_mark = { [AC] = "ˈ", [MACRON] = "" }

	local function accent_word(word, syllables)
		-- Now stress the word. If any accent exists in the word (including macron indicating an unaccented word),
		-- put the stress mark(s) at the beginning of the indicated syllable(s). Otherwise, apply the default
		-- stress rule.
		if rfind(word, accent_c) then
			for i = 1, #syllables do
				syllables[i] = rsub(syllables[i], "^(.*)(" .. accent_c .. ")(.*)$",
					function(pre, accent, post)
						return accent_to_stress_mark[accent] .. pre .. post
					end
				)
			end
		else
			-- Default stress rule. Words without vowels (e.g. IPA foot boundaries) don't get stress.
			if #syllables > 1 and rfind(word, "[^aeiouəʔbcćĉdfɡghjɟĵklmnñɲŋpqrɾsʃtvwxz#]#") or #syllables == 1 and rfind(word, V) then
				syllables[#syllables] = "ˈ" .. syllables[#syllables]
			elseif #syllables >= 2 then
				local vowel_find = false
				local stress_find = false
				for i=0, #syllables-1 do
					if rfind(syllables[#syllables - i], V) then
						if vowel_find then
							syllables[#syllables - i] = "ˈ" .. syllables[#syllables - i]
							stress_find = true
							break
						end
						vowel_find = true
					end
				end
				if vowel_find and not stress_find then
					syllables[#syllables - 1] = "ˈ" .. syllables[#syllables - 1]
				end
			end
		end
	end

	local words = rsplit(text, " ")
	for j, word in ipairs(words) do
		-- accentuation
		local syllables = rsplit(word, "%.")
		accent_word(word, syllables)
		-- Reconstruct the word.
		words[j] = table.concat(syllables, ".")
	end

	text = table.concat(words, " ")

	-- suppress syllable mark before IPA stress indicator
	text = rsub(text, "%.(" .. ipa_stress_c .. ")", "%1")
	--make all primary stresses but the last one be secondary
	text = rsub_repeatedly(text, "ˈ(.+)ˈ", "ˌ%1ˈ")

    table.insert(debug,text)

    --correct final glottal stop placement
    text = rsub(text,"([ˈˌ])ʔ([#]*)([ʔbĉćdfɡhĵɟklmnŋɲpɾrsʃtvwz])(" .. V .. ")","%1%2%3%4ʔ")

    table.insert(debug,text)

    --add temporary macron for /a/, /i/ and /u/

	text = rsub(text,"([ˈˌ])([#]*)([ʔbćĉdfɡhĵɟklmnŋpɾrstvwz]?)([ɟlnɾstw]?)([a])([.# ˈˌ])","%1%2%3%4ā%6") -- /a/ on open stressed syllables
	text = rsub(text,"([ʔbćĉdfɡhĵɟklmnŋpɾrstvwz]?)([ɟlnɾstw]?)[i]([ʔbdfɡklmnŋpɾstu#])([bdɡklmnpɾst]?)","%1%2ī%3%4") -- /i/ on closed syllables regardless of stress
	text = rsub(text,"([ˈˌ])([#]*)([ʔbćĉdfɡhĵɟklmnŋpɾrstvwz]?)([ɟlnɾstw]?)([u])([ʔbdfɡiklmnŋpɾst]?)([bdɡklmnpɾst]?)","%1%2%3%4ū%6%7") -- /u/ stress checker
	text = rsub(text,"([ˈˌ])([#]*)([ʔbćĉdfɡhĵɟklmnŋpɾrstvwz]?)([ɟlnɾstw]?)([o])([ʔbdfɡiklmnŋpɾst]?)([bdɡklmnpɾst]?)","%1%2%3%4ō%6%7") -- /o/ stress checker

    table.insert(debug, text)

      --Corrections for diphthongs
    text = rsub(text,"([aāeəiīoōuū])[iī]","%1j") --ay
    text = rsub(text,"([aāeəiīoōuū])[u]","%1w") --aw

    table.insert(debug, text)

    --remove "ɟ" and "w" inserted on vowel pair starting with "i" and "u"
    text = rsub(text,"([i])([ˈˌ]?)ɟ([aāeəouū])","%1%2%3")
    text = rsub(text,"([oōuū])([ˈˌ]?)w([aāeəiī])","%1%2%3")

    table.insert(debug,text)

    --/z/ changes
    text = rsub(text,"([aāeəoiīuū])z([ˈˌ.#])([^bdfɡĵjɟŋɾrvz])","%1s%2%3") -- /z/ turn to /s/ before some unvoiced sounds
    text = rsub(text,"([^#bdfɡĵjɟnŋɾrvzaāeəoiīuū])([ˈˌ.#])z","%1%2s") -- /z/ turn to /s/ after some unvoiced sounds
    text = rsub(text,"([bćĉdfɡhĵjɟklmnŋptvwz])([ˈˌ.]?)([ɟlɾst])([aāeəoōiīuū])([.]?)([z])","%1%2%3%4%5s") -- consonant cluster before /z/ turn to /s/
    text = rsub_repeatedly(text, "([^z]*)z([^z]*)([^#bdfɡĵjɟnŋɾrvzˈˌ.#][ˈˌ.#]?)z", "%1z%2%3s") -- /z/ turn to /s/ if /z/ already said earlier

    text = rsub_repeatedly(text, "^([#]*)([ˈˌ])([#]*)", "%1%3%2") -- Move stress inside word boundary fix at start
    text = rsub_repeatedly(text, "([ ])([#]*)([ˈˌ])([#]*)", "%1%2%4%3") -- Move stress inside word boundary fix at start

    local kne_IPA_table = {
    	["phonetic"] = text,
    	["phonemic"] = text
    }

	for key, value in pairs(kne_IPA_table) do
		text = kne_IPA_table[key]

		--phonetic transcription
		if key == "phonetic" then
	       	table.insert(debug, text)

			-- Kankanaey /o/ and /u/
			text = rsub(text,"([ou])([bdfɡlmnŋpɾstu])([bdɡklmnpɾst]?)([^#])","ʊ%2%3%4")
			text = rsub(text,"([bćĉdfɡhĵɟklmnŋpɾrstvwz])([ɟlnɾstw]?)([ou])([j])[#]","%1%2ʊ%4#")
			text = rsub(text,"([uū])([kʔ])","o%2")
			text = rsub(text,"([uū])([bćĉdfɡhĵɟklmnŋpɾrstvwz])#","o%2#")

			--Turn phonemic diphthongs to phonetic diphthongs
			text = rsub(text, "([aāeəiī])j", "%1i̯")
			text = rsub(text, "([ōoʊuū])j", "%1y̯")
			text = rsub(text, "([aāeəiīōoʊuū])w", "%1ʊ̯")

	        table.insert(debug, text)

	        --Combine consonants (except H) followed by I/U and certain stressed vowels
		    text = rsub(text,"([bćĉdfɡĵklmnɲŋpɾrstvz])([lnɾst]?)i([ˈˌ.])ɟ?([āaeəoūʊ])","%3%1%2ɟ%4")
		    text = rsub(text,"([bćĉdfɡĵklmnɲŋpɾrstvz])([lnɾst]?)u([ˈˌ.])w?([āaeəīio])","%3%1%2w%4")
		    text = rsub(text,"([h])ʊ([ˈˌ.])w?([āaeəīi])","%2%1w%3") -- only for hu with (ei) combination
			text = rsub_repeatedly(text, "([.]+)", ".")

	       	table.insert(debug, text)

			text = rsub(text,"([ˈˌ])([#]*)([ʔbćĉdfɡhĵɟklmnŋpɾrstvwz]?)([ɟlnɾstw]?)([u])([ʔbdfɡiklmnŋpɾst]?)([bdɡklmnpɾst]?)","%1%2%3%4ū%6%7")

	       	-- foreign s consonant clusters
		    text = rsub(text,"([ˈˌ.]?)([#]*)([.]?)([s])([ʔbćĉdfɡhĵklmnŋpɾrt])([ɟlnɾstw]?)([aāeəii̯īoʊʊ̯ū])",
		    	function(stress, boundary, syllable, s, cons1, cons2, vowel)
		    		if stress == "" then stress = "." end
		    		return boundary .. "ʔi" .. s .. stress .. cons1 .. cons2 .. vowel
		    	end
		    )

			-- text = rsub(text,"([ˈˌ])([ʔbćĉdfɡhĵɟklmnŋpɾrstwvz]?)([ɟlnɾstw]?)([a])","%1%2%3ā")
			-- text = rsub(text,"([ˈˌ])([ʔbćĉdfɡhĵɟklmnŋpɾrstwvz]?)([ɟlnɾstw]?)([i])","%1%2%3ī")
			-- text = rsub(text,"([ˈˌ])([ʔbćĉdfɡhĵɟklmnŋpɾrstwvz]?)([ɟlnɾstw]?)([u])","%1%2%3ū")

		    table.insert(debug, text)

	    	text = rsub(text,"([nŋ])([ˈˌ# .]*[bfpv])","m%2")
	    	text = rsub(text,"([ŋ])([ˈˌ# .]*[dlmnstwz])","n%2")
		    --text = rsub_repeatedly(text,"([aāeəii̯īoʊʊ̯ū])([#]?)([ ]?)([ˈˌ#.])([k])([aāeəiīoʊū])","%1%2%3%4x%6") -- /k/ between vowels
		    --text = rsub_repeatedly(text,"([aāeəii̯īoʊʊ̯ū])([#]?)([ ]?)([ˈˌ#.])([ɡ])([aāeəiīoʊū])", "%1%2%3%4ɣ%6") -- /ɡ/ between vowels
	        text = rsub(text,"d([ˈˌ.])ɟ","%1ĵ") --/d/ before /j/
	        text = rsub(text,"d[ɟj]([aāeəii̯īoʊʊ̯ū])","ĵ%1") --/d/ before /j/
	        -- text = rsub(text,"s[ɟj]([aāeəii̯īoʊʊ̯ū])","ʃ%1") --/s/ before /j/
	        text = rsub(text,"([n])([ˈˌ# .]*[ɡk])","ŋ%2") -- /n/ before /k/ and /g/ (some proper nouns and loanwords)
	        --text = rsub(text,"n([ˈˌ.])ɟ","%1ɲ") -- /n/ before /j/
	        --text = rsub(text,"s([ˈˌ.])ɟ","%1ʃ") -- /s/ before /j/
	        --text = rsub(text,"z([ˈˌ.])ɟ","%1ʒ") -- /z/ before /j/
	        --text = rsub(text,"t([ˈˌ.])ɟ","%1ĉ") -- /t/ before /j/
	        text = rsub(text,"([ˈˌ.])d([ɟj])([aāeəiīoʊū])","%1ĵ%3") -- /dj/ before any vowel following stress
	        --text = rsub(text,"([ˈˌ.])n([ɟj])([aāeəiīoʊū])","%1ɲ%3") -- /nj/ before any vowel following stress
	        --text = rsub(text,"([ˈˌ.])s([ɟj])([aāeəiīoʊū])","%1ʃ%3") -- /sj/ before any vowel following stress
	        --text = rsub(text,"([ˈˌ.])t([ɟj])([aāeəiīoʊū])","%1ĉ%3") -- /tj/ before any vowel following stress
	        -- text = rsub(text,"([oʊ])([m])([.]?)([ˈ]?)([pb])","u%2%3%4%5") -- /o/ and /ʊ/ before /mb/ or /mp/
	        text = rsub(text,"([aāeəiīoʊū])(ɾ)([bćĉdfɡĵklmnŋpstvz])([s]?)([#.])","%1ɹ%3%4%5") -- /ɾ/ becoming /ɹ/ before consonants not part of another syllable

	        --final fix for phonetic diphthongs
		    text = rsub(text,"([a])i̯","āi̯") --ay
		    text = rsub(text,"([a])ʊ̯","āʊ̯") --aw
		    text = rsub(text,"([i])ʊ̯","īʊ̯") --iw

			-- Kankanaey /i/ lowers before nasal
			text = rsub(text,"([i])([# .ˈˌ]*[ŋ])","ī%2")

	       	table.insert(debug, text)

		    --Change stresses before penultimate to have final syllable stress
		    text = rsub_repeatedly(text,"[ˈˌ]([ʔbćĉdfɡɣhĵɟkxlmnɲŋpɾrsʃtwvzʒ]?[ɟlnɾstw]?[āeəīoū])([^# ˈˌ]*)" ..
		    	"([.][ʔbćĉdfɡɣhĵɟkxlmnɲŋpɾrsʃtwvzʒ]?[ɟlnɾstw]?[āeīoūaəiʊ])([^# ˈˌ]*)" ..
		    	"[.]([ʔbćĉdfɡɣhĵɟkxlmnɲŋpɾrsʃtwvzʒ]?[ɟlnɾstw]?[āeīoūaəiʊ])([^# ˈˌ.]*)([# ])","ˌ%1%2%3%4ˈ%5%6%7")

			-- text = rsub(text,"([ˈˌ])([ʔbćĉdfɡhĵɟklmnŋpɾrstwvz]?)([ɟlnɾstw]?)([a])","%1%2%3ā")
			-- text = rsub(text,"([ˈˌ])([ʔbćĉdfɡhĵɟklmnŋpɾrstwvz]?)([ɟlnɾstw]?)([i])","%1%2%3ī")
			-- text = rsub(text,"([ˈˌ])([ʔbćĉdfɡhĵɟklmnŋpɾrstwvz]?)([ɟlnɾstw]?)([ʊ])","%1%2%3ū")

		    --If final syllable is stressed but so is penultimate, mark penultimate only
		    -- text = rsub_repeatedly(text,"[ˌ]([ʔbćĉdfɡɣhĵɟkxlmnɲŋpɾrsʃtwvzʒ]?[ɟlnɾstw]?[āeəīoū])([^# .ˈˌ]*)" ..
		    -- 	"([.]?[ˈˌ])([ʔbćĉdfɡɣhĵɟkxlmnɲŋpɾrsʃtwvzʒ]?[ɟlnɾstw]?)([āaeoəīōū])([^# ˈˌ.]*)([# ])","ˈ%1%2.%4%5%6%7")

		    text = rsub_repeatedly(text, "ˈ(.+)ˈ", "ˌ%1ˈ") -- Reset primary to secondary stresses if not on last word

		    -- Add vowel length to open stressed vowels
		    text = rsub_repeatedly(text,"([ˈˌ])([ʔbćĉdfɡɣhĵɟkxlmnɲŋpɾrsʃtwvzʒ]?)([ɟlnɾstw]?)([aāeəīioōūʊ])([ˈˌ.])","%1%2%3%4ː%5")

			-- Stops are unreleased on syllable-final position
		    text = rsub(text,"([pbtdkɡ])([.# ˈˌ])","%1̚%2")

		    -- /k/ is farther back except with high front vowel /i/
		    text = rsub(text,"k","k̠")
		    text = rsub(text,"(k̠)([īi])","k%2")
		    text = rsub(text,"([īi])(k̠)","%1k")

		    --Change /e/ closer to native pronunciation.
		    --text = rsub(text, "e", "ɛ")

		     --Change /ə/ closer to native pronunciation.
		    text = rsub(text, "ə", "ɨ")

		     --change a, u to unstressed equivalents (certain forms to restore)
		    text = rsub(text,"a","ʌ")
		    --text = rsub(text,"[ou]","ʊ")

		    text = rsub(text,"ī","i̞")

		else
			text = rsub(text,"([n])([ˈˌ#.]?[ɡk])","ŋ%2") -- /n/ before /k/ and /g/ (some proper nouns and loanwords)
			if not include_phonemic_syllable_boundaries then
				text = rsub(text,"%.","")
			end
			text = rsub(text,"‿", " ")
			text = rsub(text,"ʰ", "") -- Remove aspiration
			text = rsub(text,"ː", "") -- Remove varying vowel lengths
		end

		table.insert(debug, text)

	    --delete temporary macron in /a/, /o/ and /u/
	    text = rsub(text,"ā","a")
	    text = rsub(text,"ī","i")
	    text = rsub(text,"ō","o")
	    text = rsub(text,"ū","u")

		-- Final fix for "iy" and "uw" combination
		text = rsub(text,"([iɪ])([ː]?)([ˈˌ.]*)ɟ([aɐeɛəouʊ])","%1%2%3%4")
		text = rsub(text,"([uʊ])([ː]?)([ˈˌ.]*)w([aɐeɛəiɪo])","%1%2%3%4")
		text = rsub(text,"([ɪ])([ː]?)([ˈˌ.]*)ɟ([i])","%1%2%3%4")
		text = rsub(text,"([i])([ː]?)([.]*)ɟ([ɪ])","%1%2%3%4")
		text = rsub(text,"([ʊ])([ː]?)([ˈˌ.]*)w([u])","%1%2%3%4")
		text = rsub(text,"([u])([ː]?)([.]*)w([ʊ])","%1%2%3%4")

		--remove "ɟ" and "w" inserted on vowel pair starting with "e" and "o"
	    text = rsub(text,"([ɛe])([ː]?)([ˈˌ.]*)[ɟj]([aɐo])","%1%2%3%4")
	    text = rsub(text,"([o])([ː]?)([ˈˌ.]*)w([aɐeɛə])","%1%2%3%4")

		-- convert fake symbols to real ones
	    local final_conversions = {
			["ĉ"] = "t͡ʃ", -- fake "ch" to real "ch"
			["ć"] = "t͡s", -- fake "ts" to real "ts"
			["ɟ"] =  "j", -- fake "y" to real "y"
	        ["ĵ"] = "d͡ʒ" -- fake "j" to real "j"
		}

		text = rsub(text, "[ć]([" .. separator .. "])", "ts%1")
		text = rsub(text, "[ĉćɟĵ]", final_conversions)

		-- Do not have multiple syllable break consecutively
		text = rsub_repeatedly(text, "([.]+)", ".")
    	text = rsub_repeatedly(text, "([.]?)(‿)([.]?)", "%2")

    	-- remove # symbols at word and text boundaries
		text = rsub_repeatedly(text, "([.]?)#([.]?)", "")

		-- resuppress syllable mark before IPA stress indicator
		text = rsub(text, "%.(" .. ipa_stress_c .. ")", "%1")
		text = rsub_repeatedly(text, "([.]?)(" .. ipa_stress_c .. ")([.]?)", "%2")

    	kne_IPA_table[key] = toNFC(text)
	end

	return kne_IPA_table
end

function export.show(frame)
	local params = {
		[1] = {},
		["pre"] = {},
		["bullets"] = {type = "number", default = 1},
	}

	local parargs = frame:getParent().args
	local args = require("Module:parameters").process(parargs, params)

	local results = {}

	local text = args[1] or mw.title.getCurrentTitle().text

	local IPA_result = export.IPA(text)
	table.insert(results, { pron = "/" .. IPA_result["phonemic"] .. "/" })
	table.insert(results, { pron = "[" .. IPA_result["phonetic"] .. "]" })

	local pre = args.pre and args.pre .. " " or ""
	local bullet = (args.bullets ~= 0) and "* " or ""

	return bullet .. pre .. m_IPA.format_IPA_full { lang = lang, items = results }
end


local function parse_gloss(arg)
	local poses, gloss
	if arg:find("%^") then
		poses, gloss = arg:match("^(.-)%^(.*)$")
		if gloss == "" then
			gloss = nil
		end
	else
		gloss = arg
	end
	if poses then
		poses = split_on_comma(poses)
		local m_headword_data = mw.loadData(headword_data_module)
		for i, pos in ipairs(poses) do
			poses[i] = m_headword_data.pos_aliases[pos] or pos
		end
	end
	return {
		poses = poses,
		gloss = gloss,
	}
end


-- Parse a raw accent spec, which is one or more comma-separated accent qualifiers.
local function parse_accents(arg)
	return require(labels_module).split_labels_on_comma(arg)
end


-- Return the number of syllables of a phonemic or phonetic representation, which should have syllable dividers in it
-- but no hyphens.
local function get_num_syl_from_ipa(pron)
	-- Maybe we should just count vowels instead of the below code.
	pron = rsub(pron, "|", " ") -- remove IPA foot boundaries
	local words = rsplit(pron, " +")
	for i, word in ipairs(words) do
		-- IPA stress marks are syllable divisions if between characters; otherwise just remove.
		word = rsub(word, "(.)[ˌˈ](.)", "%1.%2")
		word = rsub(word, "[ˌˈ]", "")
		words[i] = word
	end
	-- There should be a syllable boundary between words.
	pron = table.concat(words, ".")
	return ulen(rsub(pron, "[^.]", "")) + 1
end


-- Get the rhyme by truncating everything up through the last stress mark + any following consonants, and remove
-- syllable boundary markers.
local function convert_phonemic_to_rhyme(phonemic)
	-- NOTE: This works because the phonemic vowels are just [aeiou] possibly with diacritics that are separate
	-- Unicode chars. If we want to handle things like ɛ or ɔ we need to add them to `vowel`.
	phonemic = rsplit(phonemic, " ")
	phonemic = phonemic[#phonemic]
	return rsub(rsub(phonemic, ".*[ˌˈ]", ""), "^" .. NV .. "*", ""):gsub("%.", "")
end


local function split_syllabified_spelling(spelling)
	spelling = "#" .. spelling .. "#"
	spelling = rsub_repeatedly(spelling, "%.([ #])", "·%1")
	spelling = rsub_repeatedly(spelling, "#", "")
	spelling = rsplit(spelling, "%.")
	for key, value in ipairs(spelling) do
		spelling[key] = rsub_repeatedly(value, "·", ".")
	end
	return spelling
end


-- "Align" syllabified respelling `syllab` to original spelling `spelling` by matching character-by-character, allowing
-- for extra syllable and accent markers in the syllabification and certain mismatches in the consonants. The goal is to
-- produce the appropriately syllabified version of the original spelling (the pagename) by matching characters in the
-- syllabified respelling to the original spelling, putting the syllable boundaries in the appropriate places in the
-- original spelling. As an example, given syllabified respelling 'a.ma.7ín' and original spelling 'amain', we would
-- like to produce 'a.ma.in'.
--
-- If we encounter an extra syllable marker (.), we allow and keep it. If we encounter an extra accent marker in the
-- syllabification, we drop it. We allow for mismatches in capitalization and for certain other mismatches, e.g. extra
-- glottal stops (written 7), h in respelling vs. g or j in the original, etc. If we can't match, we return nil
-- indicating the alignment failed.
local function align_syllabification_to_spelling(syllab, spelling)
	local result = {}
	local function concat_result()
		-- Postprocess to remove dots (syllable boundaries) next to hyphens.
		return (toNFC(table.concat(result)):gsub("%.%-", "-"):gsub("%-%.", "-"))
	end
	-- Remove glottal stop (7) from respelling to simplify the code below, because it's never found in the original
	-- spelling. (FIXME: We should do the same for diacritics, but they're currently removed earlier, in
	-- syllabify_from_spelling(). We should probably get rid of the removal there and put it here.)
	syllab = decompose(syllab:gsub("ː", "")):gsub("7", "")
	spelling = decompose(spelling)
	local syll_chars = rsplit(ulower(syllab), "")
	local spelling_chars = rsplit(spelling, "")
	local i = 1
	local j = 1
	local function matches(uci, ucj)
		-- Return true if a syllabified respelling character (uci) matches the corresponding spelling char (ucj).
		-- Both uci and ucj should be lowercase.
		-- Sound is at the key, values are the letters sound can match
		local matching_chars = {
			["e"] = {"i"},
			["ë"] = {"e", "a"},
			["h"] = {"g", "j", "x"},
			["i"] = {"e"},
			["j"] = {"g"},
			["k"] = {"j"},
			["o"] = {"u"},
			["s"] = {"j", "c"},
			["w"] = {"u", "o"},
			["y"] = {"i"}
		}

		return uci == ucj or (matching_chars[uci] and m_table.contains(matching_chars[uci], ucj))
	end
	local function silent_spelling_letter(ucj)
		return ucj == "h" or ucj == "'" or ucj == "-"
	end
	local function syll_at(pos)
		return syll_chars[pos] or ""
	end
	local function spell_at(pos)
		return spelling_chars[pos] or ""
	end
	local function uspell_at(pos)
		local c = spelling_chars[pos]
		return c and ulower(c) or ""
	end
	while i <= #syll_chars or j <= #spelling_chars do
		local uci = syll_at(i)
		local cj = spell_at(j)
		local ucj = uspell_at(j)
		if uci == "g" and syll_at(i - 1) == "n" and syll_at(i + 1) == "." and matches(syll_at(i + 2), ucj) and
			not matches(syll_at(i + 2), uspell_at(j + 1)) then
			-- As a special case, before checking whether the corresponding characters match, we have to skip an extra
			-- g in an -ng- sequence in the syllabified respelling if the corresponding spelling character matches the
			-- next respelling character (taking into account the syllable boundary). This is so that e.g.
			-- syll='ba.rang.gay' matches spelling='barangay'. Otherwise we will match the first respelling g against
			-- the spelling g and the second respelling g won't match. A similar case occurs with
			-- syll='E.vang.he.lis.ta' and spelling='Evangelista'. But we need an extra condition to not do this hack
			-- when syll='ba.rang.gay' matches spelling='baranggay'.
			i = i + 1
		elseif matches(uci, ucj) then
			table.insert(result, cj)
			i = i + 1
			j = j + 1
		elseif ucj == uspell_at(j - 1) and uci == "." and ucj ~= syll_at(i + 1) then
			-- See below. We want to allow for a doubled letter in spelling that is pronounced single, and preserve the
			-- doubled letter. But it's tricky in the presence of syllable boundaries on both sides of the doubled
			-- letter as well as doubled letters pronounced double. Specifically, there are three possibilities,
			-- exemplified by:
			-- (1) syll='Mal.lig', spelling='Mallig' -> 'Mal.lig';
			-- (2) syll='Ma.lig', spelling='Mallig' -> 'Ma.llig';
			-- (3) syll='Wil.iam', spelling='William' -> 'Will.iam'.
			-- If we copy the dot first, we get (1) and (2) right but not (3).
			-- If we copy the double letter first, we get (2) and (3) right but not (1).
			-- We choose to copy the dot first except in the situation exemplified by (3), where we copy the doubled
			-- letter first. The condition above handles (3) (the doubled letter matches against a dot) while not
			-- interfering with (1) (where the doubled letter also matches against a dot but the next letter in the
			-- syllabification is the same as the doubled letter, because the doubled letter is pronounced double).
			table.insert(result, cj)
			j = j + 1
		elseif silent_spelling_letter(ucj) and uci == "." and ucj ~= syll_at(i + 1) and
			not rfind(uspell_at(j + 1), V) then
			-- See below for silent h or apostrophe in spelling. This condition is parallel to the one directly above
			-- for silent doubled letters in spelling and handles the case of syllab='Abduramán', spelling='Abdurahman',
			-- which should be syllabified 'Ab.du.rah.man'. But we need a check to see that the next spelling character
			-- isn't a vowel, because in that case we want the silent letter to go after the period, e.g.
			-- syllab='Jumu7á', spelling='Jumu'ah' -> 'Ju.mu.'ah' (the 7 is removed above).
			table.insert(result, cj)
			j = j + 1
		elseif uci == "." then
			table.insert(result, uci)
			i = i + 1
		elseif ucj == uspell_at(j - 1) then
			-- A doubled letter in spelling that is pronounced single. Examples:
			-- * syllab='Ma.líg', spelling='Mallig' -> 'Ma.llig' (with l)
			-- * syllab='Lu.il.yér', spelling='Lhuillier' -> 'Lhu.ill.ier' (with l; a more complex example)
			-- * syllab='a.sa.la.mu a.lai.kum', spelling='assalamu alaikum' -> 'as.sa.la.mu a.lai.kum' (with s)
			-- * syllab='Jé.fer.son', spelling='Jefferson' -> 'Je.ffer.son' (with f)
			-- * syllab='Je.ma', spelling='Gemma' -> 'Ge.mma' (with m)
			-- * syllab='Ha.na', spelling='Hannah' -> 'Ha.nnah' (with n)
			-- * syllab='A.by', spelling='Abby' -> 'A.bby' (with b)
			-- * syllab='Ka.ba', spelling='Kaaba' -> 'Kaa.ba' (with a)
			-- * syllab='Fu.ji', spelling='Fujii' -> 'Fu.jii' (with i)
			table.insert(result, cj)
			j = j + 1
		elseif silent_spelling_letter(ucj) then
			-- A silent h, apostrophe or hyphen in spelling. Examples:
			-- * syllab='adán', spelling='adhan' -> 'a.dhan'
			-- * syllab='Atanasya', spelling='Athanasia' -> 'A.tha.nas.ia'
			-- * syllab='Cýntiya', spelling='Cynthia' -> 'Cyn.thi.a'
			-- * syllab='Ermóhenes', spelling='Hermogenes' -> 'Her.mo.ge.nes'
			-- * syllab='Abduramán', spelling='Abdurahman' -> 'Ab.du.rah.man'
			-- * syllab='Jumu7á', spelling='Jumu'ah' -> 'Ju.mu.'ah'
			-- * syllab='pag7ibig', spelling='pag-ibig' -> 'pag-i.big'
			table.insert(result, cj)
			j = j + 1
		elseif uci == AC or uci == GR or uci == CFLEX or uci == DIA or uci == TILDE or uci == MACRON or
			uci == "y" or uci == "w" then
			-- skip character
			i = i + 1
		else
			-- non-matching character
			mw.log(("Syllabification alignment mismatch for pagename '%s' (position %s, character %s), syllabified respelling '%s' (position %s, character %s), aligned result so far '%s'"
				):format(spelling, j, ucj, syllab, i, uci, concat_result()))
			return nil
		end
	end
	if i <= #syll_chars or j <= #spelling_chars then
		-- left-over characters on one side or the other
		mw.log(("Syllabification alignment mismatch for pagename '%s' (%s), syllabified respelling '%s' (%s), aligned result so far '%s'"
			):format(
				spelling, j > #spelling_chars and "end of string" or ("position %s, character %s"):format(j, uspell_at(j)),
				syllab, i > #syll_chars and "end of string" or ("position %s, character %s"):format(i, syll_at(i)),
				concat_result()))
		return nil
	end
	return concat_result()
end


local function generate_syll_obj(term)
	return {syllabification = term, hyph = split_syllabified_spelling(term)}
end


-- Word should already be decomposed.
local function word_has_vowels(word)
	word = ulower(word)
	return rfind(word, V) or word:find("y")
end


local function any_words_have_vowels(term)
	local words = rsplit(decompose(term), "[ %-]")
	for i, word in ipairs(words) do
		-- Allow empty word; this occurs with prefixes and suffixes.
		if word_has_vowels(word) then
			return true
		end
	end
	return false
end


local function should_generate_rhyme_from_respelling(term)
	local words = rsplit(decompose(term), " +")
	local last_word = words[#words]
	local should_generate_cat = #words == 1
	local should_generate_rhyme =
		not last_word:find("%-$") and -- no if word is a prefix
		not (last_word:find("^%-") and last_word:find(MACRON)) and -- no if word is an unstressed suffix
		word_has_vowels(last_word) -- no if word has no vowels (e.g. a single letter)
	return should_generate_rhyme, should_generate_cat
end


local function should_generate_rhyme_from_ipa(ipa)
	local should_generate_cat = not ipa:find("%s")
	local should_generate_rhyme = word_has_vowels(decompose(ipa))
	return should_generate_rhyme, should_generate_cat
end


local function should_generate_rhyme_from_termobj(termobj)
	if termobj.raw then
		return should_generate_rhyme_from_ipa(termobj.raw_phonemic or termobj.raw_phonetic)
	else
		return should_generate_rhyme_from_respelling(termobj.term)
	end
end


local function process_specified_rhymes(rhymes, sylls, parsed_respellings)
	local rhyme_ret = {}
	for _, rhyme in ipairs(rhymes) do
		local num_syl = rhyme.num_syl
		local no_num_syl = false

		-- If user explicitly gave the rhyme but didn't explicitly specify the number of syllables, try to take it from
		-- the syllabification.
		if not num_syl then
			num_syl = {}
			for _, syll in ipairs(sylls) do
				if should_generate_rhyme_from_respelling(syll.syllabification) then
					local this_num_syl = 1 + ulen(rsub(syll.syllabification, "[^.]", ""))
					m_table.insertIfNot(num_syl, this_num_syl)
				else
					no_num_syl = true
					break
				end
			end
			if no_num_syl or #num_syl == 0 then
				num_syl = nil
			end
		end

		-- If that fails and term is single-word, try to take it from the phonemic.
		if not no_num_syl and not num_syl then
			for _, parsed in ipairs(parsed_respellings) do
				for _, pronun in ipairs(parsed.pronuns) do
					-- Check that pronun.phonemic exists (it may not if raw phonetic-only pronun is given), and rhyme
					-- isn't suppressed (which may happen if the term has a qualifier "colloquial", "obsolete" or the
					-- like or is an auto-generated "glottal stop elision" pronunciation).
					if pronun.phonemic and not pronun.no_rhyme then
						if not should_generate_rhyme_from_ipa(pronun.phonemic) then
							no_num_syl = true
							break
						end
						-- Count number of syllables by looking at syllable boundaries (including stress marks).
						local this_num_syl = get_num_syl_from_ipa(pronun.phonemic)
						m_table.insertIfNot(num_syl, this_num_syl)
					end
				end
				if no_num_syl then
					break
				end
			end
			if no_num_syl or #num_syl == 0 then
				num_syl = nil
			end
		end

		local rhymeobj = m_table.shallowcopy(rhyme)
		rhymeobj.num_syl = num_syl
		table.insert(rhyme_ret, rhymeobj)
	end
end


-- Parse a pronunciation modifier in `arg`, the argument portion in an inline modifier (after the prefix), which
-- specifies a pronunciation property such as rhyme, syllabification, homophones or audio. The argument can itself have
-- inline modifiers, e.g. <audio:Foo.ogg<a:Colombia>>. The allowed inline modifiers are specified by `param_mods` (of
-- the format expected by `parse_inline_modifiers()`); in addition to any modifiers specified there, the modifiers
-- <q:...>, <qq:...>, <a:...> and <aa:...> are always accepted (and can be repeated). `generate_obj` and `parse_err` are
-- like in `parse_inline_modifiers()` and specify respectively a function to generate the object into which modifier
-- properties are stored given the non-modifier part of the argument, and a function to generate an error message (given
-- the message). Normally, a comma-separated list of pronunciation properties is accepted and parsed, where each element
-- in the list can have its own inline modifiers and where no spaces are allowed next to the commas in order for them to
-- be recognized as separators. If `no_split_on_comma` is given, only a single pronunciation property is accepted. If
-- `has_outer_container` is given, the list of pronunciation properties is embedded in the `terms` property of an outer
-- container, into which other list-level modifiers can also be stored (by setting `overall = "true"` in the respective
-- spec in `param_mods`). The return value is a list if neither `no_split_on_comma` nor `has_outer_container` are given,
-- otherwise a container object (which, in the case of `has_outer_container`, will contain a list inside of it, in the
-- `terms` property).
local function parse_pron_modifier(arg, parse_err, generate_obj, param_mods, no_split_on_comma, has_outer_container)
	if arg:find("<") then
		local insert = { store = "insert" }
		param_mods.q = insert
		param_mods.qq = insert
		param_mods.a = insert
		param_mods.aa = insert
		return require(parse_utilities_module).parse_inline_modifiers(arg, {
			param_mods = param_mods,
			generate_obj = generate_obj,
			parse_err = parse_err,
			splitchar = not no_split_on_comma and "," or nil,
			outer_container = has_outer_container and {} or nil,
		})
	elseif no_split_on_comma then
		return generate_obj(arg)
	else
		local retval = {}
		for _, term in ipairs(split_on_comma(arg)) do
			table.insert(retval, generate_obj(term))
		end
		if has_outer_container then
			retval = {
				terms = retval,
			}
		end
		return retval
	end
end


local function parse_rhyme(arg, parse_err)
	local function generate_obj(term)
		return {rhyme = term}
	end
	local param_mods = {
		s = {
			item_dest = "num_syl",
			type = "number",
			sublist = true,
		},
	}

	return parse_pron_modifier(arg, parse_err, generate_obj, param_mods)
end


local function parse_syll(arg, parse_err)
	local param_mods = {
		cap = { overall = true},
	}

	-- We need to pass in has_outer_container because we have an overall property <cap:...> (the caption, defaulting
	-- to "Syllabification") applying to the whole set of syllabifications.
	return parse_pron_modifier(arg, parse_err, generate_syll_obj, param_mods, nil, "has outer container")
end


local function parse_homophone(arg, parse_err)
	local function generate_obj(term)
		return {term = term}
	end
	local param_mods = {
		t = {
			-- [[Module:links]] (called from [[Module:homophones]]) expects the gloss in "gloss".
			item_dest = "gloss",
		},
		gloss = {},
		pos = {},
		alt = {},
		lit = {},
		id = {},
		g = {
			-- [[Module:links]] (called from [[Module:homophones]]) expects the genders in "genders".
			item_dest = "genders",
			sublist = true,
		},
	}

	return parse_pron_modifier(arg, parse_err, generate_obj, param_mods)
end


local function generate_audio_obj(arg)
	local file, gloss = arg:match("^(.-)%s*#%s*(.*)$")
	if not file then
		file = arg
		gloss = "Audio"
	end
	return {file = file, gloss = gloss}
end


local function parse_audio(arg, parse_err)
	-- None other than qualifiers
	local param_mods = {}

	-- Don't split on comma because some filenames have embedded commas not followed by a space (typically followed by
	-- an underscore).
	return parse_pron_modifier(arg, parse_err, generate_audio_obj, param_mods, "no split on comma")
end


local function syllabify_from_spelling(text, pagename)
	-- Auto syllabifications start --
	local vowel = vowel .. "ẃý" -- vowel
	local V = "[" .. vowel .. "]"
	local NV = "[^" .. vowel .. "]"
	local C = "[^" .. vowel .. separator .. "]" -- consonant

	text = decompose(text, "recompose e-dia")

	local origtext = remove_accents(text)
	text = string.lower(text)

	text = rsub(text, "[.] ", "․ ")
	text = rsub(text, "[.]$", "․")

	-- put # at word beginning and end and double ## at text/foot boundary beginning/end
	text = rsub(text, " | ", "# | #")
	text = "##" .. rsub(text, " ", "# #") .. "##"
	text = rsub_repeatedly(text, "([.]?)#([.]?)", "#")

	text = rsub(text, "ng", "ŋ")
	text = rsub(text, "ch", "ĉ")
	text = rsub(text, "t_s", "ć")
	text = rsub(text, "sh", "ʃ")
	text = rsub(text, "gu([eëiy])", "ǵ%1")
	text = rsub(text, "qu([eëiy])", "ḱ%1")
	text = rsub(text, "r", "ɾ")
	text = rsub(text, "ɾɾ", "r")
	text = rsub(text, "ʔ", "7")

	text = rsub_repeatedly(text, "#(" .. C .. "+)u([aeio])","#%1u.%2")
	text = rsub_repeatedly(text, "#(" .. C .. "+)i([aeou])","#%1i.%2")
	text = rsub_repeatedly(text, "(" .. C .. ")u([aeio])","#%1.u%2")
	text = rsub_repeatedly(text, "(" .. C .. ")i([aeou])","#%1.i%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*)u([aeio])","%1.u%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*)o([aei])","%1.ó%2")
	text = rsub(text, "a(" .. accent_c .. "*)o([#.7])","a%1ó%2")

	-- eu rules
	text = rsub_repeatedly(text, "([^" .. vowel .. "#])([e])("  .. accent_c .. "?)([u])("  .. accent_c .. "?)","%1%2%3.%4%5")

	text = rsub(text, "y([ˈˌ." .. accent .. "]*)([bćĉdfgǵhjĵkḱlmnɲŋpɾrsʃtvwɟzʔ#" .. vowel .. "])","ý%1%2")
	text = rsub(text, "ý(" .. V .. ")", "y%1")
	text = rsub(text, "w([ˈˌ]?)([bćĉdfgǵjĵkḱlmnɲŋpɾrsʃtvwɟzʔ#" .. vowel .. "])","ẃ%1%2")
	text = rsub(text, "ẃ(" .. V .. ")","w%1")

	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*)(" .. C .. V .. ")", "%1.%2")

	-- "mb", "mp", "nd", "nk", "nt" combinations
	text = rsub_repeatedly(text, "(m)([bp])([^lɾrɟy" .. vowel .. separator .."])(" .. V .. ")", "%1%2.%3%4")
	text = rsub_repeatedly(text, "(n)([dk])([^lɾrɟy" .. vowel .. separator .. "])(" .. V .. ")", "%1%2.%3%4")
	text = rsub_repeatedly(text, "(n)([s])([^ɟy" .. vowel .. separator .. "])(" .. V .. ")", "%1%2.%3%4")
	text = rsub_repeatedly(text, "(n)([t])([^lɾrɟys" .. vowel .. separator .. "])(" .. V .. ")", "%1%2.%3%4")
	text = rsub_repeatedly(text, "(ŋ)([k])([^lɾrɟy" .. vowel .. separator .. "])(" .. V .. ")", "%1%2.%3%4")
	text = rsub_repeatedly(text, "([ɾr])([bćĉdfgǵkḱlmnpsʃvz])([^lɾrɟy" .. vowel .. separator .. "])(" .. V .. ")", "%1%2.%3%4")
	text = rsub_repeatedly(text, "([ɾr])([t])([sz]?)([^lɾrɟysʃ" .. vowel .. separator .. "])(" .. V .. ")", "%1%2%3.%4%5")

	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. ")(" .. C .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. "+)(" .. C .. C .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. C .. ")%.s(" .. C .. ")", "%1s.%2")

	-- Any aeëo, or stressed iu, should be syllabically divided from a following aeëo or stressed iu.
	text = rsub_repeatedly(text, "([aeëo]" .. accent_c .. "*)([aeëo])", "%1.%2")
	text = rsub_repeatedly(text, "([aeëo]" .. accent_c .. "*)(" .. V .. accent_c .. ")", "%1.%2")
	text = rsub(text, "([iu]" .. accent_c .. ")([aeëo])", "%1.%2")
	text = rsub_repeatedly(text, "([iu]" .. accent_c .. ")(" .. V .. accent_c .. ")", "%1.%2")
	text = rsub_repeatedly(text, "i(" .. accent_c .. "*)i", "i%1.i")
	text = rsub_repeatedly(text, "u(" .. accent_c .. "*)u", "u%1.u")

	text = rsub(text, "ĉ", "ch")
	text = rsub(text, "ć", "ts")
	text = rsub(text, "ŋ", "ng")
	text = rsub(text, "ʃ", "sh")
	text = rsub(text, "ǵ", "gu")
	text = rsub(text, "ḱ", "qu")
	text = rsub(text, "r", "rr")
	text = rsub(text, "ɾ", "r")
	text = remove_accents(text)

	text = rsub_repeatedly(text, "([.]+)", ".")
	text = rsub(text, "[.]?-[.]?", "-")
	text = rsub(text, "[‿]([^ ])", "|%1")
	text = rsub(text, "[.]([^ ])", "|%1")

	text = rsub(text, "([|])+", "%1")

	-- remove # symbols at word and text boundaries
	text = rsub_repeatedly(text, "([.]?)#([.]?)", "")
	text = rsub(text, "․", ".")

	-- Fix Capitalization --
	local syllbreak = 0
	for i=1, #text do
		if text:sub(i,i) == "|" and origtext:sub(i-syllbreak, i-syllbreak) ~= "." and origtext:sub(i-syllbreak, i-syllbreak) ~= "7" then
			syllbreak = syllbreak + 1
		elseif origtext:sub(i-syllbreak, i-syllbreak) == text:sub(i,i):upper() then
			text = table.concat({text:sub(1, i-1), text:sub(i,i):upper(), text:sub(i+1)})
		end
	end

	-- Fix hyphens --
	-- FIXME!!! Why are we relying on looking at the pagename here? This should not be happening.
	origtext = pagename

	if (table.concat(rsplit(origtext, "-")) == table.concat(rsplit(table.concat(rsplit(text, "|")), "-"))) then
		syllbreak = 0
		for i=1, #text do
			if text:sub(i,i) == "|" then
				if origtext:sub(i-syllbreak, i-syllbreak) == "-" then
					text = table.concat({text:sub(1, i-1), "-", text:sub(i+1)})
				else
					syllbreak = syllbreak + 1
				end
			end
		end
	end

	-- FIXME! Hack -- up above we changed periods to vertical bars. The rest of the code expects periods so change
	-- them back. We should clean up the code above to leave the periods alone.
	return (text:gsub("|", "%."))
end

function export.syllabify_and_align(respelling, pagename)
	local syllabification = syllabify_from_spelling(respelling, pagename)
	return align_syllabification_to_spelling(syllabification, pagename)
end

local function css_wrap(text, classes)
	return ('<span class="%s">%s</span>'):format(classes, text)
end

local function format_glosses(glosses)
	if not glosses then
		return ""
	end

	local formatted_glosses = {}
	for _, glossobj in ipairs(glosses) do
		local gloss_parts = {}
		if glossobj.gloss then
			table.insert(gloss_parts, css_wrap("“", "mention-gloss-double-quote") ..
				css_wrap(glossobj.gloss, "mention-gloss") .. css_wrap("”", "mention-gloss-double-quote"))
		end
		if glossobj.poses then
			for _, pos in ipairs(glossobj.poses) do
				table.insert(gloss_parts, css_wrap(pos, "ann-pos"))
			end
		end
		table.insert(formatted_glosses, table.concat(gloss_parts, css_wrap(",", "mention-gloss-comma") .. " "))
	end

	return " " .. css_wrap("(", "mention-gloss-paren annotation-paren") ..
		table.concat(formatted_glosses, css_wrap(";", "mention-gloss-semicolon") .. " ") ..
		css_wrap(")", "mention-gloss-paren annotation-paren")
end

local function format_pronuns(pronuns)
	local pronunciations = {}

	-- Loop through each pronunciation. For each one, add the phonemic and phonetic versions to `pronunciations`,
	-- for formatting by [[Module:IPA]].
	for j, pronun in ipairs(pronuns) do
		local qs = pronun.q

		local first_pronun = #pronunciations + 1

		if not pronun.phonemic and not pronun.phonetic then
			error("Internal error: Saw neither phonemic nor phonetic pronunciation")
		end

		if pronun.phonemic then -- missing if 'raw:[...]' given
			-- don't display syllable division markers in phonemic
			local slash_pron = "/" .. pronun.phonemic:gsub("%.", "") .. "/"
			table.insert(pronunciations, {
				pron = slash_pron,
			})
		end

		if pronun.phonetic then -- missing if 'raw:/.../' given
			local bracket_pron = "[" .. pronun.phonetic .. "]"
			table.insert(pronunciations, {
				pron = bracket_pron,
			})
		end

		local last_pronun = #pronunciations

		if pronun.q then
			pronunciations[first_pronun].q = pronun.q
		end
		if j > 1 then
			pronunciations[first_pronun].separator = ", "
		end
		if pronun.qq then
			pronunciations[last_pronun].qq = pronun.qq
		end

		if pronun.refs then
			pronunciations[last_pronun].refs = pronun.refs
		end
		if first_pronun ~= last_pronun then
			pronunciations[last_pronun].separator = " "
		end
	end

	return m_IPA.format_IPA_full { lang = lang, items = pronunciations, separator = "" }
end

local function format_pronun_line(parsed)
	local formatted_pronuns = format_pronuns(parsed.pronuns)
	local pre = is_first and parsed.pre and parsed.pre .. " " or ""
	local post = is_first and parsed.post and " " .. parsed.post or ""
	return pre .. formatted_pronuns .. format_glosses(parsed.t) .. post
end


local function parse_respelling(respelling, pagename, parse_err)
	local raw_respelling = respelling:match("^raw:(.*)$")
	if raw_respelling then
		local raw_phonemic, raw_phonetic = raw_respelling:match("^/(.*)/ %[(.*)%]$")
		if not raw_phonemic then
			raw_phonemic = raw_respelling:match("^/(.*)/$")
		end
		if not raw_phonemic then
			raw_phonetic = raw_respelling:match("^%[(.*)%]$")
		end
		if not raw_phonemic and not raw_phonetic then
			parse_err(("Unable to parse raw respelling '%s', should be one of /.../, [...] or /.../ [...]")
				:format(raw_respelling))
		end
		return {
			raw = true,
			raw_phonemic = raw_phonemic,
			raw_phonetic = raw_phonetic,
		}
	end
	if respelling == "+" then
		respelling = pagename
	end
	return {term = respelling}
end


-- External entry point for {{kne-pr}}.
function export.show_full(frame)

	--------------------------------- 1. Parse the arguments. ------------------------------------

	local params = {
		[1] = {list = true},
		["rhyme"] = {},
		["syll"] = {},
		["hmp"] = {},
		["audio"] = {list = true},
		["pagename"] = {},
	}
	local parargs = frame:getParent().args
	local args = require("Module:parameters").process(parargs, params)
	local pagename = args.pagename or mw.title.getCurrentTitle().subpageText

	local respellings = #args[1] > 0 and args[1] or {"+"}
	local parsed_respellings = {}
	local function overall_parse_err(msg, arg, val)
		error(msg .. ": " .. arg .. "=" .. val)
	end
	local overall_rhyme = args.rhyme and
		parse_rhyme(args.rhyme, function(msg) overall_parse_err(msg, "rhyme", args.rhyme) end) or nil
	local overall_syll = args.syll and
		parse_syll(args.syll, function(msg) overall_parse_err(msg, "syll", args.syll) end) or nil
	local overall_hmp = args.hmp and
		parse_homophone(args.hmp, function(msg) overall_parse_err(msg, "hmp", args.hmp) end) or nil
	local overall_audio
	if #args.audio > 0 then
		overall_audio = {}
		for _, audio in ipairs(args.audio) do
			local parsed_audio = parse_audio(audio, function(msg) overall_parse_err(msg, "audio", audio) end)
			table.insert(overall_audio, parsed_audio)
		end
	end

	-- Parse each respelling. Individual arguments in 1=, 2=, etc. can consist of one or more comma-separated
	-- respellings, each of which can have inline modifiers <q:...>, <qq:...>, <a:...>, <aa:...> or <ref:...>.
	-- In addition, the respellings as a whole of a given argument can be followed by various inline modifiers,
	-- such as <t:...>, <rhyme:...>, <syll:...>, etc. The result of parsing goes into `parsed_respellings`, which
	-- is a list of objects (one per numbered argument), each of which is a table of the form
	--
	-- {
	--   terms = {TERM, TERM, ...},
	--   audio = {AUDIO, AUDIO, ...},
	--   rhyme = {RHYME, RHYME, ...},
	--   syll = {SYLL, SYLL, ...},
	--   hmp = {HMP, HMP, ...},
	--   t = {GLOSS, GLOSS, ...},
	--   pre = "PRE-TEXT" or nil,
	--   post = "POST-TEXT" or nil,
	--   bullets = NUM_BULLETS,
	--   accents = {"ACCENT", "ACCENT", ...},
	-- }
	--
	-- In this structure, TERM is an object that usually has the form
	--
	-- {
	--   term = "RESPELLING",
	--   ref = {"REF-SPEC", "REF-SPEC", ...},
	--   q = {"QUALIFIER", "QUALIFIER", ...},
	--   qq = {"QUALIFIER", "QUALIFIER", ...},
	-- }
	--
	-- Note that in this structure, "REF-SPEC" of the form parsable by parse_references() in [[Module:references]].
	--
	-- Alternatively, if phonemic or phonetic IPA is given in place of a respelling, TERM will have the form
	--
	-- {
	--   raw = true,
	--   phonemic = "PHONEMIC",
	--   phonetic = "PHONETIC",
	--   ref = {"REF-SPEC", "REF-SPEC", ...},
	--   q = {"QUALIFIER", "QUALIFIER", ...},
	--   qq = {"QUALIFIER", "QUALIFIER", ...},
	-- }
	--
	-- AUDIO is a table of the form
	--
	-- {
	--   file = "FILE",
	--   gloss = "GLOSS",
	--   q = {"QUALIFIER", "QUALIFIER", ...},
	--   qq = {"QUALIFIER", "QUALIFIER", ...},
	--   a = {"ACCENT-QUALIFIER", "ACCENT-QUALIFIER", ...},
	--   aa = {"ACCENT-QUALIFIER", "ACCENT-QUALIFIER", ...},
	-- }
	--
	-- RHYME is a table of the form
	--
	-- {
	--   rhyme = "RHYME",
	--   num_syl = {NUM_SYL, NUM_SYL, ...},
	--   q, qq, a, aa = (as for AUDIO),
	-- }
	--
	-- SYLL is a table of the form (where `hyph` is required to be named this way for [[Module:hyphenation]])
	--
	-- {
	--   syllabification = "SYL.LAB.LES",
	--   hyph = {"SYL", "LAB", "LES"},
	--   q, qq, a, aa = (as for AUDIO),
	-- }
	--
	-- HMP is a table of the form
	--
	-- {
	--   term = "HOMOPHONE",
	--   gloss = "GLOSS" or nil,
	--   pos = "POS" or nil,
	--   alt = "ALT" or nil,
	--   lit = "LIT" or nil,
	--   id = "ID" or nil,
	--   g = {"G", "G", ...},
	--   q, qq, a, aa = (as for AUDIO),
	-- }
	--
	-- GLOSS is a table of the form
	--
	-- {
	--   poses = {"POS", "POS", ...} or nil,
	--   gloss = "GLOSS" or nil,
	-- }
	for i, respelling in ipairs(respellings) do
		if respelling:find("<") then
			local param_mods = {
				pre = { overall = true },
				post = { overall = true },
				bullets = {
					overall = true,
					type = "number",
				},
				t = {
					overall = true,
					store = "insert",
					convert = parse_gloss,
				},
				rhyme = {
					overall = true,
					store = "insert-flattened",
					convert = parse_rhyme,
				},
				syll = {
					overall = true,
					-- Not `store = "insert-flattened"`. parse_syll() does not generates a list but a structure where
					-- the syllabifications are in `terms` and there's an additional overall property `cap` for the
					-- caption (defaulting to "Syllabification"). FIXME: Rethink whether we even want "insert-flattened"
					-- or just "insert" for the remaining pronunciation properties.
					convert = parse_syll,
				},
				hmp = {
					overall = true,
					store = "insert-flattened",
					convert = parse_homophone,
				},
				audio = {
					overall = true,
					store = "insert", -- not "insert-flattened" because parse_audio returns a single object
					convert = parse_audio,
				},
				ref = { store = "insert" },
				q = { store = "insert" },
				qq = { store = "insert" },
				a = {
					item_dest = "accents",
					overall = true,
					convert = parse_accents,
				},
			}

			local parsed = require(parse_utilities_module).parse_inline_modifiers(respelling, {
				paramname = i,
				param_mods = param_mods,
				generate_obj = function(term, parse_err)
					return parse_respelling(term, pagename, parse_err)
				end,
				pre_normalize_modifiers = function(data)
					local modtext = data.modtext
					modtext = modtext:match("^<(.*)>$")
					if not modtext then
						error(("Internal error: Passed-in modifier isn't surrounded by angle brackets: %s"):format(
							data.modtext))
					end
					if modtext:find("%^") and not modtext:find("^t:") then
						modtext = "t:" .. modtext
					end
					return "<" .. modtext .. ">"
				end,
				splitchar = ",",
				outer_container = {},
			})
			if not parsed.bullets then
				parsed.bullets = 1
			end
			table.insert(parsed_respellings, parsed)
		else
			local termobjs = {}
			local function parse_err(msg)
				error(msg .. ": " .. i .. "=" .. respelling)
			end
			for _, term in ipairs(split_on_comma(respelling)) do
				table.insert(termobjs, parse_respelling(term, pagename, parse_err))
			end
			table.insert(parsed_respellings, {
				terms = termobjs,
				bullets = 1,
			})
		end
	end

	--------------------------------- 2. Generate IPA, rhymes and syllabification. ------------------------------------

	-- Used for categorization below.
	local syllabification_alignment_failed = false

	-- Canonicalize syllabifications in `sylls` by convering '+' to the default syllabification of the pagename, '#' to
	-- the pagename itself, and '-' to no syllabification (return `null_syll`). If '-' not seen, return `sylls`.
	local function canonicalize_syllabification(sylls, null_syll)
		for _, syll in ipairs(sylls.terms) do
			if syll.syllabification == "+" then
				syll.syllabification = syllabify_from_spelling(pagename, pagename)
				syll.hyph = split_syllabified_spelling(syll.syllabification)
			elseif syll.syllabification == "#" then
				syll.syllabification = pagename
				syll.hyph = {syll.syllabification}
			elseif syll.syllabification == "-" then
				return null_syll
			end
		end
		return sylls
	end

	if overall_syll then
		overall_syll = canonicalize_syllabification(overall_syll, {})
	end

	local function doesnt_count_for_rhyme(list)
		if not list then
			return false
		end
		local accent_no_count = {"colloquial", "obsolete", "relaxed"}
		for _, item in ipairs(list) do
			for _, word_no_count in ipairs(accent_no_count) do
				if item:find("%f[%w]" .. word_no_count .. "%f[%W]") then
					return true
				end
			end
		end
		return false
	end

	-- Loop over individual respellings, processing each.
	for _, parsed in ipairs(parsed_respellings) do
		-- First, sort the specified accents and default to "Kankanaey".
		if not parsed.accents then
			parsed.accents = {"Standard Kankanaey"}
		end

		-- If more than one respelling given, then if any accent or qualifier has the words 'colloquial', 'obsolete' or
		-- 'relaxed' in them, don't generate a rhyme or a '#-syllable word' category.
		local more_than_one_respelling = #parsed.terms > 1 or #parsed_respellings > 1
		local is_standard_kne = m_table.contains(parsed.accents, "Standard Kankanaey")
		local all_terms_no_rhyme = more_than_one_respelling and doesnt_count_for_rhyme(parsed.accents)

		parsed.pronuns = {}
		for i, term in ipairs(parsed.terms) do
			local phonemic, phonetic
			if term.raw then
				phonemic = term.raw_phonemic
				phonetic = term.raw_phonetic
			else
				local ret = export.IPA(term.term, "include phonemic syllable boundaries")
				phonemic = ret.phonemic
				phonetic = ret.phonetic
			end
			local refs
			if not term.ref then
				refs = nil
			else
				refs = {}
				for _, refspec in ipairs(term.ref) do
					local this_refs = require("Module:references").parse_references(refspec)
					for _, this_ref in ipairs(this_refs) do
						table.insert(refs, this_ref)
					end
				end
			end

			local no_rhyme, rhyme_with_cat
			-- Same check as above for colloquial/obsolete/relaxed but check the qualifiers, which are attached to
			-- individual respellings rather than a single-line set of respellings.
			no_rhyme = all_terms_no_rhyme or more_than_one_respelling and (
				doesnt_count_for_rhyme(term.q) or doesnt_count_for_rhyme(term.qq)
			)
			if not no_rhyme then
				local should_generate_rhyme, should_generate_cat = should_generate_rhyme_from_termobj(term)
				no_rhyme = not should_generate_rhyme
				rhyme_with_cat = should_generate_cat
			end
			local pronobj = {
				raw = term.raw,
				phonemic = phonemic,
				phonetic = phonetic,
				refs = refs,
				q = term.q,
				qq = term.qq,
				no_rhyme = no_rhyme,
				rhyme_with_cat = rhyme_with_cat,
			}

			table.insert(parsed.pronuns, pronobj)

			-- If [fvz] present in phonemic pronunciation, generate a "more native-sounding" variant with [pbs] in
			-- place.
			local fvz_pronobj
			if pronobj.phonemic:find("[fvz]") then
				local fvz_charmap = { ["f"] = "p", ["v"] = "b", ["z"] = "s"}
				fvz_pronobj = {
					raw = pronobj.raw,
					phonemic = pronobj.phonemic:gsub("[fvz]", fvz_charmap),
					phonetic = pronobj.phonetic:gsub("[fvz]", fvz_charmap),
					refs = pronobj.refs,
					q = combine_qualifiers(pronobj.q, {"more native-sounding"}),
					qq = pronobj.qq,
					no_rhyme = pronobj.no_rhyme,
					rhyme_with_cat = pronobj.rhyme_with_cat,
					move_to_next_line = true,
				}
				table.insert(parsed.pronuns, fvz_pronobj)
			end
		end

		if not parsed.syll then
			if not overall_syll and any_words_have_vowels(pagename) then
				for _, term in ipairs(parsed.terms) do
					if not term.raw then
						local syllabification = syllabify_from_spelling(term.term, pagename)
						local aligned_syll = align_syllabification_to_spelling(syllabification, pagename)
						if aligned_syll then
							if not parsed.syll then
								parsed.syll = {terms = {}}
							end
							m_table.insertIfNot(parsed.syll.terms, generate_syll_obj(aligned_syll))
						else
							syllabification_alignment_failed = true
						end
					end
				end
			end
		else
			parsed.syll = canonicalize_syllabification(parsed.syll, nil)
		end

		if not parsed.rhyme then
			if overall_rhyme then
				parsed.rhyme = nil
			else
				-- Generate the rhymes.
				for _, pronun in ipairs(parsed.pronuns) do
					-- We should have already excluded multiword terms and terms without vowels from rhyme generation
					-- (see `no_auto_rhyme` below). But make sure to check that pronun.phonemic exists (it may not if
					-- raw phonetic-only pronun is given), and rhyme isn't suppressed (which may happen if the term has
					-- a qualifier "colloquial", "obsolete" or the like or is an auto-generated "glottal stop elision"
					-- pronunciation).
					if pronun.phonemic and not pronun.no_rhyme then
						-- Count number of syllables by looking at syllable boundaries (including stress marks).
						local num_syl = get_num_syl_from_ipa(pronun.phonemic)
						-- Get the rhyme by truncating everything up through the last stress mark + any following
						-- consonants, and remove syllable boundary markers.
						local rhyme = convert_phonemic_to_rhyme(pronun.phonemic)
						-- Copying qualifiers to rhymes:
						-- (1) If there's only one pronunciation, displaying any associated qualifier on the rhyme is
						--     is redundant, so don't do it.
						-- (2) If there are multiple pronunciations, then we generally do want to copy the qualifier(s)
						--     from pronunciation to rhyme, but only if a given rhyme either derives from a single
						--     pronunciation, or derives from multiple pronunciations all of which share the same
						--     qualifier(s). We do NOT want to combine two different qualifiers from two different
						--     pronunciations.
						-- (3) If there are multiple pronunciations that map to a single rhyme, and all pronunciations
						--     share qualifiers, then we might consider omitting the qualifiers as redundant; but this
						--     case will rarely happen so it might not be worth worrying about.
						-- (4) Similarly, if there are multiple pronunciations where some have the rhyme suppressed (see
						--     above), and all pronunciations share qualifiers, then we might consider omitting the
						--     qualifiers as redundant; but again, this case will rarely happen (especially since in
						--     almost all cases the suppressed-rhyme pronunciation will have distinctive qualifiers) so
						--     it probably isn't worth worrying about. Note that in the common case where the qualifiers
						--     of the rhyme-suppressed pronunciation differ from those of the rhyme-included
						--     pronunciation, we do want to include the qualifiers of the rhyme-included pronunciation
						--     (imagine e.g. there are two pronunciations marked "standard" and "colloquial"; we want to
						--     mark the rhyme as "standard").
						-- (4) There are two different types of qualifiers (left and right); when comparing qualifiers,
						--     we need to compare the entire set of both qualifiers and make sure they both match
						--     (although it will be rare to have both left and right qualifiers on a single
						--     pronunciation).
						local saw_already = false
						if not parsed.rhyme then
							parsed.rhyme = {}
						end
						for _, existing in ipairs(parsed.rhyme) do
							if existing.rhyme == rhyme then
								saw_already = true
								-- We already saw this rhyme but possibly with a different number of syllables,
								-- e.g. if the user specified two pronunciations 'biología' (4 syllables) and
								-- 'bi.ología' (5 syllables), both of which have the same rhyme /ia/.
								m_table.insertIfNot(existing.num_syl, num_syl)
								if not m_table.deepEquals(existing.q, pronun.q) or not
									m_table.deepEquals(existing.qq, pronun.qq) then
									existing.q = nil
									existing.qq = nil
								end
								break
							end
						end
						if not saw_already then
							table.insert(parsed.rhyme, {
								rhyme = rhyme,
								num_syl = {num_syl},
								q = #parsed.pronuns > 1 and pronun.q or nil,
								qq = #parsed.pronuns > 1 and pronun.qq or nil,
								nocat = not pronun.rhyme_with_cat,
							})
						end
					end
				end
			end
		else
			local no_rhyme = false
			for _, rhyme in ipairs(parsed.rhyme) do
				if rhyme.rhyme == "-" then
					no_rhyme = true
					break
				end
			end
			if no_rhyme then
				parsed.rhyme = nil
			else
				parsed.rhyme = process_specified_rhymes(parsed.rhyme, parsed.syll and parsed.syll.terms or {}, {parsed})
			end
		end
	end

	if overall_rhyme then
		local no_overall_rhyme = false
		for _, orhyme in ipairs(overall_rhyme) do
			if orhyme.rhyme == "-" then
				no_overall_rhyme = true
				break
			end
		end
		if no_overall_rhyme then
			overall_rhyme = nil
		else
			local all_sylls
			if overall_syll then
				all_sylls = overall_syll
			else
				all_sylls = {}
				for _, parsed in ipairs(parsed_respellings) do
					if parsed.syll then
						for _, syll in ipairs(parsed.syll.terms) do
							m_table.insertIfNot(all_sylls, syll)
						end
					end
				end
			end
			overall_rhyme = process_specified_rhymes(overall_rhyme, all_sylls, parsed_respellings)
		end
	end

	-- Determine whether all sets of pronunciations have the same value for a pronunciation property (rhymes,
	-- syllabifications or homophones). If so, we display them them only once at the bottom, otherwise beneath each set,
	-- indented. This function takes one argument, the name of a slot specifying the pronunciation property, and
	-- returns two values, a boolean indicating whether all values are the same and the first value seen (which will
	-- be the only value seen if all values are the same).
	local function all_sets_equal(parsed_slot)
		local first_set
		local all_sets_eq = true
		for j, parsed in ipairs(parsed_respellings) do
			if j == 1 then
				first_set = parsed[parsed_slot]
			elseif not m_table.deepEquals(first_set, parsed[parsed_slot]) then
				all_sets_eq = false
				break
			end
		end

		return all_sets_eq, first_set
	end

	local all_rhyme_sets_eq, first_rhyme_ret = all_sets_equal("rhyme")
	local all_syll_sets_eq, first_sylls = all_sets_equal("syll")
	local all_hmp_sets_eq, first_hmps = all_sets_equal("hmp")

	------------------------------ 3. Insert categories as appropriate. ---------------------------------

	local categories = {}

	local function get_rhymes_categories(rhymes)
		if not rhymes then
			return
		end
		for _, rhyme in ipairs(rhymes) do

			-- local num_vowels_in_rhyme = #rsub(rhyme.rhyme, NV, "")
			-- local penult = num_vowels_in_rhyme == 2
			-- local glottal = rhyme.rhyme:find("ʔ$")
			-- local pron_cat
			-- if penult and glottal then
			-- 	pron_cat = "malumi"
			-- elseif penult then
			-- 	pron_cat = "malumay"
			-- elseif glottal then
			-- 	pron_cat = "maragsa"
			-- else
			-- 	pron_cat = "mabilis"
			-- end
			-- m_table.insertIfNot(categories,
			-- 	("%s terms with %s pronunciation"):format(lang:getCanonicalName(), pron_cat))
		end
	end

	get_rhymes_categories(overall_rhyme)
	for _, parsed in ipairs(parsed_respellings) do
		get_rhymes_categories(parsed.rhyme)
	end

	local function get_syll_categories(sylls)
		if not sylls then
			return
		end
		for _, syll in ipairs(sylls.terms) do
			local syll_no_dot = "#" .. syll.syllabification .. "#"
			syll_no_dot = syll.syllabification:gsub("%.([^ #])", "%1"):gsub("#", "")
			if syll_no_dot ~= pagename then
				mw.log(("For page '%s', saw syllabification '%s' not matching pagename"):format(
					pagename, syll.syllabification))
				m_table.insertIfNot(categories, ("%s terms with syllabification not matching pagename"):format(
					lang:getCanonicalName()))
			end
		end
	end

	get_syll_categories(overall_syll)
	for _, parsed in ipairs(parsed_respellings) do
		get_syll_categories(parsed.syll)
	end

	if syllabification_alignment_failed then
		table.insert(categories, ("%s terms where syllabification alignment failed"):format(lang:getCanonicalName()))
	end

	---------------------------- 4. Format IPA, rhymes and syllabification for display. -------------------------------

	local function bullet_prefix(num_bullets)
		return string.rep("*", num_bullets) .. " "
	end

	local function format_rhyme(rhymes)
		return require(rhymes_module).format_rhymes {
			lang = lang,
			rhymes = rhymes,
			force_cat = force_cat,
		}
	end

	local function format_syllabifications(syllobj)
		return require(hyphenation_module).format_hyphenations {
			lang = lang,
			hyphs = syllobj.terms,
			caption = syllobj.cap or "Syllabification"
		}
	end

	local function format_homophones(hmps)
		return require("Module:homophones").format_homophones { lang = lang, homophones = hmps }
	end

	local function format_audio(audios, num_bullets)
		local ret = {}
		for i, audio in ipairs(audios) do
			local text = require(audio_module).format_audio {
				lang = lang,
				file = audio.file,
				caption = audio.gloss,
				q = audio.q,
				qq = audio.qq,
				a = audio.a,
				aa = audio.aa,
			}
			table.insert(ret, bullet_prefix(num_bullets) .. text)
		end
		return table.concat(ret, "\n")
	end

	-- Implement grouping by accent. If there is a run of more than one consecutive set of pronunciations with the
	-- same accent, the accent goes on its own line and the pronunciations with this accent go below with an extra
	-- bullet.
	local prev_accents
	local num_seen_with_these_accents
	for j, parsed in ipairs(parsed_respellings) do
		if m_table.deepEquals(prev_accents, parsed.accents) then
			parsed.of_several_accents = "continuation"
			num_seen_with_these_accents = num_seen_with_these_accents + 1
			if num_seen_with_these_accents == 2 then
				parsed_respellings[j - 1].of_several_accents = "first"
			end
		else
			prev_accents = parsed.accents
			num_seen_with_these_accents = 1
		end
	end

	-- Pull out autogenerated pronunciations and move to the next line, indented.
	for _, parsed in ipairs(parsed_respellings) do
		local saw_next_line_pronuns = false
		for _, pronun in ipairs(parsed.pronuns) do
			if pronun.move_to_next_line then
				saw_next_line_pronuns = true
				break
			end
		end
		if saw_next_line_pronuns then
			local this_line_pronuns = {}
			local next_line_pronuns = {}
			for _, pronun in ipairs(parsed.pronuns) do
				if pronun.move_to_next_line then
					table.insert(next_line_pronuns, pronun)
				else
					table.insert(this_line_pronuns, pronun)
				end
			end
			-- Now see if there are qualifiers shared among all elements of the next-line pronuns and deduplicate if so.
			local function deduplicate_qualifiers(field, keepfirst)
				local saw_nil = false
				for _, pronun in ipairs(next_line_pronuns) do
					if not pronun[field] then
						saw_nil = true
						break
					end
				end
				if not saw_nil then
					local m_setutil = require(set_utilities_module)
					local qualifiers = {}
					for _, pronun in ipairs(next_line_pronuns) do
						table.insert(qualifiers, m_setutil.list_to_set(pronun[field]))
					end
					local all_shared = m_setutil.intersect(unpack(qualifiers))
					if next(all_shared) then
						local first_index, last_index
						if keepfirst then
							first_index = 2
							last_index = #pronun
						else
							first_index = 1
							last_index = #pronun - 1
						end
						for i = first_index, last_index do
							local pronun = next_line_pronuns[i]
							local new_qualifiers = {}
							for _, q in ipairs(pronun[field]) do
								if not all_shared[q] then
									table.insert(new_qualifiers, q)
								end
							end
							pronun[field] = new_qualifiers
						end
					end
				end
			end
			parsed.pronuns = this_line_pronuns
			parsed.next_line_pronuns = next_line_pronuns
		end
	end

	-- Now actually format the pronunciations.
	local textparts = {}
	local first_line = true
	local function ins_line(linetext, num_bullets)
		if not first_line then
			table.insert(textparts, "\n")
		end
		first_line = false
		table.insert(textparts, bullet_prefix(num_bullets) .. linetext)
	end
	local min_num_bullets = 9999
	for j, parsed in ipairs(parsed_respellings) do
		if parsed.bullets < min_num_bullets then
			min_num_bullets = parsed.bullets
		end
		local accent_grouping_offset = 0
		if parsed.of_several_accents == "first" then
			ins_line(require(accent_qualifier_module).format_qualifiers(lang, parsed.accents), parsed.bullets)
		end
		local pronuns = format_pronun_line(parsed)
		local accent_prefix
		if not parsed.of_several_accents then
			accent_prefix = require(accent_qualifier_module).format_qualifiers(lang, parsed.accents) .. " "
		else
			accent_prefix = ""
			accent_grouping_offset = 1
		end
		ins_line(accent_prefix .. pronuns, parsed.bullets + accent_grouping_offset)
		if parsed.next_line_pronuns then
			ins_line(format_pronuns(parsed.next_line_pronuns), parsed.bullets + accent_grouping_offset + 1)
		end
		if parsed.audio then
			-- format_audio() inserts multiple lines and handles bullets by itself.
			table.insert(textparts, "\n")
			-- If only one pronunciation set, add the audio with the same number of bullets, otherwise indent audio by
			-- one more bullet.
			table.insert(textparts, format_audio(parsed.audio,
				(#parsed_respellings == 1 and parsed.bullets or parsed.bullets + 1) + accent_grouping_offset))
		end
		if not all_rhyme_sets_eq and parsed.rhyme then
			ins_line(format_rhyme(parsed.rhyme), parsed.bullets + 1 + accent_grouping_offset)
		end
		if not all_syll_sets_eq and parsed.syll then
			ins_line(format_syllabifications(parsed.syll), parsed.bullets + 1 + accent_grouping_offset)
		end
		if not all_hmp_sets_eq and parsed.hmp then
			ins_line(format_homophones(parsed.hmp), parsed.bullets + 1 + accent_grouping_offset)
		end
	end
	if overall_audio then
		-- format_audio() inserts multiple lines and handles bullets by itself.
		table.insert(textparts, "\n")
		table.insert(textparts, format_audio(overall_audio, min_num_bullets))
	end
	if all_rhyme_sets_eq and first_rhyme_ret then
		ins_line(format_rhyme(first_rhyme_ret), min_num_bullets)
	end
	if overall_rhyme then
		ins_line(format_rhyme(overall_rhyme), min_num_bullets)
	end
	if all_syll_sets_eq and first_sylls then
		ins_line(format_syllabifications(first_sylls), min_num_bullets)
	end
	if overall_syll then
		ins_line(format_syllabifications(overall_syll), min_num_bullets)
	end
	if all_hmp_sets_eq and first_hmps then
		ins_line(format_homophones(first_hmps), min_num_bullets)
	end
	if overall_hmp then
		ins_line(format_homophones(overall_hmp), min_num_bullets)
	end

	return table.concat(textparts) ..
		require("Module:utilities").format_categories(categories, lang, nil, nil, force_cat)
end

-- Meant to be called from a bot.
function export.pron_json(frame)
	local iparams = {
		[1] = {list = true, required = true},
		["pagename"] = {required = true},
	}
	local iargs = require("Module:parameters").process(frame.args, iparams)
	local data = {}
	local syllabification_from_pagename = syllabify_from_spelling(iargs.pagename, iargs.pagename)
	for _, respelling in ipairs(iargs[1]) do
		local pronun = export.IPA(respelling, "include phonemic syllable boundaries")
		local syllabification = export.syllabify_and_align(respelling, iargs.pagename)
		local num_syl = get_num_syl_from_ipa(pronun.phonemic)
		local rhyme = convert_phonemic_to_rhyme(pronun.phonemic)
		table.insert(data, {
			respelling = respelling,
			phonemic = pronun.phonemic,
			phonetic = pronun.phonetic,
			syllabification = syllabification,
			num_syl = num_syl,
			rhyme = rhyme,
		})
	end
	local retval = {
		pagename = iargs.pagename,
		syllabification_from_pagename = syllabification_from_pagename,
		data = data,
	}
	return require("Module:JSON").toJSON(retval)
end

return export
