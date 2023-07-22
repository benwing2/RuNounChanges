local export = {}

local m_links = require("Module:links")
local m_table = require("Module:table")
local ar_utilities = require("Module:ar-utilities")
local ar_nominals = require("Module:ar-nominals")

local lang = require("Module:languages").getByCode("ar")
local yesno = require("Module:yesno")

--[[

Author: User:Benwing, from early version by User:Atitarev, User:ZxxZxxZ

Todo:

1. Finish unimplemented conjugation types. Only IX-final-weak left (extremely
   rare, possibly only one verb اِعْمَايَ (according to Haywood and Nahmad p. 244,
   who are very specific about the irregular occurrence of alif + yā instead
   of expected اِعْمَيَّ with doubled yā). Not in Hans Wehr.
2. Implement irregular verbs as special cases and recognize them, e.g.
   -- laysa "to not be"; only exists in the past tense, no non-past, no
	  imperative, no participles, no passive, no verbal noun. Irregular
	  alternation las-/lays-.
   -- istaḥā yastaḥī "be ashamed of" -- this is complex according to Hans Wehr
	  because there are two verbs, regular istaḥyā yastaḥyī "to spare
	  (someone)'s life" and irregular istaḥyā yastaḥyī "to be ashamed to face
	  (someone)", which is irregular because it has the alternate irregular
	  form istaḥā yastaḥī which only applies to this meaning. Currently we
	  follow Haywood and Nahmad in saying that both varieties can be spelled
	  istaḥyā/istaḥā/istaḥḥā, but we should instead use a variant= param
	  similar to حَيَّ to distinguish the two possibilities, and maybe not
	  include istaḥḥā.
   -- ʿayya/ʿayiya yaʿayyu/yaʿyā "to not find the right way, be incapable of,
	  stammer, falter, fall ill". This appears to be a mixture of a geminate
	  and final-weak verb. Unclear what the whole paradigm looks like. Do
	  the consonant-ending parts in the past follow the final-weak paradigm?
	  Is it the same in the non-past? Or can you conjugate the non-past
	  fully as either geminate or final-weak?
   -- اِنْمَحَى inmaḥā or يمَّحَى immaḥā "to be effaced, obliterated; to disappear, vanish"
	  has irregular assimilation of inm- to imm- as an alternative. inmalasa
	  "to become smooth; to glide; to slip away; to escape" also has immalasa
	  as an alternative. The only other form VII verbs in Hans Wehr beginning
	  with -m- are inmalaḵa "to be pulled out, torn out, wrenched" and inmāʿa
	  "to be melted, to melt, to dissolve", which are not listed with imm-
	  alternatives, but might have them; if so, we should handle this generally.
3. Implement individual override parameters for each pardigm part. See
   Module:fro-verb for an example of how to do this generally. Note that
   {{temp|ar-conj-I}} and other of the older templates already had such
   individual override params.

Irregular verbs already implemented:

   -- [ḥayya/ḥayiya yaḥyā "live" -- behaves like a normal final-weak verb
	  (e.g. past first singular ḥayītu) except in the past-tense parts with
	  vowel-initial endings (all the third person except for the third feminine
	  plural). The normal singular and dual endings have -yiya- in them, which
	  compresses to -yya-, with the normal endings the less preferred ones.
	  In masculine third plural, expected ḥayū is replaced by ḥayyū by
	  analogy to the -yy- parts, and the regular form is not given as an
	  alternant in John Mace. Barron's 201 verbs appears to have the regular
	  ḥayū as the part, however. Note also that final -yā appears with tall
	  alif. This appears to be a spelling convention of Arabic, also applying
	  in ḥayyā (form II, "to keep (someone) alive") and 'aḥyā (form IV,
	  "to animate, revive, give birth to, give new life to").] -- implemented
   -- [ittaxadha yattaxidhu "take"] -- implemented
   -- [sa'ala yas'alu "ask" with alternative jussive/imperative yasal/sal] -- implemented
   -- [ra'ā yarā "see"] -- implemented
   -- ['arā yurī "show"] -- implemented
   -- ['akala ya'kulu "eat" with imperative kul] -- implemented
   -- ['axadha ya'xudhu "take" with imperative xudh] -- implemented
   -- ['amara ya'muru "order" with imperative mur] -- implemented

--]]

local curtitle = mw.title.getCurrentTitle().fullText

local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local usub = mw.ustring.sub
local ulen = mw.ustring.len
local u = mw.ustring.char

-- don't display i3rab in nominal forms (verbal nouns, participles)
local no_nominal_i3rab = true

-- Within this module, conjugations are the functions that do the actual
-- conjugating by creating the parts of a basic verb.
-- They are defined further down.
local conjugations = {}
-- hamza variants
local HAMZA            = u(0x0621) -- hamza on the line (stand-alone hamza) = ء
local HAMZA_ON_ALIF    = u(0x0623)
local HAMZA_ON_W       = u(0x0624)
local HAMZA_UNDER_ALIF = u(0x0625)
local HAMZA_ON_Y       = u(0x0626)
local HAMZA_ANY        = "[" .. HAMZA .. HAMZA_ON_ALIF .. HAMZA_UNDER_ALIF .. HAMZA_ON_W .. HAMZA_ON_Y .. "]"
local HAMZA_PH         = u(0xFFF0) -- hamza placeholder

-- diacritics
local A  = u(0x064E) -- fatḥa
local AN = u(0x064B) -- fatḥatān (fatḥa tanwīn)
local U  = u(0x064F) -- ḍamma
local UN = u(0x064C) -- ḍammatān (ḍamma tanwīn)
local I  = u(0x0650) -- kasra
local IN = u(0x064D) -- kasratān (kasra tanwīn)
local SK = u(0x0652) -- sukūn = no vowel
local SH = u(0x0651) -- šadda = gemination of consonants
local DAGGER_ALIF = u(0x0670)
local DIACRITIC_ANY_BUT_SH = "[" .. A .. I .. U .. AN .. IN .. UN .. SK .. DAGGER_ALIF .. "]"
-- Pattern matching short vowels
local AIU = "[" .. A .. I .. U .. "]"
-- Pattern matching short vowels or sukūn
local AIUSK = "[" .. A .. I .. U .. SK .. "]"
-- Pattern matching any diacritics that may be on a consonant
local DIACRITIC = SH .. "?" .. DIACRITIC_ANY_BUT_SH
-- Suppressed UN; we don't show -un i3rab any more, but this can be changed to show it
local UNS = no_nominal_i3rab and "" or UN

local dia = {a = A, i = I, u = U}

-- various letters and signs
local ALIF   = u(0x0627) -- ʾalif = ا
local AMAQ   = u(0x0649) -- ʾalif maqṣūra = ى
local AMAD   = u(0x0622) -- ʾalif madda = آ
local TAM    = u(0x0629) -- tāʾ marbūṭa = ة
local T      = u(0x062A) -- tāʾ = ت
local HYPHEN = u(0x0640)
local N      = u(0x0646) -- nūn = ن
local W      = u(0x0648) -- wāw = و
local Y      = u(0x064A) -- yāʾ = ي
local S      = "س"
local M      = "م"
local LRM    = u(0x200e) -- left-to-right mark

-- common combinations
local AH    = A .. TAM
local AT    = A .. T
local AA    = A .. ALIF
local AAMAQ = A .. AMAQ
local AAH   = AA .. TAM
local AAT   = AA .. T
local II    = I .. Y
local IY    = II
local UU    = U .. W
local AY    = A .. Y
local AW    = A .. W
local AYSK  = AY .. SK
local AWSK  = AW .. SK
local NA    = N .. A
local NI    = N .. I
local AAN   = AA .. N
local AANI  = AA .. NI
local AYNI  = AYSK .. NI
local AWNA  = AWSK .. NA
local AYNA  = AYSK .. NA
local AYAAT = AY .. AAT
local UNU   = "[" .. UN .. U .. "]"
local MA    = M .. A
local MU    = M .. U

-------------------------------------------------------------------------------
--                                Utility functions                          --
-------------------------------------------------------------------------------

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	return (rsubn(term, foo, bar))
end

local function links(text, face, id)
	if text == "" or text == "?" or text == "&mdash;" or text == "—" then --mdash
		return text
	else
		return m_links.full_link({lang = lang, term = text, tr = "-", id = id}, face)
	end
end

local function tag_text(text, tag, class)
	return m_links.full_link({lang = lang, alt = text, tr = "-"})
end

local function track(page)
	require("Module:debug/track")("ar-verb/" .. page)
	return true
end

local function reorder_shadda(word)
	-- shadda+short-vowel (including tanwīn vowels, i.e. -an -in -un) gets
	-- replaced with short-vowel+shadda during NFC normalisation, which
	-- MediaWiki does for all Unicode strings; however, it makes various
	-- processes inconvenient, so undo it.
	word = rsub(word, "(" .. DIACRITIC_ANY_BUT_SH .. ")" .. SH, SH .. "%1")
	return word
end

-- synthesize a frame so that exported functions meant to be called from
-- templates can be called from the debug console.
local function debug_frame(parargs, args)
	return {args = args, getParent = function() return {args = parargs} end}
end

-------------------------------------------------------------------------------
--                      Properties of different verbal forms                 --
-------------------------------------------------------------------------------

-- no longer supported
--local numeric_to_roman_form = {
--	["1"] = "I", ["2"] = "II", ["3"] = "III", ["4"] = "IV", ["5"] = "V",
--	["6"] = "VI", ["7"] = "VII", ["8"] = "VIII", ["9"] = "IX", ["10"] = "X",
--	["11"] = "XI", ["12"] = "XII", ["13"] = "XIII", ["14"] = "XIV", ["15"] = "XV",
--	["1q"] = "Iq", ["2q"] = "IIq", ["3q"] = "IIIq", ["4q"] = "IVq"
--}
--
---- convert numeric form to roman-numeral form
--local function canonicalize_form(form)
--	return numeric_to_roman_form[form] or form
--end

local allowed_forms = {"I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX",
	"X", "XI", "XII", "XIII", "XIV", "XV", "Iq", "IIq", "IIIq", "IVq"}

local function form_supports_final_weak(form)
	return form ~= "XI" and form ~= "XV" and form ~= "IVq"
end

local function form_supports_geminate(form)
	return form == "I" or form == "III" or form == "IV" or
		form == "VI" or form == "VII" or form == "VIII" or form == "X"
end

local function form_supports_hollow(form)
	return form == "I" or form == "IV" or form == "VII" or form == "VIII" or
		form == "X"
end

local function form_probably_impersonal_passive(form)
	return form == "VI"
end

local function form_probably_no_passive(form, weakness, past_vowel, nonpast_vowel)
	return form == "I" and weakness ~= "hollow" and m_table.contains(past_vowel, "u") or
		form == "VII" or form == "IX" or form == "XI" or form == "XII" or
		form == "XIII" or form == "XIV" or form == "XV" or form == "IIq" or
		form == "IIIq" or form == "IVq"
end

local function form_is_quadriliteral(form)
	return form == "Iq" or form == "IIq" or form == "IIIq" or form == "IVq"
end

-- Active forms II, III, IV, Iq use non-past prefixes in -u- instead of -a-.
local function prefix_vowel_from_form(form)
	if form == "II" or form == "III" or form == "IV" or form == "Iq" then
		return "u"
	else
		return "a"
	end
end

-- true if the active non-past takes a-vowelling rather than i-vowelling
-- in its last syllable
local function form_nonpast_a_vowel(form)
	return form == "V" or form == "VI" or form == "XV" or form == "IIq"
end

-------------------------------------------------------------------------------
--              Radicals associated with various irregular verbs             --
-------------------------------------------------------------------------------

-- Form-I verb أخذ or form-VIII verb اتخذ
local function axadh_radicals(rad1, rad2, rad3)
	return rad1 == HAMZA and rad2 == "خ" and rad3 == "ذ"
end

-- Form-I verb whose imperative has a reduced form: أكل and أخذ and أمر
local function reduced_imperative_verb(rad1, rad2, rad3)
	return axadh_radicals(rad1, rad2, rad3) or rad1 == HAMZA and (
		rad2 == "ك" and rad3 == "ل" or
		rad2 == "م" and rad3 == "ر")
end

-- Form-I verb رأى and form-IV verb أرى
local function raa_radicals(rad1, rad2, rad3)
	return rad1 == "ر" and rad2 == HAMZA and rad3 == Y
end

-- Form-I verb سأل
local function saal_radicals(rad1, rad2, rad3)
	return rad1 == "س" and rad2 == HAMZA and rad3 == "ل"
end

-- Form-I verb حيّ or حيي and form-X verb استحيا or استحى
local function hayy_radicals(rad1, rad2, rad3)
	return rad1 == "ح" and rad2 == Y and rad3 == Y
end

-------------------------------------------------------------------------------
--                               Sets of past endings                        --
-------------------------------------------------------------------------------

-- the 13 endings of the sound/hollow/geminate past tense
local past_endings = {
	-- singular
	SK .. "تُ", SK .. "تَ", SK .. "تِ", A, A .. "تْ",
	--dual
	SK .. "تُمَا", AA, A .. "تَا",
	-- plural
	SK .. "نَا", SK .. "تُمْ",
	-- two Arabic diacritics don't work together in Wikimedia
	--SK .. "تُنَّ",
	SK .. "تُن" .. SH .. A, UU .. ALIF, SK .. "نَ"
}

-- make endings for final-weak past in -aytu or -awtu. AYAW is AY or AW
-- as appropriate. Note that AA and AW are global variables.
local function make_past_endings_ay_aw(ayaw, third_sg_masc)
	return {
	-- singular
	ayaw .. SK .. "تُ", ayaw ..  SK .. "تَ", ayaw .. SK .. "تِ",
	third_sg_masc, A .. "تْ",
	--dual
	ayaw .. SK .. "تُمَا", ayaw .. AA, A .. "تَا",
	-- plural
	ayaw .. SK .. "نَا", ayaw .. SK .. "تُمْ",
	-- two Arabic diacritics don't work together in Wikimedia
	--ayaw .. SK .. "تُنَّ",
	ayaw .. SK .. "تُن" .. SH .. A, AW .. SK .. ALIF, ayaw .. SK .. "نَ"
	}
end

-- past final-weak -aytu endings
local past_endings_ay = make_past_endings_ay_aw(AY, AAMAQ)
-- past final-weak -awtu endings
local past_endings_aw = make_past_endings_ay_aw(AW, AA)

-- Make endings for final-weak past in -ītu or -ūtu. IIUU is ī or ū as
-- appropriate. Note that AA and UU are global variables.
local function make_past_endings_ii_uu(iiuu)
	return {
	-- singular
	iiuu .. "تُ", iiuu .. "تَ", iiuu .. "تِ", iiuu .. A, iiuu .. A .. "تْ",
	--dual
	iiuu .. "تُمَا", iiuu .. AA, iiuu .. A .. "تَا",
	-- plural
	iiuu .. "نَا", iiuu .. "تُمْ",
	-- two Arabic diacritics don't work together in Wikimedia
	--iiuu .. "تُنَّ",
	iiuu .. "تُن" .. SH .. A, UU .. ALIF, iiuu .. "نَ"
	}
end

-- past final-weak -ītu endings
local past_endings_ii = make_past_endings_ii_uu(II)
-- past final-weak -ūtu endings
local past_endings_uu = make_past_endings_ii_uu(UU)

-------------------------------------------------------------------------------
--                    Sets of non-past prefixes and endings                  --
-------------------------------------------------------------------------------

-- prefixes for non-past forms in -a-
local nonpast_prefixes_a = {
	-- singular
	HAMZA .. A, "تَ", "تَ", "يَ", "تَ",
	--dual
	"تَ", "يَ", "تَ",
	-- plural
	"نَ", "تَ", "تَ", "يَ", "يَ"
}

-- prefixes for non-past forms in -u- (passive; active forms II, III, IV, Iq)
local nonpast_prefixes_u = {
	-- singular
	HAMZA .. U, "تُ", "تُ", "يُ", "تُ",
	--dual
	"تُ", "يُ", "تُ",
	-- plural
	"نُ", "تُ", "تُ", "يُ", "يُ"
}

-- There are only five distinct endings in all non-past verbs. Make any set of
-- non-past endings given these five distinct endings.
local function make_nonpast_endings(null, fem, dual, pl, fempl)
	return {
	-- singular
	null, null, fem, null, null,
	-- dual
	dual, dual, dual,
	-- plural
	null, pl, fempl, pl, fempl
	}
end

-- endings for non-past indicative
local indic_endings = make_nonpast_endings(
	U,
	II .. NA,
	AANI,
	UU .. NA,
	SK .. NA
)

-- make the endings for non-past subjunctive/jussive, given the vowel diacritic
-- used in "null" endings (1s/2sm/3sm/3sf/1p)
local function make_subj_juss_endings(dia_null)
	return make_nonpast_endings(
	dia_null,
	II,
	AA,
	UU .. ALIF,
	SK .. NA
	)
end

-- endings for non-past subjunctive
local subj_endings = make_subj_juss_endings(A)

-- endings for non-past jussive
local juss_endings = make_subj_juss_endings(SK)

-- endings for alternative geminate non-past jussive in -a; same as subjunctive
local juss_endings_alt_a = subj_endings

-- endings for alternative geminate non-past jussive in -i
local juss_endings_alt_i = make_subj_juss_endings(I)

-- endings for final-weak non-past indicative in -ā. Note that AY, AW and
-- AAMAQ are global variables.
local indic_endings_aa = make_nonpast_endings(
	AAMAQ,
	AYSK .. NA,
	AY .. AANI,
	AWSK .. NA,
	AYSK .. NA
)

-- make endings for final-weak non-past indicative in -ī or -ū; IIUU is
-- ī or ū as appropriate. Note that II and UU are global variables.
local function make_indic_endings_ii_uu(iiuu)
	return make_nonpast_endings(
	iiuu,
	II .. NA,
	iiuu .. AANI,
	UU .. NA,
	iiuu .. NA
	)
end

-- endings for final-weak non-past indicative in -ī
local indic_endings_ii = make_indic_endings_ii_uu(II)

-- endings for final-weak non-past indicative in -ū
local indic_endings_uu = make_indic_endings_ii_uu(UU)

-- endings for final-weak non-past subjunctive in -ā. Note that AY, AW, ALIF,
-- AAMAQ are global variables.
local subj_endings_aa = make_nonpast_endings(
	AAMAQ,
	AYSK,
	AY .. AA,
	AWSK .. ALIF,
	AYSK .. NA
)

-- make endings for final-weak non-past subjunctive in -ī or -ū. IIUU is
-- ī or ū as appropriate. Note that AA, II, UU, ALIF are global variables.
local function make_subj_endings_ii_uu(iiuu)
	return make_nonpast_endings(
	iiuu .. A,
	II,
	iiuu .. AA,
	UU .. ALIF,
	iiuu .. NA
	)
end

-- endings for final-weak non-past subjunctive in -ī
local subj_endings_ii = make_subj_endings_ii_uu(II)

-- endings for final-weak non-past subjunctive in -ū
local subj_endings_uu = make_subj_endings_ii_uu(UU)

-- endings for final-weak non-past jussive in -ā
local juss_endings_aa = make_nonpast_endings(
	A,
	AYSK,
	AY .. AA,
	AWSK .. ALIF,
	AYSK .. NA
)

-- Make endings for final-weak non-past jussive in -ī or -ū. IU is short i or u,
-- IIUU is long ī or ū as appropriate. Note that AA, II, UU, ALIF are global
-- variables.
local function make_juss_endings_ii_uu(iu, iiuu)
	return make_nonpast_endings(
	iu,
	II,
	iiuu .. AA,
	UU .. ALIF,
	iiuu .. NA
	)
end

-- endings for final-weak non-past jussive in -ī
local juss_endings_ii = make_juss_endings_ii_uu(I, II)

-- endings for final-weak non-past jussive in -ū
local juss_endings_uu = make_juss_endings_ii_uu(U, UU)

-------------------------------------------------------------------------------
--                           Sets of imperative endings                      --
-------------------------------------------------------------------------------

-- extract the second person jussive endings to get corresponding imperative
-- endings
local function imperative_endings_from_jussive(endings)
	return {endings[2], endings[3], endings[6], endings[10], endings[11]}
end

-- normal imperative endings
local impr_endings = imperative_endings_from_jussive(juss_endings)
-- alternative geminate imperative endings in -a
local impr_endings_alt_a = imperative_endings_from_jussive(juss_endings_alt_a)
-- alternative geminate imperative endings in -i
local impr_endings_alt_i = imperative_endings_from_jussive(juss_endings_alt_i)
-- final-weak imperative endings in -ā
local impr_endings_aa = imperative_endings_from_jussive(juss_endings_aa)
-- final-weak imperative endings in -ī
local impr_endings_ii = imperative_endings_from_jussive(juss_endings_ii)
-- final-weak imperative endings in -ū
local impr_endings_uu = imperative_endings_from_jussive(juss_endings_uu)

-------------------------------------------------------------------------------
--                        Properties of specific sounds                      --
-------------------------------------------------------------------------------

-- Check that the past or non-past vowel is a, i, or u. VOWEL is the vowel to
-- check and VTYPE indicates whether it's past or non-past and is used in
-- the error message.
local function check_aiu(vtype, vowel)
	if vowel ~= "a" and vowel ~= "i" and vowel ~= "u" then
		error(vtype .. " vowel '" .. vowel .. "' should be a, i, or u")
	end
end

-- Is radical wāw (و) or yāʾ (ي)?
local function is_waw_ya(rad)
	return rad == W or rad == Y
end

-- Check that radical is wāw (و) or yāʾ (ي), error if not
local function check_waw_ya(rad)
	if not is_waw_ya(rad) then
		error("Expecting weak radical: '" .. rad .. "' should be " .. W .. " or " .. Y)
	end
end

-- Is radical guttural? This favors a non-past vowel of "a"
local function is_guttural(rad)
	return rad == HAMZA or rad == "ه" or rad == "ع" or rad == "ح"
end

-------------------------------------------------------------------------------
--                        Basic functions to inflect tenses                  --
-------------------------------------------------------------------------------

-- Implementation of inflect_tense(). See that function. Also used directly
-- to add the imperative, which has only five parts.
local function inflect_tense_1(data, tense, prefixes, stems, endings, pnums)
	if prefixes == nil then
		error("For tense '" .. tense .. "', prefixes = nil")
	end
	if stems == nil then
		error("For tense '" .. tense .. "', stems = nil")
	end
	if endings == nil then
		error("For tense '" .. tense .. "', endings = nil")
	end
	if type(prefixes) == "table" and #pnums ~= #prefixes then
		error("For tense '" .. tense .. "', found " .. #prefixes .. " prefixes but expected " .. #pnums)
	end
	if type(stems) == "table" and #pnums ~= #stems then
		error("For tense '" .. tense .. "', found " .. #stems .. " stems but expected " .. #pnums)
	end
	if #pnums ~= #endings then
		error("For tense '" .. tense .. "', found " .. #endings .. " endings but expected " .. #pnums)
	end

	-- First, initialize any nil entries to sequences.
	for i, pnum in ipairs(pnums) do
		if data.forms[pnum .. "-" .. tense] == nil then
			data.forms[pnum .. "-" .. tense] = {}
		end
	end

	-- Now add entries
	for i = 1, #pnums do
		-- Extract endings for this person-number combo
		local ends = endings[i]
		if type(ends) == "string" then ends = {ends} end
		-- Extract prefix for this person-number combo
		local prefix = prefixes
		if type(prefix) == "table" then prefix = prefix[i] end
		-- Extract stem for this person-number combo
		local stem = stems
		if type(stem) == "table" then stem = stem[i] end
		-- Add entries for stem + endings
		for j, ending in ipairs(ends) do
			-- allow some inflections to be skipped; useful for generating
			-- partly irregular inflections
			if prefix ~= "-" and stem ~= "-" then
				local part = prefix .. stem .. ending
				if part ~= "" and part ~= "-" -- and (not data.impers or pnums[i] == "3sg")
						then
					table.insert(data.forms[pnums[i] .. "-" .. tense], part)
				end
			end
		end
	end
end

-- Add to DATA the inflections for the tense indicated by TENSE (the suffix
-- in the forms names, e.g. 'perf'), formed by combining the PREFIXES
-- (either a single string or a sequence of 13 strings), STEMS
-- (either a single string or a sequence of 13 strings) with the
-- ENDINGS (a sequence of 13 values, each of which is either a string
-- or a sequence of one or more possible endings). If existing
-- inflections already exist, they will be added to, not overridden.
-- If any value of PREFIXES or STEMS is the string "-", then the corresponding
-- inflection will be skipped.
local function inflect_tense(data, tense, prefixes, stems, endings)
	local pnums = {"1s", "2sm", "2sf", "3sm", "3sf",
				   "2d", "3dm", "3df",
				   "1p", "2pm", "2pf", "3pm", "3pf"}
	inflect_tense_1(data, tense, prefixes, stems, endings, pnums)
end

-- Like inflect_tense() but for the imperative, which has only five parts
-- instead of 13.
local function inflect_tense_impr(data, stems, endings)
	local pnums = {"2sm", "2sf", "2d", "2pm", "2pf"}
	if data.noimp then
		endings = {{}, {}, {}, {}, {}}
	end
	inflect_tense_1(data, "impr", "", stems, endings, pnums)
end

-- Add VALUE (a string or array) to the end of any entries in DATA.forms[NAME],
-- initializing it to an empty array if needed.
local function insert_part(data, name, value)
	if data.forms[name] == nil then
		data.forms[name] = {}
	end
	
	if type(value) == "table" then
		data.forms[name] = value
	else
		table.insert(data.forms[name], value)
	end
end

-- Insert verbal noun VN into DATA.forms["vn"], but allow it to be overridden by
-- ARGS["vn"].
local function insert_verbal_noun(data, args, vn)
	local vns = args["vn"] and rsplit(args["vn"], "[,،]") or vn
	if type(vns) ~= "table" then
		vns = {vns}
	end
	
	vns.ids = {}
	
	for i = 1, #vns do
		local id = args["vn-id" .. i]
		
		if id then
			vns.ids[i] = id
		end
	end

	-------------------- Begin verbal-noun i3rab tracking code ---------------
	-- Examples of what you can find by looking at what links to the given
	-- pages:
	--
	-- Template:tracking/ar-verb/vn/i3rab/un (pages with verbal nouns with -un
	--   i3rab, whether explicitly specified, i.e. using vn=, or auto-generated,
	--   as is normal for augmented forms)
	-- Template:tracking/ar-verb/explicit-vn/i3rab/u (pages with explicitly
	--   specified verbal nouns with -u i3rab)
	-- Template:tracking/ar-verb/explicit-vn/i3rab/an-tall (pages with
	--   explicitly specified verbal nouns with tall-alif -an i3rab)
	-- Template:tracking/ar-verb/auto-vn/i3rab (pages with auto-generated verbal
	--   nouns with any sort of i3rab)
	-- Template:tracking/ar-verb/vn/no-i3rab (pages with verbal nouns without
	--   i3rab)
	-- Template:tracking/ar-verb/vn/would-be-decl/di (pages with verbal nouns
	--   that would be detected as diptote without explicit i3rab)
	function vntrack(pagesuff)
		track("vn/" .. pagesuff)
		if args["vn"] then
			track("explicit-vn/" .. pagesuff)
		else
			track("auto-vn/" .. pagesuff)
		end
	end

	function track_i3rab(entry, arabic, tr)
		if rfind(entry, arabic .. "$") then
			vntrack("i3rab")
			vntrack("i3rab/" .. tr)
		end
	end

	for _, entry in ipairs(vns) do
		-- Need to do this else we will have problems with VN's whose stem ends
		-- in shadda.
		entry = reorder_shadda(entry)
		track_i3rab(entry, UN, "un")
		track_i3rab(entry, U, "u")
		track_i3rab(entry, IN, "in")
		track_i3rab(entry, I, "i")
		track_i3rab(entry, AN .. "[" .. ALIF .. AMAQ .. "]", "an")
		track_i3rab(entry, AN .. ALIF, "an-tall")
		track_i3rab(entry, A, "a")
		track_i3rab(entry, SK, "sk")
		if not rfind(entry, "[" .. A .. I .. U .. AN .. IN .. UN .. DAGGER_ALIF .. "]$") and
				not rfind(entry, AN .. "[" .. ALIF .. AMAQ .. "]") then
			vntrack("no-i3rab")
		end
		entry = rsub(entry, UNU .. "?$", "")
		-- Figure out what the decltype would be without any explicit -un
		-- or -u added, to see whether there are any nouns that would be
		-- detected as diptotes, e.g. of the فَعْلَان pattern.
		local decltype = ar_nominals.detect_type(entry, false, "sg", "noun")
		vntrack("would-be-decl/" .. decltype)
	end
	-------------------- End verbal-noun i3rab tracking code ---------------

	if no_nominal_i3rab then
		vns_no_i3rab = {}
		for _, entry in ipairs(vns) do
			entry = reorder_shadda(entry)
			entry = rsub(entry, UNU .. "?$", "")
			table.insert(vns_no_i3rab, entry)
		end
		if vns.ids then
			vns_no_i3rab.ids = vns.ids
		end
		insert_part(data, "vn", vns_no_i3rab)
	else
		insert_part(data, "vn", vns)
	end
end

-------------------------------------------------------------------------------
--                      Functions to inflect the past tense                  --
-------------------------------------------------------------------------------

--generate past verbs using specified vowel and consonant stems; works for
--sound, assimilated, hollow, and geminate verbs, active and passive
local function past_2stem_conj(data, tense, v_stem, c_stem)
	inflect_tense(data, tense, "", {
		-- singular
		c_stem, c_stem, c_stem, v_stem, v_stem,
		--dual
		c_stem, v_stem, v_stem,
		-- plural
		c_stem, c_stem, c_stem, v_stem, c_stem
	}, past_endings)
end

--generate past verbs using single specified stem; works for sound and
--assimilated verbs, active and passive
local function past_1stem_conj(data, tense, stem)
	past_2stem_conj(data, tense, stem, stem)
end

-------------------------------------------------------------------------------
--                     Functions to inflect non-past tenses                  --
-------------------------------------------------------------------------------

-- Generate non-past conjugation, with two stems, for vowel-initial and
-- consonant-initial endings, respectively. Useful for active and passive;
-- for all forms; for all weaknesses (sound, assimilated, hollow, final-weak
-- and geminate) and for all types of non-past (indicative, subjunctive,
-- jussive) except for the imperative. (There is a separate function below
-- for geminate jussives because they have three alternants.) Both stems may
-- be the same, e.g. for sound verbs.
--
-- PREFIXES will generally be either "a" (= 'nonpast_prefixes_a', for active
-- forms I and V - X) or "u" (= 'nonpast_prefixes_u', for active forms II - IV
-- and Iq and all passive forms). Otherwise, it should be either a single string
-- (often "") or an array (table) of 13 items. ENDINGS should similarly be an
-- array of 13 items. If ENDINGS is nil or omitted, infer the endings from
-- the tense. If JUSSIVE is true, or ENDINGS is nil and TENSE indicatives
-- jussive, use the jussive pattern of vowel/consonant stems (different from the
-- normal ones).
local function nonpast_2stem_conj(data, tense, prefixes, v_stem, c_stem, endings, jussive)
	if prefixes == "a" then prefixes = nonpast_prefixes_a
	elseif prefixes == "u" then prefixes = nonpast_prefixes_u
	end
	if endings == nil then
		if tense == "impf" or tense == "ps-impf" then
			endings = indic_endings
		elseif tense == "subj" or tense == "ps-subj" then
			endings = subj_endings
		elseif tense == "juss" or tense == "ps-juss" then
			jussive = true
			endings = juss_endings
		else
			error("Unrecognized tense '" .. tense .."'")
		end
	end
	if not jussive then
		inflect_tense(data, tense, prefixes, {
			-- singular
			v_stem, v_stem, v_stem, v_stem, v_stem,
			--dual
			v_stem, v_stem, v_stem,
			-- plural
			v_stem, v_stem, c_stem, v_stem, c_stem
		}, endings)
	else
		inflect_tense(data, tense, prefixes, {
			-- singular
			-- 'adlul, tadlul, tadullī, yadlul, tadlul
			c_stem, c_stem, v_stem, c_stem, c_stem,
			--dual
			-- tadullā, yadullā, tadullā
			v_stem, v_stem, v_stem,
			-- plural
			-- nadlul, tadullū, tadlulna, yadullū, yadlulna
			c_stem, v_stem, c_stem, v_stem, c_stem
		}, endings)
	end
end

-- Generate non-past conjugation with one stem (no distinct stems for
-- vowel-initial and consonant-initial endings). See nonpast_2stem_conj().
local function nonpast_1stem_conj(data, tense, prefixes, stem, endings, jussive)
	nonpast_2stem_conj(data, tense, prefixes, stem, stem, endings, jussive)
end

-- Generate active/passive jussive geminative. There are three alternants, two
-- with terminations -a and -i and one in a null termination with a distinct
-- pattern of vowel/consonant stem usage. See nonpast_2stem_conj() for a
-- description of the arguments.
local function jussive_gem_conj(data, tense, prefixes, v_stem, c_stem)
	-- alternative in -a
	nonpast_2stem_conj(data, tense, prefixes, v_stem, c_stem, juss_endings_alt_a)
	-- alternative in -i
	nonpast_2stem_conj(data, tense, prefixes, v_stem, c_stem, juss_endings_alt_i)
	-- alternative in -null; requires different combination of v_stem and
	-- c_stem since the null endings require the c_stem (e.g. "tadlul" here)
	-- whereas the corresponding endings above in -a or -i require the v_stem
	-- (e.g. "tadulla, tadulli" above)
	nonpast_2stem_conj(data, tense, prefixes, v_stem, c_stem, juss_endings, "jussive")
end

-------------------------------------------------------------------------------
--                    Functions to inflect the imperative                    --
-------------------------------------------------------------------------------

-- generate imperative parts for sound or assimilated verbs
local function make_1stem_imperative(data, stem)
	inflect_tense_impr(data, stem, impr_endings)
end

-- generate imperative parts for two-stem verbs (hollow or geminate)
local function make_2stem_imperative(data, v_stem, c_stem)
	inflect_tense_impr(data,
		{c_stem, v_stem, v_stem, v_stem, c_stem}, impr_endings)
end

-- generate imperative parts for geminate verbs form I (also IV, VII, VIII, X)
local function make_gem_imperative(data, v_stem, c_stem)
	inflect_tense_impr(data,
		{v_stem, v_stem, v_stem, v_stem, c_stem}, impr_endings_alt_a)
	inflect_tense_impr(data,
		{v_stem, v_stem, v_stem, v_stem, c_stem}, impr_endings_alt_i)
	make_2stem_imperative(data, v_stem, c_stem)
end

-------------------------------------------------------------------------------
--                    Functions to inflect entire verbs                      --
-------------------------------------------------------------------------------

-- generate finite parts of a sound verb (also works for assimilated verbs)
-- from five stems (past and non-past, active and passive, plus imperative)
-- plus the prefix vowel in the active non-past ("a" or "u")
local function make_sound_verb(data, past_stem, ps_past_stem, nonpast_stem,
		ps_nonpast_stem, imper_stem, prefix_vowel)
	past_1stem_conj(data, "perf", past_stem)
	past_1stem_conj(data, "ps-perf", ps_past_stem)
	nonpast_1stem_conj(data, "impf", prefix_vowel, nonpast_stem)
	nonpast_1stem_conj(data, "subj", prefix_vowel, nonpast_stem)
	nonpast_1stem_conj(data, "juss", prefix_vowel, nonpast_stem)
	nonpast_1stem_conj(data, "ps-impf", "u", ps_nonpast_stem)
	nonpast_1stem_conj(data, "ps-subj", "u", ps_nonpast_stem)
	nonpast_1stem_conj(data, "ps-juss", "u", ps_nonpast_stem)
	make_1stem_imperative(data, imper_stem)
end

-- generate finite parts of a final-weak verb from five stems (past and
-- non-past, active and passive, plus imperative), five sets of
-- suffixes (past, non-past indicative/subjunctive/jussive, imperative)
-- and the prefix vowel in the active non-past ("a" or "u")
local function make_final_weak_verb(data, past_stem, ps_past_stem, nonpast_stem,
		ps_nonpast_stem, imper_stem, past_suffs, indic_suffs,
		subj_suffs, juss_suffs, impr_suffs, prefix_vowel)
	inflect_tense(data, "perf", "", past_stem, past_suffs)
	inflect_tense(data, "ps-perf", "", ps_past_stem, past_endings_ii)
	nonpast_1stem_conj(data, "impf", prefix_vowel, nonpast_stem, indic_suffs)
	nonpast_1stem_conj(data, "subj", prefix_vowel, nonpast_stem, subj_suffs)
	nonpast_1stem_conj(data, "juss", prefix_vowel, nonpast_stem, juss_suffs)
	nonpast_1stem_conj(data, "ps-impf", "u", ps_nonpast_stem, indic_endings_aa)
	nonpast_1stem_conj(data, "ps-subj", "u", ps_nonpast_stem, subj_endings_aa)
	nonpast_1stem_conj(data, "ps-juss", "u", ps_nonpast_stem, juss_endings_aa)
	inflect_tense_impr(data, imper_stem, impr_suffs)
end

-- generate finite parts of an augmented (form II+) final-weak verb from five
-- stems (past and non-past, active and passive, plus imperative) plus the
-- prefix vowel in the active non-past ("a" or "u") and a flag indicating if
-- behave like a form V/VI verb in taking non-past endings in -ā instead of -ī
local function make_augmented_final_weak_verb(data, past_stem, ps_past_stem,
		nonpast_stem, ps_nonpast_stem, imper_stem, prefix_vowel, form56)
	make_final_weak_verb(data, past_stem, ps_past_stem, nonpast_stem,
		ps_nonpast_stem, imper_stem, past_endings_ay,
		form56 and indic_endings_aa or indic_endings_ii,
		form56 and subj_endings_aa or subj_endings_ii,
		form56 and juss_endings_aa or juss_endings_ii,
		form56 and impr_endings_aa or impr_endings_ii,
		prefix_vowel)
end

-- generate finite parts of an augmented (form II+) sound or final-weak verb,
-- given the following:
--
-- DATA, ARGS = arguments from conjugation function
-- RAD3 = last radical; should be nil for final-weak verb
-- PAST_STEM_BASE = active past stem minus last syllable (= -al or -ā)
-- NONPAST_STEM_BASE = non-past stem minus last syllable (= -al/-il or -ā/-ī)
-- PS_PAST_STEM_BASE = passive past stem minus last syllable (= -il or -ī)
-- FORM -- form of verb (II to XV, Iq - IVq)
-- VN = verbal noun
local function make_augmented_sound_final_weak_verb(data, args, rad3,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, form)

	insert_verbal_noun(data, args, vn)

	local final_weak = rad3 == nil
	local prefix_vowel = prefix_vowel_from_form(form)
	local form56 = form_nonpast_a_vowel(form)
	local a_base_suffix = final_weak and "" or A .. rad3
	local i_base_suffix = final_weak and "" or I .. rad3

	-- past and non-past stems, active and passive
	local past_stem = past_stem_base .. a_base_suffix
	-- In forms 5 and 6, non-past has /a/ as last stem vowel in the non-past
	-- in both active and passive, but /i/ in the active participle and /a/
	-- in the passive participle. Elsewhere, consistent /i/ in active non-past
	-- and participle, consistent /a/ in passive non-past and participle.
	-- Hence, forms 5 and 6 differ only in the non-past active (but not
	-- active participle), so we have to split the finite non-past stem and
	-- active participle stem.
	local nonpast_stem = nonpast_stem_base ..
		(form56 and a_base_suffix or i_base_suffix)
	local ap_stem = nonpast_stem_base .. i_base_suffix
	local ps_past_stem = ps_past_stem_base .. i_base_suffix
	local ps_nonpast_stem = nonpast_stem_base .. a_base_suffix
	-- imperative stem
	local imper_stem = past_stem_base ..
		(form56 and a_base_suffix or i_base_suffix)

	-- make parts
	if final_weak then
		make_augmented_final_weak_verb(data, past_stem, ps_past_stem, nonpast_stem,
			ps_nonpast_stem, imper_stem, prefix_vowel, form56)
	else
		make_sound_verb(data, past_stem, ps_past_stem, nonpast_stem,
			ps_nonpast_stem, imper_stem, prefix_vowel)
	end

	-- active and passive participle
	if final_weak then
		insert_part(data, "ap", MU .. ap_stem .. IN)
		insert_part(data, "pp", MU .. ps_nonpast_stem .. AN .. AMAQ)
	else
		insert_part(data, "ap", MU .. ap_stem .. UNS)
		insert_part(data, "pp", MU .. ps_nonpast_stem .. UNS)
	end
end

-- generate finite parts of a hollow or geminate verb from ten stems (vowel and
-- consonant stems for each of past and non-past, active and passive, plus
-- imperative) plus the prefix vowel in the active non-past ("a" or "u"), plus
-- a flag indicating if we are a geminate verb
local function make_hollow_geminate_verb(data, past_v_stem, past_c_stem, ps_past_v_stem,
	ps_past_c_stem, nonpast_v_stem, nonpast_c_stem, ps_nonpast_v_stem,
	ps_nonpast_c_stem, imper_v_stem, imper_c_stem, prefix_vowel, geminate)
	past_2stem_conj(data, "perf", past_v_stem, past_c_stem)
	past_2stem_conj(data, "ps-perf", ps_past_v_stem, ps_past_c_stem)
	nonpast_2stem_conj(data, "impf", prefix_vowel, nonpast_v_stem, nonpast_c_stem)
	nonpast_2stem_conj(data, "subj", prefix_vowel, nonpast_v_stem, nonpast_c_stem)
	nonpast_2stem_conj(data, "ps-impf", "u", ps_nonpast_v_stem, ps_nonpast_c_stem)
	nonpast_2stem_conj(data, "ps-subj", "u", ps_nonpast_v_stem, ps_nonpast_c_stem)
	if geminate then
		jussive_gem_conj(data, "juss", prefix_vowel, nonpast_v_stem, nonpast_c_stem)
		jussive_gem_conj(data, "ps-juss", "u", ps_nonpast_v_stem, ps_nonpast_c_stem)
		make_gem_imperative(data, imper_v_stem, imper_c_stem)
	else
		nonpast_2stem_conj(data, "juss", prefix_vowel, nonpast_v_stem, nonpast_c_stem)
		nonpast_2stem_conj(data, "ps-juss", "u", ps_nonpast_v_stem, ps_nonpast_c_stem)
		make_2stem_imperative(data, imper_v_stem, imper_c_stem)
	end
end

-- generate finite parts of an augmented (form II+) hollow verb,
-- given the following:
--
-- DATA, ARGS = arguments from conjugation function
-- RAD3 = last radical (after the hollowness)
-- PAST_STEM_BASE = invariable part of active past stem
-- NONPAST_STEM_BASE = invariable part of non-past stem
-- PS_PAST_STEM_BASE = invariable part of passive past stem
-- VN = verbal noun
-- FORM = the verb form ("IV", "VII", "VIII", "X")
local function make_augmented_hollow_verb(data, args, rad3,
	past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, form)
	insert_verbal_noun(data, args, vn)

	local form410 = form == "IV" or form == "X"
	local prefix_vowel = prefix_vowel_from_form(form)

	local a_base_suffix_v, a_base_suffix_c
	local i_base_suffix_v, i_base_suffix_c

	a_base_suffix_v = AA .. rad3         -- 'af-āl-a, inf-āl-a
	a_base_suffix_c = A .. rad3      -- 'af-al-tu, inf-al-tu
	i_base_suffix_v = II .. rad3         -- 'uf-īl-a, unf-īl-a
	i_base_suffix_c = I .. rad3      -- 'uf-il-tu, unf-il-tu

	-- past and non-past stems, active and passive, for vowel-initial and
	-- consonant-initial endings
	local past_v_stem = past_stem_base .. a_base_suffix_v
	local past_c_stem = past_stem_base .. a_base_suffix_c
	-- yu-f-īl-u, ya-staf-īl-u but yanf-āl-u, yaft-āl-u
	local nonpast_v_stem = nonpast_stem_base ..
		(form410 and i_base_suffix_v or a_base_suffix_v)
	local nonpast_c_stem = nonpast_stem_base ..
		(form410 and i_base_suffix_c or a_base_suffix_c)
	local ps_past_v_stem = ps_past_stem_base .. i_base_suffix_v
	local ps_past_c_stem = ps_past_stem_base .. i_base_suffix_c
	local ps_nonpast_v_stem = nonpast_stem_base .. a_base_suffix_v
	local ps_nonpast_c_stem = nonpast_stem_base .. a_base_suffix_c

	-- imperative stem
	local imper_v_stem = past_stem_base ..
		(form410 and i_base_suffix_v or a_base_suffix_v)
	local imper_c_stem = past_stem_base ..
		(form410 and i_base_suffix_c or a_base_suffix_c)

	-- make parts
	make_hollow_geminate_verb(data, past_v_stem, past_c_stem, ps_past_v_stem,
		ps_past_c_stem, nonpast_v_stem, nonpast_c_stem, ps_nonpast_v_stem,
		ps_nonpast_c_stem, imper_v_stem, imper_c_stem, prefix_vowel, false)

	-- active participle
	insert_part(data, "ap", MU .. nonpast_v_stem .. UNS)
	-- passive participle
	insert_part(data, "pp", MU .. ps_nonpast_v_stem .. UNS)
end

-- generate finite parts of an augmented (form II+) geminate verb,
-- given the following:
--
-- DATA, ARGS = arguments from conjugation function
-- RAD3 = last radical (the one that gets geminated)
-- PAST_STEM_BASE = invariable part of active past stem; this and the stem
--   bases below will end with a consonant for forms IV, X, IVq, and a
--   short vowel for the others
-- NONPAST_STEM_BASE = invariable part of non-past stem
-- PS_PAST_STEM_BASE = invariable part of passive past stem
-- VN = verbal noun
-- FORM = the verb form ("III", "IV", "VI", "VII", "VIII", "IX", "X", "IVq")
local function make_augmented_geminate_verb(data, args, rad3,
	past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, form)
	insert_verbal_noun(data, args, vn)

	local prefix_vowel = prefix_vowel_from_form(form)

	local a_base_suffix_v, a_base_suffix_c
	local i_base_suffix_v, i_base_suffix_c

	if form == "IV" or form == "X" or form == "IVq" then
		a_base_suffix_v = A .. rad3 .. SH         -- 'af-all
		a_base_suffix_c = SK .. rad3 .. A .. rad3  -- 'af-lal
		i_base_suffix_v = I .. rad3 .. SH         -- yuf-ill
		i_base_suffix_c = SK .. rad3 .. I .. rad3  -- yuf-lil
	else
		a_base_suffix_v = rad3 .. SH         -- fā-ll, infa-ll
		a_base_suffix_c = rad3 .. A .. rad3  -- fā-lal, infa-lal
		i_base_suffix_v = rad3 .. SH         -- yufā-ll, yanfa-ll
		i_base_suffix_c = rad3 .. I .. rad3  -- yufā-lil, yanfa-lil
	end

	-- past and non-past stems, active and passive, for vowel-initial and
	-- consonant-initial endings
	local past_v_stem = past_stem_base .. a_base_suffix_v
	local past_c_stem = past_stem_base .. a_base_suffix_c
	local nonpast_v_stem = nonpast_stem_base ..
		(form_nonpast_a_vowel(form) and a_base_suffix_v or i_base_suffix_v)
	local nonpast_c_stem = nonpast_stem_base ..
		(form_nonpast_a_vowel(form) and a_base_suffix_c or i_base_suffix_c)
	-- form III and VI passive past do not have contracted parts, only
	-- uncontracted parts, which are added separately by those functions
	local ps_past_v_stem = (form == "III" or form == "VI") and "-" or
		ps_past_stem_base .. i_base_suffix_v
	local ps_past_c_stem = ps_past_stem_base .. i_base_suffix_c
	local ps_nonpast_v_stem = nonpast_stem_base .. a_base_suffix_v
	local ps_nonpast_c_stem = nonpast_stem_base .. a_base_suffix_c

	-- imperative stem
	local imper_v_stem = past_stem_base ..
		(form_nonpast_a_vowel(form) and a_base_suffix_v or i_base_suffix_v)
	local imper_c_stem = past_stem_base ..
		(form_nonpast_a_vowel(form) and a_base_suffix_c or i_base_suffix_c)

	-- make parts
	make_hollow_geminate_verb(data, past_v_stem, past_c_stem, ps_past_v_stem,
		ps_past_c_stem, nonpast_v_stem, nonpast_c_stem, ps_nonpast_v_stem,
		ps_nonpast_c_stem, imper_v_stem, imper_c_stem, prefix_vowel,
		"geminate")

	-- active participle
	insert_part(data, "ap", MU .. nonpast_v_stem .. UNS)
	-- passive participle
	insert_part(data, "pp", MU .. ps_nonpast_v_stem .. UNS)
end

-------------------------------------------------------------------------------
--            Conjugation functions for specific conjugation types           --
-------------------------------------------------------------------------------

-- Derive default non-past vowel from past vowel. Most common possibilities are
-- a/u, a/i, a/a if rad2 or rad3 are guttural, i/a, u/u. We choose a/u over a/i.
local function nonpast_from_past_vowel(past_vowel, rad2, rad3)
	return past_vowel == "i" and "a" or past_vowel == "u" and "u" or
		(is_guttural(rad2) or is_guttural(rad3)) and "a" or "u"
end

-- determine the imperative vowel based on non-past vowel
local function imper_vowel_from_nonpast(nonpast_vowel)
	if nonpast_vowel == "a" or nonpast_vowel == "i" then
		return "i"
	elseif nonpast_vowel == "u" then
		return "u"
	else
		error("Non-past vowel '" .. nonpast_vowel .. "' isn't a, i, or u, should have been caught earlier")
	end
end

-- Convert short vowel to equivalent long vowel (a -> alif, u -> wāw, i -> yāʾ).
local function short_to_long_vowel(vowel)
	if vowel == A then return ALIF
	elseif vowel == I then return Y
	elseif vowel == U then return W
	else
		error("Vowel '" .. vowel .. "' isn't a, i, or u, should have been caught earlier")
	end
end

-- Implement form-I sound or assimilated verb. ASSIMILATED is true for
-- assimilated verbs.
local function make_form_i_sound_assimilated_verb(data, args, rad1, rad2, rad3,
		past_vowel, nonpast_vowel, assimilated)
	-- need to provide two vowels - past and non-past
	past_vowel = past_vowel or "a"
	nonpast_vowel = nonpast_vowel or nonpast_from_past_vowel(past_vowel, rad2, rad3)
	check_aiu("past", past_vowel)
	check_aiu("non-past", nonpast_vowel)

	-- Verbal nouns (maṣādir) for form I are unpredictable and have to be supplied
	insert_verbal_noun(data, args, {})

	-- past and non-past stems, active and passive
	local past_stem = rad1 .. A .. rad2 .. dia[past_vowel] .. rad3
	local nonpast_stem = assimilated and rad2 .. dia[nonpast_vowel] .. rad3 or
		rad1 .. SK .. rad2 .. dia[nonpast_vowel] .. rad3
	local ps_past_stem = rad1 .. U .. rad2 .. I .. rad3
	local ps_nonpast_stem = rad1 .. SK .. rad2 .. A .. rad3

	-- determine the imperative vowel based on non-past vowel
	local imper_vowel = imper_vowel_from_nonpast(nonpast_vowel)

	-- imperative stem
	-- check for irregular verb with reduced imperative (أَخَذَ or أَكَلَ or أَمَرَ)
	local reducedimp = reduced_imperative_verb(rad1, rad2, rad3)
	if reducedimp then
		data.irregular = true
	end
	local imper_stem_suffix = rad2 .. dia[nonpast_vowel] .. rad3
	local imper_stem_base = (assimilated or reducedimp) and "" or
		ALIF .. dia[imper_vowel] ..
		(rad1 == HAMZA and short_to_long_vowel(dia[imper_vowel]) or rad1 .. SK)
	local imper_stem = imper_stem_base .. imper_stem_suffix

	-- make parts
	make_sound_verb(data, past_stem, ps_past_stem, nonpast_stem,
		ps_nonpast_stem, imper_stem, "a")

	-- Check for irregular verb سَأَلَ with alternative jussive and imperative.
	-- Calling this after make_sound_verb() adds additional entries to the
	-- paradigm parts.
	if saal_radicals(rad1, rad2, rad3) then
		data.irregular = true
		nonpast_1stem_conj(data, "juss", "a", "سَل")
		nonpast_1stem_conj(data, "ps-juss", "u", "سَل")
		make_1stem_imperative(data, "سَل")
	end

	-- active participle
	insert_part(data, "ap", rad1 .. AA .. rad2 .. I .. rad3 .. UNS)
	-- passive participle
	insert_part(data, "pp", MA .. rad1 .. SK .. rad2 .. U .. "و" .. rad3 .. UNS)
end

conjugations["I-sound"] = function(data, args, rad1, rad2, rad3,
		past_vowel, nonpast_vowel)
	make_form_i_sound_assimilated_verb(data, args, rad1, rad2, rad3,
		past_vowel, nonpast_vowel, false)
end

conjugations["I-assimilated"] = function(data, args, rad1, rad2, rad3,
		past_vowel, nonpast_vowel)
	make_form_i_sound_assimilated_verb(data, args, rad1, rad2, rad3,
		past_vowel, nonpast_vowel, "assimilated")
end

local function make_form_i_hayy_verb(data, args)
	-- Verbal nouns (maṣādir) for form I are unpredictable and have to be supplied
	insert_verbal_noun(data, args, {})

	data.irregular = true

	-- past and non-past stems, active and passive, and imperative stem
	local past_c_stem = "حَيِي"
	local past_v_stem_long = past_c_stem
	local past_v_stem_short = "حَيّ"
	local ps_past_c_stem = "حُيِي"
	local ps_past_v_stem_long = ps_past_c_stem
	local ps_past_v_stem_short = "حُيّ"

	local nonpast_stem = "حْي"
	local ps_nonpast_stem = nonpast_stem
	local imper_stem = "اِ" .. nonpast_stem

	-- make parts

	past_2stem_conj(data, "perf", "-", past_c_stem)
	past_2stem_conj(data, "ps-perf", "-", ps_past_c_stem)
	local variant = args["variant"]
	if variant == "short" or variant == "both" then
		past_2stem_conj(data, "perf", past_v_stem_short, "-")
		past_2stem_conj(data, "ps-perf", ps_past_v_stem_short, "-")
	end
	function inflect_long_variant(tense, long_stem, short_stem)
		inflect_tense_1(data, tense, "",
			{long_stem, long_stem, long_stem, long_stem, short_stem},
			{past_endings[4], past_endings[5], past_endings[7], past_endings[8],
			 past_endings[12]},
			{"3sm", "3sf", "3dm", "3df", "3pm"})
	end
	if variant == "long" or variant == "both" then
		inflect_long_variant("perf", past_v_stem_long, past_v_stem_short)
		inflect_long_variant("ps-perf", ps_past_v_stem_long, ps_past_v_stem_short)
	end

	nonpast_1stem_conj(data, "impf", "a", nonpast_stem, indic_endings_aa)
	nonpast_1stem_conj(data, "subj", "a", nonpast_stem, subj_endings_aa)
	nonpast_1stem_conj(data, "juss", "a", nonpast_stem, juss_endings_aa)
	nonpast_1stem_conj(data, "ps-impf", "u", ps_nonpast_stem, indic_endings_aa)
	nonpast_1stem_conj(data, "ps-subj", "u", ps_nonpast_stem, subj_endings_aa)
	nonpast_1stem_conj(data, "ps-juss", "u", ps_nonpast_stem, juss_endings_aa)
	inflect_tense_impr(data, imper_stem, impr_endings_aa)

	-- active participle apparently does not exist for this verb
	insert_part(data, "ap", {})
	-- passive participle apparently does not exist for this verb
	insert_part(data, "pp", {})
end

-- Implement form-I final-weak assimilated+final-weak verb. ASSIMILATED is true
-- for assimilated verbs.
local function make_form_i_final_weak_verb(data, args, rad1, rad2, rad3,
		past_vowel, nonpast_vowel, assimilated)

	-- حَيَّ or حَيِيَ is weird enough that we handle it as a separate function
	if hayy_radicals(rad1, rad2, rad3) then
		make_form_i_hayy_verb(data, args)
		return
	end

	-- need to provide two vowels - past and non-past
	local past_vowel = past_vowel or "a"
	local nonpast_vowel = nonpast_vowel or past_vowel == "i" and "a" or
		past_vowel == "u" and "u" or rad3 == Y and "i" or "u"
	check_aiu("past", past_vowel)
	check_aiu("non-past", nonpast_vowel)

	-- Verbal nouns (maṣādir) for form I are unpredictable and have to be supplied
	insert_verbal_noun(data, args, {})

	-- past and non-past stems, active and passive, and imperative stem
	local past_stem = rad1 .. A .. rad2
	local ps_past_stem = rad1 .. U .. rad2
	local nonpast_stem, ps_nonpast_stem, imper_stem
	if raa_radicals(rad1, rad2, rad3) then
		data.irregular = true
		nonpast_stem = rad1
		ps_nonpast_stem = rad1
		imper_stem = rad1
	else
		ps_nonpast_stem = rad1 .. SK .. rad2
		if assimilated then
			nonpast_stem = rad2
			imper_stem = rad2
		else
			nonpast_stem = ps_nonpast_stem
			-- determine the imperative vowel based on non-past vowel
			local imper_vowel = imper_vowel_from_nonpast(nonpast_vowel)
			imper_stem =  ALIF .. dia[imper_vowel] ..
				(rad1 == HAMZA and short_to_long_vowel(dia[imper_vowel])
					or rad1 .. SK) ..
				rad2
		end
	end

	-- make parts
	local past_suffs =
		rad3 == Y and past_vowel == "a" and past_endings_ay or
		rad3 == W and past_vowel == "a" and past_endings_aw or
		past_vowel == "i" and past_endings_ii or
		past_endings_uu
	local indic_suffs, subj_suffs, juss_suffs, impr_suffs
	if nonpast_vowel == "a" then
		indic_suffs = indic_endings_aa
		subj_suffs = subj_endings_aa
		juss_suffs = juss_endings_aa
		impr_suffs = impr_endings_aa
	elseif nonpast_vowel == "i" then
		indic_suffs = indic_endings_ii
		subj_suffs = subj_endings_ii
		juss_suffs = juss_endings_ii
		impr_suffs = impr_endings_ii
	else
		assert(nonpast_vowel == "u")
		indic_suffs = indic_endings_uu
		subj_suffs = subj_endings_uu
		juss_suffs = juss_endings_uu
		impr_suffs = impr_endings_uu
	end
	make_final_weak_verb(data, past_stem, ps_past_stem, nonpast_stem,
		ps_nonpast_stem, imper_stem, past_suffs, indic_suffs,
		subj_suffs, juss_suffs, impr_suffs, "a")

	-- active participle
	insert_part(data, "ap", rad1 .. AA .. rad2 .. IN)
	-- passive participle
	insert_part(data, "pp", MA .. rad1 .. SK .. rad2 ..
		(rad3 == Y and II or UU) .. SH .. UNS)
end

conjugations["I-final-weak"] = function(data, args, rad1, rad2, rad3,
		past_vowel, nonpast_vowel)
	make_form_i_final_weak_verb(data, args, rad1, rad2, rad3,
		past_vowel, nonpast_vowel, false)
end

conjugations["I-assimilated+final-weak"] = function(data, args, rad1, rad2, rad3,
		past_vowel, nonpast_vowel)
	make_form_i_final_weak_verb(data, args, rad1, rad2, rad3,
		past_vowel, nonpast_vowel, "assimilated")
end

conjugations["I-hollow"] = function(data, args, rad1, rad2, rad3,
		past_vowel, nonpast_vowel)
	-- need to specify up to two vowels, past and non-past
	-- default past vowel to short equivalent of middle radical
	local past_vowel = past_vowel or rad2 == Y and "i" or "u"
	-- default non-past vowel to past vowel, unless it's "a", in which case
	-- we default to short equivalent of middle radical
	local nonpast_vowel = nonpast_vowel or past_vowel ~= "a" and past_vowel or
		rad2 == Y and "i" or "u"
	check_aiu("past", past_vowel)
	check_aiu("non-past", nonpast_vowel)
	-- Formerly we signaled an error when past_vowel is "a" but that seems
	-- too harsh. We can interpret a past vowel of "a" as meaning to use the
	-- non-past vowel in forms requiring a short vowel. If the non-past vowel
	-- is "a" then the past vowel can only be "i" (e.g. in nāma yanāmu with
	-- first singular past of nimtu).
	if past_vowel == "a" then
		-- error("For form I hollow, past vowel cannot be 'a'")
		past_vowel = nonpast_vowel == "a" and "i" or nonpast_vowel
	end
	local lengthened_nonpast = nonpast_vowel == "u" and UU or
		nonpast_vowel == "i" and II or AA

	-- Verbal nouns (maṣādir) for form I are unpredictable and have to be supplied
	insert_verbal_noun(data, args, {})

	-- active past stems - vowel (v) and consonant (c)
	local past_v_stem = rad1 .. AA .. rad3
	local past_c_stem = rad1 .. dia[past_vowel] .. rad3

	-- active non-past stems - vowel (v) and consonant (c)
	local nonpast_v_stem = rad1 .. lengthened_nonpast .. rad3
	local nonpast_c_stem = rad1 .. dia[nonpast_vowel] .. rad3

	-- passive past stems - vowel (v) and consonant (c)
	-- 'ufīla, 'ufiltu
	local ps_past_v_stem = rad1 .. II .. rad3
	local ps_past_c_stem = rad1 .. I .. rad3

	-- passive non-past stems - vowel (v) and consonant (c)
	-- yufāla/yufalna
	-- stem is built differently but conjugation is identical to sound verbs
	local ps_nonpast_v_stem = rad1 .. AA .. rad3
	local ps_nonpast_c_stem = rad1 .. A .. rad3

	-- imperative stem
	local imper_v_stem = nonpast_v_stem
	local imper_c_stem = nonpast_c_stem

	-- make parts
	make_hollow_geminate_verb(data, past_v_stem, past_c_stem, ps_past_v_stem,
		ps_past_c_stem, nonpast_v_stem, nonpast_c_stem, ps_nonpast_v_stem,
		ps_nonpast_c_stem, imper_v_stem, imper_c_stem, "a", false)

	-- active participle
	insert_part(data, "ap", rad3 == HAMZA and rad1 .. AA .. HAMZA .. IN or
		rad1 .. AA .. HAMZA .. I .. rad3 .. UNS)
	-- passive participle
	insert_part(data, "pp", MA .. rad1 .. (rad2 == Y and II or UU) .. rad3 .. UNS)
end

conjugations["I-geminate"] = function(data, args, rad1, rad2, rad3,
		past_vowel, nonpast_vowel)
	-- need to specify two vowels, past and non-past
	local past_vowel = past_vowel or "a"
	local nonpast_vowel = nonpast_vowel or nonpast_from_past_vowel(past_vowel, rad2, rad3)

	-- Verbal nouns (maṣādir) for form I are unpredictable and have to be supplied
	insert_verbal_noun(data, args, {})

	-- active past stems - vowel (v) and consonant (c)
	local past_v_stem = rad1 .. A .. rad2 .. SH
	local past_c_stem = rad1 .. A .. rad2 .. dia[past_vowel] .. rad2

	-- active non-past stems - vowel (v) and consonant (c)
	local nonpast_v_stem = rad1 .. dia[nonpast_vowel] .. rad2 .. SH
	local nonpast_c_stem = rad1 .. SK .. rad2 .. dia[nonpast_vowel] .. rad2

	-- passive past stems - vowel (v) and consonant (c)
	-- dulla/dulilta
	local ps_past_v_stem = rad1 .. U .. rad2 .. SH
	local ps_past_c_stem = rad1 .. U .. rad2 .. I .. rad2

	-- passive non-past stems - vowel (v) and consonant (c)
	--yudallu/yudlalna
	-- stem is built differently but conjugation is identical to sound verbs
	local ps_nonpast_v_stem = rad1 .. A .. rad2 .. SH
	local ps_nonpast_c_stem = rad1 .. SK .. rad2 .. A .. rad2

	-- determine the imperative vowel based on non-past vowel
	local imper_vowel = imper_vowel_from_nonpast(nonpast_vowel)

	-- imperative stem
	local imper_v_stem = rad1 .. dia[nonpast_vowel] .. rad2 .. SH
	local imper_c_stem = ALIF .. dia[imper_vowel] ..
		(rad1 == HAMZA and short_to_long_vowel(dia[imper_vowel]) or rad1 .. SK) ..
		rad2 .. dia[nonpast_vowel] .. rad2

	-- make parts
	make_hollow_geminate_verb(data, past_v_stem, past_c_stem, ps_past_v_stem,
		ps_past_c_stem, nonpast_v_stem, nonpast_c_stem, ps_nonpast_v_stem,
		ps_nonpast_c_stem, imper_v_stem, imper_c_stem, "a", "geminate")

	-- active participle
	insert_part(data, "ap", rad1 .. AA .. rad2 .. SH .. UNS)
	-- passive participle
	insert_part(data, "pp", MA .. rad1 .. SK .. rad2 .. U .. "و" .. rad2 .. UNS)
end

-- Make form II or V sound or final-weak verb. Final-weak verbs are identified
-- by RAD3 = nil, and FORM distinguishes II from V.
local function make_form_ii_v_sound_final_weak_verb(data, args, rad1, rad2, rad3, form)
	local final_weak = rad3 == nil
	local vn = form == "V" and
		"تَ" .. rad1 .. A .. rad2 .. SH ..
			(final_weak and IN or U .. rad3 .. UNS) or
		"تَ" .. rad1 .. SK .. rad2 .. I .. "ي" ..
			(final_weak and AH or rad3) .. UNS
	local ta_pref = form == "V" and "تَ" or ""
	local tu_pref = form == "V" and "تُ" or ""

	-- various stem bases
	local past_stem_base = ta_pref .. rad1 .. A .. rad2 .. SH
	local nonpast_stem_base = past_stem_base
	local ps_past_stem_base = tu_pref .. rad1 .. U .. rad2 .. SH

	-- make parts
	make_augmented_sound_final_weak_verb(data, args, rad3,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, form)
end

conjugations["II-sound"] = function(data, args, rad1, rad2, rad3)
	make_form_ii_v_sound_final_weak_verb(data, args, rad1, rad2, rad3, "II")
end

conjugations["II-final-weak"] = function(data, args, rad1, rad2, rad3)
	make_form_ii_v_sound_final_weak_verb(data, args, rad1, rad2, nil, "II")
end

-- Make form III or VI sound or final-weak verb. Final-weak verbs are identified
-- by RAD3 = nil, and FORM distinguishes III from VI.
local function make_form_iii_vi_sound_final_weak_verb(data, args, rad1, rad2, rad3, form)
	local final_weak = rad3 == nil
	local vn = form == "VI" and
		"تَ" .. rad1 .. AA .. rad2 ..
			(final_weak and IN or U .. rad3 .. UNS) or
		{MU .. rad1 .. AA .. rad2 .. (final_weak and AAH or A .. rad3 .. AH) .. UNS,
			rad1 .. I .. rad2 .. AA .. (final_weak and HAMZA or rad3) .. UNS}
	local ta_pref = form == "VI" and "تَ" or ""
	local tu_pref = form == "VI" and "تُ" or ""

	-- various stem bases
	local past_stem_base = ta_pref .. rad1 .. AA .. rad2
	local nonpast_stem_base = past_stem_base
	local ps_past_stem_base = tu_pref .. rad1 .. UU .. rad2

	-- make parts
	make_augmented_sound_final_weak_verb(data, args, rad3,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, form)
end

conjugations["III-sound"] = function(data, args, rad1, rad2, rad3)
	make_form_iii_vi_sound_final_weak_verb(data, args, rad1, rad2, rad3, "III")
end

conjugations["III-final-weak"] = function(data, args, rad1, rad2, rad3)
	make_form_iii_vi_sound_final_weak_verb(data, args, rad1, rad2, nil, "III")
end

-- Make form III or VI geminate verb. FORM distinguishes III from VI.
local function make_form_iii_vi_geminate_verb(data, args, rad1, rad2, form)
	-- alternative verbal noun فِعَالٌ will be inserted when we add sound parts below
	local vn = form == "VI" and
		{"تَ" .. rad1 .. AA .. rad2 .. SH .. UNS} or
		{MU .. rad1 .. AA .. rad2 .. SH .. AH .. UNS}
	local ta_pref = form == "VI" and "تَ" or ""
	local tu_pref = form == "VI" and "تُ" or ""

	-- various stem bases
	local past_stem_base = ta_pref .. rad1 .. AA
	local nonpast_stem_base = past_stem_base
	local ps_past_stem_base = tu_pref .. rad1 .. UU

	-- make parts
	make_augmented_geminate_verb(data, args, rad2,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, form)

	-- Also add alternative sound (non-compressed) parts. This will lead to
	-- some duplicate entries, but they are removed in get_spans().
	make_form_iii_vi_sound_final_weak_verb(data, args, rad1, rad2, rad2, form)
end

conjugations["III-geminate"] = function(data, args, rad1, rad2, rad3)
	make_form_iii_vi_geminate_verb(data, args, rad1, rad2, "III")
end

-- Make form IV sound or final-weak verb. Final-weak verbs are identified
-- by RAD3 = nil.
local function make_form_iv_sound_final_weak_verb(data, args, rad1, rad2, rad3)
	local final_weak = rad3 == nil

	-- core of stem base, minus stem prefixes
	local stem_core

	-- check for irregular verb أَرَى
	if raa_radicals(rad1, rad2, final_weak and Y or rad3) then
		data.irregular = true
		stem_core = rad1
	else
		stem_core =	rad1 .. SK .. rad2
	end

	-- verbal noun
	local vn = HAMZA .. I .. stem_core .. AA ..
		(final_weak and HAMZA or rad3) .. UNS

	-- various stem bases
	local past_stem_base = HAMZA .. A .. stem_core
	local nonpast_stem_base = stem_core
	local ps_past_stem_base = HAMZA .. U .. stem_core

	-- make parts
	make_augmented_sound_final_weak_verb(data, args, rad3,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, "IV")
end

conjugations["IV-sound"] = function(data, args, rad1, rad2, rad3)
	make_form_iv_sound_final_weak_verb(data, args, rad1, rad2, rad3)
end

conjugations["IV-final-weak"] = function(data, args, rad1, rad2, rad3)
	make_form_iv_sound_final_weak_verb(data, args, rad1, rad2, nil)
end

conjugations["IV-hollow"] = function(data, args, rad1, rad2, rad3)
	-- verbal noun
	local vn = HAMZA .. I .. rad1 .. AA .. rad3 .. AH .. UNS

	-- various stem bases
	local past_stem_base = HAMZA .. A .. rad1
	local nonpast_stem_base = rad1
	local ps_past_stem_base = HAMZA .. U .. rad1

	-- make parts
	make_augmented_hollow_verb(data, args, rad3,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, "IV")
end

conjugations["IV-geminate"] = function(data, args, rad1, rad2, rad3)
	local vn = HAMZA .. I .. rad1 .. SK .. rad2 .. AA .. rad2 .. UNS

	-- various stem bases
	local past_stem_base = HAMZA .. A .. rad1
	local nonpast_stem_base = rad1
	local ps_past_stem_base = HAMZA .. U .. rad1

	-- make parts
	make_augmented_geminate_verb(data, args, rad2,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, "IV")
end

conjugations["V-sound"] = function(data, args, rad1, rad2, rad3)
	make_form_ii_v_sound_final_weak_verb(data, args, rad1, rad2, rad3, "V")
end

conjugations["V-final-weak"] = function(data, args, rad1, rad2, rad3)
	make_form_ii_v_sound_final_weak_verb(data, args, rad1, rad2, nil, "V")
end

conjugations["VI-sound"] = function(data, args, rad1, rad2, rad3)
	make_form_iii_vi_sound_final_weak_verb(data, args, rad1, rad2, rad3, "VI")
end

conjugations["VI-final-weak"] = function(data, args, rad1, rad2, rad3)
	make_form_iii_vi_sound_final_weak_verb(data, args, rad1, rad2, nil, "VI")
end

conjugations["VI-geminate"] = function(data, args, rad1, rad2, rad3)
	make_form_iii_vi_geminate_verb(data, args, rad1, rad2, "VI")
end

-- Make a verbal noun of the general form that applies to forms VII and above.
-- RAD12 is the first consonant cluster (after initial اِ) and RAD34 is the
-- second consonant cluster. RAD5 is the final consonant, or nil for final-weak
-- verbs.
local function high_form_verbal_noun(rad12, rad34, rad5)
	return "اِ" .. rad12 .. I .. rad34 .. AA ..
		(rad5 == nil and HAMZA or rad5) .. UNS
end

-- Populate a sound or final-weak verb for any of the various high-numbered
-- augmented forms (form VII and up) that have up to 5 consonants in two
-- clusters in the stem and the same pattern of vowels between.
-- Some of these consonants in certain verb parts are w's, which leads to apparent
-- anomalies in certain stems of these parts, but these anomalies are handled
-- automatically in postprocessing, where we resolve sequences of iwC -> īC,
-- uwC -> ūC, w + sukūn + w -> w + shadda.
--
-- RAD12 is the first consonant cluster (after initial اِ) and RAD34 is the
-- second consonant cluster. RAD5 is the final consonant, or nil for final-weak
-- verbs.
local function make_high_form_sound_final_weak_verb(data, args, rad12, rad34, rad5, form)
	local final_weak = rad5 == nil
	local vn = high_form_verbal_noun(rad12, rad34, rad5)

	-- various stem bases
	local nonpast_stem_base = rad12 .. A .. rad34
	local past_stem_base = "اِ" .. nonpast_stem_base
	local ps_past_stem_base = "اُ" .. rad12 .. U .. rad34

	-- make parts
	make_augmented_sound_final_weak_verb(data, args, rad5,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, form)
end

-- Make form VII sound or final-weak verb. Final-weak verbs are identified
-- by RAD3 = nil.
local function make_form_vii_sound_final_weak_verb(data, args, rad1, rad2, rad3)
	make_high_form_sound_final_weak_verb(data, args, "نْ" .. rad1, rad2, rad3, "VII")
end

conjugations["VII-sound"] = function(data, args, rad1, rad2, rad3)
	make_form_vii_sound_final_weak_verb(data, args, rad1, rad2, rad3)
end

conjugations["VII-final-weak"] = function(data, args, rad1, rad2, rad3)
	make_form_vii_sound_final_weak_verb(data, args, rad1, rad2, nil)
end

conjugations["VII-hollow"] = function(data, args, rad1, rad2, rad3)
	local nrad1 = "نْ" .. rad1
	local vn = high_form_verbal_noun(nrad1, Y, rad3)

	-- various stem bases
	local nonpast_stem_base = nrad1
	local past_stem_base = "اِ" ..nonpast_stem_base
	local ps_past_stem_base = "اُ" .. nrad1

	-- make parts
	make_augmented_hollow_verb(data, args, rad3,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, "VII")
end

conjugations["VII-geminate"] = function(data, args, rad1, rad2, rad3)
	local nrad1 = "نْ" .. rad1
	local vn = high_form_verbal_noun(nrad1, rad2, rad2)

	-- various stem bases
	local nonpast_stem_base = nrad1 .. A
	local past_stem_base = "اِ" .. nonpast_stem_base
	local ps_past_stem_base = "اُ" .. nrad1 .. U

	-- make parts
	make_augmented_geminate_verb(data, args, rad2,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, "VII")
end

-- Join the infixed tā' (ت) to the first radical in form VIII verbs. This may
-- cause assimilation of the tā' to the radical or in some cases the radical to
-- the tā'.
local function join_ta(rad)
	if rad == W or rad == Y or rad == "ت" then return "تّ"
	elseif rad == "د" then return "دّ"
	elseif rad == "ث" then return "ثّ"
	elseif rad == "ذ" then return "ذّ"
	elseif rad == "ز" then return "زْد"
	elseif rad == "ص" then return "صْط"
	elseif rad == "ض" then return "ضْط"
	elseif rad == "ط" then return "طّ"
	elseif rad == "ظ" then return "ظّ"
	else return rad .. SK .. "ت"
	end
end

-- Return Form VIII verbal noun. RAD3 is nil for final-weak verbs. If RAD1 is
-- hamza, there are two alternatives.
local function form_viii_verbal_noun(rad1, rad2, rad3)
	local vn = high_form_verbal_noun(join_ta(rad1), rad2, rad3)
	if rad1 == HAMZA then
		return {vn, high_form_verbal_noun(Y .. T, rad2, rad3)}
	else
		return {vn}
	end
end

-- Make form VIII sound or final-weak verb. Final-weak verbs are identified
-- by RAD3 = nil.
local function make_form_viii_sound_final_weak_verb(data, args, rad1, rad2, rad3)
	-- check for irregular verb اِتَّخَذَ
	if axadh_radicals(rad1, rad2, rad3) then
		data.irregular = true
		rad1 = T
	end
	make_high_form_sound_final_weak_verb(data, args, join_ta(rad1), rad2, rad3,
		"VIII")

	-- Add alternative parts if verb is first-hamza. Any duplicates are
	-- removed in get_spans().
	if rad1 == HAMZA then
		local vn = form_viii_verbal_noun(rad1, rad2, rad3)
		local past_stem_base2 = "اِيتَ" .. rad2
		local nonpast_stem_base2 = join_ta(rad1) .. A .. rad2
		local ps_past_stem_base2 = "اُوتُ" .. rad2
		make_augmented_sound_final_weak_verb(data, args, rad3,
			past_stem_base2, nonpast_stem_base2, ps_past_stem_base2, vn, "VIII")
	end
end

conjugations["VIII-sound"] = function(data, args, rad1, rad2, rad3)
	make_form_viii_sound_final_weak_verb(data, args, rad1, rad2, rad3)
end

conjugations["VIII-final-weak"] = function(data, args, rad1, rad2, rad3)
	make_form_viii_sound_final_weak_verb(data, args, rad1, rad2, nil)
end

conjugations["VIII-hollow"] = function(data, args, rad1, rad2, rad3)
	local vn = form_viii_verbal_noun(rad1, Y, rad3)

	-- various stem bases
	local nonpast_stem_base = join_ta(rad1)
	local past_stem_base = "اِ" .. nonpast_stem_base
	local ps_past_stem_base = "اُ" .. nonpast_stem_base

	-- make parts
	make_augmented_hollow_verb(data, args, rad3,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, "VIII")

	-- Add alternative parts if verb is first-hamza. Any duplicates are
	-- removed in get_spans().
	if rad1 == HAMZA then
		local past_stem_base2 = "اِيت"
		local nonpast_stem_base2 = nonpast_stem_base
		local ps_past_stem_base2 = "اُوت"
		make_augmented_hollow_verb(data, args, rad3,
			past_stem_base2, nonpast_stem_base2, ps_past_stem_base2, vn, "VIII")
	end
end

conjugations["VIII-geminate"] = function(data, args, rad1, rad2, rad3)
	local vn = form_viii_verbal_noun(rad1, rad2, rad2)

	-- various stem bases
	local nonpast_stem_base = join_ta(rad1) .. A
	local past_stem_base = "اِ" .. nonpast_stem_base
	local ps_past_stem_base = "اُ" .. join_ta(rad1) .. U

	-- make parts
	make_augmented_geminate_verb(data, args, rad2,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, "VIII")

	-- Add alternative parts if verb is first-hamza. Any duplicates are
	-- removed in get_spans().
	if rad1 == HAMZA then
		local past_stem_base2 = "اِيتَ"
		local nonpast_stem_base2 = nonpast_stem_base
		local ps_past_stem_base2 = "اُوتُ"
		make_augmented_geminate_verb(data, args, rad2,
			past_stem_base2, nonpast_stem_base2, ps_past_stem_base2, vn, "VIII")
	end
end

conjugations["IX-sound"] = function(data, args, rad1, rad2, rad3)
	local ipref = "اِ"
	local vn = ipref .. rad1 .. SK .. rad2 .. I .. rad3 .. AA .. rad3 .. UNS

	-- various stem bases
	local nonpast_stem_base = rad1 .. SK .. rad2 .. A
	local past_stem_base = ipref .. nonpast_stem_base
	local ps_past_stem_base = "اُ" .. rad1 .. SK .. rad2 .. U

	-- make parts
	make_augmented_geminate_verb(data, args, rad3,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, "IX")
end

conjugations["IX-final-weak"] = function(data, args, rad1, rad2, rad3)
	error("FIXME: Not yet implemented")
end

-- Populate a sound or final-weak verb for any of the various high-numbered
-- augmented forms that have 5 consonants in the stem and the same pattern of
-- vowels. Some of these consonants in certain verb parts are w's, which leads to
-- apparent anomalies in certain stems of these parts, but these anomalies
-- are handled automatically in postprocessing, where we resolve sequences of
-- iwC -> īC, uwC -> ūC, w + sukūn + w -> w + shadda.
local function make_high5_form_sound_final_weak_verb(data, args, rad1, rad2, rad3, rad4, rad5, form)
	make_high_form_sound_final_weak_verb(data, args, rad1 .. SK .. rad2,
		rad3 .. SK .. rad4, rad5, form)
end

-- Make form X sound or final-weak verb. Final-weak verbs are identified
-- by RAD3 = nil.
local function make_form_x_sound_final_weak_verb(data, args, rad1, rad2, rad3)
	make_high5_form_sound_final_weak_verb(data, args, S, T, rad1, rad2, rad3, "X")
	-- check for irregular verb اِسْتَحْيَا (also اِسْتَحَى)
	if hayy_radicals(rad1, rad2, rad3 or Y) then
		data.irregular = true
		-- Add alternative entries to the verbal paradigms. Any duplicates are
		-- removed in get_spans().
		make_high_form_sound_final_weak_verb(data, args, S .. SK .. T, rad1, rad3, "X")
	end
end

conjugations["X-sound"] = function(data, args, rad1, rad2, rad3)
	make_form_x_sound_final_weak_verb(data, args, rad1, rad2, rad3)
end

conjugations["X-final-weak"] = function(data, args, rad1, rad2, rad3)
	make_form_x_sound_final_weak_verb(data, args, rad1, rad2, nil)
end

conjugations["X-hollow"] = function(data, args, rad1, rad2, rad3)
	local vn = "اِسْتِ" .. rad1 .. AA .. rad3 .. AH .. UNS

	-- various stem bases
	local past_stem_base = "اِسْتَ" .. rad1
	local nonpast_stem_base = "سْتَ" .. rad1
	local ps_past_stem_base = "اُسْتُ" .. rad1

	-- make parts
	make_augmented_hollow_verb(data, args, rad3,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, "X")
end

conjugations["X-geminate"] = function(data, args, rad1, rad2, rad3)
	local vn = "اِسْتِ" .. rad1 .. SK .. rad2 .. AA .. rad2 .. UNS

	-- various stem bases
	local past_stem_base = "اِسْتَ" .. rad1
	local nonpast_stem_base = "سْتَ" .. rad1
	local ps_past_stem_base = "اُسْتُ" .. rad1

	-- make parts
	make_augmented_geminate_verb(data, args, rad2,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, "X")
end

conjugations["XI-sound"] = function(data, args, rad1, rad2, rad3)
	local ipref = "اِ"
	local vn = ipref .. rad1 .. SK .. rad2 .. II .. rad3 .. AA .. rad3 .. UNS

	-- various stem bases
	local nonpast_stem_base = rad1 .. SK .. rad2 .. AA
	local past_stem_base = ipref .. nonpast_stem_base
	local ps_past_stem_base = "اُ" .. rad1 .. SK .. rad2 .. UU

	-- make parts
	make_augmented_geminate_verb(data, args, rad3,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, "XI")
end

-- probably no form XI final-weak, since already geminate in form; would behave as XI-sound

-- Make form XII sound or final-weak verb. Final-weak verbs are identified
-- by RAD3 = nil.
local function make_form_xii_sound_final_weak_verb(data, args, rad1, rad2, rad3)
	make_high5_form_sound_final_weak_verb(data, args, rad1, rad2, W, rad2, rad3, "XII")
end

conjugations["XII-sound"] = function(data, args, rad1, rad2, rad3)
	make_form_xii_sound_final_weak_verb(data, args, rad1, rad2, rad3)
end

conjugations["XII-final-weak"] = function(data, args, rad1, rad2, rad3)
	make_form_xii_sound_final_weak_verb(data, args, rad1, rad2, nil)
end

-- Make form XIII sound or final-weak verb. Final-weak verbs are identified
-- by RAD3 = nil.
local function make_form_xiii_sound_final_weak_verb(data, args, rad1, rad2, rad3)
	make_high5_form_sound_final_weak_verb(data, args, rad1, rad2, W, W, rad3, "XIII")
end

conjugations["XIII-sound"] = function(data, args, rad1, rad2, rad3)
	make_form_xiii_sound_final_weak_verb(data, args, rad1, rad2, rad3)
end

conjugations["XIII-final-weak"] = function(data, args, rad1, rad2, rad3)
	make_form_xiii_sound_final_weak_verb(data, args, rad1, rad2, nil)
end

-- Make a form XIV or XV sound or final-weak verb. Last radical appears twice
-- (if`anlala / yaf`anlilu) so if it were w or y you'd get if`anwā / yaf`anwī
-- or if`anyā / yaf`anyī, i.e. we need the identity of the radical, so the
-- normal trick of passing nil as rad3 into these types of functions won't work.
-- Instead we pass the full radical as well as a flag indicating whether the
-- verb is final-weak. The last radical need not be w or y; in fact this is
-- exactly what form XV is about.
local function make_form_xiv_xv_sound_final_weak_verb(data, args, rad1, rad2, rad3, final_weak, form)
	local lastrad = not final_weak and rad3 or nil
	make_high5_form_sound_final_weak_verb(data, args, rad1, rad2, N, rad3, lastrad, form)
end

conjugations["XIV-sound"] = function(data, args, rad1, rad2, rad3)
	make_form_xiv_xv_sound_final_weak_verb(data, args, rad1, rad2, rad3, false, "XIV")
end

conjugations["XIV-final-weak"] = function(data, args, rad1, rad2, rad3)
	make_form_xiv_xv_sound_final_weak_verb(data, args, rad1, rad2, rad3, true, "XIV")
end

conjugations["XV-sound"] = function(data, args, rad1, rad2, rad3)
	make_form_xiv_xv_sound_final_weak_verb(data, args, rad1, rad2, rad3, true, "XV")
end

-- probably no form XV final-weak, since already final-weak in form; would behave as XV-sound

-- Make form Iq or IIq sound or final-weak verb. Final-weak verbs are identified
-- by RAD4 = nil. FORM distinguishes Iq from IIq.
local function make_form_iq_iiq_sound_final_weak_verb(data, args, rad1, rad2, rad3, rad4, form)
	local final_weak = rad4 == nil
	local vn = form == "IIq" and
		"تَ" .. rad1 .. A .. rad2 .. SK .. rad3 ..
			(final_weak and IN or U .. rad4 .. UNS) or
		rad1 .. A .. rad2 .. SK .. rad3 ..
			(final_weak and AAH or A .. rad4 .. AH) .. UNS
	local ta_pref = form == "IIq" and "تَ" or ""
	local tu_pref = form == "IIq" and "تُ" or ""

	-- various stem bases
	local past_stem_base = ta_pref .. rad1 .. A .. rad2 .. SK .. rad3
	local nonpast_stem_base = past_stem_base
	local ps_past_stem_base = tu_pref .. rad1 .. U .. rad2 .. SK .. rad3

	-- make parts
	make_augmented_sound_final_weak_verb(data, args, rad4,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, form)
end

conjugations["Iq-sound"] = function(data, args, rad1, rad2, rad3, rad4)
	make_form_iq_iiq_sound_final_weak_verb(data, args, rad1, rad2, rad3, rad4, "Iq")
end

conjugations["Iq-final-weak"] = function(data, args, rad1, rad2, rad3, rad4)
	make_form_iq_iiq_sound_final_weak_verb(data, args, rad1, rad2, rad3, nil, "Iq")
end

conjugations["IIq-sound"] = function(data, args, rad1, rad2, rad3, rad4)
	make_form_iq_iiq_sound_final_weak_verb(data, args, rad1, rad2, rad3, rad4, "IIq")
end

conjugations["IIq-final-weak"] = function(data, args, rad1, rad2, rad3, rad4)
	make_form_iq_iiq_sound_final_weak_verb(data, args, rad1, rad2, rad3, nil, "IIq")
end

-- Make form IIIq sound or final-weak verb. Final-weak verbs are identified
-- by RAD4 = nil.
local function make_form_iiiq_sound_final_weak_verb(data, args, rad1, rad2, rad3, rad4)
	make_high5_form_sound_final_weak_verb(data, args, rad1, rad2, N, rad3, rad4, "IIIq")
end

conjugations["IIIq-sound"] = function(data, args, rad1, rad2, rad3, rad4)
	make_form_iiiq_sound_final_weak_verb(data, args, rad1, rad2, rad3, rad4)
end

conjugations["IIIq-final-weak"] = function(data, args, rad1, rad2, rad3, rad4)
	make_form_iiiq_sound_final_weak_verb(data, args, rad1, rad2, rad3, nil)
end

conjugations["IVq-sound"] = function(data, args, rad1, rad2, rad3, rad4)
	local ipref = "اِ"
	local vn = ipref .. rad1 .. SK .. rad2 .. I .. rad3 .. SK .. rad4 .. AA .. rad4 .. UNS

	-- various stem bases
	local past_stem_base = ipref .. rad1 .. SK .. rad2 .. A .. rad3
	local nonpast_stem_base = rad1 .. SK .. rad2 .. A .. rad3
	local ps_past_stem_base = "اُ" .. rad1 .. SK .. rad2 .. U .. rad3

	-- make parts
	make_augmented_geminate_verb(data, args, rad4,
		past_stem_base, nonpast_stem_base, ps_past_stem_base, vn, "IVq")
end

-- probably no form IVq final-weak, since already geminate in form; would behave as IVq-sound

-------------------------------------------------------------------------------
--                       Guts of main conjugation function                   --
-------------------------------------------------------------------------------

local function initialize_categories(data, form, weakness, rad1, rad2, rad3, rad4)
	-- We have to distinguish weakness by form and weakness by conjugation.
	-- Weakness by form merely indicates the presence of weak letters in
	-- certain positions in the radicals. Weakness by conjugation is related
	-- to how the verbs are conjugated. For example, form-II verbs that are
	-- "hollow by form" (middle radical is wāw or yāʾ) are conjugated as sound
	-- verbs. Another example: form-I verbs with initial wāw are "assimilated
	-- by form" and most are assimilated by conjugation as well, but a few
	-- are sound by conjugation, e.g. wajuha yawjuhu "to be distinguished"
	-- (rather than wajuha yajuhu); similarly for some hollow-by-form verbs
	-- in various forms, e.g. form VIII izdawaja yazdawiju "to be in pairs"
	-- (rather than izdāja yazdāju). When most references say just plain
	-- "hollow" or "assimilated" or whatever verbs, they mean by form, so
	-- we name the categories appropriately, where e.g. "Arabic hollow verbs"
	-- means by form, "Arabic hollow verbs by conjugation" means by
	-- conjugation.
	table.insert(data.categories, "Arabic form-" .. form .. " verbs")
	table.insert(data.headword_categories, "Arabic form-" .. form .. " verbs")
	table.insert(data.categories, "Arabic " .. weakness .. " verbs by conjugation")
	table.insert(data.headword_categories, "Arabic " .. weakness .. " verbs by conjugation")
	if form_is_quadriliteral(form) then
		table.insert(data.categories, "Arabic verbs with quadriliteral roots")
		table.insert(data.headword_categories, "Arabic verbs with quadriliteral roots")
	end
	local formweak = {}
	if is_waw_ya(rad1) then
		table.insert(formweak, "assimilated")
	end
	if is_waw_ya(rad2) and rad4 == nil then
		table.insert(formweak, "hollow")
	end
	if is_waw_ya(rad4) or rad4 == nil and is_waw_ya(rad3) then
		table.insert(formweak, "final-weak")
	end
	if rad4 == nil and rad2 == rad3 then
		table.insert(formweak, "geminate")
	end
	if rad1 == HAMZA or rad2 == HAMZA or rad3 == HAMZA or rad4 == HAMZA then
		table.insert(formweak, "hamzated")
	end
	if #formweak == 0 then
		table.insert(formweak, "sound")
	end
	for _, fw in ipairs(formweak) do
		table.insert(data.categories, "Arabic " .. fw .. " form-" .. form .. " verbs")
		table.insert(data.categories, "Arabic " .. fw .. " verbs")
		table.insert(data.headword_categories, "Arabic " .. fw .. " form-" .. form .. " verbs")
		table.insert(data.headword_categories, "Arabic " .. fw .. " verbs")
	end


	local function radical_is_ambiguous(rad)
		return rad == "t" or rad == "w" or rad == "y"
	end
	local function radical_is_weak(rad)
		return rad == W or rad == Y or rad == HAMZA
	end

	local ur1, ur2, ur3, ur4 =
		data.unreg_rad1, data.unreg_rad2, data.unreg_rad3, data.unreg_rad4
	-- Create headword categories based on the radicals. Do the following before
	-- converting the Latin radicals into Arabic ones so we distinguish
	-- between ambiguous and non-ambiguous radicals.
	if radical_is_ambiguous(ur1) or radical_is_ambiguous(ur2) or
			radical_is_ambiguous(ur3) or radical_is_ambiguous(ur4) then
		table.insert(data.headword_categories,
			"Arabic verbs with ambiguous radicals")
	end
	if radical_is_weak(ur1) then
		table.insert(data.headword_categories, "Arabic form-" .. form ..
			" verbs with " .. ur1 .. " as first radical")
	end
	if radical_is_weak(ur2) then
		table.insert(data.headword_categories, "Arabic form-" .. form ..
			" verbs with " .. ur2 .. " as second radical")
	end
	if radical_is_weak(ur3) then
		table.insert(data.headword_categories, "Arabic form-" .. form ..
			" verbs with " .. ur3 .. " as third radical")
	end
	if radical_is_weak(ur4) then
		table.insert(data.headword_categories, "Arabic form-" .. form ..
			" verbs with " .. ur4 .. " as fourth radical")
	end

	if data.passive == "only" then
		table.insert(data.categories, "Arabic passive verbs")
		table.insert(data.categories, "Arabic verbs with full passive")
	elseif data.passive == "only-impers" then
		table.insert(data.categories, "Arabic passive verbs")
		table.insert(data.categories, "Arabic verbs with impersonal passive")
	elseif data.passive == "impers" then
		table.insert(data.categories, "Arabic verbs with impersonal passive")
	elseif data.passive then
		table.insert(data.categories, "Arabic verbs with full passive")
	else
		table.insert(data.categories, "Arabic verbs lacking passive forms")
	end
end

-- given form, weakness and radicals, check to make sure the radicals present
-- are allowable for the weakness. Hamzas on alif/wāw/yāʾ seats are never
-- allowed (should always appear as hamza-on-the-line), and various weaknesses
-- have various strictures on allowable consonants.
local function check_radicals(form, weakness, rad1, rad2, rad3, rad4)
	local function hamza_check(index, rad)
		if rad == HAMZA_ON_ALIF or rad == HAMZA_UNDER_ALIF or
			rad == HAMZA_ON_W or rad == HAMZA_ON_Y then
			error("Radical " .. index .. " is " .. rad .. " but should be ء (hamza on the line)")
		end
	end
	local function check_waw_ya(index, rad)
		if rad ~= W and rad ~= Y then
			error("Radical " .. index .. " is " .. rad .. " but should be و or ي")
		end
	end
	local function check_not_waw_ya(index, rad)
		if rad == W or rad == Y then
			error("In a sound verb, radical " .. index .. " should not be و or ي")
		end
	end
	hamza_check(rad1)
	hamza_check(rad2)
	hamza_check(rad3)
	hamza_check(rad4)
	if weakness == "assimilated" or weakness == "assimilated+final-weak" then
		if rad1 ~= W then
			error("Radical 1 is " .. rad1 .. " but should be و")
		end
	-- don't check that non-assimilated form I verbs don't have wāw as their
	-- first radical because some form-I verbs exist where a first-radical wāw
	-- behaves as sound, e.g. wajuha yawjuhu "to be distinguished".
	end
	if weakness == "final-weak" or weakness == "assimilated+final-weak" then
		if rad4 then
			check_waw_ya(4, rad4)
		else
			check_waw_ya(3, rad3)
		end
	elseif form_supports_final_weak(form) then
		-- non-final-weak verbs cannot have weak final radical if there's a corresponding
		-- final-weak verb category. I think this is safe. We may have problems with
		-- ḥayya/ḥayiya yaḥyā if we treat it as a geminate verb.
		if rad4 then
			check_not_waw_ya(4, rad4)
		else
			check_not_waw_ya(3, rad3)
		end
	end
	if weakness == "hollow" then
		check_waw_ya(2, rad2)
	-- don't check that non-hollow verbs in forms that support hollow verbs
	-- don't have wāw or yāʾ as their second radical because some verbs exist
	-- where a middle-radical wāw/yāʾ behaves as sound, e.g. form-VIII izdawaja
	-- "to be in pairs".
	end
	if weakness == "geminate" then
		if rad4 then
			error("Internal error. No geminate quadrilaterals, should not be seen.")
		end
		if rad2 ~= rad3 then
			error("Weakness is geminate; radical 3 is " .. rad3 .. " but should be same as radical 2 " .. rad2 .. ".")
		end
	elseif form_supports_geminate(form) then
		-- non-geminate verbs cannot have second and third radical same if there's
		-- a corresponding geminate verb category. I think this is safe. We
		-- don't fuss over double wāw or double yāʾ because this could legitimately
		-- be a final-weak verb with middle wāw/yāʾ, treated as sound.
		if rad4 then
			error("Internal error. No quadrilaterals should support geminate verbs.")
		end
		if rad2 == rad3 and not is_waw_ya(rad2) then
			error("Weakness is '" .. weakness .. "'; radical 2 and 3 are same at " .. rad2 .. " but should not be; consider making weakness 'geminate'")
		end
	end
end

-- Determine weakness from radicals
local function weakness_from_radicals(form, rad1, rad2, rad3, rad4)
	local weakness = nil
	local quadlit = rmatch(form, "q$")
	-- If weakness unspecified, derive from radicals.
	if not quadlit then
		if is_waw_ya(rad3) and rad1 == W and form == "I" then
			weakness = "assimilated+final-weak"
		elseif is_waw_ya(rad3) and form_supports_final_weak(form) then
			weakness = "final-weak"
		elseif rad2 == rad3 and form_supports_geminate(form) then
			weakness = "geminate"
		elseif is_waw_ya(rad2) and form_supports_hollow(form) then
			weakness = "hollow"
		elseif rad1 == W and form == "I" then
			weakness = "assimilated"
		else
			weakness = "sound"
		end
	else
		if is_waw_ya(rad4) then
			weakness = "final-weak"
		else
			weakness = "sound"
		end
	end
	return weakness
end

-- Guts of conjugation functions. Shared between {{temp|ar-conj}} and {{temp|ar-verb}}, among others. ARGS is the
-- arguments after processing by [[Module:parameters]]. ARGIND is the numbered argument holding the verb form (either 1
-- or 2); if form is I, the next two arguments are the past and non-past vowels; afterwards are the (optional) radicals.
-- Return five values: DATA, FORM, WEAKNESS, PAST_VOWEL, NONPAST_VOWEL. The last two are arrays of vowels (each one 'a',
-- 'i' or 'u'), since there may be more than one, or none in the case of non-form-I verbs.
local function conjugate(args, argind)
	local data = {forms = {}, categories = {}, headword_categories = {}}

	title = mw.title.getCurrentTitle()
	NAMESPACE = title.nsText
	PAGENAME = ( NAMESPACE == "Appendix" and title.subpageText ) or title.text

	local conj_type = args[argind] or
		error("Form (conjugation type) has not been specified. " ..
			"Please pass a value to parameter " .. argind ..
			" in the template invocation.")

	-- derive form and weakness from conj type
	local form, weakness
	if rfind(conj_type, "%-") then
		local form_weakness = rsplit(conj_type, "%-")
		form = form_weakness[1]
		table.remove(form_weakness, 1)
		weakness = table.concat(form_weakness, "-")
	else
		form = conj_type
		weakness = nil
	end

	-- convert numeric forms to Roman numerals
	-- no longer supported
	-- form = canonicalize_form(form)

	-- check for quadriliteral form (Iq, IIq, IIIq, IVq)
	local quadlit = rmatch(form, "q$")

	-- get radicals and past/non-past vowel
	local rad1, rad2, rad3, rad4, past_vowel, nonpast_vowel
	if form == "I" then
		past_vowel = args[argind + 1]
		nonpast_vowel = args[argind + 2]
		local function splitvowel(vowelspec)
			if vowelspec == nil then
				vowelspec = {}
			else
				vowelspec = rsplit(vowelspec, ",")
			end
			return vowelspec
		end
		-- allow multiple past or non-past vowels separated by commas, e.g.
		-- in farada/faruda yafrudu "to be single"
		past_vowel = splitvowel(past_vowel)
		nonpast_vowel = splitvowel(nonpast_vowel)
		rad1 = args[argind + 3] or args["I"]
		rad2 = args[argind + 4] or args["II"]
		rad3 = args[argind + 5] or args["III"]
	else
		rad1 = args[argind + 1] or args["I"]
		rad2 = args[argind + 2] or args["II"]
		rad3 = args[argind + 3] or args["III"]
		if quadlit then
			rad4 = args[argind + 4] or args["IV"]
		end
	end

	-- Default any unspecified radicals to radicals determined from the
	-- headword. The return radicals may have Latin letters in them (w, t, y)
	-- to indicate ambiguous radicals that should be converted to the
	-- corresponding Arabic letters.
	--
	-- Only call infer_radicals() if at least one radical unspecified,
	-- because infer_radicals() will throw an error if the headword is
	-- malformed for the form, and we don't want that to happen (e.g. we might
	-- be called from a test page).
	if not rad1 or not rad2 or not rad3 or quadlit and not rad4 then
		local wkness, r1, r2, r3, r4 =
			export.infer_radicals(PAGENAME, form)
		-- Use the inferred weakness if we don't override any of the inferred
		-- radicals with something else, i.e. for each user-specified radical,
		-- either it's nil (was not specified) or same as inferred radical.
		-- That way we will correctly set the weakness to sound in cases like
		-- layisa "to be valiant", 'aḥwaja "to need", istahwana "to consider easy",
		-- izdawaja "to be in pairs", etc.
		local use_wkness = (not rad1 or rad1 == r1) and (not rad2 or rad2 == r2) and
			(not rad3 or rad3 == r3) and (not rad4 or rad4 == r4)
		rad1 = rad1 or r1
		rad2 = rad2 or r2
		rad3 = rad3 or r3
		rad4 = rad4 or r4

		-- For most ambiguous radicals, the choice of radical doesn't matter
		-- because it doesn't affect the conjugation one way or another.
		-- For form I hollow verbs, however, it definitely does. In fact, the
		-- choice of radical is critical even beyond the past and non-past
		-- vowels because it affects the form of the passive participle.
		-- So, check for this, try to guess if necessary from non-past vowel,
		-- else signal an error, requiring that the radical be specified
		-- explicitly. This will happen when the non-past vowel isn't specified
		-- and also when it's "a", from which the radical cannot be inferred.
		-- Do this check here rather than in infer_radicals() so that we don't
		-- get an error if the appropriate radical is given but not others.
		if form == "I" and (rad2 == "w" or rad2 == "y") then
			if m_table.contains(nonpast_vowel, "i") then
				rad2 = Y
			elseif m_table.contains(nonpast_vowel, "u") then
				rad2 = W
			else
				error("Unable to guess middle radical of hollow form I verb; " ..
					"need to specify radical explicitly")
			end
		end

		-- If weakness unspecified, then maybe default to weakness determined
		-- from headword. We do this specifically when some radicals are
		-- unspecified and all specified radicals are the same as the
		-- corresponding inferred radicals, i.e. the specified radicals (if any)
		-- don't provide any new information. When this isn't the case, and
		-- the specified radicals override the inferred radicals with something
		-- else, the inferred weakness may be wrong, so we figure out
		-- the weakness below by ourselves, based on the combination of any
		-- user-specified and inferred radicals.
		--
		-- The reason for using the inferred weakness when possible is that
		-- it may be more accurate than the weakness we derive below, in
		-- particular with verbs like layisa "to be courageous",
		-- `awira "to be one-eyed", 'aḥwaja "to need", istajwaba "to interrogate",
		-- izdawaja "to be in pairs", with a weak vowel in a sound conjugation.
		-- The weakness derived below from the radicals would be hollow but the
		-- weakness inferred in infer_radicals() is (correctly) sound.
		if use_wkness then
			weakness = weakness or wkness
		end
	end

	-- Store unregularized radicals for later use in creating categories
	data.unreg_rad1 = rad1
	data.unreg_rad2 = rad2
	data.unreg_rad3 = rad3
	data.unreg_rad4 = rad4

	-- Convert the Latin radicals indicating ambiguity into the corresponding
	-- Arabic radicals.
	local function regularize_inferred_radical(rad)
		if rad == "t" then
			return T
		elseif rad == "w" then
			return W
		elseif rad == "y" then
			return Y
		else
			return rad
		end
	end

	rad1 = regularize_inferred_radical(rad1)
	rad2 = regularize_inferred_radical(rad2)
	rad3 = regularize_inferred_radical(rad3)
	rad4 = regularize_inferred_radical(rad4)

	data.rad1 = rad1
	data.rad2 = rad2
	data.rad3 = rad3
	data.rad4 = rad4

	-- Old code, default radicals to ف-ع-ل or variants.

	--if not quadlit then
	--	-- default radicals to ف-ع-ل (or ف-ل-ل for geminate, or with the
	--	-- appropriate radical replaced by wāw for assimilated/hollow/final-weak)
	--	rad1 = rad1 or
	--		(weakness == "assimilated" or weakness == "assimilated+final-weak") and W or "ف"
	--	rad2 = rad2 or weakness == "hollow" and W or
	--		weakness == "geminate" and "ل" or "ع"
	--	rad3 = rad3 or (weakness == "final-weak" or weakness == "assimilated+final-weak") and W or
	--		weakness == "geminate" and rad2 or "ل"
	--else
	--	-- default to ف-ع-ل-ق (or ف-ع-ل-و for final-weak)
	--	rad1 = rad1 or "ف"
	--	rad2 = rad2 or "ع"
	--	rad3 = rad3 or "ل"
	--	rad4 = rad4 or weakness == "final-weak" and W or "ق"
	--end

	if weakness == nil then
		weakness = weakness_from_radicals(form, rad1, rad2, rad3, rad4)
	end
	
	-- Error if radicals are wrong given the weakness. More likely to happen
	-- if the weakness is explicitly given rather than inferred. Will also
	-- happen if certain incorrect letters are included as radicals e.g.
	-- hamza on top of various letters, alif maqṣūra, tā' marbūṭa.
	check_radicals(form, weakness, rad1, rad2, rad3, rad4)

	-- check to see if an argument ends in a ?. If so, strip the ? and return
	-- true. Otherwise, return false.
	local function check_for_uncertainty(arg)
		if args[arg] and rfind(args[arg], "%?$") then
			args[arg] = rsub(args[arg], "%?$", "")
			if args[arg] == "" then
				args[arg] = nil
			end
			return true
		else
			return false
		end
	end

	-- allow a ? at the end of vn= and passive=; if so, putting the page into
	-- special categories indicating the need to check the property in
	-- question, and remove the ?. Also put into category for vn= if empty
	-- and form is I.
	if check_for_uncertainty("vn") or form == "I" and not args["vn"] then
		table.insert(data.categories, "Arabic verbs needing verbal noun checked")
		data.vn_uncertain = true
	end
	if check_for_uncertainty("passive") then
		table.insert(data.categories, "Arabic verbs needing passive checked")
		data.passive_uncertain = true
	end

	-- parse value of passive.
	--
	-- if the value is "impers", the verb has only impersonal passive;
	-- if the value is "only", the verb has only a passive, no active;
	-- if the value is "only-impers", the verb has only an impersonal passive;
	-- if the value is "yes" or variants, verb has a passive;
	-- if the value is "no" or variants, the verb has no passive.
	-- If not specified, default is yes, but no for forms VII, IX,
	-- XII - XV and IIq - IVq, and "impers" for form VI.
	local passive = args["passive"]
	if passive == "impers" or passive == "only" or passive == "only-impers" then
	elseif not passive then
		passive = form_probably_impersonal_passive(form) and "impers" or
			not form_probably_no_passive(form, weakness, past_vowel,
				nonpast_vowel) and true or false
	else
		passive = yesno(passive, "unknown")
		if passive == "unknown" then
			error("Unrecognized value '" .. args["passive"] ..
				"' to argument passive=; use 'impers', 'only', 'only-impers', " ..
				"'yes'/'y'/'true'/'1' or 'no'/'n'/'false'/'0'")
		end
	end
	data.passive = passive

	data.noimp = yesno(args["noimp"], false)
	if data.noimp then
		table.insert(data.categories, "Arabic verbs lacking imperative forms")
	end

	-- Initialize categories related to form and weakness.
	initialize_categories(data,	form, weakness, rad1, rad2, rad3, rad4)

	-- Reconstruct conjugation type from form and (possibly inferred) weakness.
	conj_type = form .. "-" .. weakness

	-- Check that the conjugation type is recognized.
	if not conjugations[conj_type] then
		error("Unknown conjugation type '" .. conj_type .. "'")
	end

	-- Actually conjugate the verb. The signature of the conjugation function
	-- is different for form-I verbs, non-form-I triliteral verbs, and
	-- quadriliteral verbs.
	--
	-- The way the conjugation functions work is they always add entries to the
	-- appropriate parts of the paradigm (each of which is an array), rather
	-- than setting the values. This makes it possible to call more than one
	-- conjugation function and essentially get a paradigm of the "either
	-- A or B" kind. Doing this may insert duplicate entries into a particular
	-- paradigm part, but this is not a problem because we remove duplicate
	-- entries (in get_spans()) before generating the actual table.
	if quadlit then
		conjugations[conj_type](data, args, rad1, rad2, rad3, rad4)
	elseif form ~= "I" then
		conjugations[conj_type](data, args, rad1, rad2, rad3)
	else
		-- For Form-I verbs, we also pass in the past and non-past vowels.
		-- There may be more than one of each in case of alternative possible
		-- conjugations. In such cases, we loop over the sets of vowels,
		-- calling the appropriate conjugation function for each combination
		-- of past and non-past vowel.

		-- If the past or non-past vowel is unspecified, its value will be
		-- an empty array. In such a case, we still want to iterate once,
		-- passing in nil. Ideally, we'd convert empty arrays into one-element
		-- arrays holding the value nil, but Lua doesn't let you put the
		-- value nil into an array. To work around this we convert each array
		-- to an array of one-element arrays and fetch the first item of the
		-- inner array when we encounter it. Corresponding to nil will
		-- be an empty array, and fetching its first item will indeed
		-- return nil.
		local function convert_to_nested_array(array)
			if #array == 0 then
				return {{}}
			else
				local retval = {}
				for _, el in ipairs(array) do
					table.insert(retval, {el})
				end
				return retval
			end
		end
		local pv_nested = convert_to_nested_array(past_vowel)
		local npv_nested = convert_to_nested_array(nonpast_vowel)
		for i, pv in ipairs(pv_nested) do
			for j, npv in ipairs(npv_nested) do
				-- items were made into 1-element arrays so undo this
				conjugations[conj_type](data, args, rad1, rad2, rad3, pv[1], npv[1])
			end
		end
	end

	return data, form, weakness, past_vowel, nonpast_vowel
end

-------------------------------------------------------------------------------
--                    Functions to create inflection tables                  --
-------------------------------------------------------------------------------

-- array of substitutions; each element is a 2-entry array FROM, TO; do it
-- this way so the concatenations only get evaluated once
local postprocess_subs = {
	-- reorder short-vowel + shadda -> shadda + short-vowel for easier processing
	{"(" .. AIU .. ")" .. SH, SH .. "%1"},

	----------same letter separated by sukūn should instead use shadda---------
	------------happens e.g. in kun-nā "we were".-----------------
	{"(.)" .. SK .. "%1", "%1" .. SH},

	---------------------------- assimilated verbs ----------------------------
	-- iw, iy -> ī (assimilated verbs)
	{I .. W .. SK, II},
	{I .. Y .. SK, II},
	-- uw, uy -> ū (assimilated verbs)
	{U .. W .. SK, UU},
	{U .. Y .. SK, UU},

    -------------- final -yā uses tall alif not alif maqṣūra ------------------
	{"(" .. Y ..  SH .. "?" .. A .. ")" .. AMAQ, "%1" .. ALIF},

	----------------------- handle hamza assimilation -------------------------
	-- initial hamza + short-vowel + hamza + sukūn -> hamza + long vowel
	{HAMZA .. A .. HAMZA .. SK, HAMZA .. A .. ALIF},
	{HAMZA .. I .. HAMZA .. SK, HAMZA .. I .. Y},
	{HAMZA .. U .. HAMZA .. SK, HAMZA .. U .. W}
}

-- Post-process verb parts to eliminate phonological anomalies. Many of the changes,
-- particularly the tricky ones, involve converting hamza to have the proper
-- seat. The rules for this are complicated and are documented on the
-- [[w:Hamza]] Wikipedia page. In some cases there are alternatives allowed,
-- and we handle them below by returning multiple possibilities.
local function postprocess_term(term)
	-- if term is regular hyphen/dash, ndash or mdash, return mdash
	if term == "-" or term == "–" or term == "—" then
		return {"—"} -- mdash
	elseif term == "?" then
		return {"?"}
	end
	-- do the main post-processing, based on the pattern substitutions in
	-- postprocess_subs
	for _, sub in ipairs(postprocess_subs) do
		term = rsub(term, sub[1], sub[2])
	end

	if not rfind(term, HAMZA) then
		return {term}
	end
	term = rsub(term, HAMZA, HAMZA_PH)
	return ar_utilities.process_hamza(term)
end

-- For each paradigm part, postprocess the entries, remove duplicates and
-- return the set of Arabic and transliterated Latin entries as two return
-- values.
local function get_spans(part)
	if type(part) == "string" then
		part = {part}
	end
	local part_nondup = {}
	-- for each entry, postprocess it, which may potentially return
	-- multiple entries; insert each into an array, checking and
	-- omitting duplicates
	for _, entry in ipairs(part) do
		for _, e in ipairs(postprocess_term(entry)) do
			m_table.insertIfNot(part_nondup, e)
		end
	end
	-- convert each individual entry into Arabic and Latin span
	local arabic_spans = {}
	local latin_spans = {}
	for _, entry in ipairs(part_nondup) do
		table.insert(arabic_spans, entry)
		if entry ~= "—" and entry ~= "?" then
			-- multiple Arabic entries may map to the same Latin entry
			-- (happens particularly with variant ways of spelling hamza)
			m_table.insertIfNot(latin_spans, (lang:transliterate(entry)))
		end
	end
	return arabic_spans, latin_spans
end

-- Make the conjugation table. Called from export.show().
local function make_table(data, title, form, intrans)
	local forms = data.forms
	local arabic_spans_3sm_perf, _
	if data.passive == "only" or data.passive == "only-impers" then
		arabic_spans_3sm_perf, _ = get_spans(forms["3sm-ps-perf"])
	else
		arabic_spans_3sm_perf, _ = get_spans(forms["3sm-perf"])
	end
	-- convert Arabic terms to spans
	for i, entry in ipairs(arabic_spans_3sm_perf) do
		arabic_spans_3sm_perf[i] = "<b lang=\"ar\" class=\"Arab\">" .. entry .. "</b>"
	end
	-- concatenate spans
	local part_3sm_perf = '<div style="display: inline-block">' ..
		table.concat(arabic_spans_3sm_perf, " <small style=\"color: #888\">or</small> ") .. "</div>"

	-- compute # of verbal nouns before we collapse them
	local num_vns = type(forms["vn"]) == "table" and #forms["vn"] or 1

	-- also extract list of verbal nouns and preceding text "verbal noun" or
	-- "verbal nouns", for the conjugation table title
	local vn_spans, _ = get_spans(forms["vn"])
	-- convert verbal nouns to spans
	for i, entry in ipairs(vn_spans) do
		vn_spans[i] = '<span lang="ar" class="Arab" style="font-weight: normal">' .. entry .. '</span>'
	end
	local vn_list = #vn_spans == 0 and "?" or
		table.concat(vn_spans, " <small style=\"color: #888\">or</small> ")
	local vn_prefix = #vn_spans > 1 and "verbal nouns" or "verbal noun"
	local vn_text = vn_prefix .. " " .. vn_list

	-- construct conjugation table title
	local title = 'Conjugation of ' .. part_3sm_perf
		.. (form == "I" and " (" .. title .. ", " .. vn_text .. ")" or " (" .. title .. ")")

	-- Format and add transliterations to all parts
	for key, part in pairs(forms) do
		-- check for empty array, size-one array holding a dash or ?
		if #part > 0 then
			local arabic_spans, latin_spans = get_spans(part)
			-- convert Arabic terms to links
			for i, entry in ipairs(arabic_spans) do
				local id
				if part.ids then
					id = part.ids[i]
				end
				
				arabic_spans[i] = links(entry, nil, id)
			end
			
			for i, translit in ipairs(latin_spans) do
				latin_spans[i] = require("Module:script utilities").tag_translit(translit, lang, "default")
			end
			
			-- concatenate spans
			forms[key] = '<div style="display: inline-block">' .. table.concat(arabic_spans, " <small style=\"color: #888\">or</small> ") .. "</div>" .. "<br/>" ..
				"<span style=\"color: #888\">" .. table.concat(latin_spans, " <small>or</small> ") .. "</span>"
		-- if no verbal nouns, it's normally because they're unknown or
		-- unspecified rather than non-existent. For an actually non-existent
		-- verbal noun, put a hyphen or mdash explicitly as the value of the
		-- paradigm part, and it will be handled appropriately (no attempt to
		-- transliterate).
		elseif key == "vn" then
			forms[key] = "?"
		else
			forms[key] = "—"
		end
	end

	local text = [=[<div class="NavFrame ar-conj">
<div class="NavHead" style="height:2.5em">]=] .. title  .. [=[</div>
<div class="NavContent">

{| class="inflection-table"
|-
! colspan="6" class="nonfinite-header" | verbal noun]=] .. (num_vns > 1 and "s" or "") .. "<br />" .. tag_text(num_vns > 1 and "الْمَصَادِر" or "الْمَصْدَر") .. [=[

| colspan="7" | {{{vn}}}
]=]

	if data.passive ~= "only" and data.passive ~= "only-impers" then
		text = text .. [=[
|-
! colspan="6" class="nonfinite-header" | active participle<br />{{{اِسْم الْفَاعِل}}}
| colspan="7" | {{{ap}}}
]=]
	end

	if data.passive then
		text = text .. [=[
|-
! colspan="6" class="nonfinite-header" | passive participle<br />{{{اِسْم الْمَفْعُول}}}
| colspan="7" | {{{pp}}}
]=]
	end

	if data.passive ~= "only" and data.passive ~= "only-impers" then
		text = text .. [=[
|-
! colspan="12" class="voice-header" | active voice<br />{{{الْفِعْل الْمَعْلُوم}}}
|-
! colspan="2" class="empty-header" | 
! colspan="3" class="number-header" | singular<br />{{{الْمُفْرَد}}}
! rowspan="12" class="divider" | 
! colspan="2" class="number-header" | dual<br />{{{الْمُثَنَّى}}}
! rowspan="12" class="divider" | 
! colspan="3" class="number-header" | plural<br />{{{الْجَمْع}}}
|-
! colspan="2" class="empty-header" | 
! class="person-header" | 1<sup>st</sup> person<br />{{{الْمُتَكَلِّم}}}
! class="person-header" | 2<sup>nd</sup> person<br />{{{الْمُخَاطَب}}}
! class="person-header" | 3<sup>rd</sup> person<br />{{{الْغَائِب}}}
! class="person-header" | 2<sup>nd</sup> person<br />{{{الْمُخَاطَب}}}
! class="person-header" | 3<sup>rd</sup> person<br />{{{الْغَائِب}}}
! class="person-header" | 1<sup>st</sup> person<br />{{{الْمُتَكَلِّم}}}
! class="person-header" | 2<sup>nd</sup> person<br />{{{الْمُخَاطَب}}}
! class="person-header" | 3<sup>rd</sup> person<br />{{{الْغَائِب}}}
|-
! rowspan="2" class="tam-header" | past (perfect) indicative<br />{{{الْمَاضِي}}}
! class="gender-header" | m
| rowspan="2" | {{{1s-perf}}}
| {{{2sm-perf}}}
| {{{3sm-perf}}}
| rowspan="2" | {{{2d-perf}}}
| {{{3dm-perf}}}
| rowspan="2" | {{{1p-perf}}}
| {{{2pm-perf}}}
| {{{3pm-perf}}}
|-
! class="gender-header" | f
| {{{2sf-perf}}}
| {{{3sf-perf}}}
| {{{3df-perf}}}
| {{{2pf-perf}}}
| {{{3pf-perf}}}
|-
! rowspan="2" class="tam-header" | non-past (imperfect) indicative<br />{{{الْمُضَارِع الْمَرْفُوع}}}
! class="gender-header" | m
| rowspan="2" | {{{1s-impf}}}
| {{{2sm-impf}}}
| {{{3sm-impf}}}
| rowspan="2" | {{{2d-impf}}}
| {{{3dm-impf}}}
| rowspan="2" | {{{1p-impf}}}
| {{{2pm-impf}}}
| {{{3pm-impf}}}
|-
! class="gender-header" | f
| {{{2sf-impf}}}
| {{{3sf-impf}}}
| {{{3df-impf}}}
| {{{2pf-impf}}}
| {{{3pf-impf}}}
|-
! rowspan="2" class="tam-header" | subjunctive<br />{{{الْمُضَارِع الْمَنْصُوب}}}
! class="gender-header" | m
| rowspan="2" | {{{1s-subj}}}
| {{{2sm-subj}}}
| {{{3sm-subj}}}
| rowspan="2" | {{{2d-subj}}}
| {{{3dm-subj}}}
| rowspan="2" | {{{1p-subj}}}
| {{{2pm-subj}}}
| {{{3pm-subj}}}
|-
! class="gender-header" | f
| {{{2sf-subj}}}
| {{{3sf-subj}}}
| {{{3df-subj}}}
| {{{2pf-subj}}}
| {{{3pf-subj}}}
|-
! rowspan="2" class="tam-header" | jussive<br />{{{الْمُضَارِع الْمَجْزُوم}}}
! class="gender-header" | m
| rowspan="2" | {{{1s-juss}}}
| {{{2sm-juss}}}
| {{{3sm-juss}}}
| rowspan="2" | {{{2d-juss}}}
| {{{3dm-juss}}}
| rowspan="2" | {{{1p-juss}}}
| {{{2pm-juss}}}
| {{{3pm-juss}}}
|-
! class="gender-header" | f
| {{{2sf-juss}}}
| {{{3sf-juss}}}
| {{{3df-juss}}}
| {{{2pf-juss}}}
| {{{3pf-juss}}}
|-
! rowspan="2" class="tam-header" | imperative<br />{{{الْأَمْر}}}
! class="gender-header" | m
| rowspan="2" | 
| {{{2sm-impr}}}
| rowspan="2" | 
| rowspan="2" | {{{2d-impr}}}
| rowspan="2" | 
| rowspan="2" | 
| {{{2pm-impr}}}
| rowspan="2" | 
|-
! class="gender-header" | f
| {{{2sf-impr}}}
| {{{2pf-impr}}}
]=]
	end

	if data.passive == "impers" or data.passive == "only-impers" then
		text = text .. [=[
|-
! colspan="12" class="voice-header" | passive voice<br />{{{الْفِعْل الْمَجْهُول}}}
|-
| colspan="2" class="empty-header" | 
! colspan="3" class="number-header" | singular<br />{{{الْمُفْرَد}}}
| rowspan="10" class="divider" | 
! colspan="2" class="number-header" | dual<br />{{{الْمُثَنَّى}}}
| rowspan="10" class="divider" | 
! colspan="3" class="number-header" | plural<br />{{{الْجَمْع}}}
|-
| colspan="2" class="empty-header" | 
! class="person-header" | 1<sup>st</sup> person<br />{{{الْمُتَكَلِّم}}}
! class="person-header" | 2<sup>nd</sup> person<br />{{{الْمُخَاطَب}}}
! class="person-header" | 3<sup>rd</sup> person<br />{{{الْغَائِب}}}
! class="person-header" | 2<sup>nd</sup> person<br />{{{الْمُخَاطَب}}}
! class="person-header" | 3<sup>rd</sup> person<br />{{{الْغَائِب}}}
! class="person-header" | 1<sup>st</sup> person<br />{{{الْمُتَكَلِّم}}}
! class="person-header" | 2<sup>nd</sup> person<br />{{{الْمُخَاطَب}}}
! class="person-header" | 3<sup>rd</sup> person<br />{{{الْغَائِب}}}
|-
! rowspan="2" class="tam-header" | past (perfect) indicative<br />{{{الْمَاضِي}}}
! class="gender-header" | m
| rowspan="2" | &mdash;
| &mdash;
| {{{3sm-ps-perf}}}
| rowspan="2" | &mdash;
| &mdash;
| rowspan="2" | &mdash;
| &mdash;
| &mdash;
|-
! class="gender-header" | f
| &mdash;
| &mdash;
| &mdash;
| &mdash;
| &mdash;
|-
! rowspan="2" class="tam-header" | non-past (imperfect) indicative<br />{{{الْمُضَارِع الْمَرْفُوع}}}
! class="gender-header" | m
| rowspan="2" | &mdash;
| &mdash;
| {{{3sm-ps-impf}}}
| rowspan="2" | &mdash;
| &mdash;
| rowspan="2" | &mdash;
| &mdash;
| &mdash;
|-
! class="gender-header" | f
| &mdash;
| &mdash;
| &mdash;
| &mdash;
| &mdash;
|-
! rowspan="2" class="tam-header" | subjunctive<br />{{{الْمُضَارِع الْمَنْصُوب}}}
! class="gender-header" | m
| rowspan="2" | &mdash;
| &mdash;
| {{{3sm-ps-subj}}}
| rowspan="2" | &mdash;
| &mdash;
| rowspan="2" | &mdash;
| &mdash;
| &mdash;
|-
! class="gender-header" | f
| &mdash;
| &mdash;
| &mdash;
| &mdash;
| &mdash;
|-
! rowspan="2" class="tam-header" | jussive<br />{{{الْمُضَارِع الْمَجْزُوم}}}
! class="gender-header" | m
| rowspan="2" | &mdash;
| &mdash;
| {{{3sm-ps-juss}}}
| rowspan="2" | &mdash;
| &mdash;
| rowspan="2" | &mdash;
| &mdash;
| &mdash;
|-
! class="gender-header" | f
| &mdash;
| &mdash;
| &mdash;
| &mdash;
| &mdash;
]=]

	elseif data.passive then
		text = text .. [=[
|-
! colspan="12" class="voice-header" | passive voice<br />{{{الْفِعْل الْمَجْهُول}}}
|-
| colspan="2" class="empty-header" | 
! colspan="3" class="number-header" | singular<br />{{{الْمُفْرَد}}}
| rowspan="10" class="divider" | 
! colspan="2" class="number-header" | dual<br />{{{الْمُثَنَّى}}}
| rowspan="10" class="divider" | 
! colspan="3" class="number-header" | plural<br />{{{الْجَمْع}}}
|-
| colspan="2" class="empty-header" | 
! class="person-header" | 1<sup>st</sup> person<br />{{{الْمُتَكَلِّم}}}
! class="person-header" | 2<sup>nd</sup> person<br />{{{الْمُخَاطَب}}}
! class="person-header" | 3<sup>rd</sup> person<br />{{{الْغَائِب}}}
! class="person-header" | 2<sup>nd</sup> person<br />{{{الْمُخَاطَب}}}
! class="person-header" | 3<sup>rd</sup> person<br />{{{الْغَائِب}}}
! class="person-header" | 1<sup>st</sup> person<br />{{{الْمُتَكَلِّم}}}
! class="person-header" | 2<sup>nd</sup> person<br />{{{الْمُخَاطَب}}}
! class="person-header" | 3<sup>rd</sup> person<br />{{{الْغَائِب}}}
|-
! rowspan="2" class="tam-header" | past (perfect) indicative<br />{{{الْمَاضِي}}}
! class="gender-header" | m
| rowspan="2" | {{{1s-ps-perf}}}
| {{{2sm-ps-perf}}}
| {{{3sm-ps-perf}}}
| rowspan="2" | {{{2d-ps-perf}}}
| {{{3dm-ps-perf}}}
| rowspan="2" | {{{1p-ps-perf}}}
| {{{2pm-ps-perf}}}
| {{{3pm-ps-perf}}}
|-
! class="gender-header" | f
| {{{2sf-ps-perf}}}
| {{{3sf-ps-perf}}}
| {{{3df-ps-perf}}}
| {{{2pf-ps-perf}}}
| {{{3pf-ps-perf}}}
|-
! rowspan="2" class="tam-header" | non-past (imperfect) indicative<br />{{{الْمُضَارِع الْمَرْفُوع}}}
! class="gender-header" | m
| rowspan="2" | {{{1s-ps-impf}}}
| {{{2sm-ps-impf}}}
| {{{3sm-ps-impf}}}
| rowspan="2" | {{{2d-ps-impf}}}
| {{{3dm-ps-impf}}}
| rowspan="2" | {{{1p-ps-impf}}}
| {{{2pm-ps-impf}}}
| {{{3pm-ps-impf}}}
|-
! class="gender-header" | f
| {{{2sf-ps-impf}}}
| {{{3sf-ps-impf}}}
| {{{3df-ps-impf}}}
| {{{2pf-ps-impf}}}
| {{{3pf-ps-impf}}}
|-
! rowspan="2" class="tam-header" | subjunctive<br />{{{الْمُضَارِع الْمَنْصُوب}}}
! class="gender-header" | m
| rowspan="2" | {{{1s-ps-subj}}}
| {{{2sm-ps-subj}}}
| {{{3sm-ps-subj}}}
| rowspan="2" | {{{2d-ps-subj}}}
| {{{3dm-ps-subj}}}
| rowspan="2" | {{{1p-ps-subj}}}
| {{{2pm-ps-subj}}}
| {{{3pm-ps-subj}}}
|-
! class="gender-header" | f
| {{{2sf-ps-subj}}}
| {{{3sf-ps-subj}}}
| {{{3df-ps-subj}}}
| {{{2pf-ps-subj}}}
| {{{3pf-ps-subj}}}
|-
! rowspan="2" class="tam-header" | jussive<br />{{{الْمُضَارِع الْمَجْزُوم}}}
! class="gender-header" | m
| rowspan="2" | {{{1s-ps-juss}}}
| {{{2sm-ps-juss}}}
| {{{3sm-ps-juss}}}
| rowspan="2" | {{{2d-ps-juss}}}
| {{{3dm-ps-juss}}}
| rowspan="2" | {{{1p-ps-juss}}}
| {{{2pm-ps-juss}}}
| {{{3pm-ps-juss}}}
|-
! class="gender-header" | f
| {{{2sf-ps-juss}}}
| {{{3sf-ps-juss}}}
| {{{3df-ps-juss}}}
| {{{2pf-ps-juss}}}
| {{{3pf-ps-juss}}}
]=]
	end

	text = text .. [=[
|}
</div>
</div>]=]

	-- Function used as replace arg of call to rsub(). Replace the
	-- specified param with its (HTML) value. The param references appear
	-- as {{{PARAM}}} in the wikicode. Also call tag_text on Arabic text
	-- appearing as {{{ARABIC-TEXT}}}.
	local function repl(param)
		if rfind(param, "^[A-Za-z0-9_-]+$") then
			return data.forms[param]
		else
			return tag_text(param)
		end
	end

	return rsub(text, "{{{([^{}]+)}}}", repl)
		.. mw.getCurrentFrame():extensionTag{
			name = "templatestyles", args = { src = "Template:ar-conj/style.css" }
		}
end

-------------------------------------------------------------------------------
--                              External entry points                        --
-------------------------------------------------------------------------------

local function add_conjugation_args(params, firstarg)
	params[firstarg] = {}
	params[firstarg + 1] = {}
	params[firstarg + 2] = {}
	params[firstarg + 3] = {}
	params[firstarg + 4] = {}
	params[firstarg + 5] = {}
	params["I"] = {}
	params["II"] = {}
	params["III"] = {}
	params["IV"] = {}
	params["vn"] = {}
	params["vn-id"] = {list = true, allow_holes = true, require_index = true}
	params["passive"] = {}
	params["variant"] = {}
	params["noimp"] = {type = "boolean"}
end


-- Implement {{ar-conj}}.
function export.show(frame)
	local parargs = frame:getParent().args

	local params = {
		["intrans"] = {},
	}
	add_conjugation_args(params, 1)

	local args = require("Module:parameters").process(parargs, params)

	local data, form, weakness, past_vowel, nonpast_vowel = conjugate(args, 1)

	-- if the value is "yes" or variants, the verb is intransitive;
	-- if the value is "no" or variants, the verb is transitive.
	-- If not specified, default is intransitive if passive == false or
	-- passive == "impers", else transitive.
	local intrans = args["intrans"]
	if not intrans then
		intrans = data.passive == false or data.passive == "impers" or data.passive == "only-impers"
	else
		intrans = yesno(intrans, "unknown")
		if intrans == "unknown" then
			error("Unrecognized value '" .. args["intrans"] ..
				"' to argument intrans=; use 'yes'/'y'/'true'/'1' or 'no'/'n'/'false'/'0'")
		end
	end
	if intrans then
		table.insert(data.categories, "Arabic intransitive verbs")
	else
		table.insert(data.categories, "Arabic transitive verbs")
	end

	-- initialize title, with weakness indicated by conjugation
	-- (FIXME should it be by form?)
	local title = "form-" .. form .. " " .. weakness

	if data.passive == "only" or data.passive == "only-impers" then
		title = title .. " passive"
	end

	if data.irregular then
		table.insert(data.categories, "Arabic irregular verbs")
		title = title .. " irregular"
	end

	return make_table(data, title, form, intrans) ..
		require("Module:utilities").format_categories(data.categories, lang)
end

-- Version of main entry point meant for calling from the debug console.
-- An example call might be as follows:
--
-- =p.show2({'I', 'a', 'u', 'ك', 'ت', 'ب'})
--
-- This is equivalent to the following template call:
--
-- {{ar-conj|I|a|u|ك|ت|ب}}
--
-- Note that the radicals were actually typed in with ك first, followed by ت
-- and then ب, but they appear in opposite order due to right-to-left
-- display issues. It's necessary to specify the radicals in the call,
-- unlike in a template call where they are inferred from the page name,
-- because there is (currently) no way to control the page name used in
-- the radical-inference code, where it will appear as 'Module:ar-verb'.
function export.show2(parargs, args)
	return export.show(debug_frame(parargs, args))
end

-- Implement {{ar-verb}}.
-- FIXME: Move this into [[Module:ar-headword]]. Standardize parameter handling with [[Module:parameters]]. Use standard
-- functionality in [[Module:head]].
function export.headword(frame)
	local parargs = frame:getParent().args

	local params = {
		["head"] = {list = true, disallow_holes = true},
		["tr"] = {list = true, allow_holes = true},
		["useparam"] = {},
		["noimpf"] = {type = "boolean"},
		["impf"] = {},
		["impfhead"] = {},
		["impftr"] = {},
		["id"] = {},
		["sort"] = {},
	}
	add_conjugation_args(params, 1)

	local args = require("Module:parameters").process(parargs, params)

	local data, form, weakness, past_vowel, nonpast_vowel = conjugate(args, 1)
	local use_params = form == "I" or args["useparam"]

	local arabic_3sm_perf, latin_3sm_perf
	local arabic_3sm_imperf, latin_3sm_imperf
	if data.passive == "only" or data.passive == "only-impers" then
		arabic_3sm_perf, latin_3sm_perf = get_spans(data.forms["3sm-ps-perf"])
		arabic_3sm_imperf, latin_3sm_imperf = get_spans(data.forms["3sm-ps-impf"])
	else
		arabic_3sm_perf, latin_3sm_perf = get_spans(data.forms["3sm-perf"])
		arabic_3sm_imperf, latin_3sm_imperf = get_spans(data.forms["3sm-impf"])
	end
	
	title = mw.title.getCurrentTitle()
	NAMESPACE = title.nsText
	PAGENAME = ( NAMESPACE == "Appendix" and title.subpageText ) or title.text
	
	-- set to PAGENAME if left empty
	local heads, trs
	if use_params and form ~= "I" then
		table.insert(data.headword_categories, "Arabic augmented verbs with parameter override")
	end
	if use_params and (#args["head"] > 0 or args["tr"].maxindex > 0) then
		heads = args["head"]
		trs = args["tr"]
		if form == "I" then
			table.insert(data.headword_categories, "Arabic form-I verbs with headword perfect determined through param, not past vowel")
		end
	elseif form == "I" and #past_vowel == 0 then
		heads = {}
		table.insert(data.headword_categories, "Arabic form-I verbs with missing past vowel in headword")
	else
		-- Massive hack to get the order correct. It gets reversed for some
		-- reason, possibly due to being surrounded by lang=ar or
		-- class=Arabic headword, so reverse the order before concatenating.
		headrev = {}
		for _, ar in ipairs(arabic_3sm_perf) do
			table.insert(headrev, 1, ar)
		end
		heads = {table.concat(headrev, " <small style=\"color: #888\">or</small> ")}
		trs = {table.concat(latin_3sm_perf, " <small style=\"color: #888\">or</small> ")}
	end

	local form_text = ' <span class="gender">[[Appendix:Arabic verbs#Form ' .. form .. '|<abbr title="Verb form ' ..
	  form .. '">' .. form .. '</abbr>]]</span>'

	local noimpf = args["noimpf"]
	local impf_arabic, impf_tr
	if use_params and noimpf then
		impf_arabic = {}
	elseif use_params and args["impf"] then
		impf_arabic = args["impfhead"] or args["impf"]
		impf_tr = args["impftr"] or (lang:transliterate(impf_arabic))
		impf_arabic = {impf_arabic}
		if form == "I" then
			table.insert(data.headword_categories, "Arabic form-I verbs with headword imperfect determined through param, not non-past vowel")
		end
	elseif form == "I" and #nonpast_vowel == 0 then
		impf_arabic = {}
		table.insert(data.headword_categories, "Arabic form-I verbs with missing non-past vowel in headword")
	else
		impf_arabic = arabic_3sm_imperf
		impf_tr = table.concat(latin_3sm_imperf, " <small style=\"color: #888\">or</small> ")
	end

	-- convert Arabic terms to bolded links
	for i, entry in ipairs(impf_arabic) do
		impf_arabic[i] = links(entry, "bold")
	end
	-- create non-past text by concatenating Arabic spans and adding
	-- transliteration, but only if we can do it non-ambiguously (either we're
	-- not form I or the non-past vowel was specified)
	local impf_text = ""
	if #impf_arabic > 0 then
		impf_text = ', <i>non-past</i> ' .. table.concat(impf_arabic, " <small style=\"color: #888\">or</small> ")
		if impf_tr then
			impf_text = impf_text .. LRM .. " (" .. impf_tr .. ")"
		end
	end

	return
		require("Module:headword").full_headword({lang = lang, pos_category = "verbs", categories = data.headword_categories,
			heads = heads, translits = trs, sort_key = args["sort"], id = args["id"]}) ..
		form_text .. impf_text
end

-- Version of headword entry point meant for calling from the debug console.
-- See export.show2().
function export.headword2(parargs, args)
	return export.headword(debug_frame(parargs, args))
end

-- Implementation of export.past3sm() and export.past3sm_all().
local function past3sm(parargs, doall)
	local params = {}
	add_conjugation_args(params, 1)

	local args = require("Module:parameters").process(parargs, params)

	local data, form, weakness, past_vowel, nonpast_vowel =	conjugate(args, 1)

	local arabic_3sm_perf, latin_3sm_perf
	if data.passive == "only" or data.passive == "only-impers" then
		arabic_3sm_perf, latin_3sm_perf = get_spans(data.forms["3sm-ps-perf"])
	else
		arabic_3sm_perf, latin_3sm_perf = get_spans(data.forms["3sm-perf"])
	end

	if doall then
		return table.concat(arabic_3sm_perf, ",")
	else
		return arabic_3sm_perf[1]
	end
end

-- Implement {{ar-past3sm}}.
--
-- Generate the 3rd singular masculine past tense (the dictionary form), given
-- the form, radicals and (for form I) past/non-past vowels (the non-past
-- vowel is ignored, but specified for compatibility with export.headword()
-- and export.show()). Form, radicals, past/non-past vowel arguments are the
-- same as for export.show(). Note that the form returned may be active or
-- passive depending on the passive= param (some values specify that the
-- verb is a passive-only verb). If there are multiple alternatives,
-- return only the first one.
function export.past3sm(frame)
	return past3sm(frame:getParent().args, false)
end

-- Version of past3sm entry point meant for calling from the debug console.
-- See export.show2().
function export.past3sm2(parargs, args)
	return export.past3sm(debug_frame(parargs, args))
end

-- Implement {{ar-past3sm-all}}.
--
-- Same as export.past3sm() but return all possible values, separated by
-- a comma. Multiple values largely come from alternative hamza seats.
function export.past3sm_all(frame)
	return past3sm(frame:getParent().args, true)
end

-- Version of past3sm_all entry point meant for calling from the debug console.
-- See export.show2().
function export.past3sm_all2(parargs, args)
	return export.past3sm_all(debug_frame(parargs, args))
end

-- Implementation of export.verb_part() and export.verb_part_all().
local function verb_part(parargs, doall)
	local params = {
		[1] = {},
	}
	add_conjugation_args(params, 2)

	local args = require("Module:parameters").process(parargs, params)

	local part = args[1]
	local data, form, weakness, past_vowel, nonpast_vowel =	conjugate(args, 2)
	local arabic, latin = get_spans(data.forms[part])

	if doall then
		return table.concat(arabic, ",")
	else
		return arabic[1]
	end
end

-- Implement {{ar-verb-part}}.
--
-- TODO: Move this into [[Module:ar-headword]]
-- Generate an arbitrary part of the verbal paradigm. If there are multiple
-- possible alternatives, return only the first one.
function export.verb_part(frame)
	return verb_part(frame:getParent().args, false)
end

-- Version of verb_part entry point meant for calling from the debug console.
-- See export.show2().
function export.verb_part2(parargs, args)
	return export.verb_part(debug_frame(parargs, args))
end

-- Implement {{ar-verb-part-all}}.
--
-- TODO: Move this into [[Module:ar-headword]]
-- Generate an arbitrary part of the verbal paradigm. If there are multiple
-- possible alternatives, return all, separated by commas.
function export.verb_part_all(frame)
	return verb_part(frame:getParent().args, true)
end

-- Version of verb_part_all entry point meant for calling from the debug
-- console. See export.show2().
function export.verb_part_all2(parargs, args)
	return export.verb_part_all(debug_frame(parargs, args))
end

-- Return a property of the conjugation other than a verb part.
local function verb_prop(parargs)
	local params = {
		[1] = {},
	}
	add_conjugation_args(params, 2)

	local args = require("Module:parameters").process(parargs, params)

	local prop = args[1]
	local data, form, weakness, past_vowel, nonpast_vowel = conjugate(args, 2)
	if prop == "form" then
		return form
	elseif prop == "weakness" then
		return weakness
	elseif prop == "form-weakness" then
		return form .. "-" .. weakness
	elseif prop == "past-vowel" then
		return table.concat(past_vowel, ",")
	elseif prop == "nonpast-vowel" then
		return table.concat(nonpast_vowel, ",")
	elseif prop == "rad1" then
		return data.rad1 or ""
	elseif prop == "rad2" then
		return data.rad2 or ""
	elseif prop == "rad3" then
		return data.rad3 or ""
	elseif prop == "rad4" then
		return data.rad4 or ""
	elseif prop == "unreg-rad1" then
		return data.unreg_rad1 or ""
	elseif prop == "unreg-rad2" then
		return data.unreg_rad2 or ""
	elseif prop == "unreg-rad3" then
		return data.unreg_rad3 or ""
	elseif prop == "unreg-rad4" then
		return data.unreg_rad4 or ""
	elseif prop == "radicals" then
		return table.concat({data.rad1, data.rad2, data.rad3, data.rad4}, ",")
	elseif prop == "unreg-radicals" then
		return table.concat({data.unreg_rad1, data.unreg_rad2,
		data.unreg_rad3, data.unreg_rad4}, ",")
	elseif prop == "passive" then
		return data.passive == true and "yes" or not data.passive and "no"
			or data.passive
	elseif prop == "passive-uncertain" then
		return data.passive_uncertain and "yes" or "no"
	elseif prop == "vn-uncertain" then
		return data.vn_uncertain and "yes" or "no"
	elseif prop == "irregular" then
		return data.irregular and "yes" or "no"
	--elseif prop == "intrans" then
	--	return data.intrans
	else
		error("Unrecognized property '" .. prop .. "'")
	end
end

-- Return a property of the conjugation other than a verb part.
function export.verb_prop(frame)
	return verb_prop(frame:getParent().args)
end

-- Version of verb_prop entry point meant for calling from the debug console.
-- See export.show2().
function export.verb_prop2(parargs, args)
	return export.verb_prop(debug_frame(parargs, args))
end

function export.verb_forms(frame)
	local parargs = frame:getParent().args
	local params = {
		[1] = {},
		[2] = {},
		[3] = {},
		[4] = {},
		[5] = {},
	}
	for _, form in ipairs(allowed_forms) do
		-- FIXME: We go up to 5 here. The code supports unlimited variants but it's unlikely we will ever see more than
		-- 2.
		for index = 1, 5 do
			local prefix = index == 1 and form or form .. index
			params[prefix .. "-pv"] = {}
			for _, extn in ipairs { "", "-vn", "-ap", "-pp" } do
				params[prefix .. extn] = {}
				params[prefix .. extn .. "-head"] = {}
				-- FIXME: No -tr?
				params[prefix .. extn .. "-gloss"] = {}
			end
		end
	end

	local args = require("Module:parameters").process(parargs, params)

	local i = 1
	local past_vowel_re = "^[aui,]*$"
	local combined_root = nil
	if not args[i] or rfind(args[i], past_vowel_re) then
		combined_root = mw.title.getCurrentTitle().text
		if not rfind(combined_root, " ") then
			error("When inferring roots from page title, need spaces in page title: " .. combined_root)
		end
	elseif rfind(args[i], " ") then
		combined_root = args[i]
		i = i + 1
	else
		local separate_roots = {}
		while args[i] and not rfind(args[i], past_vowel_re) do
			table.insert(separate_roots, args[i])
			i = i + 1
		end
		combined_root = table.concat(separate_roots, " ")
	end
	local past_vowel = args[i]
	i = i + 1
	if past_vowel and not rfind(past_vowel, past_vowel_re) then
		error("Unrecognized past vowel, should be 'a', 'i', 'u', 'a,u', etc. or empty: " .. past_vowel)
	end
	if not past_vowel then
		past_vowel = ""
	end

	local split_root = rsplit(combined_root, " ")
	-- Map from verb forms (I, II, etc.) to a table of verb properties,
	-- which has entries e.g. for "verb" (either true to autogenerate the verb
	-- head, or an explicitly specified verb head using e.g. argument "I-head"),
	-- and for "verb-gloss" (which comes from e.g. the argument "I" or "I-gloss"),
	-- and for "vn" and "vn-gloss", "ap" and "ap-gloss", "pp" and "pp-gloss".
	local verb_properties = {}
	for _, form in ipairs(allowed_forms) do
		local formpropslist = {}
		local derivs = {{"verb", ""}, {"vn", "-vn"}, {"ap", "-ap"}, {"pp", "-pp"}}
		local index = 1
		while true do
			local formprops = {}
			local prefix = index == 1 and form or form .. index
			if prefix == "I" then
				formprops["pv"] = past_vowel
			end
			if args[prefix .. "-pv"] then
				formprops["pv"] = args[prefix .. "-pv"]
			end
			for _, deriv in ipairs(derivs) do
				local prop = deriv[1]
				local extn = deriv[2]
				if args[prefix .. extn] == "+" then
					formprops[prop] = true
				elseif args[prefix .. extn] == "-" then
					formprops[prop] = false
				elseif args[prefix .. extn] then
					formprops[prop] = true
					formprops[prop .. "-gloss"] = args[prefix .. extn]
				end
				if args[prefix .. extn .. "-head"] then
					if formprops[prop] == nil then
						formprops[prop] = true
					end
					formprops[prop] = args[prefix .. extn .. "-head"]
				end
				if args[prefix .. extn .. "-gloss"] then
					if formprops[prop] == nil then
						formprops[prop] = true
					end
					formprops[prop .. "-gloss"] = args[prefix .. extn .. "-gloss"]
				end
			end
			if formprops["verb"] then
				-- If a verb form specified, also turn on vn (unless form I, with
				-- unpredictable vn) and ap, and maybe pp, according to form,
				-- weakness and past vowel. But don't turn these on if there's
				-- an explicit on/off specification for them (e.g. I-pp=-).
				if form ~= "I" and formprops["vn"] == nil then
					formprops["vn"] = true
				end
				if formprops["ap"] == nil then
					formprops["ap"] = true
				end
				local weakness = weakness_from_radicals(form, split_root[1],
					split_root[2], split_root[3], split_root[4])
				if formprops["pp"] == nil and not form_probably_no_passive(form,
						weakness, rsplit(formprops["pv"] or "", ","), {}) then
					formprops["pp"] = true
				end
				table.insert(formpropslist, formprops)
				index = index + 1
			else
				break
			end
		end
		table.insert(verb_properties, {form, formpropslist})
	end

	-- Go through and create the verb form derivations as necessary, when
	-- they haven't been explicitly given
	for _, vplist in ipairs(verb_properties) do
		local form = vplist[1]
		for _, props in ipairs(vplist[2]) do
			local args = {}
			function append_form_and_root()
				table.insert(args, form)
				if form == "I" then
					table.insert(args, props["pv"]) -- past vowel
					table.insert(args, "")
				end
				m_table.extendList(args, split_root)
			end
			if props["verb"] == true then
				args = {}
				append_form_and_root()
				props["verb"] = past3sm(args, true)
			end
			for _, deriv in ipairs({"vn", "ap", "pp"}) do
				if props[deriv] == true then
					args = {deriv}
					append_form_and_root()
					props[deriv] = verb_part(args, true)
				end
			end
		end
	end

    -- Go through and output the result
	local formtextarr = {}
	for _, vplist in ipairs(verb_properties) do
		local form = vplist[1]
		for _, props in ipairs(vplist[2]) do
			local textarr = {}
			if props["verb"] then
				local text = "* '''[[Appendix:Arabic verbs#Form " .. form .. "|Form " .. form .. "]]''': "
				local linktext = {}
				local splitheads = rsplit(props["verb"], "[,،]")
				for _, head in ipairs(splitheads) do
					table.insert(linktext, m_links.full_link({lang = lang, term = head, gloss = props["verb-gloss"]}))
				end
				text = text .. table.concat(linktext, ", ")
				table.insert(textarr, text)
				for _, derivengl in ipairs({{"vn", "Verbal noun"}, {"ap", "Active participle"}, {"pp", "Passive participle"}}) do
					local deriv = derivengl[1]
					local engl = derivengl[2]
					if props[deriv] then
						local text = "** " .. engl .. ": "
						local linktext = {}
						local splitheads = rsplit(props[deriv], "[,،]")
						for _, head in ipairs(splitheads) do
							table.insert(linktext, m_links.full_link({lang = lang, term = head, gloss = props[deriv .. "-gloss"]}))
						end
						text = text .. table.concat(linktext, ", ")
						table.insert(textarr, text)
					end
				end
				table.insert(formtextarr, table.concat(textarr, "\n"))
			end
		end
	end

	return table.concat(formtextarr, "\n")
end

-- Version of verb_forms entry point meant for calling from the debug console.
-- See export.show2().
function export.verb_forms2(parargs, args)
	return export.verb_forms(debug_frame(parargs, args))
end

-- Infer radicals from lemma headword (i.e. 3rd masculine singular past) and form (I, II, etc.). Throw an error if
-- headword is malformed. Returned radicals may contain Latin letters "t", "w" or "y" indicating ambiguous radicals
-- guessed to be tāʾ, wāw or yāʾ respectively.
function export.infer_radicals(headword, form)
	local ch = {}
	-- sub out alif-madda for easier processing
	headword = rsub(headword, AMAD, HAMZA .. ALIF)

	local len = ulen(headword)

	-- extract the headword letters into an array
	for i = 1, len do
		table.insert(ch, usub(headword, i, i))
	end

	-- check that the letter at the given index is the given string, or
	-- is one of the members of the given array
	local function check(index, must)
		local letter = ch[index]
		if type(must) == "string" then
			if letter == nil then
				error("Letter " .. index .. " is nil", 2)
			end
			if letter ~= must then
				error("For form " .. form .. ", letter " .. index ..
					" must be " .. must .. ", not " .. letter, 2)
			end
		elseif not m_table.contains(must, letter) then
			error("For form " .. form .. ", radical " .. index ..
				" must be one of " .. table.concat(must, " ") .. ", not " .. letter, 2)
		end
	end

	-- Check that length of headword is within [min, max]
	local function check_len(min, max)
		if len < min then
			error("Not enough letters in headword " .. headword ..
				" for form " .. form .. ", expected at least " .. min)
		elseif len > max then
			error("Too many letters in headword " .. headword ..
				" for form " .. form .. ", expected at most " .. max)
		end
	end

	local quadlit = rmatch(form, "q$")

	-- find first radical, start of second/third radicals, check for
	-- required letters
	local radstart, rad1, rad2, rad3, rad4
	local weakness
	if form == "I" or form == "II" then
		rad1 = ch[1]
		radstart = 2
	elseif form == "III" then
		rad1 = ch[1]
		check(2, {ALIF, W}) -- W occurs in passive-only verbs
		radstart = 3
	elseif form == "IV" then
		-- this would be alif-madda but we replaced it with hamza-alif above.
		if ch[1] == HAMZA and ch[2] == ALIF then
			rad1 = HAMZA
		else
			check(1, HAMZA_ON_ALIF)
			rad1 = ch[2]
		end
		radstart = 3
	elseif form == "V" then
		check(1, T)
		rad1 = ch[2]
		radstart = 3
	elseif form == "VI" then
		check(1, T)
		if ch[2] == AMAD then
			rad1 = HAMZA
			radstart = 3
		else
			rad1 = ch[2]
			check(3, {ALIF, W}) -- W occurs in passive-only verbs
			radstart = 4
		end
	elseif form == "VII" then
		check(1, ALIF)
		check(2, N)
		rad1 = ch[3]
		radstart = 4
	elseif form == "VIII" then
		check(1, ALIF)
		rad1 = ch[2]
		if rad1 == T or rad1 == "د" or rad1 == "ث" or rad1 == "ذ" or rad1 == "ط" or rad1 == "ظ" then
			radstart = 3
		elseif rad1 == "ز" then
			check(3, "د")
			radstart = 4
		elseif rad1 == "ص" or rad1 == "ض"  then
			check(3, "ط")
			radstart = 4
		else
			check(3, T)
			radstart = 4
		end
		if rad1 == T then
			-- radical is ambiguous, might be ت or و or ي but doesn't affect
			-- conjugation
			rad1 = "t"
		end
	elseif form == "IX" then
		check(1, ALIF)
		rad1 = ch[2]
		radstart = 3
	elseif form == "X" then
		check(1, ALIF)
		check(2, S)
		check(3, T)
		rad1 = ch[4]
		radstart = 5
	elseif form == "Iq" then
		rad1 = ch[1]
		rad2 = ch[2]
		radstart = 3
	elseif form == "IIq" then
		check(1, T)
		rad1 = ch[2]
		rad2 = ch[3]
		radstart = 4
	elseif form == "IIIq" then
		check(1, ALIF)
		rad1 = ch[2]
		rad2 = ch[3]
		check(4, N)
		radstart = 5
	elseif form == "IVq" then
		check(1, ALIF)
		rad1 = ch[2]
		rad2 = ch[3]
		radstart = 4
	elseif form == "XI" then
		check_len(5, 5)
		check(1, ALIF)
		rad1 = ch[2]
		rad2 = ch[3]
		check(4, ALIF)
		rad3 = ch[5]
		weakness = "sound"
	elseif form == "XII" then
		check(1, ALIF)
		rad1 = ch[2]
		if ch[3] ~= ch[5] then
			error("For form XII, letters 3 and 5 of headword " .. headword ..
				" should be the same")
		end
		check(4, W)
		radstart = 5
	elseif form == "XIII" then
		check_len(5, 5)
		check(1, ALIF)
		rad1 = ch[2]
		rad2 = ch[3]
		check(4, W)
		rad3 = ch[5]
		if rad3 == AMAQ then
			weakness = "final-weak"
		else
			weakness = "sound"
		end
	elseif form == "XIV" then
		check_len(6, 6)
		check(1, ALIF)
		rad1 = ch[2]
		rad2 = ch[3]
		check(4, N)
		rad3 = ch[5]
		if ch[6] == AMAQ then
			check_waw_ya(rad3)
			weakness = "final-weak"
		else
			if ch[5] ~= ch[6] then
				error("For form XIV, letters 5 and 6 of headword " .. headword ..
					" should be the same")
			end
			weakness = "sound"
		end
	elseif form == "XV" then
		check_len(6, 6)
		check(1, ALIF)
		rad1 = ch[2]
		rad2 = ch[3]
		check(4, N)
		rad3 = ch[5]
		if rad3 == Y then
			check(6, ALIF)
		else
			check(6, AMAQ)
		end
		weakness = "sound"
	else
		error("Don't recognize form " .. form)
	end

	-- Process the last two radicals. RADSTART is the index of the
	-- first of the two. If it's nil then all radicals have already been
	-- processed above, and we don't do anything.
	if radstart ~= nil then
		-- there must be one or two letters left
		check_len(radstart, radstart + 1)
		if len == radstart then
			-- if one letter left, then it's a geminate verb
			if form_supports_geminate(form) then
				weakness = "geminate"
				rad2 = ch[len]
				rad3 = ch[len]
			else
				-- oops, geminate verbs not allowed in this form; signal
				-- an error
				check_len(radstart + 1, radstart + 1)
			end
		elseif quadlit then
			-- process last two radicals of a quadriliteral form
			rad3 = ch[radstart]
			rad4 = ch[radstart + 1]
			if rad4 == AMAQ or rad4 == ALIF and rad3 == Y or rad4 == Y then
				-- rad4 can be Y in passive-only verbs
				if form_supports_final_weak(form) then
					weakness = "final-weak"
					-- ambiguous radical; randomly pick wāw as radical (but avoid
					-- two wāws in a row); it could be wāw or yāʾ, but doesn't
					-- affect the conjugation
					rad4 = rad3 == W and "y" or "w"
				else
					error("For headword " .. headword ..
						", last radical is " .. rad4 .. " but form " .. form ..
						" doesn't support final-weak verbs")
				end
			else
				weakness = "sound"
			end
		else
			-- process last two radicals of a triliteral form
			rad2 = ch[radstart]
			rad3 = ch[radstart + 1]
			if form == "I" and (is_waw_ya(rad3) or rad3 == ALIF or rad3 == AMAQ) then
				-- check for final-weak form I verb. It can end in tall alif
				-- (rad3 = wāw) or alif maqṣūra (rad3 = yāʾ) or a wāw or yāʾ
				-- (with a past vowel of i or u, e.g. nasiya/yansā "forget"
				-- or with a passive-only verb).
				if rad1 == W then
					weakness = "assimilated+final-weak"
				else
					weakness = "final-weak"
				end
				if rad3 == ALIF then
					rad3 = W
				elseif rad3 == AMAQ then
					rad3 = Y
				else
					-- ambiguous radical; randomly pick wāw as radical (but
					-- avoid two wāws); it could be wāw or yāʾ, but doesn't
					-- affect the conjugation
					rad3 = (rad1 == W or rad2 == W) and "y" or "w" -- ambiguous
				end
		elseif rad3 == AMAQ or rad2 == Y and rad3 == ALIF or rad3 == Y then
				-- rad3 == Y happens in passive-only verbs
				if form_supports_final_weak(form) then
					weakness = "final-weak"
				else
					error("For headword " .. headword ..
						", last radical is " .. rad3 .. " but form " .. form ..
						" doesn't support final-weak verbs")
				end
				-- ambiguous radical; randomly pick wāw as radical (but avoid
				-- two wāws); it could be wāw or yāʾ, but doesn't affect the
				-- conjugation
				rad3 = (rad1 == W or rad2 == W) and "y" or "w"
			elseif rad2 == ALIF then
				if form_supports_hollow(form) then
					weakness = "hollow"
					-- ambiguous radical; could be wāw or yāʾ; if form I,
					-- it's critical to get this right, and the caller checks
					-- for this situation, attempts to infer radical from
					-- non-past vowel, and if that fails, signals an error
					rad2 = "w"
				else
					error("For headword " .. headword ..
						", second radical is alif but form " .. form ..
						" doesn't support hollow verbs")
				end
			elseif form == "I" and rad1 == W then
				weakness = "assimilated"
			elseif rad2 == rad3 and (form == "III" or form == "VI") then
				weakness = "geminate"
			else
				weakness = "sound"
			end
		end
	end

	-- convert radicals to canonical form (handle various hamza varieties and
	-- check for misplaced alif or alif maqṣūra; legitimate cases of these
	-- letters are handled above)
	local function convert(rad, index)
		if rad == HAMZA_ON_ALIF or rad == HAMZA_UNDER_ALIF or
			rad == HAMZA_ON_W or rad == HAMZA_ON_Y then
			return HAMZA
		elseif rad == AMAQ then
			error("For form " .. form .. ", headword " .. headword ..
				", radical " .. index .. " must not be alif maqṣūra")
		elseif rad == ALIF then
			error("For form " .. form .. ", headword " .. headword ..
				", radical " .. index .. " must not be alif")
		else
			return rad
		end
	end
	rad1 = convert(rad1, 1)
	rad2 = convert(rad2, 2)
	rad3 = convert(rad3, 3)
	rad4 = convert(rad4, 4)

	return weakness, rad1, rad2, rad3, rad4
end

-- Infer vocalization from participle headword (active or passive), form (I, II, etc.) and whether the headword is
-- active or passive. Throw an error if headword is malformed. Returned radicals may contain Latin letters "t", "w" or "y"
-- indicating ambiguous radicals guessed to be tāʾ, wāw or yāʾ respectively.
function export.infer_participle_vocalization(headword, form, weakness, is_active)
	local ch = {}
	local orig_headword = headword
	-- sub out alif-madda for easier processing
	headword = rsub(headword, AMAD, HAMZA .. ALIF)

	local len = ulen(headword)

	-- extract the headword letters into an array
	for i = 1, len do
		table.insert(ch, usub(headword, i, i))
	end

	local function form_intro_error_msg()
		return ("For form %s %s%s participle %s, "):format(form, orig_headword ~= headword and "normalized " or "",
			is_active and "active" or "passive", headword)
	end

	local function err(msg)
		error(form_intro_error_msg() .. msg, 1)
	end

	-- check that the letter at the given index is the given string, or is one of the members of the given array
	local function check(index, must)
		local letter = ch[index]
		local function make_possible_values()
			if type(must) == "string" then
				return must
			else
				return m_table.serialCommaJoin(must, {conj = "or"})
			end
		end
		if letter == nil then
			err(("expected a letter (specifically %s) at position %s, but participle is too short"):format(
				make_possible_values(), index))
		end
		local matches
		if type(must) == "string" then
			matches = letter == must
		else
			matches = m_table.contains(must, letter)
		end
		if not matches then
			err(("letter %s at index %s must be %s"):format(letter, index, make_possible_values()))
		end
	end

	-- Check that length of headword is within [min, max]
	local function check_len(min, max)
		if len < min then
			err(("expected at least %s letters but saw %s"):format(min, len))
		elseif len > max then
			err(("expected at most %s letters but saw %s"):format(max, len))
		end
	end

	local function check_weakness(values, allow_missing, invert_condition)
		local function make_possible_weaknesses()
			for i, val in ipairs(values) do
				values[i] = "'" .. val .. "'"
			end
			return m_table.serialCommaJoin(values, {conj = "or"})
		end
		if allow_missing and invert_condition then
			error("Internal error: Can't specify both allow_missing and invert_condition")
		end
		if not weakness then
			if allow_missing or invert_condition then
				return
			else
				err(("weakness is unspecified but must be %s"):format(make_possible_weaknesses()))
			end
		else
			local matches = m_table.contains(values, weakness)
			if invert_condition and matches then
				err(("weakness '%s' must not be %s"):format(weakness, make_possible_weaknesses()))
			elseif not invert_condition and not matches then
				err(("weakness '%s' must be %s"):format(weakness, make_possible_weaknesses()))
			end
		end
	end

	local quadlit = rmatch(form, "q$")

	local vocalized

	local function handle_possibly_final_weak(sound_prefix, expected_length)
		check_len(expected_length, expected_length)
		if ch[expected_length] == AMAQ then
			-- passive final-weak
			if is_active then
				err("participle in -ِى only allowed for passive participles")
			end
			check_weakness({"final-weak", "assimilated+final-weak"}, "allow missing")
			vocalized = sound_prefix .. AN .. AMAQ
		else
			-- all others behave as if sound
			check_weakness({"final-weak", "assimilated+final-weak"}, nil, "invert condition")
			vocalized = sound_prefix .. (is_active and I or A) .. ch[expected_length]
		end
	end

	if not (form == "I" and is_active) then
		-- all participles except form I active begin in م-.
		check(1, M)
	end
	if form == "I" then
		if is_active then
			check(2, ALIF)
			local sound_prefix = ch[1] .. AA .. ch[3]
			if len == 3 then
				if ch[3] == HAMZA then
					-- Either hollow with hamzated third radical, e.g. [[شاء]] active participle 'شَاءٍ', or final-weak
					-- with hamzated second radical, e.g. [[رأى]] active participle 'رَاءٍ'. Theoretically (?), also
					-- geminate with hamzated second/third radical, but I don't know if any such verbs exist.
					if weakness == "geminate" then
						vocalized = sound_prefix .. SH
					else
						check_weakness({"hollow", "final-weak"}, "allow missing")
						vocalized = sound_prefix .. IN
					end
				else
					check_weakness({"final-weak", "geminate"})
					if weakness == "geminate" then
						vocalized = sound_prefix .. SH
					else
						vocalized = sound_prefix .. IN
					end
				end
			else
				check_len(4, 4)
				-- we will convert back to alif maqṣūra below as needed
				vocalized = sound_prefix .. I .. ch[4]
			end
		else
			-- assimilated verbs: regular, e.g. مَوْزُون "weighed"
			-- geminate verbs: regular, e.g. مَبْلُول "moistened"
			-- third-hamzated verbs: مَبْرُوء
			-- hollow verbs: مَقُود "led, driven"; مَزِيد "added, increased"
			-- hollow first-hamzated verbs: مَئِيض "returned, reverted"; مَأْيُوس "despaired" (NOTE: formation is sound);
			--   مَأُود or مَؤُود "bent; depleted"
			-- hollow third-hamzated verbs: مَشِيء "willed, intended", مَضُوء "glittered?"
			-- final-weak: مَلْقِيّ "found, encountered"; مَصْغُوّ "inclined"
			-- hollow + final-weak: مَشْوِيّ "fried, grilled", مَهْوِيّ "loved"
			-- first-hamzated + hollow + final-weak: مَأْوِيّ "received hospitably"
			local sound_prefix = MA .. ch[2] .. SK .. ch[3]
			if len == 5 then
				-- sound, assimilated or geminate
				check(4, W)
				vocalized = sound_prefix .. UU .. ch[5]
			else
				check_len(4, 4)
				if ch[4] == W then
					-- final-weak third-wāw
					vocalized = sound_prefix .. U .. W .. SK
				elseif ch[4] == Y then
					-- final-weak third-yāʾ
					vocalized = sound_prefix .. I .. Y .. SK
				else
					-- hollow
					check(3, {W, Y})
					if ch[3] == W then
						vocalized = MA .. ch[2] .. UU .. ch[4]
					else
						vocalized = MA .. ch[2] .. II .. ch[4]
					end
				end
			end
		end
	elseif form == "II" or form == "V" then
		local sound_prefix, expected_length
		if form == "V" then
			check(2, T)
			sound_prefix = MU .. T .. A .. ch[3] .. A .. ch[4] .. SH
			expected_length = 5
		else
			sound_prefix = MU .. ch[2] .. A .. ch[3] .. SH
			expected_length = 4
		end
		if len == expected_length - 1 then
			-- active final-weak
			if not is_active then
				err(("length-%s participle only allowed for active participles"):format(len))
			end
			check_weakness({"final-weak", "assimilated+final-weak"}, "allow missing")
			vocalized = sound_prefix .. IN
		else
			handle_possibly_final_weak(sound_prefix, expected_length)
		end
	elseif form == "III" or form == "VI" then
		local sound_prefix, expected_length
		if form == "VI" then
			check(2, T)
			check(4, ALIF)
			sound_prefix = MU .. T .. A .. ch[3] .. AA .. ch[5]
			expected_length = 6
		else
			sound_prefix = MU .. ch[2] .. AA .. ch[4]
			expected_length = 5
		end
		if len == expected_length - 1 then
			-- active final-weak or active or passive geminate
			if is_active then
				check_weakness({"geminate", "final-weak", "assimilated+final-weak"})
				if weakness == "geminate" then
					vocalized = sound_prefix .. SH
				else
					vocalized = sound_prefix .. IN
				end
			else
				check_weakness({"geminate"}, "allow missing")
				vocalized = sound_prefix .. SH
			end
		else
			handle_possibly_final_weak(sound_prefix, expected_length)
		end
	elseif form == "IV" or form == "X" then
		-- form IV:
		-- sound: مُرْسِخ (active, "entrenching"), مُرْسَخ (passive, "entrenched")
		-- first-hamzated (like sound): مُؤْيِس (active, "causing to despair"), مُؤْيَس (passive, "caused to despair")
		-- final-weak: مُكْرٍ (active, "renting out"), مُكْرًى (passive, "rented out")
		-- assimilated: مُورِد (active, "transferring"), مُورَد (passive, "transferred"); same when first-Y, e.g.
		--   أَيْقَنَ "to be certain of": مُوقِن (active), مُوقَن (passive)
		-- assimilated + final-weak: مُورٍ (active, "setting fire, kindling"), مُورًى (passive, "set fire, kindled")
		-- geminate: مُمِدّ (active, "granting, helping"), مُمَدّ (passive, "granted, helped")
		-- hollow: مُزِيل (active, "eliminating"), مُزَال (passive, "eliminated")
		-- hollow + final-weak: مُعْيٍ (active, "tiring"), مُعْيًى (passive, "tired")
		local sound_prefix, expected_length
		if form == "X" then
			check(2, S)
			check(3, T)
			sound_prefix = MU .. S .. SK .. T .. A .. ch[4]
			expected_length = 6
		else
			sound_prefix = MU .. ch[2]
			expected_length = 4
		end

		if len == expected_length and ch[len - 1] == Y and ch[len] ~= AMAQ then
			-- active hollow
			if not is_active then
				err("this shape only allowed for active participles")
			end
			check_weakness({"hollow"}, "allow missing")
			vocalized = sound_prefix .. II .. ch[len]
		elseif len == expected_length and ch[len - 1] == ALIF then
			-- passive hollow
			if not is_passive then
				err("this shape only allowed for passive participles")
			end
			check_weakness({"hollow"}, "allow missing")
			vocalized = sound_prefix .. AA .. ch[len]
		elseif len == expected_length - 1 then
			-- active final-weak or active or passive geminate
			if is_active then
				check_weakness({"geminate", "final-weak", "assimilated+final-weak"})
				if weakness == "geminate" then
					vocalized = sound_prefix .. I .. ch[len] .. SH
				elseif form == "IV" and ch[2] == W then
					-- assimilated final-weak
					vocalized = sound_prefix .. ch[len] .. IN
				else
					vocalized = sound_prefix .. SK .. ch[len] .. IN
				end
			else
				check_weakness({"geminate"}, "allow missing")
				vocalized = sound_prefix .. A .. ch[len] .. SH
			end
		else
			if form == "IV" and ch[2] == W then
				-- assimilated, possibly final-weak
				sound_prefix = sound_prefix .. ch[len - 1]
			else
				sound_prefix = sound_prefix .. SK .. ch[len - 1]
			end
			handle_possibly_final_weak(sound_prefix, expected_length)
		end
	elseif form == "VII" or form == "VIII" then
		-- form VII (passive participles are fairly rare but do exist):
		-- sound: مُنْكَتِب (active "subscribing"), مُنْكَتَب (passive "subscribed")
		-- geminate: مُنْضَمّ (both active "joining, containing" and passive "joined, contained")
		-- final-weak: مُنْطَلٍ (active "fooling (someone)"), مُنْطَلًى (passive "fooled")
		-- final-weak with medial wāw: مُنْطَوٍ (active "involving"), مُنْطَوًى (passive "involved")
		-- hollow: مُنْقَاد (both active "complying with" and passive "complied with")
		--
		-- for form VIII, the same variants exist but things are complicated by assimilations involving the template T.
		-- sound third-hamzated no assimilation: مُبْتَدِئ (active "beginning"), مُبْتَدَأ (passive "begun")
		-- geminate no assimilation: مُبْتَزّ (both active "robbing" and passive "robbed")
		-- final-weak no assimilation: مُبْتَنٍ (active "building"), مُبْتَنًى (passive "built")
		-- final-weak with medial wāw no assimilation: مُحْتَوٍ (active "containing"), مُحْتَوًى (passive "contained")
		-- hollow no assimilation: مُخْتَار (both active "choosing" and passive "chosen")
		--
		-- sound with total assimilation: مُتَّبِع (active "following"), مُتَّبَع (passive "followed")
		-- sound with total assimilation, assimilating wāw: مُتَّعِد (active "threatening"), مُتَّعَد (passive "threatened")
		-- sound with total assimilation, irregularly assimilating hamza: مُتَّخِذ (active "taking"), مُتَّخَذ (passive "taken")
		-- sound with total assimilation (to ḏāl, producing dāl): مُدَّخِر (active "reserving"), مُدَّخَر (passive "reserved")
		-- sound with total assimilation (to ḏāl): مُذَّكِر (active "remembering"), مُذَّكَر (passive "remembered")
		-- sound with total assimilation (to ṭāʔ): مُطَّرِح (active "discarding"), مُطَّرَح (passive "discarded")
		-- sound with total assimilation (to ẓāʔ): مُظَّلِم (active "tolerating"), مُظَّلَم (passive "tolerated")
		-- final-weak with total assimilation, assimilating wāw: مُتَّقٍ (active "guarding against"), مُتَّقًى (passive "guarded against")
		-- final-weak with total assimilation (to ṯāʔ): مُثَّنٍ (active "undulating"), مُثَّنًى (passive "undulated")
		-- final-weak with total assimilation (to dāl): مُدَّعٍ (active "claiming"), مُدَّعًى (passive "claimed")
		-- sound with partial assimilation (to zayn): مُزْدَهِر (active "thriving"), مُزْدَهَر (passive "thrived")
		-- sound with medial wāw with partial assimilation (to zayn): مُزْدَوِج (active "appearing twice")
		-- sound with partial assimilation (to ṣād): مُصْطَبِح (active "illuminating"), مُصْطَبَح (passive, "illuminated")
		-- sound with partial assimilation (to ḍād): مُضْطَرِب (active "to be disturbed"; no passive)
		-- geminate with partial assimilation (to ṣād): مُصْطَبّ (both active "effusing" and passive "effused")
		-- geminate with partial assimilation (to ḍād): مُضْطَرّ (both active "forcing" and passive "forced")
		-- final-weak with partial assimilation (to ṣād): مُصْطَلٍ (active "warming"), مُصْطَلًى (passive "warmed")
		-- hollow with partial assimilation (to zayn): مُزْدَاد (both active "increasing" and passive "increased")
		-- hollow with partial assimilation (to ṣad): مُصْطَاد (both active "hunting" and passive "hunted")

		local sound_prefix, expected_length
		if form == "X" then
			check(2, S)
			check(3, T)
			sound_prefix = MU .. S .. SK .. T .. A .. ch[4]
			expected_length = 6
		else
			sound_prefix = MU .. ch[2]
			expected_length = 4
		end

		if len == expected_length and ch[len - 1] == Y and ch[len] ~= AMAQ then
			-- active hollow
			if not is_active then
				err("this shape only allowed for active participles")
			end
			check_weakness({"hollow"}, "allow missing")
			vocalized = sound_prefix .. II .. ch[len]
		elseif len == expected_length and ch[len - 1] == ALIF then
			-- passive hollow
			if not is_passive then
				err("this shape only allowed for passive participles")
			end
			check_weakness({"hollow"}, "allow missing")
			vocalized = sound_prefix .. AA .. ch[len]
		elseif len == expected_length - 1 then
			-- active final-weak or active or passive geminate
			if is_active then
				check_weakness({"geminate", "final-weak", "assimilated+final-weak"})
				if weakness == "geminate" then
					vocalized = sound_prefix .. I .. ch[len] .. SH
				elseif form == "IV" and ch[2] == W then
					-- assimilated final-weak
					vocalized = sound_prefix .. ch[len] .. IN
				else
					vocalized = sound_prefix .. SK .. ch[len] .. IN
				end
			else
				check_weakness({"geminate"}, "allow missing")
				vocalized = sound_prefix .. A .. ch[len] .. SH
			end
		else
			if form == "IV" and ch[2] == W then
				-- assimilated, possibly final-weak
				sound_prefix = sound_prefix .. ch[len - 1]
			else
				sound_prefix = sound_prefix .. SK .. ch[len - 1]
			end
			handle_possibly_final_weak(sound_prefix, expected_length)
		end
		-- this would be alif-madda but we replaced it with hamza-alif above.
		if ch[1] == HAMZA and ch[2] == ALIF then
			rad1 = HAMZA
		else
			check(1, HAMZA_ON_ALIF)
			rad1 = ch[2]
		end
		radstart = 3
	elseif form == "V" then
		check(1, T)
		rad1 = ch[2]
		radstart = 3
	elseif form == "VI" then
		check(1, T)
		if ch[2] == AMAD then
			rad1 = HAMZA
			radstart = 3
		else
			rad1 = ch[2]
			check(3, {ALIF, W}) -- W occurs in passive-only verbs
			radstart = 4
		end
	elseif form == "VII" then
		check(1, ALIF)
		check(2, N)
		rad1 = ch[3]
		radstart = 4
	elseif form == "VIII" then
		check(1, ALIF)
		rad1 = ch[2]
		if rad1 == T or rad1 == "د" or rad1 == "ث" or rad1 == "ذ" or rad1 == "ط" or rad1 == "ظ" then
			radstart = 3
		elseif rad1 == "ز" then
			check(3, "د")
			radstart = 4
		elseif rad1 == "ص" or rad1 == "ض"  then
			check(3, "ط")
			radstart = 4
		else
			check(3, T)
			radstart = 4
		end
		if rad1 == T then
			-- radical is ambiguous, might be ت or و or ي but doesn't affect
			-- conjugation
			rad1 = "t"
		end
	elseif form == "IX" then
		check(1, ALIF)
		rad1 = ch[2]
		radstart = 3
	elseif form == "X" then
		check(1, ALIF)
		check(2, S)
		check(3, T)
		rad1 = ch[4]
		radstart = 5
	elseif form == "Iq" then
		rad1 = ch[1]
		rad2 = ch[2]
		radstart = 3
	elseif form == "IIq" then
		check(1, T)
		rad1 = ch[2]
		rad2 = ch[3]
		radstart = 4
	elseif form == "IIIq" then
		check(1, ALIF)
		rad1 = ch[2]
		rad2 = ch[3]
		check(4, N)
		radstart = 5
	elseif form == "IVq" then
		check(1, ALIF)
		rad1 = ch[2]
		rad2 = ch[3]
		radstart = 4
	elseif form == "XI" then
		check_len(5, 5)
		check(1, ALIF)
		rad1 = ch[2]
		rad2 = ch[3]
		check(4, ALIF)
		rad3 = ch[5]
		weakness = "sound"
	elseif form == "XII" then
		check(1, ALIF)
		rad1 = ch[2]
		if ch[3] ~= ch[5] then
			error("For form XII, letters 3 and 5 of headword " .. headword ..
				" should be the same")
		end
		check(4, W)
		radstart = 5
	elseif form == "XIII" then
		check_len(5, 5)
		check(1, ALIF)
		rad1 = ch[2]
		rad2 = ch[3]
		check(4, W)
		rad3 = ch[5]
		if rad3 == AMAQ then
			weakness = "final-weak"
		else
			weakness = "sound"
		end
	elseif form == "XIV" then
		check_len(6, 6)
		check(1, ALIF)
		rad1 = ch[2]
		rad2 = ch[3]
		check(4, N)
		rad3 = ch[5]
		if ch[6] == AMAQ then
			check_waw_ya(rad3)
			weakness = "final-weak"
		else
			if ch[5] ~= ch[6] then
				error("For form XIV, letters 5 and 6 of headword " .. headword ..
					" should be the same")
			end
			weakness = "sound"
		end
	elseif form == "XV" then
		check_len(6, 6)
		check(1, ALIF)
		rad1 = ch[2]
		rad2 = ch[3]
		check(4, N)
		rad3 = ch[5]
		if rad3 == Y then
			check(6, ALIF)
		else
			check(6, AMAQ)
		end
		weakness = "sound"
	else
		error("Don't recognize form " .. form)
	end

	-- Process the last two radicals. RADSTART is the index of the
	-- first of the two. If it's nil then all radicals have already been
	-- processed above, and we don't do anything.
	if radstart ~= nil then
		-- there must be one or two letters left
		check_len(radstart, radstart + 1)
		if len == radstart then
			-- if one letter left, then it's a geminate verb
			if form_supports_geminate(form) then
				weakness = "geminate"
				rad2 = ch[len]
				rad3 = ch[len]
			else
				-- oops, geminate verbs not allowed in this form; signal
				-- an error
				check_len(radstart + 1, radstart + 1)
			end
		elseif quadlit then
			-- process last two radicals of a quadriliteral form
			rad3 = ch[radstart]
			rad4 = ch[radstart + 1]
			if rad4 == AMAQ or rad4 == ALIF and rad3 == Y or rad4 == Y then
				-- rad4 can be Y in passive-only verbs
				if form_supports_final_weak(form) then
					weakness = "final-weak"
					-- ambiguous radical; randomly pick wāw as radical (but avoid
					-- two wāws in a row); it could be wāw or yāʾ, but doesn't
					-- affect the conjugation
					rad4 = rad3 == W and "y" or "w"
				else
					error("For headword " .. headword ..
						", last radical is " .. rad4 .. " but form " .. form ..
						" doesn't support final-weak verbs")
				end
			else
				weakness = "sound"
			end
		else
			-- process last two radicals of a triliteral form
			rad2 = ch[radstart]
			rad3 = ch[radstart + 1]
			if form == "I" and (is_waw_ya(rad3) or rad3 == ALIF or rad3 == AMAQ) then
				-- check for final-weak form I verb. It can end in tall alif
				-- (rad3 = wāw) or alif maqṣūra (rad3 = yāʾ) or a wāw or yāʾ
				-- (with a past vowel of i or u, e.g. nasiya/yansā "forget"
				-- or with a passive-only verb).
				if rad1 == W then
					weakness = "assimilated+final-weak"
				else
					weakness = "final-weak"
				end
				if rad3 == ALIF then
					rad3 = W
				elseif rad3 == AMAQ then
					rad3 = Y
				else
					-- ambiguous radical; randomly pick wāw as radical (but
					-- avoid two wāws); it could be wāw or yāʾ, but doesn't
					-- affect the conjugation
					rad3 = (rad1 == W or rad2 == W) and "y" or "w" -- ambiguous
				end
		elseif rad3 == AMAQ or rad2 == Y and rad3 == ALIF or rad3 == Y then
				-- rad3 == Y happens in passive-only verbs
				if form_supports_final_weak(form) then
					weakness = "final-weak"
				else
					error("For headword " .. headword ..
						", last radical is " .. rad3 .. " but form " .. form ..
						" doesn't support final-weak verbs")
				end
				-- ambiguous radical; randomly pick wāw as radical (but avoid
				-- two wāws); it could be wāw or yāʾ, but doesn't affect the
				-- conjugation
				rad3 = (rad1 == W or rad2 == W) and "y" or "w"
			elseif rad2 == ALIF then
				if form_supports_hollow(form) then
					weakness = "hollow"
					-- ambiguous radical; could be wāw or yāʾ; if form I,
					-- it's critical to get this right, and the caller checks
					-- for this situation, attempts to infer radical from
					-- non-past vowel, and if that fails, signals an error
					rad2 = "w"
				else
					error("For headword " .. headword ..
						", second radical is alif but form " .. form ..
						" doesn't support hollow verbs")
				end
			elseif form == "I" and rad1 == W then
				weakness = "assimilated"
			elseif rad2 == rad3 and (form == "III" or form == "VI") then
				weakness = "geminate"
			else
				weakness = "sound"
			end
		end
	end

	-- convert radicals to canonical form (handle various hamza varieties and
	-- check for misplaced alif or alif maqṣūra; legitimate cases of these
	-- letters are handled above)
	local function convert(rad, index)
		if rad == HAMZA_ON_ALIF or rad == HAMZA_UNDER_ALIF or
			rad == HAMZA_ON_W or rad == HAMZA_ON_Y then
			return HAMZA
		elseif rad == AMAQ then
			error("For form " .. form .. ", headword " .. headword ..
				", radical " .. index .. " must not be alif maqṣūra")
		elseif rad == ALIF then
			error("For form " .. form .. ", headword " .. headword ..
				", radical " .. index .. " must not be alif")
		else
			return rad
		end
	end
	rad1 = convert(rad1, 1)
	rad2 = convert(rad2, 2)
	rad3 = convert(rad3, 3)
	rad4 = convert(rad4, 4)

	return weakness, rad1, rad2, rad3, rad4
	error("Not implemented yet")
end

return export
