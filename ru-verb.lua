--[=[
	This module contains functions for creating inflection tables for Russian
	verbs.

	Author: Atitarev, significantly rewritten by Benwing, earliest version by CodeCat

	NOTE: This module is partly converted to support manual translit, in the
	form CYRILLIC//LATIN (i.e. with a // separating the Cyrillic and Latin
	parts). All the general infrastructure supports manual translit; the
	only thing that doesn't is some of the specific verb conjugation functions.
	In particular, all of the class 1, 2 and 4 conjugation functions support
	manual translit, and the rest don't, To convert another, follow the
	model of one of the already-converted functions.

	Note that an individual form (an entry in the 'forms' table) can be
	either a string (no special manual translit; generally this originates
	from the portion of the code that doesn't support manual translit), or
	a one-element list {CYRILLIC} (no special manual translit), or a
	two-element list {CYRILLIC, LATIN} with manual translit specified.
	The code is careful only to generate manual translit when it's needed,
	to avoid penalizing the majority of cases where manual transit isn't
	needed.

FIXME:

1. (DONE) Find any current uses of pres_futr_* overrides and remove them,
   converting to pres_ or futr_. Then make pres_futr_ overrides illegal.
]=]--

local m_utilities = require("Module:utilities")
local ut = require("Module:utils")
local com = require("Module:ru-common")
local nom = require("Module:ru-nominal")
local m_debug = require("Module:debug")
local m_table_tools = require("Module:table tools")

-- If enabled, compare this module with new version of module to make
-- sure all conjugations are the same.
local test_new_ru_verb_module = false

local export = {}

-- Within this module, conjugations are the functions that do the actual
-- conjugating by creating the forms of a basic verb.
-- They are defined further down.
local conjugations = {}

local lang = require("Module:languages").getByCode("ru")

local u = mw.ustring.char
local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local usub = mw.ustring.sub

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

-- ine() (if-not-empty)
local function ine(arg)
	if not arg or arg == "" then return nil end
	return arg
end

local function is_vowel_stem(stem)
	return rfind(stem, "[" .. com.vowel .. AC .. "]$")
end

-- Return the next number to use as an internal note symbol, starting at 1.
-- We look at existing internal notes to see if the symbol is already used.
local function next_note_symbol(data)
	local nextsym = 1
	while true do
		local sym_already_seen = false
		for _, note in ipairs(data.internal_notes) do
			if rfind(note, "^" .. nextsym .. " ") then
				sym_already_seen = true
				break
			end
		end
		if sym_already_seen then
			nextsym = nextsym + 1
		else
			break
		end
	end
	return nextsym
end

-- FIXME: Move to utils
-- Iterate over a chain of parameters, FIRST then PREF2, PREF3, ...,
-- inserting into LIST (newly created if omitted). Return LIST.
local function get_arg_chain(args, first, pref, list)
	if not list then
		list = {}
	end
	local val = args[first]
	local i = 2

	while val do
		table.insert(list, val)
		val = args[pref .. i]
		i = i + 1
	end
	return list
end

-- FIXME: Move to utils
-- Set a chain of parameters, FIRST then PREF2, PREF3, ..., from LIST.
local function set_arg_chain(args, first, pref, list)
	local param = first
	local i = 2

	for _, val in ipairs(list) do
		args[param] = val
		param = pref .. i
		i = i + 1
	end
end

-- FIXME: Move to utils
-- Append to the end of a chain of parameters, FIRST then PREF2, PREF3, ...,
-- if the value isn't already present.
local function append_to_arg_chain(args, first, pref, newval)
	local nextarg = first
	local i = 2

	while true do
		if not args[nextarg] then break end
		if ut.equals(args[nextarg], newval) then
			return nil
		end
		nextarg = pref .. i
		i = i + 1
	end
	args[nextarg] = newval
	return nextarg
end

local function getarg(args, arg, default, paramdesc)
	paramdesc = paramdesc or "Parameter " .. arg
	default = default or "-"
	--PAGENAME = mw.title.getCurrentTitle().text
	local NAMESPACE = mw.title.getCurrentTitle().nsText
	return args[arg] or (NAMESPACE == "Template" and default) or error(paramdesc .. " has not been provided")
end

local function get_stressed_arg(args, arg, default, paramdesc)
	local retval = getarg(args, arg, default, paramdesc)
	if not com.is_nonsyllabic(retval) and not com.is_stressed(retval) then
		error("Argument value " .. retval .. " (parameter " .. arg .. ") must be stressed")
	end
	return retval
end

local function get_opt_stressed_arg(args, arg)
	return args[arg] and get_stressed_arg(args, arg) or nil
end

local function get_unstressed_arg(args, arg, default, paramdesc)
	local retval = getarg(args, arg, default, paramdesc)
	if com.is_stressed(retval) then
		error("Argument value " .. retval .. " (parameter " .. arg .. ") should not be stressed")
	end
	return retval
end

local function get_opt_unstressed_arg(args, arg)
	return args[arg] and get_unstressed_arg(args, arg) or nil
end

-- Check that argument ARG of ARGS is one of the values in ALLOWED_VALUES
-- (a list), or nil if ALLOW_NIL is specified. If so, return the value found;
-- else, error.
local function check_arg(args, arg, allowed_values, allow_nil)
	local val = args[arg]
	if allow_nil and val == nil then
		return nil
	elseif ut.contains(allowed_values, val) then
		return val
	else
		error("Argument value " .. val .. " (parameter " .. arg ..
			") not one of the possible values " ..
			table.concat(allowed_values, ", ") ..
			(allow_nil and " or empty" or ""))
	end
end

local function check_opt_arg(args, arg, allowed_values)
	return check_arg(args, arg, allowed_values, "allow nil")
end

local function no_stray_args(args, maxarg)
	for i=(maxarg+1),20 do
		if args[i] then
			error("Value for argument " .. i .. " not allowed")
		end
	end
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
local make_reflexive
local parse_and_stress_override
local handle_forms_and_overrides
local finish_generating_forms
local make_table

local all_verb_types = {"pf", "pf-intr", "pf-refl", "pf-impers", "pf-impers-refl",
	"impf", "impf-intr", "impf-refl", "impf-impers", "impf-impers-refl"}

-- Examples of alternatives in use:
	-- past_m2: со́здал/созда́л, пе́редал/переда́л, о́тдал/отда́л, при́нялся/принялся́
	-- past_m3:	for verbs with three past masculine sg forms: за́нялся, заня́лся, занялс́я (заня́ться)
	-- past_n2: да́ло, дал́о; вз́яло, взяло́
	-- past_pl2: разобрали́сь (разобрали́)
	-- past_m_short: short forms in 3a (исчез, сох, etc.)
	-- past_f_short: short forms in 3a (исчезла, сохла, etc.)
	-- past_n_short: short forms in 3a (исчезло, сохло, etc.)
	-- past_pl_short: short forms in 3a (исчезли, сохли, etc.)
	-- past_adv_parts:
	--   тереть: тере́вши, тёрши, short: тере́в
	--   умереть: умере́вши, у́мерши, short: умере́в
	-- pres_adv_part: сыпля, сыпя, лёжа (лежать)
	-- pres_2sg2: сыплешь, сыпешь
	-- pres_3sg2: сыплет, сыпет
	-- pres_1pl2: сыплем, сыпем
	-- pres_2pl2: сыплете, сыпете
	-- pres_3pl2: сыплют, сыпют
	-- futr_2sg2: насыплешь, насыпешь
	-- futr_3sg2: насыплет, насыпет
	-- futr_1pl2: насыплем, насыпем
	-- futr_2pl2: насыплете, насыпете
	-- futr_3pl2: насыплют, насыпют

-- List of all verb forms. Each element is a list, where the first element
-- is the "main" form and the remainder are alternatives. The following
-- *MUST* hold:
-- 1. Forms must be given in the order they will appear in the outputted
--    table.
-- 2. Short forms (those ending in "_short") must be listed after the
--    corresponding non-short forms.
-- 3. For each person, e.g. '2sg', there must be the same number of
--    futr_PERSON, pres_PERSON and pres_futr_PERSON forms, and the alternative
--    forms must be listed in the same order.
local all_verb_forms = {
	-- present tense
	{"pres_1sg", "pres_1sg2", "pres_1sg3", "pres_1sg4"},
	{"pres_2sg", "pres_2sg2", "pres_2sg3", "pres_2sg4"},
	{"pres_3sg", "pres_3sg2", "pres_3sg3", "pres_3sg4"},
	{"pres_1pl", "pres_1pl2", "pres_1pl3", "pres_1pl4"},
	{"pres_2pl", "pres_2pl2", "pres_2pl3", "pres_2pl4"},
	{"pres_3pl", "pres_3pl2", "pres_3pl3", "pres_3pl4"},
	-- future tense
	{"futr_1sg", "futr_1sg2", "futr_1sg3", "futr_1sg4"},
	{"futr_2sg", "futr_2sg2", "futr_2sg3", "futr_2sg4"},
	{"futr_3sg", "futr_3sg2", "futr_3sg3", "futr_3sg4"},
	{"futr_1pl", "futr_1pl2", "futr_1pl3", "futr_1pl4"},
	{"futr_2pl", "futr_2pl2", "futr_2pl3", "futr_2pl4"},
	{"futr_3pl", "futr_3pl2", "futr_3pl3", "futr_3pl4"},
	-- present-future tense. The conjugation functions generate the
	-- "present-future" tense instead of either the present or future tense,
	-- since the same forms are used in the present imperfect and future
	-- perfect. These forms are later copied into the present or future in
	-- finish_generating_forms().
	{"pres_futr_1sg", "pres_futr_1sg2", "pres_futr_1sg3", "pres_futr_1sg4"},
	{"pres_futr_2sg", "pres_futr_2sg2", "pres_futr_2sg3", "pres_futr_2sg4"},
	{"pres_futr_3sg", "pres_futr_3sg2", "pres_futr_3sg3", "pres_futr_3sg4"},
	{"pres_futr_1pl", "pres_futr_1pl2", "pres_futr_1pl3", "pres_futr_1pl4"},
	{"pres_futr_2pl", "pres_futr_2pl2", "pres_futr_2pl3", "pres_futr_2pl4"},
	{"pres_futr_3pl", "pres_futr_3pl2", "pres_futr_3pl3", "pres_futr_3pl4"},
	-- imperative
	{"impr_sg", "impr_sg2", "impr_sg3", "impr_sg4"},
	{"impr_pl", "impr_pl2", "impr_pl3", "impr_pl4"},
	-- past
	{"past_m", "past_m2", "past_m3", "past_m4"},
	{"past_f", "past_f2", "past_f3", "past_f4"},
	{"past_n", "past_n2", "past_n3", "past_n4"},
	{"past_pl", "past_pl2", "past_pl3", "past_pl4"},
	{"past_m_short", "past_m_short2", "past_m_short3", "past_m_short4"},
	{"past_f_short", "past_f_short2", "past_f_short3", "past_f_short4"},
	{"past_n_short", "past_n_short2", "past_n_short3", "past_n_short4"},
	{"past_pl_short", "past_pl_short2", "past_pl_short3", "past_pl_short4"},

	-- active participles
	{"pres_actv_part", "pres_actv_part2", "pres_actv_part3", "pres_actv_part4"},
	{"past_actv_part", "past_actv_part2", "past_actv_part3", "past_actv_part4"},
	-- passive participles
	{"pres_pasv_part", "pres_pasv_part2", "pres_pasv_part3", "pres_pasv_part4"},
	{"past_pasv_part", "past_pasv_part2", "past_pasv_part3", "past_pasv_part4"},
	-- adverbial participles
	{"pres_adv_part", "pres_adv_part2", "pres_adv_part3", "pres_adv_part4"},
	{"past_adv_part", "past_adv_part2", "past_adv_part3", "past_adv_part4"},
	{"past_adv_part_short", "past_adv_part_short2", "past_adv_part_short3", "past_adv_part_short4"},
	-- infinitive
	{"infinitive"},
}

local prop_aliases = {
	pap="past_actv_part",
	paptail="past_actv_part_tail",
	paptailall="past_actv_part_tailall",
	ppp="past_pasv_part",
	ppptail="past_pasv_part_tail",
	ppptailall="past_pasv_part_tailall",
	prap="pres_actv_part",
	praptail="pres_actv_part_tail",
	praptailall="pres_actv_part_tailall",
	prpp="pres_pasv_part",
	prpptail="pres_pasv_part_tail",
	prpptailall="pres_pasv_part_tailall",
	padp="past_adv_part",
	padptail="past_adv_part_tail",
	padptailall="past_adv_part_tailall",
	padp_short="past_adv_part_short",
	padp_shorttail="past_adv_part_short_tail",
	padp_shorttailall="past_adv_part_short_tailall",
	pradp="pres_adv_part",
	pradptail="pres_adv_part_tail",
	pradptailall="pres_adv_part_tailall",
}

-- Table mapping "main" to the list of all forms in the series (e.g.
-- past_m, past_m2, past_m3, etc.). If a main form (e.g. past_m) is missing,
-- it needs to end up with a value of "", whereas the alternatives
-- (e.g. past_m2, past_m3) need to end up with a value of nil.
local main_to_all_verb_forms = {}

-- List of the main verb forms for the past.
local past_verb_forms = {"past_m", "past_f", "past_n", "past_pl"}
-- List of the main verb forms for the present.
local pres_verb_forms = {"pres_1sg", "pres_2sg", "pres_3sg",
	"pres_1pl", "pres_2pl", "pres_3pl"}
-- List of the main verb forms for the future.
local futr_verb_forms = {"futr_1sg", "futr_2sg", "futr_3sg",
	"futr_1pl", "futr_2pl", "futr_3pl"}
-- List of the main verb forms for the imperative.
local impr_verb_forms = {"impr_sg", "impr_pl"}

-- Compile main_to_all_verb_forms.
for _, proplist in ipairs(all_verb_forms) do
	main_to_all_verb_forms[proplist[1]] = proplist
end

-- Map listing the forms to be displayed, and the verb forms used to generate
-- the displayed form, in order. For example, under past_m will be found
-- {"past_m_short", "past_m", "past_m2", "past_m3"} because those forms in
-- that order are displayed in the table under "masculine singular past".
local disp_verb_form_map = {}
for _, proplist in ipairs(all_verb_forms) do
	local key = proplist[1]
	-- if we find short forms, insert them at the beginning of the list for
	-- the corresponding full forms. This requires that short forms are
	-- listed in all_verb_forms after the corresponding full forms.
	if rfind(key, "_short$") then
		local full_key = rsub(key, "_short$", "")
		-- short forms should occur in list after full forms
		assert(#(disp_verb_form_map[full_key]) > 0)
		-- build entry for full form, consisting first of the short forms,
		-- in order, then the full forms, in order.
		local new_entry = {}
		for _, form in ipairs(proplist) do
			table.insert(new_entry, form)
		end
		for _, form in ipairs(disp_verb_form_map[full_key]) do
			table.insert(new_entry, form)
		end
		disp_verb_form_map[full_key] = new_entry
	elseif rfind(key, "^pres_futr") then
		-- skip these forms, not displayed
	else
		disp_verb_form_map[key] = mw.clone(proplist)
	end
end

local all_verb_props = mw.clone(all_verb_forms)
local non_form_props = {"title", "perf", "intr", "impers", "categories", "notes", "internal_notes"}
for _, prop in ipairs(non_form_props) do
	table.insert(all_verb_props, {prop})
end

-- Clone parent's args while also assigning nil to empty strings. Handle
-- aliases in the process. Extract and remove conjugation type from arg 1.
-- Return new arguments and extracted conjugation type.
local function clone_args_handle_aliases(frame)
	local args = {}
	local conj_type = nil
	for pname, param in pairs(frame:getParent().args) do
		local argval = ine(param)
		local mainprop, num = rmatch(pname, "^([a-z_]+)([0-9]*)$")
		if not mainprop then
			if pname == 1 and argval then
				-- This complex spec matches matches 3°a, 3oa, 4a1a, 6c1a,
				-- 1a6a, 6a1as13, 6a1as14, etc.
				conj_type = rmatch(argval, "^([0-9]+[°o0-9abc]*[abc]s?1?[34]?)")
				argval = rsub(argval, "^[0-9]+[°o0-9abc]*[abc]s?1?[34]?/?", "")
				if not conj_type then
					conj_type = rmatch(argval, "^(irreg%-[абцдефгчийклмнопярстувшхызёюжэщьъ%-]*)")
					argval = rsub(argval, "^irreg%-[абцдефгчийклмнопярстувшхызёюжэщьъ%-]*/?", "")
				end
			end
			args[pname] = argval
		else
			mainprop = prop_aliases[mainprop] or mainprop
			args[mainprop .. num] = argval
		end
	end
	if not conj_type then
		local NAMESPACE = mw.title.getCurrentTitle().nsText
		if NAMESPACE == "Template" then
			conj_type = "1a"
		else
			error("Must specify argument 1 (conjugation type)")
		end
	end
	return args, conj_type
end

function export.do_generate_forms(conj_type, args)
	-- Verb type, one of impf, pf, impf-intr, pf-intr, impf-refl, pf-refl.
	-- Default to impf on the template page so that there is no script error.
	local verb_type = getarg(args, 2, "impf", "Verb type (second parameter)")
	-- verbs may have reflexive ending stressed in the masculine singular: занялся́, начался́, etc.
	local notes = get_arg_chain(args, "notes", "notes")

	local forms, categories

	track("conj-" .. conj_type) -- FIXME, convert to regular category

	if not ut.contains(all_verb_types, verb_type) then
		error("Invalid verb type " .. verb_type)
	end

	local data = {}
	data.verb_type = verb_type
	data.conj_type = conj_type
	data.internal_notes = {}
	if rfind(conj_type, "^irreg") then
		data.title = "irregular"
	else
		data.title = "class " .. conj_type
	end

	--impersonal
	data.impers = rfind(verb_type, "impers")
	data.intr = data.impers or rfind(verb_type, "intr")
	data.refl = rfind(verb_type, "refl")
	data.perf = rfind(verb_type, "^pf")
	data.iter = args["iter"]
	data.nopres = args["nopres"]
	data.nopast = args["nopast"]
	data.nofutr = args["nofutr"]
	data.noimpr = args["noimpr"]
	if data.iter and data.perf then
		error("Iterative verbs must be imperfective")
	end

	-- FIXME, temporary tracking for places that need conversion to past stress
	-- variant
	if args["past_m2"] or args["past_m3"] or args["past_m4"] or
		args["past_f"] or args["past_f2"] or args["past_f3"] or args["past_f4"] or
		args["past_n"] or args["past_n2"] or args["past_n3"] or args["past_n4"] or
		args["past_pl"] or args["past_pl2"] or args["past_pl3"] or args["past_pl4"] then
		track("explicit-past")
	end
	if args["reflex_stress"] then
		track("reflex-stress")
	end

	data.ppp_override = false
	for _, form in ipairs(main_to_all_verb_forms["past_pasv_part"]) do
		if args[form] then
			data.ppp_override = true
			break
		end
	end
	data.shouldnt_have_ppp = data.refl or data.intr and not data.impers
	if data.ppp_override and data.shouldnt_have_ppp then
		error("Shouldn't specify past passive participle with reflexive or intransitive verbs")
	elseif data.perf and not data.shouldnt_have_ppp and not data.ppp_override then
		-- possible omissions
		track("perfective-no-ppp")
	end

	if conjugations[conj_type] then
		forms = conjugations[conj_type](args, data)
	else
		error("Unknown conjugation type '" .. conj_type .. "'")
	end

	local reflex_stress = args["reflex_stress"] or data.default_reflex_stress -- "ся́"

	if rfind(conj_type, "^irreg") then
		categories = {"Russian irregular verbs"}
	else
		local class_num = rmatch(conj_type, "^([0-9]+)")
		assert(class_num and class_num ~= "")
		categories = {"Russian class " .. class_num .. " verbs"}
	end
	data.title = data.title ..
		(data.perf and " perfective" or " imperfective") ..
		(data.refl and " reflexive" or data.intr and " intransitive" or " transitive") ..
		(data.impers and " impersonal" or "") ..
		(data.iter and " iterative" or "")

	-- Perfective/imperfective
	if data.perf then
		table.insert(categories, "Russian perfective verbs")
	else
		table.insert(categories, "Russian imperfective verbs")
	end

	handle_forms_and_overrides(args, forms, data.perf)

	-- catch errors in verb arguments that lead to the infinitive not matching
	-- page title, but only in the main namespace
	local PAGENAME = mw.title.getCurrentTitle().text
	local NAMESPACE = mw.title.getCurrentTitle().nsText
	local inf = forms.infinitive
	if type(inf) == "table" then
		inf = inf[1]
	end
	inf, _ = m_table_tools.get_notes(inf) -- remove any footnote symbols (e.g. грясти́)
	local inf_noaccent = com.remove_accents(inf)
	if data.refl then
		if rfind(inf_noaccent, "и$") then
			inf_noaccent = inf_noaccent .. "сь"
			inf = inf .. "сь"
		else
			inf_noaccent = inf_noaccent .. "ся"
			inf = inf .. "ся"
		end
	end
	if NAMESPACE == "" and inf_noaccent ~= PAGENAME then
		error("Infinitive " .. inf .. " doesn't match pagename " ..
			PAGENAME)
	end

	-- Reflexive/intransitive/transitive
	if data.refl then
		make_reflexive(forms, reflex_stress and reflex_stress ~= "n" and
			reflex_stress ~= "no")
		table.insert(categories, "Russian reflexive verbs")
	elseif data.intr then
		table.insert(categories, "Russian intransitive verbs")
	else
		table.insert(categories, "Russian transitive verbs")
	end

	-- Impersonal
	if data.impers then
		table.insert(categories, "Russian impersonal verbs")
	end
	-- Iterative
	if data.iter then
		table.insert(categories, "Russian iterative verbs")
	end

	finish_generating_forms(forms, data)

	return forms, data.title, data.perf, data.intr or data.refl, data.impers, categories, notes, data.internal_notes
end

local function fetch_forms(forms)
	local function fetch_one_form(form)
		local val = forms[form]
		local ru, tr
		if type(val) == "table" then
			ru, tr = val[1], val[2]
		elseif type(val) == "string" and val ~= "" and val ~= "-" then
			ru = val
		end
		if not ru then
			return nil
		end
		local ruentry, runotes = m_table_tools.get_notes(ru)
		local trentry, trnotes
		if tr then
			trentry, trnotes = m_table_tools.get_notes(tr)
		end
		-- There shouldn't be any links.
		-- ruentry = m_links.remove_links(ruentry)
		-- There shouldn't be any vertical bars.
		-- ruentry = rsub(ruentry, "|", "<!>")
		-- if trentry then
		-- 	trentry = rsub(trentry, "|", "<!>")
		-- end
		return trentry and ruentry .. "//" .. trentry or ruentry
	end
	local vals = {}
	for _, proplist in ipairs(all_verb_forms) do
		local vallist = {}
		local propname = proplist[1]
		if not rfind(propname, "^pres_futr") then
			for _, prop in ipairs(proplist) do
				local val = fetch_one_form(prop)
				if val then
					table.insert(vallist, val)
				end
			end
			if #vallist > 0 then
				table.insert(vals, propname .. "=" .. table.concat(vallist, ","))
			end
		end
	end
	return table.concat(vals, "|")
end

function export.generate_forms(frame)
	local args, conj_type = clone_args_handle_aliases(frame)
	local forms, title, perf, intr, impers, categories, notes, internal_notes = export.do_generate_forms(conj_type, args)
	return fetch_forms(forms)
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
	local args, conj_type = clone_args_handle_aliases(frame)

	local args_clone
	if test_new_ru_verb_module then
		-- args may be modified by do_generate_forms()
		args_clone = mw.clone(args)
	end

	local forms, title, perf, intr, impers, categories, notes, internal_notes = export.do_generate_forms(conj_type, args)

	-- Test code to compare existing module to new one.
	if test_new_ru_verb_module then
		local m_new_ru_verb = require("Module:User:Benwing2/ru-verb")
		local newforms, newtitle, newperf, newintr, newimpers, newcategories, newnotes, newinternal_notes = m_new_ru_verb.do_generate_forms(conj_type, args_clone)
		local vals = mw.clone(forms)
		vals.title = title
		vals.perf = perf
		vals.intr = intr
		vals.impers = impers
		vals.categories = categories
		vals.notes = notes
		vals.internal_notes = internal_notes
		local newvals = mw.clone(newforms)
		newvals.title = newtitle
		newvals.perf = newperf
		newvals.intr = newintr
		newvals.impers = newimpers
		newvals.categories = newcategories
		newvals.notes = newnotes
		newvals.internal_notes = newinternal_notes
		local difconj = false
		for _, proplist in ipairs(all_verb_props) do
			for _, prop in ipairs(proplist) do
				local val = vals[prop]
				local newval = newvals[prop]
				-- deal with impedance mismatch between old style (plain string)
				-- and new style (Russian/translit array), and empty string vs. nil
				if not ut.contains(non_form_props, prop) then
					if type(val) == "string" then val = {val} end
					if val and val[1] == "" then val = nil end
					if type(newval) == "string" then newval = {newval} end
					if newval and newval[1] == "" then newval = nil end
				end
				-- Ignore changes in pres_futr_*, which aren't displayed
				if not ut.equals(val, newval) and not rfind(prop, "^pres_futr") then
					-- Uncomment this to display the particular case and
					-- differing forms.
					--error(prop .. " " .. (val and concat_vals(val) or "nil") .. " || " .. (newval and concat_vals(newval) or "nil"))
					difconj = true
					break
				end
			end
		end
		track(difconj and "different-conj" or "same-conj")
	end

	return make_table(forms, title, perf, intr, impers, notes, internal_notes) .. m_utilities.format_categories(categories, lang)
end

--[=[
	Functions for working with stems, paradigms, Russian/translit
]=]--

-- Combine a stem with optional translit with an ending, returning a tuple
-- {RUSSIAN, TR}.
local function combine(stem, tr, ending)
	if not ending or ending == "-" then
		return {""}
	end
	if stem ~= "" and com.is_stressed(ending) then
		stem, tr = com.make_unstressed_once(stem, tr)
	end
	stem = stem .. ending
	if tr then
		tr = tr .. com.translit(ending)
	end
	return {stem, tr}
end

-- Set an individual form PARAM in FORMS with value based on stem STEM (with
-- optional translit TR) and ENDINGS, either a single string or a list of
-- strings. If there are multiple endings listed, they will go successively
-- into PARAM, PARAM2, etc. (e.g. past_m, past_m2, etc.).
local function set_form(forms, param, stem, tr, endings)
	if type(endings) ~= "table" then
		endings = {endings}
	end
	local entries = {}
	for _, val in ipairs(endings) do
		ut.insert_if_not(entries, combine(stem, tr, val))
	end
	set_arg_chain(forms, param, param, entries)
end

-- Append to an individual form PARAM in FORMS with value based on stem STEM
-- (with optional translit TR) and ENDINGS, either a single string or a list of
-- strings. If there are multiple endings listed, they will go successively
-- into PARAM, PARAM2, etc. (e.g. past_m, past_m2, etc.), provided there are
-- no existing forms already present. Duplicate forms aren't inserted.
local function append_form(forms, param, stem, tr, endings)
	if type(endings) ~= "table" then
		endings = {endings}
	end
	for _, val in ipairs(endings) do
		append_to_arg_chain(forms, param, param, combine(stem, tr, val))
	end
end

local function extract_russian_tr(form, translit)
	local ru, tr
	if type(form) == "table" then
		ru, tr = form[1], form[2]
	else
		ru = form
	end
	if not tr and translit then
		tr = ru and com.translit(ru)
	end
	return ru, tr
end

local function append_pres_futr(forms, stem, tr,
	sg1, sg2, sg3, pl1, pl2, pl3)
	append_form(forms, "pres_futr_1sg", stem, tr, sg1)
	append_form(forms, "pres_futr_2sg", stem, tr, sg2)
	append_form(forms, "pres_futr_3sg", stem, tr, sg3)
	append_form(forms, "pres_futr_1pl", stem, tr, pl1)
	append_form(forms, "pres_futr_2pl", stem, tr, pl2)
	append_form(forms, "pres_futr_3pl", stem, tr, pl3)
end

local function append_participles_2stem(forms,
	pres_stem, pres_tr, past_stem, past_tr,
	pres_actv, pres_pasv, pres_adv, past_actv, past_adv, past_adv_short)
	append_form(forms, "pres_actv_part", pres_stem, pres_tr, pres_actv)
	append_form(forms, "pres_pasv_part", pres_stem, pres_tr, pres_pasv)
	append_form(forms, "pres_adv_part", pres_stem, pres_tr, pres_adv)
	append_form(forms, "past_actv_part", past_stem, past_tr, past_actv)
	append_form(forms, "past_adv_part", past_stem, past_tr, past_adv)
	append_form(forms, "past_adv_part_short", past_stem, past_tr, past_adv_short)
end

local function append_participles(forms, stem, tr,
	pres_actv, pres_pasv, pres_adv, past_actv, past_adv, past_adv_short)
	append_participles_2stem(forms, stem, tr, stem, tr,
		pres_actv, pres_pasv, pres_adv, past_actv, past_adv, past_adv_short)
end

local function set_ppp(forms, stem, tr, ending)
	set_form(forms, "past_pasv_part", stem, tr, ending)
end

local function append_ppp(forms, stem, tr, ending)
	append_form(forms, "past_pasv_part", stem, tr, ending)
end

local function set_imper(forms, stem, tr, sg, pl)
	set_form(forms, "impr_sg", stem, tr, sg)
	set_form(forms, "impr_pl", stem, tr, pl)
end

local function append_imper(forms, stem, tr, sg, pl)
	append_form(forms, "impr_sg", stem, tr, sg)
	append_form(forms, "impr_pl", stem, tr, pl)
end

local function set_past(forms, stem, tr, m, f, n, pl)
	set_form(forms, "past_m", stem, tr, m)
	set_form(forms, "past_f", stem, tr, f)
	set_form(forms, "past_n", stem, tr, n)
	set_form(forms, "past_pl", stem, tr, pl)
end

local function append_past(forms, stem, tr, m, f, n, pl)
	append_form(forms, "past_m", stem, tr, m)
	append_form(forms, "past_f", stem, tr, f)
	append_form(forms, "past_n", stem, tr, n)
	append_form(forms, "past_pl", stem, tr, pl)
end

local variant_to_title = {
	["[(2)]"] = "[②]",
	["(2)"] = "②",
	["[(3)]"] = "[③]",
	["(3)"] = "③",
	["[(4)]"] = "[④]",
	["(4)"] = "④",
	["[(5)]"] = "[⑤]",
	["(5)"] = "⑤",
	["[(6)]"] = "[⑥]",
	["(6)"] = "⑥",
	["[(7)]"] = "[⑦]",
	["(7)"] = "⑦",
	["[(8)]"] = "[⑧]",
	["(8)"] = "⑧",
	["(9)"] = "⑨",
	["щ"] = "(-щ-)",
	["ё"] = "(-ё-)",
	["о"] = "(-о-)",
	["жд"] = "(-жд-)",
}

local function prepare_past_stress_indicator(past_stress)
	if not past_stress or past_stress == "a" then
		return ""
	end
	past_stress = rsub(past_stress, "%(1%)", "①")
	past_stress = rsub(past_stress, "(.),%1①", "%1[①]")
	past_stress = rsub(past_stress, "(.)①,%1", "%1[①]")
	past_stress = rsub(past_stress, "''", "&#39;&#39;")
	past_stress = rsub(past_stress, "-nd", "")
	past_stress = rsub(past_stress, "-bd", "")
	return "/" .. past_stress
end

local function parse_variants(data, variants, allowed, def_past_stress)
	variants = variants or ""
	local variant_title = ""
	if variants ~= "" then -- short-circuit the most common case
		-- Allow brackets around both 5 and 6, e.g. [(5)(6)]
		variants = rsub(variants, "%[(%([56]%))(%([56]%))%]", "[%1][%2]")
		variants = rsub(variants, "(%[?%(?[23456789ёощийьж+][дp]?%)?%]?)", function(var)
			if ut.contains({"(2)", "[(2)]", "(3)", "[(3)]", "и", "й", "ь"}, var) then
				if data.imper_variant then
					error("Saw two imperative variants " .. data.imper_variant ..
						" and " .. var)
				end
				local is_23 = ut.contains({"(2)", "[(2)]", "(3)", "[(3)]"}, var)
				if is_23 and not ut.contains(allowed, "23") or
					not is_23 and not ut.contains(allowed, "и") then
					error("Variant " .. var .. " not allowed for this verb class")
				end
				data.imper_variant = var
			elseif ut.contains({"(4)", "[(4)]"}, var) then
				if data.var4 then
					error("Saw two variant-4 specs " .. data.var4 .. " and " .. var)
				end
				if not ut.contains(allowed, "4") then
					error("Variant " .. var .. " not allowed for this verb class")
				end
				data.var4 = var == "(4)" and "req" or "opt"
			elseif ut.contains({"(5)", "[(5)]"}, var) then
				if data.var5 then
					error("Saw two variant-5 specs " .. data.var5 .. " and " .. var)
				end
				if not ut.contains(allowed, "5") then
					error("Variant " .. var .. " not allowed for this verb class")
				end
				data.var5 = var == "(5)" and "req" or "opt"
			elseif ut.contains({"(6)", "[(6)]"}, var) then
				if data.var6 then
					error("Saw two variant-6 specs " .. data.var6 .. " and " .. var)
				end
				if not ut.contains(allowed, "6") then
					error("Variant " .. var .. " not allowed for this verb class")
				end
				data.var6 = var == "(6)" and "req" or "opt"
			elseif ut.contains({"(7)", "[(7)]", "(8)", "[(8)]", "+p"}, var) then
				if data.shouldnt_have_ppp then
					error("Shouldn't specify past passive participle with reflexive or intransitive verbs")
				end
				if data.ppp then
					error("Saw two past passive participle specs " .. data.ppp .. " and " .. var)
				end
				if ut.contains({"(7)", "[(7)]"}, var) and not ut.contains(allowed, "7") or
					ut.contains({"(8)", "[(8)]"}, var) and not ut.contains(allowed, "8") or
					var == "+p" and not ut.contains(allowed, "+p") then
					error("Variant " .. var .. " not allowed for this verb class")
				end
				data.ppp = var
			elseif var == "(9)" then
				if data.var9 then
					error("Saw (9) twice")
				end
				if not ut.contains(allowed, "9") then
					error("Variant " .. var .. " not allowed for this verb class")
				end
				data.var9 = true
			elseif var == "щ" then
				-- specify that the 1sg pres/futr and past passive participle
				-- of class 4/5/6 verbs iotate -т to -щ instead of -ч; cf.
				-- похи́тить (похи́щу) (4a), защити́ть (защищу́) (4b),
				-- поглоти́ть (поглощу́) (4c), клевета́ть (клевещу́) (6c)
				if data.shch then
					error("Saw щ twice")
				end
				if not ut.contains(allowed, "щ") then
					error("Variant " .. var .. " not allowed for this verb class")
				end
				data.shch = "щ"
			elseif var == "ё" then
				-- specify that the past passive participle has ё instead of е
				if data.yo then
					error("Saw ё twice")
				end
				if not ut.contains(allowed, "ё") then
					error("Variant " .. var .. " not allowed for this verb class")
				end
				data.yo = true
			elseif var == "о" then
				-- specify that the past passive participle has о instead of е
				-- NOTE: Not currently allowed as a user-specifiable variant
				if data.o then
					error("Saw о twice")
				end
				if not ut.contains(allowed, "о") then
					error("Variant " .. var .. " not allowed for this verb class")
				end
				data.o = true
			elseif var == "жд" then
				-- specify that the past passive participle of class 4/5/6 verbs
				-- iotates -д to -жд instead of -ж
				if data.zhd then
					error("Saw жд twice")
				end
				if not ut.contains(allowed, "жд") then
					error("Variant " .. var .. " not allowed for this verb class")
				end
				data.zhd = true
			else
				error("Unrecognized variant spec: " .. var)
			end
			variant_title = variant_title .. (variant_to_title[var] or "")
			return ""
		end)
		variant_title = rsub(variant_title, "%[⑤%]%[⑥%]", "[⑤⑥]")
	end
	if variants ~= "" and not ut.contains(allowed, "past") then
		error("Past stress " .. variants .. " not allowed for this verb class")
	end
	if data.yo and not data.ppp then
		error("Variant ё specified without calling for past passive participle")
	end
	if data.o and not data.ppp then
		error("Variant о specified without calling for past passive participle")
	end
	if data.zhd and not data.ppp then
		error("Variant жд specified without calling for past passive participle")
	end
	if data.perf and not data.ppp and not data.ppp_override and not data.shouldnt_have_ppp and not data.impers then
		error("For perfective transitive verbs, need to specify past passive participle by variant or override; use |ppp=- if no such participle")
	end
	data.past_stress = variants == "" and (def_past_stress or "a") or variants
	data.title = data.title ..
		prepare_past_stress_indicator(data.past_stress) ..
		variant_title
end

local function set_past_by_stress(forms, past_stresses, prefix, prefixtr, base,
		basetr, args, data, no_pastml)
	-- If there isn't manual translit for the prefix, we need to supply it
	-- if there's manual translit for the base, because we often concatenate
	-- prefix to the base.
	local prefixtr = prefixtr or basetr and com.translit(prefix)
	for _, past_stress in ipairs(rsplit(past_stresses, ",")) do
		local pastml = no_pastml and "" or "л"
		local stressed_prefixtr
		if prefix == "пере" then
			stressed_prefix = "пе́ре"
			stressed_prefixtr = "pe" .. AC .. "re"
		elseif prefix == "раз" then
			stressed_prefix = "ро́з"
			stressed_prefixtr = "ro" .. AC .. "z"
		elseif prefix == "рас" then
			-- Does this ever occur?
			stressed_prefix = "ро́с"
			stressed_prefixtr = "ro" .. AC .. "s"
		elseif prefix == "ра" and rfind(base, "^[сз]") then
			-- Type 9/11/14/16 with automatically split prefix; may never happen.
			stressed_prefix = "ро́"
			stressed_prefixtr = "ro" .. AC
		else
			stressed_prefix, stressed_prefixtr =
				com.make_ending_stressed(prefix, prefixtr)
		end
		-- Normally the base is stressed and the prefix isn't, but it could
		-- be the other way around, e.g. in запереть and запереться, where
		-- the stress on the prefix is used to get prefix-stressed participles.
		-- To deal with this, we usually combine base and prefix unchanged,
		-- but in combination with stressed_prefix we always want an unstressed
		-- base, and when a stressed -ся́ is called for, we want both of them
		-- unstressed.
		local ubase, ubasetr = com.make_unstressed(base, basetr)
		local uprefix, uprefixtr = com.make_unstressed(prefix, prefixtr)
		local prefixbase = prefix .. base
		local prefixbasetr = basetr and prefixtr .. basetr
		local stressed_prefix_ubase = stressed_prefix .. ubase
		local stressed_prefix_ubasetr = ubasetr and stressed_prefixtr .. ubasetr
		local uprefixubase = uprefix .. ubase
		local uprefixubasetr = ubasetr and uprefixtr .. ubasetr
		if past_stress == "a" then
			-- (/под/пере/при/по)забы́ть, раздобы́ть, (/пере/по)забы́ться
			append_past(forms, prefixbase, prefixbasetr, pastml,
				"ла", "ло", "ли")
		elseif past_stress == "a(1)" then
			-- вы́дать, вы́быть, etc.; also проби́ть with the meaning
			-- "to strike (of a clock)" (which is a(1),a or similar)
			append_past(forms, stressed_prefix_ubase,
				stressed_prefix_ubasetr, pastml, "ла", "ло", "ли")
		elseif past_stress == "b" then
			append_past(forms, prefixbase, prefixbasetr, pastml,
				"ла́", "ло́", "ли́")
		elseif past_stress == "b*" then
			 if not rfind(data.verb_type, "refl") then
				error("Only reflexive verbs can take past stress variant " .. past_stress)
			 end
			-- See comment in type c''. We want to see whether we actually
			-- added an argument, and if so, where.
			local argset = append_to_arg_chain(forms, "past_m", "past_m",
				combine(uprefixubase, uprefixubasetr, pastml))
			if argset and not args[argset] and not rfind(data.verb_type, "impers") then
				data.default_reflex_stress = "ся́"
			end
			append_past(forms, prefixbase, prefixbasetr, {}, "ла́", "ло́", "ли́")
		elseif past_stress == "c" then
			-- изда́ть, возда́ть, сдать, пересозда́ть, воссозда́ть, надда́ть, наподда́ть, etc.
			-- быть, избы́ть, сбыть
			-- клясть, закля́сть
			append_past(forms, prefixbase, prefixbasetr, pastml, "ла́", "ло", "ли")
		elseif past_stress == "c(1)" then
			-- прибы́ть, убы́ть
			-- прокля́сть
			-- also, c(1),c:
			--   зада́ть, обда́ть, отда́ть, подда́ть, переда́ть (пе́редал), преда́ть, прода́ть, разда́ть (ро́здал), созда́ть, etc.
			--   отбы́ть, побы́ть, пробы́ть
			-- also, c,c(1):
			--   добы́ть
			-- Because the prefix may vary depending on stress (esp. for
			-- раздать [ро́здал/раздала́]), we need to separate the endings that
			-- take the stressed prefix and those that take the unstressed
			-- prefix with stressed ending.
			append_past(forms, stressed_prefix_ubase, stressed_prefix_ubasetr,
				pastml, {}, "ло", "ли")
			append_past(forms, prefixbase, prefixbasetr, {}, "ла́", {}, {})
		elseif past_stress == "c'" then
			-- дать
			--same with "взять"
			append_past(forms, prefixbase, prefixbasetr,
				pastml, "ла́", {"ло", "ло́"}, "ли")
		elseif past_stress == "c''" or past_stress == "c''-nd" or past_stress == "c''-bd" then
			 if not rfind(data.verb_type, "refl") then
				error("Only reflexive verbs can take past stress variant " .. past_stress)
			 end
			-- c'' (-ся́ dated): all verbs in -да́ться; избы́ться, сбы́ться; all verbs in -кля́сться
			-- c''-nd (-ся́ not dated): various verbs in -ня́ться per Zaliznyak
			-- c''-bd (-ся́ becoming dated): various verbs in -ня́ться per ruwikt
			local note_symbol = past_stress == "c''-nd" and "" or
				next_note_symbol(data)
			append_past(forms, prefixbase, prefixbasetr,
				pastml, "ла́", {"ло́", "ло"}, {"ли́", "ли"})
			-- We want to see whether we actually added an argument, and if
			-- so, where.
			local argset = append_to_arg_chain(forms, "past_m", "past_m",
				combine(uprefixubase, uprefixubasetr, pastml .. note_symbol))
			-- Only display the internal note and set the default reflex
			-- stress if the form with the note will be displayed (i.e. not
			-- impersonal, and no override of this form). FIXME: We should
			-- have a more general mechanism to check for this.
			if not args[argset] and not rfind(data.verb_type, "impers") then
				ut.insert_if_not(data.internal_notes,
					past_stress == "c''" and note_symbol .. " Dated." or
					past_stress == "c''-bd" and note_symbol .. " Becoming dated." or nil)
				data.default_reflex_stress = "ся́"
			end
		elseif past_stress == "c''(1)" then
			-- запере́ться
			-- See comment in type c''. We want to see whether we actually
			-- added an argument, and if so, where.
			local argset = append_to_arg_chain(forms, "past_m", "past_m",
				combine(uprefixubase, uprefixubasetr, pastml))
			if argset and not args[argset] and not rfind(data.verb_type, "impers") then
				data.default_reflex_stress = "ся́"
			end
			append_past(forms, prefixbase, prefixbasetr, {}, "ла́", "ло́", "ли́")
			append_past(forms, stressed_prefix_ubase, stressed_prefix_ubasetr,
				pastml, {}, "ло", "ли")
		else
			error("Unrecognized past-stress value " .. past_stress .. ", should be a, a(1), b, b*, c, c(1), c', c'', c''-nd, c''-bd, c''(1) or comma-separated list")
		end
	end
end

local function split_prefix(ru, tr)
	local rusyl, trsyl = com.split_syllables(ru, tr)
	local last_ru = rusyl[#rusyl]
	local last_tr = trsyl and trsyl[#trsyl]
	table.remove(rusyl, #rusyl)
	local prefix_ru = table.concat(rusyl, "")
	local prefix_tr
	if trsyl then
		table.remove(trsyl, #trsyl)
		trsyl = table.concat(trsyl, "")
	end
	return prefix_ru, prefix_tr, last_ru, last_tr
end

local function append_imper_by_variant(forms, stem, tr, variant, verbclass, note)
	local vowel_stem = is_vowel_stem(stem)
	local stress = rmatch(verbclass, "([abc])$")
	if not stress then
		error("Unrecognized verb class '" .. verbclass .. "', should end with a, b or c")
	end
	note = note or ""
	local longend = stress == "a" and "и" or "и́"
	local shortend = vowel_stem and (com.is_unstressed(stem) and "́й" -- accent on previous vowel
		or "й") or "ь"
	local function append_short_imper()
		append_imper(forms, stem, tr, shortend .. note, shortend .. "те" .. note)
	end
	local function append_long_imper()
		append_imper(forms, stem, tr, longend .. note, longend .. "те" .. note)
	end
	if variant and variant ~= "" then
		track("explicit-imper")
		track("explicit-imper/" .. verbclass)
	end
	if variant == "(2)" then
		-- use short variants with вы́- (for these verbs, long is expected)
		if not rfind(stem, "^вы́-") then
			error("Should only specify imperative variant (2) with verbs in вы́-, not " .. stem)
		end
		append_short_imper()
	elseif variant == "[(2)]" then
		-- use both long and short variants
		append_long_imper()
		append_short_imper()
	elseif variant == "(3)" then
		-- long in singular, short in plural
		append_imper(forms, stem, tr, longend .. note, shortend .. "те" .. note)
	elseif variant == "[(3)]" then
		-- long and short in singular, short in plural
		append_imper(forms, stem, tr, {longend .. note, shortend .. note},
			shortend .. "те" .. note)
	elseif variant == "ь" or variant == "й" then
		-- short variants wanted
		append_short_imper()
	elseif variant == "и" then
		-- long variants wanted
		append_long_imper()
	else
		assert(not variant or variant == "")
		if vowel_stem then
			if verbclass == "4b" or verbclass == "4c" or (
				verbclass == "4a" and rfind(stem, "^вы́-")) then
				append_long_imper()
			else
				append_short_imper()
			end
		else -- consonant stem
			if stress == "b" or stress == "c" then
				append_long_imper()
			else
				assert(stress == "a")
				-- "и" after вы́-, e.g. вы́садить
				-- "и" after final щ, e.g. тара́щиться (although this particular
				--    verb has a [(3)] spec attached to it)
				if rfind(stem, "^вы́-") or rfind(stem, "щ$") or
					-- "и" after two consonants in a row (мо́рщить, зафре́ндить)
					rfind(stem, "[бвгджзклмнпрстфхцчшщь][бвгджзклмнпрстфхцчшщ]$") then
					append_long_imper()
				else
					-- "ь" after a single consonant (бре́дить)
					append_short_imper()
				end
			end
		end
	end
end

-- Compute the past passive participle stem for verbs that require it to be
-- iotated (class 4, and class 5 in -еть).
local function iotated_ppp(data, stem, tr)
	local iotated_stem, iotated_tr
	if data.zhd then
		local subbed
		iotated_stem, subbed = rsubb(stem, "д$", "жд")
		if not subbed then
			error("Variant -жд- specified but stem " .. stem .. " doesn't end in -д")
		end
		if tr then
			iotated_tr, subbed = rsubb(tr, "d$", "žd")
			if not subbed then
				error("Variant -жд- specified but translit " .. tr .. " doesn't end in -d")
			end
		end
	else
		iotated_stem, iotated_tr = com.iotation(stem, tr, data.shch)
	end
	return iotated_stem, iotated_tr
end

-- Set the past passive participle of verbs where the stress is moved left
-- from the ending by one syllable (if possible) if the ending is stressed,
-- otherwise left as-is (except class 1a in -е́ть, which has ending-stressed
-- -ённый). This applies to classes 1, 2, 3, 5, 6, 10 and 13. The stem comes
-- from the infinitive, iotated in class 5 -еть verbs. The participle ending
-- is -анный/-янный for verbs in -ать/-ять, -енный/-ённый for verbs in -еть,
-- otherwise -тый.
local function set_moving_ppp(forms, data)
	if not data.ppp then
		return
	end
	local infinitive, infinitivetr = extract_russian_tr(forms["infinitive"])
	local stem, ending = rmatch(infinitive, "^(.*)([аеоуя]́?ть)$")
	if not stem then
		error("Strange infinitive " .. infinitive .. " when trying to create participle")
	end
	local tr, endingtr
	if infinitivetr then
		if ending == "ять" or ending == "я́ть" then
			tr, endingtr = rmatch(infinitivetr, "^(.*)(ja" .. AC .. "?tʹ)$")
		else
			tr, endingtr = rmatch(infinitivetr, "^(.*)([aeou]" .. AC .. "?tʹ)$")
		end
		if not tr then
			error("Translit " .. infinitivetr .. " doesn't match Cyrillic " ..
				infinitive)
		end
	end
	local ending_vowel = usub(ending, 1, 1)
	local ppptype = data.ppp
	if com.is_nonsyllabic(stem) then
		-- e.g. 3b гну́ть (гну́тый)
		ppptype = "(7)"
	end
	if ut.contains({"5a", "5b", "5c"}, data.conj_type) and ending_vowel == "е" then
		stem, tr = iotated_ppp(data, stem, tr)
	end
	if not com.is_stressed(stem) then
		stem, tr = com.make_ending_stressed(stem, tr)
	end
	if data.o then
		-- цев -> цо́в, e.g. (об)лицева́ть -> (об)лицо́ванный
		stem = rsub(stem, "е́", "о́") -- Cyrillic
		if tr then
			tr = rsub(tr, "e" .. AC, "o" .. AC) -- Latin
		end
	elseif data.yo then
		-- ё occurs with e.g. 1a наверста́ть (навёрстанный)
		-- ё occurs with e.g. 3b поверну́ть (повёрнутый)
		-- ё occurs with e.g. 5b лежа́ть (лёжанный) but not with 5c держа́ть
		--   (де́ржанный)
		-- ё occurs always with class 2 in -ева́ть, e.g.
		--   (за)тушева́ть ((за)тушёванный) and (за)клева́ть ((за)клёванный)
		local subbed
		stem, subbed = rsubb(stem, "е́", "ё") -- Cyrillic
		if not subbed then
			error("No stressed е in stem " .. stem .. " to replace with ё when trying to create participle")
		end
		if tr then
			tr, subbed = rsub(tr, "je" .. AC, "jo" .. AC) -- Latin
			if not subbed then
				tr, subbed = rsub(tr, "e" .. AC, "jo" .. AC) -- Latin
			end
			if not subbed then
				error("No stressed е in translit " .. tr .. " to replace with jo when trying to create participle")
			end
		end
	end
	if data.conj_type == "1a" and ending_vowel == "е" then
		-- 1a, only одоле́ть, преодоле́ть, verbs in -печатле́ть
		set_ppp(forms, stem, tr, "ённый")
	else
		local stressed_ending, unstressed_ending
		if ending_vowel == "е" then
			stressed_ending = "ённый"
			unstressed_ending = "енный"
		else
			local ppp_ending =
				(ending_vowel == "а" or ending_vowel == "я") and "нный" or "тый"
			stressed_ending = ending_vowel .. AC .. ppp_ending
			unstressed_ending = ending_vowel .. ppp_ending
		end
		set_ppp(forms, stem, tr,
			-- (7) occurs with 1a обуя́ть (обуя́нный)
			ppptype == "(7)" and stressed_ending or
			-- [(7)] -- when does it occur? may only occur in class 4
			ppptype == "[(7)]" and {unstressed_ending, stressed_ending} or
			unstressed_ending)
	end
end

-- Set the past passive participle for those classes where it is derived
-- from the past tense masculine singular (9, 11, 12, 14, 15, 16). We need
-- to apply any relevant overrides.
local function set_ppp_from_past_m(forms, args, data)
	if not data.ppp then
		return
	end
	for _, form in pairs(main_to_all_verb_forms["past_m"]) do
		local ru, tr
		if args[form] then
			local override = parse_and_stress_override(form, args[form])
			ru, tr = extract_russian_tr(override)
		end
		if (not ru or ru == "" or ru == "-") and forms[form] then
			ru, tr = extract_russian_tr(forms[form])
		end
		if ru and ru ~= "" and ru ~= "-" then
			if rfind(ru, "л$") then
				ru = rsub(ru, "л$", "")
				if tr then
					tr = rsub(tr, "l$", "")
				end
			end
			append_ppp(forms, ru, tr, "тый")
		end
	end
end

-- Set the past passive participle for class-4 verbs.
local function set_class_4_ppp(forms, data, stem, tr)
	if not data.ppp then
		return
	end
	local iotated_stem, iotated_tr = iotated_ppp(data, stem, tr)
	if data.conj_type == "4b" then
		local stressed_iotated_stem, stressed_iotated_tr =
			com.make_ending_stressed(iotated_stem, iotated_tr)
		set_ppp(forms, stressed_iotated_stem, stressed_iotated_tr,
			-- (8) occurs with 4b скрои́ть (скро́енный)
			data.ppp == "(8)" and "енный" or
			-- [(8)] occurs with 4b разгроми́ть (разгромлённый, разгро́мленный)
			data.ppp == "[(8)]" and {"ённый", "енный"} or "ённый")
	else
		set_ppp(forms, iotated_stem, iotated_tr,
			-- (7) occurs with 4c раздели́ть (разделённый)
			data.ppp == "(7)" and "ённый" or
			-- [(7)] occurs with 4a осве́домить (осве́домленный, осведомлённый)
			-- [(7)] occurs with 4c иссуши́ть (иссу́шенный, иссушённый)
			data.ppp == "[(7)]" and {"енный", "ённый"} or "енный")
	end
end

-- Set the past passive participle for class-7 and class-8 verbs. These
-- form the PPP by adding to the base of the 3sg pres/futr (i.e. minus
-- -ет/-ёт). The stress follows the stress of the past singular feminine.
-- Only types a, a(1) and b exist, meaning that if the past singular feminine
-- is ending-stressed then the PPP ending is -ённый, otherwise it is -енный
-- with the stress of the 3sg pres/futr base preserved (and added to the
-- last syllable if the base has no stress, as in 7b укра́сть, 3sg украдёт,
-- fem sg past укра́ла, PPP укра́денный).
local function set_class_7_8_ppp(forms, args, data)
	if not data.ppp then
		return
	end
	local sg3_bases = {}
	-- Extract 3sg bases. It's unlikely that there is more than one possible
	-- form but we support it.
	-- FIXME: We don't support checking for overrides here; doing so isn't
	-- overly hard but is a bit tricky because the overrides will be either
	-- pres_3sg or futr_3sg, depending on the aspect of the verb.
	-- FIXME: We don't support manual translit here, because neither 7 nor 8
	-- support it elsewhere.
	for _, form in pairs(main_to_all_verb_forms["pres_futr_3sg"]) do
		local ru, tr
		if forms[form] then
			ru, tr = extract_russian_tr(forms[form])
		end
		if ru and ru ~= "" and ru ~= "-" then
			ru = rsub(ru, "[её]т$", "")
			if com.is_unstressed(ru) then
				ru = com.make_ending_stressed(ru)
			end
			ut.insert_if_not(sg3_bases, ru)
		end
	end

	-- Here we do the same rigmarole as in set_ppp_from_past_m(), to respect
	-- any past_f overrides that might have been set. It's unlikely that
	-- there is more than one possible form but we support it.
	for _, form in pairs(main_to_all_verb_forms["past_f"]) do
		local ru, tr
		if args[form] then
			local override = parse_and_stress_override(form, args[form])
			ru, tr = extract_russian_tr(override)
		end
		if (not ru or ru == "" or ru == "-") and forms[form] then
			ru, tr = extract_russian_tr(forms[form])
		end
		if ru and ru ~= "" and ru ~= "-" then
			for _, base in ipairs(sg3_bases) do
				append_ppp(forms, base, nil,
					-- check if past_f is ending-stressed
					rfind(ru, AC .. "$") and "ённый" or "енный")
			end
		end
	end
end

--[=[
	Conjugation functions
]=]--

conjugations["1a"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"+p", "7", "ё"})
	local stem, tr = nom.split_russian_tr(get_stressed_arg(args, 3))
	no_stray_args(args, 3)

	forms["infinitive"] = combine(stem, tr, "ть")
	append_participles(forms, stem, tr, "ющий", "емый", "я", "вший", "вши", "в")
	set_moving_ppp(forms, data)
	present_je_a(forms, stem, tr)
	set_imper(forms, stem, tr, "й", "йте")
	set_past(forms, stem, tr, "л", "ла", "ло", "ли")

	return forms
end

local function guts_of_class_2(args, data)
	local forms = {}

	local inf_stem, inf_tr = nom.split_russian_tr(get_stressed_arg(args, 3))
	no_stray_args(args, 3)
	local pres_stem, pres_tr = inf_stem, inf_tr
	local variants = args[1] or ""
	parse_variants(data, variants, {"+p", "7"})
	-- If stem ends in -ева́ть and a past passive participle is called for
	-- with stress on the -е-, automatically set -о- or -ё- as required.
	if data.ppp and data.ppp ~= "(7)" then
		if rfind(inf_stem, "цева́") then
			if data.ppp == "[(7)]" then
				-- FIXME. Theoretically we should support this but there
				-- aren't any verbs requiring it. It won't work properly
				-- currently because we need the о to appear only when
				-- stressed.
				error("Variant [(7)] not supported for class 2")
			end
			-- цев -> цо́в, e.g. (об)лицева́ть -> (об)лицо́ванный
			data.o = true
			data.title = data.title .. "(-о-)"
		elseif rfind(inf_stem, "ева́") then
			data.yo = true
			data.title = data.title .. "(-ё-)"
		end
	end

	-- all -ова- change to -у-
	pres_stem = rsub(pres_stem, "о(́?)ва(́?)$", "у%1%2")
	pres_tr = pres_tr and rsub(pres_tr, "o(́?)va(́?)$", "u%1%2")
	-- -ева- change to -ю- after most consonants and vowels, to -у- after hissing sounds and ц
	if rfind(pres_stem, "[бвгдзклмнпрстфхь" .. com.vowel .. AC .. "]е(́?)ва(́?)$") then
		pres_stem = rsub(pres_stem, "е(́?)ва(́?)$", "ю%1%2")
		pres_tr = pres_tr and rsub(pres_tr, "e(́?)va(́?)$", "ju%1%2")
	elseif rfind(pres_stem, "[жцчшщ]е(́?)ва(́?)$") then
		pres_stem = rsub(pres_stem, "е(́?)ва(́?)$", "у%1%2")
		pres_tr = pres_tr and rsub(pres_tr, "e(́?)va(́?)$", "u%1%2")
	end

	forms["infinitive"] = combine(inf_stem, inf_tr, "ть")
	if data.conj_type == "2a" then
		append_participles_2stem(forms, pres_stem, pres_tr, inf_stem, inf_tr,
			"ющий", "емый", "я", "вший", "вши", "в")
		present_je_a(forms, pres_stem, pres_tr)
	else
		append_participles_2stem(forms, pres_stem, pres_tr, inf_stem, inf_tr,
			"ю́щий", "-", "я́", "вший", "вши", "в")
		present_je_b(forms, pres_stem, pres_tr)
	end
	set_moving_ppp(forms, data)
	set_imper(forms, pres_stem, pres_tr, "й", "йте")
	set_past(forms, inf_stem, inf_tr, "л", "ла", "ло", "ли")

	return forms
end

conjugations["2a"] = function(args, data)
	return guts_of_class_2(args, data)
end

conjugations["2b"] = function(args, data)
	return guts_of_class_2(args, data)
end

conjugations["3°a"] = function(args, data)
	local forms = {}

	-- (5), [(6)] or similar; imperative indicators
	data.title = "class 3°a" -- in case it is "class 3oa"
	parse_variants(data, args[1], {"5", "6", "23", "и", "+p", "7", "ё"})
	local stem = get_stressed_arg(args, 3)
	local vowel_stem = is_vowel_stem(stem)
	no_stray_args(args, 3)

	forms["infinitive"] = stem .. "нуть"

	append_participles(forms, stem, nil,
		-- default is blank for pres passive and adverbial
		"нущий", "-", "-",
		data.var6 == "req" and "нувший" or
		data.var6 == "opt" and (vowel_stem and {"вший", "нувший"} or {"ший", "нувший"}) or
		vowel_stem and "вший" or "ший",
		data.var6 == "req" and "нувши" or
		data.var6 == "opt" and (vowel_stem and {"вши", "нувши"} or {"ши", "нувши"}) or
		vowel_stem and "вши" or "ши",
		data.var6 == "req" and "нув" or
		data.var6 == "opt" and (vowel_stem and {"в", "нув"} or "нув") or
		vowel_stem and "в" or "-")
	set_moving_ppp(forms, data)
	present_e_a(forms, stem .. "н")
	append_imper_by_variant(forms, stem .. "н", nil, data.imper_variant, "3°a")

	forms["past_m"] = data.var5 and stem .. "нул" or "-"
	forms["past_m_short"] = data.var5 ~= "req" and (vowel_stem and stem .. "л" or stem) or nil
	forms["past_f_short"] = stem .. "ла"
	forms["past_n_short"] = stem .. "ло"
	forms["past_pl_short"] = stem .. "ли"

	return forms
end

conjugations["3oa"] = conjugations["3°a"]

conjugations["3a"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"23", "и", "+p", "7", "ё"})
	local stem = get_stressed_arg(args, 3)
	no_stray_args(args, 3)

	forms["infinitive"] = stem .. "нуть"
	append_participles(forms, stem, nil,
		-- default is blank for pres passive and adverbial
		"нущий", "-", "-", "нувший", "нувши", "нув")
	set_moving_ppp(forms, data)
	present_e_a(forms, stem .. "н")

	append_imper_by_variant(forms, stem .. "н", nil, data.imper_variant, "3a")
	set_past(forms, stem .. "нул", nil, "", "а", "о", "и")

	return forms
end

local function guts_of_3b_3c(forms, data, stem_noa)
	forms["infinitive"] = stem_noa .. "у́ть"

	append_participles(forms, stem_noa, nil,
		-- default is blank for pres passive and adverbial
		"у́щий", "-", "-", "у́вший", "у́вши", "у́в")
	set_moving_ppp(forms, data)
	set_imper(forms, stem_noa, nil, "и́", "и́те")
	set_past(forms, stem_noa .. "у́л", nil, "", "а", "о", "и")
end

conjugations["3b"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"+p", "7", "ё"})
	local stem = get_unstressed_arg(args, 3)
	no_stray_args(args, 3)

	guts_of_3b_3c(forms, data, stem)
	present_e_b(forms, stem)

	return forms
end

conjugations["3c"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"+p", "7", "ё"})
	local stem = get_stressed_arg(args, 3)
	no_stray_args(args, 3)
	-- remove accent for some forms
	local stem_noa = com.remove_accents(stem)

	guts_of_3b_3c(forms, data, stem_noa)
	present_e_c(forms, stem)

	return forms
end

conjugations["4a"] = function(args, data)
	local forms = {}

	-- imperative variants, also щ, used for verbs like похитить (похи́щу) (4a),
	-- защитить (защищу́) (4b), поглотить (поглощу́) (4c) with a different
	-- iotation (т -> щ, not ч)
	parse_variants(data, args[1], {"23", "и", "щ", "past", "+p", "7", "жд"})
	local stem, tr = nom.split_russian_tr(get_stressed_arg(args, 3))
	no_stray_args(args, 3)

	forms["infinitive"] = combine(stem, tr, "ить")

	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	local hushing = rfind(stem, "[шщжч]$")
	append_participles(forms, stem, tr, hushing and "ащий" or "ящий",
		"имый", hushing and "а" or "я", "ивший", "ивши", "ив")
	set_class_4_ppp(forms, data, stem, tr)
	present_i_a(forms, stem, tr, data.shch)
	append_imper_by_variant(forms, stem, tr, data.imper_variant, "4a")
	-- set prefix to "" as past stem may vary in length and no (1) variants
	set_past_by_stress(forms, data.past_stress, "", nil, stem .. "и",
		tr and tr .. "i", args, data)

	return forms
end

conjugations["4a1a"] = function(args, data)
	local forms = {}

	data.title = "class 4a//1a"
	-- imperative variants, also щ, used for verbs like похитить (похи́щу) (4a),
	-- защитить (защищу́) (4b), поглотить (поглощу́) (4c) with a different
	-- iotation (т -> щ, not ч)
	parse_variants(data, args[1], {"23", "и", "щ", "past", "+p", "7", "жд"})
	local stem1, tr1 = nom.split_russian_tr(get_stressed_arg(args, 3))
	local stem4 = rsub(stem1, "[ая]$", "")
	local tr4 = tr1 and rsub(tr1, "j?a$", "")
	no_stray_args(args, 3)

	forms["infinitive"] = combine(stem4, tr4, "ить")

	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	local hushing = rfind(stem4, "[шщжч]$")
	append_participles(forms, stem4, tr4, hushing and "ащий" or "ящий",
		"имый", hushing and "а" or "я", "ивший", "ивши", "ив")
	append_participles(forms, stem1, tr1, "ющий", "емый", "я", {}, {}, {})
	set_class_4_ppp(forms, data, stem4, tr4)
	present_i_a(forms, stem4, tr4, data.shch)
	present_je_a(forms, stem1, tr1)
	append_imper_by_variant(forms, stem4, tr4, data.imper_variant, "4a")
	append_imper(forms, stem1, tr1, "й", "йте")
	-- set prefix to "" as past stem may vary in length and no (1) variants
	set_past_by_stress(forms, data.past_stress, "", nil, stem4 .. "и",
		tr4 and tr4 .. "i", args, data)

	return forms
end

conjugations["4b"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"щ", "past", "+p", "8", "жд"})
	local stem, tr = nom.split_russian_tr(get_unstressed_arg(args, 3))
	no_stray_args(args, 3)

	forms["infinitive"] = combine(stem, tr, "и́ть")

	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	local hushing = rfind(stem, "[шщжч]$")
	append_participles(forms, stem, tr, hushing and "а́щий" or "я́щий",
		"и́мый", hushing and "а́" or "я́", "и́вший", "и́вши", "и́в")
	set_class_4_ppp(forms, data, stem, tr)
	present_i_b(forms, stem, tr, data.shch)
	set_imper(forms, stem, tr, "и́", "и́те")
	-- set prefix to "" as past stem may vary in length and no (1) variants
	local stem_noa, tr_noa = com.make_unstressed_once(stem ,tr)
	set_past_by_stress(forms, data.past_stress, "", nil, stem_noa .. "и́",
		tr_noa and tr_noa .. "i" .. AC, args, data)

	return forms
end

conjugations["4c"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"щ", "4", "past", "+p", "7", "жд"})
	local stem, tr = nom.split_russian_tr(get_stressed_arg(args, 3))
	no_stray_args(args, 3)

	forms["infinitive"] = combine(stem, tr, "и́ть")

	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	local hushing = rfind(stem, "[шщжч]$")
	local prap_end_stressed = hushing and "а́щий" or "я́щий"
	local prap_stem_stressed = hushing and "ащий" or "ящий"
	append_participles(forms, stem, tr, data.var4 == "req" and prap_stem_stressed
		or data.var4 == "opt" and {prap_end_stressed, prap_stem_stressed}
		or prap_end_stressed,
		"и́мый", hushing and "а́" or "я́", "и́вший", "и́вши", "и́в")
	set_class_4_ppp(forms, data, stem, tr)
	present_i_c(forms, stem, tr, data.shch)
	set_imper(forms, stem, tr, "и́", "и́те")
	local stem_noa, tr_noa = com.make_unstressed_once(stem ,tr)
	set_past_by_stress(forms, data.past_stress, "", nil, stem_noa .. "и́",
		tr_noa and tr_noa .. "i" .. AC, args, data)

	return forms
end

-- Combined class 5. But there's enough conditional code that it might make
-- more sense to separate them again.
local function guts_of_class_5(args, data)
	local forms = {}
	local is5a = data.conj_type == "5a"
	local is5b = data.conj_type == "5b"

	-- imperative ending (выгнать - выгони) and past stress; imperative is
	-- "й" after any vowel (e.g. выстоять), with or without an acute accent,
	-- otherwise ь or и
	if is5a or is5b then
		parse_variants(data, args[1], {"23", "и", "past", "+p", "7", "ё"})
	else
		parse_variants(data, args[1], {"23", "и", "past", "+p", "7", "ё", "4"})
	end
	local stem, past_stem
	if is5a then
		stem = get_stressed_arg(args, 3)
		-- обидеть, выстоять have different past tense and infinitive forms
		past_stem = get_opt_stressed_arg(args, 4) or stem .. "е"
	elseif is5b then
		stem = get_unstressed_arg(args, 3)
		past_stem = get_stressed_arg(args, 4)
	else
		stem = get_stressed_arg(args, 3)
		past_stem = get_stressed_arg(args, 4)
	end
	no_stray_args(args, 4)

	forms["infinitive"] = past_stem .. "ть"

	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	local hushing = rfind(stem, "[шщжч]$")
	if is5a then
		append_participles_2stem(forms, stem, nil, past_stem, nil,
			hushing and "ащий" or "ящий", "имый", hushing and "а" or "я",
			"вший", "вши", "в")
	elseif is5b then
		append_participles_2stem(forms, stem, nil, past_stem, nil,
			hushing and "а́щий" or "я́щий", "и́мый", hushing and "а́" or "я́",
			"вший", "вши", "в")
	else
		-- var4 occurs with at least терпре́ть and дыша́ть
		local prap_end_stressed = hushing and "а́щий" or "я́щий"
		local prap_stem_stressed = hushing and "ащий" or "ящий"
		append_participles_2stem(forms, stem, nil, past_stem, nil,
			data.var4 == "req" and prap_stem_stressed
			or data.var4 == "opt" and {prap_end_stressed, prap_stem_stressed}
			or prap_end_stressed,
			"и́мый", hushing and "а́" or "я́", "вший", "вши", "в")
	end
	set_moving_ppp(forms, data)
	if is5a then
		present_i_a(forms, stem)
	elseif is5b then
		present_i_b(forms, stem)
	else
		present_i_c(forms, stem)
	end
	append_imper_by_variant(forms, stem, nil, data.imper_variant, data.conj_type)

	-- set prefix to "" as past stem may vary in length and no (1) variants
	set_past_by_stress(forms, data.past_stress, "", nil, past_stem, nil,
		args, data)

	return forms
end

conjugations["5a"] = function(args, data)
	return guts_of_class_5(args, data)
end

conjugations["5b"] = function(args, data)
	return guts_of_class_5(args, data)
end

conjugations["5c"] = function(args, data)
	return guts_of_class_5(args, data)
end

-- Implement 6a, 6a1a and 1a6a.
local function guts_of_6a(args, data, vclass)
	local forms = {}

	-- Type 6a1a, section 13:
	-- Forms of both 6a and 1a can occur. They are the same in the infinitive
	-- and past. In the present active participle and the present/future, the
	-- type 6 forms are preferred and the type 1a forms are colloquial. In the
	-- remaining present forms and the imperative, both are equally preferred
	-- (we put the type-6 forms first because Zaliznyak lists them first).
	-- Type 6a1a section 14, type 1a6a:
	-- Forms of both 6a and 1a can occur. They are the same in the infinitive
	-- and past. In the present adverbial participle and the imperative, the
	-- type 1a forms are preferred and the type 6a forms are dated. In the
	-- remaining present forms, one or the other is slightly preferred (type
	-- 6a for 6a1a, type 1a for 1a6a).
	if vclass == "6a1as13" or vclass == "6a1as14" then
		data.title = "class 6a//1a"
	elseif vclass == "1a6a" then
		data.title = "class 1a//6a"
		-- if vclass is just 6a, data.title already set correctly
	end
	parse_variants(data, args[1], {"23", "и", "past", "+p", "7", "ё"})
	local stem = get_stressed_arg(args, 3)
	local vowel_end_stem = is_vowel_stem(stem)
	-- optional infinitive/past stem for verbs like колеба́ть
	local inf_past_stem = get_opt_stressed_arg(args, 4) or
		vowel_end_stem and stem .. "я" or stem .. "а"
	-- irregular imperatives (сыпать - сыпь is moved to a separate function but the parameter may still be needed)
	local impr_sg = get_opt_stressed_arg(args, 5)
	no_stray_args(args, 5)
	-- no iotation, e.g. вырвать - вы́рву
	local no_iotation = check_opt_arg(args, "no_iotation", {"1"})
	-- вызвать - вы́зову (в́ызов)
	local pres_stem = get_opt_stressed_arg(args, "pres_stem") or stem
	-- replace consonants for 1st person singular present/future
	local iotated_stem = no_iotation and pres_stem or com.iotation(pres_stem)

	forms["infinitive"] = inf_past_stem .. "ть"

	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	local hushing = rfind(iotated_stem, "[шщжч]$") or no_iotation

	-- Participles
	if vclass == "6a" or vclass == "6a1as13" then
		append_participles_2stem(forms, iotated_stem, nil, inf_past_stem, nil,
			hushing and "ущий" or "ющий", "емый", hushing and "а" or "я",
			"вший", "вши", "в")
		if vclass == "6a1as13" then
			-- then all the type 1a forms (both are the same in the past)
			append_participles(forms, inf_past_stem, nil, "ющий*", "емый", "я")
		end
	elseif vclass == "6a1as14" then
		-- first the preferred type 6a present active/passive participles
		append_participles(forms, iotated_stem, nil,
			hushing and "ущий" or "ющий", "емый", {}, {}, {}, {})
		-- then all the type 1a forms (both are the same in the past)
		append_participles(forms, inf_past_stem, nil, "ющий", "емый", "я",
			"вший", "вши", "в")
		-- then the dated type 6a present adverbial participle
		append_participles(forms, iotated_stem, nil,
			{}, {}, hushing and "а*" or "я*", {}, {}, {})
	else -- type 1a6a
		-- first the preferred type 1a forms (both are the same in the past)
		append_participles(forms, inf_past_stem, nil, "ющий", "емый", "я",
			"вший", "вши", "в")
		-- then the type 6a forms (dated in present adverbial participle)
		append_participles(forms, iotated_stem, nil,
			hushing and "ущий" or "ющий", "емый", hushing and "а*" or "я*",
			{}, {}, {})
	end
	set_moving_ppp(forms, data)

	-- Present/future tense
	local function class_6_present()
		if no_iotation then
			present_e_a(forms, pres_stem)
		else
			present_je_a(forms, pres_stem)
		end
	end
	if vclass == "6a" then
		class_6_present()
	elseif vclass == "1a6a" then
		-- Do type 1a forms
		present_je_a(forms, inf_past_stem)
		class_6_present()
	elseif vclass == "6a1as14" then
		class_6_present()
		-- Do type 1a forms
		present_je_a(forms, inf_past_stem)
	else
		-- 6a1as13
		class_6_present()
		-- Do type 1a forms
		present_je_a(forms, inf_past_stem, nil, "*")
	end

	-- Imperative forms; if 1a6a or 6a1as14, type 6a forms are dated;
	-- if 6a1as13, type 6a forms go first.
	local function class_1_impr()
		append_imper(forms, inf_past_stem, nil, "й", "йте")
	end
	local function class_6_impr()
		local dated_note = (vclass == "6a1as14" or vclass == "1a6a") and "*" or ""
		if impr_sg then
			-- irreg impr_sg: сыпать  - сыпь, сыпьте
			append_imper(forms, impr_sg, nil, "" .. dated_note, "те" .. dated_note)
		else
			append_imper_by_variant(forms, iotated_stem, nil, data.imper_variant,
				"6a", dated_note)
		end
	end
	if vclass == "6a1as14" or vclass == "1a6a" then
		class_1_impr()
		class_6_impr()
	elseif vclass == "6a1as13" then
		class_6_impr()
		class_1_impr()
	else
		class_6_impr()
	end

	-- set prefix to "" as past stem may vary in length and no (1) variants
	set_past_by_stress(forms, data.past_stress, "", nil, inf_past_stem, nil,
		args, data)

	if vclass == "6a1as14" or vclass == "1a6a" then
		ut.insert_if_not(data.internal_notes, "* Dated.")
	elseif vclass == "6a1as13" then
		ut.insert_if_not(data.internal_notes, "* Colloquial; type-6 forms preferred.")
	end

	return forms
end

conjugations["6a"] = function(args, data)
	return guts_of_6a(args, data, "6a")
end

conjugations["6a1as13"] = function(args, data)
	return guts_of_6a(args, data, "6a1as13")
end

conjugations["6a1as14"] = function(args, data)
	return guts_of_6a(args, data, "6a1as14")
end

conjugations["1a6a"] = function(args, data)
	return guts_of_6a(args, data, "1a6a")
end

conjugations["6b"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"past", "+p", "7", "ё"})
	local stem = get_unstressed_arg(args, 3)
	local vowel_end_stem = is_vowel_stem(stem)
	-- звать - зов, драть - дер
	local pres_stem = get_opt_unstressed_arg(args, 4) or stem
	no_stray_args(args, 4)

	forms["pres_pasv_part"] = ""

	present_e_b(forms, pres_stem)

	local impr_end = vowel_end_stem and "́й" -- accent on the preceding vowel
		or "и́"
	set_imper(forms, pres_stem, nil, impr_end, impr_end .. "те")

	if rfind(pres_stem, "[шщжч]$") then
		forms["pres_adv_part"] = pres_stem .. "а́"
	else
		forms["pres_adv_part"] = pres_stem .. "я́"
	end

	if is_vowel_stem(pres_stem) then
		forms["pres_actv_part"] = pres_stem .. "ю́щий"
	else
		forms["pres_actv_part"] = pres_stem .. "у́щий"
	end

	if vowel_end_stem then
		forms["infinitive"] = stem .. "я́ть"
		forms["past_actv_part"] = stem .. "я́вший"
		forms["past_adv_part"] = stem .. "я́вши"
		forms["past_adv_part_short"] = stem .. "я́в"
	else
		forms["infinitive"] = stem .. "а́ть"
		forms["past_actv_part"] = stem .. "а́вший"
		forms["past_adv_part"] = stem .. "а́вши"
		forms["past_adv_part_short"] = stem .. "а́в"
	end
	set_moving_ppp(forms, data)

	-- past_f for ждала́, подождала́ now handled through general mechanism
	--for разобрало́сь, past_n2 разобрало́ now handled through general mechanism
	--for разобрали́сь, past_pl2 разобрали́ now handled through general mechanism

	-- set prefix to "" as past stem may vary in length and no (1) variants
	set_past_by_stress(forms, data.past_stress, "", nil,
		stem .. (vowel_end_stem and "я́" or "а́"), nil, args, data)

	return forms
end

-- Implement 6c and 6c1a.
local function guts_of_6c(args, data, vclass)
	local forms = {}

	-- In type 6c1a, forms of both 6c and 1a can occur. They are
	-- the same in the infinitive and past. In the present active participle
	-- and the present/future, the type 6c forms are preferred and the type 1a
	-- forms are colloquial. In the remaining present forms and the imperative,
	-- both are equally preferred (we put the 6c forms first because Zaliznyak
	-- lists 6c first).
	if vclass == "6c1a" then
		data.title = "class 6c//1a"
	end
	
	-- optional щ parameter for verbs like клеветать (клевещу́), past stress
	parse_variants(data, args[1], {"щ", "past", "+p", "7", "ё"})
	local stem = get_stressed_arg(args, 3)
	no_stray_args(args, 3)
	-- remove accent for some forms
	local stem_noa = com.make_unstressed(stem)
	-- iotate the stem
	local iotated_stem = com.iotation(stem, nil, data.shch)
	local stem1a = stem_noa .. "а́"
	-- applies only to стона́ть, застона́ть, простона́ть
	local no_iotation = check_opt_arg(args, "no_iotation", {"1"})

	forms["infinitive"] = stem_noa .. "а́ть"

	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	local hushing = rfind(iotated_stem, "[шщжч]$")
	-- Participles
	append_participles_2stem(forms, iotated_stem, nil, stem_noa, nil,
		(hushing or no_iotation) and "ущий" or "ющий", {},
		hushing and "а́" or "я́", "а́вший", "а́вши", "а́в")
	if vclass == "6c1a" then
		-- then all the type 1a forms (both are the same in the past)
		append_participles(forms, stem1a, nil, "ющий*", "емый", "я")
	end
	set_moving_ppp(forms, data)

	if no_iotation then
		present_e_c(forms, stem)
	else
		present_je_c(forms, stem, nil, data.shch)
	end
	append_imper(forms, iotated_stem, nil, "и́", "и́те")
	if vclass == "6c1a" then
		present_je_a(forms, stem1a, nil, "*")
		append_imper(forms, stem1a, nil, "й", "йте")
	end

	-- set prefix to "" as past stem may vary in length and no (1) variants
	set_past_by_stress(forms, data.past_stress, "", nil, stem_noa .. "а́", nil,
		args, data)

	if vclass == "6c1a" then
		ut.insert_if_not(data.internal_notes, "* Colloquial; type-6 forms preferred.")
	end

	return forms
end

conjugations["6c"] = function(args, data)
	return guts_of_6c(args, data, "6c")
end

conjugations["6c1a"] = function(args, data)
	return guts_of_6c(args, data, "6c1a")
end

local function guts_of_class_7(args, data, forms, pres_stem,
	past_part_stem,	past_tense_stem)
	local is7b = data.conj_type == "7b"
	if not past_part_stem then
		past_part_stem = pres_stem
		if is7b and data.past_stress ~= "b" then
			past_part_stem = rsub(past_part_stem, "[дт]$", "")
		end
	end
	if not past_tense_stem then
		past_tense_stem = past_part_stem
		if is7b then
			past_tense_stem = rsub(past_tense_stem, "е́([^" .. com.vowel .. "]*)$",
				"ё%1")
		end
		past_tense_stem = rsub(past_tense_stem, "[дт]$", "")
	end
	local vowel_pp = is_vowel_stem(past_part_stem)
	local pap = vowel_pp and "вши" or "ши"
	local var9_note_symbol = next_note_symbol(data)
	append_participles_2stem(forms, pres_stem, nil, past_part_stem, nil,
		is7b and "у́щий" or "ущий", "-", is7b and "я́" or "я",
		vowel_pp and "вший" or "ший",
		data.var9 and {is7b and "я́" or "я", pap .. var9_note_symbol} or pap,
		vowel_pp and not data.var9 and "в" or "-")
	if data.var9 then
		ut.insert_if_not(data.internal_notes, var9_note_symbol .. " Dated.")
	end
	-- set prefix to "" as past stem may vary in length and no (1) variants
	set_past_by_stress(forms, data.past_stress, "", nil, past_tense_stem, nil,
		args, data,
		-- 0 ending if the past stem ends in a consonant
		not is_vowel_stem(past_tense_stem) and "no-pastml")
	-- set PPP; must be done after both present 3sg and past fem have been set
	set_class_7_8_ppp(forms, args, data)
end

conjugations["7a"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"23", "и", "9","past", "+p"})
	local full_inf = get_stressed_arg(args, 3)
	local pres_stem = get_stressed_arg(args, 4)
	local past_part_stem = get_opt_stressed_arg(args, 5)
	local past_tense_stem = get_opt_stressed_arg(args, 6)
	no_stray_args(args, 6)

	forms["infinitive"] = full_inf

	present_e_a(forms, pres_stem)
	append_imper_by_variant(forms, pres_stem, nil, data.imper_variant, "7a")
	-- вычесть - non-existent past_actv_part handled through general mechanism
	-- лезть - ле́зши - non-existent past_actv_part handled through general mechanism
	-- вычесть - past_m=вы́чел handled through general mechanism
	guts_of_class_7(args, data, forms, pres_stem, past_part_stem,
		past_tense_stem)

	return forms
end

conjugations["7b"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"9", "past", "+p"})
	local full_inf = get_stressed_arg(args, 3)
	local past_part_stem = get_opt_stressed_arg(args, 5)
	local pres_stem = past_part_stem and get_unstressed_arg(args, 4) or get_stressed_arg(args, 4)
	local past_tense_stem = get_opt_stressed_arg(args, 6)
	no_stray_args(args, 6)

	forms["infinitive"] = full_inf

	present_e_b(forms, pres_stem)
	set_imper(forms, pres_stem, nil, "и́", "и́те")
	guts_of_class_7(args, data, forms, pres_stem, past_part_stem,
		past_tense_stem)

	return forms
end

conjugations["8a"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"past", "+p"})
	local stem = get_stressed_arg(args, 3)
	local full_inf = get_stressed_arg(args, 4)
	local stressed_past_stem = args[5] and get_stressed_arg(args, 5) or stem
	no_stray_args(args, 5)
	forms["infinitive"] = full_inf

	-- default for pres_pasv_part is blank
	append_participles_2stem(forms, stem, nil, stressed_past_stem, nil,
		"ущий", "-", "-", "ший", "ши", "-")

	local iotated_stem = com.iotation(stem)

	append_pres_futr(forms, iotated_stem, nil, {}, "ешь", "ет", "ем", "ете", {})
	append_pres_futr(forms, stem, nil, "у", {}, {}, {}, {}, "ут")

	set_imper(forms, stem, nil, "и", "ите")
	-- set prefix to "" as stem may vary in length and no (1) variants
	set_past_by_stress(forms, data.past_stress, "", nil, stem, nil, args, data,
		"no-pastml")
	forms["past_m"] = stressed_past_stem

	-- set PPP; must be done after both present 3sg and past fem have been set
	set_class_7_8_ppp(forms, args, data)

	return forms
end

conjugations["8b"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"past", "+p"}, "b")
	local stem = data.past_stress == "b" and args[5] and getarg(args, 3) or
		get_stressed_arg(args, 3)
	local full_inf = get_stressed_arg(args, 4)
	local stressed_past_stem = args[5] and get_stressed_arg(args, 5) or stem
	no_stray_args(args, 5)
	forms["infinitive"] = full_inf

	-- default for pres_pasv_part is blank; влечь -> влеко́мый handled through
	-- general override mechanism
	append_participles_2stem(forms, stem, nil, stressed_past_stem, nil,
		"у́щий", "-", "-", "ший", "ши", "-")

	local iotated_stem = com.iotation(stem)

	append_pres_futr(forms, iotated_stem, nil, {}, "ёшь", "ёт", "ём", "ёте", {})
	append_pres_futr(forms, stem, nil, "у́", {}, {}, {}, {}, "у́т")
	set_imper(forms, stem, nil, "и́", "и́те")
	-- set prefix to "" as stem may vary in length and no (1) variants
	set_past_by_stress(forms, data.past_stress, "", nil, stem, nil, args, data,
		"no-pastml")
	forms["past_m"] = stressed_past_stem

	-- set PPP; must be done after both present 3sg and past fem have been set
	set_class_7_8_ppp(forms, args, data)

	return forms
end

conjugations["9a"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"past", "+p"})
	local stem = get_stressed_arg(args, 3)
	local pres_stem = get_stressed_arg(args, 4)
	no_stray_args(args, 4)
	local prefix, _, base, _ = split_prefix(stem)

	forms["infinitive"] = stem .. "еть"

	-- perfective only
	append_participles(forms, stem, nil, "-", "-", "-", "евший", "евши", "ев")
	present_e_a(forms, pres_stem)
	set_imper(forms, pres_stem, nil, "и", "ите")
	-- past_m doesn't end in л
	set_past_by_stress(forms, data.past_stress, prefix, nil, base, nil,
		args, data, "no-pastml")
	set_ppp_from_past_m(forms, args, data)

	return forms
end

conjugations["9b"] = function(args, data)
	local forms = {}

	--for this type, it's important to distinguish impf and pf
	local impf = rfind(data.verb_type, "^impf")

	parse_variants(data, args[1], {"past", "+p"})
	local stem = get_stressed_arg(args, 3)
	local pres_stem = get_unstressed_arg(args, 4)
	-- remove stress, replace ё with е
	local stem_noa = com.make_unstressed(stem)
	no_stray_args(args, 4)
	local prefix, _, base, _ = split_prefix(stem)

	forms["infinitive"] = stem_noa .. "е́ть"

	forms["pres_actv_part"] = pres_stem .. "у́щий"
	-- default is blank
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = ""

	forms["past_actv_part"] = stem .. "ший"

	if impf then --тереть -> тёрши
		forms["past_adv_part"] = stem .. "ши"
		forms["past_adv_part_short"] = ""
	else --растереть -> растере́вши, растере́в
		forms["past_adv_part"] = stem_noa .. "е́вши"
		forms["past_adv_part_short"] = stem_noa .. "е́в"
	end

	present_e_b(forms, pres_stem)
	set_imper(forms, pres_stem, nil, "и́", "и́те")

	-- past_m doesn't end in л
	set_past_by_stress(forms, data.past_stress, prefix, nil, base, nil,
		args, data, "no-pastml")
	set_ppp_from_past_m(forms, args, data)

	return forms
end

conjugations["10a"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"+p", "7"})
	local stem = get_stressed_arg(args, 3)
	no_stray_args(args, 3)

	forms["infinitive"] = stem .. "оть"

	-- These verbs are perfective-only, no present participles
	append_participles(forms, stem, nil, "-", "-", "-", "овший", "овши", "ов")
	set_moving_ppp(forms, data)
	present_je_a(forms, stem)
	set_imper(forms, stem, nil, "и", "ите")
	set_past(forms, stem .. "ол", nil, "", "а", "о", "и")

	return forms
end

conjugations["10c"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"+p", "7"})
	local inf_stem = get_stressed_arg(args, 3)
	-- present tense stressed stem "моло́ть" - ме́лет
	local pres_stem = get_stressed_arg(args, 4)
	no_stray_args(args, 4)
	-- remove accent for some forms
	local pres_stem_noa = com.remove_accents(pres_stem)

	forms["infinitive"] = inf_stem .. "ть"

	-- default for pres_pasv_part is blank
	append_participles_2stem(forms, pres_stem, nil, inf_stem, nil,
		"ющий", "-", "я́", "вший", "вши", "в")
	set_moving_ppp(forms, data)
	present_je_c(forms, pres_stem, nil)
	set_imper(forms, pres_stem_noa, nil, "и́", "и́те")
	set_past(forms, inf_stem .. "л", nil, "", "а", "о", "и")

	return forms
end

conjugations["11a"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"past", "+p"})
	local stem = get_stressed_arg(args, 3)
	no_stray_args(args, 3)
	local prefix, _, base, _ = split_prefix(stem .. "и")

	forms["infinitive"] = stem .. "ить"

	-- perfective only
	append_participles(forms, stem, nil, "-", "-", "-", "ивший", "ивши", "ив")
	present_je_a(forms, stem .. "ь")
	forms["impr_sg"] = stem .. "ей"
	forms["impr_pl"] = stem .. "ейте"

	set_past_by_stress(forms, data.past_stress, prefix, nil, base, nil,
		args, data)
	set_ppp_from_past_m(forms, args, data)

	return forms
end

conjugations["11b"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"past", "+p"})
	local stem = get_unstressed_arg(args, 3)
	local pres_stem = get_unstressed_arg(args, 4)
	no_stray_args(args, 4)
	local prefix, _, base, _ = split_prefix(stem .. "и́")

	forms["infinitive"] = stem .. "и́ть"

	append_participles_2stem(forms, pres_stem, nil, stem, nil,
		"ью́щий", "-", "ья́", "и́вший", "и́вши", "и́в")
	present_je_b(forms, pres_stem .. "ь")
	forms["impr_sg"] = stem .. "е́й"
	forms["impr_pl"] = stem .. "е́йте"

	-- e.g. пила́, лила́
	set_past_by_stress(forms, data.past_stress, prefix, nil, base, nil,
		args, data)
	set_ppp_from_past_m(forms, args, data)

	return forms
end

conjugations["12a"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"past", "+p"})
	local stem = get_stressed_arg(args, 3)
	local pres_stem = get_stressed_arg(args, 4)
	no_stray_args(args, 4)
	local prefix, _, base, _ = split_prefix(stem)

	forms["infinitive"] = stem .. "ть"

	forms["pres_actv_part"] = pres_stem .. "ющий"
	forms["pres_pasv_part"] = pres_stem .. "емый"
	forms["pres_adv_part"] = pres_stem .. "я"

	forms["past_actv_part"] = stem .. "вший"

	forms["past_adv_part"] = stem .. "вши"
	forms["past_adv_part_short"] = stem .. "в"
	present_je_a(forms, pres_stem)
	forms["impr_sg"] = pres_stem .. "й"
	forms["impr_pl"] = pres_stem .. "йте"

	set_past_by_stress(forms, data.past_stress, prefix, nil, base, nil,
		args, data)
	set_ppp_from_past_m(forms, args, data)

	return forms
end

conjugations["12b"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"past", "+p"})
	local stem = get_stressed_arg(args, 3)
	local pres_stem = get_unstressed_arg(args, 4)
	no_stray_args(args, 4)
	local prefix, _, base, _ = split_prefix(stem)

	forms["infinitive"] = stem .. "ть"

	forms["pres_actv_part"] = pres_stem .. "ю́щий"
	-- default is blank
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = pres_stem .. "я́"

	forms["past_actv_part"] = stem .. "вший"

	forms["past_adv_part"] = stem .. "вши"
	forms["past_adv_part_short"] = stem .. "в"
	present_je_b(forms, pres_stem)
	-- the preceding vowel is stressed
	forms["impr_sg"] = pres_stem .. "́й"
	forms["impr_pl"] = pres_stem .. "́йте"

	-- e.g. гнила́ but пе́ла
	set_past_by_stress(forms, data.past_stress, prefix, nil, base, nil,
		args, data)
	set_ppp_from_past_m(forms, args, data)

	return forms
end

conjugations["13b"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"+p"})
	local stem = get_stressed_arg(args, 3)
	local pres_stem = get_unstressed_arg(args, 4)
	no_stray_args(args, 4)

	forms["infinitive"] = stem .. "ть"

	forms["pres_actv_part"] = pres_stem .. "ю́щий"
	forms["pres_pasv_part"] = stem .. "емый"
	forms["pres_adv_part"] = stem .. "я"

	forms["past_actv_part"] = stem .. "вший"

	forms["past_adv_part"] = stem .. "вши"
	forms["past_adv_part_short"] = stem .. "в"
	set_moving_ppp(forms, data)
	present_je_b(forms, pres_stem)
	forms["impr_sg"] = stem .. "й"
	forms["impr_pl"] = stem .. "йте"

	set_past(forms, stem .. "л", nil, "", "а", "о", "и")

	return forms
end

conjugations["14a"] = function(args, data)
	-- only one verb: вы́жать
	local forms = {}

	parse_variants(data, args[1], {"past", "+p"})
	local stem = get_stressed_arg(args, 3)
	local pres_stem = get_stressed_arg(args, 4)
	no_stray_args(args, 4)
	local prefix, _, base, _ = split_prefix(stem)

	forms["infinitive"] = stem .. "ть"

	-- perfective only
	forms["pres_actv_part"] = ""
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = ""

	forms["past_actv_part"] = stem .. "вший"

	forms["past_adv_part"] = stem .. "вши"
	forms["past_adv_part_short"] = stem .. "в"

	present_e_a(forms, pres_stem)

	forms["impr_sg"] = pres_stem .. "и"
	forms["impr_pl"] = pres_stem .. "ите"

	set_past_by_stress(forms, data.past_stress, prefix, nil, base, nil,
		args, data)
	set_ppp_from_past_m(forms, args, data)

	return forms
end

conjugations["14b"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"past", "+p"})
	local stem = get_stressed_arg(args, 3)
	local pres_stem = get_unstressed_arg(args, 4)
	no_stray_args(args, 4)
	local prefix, _, base, _ = split_prefix(stem)

	forms["infinitive"] = stem .. "ть"

	forms["pres_actv_part"] = pres_stem .. "у́щий"
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = pres_stem .. "я́"

	forms["past_actv_part"] = stem .. "вший"

	forms["past_adv_part"] = stem .. "вши"
	forms["past_adv_part_short"] = stem .. "в"

	present_e_b(forms, pres_stem)

	forms["impr_sg"] = pres_stem .. "и́"
	forms["impr_pl"] = pres_stem .. "и́те"

	set_past_by_stress(forms, data.past_stress, prefix, nil, base, nil,
		args, data)
	set_ppp_from_past_m(forms, args, data)

	return forms
end

conjugations["14c"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"past", "+p"})
	local stem = get_stressed_arg(args, 3)
	local pres_stem = get_stressed_arg(args, 4)
	local pres_stem_noa = com.make_unstressed(pres_stem)
	no_stray_args(args, 4)
	local prefix, _, base, _ = split_prefix(stem)

	forms["infinitive"] = stem .. "ть"

	forms["pres_actv_part"] = pres_stem .. "у́щий"
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = pres_stem .. "я́"

	forms["past_actv_part"] = stem .. "вший"

	forms["past_adv_part"] = stem .. "вши"
	forms["past_adv_part_short"] = stem .. "в"

	present_e_c(forms, pres_stem)

	forms["impr_sg"] = pres_stem_noa .. "и́"
	forms["impr_pl"] = pres_stem_noa .. "и́те"

	--two forms for past_m: при́нялся, приня́лся
	--изъя́ла but приняла́
	set_past_by_stress(forms, data.past_stress, prefix, nil, base, nil,
		args, data)
	set_ppp_from_past_m(forms, args, data)

	return forms
end

conjugations["15a"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"+p"})
	local stem = get_stressed_arg(args, 3)
	no_stray_args(args, 3)

	forms["infinitive"] = stem .. "ть"

	forms["pres_actv_part"] = stem .. "нущий"
	forms["past_actv_part"] = stem .. "вший"
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = ""
	forms["past_adv_part"] = stem .. "вши"
	forms["past_adv_part_short"] = stem .. "в"

	present_e_a(forms, stem .. "н")

	forms["impr_sg"] = stem .. "нь"
	forms["impr_pl"] = stem .. "ньте"

	set_past(forms, stem .. "л", nil, "", "а", "о", "и")
	set_ppp_from_past_m(forms, args, data)

	return forms
end

conjugations["16a"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"past", "+p"})
	local stem = get_stressed_arg(args, 3)
	local stem_noa = com.make_unstressed(stem)
	no_stray_args(args, 3)
	local prefix, _, base, _ = split_prefix(stem)

	forms["infinitive"] = stem .. "ть"

	forms["pres_actv_part"] = stem_noa .. "ву́щий"
	forms["past_actv_part"] = stem .. "вший"
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = ""
	forms["past_adv_part"] = stem .. "вши"
	forms["past_adv_part_short"] = stem .. "в"

	present_e_a(forms, stem .. "в")

	forms["impr_sg"] = stem .. "ви"
	forms["impr_pl"] = stem .. "вите"

	set_past_by_stress(forms, data.past_stress, prefix, nil, base, nil,
		args, data)
	set_ppp_from_past_m(forms, args, data)

	return forms
end

conjugations["16b"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"past", "+p"})
	local stem = get_stressed_arg(args, 3)
	local stem_noa = com.make_unstressed(stem)
	no_stray_args(args, 3)
	local prefix, _, base, _ = split_prefix(stem)

	forms["infinitive"] = stem .. "ть"

	forms["pres_actv_part"] = stem_noa .. "ву́щий"
	forms["past_actv_part"] = stem .. "вший"
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = stem_noa .. "вя́"
	forms["past_adv_part"] = stem .. "вши"
	forms["past_adv_part_short"] = stem .. "в"

	present_e_b(forms, stem_noa .. "в")

	forms["impr_sg"] = stem_noa .. "ви́"
	forms["impr_pl"] = stem_noa .. "ви́те"

	-- e.g. прижило́сь, прижи́лось
	set_past_by_stress(forms, data.past_stress, prefix, nil, base, nil,
		args, data)
	set_ppp_from_past_m(forms, args, data)

	return forms
end

conjugations["irreg-бежать"] = function(args, data)
	-- irregular, only for verbs derived from бежать with the same stress pattern
	local forms = {}

	local prefix = args[3] or ""
	data.title = prefix == "вы́" and "class 5a" or "class 5b"
	parse_variants(data, args[1], {})
	no_stray_args(args, 3)

	-- вы́бежать (perfective)
	if prefix == "вы́" then
		forms["infinitive"] = prefix .. "бежать"

		forms["past_actv_part"] = prefix .. "бежавший"
		forms["past_adv_part"] = prefix .. "бежавши"
		forms["past_adv_part_short"] = prefix .. "бежав"

		forms["impr_sg"] = prefix .. "беги"
		forms["impr_pl"] = prefix .. "бегите"
		append_pres_futr(forms, prefix, nil,
			"бегу", "бежишь", "бежит", "бежим", "бежите", "бегут")

		set_past(forms, prefix .. "бежал", nil, "", "а", "о", "и")
	else
		forms["infinitive"] = prefix .. "бежа́ть"

		forms["past_actv_part"] = prefix .. "бежа́вший"
		forms["pres_pasv_part"] = ""
		forms["past_adv_part"] = prefix .. "бежа́вши"
		forms["past_adv_part_short"] = prefix .. "бежа́в"

		forms["pres_actv_part"] = prefix .. "бегу́щий"
		forms["pres_adv_part"] = ""

		forms["impr_sg"] = prefix .. "беги́"
		forms["impr_pl"] = prefix .. "беги́те"
		append_pres_futr(forms, prefix, nil,
			"бегу́", "бежи́шь", "бежи́т", "бежи́м", "бежи́те", "бегу́т")

		set_past(forms, prefix .. "бежа́л", nil, "", "а", "о", "и")
	end
	-- no PPP's for any derivatives of бежать

	return forms
end

conjugations["irreg-хотеть"] = function(args, data)
	-- irregular, only for verbs derived from хотеть with the same stress pattern
	local forms = {}

	local prefix = args[3] or ""
	data.title = "class 5c'"
	parse_variants(data, args[1], {})
	no_stray_args(args, 3)

	forms["infinitive"] = prefix .. "хоте́ть"

	forms["past_actv_part"] = prefix .. "хоте́вший"
	forms["pres_pasv_part"] = ""
	forms["past_adv_part"] = prefix .. "хоте́вши"
	forms["past_adv_part_short"] = prefix .. "хоте́в"

	forms["pres_actv_part"] = prefix .. "хотя́щий"
	forms["pres_adv_part"] = prefix .. "хотя́"

	forms["impr_sg"] = prefix .. "хоти́"
	forms["impr_pl"] = prefix .. "хоти́те"
	append_pres_futr(forms, prefix, nil,
		"хочу́", "хо́чешь", "хо́чет", "хоти́м", "хоти́те", "хотя́т")
	set_past(forms, prefix .. "хоте́л", nil, "", "а", "о", "и")

	return forms
end

conjugations["irreg-дать"] = function(args, data)
	-- irregular, only for verbs derived from дать with the same stress pattern and вы́дать
	local forms = {}

	--for this type, it's important to distinguish if it's reflexive to set some stress patterns
	local refl = rfind(data.verb_type, "refl")

	local prefix = args[3] or ""
	data.title = prefix == "вы́" and "irreg-a" or "irreg-b"
	parse_variants(data, args[1], {"past"}, prefix == "вы́" and "a(1)" or refl and "c''" or "c'")
	no_stray_args(args, 3)

	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = ""
	-- вы́дать (perfective)
	if prefix == "вы́" then
		forms["infinitive"] = prefix .. "дать"

		forms["past_actv_part"] = prefix .. "давший"
		forms["past_adv_part"] = prefix .. "давши"
		forms["past_adv_part_short"] = prefix .. "дав"

		forms["pres_actv_part"] = ""

		forms["impr_sg"] = prefix .. "дай"
		forms["impr_pl"] = prefix .. "дайте"
		append_pres_futr(forms, prefix, nil,
			"дам", "дашь", "даст", "дадим", "дадите", "дадут")
	else
		forms["infinitive"] = prefix .. "да́ть"

		forms["past_actv_part"] = prefix .. "да́вший"
		forms["past_adv_part"] = prefix .. "да́вши"
		forms["past_adv_part_short"] = prefix .. "да́в"

		forms["pres_actv_part"] = "даю́щий"

		forms["impr_sg"] = prefix .. "да́й"
		forms["impr_pl"] = prefix .. "да́йте"
		append_pres_futr(forms, prefix, nil,
			"да́м", "да́шь", "да́ст", "дади́м", "дади́те", "даду́т")
	end

	set_past_by_stress(forms, data.past_stress, prefix, nil, "да́", nil,
		args, data)

	return forms
end

conjugations["irreg-есть"] = function(args, data)
	-- irregular, only for verbs derived from есть
	local forms = {}

	local prefix = args[3] or ""
	data.title = prefix == "вы́" and "irreg-a" or "irreg-b"
	parse_variants(data, args[1], {})
	no_stray_args(args, 3)

	forms["infinitive"] = prefix .. "е́сть"

	-- вы́есть (perfective)
	if prefix == "вы́" then
		forms["infinitive"] = prefix .. "есть"

		forms["past_actv_part"] = prefix .. "евший"
		forms["past_adv_part"] = prefix .. "евши"
		forms["past_adv_part_short"] = prefix .. "ев"

		forms["impr_sg"] = prefix .. "ешь"
		forms["impr_pl"] = prefix .. "ешьте"
		append_pres_futr(forms, prefix, nil,
			"ем", "ешь", "ест", "едим", "едите", "едят")

		set_past(forms, prefix .. "ел", nil, "", "а", "о", "и")
	else
		forms["past_actv_part"] = prefix .. "е́вший"
		forms["pres_pasv_part"] = "едо́мый"
		forms["past_adv_part"] = prefix .. "е́вши"
		forms["past_adv_part_short"] = prefix .. "е́в"

		forms["pres_actv_part"] = "едя́щий"
		forms["pres_adv_part"] = "едя́"

		forms["impr_sg"] = prefix .. "е́шь"
		forms["impr_pl"] = prefix .. "е́шьте"
		append_pres_futr(forms, prefix, nil,
			"е́м", "е́шь", "е́ст", "еди́м", "еди́те", "едя́т")

		set_past(forms, prefix .. "е́л", nil, "", "а", "о", "и")
	end

	return forms
end

conjugations["irreg-сыпать"] = function(args, data)
	-- irregular, only for verbs derived from сыпать
	local forms = {}

	local prefix = args[3] or ""
	data.title = "class 6a"
	parse_variants(data, args[1], {})
	no_stray_args(args, 3)

	-- вы́сыпать (perfective), not to confuse with высыпа́ть (1a, imperfective)
	if prefix == "вы́" then
		forms["infinitive"] = prefix .. "сыпать"

		forms["past_actv_part"] = prefix .. "сыпавший"
		forms["past_adv_part"] = prefix .. "сыпавши"
		forms["past_adv_part_short"] = prefix .. "сыпав"

		set_imper(forms, prefix .. "сып", nil, {"и", "ь"}, "ьте")
		present_je_a(forms, prefix .. "сыпл")
		append_pres_futr(forms, prefix .. "сып", nil,
			{}, "ешь", "ет", "ем", "ете", {})

		set_past(forms, prefix .. "сыпал", nil, "", "а", "о", "и")
	else
		forms["infinitive"] = prefix .. "сы́пать"

		forms["past_actv_part"] = prefix .. "сы́павший"
		forms["pres_pasv_part"] = prefix .. "сы́племый"
		forms["past_adv_part"] = prefix .. "сы́павши"
		forms["past_adv_part_short"] = prefix .. "сы́пав"

		forms["pres_actv_part"] = prefix .. "сы́плющий"
		forms["pres_adv_part"] = prefix .. "сы́пля"
		forms["pres_adv_part2"] = prefix .. "сы́пя"

		set_imper(forms, prefix .. "сы́п", nil, "ь", "ьте")
		present_je_a(forms, prefix .. "сы́пл")
		append_pres_futr(forms, prefix .. "сы́п", nil,
			{}, "ешь", "ет", "ем", "ете", {})

		set_past(forms, prefix .. "сы́пал", nil, "", "а", "о", "и")
	end

	return forms
end

conjugations["irreg-лгать"] = function(args, data)
	-- irregular, only for verbs derived from лгать with the same stress pattern
	local forms = {}

	local prefix = args[3] or ""
	data.title = "class 6°b/c"
	parse_variants(data, args[1], {})
	no_stray_args(args, 3)

	forms["infinitive"] = prefix .. "лга́ть"

	forms["past_actv_part"] = prefix .. "лга́вший"
	forms["pres_pasv_part"] = ""
	forms["past_adv_part"] = prefix .. "лга́вши"
	forms["past_adv_part_short"] = prefix .. "лга́в"

	forms["pres_actv_part"] = prefix .. "лгу́щий"
	forms["pres_adv_part"] = ""

	forms["impr_sg"] = prefix .. "лги́"
	forms["impr_pl"] = prefix .. "лги́те"

	append_pres_futr(forms, prefix, nil,
		"лгу́", "лжёшь", "лжёт", "лжём", "лжёте", "лгу́т")

	set_past(forms, prefix .. "лга́л", nil, "", "а́", "о", "и")

	return forms
end

conjugations["irreg-мочь"] = function(args, data)
	-- irregular, only for verbs derived from мочь with the same stress pattern
	local forms = {}

	local prefix = args[3] or ""
	data.title = "class 8c/b"
	parse_variants(data, args[1], {})
	no_stray_args(args, 3)

	local no_past_adv = "0"

	forms["infinitive"] = prefix .. "мо́чь"

	forms["past_actv_part"] = prefix .. "мо́гший"
	forms["pres_pasv_part"] = ""

	forms["past_adv_part"] = ""
	forms["past_adv_part_short"] = ""

	forms["pres_actv_part"] = prefix .. "мо́гущий"
	forms["pres_adv_part"] = ""

	forms["impr_sg"] = prefix .. "моги́"
	forms["impr_pl"] = prefix .. "моги́те"

	append_pres_futr(forms, prefix, nil,
		"могу́", "мо́жешь", "мо́жет", "мо́жем", "мо́жете", "мо́гут")

	set_past(forms, prefix, nil, "мо́г", "могла́", "могло́", "могли́")

	return forms
end

conjugations["irreg-слать"] = function(args, data)
	-- irregular, only for verbs derived from слать
	local forms = {}

	local prefix = args[3] or ""
	data.title = prefix == "вы́" and "class 6a" or "class 6b"
	parse_variants(data, args[1], {})
	no_stray_args(args, 3)

	-- вы́слать (perfective)
	if prefix == "вы́" then
		forms["infinitive"] = prefix .. "слать"
		forms["past_actv_part"] = prefix .. "славший"
		forms["past_adv_part"] = prefix .. "славши"
		forms["past_adv_part_short"] = prefix .. "слав"

		forms["impr_sg"] = prefix .. "шли"
		forms["impr_pl"] = prefix .. "шлите"

		present_je_a(forms, prefix .. "шл")

		set_past(forms, prefix .. "слал", nil, "", "а", "о", "и")
	else
		forms["infinitive"] = prefix .. "сла́ть"

		forms["past_actv_part"] = prefix .. "сла́вший"
		forms["pres_pasv_part"] = ""
		forms["past_adv_part"] = prefix .. "сла́вши"
		forms["past_adv_part_short"] = prefix .. "сла́в"

		forms["pres_actv_part"] = prefix .. "шлю́щий"
		forms["pres_adv_part"] = ""

		forms["impr_sg"] = prefix .. "шли́"
		forms["impr_pl"] = prefix .. "шли́те"

		present_je_b(forms, prefix .. "шл")

		set_past(forms, prefix .. "сла́л", nil, "", "а", "о", "и")
	end

	return forms
end

conjugations["irreg-идти"] = function(args, data)
	-- irregular, only for verbs derived from идти, including прийти́ and в́ыйти
	local forms = {}

	local prefix = args[3] or ""
	data.title = prefix == "вы́" and "irreg-a" or "irreg-b/b"
	parse_variants(data, args[1], {})
	no_stray_args(args, 3)

	forms["pres_pasv_part"] = ""

	if prefix == "вы́" then
		forms["infinitive"] = prefix .. "йти"
		forms["impr_sg"] = prefix .. "йди"
		forms["impr_pl"] = prefix .. "йдите"
		present_e_a(forms, prefix .. "йд")
		forms["past_adv_part"] = prefix .. "шедши"
		forms["past_adv_part_short"] = prefix .. "йдя"
	elseif prefix == "при" then
		forms["infinitive"] = prefix .. "йти́"
		forms["impr_sg"] = prefix .. "ди́"
		forms["impr_pl"] = prefix .. "ди́те"
		present_e_b(forms, prefix .. "д")
		forms["past_adv_part"] = prefix .. "ше́дши"
		forms["past_adv_part_short"] = prefix .. "дя́"
	elseif prefix == "" then
		-- only идти, present imperfective
		forms["pres_adv_part"] = "идя́"
		forms["pres_actv_part"] = "иду́щий"
		forms["infinitive"] = "идти́"
		forms["impr_sg"] = "иди́"
		forms["impr_pl"] = "иди́те"
		present_e_b(forms, "ид")
		forms["past_adv_part"] = "ше́дши"
		forms["past_adv_part_short"] = ""
	else
		forms["infinitive"] = prefix .. "йти́"
		forms["pres_actv_part"] = prefix .. "иду́щий"
		forms["impr_sg"] = prefix .. "йди́"
		forms["impr_pl"] = prefix .. "йди́те"
		present_e_b(forms, prefix .. "йд")
		forms["past_adv_part"] = prefix .. "ше́дши"
		forms["past_adv_part_short"] = prefix .. "йдя́"
	end

	-- вы́йти (perfective)
	if prefix == "вы́" then
		forms["past_actv_part"] = prefix .. "шедший"
		set_past(forms, prefix, nil, "шел", "шла", "шло", "шли")
	else
		forms["past_actv_part"] = prefix .. "ше́дший"
		set_past(forms, prefix, nil, "шёл", "шла́", "шло́", "шли́")
	end

	return forms
end

conjugations["irreg-ехать"] = function(args, data)
	-- irregular, only for verbs derived from ехать
	local forms = {}

	local prefix = args[3] or ""
	data.title = "irreg-a"
	parse_variants(data, args[1], {})
	no_stray_args(args, 3)

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
	forms["past_adv_part"] = past_stem .. "авши"
	forms["past_adv_part_short"] = past_stem .. "ав"
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

	set_past(forms, past_stem .. "ал", nil, "", "а", "о", "и")

	return forms
end

conjugations["irreg-минуть"] = function(args, data)
	-- for the irregular verb "ми́нуть"
	local forms = {}

	data.title = "class 3c"
	parse_variants(data, args[1], {})
	local stem = get_stressed_arg(args, 3)
	local stem_noa = com.make_unstressed(stem)
	no_stray_args(args, 3)

	forms["infinitive"] = stem .. "уть"

	forms["pres_actv_part"] = stem .. "у́щий"
	forms["past_actv_part"] = stem_noa .. "у́вший"
	forms["past_actv_part2"] = stem .. "увший"
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = ""
	forms["past_adv_part"] = stem_noa .. "у́вши"
	forms["past_adv_part_short"] = stem_noa .. "у́в"
	forms["past_adv_part2"] = stem .. "увши"
	forms["past_adv_part_short2"] = stem .. "ув"

	present_e_c(forms, stem)

	-- no imperative
	forms["impr_sg"] = ""
	forms["impr_pl"] = ""

	set_past(forms, stem, nil, {"у́л", "ул"}, {"у́ла", "ула"}, {"у́ло", "уло"}, {"у́ли", "ули"})

	return forms
end

conjugations["irreg-живописать-миновать"] = function(args, data)
	-- for irregular verbs "живописа́ть" and "минова́ть", mixture of types 1 and 2
	local forms = {}

	data.title = "class 1a"
	parse_variants(data, args[1], {})
	local inf_stem = get_stressed_arg(args, 3)
	local pres_stem = get_stressed_arg(args, 4)
	no_stray_args(args, 4)

	forms["infinitive"] = inf_stem .. "ть"

	forms["pres_actv_part"] = pres_stem .. "ющий"
	forms["past_actv_part"] = inf_stem .. "вший"
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = pres_stem .. "я"
	forms["past_adv_part"] = inf_stem .. "вши"
	forms["past_adv_part_short"] = inf_stem .. "в"

	present_je_a(forms, pres_stem)

	forms["impr_sg"] = pres_stem .. "й"
	forms["impr_pl"] = pres_stem .. "йте"

	set_past(forms, inf_stem .. "л", nil, "", "а", "о", "и")

	return forms
end

conjugations["irreg-лечь"] = function(args, data)
	-- irregular, only for verbs derived from лечь with the same stress pattern
	local forms = {}

	local prefix = args[3] or ""
	data.title = "class 8a/b"
	parse_variants(data, args[1], {})
	no_stray_args(args, 3)

	forms["infinitive"] = prefix .. "ле́чь"

	forms["past_actv_part"] = prefix .. "лёгший"
	forms["pres_pasv_part"] = ""

	forms["past_adv_part"] = prefix .. "лёгши"
	forms["past_adv_part_short"] = ""

	forms["pres_actv_part"] = ""
	forms["pres_adv_part"] = ""

	forms["impr_sg"] = prefix .. "ля́г"
	forms["impr_pl"] = prefix .. "ля́гте"
	append_pres_futr(forms, prefix, nil,
		"ля́гу", "ля́жешь", "ля́жет", "ля́жем", "ля́жете", "ля́гут")
	set_past(forms, prefix, nil, "лёг", "легла́", "легло́", "легли́")

	return forms
end

conjugations["irreg-зиждиться"] = function(args, data)
	-- irregular, only for verbs derived from зиждиться with the same stress pattern
	local forms = {}

	local prefix = args[3] or ""
	data.title = "irreg-a"
	parse_variants(data, args[1], {})
	no_stray_args(args, 3)

	forms["infinitive"] = prefix .. "зи́ждить"

	forms["past_actv_part"] = prefix .. "зи́ждивший"
	forms["pres_pasv_part"] = ""

	forms["past_adv_part"] = prefix .. "зи́ждивши"
	forms["past_adv_part_short"] = ""

	forms["pres_actv_part"] = prefix .. "зи́ждущий"
	forms["pres_adv_part"] = prefix .. "зи́ждя"

	forms["impr_sg"] = prefix .. "зи́жди"
	forms["impr_pl"] = prefix .. "зи́ждите"
	present_e_a(forms, prefix .. "зи́жд")
	set_past(forms, prefix .. "зи́ждил", nil, "", "а", "о", "и")

	return forms
end

conjugations["irreg-клясть"] = function(args, data)
	-- irregular, only for verbs derived from клясть with the same stress pattern
	local forms = {}

	--for this type, it's important to distinguish if it's reflexive to set some stress patterns
	local refl = rfind(data.verb_type, "refl")

	local prefix = args[3] or ""
	data.title = "irreg-b"
	parse_variants(data, args[1], {"past"}, prefix == "вы́" and "a(1)" or refl and "c''" or "c")
	no_stray_args(args, 3)

	forms["infinitive"] = prefix .. "кля́сть"

	forms["past_actv_part"] = prefix .. "кля́вший"
	forms["pres_pasv_part"] = prefix .. "кляну́щий"

	forms["past_adv_part"] = prefix .. "кля́вши"
	forms["past_adv_part_short"]  =prefix .. "кля́в"

	forms["pres_actv_part"] = prefix .. "кляну́щий"
	forms["pres_adv_part"] = prefix .. "кляня́"

	forms["impr_sg"] = prefix .. "кляни́"
	forms["impr_pl"] = prefix .. "кляни́те"
	present_e_b(forms, prefix .. "клян")
	set_past_by_stress(forms, data.past_stress, prefix, nil, "кля́", nil,
		args, data)

	return forms
end

conjugations["irreg-стелить-стлать"] = function(args, data)
	-- irregular, only for verbs derived from стелить and стлать with the same stress pattern
	local forms = {}

	local prefix = args[4] or ""
	local stem = get_stressed_arg(args, 3)
	data.title = ((prefix == "вы́" and stem == "стлать") and "class 6a" or
		stem == "стла́ть" and "class 6c" or
		stem == (prefix == "вы́" and stem == "стелить") and "class 4a" or
		"class 4c")
	parse_variants(data, args[1], {})
	no_stray_args(args, 4)

	forms["infinitive"] = prefix .. stem .. "ть"

	forms["past_actv_part"] = prefix .. stem .. "вший"
	forms["past_adv_part"] = prefix .. stem .. "вши"
	forms["past_adv_part_short"] = prefix  .. stem .. "в"

	if prefix == "вы́" then
		forms["pres_pasv_part"] = prefix .. "стелимый"
		forms["pres_actv_part"] = prefix .. "стелющий"
		forms["pres_adv_part"] = prefix .. "стеля"

		forms["impr_sg"] = prefix .. "стели"
		forms["impr_pl"] = prefix .. "стелите"
		present_je_c(forms, prefix .. "стел")
	else
		forms["pres_pasv_part"] = prefix .. "стели́мый"
		forms["pres_actv_part"] = prefix .. "сте́лющий"
		forms["pres_adv_part"] = prefix .. "стеля́"

		forms["impr_sg"] = prefix .. "стели́"
		forms["impr_pl"] = prefix .. "стели́те"
		present_je_c(forms, prefix .. "сте́л")
	end
	set_past(forms, prefix .. stem .. "л", nil, "", "а", "о", "и")

	return forms
end

conjugations["irreg-быть"] = function(args, data)
	-- irregular, only for verbs derived from быть with various stress patterns, the actual verb быть different from its derivatives
	local forms = {}

	--for this type, it's important to distinguish if it's reflexive to set some stress patterns
	local refl = rfind(data.verb_type, "refl")

	local prefix = args[3] or ""
	data.title = "irreg-a"
	parse_variants(data, args[1], {"past"}, prefix == "вы́" and "a(1)" or refl and "c''" or "c")
	no_stray_args(args, 3)

	forms["pres_pasv_part"] = ""
	-- if the prefix is stressed
	if com.is_stressed(prefix) then
		forms["infinitive"] = prefix .. "быть"
		forms["pres_actv_part"] = prefix .. "сущий"
		forms["past_actv_part"] = prefix .. "бывший"
		forms["past_adv_part"] = prefix .. "бывши"
		forms["past_adv_part_short"] = prefix .. "быв"
		forms["impr_sg"] = prefix .. "будь"
		forms["impr_pl"] = prefix .. "будьте"
	else
		forms["infinitive"] = prefix .. "бы́ть"
		forms["pres_actv_part"] = prefix .. "су́щий"
		forms["past_actv_part"] = prefix .. "бы́вший"
		--only for "бы́ть" - бу́дучи
		if prefix == "" then
			forms["pres_adv_part"] = "бу́дучи"
		else
			forms["pres_adv_part"] = ""
		end
		forms["past_adv_part"] = prefix .. "бы́вши"
		forms["past_adv_part_short"] = prefix .. "бы́в"
		forms["impr_sg"] = prefix .. "бу́дь"
		forms["impr_pl"] = prefix .. "бу́дьте"
	end


	-- only for "бы́ть", some forms are archaic
	if forms["infinitive"] == "бы́ть" then
		append_pres_futr(forms, "", nil,
			"есмь", "еси́", "есть", "есмы́", "е́сте", "суть")
	elseif com.is_stressed(prefix) then
		-- if the prefix is stressed, e.g. "вы́быть"
		present_e_a(forms, prefix .. "буд")
	else
		present_e_a(forms, prefix .. "бу́д")
	end

	set_past_by_stress(forms, data.past_stress, prefix, nil, "бы́", nil,
		args, data)

	return forms
end

conjugations["irreg-ссать-сцать"] = function(args, data)
	-- irregular, only for verbs derived from ссать and сцать (both vulgar!)
	local forms = {}

	local prefix = args[5] or ""
	data.title = prefix == "вы́" and "irreg-a" or "irreg-b"
	parse_variants(data, args[1], {})
	local stem = get_stressed_arg(args, 3)
	local pres_stem = get_unstressed_arg(args, 4)

	no_stray_args(args, 5)
	-- if the prefix is stressed, remove stress from the stem
	if com.is_stressed(prefix) then
		stem = com.remove_accents(stem)
	end

	forms["infinitive"] = prefix .. stem .. "ть"

	-- if the prefix is stressed, probably only вы́-
	if com.is_stressed(prefix) then
		forms["pres_actv_part"] = prefix .. pres_stem .. "ущий"

		forms["impr_sg"] = prefix .. pres_stem .. "ы"
		forms["impr_pl"] = prefix .. pres_stem .. "ыте"
		append_pres_futr(forms, prefix .. pres_stem, nil,
			"у", "ышь", "ыт", "ым", "ыте", "ут")
	else
		forms["pres_actv_part"] = prefix .. pres_stem .. "у́щий"

		forms["impr_sg"] = prefix .. pres_stem .. "ы́"
		forms["impr_pl"] = prefix .. pres_stem .. "ы́те"
		append_pres_futr(forms, prefix .. pres_stem, nil,
			"у́", "ы́шь", "ы́т", "ы́м", "ы́те", "у́т")
	end

	forms["past_actv_part"] = prefix .. stem .. "вший"
	forms["pres_pasv_part"] = ""
	forms["past_adv_part"] = prefix .. stem .. "вши"
	forms["past_adv_part_short"] = prefix  .. stem .. "в"

	forms["pres_adv_part"] = ""

	set_past(forms, prefix .. stem .. "л", nil, "", "а", "о", "и")

	return forms
end

conjugations["irreg-чтить"] = function(args, data)
	-- irregular, only for verbs derived from чтить
	local forms = {}

	local prefix = args[3] or ""
	data.title = "class 4b"
	parse_variants(data, args[1], {})
	no_stray_args(args, 3)

	forms["infinitive"] = prefix .. "чти́ть"

	forms["past_actv_part"] = prefix .. "чти́вший"
	forms["pres_pasv_part"] = "чти́мый"
	forms["past_adv_part"] = prefix .. "чти́вши"
	forms["past_adv_part_short"] = prefix .. "чти́в"

	forms["pres_actv_part"] = prefix .. "чтя́щий"
	forms["pres_actv_part2"] = prefix .. "чту́щий"
	forms["pres_adv_part"] = prefix .. "чтя́"

	forms["impr_sg"] = prefix .. "чти́"
	forms["impr_pl"] = prefix .. "чти́те"

	append_pres_futr(forms, prefix .. "чт", nil,
		"у́", "и́шь", "и́т", "и́м", "и́те", {"я́т", "у́т"})

	set_past(forms, prefix .. "чти́л", nil, "", "а", "о", "и")

	return forms
end

conjugations["irreg-шибить"] = function(args, data)
	-- irregular, only for verbs in -шибить(ся)
	local forms = {}

	local prefix = args[3] or ""
	data.title = prefix == "вы́" and "irreg-a" or "irreg-b"
	parse_variants(data, args[1], {})
	no_stray_args(args, 3)

	forms["pres_pasv_part"] = ""
	forms["pres_actv_part"] = ""
	forms["pres_actv_part2"] = ""
	forms["pres_adv_part"] = ""
	if com.is_stressed(prefix) then
		-- if the prefix is stressed (probably only вы́-)
		forms["infinitive"] = prefix .. "шибить"

		forms["past_actv_part"] = prefix .. "шибивший"
		forms["past_adv_part"] = prefix .. "шибивши"
		forms["past_adv_part_short"] = prefix .. "шибив"

		forms["impr_sg"] = prefix .. "шиби"
		forms["impr_pl"] = prefix .. "шибите"
		present_e_a(forms, prefix .. "шиб")
		set_past(forms, prefix .. "шиб", nil, "", "ла", "ло", "ли")
	else
		forms["infinitive"] = prefix .. "шиби́ть"

		forms["past_actv_part"] = prefix .. "шиби́вший"
		forms["past_adv_part"] = prefix .. "шиби́вши"
		forms["past_adv_part_short"] = prefix .. "шиби́в"

		forms["impr_sg"] = prefix .. "шиби́"
		forms["impr_pl"] = prefix .. "шиби́те"
		present_e_b(forms, prefix .. "шиб")
		set_past(forms, prefix .. "ши́б", nil, "", "ла", "ло", "ли")
	end

	return forms
end

conjugations["irreg-реветь"] = function(args, data)
	-- irregular, only for verbs derived from "реветь"
	local forms = {}

	local prefix = args[3] or ""
	data.title = "irreg-b"
	parse_variants(data, args[1], {})
	no_stray_args(args, 3)

	forms["infinitive"] = prefix .. "реве́ть"

	forms["pres_actv_part"] = prefix .. "реву́щий"
	forms["past_actv_part"] = prefix .. "реве́вший"
	forms["pres_pasv_part"] = ""
	forms["pres_adv_part"] = prefix .. "ревя́"
	forms["past_adv_part"] = prefix .. "реве́вши"
	forms["past_adv_part_short"] = prefix .. "реве́в"

	present_e_b(forms, prefix .. "рев")
	-- no imperative
	forms["impr_sg"] = prefix .. "реви́"
	forms["impr_pl"] = prefix .. "реви́те"

	set_past(forms, prefix .. "реве́л", nil, "", "а", "о", "и")

	return forms
end

conjugations["irreg-внимать"] = function(args, data)
	-- irregular, only for внимать
	local forms = {}

	local prefix = args[3] or ""
	data.title = "class 1a//6a"
	parse_variants(data, args[1], {})
	no_stray_args(args, 3)

	forms["infinitive"] = prefix .. "внима́ть"

	-- handle внемл- forms
	append_participles(forms, prefix .. "вне́мл", nil,
		"ющий", "емый", {"я", "я́"}, {}, {}, {})
	-- handle внима́- forms
	append_participles(forms, prefix .. "внима́", nil,
		"ющий", "емый", "я", "вший", "вши", "в")
	set_imper(forms, prefix, nil, {"вне́мли", "внемли́", "внима́й"},
		{"вне́млите", "внемли́те", "внима́йте"})
	present_je_a(forms, prefix .. "вне́мл")
	-- Both вне́млю and внемлю́ are possible
	append_pres_futr(forms, prefix .. "внемл", nil, "ю́", {}, {}, {}, {}, {})
	present_je_a(forms, prefix .. "внима́")
	set_past(forms, prefix .. "внима́л", nil, "", "а", "о", "и")

	return forms
end

conjugations["irreg-внять"] = function(args, data)
	-- irregular, only for внять
	local forms = {}

	local prefix = args[3] or ""
	data.title = "class 14c/c"
	parse_variants(data, args[1], {})
	no_stray_args(args, 3)

	forms["infinitive"] = prefix .. "вня́ть"

	forms["past_actv_part"] = prefix .. "вня́вший"
	forms["pres_pasv_part"] = prefix .. ""
	forms["past_adv_part"] = prefix .. "вня́вши"
	forms["past_adv_part_short"] = prefix .. "вня́в"

	forms["pres_actv_part"] = prefix .. ""
	forms["pres_adv_part"] = prefix .. ""

	forms["impr_sg"] = prefix .. "вними́"
	forms["impr_pl"] = prefix .. "вними́те"
	forms["impr_sg2"] = prefix .. "вонми́"
	forms["impr_pl2"] = prefix .. "вонми́те"

	present_e_c(forms, prefix .. "вни́м")
	present_e_c(forms, prefix .. "во́нм")
	set_past(forms, prefix .. "вня́л", nil, "", "а́", "о", "и")

	return forms
end

conjugations["irreg-обязывать"] = function(args, data)
	-- irregular, only for the reflexive verb обязываться
	local forms = {}

	local prefix = args[3] or ""
	data.title = "class 1a"
	parse_variants(data, args[1], {})
	no_stray_args(args, 3)

	forms["infinitive"] = prefix .. "обя́зывать"

	forms["past_actv_part"] = prefix .. "обя́зывавший"
	forms["pres_pasv_part"] = prefix .. "обя́зываемый"
	forms["pres_pasv_part2"] = prefix .. "обязу́емый"
	forms["past_adv_part"] = prefix .. "обя́зывавши"
	forms["past_adv_part_short"] = prefix .. "обя́зывав"

	forms["pres_actv_part"] = prefix .. "обя́зывающий"
	forms["pres_actv_part2"] = prefix .. "обязу́ющий"
	forms["pres_adv_part"] = prefix .. "обя́зывая"
	forms["pres_adv_part2"] = prefix .. "обязу́я"

	forms["impr_sg"] = prefix .. "обя́зывай"
	forms["impr_sg2"] = prefix .. "обязу́й"
	forms["impr_pl"] = prefix .. "обя́зывайте"
	forms["impr_pl2"] = prefix .. "обязу́йте"

	present_je_a(forms, prefix .. "обя́зыва")
	present_je_a(forms, prefix .. "обязу́")

	set_past(forms, prefix .. "обя́зывал", nil, "", "а", "о", "и")

	return forms
end

--[=[
	Partial conjugation functions
]=]--

-- Present forms with -e-, no j-vowels.
present_e_a = function(forms, stem, tr)
	append_pres_futr(forms, stem, tr, "у", "ешь", "ет", "ем", "ете", "ут")
end

present_e_b = function(forms, stem, tr)
	local vowel_stem = is_vowel_stem(stem)
	append_pres_futr(forms, stem, tr,
		vowel_stem and "ю́" or "у́", "ёшь", "ёт", "ём", "ёте",
		vowel_stem and "ю́т" or "у́т")
end

present_e_c = function(forms, stem, tr)
	append_pres_futr(forms, stem, tr, "у́", "ешь", "ет", "ем", "ете", "ут")
end

-- Present forms with -e-, with j-vowels.
present_je_a = function(forms, stem, tr, note)
	local iotated_stem, iotated_tr = com.iotation(stem, tr)

	local hushing = rfind(iotated_stem, "[шщжч]$")
	note = note or ""
	append_pres_futr(forms, iotated_stem, iotated_tr,
		hushing and "у" .. note or "ю" .. note, "ешь" .. note, "ет" .. note,
		"ем" .. note, "ете" .. note,
		hushing and "ут" .. note or "ют" .. note)
end

present_je_b = function(forms, stem, tr)
	append_pres_futr(forms, stem, tr, "ю́", "ёшь", "ёт", "ём", "ёте", "ю́т")
end

present_je_c = function(forms, stem, tr, shch)
	-- shch - iotate final т as щ, not ч

	-- iotate the stem
	local iotated_stem, iotated_tr = com.iotation(stem, tr, shch)

	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	local hushing = rfind(iotated_stem, "[шщжч]$") -- or no_iotation
	append_pres_futr(forms, iotated_stem, iotated_tr,
		hushing and "у́" or "ю́", "ешь", "ет", "ем", "ете",
		hushing and "ут" or "ют")
end

-- Present forms with -i-.
present_i_a = function(forms, stem, tr, shch)
	-- shch - iotate final т as щ, not ч

	-- iotate the stem
	local iotated_stem, iotated_tr = com.iotation(stem, tr, shch)

	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	local iotated_hushing = rfind(iotated_stem, "[шщжч]$")
	local hushing = rfind(stem, "[шщжч]$")
	local ending_1sg = iotated_hushing and "у" or "ю"
	append_pres_futr(forms, stem, tr,
		{}, "ишь", "ит", "им", "ите", hushing and "ат" or "ят")
	append_pres_futr(forms, iotated_stem, iotated_tr,
		ending_1sg, {}, {}, {}, {}, {})
end

present_i_b = function(forms, stem, tr, shch)
	-- parameter shch - iotatate final т as щ, not ч
	if not shch then
		shch = ""
	end

	-- iotate the stem
	local iotated_stem, iotated_tr = com.iotation(stem, tr, shch)

	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	local iotated_hushing = rfind(iotated_stem, "[шщжч]$")
	local hushing = rfind(stem, "[шщжч]$")
	local ending_1sg = iotated_hushing and "у́" or "ю́"
	append_pres_futr(forms, stem, tr,
		{}, "и́шь", "и́т", "и́м", "и́те", hushing and "а́т" or "я́т")
	append_pres_futr(forms, iotated_stem, iotated_tr,
		ending_1sg, {}, {}, {}, {}, {})
end

present_i_c = function(forms, stem, tr, shch)
	-- shch - iotate final т as щ, not ч

	-- iotate the stem
	local iotated_stem, iotated_tr = com.iotation(stem, tr, shch)

	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	local iotated_hushing = rfind(iotated_stem, "[шщжч]$")
	local hushing = rfind(stem, "[шщжч]$")
	local ending_1sg = iotated_hushing and "у́" or "ю́"
	append_pres_futr(forms, stem, tr,
		{}, "ишь", "ит", "им", "ите", hushing and "ат" or "ят")
	append_pres_futr(forms, iotated_stem, iotated_tr,
		ending_1sg, {}, {}, {}, {}, {})
end

-- Add the reflexive particle to all verb forms
make_reflexive = function(forms, reflex_stress)
	for key, form in pairs(forms) do
		local ru, tr = extract_russian_tr(form)
		-- check for empty strings, dashes and nil's
		if ru ~= "" and ru and ru ~= "-" then
			local ruentry, runotes = m_table_tools.separate_notes(ru)
			local trentry, trnotes
			if tr then
				trentry, trnotes = m_table_tools.separate_notes(tr)
			end
			if is_vowel_stem(ruentry) then
				forms[key] = {ruentry .. "сь" .. runotes, trentry and trentry .. "sʹ" .. trnotes}
			-- if a past_m form doesn't contain a stress, add a stressed
			-- particle "ся́" if called for
			elseif reflex_stress and com.is_unstressed(ruentry) and rfind(key, "^past_m") then
				forms[key] = {ruentry .. "ся́" .. runotes, trentry and trentry .. "sja" .. AC .. trnotes}
			else
				forms[key] = {ruentry .. "ся" .. runotes, trentry and trentry .. "sja" .. trnotes}
			end
		end
	end

	-- This form does not exist for reflexive verbs.
	forms["past_adv_part_short"] = ""
end

local function setup_pres_futr(forms, perf)
	local inf, inf_tr = extract_russian_tr(forms["infinitive"])

	-- Copy the main form FROMFORM to the main form TOFORM, and copy all
	-- associated alternative forms.
	local function copy_form(fromform, toform)
		local fromforms = main_to_all_verb_forms[fromform]
		local toforms = main_to_all_verb_forms[toform]
		local numforms = #fromforms
		assert(#toforms == numforms)
		for i=1,numforms do
			forms[toforms[i]] = forms[fromforms[i]]
		end
	end

	-- Copy pres_futr_* to pres_* (imperfective) or futr_* (perfective).
	if perf then
		copy_form("pres_futr_1sg", "futr_1sg")
		copy_form("pres_futr_2sg", "futr_2sg")
		copy_form("pres_futr_3sg", "futr_3sg")
		copy_form("pres_futr_1pl", "futr_1pl")
		copy_form("pres_futr_2pl", "futr_2pl")
		copy_form("pres_futr_3pl", "futr_3pl")
	else
		copy_form("pres_futr_1sg", "pres_1sg")
		copy_form("pres_futr_2sg", "pres_2sg")
		copy_form("pres_futr_3sg", "pres_3sg")
		copy_form("pres_futr_1pl", "pres_1pl")
		copy_form("pres_futr_2pl", "pres_2pl")
		copy_form("pres_futr_3pl", "pres_3pl")
	end

	local function insert_future(inf, inf_tr)
		forms["futr_1sg"] = {"бу́ду" .. inf, inf_tr and "búdu" .. inf_tr}
		forms["futr_2sg"] = {"бу́дешь" .. inf, inf_tr and "búdešʹ" .. inf_tr}
		forms["futr_3sg"] = {"бу́дет" .. inf, inf_tr and "búdet" .. inf_tr}
		forms["futr_1pl"] = {"бу́дем" .. inf, inf_tr and "búdem" .. inf_tr}
		forms["futr_2pl"] = {"бу́дете" .. inf, inf_tr and "búdete" .. inf_tr}
		forms["futr_3pl"] = {"бу́дут" .. inf, inf_tr and "búdut" .. inf_tr}
	end

	if not perf then
		insert_future(" " .. inf, inf_tr and " " .. inf_tr)
	end

	-- only for "бы́ть" the future forms are бу́ду, бу́дешь, etc.
	if inf == "бы́ть" then
		insert_future("", nil)
	end
end

parse_and_stress_override = function(form, val)
	if rfind(form, "^pres_futr") then
		error("Overrides of pres_futr* are illegal")
	end
	local allow_unaccented
	val, allow_unaccented = rsubb(val, "^%*", "")
	local ru, tr = nom.split_russian_tr(val)
	-- past_m can be unaccented in connection with reflex_stress=ся́
	if not allow_unaccented and not rfind(form, "^past_m") then
		if tr and com.is_unstressed(ru) ~= com.is_unstressed(tr) then
			error("Override " .. form .. "=" .. ru .. " and translit " .. tr .. " must have same accent pattern")
		end
		if com.is_monosyllabic(ru) then
			ru, tr = com.make_ending_stressed(ru, tr)
		elseif com.needs_accents(ru) then
			error("Override " .. form .. "=" .. ru .. " requires an accent")
		end
	end
	return {ru, tr}
end

-- Set up pres_* or futr_*; handle *sym/*tail/*tailall notes and overrides.
handle_forms_and_overrides = function(args, forms, perf)
	setup_pres_futr(forms, perf)

	local function append_value(forms, prop, value)
		if forms[prop] and forms[prop] ~= "" and forms[prop] ~= "-" then
			value = nom.split_russian_tr(value, "dopair")
			local curval = forms[prop]
			if type(curval) == "string" then
				curval = {curval}
			end
			forms[prop] = nom.concat_paired_russian_tr(curval, value)
		end
	end

	local function append_note_all(forms, proplist, value)
		for _, prop in ipairs(proplist) do
			append_value(forms, prop, value)
		end
	end

	local function append_note_last(forms, proplist, value, gt_one)
		local numprops = 0
		local lastprop
		-- Find the last property in the series with a value
		for _, prop in ipairs(proplist) do
			if forms[prop] and forms[prop] ~= "" and forms[prop] ~= "-" then
				numprops = numprops + 1
				lastprop = prop
			end
		end
		if numprops > (gt_one and 1 or 0) then
			append_value(forms, lastprop, value)
		end
	end

	for _, proplist in ipairs(all_verb_forms) do
		local vallist = {}
		-- Handle PROP_sym, which applies to all overridable properties, including
		-- alternative forms, and applies to exactly that property.
		for _, prop in ipairs(proplist) do
			if args[prop .. "_sym"] then
				append_value(forms, prop, args[prop .. "_sym"])
			end
		end
		local propname = proplist[1]
		-- Handle PROP_tail, which applies to a series of properties (e.g. past_m,
		-- past_m2, ...) and appends to the last one.
		if args[propname .. "_tail"] then
			append_note_last(forms, proplist, args[propname .. "_tail"])
		end
		-- Handle PROP_tailall, which applies to a series of properties and
		-- appends to all.
		if args[propname .. "_tailall"] then
			append_note_all(forms, proplist, args[propname .. "_tailall"])
		end
	end

	if args["pasttail"] then
		for _, prop in ipairs(past_verb_forms) do
			append_note_last(forms, main_to_all_verb_forms[prop], args["pasttail"], ">1")
		end
	end
	if args["pasttailall"] then
		for _, prop in ipairs(past_verb_forms) do
			append_note_all(forms, main_to_all_verb_forms[prop], args["pasttailall"])
		end
	end
	if args["prestail"] then
		for _, prop in ipairs(pres_verb_forms) do
			append_note_last(forms, main_to_all_verb_forms[prop], args["prestail"], ">1")
		end
	end
	if args["prestailall"] then
		for _, prop in ipairs(pres_verb_forms) do
			append_note_all(forms, main_to_all_verb_forms[prop], args["prestailall"])
		end
	end
	if args["futrtail"] then
		for _, prop in ipairs(futr_verb_forms) do
			append_note_last(forms, main_to_all_verb_forms[prop], args["futrtail"], ">1")
		end
	end
	if args["futrtailall"] then
		for _, prop in ipairs(futr_verb_forms) do
			append_note_all(forms, main_to_all_verb_forms[prop], args["futrtailall"])
		end
	end
	if args["imprtail"] then
		for _, prop in ipairs(impr_verb_forms) do
			append_note_last(forms, main_to_all_verb_forms[prop], args["imprtail"], ">1")
		end
	end
	if args["imprtailall"] then
		for _, prop in ipairs(impr_verb_forms) do
			append_note_all(forms, main_to_all_verb_forms[prop], args["imprtailall"])
		end
	end

	--handle overrides (formerly we only had past_pasv_part as a
	--general override, plus scattered main-form overrides in particular
	--conjugation classes)
	for _, all_forms in pairs(main_to_all_verb_forms) do
		local i = 0
		for _, form in ipairs(all_forms) do
			i = i + 1
			if args[form] then
				forms[form] = parse_and_stress_override(form, args[form])
			elseif i == 1 then
				forms[form] = forms[form] or ""
			end
		end
	end
end

-- Finish generating the forms, clearing out some forms when impersonal/intr,
-- selecting present or future forms from pres_futr_*, etc.
finish_generating_forms = function(forms, data)
	-- Set the main form FORM to the empty string, and corresponding alt forms
	-- to nil.
	local function clear_form(form)
		local i = 0
		for _, altform in ipairs(main_to_all_verb_forms[form]) do
			i = i + 1
			if i == 1 then
				forms[altform] = ""
			else
				forms[altform] = nil
			end
		end
	end

	-- Intransitive and reflexive verbs have no passive participles.
	if data.intr or data.refl then
		clear_form("pres_pasv_part")
		clear_form("past_pasv_part")
	end

	if data.impers then
		clear_form("pres_1sg")
		clear_form("pres_2sg")
		clear_form("pres_1pl")
		clear_form("pres_2pl")
		clear_form("pres_3pl")
		clear_form("futr_1sg")
		clear_form("futr_2sg")
		clear_form("futr_1pl")
		clear_form("futr_2pl")
		clear_form("futr_3pl")
		clear_form("past_m")
		clear_form("past_f")
		clear_form("past_pl")
		clear_form("pres_actv_part")
		clear_form("past_actv_part")
		clear_form("pres_adv_part")
		clear_form("past_adv_part")
		clear_form("past_adv_part_short")
		clear_form("impr_sg")
		clear_form("impr_pl")
	end

	-- Perfective and iterative verbs have no present forms, as well as
	-- verbs marked nopres=1.
	if data.perf or data.iter or data.nopres then
		clear_form("pres_actv_part")
		clear_form("pres_pasv_part")
		clear_form("pres_adv_part")
		clear_form("pres_1sg")
		clear_form("pres_2sg")
		clear_form("pres_3sg")
		clear_form("pres_1pl")
		clear_form("pres_2pl")
		clear_form("pres_3pl")
	end
	-- Some verbs (e.g. грясти́, густи́) have no past
	if data.nopast then
		clear_form("past_m")
		clear_form("past_f")
		clear_form("past_n")
		clear_form("past_pl")
		clear_form("past_m_short")
		clear_form("past_f_short")
		clear_form("past_n_short")
		clear_form("past_pl_short")
		clear_form("past_actv_part")
		clear_form("past_pasv_part")
		clear_form("past_adv_part")
		clear_form("past_adv_part_short")
	end
	-- Iterative verbs and verbs marked noimpr=1 have no imperative forms.
	if data.iter or data.noimpr then
		clear_form("impr_sg")
		clear_form("impr_pl")
	end
	-- Iterative verbs and verbs marked nofutr=1 have no future forms.
	if data.iter or data.nofutr then
		clear_form("futr_1sg")
		clear_form("futr_2sg")
		clear_form("futr_3sg")
		clear_form("futr_1pl")
		clear_form("futr_2pl")
		clear_form("futr_3pl")
	end
end

-- Make the table
make_table = function(forms, title, perf, intr, impers, notes, internal_notes)
	local inf, inf_tr = extract_russian_tr(forms["infinitive"])

	local title = "Conjugation of <span lang=\"ru\" class=\"Cyrl\">''" .. inf .. "''</span>" .. (title and " (" .. title .. ")" or "")

	local function add_links(ru, rusuf, runotes, tr, trnotes)
		return "<span lang=\"ru\" class=\"Cyrl\">[[" .. com.remove_accents(ru) .. "#Russian|" .. ru .. "]]" .. rusuf .. runotes .. "</span><br/><span style=\"color: #888\">" .. tr .. trnotes .. "</span>"
	end

	-- Add transliterations to all forms
	for key, form in pairs(forms) do
		local ru, tr = extract_russian_tr(form, "translit")
		-- check for empty strings, dashes and nil's
		if ru ~= "" and ru and ru ~= "-" then
			local ruentry, runotes = m_table_tools.get_notes(ru)
			local trentry, trnotes = m_table_tools.get_notes(tr)
			if rfind(key, "^futr") then
				-- Add link to first word (form of 'to be')
				tobe, inf = rmatch(ruentry, "^([^ ]*) ([^ ]*)$")
				if tobe then
					forms[key] = add_links(tobe, " " .. inf, runotes, trentry, trnotes)
				else
					forms[key] = add_links(ruentry, "", runotes, trentry, trnotes)
				end
			else
				forms[key] = add_links(ruentry, "", runotes, trentry, trnotes)
			end
		else
			forms[key] = "&mdash;"
		end
	end

	local disp = {}
	for dispform, sourceforms in pairs(disp_verb_form_map) do
		local entry = {}
		for _, form in ipairs(sourceforms) do
			if forms[form] and forms[form] ~= "&mdash;" then
				table.insert(entry, forms[form])
			end
		end
		disp[dispform] = table.concat(entry, ",<br/>")
		if disp[dispform] == "" then
			disp[dispform] = "&mdash;"
		end
	end

	local all_notes = {}
	for _, note in ipairs(internal_notes) do
		local symbol, entry = m_table_tools.get_initial_notes(note)
		table.insert(all_notes, symbol .. entry)
	end
	for _, note in ipairs(notes) do
		local symbol, entry = m_table_tools.get_initial_notes(note)
		table.insert(all_notes, symbol .. entry)
	end

	local notes_text
	if #all_notes > 0 then
		notes_text = "\n|+ " .. table.concat(all_notes, "\n|+ ") .. "\n"
	else
		notes_text = ""
	end

	return [=[<div class="NavFrame" style="width:49.6em;">
<div class="NavHead" style="text-align:left; background:#e0e0ff;">]=] .. title .. [=[</div>
<div class="NavContent">
{| class="inflection inflection-ru inflection-verb inflection-table"
|+ Note: for declension of participles, see their entries. Adverbial participles are indeclinable.
]=] .. notes_text .. [=[
|- class="rowgroup"
! colspan="3" | ]=] .. (perf and [=[[[совершенный вид|perfective aspect]]]=] or [=[[[несовершенный вид|imperfective aspect]]]=]) .. [=[

|-
! [[неопределённая форма|infinitive]]
| colspan="2" | ]=] .. disp.infinitive .. [=[

|- class="rowgroup"
! style="width:15em" | [[причастие|participles]]
! [[настоящее время|present tense]]
! [[прошедшее время|past tense]]
|-
! [[действительный залог|active]]
| ]=] .. disp.pres_actv_part .. [=[ || ]=] .. disp.past_actv_part .. [=[

|-
! [[страдательный залог|passive]]
| ]=] .. disp.pres_pasv_part .. [=[ || ]=] .. disp.past_pasv_part .. [=[

|-
! [[деепричастие|adverbial]]
| ]=] .. disp.pres_adv_part .. [=[ || ]=] .. disp.past_adv_part .. [=[

|- class="rowgroup"
!
! [[настоящее время|present tense]]
! [[будущее время|future tense]]
|-
! [[первое лицо|1st]] [[единственное число|singular]] (<span lang="ru" class="Cyrl">я</span>)
| ]=] .. disp.pres_1sg .. [=[ || ]=] .. disp.futr_1sg .. [=[

|-
! [[второе лицо|2nd]] [[единственное число|singular]] (<span lang="ru" class="Cyrl">ты</span>)
| ]=] .. disp.pres_2sg .. [=[ || ]=] .. disp.futr_2sg .. [=[

|-
! [[третье лицо|3rd]] [[единственное число|singular]] (<span lang="ru" class="Cyrl">он/она́/оно́</span>)
| ]=] .. disp.pres_3sg .. [=[ || ]=] .. disp.futr_3sg .. [=[

|-
! [[первое лицо|1st]] [[множественное число|plural]] (<span lang="ru" class="Cyrl">мы</span>)
| ]=] .. disp.pres_1pl .. [=[ || ]=] .. disp.futr_1pl .. [=[

|-
! [[второе лицо|2nd]] [[множественное число|plural]] (<span lang="ru" class="Cyrl">вы</span>)
| ]=] .. disp.pres_2pl .. [=[ || ]=] .. disp.futr_2pl .. [=[

|-
! [[третье лицо|3rd]] [[множественное число|plural]] (<span lang="ru" class="Cyrl">они́</span>)
| ]=] .. disp.pres_3pl .. [=[ || ]=] .. disp.futr_3pl .. [=[

|- class="rowgroup"
! [[повелительное наклонение|imperative]]
! [[единственное число|singular]]
! [[множественное число|plural]]
|-
!
| ]=] .. disp.impr_sg .. [=[ || ]=] .. disp.impr_pl .. [=[

|- class="rowgroup"
! [[прошедшее время|past tense]]
! [[единственное число|singular]]
! [[множественное число|plural]]<br/>(<span lang="ru" class="Cyrl">мы/вы/они́</span>)
|-
! [[мужской род|masculine]] (<span lang="ru" class="Cyrl">я/ты/он</span>)
| ]=] .. disp.past_m .. [=[ || rowspan="3" | ]=] .. disp.past_pl .. [=[

|-
! [[женский род|feminine]] (<span lang="ru" class="Cyrl">я/ты/она́</span>)
| ]=] .. disp.past_f .. [=[

|-
! style="background-color:#ffffe0; text-align:left;" | [[средний род|neuter]] (<span lang="ru" class="Cyrl">оно́</span>)
| ]=] .. disp.past_n .. [=[

|}
</div>
</div>]=]
end

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
