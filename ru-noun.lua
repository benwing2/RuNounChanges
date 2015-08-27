--[=[
	This module contains functions for creating inflection tables for Russian
	nouns.

	Arguments:
		1: stress pattern number, or multiple numbers separated by commas
		2: stem
		3: declension type (usually just the ending)
		4: suffixless form (optional, default = stem)
		a: animacy (a = animate, i = inanimate, b = both, otherwise inanimate)
		n: number restriction (p = plural only, s = singular only, otherwise both)
		pl: special plural stem (optional, default = stem)
		barepl: suffixless plural stem (optional, default = argument 4 if explicitly given, else plural stem)

	Case abbreviations:
		nom: nominative
		gen: genitive
		dat: dative
		acc: accusative
		ins: instrumental
		pre: prepositional
		par: partitive
		loc: locative
		voc: vocative
]=]--

local m_utilities = require("Module:utilities")
local ut = require("Module:utils")
local m_links = require("Module:links")
local com = require("Module:ru-common")
local strutils = require("Module:string utilities")
local m_table_tools = require("Module:table tools")
local m_debug = require("Module:debug")

local export = {}

local lang = require("Module:languages").getByCode("ru")

local u = mw.ustring.char
local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local ulower = mw.ustring.lower
local usub = mw.ustring.sub

local AC = u(0x0301) -- acute =  ́

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

function track(page)
	m_debug.track("ru-noun/" .. page)
	return true
end

-- Old-style declensions.
local declensions_old = {}
-- New-style declensions; computed automatically from the old-style ones.
local declensions = {}
-- Auto-detection functions, old-style, for a given input declension.
-- It is passed two params, (stressed) STEM and STRESS_PATTERN, and should
-- return the ouput declension.
local detect_decl_old = {}
-- Auto-detection functions, new style; computed automatically from the
-- old-style ones.
local detect_decl = {}
local sibilant_suffixes = {}
local stress_patterns = {}
-- Set of patterns with stressed genitive plural.
local stressed_gen_pl_patterns = {}
-- Set of patterns with stressed prepositional singular.
local stressed_pre_sg_patterns = {}
-- List of all cases, excluding loc/par/voc.
local decl_cases
-- List of all cases, including loc/par/voc.
local cases
-- Type of trailing letter, for tracking purposes
local trailing_letter_type

local function tracking_code(stress_arg, stress, decl_class,
		real_decl_class, args)
	decl_class = decl_class or ""
	real_decl_class = real_decl_class or ""
	local hint = ulower(usub(com.remove_accents(args.stem), -1))
	local hint_type_list = trailing_letter_type[hint] or {"hard-cons", "cons"}
	if real_decl_class == decl_class then
		real_decl_class = nil
	end
	local function dotrack(prefix)
		-- unclear if this is needed: track("stress/" .. stress_arg)
		track(stress)
		track(decl_class)
		track(decl_class .. "/" .. stress)
		if real_decl_class then
			track(real_decl_class)
			track(real_decl_class .. "/" .. stress)
		end
		for _, hint_type in ipairs(hint_type_list) do
			track(hint_type)
			track(decl_class .. "/" .. hint_type)
			if real_decl_class then
				track(real_decl_class .. "/" .. hint_type)
			end
		end
		if args.pl ~= args.stem then
			track("irreg-pl")
		end
	end
	dotrack("")
	if args.bare ~= args.stem then
		track("reducible-stem")
		dotrack("reducible-stem/")
	end
	if rfind(args.stem, "и́?н$") and (decl_class == "" or decl_class == "-") then
		track("irregular-in")
	end
	if rfind(args.stem, "[еёо]́?нок$") and (decl_class == "" or decl_class == "-") then
		track("irregular-onok")
	end
	if args.pltail then
		track("pltail")
	end
	if args.sgtail then
		track("sgtail")
	end
	for case in pairs(cases) do
		if args[case] then
			track("irreg/" .. case)
			-- questionable use: dotrack("irreg/" .. case .. "/")
		end
	end
end

local function do_show(frame, old)
	PAGENAME = mw.title.getCurrentTitle().text
	SUBPAGENAME = mw.title.getCurrentTitle().subpageText
	NAMESPACE = mw.title.getCurrentTitle().nsText

	local args = {}
	--Clone parent's args while also assigning nil to empty strings.
	for pname, param in pairs(frame:getParent().args) do
		if param == "" then args[pname] = nil
		else args[pname] = param
		end
	end

	-- FIXME: Eliminate barepl, convert pl to 5th numbered arg
	if args["barepl"] or args["barepl2"] or args["barepl3"] or args["barepl4"] or args["barepl5"] then
		track("barepl")
	end
	if args["pl"] or args["pl2"] or args["pl3"] or args["pl4"] or args["pl5"] then
		track("pl")
	end
	
	-- Gather arguments into an array of STEM_SET objects, containing
	-- (potentially) elements 1, 2, 3, 4, 'pl', 'barepl' where 1, 2, 3, 4
	-- correspond to stress pattern, stem, declension type and bare stem and
	-- come from consecutive numbered parameters, and 'pl' and 'barepl' come
	-- from parameters named 'pl', 'pl2', 'pl3', ... and similarly for
	-- 'barepl'. Sets of stem parameters are separated by the word "or".
	local stem_sets = {}
	-- Find maximum-numbered arg, allowing for holes
	local max_arg = 0
	for k, v in pairs(args) do
		if type(k) == "number" and k > max_arg then
			max_arg = k
		end
	end
	-- Now gather the arguments.
	local offset = 0
	local stem_set = {}
	for i=1,(max_arg + 1) do
		if args[i] == "or" or i == max_arg + 1 then
			local setnum = #stem_sets + 1
			stem_set.pl = args["pl" .. (setnum == 1 and "" or setnum)]
			stem_set.barepl = args["barepl" .. (setnum == 1 and "" or setnum)]
			table.insert(stem_sets, stem_set)
			stem_set = {}
			offset = i
		else
			stem_set[i - offset] = args[i]
		end
	end
	-- Gather any remaining stem specs composed only of plN and/or bareplN.
	i = #stem_sets + 1
	assert(i > 1)
	while true do
		local pl = args["pl" .. i]
		local barepl = args["barepl" .. i]
		if not pl and not barepl then
			break
		end
		table.insert(stem_sets, {pl=pl, barepl=barepl})
		i = i + 1
	end

	-- Initialize non-stem-specific arguments.
	args.a = args.a and string.sub(args.a, 1, 1) or "i"
	args.n = args.n and string.sub(args.n, 1, 1) or nil
	args.forms = {}
	args.old = old
	-- HACK: Escape * at beginning of line so it doesn't show up
	-- as a list entry. Many existing templates use * for footnotes.
	-- FIXME: We should maybe do this in {{ru-decl-noun}} instead.
	if args.notes then
		args.notes = rsub(args.notes, "^%*", "&#42;")
	end

	local decls = old and declensions_old or declensions
	local detectfuns = old and detect_decl_old or detect_decl

	-- Default arguments. After the first stem set is processed, we set the
	-- defaults based on that set.
	local default_stress = "1"
	local default_decl = ""
	local default_stem = SUBPAGENAME
	local default_bare, default_pl, default_barepl
	local first = true

	if #stem_sets > 1 then
		track("multiple-stems")
	end

	for _, stem_set in ipairs(stem_sets) do
		local stress_arg = stem_set[1] or default_stress
		local decl_class = stem_set[3] or default_decl
		local stem_specified = stem_set[2] or first
		args.stem = stem_set[2] or default_stem
		if ut.contains({"", "m", "f", "n"}, decl_class) then
			args.stem, decl_class = detect_stem_type(args.stem, decl_class)
		end
		-- For bare, pl and barepl, we default to other specified arguments,
		-- falling back to the stem if specified or we're handling the
		-- first stem set; as a last resort, use the defaults taken from the
		-- first stem set.
		args.bare = stem_set[4] or stem_specified and args.stem or default_bare
		args.pl = stem_set.pl or stem_specified and args.stem or default_pl
		args.barepl = stem_set.barepl or stem_set[4] or stem_set.pl or
			stem_specified and args.stem or default_barepl
		if first then
			default_stress = stress_arg
			default_decl = decl_class
			default_stem = args.stem
			default_bare = args.bare
			default_pl = args.pl
			default_barepl = args.barepl
		end
		args.ustem = com.make_unstressed_once(args.stem)
		-- unused: args.ubare = com.make_unstressed_once(args.bare)
		args.upl = com.make_unstressed_once(args.pl)
		-- unused: args.ubarepl = com.make_unstressed_once(args.barepl)
		args.hint = ulower(usub(args.stem, -1))

		if rfind(stress_arg, ",") then
			track("multiple-stress-patterns")
		end

		-- Loop over stress patterns in case more than one given.
		for _, stress in ipairs(rsplit(stress_arg, ",")) do
			if not stress_patterns[stress] then
				error("Unrecognized stress pattern " .. stress)
			end
			local sub_decl_classes
			-- Loop over declension classes (we may have two of them, one for
			-- singular and one for plural, in the case of a mixed declension
			-- class of the form SGDECL/PLDECL).
			if rfind(decl_class, "/") then
				track("mixed-decl")
				local indiv_decl_classes = rsplit(decl_class, "/")
				if #indiv_decl_classes ~= 2 then
					error("Mixed declensional class " .. decl_class
						.. "needs exactly two classes, singular and plural")
				end
				sub_decl_classes = {{indiv_decl_classes[1], "sg"}, {indiv_decl_classes[2], "pl"}}
			else
				sub_decl_classes = {{decl_class}}
			end
			for _,decl_class_spec in ipairs(sub_decl_classes) do
				-- We may resolve the user-specified declension class into a
				-- more specific variant depending on the properties of the stem
				-- and/or stress pattern. We use detection functions to do this.
				local orig_decl_class = decl_class_spec[1]
				local number = decl_class_spec[2]
				local real_decl_class = orig_decl_class
				-- Repeatedly resolve a decl class into a more specific one
				-- until nothing changes. We do this so that, e.g., the blank
				-- class can resolve to class "-" (for masculine stems ending
				-- in a consonant), which can resolve in turn to class "-sib"
				-- (for masculine stems ending in a sibilant) or "-normal"
				-- (for non-sibilant stems).
				while true do
					local resolved_decl_class = detectfuns[real_decl_class] and
						detectfuns[real_decl_class](args.stem, stress) or real_decl_class
					if real_decl_class == resolved_decl_class then
						break
					end
					real_decl_class = resolved_decl_class
				end
				if not decls[real_decl_class] then
					if real_decl_class ~= orig_decl_class then 
						error("Unrecognized declension class " .. orig_decl_class .. " (mapped to " .. real_decl_class .. ")")
					else
						error("Unrecognized declension class " .. orig_decl_class)
					end
				end
				tracking_code(stress_arg, stress, orig_decl_class, real_decl_class, args)
				do_stress_pattern(stress_patterns[stress], args,
					decls[real_decl_class], number)
			end
		end
	end

	handle_forms_and_overrides(args)

	return make_table(args)
end

-- The main entry point for modern declension tables.
function export.show(frame)
	return do_show(frame, false)
end

-- The main entry point for old declension tables.
function export.show_old(frame)
	return do_show(frame, true)
end

----------------- Declension helper functions -----------------

local function old_to_new(v)
	v = rsub(v, "ъ$", "")
	v = rsub(v, "^ъ", "")
	v = rsub(v, "і", "и")
	v = rsub(v, "ѣ", "е")
	return v
end

-- Function to convert old detect_decl function to new one
local function old_detect_decl_to_new(ofunc)
	return function(stem, stress)
		return old_to_new(ofunc(stem, stress))
	end
end

-- Attempt to detect the type of the stem (= including ending) based
-- on its ending, separating off the base and the ending. DECL is the
-- value passed in and might be "", "m" or "f"; the latter are necessary
-- when dealing with -ь stems.
function detect_stem_type(stem, decl)
	base, ending = rmatch(stem, "^(.*)([еЕ]́)$")
	if base then
		return base, ulower(ending)
	end
	base = rmatch(stem, "^(.*[шщчжцШЩЧЖЦ])[еЕ]$") -- unaccented
	if base then
		return base, "о"
	end
	base, ending = rmatch(stem, "^(.*)([ёоЁО]́?[нН][оО][кК][ъЪ]?)$")
	if base then
		return base, com.remove_accents(ulower(ending))
	end
	base, ending = rmatch(stem, "^(.*)([мМ][яЯ])́?$")
	if base then
		-- FIXME: What about мя-1? Maybe it's rare enough that we
		-- don't have to worry about it?
		return base, ending
	end
	base, ending = rmatch(stem, "^(.*)([ьЬ][яеёЯЕЁ])́?$")
	if base then
		return base, ulower(ending)
	end
	base, ending = rmatch(stem, "^(.*)([йаяеоёъЙАЯЕОЁЪ])́?$")
	if base then
		return base, ulower(ending)
	end
	base = rmatch(stem, "^(.*)[ьЬ]$")
	if base then
		if decl == "m" or decl == "f" then
			return base, "ь-" .. decl
		else
			error("Need to specify decl m or f with stem in -ь: ".. stem)
		end
	end
	if rfind(stem, "[уыэюиіѣѵУЫЭЮИІѢѴ]́?$") then
		error("Don't know how to decline stem ending in this type of vowel: " .. stem)
	end
	-- FIXME: What about -ин?
	return stem, "-"
end

--------------------------------------------------------------------------
--                      Second-declension masculine                     --
--------------------------------------------------------------------------

----------------- Masculine hard -------------------

-- Normal hard-masculine declension, ending in a hard consonant
-- (ending in -ъ, old-style).
declensions_old["ъ-normal"] = {
	["nom_sg"] = "ъ",
	["gen_sg"] = "а́",
	["dat_sg"] = "у́",
	["acc_sg"] = nil,
	["ins_sg"] = "о́мъ",
	["pre_sg"] = "ѣ́",
	["nom_pl"] = "ы́",
	["gen_pl"] = "о́въ",
	["dat_pl"] = "а́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "а́ми",
	["pre_pl"] = "а́хъ",
}

-- Hard-masculine declension ending in a sibilant (plus -ъ, old-style).
-- Has genitive plural in -е́й.
declensions_old["ъ-sib"] = mw.clone(declensions_old["ъ-normal"])
declensions_old["ъ-sib"]["gen_pl"] = "е́й"

-- User-facing declension type "-" (old-style "ъ");
-- mapped to "-normal" (old-style "ъ-normal") or "-sib" (old-style "ъ-sib")
detect_decl_old["ъ"] = function(stem, stress)
	if sibilant_suffixes[ulower(usub(stem, -1))] then
		return "ъ-sib"
	else
		return "ъ-normal"
	end
end

-- Normal mapping of old ъ would be "" (blank), but we call it "-" so we
-- have a way of referring to it without defaulting if need be (e.g. in the
-- second stem of a word where the first stem has a different decl class),
-- and eventually want to make "" (blank) auto-detect the class.
detect_decl["-"] = old_detect_decl_to_new(detect_decl_old["ъ"])
-- User-facing declension type ""; currently same as "-" (old-style "ъ").
-- FIXME: Should allow the nom. sg. to be given and auto-detect the decl
-- as much as possible.
detect_decl_old[""] = detect_decl_old["ъ"]

----------------- Masculine hard, irregular plural -------------------

-- Normal hard-masculine declension, ending in a hard consonant
-- (ending in -ъ, old-style), with irreg nom pl -а.
declensions_old["ъ-а-normal"] = mw.clone(declensions_old["ъ-normal"])
declensions_old["ъ-а-normal"]["nom_pl"] = "а́"

-- Hard-masculine declension ending in a sibilant (plus -ъ, old-style),
-- with irreg nom pl -а. Has genitive plural in -е́й.
declensions_old["ъ-а-sib"] = mw.clone(declensions_old["ъ-а-normal"])
declensions_old["ъ-а-sib"]["gen_pl"] = "е́й"

-- User-facing declension type "-а" (old-style "ъ-а");
-- mapped to "ъ-а-normal" or "ъ-а-sib"
detect_decl_old["ъ-а"] = function(stem, stress)
	if sibilant_suffixes[ulower(usub(stem, -1))] then
		return "ъ-а-sib"
	else
		return "ъ-а-normal"
	end
end

-- Normal hard-masculine declension, ending in a hard consonant
-- (ending in -ъ, old-style), with irreg soft pl -ья.
-- Differs from the normal declension throughout the plural.
declensions_old["ъ-ья-normal"] = {
	["nom_sg"] = "ъ",
	["gen_sg"] = "а́",
	["dat_sg"] = "у́",
	["acc_sg"] = nil,
	["ins_sg"] = "о́мъ",
	["pre_sg"] = "ѣ́",
	["nom_pl"] = "ья́",
	["gen_pl"] = "ьёвъ",
	["dat_pl"] = "ья́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "ья́ми",
	["pre_pl"] = "ья́хъ",
}

-- Same as previous, ending in a sibilant (plus -ъ, old-style).
-- Has genitive plural in -е́й.
declensions_old["ъ-ья-sib"] = mw.clone(declensions_old["ъ-ья-normal"])
declensions_old["ъ-ья-sib"]["gen_pl"] = "е́й"

-- User-facing declension type "-ья" (old-style "ъ-ья");
-- mapped to "ъ-ья-normal" or "ъ-ья-sib"
detect_decl_old["ъ-ья"] = function(stem, stress)
	if sibilant_suffixes[ulower(usub(stem, -1))] then
		return "ъ-ья-sib"
	else
		return "ъ-ья-normal"
	end
end

----------------- Masculine hard, suffixed, irregular plural -------------------

declensions_old["инъ"] = {
	["nom_sg"] = "и́нъ",
	["gen_sg"] = "и́на",
	["dat_sg"] = "и́ну",
	["acc_sg"] = nil,
	["ins_sg"] = "и́номъ",
	["pre_sg"] = "и́нѣ",
	["nom_pl"] = "е́",
	["gen_pl"] = "ъ",
	["dat_pl"] = "а́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "а́ми",
	["pre_pl"] = "а́хъ",
}

declensions_old["ёнокъ"] = {
	["nom_sg"] = "ёнокъ",
	["gen_sg"] = "ёнка",
	["dat_sg"] = "ёнку",
	["acc_sg"] = nil,
	["ins_sg"] = "ёнкомъ",
	["pre_sg"] = "ёнкѣ",
	["nom_pl"] = "я́та",
	["gen_pl"] = "я́т",
	["dat_pl"] = "я́тамъ",
	["acc_pl"] = nil,
	["ins_pl"] = "я́тами",
	["pre_pl"] = "я́тахъ",
}

declensions_old["онокъ"] = declensions_old["ёнокъ"]
declensions_old["енокъ"] = declensions_old["ёнокъ"]

----------------- Masculine soft -------------------

-- Normal soft-masculine declension in -ь
declensions_old["ь-m"] = {
	["nom_sg"] = "ь",
	["gen_sg"] = "я́",
	["dat_sg"] = "ю́",
	["acc_sg"] = nil,
	["ins_sg"] = "ёмъ",
	["pre_sg"] = "ѣ́",
	["nom_pl"] = "и́",
	["gen_pl"] = "е́й",
	["dat_pl"] = "я́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "я́ми",
	["pre_pl"] = "я́хъ",
}

-- Soft-masculine declension in -ь with irreg nom pl -я
declensions_old["ь-я"] = mw.clone(declensions_old["ь-m"])
declensions_old["ь-я"]["nom_pl"] = "я́"

----------------- Masculine palatal -------------------

-- Normal masculine declension in palatal -й
declensions_old["й-normal"] = {
	["nom_sg"] = "й",
	["gen_sg"] = "я́",
	["dat_sg"] = "ю́",
	["acc_sg"] = nil,
	["ins_sg"] = "ёмъ",
	["pre_sg"] = "ѣ́",
	["nom_pl"] = "и́",
	["gen_pl"] = "ёвъ",
	["dat_pl"] = "я́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "я́ми",
	["pre_pl"] = "я́хъ",
}

-- Masculine declension in -ий (old -ій):
-- differs from normal in prep sg
declensions_old["(і)й"] = mw.clone(declensions_old["й-normal"])
declensions_old["(і)й"]["pre_sg"] = "и́"

-- User-facing declension type "й"; mapped to "й-normal" or "(і)й"
detect_decl_old["й"] = function(stem, stress)
	if rfind(stem, "[іи]" .. AC .. "?$") then
		return "(і)й"
	else
		return "й-normal"
	end
end

--------------------------------------------------------------------------
--                       First-declension feminine                      --
--------------------------------------------------------------------------

----------------- Feminine hard -------------------

-- Normal hard-feminine declension in -а
declensions_old["а-normal"] = {
	["nom_sg"] = "а́",
	["gen_sg"] = "ы́",
	["dat_sg"] = "ѣ́",
	["acc_sg"] = "у́",
	["ins_sg"] = {"о́й", "о́ю"},
	["pre_sg"] = "ѣ́",
	["nom_pl"] = "ы́",
	["gen_pl"] = "ъ",
	["dat_pl"] = "а́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "а́ми",
	["pre_pl"] = "а́хъ",
}

-- Special case: Hard-feminine declension in sibilant ending with 
-- stressed genitive plural. Has special gen pl -е́й.
declensions_old["а-sib-2"] = mw.clone(declensions_old["а-normal"])
declensions_old["а-sib-2"]["gen_pl"] = "е́й"

-- User-facing declension type "а"; mapped to "а-normal" or "а-sib-2"
detect_decl_old["а"] = function(stem, stress)
	if sibilant_suffixes[ulower(usub(stem, -1))] and stressed_gen_pl_patterns[stress] then
		return "а-sib-2"
	else
		return "а-normal"
	end
end

----------------- Feminine soft -------------------

-- Normal soft-feminine declension in -я
declensions_old["я-normal"] = {
	["nom_sg"] = "я́",
	["gen_sg"] = "и́",
	["dat_sg"] = "ѣ́",
	["acc_sg"] = "ю́",
	["ins_sg"] = {"ёй", "ёю"},
	["pre_sg"] = "ѣ́",
	["nom_pl"] = "и́",
	["gen_pl"] = "й",
	["dat_pl"] = "я́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "я́ми",
	["pre_pl"] = "я́хъ",
}

-- Soft-feminine declension in -ия (old -ія):
-- differs from normal in dat sg and prep sg
declensions_old["(і)я"] = mw.clone(declensions_old["я-normal"])
declensions_old["(і)я"]["dat_sg"] = "и́"
declensions_old["(і)я"]["pre_sg"] = "и́"

-- User-facing declension type "я"; mapped to "я-normal" or "(і)я"
detect_decl_old["я"] = function(stem, stress)
	if rfind(stem, "[іи]" .. AC .. "?$") then
		return "(і)я"
	else
		return "я-normal"
	end
end

-- Soft-feminine declension in -ья, with unstressed genitive plural -ий.
-- Almost like ь + -я endings except for genitive plural.
declensions_old["ья-1"] = {
	["nom_sg"] = "ья́",
	["gen_sg"] = "ьи́",
	["dat_sg"] = "ьѣ́",
	["acc_sg"] = "ью́",
	["ins_sg"] = {"ьёй", "ьёю"},
	["pre_sg"] = "ьѣ́",
	["nom_pl"] = "ьи́",
	["gen_pl"] = "ий",
	["dat_pl"] = "ья́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "ья́ми",
	["pre_pl"] = "ья́хъ",
}

-- Soft-feminine declension in -ья, with stressed genitive plural -е́й.
declensions_old["ья-2"] = mw.clone(declensions_old["ья-1"])
-- circumflex accent is a signal that forces stress, particularly
-- in accent pattern 4.
declensions_old["ья-2"]["gen_pl"] = "е̂й"

-- User-facing declension type "ья"
detect_decl_old["ья"] = function(stem, stress)
	if stressed_gen_pl_patterns[stress] or stress == "4" or stress == "4*" then
		return "ья-2"
	else
		return "ья-1"
	end
end

--------------------------------------------------------------------------
--                       Second-declension neuter                       --
--------------------------------------------------------------------------

----------------- Neuter hard -------------------

-- Normal hard-neuter declension in -о
declensions_old["о"] = {
	["nom_sg"] = "о́",
	["gen_sg"] = "а́",
	["dat_sg"] = "у́",
	["acc_sg"] = "о́",
	["ins_sg"] = "о́мъ",
	["pre_sg"] = "ѣ́",
	["nom_pl"] = "а́",
	["gen_pl"] = "ъ",
	["dat_pl"] = "а́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "а́ми",
	["pre_pl"] = "а́хъ",
}

-- Hard-neuter declension in -о with irreg nom pl -и
declensions_old["о-и"] = mw.clone(declensions_old["о"])
declensions_old["о-и"]["nom_pl"] = "ы́"

declensions_old["о-ы"] = declensions_old["о-и"]

-- Normal hard-neuter declension in -о with irreg soft pl -ья;
-- differs throughout the plural from normal -о.
declensions_old["о-ья-normal"] = {
	["nom_sg"] = "о́",
	["gen_sg"] = "а́",
	["dat_sg"] = "у́",
	["acc_sg"] = "о́",
	["ins_sg"] = "о́мъ",
	["pre_sg"] = "ѣ́",
	["nom_pl"] = "ья́",
	["gen_pl"] = "ьёвъ",
	["dat_pl"] = "ья́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "ья́ми",
	["pre_pl"] = "ья́хъ",
}

-- Same as previous, stem ending in a sibilant.
-- Has genitive plural in -е́й. (FIXME, do any such words occur?)
declensions_old["о-ья-sib"] = mw.clone(declensions_old["о-ья-normal"])
declensions_old["о-ья-sib"]["gen_pl"] = "е́й"

-- User-facing declension type "о-ья"; mapped to "о-ья-normal" or "о-ья-sib"
detect_decl_old["о-ья"] = function(stem, stress)
	if sibilant_suffixes[ulower(usub(stem, -1))] then
		return "о-ья-sib"
	else
		return "о-ья-normal"
	end
end

declensions_old["о-ья"] = {
}

----------------- Neuter soft -------------------

-- Normal soft-neuter declension in -е (stressed -ё)
declensions_old["е-normal"] = {
	["nom_sg"] = "ё",
	["gen_sg"] = "я́",
	["dat_sg"] = "ю́",
	["acc_sg"] = "ё",
	["ins_sg"] = "ёмъ",
	["pre_sg"] = "ѣ́",
	["nom_pl"] = "я́",
	["gen_pl"] = "е́й",
	["dat_pl"] = "я́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "я́ми",
	["pre_pl"] = "я́хъ",
}

-- Soft-neuter declension in unstressed -ие (old -іе):
-- differs from normal in prep sg and gen pl
declensions_old["(і)е-1"] = mw.clone(declensions_old["е-normal"])
declensions_old["(і)е-1"]["pre_sg"] = "и́"
declensions_old["(і)е-1"]["gen_pl"] = "й"

-- Soft-neuter declension in stressed -иё (old -іё)
-- differs from normal in gen pl only
declensions_old["(і)е-2"] = mw.clone(declensions_old["е-normal"])
declensions_old["(і)е-2"]["gen_pl"] = "й"

-- User-facing declension type "е"; mapped to "е-normal", "(і)е-1" or "(і)е-2"
detect_decl_old["е"] = function(stem, stress)
	if rfind(stem, "[іи]" .. AC .. "?$") then
		if stressed_pre_sg_patterns[stress] then
			return "(і)е-2"
		else
			return "(і)е-1"
		end
	else
		return "е-normal"
	end
end

-- User-facing declension type "ё" = "е"
detect_decl_old["ё"] = detect_decl_old["е"]

-- Rare soft-neuter declension in stressed -е́, normal variation
-- (e.g. муде́).
declensions_old["е́-normal"] = {
	["nom_sg"] = "е́",
	["gen_sg"] = "я́",
	["dat_sg"] = "ю́",
	["acc_sg"] = "е́",
	["ins_sg"] = "е́мъ",
	["pre_sg"] = "ѣ́",
	["nom_pl"] = "я́",
	["gen_pl"] = "е́й",
	["dat_pl"] = "я́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "я́ми",
	["pre_pl"] = "я́хъ",
}

-- Rare soft-neuter declension in -ие́ (old -іе́), cf. бытие́
declensions_old["(і)е́"] = mw.clone(declensions_old["е́-normal"])
declensions_old["(і)е́"]["pre_sg"] = "и́"
declensions_old["(і)е́"]["gen_pl"] = "й"

-- User-facing declension type "е́"
detect_decl_old["е́"] = function(stem, stress)
	if rfind(stem, "[іи]" .. AC .. "?$") then
		return "(і)е́"
	else
		return "е́-normal"
	end
end

-- Soft-neuter declension in unstressed -ье (stressed -ьё),
-- with unstressed genitive plural -ий.
declensions_old["ье-1"] = {
	["nom_sg"] = "ьё",
	["gen_sg"] = "ья́",
	["dat_sg"] = "ью́",
	["acc_sg"] = "ьё",
	["ins_sg"] = "ьёмъ",
	["pre_sg"] = "ьѣ́",
	["nom_pl"] = "ья́",
	["gen_pl"] = "ий",
	["dat_pl"] = "ья́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "ья́ми",
	["pre_pl"] = "ья́хъ",
}

-- Soft-neuter declension in unstressed -ье (stressed -ьё),
-- with stressed genitive plural -е́й.
declensions_old["ье-2"] = mw.clone(declensions_old["ье-1"])
declensions_old["ье-2"]["gen_pl"] = "е́й"

-- User-facing declension type "ье"
detect_decl_old["ье"] = function(stem, stress)
	if stressed_gen_pl_patterns[stress] then
		return "ье-2"
	else
		return "ье-1"
	end
end

-- User-facing declension type "ьё" = "ье"
detect_decl_old["ьё"] = detect_decl_old["ье"]

--------------------------------------------------------------------------
--                           Third declension                           --
--------------------------------------------------------------------------

declensions_old["ь-f"] = {
	["nom_sg"] = "ь",
	["gen_sg"] = "и́",
	["dat_sg"] = "и́",
	["acc_sg"] = "ь",
	["ins_sg"] = "ью", -- note no stress, will always trigger stem stress even in classes 2/4/6
	["pre_sg"] = "и́",
	["nom_pl"] = "и́",
	["gen_pl"] = "е́й",
	["dat_pl"] = "я́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "я́ми",
	["pre_pl"] = "я́хъ",
}

declensions_old["мя"] = {
	["nom_sg"] = "мя",
	["gen_sg"] = "мени",
	["dat_sg"] = "мени",
	["acc_sg"] = nil,
	["ins_sg"] = "менемъ",
	["pre_sg"] = "мени",
	["nom_pl"] = "мена́",
	["gen_pl"] = "мёнъ",
	["dat_pl"] = "мена́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "мена́ми",
	["pre_pl"] = "мена́хъ",
}

declensions_old["мя-1"] = {
	["nom_sg"] = "мя",
	["gen_sg"] = "мени",
	["dat_sg"] = "мени",
	["acc_sg"] = nil,
	["ins_sg"] = "менемъ",
	["pre_sg"] = "мени",
	["nom_pl"] = "мёна",
	["gen_pl"] = "мёнъ",
	["dat_pl"] = "мёнамъ",
	["acc_pl"] = nil,
	["ins_pl"] = "мёнами",
	["pre_pl"] = "мёнахъ",
}

--------------------------------------------------------------------------
--                              Invariable                              --
--------------------------------------------------------------------------

-- Invariable declension; no endings.
declensions_old["*"] = {
	["nom_sg"] = "",
	["gen_sg"] = "",
	["dat_sg"] = "",
	["acc_sg"] = "",
	["ins_sg"] = "",
	["pre_sg"] = "",
	["nom_pl"] = "",
	["gen_pl"] = "",
	["dat_pl"] = "",
	["acc_pl"] = "",
	["ins_pl"] = "",
	["pre_pl"] = "",
}

--------------------------------------------------------------------------
--                         Inflection functions                         --
--------------------------------------------------------------------------

local function clone_old_to_new(odecl)
	local ndecl = {}
	for k, v in pairs(odecl) do
		if type(v) == "table" then
			local new_entry = {}
			for _, i in ipairs(v) do
				table.insert(new_entry, old_to_new(i))
			end
			ndecl[k] = new_entry
		else
			ndecl[k] = old_to_new(v)
		end
	end
	return ndecl
end

-- populate declensions[] from declensions_old[]
for odecltype, odecl in pairs(declensions_old) do
	local ndecltype = old_to_new(odecltype)
	if not declensions[ndecltype] then
		declensions[ndecltype] = clone_old_to_new(odecl)
	end
end

-- populate detect_decl[] from detect_decl_old[]
for odeclfrom, ofunc in pairs(detect_decl_old) do
	local declfrom = old_to_new(odeclfrom)
	if not detect_decl[declfrom] then
		detect_decl[declfrom] = old_detect_decl_to_new(ofunc)
	end
end

local stressed_sibilant_rules = {
	["я"] = "а",
	["ы"] = "и",
	["ё"] = "о́",
	["ю"] = "у",
}

local stressed_c_rules = {
	["я"] = "а",
	["ё"] = "о́",
	["ю"] = "у",
}

local unstressed_sibilant_rules = {
	["я"] = "а",
	["ы"] = "и",
	["о"] = "е",
	["ю"] = "у",
}

local unstressed_c_rules = {
	["я"] = "а",
	["о"] = "е",
	["ю"] = "у",
}

local velar_rules = {
	["ы"] = "и",
}

local stressed_rules = {
	["ш"] = stressed_sibilant_rules,
	["щ"] = stressed_sibilant_rules,
	["ч"] = stressed_sibilant_rules,
	["ж"] = stressed_sibilant_rules,
	["ц"] = stressed_c_rules,
	["к"] = velar_rules,
	["г"] = velar_rules,
	["х"] = velar_rules,
}

local unstressed_rules = {
	["ш"] = unstressed_sibilant_rules,
	["щ"] = unstressed_sibilant_rules,
	["ч"] = unstressed_sibilant_rules,
	["ж"] = unstressed_sibilant_rules,
	["ц"] = unstressed_c_rules,
	["к"] = velar_rules,
	["г"] = velar_rules,
	["х"] = velar_rules,
}

local old_consonantal_suffixes = {
	["ъ"] = true,
	["ь"] = true,
	["й"] = true,
}

local consonantal_suffixes = {
	[""] = true,
	["ь"] = true,
	["й"] = true,
}

trailing_letter_type = {
	["ш"] = {"sibilant", "cons"},
	["щ"] = {"sibilant", "cons"},
	["ч"] = {"sibilant", "cons"},
	["ж"] = {"sibilant", "cons"},
	["ц"] = {"c", "cons"},
	["к"] = {"velar", "cons"},
	["г"] = {"velar", "cons"},
	["х"] = {"velar", "cons"},
	["ь"] = {"soft-cons", "cons"},
	["ъ"] = {"hard-cons", "cons"},
	["й"] = {"palatal", "cons"},
	["а"] = {"vowel", "hard-vowel"},
	["я"] = {"vowel", "soft-vowel"},
	["э"] = {"vowel", "hard-vowel"},
	["е"] = {"vowel", "soft-vowel"},
	["ѣ"] = {"vowel", "soft-vowel"},
	["и"] = {"i", "vowel", "soft-vowel"},
	["і"] = {"i", "vowel", "soft-vowel"},
	["ѵ"] = {"i", "vowel", "soft-vowel"},
	["ы"] = {"vowel", "hard-vowel"},
	["о"] = {"vowel", "hard-vowel"},
	["ё"] = {"vowel", "soft-vowel"},
	["у"] = {"vowel", "hard-vowel"},
	["ю"] = {"vowel", "soft-vowel"},
}

sibilant_suffixes = {
	["ш"] = true,
	["щ"] = true,
	["ч"] = true,
	["ж"] = true,
}

local function combine_stem_and_suffix(args, rules, stem, suf)
	local first = usub(suf, 1, 1)
	if rules then
		local conv = rules[first]
		if conv then
			local ending = usub(suf, 2)
			if args.old and conv == "и" and mw.ustring.find(ending, "^́?[аеёиійоуэюяѣ]") then
				conv = "і"
			end
			suf = conv .. ending
		end
	end
	return stem .. suf
end

local function attach_unstressed(args, case, suf)
	if suf == nil then
		return nil
	elseif rfind(suf, "̂") then -- if suf has circumflex accent, it forces stressed
		return attach_stressed(args, case, suf)
	end
	local is_pl = rfind(case, "_pl$")
	local old = args.old
	local stem = is_pl and args.pl or args.stem
	local barestem = is_pl and args.barepl or args.bare
	if old and old_consonantal_suffixes[suf] or not old and consonantal_suffixes[suf] then
		if rfind(barestem, old and "[йьъ]$" or "[йь]$") then
			return barestem
		else
			if suf == "й" or suf == "ь" then
				if rfind(barestem, "[аеёиіоуэюяѣ́]$") then
					suf = "й"
				else
					suf = "ь"
				end
			end
			return barestem .. suf
		end
	end
	suf = com.make_unstressed(suf)
	local rules = unstressed_rules[args.hint]
	return combine_stem_and_suffix(args, rules, stem, suf)
end

function attach_stressed(args, case, suf)
	if suf == nil then
		return nil
	end
 	-- circumflex forces stress even when the accent pattern calls for no stress
	suf = rsub(suf, "̂", "́")
	if not rfind(suf, "[ё́]") then -- if suf has no "ё" or accent marks
		return attach_unstressed(args, case, suf)
	end
	local is_pl = rfind(case, "_pl$")
	local old = args.old
	local stem = is_pl and args.upl or args.ustem
	local rules = stressed_rules[args.hint]
	return combine_stem_and_suffix(args, rules, stem, suf)
end

local function attach_with(args, case, suf, fun)
	if type(suf) == "table" then
		local tbl = {}
		for _, x in ipairs(suf) do
			for _, form in ipairs(attach_with(args, case, x, fun)) do
				table.insert(tbl, form)
			end
		end
		return tbl
	else
		return {fun(args, case, suf)}
	end
end

local function gen_form(args, decl, case, fun)
	if not args.forms[case] then
		args.forms[case] = {}
	end
	for _, form in ipairs(attach_with(args, case, decl[case], fun)) do
		ut.insert_if_not(args.forms[case], form)
	end
end

local attachers = {
	["+"] = attach_stressed,
	["-"] = attach_unstressed,
}

function do_stress_pattern(stress_pattern, args, decl, number)
	for case in pairs(decl_cases) do
		if not number or (number == "sg" and rfind(case, "_sg$")) or
			(number == "pl" and rfind(case, "_pl$")) then
			gen_form(args, decl, case, attachers[stress_pattern[case]])
		end
	end
end

stress_patterns["1"] = {
	nom_sg="-", gen_sg="-", dat_sg="-", acc_sg="-", ins_sg="-", pre_sg="-",
	nom_pl="-", gen_pl="-", dat_pl="-", acc_pl="-", ins_pl="-", pre_pl="-",
}

stress_patterns["2"] = {
	nom_sg="+", gen_sg="+", dat_sg="+", acc_sg="+", ins_sg="+", pre_sg="+",
	nom_pl="+", gen_pl="+", dat_pl="+", acc_pl="+", ins_pl="+", pre_pl="+",
}

stress_patterns["3"] = {
	nom_sg="-", gen_sg="-", dat_sg="-", acc_sg="-", ins_sg="-", pre_sg="-",
	nom_pl="+", gen_pl="+", dat_pl="+", acc_pl="+", ins_pl="+", pre_pl="+",
}

stress_patterns["4"] = {
	nom_sg="+", gen_sg="+", dat_sg="+", acc_sg="+", ins_sg="+", pre_sg="+",
	nom_pl="-", gen_pl="-", dat_pl="-", acc_pl="-", ins_pl="-", pre_pl="-",
}

stress_patterns["4*"] = {
	nom_sg="+", gen_sg="+", dat_sg="+", acc_sg="-", ins_sg="+", pre_sg="+",
	nom_pl="-", gen_pl="-", dat_pl="-", acc_pl="-", ins_pl="-", pre_pl="-",
}

stress_patterns["5"] = {
	nom_sg="-", gen_sg="-", dat_sg="-", acc_sg="-", ins_sg="-", pre_sg="-",
	nom_pl="-", gen_pl="+", dat_pl="+", acc_pl="+", ins_pl="+", pre_pl="+",
}

stress_patterns["6"] = {
	nom_sg="+", gen_sg="+", dat_sg="+", acc_sg="+", ins_sg="+", pre_sg="+",
	nom_pl="-", gen_pl="+", dat_pl="+", acc_pl="+", ins_pl="+", pre_pl="+",
}

stress_patterns["6*"] = {
	nom_sg="+", gen_sg="+", dat_sg="+", acc_sg="-", ins_sg="+", pre_sg="+",
	nom_pl="-", gen_pl="+", dat_pl="+", acc_pl="+", ins_pl="+", pre_pl="+",
}

stressed_gen_pl_patterns = {
	["2"] = true,
	["3"] = true,
	["5"] = true,
	["6"] = true,
	["6*"] = true,
}

stressed_pre_sg_patterns = {
	["2"] = true,
	["4"] = true,
	["4*"] = true,
	["6"] = true,
	["6*"] = true,
}

local after_titles = {
	["a"] = " (animate)",
	["i"] = " (inanimate)",
	["b"] = "",
}

local numbers = {
	["s"] = "singular",
	["p"] = "plural",
}

local form_temp = [=[{term}<br/><span style="color: #888">{tr}</span>]=]
local old_title_temp = [=[Pre-reform declension of <b lang="ru" class="Cyrl">{lemma}</b>]=]
local title_temp = [=[Declension of <b lang="ru" class="Cyrl">{lemma}</b>]=]

local partitive = nil
local locative = nil
local vocative = nil
local notes_template = nil
local templates = {}

-- cases that are declined normally instead of handled through overrides
decl_cases = {
	["nom_sg"] = true,
	["gen_sg"] = true,
	["dat_sg"] = true,
	["acc_sg"] = true,
	["ins_sg"] = true,
	["pre_sg"] = true,
	["nom_pl"] = true,
	["gen_pl"] = true,
	["dat_pl"] = true,
	["acc_pl"] = true,
	["ins_pl"] = true,
	["pre_pl"] = true,
}

-- all cases displayable or handleable through overrides
cases = {
	["nom_sg"] = true,
	["gen_sg"] = true,
	["dat_sg"] = true,
	["acc_sg"] = true,
	["ins_sg"] = true,
	["pre_sg"] = true,
	["nom_pl"] = true,
	["gen_pl"] = true,
	["dat_pl"] = true,
	["acc_pl"] = true,
	["ins_pl"] = true,
	["pre_pl"] = true,
	["par"] = true,
	["loc"] = true,
	["voc"] = true,
}

function handle_forms_and_overrides(args)
	for case in pairs(cases) do
		local ispl = rfind(case, "_pl$")
		if args.sgtail and not ispl and args.forms[case] then
			local lastarg = #(args.forms[case])
			if lastarg > 0 then
				args.forms[case][lastarg] = args.forms[case][lastarg] .. args.sgtail
			end
		end
		if args.pltail and ispl and args.forms[case] then
			local lastarg = #(args.forms[case])
			if lastarg > 0 then
				args.forms[case][lastarg] = args.forms[case][lastarg] .. args.pltail
			end
		end
		if args[case] then
			args[case] = rsub(args[case], "~", ispl and args.pl or args.stem)
		end
		args[case] = args[case] and rsplit(args[case], "%s*,%s*") or args.forms[case]
	end

	-- handle + in loc/par meaning "the expected form"
	for _, case in ipairs({"loc", "par"}) do
		if args[case] then
			local new_args = {}
			for _, arg in ipairs(args[case]) do
				-- don't just handle + by itself in case the arg has в or на
				-- or whatever attached to it
				if rfind(arg, "^%+") or rfind(arg, "[%s%[|]%+") then
					for _, dat in ipairs(args["dat_sg"]) do
						local subval = case == "par" and dat or com.make_ending_stressed(dat)
						-- wrap the word in brackets so it's linked; but not if it
						-- appears to already be linked
						local newarg = rsub(arg, "^%+", "[[" .. subval .. "]]")
						newarg = rsub(newarg, "([%[|])%+", "%1" .. subval)
						newarg = rsub(newarg, "(%s)%+", "%1[[" .. subval .. "]]")
						table.insert(new_args, newarg)
					end
				else
					table.insert(new_args, arg)
				end
			end
			args[case] = new_args
		end
	end
end

-- Make the table
function make_table(args)
	local anim = args.a
	local numb = args.n
	local old = args.old
	args.after_title = after_titles[anim]
	args.number = numbers[numb]

	args.lemma = m_links.remove_links((numb == "p") and table.concat(args.nom_pl, ", ") or table.concat(args.nom_sg, ", "))
	args.title = args.title or
		strutils.format(old and old_title_temp or title_temp, args)

	for case in pairs(cases) do
		if args[case] then
			if type(args[case]) ~= "table" then
				error("Logic error, args[case] should be nil or table")
			end
			if #args[case] == 0 then
				args[case] = nil
			end
		end
	end

	if anim == "a" then
		if not args.acc_sg then
			args.acc_sg = args.gen_sg
		end
		if not args.acc_pl then
			args.acc_pl = args.gen_pl
		end
	elseif anim == "i" then
		if not args.acc_sg then
			args.acc_sg = args.nom_sg
		end
		if not args.acc_pl then
			args.acc_pl = args.nom_pl
		end
	end

	for case in pairs(cases) do
		if args[case] then
			if #args[case] == 1 and args[case][1] == "-" then
				args[case] = "&mdash;"
			else
				local ru_vals = {}
				local tr_vals = {}
				for i, x in ipairs(args[case]) do
					local entry, notes = m_table_tools.get_notes(x)
					-- clean <br /> that's in many multi-form entries and
					-- messes up linking
					entry = rsub(entry, "^%s*<br%s*/>%s*", "")
					if old then
						ut.insert_if_not(ru_vals, m_links.full_link(com.make_unstressed(entry), entry, lang, nil, nil, nil, {tr = "-"}, false) .. notes)
					else
						ut.insert_if_not(ru_vals, m_links.full_link(entry, nil, lang, nil, nil, nil, {tr = "-"}, false) .. notes)
					end
					ut.insert_if_not(tr_vals, lang:transliterate(m_links.remove_links(entry)) .. notes)
				end
				local term = table.concat(ru_vals, ", ")
				local tr = table.concat(tr_vals, ", ")
				args[case] = strutils.format(form_temp, {["term"] = term, ["tr"] = tr})
			end
		end
	end

	local temp = nil

	if numb == "s" then
		args.nom_x = args.nom_sg
		args.gen_x = args.gen_sg
		args.dat_x = args.dat_sg
		args.acc_x = args.acc_sg
		args.ins_x = args.ins_sg
		args.pre_x = args.pre_sg
		if args.acc_sg then
			temp = "half"
		else
			temp = "half_a"
		end
	elseif numb == "p" then
		args.nom_x = args.nom_pl
		args.gen_x = args.gen_pl
		args.dat_x = args.dat_pl
		args.acc_x = args.acc_pl
		args.ins_x = args.ins_pl
		args.pre_x = args.pre_pl
		args.par = nil
		args.loc = nil
		args.voc = nil
		if args.acc_pl then
			temp = "half"
		else
			temp = "half_a"
		end
	else
		if args.acc_pl then
			temp = "full"
		elseif args.acc_sg then
			temp = "full_af"
		else
			temp = "full_a"
		end
	end

	if args.par then
		args.par_clause = strutils.format(partitive, args)
	else
		args.par_clause = ""
	end

	if args.loc then
		args.loc_clause = strutils.format(locative, args)
	else
		args.loc_clause = ""
	end

	if args.voc then
		args.voc_clause = strutils.format(vocative, args)
	else
		args.voc_clause = ""
	end

	if args.notes then
		args.notes_clause = strutils.format(notes_template, args)
	else
		args.notes_clause = ""
	end

	return strutils.format(templates[temp], args)
end

partitive = [===[

! style="background:#eff7ff" | partitive
| {par}
|-]===]

locative = [===[

! style="background:#eff7ff" | locative
| {loc}
|-]===]

vocative = [===[

! style="background:#eff7ff" | vocative
| {voc}
|-]===]

notes_template = [===[
<div style="width:100%;text-align:left;background:#d9ebff">
<div style="display:inline-block;text-align:left;padding-left:1em;padding-right:1em">
{notes}
</div></div>
]===]

templates["full"] = [===[
<div>
<div class="NavFrame" style="display: inline-block; min-width: 45em">
<div class="NavHead" style="background:#eff7ff">{title}{after_title}</div>
<div class="NavContent">
{\op}| style="background:#F9F9F9;text-align:center; min-width:45em" class="inflection-table"
|-
! style="width:10em;background:#d9ebff" | 
! style="background:#d9ebff" | singular
! style="background:#d9ebff" | plural
|-
! style="background:#eff7ff" | nominative
| {nom_sg}
| {nom_pl}
|-
! style="background:#eff7ff" | genitive
| {gen_sg}
| {gen_pl}
|-
! style="background:#eff7ff" | dative
| {dat_sg}
| {dat_pl}
|-
! style="background:#eff7ff" | accusative
| {acc_sg}
| {acc_pl}
|-
! style="background:#eff7ff" | instrumental
| {ins_sg}
| {ins_pl}
|-
! style="background:#eff7ff" | prepositional
| {pre_sg}
| {pre_pl}
|-{par_clause}{loc_clause}{voc_clause}
|{\cl}{notes_clause}</div></div></div>]===]

templates["full_a"] = [===[
<div>
<div class="NavFrame" style="display: inline-block; min-width: 50em">
<div class="NavHead" style="background:#eff7ff">{title}{after_title}</div>
<div class="NavContent">
{\op}| style="background:#F9F9F9;text-align:center; min-width:50em" class="inflection-table"
|-
! style="width:15em;background:#d9ebff" | 
! style="background:#d9ebff" | singular
! style="background:#d9ebff" | plural
|-
! style="background:#eff7ff" | nominative
| {nom_sg}
| {nom_pl}
|-
! style="background:#eff7ff" | genitive
| {gen_sg}
| {gen_pl}
|-
! style="background:#eff7ff" | dative
| {dat_sg}
| {dat_pl}
|-
! style="background:#eff7ff" rowspan="2" | accusative <span style="padding-left:1em;display:inline-block;vertical-align:middle">animate<br/>inanimate</span>
| {gen_sg}
| {gen_pl}
|-
| {nom_sg}
| {nom_pl}
|-
! style="background:#eff7ff" | instrumental
| {ins_sg}
| {ins_pl}
|-
! style="background:#eff7ff" | prepositional
| {pre_sg}
| {pre_pl}
|-{par_clause}{loc_clause}{voc_clause}
|{\cl}{notes_clause}</div></div></div>]===]

templates["full_af"] = [===[
<div>
<div class="NavFrame" style="display: inline-block; min-width: 50em">
<div class="NavHead" style="background:#eff7ff">{title}{after_title}</div>
<div class="NavContent">
{\op}| style="background:#F9F9F9;text-align:center; min-width:50em" class="inflection-table"
|-
! style="width:15em;background:#d9ebff" | 
! style="background:#d9ebff" | singular
! style="background:#d9ebff" | plural
|-
! style="background:#eff7ff" | nominative
| {nom_sg}
| {nom_pl}
|-
! style="background:#eff7ff" | genitive
| {gen_sg}
| {gen_pl}
|-
! style="background:#eff7ff" | dative
| {dat_sg}
| {dat_pl}
|-
! style="background:#eff7ff" rowspan="2" | accusative <span style="padding-left:1em;display:inline-block;vertical-align:middle">animate<br/>inanimate</span>
| rowspan="2" | {acc_sg}
| {gen_pl}
|-
| {nom_pl}
|-
! style="background:#eff7ff" | instrumental
| {ins_sg}
| {ins_pl}
|-
! style="background:#eff7ff" | prepositional
| {pre_sg}
| {pre_pl}
|-{par_clause}{loc_clause}{voc_clause}
|{\cl}{notes_clause}</div></div></div>]===]

templates["half"] = [===[
<div>
<div class="NavFrame" style="display: inline-block; min-width: 30em">
<div class="NavHead" style="background:#eff7ff">{title}{after_title}</div>
<div class="NavContent">
{\op}| style="background:#F9F9F9;text-align:center; min-width:30em" class="inflection-table"
|-
! style="width:10em;background:#d9ebff" | 
! style="background:#d9ebff" | {number}
|-
! style="background:#eff7ff" | nominative
| {nom_x}
|-
! style="background:#eff7ff" | genitive
| {gen_x}
|-
! style="background:#eff7ff" | dative
| {dat_x}
|-
! style="background:#eff7ff" | accusative
| {acc_x}
|-
! style="background:#eff7ff" | instrumental
| {ins_x}
|-
! style="background:#eff7ff" | prepositional
| {pre_x}
|-{par_clause}{loc_clause}{voc_clause}
|{\cl}{notes_clause}</div></div></div>]===]

templates["half_a"] = [===[
<div>
<div class="NavFrame" style="display: inline-block; min-width: 35em">
<div class="NavHead" style="background:#eff7ff">{title}{after_title}</div>
<div class="NavContent">
{\op}| style="background:#F9F9F9;text-align:center; min-width:35em" class="inflection-table"
|-
! style="width:15em;background:#d9ebff" | 
! style="background:#d9ebff" | {number}
|-
! style="background:#eff7ff" | nominative
| {nom_x}
|-
! style="background:#eff7ff" | genitive
| {gen_x}
|-
! style="background:#eff7ff" | dative
| {dat_x}
|-
! style="background:#eff7ff" rowspan="2" | accusative <span style="padding-left:1em;display:inline-block;vertical-align:middle">animate<br/>inanimate</span>
| {gen_x}
|-
| {nom_x}
|-
! style="background:#eff7ff" | instrumental
| {ins_x}
|-
! style="background:#eff7ff" | prepositional
| {pre_x}
|-{par_clause}{loc_clause}{voc_clause}
|{\cl}{notes_clause}</div></div></div>]===]

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
