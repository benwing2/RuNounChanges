local export = {}


--[=[

Authorship: Ben Wing <benwing2>

]=]

--[=[

TERMINOLOGY:

-- "slot" = A particular combination of tense/aspect/person/number, or for participles
	 a particular combination of tense/aspect/voice/case/gender/number/definiteness.
	 Example slot names for nouns are "pres_1sg" (present first singular) and
	 "paap_def_obj_m_sg" (definite objective masculine singular past active aorist participle).
	 Each slot is filled with zero or more forms.

-- "form" = The conjugated Bulgarian form representing the value of a given slot.
	 For example, реши́лия is a form, representing the value of the paap_def_obj_m_sg
	 slot of the lemma реша́.

-- "lemma" = The dictionary form of a given Bulgarian term. Generally the first singular
	 present, but may occasionally be another form if the first singular present is missing.
]=]

local lang = require("Module:languages").getByCode("bg")
local m_links = require("Module:links")
local m_table = require("Module:table")
local m_string_utilities = require("Module:string utilities")
local m_para = require("Module:parameters")
local m_bg_translit = require("Module:bg-translit")
local com = require("Module:bg-common")

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


local function link(term)
	return m_links.full_link({lang = lang, term = term, tr = "-"})
end


local verb_slots = {
	-- present tense
	"pres_1sg", "pres_2sg", "pres_3sg", "pres_1pl", "pres_2pl", "pres_3pl",
	-- imperfect
	"impf_1sg", "impf_2sg", "impf_3sg", "impf_1pl", "impf_2pl", "impf_3pl",
	-- aorist
	"aor_1sg", "aor_2sg", "aor_3sg", "aor_1pl", "aor_2pl", "aor_3pl",
	-- imperative
	"impv_sg", "impv_pl",
	-- present active participle
	"prap_ind_m_sg", "prap_def_sub_m_sg", "prap_def_obj_m_sg",
	"prap_ind_f_sg", "prap_def_f_sg", "prap_ind_n_sg", "prap_def_n_sg",
	"prap_ind_pl", "prap_def_pl",
	-- past active aorist participle
	"paap_ind_m_sg", "paap_def_sub_m_sg", "paap_def_obj_m_sg",
	"paap_ind_f_sg", "paap_def_f_sg", "paap_ind_n_sg", "paap_def_n_sg",
	"paap_ind_pl", "paap_def_pl",
	-- past active imperfect participle
	"paip_m_sg", "paip_f_sg", "paip_n_sg", "paip_pl",
	-- past passive participle
	"ppp_ind_m_sg", "ppp_def_sub_m_sg", "ppp_def_obj_m_sg",
	"ppp_ind_f_sg", "ppp_def_f_sg", "ppp_ind_n_sg", "ppp_def_n_sg",
	"ppp_ind_pl", "ppp_def_pl",
	-- verbal noun
	"vn_ind_sg", "vn_def_sg", "vn_ind_pl", "vn_def_pl",
	-- adverbial participle
	"advp",
}


local impers_verb_slots = m_table.listToSet({
	"pres_3sg",
	"impf_3sg",
	"aor_3sg",
	"prap_ind_n_sg", "prap_def_n_sg",
	"paap_ind_n_sg", "paap_def_n_sg",
	"paip_n_sg",
	"ppp_ind_n_sg", "ppp_def_n_sg",
	"vn_ind_sg", "vn_def_sg", "vn_ind_pl", "vn_def_pl",
	"advp",
})


local prefix_to_accel_form = {
	["pres"] = "pres|ind",
	["impf"] = "impf|ind",
	["aor"] = "aor|ind",
	["impv"] = "imp",
	["prap"] = "pres|act|part",
	["paap"] = "past|act|aor|part",
	["paip"] = "past|act|impf|part",
	["ppp"] = "past|pass|part",
	["vn"] = "vnoun",
	["advp"] = "adv|part",
}


local suffix_to_accel_form = {
	-- suffixes for finite forms
	["1sg"] = "1|s",
	["2sg"] = "2|s",
	["3sg"] = "3|s",
	["1pl"] = "1|p",
	["2pl"] = "2|p",
	["3pl"] = "3|p",
	-- additional suffixes for imperatives
	["sg"] = "s",
	["pl"] = "p",
	-- suffixes for participles that can have definite forms
	["ind_m_sg"] = "indef|m|s",
	["def_sub_m_sg"] = "def|sbjv|m|s",
	["def_obj_m_sg"] = "def|objv|m|s",
	["ind_f_sg"] = "indef|f|s",
	["def_f_sg"] = "def|f|s",
	["ind_n_sg"] = "indef|n|s",
	["def_n_sg"] = "def|n|s",
	["ind_pl"] = "indef|p",
	["def_pl"] = "def|p",
	-- suffixes for participles that only have indefinite forms (i.e. imperfect participle)
	-- ("pl" already handled above)
	["m_sg"] = "m|s",
	["f_sg"] = "f|s",
	["n_sg"] = "n|s",
	-- additional verbal noun suffixes
	["ind_sg"] = "indef|s",
	["def_sg"] = "def|s",
}


local function slot_to_accel_form(slot)
	local prefix, suffix = rmatch(slot, "^([a-z]+)_(.*)$")
	if not prefix then
		return prefix_to_accel_form[slot]
	end
	return suffix_to_accel_form[suffix] .. "|" .. prefix_to_accel_form[prefix]
end


local verb_notr_slots = {
	"paap_ind_m_sg", "paap_ind_f_sg", "paap_ind_n_sg", "paap_ind_pl",
	"paip_m_sg", "paip_f_sg", "paip_n_sg", "paip_pl",
}


local base_slots = {
	"prap", -- masculine indefinite singular present active participle
	"paap", -- masculine indefinite singular past active aorist participle
	"paap_pl", -- masculine indefinite plural past active aorist participle
	"paip", -- masculine indefinite singular past active imperfect participle
	"advp", -- adverbial participle
	"pres", -- present 1sg
	"pres2", -- present 2sg
	"impf", -- imperfect 1sg
	"impf2", -- imperfect 2sg
	"aor", -- aorist 1sg
	"aor2", -- aorist 2sg
	"impv", -- imperative singular
	"vn", -- verbal noun
}


-- Used to determine if a perfective verb is prefixed; such verbs can't have
-- a stress-shifted aorist. This will have false positives; such verbs should
-- be indicated using (-pref).
local prefixes = {
	"^[дп]о", -- also catches под-
	"^[зн]а", -- also catches над-
	"^из",
	"^о" .. com.non_vowel_c, -- also catches об-, от-
	"^пр[еио]", -- also catches пред-
	"^раз",
	"^[вс][^аеиоуяю]", -- also catches въ-, съ–
	"^у",
}


local function verb_may_be_prefixed(lemma)
	for _, prefix in ipairs(prefixes) do
		if rfind(lemma, prefix) then
			return true
		end
	end
	return false
end


local function map_forms(forms, fn, first_only)
	if forms == nil then
		return nil
	elseif type(forms) == "string" then
		return forms == "?" and "?" or fn(forms)
	elseif forms.form then
		return {form = forms.form == "?" and "?" or fn(forms.form), footnotes = forms.footnotes}
	else
		local retval = {}
		for i, form in ipairs(forms) do
			if first_only then
				return map_forms(form, fn)
			end
			table.insert(retval, map_forms(form, fn))
		end
		return retval
	end
end


local function map_append(forms, suffix)
	return map_forms(forms, function(form) return form .. suffix end)
end


local function map_rsub(forms, from, to)
	return map_forms(forms, function(form) return rsub(form, from, to) end)
end


local function conjugate_all(base)
	local function combine_stem_ending(stem, ending)
		if stem == "?" then
			return "?"
		else
			return stem .. ending
		end
	end

	local function add(slot, stems, ending)
		if stems == nil then
			return
		end
		if type(stems) == "string" then
			com.insert_form(base.forms, slot, {form = combine_stem_ending(stems, ending)})
		else
			if stems.form then
				stems = {stems}
			end
			for _, stem in ipairs(stems) do
				if type(stem) == "string" then
					stem = {form = stem}
				end
				com.insert_form(base.forms, slot, {form = combine_stem_ending(stem.form, ending), footnotes = stem.footnotes})
			end
		end
	end

	local function conjugate_participle(baseslot, msg, fsg, nsg, pl)
		add(baseslot .. "_ind_m_sg", msg, "")
		add(baseslot .. "_def_sub_m_sg", pl, "ят")
		add(baseslot .. "_def_obj_m_sg", pl, "я")
		add(baseslot .. "_ind_f_sg", fsg, "")
		add(baseslot .. "_def_f_sg", fsg, "та")
		add(baseslot .. "_ind_n_sg", nsg, "")
		add(baseslot .. "_def_n_sg", nsg, "то")
		add(baseslot .. "_ind_pl", pl, "")
		add(baseslot .. "_def_pl", pl, "те")
	end

	local function conjugate_aor_impf(baseslot, stem, stem23)
		add(baseslot .. "_1sg", stem, "")
		add(baseslot .. "_2sg", stem23, "")
		add(baseslot .. "_3sg", stem23, "")
		add(baseslot .. "_1pl", stem, "ме")
		add(baseslot .. "_2pl", stem, "те")
		add(baseslot .. "_3pl", stem, "а")
	end

	if base.aspect ~= "pf" then
		conjugate_participle("prap", base.prap, map_append(base.prap, "а"),
			map_append(base.prap, "о"), map_append(base.prap, "и"))
	end
	conjugate_participle("paap", base.paap, base.paapf, base.paapn, base.paappl)
	if base.trans == "tr" then
		conjugate_participle("ppp", base.ppp, map_append(base.ppp, "а"), map_append(base.ppp, "о"),
			base.ppppl)
	end
	add("paip_m_sg", base.paip, "")
	add("paip_f_sg", base.paipf, "")
	add("paip_n_sg", base.paipn, "")
	add("paip_pl", base.paippl, "")
	if base.aspect ~= "pf" then
		add("vn_ind_sg", base.vn, "")
		add("vn_def_sg", base.vn, "то")
		-- Some verbal nouns are ending-stressed, but the plural in -ия pushes
		-- the stress onto the stem.
		add("vn_ind_pl", map_forms(base.vn, function(form)
			return com.maybe_stress_final_syllable(rsub(form, "е́?$", ""))
		end), "ия")
		add("vn_def_pl", map_forms(base.vn, function(form)
			return com.maybe_stress_final_syllable(rsub(form, "е́?$", ""))
		end), "ията")
		add("vn_ind_pl", base.vn, "та")
		add("vn_def_pl", base.vn, "тата")
	end
	add("pres_1sg", base.pres1sg, "")
	add("pres_2sg", base.pres2sg, "")
	add("pres_3sg", base.pres3sg, "")
	add("pres_1pl", base.pres1pl, "")
	add("pres_2pl", base.pres2pl, "")
	add("pres_3pl", base.pres3pl, "")
	conjugate_aor_impf("aor", base.aor, base.aor23)
	conjugate_aor_impf("impf", base.impf, base.impf23)
	add("impv_sg", base.impv, "")
	add("impv_pl", base.impvpl, "")
	if base.aspect ~= "pf" then
		add("advp", base.advp, "")
	end
end


local function add_reflexive_suffix(base)
	for _, slot in ipairs(verb_slots) do
		if not rfind(slot, "^vn_") then
			base.forms[slot] = com.map_forms(base.forms[slot], function(form)
				return form .. " " .. base.refl
			end)
		end
	end
end


local function remove_non_impersonal_forms(base)
	for _, slot in ipairs(verb_slots) do
		if not impers_verb_slots[slot] then
			base.forms[slot] = nil
		end
	end
end


local function add_categories(base)
	base.categories = {}
	if base.aspect == "impf" then
		table.insert(base.categories, "Bulgarian imperfective verbs")
	elseif base.aspect == "pf" then
		table.insert(base.categories, "Bulgarian perfective verbs")
	else
		assert(base.aspect == "both")
		table.insert(base.categories, "Bulgarian imperfective verbs")
		table.insert(base.categories, "Bulgarian perfective verbs")
		table.insert(base.categories, "Bulgarian biaspectual verbs")
	end
	if base.trans == "tr" then
		table.insert(base.categories, "Bulgarian transitive verbs")
	elseif base.trans == "intr" then
		table.insert(base.categories, "Bulgarian intransitive verbs")
	end
	if base.refl then
		table.insert(base.categories, "Bulgarian reflexive verbs")
	end
	if base.irreg or base.conj == "irreg" then
		table.insert(base.categories, "Bulgarian irregular verbs")
	end
	if base.conj ~= "irreg" then
		table.insert(base.categories, "Bulgarian conjugation " .. base.conj .. " verbs")
	end
end


local function pres_advp_1conj(base, lemma)
	local stem, last_letter, accent = rmatch(lemma, "^(.*)(.)[ая](́?)$")
	if not stem then
		error("Unrecognized lemma for conjugation 1: '" .. lemma .. "'")
	end
	local last_letter_pal = com.first_palatalization[last_letter] or last_letter
	base.pres3sg = stem .. last_letter_pal .. "е" .. accent
	-- defaults to 1sg + т, but set it explicitly in case we're called
	-- from ям, дам, знам, with irregular 1sg
	base.pres3pl = lemma .. "т"
	base.advp = base.pres3sg .. "йки"
end


local function pres_advp_2conj(base, lemma)
	local stem, accent = rmatch(lemma, "^(.*)[ая](́?)$")
	if not stem then
		error("Unrecognized lemma for conjugation 2: '" .. lemma .. "'")
	end
	base.pres3sg = stem .. "и" .. accent
	base.advp = stem .. "е" .. accent .. "йки"
end


local function impf_12conj(base, lemma)
	local stem, last_letter, accent = rmatch(lemma, "^(.*)(.)[ая](́?)$")
	if not stem then
		error("Unrecognized lemma for conjugation 1 or 2: '" .. lemma .. "'")
	end
	local last_letter_pal = com.first_palatalization[last_letter] or last_letter
	local full_stem = stem .. last_letter_pal
	base.impf23 = full_stem .. "е" .. accent .. "ше"
	if accent == AC then
		if rfind(last_letter_pal, "[жчш]") then
			base.impf = {full_stem .. "а́х", {form = full_stem .. "е́х", footnotes = {"[largely fallen into disuse]"}}}
		else
			base.impf = full_stem .. "я́х"
			-- This is the only case where the imperfect participle's vowel
			-- disagrees with the imperfect 1sg vowel, since it's a yat vowel
			-- followed by a front vowel. In other cases, postprocess_base()
			-- will automatically generate the imperfect participle bases based
			-- on the imperfect 1sg.
			base.paippl = full_stem .. "е́ли"
		end
	else
		base.impf = full_stem .. "ех"
	end
end


local function generate_maybe_shifted_aorist(base, aor23, shifted_aor23)
	if base.aspect ~= "pf" or not base.prefixed then
		shifted_aor23 = shifted_aor23 or rsub(aor23, AC, "") .. AC
		if aor23 ~= shifted_aor23 then
			base.aor23 = {aor23, {form = shifted_aor23, footnotes = {"[dialectally marked]"}}}
		else
			base.aor23 = aor23
		end
	else
		base.aor23 = aor23
	end
end


local function impv_12conj(base, lemma)
	local stem, last_letter = rmatch(lemma, "^(.-)(.)́?[ая]́?$")
	if not stem then
		error("Unrecognized lemma for conjugation 1 or 2: '" .. lemma .. "'")
	end
	last_letter = com.first_palatalization[last_letter] or last_letter
	local full_stem = stem .. last_letter
	if rfind(last_letter, com.vowel_c) then
		base.impv = com.maybe_stress_final_syllable(full_stem) .. "й"
	else
		full_stem = rsub(full_stem, AC, "") 
		base.impv = full_stem .. "и́"
		base.impvpl = full_stem .. "е́те"
	end
end


local function impf_impv_12conj(base, lemma)
	impf_12conj(base, lemma)
	impv_12conj(base, lemma)
end


local conjs = {}


conjs["1.1"] = function(base, lemma)
	pres_advp_1conj(base, lemma)
	impf_impv_12conj(base, lemma)

	local stem, last_letter = rmatch(lemma, "^(.*)(.)а́?$")
	if not stem then
		error("Unrecognized lemma for class 1.1: '" .. lemma .. "'")
	end
	stem = com.maybe_stress_final_syllable(stem)

	-- Generate aorist stems (and various other stems for вля́за).
	local last_letter_pal = com.first_palatalization[last_letter] or last_letter
	if rfind(lemma, "ля́за$") then
		local full_stem = stem .. last_letter
		local unyat_stem = rsub(full_stem, "ля́з$", "ле́з")
		base.aor = full_stem .. "ох"
		base.aor23 = unyat_stem .. "е"
		base.impf = unyat_stem .. "ех"
		base.impf23 = unyat_stem .. "еше"
		base.pres3sg = unyat_stem .. "е"
		base.impv = unyat_stem
		base.irreg = true
	elseif rfind(lemma, "[бв]лека́$") or rfind(lemma, "сека́$") then
		base.aor = rsub(stem, "^(.*)е", "%1я") .. last_letter .. "ох"
		base.aor23 = stem .. last_letter_pal .. "е"
	else
		base.aor = stem .. last_letter .. "ох"
		base.aor23 = stem .. last_letter_pal .. "е"
	end

	-- Generate aorist participle stems.
	if rfind(lemma, "раста́$") then
		base.paap = stem .. "ъл"
		base.paapf = stem .. "ла"
		base.irreg = true
	elseif last_letter == "д" or last_letter == "т" then
		base.paap = stem .. "л"
	else
		local full_stem = rsub(base.aor, "ох$", "")
		base.paap = full_stem .. "ъл"
		base.paapf = full_stem .. "ла"
		base.paappl = rsub(full_stem, "я", "е") .. "ли"
	end

	-- Generate past passive participle stems.
	base.ppp = stem .. last_letter_pal .. "ен"

	-- Generate verbal noun stems.
	base.vna = base.aor23 .. "не"
end


conjs["1.2"] = function(base, lemma)
	pres_advp_1conj(base, lemma)
	impf_impv_12conj(base, lemma)

	if not rfind(lemma, "а́?$") then
		error("Unrecognized lemma for class 1.2: '" .. lemma .. "'")
	end

	-- Generate aorist stems.
	local aor23
	if rfind(lemma, "ера́$") then
		-- бера́, дера́, пера́ and derivatives
		aor23 = rsub(lemma, "ера́$", "ра́")
	elseif rfind(lemma, "греба́$") then
		aor23 = rsub(lemma, "греба́$", "гре́ба")
		base.irreg = true
	elseif rfind(lemma, "гриза́$") then
		aor23 = rsub(lemma, "гриза́$", "гри́за")
		base.irreg = true
	elseif rfind(lemma, "я́") then
		-- дя́на (Chitanka type 153tt)
		-- бя́лна се, дя́лна, избя́гна, мля́сна, мя́рна, отбя́гна, пробя́гна, ря́зна (Chitanka type 152att)
		-- забя́гна, кря́кна, кря́сна, побя́гна, прибя́гна, убя́гна (Chitanka type 152ait)
 		local unyat_stem = rsub(lemma, "я́(.*)а$", "е́%1")
		local unstressed_unyat_stem = rsub(unyat_stem, "е́", "е")
		local shifted_aor23 = unstressed_unyat_stem .. "а́"
		generate_maybe_shifted_aorist(base, lemma, shifted_aor23)
		base.impf = unyat_stem .. "ех"
		base.impf23 = unyat_stem .. "еше"
		base.pres3sg = unyat_stem .. "е"
		base.impv = unstressed_unyat_stem .. "и́"
		base.impvpl = unstressed_unyat_stem .. "е́те"
		base.irreg = true
	else
		generate_maybe_shifted_aorist(base, lemma)
	end
	if aor23 then
		base.aor23 = aor23
	end

	-- Generate past passive participle stems.
	base.ppp = aor23 and aor23 .. "н" or rfind(lemma, "на́?$") and lemma .. "т" or lemma .. "н"

	-- Generate verbal noun stems.
	if rfind(lemma, "на́?$") then
		base.vna = false
	elseif rfind(lemma, "ера́$") then
		base.vna = rsub(lemma, "ера́$", "ране́")
		base.vni = false
	end
end


conjs["1.3"] = function(base, lemma)
	pres_advp_1conj(base, lemma)
	impf_impv_12conj(base, lemma)

	if not rfind(lemma, "я́?$") then
		error("Unrecognized lemma for class 1.3: '" .. lemma .. "'")
	end

	-- Generate aorist stems.
	local aor23
	if rfind(lemma, "дре́мя$") then
		aor23 = rsub(lemma, "дре́мя$", "дря́ма")
		local shifted_aor23 = rsub(lemma, "дре́мя$", "дрема́")
		generate_maybe_shifted_aorist(base, aor23, shifted_aor23)
		base.irreg = true
	else
		aor23 = rsub(lemma, "^(.*)я", "%1а")
		generate_maybe_shifted_aorist(base, rsub(lemma, "^(.*)я", "%1а"))
	end

	-- Generate past passive participle stems.
	base.ppp = aor23 .. "н"
end


conjs["1.4"] = function(base, lemma)
	pres_advp_1conj(base, lemma)
	impf_impv_12conj(base, lemma)

	-- Generate aorist stems.
	local aor23
	local skip_generate_aorist = false
	if rfind(lemma, "лъ́жа$") or rfind(lemma, "стри́жа$") or rfind(lemma, "стъ́ржа$") then
		aor23 = rsub(lemma, "жа$", "га")
	elseif rfind(lemma, "ре́жа$") then
		aor23 = rsub(lemma, "ре́жа$", "ря́за")
		local shifted_aor23 = rsub(lemma, "ре́жа", "реза́")
		generate_maybe_shifted_aorist(base, aor23, shifted_aor23)
		skip_generate_aorist = true
		base.irreg = true
	elseif rfind(lemma, "жа$") then
		aor23 = rsub(lemma, "жа$", "за")
	elseif rfind(lemma, "ча$") then
		aor23 = rsub(lemma, "ча$", "ка")
	elseif rfind(lemma, "ша$") then
		aor23 = rsub(lemma, "ша$", "са")
	elseif rfind(lemma, "ща$") then -- тра́ща
		aor23 = rsub(lemma, "ща$", "та")
	else
		error("Unrecognized lemma for class 1.4: '" .. lemma .. "'")
	end
	if not skip_generate_aorist then
		generate_maybe_shifted_aorist(base, aor23)
	end

	-- Generate past passive participle stems.
	base.ppp = aor23 .. "н"
end


conjs["1.5"] = function(base, lemma)
	pres_advp_1conj(base, lemma)
	impf_impv_12conj(base, lemma)

	if not rfind(lemma, "[рщ]а́$") then
		error("Unrecognized lemma for class 1.5: '" .. lemma .. "'")
	end

	-- Generate aorist stems.
	base.aor23 = rsub(lemma, "а́$", "я́")
	base.paappl = rsub(lemma, "а́$", "е́ли")

	-- Generate past passive participle stems.
	base.ppp = base.aor23 .. "н"
	base.ppppl = rsub(base.aor23, "я́$", "е́") .. "ни"
end


conjs["1.6"] = function(base, lemma)
	pres_advp_1conj(base, lemma)
	impf_impv_12conj(base, lemma)

	if not rfind(lemma, "[аяе]́я$") then
		error("Unrecognized lemma for class 1.6: '" .. lemma .. "'")
	end

	-- Generate aorist stems.
	generate_maybe_shifted_aorist(base, lemma)

	-- Generate past passive participle stems.
	if rfind(lemma, "зна́я$") then
		base.ppp = rsub(lemma, "я$", "ен")
		base.irreg = true
	else
		base.ppp = lemma .. "н"
	end
end


conjs["1.7"] = function(base, lemma)
	pres_advp_1conj(base, lemma)
	impf_impv_12conj(base, lemma)

	local ppp_endings
	if base.ppp_ending == "т" then
		ppp_endings = "т"
	elseif base.ppp_ending == "тн" then
		ppp_endings = {"т", "н"}
	elseif base.ppp_ending == "нт" then
		ppp_endings = {"н", "т"}
	else
		ppp_endings = "н"
	end

	-- Generate aorist and past passive participle stems.
	if rfind(lemma, "ма$") then
		base.aor23 = rsub(lemma, "ма$", "")
		base.ppp = base.aor23 .. "т"
	elseif rfind(lemma, "[жчш]е́я$") then
		base.aor23 = rsub(lemma, "е́я$", "а́")
		base.ppp = map_forms(ppp_endings, function(ending) return base.aor23 .. ending end) 
	elseif rfind(lemma, "е́я$") then
		base.aor23 = rsub(lemma, "е́я$", "я́")
		local yat_plural_stem = rsub(lemma, "е́я$", "е́")
		base.paappl = yat_plural_stem .. "ли"
		base.ppp = map_forms(ppp_endings, function(ending) return base.aor23 .. ending end) 
		base.ppppl = map_forms(ppp_endings, function(ending) return yat_plural_stem .. ending .. "и" end) 
	elseif rfind(lemma, "[аяиую]́я$") then
		-- For verbs in -я́я (влия́я, сия́я), this results in an aorist participle
		-- in -я́л, but per rechnik.chitanka.info it stays as -я́ли in the plural,
		-- not **-е́ли.
		base.aor23 = rsub(lemma, "я$", "")
		if rfind(lemma, "[иую]́я$") then
			base.ppp = base.aor23 .. "т"
		else
			base.ppp = map_forms(ppp_endings, function(ending) return base.aor23 .. ending end)
		end
	else
		error("Unrecognized lemma for class 1.7: '" .. lemma .. "'")
	end

	-- Generate verbal noun stems.
	if rfind(lemma, "[еиую]́я$") then
		base.vna = false
	end
end


conjs["2.1"] = function(base, lemma)
	pres_advp_2conj(base, lemma)
	impf_impv_12conj(base, lemma)

	-- Generate aorist stems.
	generate_maybe_shifted_aorist(base, rsub(lemma, "^(.*)[ая]", "%1и"))

	-- Generate past passive participle stems.
	base.ppp = rsub(lemma, "^(.*)[ая](́?)$", "%1е%2н")

	-- Generate verbal noun stems.
	base.vna = base.ppp .. "е"
	base.vni = false
end


conjs["2.2"] = function(base, lemma)
	pres_advp_2conj(base, lemma)
	impf_impv_12conj(base, lemma)

	if not rfind(lemma, "я́$") then
		error("Unrecognized lemma for class 2.2: '" .. lemma .. "'")
	end

	-- Generate aorist stems.
	base.aor23 = lemma
	local oya = rfind(lemma, "оя́$") -- стоя́, боя́ се
	local yat_plural_stem = oya and lemma or rsub(lemma, "я́$", "е́")
	base.paappl = yat_plural_stem .. "ли"

	if oya then
		-- стоя has both стоя́не and стое́не as verbal nouns
		base.vna = lemma .. "не"
		base.paippl = lemma .. "ли"
		base.irreg = true
	end
	
	-- Generate past passive participle stems.
	base.ppp = base.aor23 .. "н"
	base.ppppl = yat_plural_stem .. "ни"
end


conjs["2.3"] = function(base, lemma)
	pres_advp_2conj(base, lemma)
	impf_impv_12conj(base, lemma)

	if not rfind(lemma, "[жчш]а́$") then
		error("Unrecognized lemma for class 2.3: '" .. lemma .. "'")
	end

	-- Generate aorist stems.
	base.aor23 = lemma

	-- Generate past passive participle stems.
	base.ppp = base.aor23 .. "н"

	-- Handle irregularities
	if rfind(lemma, "държа́$") then
		base.impv = rsub(lemma, "държа́$", "дръ́ж")
		base.irreg = true
	end
end


conjs["3"] = function(base, lemma)
	local stem = rmatch(lemma, "^(.*[ая])м$")
	if not stem then
		error("Unrecognized lemma for conjugation 3: '" .. lemma .. "'")
	end

	-- Generate present stems.
	base.pres3sg = stem
	base.pres1pl = stem .. "ме"
	base.pres3pl = stem .. "т"

	-- Generate imperfect stems.
	base.impf = stem .. "х"
	base.impf23 = stem .. "ше"

	-- Generate aorist stems.
	generate_maybe_shifted_aorist(base, stem)

	-- Generate imperative stems.
	base.impv = stem .. "й"

	-- Generate past passive participle stems.
	base.ppp = stem .. "н"

	-- Generate adverbial participle.
	base.advp = stem .. "йки"
end


conjs["irreg"] = function(base, lemma)
	base.irreg = true
	if rfind(lemma, "я́м$") then
		conjs["1.1"](base, rsub(lemma, "я́м$", "яда́"))
		base.vni = false
		base.impv = rsub(lemma, "м$", "ж")
		base.conj = "1.1"
	elseif rfind(lemma, "съ́м$") then
		local stem = rmatch(lemma, "^(.*)съ́м$")
		base.pres2sg = stem .. "си́"
		base.pres3sg = stem .. "е́"
		base.pres1pl = stem .. "сме́"
		base.pres2pl = stem .. "сте́"
		base.pres3pl = stem .. "са́"
		base.aor = stem .. "бя́х"
		base.aor23 = {stem .. "бе́", stem .. "бе́ше"}
		base.impf = stem .. "бя́х"
		base.impf23 = stem .. "бе́ше"
		base.prap = false
		base.paap = stem .. "би́л"
		base.paapf = stem .. "била́"
		base.paip = stem .. "би́л"
		base.paipf = stem .. "била́"
		base.advp = {stem .. "бъ́дейки", stem .. "би́дейки"}
		base.impv = "бъди́"
		base.impvpl = "бъде́те"
		base.vna = false
		base.vni = false
	elseif rfind(lemma, "бъ́да$") then
		local stem = rmatch(lemma, "^(.*)бъ́да$")
		base.pres3sg = stem .. "бъ́де"
		base.aor = {stem .. "би́х", stem .. "би́дох"}
		base.aor23 = {stem .. "би́", stem .. "би́де"}
		base.impf = {stem .. "бъ́дех", stem .. "бя́х"}
		base.impf23 = {stem .. "бъ́деше", stem .. "бе́ше"}
		base.prap = stem .. "бъ́дещ"
		base.paap = stem .. "би́л"
		base.paapf = stem .. "била́"
		base.paip = stem .. "бъ́дел"
		base.advp = {stem .. "бъ́дейки", stem .. "би́дейки"}
		base.impv = "бъди́"
		base.impvpl = "бъде́те"
		base.vna = false
		base.vni = false
	elseif rfind(lemma, "ща́") then
		local stem = rmatch(lemma, "^(.*)ща́$")
		base.pres3sg = stem .. "ще́"
		base.aor = stem .. "щя́х"
		base.aor23 = {stem .. "щя́", stem .. "ще́ше"}
		base.impf = stem .. "щя́х"
		base.impf23 = stem .. "ще́ше"
		base.prap = false
		base.paap = stem .. "щя́л"
		base.paappl = stem .. "ще́ли"
		base.paip = stem .. "щя́л"
		base.paippl = stem .. "ще́ли"
		base.vna = false
		base.vni = false
	elseif rfind(lemma, "зна́м$") then
		conjs["1.6"](base, rsub(lemma, "а́м$", "а́я"))
		base.conj = "1.6"
	elseif rfind(lemma, "да́м$") then
		conjs["1.1"](base, rsub(lemma, "да́м$", "дада́"))
		base.impv = rsub(lemma, "м$", "й")
		base.conj = "1.1"
	elseif rfind(lemma, "йда$") then -- до́йда, за́йда, подо́йда, придо́йда
		pres_advp_1conj(base, lemma)
		impf_impv_12conj(base, lemma)
		base.aor = rsub(lemma, AC .. "йда$", "йдо́х")
		base.aor23 = rsub(lemma, AC .. "йда$", "йде́")
		base.paap = rsub(lemma, AC .. "йда$", "шъ́л")
		base.paapf = rsub(lemma, AC .. "йда$", "шла́")
		if lemma == "до́йда" then
			base.impv = "ела́"
			base.impvpl = base.impv .. "те"
		end
		-- no past passive participle
		base.vna = false
		base.conj = "1.1"
	elseif rfind(lemma, "и́да$") then -- и́да, оти́да, пооти́да, разоти́да
		pres_advp_1conj(base, lemma)
		impf_impv_12conj(base, lemma)
		if lemma ~= "и́да" then
			-- base verb и́да doesn't have aorist or aorist participle forms
			base.aor = rsub(lemma, "да$", "дох")
			base.aor23 = rsub(lemma, "да$", "де")
			base.paap = {rsub(lemma, "да$", "шъл"), rsub(lemma, "и́да$", "ишъ́л"),
				{form=rsub(lemma, "да$", "шел"), footnotes={"[dialectal]"}}}
			base.paapf = {rsub(lemma, "да$", "шла"), rsub(lemma, "и́да$", "ишла́")}
		end
		-- no past passive participle, no verbal noun
		base.vna = false
		base.vni = false
		base.conj = "1.1"
	elseif rfind(lemma, "мо́га$") then
		pres_advp_1conj(base, lemma)
		impf_12conj(base, lemma)
		-- no imperative
		base.aor23 = rsub(lemma, "мо́га$", "можа́")
		local reg_aor23 = rsub(lemma, "мо́га$", "можа́л")
		base.paap = {rsub(lemma, "мо́га$", "могъ́л"), reg_aor23}
		base.paapf = {rsub(lemma, "мо́га$", "могла́"), reg_aor23 .. "а"}
		-- no past passive participle
		base.vna = false
	elseif rfind(lemma, "спя́$") then
		pres_advp_2conj(base, lemma)
		impf_impv_12conj(base, lemma)
		base.aor23 = rsub(lemma, "я́$", "а́")
		-- no past passive participle
		base.vna = rsub(lemma, "я́$", "ане́")
		base.vni = false
	elseif rfind(lemma, "ме́ля$") then
		local stem = rmatch(lemma, "^(.*)я$")
		base.pres3sg = {stem .. "е", stem .. "и"}
		base.advp = stem .. "ейки"
		impf_impv_12conj(base, lemma)
		base.aor23 = rsub(lemma, "е́ля$", "ля́")
		local yat_plural_stem = rsub(lemma, "е́ля$", "ле́")
		base.paappl = yat_plural_stem .. "ли"
		base.ppp = base.aor23 .. "н"
		base.ppppl = yat_plural_stem .. "ни"
		base.vna = false
		-- prefixed variants are perfective and don't have verbal nouns
		base.vni = {"ме́лене", {form="мле́не", footnotes={"[colloquial]"}}, {form="млене́", footnotes={"[colloquial]"}}}
	elseif rfind(lemma, "ко́ля$") then
		pres_advp_2conj(base, lemma)
		impf_impv_12conj(base, lemma)
		base.aor23 = {rsub(lemma, "о́ля$", "ла́"), rsub(lemma, "я$", "и")}
		base.ppp = {rsub(lemma, "о́ля$", "ла́н"), rsub(lemma, "я$", "ен")}
		base.vna = false
		-- prefixed variants are perfective and don't have verbal nouns
		base.vni = {"ко́лене", "клане́"}
	elseif rfind(lemma, "ви́дя$") then
		pres_advp_2conj(base, lemma)
		impf_impv_12conj(base, lemma)
		base.aor23 = rsub(lemma, "ви́дя$", "видя́")
		local yat_plural_stem = rsub(base.aor23, "я́$", "е́")
		base.paappl = yat_plural_stem .. "ли"
		-- Generate past passive participle stems.
		base.ppp = base.aor23 .. "н"
		base.ppppl = yat_plural_stem .. "ни"
		-- Generate imperative forms.
		base.impv = rsub(lemma, "ви́дя$", "ви́ж")
		-- perfective; no verbal noun
		base.vna = false
		base.vni = false
		base.conj = "2.2"
	elseif rfind(lemma, "кълна́$") then
		pres_advp_1conj(base, lemma)
		impf_impv_12conj(base, lemma)
		base.aor23 = {rsub(lemma, "кълна́$", "кле́"), lemma}
		base.ppp = {rsub(lemma, "кълна́$", "кле́т"), lemma .. "т"}
		base.vna = false
		base.conj = "1.2"
	elseif rfind(lemma, "сте́ля$") then
		pres_advp_1conj(base, lemma)
		impf_impv_12conj(base, lemma)
		base.aor23 = rsub(lemma, "сте́ля$", "стла́")
		base.ppp = base.aor23 .. "н"
		base.vna = false
		base.conj = "1.3"
	elseif rfind(lemma, "беле́жа$") then
		pres_advp_2conj(base, lemma)
		impf_impv_12conj(base, lemma)
		base.aor23 = rsub(lemma, "ле́жа$", "ля́за")
		base.ppp = rsub(lemma, "ле́жа$", "ля́зан")
		base.vna = false
	else
		error("Irregular verb '" .. lemma .. "' not yet supported")
	end
end


local function postprocess_base(base, lemma)
	if not base.pres1sg then
		base.pres1sg = lemma
	end
	if not base.pres2sg then
		base.pres2sg = map_append(base.pres3sg, "ш")
	end
	if not base.pres1pl then
		base.pres1pl = map_append(base.pres3sg, "м")
	end
	if not base.pres2pl then
		base.pres2pl = map_append(base.pres3sg, "те")
	end
	if not base.pres3pl then
		base.pres3pl = map_append(base.pres1sg, "т")
	end
	if not base.aor then
		base.aor = map_append(base.aor23, "х")
	end
	if base.prap == false then
		base.prap = nil
	elseif not base.prap then
		base.prap = map_rsub(base.impf, "х$", "щ")
	end
	if not base.paap then
		base.paap = map_rsub(base.aor, "х$", "л")
	end
	if not base.paapf then
		base.paapf = map_append(base.paap, "а")
	end
	if not base.paapn then
		base.paapn = map_rsub(base.paapf, "а(́?)$", "о%1")
	end
	if not base.paappl then
		base.paappl = map_rsub(base.paapf, "а(́?)$", "и%1")
	end
	if not base.paip then
		base.paip = map_rsub(base.impf, "х$", "л")
	end
	if not base.paipf then
		base.paipf = map_append(base.paip, "а")
	end
	if not base.paipn then
		base.paipn = map_rsub(base.paipf, "а(́?)$", "о%1")
	end
	if not base.paippl then
		base.paippl = map_rsub(base.paipf, "а(́?)$", "и%1")
	end
	if not base.ppppl then
		base.ppppl = map_append(base.ppp, "и")
	end
	if not base.impvpl then
		base.impvpl = map_append(base.impv, "те")
	end
	local function aor_to_vn(form)
		form = rsub(form, "я́х$", "е́не")
		form = rsub(form, "х$", "не")
		return form
	end
	local function impf_to_vn(form)
		form = rsub(form, "[ая]́х$", "е́не")
		form = rsub(form, "х$", "не")
		return form
	end
	if base.vna == nil then
		base.vna = map_forms(base.aor, aor_to_vn, "first only")
	end
	if base.vni == nil then
		base.vni = map_forms(base.impf, impf_to_vn, "first only")
	end
	if base.vna == false and base.vni == false then
		base.vn = nil
	elseif base.vna == false then
		base.vn = base.vni
	elseif base.vni == false then
		base.vn = base.vna
	elseif base.vna == base.vni then
		base.vn = base.vna
	elseif base.aspect == "pf" then
		-- No verbal noun.
		base.vn = nil
	elseif base.vnspec == "a" then
		base.vn = base.vna
	elseif base.vnspec == "i" then
		base.vn = base.vni
	elseif base.vnspec == "ai" then
		base.vn = {base.vna, base.vni}
	elseif base.vnspec == "ia" then
		base.vn = {base.vni, base.vna}
	elseif base.vnspec == "?" then
		base.vn = "?"
	else
		error("Imperfective/biaspectual verb '" .. base.full_lemma .. "' has two possible verbal nouns, don't know which one to choose; specify 'vna' for " .. base.vna .. ", 'vni' for " .. base.vni .. ", or 'vnai' or 'vnia' for both")
	end
end


local function parse_indicator_and_form_spec(angle_bracket_spec)
	local inside = rmatch(angle_bracket_spec, "^<(.*)>$")
	assert(inside)
	local base = {}
	local parts = rsplit(inside, ".", true)
	local conj
	local start = 1
	if parts[1] == "irreg" then
		conj = "irreg"
		start = 2
	elseif rfind(parts[1], "^[123]$") then
		conj = parts[1]
		start = 2
		if parts[2] and rfind(parts[2], "^[1-7]$") then
			conj = conj .. "." .. parts[2]
			start = 3
		end
	end
	base.conj = conj
	for i=start,#parts do
		local part = parts[i]
		if part == "impf" or part == "pf" or part == "both" then
			if base.aspect then
				error("Can't specify aspect twice: '" .. inside .. "'")
			end
			base.aspect = part
		elseif part == "tr" or part == "intr" then
			if base.trans then
				error("Can't specify transitivity twice: " .. inside .. "'")
			end
			base.trans = part
		elseif part == "т" or part == "тн" or part == "нт" then
			if base.ppp_ending then
				error("Can't specify past passive participle ending twice: " .. inside .. "'")
			end
			base.ppp_ending = part
		elseif part == "-pref" then
			if base.no_pref then
				error("Can't specify '-pref' twice: " .. inside .. "'")
			end
			base.no_pref = true
		elseif part == "vna" or part == "vni" or part == "vnai" or part == "vnia" or part == "vn?" then
			if base.vnspec then
				error("Can't specify verbal noun spec twice: " .. inside .. "'")
			end
			base.vnspec = rsub(part, "^vn", "")
		elseif part == "impers" then
			if base.impers then
				error("Can't specify 'impers' twice: " .. inside .. "'")
			end
			base.impers = true
		else
			error("Unrecognized indicator '" .. part .. "': '" .. inside .. "'")
		end
	end
	return base
end


-- Separate out reflexive suffix, check that multisyllabic lemmas have stress, and add stress
-- to monosyllabic lemmas if needed.
local function check_lemma_stress(base, lemma)
	local active_verb, refl = rmatch(lemma, "^(.*) (с[еи])$")
	if active_verb then
		base.refl = refl
		lemma = active_verb
	end
	lemma = com.add_monosyllabic_stress(lemma)
	if not rfind(lemma, AC) then
		error("Multisyllabic lemma '" .. lemma .. "' needs an accent")
	end
	if base.refl then
		base.full_lemma = lemma .. " " .. base.refl
	else
		base.full_lemma = lemma
	end
	return lemma
end


local function impersonal_to_personal_lemma(lemma, conj)
	local undo_first_palatalization = {
		["ч"] = "к",
		["ж"] = "г",
		["ш"] = "х",
	}

	local function mustsub(from, to)
		local newlemma = rsub(lemma, from, to)
		if newlemma == lemma then
			error("Unrecognized impersonal lemma for conjugation " .. conj .. ": " .. lemma)
		end
		return newlemma
	end

	local conj_is_2 = rfind(conj, "^2%.")
	if conj == "1.1" then
		return mustsub("(.)е(́?)$",
			function(last_cons, accent)
				return (undo_first_palatalization[last_cons] or last_cons) .. "а" .. accent
			end)
	elseif conj == "1.2" or conj == "1.4" or conj == "1.5" or (conj == "1.7" and rfind(lemma, "ме$")) then
		return mustsub("е(́?)$", "а%1")
	elseif conj == "1.3" or conj == "1.6" or conj == "1.7" then
		return mustsub("е(́?)$", "я%1")
	elseif (conj_is_2 and rfind(lemma, "[чжш]е$")) then
		return mustsub("и(́?)$", "а%1")
	elseif conj_is_2 then
		return mustsub("и(́?)$", "я%1")
	elseif rfind(conj, "^3") then
		return lemma .. "м"
	else
		error("Can't handle irregular impersonal verbs yet")
	end
end


local function detect_indicator_and_form_spec(base, lemma)
	if not base.aspect then
		error("Aspect of 'pf', 'impf' or 'both' must be specified")
	end
	if base.refl then
		if base.trans then
			error("Can't specify transitivity with reflexive verb, they're always intransitive: '" .. base.full_lemma .. "'")
		end
	elseif not base.trans then
		error("Transitivity of 'tr' or 'intr' must be specified")
	end
	local pers_ending = base.impers and "" or "м"
	if not base.conj then
		if rfind(lemma, "[ая]" .. pers_ending .. "$") then
			base.conj = "3"
		elseif base.impers then
			error("For lemma ending in -е or -и, conjugation must be specified: '" .. lemma .. "'")
		else
			error("For lemma ending in -а or -я, conjugation must be specified: '" .. lemma .. "'")
		end
	elseif base.conj == "3.1" then
		if not rfind(lemma, "а" .. pers_ending .. "$") then
			error("Conjugation 3.1 lemma must end in -а" .. pers_ending .. ": '" .. lemma .. "'")
		end
		base.conj = "3"
	elseif base.conj == "3.2" then
		if not rfind(lemma, "я" .. pers_ending .. "$") then
			error("Conjugation 3.2 lemma must end in -я" .. pers_ending .. ": '" .. lemma .. "'")
		end
		base.conj = "3"
	elseif not conjs[base.conj] then
		error("Unrecognized conjugation '" .. base.conj .. "' for lemma '" .. lemma .. "'")
	end
	base.orig_lemma = lemma
	if base.impers then
		lemma = impersonal_to_personal_lemma(lemma, base.conj)
	end
	base.prefixed = not base.no_pref and verb_may_be_prefixed(lemma)
	return lemma
end


local function parse_word_spec(text)
	local segments = com.parse_balanced_segment_run(text, "<", ">")
	if #segments ~= 3 or segments[3] ~= "" then
		error("Verb spec must be of the form 'LEMMA<CONJ.SPECS>': '" .. text .. "'")
	end
	local lemma = segments[1]
	local base = parse_indicator_and_form_spec(segments[2])
	return base, lemma
end


local function format_gender(g)
	return require("Module:gender and number").format_list({g})
end


local function show_forms(base, fullmod)
	local forms = base.forms
	local lemmas = {}
	for _, lemma in ipairs(forms.lemma) do
		table.insert(lemmas, com.remove_monosyllabic_stress(lemma))
	end
	local accel_lemma = lemmas[1]
	forms.lemma = table.concat(lemmas, ", ")

	local footnote_obj = com.init_footnote_obj()

	for _, notr_slot in ipairs(verb_notr_slots) do
		forms[notr_slot .. "_notr"] = com.display_one_form(footnote_obj, forms, notr_slot,
			nil, nil, false, "slash join")
	end
	com.display_forms(footnote_obj, forms, forms, verb_slots, "is list", accel_lemma, slot_to_accel_form)
	if fullmod then
		com.display_forms(footnote_obj, forms, forms, fullmod.verb_compound_slots, "is list", nil, nil)
	end
	forms.refl = base.refl or ""
	-- forms.along_with_refl = base.refl and "along with [[" .. base.refl .. "]]" or ""
	forms.along_with_refl = ""
	forms.gm = format_gender("m")
	forms.gf = format_gender("f")
	forms.gn = format_gender("n")
	forms.gp = format_gender("p")
	if base.footnote then
		table.insert(footnote_obj.notes, base.footnote)
	end
	forms.footnote = table.concat(footnote_obj.notes, "<br />")
end


local function make_table(base, fullmod)
	local forms = base.forms

	local ann_parts = {}
	if base.conj == "irreg" then
		table.insert(ann_parts, "irregular")
	else
		table.insert(ann_parts, "conjugation " .. base.conj)
		if base.irreg then
			table.insert(ann_parts, "irregular")
		end
	end
	table.insert(ann_parts,
		base.aspect == "impf" and "imperfective" or
		base.aspect == "pf" and "perfective" or
		"biaspectual")
	table.insert(ann_parts,
		base.trans == "tr" and "transitive" or
		base.trans == "intr" and "intransitive" or
		"reflexive")
	if base.impers then
		table.insert(ann_parts, "impersonal")
	end
	forms.annotation = " (" .. table.concat(ann_parts, ", ") .. ")"

	-- auxiliaries used in the table
	forms.nyama = link("ня́ма")
	forms.nyamashe = link("ня́маше")
	forms.nyamalo = link("ня́мало")
	forms.shte = link("ще")
	forms.shta = link("ща")
	forms.da = link("да")
	forms.bilo = link("било́")
	forms.sam = link("съм")
	forms.e = link("е")
	forms.bada = link("бъ́да")

	local aor_part_list_pers = [=[
	{paap_ind_m_sg_notr} {gm}, {paap_ind_f_sg_notr} {gf}, {paap_ind_n_sg_notr} {gn}, or {paap_ind_pl_notr} {gp}]=]
	local aor_part_list_impers = [=[
	{paap_ind_n_sg_notr}]=]
	local impf_part_list_pers = [=[
	{paip_m_sg_notr} {gm}, {paip_f_sg_notr} {gf}, {paip_n_sg_notr} {gn}, or {paip_pl_notr} {gp}]=]
	local impf_part_list_impers = [=[
	{paip_n_sg_notr}]=]

	local table_spec_non_compound = [=[
<div class="NavFrame">
<div class="NavHead" align=left>&nbsp; &nbsp; Conjugation of {lemma}{annotation}</div>
<div class="NavContent" align="center">

{\op}| style="background:#F0F0F0; font-size: 90%; width:100%; margin: 0 auto 0 auto; text-align:center;" class="inflection-table"
! colspan="2" style="width:10%; background:#e2e4c0;" | participles
! style="background:#e2e4c0" | present active participle
! style="background:#e2e4c0" | past active aorist participle
! style="background:#e2e4c0" | past active imperfect participle
! style="background:#e2e4c0" | past passive participle
! style="background:#e2e4c0" | verbal noun
! style="background:#e2e4c0" | adverbial participle
|-
! rowspan="3" style="background:#e2e4c0" | masculine
! style="background:#e2e4c0" | indefinite
|{prap_ind_m_sg}
|{paap_ind_m_sg}
|{paip_m_sg}
|{ppp_ind_m_sg}
| rowspan="5" |
| rowspan="9" |{advp}
|-
! style="background:#e2e4c0; white-space: nowrap;" | definite subject form
|{prap_def_sub_m_sg}
|{paap_def_sub_m_sg}
|—
|{ppp_def_sub_m_sg}
|-
! style="background:#e2e4c0; white-space: nowrap;" | definite object form
|{prap_def_obj_m_sg}
|{paap_def_obj_m_sg}
|—
|{ppp_def_obj_m_sg}
|-
! rowspan="2" style="background:#e2e4c0" | feminine
! style="background:#e2e4c0" | indefinite
|{prap_ind_f_sg}
|{paap_ind_f_sg}
|{paip_f_sg}
|{ppp_ind_f_sg}
|-
! style="background:#e2e4c0" | definite
|{prap_def_f_sg}
|{paap_def_f_sg}
|—
|{ppp_def_f_sg}
|-
! rowspan="2" style="background:#e2e4c0" | neuter
! style="background:#e2e4c0" | indefinite
|{prap_ind_n_sg}
|{paap_ind_n_sg}
|{paip_n_sg}
|{ppp_ind_n_sg}
|{vn_ind_sg}
|-
! style="background:#e2e4c0" | definite
|{prap_def_n_sg}
|{paap_def_n_sg}
|—
|{ppp_def_n_sg}
|{vn_def_sg}
|-
! rowspan="2" style="background:#e2e4c0" | plural
! style="background:#e2e4c0" | indefinite
|{prap_ind_pl}
|{paap_ind_pl}
|{paip_pl}
|{ppp_ind_pl}
|{vn_ind_pl}
|-
! style="background:#e2e4c0" | definite
|{prap_def_pl}
|{paap_def_pl}
|—
|{ppp_def_pl}
|{vn_def_pl}
|{\cl}
{\op}| style="background:#F0F0F0; font-size: 90%; width: 100%" class="inflection-table"
! colspan="{ncol}" rowspan="2" style="background:#C0C0C0" | person
! colspan="3" style="background:#C0C0C0" | singular
! colspan="3" style="background:#C0C0C0" | plural
|-
! style="background:#C0C0C0;width:12.5%" | first
! style="background:#C0C0C0;width:12.5%" | second
! style="background:#C0C0C0;width:12.5%" | third
! style="background:#C0C0C0;width:12.5%" | first
! style="background:#C0C0C0;width:12.5%" | second
! style="background:#C0C0C0;width:12.5%" | third
|-
! colspan="{ncol}" style="background:#c0cfe4" | indicative
! style="background:#c0cfe4" | аз
! style="background:#c0cfe4" | ти
! style="background:#c0cfe4" | той/тя/то
! style="background:#c0cfe4" | ние
! style="background:#c0cfe4" | вие
! style="background:#c0cfe4" | те
|-
! colspan="{ncol}" style="background:#c0cfe4" | present
| {pres_1sg}
| {pres_2sg}
| {pres_3sg}
| {pres_1pl}
| {pres_2pl}
| {pres_3pl}
|-
! colspan="{ncol}" style="background:#c0cfe4" | imperfect
| {impf_1sg}
| {impf_2sg}
| {impf_3sg}
| {impf_1pl}
| {impf_2pl}
| {impf_3pl}
|-
! colspan="{ncol}" style="background:#c0cfe4" | aorist
| {aor_1sg}
| {aor_2sg}
| {aor_3sg}
| {aor_1pl}
| {aor_2pl}
| {aor_3pl}
|-
]=]

	local table_spec_compound_short = [=[
! rowspan="2" style="background:#c0cfe4" | future
! style="background:#c0cfe4" | pos.
! colspan="6" style="background:#C0C0C0" | Use {shte} {refl} followed by the present indicative tense
|-
! style="background:#c0cfe4" | neg.
! colspan="6" style="background:#C0C0C0" | Use {nyama} {da} {refl} followed by the present indicative tense
|-
! rowspan= "2" style="background:#c0cfe4" | future in the past
! style="background:#c0cfe4" | pos.
! colspan="6" style="background:#C0C0C0" | Use the imperfect indicative tense of {shta} followed by {da} {refl} and the present indicative tense
|-
! style="background:#c0cfe4" | neg.
! colspan="6" style="background:#C0C0C0" | Use {nyamashe} {da} {refl} followed by the present indicative tense
|-
! colspan="2" style="background:#c0cfe4" | present perfect
! colspan="6" style="background:#C0C0C0" | Use the present indicative tense of {sam} {along_with_refl} and {aor_part_list}
|-
! colspan="2" style="background:#c0cfe4" | past perfect
! colspan="6" style="background:#C0C0C0" | Use the imperfect indicative tense of {sam} {along_with_refl} and {aor_part_list}
|-
! colspan="2" style="background:#c0cfe4" | future perfect
! colspan="6" style="background:#C0C0C0" | Use the future indicative tense of {sam} {along_with_refl} and {aor_part_list}
|-
! colspan="2" style="background:#c0cfe4" | future perfect in the past
! colspan="6" style="background:#C0C0C0" | Use the future in the past indicative tense of {sam} {along_with_refl} and {aor_part_list}
|-
! colspan="2" style="background:#c0e4c0" | renarrative
! style="background:#c0e4c0" | аз
! style="background:#c0e4c0" | ти
! style="background:#c0e4c0" | той/тя/то
! style="background:#c0e4c0" | ние
! style="background:#c0e4c0" | вие
! style="background:#c0e4c0" | те
|-
! colspan="2" style="background:#c0e4c0" | present and imperfect
! colspan="6" style="background:#C0C0C0; white-space: nowrap;" | Use the present indicative tense of {sam} (leave it out in third person) {along_with_refl} and {impf_part_list}
|-
! colspan="2" style="background:#c0e4c0" | aorist
! colspan="6" style="background:#C0C0C0" | Use the present indicative tense of {sam} (leave it out in third person) {along_with_refl} and {aor_part_list}
|-
! rowspan="2" style="background:#c0e4c0" | future and future in the past
! style="background:#c0e4c0" | pos.
! colspan="6" style="background:#C0C0C0" | Use the present/imperfect renarrative tense of {shta} followed by {da} {refl} and the present indicative tense
|-
! style="background:#c0e4c0" | neg.
! colspan="6" style="background:#C0C0C0" | Use {nyamalo} {da} {refl} and the present indicative tense
|-
! colspan="2" style="background:#c0e4c0" | present and past perfect
! colspan="6" style="background:#C0C0C0" | Use the present/imperfect renarrative tense of {sam} {along_with_refl} and {aor_part_list}
|-
! colspan="2" style="background:#c0e4c0" | future perfect and future perfect in the past
! colspan="6" style="background:#C0C0C0" | Use the future/future in the past renarrative tense of {sam} {along_with_refl} and {aor_part_list}
|-
! colspan="2" style="background:#f0e68c" | dubitative
! style="background:#f0e68c" | аз
! style="background:#f0e68c" | ти
! style="background:#f0e68c" | той/тя/то
! style="background:#f0e68c" | ние
! style="background:#f0e68c" | вие
! style="background:#f0e68c" | те
|-
! colspan="2" style="background:#f0e68c" | present and imperfect
! colspan="6" style="background:#C0C0C0" | Use the present/imperfect renarrative tense of {sam} {along_with_refl} and {impf_part_list}
|-
! colspan="2" style="background:#f0e68c" | aorist
! colspan="6" style="background:#C0C0C0" | Use the aorist renarrative tense of {sam} {along_with_refl} and {aor_part_list}
|-
! rowspan="2" style="background:#f0e68c" | future and future in the past
! style="background:#f0e68c" | pos.
! colspan="6" style="background:#C0C0C0" | Use the present/imperfect dubitative tense of {shta} followed by {da} {refl} and the present indicative tense
|-
! style="background:#f0e68c" | neg.
! colspan="6" style="background:#C0C0C0" | Use {nyamalo} {bilo} {da} {refl} and the present indicative tense
|-
! colspan="2" style="background:#f0e68c" | present and past perfect
| colspan="6" |<center>''none''</center>
|-
! colspan="2" style="background:#f0e68c" | future perfect and future perfect in the past
! colspan="6" style="background:#C0C0C0; white-space: nowrap;" | Use the future/future in the past dubitative tense of {sam} {along_with_refl} and {aor_part_list}
|-
! colspan="2" style="background:#9be1ff" | conclusive
! style="background:#9be1ff" | аз
! style="background:#9be1ff" | ти
! style="background:#9be1ff" | той/тя/то
! style="background:#9be1ff" | ние
! style="background:#9be1ff" | вие
! style="background:#9be1ff" | те
|-
! colspan="2" style="background:#9be1ff" | present and imperfect
! colspan="6" style="background:#C0C0C0" | Use the present indicative tense of {sam} {along_with_refl} and {impf_part_list}
|-
! colspan="2" style="background:#9be1ff" | aorist
! colspan="6" style="background:#C0C0C0" | Use the present indicative tense of {sam} {along_with_refl} and {aor_part_list}
|-
! rowspan="2" style="background:#9be1ff" | future and future in the past
! style="background:#9be1ff" | pos.
! colspan="6" style="background:#C0C0C0" | Use the present/imperfect conclusive tense of {shta} followed by {da} {refl} and the present indicative tense
|-
! style="background:#9be1ff" | neg.
! colspan="6" style="background:#C0C0C0" | Use {nyamalo} {e} {da} {refl} and the present indicative tense
|-
! colspan="2" style="background:#9be1ff" | present and past perfect
! colspan="6" style="background:#C0C0C0" | Use the present/imperfect conclusive tense of {sam} {along_with_refl} and {aor_part_list}
|-
! colspan="2" style="background:#9be1ff" | future perfect and future perfect in the past
! colspan="6" style="background:#C0C0C0; white-space: nowrap;" | Use the future/future in the past conclusive tense of {sam} {along_with_refl} and {aor_part_list}
|-
! rowspan="2" colspan="2" style="background:#f2b6c3" | conditional
! style="background:#f2b6c3" | аз
! style="background:#f2b6c3" | ти
! style="background:#f2b6c3" | той/тя/то
! style="background:#f2b6c3" | ние
! style="background:#f2b6c3" | вие
! style="background:#f2b6c3" | те
|-
! colspan="6" style="background:#C0C0C0" | Use the first aorist indicative tense of {bada} {along_with_refl} and {aor_part_list}
|-
]=]

	local table_spec_end = [=[
! rowspan="2" colspan="{ncol}" style="background:#e4d4c0" | imperative
! style="background:#e4d4c0" | -
! style="background:#e4d4c0" | ти
! style="background:#e4d4c0" | -
! style="background:#e4d4c0" | -
! style="background:#e4d4c0" | вие
! style="background:#e4d4c0" | -
|-
|
| {impv_sg}
|
|
| {impv_pl}
|
|{\cl}{notes_clause}</div></div>]=]

	local notes_template = [===[
<div style="width:100%;text-align:left;background:#d9ebff">
<div style="display:inline-block;text-align:left;padding-left:1em;padding-right:1em">
{footnote}
</div></div>
]===]

	forms.aor_part_list = m_string_utilities.format(
		base.impers and aor_part_list_impers or aor_part_list_pers, forms)
	forms.impf_part_list = m_string_utilities.format(
		base.impers and impf_part_list_impers or impf_part_list_pers, forms)
	forms.notes_clause = forms.footnote ~= "" and
		m_string_utilities.format(notes_template, forms) or ""
	forms.ncol = fullmod and "3" or "2"
	local table_spec_compound = fullmod and fullmod.table_spec_compound_full or table_spec_compound_short
	local table_spec = table_spec_non_compound .. table_spec_compound .. table_spec_end
	return m_string_utilities.format(table_spec, forms)
end


-- Externally callable function to parse and decline a verb given user-specified arguments.
-- Return value is WORD_SPEC, an object where the declined forms are in `WORD_SPEC.forms`
-- for each slot. If there are no values for a slot, the slot key will be missing. The value
-- for a given slot is a list of objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms(parent_args, pos, from_headword, def)
	local params = {
		[1] = {required = true, default = def or "пра́вя<2.1.impf.tr>"},
		footnote = {},
		title = {},
		full = {type = "boolean"},
	}
	if from_headword then
		params.lemma = {list = true}
		params.id = {}
		params.pos = {default = pos}
		params.cat = {list = true}
	end

	local args = m_para.process(parent_args, params)

	if args.title then
		track("overriding-title")
	end
	pos = args.pos or pos -- args.pos only set when from_headword
	
	local base, lemma = parse_word_spec(args[1])
	lemma = check_lemma_stress(base, lemma)
	lemma = detect_indicator_and_form_spec(base, lemma)
	conjs[base.conj](base, lemma)
	postprocess_base(base, lemma)
	base.forms = {}
	base.footnote = footnote
	conjugate_all(base)
	if base.refl then
		add_reflexive_suffix(base)
	end
	if base.impers then
		remove_non_impersonal_forms(base)
	end
	add_categories(base)
	local fullmod
	if args.full then
		fullmod = require("Module:bg-verb/full")
		fullmod.conjugate_all_compound(base)
	end
	base.forms.lemma = args.lemma and #args.lemma > 0 and args.lemma or
		{base.orig_lemma .. (base.refl and " " .. base.refl or "")}
	return base, fullmod
end


-- Main entry point. Template-callable function to parse and conjugate a verb given
-- user-specified arguments and generate a displayable table of the conjugated forms.
function export.show(frame)
	local parent_args = frame:getParent().args
	local base, fullmod = export.do_generate_forms(parent_args)
	show_forms(base, fullmod)
	return make_table(base, fullmod) .. require("Module:utilities").format_categories(base.categories, lang)
end


-- Template-callable function to parse and decline a noun given user-specified arguments and return
-- the forms as a string "SLOT=FORM,FORM,...|SLOT=FORM,FORM,...|...". Embedded pipe symbols (as might
-- occur in embedded links) are converted to <!>. If |include_props=1 is given, also include
-- additional properties (currently, only "|n=NUMBER"). This is for use by bots.
function export.generate_forms(frame)
	local include_props = frame.args["include_props"]
	local parent_args = frame:getParent().args
	local base = export.do_generate_forms(parent_args)
	return concat_forms(base, include_props)
end


return export
