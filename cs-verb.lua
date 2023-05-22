local export = {}


--[=[

Authorship: Ben Wing <benwing2>

]=]

--[=[

TERMINOLOGY:

-- "slot" = A particular combination of tense/mood/person/number/gender/etc.
	 Example slot names for verbs are "pres_1s" (present first singular) and
	 "past_pasv_part_impers" (impersonal past passive participle).
	 Each slot is filled with zero or more forms.

-- "form" = The conjugated Czech form representing the value of a given slot.

-- "lemma" = The dictionary form of a given Czech term. Generally the infinitive,
	 but may occasionally be another form if the infinitive is missing.
]=]

local lang = require("Module:languages").getByCode("cs")
local m_table = require("Module:table")
local m_links = require("Module:links")
local m_string_utilities = require("Module:string utilities")
local m_script_utilities = require("Module:script utilities")
local iut = require("Module:User:Benwing2/inflection utilities")
local m_para = require("Module:parameters")
local com = require("Module:User:Benwing2/cs-common")

local current_title = mw.title.getCurrentTitle()
local NAMESPACE = current_title.nsText
local PAGENAME = current_title.text

local u = mw.ustring.char
local rsplit = mw.text.split
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rgmatch = mw.ustring.gmatch
local rsubn = mw.ustring.gsub
local ulen = mw.ustring.len
local uupper = mw.ustring.upper

local TEMP_REFLEXIVE_INSERTION_POINT = u(0xFFF0) -- temporary character used to mark the reflexive insertion point


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


local function tag_text(text)
	return m_script_utilities.tag_text(text, lang)
end


local verb_slots = {
	["infinitive"] = "inf",
	["pres_act_part"] = "pres|act|part",
	["past_act_part"] = "past|act|part",
	["long_pass_part"] = "long|past|pass|part",
	["pres_tgress_m"] = "m|s|pres|tgress",
	["pres_tgress_fn"] = "f//n|s|pres|tgress",
	["pres_tgress_p"] = "p|pres|tgress",
	["past_tgress_m"] = "m|s|past|tgress",
	["past_tgress_fn"] = "f//n|s|past|tgress",
	["past_tgress_p"] = "p|past|tgress",
	["vnoun"] = "vnoun",
	["pres_fut_1s"] = "-",
	["pres_fut_2s"] = "-",
	["pres_fut_3s"] = "-",
	["pres_fut_1p"] = "-",
	["pres_fut_2p"] = "-",
	["pres_fut_3p"] = "-",
	["pres_1s"] = "1|s|pres|ind",
	["pres_2s"] = "2|s|pres|ind",
	["pres_3s"] = "3|s|pres|ind",
	["pres_1p"] = "1|p|pres|ind",
	["pres_2p"] = "2|p|pres|ind",
	["pres_3p"] = "3|p|pres|ind",
	["fut_1s"] = "1|s|fut|ind",
	["fut_2s"] = "2|s|fut|ind",
	["fut_3s"] = "3|s|fut|ind",
	["fut_1p"] = "1|p|fut|ind",
	["fut_2p"] = "2|p|fut|ind",
	["fut_3p"] = "3|p|fut|ind",
	["imp_2s"] = "2|s|imp",
	["imp_1p"] = "1|p|imp",
	["imp_2p"] = "2|p|imp",
}


local function add_part_gender_number(pref, accel_template)
	for _, slot_accel_part in ipairs {
		{"m", "m|s"},
		{"f", "f|s"},
		{"n", "n|s"},
		{"mp_an", "an|m|p"},
		{"mp_in", "in|m|p"},
		{"fp", "f|p"},
		{"np", "n|p"},
	} do
		local slot, accel_part = unpack(slot_accel_part)
		verb_slots[pref .. "_" .. slot] = accel_template:format(accel_part)
	end
end

-- List used for generating person-number-gender tenses like the past and conditional. Each element is a three-element
-- list of {DEST_SUFFIX, GENDER_NUMBER_SUFFIX, TEMPLATE_IND} where DEST_SUFFIX is the suffix to add onto the destination
-- prefix (e.g. "past_") to generate the slot; GENDER_NUMBER_SUFFIX is the suffix used to fetch the participle; and
-- TEMPLATE_IND is the suffix used to fetch the appropriate person-number template.
local person_number_gender_props = {
	{"1sm", "m", 1}, {"1sf", "f", 1}, {"1sn", "n", 1},
	{"2sm", "m", 2}, {"2sf", "f", 2}, {"2sn", "n", 2},
	{"3sm", "m", 3}, {"3sf", "f", 3}, {"3sn", "n", 3},
	{"1pm", "mp_an", 4}, {"1pf", "fp", 4}, {"1pn", "np", 4},
	{"2pm_polite", "m", 5}, {"2pm_plural", "mp_an", 5},
	{"2pf_polite", "f", 5}, {"2pf_plural", "fp", 5},
	{"2pn_polite", "n", 5}, {"2pn_plural", "np", 5},
	{"3pm_an", "mp_an", 6}, {"3pm_in", "mp_in", 6}, {"3pf", "fp", 6}, {"3pn", "np", 6},
}

local function add_tense_person_number_gender(pref)
	for _, suffix_pair in ipairs(person_number_gender_props) do
		local suffix, _, _ = unpack(suffix_pair)
		verb_slots[pref .. "_" .. suffix] = "-"
	end
end

add_part_gender_number("lpart", "%s|l-part")
add_part_gender_number("ppp", "short|%s|past|pass|part")

add_tense_person_number_gender("past")
add_tense_person_number_gender("cond")
-- Skip this as it's obsolete.
-- add_tense_person_number_gender("past_perf")
add_tense_person_number_gender("cond_past")

local budu_forms = {
	["1s"] = "budu",
	["2s"] = "budeš",
	["3s"] = "bude",
	["1p"] = "budeme",
	["2p"] = "budete",
	["3p"] = "budou",
}


local override_stems = m_table.listToSet {
	"pres",
	"past",
	"imp",
	"ppp",
	"vn",
	"prtr",
	"patr",
}


local function skip_slot(base, slot)
	if slot == "infinitive" then
		return false
	end
	if base.nopres and (rfind(slot, "pres") or rfind(slot, "fut")) then
		return true
	end
	if base.nopast and (rfind(slot, "past") or rfind(slot, "lpart")) then
		return true
	end
	if base.noimp and rfind(slot, "imp") then
		return true
	end
	if base.impers then
		-- Include _3s and _3sn slots, as well as _n and _fn slots for participles/transgressives.
		if rfind(slot, "3sn?$") or rfind(slot, "_f?n$") or slot == "vnoun" then
			return false
		else
			return true
		end
	end
	if (base.only3 or base.only3pl) and rfind(slot, "[12]") then
		return true
	end
	if (base.onlypl or base.only3pl) and (rfind(slot, "[123]s") or rfind(slot, "_[mfn]$") or rfind(slot, "_fn$")) then
		return true
	end
	if base.only3orpl and rfind(slot, "[12]s") then
		return true
	end
	return false
end


local function add(base, slot, stems, endings, footnotes)
	if not endings then
		return
	end
	if skip_slot(base, slot) then
		return
	end
	endings = iut.combine_form_and_footnotes(endings, footnotes)
	local function combine_stem_ending(stem, ending)
		return com.combine_stem_ending(base, slot, stem, ending)
	end
	iut.add_forms(base.forms, slot, stems, endings, combine_stem_ending)
end


local function map_forms(forms, fn)
	if type(forms) == "table" then
		forms = iut.convert_to_general_list_form(forms)
		for _, form in ipairs(forms) do
			fn(form.form, form.footnotes)
		end
	else
		fn(forms)
	end
end


local function fetch_footnotes(separated_group, allow_multiple_groups)
	local footnote_groups = allow_multiple_groups and {} or nil
	local footnotes
	for j = 2, #separated_group - 1, 2 do
		if allow_multiple_groups and separated_group[j + 1] == ":" then
			table.insert(footnote_groups, footnotes or {})
		elseif separated_group[j + 1] ~= "" then
			error("Extraneous text after bracketed footnotes: '" .. table.concat(separated_group) .. "'")
		end
		if not footnotes then
			footnotes = {}
		end
		table.insert(footnotes, separated_group[j])
	end
	if allow_multiple_groups then
		if not footnotes then
			error("Footnote-separating colon doesn't precede a footnote")
		end
		table.insert(footnote_groups, footnotes)
		return footnote_groups
	else
		return footnotes
	end
end


local function add_imperative(base, sg2, footnotes)
	add(base, "imp_2s", sg2, "", footnotes)
	-- "Long" imperatives end in -i
	local stem = rmatch(sg2, "^(.-)i$")
	if stem then
		add(base, "imp_1p", stem, "ěme", footnotes)
		add(base, "imp_2p", stem, "ěte", footnotes)
	elseif rfind(sg2, com.vowel_c .. "$") then
		error("Invalid 2sg imperative, ends in vowel other than -i: '" .. sg2 .. "'")
	else
		add(base, "imp_1p", sg2, "me", footnotes)
		add(base, "imp_2p", sg2, "te", footnotes)
	end
end


local function add_present_a_imperative(base, stems, footnotes)
	map_forms(stems, function(stem, stem_footnotes)
		stem_footnotes = iut.combine_footnotes(stem_footnotes, footnotes)
		add_imperative(base, stem .. "ej", stem_footnotes)
	end)
end

local function get_imptypes_for_stem(base)
	local imptypes
	if rfind(base.stem, "[sš][tť]$") or rfind(base.stem, "tř$") then
		imptypes = {"long", "short"}
	else
		-- Substitute 'ch' with a single character to make the following code simpler.
		local modstem = base.stem:gsub("ch", com.TEMP_CH)
		if rfind(modstem, com.cons_c .. "[lr]" .. com.cons_c .. "$") then
			-- [[trp]]; not long imperative.
			imptypes = "short"
		elseif rfind(modstem, com.cons_c .. com.cons_c .. "$") then
			imptypes = "long"
		else
			imptypes = "short"
		end
	end

	return imptypes
end


local function get_imperative_principal_part(base, infstem, imptype)
	local sg2, sg2_2
	if imptype == "long" then
		sg2 = com.combine_stem_ending(base, "imp_2s", infstem, "i")
	else
		-- See comment below at IV.1, there are rare cases where i-ě alternations occur in imperatives, e.g.
		-- [[podnítit]] impv. 'podniť ~ [rare] podněť'. 'ů' is reduced to 'u' rather than 'o', at least in
		-- [[půlit]] and derivatives.
		infstem = com.apply_vowel_alternation(imptype == "short-ě" and "quant-ě" or "quant", infstem, "noerror", "ring-u-to-u")
		if rfind(infstem, "[" .. com.paired_plain .. com.velar .. "]$") then
			sg2 = com.apply_second_palatalization(infstem, "is verb")
		else
			sg2 = infstem
		end
		if rfind(infstem, com.velar_c .. "$") then
			sg2_2 = com.apply_first_palatalization(infstem, "is verb")
		end
	end
	return {sg2, sg2_2}
end


local function add_imperative_from_present(base, pres3p_stems, overriding_imptypes, footnotes)
	local imptypes
	if overriding_imptypes then
		imptypes = overriding_imptypes
	elseif base.imptypes then
		imptypes = base.imptyoes
	end

	local function add_imp_for_stem(stem, stem_footnotes)
		if not imptypes then
			imptypes = get_imptypes_for_stem(imptypes)
		end
		local function add_imp_for_type(imptype, imptype_footnotes)
			local all_footnotes = iut.combine_footnotes(stem_footnotes,
				iut.combine_footnotes(imptype_footnotes, footnotes))
			local sg2, sg2_2
			if imptype == "long" then
				sg2 = com.combine_stem_ending(base, "imp_2s", stem, "i")
			else
				-- See comment below at IV.1, there are rare cases where i-ě alternations occur in imperatives, e.g.
				-- [[podnítit]] impv. 'podniť ~ [rare] podněť'. 'ů' is reduced to 'u' rather than 'o', at least in
				-- [[půlit]] and derivatives.
				stem = com.apply_vowel_alternation(imptype == "short-ě" and "quant-ě" or "quant", stem, "noerror", "ring-u-to-u")
				if rfind(stem, "[" .. com.paired_plain .. com.velar .. "]$") then
					sg2 = com.apply_second_palatalization(stem, "is verb")
				else
					sg2 = stem
				end
				if rfind(stem, com.velar_c .. "$") then
					sg2_2 = com.apply_first_palatalization(stem, "is verb")
				end
			end
			add_imperative(base, sg2, all_footnotes)
			if sg2_2 then
				add_imperative(base, sg2_2, all_footnotes)
			end
		end
		map_forms(imptypes, add_imp_for_type)
	end

	map_forms(pres3p_stems, add_imp_for_stem)
end


local function add_pres_fut(base, stems, sg1, sg2, sg3, pl1, pl2, pl3, footnotes)
	add(base, "pres_fut_1s", stems, sg1, footnotes)
	add(base, "pres_fut_2s", stems, sg2, footnotes)
	add(base, "pres_fut_3s", stems, sg3, footnotes)
	add(base, "pres_fut_1p", stems, pl1, footnotes)
	add(base, "pres_fut_2p", stems, pl2, footnotes)
	add(base, "pres_fut_3p", stems, pl3, footnotes)
end


local function generate_default_pres_tgress_principal_part(base, do_err)
	return iut.map_forms(base.forms.pres_fut_3p, function(form)
		local pref = rmatch(form, "^(.*)ou$")
		local ending
		if pref then
			ending = "a"
		else
			pref = rmatch(form, "^(.*)í")
			if pref then
				-- ě may be converted to e by com.combine_stem_ending()
				ending = "ě"
			else
				error("'prtr:' must be given in order to specify the present transgressive principal part because third-person "
					.. "plural present/future '" .. form .. "' does not end in -ou or -í")
			end
		end
		return combine_stem_ending(base, "pres_tgress_m", pref, ending)
	end)
end


local function add_pres_tgress(base)
	add(base, "pres_tgress_m", base.principal_part_forms.prtr, "")
	local prtr_stems = iut.map_forms(base.principal_part_forms.prtr, function(form)
		local pref = rmatch(form, "^(.*)a$")
		if pref then
			pref = pref .. "ou"
		end
		if not pref then
			pref = rmatch(form, "^(.*)[eě]$")
			if pref then
				pref = pref .. "í"
			end
		end
		if not pref then
			error("Unrecognized present transgressive principal part '" .. form .. "', which does not end in -a, -e or -ě")
		end
		return pref
	end)
	add(base, "pres_tgress_fn", prtr_stems, "c")
	add(base, "pres_tgress_p", prtr_stems, "ce")
end


local function generate_default_pres_act_part_principal_part(base, do_err)
	return iut.map_forms(base.forms.pres_tgress_fn, function(form)
		return form .. "í"
	end)
end


local function add_pres_act_part(base)
	add(base, "pres_act_part", base.principal_part_forms.pres_act_part, "")
end


local function add_present_e(base, stems, pres1s3p_stems, soft_stem, prtr_endings, noimp, footnotes)
	pres1s3p_stems = base.pres1s3p_stems or pres1s3p_stems or stems
	stems = base.pres_stems or stems
	local s1_ending, p3_ending
	if soft_stem then
		s1_ending = "i"
		p3_ending = "í"
	else
		s1_ending = "u"
		p3_ending = "ou"
	end
	add_pres_fut(base, stems, nil, "eš", "e", "eme", "ete", nil, footnotes)
	add_pres_fut(base, pres1s3p_stems, s1_ending, nil, nil, nil, nil, p3_ending, footnotes)
	add_pres_tgress(base, stems, prtr_endings or p3_ending, footnotes)
	if not noimp then
		add_imperative_from_present(base, pres1s3p_stems, nil, footnotes)
	end
end


local function add_present_a(base, stems, prtr_endings, noimp, footnotes)
	stems = base.pres_stems or stems
	add_pres_fut(base, stems, "ám", "áš", "á", "áme", "áte", "ají", footnotes)
	add_pres_tgress(base, stems, prtr_endings or "ají", footnotes)
	if not noimp then
		add_present_a_imperative(base, stems, footnotes)
	end
end


local function add_present_i(base, stems, noimp)
	stems = base.pres_stems or stems
	add_pres_fut(base, stems, "ím", "íš", "í", "íme", "íte", "í")
	add_pres_tgress(base, stems, "í")
	if not noimp then
		add_imperative_from_present(base, stems)
	end
end


local part_suffix_to_ending_list = {
	{"m", ""},
	{"f", "a"},
	{"n", "o"},
	{"mp_an", "i"},
	{"mp_in", "y"},
	{"fp", "y"},
	{"np", "a"},
}

local part_suffix_to_ending = {}

for _, suffix_ending in ipairs(part_suffix_to_ending_list) do
	local suffix, ending = unpack(suffix_ending)
	part_suffix_to_ending[suffix] = ending
end


-- No generate_default_past_principal_part(), which generates the past_m principal part.
-- This must be specified by each verb conjugation.


local function add_past_m(base)
	add(base, "lpart_m", base.principal_part_forms.past, "")
end


local function generate_default_past_f_principal_part(base, do_err)
	iut.map_forms(base.principal_part_forms.past, function(form)
		return form .. "a"
	end)
end


local function add_past_other_than_m(base)
	for _, suffix_ending in ipairs(part_suffix_to_ending_list) do
		local suffix, ending = unpack(suffix_ending)
		if suffix ~= "m" then
			add(base, "lpart_" .. suffix, base.principal_part_forms.pastf, ending)
		end
	end
end


local function generate_default_past_tgress_principal_part(base, do_err)
	return iut.map_forms(base.forms.lpart_m, function(form)
		local pref = rmatch(form, "^(.*)l$")
		if not pref then
			error("'patr:' must be given in order to specify the past transgressive principal part because masculine "
				.. "singular l-participle '" .. form .. "' does not end in -l")
		end
		if rfind(pref, com.vowel_c .. "$") then
			pref = pref .. "v"
		end
		return pref
	end)
end


local function add_past_tgress(base)
	-- Past transgressive not available for imperfective verbs.
	if base.aspect == "impf" then
		return
	end
	local patr_stems = base.principal_part_forms.patr
	add(base, "past_tgress_m", patr_stems, "")
	add(base, "past_tgress_fn", patr_stems, "ši")
	add(base, "past_tgress_p", patr_stems, "še")
	add(base, "past_act_part", patr_stems, "ší")
end


-- No generate_default_ppp_principal_part(), which generates the ppp_m principal part.
-- This must be specified by each verb conjugation.


local function add_ppp(base)
	if not base.ppp then
		return
	end
	for _, suffix_ending in ipairs(part_suffix_to_ending_list) do
		local suffix, ending = unpack(suffix_ending)
		add(base, "ppp_" .. suffix, base.principal_part_forms.ppp, ending)
	end
end


local function add_ppp(base, stems, vn_stems)
	if base.ppp then
		-- Add the long passive participle. Short participles in -án shorten to -an (e.g. 'jmenován' -> 'jmenovaný',
		--  'dělán' -> 'dělaný').
		map_forms(stems, function(stem, footnotes)
			stem = stem:gsub("án$", "an")
			add(base, "long_pass_part", stem, "ý", footnotes)
		end)
		for _, suffix_ending in ipairs(part_suffix_to_ending_list) do
			local suffix, ending = unpack(suffix_ending)
			add(base, "ppp_" .. suffix, stems, ending)
		end
	end
	vn_stems = vn_stems or stems
	-- FIXME, sometimes the vowel shortens; e.g. [[ptát]] ppp 'ptán' vn 'ptaní'; similarly [[hrát]] 'hraní',
	-- [[spát]] 'spaní', [[tkát]] 'tkaní', but not all- monosyllabic verbs, e.g. [[dbát]] ppp 'dbán' vn. 'dbání' or 'dbaní'
	-- and [[znát]] ppp. 'znán' vn. only 'znání'.
	add(base, "vnoun", vn_stems, "í")
end


local function add_vn(base)
	add(base, "vnoun", base.principal_part_forms.vn, "")
end


--[=[
Data on how to conjugate individual rows (i.e. tense/aspect combinations, such as present indicative or
conditional).

The order listed here matters. It determines the order of generating row forms. The order must have
'inf' < 'pres' < 'sub' < 'imp' < 'negimp' because the present indicative uses the root_stressed_stem generated
by add_infinitive; the present subjunctive uses generated forms from the present indicative; the imperative uses
forms from the present subjunctive and present indicative; and the negative imperative uses forms from the infinitive
and the imperative. Similarly we must have 'fut' < 'cond' because the conditional uses the future principal part.

The following specs are allowed:

-- `desc` must be present and is an all-lowercase English description of the row. It is used in error messages and in
   generating categories of the form 'Italian verbs with irregular ROW' and 'Italian verbs with missing ROW'.
-- `tag_suffix` must be present is a string containing the {{inflection of}} tags that are appended onto the
   person/number tags to form the accelerator spec. For example, the spec "pres|sub" means that the accelerator spec
   for the third singular present subjunctive will be "3|s|pres|sub". This accelerator spec is passed to
   [[Module:inflection utilities]], which in turn passes it to [[Module:links]] when generating the link(s) for the
   corresponding verb form(s). The spec ultimately gets processed by [[Module:accel]] to generate the definition line
   for nonexistent verb forms. (FIXME: Accelerator support is currently disabled for forms with non-final accents.
   We need to change the code in [[Module:inflection utilities]] so it sets the correct target not containing the
   non-final accent.)
-- `persnums` must be present and specifies the possible person/number suffixes to add onto the row-level slot
   (e.g. "phis" for the past historic) to form the individual person/number-specific slot (e.g. "phis2s" for the
   second-person singular past historic).
-- `row_override_persnums`, if present, specifies the person/number suffixes that are specified by a row override.
   If omitted, `persnums` is used.
-- `row_override_persnums_to_full_persnums`, if present, specifies a mapping from the person/number suffixes
   specified by a row override to the person/number/suffixes used for conjugating the row. This is used, for example,
   with the subjunctive and imperfect subjunctive, where the first element of the row override specifies
   (respectively) the 123s and 12s forms, which need to be copied (respectively) to the 1s/2s/3s and 1s/3s forms.
   If omitted, no such copying happens. It's still possible for the row override persnums to disagree with the
   overall persnums. This happens, for example, with the imperative, where the 'improw:' row override spec specifies
   only the 2s and 2p forms; the remaining forms (3s, 1p, 3p) are generated during conjugation by copying from other
   forms, and can't be overridden using a row override. (They can still be overridden using a single override such
   as 'imp3s:...' or a late single override such as 'imp3s!:...'.
-- `generate_default_principal_part`, if present, should be a function of two arguments, `base` and `do_err`, and
   should return the principal part(s) for the row. The return value can be anything that is convertible to the
   "general list form" of a slot's forms, i.e. it can return a string, an object
   {form = FORM, footnotes = {FOOTNOTE, FOOTNOTE, ...}}, or a list of either. It must be present if `conjugate` is
   a table, but may be missing if `conjugate` is a function, in which case the function needs to generate the
   principal part itself or otherwise handle things differently. For example, the present indicative does not
   specify a value for `generate_default_principal_part` because there are actually two principal parts for the
   present tense (first and third singular), which are processed at the beginning of the present indicative
   `conjugate` function. Similarly, the infinitive does not specify a value for `generate_default_principal_part`
   because there is no principal part to speak of; the infinitive is generated directly from the lemma in combination
   with the slash or backslash that follows the auxiliary and (in the case of a root-stressed infinitive) the
   single-vowel spec following the backslash. If `do_err` is given to this function, the function may throw an error
   if it can't generate the principal part; otherwise it should return nil.
-- `conjugate` is either a function to conjugate the row (of two arguments, `base` and `rowslot`), or a table
   containing the endings to add onto the principal part to conjugate the row. In the latter case, there should be
   the same number of elements in the table as there are elements in `row_override_persnums` (if given) or
   `persnums` (otherwise).
-- `no_explicit_principal_part` (DOCUMENT ME)
-- `no_row_overrides` (DOCUMENT ME)
-- `no_single_overrides` (DOCUMENT ME)
-- `add_clitics` is a mandatory function of two arguments, `base` and `rowslot`, to add clitics to the forms for the
   specified row. It will only be called if `base.verb.linked_suf` is non-empty, i.e. there is a clitic to add.
-- `dont_check_defective_status` (DOCUMENT ME)
]=]
local row_conjugations = {
	{"inf", {
		desc = "infinitive",
		tag_suffix = "inf",
		persnums = {""},
		-- No generate_default_principal_part; handled specially in add_infinitive.
		conjugate = add_infinitive,
		no_explicit_principal_part = true, -- because handled specially using / or \ notation
		no_row_overrides = true, -- useless because there's only one form; use / or \ notation
		no_single_overrides = true, --useless because there's only one form; use / or \ notation
		add_clitics = add_infinitive_clitics,
		add_prefixed_reflexive_variants = add_non_finite_prefixed_reflexive_variants,
	}},
	{"pres", {
		desc = "present indicative",
		tag_suffix = "pres|ind",
		persnums = full_person_number_list,
		-- No generate_default_principal_part; handled specially in add_present_indic because we actually have
		-- two principal parts for the present indicative ("pres" and "pres3s").
		conjugate = add_present_indic,
		-- No setting for no_explicit_principal_part here because it would never be checked; we special-case 'pres:'
		-- overrides before checking no_explicit_principal_part. The reason for special-casing is because there are two
		-- principal parts involved, "pres" and "pres3s", and we allow both to be specified using the syntax
		-- 'pres:PRES^PRES3S'.
		add_clitics = add_finite_clitics,
	}},
	{"sub", {
		desc = "present subjunctive",
		tag_suffix = "pres|sub",
		persnums = full_person_number_list,
		row_override_persnums = {"123s", "1p", "2p", "3p"},
		row_override_persnums_to_full_persnums = {["123s"] = {"1s", "2s", "3s"}},
		generate_default_principal_part = generate_default_present_subj_principal_part,
		conjugate = add_present_subj,
		add_clitics = add_finite_clitics,
	}},
	{"imp", {
		desc = "imperative",
		tag_suffix = "imp",
		persnums = imp_person_number_list,
		row_override_persnums = {"2s", "2p"},
		generate_default_principal_part = generate_default_imperative_principal_part,
		conjugate = add_imperative,
		add_clitics = add_imperative_clitics,
		add_prefixed_reflexive_variants = add_imperative_prefixed_reflexive_variants,
	}},
	{"negimp", {
		desc = "negative imperative",
		tag_suffix = "-",
		persnums = imp_person_number_list,
		-- No generate_default_principal_part because all parts are copied from other parts.
		conjugate = add_negative_imperative,
		add_clitics = add_negative_imperative_clitics,
		no_explicit_principal_part = true, -- because all parts are copied from other parts
		no_row_overrides = true, -- not useful; use single overrides if really needed
		-- We don't want a category [[:Category:Italian verbs with missing negative imperative]]; doesn't make
		-- sense as all parts are copied from elsewhere.
		dont_check_defective_status = true,
	}},
	{"phis", {
		desc = "past historic",
		tag_suffix = "phis",
		persnums = full_person_number_list,
		generate_default_principal_part = generate_default_past_historic_principal_part,
		conjugate = add_past_historic,
		add_clitics = add_finite_clitics,
		-- Set to "builtin" because normally handled specially in PRES^PRES3S,PHIS,PP spec, but when a built-in verb
		-- is involved, we want a way of overriding the past historic (using 'phis:').
		no_explicit_principal_part = "builtin",
	}},
	{"imperf", {
		desc = "imperfect indicative",
		tag_suffix = "impf|ind",
		persnums = full_person_number_list,
		generate_default_principal_part = function(base) return iut.map_forms(base.verb.unstressed_stem,
			function(stem) return combine_stem_ending(base, "imperf1s", stem, base.conj_vowel .. "vo") end) end,
		conjugate = {"o", "i", "a", "àmo", "àte", "ano"},
		add_clitics = add_finite_clitics,
	}},
	{"impsub", {
		desc = "imperfect subjunctive",
		tag_suffix = "impf|sub",
		persnums = full_person_number_list,
		row_override_persnums = {"12s", "3s", "1p", "2p", "3p"},
		row_override_persnums_to_full_persnums = {["12s"] = {"1s", "2s"}},
		generate_default_principal_part = function(base) return iut.map_forms(base.verb.unstressed_stem,
			function(stem) return combine_stem_ending(base, "impsub12s", stem, base.conj_vowel .. "ssi") end) end,
		conjugate = {"ssi", "sse", "ssimo", "ste", "ssero"},
		add_clitics = add_finite_clitics,
	}},
	{"fut", {
		desc = "future",
		tag_suffix = "fut",
		persnums = full_person_number_list,
		generate_default_principal_part = generate_default_future_principal_part,
		conjugate = {"ò", "ài", "à", "émo", "éte", "ànno"},
		add_clitics = add_finite_clitics,
	}},
	{"cond", {
		desc = "conditional",
		tag_suffix = "cond",
		persnums = full_person_number_list,
		generate_default_principal_part = generate_default_conditional_principal_part,
		conjugate = {"èi", "ésti", {"èbbe", "ébbe"}, "émmo", "éste", {"èbbero", "ébbero"}},
		add_clitics = add_finite_clitics,
	}},
	{"pp", {
		desc = "past participle",
		tag_suffix = "past|part",
		persnums = {""},
		generate_default_principal_part = generate_default_past_participle_principal_part,
		conjugate = {""},
		add_clitics = add_participle_clitics,
		-- Set to "builtin" because normally handled specially in PRES^PRES3S,PHIS,PP spec, but when a built-in verb
		-- is involved, we want a way of overriding the past participle (using 'pp:').
		no_explicit_principal_part = "builtin",
		no_row_overrides = true, -- useless because there's only one form; use the PRES^PRES3S,PHIS,PP or pp: spec
		no_single_overrides = true, --useless because there's only one form; use the PRES^PRES3S,PHIS,PP or pp: spec
	}},
	{"ger", {
		desc = "gerund",
		tag_suffix = "ger",
		persnums = {""},
		generate_default_principal_part = generate_default_gerund_principal_part,
		conjugate = {""},
		add_clitics = add_gerund_clitics,
		add_prefixed_reflexive_variants = add_non_finite_prefixed_reflexive_variants,
		no_row_overrides = true, -- useless because there's only one form; use explicit principal part
		no_single_overrides = true, -- useless because there's only one form; use explicit principal part
	}},
	{"presp", {
		desc = "present participle",
		tag_suffix = "pres|part",
		persnums = {""},
		generate_default_principal_part = generate_default_present_participle_principal_part,
		conjugate = {""},
		add_clitics = add_participle_clitics,
		no_row_overrides = true, -- useless because there's only one form; use explicit principal part
		no_single_overrides = true, -- useless because there's only one form; use explicit principal part
		-- Disable this; seems most verbs do have present participles
		-- not_defaulted = true, -- not defaulted, user has to request it explicitly
		dont_check_defective_status = true, -- this is frequently missing and doesn't indicate a defective verb
	}},
}

local row_conjugation_map = {}

for _, rowconj in ipairs(row_conjugations) do
	local rowslot, rowspec = unpack(rowconj)
	row_conjugation_map[rowslot] = rowspec
end


local function separate_stem_suffix(lemma, regex, class)
	local stem, suffix = rmatch(lemma, regex)
	if not stem and class then
		error("Unrecognized lemma for class " .. class .. ": '" .. lemma .. "'")
	end
	return stem, suffix
end


local function parse_variant_codes(run, allowed_codes, variant_type, parse_err)
	local allowed_code_set = m_table.listToSet(allowed_codes)
	local colon_separated_groups = iut.split_alternating_runs_and_strip_spaces(run, ":")
	local retval = {}
	for _, group in ipairs(colon_separated_groups) do
		for i, code in ipairs(allowed_codes) do
			allowed_codes[i] = "'" .. code .. "'"
		end
		if not allowed_code_set[group[1]] then
			parse_err(("Unrecognized variant code '%s' for %s: should be one of %s"):format(group[1], variant_type,
				m_table.serialCommaJoin(allowed_codes)))
		end
		table.insert(retval, {form = group[1], footnotes = fetch_footnotes(group)})
	end
	return retval
end


local parse = {}
local conjs = {}


--[=[ Verbs whose infinitive and present stems both end in a consonant.
1. Verbs in -k/h:
   [péct]] "to bake": pres. 'peču' (very bookish/outdated 'peku', not in IJP), 'pečeš', 'peče', 'pečeme', 'pečete',
	'pečou' (very bookish/outdated pekou)
   [[síct]] "to sow": pres. 'seču', etc. like péct
   [[téct]] "to flow": pres. 'teču', etc. like péct
   [[tlouct]] "to beat": pres. 'tluču', etc. like péct
   [[vléct]] "to drag": pres. 'vleču', etc. like péct
   [[moct]] "to be able": pres. 'mohu' (colloquial 'můžu'), 'můžeš', ..., 'můžete', 'mohou' (colloquial 'můžou')
   [[stříci se]] "to beware" (bookish, becoming obsolete except the imperative): pres. 'střehu se', 'střežeš se', ...,
	'střežete se', 'střehou se'
   These verbs have alternative bookish/obsolescent infinitives in '-ci', although 'moci' is still common and
	actually more frequent.
   Note also derivatives, e.g. [[přemoct]] "to overpower", [[pomoct]] "to help", [[obléct]] "to put on" (= ob- + vléct).
]=]

--[=[
conjs["I.1"] = function(base, lemma)
	local suffix
	local stem = separate_stem_suffix(lemma, "^(.*)c[ti]$")
	if stem then
		if not base.cons or (base.cons ~= "k" and base.cons ~= "h") then
			error("Must specify consonant as 'k' or 'h' for verbs in -ct/-ci")
		end
	end
	if not stem then
		stem, suffix = separate_stem_suffix(lemma, "^(.*)([bp])sti?$")
		if stem then
			-- [[zábsti]] (pres1s 'zebu'); obsolete [[hřébsti]] (hřebu), [[skúbsti]] (skubu), [[dlúbsti]] (dlubu),
			-- [[tépsti]] (tepu)
			local presstem = com.apply_vowel_alternation(base.ye and "quant-ě" or "quant", stem)
			add_present_e(base, presstem


			
	if last_cons == "к" or last_cons == "г" then
		error("Use class 8 for lemmas in -гти and -кти: '" .. lemma .. "'")
	end
	if last_cons == "р" then
		error("Use class 9 for lemmas in -рти: '" .. lemma .. "'")
	end
	if last_cons == "с" then
		if base.cons then
			last_cons = base.cons
		else
			error("With lemmas in -сти, must specify final consonant: '" .. lemma .. "'")
		end
	elseif base.cons then
		error("Can only specify final consonant '" .. base.cons .. "' with lemma ending in -сти: '" .. lemma .. "'")
	end
	local stressed_stem = com.maybe_stress_final_syllable(stem)
	add_present_e(base, stressed_stem .. last_cons)
	local past_msg, past_rest
	if base.cons == "д" or base.cons == "т" or base.cons == "в" then
		-- NOTE: This applies to плисти́ (with base.cons == "в") but not пливти́
		past_msg = stressed_stem .. "в"
		past_rest = stressed_stem .. "л"
	elseif base.cons == "ст" then
		past_msg = stressed_stem .. "с"
		past_rest = past_msg .. "л"
	else
		past_msg = stressed_stem .. last_cons
		past_rest = past_msg .. "л"
	end
	if base.i then
		past_msg = rsub(past_msg, "[ео](́?" .. com.cons_c .. "+)$", "і%1")
	end
	add_past(base, past_msg, past_rest)
	add_ppp(base, stressed_stem .. last_cons .. "ен")
end
]=]


--[=[
II.1 (stem ends in a consonant):

E.g.

[[blbnout]] past^(nu) (blbl ~ blbnul, blbnut, impf, vn blbnutí)
[[plácnout]] past^(nu) (plácl ~ plácnul, plácnut, plácnuv, vn plácnutí)
[[padnout]] (pf.) patr^nu^- (padl, no PPP, padnuv ~ pad, padnutí)
[[padnout]] (biasp.) patr^nu^- (padl, no PPP, padnuv ~ pad, padnutí)
[[napadnout]] ppp^n.vn^n^t.patr^nu^- (napadl, napaden, napadnuv ~ napad, napadení ~ napadnutí)
[[odpadnout]] patr^-^nu (odpadl, no PPP, odpad ~ odpadnuv, odpadnutí)
[[přepadnout]] ppp^n.vn^n^t.patr^-^nu (přepadl, přepaden, přepad ~ přepadnuv, přepadení ~ přepadnutí)
[[rozpadnout se]] patr^nu^- (rozpadl se, rozpadnut, rozpadnuv se ~ rozpad se, rozpadnutí se)
[[dopadnout]] ppp^n.vn^n^t.patr^nu^- (dopadl, dopaden, dopadnuv ~ dopad, dopadení ~ dopadnutí [VN differentiated by meaning: dopadení [přistižení = "catch?"] vs. dopadnutí [padnutí = "fall?"])
[[spadnout]] ppp^n.vn^t.patr^nu^- (spadl, spaden, spadnuv ~ spad, vn spadnutí)
[[upadnout]] ppp^n^t.vn^t.patr^-^nu (upadl, upaden ~ upadnut, upad ~ upadnuv, vn upadnutí)
[[vypadnout]] patr^-^nu (vypadl, no PPP, vypad ~ vypadnuv, vn vypadnutí)
[[ukradnout]] - (ukradl, ukradnut, ukradnuv, ukradnutí) [but IJP commentary says 'ukraden' and 'ukradení' still in use]
[[chřadnout]] - (chřadl, no PPP, impf, chřadnutí)
[[blednout]] - (bledl, no PPP, impv, blednutí)
[[sednout]] - (sedl, no PPP, sednuv, sednutí)
[[usednout]] - (usedl, usednut, usednuv, usednutí)
[[nastydnout]] - (nastydl, nastydnut, nastydnuv, nastydnutí)
[[sládnout]] - (sládl, no PPP, impf, sládnutí)
[[vládnout]] - (vladl, no PPP, impf, vn vládnutí)
[[zvládnout]] - (zvládl, zvládnut, zvládnuv, vn zvládnutí)
[[rafnout]] past^(nu) (rafl ~ rafnul, rafnut, rafnuv, vn rafnutí)
[[hnout]] past^nu (hnul, hnut, hnuv, hnutí), same for [[pohnout]]
[[nadchnout]] past^(nu).ppp^t^n (nadchl ~ nadchnul, nadchnut ~ nadšen, nadchnuv, nadchnutí ~ nadšení)
[[schnout]] - (schnul, schnut, impf, vn schnutí)
[[uschnout]] past^(nu) (uschl ~ uschnul, uschnut, uschnuv, vn uschnutí)
[[vyschnout]] past^(nu) (vyschl ~ vyschnul, no PPP, vyschnuv, vn vyschnutí)
[[bouchnout]] past^(nu) (bouchl ~ bouchnul, bouchnut, bouchnuv, vn bouchnutí)
[[oblehnout]] ppp^n (oblehl, obležen, oblehnuv, obležení)
[[stihnout]] ppp^n.vn^t^n (stihl, stižen, stihnuv, stihnutí ~ stižení)
[[zastihnout]] ppp^n (zastihl, zastižen, zastihnuv, zastižení)
[[zdvihnout]] ppp^n.vn^t^n (zdvihl, zdvižen, zdvihnuv, vn zdvihnutí ~ zdvižení)
[[pozdvihnout]] ppp^n (pozdvihl, pozdvižen, pozdvihnuv, vn pozdvižení)
[[střihnout]] ppp^n.vn^t^n (střihl, střižen, střihnuv, střihnutí ~ střižení)
[[ustřihnout]] ppp^n.vn^t^n (ustřihl, ustřižen, ustřihnuv, ustřihnutí ~ ustřižení)
[[trhnout]] past^(nu).ppp^t^n (trhl ~ trhnul, trhnut ~ tržen, trhnuv, trhnutí ~ tržení)
[[podtrhnout]] past^(nu).ppp^n.vn^t or past^(nu).ppp^n [by meaning] (podtrhl ~ podtrhnul, podtržen, podtrhnuv, podtrhnutí ~ podtržení [VN differentiated by meaning: podtrhnutí [of a chair], podtržení [of words]])
[[roztrhnout]] ppp^n (roztrhl, roztržen, roztrhnuv, roztržení)
[[vrhnout]] past^(nu).ppp^t^n (vrhl ~ vrhnul, vrhnut ~ vržen, vrhnuv, vn vrhnutí ~ vržení)
[[svrhnout]] ppp^n (svrhl, svržen, svrhnuv, svržení)
[[vyvrhnout]] past^(nu) or past^(nu).ppp^n [by meaning] (vyvhrl ~ vyvrhnul, vyvrhnut ~ vyvržen [PPP differentiated by meaning: 'vyvržen' [ejected (from society)], 'vyvrhnut' [published]], vyvrhnuv, vyvrhnutí ~ vyvržení)
[[sáhnout]] - (sáhl, no PPP, sáhnuv, sáhnutí)
[[zasáhnout]] ppp^n.vn^t^n (zasáhl, zasažen, zasáhnuv, zasáhnuti ~ zasažení)
[[obsáhnout]] - or ppp^n [by meaning] (obsáhl, obsáhnut ~ obsažen [differentiated by meaning], obsáhnuv, obsáhnutí ~ obsažení)
[[přesáhnout]] ppp^n.vn^t (přesáhl, přesažen, přesáhnuv, přesáhnutí)
[[dosáhnout]] ppp^n (dosáhl, dosažen, dosáhnuv, dosažení)
[[táhnout]] ppp^n (táhl, tažen, impv, tažení)
[[zatáhnout]] ppp^n (zatáhl, zatažen, zatáhnuv, zatažení)
[[vytáhnout]] ppp^n (vytáhl, vytažen, vytáhnuv, vytažení)
[[napřáhnout]] ppp^n.vn^t (napřáhl, napřažen, napřáhnuv, napřáhnutí)
[[přeřeknout se]] ppp^n^t.vn^t (přeřekl se, přeřečen ~ přeřeknut, přeřeknuv se, přeřeknutí se)
[[křiknout]] past^(nu) (křikl ~ křiknul, no PPP, křiknuv, vn křiknutí)
[[polknout]] past^(nu) (polkl ~ polknul, polknut, polknuv, vn polknutí)
[[zamknout]] ppp^n^t (zamkl, zamčen ~ zamknut, zamknuv, zamčení ~ zamknutí)
[[obemknout]] - (obemkl, obemknut, obemknuv, obemknutí)
[[odemknout]] ppp^n^t (odemkl, odemčen ~ odemknut, odemknuv, odemčení ~ odemknutí)
[[semknout]] patr^- (semkl, semknut, semk, semknutí)
[[přimknout]] - (přimkl, přimknut, přimknuv, přimknutí)
[[vymknout]] - (vymkl, vymknut, vymknuv, vymknutí)
[[cinknout]] past^(nu) (cinkl ~ cinknul, cinknut, cinknuv, vn cinknutí)
[[fnrknout]] past^(nu) (fnrkl ~ fnrknul, no PPP, fnrknuv, fnrknutí)
[[prasknout]] past^(nu) (praskl ~ prasknul, prasknut, prasknuv, vn prasknutí)
[[tisknout]] - or ppp^n [by meaning] (tiskl, tisknut ~ tištěn [differentiated by meaning], impf, tisknutí ~ tištění)
[[stisknout]] - (stiskl, stisknut, stisknuv, stisknutí)
[[vytisknout]] past^(nu).ppp^t^n (vytiskl ~ vytisknul, vytisknut ~ vytištěn, vytisknuv, vytisknutí ~ vytištění)
[[blýsknout]] past^(nu) (blýskl ~ blýsknul, no PPP, blýsknuv, blýsknutí)
[[tknout se]] - (tknul se, tknut [PPP with reflexive], tknuv se, vn tknutí)
[[dotknout se]] past^(nu).ppp^n^t.vn^t (dotkl se ~ dotknul se, dotčen ~ dotknut [PPP with reflexive], dotknuv se, vn dotknutí)
[[vytknout]] past^(nu).ppp^n^t (vytkl ~ vytknul, vytčen ~ vytknut, vytknuv, vn vytčení ~ vytknutí); same for [[protknout]], [[zatknout]]
[[kouknout]] past^(nu) (koukl ~ kouknul, no PPP, kouknuv, kouknutí)
[[nařknout]] ppp^n^t (nařkl, nařčen ~ nařknut, nařknuv, nařčení ~ nařknutí)
[[přiřknout]] ppp^n^t (přiřkl, přiřčen ~ přiřknut, přiřknuv, přiřčení ~ přiřknutí)
[[uřknout]] - (uřkl, uřknut, uřknuv, uřknutí)
[[vyřknout]] ppp^n^t (vyřkl, vyřčen ~ vyřknut, vyřknuv, vyřčení ~ vyřknutí)
[[obléknout]] [also oblíknout ~ obléct ~ obléci ~ oblíct] ppp^n^t (oblékl, oblečen ~ obléknut, obléknuv, oblečení ~ obléknutí [VN differentiated by meaning: oblečení [of clothing], obléknutí])
[[vléknout]] [obsolete for vléct per IJP]
[[navléknout]] [also navlíknout ~ navléct ~ navléci ~ navlíct] ppp^n^t.vn^t (navlékl, navlečen ~ navléknut, navléknuv, navléknutí)
[[převléknout]] [also převlíknout ~ převléct ~ převléci ~ převlíct] ?? ppp^n^t.vn^n vs. ppp^n^t.vn^t [by meaning; unless PPP is also distinguished by meaning] (převlékl ~ převléknul, převlečen ~ převléknut, převléknuv, převlečení ~ převléknutí [VN differentiated by meaning: převlečení [disguise] ~ převléknutí [change clothing]])
[[svléknout]] [also svlíknout ~ svléct ~ svléci ~ svlíct] past^(nu).ppp^n^t (svlékl ~ svléknul, svlečen ~ svléknut, svléknuv, svlečení ~ svléknutí)
[[oblíknout]] - (oblíkl, oblíknut, oblíknuv, oblíknutí)
[[lnout]] past^nu (lnul, no PPP, impf, lnutí)
[[přilnout]] past^nu (přilnul, přilnut, přilnuv, přilnutí)
[[povšimnout si]] - (povšiml si, povšimnut si, povšimnuv si, povšimnutí)
[[klapnout]] past^(nu) (klapl ~ klapnul, klapnut, klapnuv, vn klapnutí)
[[klepnout]] past^(nu) (klepl ~ klepnul, klepnut, klepnuv, vn klepnutí)
[[dupnout]] past^(nu) (dupl ~ dupnul, no PPP, dupnuv, vn dupnutí)
[[vyhoupnout se]] past^(nu) (vyhoupl se ~ vyhoupnul se, vyhoupnut [WHAT DOES A REFLEXIVE VERB WITH PPP MEAN?], vyhoupnuv se, vyhoupnutí)
[[křupnout]] past^(nu) (křupl ~ křupnul, křupnut, křupnuv, křupnutí)
[[stárnout]] - (stárl, no PPP, impf, stárnutí)
[[užasnout]] - (užasl, no PPP, užasnuv, užasnutí)
[[zesnout]] past^nu (zesnul, no PPP, zesnuv, zesnutí)
[[smlsnout]] past^(nu) (smlsl ~ smlsnul, no PPP, impf, vn smlsnutí)
[[usnout]] past^nu (usnul, usnut, usnuv, usnutí)
[[bohatnout]] - (bohatl, no PPP, impf, bohatnutí)
[[procitnout]] - (procitl, no PPP, procitnuv, procitnutí)
[[zhltnout]] past^(nu) (zhltl ~ zhltnul, zhltnut, zhltnuv, vn zhltnutí)
[[škrtnout]] past^(nu) (šrktl ~ šrktnul, škrtnout, šrktnuv, vn šrktnutí)
[[zvrtnout]] past^(nu) (zvrtl ~ zvrtnul, zvrtnut, zvrtnuv, vn zvrtnutí)
[[couvnout]] past^(nu) (couvl ~ couvnul, no PPP, couvnuv, vn couvnutí)
[[naleznout]] [not in IJP] [but IJP commentary says 'nalezen' and 'nalezení' still in use]
[[vynaleznout]] [not in IJP] [but IJP commentary says 'vynalezen' and 'vynalezení' still in use]
[[mrznout]] past^(nu) (mrzl ~ mrznul, mrznut, impf, vn mrznutí)
[[uváznout]] past^(nu) (uvázl ~ uváznul, no PPP, uváznuv, uváznutí)
[[říznout]] past^(nu) (řízl ~ říznul, říznut, říznuv, říznutí), same for [[vyříznout]], [[doříznout]], [[naříznout]], [[rozříznout]])

Per IJP, the past transgressive always ends in -nuv, and the endingless forms are totally obsolete.
(But not always it seems, see above.)

Variation:

Past: -l, -nul, -l ~ -nul: - nu (nu) [must be specified]
PPP: -nut, -en, -nut ~ -en, -en ~ -nut: t n t:n n:t [defaults to t]
past tgress: -nuv, null, -nuv ~ null, null ~ -nuv: nu - nu:- -:nu [defaults to nu]
vn: -nutí, -ení, -nutí ~ -ení, -ení ~ -nutí: defaults to same as PPP, or t if no PPP
]=]
parse["II.1"] = function(base, conjmod_run, parse_err)
	local separated_groups = iut.split_alternating_runs_and_strip_spaces(conjmod_run, "[/,]", "preserve splitchar")
	local past_conjmod = separated_groups[1]
	local ppp_conjmod, vn_conjmod, ptr_conjmod
	local expected_ptr_index = 3
	if #separated_groups > 1 and separated_groups[2][1] == "/" then
		ppp_conjmod = separated_groups[3]
		expected_ptr_index = 5
		if #separated_groups > 3 and separated_groups[4][1] == "/" then
			vn_conjmod = separated_groups[5]
			expected_ptr_index = 7
		end
	end
	if #separated_groups >= expected_ptr_index then
		local ptr_separator = separated_groups[expected_ptr_index - 1][1]
		if ptr_separator ~= "," then
			parse_err("Expected a comma as separator for past transgressive but saw '" .. ptr_separator .. "'")
		end
		ptr_conjmod = separated_groups[expected_ptr_index]
		if #separated_groups > expected_ptr_index then
			parse_err("Junk at end of II.1 conjugation modifier spec, after past transgressive spec")
		end
	end

	base.past_stem = parse_variant_codes(past_conjmod, {"-", "nu", "(nu)"}, "II.1 past tense", parse_err)
	if not ppp_conjmod then
		base.ppp_stem = {{form = "t"}}
	else
		base.ppp_stem = parse_variant_codes(ppp_conjmod, {"", "t", "n"}, "II.1 past passive participle", parse_err)
	end
	if not vn_conjmod then
		base.vn_stem = {{form = "t"}}
	else
		base.vn_stem = parse_variant_codes(ppp_conjmod, {"", "t", "n"}, "II.1 verbal noun", parse_err)
	end
	if not vn_conjmod then
		base.ptr_stem = {{form = "nu"}}
	else
		base.ptr_stem = parse_variant_codes(ppp_conjmod, {"-", "nu"}, "II.1 past transgressive", parse_err)
	end
end


conjs["II.1"] = function(base, lemma)
	local stem = separate_stem_suffix(lemma, "^(.*)nout$", "II.1")

	local function shorten_and_palatalize(stem)
		local begin, lastv, lastc = rmatch(stem, "^(.*)(" .. com.vowel_c .. ")(" .. com.cons_c .. "*)$")
		if not begin then
			begin = ""
			lastv = ""
			lastc = stem
		elseif lastv == "á" then
			-- [[vytáhnout]] -> 'vytažen'
			lastv = "a"
		elseif lastv == "é" then
			-- [[obléknout]] -> 'oblečen'
			-- FIXME, do we need to convert ň/ť/ď to plain versions and vowel to ě?
			lastv = "e"
		end
		-- [[tisknout]] -> 'tištěn'
		-- [[nadchnout]] -> 'nadšen'
		-- [[práhnout]] -> 'pražen'
		-- [[vléknout]] -> 'vlečen'
		lastc = com.apply_first_palatalization(lastc, "verb")
		return begin .. lastv .. lastc
	end

	-- Normalize the codes computed by the parse function above.

	-- First the past tense. We need to expand "(nu)" to "-" and "nu", then normalize appropriately.
	local saw_paren_nu = false
	for _, formobj in ipairs(base.past_stem) do
		if formobj.form == "(nu)" then
			saw_paren_nu = true
			break
		end
	end
	local expanded_past
	if saw_paren_nu then
		expanded_past = {}
		for _, formobj in ipairs(base.past_stem) do
			if formobj.form == "(nu)" then
				table.insert(expanded_past, {form = "-", footnotes = formobj.footnotes})
				table.insert(expanded_past, {form = "nu", footnotes = formobj.footnotes})
			else
				table.insert(expanded_past, formobj)
			end
		end
	else
		 expanded_past = base.past_stem
	end
	for _, formobj in ipairs(expanded_past) do
		if formobj.form == "-" then
			formobj.form = stem
		elseif formobj.form == "nu" then
			formobj.form = stem .. "nu"
		else
			error("Internal error: Saw unrecognized past tense variant code '" .. formobj.form .. "'")
		end
	end

	local function normalize_ppp_and_vn(stems, stem_type)
		for _, formobj in ipairs(stems) do
			if formobj.form == "t" then
				formobj.form = stem .. "nut"
			elseif formobj.form == "n" then
				-- We need to call combine_stem_ending() in case of e.g. [[tisknout]] -> stem 'tišť' -> 'tištěn'.
				formobj.form = com.combine_stem_ending(base, nil, shorten_and_palatalize(stem), "en")
			else
				error("Internal error: Saw unrecognized " .. stem_type .. " variant code '" .. formobj.form .. "'")
			end
		end
	end

	-- Now the PPP and verbal noun.
	normalize_ppp_and_vn(base.ppp_stem, "PPP")
	normalize_ppp_and_vn(base.vn_stem, "verbal noun")

	-- Now the past transgressive.
	for _, formobj in ipairs(base.ptr_stem) do
		if formobj.form == "-" then
			formobj.form = stem
		elseif formobj.form == "nu" then
			formobj.form = stem .. "nuv"
		else
			error("Internal error: Saw unrecognized past transgressive variant code '" .. formobj.form .. "'")
		end
	end

	add_present_e(base, stem .. "n")
	-- Masculine singular past may have -l, -nul or both, but other forms of the past generally only have -l.
	add_past(base, expanded_past, stem, base.ptr_stem)
	add_ppp(base, base.ppp_stem, base.vn_stem)
end


--[=[
E.g.:

[[krýt]] (kryji ~ kryju [colloquial], kryl, kryt, kryje, krytí)
[[zakrýt]] (zakryji ~ zakryju [colloquial], zakryl, zakryt, zakryv, zakrytí)
[[mýt]], [[nýt]], [[rýt]], [[týt]], [[výt]] (essentially like 'krýt')
[[pít]] (piji ~ piju [colloquial], pil, pit, impf, pití)
[[vypít]] (vypiji ~ vypiju [colloquial], vypil, vypit, vypiv, vypití)
[[bít]] (biji ~ etc., bil, bit, impf, bití)
[[rozbít]] (rozbiji, rozbil, rozbit, rozbiv, rozbití)
[[šít]] (šiji, šil, šit, impf, šití)
[[sešít]] (sešiji, sešil, sešit, sešiv, sešití) [not in IJP]
[[žít]] (žiji, žil, žit, impf, žití)
[[prožít]] (prožiji, prožil, prožit, proživ, prožití)
[[klít]] (kleji, klel, klet, impf, kletí ~ klení)
[[proklít]] (prokleji, proklel, proklet, proklev, prokletí)
[[dout]] (duji, dul, no PPP, impf, dutí)
[[zadout]] (zaduji, zadul, no PPP, zaduv, zadutí)
[[lát]] (laji [impv laj, prtg laje], lál, lán, impf, lání)
[[vylát]] (vylaji [impv vylaj], vylál, vylán, vyláv, vylání) [not in IJP]
[[tát]] (taji [impv taj, prtg taje], tál, no PPP [given as tán (tát) in Wikipedia], impf, tání)
[[roztát]] (roztaji [impv roztaj, prtg roztaje], roztál, roztán, roztáv, roztání)
[[přát]] (přeji [impv přej, prtg přeje], přál, no PPP, impf, přání)
[[popřát]] (popřeji [impv popřej], popřál, popřán, popřáv, popřání)
[[smát se]] (směji se [impv směj se, prtg směje se], smál se, no PPP [given as smán (smát) in Wikipedia], impf, no VN [given as smání (smátí) in Wikipedia])
[[usmát se]] (usměji se [impv usměj se], usmál se, no PPP, usmáv [NOTE: IJP has usmav but this appears to be a mistake], usmání)
[[nasmát se]] [biaspectual: also prtg 'nasměje se'] (nasměji se [impv nasměj se], nasmál se, no PPP, nasmáv, nasmání)
[[sít]] (seji [impv sej, prtg seje], sel ~ sil, set, impf, setí)
[[zasít]] (zaseji [impv zasej], zasel ~ zasil, zaset, zasev, zasetí)
[[vát]] (věji [impv věj, prtg věje], vál, no PPP [given as ván (vát) in Wikipedia], impf, vání [vátí is very rare])
[[navát]] (navěji [impv navěj, prtg navěje], navál, navát, naváv, navátí)
[[hrát]] (hraji [impv hraj ~ hrej [bookish]], hrál, hrán, hraje, hraní [NOTE: short vowel])

Variation:

* Present tense shortens infinitive vowel: ý -> y; ou -> u; í -> i or ě; á -> a or ě.
* Past tense vowel matches present vowel unless infinitive has á, in which case past tense has á.
* PPP has -t unless infinitive has á, in which case PPP may have -n or -t (or maybe both).
* PPP stem usually matches past stem; but note [[sít]], [[zasít]] with past stem '(za)sel ~ (za)sil' but PPP only
  (za)set. Similarly for past transgressive.
* No instances I can see of verbal noun stem disagreeing with PPP stem.

Variant codes:
- Use 'n' for PPP in -n, 't' for PPP in '-t', 'n:t' or 't:n' for both (defaults to 'n'):
* [[lát]], [[vylát]]: III.1
* [[tát]], [[roztát]]: III.1
* [[přát]], [[popřát]]: III.1.pres^ě
* [[smát se]]: III.1.pres^ě.vn:-
* [[usmát se]], [[nasmát se]]: III.1.ppp^n.ě
* [[vát]]: III.1.ppp^n^t[rare]
* [[navát]]: III.1.ppp^t

]=]
parse["III.1"] = function(base, conjmod_run, parse_err)
	base.ppp_stem = parse_variant_codes(conjmod_run, {"", "t", "n"}, "III.1 past passive participle", parse_err)
end


conjs["III.1"] = function(base, lemma)
	local stem = separate_stem_suffix(lemma, "^(.*)t$", "III.1")
	local begin, lastv = rmatch(stem, "^(.*)(ou)$")
	if not begin then
		begin, lastv = rmatch(stem, "^(.*)([áíý])$")
	end
	if not begin then
		error("Unrecognized lemma for class III.1: '" .. lemma .. "' (should end in -át, -ít, -ýt or -out)")
	end
	local pres_stem = com.apply_vowel_alternation(base.ye and "quant-ě" or "quant", stem)
	local past_stem = lastv == "á" and stem or pres_stem

	-- Normalize the codes computed by the parse function above.
	if not base.ppp_stem then
		base.ppp_stem = {{form = lastv == "á" and "n" or "t"}}
	end
	for _, formobj in ipairs(base.ppp_stem) do
		formobj.form = past_stem .. formobj.form
	end

	add_present_e(base, pres_stem .. "j", nil, "soft")
	add_present_e(base, {}, pres_stem .. "j", false, {}, "noimp", "[colloquial]")
	add_past(base, past_stem)
	add_ppp(base, base.ppp_stem)
end


--[=[
III.2:

[[darovat]] "to donate"
[[sledovat]] "to follow"
[[konstruovat]] "to construct"
]=]
conjs["III.2"] = function(base, lemma)
	local stem = separate_stem_suffix(lemma, "^(.*)ovat$", "III.2")
	add_present_e(base, stem .. "uj", nil, "soft")
	add_past(base, stem .. "ova")
	add_ppp(base, stem .. "ován")
end


--[=[
IV.1:

[[prosit]] (prosím, pros, prosil, prošen, prose, prošení)
[[vyprosit]] (vyprosím, vypros, vyprosil, vyprošen, vyprosiv, vyprošení)
[[nosit]] (nosím, nos, nosil, nošen, nose, nošení)
[[nanosit]] (nanosím, nanos, nanosil, nanošen, nanosiv, nanošení)
[[spasit]] (spasím, spas, spasil, spasen, spasiv, spasení)
[[cizopasit]] (cizopasím, cizopas, cizopasil, cizopasen, cizopase, cizopasení)
[[vozit]] (vozím, voz, vozil, vožen ~ vozen, voze, vožení ~ vození)
[[navozit]] (navozím, navoz, navozil, navozen ~ navožen, navoziv, navození ~ navožení)
[[chodit]] (chodím, choď, chodil, chozen, chodě, chození)
[[nachodit]] (nachodím, nachoď, nachodil, nachozen, nachodiv, nachození)
[[platit]] (platím, plať, platil, placen, platě, placení)
[[naplatit]] (naplatím, naplať, naplatil, naplacen, zaplativ, naplacení)
[[čistit]] (čistím, čisť ~ čisti, čistil, čištěn ~ čistěn, čistě, čištění ~ čistění)
[[vyčistit]] (vyčistím, vyčisť ~ vyčisti, vyčistil, vyčištěn ~ vyčistěn, vyčistiv, vyčištění ~ vyčistění)
[[pustit]] (pustím, pusť, pustil, puštěn, pustiv, puštění)
[[napustit]] (napustím, napusť, napustil, napuštěn, napustiv, napuštění)
[[vábit]] (vábím, vab ~ vábi, vábil, váben, vábě, vábení)
[[učit]] (učím, uč, učil, učen, uče, učení)
[[křivdit]] (křivdím, křivdi ~ křivď, křivdil, křivděn, křivdě, křivdění)
[[mírnit]] (mírním, mírni, mírnil, mírněn, mírně, mírnění)
[[jezdit]] (jezdím, jezdi, jezdil, ježděn ~ jezděn, jezdě, ježdění ~ jezdění)
[[zpozdit]] (zpozdím, zpozdi, zpozdil, zpožděn, zpozdiv, zpoždění)
[[zaostřit]] (zaostřím, zaostři, zaostřil, zaostřen, zaostřiv, zaostření)
[[zvětšit]] (zvětším, zvětši, zvětšil, zvětšen, zvětšiv, zvětšení)
[[oprostit]] (oprostím, oprosti ~ oprosť, oprostil, oproštěn, oprostiv, oproštění)
[[roztříštit]] (roztříštím, roztříšti, roztříštil, roztříštěn, roztříštiv, roztříštění) [NOTE: SSJC says impv roztříšť or roztříšti; IJP's commentary also says this should be the case]
[[opatřit]] (opatřím, opatři ~ opatř, opatřil, opatřen, opatřiv, opatření)
[[brzdit]] (brzdím, brzdi ~ brzď, brzdil, brzděn ~ bržděn, brzdě, brzdění ~ brždění)
[[přesvědčit]] (přesvědčím, přesvědči ~ přesvědč, přesvědčil, přesvědčen, přesvědčiv, přesvědčení)
[[léčit]] (léčím, léči ~ leč, léčil, léčen, léče, léčení)
[[loudit]] (loudím, loudi ~ luď, loudil, louděn, loudě, loudění)
[[toužit]] (toužím, touži ~ tuž, toužil, toužen, touže, toužení)
[[soudit]] (soudím, suď, soudil, souzen, soudě, souzení)
[[koupit]] (koupím, kup, koupil, koupen, koupiv, koupení)
[[rdousit]] (rdousím, rdousi ~ rdus, rdousil, rdoušen, rdouse, rdoušení)
[[bloudit]] (bloudím, bloudi ~ bluď, bloudil, no PPP, bloudě, bloudění)
[[vrátit]] (vrátím, vrať, vrátil, vrácen, vrátiv, vrácení)
[[přiblížit]] (přiblížím, přibliž, přiblížil, přiblížen, přiblíživ, přiblížení)
[[lícit]] (lícím, líci ~ lic, lícil, no PPP, líce, lícení)
[[čepýřit]] (čepýřím, čepyř ~ čepýři, čepýřil, čepýřen, čepýře, čepýření)
[[chýlit]] (chýlím, chyl, chýlil, chýlen, chýle, chýlení)
[[půlit]] (půlím, pul, půlil, půlen, půle, půlení)
[[půjčit]] (půjčím, půjč [IRREG], půjčil, půjčen, půjčiv, půjčení)
[[trůnit]] (trůním, trůni, trůnil, no PPP, trůně, trůnění)
[[podnítit]] (podnítím, podniť ~ [rare] podněť, podnítil, podnícen, podnítiv, podnícení)
[[vštípit]] (vštípím, vštěp ~ vštip, vštípil, vštípen, vštípiv, vštípení)

In -ít:

[[ctít]] (ctím, cti, ctil, ctěn, ctě, ctění)
[[clít]] (clím, cli, clil, clen, cle, clení)
[[dštít]] (dštím, dšti, dštil, dštěn, dště, dštění)
[[pohřbít]] (pohřbím, pohřbi, pohřbil, pohřben, pohřbiv, pohřbení)
[[křtít]] (křtím, křti, křtil, křtěn, křtě, křtění)
[[obelstít]] (obelstím, obelsti, obelstil, obelstěn, obelstiv, obelstění)
[[mdlít]] (mdlím, mdli, mdlil, no PPP?, mdle, mdlení) [NOTE: also mdlít IV.2]
[[mstít]] (mstím, msti, mstil, mstěn, mstě, mstění)
[[mžít]] (mžím, mži, mžil, mžen, mže, mžení)



Variation:

* Imperative can have long forms, short forms or both. Defaults to both forms if stem ends in -st, -št or -tř, otherwise
  long forms if stem ends in two or more consonants, otherwise short forms. Short form imperative also shortens long
  stem vowels (á é í ý ů ou -> a e i y u u); but note půjčit, with imperative půjč. Alternations between í and ě seem
  rare; SSJC mentions [[nítit]] and [[podnítit]] with imperative (pod)niť or rarely (pod)něť; IJP has both and mentions
  that the latter is rare. SSJC also mentions [[svítit]] with imperative sviť or rarely svěť but IJP says only sviť.
  SSJC also mentions [[vštípit]] with imperative vštěp or vštip; IJP agrees. SSJC mentions [[vybílit]] with imperative
  vybil or rarely vyběl; IJP says imperative vybil or vybíli. SSJC has two [[vytížit]] verbs, the second of which has
  imperative only vytěž; IJP doesn't include this verb, only the first [[vytížit]].
* PPP's usually iotate coronals: s -> š, z -> ž, st -> šť, zd -> žď, t -> c, d -> z, n -> ň (velars and plain r do not
  generally occur as the last stem consonant). But not always, and sometimes both iotated and non-iotated variants
  occur. When non-iotated variants of t/d occur, they are palatalized, e.g. [[loudit]] -> 'louděn', [[ctit]] -> 'ctěn'.

Variant codes:
- Use 'long' for long imperative, 'short' for short imperative, 'long:short' or 'short:long' for both (default as above).
- Use 'iot' for iotated PPP, 'ni' for non-iotated PPP, 'iot:ni' or 'ni:iot' for both (default is iotated).
* [[čistit]]: IV.1.imp^short^long.ppp^iot^ni
* [[brzdit]]: IV.1.imp^long^short.ppp^ni^iot
* [[spasit]]: IV.1.ppp^ni
* [[vozit]]: IV.1.ppp^iot^ni
* [[loudit]]: IV.1.imp^long^short.ppp^ni

]=]

conj["IV.1"] = {
	init = function(base)
		-- Some with -ít e.g. [[pohřbít]]
		local infstem = separate_stem_suffix(base.lemma, "^(.*)[ií]t$", "IV.1")
		base.infstem = com.convert_paired_plain_to_palatal(infstem)
	end,
	pres = function(base) return base.infstem .. "ím" end,
	imp = {
		choices = {"long", "short", "short-ě"},
		default = get_imptypes_for_stem,
		generate_part = function(base, variant)
			return get_imperative_principal_part(base, base.infstem, form)
		end,
	},
	past = function(base) return base.infstem .. "il" end,
	ppp = {
		choices = {"iot", "ni"},
		default = "iot",
		generate_part = function(base, variant)
			if variant == "iot" then
				local iotated_stem = com.iotate(base.infstem)
				return com.combine_stem_ending(base, "ppp_m", iotated_stem, "en")
			elseif variant == "ni" then
				return com.combine_stem_ending(base, "ppp_m", base.infstem, "en")
			else
				error("Internal error: Saw unrecognized PPP variant code '" .. variant .. "'")
			end
		end,
	},


parse["IV.1"] = function(base, conjmod_run, parse_err)
	local separated_groups = iut.split_alternating_runs_and_strip_spaces(conjmod_run, ",")
	for _, separated_group in ipairs(separated_groups) do
		if rfind(separated_group[1], "^long") or rfind(separated_group[1], "^short") then
			-- Imperative specs
			if base.impspec then
				parse_err("Saw two sets of long/short imperative specs")
			end
			base.impspec = parse_variant_codes(separated_group, {"long", "short", "short-ě"}, "imperative type", parse_err)
		elseif rfind(separated_group[1], "^iot") or rfind(separated_group[1], "^ni") then
			-- PPP specs
			if base.ppp_stem then
				parse_err("Saw two sets of iotated/non-iotated past passive participle specs")
			end
			base.ppp_stem = parse_variant_codes(separated_group, {"iot", "ni"}, "past passive participle type",
				parse_err)
		else
			parse_err("Unrecognized indicator '" .. separated_group[1] .. "'")
		end
	end
end


conjs["IV.1"] = function(base, lemma)
	-- Some with -ít e.g. [[pohřbít]]
	local stem = separate_stem_suffix(lemma, "^(.*)[ií]t$", "IV.1")

	stem = com.convert_paired_plain_to_palatal(stem)

	-- Normalize the codes computed by the parse function above. We don't need to do anything to the 'long'/'short'
	-- imperative codes because add_imperative_from_present() takes the codes directly.
	if not base.ppp_stem then
		base.ppp_stem = {{form = "iot"}}
	end
	for _, formobj in ipairs(base.ppp_stem) do
		if formobj.form == "iot" then
			local iotated_stem = com.iotate(stem)
			formobj.form = com.combine_stem_ending(base, "ppp_m", iotated_stem, "en")
		elseif formobj.form == "ni" then
			formobj.form = com.combine_stem_ending(base, "ppp_m", stem, "en")
		else
			error("Internal error: Saw unrecognized PPP variant code '" .. formobj.form .. "'")
		end
	end

	add_present_i(base, stem, "noimp")
	add_imperative_from_present(base, stem, base.impspec)
	add_past(base, com.combine_stem_ending(base, "lpart_m", stem, "i"))
	add_ppp(base, base.ppp_stem)
end

--[=[
IV.2:

[[bdít]] (bdím # bdí, bdi, bděl, bděn, bdě, bdění)
[[čnět]] ~ [[čnít]] (čním # čnějí ~ ční, čni, čněl, čněn, čněje ~ čně, čnění)
[[čpět]] ~ [[čpít]] (čpím # čpí, čpi, čpěl, čpěn, čpě, čpění)
[[dít]] [biasp] (dím # dějí, děj, děl, no PPP, děje / děv, no VN)
[[dlít]] (dlím # dlejí ~ dlí, dli, dlel, dlen, dle ~ dleje, dlení)
[[hřmět]] ~ [[hřmít]] (hřmím # hřmí ~ hřmějí, hřmi, hřměl, no PPP, hřmě ~ presumably hřměje, hřmění)
[[lpět]] ~ [[lpít]] (lpím # lpějí ~ lpí, lpi ~ lpěj, lpěl, lpěn, lpěje ~ lpě, lpění)
[[mdlít]] (mdlím # mdlejí ~ mdlí, mdli, mdlel, no PPP?, mdleje ~ presumably mdle, mdlení) [NOTE: also mdlít IV.1]
etc.

[[trpět]] [default] (trpím # trpí, trp, trpěl, trpěn, trpě, trpění)
[[bolet]] /preslong:short (bolím # bolejí ~ bolí, bol, bolel, no PPP, boleje ~ bole, bolení)
[[hovět]] /preslong:short,implong:short (hovím # hovějí ~ hoví, hověj ~ hov, hověl, no PPP, hověje ~ hově, hovění)
[[náležet]] (náležím # náležejí ~ náleží, náležej ~ nálež, náležel, náležen, náleže ~ náležeje, náležení)
[[souviset]] (souvisím # souvisejí ~ souvisí, souvisej, souvisel, no PPP, souvise ~ souviseje, souvisení)
[[šumět]] (šumím # šumějí ~ šumí, šuměj ~ šum, šuměl, no PPP, šuměje ~ šumě, šumění)
[[večeřet]] (večeřím # večeřejí ~ večeří, večeř, večeřel, no PPP, večeře, večeření)
[[záviset]] (závisím # závisejí ~ závisí, závisej, závisel, no PPP, závise ~ záviseje, závisení)
[[zmizet]] (zmizím # zmizejí ~ zmizí, zmiz, zmizel, zmizen, zmizev, zmizení)
[[čumět]] (čumím # čumějí ~ čumí, čum, čuměl, no PPP, čuměje ~ čumě, čumění)
[[slyšet]] (slyším # slyší, slyš ~ poslyš ["perceive by hearing"], slyšel, slyšen, slyše, slyšení)
[[běžet]] (běžím # běží, běž ~ poběž, běžel, běžen, běže, běžení; fut. poběžím ... poběží)
[[letet]] (letím # letí, leť ~ poleť, letěl, letěn, letě, letění; fut. poletím ... poletí)
[[vidět]] (vidím # vidí, viz [IRREG], viděl, viděn, vida [IRREG], vidění)

]=]


--[=[
[[dělat]] "to do" V.1
[[konat]] "to act" V.1
[[chovat]] "to behave" V.1
[[doufat]] "to hope" V.1
[[ptát se]] "to ask" (vn 'ptaní se') V.1.vn:ptaní
[[dbát]] "to care" (vn 'dbání ~ dbaní') V.1.vn:dbání:dbaní
[[zanedbat]] "to neglect" V.1
[[znát]] "to know" V.1
[[poznat]] "to know (pf.)" V.1
[[poznávat]] "to know (secondary impf.)" V.1
[[nechat]] "to let (pf)" (imperative 'nech ~ nechej') V.1.imp:nech:nechej
[[nechávat]] "to let (impf)" V.1
[[obědvat]] "to lunch" V.1
[[odolat]] "to resist"/[[zdolat]]/[[udolat]] V.1
[[plácat]] "to slap" V.1
[[drncat]] "to rattle" V.1
[[kecat]] "to chatter" V.1
[[cucat]] "to suck" V.1
]=]

conjs["V.1"] = function(base, lemma)
	local stem = separate_stem_suffix(lemma, "^(.*)[aá]t$", "V.1")
	add_present_a(base, stem)
	add_past(base, stem .. "a")
	add_ppp(base, stem .. "án")
end

--[=[

* Verbs in [sz]:
[[tesat]] "to carve" (pres 'tesám ~ tešu', impv 'tesej ~ teš', tr.ppp)
[[česat]] "to comb" (pres 'češu ~ česám', impv 'češ ~ česej', tr.ppp)
[[klusat]] "to trot" (pres 'klusám ~ klušu', impv 'klusej'; intr)
[[křesat]] "to scrape" (pres 'křesám ~ křešu', impv 'křesej ~ křeš', tr.-ppp)
[[řezat]] "to cut" (pres 'řežu ~ řezám', impv 'řež ~ řežej'; tr.ppp)
[[lízat]] "to lick" (pres 'lízám ~ lížu', impv 'lízej ~ liž' [NOTE: short vowel], tr.-ppp)
[[hryzat]] "to bite" (also [[hrýzt]]; pres 'hryzám ~ hryžu', impv 'hryzej ~ hryž', tr.ppp)
[[pásat se]] "to graze" (not in IJP; prefixed 'přepásat' etc. in IJP [pres 'přepásám ~ přepášu', impv 'přepásej', tr.ppp)
[[klouzat]] "to slide" (pres 'klouzám ~ kloužu', impv 'klouzej'; intr PPP?)

* Verbs in [bpvfm]:
[[hýbat]] "to move" (pres 'hýbám ~ hýbu', impv 'hýbej'; intr no PPP)
[[dlabat]] "to gouge" (pres 'dlabám ~ dlabu', impv 'dlab ~ dlabej', PPP)
[[škrábat]] "to scratch" (also [[škrabat]]; pres 'škrábám ~ škrábu', impv 'škrábej ~ škrab' [NOTE: short vowel], PPP)
[[klepat]] "to knock" (pres 'klepám ~ klepu', impv 'klep ~ klepej', PPP)
[[kopat]] "to kick" (pres 'kopám ~ kopu', impv 'kopej', PPP)
[[koupat]] "to bathe" (pres 'koupám ~ koupu', impv 'koupej', PPP)
[[sypat]] "to sprinkle" (pres 'sypám ~ sypu', impv 'syp ~ sypej', PPP)
[[drápat]] "to claw" (pres 'drápám ~ drápu', impv 'drápej', PPP)
[[dupat]] "to stomp" (pres 'dupám ~ dupu', impv 'dupej', PPP)
[[loupat]] "to peel" (pres 'loupám ~ loupu', impv 'loupej', PPP)
[[rýpat]] "to dig" (pres 'rýpám ~ rýpu', impv 'rýpej', PPP)
[[štípat]] "to pinch" (pres 'štípám ~ štípu', impv 'štípej', PPP)
[[šlapat]] "to step; to trample" (pres 'šlapám ~ šlapu', impv 'šlap ~ šlapej', PPP)
[[tápat]] "to grope" (pres 'tápám ~ tápu', impv 'tápej', intr no PPP)
[[dřímat]] "to doze" (pres 'dřímám ~ dřímu', impv 'dřímej', intr no PPP)
[[klamat]] "to deceive" (pres 'klamu', impv 'klamej ~ klam', PPP)
[[lámat]] "to break" (pres 'lámu', impv 'lam [NOTE: short vowel] ~ lámej', PPP)
[[plavat]] "to swim, to float" (pres 'plavu', impv 'plavej ~ plav ~ poplav', intr PPP? 'plaván', pres tgress 'plavaje')
[[klofat]] "to peck; to tap, to knock" (pres 'klofám ~ klofu', impv 'klofej', PPP)

* Verbs in [rln]:
[[orat]] "to plow" (pres 'orám ~ ořu', impv 'orej ~ oř', PPP)
[[párat]] "to unstitch; to unravel" (pres 'párám ~ pářu', impv 'párej', PPP)
[[dudlat]] "to hum, to drone (of an instrument or musician); to grumble, to groan; to suck (one's thumb, etc.; of a
  child)" (not in IJP; SSJC says 'dudlám' or 'dudlu', impv 'dudlej', 'dudli'; tr no PPP)
[[stonat]] "to moan, to groan" (pres only 'stůňu, stůněš', impv 'stonej', intr no PPP, vnoun 'stonání', pres tgress 'stonaje')

* Verbs in [kh] and -ch:
[[týkat se]] (pres 'týči se ~ týču se ~ týkám se'; impv only 'týkej se'; vn 'týkání')
[[kdákat]] (pres 'kdáču ~ kdákám', impv 'kdákej', PPP)
[[kvákat]] (pres 'kváču ~ kvákám', impv 'kvákej', no PPP)
[[páchat]] (pres 'páchám ~ pášu', impv 'páchej', PPP)

* Verbs in [td]:
[none; all verbs given in Wikipedia as examples are either V.1 or missing in IJP]

Types:
* [default] = a-stem + e-stem, impv only a-stem = [[klusat]], [[přepásat]], [[klouzat]], [[hýbat]], [[škrabat]], [[kopat]], [[koupat]], [[drápat]], [[dupat]], [[loupat]], [[rýpat]], [[štípat]], [[tápat]], [[dřímat]], [[klamat]], [[klofat]], [[párat]], [[páchat]]
* pres^e^a = e-stem + a-stem, impv only a-stem = [[týkat se]], [[kdákat]], [[kvákat]]
* pres^e = e-stem, impv only a-stem = [[stonat]]
* imp^e^a = a-stem + e-stem, impv e-stem + a-stem = [[dlabat]], [[klepat]], [[sypat]], [[šlapat]], [[lámat]] (short 'lam')
* pres^e^a.imp^e^a = e-stem + a-stem, impv e-stem + a-stem = [[česat]], [[řezat]]
* pres^e.imp^e^a = e-stem, impv only e-stem + a-stem
* imp^a^e = a-stem + e-stem, impv a-stem + e-stem = [[tesat]], [[křesat]], [[lízej]], [[hryzat]], [[orat]], [[dudlat]]
* pres^e^a.imp^a^e = e-stem + a-stem, impv a-stem + e-stem
* pres^e.imp^a^e = e-stem, impv only a-stem + e-stem = [[plavat]]
]=]

parse["V.2"] = function(base, conjmod_run, parse_err)
	local separated_groups = iut.split_alternating_runs_and_strip_spaces(conjmod_run, ",")
	for _, separated_group in ipairs(separated_groups) do
		if rfind(separated_group[1], "^a") or rfind(separated_group[1], "^e") then
			-- pres specs
			if base.pres_stem then
				parse_err("Saw two sets of present stem specs")
			end
			base.pres_stem = parse_variant_codes(separated_group, {"a", "e"}, "present stem type", parse_err)
		elseif rfind(separated_group[1], "^imp") then
			-- Imperative specs
			if base.imp_stem then
				parse_err("Saw two sets of imperative specs")
			end
			base.imp_stem = parse_variant_codes(separated_group, {"impa", "impe"}, "imperative type", parse_err)
		else
			parse_err("Unrecognized indicator '" .. separated_group[1] .. "'")
		end
	end
end


conjs["V.2"] = function(base, lemma)
	local stem = separate_stem_suffix(lemma, "^(.*)at$", "V.2")
	local iotated_stem = com.iotate(stem)

	-- Normalize the codes computed by the parse function above.
	if not base.pres_stem then
		base.pres_stem = {{form = "a"}, {form = "e"}}
	end
	for _, formobj in ipairs(base.pres_stem) do
		if formobj.form == "a" then
			add_present_a(base, stem, {}, "noimp", formobj.footnotes)
		elseif formobj.form == "e" then
			add_present_e(base, iotated_stem, nil, false, {}, "noimp", formobj.footnotes)
		else
			error("Internal error: Saw unrecognized present tense code '" .. formobj.form .. "'")
		end
	end
	-- Present transgressive is always a-stem regardless of present tense.
	add_pres_tgress(base, stem, "ají")
	if not base.imp_stem then
		base.imp_stem = {{form = "impa"}}
	end
	for _, formobj in ipairs(base.imp_stem) do
		if formobj.form == "impa" then
			add_present_a_imperative(base, stem, formobj.footnotes)
		elseif formobj.form == "impe" then
			add_imperative_from_present(base, iotated_stem, nil, formobj.footnotes)
		else
			error("Internal error: Saw unrecognized imperative code '" .. formobj.form .. "'")
		end
	end

	add_past(base, stem .. "a")
	add_ppp(base, stem .. "án")
end


conjs["5"] = function(base, lemma)
	local stem, suffix, ac = separate_stem_suffix_accent(lemma, "5", "^(.*)([іая])(́?)ти$")
	local stem_ends_in_vowel = com.ends_in_vowel(stem)
	if suffix == "я" and not stem_ends_in_vowel then
		error("Ending -яти can only be used with a vocalic stem: '" .. lemma .. "'")
	elseif suffix ~= "я" and stem_ends_in_vowel then
		error("Ending -яти must be used with a vocalic stem: '" .. lemma .. "'")
	end
	local stressed_stem = com.maybe_stress_final_syllable(stem)
	local sg2
	if base.i then
		if not rfind(stem, "о́?$") then
			error("і-modifier can only be used with stem ending in -о: '" .. lemma .. "'")
		end
		sg2 = com.maybe_stress_final_syllable(rsub(stem, "о(́?)$", "і%1й"))
	end
	add_present_i(base, stressed_stem, sg2)
	add_past(base, stem .. suffix .. ac)
	add_retractable_ppp(base, (suffix == "і" and com.iotate(stem) .. "е" or stem .. suffix) .. ac .. "н")
end

conjs["8"] = function(base, lemma)
	local stem, last_cons = rmatch(lemma, "^(.*)([кг])ти́?$")
	if not stem then
		error("Unrecognized lemma for class 8: '" .. lemma .. "'")
	end
	local palatalized_cons = com.iotate(last_cons)
	local stressed_stem = com.maybe_stress_final_syllable(stem)
	add_present_e(base, stressed_stem .. palatalized_cons)
	local past_msg = stressed_stem .. last_cons
	local past_rest = past_msg .. "л"
	if base.i then
		past_msg = rsub(past_msg, "[еоя](́?" .. com.cons_c .. "+)$", "і%1")
	end
	add_past(base, past_msg, past_rest)
	add_ppp(base, stressed_stem .. palatalized_cons .. "ен")
end


conjs["9"] = function(base, lemma)
	local stem, suffix = rmatch(lemma, "^(.*)(е́?р)ти$")
	if not stem then
		error("Unrecognized lemma for class 9: '" .. lemma .. "'")
	end
	if accent ~= "a" and accent ~= "b" then
		error("Only accent a or b allowed for class 9: '" .. base.conj .. "'")
	end
	local pres_stem
	if base.conj_star then
		pres_stem = rsub(stem, "^(.*)(.)$", "%1і%2")
	else
		pres_stem = stem
	end
	add_present_e(base, pres_stem .. "р")
	local stressed_stem = com.maybe_stress_final_syllable(stem .. suffix)
	add_past(base, stressed_stem, stressed_stem .. "л")
	add_ppp(base, stressed_stem .. "т")
end


conjs["10"] = function(base, lemma)
	local stem, suffix, ac = separate_stem_suffix_accent(lemma, "10", "^(.*)(о[лр]о)(́?)ти$")
	if accent ~= "a" and accent ~= "c" then
		error("Only accent a or c allowed for class 10: '" .. base.conj .. "'")
	end
	local stressed_stem = com.maybe_stress_final_syllable(rsub(stem .. suffix, "о$", ""))
	add_present_e(base, stressed_stem, "1sg3pl")
	add_past(base, stem .. suffix .. ac)
	-- If explicit present stem given (e.g. for моло́ти), use it/them in the н-participle.
	local n_ppps
	if base.pres_stems then
		n_ppps = {}
		for _, pres_stem in ipairs(base.pres_stems) do
			table.insert(n_ppps, pres_stem .. "ен")
		end
	else
		n_ppps = stressed_stem .. "ен"
	end
	local t_ppp = stressed_stem .. "от"
	if base.conj == "н" then
		add_ppp(base, n_ppps)
	elseif base.conj == "т" then
		add_ppp(base, t_ppp)
	else
		add_ppp(base, n_ppps)
		add_ppp(base, t_ppp)
	end
end


conjs["11"] = function(base, lemma)
	local stem, suffix, ac = separate_stem_suffix_accent(lemma, "11", "^(.*)(и)(́?)ти$")
	if accent ~= "a" and accent ~= "b" then
		error("Only accent a or b allowed for class 11: '" .. base.conj .. "'")
	end
	local pres_stem
	if base.conj_star then
		pres_stem = rsub(stem, "^(.*)(.)$", "%1і%2")
	else
		pres_stem = stem
	end
	if rfind(pres_stem, "л$") then
		pres_stem = pres_stem .. "л"
	else
		pres_stem = pres_stem .. "'"
	end
	local full_stem = stem .. suffix .. ac
	add_present_e(base, pres_stem, "all", full_stem .. "й")
	add_past(base, full_stem)
	add_ppp(base, full_stem .. "т")
end


conjs["12"] = function(base, lemma)
	local stem = rmatch(lemma, "^(.*" .. com.vowel_c .. AC .. "?)ти$")
	if not stem then
		error("Unrecognized lemma for class 12: '" .. lemma .. "'")
	end
	if accent ~= "a" and accent ~= "b" then
		error("Only accent a or b allowed for class 12: '" .. base.conj .. "'")
	end
	add_present_e(base, stem)
	add_past(base, stem)
	add_ppp(base, stem .. "т")
end


conjs["13"] = function(base, lemma)
	local stem = rmatch(lemma, "^(.*а)ва́ти$")
	if not stem then
		error("Unrecognized lemma for class 13: '" .. lemma .. "'")
	end
	if accent ~= "b" then
		error("Only accent b allowed for class 13: '" .. base.conj .. "'")
	end
	local full_stem = stem .. "ва́"
	add_present_e(base, stem, nil, full_stem .. "й")
	add_past(base, full_stem)
	add_retractable_ppp(base, full_stem .. "н")
end


conjs["14"] = function(base, lemma)
	-- -сти occurs in п'я́сти́ and роз(і)п'я́сти́
	local stem = rmatch(lemma, "^(.*[ая]́?)с?ти́?$")
	if not stem then
		error("Unrecognized lemma for class 14: '" .. lemma .. "'")
	end
	if not base.pres_stems then
		error("With class 14, must specify explicit present stem using 'pres:STEM'")
	end
	add_present_e(base, "foo")
	local stressed_stem = com.maybe_stress_final_syllable(stem)
	add_past(base, stressed_stem)
	add_retractable_ppp(base, stressed_stem .. "т")
end


conjs["irreg"] = function(base, lemma)
	local prefix = rmatch(lemma, "^(.*)да́?ти$")
	if prefix then
		local stressed_prefix = com.is_stressed(prefix)
		if stressed_prefix then
			add_pres_fut(base, prefix, "дам", "даси", "дасть", "дамо", "дасте", "дадуть")
			add_imperative(base, prefix .. "дай")
			add_past(base, prefix .. "да")
			add_retractable_ppp(base, prefix .. "дан") -- ви́даний from ви́дати
		else
			add_pres_fut(base, prefix, "да́м", "даси́", "да́сть", "дамо́", "дасте́", "даду́ть")
			add_imperative(base, prefix .. "да́й")
			add_past(base, prefix .. "да́")
			add_retractable_ppp(base, prefix .. "да́н") -- e.g. пере́даний from переда́ти
		end
		return
	end
	prefix = rmatch(lemma, "^(.*по)ві́?сти́?$")
	if prefix then
		local stressed_prefix = com.is_stressed(prefix)
		if stressed_prefix then
			add_pres_fut(base, prefix, "вім", "віси", "вість", "вімо", "вісте", "відять")
			add_imperative(base, prefix .. "відж", "[lc]")
			add_imperative(base, prefix .. "віж", "[lc]")
			add_past(base, prefix .. "ві")
			-- no PPP
		else
			add_pres_fut(base, prefix, "ві́м", "віси́", "ві́сть", "вімо́", "вісте́", "відя́ть")
			add_imperative(base, prefix .. "ві́дж", "[lc]")
			add_imperative(base, prefix .. "ві́ж", "[lc]")
			add_past(base, prefix .. "ві́")
			-- no PPP
		end
		return
	end
	prefix = rmatch(lemma, "^(.*)ї́?сти$")
	if prefix then
		local stressed_prefix = com.is_stressed(prefix)
		if stressed_prefix then
			add_pres_fut(base, prefix, "їм", "їси", "їсть", "їмо", "їсте", "їдять")
			add_imperative(base, prefix .. "їж")
			add_past(base, prefix .. "ї")
			add_ppp(base, prefix .. "їден") -- ви́їдений from ви́їсти
		else
			add_pres_fut(base, prefix, "ї́м", "їси́", "ї́сть", "їмо́", "їсте́", "їдя́ть")
			add_imperative(base, prefix .. "ї́ж")
			add_past(base, prefix .. "ї́")
			add_ppp(base, prefix .. "ї́ден") -- e.g. прої́дений from прої́сти
		end
		return
	end
	prefix = rmatch(lemma, "^(.*)бу́?ти$")
	if prefix then
		local stressed_prefix = com.is_stressed(prefix)
		if prefix == "" then
			error("Can't handle unprefixed irregular verb бу́ти yet")
		end
		add_present_e(base, prefix .. (stressed_prefix and "буд" or "бу́д"), "a")
		add_past(base, prefix .. (stressed_prefix and "бу" or "бу́"))
		add_ppp(base, prefix .. (stressed_prefix and "бут" or "бу́т")) -- e.g. забу́тий from забу́ти
		return
	end
	prefix = rmatch(lemma, "^(.*)ї́?хати$")
	if prefix then
		local stressed_prefix = com.is_stressed(prefix)
		add_present_e(base, prefix .. (stressed_prefix and "їд" or "ї́д"), "a")
		add_past(base, prefix .. (stressed_prefix and "їха" or "ї́ха"))
		-- no PPP
		return
	end
	prefix = rmatch(lemma, "^(.*)шиби́?ти$")
	if prefix then
		local stressed_prefix = com.is_stressed(prefix)
		add_present_e(base, prefix .. "шиб", stressed_prefix and "a" or "b")
		local past_msg = prefix .. (stressed_prefix and "шиб" or "ши́б")
		add_past(base, past_msg, past_msg .. "л")
		add_ppp(base, prefix .. (stressed_prefix and "шиблен" or "ши́блен")) -- e.g. проши́блений from прошиби́ти
		return
	end
	prefix = rmatch(lemma, "^(.*соп)і́ти$")
	if prefix then
		add_pres_fut(base, prefix, "лю́", "е́ш", "е́", {"е́м", "емо́"}, "ете́", "ля́ть")
		add_imperative(base, prefix .. "и́")
		add_past(base, prefix .. "і́")
		-- no PPP
		return
	end
	prefix = rmatch(lemma, "^(.*)жи́?ти$")
	if prefix then
		local stressed_prefix = com.is_stressed(prefix)
		add_present_e(base, prefix .. "жив", stressed_prefix and "a" or "b")
		add_past(base, prefix .. (stressed_prefix and "жи" or "жи́"))
		add_ppp(base, prefix .. (stressed_prefix and "жит" or "жи́т")) -- e.g. пережи́тий from пережи́ти
		return
	end
	prefix = rmatch(lemma, "^(.*)бі́?гти$")
	if prefix then
		local stressed_prefix = com.is_stressed(prefix)
		add_present_i(base, prefix .. "біж", stressed_prefix and "a" or "b")
		local past_msg = prefix .. (stressed_prefix and "біг" or "бі́г")
		add_past(base, past_msg, past_msg .. "л")
		-- no PPP
		return
	end
	prefix = rmatch(lemma, "^(п?і)ти́$")
	if not prefix then
		prefix = rmatch(lemma, "^(.*й)ти́?$")
	end
	if prefix then
		local stressed_prefix = com.is_stressed(prefix)
		add_present_e(base, com.maybe_stress_final_syllable(prefix .. "д"),
			stressed_prefix and "a" or (prefix == "і" or prefix == "й") and "b" or "c")
		add_past(base, prefix .. (stressed_prefix and "шов" or "шо́в"), com.maybe_stress_final_syllable(prefix .. "шл"))
		add_retractable_ppp(base, prefix .. (stressed_prefix and "ден" or "де́н")) -- e.g. пере́йдений from перейти́
		return
	end
	error("Unrecognized irregular verb: '" .. lemma .. "'")
end


local function add_infinitive(base)
	add(base, "infinitive", base.lemma, "")
	-- FIXME: Consider adding old infinitive in -ti as an alternant at the end (after adding imperfective future)
end


local function set_present_future(base)
	local forms = base.forms
	if base.aspect == "pf" then
		for slot_suffix, _ in pairs(budu_forms) do
			forms["fut_" .. slot_suffix] = forms["pres_fut_" .. slot_suffix]
			forms["pres_fut_" .. slot_suffix] = nil
		end
	else
		for slot_suffix, _ in pairs(budu_forms) do
			forms["pres_" .. slot_suffix] = forms["pres_fut_" .. slot_suffix]
			forms["pres_fut_" .. slot_suffix] = nil
		end
		-- Do the periphrastic future with [[budu]]
		if forms.infinitive then
			for slot_suffix, budu_form in pairs(budu_forms) do
				local futslot = "fut_" .. slot_suffix
				if not skip_slot(base, futslot) then
					iut.insert_forms(forms, futslot, iut.map_forms(forms.infinitive, function(form)
						if not form:find("%[") then
							form = "[[" .. form .. "]]"
						end
						return "[[" .. budu_form .. "]]" .. TEMP_REFLEXIVE_INSERTION_POINT .. " " .. form
					end))
				end
			end
		end
	end
end


-- Generate a composed tense. `pref` is the prefix of the tense (e.g. "past") and `templates` is a 6-element list of
-- templates used to generate the composed tense. Each template should have a %s where the l-participle is substituted
-- and a * where TEMP_REFLEXIVE_INSERTION_POINT is substituted, indicating where the reflexive clitic should go.
-- `dual_template` is true if each template has two slots in it (the first for the l-participle of [[být]], the second
-- for the l-participle of the verb itself).
local function add_composed_tense(base, pref, templates, dual_template)
	for _, props in ipairs(person_number_gender_props) do
		local dest_suffix, part_suffix, template_index = unpack(props)
		local template = templates[template_index]
		template = template:gsub("%*", TEMP_REFLEXIVE_INSERTION_POINT)
		iut.insert_forms(base.forms, pref .. "_" .. dest_suffix, iut.map_forms(base.forms["lpart_" .. part_suffix], function(form)
			if not form:find("%[") then
				form = "[[" .. form .. "]]"
			end
			if dual_template then
				local byl_form = "[[byl" .. part_suffix_to_ending[part_suffix] .. "]]"
				return template:format(byl_form, form)
			else
				return template:format(form)
			end
		end))
	end
end


local function generate_composed_tenses(base)
	-- Then generate the past tense by combining the l-participle with the present tense of [[být]].
	add_composed_tense(base, "past", {"%s [[jsem]]*", "%s [[jsi]]*", "%s*", "%s [[jsme]]*", "%s [[jste]]*", "%s*"})
	add_composed_tense(base, "cond", {"%s [[bych]]*", "%s [[bys]]*", "%s [[by]]*", "%s [[bychom]]*", "%s [[byste]]*", "%s [[by]]*"})
	add_composed_tense(base, "cond_past", {"%s [[bych]]* %s", "%s [[bys]]* %s", "%s [[by]]* %s",
		"%s [[bychom]]* %s", "%s [[byste]]* %s", "%s [[by]]* %s"}, "dual template")
end


-- Add a reflexive pronoun as appropriate to the base forms that were generated.
local function add_reflexive_to_forms(base)
	if not base.refl then
		-- Remove insertion point character.
		for slot, accel in pairs(verb_slots) do
			if base.forms[slot] then
				for _, form in ipairs(base.forms[slot]) do
					form.form = form.form:gsub(TEMP_REFLEXIVE_INSERTION_POINT, "")
				end
			end
		end
		return
	end

	clitic = " [[" .. base.refl .. "]]"
	local paren_clitic = " ([[" .. base.refl .. "]])"
	for slot, accel in pairs(verb_slots) do
		if base.forms[slot] then
			local this_clitic = slot == "vnoun" and paren_clitic or clitic
			-- Add clitic as separate word before all other forms.
			for _, form in ipairs(base.forms[slot]) do
				if form.form:find(TEMP_REFLEXIVE_INSERTION_POINT) then
					form.form = form.form:gsub(TEMP_REFLEXIVE_INSERTION_POINT, this_clitic)
				else
					if not form.form:find("%[") then
						form.form = "[[" .. form.form .. "]]"
					end
					form.form = form.form .. this_clitic
				end
				form.form = form.form:gsub("%[%[bys%]%] %[%[(s[ei])%]%]", "[[by]] [[%1s]]")
				form.form = form.form:gsub("%[%[jsi%]%] %[%[(s[ei])%]%]", "[[%1s]]")
			end
		end
	end
end


local function conjugate_verb(base)
	add_infinitive(base)
	conjs[base.conj](base, base.lemma)
	set_present_future(base)
	generate_composed_tenses(base)
	add_reflexive_to_forms(base)
end


local function fetch_footnotes(separated_group)
	local footnotes
	for j = 2, #separated_group - 1, 2 do
		if separated_group[j + 1] ~= "" then
			error("Extraneous text after bracketed footnotes: '" .. table.concat(separated_group) .. "'")
		end
		if not footnotes then
			footnotes = {}
		end
		table.insert(footnotes, separated_group[j])
	end
	return footnotes
end


local function parse_indicator_spec(angle_bracket_spec)
	local inside = rmatch(angle_bracket_spec, "^<(.*)>$")
	assert(inside)
	local function parse_err(msg)
		error(msg .. ": '" .. inside .. "'")
	end
	local base = {overrides = {}, forms = {}}
	local segments = iut.parse_balanced_segment_run(inside, "[", "]")
	local dot_separated_groups = iut.split_alternating_runs_and_strip_spaces(segments, "%.")
	local major_class = dot_separated_groups[1][1]
	if major_class ~= "I" and major_class ~= "II" and major_class ~= "III" and major_class ~= "IV" and
		major_class ~= "V" and major_class ~= "irreg" then
		parse_err("Unrecognized major verb class '" .. major_class .. "'; expected 'I', 'II', 'III', 'IV', 'V' or 'irreg'")
	end
	if #dot_separated_groups[1] > 1 then
		parse_err("No footnotes allowed after major class")
	end
	local start_of_indicators = major_class == "irreg" and 2 or 3
	if major_class == "irreg" then
		base.conj = "irreg"
	else
		local minor_class_and_variants = dot_separated_groups[2][1]
		local minor_class, variants = rmatch(minor_class_and_variants, "^([123])/(.*)$")
		if not minor_class then
			minor_class = rmatch(minor_class_and_variants, "^([123])$")
		end
		if not minor_class then
			parse_err("Unrecognized minor verb class; expected 1, 2 or 3")
		end
		base.conj = major_class .. "." .. minor_class
		if variants then
			dot_separated_groups[2][1] = variants
			if parse[base.conj] then
				local function parse_err(msg)
					error(msg .. ": '" .. table.concat(dot_separated_groups[2]) .. "'")
				end
				parse[base.conj](base, dot_separated_groups[2], parse_err)
			else
				parse_err("No variants allowed for conjugation " .. base.conj)
			end
		elseif #dot_separated_groups[2] > 1 then
			parse_err("No footnotes allowed after minor class")
		end
	end
	for i, dot_separated_group in ipairs(dot_separated_groups) do
		if i >= start_of_indicators then
			local part = dot_separated_group[1]
			local stem, rest = rmatch(part, "^([a-z_]+):(.*)$")
			if override_stems[stem] then
				if base.overrides[stem] then
					parse_err(("Two overrides specified for stem '%s'"):format(stem))
				end
				base.overrides[stem] = {}
				dot_separated_group[1] = rest
				local colon_separated_groups = iut.split_alternating_runs_and_strip_spaces(dot_separated_group, ":")
				for i, colon_separated_group in ipairs(colon_separated_groups) do
					local form = colon_separated_group[1]
					if form == "" then
						-- No need to use parse_err() as the overall spec is probably irrelevant
						error(("Use - to indicate a missing stem '%s': '%s'"):format(stem, table.concat(dot_separated_group)))
					elseif form == "-" then
						if #colon_separated_group > 1 then
							error(("No footnotes allowed with '-' as stem value for stem '%s': '%s'"):format(stem,
								table.concat(dot_separated_group)))
						end
						-- don't record a value
					else
						local value = {}
						value.form = form
						value.footnotes = fetch_footnotes(colon_separated_group)
						table.insert(base.overrides[stem], value)
					end
				end
			elseif part == "" then
				if #dot_separated_group == 1 then
					error("Blank indicator: '" .. inside .. "'")
				end
				base.footnotes = fetch_footnotes(dot_separated_group)
			elseif #dot_separated_group > 1 then
				error("Footnotes only allowed with stem overridese or by themselves: '" .. table.concat(dot_separated_group) .. "'")
			elseif part == "impf" or part == "pf" or part == "both" then
				if base.aspect then
					parse_err("Can't specify aspect twice")
				end
				base.aspect = part
			elseif part == "tr" or part == "intr" or part == "mixed" then
				if base.trans then
					parse_err("Can't specify transitivity twice")
				end
				base.trans = part
			elseif part == "ppp" or part == "-ppp" then
				if base.ppp ~= nil then
					parse_err("Can't specify past passive participle indicator twice")
				end
				base.ppp = part == "ppp"
			elseif part == "impers" or part == "3only" or part == "plonly" or part == "3plonly" or part == "3orplonly" or
				part == "ě" then
				local field = part
				if part == "ě" then
					field = "ye"
				end
				if base[field] then
					parse_err(("Can't specify '%s' twice"):format(part))
				end
				base[field] = true
			else
				error("Unrecognized indicator '" .. part .. "': " .. angle_bracket_spec)
			end
		end
	end
	return base
end


local function normalize_all_lemmas(alternant_multiword_spec, pagename)
	iut.map_word_specs(alternant_multiword_spec, function(base)
		if base.lemma == "" then
			base.lemma = pagename
		end
		base.orig_lemma = base.lemma
		base.orig_lemma_no_links = m_links.remove_links(base.lemma)
		-- If reflexive verb is explicitly specified by the user, we will convert the space before the reflexive clitic
		-- to an underscore in split_bracketed_runs_into_words().
		local active_verb, refl = rmatch(base.orig_lemma_no_links, "^(.*)[ _](s[ei])$")
		if active_verb then
			base.refl = refl
			base.lemma = active_verb
		else
			base.lemma = base.orig_lemma_no_links
		end
		-- Convert "old-style" lemma e.g. [[dělati]], [[nésti]], [[moci]] into new-style [[dělat]], [[nést]], [[moct]]
		local old_style_stem = rmatch(base.lemma, "^(.*)i$")
		if old_style_stem then
			if rfind(old_style_stem, "c$") then
				-- [[moci]], [[peci]], etc.
				base.lemma = old_style_stem .. "t"
			elseif rfind(old_style_stem, "t$") then
				base.lemma = old_style_stem
			else
				error(("Unrecognized old-style lemma '%s', should end in -ci or -ti"):format(base.orig_lemma_no_links))
			end
		end
	end)
end


local function detect_indicator_spec(base)
	if not base.aspect then
		error("Aspect of 'pf', 'impf' or 'both' must be specified")
	end
	if base.refl then
		if base.trans then
			error("Can't specify transitivity with reflexive verb, they're always intransitive: '" .. base.orig_lemma_no_links .. "'")
		end
	elseif not base.trans then
		error("Transitivity of 'tr', 'intr' or 'mixed' must be specified")
	end
	if base.ppp ~= nil then
		if base.trans == "intr" then
			error("Can't specify 'ppp' or '-ppp' with intransitive verbs")
		end
	elseif base.trans and base.trans ~= "intr" then
		error("Must specify 'ppp' or '-ppp' with transitive or mixed-transitive verbs")
	end
end


local function detect_all_indicator_specs(alternant_multiword_spec)
	iut.map_word_specs(alternant_multiword_spec, function(base)
		detect_indicator_spec(base)
		if not alternant_multiword_spec.aspect then
			alternant_multiword_spec.aspect = base.aspect
		elseif alternant_multiword_spec.aspect ~= base.aspect then
			alternant_multiword_spec.aspect = "both"
		end
		if alternant_multiword_spec.refl == nil then
			alternant_multiword_spec.refl = base.refl
		elseif alternant_multiword_spec.refl ~= base.refl then
			error("With multiple alternants, all must agree on reflexive clitic")
		end
		if not alternant_multiword_spec.trans then
			alternant_multiword_spec.trans = base.trans
		elseif alternant_multiword_spec.trans ~= base.trans then
			alternant_multiword_spec.trans = "mixed"
		end
		for _, prop in ipairs({"nopres", "noimp", "nopast", "impers", "only3", "onlypl", "only3pl", "only3orpl"}) do
			if alternant_multiword_spec[prop] == nil then
				alternant_multiword_spec[prop] = base[prop]
			elseif alternant_multiword_spec[prop] ~= base[prop] then
				alternant_multiword_spec[prop] = false
			end
		end
	end)
end


local function add_categories(alternant_multiword_spec)
	local cats = {}
	local function insert(cattype)
		table.insert(cats, "Czech " .. cattype .. " verbs")
	end
	if alternant_multiword_spec.aspect == "impf" then
		insert("imperfective")
	elseif alternant_multiword_spec.aspect == "pf" then
		insert("perfective")
	else
		assert(alternant_multiword_spec.aspect == "both")
		insert("imperfective")
		insert("perfective")
		insert("biaspectual")
	end
	if alternant_multiword_spec.trans == "tr" then
		insert("transitive")
	elseif alternant_multiword_spec.trans == "intr" then
		insert("intransitive")
	elseif alternant_multiword_spec.trans == "mixed" then
		insert("transitive")
		insert("intransitive")
	end
	if alternant_multiword_spec.is_refl then
		insert("reflexive")
	end
	if alternant_multiword_spec.impers then
		insert("impersonal")
	end
	iut.map_word_specs(alternant_multiword_spec, function(base)
		if base.conj == "irreg" or base.irreg then
			insert("irregular")
		end
		if base.conj ~= "irreg" then
			insert("class " .. base.conj)
			insert("class " .. rsub(base.conj, "^([0-9]+).*", "%1"))
		end
	end)
	alternant_multiword_spec.categories = cats
end


local function show_forms(alternant_multiword_spec)
	local lemmas = {}
	if alternant_multiword_spec.forms.infinitive then
		for _, inf in ipairs(alternant_multiword_spec.forms.infinitive) do
			table.insert(lemmas, inf.form)
		end
	end
	local props = {
		lemmas = lemmas,
		slot_table = verb_slots,
		lang = lang,
	}
	iut.show_forms(alternant_multiword_spec.forms, props)
end


local function make_table(alternant_multiword_spec)
	local forms = alternant_multiword_spec.forms

	local table_spec_overall = [=[
<div class="NavFrame" style="width:90em;">
<div class="NavHead" style="background:#e0e0ff;">{title}{annotation}</div>
<div class="NavContent">
{\op}| class="inflection-table inflection inflection-cs inflection-verb" style="border: 2px solid black;" border=1
|-
! rowspan=3 colspan=2 style="background:#cddfff" |
! colspan=3 style="background:#cddfff; text-align: center;" | [[singular]]
! colspan=4 style="background:#cddfff; text-align: center;" | [[plural]]
|-
! rowspan=2 style="background:#e7f3ff; text-align: center;vertical-align:middle;"| [[masculine]]
! rowspan=2 style="background:#e7f3ff; text-align: center;vertical-align:middle;"| [[feminine]]
! rowspan=2 style="background:#e7f3ff; text-align: center;vertical-align:middle;"| [[neuter]]
! colspan=2 style="background:#e7f3ff; text-align: center;"| [[masculine]]
! rowspan=2 style="background:#e7f3ff; text-align: center;vertical-align:middle;"| [[feminine]]
! rowspan=2 style="background:#e7f3ff; text-align: center;vertical-align:middle;"| [[neuter]]
|-
! style="background:#e7f3ff; text-align: center;"| [[animate]]
! style="background:#e7f3ff; text-align: center;"| [[inanimate]]
|-
! style="background:#e7f3ff; text-align: center; width:8%;"| invariable
! style="background:#cddfff; text-align: center; width:8%;"| [[infinitive]]
| colspan=7 | {infinitive}
|-
! rowspan=4 style="background:#e7f3ff; text-align: center; vertical-align: middle;"| number/gender<br/>only
! style="background:#cddfff; text-align: center;"| [[short]]&nbsp;[[passive]]&nbsp;[[participle]]
| {ppp_m}
| {ppp_f}
| {ppp_n}
| {ppp_mp_an}
| {ppp_mp_in}
| {ppp_fp}
| {ppp_np}
|-
! style="background:#cddfff; text-align: center;"| l-participle
| {lpart_m}
| {lpart_f}
| {lpart_n}
| {lpart_mp_an}
| {lpart_mp_in}
| {lpart_fp}
| {lpart_np}
|-
! style="background:#cddfff; text-align: center;"| [[present]]&nbsp;[[transgressive]]
| {pres_tgress_m}
| colspan=2|{pres_tgress_fn}
| colspan=4|{pres_tgress_p}
|-
! style="background:#cddfff; text-align: center;"| [[past]]&nbsp;[[transgressive]]
| {past_tgress_m}
| colspan=2|{past_tgress_fn}
| colspan=4|{past_tgress_p}
|-
! rowspan=3 style="background:#e7f3ff; text-align: center; vertical-align: middle;"| declined<br/>as<br/>adjective
! style="background:#cddfff; text-align: center;"| [[present]]&nbsp;[[active]]&nbsp;[[participle]]
| colspan=7 | {pres_act_part}
|-
! style="background:#cddfff; text-align: center;"| [[past]]&nbsp;[[active]]&nbsp;[[participle]]
| colspan=7 | {past_act_part}
|-
! style="background:#cddfff; text-align: center;"| [[long]]&nbsp;[[passive]]&nbsp;[[participle]]
| colspan=7 | {long_pass_part}
|-
! style="background:#e7f3ff; text-align: center;"| case/number<br/>only
! style="background:#cddfff; text-align: center; vertical-align: middle;"| [[verbal noun|verbal&nbsp;noun]]
| style="vertical-align: middle;" colspan=7 | {vnoun}
|-
{indicative_header}{present_table}| {fut_1s}
| {fut_2s}
| {fut_3s}
| {fut_1p}
| colspan=2 | {fut_2p}
| {fut_3p}
|-
{past_table}{conditional_header}{cond_table}{cond_past_table}! style="background:#cddfff; text-align: center; border-top-width: 3px;" colspan=2 | [[imperative mood|imperative]]
| style="border-top-width: 3px;" | —
| style="border-top-width: 3px;" | {imp_2s}
| style="border-top-width: 3px;" | —
| style="border-top-width: 3px;" | {imp_1p}
| style="border-top-width: 3px;" colspan=2 | {imp_2p}
| style="border-top-width: 3px;" | —
|{\cl}{notes_clause}</div></div>]=]

	local table_spec_person_number_header = [=[
!style="background:#cddfff; text-align: center; vertical-align: middle; border-top-width: 3px;" rowspan=3 colspan=2 | MOOD
!style="background:#cddfff; text-align: center; border-top-width: 3px;" colspan=3 | [[singular]]
!style="background:#cddfff; text-align: center; border-top-width: 3px;" colspan=4 | [[plural]] (or polite)
|-
!style="background:#e7f3ff; text-align: center; vertical-align: middle;" rowspan=2 | [[first person|first]]
!style="background:#e7f3ff; text-align: center; vertical-align: middle;" rowspan=2 | [[second person|second]]
!style="background:#e7f3ff; text-align: center; vertical-align: middle;" rowspan=2 | [[third person|third]]
!style="background:#e7f3ff; text-align: center; vertical-align: middle;" rowspan=2 | [[first person|first]]
!style="background:#e7f3ff; text-align: center; vertical-align: middle;" colspan=2 | [[second person|second]]
!style="background:#e7f3ff; text-align: center; vertical-align: middle;" rowspan=2 | [[third person|third]]
|-
!style="background:#e7f3ff; text-align: center;" | [[polite]] [[singular]]
!style="background:#e7f3ff; text-align: center;" | [[plural]]
|-
]=]

	local table_spec_single_aspect_present = [=[
! style="background:#cddfff; text-align: center;" colspan=2 | [[present tense|present]]
| {pres_1s}
| {pres_2s}
| {pres_3s}
| {pres_1p}
| colspan=2 | {pres_2p}
| {pres_3p}
|-
! style="background:#cddfff; text-align: center;" colspan=2 | [[future tense|future]]
]=]

	local table_spec_biaspectual_present = [=[
! style="background:#cddfff; text-align: center;" colspan=2 | [[present tense|present]]&nbsp;(imperfective)
| rowspan=2 | {pres_1s}
| rowspan=2 | {pres_2s}
| rowspan=2 | {pres_3s}
| rowspan=2 | {pres_1p}
| colspan=2 rowspan=2 | {pres_2p}
| rowspan=2 | {pres_3p}
|-
! style="background:#cddfff; text-align: center;" colspan=2 | [[future tense|future]]&nbsp;(perfective)
|-
! style="background:#cddfff; text-align: center;" colspan=2 | [[future tense|future]]&nbsp;(imperfective)
]=]

	local table_spec_person_number_gender = [=[
!style="background:#cddfff; text-align: center; vertical-align: middle;" rowspan=4 | TENSE
!style="background:#e7f3ff; text-align: center;"| [[masculine]]&nbsp;[[animate]]
| rowspan=2 | {PREF_1sm}
| rowspan=2 | {PREF_2sm}
| rowspan=2 | {PREF_3sm}
| rowspan=2 | {PREF_1pm}
| rowspan=2 | {PREF_2pm_polite}
| rowspan=2 | {PREF_2pm_plural}
| {PREF_3pm_an}
|-
!style="background:#e7f3ff; text-align: center;"| [[masculine]]&nbsp;[[inanimate]]
| {PREF_3pm_in}
|-
!style="background:#e7f3ff; text-align: center;"| [[feminine]]
| {PREF_1sf}
| {PREF_2sf}
| {PREF_3sf}
| {PREF_1pf}
| {PREF_2pf_polite}
| {PREF_2pf_plural}
| {PREF_3pf}
|-
!style="background:#e7f3ff; text-align: center;"| [[neuter]]
| {PREF_1sn}
| {PREF_2sn}
| {PREF_3sn}
| {PREF_1pn}
| {PREF_2pn_polite}
| {PREF_2pn_plural}
| {PREF_3pn}
|-
]=]

	local notes_template = [===[
<div style="width:100%;text-align:left;background:#cddfff">
<div style="display:inline-block;text-align:left;padding-left:1em;padding-right:1em">
{footnote}
</div></div>
]===]

	if alternant_multiword_spec.title then
		forms.title = alternant_multiword_spec.title
	else
		forms.title = 'Conjugation of <i lang="cs">' .. forms.lemma .. '</i>'
	end

	local ann_parts = {}
	local saw_irreg_conj = false
	local saw_base_irreg = false
	local all_irreg_conj = true
	local conjs = {}
	iut.map_word_specs(alternant_multiword_spec, function(base)
		m_table.insertIfNot(conjs, base.conj)
		if base.conj == "irreg" then
			saw_irreg_conj = true
		else
			all_irreg_conj = false
		end
		if base.irreg then
			saw_base_irreg = true
		end
	end)
	if all_irreg_conj then
		table.insert(ann_parts, "irregular")
	else
		table.insert(ann_parts, "class " .. table.concat(conjs, " // "))
	end
	table.insert(ann_parts,
		alternant_multiword_spec.aspect == "impf" and "imperfective" or
		alternant_multiword_spec.aspect == "pf" and "perfective" or
		"biaspectual")
	if alternant_multiword_spec.trans then
		table.insert(ann_parts,
			alternant_multiword_spec.trans == "tr" and "transitive" or
			alternant_multiword_spec.trans == "intr" and "intransitive" or
			"transitive and intransitive"
		)
	end
	if alternant_multiword_spec.is_refl then
		table.insert(ann_parts, "reflexive")
	end
	if alternant_multiword_spec.impers then
		table.insert(ann_parts, "impersonal")
	end
	if saw_base_irreg and not saw_irreg_conj then
		table.insert(ann_parts, "irregular")
	end
	forms.annotation = " (" .. table.concat(ann_parts, ", ") .. ")"

	if alternant_multiword_spec.aspect == "pf" then
		forms.aspect_indicator = "[[perfective aspect]]"
	elseif alternant_multiword_spec.aspect == "impf" then
		forms.aspect_indicator = "[[imperfective aspect]]"
	else
		forms.aspect_indicator = "[[biaspectual]]"
	end

	forms.notes_clause = forms.footnote ~= "" and
		m_string_utilities.format(notes_template, forms) or ""
	forms.present_table = m_string_utilities.format(
		alternant_multiword_spec.aspect == "both" and table_spec_biaspectual_present or table_spec_single_aspect_present,
		forms
	)
	local table_spec_indicative_header = table_spec_person_number_header:gsub("MOOD", "[[indicative mood|indicative]]")
	forms.indicative_header = m_string_utilities.format(table_spec_indicative_header, forms)
	local table_spec_conditional_header = table_spec_person_number_header:gsub("MOOD", "[[conditional mood|conditional]]")
	forms.conditional_header = m_string_utilities.format(table_spec_conditional_header, forms)
	local table_spec_past = table_spec_person_number_gender:gsub("TENSE", "[[past tense|past]]"):gsub("PREF", "past")
	forms.past_table = m_string_utilities.format(table_spec_past, forms)
	local table_spec_cond = table_spec_person_number_gender:gsub("TENSE", "[[present tense|present]]"):gsub("PREF", "cond")
	forms.cond_table = m_string_utilities.format(table_spec_cond, forms)
	local table_spec_cond_past = table_spec_person_number_gender:gsub("TENSE", "[[past tense|past]]"):gsub("PREF", "cond_past")
	forms.cond_past_table = m_string_utilities.format(table_spec_cond_past, forms)
	return m_string_utilities.format(table_spec_overall, forms)
end


-- Externally callable function to parse and conjugate a verb given user-specified arguments. Return value is
-- ALTERNANT_MULTIWORD_SPEC, an object where the conjugated forms are in `ALTERNANT_MULTIWORD_SPEC.forms`
-- for each slot. If there are no values for a slot, the slot key will be missing. The value for a given slot
-- is a list of objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms(parent_args, from_headword)
	local params = {
		[1] = {required = true, default = "jmenovat<III.2.both.tr.ppp>"},
		title = {},
		pagename = {},
		json = {type = "boolean"},
		pos = {},
	}

	local args = m_para.process(parent_args, params)

	-- Ensure we don't split a reflexive verb by replacing the space before 'se' or 'si' with an underscore.
	local function split_bracketed_runs_into_words(bracketed_runs)
		for j, segment in ipairs(bracketed_runs) do
			if j % 2 == 1 then
				bracketed_runs[j] = segment:gsub(" (s[ei])$", "_%1")
			end
		end
		return iut.default_split_bracketed_runs_into_words(bracketed_runs)
	end

	local parse_props = {
		parse_indicator_spec = parse_indicator_spec,
		split_bracketed_runs_into_words = split_bracketed_runs_into_words,
		angle_brackets_omittable = true,
		allow_blank_lemma = true,
	}
	local alternant_multiword_spec = iut.parse_inflected_text(args[1], parse_props)
	alternant_multiword_spec.title = args.title
	alternant_multiword_spec.args = args
	local pagename = args.pagename or mw.title.getCurrentTitle().subpageText
	alternant_multiword_spec.forms = {}
	normalize_all_lemmas(alternant_multiword_spec, pagename)
	detect_all_indicator_specs(alternant_multiword_spec)
	local inflect_props = {
		slot_table = verb_slots,
		lang = lang,
		inflect_word_spec = conjugate_verb,
		-- We add links around the generated verbal forms rather than allow the entire multiword
		-- expression to be a link, so ensure that user-specified links get included as well.
		include_user_specified_links = true,
	}
	iut.inflect_multiword_or_alternant_multiword_spec(alternant_multiword_spec, inflect_props)
	-- process_overrides(alternant_multiword_spec.forms, args)
	add_categories(alternant_multiword_spec)
	return alternant_multiword_spec
end


-- Entry point for {{cs-conj}}. Template-callable function to parse and conjugate a verb given
-- user-specified arguments and generate a displayable table of the conjugated forms.
function export.show(frame)
	local parent_args = frame:getParent().args
	local alternant_multiword_spec = export.do_generate_forms(parent_args)
	show_forms(alternant_multiword_spec)
	return make_table(alternant_multiword_spec) .. require("Module:utilities").format_categories(alternant_multiword_spec.categories, lang)
end


return export
