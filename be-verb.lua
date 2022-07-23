local export = {}


--[=[

Authorship: Ben Wing <benwing2>

]=]

--[=[

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
local com = require("Module:be-common")

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
	["pres_actv_part"] = "pres|act|part",
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
	["д"] = "д",
	["d"] = "д",
	["т"] = "т",
	["t"] = "т",
	["с"] = "с",
	["s"] = "с",
	["ст"] = "ст",
	["st"] = "ст",
	["в"] = "в",
	["v"] = "в",
}


local function destress_ending(ending)
	if type(ending) == "string" then
		return com.remove_accents(ending)
	else
		for i, e in ipairs(ending) do
			ending[i] = destress_ending(e)
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
		if com.is_accented(ending) then
			stem = com.remove_accents(stem)
		end
		return com.destress_vowels_after_stress_movement(stem .. ending)
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


local function add_user_supplied(base, slot, form)
	iut.insert_form(base.forms, slot, {form = form})
end


local function add_imperative(base, sg2, footnote)
	local sg2form = iut.generate_form(sg2, footnote)
	add(base, "impr_sg", sg2form, "")
	add(base, "impr_pl", sg2form, "це")
end


local function add_imperative_from_present(base, presstem)
	local imptype = base.imptype
	if not imptype then
		if com.ends_in_vowel(presstem) then
			imptype = "short"
		elseif base.accent == "b" or base.accent == "c" then
			imptype = "long"
		elseif rfind(presstem, "^вы́") then
			imptype = "long"
		elseif rfind(presstem, com.vowel_c .. "́?д[зж]$") then
			imptype = "short"
		elseif rfind(presstem, com.cons_c .. com.cons_c .. "$") then
			imptype = "long"
		else
			imptype = "short"
		end
	end
	local sg2
	if imptype == "long" then
		vowel = com.ends_always_hard(presstem) and "ы" or "і"
		if base.accent == "a" then
			sg2 = palatalize_td(presstem) .. vowel
		else
			sg2 = palatalize_td(com.remove_accents(presstem)) .. vowel .. AC
		end
	elseif com.ends_in_vowel(presstem) then
		sg2 = presstem .. "й"
	elseif com.ends_always_hard(presstem) then
		sg2 = presstem
	elseif rfind(presstem, "в$") then
		sg2 = rsub(presstem, "в$", "ў")
	else
		sg2 = palatalize_td(presstem) .. "ь"
	end
	add_imperative(base, sg2)
end


local function add_pres_adv_part(base, stem, pl3)
	if base.aspect ~= "pf" then
		if type(base.pradp) == "table" then
			for _, pradp in ipairs(base.pradp) do
				if pradp ~= "-" then
					add_user_supplied(base, "pres_adv_part", pradp)
				end
			end
		elseif type(pl3) == "string" then
			local pradp = base.pradp
			if not pradp then
				pradp = com.is_accented(pl3) and "+" or "-"
			end
			local pl3base = rmatch(pl3, "^(.-)ць$")
			if not pl3base then
				error("Invalid third-plural ending, doesn't end in -ць: '" .. pl3 .. "'")
			end
			for _, parttype in ipairs(rsplit(pradp, "")) do
				local ending
				if parttype == "-" then
					ending = com.remove_accents(pl3base) .. "чы"
				elseif parttype == "!" then
					ending = com.add_monosyllabic_accent(pl3base) .. "чы"
				elseif parttype == "+" then
					ending = com.remove_accents(pl3base) .. "чы́"
				else
					error("Internal error: Unrecognized present adverbial participle indicator '" .. parttype .. "'")
				end
				add(base, "pres_adv_part", stem, ending)
			end
		end
	end
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
	add_pres_adv_part(base, stem, pl3)
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


local function add_present_e(base, stem, variant, overriding_imp)
	stem = base.pres_stem or stem
	-- Determine the stressed endings. We will then destress the endings as appropriate for the
	-- accent pattern.
	local endings
	local iotated_stem = variant == "iotate" and com.iotate(stem) or stem
	if com.ends_always_hard(stem) or com.ends_always_hard(iotated_stem) then
		-- р or hushing sounds need non-iotated variants.
		endings = {"у́", "э́ш", base.is_refl and "э́ць" or "э́", "о́м", "аце́", "у́ць"}
	else
		-- The iotated 1sg/3pl sometimes occur after consonants, e.g. in сы́паць (сы́плю, сы́плеш, ...).
		local y_endings = variant == "yend" or com.ends_in_vowel(stem) or rfind(stem, "['ь]$")
		endings = {y_endings and "ю́" or "у́", "е́ш", base.is_refl and "е́ць" or "е́", "ё́м",
			"еце́", y_endings and "ю́ць" or "у́ць"}
	end
	destress_present_endings_per_accent(endings, base.accent)
	local s1, s2, s3, p1, p2, p3 = unpack(endings)
	if iotated_stem == stem then
		add_pres_futr(base, stem, s1, s2, s3, p1, p2, p3)
	else
		add_pres_futr(base, stem, s1, {}, {}, {}, {}, p3)
		add_pres_futr(base, iotated_stem, {}, s2, s3, p1, p2, {})
	end
	if overriding_imp == false then
		-- do nothing
	elseif overriding_imp then
		add_imperative(base, overriding_imp)
	else
		add_imperative_from_present(base, iotated_stem)
	end
end


local function add_present_i(base, stem, overriding_imp)
	stem = base.pres_stem or stem
	-- Determine the stressed endings. We will then destress the endings as appropriate for the
	-- accent pattern.
	local endings
	local iotated_stem
	if com.ends_always_hard(stem) then
		-- р or hushing sounds need non-iotated variants.
		endings = {"у́", "ы́ш", "ы́ць", "ы́м", "ыце́", "а́ць"}
		iotated_stem = stem
	else
		iotated_stem = com.iotate(stem)
		endings = {com.ends_always_hard(iotated_stem) and "у́" or "ю́", "і́ш", "і́ць",
			"і́м", "іце́", com.ends_always_hard(stem) and "а́ць" or "я́ць"}
	end
	destress_present_endings_per_accent(endings, base.accent)
	local s1, s2, s3, p1, p2, p3 = unpack(endings)
	if stem == iotated_stem then
		add_pres_futr(base, stem, s1, s2, s3, p1, p2, p3)
	else
		add_pres_futr(base, iotated_stem, s1, {}, {}, {}, {}, {})
		add_pres_futr(base, stem, {}, s2, s3, p1, p2, p3)
	end
	if overriding_imp == false then
		-- do nothing
	elseif overriding_imp then
		add_imperative(base, overriding_imp)
	else
		add_imperative_from_present(base, stem)
	end
end


local function add_past(base, msgstem, reststem)
	add(base, "past_m", msgstem, "")
	add(base, "past_f", reststem, base.past_accent == "b" and "а́" or "а")
	add(base, "past_n", reststem, base.past_accent == "b" and "о́" or "а")
	add(base, "past_pl", reststem, base.past_accent == "b" and "і́" or "і")
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
			add_user_supplied(base, "past_pasv_part", ppp)
		end
	elseif not base.impers then
		add(base, "past_pasv_part", stem, "ы")
	end
end


local function add_retractable_ppp(base, stem)
	if not base.ppp then
		return
	end
	if type(base.ppp) == "table" then
		add_ppp(base, stem)
		return
	end
	if base.ppp == "+" then
		add_ppp(base, stem)
	else
		local retracted_stem = stem
		local stembase, last_syl = rmatch(stem, "^(.-)(" .. com.vowel_c .. AC .. "?[нт])$")
		if not stembase then
			error("Internal error: Unrecognized stem for past passive participle: '" .. stem .. "'")
		end
		if com.is_accented(last_syl) and not com.is_nonsyllabic(stembase) then
			stembase = com.maybe_accent_final_syllable(stembase)
			last_syl = com.remove_accents(last_syl)
			retracted_stem = stembase .. last_syl
		end
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


local function check_stress_for_accent_type(base, ac)
	if (base.accent == "b" or base.accent == "c") and ac ~= AC then
		error("For class " .. base.conj .. ", lemma must be end-stressed: '" .. base.orig_lemma .. "'")
	end
	if base.accent == "a" and ac == AC then
		error("For class " .. base.conj .. ", lemma must be stem-stressed: '" .. base.orig_lemma .. "'")
	end
end


local function separate_stem_suffix_accent(base, regex)
	local stem, suffix, ac = rmatch(base.lemma, regex)
	if not stem then
		error("Unrecognized lemma for class " .. base.conjnum .. ": '" .. base.orig_lemma .. "'")
	end
	check_stress_for_accent_type(base, ac)
	return stem, suffix, ac
end


local conjs = {}


conjs["1"] = function(base)
	local stem, suffix, ac = rmatch(base.lemma, "^(.*)([аяеэ])(́?)ць$")
	if not stem then
		error("Unrecognized lemma for class 1: '" .. base.orig_lemma .. "'")
	end
	if base.accent ~= "a" then
		error("Only accent a allowed for class 1: '" .. base.conj .. "'")
	end
	local full_stem = stem .. suffix .. ac
	base.stressed_stem = full_stem
	add_present_e(base, full_stem)
	add_default_past(base, full_stem)
	add_retractable_ppp(base, full_stem .. ((suffix == "е" or suffix == "э") and "т" or "н"))
end


conjs["2"] = function(base)
	if base.vowel_alternant then
		error("No need to specify vowel alternant '" .. base.vowel_alternant .. "' in class 2; it's handled automatically")
	end
	local stem, last_vowel, suffix = rmatch(base.lemma, "^(.*)([аяе])(ва́?)ць$")
	if not stem then
		error("Unrecognized lemma for class 2: '" .. base.orig_lemma .. "'")
	end
	if base.accent ~= "a" and base.accent ~= "b" then
		error("Only accent a or b allowed for class 2: '" .. base.conj .. "'")
	end
	if base.accent == "b" and suffix ~= "ва́" then
		error("For class 2b, lemma must be end-stressed: '" .. base.orig_lemma .. "'")
	end
	local pres_stem = com.maybe_accent_final_syllable(stem .. (last_vowel == "а" and "у" or "ю"))
	local past_stem = stem .. (last_vowel == "а" and "о" or "ё") .. suffix
	add_present_e(base, pres_stem)
	add_default_past(base, past_stem)
	add_retractable_ppp(base, past_stem .. "н")
end


conjs["3"] = function(base)
	-- FIXME, handle звяць here?
	local stem, suffix, ac = separate_stem_suffix_accent(base, "^(.*)(ну)(́?)ць$")
	local stressed_stem = com.maybe_accent_final_syllable(stem)
	add_present_e(base, stressed_stem .. "н")
	local long_stem = stem .. suffix .. ac
	if base.conjmod == "" then
		add_default_past(base, long_stem)
	elseif base.conjmod == "°" then
		if base.accent ~= "a" then
			error("No current support for class 3°" .. base.accent)
		end
		add_past(base, stem, stem .. "л")
	else
		error("Internal error: Unrecognized conjugation modifier: '" .. base.conjmod .. "'")
	end
	add_retractable_ppp(base, long_stem .. "т")
end


conjs["4"] = function(base)
	local stem, suffix, ac = separate_stem_suffix_accent(base, "^(.*)([іы])(́?)ць$")
	local stressed_stem = com.maybe_accent_final_syllable(stem)
	add_present_i(base, stressed_stem)
	add_default_past(base, stem .. suffix .. ac)
	local iotated_stem = com.iotate(stem)
	-- By default, stress will retract one syllable if accent is c but not b,
	-- but this can be overridden in both directions using 'ppp-' (for b)
	-- or 'ppp+' (for c).
	add_retractable_ppp(base, iotated_stem .. (com.ends_always_hard(iotated_stem) and "о" or "ё") .. ac .. "н")
end


conjs["5"] = function(base)
	local stem, suffix, ac = separate_stem_suffix_accent(base, "^(.*)([еэая])(́?)ць$")
	local stem_ends_in_vowel = com.ends_in_vowel(stem)
	if suffix == "я" and not stem_ends_in_vowel then
		error("Ending -яць can only be used with a vocalic stem: '" .. base.orig_lemma .. "'")
	elseif suffix ~= "я" and stem_ends_in_vowel then
		error("Ending -яць must be used with a vocalic stem: '" .. base.orig_lemma .. "'")
	end
	local stressed_stem = com.maybe_accent_final_syllable(stem)
	add_present_i(base, stressed_stem)
	add_default_past(base, stem .. suffix .. ac)
	local iotated_stem = com.iotate(stem)
	add_retractable_ppp(base, iotated_stem .. (com.ends_always_hard(iotated_stem) and "а" or suffix) .. ac .. "н")
end


conjs["6"] = function(base)
	local stem, suffix, ac = separate_stem_suffix_accent(base, "^(.*)([еая])(́?)ць$")
	local stem_ends_in_vowel = com.ends_in_vowel(stem)
	if suffix == "я" and not stem_ends_in_vowel then
		error("Ending -яць can only be used with a vocalic stem: '" .. base.orig_lemma .. "'")
	elseif suffix ~= "я" and stem_ends_in_vowel then
		error("Ending -яць must be used with a vocalic stem: '" .. base.orig_lemma .. "'")
	end
	local pres_stem = com.maybe_accent_final_syllable(stem)
	if base.conjmod == "" then
		pres_stem = com.iotate(pres_stem)
	end
	local sg2
	-- These verbs have non-iotated imperative even though the present tense is iotated.
	if rfind(base.lemma, "сы́?паць$") then
		sg2 = stem
		base.irreg = true
	elseif rfind(base.lemma, "хоце́ць$") then
		sg2 = stem .. "і́"
		base.irreg = true
	end
	add_present_e(base, pres_stem, base.conjmod == "" and "yend" or nil, sg2)
	local full_stem = stem .. suffix .. ac
	add_default_past(base, full_stem)
	add_retractable_ppp(base, full_stem .. "н")
end


conjs["7"] = function(base)
	local stem, last_cons = rmatch(base.lemma, "^(.*)(" .. com.cons_c .. ")ці́?$")
	if not stem then
		error("Unrecognized lemma for class 7: '" .. base.orig_lemma .. "'")
	end
	if last_cons == "р" then
		error("Use class 9 for lemmas in -рці: '" .. base.orig_lemma .. "'")
	end
	if last_cons == "с" then
		if base.cons then
			last_cons = base.cons
		else
			error("With lemmas in -сці, must specify final consonant: '" .. base.orig_lemma .. "'")
		end
	elseif base.cons then
		error("Can only specify final consonant '" .. base.cons .. "' with lemma ending in -сці: '" .. base.orig_lemma .. "'")
	end
	local stressed_stem = com.maybe_accent_final_syllable(stem)
	add_present_e(base, stressed_stem .. last_cons)
	local past_msg, past_rest
	if base.cons == "д" or base.cons == "т" or base.cons == "в" then
		past_msg = stressed_stem .. "ў"
		past_rest = stressed_stem .. "л"
	elseif base.cons == "ст" then
		past_msg = stressed_stem .. "с"
		past_rest = past_msg .. "л"
	else
		past_msg = stressed_stem .. last_cons
		past_rest = past_msg .. "л"
	end
	if base.jo then
		past_msg = rsub(past_msg, "([еэ]́)", {["е́"] = "ё́", ["э́"] = "о́"})
	end
	add_past(base, past_msg, past_rest)
	add_retractable_ppp(base, com.remove_accents(stem) .. palatalize_td(last_cons) .. "ё́н")
end


conjs["8"] = function(base)
	local stem, last_cons = rmatch(base.lemma, "^(.-)(г?)чы́?$")
	if not stem then
		error("Unrecognized lemma for class 8: '" .. base.orig_lemma .. "'")
	end
	if last_cons == "" then
		last_cons = "к"
	end
	local palatalized_cons = com.iotate(last_cons)
	local stressed_stem = com.maybe_accent_final_syllable(stem)
	add_present_e(base, stressed_stem .. last_cons, "iotate")
	local past_msg = stressed_stem .. last_cons
	local past_rest = past_msg .. "л"
	if base.jo then
		past_msg = rsub(past_msg, "([еэ]́)", {["е́"] = "ё́", ["э́"] = "о́"})
	end
	add_past(base, past_msg, past_rest)
	add_retractable_ppp(base, com.remove_accents(stem) .. palatalized_cons .. "о́н")
end


local function construct_long_prefix_variant(prefix)
	if rfind(prefix, "рас$") then
		return rsub(prefix, "рас$", "разо")
	end
	if prefix == "з" then
		return "со"
	end
	return prefix .. "о"
end

conjs["9"] = function(base)
	local stem, suffix = rmatch(base.lemma, "^(.*)(е́?р)ці$")
	if not stem then
		error("Unrecognized lemma for class 9: '" .. base.orig_lemma .. "'")
	end
	if base.accent ~= "a" and base.accent ~= "b" then
		error("Only accent a or b allowed for class 9: '" .. base.conj .. "'")
	end
	if base.conj_star then
		pres_stem = rsub(stem, "^(.*)(.)$", function(prefix, root)
			return construct_long_prefix_variant(prefix) .. root
		end)
	else
		pres_stem = stem
	end
	pres_stem = rsub(pres_stem, "ц$", "т")
	add_present_e(base, pres_stem .. "р")
	local stressed_stem = rsub(com.maybe_accent_final_syllable(stem .. suffix), "е́", "ё́")
	add_past(base, stressed_stem, stressed_stem .. "л")
	add_ppp(base, stressed_stem .. "т")
end


conjs["10"] = function(base)
	local stem, suffix, ac = separate_stem_suffix_accent(base, "^(.*)([ао][лр][ао])(́?)ць$")
	if base.accent ~= "a" and base.accent ~= "c" then
		error("Only accent a or c allowed for class 10: '" .. base.conj .. "'")
	end
	suffix = rsub(suffix, "а", "о")
	local stressed_stem = com.maybe_accent_final_syllable(rsub(stem .. suffix, "о$", ""))
	add_present_e(base, stressed_stem, "yend")
	add_default_past(base, stem .. suffix .. ac)
	-- If explicit present stem given (e.g. for мало́ць), use it in the н-participle.
	local n_ppp, n_stem
	if base.pres_stem then
		n_stem = base.pres_stem
	else
		n_stem = stressed_stem
	end
	n_ppp = n_stem .. "он"
	local t_ppp = stressed_stem .. "от"
	for _, indicator in ipairs(rsplit(base.ppp_ending, "")) do
		if indicator == "n" then
			add_ppp(base, n_ppp)
		elseif indicator == "t" then
			add_ppp(base, t_ppp)
		end
	end
end


conjs["11"] = function(base)
	local stem, suffix, ac = separate_stem_suffix_accent(base, "^(.*)(і)(́?)ць$")
	if base.accent ~= "a" and base.accent ~= "b" then
		error("Only accent a or b allowed for class 11: '" .. base.conj .. "'")
	end
	local pres_stem
	if base.conj_star then
		pres_stem = rsub(stem, "^(.*)(.)$", function(prefix, root)
			return construct_long_prefix_variant(prefix) .. root
		end)
	else
		pres_stem = stem
	end
	if rfind(pres_stem, "л$") then
		pres_stem = pres_stem .. "ь"
	else
		pres_stem = pres_stem .. "'"
	end
	-- FIXME, віць and ліць should be 11-only due to imperative
	local full_stem = stem .. suffix .. ac
	add_present_e(base, pres_stem, "yend", full_stem)
	add_default_past(base, full_stem)
	add_ppp(base, full_stem .. "т")
end


conjs["12"] = function(base)
	-- Handle гні́сці
	local stem = rmatch(base.lemma, "^(.*" .. com.vowel_c .. AC .. "?)с?ц[ьі]$")
	if not stem then
		error("Unrecognized lemma for class 12: '" .. base.orig_lemma .. "'")
	end
	if base.accent ~= "a" and base.accent ~= "b" then
		error("Only accent a or b allowed for class 12: '" .. base.conj .. "'")
	end
	add_present_e(base, stem)
	add_default_past(base, stem)
	add_ppp(base, stem .. "т")
end


conjs["13"] = function(base)
	local stem = rmatch(base.lemma, "^(.*а)ва́ць$")
	if not stem then
		error("Unrecognized lemma for class 13: '" .. base.orig_lemma .. "'")
	end
	if base.accent ~= "b" then
		error("Only accent b allowed for class 13: '" .. base.conj .. "'")
	end
	local full_stem = stem .. "ва́"
	add_present_e(base, stem, nil, full_stem .. "й")
	add_default_past(base, full_stem)
	add_retractable_ppp(base, full_stem .. "н")
end


conjs["14"] = function(base)
	local stem = rmatch(base.lemma, "^(.*[ая]́?)ць$")
	if not stem then
		error("Unrecognized lemma for class 14: '" .. base.orig_lemma .. "'")
	end
	if not base.pres_stem then
		error("With class 14, must specify explicit present stem using 'pres:STEM'")
	end
	add_present_e(base, "foo")
	local stressed_stem = com.maybe_accent_final_syllable(stem)
	add_default_past(base, stressed_stem)
	add_retractable_ppp(base, stressed_stem .. "т")
end


conjs["15"] = function(base)
	local stem = rmatch(base.lemma, "^(.*" .. com.vowel_c .. AC .. "?)ць$")
	if not stem then
		error("Unrecognized lemma for class 15: '" .. base.orig_lemma .. "'")
	end
	-- заста́цца is class 15b
	if base.accent ~= "a" and base.accent ~= "b" then
		error("Only accent a or b allowed for class 15: '" .. base.conj .. "'")
	end
	add_present_e(base, stem .. "н")
	add_default_past(base, stem)
	add_ppp(base, stem .. "т")
end


conjs["16"] = function(base)
	local stem = rmatch(base.lemma, "^(.*" .. com.vowel_c .. AC .. "?)ць$")
	if not stem then
		error("Unrecognized lemma for class 15: '" .. base.orig_lemma .. "'")
	end
	if base.accent ~= "a" and base.accent ~= "b" then
		error("Only accent a or b allowed for class 16: '" .. base.conj .. "'")
	end
	add_present_e(base, stem .. "в")
	add_default_past(base, stem)
	add_ppp(base, stem .. "т")
end


conjs["irreg"] = function(base)
	local prefix
	local function add_manual_pres_futr_imper(s1, s2, s3, p1, p2, p3, imp)
		if com.is_accented(prefix) then
			s1 = destress_ending(s1)
			s2 = destress_ending(s2)
			s3 = destress_ending(s3)
			p1 = destress_ending(p1)
			p2 = destress_ending(p2)
			p3 = destress_ending(p3)
			imp = destress_ending(imp)
		end
		add_pres_futr(base, prefix, s1, s2, s3, p1, p2, p3)
		add_imperative(base, prefix .. imp)
	end
	local function add_default_past_ppp(past, ppp)
		local stressed_prefix = com.is_accented(prefix)
		if stressed_prefix then
			past = destress_ending(past)
		end
		add_default_past(base, prefix .. past)
		if ppp then
			if stressed_prefix then
				ppp = destress_ending(ppp)
			end
			add_retractable_ppp(base, prefix .. ppp)
		end
	end

	prefix = rmatch(base.lemma, "^(.*)да́?ць$")
	if prefix then
		add_manual_pres_futr_imper("да́м", "дасі́", "да́сць", "дадзі́м", "дасце́", "даду́ць", "да́й")
		add_default_past_ppp("да́", "да́дзен")
		return
	end
	prefix = rmatch(base.lemma, "^(.*)е́?сці$")
	if prefix then
		add_manual_pres_futr_imper("е́м", "есі́", "е́сць", "едзі́м", "есце́", "еду́ць", "е́ш")
		add_default_past_ppp("е́", "е́дзен")
		return
	end
	prefix = rmatch(base.lemma, "^(.*)бы́?ць$")
	if prefix then
		if prefix == "" then
			error("Can't handle unprefixed irregular verb выць yet")
		end
		base.accent = "a"
		add_present_e(base, prefix .. (com.is_accented(prefix) and "буд" or "бу́д"))
		add_default_past_ppp("бы́", "бы́т")
		return
	end
	prefix = rmatch(base.lemma, "^(.*)е́?хаць$")
	if prefix then
		base.accent = "a"
		add_present_e(base, prefix .. (com.is_accented(prefix) and "ед" or "е́д"))
		add_default_past_ppp("е́ха") -- no PPP
		return
	end
	local root
	prefix, root = rmatch(base.lemma, "^(.*)(бе́?г)чы$")
	if prefix then
		local stressed_prefix = com.is_accented(prefix)
		if not stressed_prefix then
			root = com.remove_accents(root)
		end
		local iotated_root = com.iotate(root)
		base.accent = stressed_prefix and "a" or "b"
		if not base.pradp then
			base.pradp = "!+"
		end
		if stressed_prefix then
			add_pres_futr(base, prefix .. root, "у", {}, {}, {}, {}, "уць")
			add_pres_futr(base, prefix .. iotated_root, {}, "ыш", "ыць", "ым", "ыце", {})
		else
			add_pres_futr(base, prefix .. root, "у́", {}, {}, {}, {}, "у́ць")
			add_pres_futr(base, prefix .. iotated_root, {}, "ы́ш", "ы́ць", "ы́м", "ы́це", {})
		end
		add_imperative(base, prefix .. iotated_root .. (stressed_prefix and "ы" or "ы́"))
		local past_msg = prefix .. (stressed_prefix and "бег" or "бе́г")
		add_past(base, past_msg, past_msg .. "л")
		-- no PPP
		return
	end
	prefix = rmatch(base.lemma, "^(.*)лга́?ць")
	if prefix then
		local stressed_prefix = com.is_accented(prefix)
		base.accent = stressed_prefix and "a" or "b"
		add_present_e(base, com.maybe_accent_final_syllable(prefix .. "лг"), "iotate")
		add_default_past_ppp("лга́") -- no PPP
		return
	end
	prefix = rmatch(base.lemma, "^(.*[іый])сці́?$")
	if prefix then
		local stressed_prefix = com.is_accented(prefix)
		base.accent = stressed_prefix and "a" or (prefix == "і" or prefix == "й") and "b" or "c"
		add_present_e(base, com.maybe_accent_final_syllable(prefix .. "д"))
		add_past(base, prefix .. (stressed_prefix and "шоў" or "шо́ў"), com.maybe_accent_final_syllable(prefix .. "шл"))
		-- no PPP
		return
	end
	error("Unrecognized irregular verb: '" .. base.orig_lemma .. "'")
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
		base.conjmod = ""
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
				base.ppp = rsplit(rsub(part, "^ppp:", ""), ":")
			else
				base.ppp = rsub(part, "^ppp", "")
				local seen_plus_minus = {}
				local seen_t_n = {}
				if base.ppp ~= "" then
					for _, indicator in ipairs(rsplit(base.ppp, "")) do
						if indicator == "+" or indicator == "-" then
							if m_table.contains(seen_plus_minus, indicator) then
								error("Repeated past passive participle +/- indicator in spec '" .. part .. "'")
							else
								table.insert(seen_plus_minus, indicator)
							end
						elseif indicator == "t" or indicator == "n" then
							if m_table.contains(seen_t_n, indicator) then
								error("Repeated past passive participle t/n indicator in spec '" .. part .. "'")
							else
								table.insert(seen_t_n, indicator)
							end
						else
							error("Unrecognized past passive participle indicator '" .. indicator .. "' in spec '" .. part .. "'")
						end
					end
					base.ppp = table.concat(seen_plus_minus)
					base.ppp_ending = table.concat(seen_t_n)
					if base.ppp_ending == "" then
						base.ppp_ending = nil
					end
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
				for _, indicator in ipairs(rsplit(base.pradp, "")) do
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
		elseif allowed_class_7_specs[part] then
			if base.cons then
				error("Can't specify consonant modifier twice: " .. angle_bracket_spec)
			end
			base.cons = allowed_class_7_specs[part]
		elseif part == "ё" or part == "jo" then
			if base.jo then
				error("Can't specify 'ё'/'jo' twice: " .. angle_bracket_spec)
			end
			base.jo = true
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
	if not com.is_stressed(base.lemma) then
		error("Multisyllabic lemma '" .. base.orig_lemma .. "' needs an accent")
	end
	base.lemma = com.mark_stressed_vowels_in_unstressed_syllables(base.lemma)
	local valt = base.vowel_alternant and {base.vowel_alternant} or nil
	base.lemma = com.apply_vowel_alternation(base.lemma, valt)
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
		elseif base.conjnum == "7" or base.conjnum == "8" or base.conjnum == "10" then
			base.ppp = "-"
		else
			base.ppp = "+"
		end
	end
	-- Don't set default for base.pradp here. It depends on base.accent, which
	-- may not be set till we call the conjugation function (at least in the case
	-- of "irreg").
	if base.conjnum == "10" then
		if not base.ppp_ending then
			base.ppp_ending = "t"
		end
	elseif base.ppp_ending then
		error("Can only specify 't' or 'n' with 'ppp' with class 10: '" .. base.ppp_ending .. "'")
	end
	if base.cons and base.conjnum ~= "7" then
		error("Consonant modifier '" .. base.cons .. "' can only be specified with class 7")
	end
	if base.jo and base.conjnum ~= "7" and base.conjnum ~= "8" then
		error("Modifier 'ё'/'jo' can only be specified with classes 7 or 8")
	end
	if base.conjmod ~= "" then
		if base.conjnum ~= "3" and base.conjnum ~= "6" then
			error("Conjugation modifiers only allowed for conjugations 3 and 6: '" .. base.conjmod .. "'")
		end
	end
	if base.pres_stem and base.conjnum ~= "14" then
		base.irreg = true
	end
	if base.pres_stem then
		if base.accent == "a" or base.accent == "c" then
			base.pres_stem = com.add_monosyllabic_accent(base.pres_stem)
			if not com.is_stressed(base.pres_stem) then
				error("With accent pattern " .. base.accent .. ", explicit present stem '" .. base.pres_stem .. "' must have an accent")
			base.pres_stem = com.mark_stressed_vowels_in_unstressed_syllables(base.pres_stem)
			end
		else
			if com.is_accented(base.pres_stem) then
				error("With accent pattern b, explicit present stem .. '" .. base.pres_stem .. "' should not have an accent")
			end
			-- Add two fictitious vowels at the end so that mark_stressed_vowels_in_unstressed_syllables()
			-- will function correctly, then remove them.
			base.pres_stem = base.pres_stem .. "ава́"
			base.pres_stem = com.mark_stressed_vowels_in_unstressed_syllables(base.pres_stem)
			base.pres_stem = rsub(base.pres_stem, "ава́$", "")
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
		error("Verb spec must be of the form 'LEMMA<CONJ.SPECS>': '" .. table.concat(segments) .. "'")
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
! [[active]]
| {pres_actv_part}
| &mdash;<!--absent-->
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


-- Externally callable function to parse and conjugate a verb given user-specified arguments.
-- Return value is WORD_SPEC, an object where the conjugated forms are in `WORD_SPEC.forms`
-- for each slot. If there are no values for a slot, the slot key will be missing. The value
-- for a given slot is a list of objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms(parent_args, pos, from_headword, def)
	local params = {
		[1] = {required = true, default = "піса́ць<6c.impf.tr.ppp->"},
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
		local formtext = iut.concat_forms_in_slot(alternant_spec.forms[slot])
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
