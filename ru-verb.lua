--[=[
	This module contains functions for creating inflection tables for Russian
	verbs.
	
	Author: Atitarev, earliest version by CodeCat
]=]--

local m_utilities = require("Module:utilities")
local ut = require("Module:utils")
local com = require("Module:ru-common")
local m_debug = require("Module:debug")

-- If enabled, compare this module with new version of module to make
-- sure all conjugations are the same.
local test_new_ru_verb_module = false

local export = {}

-- Within this module, conjugations are the functions that do the actual
-- conjugating by creating the forms of a basic verb.
-- They are defined further down.
local conjugations = {}

local lang = require("Module:languages").getByCode("ru")

local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local rmatch = mw.ustring.match

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

-- ine() (if-not-empty)
local function ine(arg)
	if not arg or arg == "" then return nil end
	return arg
end

-- Clone parent's args while also assigning nil to empty strings.
local function clone_args(frame)
	local args = {}
	for pname, param in pairs(frame:getParent().args) do
		args[pname] = ine(param)
	end
	return args
end

local function getarg(args, arg, default, paramdesc)
	paramdesc = paramdesc or "Parameter " .. arg
        default = default or "-"
	--PAGENAME = mw.title.getCurrentTitle().text
	local NAMESPACE = mw.title.getCurrentTitle().nsText
	return args[arg] or (NAMESPACE == "Template" and default) or error(paramdesc .. " has not been provided")
end

local function track(page)
	m_debug.track("ru-verb/" .. page)
	return true
end

-- Forward functions

local present_e_a
local present_e_b
local present_e_c
local present_je_a
local present_je_b
local present_je_c
local present_i_a
local present_i_b
local present_i_c
local make_reflexive_alt
local make_reflexive
local make_table

local all_verb_forms = {
	-- present tense
	"pres_1sg", "pres_1sg2",
	"pres_2sg", "pres_2sg2",
	"pres_3sg", "pres_3sg2",
	"pres_1pl", "pres_1pl2",
	"pres_2pl", "pres_2pl2",
	"pres_3pl", "pres_3pl2",
	-- present-future tense
	"pres_futr_1sg", "pres_futr_1sg2",
	"pres_futr_2sg", "pres_futr_2sg2",
	"pres_futr_3sg", "pres_futr_3sg2",
	"pres_futr_1pl", "pres_futr_1pl2",
	"pres_futr_2pl", "pres_futr_2pl2",
	"pres_futr_3pl", "pres_futr_3pl2",
	-- future tense
	"futr_1sg", "futr_1sg2",
	"futr_2sg", "futr_2sg2",
	"futr_3sg", "futr_3sg2",
	"futr_1pl", "futr_1pl2",
	"futr_2pl", "futr_2pl2",
	"futr_3pl", "futr_3pl2",
	-- imperative
	"impr_sg", "impr_sg2",
	"impr_pl", "impr_pl2",
	-- past
	"past_m", "past_m2", "past_m3",
	"past_f", "past_f2", "past_f3",
	"past_n", "past_n2", "past_n3",
	"past_pl", "past_pl2", "past_pl3",
	"past_m_short",
	"past_f_short",
	"past_n_short",
	"past_pl_short",

	-- active participles
	"pres_actv_part", "pres_actv_part2",
	"past_actv_part", "past_actv_part2",
	-- passive participles
	"pres_pasv_part", "pres_pasv_part2",
	"past_pasv_part", "past_pasv_part2",
	-- adverbial participles
	"pres_adv_part", "pres_adv_part2",
	"past_adv_part", "past_adv_part2",
	"past_adv_part_short", "past_adv_part_short2",
	-- infinitive
	"infinitive",
}

local all_verb_props = mw.clone(all_verb_forms)
table.insert(all_verb_props, "title")
table.insert(all_verb_props, "perf")
table.insert(all_verb_props, "intr")
table.insert(all_verb_props, "impers")
table.insert(all_verb_props, "categories")

function export.generate_forms(conj_type, args)
	-- Verb type, one of impf, pf, impf-intr, pf-intr, impf-refl, pf-refl.
	-- Default to impf on the template page so that there is no script error.
	local verb_type = getarg(args, 1, "impf", "Verb type (first parameter)")
	-- verbs may have reflexive ending stressed in the masculine singular: занялся́, начался́, etc.
	local reflex_stress = args["reflex_stress"] -- "ся́"

	local forms, title, categories

	if conjugations[conj_type] then
		forms = conjugations[conj_type](args)
	else
		error("Unknown conjugation type '" .. conj_type .. "'")
	end

	if rfind(conj_type, "^irreg") then
		categories = {"Russian irregular verbs"}
		title = "irregular"
	else
		local class_num = rmatch(conj_type, "^([0-9]+)")
		assert(class_num and class_num ~= "")
		categories = {"Russian class " .. class_num .. " verbs"}
		title = "class " .. class_num
	end

	-- This form is not always present on verbs, so it needs to be specified explicitly.
	forms["past_pasv_part"] = args["past_pasv_part"] or ""

	--alternative forms
	local altforms = {"impr_sg2", "impr_pl2",
		"pres_actv_part2", "past_actv_part2", "pres_pasv_part2", "past_pasv_part2",
		"pres_adv_part2", "past_adv_part2", "past_adv_part_short2",
		"past_m2", "past_m3", "past_f2", "past_n2", "past_pl2",
		"pres_futr_1sg2", "pres_futr_2sg2", "pres_futr_3sg2",
		"pres_futr_1pl2", "pres_futr_2pl2", "pres_futr_3pl2"}
	for _, altform in ipairs(altforms) do
		forms[altform] = forms[altform] or args[altform]
	end

	--бдеть, победить have no 1st person sg present (impf) / future (pf)
	if args["no_1sg_pres"] == "1" then
		forms["pres_futr_1sg"] = ""
	end

	if args["no_1sg_futr"] == "1" then
		forms["pres_futr_1sg"] = ""
	end

	local intr = (verb_type == "impf-intr" or verb_type == "pf-intr" or verb_type == "pf-impers" or verb_type == "impf-impers" or verb_type == "pf-impers-refl" or verb_type == "impf-impers-refl")
	local refl = (verb_type == "impf-refl" or verb_type == "pf-refl" or verb_type == "pf-impers-refl" or verb_type == "impf-impers-refl")
	local perf = (verb_type == "pf" or verb_type == "pf-intr" or verb_type == "pf-refl" or verb_type == "pf-impers" or verb_type == "pf-impers-refl")
	--impersonal
	local impers = (verb_type == "pf-impers" or verb_type == "impf-impers" or verb_type == "pf-impers-refl" or verb_type == "impf-impers-refl")

	-- Perfective/imperfective
	if perf then
		table.insert(categories, "Russian perfective verbs")
	else
		table.insert(categories, "Russian imperfective verbs")
	end

	-- call alternative reflexive form to add a stressed "ся́" particle
	if reflex_stress then
		make_reflexive_alt(forms)
	end

	-- Reflexive/intransitive/transitive
	if refl then
		make_reflexive(forms)
		table.insert(categories, "Russian reflexive verbs")
	elseif intr then
		table.insert(categories, "Russian intransitive verbs")
	else
		table.insert(categories, "Russian transitive verbs")
	end

	-- Impersonal
	if impers then
		table.insert(categories, "Russian impersonal verbs")
	end

	return forms, title, perf, intr or refl, impers, categories
end

local function concat_vals(val)
	if type(val) == "table" then
		return table.concat(val, ",")
	else
		return val
	end
end

-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	local conj_type = frame.args[1] or error("Conjugation type has not been specified. Please pass parameter 1 to the module invocation")
	local args = clone_args(frame)

	local args_clone
	if test_new_ru_verb_module then
		args_clone = mw.clone(args)
	end

	local forms, title, perf, intr, impers, categories = export.generate_forms(conj_type, args)

	-- Test code to compare existing module to new one.
	if test_new_ru_verb_module then
		local m_new_ru_verb = require("Module:User:Benwing2/ru-verb")
		local newforms, newtitle, newperf, newintr, newimpers, newcategories = m_new_ru_verb.generate_forms(conj_type, args_clone)
		local vals = mw.clone(forms)
		vals.title = title
		vals.perf = perf
		vals.intr = intr
		vals.impers = impers
		vals.categories = categories
		local newvals = mw.clone(newforms)
		newvals.title = newtitle
		newvals.perf = newperf
		newvals.intr = newintr
		newvals.impers = newimpers
		newvals.categories = newcategories
		for _, prop in ipairs(all_verb_props) do
			local val = vals[prop]
			local newval = newvals[prop]
			if not ut.equals(val, newval) then
				-- Uncomment this to display the particular case and
				-- differing forms.
				--error(prop .. " " .. (val and concat_vals(val) or "nil") .. " || " .. (newval and concat_vals(newval) or "nil"))
				track("different-conj")
				break
			end
		end
	end

	return make_table(forms, title, perf, intr, impers) .. m_utilities.format_categories(categories, lang)

end

--[=[
	Conjugation functions
]=]--

conjugations["1a"] = function(args)
	local forms = {}

	local stem = getarg(args, 2)
	local tr = args.tr

	forms["infinitive"] = stem .. "ть"

	forms["pres_actv_part"] = stem .. "ющий"
	forms["past_actv_part"] = stem .. "вший"
	forms["pres_pasv_part"] = stem .. "емый"
	forms["pres_adv_part"] = stem .. "я"
	forms["past_adv_part"] = stem .. "вши"
	forms["past_adv_part_short"] = stem .. "в"

	present_je_a(forms, stem)

	forms["impr_sg"] = stem .. "й"
	forms["impr_pl"] = stem .. "йте"

	forms["past_m"] = stem .. "л"
	forms["past_f"] = stem .. "ла"
	forms["past_n"] = stem .. "ло"
	forms["past_pl"] = stem .. "ли"

	return forms
end

conjugations["2a"] = function(args)
	local forms = {}

	local inf_stem = getarg(args, 2)
	local pres_stem = inf_stem
	local pres_stem = inf_stem
	local pres_stem = inf_stem

	-- -ева- change to -ю- after most consonants and vowels, to -у- after hissing sounds and ц
	if rfind(pres_stem, "ова$") then
		pres_stem = rsub(pres_stem, "ова$", "у")
	elseif rfind(pres_stem, "о́ва$") then
		pres_stem = rsub(pres_stem, "о́ва$", "у́")
	elseif rfind(pres_stem, "ова́$") then
		pres_stem = rsub(pres_stem, "ова́$", "у́")
	elseif rfind(pres_stem, "[жцчшщ]ева$") then
		pres_stem = rsub(pres_stem, "ева$", "у")
	elseif rfind(pres_stem, "[жцчшщ]е́ва$") then
		pres_stem = rsub(pres_stem, "е́ва$", "у́")
	elseif rfind(pres_stem, "[жцчшщ]ева́$") then
		pres_stem = rsub(pres_stem, "ева́$", "у́")
	elseif rfind(pres_stem, "[бвгдзклмнпрстфхьаэыоуяеиёю́]ева$") then
		pres_stem = rsub(pres_stem, "ева$", "ю")
	elseif rfind(pres_stem, "[бвгдзклмнпрстфхьаэыоуяеиёю́]е́ва$") then
		pres_stem = rsub(pres_stem, "е́ва$", "ю́")
	elseif rfind(pres_stem, "[бвгдзклмнпрстфхьаэыоуяеиёю́]ева́$") then
		pres_stem = rsub(pres_stem, "ева́$", "ю́")
	end

	forms["infinitive"] = inf_stem .. "ть"

	forms["pres_actv_part"] = pres_stem .. "ющий"
	forms["past_actv_part"] = inf_stem .. "вший"
	forms["pres_pasv_part"] = pres_stem .. "емый"
	forms["pres_adv_part"] = pres_stem .. "я"
	forms["past_adv_part"] = inf_stem .. "вши"; forms["past_adv_part_short"] = inf_stem .. "в"

	present_je_a(forms, pres_stem)

	forms["impr_sg"] = pres_stem .. "й"
	forms["impr_pl"] = pres_stem .. "йте"

	forms["past_m"] = inf_stem .. "л"
	forms["past_f"] = inf_stem .. "ла"
	forms["past_n"] = inf_stem .. "ло"
	forms["past_pl"] = inf_stem .. "ли"

	return forms
end

conjugations["2b"] = function(args)
	local forms = {}

	local inf_stem = getarg(args, 2)
	local pres_stem = inf_stem
	-- all -ова- change to -у-
	pres_stem = rsub(pres_stem, "о(́?)ва(́?)$", "у%1%2")
	-- -ева- change to -ю- after most consonants and vowels, to -у- after hissing sounds and ц
	if rfind(pres_stem, "[бвгдзклмнпрстфхьаэыоуяеиёю́]е(́?)ва(́?)$") then
		pres_stem = rsub(pres_stem, "е(́?)ва(́?)$", "ю%1%2")
	elseif rfind(pres_stem, "[жцчшщ]е(́?)ва(́?)$") then
		pres_stem = rsub(pres_stem, "е(́?)ва(́?)$", "у%1%2")
	end

	local pres_stem_noa = com.remove_accents(pres_stem)

	forms["infinitive"] = inf_stem .. "ть"

	forms["pres_actv_part"] = pres_stem_noa .. "ю́щий"
	forms["past_actv_part"] = inf_stem .. "вший"
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = pres_stem_noa .. "я́"
	forms["past_adv_part"] = inf_stem .. "вши"; forms["past_adv_part_short"] = inf_stem .. "в"

	present_je_b(forms, pres_stem_noa)

	forms["impr_sg"] = pres_stem .. "й"
	forms["impr_pl"] = pres_stem .. "йте"

	forms["past_m"] = inf_stem .. "л"
	forms["past_f"] = inf_stem .. "ла"
	forms["past_n"] = inf_stem .. "ло"
	forms["past_pl"] = inf_stem .. "ли"

	return forms
end

conjugations["3a"] = function(args)

	local forms = {}

	local stem = getarg(args, 2)
	-- non-empty if no short past forms to be used
	local no_short_past = args[3]
	-- non-empty if no short past participle forms to be used
	local no_short_past_partcpl = args[4]
	-- "нь" if "-нь"/"-ньте" instead of "-ни"/"-ните" in the imperative
	local impr_end = args[5]
	-- optional full infinitive form for verbs like достичь
	local full_inf = args[6]
	-- optional short masculine past form for verbs like вять
	local past_m_short = args[7]

	-- if full infinitive is not passed, build from the stem, otherwise use the optional parameter
	if not full_inf then
		forms["infinitive"] = stem .. "нуть"
	else
		forms["infinitive"] = full_inf
	end

	forms["pres_actv_part"] = stem .. "нущий"
	forms["past_actv_part"] = stem .. "нувший"
	-- default is blank
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = ""
	forms["past_adv_part"] = stem .. "нувши"; forms["past_adv_part_short"] = stem .. "нув"

	present_e_a(forms, stem .. "н")

	-- "ни" or "нь"
	forms["impr_sg"] = stem .. (impr_end or "ни")
	forms["impr_pl"] = stem .. (impr_end or "ни") .. "те"

	-- if the 4rd argument is empty, add short past active participle,
	-- both short and long will be used
	if no_short_past_partcpl then
		forms["past_actv_part_short"] = ""
	else
		forms["past_actv_part_short"] = stem .. "ший"
	end

	forms["past_m"] = stem .. "нул"
	forms["past_f"] = stem .. "нула"
	forms["past_n"] = stem .. "нуло"
	forms["past_pl"] = stem .. "нули"

	-- if the 3rd argument is empty add short past forms
	if not no_short_past then
		-- use long and short past forms
		forms["past_m_short"] = stem
		forms["past_f_short"] = stem .. "ла"
		forms["past_n_short"] = stem .. "ло"
		forms["past_pl_short"] = stem .. "ли"
	end

	-- if past_m_short is special, e.g. вять - вял, then use it, otherwise use the current value
	if past_m_short then
		forms["past_m_short"] = past_m_short
	end

	return forms
end

conjugations["3b"] = function(args)
	local forms = {}

	local stem = getarg(args, 2)

	forms["infinitive"] = stem .. "у́ть"

	forms["pres_actv_part"] = stem .. "у́щий"
	forms["past_actv_part"] = stem .. "у́вший"
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = ""
	forms["past_adv_part"] = stem .. "у́вши"; forms["past_adv_part_short"] = stem .. "у́в"

	present_e_b(forms, stem)

	forms["impr_sg"] = stem .. "и́"
	forms["impr_pl"] = stem .. "и́те"

	forms["past_m"] = stem .. "у́л"
	forms["past_f"] = stem .. "у́ла"
	forms["past_n"] = stem .. "у́ло"
	forms["past_pl"] = stem .. "у́ли"

	return forms
end

conjugations["3c"] = function(args)
	local forms = {}

	local stem = getarg(args, 2)
	-- remove accent for some forms
	local stem_noa = com.remove_accents(stem)

	forms["infinitive"] = stem_noa .. "у́ть"

	forms["pres_actv_part"] = stem_noa .. "у́щий"
	forms["past_actv_part"] = stem_noa .. "у́вший"
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = ""
	forms["past_adv_part"] = stem_noa .. "у́вши"; forms["past_adv_part_short"] = stem_noa .. "у́в"

	present_e_c(forms, stem)

	forms["impr_sg"] = stem_noa .. "и́"
	forms["impr_pl"] = stem_noa .. "и́те"

	forms["past_m"] = stem_noa .. "у́л"
	forms["past_f"] = stem_noa .. "у́ла"
	forms["past_n"] = stem_noa .. "у́ло"
	forms["past_pl"] = stem_noa .. "у́ли"

	return forms
end

conjugations["4a"] = function(args)
	local forms = {}

	local stem = getarg(args, 2)
	-- for "a" stress type "й" - after vowels, "ь" - after single consonants, "и" - after consonant clusters
	local impr_end_param = args[3]
	-- optional parameter for verbs like похитить (похи́щу) (4a), защитить (защищу́) (4b), поглотить (поглощу́) (4c) with a different iotation (т -> щ, not ч)
	local shch = args[4]

	--set defaults if nothing is passed, "й" for stems ending in a vowel, "ь" for single consonant ending, "и" for double consonant ending
	-- "й" after any vowel, with or without an acute accent (беспоко́ить), no parameter passed
	local impr_end = ""
	if impr_end_param then
		impr_end = impr_end_param
	elseif rfind(stem, "[аэыоуяеиёю́]$") then
		impr_end = "й"
	-- "и" after two consonants in a row (мо́рщить, зафре́ндить), no parameter passed
	elseif rfind(stem, "[бвгджзклмнпрстфхцчшщь][бвгджзклмнпрстфхцчшщ]$") then
		impr_end = "и"
	-- "ь" after a single consonant (бре́дить), no parameter passed
	elseif rfind(stem, "[аэыоуяеиёю́][бвгджзклмнпрстфхцчшщ]$") then
		impr_end = "ь"
	-- default
	else --default
		impr_end = "ь"
	end

	forms["infinitive"] = stem .. "ить"

	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	if rfind(stem, "[шщжч]$") then
		forms["pres_actv_part"] = stem .. "ащий"
		forms["pres_adv_part"] = stem .. "а"
		-- use the passed parameter or default
		forms["impr_sg"] = stem .. impr_end
		forms["impr_pl"] = stem .. impr_end .. "те"
	else
		forms["pres_actv_part"] = stem .. "ящий"
		forms["pres_adv_part"] = stem .. "я"
		-- use the passed parameter or default
		forms["impr_sg"] = stem .. impr_end
		forms["impr_pl"] = stem .. impr_end .. "те"
	end

	forms["past_actv_part"] = stem .. "ивший"
	forms["pres_pasv_part"] = stem .. "имый"
	forms["past_adv_part"] = stem .. "ивши"; forms["past_adv_part_short"] = stem .. "ив"

	-- if shch is nil, pass nothing, otherwise pass "щ"
	if not shch then
		present_i_a(forms, stem)    -- param #3 must be a string
	else -- tell the conjugator that this is an exception
		present_i_a(forms, stem, shch)
	end

	forms["past_m"] = stem .. "ил"
	forms["past_f"] = stem .. "ила"
	forms["past_n"] = stem .. "ило"
	forms["past_pl"] = stem .. "или"

	return forms
end

conjugations["4b"] = function(args)
	local forms = {}

	local stem = getarg(args, 2)
	-- optional parameter for verbs like похитить (похи́щу) (4a), защитить (защищу́) (4b), поглотить (поглощу́) (4c) with a different iotation (т -> щ, not ч)
	local shch = args[3]
	-- some verbs don't have 1st person singular - победить, возродить, use "no_1sg_futr=1" in the template
	local no_1sg_futr = "0"
	local past_f = args["past_f"]

	if not args["no_1sg_futr"] then
		no_1sg_futr = 0
	elseif args["no_1sg_futr"] == "1" then
		no_1sg_futr = 1
	else
		no_1sg_futr = 0
	end

	forms["infinitive"] = stem .. "и́ть"

	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	if rfind(stem, "[шщжч]$") then
		forms["pres_actv_part"] = stem .. "а́щий"
		forms["pres_adv_part"] = stem .. "а́"
	else
		forms["pres_actv_part"] = stem .. "я́щий"
		forms["pres_adv_part"] = stem .. "я́"
	end

	forms["past_actv_part"] = stem .. "и́вший"
	forms["pres_pasv_part"] = stem .. "и́мый"
	forms["past_adv_part"] = stem .. "и́вши"; forms["past_adv_part_short"] = stem .. "и́в"

	-- if shch is nil, pass nothing, otherwise pass "щ"
	if not shch then
		present_i_b(forms, stem, 0)
	else -- т-щ, not т-ч
		present_i_b(forms, stem, 0, shch)
	end

	-- make 1st person future singular blank if no_1sg_futr = 1
	if no_1sg_futr == 1 then
		forms["pres_futr_1sg"] = ""
	end

	forms["impr_sg"] = stem .. "и́"
	forms["impr_pl"] = stem .. "и́те"

	forms["past_m"] = stem .. "и́л"
	forms["past_n"] = stem .. "и́ло"
	forms["past_pl"] = stem .. "и́ли"

	if past_f then
		forms["past_f"] = past_f
	else
		forms["past_f"] = stem .. "и́ла"
	end

	return forms
end

conjugations["4c"] = function(args)
	local forms = {}

	local stem = getarg(args, 2)
	-- optional parameter for verbs like похитить (похи́щу) (4a), защитить (защищу́) (4b), поглотить (поглощу́) (4c) with a different iotation (т -> щ, not ч)
	local shch = args[3]

	-- remove accent for some forms
	local stem_noa = com.remove_accents(stem)
	-- replace consonants for 1st person singular present/future
	local iotated_stem = com.iotation(stem_noa)

	forms["infinitive"] = stem_noa .. "и́ть"

	forms["past_actv_part"] = stem_noa .. "и́вший"
	forms["pres_pasv_part"] = stem_noa .. "и́мый"
	forms["past_adv_part"] = stem_noa .. "и́вши"; forms["past_adv_part_short"] = stem_noa .. "и́в"

	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	if rfind(stem, "[шщжч]$") then
		forms["pres_actv_part"] = stem_noa .. "а́щий"
		forms["pres_adv_part"] = stem_noa .. "а́"
	else
		forms["pres_actv_part"] = stem_noa .. "я́щий"
		forms["pres_adv_part"] = stem_noa .. "я́"
	end

	forms["impr_sg"] = stem_noa .. "и́"
	forms["impr_pl"] = stem_noa .. "и́те"

	-- if shch is nil, pass nothing, otherwise pass "щ"
	if not shch then
		present_i_c(forms, stem)    -- param #3 must be a string
	else -- tell the conjugator that this is an exception
		present_i_c(forms, stem, shch)
	end

	forms["past_m"] = stem_noa .. "и́л"
	forms["past_f"] = stem_noa .. "и́ла"
	forms["past_n"] = stem_noa .. "и́ло"
	forms["past_pl"] = stem_noa .. "и́ли"

	-- pres_actv_part for суши́ть -> су́шащий
	if forms["infinitive"] == "суши́ть" then
		forms["pres_actv_part"] = "су́шащий"
	end

	return forms
end

conjugations["5a"] = function(args)
	local forms = {}

	local stem = getarg(args, 2)
	-- обидеть, выстоять have different past tense and infinitive forms
	local past_stem = args[3]
	-- imperative ending, выгнать - выгони
	local impr_end = args[4]

	if not past_stem then
		past_stem = stem .. "е"
	end

	if not impr_end then
		impr_end = "ь"
	end

	forms["infinitive"] = past_stem .. "ть"

	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	if rfind(stem, "[шщжч]$") then
		forms["pres_actv_part"] = stem .. "ащий"
		forms["pres_adv_part"] = stem .. "а"
	else
		forms["pres_actv_part"] = stem .. "ящий"
		forms["pres_adv_part"] = stem .. "я"
	end

	forms["past_actv_part"] = past_stem .. "вший"
	forms["pres_pasv_part"] = stem .. "имый"
	forms["past_adv_part"] = past_stem .. "вши"; forms["past_adv_part_short"] = past_stem .. "в"

	-- "й" after any vowel (e.g. выстоять), with or without an acute accent, otherwise "ь"
	if rfind(stem, "[аэыоуяеиёю́]$") and impr_end == nil then
		impr_end = "й"
	end

	forms["impr_sg"] = stem .. impr_end
	forms["impr_pl"] = stem .. impr_end .. "те"

	present_i_a(forms, stem)

	forms["past_m"] = past_stem .. "л"
	forms["past_f"] = past_stem .. "ла"
	forms["past_n"] = past_stem .. "ло"
	forms["past_pl"] = past_stem .. "ли"

	return forms
end

conjugations["5b"] = function(args)
	local forms = {}

	local stem = getarg(args, 2)
	local past_stem = getarg(args, 3)
	-- irreg: лежать - лёжа
	local pres_adv_part = args[4]

	if rfind(stem, "[шщжч]$") then
		forms["pres_actv_part"] = stem .. "а́щий"
	else
		forms["pres_actv_part"] = stem .. "я́щий"
	end

	-- override if passed as a parameter, e.g. лёжа
	if pres_adv_part then
		forms["pres_adv_part"] = pres_adv_part
	elseif rfind(stem, "[шщжч]$") and not pres_adv_part then
		forms["pres_adv_part"] = stem .. "а́"
	else
		forms["pres_adv_part"] = stem .. "я́"
	end

	forms["infinitive"] = past_stem .. "ть"
	forms["past_actv_part"] = past_stem .. "вший"
	forms["past_adv_part"] = past_stem .. "вши"; forms["past_adv_part_short"] = past_stem .. "в"
	forms["past_m"] = past_stem .. "л"
	forms["past_f"] = past_stem .. "ла"
	forms["past_n"] = past_stem .. "ло"
	forms["past_pl"] = past_stem .. "ли"

	forms["pres_pasv_part"] = stem .. "и́мый"

	present_i_b(forms, stem)

	-- "й" after any vowel (e.g. выстоять), with or without an acute accent, otherwise "ь"
	local impr_end = "и́"
	if rfind(stem, "[аэыоуяеиёю́]$") then
		impr_end = "́й" -- the last vowel is stressed (an acute accent before "й")
	end

	forms["impr_sg"] = stem .. impr_end
	forms["impr_pl"] = stem .. impr_end .. "те"

	return forms
end

conjugations["5c"] = function(args)
	local forms = {}

	local stem = getarg(args, 2)
	local past_stem = getarg(args, 3)
	-- e.g. гнать - гнала́
	local fem_past = args[4]

	-- remove accent for some forms
	local stem_noa = com.remove_accents(stem)
	-- replace consonants for 1st person singular present/future
	local iotated_stem = com.iotation(stem_noa)

	forms["infinitive"] = past_stem .. "ть"

	forms["past_actv_part"] = past_stem .. "вший"
	forms["pres_pasv_part"] = stem_noa .. "и́мый"
	forms["past_adv_part"] = past_stem .. "вши"; forms["past_adv_part_short"] = past_stem .. "в"

	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	if rfind(stem, "[шщжч]$") then
		forms["pres_actv_part"] = stem_noa .. "а́щий"
		forms["pres_adv_part"] = stem_noa .. "а́"
	else
		forms["pres_actv_part"] = stem_noa .. "я́щий"
		forms["pres_adv_part"] = stem_noa .. "я́"
	end

	forms["impr_sg"] = stem_noa .. "и́"
	forms["impr_pl"] = stem_noa .. "и́те"

	present_i_c(forms, stem)

	-- some verbs have a different stress in the feminine past from, e.g. гнать - гнала
	if not fem_past then
		forms["past_f"] = past_stem .. "ла"
	else
		forms["past_f"] = fem_past
	end

	forms["past_m"] = past_stem .. "л"
	forms["past_n"] = past_stem .. "ло"
	forms["past_pl"] = past_stem .. "ли"

	return forms
end

conjugations["6a"] = function(args)
	local forms = {}

	local stem = getarg(args, 2)
	local impr_end = args[3]
	-- irregular imperatives (сыпать  - сыпь is moved to a separate function but the parameter may still be needed)
	local impr_sg = args[4]
	-- optional full infinitive form for verbs like колебать
	local full_inf = args[5]
	-- no iotation, e.g. вырвать - вы́рву
	local no_iotation = nil
	if args["no_iotation"] == "1" then
		no_iotation = "1"
	end
	-- вызвать - вы́зову (в́ызов)
	local pres_stem = args["pres_stem"] or stem

	-- replace consonants for 1st person singular present/future
	local iotated_stem = com.iotation(pres_stem)

	if rfind(iotated_stem, "[шщжч]$") then
		forms["pres_actv_part"] = iotated_stem .. "ущий"
	else
		forms["pres_actv_part"] = iotated_stem .. "ющий"
	end

	if rfind(iotated_stem, "[шщжч]$") then
		forms["pres_adv_part"] = iotated_stem .. "а"
	else
		forms["pres_adv_part"] = iotated_stem .. "я"
	end

	if no_iotation then
		forms["pres_adv_part"] = pres_stem .. "я"
	end

	if rfind(stem, "[аэыоуяеиёю́]$") then
		forms["infinitive"] = stem .. "ять"
		forms["past_actv_part"] = stem .. "явший"
		forms["past_adv_part"] = stem .. "явши"; forms["past_adv_part_short"] = stem .. "яв"
		forms["past_m"] = stem .. "ял"
		forms["past_f"] = stem .. "яла"
		forms["past_n"] = stem .. "яло"
		forms["past_pl"] = stem .. "яли"
	else
		forms["infinitive"] = stem .. "ать"
		forms["past_actv_part"] = stem .. "авший"
		forms["past_adv_part"] = stem .. "авши"; forms["past_adv_part_short"] = stem .. "ав"
		forms["past_m"] = stem .. "ал"
		forms["past_f"] = stem .. "ала"
		forms["past_n"] = stem .. "ало"
		forms["past_pl"] = stem .. "али"
	end

	-- if full infinitive is not passed, build from the stem, otherwise use the optional parameter
	if full_inf then
		forms["infinitive"] = full_inf
	end

	if no_iotation then
		forms["pres_pasv_part"] = stem .. "емый"
	else
		forms["pres_pasv_part"] = iotated_stem .. "емый"
	end

	present_je_a(forms, pres_stem, no_iotation)

	if not impr_end and rfind(stem, "[аэыоуяеиёю́]$") and not impr_end then
		impr_end = "й"
	elseif not impr_end and not rfind(stem, "[аэыоуяеиёю́]$") and not impr_end then
		impr_end = "и"
	end

	if no_iotation then
		forms["impr_sg"] = pres_stem .. impr_end
		forms["impr_pl"] = pres_stem .. impr_end .. "те"
	else
		forms["impr_sg"] = iotated_stem .. impr_end
		forms["impr_pl"] = iotated_stem .. impr_end .. "те"
	end

	-- irreg: сыпать  - сыпь, сыпьте
	if impr_sg then
		forms["impr_sg"] = impr_sg
		forms["impr_pl"] = impr_sg .. "те"
	end

	return forms
end

conjugations["6b"] = function(args)
	local forms = {}

	local stem = getarg(args, 2)
	-- звать - зов, драть - дер
	local pres_stem = args[3] or stem
	local past_f = args[4]
	local past_n2 = args["past_n2"]
	local past_pl2 = args["past_pl2"]

	forms["pres_pasv_part"] = ""

	present_e_b(forms, pres_stem)

	if not impr_end and rfind(stem, "[аэыоуяеиёю́]$") then
		impr_end = "́й" -- accent on the preceding vowel
	elseif not impr_end and not rfind(stem, "[аэыоуяеиёю́]$") then
		impr_end = "и́"
	end

	forms["impr_sg"] = pres_stem .. impr_end
	forms["impr_pl"] = pres_stem .. impr_end .. "те"

	if rfind(pres_stem, "[шщжч]$") then
		forms["pres_adv_part"] = pres_stem .. "а́"
	else
		forms["pres_adv_part"] = pres_stem .. "я́"
	end

	if rfind(pres_stem, "[аэыоуяеиёю́]$") then
		forms["pres_actv_part"] = pres_stem .. "ю́щий"
	else
		forms["pres_actv_part"] = pres_stem .. "у́щий"
	end

	if rfind(stem, "[аэыоуяеиёю́]$") then
		forms["infinitive"] = stem .. "я́ть"
		forms["past_actv_part"] = stem .. "я́вший"
		forms["past_adv_part"] = stem .. "я́вши"; forms["past_adv_part_short"] = stem .. "́яв"
		forms["past_m"] = stem .. "я́л"
		forms["past_f"] = stem .. "я́ла"
		forms["past_n"] = stem .. "я́ло"
		forms["past_pl"] = stem .. "я́ли"
	else
		forms["infinitive"] = stem .. "а́ть"
		forms["past_actv_part"] = stem .. "а́вший"
		forms["past_adv_part"] = stem .. "а́вши"; forms["past_adv_part_short"] = stem .. "а́в"
		forms["past_m"] = stem .. "а́л"
		forms["past_f"] = stem .. "а́ла"
		forms["past_n"] = stem .. "а́ло"
		forms["past_pl"] = stem .. "а́ли"
	end

	-- ждала́, подождала́
	if past_f then
		forms["past_f"] = past_f
	end
	--разобрало́сь (разобрало́)
	forms["past_n2"] = past_n2
	--разобрали́сь (разобрали́)
	forms["past_pl2"] = past_pl2

	return forms
end

conjugations["6c"] = function(args)
	local forms = {}

	local stem = getarg(args, 2)
	-- optional parameter for verbs like клеветать (клевещу́
	local shch = args[3]
	-- remove accent for some forms
	local stem_noa = com.make_unstressed(stem)
	-- iotate the stem
	local iotated_stem = ""
	if not shch then
		iotated_stem = com.iotation(stem)
	else
		iotated_stem = com.iotation(stem, shch)
	end
	-- iotate the 2nd stem
	local iotated_stem_noa = ""
	if not shch then
		iotated_stem_noa = com.iotation(stem_noa)
	else
		iotated_stem_noa = com.iotation(stem_noa, shch)
	end
		
	local no_iotation = nil
	if args["no_iotation"] == "1" then
		no_iotation = "1"
	end
	
	forms["infinitive"] = stem_noa .. "а́ть"

	forms["past_actv_part"] = stem_noa .. "а́вший"
	forms["pres_pasv_part"] = ""
	forms["past_adv_part"] = stem_noa .. "а́вши"; forms["past_adv_part_short"] = stem_noa .. "а́в"

	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	if rfind(iotated_stem, "[шщжч]$") or no_iotation then
		forms["pres_actv_part"] = iotated_stem ..  "ущий"
	else
		forms["pres_actv_part"] = iotated_stem ..  "ющий"
	end

	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	if rfind(iotated_stem_noa, "[шщжч]$") then
		forms["pres_adv_part"] = iotated_stem_noa ..  "а́"
	else
		forms["pres_adv_part"] = iotated_stem_noa ..  "я́"
	end

	--present_je_c(forms, stem, no_iotation)
	-- if shch is nil, pass nothing, otherwise pass "щ"
	if not shch then
		present_je_c(forms, stem)    -- param #3 must be a string
	else -- tell the conjugator that this is an exception
		present_je_c(forms, stem, shch)
	end	

	forms["impr_sg"] = iotated_stem_noa .. "и́"
	forms["impr_pl"] = iotated_stem_noa .. "и́те"

	forms["past_m"] = stem_noa .. "а́л"
	forms["past_f"] = stem_noa .. "а́ла"
	forms["past_n"] = stem_noa .. "а́ло"
	forms["past_pl"] = stem_noa .. "а́ли"

	return forms
end

conjugations["7a"] = function(args)
	local forms = {}

	local full_inf = getarg(args, 2)
	local pres_stem = getarg(args, 3)
	local past_stem = getarg(args, 4)
	local impr_sg = getarg(args, 5)
	local past_adv_part = getarg(args, 6)
	local past_m = args["past_m"]
	local past_f = args["past_f"]
	local past_n = args["past_n"]
	local past_pl = args["past_pl"]
	local pres_adv_part = args["pres_adv_part"]
	local past_actv_part = args["past_actv_part"]

	forms["infinitive"] = full_inf

	forms["pres_actv_part"] = pres_stem .. "ущий"

	-- вычесть - "" (non-existent)
	if past_actv_part then
		forms["past_actv_part"] = past_actv_part
	else
		forms["past_actv_part"] = past_stem .. "ший"
	end

	-- лезть - ле́зши (non-existent)
	if pres_adv_part then
		forms["pres_adv_part"] = pres_adv_part
	else
		forms["pres_adv_part"] =pres_stem .. "я"
	end

	forms["pres_pasv_part"] = ""
	forms["past_adv_part"] = past_adv_part; forms["past_adv_part_short"] = ""

	present_e_a(forms, pres_stem)

	forms["impr_sg"] = impr_sg
	forms["impr_pl"] = impr_sg .. "те"

	-- 0 ending if the past stem ends in a consonant
	if rfind(past_stem, "[аэыоуяеиёю́]$") then
		forms["past_m"] = past_stem .. "л"
	else
		forms["past_m"] = past_stem
	end

	-- вычесть - вы́чел
	if past_m then
		forms["past_m"] = past_m
	end
	
	if past_f then
		forms["past_f"] = past_f
	else
		forms["past_f"] = past_stem .. "ла"
	end
	
	if past_n then
		forms["past_n"] = past_n
	else
		forms["past_n"] = past_stem .. "ло"
	end

	if past_pl then
		forms["past_pl"] = past_pl
	else
		forms["past_pl"] = past_stem .. "ли"
	end
	
	return forms
end

conjugations["7b"] = function(args)
	local forms = {}

	local full_inf = getarg(args, 2)
	local pres_stem = getarg(args, 3)
	local past_stem = getarg(args, 4)

	local pres_pasv_part = args["pres_pasv_part"]
	local past_actv_part = args["past_actv_part"]
	local past_adv_part = args["past_adv_part"]
	local past_adv_part_short = args["past_adv_part_short"]

	local past_m = args["past_m"]
	local past_n = args["past_n"]
	local past_f = args["past_f"]
	local past_pl = args["past_pl"]

	forms["infinitive"] = full_inf

	forms["pres_actv_part"] = pres_stem .. "у́щий"
	forms["pres_adv_part"] = pres_stem .. "я́"

	if past_actv_part then
		forms["past_actv_part"] = past_actv_part
	else
		forms["past_actv_part"] = past_stem .. "ший"
	end

	if past_adv_part then
		forms["past_adv_part"] = past_adv_part
	else
		forms["past_adv_part"] = past_stem .. "вши"
	end

	if past_adv_part_short then
		forms["past_adv_part_short"] = past_adv_part_short
	else
		forms["past_adv_part_short"] = past_stem .. "в"
	end

	if pres_pasv_part then
		forms["pres_pasv_part"] = pres_pasv_part
	else
		forms["pres_pasv_part"] = ""
	end

	present_e_b(forms, pres_stem)

	forms["impr_sg"] = pres_stem .. "и́"
	forms["impr_pl"] = pres_stem .. "и́те"

	-- 0 ending if the past stem ends in a consonant
	if rfind(past_stem, "[аэыоуяеиёю́]$") then
		forms["past_m"] = past_stem .. "л"
	else
		forms["past_m"] = past_stem
	end

	if past_m then
		forms["past_m"] = past_m
	end

	if past_f then
		forms["past_f"] = past_f
	else
		forms["past_f"] = past_stem .. "ла"
	end
	if past_n then
		forms["past_n"] = past_n
	else
		forms["past_n"] = past_stem .. "ло"
	end
	if past_pl then
		forms["past_pl"] = past_pl
	else
		forms["past_pl"] = past_stem .. "ли"
	end

	return forms
end

conjugations["8a"] = function(args)
	local forms = {}

	local stem = getarg(args, 2)
	local full_inf = getarg(args, 3)
	local past_m = getarg(args, "past_m")
	-- if full infinitive is not passed, build from the stem, otherwise use the optional parameter
	forms["infinitive"] = full_inf

	forms["pres_actv_part"] = stem .. "ущий"
	forms["past_actv_part"] = past_m .. "ший"
	-- default is blank
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = ""

	forms["past_adv_part"] = past_m .. "ши"; forms["past_adv_part_short"] = ""

	local iotated_stem = com.iotation(stem)

	forms["pres_futr_1sg"] = stem .. "у"
	forms["pres_futr_2sg"] = iotated_stem .. "ешь"
	forms["pres_futr_3sg"] = iotated_stem .. "ет"
	forms["pres_futr_1pl"] = iotated_stem .. "ем"
	forms["pres_futr_2pl"] = iotated_stem .. "ете"
	forms["pres_futr_3pl"] = stem .. "ут"

	forms["impr_sg"] = stem .. "и"
	forms["impr_pl"] = stem .. "ите"

	forms["past_m"] = past_m
	forms["past_f"] = stem .. "ла"
	forms["past_n"] = stem .. "ло"
	forms["past_pl"] = stem .. "ли"

	return forms
end

conjugations["8b"] = function(args)
	local forms = {}

	local stem = getarg(args, 2)
	local full_inf = getarg(args, 3)
	local past_m = getarg(args, "past_m")
	local pres_pasv_part = args["pres_pasv_part"]
	-- if full infinitive is not passed, build from the stem, otherwise use the optional parameter
	forms["infinitive"] = full_inf

	forms["pres_actv_part"] = stem .. "у́щий"
	forms["past_actv_part"] = past_m .. "ший"
	-- default is blank
	forms["pres_pasv_part"] = ""
	if pres_pasv_part then --влечь -> влеко́мый
		forms["pres_pasv_part"] = pres_pasv_part
	end
	forms["pres_adv_part"] = ""

	forms["past_adv_part"] = past_m .. "ши"; forms["past_adv_part_short"] = ""

	local iotated_stem = com.iotation(stem)

	forms["pres_futr_1sg"] = stem .. "у́"
	forms["pres_futr_3pl"] = stem .. "у́т"

	forms["pres_futr_2sg"] = iotated_stem .. "ёшь"
	forms["pres_futr_3sg"] = iotated_stem .. "ёт"
	forms["pres_futr_1pl"] = iotated_stem .. "ём"
	forms["pres_futr_2pl"] = iotated_stem .. "ёте"

	forms["impr_sg"] = stem .. "и́"
	forms["impr_pl"] = stem .. "и́те"

	forms["past_m"] = past_m
	forms["past_f"] = stem .. "ла́"
	forms["past_n"] = stem .. "ло́"
	forms["past_pl"] = stem .. "ли́"

	return forms
end

conjugations["9a"] = function(args)
	local forms = {}

	local stem = getarg(args, 2)
	local pres_stem = getarg(args, 3)

	forms["infinitive"] = stem .. "еть"

	-- prefective only
	forms["pres_actv_part"] = ""
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = ""

	forms["past_actv_part"] = stem .. "евший"
	-- default is blank

	forms["past_adv_part"] = stem .. "евши"; forms["past_adv_part_short"] = stem .. "ев"

	present_e_a(forms, pres_stem)

	forms["impr_sg"] = pres_stem .. "и"
	forms["impr_pl"] = pres_stem .. "ите"

	forms["past_m"] = stem
	forms["past_f"] = stem .. "ла"
	forms["past_n"] = stem .. "ло"
	forms["past_pl"] = stem .. "ли"

	return forms
end

conjugations["9b"] = function(args)
	local forms = {}
	
	--for this type, it's important to distinguish impf and pf
	local verb_type = getarg(args, 1, "impf", "Verb type (first parameter)")
	local impf = (verb_type == "impf" or verb_type == "impf-intr" or verb_type == "impf-impers" or verb_type == "impf-refl" or verb_type == "impf-impers-refl")
	local pf = (verb_type == "pf" or verb_type == "pf-intr" or verb_type == "pf-impers" or verb_type == "pf-refl" or verb_type == "pf-impers-refl")
	
	local stem = getarg(args, 2)
	local pres_stem = getarg(args, 3)
	local past_adv_part2 = args["past_adv_part2"]
	local past_f = args["past_f"]
	-- remove stress, replace ё with е
	local stem_noa = com.make_unstressed(stem)

	forms["infinitive"] = stem_noa .. "е́ть"

	forms["pres_actv_part"] = pres_stem .. "у́щий"
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = ""

	forms["past_actv_part"] = stem .. "ший"
	-- default is blank

	--тереть -> тёрши
	if impf then
		forms["past_adv_part"] = stem .. "ши"; forms["past_adv_part_short"] = ""
	end
	
	--растереть -> растере́вши, растер́ев
	if pf then
		forms["past_adv_part"] = stem_noa .. "е́вши"; forms["past_adv_part_short"] = stem_noa .. "е́в"
	end

	present_e_b(forms, pres_stem)

	forms["impr_sg"] = pres_stem .. "и́"
	forms["impr_pl"] = pres_stem .. "и́те"

	forms["past_m"] = stem
	forms["past_f"] = stem .. "ла"
	forms["past_n"] = stem .. "ло"
	forms["past_pl"] = stem .. "ли"
	
	if past_f then
		forms["past_f"] = past_f
	else
		forms["past_f"] = stem .. "ла"
	end

	return forms
end

conjugations["10a"] = function(args)
	local forms = {}

	local stem = getarg(args, 2)

	forms["infinitive"] = stem .. "оть"

	forms["pres_actv_part"] = ""
	forms["past_actv_part"] = stem .. "овший"
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = ""
	forms["past_adv_part"] = stem .. "овши"; forms["past_adv_part_short"] = stem .. "ов"

	present_je_a(forms, stem)

	forms["impr_sg"] = stem .. "и"
	forms["impr_pl"] = stem .. "ите"

	forms["past_m"] = stem .. "ол"
	forms["past_f"] = stem .. "ола"
	forms["past_n"] = stem .. "оло"
	forms["past_pl"] = stem .. "оли"

	return forms
end

conjugations["10c"] = function(args)
	local forms = {}

	local inf_stem = getarg(args, 2)
	-- present tense stressed stem "моло́ть" - м́елет
	local pres_stem = getarg(args, 3)
	-- remove accent for some forms
	local pres_stem_noa = com.remove_accents(pres_stem)

	forms["infinitive"] = inf_stem .. "ть"

	forms["pres_actv_part"] = pres_stem .. "ющий"
	forms["past_actv_part"] = inf_stem .. "вший"
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = pres_stem_noa .. "я́"
	forms["past_adv_part"] = inf_stem .. "вши"; forms["past_adv_part_short"] = inf_stem .. "в"

	present_je_c(forms, pres_stem)

	forms["impr_sg"] = pres_stem_noa .. "и́"
	forms["impr_pl"] = pres_stem_noa .. "и́те"

	forms["past_m"] = inf_stem .. "л"
	forms["past_f"] = inf_stem .. "ла"
	forms["past_n"] = inf_stem .. "ло"
	forms["past_pl"] = inf_stem .. "ли"

	return forms
end

conjugations["11a"] = function(args)
	local forms = {}

	local stem = getarg(args, 2)

	forms["infinitive"] = stem .. "ить"

	-- prefective only
	forms["pres_actv_part"] = ""
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = ""

	forms["past_actv_part"] = stem .. "ивший"
	-- default is blank

	forms["past_adv_part"] = stem .. "ивши"; forms["past_adv_part_short"] = stem .. "ив"

	forms["pres_futr_1sg"] = stem .. "ью"
	forms["pres_futr_2sg"] = stem .. "ьешь"
	forms["pres_futr_3sg"] = stem .. "ьет"
	forms["pres_futr_1pl"] = stem .. "ьем"
	forms["pres_futr_2pl"] = stem .. "ьете"
	forms["pres_futr_3pl"] = stem .. "ьют"

	forms["impr_sg"] = stem .. "ей"
	forms["impr_pl"] = stem .. "ейте"

	forms["past_m"] = stem .. "ил"
	forms["past_f"] = stem .. "ила"
	forms["past_n"] = stem .. "ило"
	forms["past_pl"] = stem .. "или"

	return forms
end

conjugations["11b"] = function(args)
	local forms = {}

	local stem = getarg(args, 2)
	local pres_stem = getarg(args, 3)
	local past_f = args["past_f"]

	forms["infinitive"] = stem .. "и́ть"

	forms["pres_actv_part"] = pres_stem .. "ью́щий"
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = pres_stem .. "ья́"

	forms["past_actv_part"] = stem .. "и́вший"
	-- default is blank

	forms["past_adv_part"] = stem .. "и́вши"; forms["past_adv_part_short"] = stem .. "и́в"

	forms["pres_futr_1sg"] = pres_stem .. "ью́"
	forms["pres_futr_2sg"] = pres_stem .. "ьёшь"
	forms["pres_futr_3sg"] = pres_stem .. "ьёт"
	forms["pres_futr_1pl"] = pres_stem .. "ьём"
	forms["pres_futr_2pl"] = pres_stem .. "ьёте"
	forms["pres_futr_3pl"] = pres_stem .. "ью́т"

	forms["impr_sg"] = stem .. "е́й"
	forms["impr_pl"] = stem .. "е́йте"

	forms["past_m"] = stem .. "и́л"
	forms["past_f"] = stem .. "и́ла"
	forms["past_n"] = stem .. "и́ло"
	forms["past_pl"] = stem .. "и́ли"
	-- пила́, лила́
	if past_f then
		forms["past_f"] =past_f
	else
		forms["past_f"] = stem .. "и́ла"
	end

	return forms
end

conjugations["12a"] = function(args)
	local forms = {}

	local stem = getarg(args, 2)
	local pres_stem = getarg(args, 3)

	forms["infinitive"] = stem .. "ть"

	forms["pres_actv_part"] = pres_stem .. "ющий"
	forms["pres_pasv_part"] = pres_stem .. "емый"
	forms["pres_adv_part"] = pres_stem .. "я"

	forms["past_actv_part"] = stem .. "вший"
	-- default is blank

	forms["past_adv_part"] = stem .. "вши"; forms["past_adv_part_short"] = stem .. "в"

	forms["pres_futr_1sg"] = pres_stem .. "ю"
	forms["pres_futr_2sg"] = pres_stem .. "ешь"
	forms["pres_futr_3sg"] = pres_stem .. "ет"
	forms["pres_futr_1pl"] = pres_stem .. "ем"
	forms["pres_futr_2pl"] = pres_stem .. "ете"
	forms["pres_futr_3pl"] = pres_stem .. "ют"

	forms["impr_sg"] = pres_stem .. "й"
	forms["impr_pl"] = pres_stem .. "йте"

	forms["past_m"] = stem .. "л"
	forms["past_f"] = stem .. "ла"
	forms["past_n"] = stem .. "ло"
	forms["past_pl"] = stem .. "ли"

	return forms
end

conjugations["12b"] = function(args)
	local forms = {}

	local stem = getarg(args, 2)
	local pres_stem = getarg(args, 3)
	-- гнила́ needs a parameter, default - пе́ла
	local past_f = args["past_f"]

	forms["infinitive"] = stem .. "ть"

	forms["pres_actv_part"] = pres_stem .. "ю́щий"
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = pres_stem .. "я́"

	forms["past_actv_part"] = stem .. "вший"
	-- default is blank

	forms["past_adv_part"] = stem .. "вши"; forms["past_adv_part_short"] = stem .. "в"

	forms["pres_futr_1sg"] = pres_stem .. "ю́"
	forms["pres_futr_2sg"] = pres_stem .. "ёшь"
	forms["pres_futr_3sg"] = pres_stem .. "ёт"
	forms["pres_futr_1pl"] = pres_stem .. "ём"
	forms["pres_futr_2pl"] = pres_stem .. "ёте"
	forms["pres_futr_3pl"] = pres_stem .. "ю́т"

	-- the preceding vowel is stressed
	forms["impr_sg"] = pres_stem .. "́й"
	forms["impr_pl"] = pres_stem .. "́йте"

	-- гнила́
	if past_f then
		forms["past_f"] = past_f
	else
		forms["past_f"] = stem .. "ла"
	end

	forms["past_m"] = stem .. "л"
	forms["past_n"] = stem .. "ло"
	forms["past_pl"] = stem .. "ли"

	return forms
end

conjugations["13b"] = function(args)
	local forms = {}

	local stem = getarg(args, 2)
	local pres_stem = getarg(args, 3)

	forms["infinitive"] = stem .. "ть"

	forms["pres_actv_part"] = pres_stem .. "ю́щий"
	forms["pres_pasv_part"] = stem .. "емый"
	forms["pres_adv_part"] = stem .. "я"

	forms["past_actv_part"] = stem .. "вший"
	-- default is blank

	forms["past_adv_part"] = stem .. "вши"; forms["past_adv_part_short"] = stem .. "в"

	forms["pres_futr_1sg"] = pres_stem .. "ю́"
	forms["pres_futr_2sg"] = pres_stem .. "ёшь"
	forms["pres_futr_3sg"] = pres_stem .. "ёт"
	forms["pres_futr_1pl"] = pres_stem .. "ём"
	forms["pres_futr_2pl"] = pres_stem .. "ёте"
	forms["pres_futr_3pl"] = pres_stem .. "ю́т"

	forms["impr_sg"] = stem .. "й"
	forms["impr_pl"] = stem .. "йте"

	forms["past_m"] = stem .. "л"
	forms["past_f"] = stem .. "ла"
	forms["past_n"] = stem .. "ло"
	forms["past_pl"] = stem .. "ли"

	return forms
end

conjugations["14a"] = function(args)
	-- only one verb: вы́жать
	local forms = {}

	local stem = getarg(args, 2)
	local pres_stem = getarg(args, 3)

	forms["infinitive"] = stem .. "ть"

	-- perfective only
	forms["pres_actv_part"] = ""
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = ""

	forms["past_actv_part"] = stem .. "вший"
	-- default is blank

	forms["past_adv_part"] = stem .. "вши"; forms["past_adv_part_short"] = stem .. "в"

	present_e_a(forms, pres_stem)

	forms["impr_sg"] = pres_stem .. "и"
	forms["impr_pl"] = pres_stem .. "ите"

	forms["past_m"] = stem .. "л"
	forms["past_f"] = stem .. "ла"
	forms["past_n"] = stem .. "ло"
	forms["past_pl"] = stem .. "ли"

	return forms
end

conjugations["14b"] = function(args)
	local forms = {}

	local stem = getarg(args, 2)
	local pres_stem = getarg(args, 3)
	-- заня́ться has three forms: за́нялся, зан́ялся, занялся́
	local past_m = args["past_m"]
	local past_m2 = args["past_m2"]
	local past_m3 = args["past_m3"]
	local past_f = args["past_f"]
	local past_n = args["past_n"]
	local past_n2 = args["past_n2"]
	local past_pl = args["past_pl"]
	local past_pl2 = args["past_pl2"]

	forms["infinitive"] = stem .. "ть"

	forms["pres_actv_part"] = pres_stem .. "у́щий"
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = pres_stem .. "я́"

	forms["past_actv_part"] = stem .. "вший"

	forms["past_adv_part"] = stem .. "вши"; forms["past_adv_part_short"] = stem .. "в"

	present_e_b(forms, pres_stem)

	forms["impr_sg"] = pres_stem .. "и́"
	forms["impr_pl"] = pres_stem .. "и́те"

	if past_m then
		forms["past_m"] = past_m
		forms["past_n"] = past_m .. "о"
		forms["past_pl"] = past_m .. "и"
	else
		forms["past_m"] = stem .. "л"
		forms["past_f"] = stem .. "ла"
		forms["past_n"] = stem .. "ло"
		forms["past_pl"] = stem .. "ли"
	end

	if past_f then
		forms["past_f"] = past_f
	end

	-- override these if supplied
	if past_n then
		forms["past_n"] = past_n
	end

	if past_pl then
		forms["past_pl"] = past_pl
	end

	if past_m2 then
		forms["past_m2"] = past_m2
	end

	if past_m3 then
		forms["past_m3"] = past_m3
	end

	if past_n2 then
		forms["past_n2"] = past_n2
	end

	if past_pl2 then
		forms["past_pl2"] = past_pl2
	end

	return forms
end

conjugations["14c"] = function(args)
	local forms = {}

	local stem = getarg(args, 2)
	local pres_stem = getarg(args, 3)
	local pres_stem_noa = com.make_unstressed(pres_stem)
	local past_m = args["past_m"]
	local past_f = args["past_f"]
	local past_n = args["past_n"]
	local past_pl = args["past_pl"]
	local past_m2 = args["past_m2"]
	local past_n2 = args["past_n2"]
	local past_pl2 = args["past_pl2"]

	forms["infinitive"] = stem .. "ть"

	forms["pres_actv_part"] = pres_stem .. "у́щий"
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = pres_stem .. "я́"

	forms["past_actv_part"] = stem .. "вший"

	forms["past_adv_part"] = stem .. "вши"; forms["past_adv_part_short"] = stem .. "в"

	present_e_c(forms, pres_stem)

	forms["impr_sg"] = pres_stem_noa .. "и́"
	forms["impr_pl"] = pres_stem_noa .. "и́те"

	if past_m then
		forms["past_m"] = past_m
		forms["past_n"] = past_m .. "о"
		forms["past_pl"] = past_m .. "и"
	else
		forms["past_m"] = stem .. "л"
		forms["past_n"] = stem .. "ло"
		forms["past_pl"] = stem .. "ли"
	end

	if past_n then
		forms["past_n"] = past_n
	end
	--изъя́ла but приняла́
	if past_f then
		forms["past_f"] = past_f
	else
		forms["past_f"] = stem .. "ла"
	end

	--two forms: при́нялся, принялс́я
	if past_m2 then
		forms["past_m2"] = past_m2
	end

	if past_n2 then
		forms["past_n2"] = past_n2
	end

	if past_pl then
		forms["past_pl"] = past_pl
	end

	if past_pl2 then
		forms["past_pl2"] = past_pl2
	end

	return forms
end

conjugations["15a"] = function(args)
	local forms = {}

	local stem = getarg(args, 2)

	forms["infinitive"] = stem .. "ть"

	forms["pres_actv_part"] = stem .. "нущий"
	forms["past_actv_part"] = stem .. "вший"
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = ""
	forms["past_adv_part"] = stem .. "вши"; forms["past_adv_part_short"] = stem .. "в"

	present_e_a(forms, stem .. "н")

	forms["impr_sg"] = stem .. "нь"
	forms["impr_pl"] = stem .. "ньте"

	forms["past_m"] = stem .. "л"
	forms["past_f"] = stem .. "ла"
	forms["past_n"] = stem .. "ло"
	forms["past_pl"] = stem .. "ли"

	return forms
end

conjugations["16a"] = function(args)
	local forms = {}

	local stem = getarg(args, 2)

	forms["infinitive"] = stem .. "ть"

	forms["pres_actv_part"] = stem .. "ву́щий"
	forms["past_actv_part"] = stem .. "вший"
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = ""
	forms["past_adv_part"] = stem .. "вши"; forms["past_adv_part_short"] = stem .. "в"

	present_e_a(forms, stem .. "в")

	forms["impr_sg"] = stem .. "ви"
	forms["impr_pl"] = stem .. "вите"

	forms["past_m"] = stem .. "л"
	forms["past_f"] = stem .. "ла"
	forms["past_n"] = stem .. "ло"
	forms["past_pl"] = stem .. "ли"

	return forms
end

conjugations["16b"] = function(args)
	local forms = {}

	local stem = getarg(args, 2)
	local stem_noa = com.make_unstressed(stem)

	local past_n2 = args["past_n2"]
	local past_pl2 = args["past_pl2"]

	forms["infinitive"] = stem .. "ть"

	forms["pres_actv_part"] = stem_noa .. "ву́щий"
	forms["past_actv_part"] = stem .. "вший"
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = stem_noa .. "вя́"
	forms["past_adv_part"] = stem .. "вши"; forms["past_adv_part_short"] = stem .. "в"

	present_e_b(forms, stem_noa .. "в")

	forms["impr_sg"] = stem_noa .. "ви́"
	forms["impr_pl"] = stem_noa .. "ви́те"

	forms["past_m"] = stem .. "л"
	forms["past_f"] = stem_noa .. "ла́"
	forms["past_n"] = stem .. "ло"
	forms["past_pl"] = stem .. "ли"

	if past_m then
		forms["past_m"] = past_m
	end

	if past_n then
		forms["past_n"] = past_n
	end

	if past_pl then
		forms["past_pl"] = past_pl
	end

	-- прижило́сь, прижи́лось
	if past_n2 then
		forms["past_n2"] = past_n2
	end

	if past_pl2 then
		forms["past_pl2"] = past_pl2
	end

	return forms
end

conjugations["irreg-бежать"] = function(args)
	-- irregular, only for verbs derived from бежать with the same stress pattern
	local forms = {}

	local prefix = args[2] or ""

	forms["infinitive"] = prefix .. "бежа́ть"

	forms["past_actv_part"] = prefix .. "бежа́вший"
	forms["pres_pasv_part"] = ""
	forms["past_adv_part"] = prefix .. "бежа́вши"; forms["past_adv_part_short"] = prefix .. "бежа́в"

	forms["pres_actv_part"] = prefix .. "бегу́щий"
	forms["pres_adv_part"] = ""

	forms["impr_sg"] = prefix .. "беги́"
	forms["impr_pl"] = prefix .. "беги́те"

	forms["pres_futr_1sg"] = prefix .. "бегу́"
	forms["pres_futr_2sg"] = prefix .. "бежи́шь"
	forms["pres_futr_3sg"] = prefix .. "бежи́т"
	forms["pres_futr_1pl"] = prefix .. "бежи́м"
	forms["pres_futr_2pl"] = prefix .. "бежи́те"
	forms["pres_futr_3pl"] = prefix .. "бегу́т"

	forms["past_m"] = prefix .. "бежа́л"
	forms["past_f"] = prefix .. "бежа́ла"
	forms["past_n"] = prefix .. "бежа́ло"
	forms["past_pl"] = prefix .. "бежа́ли"

	-- вы́бежать (perfective)
	if prefix == "вы́" then
		forms["infinitive"] = prefix .. "бежать"

		forms["past_actv_part"] = prefix .. "бежавший"
		forms["past_adv_part"] = prefix .. "бежавши"; forms["past_adv_part_short"] = prefix .. "бежав"

		forms["impr_sg"] = prefix .. "беги"
		forms["impr_pl"] = prefix .. "бегите"

		forms["pres_futr_1sg"] = prefix .. "бегу"
		forms["pres_futr_2sg"] = prefix .. "бежишь"
		forms["pres_futr_3sg"] = prefix .. "бежит"
		forms["pres_futr_1pl"] = prefix .. "бежим"
		forms["pres_futr_2pl"] = prefix .. "бежите"
		forms["pres_futr_3pl"] = prefix .. "бегут"

		forms["past_m"] = prefix .. "бежал"
		forms["past_f"] = prefix .. "бежала"
		forms["past_n"] = prefix .. "бежало"
		forms["past_pl"] = prefix .. "бежали"
	end

	return forms
end

conjugations["irreg-спать"] = function(args)
	-- irregular, only for verbs derived from спать
	local forms = {}

	local prefix = args[2] or ""

	forms["infinitive"] = prefix .. "спа́ть"

	forms["past_actv_part"] = prefix .. "спа́вший"
	forms["pres_pasv_part"] = ""
	forms["past_adv_part"] = prefix .. "спа́вши"; forms["past_adv_part_short"] = prefix .. "спа́в"

	forms["pres_actv_part"] = prefix .. "спя́щий"
	forms["pres_adv_part"] = prefix .. "спя́"

	forms["impr_sg"] = prefix .. "спи́"
	forms["impr_pl"] = prefix .. "спи́те"

	forms["pres_futr_1sg"] = prefix .. "сплю́"
	forms["pres_futr_2sg"] = prefix .. "спи́шь"
	forms["pres_futr_3sg"] = prefix .. "спи́т"
	forms["pres_futr_1pl"] = prefix .. "спи́м"
	forms["pres_futr_2pl"] = prefix .. "спи́те"
	forms["pres_futr_3pl"] = prefix .. "спя́т"

	forms["past_m"] = prefix .. "спа́л"
	forms["past_f"] = prefix .. "спала́"
	forms["past_n"] = prefix .. "спа́ло"
	forms["past_pl"] = prefix .. "спа́ли"

	-- вы́спаться (perfective, reflexive), reflexive endings are added later
	if prefix == "вы́" then
		forms["infinitive"] = prefix .. "спать"

		forms["past_actv_part"] = prefix .. "спавший"
		forms["past_adv_part"] = prefix .. "спавши"; forms["past_adv_part_short"] = ""

		forms["impr_sg"] = prefix .. "спи"
		forms["impr_pl"] = prefix .. "спите"

		forms["pres_futr_1sg"] = prefix .. "сплю"
		forms["pres_futr_2sg"] = prefix .. "спишь"
		forms["pres_futr_3sg"] = prefix .. "спит"
		forms["pres_futr_1pl"] = prefix .. "спим"
		forms["pres_futr_2pl"] = prefix .. "спите"
		forms["pres_futr_3pl"] = prefix .. "спят"

		forms["past_m"] = prefix .. "спал"
		forms["past_f"] = prefix .. "спала"
		forms["past_n"] = prefix .. "спало"
		forms["past_pl"] = prefix .. "спали"
	end

	return forms
end

conjugations["irreg-хотеть"] = function(args)
	-- irregular, only for verbs derived from хотеть with the same stress pattern
	local forms = {}

	local prefix = args[2] or ""

	forms["infinitive"] = prefix .. "хоте́ть"

	forms["past_actv_part"] = prefix .. "хоте́вший"
	forms["pres_pasv_part"] = ""
	forms["past_adv_part"] = prefix .. "хоте́вши"; forms["past_adv_part_short"] = prefix .. "хоте́в"

	forms["pres_actv_part"] = prefix .. "хотя́щий"
	forms["pres_adv_part"] = prefix .. "хотя́"

	forms["impr_sg"] = prefix .. "хоти́"
	forms["impr_pl"] = prefix .. "хоти́те"

	forms["pres_futr_1sg"] = prefix .. "хочу́"
	forms["pres_futr_2sg"] = prefix .. "хо́чешь"
	forms["pres_futr_3sg"] = prefix .. "хо́чет"
	forms["pres_futr_1pl"] = prefix .. "хоти́м"
	forms["pres_futr_2pl"] = prefix .. "хоти́те"
	forms["pres_futr_3pl"] = prefix .. "хотя́т"

	forms["past_m"] = prefix .. "хоте́л"
	forms["past_f"] = prefix .. "хоте́ла"
	forms["past_n"] = prefix .. "хоте́ло"
	forms["past_pl"] = prefix .. "хоте́ли"

	return forms
end

conjugations["irreg-дать"] = function(args)
	-- irregular, only for verbs derived from дать with the same stress pattern and вы́дать
	local forms = {}

	--for this type, it's important to distinguish if it's reflexive to set some stress patterns
	local verb_type = getarg(args, 1, "refl", "Verb type (first parameter)")
	local refl = (verb_type == "impf-refl" or verb_type == "pf-refl" or verb_type == "impf-impers-refl" or verb_type == "pf-impers-refl")
	
	local prefix = args[2] or ""
	-- alternative past masculine forms: со́здал/созд́ал, п́ередал/переда́л, ́отдал/отд́ал, etc.
	local past_m = args["past_m"]
	local past_m2 = args["past_m2"]
	local past_f = args["past_f"]
	local past_n = args["past_n"]
	local past_pl = args["past_pl"]

	forms["infinitive"] = prefix .. "да́ть"

	forms["past_actv_part"] = prefix .. "да́вший"
	forms["pres_pasv_part"] = ""
	forms["past_adv_part"] = prefix .. "да́вши"; forms["past_adv_part_short"] = prefix .. "да́в"

	forms["pres_actv_part"] = "даю́щий"
	forms["pres_adv_part"] = ""

	forms["impr_sg"] = prefix .. "да́й"
	forms["impr_pl"] = prefix .. "да́йте"

	forms["pres_futr_1sg"] = prefix .. "да́м"
	forms["pres_futr_2sg"] = prefix .. "да́шь"
	forms["pres_futr_3sg"] = prefix .. "да́ст"
	forms["pres_futr_1pl"] = prefix .. "дади́м"
	forms["pres_futr_2pl"] = prefix .. "дади́те"
	forms["pres_futr_3pl"] = prefix .. "даду́т"

	forms["past_m"] = prefix .. "да́л"
	-- пе́редал, ́отдал, пр́одал, з́адал, etc.
	forms["past_m2"] = past_m2
	forms["past_f"] = prefix .. "дала́"
	forms["past_n"] = prefix .. "да́ло"
	forms["past_n2"] = prefix .. "дало́" --same with "взять"
	forms["past_pl"] = prefix .. "да́ли"
	
	if refl then
		forms["past_n"] = prefix .. "дало́"
		forms["past_n2"] = nil
	end

	-- вы́дать (perfective)
	if prefix == "вы́" then
		forms["infinitive"] = prefix .. "дать"

		forms["past_actv_part"] = prefix .. "давший"

		forms["past_adv_part"] = prefix .. "давши"; forms["past_adv_part_short"] = prefix .. "дав"

		forms["impr_sg"] = prefix .. "дай"
		forms["impr_pl"] = prefix .. "дайте"

		forms["pres_futr_1sg"] = prefix .. "дам"
		forms["pres_futr_2sg"] = prefix .. "дашь"
		forms["pres_futr_3sg"] = prefix .. "даст"
		forms["pres_futr_1pl"] = prefix .. "дадим"
		forms["pres_futr_2pl"] = prefix .. "дадите"
		forms["pres_futr_3pl"] = prefix .. "дадут"

		forms["past_m"] = prefix .. "дал"
		forms["past_f"] = prefix .. "дала"
		forms["past_n"] = prefix .. "дало"
		forms["past_pl"] = prefix .. "дали"
	end

	if past_m then
		forms["past_m"] = past_m
	end
	if past_f then
		forms["past_f"] = past_f
	end
	if past_n then
		forms["past_n"] = past_n
	end
	if past_pl then
		forms["past_pl"] = past_pl
	end

	return forms
end

conjugations["irreg-есть"] = function(args)
	-- irregular, only for verbs derived from есть
	local forms = {}

	local prefix = args[2] or ""

	forms["infinitive"] = prefix .. "е́сть"

	forms["past_actv_part"] = prefix .. "е́вший"
	forms["pres_pasv_part"] = "едо́мый"
	forms["past_adv_part"] = prefix .. "е́вши"; forms["past_adv_part_short"] = prefix .. "е́в"

	forms["pres_actv_part"] = "едя́щий"
	forms["pres_adv_part"] = "едя́"

	forms["impr_sg"] = prefix .. "е́шь"
	forms["impr_pl"] = prefix .. "е́шьте"

	forms["pres_futr_1sg"] = prefix .. "е́м"
	forms["pres_futr_2sg"] = prefix .. "е́шь"
	forms["pres_futr_3sg"] = prefix .. "е́ст"
	forms["pres_futr_1pl"] = prefix .. "еди́м"
	forms["pres_futr_2pl"] = prefix .. "еди́те"
	forms["pres_futr_3pl"] = prefix .. "едя́т"

	forms["past_m"] = prefix .. "е́л"
	forms["past_f"] = prefix .. "е́ла"
	forms["past_n"] = prefix .. "е́ло"
	forms["past_pl"] = prefix .. "е́ли"

	-- вы́есть (perfective)
	if prefix == "вы́" then
		forms["infinitive"] = prefix .. "есть"

		forms["past_actv_part"] = prefix .. "евший"
		forms["past_adv_part"] = prefix .. "евши"; forms["past_adv_part_short"] = prefix .. "ев"

		forms["impr_sg"] = prefix .. "ешь"
		forms["impr_pl"] = prefix .. "ешьте"

		forms["pres_futr_1sg"] = prefix .. "ем"
		forms["pres_futr_2sg"] = prefix .. "ешь"
		forms["pres_futr_3sg"] = prefix .. "ест"
		forms["pres_futr_1pl"] = prefix .. "едим"
		forms["pres_futr_2pl"] = prefix .. "едите"
		forms["pres_futr_3pl"] = prefix .. "едят"

		forms["past_m"] = prefix .. "ел"
		forms["past_f"] = prefix .. "ела"
		forms["past_n"] = prefix .. "ело"
		forms["past_pl"] = prefix .. "ели"
	end

	return forms
end

conjugations["irreg-сыпать"] = function(args)
	-- irregular, only for verbs derived from сыпать
	local forms = {}

	local prefix = args[2] or ""

	forms["infinitive"] = prefix .. "сы́пать"

	forms["past_actv_part"] = prefix .. "сы́павший"
	forms["pres_pasv_part"] = prefix .. "сы́племый"
	forms["past_adv_part"] = prefix .. "сы́павши"; forms["past_adv_part_short"] = prefix .. "сы́пав"

	forms["pres_actv_part"] = prefix .. "сы́плющий"
	forms["pres_adv_part"] = prefix .. "сы́пля"
	forms["pres_adv_part2"] = prefix .. "сы́пя"

	forms["impr_sg"] = prefix .. "сы́пь"
	forms["impr_pl"] = prefix .. "сы́пьте"

	forms["pres_futr_1sg"] = prefix .. "сы́плю"
	forms["pres_futr_2sg"] = prefix .. "сы́плешь"
	forms["pres_futr_2sg2"] = prefix .. "сы́пешь"
	forms["pres_futr_3sg"] = prefix .. "сы́плет"
	forms["pres_futr_3sg2"] = prefix .. "сы́пет"
	forms["pres_futr_1pl"] = prefix .. "сы́плем"
	forms["pres_futr_1pl2"] = prefix .. "сы́пем"
	forms["pres_futr_2pl"] = prefix .. "сы́плете"
	forms["pres_futr_2pl2"] = prefix .. "сы́пете"
	forms["pres_futr_3pl"] = prefix .. "сы́плют"

	forms["past_m"] = prefix .. "сы́пал"
	forms["past_f"] = prefix .. "сы́пала"
	forms["past_n"] = prefix .. "сы́пало"
	forms["past_pl"] = prefix .. "сы́пали"

	-- вы́сыпать (perfective), not to confuse with высыпа́ть (1a, imperfective)
	if prefix == "вы́" then
		forms["infinitive"] = prefix .. "сыпать"

		forms["past_actv_part"] = prefix .. "сыпавший"
		forms["past_adv_part"] = prefix .. "сыпавши"; forms["past_adv_part_short"] = prefix .. "сыпав"

		forms["impr_sg"] = prefix .. "сыпь"
		forms["impr_pl"] = prefix .. "сыпьте"

		forms["pres_futr_1sg"] = prefix .. "сыплю"
		forms["pres_futr_2sg"] = prefix .. "сыплешь"
		forms["pres_futr_2sg2"] = prefix .. "сыпешь"
		forms["pres_futr_3sg"] = prefix .. "сыплет"
		forms["pres_futr_3sg2"] = prefix .. "сыпет"
		forms["pres_futr_1pl"] = prefix .. "сыплем"
		forms["pres_futr_1pl2"] = prefix .. "сыпем"
		forms["pres_futr_2pl"] = prefix .. "сыплете"
		forms["pres_futr_2pl2"] = prefix .. "сыпете"
		forms["pres_futr_3pl"] = prefix .. "сыплют"
		forms["pres_futr_3pl2"] = prefix .. "сыпют"

		forms["past_m"] = prefix .. "сыпал"
		forms["past_f"] = prefix .. "сыпала"
		forms["past_n"] = prefix .. "сыпало"
		forms["past_pl"] = prefix .. "сыпали"
	end

	return forms
end

conjugations["irreg-лгать"] = function(args)
	-- irregular, only for verbs derived from лгать with the same stress pattern
	local forms = {}

	local prefix = args[2] or ""

	forms["infinitive"] = prefix .. "лга́ть"

	forms["past_actv_part"] = prefix .. "лга́вший"
	forms["pres_pasv_part"] = ""
	forms["past_adv_part"] = prefix .. "лга́вши"; forms["past_adv_part_short"] = prefix .. "лга́в"

	forms["pres_actv_part"] = prefix .. "лгу́щий"
	forms["pres_adv_part"] = ""

	forms["impr_sg"] = prefix .. "лги́"
	forms["impr_pl"] = prefix .. "лги́те"

	forms["pres_futr_1sg"] = prefix .. "лгу́"
	forms["pres_futr_2sg"] = prefix .. "лжёшь"
	forms["pres_futr_3sg"] = prefix .. "лжёт"
	forms["pres_futr_1pl"] = prefix .. "лжём"
	forms["pres_futr_2pl"] = prefix .. "лжёте"
	forms["pres_futr_3pl"] = prefix .. "лгу́т"

	forms["past_m"] = prefix .. "лга́л"
	forms["past_f"] = prefix .. "лгала́"
	forms["past_n"] = prefix .. "лга́ло"
	forms["past_pl"] = prefix .. "лга́ли"

	return forms
end

conjugations["irreg-мочь"] = function(args)
	-- irregular, only for verbs derived from мочь with the same stress pattern
	local forms = {}

	local prefix = args[2] or ""

	local no_past_adv = "0"

	forms["infinitive"] = prefix .. "мо́чь"

	forms["past_actv_part"] = prefix .. "мо́гший"
	forms["pres_pasv_part"] = ""

	forms["past_adv_part"] = ""; forms["past_adv_part_short"] = ""

	forms["pres_actv_part"] = prefix .. "мо́гущий"
	forms["pres_adv_part"] = ""

	forms["impr_sg"] = prefix .. "моги́"
	forms["impr_pl"] = prefix .. "моги́те"

	forms["pres_futr_1sg"] = prefix .. "могу́"
	forms["pres_futr_2sg"] = prefix .. "мо́жешь"
	forms["pres_futr_3sg"] = prefix .. "мо́жет"
	forms["pres_futr_1pl"] = prefix .. "мо́жем"
	forms["pres_futr_2pl"] = prefix .. "мо́жете"
	forms["pres_futr_3pl"] = prefix .. "мо́гут"

	forms["past_m"] = prefix .. "мо́г"
	forms["past_f"] = prefix .. "могла́"
	forms["past_n"] = prefix .. "могло́"
	forms["past_pl"] = prefix .. "могли́"

	return forms
end

conjugations["irreg-слать"] = function(args)
	-- irregular, only for verbs derived from слать
	local forms = {}

	local prefix = args[2] or ""

	forms["infinitive"] = prefix .. "сла́ть"

	forms["past_actv_part"] = prefix .. "сла́вший"
	forms["pres_pasv_part"] = ""
	forms["past_adv_part"] = prefix .. "сла́вши"; forms["past_adv_part_short"] = prefix .. "сла́в"

	forms["pres_actv_part"] = prefix .. "шлю́щий"
	forms["pres_adv_part"] = ""

	forms["impr_sg"] = prefix .. "шли́"
	forms["impr_pl"] = prefix .. "шли́те"

	forms["pres_futr_1sg"] = prefix .. "шлю́"
	forms["pres_futr_2sg"] = prefix .. "шлёшь"
	forms["pres_futr_3sg"] = prefix .. "шлёт"
	forms["pres_futr_1pl"] = prefix .. "шлём"
	forms["pres_futr_2pl"] = prefix .. "шлёте"
	forms["pres_futr_3pl"] = prefix .. "шлю́т"

	forms["past_m"] = prefix .. "сла́л"
	forms["past_f"] = prefix .. "сла́ла"
	forms["past_n"] = prefix .. "сла́ло"
	forms["past_pl"] = prefix .. "сла́ли"

	-- вы́слать (perfective)
	if prefix == "вы́" then
		forms["infinitive"] = prefix .. "слать"
		forms["past_actv_part"] = prefix .. "славший"
		forms["past_adv_part"] = prefix .. "славши"; forms["past_adv_part_short"] = prefix .. "слав"

		forms["impr_sg"] = prefix .. "шли"
		forms["impr_pl"] = prefix .. "шлите"

		forms["pres_futr_1sg"] = prefix .. "шлю"
		forms["pres_futr_2sg"] = prefix .. "шлешь"
		forms["pres_futr_3sg"] = prefix .. "шлет"
		forms["pres_futr_1pl"] = prefix .. "шлем"
		forms["pres_futr_2pl"] = prefix .. "шлете"
		forms["pres_futr_3pl"] = prefix .. "шлют"

		forms["past_m"] = prefix .. "слал"
		forms["past_f"] = prefix .. "слала"
		forms["past_n"] = prefix .. "слало"
		forms["past_pl"] = prefix .. "слали"
	end

	return forms
end

conjugations["irreg-идти"] = function(args)
	-- irregular, only for verbs derived from идти, including прийти́ and в́ыйти
	local forms = {}

	local prefix = args[2] or ""

	forms["pres_pasv_part"] = ""

	if prefix == "вы́" then
		forms["infinitive"] = prefix .. "йти"
		forms["impr_sg"] = prefix .. "йди"
		forms["impr_pl"] = prefix .. "йдите"
		present_e_a(forms, prefix .. "йд")
		forms["past_adv_part"] = prefix .. "шедши"; forms["past_adv_part_short"] = prefix .. "йдя"
	elseif prefix == "при" then
		forms["infinitive"] = prefix .. "йти́"
		forms["impr_sg"] = prefix .. "ди́"
		forms["impr_pl"] = prefix .. "ди́те"
		present_e_b(forms, prefix .. "д")
		forms["past_adv_part"] = prefix .. "ше́дши"; forms["past_adv_part_short"] = prefix .. "дя́"
	else
		forms["infinitive"] = prefix .. "йти́"
		forms["pres_actv_part"] = prefix .. "иду́щий"
		forms["impr_sg"] = prefix .. "йди́"
		forms["impr_pl"] = prefix .. "йди́те"
		present_e_b(forms, prefix .. "йд")
		forms["past_adv_part"] = prefix .. "ше́дши"; forms["past_adv_part_short"] = prefix .. "йдя́"
	end

	-- only идти, present imperfective
	if prefix == "" then
		--only used with imperfective идти
		forms["pres_adv_part"] = "идя́"
		forms["pres_actv_part"] = "иду́щий"
		forms["infinitive"] = "идти́"
		forms["pres_actv_part"] = "иду́щий"
		forms["impr_sg"] = "иди́"
		forms["impr_pl"] = "иди́те"
		present_e_b(forms, "ид")
		forms["past_adv_part"] = "ше́дши"; forms["past_adv_part_short"] = ""
	end

	-- вы́йти (perfective)
	if prefix == "вы́" then
		forms["past_actv_part"] = prefix .. "шедший"
		forms["past_m"] = prefix .. "шел"
		forms["past_f"] = prefix .. "шла"
		forms["past_n"] = prefix .. "шло"
		forms["past_pl"] = prefix .. "шли"
	else
		forms["past_actv_part"] = prefix .. "ше́дший"
		forms["past_m"] = prefix .. "шёл"
		forms["past_f"] = prefix .. "шла́"
		forms["past_n"] = prefix .. "шло́"
		forms["past_pl"] = prefix .. "шли́"
	end

	return forms
end

conjugations["irreg-ехать"] = function(args)
	-- irregular, only for verbs derived from ехать
	local forms = {}

	local prefix = args[2] or ""

	local pres_stem = prefix .. "е́д"
	local past_stem = prefix .. "е́х"
	-- вы́ехать
	if prefix == "вы́" then
		pres_stem = prefix .. "ед"
		past_stem = prefix .. "ех"
	end

	forms["infinitive"] = past_stem .. "ать"
	forms["past_actv_part"] = past_stem .. "авший"
	forms["pres_pasv_part"] = ""
	forms["past_adv_part"] = past_stem .. "авши"; forms["past_adv_part_short"] = past_stem .. "ав"
	--вы́ехать has no present
	forms["pres_actv_part"] = pres_stem .. "ущий"
	forms["pres_adv_part"] = ""

	--literary (special) imperative forms for ехать are поезжа́й, поезжа́йте
	if prefix == "" then
		forms["impr_sg"] = "поезжа́й"
		forms["impr_pl"] = "поезжа́йте"
		forms["impr_sg2"] = "езжа́й"
		forms["impr_pl2"] = "езжа́йте"
	elseif prefix == "вы́" then
		forms["impr_sg"] = "выезжа́й"
		forms["impr_pl"] = "выезжа́йте"
	else
		forms["impr_sg"] = prefix .. "езжа́й"
		forms["impr_pl"] = prefix .. "езжа́йте"
	end

	present_e_a(forms, pres_stem)

	forms["past_m"] = past_stem .. "ал"
	forms["past_f"] = past_stem .. "ала"
	forms["past_n"] = past_stem .. "ало"
	forms["past_pl"] = past_stem .. "али"

	return forms
end

conjugations["irreg-минуть"] = function(args)
	-- for the irregular verb "ми́нуть"
	local forms = {}

	local stem = getarg(args, 2)
	local stem_noa = com.make_unstressed(stem)

	forms["infinitive"] = stem .. "уть"

	forms["pres_actv_part"] = stem .. "у́щий"
	forms["past_actv_part"] = stem_noa .. "у́вший"
	forms["past_actv_part2"] = stem .. "увший"
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = ""
	forms["past_adv_part"] = stem_noa .. "у́вши"; forms["past_adv_part_short"] = stem_noa .. "у́в"
	forms["past_adv_part2"] = stem .. "увши"; forms["past_adv_part_short2"] = stem .. "ув"

	present_e_c(forms, stem)

	-- no imperative
	forms["impr_sg"] = ""
	forms["impr_pl"] = ""

	forms["past_m"] = stem_noa .. "у́л"
	forms["past_f"] = stem_noa .. "у́ла"
	forms["past_n"] = stem_noa .. "у́ло"
	forms["past_pl"] = stem_noa .. "у́ли"
	forms["past_m2"] = stem .. "ул"
	forms["past_f2"] = stem .. "ула"
	forms["past_n2"] = stem .. "уло"
	forms["past_pl2"] = stem .. "ули"

	return forms
end

conjugations["irreg-живописать-миновать"] = function(args)
	-- for irregular verbs "живописа́ть" and "минова́ть", mixture of types 1 and 2
	local forms = {}

	local inf_stem = getarg(args, 2)
	local pres_stem = getarg(args, 3)

	forms["infinitive"] = inf_stem .. "ть"

	forms["pres_actv_part"] = pres_stem .. "ющий"
	forms["past_actv_part"] = inf_stem .. "вший"
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = pres_stem .. "я"
	forms["past_adv_part"] = inf_stem .. "вши"; forms["past_adv_part_short"] = inf_stem .. "в"

	present_je_a(forms, pres_stem)

	forms["impr_sg"] = pres_stem .. "й"
	forms["impr_pl"] = pres_stem .. "йте"

	forms["past_m"] = inf_stem .. "л"
	forms["past_f"] = inf_stem .. "ла"
	forms["past_n"] = inf_stem .. "ло"
	forms["past_pl"] = inf_stem .. "ли"

	return forms
end

conjugations["irreg-лечь"] = function(args)
	-- irregular, only for verbs derived from лечь with the same stress pattern
	local forms = {}

	local prefix = args[2] or ""

	forms["infinitive"] = prefix .. "ле́чь"

	forms["past_actv_part"] = prefix .. "лёгший"
	forms["pres_pasv_part"] = ""

	forms["past_adv_part"] = prefix .. "лёгши"; forms["past_adv_part_short"] = ""

	forms["pres_actv_part"] = ""
	forms["pres_adv_part"] = ""

	forms["impr_sg"] = prefix .. "ля́г"
	forms["impr_pl"] = prefix .. "ля́гте"

	forms["pres_futr_1sg"] = prefix .. "ля́гу"
	forms["pres_futr_2sg"] = prefix .. "ля́жешь"
	forms["pres_futr_3sg"] = prefix .. "ля́жет"
	forms["pres_futr_1pl"] = prefix .. "ля́жем"
	forms["pres_futr_2pl"] = prefix .. "ля́жете"
	forms["pres_futr_3pl"] = prefix .. "ля́гут"

	forms["past_m"] = prefix .. "лёг"
	forms["past_f"] = prefix .. "легла́"
	forms["past_n"] = prefix .. "легло́"
	forms["past_pl"] = prefix .. "легли́"

	return forms
end

conjugations["irreg-зиждиться"] = function(args)
	-- irregular, only for verbs derived from зиждиться with the same stress pattern
	local forms = {}

	local prefix = args[2] or ""

	forms["infinitive"] = prefix .. "зи́ждить"

	forms["past_actv_part"] = prefix .. "зи́ждивший"
	forms["pres_pasv_part"] = ""

	forms["past_adv_part"] = prefix .. "зи́ждивши"; forms["past_adv_part_short"] = ""

	forms["pres_actv_part"] = prefix .. "зи́ждущий"
	forms["pres_adv_part"] = prefix .. "зи́ждя"

	forms["impr_sg"] = prefix .. "зи́жди"
	forms["impr_pl"] = prefix .. "зи́ждите"

	forms["pres_futr_1sg"] = prefix .. "зи́жду"
	forms["pres_futr_2sg"] = prefix .. "зи́ждешь"
	forms["pres_futr_3sg"] = prefix .. "зи́ждет"
	forms["pres_futr_1pl"] = prefix .. "зи́ждем"
	forms["pres_futr_2pl"] = prefix .. "зи́ждете"
	forms["pres_futr_3pl"] = prefix .. "зи́ждут"

	forms["past_m"] = prefix .. "зи́ждил"
	forms["past_f"] = prefix .. "зи́ждила"
	forms["past_n"] = prefix .. "зи́ждило"
	forms["past_pl"] = prefix .. "зи́ждили"

	return forms
end

conjugations["irreg-клясть"] = function(args)
	-- irregular, only for verbs derived from клясть with the same stress pattern
	local forms = {}

	local prefix = args[2] or ""

	forms["infinitive"] = prefix .. "кля́сть"

	forms["past_actv_part"] = prefix .. "кля́вший"
	forms["pres_pasv_part"] = prefix .. "кляну́щий"

	forms["past_adv_part"] = prefix .. "кля́вши"; forms["past_adv_part_short"]  =prefix .. "кля́в"

	forms["pres_actv_part"] = prefix .. "кляну́щий"
	forms["pres_adv_part"] = prefix .. "кляня́"

	forms["impr_sg"] = prefix .. "кляни́"
	forms["impr_pl"] = prefix .. "кляни́те"

	forms["pres_futr_1sg"] = prefix .. "кляну́"
	forms["pres_futr_2sg"] = prefix .. "клянёшь"
	forms["pres_futr_3sg"] = prefix .. "клянёт"
	forms["pres_futr_1pl"] = prefix .. "клянём"
	forms["pres_futr_2pl"] = prefix .. "клянёте"
	forms["pres_futr_3pl"] = prefix .. "кляну́т"

	if args["past_m"] then
		forms["past_m"] = args["past_m"]
		forms["past_n"] = args["past_m"] .. "о"
		forms["past_pl"] = args["past_m"] .. "и"
	else
		forms["past_m"] = prefix .. "кля́л"
		forms["past_n"] = prefix .. "кля́ло"
		forms["past_pl"] = prefix .. "кля́ли"
	end

	forms["past_f"] = prefix .. "кляла́"

	return forms
end

conjugations["irreg-слыхать-видать"] = function(args)
	-- irregular, only for isolated verbs derived from слыхать or видать with the same stress pattern
	local forms = {}

	local stem = getarg(args, 2)

	forms["infinitive"] = stem .. "ть"

	forms["past_actv_part"] = stem .. "вший"
	forms["pres_pasv_part"] = ""

	forms["past_adv_part"] = stem .. "вши"; forms["past_adv_part_short"] = stem .. "в"

	-- no present forms or imperatives
	forms["pres_actv_part"] = ""
	forms["pres_adv_part"] = ""

	forms["impr_sg"] = ""
	forms["impr_pl"] = ""

	forms["pres_futr_1sg"] = ""
	forms["pres_futr_2sg"] = ""
	forms["pres_futr_3sg"] = ""
	forms["pres_futr_1pl"] = ""
	forms["pres_futr_2pl"] = ""
	forms["pres_futr_3pl"] = ""

	forms["past_m"] = stem .. "л"
	forms["past_f"] = stem .. "ла"
	forms["past_n"] = stem .. "ло"
	forms["past_pl"] = stem .. "ли"

	return forms
end

conjugations["irreg-стелить-стлать"] = function(args)
	-- irregular, only for verbs derived from стелить and стлать with the same stress pattern
	local forms = {}

	local stem = getarg(args, 2)
	local prefix = args[3] or ""

	forms["infinitive"] = prefix .. stem .. "ть"

	forms["past_actv_part"] = prefix .. stem .. "вший"
	forms["pres_pasv_part"] = prefix .. "стели́мый"
	forms["past_adv_part"] = prefix .. stem .. "вши"; forms["past_adv_part_short"] = prefix  .. stem .. "в"

	forms["pres_actv_part"] = prefix .. "сте́лющий"
	forms["pres_adv_part"] = prefix .. "стеля́"

	forms["impr_sg"] = prefix .. "стели́"
	forms["impr_pl"] = prefix .. "стели́те"

	forms["pres_futr_1sg"] = prefix .. "стелю́"
	forms["pres_futr_2sg"] = prefix .. "сте́лешь"
	forms["pres_futr_3sg"] = prefix .. "сте́лет"
	forms["pres_futr_1pl"] = prefix .. "сте́лем"
	forms["pres_futr_2pl"] = prefix .. "сте́лете"
	forms["pres_futr_3pl"] = prefix .. "сте́лют"

	forms["past_m"] = prefix .. stem .. "л"
	forms["past_f"] = prefix .. stem .. "ла"
	forms["past_n"] = prefix .. stem .. "ло"
	forms["past_pl"] = prefix .. stem .. "ли"

	return forms
end

conjugations["irreg-быть"] = function(args)
	-- irregular, only for verbs derived from быть with various stress patterns, the actual verb быть different from its derivatives
	local forms = {}

	local prefix = args[2] or ""
	local past_m = args["past_m"]
	local past_f = args["past_f"]
	local past_n = args["past_n"]
	local past_pl = args["past_pl"]

	if prefix == ""
		then forms["infinitive"] = "бы́ть"
	else
		forms["infinitive"] = prefix .. "бы́ть"
	end

	forms["past_actv_part"] = prefix .. "бы́вший"

	forms["pres_pasv_part"] = ""

	--only for "бы́ть" - бу́дучи
	if forms["infinitive"] == "бы́ть" then
		forms["past_adv_part"] = "бу́дучи"; forms["past_adv_part_short"] = ""
	end

	forms["past_adv_part"] = prefix .. "бы́вши"; forms["past_adv_part_short"] = prefix .. "бы́в"

	-- if the prefix is stressed
	if rfind(prefix, "[́]") then
		forms["past_adv_part"] = prefix .. "бывши"; forms["past_adv_part_short"] = prefix .. "быв"
	end

	forms["pres_actv_part"] = "су́щий"
	forms["pres_adv_part"] = ""

	forms["impr_sg"] = prefix .. "бу́дь"
	forms["impr_pl"] = prefix .. "бу́дьте"

	-- only for "бы́ть", some forms are archaic
	if forms["infinitive"] == "бы́ть" then
		forms["pres_futr_1sg"] = "есмь"
		forms["pres_futr_2sg"] = "еси́"
		forms["pres_futr_3sg"] = "есть"
		forms["pres_futr_1pl"] = "есмы́"
		forms["pres_futr_2pl"] = "е́сте"
		forms["pres_futr_3pl"] = "суть"
	else
		forms["pres_futr_1sg"] = prefix .. "бу́ду"
		forms["pres_futr_2sg"] = prefix .. "бу́дешь"
		forms["pres_futr_3sg"] = prefix .. "бу́дет"
		forms["pres_futr_1pl"] = prefix .. "бу́дем"
		forms["pres_futr_2pl"] = prefix .. "бу́дете"
		forms["pres_futr_3pl"] = prefix .. "бу́дут"
	end

	-- if the prefix is stressed, e.g. "вы́быть"
	if rfind(prefix, "[́]") then
		forms["pres_futr_1sg"] = prefix .. "буду"
		forms["pres_futr_2sg"] = prefix .. "будешь"
		forms["pres_futr_3sg"] = prefix .. "будет"
		forms["pres_futr_1pl"] = prefix .. "будем"
		forms["pres_futr_2pl"] = prefix .. "будете"
		forms["pres_futr_3pl"] = prefix .. "будут"
	end

	forms["past_m"] = prefix .. "бы́л"
	forms["past_f"] = prefix .. "была́"
	forms["past_n"] = prefix .. "бы́ло"
	forms["past_pl"] = prefix .. "бы́ли"

	-- if the prefix is stressed
	if rfind(prefix, "[́]") then
		forms["past_m"] = prefix .. "был"
		forms["past_f"] = prefix .. "была"
		forms["past_n"] = prefix .. "было"
		forms["past_pl"] = prefix .. "были"
	end

	-- при́был
	if past_m then
		forms["past_m"] = past_m
	end
	-- прибыла́
	if past_f then
		forms["past_f"] = past_f
	end
	-- сбыло́сь
	if past_n then
		forms["past_n"] = past_n
	end
	-- сбыли́сь
	if past_pl then
		forms["past_pl"] = past_pl
	end

	return forms
end

conjugations["irreg-ссать-сцать"] = function(args)
	-- irregular, only for verbs derived from ссать and сцать (both vulgar!)
	local forms = {}

	local stem = getarg(args, 2)
	local pres_stem = getarg(args, 3)

	local prefix = args[4] or ""
	-- if the prefix is stressed, remove stress from the stem
	if rfind(prefix, "[́]") then
		stem = com.remove_accents(stem)
	end

	forms["infinitive"] = prefix .. stem .. "ть"

	-- if the prefix is stressed
	if rfind(prefix, "[́]") then
		forms["pres_actv_part"] = prefix .. pres_stem .. "ущий"

		forms["impr_sg"] = prefix .. pres_stem .. "ы"
		forms["impr_pl"] = prefix .. pres_stem .. "ыте"

		forms["pres_futr_1sg"] = prefix .. pres_stem .. "у"
		forms["pres_futr_2sg"] = prefix .. pres_stem .. "ышь"
		forms["pres_futr_3sg"] = prefix .. pres_stem .. "ыт"
		forms["pres_futr_1pl"] = prefix .. pres_stem .. "ым"
		forms["pres_futr_2pl"] = prefix .. pres_stem .. "ыте"
		forms["pres_futr_3pl"] = prefix .. pres_stem .. "ут"
	else
		forms["pres_actv_part"] = prefix .. pres_stem .. "у́щий"

		forms["impr_sg"] = prefix .. pres_stem .. "ы́"
		forms["impr_pl"] = prefix .. pres_stem .. "ы́те"

		forms["pres_futr_1sg"] = prefix .. pres_stem .. "у́"
		forms["pres_futr_2sg"] = prefix .. pres_stem .. "ы́шь"
		forms["pres_futr_3sg"] = prefix .. pres_stem .. "ы́т"
		forms["pres_futr_1pl"] = prefix .. pres_stem .. "ы́м"
		forms["pres_futr_2pl"] = prefix .. pres_stem .. "ы́те"
		forms["pres_futr_3pl"] = prefix .. pres_stem .. "у́т"
	end

	forms["past_actv_part"] = prefix .. stem .. "вший"
	forms["pres_pasv_part"] = ""
	forms["past_adv_part"] = prefix .. stem .. "вши"; forms["past_adv_part_short"] = prefix  .. stem .. "в"

	forms["pres_adv_part"] = ""

	forms["past_m"] = prefix .. stem .. "л"
	forms["past_f"] = prefix .. stem .. "ла"
	forms["past_n"] = prefix .. stem .. "ло"
	forms["past_pl"] = prefix .. stem .. "ли"

	return forms
end

conjugations["irreg-чтить"] = function(args)
	-- irregular, only for verbs derived from чтить
	local forms = {}
	
	local prefix = args[2] or ""
	
	forms["infinitive"] = prefix .. "чти́ть"
 
	forms["past_actv_part"] = prefix .. "чти́вший"
	forms["pres_pasv_part"] = "чти́мый"
	forms["past_adv_part"] = prefix .. "чти́вши"; forms["past_adv_part_short"] = prefix .. "чти́в"
 
	forms["pres_actv_part"] = prefix .. "чтя́щий"
	forms["pres_actv_part2"] = prefix .. "чту́щий"
	forms["pres_adv_part"] = prefix .. "чтя́"
 
	forms["impr_sg"] = prefix .. "чти́"
	forms["impr_pl"] = prefix .. "чти́те"
 
	forms["pres_futr_1sg"] = prefix .. "чту́"
	forms["pres_futr_2sg"] = prefix .. "чти́шь"
	forms["pres_futr_3sg"] = prefix .. "чти́т"
	forms["pres_futr_1pl"] = prefix .. "чти́м"
	forms["pres_futr_2pl"] = prefix .. "чти́те"
	forms["pres_futr_3pl"] = prefix .. "чтя́т"
	forms["pres_futr_3pl2"] = prefix .. "чту́т"
 
	forms["past_m"] = prefix .. "чти́л"
	forms["past_f"] = prefix .. "чти́ла"
	forms["past_n"] = prefix .. "чти́ло"
	forms["past_pl"] = prefix .. "чти́ли"
 
	return forms
end

conjugations["irreg-ошибиться"] = function(args)
	-- irregular, only for for ошибиться
	local forms = {}
	
	local prefix = args[2] or ""
	
	forms["infinitive"] = prefix .. "ошиби́ть"
 
	forms["past_actv_part"] = prefix .. "ошиби́вший"
	forms["pres_pasv_part"] = ""
	forms["past_adv_part"] = prefix .. "ошиби́вши"; forms["past_adv_part_short"] = ""
 
	forms["pres_actv_part"] = ""
	forms["pres_actv_part2"] = ""
	forms["pres_adv_part"] = ""
 
	forms["impr_sg"] = prefix .. "ошиби́"
	forms["impr_pl"] = prefix .. "ошиби́те"
 
	forms["pres_futr_1sg"] = prefix .. "ошибу́"
	forms["pres_futr_2sg"] = prefix .. "ошибёшь"
	forms["pres_futr_3sg"] = prefix .. "ошибёт"
	forms["pres_futr_1pl"] = prefix .. "ошибём"
	forms["pres_futr_2pl"] = prefix .. "ошибёте"
	forms["pres_futr_3pl"] = prefix .. "ошибу́т"
 
	forms["past_m"] = prefix .. "оши́б"
	forms["past_f"] = prefix .. "оши́бла"
	forms["past_n"] = prefix .. "оши́бло"
	forms["past_pl"] = prefix .. "оши́бли"
 
	return forms
end

conjugations["irreg-плескать"] = function(args)
	-- irregular, only for verbs derived from плескать
	local forms = {}

	local prefix = args[2] or ""

	forms["infinitive"] = prefix .. "плеска́ть"

	forms["past_actv_part"] = prefix .. "плеска́вший"
	forms["pres_pasv_part"] = prefix .. "плеска́емый"
	forms["past_adv_part"] = prefix .. "плеска́вши"; forms["past_adv_part_short"] = prefix .. "плеска́в"

	forms["pres_actv_part"] = prefix .. "плеска́ющий"
	forms["pres_actv_part2"] = prefix .. "пле́щущий"
	forms["pres_adv_part"] = prefix .. "плеска́я"
	forms["pres_adv_part2"] = prefix .. "плеща́"

	forms["impr_sg"] = prefix .. "плеска́й"
	forms["impr_sg2"] = prefix .. "плещи́"
	forms["impr_pl"] = prefix .. "плеска́йте"
	forms["impr_pl2"] = prefix .. "плещи́те"

	forms["pres_futr_1sg"] = prefix .. "плеска́ю"
	forms["pres_futr_2sg"] = prefix .. "плеска́ешь"
	forms["pres_futr_3sg"] = prefix .. "плеска́ет"
	forms["pres_futr_1pl"] = prefix .. "плеска́ем"
	forms["pres_futr_2pl"] = prefix .. "плеска́ете"
	forms["pres_futr_3pl"] = prefix .. "плеска́ют"

	forms["pres_futr_1sg2"] = prefix .. "плещу́"
	forms["pres_futr_2sg2"] = prefix .. "пле́щешь"
	forms["pres_futr_3sg2"] = prefix .. "пле́щет"
	forms["pres_futr_1pl2"] = prefix .. "пле́щем"
	forms["pres_futr_2pl2"] = prefix .. "пле́щете"
	forms["pres_futr_3pl2"] = prefix .. "пле́щут"

	forms["past_m"] = prefix .. "плеска́л"
	forms["past_f"] = prefix .. "плеска́ла"
	forms["past_n"] = prefix .. "плеска́ло"
	forms["past_pl"] = prefix .. "плеска́ли"

	return forms
end

 conjugations["irreg-реветь"] = function(args)
	-- irregular, only for verbs derived from "реветь"
	local forms = {}
 
	local prefix = args[2] or ""
 
	forms["infinitive"] = prefix .. "реве́ть"
 
	forms["pres_actv_part"] = prefix .. "реву́щий"
	forms["past_actv_part"] = prefix .. "реве́вший"
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = prefix .. "ревя́"
	forms["past_adv_part"] = prefix .. "реве́вши"; forms["past_adv_part_short"] = prefix .. "реве́в"
 
	forms["pres_futr_1sg"] = prefix .. "реву́"
	forms["pres_futr_2sg"] = prefix .. "ревёшь"
	forms["pres_futr_3sg"] = prefix .. "ревёт"
	forms["pres_futr_1pl"] = prefix .. "ревём"
	forms["pres_futr_2pl"] = prefix .. "ревёте"
	forms["pres_futr_3pl"] = prefix .. "реву́т"
 
	-- no imperative
	forms["impr_sg"] = prefix .. "реви́"
	forms["impr_pl"] = prefix .. "реви́те"
 
	forms["past_m"] = prefix .. "реве́л"
	forms["past_f"] = prefix .. "реве́ла"
	forms["past_n"] = prefix .. "реве́ло"
	forms["past_pl"] = prefix .. "реве́ли"

	return forms
end

conjugations["irreg-внимать"] = function(args)
	-- irregular, only for verbs derived from внимать
	local forms = {}
 
	local prefix = args[2] or ""
 
	forms["infinitive"] = prefix .. "внима́ть"
 
	forms["past_actv_part"] = prefix .. "внима́вший"
	forms["pres_pasv_part"] = prefix .. "вне́млемый"
	forms["pres_pasv_part2"] = prefix .. "внима́емый"
	forms["past_adv_part"] = prefix .. "внима́вши"; forms["past_adv_part_short"] = prefix .. "внима́в"
 
	forms["pres_actv_part"] = prefix .. "вне́млющий"
	forms["pres_actv_part2"] = prefix .. "внима́ющий"
	forms["pres_adv_part"] = prefix .. "вне́мля́"
	forms["pres_adv_part2"] = prefix .. "внима́я"
 
	forms["impr_sg"] = prefix .. "вне́мли́"
	forms["impr_pl"] = prefix .. "вне́мли́те"
	forms["impr_sg2"] = prefix .. "внима́й"
	forms["impr_pl2"] = prefix .. "внима́йте"
 
	forms["pres_futr_1sg"] = prefix .. "вне́млю́"
	forms["pres_futr_2sg"] = prefix .. "вне́млешь"
	forms["pres_futr_3sg"] = prefix .. "вне́млет"
	forms["pres_futr_1pl"] = prefix .. "вне́млем"
	forms["pres_futr_2pl"] = prefix .. "вне́млете"
	forms["pres_futr_3pl"] = prefix .. "вне́млют"
	
	forms["pres_futr_1sg2"] = prefix .. "внима́ю"
	forms["pres_futr_2sg2"] = prefix .. "внима́ешь"
	forms["pres_futr_3sg2"] = prefix .. "внима́ет"
	forms["pres_futr_1pl2"] = prefix .. "внима́ем"
	forms["pres_futr_2pl2"] = prefix .. "внима́ете"
	forms["pres_futr_3pl2"] = prefix .. "внима́ют"
 
	forms["past_m"] = prefix .. "внима́л"
	forms["past_f"] = prefix .. "внима́ла"
	forms["past_n"] = prefix .. "внима́ло"
	forms["past_pl"] = prefix .. "внима́ли"
 
	return forms
end

conjugations["irreg-обязывать"] = function(args)
	-- irregular, only for the reflexive verb обязаться
	local forms = {}

	local prefix = args[2] or ""
	local past_m = args["past_m"]
	local past_m2 = args["past_m2"]
	local past_f = args["past_f"]
	local past_n = args["past_n"]
	local past_pl = args["past_pl"]

	forms["infinitive"] = prefix .. "обя́зывать"

	forms["past_actv_part"] = prefix .. "обя́зывавший"
	forms["pres_pasv_part"] = prefix .. "обя́зываемый"
	forms["pres_pasv_part2"] = prefix .. "обязу́емый"
	forms["past_adv_part"] = prefix .. "обя́зывавши"; forms["past_adv_part_short"] = prefix .. "обя́зывав"

	forms["pres_actv_part"] = prefix .. "обя́зывающий"
	forms["pres_actv_part2"] = prefix .. "обязу́ющий"
	forms["pres_adv_part"] = prefix .. "обя́зывая"
	forms["pres_adv_part2"] = prefix .. "обязу́я"

	forms["impr_sg"] = prefix .. "обя́зывай"
	forms["impr_sg2"] = prefix .. "обязу́й"
	forms["impr_pl"] = prefix .. "обя́зывайте"
	forms["impr_pl2"] = prefix .. "обязу́йте"

	forms["pres_futr_1sg"] = prefix .. "обя́зываю"
	forms["pres_futr_2sg"] = prefix .. "обя́зываешь"
	forms["pres_futr_3sg"] = prefix .. "обя́зывает"
	forms["pres_futr_1pl"] = prefix .. "обя́зываем"
	forms["pres_futr_2pl"] = prefix .. "обя́зываете"
	forms["pres_futr_3pl"] = prefix .. "обя́зывают"

	forms["pres_futr_1sg2"] = prefix .. "обязу́ю"
	forms["pres_futr_2sg2"] = prefix .. "обязу́ешь"
	forms["pres_futr_3sg2"] = prefix .. "обязу́ет"
	forms["pres_futr_1pl2"] = prefix .. "обязу́ем"
	forms["pres_futr_2pl2"] = prefix .. "обязу́ете"
	forms["pres_futr_3pl2"] = prefix .. "обязу́ют"	

	forms["past_m"] = prefix .. "обя́зывал"
	forms["past_f"] = prefix .. "обя́зывала"
	forms["past_n"] = prefix .. "обя́зывало"
	forms["past_pl"] = prefix .. "обя́зывали"

	return forms
end

--[=[
	Partial conjugation functions
]=]--

-- Present forms with -e-, no j-vowels.
present_e_a = function(forms, stem)

	forms["pres_futr_1sg"] = stem .. "у"
	forms["pres_futr_2sg"] = stem .. "ешь"
	forms["pres_futr_3sg"] = stem .. "ет"
	forms["pres_futr_1pl"] = stem .. "ем"
	forms["pres_futr_2pl"] = stem .. "ете"
	forms["pres_futr_3pl"] = stem .. "ут"
end

present_e_b = function(forms, stem)

	if rfind(stem, "[аэыоуяеиёю́]$") then
		forms["pres_futr_1sg"] = stem .. "ю́"
		forms["pres_futr_3pl"] = stem .. "ю́т"
	else
		forms["pres_futr_1sg"] = stem .. "у́"
		forms["pres_futr_3pl"] = stem .. "у́т"
	end

	forms["pres_futr_2sg"] = stem .. "ёшь"
	forms["pres_futr_3sg"] = stem .. "ёт"
	forms["pres_futr_1pl"] = stem .. "ём"
	forms["pres_futr_2pl"] = stem .. "ёте"
end

present_e_c = function(forms, stem)
	local stem_noa = com.make_unstressed(stem)

	forms["pres_futr_1sg"] = stem_noa .. "у́"
	forms["pres_futr_2sg"] = stem .. "ешь"
	forms["pres_futr_3sg"] = stem .. "ет"
	forms["pres_futr_1pl"] = stem .. "ем"
	forms["pres_futr_2pl"] = stem .. "ете"
	forms["pres_futr_3pl"] = stem .. "ут"
end

-- Present forms with -e-, with j-vowels.
present_je_a = function(forms, stem, no_iotation)
	local iotated_stem = com.iotation(stem, shch)

	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	if rfind(iotated_stem, "[шщжч]$") then
		forms["pres_futr_1sg"] = iotated_stem .. "у"
	else
		forms["pres_futr_1sg"] = iotated_stem .. "ю"
	end

	if rfind(iotated_stem, "[шщжч]$") then
		forms["pres_futr_3pl"] = iotated_stem .. "ут"
	else
		forms["pres_futr_3pl"] = iotated_stem .. "ют"
	end

	forms["pres_futr_2sg"] = iotated_stem .. "ешь"
	forms["pres_futr_3sg"] = iotated_stem .. "ет"
	forms["pres_futr_1pl"] = iotated_stem .. "ем"
	forms["pres_futr_2pl"] = iotated_stem .. "ете"

	if no_iotation then
		forms["pres_futr_1sg"] = stem .. "у"
		forms["pres_futr_3pl"] = stem .. "ут"
		forms["pres_futr_2sg"] = stem .. "ешь"
		forms["pres_futr_3sg"] = stem .. "ет"
		forms["pres_futr_1pl"] = stem .. "ем"
		forms["pres_futr_2pl"] = stem .. "ете"
	end
end

present_je_b = function(forms, stem)

	forms["pres_futr_1sg"] = stem .. "ю́"
	forms["pres_futr_2sg"] = stem .. "ёшь"
	forms["pres_futr_3sg"] = stem .. "ёт"
	forms["pres_futr_1pl"] = stem .. "ём"
	forms["pres_futr_2pl"] = stem .. "ёте"
	forms["pres_futr_3pl"] = stem .. "ю́т"
end

present_je_c = function(forms, stem, shch)
	-- shch - iotatate final т as щ, not ч

	-- iotate the stem
	local stem_noa = com.make_unstressed(stem)
	-- iotate the stem
	local iotated_stem = ""
	if not shch then
		iotated_stem = com.iotation(stem)
	else
		iotated_stem = com.iotation(stem, shch)
	end
	
	local iotated_stem_noa = com.make_unstressed(iotated_stem)

	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	if rfind(iotated_stem, "[шщжч]$") or no_iotation then
		forms["pres_futr_1sg"] = iotated_stem_noa .. "у́"
	else
		forms["pres_futr_1sg"] = iotated_stem_noa .. "ю́"
	end

	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	if rfind(iotated_stem, "[шщжч]$") or no_iotation then
		forms["pres_futr_3pl"] = iotated_stem .. "ут"
	else
		forms["pres_futr_3pl"] = iotated_stem .. "ют"
	end

	forms["pres_futr_2sg"] = iotated_stem .. "ешь"
	forms["pres_futr_3sg"] = iotated_stem .. "ет"
	forms["pres_futr_1pl"] = iotated_stem .. "ем"
	forms["pres_futr_2pl"] = iotated_stem .. "ете"
end

-- Present forms with -i-.
present_i_a = function(forms, stem, shch)
	-- shch - iotatate final т as щ, not ч
	-- iotate the stem
	local iotated_stem = com.iotation(stem, shch)

	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	if rfind(iotated_stem, "[шщжч]$") then
		forms["pres_futr_1sg"] = iotated_stem .. "у"
	else
		forms["pres_futr_1sg"] = iotated_stem .. "ю"
	end

	if rfind(stem, "[шщжч]$") then
		forms["pres_futr_3pl"] = stem .. "ат"
	else
		forms["pres_futr_3pl"] = stem .. "ят"
	end

	forms["pres_futr_2sg"] = stem .. "ишь"
	forms["pres_futr_3sg"] = stem .. "ит"
	forms["pres_futr_1pl"] = stem .. "им"
	forms["pres_futr_2pl"] = stem .. "ите"
end

present_i_b = function(forms, stem, no_1sg_futr, shch)
	-- parameter no_1sg_futr - no 1st person singular future if no_1sg_futr = 1
	if not no_1sg_futr then
		no_1sg_futr = 0
	end

	-- parameter shch - iotatate final т as щ, not ч
	if not shch then
		shch = ""
	end

	-- iotate the stem
	local iotated_stem = com.iotation(stem, shch)

	-- Make 1st person future singular blank if no_1sg_futr = 1
	if no_1sg_futr == 1 then
		forms["pres_futr_1sg"] = ""
	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	elseif rfind(iotated_stem, "[шщжч]$") then
		forms["pres_futr_1sg"] = iotated_stem .. "у́"
	else
		forms["pres_futr_1sg"] = iotated_stem .. "ю́"
	end

	if rfind(stem, "[шщжч]$") then
		forms["pres_futr_3pl"] = stem .. "а́т"
	else
		forms["pres_futr_3pl"] = stem .. "я́т"
	end

	forms["pres_futr_2sg"] = stem .. "и́шь"
	forms["pres_futr_3sg"] = stem .. "и́т"
	forms["pres_futr_1pl"] = stem .. "и́м"
	forms["pres_futr_2pl"] = stem .. "и́те"

end

present_i_c = function(forms, stem, shch)
	-- shch - iotatate final т as щ, not ч

	local stem_noa = com.make_unstressed(stem)
	-- iotate the stem
	local iotated_stem = com.iotation(stem_noa, shch)

	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	if rfind(iotated_stem, "[шщжч]$") then
		forms["pres_futr_1sg"] = iotated_stem .. "у́"
	else
		forms["pres_futr_1sg"] = iotated_stem .. "ю́"
	end

	if rfind(stem, "[шщжч]$") then
		forms["pres_futr_3pl"] = stem .. "ат"
	else
		forms["pres_futr_3pl"] = stem .. "ят"
	end

	if rfind(stem, "[шщжч]$") then
		forms["pres_futr_3pl"] = stem .. "ат"
	else
		forms["pres_futr_3pl"] = stem .. "ят"
	end

	forms["pres_futr_2sg"] = stem .. "ишь"
	forms["pres_futr_3sg"] = stem .. "ит"
	forms["pres_futr_1pl"] = stem .. "им"
	forms["pres_futr_2pl"] = stem .. "ите"
end

-- add alternative form stressed on the reflexive particle
make_reflexive_alt = function(forms)

	for key, form in pairs(forms) do
		if form ~= "" then
			-- if a form doesn't contain a stress, add a stressed particle "ся́"
			if not rfind(form, "[́]") then
				-- only applies to past masculine forms
				if key == "past_m" or key == "past_m2" or key == "past_m3" then
					forms[key] = form .. "ся́"
				end
			end
		end
	end
end

-- Add the reflexive particle to all verb forms
make_reflexive = function(forms)
	for key, form in pairs(forms) do
		-- The particle is "сь" after a vowel, "ся" after a consonant
		-- append "ся" if "ся́" was not attached already
		if form ~= "" and not rfind(form, "ся́$") then
			if rfind(form, "[аэыоуяеиёю́]$") then
				forms[key] = form .. "сь"
			else
				forms[key] = form .. "ся"
			end
		end
	end

	-- This form does not exist for reflexive verbs.
	forms["past_adv_part_short"] = ""
end

-- Make the table
make_table = function(forms, title, perf, intr, impers)
	local title = "Conjugation of <span lang=\"ru\" class=\"Cyrl\">''" .. forms["infinitive"] .. "''</span>" .. (title and " (" .. title .. ")" or "")

	-- Intransitive verbs have no passive participles.
	if intr then
		forms["pres_pasv_part"] = ""
		forms["pres_pasv_part2"] = nil
		forms["past_pasv_part"] = ""
		forms["past_pasv_part2"] = nil
	end

	if impers then
		forms["pres_futr_1sg"] = ""
		forms["pres_futr_2sg"] = ""
		forms["pres_futr_1pl"] = ""
		forms["pres_futr_2pl"] = ""
		forms["pres_futr_3pl"] = ""
		forms["past_m"] = ""
		forms["past_f"] = ""
		forms["past_pl"] = ""
		forms["pres_actv_part"] = ""
		forms["past_actv_part"] = ""
		forms["pres_adv_part"] = ""
		forms["past_adv_part"] = ""
		forms["past_adv_part_short"] = ""
		forms["impr_sg"] = ""
		forms["impr_pl"] = ""
		--alternatives
		forms["pres_futr_1sg2"] = nil
		forms["pres_futr_2sg2"] = nil
		forms["pres_futr_1pl2"] = nil
		forms["pres_futr_2pl2"] = nil
		forms["pres_futr_3pl2"] = nil
		forms["past_m2"] = nil
		forms["past_m3"] = nil
		forms["past_f2"] = nil
		forms["past_pl2"] = nil
		forms["pres_actv_part2"] = nil
		forms["past_actv_part2"] = nil
		forms["pres_adv_part2"] = nil
		forms["past_adv_part2"] = nil
		forms["past_adv_part_short2"] = nil
		forms["impr_sg2"] = nil
		forms["impr_pl2"] = nil
	end

	-- Perfective verbs have no present forms.
	if perf then
		forms["pres_actv_part"] = ""
		forms["pres_pasv_part"] = ""
		forms["pres_adv_part"] = ""
		forms["pres_1sg"] = ""
		forms["pres_2sg"] = ""
		forms["pres_3sg"] = ""
		forms["pres_1pl"] = ""
		forms["pres_2pl"] = ""
		forms["pres_3pl"] = ""
		--alternatives
		forms["pres_actv_part2"] = nil
		forms["pres_pasv_part2"] = nil
		forms["pres_adv_part2"] = nil
		forms["pres_1sg2"] = nil
		forms["pres_2sg2"] = nil
		forms["pres_3sg2"] = nil
		forms["pres_1pl2"] = nil
		forms["pres_2pl2"] = nil
		forms["pres_3pl2"] = nil

		forms["futr_1sg"] = forms["pres_futr_1sg"]
		forms["futr_2sg"] = forms["pres_futr_2sg"]
		forms["futr_3sg"] = forms["pres_futr_3sg"]
		forms["futr_1pl"] = forms["pres_futr_1pl"]
		forms["futr_2pl"] = forms["pres_futr_2pl"]
		forms["futr_3pl"] = forms["pres_futr_3pl"]
		-- alternatives
		forms["futr_1sg2"] = forms["pres_futr_1sg2"]
		forms["futr_2sg2"] = forms["pres_futr_2sg2"]
		forms["futr_3sg2"] = forms["pres_futr_3sg2"]
		forms["futr_1pl2"] = forms["pres_futr_1pl2"]
		forms["futr_2pl2"] = forms["pres_futr_2pl2"]
		forms["futr_3pl2"] = forms["pres_futr_3pl2"]
	else
		forms["pres_1sg"] = forms["pres_futr_1sg"]
		forms["pres_2sg"] = forms["pres_futr_2sg"]
		forms["pres_3sg"] = forms["pres_futr_3sg"]
		forms["pres_1pl"] = forms["pres_futr_1pl"]
		forms["pres_2pl"] = forms["pres_futr_2pl"]
		forms["pres_3pl"] = forms["pres_futr_3pl"]
		forms["pres_2sg"] = forms["pres_futr_2sg"]
		-- alternatives
		forms["pres_1sg2"] = forms["pres_futr_1sg2"]
		forms["pres_2sg2"] = forms["pres_futr_2sg2"]
		forms["pres_3sg2"] = forms["pres_futr_3sg2"]
		forms["pres_1pl2"] = forms["pres_futr_1pl2"]
		forms["pres_2pl2"] = forms["pres_futr_2pl2"]
		forms["pres_3pl2"] = forms["pres_futr_3pl2"]
	end
	
	local inf = forms["infinitive"]
	local inf_tr = lang:transliterate(forms["infinitive"])

	-- Add transliterations to all forms
	for key, form in pairs(forms) do
		-- check for empty strings, dashes and nil's
		if form ~= "" and form and form ~= "-" then
			forms[key] = "<span lang=\"ru\" class=\"Cyrl\">[[" .. com.remove_accents(form) .. "#Russian|" .. form .. "]]</span><br/><span style=\"color: #888\">" .. lang:transliterate(form) .. "</span>"
		else
			forms[key] = "&mdash;"
		end
	end

	if not perf then
		forms["futr_1sg"] = "<span lang=\"ru\" class=\"Cyrl\">[[буду#Russian|бу́ду]] " .. inf .. "</span><br/><span style=\"color: #888\">búdu " .. inf_tr .. "</span>"
		forms["futr_2sg"] = "<span lang=\"ru\" class=\"Cyrl\">[[будешь#Russian|бу́дешь]] " .. inf .. "</span><br/><span style=\"color: #888\">búdešʹ " .. inf_tr .. "</span>"
		forms["futr_3sg"] = "<span lang=\"ru\" class=\"Cyrl\">[[будет#Russian|бу́дет]] " .. inf .. "</span><br/><span style=\"color: #888\">búdet " .. inf_tr .. "</span>"
		forms["futr_1pl"] = "<span lang=\"ru\" class=\"Cyrl\">[[будем#Russian|бу́дем]] " .. inf .. "</span><br/><span style=\"color: #888\">búdem " .. inf_tr .. "</span>"
		forms["futr_2pl"] = "<span lang=\"ru\" class=\"Cyrl\">[[будете#Russian|бу́дете]] " .. inf .. "</span><br/><span style=\"color: #888\">búdete " .. inf_tr .. "</span>"
		forms["futr_3pl"] = "<span lang=\"ru\" class=\"Cyrl\">[[будут#Russian|бу́дут]] " .. inf .. "</span><br/><span style=\"color: #888\">búdut " .. inf_tr .. "</span>"
	end

	-- only for "бы́ть" the future forms are бу́ду, бу́дешь, etc.
	if inf == "бы́ть" then
		forms["futr_1sg"] = "<span lang=\"ru\" class=\"Cyrl\">[[буду#Russian|бу́ду]] " .. "</span><br/><span style=\"color: #888\">búdu " .. "</span>"
		forms["futr_2sg"] = "<span lang=\"ru\" class=\"Cyrl\">[[будешь#Russian|бу́дешь]] " .. "</span><br/><span style=\"color: #888\">búdešʹ " .. "</span>"
		forms["futr_3sg"] = "<span lang=\"ru\" class=\"Cyrl\">[[будет#Russian|бу́дет]] "  .. "</span><br/><span style=\"color: #888\">búdet " .. "</span>"
		forms["futr_1pl"] = "<span lang=\"ru\" class=\"Cyrl\">[[будем#Russian|бу́дем]] "  .. "</span><br/><span style=\"color: #888\">búdem "  .. "</span>"
		forms["futr_2pl"] = "<span lang=\"ru\" class=\"Cyrl\">[[будете#Russian|бу́дете]] "  .. "</span><br/><span style=\"color: #888\">búdete "  .. "</span>"
		forms["futr_3pl"] = "<span lang=\"ru\" class=\"Cyrl\">[[будут#Russian|бу́дут]] "  .. "</span><br/><span style=\"color: #888\">búdut "  .. "</span>"
	end

	if impers then
		forms["futr_1sg"] = ""
		forms["futr_2sg"] = ""
		forms["futr_1pl"] = ""
		forms["futr_2pl"] = ""
		forms["futr_3pl"] = ""
		--alternatives
		forms["futr_1sg2"] = nil
		forms["futr_2sg2"] = nil
		forms["futr_1pl2"] = nil
		forms["futr_2pl2"] = nil
		forms["futr_3pl2"] = nil
	end

	-- alternative forms
	local alt_impr_sg = forms["impr_sg"]
	if forms["impr_sg2"] then alt_impr_sg = forms["impr_sg"] .. ",<br/>" .. forms["impr_sg2"] end
	local alt_impr_pl = forms["impr_pl"]
	if forms["impr_pl2"] then alt_impr_pl = forms["impr_pl"] .. ",<br/>" .. forms["impr_pl2"] end
	-- со́здал/созд́ал, п́ередал/переда́л, ́отдал/отд́ал
	local alt_past_m = forms["past_m"]
	if forms["past_m2"] then alt_past_m = forms["past_m"] .. ",<br/>" .. forms["past_m2"] end
	--for verbs with three past masculine sg forms: за́нялся, заня́лся, занялс́я (заня́ться)
	if forms["past_m3"] then alt_past_m = alt_past_m .. ",<br/>" .. forms["past_m3"] end
	-- short forms in 3a (исчез, сох, etc.)
	if forms["past_m_short"] then alt_past_m = forms["past_m_short"] .. ",<br/>" .. alt_past_m end
	local alt_past_f = forms["past_f"]
	if forms["past_f2"] then alt_past_f = forms["past_f"] .. ",<br/>" .. forms["past_f2"] end
	-- short forms in 3a (исчезла, сохла, etc.)
	if forms["past_f_short"] then alt_past_f = forms["past_f_short"] .. ",<br/>" .. alt_past_f end
	-- да́ло, дал́о; вз́яло, взяло́
	local alt_past_n = forms["past_n"]
	if forms["past_n2"] then alt_past_n = forms["past_n"] .. ",<br/>" .. forms["past_n2"] end
	-- short forms in 3a (исчезло, сохло, etc.)
	if forms["past_n_short"] then alt_past_n = forms["past_n_short"] .. ",<br/>" .. alt_past_n end
	-- разобрали́сь (разобрали́)
	local alt_past_pl = forms["past_pl"]
	if forms["past_pl2"] then alt_past_pl = forms["past_pl"] .. ",<br/>" .. forms["past_pl2"] end
	-- short forms in 3a (исчезли, сохли, etc.)
	if forms["past_pl_short"] then alt_past_pl = forms["past_pl_short"] .. ",<br/>" .. alt_past_pl end
	--
	-- тереть: тере́вши, тёрши, short: тере́в
	-- умереть: умере́вши, у́мерши, short: умере́в
	local past_adv_parts = {}
	if forms["past_adv_part_short"] ~= "&mdash;" then
		table.insert(past_adv_parts, forms["past_adv_part_short"])
	end
	if forms["past_adv_part_short2"] then
		table.insert(past_adv_parts, forms["past_adv_part_short2"])
	end
	table.insert(past_adv_parts, forms["past_adv_part"])
	if forms["past_adv_part2"] then
		table.insert(past_adv_parts, forms["past_adv_part2"])
	end
	local alt_past_adv_part = table.concat(past_adv_parts, ",<br/>")
	-- сыпля, сыпя
	local alt_pres_adv_part = forms["pres_adv_part"]
	if forms["pres_adv_part2"] and not perf then alt_pres_adv_part = forms["pres_adv_part"] .. ",<br/>" .. forms["pres_adv_part2"] end

	local alt_pres_1sg = forms["pres_1sg"]
	if forms["pres_1sg2"] and not perf then alt_pres_1sg = forms["pres_1sg"] .. ",<br/>" .. forms["pres_1sg2"] end
	-- сыплешь, сыпешь
	local alt_pres_2sg = forms["pres_2sg"]
	if forms["pres_2sg2"] and not perf then alt_pres_2sg = forms["pres_2sg"] .. ",<br/>" .. forms["pres_2sg2"] end
	-- сыплет, сыпет
	local alt_pres_3sg = forms["pres_3sg"]
	if forms["pres_3sg2"] and not perf then alt_pres_3sg = forms["pres_3sg"] .. ",<br/>" .. forms["pres_3sg2"] end
	-- сыплем, сыпем
	local alt_pres_1pl = forms["pres_1pl"]
	if forms["pres_1pl2"] and not perf then alt_pres_1pl = forms["pres_1pl"] .. ",<br/>" .. forms["pres_1pl2"] end
	-- сыплете, сыпете
	local alt_pres_2pl = forms["pres_2pl"]
	if forms["pres_2pl2"] and not perf then alt_pres_2pl = forms["pres_2pl"] .. ",<br/>" .. forms["pres_2pl2"] end
	-- сыплют, сыпют
	local alt_pres_3pl = forms["pres_3pl"]
	if forms["pres_3pl2"] and not perf then alt_pres_3pl = forms["pres_3pl"] .. ",<br/>" .. forms["pres_3pl2"] end
	local alt_futr_1sg = forms["futr_1sg"]
	if forms["futr_1sg2"] then alt_futr_1sg = forms["futr_1sg"] .. ",<br/>" .. forms["futr_1sg2"] end
	-- насыплешь, насыпешь
	local alt_futr_2sg = forms["futr_2sg"]
	if forms["futr_2sg2"] then alt_futr_2sg = forms["futr_2sg"] .. ",<br/>" .. forms["futr_2sg2"] end
	-- насыплет, насыпет
	local alt_futr_3sg = forms["futr_3sg"]
	if forms["futr_3sg2"] then alt_futr_3sg = forms["futr_3sg"] .. ",<br/>" .. forms["futr_3sg2"] end
	-- насыплем, насыпем
	local alt_futr_1pl = forms["futr_1pl"]
	if forms["futr_1pl2"] then alt_futr_1pl = forms["futr_1pl"] .. ",<br/>" .. forms["futr_1pl2"] end
	-- насыплете, насыпете
	local alt_futr_2pl = forms["futr_2pl"]
	if forms["futr_2pl2"] then alt_futr_2pl = forms["futr_2pl"] .. ",<br/>" .. forms["futr_2pl2"] end
	-- насыплют, насыпют
	local alt_futr_3pl = forms["futr_3pl"]
	if forms["futr_3pl2"] then alt_futr_3pl = forms["futr_3pl"] .. ",<br/>" .. forms["futr_3pl2"] end

	local alt_pres_actv_part = forms["pres_actv_part"]
	if forms["pres_actv_part2"] then alt_pres_actv_part = forms["pres_actv_part"] .. ",<br/>" .. forms["pres_actv_part2"] end

	local alt_past_actv_part = forms["past_actv_part"]
	if forms["past_actv_part2"] then alt_past_actv_part = forms["past_actv_part"] .. ",<br/>" .. forms["past_actv_part2"] end

	local alt_pres_pasv_part = forms["pres_pasv_part"]
	if forms["pres_pasv_part2"] then alt_pres_pasv_part = forms["pres_pasv_part"] .. ",<br/>" .. forms["pres_pasv_part2"] end

	local alt_past_pasv_part = forms["past_pasv_part"]
	if forms["past_pasv_part2"] then alt_past_pasv_part = forms["past_pasv_part"] .. ",<br/>" .. forms["past_pasv_part2"] end

	return [=[<div class="NavFrame" style="width:49.6em;">
<div class="NavHead" style="text-align:left; background:#e0e0ff;">]=] .. title .. [=[</div>
<div class="NavContent">
{| class="inflection inflection-ru inflection-verb inflection-table"
|+ Note 1: for declension of participles, see their entries. Adverbial participles are indeclinable.
|- class="rowgroup"
! colspan="3" | ]=] .. (perf and [=[[[совершенный вид|perfective aspect]]]=] or [=[[[несовершенный вид|imperfective aspect]]]=]) .. [=[

|-
! [[неопределённая форма|infinitive]]
| colspan="2" | ]=] .. forms["infinitive"] .. [=[

|- class="rowgroup"
! style="width:15em" | [[причастие|participles]]
! [[настоящее время|present tense]]
! [[прошедшее время|past tense]]
|-
! [[действительный залог|active]]
| ]=] .. alt_pres_actv_part .. [=[ || ]=] .. alt_past_actv_part .. [=[

|-
! [[страдательный залог|passive]]
| ]=] .. alt_pres_pasv_part .. [=[ || ]=] .. alt_past_pasv_part .. [=[

|-
! [[деепричастие|adverbial]]
| ]=] .. alt_pres_adv_part .. [=[ || ]=] .. alt_past_adv_part .. [=[

|- class="rowgroup"
!
! [[настоящее время|present tense]]
! [[будущее время|future tense]]
|-
! [[первое лицо|1st]] [[единственное число|singular]] (<span lang="ru" class="Cyrl">я</span>)
| ]=] .. alt_pres_1sg .. [=[ || ]=] .. alt_futr_1sg .. [=[

|-
! [[второе лицо|2nd]] [[единственное число|singular]] (<span lang="ru" class="Cyrl">ты</span>)
| ]=] .. alt_pres_2sg .. [=[ || ]=] .. alt_futr_2sg .. [=[

|-
! [[третье лицо|3rd]] [[единственное число|singular]] (<span lang="ru" class="Cyrl">он/она́/оно́</span>)
| ]=] .. alt_pres_3sg .. [=[ || ]=] .. alt_futr_3sg .. [=[

|-
! [[первое лицо|1st]] [[множественное число|plural]] (<span lang="ru" class="Cyrl">мы</span>)
| ]=] .. alt_pres_1pl .. [=[ || ]=] .. alt_futr_1pl .. [=[

|-
! [[второе лицо|2nd]] [[множественное число|plural]] (<span lang="ru" class="Cyrl">вы</span>)
| ]=] .. alt_pres_2pl .. [=[ || ]=] .. alt_futr_2pl .. [=[

|-
! [[третье лицо|3rd]] [[множественное число|plural]] (<span lang="ru" class="Cyrl">они́</span>)
| ]=] .. alt_pres_3pl .. [=[ || ]=] .. alt_futr_3pl .. [=[

|- class="rowgroup"
! [[повелительное наклонение|imperative]]
! [[единственное число|singular]]
! [[множественное число|plural]]
|-
!
| ]=] .. alt_impr_sg .. [=[ || ]=] .. alt_impr_pl .. [=[

|- class="rowgroup"
! [[прошедшее время|past tense]]
! [[единственное число|singular]]
! [[множественное число|plural]]<br/>(<span lang="ru" class="Cyrl">мы/вы/они́</span>)
|-
! [[мужской род|masculine]] (<span lang="ru" class="Cyrl">я/ты/он</span>)
| ]=] .. alt_past_m .. [=[ || rowspan="3" | ]=] .. alt_past_pl .. [=[

|-
! [[женский род|feminine]] (<span lang="ru" class="Cyrl">я/ты/она́</span>)
| ]=] .. alt_past_f .. [=[

|-
! style="background-color:#ffffe0; text-align:left;" | [[средний род|neuter]] (<span lang="ru" class="Cyrl">оно́</span>)
| ]=] .. alt_past_n .. [=[

|}
</div>
</div>]=]
end

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
