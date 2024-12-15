local export = {}


--[=[

Authorship: Ben Wing <benwing2>

]=]

--[=[

TERMINOLOGY:

-- "slot" = A particular combination of tense/mood/person/number/gender/etc.
	 Example slot names for verbs are "pres_1sg" (present first singular) and
	 "past_pasv_part_impers" (impersonal past passive participle).
	 Each slot is filled with zero or more forms.

-- "form" = The conjugated Ukrainian form representing the value of a given slot.

-- "lemma" = The dictionary form of a given Ukrainian term. Generally the infinitive,
	 but may occasionally be another form if the infinitive is missing.
]=]

local lang = require("Module:languages").getByCode("uk")
local m_table = require("Module:table")
local m_string_utilities = require("Module:string utilities")
local m_script_utilities = require("Module:script utilities")
local iut = require("Module:inflection utilities")
local m_para = require("Module:parameters")
local com = require("Module:uk-common")

local current_title = mw.title.getCurrentTitle()
local NAMESPACE = current_title.nsText
local PAGENAME = current_title.text

local u = require("Module:string/char")
local rsplit = mw.text.split
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rgmatch = mw.ustring.gmatch
local rsubn = mw.ustring.gsub
local ulen = mw.ustring.len
local uupper = mw.ustring.upper

local AC = u(0x0301) -- acute =  ́


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
	["pres_actv_part"] = "pres|act|part",
	["past_actv_part"] = "past|act|part",
	["past_pasv_part"] = "past|pass|part",
	["pres_adv_part"] = "pres|adv|part",
	["past_pasv_part_impers"] = "impers|past|pass|part",
	["past_adv_part"] = "past|adv|part",
	["pres_1sg"] = "1|s|pres|ind",
	["pres_2sg"] = "2|s|pres|ind",
	["pres_3sg"] = "3|s|pres|ind",
	["pres_1pl"] = "1|p|pres|ind",
	["pres_2pl"] = "2|p|pres|ind",
	["pres_3pl"] = "3|p|pres|ind",
	["futr_1sg"] = "1|s|fut|ind",
	["futr_2sg"] = "2|s|fut|ind",
	["futr_3sg"] = "3|s|fut|ind",
	["futr_1pl"] = "1|p|fut|ind",
	["futr_2pl"] = "2|p|fut|ind",
	["futr_3pl"] = "3|p|fut|ind",
	["impr_2sg"] = "2|s|imp",
	["impr_1pl"] = "1|p|imp",
	["impr_2pl"] = "2|p|imp",
	["past_m"] = "m|s|past|ind",
	["past_f"] = "f|s|past|ind",
	["past_n"] = "n|s|past|ind",
	["past_pl"] = "p|past|ind",
}


local input_verb_slots = {}
for slot, _ in pairs(output_verb_slots) do
	if rfind(slot, "^pres_[123]") then
		table.insert(input_verb_slots, rsub(slot, "^pres_", "pres_futr_"))
	elseif not rfind(slot, "^futr_") then
		table.insert(input_verb_slots, slot)
	end
end


local futr_suffixes = {
	["1sg"] = "му",
	["2sg"] = "меш",
	["3sg"] = "ме",
	["1pl"] = {"мемо", "мем"},
	["2pl"] = "мете",
	["3pl"] = "муть",
}


local futr_refl_suffixes = {
	["1sg"] = {"мусь", "муся"},
	["2sg"] = "мешся",
	["3sg"] = "меться",
	["1pl"] = {"мемось", "мемося", "мемся"},
	["2pl"] = {"метесь", "метеся"},
	["3pl"] = "муться",
}


local budu_forms = {
	["1sg"] = "бу́ду",
	["2sg"] = "бу́деш",
	["3sg"] = "бу́де",
	["1pl"] = "бу́демо",
	["2pl"] = "бу́дете",
	["3pl"] = "бу́дуть",
}


local function stress_ending(ending)
	if type(ending) == "string" then
		return com.maybe_stress_final_syllable(ending)
	else
		for i, e in ipairs(ending) do
			ending[i] = com.maybe_stress_final_syllable(e)
		end
		return ending
	end
end


local function skip_slot(base, slot)
	if slot == "infinitive" then
		return false
	end
	if base.nopres and (rfind(slot, "pres") or rfind(slot, "futr")) then
		return true
	end
	if base.nopast and rfind(slot, "past") then
		return true
	end
	if base.noimp and rfind(slot, "impr") then
		return true
	end
	if base.impers then
		if rfind(slot, "3sg") or rfind(slot, "adv_part") or slot == "past_pasv_part_impers" or slot == "past_n" then
			return false
		else
			return true
		end
	end
	if (base.only3 or base.only3pl) and rfind(slot, "[12]") then
		return true
	end
	if (base.onlypl or base.only3pl) and (rfind(slot, "sg") or rfind(slot, "^past_[mfn]$")) then
		return true
	end
	if base.only3orpl and rfind(slot, "[12]sg") then
		return true
	end
	return false
end


local function add(base, slot, stems, endings)
	if skip_slot(base, slot) then
		return
	end
	iut.add_forms(base.forms, slot, stems, endings, com.combine_stem_ending)
end


local function add_imperative(base, sg2, footnote)
	local sg2form = com.generate_form(sg2, footnote)
	add(base, "impr_2sg", sg2form, "")
	-- "Long" imperatives end in -и or occasionally -ї (e.g. труї́ from труї́ти, ви́труї from ви́труїти)
	local stem, vowel, ac = rmatch(sg2, "^(.-)([иї])(" .. AC .. "?)$")
	if stem then
		local acvowel = (vowel == "и" and "і" or "ї") .. ac
		local stemform = com.generate_form(stem, footnote)
		add(base, "impr_1pl", stemform, {acvowel .. "м", acvowel .. "мо"})
		add(base, "impr_2pl", stemform, {acvowel .. "ть"})
	elseif com.ends_in_vowel(sg2) then
		error("Invalid 2sg imperative, ends in vowel other than -и or -ї: '" .. sg2 .. "'")
	else
		add(base, "impr_1pl", sg2form, "мо")
		add(base, "impr_2pl", sg2form, "те")
	end
end


local function add_imperative_from_present(base, presstem, accent)
	local imptype = base.imptype
	if not imptype then
		if accent == "b" or accent == "c" then
			imptype = "long"
		elseif rfind(presstem, "^ви́") then
			imptype = "long"
		elseif rfind(presstem, com.cons_c .. "[лрмн]$") then
			imptype = "long"
		else
			imptype = "short"
		end
	end
	local sg2
	if com.ends_in_vowel(presstem) then
		-- If the stem ends in a vowel, then regardless of imptype, stress the final
		-- syllable if needed and add й, effectively using the short type.
		sg2 = com.maybe_stress_final_syllable(presstem) .. "й"
	elseif imptype == "long" then
		if accent == "a" then
			sg2 = presstem .. "и"
		else
			sg2 = com.remove_stress(presstem) .. "и́"
		end
	elseif rfind(presstem, "[дтсзлн]$") then
		sg2 = com.maybe_stress_final_syllable(presstem) .. "ь"
	else
		sg2 = com.maybe_stress_final_syllable(presstem)
	end
	add_imperative(base, sg2)
end


local function add_pres_futr(base, stem, sg1, sg2, sg3, pl1, pl2, pl3)
	add(base, "pres_futr_1sg", stem, sg1)
	add(base, "pres_futr_2sg", stem, sg2)
	add(base, "pres_futr_3sg", stem, sg3)
	add(base, "pres_futr_1pl", stem, pl1)
	add(base, "pres_futr_2pl", stem, pl2)
	add(base, "pres_futr_3pl", stem, pl3)
	-- Do the present adverbial participle, which is based on the third plural present.
	-- FIXME: Do impersonal verbs have this participle?
	if base.aspect ~= "pf" and type(pl3) == "string" then
		local pl3base = rmatch(pl3, "^(.-)ть$")
		if not pl3base then
			error("Invalid third-plural ending, doesn't end in -ть: '" .. pl3 .. "'")
		end
		local ending = "чи"
		if com.is_stressed(pl3base) then
			pl3base = com.remove_stress(pl3base)
			ending = "чи́"
		end
		add(base, "pres_adv_part", stem, pl3base .. ending)
	end
end


local function stress_present_endings_per_accent(endings, accent)
	if accent == "b" then
		for i, ending in ipairs(endings) do
			endings[i] = stress_ending(ending)
		end
	elseif accent == "c" then
		endings[1] = stress_ending(endings[1])
	end
	return endings
end


local function add_present_e(base, stem, accent, use_y_endings, overriding_imp, no_override_stem)
	if not no_override_stem then
		stem = base.pres_stems or stem
	end
	if type(stem) == "table" then
		for _, st in ipairs(stem) do
			add_present_e(base, st, accent, use_y_endings, overriding_imp, true)
		end
		return
	end
	local endings
	if use_y_endings == "all" or com.ends_in_vowel(stem) then
		endings = {"ю", "єш", base.is_refl and "єть" or "є", {"єм", "ємо"}, "єте", "ють"}
	elseif use_y_endings == "1sg3pl" and not rfind(stem, com.hushing_c .. "$") then
		endings = {"ю", "еш", base.is_refl and "еть" or "е", {"ем", "емо"}, "ете", "ють"}
	else
		endings = {"у", "еш", base.is_refl and "еть" or "е", {"ем", "емо"}, "ете", "уть"}
	end
	endings = stress_present_endings_per_accent(endings, accent)
	add_pres_futr(base, stem, unpack(endings))
	if overriding_imp == false then
		-- do nothing
	elseif overriding_imp then
		add_imperative(base, overriding_imp)
	else
		add_imperative_from_present(base, stem, accent)
	end
end


local function add_present_i(base, stem, accent, overriding_imp, no_override_stem)
	if not no_override_stem then
		stem = base.pres_stems or stem
	end
	if type(stem) == "table" then
		for _, st in ipairs(stems) do
			add_present_i(base, st, accent, overriding_imp, true)
		end
		return
	end
	local endings
	local iotated_type, iotated_stem
	if com.ends_in_vowel(stem) then
		endings = {"ю", "їш", "їть", {"їм", "їмо"}, "їте", "ять"}
		iotated_type = "none"
	else
		iotated_stem = com.iotate(stem)
		endings = {rfind(iotated_stem, com.hushing_c .. "$") and "у" or "ю", "иш", "ить",
			{"им", "имо"}, "ите", rfind(stem, com.hushing_c .. "$") and "ать" or "ять"}
		if stem == iotated_stem then
			iotated_type = "none"
		elseif rfind(iotated_stem, "л$") then
			iotated_type = "1sg3pl"
		else
			iotated_type = "1sg"
		end
	end
	endings = stress_present_endings_per_accent(endings, accent)
	local s1, s2, s3, p1, p2, p3 = unpack(endings)
	if iotated_type == "none" then
		add_pres_futr(base, stem, s1, s2, s3, p1, p2, p3)
	elseif iotated_type == "1sg" then
		add_pres_futr(base, iotated_stem, s1, {}, {}, {}, {}, {})
		add_pres_futr(base, stem, {}, s2, s3, p1, p2, p3)
	else
		add_pres_futr(base, iotated_stem, s1, {}, {}, {}, {}, p3)
		add_pres_futr(base, stem, {}, s2, s3, p1, p2, {})
	end
	if overriding_imp == false then
		-- do nothing
	elseif overriding_imp then
		add_imperative(base, overriding_imp)
	else
		add_imperative_from_present(base, stem, accent)
	end
end


local function add_past(base, msgstem, reststem)
	add(base, "past_m", msgstem, "")
	add(base, "past_f", reststem, base.past_accent == "b" and "а́" or "а")
	add(base, "past_n", reststem, base.past_accent == "b" and "о́" or "о")
	add(base, "past_pl", reststem, base.past_accent == "b" and "и́" or "и")
	add(base, "past_adv_part", msgstem, "ши")
end


local function add_default_past(base, stem)
	add_past(base, stem .. "в", stem .. "л")
end


local function add_ppp(base, stem)
	if base.is_refl or not base.ppp or base.trans == "intr" then
		return
	end
	if not base.impers then
		add(base, "past_pasv_part", stem, "ий")
	end
	add(base, "past_pasv_part_impers", stem, "о")
end


local function add_retractable_ppp(base, stem)
	if base.retractedppp then
		local stembase, last_syl = rmatch(stem, "^(.-)(" .. com.vowel_c .. AC .. "?[нт])$")
		if not stembase then
			error("Internal error: Unrecognized stem for past passive participle: '" .. stem .. "'")
		end
		if com.is_stressed(last_syl) and not com.is_nonsyllabic(stembase) then
			stembase = com.maybe_stress_final_syllable(stembase)
			last_syl = com.remove_stress(last_syl)
			stem = stembase .. last_syl
		end
	end
	add_ppp(base, stem)
end


local function check_stress_for_accent_type(lemma, class, accent, ac)
	if (accent == "b" or accent == "c") and ac ~= AC then
		error("For class " .. class .. "b or " .. class .. "c, lemma must be end-stressed: '" .. lemma .. "'")
	end
	if accent == "a" and ac == AC then
		error("For class " .. class .. "a, lemma must be stem-stressed: '" .. lemma .. "'")
	end
end


local function separate_stem_suffix_accent(lemma, class, accent, regex)
	local stem, suffix, ac = rmatch(lemma, regex)
	if not stem then
		error("Unrecognized lemma for class " .. class .. ": '" .. lemma .. "'")
	end
	check_stress_for_accent_type(lemma, class, accent, ac)
	return stem, suffix, ac
end


local conjs = {}


conjs["1"] = function(base, lemma, accent)
	local stem = rmatch(lemma, "^(.*[аяі]́?)ти$")
	if not stem then
		error("Unrecognized lemma for class 1: '" .. lemma .. "'")
	end
	if accent ~= "a" then
		error("Only accent a allowed for class 1: '" .. base.conj .. "'")
	end
	add_present_e(base, stem, "a")
	add_default_past(base, stem)
	add_retractable_ppp(base, stem .. "н")
end


conjs["2"] = function(base, lemma, accent)
	local stem, suffix = rmatch(lemma, "^(.*[ую]́?)(ва́?)ти$")
	if not stem then
		error("Unrecognized lemma for class 2: '" .. lemma .. "'")
	end
	if accent ~= "a" and accent ~= "b" then
		error("Only accent a or b allowed for class 2: '" .. base.conj .. "'")
	end
	if accent == "b" and suffix ~= "ва́" then
		error("For class 2b, lemma must be end-stressed: '" .. lemma .. "'")
	end
	local stressed_stem = com.maybe_stress_final_syllable(stem)
	add_present_e(base, accent == "a" and stressed_stem or stem, accent)
	add_default_past(base, stem .. suffix)
	if com.is_stressed(suffix) then
		local pppstem = rsub(stem, "^(.*)([ую])$",
			function(a, b) return a .. (
				b == "у" and "о́" or com.ends_in_vowel(a) and "йо́" or "ьо́"
			) end)
		add_ppp(base, pppstem .. "ван")
	else
		add_ppp(base, stem .. "ван")
	end
end


conjs["3"] = function(base, lemma, accent)
	local stem, suffix, ac = rmatch(lemma, "^(.*)(ну)(́?)ти$")
	if not stem then
		stem, ac = rmatch(lemma, "^(.*г)ти(́?)$")
		if not stem then
			error("Unrecognized lemma for class 3: '" .. lemma .. "'")
		end
	end
	check_stress_for_accent_type(lemma, "3", accent, ac)
	local stressed_stem = com.maybe_stress_final_syllable(stem)
	add_present_e(base, stressed_stem .. "н", accent)
	local long_stem = stem .. "ну" .. ac
	if base.conjmod == "" then
		add_default_past(base, long_stem)
	elseif base.conjmod == "°" then
		add_past(base, stressed_stem, stressed_stem .. "л")
	elseif base.conjmod == "(°)" then
		add_past(base, long_stem .. "в", stressed_stem .. "л")
		add_past(base, stressed_stem, long_stem .. "л", "a")
	elseif base.conjmod == "[°]" then
		add_past(base, stressed_stem, stressed_stem .. "л")
		add_default_past(base, long_stem)
	else
		error("Internal error: Unrecognized conjugation modifier: '" .. base.conjmod .. "'")
	end
	-- May need to stress final syllable in case of nonsyllabic stem, e.g. for гну́ти.
	local n_ppp = com.maybe_stress_final_syllable(stressed_stem .. "нен")
	local t_ppp = com.maybe_stress_final_syllable(stressed_stem .. "нут")
	if base.cons == "н" then
		add_ppp(base, n_ppp)
	elseif base.cons == "т" then
		add_ppp(base, t_ppp)
	else
		add_ppp(base, n_ppp)
		add_ppp(base, t_ppp)
	end
end


conjs["4"] = function(base, lemma, accent)
	local stem, suffix, ac = separate_stem_suffix_accent(lemma, "4", accent, "^(.*)([иї])(́?)ти$")
	local stem_ends_in_vowel = com.ends_in_vowel(stem)
	if suffix == "ї" and not stem_ends_in_vowel then
		error("Ending -їти can only be used with a vocalic stem: '" .. lemma .. "'")
	elseif suffix ~= "ї" and stem_ends_in_vowel then
		error("Ending -їти must be used with a vocalic stem: '" .. lemma .. "'")
	end
	local stressed_stem = com.maybe_stress_final_syllable(stem)
	local sg2
	if base.i then
		if not rfind(stem, "о́?$") then
			error("і-modifier can only be used with stem ending in -о: '" .. lemma .. "'")
		end
		sg2 = com.maybe_stress_final_syllable(rsub(stem, "о(́?)$", "і%1й"))
	elseif base.yi then
		if suffix ~= "ї" then
			error("'ї' can only be used with stem ending in -ї: '" .. lemma .. "'")
		end
		if accent == "a" then -- ви́труїти, impv ви́труї; default would be ви́труй
			sg2 = stem .. "ї"
		else
			sg2 = stem .. "ї́" -- труї́ти, impv труї́; default would be тру́й
		end
		-- NOTE: строїти has three different meanings with three different imperatives:
		-- (1) стро́їти "to align, adjust, arrange": impv строй
		-- (2) стро́їти "to connect in three": impv стрій
		-- (3) строї́ти "to flow": impv строї́
	end
	add_present_i(base, stressed_stem, accent, sg2)
	add_default_past(base, stem .. suffix .. ac)
	if accent == "a" then
		add_ppp(base, com.iotate(stressed_stem) .. (stem_ends_in_vowel and "єн" or "ен"))
	else
		-- By default, stress will retract one syllable if accent is c but not b,
		-- but this can be overridden in both directions using 'retractedppp' (for b)
		-- or '-retractedppp' (for c).
		add_retractable_ppp(base, com.remove_stress(com.iotate(stem)) .. (stem_ends_in_vowel and "є́н" or "е́н"))
	end
end


conjs["5"] = function(base, lemma, accent)
	local stem, suffix, ac = separate_stem_suffix_accent(lemma, "5", accent, "^(.*)([іая])(́?)ти$")
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
	add_present_i(base, stressed_stem, accent, sg2)
	add_default_past(base, stem .. suffix .. ac)
	add_retractable_ppp(base, (suffix == "і" and com.iotate(stem) .. "е" or stem .. suffix) .. ac .. "н")
end


conjs["6"] = function(base, lemma, accent)
	-- хоті́ти is anomalous in that it's 6a.
	local stem, suffix, ac = rmatch(lemma, "^(.*хот)(і)(́)ти$")
	if stem and accent == "a" then
		base.irreg = true
	else
		stem, suffix, ac = separate_stem_suffix_accent(lemma, "6", accent, "^(.*)([іая])(́?)ти$")
	end
	local stem_ends_in_vowel = com.ends_in_vowel(stem)
	if suffix == "я" and not stem_ends_in_vowel then
		error("Ending -яти can only be used with a vocalic stem: '" .. lemma .. "'")
	elseif suffix ~= "я" and stem_ends_in_vowel then
		error("Ending -яти must be used with a vocalic stem: '" .. lemma .. "'")
	end
	local stressed_stem = com.maybe_stress_final_syllable(stem)
	if base.conjmod == "" then
		stressed_stem = com.iotate(stressed_stem)
	end
	local sg2
	if rfind(lemma, "си́?пати$") then
		sg2 = stem
		base.irreg = true
	end
	add_present_e(base, stressed_stem, accent,
		base.conjmod == "" and not stem_ends_in_vowel and "1sg3pl", sg2)
	add_default_past(base, stem .. suffix .. ac)
	add_retractable_ppp(base, stem .. (suffix == "і" and "е" or suffix) .. ac .. "н")
end


conjs["7"] = function(base, lemma, accent)
	local stem, last_cons = rmatch(lemma, "^(.*)(" .. com.cons_c .. ")ти́?$")
	if not stem then
		error("Unrecognized lemma for class 7: '" .. lemma .. "'")
	end
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
	add_present_e(base, stressed_stem .. last_cons, accent)
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


conjs["8"] = function(base, lemma, accent)
	local stem, last_cons = rmatch(lemma, "^(.*)([кг])ти́?$")
	if not stem then
		error("Unrecognized lemma for class 8: '" .. lemma .. "'")
	end
	local palatalized_cons = com.iotate(last_cons)
	local stressed_stem = com.maybe_stress_final_syllable(stem)
	add_present_e(base, stressed_stem .. palatalized_cons, accent)
	local past_msg = stressed_stem .. last_cons
	local past_rest = past_msg .. "л"
	if base.i then
		past_msg = rsub(past_msg, "[еоя](́?" .. com.cons_c .. "+)$", "і%1")
	end
	add_past(base, past_msg, past_rest)
	add_ppp(base, stressed_stem .. palatalized_cons .. "ен")
end


conjs["9"] = function(base, lemma, accent)
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
	add_present_e(base, pres_stem .. "р", accent)
	local stressed_stem = com.maybe_stress_final_syllable(stem .. suffix)
	add_past(base, stressed_stem, stressed_stem .. "л")
	add_ppp(base, stressed_stem .. "т")
end


conjs["10"] = function(base, lemma, accent)
	local stem, suffix, ac = separate_stem_suffix_accent(lemma, "10", accent, "^(.*)(о[лр]о)(́?)ти$")
	if accent ~= "a" and accent ~= "c" then
		error("Only accent a or c allowed for class 10: '" .. base.conj .. "'")
	end
	local stressed_stem = com.maybe_stress_final_syllable(rsub(stem .. suffix, "о$", ""))
	add_present_e(base, stressed_stem, accent, "1sg3pl")
	add_default_past(base, stem .. suffix .. ac)
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


conjs["11"] = function(base, lemma, accent)
	local stem, suffix, ac = separate_stem_suffix_accent(lemma, "11", accent, "^(.*)(и)(́?)ти$")
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
	add_present_e(base, pres_stem, accent, "all", full_stem .. "й")
	add_default_past(base, full_stem)
	add_ppp(base, full_stem .. "т")
end


conjs["12"] = function(base, lemma, accent)
	local stem = rmatch(lemma, "^(.*" .. com.vowel_c .. AC .. "?)ти$")
	if not stem then
		error("Unrecognized lemma for class 12: '" .. lemma .. "'")
	end
	if accent ~= "a" and accent ~= "b" then
		error("Only accent a or b allowed for class 12: '" .. base.conj .. "'")
	end
	add_present_e(base, stem, accent)
	add_default_past(base, stem)
	add_ppp(base, stem .. "т")
end


conjs["13"] = function(base, lemma, accent)
	local stem = rmatch(lemma, "^(.*а)ва́ти$")
	if not stem then
		error("Unrecognized lemma for class 13: '" .. lemma .. "'")
	end
	if accent ~= "b" then
		error("Only accent b allowed for class 13: '" .. base.conj .. "'")
	end
	local full_stem = stem .. "ва́"
	add_present_e(base, stem, accent, nil, full_stem .. "й")
	add_default_past(base, full_stem)
	add_retractable_ppp(base, full_stem .. "н")
end


conjs["14"] = function(base, lemma, accent)
	-- -сти occurs in п'я́сти́ and роз(і)п'я́сти́
	local stem = rmatch(lemma, "^(.*[ая]́?)с?ти́?$")
	if not stem then
		error("Unrecognized lemma for class 14: '" .. lemma .. "'")
	end
	if not base.pres_stems then
		error("With class 14, must specify explicit present stem using 'pres:STEM'")
	end
	add_present_e(base, "foo", accent)
	local stressed_stem = com.maybe_stress_final_syllable(stem)
	add_default_past(base, stressed_stem)
	add_retractable_ppp(base, stressed_stem .. "т")
end


conjs["15"] = function(base, lemma, accent)
	local stem = rmatch(lemma, "^(.*" .. com.vowel_c .. AC .. "?)ти$")
	if not stem then
		error("Unrecognized lemma for class 15: '" .. lemma .. "'")
	end
	if accent ~= "a" then
		error("Only accent a allowed for class 15: '" .. base.conj .. "'")
	end
	add_present_e(base, stem .. "н", accent)
	add_default_past(base, stem)
	add_ppp(base, stem .. "т")
end


conjs["irreg"] = function(base, lemma, accent)
	local prefix = rmatch(lemma, "^(.*)да́?ти$")
	if prefix then
		local stressed_prefix = com.is_stressed(prefix)
		if stressed_prefix then
			add_pres_futr(base, prefix, "дам", "даси", "дасть", "дамо", "дасте", "дадуть")
			add_imperative(base, prefix .. "дай")
			add_default_past(base, prefix .. "да")
			add_retractable_ppp(base, prefix .. "дан") -- ви́даний from ви́дати
		else
			add_pres_futr(base, prefix, "да́м", "даси́", "да́сть", "дамо́", "дасте́", "даду́ть")
			add_imperative(base, prefix .. "да́й")
			add_default_past(base, prefix .. "да́")
			add_retractable_ppp(base, prefix .. "да́н") -- e.g. пере́даний from переда́ти
		end
		return
	end
	prefix = rmatch(lemma, "^(.*по)ві́?сти́?$")
	if prefix then
		local stressed_prefix = com.is_stressed(prefix)
		if stressed_prefix then
			add_pres_futr(base, prefix, "вім", "віси", "вість", "вімо", "вісте", "відять")
			add_imperative(base, prefix .. "відж", "[lc]")
			add_imperative(base, prefix .. "віж", "[lc]")
			add_default_past(base, prefix .. "ві")
			-- no PPP
		else
			add_pres_futr(base, prefix, "ві́м", "віси́", "ві́сть", "вімо́", "вісте́", "відя́ть")
			add_imperative(base, prefix .. "ві́дж", "[lc]")
			add_imperative(base, prefix .. "ві́ж", "[lc]")
			add_default_past(base, prefix .. "ві́")
			-- no PPP
		end
		return
	end
	prefix = rmatch(lemma, "^(.*)ї́?сти$")
	if prefix then
		local stressed_prefix = com.is_stressed(prefix)
		if stressed_prefix then
			add_pres_futr(base, prefix, "їм", "їси", "їсть", "їмо", "їсте", "їдять")
			add_imperative(base, prefix .. "їж")
			add_default_past(base, prefix .. "ї")
			add_ppp(base, prefix .. "їден") -- ви́їдений from ви́їсти
		else
			add_pres_futr(base, prefix, "ї́м", "їси́", "ї́сть", "їмо́", "їсте́", "їдя́ть")
			add_imperative(base, prefix .. "ї́ж")
			add_default_past(base, prefix .. "ї́")
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
		add_default_past(base, prefix .. (stressed_prefix and "бу" or "бу́"))
		add_ppp(base, prefix .. (stressed_prefix and "бут" or "бу́т")) -- e.g. забу́тий from забу́ти
		return
	end
	prefix = rmatch(lemma, "^(.*)ї́?хати$")
	if prefix then
		local stressed_prefix = com.is_stressed(prefix)
		add_present_e(base, prefix .. (stressed_prefix and "їд" or "ї́д"), "a")
		add_default_past(base, prefix .. (stressed_prefix and "їха" or "ї́ха"))
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
		add_pres_futr(base, prefix, "лю́", "е́ш", "е́", {"е́м", "емо́"}, "ете́", "ля́ть")
		add_imperative(base, prefix .. "и́")
		add_default_past(base, prefix .. "і́")
		-- no PPP
		return
	end
	prefix = rmatch(lemma, "^(.*)жи́?ти$")
	if prefix then
		local stressed_prefix = com.is_stressed(prefix)
		add_present_e(base, prefix .. "жив", stressed_prefix and "a" or "b")
		add_default_past(base, prefix .. (stressed_prefix and "жи" or "жи́"))
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


local function parse_indicator_and_form_spec(angle_bracket_spec)
	local inside = rmatch(angle_bracket_spec, "^<(.*)>$")
	assert(inside)
	local base = {}
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
				-- pp. 235-236 of Routledge's "Ukrainian: A Comprehensive Grammar" say that
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


-- Used for manual specification using {{uk-conj-manual}}.
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


-- Used for manual specification using {{uk-conj-manual}}.
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
		for suffix, _ in pairs(futr_suffixes) do
			forms["futr_" .. suffix] = forms["pres_futr_" .. suffix]
		end
	else
		for suffix, _ in pairs(futr_suffixes) do
			forms["pres_" .. suffix] = forms["pres_futr_" .. suffix]
		end
		-- Do the periphrastic future with бу́ду
		if forms.infinitive then
			for _, inf in ipairs(forms.infinitive) do
				for slot_suffix, _ in pairs(futr_suffixes) do
					local futrslot = "futr_" .. slot_suffix
					if not skip_slot(alternant_multiword_spec, futrslot) then
						iut.insert_form(forms, futrslot, {
							form = "[[" .. budu_forms[slot_suffix] .. "]] [[" ..
								com.initial_alternation(inf.form, budu_forms[slot_suffix]) .. "]]",
							no_accel = true,
						})
					end
				end
			end
		end
		-- Do the synthetic future
		if forms.infinitive then
			for _, inf in ipairs(forms.infinitive) do
				local futr_sufs
				local infstem = rmatch(inf.form, "^(.-)с[яь]$")
				if infstem then
					futr_sufs = futr_refl_suffixes
				else
					futr_sufs = futr_suffixes
					infstem = inf.form
				end
				for slot_suffix, futr_suffix in pairs(futr_sufs) do
					local futrslot = "futr_" .. slot_suffix
					if rfind(infstem, "ти́?$") then
						if type(futr_suffix) ~= "table" then
							futr_suffix = {futr_suffix}
						end
						for _, fs in ipairs(futr_suffix) do
							add(alternant_multiword_spec, futrslot, infstem, fs)
						end
					end
				end
			end
		end
	end
end


local function add_categories(alternant_multiword_spec)
	local cats = {}
	local function insert(cattype)
		table.insert(cats, "Ukrainian " .. cattype .. " verbs")
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
		canonicalize = function(form)
			return com.remove_monosyllabic_stress(form)
		end,
		include_translit = true,
		-- Explicit additional top-level footnotes only occur with {{uk-conj-manual}}.
		footnotes = alternant_multiword_spec.footnotes,
		allow_footnote_symbols = not not alternant_multiword_spec.footnotes,
	}
	iut.show_forms(alternant_multiword_spec.forms, props)
end


local function make_table(alternant_multiword_spec)
	local forms = alternant_multiword_spec.forms

	local table_spec_part1 = [=[
<div class="NavFrame" style="max-width:60em">
<div class="NavHead" style="text-align:left; background:var(--wikt-palette-lightindigo, #e9e9ff);">{title}{annotation}</div>
<div class="NavContent" style="overflow:auto">
{\op}| class="inflection-table inflection inflection-uk inflection-verb"
|+ For declension of participles, see their entries. Adverbial participles are indeclinable.
|- class="rowgroup"
! colspan="3" | {aspect_indicator}
|-
! [[infinitive]]
| colspan="2" | {infinitive}
|- class="rowgroup"
! [[participles]]
! [[present tense]]
! [[past tense]]
|-
! [[active]]
| {pres_actv_part}
| {past_actv_part}
|-
! [[passive]]
| &mdash;<!--absent-->
| {past_pasv_part}{past_pasv_part_impers}
|-
! [[adverbial]]
| {pres_adv_part}
| {past_adv_part}
|- class="rowgroup"
]=]

	local table_spec_single_aspect = [=[
!
! [[present tense]]
! [[future tense]]
|-
]=]

	local table_spec_biaspectual = [=[
! rowspan="2" |
! [[present tense|present&nbsp;tense]]&nbsp;(imperfective)
! [[future tense|future&nbsp;tense]]&nbsp;(imperfective)
|- class="rowgroup"
! style="text-align: center;" | [[future tense|future&nbsp;tense]]&nbsp;(perfective)
! —
|-
]=]

	local table_spec_part2 = [=[
! [[first-person singular|1st singular]]<br />{ya}
| {pres_1sg}
| {futr_1sg}
|-
! [[second-person singular|2nd singular]]<br />{ty}
| {pres_2sg}
| {futr_2sg}
|-
! [[third-person singular|3rd singular]]<br />{vin_vona_vono}
| {pres_3sg}
| {futr_3sg}
|-
! [[first-person plural|1st plural]]<br />{my}
| {pres_1pl}
| {futr_1pl}
|-
! [[second-person plural|2nd plural]]<br />{vy}
| {pres_2pl}
| {futr_2pl}
|-
! [[third-person plural|3rd plural]]<br />{vony}
| {pres_3pl}
| {futr_3pl}
|- class="rowgroup"
! [[imperative]]
! [[singular]]
! [[plural]]
|-
! first-person
| —
| {impr_1pl}
|-
! second-person
| {impr_2sg}
| {impr_2pl}
|- class="rowgroup"
! [[past tense]]
! [[singular]]
! [[plural]]<br />{my_vy_vony}
|-
! [[masculine]]<br />{ya_ty_vin}
| {past_m}
| rowspan="3" | {past_pl}
|-
! [[feminine]]<br />{ya_ty_vona}
| {past_f}
|- 
! [[neuter]]<br />{vono}
| {past_n}
|{\cl}{notes_clause}</div></div>]=]

	local table_spec = table_spec_part1 ..
		(alternant_multiword_spec.aspect == "both" and table_spec_biaspectual or table_spec_single_aspect) ..
		table_spec_part2

	local notes_template = [===[
<div style="width:100%;text-align:left;background:var(--wikt-palette-lightblue, #d9ebff)">
<div style="display:inline-block;text-align:left;padding-left:1em;padding-right:1em">
{footnote}
</div></div>
]===]

	if alternant_multiword_spec.title then
		forms.title = alternant_multiword_spec.title
	else
		forms.title = 'Conjugation of <i lang="uk" class="Cyrl">' .. forms.lemma .. '</i>'
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
function export.do_generate_forms(parent_args, pos, from_headword, def)
	local params = {
		[1] = {required = true, default = "чита́ти<1a.impf.tr.ppp>"},
		footnote = {list = true},
		title = {},
	}
	for _, slot in ipairs(input_verb_slots) do
		params[slot] = {}
	end

	local args = m_para.process(parent_args, params)
	local alternant_multiword_spec = parse_alternant_or_word_spec(args[1])
	alternant_multiword_spec.title = args.title
	alternant_multiword_spec.footnotes = args.footnote
	alternant_multiword_spec.forms = {}
	for _, base in ipairs(alternant_multiword_spec.alternants) do
		base.forms = alternant_multiword_spec.forms
		normalize_lemma(base)
	end
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


-- Entry point for {{uk-conj}}. Template-callable function to parse and conjugate a verb given
-- user-specified arguments and generate a displayable table of the conjugated forms.
function export.show(frame)
	local parent_args = frame:getParent().args
	local alternant_multiword_spec = export.do_generate_forms(parent_args)
	show_forms(alternant_multiword_spec)
	return make_table(alternant_multiword_spec) .. require("Module:utilities").format_categories(alternant_multiword_spec.categories, lang)
end


-- Entry point for {{uk-conj-manual}}. Template-callable function to parse and conjugate a verb given
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
