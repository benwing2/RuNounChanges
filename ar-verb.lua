--[=[

This module implements {{ar-conj}} and provides the underlying conjugation functions for {{ar-verb}}
(whose actual formatting is done in [[Module:ar-headword]]).

Author: User:Benwing, from an early version (2013-2014) by User:Atitarev, User:ZxxZxxZ.

]=]

local export = {}
local int = {}

--[=[

TERMINOLOGY:

-- "slot" = A particular combination of tense/mood/person/number/etc.
	 Example slot names for verbs are "past_1s" (past tense first-person singular), "juss_pass_3fp" (non-past jussive
	 passive third-person feminine plural) "ap" (active participle). Each slot is filled with zero or more forms.

-- "form" = The conjugated Arabic form representing the value of a given slot.

-- "lemma" = The dictionary form of a given Arabic term. For Arabic, normally the third person masculine singular past,
	 although other forms may be used if this form is missing (e.g. in passive-only verbs or verbs lacking the past).
]=]

--[=[

FIXME:

1. Finish unimplemented conjugation types. Only IX-final-weak left (extremely rare, possibly only one verb اِعْمَايَ
   (according to Haywood and Nahmad p. 244, who are very specific about the irregular occurrence of alif + yā instead
   of expected اِعْمَيَّ with doubled yā). Not in Hans Wehr.

2. Implement irregular verbs as special cases and recognize them, e.g.
   -- laysa "to not be"; only exists in the past tense, no non-past, no imperative, no participles, no passive, no
      verbal noun. Irregular alternation las-/lays-.
   -- istaḥā yastaḥī "be ashamed of" -- this is complex according to Hans Wehr because there are two verbs, regular
      istaḥyā yastaḥyī "to spare (someone)'s life" and irregular istaḥyā yastaḥyī "to be ashamed to face (someone)",
	  which is irregular because it has the alternate irregular form istaḥā yastaḥī which only applies to this meaning.
	  Currently we follow Haywood and Nahmad in saying that both varieties can be spelled istaḥyā/istaḥā/istaḥḥā, but we
	  should instead use a variant= param similar to حَيَّ to distinguish the two possibilities, and maybe not include
	  istaḥḥā.
   -- ʿayya/ʿayiya yaʿayyu/yaʿyā "to not find the right way, be incapable of, stammer, falter, fall ill". This appears
      to be a mixture of a geminate and final-weak verb. Unclear what the whole paradigm looks like. Do the
      consonant-ending parts in the past follow the final-weak paradigm? Is it the same in the non-past? Or can you
      conjugate the non-past fully as either geminate or final-weak?
   -- اِنْمَحَى inmaḥā or يمَّحَى immaḥā "to be effaced, obliterated; to disappear, vanish" has irregular assimilation of inm-
      to imm- as an alternative. inmalasa "to become smooth; to glide; to slip away; to escape" also has immalasa as an
	  alternative. The only other form VII verbs in Hans Wehr beginning with -m- are inmalaḵa "to be pulled out, torn
	  out, wrenched" and inmāʿa "to be melted, to melt, to dissolve", which are not listed with imm- alternatives, but
	  might have them; if so, we should handle this generally.
   -- يَرَعَ yaraʕa yariʕu "to be a coward, to be chickenhearted" as an alternative form of يَرِعَ yariʕa yayraʕu (as given in
      Wehr).
3. Implement individual override parameters for each paradigm part. See Module:fro-verb for an example of how to do this
   generally. Note that {{temp|ar-conj-I}} and other of the older templates already had such individual override params.
   [DONE]

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

--]=]

local export = {}

local force_cat = false -- set to true for debugging
local check_for_red_links = false -- set to false for debugging

local lang = require("Module:languages").getByCode("ar")

local m_links = require("Module:links")
local m_string_utilities = require("Module:string utilities")
local m_table = require("Module:User:Benwing2/table")
local ar_utilities = require("Module:ar-utilities")
local ar_nominals = require("Module:ar-nominals")
local iut = require("Module:User:Benwing2/inflection utilities")
local parse_utilities_module = "Module:parse utilities"
local pron_qualifier_module = "Module:pron qualifier"

local rfind = m_string_utilities.find
local rsubn = m_string_utilities.gsub
local rmatch = m_string_utilities.match
local rsplit = m_string_utilities.split
local usub = m_string_utilities.sub
local ulen = m_string_utilities.len
local u = m_string_utilities.char

local dump = mw.dumpObject

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

local BAD = u(0xFFF1)
local BORDER = u(0xFFF2)

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

-- translit_patterns
local V = "aeiouāēīōū"
local NV = "[^" .. V .. "]"

local dia = {a = A, i = I, u = U}
local undia = {[A] = "a", [I] = "i", [U] = "u"}

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
local TA    = T .. A
local TU    = T .. U
local _I    = ALIF .. I
local _U    = ALIF .. U

local translit_cache = {
	-- hamza variants
	[HAMZA] = "ʔ",
	[HAMZA_ON_ALIF] = "ʔ",
	[HAMZA_ON_W] = "ʔ",
	[HAMZA_UNDER_ALIF] = "ʔ",
	[HAMZA_ON_Y] = "ʔ",
	[HAMZA_PH] = "ʔ",

	-- diacritics
	[A] = "a",
	[AN] = "an",
	[U] = "u",
	[UN] = "un",
	[I] = "i",
	[IN] = "in",
	[SK] = "",
	[SH] = "*", -- handled specially
	[DAGGER_ALIF] = "ā",
	[UNS] = no_nominal_i3rab and "" or "un",

	-- various letters and signs
	[""] = "",
	[ALIF] = BAD, -- we should never be transliterating ALIF by itself, as its translit in isolation is ambiguous
	[AMAQ] = BAD,
	[AMAD] = "ʔā",
	[TAM] = "",
	[T] = "t",
	[N] = "n",
	[W] = "w",
	[Y] = "y",
	[S] = "s",
	[M] = "m",
	[LRM] = "",

	-- common combinations
	[AH] = "a",
	[AT] = "at",
	[AA] = "ā",
	[AAMAQ] = "ā",
	[AAH] = "āh",
	[AAT] = "āt",
	[II] = "ī",
	[UU] = "ū",
	[AY] = "ay",
	[AW] = "aw",
	[AYSK] = "ay",
	[AWSK] = "aw",
	[NA] = "na",
	[NI] = "ni",
	[AAN] = "ān",
	[AANI] = "āni",
	[AYNI] = "ayni",
	[AWNA] = "awna",
	[AYNA] = "ayna",
	[AYAAT] = "ayāt",
	[MA] = "ma",
	[MU] = "mu",
	[TA] = "ta",
	[TU] = "tu",
	[_I] = "i",
	[_U] = "u",
}

local function transliterate(text)
	local cached = translit_cache[text]
	if cached then
		if cached == BAD then
			error(("Internal error: Unable to transliterate %s because explicitly marked as BAD"):format(text))
		end
		return cached
	end
	local tr = (lang:transliterate(text))
	if not tr then
		error(("Internal error: Unable to transliterate: %s"):format(text))
	end
	translit_cache[text] = tr
	return tr
end

local all_person_number_list = {
	"1s",
	"2ms",
	"2fs",
	"3ms",
	"3fs",
	"2d",
	"3md",
	"3fd",
	"1p",
	"2mp",
	"2fp",
	"3mp",
	"3fp"
}

local function make_person_number_slot_accel_list(list)
	local slot_accel_list = {}
	return slot_accel_list
end

local imp_person_number_list = {}
for _, pn in ipairs(all_person_number_list) do
	if pn:find("^2") then
		table.insert(imp_person_number_list, pn)
	end
end

local passive_types = m_table.listToSet {
	"withpass", -- verb has both active and passive
	"nopass", -- verb is active-only
	"onlypass", -- verb is passive-only
	"imperspass", -- verb is active with impersonal passive
	"impers", -- verb itself is impersonal, meaning passive-only with impersonal passive
}

local indicator_flags = m_table.listToSet {
	"noimp", "no_nonpast",
}

local potential_lemma_slots = {"past_3ms", "past_pass_3ms", "ind_3ms", "ind_pass_3ms", "imp_2ms"}

local unsettable_slots = {}
for _, potential_lemma_slot in ipairs(potential_lemma_slots) do
	table.insert(unsettable_slots, potential_lemma_slot .. "_linked")
end
table.insert(unsettable_slots, "vn2") -- secondary default for form III verbal nouns
local unsettable_slots_set = m_table.listToSet(unsettable_slots)

-- Initialize all the slots for which we generate forms.
local function add_slots(alternant_multiword_spec)
	alternant_multiword_spec.verb_slots = {
		{"ap", "act|part"},
		{"pp", "pass|part"},
		{"vn", "vnoun"},
	}
	for _, unsettable_slot in ipairs(unsettable_slots) do
		table.insert(alternant_multiword_spec.verb_slots, {unsettable_slot, "-"})
	end

	-- Add entries for a slot with person/number variants.
	-- `slot_prefix` is the prefix of the slot, typically specifying the tense/aspect.
	-- `tag_suffix` is a string listing the set of inflection tags to add after the person/number tags.
	-- `person_number_list` is a list of the person/number slot suffixes to add to `slot_prefix`.
	local function add_personal_slot(slot_prefix, tag_suffix, person_number_list)
		for _, persnum in ipairs(person_number_list) do
			local slot = slot_prefix .. "_" .. persnum
			local accel = persnum:gsub("(.)", "%1|") .. tag_suffix
			table.insert(alternant_multiword_spec.verb_slots, {slot, accel})
		end
	end

	local tenses = {
		{"past", "past|%s"},
		{"ind", "non-past|%s|ind"},
		{"sub", "non-past|%s|sub"},
		{"juss", "non-past|%s|juss"},
	}
	for _, slot_accel in ipairs(tenses) do
		local slot, accel = unpack(slot_accel)
		for _, voice in ipairs {"act", "pass"} do
			add_personal_slot(voice == "act" and slot or slot .. "_pass", accel:format(voice),
				all_person_number_list)
		end
	end
	add_personal_slot("imp", "imp", imp_person_number_list)

	alternant_multiword_spec.verb_slots_map = {}
	for _, slot_accel in ipairs(alternant_multiword_spec.verb_slots) do
		local slot, accel = unpack(slot_accel)
		alternant_multiword_spec.verb_slots_map[slot] = accel
	end
end

local overridable_stems = {}

local slot_override_param_mods = {
	footnote = {
		item_dest = "footnotes",
		store = "insert",
	},
	alt = {},
	t = {
		-- [[Module:links]] expects the gloss in "gloss".
		item_dest = "gloss",
	},
	gloss = {},
	g = {
		-- [[Module:links]] expects the genders in "g". `sublist = true` automatically splits on comma (optionally
		-- with surrounding whitespace).
		item_dest = "genders",
		sublist = true,
	},
	pos = {},
	lit = {},
	id = {},
	-- Qualifiers and labels
	q = {
		type = "qualifier",
	},
	qq = {
		type = "qualifier",
	},
	l = {
		type = "labels",
	},
	ll = {
		type = "labels",
	},
}

local function generate_obj(formval, parse_err)
	local val, uncertain = formval:match("^(.*)(%?)$")
	val = val or formval
	uncertain = not not uncertain
	local ar, translit = val:match("^(.*)//(.*)$")
	if not ar then
		ar = formval
	end
	return {form = ar, translit = translit, uncertain = uncertain}
end

local function parse_inline_modifiers(comma_separated_group, parse_err)
	return require(parse_utilities_module).parse_inline_modifiers_from_segments {
		group = comma_separated_group,
		props = {
			param_mods = param_mods,
			parse_err = parse_err,
			generate_obj = generate_obj,
			pre_normalize_modifiers = function(data)
				local modtext = data.modtext
				modtext = modtext:match("^%[(.*)%]$")
				if modtext then
					return ("<footnote:%s>"):format(modtext)
				end
				return modtext
			end,
		},
	}
end

local function allow_multiple_values_for_override(comma_separated_groups, data, is_slot_override)
	local retvals = {}
	for _, comma_separated_group in ipairs(comma_separated_groups) do
		local retval
		if is_slot_override then
			retval = parse_inline_modifiers(comma_separated_groups, data.parse_err)
		else
			local retval = generate_obj(comma_separated_group[1], data.parse_err)
			retval.footnotes = data.fetch_footnotes(comma_separated_group)
		end
		table.insert(retvals, retval)
	end
	for _, form in ipairs(retvals) do
		if form.form == "+" or form.form == "++" then
			if not is_slot_override then
				error(("Stem override '%s' cannot use + or ++ to request a default"):format(data.prefix))
			end
			data.base.slot_uses_default[data.prefix] = true
		end
	end
	for _, form in ipairs(retvals) do
		if form.form == "-" then
			data.base.slot_explicitly_missing[data.prefix] = true
			break
		end
	end
	if data.base.slot_explicitly_missing[data.prefix] then
		for _, form in ipairs(retvals) do
			if form.form ~= "-" then
				data.parse_err(("For slot or stem '%s', saw both - and a value other than -, which isn't allowed"):
					format(data.prefix))
			end
		end
		return nil
	end
	return retvals
end

local function simple_choice(choices)
	return function(separated_groups, data)
		if #separated_groups > 1 then
			data.parse_err("For spec '" .. data.prefix .. ":', only one value currently allowed")
		end
		if #separated_groups[1] > 1 then
			data.parse_err("For spec '" .. data.prefix .. ":', no footnotes currently allowed")
		end
		local choice = separated_groups[1][1]
		if not m_table.contains(choices, choice) then
			data.parse_err("For spec '" .. data.prefix .. ":', saw value '" .. choice .. "' but expected one of '" ..
				table.concat(choices, ",") .. "'")
		end
		return choice
	end
end

for _, overridable_stem in ipairs {
	"past",
	"past_v",
	"past_c",
	"past_pass",
	"past_pass_v",
	"past_pass_c",
	"nonpast",
	"nonpast_v",
	"nonpast_c",
	"nonpast_pass",
	"nonpast_pass_v",
	"nonpast_pass_c",
	"imp",
	"imp_v",
	"imp_c",
} do
	overridable_stems[overridable_stem] = allow_multiple_values_for_override
end

overridable_stems.past_final_weak_vowel = simple_choice { "ay", "aw", "ī", "ū" }
overridable_stems.past_pass_final_weak_vowel = simple_choice { "ay", "aw", "ī", "ū" }
overridable_stems.nonpast_final_weak_vowel = simple_choice { "ā", "ī", "ū" }
overridable_stems.nonpast_pass_final_weak_vowel = simple_choice { "ā", "ī", "ū" }


-------------------------------------------------------------------------------
--                                Utility functions                          --
-------------------------------------------------------------------------------

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	return (rsubn(term, foo, bar))
end

-- version of rsubn() that returns a 2nd argument boolean indicating whether a substitution was made.
local function rsubb(term, foo, bar)
	local retval, nsubs = rsubn(term, foo, bar)
	return retval, nsubs > 0
end

-- Concatenate one or more strings or form objects.
local function q(...)
	local not_all_strings = false
	local has_manual_translit = false
	for i = 1, select("#", ...) do
		local argt = select(i, ...)
		if not argt then
			error(("Internal error: Saw nil at index %s: %s"):format(i, dump({...})))
		end
		if type(argt) ~= "string" then
			not_all_strings = true
			if argt.translit then
				has_manual_translit = true
				break
			end
		end
	end

	if not not_all_strings then
		-- just strings, concatenate directly
		return table.concat({...})
	end

	--error(dump({...}))

	local formvals = {}
	local translit = has_manual_translit and {} or nil
	local footnotes

	for i = 1, select("#", ...) do
		local argt = select(i, ...)
		if type(argt) == "string" then
			formvals[i] = argt
			if has_manual_translit then
				translit[i] = transliterate(argt)
			end
		else
			formvals[i] = argt.form
			if has_manual_translit then
				translit[i] = argt.translit or transliterate(argt.form)
			end
			footnotes = iut.combine_footnotes(footnotes, argt.footnotes)
		end
	end

	-- FIXME: Do we want to support other properties?
	return {
		form = table.concat(formvals),
		translit = has_manual_translit and table.concat(translit) or nil,
		footnotes = footnotes,
	}
end

-- Return the formval associated with `rad` (a radical or past/non-past vowel, either a string or form object).
local function rget(rad)
	if type(rad) == "string" then
		return rad
	elseif type(rad) == "table" then
		return rad.form
	else
		error(("Internal error: Unexpected type for radical or past/non-past vowel: %s"):format(dump(rad)))
	end
end

-- Return the footnotes associated with `rad` (a radical or past/non-past vowel, either a string or form object).
local function rget_footnotes(rad)
	if type(rad) == "string" then
		return nil
	elseif type(rad) == "table" then
		return rad.footnotes
	else
		error(("Internal error: Unexpected type for radical or past/non-past vowel: %s"):format(dump(rad)))
	end
end

-- Return true if the formval associated with `rad` (a radical or past/non-past vowel, either a string or form object)
-- is `val`.
local function req(rad, val)
	return rget(rad) == val
end

-- Map `vow` (a past/non-past vowel, either a string or form object without translit) by passing the formval through
-- `fn`. Don't call this on radicals because they may have manual translit and it isn't clear how to handle that.
local function map_vowel(vow, fn)
	if type(vow) == "string" then
		return fn(vow)
	elseif type(vow) == "table" then
		return {form = fn(vow.form), footnotes = vow.footnotes}
	else
		error(("Internal error: Unexpected type for past/non-past vowel: %s"):format(dump(vow)))
	end
end

local function get_radicals_3(vowel_spec)
	return vowel_spec.rad1, vowel_spec.rad2, vowel_spec.rad3, vowel_spec.past, vowel_spec.nonpast
end

local function get_radicals_4(vowel_spec)
	return vowel_spec.rad1, vowel_spec.rad2, vowel_spec.rad3, vowel_spec.rad4
end

local function is_final_weak(base, vowel_spec)
	return vowel_spec.weakness == "final-weak" or base.form == "XV"
end

local function link_term(text, face, id)
	return m_links.full_link({lang = lang, term = text, tr = "-", id = id}, face)
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

-------------------------------------------------------------------------------
--                        Basic functions to inflect tenses                  --
-------------------------------------------------------------------------------

local function skip_slot(base, slot, allow_overrides)
	if base.slot_explicitly_missing[slot] then
		return true
	end
	if not allow_overrides and base.slot_overrides[slot] and not base.slot_uses_default[slot] then
		-- Skip any slots for which there are overrides, except those that request the default value using + or ++.
		return true
	end

	if base.passive == "nopass" and (slot == "pp" or slot:find("_pass")) then
		return true
	elseif base.passive == "onlypass" and slot ~= "pp" and slot ~= "vn" and not slot:find("_pass") then
		return true
	elseif base.passive == "imperspass" and slot:find("_pass") and not slot:find("3ms") then
		return true
	elseif base.passive == "impers" and (slot == "ap" or not slot:find("_pass") or
		slot:find("_pass") and not slot:find("3ms")) then
		return true
	end

	if (base.noimp or base.no_nonpast) and slot:find("^imp_") then
		return true
	end
	if base.no_nonpast and (slot:find("^ind_") or slot:find("^sub_") or slot:find("^juss")) then
		return true
	end

	return false
end

local function basic_combine_stem_ending(stem, ending)
	return stem .. ending
end

local function basic_combine_stem_ending_tr(stem, ending)
	return stem .. ending
end

local function add3(base, slot, prefixes, stems, endings, footnotes, allow_overrides)
	if skip_slot(base, slot, allow_overrides) then
		return
	end

	-- Optimization since the prefixes are almost always single strings.
	if type(prefixes) == "string" then
		local function do_combine_stem_ending(stem, ending)
			return prefixes .. stem .. ending
		end
		local function do_combine_stem_ending_tr(stem, ending)
			return transliterate(prefixes) .. stem .. ending
		end
		iut.add_forms(base.forms, slot, stems, endings, do_combine_stem_ending, transliterate,
			do_combine_stem_ending_tr, footnotes)
	else
		iut.add_multiple_forms(base.forms, slot, {prefixes, stems, endings}, basic_combine_stem_ending, transliterate,
			basic_combine_stem_ending_tr, footnotes)
	end
end

local function insert_form(base, slot, form, allow_overrides)
	if not skip_slot(base, slot, allow_overrides) then
		if type(form) == "string" then
			form = {form = form}
		end
		iut.insert_form(base.forms, slot, form)
	end
end

local function insert_forms(base, slot, forms, allow_overrides)
	if not skip_slot(base, slot, allow_overrides) then
		iut.insert_forms(base.forms, slot, forms)
	end
end

local function map_general(stemforms, fn)
	return iut.map_forms(iut.convert_to_general_list_form(stemforms), fn)
end

local function flatmap_general(stemforms, fn)
	return iut.flatmap_forms(iut.convert_to_general_list_form(stemforms), fn)
end

local function construct_stems(base)
	local stems = base.stem_overrides
	stems.past_v = stems.past_v or stems.past
	stems.past_c = stems.past_c or stems.past
	stems.past_pass_v = stems.past_pass_v or stems.past_pass
	stems.past_pass_c = stems.past_pass_c or stems.past_pass
	stems.nonpast_v = stems.nonpast_v or stems.nonpast
	stems.nonpast_c = stems.nonpast_c or stems.nonpast
	stems.nonpast_pass_v = stems.nonpast_pass_v or stems.nonpast_pass
	stems.nonpast_pass_c = stems.nonpast_pass_c or stems.nonpast_pass
	stems.imp_v = stems.imp_v or stems.imp
	stems.imp_c = stems.imp_c or stems.imp
	local function truncate_nonpast_initial_cons(stem_type, form, translit)
		if not form:find("^" .. Y) then
			error(("Form value %s for stem type '%s' should begin with ي"):format(form, stem_type))
		end
		form = form:gsub("^" .. Y, "")
		if translit then
			if not translit:find("^y") then
				error(("Translit value %s for stem type '%s' should begin with y"):format(translit, stem_type))
			end
			translit = translit:gsub("^y", "")
		end
		return form, translit
	end
	for nonpast_stem_type in ipairs { "nonpast_v", "nonpast_c", "nonpast_pass_v", "nonpast_pass_c" } do
		if stems[nonpast_stem_type] then
			stems[nonpast_stem_type] = map_general(stems[nonpast_stem_type], function(form, translit)
				return truncate_nonpast_initial_cons(nonpast_stem_type, form, translit)
			end)
		end
	end
end

-------------------------------------------------------------------------------
--                      Properties of different verbal forms                 --
-------------------------------------------------------------------------------

local allowed_vforms = {"I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX",
	"X", "XI", "XII", "XIII", "XIV", "XV", "Iq", "IIq", "IIIq", "IVq"}
local allowed_vforms_set = m_table.listToSet(allowed_vforms)
local allowed_vforms_with_weakness = m_table.shallowcopy(allowed_vforms)

-- The user needs to be able to explicitly specify that a form-I verb (specifically one whose initial radical is و) is
-- sound. Cf. wajiʕa yawjaʕu (not #yajaʕu) "to ache, to hurt". In general, i~a and u~u verbs whose initial radical is و
-- seem to not assimilate the first radical; cf. وقح "to be shameless", variously waqaḥa~yaqiḥu, waquḥa~yawquḥu and
-- waqiḥa~yawqaḥu, whereas a~i verbs (wafaḍa~yafiḍu "to rush"), i~i verbs (wafiqa~yafiqu "to be proper, to be suitable")
-- and a~a verbs (waḍaʕa~yaḍaʕu "to set down, to place") do assimilate. But there are naturally exceptions, e.g.
-- waṭiʔa~yaṭaʔu "to tread, to trample"; wasiʕa~yasaʕu "to be spacious; to be well-off"; waṯiʔa~yaṯaʔu "to get bruised,
-- to be sprained". Also beware of waniya~yawnā "to be faint; to languish", which is sound in the first radical and
-- final-weak in the last radical. Nonetheless, the regularity of the patterns mentioned above suggest we should provide
-- them as defaults.

-- Note that there are other cases of unexpectedly sound verbs, e.g. izdawaja~yazdawiju "to be in pairs", layisa~yalyasu
-- "to be valiant, to be brave", ʔaḥwaja~yuḥwiju "to need", istahwana~yastahwinu "to consider easy", sawisa~yaswasu "to
-- be or become moth-eaten or worm-eaten" (vs. sāsa~yasūsu "to govern, to rule" from the same radicals), ʕawira~yaʕwaru
-- "to be one-eyed", istajwaba~yastajwibu "to interrogate", etc. But in these cases there is no need for explicit user
-- specification as the lemma itself specifies the unexpected soundness.
for _, form_with_weakness in ipairs { "I-sound", "I-assimilated", "irreg-sound", "irreg-hollow", "irreg-geminate",
	"irreg-final-weak" } do
	table.insert(allowed_vforms_with_weakness, form_with_weakness)
end
local allowed_vforms_with_weakness_set = m_table.listToSet(allowed_vforms_with_weakness)

local function vform_supports_final_weak(vform)
	return vform ~= "XI" and vform ~= "XV" and vform ~= "IVq"
end

local function vform_supports_geminate(vform)
	return vform == "I" or vform == "III" or vform == "IV" or
		vform == "VI" or vform == "VII" or vform == "VIII" or vform == "X"
end

local function vform_supports_hollow(vform)
	return vform == "I" or vform == "IV" or vform == "VII" or vform == "VIII" or
		vform == "X"
end

local function vform_probably_impersonal_passive(vform)
	return vform == "VI"
end

local function vform_probably_no_passive(vform, weakness, past_vowel, nonpast_vowel)
	return vform == "I" and weakness ~= "hollow" and req(past_vowel, U) or
		vform == "VII" or vform == "IX" or vform == "XI" or vform == "XII" or
		vform == "XIII" or vform == "XIV" or vform == "XV" or vform == "IIq" or
		vform == "IIIq" or vform == "IVq"
end

local function vform_is_quadriliteral(vform)
	return vform == "Iq" or vform == "IIq" or vform == "IIIq" or vform == "IVq"
end

-- Active vforms II, III, IV, Iq use non-past prefixes in -u- instead of -a-.
local function prefix_vowel_from_vform(vform)
	if vform == "II" or vform == "III" or vform == "IV" or vform == "Iq" then
		return "u"
	else
		return "a"
	end
end

-- True if the active non-past takes a-vocalization rather than i-vocalization in its last syllable.
local function vform_nonpast_a_vowel(vform)
	return vform == "V" or vform == "VI" or vform == "XV" or vform == "IIq"
end

-------------------------------------------------------------------------------
--                        Properties of specific sounds                      --
-------------------------------------------------------------------------------

-- Is radical wāw (و) or yāʾ (ي)?
local function is_waw_ya(rad)
	return req(rad, W) or req(rad, Y)
end

-- Check that radical is wāw (و) or yāʾ (ي), error if not
local function check_waw_ya(rad)
	if not is_waw_ya(rad) then
		error("Expecting weak radical: '" .. rget(rad) .. "' should be " .. W .. " or " .. Y)
	end
end

-- FUCK ME HARD. "Lua error at line 1514: main function has more than 200 local variables".
local function create_conjugations()
	-------------------------------------------------------------------------------
	--              Radicals associated with various irregular verbs             --
	-------------------------------------------------------------------------------

	-- Form-I verb أخذ or form-VIII verb اتخذ
	local function axadh_radicals(rad1, rad2, rad3)
		return req(rad1, HAMZA) and req(rad2, "خ") and req(rad3, "ذ")
	end

	-- Form-I verb whose imperative has a reduced form: أكل and أخذ and أمر
	local function reduced_imperative_verb(rad1, rad2, rad3)
		return axadh_radicals(rad1, rad2, rad3) or req(rad1, HAMZA) and (
			req(rad2, "ك") and req(rad3, "ل") or
			req(rad2, "م") and req(rad3, "ر"))
	end

	-- Form-I verb رأى and form-IV verb أرى
	local function raa_radicals(rad1, rad2, rad3)
		return req(rad1, "ر") and req(rad2, HAMZA) and is_waw_ya(rad3)
	end

	-- Form-I verb سأل
	local function saal_radicals(rad1, rad2, rad3)
		return req(rad1, "س") and req(rad2, HAMZA) and req(rad3, "ل")
	end

	-- Form-I verb حيّ or حيي and form-X verb استحيا or استحى
	local function hayy_radicals(rad1, rad2, rad3)
		return req(rad1, "ح") and req(rad2, Y) and is_waw_ya(rad3)
	end

	-------------------------------------------------------------------------------
	--                               Sets of past endings                        --
	-------------------------------------------------------------------------------

	-- The 13 endings of the sound/hollow/geminate past tense.
	local past_endings = {
		-- singular
		SK .. TU, SK .. TA, SK .. "تِ", A, A .. "تْ",
		--dual
		SK .. "تُمَا", AA, A .. "تَا",
		-- plural
		SK .. "نَا", SK .. "تُمْ",
		-- two Arabic diacritics don't work together in Wikimedia
		--SK .. "تُنَّ",
		SK .. "تُن" .. SH .. A, UU .. ALIF, SK .. "نَ"
	}

	-- Make endings for final-weak past in -aytu or -awtu. AYAW is AY or AW as appropriate. Note that AA and AW are global
	-- variables.
	local function make_past_endings_ay_aw(ayaw, third_sg_masc)
		return {
		-- singular
		ayaw .. SK .. TU, ayaw ..  SK .. TA, ayaw .. SK .. "تِ",
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

	-- Make endings for final-weak past in -ītu or -ūtu. IIUU is ī or ū as appropriate. Note that AA and UU are global
	-- variables.
	local function make_past_endings_ii_uu(iiuu)
		return {
		-- singular
		iiuu .. TU, iiuu .. TA, iiuu .. "تِ", iiuu .. A, iiuu .. A .. "تْ",
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

	local nonpast_prefix_consonants = {
		-- singular
		HAMZA, T, T, Y, T,
		-- dual
		T, Y, T,
		-- plural
		N, T, T, Y, Y
	}

	-- There are only five distinct endings in all non-past verbs. Make any set of non-past endings given these five
	-- distinct endings.
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
	local ind_endings = make_nonpast_endings(
		U,
		II .. NA,
		AANI,
		UU .. NA,
		SK .. NA
	)

	-- Make the endings for non-past subjunctive/jussive, given the vowel diacritic used in "null" endings
	-- (1s/2ms/3ms/3fs/1p).
	local function make_sub_juss_endings(dia_null)
		return make_nonpast_endings(
		dia_null,
		II,
		AA,
		UU .. ALIF,
		SK .. NA
		)
	end

	-- endings for non-past subjunctive
	local sub_endings = make_sub_juss_endings(A)

	-- endings for non-past jussive
	local juss_endings = make_sub_juss_endings(SK)

	-- endings for alternative geminate non-past jussive in -a; same as subjunctive
	local juss_endings_alt_a = sub_endings

	-- endings for alternative geminate non-past jussive in -i
	local juss_endings_alt_i = make_sub_juss_endings(I)

	-- Endings for final-weak non-past indicative in -ā. Note that AY, AW and AAMAQ are global variables.
	local ind_endings_aa = make_nonpast_endings(
		AAMAQ,
		AYSK .. NA,
		AY .. AANI,
		AWSK .. NA,
		AYSK .. NA
	)

	-- Make endings for final-weak non-past indicative in -ī or -ū; IIUU is ī or ū as appropriate. Note that II and UU are
	-- global variables.
	local function make_ind_endings_ii_uu(iiuu)
		return make_nonpast_endings(
			iiuu,
			II .. NA,
			iiuu .. AANI,
			UU .. NA,
			iiuu .. NA
		)
	end

	-- endings for final-weak non-past indicative in -ī
	local ind_endings_ii = make_ind_endings_ii_uu(II)

	-- endings for final-weak non-past indicative in -ū
	local ind_endings_uu = make_ind_endings_ii_uu(UU)

	-- Endings for final-weak non-past subjunctive in -ā. Note that AY, AW, ALIF, AAMAQ are global variables.
	local sub_endings_aa = make_nonpast_endings(
		AAMAQ,
		AYSK,
		AY .. AA,
		AWSK .. ALIF,
		AYSK .. NA
	)

	-- Make endings for final-weak non-past subjunctive in -ī or -ū. IIUU is ī or ū as appropriate. Note that AA, II, UU,
	-- ALIF are global variables.
	local function make_sub_endings_ii_uu(iiuu)
		return make_nonpast_endings(
			iiuu .. A,
			II,
			iiuu .. AA,
			UU .. ALIF,
			iiuu .. NA
		)
	end

	-- endings for final-weak non-past subjunctive in -ī
	local sub_endings_ii = make_sub_endings_ii_uu(II)

	-- endings for final-weak non-past subjunctive in -ū
	local sub_endings_uu = make_sub_endings_ii_uu(UU)

	-- endings for final-weak non-past jussive in -ā
	local juss_endings_aa = make_nonpast_endings(
		A,
		AYSK,
		AY .. AA,
		AWSK .. ALIF,
		AYSK .. NA
	)

	-- Make endings for final-weak non-past jussive in -ī or -ū. IU is short i or u, IIUU is long ī or ū as appropriate.
	-- Note that AA, II, UU, ALIF are global variables.
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

	-- Extract the second person jussive endings to get corresponding imperative endings.
	local function imperative_endings_from_jussive(endings)
		return {endings[2], endings[3], endings[6], endings[10], endings[11]}
	end

	-- normal imperative endings
	local imp_endings = imperative_endings_from_jussive(juss_endings)
	-- alternative geminate imperative endings in -a
	local imp_endings_alt_a = imperative_endings_from_jussive(juss_endings_alt_a)
	-- alternative geminate imperative endings in -i
	local imp_endings_alt_i = imperative_endings_from_jussive(juss_endings_alt_i)
	-- final-weak imperative endings in -ā
	local imp_endings_aa = imperative_endings_from_jussive(juss_endings_aa)
	-- final-weak imperative endings in -ī
	local imp_endings_ii = imperative_endings_from_jussive(juss_endings_ii)
	-- final-weak imperative endings in -ū
	local imp_endings_uu = imperative_endings_from_jussive(juss_endings_uu)

	-------------------------------------------------------------------------------
	--                        Basic functions to inflect tenses                  --
	-------------------------------------------------------------------------------

	-- Add to `base` the inflections for the tense indicated by `tense` (the prefix in the slot names, e.g. 'past_act' or
	-- 'juss_pass'), formed by combining the `prefixes`, `stems` and `endings`. Each of `prefixes`, `stems` and `endings` is
	-- either a sequence of 5 (for the imperative) or 13 (for other tenses) form values, where a form value is either a
	-- string, a form object (which is a table of the form {form="FORM", translit="MANUAL_TRANSLIT", footnotes={"FOOTNOTE",
	-- "FOOTNOTE", ...}}), or a list of strings and/or form objects. Alternatively, any of `prefixes`, `stems` or `endings`
	-- can be a single-element list containing a form value, with an additional key `all_same` set to true, or (as a special
	-- case) a single string; in the latter cases, the same value is used for all 5 or 13 slots. If existing inflections
	-- already exist, they will be added to, not overridden. `pnums` is the list of person/number slot name suffixes, which
	-- must match up with the elements in `prefixes`, `stems` and `endings` (i.e. 5 for imperative, 13 otherwise).
	local function inflect_tense_1(base, tense, prefixes, stems, endings, pnums, footnotes)
		if not prefixes or not stems or not endings then
			return
		end
		local function verify_affixes(affixname, affixes)
			local function interr(msg)
				error(("Internal error: For tense '%s', '%s' %s: %s"):format(tense, affixname, msg, dump(affixes)))
			end
			if type(affixes) == "string" then
				-- do nothing
			elseif type(affixes) ~= "table" then
				interr("is not a table or string")
			elseif affixes.all_same then
				if #affixes ~= 1 then
					interr("with all_same = true should have length 1")
				end
			else
				if #affixes ~= #pnums then
					interr(("should have length 1 but has length %s"):format(#affixes))
				end
			end
		end

		verify_affixes("prefixes", prefixes)
		verify_affixes("stems", stems)
		verify_affixes("endings", endings)

		local function get_affix(affixes, i)
			if type(affixes) == "string" then
				return affixes
			elseif affixes.all_same then
				return affixes[1]
			else
				return affixes[i]
			end
		end

		for i, pnum in ipairs(pnums) do
			local prefix = get_affix(prefixes, i)
			local stem = get_affix(stems, i)
			local ending = get_affix(endings, i)
			local slot = tense .. "_" .. pnum
			add3(base, slot, prefix, stem, ending, footnotes)
		end
	end

	-- Add to `base` the inflections for the tense indicated by `tense` (the prefix in the slot names, e.g. 'past_act' or
	-- 'juss_pass'), formed by combining the `prefixes`, `stems` and `endings`. This is a simple wrapper around
	-- inflect_tense_1() that applies to all tenses other than the imperative; see inflect_tense_1() for more information
	-- about the parameters.
	local function inflect_tense(base, tense, prefixes, stems, endings, footnotes)
		inflect_tense_1(base, tense, prefixes, stems, endings, all_person_number_list, footnotes)
	end

	-- Like inflect_tense() but for the imperative, which has only five parts instead of 13 and no prefixes.
	local function inflect_tense_imp(base, stems, endings, footnotes)
		inflect_tense_1(base, "imp", "", stems, endings, imp_person_number_list, footnotes)
	end

	-------------------------------------------------------------------------------
	--                      Functions to inflect the past tense                  --
	-------------------------------------------------------------------------------

	-- Generate past verbs using specified vowel and consonant stems; works for sound, assimilated, hollow, and geminate
	-- verbs, active and passive.
	local function past_2stem_conj(base, tense, v_stem, c_stem)
		v_stem = base.stem_overrides.past_v or v_stem
		c_stem = base.stem_overrides.past_c or c_stem
		inflect_tense(base, tense, "", {
			-- singular
			c_stem, c_stem, c_stem, v_stem, v_stem,
			--dual
			c_stem, v_stem, v_stem,
			-- plural
			c_stem, c_stem, c_stem, v_stem, c_stem
		}, past_endings)
	end

	-- Generate past verbs using single specified stem; works for sound and assimilated verbs, active and passive.
	local function past_1stem_conj(base, tense, stem)
		past_2stem_conj(base, tense, stem, stem)
	end

	-------------------------------------------------------------------------------
	--                     Functions to inflect non-past tenses                  --
	-------------------------------------------------------------------------------

	-- Generate non-past conjugation, with two stems, for vowel-initial and consonant-initial endings, respectively. Useful
	-- for active and passive; for all forms; for all weaknesses (sound, assimilated, hollow, final-weak and geminate) and
	-- for all types of non-past (indicative, subjunctive, jussive) except for the imperative. (There is a separate wrapper
	-- function below for geminate jussives because they have three alternants.) Both stems may be the same, e.g. for sound
	-- verbs.

	-- `prefix_vowel` will be either "a" or "u". `endings` should be an array of 13 items. If `endings` is nil or omitted,
	-- infer the endings from the tense. If `jussive` is true, or `endings` is nil and `tense` indicatives jussive, use the
	-- jussive pattern of vowel/consonant stems (different from the normal ones).
	local function nonpast_2stem_conj(base, tense, prefix_vowel, v_stem, c_stem, endings, jussive)
		local passive = tense:find("_pass") and "_pass" or ""
		-- Override stems with user-specified stems if available.
		v_stem = base.stem_overrides["nonpast" .. passive .. "_v"] or v_stem and q(dia[prefix_vowel], v_stem) or nil
		c_stem = base.stem_overrides["nonpast" .. passive .. "_c"] or c_stem and q(dia[prefix_vowel], c_stem) or nil
		if endings == nil then
			if tense:find("^ind") then
				endings = ind_endings
			elseif tense:find("^sub") then
				endings = sub_endings
			elseif tense:find("^juss") then
				jussive = true
				endings = juss_endings
			else
				error("Internal error: Unrecognized tense '" .. tense .."'")
			end
		end
		if not jussive then
			inflect_tense(base, tense, nonpast_prefix_consonants, {
				-- singular
				v_stem, v_stem, v_stem, v_stem, v_stem,
				--dual
				v_stem, v_stem, v_stem,
				-- plural
				v_stem, v_stem, c_stem, v_stem, c_stem
			}, endings)
		else
			inflect_tense(base, tense, nonpast_prefix_consonants, {
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

	-- Generate non-past conjugation with one stem (no distinct stems for vowel-initial and consonant-initial endings). See
	-- nonpast_2stem_conj().
	local function nonpast_1stem_conj(base, tense, prefix_vowel, stem, endings, jussive)
		nonpast_2stem_conj(base, tense, prefix_vowel, stem, stem, endings, jussive)
	end

	-- Generate active/passive jussive geminative. There are three alternants, two with terminations -a and -i and one in a
	-- null termination with a distinct pattern of vowel/consonant stem usage. See nonpast_2stem_conj() for a description of
	-- the arguments.
	local function jussive_gem_conj(base, tense, prefix_vowel, v_stem, c_stem)
		-- alternative in -a
		nonpast_2stem_conj(base, tense, prefix_vowel, v_stem, c_stem, juss_endings_alt_a)
		-- alternative in -i
		nonpast_2stem_conj(base, tense, prefix_vowel, v_stem, c_stem, juss_endings_alt_i)
		-- alternative in -null; requires different combination of v_stem and
		-- c_stem since the null endings require the c_stem (e.g. "tadlul" here)
		-- whereas the corresponding endings above in -a or -i require the v_stem
		-- (e.g. "tadulla, tadulli" above)
		nonpast_2stem_conj(base, tense, prefix_vowel, v_stem, c_stem, juss_endings, "jussive")
	end

	-------------------------------------------------------------------------------
	--                    Functions to inflect the imperative                    --
	-------------------------------------------------------------------------------

	-- Generate imperative conjugation, with two stems, for vowel-initial and consonant-initial endings, respectively.
	-- Useful for all forms, and for all weaknesses other than final-weak. Note that the two stems may be the same
	-- (specifically for sound and assimilated verbs). If `endings` is nil or omitted, use `imp_endings`. If `alt_gem` is
	-- specified, use the pattern of vowel and consonant stems appropriate for the alternative geminate imperatives that
	-- use a null ending of -a or -i instead of an empty ending.
	local function make_2stem_imperative(base, v_stem, c_stem, endings, alt_gem)
		endings = endings or imp_endings
		-- Override stems with user-specified stems if available.
		v_stem = base.stem_overrides.imp_v or v_stem
		c_stem = base.stem_overrides.imp_c or c_stem
		if alt_gem then
			inflect_tense_imp(base, {v_stem, v_stem, v_stem, v_stem, c_stem}, endings)
		else
			inflect_tense_imp(base, {c_stem, v_stem, v_stem, v_stem, c_stem}, endings)
		end
	end

	-- Generate imperative parts for sound or assimilated verbs.
	local function make_1stem_imperative(base, stem)
		make_2stem_imperative(base, stem, stem)
	end

	-- Generate imperative parts for geminate verbs form I (also IV, VII, VIII, X).
	local function make_gem_imperative(base, v_stem, c_stem)
		make_2stem_imperative(base, v_stem, c_stem, imp_endings_alt_a, "alt gem")
		make_2stem_imperative(base, v_stem, c_stem, imp_endings_alt_i, "alt gem")
		make_2stem_imperative(base, v_stem, c_stem)
	end

	-------------------------------------------------------------------------------
	--                    Functions to inflect entire verbs                      --
	-------------------------------------------------------------------------------

	-- Generate finite parts of a sound verb (also works for assimilated verbs) from five stems (past and non-past, active
	-- and passive, plus imperative) plus the prefix vowel in the active non-past ("a" or "u").
	local function make_sound_verb(base, past_stem, past_pass_stem, nonpast_stem, nonpast_pass_stem, imp_stem,
			prefix_vowel)
		past_1stem_conj(base, "past", past_stem)
		past_1stem_conj(base, "past_pass", past_pass_stem)
		nonpast_1stem_conj(base, "ind", prefix_vowel, nonpast_stem)
		nonpast_1stem_conj(base, "sub", prefix_vowel, nonpast_stem)
		nonpast_1stem_conj(base, "juss", prefix_vowel, nonpast_stem)
		nonpast_1stem_conj(base, "ind_pass", "u", nonpast_pass_stem)
		nonpast_1stem_conj(base, "sub_pass", "u", nonpast_pass_stem)
		nonpast_1stem_conj(base, "juss_pass", "u", nonpast_pass_stem)
		make_1stem_imperative(base, imp_stem)
	end

	local function past_final_weak_endings_from_vowel(vowel)
		if vowel == "ay" then
			return past_endings_ay
		elseif vowel == "aw" then
			return past_endings_aw
		elseif vowel == "ī" then
			return past_endings_ii
		elseif vowel == "ū" then
			return past_endings_uu
		elseif not vowel then
			return nil
		else
			error(("Internal error: Unrecognized past final-weak vowel spec '%s'"):format(vowel))
		end
	end

	local function nonpast_final_weak_endings_from_vowel(vowel)
		if vowel == "ā" then
			return ind_endings_aa, sub_endings_aa, juss_endings_aa, imp_endings_aa
		elseif vowel == "ī" then
			return ind_endings_ii, sub_endings_ii, juss_endings_ii, imp_endings_ii
		elseif vowel == "ū" then
			return ind_endings_uu, sub_endings_uu, juss_endings_uu, imp_endings_uu
		elseif not vowel then
			return nil
		else
			error(("Internal error: Unrecognized non-past final-weak vowel spec '%s'"):format(vowel))
		end
	end

	-- Generate finite parts of a final-weak verb from five stems (past and non-past, active and passive, plus imperative),
	-- the past active ending vowel (ay, aw, ī or ū), the non-past active ending vowel (ā, ī or ū) and the prefix vowel in
	-- the active non-past (a or u).
	local function make_final_weak_verb(base, past_stem, past_pass_stem, nonpast_stem, nonpast_pass_stem, imp_stem,
			past_ending_vowel, nonpast_ending_vowel, prefix_vowel)
		past_stem = base.stem_overrides.past or past_stem
		past_pass_stem = base.stem_overrides.past_pass or past_pass_stem
		past_ending_vowel = base.stem_overrides.past_final_weak_vowel or past_ending_vowel
		local past_pass_ending_vowel = base.stem_overrides.past_pass_final_weak_vowel or "ī"
		nonpast_ending_vowel = base.stem_overrides.nonpast_final_weak_vowel or nonpast_ending_vowel
		local nonpast_pass_ending_vowel = base.stem_overrides.nonpast_pass_final_weak_vowel or "ā"
		local past_endings = past_final_weak_endings_from_vowel(past_ending_vowel)
		local past_pass_endings = past_final_weak_endings_from_vowel(past_pass_ending_vowel)
		local ind_endings, sub_endings, juss_endings, imp_endings =
			nonpast_final_weak_endings_from_vowel(nonpast_ending_vowel)
		local ind_pass_endings, sub_pass_endings, juss_pass_endings =
			nonpast_final_weak_endings_from_vowel(nonpast_pass_ending_vowel)

		inflect_tense(base, "past", "", past_stem, past_endings)
		inflect_tense(base, "past_pass", "", past_pass_stem, past_pass_endings)
		nonpast_1stem_conj(base, "ind", prefix_vowel, nonpast_stem, ind_endings)
		nonpast_1stem_conj(base, "sub", prefix_vowel, nonpast_stem, sub_endings)
		nonpast_1stem_conj(base, "juss", prefix_vowel, nonpast_stem, juss_endings)
		nonpast_1stem_conj(base, "ind_pass", "u", nonpast_pass_stem, ind_pass_endings)
		nonpast_1stem_conj(base, "sub_pass", "u", nonpast_pass_stem, sub_pass_endings)
		nonpast_1stem_conj(base, "juss_pass", "u", nonpast_pass_stem, juss_pass_endings)
		inflect_tense_imp(base, imp_stem, imp_endings)
	end

	-- Generate finite parts of an augmented (form II+) final-weak verb from five stems (past and non-past, active and
	-- passive, plus imperative) plus the prefix vowel in the active non-past ("a" or "u") and a flag indicating if behave
	-- like a form V/VI verb in taking non-past endings in -ā instead of -ī.
	local function make_augmented_final_weak_verb(base, past_stem, past_pass_stem, nonpast_stem, nonpast_pass_stem,
		imp_stem, prefix_vowel, form56)
		make_final_weak_verb(base, past_stem, past_pass_stem, nonpast_stem, nonpast_pass_stem, imp_stem, "ay",
			form56 and "ā" or "ī", prefix_vowel)
	end

	-- Generate finite parts of an augmented (form II+) sound or final-weak verb, given:
	-- * `base` (conjugation data structure);
	-- * `vowel_spec` (radicals, weakness);
	-- * `past_stem_base` (active past stem minus last syllable (= -al or -ā));
	-- * `nonpast_stem_base` (non-past stem minus last syllable (= -al/-il or -ā/-ī);
	-- * `past_pass_stem_base` (passive past stem minus last syllable (= -il or -ī));
	-- * `vn` (verbal noun).
	local function make_augmented_sound_final_weak_verb(base, vowel_spec, past_stem_base, nonpast_stem_base,
		past_pass_stem_base, vn)
		insert_form(base, "vn", vn)

		local rad3 = vowel_spec.rad3
		local final_weak = is_final_weak(base, vowel_spec)
		local prefix_vowel = prefix_vowel_from_vform(base.verb_form)
		local form56 = vform_nonpast_a_vowel(base.verb_form)
		local a_base_suffix = final_weak and "" or q(A, rad3)
		local i_base_suffix = final_weak and "" or q(I, rad3)

		-- past and non-past stems, active and passive
		local past_stem = q(past_stem_base, a_base_suffix)
		-- In forms 5 and 6, non-past has /a/ as last stem vowel in the non-past
		-- in both active and passive, but /i/ in the active participle and /a/
		-- in the passive participle. Elsewhere, consistent /i/ in active non-past
		-- and participle, consistent /a/ in passive non-past and participle.
		-- Hence, forms 5 and 6 differ only in the non-past active (but not
		-- active participle), so we have to split the finite non-past stem and
		-- active participle stem.
		local nonpast_stem = q(nonpast_stem_base, form56 and a_base_suffix or i_base_suffix)
		local ap_stem = q(nonpast_stem_base, i_base_suffix)
		local past_pass_stem = q(past_pass_stem_base, i_base_suffix)
		local nonpast_pass_stem = q(nonpast_stem_base, a_base_suffix)
		-- imperative stem
		local imp_stem = q(past_stem_base, form56 and a_base_suffix or i_base_suffix)

		-- make parts
		if final_weak then
			make_augmented_final_weak_verb(base, past_stem, past_pass_stem, nonpast_stem, nonpast_pass_stem, imp_stem,
				prefix_vowel, form56)
		else
			make_sound_verb(base, past_stem, past_pass_stem, nonpast_stem, nonpast_pass_stem, imp_stem, prefix_vowel)
		end

		-- active and passive participle
		if final_weak then
			insert_form(base, "ap", q(MU, ap_stem, IN))
			insert_form(base, "pp", q(MU, nonpast_pass_stem, AN, AMAQ))
		else
			insert_form(base, "ap", q(MU, ap_stem, UNS))
			insert_form(base, "pp", q(MU, nonpast_pass_stem, UNS))
		end
	end

	-- Generate finite parts of a hollow or geminate verb from ten stems (vowel and consonant stems for each of past and
	-- non-past, active and passive, plus imperative) plus the prefix vowel in the active non-past ("a" or "u"), plus a flag
	-- indicating if we are a geminate verb.
	local function make_hollow_geminate_verb(base, geminate, past_v_stem, past_c_stem, past_pass_v_stem, past_pass_c_stem,
			nonpast_v_stem, nonpast_c_stem, nonpast_pass_v_stem, nonpast_pass_c_stem, imp_v_stem, imp_c_stem, prefix_vowel)
		past_2stem_conj(base, "past", past_v_stem, past_c_stem)
		past_2stem_conj(base, "past_pass", past_pass_v_stem, past_pass_c_stem)
		nonpast_2stem_conj(base, "ind", prefix_vowel, nonpast_v_stem, nonpast_c_stem)
		nonpast_2stem_conj(base, "sub", prefix_vowel, nonpast_v_stem, nonpast_c_stem)
		nonpast_2stem_conj(base, "ind_pass", "u", nonpast_pass_v_stem, nonpast_pass_c_stem)
		nonpast_2stem_conj(base, "sub_pass", "u", nonpast_pass_v_stem, nonpast_pass_c_stem)
		if geminate then
			jussive_gem_conj(base, "juss", prefix_vowel, nonpast_v_stem, nonpast_c_stem)
			jussive_gem_conj(base, "juss_pass", "u", nonpast_pass_v_stem, nonpast_pass_c_stem)
			make_gem_imperative(base, imp_v_stem, imp_c_stem)
		else
			nonpast_2stem_conj(base, "juss", prefix_vowel, nonpast_v_stem, nonpast_c_stem)
			nonpast_2stem_conj(base, "juss_pass", "u", nonpast_pass_v_stem, nonpast_pass_c_stem)
			make_2stem_imperative(base, imp_v_stem, imp_c_stem)
		end
	end

	-- Generate finite parts of an augmented (form II+) hollow verb, given:
	-- * `base` (conjugation data structure);
	-- * `vowel_spec` (radicals, weakness);
	-- * `past_stem_base` (invariable part of active past stem);
	-- * `nonpast_stem_base` (invariable part of nonpast stem);
	-- * `past_pass_stem_base` (invariable part of passive past stem);
	-- * `vn` (verbal noun).
	local function make_augmented_hollow_verb(base, vowel_spec, past_stem_base, nonpast_stem_base, past_pass_stem_base, vn)
		insert_form(base, "vn", vn)

		local rad3 = vowel_spec.rad3
		local form410 = base.verb_form == "IV" or base.verb_form == "X"
		local prefix_vowel = prefix_vowel_from_vform(base.verb_form)

		local a_base_suffix_v, a_base_suffix_c
		local i_base_suffix_v, i_base_suffix_c

		a_base_suffix_v = q(AA, rad3)         -- 'af-āl-a, inf-āl-a
		a_base_suffix_c = q(A, rad3)      -- 'af-al-tu, inf-al-tu
		i_base_suffix_v = q(II, rad3)         -- 'uf-īl-a, unf-īl-a
		i_base_suffix_c = q(I, rad3)      -- 'uf-il-tu, unf-il-tu

		-- past and non-past stems, active and passive, for vowel-initial and
		-- consonant-initial endings
		local past_v_stem = q(past_stem_base, a_base_suffix_v)
		local past_c_stem = q(past_stem_base, a_base_suffix_c)
		-- yu-f-īl-u, ya-staf-īl-u but yanf-āl-u, yaft-āl-u
		local nonpast_v_stem = q(nonpast_stem_base, form410 and i_base_suffix_v or a_base_suffix_v)
		local nonpast_c_stem = q(nonpast_stem_base, form410 and i_base_suffix_c or a_base_suffix_c)
		local past_pass_v_stem = q(past_pass_stem_base, i_base_suffix_v)
		local past_pass_c_stem = q(past_pass_stem_base, i_base_suffix_c)
		local nonpast_pass_v_stem = q(nonpast_stem_base, a_base_suffix_v)
		local nonpast_pass_c_stem = q(nonpast_stem_base, a_base_suffix_c)

		-- imperative stem
		local imp_v_stem = q(past_stem_base, form410 and i_base_suffix_v or a_base_suffix_v)
		local imp_c_stem = q(past_stem_base, form410 and i_base_suffix_c or a_base_suffix_c)

		-- make parts
		make_hollow_geminate_verb(base, false, past_v_stem, past_c_stem, past_pass_v_stem,
			past_pass_c_stem, nonpast_v_stem, nonpast_c_stem, nonpast_pass_v_stem,
			nonpast_pass_c_stem, imp_v_stem, imp_c_stem, prefix_vowel)

		-- active participle
		insert_form(base, "ap", q(MU, nonpast_v_stem, UNS))
		-- passive participle
		insert_form(base, "pp", q(MU, nonpast_pass_v_stem, UNS))
	end

	-- Generate finite parts of an augmented (form II+) geminate verb, given:
	-- * `base` (conjugation data structure);
	-- * `vowel_spec` (radicals, weakness);
	-- * `past_stem_base` (invariable part of active past stem; this and the stem bases below will end with a consonant for
	--                     forms IV, X, IVq, and a short vowel for the others);
	-- * `nonpast_stem_base` (invariable part of nonpast stem);
	-- * `past_pass_stem_base` (invariable part of passive past stem);
	-- * `vn` (verbal noun).
	local function make_augmented_geminate_verb(base, vowel_spec, past_stem_base, nonpast_stem_base, past_pass_stem_base,
			vn)
		insert_form(base, "vn", vn)

		local vform = base.verb_form
		local rad3 = vowel_spec.rad3
		local prefix_vowel = prefix_vowel_from_vform(vform)

		local a_base_suffix_v, a_base_suffix_c
		local i_base_suffix_v, i_base_suffix_c

		if vform == "IV" or vform == "X" or vform == "IVq" then
			a_base_suffix_v = q(A, rad3, SH)         -- 'af-all
			a_base_suffix_c = q(SK, rad3, A, rad3)  -- 'af-lal
			i_base_suffix_v = q(I, rad3, SH)         -- yuf-ill
			i_base_suffix_c = q(SK, rad3, I, rad3)  -- yuf-lil
		else
			a_base_suffix_v = q(rad3, SH)         -- fā-ll, infa-ll
			a_base_suffix_c = q(rad3, A, rad3)  -- fā-lal, infa-lal
			i_base_suffix_v = q(rad3, SH)         -- yufā-ll, yanfa-ll
			i_base_suffix_c = q(rad3, I, rad3)  -- yufā-lil, yanfa-lil
		end

		-- past and non-past stems, active and passive, for vowel-initial and
		-- consonant-initial endings
		local past_v_stem = q(past_stem_base, a_base_suffix_v)
		local past_c_stem = q(past_stem_base, a_base_suffix_c)
		local nonpast_v_stem = q(nonpast_stem_base, vform_nonpast_a_vowel(vform) and a_base_suffix_v or i_base_suffix_v)
		local nonpast_c_stem = q(nonpast_stem_base, vform_nonpast_a_vowel(vform) and a_base_suffix_c or i_base_suffix_c)
		-- vform III and VI passive past do not have contracted parts, only
		-- uncontracted parts, which are added separately by those functions
		local past_pass_v_stem = (vform == "III" or vform == "VI") and {} or q(past_pass_stem_base, i_base_suffix_v)
		local past_pass_c_stem = q(past_pass_stem_base, i_base_suffix_c)
		local nonpast_pass_v_stem = q(nonpast_stem_base, a_base_suffix_v)
		local nonpast_pass_c_stem = q(nonpast_stem_base, a_base_suffix_c)

		-- imperative stem
		local imp_v_stem = q(past_stem_base, vform_nonpast_a_vowel(vform) and a_base_suffix_v or i_base_suffix_v)
		local imp_c_stem = q(past_stem_base, vform_nonpast_a_vowel(vform) and a_base_suffix_c or i_base_suffix_c)

		-- make parts
		make_hollow_geminate_verb(base, "geminate", past_v_stem, past_c_stem, past_pass_v_stem,
			past_pass_c_stem, nonpast_v_stem, nonpast_c_stem, nonpast_pass_v_stem,
			nonpast_pass_c_stem, imp_v_stem, imp_c_stem, prefix_vowel)

		-- active participle
		insert_form(base, "ap", q(MU, nonpast_v_stem, UNS))
		-- passive participle
		insert_form(base, "pp", q(MU, nonpast_pass_v_stem, UNS))
	end

	-------------------------------------------------------------------------------
	--            Conjugation functions for specific conjugation types           --
	-------------------------------------------------------------------------------

	local function form_i_imp_stem_through_rad1(nonpast_vowel, rad1)
		local imp_vowel = map_vowel(nonpast_vowel, function(vow)
			if vow == A or vow == I then
				return I
			elseif vow == U then
				return U
			else
				error(("Internal error: Non-past vowel %s isn't a, i, or u, should have been caught earlier"):format(
					dump(nonpast_vowel)))
			end
		end)

		-- Careful, ALIF on its own can't be transliterated properly.
		if req(rad1, HAMZA) then
			return map(imp_vowel, function(vow)
				return ALIF .. imp_vowel == I and II or UU
			end)
		else
			local vowel_on_alif = map_vowel(imp_vowel, function(vow)
				return ALIF .. vow
			end)
			return q(vowel_on_alif, rad1, SK)
		end
	end

	-- Implement form-I sound or assimilated verb. ASSIMILATED is true for assimilated verbs.
	local function make_form_i_sound_assimilated_verb(base, vowel_spec, assimilated)
		local rad1, rad2, rad3, past_vowel, nonpast_vowel = get_radicals_3(vowel_spec)

		-- Verbal nouns (maṣādir) for form I are unpredictable and have to be supplied

		-- past and non-past stems, active and passive
		local past_stem = q(rad1, A, rad2, past_vowel, rad3)
		local nonpast_stem = assimilated and q(rad2, nonpast_vowel, rad3) or
			q(rad1, SK, rad2, nonpast_vowel, rad3)
		local past_pass_stem = q(rad1, U, rad2, I, rad3)
		local nonpast_pass_stem = q(rad1, SK, rad2, A, rad3)

		-- imperative stem
		-- check for irregular verb with reduced imperative (أَخَذَ or أَكَلَ or أَمَرَ)
		local reducedimp = reduced_imperative_verb(rad1, rad2, rad3)
		if reducedimp then
			base.irregular = true
		end
		local imp_stem_suffix = q(rad2, nonpast_vowel, rad3)
		local imp_stem_base = (assimilated or reducedimp) and "" or form_i_imp_stem_through_rad1(nonpast_vowel, rad1)
		local imp_stem = q(imp_stem_base, imp_stem_suffix)

		-- make parts
		make_sound_verb(base, past_stem, past_pass_stem, nonpast_stem, nonpast_pass_stem, imp_stem, "a")

		-- Check for irregular verb سَأَلَ with alternative jussive and imperative.  Calling this after make_sound_verb() adds
		-- additional entries to the paradigm parts.
		if saal_radicals(rad1, rad2, rad3) then
			base.irregular = true
			nonpast_1stem_conj(base, "juss", "a", "سَل")
			nonpast_1stem_conj(base, "juss_pass", "u", "سَل")
			make_1stem_imperative(base, "سَل")
		end

		-- active participle
		insert_form(base, "ap", q(rad1, AA, rad2, I, rad3, UNS))
		-- passive participle
		insert_form(base, "pp", q(MA, rad1, SK, rad2, UU, rad3, UNS))
	end

	conjugations["I-sound"] = function(base, vowel_spec)
		make_form_i_sound_assimilated_verb(base, vowel_spec, false)
	end

	conjugations["irreg-sound"] = function(base, vowel_spec)
		-- All default stems are nil.
		make_sound_verb(base)
	end

	conjugations["irreg-hollow"] = function(base, vowel_spec)
		-- All default stems are nil.
		make_hollow_geminate_verb(base, false)
	end

	conjugations["irreg-geminate"] = function(base, vowel_spec)
		-- All default stems are nil.
		make_hollow_geminate_verb(base, "geminate")
	end

	conjugations["irreg-final-weak"] = function(base, vowel_spec)
		-- All default stems are nil.
		make_final_weak_verb(base)
	end

	conjugations["I-assimilated"] = function(base, vowel_spec)
		make_form_i_sound_assimilated_verb(base, vowel_spec, "assimilated")
	end

	local function make_form_i_hayy_verb(base)
		-- Verbal nouns (maṣādir) for form I are unpredictable and have to be supplied
		base.irregular = true

		-- past and non-past stems, active and passive, and imperative stem
		local past_c_stem = "حَيِي"
		local past_v_stem_long = past_c_stem
		local past_v_stem_short = "حَيّ"
		local past_pass_c_stem = "حُيِي"
		local past_pass_v_stem_long = past_pass_c_stem
		local past_pass_v_stem_short = "حُيّ"

		local nonpast_stem = "حْي"
		local nonpast_pass_stem = nonpast_stem
		local imp_stem = _I .. nonpast_stem

		-- make parts

		past_2stem_conj(base, "past", {}, past_c_stem)
		past_2stem_conj(base, "past_pass", {}, past_pass_c_stem)
		if base.variant == "short" or base.variant == "both" then
			past_2stem_conj(base, "past", past_v_stem_short, {})
			past_2stem_conj(base, "past_pass", past_pass_v_stem_short, {})
		end
		function inflect_long_variant(tense, long_stem, short_stem)
			inflect_tense_1(base, tense, "",
				{long_stem, long_stem, long_stem, long_stem, short_stem},
				{past_endings[4], past_endings[5], past_endings[7], past_endings[8],
				 past_endings[12]},
				{"3ms", "3fs", "3md", "3fd", "3mp"})
		end
		if variant == "long" or variant == "both" then
			inflect_long_variant("past", past_v_stem_long, past_v_stem_short)
			inflect_long_variant("past_pass", past_pass_v_stem_long, past_pass_v_stem_short)
		end

		nonpast_1stem_conj(base, "ind", "a", nonpast_stem, ind_endings_aa)
		nonpast_1stem_conj(base, "sub", "a", nonpast_stem, sub_endings_aa)
		nonpast_1stem_conj(base, "juss", "a", nonpast_stem, juss_endings_aa)
		nonpast_1stem_conj(base, "ind_pass", "u", nonpast_pass_stem, ind_endings_aa)
		nonpast_1stem_conj(base, "sub_pass", "u", nonpast_pass_stem, sub_endings_aa)
		nonpast_1stem_conj(base, "juss_pass", "u", nonpast_pass_stem, juss_endings_aa)
		inflect_tense_imp(base, imp_stem, imp_endings_aa)

		-- active and passive participles apparently do not exist for this verb
	end

	-- Implement form-I final-weak assimilated+final-weak verb. ASSIMILATED is true for assimilated verbs.
	local function make_form_i_final_weak_verb(base, vowel_spec, assimilated)
		local rad1, rad2, rad3, past_vowel, nonpast_vowel = get_radicals_3(vowel_spec)

		-- حَيَّ or حَيِيَ is weird enough that we handle it as a separate function
		if hayy_radicals(rad1, rad2, rad3) then
			make_form_i_hayy_verb(base)
			return
		end

		-- Verbal nouns (maṣādir) for form I are unpredictable and have to be supplied.

		-- Past and non-past stems, active and passive, and imperative stem.
		local past_stem = q(rad1, A, rad2)
		local past_pass_stem = q(rad1, U, rad2)
		local nonpast_stem, nonpast_pass_stem, imp_stem
		if raa_radicals(rad1, rad2, rad3) then
			base.irregular = true
			nonpast_stem = rad1
			nonpast_pass_stem = rad1
			imp_stem = rad1
		else
			nonpast_pass_stem = q(rad1, SK, rad2)
			if assimilated then
				nonpast_stem = rad2
				imp_stem = rad2
			else
				nonpast_stem = nonpast_pass_stem
				imp_stem = q(form_i_imp_stem_through_rad1(nonpast_vowel, rad1), rad2)
			end
		end

		-- Make parts.
		local past_ending_vowel =
			req(rad3, Y) and req(past_vowel, A) and "ay" or
			req(rad3, W) and req(past_vowel, A) and "aw" or
			past_vowel == "i" and "ī" or "ū"
		-- Try to preserve footnotes attached to the third radical and/or past and/or non-past vowels.
		local past_footnotes = iut.combine_footnotes(rget_footnotes(rad3), rget_footnotes(past_vowel))
		local nonpast_ending_vowel = nonpast_vowel == "a" and "ā" or nonpast_vowel == "i" and "ī" or "ū"
		local nonpast_footnotes = iut.combine_footnotes(rget_footnotes(rad3), rget_footnotes(nonpast_vowel))
		make_final_weak_verb(base,
			iut.combine_form_and_footnotes(past_stem, past_footnotes),
			iut.combine_form_and_footnotes(past_pass_stem, past_footnotes),
			iut.combine_form_and_footnotes(nonpast_stem, nonpast_footnotes),
			iut.combine_form_and_footnotes(nonpast_pass_stem, nonpast_footnotes),
			iut.combine_form_and_footnotes(imp_stem, nonpast_footnotes),
			past_ending_vowel, nonpast_ending_vowel, "a")

		-- active participle
		insert_form(base, "ap", q(rad1, AA, rad2, IN))
		insert_form(base, "pp", q(MA, rad1, SK, rad2, req(rad3, Y) and II or UU, SH, UNS))
	end

	conjugations["I-final-weak"] = function(base, vowel_spec)
		make_form_i_final_weak_verb(base, vowel_spec, false)
	end

	conjugations["I-assimilated+final-weak"] = function(base, vowel_spec)
		make_form_i_final_weak_verb(base, vowel_spec, "assimilated")
	end

	conjugations["I-hollow"] = function(base, vowel_spec)
		local rad1, rad2, rad3, past_vowel, nonpast_vowel = get_radicals_3(vowel_spec)
		-- Formerly we signaled an error when past_vowel is "a" but that seems too harsh. We can interpret a past vowel of
		-- "a" as meaning to use the non-past vowel in forms requiring a short vowel. If the non-past vowel is "a" then the
		-- past vowel can only be "i" (e.g. in nāma yanāmu with first singular past of nimtu).
		if req(past_vowel, A) then
			-- error("For form I hollow, past vowel cannot be 'a'")
			past_vowel = map_vowel(past_vowel, function(vow)
				return req(nonpast_vowel, A) and I or rget(nonpast_vowel)
			end)
		end
		local lengthened_nonpast = map_vowel(nonpast_vowel, function(vow)
			return vow == U and UU or vow == I and II or AA
		end)

		-- Verbal nouns (maṣādir) for form I are unpredictable and have to be supplied.

		-- active past stems - vowel (v) and consonant (c)
		local past_v_stem = q(rad1, AA, rad3)
		local past_c_stem = q(rad1, past_vowel, rad3)

		-- active non-past stems - vowel (v) and consonant (c)
		local nonpast_v_stem = q(rad1, lengthened_nonpast, rad3)
		local nonpast_c_stem = q(rad1, nonpast_vowel, rad3)

		-- passive past stems - vowel (v) and consonant (c)
		-- 'ufīla, 'ufiltu
		local past_pass_v_stem = q(rad1, II, rad3)
		local past_pass_c_stem = q(rad1, I, rad3)

		-- passive non-past stems - vowel (v) and consonant (c)
		-- yufāla/yufalna
		-- stem is built differently but conjugation is identical to sound verbs
		local nonpast_pass_v_stem = q(rad1, AA, rad3)
		local nonpast_pass_c_stem = q(rad1, A, rad3)

		-- imperative stem
		local imp_v_stem = nonpast_v_stem
		local imp_c_stem = nonpast_c_stem

		-- make parts
		make_hollow_geminate_verb(base, false, past_v_stem, past_c_stem, past_pass_v_stem,
			past_pass_c_stem, nonpast_v_stem, nonpast_c_stem, nonpast_pass_v_stem,
			nonpast_pass_c_stem, imp_v_stem, imp_c_stem, "a")

		-- active participle
		insert_form(base, "ap", req(rad3, HAMZA) and q(rad1, AA, HAMZA, IN) or
			q(rad1, AA, HAMZA, I, rad3, UNS))
		-- passive participle
		insert_form(base, "pp", q(MA, rad1, req(rad2, Y) and II or UU, rad3, UNS))
	end

	conjugations["I-geminate"] = function(base, vowel_spec)
		local rad1, rad2, rad3, past_vowel, nonpast_vowel = get_radicals_3(vowel_spec)

		-- Verbal nouns (maṣādir) for form I are unpredictable and have to be supplied.

		-- active past stems - vowel (v) and consonant (c)
		local past_v_stem = q(rad1, A, rad2, SH)
		local past_c_stem = q(rad1, A, rad2, past_vowel, rad2)

		-- active non-past stems - vowel (v) and consonant (c)
		local nonpast_v_stem = q(rad1, nonpast_vowel, rad2, SH)
		local nonpast_c_stem = q(rad1, SK, rad2, nonpast_vowel, rad2)

		-- passive past stems - vowel (v) and consonant (c)
		-- dulla/dulilta
		local past_pass_v_stem = q(rad1, U, rad2, SH)
		local past_pass_c_stem = q(rad1, U, rad2, I, rad2)

		-- passive non-past stems - vowel (v) and consonant (c)
		--yudallu/yudlalna
		-- stem is built differently but conjugation is identical to sound verbs
		local nonpast_pass_v_stem = q(rad1, A, rad2, SH)
		local nonpast_pass_c_stem = q(rad1, SK, rad2, A, rad2)

		-- imperative stem
		local imp_v_stem = q(rad1, nonpast_vowel, rad2, SH)
		local imp_c_stem = q(form_i_imp_stem_through_rad1(nonpast_vowel, rad1), rad2, nonpast_vowel, rad2)

		-- make parts
		make_hollow_geminate_verb(base, "geminate", past_v_stem, past_c_stem, past_pass_v_stem,
			past_pass_c_stem, nonpast_v_stem, nonpast_c_stem, nonpast_pass_v_stem,
			nonpast_pass_c_stem, imp_v_stem, imp_c_stem, "a")

		-- active participle
		insert_form(base, "ap", q(rad1, AA, rad2, SH, UNS))
		-- passive participle
		insert_form(base, "pp", q(MA, rad1, SK, rad2, UU, rad2, UNS))
	end

	-- Make form II or V sound or final-weak verb.
	local function make_form_ii_v_sound_final_weak_verb(base, vowel_spec)
		local rad1, rad2, rad3 = get_radicals_3(vowel_spec)
		local final_weak = is_final_weak(base, vowel_spec)
		local vform = base.verb_form
		local vn = vform == "V" and
			q(TA, rad1, A, rad2, SH, final_weak and IN or q(U, rad3, UNS)) or
			q(TA, rad1, SK, rad2, II, final_weak and AH or rad3, UNS)
		local ta_pref = vform == "V" and TA or ""
		local tu_pref = vform == "V" and TU or ""

		-- various stem bases
		local past_stem_base = q(ta_pref, rad1, A, rad2, SH)
		local nonpast_stem_base = past_stem_base
		local past_pass_stem_base = q(tu_pref, rad1, U, rad2, SH)

		-- make parts
		make_augmented_sound_final_weak_verb(base, vowel_spec, past_stem_base, nonpast_stem_base, past_pass_stem_base, vn)
	end

	conjugations["II-sound"] = function(base, vowel_spec)
		make_form_ii_v_sound_final_weak_verb(base, vowel_spec)
	end

	conjugations["II-final-weak"] = function(base, vowel_spec)
		make_form_ii_v_sound_final_weak_verb(base, vowel_spec)
	end

	-- Make form III or VI sound or final-weak verb.
	local function make_form_iii_vi_sound_final_weak_verb(base, vowel_spec)
		local rad1, rad2, rad3 = get_radicals_3(vowel_spec)
		local final_weak = is_final_weak(base, vowel_spec)
		local vform = base.verb_form
		local vn = vform == "VI" and
			q(TA, rad1, AA, rad2, final_weak and IN or q(U, rad3, UNS)) or
			q(MU, rad1, AA, rad2, final_weak and AAH or q(A, rad3, AH), UNS)
		local ta_pref = vform == "VI" and TA or ""
		local tu_pref = vform == "VI" and TU or ""

		-- various stem bases
		local past_stem_base = q(ta_pref, rad1, AA, rad2)
		local nonpast_stem_base = past_stem_base
		local past_pass_stem_base = q(tu_pref, rad1, UU, rad2)

		-- make parts
		make_augmented_sound_final_weak_verb(base, vowel_spec, past_stem_base, nonpast_stem_base, past_pass_stem_base, vn)
		if vform == "III" then
			-- Insert alternative verbal noun فِعَال. Since not all verbs have this, we require that verbs that do have it
			-- specify it explicitly; a shortcut ++ is provided to make this easier (e.g. <vn:+,++> to indicate that both
			-- the normal verbal noun مُفَاعَلَة and secondary verbal noun فِعَال are available).
			insert_form(base, "vn2", q(rad1, I, rad2, AA, final_weak and HAMZA or rad3, UNS))
		end
	end

	conjugations["III-sound"] = function(base, vowel_spec)
		make_form_iii_vi_sound_final_weak_verb(base, vowel_spec)
	end

	conjugations["III-final-weak"] = function(base, vowel_spec)
		make_form_iii_vi_sound_final_weak_verb(base, vowel_spec)
	end

	-- Make form III or VI geminate verb.
	local function make_form_iii_vi_geminate_verb(base, vowel_spec)
		local rad1, rad2, rad3 = get_radicals_3(vowel_spec)
		local vform = base.verb_form
		-- Alternative verbal noun فِعَال will be inserted when we add sound parts below.
		local vn = vform == "VI" and
			{q(TA, rad1, AA, rad2, SH, UNS)} or
			{q(MU, rad1, AA, rad2, SH, AH, UNS)}
		local ta_pref = vform == "VI" and TA or ""
		local tu_pref = vform == "VI" and TU or ""

		-- Various stem bases.
		local past_stem_base = q(ta_pref, rad1, AA)
		local nonpast_stem_base = past_stem_base
		local past_pass_stem_base = q(tu_pref, rad1, UU)

		-- Make parts.
		make_augmented_geminate_verb(base, vowel_spec, past_stem_base, nonpast_stem_base, past_pass_stem_base, vn)

		-- Also add alternative sound (non-compressed) parts. This will lead to some duplicate entries, but they are removed
		-- during addition.
		make_form_iii_vi_sound_final_weak_verb(base, vowel_spec)
	end

	conjugations["III-geminate"] = function(base, vowel_spec)
		make_form_iii_vi_geminate_verb(base, vowel_spec)
	end

	-- Make form IV sound or final-weak verb.
	local function make_form_iv_sound_final_weak_verb(base, vowel_spec)
		local rad1, rad2, rad3 = get_radicals_3(vowel_spec)
		local final_weak = is_final_weak(base, vowel_spec)

		-- core of stem base, minus stem prefixes
		local stem_core

		-- check for irregular verb أَرَى
		if raa_radicals(rad1, rad2, rad3) then
			base.irregular = true
			stem_core = rad1
		else
			stem_core =	q(rad1, SK, rad2)
		end

		-- verbal noun
		local vn = q(HAMZA, I, stem_core, AA, final_weak and HAMZA or rad3, UNS)

		-- various stem bases
		local past_stem_base = q(HAMZA, A, stem_core)
		local nonpast_stem_base = stem_core
		local past_pass_stem_base = q(HAMZA, U, stem_core)

		-- make parts
		make_augmented_sound_final_weak_verb(base, vowel_spec, past_stem_base, nonpast_stem_base, past_pass_stem_base, vn)
	end

	conjugations["IV-sound"] = function(base, vowel_spec)
		make_form_iv_sound_final_weak_verb(base, vowel_spec)
	end

	conjugations["IV-final-weak"] = function(base, vowel_spec)
		make_form_iv_sound_final_weak_verb(base, vowel_spec)
	end

	conjugations["IV-hollow"] = function(base, vowel_spec)
		-- verbal noun
		local vn = q(HAMZA, I, rad1, AA, rad3, AH, UNS)

		-- various stem bases
		local past_stem_base = q(HAMZA, A, rad1)
		local nonpast_stem_base = rad1
		local past_pass_stem_base = q(HAMZA, U, rad1)

		-- make parts
		make_augmented_hollow_verb(base, vowel_spec, past_stem_base, nonpast_stem_base, past_pass_stem_base, vn)
	end

	conjugations["IV-geminate"] = function(base, vowel_spec)
		local vn = q(HAMZA, I, rad1, SK, rad2, AA, rad2, UNS)

		-- various stem bases
		local past_stem_base = q(HAMZA, A, rad1)
		local nonpast_stem_base = rad1
		local past_pass_stem_base = q(HAMZA, U, rad1)

		-- make parts
		make_augmented_geminate_verb(base, vowel_spec, past_stem_base, nonpast_stem_base, past_pass_stem_base, vn)
	end

	conjugations["V-sound"] = function(base, vowel_spec)
		make_form_ii_v_sound_final_weak_verb(base, vowel_spec)
	end

	conjugations["V-final-weak"] = function(base, vowel_spec)
		make_form_ii_v_sound_final_weak_verb(base, vowel_spec)
	end

	conjugations["VI-sound"] = function(base, vowel_spec)
		make_form_iii_vi_sound_final_weak_verb(base, vowel_spec)
	end

	conjugations["VI-final-weak"] = function(base, vowel_spec)
		make_form_iii_vi_sound_final_weak_verb(base, vowel_spec)
	end

	conjugations["VI-geminate"] = function(base, vowel_spec)
		make_form_iii_vi_geminate_verb(base, vowel_spec)
	end

	-- Make a verbal noun of the general form that applies to forms VII and above. RAD12 is the first consonant cluster
	-- (after initial اِ) and RAD34 is the second consonant cluster. RAD5 is the final consonant.
	local function high_form_verbal_noun(rad12, rad34, rad5)
		return q(_I, rad12, I, rad34, AA, rad5, UNS)
	end

	-- Populate a sound or final-weak verb for any of the various high-numbered augmented forms (form VII and up) that have
	-- up to 5 consonants in two clusters in the stem and the same pattern of vowels between.  Some of these consonants in
	-- certain verb parts are w's, which leads to apparent anomalies in certain stems of these parts, but these anomalies
	-- are handled automatically in postprocessing, where we resolve sequences of iwC -> īC, uwC -> ūC, w + sukūn + w -> w +
	-- shadda.

	-- RAD12 is the first consonant cluster (after initial اِ) and RAD34 is the second consonant cluster. RAD5 is the final
	-- consonant.
	local function make_high_form_sound_final_weak_verb(base, vowel_spec, rad12, rad34, rad5)
		local final_weak = is_final_weak(base, vowel_spec)
		local vn = high_form_verbal_noun(rad12, rad34, final_weak and HAMZA or rad5)

		-- various stem bases
		local nonpast_stem_base = q(rad12, A, rad34)
		local past_stem_base = q(_I, nonpast_stem_base)
		local past_pass_stem_base = q(_U, rad12, U, rad34)

		-- make parts
		make_augmented_sound_final_weak_verb(base, vowel_spec, past_stem_base, nonpast_stem_base, past_pass_stem_base, vn)
	end

	-- Make form VII sound or final-weak verb.
	local function make_form_vii_sound_final_weak_verb(base, vowel_spec)
		make_high_form_sound_final_weak_verb(base, vowel_spec, q("نْ", rad1), rad2, rad3)
	end

	conjugations["VII-sound"] = function(base, vowel_spec)
		make_form_vii_sound_final_weak_verb(base, vowel_spec)
	end

	conjugations["VII-final-weak"] = function(base, vowel_spec)
		make_form_vii_sound_final_weak_verb(base, vowel_spec)
	end

	conjugations["VII-hollow"] = function(base, vowel_spec)
		local nrad1 = q("نْ", rad1)
		local vn = high_form_verbal_noun(nrad1, Y, rad3)

		-- various stem bases
		local nonpast_stem_base = nrad1
		local past_stem_base = q(_I, nonpast_stem_base)
		local past_pass_stem_base = q(_U, nrad1)

		-- make parts
		make_augmented_hollow_verb(base, vowel_spec, past_stem_base, nonpast_stem_base, past_pass_stem_base, vn)
	end

	conjugations["VII-geminate"] = function(base, vowel_spec)
		local rad1, rad2, rad3 = get_radicals_3(vowel_spec)
		local nrad1 = q("نْ", rad1)
		local vn = high_form_verbal_noun(nrad1, rad2, rad2)

		-- various stem bases
		local nonpast_stem_base = q(nrad1, A)
		local past_stem_base = q(_I, nonpast_stem_base)
		local past_pass_stem_base = q(_U, nrad1, U)

		-- make parts
		make_augmented_geminate_verb(base, vowel_spec, past_stem_base, nonpast_stem_base, past_pass_stem_base, vn)
	end

	-- Join the infixed tā' (ت) to the first radical in form VIII verbs. This may cause assimilation of the tā' to the
	-- radical or in some cases the radical to the tā'.
	local function join_ta(rad)
		local function eq(val)
			return req(rad, val)
		end
		if eq(W) or eq(Y) or eq("ت") then return "تّ"
		elseif eq("د") then return "دّ"
		elseif eq("ث") then return "ثّ"
		elseif eq("ذ") then return "ذّ"
		elseif eq("ز") then return "زْد"
		elseif eq("ص") then return "صْط"
		elseif eq("ض") then return "ضْط"
		elseif eq("ط") then return "طّ"
		elseif eq("ظ") then return "ظّ"
		else return q(rad, SK, "ت")
		end
	end

	-- Return Form VIII verbal noun. If RAD1 is hamza, there are two alternatives.
	local function form_viii_verbal_noun(base, vowel_spec, rad1, rad2, rad3)
		local final_weak = is_final_weak(base, vowel_spec)
		rad3 = final_weak and HAMZA or rad3
		local vn = high_form_verbal_noun(join_ta(rad1), rad2, rad3)
		if req(rad1, HAMZA) then
			return {vn, high_form_verbal_noun(Y .. T, rad2, rad3)}
		else
			return {vn}
		end
	end

	-- Make form VIII sound or final-weak verb.
	local function make_form_viii_sound_final_weak_verb(base, vowel_spec)
		-- check for irregular verb اِتَّخَذَ
		if axadh_radicals(rad1, rad2, rad3) then
			base.irregular = true
			rad1 = T
		end
		make_high_form_sound_final_weak_verb(base, vowel_spec, join_ta(rad1), rad2, rad3)

		-- Add alternative parts if verb is first-hamza. Any duplicates are removed during addition.
		if req(rad1, HAMZA) then
			local vn = form_viii_verbal_noun(vowel_spec, rad1, rad2, rad3)
			local past_stem_base2 = q("اِيتَ", rad2)
			local nonpast_stem_base2 = q(join_ta(rad1), A, rad2)
			local past_pass_stem_base2 = q("اُوتُ", rad2)
			make_augmented_sound_final_weak_verb(base, vowel_spec, past_stem_base2, nonpast_stem_base2,
				past_pass_stem_base2, vn)
		end
	end

	conjugations["VIII-sound"] = function(base, vowel_spec)
		make_form_viii_sound_final_weak_verb(base, vowel_spec)
	end

	conjugations["VIII-final-weak"] = function(base, vowel_spec)
		make_form_viii_sound_final_weak_verb(base, vowel_spec)
	end

	conjugations["VIII-hollow"] = function(base, vowel_spec)
		local vn = form_viii_verbal_noun(vowel_spec, rad1, Y, rad3)

		-- various stem bases
		local nonpast_stem_base = join_ta(rad1)
		local past_stem_base = q(_I, nonpast_stem_base)
		local past_pass_stem_base = q(_U, nonpast_stem_base)

		-- make parts
		make_augmented_hollow_verb(base, vowel_spec, past_stem_base, nonpast_stem_base, past_pass_stem_base, vn)

		-- Add alternative parts if verb is first-hamza. Any duplicates are removed during addition.
		if req(rad1, HAMZA) then
			local past_stem_base2 = "اِيت"
			local nonpast_stem_base2 = nonpast_stem_base
			local past_pass_stem_base2 = "اُوت"
			make_augmented_hollow_verb(base, vowel_spec, past_stem_base2, nonpast_stem_base2, past_pass_stem_base2, vn)
		end
	end

	conjugations["VIII-geminate"] = function(base, vowel_spec)
		local vn = form_viii_verbal_noun(vowel_spec, rad1, rad2, rad2)

		-- various stem bases
		local nonpast_stem_base = q(join_ta(rad1), A)
		local past_stem_base = q(_I, nonpast_stem_base)
		local past_pass_stem_base = q(_U, join_ta(rad1), U)

		-- make parts
		make_augmented_geminate_verb(base, vowel_spec, past_stem_base, nonpast_stem_base, past_pass_stem_base, vn)

		-- Add alternative parts if verb is first-hamza. Any duplicates are removed during addition.
		if req(rad1, HAMZA) then
			local past_stem_base2 = "اِيتَ"
			local nonpast_stem_base2 = nonpast_stem_base
			local past_pass_stem_base2 = "اُوتُ"
			make_augmented_geminate_verb(base, vowel_spec, past_stem_base2, nonpast_stem_base2, past_pass_stem_base2, vn)
		end
	end

	conjugations["IX-sound"] = function(base, vowel_spec)
		local ipref = _I
		local vn = q(ipref, rad1, SK, rad2, I, rad3, AA, rad3, UNS)

		-- various stem bases
		local nonpast_stem_base = q(rad1, SK, rad2, A)
		local past_stem_base = q(ipref, nonpast_stem_base)
		local past_pass_stem_base = q(_U, rad1, SK, rad2, U)

		-- make parts
		make_augmented_geminate_verb(base, vowel_spec, past_stem_base, nonpast_stem_base, past_pass_stem_base, vn)
	end

	conjugations["IX-final-weak"] = function(base, vowel_spec)
		error("FIXME: Not yet implemented")
	end

	-- Populate a sound or final-weak verb for any of the various high-numbered
	-- augmented forms that have 5 consonants in the stem and the same pattern of
	-- vowels. Some of these consonants in certain verb parts are w's, which leads to
	-- apparent anomalies in certain stems of these parts, but these anomalies
	-- are handled automatically in postprocessing, where we resolve sequences of
	-- iwC -> īC, uwC -> ūC, w + sukūn + w -> w + shadda.
	local function make_high5_form_sound_final_weak_verb(base, vowel_spec, rad1, rad2, rad3, rad4, rad5)
		make_high_form_sound_final_weak_verb(base, vowel_spec, q(rad1, SK, rad2), q(rad3, SK, rad4), rad5)
	end

	-- Make form X sound or final-weak verb.
	local function make_form_x_sound_final_weak_verb(base, vowel_spec)
		make_high5_form_sound_final_weak_verb(base, vowel_spec, S, T, rad1, rad2, rad3)
		-- check for irregular verb اِسْتَحْيَا (also اِسْتَحَى)
		if hayy_radicals(rad1, rad2, rad3) then
			base.irregular = true
			-- Add alternative entries to the verbal paradigms. Any duplicates are removed during addition.
			make_high_form_sound_final_weak_verb(base, vowel_spec, S .. SK .. T, rad1, rad3)
		end
	end

	conjugations["X-sound"] = function(base, vowel_spec)
		make_form_x_sound_final_weak_verb(base, vowel_spec)
	end

	conjugations["X-final-weak"] = function(base, vowel_spec)
		make_form_x_sound_final_weak_verb(base, vowel_spec)
	end

	conjugations["X-hollow"] = function(base, vowel_spec)
		local vn = q("اِسْتِ", rad1, AA, rad3, AH, UNS)

		-- various stem bases
		local past_stem_base = q("اِسْتَ", rad1)
		local nonpast_stem_base = q("سْتَ", rad1)
		local past_pass_stem_base = q("اُسْتُ", rad1)

		-- make parts
		make_augmented_hollow_verb(base, vowel_spec, past_stem_base, nonpast_stem_base, past_pass_stem_base, vn)
	end

	conjugations["X-geminate"] = function(base, vowel_spec)
		local vn = q("اِسْتِ", rad1, SK, rad2, AA, rad2, UNS)

		-- various stem bases
		local past_stem_base = q("اِسْتَ", rad1)
		local nonpast_stem_base = q("سْتَ", rad1)
		local past_pass_stem_base = q("اُسْتُ", rad1)

		-- make parts
		make_augmented_geminate_verb(base, vowel_spec, past_stem_base, nonpast_stem_base, past_pass_stem_base, vn)
	end

	conjugations["XI-sound"] = function(base, vowel_spec)
		local ipref = _I
		local vn = q(ipref, rad1, SK, rad2, II, rad3, AA, rad3, UNS)

		-- various stem bases
		local nonpast_stem_base = q(rad1, SK, rad2, AA)
		local past_stem_base = q(ipref, nonpast_stem_base)
		local past_pass_stem_base = q(_U, rad1, SK, rad2, UU)

		-- make parts
		make_augmented_geminate_verb(base, vowel_spec, past_stem_base, nonpast_stem_base, past_pass_stem_base, vn)
	end

	-- Probably no form XI final-weak, since already geminate in form; would behave as XI-sound.

	-- Make form XII sound or final-weak verb.
	local function make_form_xii_sound_final_weak_verb(base, vowel_spec)
		make_high5_form_sound_final_weak_verb(base, vowel_spec, rad1, rad2, W, rad2, rad3)
	end

	conjugations["XII-sound"] = function(base, vowel_spec)
		make_form_xii_sound_final_weak_verb(base, vowel_spec)
	end

	conjugations["XII-final-weak"] = function(base, vowel_spec)
		make_form_xii_sound_final_weak_verb(base, vowel_spec)
	end

	-- Make form XIII sound or final-weak verb.
	local function make_form_xiii_sound_final_weak_verb(base, vowel_spec)
		make_high5_form_sound_final_weak_verb(base, vowel_spec, rad1, rad2, W, W, rad3)
	end

	conjugations["XIII-sound"] = function(base, vowel_spec)
		make_form_xiii_sound_final_weak_verb(base, vowel_spec)
	end

	conjugations["XIII-final-weak"] = function(base, vowel_spec)
		make_form_xiii_sound_final_weak_verb(base, vowel_spec)
	end

	-- Make a form XIV or XV sound or final-weak verb. Last radical appears twice (if`anlala / yaf`anlilu) so if it were w
	-- or y you'd get if`anwā / yaf`anwī or if`anyā / yaf`anyī, i.e. unlike for most augmented verbs, the identity of the
	-- radical matters.
	local function make_form_xiv_xv_sound_final_weak_verb(base, vowel_spec)
		local lastrad = base.verb_form == "XV" and Y or rad3
		make_high5_form_sound_final_weak_verb(base, vowel_spec, rad1, rad2, N, rad3, lastrad)
	end

	conjugations["XIV-sound"] = function(base, vowel_spec)
		make_form_xiv_xv_sound_final_weak_verb(base, vowel_spec)
	end

	conjugations["XIV-final-weak"] = function(base, vowel_spec)
		make_form_xiv_xv_sound_final_weak_verb(base, vowel_spec)
	end

	conjugations["XV-sound"] = function(base, vowel_spec)
		make_form_xiv_xv_sound_final_weak_verb(base, vowel_spec)
	end

	-- Probably no form XV final-weak, since already final-weak in form; would behave as XV-sound.

	-- Make form Iq or IIq sound or final-weak verb.
	local function make_form_iq_iiq_sound_final_weak_verb(base, vowel_spec)
		local rad1, rad2, rad3, rad4 = get_radicals_4(vowel_spec)
		local final_weak = is_final_weak(base, vowel_spec)
		local vform = base.verb_form
		local vn = vform == "IIq" and
			q(TA, rad1, A, rad2, SK, rad3, (final_weak and IN or q(U, rad4, UNS))) or
			q(rad1, A, rad2, SK, rad3, (final_weak and AAH or q(A, rad4, AH)), UNS)
		local ta_pref = vform == "IIq" and TA or ""
		local tu_pref = vform == "IIq" and TU or ""

		-- various stem bases
		local past_stem_base = q(ta_pref, rad1, A, rad2, SK, rad3)
		local nonpast_stem_base = past_stem_base
		local past_pass_stem_base = q(tu_pref, rad1, U, rad2, SK, rad3)

		-- make parts
		make_augmented_sound_final_weak_verb(base, vowel_spec, past_stem_base, nonpast_stem_base, past_pass_stem_base)
	end

	conjugations["Iq-sound"] = function(base, vowel_spec)
		make_form_iq_iiq_sound_final_weak_verb(base, vowel_spec)
	end

	conjugations["Iq-final-weak"] = function(base, vowel_spec)
		make_form_iq_iiq_sound_final_weak_verb(base, vowel_spec)
	end

	conjugations["IIq-sound"] = function(base, vowel_spec)
		make_form_iq_iiq_sound_final_weak_verb(base, vowel_spec)
	end

	conjugations["IIq-final-weak"] = function(base, vowel_spec)
		make_form_iq_iiq_sound_final_weak_verb(base, vowel_spec)
	end

	-- Make form IIIq sound or final-weak verb.
	local function make_form_iiiq_sound_final_weak_verb(base, vowel_spec)
		local rad1, rad2, rad3, rad4 = get_radicals_4(vowel_spec)
		make_high5_form_sound_final_weak_verb(base, vowel_spec, rad1, rad2, N, rad3, rad4)
	end

	conjugations["IIIq-sound"] = function(base, vowel_spec)
		make_form_iiiq_sound_final_weak_verb(base, vowel_spec)
	end

	conjugations["IIIq-final-weak"] = function(base, vowel_spec)
		make_form_iiiq_sound_final_weak_verb(base, vowel_spec)
	end

	conjugations["IVq-sound"] = function(base, vowel_spec)
		local rad1, rad2, rad3, rad4 = get_radicals_4(vowel_spec)
		local ipref = _I
		local vn = q(ipref, rad1, SK, rad2, I, rad3, SK, rad4, AA, rad4, UNS)

		-- various stem bases
		local past_stem_base = q(ipref, rad1, SK, rad2, A, rad3)
		local nonpast_stem_base = q(rad1, SK, rad2, A, rad3)
		local past_pass_stem_base = q(_U, rad1, SK, rad2, U, rad3)

		-- make parts
		make_augmented_geminate_verb(base, vowel_spec, past_stem_base, nonpast_stem_base, past_pass_stem_base, vn)
	end

	-- Probably no form IVq final-weak, since already geminate in form; would behave as IVq-sound.
end

create_conjugations()

-------------------------------------------------------------------------------
--                       Guts of main conjugation function                   --
-------------------------------------------------------------------------------

-- Given form, weakness and radicals, check to make sure the radicals present are allowable for the weakness. Hamzas on
-- alif/wāw/yāʾ seats are never allowed (should always appear as hamza-on-the-line), and various weaknesses have various
-- strictures on allowable consonants. FIXME: Still needed?
local function check_radicals(form, weakness, rad1, rad2, rad3, rad4)
	local function hamza_check(index, rad)
		if rad == HAMZA_ON_ALIF or rad == HAMZA_UNDER_ALIF or
			rad == HAMZA_ON_W or rad == HAMZA_ON_Y then
			error("Radical " .. index .. " is " .. rad .. " but should be ء (hamza on the line)")
		end
	end
	local function check_waw_ya(index, rad)
		if not is_waw_ya(rad) then
			error("Radical " .. index .. " is " .. rad .. " but should be و or ي")
		end
	end
	local function check_not_waw_ya(index, rad)
		if is_waw_ya(rad) then
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
	elseif vform_supports_final_weak(form) then
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
			error("Internal error: No geminate quadrilaterals, should not be seen")
		end
		if rad2 ~= rad3 then
			error("Weakness is geminate; radical 3 is " .. rad3 .. " but should be same as radical 2 " .. rad2)
		end
	elseif vform_supports_geminate(form) then
		-- non-geminate verbs cannot have second and third radical same if there's
		-- a corresponding geminate verb category. I think this is safe. We
		-- don't fuss over double wāw or double yāʾ because this could legitimately
		-- be a final-weak verb with middle wāw/yāʾ, treated as sound.
		if rad4 then
			error("Internal error: No quadrilaterals should support geminate verbs")
		end
		if rad2 == rad3 and not is_waw_ya(rad2) then
			error("Weakness is '" .. weakness .. "'; radical 2 and 3 are same at " .. rad2 .. " but should not be; consider making weakness 'geminate'")
		end
	end
end

-- Determine weakness from radicals. FIXME: This may not be necessary any more.
local function weakness_from_radicals(form, rad1, rad2, rad3, rad4)
	local weakness = nil
	local quadlit = rmatch(form, "q$")
	-- If weakness unspecified, derive from radicals.
	if not quadlit then
		if is_waw_ya(rad3) and rad1 == W and form == "I" then
			weakness = "assimilated+final-weak"
		elseif is_waw_ya(rad3) and vform_supports_final_weak(form) then
			weakness = "final-weak"
		elseif rad2 == rad3 and vform_supports_geminate(form) then
			weakness = "geminate"
		elseif is_waw_ya(rad2) and vform_supports_hollow(form) then
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

local postprocess_tr_subs = {
	{"ī([" .. V .. "y*])", "iy%1"},
	{"ū([" .. V .. "w*])", "uw%1"},
	{"(.)%*", "%1%1"}, -- implement shadda

	---------------------------- assimilated verbs ----------------------------
	-- iw -> ī (assimilated verbs)
	{"iw(" .. NV .. ")", "ī%1"},
	-- uy -> ū (assimilated verbs)
	{"uy(" .. NV .. ")", "ū%1"},

	----------------------- handle hamza assimilation -------------------------
	-- initial hamza + short-vowel + hamza + sukūn -> hamza + long vowel
	{"ʔaʔ(" .. NV .. ")", "ʔā%1"},
	{"ʔiʔ(" .. NV .. ")", "ʔī%1"},
	{"ʔuʔ(" .. NV .. ")", "ʔū%1"},
}

-- Post-process verb parts to eliminate phonological anomalies. Many of the changes, particularly the tricky ones,
-- involve converting hamza to have the proper seat. The rules for this are complicated and are documented on the
-- [[w:Hamza]] Wikipedia page. In some cases there are alternatives allowed, and we handle them below by returning
-- multiple possibilities.
local function postprocess_term(term)
	if term == "?" then
		return "?"
	end
	-- Add BORDER at text boundaries.
	term = BORDER .. term .. BORDER
	-- Do the main post-processing, based on the pattern substitutions in postprocess_subs.
	for _, sub in ipairs(postprocess_subs) do
		term = rsub(term, sub[1], sub[2])
	end
	term = term:gsub(BORDER, "")
	if not rfind(term, HAMZA) then
		return term
	end
	term = term:gsub(HAMZA, HAMZA_PH)
	term = ar_utilities.process_hamza(term)
	if #term == 1 then
		term = term[1]
	end
	return term
end

local function postprocess_translit(translit)
	if translit == "?" then
		return "?"
	end
	-- Add BORDER at text boundaries.
	translit = BORDER .. translit .. BORDER
	-- Do the main post-processing, based on the pattern substitutions in postprocess_tr_subs.
	for _, sub in ipairs(postprocess_tr_subs) do
		translit = rsub(translit, sub[1], sub[2])
	end
	translit = translit:gsub(BORDER, "")
	return translit
end

local function postprocess_forms(base)
	local converted_values = {}
	for slot, forms in pairs(base.forms) do
		local need_dedup = false
		for i, form in ipairs(forms) do
			local term = postprocess_term(form.form)
			local translit = form.translit and postprocess_translit(form.translit) or nil
			if term ~= form.form or translit ~= form.translit then
				need_dedup = true
			end
			converted_values[i] = {term, translit}
		end
		if need_dedup then
			local temp_dedup = {}
			for i = 1, #forms do
				local new_term, new_translit = unpack(converted_values[i])
				if type(new_term) == "table" then
					for _, nt in ipairs(new_term) do
						local new_formobj = {
							form = nt,
							translit = new_translit,
							footnotes = forms[i].footnotes,
						}
						iut.insert_form(temp_dedup, "temp", new_formobj)
					end
				else
					local new_formobj = {
						form = new_term,
						translit = new_translit,
						footnotes = forms[i].footnotes,
					}
					iut.insert_form(temp_dedup, "temp", new_formobj)
				end
			end
			base.forms[slot] = temp_dedup.temp
		end
	end
end

local function process_slot_overrides(base)
	for slot, forms in pairs(base.slot_overrides) do
		local existing_values = base.forms[slot]
		base.forms[slot] = nil
		for _, form in ipairs(forms) do
			if form.form == "+" then
				if not existing_values then
					error(("Slot '%s' requested the default value but no such value available"):format(slot))
				end
				-- We maintain an invariant that no two slots share a form object (although they may share the footnote
				-- lists inside the form objects). However, there is no need to copy the form objects here because there
				-- is a one-to-one correspondence between slots and slot overrides, i.e. you can't have a default value
				-- go into two slots.
				insert_forms(base, slot, existing_values, "allow overrides")
			elseif form.form == "++" then
				if slot ~= "vn" then
					error(("Secondary default value request '++' only applicable to verbal nouns, but found in slot '%s'"):
					format(slot))
				end
				local existing_values = base.forms.vn2
				if not existing_values then
					error(("Slot '%s' requested the secondary default value but no such value available"):format(slot))
				end
				-- See comment above about the lack of need to copy the form objects.
				insert_forms(base, slot, existing_values, "allow overrides")
				-- To make sure there aren't shared form objects.
				base.forms.vn2 = nil
			else
				insert_form(base, slot, form, "allow overrides")
			end
		end
	end
end


local function handle_lemma_linked(base)
	-- Compute linked versions of potential lemma slots, for use in {{ar-verb}}. We substitute the original lemma
	-- (before removing links) for forms that are the same as the lemma, if the original lemma has links.
	for _, slot in ipairs(potential_lemma_slots) do
		insert_forms(base, slot .. "_linked", iut.map_forms(base.forms[slot], function(form)
			if form == base.lemma and rfind(base.linked_lemma, "%[%[") then
				return base.linked_lemma
			else
				return form
			end
		end))
	end
end


-- Process specs given by the user using 'addnote[SLOTSPEC][FOOTNOTE][FOOTNOTE][...]'.
local function process_addnote_specs(base)
	for _, spec in ipairs(base.addnote_specs) do
		for _, slot_spec in ipairs(spec.slot_specs) do
			slot_spec = "^" .. slot_spec .. "$"
			for slot, forms in pairs(base.forms) do
				if rfind(slot, slot_spec) then
					-- To save on memory, side-effect the existing forms.
					for _, form in ipairs(forms) do
						form.footnotes = iut.combine_footnotes(form.footnotes, spec.footnotes)
					end
				end
			end
		end
	end
end


local function add_missing_links_to_forms(base)
	-- Any forms without links should get them now. Redundant ones will be stripped later.
	for slot, forms in pairs(base.forms) do
		for _, form in ipairs(forms) do
			if not form.form:find("%[%[") then
				form.form = "[[" .. form.form .. "]]"
			end
		end
	end
end


local function conjugate_verb(base)
	construct_stems(base)
	for _, vowel_spec in ipairs(base.conj_vowels) do
		-- Reconstruct conjugation type from verb form and (possibly inferred) weakness.
		conj_type = base.verb_form .. "-" .. vowel_spec.weakness

		-- Check that the conjugation type is recognized.
		if not conjugations[conj_type] then
			error("Unknown conjugation type '" .. conj_type .. "'")
		end

		-- The way the conjugation functions work is they always add entries to the appropriate parts of the paradigm
		-- (each of which is an array), rather than setting the values. This makes it possible to call more than one
		-- conjugation function and essentially get a paradigm of the "either A or B" kind. Doing this may insert
		-- duplicate entries into a particular paradigm part, but this is not a problem because we check for duplicate
		-- entries when adding them, and don't insert in that case.
		conjugations[conj_type](base, vowel_spec)
	end
	postprocess_forms(base)
	process_slot_overrides(base)
	-- This should happen before add_missing_links_to_forms() so that the comparison `form == base.lemma` in
	-- handle_lemma_linked() works correctly and compares unlinked forms to unlinked forms.
	handle_lemma_linked(base)
	process_addnote_specs(base)
	if not base.alternant_multiword_spec.args.noautolinkverb then
		add_missing_links_to_forms(base)
	end
end


local function parse_indicator_spec(angle_bracket_spec)
	-- Store the original angle bracket spec so we can reconstruct the overall conj spec with the lemma(s) in them.
	local base = {
		angle_bracket_spec = angle_bracket_spec,
		conj_vowels = {},
		root_consonants = {},
		user_stem_overrides = {},
		user_slot_overrides = {},
		slot_explicitly_missing = {},
		slot_uses_default = {},
		addnote_specs = {},
	}
	local function parse_err(msg)
		error(msg .. ": " .. angle_bracket_spec)
	end
	local function fetch_footnotes(separated_group)
		local footnotes
		for j = 2, #separated_group - 1, 2 do
			if separated_group[j + 1] ~= "" then
				parse_err("Extraneous text after bracketed footnotes: '" .. table.concat(separated_group) .. "'")
			end
			if not footnotes then
				footnotes = {}
			end
			table.insert(footnotes, separated_group[j])
		end
		return footnotes
	end

	local inside = angle_bracket_spec:match("^<(.*)>$")
	assert(inside)
	local segments = iut.parse_multi_delimiter_balanced_segment_run(inside, {{"[", "]"}, {"<", ">"}})
	local dot_separated_groups = iut.split_alternating_runs_and_strip_spaces(segments, "%.")

	-- The first dot-separated element must specify the verb form, e.g. IV or IIq. If the form is I, it needs to include
	-- the the past and non-past vowels, e.g.  I/a~u for kataba ~ yaktubu. More than one vowel can be given,
	-- comma-separated, and more than one past~non-past pair can be given, slash-separated, e.g. I/a,u~u/i~a for form I
	-- كمل, which can be conjugated as kamala/kamula ~ yakmulu or kamila ~ yakmalu. An individual vowel spec must be one
	-- of a, i or u and in general (a) at least one past~non-past pair most be given, and (b) both past and non-past
	-- vowels must be given even though sometimes the vowel can be determined from the unvocalized form. An exception is
	-- passive-only verbs, where the vowels can't in general be determined (except indirectly in some cases by looking
	-- at an associated non-passive verb); in that case, the vowel~vowel spec can left out.
	local slash_separated_groups = iut.split_alternating_runs_and_strip_spaces(dot_separated_groups[1], "/")
	local form_spec = slash_separated_groups[1]
	base.form_footnotes = fetch_footnotes(form_spec)
	if form_spec[1] == "" then
		parse_err("Missing verb form")
	end
	if not allowed_vforms_with_weakness_set[form_spec[1]] then
		parse_err(("Unrecognized verb form '%s', should be one of %s"):format(
			form_spec[1], m_table.serialCommaJoin(allowed_vforms, {conj = "or", dontTag = true})))
	end
	if form_spec[1]:find("%-") then
		base.verb_form, base.explicit_weakness = form_spec[1]:match("^(.-)%-(.*)$")
	else
		base.verb_form = form_spec[1]
	end

	if #slash_separated_groups > 1 then
		if base.verb_form ~= "I" then
			parse_err(("Past~non-past vowels can only be specified when verb form is I, but saw form '%s'"):format(
				base.verb_form))
		end
		for i = 2, #slash_separated_groups do
			local slash_separated_group = slash_separated_groups[i]
			local tilde_separated_groups = iut.split_alternating_runs_and_strip_spaces(slash_separated_group, "~")
			if #tilde_separated_groups ~= 2 then
				parse_err(("Expected two tilde-separated vowel specs: %s"):format(table.concat(slash_separated_group)))
			end
			local function parse_conj_vowels(tilde_separated_group, vtype)
				local conj_vowel_objects = {}
				local comma_separated_groups = iut.split_alternating_runs_and_strip_spaces(tilde_separated_group, ",")
				for _, comma_separated_group in ipairs(comma_separated_groups) do
					local conj_vowel = comma_separated_group[1]
					if conj_vowel ~= "a" and conj_vowel ~= "i" and conj_vowel ~= "u" then
						parse_err(("Expected %s conjugation vowel '%s' to be one of a, i or u in %s"):format(
							vtype, conj_vowel, table.concat(slash_separated_group)))
					end
					conj_vowel = dia[conj_vowel]
					local conj_vowel_footnotes = fetch_footnotes(comma_separated_group)
					-- Try to use strings when possible as it makes q() significantly more efficient.
					if conj_vowel_footnotes then
						table.insert(conj_vowel_objects, {form = conj_vowel, footnotes = conj_vowel_footnotes})
					else
						table.insert(conj_vowel_objects, conj_vowel)
					end
				end
				return conj_vowel_objects
			end
			local conj_vowel_spec = {
				past = parse_conj_vowels(tilde_separated_groups[1], "past"),
				nonpast = parse_conj_vowels(tilde_separated_groups[2], "non-past"),
			}
			table.insert(base.conj_vowels, conj_vowel_spec)
		end
	end

	for i = 2, #dot_separated_groups do
		local dot_separated_group = dot_separated_groups[i]
		local first_element = dot_separated_group[1]
		if first_element == "addnote" then
			local spec_and_footnotes = fetch_footnotes(dot_separated_group)
			if #spec_and_footnotes < 2 then
				parse_err("Spec with 'addnote' should be of the form 'addnote[SLOTSPEC][FOOTNOTE][FOOTNOTE][...]'")
			end
			local slot_spec = table.remove(spec_and_footnotes, 1)
			local slot_spec_inside = rmatch(slot_spec, "^%[(.*)%]$")
			if not slot_spec_inside then
				parse_err("Internal error: slot_spec " .. slot_spec .. " should be surrounded with brackets")
			end
			local slot_specs = rsplit(slot_spec_inside, ",")
			-- FIXME: Here, [[Module:it-verb]] called strip_spaces(). Generally we don't do this. Should we?
			table.insert(base.addnote_specs, {slot_specs = slot_specs, footnotes = spec_and_footnotes})
		elseif first_element:find("^var:") then
			if #dot_separated_group > 1 then
				parse_err(("Can't attach footnotes to 'var:' spec '%s'"):format(first_element))
			end
			base.var = first_element:match("^var:(.*)$")
		elseif first_element:find("^I+V?:") then
			if #dot_separated_group > 1 then
				parse_err(("Can't attach footnotes to root consonant spec '%s'"):format(first_element))
			end
			local root_cons, root_cons_value = first_element:match("^(I+V?):(.*)$")
			local root_index
			if root_cons == "I" then
				root_index = 1
			elseif root_cons == "II" then
				root_index = 2
			elseif root_cons == "III" then
				root_index = 3
			elseif root_cons == "IV" then
				root_index = 4
				if not base.verb_form:find("q$") then
					parse_err(("Can't specify root consonant IV for non-quadriliteral verb form '%s': %s"):format(
						base.verb_form, first_element))
				end
			end
			local cons, translit = root_cons_value:match("^(.*)//(.*)$")
			if not cons then
				cons = root_cons_value
			end
			base.root_consonants[root_index] = {form = cons, translit = translit}
		elseif first_element:find("^[a-z][a-z0-9_]*:") then
			local slot_or_stem, remainder = first_element:match("^(.-):(.*)$")
			dot_separated_group[1] = remainder
			local comma_separated_groups = iut.split_alternating_runs_and_strip_spaces(dot_separated_group, "[,،]")
			if overridable_stems[slot_or_stem] then
				if base.user_stem_overrides[slot_or_stem] then
					parse_err("Overridable stem '" .. slot_or_stem .. "' specified twice")
				end
				base.user_stem_overrides[slot_or_stem] = overridable_stems[slot_or_stem](comma_separated_groups,
					{prefix = slot_or_stem, base = base, parse_err = parse_err, fetch_footnotes = fetch_footnotes})
			else -- assume a form override; we validate further later when the possible slots are available
				if base.user_slot_overrides[slot_or_stem] then
					parse_err("Form override '" .. slot_or_stem .. "' specified twice")
				end
				base.user_slot_overrides[slot_or_stem] = allow_multiple_values_for_override(comma_separated_groups,
					{prefix = slot_or_stem, base = base, parse_err = parse_err, fetch_footnotes = fetch_footnotes},
					"is form override")
			end
		elseif indicator_flags[first_element] then
			if #dot_separated_group > 1 then
				parse_err("No footnotes allowed with '" .. first_element .. "' spec")
			end
			if base[first_element] then
				parse_err("Spec '" .. first_element .. "' specified twice")
			end
			base[first_element] = true
		else
			local passive, uncertain = first_element:match("^(.*)(%?)$")
			passive = passive or first_element
			uncertain = not not uncertain
			if passive_types[passive] then
				if #dot_separated_group > 1 then
					parse_err("No footnotes allowed with '" .. passive .. "' spec")
				end
				if base.passive then
					parse_err("Value for passive type specified twice")
				end
				base.passive = passive
				base.passive_uncertain = uncertain
			else
				parse_err("Unrecognized spec '" .. first_element .. "'")
			end
		end
	end

	return base
end


-- Normalize all lemmas, substituting the pagename for blank lemmas and adding links to multiword lemmas.
local function normalize_all_lemmas(alternant_multiword_spec, head)

	-- (1) Add links to all before and after text. Remember the original text so we can reconstruct the verb spec later.
	if not alternant_multiword_spec.args.noautolinktext then
		iut.add_links_to_before_and_after_text(alternant_multiword_spec, "remember original")
	end

	-- (2) Remove any links from the lemma, but remember the original form so we can use it below in the 'lemma_linked'
	--     form.
	iut.map_word_specs(alternant_multiword_spec, function(base)
		if base.lemma == "" then
			base.lemma = head
		end

		base.user_specified_lemma = base.lemma

		base.lemma = m_links.remove_links(base.lemma)
		base.user_specified_verb = base.lemma
		base.verb = base.user_specified_verb

		local linked_lemma
		if alternant_multiword_spec.args.noautolinkverb or base.user_specified_lemma:find("%[%[") then
			linked_lemma = base.user_specified_lemma
		else
			-- Add links to the lemma so the user doesn't specifically need to, since we preserve
			-- links in multiword lemmas and include links in non-lemma forms rather than allowing
			-- the entire form to be a link.
			linked_lemma = iut.add_links(base.user_specified_lemma)
		end
		base.linked_lemma = linked_lemma
	end)
end


local function detect_indicator_spec(base)
	base.forms = {}
	base.stem_overrides = {}
	base.slot_overrides = {}

	if not base.conj_vowels[1] then
		if base.verb_form == "I" and base.passive ~= "onlypass" and base.passive ~= "impers" then
			error("Form I verb that isn't passive-only must have past~non-past vowels specified")
		end
		base.conj_vowels = {
			past = "-",
			nonpast = "-",
		}
	else
		base.unexpanded_conj_vowels = m_table.deepcopy(base.conj_vowels)
		-- If multiple vowels specified for a given vowel type (e.g. a,u~u), expand so that each spec in
		-- base.conj_vowels has just one past and one non-past vowel.
		local needs_expansion = false
		for _, spec in ipairs(base.conj_vowels) do
			if #spec.past > 1 or #spec.nonpast > 1 then
				needs_expansion = true
				break
			end
		end
		if needs_expansion then
			local expansion = {}
			for _, spec in ipairs(base.conj_vowels) do
				for _, past in ipairs(spec.past) do
					for _, nonpast in ipairs(spec.nonpast) do
						table.insert(expansion, {past = past, nonpast = nonpast})
					end
				end
			end
			base.conj_vowels = expansion
		else
			for _, spec in ipairs(base.conj_vowels) do
				spec.past = spec.past[1]
				spec.nonpast = spec.nonpast[1]
			end
		end
	end

	local vform = base.verb_form

	-- check for quadriliteral form (Iq, IIq, IIIq, IVq)
	local quadlit = rmatch(vform, "q$")

	-- Infer radicals as necessary. We infer a separate set of radicals for each past~non-past vowel combination because
	-- they may be different (particularly with form-I hollow verbs).
	for _, vowel_spec in ipairs(base.conj_vowels) do
		-- NOTE: rad1, rad2, etc. refer to user-specified radicals, which are formobj tables that optionally specify an
		-- explicit manual translit, whereas ir1, ir2, etc. refer to inferred radicals, which are strings (and may
		-- contain Latin letters to indicate ambiguousr radicals; see below).
		local rads = base.root_consonants
		local rad1, rad2, rad3, rad4 = rads[1], rads[2], rads[3], rads[4]

		-- Default any unspecified radicals to radicals determined from the headword. The returned radicals may have
		-- Latin letters in them (w, t, y) to indicate ambiguous radicals that should be converted to the corresponding
		-- Arabic letters. Note that 't' means a radical that could be any of ت/و/ي while 'w' and 'y' mean a radical
		-- that could be either و or ي.
		local weakness, ir1, ir2, ir3, ir4 =
			export.infer_radicals(base.lemma, vform, vowel_spec.past, vowel_spec.nonpast)

		-- For most ambiguous radicals, the choice of radical doesn't matter because it doesn't affect the conjugation
		-- one way or another.  For form I hollow verbs, however, it definitely does. In fact, the choice of radical is
		-- critical even beyond the past and non-past vowels because it affects the form of the passive participle.  So,
		-- check for this and signal an error if the radical could not be inferred and is not given explicitly.
		if vform == "I" and (ir2 == "w" or ir2 == "y") and not rad2 then
			error("Unable to guess middle radical of hollow form I verb; need to specify radical explicitly")
		end

		-- Convert the Latin radicals indicating ambiguity into the corresponding Arabic radicals.
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

		-- Return the appropriate radical at index `index` (1 through 4), based either on the user-specified radical
		-- `user_radical` or (if unspecified) `inferred_radical`, inferred from the unvocalized lemma. Two values are
		-- returned, the "regularized" version of the radical (where ambiguous inferred radicals are converted to their
		-- most likely actual radical) and the non-regularized version. The returned values are form objects rather than
		-- strings.
		local function fetch_radical(user_radical, inferred_radical, index)
			if not user_radical then
				return {form = regularize_inferred_radical(inferred_radical)}, {form = inferred_radical}
			else
				local allowed_radicals
				if inferred_radical == "t" then
					allowed_radicals = {T, W, Y}
				elseif inferred_radical == "w" or inferred_radical == "y" then
					allowed_radicals = {W, Y}
				end
				if allowed_radicals then
					local allowed_radical_set = m_table.listToSet(allowed_radicals)
					if not allowed_radical_set[user_radical.form] then
						error(("For lemma %s, radical %s ambiguously inferred as %s but user radical incompatibly given as %s"):
						format(base.lemma, index,
						m_table.serialCommaJoin(allowed_radicals, {conj = "or", dontTag = true}), user_radical.form))
					end
				elseif user_radical.form ~= inferred_radical then
					error(("For lemma %s, radical %s inferred as %s but user radical incompatibly given as %s"):
					format(base.lemma, index, inferred_radical, user_radical.form))
				end
				return user_radical, user_radical
			end
		end

		vowel_spec.rad1, vowel_spec.unreg_rad1 = fetch_radical(rad1, ir1, 1)
		vowel_spec.rad2, vowel_spec.unreg_rad2 = fetch_radical(rad2, ir2, 2)
		vowel_spec.rad3, vowel_spec.unreg_rad3 = fetch_radical(rad3, ir3, 3)
		if quadlit then
			vowel_spec.rad4, vowel_spec.unreg_rad4 = fetch_radical(rad4, ir4, 4)
		end

		-- If explicit weakness given using 'I-sound' or 'I-assimilated', we may need to adjust the inferred weakness.
		if base.explicit_weakness == "sound" then
			if weakness == "assimilated" then
				weakness = "sound"
			elseif weakness == "assimilated+final-weak" then
				-- Verbs like waniya~yawnā "to be faint; to languish" (although the defaults should handle this
				-- correctly)
				weakness = "final-weak"
			else
				error(("Can't specify form 'I-sound' when inferred weakness is '%s' for lemma %s"):format(
					weakness, base.lemma))
			end
		elseif base.explicit_weakness == "assimilated" then
			if weakness == "sound" then
				-- i~a verbs like waṭiʔa~yaṭaʔu "to tread, to trample"; wasiʕa~yasaʕu "to be spacious; to be well-off";
				-- waṯiʔa~yaṯaʔu "to get bruised, to be sprained", which would default to sound.
				weakness = "assimilated"
			elseif weakness == "final-weak" then
				-- For completeness; not clear if any verbs occur where this is needed. (There are plenty of
				-- assimilated+final-weak verbs but the defaults should take care of them.)
				weakness = "assimilated+final-weak"
			else
				error(("Can't specify form 'I-assimilated' when inferred weakness is '%s' for lemma %s"):format(
					weakness, base.lemma))
			end
		elseif base.explicit_weakness then
			error(("Internal error: Unrecognized value '%s' for base.explicit_weakness"):format(base.explicit_weakness))
		end

		vowel_spec.weakness = weakness

		-- Error if radicals are wrong given the weakness. More likely to happen if the weakness is explicitly given
		-- rather than inferred. Will also happen if certain incorrect letters are included as radicals e.g. hamza on
		-- top of various letters, alif maqṣūra, tā' marbūṭa. FIXME: May not be necessary?
		check_radicals(vform, weakness, vowel_spec.rad1.form, vowel_spec.rad2.form, vowel_spec.rad3.form,
			quadlit and vowel_spec.rad4.form or nil)
	end

	-- Set value of passive. If not specified, default is yes, but no for forms VII, IX,
	-- XI - XV and IIq - IVq, and "impers" for form VI.
	local passive = base.passive
	if not passive then
		if vform_probably_impersonal_passive(vform) then
			base.passive = "imperspass"
		else
			local has_passive = false
			for _, vowel_spec in ipairs(base.conj_vowels) do
				if not vform_probably_no_passive(vform, vowel_spec.weakness, vowel_spec.past, vowel_spec.nonpast) then
					has_passive = true
					break
				end
			end
			if has_passive then
				base.passive = "withpass"
				base.passive_uncertain = true
			else
				base.passive = "nopass"
			end
		end
	end

	-- NOTE: Currently there are no built-in stems or form overrides for Arabic; this code is inherited from
	-- [[Module:ca-verb]], where such things do exist, and is kept for generality in case we decide in the future to
	-- implement such things.

	-- Override built-in verb stems and overrides with user-specified ones.
	for stem, values in pairs(base.user_stem_overrides) do
		base.stem_overrides[stem] = values
	end
	for slot, values in pairs(base.user_slot_overrides) do
		if not base.alternant_multiword_spec.verb_slots_map[slot] then
			error("Unrecognized override slot '" .. slot .. "': " .. base.angle_bracket_spec)
		end
		if unsettable_slots_set[slot] then
			error("Slot '" .. slot .. "' cannot be set using an override: " .. base.angle_bracket_spec)
		end
		if skip_slot(base, slot, "allow overrides") then
			error("Override slot '" .. slot ..
				"' would be skipped based on the passive, 'noimp' and/or 'no_nonpast' settings: " ..
				base.angle_bracket_spec)
		end
		base.slot_overrides[override] = values
	end

	if base.verb_form == "irreg-final-weak" then
		for _, stem_type in ipairs { "past", "past_pass", "nonpast", "nonpast_pass" } do
			if base.stem_overrides[stem_type .. "_c"] or base.stem_overrides[stem_type .. "_v"] then
				error(("Specify past stem for verb type 'irreg-final-weak' using '%s:...' not '%s_c:...' or '%s_v:...'"):
					format(stem_type, stem_type, stem_type))
			end
		end
		for _, stem_type in ipairs { "past", "nonpast" } do
			if base.stem_overrides[stem_type] or not base.stem_overrides[stem_type .. "_final_weak_vowel"] then
				error(("For verb type 'irreg-final-weak', if '%s:...' specified, so must '%s_final_weak_vowel:...'"):
					format(stem_type, stem_type))
			end
		end
	end
end


local function detect_all_indicator_specs(alternant_multiword_spec)
	add_slots(alternant_multiword_spec)
	alternant_multiword_spec.slot_explicitly_missing = {}

	iut.map_word_specs(alternant_multiword_spec, function(base)
		-- So arguments, etc. can be accessed. WARNING: Creates circular reference.
		base.alternant_multiword_spec = alternant_multiword_spec
		detect_indicator_spec(base)
		-- User-specified indicator flags. Do these after calling detect_indicator_spec() because the latter may set
		-- these indicators for built-in verbs (at least that is the case in [[Module:ca-verb]], on which this module
		-- was based).
		for prop, _ in pairs(indicator_flags) do
			if base[prop] then
				alternant_multiword_spec[prop] = true
			end
		end
		if base.passive_uncertain then
			alternant_multiword_spec.passive_uncertain = true
		end
		-- Propagate explicitly-missing indicators up.
		for slot, val in pairs(base.slot_explicitly_missing) do
			alternant_multiword_spec.slot_explicitly_missing[slot] =
				alternant_multiword_spec.slot_explicitly_missing[slot] or val
		end
	end)
end

-- Copy default slots (active participle, passive participle, verbal noun) when overrides not provided or when an
-- override is given with the value of + or ++.
local function copy_default_slots(alternant_multiword_spec)
	if not alternant_multiword_spec.forms.ap and not alternant_multiword_spec.slot_explicitly_missing.ap then
	end
end


-- Determine certain properties of the verb from the overall forms, such as whether the verb is active-only or
-- passive-only, is impersonal, lacks an imperative, etc.
local function determine_verb_properties_from_forms(alternant_multiword_spec)
	alternant_multiword_spec.has_active = false
	alternant_multiword_spec.has_passive = false
	alternant_multiword_spec.has_non_impers_active = false
	alternant_multiword_spec.has_non_impers_passive = false
	alternant_multiword_spec.has_imp = false
	alternant_multiword_spec.has_past = false
	alternant_multiword_spec.has_nonpast = false
	for slot, _ in pairs(alternant_multiword_spec.forms) do
		if slot == "ap" or slot:find("[123]") and not slot:find("_pass") then
			alternant_multiword_spec.has_active = true
		end
		if slot == "pp" or slot:find("[123]") and slot:find("_pass") then
			alternant_multiword_spec.has_passive = true
		end
		if slot:find("[123]") and not slot:find("pass_[123]") and not slot:find("3ms") then
			alternant_multiword_spec.has_non_impers_active = true
		end
		if slot:find("pass_[123]") and not slot:find("3ms") then
			alternant_multiword_spec.has_non_impers_passive = true
		end
		if slot:find("^imp_") then
			alternant_multiword_spec.has_imp = true
		end
		if slot:find("^past_") then
			alternant_multiword_spec.has_past = true
		end
		if slot:find("^ind_") or slot:find("^sub_") or slot:find("^juss_") then
			alternant_multiword_spec.has_nonpast = true
		end
	end
end


local function add_categories_and_annotation(alternant_multiword_spec, base, multiword_lemma, insert_ann, insert_cat)
	if check_for_red_links and alternant_multiword_spec.source_template == "ar-conj" and multiword_lemma then
		for _, slot_and_accel in ipairs(alternant_multiword_spec.verb_slots) do
			local slot = slot_and_accel[1]
			local forms = base.forms[slot]
			local must_break = false
			if forms then
				for _, form in ipairs(forms) do
					if not form.form:find("%[%[") then
						local title = mw.title.new(form.form)
						if title and not title.exists then
							insert_cat("verbs with red links in their inflection tables")
							must_break = true
						break
						end
					end
				end
			end
			if must_break then
				break
			end
		end
	end

	local vform = base.verb_form
	insert_ann("form", vform)
	insert_cat("form-" .. vform .. " verbs")
	if vform_is_quadriliteral(vform) then
		insert_cat("verbs with quadriliteral roots")
	end

	for _, vowel_spec in ipairs(base.conj_vowels) do
		local rad1, rad2, rad3, rad4 = get_radicals_4(vowel_spec)
		local final_weak = is_final_weak(base, vowel_spec)
		local weakness = vowel_spec.weakness

		-- We have to distinguish weakness by form and weakness by conjugation. Weakness by form merely indicates the
		-- presence of weak letters in certain positions in the radicals. Weakness by conjugation is related to how the
		-- verbs are conjugated. For example, form-II verbs that are "hollow by form" (middle radical is wāw or yāʾ) are
		-- conjugated as sound verbs. Another example: form-I verbs with initial wāw are "assimilated by form" and most
		-- are assimilated by conjugation as well, but a few are sound by conjugation, e.g. wajuha yawjuhu "to be
		-- distinguished" (rather than wajuha yajuhu); similarly for some hollow-by-form verbs in various forms, e.g.
		-- form VIII izdawaja yazdawiju "to be in pairs" (rather than izdāja yazdāju). Categories referring to weakness
		-- always refer to weakness by conjugation; weakness by form is distinguished only by categories such as
		-- [[:Category:Arabic form-III verbs with و as second radical]].
		insert_ann("weakness", weakness)
		insert_cat(("%s form-%s verbs"):format(weakness, vform))

		local function radical_is_ambiguous(rad)
			return req(rad, "t") or req(rad, "w") or req(rad, "y")
		end
		local function radical_is_weak(rad)
			return is_waw_ya(rad) or req(rad, HAMZA)
		end
	
		local ur1, ur2, ur3, ur4 = vowel_spec.unreg_rad1, vowel_spec.unreg_rad2, vowel_spec.unreg_rad3, vowel_spec.unreg_rad4
		-- Create headword categories based on the radicals. Do the following before
		-- converting the Latin radicals into Arabic ones so we distinguish
		-- between ambiguous and non-ambiguous radicals.
		if radical_is_ambiguous(ur1) or radical_is_ambiguous(ur2) or radical_is_ambiguous(ur3) or
			ur4 and radical_is_ambiguous(ur4) then
			insert_cat("verbs with ambiguous radicals")
		end
		if radical_is_weak(ur1) then
			insert_cat("form-" .. vform ..  " verbs with " .. ur1.form .. " as first radical")
		end
		if radical_is_weak(ur2) then
			insert_cat("form-" .. vform ..  " verbs with " .. ur2.form .. " as second radical")
		end
		if radical_is_weak(ur3) then
			insert_cat("form-" .. vform ..  " verbs with " .. ur3.form .. " as third radical")
		end
		if ur4 and radical_is_weak(ur4) then
			insert_cat("form-" .. vform ..  " verbs with " .. ur4.form .. " as fourth radical")
		end
	end

	if vform == "I" and base.unexpanded_conj_vowels then
		for _, vowel_spec in ipairs(base.unexpanded_conj_vowels) do
			local past_vowels = {}
			for _, past in ipairs(vowel_spec.past) do
				table.insert(past_vowels, undia[rget(past)])
			end
			local nonpast_vowels = {}
			for _, nonpast in ipairs(vowel_spec.nonpast) do
				table.insert(nonpast_vowels, undia[rget(nonpast)])
			end
			insert_ann("vowels",
				("%s ~ %s"):format(table.concat(past_vowels, ","), table.concat(nonpast_vowels, ",")))
			for _, past in ipairs(vowel_spec.past) do
				for _, nonpast in ipairs(vowel_spec.nonpast) do
					insert_cat(("form-I verbs with past vowel %s and non-past vowel %s"):format(
						undia[rget(past)], undia[rget(nonpast)]))
				end
			end
		end
	end

	if base.irregular then
		insert_ann("irreg", "irregular")
		insert_cat("irregular verbs")
	else
		insert_ann("irreg", "regular")
	end
end


-- Compute the categories to add the verb to, as well as the annotation to display in the conjugation title bar. We
-- combine the code to do these functions as both categories and title bar contain similar information.
local function compute_categories_and_annotation(alternant_multiword_spec)
	alternant_multiword_spec.categories = {}
	local ann = {}
	alternant_multiword_spec.annotation = ann
	ann.form = {}
	ann.weakness = {}
	ann.vowels = {}
	ann.passive = nil
	ann.irreg = {}
	ann.defective = {}

	local multiword_lemma = false
    for _, slot in ipairs(potential_lemma_slots) do
        if alternant_multiword_spec.forms[slot] then
            for _, formobj in ipairs(alternant_multiword_spec.forms[slot]) do
				if formobj.form:find(" ") then
					multiword_lemma = true
					break
				end
            end 
            break
        end
    end 

	local function insert_ann(anntype, value)
		m_table.insertIfNot(alternant_multiword_spec.annotation[anntype], value)
	end

	local function insert_cat(cat, also_when_multiword)
		-- Don't place multiword terms in categories like 'Arabic form-II verbs' to avoid spamming the categories with
		-- such terms.
		if also_when_multiword or not multiword_lemma then
			m_table.insertIfNot(alternant_multiword_spec.categories, "Arabic " .. cat)
		end
	end

	iut.map_word_specs(alternant_multiword_spec, function(base)
		add_categories_and_annotation(alternant_multiword_spec, base, multiword_lemma, insert_ann, insert_cat)
	end)

	if alternant_multiword_spec.forms.vn then
		for _, form in ipairs(alternant_multiword_spec.forms.vn) do
			if form.uncertain then
				insert_cat("verbs needing verbal noun checked")
				break
			end
		end
	elseif not alternant_multiword_spec.slot_explicitly_missing.vn then
		-- Assume an unspecified and non-defaulted verbal noun (form I, form III) is omitted rather than explicitly
		-- missing. Use <vn:-> to explicitly indicate the lack of verbal noun.
		insert_cat("verbs needing verbal noun checked")
	end

	if alternant_multiword_spec.has_active then
		if alternant_multiword_spec.has_passive and alternant_multiword_spec.has_non_impers_passive then
			insert_cat("verbs with full passive")
			ann.passive = "full passive"
		elseif alternant_multiword_spec.has_passive then
			insert_cat("verbs with impersonal passive")
			ann.passive = "impersonal passive"
		else
			insert_cat("verbs lacking passive forms")
			ann.passive = "no passive"
		end
	else
		if alternant_multiword_spec.has_non_impers_passive then
			insert_cat("passive verbs")
			insert_cat("verbs with full passive")
			ann.passive = "passive-only"
		else
			insert_cat("passive verbs")
			insert_cat("impersonal verbs")
			insert_cat("verbs with impersonal passive")
			ann.passive = "impersonal (passive-only)"
		end
	end

	if alternant_multiword_spec.passive_uncertain then
		insert_cat("verbs needing passive checked")
		ann.passive = ann.passive .. ' <abbr title="passive status uncertain">(?)</abbr>'
	end

	if alternant_multiword_spec.has_active and not alternant_multiword_spec.has_imp then
		insert_ann("defective", "no imperative")
		insert_cat("verbs lacking imperative forms")
	end
	if not alternant_multiword_spec.has_past then
		insert_ann("defective", "no past")
		insert_cat("verbs lacking past forms")
	end
	if not alternant_multiword_spec.has_nonpast then
		insert_ann("defective", "no non-past")
		insert_cat("verbs lacking non-past forms")
	end

	local ann_parts = {}
	local function insert_ann_part(part)
		local val = table.concat(ann[part], " or ")
		if val ~= "" then
			table.insert(ann_parts, val)
		end
	end

	insert_ann_part("form")
	insert_ann_part("weakness")
	insert_ann_part("vowels")
	if ann.passive then
		table.insert(ann_parts, ann.passive)
	end
	insert_ann_part("irreg")
	insert_ann_part("defective")
	alternant_multiword_spec.annotation = table.concat(ann_parts, ", ")
end


local function show_forms(alternant_multiword_spec)
    local lemmas = {}
    for _, slot in ipairs(potential_lemma_slots) do
        if alternant_multiword_spec.forms[slot] then
            for _, formobj in ipairs(alternant_multiword_spec.forms[slot]) do
                table.insert(lemmas, formobj)
            end 
            break
        end
    end 

	alternant_multiword_spec.lemmas = lemmas -- save for later use in make_table()
	alternant_multiword_spec.vn = alternant_multiword_spec.forms.vn -- save for later use in make_table()

	local reconstructed_verb_spec = iut.reconstruct_original_spec(alternant_multiword_spec)

	local function transform_accel_obj(slot, formobj, accel_obj)
		if accel_obj then
			accel_obj.form = "verb-form-" .. reconstructed_verb_spec
		end
		return accel_obj
	end

	local function generate_link(data)
		local form = data.form
		local link = m_links.full_link {
			lang = lang, term = form.formval_for_link, tr = "-", accel = form.accel_obj,
			alt = form.alt, gloss = form.gloss, genders = form.genders, pos = form.pos, lit = form.lit, id = form.id,
		} .. iut.get_footnote_text(form.footnotes, data.footnote_obj)
		if form.q and form.q[1] or form.qq and form.qq[1] or form.l and form.l[1] or form.ll and form.ll[1] then
			link = require(pron_qualifier_module).format_qualifiers {
				lang = lang,
				text = link,
				q = form.q,
				qq = form.qq,
				l = form.l,
				ll = form.ll,
			}
		end
		return link
	end

	local props = {
		lang = lang,
		lemmas = lemmas,
		transform_accel_obj = transform_accel_obj,
		generate_link = generate_link,
		slot_list = alternant_multiword_spec.verb_slots,
		include_translit = true,
	}
	iut.show_forms(alternant_multiword_spec.forms, props)
end


-------------------------------------------------------------------------------
--                    Functions to create inflection tables                  --
-------------------------------------------------------------------------------

-- Make the conjugation table. Called from export.show().
local function make_table(alternant_multiword_spec)
	local notes_template = [=[
<div style="width:100%;text-align:left;background:#d9ebff">
<div style="display:inline-block;text-align:left;padding-left:1em;padding-right:1em">
{footnote}
</div></div>
]=]

	local text = [=[
<div class="NavFrame ar-conj">
<div class="NavHead" style="height:2.5em">&nbsp; &nbsp; Conjugation of {title}</div>
<div class="NavContent">

{\op}| class="inflection-table"
|-
! colspan="6" class="nonfinite-header" | verbal noun<br /><<الْمَصْدَر>>
| colspan="7" | {vn}
]=]

	if alternant_multiword_spec.has_active then
		text = text .. [=[
|-
! colspan="6" class="nonfinite-header" | active participle<br /><<اِسْم الْفَاعِل>>
| colspan="7" | {ap}
]=]
	end

	if alternant_multiword_spec.has_passive then
		text = text .. [=[
|-
! colspan="6" class="nonfinite-header" | passive participle<br /><<اِسْم الْمَفْعُول>>
| colspan="7" | {pp}
]=]
	end

	if alternant_multiword_spec.has_active then
		text = text .. [=[
|-
! colspan="12" class="voice-header" | active voice<br /><<الْفِعْل الْمَعْلُوم>>
|-
! colspan="2" class="empty-header" | 
! colspan="3" class="number-header" | singular<br /><<الْمُفْرَد>>
! rowspan="12" class="divider" | 
! colspan="2" class="number-header" | dual<br /><<الْمُثَنَّى>>
! rowspan="12" class="divider" | 
! colspan="3" class="number-header" | plural<br /><<الْجَمْع>>
|-
! colspan="2" class="empty-header" | 
! class="person-header" | 1<sup>st</sup> person<br /><<الْمُتَكَلِّم>>
! class="person-header" | 2<sup>nd</sup> person<br /><<الْمُخَاطَب>>
! class="person-header" | 3<sup>rd</sup> person<br /><<الْغَائِب>>
! class="person-header" | 2<sup>nd</sup> person<br /><<الْمُخَاطَب>>
! class="person-header" | 3<sup>rd</sup> person<br /><<الْغَائِب>>
! class="person-header" | 1<sup>st</sup> person<br /><<الْمُتَكَلِّم>>
! class="person-header" | 2<sup>nd</sup> person<br /><<الْمُخَاطَب>>
! class="person-header" | 3<sup>rd</sup> person<br /><<الْغَائِب>>
|-
! rowspan="2" class="tam-header" | past (perfect) indicative<br /><<الْمَاضِي>>
! class="gender-header" | m
| rowspan="2" | {past_1s}
| {past_2ms}
| {past_3ms}
| rowspan="2" | {past_2d}
| {past_3md}
| rowspan="2" | {past_1p}
| {past_2mp}
| {past_3mp}
|-
! class="gender-header" | f
| {past_2fs}
| {past_3fs}
| {past_3fd}
| {past_2fp}
| {past_3fp}
|-
! rowspan="2" class="tam-header" | non-past (imperfect) indicative<br /><<الْمُضَارِع الْمَرْفُوع>>
! class="gender-header" | m
| rowspan="2" | {ind_1s}
| {ind_2ms}
| {ind_3ms}
| rowspan="2" | {ind_2d}
| {ind_3md}
| rowspan="2" | {ind_1p}
| {ind_2mp}
| {ind_3mp}
|-
! class="gender-header" | f
| {ind_2fs}
| {ind_3fs}
| {ind_3fd}
| {ind_2fp}
| {ind_3fp}
|-
! rowspan="2" class="tam-header" | subjunctive<br /><<الْمُضَارِع الْمَنْصُوب>>
! class="gender-header" | m
| rowspan="2" | {sub_1s}
| {sub_2ms}
| {sub_3ms}
| rowspan="2" | {sub_2d}
| {sub_3md}
| rowspan="2" | {sub_1p}
| {sub_2mp}
| {sub_3mp}
|-
! class="gender-header" | f
| {sub_2fs}
| {sub_3fs}
| {sub_3fd}
| {sub_2fp}
| {sub_3fp}
|-
! rowspan="2" class="tam-header" | jussive<br /><<الْمُضَارِع الْمَجْزُوم>>
! class="gender-header" | m
| rowspan="2" | {juss_1s}
| {juss_2ms}
| {juss_3ms}
| rowspan="2" | {juss_2d}
| {juss_3md}
| rowspan="2" | {juss_1p}
| {juss_2mp}
| {juss_3mp}
|-
! class="gender-header" | f
| {juss_2fs}
| {juss_3fs}
| {juss_3fd}
| {juss_2fp}
| {juss_3fp}
|-
! rowspan="2" class="tam-header" | imperative<br /><<الْأَمْر>>
! class="gender-header" | m
| rowspan="2" | 
| {imp_2ms}
| rowspan="2" | 
| rowspan="2" | {imp_2d}
| rowspan="2" | 
| rowspan="2" | 
| {imp_2mp}
| rowspan="2" | 
|-
! class="gender-header" | f
| {imp_2fs}
| {imp_2fp}
]=]
	end

	if alternant_multiword_spec.has_passive then
		text = text .. [=[
|-
! colspan="12" class="voice-header" | passive voice<br /><<الْفِعْل الْمَجْهُول>>
|-
| colspan="2" class="empty-header" | 
! colspan="3" class="number-header" | singular<br /><<الْمُفْرَد>>
| rowspan="10" class="divider" | 
! colspan="2" class="number-header" | dual<br /><<الْمُثَنَّى>>
| rowspan="10" class="divider" | 
! colspan="3" class="number-header" | plural<br /><<الْجَمْع>>
|-
| colspan="2" class="empty-header" | 
! class="person-header" | 1<sup>st</sup> person<br /><<الْمُتَكَلِّم>>
! class="person-header" | 2<sup>nd</sup> person<br /><<الْمُخَاطَب>>
! class="person-header" | 3<sup>rd</sup> person<br /><<الْغَائِب>>
! class="person-header" | 2<sup>nd</sup> person<br /><<الْمُخَاطَب>>
! class="person-header" | 3<sup>rd</sup> person<br /><<الْغَائِب>>
! class="person-header" | 1<sup>st</sup> person<br /><<الْمُتَكَلِّم>>
! class="person-header" | 2<sup>nd</sup> person<br /><<الْمُخَاطَب>>
! class="person-header" | 3<sup>rd</sup> person<br /><<الْغَائِب>>
|-
! rowspan="2" class="tam-header" | past (perfect) indicative<br /><<الْمَاضِي>>
! class="gender-header" | m
| rowspan="2" | {past_pass_1s}
| {past_pass_2ms}
| {past_pass_3ms}
| rowspan="2" | {past_pass_2d}
| {past_pass_3md}
| rowspan="2" | {past_pass_1p}
| {past_pass_2mp}
| {past_pass_3mp}
|-
! class="gender-header" | f
| {past_pass_2fs}
| {past_pass_3fs}
| {past_pass_3fd}
| {past_pass_2fp}
| {past_pass_3fp}
|-
! rowspan="2" class="tam-header" | non-past (imperfect) indicative<br /><<الْمُضَارِع الْمَرْفُوع>>
! class="gender-header" | m
| rowspan="2" | {ind_pass_1s}
| {ind_pass_2ms}
| {ind_pass_3ms}
| rowspan="2" | {ind_pass_2d}
| {ind_pass_3md}
| rowspan="2" | {ind_pass_1p}
| {ind_pass_2mp}
| {ind_pass_3mp}
|-
! class="gender-header" | f
| {ind_pass_2fs}
| {ind_pass_3fs}
| {ind_pass_3fd}
| {ind_pass_2fp}
| {ind_pass_3fp}
|-
! rowspan="2" class="tam-header" | subjunctive<br /><<الْمُضَارِع الْمَنْصُوب>>
! class="gender-header" | m
| rowspan="2" | {sub_pass_1s}
| {sub_pass_2ms}
| {sub_pass_3ms}
| rowspan="2" | {sub_pass_2d}
| {sub_pass_3md}
| rowspan="2" | {sub_pass_1p}
| {sub_pass_2mp}
| {sub_pass_3mp}
|-
! class="gender-header" | f
| {sub_pass_2fs}
| {sub_pass_3fs}
| {sub_pass_3fd}
| {sub_pass_2fp}
| {sub_pass_3fp}
|-
! rowspan="2" class="tam-header" | jussive<br /><<الْمُضَارِع الْمَجْزُوم>>
! class="gender-header" | m
| rowspan="2" | {juss_pass_1s}
| {juss_pass_2ms}
| {juss_pass_3ms}
| rowspan="2" | {juss_pass_2d}
| {juss_pass_3md}
| rowspan="2" | {juss_pass_1p}
| {juss_pass_2mp}
| {juss_pass_3mp}
|-
! class="gender-header" | f
| {juss_pass_2fs}
| {juss_pass_3fs}
| {juss_pass_3fd}
| {juss_pass_2fp}
| {juss_pass_3fp}
]=]
	end

	text = text .. [=[
|{\cl}{notes_clause}</div></div>]=]

	local forms = alternant_multiword_spec.forms

	if not alternant_multiword_spec.lemmas then
		forms.title = "—"
	else
		local linked_lemmas = {}
		for _, form in ipairs(alternant_multiword_spec.lemmas) do
			table.insert(linked_lemmas, link_term(form.form, "term"))
		end
		forms.title = table.concat(linked_lemmas, ", ")
	end

	local ann_parts = {}
	if alternant_multiword_spec.annotation ~= "" then
		table.insert(ann_parts, alternant_multiword_spec.annotation)
	end
	if alternant_multiword_spec.vn then
		local linked_vns = {}
		for _, form in ipairs(alternant_multiword_spec.vn) do
			table.insert(linked_vns, link_term(form.form, "term"))
		end
		table.insert(ann_parts, (#linked_vns > 1 and "verbal nouns" or "verbal noun") .. " " ..
			table.concat(linked_vns, ", "))
	end
	local annotation = table.concat(ann_parts, ", ")
	if annotation ~= "" then
		forms.title = forms.title .. " (" .. annotation .. ")"
	end

	-- Format the table.
	forms.notes_clause = forms.footnote ~= "" and m_string_utilities.format(notes_template, forms) or ""
	local tagged_table = rsub(text, "<<(.-)>>", tag_text)
	return m_string_utilities.format(tagged_table, forms) .. mw.getCurrentFrame():extensionTag{
		name = "templatestyles", args = { src = "Template:ar-conj/style.css" }
	}
end

-------------------------------------------------------------------------------
--                              External entry points                        --
-------------------------------------------------------------------------------

-- Append two lists `l1` and `l2`, removing duplicates. If either is {nil}, just return the other.
local function combine_lists(l1, l2)
	-- combine_footnotes() does exactly what we want.
	return iut.combine_footnotes(l1, l2)
end

local function combine_ancillary_properties(data)
	local src1 = data.formobj1
	local src2 = data.formobj2
	local dest = data.dest_formobj
	dest.uncertain = src1.uncertain or src2.uncertain
	if src1.genders and src2.genders and not m_table.deepEquals(src1.genders, src2.genders) then
		-- do nothing
	else
		dest.genders = src1.genders or src2.genders
	end
	if src1.pos and src2.pos and src1.pos ~= src2.pos then
		-- do nothing
	else
		dest.pos = src1.pos or src2.pos
	end
	-- Don't copy .alt, .gloss, .lit, .id, which describe a single term and don't extend to multiword terms.
	dest.q = combine_lists(src1.q, src2.q)
	dest.qq = combine_lists(src1.qq, src2.qq)
	dest.l = combine_lists(src1.l, src2.l)
	dest.ll = combine_lists(src1.ll, src2.ll)
end

-- Externally callable function to parse and conjugate a verb given user-specified arguments.
-- Return value is WORD_SPEC, an object where the conjugated forms are in `WORD_SPEC.forms`
-- for each slot. If there are no values for a slot, the slot key will be missing. The value
-- for a given slot is a list of objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms(args, source_template, headword_head)
	local PAGENAME = mw.title.getCurrentTitle().subpageText
	local function in_template_space()
		return mw.title.getCurrentTitle().nsText == "Template"
	end

	-- Determine the verb spec we're being asked to generate the conjugation of. This may be taken from the current page
	-- title or the value of |pagename=; but not when called from {{ar-verb form of}}, where the page title is a
	-- non-lemma form. Note that the verb spec may omit the lemma; e.g. it may be "<II>". For this reason, we use the
	-- value of `pagename` computed here down below, when calling normalize_all_lemmas().
	local pagename = source_template ~= "ar-verb form of" and args.pagename or PAGENAME
	local head = headword_head or pagename
	local arg1 = args[1]

	if not arg1 then
		if (pagename == "ar-conj" or pagename == "ar-verb" or pagename == "ar-verb form of") and in_template_space() then
			arg1 = "كتب<I>"
		else
			arg1 = "<>"
		end
	end

	-- When called from {{ar-verb form of}}, determine the non-lemma form whose inflections we're being asked to
	-- determine. This normally comes from the page title or the value of |pagename=.
	local verb_form_of_form
	if source_template == "ar-verb form of" then
		verb_form_of_form = args.pagename
		if not verb_form_of_form then
			if PAGENAME == "ar-verb form of" and in_template_space() then
				verb_form_of_form = "كتبت"
			else
				verb_form_of_form = PAGENAME
			end
		end
	end

	local incorporated_headword_head_into_lemma = false
	if arg1:find("^<.*>$") then -- missing lemma
		if head:find(" ") then
			-- If multiword lemma, try to add arg spec after the first word.
			-- Try to preserve the brackets in the part after the verb, but don't do it
			-- if there aren't the same number of left and right brackets in the verb
			-- (which means the verb was linked as part of a larger expression).
			local first_word, post = rmatch(head, "^(.-)( .*)$")
			local left_brackets = rsub(first_word, "[^%[]", "")
			local right_brackets = rsub(first_word, "[^%]]", "")
			if #left_brackets == #right_brackets then
				arg1 = iut.remove_redundant_links(first_word) .. arg1 .. post
				incorporated_headword_head_into_lemma = true
			else
				-- Try again using the form without links.
				local linkless_head = m_links.remove_links(head)
				if linkless_head:find(" ") then
					first_word, post = rmatch(linkless_head, "^(.-)( .*)$")
					arg1 = first_word .. arg1 .. post
				else
					error("Unable to incorporate <...> spec into explicit head due to a multiword linked verb or " ..
						"unbalanced brackets; please include <> explicitly: " .. arg1)
				end
			end
		else
			-- Will be incorporated through `head` below in the call to normalize_all_lemmas().
			incorporated_headword_head_into_lemma = true
		end
	end

	local parse_props = {
		parse_indicator_spec = parse_indicator_spec,
		allow_default_indicator = true,
		allow_blank_lemma = true,
	}
	local alternant_multiword_spec = iut.parse_inflected_text(arg1, parse_props)
	alternant_multiword_spec.pos = pos or "verbs"
	alternant_multiword_spec.args = args
	alternant_multiword_spec.source_template = source_template
	alternant_multiword_spec.verb_form_of_form = verb_form_of_form
	alternant_multiword_spec.incorporated_headword_head_into_lemma = incorporated_headword_head_into_lemma

	normalize_all_lemmas(alternant_multiword_spec, head)
	detect_all_indicator_specs(alternant_multiword_spec)
	local inflect_props = {
		slot_list = alternant_multiword_spec.verb_slots,
		inflect_word_spec = conjugate_verb,
		combine_ancillary_properties = combine_ancillary_properties,
		-- We add links around the generated verbal forms rather than allow the entire multiword
		-- expression to be a link, so ensure that user-specified links get included as well.
		include_user_specified_links = true,
	}
	iut.inflect_multiword_or_alternant_multiword_spec(alternant_multiword_spec, inflect_props)
	copy_default_slots(alternant_multiword_spec)

	-- Remove redundant brackets around entire forms.
	for slot, forms in pairs(alternant_multiword_spec.forms) do
		for _, form in ipairs(forms) do
			form.form = iut.remove_redundant_links(form.form)
		end
	end

	determine_verb_properties_from_forms(alternant_multiword_spec)
	compute_categories_and_annotation(alternant_multiword_spec)
	if args.json and source_template == "ar-conj" then
        -- There is a circular reference in `base.alternant_multiword_spec`, which points back to top level.
        iut.map_word_specs(alternant_multiword_spec, function(base)
            base.alternant_multiword_spec = nil
        end)
		return require("Module:JSON").toJSON(alternant_multiword_spec.forms)
	end
	return alternant_multiword_spec
end


-- Entry point for {{ar-conj}}. Template-callable function to parse and conjugate a verb given
-- user-specified arguments and generate a displayable table of the conjugated forms.
function export.show(frame)
	local parent_args = frame:getParent().args
	local params = {
		[1] = {},
		["noautolinktext"] = {type = "boolean"},
		["noautolinkverb"] = {type = "boolean"},
		["pagename"] = {}, -- for testing/documentation pages
		["json"] = {type = "boolean"}, -- for bot use
	}
	local args = require("Module:parameters").process(parent_args, params)
	local alternant_multiword_spec = export.do_generate_forms(args, "ar-conj")
	if type(alternant_multiword_spec) == "string" then
		-- JSON return value
		return alternant_multiword_spec
	end
	show_forms(alternant_multiword_spec)
	return make_table(alternant_multiword_spec) ..
		require("Module:utilities").format_categories(alternant_multiword_spec.categories, lang, nil, nil, force_cat)
end


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

	local base, form, weakness, past_vowel, nonpast_vowel = conjugate(args, 1)
	local use_params = form == "I" or args["useparam"]

	local arabic_3sm_perf, latin_3sm_perf
	local arabic_3sm_imperf, latin_3sm_imperf
	if base.passive == "only" or base.passive == "only-impers" then
		arabic_3sm_perf, latin_3sm_perf = get_spans(base.forms["3sm-ps-perf"])
		arabic_3sm_imperf, latin_3sm_imperf = get_spans(base.forms["3sm-ps-impf"])
	else
		arabic_3sm_perf, latin_3sm_perf = get_spans(base.forms["3sm-perf"])
		arabic_3sm_imperf, latin_3sm_imperf = get_spans(base.forms["3sm-impf"])
	end
	
	title = mw.title.getCurrentTitle()
	NAMESPACE = title.nsText
	PAGENAME = ( NAMESPACE == "Appendix" and title.subpageText ) or title.text
	
	-- set to PAGENAME if left empty
	local heads, trs
	if use_params and form ~= "I" then
		table.insert(base.headword_categories, "Arabic augmented verbs with parameter override")
	end
	if use_params and (#args["head"] > 0 or args["tr"].maxindex > 0) then
		heads = args["head"]
		trs = args["tr"]
		if form == "I" then
			table.insert(base.headword_categories, "Arabic form-I verbs with headword perfect determined through param, not past vowel")
		end
	elseif form == "I" and #past_vowel == 0 then
		heads = {}
		table.insert(base.headword_categories, "Arabic form-I verbs with missing past vowel in headword")
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
		impf_tr = args["impftr"] or transliterate(impf_arabic)
		impf_arabic = {impf_arabic}
		if form == "I" then
			table.insert(base.headword_categories, "Arabic form-I verbs with headword imperfect determined through param, not non-past vowel")
		end
	elseif form == "I" and #nonpast_vowel == 0 then
		impf_arabic = {}
		table.insert(base.headword_categories, "Arabic form-I verbs with missing non-past vowel in headword")
	else
		impf_arabic = arabic_3sm_imperf
		impf_tr = table.concat(latin_3sm_imperf, " <small style=\"color: #888\">or</small> ")
	end

	-- convert Arabic terms to bolded links
	for i, entry in ipairs(impf_arabic) do
		impf_arabic[i] = link_term(entry, "bold")
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
		require("Module:headword").full_headword({lang = lang, pos_category = "verbs", categories = base.headword_categories,
			heads = heads, translits = trs, sort_key = args["sort"], id = args["id"]}) ..
		form_text .. impf_text
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
	for _, form in ipairs(allowed_vforms) do
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
	for _, form in ipairs(allowed_vforms) do
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
				if formprops["pp"] == nil and not vform_probably_no_passive(form,
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

-- Infer radicals from lemma headword (i.e. 3rd masculine singular past) and verb form (I, II, etc.). Throw an error if
-- headword is malformed. Returned radicals may contain Latin letters "t", "w" or "y" indicating ambiguous radicals
-- guessed to be tāʾ, wāw or yāʾ respectively.
function export.infer_radicals(headword, vform, past_vowel, nonpast_vowel)
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
				error("For verb form " .. vform .. ", letter " .. index ..
					" must be " .. must .. ", not " .. letter, 2)
			end
		elseif not m_table.contains(must, letter) then
			error("For verb form " .. vform .. ", radical " .. index ..
				" must be one of " .. table.concat(must, " ") .. ", not " .. letter, 2)
		end
	end

	-- Check that length of headword is within [min, max]
	local function check_len(min, max)
		if len < min then
			error(("Not enough letters in headword %s for verb form %s, expected at least %s"):format(
				headword, vform, min))
		elseif len > max then
			error(("Too many letters in headword %s for verb form %s, expected at most %s"):format(
				headword, vform, max))
		end
	end

	-- If the vowels are i~a or u~u, a form I verb beginning with w- normally keeps the w in the non-past. Otherwise it
	-- loses it (i.e. it is "assimilated").
	local function form_I_w_non_assimilated()
		return req(past_vowel, I) and req(nonpast_vowel, A) or req(past_vowel, U) and req(nonpast_vowel, U)
	end

	local quadlit = rmatch(vform, "q$")

	-- find first radical, start of second/third radicals, check for
	-- required letters
	local radstart, rad1, rad2, rad3, rad4
	local weakness
	if vform == "I" or vform == "II" then
		rad1 = ch[1]
		radstart = 2
	elseif vform == "III" then
		rad1 = ch[1]
		check(2, {ALIF, W}) -- W occurs in passive-only verbs
		radstart = 3
	elseif vform == "IV" then
		-- this would be alif-madda but we replaced it with hamza-alif above.
		if ch[1] == HAMZA and ch[2] == ALIF then
			rad1 = HAMZA
		else
			check(1, HAMZA_ON_ALIF)
			rad1 = ch[2]
		end
		radstart = 3
	elseif vform == "V" then
		check(1, T)
		rad1 = ch[2]
		radstart = 3
	elseif vform == "VI" then
		check(1, T)
		if ch[2] == AMAD then
			rad1 = HAMZA
			radstart = 3
		else
			rad1 = ch[2]
			check(3, {ALIF, W}) -- W occurs in passive-only verbs
			radstart = 4
		end
	elseif vform == "VII" then
		check(1, ALIF)
		check(2, N)
		rad1 = ch[3]
		radstart = 4
	elseif vform == "VIII" then
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
	elseif vform == "IX" then
		check(1, ALIF)
		rad1 = ch[2]
		radstart = 3
	elseif vform == "X" then
		check(1, ALIF)
		check(2, S)
		check(3, T)
		rad1 = ch[4]
		radstart = 5
	elseif vform == "Iq" then
		rad1 = ch[1]
		rad2 = ch[2]
		radstart = 3
	elseif vform == "IIq" then
		check(1, T)
		rad1 = ch[2]
		rad2 = ch[3]
		radstart = 4
	elseif vform == "IIIq" then
		check(1, ALIF)
		rad1 = ch[2]
		rad2 = ch[3]
		check(4, N)
		radstart = 5
	elseif vform == "IVq" then
		check(1, ALIF)
		rad1 = ch[2]
		rad2 = ch[3]
		radstart = 4
	elseif vform == "XI" then
		check_len(5, 5)
		check(1, ALIF)
		rad1 = ch[2]
		rad2 = ch[3]
		check(4, ALIF)
		rad3 = ch[5]
		weakness = "sound"
	elseif vform == "XII" then
		check(1, ALIF)
		rad1 = ch[2]
		if ch[3] ~= ch[5] then
			error("For verb form XII, letters 3 and 5 of headword " .. headword .. " should be the same")
		end
		check(4, W)
		radstart = 5
	elseif vform == "XIII" then
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
	elseif vform == "XIV" then
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
				error("For verb form XIV, letters 5 and 6 of headword " .. headword .. " should be the same")
			end
			weakness = "sound"
		end
	elseif vform == "XV" then
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
		error("Don't recognize verb form " .. vform)
	end

	-- Process the last two radicals. RADSTART is the index of the first of the two. If it's nil then all radicals have
	-- already been processed above, and we don't do anything.
	if radstart ~= nil then
		-- There must be one or two letters left.
		check_len(radstart, radstart + 1)
		if len == radstart then
			-- If one letter left, then it's a geminate verb.
			if vform_supports_geminate(vform) then
				weakness = "geminate"
				rad2 = ch[len]
				rad3 = ch[len]
			else
				-- Oops, geminate verbs not allowed in this verb form; signal an error.
				check_len(radstart + 1, radstart + 1)
			end
		elseif quadlit then
			-- Process last two radicals of a quadriliteral verb form.
			rad3 = ch[radstart]
			rad4 = ch[radstart + 1]
			if rad4 == AMAQ or rad4 == ALIF and rad3 == Y or rad4 == Y then
				-- rad4 can be Y in passive-only verbs.
				if vform_supports_final_weak(vform) then
					weakness = "final-weak"
					-- Ambiguous radical; randomly pick wāw as radical (but avoid two wāws in a row); it could be wāw or
					-- yāʾ, but doesn't affect the conjugation.
					rad4 = rad3 == W and "y" or "w"
				else
					error("For headword " .. headword .. ", last radical is " .. rad4 .. " but verb form " .. vform ..
						" doesn't support final-weak verbs")
				end
			else
				weakness = "sound"
			end
		else
			-- Process last two radicals of a triliteral verb form.
			rad2 = ch[radstart]
			rad3 = ch[radstart + 1]
			if vform == "I" and (is_waw_ya(rad3) or rad3 == ALIF or rad3 == AMAQ) then
				-- Check for final-weak form I verb. It can end in tall alif (rad3 = wāw) or alif maqṣūra (rad3 = yāʾ)
				-- or a wāw or yāʾ (with a past vowel of i or u, e.g. nasiya/yansā "forget" or with a passive-only
				-- verb).
				if rad1 == W and not form_I_w_non_assimilated() then
					weakness = "assimilated+final-weak"
				else
					weakness = "final-weak"
				end
				if rad3 == ALIF then
					rad3 = W
				elseif rad3 == AMAQ then
					rad3 = Y
				else
					-- Ambiguous radical; randomly pick wāw as radical (but avoid two wāws); it could be wāw or yāʾ, but
					-- doesn't affect the conjugation.
					rad3 = (rad1 == W or rad2 == W) and "y" or "w" -- ambiguous
				end
		elseif rad3 == AMAQ or rad2 == Y and rad3 == ALIF or rad3 == Y then
				-- rad3 == Y happens in passive-only verbs.
				if vform_supports_final_weak(vform) then
					weakness = "final-weak"
				else
					error("For headword " .. headword .. ", last radical is " .. rad3 .. " but verb form " .. vform ..
						" doesn't support final-weak verbs")
				end
				-- Ambiguous radical; randomly pick wāw as radical (but avoid two wāws); it could be wāw or yāʾ, but
				-- doesn't affect the conjugation.
				rad3 = (rad1 == W or rad2 == W) and "y" or "w"
			elseif rad2 == ALIF then
				if vform_supports_hollow(vform) then
					weakness = "hollow"
					if vform == "I" and nonpast_vowel == "u" then
						rad2 = W
					elseif vform == "I" and nonpast_vowel == "i" then
						rad2 = Y
					else
						-- Ambiguous radical; could be wāw or yāʾ; if verb form I, it's critical to get this right, and
						-- the caller checks for this situation and throws an error if non-past vowel is "a" and second
						-- radical isn't explicitly given.
						rad2 = "w"
					end
				else
					error("For headword " .. headword .. ", second radical is alif but verb form " .. vform ..
						" doesn't support hollow verbs")
				end
			elseif vform == "I" and rad1 == W and not form_I_w_non_assimilated() then
				weakness = "assimilated"
			elseif rad2 == rad3 and (vform == "III" or vform == "VI") then
				weakness = "geminate"
			else
				weakness = "sound"
			end
		end
	end

	-- Convert radicals to canonical form (handle various hamza varieties and check for misplaced alif or alif maqṣūra;
	-- legitimate cases of these letters are handled above).
	local function convert(rad, index)
		if rad == HAMZA_ON_ALIF or rad == HAMZA_UNDER_ALIF or
			rad == HAMZA_ON_W or rad == HAMZA_ON_Y then
			return HAMZA
		elseif rad == AMAQ then
			error("For verb form " .. vform .. ", headword " .. headword .. ", radical " .. index ..
				" must not be alif maqṣūra")
		elseif rad == ALIF then
			error("For verb form " .. vform .. ", headword " .. headword .. ", radical " .. index ..
				" must not be alif")
		else
			return rad
		end
	end
	rad1 = convert(rad1, 1)
	rad2 = convert(rad2, 2)
	rad3 = convert(rad3, 3)
	rad4 = convert(rad4, 4)

	if not weakness then
		error("Internal error: Returned weakness from infer_radicals() is nil")
	end
	return weakness, rad1, rad2, rad3, rad4
end

-- Infer vocalization from participle headword (active or passive), verb form (I, II, etc.) and whether the headword is
-- active or passive. Throw an error if headword is malformed. Returned radicals may contain Latin letters "t", "w" or "y"
-- indicating ambiguous radicals guessed to be tāʾ, wāw or yāʾ respectively.
function export.infer_participle_vocalization(headword, vform, weakness, is_active)
	local chars = {}
	local orig_headword = headword
	-- Sub out alif-madda for easier processing.
	headword = rsub(headword, AMAD, HAMZA .. ALIF)

	local len = ulen(headword)

	-- Extract the headword letters into an array.
	for i = 1, len do
		table.insert(chars, usub(headword, i, i))
	end

	local function form_intro_error_msg()
		return ("For verb form %s %s%s participle %s, "):format(vform, orig_headword ~= headword and "normalized " or
			"", is_active and "active" or "passive", headword)
	end

	local function err(msg)
		error(form_intro_error_msg() .. msg, 1)
	end

	-- Check that length of headword is within [min, max].
	local function check_len(min, max)
		if min and len < min then
			err(("expected at least %s letters but saw %s"):format(min, len))
		elseif max and len > max then
			err(("expected at most %s letters but saw %s"):format(max, len))
		end
	end

	-- Get the character at `ind`, making sure it exists.
	local function c(ind)
		check_len(ind)
		return chars[ind]
	end

	-- Check that the letter at the given index is the given string, or is one of the members of the given array
	local function check(index, must)
		local letter = chars[index]
		local function make_possible_values()
			if type(must) == "string" then
				return must
			else
				return m_table.serialCommaJoin(must, {conj = "or", dontTag = true})
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

	local function check_weakness(values, allow_missing, invert_condition)
		local function make_possible_weaknesses()
			for i, val in ipairs(values) do
				values[i] = "'" .. val .. "'"
			end
			return m_table.serialCommaJoin(values, {conj = "or", dontTag = true})
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

	local vocalized

	local function handle_possibly_final_weak(sound_prefix, expected_length)
		check_len(expected_length, expected_length)
		if c(expected_length) == AMAQ then
			-- passive final-weak
			if is_active then
				err("participle in -ِى only allowed for passive participles")
			end
			check_weakness({"final-weak", "assimilated+final-weak"}, "allow missing")
			vocalized = sound_prefix .. AN .. AMAQ
		else
			-- all others behave as if sound
			check_weakness({"final-weak", "assimilated+final-weak"}, nil, "invert condition")
			vocalized = sound_prefix .. (is_active and I or A) .. c(expected_length)
		end
	end

	if not (vform == "I" and is_active) then
		-- all participles except verb form I active begin in م-.
		check(1, M)
	end
	if vform == "I" then
		if is_active then
			check(2, ALIF)
			local sound_prefix = c(1) .. AA .. c(3)
			if len == 3 then
				if c(3) == HAMZA then
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
				vocalized = sound_prefix .. I .. c(4)
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
			local sound_prefix = MA .. c(2) .. SK .. c(3)
			if len == 5 then
				-- sound, assimilated or geminate
				check(4, W)
				vocalized = sound_prefix .. UU .. c(5)
			else
				check_len(4, 4)
				if c(4) == W then
					-- final-weak third-wāw
					vocalized = sound_prefix .. U .. W .. SH
				elseif c(4) == Y then
					-- final-weak third-yāʾ
					vocalized = sound_prefix .. I .. Y .. SH
				else
					-- hollow
					check(3, {W, Y})
					if c(3) == W then
						vocalized = MA .. c(2) .. UU .. c(4)
					else
						vocalized = MA .. c(2) .. II .. c(4)
					end
				end
			end
		end
	elseif vform == "II" or vform == "V" or vform == "XII" or vform == "XIII" or vform == "Iq" or vform == "IIq" or
		vform == "IIIq" then
		local sound_prefix, expected_length
		if vform == "II" then
			sound_prefix = MU .. c(2) .. A .. c(3) .. SH
			expected_length = 4
		elseif vform == "V" then
			check(2, T)
			sound_prefix = MU .. T .. A .. c(3) .. A .. c(4) .. SH
			expected_length = 5
		elseif vform == "XII" then
			-- e.g. [[احدودب]] "to be or become convex or humpbacked", مُحْدَوْدِب (active);
			-- [[اثنونى]] "to be bent; to be doubled up", مُثْنَوْنٍ (active)
			check(4, W)
			if c(3) ~= c(5) then
				err(("third letter %s should be the same as the fifth letter %s"):format(c(3), c(5)))
			end
			sound_prefix = MU .. c(2) .. SK .. c(3) .. A .. W .. SK .. c(5)
			expected_length = 6
		elseif vform == "XIII" then
			-- e.g. [[اخروط]] "to get entangled; to extend", مُخْرَوِّط (active), مُخْرَوَّط (passive)
			check(4, W)
			sound_prefix = MU .. c(2) .. SK .. c(3) .. A .. W .. SH
			expected_length = 5
		elseif vform == "Iq" then
			sound_prefix = MU .. c(2) .. A .. c(3) .. SK .. c(4)
			expected_length = 5
		elseif vform == "IIq" then
			check(2, T)
			sound_prefix = MU .. T .. A .. c(3) .. A .. c(4) .. SK .. c(5)
			expected_length = 6
		elseif vform == "IIIq" then
			-- e.g. [[اخرنطم]] "to be proud and angry"
			check(4, T)
			sound_prefix = MU .. c(2) .. SK .. c(3) .. A .. N .. SK .. c(5)
			expected_length = 6
		else
			error("Internal error: Unhandled verb form " .. vform)
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
	elseif vform == "III" or vform == "VI" then
		local sound_prefix, expected_length
		if vform == "VI" then
			check(2, T)
			check(4, ALIF)
			sound_prefix = MU .. T .. A .. c(3) .. AA .. c(5)
			expected_length = 6
		else
			sound_prefix = MU .. c(2) .. AA .. c(4)
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
	elseif vform == "IV" or vform == "X" then
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
		if vform == "X" then
			check(2, S)
			check(3, T)
			sound_prefix = MU .. S .. SK .. T .. A .. c(4)
			expected_length = 6
		else
			sound_prefix = MU .. c(2)
			expected_length = 4
		end

		if len == expected_length and c(len - 1) == Y and c(len) ~= AMAQ then
			-- active hollow
			if not is_active then
				err("this shape only allowed for active participles")
			end
			check_weakness({"hollow"}, "allow missing")
			vocalized = sound_prefix .. II .. c(len)
		elseif len == expected_length and c(len - 1) == ALIF then
			-- passive hollow
			if is_active then
				err("this shape only allowed for passive participles")
			end
			check_weakness({"hollow"}, "allow missing")
			vocalized = sound_prefix .. AA .. c(len)
		elseif len == expected_length - 1 then
			-- active final-weak or active or passive geminate
			if is_active then
				check_weakness({"geminate", "final-weak", "assimilated+final-weak"})
				if weakness == "geminate" then
					vocalized = sound_prefix .. I .. c(len) .. SH
				elseif vform == "IV" and c(2) == W then
					-- assimilated final-weak
					vocalized = sound_prefix .. c(len) .. IN
				else
					vocalized = sound_prefix .. SK .. c(len) .. IN
				end
			else
				check_weakness({"geminate"}, "allow missing")
				vocalized = sound_prefix .. A .. c(len) .. SH
			end
		else
			if vform == "IV" and c(2) == W then
				-- assimilated, possibly final-weak
				sound_prefix = sound_prefix .. c(expected_length - 1)
			else
				sound_prefix = sound_prefix .. SK .. c(expected_length - 1)
			end
			handle_possibly_final_weak(sound_prefix, expected_length)
		end
	elseif vform == "VII" or vform == "VIII" then
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
		local sound_prefix, sufind
		if vform == "VII" then
			check(2, N)
			sound_prefix = MU .. N .. SK .. c(3)
			sufind = 4
		else
			local c2 = c(2)
			if c2 == T or c2 == "د" or c2 == "ث" or c2 == "ذ" or c2 == "ط" or c2 == "ظ" then
				-- full assimilation
				sound_prefix = MU .. c2 .. SH
				sufind = 3
			else
				-- partial or no assimilation
				if c2 == "ز" then
					check(3, "د")
				elseif c2 == "ص" or c2 == "ض"  then
					check(3, "ط")
				else
					check(3, T)
				end
				sound_prefix = MU .. c2 .. SK .. c(3)
				sufind = 4
			end
		end
		if c(sufind) == ALIF then
			-- hollow, active or passive
			check_len(sufind + 1, sufind + 1)
			check_weakness({"hollow"}, "allow missing")
			vocalized = sound_prefix .. AA .. c(sufind + 1)
		elseif len == sufind then
			-- active final-weak or active or passive geminate
			if is_active then
				check_weakness({"geminate", "final-weak", "assimilated+final-weak"})
				if weakness == "geminate" then
					vocalized = sound_prefix .. A .. c(len) .. SH
				else
					vocalized = sound_prefix .. A .. c(len) .. IN
				end
			else
				check_weakness({"geminate"}, "allow missing")
				vocalized = sound_prefix .. A .. c(len) .. SH
			end
		else
			sound_prefix = sound_prefix .. A .. c(sufind)
			handle_possibly_final_weak(sound_prefix, sufind + 1)
		end
	elseif vform == "IX" then
		check_len(4, 4)
		vocalized = MU .. c(2) .. SK .. c(3) .. A .. c(4) .. SH
	elseif vform == "IVq" then
		-- e.g. [[اذلعب]] "to scamper away", مُذْلَعِبّ (active), مُذْلَعَبّ (passive);
		-- [[اطمأن]] "to remain quietly; to be certain", مُطْمَئِنّ (active), مُطْمَأَنّ (passive)
		check_len(5, 5)
		local sound_prefix = MU .. c(2) .. SK .. c(3) .. A .. c(4)
		if is_active then
			vocalized = sound_prefix .. I .. c(5) .. SH
		else
			vocalized = sound_prefix .. A .. c(5) .. SH
		end
	elseif vform == "XI" then
		check_len(5, 5)
		check(4, ALIF)
		vocalized = MU .. c(2) .. SK .. c(3) .. AA .. c(5) .. SH
		-- e.g. [[احمار]] "to turn red, to blush", مُحْمَارّ (active)
	elseif vform == "XIV" or vform == "XV" then
		-- FIXME: Implement. No examples in Wiktionary currently; need to look up in a grammar.
		error("Support for verb form " .. vform .. " not implemented yet")
	else
		error("Don't recognize verb form " .. vform)
	end

	vocalized = rsub(vocalized, HAMZA .. AA, AMAD)

	local reconstructed_headword = lang:makeEntryName(vocalized)
	if reconstructed_headword ~= orig_headword then
		error(("Internal error: Vocalized participle %s doesn't match original participle %s"):format(
			vocalized, orig_headword))
	end
	
	return vocalized
end

function export.test_infer_participle_vocalization(frame)
	local iparams = {
		[1] = {required = true},
		[2] = {required = true},
		["weakness"] = {},
		["passive"] = {type = "boolean"}
	}

	local iargs = require("Module:parameters").process(frame.args, iparams)

	return export.infer_participle_vocalization(iargs[1], iargs[2], iargs.weakness, not iargs.passive)
end

return export
