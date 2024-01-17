local export = {}

local lang = require("Module:languages").getByCode("ca")

local m_IPA = require("Module:IPA")
local m_a = require("Module:accent qualifier")
local m_table = require("Module:table")

local parse_utilities_module = "Module:parse utilities"
local patut_module = "Module:pattern utilities"

local listToSet = require("Module:table").listToSet

--[=[
FIXME:

1. [zʒ] should reduce to [ʒ] in Central and Balearic ([[disjunt]], [[disjuntor]]). Similar for [sʃ] ([[desxifrar]]).
2. There needs to be a way of forcing [ʃ]. (Maybe just ʃ?) [DONE]
3. Make sure manual dot for syllable break works, cf. [[best-seller]] respelled `bèst.sèlerr'.
4. Explicit accents on a/i/u should be removed in split_syllables().
5. Compress double schwa in Central/Balearic in e.g. [[sobreescalfament]]; seems not to operate in Valencian.
6. bm -> [mm] e.g. [[subministrament]]; seems not to operate in Valencian.
7. ë (and presumably ê) doesn't work in secondary stress, always becomes /ɛ/ (e.g. in [[extrajudicial]] respelled
   'ëxtrajudiciàl'; this seems to be because the handling of ë goes through mid_vowel_hint, which doesn't work for
   secondary stress.
8. Respect ʃ at beginning of word in Valencian.
9. [ʃ] in single substitution specs should match against written x.
10. Prefixes e.g. [[xilo-]] should not have stress by default.
11. Remove single quote near beginning of processing so we don't need to respell infinitives like [[captindre's]].
12. Correctly handle -bl and -gl in respelling, generating [bl] and [gl].
13. Correctly handle [βðɣ] in respelling forcing fricatives; should not be fortitioned.
14. [βðɣ] in single substitution specs should match against b/d/g.
15. [ss] in single substitution specs should match against ss?; used to force a pronounced [s].
16. Correctly handle written -dg- after [rz]: fricatives in Valencian, stops in Central (and Balearic?).
17. Correctly handle lenition of written -bdg-: (1) -b- not lenited in Valencian or Balearic, lenited to [β] in
    Central Catalan after vowels and consonants except nasals and [rz]; (2) -g- not lenited after nasals, also not
	after [rz] in Central Catalan (and maybe Balearic?), otherwise yes except utterance initial; (3) -d- not lenited
	after nasals or laterals, also not after [rz] in Central Catalan (and maybe Balearic?), otherwise yes except
	utterance initial. Verify against ca-IPA equivalent on cawikt and also based on {{w|Catalan phonology}} and the IEC
	grammar that Vriullop linked.
18. Finish rewriting do_dialect_specific() to operate on whole word using Lua patterns.
19. Implement multiword handling.
20. Make sure suffix handling works correctly.
21. Add many more test cases and redo test harness ala the German test harness.
22. Redo handling of mid-vowel hints so it gets done early and in one place.
23. Think about how to solve the issue of mid-vowel hints along with secondary stress marks in substitution specs.
    Maybe a single mid-vowel spec should be rewritten to be a single substitution spec and the insertion of the
	mid-vowel spec should happen during resolution of substitution specs.
]=]


local usub = mw.ustring.sub
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local rsubn = mw.ustring.gsub
local ulower = mw.ustring.lower
local u = mw.ustring.char
local ugcodepoint = w.ustring.gcodepoint

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
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

local function track_mid_vowel(vowel, cont)
	require("Module:debug/track"){"ca-IPA/" .. vowel, "ca-IPA/" .. vowel .. "/" .. cont}
	return true
end


export.dialects = {"bal", "cen", "val"}
export.dialects_to_names = {
	bal = "Balearic",
	cen = "Central Catalan",
	val = "Valencian",
}
export.dialect_groups = {
	east = {"bal", "cen"},
}


local written_unaccented_vowel = "aeiouyAEIOUY"
local written_accented_vowel = "àèéêëíïòóôúüýÀÈÉÊËÍÏÒÓÔÚÜÝ"
local ipa_vowel = "ɔɛ"
local AV = "[" .. written_accented_vowel .. "]"
local written_vowel = written_unaccented_vowel .. written_accented_vowel
local vowel = written_vowel .. ipa_vowel
local V = "[" .. vowel .. "]"
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

local stress = AC .. GR
local stress_c = "[" .. AC .. GR .. "]"
local ipa_stress = "ˈˌ"
local ipa_stress_c = "[" .. ipa_stress .. "]"
local sylsep = "%-." .. SYLDIV -- hyphen included for syllabifying from spelling
local sylsep_c = "[" .. sylsep .. "]"
local wordsep = "# "
local separator_not_wordsep = accent .. ipa_stress .. sylsep
local separator = separator_not_wordsep .. wordsep
local separator_c = "[" .. separator .. "]"
local C = "[^" .. vowel .. separator .. "]" -- consonant class including h

export.mid_vowel_hints = "éèêëóòô"
export.mid_vowel_hint_c = "[" .. export.mid_vowel_hints .. "]"

local TEMP_PAREN_R = u(0xFFF1)
local TEMP_PAREN_RR = u(0xFFF2)

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
	"v", "vl",
	"w",
	"x",
	"z",
} 

local function fix_prefixes(word)
	-- Orthographic fixes for unassimilated prefixes
	local prefix = {
		"a[eè]ro", "ànte", "[aà]nti", "[aà]rxi", "[aà]uto", -- a- is ambiguous as prefix
		"bi", "b[ií]li", "bio",
		"c[oò]ntra", -- ambiguous co-
		"dia", "dodeca",
		"[eé]ntre", "equi", "estereo", -- ambiguous e-(radic)
		"f[oó]to",
		"g[aà]stro", "gr[eé]co",
		"hendeca", "hepta", "hexa", "h[oò]mo",
		"[ií]nfra", "[ií]ntra",
		"m[aà]cro", "m[ií]cro", "mono", "morfo", "m[uú]lti",
		"n[eé]o",
		"octo", "orto",
		"penta", "p[oòô]li", "pol[ií]tico", "pr[oòô]to", "ps[eèêë]udo", "psico", -- ambiguous pre-(s), pro-
		"qu[aà]si", "qu[ií]mio",
		"r[aà]dio", -- ambiguous re-
		"s[eèêë]mi", "s[oó]bre", "s[uú]pra",
		"termo", "tetra", "tri", -- ambiguous tele-(r)
		"[uú]ltra", "[uu]n[ií]",
		"v[ií]ce"
	}
	local prefix_r = {"[eèéêë]xtra", "pr[eé]"}
	local prefix_s = {"antropo", "centro", "deca", "d[ií]no", "eco", "[eèéêë]xtra",
		"hetero", "p[aà]ra", "post", "pré", "s[oó]ta", "tele"}
	local prefix_i = {"pr[eé]", "pr[ií]mo", "pro", "tele"}
	local no_prefix = {"autoic", "autori", "biret", "biri", "bisa", "bisell", "bisó", "biur", "contrari", "contrau",
		"diari", "equise", "heterosi", "monoi", "parasa", "parasit", "preix", "psicosi", "sobrera", "sobreri"}

	-- False prefixes
	for _, pr in ipairs(no_prefix) do
		if rfind(word, "^" .. pr) then
			return word
		end
	end

	-- Double r in prefix + r + vowel
	for _, pr in ipairs(prefix_r) do
		word = rsub(word, "^(" .. pr .. ")r([aàeèéiíïoòóuúü])", "%1rr%2")
	end
	word = rsub(word, "^eradic", "erradic")

	-- Double s in prefix + s + vowel
	for _, pr in ipairs(prefix_s) do
		word = rsub(word, "^(" .. pr .. ")s([aàeèéiíïoòóuúü])", "%1ss%2")
	end

	-- Hiatus in prefix + i
	for _, pr in ipairs(prefix_i) do
		word = rsub(word, "^(" .. pr .. ")i(.)", "%1ï%2")
	end

	-- Both prefix + r/s or i/u
	for _, pr in ipairs(prefix) do
		word = rsub(word, "^(" .. pr .. ")([rs])([aàeèéiíïoòóuúü])", "%1%2%2%3")
		word = rsub(word, "^(" .. pr .. ")i(.)", "%1ï%2")
		word = rsub(word, "^(" .. pr .. ")u(.)", "%1ü%2")
	end

	-- Voiced s in prefix roots -fons-, -dins-, -trans-
	word = rsub(word, "^enfons([aàeèéiíoòóuú])", "enfonz%1")
	word = rsub(word, "^endins([aàeèéiíoòóuú])", "endinz%1")
	word = rsub(word, "tr([aà])ns([aàeèéiíoòóuúbdghlmv])", "tr%1nz%2")

	-- in + ex > ineks/inegz
	word = rsub(word, "^inex", "inhex")

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

local function word_fixes(word)
	word = rsub(word, "%(rr%)", TEMP_PAREN_RR)
	word = rsub(word, "%(r%)", TEMP_PAREN_R)
	word = rsub(word, "%-([rs]?)", "-%1%1")
	word = rsub(word, "rç$", "rrs") -- silent r only in plurals -rs
	word = fix_prefixes(word) -- internal pause after a prefix
	word = restore_diaereses(word) -- no diaeresis saving
	word = fix_y(word) -- ny > ñ else y > i vowel or consonant
	-- all words in pn- (e.g. [[pneumotòrax]] and mn- (e.g. [[mnemònic]]) have silent p/m in both Central and Valencian
	word = rsub(word, "^[pm]n", "n")

	return word
end

local function split_vowels(vowels)
	local syllables = {{onset = "", vowel = usub(vowels, 1, 1), coda = ""}}
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

-- Split the word into syllables
local function split_syllables(remainder)
	local syllables = {}

	while remainder ~= "" do
		local consonants, vowels

		consonants, remainder = rmatch(remainder, "^([^aeiouàèéêëíòóôúïü]*)(.-)$")
		vowels, remainder = rmatch(remainder, "^([aeiouàèéêëíòóôúïü]*)(.-)$")

		if vowels == "" then
			syllables[#syllables].coda = syllables[#syllables].coda .. consonants
		else
			local onset = consonants
			local first_vowel = usub(vowels, 1, 1)

			if (rfind(onset, "[gq]$") and (first_vowel == "ü" or (first_vowel == "u" and vowels ~= "u")))
			or ((onset == "" or onset == "h") and #syllables == 0 and first_vowel == "i" and vowels ~= "i")
			then
				onset = onset .. usub(vowels, 1, 1)
				vowels = usub(vowels, 2)
			end

			local vsyllables = split_vowels(vowels)
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

		while not (current.onset == "" or valid_onsets[current.onset]) do
			local letter = usub(current.onset, 1, 1)
			current.onset = usub(current.onset, 2)
			if not rfind(letter, "[·%-%.]") then -- syllable separators
				previous.coda = previous.coda .. letter
			else
				break
			end
		end
	end

	-- Detect stress
	for i, syll in ipairs(syllables) do
		if rfind(syll.vowel, "^[àèéêëíòóôú]$") then
			syllables.stress = i -- primary stress: the last one stressed
			syll.stressed = true
		end
	end

	if not syllables.stress then
		local count = #syllables

		if count == 1 then
			syllables.stress = 1
		else
			local final = syllables[count]

			if final.coda == "" or final.coda == "s" or (final.coda == "n" and (final.vowel == "e" or final.vowel == "i")) then
				syllables.stress = count - 1
			else
				syllables.stress = count
			end
		end
		syllables[syllables.stress].stressed = true
	end

	return syllables
end

local IPA_vowels = {
	["a"] = "a", ["à"] = "a",
	["e"] = "e", ["è"] = "ɛ", ["ê"] = "ɛ", ["ë"] = "ɛ", ["é"] = "e",
	["i"] = "i", ["í"] = "i", ["ï"] = "i",
	["o"] = "o", ["ò"] = "ɔ", ["ô"] = "ɔ", ["ó"] = "o",
	["u"] = "u", ["ú"] = "u", ["ü"] = "u",
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
	cons = rsub(cons, "g", "ɡ") -- regular g to IPA ɡ
	cons = rsub(cons, "j", "ʒ")
	-- Don't replace x -> ʃ yet so we can distinguish x from manually specified ʃ.

	cons = rsub(cons, "i", "j") -- must be after j > ʒ
	cons = rsub(cons, "y", "j") -- must be after j > ʒ and fix_y
	cons = rsub(cons, "[uü]", "w")

	return cons
end


-- Do context-sensitive phonological changes. Formerly this was all done syllable-by-syllable but that made the code
-- tricky (since it often had to look at adjacent syllables) and full of subtle bugs. Now we first concatenate the
-- syllables back to a word and work on the word as a whole. FIXME: We should just keep the word always together and
-- not split into a syllable-by-syllable structure at all.
local function postprocess_general(syllables, dialect)
	-- Combine syllables.
	local combined = {}
	for i, syll in ipairs(syllables) do
		local ac = i == syllables.stress and AC or -- primary stress
			syllables[i].stressed and GR or -- secondary stress
			""
		table.insert(combined, syll.onset .. syll.vowel .. ac .. syll.coda)
	end
	local text = "##" .. table.concat(combined, ".") .. "##"

	local function concat_keys(tab)
		local res = {}
		for k, _ in pairs(tab) do
			table.insert(res, k)
		end
		return table.concat(res)
	end

	local voiced = listToSet {"b", "ð", "d", "ɡ", "m", "n", "ɲ", "l", "ʎ", "r", "ɾ", "v", "z", "ʒ", "ʣ", "ʤ"}
	local voiced_keys = concat_keys(voiced)
	local voiceless = listToSet {"p", "t", "k", "f", "s", "ʃ", "ʦ", "ʧ"}
	local voiceless_keys = concat_keys(voiceless)
	local voicing = {["p"] = "b", ["t"] = "d", ["k"] = "ɡ", ["f"] = "v", ["s"] = "z", ["ʃ"] = "ʒ", ["ʦ"] = "ʤ",
		["ʧ"] = "ʤ"}
	local voicing_keys = concat_keys(voicing)
	local devoicing = {}
	for k, v in pairs(voicing) do
		devoicing[v] = k
	end
	local devoicing_keys = concat_keys(devoicing)

	-- Handle ex(h)- + vowel > -egz-. We handle -x- on either side of the syllable boundary (ex- vs. exh-). Note that
	-- this also handles inex(h)- + vowel because in fix_prefixes we respell inex- as inhex-, which ends up at this
	-- stage as in.e.xV, or as in.ex.V in the case of inexh-.
	text = rsub_repeatedly(text, "([.#][eɛ]" .. stress_c .. "?)" .. sylsep_c .. "*x" .. sylsep_c .. "*(" .. V .. ")",
		"%1ɡ.z%2") --IPA ɡ

	-- Handle remaining x

	-- -x- at the beginning of a coda becomes [ks], e.g. [[annex]], [[apèndix]], [[extracció]]; but not elsewhere in
	-- the coda, e.g. in [[romanx]], [[ponx]]; words with [ks] in -nx such as [[esfinx]], [[linx]], [[manx]] need
	-- respelling with [ks]; words ending in vowel + x like [[ídix]] need respelling with [ʃ]
	text = rsub(text, "(" .. V .. stress_c .. "?)x", "%1ks")
	-- Other x becomes [ʃ]
	text = rsub(text, "x", "ʃ")

	-- Doubled ss -> s e.g. in exs-, exc(e/i)-, sc(e/i)-
	text = rsub(text, "s(" .. sylsep_c .. "*)s", "%1s")

	-- Coda consonant losses; in Central Catalan, they happen everywhere, but otherwise they don't happen when
	-- absolutely word-finally (e.g. [[blanc]] has /k/ in Balearic and Valencian but not [[blancs]]).
	local boundary = dialect == "cen" and "(.)" or "([^#])"
	text = rsub(text, "m[pb]" .. boundary, "m%1")
	text = rsub(text, "([ln])[td]" .. boundary, "%1%2")
	text = rsub(text, "[nŋ][kɡ]" .. boundary, "ŋ%1")

	-- Consonant assimilations

	-- t + lateral/nasal assimilation -> geminate across syllable boundary; FIXME: this doesn't always happen in -tl-,
	-- -tm-, e.g. [[atmosfèric]] [ədmusfɛ́ɾik] in GDLC along with [[tmesi]] [dmɛ́zi]; [[atlàntic]] has [əllántik] in GDLC
	-- but [adlántik] in DNV.
	text = rsub(text, "t(" .. sylsep_c .. ")([lʎmn])", "%2%1%2")

	-- ɡn -> ŋn e.g. [[regnar]] (including word-initial gn- e.g. [[gnòmic]], [[gneis]]) 
	text = rsub(text, "g(" .. sylsep_c .. "*n)", "ŋ%1")

	-- n + labial > labialized assimilation
	text = rsub(text, "n(" .. sylsep_c .. "*[mbp])", "m%1")
	text = rsub(text, "n(" .. sylsep_c .. "*[fv])", "ɱ%1")

	-- n + velar > velarized assimilation
	text = rsub(text, "n(" .. sylsep_c .. "*[kɡ])", "ŋ%1")

	-- l/n + palatal > palatalized assimilation
	text = rsub(text, "([ln])(" .. sylsep_c .. "*[ʎɲʃʒʧʤ])", function(ln, palatal)
		ln = ({["l"] = "ʎ", ["n"] = "ɲ"})[ln]
		return ln .. palatal
	end)

	-- ɡʒ > d͡ʒ
	text = rsub(text, "ɡ(" .. sylsep_c .. "*)ʒ", "%1ʤ")

	-- ɲs > ɲʃ; FIXME: not sure the purpose of this; it doesn't apply in [[menys]] or derived terms like [[menyspreu]]
	-- text = rsub(text, "ɲs", "%1ʃ")

	-- Voicing or devoicing; we want to proceed from right to left, and due to the limitations of patterns (in
	-- particular, the lack of support for alternations), it's difficult to do this cleanly using Lua patterns, so we
	-- do it character by character.
	local chars = split_into_chars(text)
	-- We need to look two characters ahead in some cases, so start two characters from the end. This is safe because
	-- the overall respelling ends in "##". (Similarly, as an optimization, don't check the first two characters, which
	-- are always "##".)
	for i = #chars - 2, 3, -1 do
		-- We are looking for two consonants next to each other, possibly separated by a syllable divider.
		-- We also handle a consonant followed by a syllable divider then a vowel, and a consonant word-finally.
		local first = chars[i]
		local second
		if not rfind(first, C) then
			-- continue
		elseif chars[i + 1] == "#" then
			second = ""
		elseif rfind(chars[i + 1], sylsep_c) then
			if rfind(chars[i + 2], C) then
				second = chars[i + 2]
			elseif rfind(chars[i + 2], V) then
				second = ""
			end
		elseif rfind(chars[i + 1], C) then
			second = chars[i + 1]
		end
		if second then
			if voiced[second] and voicing[first] then
				chars[i] = voicing[first]
			elseif (voiceless[second] or second == "") and devoicing[first] then
				chars[i] = devoicing[first]
			end
		end
	end
	text = table.concat(chars)

	-- ɾ -> r word-initially or after [lns]
	text = rsub(text, "([#lns]" .. sylsep_c .. ")ɾ", "%1r")

	-- no spirants after r/z
	-- FIXME: Spirant support isn't properly implemented.
	text = rsub(text, "([rzʣ]" .. sylsep_c .. "*)([βðɣ])", function(prev, fricative)
		fricative = ({["β"] = "b", ["ð"] = "d", ["ɣ"] = "ɡ"})[fricative]
		return prev .. fricative
	end)

	-- Final losses.
	text = rsub(text, "j(ʧs?#)", "%1") -- boigs /bɔt͡ʃ/
	text = rsub(text, "([ʃʧs])s#", "%1#") -- homophone plurals -xs, -igs, -çs

	-- Reduction of unstressed a,e in Central and Balearic (Eastern Catalan).
	if dialect ~= "val" then
		-- The following rules seem to apply, based on the old code:
		-- (1) Stressed a and e are never reduced.
		-- (2) Unstressed e directly following ə/o/ɔ is not reduced.
		-- (3) Unstressed e directly before written <a> or before /ɔ/ is not reduced.
		-- (4) Written <ee> when both vowels precede the primary stress is reduced to [əə]. (This rule preempts #2.)
		-- (5) Written <ee> when both vowels follow the primary stress isn't reduced at all.
		-- Rule #2 in particular seems to require that we proceed left to right, which is how the old code was
		-- implemented.
		-- FIXME: These rules seem overly complex and may produce incorrect results in some circumstances.
		local chars = split_into_chars(text)
		-- See above where voicing assimilation is handled. The overall respelling begins and ends in ## and we need to
		-- look ahead two or more chars.
		local seen_primary_stress = false
		for i = 3, #chars - 2 do
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
					prev = chars[i - 2]
					prev_stress = ""
					if rfind(prev, stress_c) then
						prev_stress = prev
						prev = chars[i - 3] or ""
					end
				end
				if not rfind(chars[i + 1], sylsep_c) then
					nxt = ""
					-- leave nxt at nil
				else
					nxt = chars[i + 2]
					nxt_stress = chars[i + 3] or ""
				end
				if this == "e" and rfind(prev, "[əoɔ]") then
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
	end
	text = table.concat(chars)

	return text
end


local function do_dialect_specific(syllables, dialect, mid_vowel_hint)
	syllables = mw.clone(syllables)

	for i = 1, #syllables do
		local current = syllables[i]
		local previous = syllables[i - 1]

		-- In replace_context_free(), we converted single r to ɾ and double rr to r.
		-- FIXME: For some reason, Central and Balearic final -r renders as /r/ but Valencian final -r renders as /ɾ/.
		-- This is inherited from the older code. Correct?
		if dialect == "cen" then
			current.coda = rsub(current.coda, TEMP_PAREN_R, "")
			current.coda = rsub(current.coda, TEMP_PAREN_RR, "r")
		elseif dialect == "bal" then
			current.coda = rsub(current.coda, TEMP_PAREN_R, "")
			current.coda = rsub(current.coda, TEMP_PAREN_RR, "")
		else
			current.coda = rsub(current.coda, TEMP_PAREN_R, "ɾ")
			current.coda = rsub(current.coda, TEMP_PAREN_RR, "ɾ")
			current.coda = rsub(current.coda, "r", "ɾ")
		end

		if dialect == "cen" then
			-- Reduction of unstressed o
			if current.vowel == "o" and not (current.stressed or current.coda == "w") then
				current.vowel = rsub(current.vowel, "o", "u")
			end
		elseif dialect == "bal" then
			-- Reduction of unstressed o per vowel harmony
			if i > 1 and current.stressed and rfind(current.vowel, "[iu]") and not previous.stressed then
				previous.vowel = rsub(previous.vowel, "o", "u")
			end
		else -- Valencian
			-- Variable mid vowel
			if i == syllables.stress and (mid_vowel_hint == "ê" or mid_vowel_hint == "ë" or mid_vowel_hint == "ô") then
				current.vowel = rsub(current.vowel, "[ɛëɔ]", {["ɛ"] = "e", ["ë"] = "e", ["ɔ"] = "o"})
			end
		end

		if dialect == "cen" then
			-- v > b
			current.onset = rsub(current.onset, "v", "b")
			current.coda = rsub(current.coda, "nb", "mb")
			if i > 1 and rfind(current.onset, "^b") then
				previous.coda = rsub(previous.coda, "n$", "m")
			end
		end

		if dialect ~= "val" then
			-- bl -> bbl, gl -> ggl after the stress; to avoid this, write b.l or g.l so the b/g is in a separate
			-- syllable; this must follow v > b above; NOTE: IPA ɡ must be used here not regular g
			if i > 1 and previous.coda == "" and previous.stressed then
				local bg = rmatch(current.onset, "^([bɡ])l")
				if bg then
					previous.coda = bg
				end
			end
		else -- Valencian; undo manually written 'bbl', 'ggl' in words like [[poblar]], [[reglament]]
			if i > 1 then
				local bg = rmatch(current.onset, "^([bɡ])l")
				if bg and previous.coda == bg then
					previous.coda = ""
				end
			end
		end

		if dialect == "cen" then
			-- allophones of r
			current.coda = rsub(current.coda, "ɾ", "r")
		end

		if dialect == "bal" then
			-- Stressed schwa
			if i == syllables.stress and mid_vowel_hint == "ê" then -- not ë
				current.vowel = rsub(current.vowel, "ɛ", "ə")
			end
		end

		if dialect ~= "val" then
			-- Remove j before palatal obstruents
			current.coda = rsub(current.coda, "j([ʃʒʧʤ])", "%1")

			if i > 1 then
				if rfind(current.onset, "^[ʃʒʧʤ]") then
					previous.coda = rsub(previous.coda, "j$", "")
				end
			end
		else -- Valencian
			-- Fortition of palatal fricatives
			current.onset = rsub(current.onset, "ʒ", "ʤ")
			current.coda = rsub(current.coda, "ʒ", "ʤ")

			if i > 1 and previous.vowel == "i" and previous.coda == "" and current.onset == "ʣ" then
				current.onset = "z"
			elseif (i == 1 and current.onset == "ʃ")
				or (i > 1 and current.onset == "ʃ" and previous.coda ~= "" and previous.coda ~= "j")
				then
				current.onset = "ʧ"
			end
		end

		if dialect ~= "cen" then
			-- No palatal gemination ʎʎ > ll or ʎ, in Valencian and Balearic
			if i > 1 and current.onset == "ʎ" and previous.coda == "ʎ" then
				local prev_syll = previous.onset .. previous.vowel .. previous.coda
				if rfind(prev_syll, "[bpw]aʎ$")
					or rfind(prev_syll, "[mv]eʎ$")
					or rfind(prev_syll, "tiʎ$")
					or rfind(prev_syll, "m[oɔ]ʎ$")
					or (rfind(prev_syll, "uʎ$") and current.vowel == "a")
					then
					previous.coda = "l"
					current.onset = "l"
				else
					previous.coda = ""
				end
			end
		end
	end

	return syllables
end


local function mid_vowel_e(syllables)
	-- most common cases, other ones are assumed ambiguous
	post_consonants = syllables[syllables.stress].coda
	post_vowel = ""
	post_letters = post_consonants
	if syllables.stress == #syllables - 1 then
		post_consonants = post_consonants .. syllables[#syllables].onset
		post_vowel = syllables[#syllables].vowel
		post_letters = post_consonants .. post_vowel .. syllables[#syllables].coda
	end

	if syllables[syllables.stress].vowel == "e" then
		-- final -el (not -ell) usually è but not too many cases
		if post_letters == "nt" or post_letters == "nts" then
			track_mid_vowel("e", "nt-nts")
			return "é"
		elseif rfind(post_letters, "^r[ae]?s?$") then
			track_mid_vowel("e", "r-rs-ra-res")
			return "é"
		elseif rfind(post_consonants, "^r[dfjlnrstxyz]") then -- except bilabial and velar
			track_mid_vowel("e", "rC")
			return "è"
		elseif post_letters == "sos" or post_letters == "sa" or post_letters == "ses" then -- inflection of -ès
			track_mid_vowel("e", "sos-sa-ses")
			return "ê"
		end
	elseif syllables[syllables.stress].vowel == "è" then
		if post_letters == "s" or post_letters == "" then -- -ès, -è
			track_mid_vowel("è", "s-blank")
			return "ê"
		end
	end

	return nil
end

local function mid_vowel_o(syllables)
	-- most common cases, other ones are assumed ambiguous
	post_consonants = syllables[syllables.stress].coda
	post_vowel = ""
	post_letters = post_consonants
	if syllables.stress == #syllables - 1 then
		post_consonants = post_consonants .. syllables[#syllables].onset
		post_vowel = syllables[#syllables].vowel
		post_letters = post_consonants .. post_vowel .. syllables[#syllables].coda
	end

	if post_vowel == "u" then
		track_mid_vowel("o", "u")
		return "ò"
	-- this may be mostly OK but there aren't too many examples; if we want to add this it should be limited to -oic(s)/-oica/-oiques, -oide(s)
	--elseif usub(post_letters, 1, 1) == "i" and usub(post_letters, 1, 2) ~= "ix" then -- diphthong oi
	--	track_mid_vowel("o", "i-not-ix")
	--	return "ò"
	elseif rfind(post_letters, "^r[ae]?s?$") then
		track_mid_vowel("o", "r-rs-ra-res")
		return "ó"
	end

	return nil
end

local function to_IPA(syllables, suffix_syllables, mid_vowel_hint, pos)
	-- Stressed vowel is ambiguous
	if rfind(syllables[syllables.stress].vowel, "[eéèoòó]") then
		if mid_vowel_hint then
			syllables[syllables.stress].vowel = mid_vowel_hint
		elseif syllables[syllables.stress].vowel == "e" or syllables[syllables.stress].vowel == "o" then
			local marks = {["e"] = mw.ustring.char(0x0301, 0x0300, 0x0302, 0x0308), ["o"] = mw.ustring.char(0x0301, 0x0300, 0x0302)}
			error("The stressed vowel \"" .. syllables[syllables.stress].vowel
				.. "\" is ambiguous. Please mark it with an acute, grave, or combined accent: "
				.. table.concat(
					require("Module:fun").map(
						function (accent)
							return syllables[syllables.stress].vowel .. accent
						end,
						marks[syllables[syllables.stress].vowel]),
					", "):gsub("^(.+), ", "%1, or ")
				.. ".")
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
		-- FIXME: Explicit accents on a/i/u should be removed in split_syllables().
		if final.coda == "r" and rfind(final.vowel, "[aàiíé]") or final.coda == "rs" and rfind(final.vowel, "[é]") or
			final.vowel == "ó" and rfind(final.coda, "^rs?$") and rfind(final.onset, "[stdç]") then
			final.coda = TEMP_PAREN_R
		end
	end
	if rfind(final.coda, "^rs?$") or rfind(final.coda, "[^r]rs?$") then
		error("Final -r by itself or in -rs is ambiguous except in the verbal endings -ar or -ir, in the nominal " ..
			"or adjectival endings -er(s) and -[dtsç]or(s). In all other cases it needs to be rewritten using one " ..
			"of 'rr' (pronounced everywhere), '(rr)' (pronounced everywhere but Balearic) or '(r)' (pronounced only " ..
			"in Valencian). Note that adjectives in -ar usually need rewriting using '(rr)'; nouns in -ar referring " ..
			"to places should be rewritten using '(r)'; and loanword nouns in -ir usually need rewriting using 'rr'.")
	end

	local syllables_IPA = {stress = syllables.stress}

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

		syll.vowel = rsub(syll.vowel, ".", IPA_vowels)
	end

	for _, suffix_syl in ipairs(suffix_syllables) do
		table.insert(syllables_IPA, suffix_syl)
	end

	syllables_IPA = postprocess_general(syllables_IPA)

	return syllables_IPA
end

-- Reduction of unstressed a,e in Central and Balearic (Eastern Catalan)
local function reduction_ae(syllables)
	for i = 1, #syllables do
		local current = syllables[i]
		local previous = syllables[i - 1] or {onset = "", vowel = "", coda = ""}
		local posterior = syllables[i + 1] or {onset = "", vowel = "", coda = ""}

		local pre_vowel_pair = previous.vowel .. previous.coda .. current.onset .. current.vowel
		local post_vowel_pair = current.vowel .. current.coda .. posterior.onset .. posterior.vowel
		local reduction = true

		if current.stressed then
			reduction = false
		elseif pre_vowel_pair == "əe" then
			reduction = false
		elseif post_vowel_pair == "ea" or post_vowel_pair == "eɔ" then
			reduction = false
		elseif i < syllables.stress - 1 and post_vowel_pair == "ee" then
			posterior.vowel = "ə"
		elseif i > syllables.stress and post_vowel_pair == "ee" then
			reduction = false
		elseif pre_vowel_pair == "oe" or pre_vowel_pair == "ɔe" then
			reduction = false
		end

		if reduction then
			current.vowel = rsub(current.vowel, "[ae]", "ə")
		end
	end
	return syllables
end


local function do_dialect_specific(syllables, dialect, mid_vowel_hint)
	syllables = mw.clone(syllables)

	if dialect ~= "val" then
		-- Reduction of unstressed vowels a,e
		syllables = reduction_ae(syllables)
	end

	for i = 1, #syllables do
		local current = syllables[i]
		local previous = syllables[i - 1]

		-- In replace_context_free(), we converted single r to ɾ and double rr to r.
		-- FIXME: For some reason, Central and Balearic final -r renders as /r/ but Valencian final -r renders as /ɾ/.
		-- This is inherited from the older code. Correct?
		if dialect == "cen" then
			current.coda = rsub(current.coda, TEMP_PAREN_R, "")
			current.coda = rsub(current.coda, TEMP_PAREN_RR, "r")
		elseif dialect == "bal" then
			current.coda = rsub(current.coda, TEMP_PAREN_R, "")
			current.coda = rsub(current.coda, TEMP_PAREN_RR, "")
		else
			current.coda = rsub(current.coda, TEMP_PAREN_R, "ɾ")
			current.coda = rsub(current.coda, TEMP_PAREN_RR, "ɾ")
			current.coda = rsub(current.coda, "r", "ɾ")
		end

		if dialect == "cen" then
			-- Reduction of unstressed o
			if current.vowel == "o" and not (current.stressed or current.coda == "w") then
				current.vowel = rsub(current.vowel, "o", "u")
			end
		elseif dialect == "bal" then
			-- Reduction of unstressed o per vowel harmony
			if i > 1 and current.stressed and rfind(current.vowel, "[iu]") and not previous.stressed then
				previous.vowel = rsub(previous.vowel, "o", "u")
			end
		else -- Valencian
			-- Variable mid vowel
			if i == syllables.stress and (mid_vowel_hint == "ê" or mid_vowel_hint == "ë" or mid_vowel_hint == "ô") then
				current.vowel = rsub(current.vowel, "[ɛëɔ]", {["ɛ"] = "e", ["ë"] = "e", ["ɔ"] = "o"})
			end
		end

		if dialect == "cen" then
			-- v > b
			current.onset = rsub(current.onset, "v", "b")
			current.coda = rsub(current.coda, "nb", "mb")
			if i > 1 and rfind(current.onset, "^b") then
				previous.coda = rsub(previous.coda, "n$", "m")
			end
		end

		if dialect ~= "val" then
			-- bl -> bbl, gl -> ggl after the stress; to avoid this, write b.l or g.l so the b/g is in a separate
			-- syllable; this must follow v > b above; NOTE: IPA ɡ must be used here not regular g
			if i > 1 and previous.coda == "" and previous.stressed then
				local bg = rmatch(current.onset, "^([bɡ])l")
				if bg then
					previous.coda = bg
				end
			end
		else -- Valencian; undo manually written 'bbl', 'ggl' in words like [[poblar]], [[reglament]]
			if i > 1 then
				local bg = rmatch(current.onset, "^([bɡ])l")
				if bg and previous.coda == bg then
					previous.coda = ""
				end
			end
		end

		if dialect == "cen" then
			-- allophones of r
			current.coda = rsub(current.coda, "ɾ", "r")
		end

		if dialect == "bal" then
			-- Stressed schwa
			if i == syllables.stress and mid_vowel_hint == "ê" then -- not ë
				current.vowel = rsub(current.vowel, "ɛ", "ə")
			end
		end

		if dialect ~= "val" then
			-- Remove j before palatal obstruents
			current.coda = rsub(current.coda, "j([ʃʒʧʤ])", "%1")

			if i > 1 then
				if rfind(current.onset, "^[ʃʒʧʤ]") then
					previous.coda = rsub(previous.coda, "j$", "")
				end
			end
		else -- Valencian
			-- Fortition of palatal fricatives
			current.onset = rsub(current.onset, "ʒ", "ʤ")
			current.coda = rsub(current.coda, "ʒ", "ʤ")

			if i > 1 and previous.vowel == "i" and previous.coda == "" and current.onset == "ʣ" then
				current.onset = "z"
			elseif (i == 1 and current.onset == "ʃ")
				or (i > 1 and current.onset == "ʃ" and previous.coda ~= "" and previous.coda ~= "j")
				then
				current.onset = "ʧ"
			end
		end

		if dialect ~= "cen" then
			-- No palatal gemination ʎʎ > ll or ʎ, in Valencian and Balearic
			if i > 1 and current.onset == "ʎ" and previous.coda == "ʎ" then
				local prev_syll = previous.onset .. previous.vowel .. previous.coda
				if rfind(prev_syll, "[bpw]aʎ$")
					or rfind(prev_syll, "[mv]eʎ$")
					or rfind(prev_syll, "tiʎ$")
					or rfind(prev_syll, "m[oɔ]ʎ$")
					or (rfind(prev_syll, "uʎ$") and current.vowel == "a")
					then
					previous.coda = "l"
					current.onset = "l"
				else
					previous.coda = ""
				end
			end
		end
	end

	return syllables
end


local function join_syllables(syllables)
	syllables = mw.clone(syllables)

	for i, syll in ipairs(syllables) do
		syll = syll.onset .. syll.vowel .. syll.coda

		if i == syllables.stress then -- primary stress
			syll = "ˈ" .. syll
		elseif syllables[i].stressed then -- secondary stress
			syll = "ˌ" .. syll
		end

		syllables[i] = syll
	end

	local text = rsub(table.concat(syllables, "."), ".([ˈˌ])", "%1")
	local full_affricates = { ["ʦ"] = "t͡s", ["ʣ"] = "d͡z", ["ʧ"] = "t͡ʃ", ["ʤ"] = "d͡ʒ" }
	text = rsub(text, "([ʦʣʧʤ])", full_affricates)
	return text
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
	escaped_from = escaped_from:gsub("ks", "x"):gsub("gz", "x"):gsub("([bg])%1l", "%1l"):gsub("[.%-]", "")
	escaped_from = require(patut_module).pattern_escape(escaped_from)
	escaped_from = escaped_from:gsub("rr", "rr?")
	escaped_from = rsub(escaped_from, AV, function(v) return "[" .. v .. written_accented_to_plain_vowel[v] .. "]" end)
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


-- Parse a respelling given by the user, allowing for '+' for pagename, mid vowel hints in place of a respelling
-- and substitution specs like '[ks]' or [val:vol,ê,ks]. In general, return an object
-- {term = PARSED_RESPELLING, mid_vowel_hint = MID_VOWEL_HINT}. Other fields are set in special cases: If a raw
-- respelling was seen, the fields `raw_phonemic` and/or `raw_phonetic` are set; if ? is seen, the field `unknown` is
-- set; and if - is seen, the field `omitted` is set.
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

	local pos, rest = respelling:match("^([a-z]+)/(.*)$")
	if pos then
		if not canonicalize_pos[pos] then
			local valid_pos = {}
			for vp, _ in pairs(canonicalize_pos) do
				table.insert(valid_pos, vp)
			end
			error(("Unrecognized part of speech '%s', should be one of %s"):format(pos, table.concat(valid_pos, ", ")))
		end
		pos = canonicalize_pos[pos]
		respelling = rest
		if respelling == "" then
			respelling = "+"
		end
	end

	local mid_vowel_hint
	if respelling == "+" then
		respelling = pagename
	elseif rfind(respelling, "^" .. export.mid_vowel_hint_c .. "$") then
		mid_vowel_hint = respelling
		respelling = pagename
	elseif rfind(respelling, "^%[.*%]$") then
		local subs = rsplit(rmatch(respelling, "^%[(.*)%]$"), ",")
		respelling = pagename
		for _, sub in ipairs(subs) do
			local from, escaped_from, to, escaped_to, whole_word
			if rfind(sub, "^~") then
				-- whole-word match
				sub = rmatch(sub, "^~(.*)$")
				whole_word = true
			end
			if sub:find(":") then
				from, to = rmatch(sub, "^(.-):(.*)$")
			elseif rfind(sub, "^" .. export.mid_vowel_hint_c .. "$") then
				if mid_vowel_hint then
					parse_err(("Specified mid vowel hint twice, '%s' and '%s'"):format(
						mid_vowel_hint, sub))
				end
				mid_vowel_hint = sub
			else
				to = sub
				from = convert_single_substitution_to_original(to, pagename, whole_word)
			end
			if from then
				local patut = require(patut_module)
				escaped_from = patut.pattern_escape(from)
				if whole_word then
					escaped_from = "%f[%a]" .. escaped_from .. "%f[%A]"
				end
				escaped_to = patut.replacement_escape(to)
				local subbed_respelling, nsubs = rsubn(respelling, escaped_from, escaped_to)
				if nsubs == 0 then
					parse_err(("Substitution spec %s -> %s didn't match processed pagename"):format(from, to))
				elseif nsubs > 1 then
					parse_err(("Substitution spec %s -> %s matched multiple substrings in processed pagename, add more context"):format(from, to))
				else
					respelling = subbed_respelling
				end
			end
		end
	end

	return {term = respelling, mid_vowel_hint = mid_vowel_hint, pos = pos}
end


-- Parse a list of comma-split runs containing one or more respellings, i.e. after calling parse_balanced_segment_run()
-- or the like followed by split_alternating_runs() or the like (see [[Module:parse utilities]]). `pagename` is the
-- pagename, for use when a respelling is just '+', a mid-vowel hint like 'ê' or a substitution spec like '[ks]'.
-- `original_input` is the raw input and `input_param` the name of the param containing the raw input; both are used
-- only in error messages. Return an object specifying the respellings, currently with a single field 'terms' (this
-- format is used in case other outer properties exist in the future), where 'terms' is a list of term objects. Each
-- term object contains either a field 'term' with the respelling and an optional field 'mid_vowel_hint' with the
-- extracted mid-vowel hint (e.g. "ê"), or fields 'raw_phonemic' and/or 'raw_phonetic' (if the user specified raw IPA
-- using "/.../" or "/.../ [...]" or "raw:[...]"). In addition, there may be fields 'q', 'qq', 'a', 'aa', and/or 'ref'
-- corresponding to inline modifiers. Each such field is a list; all are lists of strings except for 'ref', which is
-- a list of objects as returned by parse_references() in [[Module:references]].
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


-- Generate the pronunciation of `word` (a string, the respelling), where `mid_vowel_hint` specifies how to handle
-- stressed mid vowels. Return two values: the phonemic pronunciation along with the mid vowel hint, determined from
-- the respelling itself if `mid_vowel_hint` isn't passed in.
local function generate_pronun_syllables(word, mid_vowel_hint, pos)
	local suffix_syllables = {}
	if not pos or pos == "adverb" then
		local word_before_ment, ment = rmatch(word, "^(.*)(m[eé]nt)$")
		if word_before_ment and (pos == "adverb" or not rfind(word_before_ment, "[iï]$") and
			rfind(word_before_ment, V .. ".*" .. V)) then
			suffix_syllables = {{onset = "m", vowel = "e", coda = "nt", stressed = true}}
			pos = "adjective"
			word = word_before_ment
		end
	end

	word = word_fixes(word)

	local syllables = split_syllables(word)
	if mid_vowel_hint == nil then
		if rfind(syllables[syllables.stress].vowel, "[éêëòóô]") then
			mid_vowel_hint = rmatch(syllables[syllables.stress].vowel, "[éêëòóô]")
		elseif rfind(syllables[syllables.stress].vowel, "[eè]") then
			mid_vowel_hint = mid_vowel_e(syllables)
		elseif syllables[syllables.stress].vowel == "o" then
			mid_vowel_hint = mid_vowel_o(syllables)
		end
	end

	local ipa_syllables = to_IPA(syllables, suffix_syllables, mid_vowel_hint, pos)
	if #suffix_syllables > 0 then
		ipa_syllables.stress = #ipa_syllables
	end
	return ipa_syllables, mid_vowel_hint
end


-- Generate the phonemic and phonetic pronunciations of the respellings in `parsed_respellings`, which is a table whose
-- keys are dialect identifiers (e.g. "cen" for Central Catalan, "val" for Valencian) and whose values are objects of
-- the format returned by parse_comma_separated_groups() (see comment above that function). This destructively modifies
-- `parsed_respellings`, adding fields `phonemic` and `phonetic` containing the generated pronunciations and removing
-- the input fields used to generate those output fields. (FIXME: Currently only phonemic pronunciation is generated.)
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
				local word = ulower(termobj.term)
				local mid_vowel_hint = termobj.mid_vowel_hint
				local syllables, mid_vowel_hint = generate_pronun_syllables(word, mid_vowel_hint, termobj.pos)
				termobj.phonemic = join_syllables(do_dialect_specific(syllables, dialect, mid_vowel_hint))
				-- set to nil so by-value comparisons respect only the resulting phonemic/phonetic and qualifiers
				termobj.term = nil
				termobj.mid_vowel_hint = nil
			end
		end
	end
end


-- Group pronunciations by dialect, i.e. grouping pronunciations that are identical in every way (including both the
-- pronunciation(s) and any qualifiers and other inline modifiers). `parsed_respellings` contains the output from
-- generate_phonemic_phonetic(), and the return value is a list of grouped pronunciations, where each object in the list
-- contains fields 'dialects' (a list of dialects containing the pronunciations) and 'pronuns' (a list of
-- pronunciations, where each pronunciation is specified by an object containing fields 'phonemic' and 'phonetic', as
-- generated by generate_phonemic_phonetic(), along with any inline modifier fields 'q', 'qq', 'a', 'aa' and/or 'ref').
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

		grouped_pronun_spec.formatted = m_IPA.format_IPA_full(lang, pronunciations, nil, "")
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
function export.test(word, mid_vowel_hint, pos)
	local syllables, mid_vowel_hint = generate_pronun_syllables(word, mid_vowel_hint, pos)

	local grouped = {}

	for _, dialect in ipairs(export.dialects) do
		local ipa = join_syllables(do_dialect_specific(syllables, dialect, mid_vowel_hint))
		if grouped[ipa] then
			table.insert(grouped[ipa], dialect)
		else
			grouped[ipa] = {dialect}
		end
	end

	local out = {}

	for ipa, dialects in pairs(grouped) do
		local dialect_names = {}
		for _, dialect in ipairs(dialects) do
			table.insert(dialect_names, export.dialects_to_names[dialect])
		end
		table.insert(out, table.concat(dialect_names, ", ") .. ": /" .. ipa .. "/")
	end

	table.sort(out)
	return table.concat(out, ";<br>")
end

-- on debug console use: =p.debug("your_word", "your_hint", "your_pos")
function export.debug(word, mid_vowel_hint, pos)
	local syllables, mid_vowel_hint = generate_pronun_syllables(ulower(word), mid_vowel_hint, pos)

	local ret = {}

	for _, dialect in ipairs(export.dialects) do
		local syllables_accented = do_dialect_specific(syllables, dialect, mid_vowel_hint)
		table.insert(ret, dialect .. " " .. join_syllables(syllables_accented))
	end

	return table.concat(ret, "\n")
end

return export
