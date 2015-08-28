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

TODO:

1. Change {{temp|ru-decl-noun-pl}} and {{temp|ru-decl-noun-unc}} to use
   'manual' instead of '*' as the decl class.
2. Bug in -я nouns with bare specified; should not have -ь ending. Old templates did not add this ending when bare occurred. (PROBABLY SHOULD ALWAYS HAVE BARE
BE BARE, NEVER ADD A NON-SYLLABIC ENDING. HAVE TRACKING CODE FOR THIS.)
3. Genitive plural of -ёнокъ should be -атъ?
4. Remove barepl, make pl= be 5th argument. [IMPLEMENTED IN GITHUB IN TWO
   DIFFERENT BRANCHES]
5. (Add stress pattern for ь-stem numbers. Wikitiki handled that through
   overriding the ins_sg. I thought there would be complications with the
   nom_sg in multi-syllabic words but no.)
6. Eliminate complicated defaulting code for second and further stem sets.
   Should simply default to same values as the first stem set does, without
   the first stem set serving as defaults for the remainder.
   [IMPLEMENTED IN GITHUB]
7. Fixes for stem-multi-syllabic words with ending stress in gen pl but
   non-syllabic gen pl, with stress transferring onto final syllable even if
   stem is otherwise stressed on an earlier syllable (e.g. голова́ in
   accent pattern 6, nom pl го́ловы, gen pl голо́в). Currently these are handled
   by overriding "bare" but I want to make bare predictable mostly, just
   specifying that the noun is reducible should be enough. (IMPLEMENTED AS
   TRACKING CODE, NOT YET TURNED ON FOR REAL)
8. [If decl omitted, it should default to 1 or 2 depending on whether accent
   is on stem or ending, not always 1. It should also recognize plural in
   the auto-detection code when the gender is set. This can be used e.g. in
   class 4 or 6 to avoid having to distort the accent in the singular.]
   -- AUTO-DETECTING ACCENT CLASS 1 OR 2 IMPLEMENTED IN GITHUB; RECOGNIZING
   -- PLURAL IMPLEMENTED BUT COMMENTED OUT, NOT SURE IT'S A GOOD IDEA.
9. Possibly, issue an error unless allow_no_accent is given (perhaps it
   should be "given" using a * at the beginning of the stem).
10. [Make it so that the plural-specifying decl classes -а, -ья, and new -ы, -и
   still auto-detect the class and convert the resulting auto-detected class
   to one with the plural variant. It's useful then to have explicit names for
   the plural-variant classes -а, -ья. I propose c-а, c-ья, which are aliases;
   the canonical name is still -a, -ья so that you can still say something like
   ин/-ья. We should similarly have 'c' has the alias for -.  The classes
   would look like (where * means to construct a slash class)

   Orig        -а          -ья          -ы         -и
   -           -а          -ья          -          -
   ъ           ъ-а         ъ-ья         ъ          ъ
   ь-m         *           *            *          ь-m
   а           *           *            а          а
   я           *           *            *          я
   о           о           о-ья         о-ы        о-и
   е           е           *            *          *
   ь-f         *           *            *          ь-f
] - IMPLEMENTED, NEED TO TEST
11. Add ability to specify manual translation. (IMPLEMENTED IN GITHUB but
   based off of significantly older version of module)
12. Support adjective declensions. Autodetection should happen by putting +
   in decl field to indicate it's an adjective. Adjective decl types should
   begin with a +. (Formerly a * but currently that stands for "invariable".)
   (PARTLY IMPLEMENTED IN GITHUB)
13. Support multiple words. (PARTLY IMPLEMENTED IN GITHUB)

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

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

-- version of rfind() that lowercases its string first, for case-insensitive matching
local function rlfind(term, foo)
	return rfind(ulower(term), foo)
end

local function track(page)
	m_debug.track("ru-noun/" .. page)
	return true
end

-- Clone parent's args while also assigning nil to empty strings.
local function clone_args(frame)
	local args = {}
	for pname, param in pairs(frame:getParent().args) do
		if param == "" then args[pname] = nil
		else args[pname] = param
		end
	end
	return args
end

-- Old-style declensions.
local declensions_old = {}
-- Category and type information corresponding to declensions: These may
-- contain the following fields: 'singular', 'plural', 'decl', 'hard', 'g',
-- 'suffix', 'gensg', 'irregpl', 'cant_reduce', 'stem_suffix'.
--
-- 'singular' is used to construct a category of the form
-- "Russian nominals SINGULAR". If omitted, a category is constructed of the
-- form "Russian nominals ending in -ENDING", where ENDING is the actual
-- nom sg ending shorn of its acute accents; or "Russian nominals ending
-- in suffix -ENDING", if 'suffix' is true. The value of SINGULAR can be
-- one of the following: a single string, a list of strings, or a function,
-- which is passed one argument (the value of ENDING that would be used to
-- auto-initialize the category), and should return a single string or list
-- of strings. Such a category is only constructed if 'gensg' is true.
--
-- 'plural' is analogous but used to construct a category of the form
-- "Russian nominals with PLURAL", and if omitted, a category is constructed
-- of the form "Russian nominals with plural -ENDING", based on the actual
-- nom pl ending shorn of its acute accents. Currently no plural category
-- is actually constructed.
--
-- In addition, a category may normally constructed from the combination of
-- 'singular' and 'plural', appropriately defaulted; e.g. if both are present,
-- the combined category will be "Russian nominals SINGULAR with PLURAL" and
-- if both are missing, the combined category will be
-- "Russian nominals ending in -SGENDING with plural -PLENDING" (or
-- "Russian nominals ending in suffix -SGENDING with plural -PLENDING" if
-- 'suffix' is true). Note that if either singular or plural or both
-- specifies a list, looping will occur over all combinations. Such a
-- category is constructed only if 'irregpl' or 'suffix' is true or if the
-- declension class is a slash class.
--
-- 'decl' is "1st", "2nd", "3rd" or "invariable"; 'hard' is "hard", "soft"
-- or "none"; 'g' is "m", "f", "n" or "none"; these are all traditional
-- declension categories.
--
-- If 'suffix' is true, the declension type includes a long suffix
-- added to the string that itself undergoes reducibility and such, and so
-- reducibility cannot occur in the stem minus the suffix. Categoriess will
-- be created for the suffix.
--
-- In addition to the above categories, additional more specific categories
-- are constructed based on the final letter of the stem, e.g.
-- "Russian velar-stem 1st-declension hard nominals". See
-- get_stem_trailing_letter_type(). 'stem_suffix', if present, is added to
-- the end of the stem when get_stem_trailing_letter_type() is called.
-- This is the only place that 'stem_suffix' is used. This is for use with
-- the '-ья' and '-ье' declension types, so that the trailing letter is
-- 'ь' and not whatever precedes it.
--
-- 'enable_categories' is a special hack for testing, which disables all
-- category insertion if false. Delete this as soon as we've verified the
-- working of the category code and created all the necessary categories.
local enable_categories = true
-- Category/type info corresponding to old-style declensions; see above.
local declensions_old_cat = {}
-- New-style declensions; computed automatically from the old-style ones,
-- for the most part.
local declensions = {}
-- Category/type info corresponding to new-style declensions. Computed
-- automatically from the old-style ones, for the most part. Same format
-- as the old-style ones.
local declensions_cat = {}
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

--------------------------------------------------------------------------
--                     Tracking and categorization                      --
--------------------------------------------------------------------------

-- FIXME! Move below the main code

-- FIXME!! Delete most of this tracking code once we've enabled all the
-- categories. Note that some of the tracking categories aren't redundant;
-- in particular, we have more specific categories that combine
-- decl and stress classes, such as "а/5" or "о-ья/4*"; we also have
-- the same prefixed by "reducible-stem/" for reducible stems.
local function tracking_code(stress, decl_class, real_decl_class, args)
	assert(decl_class)
	assert(real_decl_class)
	local hint_types, _ = get_stem_trailing_letter_type(args.stem)
	if real_decl_class == decl_class then
		real_decl_class = nil
	end
	local function dotrack(prefix)
		track(stress)
		track(decl_class)
		track(decl_class .. "/" .. stress)
		if real_decl_class then
			track(real_decl_class)
			track(real_decl_class .. "/" .. stress)
		end
		for _, hint_type in ipairs(hint_types) do
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
	if rlfind(args.stem, "и́?н$") and (decl_class == "" or decl_class == "-") then
		track("irregular-in")
	end
	if rlfind(args.stem, "[еёо]́?нок$") and (decl_class == "" or decl_class == "-") then
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

local gender_to_full = {m="masculine", f="feminine", n="neuter"}

-- Insert the category CAT (a string) into list CATEGORIES. String will
-- have "Russian " prepended and ~ substituted for the part of speech --
-- currently always "nominals".
local function insert_category(categories, cat)
	if enable_categories then
		table.insert(categories, "Russian " .. rsub(cat, "~", "nominals"))
	end
end

-- Insert categories into ARGS.CATEGORIES corresponding to the specified
-- stress and declension classes and to the form of the stem (e.g. velar,
-- sibilant, etc.).
local function categorize(stress, decl_class, args)
	local function cat_to_list(cat)
		if not cat then
			return {}
		elseif type(cat) == "string" then
			return {cat}
		else
			assert(type(cat) == "table")
			return cat
		end
	end

	-- Insert category CAT into the list of categories in ARGS.
	-- CAT may be nil, a single string or a list of strings. We call
	-- insert_category() on each string. The strings will have "Russian "
	-- prepended and "~" replaced with the part of speech (currently always
	-- "nominals").
	local function insert_cat(cat)
		for _, c in ipairs(cat_to_list(cat)) do
			insert_category(args.categories, c)
		end
	end

	-- Insert category CAT, as with insert_cat(); but also insert categories
	-- prepending each of the stem types in STEM_TYPES.
	local function insert_cat_with_stem_type(cat, stem_types)
		for _, c in ipairs(cat_to_list(cat)) do
			for _, stem_type in ipairs(stem_types) do
				insert_cat(stem_type .. "-stem " .. c)
			end
		end
		insert_cat(cat)
	end

	-- "Resolve" the category spec CATSPEC into the sort of category spec
	-- accepted by insert_cat(), i.e. nil, a single string or a list of
	-- strings. CATSPEC may be any of these or a function, which takes one
	-- argument (SUFFIX) and returns another CATSPEC.
	local function resolve_cat(catspec, suffix)
		if type(catspec) == "function" then
			return resolve_cat(catspec(suffix), suffix)
		else
			return catspec
		end
	end

	-- Check whether an override for nom_sg or nom_pl still contains the
	-- normal suffix (which should already have accents removed) in at least
	-- one of its entries. If no override then of course we return true.
	local function override_matches_suffix(override, suffix, ispl)
		if not override then
			return true
		end
		assert(suffix == com.remove_accents(suffix))		
		override = canonicalize_override(override, args, ispl)
		for _, x in ipairs(override) do
			local entry, notes = m_table_tools.get_notes(x)
			entry = com.remove_accents(m_links.remove_links(entry))
			if rlfind(entry, suffix .. "$") then
				return true
			end
		end
		return false
	end

	assert(decl_class)
	local decl_cats = old and declensions_old_cat or declensions_cat

	local sgdecl, pldecl
	if rfind(decl_class, "/") then
		local indiv_decl_classes = rsplit(decl_class, "/")
		sgdecl, pldecl = indiv_decl_classes[1], indiv_decl_classes[2]
	else
		sgdecl, pldecl = decl_class, decl_class
	end
	local sgdc = decl_cats[sgdecl]
	local pldc = decl_cats[pldecl]
	assert(sgdc)
	assert(pldc)

	local _, sgstem_types = get_stem_trailing_letter_type(
		args.stem .. (sgdc.stem_suffix or ""))

	-- insert human version of traditional declension
	local decl_cat
	if sgdc.decl == "invariable" then
		decl_cat = "invariable ~"
	elseif sgdc.decl == "3rd" then
		decl_cat = "3rd-declension ~"
	elseif sgdc.decl == "1st" then
		decl_cat = "1st-declension " .. sgdc.hard .. " ~"
	elseif sgdc.decl == "2nd" then
		decl_cat = ("2nd-declension " .. sgdc.hard .. " normally-" ..
			gender_to_full[sgdc.g] .. " ~")
	else
		assert(false, "Unrecognized declension type")
	end
	insert_cat_with_stem_type(decl_cat,
		sgdc.decl == "invariable" and {} or sgstem_types)
	local sgsuffix = args.suffixes["nom_sg"]
	if sgsuffix then
		assert(#sgsuffix == 1) -- If this ever fails, then implement a loop
		sgsuffix = com.remove_accents(sgsuffix[1])
		-- If we are a plurale tantum or if nom_sg is overridden and has
		-- an unusual suffix, then don't create category for sg suffix
		if args.n == "p" or not override_matches_suffix(args["nom_sg"], sgsuffix, false) then
			sgsuffix = nil
		end
	end
	local plsuffix = args.suffixes["nom_pl"]
	if plsuffix then
		assert(#plsuffix == 1) -- If this ever fails, then implement a loop
		plsuffix = com.remove_accents(plsuffix[1])
		-- If we are a singulare tantum or if nom_pl is overridden and has
		-- an unusual suffix, then don't create category for pl suffix
		if args.n == "s" or not override_matches_suffix(args["nom_pl"], plsuffix, true) then
			plsuffix = nil
		end
	end
	local sgcat = sgsuffix and (resolve_cat(sgdc.singular, sgsuffix) or "ending in " .. (sgdc.suffix and "suffix " or "") .. "-" .. sgsuffix)
	local plcat = plsuffix and (resolve_cat(pldc.plural, suffix) or "plural -" .. plsuffix)
	if sgcat and sgdc.gensg then
		for _, cat in ipairs(cat_to_list(sgcat)) do
			insert_cat("~ " .. cat)
		end
	end
	if sgcat and plcat and (sgdc.suffix or sgdc.irregpl or
			rfind(decl_class, "/")) then
		for _, scat in ipairs(cat_to_list(sgcat)) do
			for _, pcat in ipairs(cat_to_list(plcat)) do
				insert_cat("~ " .. scat .. " with " .. pcat)
			end
		end
	end

	if args.pl ~= args.stem then
		insert_cat("~ with irregular plural")
	end
	if args.bare ~= args.stem then
		insert_cat("~ with reducible stem")
	end
	for case in pairs(cases) do
		if args[case] then
			local engcase = rsub(case, "^([a-z]*)", {
				nom="nominative", gen="genitive", dat="dative",
				acc="accusative", ins="instrumental", pre="prepositional",
				par="partitive", loc="locative", voc="vocative"
			})
			engcase = rsub(engcase, "(_[a-z]*)$", {
				_sg=" singular", _pl=" plural"
			})
			if case == "loc" or case == "voc" or case == "par" then
				insert_cat("~ with " .. engcase)
			else
				insert_cat("~ with irregular " .. engcase)
			end
		end
	end

	insert_cat("~ with stress pattern " .. stress)
	-- FIXME! Should we create categories for combinations of stress pattern
	-- and declension? Certain aspects of the declension depend on such
	-- combinations; e.g. the genitive plural of nouns in -а is normally
	-- null, but the special form ей exists with the combination of
	-- sibilant stems and accented genitive plural (stress patterns
	-- 2, 3, 5, 6, 6*; see stressed_gen_pl_patterns[]). But any attempt to
	-- create such combinations will lead to a large number of categories.
	-- Most viable would be stress pattern + traditional decl; that gives
	-- 8 stress patterns times 8 traditional decls (1-hard, 1-soft, 2-hard-m,
	-- 2-soft-m, 2-palatal-m, 2-hard-n, 2-soft-n, 3) = 64. Note that not all
	-- of these actually have any members in them. However, this isn't fine
	-- enough to create a category for the the -а genitive plural in -ей in
	-- that it doesn't also include the stem type (sibilant, velar, etc.);
	-- but simultaneously it's too fine in that it doesn't group the stress
	-- patterns with stressed genitive plural.
end

--------------------------------------------------------------------------
--                              Main code                               --
--------------------------------------------------------------------------

local function do_show(frame, old)
	PAGENAME = mw.title.getCurrentTitle().text
	SUBPAGENAME = mw.title.getCurrentTitle().subpageText
	NAMESPACE = mw.title.getCurrentTitle().nsText

	local args = clone_args(frame)

	local manual = false

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
			if stem_set[3] == "manual" then
				manual = true
			end
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

	if manual then
		if #stem_sets > 1 then
			error("Can't specify multiple stem sets when manual")
		end
		if stem_sets[1][4] or stem_sets[1].pl or stem_sets[1].barepl then
			error("Can't specify optional stem parameters when manual")
		end
	end

	-- Initialize non-stem-specific arguments.
	args.a = args.a and string.sub(args.a, 1, 1) or "i"
	args.n = args.n and string.sub(args.n, 1, 1) or nil
	args.forms = {}
	args.categories = {}
	local function insert_cat(cat)
		insert_category(args.categories, cat)
	end
	args.old = old
	-- HACK: Escape * at beginning of line so it doesn't show up
	-- as a list entry. Many existing templates use * for footnotes.
	-- FIXME: We should maybe do this in {{ru-decl-noun}} instead.
	if args.notes then
		args.notes = rsub(args.notes, "^%*", "&#42;")
	end

	local decls = old and declensions_old or declensions
	local detectfuns = old and detect_decl_old or detect_decl
	local decl_cats = old and declensions_old_cat or declensions_cat

	-- Default arguments. After the first stem set is processed, we set the
	-- defaults based on that set.
	local default_stress = "1"
	local default_decl = ""
	local default_stem = SUBPAGENAME
	local default_bare, default_pl, default_barepl
	local first = true

	if #stem_sets > 1 then
		track("multiple-stems")
		insert_cat("~ with multiple stems")
	end

	for _, stem_set in ipairs(stem_sets) do
		local stress_arg = stem_set[1] or default_stress
		local decl_class = stem_set[3] or default_decl
		local stem_specified = stem_set[2] or first
		local stem = stem_set[2] or default_stem
		if ut.contains({"", "m", "f", "n"}, decl_class) then
			stem, decl_class = detect_stem_type(stem, decl_class)
		end
		-- For bare, pl and barepl, we default to other specified arguments,
		-- falling back to the stem if specified or we're handling the
		-- first stem set; as a last resort, use the defaults taken from the
		-- first stem set.
		local bare = stem_set[4] or stem_specified and stem or default_bare
		args.pl = stem_set.pl or stem_specified and stem or default_pl
		args.barepl = stem_set.barepl or stem_set[4] or stem_set.pl or
			stem_specified and stem or default_barepl

		if first then
			default_stress = stress_arg
			default_decl = decl_class
			default_stem = stem
			default_bare = bare
			default_pl = args.pl
			default_barepl = args.barepl
		end

		-- validate stress arg and decl type and convert to list
		stress_arg = rsplit(stress_arg, ",")
		for _, stress in ipairs(stress_arg) do
			if not stress_patterns[stress] then
				error("Unrecognized stress pattern " .. stress)
			end
		end
		local sub_decl_classes
		if rfind(decl_class, "/") then
			track("mixed-decl")
			insert_cat("~ with mixed declension")
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
			local dclass = decl_class_spec[1]
			if not decl_cats[dclass] then
				error("Unrecognized declension class " .. dclass)
			end
		end

		if #stress_arg > 1 then
			track("multiple-stress-patterns")
			insert_cat("~ with multiple stress patterns")
		end

		-- Loop over stress patterns in case more than one given.
		for _, stress in ipairs(stress_arg) do
			-- Loop over declension classes (we may have two of them, one for
			-- singular and one for plural, in the case of a mixed declension
			-- class of the form SGDECL/PLDECL).
			args.suffixes = {}

			local resolved_bare = bare
			-- Handle (un)reducibles
			if bare == "*" then
				local sgclass = sub_decl_classes[1][1]
				if is_reducible(stem, sgclass, old) then
					resolved_bare = stem
					stem = export.reduce_nom_sg_stem(stem, sgclass, "error")
				elseif is_unreducible(stem, sgclass, old) then
					resolved_bare = export.unreduce_nom_sg_stem(stem, sgclass,
						stress, old, "error")
				else
					error("Declension class " .. sgclass .. " not (un)reducible")
				end
			elseif stem ~= bare then
				-- FIXME: Tracking code eventually to remove
				local sgclass = sub_decl_classes[1][1]
				if is_reducible(stem, sgclass, old) then
					local autostem = export.reduce_nom_sg_stem(bare, sgclass)
					if not autostem then
						track("error-reducible")
					elseif autostem == stem then
						track("predictable-reducible")
					else
						track("unpredictable-reducible")
					end
				elseif is_unreducible(stem, sgclass, old) then
					local autobare = export.unreduce_nom_sg_stem(stem, sgclass,
						stress, old)
					if not autobare then
						track("error-unreducible")
					elseif autobare == bare then
						track("predictable-unreducible")
					else
						track("unpredictable-unreducible")
					end
				else
					track("bare-without-reducibility")
				end
			end

			args.stem = stem
			args.bare = resolved_bare
			args.ustem = com.make_unstressed_once(stem)
			args.upl = com.make_unstressed_once(args.pl)
			args.hint = ulower(usub(stem, -1))

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
						detectfuns[real_decl_class](stem, stress) or real_decl_class
					if real_decl_class == resolved_decl_class then
						break
					end
					real_decl_class = resolved_decl_class
				end
				assert(decls[real_decl_class])
				tracking_code(stress, orig_decl_class, real_decl_class, args)
				do_stress_pattern(stress_patterns[stress], args,
					decls[real_decl_class], number)
			end
			categorize(stress, decl_class, args)
		end
	end

	handle_forms_and_overrides(args)

	return make_table(args) .. m_utilities.format_categories(args["categories"], lang)
end

-- The main entry point for modern declension tables.
function export.show(frame)
	return do_show(frame, false)
end

-- The main entry point for old declension tables.
function export.show_old(frame)
	return do_show(frame, true)
end

local stem_expl = {
	["velar"] = "a velar (-к, -г or –x)",
	["sibilant"] = "a sibilant (-ш, -ж, -ч or -щ)",
	["ц"] = "-ц",
	["i"] = "-и (old-style -і)",
	["й"] = "-й",
	["ь"] = "-ь (indicating a soft consonant, in this case followed by /j/)",
}

-- Implementation of template 'runouncatboiler'.
function export.catboiler(frame)
	local args = clone_args(frame)

	local cats = {}
	insert_category(cats, "~")

	local maintext
	if args[1] == "decl" then
		if args[2] == "invariable" then
			maintext = "invariable (indeclinable) ~, which normally have the same form for all cases and numbers."
		else
			maintext = (args[7] and args[7] .. "-stem " or "") .. args[2] .. "-declension " .. (args[3] and args[3] .. " " or "") .. "normally-" .. args[4] .. " ~, normally ending in nominative singular " .. args[5] .. " and nominative plural " .. args[6] .. ". The stem ends in " .. (args[8] or stem_expl[args[7]]) .. "."
		end
		insert_category(cats, "~ by declension type")
		if args[7] then
			insert_category(cats, "~ by declension type and stem type")
		end
	elseif args[1] == "sg" then
		maintext = "~ ending in nominative singular " .. args[2] .. "."
		insert_category(cats, "~ by singular ending")
	elseif args[1] == "pl" then
		maintext = "~ ending in nominative plural " .. args[2] .. "."
		insert_category(cats, "~ by plural ending")
	elseif args[1] == "sgpl" then
		maintext = "~ ending in nominative singular " .. args[2] .. " and nominative plural " .. args[3] .. "."
		insert_category(cats, "~ by singular and plural ending")
	elseif args[1] == "stress" then
		maintext = "~ with stress pattern " .. args[2] .. "."
		insert_category(cats, "~ by stress pattern")
	elseif args[1] == "extracase" then
		maintext = "~ with a separate " .. args[2] .. " singular case."
		insert_category(cats, "~ by case form")
	elseif args[1] == "irregcase" then
		maintext = "~ with an irregular " .. args[2] .. " case."
		insert_category(cats, "~ by case form")
	else
		maintext = "~ " .. args[1]
	end

	return "This category contains Russian " .. rsub(maintext, "~", "nominals")
		.. "\n" ..
		mw.getCurrentFrame():expandTemplate{title="ru-categoryTOC", args={}}
		.. m_utilities.format_categories(cats, lang)
end

--------------------------------------------------------------------------
--                   Autodetection and stem munging                     --
--------------------------------------------------------------------------

-- Attempt to detect the type of the stem (= including ending) based
-- on its ending, separating off the base and the ending. DECL is the
-- value passed in and might be "", "m" or "f"; the latter are necessary
-- when dealing with -ь stems.
function detect_stem_type(stem, decl)
	local base, ending = rmatch(stem, "^(.*)([еЕ]́)$") -- accented
	if base then
		return base, ulower(ending)
	end
	base = rmatch(stem, "^(.*[" .. com.sib_c .. "])[еЕ]$") -- unaccented
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

function is_reducible(stem, decl, old)
	local decl_cats = old and declensions_old_cat or declensions_cat
	local dc = decl_cats[decl]
	if dc.suffix or dc.cant_reduce then return false end
	if dc.decl == "3rd" or dc.g == "m" then return true end
	return false
end

-- Reduce nom sg to stem by eliminating the "epenthetic" vowel. Applies to
-- masculine 2nd-declension hard and soft, and 3rd-declension feminine in
-- -ь. STEM and DECL are after detect_stem_type(), before converting
-- outward-facing declensions to inward ones.
function export.reduce_nom_sg_stem(stem, decl, can_err)
	local pre, letter, post
	pre, post = rmatch(stem, "^(.*)[Оо]́?(.)$")
	if pre then
		-- FIXME, what about when the accent is on the removed letter?
		return pre .. post
	end
	if decl == "й" then
		pre, letter = rmatch(stem, "^(.*)([еёЕЁ])́?$")
		if pre then
			return pre .. (rfind(letter, "[ЕЁ]") and "Й" or "й")
		end
	end
	pre, letter, post = rmatch(stem, "^(.*[" .. com.vowel .. "])([еёЕЁ])́?([" .. com.cons .. "]+)$")
	if pre then
		return pre .. (rfind(letter, "[ЕЁ]") and "Й" or "й") .. post
	end
	pre, letter, post = rmatch(stem, "^(.*[" .. com.cons_except_sib_c .. "])([еёЕЁ])́?([" .. com.velar .. "])$")
	if not pre then
		pre, letter, post = rmatch(stem, "^(.*[лЛ])([еёЕЁ])́?([" .. com.cons .. "]+)$")
	end
	if pre then
		return pre .. (rfind(letter, "[ЕЁ]") and "Ь" or "ь") .. post
	end
	pre, letter, post = rmatch(stem, "^(.*)([еёЕЁ])́?([" .. com.cons .. "]+)$")
	if pre then
		return pre .. post
	end
	if can_err then
		error("Unable to reduce stem " .. stem)
	else
		return nil
	end
end

function is_unreducible(stem, decl, old)
	local decl_cats = old and declensions_old_cat or declensions_cat
	local dc = decl_cats[decl]
	if dc.suffix or dc.cant_reduce then return false end
	if dc.decl == "1st" or dc.decl == "2nd" and dc.g == "n" then return true end
	return false
end
	
-- Generate the unreduced gen pl stem given STEM, DECL and STRESS; this is
-- without any terminating non-syllabic ending, which is added if needed by
-- the calling function.
local function basic_unreduce_nom_sg_stem(stem, decl, stress, can_err)
	local pre, letter, post
	-- FIXME!!! Deal with this special case
	--if not (z.stem_type == 'soft' and _.equals(z.stress_type, {'b', 'f'}) -- we should ignore asterix for 2*b and 2*f (so to process it just like 2b or 2f)
	--		 or _.contains(z.specific, '(2)') and _.equals(z.stem_type, {'velar', 'letter-ц', 'vowel'}))  -- and also the same for (2)-specific and 3,5,6 stem-types
	--then 

	-- I think this corresponds to our -ья and -ье types, which we
	-- handle separately
	--if z.stem_type == 'vowel' then  -- 1).
	--	if _.equals(z.stress_type, {'b', 'c', 'e', 'f', "f'", "b'" }) then  -- gen_pl ending stressed  -- TODO: special vars for that
	--		z.stems['gen_pl'] = _.replace(z.stems['gen_pl'], 'ь$', 'е́')
	--	else
	--		z.stems['gen_pl'] = _.replace(z.stems['gen_pl'], 'ь$', 'и')
	--	end
	--end

	pre, letter, post = rmatch(stem, "^(.*)([" .. com.cons .. "])([" .. com.cons .. "])$")
	if pre then
		local is_upper = rfind(post, "[" .. com.uppercase .. "]")
		if rfind(letter, "[ьйЬЙ]") then
			if rfind(post, "[цЦ]$") or not stressed_gen_pl_patterns[stress] then
				return pre .. (is_upper and "Е" or "е") .. post
			else
				return pre .. (is_upper and "Ё" or "ё") .. post
			end
		elseif rfind(letter, "[" .. com.cons_except_sib_c .. "]") and rfind(post, "[" .. com.velar .. "]") or
				rfind(letter, "[" .. com.velar .. "]") then
			return pre .. letter .. (is_upper and "О" or "о") .. post
		elseif post == "ц" or post == "Ц" then
			return pre .. letter .. (is_upper and "Е" or "е") .. post
		elseif stressed_gen_pl_patterns[stress] then
			if rfind(letter, "[" .. com.sib .. "]") then
				return pre .. letter .. (is_upper and "О́" or "о́") .. post
			else
				return pre .. letter .. (is_upper and "Ё" or "ё") .. post
			end
		else
			return pre .. letter.. (is_upper and "Е" or "е") .. post
		end
	end
	if can_err then
		error("Unable to unreduce stem " .. stem)
	else
		return nil
	end
end

-- Unreduce stem to the form found in the gen pl by inserting an epenthetic
-- vowel. Applies to 1st declension and 2nd declension neuter. STEM and DECL
-- are after detect_stem_type(), before converting outward-facing declensions
-- to inward ones. STRESS is the stess pattern.
function export.unreduce_nom_sg_stem(stem, decl, stress, old, can_err)
	local ret = basic_unreduce_nom_sg_stem(stem, decl, stress, can_err)
	if not ret then
		return nil
	end
	if old and declensions_old_cat[decl].hard == "hard" then
		return ret .. "ъ"
	elseif decl == "я" then
		-- This next clause corresponds to a special case in Vitalik's module.
		-- It says that nouns in -ня (accent class 1) have gen pl without
		-- trailing -ь. It appears to apply to most nouns in -ня (possibly
		-- all in -льня), but ку́хня (gen pl ку́хонь) is an exception.
		-- дере́вня is an apparent exception but not really because it is
		-- accent class 5.
		if rfind(ret, "[нН]$") and stress == "1" then
			return ret
		elseif rfind(ret, com.vowel .. "́?$") then
			return ret .. "й"
		else
			return ret .. "ь"
		end
	else
		return ret
	end
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
declensions_old_cat["ъ"] = { decl="2nd", hard="hard", g="m" }

-- Normal mapping of old ъ would be "" (blank), but we call it "-" so we
-- have a way of referring to it without defaulting if need be (e.g. in the
-- second stem of a word where the first stem has a different decl class),
-- and eventually want to make "" (blank) auto-detect the class.
detect_decl["-"] = old_detect_decl_to_new(detect_decl_old["ъ"])
declensions_cat["-"] = declensions_old_cat["ъ"]

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
declensions_old_cat["ъ-а"] = { decl="2nd", hard="hard", g="m", irregpl=true }
declensions_cat["-а"] = {
	singular = "ending in a consonant",
	decl="2nd", hard="hard", g="m", irregpl=true,
}

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
declensions_old_cat["ъ-ья"] = { decl="2nd", hard="hard", g="m", irregpl=true }
declensions_cat["-ья"] = {
	singular = "ending in a consonant",
	decl="2nd", hard="hard", g="m", irregpl=true,
}

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

declensions_old_cat["инъ"] = { decl="2nd", hard="hard", g="m", suffix=true }

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

declensions_old_cat["ёнокъ"] = { decl="2nd", hard="hard", g="m", suffix=true }
declensions_old_cat["-онокъ"] = declensions_old_cat["ёнокъ"]
declensions_old_cat["-енокъ"] = declensions_old_cat["ёнокъ"]

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

declensions_old_cat["ь-m"] = { decl="2nd", hard="soft", g="m" }

-- Soft-masculine declension in -ь with irreg nom pl -я
declensions_old["ь-я"] = mw.clone(declensions_old["ь-m"])
declensions_old["ь-я"]["nom_pl"] = "я́"

declensions_old_cat["ь-я"] = { decl="2nd", hard="soft", g="m", irregpl=true }

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
	if rlfind(stem, "[іи]́?$") then
		return "(і)й"
	else
		return "й-normal"
	end
end

declensions_old_cat["й"] = { decl="2nd", hard="palatal", g="m" }

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

declensions_old_cat["а"] = { decl="1st", hard="hard", g="f" }

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
	if rlfind(stem, "[іи]́?$") then
		return "(і)я"
	else
		return "я-normal"
	end
end

declensions_old_cat["я"] = { decl="1st", hard="soft", g="f" }

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

declensions_old_cat["ья"] = {
	decl="1st", hard="soft", g="f",
	stem_suffix="ь",
	cant_reduce=true -- already has unreduced gen pl
}

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
declensions_old_cat["о"] = { decl="2nd", hard="hard", g="n" }

-- Hard-neuter declension in -о with irreg nom pl -и
declensions_old["о-и"] = mw.clone(declensions_old["о"])
declensions_old["о-и"]["nom_pl"] = "ы́"
declensions_old_cat["о-и"] = { decl="2nd", hard="hard", g="n", irregpl=true }

declensions_old["о-ы"] = declensions_old["о-и"]
declensions_old_cat["о-ы"] = declensions_old_cat["о-и"]

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
declensions_old_cat["о-ья"] = { decl="2nd", hard="hard", g="n", irregpl=true }

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
	if rlfind(stem, "[іи]́?$") then
		if stressed_pre_sg_patterns[stress] then
			return "(і)е-2"
		else
			return "(і)е-1"
		end
	else
		return "е-normal"
	end
end
declensions_old_cat["е"] = {
	singular = function(suffix)
		if suffix == "ё" then
			return "ending in -ё"
		else
			return {}
		end
	end,
	decl="2nd", hard="soft", g="n", gensg=true
}

-- User-facing declension type "ё" = "е"
detect_decl_old["ё"] = detect_decl_old["е"]
declensions_old_cat["ё"] = declensions_old_cat["е"]

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
	if rlfind(stem, "[іи]́?$") then
		return "(і)е́"
	else
		return "е́-normal"
	end
end
declensions_old_cat["е́"] = {
	singular = "ending in stressed -е",
	decl="2nd", hard="soft", g="n", gensg=true
}

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

declensions_old_cat["ье"] = {
	singular = function(suffix)
		if suffix == "ьё" then
			return "ending in -ьё"
		else
			return {}
		end
	end,
	decl="2nd", hard="soft", g="n", gensg=true,
	stem_suffix="ь",
	cant_reduce=true -- already has unreduced gen pl
}
declensions_old_cat["ьё"] = declensions_old_cat["ье"]

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

declensions_old_cat["ь-f"] = { decl="3rd", hard="soft", g="f" }

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

declensions_old_cat["мя"] = { decl="3rd", hard="soft", g="n", suffix=true }

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

declensions_old_cat["мя-1"] = { decl="3rd", hard="soft", g="n", suffix=true }

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
declensions_old_cat["*"] = { decl="invariable", hard="none", g="none" }

--------------------------------------------------------------------------
--                      Populate new from old                           --
--------------------------------------------------------------------------

local function old_to_new(v)
	v = rsub(v, "ъ$", "")
	v = rsub(v, "^ъ", "")
	v = rsub(v, "(%A)ъ", "%1")
	v = rsub(v, "ъ(%A)", "%1")
	v = rsub(v, "і", "и")
	v = rsub(v, "ѣ", "е")
	return v
end

-- Function to convert old detect_decl function to new one
function old_detect_decl_to_new(ofunc)
	return function(stem, stress)
		return old_to_new(ofunc(stem, stress))
	end
end

local function old_decl_to_new(odecl)
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

local function old_decl_cat_entry_to_new(odecl_cat_entry)
	if not odecl_cat_entry then
		return nil
	elseif type(odecl_cat_entry) == "function" then
		return function(suffix)
			return old_decl_cat_entry_to_new(odecl_cat_entry(suffix))
		end
	elseif type(odecl_cat_entry) == "table" then
		local ndecl_cat_entry = {}
		for k, v in pairs(odecl_cat_entry) do
			ndecl_cat_entry[k] = old_decl_cat_entry_to_new(v)
		end
		return ndecl_cat_entry
	elseif type(odecl_cat_entry) == "boolean" then
		return odecl_cat_entry
	else
		assert(type(odecl_cat_entry) == "string")
		return old_to_new(odecl_cat_entry)
	end
end

local function old_decl_cat_to_new(odeclcat)
	local ndeclcat = {}
	for k, v in pairs(odeclcat) do
		ndeclcat[k] = old_decl_cat_entry_to_new(v)
	end
	return ndeclcat
end

-- populate declensions[] from declensions_old[]
for odecltype, odecl in pairs(declensions_old) do
	local ndecltype = old_to_new(odecltype)
	if not declensions[ndecltype] then
		declensions[ndecltype] = old_decl_to_new(odecl)
	end
end

-- populate declensions_cat[] from declensions_old_cat[]
for odecltype, odeclcat in pairs(declensions_old_cat) do
	local ndecltype = old_to_new(odecltype)
	if not declensions_cat[ndecltype] then
		declensions_cat[ndecltype] = old_decl_cat_to_new(odeclcat)
	end
end

-- populate detect_decl[] from detect_decl_old[]
for odeclfrom, ofunc in pairs(detect_decl_old) do
	local declfrom = old_to_new(odeclfrom)
	if not detect_decl[declfrom] then
		detect_decl[declfrom] = old_detect_decl_to_new(ofunc)
	end
end

--------------------------------------------------------------------------
--                        Inflection functions                          --
--------------------------------------------------------------------------

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

local old_consonantal_suffixes = ut.list_to_set({"ъ", "ь", "й"})

local consonantal_suffixes = ut.list_to_set({"", "ь", "й"})

-- used for tracking and categorization
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

-- used for categorization
tltype_to_stem_type = {
	["sibilant"] = "sibilant",
	["velar"] = "velar",
	["c"] = "ц",
	["palatal"] = "й",
	["i"] = "i",
	["soft-cons"] = "ь",
	-- These are probably not useful as they don't reflect what people
	-- would think, e.g. nouns in -ь would still be counted as hard-stem
	-- because the -ь is considered an ending.
	-- ["hard-cons"] = "hard-consonant",
	-- ["hard-vowel"] = "hard-vowel",
	-- ["soft-vowel"] = "soft-vowel",
	-- Eliminate these to reduce number of categories
	-- ["cons"] = "consonant",
	-- ["vowel"] = "vowel",
}

function get_stem_trailing_letter_type(stem)
	local hint = ulower(usub(com.remove_accents(stem), -1))
	local hint_types = trailing_letter_type[hint] or {"hard-cons", "cons"}
	local stem_types = {}
	for _, hint_type in ipairs(hint_types) do
		table.insert(stem_types, tltype_to_stem_type[hint_type])
	end
	return hint_types, stem_types
end

sibilant_suffixes = ut.list_to_set({"ш", "щ", "ч", "ж"})

local function combine_stem_and_suffix(stem, suf, rules, old)
	local first = usub(suf, 1, 1)
	if rules then
		local conv = rules[first]
		if conv then
			local ending = usub(suf, 2)
			if old and conv == "и" and mw.ustring.find(ending, "^́?[аеёиійоуэюяѣ]") then
				conv = "і"
			end
			suf = conv .. ending
		end
	end
	return stem .. suf, suf
end

-- Attach the stressed stem (or plural stem, or barestem) out of ARGS
-- to the unstressed suffix SUF, modifying the suffix as necessary for the
-- last letter of the stem (e.g. if it is velar, sibilant or ц). CASE is
-- the case form being created and is used to select the plural stem if
-- needed. Returns two values, the combined form and the modified suffix.
local function attach_unstressed(args, case, suf)
	if suf == nil then
		return nil, nil
	elseif rfind(suf, "̂") then -- if suf has circumflex accent, it forces stressed
		return attach_stressed(args, case, suf)
	end
	local is_pl = rfind(case, "_pl$")
	local old = args.old
	local stem = is_pl and args.pl or args.stem
	local barestem = is_pl and args.barepl or args.bare
	if old and old_consonantal_suffixes[suf] or not old and consonantal_suffixes[suf] then
		if rlfind(barestem, old and "[йьъ]$" or "[йь]$") then
			return barestem, ""
		else
			if suf == "й" or suf == "ь" then
				if rfind(barestem, "[" .. com.vowel .. "]́?$") then
					suf = "й"
				else
					suf = "ь"
				end
			end
			return barestem .. suf, suf
		end
	end
	suf = com.make_unstressed(suf)
	local rules = unstressed_rules[args.hint]
	return combine_stem_and_suffix(stem, suf, rules, old)
end

-- Analogous to attach_unstressed() but for the unstressed stem and a
-- stressed suffix.
function attach_stressed(args, case, suf)
	if suf == nil then
		return nil, nil
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
	return combine_stem_and_suffix(stem, suf, rules, old)
end

-- Attach the appropriate stressed or unstressed stem (or plural stem as
-- determined by CASE, or barestem) out of ARGS to the suffix SUF, which may
-- be a list of alternative suffixes (e.g. in the inst sg of feminine nouns).
-- Calls FUN (either attach_stressed() or attach_unstressed() to do the work
-- for an individual suffix. Returns two values, a list of combined forms
-- and a list of the real suffixes used (which may be modified from the
-- passed-in suffixes, e.g. by removing stress marks or modifying vowels in
-- various ways after a stem-final velar, sibilant or ц).
local function attach_with(args, case, suf, fun)
	if type(suf) == "table" then
		local all_combineds = {}
		local all_realsufs = {}
		for _, x in ipairs(suf) do
			local combineds, realsufs = attach_with(args, case, x, fun)
			for _, combined in ipairs(combineds) do
				table.insert(all_combineds, combined)
			end
			for _, realsuf in ipairs(realsufs) do
				table.insert(all_realsufs, realsuf)
			end
		end
		return all_combineds, all_realsufs
	else
		local combined, realsuf = fun(args, case, suf)
		return {combined}, {realsuf}
	end
end

-- Generate the form(s) and suffix(es) for CASE according to the declension
-- table DECL, using the attachment function FUN (one of attach_stressed()
-- or attach_unstressed()).
local function gen_form(args, decl, case, fun)
	if not args.forms[case] then
		args.forms[case] = {}
	end
	if not args.suffixes[case] then
		args.suffixes[case] = {}
	end
	local combineds, realsufs = attach_with(args, case, decl[case], fun)
	for _, form in ipairs(combineds) do
		ut.insert_if_not(args.forms[case], form)
	end
	for _, realsuf in ipairs(realsufs) do
		ut.insert_if_not(args.suffixes[case], realsuf)
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

stressed_gen_pl_patterns = ut.list_to_set({"2", "3", "5", "6", "6*"})

stressed_pre_sg_patterns = ut.list_to_set({"2", "4", "4*", "6", "6*"})

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
decl_cases = ut.list_to_set({
	"nom_sg", "gen_sg", "dat_sg", "acc_sg", "ins_sg", "pre_sg",
	"nom_pl", "gen_pl", "dat_pl", "acc_pl", "ins_pl", "pre_pl",
})

-- all cases displayable or handleable through overrides
cases = ut.list_to_set({
	"nom_sg", "gen_sg", "dat_sg", "acc_sg", "ins_sg", "pre_sg",
	"nom_pl", "gen_pl", "dat_pl", "acc_pl", "ins_pl", "pre_pl",
	"par", "loc", "voc",
})

-- Convert a raw override into a canonicalized list of individual overrides.
-- If input is nil, so is output. Certain junk (e.g. <br/>) is removed,
-- and ~ and ~~ are substituted appropriately; ARGS and ISPL are required for
-- this purpose. if will still be necessary to call m_table_tools.get_notes()
-- to separate off any trailing "notes" (asterisks, superscript numbers, etc.),
-- and m_links.remove_links() to remove any links to get the raw override
-- form.
function canonicalize_override(val, args, ispl)
	if val then
		-- clean <br /> that's in many multi-form entries and messes up linking
		val = rsub(val, "<br%s*/>", "")
		local stem = ispl and args.pl or args.stem
		val = rsub(val, "~~", com.make_unstressed_once(stem))
		val = rsub(val, "~", stem)
		val = rsplit(val, "%s*,%s*")
	end
	return val
end

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
			args[case] = canonicalize_override(args[case], args, ispl)
		else
			args[case] = args.forms[case]
		end
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
