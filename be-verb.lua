local export = {}


--[=[

Authorship: Ben Wing <benwing2>

]=]

--[=[

WARNING: A lot of the code in this module is carried over from [[Module:uk-verb]]
and not yet converted for Belarusian. Only the portion of the code that supports
{{be-conj-manual}} is properly converted and tested.

TERMINOLOGY:

-- "slot" = A particular combination of tense/mood/person/number/gender/etc.
	 Example slot names for verbs are "pres_1sg" (present first singular) and
	 "past_pasv_part" (past passive participle). Each slot is filled with zero
	 or more forms.

-- "form" = The conjugated Belarusian form representing the value of a given slot.

-- "lemma" = The dictionary form of a given Belarusian term. Generally the infinitive,
	 but may occasionally be another form if the infinitive is missing.
]=]

local lang = require("Module:languages").getByCode("be")
local m_links = require("Module:links")
local m_table = require("Module:table")
local m_string_utilities = require("Module:string utilities")
local m_script_utilities = require("Module:script utilities")
local iut = require("Module:inflection utilities")
local m_para = require("Module:parameters")
local com = require("Module:User:Benwing2/be-common")

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
	["past_pasv_part"] = "past|pass|part",
	["pres_adv_part"] = "pres|adv|part",
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
	["impr_sg"] = "2|s|imp",
	["impr_pl"] = "2|p|imp",
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


local budu_forms = {
	["1sg"] = "бу́ду",
	["2sg"] = "бу́дзеш",
	["3sg"] = "бу́дзе",
	["1pl"] = "бу́дзем",
	["2pl"] = "бу́дзеце",
	["3pl"] = "бу́дуць",
}


local allowed_class_7_specs = {
	["д"] = "d",
	["d"] = "d",
	["т"] = "t",
	["t"] = "t",
	["с"] = "s",
	["s"] = "s",
	["ст"] = "st",
	["st"] = "st",
	["б"] = "b",
	["b"] = "b",
}


local function destress_ending(ending)
	if type(ending) == "string" then
		return com.make_unstressed(ending)
	else
		for i, e in ipairs(ending) do
			ending[i] = destress_ending(e)
		end
		return ending
	end
end


local function construct_stems(base, accent)
	if base.pres_stem then
		if accent == "a" or accent == "c" then
			base.stressed_stem = base.pres_stem
		else
			base.unstressed_stem = base.pres_stem
		end
	end
	if accent == "b" or accent == "c" then
		if base.unstressed_stem then
			base.stressed_stem = com.move_stress_left_onto_last_syllable(
				base.unstressed_stem, base.vowel_alternant)
			base.unstressed_2pl_stem =
				com.move_stress_right_when_stem_unstressed(base.unstressed_stem,
					base.vowel_alternant)
		else
			assert(base.stressed_stem)
			base.unstressed_stem = com.move_stress_right_off_of_last_syllable(
				base.stressed_stem, base.vowel_alternant)
			base.unstressed_2pl_stem = com.move_stress_right_twice_off_of_last_syllable(
				base.stressed_stem, base)
		end
	else
		assert(accent == "a")
		assert(base.stressed_stem)
		assert(com.is_stressed(base.stressed_stem))
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
		if rfind(slot, "3sg") or rfind(slot, "adv_part") or slot == "past_n" then
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


local function combine_stem_ending(stem, ending)
	if stem == "?" then
		return "?"
	else
		return stem .. ending
	end
end


local function palatalize_td(stem)
	stem = rsub(stem, "т$", "ц")
	stem = rsub(stem, "д$", "дз")
	return stem
end


local function add(base, slot, stem, ending)
	if skip_slot(base, slot) then
		return
	end
	if type(ending) == "table" then
		for _, e in ipairs(ending) do
			add(base, slot, stem, e)
		end
		return
	end
	if rfind(ending, "^[яеіёюь]") then
		if type(stem) == "table" then
			local new_form = palatalize_td(stem.form)
			if new_form ~= stem.form then
				stem = m_table.shallowcopy(stem)
				stem.form = new_form
			end
		else
			stem = palatalize_td(stem)
		end
	end
	iut.add_forms(base.forms, slot, stem, ending, combine_stem_ending)
end


local function add_default_stem(base, slot, ending)
	if type(ending) == "table" then
		for _, e in ipairs(ending) do
			add_default_stem(base, slot, e)
		end
		return
	end
	local stressed_ending = com.is_stressed(ending)
	local stem
	if stressed_ending then
		stem = com.is_monosyllabic(ending) and base.unstressed_stem or
			base.unstressed_2pl_stem
	else
		stem = base.stressed_stem
	end
	add(base, slot, stem, ending)
end


local function add_imperative(base, sg2, footnote)
	local sg2form = iut.generate_form(sg2, footnote)
	add(base, "impr_sg", sg2form, "")
	add(base, "impr_pl", sg2form, "це")
end


local function add_imperative_from_present(base, accent)
	local imptype = base.imptype
	if not base.imptype then
		if accent == "b" or accent == "c" then
			imptype = "long"
		elseif rfind(base.stressed_stem, "^вы́") then
			imptype = "long"
		elseif rfind(base.stressed_stem, com.vowel_c .. "́?д[зж]$") then
			imptype = "short"
		elseif rfind(base.stressed_stem, com.cons_c .. com.cons_c .. "$") then
			imptype = "long"
		else
			imptype = "short"
		end
	end
	local sg2
	if com.ends_in_vowel(base.stressed_stem) then
		-- If the stem ends in a vowel, then regardless of imptype, use the stressed
		-- stem and add й, effectively using the short type.
		sg2 = base.stressed_stem .. "й"
	elseif imptype == "long" then
		vowel = rfind(base.stressed_stem, com.always_hard_c .. "$") and "ы" or "і"
		if accent == "a" then
			sg2 = base.stressed_stem .. vowel
		else
			sg2 = base.unstressed_stem .. vowel .. AC
		end
	elseif rfind(base.stressed_stem, com.always_hard_c .. "$") then
		sg2 = base.stressed_stem
	elseif rfind(base.stressed_stem, "в$") then
		sg2 = rsub(base.stressed_stem, "в$", "ў")
	else
		sg2 = base.stressed_stem .. "ь"
	end
	add_imperative(base, sg2)
end


local function add_pres_adv_part(base, pl3)
	if base.aspect ~= "pf" then
		if type(base.pradp) == "table" then
			for _, pradp in ipairs(base.pradp) do
				add(base, "pres_adv_part", pradp, "")
			end
		elseif type(pl3) == "string" then
			local pl3base = rmatch(pl3, "^(.-)ць$")
			if not pl3base then
				error("Invalid third-plural ending, doesn't end in -ць: '" .. pl3 .. "'")
			end
			for _, parttype in ipairs(rsplit(base.pradp, "")) do
				local ending
				if parttype == "-" then
					ending = com.make_unstressed(pl3base) .. "чы"
				elseif parttype == "!" then
					ending = com.add_monosyllabic_accent(pl3base) .. "чы"
				elseif parttype == "+" then
					ending = com.make_unstressed(pl3base) .. "чы́"
				else
					error("Internal error: Unrecognized present adverbial participle indicator '" .. parttype .. "'")
				end
				add_default_stem(base, "pres_adv_part", ending)
			end
		end
	end
end


local function add_pres_futr(base, sg1, sg2, sg3, pl1, pl2, pl3)
	add_default_stem(base, "pres_futr_1sg", sg1)
	add_default_stem(base, "pres_futr_2sg", sg2)
	add_default_stem(base, "pres_futr_3sg", sg3)
	add_default_stem(base, "pres_futr_1pl", pl1)
	add_default_stem(base, "pres_futr_2pl", pl2)
	add_default_stem(base, "pres_futr_3pl", pl3)
	-- Do the present adverbial participle, which is based on the third plural present.
	-- FIXME: Do impersonal verbs have this participle?
	add_pres_adv_part(base, pl3)
end


local function destress_present_endings_per_accent(endings, accent)
	if accent == "b" then
		return
	end
	for i, ending in ipairs(endings) do
		if i ~= 1 or accent == "a" then
			endings[i] = destress_ending(ending)
		end
	end
end


local function add_present_e(base, accent, use_y_endings, overriding_imp)
	construct_stems(base, accent)
	-- Determine the stressed endings. We will then destress the endings as appropriate for the
	-- accent pattern.
	local endings
	if rfind(base.stressed_stem, com.always_hard_c .. "$") then
		-- р or hushing sounds need non-iotated variants.
		endings = {"у́", "э́ш", base.is_refl and "э́ць" or "э́", "о́м", "аце́", "у́ць"}
	else
		-- The iotated 1sg/3pl sometimes occur after consonants, e.g. in сы́паць (сы́плю, сы́плеш, ...).
		local iotated = use_y_endings or com.ends_in_vowel(base.stressed_stem) or
			rfind(base.stressed_stem, "['ь]$")
		endings = {iotated and "ю́" or "у́", "е́ш", base.is_refl and "е́ць" or "е́", "ём",
			accent == "b" and "яце́" or "еце", iotated and "ю́ць" or "у́ць"}
	end
	destress_present_endings_per_accent(endings, accent)
	add_pres_futr(base, unpack(endings))
	if overriding_imp == false then
		-- do nothing
	elseif overriding_imp then
		add_imperative(base, overriding_imp)
	else
		add_imperative_from_present(base, accent)
	end
end


local function add_present_i(base, accent, overriding_imp)
	construct_stems(base, accent)
	-- Determine the stressed endings. We will then destress the endings as appropriate for the
	-- accent pattern.
	local endings
	local iotated, iotated_stem
	if rfind(base.stressed_stem, com.always_hard_c .. "$") then
		-- р or hushing sounds need non-iotated variants.
		endings = {"у́", "ы́ш", "ы́ць", "ы́м", "ыце́", "а́ць"}
		iotated = false
	else
		local stem = accent == "a" and base.stressed_stem or base.unstressed_stem
		iotated_stem = com.iotate(stem)
		endings = {rfind(iotated_stem, com.always_hard_c .. "$") and "у́" or "ю́", "і́ш", "і́ць",
			"і́м", "іце́", rfind(stem, com.always_hard_c .. "$") and "а́ць" or "я́ць"}
		iotated = stem ~= iotated_stem
	end
	destress_present_endings_per_accent(endings, accent)
	local s1, s2, s3, p1, p2, p3 = unpack(endings)
	if not iotated then
		add_pres_futr(base, s1, s2, s3, p1, p2, p3)
	else
		local orig_stem = accent == "a" and base.stressed_stem or base.unstressed_stem
		if accent == "a" then
			base.stressed_stem = iotated_stem
		else
			base.unstressed_stem = iotated_stem
		end
		add_pres_futr(base, s1, {}, {}, {}, {}, {})
		if accent == "a" then
			base.stressed_stem = orig_stem
		else
			base.unstressed_stem = orig_stem
		end
		add_pres_futr(base, {}, s2, s3, p1, p2, p3)
	end
	if overriding_imp == false then
		-- do nothing
	elseif overriding_imp then
		add_imperative(base, overriding_imp)
	else
		add_imperative_from_present(base, accent)
	end
end


local function add_past(base, msgstem, reststem)
	add(base, "past_m", msgstem, "")
	add(base, "past_f", reststem, base.past_accent == "b" and "а́" or "а")
	add(base, "past_n", reststem, base.past_accent == "b" and "о́" or "а")
	add(base, "past_pl", reststem, base.past_accent == "b" and "ы́" or "ы")
	add(base, "past_adv_part", msgstem, "шы")
end


local function add_default_past(base, stem)
	add_past(base, stem .. "ў", stem .. "л")
end


local function add_ppp(base, stem)
	if base.is_refl or not base.ppp or base.trans == "intr" then
		return
	end
	if type(base.ppp) == "table" then
		for _, ppp in ipairs(base.ppp) do
			add(base, "past_pasv_part", ppp, "")
		end
	elseif not base.impers then
		add(base, "past_pasv_part", stem, "ы")
	end
end


local function add_retractable_ppp(base, stem)
	if not base.ppp then
		return
	end
	if base.ppp == "+" then
		add_ppp(base, stem)
	else
		local retracted_stem = com.move_stress_left_off_of_last_syllable(stem, base.vowel_alternant)
		if base.ppp == "+-" then
			add_ppp(base, stem)
			add_ppp(base, retracted_stem)
		elseif base.ppp == "-" then
			add_ppp(base, retracted_stem)
		elseif base.ppp == "-+" then
			add_ppp(base, retracted_stem)
			add_ppp(base, stem)
		else
			error("Internal error: Unrecognized PPP indicator '" .. base.ppp .. "'")
		end
	end
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
	if accent == "b" or accent == "c" then
		base.unstressed_stem = stem
	else
		base.stressed_stem = stem
	end
	return stem, suffix, ac
end


local conjs = {}


conjs["1"] = function(base, lemma, accent)
	local stem, suffix, ac = rmatch(lemma, "^(.*)([аяеэ])(́?)ць$")
	if not stem then
		error("Unrecognized lemma for class 1: '" .. lemma .. "'")
	end
	if accent ~= "a" then
		error("Only accent a allowed for class 1: '" .. base.conj .. "'")
	end
	local full_stem = stem .. suffix .. ac
	base.stressed_stem = full_stem
	add_present_e(base, "a")
	add_default_past(base, full_stem)
	add_retractable_ppp(base, full_stem .. ((suffix == "е" or suffix == "э") and "т" or "н"))
end


conjs["2"] = function(base, lemma, accent)
	if base.vowel_alternant then
		error("Can't specify vowel alternants with class 2 verbs: " .. base.vowel_alternant)
	end
	local stem, suffix = rmatch(lemma, "^(.*)([ая]ва́)ць$")
	local pres_stem
	if stem then
		if suffix == "ава́" then
			pres_stem = stem .. "у"
		else
			pres_stem = stem .. "ю"
		end
		if accent == "a" then
			base.stressed_stem = com.move_stress_left_onto_last_syllable(pres_stem)
		else
			base.unstressed_stem = pres_stem
		end
	else
		stem, suffix = rmatch(lemma, "^(.*)([ае]ва)ць$")
		if stem then
			if suffix == "ава" then
				pres_stem = stem .. "у"
			else
				pres_stem = stem .. "ю"
			end
			base.stressed_stem = pres_stem
			if accent == "b" then
				error("For class 2b, lemma must be end-stressed: '" .. lemma .. "'")
			end
		else
			error("Unrecognized lemma for class 2: '" .. lemma .. "'")
		end
	end
	if accent ~= "a" and accent ~= "b" then
		error("Only accent a or b allowed for class 2: '" .. base.conj .. "'")
	end
	add_present_e(base, accent)
	add_default_past(base, stem .. suffix)
	base.vowel_alternant = "ao"
	add_retractable_ppp(base, stem .. suffix .. "н")
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
	if base.conj == "н" then
		add_ppp(base, n_ppp)
	elseif base.conj == "т" then
		add_ppp(base, t_ppp)
	else
		add_ppp(base, n_ppp)
		add_ppp(base, t_ppp)
	end
end


conjs["4"] = function(base, lemma, accent)
	separate_stem_suffix_accent(base, lemma, "4", accent, "^(.*)([іы])(́?)ць$")
	add_present_i(base, accent)
	add_default_past(base, stem .. suffix .. ac)
	if accent == "a" then
		add_ppp(base, com.iotate(stressed_stem) .. (stem_ends_in_vowel and "єн" or "ен"))
	else
		-- By default, stress will retract one syllable if accent is c but not b,
		-- but this can be overridden in both directions using 'ppp-' (for b)
		-- or 'ppp+' (for c).
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
		past_msg = rsub(past_msg, "[еоя](́?" .. com.cons_c .. "+)$", "і%1")
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
	-- If explicit present stem given (e.g. for моло́ти), use it in the н-participle.
	local n_ppp
	if base.pres_stem then
		n_ppp = base.pres_stem .. "ен"
	else
		n_ppp = stressed_stem .. "ен"
	end
	local t_ppp = stressed_stem .. "от"
	if base.conj == "н" then
		add_ppp(base, n_ppp)
	elseif base.conj == "т" then
		add_ppp(base, t_ppp)
	else
		add_ppp(base, n_ppp)
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
	add_present_e(base, stem, accent)
	local full_stem = stem .. "ва́"
	add_default_past(base, full_stem)
	add_retractable_ppp(base, full_stem .. "н")
end


conjs["14"] = function(base, lemma, accent)
	-- -сти occurs in п'я́сти́ and роз(і)п'я́сти́
	local stem = rmatch(lemma, "^(.*[ая]́?)с?ти́?$")
	if not stem then
		error("Unrecognized lemma for class 14: '" .. lemma .. "'")
	end
	if not base.pres_stem then
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
		add_present_e(base, prefix .. (stressed_prefix and "їд" or "ї́д"), accent)
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
		base.conjnum, base.conjmod, base.accent = rmatch(conj, "^([0-9]+)(°?)([abc])$")
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
		elseif rfind(part, "^ppp") or part == "-ppp" then
			if base.ppp ~= nil then
				error("Can't specify past passive participle indicator twice: " .. angle_bracket_spec)
			end
			if part == "-ppp" then
				base.ppp = false
			elseif rfind(part, "^ppp:") then
				base.ppp = rsplit(rsub(part, "^pradp:", ""), ":")
			else
				base.ppp = rsub(part, "^ppp", "")
				if base.ppp ~= "" and base.ppp ~= "+" and base.ppp ~= "-" and base.ppp ~= "+-" and base.ppp ~= "-+" then
					error("Invalid value for past passive participle indicator: " .. angle_bracket_spec)
				end
			end
		elseif rfind(part, "^pradp") then
			if base.pradp ~= nil then
				error("Can't specify present adverbial participle indicator twice: " .. angle_bracket_spec)
			end
			if rfind(part, "^pradp:") then
				base.pradp = rsplit(rsub(part, "^pradp:", ""), ":")
			else
				base.pradp = rsub(part, "^pradp", "")
				local seen_indicators = {}
				for _, indicator in rsplit(base.pradp, "") do
					if seen_indicators[indicator] then
						error("Repeated present adverbial participle indicator in spec '" .. part .. "'")
					elseif indicator ~= "-" and indicator ~= "+" and indicator ~= "!" then
						error("Unrecognized present adverbial participle indicator '" .. indicator .. "' in spec '" .. part .. "'")
					else
						seen_indicators[indicator] = indicator
					end
				end
			end
		elseif part == "impers" then
			if base.impers then
				error("Can't specify 'impers' twice: " .. angle_bracket_spec)
			end
			base.impers = true
		elseif part == "longimp" or part == "shortimp" then
			if base.imptype then
				error("Can't specify imperative type twice: " .. angle_bracket_spec)
			end
			base.imptype = part
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
		elseif allowed_class_7_specs[part] then
			if base.cons then
				error("Can't specify consonant modifier twice: " .. angle_bracket_spec)
			end
			base.cons = allowed_class_7_specs[part]
		elseif part == "ae" or part == "ao" then
			if base.vowel_alternant then
				error("Can't specify vowel alternant twice: " .. angle_bracket_spec)
			end
			base.vowel_alternant = part
		elseif rfind(part, "^pres:") then
			part = rsub(part, "^pres:", "")
			base.pres_stem = rsub(part, "^pres:", "")
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
	base.lemma = com.add_monosyllabic_accent(base.lemma)
	if not rfind(base.lemma, AC) then
		error("Multisyllabic lemma '" .. base.orig_lemma .. "' needs an accent")
	end
	local active_verb = rmatch(base.lemma, "^(.*)ся$")
	if active_verb then
		base.is_refl = true
		base.lemma = active_verb
	else
		active_verb = rmatch(base.lemma, "^(.*)ца$")
		if active_verb then
			base.is_refl = true
			base.lemma = active_verb .. "ь"
		end
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
	elseif base.trans and base.trans ~= "intr" and base.aspect ~= "impf" then
		error("Must specify 'ppp' or '-ppp' with perfective transitive or mixed-transitive verbs")
	end
	if base.ppp == "" then
		if base.conjnum == "4" then
			if base.accent == "b" then
				base.ppp = "+"
			else
				base.ppp = "-"
			end
		else
			base.ppp = "+"
		end
	end
	if not base.pradp then
		if base.accent == "a" then
			base.pradp = "-"
		else
			base.pradp = "+"
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
	if base.pres_stem and base.conjnum ~= "14" then
		base.irreg = true
	end
	if base.pres_stem then
		if base.accent == "a" or base.accent == "c" then
			base.pres_stem = com.add_monosyllabic_accent(base.pres_stem)
			if not com.is_stressed(base.pres_stem) then
				error("With accent pattern " .. base.accent .. ", explicit present stem '" .. base.pres_stem .. "' must have an accent")
			end
		elseif com.is_stressed(base.pres_stem) then
			error("With accent pattern b, explicit present stem .. '" .. base.pres_stem .. "' should not have an accent")
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


local function detect_all_indicator_and_form_specs(alternant_spec)
	for _, base in ipairs(alternant_spec.alternants) do
		detect_indicator_and_form_spec(base)
		if not alternant_spec.aspect then
			alternant_spec.aspect = base.aspect
		elseif alternant_spec.aspect ~= base.aspect then
			alternant_spec.aspect = "both"
		end
		if alternant_spec.is_refl == nil then
			alternant_spec.is_refl = base.is_refl
		elseif alternant_spec.is_refl ~= base.is_refl then
			error("With multiple alternants, all must agree on reflexivity")
		end
		if not alternant_spec.trans then
			alternant_spec.trans = base.trans
		elseif alternant_spec.trans ~= base.trans then
			alternant_spec.trans = "mixed"
		end
		for _, prop in ipairs({"nopres", "noimp", "nopast", "impers", "only3", "onlypl", "only3pl", "only3orpl"}) do
			if alternant_spec[prop] == nil then
				alternant_spec[prop] = base[prop]
			elseif alternant_spec[prop] ~= base[prop] then
				alternant_spec[prop] = false
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
end


local function add_reflexive_suffix(alternant_spec)
	if not alternant_spec.is_refl then
		return
	end
	for slot, formvals in pairs(alternant_spec.forms) do
		alternant_spec.forms[slot] = iut.flatmap_forms(formvals, function(form)
			if (slot == "infinitive" or rfind(slot, "^pres_futr_3")) and rfind(form, "ць$") then
				return {rsub(form, "ць$", "цца")}
			elseif slot == "pres_futr_3sg" and com.ends_in_vowel(form) then
				return {form .. "цца"}
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


-- Used for manual specification using {{be-conj-manual}}.
local function set_reflexive_flag(alternant_spec)
	if alternant_spec.forms.infinitive then
		for _, inf in ipairs(alternant_spec.forms.infinitive) do
			if rfind(inf.form, "ся$") or rfind(inf.form, "ца$") then
				alternant_spec.is_refl = true
			end
		end
	end
end


local function set_present_future(alternant_spec)
	local forms = alternant_spec.forms
	local futr_suffixes = {"1sg", "2sg", "3sg", "1pl", "2pl", "3pl"}
	if alternant_spec.aspect == "pf" then
		for _, suffix in ipairs(futr_suffixes) do
			forms["futr_" .. suffix] = forms["pres_futr_" .. suffix]
		end
	else
		for _, suffix in ipairs(futr_suffixes) do
			forms["pres_" .. suffix] = forms["pres_futr_" .. suffix]
		end
		-- Do the periphrastic future with бу́ду
		if forms.infinitive then
			for _, inf in ipairs(forms.infinitive) do
				for _, slot_suffix in ipairs(futr_suffixes) do
					local futrslot = "futr_" .. slot_suffix
					if not skip_slot(alternant_spec, futrslot) then
						iut.insert_form(forms, futrslot, {
							form = "[[" .. budu_forms[slot_suffix] .. "]] [[" ..
								com.initial_alternation(inf.form, budu_forms[slot_suffix]) .. "]]",
							no_accel = true,
						})
					end
				end
			end
		end
	end
end


local function add_categories(alternant_spec)
	local cats = {}
	local function insert(cattype)
		table.insert(cats, "Belarusian " .. cattype .. " verbs")
	end
	if alternant_spec.aspect == "impf" then
		insert("imperfective")
	elseif alternant_spec.aspect == "pf" then
		insert("perfective")
	else
		assert(alternant_spec.aspect == "both")
		insert("imperfective")
		insert("perfective")
		insert("biaspectual")
	end
	if alternant_spec.trans == "tr" then
		insert("transitive")
	elseif alternant_spec.trans == "intr" then
		insert("intransitive")
	elseif alternant_spec.trans == "mixed" then
		insert("transitive")
		insert("intransitive")
	end
	if alternant_spec.is_refl then
		insert("reflexive")
	end
	if alternant_spec.impers then
		insert("impersonal")
	end
	if alternant_spec.alternants then -- not when manual
		for _, base in ipairs(alternant_spec.alternants) do
			if base.conj == "irreg" or base.irreg then
				insert("irregular")
			end
			if base.conj ~= "irreg" then
				insert("class " .. base.conj)
				insert("class " .. rsub(base.conj, "^([0-9]+).*", "%1"))
			end
		end
	end
	alternant_spec.categories = cats
end


local function show_forms(alternant_spec)
	local lemmas = {}
	if alternant_spec.forms.infinitive then
		for _, inf in ipairs(alternant_spec.forms.infinitive) do
			table.insert(lemmas, com.remove_monosyllabic_accents(inf.form))
		end
	end
	props = {
		lang = lang,
		canonicalize = function(form)
			return com.remove_monosyllabic_accents(form)
		end,
	}
	iut.show_forms_with_translit(alternant_spec.forms, lemmas, output_verb_slots, props, alternant_spec.footnotes, "allow footnote symbols")
end


local function make_table(alternant_spec)
	local forms = alternant_spec.forms

	local table_spec_part1 = [=[
<div class="NavFrame" style="width:60em">
<div class="NavHead" style="text-align:left; background:#e0e0ff;">{title}{annotation}</div>
<div class="NavContent">
{\op}| class="inflection-table inflection inflection-be inflection-verb"
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
! [[passive]]
| &mdash;<!--absent-->
| {past_pasv_part}
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
! [[third-person singular|3rd singular]]<br />{yon_yana_yano}
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
! [[third-person plural|3rd plural]]<br />{yany}
| {pres_3pl}
| {futr_3pl}
|- class="rowgroup"
! [[imperative]]
! [[singular]]
! [[plural]]
|-
! second-person
| {impr_sg}
| {impr_pl}
|- class="rowgroup"
! [[past tense]]
! [[singular]]
! [[plural]]<br />{my_vy_yany}
|-
! [[masculine]]<br />{ya_ty_yon}
| {past_m}
| rowspan="3" | {past_pl}
|-
! [[feminine]]<br />{ya_ty_yana}
| {past_f}
|- 
! [[neuter]]<br />{yano}
| {past_n}
|{\cl}{notes_clause}</div></div>]=]

	local table_spec = table_spec_part1 ..
		(alternant_spec.aspect == "both" and table_spec_biaspectual or table_spec_single_aspect) ..
		table_spec_part2

	local notes_template = [===[
<div style="width:100%;text-align:left;background:#d9ebff">
<div style="display:inline-block;text-align:left;padding-left:1em;padding-right:1em">
{footnote}
</div></div>
]===]

	if alternant_spec.title then
		forms.title = alternant_spec.title
	else
		forms.title = 'Conjugation of <i lang="be" class="Cyrl">' .. forms.lemma .. '</i>'
	end

	if alternant_spec.manual then
		forms.annotation = ""
	else
		local ann_parts = {}
		local saw_irreg_conj = false
		local saw_base_irreg = false
		local all_irreg_conj = true
		local conjs = {}
		for _, base in ipairs(alternant_spec.alternants) do
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
			alternant_spec.aspect == "impf" and "imperfective" or
			alternant_spec.aspect == "pf" and "perfective" or
			"biaspectual")
		if alternant_spec.trans then
			table.insert(ann_parts,
				alternant_spec.trans == "tr" and "transitive" or
				alternant_spec.trans == "intr" and "intransitive" or
				"transitive and intransitive"
			)
		end
		if alternant_spec.is_refl then
			table.insert(ann_parts, "reflexive")
		end
		if alternant_spec.impers then
			table.insert(ann_parts, "impersonal")
		end
		if saw_base_irreg and not saw_irreg_conj then
			table.insert(ann_parts, "irregular")
		end
		forms.annotation = " (" .. table.concat(ann_parts, ", ") .. ")"
	end

	-- pronouns used in the table
	forms.ya = tag_text("я")
	forms.ty = tag_text("ты")
	forms.yon_yana_yano = tag_text("ён / яна́ / яно́")
	forms.my = tag_text("мы")
	forms.vy = tag_text("вы")
	forms.yany = tag_text("яны́")
	forms.my_vy_yany = tag_text("мы / вы / яны́")
	forms.ya_ty_yon = tag_text("я / ты / ён")
	forms.ya_ty_yana = tag_text("я / ты / яна́")
	forms.yano = tag_text("яно́")

	if alternant_spec.aspect == "pf" then
		forms.aspect_indicator = "[[perfective aspect]]"
	elseif alternant_spec.aspect == "impf" then
		forms.aspect_indicator = "[[imperfective aspect]]"
	else
		forms.aspect_indicator = "[[biaspectual]]"
	end

	forms.notes_clause = forms.footnote ~= "" and
		m_string_utilities.format(notes_template, forms) or ""
	return m_string_utilities.format(table_spec, forms)
end


-- Implementation of template 'be-verb cat'.
function export.catboiler(frame)
	local SUBPAGENAME = mw.title.getCurrentTitle().subpageText

	local cats = {}

	local cls, variant, pattern = rmatch(SUBPAGENAME, "^Belarusian class ([0-9]*)([()%[%]°]*)([abc]?) verbs")
	local text = nil
	if not cls then
		error("Invalid category name, should be e.g. \"Belarusian class 3a verbs\"")
	end
	if pattern == "" then
		table.insert(cats, "Belarusian verbs by class|" .. cls .. variant)
		text = "This category contains Belarusian class " .. cls .. " verbs."
	else
		table.insert(cats, "Belarusian verbs by class and accent pattern|" .. cls .. pattern)
		table.insert(cats, "Belarusian class " .. cls .. " verbs|" .. pattern)
		text = "This category contains Belarusian class " .. cls .. " verbs of " ..
			"accent pattern " .. pattern .. (
			variant == "" and "" or " and variant " .. variant) .. ". " .. (
			pattern == "a" and "With this pattern, all forms are stem-stressed."
			or pattern == "b" and "With this pattern, all forms are ending-stressed."
			or "With this pattern, the first singular present indicative and all forms " ..
			"outside of the present indicative are ending-stressed, while the remaining " ..
			"forms of the present indicative are stem-stressed.").. (
			variant == "" and "" or
			cls == "3" and variant == "°" and " The variant code indicates that the -н of the stem " ..
			"is missing in most non-present-tense forms." or
			cls == "3" and (variant == "(°)" or variant == "[°]") and
			" The variant code indicates that the -н of the stem " ..
			"is optionally missing in most non-present-tense forms." or
			cls == "6" and variant == "°" and
			" The variant code indicates that the present tense is not " ..
			"[[Appendix:Glossary#iotation|iotated]]. (In most verbs of this class, " ..
			"the present tense is iotated, e.g. писа́ти with present tense " ..
			"пишу́, пи́шеш, пи́ше, etc.)" or
			error("Unrecognized variant code " .. variant .. " for class " .. cls)
			)
	end

	return text	.. "\n" ..
		mw.getCurrentFrame():expandTemplate{title="be-categoryTOC", args={}}
		.. require("Module:utilities").format_categories(cats, lang, nil, nil, "force")
end


-- Externally callable function to parse and conjugate a verb given user-specified arguments.
-- Return value is WORD_SPEC, an object where the conjugated forms are in `WORD_SPEC.forms`
-- for each slot. If there are no values for a slot, the slot key will be missing. The value
-- for a given slot is a list of objects {form=FORM, footnotes=FOOTNOTES}.
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
	local alternant_spec = parse_alternant_or_word_spec(args[1])
	alternant_spec.title = args.title
	alternant_spec.footnotes = args.footnote
	alternant_spec.forms = {}
	for _, base in ipairs(alternant_spec.alternants) do
		base.forms = alternant_spec.forms
		normalize_lemma(base)
	end
	detect_all_indicator_and_form_specs(alternant_spec)
	for _, base in ipairs(alternant_spec.alternants) do
		add_infinitive(base)
		conjs[base.conjnum](base, base.lemma, base.accent)
	end
	add_reflexive_suffix(alternant_spec)
	process_overrides(alternant_spec.forms, args)
	set_present_future(alternant_spec)
	add_categories(alternant_spec)
	return alternant_spec
end


-- Externally callable function to parse and conjugate a verb where all forms are given manually.
-- Return value is WORD_SPEC, an object where the conjugated forms are in `WORD_SPEC.forms`
-- for each slot. If there are no values for a slot, the slot key will be missing. The value
-- for a given slot is a list of objects {form=FORM, footnotes=FOOTNOTES}.
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
	local alternant_spec = {
		aspect = args.aspect,
		title = args.title,
		footnotes = args.footnote,
		forms = {},
		manual = true,
	}
	process_overrides(alternant_spec.forms, args)
	set_reflexive_flag(alternant_spec)
	set_present_future(alternant_spec)
	add_categories(alternant_spec)
	return alternant_spec
end


-- Entry point for {{be-conj}}. Template-callable function to parse and conjugate a verb given
-- user-specified arguments and generate a displayable table of the conjugated forms.
function export.show(frame)
	local parent_args = frame:getParent().args
	local alternant_spec = export.do_generate_forms(parent_args)
	show_forms(alternant_spec)
	return make_table(alternant_spec) .. require("Module:utilities").format_categories(alternant_spec.categories, lang)
end


-- Entry point for {{be-conj-manual}}. Template-callable function to parse and conjugate a verb given
-- manually-specified inflections and generate a displayable table of the conjugated forms.
function export.show_manual(frame)
	local parent_args = frame:getParent().args
	local alternant_spec = export.do_generate_forms_manual(parent_args)
	show_forms(alternant_spec)
	return make_table(alternant_spec) .. require("Module:utilities").format_categories(alternant_spec.categories, lang)
end


-- Concatenate all forms of all slots into a single string of the form
-- "SLOT=FORM,FORM,...|SLOT=FORM,FORM,...|...". Embedded pipe symbols (as might occur
-- in embedded links) are converted to <!>. If INCLUDE_PROPS is given, also include
-- additional properties (currently, only "|aspect=ASPECT"). This is for use by bots.
local function concat_forms(alternant_spec, include_props)
	local ins_text = {}
	for slot, _ in pairs(output_verb_slots) do
		local formtext = com.concat_forms_in_slot(alternant_spec.forms[slot])
		if formtext then
			table.insert(ins_text, slot .. "=" .. formtext)
		end
	end
	if include_props then
		table.insert(ins_text, "aspect=" .. alternant_spec.aspect)
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
	local alternant_spec = export.do_generate_forms(parent_args)
	return concat_forms(alternant_spec, include_props)
end


return export
