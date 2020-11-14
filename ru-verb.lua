--[=[
	This module contains functions for creating inflection tables for Russian
	verbs.

	Author: Benwing, rewritten from early version by Atitarev, earliest version by CodeCat

	NOTE: This module is partly converted to support manual translit, in the
	form CYRILLIC//LATIN (i.e. with a // separating the Cyrillic and Latin
	parts). All the general infrastructure supports manual translit; the
	only thing that doesn't is some of the specific verb conjugation functions.
	In particular, all of the class 1, 2, 3 and 4 conjugation functions support
	manual translit, and the rest don't. To convert another, follow the
	model of one of the already-converted functions.

	Note that an individual form (an entry in the 'forms' table) can be
	either a string (no special manual translit; generally this originates
	from the portion of the code that doesn't support manual translit), or
	a one-element list {CYRILLIC} (no special manual translit), or a
	two-element list {CYRILLIC, LATIN} with manual translit specified.
	The code is careful only to generate manual translit when it's needed,
	to avoid penalizing the majority of cases where manual transit isn't
	needed.
]=]

local m_utilities = require("Module:utilities")
local ut = require("Module:utils")
local m_links = require("Module:links")
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
local DIA = u(0x0308) -- diaeresis =  ̈
local PSEUDOCONS = u(0xFFF2) -- pseudoconsonant placeholder, matching ru-common
local IRREG = "△"

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

-- Fancy version of ine() (if-not-empty). Converts empty string to nil,
-- but also strips leading/trailing space and then single or double quotes,
-- to allow for embedded spaces.
local function ine(arg)
	if not arg then return nil end
	arg = rsub(arg, "^%s*(.-)%s*$", "%1")
	if arg == "" then return nil end
	local inside_quotes = rmatch(arg, '^"(.*)"$')
	if inside_quotes then
		return inside_quotes
	end
	inside_quotes = rmatch(arg, "^'(.*)'$")
	if inside_quotes then
		return inside_quotes
	end
	return arg
end

local function is_vowel_stem(stem)
	return rfind(stem, "[" .. com.vowel .. AC .. DIA .. "]$")
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

-- For a given form in a conjugation table, we allow either strings or
-- two-element lists {RUSSIAN, TRANSLIT}, where TRANSLIT can be nil
-- (equivalent to a one-element list). When comparing them, we have to take
-- this into account.
local function forms_equal(form1, form2)
	if type(form1) ~= "table" then
		form1 = {form1}
	end
	if type(form2) ~= "table" then
		form2 = {form2}
	end
	return ut.equals(form1, form2)
end

local function contains_form(forms, form)
	for _, f in ipairs(forms) do
		if forms_equal(f, form) then
			return true
		end
	end
	return false
end

-- FIXME: Move to utils
-- Append to the end of a chain of parameters, FIRST then PREF2, PREF3, ...,
-- if the value isn't already present.
local function append_to_arg_chain(args, first, pref, newval)
	local nextarg = first
	local i = 2

	if newval == "" then
		error("Internal error: attempt to insert blank value into arg chain")
	end

	while true do
		if not args[nextarg] then break end
		if forms_equal(args[nextarg], newval) then
			return nil
		end
		nextarg = pref .. i
		i = i + 1
	end
	args[nextarg] = newval
	return nextarg
end

local function get_true_arg(arg, not_off_by_1)
	-- We normally move all params down by one because the first param is the
	-- verb type; so reflect this correctly if the arg is numeric and
	-- not_off_by_1 isn't given
	return (not_off_by_1 or type(arg) ~= "number") and arg or arg + 1
end

local function getarg(args, arg, default, paramdesc, not_off_by_1)
	paramdesc = paramdesc or "Parameter " .. get_true_arg(arg, not_off_by_1)
	default = default or "-"
	--PAGENAME = mw.title.getCurrentTitle().text
	local NAMESPACE = mw.title.getCurrentTitle().nsText
	return args[arg] or (NAMESPACE == "Template" and default) or error(paramdesc .. " has not been provided")
end

local function check_stressed_arg(val, arg)
	-- don't consider suffixes
	if not rfind(val, "^%-") and not com.is_nonsyllabic(val) and not com.is_stressed(val) then
		error("Argument value " .. val .. " (parameter " .. get_true_arg(arg) .. ") must be stressed")
	end
	return val
end

local function get_stressed_arg(args, arg, default, paramdesc)
	local retval = getarg(args, arg, default, paramdesc)
	check_stressed_arg(retval, arg)
	return retval
end

local function get_opt_stressed_arg(args, arg)
	return args[arg] and get_stressed_arg(args, arg) or nil
end

local function check_unstressed_arg(val, arg)
	if com.is_stressed(val) then
		error("Argument value " .. val .. " (parameter " .. get_true_arg(arg) .. ") should not be stressed")
	end
	return val
end

local function get_unstressed_arg(args, arg, default, paramdesc)
	local retval = getarg(args, arg, default, paramdesc)
	check_unstressed_arg(retval, arg)
	return retval
end

local function get_opt_unstressed_arg(args, arg)
	return args[arg] and get_unstressed_arg(args, arg) or nil
end

local function no_stray_args(args, maxarg)
	for i=(maxarg + 1), 20 do
		if args[i] then
			error("Value for argument " .. get_true_arg(i) .. " not allowed ("
				.. args[i] .. " supplied)")
		end
	end
end

-- Extract a form spec (either a single string or a two-element table {RU, TR}
-- into the component Russian and transliterated components. Normally, if
-- an explicit manual translit wasn't given, the resulting translit will be
-- nil; but if ALWAYS_TRANSLIT is given, it will be auto-transliterated from
-- the Russian as needed.
local function extract_russian_tr(form, always_translit)
	local ru, tr
	if type(form) == "table" then
		ru, tr = form[1], form[2]
	else
		ru = form
	end
	if not tr and always_translit then
		tr = ru and com.translit(ru)
	end
	return ru, tr
end

local function strip_arg_status_prefix(arg)
	if not arg then
		return arg, ""
	end
	local subbed
	arg, subbed = rsubb(arg, "^awkward%-", "")
	if subbed then
		return arg, "awkward-"
	end
	arg, subbed = rsubb(arg, "^none%-", "")
	if subbed then
		return arg, "none-"
	end
	return arg, ""
end

local function track(page)
	m_debug.track("ru-verb/" .. page)
	return true
end

-- Forward functions

local present_e_a
local present_e_b
local present_e_c
local present_je
local present_i
local make_reflexive
local make_pre_reform
local parse_and_stress_override
local handle_forms_and_overrides
local finish_generating_forms
local make_table

local all_verb_types = {
	"pf", "pf-intr", "pf-refl",
	"pf-impers", "pf-intr-impers", "pf-refl-impers",
	"impf", "impf-intr", "impf-refl",
	"impf-impers", "impf-intr-impers", "impf-refl-impers"}

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

-- List of all main verb forms. Short forms (those ending in "_short")
-- must be listed after the corresponding non-short forms.
local all_main_verb_forms = {
	-- present tense
	"pres_1sg", "pres_2sg", "pres_3sg", "pres_1pl", "pres_2pl", "pres_3pl",
	-- future tense
	"futr_1sg", "futr_2sg", "futr_3sg", "futr_1pl", "futr_2pl", "futr_3pl",
	-- present-future tense. The conjugation functions generate the
	-- "present-future" tense instead of either the present or future tense,
	-- since the same forms are used in the present imperfect and future
	-- perfect. These forms are later copied into the present or future in
	-- finish_generating_forms().
	"pres_futr_1sg", "pres_futr_2sg", "pres_futr_3sg", "pres_futr_1pl", "pres_futr_2pl", "pres_futr_3pl",
	-- imperative
	"impr_sg", "impr_pl",
	-- past
	"past_m", "past_f", "past_n", "past_pl",
	"past_m_short", "past_f_short", "past_n_short", "past_pl_short",

	-- active participles
	"pres_actv_part", "past_actv_part",
	-- passive participles
	"pres_pasv_part", "past_pasv_part",
	-- adverbial participles
	"pres_adv_part", "past_adv_part", "past_adv_part_short",
	-- infinitive
	"infinitive"
}

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
--
-- FIXME!!! We should fix things so we no longer need to compute this table.
local all_verb_forms = {}

-- Compile all_verb_forms
for _, mainform in ipairs(all_main_verb_forms) do
	local entry = {}
	table.insert(entry, mainform)
	for i=2,9 do
		table.insert(entry, mainform .. i)
	end
	table.insert(all_verb_forms, entry)
end

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
-- List of the main verb forms for participles.
local part_verb_forms = {"pres_actv_part", "past_actv_part",
	"pres_pasv_part", "past_pasv_part",
	"pres_adv_part", "past_adv_part", "past_adv_part_short"}
-- List of the main verb forms for present participles.
local pres_part_verb_forms = {"pres_actv_part", "pres_pasv_part",
	"pres_adv_part"}
-- List of the main verb forms for past participles.
local past_part_verb_forms = {"past_actv_part", "past_pasv_part",
	"past_adv_part", "past_adv_part_short"}

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

-- Clone parent's args while also assigning nil to empty strings and splitting
-- arg sets (numeric args separated by "or"), assigning named args to
-- all all sets. Handle aliases in the process. Extract conjugation type
-- from the first arg of the arg set (for the initial arg set, this will be
-- arg 2 because arg 1 is the verb type), assigning to '.conj_type' of the
-- arg set. Return arg sets.
local function split_args_handle_aliases(frame)
	local args = frame:getParent().args
	local arg_sets = {}
	local arg_set = {}
	-- Verb type, e.g. impf, pf, impf-intr, pf-intr, impf-refl, pf-refl, etc.
	-- Default to impf on the template page so that there is no script error.
	local verb_type = getarg(args, 1, "impf", "Verb type (first parameter)")
	local offset = 1
	-- Find maximum-numbered arg, allowing for holes.
	local max_arg = 1 -- needs to be 1 not 0 so template pages display ok
	for pname, param in pairs(args) do
		if type(pname) == "number" and pname > max_arg then
			max_arg = pname
		end
	end

	-- Now gather the numbered arguments.
	for i=2,(max_arg + 1) do
		local end_arg_set = false
		if i == max_arg + 1 or args[i] == "or" then
			end_arg_set = true
		end

		if end_arg_set then
			table.insert(arg_sets, arg_set)
			arg_set = {}
			offset = i
		else
			arg_set[i - offset] = ine(args[i])
		end
	end

	-- Insert named arguments into all arg sets, mapping aliases appropriately.
	for pname, param in pairs(args) do
		if type(pname) == "string" then
			local argval = ine(param)
			local mainprop, num = rmatch(pname, "^([a-z_]+)([0-9]*)$")
			for i=1,#arg_sets do
				if not mainprop then
					arg_sets[i][pname] = argval
				else
					mainprop = prop_aliases[mainprop] or mainprop
					arg_sets[i][mainprop .. num] = argval
				end
			end
		end
	end

	-- If we're conjugating a suffix, insert a pseudoconsonant at the beginning
	-- of all forms, so they get conjugated as if ending in a consonant.
	-- We remove the pseudoconsonant later.
	for i=1,#arg_sets do
		asif_prefix = (arg_sets[i]["asif_prefix"] or
			arg_sets[i][2] and rfind(arg_sets[i][2], "^%-") and PSEUDOCONS)
		if asif_prefix then
			for k, v in pairs(arg_sets[i]) do
				arg_sets[i][k] = rsub(v, "^%-", "-" .. asif_prefix)
			end
		end
	end

	-- Frob conjugation type.
	for i=1,#arg_sets do
		local arg1 = arg_sets[i][1]
		local conj_type
		if arg1 then
			local orig_arg1 = arg1
			-- This complex spec matches matches 3°a, 3oa, 4a1a, 6c1a,
			-- 1a6a, 6a1as13, 6a1as14, 11*b, etc.
			conj_type = rmatch(arg1, "^([0-9]+[*°o0-9abc]*[abc]s?1?[34]?)")
			arg1 = rsub(arg1, "^[0-9]+[*°o0-9abc]*[abc]s?1?[34]?", "")
			if not conj_type then
				if rfind(arg1, "^irreg") then
					conj_type = "irreg"
					arg1 = rsub(arg1, "^irreg", "")
				end
				if not conj_type then
					-- Check for Cyrillic, a common mistake (esp. Cyrillic а)
					if rfind(orig_arg1, "[абцдеѣфгчийклмнопярстувшхызёюжэщьъ]") then
						error("Unrecognized conjugation type (WARNING, has Cyrillic in it): " .. orig_arg1)
					else
						error("Unrecognized conjugation type: " .. orig_arg1)
					end
				end
			end
			-- The * variant is conventionally written e.g. 11*b; if found in
			-- the conj_type, move it to the beginning of the remainder
			if rfind(conj_type, "%*") then
				conj_type = rsub(conj_type, "%*", "")
				arg1 = "*" .. arg1
			end
			arg_sets[i][1] = arg1
		else
			local NAMESPACE = mw.title.getCurrentTitle().nsText
			if NAMESPACE == "Template" and i == 1 then
				conj_type = "1a"
			else
				error("Must specify argument 2 (conjugation type)")
			end
		end
		arg_sets[i]["conj_type"] = conj_type
	end
	return arg_sets, verb_type
end

function export.do_generate_forms(arg_sets, verb_type, old)
	local set1 = arg_sets[1]
	local notes = get_arg_chain(set1, "notes", "notes")

	local forms = {}
	local categories = {}

	if not ut.contains(all_verb_types, verb_type) then
		error("Invalid verb type " .. verb_type)
	end

	local data = {}
	data.verb_type = verb_type

	--impersonal
	data.impers = rfind(verb_type, "impers")
	data.intr = rfind(verb_type, "intr")
	data.perf = rfind(verb_type, "^pf")
	data.iter = set1["iter"]
	data.nopres = set1["nopres"]
	data.nopast = set1["nopast"]
	data.nofutr = set1["nofutr"]
	data.noimpr = set1["noimpr"]
	if data.iter and data.perf then
		error("Iterative verbs must be imperfective")
	end
	data.old = old

	data.has_ppp = set1["has_ppp"]
	data.has_prpp = set1["has_prpp"]
	data.ppp_override = false
	data.prpp_override = false
	for _, form in ipairs(main_to_all_verb_forms["past_pasv_part"]) do
		if set1[form] then
			data.ppp_override = true
			break
		end
	end
	data.main_ppp_override = not not set1["past_pasv_part"]
	for _, form in ipairs(main_to_all_verb_forms["pres_pasv_part"]) do
		if set1[form] then
			data.prpp_override = true
			break
		end
	end

	data.internal_notes = {}
	local titles = {}
	for i=1,#arg_sets do
		local args = arg_sets[i]
		local conj_type = args.conj_type
		-- Support e.g. 3oa in place of 3°a
		conj_type = rsub(conj_type, "o", "°")
		track("conj-" .. conj_type) -- FIXME, convert to regular category
		track("conj-" .. conj_type .. "/" .. verb_type) -- FIXME, convert to regular category
		data.conj_type = conj_type
		data.cat_conj_types = {conj_type}
		if conj_type == "irreg" then
			data.title = "irregular"
		else
			data.title = conj_type
		end
		if not conjugations[conj_type] then
			error("Unknown conjugation type '" .. conj_type .. "'")
		end

		if args[2] then
			local inf, tr = nom.split_russian_tr(args[2])
			if rfind(inf, "[тч]ься$") then
				inf = rsub(inf, "ся$", "")
				tr = nom.strip_tr_ending(tr, "ся")
				data.refl = true
			elseif rfind(inf, "ти́?сь$") then
				-- 7a (вы́вестись), 7b (вести́сь) or derivative of -йти́ (разойти́сь)
				inf = rsub(inf, "сь$", "")
				tr = nom.strip_tr_ending(tr, "сь")
				data.refl = true
			elseif rfind(inf, "[тч]ь$") then
				-- Allow monosyllabic infinitives to be specified without stress
				if com.is_monosyllabic(inf) and not rfind(inf, "^%-") then
					inf, tr = com.make_ending_stressed(inf, tr)
				end
			end
			if tr then
				args[2] = inf .. "//" .. tr
			else
				args[2] = inf
			end
		end

		if data.refl and data.intr then
			error("Can't specify -intr with reflexive verbs")
		end
		if data.has_ppp or data.has_prpp then
			if data.refl then
				error("Can't specify has_ppp=y or has_prpp=y with reflexive verbs")
			end
			if not data.intr then
				error("Can only specify has_ppp=y or has_prpp=y with intransitive verbs")
			end
		end
		data.shouldnt_have_ppp = data.refl or not data.has_ppp and data.intr
		data.shouldnt_have_prpp = data.refl or not data.has_prpp and data.intr
		if data.ppp_override and data.shouldnt_have_ppp then
			error("Shouldn't specify past passive participle with reflexive or intransitive verbs, if it's needed use has_ppp=y")
		elseif data.perf and not data.shouldnt_have_ppp and not data.ppp_override then
			-- possible omissions
			track("perfective-no-ppp")
		end
		if data.prpp_override and data.shouldnt_have_prpp then
			error("Shouldn't specify present passive participle with reflexive or intransitive verbs, if it's needed use has_prpp=y")
		end

		-- Call conjugation function. It will return a table of forms
		-- as if it's the first arg set. If it is in fact the first
		-- arg set, we just use the table directly (we may destructively
		-- modify it if there are later arg sets, but this is OK because
		-- no one else but us uses the table). Otherwise we need to
		-- append the values from the table to those of the previous
		-- arg sets.
		local arg_set_forms = conjugations[conj_type](args, data)
		if i == 1 then
			forms = arg_set_forms
		else
			for _, all_forms in pairs(main_to_all_verb_forms) do
				for _, form in ipairs(all_forms) do
					if arg_set_forms[form] then
						append_to_arg_chain(forms, all_forms[1], all_forms[1],
							arg_set_forms[form])
					end
				end
			end
		end
		ut.insert_if_not(titles, data.title)

		if conj_type == "irreg" then
			table.insert(categories, "Russian irregular verbs")
		end
		-- For irregular verbs, if the verb didn't set a specific cat_conj_type,
		-- it will be the same as the conj_type and be "irreg". In that case,
		-- replace it with the title, which might be a proper conjugation type
		-- like 4a or 8c/b (and remove anything starting with a slash, to
		-- account for cases like 8c/b). After doing this, the cat_conj_type
		-- might still begin with "irreg" (for sufficiently irregular verbs that
		-- they can't be assigned to any of the normal classes), in which case
		-- we don't create a class for the verb beyond "Russian irregular verbs"
		-- (set above).
		if data.cat_conj_types[1] == "irreg" then
			data.cat_conj_types = {rsub(rsub(data.title, "/.*", ""), "⑨", "")}
		end
		for _, cat_conj_type in ipairs(data.cat_conj_types) do
			if not rmatch(cat_conj_type, "^irreg") then
				local class_num = rmatch(cat_conj_type, "^([0-9]+)")
				assert(class_num and class_num ~= "")
				table.insert(categories, "Russian class " .. class_num .. " verbs")
				table.insert(categories, "Russian class " .. cat_conj_type .. " verbs")
			end
		end
	end

	data.title = "class " .. table.concat(titles, " // ") ..
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

	handle_forms_and_overrides(set1, forms, data)

	local function remove_pseudo(str)
		toremove = set1["asif_prefix"] or PSEUDOCONS
		if str == nil then
			return str
		end
		str = rsub(str, "^%-" .. toremove, "-")
		-- also handle prefix after space, e.g. in futures
		str = rsub(str, " %-" .. toremove, " -")
		return str
	end

	-- Remove pseudoconsonant we may have inserted; if no ending, insert
	-- "(no suffix)".
	for k, v in pairs(forms) do
		if forms[k] == "-" .. PSEUDOCONS or type(forms[k] == "table") and forms[k][1] == "-" .. PSEUDOCONS then
			-- Make the translit empty.
			forms[k] = {"(no suffix)", ""}
		else
			if type(forms[k]) == "table" then
				forms[k][1] = remove_pseudo(forms[k][1])
				forms[k][2] = remove_pseudo(forms[k][2])
			else
				forms[k] = remove_pseudo(forms[k])
			end
		end
	end

	-- Catch errors in verb arguments that lead to the infinitive not matching
	-- page title, but only in the main namespace.
	local NAMESPACE = mw.title.getCurrentTitle().nsText
	if NAMESPACE == "" then
		local PAGENAME = mw.title.getCurrentTitle().text
		for _, form in ipairs(main_to_all_verb_forms["infinitive"]) do
			local inf, inf_tr = extract_russian_tr(forms[form])
			if inf then
				inf, _ = m_table_tools.separate_notes(inf) -- remove any footnote symbols (e.g. грясти́)
				local inf_noaccent = com.remove_accents(inf)
				if inf ~= "-" then
					if data.refl then
						if rfind(inf_noaccent, "и$") then
							inf_noaccent = inf_noaccent .. "сь"
							inf = inf .. "сь"
						else
							inf_noaccent = inf_noaccent .. "ся"
							inf = inf .. "ся"
						end
					end
					if inf_noaccent ~= PAGENAME then
						error("Infinitive " .. inf .. " doesn't match pagename " ..
							PAGENAME)
					end
				end
			end
		end
	end

	-- Reflexive/intransitive/transitive
	if set1["reflex_stress"] then
		track("reflex-stress")
	end
	if data.refl then
		local reflex_stress = set1["reflex_stress"] or data.default_reflex_stress -- "ся́"
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

	if data.old then
		make_pre_reform(forms)
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
	local arg_sets, verb_type = split_args_handle_aliases(frame)
	local old = frame.args["old"] or arg_sets[1]["old"]
	local forms, title, perf, intr, impers, categories, notes, internal_notes = export.do_generate_forms(arg_sets, verb_type, old)
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
	local arg_sets, verb_type = split_args_handle_aliases(frame)
	local old = frame.args["old"] or arg_sets[1]["old"]

	local arg_sets_clone
	if test_new_ru_verb_module then
		-- arg_sets may be modified by do_generate_forms()
		arg_sets_clone = mw.clone(arg_sets)
	end

	local forms, title, perf, intr, impers, categories, notes, internal_notes =
		export.do_generate_forms(arg_sets, verb_type, old)

	-- Test code to compare existing module to new one.
	if test_new_ru_verb_module then
		local m_new_ru_verb = require("Module:User:Benwing2/ru-verb")
		local newforms, newtitle, newperf, newintr, newimpers, newcategories, newnotes, newinternal_notes =
			m_new_ru_verb.do_generate_forms(arg_sets_clone, verb_type, old)
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
				if not forms_equal(val, newval) and not rfind(prop, "^pres_futr") then
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

	return make_table(forms, title, perf, intr, impers, notes, internal_notes, old) .. m_utilities.format_categories(categories, lang)
end

-- Implementation of template 'ruverbcatboiler'.
function export.catboiler(frame)
	local SUBPAGENAME = mw.title.getCurrentTitle().subpageText

	local cats = {}

	local cls, variant, pattern = rmatch(SUBPAGENAME, "^Russian class ([0-9]*)(°?)([abc]?) verbs")
	local text = nil
	if not cls then
		error("Invalid category name, should be e.g. \"Russian class 3a verbs\"")
	end
	if pattern == "" then
		table.insert(cats, "Russian verbs by class|" .. cls .. variant)
		text = "This category contains Russian class " .. cls .. " verbs."
	else
		table.insert(cats, "Russian verbs by class and accent pattern|" .. cls .. pattern)
		table.insert(cats, "Russian class " .. cls .. " verbs|" .. pattern)
		text = "This category contains Russian class " .. cls .. " verbs of " ..
			"accent pattern " .. pattern .. (
			variant == "" and "" or " and variant " .. variant) .. ". " .. (
			pattern == "a" and "With this pattern, all forms are stem-stressed."
			or pattern == "b" and "With this pattern, all forms are ending-stressed."
			or "With this pattern, the first singular present indicative and all forms " ..
			"outside of the present indicative are ending-stressed, while the remaining " ..
			"forms of the present indicative are stem-stressed.").. (
			variant == "" and "" or
			cls == "3" and " The variant code indicates that the -н of the stem " ..
			"is missing in most non-present-tense forms." or
			" The variant code indicates that the present tense is not " ..
			"[[Appendix:Glossary#iotation|iotated]]. (In most verbs of this class, " ..
			"the present tense is iotated, e.g. иска́ть with present tense " ..
			"ищу́, и́щешь, и́щет, etc.)")
	end

	return text	.. "\n" ..
		mw.getCurrentFrame():expandTemplate{title="ru-categoryTOC", args={}}
		.. m_utilities.format_categories(cats, lang, nil, nil, "force")
end

--[=[
	Functions for working with stems, paradigms, Russian/translit
]=]

-- Combine a stem with optional translit with an ending and possibly a foonote
-- symbol (which may be a tuple {RUNOTES, TRNOTES}), returning a tuple
-- {RUSSIAN, TR}.
local function combine(stem, tr, ending, note)
	if not ending or ending == "-" then
		return nil
	end
	local arg_status
	ending, arg_status = strip_arg_status_prefix(ending)
	if stem ~= "" and com.is_stressed(ending) then
		stem, tr = com.make_unstressed_once(stem, tr)
	end
	stem = arg_status .. stem
	if not note then
		return nom.concat_russian_tr(stem, tr, ending, nil, "dopair")
	else
		local runotes, trnotes = extract_russian_tr(note)
		local ruending, trending = nom.concat_russian_tr(ending, nil, runotes, trnotes)
		return nom.concat_russian_tr(stem, tr, ruending, trending, "dopair")
	end
end

-- Set an individual form PARAM in FORMS with value based on stem STEM (with
-- optional translit TR), ENDINGS (either a single string or a list of strings)
-- and NOTE (nil, a string, or a tuple {RUSSIAN, TR}). If there are multiple
-- endings listed, they will go successively into PARAM, PARAM2, etc.
-- (e.g. past_m, past_m2, etc.).
local function set_form(forms, param, stem, tr, endings, note)
	if type(endings) ~= "table" then
		endings = {endings}
	end
	local entries = {}
	for _, val in ipairs(endings) do
		ut.insert_if_not(entries, combine(stem, tr, val, note))
	end
	set_arg_chain(forms, param, param, entries)
end

-- Append to an individual form PARAM in FORMS with value based on stem STEM
-- (with optional translit TR), ENDINGS (either a single string or a list of
-- strings) and NOTE (nil, a string, or a tuple {RUSSIAN, TR}). If there are
-- multiple endings listed, they will go successively into PARAM, PARAM2, etc.
-- (e.g. past_m, past_m2, etc.), provided there are no existing forms already
-- present. Duplicate forms aren't inserted.
local function append_form(forms, param, stem, tr, endings, note)
	if type(endings) ~= "table" then
		endings = {endings}
	end
	for _, val in ipairs(endings) do
		append_to_arg_chain(forms, param, param, combine(stem, tr, val, note))
	end
end

local function append_pres_futr(forms, stem, tr,
	sg1, sg2, sg3, pl1, pl2, pl3, note)
	append_form(forms, "pres_futr_1sg", stem, tr, sg1, note)
	append_form(forms, "pres_futr_2sg", stem, tr, sg2, note)
	append_form(forms, "pres_futr_3sg", stem, tr, sg3, note)
	append_form(forms, "pres_futr_1pl", stem, tr, pl1, note)
	append_form(forms, "pres_futr_2pl", stem, tr, pl2, note)
	append_form(forms, "pres_futr_3pl", stem, tr, pl3, note)
end

local function append_participles_2stem(forms,
	pres_stem, pres_tr, past_stem, past_tr,
	pres_actv, pres_pasv, pres_adv, past_actv, past_adv, past_adv_short,
	pres_note, past_note)
	append_form(forms, "pres_actv_part", pres_stem, pres_tr, pres_actv, pres_note)
	append_form(forms, "pres_pasv_part", pres_stem, pres_tr, pres_pasv, pres_note)
	append_form(forms, "pres_adv_part", pres_stem, pres_tr, pres_adv, pres_note)
	append_form(forms, "past_actv_part", past_stem, past_tr, past_actv, past_note)
	append_form(forms, "past_adv_part", past_stem, past_tr, past_adv, past_note)
	append_form(forms, "past_adv_part_short", past_stem, past_tr, past_adv_short, past_note)
end

local function append_participles(forms, stem, tr,
	pres_actv, pres_pasv, pres_adv, past_actv, past_adv, past_adv_short, note)
	append_participles_2stem(forms, stem, tr, stem, tr,
		pres_actv, pres_pasv, pres_adv, past_actv, past_adv, past_adv_short, note, note)
end

local function set_ppp(forms, stem, tr, ending, note)
	set_form(forms, "past_pasv_part", stem, tr, ending, note)
end

local function append_ppp(forms, stem, tr, ending, note)
	append_form(forms, "past_pasv_part", stem, tr, ending, note)
end

local function append_imper(forms, stem, tr, sg, pl, note)
	append_form(forms, "impr_sg", stem, tr, sg, note)
	append_form(forms, "impr_pl", stem, tr, pl, note)
end

local function set_past(forms, stem, tr, m, f, n, pl, note)
	set_form(forms, "past_m", stem, tr, m, note)
	set_form(forms, "past_f", stem, tr, f, note)
	set_form(forms, "past_n", stem, tr, n, note)
	set_form(forms, "past_pl", stem, tr, pl, note)
end

local function append_past(forms, stem, tr, m, f, n, pl, note)
	append_form(forms, "past_m", stem, tr, m, note)
	append_form(forms, "past_f", stem, tr, f, note)
	append_form(forms, "past_n", stem, tr, n, note)
	append_form(forms, "past_pl", stem, tr, pl, note)
end

-- Prepend a possibly-stressed prefix to all forms; if prefix is stressed,
-- destress the forms before prepending. FIXME: Should support explicit
-- manual translit.
local function prepend_prefix(forms, prefix, pre_two_cons_prefix)
	pre_two_cons_prefix = pre_two_cons_prefix or prefix
	local stressed_prefix = com.is_stressed(prefix)
	for key, form in pairs(forms) do
		local ru, tr = extract_russian_tr(form)
		if tr then
			error("Explicit manual translit not yet supported")
		end
		-- check for empty string, dashes and nil's
		if ru and ru ~= "" and ru ~= "-" then
			if stressed_prefix then
				ru = com.make_unstressed(ru)
			end
			if rfind(ru, "^[" .. com.cons .. "][" .. com.cons .. "]") then
				forms[key] = pre_two_cons_prefix .. ru
			else
				forms[key] = prefix .. ru
			end
		end
	end
end

-- Apply regex substitution FROM -> TO to all forms. FIXME: Should support
-- explicit manual translit.
local function rsub_forms(forms, from, to)
	for key, form in pairs(forms) do
		local ru, tr = extract_russian_tr(form)
		if tr then
			error("Explicit manual translit not yet supported")
		end
		-- check for empty string, dashes and nil's
		if ru and ru ~= "" and ru ~= "-" then
			forms[key] = rsub(ru, from, to)
		end
	end
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

local function parse_variants(data, variants, allowed)
	-- Need to set these to nil in case of multiple arg sets
	data.imper_variant = nil
	data.var4 = nil
	data.var5 = nil
	data.var6 = nil
	data.ppp = nil
	data.var9 = nil
	data.shch = nil
	data.yo = nil
	data.o = nil
	data.zhd = nil
	data.star = nil
	variants = variants or ""
	local variant_title = ""
	if variants ~= "" then -- short-circuit the most common case
		-- Only recognize * variant for long-variant prefix at the beginning
		-- of the variant code block (where it gets moved if it's in the
		-- middle of the conjugation type, as it normally is) because a *
		-- also occurs in b*, a past stress variant code.
		if rfind(variants, "^%*") then
			-- Specify that the present/future tense has extra -о in the prefix:
			-- types 9*b (e.g. растере́ть, futr_1sg разотру́) and 11*b (e.g. изли́ть,
			-- futr_1sg изолью́). It can also occur with type 7*b (in -че́сть,
			-- e.g. счесть, сочту́; расче́сть, разочту́) and type 8*b (in -же́чь, e.g.
			-- сжечь, сожгу́) but these are always irregular and require the
			-- present tense to be specified explicitly. It can also occur
			-- with type 14*b (e.g. размя́ть, разомну́; сжать, сожну́; подожа́ть, подожму́),
			-- but for these verbs the present tense is unpredictable and
			-- must be specified explicitly.
			--
			-- This can also occur where the extra -о occurs in the infinitive
			-- and past, but not the present tense: type 5*c (in -гна́ть, e.g.
			-- согна́ть, сгоню́; разогна́ться, разгоню́сь), type 6*c (in -стла́ть, e.g.
			-- подостла́ть, подстелю́; разостла́ть, расстелю́), type 6°*c
			-- (in -зва́ть, -бра́ть, -дра́ть, e.g. подозва́ть, подзову́; разобра́ться, разберу́сь);
			-- but these are always irregular and require the present tense
			-- to be specified explicitly.
			if not ut.contains(allowed, "*") then
				error("Variant " .. var .. " not allowed for this verb class")
			end
			data.star = true
			variants = rsub(variants, "^*", "")
		end

		-- Allow brackets around both 5 and 6, e.g. [(5)(6)]
		variants = rsub(variants, "%[(%([56]%))(%([56]%))%]", "[%1][%2]")

		-- Handle all remaining variants. We do this using an rsub() function,
		-- where we pull out, parse and remove each variant in turn.
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
					error("Shouldn't specify past passive participle with reflexive or intransitive verbs, if it's needed use has_ppp=y")
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
	data.past_stress = variants == "" and "a" or rsub(variants, "/", "")
	data.title = data.title ..
		prepare_past_stress_indicator(data.past_stress) ..
		variant_title
	if data.star then
		data.title = rsub(data.title, "^([0-9]+°?)", "%1*")
	end
	-- If there's an override of past_pasv_part, generate the normal participle
	-- so we can determine whether the override is irregular. But set a flag
	-- so we erase any automatically generated past passive participles that
	-- aren't overridden. This happens for example in обнять, where there are
	-- two automatically generated past passive participles but a single
	-- ppp=о́внятый override.
	if not data.ppp and data.main_ppp_override then
		data.ppp = "+p"
		data.ppp_auto_generated = true
	end
end

local function set_past_by_stress(forms, past_stresses, prefix, prefixtr, base,
		basetr, args, data, no_pastml, note)
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
				"ла", "ло", "ли", note)
		elseif past_stress == "a(1)" then
			-- вы́дать, вы́быть, etc.; also проби́ть with the meaning
			-- "to strike (of a clock)" (which is a(1),a or similar)
			append_past(forms, stressed_prefix_ubase,
				stressed_prefix_ubasetr, pastml, "ла", "ло", "ли", note)
		elseif past_stress == "b" then
			append_past(forms, prefixbase, prefixbasetr, pastml,
				"ла́", "ло́", "ли́", note)
		elseif past_stress == "b*" then
			if not data.refl then
				error("Only reflexive verbs can take past stress variant " .. past_stress)
			end
			-- See comment in type c''. We want to see whether we actually
			-- added an argument, and if so, where.
			local argset = append_to_arg_chain(forms, "past_m", "past_m",
				combine(uprefixubase, uprefixubasetr, pastml .. (note or "")))
			if argset and not args[argset] and not data.impers then
				data.default_reflex_stress = "ся́"
			end
			append_past(forms, prefixbase, prefixbasetr, {}, "ла́", "ло́", "ли́", note)
		elseif past_stress == "c" then
			-- изда́ть, возда́ть, сдать, пересозда́ть, воссозда́ть, надда́ть, наподда́ть, etc.
			-- быть, избы́ть, сбыть
			-- клясть, закля́сть
			append_past(forms, prefixbase, prefixbasetr, pastml, "ла́", "ло", "ли", note)
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
				pastml, {}, "ло", "ли", note)
			append_past(forms, prefixbase, prefixbasetr, {}, "ла́", {}, {}, note)
		elseif past_stress == "c'" then
			-- дать
			--same with "взять"
			append_past(forms, prefixbase, prefixbasetr,
				pastml, "ла́", {"ло", "ло́"}, "ли", note)
		elseif past_stress == "c''" or past_stress == "c''-nd" or past_stress == "c''-bd" then
			if not data.refl then
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
				combine(uprefixubase, uprefixubasetr, pastml .. note_symbol .. (note or "")))
			-- Only display the internal note and set the default reflex
			-- stress if the form with the note will be displayed (i.e. not
			-- impersonal, and no override of this form). FIXME: We should
			-- have a more general mechanism to check for this.
			if not args[argset] and not data.impers then
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
				combine(uprefixubase, uprefixubasetr, pastml .. (note or "")))
			if argset and not args[argset] and not data.impers then
				data.default_reflex_stress = "ся́"
			end
			append_past(forms, prefixbase, prefixbasetr, {}, "ла́", "ло́", "ли́", note)
			append_past(forms, stressed_prefix_ubase, stressed_prefix_ubasetr,
				pastml, {}, "ло", "ли", note)
		else
			error("Unrecognized past-stress value " .. past_stress .. ", should be a, a(1), b, b*, c, c(1), c', c'', c''-nd, c''-bd, c''(1) or comma-separated list")
		end
	end
end

-- Split a verb stem into a possibly multisyllabic prefix (пере-, переиз-,
-- воссоз-, повы́-, etc.) and a single-syllable main verb (-тер-, -ли́-, -гре́-,
-- etc.). Normally the splitting is done simply by looking for alternating
-- vowel/consonant sequences, meaning that e.g. разгре́ will be split as
-- ра + згре́ and растер will be split as ра + стер. For most purposes, this
-- doesn't matter, but for the * variant it does; in that case, if it is
-- known that the main verb base always begins with a single consonant,
-- specify SINGLE_CONS_BASE and then e.g. растер will be split as рас + тер.
local function split_monosyllabic_main_verb(ru, tr, single_cons_base)
	local rusyl, trsyl = com.split_syllables(ru, tr)
	local last_ru = rusyl[#rusyl]
	local last_tr = trsyl and trsyl[#trsyl]
	table.remove(rusyl, #rusyl)
	local prefix_ru = table.concat(rusyl, "")
	local prefix_tr
	if trsyl then
		table.remove(trsyl, #trsyl)
		prefix_tr = table.concat(trsyl, "")
	end
	if single_cons_base then
		local cons_to_move, rest = rmatch(last_ru, "^([" .. com.cons .. "]+)([" .. com.cons .. "].*)$")
		if cons_to_move then
			prefix_ru = prefix_ru .. cons_to_move
			last_ru = rest
		end
		if last_tr then
			cons_to_move, rest = rmatch(last_tr, "^([" .. com.tr_cons .. "]+)([" .. com.tr_cons .. "].*)$")
			if cons_to_move then
				prefix_tr = prefix_tr .. cons_to_move
				last_tr = rest
			end
		end
	end
	return prefix_ru, prefix_tr, last_ru, last_tr
end

local function split_known_main_verb(arg, mains)
	-- Given an argument (which may be RUSSIAN//TR), split the prefix from
	-- the main verb, which should be one of the verbs in MAINS (which can be
	-- a -- single verb or a list of verbs, but in either case all verbs
	-- need to be stressed). This correctly handles stressed and unstressed
	-- prefixes.
	local stem, tr = nom.split_russian_tr(arg)
	if type(mains) ~= "table" then
		mains = {mains}
	end
	for _, main in ipairs(mains) do
		assert(com.is_stressed(main))
		if rfind(stem, main .. "$") then
			stem, tr = nom.strip_ending(stem, tr, main)
			if com.is_stressed(stem) then
				error("Two stresses in " .. arg)
			end
			return stem, tr, main, nil
		end
		main = com.make_unstressed_once(main)
		if rfind(stem, main .. "$") then
			stem, tr = nom.strip_ending(stem, tr, main)
			if com.is_unstressed(stem) then
				error("No stresses in " .. arg)
			end
			return stem, tr, main, nil
		end
	end
	if #mains == 1 then
		error("Argument " .. arg .. " doesn't end in " .. mains[1])
	else
		error("Argument " .. arg .. " doesn't end in any of " .. table.concat(mains, ","))
	end
end

local function construct_long_prefix_variant(prefix)
	if rfind(prefix, "рас$") then
		return rsub(prefix, "рас$", "разо")
	end
	if rfind(prefix, "ис$") then
		return rsub(prefix, "ис$", "изо")
	end
	if rfind(prefix, "вс$") then
		return rsub(prefix, "вс$", "взо")
	end
	return prefix .. "о"
end

local function append_imper_by_variant(forms, stem, tr, variant, verbclass, note)
	local vowel_stem = is_vowel_stem(stem)
	local stress = rmatch(verbclass, "([abc])$")
	if not stress then
		error("Unrecognized verb class '" .. verbclass .. "', should end with a, b or c")
	end
	local longend = stress == "a" and "и" or "и́"
	local shortend = vowel_stem and (com.is_unstressed(stem) and "́й" -- accent on previous vowel
		or "й") or "ь"
	local function append_short_imper()
		append_imper(forms, stem, tr, shortend, shortend .. "те", note)
	end
	local function append_long_imper()
		append_imper(forms, stem, tr, longend, longend .. "те", note)
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
		append_imper(forms, stem, tr, longend, shortend .. "те", note)
	elseif variant == "[(3)]" then
		-- long and short in singular, short in plural
		append_imper(forms, stem, tr, {longend, shortend}, shortend .. "те", note)
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
		iotated_stem, subbed = rsubb(stem, "з?д$", "жд")
		if not subbed then
			error("Variant -жд- specified but stem " .. stem .. " doesn't end in -д")
		end
		if tr then
			iotated_tr, subbed = rsubb(tr, "z?d$", "žd")
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
-- from the infinitive, iotated in class 5 -еть/-ѣть verbs. The participle
-- ending is -анный/-янный for verbs in -ать/-ять, -енный/-ённый for verbs in -еть,
-- -ѣнный/-ѣ̈нный for verbs in -ѣть, otherwise -тый.
local function set_moving_ppp(forms, data)
	if not data.ppp then
		return
	end
	-- NOTE: No need to check for multiple infinitives because no verbs have
	-- them normally, and we probably don't want to check for overrides here
	-- (e.g. it would break достичь and related verbs, which have participles
	-- based on the infinitive достигнуть).
	local infinitive, infinitivetr = extract_russian_tr(forms["infinitive"])
	local stem, ending = rmatch(infinitive, "^(.*)([аеѣоуя]́?ть)$")
	if not stem then
		error("Strange infinitive " .. infinitive .. " when trying to create participle")
	end
	local tr, endingtr
	if infinitivetr then
		if ending == "ять" or ending == "я́ть" then
			tr, endingtr = rmatch(infinitivetr, "^(.*)(ja" .. AC .. "?tʹ)$")
		else
			tr, endingtr = rmatch(infinitivetr, "^(.*)([aeěou]" .. AC .. "?tʹ)$")
		end
		if not tr then
			error("Translit " .. infinitivetr .. " doesn't match Cyrillic " ..
				infinitive)
		end
	end
	local ending_vowel = usub(ending, 1, 1)
	local ppptype = data.ppp
	if com.is_nonsyllabic(stem) then
		-- e.g. 3b гну́ть (гну́тый); but not -нуть (type 3a, as a suffix)
		ppptype = "(7)"
	end
	if ut.contains({"5a", "5b", "5c"}, data.conj_type) and
		(ending_vowel == "е" or ending_vowel == "ѣ") then
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
		if not subbed and data.old then
			stem, subbed = rsub(stem, "ѣ́", "ѣ̈")
		end
		if not subbed then
			error("No stressed е" .. (data.old and " or ѣ" or "") ..
				" in stem " .. stem ..
				" to replace with ё" .. (data.old and " or ѣ̈" or "") ..
				" when trying to create participle")
		end
		if tr then
			tr, subbed = rsub(tr, "j[eě]" .. AC, "jo" .. AC) -- Latin
			if not subbed then
				tr, subbed = rsub(tr, "[eě]" .. AC, "jo" .. AC) -- Latin
			end
			if not subbed then
				error("No stressed е in translit " .. tr .. " to replace with jo when trying to create participle")
			end
		end
	end
	if data.conj_type == "1a" and ending_vowel == "е" then
		-- 1a, only одоле́ть, преодоле́ть, verbs in -печатле́ть
		set_ppp(forms, stem, tr, "ённый")
	elseif data.conj_type == "1a" and ending_vowel == "ѣ" then
		set_ppp(forms, stem, tr, "ѣ̈нный")
	else
		local stressed_ending, unstressed_ending
		if ending_vowel == "е" then
			stressed_ending = "ённый"
			unstressed_ending = "енный"
		elseif ending_vowel == "ѣ" then
			stressed_ending = "ѣ̈нный"
			unstressed_ending = "ѣнный"
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

-- Iterate over the values of a property (e.g. past_m, past_f), handling
-- overrides properly. Call FN on each one, passing in RU, TR, NOTE.
local function iterate_over_prop(forms, args, prop, fn)
	for _, form in ipairs(main_to_all_verb_forms[prop]) do
		local ru, tr
		if args[form] then
			local orig_forms = {}
			for _, form2 in ipairs(main_to_all_verb_forms[prop]) do
				if forms[form2] then
					table.insert(orig_forms, forms[form2])
				end
			end
			local override = parse_and_stress_override(form, args[form], forms[form], orig_forms)
			ru, tr = extract_russian_tr(override)
		end
		if (not ru or ru == "" or ru == "-") and forms[form] then
			ru, tr = extract_russian_tr(forms[form])
		end
		-- skip unstressed forms (may occur in the past_m when a stressed
		-- reflexive -ся́ should occur; these occur only in запереться and
		-- опереться, where they're used to generate the past active part
		-- and past adverbial part, and end-stressed forms shouldn't be
		-- generated)
		if ru and ru ~= "" and ru ~= "-" and not com.is_unstressed(ru) then
			local ruentry, runotes = m_table_tools.separate_notes(ru)
			local trentry, trnotes
			if tr then
				trentry, trnotes = m_table_tools.separate_notes(tr)
			end
			fn(ruentry, trentry, {runotes, trnotes})
		end
	end
end

-- Set the past passive participle for those classes where it is derived
-- from the past tense masculine singular (9, 11, 12, 14, 15, 16). We need
-- to apply any relevant overrides.
local function set_ppp_from_past_m(forms, args, data)
	if not data.ppp then
		return
	end
	iterate_over_prop(forms, args, "past_m", function(ru, tr, note)
		if rfind(ru, "л$") then
			ru = rsub(ru, "л$", "")
			if tr then
				tr = rsub(tr, "l$", "")
			end
		end
		append_ppp(forms, ru, tr, "тый", note)
	end)
end

-- Set the past passive participle for class-4 verbs.
local function set_class_4_ppp(forms, data, stem, tr, vclass)
	if not data.ppp then
		return
	end
	local iotated_stem, iotated_tr = iotated_ppp(data, stem, tr)
	vclass = vclass or data.conj_type
	if vclass == "4b" then
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
	-- Extract 3sg bases. There may be more than one possible form, e.g. in
	-- обокра́сть, so support this.
	-- FIXME: We don't support checking for overrides here; doing so isn't
	-- overly hard but is a bit tricky because the overrides will be either
	-- pres_3sg or futr_3sg, depending on the aspect of the verb.
	-- FIXME: We don't support manual translit here, because neither 7 nor 8
	-- support it elsewhere.
	for _, form in ipairs(main_to_all_verb_forms["pres_futr_3sg"]) do
		local ru, tr
		if forms[form] then
			ru, tr = extract_russian_tr(forms[form])
		end
		if ru and ru ~= "" and ru ~= "-" then
			local ruentry, runotes = m_table_tools.separate_notes(ru)
			ruentry = rsub(ruentry, "[её]т$", "")
			if com.is_unstressed(ruentry) then
				ruentry = com.make_ending_stressed(ruentry)
			end
			ut.insert_if_not(sg3_bases, {ruentry, runotes})
		end
	end

	-- Here we do the same rigmarole as in set_ppp_from_past_m(), to respect
	-- any past_f overrides that might have been set. It's unlikely that
	-- there is more than one possible form but we support it.
	iterate_over_prop(forms, args, "past_f", function(ru, tr, note)
		for _, base_and_notes in ipairs(sg3_bases) do
			local base, notes = base_and_notes[1], base_and_notes[2]
			append_ppp(forms, base, nil,
				-- check if past_f is ending-stressed
				rfind(ru, AC .. "$") and "ённый" or "енный", notes)
		end
	end)
end

--[=[
	Conjugation functions
]=]

conjugations["1a"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"+p", "7", "ё"})
	local stem, tr = nom.split_russian_tr(get_stressed_arg(args, 2))
	if stem == "-" and not tr then
		-- Template space; leave it
	else
		stem, tr = nom.strip_ending(stem, tr, "ть")
	end
	no_stray_args(args, 2)

	forms["infinitive"] = combine(stem, tr, "ть")
	append_participles(forms, stem, tr, "ющий", "емый", "я", "вший", "вши", "в")
	set_moving_ppp(forms, data)
	present_je(forms, stem, tr, "a")
	append_imper(forms, stem, tr, "й", "йте")
	set_past(forms, stem, tr, "л", "ла", "ло", "ли")

	return forms
end

local function guts_of_2(args, data)
	local forms = {}

	local inf_stem, inf_tr = nom.split_russian_tr(get_stressed_arg(args, 2))
	inf_stem, inf_tr = nom.strip_ending(inf_stem, inf_tr, "ть")
	no_stray_args(args, 2)

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
		present_je(forms, pres_stem, pres_tr, "a")
	else
		append_participles_2stem(forms, pres_stem, pres_tr, inf_stem, inf_tr,
			"ю́щий", "-", "я́", "вший", "вши", "в")
		present_je(forms, pres_stem, pres_tr, "b")
	end
	set_moving_ppp(forms, data)
	append_imper(forms, pres_stem, pres_tr, "й", "йте")
	set_past(forms, inf_stem, inf_tr, "л", "ла", "ло", "ли")

	return forms
end

conjugations["2a"] = function(args, data)
	return guts_of_2(args, data)
end

conjugations["2b"] = function(args, data)
	return guts_of_2(args, data)
end

conjugations["3°a"] = function(args, data)
	local forms = {}

	-- (5), [(6)] or similar; imperative indicators
	parse_variants(data, args[1], {"5", "6", "23", "и", "+p", "7", "ё"})
	local stem, tr = nom.split_russian_tr(get_stressed_arg(args, 2))
	stem, tr = nom.strip_ending(stem, tr, "нуть")
	local vowel_stem = is_vowel_stem(stem)
	no_stray_args(args, 2)

	forms["infinitive"] = combine(stem, tr, "нуть")

	append_participles(forms, stem, tr,
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
	present_e_a(forms, stem .. "н", tr and tr .. "n")
	append_imper_by_variant(forms, stem .. "н", tr and tr .. "n", data.imper_variant, "3°a")

	forms["past_m"] = data.var5 and combine(stem, tr, "нул") or "-"
	forms["past_m_short"] = data.var5 ~= "req" and combine(stem, tr, (vowel_stem and "л" or "")) or nil
	forms["past_f_short"] = combine(stem, tr, "ла")
	forms["past_n_short"] = combine(stem, tr, "ло")
	forms["past_pl_short"] = combine(stem, tr, "ли")

	return forms
end

conjugations["3a"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"23", "и", "+p", "7", "ё"})
	local stem, tr = nom.split_russian_tr(get_stressed_arg(args, 2))
	-- make sure we can strip нуть from the stem and any translit;
	nom.strip_ending(stem, tr, "нуть")
	-- but then just strip the -уть and leave the н
	stem, tr = nom.strip_ending(stem, tr, "уть")
	no_stray_args(args, 2)

	forms["infinitive"] = combine(stem, tr, "уть")
	append_participles(forms, stem, tr,
		-- default is blank for pres passive and adverbial
		"ущий", "-", "-", "увший", "увши", "ув")
	set_moving_ppp(forms, data)
	present_e_a(forms, stem, tr)

	append_imper_by_variant(forms, stem, tr, data.imper_variant, "3a")
	set_past(forms, stem .. "ул", tr and tr .. "ul", "", "а", "о", "и")

	return forms
end

local function guts_of_3b_3c(args, data, vclass)
	local forms = {}

	parse_variants(data, args[1], {"+p", "7", "ё"})
	local stem, tr = nom.split_russian_tr(get_stressed_arg(args, 2))
	-- make sure we can strip нуть from the stem and any translit;
	nom.strip_ending(stem, tr, "ну́ть")
	-- but then just strip the -у́ть and leave the н
	stem, tr = nom.strip_ending(stem, tr, "у́ть")
	no_stray_args(args, 2)

	forms["infinitive"] = combine(stem, tr, "у́ть")

	append_participles(forms, stem, tr,
		-- default is blank for pres passive and adverbial
		"у́щий", "-", "-", "у́вший", "у́вши", "у́в")
	set_moving_ppp(forms, data)
	append_imper(forms, stem, tr, "и́", "и́те")
	set_past(forms, stem, tr, "у́л", "у́ла", "у́ло", "у́ли")
	if data.conj_type == "3b" then
		present_e_b(forms, stem, tr)
	else
		stem, tr = com.make_ending_stressed(stem, tr)
		present_e_c(forms, stem, tr)
	end

	return forms
end

conjugations["3b"] = function(args, data)
	return guts_of_3b_3c(args, data)
end

conjugations["3c"] = function(args, data)
	return guts_of_3b_3c(args, data)
end

conjugations["4a"] = function(args, data)
	local forms = {}

	-- imperative variants, also щ, used for verbs like похитить (похи́щу) (4a),
	-- защитить (защищу́) (4b), поглотить (поглощу́) (4c) with a different
	-- iotation (т -> щ, not ч)
	parse_variants(data, args[1], {"23", "и", "щ", "past", "+p", "7", "жд"})
	local stem, tr = nom.split_russian_tr(get_stressed_arg(args, 2))
	stem, tr = nom.strip_ending(stem, tr, "ить")
	no_stray_args(args, 2)

	forms["infinitive"] = combine(stem, tr, "ить")

	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	local hushing = rfind(stem, "[шщжч]$")
	append_participles(forms, stem, tr, hushing and "ащий" or "ящий",
		"awkward-имый", hushing and "а" or "я", "ивший", "ивши", "ив")
	set_class_4_ppp(forms, data, stem, tr)
	present_i(forms, stem, tr, "a", data.shch)
	append_imper_by_variant(forms, stem, tr, data.imper_variant, "4a")
	-- set prefix to "" as past stem may vary in length and no (1) variants
	set_past_by_stress(forms, data.past_stress, "", nil, stem .. "и",
		tr and tr .. "i", args, data)

	return forms
end

conjugations["4a1a"] = function(args, data)
	local forms = {}

	data.title = "4a // 1a"
	data.cat_conj_types = {"1a", "4a"}
	-- imperative variants, also щ, used for verbs like похитить (похи́щу) (4a),
	-- защитить (защищу́) (4b), поглотить (поглощу́) (4c) with a different
	-- iotation (т -> щ, not ч)
	parse_variants(data, args[1], {"23", "и", "щ", "past", "+p", "7", "жд"})
	local stem4, tr4 = nom.split_russian_tr(get_stressed_arg(args, 2))
	stem4, tr4 = nom.strip_ending(stem4, tr4, "ить")
	local hushing = rfind(stem4, "[шщжч]$")
	local stem1, tr1
	if hushing then
		stem1 = stem4 .. "а"
		tr1 = tr4 and tr4 .. "a"
	else
		stem1 = stem4 .. "я"
		tr1 = tr4 and tr4 .. "ja"
	end
	no_stray_args(args, 2)

	forms["infinitive"] = combine(stem4, tr4, "ить")

	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	append_participles(forms, stem4, tr4, hushing and "ащий" or "ящий",
		"awkward-имый", hushing and "а" or "я", "ивший", "ивши", "ив")
	append_participles(forms, stem1, tr1, "ющий", "емый", "я", {}, {}, {})
	set_class_4_ppp(forms, data, stem4, tr4)
	present_i(forms, stem4, tr4, "a", data.shch)
	present_je(forms, stem1, tr1, "a", data.shch)
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
	local stem, tr = nom.split_russian_tr(get_stressed_arg(args, 2))
	stem, tr = nom.strip_ending(stem, tr, "и́ть")
	no_stray_args(args, 2)

	forms["infinitive"] = combine(stem, tr, "и́ть")

	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	local hushing = rfind(stem, "[шщжч]$")
	append_participles(forms, stem, tr, hushing and "а́щий" or "я́щий",
		"awkward-и́мый", hushing and "а́" or "я́", "и́вший", "и́вши", "и́в")
	set_class_4_ppp(forms, data, stem, tr)
	present_i(forms, stem, tr, "b", data.shch)
	append_imper(forms, stem, tr, "и́", "и́те")
	-- set prefix to "" as past stem may vary in length and no (1) variants
	local stem_noa, tr_noa = com.make_unstressed_once(stem, tr)
	set_past_by_stress(forms, data.past_stress, "", nil, stem_noa .. "и́",
		tr_noa and tr_noa .. "i" .. AC, args, data)

	return forms
end

conjugations["4c"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"щ", "4", "past", "+p", "7", "жд"})
	local stem, tr = nom.split_russian_tr(get_stressed_arg(args, 2))
	stem, tr = nom.strip_ending(stem, tr, "и́ть")
	stem, tr = com.make_ending_stressed(stem, tr)
	no_stray_args(args, 2)

	forms["infinitive"] = combine(stem, tr, "и́ть")

	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	local hushing = rfind(stem, "[шщжч]$")
	local prap_end_stressed = hushing and "а́щий" or "я́щий"
	local prap_stem_stressed = hushing and "ащий" or "ящий"
	append_participles(forms, stem, tr, data.var4 == "req" and prap_stem_stressed
		or data.var4 == "opt" and {prap_end_stressed, prap_stem_stressed}
		or prap_end_stressed,
		"awkward-и́мый", hushing and "а́" or "я́", "и́вший", "и́вши", "и́в")
	set_class_4_ppp(forms, data, stem, tr)
	present_i(forms, stem, tr, "c", data.shch)
	append_imper(forms, stem, tr, "и́", "и́те")
	local stem_noa, tr_noa = com.make_unstressed_once(stem, tr)
	set_past_by_stress(forms, data.past_stress, "", nil, stem_noa .. "и́",
		tr_noa and tr_noa .. "i" .. AC, args, data)

	return forms
end

-- Combined class 5. But there's enough conditional code that it might make
-- more sense to separate them again.
local function guts_of_5(args, data)
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
	local inf = get_stressed_arg(args, 2)
	local past_stem = nom.strip_ending(inf, nil, "ть")
	local stem = is5b and get_opt_unstressed_arg(args, 3) or get_opt_stressed_arg(args, 3)
	local default_stem = rmatch(past_stem, "^(.*)[еѣая]́?$")
	if not default_stem then
		error("Argument " .. inf .. " doesn't end in еть, ѣть, ать or ять")
	end
	if not is5a and not is5b then
		default_stem = com.make_ending_stressed(default_stem)
	end
	stem = stem or default_stem
	local pres_note = stem ~= default_stem and IRREG

	no_stray_args(args, 3)

	forms["infinitive"] = past_stem .. "ть"

	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	local hushing = rfind(stem, "[шщжч]$")
	if is5a then
		append_participles_2stem(forms, stem, nil, past_stem, nil,
			hushing and "ащий" or "ящий", "имый", hushing and "а" or "я",
			"вший", "вши", "в", pres_note)
	elseif is5b then
		append_participles_2stem(forms, stem, nil, past_stem, nil,
			hushing and "а́щий" or "я́щий", "и́мый", hushing and "а́" or "я́",
			"вший", "вши", "в", pres_note)
	else
		-- var4 occurs with at least терпре́ть and дыша́ть
		local prap_end_stressed = hushing and "а́щий" or "я́щий"
		local prap_stem_stressed = hushing and "ащий" or "ящий"
		append_participles_2stem(forms, stem, nil, past_stem, nil,
			data.var4 == "req" and prap_stem_stressed
			or data.var4 == "opt" and {prap_end_stressed, prap_stem_stressed}
			or prap_end_stressed,
			"и́мый", hushing and "а́" or "я́", "вший", "вши", "в", pres_note)
	end
	set_moving_ppp(forms, data)
	present_i(forms, stem, nil, is5a and "a" or is5b and "b" or "c", nil, pres_note)
	append_imper_by_variant(forms, stem, nil, data.imper_variant, data.conj_type, pres_note)

	-- set prefix to "" as past stem may vary in length and no (1) variants
	set_past_by_stress(forms, data.past_stress, "", nil, past_stem, nil,
		args, data)

	return forms
end

conjugations["5a"] = function(args, data)
	return guts_of_5(args, data)
end

conjugations["5b"] = function(args, data)
	return guts_of_5(args, data)
end

conjugations["5c"] = function(args, data)
	return guts_of_5(args, data)
end

-- Implement 6a, 6°a, 6a1as13, 6a1as14, and 1a6a.
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
		data.title = "6a // 1a"
		data.cat_conj_types = {"1a", "6a"}
	elseif vclass == "1a6a" then
		data.title = "1a // 6a"
		data.cat_conj_types = {"1a", "6a"}
	end
	parse_variants(data, args[1], {"23", "и", "past", "+p", "7", "ё"})
	local inf = get_stressed_arg(args, 2)
	local inf_past_stem = nom.strip_ending(inf, nil, "ть")
	local stem = rmatch(inf_past_stem, "^(.*)[ая]́?$")
	if not stem then
		error("Argument " .. inf .. " doesn't end in ать or ять")
	end
	if com.is_unstressed(stem) then
		-- колыха́ть, колеба́ть, etc.
		stem = com.make_ending_stressed(stem)
	end
	-- вызвать - вы́зову (в́ызов)
	local pres_stem = get_opt_stressed_arg(args, 3) or stem
	no_stray_args(args, 3)
	local pres_note = pres_stem ~= stem and IRREG

	-- no iotation, e.g. вырвать - вы́рву
	local no_iotation = vclass == "6°a"
	-- replace consonants for 1st person singular present/future
	local iotated_stem = no_iotation and pres_stem or com.iotation(pres_stem)

	forms["infinitive"] = inf_past_stem .. "ть"

	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	local hushing = rfind(iotated_stem, "[шщжч]$") or no_iotation

	-- Participles
	-- pres_pasv_part is normal if infinitive ends in -ять, nonexistent except
	-- with certain lexical exceptions (колеба́ть, колыха́ть, глаго́лать,
	-- дви́гать with exceptional form дви́жимый) if infinitive ends in -ать
	local prpp_status = rfind(inf_past_stem, "я́?$") and "" or "none-"
	if vclass == "6a" or vclass == "6°a" or vclass == "6a1as13" then
		append_participles_2stem(forms, iotated_stem, nil, inf_past_stem, nil,
			hushing and "ущий" or "ющий", prpp_status .. "емый", hushing and "а" or "я",
			"вший", "вши", "в", pres_note)
		if vclass == "6a1as13" then
			-- then all the type 1a forms (both are the same in the past)
			append_participles(forms, inf_past_stem, nil, "ющий*", prpp_status .. "емый", "я")
		end
	elseif vclass == "6a1as14" then
		-- first the preferred type 6a present active/passive participles
		append_participles(forms, iotated_stem, nil,
			hushing and "ущий" or "ющий", prpp_status .. "емый", {}, {}, {}, {}, pres_note)
		-- then all the type 1a forms (both are the same in the past)
		append_participles(forms, inf_past_stem, nil, "ющий", "емый", "я",
			"вший", "вши", "в")
		-- then the dated type 6a present adverbial participle
		append_participles(forms, iotated_stem, nil,
			{}, {}, hushing and "а*" or "я*", {}, {}, {}, pres_note)
	else -- type 1a6a
		-- first the preferred type 1a forms (both are the same in the past)
		append_participles(forms, inf_past_stem, nil, "ющий", "емый", "я",
			"вший", "вши", "в")
		-- then the type 6a forms (dated in present adverbial participle)
		append_participles(forms, iotated_stem, nil,
			hushing and "ущий" or "ющий", prpp_status .. "емый", hushing and "а*" or "я*",
			{}, {}, {}, pres_note)
	end
	set_moving_ppp(forms, data)

	-- Present/future tense
	local function class_6_present()
		if no_iotation then
			present_e_a(forms, pres_stem, nil, pres_note)
		else
			present_je(forms, pres_stem, nil, "a", nil, pres_note)
		end
	end
	if vclass == "6a" or vclass == "6°a" then
		class_6_present()
	elseif vclass == "1a6a" then
		-- Do type 1a forms
		present_je(forms, inf_past_stem, nil, "a")
		class_6_present()
	elseif vclass == "6a1as14" then
		class_6_present()
		-- Do type 1a forms
		present_je(forms, inf_past_stem, nil, "a")
	else
		-- 6a1as13
		class_6_present()
		-- Do type 1a forms
		present_je(forms, inf_past_stem, nil, "a", nil, "*")
	end

	-- Imperative forms; if 1a6a or 6a1as14, type 6a forms are dated;
	-- if 6a1as13, type 6a forms go first.
	local function class_1_impr()
		append_imper(forms, inf_past_stem, nil, "й", "йте")
	end
	local function class_6_impr()
		local dated_note = ((vclass == "6a1as14" or vclass == "1a6a") and "*" or "") ..
			(pres_note or "")
		append_imper_by_variant(forms, iotated_stem, nil, data.imper_variant,
			"6a", dated_note)
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

conjugations["6°a"] = function(args, data)
	return guts_of_6a(args, data, "6°a")
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

-- implement 6b, 6°b
local function guts_of_6b(args, data, vclass)
	local forms = {}

	parse_variants(data, args[1], {"past", "+p", "7", "ё"})
	local inf = get_stressed_arg(args, 2)
	local stem = rmatch(inf, "^(.*)[ая]́ть$")
	if not stem then
		error("Argument " .. inf .. " doesn't end in ать or ять")
	end
	-- звать - зов, драть - дер
	local pres_stem = get_opt_unstressed_arg(args, 3) or stem
	no_stray_args(args, 3)
	-- no iotation, e.g. рвать - рву
	local no_iotation = vclass == "6°b"
	local vowel_end_stem = is_vowel_stem(stem)
	local pres_note = pres_stem ~= stem and IRREG

	if no_iotation then
		present_e_b(forms, pres_stem, nil, pres_note)
	else
		present_je(forms, pres_stem, nil, "b", nil, pres_note)
	end

	local impr_end = vowel_end_stem and "́й" -- accent on the preceding vowel
		or "и́"
	append_imper(forms, pres_stem, nil, impr_end, impr_end .. "те", pres_note)

	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	local hushing = rfind(pres_stem, "[шщжч]$")

	-- no pres_pasv_part
	local past_stem_with_vowel = stem .. (vowel_end_stem and "я́" or "а́")
	append_participles_2stem(
		forms, pres_stem, nil, past_stem_with_vowel, nil,
		((hushing or no_iotation) and "у́щий" or "ю́щий"), {}, (hushing and "а́" or "я́"),
		"вший", "вши", "в", pres_note)
	forms["infinitive"] = combine(past_stem_with_vowel, nil, "ть")
	set_moving_ppp(forms, data)

	-- past_f for ждала́, подождала́ now handled through general mechanism
	--for разобрало́сь, past_n2 разобрало́ now handled through general mechanism
	--for разобрали́сь, past_pl2 разобрали́ now handled through general mechanism

	-- set prefix to "" as past stem may vary in length and no (1) variants
	set_past_by_stress(forms, data.past_stress, "", nil,
		stem .. (vowel_end_stem and "я́" or "а́"), nil, args, data)

	return forms
end

conjugations["6b"] = function(args, data)
	return guts_of_6b(args, data, "6b")
end

conjugations["6°b"] = function(args, data)
	return guts_of_6b(args, data, "6°b")
end

-- Implement 6c, 6°c and 6c1a.
local function guts_of_6c(args, data, vclass)
	local forms = {}

	-- In type 6c1a, forms of both 6c and 1a can occur. They are
	-- the same in the infinitive and past. In the present active participle
	-- and the present/future, the type 6c forms are preferred and the type 1a
	-- forms are colloquial. In the remaining present forms and the imperative,
	-- both are equally preferred (we put the 6c forms first because Zaliznyak
	-- lists 6c first).
	if vclass == "6c1a" then
		data.title = "6c // 1a"
		data.cat_conj_types = {"1a", "6c"}
	end

	-- optional щ parameter for verbs like клеветать (клевещу́), past stress
	parse_variants(data, args[1], {"щ", "past", "+p", "7", "ё"})
	local stem = nom.strip_ending(get_stressed_arg(args, 2), nil, "а́ть")
	stem = com.make_ending_stressed(stem)
	-- разостла́ть - расстелю́, рассте́лешь
	local pres_stem = get_opt_stressed_arg(args, 3) or stem
	no_stray_args(args, 3)
	local pres_note = pres_stem ~= stem and IRREG
	-- remove accent for some forms
	local stem_noa = com.make_unstressed(stem)
	-- applies only to стона́ть, застона́ть, простона́ть
	local no_iotation = vclass == "6°c"
	-- iotate the stem
	local iotated_stem =
		no_iotation and pres_stem or com.iotation(pres_stem, nil, data.shch)
	local stem1a = stem_noa .. "а́"

	forms["infinitive"] = stem_noa .. "а́ть"

	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	local hushing = rfind(iotated_stem, "[шщжч]$")
	-- Participles
	append_participles_2stem(forms, iotated_stem, nil, stem_noa, nil,
		(hushing or no_iotation) and "ущий" or "ющий", {},
		hushing and "а́" or "я́", "а́вший", "а́вши", "а́в", pres_note)
	if vclass == "6c1a" then
		-- then all the type 1a forms (both are the same in the past)
		append_participles(forms, stem1a, nil, "ющий*", "емый", "я")
	end
	set_moving_ppp(forms, data)

	if no_iotation then
		present_e_c(forms, pres_stem, nil, pres_note)
	else
		present_je(forms, pres_stem, nil, "c", data.shch, pres_note)
	end
	append_imper(forms, iotated_stem, nil, "и́", "и́те", pres_note)
	if vclass == "6c1a" then
		present_je(forms, stem1a, nil, "a", nil, "*")
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

conjugations["6°c"] = function(args, data)
	return guts_of_6c(args, data, "6°c")
end

conjugations["6c1a"] = function(args, data)
	return guts_of_6c(args, data, "6c1a")
end

local function convert_last_e_to_yo(form)
	return rsub(form,
		"([еѣ])́?([^" .. com.vowel .. "]*)$",
		function(e, nonvowels)
			return (e == "е" and "ё" or "ѣ̈") .. nonvowels
		end)
end

local function guts_of_7(args, data, forms)
	local is7b = data.conj_type == "7b"

	local full_inf = get_stressed_arg(args, 2)
	local pres_stems = is7b and get_unstressed_arg(args, 3) or get_stressed_arg(args, 3)
	pres_stems = rsplit(pres_stems, ",")
	local past_stem
	if past_stem ~= "ёе" then
		past_stem = get_opt_stressed_arg(args, 4)
	end
	local past_stem_vowel_alt = past_stem == "ёе"
	if past_stem_vowel_alt then
		past_stem = nil
	end
	no_stray_args(args, 4)

	forms["infinitive"] = full_inf

	-- Construct the default past and present stem by a combination of
	-- infinitive and present final consonant.
	-- (1) Deduce the final consonant.
	local final_cons
	for _, pres_stem in ipairs(pres_stems) do
		-- Final cons is -ст if pres stem ends in vowel + ст, else
		-- single final cons [дтсзбп] (no actual examples of final п).
		-- Note that final -з can occur after a consonant (e.g. ползти́).
		local this_final_cons = rmatch(pres_stem,
			"[" .. com.vowel .. "]" .. AC .. "?(ст)$")
		if not this_final_cons then
			this_final_cons = rmatch(pres_stem,	"([дтсзбп])$")
		end
		if not this_final_cons then
			error("Unable to determine final consonant from present stem " .. pres_stem)
		end
		if final_cons and this_final_cons ~= final_cons then
			error("Present stems with conflicting final consonants specified: " ..
				table.concat(pres_stems, ","))
		end
		final_cons = this_final_cons
	end
	-- (2) Find the infinitive minus the termination.
	local prefix = rmatch(full_inf, "^(.*)[сз]т[иь]" .. AC .."?$")
	if not prefix then
		error("Strange infinitive " .. full_inf .. "in class 7")
	end
	-- (3) Combine infinitive with final consonant.
	local default_pres_stem = prefix .. final_cons
	if is7b then
		default_pres_stem = com.make_unstressed(default_pres_stem)
	end
	local default_past_stem = default_pres_stem
	if com.is_unstressed(default_past_stem) then
		default_past_stem = com.make_ending_stressed(default_past_stem)
	end
	-- (4) Past stems ending in -д and -т when the infinitive ends in -сть (but not -сти or -сти́)
	--     lose this consonant (page 85 of Zaliznyak, see also footnote 2 on that page).
	if rfind(full_inf, "сть$") then
		default_past_stem = rsub(default_past_stem, "[дт]$", "")
	end
	-- (5) If 7b and the past stem wasn't originally specified as ёе, the past stem gets
	-- ё in place of е.
	if is7b and not past_stem_vowel_alt then
		default_past_stem = convert_last_e_to_yo(default_past_stem)
	end

	for _, pres_stem in ipairs(pres_stems) do
		local pres_note = pres_stem ~= default_pres_stem and IRREG
		if is7b then
			present_e_b(forms, pres_stem, nil, pres_note)
			append_imper(forms, pres_stem, nil, "и́", "и́те", pres_note)
		else
			present_e_a(forms, pres_stem, nil, pres_note)
			append_imper_by_variant(forms, pres_stem, nil, data.imper_variant,
				"7a", pres_note)
		end
	end

	-- Construct the past stem if not specified. Note that we then derive a separate
	-- past-tense stem from this stem, and this stem as such ends up applying only
	-- to the past active and adverbial participles.
	if not past_stem then
		past_stem = default_past_stem
	end
	local past_note = past_stem ~= default_past_stem and IRREG

	-- Derive the past tense stem from the past stem derived above. This has ё instead of е
	-- in 7b verbs; it also loses д and т in all cases, when the past stem derived above only loses
	-- these consonants in some cases.
	local past_tense_stem = past_stem
	if is7b then
		past_tense_stem = convert_last_e_to_yo(past_tense_stem)
	end
	past_tense_stem = rsub(past_tense_stem, "[дт]$", "")

	local vowel_pp = is_vowel_stem(past_stem)
	local pap = vowel_pp and "вши" or "ши"
	local var9_note_symbol = next_note_symbol(data)
	for _, pres_stem in ipairs(pres_stems) do
		append_participles_2stem(forms, pres_stem, nil, past_stem, nil,
			is7b and "у́щий" or "ущий", "-", is7b and "я́" or "я",
			vowel_pp and "вший" or "ший",
			data.var9 and {is7b and "я́" or "я", pap .. var9_note_symbol} or pap,
			vowel_pp and not data.var9 and "в" or "-", pres_note, past_note)
	end
	if data.var9 then
		ut.insert_if_not(data.internal_notes, var9_note_symbol .. " Dated.")
	end
	-- set prefix to "" as past stem may vary in length and no (1) variants
	set_past_by_stress(forms, data.past_stress, "", nil, past_tense_stem, nil,
		args, data,
		-- 0 ending if the past stem ends in a consonant
		not is_vowel_stem(past_tense_stem) and "no-pastml", past_note)
	-- set PPP; must be done after both present 3sg and past fem have been set
	set_class_7_8_ppp(forms, args, data)
end

conjugations["7a"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"23", "и", "9","past", "+p"})

	-- лезть - ле́зши - non-existent past_actv_part handled through general mechanism
	guts_of_7(args, data, forms)

	return forms
end

conjugations["7b"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"9", "past", "+p"})

	guts_of_7(args, data, forms)

	return forms
end

local function class_8a_stem_to_infinitive(stem)
	-- map e.g. вы́сек back to высе́чь
	return rsub(stem, "[гк]$", "чь")
end

local function class_8b_stem_to_infinitive(stem)
	-- map e.g. отвлёк back to отвле́чь
	-- map e.g. зажёг back to заже́чь
	return com.make_ending_stressed(rsub(rsub(rsub(stem, "ё", "е"), "ѣ̈", "ѣ"), "[гк]$", "чь"))
end

conjugations["8a"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"past", "+p"})
	local full_inf = get_stressed_arg(args, 2)
	local stem = get_stressed_arg(args, 3)
	local stressed_past_stem = get_opt_stressed_arg(args, 4) or stem
	no_stray_args(args, 4)
	forms["infinitive"] = full_inf
	local pres_note = class_8a_stem_to_infinitive(stem) ~= full_inf and IRREG
	local stressed_past_note =
		class_8a_stem_to_infinitive(stressed_past_stem) ~= full_inf and IRREG

	-- default for pres_pasv_part is blank
	append_participles_2stem(forms, stem, nil, stressed_past_stem, nil,
		"ущий", "-", "-", "ший", "ши", "-", pres_note, stressed_past_note)

	local iotated_stem = com.iotation(stem)

	append_pres_futr(forms, iotated_stem, nil, {}, "ешь", "ет", "ем", "ете", {}, pres_note)
	append_pres_futr(forms, stem, nil, "у", {}, {}, {}, {}, "ут", pres_note)
	append_imper(forms, stem, nil, "и", "ите", pres_note)
	-- set prefix to "" as stem may vary in length and no (1) variants
	set_past_by_stress(forms, data.past_stress, "", nil, stem, nil, args, data,
		"no-pastml", pres_note)
	forms["past_m"] = stressed_past_stem .. (stressed_past_note or "")

	-- set PPP; must be done after both present 3sg and past fem have been set
	set_class_7_8_ppp(forms, args, data)

	return forms
end

conjugations["8b"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"past", "+p"})
	local full_inf = get_stressed_arg(args, 2)
	local stem = get_unstressed_arg(args, 3)
	local stressed_past_stems = rsplit(args[4] or "ё", ",")
	for _, stressed_past_stem in ipairs(stressed_past_stems) do
		if stressed_past_stem ~= "е" then
			check_stressed_arg(stressed_past_stem, 4)
		end
	end
	no_stray_args(args, 4)
	forms["infinitive"] = full_inf
	local pres_note = class_8b_stem_to_infinitive(stem) ~= full_inf and IRREG

	local iotated_stem = com.iotation(stem)
	append_pres_futr(forms, iotated_stem, nil, {}, "ёшь", "ёт", "ём", "ёте", {}, pres_note)
	append_pres_futr(forms, stem, nil, "у́", {}, {}, {}, {}, "у́т", pres_note)
	append_imper(forms, stem, nil, "и́", "и́те", pres_note)
	-- set prefix to "" as stem may vary in length and no (1) variants
	set_past_by_stress(forms, data.past_stress, "", nil,
		com.make_ending_stressed(stem), nil, args, data, "no-pastml", pres_note)
	forms["past_m"] = nil

	for _, stressed_past_stem in ipairs(stressed_past_stems) do
		local pastm_stem, past_part_stem
		if stressed_past_stem == "е" then
			past_part_stem = com.make_ending_stressed(stem)
			pastm_stem = past_part_stem
		elseif stressed_past_stem == "ё" then
			past_part_stem = convert_last_e_to_yo(com.make_ending_stressed(stem))
			pastm_stem = past_part_stem
		elseif stressed_past_stem == "ёе" then
			past_part_stem = com.make_ending_stressed(stem)
			pastm_stem = convert_last_e_to_yo(past_part_stem)
		else
			pastm_stem = stressed_past_stem
			past_part_stem = stressed_past_stem
		end

		local past_note =
			class_8b_stem_to_infinitive(pastm_stem) ~= full_inf and IRREG
		-- default for pres_pasv_part is blank; влечь -> влеко́мый handled through
		-- general override mechanism
		append_participles_2stem(forms, stem, nil, past_part_stem, nil,
			"у́щий", "-", "-", "ший", "ши", "-", pres_note, past_note)
		append_form(forms, "past_m", pastm_stem, nil, "", past_note)
	end

	-- set PPP; must be done after both present 3sg and past fem have been set
	set_class_7_8_ppp(forms, args, data)

	return forms
end

conjugations["9a"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"past", "+p"})
	local stem = nom.strip_ending(get_stressed_arg(args, 2), nil, "еть")
	local pres_stem = get_opt_stressed_arg(args, 3)
	no_stray_args(args, 3)
	local prefix, _, base, _ = split_monosyllabic_main_verb(stem)
	local default_pres_stem = prefix .. rsub(base, "е", "")
	pres_stem = pres_stem or default_pres_stem
	local pres_note = pres_stem ~= default_pres_stem and IRREG

	forms["infinitive"] = stem .. "еть"

	-- perfective only
	append_participles(forms, stem, nil, "-", "-", "-", "ший", "ши", "ев")
	present_e_a(forms, pres_stem, nil, pres_note)
	append_imper(forms, pres_stem, nil, "и", "ите", pres_note)
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

	parse_variants(data, args[1], {"past", "+p", "*"})
	local stem_noa = nom.strip_ending(get_stressed_arg(args, 2), nil, "е́ть")
	local stem = rsub(stem_noa, "(.*)е", "%1ё")
	local pres_stem = get_opt_unstressed_arg(args, 3)
	-- stem used for past active and adverbial participles; defaults to past_m
	local past_part_stem = get_opt_stressed_arg(args, 4)
	no_stray_args(args, 4)
	local prefix, _, base, _ = split_monosyllabic_main_verb(stem, nil, "single_cons_base")
	local default_pres_stem =
		data.star and construct_long_prefix_variant(prefix) .. rsub(base, "[её]", "") or
		prefix .. rsub(base, "[её]", "")
	pres_stem = pres_stem or default_pres_stem
	local pres_note = pres_stem ~= default_pres_stem and IRREG

	forms["infinitive"] = stem_noa .. "е́ть"

	present_e_b(forms, pres_stem, nil, pres_note)
	append_imper(forms, pres_stem, nil, "и́", "и́те", pres_note)

	-- past_m doesn't end in л
	set_past_by_stress(forms, data.past_stress, prefix, nil, base, nil,
		args, data, "no-pastml")
	set_ppp_from_past_m(forms, args, data)
	append_participles_2stem(forms, pres_stem, nil, stem, nil, "у́щий", {}, {},
		-- impf: тереть -> тёрши
		-- pf: растереть -> растёрши, растере́в
		-- we handle (рас)тёрши down below because the stress depends on the
		-- past_m: запереть -> за́пер, за́перши(й)
		{}, {}, impf and {} or "е́в", pres_note)
	if past_part_stem then
		for _, ppstem in ipairs(rsplit(past_part_stem, ",")) do
			append_participles(forms, ppstem, nil, {}, {}, {}, "ший", "ши", {})
		end
	else
		iterate_over_prop(forms, args, "past_m", function(ru, tr, note)
			append_participles(forms, ru, tr, {}, {}, {}, "ший", "ши", {}, note)
		end)
	end
	return forms
end

conjugations["10a"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"+p", "7"})
	local stem = nom.strip_ending(get_stressed_arg(args, 2), nil, "оть")
	no_stray_args(args, 2)

	forms["infinitive"] = stem .. "оть"

	-- These verbs are perfective-only, no present participles
	append_participles(forms, stem, nil, "-", "-", "-", "овший", "овши", "ов")
	set_moving_ppp(forms, data)
	present_je(forms, stem, nil, "a")
	append_imper(forms, stem, nil, "и", "ите")
	set_past(forms, stem .. "ол", nil, "", "а", "о", "и")

	return forms
end

conjugations["10c"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"+p", "7"})
	local inf_stem = nom.strip_ending(get_stressed_arg(args, 2), nil, "ть")
	-- present tense stressed stem "моло́ть" - ме́лет
	local pres_stem = get_opt_stressed_arg(args, 3)
	no_stray_args(args, 3)
	local default_pres_stem =
		com.make_ending_stressed(nom.strip_ending(inf_stem, nil, "о́"))
	pres_stem = pres_stem or default_pres_stem
	-- remove accent for some forms
	local pres_stem_noa = com.remove_accents(pres_stem)
	local pres_note = pres_stem ~= default_pres_stem and IRREG

	forms["infinitive"] = inf_stem .. "ть"

	-- default for pres_pasv_part is blank
	append_participles_2stem(forms, pres_stem, nil, inf_stem, nil,
		"ющий", "-", "я́", "вший", "вши", "в", pres_note)
	set_moving_ppp(forms, data)
	present_je(forms, pres_stem, nil, "c", nil, pres_note)
	append_imper(forms, pres_stem_noa, nil, "и́", "и́те", pres_note)
	set_past(forms, inf_stem .. "л", nil, "", "а", "о", "и")

	return forms
end

conjugations["11a"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"past", "+p"})
	local stem = nom.strip_ending(get_stressed_arg(args, 2), nil, "ить")
	no_stray_args(args, 2)
	local prefix, _, base, _ = split_monosyllabic_main_verb(stem .. "и")

	forms["infinitive"] = stem .. "ить"
	-- perfective only
	append_participles(forms, stem, nil, "-", "-", "-", "ивший", "ивши", "ив")
	present_je(forms, stem .. "ь", nil, "a")
	append_imper(forms, stem .. "ей", nil, "", "те")
	set_past_by_stress(forms, data.past_stress, prefix, nil, base, nil,
		args, data)
	set_ppp_from_past_m(forms, args, data)

	return forms
end

conjugations["11b"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"past", "+p", "*"})
	local stem = nom.strip_ending(get_stressed_arg(args, 2), nil, "и́ть")
	local pres_stem = get_opt_unstressed_arg(args, 3)
	no_stray_args(args, 3)
	local prefix, _, base, _ = split_monosyllabic_main_verb(stem .. "и́", nil, "single_cons_base")
	local default_pres_stem =
		data.star and construct_long_prefix_variant(prefix) .. rsub(base, "и́$", "") or
		stem
	pres_stem = pres_stem or default_pres_stem
	local pres_note = pres_stem ~= default_pres_stem and IRREG

	forms["infinitive"] = stem .. "и́ть"

	append_participles_2stem(forms, pres_stem, nil, stem, nil,
		"ью́щий", "-", "ья́", "и́вший", "и́вши", "и́в", pres_note)
	present_je(forms, pres_stem .. "ь", nil, "b", nil, pres_note)
	append_imper(forms, stem .. "е́й", nil, "", "те")

	-- e.g. пила́, лила́
	set_past_by_stress(forms, data.past_stress, prefix, nil, base, nil,
		args, data)
	set_ppp_from_past_m(forms, args, data)

	return forms
end

conjugations["12a"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"past", "+p"})
	local stem = nom.strip_ending(get_stressed_arg(args, 2), nil, "ть")
	local pres_stem = get_opt_stressed_arg(args, 3)
	no_stray_args(args, 3)
	local default_pres_stem = stem
	pres_stem = pres_stem or default_pres_stem
	local pres_note = pres_stem ~= default_pres_stem and IRREG
	local prefix, _, base, _ = split_monosyllabic_main_verb(stem)

	forms["infinitive"] = stem .. "ть"

	append_participles_2stem(forms, pres_stem, nil, stem, nil,
		"ющий", "емый", "я", "вший", "вши", "в", pres_note)
	present_je(forms, pres_stem, nil, "a", nil, pres_note)
	append_imper(forms, pres_stem .. "й", nil, "", "те", pres_note)

	set_past_by_stress(forms, data.past_stress, prefix, nil, base, nil,
		args, data)
	set_ppp_from_past_m(forms, args, data)

	return forms
end

conjugations["12b"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"past", "+p"})
	local stem = nom.strip_ending(get_stressed_arg(args, 2), nil, "ть")
	local pres_stem = get_opt_unstressed_arg(args, 3)
	no_stray_args(args, 3)
	local default_pres_stem = com.make_unstressed_once(stem)
	pres_stem = pres_stem or default_pres_stem
	local pres_note = pres_stem ~= default_pres_stem and IRREG
	local prefix, _, base, _ = split_monosyllabic_main_verb(stem)

	forms["infinitive"] = stem .. "ть"

	-- no pres_pasv_part
	append_participles_2stem(forms, pres_stem, nil, stem, nil,
		"ю́щий", "-", "я́", "вший", "вши", "в", pres_note)
	present_je(forms, pres_stem, nil, "b", nil, pres_note)
	-- the preceding vowel is stressed
	append_imper(forms, pres_stem .. "́й", nil, "", "те", pres_note)

	-- e.g. гнила́ but пе́ла
	set_past_by_stress(forms, data.past_stress, prefix, nil, base, nil,
		args, data)
	set_ppp_from_past_m(forms, args, data)

	return forms
end

conjugations["13b"] = function(args, data)
	local forms = {}

	parse_variants(data, args[1], {"+p"})
	local stem = nom.strip_ending(get_stressed_arg(args, 2), nil, "ть")
	local pres_stem = nom.strip_ending(stem, nil, "ва́")
	no_stray_args(args, 2)

	forms["infinitive"] = stem .. "ть"

	-- tricky to use append_participles_2stem() because only pres_actv_part
	-- uses pres_stem, not all present participles
	forms["pres_actv_part"] = pres_stem .. "ю́щий"
	forms["pres_pasv_part"] = stem .. "емый"
	forms["pres_adv_part"] = stem .. "я"

	forms["past_actv_part"] = stem .. "вший"

	forms["past_adv_part"] = stem .. "вши"
	forms["past_adv_part_short"] = stem .. "в"
	set_moving_ppp(forms, data)
	present_je(forms, pres_stem, nil, "b")
	forms["impr_sg"] = stem .. "й"
	forms["impr_pl"] = stem .. "йте"

	set_past(forms, stem .. "л", nil, "", "а", "о", "и")

	return forms
end

conjugations["14a"] = function(args, data)
	-- only one verb: вы́жать
	local forms = {}

	parse_variants(data, args[1], {"past", "+p"})
	local stem = nom.strip_ending(get_stressed_arg(args, 2), nil, "ть")
	local pres_stem = get_stressed_arg(args, 3)
	no_stray_args(args, 3)
	local prefix, _, base, _ = split_monosyllabic_main_verb(stem)

	forms["infinitive"] = stem .. "ть"

	-- perfective only
	append_participles(forms, stem, nil, "-", "-", "-", "вший", "вши", "в")
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
	local stem = nom.strip_ending(get_stressed_arg(args, 2), nil, "ть")
	local pres_stem = get_unstressed_arg(args, 3)
	no_stray_args(args, 3)
	local prefix, _, base, _ = split_monosyllabic_main_verb(stem)

	forms["infinitive"] = stem .. "ть"

	-- no pres_pasv_part
	append_participles_2stem(forms, pres_stem, nil, stem, nil,
		"у́щий", "-", "я́", "вший", "вши", "в")
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
	local stem = nom.strip_ending(get_stressed_arg(args, 2), nil, "ть")
	local pres_stem = get_stressed_arg(args, 3)
	local pres_stem_noa = com.make_unstressed(pres_stem)
	no_stray_args(args, 3)
	local prefix, _, base, _ = split_monosyllabic_main_verb(stem)

	forms["infinitive"] = stem .. "ть"

	-- no pres_pasv_part
	append_participles_2stem(forms, pres_stem, nil, stem, nil,
		"у́щий", "-", "я́", "вший", "вши", "в")
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
	local stem = nom.strip_ending(get_stressed_arg(args, 2), nil, "ть")
	no_stray_args(args, 2)

	forms["infinitive"] = stem .. "ть"

	-- no pres_pasv_part
	-- no pres_adv_part
	append_participles(forms, stem, nil, "нущий", "-", "-", "вший", "вши", "в")
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
	local stem = nom.strip_ending(get_stressed_arg(args, 2), nil, "ть")
	no_stray_args(args, 2)
	local prefix, _, base, _ = split_monosyllabic_main_verb(stem)

	forms["infinitive"] = stem .. "ть"

	-- no pres_pasv_part
	-- no pres_adv_part
	append_participles(forms, stem, nil, "ву́щий", "-", "-", "вший", "вши", "в")
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
	local stem = nom.strip_ending(get_stressed_arg(args, 2), nil, "ть")
	local stem_noa = com.make_unstressed(stem)
	no_stray_args(args, 2)
	local prefix, _, base, _ = split_monosyllabic_main_verb(stem)

	forms["infinitive"] = stem .. "ть"
	-- no pres_pasv_part
	append_participles(forms, stem, nil, "ву́щий", "-", "вя́", "вший", "вши", "в")
	present_e_b(forms, stem_noa .. "в")

	forms["impr_sg"] = stem_noa .. "ви́"
	forms["impr_pl"] = stem_noa .. "ви́те"

	-- e.g. прижило́сь, прижи́лось
	set_past_by_stress(forms, data.past_stress, prefix, nil, base, nil,
		args, data)
	set_ppp_from_past_m(forms, args, data)

	return forms
end

conjugations["irreg"] = function(args, data)
	local prefix, _, main = split_known_main_verb(get_stressed_arg(args, 2),
		-- честь must go before есть
		{"бежа́ть", "бѣжа́ть", "хоте́ть", "хотѣ́ть", "да́ть", "че́сть",
			"е́сть", "ѣ́сть", "сы́пать", "лга́ть", "мо́чь", "идти́", "йти́",
			"е́хать", "ѣ́хать", "мину́ть", "живописа́ть", "ле́чь",
			"зи́ждить", "зы́бить", "кля́сть", "стели́ть", "бы́ть", "сса́ть", "сца́ть",
			"чти́ть", "шиби́ть", "реве́ть", "има́ть", "вня́ть", "обя́зывать"})
	main = com.make_unstressed_once(main)
	if not conjugations["irreg-" .. main] then
		error("Strange, can't find conjugation for main verb " .. main)
	end
	return conjugations["irreg-" .. main](args, data)
end

conjugations["irreg-бежать"] = function(args, data)
	-- irregular, only for verbs derived from бежать with the same stress pattern
	local forms = {}

	local prefix = split_known_main_verb(get_stressed_arg(args, 2),
		{"бежа́ть", "бѣжа́ть"})
	data.title = com.is_stressed(prefix) and "5a" or "5b"
	-- no past passive participles of any verbs of this type
	parse_variants(data, args[1], {})
	no_stray_args(args, 2)

	forms["infinitive"] = "бежа́ть"
	append_participles_2stem(forms, "бег", nil, "бежа́", nil,
		"у́щий", "-", "-", "вший", "вши", "в", IRREG)
	append_imper(forms, "беги́", nil, "", "те", IRREG)
	append_pres_futr(forms, "бе", nil,
		"гу́" .. IRREG, "жи́шь", "жи́т", "жи́м", "жи́те", "гу́т" .. IRREG)
	set_past(forms, "бежа́л", nil, "", "а", "о", "и")
	if data.old then
		rsub_forms(forms, "^бе", "бѣ")
	end
	prepend_prefix(forms, prefix)
	-- no PPP's for any derivatives of бежать

	return forms
end

conjugations["irreg-бѣжать"] = conjugations["irreg-бежать"]

conjugations["irreg-хотеть"] = function(args, data)
	-- irregular, only for verbs derived from хотеть with the same stress pattern
	local forms = {}

	local prefix = split_known_main_verb(get_stressed_arg(args, 2),
		{"хоте́ть", "хотѣ́ть"})
	data.title = "5c'"
	data.cat_conj_types = {"5c"} -- no class for 5c', no point in creating for just this verb
	-- no past passive participles of any verbs of this type
	parse_variants(data, args[1], {})
	no_stray_args(args, 2)

	forms["infinitive"] = "хоте́ть"
	append_participles_2stem(forms, "хот", nil, "хоте́", nil,
		"я́щий", "-", "я́",	"вший", "вши", "в")
	append_imper(forms, "хоти́", nil, "", "те")
	append_pres_futr(forms, "", nil,
		"хочу́", "хо́чешь" .. IRREG, "хо́чет" .. IRREG, "хоти́м", "хоти́те", "хотя́т")
	set_past(forms, "хоте́л", nil, "", "а", "о", "и")
	if data.old then
		rsub_forms(forms, "^хоте", "хотѣ")
	end
	prepend_prefix(forms, prefix)

	return forms
end

conjugations["irreg-хотѣть"] = conjugations["irreg-хотеть"]

conjugations["irreg-дать"] = function(args, data)
	-- irregular, only for verbs derived from дать with the same stress pattern and вы́дать
	local forms = {}

	--for this type, it's important to distinguish if it's reflexive to set some stress patterns
	local prefix = split_known_main_verb(get_stressed_arg(args, 2), "да́ть")
	data.title = com.is_stressed(prefix) and "irreg-a" or "irreg-b"
	parse_variants(data, args[1], {"past", "+p"})
	no_stray_args(args, 2)

	forms["infinitive"] = "да́ть"
	-- no pres_pasv_part
	-- no pres_adv_part
	append_participles(forms, "", nil, "даю́щий", "-", "-",
		"да́вший", "да́вши", "да́в")
	append_imper(forms, "да́й", nil, "", "те")
	append_pres_futr(forms, "", nil,
		"да́м", "да́шь", "да́ст", "дади́м", "дади́те", "даду́т")
	prepend_prefix(forms, prefix)
	set_past_by_stress(forms, data.past_stress, prefix, nil, "да́", nil,
		args, data)
	if data.ppp then
		if prefix == "пере" then
			set_ppp(forms, "", nil, "пе́реданный")
		elseif prefix == "раз" then
			set_ppp(forms, "", nil, "ро́зданный")
		else
			set_moving_ppp(forms, data)
		end
	end

	return forms
end

conjugations["irreg-есть"] = function(args, data)
	-- irregular, only for verbs derived from есть
	local forms = {}

	local prefix = split_known_main_verb(get_stressed_arg(args, 2),
		{"е́сть", "ѣ́сть"})
	data.title = com.is_stressed(prefix) and "irreg-a" or "irreg-b"
	parse_variants(data, args[1], {"+p"})
	no_stray_args(args, 2)

	forms["infinitive"] = "е́сть"
	append_participles_2stem(forms, "ед", nil, "е́", nil,
		"я́щий", "о́мый", "я́", "вший", "вши", "в")
	if data.ppp then
		set_ppp(forms, "е́д", nil, "енный")
	end
	append_imper(forms, "е́шь", nil, "", "те")
	append_pres_futr(forms, "е́", nil,
		"м", "шь", "ст", "ди́м", "ди́те", "дя́т")
	set_past(forms, "е́л", nil, "", "а", "о", "и")
	if data.old then
		rsub_forms(forms, "^е", "ѣ")
	end
	prepend_prefix(forms, prefix)

	return forms
end

conjugations["irreg-ѣсть"] = conjugations["irreg-есть"]

conjugations["irreg-сыпать"] = function(args, data)
	-- irregular, only for verbs derived from сыпать
	local forms = {}

	--for this type, it's important to distinguish if it's reflexive for вы́сыпаться vs. вы́сыпать imperative
	local prefix = split_known_main_verb(get_stressed_arg(args, 2), "сы́пать")
	data.title = "6a"
	parse_variants(data, args[1], {"+p"})
	no_stray_args(args, 2)

	forms["infinitive"] = "сы́пать"
	append_participles(forms, "сы́п", nil,
		"лющий", "лемый", {"ля", "я" .. IRREG}, "авший", "авши", "ав")
	append_imper(forms, "сы́п", nil,
		-- вы́сыпать (but not вы́сыпаться) has two imperative singulars
		com.is_stressed(prefix) and not data.refl and {"и", "ь"} or "ь", "ьте", IRREG)
	present_je(forms, "сы́пл", nil, "a")
	append_pres_futr(forms, "сы́п", nil,
		{}, "ешь", "ет", "ем", "ете", {}, IRREG)
	set_past(forms, "сы́пал", nil, "", "а", "о", "и")
	prepend_prefix(forms, prefix)
	set_moving_ppp(forms, data)

	return forms
end

conjugations["irreg-лгать"] = function(args, data)
	-- irregular, only for verbs derived from лгать with the same stress pattern
	local forms = {}

	local prefix = split_known_main_verb(get_stressed_arg(args, 2), "лга́ть")
	data.title = "6°b/c"
	parse_variants(data, args[1], {"+p"})
	no_stray_args(args, 2)

	forms["infinitive"] = "лга́ть"
	-- no pres_pasv_part
	-- no pres_adv_part
	append_participles(forms, "лг", nil,
		"у́щий", "-", "-", "а́вший", "а́вши", "а́в")
	append_imper(forms, "лги́", nil, "", "те")
	append_pres_futr(forms, "", nil,
		"лгу́", "лжёшь" .. IRREG, "лжёт" .. IRREG, "лжём" .. IRREG, "лжёте" .. IRREG, "лгу́т")
	set_past(forms, "лга́л", nil, "", "а́", "о", "и")
	prepend_prefix(forms, prefix)
	set_moving_ppp(forms, data)

	return forms
end

conjugations["irreg-мочь"] = function(args, data)
	-- irregular, only for verbs derived from мочь with the same stress pattern
	local forms = {}

	local prefix = split_known_main_verb(get_stressed_arg(args, 2), "мо́чь")
	data.title = "8c/b"
	-- no past passive participles of any verbs of this type
	parse_variants(data, args[1], {})
	no_stray_args(args, 2)

	forms["infinitive"] = "мо́чь"
	-- no passive or adverbial participles
	append_participles(forms, "мо́г", nil,
		"у́щий", "-", "-", "ший", "-", "-")
	append_imper(forms, "моги́", nil, "", "те")
	append_pres_futr(forms, "", nil,
		"могу́", "мо́жешь", "мо́жет", "мо́жем", "мо́жете", "мо́гут")
	set_past(forms, "мо́г", nil, "", "ла́", "ло́", "ли́")
	prepend_prefix(forms, prefix)

	return forms
end

conjugations["irreg-идти"] = function(args, data)
	-- irregular, only for verbs derived from идти, including прийти́ and в́ыйти
	local forms = {}

	local prefix = args[2] == "идти́" and "" or
		split_known_main_verb(get_stressed_arg(args, 2), "йти́")
	data.title = com.is_stressed(prefix) and "irreg-a" or "irreg-b/b"
	parse_variants(data, args[1], {"+p"})
	no_stray_args(args, 2)

	-- no pres_pasv_part

	if prefix == "" then
		-- only идти, present imperfective
		forms["infinitive"] = "идти́"
		append_imper(forms, "иди́", nil, "", "те")
		present_e_b(forms, "ид")
		-- no past_adv_part_short
		append_participles(forms, "", nil,
			"иду́щий", "-", "идя́", "ше́дший", "ше́дши", "-")
	elseif rfind(prefix, "и$") then -- при
		forms["infinitive"] = "йти́"
		append_imper(forms, "ди́", nil, "", "те")
		present_e_b(forms, "д")
		append_participles(forms, "", nil,
			"-", "-", "-", "ше́дший", "ше́дши", "дя́")
	else
		forms["infinitive"] = "йти́"
		append_imper(forms, "йди́", nil, "", "те")
		present_e_b(forms, "йд")
		append_participles(forms, "", nil,
			"-", "-", "-", "ше́дший", "ше́дши", "йдя́")
	end
	set_past(forms, "", nil, "шёл", "шла́", "шло́", "шли́")
	prepend_prefix(forms, prefix)
	if data.ppp then
		if prefix == "на" or prefix == "про" then
			-- найти́ and пройти́ exceptionally have the stress on the prefix
			set_ppp(forms, prefix, nil, "́йденный")
		else
			-- вы́йти and прийти́ are intransitive so we don't have to worry about them
			set_ppp(forms, prefix, nil, "йдённый")
		end
	end

	return forms
end

conjugations["irreg-йти"] = conjugations["irreg-идти"]

conjugations["irreg-ехать"] = function(args, data)
	-- irregular, only for verbs derived from ехать
	local forms = {}
	local old = data.old

	local prefix = split_known_main_verb(get_stressed_arg(args, 2),
		{"е́хать", "ѣ́хать"})
	data.title = "irreg-a"
	-- no past passive participles of any verbs of this type
	parse_variants(data, args[1], {})
	no_stray_args(args, 2)

	forms["infinitive"] = "е́хать"
	-- no pres_pasv_part
	-- no pres_adv_part
	append_participles_2stem(forms, "е́д", nil, "е́х", nil,
		"ущий", "-", "-", "авший", "авши", "ав")
	present_e_a(forms, "е́д")
	set_past(forms, "е́хал", nil, "", "а", "о", "и")
	if data.old then
		rsub_forms(forms, "^е", "ѣ")
	end
	prepend_prefix(forms, prefix)

	--special-case the imperative
	--literary (special) imperative forms for ехать are поезжа́й, поезжа́йте
	impstem = data.old and "ѣзжа́й" or "езжа́й"
	if prefix == "" then
		append_imper(forms, "по" .. impstem, nil, "", "те")
		append_imper(forms, impstem, nil, "", "те")
	elseif com.is_stressed(prefix) then
		append_imper(forms, com.make_unstressed_once(prefix) .. impstem, nil, "", "те")
	else
		append_imper(forms, prefix .. impstem, nil, "", "те")
	end

	return forms
end

conjugations["irreg-ѣхать"] = conjugations["irreg-ехать"]

conjugations["irreg-минуть"] = function(args, data)
	-- for the irregular verb "мину́ть"
	local forms = {}

	local prefix = split_known_main_verb(get_stressed_arg(args, 2), "мину́ть")
	data.title = "3c"
	parse_variants(data, args[1], {"+p"})
	no_stray_args(args, 2)

	forms["infinitive"] = "мину́ть"
	-- no pres_pasv_part
	-- no pres_adv_part
	append_participles(forms, "ми́н", nil,
		"у́щий", "-", "-", "у́вший", "у́вши", "у́в")
	present_e_c(forms, "ми́н")
	forms["pres_futr_1sg"] = "-" -- no futr 1sg
	-- no imperative
	-- two possible variants, one with root-only stress, the other with
	-- either root or suffix stress.
	if not args["root_past_stress"] then
		append_past(forms, "мину́л", nil, "", "а", "о", "и")
	end
	append_past(forms, "ми́нул", nil, "", "а", "о", "и", IRREG)
	prepend_prefix(forms, prefix)
	set_moving_ppp(forms, data)

	return forms
end

conjugations["irreg-живописать"] = function(args, data)
	-- for irregular verb "живописа́ть", mixture of types 1 and 2
	local forms = {}

	local inf = get_stressed_arg(args, 2)
	data.title = "1a"
	parse_variants(data, args[1], {"+p"})
	local inf_stem = nom.strip_ending(inf, nil, "ть")
	local pres_stem = rfind(inf_stem, "а́$") and rsub(inf_stem, "а́$", "у́")
		or error("Unexpected infinitive " .. inf)
	no_stray_args(args, 2)

	forms["infinitive"] = inf_stem .. "ть"
	-- no pres_pasv_part
	append_participles_2stem(forms, pres_stem, nil, inf_stem, nil,
		"ющий", "-", "я", "вший", "вши", "в", IRREG)
	set_moving_ppp(forms, data)
	present_je(forms, pres_stem, nil, "a", nil, IRREG)
	append_imper(forms, pres_stem .. "й", nil, "", "те", IRREG)
	set_past(forms, inf_stem .. "л", nil, "", "а", "о", "и")

	return forms
end

conjugations["irreg-лечь"] = function(args, data)
	-- irregular, only for verbs derived from лечь with the same stress pattern
	local forms = {}

	local prefix = split_known_main_verb(get_stressed_arg(args, 2), "ле́чь")
	data.title = "8a/b"
	-- no past passive participles of any verbs of this type
	parse_variants(data, args[1], {})
	no_stray_args(args, 2)

	forms["infinitive"] = "ле́чь"
	-- no pres parts because always perfective
	-- no past_adv_part_short
	append_participles(forms, "лёг", nil,
		"-", "-", "-", "ший", "ши", "-")
	append_imper(forms, "ля́г", nil, "", "те", IRREG)
	append_pres_futr(forms, "ля́", nil,
		"гу", "жешь", "жет", "жем", "жете", "гут", IRREG)
	set_past(forms, "", nil, "лёг", "легла́", "легло́", "легли́")
	prepend_prefix(forms, prefix)

	return forms
end

conjugations["irreg-честь"] = function(args, data)
	-- irregular, only for verbs derived from идти, including прийти́ and в́ыйти
	local forms = {}

	local prefix = split_known_main_verb(get_stressed_arg(args, 2), "че́сть")
	local pre_two_cons_prefix =
		prefix == "об" and "обо" or
		prefix == "с" and "со" or
		prefix == "рас" and "разо" or
		prefix
	data.title = prefix == "" and "7b/b" or com.is_stressed(prefix) and "7a⑨" or
		pre_two_cons_prefix ~= prefix and "7*b/b⑨" or "7b/b⑨"
	parse_variants(data, args[1], {"+p"})
	no_stray_args(args, 2)

	-- no pres_pasv_part

	forms["infinitive"] = "че́сть"
	append_imper(forms, "чти́", nil, "", "те", IRREG)
	present_e_b(forms, "чт", nil, IRREG)
	if prefix == "" then
		append_participles(forms, "", nil,
			"чту́щий", "-", "чтя́", "чти́вший", "чти́вши", "чти́в", IRREG)
	elseif com.is_stressed(prefix) then
		append_participles(forms, "", nil,
			"-", "-", "-", "-", "чтя́", "-", IRREG)
	else
		append_participles(forms, "", nil,
			"-", "-", "-", "-", {"чтя́" .. IRREG, "чётши*"}, "-")
		ut.insert_if_not(data.internal_notes, "* Dated.")
	end
	if data.ppp then
		set_ppp(forms, "", nil, "чтённый" .. IRREG)
	end
	set_past(forms, "", nil, "чёл", "чла́" .. IRREG, "чло́" .. IRREG, "чли́" .. IRREG)
	prepend_prefix(forms, prefix, pre_two_cons_prefix)
	return forms
end

conjugations["irreg-зиждить"] = function(args, data)
	-- irregular, only for verbs derived from зиждить(ся) with the same stress pattern
	local forms = {}

	local prefix = split_known_main_verb(get_stressed_arg(args, 2), "зи́ждить")
	data.title = "irreg-a"
	parse_variants(data, args[1], {"+p"})
	no_stray_args(args, 2)

	forms["infinitive"] = "зи́ждить"
	append_participles(forms, "зи́жд", nil,
		"ущий", "емый", "я", "ивший", "ивши", "ив")
	if data.ppp then
		set_ppp(forms, "зи́жд", nil, "енный")
	end
	append_imper(forms, "зи́жди", nil, "", "те")
	present_e_a(forms, "зи́жд")
	set_past(forms, "зи́ждил", nil, "", "а", "о", "и")
	prepend_prefix(forms, prefix)

	return forms
end

conjugations["irreg-зыбить"] = function(args, data)
	-- irregular, only for verbs derived from зыбить
	local forms = {}

	local prefix = split_known_main_verb(get_stressed_arg(args, 2), "зы́бить")
	data.title = "irreg-a"
	-- no past passive participles of any verbs of this type
	parse_variants(data, args[1], {})
	no_stray_args(args, 2)

	forms["infinitive"] = "зы́бить"
	append_participles(forms, "зы́б", nil,
		"лющий", "лемый", "ля", "ивший", "ивши", "ив")
	append_imper(forms, "зы́бли", nil, "", "те")
	present_je(forms, "зы́б", nil, "a")
	set_past(forms, "зы́бил", nil, "", "а", "о", "и")
	prepend_prefix(forms, prefix)

	return forms
end

conjugations["irreg-клясть"] = function(args, data)
	-- irregular, only for verbs derived from клясть with the same stress pattern
	local forms = {}

	--for this type, it's important to distinguish if it's reflexive to set some stress patterns
	local prefix = split_known_main_verb(get_stressed_arg(args, 2), "кля́сть")
	data.title = "irreg-b"
	parse_variants(data, args[1], {"past", "+p"})
	no_stray_args(args, 2)

	forms["infinitive"] = "кля́сть"
	append_participles_2stem(forms, "клян", nil, "кля́", nil,
		"у́щий", "и́мый", "я́", "вший", "вши", "в")
	append_imper(forms, "кляни́", nil, "", "те")
	present_e_b(forms, "клян")
	prepend_prefix(forms, prefix)
	set_past_by_stress(forms, data.past_stress, prefix, nil, "кля́", nil,
		args, data)
	set_ppp_from_past_m(forms, args, data)

	return forms
end

conjugations["irreg-стелить"] = function(args, data)
	-- irregular, only for verbs derived from стелить
	local forms = {}

	local prefix = split_known_main_verb(get_stressed_arg(args, 2), "стели́ть")
	data.title = com.is_stressed(prefix) and "4a" or "4c"
	parse_variants(data, args[1], {"+p"})
	no_stray_args(args, 2)

	forms["infinitive"] = "стели́ть"
	append_participles(forms, "сте́л", nil,
		"ющий" .. IRREG, "и́мый", "я́", "и́вший", "и́вши", "и́в")
	set_class_4_ppp(forms, data, "сте́л", nil, data.title)
	append_imper(forms, "стели́", nil, "", "те")
	append_pres_futr(forms, "сте́л", nil, "ю́", {}, {}, {}, {}, {})
	append_pres_futr(forms, "сте́л", nil, {}, "ешь", "ет", "ем", "ете", "ют", IRREG)
	set_past(forms, "стели́л", nil, "", "а", "о", "и")
	prepend_prefix(forms, prefix)

	return forms
end

conjugations["irreg-быть"] = function(args, data)
	-- irregular, only for verbs derived from быть with various stress patterns, the actual verb быть different from its derivatives
	local forms = {}

	--for this type, it's important to distinguish if it's reflexive to set some stress patterns
	local prefix = split_known_main_verb(get_stressed_arg(args, 2), "бы́ть")
	data.title = "irreg-a"
	parse_variants(data, args[1], {"past", "+p"})
	no_stray_args(args, 2)

	forms["infinitive"] = "бы́ть"
	-- no pres_pasv_part
	append_participles(forms, "", nil, "су́щий", "-", "бу́дучи",
		"бы́вший", "бы́вши", "бы́в")
	append_imper(forms, "бу́дь", nil, "", "те")
	prepend_prefix(forms, prefix)

	-- only for "бы́ть", some forms are archaic
	if forms["infinitive"] == "бы́ть" then
		append_pres_futr(forms, "", nil, "есть", "есть", "есть", "есть", "есть", "есть")
	elseif com.is_stressed(prefix) then
		-- if the prefix is stressed, e.g. "вы́быть"
		present_e_a(forms, prefix .. "буд")
	else
		present_e_a(forms, prefix .. "бу́д")
	end

	set_past_by_stress(forms, data.past_stress, prefix, nil, "бы́", nil,
		args, data)
	set_ppp_from_past_m(forms, args, data)

	return forms
end

conjugations["irreg-ссать-сцать"] = function(args, data)
	-- irregular, only for verbs derived from ссать and сцать (both vulgar!)
	local forms = {}

	local prefix, _, stem = split_known_main_verb(get_stressed_arg(args, 2),
		{"сса́ть", "сца́ть"})
	data.title = com.is_stressed(prefix) and "irreg-a" or "irreg-b"
	-- no past passive participles of any verbs of this type
	parse_variants(data, args[1], {})
	stem = nom.strip_ending(stem, nil, "ть")
	local pres_stem = rsub(stem, "а́?$", "")
	no_stray_args(args, 2)

	forms["infinitive"] = stem .. "ть"
	-- no pres_pasv_part
	-- no pres_adv_part
	append_participles(forms, pres_stem, nil, "у́щий", "-", "-",
		"а́вший", "а́вши", "а́в")
	append_imper(forms, pres_stem, nil, "ы́", "ы́те")
	append_pres_futr(forms, pres_stem, nil,
		"у́", "ы́шь", "ы́т", "ы́м", "ы́те", "у́т")
	set_past(forms, stem .. "л", nil, "", "а", "о", "и")
	prepend_prefix(forms, prefix)

	return forms
end

conjugations["irreg-ссать"] = conjugations["irreg-ссать-сцать"]
conjugations["irreg-сцать"] = conjugations["irreg-ссать-сцать"]

conjugations["irreg-чтить"] = function(args, data)
	-- irregular, only for verbs derived from чтить
	local forms = {}

	local prefix = split_known_main_verb(get_stressed_arg(args, 2), "чти́ть")
	data.title = "4b"
	parse_variants(data, args[1], {"+p"})
	no_stray_args(args, 2)

	forms["infinitive"] = "чти́ть"
	append_participles_2stem(forms, "чт", nil, "чти́", nil,
		{"я́щий", "у́щий" .. IRREG}, "и́мый", "я́", "вший", "вши", "в")
	if data.ppp then
		set_ppp(forms, "чт", nil, "ённый")
	end
	append_imper(forms, "чти́", nil, "", "те")
	append_pres_futr(forms, "чт", nil,
		"у́" .. IRREG, "и́шь", "и́т", "и́м", "и́те", {"я́т", "у́т" .. IRREG})
	set_past(forms, "чти́л", nil, "", "а", "о", "и")
	prepend_prefix(forms, prefix)

	return forms
end

conjugations["irreg-шибить"] = function(args, data)
	-- irregular, only for verbs in -шибить(ся)
	local forms = {}

	local prefix = split_known_main_verb(get_stressed_arg(args, 2), "шиби́ть")
	data.title = com.is_stressed(prefix) and "irreg-a" or "irreg-b"
	parse_variants(data, args[1], {"+p"})
	no_stray_args(args, 2)

	-- no present participles
	forms["infinitive"] = "шиби́ть"
	append_participles(forms, "шиби́", nil,
		"-", "-", "-", "вший", "вши", "в")
	if data.ppp then
		set_ppp(forms, "ши́бл", nil, "енный")
	end
	append_imper(forms, "шиби́", nil, "", "те")
	present_e_b(forms, "шиб")
	set_past(forms, "ши́б", nil, "", "ла", "ло", "ли")
	prepend_prefix(forms, prefix)

	return forms
end

conjugations["irreg-реветь"] = function(args, data)
	-- irregular, only for verbs derived from "реветь"
	local forms = {}

	local prefix = split_known_main_verb(get_stressed_arg(args, 2), "реве́ть")
	data.title = "irreg-b"
	-- no past passive participles of any verbs of this type
	parse_variants(data, args[1], {})
	no_stray_args(args, 2)

	forms["infinitive"] = "реве́ть"
	-- no pres_pasv_part
	append_participles_2stem(forms, "рев", nil, "реве́", nil,
		"у́щий", "-", "я́", "вший", "вши", "в")
	present_e_b(forms, "рев")
	append_imper(forms, "реви́", nil, "", "те")
	set_past(forms, "реве́л", nil, "", "а", "о", "и")
	prepend_prefix(forms, prefix)

	return forms
end

conjugations["irreg-имать"] = function(args, data)
	-- irregular, only for внимать and certain archaic verbs (e.g. имать as
	-- conjugated in the 18th century, отъимать)
	local forms = {}

	local prefix = split_known_main_verb(get_stressed_arg(args, 2), "има́ть")
	data.title = "1a // 6a"
	data.cat_conj_types = {"1a", "6a"}
	parse_variants(data, args[1], {"+p"})
	no_stray_args(args, 2)

	forms["infinitive"] = "има́ть"

	-- handle внемл- forms
	append_participles(forms, "е́мл", nil,
		"ющий", "емый", {"я", "я́"}, {}, {}, {})
	-- handle внима́- forms
	append_participles(forms, "има́", nil,
		"ющий", "емый", "я", "вший", "вши", "в")
	if data.ppp then
		-- FIXME, do class-1a-type ppp's (e.g. вни́манный) exist?
		-- ruwikt marks them with a *
		set_ppp(forms, "е́мл", nil, "енный")
	end
	append_imper(forms, "", nil, {"е́мли", "емли́", "има́й"},
		{"е́млите", "емли́те", "има́йте"})
	present_je(forms, "е́мл", nil, "a")
	-- Both вне́млю and внемлю́ are possible
	append_pres_futr(forms, "емл", nil, "ю́", {}, {}, {}, {}, {})
	present_je(forms, "има́", nil, "a")
	set_past(forms, "има́л", nil, "", "а", "о", "и")
	prepend_prefix(forms, prefix)

	return forms
end

conjugations["irreg-внять"] = function(args, data)
	-- irregular, only for внять
	local forms = {}

	local prefix = split_known_main_verb(get_stressed_arg(args, 2), "вня́ть")
	data.title = "14c/c"
	parse_variants(data, args[1], {"+p"})
	no_stray_args(args, 2)

	forms["infinitive"] = "вня́ть"
	-- perfective only; no present participles
	append_participles(forms, "вня́", nil,
		"-", "-", "-", "вший", "вши", "в")
	append_imper(forms, "вними́", nil, "", "те")
	append_imper(forms, "вонми́", nil, "", "те")
	present_e_c(forms, "вни́м")
	present_e_c(forms, "во́нм")
	set_past(forms, "вня́л", nil, "", "а́", "о", "и")
	set_ppp_from_past_m(forms, args, data)
	prepend_prefix(forms, prefix)

	return forms
end

conjugations["irreg-обязывать"] = function(args, data)
	-- irregular, only for обязывать and обязываться
	local forms = {}

	local prefix = split_known_main_verb(get_stressed_arg(args, 2), "обя́зывать")
	data.title = "1a"
	-- no past passive participles of any verbs of this type
	parse_variants(data, args[1], {})
	no_stray_args(args, 2)

	forms["infinitive"] = "обя́зывать"
	append_participles_2stem(forms, "обя́з", nil, "обя́зыва", nil,
		{"ывающий", "у́ющий"}, {"ываемый", "у́емый"}, {"ывая", "у́я"}, "вший", "вши", "в")
	append_imper(forms, "обя́зывай", nil, "", "те")
	append_imper(forms, "обязу́й", nil, "", "те")
	present_je(forms, "обя́зыва", nil, "a")
	present_je(forms, "обязу́", nil, "a")
	set_past(forms, "обя́зывал", nil, "", "а", "о", "и")
	prepend_prefix(forms, prefix)

	return forms
end

--[=[
	Partial conjugation functions
]=]

-- Present forms with -e-, no j-vowels.
present_e_a = function(forms, stem, tr, note)
	append_pres_futr(forms, stem, tr, "у", "ешь", "ет", "ем", "ете", "ут", note)
end

present_e_b = function(forms, stem, tr, note)
	append_pres_futr(forms, stem, tr, "у́", "ёшь", "ёт", "ём", "ёте", "у́т", note)
end

present_e_c = function(forms, stem, tr, note)
	append_pres_futr(forms, stem, tr, "у́", "ешь", "ет", "ем", "ете", "ут", note)
end

-- Present forms with -e- and iotated stem. ABC = "a", "b" or "c", indicating
-- the accent pattern. If SHCH is set, iotate final т as щ, not ч. If NOTE
-- is given, add it to each form.
present_je = function(forms, stem, tr, abc, shch, note)
	local iotated_stem, iotated_tr = com.iotation(stem, tr, shch)

	assert(abc == "a" or abc == "b" or abc == "c")
	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	local hushing = rfind(iotated_stem, "[шщжч]$") -- or no_iotation
	local ending_1sg =
		hushing and (abc == "a" and "у" or "у́") or
		not hushing and (abc == "a" and "ю" or "ю́")
	if abc == "b" then
		append_pres_futr(forms, iotated_stem, iotated_tr,
			{}, "ёшь", "ёт", "ём", "ёте", (hushing and "у́т" or "ю́т"), note)
	else
		append_pres_futr(forms, iotated_stem, iotated_tr,
			{}, "ешь", "ет", "ем", "ете", (hushing and "ут" or "ют"), note)
	end
	append_pres_futr(forms, iotated_stem, iotated_tr,
		ending_1sg, {}, {}, {}, {}, {}, note)
end

-- Present forms with -i- (and iotated stem in the 1sg). ABC = "a", "b" or "c",
-- indicating the accent pattern. If SHCH is set, iotate final т as щ, not ч.
-- If NOTE is given, add it to each form.
present_i = function(forms, stem, tr, abc, shch, note)
	local iotated_stem, iotated_tr = com.iotation(stem, tr, shch)

	assert(abc == "a" or abc == "b" or abc == "c")
	-- Verbs ending in a hushing consonant do not get j-vowels in the endings.
	local iotated_hushing = rfind(iotated_stem, "[шщжч]$")
	local hushing = rfind(stem, "[шщжч]$")
	local ending_1sg =
		iotated_hushing and (abc == "a" and "у" or "у́") or
		not iotated_hushing and (abc == "a" and "ю" or "ю́")
	if abc == "b" then
		append_pres_futr(forms, stem, tr,
			{}, "и́шь", "и́т", "и́м", "и́те", hushing and "а́т" or "я́т", note)
	else
		append_pres_futr(forms, stem, tr,
			{}, "ишь", "ит", "им", "ите", hushing and "ат" or "ят", note)
	end
	append_pres_futr(forms, iotated_stem, iotated_tr,
		ending_1sg, {}, {}, {}, {}, {}, note)
end

-- Add the reflexive particle to all verb forms
make_reflexive = function(forms, reflex_stress)
	for key, form in pairs(forms) do
		local ru, tr = extract_russian_tr(form)
		-- check for empty string, dashes and nil's
		if ru and ru ~= "" and ru ~= "-" then
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
end

-- Convert verb forms to pre-reform style by adding ъ to consonant-final
-- forms (excluding those ending in й and ь) and converting -ий to -ій and
-- -ийся to -ійся
make_pre_reform = function(forms)
	for key, form in pairs(forms) do
		local ru, tr = extract_russian_tr(form)
		-- check for empty string, dashes and nil's
		if ru and ru ~= "" and ru ~= "-" then
			local ruentry, runotes = m_table_tools.separate_notes(ru)
			if rfind(ruentry, "[бцдфгчклмнпрствшхзжщ]$") then
				forms[key] = {ruentry .. "ъ" .. runotes, tr}
			else
				forms[key] = {rsub(rsub(ruentry, "ий$", "ій"), "ийся$", "ійся") .. runotes, tr}
			end
		end
	end
end

local function setup_pres_futr(forms, perf, old)
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

	local futr_data = {
		{"futr_1sg", "бу́ду", "búdu"},
		{"futr_2sg", "бу́дешь", "búdešʹ"},
		{"futr_3sg", "бу́дет" .. (old and "ъ" or ""), "búdet"},
		{"futr_1pl", "бу́дем" .. (old and "ъ" or ""), "búdem"},
		{"futr_2pl", "бу́дете", "búdete"},
		{"futr_3pl", "бу́дут" .. (old and "ъ" or ""), "búdut"}
	}

	local function insert_future(inf, inf_tr)
		for _, fut in ipairs(futr_data) do
			append_to_arg_chain(forms, fut[1], fut[1],
				{fut[2] .. inf, inf_tr and fut[3] .. inf_tr})
		end
	end

	-- Insert future, if required (there may conceivably be multiple infitives).
	for _, form in ipairs(main_to_all_verb_forms["infinitive"]) do
		local infinitive = forms[form]
		if infinitive then
			local inf, inf_tr = extract_russian_tr(forms[form])

			-- only for "бы́ть" the future forms are бу́ду, бу́дешь, etc.
			if inf == "бы́ть" then
				insert_future("", nil)
			elseif not perf then
				insert_future(" " .. inf, inf_tr and " " .. inf_tr)
			end
		end
	end
end

parse_and_stress_override = function(form, val, existing, all_existing)
	if rfind(form, "^pres_futr") then
		error("Overrides of pres_futr* are illegal, use pres_* or futr_*")
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
	if rfind(ru, "%+") then
		-- If either the existing or override has manual translit, the resulting
		-- form should have manual translit. We specify ALWAYS_TRANSLIT if
		-- the override has manual translit, so that we can substitute the
		-- existing translit into the override translit.
		local existing_ru, existing_tr = extract_russian_tr(existing, not not tr)
		-- used especially for present participles; substitute existing form,
		-- minus any "awkward-" or "none-" prefixes.
		ru = rsub(ru, "%+", strip_arg_status_prefix(existing_ru))
		-- If there's existing translit but not in the override, make sure it's
		-- carried along.
		if existing_tr and not tr then
			tr = com.translit(ru)
		end
		tr = tr and rsub(tr, "%+", strip_arg_status_prefix(existing_tr))
	end
	-- If there's an override and it doesn't match an existing form, it's
	-- irregular and indicate it using the IRREG marker. We don't do this if
	-- the override simply removes a form. We do do this if there aren't any
	-- existing forms, on the theory that the presence of a form when none is
	-- normally called for is an irregularity. When comparing against the
	-- existing forms, strip any status prefix (e.g. 'awkward-').
	if all_existing then
		local all_existing_stripped = {}
		for _, ae in ipairs(all_existing) do
			local existing_ru, existing_tr = extract_russian_tr(ae)
			existing_ru = strip_arg_status_prefix(existing_ru)
			existing_tr = existing_tr and strip_arg_status_prefix(existing_tr)
			table.insert(all_existing_stripped, {existing_ru, existing_tr})
		end
		if ru ~= "-" and not contains_form(all_existing_stripped, {ru, tr}) then
			ru = ru .. IRREG
			tr = tr and tr .. IRREG
		end
	end
	return {ru, tr}
end

-- Set up pres_* or futr_*; handle *sym/*tail/*tailall notes and overrides.
handle_forms_and_overrides = function(args, forms, data)
	setup_pres_futr(forms, data.perf, data.old)

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

	-- Now handle pasttail, pasttailall, prestail, prestailall, etc.

	-- Table listing tail-arg prefix and corresponding verb forms.
	local tailargs = {
		{"past", past_verb_forms},
		{"pres", pres_verb_forms},
		{"futr", futr_verb_forms},
		{"impr", impr_verb_forms},
		{"part", part_verb_forms},
		{"prespart", pres_part_verb_forms},
		{"pastpart", past_part_verb_forms},
		{"", all_main_verb_forms}
	}

	for _, tailspec in ipairs(tailargs) do
		tailforms = tailspec[2]
		-- Handle the ...tail variants.
		tailarg = tailspec[1] .. "tail"
		if args[tailarg] then
			track(tailarg)
			for _, prop in ipairs(tailforms) do
				append_note_last(forms, main_to_all_verb_forms[prop], args[tailarg], ">1")
			end
		end
		-- Handle the ...tailall variants.
		tailallarg = tailspec[1] .. "tailall"
		if args[tailallarg] then
			track(tailallarg)
			for _, prop in ipairs(tailforms) do
				append_note_all(forms, main_to_all_verb_forms[prop], args[tailallarg])
			end
		end
	end

	--handle overrides (formerly we only had past_pasv_part as a
	--general override, plus scattered main-form overrides in particular
	--conjugation classes)
	for _, all_forms in pairs(main_to_all_verb_forms) do
		local i = 0
		local orig_forms = {}
		for _, form in ipairs(all_forms) do
			if forms[form] then
				table.insert(orig_forms, forms[form])
			end
		end
		for _, form in ipairs(all_forms) do
			i = i + 1
			-- If we auto-generated the past passive participle in order to
			-- check for irregular overrides, make sure to erase any such
			-- participles that weren't overridden. This happens for example
			-- in обнять, where there are two automatically generated past
			-- passive participles but a single ppp=о́внятый override.
			local override = args[form] or (
				data.ppp_auto_generated and rfind(form, "^past_pasv_part") and "-"
			)
			if override then
				forms[form] = parse_and_stress_override(form, override,
					forms[form], orig_forms)
			elseif i == 1 then
				forms[form] = forms[form] or ""
			end
		end
	end
end

-- Finish generating the forms; primarily, clear out unused forms.
finish_generating_forms = function(forms, data)
	-- Convert any main form that's nil (meaning no forms at all corresponding
	-- to this main form) to the empty string.
	for main_form, _ in pairs(main_to_all_verb_forms) do
		if not forms[main_form] then
			forms[main_form] = ""
		end
	end

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

	-- Intransitive and reflexive verbs have no passive participles
	-- (unless has_prpp=y and/or has_ppp=y).
	if data.intr or data.refl then
		if not data.has_prpp then
			clear_form("pres_pasv_part")
		end
		if not data.has_ppp then
			clear_form("past_pasv_part")
		end
	end
	if data.refl then
		-- no past_adv_part_short for reflexive verbs
		clear_form("past_adv_part_short")
	end
	-- Impersonal verbs normally have no passive participles, but allow them
	-- if there's specifically an override. We only do this for the present
	-- passive participle because the past passive participle isn't inserted
	-- by default, and we still want +p to work, which doesn't currently set
	-- data.ppp_override.
	if data.impers and not data.prpp_override then
		clear_form("pres_pasv_part")
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
		clear_form("past_m_short")
		clear_form("past_f_short")
		clear_form("past_pl_short")
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

	--handle "none-" and "awkward-" prefixes (used especially for pres_pasv_part)
	local footnote_sym = nil
	for _, all_forms in pairs(main_to_all_verb_forms) do
		local i = 0
		for _, form in ipairs(all_forms) do
			i = i + 1
			if forms[form] then
				local formru, formtr = extract_russian_tr(forms[form])
				if rfind(formru, "^none%-") then
					if i == 1 then
						forms[form] = ""
					else
						forms[form] = nil
					end
				elseif rfind(formru, "^awkward%-") then
					if not footnote_sym then
						footnote_sym = next_note_symbol(data)
						ut.insert_if_not(data.internal_notes, footnote_sym .. " Rare and awkward.")
					end
					forms[form] = {rsub(formru, "^awkward%-", "") .. footnote_sym,
						formtr and rsub(formtr, "^awkward%-", "") .. footnote_sym}
				end
			end
		end
	end

	--Insert footnote for IRREG symbol if present.
	for _, all_forms in pairs(main_to_all_verb_forms) do
		for _, form in ipairs(all_forms) do
			if forms[form] then
				local formru, formtr = extract_russian_tr(forms[form])
				if rfind(formru, IRREG) then
					ut.insert_if_not(data.internal_notes, IRREG .. " Irregular.")
				end
			end
		end
	end
end

local accel_forms = {
  -- present tense
  pres_1sg = "1|s|pres|ind",
  pres_2sg = "2|s|pres|ind",
  pres_3sg = "3|s|pres|ind",
  pres_1pl = "1|p|pres|ind",
  pres_2pl = "2|p|pres|ind",
  pres_3pl = "3|p|pres|ind",
  -- future tense
  futr_1sg = "1|s|fut|ind",
  futr_2sg = "2|s|fut|ind",
  futr_3sg = "3|s|fut|ind",
  futr_1pl = "1|p|fut|ind",
  futr_2pl = "2|p|fut|ind",
  futr_3pl = "3|p|fut|ind",
  -- imperative
  impr_sg = "2|s|imp",
  impr_pl = "2|p|imp",
  -- past
  past_m = "m|s|past|ind",
  past_f = "f|s|past|ind",
  past_n = "n|s|past|ind",
  past_pl = "p|past|ind",
  past_m_short = "short|m|s|past|ind",
  past_f_short = "short|f|s|past|ind",
  past_n_short = "short|n|s|past|ind",
  past_pl_short = "short|p|past|ind",
  -- active participles
  pres_actv_part = "pres|act|part",
  past_actv_part = "past|act|part",
  -- passive participles
  pres_pasv_part = "pres|pass|part",
  past_pasv_part = "past|pass|part",
  -- adverbial participles
  pres_adv_part = "pres|adv|part",
  past_adv_part = "past|adv|part",
  past_adv_part_short = "short|past|adv|part",
  -- infinitive
  infinitive = "inf",
}

-- Make the table
make_table = function(forms, title, perf, intr, impers, notes, internal_notes, old)
	local infinitives = {}
	for _, form in ipairs(main_to_all_verb_forms["infinitive"]) do
		local infinitive = forms[form]
		if infinitive then
			local inf, inf_tr = extract_russian_tr(forms[form])
			if inf ~= "-" then
				ut.insert_if_not(infinitives, inf)
			end
		end
	end

	-- Group forms together for a given key and combine adjacent forms with the same
	-- Russian (they should always have different translits). Take care not to introduce
	-- manual translit unnecessarily.
	local grouped_forms = {}
	for dispform, sourceforms in pairs(disp_verb_form_map) do
		local entry = {}
		for _, form in ipairs(sourceforms) do
			local ru, tr = extract_russian_tr(forms[form])
			-- check for empty strings, dashes and nil's
			if ru and ru ~= "" and ru ~= "-" and ru ~= "&mdash;" then
				if #entry > 0 then
					local lastru, lasttr = extract_russian_tr(entry[#entry])
					if lastru == ru then
						if not lasttr and not tr or lasttr == tr then
							error("Russian form " .. ru .. " is duplicated, probably due to a duplicative override")
						end
						lasttr = lasttr or com.translit(lastru)
						tr = tr or com.translit(ru)
						entry[#entry] = {ru, lasttr .. " ''or'' " .. tr}
					else
						table.insert(entry, {ru, tr})
					end
				else
					table.insert(entry, {ru, tr})
				end
			end
		end
		grouped_forms[dispform] = entry
	end

	local title = (old and "Pre-reform conjugation" or "Conjugation") .. (#infinitives == 0 and "" or
		" of <span lang=\"ru\" class=\"Cyrl\">''" .. table.concat(infinitives, ", ") .. "''</span>") ..
		(title and " (" .. title .. ")" or "")

	local function add_links(ru, rusuf, runotes, tr, trnotes, accel)
		local ruspan
		if old then
			ruspan = m_links.full_link({lang = lang, term = com.remove_jo(ru), accel = accel,
				alt = not ru:find("[[", 1, true) and ru, tr = "-"})
		else
			ruspan = m_links.full_link({lang = lang, term = ru, accel = accel, tr = "-"})
		end
		if rusuf ~= "" then
			rusuf = "<span lang=\"ru\" class=\"Cyrl\">" .. rusuf .. "</span>"
		end
		return ruspan .. rusuf .. runotes .. "<br/>" .. require("Module:script utilities").tag_translit(tr .. trnotes, lang, "default", 'style="color: #888"')
	end

	-- NOTE: No need to check for multiple infinitives because the accel system
	-- doesn't support multiple lemmas.
	local lemma, lemmatr = extract_russian_tr(forms["infinitive"])

	-- check for empty strings, dashes and nil's
	if lemma and lemma ~= "" and lemma ~= "-" and lemma ~= "&mdash;" then
		lemma, _ = m_table_tools.separate_notes(lemma)
		if lemmatr then
			lemmatr, _ = m_table_tools.separate_notes(lemmatr)
		end
	else
		-- In case the lemma is an empty string or dash, set to nil so we don't
		-- set a lemma in the accelerator and fall back to the page name.
		lemma = nil
		lemmatr = nil
	end

	-- Convert to displayed form
	local disp = {}
	for key, entry in pairs(grouped_forms) do
		for i, form in ipairs(entry) do
			local ru, origtr = extract_russian_tr(form)
			local tr = origtr or ru and com.translit(ru)
			local ruentry, runotes = m_table_tools.get_notes(ru)
			local trentry, trnotes = m_table_tools.get_notes(tr)
			local accel_form = accel_forms[key]
			if not accel_form then
				error("Unrecognized key " .. key .. " when looking up accelerator form")
			end
			local accel
			if origtr and origtr:find(" ''or'' ") then
				-- Multiple translits for a given Russian term.
				-- FIXME! Support this.
				accel = nil
			else
				accel = { form = accel_form, translit = origtr,
					lemma = lemma, lemma_translit = lemmatr}
			end

			if rfind(key, "^futr") then
				-- Add link to first word (form of 'to be')
				tobe, inf = rmatch(ruentry, "^([^ ]*) ([^ ]*)$")
				if tobe then
					-- No accelerators for imperfective future, as it's just the future of "to be"
					-- plus the infinitive.
					entry[i] = add_links(tobe, " " .. inf, runotes, trentry, trnotes, nil)
				else
					entry[i] = add_links(ruentry, "", runotes, trentry, trnotes, accel)
				end
			else
				entry[i] = add_links(ruentry, "", runotes, trentry, trnotes, accel)
			end
		end
		disp[key] = table.concat(entry, ",<br/>")
		if disp[key] == "" then
			disp[key] = "&mdash;"
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
	table.insert(all_notes, 1,
		"Note: For declension of participles, see their entries. Adverbial participles are indeclinable.")
	notes_text = table.concat(all_notes, "<br />") .. "\n"

	return require("Module:TemplateStyles")("Module:ru-verb/style.css") ..
[=[<div class="NavFrame" style="width:49.6em;">
<div class="NavHead" style="text-align:left; background:#e0e0ff;">]=] .. title .. [=[</div>
<div class="NavContent">
{| class="inflection inflection-ru inflection-verb inflection-table"
|+ ]=] .. notes_text .. [=[
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
! style="background-color: #ffffe0;" | [[средний род|neuter]] (<span lang="ru" class="Cyrl">оно́</span>)
| ]=] .. disp.past_n .. [=[

|}
</div>
</div>]=]
end

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
