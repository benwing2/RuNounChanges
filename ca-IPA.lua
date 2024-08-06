local export = {}

local lang = require("Module:languages").getByCode("ca")

local m_IPA = require("Module:IPA")
local m_table = require("Module:table")

local parse_utilities_module = "Module:parse utilities"
local strutil_module = "Module:string utilities"

local listToSet = require("Module:table").listToSet

--[=[
FIXME:

1. [zʒ] should reduce to [ʒ] in Central and Balearic ([[disjunt]], [[disjuntor]]). Similar for [sʃ]
   ([[desxifrar]]). [DONE]
2. There needs to be a way of forcing [ʃ]. (Maybe just ʃ?) [DONE]
3. Make sure manual dot for syllable break works, cf. [[best-seller]] respelled `bèst.sèlerr'. [DONE]
4. Explicit accents on a/i/u should be removed in split_syllables(). [NOT DONE; not needed]
5. Compress double schwa in Central/Balearic in e.g. [[sobreescalfament]], [[centreafricà]], [[contraatac]],
   [[contraescarpa]]; seems not to operate in Valencian.
6. Compress unstressed <ie> and <oe> followed by coda consonant -> [u] in Central/Balearic in e.g. [[aeroespacial]],
   [[autoescola]], [[antiespasmòdic]], but not [[autoerotisme]], [[antiemètic]]; seems not to operate in Valencian.
   NOTE: It does operate in an open syllable in [[fotoelèctric]], [[fotoelectricitat]], [[macroeconomia]]; not sure why.
7. Compress unstressed <oo> followed by a coda consonant -> [u] in Central/Balearic in e.g. [[microorganisme]]. Seems
   not to operate in Valencian.
8. bm -> [mm] e.g. [[subministrament]]; seems not to operate in Valencian.
9. ë (and presumably ê) doesn't work in secondary stress, always becomes /ɛ/ (e.g. in [[extrajudicial]] respelled
   'ëxtrajudiciàl'; this seems to be because the handling of ë goes through mid_vowel_hint, which doesn't work for
   secondary stress. [DONE]
10. Respect ʃ at beginning of word in Valencian. [DONE]
11. [ʃ] in single substitution specs should match against written x. [DONE]
12. Prefixes e.g. [[xilo-]] should not have stress by default, and written primary stresses should be converted to
    secondary. [DONE]
13. Convert apostrophe near beginning to tie (‿) and make sure we take account of it later, so that words like
	[[captindre's]] and phrases like [[dona d'aigua]] work correctly. [DONE]
14. Correctly handle -bl and -gl in respelling, generating [bl] and [gl]. [NOT DONE; use _bl, _gl]
15. Correctly handle [βðɣ] in respelling forcing fricatives; should not be fortitioned. [NOT DONE; not needed]
16. [βðɣ] in single substitution specs should match against b/d/g. [NOT DONE; not needed]
17. [ss] in single substitution specs should match against ss?; used to force a pronounced [s]. [DONE]
18. [dm] in single substitution specs should match against [td]m. [NOT DONE; not needed]
19. Correctly handle written -dg- after [rz]: fricatives in Valencian, stops in Central (and Balearic?). [DONE]
20. Correctly handle lenition of written -bdg-: (1) -b- not lenited in Valencian or Balearic, lenited to [β] in
    Central Catalan after vowels and consonants except nasals and [rz]; (2) -g- not lenited after nasals, also not
	after [rz] in Central Catalan (and maybe Balearic?), otherwise yes except utterance initial; (3) -d- not lenited
	after nasals or laterals, also not after [rz] in Central Catalan (and maybe Balearic?), otherwise yes except
	utterance initial. Verify against ca-IPA equivalent on cawikt and also based on {{w|Catalan phonology}} and the IEC
	grammar that Vriullop linked. [DONE]
21. Finish rewriting do_dialect_specific() to operate on whole word using Lua patterns. [DONE]
22. Implement multiword handling. [DONE]
23. Make sure suffix handling works correctly. [DONE]
24. Add many more test cases and redo test harness ala the German test harness. [DONE]
25. Redo handling of mid-vowel hints so it gets done early and in one place. [DONE]
26. Think about how to solve the issue of mid-vowel hints along with secondary stress marks in substitution specs.
    Maybe a single mid-vowel spec should be rewritten to be a single substitution spec and the insertion of the
	mid-vowel spec should happen during resolution of substitution specs. [DONE]
27. <tm> should default to [dm] not [mm]. [DONE]
28. Fix handling of mid vowel default in -è/-ès/-esa so it doesn't affect [[tèbia]] etc. [DONE]
29. x- after hyphen should probably become tx- in Valencian, cf. [[para-xocs]]. [DONE]
30. Implement DOTOVER to indicate lack of stress in a word, e.g. in a suffix. [DONE]
31. Handle words without vowels. [DONE]
32. Finish reviewing places where we may need to check for tie symbols.
33. Handle tie indicating liaison in e.g. [[Sant Antoni de Portmany]]. [DONE]
34. Handle pronunciation of [[amb]] correctly. [DONE]
35. Handle tie indicating liaison before h- correctly, e.g. [[Sant Hipòlit]]. [DONE]
36. Lenition should happen in Valencian in [[regla]] whether respelled 'réggla', 'régla' or 'rég_la'. [DONE]
37. Syllabification should happen correctly when underscore is used in 'bíb_lia' to block doubling of <bl>. [DONE]
38. <cn> should show up as [ŋn]. [DONE]
39. Delete [t] after [s] before anything but [s] ([[best-seller]]) or [ɾ] ([[postrem]]). [DONE]
40. Delete <t/d> after <n> before consonant even in Valencian; likewise for <p/b> after <m>, <c/g> after <n>. [DONE]
41. DOTOVER in single substitution specs should work. [DONE]
42. Underline in single substitution specs should work. [DONE]
43. LINEUNDER should work to indicate secondary stress after the primary stress, including in single substitution
    specs. [DONE]
]=]


local usub = mw.ustring.sub
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local rsubn = mw.ustring.gsub
local ulower = mw.ustring.lower
local u = require("Module:string/char")
local ugcodepoint = mw.ustring.gcodepoint


export.dialects = {"bal", "cen", "val"}
export.dialects_to_names = {
	bal = "Balearic",
	cen = "Central Catalan",
	val = "Valencian",
}
export.dialect_groups = {
	east = {"bal", "cen"},
}


local written_unaccented_vowel_l = "aeiouyAEIOUY"
local written_stressed_vowel_l = "àèéêëíòóôúýÀÈÉÊËÍÒÓÔÚÝ"
local written_accented_not_stressed_vowel_l = "ïüÏÜ"
local written_accented_vowel_l = written_stressed_vowel_l .. written_accented_not_stressed_vowel_l
local ipa_vowel_l = "ɔɛə"
local written_vowel_l = written_unaccented_vowel_l .. written_accented_vowel_l
local vowel_l = written_vowel_l .. ipa_vowel_l
local V = "[" .. vowel_l .. "]"
local written_accented_to_plain_vowel = {
	["à"] = "a",
	["è"] = "e",
	["é"] = "e",
	["ê"] = "e",
	["ë"] = "e",
	["í"] = "i",
	["ï"] = "i",
	["ò"] = "o",
	["ó"] = "o",
	["ô"] = "o",
	["ú"] = "u",
	["ü"] = "u",
	["ý"] = "y",
	["À"] = "A",
	["È"] = "E",
	["É"] = "E",
	["Ê"] = "E",
	["Ë"] = "E",
	["Í"] = "I",
	["Ï"] = "I",
	["Ò"] = "O",
	["Ó"] = "O",
	["Ô"] = "O",
	["Ú"] = "U",
	["Ü"] = "U",
	["Ý"] = "Y",
}

local AC = u(0x0301) -- acute =  ́
local GR = u(0x0300) -- grave =  ̀
local CFLEX = u(0x0302) -- circumflex =  ̂
local DOTOVER = u(0x0307) -- dot over =  ̇
local DIA = u(0x0308) -- diaeresis =  ̈
local LINEUNDER = u(0x0331) -- lineunder =  ̱

local stress_l = AC .. GR
local stress_c = "[" .. stress_l .. "]"
local ipa_stress_l = "ˈˌ"
local ipa_stress_c = "[" .. ipa_stress_l .. "]"
local sylsep_l = "%-." -- hyphen included for syllabifying from spelling; FIXME: formerly included SYLDIV
local sylsep_c = "[" .. sylsep_l .. "]"
local tie_l = "‿'"
local tie_c = "[" .. tie_l .. "]"
local charsep_l = sylsep_l .. tie_l .. stress_l .. ipa_stress_l
local charsep_c = "[" .. charsep_l .. "]"
local wordsep_l = "# "
local wordsep_c = "[" .. wordsep_l .. "]"
local separator_l = charsep_l .. wordsep_l
local separator_c = "[" .. separator_l .. "]"
local neg_guts_of_cons = vowel_l .. separator_l
local C = "[^" .. neg_guts_of_cons .. "]" -- consonant class including h

export.mid_vowel_hints = "éèêëóòô"
export.mid_vowel_hint_c = "[" .. export.mid_vowel_hints .. "]"

local TEMP_PAREN_R = u(0xFFF1)
local TEMP_PAREN_RR = u(0xFFF2)
-- Pseudo-consonant at the edge of prefixes ending in a vowel and suffixes beginning with a vowel; FIXME: not currently
-- used.
local PSEUDOCONS = u(0xFFF3)
-- local PREFIX_MARKER = u(0xFFF4) -- marker indicating a prefix so we can convert primary to secondary accents


local valid_onsets = listToSet {
	"b", "bl", "br",
	"c", "cl", "cr",
	"ç",
	"d", "dj", "dr",
	"f", "fl", "fr",
	"g", "gl", "gr", "gu", "gü",
	"h",
	"i",
	"j",
	"k", "kl", "kr",
	"l", "ll",
	"m",
	"n", "ny", "ñ",
	"p", "pl", "pr",
	"qu", "qü",
	"r", "rr",
	"s", "ss",
	"t", "tg", "tj", "tr", "tx", "tz",
	"u",
	"v", "vl", "vr",
	"w",
	"x",
	"ʃ", -- e.g. 'χruʃóf' respelling of [[Khrusxov]]
	"χ", -- in case of respelling
	"y",
	"z",
} 

local decompose_dotover = {
	-- No composed i, u or U with DOTOVER.
	["ȧ"] = "a" .. DOTOVER,
	["ė"] = "e" .. DOTOVER,
	["ȯ"] = "o" .. DOTOVER,
	["ẏ"] = "y" .. DOTOVER,
	["Ȧ"] = "A" .. DOTOVER,
	["Ė"] = "E" .. DOTOVER,
	["İ"] = "I" .. DOTOVER,
	["Ȯ"] = "O" .. DOTOVER,
	["Ẏ"] = "Y" .. DOTOVER,
}

local unstressed_words = listToSet {
	-- proclitic object pronouns
	"em", "et", "es", "el", "la", "els", "les", "li", "ens", "us", "ho", "hi", "en",
	-- enclitic object pronouns usually attach with hyphen to preceding verb but not always, cf. [[tant me fa]]
	"me", "te", "se", "lo", "los", "nos", "vos", "ne",
	-- contracted object pronouns and articles attached with apostrophe so no need to include
	-- unstressed possessives
	"mon", "ma", "mos", "mes", "ton", "ta", "tos", "tes", "son", "sa", "sos", "ses",
	-- prepositions
	"a", "de", "per", "amb", "ab", -- 'en' already included as proclitic object pronouns
	-- prepositional contractions
	"al", "als", "del", "dels", "pel", "pels",
	-- articles 'el', 'la', 'els', 'les' already included as proclitic pronouns
	-- personal articles
	"na", -- 'en' already included above
	-- indefinite articles
	"un", "uns",
	-- salat articles
	"ets", "so", -- 'es' already included as proclitic object pronouns and 'ses', 'sa', 'sos' as possessives
	-- conjunctions
	"i", "o", "si", "ni", "que",
}

-- Version of rsubn() that discards all but the first return value.
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

-- Version of rsubn() that returns a 2nd argument boolean indicating whether a substitution was made.
local function rsubb(term, foo, bar)
	local retval, nsubs = rsubn(term, foo, bar)
	return retval, nsubs > 0
end

-- Apply rsub() repeatedly until no change.
local function rsub_repeatedly(term, foo, bar)
	while true do
		local new_term = rsub(term, foo, bar)
		if new_term == term then
			return term
		end
		term = new_term
	end
end

local function split_into_chars(text)
	local chars = {}
	for codepoint in ugcodepoint(text) do
		table.insert(chars, u(codepoint))
	end
	return chars
end

local function split_on_comma(term)
	if term:find(",%s") or term:find("\\") then
		return require(parse_utilities_module).split_on_comma(term)
	else
		return rsplit(term, ",")
	end
end

local function concat_keys(tab)
	local res = {}
	for k, _ in pairs(tab) do
		table.insert(res, k)
	end
	return table.concat(res)
end


local function handle_unstressed_words(words)
	words = m_table.deepcopy(words)

	-- Lowercase all words for ease in further processing.
	for i, wordobj in ipairs(words) do
		wordobj.term = ulower(wordobj.term)
	end

	-- Check if the word at index `i` in `words` is "amb" and the following word begins with a vowel.
	local function is_amb_to_join(words, i)
		return i < #words and words[i].term == "a" .. DOTOVER .. "mb" and rfind(words[i + 1].term, "^h?" .. V)
	end
	local saw_amb_to_join = true

	-- Mark all unstressed words with DOTOVER, so that split_syllables() doesn't assign stress. We need to do this
	-- before special handling for [[amb]], because [[amb]] may join to another unstressed word like [[el]], in the
	-- process losing the identity of the two words. In the process, see if [[amb]] occurs before a following
	-- vowel-initial word (which may begin with h-).
	for i, wordobj in ipairs(words) do
		-- Put DOTOVER after the last vowel (to handle the case of [[que]]). It doesn't actually matter where we put
		-- it, because split_syllables() just looks for DOTOVER anywhere in the word.
		if unstressed_words[wordobj.term] then
			wordobj.term = rsub(wordobj.term, "^(.*" .. V .. ")", "%1" .. DOTOVER)
		end
		if is_amb_to_join(words, i) then
			saw_amb_to_join = true
		end
	end

	-- Join [[amb]] before vowel-initial word with following word.
	if saw_amb_to_join then
		local new_words = {}
		local i = 1
		while i <= #words do
			if is_amb_to_join(words, i) then
				table.insert(new_words, {term = words[i].term .. "‿" .. words[i + 1].term, pos = words[i + 1].pos})
				i = i + 2
			else
				table.insert(new_words, words[i])
				i = i + 1
			end
		end
		words = new_words
	end

	-- Finally, rewrite some unstressed words to get the right pronunciation. Any remaining [[amb]] not before a
	-- vowel-initial word is pronounced [am] even in Valencian (where [amp]/[amb] would be expected), and [[per]] always
	-- has a pronounced <r>.
	local unstressed_word_replacement = {
		["a" .. DOTOVER .. "mb"] = "a" .. DOTOVER .. "m",
		["pe" .. DOTOVER .. "r"] = "pe" .. DOTOVER .. "rr",
	}

	for i, wordobj in ipairs(words) do
		wordobj.term = unstressed_word_replacement[wordobj.term] or wordobj.term
	end

	return words
end


local function fix_prefixes(word)
	-- Voiced s in prefix roots -fons-, -dins-, -trans-
	word = rsub(word, "^enfons([aàeèéiíoòóuú])", "enfonz%1")
	word = rsub(word, "^endins([aàeèéiíoòóuú])", "endinz%1")
	word = rsub(word, "tr([aà])ns([aàeèéiíoòóuúbdghlmv])", "tr%1nz%2")

	-- in + ex > ineks/inegz
	word = rsub(word, "^inex", "in.ex")

	return word
end

local function restore_diaereses(word)
	-- Some structural forms do not have diaeresis per diacritic savings, let's restore it to identify hiatus

	word = rsub(word, "([iu])um(s?)$", "%1üm%2") -- Latinisms (-ius is ambiguous but rare)

	word = rsub(word, "([aeiou])isme(s?)$", "%1ísme%2") -- suffix -isme
	word = rsub(word, "([aeiou])ist([ae]s?)$", "%1íst%2") -- suffix -ista

	word = rsub(word, "([aeou])ir$", "%1ír") -- verbs -ir
	word = rsub(word, "([aeou])int$", "%1ínt") -- present participle
	word = rsub(word, "([aeo])ir([éà])$", "%1ïr%2") -- future
	word = rsub(word, "([^gq]u)ir([éà])$", "%1ïr%2")
	word = rsub(word, "([aeo])iràs$", "%1ïràs")
	word = rsub(word, "([^gq]u)iràs$", "%1ïràs")
	word = rsub(word, "([aeo])ir(e[mu])$", "%1ïr%2")
	word = rsub(word, "([^gq]u)ir(e[mu])$", "%1ïr%2")
	word = rsub(word, "([aeo])iran$", "%1ïran")
	word = rsub(word, "([^gq]u)iran$", "%1ïran")
	word = rsub(word, "([aeo])iria$", "%1ïria") -- conditional
	word = rsub(word, "([^gq]u)iria$", "%1ïria")
	word = rsub(word, "([aeo])ir(ie[sn])$", "%1ïr%2")
	word = rsub(word, "([^gq]u)ir(ie[sn])$", "%1ïr%2")

	return word
end

local function fix_y(word)
	-- y > vowel i else consonant /j/, except ny

	word = rsub(word, "ny", "ñ")

	word = rsub(word, "y([^aeiouàèéêëíòóôúïü])", "i%1") -- vowel if not next to another vowel
	word = rsub(word, "([^aeiouàèéêëíòóôúïü·%-%.])y", "%1i") -- excluding also syllables separators

	return word
end

local function mid_vowel_fixes(word)
	local function track_mid_vowel(vowel, cont)
		require("Module:debug/track"){"ca-IPA/" .. vowel, "ca-IPA/" .. vowel .. "/" .. cont}
		return true
	end
	local changed
	-- final -el (not -ell) usually è but not too many cases
	word, changed = rsubb(word, "e(nts?)$", "é%1")
	if changed then
		track_mid_vowel("e", "nt-nts")
	end
	word, changed = rsubb(word, "e(rs?)$", "é%1")
	if changed then
		track_mid_vowel("e", "r-rs")
	end
	word, changed = rsubb(word, "o(rs?)$", "ó%1")
	if changed then
		track_mid_vowel("o", "r-rs")
	end
	word, changed = rsubb(word, "è(s?)$", "ê%1")
	if changed then
		track_mid_vowel("è", "s-blank")
	end
	word, changed = rsubb(word, "e(s[oe]s)$", "ê%1")
	if changed then
		track_mid_vowel("e", "sos-sa-ses")
	end
	word, changed = rsubb(word, "e(sa)$", "ê%1")
	if changed then
		track_mid_vowel("e", "sos-sa-ses")
	end
	return word
end

local function word_fixes(word, dialect)
	word = rsub(word, "%(rr%)", TEMP_PAREN_RR)
	word = rsub(word, "%(r%)", TEMP_PAREN_R)
	word = rsub(word, "%-([rs]?)", "-%1%1")
	if dialect == "val" then
		word = rsub(word, "%-x", "-tx")
	end
	word = rsub(word, "rç$", "rrs") -- silent r only in plurals -rs
	word = fix_prefixes(word) -- internal pause after a prefix
	word = restore_diaereses(word) -- no diaeresis saving
	word = fix_y(word) -- ny > ñ else y > i vowel or consonant
	word = mid_vowel_fixes(word)
	-- all words in pn- (e.g. [[pneumotòrax]] and mn- (e.g. [[mnemònic]]) have silent p/m in both Central and Valencian
	word = rsub(word, "^[pm]n", "n")
	-- Respell ch + vowel as tx, before we remove other h's after consonants.
	word = rsub(word, "ch(" .. V ..")", "tx%1")
	-- Delete h after a consonant. This must happen here, before split_syllables(). We don't delete h after a vowel
	-- yet because it indicates a hiatus.
	word = rsub(word, "(" .. C .. ")h", "%1")

	return word
end

local function split_vowels(vowels, saw_dotover, saw_lineunder)
	local syllables = {{onset = "", vowel = usub(vowels, 1, 1), coda = "", separator = "", has_dotover = saw_dotover,
		has_lineunder = saw_lineunder}}
	vowels = usub(vowels, 2)

	while vowels ~= "" do
		local syll = {onset = "", vowel = "", coda = ""}
		syll.onset, syll.vowel, vowels = rmatch(vowels, "^([iu]?)(.)(.-)$")
		table.insert(syllables, syll)
	end

	local count = #syllables

	if count >= 2 and (syllables[count].vowel == "i" or syllables[count].vowel == "u") then
		syllables[count - 1].coda = syllables[count].vowel
		syllables[count] = nil
	end

	return syllables
end

-- Split the word into syllables. Return a list of syllable objects, each of which contains fields `onset`, `vowel`,
-- `coda`, `separator` (a user-specified syllable divider that goes before the syllable; one of '·', '-' or '.') and
-- `stressed` (a boolean indicating that the syllable is stressed). In addition, the list has fields `stress` (the
-- index of the syllable with primary stress) and `is_prefix` (true if the word is a prefix, i.e. it ends in '-').
-- Normally, prefixes are treated as unstressed if a stressed syllable isn't explicitly marked, but this can be
-- overridden with `stress_prefixes`, which causes the automatic stress-assignment algorithm to run for these terms.
local function split_syllables(word, stress_prefixes, may_be_uppercase)
	local syllables = {}
	local saw_dotover = false

	local remainder = word
	local is_prefix = false
	if remainder:find("%-$") then -- prefix
		is_prefix = true
		remainder = remainder:gsub("%-$", "")
	end
	local is_suffix = false
	if remainder:find("^%-") then -- suffix
		is_suffix = true
		remainder = remainder:gsub("^%-", "")
	end

	while remainder ~= "" do
		local consonants, vowels

		-- FIXME: Using C and V below instead of the existing patterns slows things down TREMENDOUSLY.
		-- Not sure why.
		local vowel_list = may_be_uppercase and "aeiouàèéêëíòóôúïüAEIOUÀÈÉÊËÍÒÓÔÚÏÜ" .. DOTOVER .. LINEUNDER or
			"aeiouàèéêëíòóôúïü" .. DOTOVER .. LINEUNDER
		consonants, remainder = rmatch(remainder, "^([^" .. vowel_list .. "]*)(.-)$")
		vowels, remainder = rmatch(remainder, "^([" .. vowel_list .. "]*)(.-)$")
		local this_saw_dotover = not not rfind(vowels, DOTOVER)
		if this_saw_dotover then
			saw_dotover = true
			vowels = vowels:gsub(DOTOVER, "")
		end
		local this_saw_lineunder = not not rfind(vowels, LINEUNDER)
		if this_saw_lineunder then
			vowels = vowels:gsub(LINEUNDER, "")
		end

		if vowels == "" then
			if #syllables > 0 then
				syllables[#syllables].coda = syllables[#syllables].coda .. consonants
			else
				-- word without vowels, e.g. foot boundary |
				table.insert(syllables, {onset = consonants, vowel = "", coda = "", separator = ""})
			end
		else
			local onset = consonants
			local first_vowel = usub(vowels, 1, 1)

			if (rfind(onset, "[gqGQ]$") and (first_vowel == "ü" or (first_vowel == "u" and vowels ~= "u")))
			or ((onset == "" or onset == "h" or onset == "H") and #syllables == 0 and
				(first_vowel == "i" or first_vowel == "I") and (vowels ~= "i" and vowels ~= "I"))
			then
				onset = onset .. usub(vowels, 1, 1)
				vowels = usub(vowels, 2)
			end

			local vsyllables = split_vowels(vowels, this_saw_dotover, this_saw_lineunder)
			vsyllables[1].onset = onset .. vsyllables[1].onset

			for _, s in ipairs(vsyllables) do
				table.insert(syllables, s)
			end
		end
	end

	-- Shift over consonants from the onset to the preceding coda, until the syllable onset is valid
	for i = 2, #syllables do
		local current = syllables[i]
		local previous = syllables[i-1]

		while not (current.onset == "" or valid_onsets[rsub(rsub(current.onset, tie_c .. "[hH]?$", ""), "_", "")]) do
			local letter = usub(current.onset, 1, 1)
			current.onset = usub(current.onset, 2)
			if rfind(letter, "[·%-%.]") then -- syllable separators
				current.separator = letter
				break
			else
				previous.coda = previous.coda .. letter
				if rfind(letter, tie_c) then
					break
				end
			end
		end
	end

	-- Detect stress
	for i, syll in ipairs(syllables) do
		if rfind(syll.vowel, "^[" .. written_stressed_vowel_l .. "]$") then
			syll.stressed = true
			-- primary stress: the last one stressed without LINEUNDER
			if not syll.has_lineunder then
				syllables.stress = i
			end
		end
	end

	-- Assign default stress
	if not syllables.stress and not saw_dotover and (stress_prefixes or not is_prefix) then
		local count = #syllables

		if count == 1 then
			if syllables[1].vowel ~= "" then -- vowel-less words don't get stress
				syllables.stress = 1
			end
		else
			local final = syllables[count]

			-- Take account of tie symbols (apostrophes and ‿).
			if rfind(final.coda, "^[s" .. tie_l .. "]*$") or (rfind(final.coda, "^" .. tie_c .. "*n" .. tie_c .. "*$") and (
				final.vowel == "e" or final.vowel == "i" or final.vowel == "ï")) then
				syllables.stress = count - 1
			else
				syllables.stress = count
			end
		end
		if syllables.stress then
			syllables[syllables.stress].stressed = true
		end
	end

	syllables.is_prefix = is_prefix
	syllables.is_suffix = is_suffix
	return syllables
end

local function reconstitute_word_from_syllables(syllables)
	local parts = {}
	local function ins(txt)
		table.insert(parts, txt)
	end
	if syllables.is_suffix then
		ins("-")
	end
	for _, syl in ipairs(syllables) do
		ins(syl.separator)
		ins(syl.onset)
		ins(syl.vowel)
		if syl.has_dotover then
			ins(DOTOVER)
		end
		if syl.has_lineunder then
			ins(LINEUNDER)
		end
		ins(syl.coda)
	end
	if syllables.is_prefix then
		ins("-")
	end
	return table.concat(parts)
end

local function decompose_respelling(text)
	local dotover_keys = concat_keys(decompose_dotover)
	return rsub(text, "[" .. dotover_keys .. "]", decompose_dotover)
end

local function canon_respelling(text)
	local function canon_spaces(text)
		text = rsub(text, "%s+", " ")
		text = rsub(text, "^ ", "")
		text = rsub(text, " $", "")
		return text
	end

	text = canon_spaces(text)
	-- eliminate upside down punctuation
	text = rsub(text, "[¡¿]", "")
	-- eliminate utterance-final punctuation
	text = rsub(text, "[!?.]$", "")
	-- eliminate double and triple quotes
	text = rsub(text, "''+", "")
	-- Convert commas and em/en dashes to IPA foot boundaries; require a space after commas and en dashes (for the
	-- latter, in particular, to avoid treating the en dash in 'Bose–Einstein condensate' as a foot boundary.
	text = rsub(text, " *[,–] ", " | ")
	text = rsub(text, " *[—] *", " | ")
	-- ... in phrases like [[com es diu...en català]] and [[necessito ...]] become foot boundaries
	text = rsub(text, " *%.%.%. *", " | ")
	-- remaining commas and en dashes become spaces
	text = rsub(text, "[,–]", " ")
	-- may need to eliminate extraneous spaces again, e.g. if there was a space before or after an eliminated
	-- punctuation mark
	text = canon_spaces(text)
	-- question mark or exclamation point in the middle of a sentence -> IPA foot boundary
	text = rsub(text, "([^ ]) *[!?] *([^ ])", "%1 | %2")
	return text
end


local IPA_vowels_central = {
	["ê"] = "ɛ", ["ë"] = "ɛ", ["ô"] = "ɔ",
}
local IPA_vowels_balearic = {
	["ê"] = "ə", ["ë"] = "ɛ", ["ô"] = "ɔ",
}
local IPA_vowels_valencian = {
	["ê"] = "e", ["ë"] = "e", ["ô"] = "o",
}

local IPA_vowels = {
	["à"] = "a",
	["è"] = "ɛ", ["ê"] = "ɛ", ["ë"] = "ɛ", ["é"] = "e",
	["í"] = "i", ["ï"] = "i",
	["ò"] = "ɔ", ["ô"] = "ɔ", ["ó"] = "o",
	["ú"] = "u", ["ü"] = "u",
}

local function replace_context_free(cons)
	cons = rsub(cons, "ŀ", "l")

	cons = rsub(cons, "r", "ɾ")
	cons = rsub(cons, "ɾɾ", "r")
	cons = rsub(cons, "ss", "s")
	cons = rsub(cons, "ll", "ʎ")
	cons = rsub(cons, "ñ", "ɲ") -- hint ny > ñ

	-- NOTE: We use single-character affricate symbols during processing for ease in handling, and convert them
	-- to tied multi-character affricates at the end of join_syllables().
	cons = rsub(cons, "[dt]j", "ʤ")
	cons = rsub(cons, "tx", "ʧ")
	cons = rsub(cons, "[dt]z", "ʣ")

	cons = rsub(cons, "ç", "s")
	cons = rsub(cons, "[cq]", "k")
	cons = rsub(cons, "h", "")
	cons = rsub(cons, "j", "ʒ")
	-- Don't replace x -> ʃ yet so we can distinguish x from manually specified ʃ.

	cons = rsub(cons, "i", "j") -- must be after j > ʒ
	cons = rsub(cons, "y", "j") -- must be after j > ʒ and fix_y
	cons = rsub(cons, "[uü]", "w")
	cons = rsub(cons, "'", "‿")

	return cons
end


-- Do context-sensitive phonological changes. Formerly this was all done syllable-by-syllable but that made the code
-- tricky (since it often had to look at adjacent syllables) and full of subtle bugs. Now we first concatenate the
-- syllables back to words and the words to the combined text and work on the text as a whole. FIXME: We should move
-- more of the work done in preprocess_word(), e.g. most of replace_context_free(), here.
local function postprocess_general(text, dialect)
	local function verify(cond, msg)
		if not cond then
			error(("Internal error: %s; processed respelling at this point is '%s'"):format(msg, text))
		end
		return true
	end

	local voiced = listToSet {"b", "d", "g", "m", "n", "ɲ", "l", "ʎ", "r", "ɾ", "v", "z", "ʒ", "ʣ", "ʤ"}
	local voiced_keys = concat_keys(voiced)
	local voiceless = listToSet {"p", "t", "k", "f", "s", "ʃ", "ʦ", "ʧ"}
	local voiceless_keys = concat_keys(voiceless)
	local voicing = {["p"] = "b", ["t"] = "d", ["k"] = "g", ["f"] = "v", ["s"] = "z", ["ʃ"] = "ʒ", ["ʦ"] = "ʤ",
		["ʧ"] = "ʤ"}
	local voicing_keys = concat_keys(voicing)
	local devoicing = {}
	for k, v in pairs(voicing) do
		devoicing[v] = k
	end
	local devoicing_keys = concat_keys(devoicing)

	------------------ Handle <x>

	-- Handle ex- + vowel > -egz-. We handle -x- on either side of the syllable boundary. Note that this also handles
	-- inex- + vowel because in fix_prefixes we respell inex- as in.ex-, which ends up at this stage as in.e.xV.
	text = rsub_repeatedly(text, "([.#][eɛ]" .. stress_c .. "*)(" .. charsep_c .. "*)x(" .. charsep_c .. "*" .. V ..
		")", function(e, pre, post)
			-- Preserve other character separators (especially the tie character ‿).
			pre = pre:gsub("%.", "")
			post = post:gsub("%.", "")
			return e .. pre .. "g.z" .. post
		end)
	-- -x- at the beginning of a coda becomes [ks], e.g. [[annex]], [[apèndix]], [[extracció]]; but not elsewhere in
	-- the coda, e.g. in [[romanx]], [[ponx]]; words with [ks] in -nx such as [[esfinx]], [[linx]], [[manx]] need
	-- respelling with [ks]; words ending in vowel + x like [[ídix]] need respelling with [ʃ]
	text = rsub(text, "(" .. V .. stress_c .. "*)x", "%1ks")
	if dialect == "val" then
		-- Word-initial <x> as well as <x> after a consonant other than /j/ (including in the coda, e.g. [[ponx]])
		-- becomes [t͡ʃ].
		text = rsub(text, "#x", "#ʧ")
		text = rsub(text, "([^" .. vowel_l .. separator_l .. "j]" .. charsep_c .. "*)x", "%1ʧ")
	end
	-- Other x becomes [ʃ]
	text = rsub(text, "x", "ʃ")

	-- Doubled ss -> s e.g. in exs-, exc(e/i)-, sc(e/i)-; FIXME: should this apply across word boundaries?
	text = rsub(text, "s(" .. charsep_c .. "*)s", "%1s")

	------------------ Coda consonant losses

	-- In Central Catalan, coda losses happen everywhere, but otherwise they don't happen when
	-- absolutely word-finally before a vowel or end of utterance (e.g. [[blanc]] has /k/ in Balearic and
	-- Valencian but not [[blancs]]). Must precede consonant assimilations.
	local boundary = dialect == "cen" and "(.)" or "([^#])"
	text = rsub(text, "m[pb]" .. boundary, "m%1")
	text = rsub(text, "([ln])[td]" .. boundary, "%1%2")
	text = rsub(text, "[nŋ][kg]" .. boundary, "ŋ%1")
	if dialect == "val" or dialect == "bal" then
		local before_cons = "(" .. separator_c .. "*" .. C .. ")"
		text = rsub(text, "m[pb]" .. before_cons, "m%1")
		text = rsub(text, "([ln])[td]" .. before_cons, "%1%2")
		text = rsub(text, "[nŋ][kg]" .. before_cons, "ŋ%1")
	end

	-- Delete /t/ between /s/ and any consonant other than /s/ or /ɾ/. Must precede voicing assimilation and
	-- t + lateral/nasal assimilation.
	text = rsub(text, "st(" .. sylsep_c .. "*[^" .. neg_guts_of_cons .. "sɾ])", "s%1")
	
	------------------ Consonant assimilations

	if dialect == "cen" then
		-- v > b in onsets (not in codas, e.g. [[ovni]] [ɔ́vni] and [[hafni]] [ávni]). This needs to precede
		-- assimilation of nb -> mb.
		text = rsub(text, "v(" .. C .. "*" .. V ..")", "b%1")
	end

	-- t + lateral assimilation -> geminate across syllable boundary. We don't any more do t + nasal assimiation
	-- because there are too many exceptions, e.g. [[aritmètic]], [[atmosfèric]], [[ètnia]]. Instead, we require that
	-- cases where it does happen use respelling to effect this. FIXME: this doesn't always happen in -tl- either,
	-- e.g. [[atlàntic]] has [əllántik] in GDLC but [adlántik] in DNV.
	--
	-- FIXME: Clean this up, maybe move below voicing assimilation, investigate whether it operates across words,
	-- move stuff below that special-cases tll in Valencian here.
	text = rsub(text, "t(" .. sylsep_c .. ")([lʎ])", "%2%1%2")

	-- n + labial > labialized assimilation
	text = rsub(text, "n(" .. separator_c .. "*[mbp])", "m%1")
	text = rsub(text, "n(" .. separator_c .. "*[fv])", "ɱ%1")

	-- n + velar > velarized assimilation
	text = rsub(text, "n(" .. separator_c .. "*[kg])", "ŋ%1")

	-- l/n + palatal > palatalized assimilation
	text = rsub(text, "([ln])(" .. separator_c .. "*[ʎɲʃʒʧʤ])", function(ln, palatal)
		ln = ({["l"] = "ʎ", ["n"] = "ɲ"})[ln]
		return ln .. palatal
	end)

	-- ɲs > ɲʃ; FIXME: not sure the purpose of this; it doesn't apply in [[menys]] or derived terms like [[menyspreu]]
	-- NOTE: Per [https://giec.iec.cat/textgramatica/codi/4.4], it does apply in these scenarios but the result is
	-- somewhere between [s] and [ʃ], which is why it isn't shown in GDLC.
	-- text = rsub(text, "ɲs", "%1ʃ")

	------------------ Handle <r>

	-- In replace_context_free(), we converted single r to ɾ and double rr to r.
	if dialect == "cen" then
		text = rsub(text, TEMP_PAREN_R, "")
		text = rsub(text, TEMP_PAREN_RR, "r")
	elseif dialect == "bal" then
		text = rsub(text, TEMP_PAREN_R, "")
		text = rsub(text, TEMP_PAREN_RR, "")
	else
		verify(dialect == "val", ("Unrecognized dialect '%s'"):format(dialect))
		text = rsub(text, TEMP_PAREN_R, "ɾ")
		text = rsub(text, TEMP_PAREN_RR, "ɾ")
	end
	if dialect ~= "val" then
		-- Coda /ɾ/ -> /r/
		-- FIXME: This is inherited from the older code. Correct?
		text = rsub(text, "(" .. V .. stress_c .. "*" .. C .. "*)ɾ", "%1r")
	end		

	-- ɾ -> r word-initially or after [lns]; needs to precede voicing assimilation as <s> will be voiced to [z] before
	-- /ɾ/.
	text = rsub(text, "([#lns]" .. sylsep_c .. "*)ɾ", "%1r")

	------------------ Voicing assimilation

	-- Voicing or devoicing; we want to proceed from right to left, and due to the limitations of patterns (in
	-- particular, the lack of support for alternations), it's difficult to do this cleanly using Lua patterns, so we
	-- do it character by character.
	local chars = split_into_chars(text)
	-- We need to look two characters ahead in some cases, so start two characters from the end. This is safe because
	-- the overall respelling ends in "##". (Similarly, as an optimization, don't check the first two characters, which
	-- are always "##".)
	for i = #chars - 2, 3, -1 do
		-- We are looking for two consonants next to each other, possibly separated by a syllable or word divider.
		-- We also handle a consonant followed by a syllable divider then a vowel, and a consonant word-finally.
		-- Note that only coda consonants can change voicing, so we need to check to make sure we're in the coda.
		local first = chars[i]
		-- If `second` is nil, no assimilation occurs. Otherwise, `second` should be a consonant or empty string (which
		-- represents a syllable or word boundary followed by a vowel or end of string), and we assimilate to that
		-- consonant (empty string forces devoicing).
		local second
		-- If set to true, we're processing a consonant directly before a word boundary followed by a word beginning
		-- with a vowel. In this context, voiceless sibilants voice. Note that we handle voicing of <s> word-internally
		-- separately, in preprocess_word() [FIXME: maybe move much of the processing in preprocess_word() into this
		-- function].
		local word_boundary_before_vowel
		if not rfind(first, C) then
			-- leave `second` at nil; no assimilation
		elseif chars[i + 1] == "#" then -- word boundary
			if chars[i + 2] == " " then
				-- chars[i + 3] should always be "#"
				verify(chars[i + 3] == "#", "Word boundary followed by space but not #")
				if rfind(chars[i + 4], C) then
					second = chars[i + 4]
				else
					second = ""
					word_boundary_before_vowel = true
				end
			else
				second = ""
			end
		elseif rfind(chars[i + 1], sylsep_c) then -- syllable boundary
			if rfind(chars[i + 2], C) then
				second = chars[i + 2]
			else
				second = ""
			end
		elseif rfind(chars[i + 1], C) then
			second = chars[i + 1]
		else
			-- followed by a vowel not across a syllable or word boundary; leave `second` as nil, no assimilation
		end
		if second then
			-- Make sure we're in the coda. We have to look backwards until we find a vowel or syllable/word boundary.
			local in_coda = false
			local j = i - 1
			while true do
				verify(j > 0, "Missing word boundary at beginning of overall respelling")
				if rfind(chars[j], "[" .. sylsep_l .. wordsep_l .. "]") then
					break
				elseif rfind(chars[j], V) then
					in_coda = true
					break
				end
				j = j - 1
			end
			if in_coda then
				if word_boundary_before_vowel and rfind(first, "[zʒʣʤ]") then
					-- leave alone
				elseif voiced[second] and voicing[first] or word_boundary_before_vowel and rfind(first, "[sʃʦʧ]") then
					chars[i] = voicing[first]
				elseif (voiceless[second] or second == "") and devoicing[first] then
					chars[i] = devoicing[first]
				end
			end
		end
	end
	text = table.concat(chars)

	-- gn -> ŋn e.g. [[regnar]] (including word-initial gn- e.g. [[gnòmic]], [[gneis]]) 
	-- FIXME: This should be moved below voicing assimilation, and we need to investigate if it operates across words
	-- (here I'm guessing yes).
	if dialect ~= "cen" then
		text = rsub(text, "#gn", "#n")
	end
	text = rsub(text, "g(" .. separator_c .. "*n)", "ŋ%1")

	-- gʒ > d͡ʒ
	-- FIXME: We need to investigate if it operates across words
	text = rsub(text, "g(" .. sylsep_c .. "*)ʒ", "%1ʤ")
	-- sʃ -> ʃ ([[desxifrar]]), zʒ -> ʒ ([[disjuntor]])
	if dialect ~= "val" then
		text = rsub(text, "s(" .. separator_c .. "*ʃ)", "%1")
		text = rsub(text, "z(" .. separator_c .. "*ʒ)", "%1")
	end

	------------------ Gemination of <bl>, <gl>

	if dialect ~= "val" then
		-- bl -> bbl, gl -> ggl after the stress when following a vowel; to avoid this, use <b_l> or <g_l>.
		-- This must follow v > b above. To force a hard ungeminated [b] or [g], use <_b> or <_g>.
		text = rsub(text, "(" .. stress_c .. ")(" .. sylsep_c .. ")([bg])l", "%1%3%2%3l")
	else -- Valencian; undo manually written 'bbl', 'ggl' in words like [[poblar]], [[reglament]]
		text = rsub(text, "([bg])(" .. sylsep_c .. ")%1l", "%2%1l")
	end

	------------------ Lenition of voiced stops

	-- In Central Catalan, b/d/g become fricatives (actually approximants, like in Spanish) in the onset following a
	-- vowel and (except for <d>) after <l> and <ll> (cf. GDLC [[cabellblanc]] [kəβɛ̀ʎβláŋ]). This also happens across
	-- word boundaries but doesn't happen after stops, nor in Central Catalan after [r], [ɾ] or [z] (and hence probably
	-- not after [ʒ] either, although I can't find any examples in GDLC).
	--
	-- In Valencian, <b> doesn't lenite (at least formally?), but <d> and <g> do lenite after [r], [ɾ] or [z].
	--
	-- Balearic is like Valencian in not leniting <b>, and probably like Central Catalan otherwise.
	local lenite_bdg = {["b"] = "β", ["d"] = "ð", ["g"] = "ɣ"}
	if dialect == "cen" then
		text = rsub(text, "([" .. vowel_l .. "jwlʎv]" .. separator_c .. "*[.#]" .. separator_c .. "*)([bdg])",
			function(before, bdg) return before .. lenite_bdg[bdg] end)
	elseif dialect == "val" then
		text = rsub(text, "([" .. vowel_l .. "jwlʎvrɾzʣ]" .. separator_c .. "*[.#]" .. separator_c .. "*)([dg])",
			function(before, dg) return before .. lenite_bdg[dg] end)
	else
		verify(dialect == "bal", ("Unrecognized dialect '%s'"):format(dialect))
		text = rsub(text, "([" .. vowel_l .. "jwlʎv]" .. separator_c .. "*[.#]" .. separator_c .. "*)([dg])",
			function(before, dg) return before .. lenite_bdg[dg] end)
	end

	------------------ Vowel reduction

	-- Reduction of unstressed a,e in Central and Balearic (Eastern Catalan).
	if dialect ~= "val" then
		-- The following rules seem to apply, based on the old code:
		-- (1) Stressed a and e are never reduced.
		-- (2) Unstressed e directly following ə is not reduced.
		-- (3) Unstressed e directly before written <a> or before /ɔ/ is not reduced.
		-- (4) Written <ee> when both vowels precede the primary stress is reduced to [əə]. (This rule preempts #2.)
		-- (5) Written <ee> when both vowels follow the primary stress isn't reduced at all.
		-- Rule #2 in particular seems to require that we proceed left to right, which is how the old code was
		-- implemented.
		-- FIXME: These rules seem overly complex and may produce incorrect results in some circumstances.
		local words = rsplit(text, " ")
		for j, word in ipairs(words) do
			local chars = split_into_chars(word)
			-- See above where voicing assimilation is handled. The overall respelling begins and ends in #, which we
			-- can ignore. We need to look ahead three chars in some circumstances, but in all those circumstances we
			-- shoudn't run off the end (and have assertions to check this).
			local seen_primary_stress = false
			for i = 2, #chars - 1 do
				local this = chars[i]
				if chars[i] == AC then
					seen_primary_stress = true
				end
				if (this ~= "a" and this ~= "e") or rfind(chars[i + 1], stress_c) then
					-- Not a/e, or a stressed vowel; continue
				else
					local reduction = true
					local prev, prev_stress, nxt, nxt_stress
					if not rfind(chars[i - 1], sylsep_c) then
						prev = ""
					else
						prev = chars[i - 2] -- this should be non-nil as chars[i - 1] is a syllable separator (not #)
						verify(prev, "Missing # at word boundary")
						prev_stress = ""
						if rfind(prev, stress_c) then
							prev_stress = prev
							prev = chars[i - 3]
							-- As above; chars[i - 2] is a stress indicator (not #).
							verify(prev, "Missing # at word boundary")
						end
					end
					if not rfind(chars[i + 1], sylsep_c) then
						nxt = ""
						-- leave nxt at nil
					else
						nxt = chars[i + 2]
						nxt_stress = chars[i + 3]
						-- chars[i + 1] is a syllable separator, so chars[i + 2] should not be a word boundary, so
						-- chars[i + 3] should exist.
						verify(nxt and nxt_stress, "Syllable separator at word boundary or missing # at word boundary")
					end
					if this == "e" and rfind(prev, "ə") then
						reduction = false
					elseif this == "e" and rfind(nxt, "[aɔ]") then
						reduction = false
					elseif this == "e" and nxt == "e" and not rfind(nxt_stress, AC) then
						-- FIXME: Check specifically for AC duplicates previous logic but is probably wrong or unnecessary.
						if not seen_primary_stress then
							chars[i + 2] = "ə"
						else
							reduction = false
						end
					end
					if reduction then
						chars[i] = "ə"
					end
				end
			end
			words[j] = table.concat(chars)
		end
		text = table.concat(words, " ")
	end

	if dialect == "cen" then
		-- Reduction of unstressed o (not before w)
		text = rsub(text, "o([^" .. stress_l .. "w])", "u%1")
	elseif dialect == "bal" then
		-- Reduction of unstressed o per vowel harmony: unstressed /o/ -> /u/ directly before stressed /i/ or /u/;
		-- as a Lua pattern, o can be followed only by consonants and/or syllable separators (no vowels, stress marks
		-- or word separators).
		text = rsub(text, "o([^" .. vowel_l .. stress_l .. wordsep_l .. "]*[iu]" .. stress_c .. ")", "u%1")
	end

	-- Final losses.
	text = rsub(text, "j(ʧs?#)", "%1") -- boigs /bɔt͡ʃ/
	text = rsub(text, "([ʃʧs])s#", "%1#") -- homophone plurals -xs, -igs, -çs

	if dialect ~= "val" then
		-- Remove j before palatal obstruents
		text = rsub(text, "j(" .. sylsep_c .. "*[ʃʒʧʤ])", "%1")
	else -- Valencian
		-- Fortition of palatal fricatives
		text = rsub(text, "ʒ", "ʤ")
		text = rsub(text, "(i" .. stress_c .. "*" .. sylsep_c .. ")ʣ", "%1z")
	end

	if dialect ~= "cen" then
		-- No palatal gemination ʎʎ > ll or ʎ, in Valencian and Balearic.
		-- FIXME: These conditions seem to be targeting specific words and should probably be fixed using respelling
		-- instead.
		text = rsub(text, "([bpw]a" .. stress_c .. "*)ʎ(" .. sylsep_c .. "*)ʎ", "%1l%2l")
		text = rsub(text, "([mv]e" .. stress_c .. "*)ʎ(" .. sylsep_c .. "*)ʎ", "%1l%2l")
		text = rsub(text, "(ti" .. stress_c .. "*)ʎ(" .. sylsep_c .. "*)ʎ", "%1l%2l")
		text = rsub(text, "(m[oɔ]" .. stress_c .. "*)ʎ(" .. sylsep_c .. "*)ʎ", "%1l%2l")
		text = rsub(text, "(u" .. stress_c .. "*)ʎ(" .. sylsep_c .. "*)ʎ", "%1l%2l")
		text = rsub(text, "ʎ(" .. sylsep_c .. "*ʎ)", "%1")
	end

	---------- Convert pseudo-symbols to real ones.

	-- Convert g to IPA ɡ.
	text = rsub(text, "g", "ɡ")

	-- Convert pseudo-afficate symbols to full affricates.
	local full_affricates = { ["ʦ"] = "t͡s", ["ʣ"] = "d͡z", ["ʧ"] = "t͡ʃ", ["ʤ"] = "d͡ʒ" }
	text = rsub(text, "([ʦʣʧʤ])", full_affricates)

	---------- Generate IPA stress marks.

	-- Convert acute and grave to IPA stress marks.
	text = rsub(text, AC, "ˈ")
	text = rsub(text, GR, "ˌ")
	-- Move IPA stress marks to the beginning of the syllable.
	text = rsub_repeatedly(text, "([#.])([^#.]*)(" .. ipa_stress_c .. ")", "%1%3%2")
	-- Suppress syllable divider before IPA stress indicator.
	text = rsub(text, "%.(#?" .. ipa_stress_c .. ")", "%1")
	-- Make all primary stresses but the last one in a given word be secondary. May be fed by the first rule above.
	-- FIXME: Currently this is handled earlier, but we might want to move it here, as is done in [[Module:pt-pronunc]].
	-- text = rsub_repeatedly(text, "ˈ([^ ]+)ˈ", "ˌ%1ˈ")
	-- Make primary stresses in prefixes become secondary. (FIXME: Handled earlier now.)
	-- text = rsub_repeatedly(text, "ˈ([^#]*#" .. PREFIX_MARKER .. ")", "ˌ%1")

	-- Remove # symbols at word/text boundaries, as well as _ (which forces separate interpretation), pseudo-consonant
	-- markers (at edges of some prefixes/suffixes), and prefix markers, and recompose.
	text = rsub(text, "[#_" .. PSEUDOCONS .. "]", "")
	text = mw.ustring.toNFC(text)

	return text
end


local function preprocess_word(syllables, suffix_syllables, dialect, pos, orig_word)
	-- Stressed vowel is ambiguous
	if syllables.stress then
		local stressed_vowel = syllables[syllables.stress].vowel
		if rfind(stressed_vowel, "[eo]") then
			local marks = {["e"] = {AC, GR, CFLEX, DIA}, ["o"] = {AC, GR, CFLEX}}
			local marked_vowels = {}
			for _, mark in ipairs(marks[stressed_vowel]) do
				table.insert(marked_vowels, stressed_vowel .. mark)
			end

			error(("In respelling '%s', the stressed vowel '%s' is ambiguous. Please mark it with an acute, " ..
				"grave, or combined accent: %s."):format(orig_word, stressed_vowel,
				m_table.serialCommaJoin(marked_vowels, {dontTag = true, conj = "or"})))
		end
	end

	-- Final -r is ambiguous in many cases.
	local final = syllables[#syllables]
	-- Stressed final r after a or i in non-monosyllables is treated as (r), i.e. verbal infinitives are assumed (NOTE:
	-- not always the case, e.g. there are many adjectives and nouns in -ar that should be marked as '(rr)', and
	-- several loanword nouns in -ir that should be marked as 'rr'). Likewise for stressed final r or rs after é in
	-- non-monosyllables (which are usually adjectives or nouns with the -er ending, but may be verbal infinitives,
	-- which should be marked as 'ê(r)'). That is, it disappears other than in Valencian. All other final r and final
	-- rs are considered ambiguous and need to be rewritten using rr, (rr) or (r).
	if #syllables > 1 and final.stressed then
		if final.coda == "r" and rfind(final.vowel, "[aàiíé]") or final.coda == "rs" and final.vowel == "é" or
			final.vowel == "ó" and rfind(final.coda, "^rs?$") and rfind(final.onset, "[stdç]") then
			final.coda = TEMP_PAREN_R
		end
	end
	if rfind(final.coda, "^rs?$") or rfind(final.coda, "[^r]rs?$") then
		error(("In respelling '%s', final -r by itself or in -rs is ambiguous except in the verbal endings -ar or " ..
			"-ir, in the nominal or adjectival endings -er(s) and -[dtsç]or(s). In all other cases it needs to be " ..
			"rewritten using one of 'rr' (pronounced everywhere), '(rr)' (pronounced everywhere but Balearic) or " ..
			"'(r)' (pronounced only in Valencian). Note that adjectives in -ar usually need rewriting using '(rr)'; " ..
			"nouns in -ar referring to places should be rewritten using '(r)'; and loanword nouns in -ir usually " ..
			"need rewriting using 'rr'."):format(orig_word))
	end

	local syllables_IPA = {stress = syllables.stress, is_prefix = syllables.is_prefix, is_suffix = syllables.is_suffix}

	for key, val in ipairs(syllables) do
		syllables_IPA[key] = {onset = val.onset, vowel = val.vowel, coda = val.coda, stressed = val.stressed}
	end

	-- Replace letters with IPA equivalents
	for i, syll in ipairs(syllables_IPA) do
		-- Voicing of s
		if syll.onset == "s" and i > 1 and rfind(syllables[i - 1].coda, "^[iu]?$") then
			syll.onset = "z"
		end

		if rfind(syll.vowel, "^[eèéêëií]$") then
			syll.onset = rsub(syll.onset, "tg$", "ʤ")
			syll.onset = rsub(syll.onset, "[cg]$", {["c"] = "s", ["g"] = "ʒ"})
			syll.onset = rsub(syll.onset, "[qg]u$", {["qu"] = "k", ["gu"] = "g"})
		end

		syll.coda = rsub(syll.coda, "igs?$", "iʤ")

		syll.onset = replace_context_free(syll.onset)
		syll.coda = replace_context_free(syll.coda)

		syll.vowel = rsub(syll.vowel, ".",
			dialect == "cen" and IPA_vowels_central or
			dialect == "bal" and IPA_vowels_balearic or
			IPA_vowels_valencian
		)
		syll.vowel = rsub(syll.vowel, ".", IPA_vowels)
	end

	for _, suffix_syl in ipairs(suffix_syllables) do
		table.insert(syllables_IPA, suffix_syl)
	end

	return syllables_IPA
end


-- Given a single substitution spec, `to`, figure out the corresponding value of `from` used in a complete
-- substitution spec. `pagename` is the name of the page, either the actual one or taken from the `pagename` param.
-- `whole_word`, if set, indicates that the match must be to a whole word (it was preceded by ~).
local function convert_single_substitution_to_original(to, pagename, whole_word)
	-- Replace specially-handled characters with a class matching the character and possible replacements.
	local escaped_from = to
	-- Handling of '(rr)', '(r)', '.' and '-' needs to be done before calling pattern_escape(); otherwise they will be
	-- escaped.
	escaped_from = escaped_from:gsub("%(rr%)", "r")
	escaped_from = escaped_from:gsub("%(r%)", "r")
	escaped_from = escaped_from:gsub("ks", "x"):gsub("Ks", "X"):gsub("gz", "x"):gsub("([bg])%1l", "%1l"):gsub("[._]", "")
	escaped_from = require(strutil_module).pattern_escape(escaped_from)
	escaped_from = escaped_from:gsub("rr", "rr?")
	escaped_from = escaped_from:gsub("ss", "ss?")
	escaped_from = escaped_from:gsub("ʃ", "[xX]")
	-- This is tricky, because we already passed `escaped_from` through pattern_escape() causing a hyphen to get a
	-- % sign before it, and have to double up the percent signs to match and replace a literal %.
	escaped_from = escaped_from:gsub("%%%-", "%%-?")
	-- Tie sign (‿) should match against space, hyphen or nothing in the original.
	escaped_from = escaped_from:gsub("‿", "[ %%-]?")
	escaped_from = rsub(escaped_from, "[" .. written_accented_vowel_l .. "]",
		function(v) return "[" .. v .. written_accented_to_plain_vowel[v] .. "]" end)
	escaped_from = escaped_from:gsub(DOTOVER, DOTOVER .. "?"):gsub(LINEUNDER, LINEUNDER .. "?")
	escaped_from = "(" .. escaped_from .. ")"
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


local function apply_substitution_spec(respelling, pagename, pos, allow_mid_vowel_hints, parse_err)
	local subs = split_on_comma(rmatch(respelling, "^%[(.*)%]$"))
	respelling = pagename
	local mid_vowel_hint
	local regular_subs = {}
	for _, sub in ipairs(subs) do
		if rfind(sub, "^" .. export.mid_vowel_hint_c .. "$") then
			if mid_vowel_hint then
				parse_err(("Specified mid vowel hint twice, '%s' and '%s'"):format(
					mid_vowel_hint, sub))
			end
			mid_vowel_hint = sub
		else
			table.insert(regular_subs, sub)
		end
	end
	if mid_vowel_hint then
		if not allow_mid_vowel_hints then
			parse_err(("Mid vowel hint '%s' not allowed when apply one substitution spec to multiple words"):format(
				mid_vowel_hint))
		end
		local suffix = ""
		-- FIXME: This duplicates logic in to_IPA().
		if not pos or pos == "adverb" then
			local part_before_ment, ment = rmatch(respelling, "^(.*)(m[eé]nt)$")
			if part_before_ment and (pos == "adverb" or not rfind(part_before_ment, "[iï]$") and
				rfind(part_before_ment, V .. ".*" .. V)) then
				suffix = ment
				respelling = part_before_ment
			end
		end
		local syllables = split_syllables(respelling, "stress prefixes", "may be uppercase")
		local stressed_vowel = syllables[syllables.stress].vowel
		if stressed_vowel == mid_vowel_hint then
			-- do nothing
		elseif rfind(mid_vowel_hint, "[èéêë]") and rfind(stressed_vowel, "[eEèÈ]") or
			rfind(mid_vowel_hint, "[òóô]") and rfind(stressed_vowel, "[oO]") then
				syllables[syllables.stress].vowel = mid_vowel_hint
		else
			parse_err(("Stressed vowel '%s' not compatible with mid vowel hint '%s'"):format(
				stressed_vowel, mid_vowel_hint))
		end
		respelling = reconstitute_word_from_syllables(syllables) .. suffix
	end

	for _, sub in ipairs(regular_subs) do
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
			from = convert_single_substitution_to_original(to, pagename, whole_word)
		end
		if from then
			local strutil = require(strutil_module)
			escaped_from = strutil.pattern_escape(from)
			if whole_word then
				escaped_from = "%f[%a]" .. escaped_from .. "%f[%A]"
			end
			escaped_to = strutil.replacement_escape(to)
			local subbed_respelling, nsubs = rsubn(respelling, escaped_from, escaped_to)
			if nsubs == 0 then
				parse_err(("Substitution spec %s -> %s didn't match processed pagename '%s'"):format(
					from, to, respelling))
			elseif nsubs > 1 then
				parse_err(("Substitution spec %s -> %s matched multiple substrings in processed pagename '%s', add " ..
					"more context"):format(from, to, respelling))
			else
				respelling = subbed_respelling
			end
		end
	end

	return respelling
end


local canonicalize_pos = {
	n = "noun",
	noun = "noun",
	v = "verb",
	vb = "verb",
	verb = "verb",
	a = "adjective",
	adj = "adjective",
	adjective = "adjective",
	av = "adverb",
	adv = "adverb",
	adverb = "adverb",
	o = "other",
	other = "other",
}


local function parse_off_pos(respelling, parse_err)
	local pos, rest = respelling:match("^([a-z]+)/(.*)$")
	if pos then
		if not canonicalize_pos[pos] then
			local valid_pos = {}
			for vp, _ in pairs(canonicalize_pos) do
				table.insert(valid_pos, vp)
			end
			table.sort(valid_pos)
			parse_err(("Unrecognized part of speech '%s', should be one of %s"):format(pos,
				table.concat(valid_pos, ", ")))
		end
		pos = canonicalize_pos[pos]
		respelling = rest
		if respelling == "" then
			respelling = "+"
		end
	end
	return pos, respelling
end


-- Parse a respelling given by the user, allowing for '+' for pagename, mid vowel hints in place of a respelling and
-- substitution specs like '[ks]' or [val:vol,ê,ks]. In general, return an object {words = {WORD, WORD, ...}} where
-- WORD is of the form {term = PARSED_RESPELLING, pos = POS}. Other fields are set in special cases: If a raw respelling
-- was seen, the fields `raw_phonemic` and/or `raw_phonetic` are set; if '?' is seen, the field `unknown` is set; and if
-- '-' is seen, the field `omitted` is set.
local function parse_respelling(respelling, pagename, parse_err)
	if respelling == "?" then
		return {
			unknown = true
		}
	end
	if respelling == "-" then
		return {
			omitted = true
		}
	end
	local saw_raw
	local remaining_respelling = respelling:match("^raw:(.*)$")
	if remaining_respelling then
		saw_raw = true
		respelling = remaining_respelling
	end
	local raw_phonemic, raw_phonetic = respelling:match("^/(.*)/ %[(.*)%]$")
	if not raw_phonemic then
		raw_phonemic = respelling:match("^/(.*)/$")
	end
	if not raw_phonemic and saw_raw then
		raw_phonetic = respelling:match("^%[(.*)%]$")
	end
	if raw_phonemic or raw_phonetic then
		return {
			raw_phonemic = raw_phonemic,
			raw_phonetic = raw_phonetic,
		}
	end

	pagename = decompose_respelling(pagename)
	respelling = decompose_respelling(respelling)

	local function split_respelling_into_words(respelling, parse_pos)
		respelling = canon_respelling(respelling)
		local word_objs = {}
		local respelling_words = rsplit(respelling, " ")
		for _, word in ipairs(respelling_words) do
			local pos
			if parse_pos then
				pos, word = parse_off_pos(word, parse_err)
			end
			table.insert(word_objs, {term = word, pos = pos})
		end
		return {words = word_objs}
	end

	local function substitute_respelling_word(respelling_word, pagename_word)
		local pos
		pos, respelling_word = parse_off_pos(respelling_word, parse_err)
		if respelling_word == "+" then
			respelling_word = pagename_word
		else
			if rfind(respelling_word, "^" .. export.mid_vowel_hint_c .. "$") then
				respelling_word = "[" .. respelling_word .. "]"
			end
			if rfind(respelling_word, "^%[.*%]$") then
				respelling_word = apply_substitution_spec(respelling_word, pagename_word, pos,
					"allow mid vowel hint", parse_err)
			end
		end
		return {term = respelling_word, pos = pos}
	end

	-- At this point, if there are multiple words in the pagename, there are three syntaxes allowed: all-at-once,
	-- replacement or word-by-word. All-at-once syntax involves either a + representing the entire pagename, or a
	-- substitution spec that applies to all words in the pagename. This syntax cannot have a prefixed part of speech
	-- because it wouldn't be clear which word to apply the part of speech to. Replacement syntax simply spells out the
	-- respelling without any substitution specs or +'s (but possibly with parts of speech prefixed to individual
	-- words), and can have a different number of words than the pagename (essentially, the pagename is disregarded).
	-- Word-by-word syntax involves a combination of respelled words, per-word substitution specs and/or a +
	-- representing an individual word, and must have the same number of words as the pagename so that substitution
	-- specs and +'s can be lined up with words in the pagename. In all cases, the return value is in the same format;
	-- see comment at top of function.
	if pagename:find(" ") or respelling:find(" ") then
		if respelling == "+" then
			return split_respelling_into_words(pagename)
		elseif rfind(respelling, "^%[.*%]$") then
			-- all-at-once syntax with substitution spec
			return split_respelling_into_words(apply_substitution_spec(respelling, pagename, nil, false, parse_err))
		elseif rfind(respelling, "^([a-z]+)/$") or rfind(respelling, "^([a-z]+)/%[[^%[%]]*%]$") then
			-- attempt to include a part of speech in all-at-once syntax
			parse_err(("Part of speech not allowed when pagename is multiword and all-at-once syntax is used in " ..
				"the respelling, but saw '%s'"):format(respelling))
		elseif rfind(respelling, "^" .. export.mid_vowel_hint_c .. "$") then
			-- attempt to use a mid-vowel hint in all-at-once syntax
			parse_err(("Single mid-vowel hint not allowed when pagename is multiword because it's not clear which " ..
				"word to apply it to, but saw '%s'"):format(respelling))
		elseif rfind(respelling, "[+%[%]]") or rfind(respelling, "^" .. export.mid_vowel_hint_c .. " ") or
			rfind(respelling, " " .. export.mid_vowel_hint_c .. " ") or
			rfind(respelling, " " .. export.mid_vowel_hint_c .. "$") then
			-- word-by-word syntax
			local sub_with_space = rmatch(respelling, "%[[^%[%]]* [^%[%]]*%]")
			if sub_with_space then
				parse_err(("When using word-by-word syntax with a multiword pagename, saw substitution spec '%s' " ..
					"with spaces, which is not allowed because it must match a single word"):format(sub_with_space))
			end
			pagename = canon_respelling(pagename)
			respelling = canon_respelling(respelling)
			local pagename_words = rsplit(pagename, " ")
			local respelling_words = rsplit(respelling, " ")
			if #pagename_words ~= #respelling_words then
				parse_err(("When using word-by-word syntax with a multiword pagename, saw %s words in pagename but " ..
					"%s word%s in respelling; they need to match"):format(#pagename_words, #respelling_words,
						#respelling_words > 1 and "s" or ""))
			end
			local word_objs = {}
			for i = 1, #pagename_words do
				table.insert(word_objs, substitute_respelling_word(respelling_words[i], pagename_words[i]))
			end
			return {words = word_objs}
		else
			-- replacement syntax; pagename ignored
			return split_respelling_into_words(respelling, "parse pos")
		end
	else
		local word_obj = substitute_respelling_word(respelling, pagename)
		word_obj.term = canon_respelling(word_obj.term)
		return {words = {word_obj}}
	end
end


-- Parse a list of comma-split runs containing one or more respellings, i.e. after calling parse_balanced_segment_run()
-- or the like followed by split_alternating_runs() or the like (see [[Module:parse utilities]]). `pagename` is the
-- pagename, for use when a respelling is just '+', a mid-vowel hint like 'ê' or a substitution spec like '[ks]'.
-- `original_input` is the raw input and `input_param` the name of the param containing the raw input; both are used
-- only in error messages. Return an object specifying the respellings, currently with a single field 'terms' (this
-- format is used in case other outer properties exist in the future), where 'terms' is a list of term objects. Each
-- term object contains either a field `term` with the respelling and an optional part of speech `pos`, or fields
-- `raw_phonemic` and/or `raw_phonetic` (if the user specified raw IPA using "/.../" or "/.../ [...]" or "raw:[...]"),
-- `unknown` (if the user specified "?"), or `omitted` (if the user specified "-"). In addition, there may be fields
-- `q`, `qq`, `a`, `aa`, and/or `ref` corresponding to inline modifiers. Each such field is a list; all are lists of
-- strings except for `ref`, which is a list of objects as returned by parse_references() in [[Module:references]].
function export.parse_comma_separated_groups(comma_separated_groups, pagename, original_input, input_param)
	local function generate_obj(respelling, parse_err)
		return parse_respelling(respelling, pagename == true and respelling or pagename, parse_err)
	end
	local put = require(parse_utilities_module)

	local outer_container = {terms = {}}
	for _, group in ipairs(comma_separated_groups) do
		-- Rejoin runs that don't involve <...>.
		local j = 2
		while j <= #group do
			if not group[j]:find("^<.*>$") then
				group[j - 1] = group[j - 1] .. group[j] .. group[j + 1]
				table.remove(group, j)
				table.remove(group, j)
			else
				j = j + 2
			end
		end

		local param_mods = {
			-- pre = { overall = true },
			-- post = { overall = true },
			ref = { store = "insert", convert = function(arg, parse_err)
				return require("Module:references").parse_references(arg)
			end },
			q = { store = "insert" },
			qq = { store = "insert" },
			a = { store = "insert" },
			aa = { store = "insert" },
		}

		table.insert(outer_container.terms, put.parse_inline_modifiers_from_segments {
			group = group,
			arg = original_input,
			props = {
				paramname = input_param,
				param_mods = param_mods,
				generate_obj = generate_obj,
				splitchar = ",",
				outer_container = outer_container,
			},
		})
	end

	return outer_container
end


-- Generate the pronunciation of `words` (a list of word objects representing respellings, each of which is an object
-- of the form {term = RESPELLING, pos = PART_OF_SPEECH} in `dialect` ("cen", "bal" or "val").
local function to_IPA(words, dialect)
	local pronuns = {}

	for _, wordobj in ipairs(words) do
		if rfind(wordobj.term, "[áìùÁÌÙ]") then
			error(("Invalid accented character in respelling '%s'; use accented à í ú, not the reversed versions"
				):format(wordobj.term))
		end
	end
	
	words = handle_unstressed_words(words)
	
	for _, wordobj in ipairs(words) do
		local word = wordobj.term
		local pos = wordobj.pos
		local suffix_syllables = {}
		local orig_word = word

		word = ulower(word)
		if not pos or pos == "adverb" then
			local word_before_ment, ment = rmatch(word, "^(.*)(m[eé]nt)$")
			if word_before_ment and (pos == "adverb" or not rfind(word_before_ment, "[iï]$") and
				rfind(word_before_ment, V .. ".*" .. V)) then
				suffix_syllables = {{onset = "m", vowel = "e", coda = "nt", stressed = true}}
				pos = "adjective"
				word = word_before_ment
			end
		end

		word = word_fixes(word, dialect)
		local syllables = split_syllables(word)
		syllables = preprocess_word(syllables, suffix_syllables, dialect, pos, orig_word)
		-- Combine syllables.
		local combined = {}
		local has_ment = #suffix_syllables > 0
		for i, syll in ipairs(syllables) do
			local ac = (i == syllables.stress and not syllables.is_prefix and not has_ment or
				has_ment and i == #syllables) and AC or -- primary stress
				syllables[i].stressed and GR or -- secondary stress
				""
			table.insert(combined, syll.onset .. syll.vowel .. ac .. syll.coda)
		end
		table.insert(pronuns, table.concat(combined, "."))
	end

	-- Put double ## at utterance boundaries (beginning/end of string) and at foot boundaries (marked with |).
	-- Note that if the string without pound signs is 'foo bar baz | bat quux', the final string will be
	-- '##foo# #bar# #baz## #|# ##bat# #quux##'.
	local text = "##" .. table.concat(pronuns, " ") .. "##"
	text = rsub(text, " | ", "# | #")
	text = rsub(text, " ", "# #")
	return postprocess_general(text, dialect)
end


-- Generate the phonemic and phonetic pronunciations of the respellings in `parsed_respellings`, which is a table whose
-- keys are dialect identifiers (e.g. "cen" for Central Catalan, "val" for Valencian) and whose values are objects of
-- the format returned by parse_comma_separated_groups() (see comment above that function). This destructively modifies
-- `parsed_respellings`, adding fields `phonemic` and `phonetic` containing the generated pronunciations and removing
-- the input fields used to generate those output fields. (FIXME: Currently only phonetic pronunciation is generated.)
function export.generate_phonemic_phonetic(parsed_respellings)
	-- Convert each canonicalized respelling to phonemic/phonetic IPA.
	for dialect, respelling_spec in pairs(parsed_respellings) do
		for _, termobj in ipairs(respelling_spec.terms) do
			if termobj.unknown or termobj.omitted then
				-- leave alone, will handle later
			elseif termobj.raw_phonemic or termobj.raw_phonetic then
				termobj.phonemic = termobj.raw_phonemic
				termobj.phonetic = termobj.raw_phonetic
				-- set to nil so by-value comparisons respect only the resulting phonemic/phonetic and qualifiers
				termobj.raw_phonemic = nil
				termobj.raw_phonetic = nil
			else
				termobj.phonetic = to_IPA(termobj.words, dialect)
				-- set to nil so by-value comparisons respect only the resulting phonemic/phonetic and qualifiers
				termobj.words = nil
			end
		end
	end
end


-- Group pronunciations by dialect, i.e. grouping pronunciations that are identical in every way (including both the
-- pronunciation(s) and any qualifiers and other inline modifiers). `parsed_respellings` contains the output from
-- generate_phonemic_phonetic(), and the return value is a list of grouped pronunciations, where each object in the list
-- contains fields `dialects` (a list of dialects containing the pronunciations) and `pronuns` (a list of
-- pronunciations, where each pronunciation is specified by an object containing fields `phonemic` and `phonetic`, as
-- generated by generate_phonemic_phonetic(), along with any inline modifier fields `q`, `qq`, `a`, `aa` and/or `ref`).
function export.group_pronuns_by_dialect(parsed_respellings)
	local grouped_pronuns = {}
	for dialect, pronun_spec in pairs(parsed_respellings) do
		local saw_omitted = false
		for _, termobj in ipairs(pronun_spec.terms) do
			if termobj.omitted then
				saw_omitted = true
				break
			end
		end
		if not saw_omitted then
			local saw_existing = false
			for _, group in ipairs(grouped_pronuns) do
				if m_table.deepEquals(group.pronuns, pronun_spec.terms) then
					table.insert(group.dialects, dialect)
					saw_existing = true
					break
				end
			end
			if not saw_existing then
				table.insert(grouped_pronuns, {dialects = {dialect}, pronuns = pronun_spec.terms})
			end
		end
	end
	return grouped_pronuns
end


-- Format pronunciations grouped by dialect. `grouped_pronuns` contains the output of group_pronuns_by_dialect().
-- This destructively modifies `grouped_pronuns`, adding a field 'formatted' to the first-level values of
-- `grouped_pronuns` containing the formatted pronunciation(s) for a given set of dialects.
function export.format_grouped_pronunciations(grouped_pronuns)
	for _, grouped_pronun_spec in pairs(grouped_pronuns) do
		local pronunciations = {}

		-- Loop through each pronunciation. For each one, add the phonemic and phonetic versions to `pronunciations`,
		-- for formatting by [[Module:IPA]] or raw (for use in [[Module:ca-headword]]).
		for j, pronun in ipairs(grouped_pronun_spec.pronuns) do
			-- Add dialect tags to left accent qualifiers if first one
			local as = pronun.a
			if j == 1 then
				if as then
					as = m_table.deepcopy(as)
				else
					as = {}
				end
				for _, dialect in ipairs(grouped_pronun_spec.dialects) do
					table.insert(as, export.dialects_to_names[dialect])
				end
			end

			local first_pronun = #pronunciations + 1

			if pronun.unknown then
				-- FIXME: This is a massive hack but it works for now.
				table.insert(pronunciations, { pron = "", pretext = "''unknown''" })
			else
				if not pronun.phonemic and not pronun.phonetic then
					error("Internal error: Saw neither phonemic nor phonetic pronunciation")
				end

				if pronun.phonemic then -- missing if 'raw:[...]' given
					local slash_pron = "/" .. pronun.phonemic .. "/"
					table.insert(pronunciations, {
						pron = slash_pron,
					})
				end

				if pronun.phonetic then -- missing if '/.../' given
					local bracket_pron = "[" .. pronun.phonetic .. "]"
					table.insert(pronunciations, {
						pron = bracket_pron,
					})
				end
			end

			local last_pronun = #pronunciations

			if pronun.q then
				pronunciations[first_pronun].q = pronun.q
			end
			if as then
				pronunciations[first_pronun].a = as
			end
			if j > 1 then
				pronunciations[first_pronun].separator = ", "
			end
			if pronun.qq then
				pronunciations[last_pronun].qq = pronun.qq
			end
			if pronun.aa then
				pronunciations[last_pronun].aa = pronun.aa
			end
			if pronun.refs then
				pronunciations[last_pronun].refs = pronun.refs
			end
			if first_pronun ~= last_pronun then
				pronunciations[last_pronun].separator = " "
			end
		end

		grouped_pronun_spec.formatted = m_IPA.format_IPA_full {
			lang = lang,
			items = pronunciations,
			separator = "",
		}
	end
end


function export.show(frame)
	local params = {
		[1] = {},
		indent = {},
		pagename = {} -- for testing or documentation pages
	}

	for _, dialect in ipairs(export.dialects) do
		params[dialect] = {}
	end
	for dialect_group, _ in pairs(export.dialect_groups) do
		params[dialect_group] = {}
	end

	local args = require("Module:parameters").process(frame:getParent().args, params)
	local pagename = args.pagename or mw.title.getCurrentTitle().subpageText

	-- Set inputs
	local inputs = {}
	-- If 1= specified, do all dialects.
	if args[1] then
		for _, dialect in ipairs(export.dialects) do
			inputs[dialect] = {input = args[1], param = 1}
		end
	end
	-- Then do dialect groups.
	for dialect_group, group_dialects in pairs(export.dialect_groups) do
		if args[dialect_group] then
			for _, dialect in ipairs(group_dialects) do
				inputs[dialect] = {input = args[dialect_group], param = dialect_group}
			end
		end
	end
	-- Then do individual dialect settings.
	for _, dialect in ipairs(export.dialects) do
		if args[dialect] then
			inputs[dialect] = {input = args[dialect], param = dialect}
		end
	end
	-- If no inputs given, set all dialects based on current pagename.
	if not next(inputs) then
		for _, dialect in ipairs(export.dialects) do
			inputs[dialect] = {input = "+", param = "(pagename)"}
		end
	end

	-- Parse the arguments.
	local parsed_respellings = {}
	for dialect, inputspec in pairs(inputs) do
		local function generate_obj(respelling, parse_err)
			return parse_respelling(respelling, pagename, parse_err)
		end

		if inputspec.input:find("[<%[]") then
			local put = require(parse_utilities_module)
			-- Parse balanced segment runs involving either [...] (substitution notation) or <...> (inline modifiers).
			-- We do this because we don't want commas inside of square or angle brackets to count as respelling
			-- delimiters. However, we need to rejoin square-bracketed segments with nearby ones after splitting
			-- alternating runs on comma. For example, if we are given
			-- "a[x]a<q:learned>,[vol:vôl,ks]<q:nonstandard>", after calling
			-- parse_multi_delimiter_balanced_segment_run() we get the following output:
			--
			-- {"a", "[x]", "a", "<q:learned>", ",", "[vol:vôl,ks]", "", "<q:nonstandard>", ""}
			--
			-- After calling split_alternating_runs(), we get the following:
			--
			-- {{"a", "[x]", "a", "<q:learned>", ""}, {"", "[vol:vôl,ks]", "", "<q:nonstandard>", ""}}
			--
			-- We need to rejoin stuff on either side of the square-bracketed portions.
			local segments = put.parse_multi_delimiter_balanced_segment_run(inputspec.input, {{"<", ">"}, {"[", "]"}})

			local comma_separated_groups = put.split_alternating_runs_on_comma(segments)

			-- Process each value.
			local outer_container = export.parse_comma_separated_groups(comma_separated_groups, pagename,
				inputspec.input, inputspec.param)
			parsed_respellings[dialect] = outer_container
		else
			local termobjs = {}
			local function parse_err(msg)
				error(msg .. ": " .. inputspec.param .. "=" .. inputspec.input)
			end
			for _, term in ipairs(split_on_comma(inputspec.input)) do
				table.insert(termobjs, generate_obj(term, parse_err))
			end
			parsed_respellings[dialect] = {
				terms = termobjs,
			}
		end
	end

	-- Convert each canonicalized respelling to phonemic/phonetic IPA.
	export.generate_phonemic_phonetic(parsed_respellings)

	-- Group the results.
	local grouped_pronuns = export.group_pronuns_by_dialect(parsed_respellings)

	-- Format the results.
	export.format_grouped_pronunciations(grouped_pronuns)

	-- Concatenate formatted results.
	local formatted = {}
	for _, grouped_pronun_spec in ipairs(grouped_pronuns) do
		table.insert(formatted, grouped_pronun_spec.formatted)
	end
	local indent = (args.indent or "*") .. " "
	local out = table.concat(formatted, "\n" .. indent)
	if args.indent then
		out = indent .. out
	end

	return out
end

-- Used by [[Module:ca-IPA/testcases]].
function export.test(pagename, respelling, dialect)
	local function parse_err(msg)
		error(msg)
	end
	local parsed = parse_respelling(respelling, pagename, parse_err)
	return to_IPA(parsed.words, dialect)
end

return export
