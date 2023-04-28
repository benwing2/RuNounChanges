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
local m_string_utilities = require("Module:string utilities")
local m_script_utilities = require("Module:script utilities")
local iut = require("Module:inflection utilities")
local m_para = require("Module:parameters")
local com = require("Module:cs-common")

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


local output_verb_slots = {
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
	["lpart_m"] = "m|s|l-part",
	["lpart_f"] = "f|s|l-part",
	["lpart_n"] = "n|s|l-part",
	["lpart_mp_an"] = "an|m|p|l-part",
	["lpart_mp_in"] = "in|m|p|l-part",
	["lpart_fp"] = "f|p|l-part",
	["lpart_np"] = "n|p|l-part",
	["ppp_m"] = "short|m|s|past|pass|part",
	["ppp_f"] = "short|f|s|past|pass|part",
	["ppp_n"] = "short|n|s|past|pass|part",
	["ppp_mp_an"] = "short|an|m|p|past|pass|part",
	["ppp_mp_in"] = "short|in|m|p|past|pass|part",
	["ppp_fp"] = "short|f|p|past|pass|part",
	["ppp_np"] = "short|n|p|past|pass|part",
	["past_1sm"] = "-",
	["past_1sf"] = "-",
	["past_1sn"] = "-",
	["past_2sm"] = "-",
	["past_2sf"] = "-",
	["past_2sn"] = "-",
	["past_3sm"] = "-",
	["past_3sf"] = "-",
	["past_3sn"] = "-",
	["past_1pm"] = "-",
	["past_1pf"] = "-",
	["past_1pn"] = "-",
	["past_2pm_polite"] = "-",
	["past_2pm_plural"] = "-",
	["past_2pf_polite"] = "-",
	["past_2pf_plural"] = "-",
	["past_2pn_polite"] = "-",
	["past_2pn_plural"] = "-",
	["past_3pm_an"] = "-",
	["past_3pm_in"] = "-",
	["past_3pf"] = "-",
	["past_3pn"] = "-",
}


local input_verb_slots = {}
for slot, _ in pairs(output_verb_slots) do
	if rfind(slot, "^pres_[123]") then
		table.insert(input_verb_slots, rsub(slot, "^pres_", "pres_fut_"))
	elseif not rfind(slot, "^fut_") then
		table.insert(input_verb_slots, slot)
	end
end


local budu_forms = {
	["1s"] = "budu",
	["2s"] = "budeš",
	["3s"] = "bude",
	["1p"] = "budeme",
	["2p"] = "budete",
	["3p"] = "budou",
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
	iut.add_forms(base.forms, slot, stems, endings, com.combine_stem_ending)
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
	add(base, "imp_2s", sg2form, "", footnotes)
	-- "Long" imperatives end in -i
	local stem = rmatch(sg2, "^(.-)i$")
	if stem then
		add(base, "imp_1p", plstem, "ěme", footnotes)
		add(base, "imp_2p", plstem, "ěte", footnotes)
	elseif com.ends_in_vowel(sg2) then
		error("Invalid 2sg imperative, ends in vowel other than -i: '" .. sg2 .. "'")
	else
		add(base, "imp_1p", sg2form, "me", footnotes)
		add(base, "imp_2p", sg2form, "te", footnotes)
	end
end


local function add_present_a_imperative(base, stems)
	map_forms(stems, function(stem, footnotes)
		add_imperative(base, stem .. "ej", footnotes)
	end)
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
			if rfind(stem, "[sš][tť]$") or rfind(stem, "tř$") then
				imptypes = {"long", "short"}
			else
				-- Substitute 'ch' with a single character to make the following code simpler.
				local modstem = stem:gsub("ch", com.TEMP_CH)
				if rfind(modstem, com.cons_c .. "[lr]" .. com.cons_c .. "$") then
					-- [[trp]]; not long imperative.
					imptypes = "short"
				elseif rfind(modstem, com.cons_c .. com.cons_c .. "$") then
					imptypes = "long"
				else
					imptypes = "short"
				end
			end
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
				stem = com.apply_vowel_alternation(base.ye and "quant-ě" or "quant", stem, "noerror", "ring-u-to-u")
				if rfind(stem, "[" .. com.paired_plain .. com.velar .. "]$") then
					sg2 = com.apply_second_palatalization(stem, "is verb")
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


local function add_pres_fut(base, stems, sg1, sg2, sg3, pl1, pl2, pl3, footnotes, ptr_endings)
	add(base, "pres_fut_1s", stems, sg1, footnotes)
	add(base, "pres_fut_2s", stems, sg2, footnotes)
	add(base, "pres_fut_3s", stems, sg3, footnotes)
	add(base, "pres_fut_1p", stems, pl1, footnotes)
	add(base, "pres_fut_2p", stems, pl2, footnotes)
	add(base, "pres_fut_3p", stems, pl3, footnotes)
end


local function add_pres_tgress(base, stems, prtr_endings)
	map_forms(prtr_endings, function(prtr_ending, prtr_footnotes)
		if prtr_ending == "ou" then
			add(base, "pres_tgress_m", stems, "a", prtr_footnotes)
		elseif prtr_ending == "í" then
			-- ě may be converted to e by com.combine_stem_ending()
			add(base, "pres_tgress_m", stems, "ě", prtr_footnotes)
		elseif prtr_ending == "ají" then
			add(base, "pres_tgress_m", stems, "aje", prtr_footnotes)
		else
			error(("Unrecognized present transgressive ending '%s', expected 'ou', 'í' or 'ají'"):format(prtr_ending))
		end
		add(base, "pres_tgress_fn", stems, prtr_ending .. "c", prtr_footnotes)
		add(base, "pres_tgress_p", stems, prtr_ending .. "ce", prtr_footnotes)
		add(base, "past_act_part", stems, prtr_ending .. "ce", prtr_footnotes)
	end)
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
		p3_ending = "ú"
	end
	add_pres_fut(base, stems, nil, "eš", "e", "eme", "ete", nil, footnotes)
	add_pres_fut(base, pres1s3p_stems, s1_ending, nil, nil, nil, nil, p3_ending, footnotes)
	add_pres_tgress(base, stems, prtr_endings or p3_ending)
	if not noimp then
		add_imperative_from_present(base, pres1s3p_stems, nil, footnotes)
	end
end


local function add_present_a(base, stems, noimp)
	stems = base.pres_stems or stems
	add_pres_fut(base, stems, "ám", "áš", "á", "áme", "áte", "ají")
	add_pres_tgress(base, stems, "ají")
	if not noimp then
		add_present_a_imperative(base, stems)
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


local function add_past(base, msgstems, reststems, ptr_stems)
	reststems = reststems or msgstems
	-- First, generate the l-participle forms.
	add(base, "lpart_m", msgstems, "l")
	add(base, "lpart_f", reststems, "la")
	add(base, "lpart_n", reststems, "lo")
	add(base, "lpart_mp_an", reststems, "li")
	add(base, "lpart_mp_in", reststems, "ly")
	add(base, "lpart_fp", reststems, "ly")
	add(base, "lpart_np", reststems, "la")

	-- Then generate the past tense by combining the l-participle with the present tense of [[být]].
	local function add_forms_with_aux(source_slot, dest_slot, aux_form, split_by_animacy)
		if split_by_animacy then
			genders = {"m_an", "m_in", "f", "n"}
		else
			genders = {"m", "f", "n"}
		end
		for _, gender in ipairs(genders) do
			if type(source_slot) == "string" then
				source_slot = source_slot:format(gender)
			else
				source_slot = source_slot(gender)
			end
			if type(dest_slot) == "string" then
				dest_slot = dest_slot:format(gender)
			else
				dest_slot = dest_slot(gender)
			end
			if aux_form then
				iut.insert_forms(base.forms, dest_slot, iut.map_forms(base.forms[source_slot], function(form)
					return "[[" .. form .. "]] [[" .. aux_form .. "]]" end))
			else
				iut.insert_forms(base.forms, dest_slot, iut.map_forms(base.forms[source_slot], function(form)
					return form end))
			end
		end
	end

	add_forms_with_aux("lpart_%s", "past_1s%s", "jsem")
	add_forms_with_aux("lpart_%s", "past_2s%s", "jsi")
	add_forms_with_aux("lpart_%s", "past_3s%s", nil)
	local function plural_source_slot(gender)
		if gender == "m" then
			return "lpart_mp_an"
		else
			return ("lpart_%sp"):format(gender)
		end
	end
	add_forms_with_aux(plural_source_slot, "past_1p%s", "jsme")
	add_forms_with_aux("lpart_%s", "past_2p%s_polite", "jste")
	add_forms_with_aux(plural_source_slot, "past_2p%s_plural", "jste")
	local function plural_source_slot_with_animacy(gender)
		if gender == "m_an" then
			return "lpart_mp_an"
		elseif gender == "m_in" then
			return "lpart_mp_an"
		else
			return ("lpart_%sp"):format(gender)
		end
	end
	add_forms_with_aux(plural_source_slot_with_animacy, "past_3p%s", nil, "split by animacy")

	-- Add the past transgressive; not available for imperfective verbs.
	if base.aspect == "impf" then
		return
	end
	if not ptr_stems then
		ptr_stems = {}
		map_forms(msgstems, function(stem, footnotes)
			local ptr_stem = stem
			if rfind(stem, com.vowel_c .. "$") then
				ptr_stem = ptr_stem .. "v"
			end
			table.insert(ptr_stems, {form = ptr_stem, footnotes = footnotes})
		end)
	end
	add(base, "past_tgress_ms", ptr_stems, "")
	add(base, "past_tgress_fns", ptr_stems, "ši")
	add(base, "past_tgress_p", ptr_stems, "še")
end


local function add_ppp(base, stems, vn_stems)
	if base.ppp then
		add(base, "long_pass_part", stems, "ý")
		add(base, "ppp_m", stems, "")
		add(base, "ppp_f", stems, "a")
		add(base, "ppp_n", stems, "o")
		add(base, "ppp_mp_an", stems, "i")
		add(base, "ppp_mp_in", stems, "y")
		add(base, "ppp_fp", stems, "y")
		add(base, "ppp_np", stems, "a")
	end
	vn_stems = vn_stems or stems
	-- FIXME, sometimes the vowel shortens; e.g. [[ptát]] ppp 'ptán' vn 'ptaní'; similarly [[hrát]] but not all
	-- monosyllabic verbs, e.g. [[dbát]] ppp 'dbán' vn. 'dbání' or 'dbaní' and [[znát]] ppp. 'znán' vn. only 'znání'.
	add(base, "vnoun", vn_stems, "í")
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
	local colon_separated_groups = iut.split_alternating_runs_and_strip_spaces(conjmod_segments, ":")
	local retval = {}
	for _, group in ipairs(colon_separated_groups) do
		for i, code in ipairs(allowed_codes) do
			allowed_codes[i] = "'" .. code .. "'"
		end
		if not allowed_code_set[group[1]] then
			parse_err(("Unrecognized variant code '%s' for %s: should be one of %s"):format(group[1], variant_type,
				m_table.serialCommaJoin(allowed_codes)))
		end
		table.insert(list, {form = group[1], footnotes = fetch_footnotes(group)})
	end
	return retval
end

	
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

[[blbnout]] (nu) (blbl ~ blbnul, blbnut, impf, vn blbnutí)
[[plácnout]] (nu) (plácl ~ plácnul, plácnut, plácnuv, vn plácnutí)
[[padnout]] (pf.) -,nu:- (padl, no PPP, padnuv ~ pad, padnutí)
[[padnout]] (biasp.) -,nu:- (padl, no PPP, padnuv ~ pad, padnutí)
[[napadnout]] -/n/n:t,nu:- (napadl, napaden, napadnuv ~ napad, napadení ~ napadnutí)
[[odpadnout]] -,-:nu (odpadl, no PPP, odpad ~ odpadnuv, odpadnutí)
[[přepadnout]] -/n/n:t,-:nu (přepadl, přepaden, přepad ~ přepadnuv, přepadení ~ přepadnutí)
[[rozpadnout se]] -,nu:- (rozpadl se, rozpadnut, rozpadnuv se ~ rozpad se, rozpadnutí se)
[[dopadnout]] -/n/n:t,nu:- (dopadl, dopaden, dopadnuv ~ dopad, dopadení ~ dopadnutí [VN differentiated by meaning: dopadení [přistižení = "catch?"] vs. dopadnutí [padnutí = "fall?"])
[[spadnout]] -/n/t,nu:- (spadl, spaden, spadnuv ~ spad, vn spadnutí)
[[upadnout]] -/n:t/t,-:nu (upadl, upaden ~ upadnut, upad ~ upadnuv, vn upadnutí)
[[vypadnout]] -,-:nu (vypadl, no PPP, vypad ~ vypadnuv, vn vypadnutí)
[[ukradnout]] - (ukradl, ukradnut, ukradnuv, ukradnutí) [but IJP commentary says 'ukraden' and 'ukradení' still in use]
[[chřadnout]] - (chřadl, no PPP, impf, chřadnutí)
[[blednout]] - (bledl, no PPP, impv, blednutí)
[[sednout]] - (sedl, no PPP, sednuv, sednutí)
[[usednout]] - (usedl, usednut, usednuv, usednutí)
[[nastydnout]] - (nastydl, nastydnut, nastydnuv, nastydnutí)
[[sládnout]] - (sládl, no PPP, impf, sládnutí)
[[vládnout]] - (vladl, no PPP, impf, vn vládnutí)
[[zvládnout]] - (zvládl, zvládnut, zvládnuv, vn zvládnutí)
[[rafnout]] (nu) (rafl ~ rafnul, rafnut, rafnuv, vn rafnutí)
[[hnout]] nu (hnul, hnut, hnuv, hnutí), same for [[pohnout]]
[[nadchnout]] (nu)/t:n (nadchl ~ nadchnul, nadchnut ~ nadšen, nadchnuv, nadchnutí ~ nadšení)
[[schnout]] - (schnul, schnut, impf, vn schnutí)
[[uschnout]] (nu) (uschl ~ uschnul, uschnut, uschnuv, vn uschnutí)
[[vyschnout]] (nu) (vyschl ~ vyschnul, no PPP, vyschnuv, vn vyschnutí)
[[bouchnout]] (nu) (bouchl ~ bouchnul, bouchnut, bouchnuv, vn bouchnutí)
[[oblehnout]] -/n (oblehl, obležen, oblehnuv, obležení)
[[stihnout]] -/n/t:n (stihl, stižen, stihnuv, stihnutí ~ stižení)
[[zastihnout]] -/n (zastihl, zastižen, zastihnuv, zastižení)
[[zdvihnout]] -/n/t:n (zdvihl, zdvižen, zdvihnuv, vn zdvihnutí ~ zdvižení)
[[pozdvihnout]] -/n (pozdvihl, pozdvižen, pozdvihnuv, vn pozdvižení)
[[střihnout]] -/n/t:n (střihl, střižen, střihnuv, střihnutí ~ střižení)
[[ustřihnout]] -/n/t:n (ustřihl, ustřižen, ustřihnuv, ustřihnutí ~ ustřižení)
[[trhnout]] (nu)/t:n (trhl ~ trhnul, trhnut ~ tržen, trhnuv, trhnutí ~ tržení)
[[podtrhnout]] (nu)/n/t or (nu)/n [by meaning] (podtrhl ~ podtrhnul, podtržen, podtrhnuv, podtrhnutí ~ podtržení [VN differentiated by meaning: podtrhnutí [of a chair], podtržení [of words]])
[[roztrhnout]] -/n (roztrhl, roztržen, roztrhnuv, roztržení)
[[vrhnout]] (nu)/t:n (vrhl ~ vrhnul, vrhnut ~ vržen, vrhnuv, vn vrhnutí ~ vržení)
[[svrhnout]] -/n (svrhl, svržen, svrhnuv, svržení)
[[vyvrhnout]] (nu) or (nu)/n [by meaning] (vyvhrl ~ vyvrhnul, vyvrhnut ~ vyvržen [PPP differentiated by meaning: 'vyvržen' [ejected (from society)], 'vyvrhnut' [published]], vyvrhnuv, vyvrhnutí ~ vyvržení)
[[sáhnout]] - (sáhl, no PPP, sáhnuv, sáhnutí)
[[zasáhnout]] -/n/t:n (zasáhl, zasažen, zasáhnuv, zasáhnuti ~ zasažení)
[[obsáhnout]] - or -/n [by meaning] (obsáhl, obsáhnut ~ obsažen [differentiated by meaning], obsáhnuv, obsáhnutí ~ obsažení)
[[přesáhnout]] -/n/t (přesáhl, přesažen, přesáhnuv, přesáhnutí)
[[dosáhnout]] -/n (dosáhl, dosažen, dosáhnuv, dosažení)
[[táhnout]] -/n (táhl, tažen, impv, tažení)
[[zatáhnout]] -/n (zatáhl, zatažen, zatáhnuv, zatažení)
[[vytáhnout]] -/n (vytáhl, vytažen, vytáhnuv, vytažení)
[[napřáhnout]] -/n/t (napřáhl, napřažen, napřáhnuv, napřáhnutí)
[[přeřeknout se]] -/n:t/t (přeřekl se, přeřečen ~ přeřeknut, přeřeknuv se, přeřeknutí se)
[[křiknout]] (nu) (křikl ~ křiknul, no PPP, křiknuv, vn křiknutí)
[[polknout]] (nu) (polkl ~ polknul, polknut, polknuv, vn polknutí)
[[zamknout]] -/n:t (zamkl, zamčen ~ zamknut, zamknuv, zamčení ~ zamknutí)
[[obemknout]] - (obemkl, obemknut, obemknuv, obemknutí)
[[odemknout]] -/n:t (odemkl, odemčen ~ odemknut, odemknuv, odemčení ~ odemknutí)
[[semknout]] -,- (semkl, semknut, semk, semknutí)
[[přimknout]] - (přimkl, přimknut, přimknuv, přimknutí)
[[vymknout]] - (vymkl, vymknut, vymknuv, vymknutí)
[[cinknout]] (nu) (cinkl ~ cinknul, cinknut, cinknuv, vn cinknutí)
[[fnrknout]] (nu) (fnrkl ~ fnrknul, no PPP, fnrknuv, fnrknutí)
[[prasknout]] (nu) (praskl ~ prasknul, prasknut, prasknuv, vn prasknutí)
[[tisknout]] - or -/n [by meaning] (tiskl, tisknut ~ tištěn [differentiated by meaning], impf, tisknutí ~ tištění)
[[stisknout]] - (stiskl, stisknut, stisknuv, stisknutí)
[[vytisknout]] (nu)/t:n (vytiskl ~ vytisknul, vytisknut ~ vytištěn, vytisknuv, vytisknutí ~ vytištění)
[[blýsknout]] (nu) (blýskl ~ blýsknul, no PPP, blýsknuv, blýsknutí)
[[tknout se]] - (tknul se, tknut [PPP with reflexive], tknuv se, vn tknutí)
[[dotknout se]] (nu)/n:t/t (dotkl se ~ dotknul se, dotčen ~ dotknut [PPP with reflexive], dotknuv se, vn dotknutí)
[[vytknout]] (nu)/n:t (vytkl ~ vytknul, vytčen ~ vytknut, vytknuv, vn vytčení ~ vytknutí); same for [[protknout]], [[zatknout]]
[[kouknout]] (nu) (koukl ~ kouknul, no PPP, kouknuv, kouknutí)
[[nařknout]] -/n:t (nařkl, nařčen ~ nařknut, nařknuv, nařčení ~ nařknutí)
[[přiřknout]] -/n:t (přiřkl, přiřčen ~ přiřknut, přiřknuv, přiřčení ~ přiřknutí)
[[uřknout]] - (uřkl, uřknut, uřknuv, uřknutí)
[[vyřknout]] -/n:t (vyřkl, vyřčen ~ vyřknut, vyřknuv, vyřčení ~ vyřknutí)
[[obléknout]] [also oblíknout ~ obléct ~ obléci ~ oblíct] -/n:t (oblékl, oblečen ~ obléknut, obléknuv, oblečení ~ obléknutí [VN differentiated by meaning: oblečení [of clothing], obléknutí])
[[vléknout]] [obsolete for vléct per IJP]
[[navléknout]] [also navlíknout ~ navléct ~ navléci ~ navlíct] -/n:t/t (navlékl, navlečen ~ navléknut, navléknuv, navléknutí)
[[převléknout]] [also převlíknout ~ převléct ~ převléci ~ převlíct] ?? -/n:t/n vs. -/n:t/t [by meaning; unless PPP is also distinguished by meaning] (převlékl ~ převléknul, převlečen ~ převléknut, převléknuv, převlečení ~ převléknutí [VN differentiated by meaning: převlečení [disguise] ~ převléknutí [change clothing]])
[[svléknout]] [also svlíknout ~ svléct ~ svléci ~ svlíct] (nu)/n:t (svlékl ~ svléknul, svlečen ~ svléknut, svléknuv, svlečení ~ svléknutí)
[[oblíknout]] - (oblíkl, oblíknut, oblíknuv, oblíknutí)
[[lnout]] nu (lnul, no PPP, impf, lnutí)
[[přilnout]] nu (přilnul, přilnut, přilnuv, přilnutí)
[[povšimnout si]] - (povšiml si, povšimnut si, povšimnuv si, povšimnutí)
[[klapnout]] (nu) (klapl ~ klapnul, klapnut, klapnuv, vn klapnutí)
[[klepnout]] (nu) (klepl ~ klepnul, klepnut, klepnuv, vn klepnutí)
[[dupnout]] (nu) (dupl ~ dupnul, no PPP, dupnuv, vn dupnutí)
[[vyhoupnout se]] (nu) (vyhoupl se ~ vyhoupnul se, vyhoupnut [WHAT DOES A REFLEXIVE VERB WITH PPP MEAN?], vyhoupnuv se, vyhoupnutí)
[[křupnout]] (nu) (křupl ~ křupnul, křupnut, křupnuv, křupnutí)
[[stárnout]] - (stárl, no PPP, impf, stárnutí)
[[užasnout]] - (užasl, no PPP, užasnuv, užasnutí)
[[zesnout]] nu (zesnul, no PPP, zesnuv, zesnutí)
[[smlsnout]] (nu) (smlsl ~ smlsnul, no PPP, impf, vn smlsnutí)
[[usnout]] nu (usnul, usnut, usnuv, usnutí)
[[bohatnout]] - (bohatl, no PPP, impf, bohatnutí)
[[procitnout]] - (procitl, no PPP, procitnuv, procitnutí)
[[zhltnout]] (nu) (zhltl ~ zhltnul, zhltnut, zhltnuv, vn zhltnutí)
[[škrtnout]] (nu) (šrktl ~ šrktnul, škrtnout, šrktnuv, vn šrktnutí)
[[zvrtnout]] (nu) (zvrtl ~ zvrtnul, zvrtnut, zvrtnuv, vn zvrtnutí)
[[couvnout]] (nu) (couvl ~ couvnul, no PPP, couvnuv, vn couvnutí)
[[naleznout]] [not in IJP] [but IJP commentary says 'nalezen' and 'nalezení' still in use]
[[vynaleznout]] [not in IJP] [but IJP commentary says 'vynalezen' and 'vynalezení' still in use]
[[mrznout]] (nu) (mrzl ~ mrznul, mrznut, impf, vn mrznutí)
[[uváznout]] (nu) (uvázl ~ uváznul, no PPP, uváznuv, uváznutí)
[[říznout]] (nu) (řízl ~ říznul, říznut, říznuv, říznutí), same for [[vyříznout]], [[doříznout]], [[naříznout]], [[rozříznout]])

Per IJP, the past transgressive always ends in -nuv, and the endingless forms are totally obsolete.
(But not always it seems, see above.)

Variation:

Past: -l, -nul, -l ~ -nul: - nu (nu) [must be specified]
PPP: -nut, -en, -nut ~ -en, -en ~ -nut: t n t:n n:t [defaults to t]
past tgress: -nuv, null, -nuv ~ null, null ~ -nuv: nu - nu:- -:nu [defaults to nu]
vn: -nutí, -ení, -nutí ~ -ení, -ení ~ -nutí: defaults to same as PPP, or t if no PPP
]=]
parse["II.1"] = function(base, conjmod_run, parse_err)
	local function parse_err(msg)
		error(msg .. ": " .. table.concat(conjmod_run))
	end
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
	if saw_paren_nu then
		local expanded_past = {}
		for _, formobj in ipairs(base.past_stem) do
			if formobj.form == "(nu)" then
				table.insert(expanded_past, {form = "-", footnotes = formobj.footnotes})
				table.insert(expanded_past, {form = "nu", footnotes = formobj.footnotes})
			else
				table.insert(expanded_past, formobj)
			end
		end
	end
	for _, formobj in ipairs(base.past_stem) do
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
	add_past(base, base.past_stem, stem, base.ptr_stem)
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
* [[přát]], [[popřát]]: III.1.ě
* [[smát se]]: III.1.ě.vn:-
* [[usmát se]], [[nasmát se]]: III.1/n.ě
* [[vát]]: III.1/n:t[rare]
* [[navát]]: III.1/t

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
	for _, formobj in ipairs(base.ppp_stem) do
		local form = formobj.form
		if form == "" then
			form = lastv == "á" and "n" or "t"
		end
		formobj.form = past_stem .. form
	end

	add_present_e(base, stem .. "j", nil, "soft")
	add_present_e(base, {}, stem .. "j", false, {}, false, "[colloquial]")
	add_past(base, past_stem)
	add_ppp(base, base.ppp_stem)
end


--[=[
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
E.g.:

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
[[pohřbít]] (pohřbím, pohřbi, pohřbil, pohřben, pohřbiv, pohřbení)
[[mírnit]] (mírním, mírni, mírnil, mírněn, mírně, mírnění)
[[jezdit]] (jezdím, jezdi, jezdil, ježděn ~ jezděn, jezdě, ježdění ~ jezdění)
[[zpozdit]] (zpozdím, zpozdi, zpozdil, zpožděn, zpozdiv, zpoždění)
[[zaostřit]] (zaostřím, zaostři, zaostřil, zaostřen, zaostřiv, zaostření)
[[zvětšit]] (zvětším, zvětši, zvětšil, zvětšen, zvětšiv, zvětšení)
[[ctit]] (ctím, cti, ctil, ctěn, ctě, ctění)
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
[[půjčit]] (půjčím, půjč, půjčil, půjčen, půjčiv, půjčení)
[[trůnit]] (trůním, trůni, trůnil, no PPP, trůně, trůnění)
[[podnítit]] (podnítím, podniť ~ [rare] podněť, podnítil, podnícen, podnítiv, podnícení)
[[vštípit]] (vštípím, vštěp ~ vštip, vštípil, vštípen, vštípiv, vštípení)

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
* [[čistit]]: IV.1/short:long,iot:ni
* [[brzdit]]: IV.1/long:short,ni:iot
* [[spasit]]: IV.1/ni
* [[vozit]]: IV.1/iot:ni
* [[loudit]]: IV.1/long:short,ni

]=]

parse["IV.1"] = function(base, conjmod_run, parse_err)
	local separated_groups = iut.split_alternating_runs_and_strip_spaces(conjmod_run, ",")
	for _, separated_group in ipairs(separated_groups) do
		if rfind(separated_group[1], "^long") or rfind(separated_group[1], "^short") then
			-- Imperative specs
			if base.impspec then
				parse_err("Saw two sets of long/short imperative specs")
			end
			base.impspec = parse_variant_codes(separated_group, {"long", "short"}, "imperative type", parse_err)
		elseif rfind(separated_group[1], "^iot") or rfind(separated_group[1], "^ni") then
			-- PPP specs
			if base.pppspec then
				parse_err("Saw two sets of iotated/non-iotated past passive participle specs")
			end
			base.pppspec = parse_variant_codes(separated_group, {"iot", "ni"}, "past passive participle type",
				parse_err)
		else
			parse_err("Unrecognized indicator '" .. separated_group[1] .. "'")
		end
	end
end


conjs["IV.1"] = function(base, lemma)
	local stem = separate_stem_suffix(lemma, "^(.*)it$", "IV.1")

	stem = com.convert_paired_plain_to_palatal(stem)

	-- Normalize the codes computed by the parse function above. We don't need to do anything to the 'long'/'short'
	-- imperative codes because add_imperative_from_present() takes the codes directly.
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

	add_present_e(base, stem .. "j", nil, "soft")
	add_present_e(base, {}, stem .. "j", false, {}, false, "[colloquial]")
	add_past(base, past_stem)
	add_ppp(base, base.ppp_stem)
end

--[=[
[[dělat]] "to do"
[[konat]] "to act"
[[chovat]] "to behave"
[[doufat]] "to hope"
[[ptát se]] "to ask" (vn 'ptaní se')
[[dbát]] "to care" (vn 'dbání ~ dbaní')
[[zanedbat]] "to neglect"
[[znát]] "to know"
[[poznat]] "to know (pf.)"
[[poznávat]] "to know (secondary impf.)"
[[nechat]] "to let (pf)" (imperative 'nech ~ nechej')
[[nechávat]] "to let (impf)"
[[obědvat]] "to lunch"
[[odolat]] "to resist"/[[zdolat]]/[[udolat]]
[[plácat]] "to slap"
[[drncat]] "to rattle"
[[kecat]] "to chatter"
[[cucat]] "to suck"
]=]

conjs["V.1"] = function(base, lemma)
	local stem = separate_stem_suffix(lemma, "^(.*)[aá]t$", "V.1")
	add_present_a(base, stem)
	add_past(base, stem .. "a")
	add_ppp(base, stem .. "án")
end

--[=[

* Verbs in [sz]:
[[tesat]] "to carve" (impv 'tesej ~ teš', tr.ppp)
[[česat]] "to comb" ('češu' listed first in IJP, impv 'češ ~ česej', tr.ppp)
[[klusat]] "to trot" (impv only 'klusej' in IJP; intr)
[[křesat]] "to scrape" (impf 'křesej ~ křeš', tr.-ppp)
[[řezat]] "to cut" ('řežu' listed first in IJP, impv 'řež ~ řežej'; tr.ppp)
[[lízat]] "to lick" (impv 'lízej ~ líž', tr.-ppp)
[[hryzat]] "to bite" (also [[hrýzt]]; impv 'hryzej ~ hryž', tr.ppp)
[[hlásat]] "to proclaim" (V.1 in IJP; tr.ppp)
[[plesat]] "to dance" (V.1 in IJP; intr PPP?)
[[pásat se]] "to graze" (not in IJP; prefixed 'přepásat' etc. in IJP [V.2, tr.ppp; impv only 'přepásej' in IJP)
[[klouzat]] "to slide" (impv only 'klouzej' in IJP; intr PPP?)

* Verbs in [bpvfm]:
[[hýbat]] "to move" (impv 'hýbej'; intr no PPP)
[[dlabat]] "to gouge" (impv 'dlab ~ dlabej', PPP)
[[škrabat]] "to scratch" (impv 'škrabej ~ škrab', PPP)
[[klepat]] "to knock" (impv 'klep ~ klepej', PPP)
[[kopat]] "to kick" (impv 'kopej', PPP)
[[koupat]] "to bathe" (impv 'koupej', PPP)
[[sypat]] "to sprinkle" (impv 'syp ~ sypej', PPP)
[[drápat]] "to claw" (impv 'drápej', PPP)
[[dupat]] "to stomp" (impv 'dupej', PPP)
[[loupat]] "to peel" (impv 'loupej', PPP)
[[rýpat]] "to dig" (impv 'rýpej', PPP)
[[štípat]] "to pinch" (impv 'štípej', PPP)
[[šlapat]] "to step; to trample" (impv 'šlap ~ šlapej', PPP)
[[tápat]] "to grope" (impv 'tápej', intr no PPP)
[[dřímat]] "to doze" (impv 'dřímej', intr no PPP)
[[klamat]] "to deceive" (impv 'klamej ~ klam', PPP)
[[lámat]] "to break" (impv 'lam [note, short] ~ lámej', PPP)
[[plavat]] "to swim, to float" (pres only 'plavu, plaveš', impv 'plavej ~ plav ~ poplav', intr PPP? 'plaván', pres tgress 'plavaje')
[[klofat]] "to peck; to tap, to knock" (impv 'klofej', PPP)

* Verbs in [rln]:
[[orat]] "to plow" (impv 'orej ~ oř', PPP)
[[párat]] "to unstitch; to unravel" (impv 'párej', PPP)
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
]=]

conjs["V.2"] = function(base, lemma)
	local stem = separate_stem_suffix(lemma, "^(.*)at$", "V.2")
	local iotated_stem = com.iotate(stem)
	-- Types:
	-- * a = a-stem + e-stem, impv only a-stem = [[klusat]], [[přepásat]], [[klouzat]], [[hýbat]], [[škrabat]], [[kopat]], [[koupat]], [[drápat]], [[dupat]], [[loupat]], [[rýpat]], [[štípat]], [[tápat]], [[dřímat]], [[klamat]], [[klofat]], [[párat]], [[páchat]]
	-- * a' = e-stem + a-stem, impv only a-stem = [[týkat se]], [[kdákat]], [[kvákat]]
	-- * a'' = e-stem, impv only a-stem = [[stonat]]
	-- * b = a-stem + e-stem, impv e-stem + a-stem = [[dlabat]], [[klepat]], [[sypat]], [[šlapat]], [[lámat]] (short 'lam')
	-- * b' = e-stem + a-stem, impv e-stem + a-stem = [[česat]], [[řezat]]
	-- * b'' = e-stem, impv only e-stem + a-stem
	-- * c = a-stem + e-stem, impv a-stem + e-stem = [[tesat]], [[křesat]], [[lízej]], [[hryzat]], [[orat]], [[dudlat]]
	-- * c' = e-stem + a-stem, impv a-stem + e-stem
	-- * c'' = e-stem, impv only a-stem + e-stem = [[plavat]]
	local conjletter, conjprime = rmatch(base.conjmod, "^([abc])('*)$")
	if not conjletter then
		error("Internal error: Unable to match conjugation modifier '" .. base.conjmod .. "'")
	end
	local function add_a()
		add_present_a(base, stem, false)
	end
	local function add_a_imperative()
		add_present_a_imperative(base, stem)
	end
	local function add_e()
		add_present_e(base, iotated_stem, nil, false, "í", false)
	end
	local function add_e_imperative()
		add_imperative_from_present(base, iotated_stem)
	end
	if conjprime == "" then
		add_a()
		add_e()
	elseif conjprime == "'" then
		add_e()
		add_a()
	elseif conjprime == "''" then
		add_e()
	else
		error("Internal error: Unable to match conjugation prime modifier '" .. conjprime .. "'")
	end
	if conjletter == "a" then
		add_a_imperative()
	elseif conjletter == "b" then
		add_e_imperative()
		add_a_imperative()
	else
		add_a_imperative()
		add_e_imperative()
	end
	add_past(base, stem .. "a")
	add_ppp(base, stem .. "á")
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


local function parse_indicator_spec(angle_bracket_spec)
	local inside = rmatch(angle_bracket_spec, "^<(.*)>$")
	assert(inside)
	local base = {overrides = {}, forms = {}}
	local parts = rsplit(inside, ".", true)
	local conjarg = parts[1]
	local conj, past_accent = rmatch(conjarg, "^(.*)/(.*)$")
	if past_accent then
		if past_accent ~= "a" and past_accent ~= "b" then
			error("Unrecognized past-tense accent in conjugation spec '" .. conjarg .. "', should be 'a' or 'b': '" .. past_accent .. "'")
		end
		base.past_accent = past_accent
	else
		conj = conjarg
	end
	if conj == "irreg" then
		base.conjnum = "irreg"
	else
		conj, base.conj_star = rsubb(conj, "%*", "")
		base.conjnum, base.conjmod, base.accent = rmatch(conj, "^([0-9]+)([°()%[%]]*)([abc])$")
		if not base.conjnum then
			error("Invalid format for conjugation, should be e.g. '1a', '4b' or '6°c': '" .. conj .. "'")
		end
		if not conjs[base.conjnum] then
			error("Unrecognized conjugation: '" .. base.conjnum .. "'")
		end
	end
	base.conj = conj
	for i=2,#parts do
		local part = parts[i]
		if part == "impf" or part == "pf" or part == "both" then
			if base.aspect then
				error("Can't specify aspect twice: " .. angle_bracket_spec)
			end
			base.aspect = part
		elseif part == "tr" or part == "intr" or part == "mixed" then
			if base.trans then
				error("Can't specify transitivity twice: " .. angle_bracket_spec)
			end
			base.trans = part
		elseif part == "ppp" or part == "-ppp" then
			if base.ppp ~= nil then
				error("Can't specify past passive participle indicator twice: " .. angle_bracket_spec)
			end
			base.ppp = part == "ppp"
		elseif part == "retractedppp" or part == "-retractedppp" then
			if base.retractedppp ~= nil then
				error("Can't specify retracted past passive participle indicator twice: " .. angle_bracket_spec)
			end
			base.retractedppp = part == "retractedppp"
		elseif part == "impers" then
			if base.impers then
				error("Can't specify 'impers' twice: " .. angle_bracket_spec)
			end
			base.impers = true
		elseif part == "longimp" or part == "shortimp" then
			if base.imptype then
				error("Can't specify imperative type twice: " .. angle_bracket_spec)
			end
			base.imptype = rsub(part, "imp$", "")
		elseif part == "-imp" then
			if base.noimp then
				error("Can't specify '-imp' twice: " .. angle_bracket_spec)
			end
			base.noimp = true
		elseif part == "-pres" then
			if base.nopres then
				error("Can't specify '-pres' twice: " .. angle_bracket_spec)
			end
			base.nopres = true
		elseif part == "-past" then
			if base.nopast then
				error("Can't specify '-past' twice: " .. angle_bracket_spec)
			end
			base.nopast = true
		elseif part == "3only" then
			if base.only3 then
				error("Can't specify '3only' twice: " .. angle_bracket_spec)
			end
			base.only3 = true
		elseif part == "plonly" then
			if base.onlypl then
				error("Can't specify 'plonly' twice: " .. angle_bracket_spec)
			end
			base.onlypl = true
		elseif part == "3plonly" then
			if base.only3pl then
				error("Can't specify '3plonly' twice: " .. angle_bracket_spec)
			end
			base.only3pl = true
		elseif part == "3orplonly" then
			if base.only3orpl then
				error("Can't specify '3orplonly' twice: " .. angle_bracket_spec)
			end
			base.only3orpl = true
		elseif part == "с" or part == "д" or part == "т" or part == "ст" or part == "в" or part == "н" then
			if base.cons then
				error("Can't specify consonant modifier twice: " .. angle_bracket_spec)
			end
			base.cons = part
		elseif part == "і" or part == "-і" then -- Cyrillic і
			if base.i ~= nil then
				error("Can't specify і-modifier twice: " .. angle_bracket_spec)
			end
			base.i = part == "і" -- Latin i in base.i
		elseif part == "ї" then -- Cyrillic ї 
			if base.yi ~= nil then
				error("Can't specify 'ї' twice: " .. angle_bracket_spec)
			end
			base.yi = true
		elseif rfind(part, "^pres:") then
			part = rsub(part, "^pres:", "")
			base.pres_stems = rsplit(part, ":", true)
		else
			error("Unrecognized indicator '" .. part .. "': " .. angle_bracket_spec)
		end
	end
	return base
end


-- Separate out reflexive suffix, check that multisyllabic lemmas have stress, and add stress
-- to monosyllabic lemmas if needed.
local function normalize_lemma(base)
	base.orig_lemma = base.lemma
	base.lemma = com.add_monosyllabic_stress(base.lemma)
	if not rfind(base.lemma, AC) then
		error("Multisyllabic lemma '" .. base.orig_lemma .. "' needs an accent")
	end
	local active_verb, refl = rmatch(base.lemma, "^(.*)(с[яь])$")
	if active_verb then
		base.is_refl = true
		base.lemma = active_verb
	end
	if rfind(base.lemma, "ть$") then
		if refl == "сь" then
			error("Reflexive infinitive lemma in -тьсь not possible, use -тися, -тись or ться: '" .. base.orig_lemma)
		end
		base.lemma = rsub(base.lemma, "ть$", "ти")
	end
end


local function detect_indicator_and_form_spec(base)
	if not base.aspect then
		error("Aspect of 'pf', 'impf' or 'both' must be specified")
	end
	if base.is_refl then
		if base.trans then
			error("Can't specify transitivity with reflexive verb, they're always intransitive: '" .. base.orig_lemma .. "'")
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
	if base.ppp and base.retractedppp == nil then
		if base.conjnum == "14" or base.conjnum == "4" and base.accent == "b" then
			-- Does not retract normally, but can.
		else
			-- Will be ignored when add_retractable_ppp() isn't called.
			base.retractedppp = true
		end
	end
	if base.cons then
		if (base.conjnum == "3" or base.conjnum == "10") and rfind(base.cons, "^[тн]$") then
			-- ok
		elseif base.conjnum == "7" and (rfind(base.cons, "^[сдтв]$") or base.cons == "ст") then
			-- ok
		else
			error("Consonant modifier '" .. base.cons .. "' can't be specified with class " .. base.conjnum)
		end
	end
	if base.i ~= nil then
		if rfind(base.conjnum, "^[4578]$") then
			-- ok
		else
			error("і-modifier can't be specified with class " .. base.conjnum)
		end
	elseif base.yi then
		if base.conjnum ~= "4" then
			error("'ї' can only be specified with class 4")
		end
	elseif base.conjnum == "7" or base.conjnum == "8" then
		base.i = true
	end
	if base.conjnum == "3" then
		if base.conjmod ~= "" and base.conjmod ~= "°" and base.conjmod ~= "(°)" and base.conjmod ~= "[°]" then
			error("Unrecognized conjugation modifier for class 3: '" .. base.conjmod .. "'")
		end
	elseif base.conjnum == "6" then
		if base.conjmod ~= "" and base.conjmod ~= "°" then
			error("Unrecognized conjugation modifier for class 6: '" .. base.conjmod .. "'")
		end
	elseif base.conjmod and base.conjmod ~= "" then
		error("Conjugation modifiers only allowed for conjugations 3 and 6: '" .. base.conjmod .. "'")
	end
	if base.pres_stems and base.conjnum ~= "14" then
		base.irreg = true
	end
	if (base.accent == "a" or base.accent == "c") and base.pres_stems then
		for _, pres_stem in ipairs(base.pres_stems) do
			if not com.is_stressed(pres_stem) then
				error("Explicit present stem '" .. pres_stem .. "' must have an accent")
			end
		end
	end
	if not base.past_accent then
		if (base.conjnum == "7" or base.conjnum == "8") and base.accent == "b" then
			base.past_accent = "b"
		else
			base.past_accent = "a"
		end
	end
end


local function detect_all_indicator_and_form_specs(alternant_multiword_spec)
	for _, base in ipairs(alternant_multiword_spec.alternants) do
		detect_indicator_and_form_spec(base)
		if not alternant_multiword_spec.aspect then
			alternant_multiword_spec.aspect = base.aspect
		elseif alternant_multiword_spec.aspect ~= base.aspect then
			alternant_multiword_spec.aspect = "both"
		end
		if alternant_multiword_spec.is_refl == nil then
			alternant_multiword_spec.is_refl = base.is_refl
		elseif alternant_multiword_spec.is_refl ~= base.is_refl then
			error("With multiple alternants, all must agree on reflexivity")
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
	end
end


local function parse_word_spec(segments)
	if #segments ~= 3 or segments[3] ~= "" then
		error("Verb spec must be of the form 'LEMMA<CONJ.SPECS>': '" .. text .. "'")
	end
	local lemma = segments[1]
	local base = parse_indicator_and_form_spec(segments[2])
	base.lemma = lemma
	return base
end


-- Parse an alternant, e.g. "((ви́сіти<5a.impf.intr>,висі́ти<5b.impf.intr>))". The return value is a table of the form
-- {
--   alternants = {WORD_SPEC, WORD_SPEC, ...}
-- }
--
-- where WORD_SPEC describes a given alternant and is as returned by parse_word_spec().
local function parse_alternant(alternant)
	local parsed_alternants = {}
	local alternant_text = rmatch(alternant, "^%(%((.*)%)%)$")
	local segments = iut.parse_balanced_segment_run(alternant_text, "<", ">")
	local comma_separated_groups = iut.split_alternating_runs(segments, ",")
	local alternant_spec = {alternants = {}}
	for _, comma_separated_group in ipairs(comma_separated_groups) do
		table.insert(alternant_spec.alternants, parse_word_spec(comma_separated_group))
	end
	return alternant_spec
end


local function parse_alternant_or_word_spec(text)
	if rfind(text, "^%(%((.*)%)%)$") then
		return parse_alternant(text)
	else
		local segments = iut.parse_balanced_segment_run(text, "<", ">")
		return {alternants = {parse_word_spec(segments)}}
	end
end


local function add_infinitive(base)
	add(base, "infinitive", base.lemma, "")
	-- Alternative infinitive in -ть only exists for lemmas ending in unstressed -ти
	-- and preceded by a vowel. Not уме́рти, not нести́.
	if rfind(base.lemma, com.vowel_c .. AC .. "?ти$") then
		add(base, "infinitive", rsub(base.lemma, "ти$", "ть"), "")
	end
end


local function add_reflexive_suffix(alternant_multiword_spec)
	if not alternant_multiword_spec.is_refl then
		return
	end
	for slot, formvals in pairs(alternant_multiword_spec.forms) do
		alternant_multiword_spec.forms[slot] = iut.flatmap_forms(formvals, function(form)
			if rfind(slot, "adv_part$") then
				-- pp. 235-236 of Routledge's "Czech: A Comprehensive Grammar" say that
				-- -ся becomes -сь after adverbial participles. I take this to mean that
				-- the -ся form doesn't occur. FIXME: Verify this.
				return {form .. "сь"}
			elseif rfind(form, com.vowel_c .. AC .. "?[вй]?$") then
				return {form .. "ся", form .. "сь"}
			else
				return {form .. "ся"}
			end
		end)
	end
end


local function process_overrides(forms, args)
	for _, slot in ipairs(input_verb_slots) do
		if args[slot] then
			forms[slot] = nil
			if args[slot] ~= "-" and args[slot] ~= "—" then
				for _, form in ipairs(rsplit(args[slot], "%s*,%s*")) do
					iut.insert_form(forms, slot, {form=form})
				end
			end
		end
	end
end


-- Used for manual specification using {{cs-conj-manual}}.
local function augment_with_alt_infinitive(alternant_multiword_spec)
	local newinf = {}
	local forms = alternant_multiword_spec.forms
	if forms.infinitive then
		forms.infinitive = iut.flatmap_forms(forms.infinitive, function(inf)
			inf = com.add_monosyllabic_stress(inf)
			if rfind(inf, com.vowel_c .. AC .. "?ти$") then
				return {inf, rsub(inf, "ти$", "ть")}
			elseif rfind(inf, com.vowel_c .. AC .. "?тис[яь]$") then
				return {inf, rsub(inf, "тис[яь]$", "ться")}
			else
				return {inf}
			end
		end)
	end
end


-- Used for manual specification using {{cs-conj-manual}}.
local function set_reflexive_flag(alternant_multiword_spec)
	if alternant_multiword_spec.forms.infinitive then
		for _, inf in ipairs(alternant_multiword_spec.forms.infinitive) do
			if rfind(inf.form, "с[яь]$") then
				alternant_multiword_spec.is_refl = true
			end
		end
	end
end


local function set_present_future(alternant_multiword_spec)
	local forms = alternant_multiword_spec.forms
	if alternant_multiword_spec.aspect == "pf" then
		for suffix, _ in pairs(fut_suffixes) do
			forms["fut_" .. suffix] = forms["pres_fut_" .. suffix]
		end
	else
		for suffix, _ in pairs(fut_suffixes) do
			forms["pres_" .. suffix] = forms["pres_fut_" .. suffix]
		end
		-- Do the periphrastic future with búdu
		if forms.infinitive then
			for _, inf in ipairs(forms.infinitive) do
				for slot_suffix, _ in pairs(fut_suffixes) do
					local futslot = "fut_" .. slot_suffix
					if not skip_slot(alternant_multiword_spec, futslot) then
						iut.insert_form(forms, futslot, {
							form = "[[" .. budu_forms[slot_suffix] .. "]] [[" .. inf.form .. "]]",
							no_accel = true,
						})
					end
				end
			end
		end
	end
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
	if alternant_multiword_spec.alternants then -- not when manual
		for _, base in ipairs(alternant_multiword_spec.alternants) do
			if base.conj == "irreg" or base.irreg then
				insert("irregular")
			end
			if base.conj ~= "irreg" then
				insert("class " .. base.conj)
				insert("class " .. rsub(base.conj, "^([0-9]+).*", "%1"))
			end
		end
	end
	alternant_multiword_spec.categories = cats
end


local function show_forms(alternant_multiword_spec)
	local lemmas = {}
	if alternant_multiword_spec.forms.infinitive then
		for _, inf in ipairs(alternant_multiword_spec.forms.infinitive) do
			table.insert(lemmas, com.remove_monosyllabic_stress(inf.form))
		end
	end
	local props = {
		lemmas = lemmas,
		slot_table = output_verb_slots,
		lang = lang,
		-- Explicit additional top-level footnotes only occur with {{cs-conj-manual}}.
		footnotes = alternant_multiword_spec.footnotes,
		allow_footnote_symbols = not not alternant_multiword_spec.footnotes,
	}
	iut.show_forms(alternant_multiword_spec.forms, props)
end


local function make_table(alternant_multiword_spec)
	local forms = alternant_multiword_spec.forms

	local table_spec_part1 = [=[
<div class="NavFrame" style="width:120em">
<div class="NavHead" style="text-align:left; background:#e0e0ff;">{title}{annotation}</div>
<div class="NavContent">
{\op}| class="inflection-table inflection inflection-cs inflection-verb"
|-
! rowspan=3 colspan=2 style="background:#d9ebff" |
! colspan=3 style="background:#d9ebff" | [[singular]]
! colspan=4 style="background:#d9ebff" | [[plural]]
|-
! rowspan=2 style="background:#eff7ff;vertical-align:top;"| [[masculine]]
! rowspan=2 style="background:#eff7ff;vertical-align:top;"| [[feminine]]
! rowspan=2 style="background:#eff7ff;vertical-align:top;"| [[neuter]]
! colspan=2 style="background:#eff7ff"| [[masculine]]
! rowspan=2 style="background:#eff7ff;vertical-align:top;"| [[feminine]]
! rowspan=2 style="background:#eff7ff;vertical-align:top;"| [[neuter]]
|-
! style="background:#eff7ff"| [[animate]]
! style="background:#eff7ff"| [[inanimate]]
|-
! style="background:#d9ebff"| invariable
! style="background:#d9ebff"| [[infinitive]]
| colspan=7 | {infinitive}
|-
! colspan=4 style="background:#d9ebff"| number/gender<br/>only
! style="background:#d9ebff"| [[short]]&nsbp;[[passive]]&nbsp;[[participle]]
| {ppp_m}
| {ppp_f}
| {ppp_n}
| {ppp_mp_an}
| {ppp_mp_in}
| {ppp_fp}
| {ppp_np}
|-
! style="background:#d9ebff"| l-participle
| {lpart_m}
| {lpart_f}
| {lpart_n}
| {lpart_mp_an}
| {lpart_mp_in}
| {lpart_fp}
| {lpart_np}
|-
! style="background:#d9ebff"| [[present]]&nsbp;[[transgressive]]
| {pres_tgress_m}
| colspan=2|{pres_tgress_fn}
| colspan=4|{pres_tgress_p}
|-
! style="background:#d9ebff"| [[past]]&nsbp;[[transgressive]]
| {past_tgress_m}
| colspan=2|{past_tgress_fn}
| colspan=4|{past_tgress_p}
|-
! colspan=3 style="background:#d9ebff"| declined<br/>as<br/>adjective
! style="background:#d9ebff"| [[present]]&nsbp;[[active]]&nbsp;[[participle]]
| colspan=7 | {pres_act_part}
|-
! style="background:#d9ebff"| [[past]]&nsbp;[[active]]&nbsp;[[participle]]
| colspan=7 | {past_act_part}
|-
! style="background:#d9ebff"| [[long]]&nsbp;[[passive]]&nbsp;[[participle]]
| colspan=7 | {long_pass_part}
|-
! style="background:#d9ebff"| case/number<br/>only
! style="background:#d9ebff"| [[verbal noun|verbal&nsbp;noun]]
| colspan=7 | {vnoun}
]=]

	local table_spec_single_aspect_present = [=[
! style="background:#d9ebff" colspan=2 | [[present tense|present]]
| {pres_1s}
| {pres_2s}
| {pres_3s}
| {pres_1p}
| colspan=2 | {pres_2p}
| {pres_3p}
|-
! style="background:#d9ebff" colspan=2 | [[future tense|future]]
]=]

	local table_spec_biaspectual_present = [=[
! style="background:#d9ebff" colspan=2 | [[present tense|present]]&nbsp;(imperfective)
| rowspan=2 | {pres_1s}
| rowspan=2 | {pres_2s}
| rowspan=2 | {pres_3s}
| rowspan=2 | {pres_1p}
| colspan=2 rowspan=2 | {pres_2p}
| rowspan=2 | {pres_3p}
|-
! style="background:#d9ebff" colspan=2 | [[future tense|future]]&nbsp;(perfective)
|-
! style="background:#d9ebff" colspan=2 | [[future tense|future]]&nbsp;(imperfective)
]=]

	local table_spec_part2 = [=[
!style="background:#d9ebff" rowspan=3 colspan=2 | [[indicative]]
!style="background:#d9ebff" colspan=3 | [[singular]]
!style="background:#d9ebff" colspan=4 | [[plural]] (or polite)
|-
!style="background:#eff7ff" rowspan=2 | [[first person|first]]
!style="background:#eff7ff" rowspan=2 | [[second person|second]]
!style="background:#eff7ff" rowspan=2 | [[third person|third]]
!style="background:#eff7ff" rowspan=2 | [[first person|first]]
!style="background:#eff7ff" colspan=2 | [[second person|second]]
!style="background:#eff7ff" rowspan=2 | [[third person|third]]
|-
!style="background:#eff7ff" [[polite]] [[singular]]
!style="background:#eff7ff" [[plural]]
|-
{present_table}| {fut_1s}
| {fut_2s}
| {fut_3s}
| {fut_1p}
| colspan=2 | {fut_2p}
| {fut_3p}
|-
!style="background:#d9ebff" rowspan=4 | [[past tense|past]]
!style="background:#eff7ff"| [[masculine]]&nbsp;[[animate]]
| rowspan=2 | {past_1sm}
| rowspan=2 | {past_2sm}
| rowspan=2 | {past_3sm}
| rowspan=2 | {past_1pm}
| rowspan=2 | {past_2pm_polite}
| rowspan=2 | {past_2pm_plural}
| {past_3pm_an}
|-
!style="background:#eff7ff"| [[masculine]]&nbsp;[[inanimate]]
| {past_3pm_in}
|-
!style="background:#eff7ff"| [[feminine]]
| {past_1sf}
| {past_2sf}
| {past_3sf}
| {past_1pf}
| {past_2pf_polite}
| {past_2pf_plural}
| {past_3pf}
|-
!style="background:#eff7ff"| [[neuter]]
| {past_1sn}
| {past_2sn}
| {past_3sn}
| {past_1pn}
| {past_2pn_polite}
| {past_2pn_plural}
| {past_3pn}
|-
! style="background:#d9ebff" colspan=2 | [[imperative]]
| —
| {imp_2s}
| —
| {imp_1p}
| colspan=2 | {imp_2p}
| —
|{\cl}{notes_clause}</div></div>]=]

	local table_spec = table_spec_part1 ..
		(alternant_multiword_spec.aspect == "both" and table_spec_biaspectual or table_spec_single_aspect) ..
		table_spec_part2

	local notes_template = [===[
<div style="width:100%;text-align:left;background:#d9ebff">
<div style="display:inline-block;text-align:left;padding-left:1em;padding-right:1em">
{footnote}
</div></div>
]===]

	if alternant_multiword_spec.title then
		forms.title = alternant_multiword_spec.title
	else
		forms.title = 'Conjugation of <i lang="cs">' .. forms.lemma .. '</i>'
	end
	if forms.past_pasv_part_impers == "—" then
		forms.past_pasv_part_impers = ""
	else
		forms.past_pasv_part_impers = "<br />impersonal: " .. forms.past_pasv_part_impers
	end

	if alternant_multiword_spec.manual then
		forms.annotation = ""
	else
		local ann_parts = {}
		local saw_irreg_conj = false
		local saw_base_irreg = false
		local all_irreg_conj = true
		local conjs = {}
		for _, base in ipairs(alternant_multiword_spec.alternants) do
			m_table.insertIfNot(conjs, base.conj)
			if base.conj == "irreg" then
				saw_irreg_conj = true
			else
				all_irreg_conj = false
			end
			if base.irreg then
				saw_base_irreg = true
			end
		end
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
	end

	-- pronouns used in the table
	forms.ya = tag_text("я")
	forms.ty = tag_text("ти")
	forms.vin_vona_vono = tag_text("він / вона / воно")
	forms.my = tag_text("ми")
	forms.vy = tag_text("ви")
	forms.vony = tag_text("вони")
	forms.my_vy_vony = tag_text("ми / ви / вони")
	forms.ya_ty_vin = tag_text("я / ти / він")
	forms.ya_ty_vona = tag_text("я / ти / вона")
	forms.vono = tag_text("воно")

	if alternant_multiword_spec.aspect == "pf" then
		forms.aspect_indicator = "[[perfective aspect]]"
	elseif alternant_multiword_spec.aspect == "impf" then
		forms.aspect_indicator = "[[imperfective aspect]]"
	else
		forms.aspect_indicator = "[[biaspectual]]"
	end

	forms.notes_clause = forms.footnote ~= "" and
		m_string_utilities.format(notes_template, forms) or ""
	return m_string_utilities.format(table_spec, forms)
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
	local parse_props = {
		parse_indicator_spec = parse_indicator_spec,
		angle_brackets_omittable = true,
		allow_blank_lemma = true,
	}
	local alternant_multiword_spec = iut.parse_inflected_text(args[1], parse_props)
	alternant_multiword_spec.title = args.title
	alternant_multiword_spec.args = args
	local pagename = args.pagename or mw.title.getCurrentTitle().subpageText
	alternant_multiword_spec.forms = {}
	normalize_all_lemmas(alternant_multiword_spec, pagename)
	detect_all_indicator_and_form_specs(alternant_multiword_spec)
	for _, base in ipairs(alternant_multiword_spec.alternants) do
		add_infinitive(base)
		conjs[base.conjnum](base, base.lemma, base.accent)
	end
	add_reflexive_suffix(alternant_multiword_spec)
	process_overrides(alternant_multiword_spec.forms, args)
	set_present_future(alternant_multiword_spec)
	add_categories(alternant_multiword_spec)
	return alternant_multiword_spec
end


-- Externally callable function to parse and conjugate a verb where all forms are given manually. Return value is
-- ALTERNANT_MULTIWORD_SPEC, an object where the conjugated forms are in `ALTERNANT_MULTIWORD_SPEC.forms` for each
-- slot. If there are no values for a slot, the slot key will be missing. The value for a given slot is a list of
-- objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms_manual(parent_args, pos, from_headword, def)
	local params = {
		footnote = {list = true},
		title = {},
		aspect = {required = true, default = "impf"},
	}
	for _, slot in ipairs(input_verb_slots) do
		params[slot] = {}
	end

	local args = m_para.process(parent_args, params)
	if args.aspect ~= "pf" and args.aspect ~= "impf" and args.aspect ~= "both" then
		error("Aspect '" .. args.aspect .. "' must be 'pf', 'impf' or 'both'")
	end
	local alternant_multiword_spec = {
		aspect = args.aspect,
		title = args.title,
		footnotes = args.footnote,
		forms = {},
		manual = true,
	}
	process_overrides(alternant_multiword_spec.forms, args)
	augment_with_alt_infinitive(alternant_multiword_spec)
	set_reflexive_flag(alternant_multiword_spec)
	set_present_future(alternant_multiword_spec)
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


-- Entry point for {{cs-conj-manual}}. Template-callable function to parse and conjugate a verb given
-- manually-specified inflections and generate a displayable table of the conjugated forms.
function export.show_manual(frame)
	local parent_args = frame:getParent().args
	local alternant_multiword_spec = export.do_generate_forms_manual(parent_args)
	show_forms(alternant_multiword_spec)
	return make_table(alternant_multiword_spec) .. require("Module:utilities").format_categories(alternant_multiword_spec.categories, lang)
end


-- Concatenate all forms of all slots into a single string of the form
-- "SLOT=FORM,FORM,...|SLOT=FORM,FORM,...|...". Embedded pipe symbols (as might occur
-- in embedded links) are converted to <!>. If INCLUDE_PROPS is given, also include
-- additional properties (currently, only "|aspect=ASPECT"). This is for use by bots.
local function concat_forms(alternant_multiword_spec, include_props)
	local ins_text = {}
	for slot, _ in pairs(output_verb_slots) do
		local formtext = com.concat_forms_in_slot(alternant_multiword_spec.forms[slot])
		if formtext then
			table.insert(ins_text, slot .. "=" .. formtext)
		end
	end
	if include_props then
		table.insert(ins_text, "aspect=" .. alternant_multiword_spec.aspect)
	end
	return table.concat(ins_text, "|")
end

-- Template-callable function to parse and conjugate a verb given user-specified arguments and return
-- the forms as a string "SLOT=FORM,FORM,...|SLOT=FORM,FORM,...|...". Embedded pipe symbols (as might
-- occur in embedded links) are converted to <!>. If |include_props=1 is given, also include
-- additional properties (currently, only "|aspect=ASPECT"). This is for use by bots.
function export.generate_forms(frame)
	local include_props = frame.args["include_props"]
	local parent_args = frame:getParent().args
	local alternant_multiword_spec = export.do_generate_forms(parent_args)
	return concat_forms(alternant_multiword_spec, include_props)
end


return export
