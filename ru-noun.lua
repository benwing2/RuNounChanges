--[=[
	This module contains functions for creating inflection tables for Russian
	nouns.

	Arguments:
		1: accent pattern number, or multiple numbers separated by commas
		2: stem, with ending; or leave out the ending and put it in the
		   declension type field
		3: declension type (usually just the ending); or blank or a gender
		   (m/f/n) to infer it from the full stem; append ^ to get the
		   alternate genitive plural ending (-ъ/none for masculine, -ей for
		   feminine, -ов(ъ) or variants for neuter)
		4: suffixless form (optional, default = stem); or * to infer it,
		   in which case the stem should reflect the nom sg form
		5: special plural stem (optional, default = stem)
		a: animacy (a = animate, i = inanimate, b = both, otherwise inanimate)
		n: number restriction (p = plural only, s = singular only, otherwise both)
		CASE_NUM or acc_NUM_ANIM or par/loc/voc: override (or multiple
		    values separated by commas) for particular form; forms auto-linked;
			can have raw links in it, can have an ending "note" (*, +, 1, 2, 3,
			etc.)
		arg with value "or": specify multiple stem sets; further stem sets
		    follow the "or"

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

	Number abbreviations:
		sg: singular
		pl: plural

	Animacy abbreviations:
		an: animate
		in: inanimate

TODO:

1. Change {{temp|ru-decl-noun-pl}} and {{temp|ru-decl-noun-unc}} to use
   'manual' instead of '*' as the decl class.
1a. Find places with '-' as the decl class and remove or change to #.
   All should occur where there are multiple stems, maybe only in one place
   (мальчонок?). USE TRACKING.
1b. Find places with '*' as the decl class and change to -. There is at
   least one. USE TRACKING.
1c. FIXME: Consider changing '-' to mean invariable to '^' or similar.
1d. FIXME: Add proper support for Zaliznyak b', f''.
1e. FIXME: Add ё as a "specific", using Vitalik's algorithm (rightmost е
   becomes ё).
1f. FIXME: Implement auto-stressing multisyllabic stems in accent patterns
   d and f. It appears that the plural-stem-stressed forms have the stress
   on the last stem syllable in d and on the first stem syllable in f;
   but in f it moves to the last stem syllable in the gen pl (which is
   ending-stressed). Additional trickiness ensues with words like середа́
   (1f',ё) and железа́ (1f,ё), which have nom pl се́реда and же́леза but
   gen pl серёд, желёз, so the normal way of specifying things would have
   to specify stressed се́реда,же́леза and use an explicit bare to specify
   серёд and желёз. It would be nice if they could be specified the
   Zaliznyak way and have everything work. Maybe the implementation would
   be to internally generate a stressed stem се́реда,же́леза and explicit
   bare серёд,желёз, and keep track of the fact that these aren't reducibles.
   See what Vitalik's module does. (I think Vitalik's module has at least four
   separate stems, nom sg, ins sg, nom pl, gen pl and does some magic with
   them. The ins sg stem is necessary for 8* feminine words like люво́вь, with
   reducible stem любв- in gen/dat/pre sg and throughout the plural (I think),
   but ins sg любо́вью.)
2. Require stem to be specified instead of defaulting to page. [IMPLEMENTED
   IN GITHUB]
3. Bug in -я nouns with bare specified; gen pl should not have -ь ending. Old
   templates did not add this ending when bare occurred. [SHOULD ALWAYS
   HAVE BARE BE BARE, NEVER ADD A NON-SYLLABIC ENDING. IMPLEMENTED IN GITHUB.
   TRACKING CODE PRESENT TO CHECK FOR CASES WHERE IT MIGHT BE WRONG.]
4. Remove barepl, make pl= be 5th argument. [IMPLEMENTED IN GITHUB IN TWO
   DIFFERENT BRANCHES]
5. (Add accent pattern for ь-stem numbers. Wikitiki handled that through
   overriding the ins_sg. I thought there would be complications with the
   nom_sg in multi-syllabic words but no.)
6. Eliminate complicated defaulting code for second and further stem sets.
   Should simply default to same values as the first stem set does, without
   the first stem set serving as defaults for the remainder, except that
   the stem itself can default to the previous stem set. [IMPLEMENTED IN
   GITHUB. PREVIOUSLY DIDN'T ALLOW STEM TO BE DEFAULTED AND CHANGED SOME
   NOUNS TO THAT EFFECT; UNDO THEM.]
7. Fixes for stem-multi-syllabic words with ending stress in gen pl but
   non-syllabic gen pl, with stress transferring onto final syllable even if
   stem is otherwise stressed on an earlier syllable (e.g. голова́ in
   accent pattern 6, nom pl го́ловы, gen pl голо́в). Currently these are handled
   by overriding "bare" but I want to make bare predictable mostly, just
   specifying that the noun is reducible should be enough. [IMPLEMENTED
   IN GITHUB. TRACKING CODE PRESENT TO CHECK FOR CASES WHERE IT MIGHT BE
   WRONG.]
8. If decl omitted, it should default to 1 or 2 depending on whether accent
   is on stem or ending, not always 1. [IMPLEMENTED IN GITHUB]
9. [Should recognize plural in the auto-detection code when the gender is set.
   This can be used e.g. in class 4 or 6 to avoid having to distort the accent
   in the singular.] [RECOGNIZING PLURAL IMPLEMENTED BUT COMMENTED OUT, NOT
   SURE IT'S A GOOD IDEA.] [NOTE: This is necessary for full compatibility
   with ru-decl-noun-z; we should look how Vitalik's module does things]
10. Issue an error unless allow_no_accent is given (using a * at the beginning
   of the stem). [IMPLEMENTED IN GITHUB; AT LEAST ONE WIKTIONARY ENTRY WILL
   NEED TO HAVE THE * ADDED]
11. Make it so that the plural-specifying decl classes -а, -ья, and new -ы, -и
   still auto-detect the class and convert the resulting auto-detected class
   to one with the plural variant. It's useful then to have explicit names for
   the plural-variant classes -а, -ья. I propose #-а, #-ья, which are aliases;
   the canonical name is still -a, -ья so that you can still say something like
   ин/-ья. We should similarly have # has the alias for -.  The classes
   would look like (where * means to construct a slash class)

   Orig        -а          -ья          -ы         -и
   (blank)     -а          -ья          (blank)    (blank)
   ъ           ъ-а         ъ-ья         ъ          ъ
   ь-m         *           *            *          ь-m
   а           *           *            а          а
   я           *           *            *          я
   о           о           о-ья         о-и        о-и
   е           *           *            *          *
   ь-f         *           *            *          ь-f
  [IMPLEMENTED, NEED TO TEST]
12. Add ability to specify manual translation. [IMPLEMENTED IN GITHUB FOR
   NOUNS, NOT YET FOR ADJECTIVES, NOT TESTED, ALMOST CERTAINLY HAS ERRORS]
13. Support adjective declensions. Autodetection should happen by putting +
   in decl field to indicate it's an adjective. Adjective decl types should
   begin with a +. (Formerly a * but currently that stands for "invariable".)
   [IMPLEMENTED IN GITHUB, NOT TESTED]
14. Support multiple words. [IMPLEMENTED IN GITHUB, NOT TESTED]
15. [Eliminate - as an alias for blank signifying the consonant declension;
    can use c if necessary.] -- Rethink using c for the consonant declension,
	in case we want to allow c for accent class c/3 and have the code
	auto-recognize stress pattern used in the declension field.
16. Implement (1) as an alias for certain irregular plurals, for
    compatibility with Zaliznyak.
17. Eventually: Even with decl type explicitly given, the full stem with
    ending should be included.

]=]--

local m_utilities = require("Module:utilities")
local ut = require("Module:utils")
local m_links = require("Module:links")
local com = require("Module:ru-common")
local m_ru_adj = require("Module:User:Benwing2/ru-adjective")
local m_ru_translit = require("Module:ru-translit")
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

-- Fancy version of ine() (if-not-empty). Converts empty string to nil,
-- but also strips single or double quotes, to allow for embedded spaces.
local function ine(arg)
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

-- Clone parent's args while also assigning nil to empty strings.
local function clone_args(frame)
	local args = {}
	for pname, param in pairs(frame:getParent().args) do
		args[pname] = ine(param)
	end
	return args
end

-- Old-style declensions.
local declensions_old = {}
-- New-style declensions; computed automatically from the old-style ones,
-- for the most part.
local declensions = {}
-- Category and type information corresponding to declensions: These may
-- contain the following fields: 'singular', 'plural', 'decl', 'hard', 'g',
-- 'suffix', 'gensg', 'irregpl', 'cant_reduce', 'ignore_reduce', 'stem_suffix'.
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
-- "Russian velar-stem 1st-declension hard nominals". See calls to
-- com.get_stem_trailing_letter_type(). 'stem_suffix', if present, is added to
-- the end of the stem when get_stem_trailing_letter_type() is called.
-- This is the only place that 'stem_suffix' is used. This is for use with
-- the '-ья' and '-ье' declension types, so that the trailing letter is
-- 'ь' and not whatever precedes it.
--
-- 'enable_categories' is a special hack for testing, which disables all
-- category insertion if false. Delete this as soon as we've verified the
-- working of the category code and created all the necessary categories.
local enable_categories = true
-- Whether to recognize plural stem forms given the gender.
local recognize_plurals = true
-- Category/type info corresponding to old-style declensions; see above.
local declensions_old_cat = {}
-- Category/type info corresponding to new-style declensions. Computed
-- automatically from the old-style ones, for the most part. Same format
-- as the old-style ones.
local declensions_cat = {}
-- Table listing aliases of old-style declension classes.
local declensions_old_aliases = {}
-- Table listing aliases of new-style declension classes; computed
-- automatically from the old-style ones.
local declensions_aliases = {}
-- Auto-detection functions, old-style, for a given input declension.
-- It is passed two params, (stressed) STEM and STRESS_PATTERN, and should
-- return the ouput declension.
local detect_decl_old = {}
-- Auto-detection functions, new style; computed automatically from the
-- old-style ones.
local detect_decl = {}
local sibilant_suffixes = {}
local stress_patterns = {}
-- Set of patterns with ending-stressed genitive plural.
local ending_stressed_gen_pl_patterns = {}
-- Set of patterns with ending-stressed prepositional singular.
local ending_stressed_pre_sg_patterns = {}
-- Set of patterns with ending-stressed dative singular.
local ending_stressed_dat_sg_patterns = {}
-- Set of patterns with all singular forms ending-stressed.
local ending_stressed_sg_patterns = {}
-- Set of patterns with all plural forms ending-stressed.
local ending_stressed_pl_patterns = {}
-- List of all cases that are declined normally.
local decl_cases
-- List of all cases, including those that can be overridden (loc/par/voc,
-- animate/inanimate variants).
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
local function tracking_code(stress, decl_class, real_decl_class, args, n, islast)
	assert(decl_class)
	assert(real_decl_class)
	local hint_types = com.get_stem_trailing_letter_type(args.stem)
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
	if args.bare and args.bare ~= args.stem then
		track("reducible-stem")
		dotrack("reducible-stem/")
	end
	if rlfind(args.stem, "и́?н$") and (decl_class == "" or decl_class == "#") then
		track("irregular-in")
	end
	if rlfind(args.stem, "[еёо]́?нок$") and (decl_class == "" or decl_class == "#") then
		track("irregular-onok")
	end
	if args.pltail then
		track("pltail")
	end
	if args.sgtail then
		track("sgtail")
	end
	if args.alt_gen_pl then
		track("alt-gen-pl")
	end
	for _, case in ipairs(cases) do
		if args[case .. n] then
			track("irreg/" .. case)
			track("irreg/" .. case .. n)
			-- questionable use: dotrack("irreg/" .. case .. "/")
			-- questionable use: dotrack("irreg/" .. case .. n .. "/")
		end
		if islast and args[case] then
			track("irreg/" .. case)
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
-- sibilant, etc.). N is the number of the word being processed; ISLAST
-- is true if this is the last word.
local function categorize(stress, decl_class, args, n, islast)
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

	local sghint_types = com.get_stem_trailing_letter_type(
		args.stem .. (sgdc.stem_suffix or ""))

	-- insert English version of Zaliznyak stem type
	if sgdc.decl == "invariable" then
		insert_cat("invariable ~")
	else
		local stem_type =
			sgdc.decl == "3rd" and "3rd-declension" or
			ut.contains(sghint_types, "velar") and "velar-stem" or
			ut.contains(sghint_types, "sibilant") and "sibilant-stem" or
			ut.contains(sghint_types, "c") and "ц-stem" or
			ut.contains(sghint_types, "i") and "i-stem" or
			ut.contains(sghint_types, "vowel") and "vowel-stem" or
			ut.contains(sghint_types, "soft-cons") and "vowel-stem" or
			ut.contains(sghint_types, "palatal") and "vowel-stem" or
			sgdc.hard == "soft" and "soft-stem" or
			"hard-stem"
		if sgdc.adj then
			if sgdc.possadj then
				insert_cat(sgdc.decl .. " possessive " .. gender_to_full[sgdc.g] .. " adjectival ~")
			elseif stem_type == "soft-stem" or stem_type == "vowel-stem" then
				insert_cat(stem_type .. " " .. gender_to_full[sgdc.g] .. " adjectival ~")
			else
				insert_cat(stem_type .. " " .. gender_to_full[sgdc.g] .. " accent-" .. stress .. " adjectival ~")
			end
		else
			-- NOTE: There are 8 Zaliznyak-style stem types and 3 genders, but
			-- we don't create a category for masculine-type 3rd-declension
			-- nominals (there is such a noun, путь, but it mostly behaves
			-- like a feminine noun), so there are 23.
			insert_cat(stem_type .. " " .. gender_to_full[sgdc.g] .. "-type ~")
			-- NOTE: Here we are creating categories for the combination of
			-- stem, gender and accent. There are 8 accent patterns and 23
			-- combinations of stem and gender, which potentially makes for
			-- 8*23 = 184 such categories, which is a lot. Not all such
			-- categories should actually exist; there were maybe 75 former
			-- declension templates, each of which was essentially categorized
			-- by the same three variables, but some of which dealt with
			-- ancillary issues like irregular plurals; this amounts to 67
			-- actual stem/gender/accent categories.
			insert_cat(stem_type .. " " .. gender_to_full[sgdc.g] .. "-type accent-" .. stress .. " ~")
		end
		insert_cat("~ with accent pattern " .. stress)
	end
	local sgsuffix = args.suffixes["nom_sg"]
	if sgsuffix then
		assert(#sgsuffix == 1) -- If this ever fails, then implement a loop
		sgsuffix = com.remove_accents(sgsuffix[1])
		-- If we are a plurale tantum or if nom_sg is overridden and has
		-- an unusual suffix, then don't create category for sg suffix
		if args.n == "p" or not override_matches_suffix(args["nom_sg" .. n], sgsuffix, false) or islast and not override_matches_suffix(args["nom_sg"], sgsuffix, false) then
			sgsuffix = nil
		end
	end
	local plsuffix = args.suffixes["nom_pl"]
	if plsuffix then
		assert(#plsuffix == 1) -- If this ever fails, then implement a loop
		plsuffix = com.remove_accents(plsuffix[1])
		-- If we are a singulare tantum or if nom_pl is overridden and has
		-- an unusual suffix, then don't create category for pl suffix
		if args.n == "s" or not override_matches_suffix(args["nom_pl" .. n], plsuffix, true) or islast and not override_matches_suffix(args["nom_pl"], plsuffix, true) then
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
	if args.bare and args.bare ~= args.stem then
		insert_cat("~ with reducible stem")
	end
	if args.alt_gen_pl then
		insert_cat("~ with alternate genitive plural")
	end
	if sgdc.adj then
		insert_cat("adjectival ~")
	end
	for _, case in ipairs(cases) do
		if args[case .. n] or islast and args[case] then
			local engcase = rsub(case, "^([a-z]*)", {
				nom="nominative", gen="genitive", dat="dative",
				acc="accusative", ins="instrumental", pre="prepositional",
				par="partitive", loc="locative", voc="vocative"
			})
			engcase = rsub(engcase, "(_[a-z]*)", {
				_sg=" singular", _pl=" plural",
				_an=" animate", _in=" inanimate"
			})
			if case == "loc" or case == "voc" or case == "par" then
				insert_cat("~ with " .. engcase)
			elseif not args.manual then
				insert_cat("~ with irregular " .. engcase)
			end
		end
	end
end

--------------------------------------------------------------------------
--                              Main code                               --
--------------------------------------------------------------------------

-- FIXME! Properly support b', f''
local zaliznyak_to_our_stress_pattern = {
	["a"] = "1",
	["b"] = "2",
	["b'"] = "2",
	["c"] = "3",
	["d"] = "4",
	["d'"] = "4*",
	["e"] = "5",
	["f"] = "6",
	["f'"] = "6*",
	["f''"] = "6*",
}

-- Used by do_show().
local function arg1_is_stress(arg1)
	if not arg1 then return false end
	for _, arg in ipairs(rsplit(arg1, ",")) do
		if not (rfind(arg, "^[1-6]%*?$") or rfind(arg, "^[a-f]'?'?$")) then
			return false
		end
	end
	return true
end

-- Used by do_show() and do_show_multi(), handling a word joiner argument
-- of the form 'join:JOINER'.
local function extract_word_joiner(spec)
	word_joiner = rmatch(args[i], "^join:(.*)$")
	assert(word_joiner)
	return word_joiner
end

local function do_show(frame, old)
	local args = clone_args(frame)

	old = old or args.old

	-- FIXME! Delete this when we've converted all uses of pl= args
	if args["pl"] or args["pl2"] or args["pl3"] or args["pl4"] or args["pl5"] then
		track("pl")
	end

	-- This is a list with each element corresponding to a word and
	-- consisting of a two-element list, STEM_SETS and JOINER, where STEM_SETS
	-- is a list of STEM_SET objects, one per alternative stem, and JOINER
	-- is a string indicating how to join the word to the next one.
	local per_word_info = {}

	-- Gather arguments into a list of STEM_SET objects, containing
	-- (potentially) elements 1, 2, 3, 4, 5, corresponding to accent pattern,
	-- stem, declension type, bare stem, pl stem and coming from consecutive
	-- numbered parameters. Sets of stem parameters are separated by the
	-- word "or".
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
		local end_stem_set = false
		local end_word = false
		local word_joiner
		if i == max_arg + 1 then
			end_stem_set = true
			end_word = true
			word_joiner = ""
		elseif args[i] == "_" then
			end_stem_set = true
			end_word = true
			word_joiner = " "
		elseif rfind(args[i], "^join:") then
			end_stem_set = true
			end_word = true
			word_joiner = extract_word_joiner(args[i])
		elseif args[i] == "or" then
			end_stem_set = true
		end

		if end_stem_set then
			table.insert(stem_sets, stem_set)
			stem_set = {}
			offset = i
			if end_word then
				table.insert(per_word_info, {stem_sets, word_joiner})
				stem_sets = {}
			end
		else
			-- If the first argument isn't stress, that means all arguments
			-- have been shifted to the left one. We want to shift them
			-- back to the right one, so we change the offset so that we
			-- get the same effect of skipping a slot in the stem set.
			if i - offset == 1 and not arg1_is_stress(args[i]) then
				offset = offset - 1
			end
			if i - offset > 5 then
				error("Too many arguments for stem set: arg " .. i .. " = " .. (args[i] or "(blank)"))
			end
			stem_set[i - offset] = args[i]
		end
	end

	args.old = args.old or old
	return do_show_1(args, per_word_info)
end

local function do_show_multi(frame)
	local args = clone_args(frame)

	-- This is a list with each element corresponding to a word and
	-- consisting of a two-element list, STEM_SET and JOINER, where STEM_SET
	-- is a list of STEM_SET objects, one per alternative stem, and JOINER
	-- is a string indicating how to join the word to the next one.
	local per_word_info = {}

	-- Find maximum-numbered arg, allowing for holes (FIXME: Is this needed
	-- here? Will there be holes?)
	local max_arg = 0
	for k, v in pairs(args) do
		if type(k) == "number" and k > max_arg then
			max_arg = k
		end
	end

	-- Gather arguments into a list of STEM_SET objects, containing
	-- (potentially) elements 1, 2, 3, 4, 5, corresponding to accent pattern,
	-- stem, declension type, bare stem, pl stem. They come from a single
	-- argument of the form STEM:ACCENTPATTERN:BARE:PL where all but STEM may
	-- (and probably will be) omitted and STEM may be of the following forms:
	--   STEM (for a noun with auto-detected decl class),
	--   STEM*DECL (for a noun with explicit decl class),
	--   STEM* (for an invariable word)
	--   STEM+ (for an adjective with auto-detected decl class)
	--   STEM+DECL (for an adjective with explicit decl class)
	-- Sets of stem parameters are separated by the word "or".
	local stem_sets = {}

	local continue_stem_sets = true
	for i=1,(max_arg + 1) do
		local end_word = false
		local word_joiner
		local process_arg = false
		if i == max_arg + 1 then
			end_word = true
			word_joiner = ""
		elseif args[i] == "-" then
			end_word = true
			word_joiner = "-"
		elseif rfind(args[i], "^join:") then
			end_word = true
			word_joiner = extract_word_joiner(args[i])
		elseif args[i] == "or" then
			continue_stem_sets = true
		else
			if continue_stem_sets then
				continue_stem_sets = false
			else
				end_word = true
				word_joiner = " "
			end
			process_arg = true
		end

		if end_word then
			table.insert(per_word_info, {stem_sets, word_joiner})
			stem_sets = {}
		end
		if process_arg then
			local vals = rsplit(args[i], ":")
			if #vals > 4 then
				error("Can't specify more than 4 colon-separated arguments of stem set: " .. args[i])
			end
			local stem_set = {}
			stem_set[1] = vals[2]
			stem_set[2] = vals[1]
			stem_set[3] = ""
			stem_set[4] = vals[3]
			stem_set[5] = vals[4]
			local adj_stem, adj_type = rmatch(stem_set[1], "^(.*)(%+.*)$")
			if adj_stem then
				stem_set[1] = adj_stem
				stem_set[3] = adj_type
			else
				local noun_stem, noun_type = rmatch(stem_set[1], "^(.*)%*(.*)$")
				if noun_stem then
					stem_set[1] = noun_stem
					if noun_type == "" then -- invariable
						stem_set[3] == "-"
					else
						stem_set[3] = noun_type
					end
				end
			end
			table.insert(stem_sets, stem_set)
		end
	end

	return do_show_1(args, per_word_info)
end

-- Implementation of do_show() and do_show_multi(), which have equivalent
-- functionality but different calling sequence.
function do_show_1(args, per_word_info)
	local function verify_animacy_value(val)
		if not val then return nil end
		local short = usub(val, 1, 1)
		if short == "a" or short == "i" or short == "b" then
			return short
		end
		error("Animacy value " .. val .. " should be empty or start with 'a' (animate), 'i' (inanimate), or 'b' (both)")
		return nil
	end

	local function verify_number_value(val)
		if not val then return nil end
		local short = usub(val, 1, 1)
		if short == "s" or short == "p" then
			return short
		end
		error("Number value " .. val .. " should be empty or start with 's' (singular), 'p' (plural), or 'b' (both)")
		return nil
	end

	-- Verify and canonicalize animacy and number
	for i=1,#per_word_info do
		args["a" .. i] = verify_animacy_value(args["a" .. i])
		args["n" .. i] = verify_number_value(args["n" .. i])
	end
	args.a = verify_animacy_value(args.a) or "i"
	args.n = verify_number_value(args.n) or "b"

	-- Initialize non-word-specific arguments.
	args.per_word_info = {}
	args.any_overridden = {}
	args.categories = {}
	local function insert_cat(cat)
		insert_category(args.categories, cat)
	end
	local old = args.old
	-- HACK: Escape * at beginning of line so it doesn't show up
	-- as a list entry. Many existing templates use * for footnotes.
	-- FIXME: We should maybe do this in {{ru-decl-noun}} instead.
	if args.notes then
		args.notes = rsub(args.notes, "^%*", "&#42;")
	end
	local decls = old and declensions_old or declensions
	local decl_cats = old and declensions_old_cat or declensions_cat
	local detectfuns = old and detect_decl_old or detect_decl

	local default_stem = nil

	-- Made into a function to avoid having to indent a lot of code.
	-- Process a single stem set of a single word. This inserts the forms
	-- for the word into args.forms and sets categories and tracking pages.
	local function do_stem_set(stem_set, n, islast)
		local stress_arg = stem_set[1]
		local decl_class = stem_set[3] or ""
		local bare = stem_set[4]
		local pl = stem_set[5]
		if decl_class == "manual" then
			decl_class = "-"
			args.manual = true
			if #per_word_info > 1 or #stem_sets > 1 then
				error("Can't specify multiple words or stem sets when manual")
			end
			if bare or pl then
				error("Can't specify optional stem parameters when manual")
			end
		end
		args.alt_gen_pl = rfind(decl_class, "%(2%)")
		decl_class = rsub(decl_class, "%(2%)", "")
		args.reducible = rfind(decl_class, "%*")
		decl_class = rsub(decl_class, "%*", "")
		local stem = stem_set[2] or default_stem
		if not stem then
			error("Stem in first stem set must be specified")
		end
		default_stem = stem
		local was_accented
		if rfind(decl_class, "^%+") then
			stem, decl_class, was_accented = detect_adj_type(stem, decl_class, old)
		else
			stem, decl_class, was_accented = detect_stem_type(stem, decl_class, args.a, old)
		end
		stress_arg = stress_arg or detect_stress_pattern(decl_class, was_accented)

		-- validate/canonicalize stress arg and convert to list
		stress_arg = rsplit(stress_arg, ",")
		for i=1,#stress_arg do
			stress_arg[i] = zaliznyak_to_our_stress_pattern[stress_arg[i]] or
				stress_arg[i]
		end
		for _, stress in ipairs(stress_arg) do
			if not stress_patterns[stress] then
				error("Unrecognized accent pattern " .. stress)
			end
		end
		-- convert decl type to list
		local sub_decl_classes
		if rfind(decl_class, "/") then
			track("mixed-decl")
			insert_cat("~ with mixed declension")
			local indiv_decl_classes = rsplit(decl_class, "/")
			-- Should have been caught in canonicalize_decl()
			assert(#indiv_decl_classes == 2)
			sub_decl_classes = {{indiv_decl_classes[1], "sg"}, {indiv_decl_classes[2], "pl"}}
		else
			sub_decl_classes = {{decl_class}}
		end

		if #stress_arg > 1 then
			track("multiple-accent-patterns")
			insert_cat("~ with multiple accent patterns")
		end

		local allow_unaccented = rfind(stem, "^%*")
		stem = rsub(stem, "^%*", "")

		local original_stem = stem
		local original_bare = bare
		local original_pl = pl

		-- Loop over accent patterns in case more than one given.
		for _, stress in ipairs(stress_arg) do
			args.suffixes = {}

			stem = original_stem
			bare = original_bare
			pl = original_pl

			-- it's safe to accent monosyllabic stems
			if com.is_monosyllabic(stem) then
				stem = com.make_ending_stressed(stem)
			end
			-- If all forms that use a given stem are ending-stressed, it's
			-- safe to stress the last syllable of the stem in case it's
			-- multisyllabic and unstressed; else give an error unless the
			-- user has indicated they purposely are leaving the word
			-- unstressed (e.g. due to not knowing the stress) by putting
			-- a * at the beginning of the main stem
			if com.is_unstressed(stem) then
				local all_ending_stressed = (args.n == "s" or pl) and
					ending_stressed_sg_patterns[stress] or
					args.n == "p" and ending_stressed_pl_patterns[stress] or
					stress == "2"
				if all_ending_stressed then
					stem = com.make_ending_stressed(stem)
				elseif not allow_unaccented then
					error("Stem " .. stem .. " requires an accent")
				end
			end
			if pl
				if com.is_monosyllabic(pl) then
					pl = com.make_ending_stressed(pl)
				end
			    if com.is_unstressed(pl) then
					if ending_stressed_pl_patterns[stress] then
						pl = com.make_ending_stressed(pl)
					elseif not allow_unaccented then
						error("Plural stem " .. pl .. " requires an accent")
					end
				end
			end
			local sgdecl = sub_decl_classes[1][1]
			local sgdc = decl_cats[sgdecl]
			local resolved_bare = bare
			-- Handle (un)reducibles
			if bare then
				-- FIXME: Tracking code eventually to remove; track cases
				-- where bare is explicitly specified to see how many could
				-- be predicted
				if stem == bare then
					track("explicit-bare-same-as-stem")
				elseif com.make_unstressed(stem) == com.make_unstressed(bare) then
					track("explicit-bare-different-stress")
					track("explicit-bare-different-stress-from-stem")
				elseif rfind(decl_class, "^ь-") and (stem .. "ь") == bare then
					track("explicit-bare-same-as-nom-sg")
				elseif rfind(decl_class, "^ь-") and com.make_unstressed(stem .. "ь") == com.make_unstressed(bare) then
					track("explicit-bare-different-stress")
					track("explicit-bare-different-stress-from-nom-sg")
				else
					if is_reducible(sgdc) then
						local autostem = export.reduce_nom_sg_stem(bare, sgdecl)
						if not autostem then
							track("error-reducible")
						elseif autostem == stem then
							track("explicit-bare/predictable-reducible")
						elseif com.make_unstressed(autostem) == com.make_unstressed(stem) then
							track("predictable-reducible-but-for-stress")
						else
							track("unpredictable-reducible")
						end
					elseif is_unreducible(sgdc) then
						local autobare = export.unreduce_nom_sg_stem(stem, sgdecl, stress)
						if not autobare then
							track("error-unreducible")
						elseif autobare == bare then
							track("predictable-unreducible")
						elseif com.make_unstressed(autobare) == com.make_unstressed(bare) then
							track("predictable-unreducible-but-for-stress")
						else
							track("unpredictable-unreducible")
						end
					else
						track("bare-without-reducibility")
					end
				end
			elseif args.reducible and not sgdc.ignore_reduce then
				-- Zaliznyak treats all nouns in -ье and -ья as being
				-- reducible. We handle this automatically and don't require
				-- the user to specify this, but ignore it if so for
				-- compatibility.
				if is_reducible(sgdc) then
					resolved_bare = stem
					stem = export.reduce_nom_sg_stem(stem, sgdecl, "error")
				elseif is_unreducible(sgdc) then
					resolved_bare = export.unreduce_nom_sg_stem(stem, sgdecl,
						stress, old, "error")
				else
					error("Declension class " .. sgdecl .. " not (un)reducible")
				end
			end

			if resolved_bare and com.is_monosyllabic(resolved_bare) then
				resolved_bare = com.make_ending_stressed(resolved_bare)
			end

			-- Bare should always be stressed
			if resolved_bare and com.is_unstressed(resolved_bare) and not allow_unaccented then
				error("Resolved bare stem " .. resolved_bare .. " requires an accent")
			end

			args.stem = stem
			args.bare = resolved_bare
			args.ustem = com.make_unstressed_once(stem)
			args.pl = pl or stem
			args.upl = com.make_unstressed_once(args.pl)

			-- Loop over declension classes (we may have two of them, one for
			-- singular and one for plural, in the case of a mixed declension
			-- class of the form SGDECL/PLDECL).
			for _,decl_class_spec in ipairs(sub_decl_classes) do
				-- We may resolve the user-specified declension class into a
				-- more specific variant depending on the properties of the stem
				-- and/or accent pattern. We use detection functions to do this.
				local orig_decl_class = decl_class_spec[1]
				local number = decl_class_spec[2]
				local real_decl_class = orig_decl_class
				real_decl_class = detectfuns[real_decl_class] and
					detectfuns[real_decl_class](stem, stress) or real_decl_class
				assert(decls[real_decl_class])
				tracking_code(stress, orig_decl_class, real_decl_class, args,
					n, islast)
				do_stress_pattern(stress, args, decls[real_decl_class], number)
			end

			categorize(stress, decl_class, args, n, islast)
		end
	end

	local n = 0
	for _, word_info in ipairs(per_word_info) do
		n = n + 1
		local islast = n == #per_word_info
		local stem_sets, joiner = word_info[1], word_info[2]
		args.forms = {}

		if #stem_sets > 1 then
			track("multiple-stems")
			insert_cat("~ with multiple stems")
		end

		default_stem = nil

		for _, stem_set in ipairs(stem_sets) do
			do_stem_set(stem_set, n, islast)
		end

		handle_forms_and_overrides(args, n, islast)
		table.insert(args.per_word_info, {args.forms, joiner})
	end

	handle_overall_forms_and_overrides(args)

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

-- The new entry point, esp. for multiple words (but works fine for
-- single words).
function export.show_multi(frame)
	return do_show_multi(frame)
end

local stem_expl = {
	["velar-stem"] = "a velar (-к, -г or –x)",
	["sibilant-stem"] = "a sibilant (-ш, -ж, -ч or -щ)",
	["ц-stem"] = "-ц",
	["i-stem"] = "-и (old-style -і)",
	["vowel-stem"] = "a vowel other than -и or -і, or -й or -ь",
	["soft-stem"] = "a soft consonant",
	["hard-stem"] = "a hard consonant",
}

local zaliznyak_stem_type = {
	["velar-stem"] = "3",
	["sibilant-stem"] = "4",
	["ц-stem"] = "5",
	["i-stem"] = "7",
	["vowel-stem"] = "6",
	["soft-stem"] = "2",
	["hard-stem"] = "1",
	["3rd-declension"] = "8",
}

local zaliznyak_stress_pattern = {
	["1"] = "a",
	["2"] = "b (b' for 3rd-declension feminine nouns)",
	["3"] = "c",
	["4"] = "d",
	["4*"] = "d'",
	["5"] = "e",
	["6"] = "f",
	["6*"] = "f' (f'' for 3rd-declension feminine nouns)",
}

local stem_gender_endings = {
    masculine = {
		["hard-stem"]      = {"a hard consonant (-ъ old-style)", "-ы"},
		["ц-stem"]         = {"-ц (-цъ old-style)", "-ы"},
		["velar-stem"]     = {"a velar (plus -ъ old-style)", "-и"},
		["sibilant-stem"]  = {"a sibilant (plus -ъ old-style)", "-и"},
		["soft-stem"]      = {"-ь", "-и"},
		["i-stem"]         = {"-й", "-и"},
		["vowel-stem"]     = {"-й", "-и"},
		["3rd-declension"] = {"-ь", "-и"},
	},
    feminine = {
		["hard-stem"]      = {"-а", "-ы"},
		["ц-stem"]         = {"-а", "-ы"},
		["velar-stem"]     = {"-а", "-и"},
		["sibilant-stem"]  = {"-а", "-и"},
		["soft-stem"]      = {"-я", "-и"},
		["i-stem"]         = {"-я", "-и"},
		["vowel-stem"]     = {"-я", "-и"},
		["3rd-declension"] = {"-ь", "-и"},
	},
    neuter = {
		["hard-stem"]      = {"-о", "-а"},
		["ц-stem"]         = {"-е", "-а"},
		["velar-stem"]     = {"-о", "-а"},
		["sibilant-stem"]  = {"-е", "-а"},
		["soft-stem"]      = {"-е", "-я"},
		["i-stem"]         = {"-е", "-я"},
		["vowel-stem"]     = {"-е", "-я"},
		["3rd-declension"] = {"-мя", "-мена or -мёна"},
	},
}

-- Implementation of template 'runouncatboiler'.
function export.catboiler(frame)
	local SUBPAGENAME = mw.title.getCurrentTitle().subpageText
	local args = clone_args(frame)

	local cats = {}
	insert_category(cats, "~")

	local function get_stem_gender_text(stem, gender)
		if not stem_gender_endings[gender] then
			error("Invalid gender " .. gender)
		end
		local endings = stem_gender_endings[gender][stem]
		if not endings then
			error("Invalid stem type " .. stem)
		end
		local sgending, plending = endings[1], endings[2]
		local stemtext =
			stem == "3rd-declension" and "" or
			" The stem ends in " .. stem_expl[stem] .. " and is Zaliznyak's type " .. zaliznyak_stem_type[stem] .. "."
		local decltext =
			stem == "3rd-declension" and "" or
			" This is traditionally considered to belong to the " .. (gender == "feminine" and "1st" or "2nd") .. " declension."
		return stem .. ", usually " .. gender .. " ~, normally ending in nominative singular " .. sgending .. " and nominative plural " .. plending .. "." .. stemtext .. decltext
	end

	local maintext
	if args[1] == "stemgenderstress" then
		local stem, gender, stress = rmatch(SUBPAGENAME, "^Russian (.-) (.-)%-type accent-(.-) ")
		if not stem then
			error("Invalid category name, should be e.g. \"Russian velar-stem masculine-type accent-1 nominals\"")
		end
		local stem_gender_text = get_stem_gender_text(stem, gender)
		local accent_text = " This nominal is stressed according to accent pattern " .. stress .. ", corresponding to Zaliznyak's type " .. zaliznyak_stress_pattern[stress] .. "."
		maintext = stem_gender_text .. accent_text
		insert_category(cats, "~ by stem type, gender and accent pattern")
	elseif args[1] == "stemgender" then
		if rfind(SUBPAGENAME, "invariable") then
			maintext = "invariable (indeclinable) ~, which normally have the same form for all cases and numbers."
		else
			local stem, gender = rmatch(SUBPAGENAME, "^Russian (.-) (.-)%-type")
			if not stem then
				error("Invalid category name, should be e.g. \"Russian velar-stem masculine-type nominals\"")
			end
			maintext = get_stem_gender_text(stem, gender)
		end
		insert_category(cats, "~ by stem type and gender")
	elseif args[1] == "adj" then
		local stem, gender, stress = rmatch(SUBPAGENAME, "^Russian (.*) (.-) accent-(.-) adjectival")
		if not stem then
			stem, gender = rmatch(SUBPAGENAME, "^Russian (.*) (.-) adjectival")
		end
		if not stem then
			error("Invalid category name, should be e.g. \"Russian velar-stem masculine accent-1 adjectival nominals\"")
		end
		local stemtext
		if rfind(stem, "possessive") then
			possessive = "possessive "
			stem = rsub(stem, " possessive", "")
			stemtext = ""
		else
			if not stem_expl[stem] then
				error("Invalid stem type " .. stem)
			end
			possessive = ""
			stemtext = " The stem ends in " .. stem_expl[stem] .. " and is Zaliznyak's type " .. zaliznyak_stem_type[stem] .. "."
		end
		local stresstext = stress == "1" and
			"This nominal is stressed according to accent pattern 1 (stress on the stem), corresponding to Zaliznyak's type a." or
			stress == "2" and
			"This nominal is stressed according to accent pattern 2 (stress on the ending), corresponding to Zaliznyak's type b." or
			"All nominals of this class are stressed according to accent pattern 1 (stress on the stem), corresponding to Zaliznyak's type a."
		local decl = stress == "1"
		maintext = stem .. " " .. gender .. " ~, with " .. possessive .. "adjectival endings, ending in nominative singular " .. args[2] .. " and nominative plural " .. args[3] .. "." .. stemtext .. " " .. stresstext
		insert_category(cats, "~ by stem type, gender and accent pattern")
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
		maintext = "~ with accent pattern " .. args[2] .. ", corresponding to Zaliznyak's type " .. zaliznyak_stress_pattern[args[2]] .. "."
		insert_category(cats, "~ by accent pattern")
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
-- on its ending, separating off the base and the ending. GENDER
-- may be omitted except for -ь stems, where it must be "m" or "f".
local function detect_basic_stem_type(stem, gender, anim)
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
		return base, ulower(ending)
	end
	base, ending = rmatch(stem, "^(.*)([ёоЁО]́?[нН][оО][чЧ][еЕ][кК][ъЪ]?)$")
	if base then
		return base, ulower(ending)
	end
	base, ending = rmatch(stem, "^(.*[аяАЯ]́?[нН])([иИ]́?[нН][ъЪ]?)$")
	-- Need to check the animacy to avoid nouns like маиганин, цианин,
	-- меланин, соланин, etc.
	if base and anim == "a" then
		return base, ulower(ending)
	end
	base, ending = rmatch(stem, "^(.*)([мМ][яЯ]́?)$")
	if base then
		-- We don't worry about мя-1, as it's extremely rare -- there's only
		-- one word with the declension.
		return base, ending
	end
	--recognize plural endings
	--NOT CLEAR IF THIS IS A GOOD IDEA.
	if recognize_plurals then
		if gender == "n" then
			base, ending = rmatch(stem, "^(.*)([ьЬ][яЯ]́?)$")
			if base then
				error("Ambiguous plural stem " .. stem .. " in -ья, singular could be -о or -ье/-ьё; specify the singular")
			end
			base, ending = rmatch(stem, "^(.*)([аяАЯ]́?)$")
			if base then
				return base, rfind(ending, "[аА]") and "о" or "е", ending
			end
		end
		if gender == "f" then
			base, ending = rmatch(stem, "^(.*)(ь[иИ]́?)$")
			if base then
				return base, "ья", ending
			end
		end
		if gender == "m" then
			base, ending = rmatch(stem, "^(.*)(ь[яЯ]́?)$")
			if base then
				return base, "-ья", ending
			end
			base, ending = rmatch(stem, "^(.*)([аА]́?)$")
			if base then
				return base, "-а", ending
			end
		end
		if gender == "m" or gender == "f" then
			base, ending = rmatch(stem, "^(.*[" .. com.sib .. com.velar .. "])([иИ]́?)$")
			if not base then
				base, ending = rmatch(stem, "^(.*)([ыЫ]́?)$")
			end
			if base then
				return base, gender == "m" and "" or "а", ending
			end
			base, ending = rmatch(stem, "^(.*)([иИ]́?)$")
			if base then
				if gender == "m" then
					return base, "ь-m", ending
				else
					error("Ambiguous plural stem " .. stem .. " in -и, singular could be -я or -ь; specify the singular")
				end
			end
		end
	end
	base, ending = rmatch(stem, "^(.*)([ьЬ][яеёЯЕЁ]́?)$")
	if base then
		return base, ulower(ending)
	end
	base, ending = rmatch(stem, "^(.*)([йаяеоёъЙАЯЕОЁЪ]́?)$")
	if base then
		return base, ulower(ending)
	end
	base = rmatch(stem, "^(.*)[ьЬ]$")
	if base then
		if gender == "m" or gender == "f" then
			return base, "ь-" .. gender
		else
			error("Need to specify gender m or f with stem in -ь: ".. stem)
		end
	end
	if rfind(stem, "[уыэюиіѣѵУЫЭЮИІѢѴ]́?$") then
		error("Don't know how to decline stem ending in this type of vowel: " .. stem)
	end
	return stem, ""
end

local plural_variation_detection_map = {
	[""] = {["-а"]="-а", ["-ья"]="-ья", ["-ы"]="", ["-и"]=""},
	["ъ"] = {["-а"]="ъ-а", ["-ья"]="ъ-ья", ["-ы"]="ъ", ["-и"]="ъ"},
	["й"] = {["-и"]="й", ["-я"]="й-я"},
	["ь-m"] = {["-и"]="ь-m", ["-я"]="ь-я"},
	["а"] = {["-ы"]="а", ["-и"]="а"},
	["я"] = {["-и"]="я"},
	["о"] = {["-а"]="о", ["-ья"]="о-ья", ["-ы"]="о-и", ["-о"]="о-и"},
	["е"] = {},
	["ъ-f"] = {["-и"]="ъ-f"},
}

local special_case_1_to_plural_variation = {
	[""] = "-а",
	["ъ"] = "ъ-а",
	["й"] = "й-я",
	["ь-m"] = "ь-я",
	["о"] = "о-и",
}

-- Attempt to detect the declension type (including plural variants)
-- based on the ending of the stem (or nom sg), separating off the base
-- and the ending. DECL is the value passed in and might be "", "m",
-- "f", "n", "-а", "-я", "-ья", "-ы", "-и", or "GENDER-PLURAL" using one of
-- the above genders and plurals. Gender is ignored except for -ь stems,
-- where "m" or "f" is required. The special case (1) of Zaliznyak can
-- also be given as an alternative to specifying the plural variant,
-- for certain types of plural variants.
function detect_stem_type(stem, decl, anim, old)
	local want_sc1 = rmatch(decl, "%(1%)")
	decl = rsub(decl, "%(1%)", "")
	local gender = rmatch(decl, "^([mfn]?)$")
	local plural
	if not gender then
		gender, plural = rmatch(decl, "^([mfn]?)(%-.+)$")
	end
	if gender then
		stem, decl, orig_ending = detect_basic_stem_type(stem, gender, anim)
	end
	-- A word like щи (pluralia tantum, stem щ-) should always be considered
	-- end-stressed.
	local was_accented = com.is_stressed(decl) or orig_ending and com.is_stressed(orig_ending) or com.is_vowelless(stem)
	decl = canonicalize_decl(decl, old)
	if not plural then
		if want_sc1 then
			decl = special_case_1_to_plural_variation[decl] or
				error("Special case (1) not compatible with declension " .. decl)
		end
		return stem, decl, was_accented
	end
	if want_sc1 then
		error("Special case (1) not compatible with explicit plural")
	end
	local plural_variant
	if plural_variation_detection_map[decl] then
		plural_variant = plural_variation_detection_map[decl][plural]
	end
	if plural_variant then
		return stem, plural_variant, was_accented
	else
		return stem, decl .. "/" .. plural, was_accented
	end
end

function detect_adj_type(stem, decl, old)
	local was_accented = com.is_stressed(decl)
	local base, ending
	if decl == "+" then
		base, ending = rmatch(stem, "^(.*)([ыиіьаяое]́?[йея])$")
		if base then
			was_accented = com.is_stressed(ending)
			ending = com.remove_accents(ending)
			if rfind(ending, "^[іи]й$") and rfind(base, "[" .. com.velar .. com.sib .. "]$") then
				ending = "+ый"
			-- The following is necessary for -ц, unclear if makes sense for
			-- sibilants. (Would be necessary -- I think -- if we were
			-- inferring short adjective forms, but we're not.)
			elseif ending == "ее" and rfind(base, "[" .. com.sib_c .. "]$") then
				ending = "+ое"
			else
				ending = "+" .. ending
			end
		else
			error("Cannot determine stem type of adjective: " .. stem)
		end
	elseif decl == "+short" or decl == "+mixed" then
		-- FIXME! Not clear if this works with accented endings, check it
		base, ending = rmatch(stem, "^(.-)([оеаъ]?́?)$")
		assert(base)
		was_accented = com.is_stressed(ending)
		ending = com.remove_accents(ending)
		if ending == "е" then
			ending = "о"
		end
		ending = "+" .. ending .. "-" .. usub(decl, 2)
	else
		base, ending = stem, decl
	end
	return base, canonicalize_decl(ending, old), was_accented
end

-- Detect stress pattern (1 or 2) based on whether ending is stressed or
-- decl class is inherently ending-stressed. NOTE: This function is run
-- after alias resolution and accent removal.
function detect_stress_pattern(decl, was_accented)
	-- ёнок and ёночек always bear stress
	-- not anchored to ^ or $ in case of a slash declension and old-style decls
	if rfind(decl, "ёнок") or rfind(decl, "ёночек") then
		return "2"
	-- stressed suffix и́н; missing in plural and true endings don't bear stress
	-- (except for exceptional господи́н)
	elseif rfind(decl, "ин") and was_accented then
		return "4"
	-- Adjectival -ой always bears the stress
	elseif rfind(decl, "%+ой") then
		return "2"
	-- Finally, class 2 if ending was accented by user
	elseif was_accented then
		return "2"
	else
		return "1"
	end
end

-- Canonicalize decl class into non-accented and alias-resolved form;
-- but note that some canonical decl class names with an accent in them
-- (e.g. е́, not the same as е, whose accented version is ё; and various
-- adjective declensions).
function canonicalize_decl(decl, old)
	if rfind(decl, "/") then
		local split_decl = rsplit(decl, "/")
		if #split_decl ~= 2 then
			error("Mixed declensional class " .. decl
				.. "needs exactly two classes, singular and plural")
		end
		return canonicalize_decl(split_decl[1], old) .. "/" ..
			canonicalize_decl(split_decl[2], old)
	end
	-- remove accents, but not from е́ or from adj decls
	if decl ~= "е́" and not rfind(decl, "^%+") then
		decl = com.remove_accents(decl)
	end

	local decl_aliases = old and declensions_old_aliases or declensions_aliases
	local decl_cats = old and declensions_old_cat or declensions_cat
	if decl_aliases[decl] then
		-- If we find an alias, map it, and sanity-check that there's
		-- a category entry for the result.
		decl = decl_aliases[decl]
		assert(decl_cats[decl])
	elseif not decl_cats[decl] then
		error("Unrecognized declension class " .. decl)
	end
	-- We can't yet sanity-check that there is an actual declension,
	-- because there's still the detect_decl step, which conceivably
	-- could convert the user-visible declension class (which always
	-- has a category object) to an internal declension variant.
	-- We don't much do this any more, but it's still possible.
	return decl
end

function is_reducible(decl_cat)
	if decl_cat.suffix or decl_cat.cant_reduce then
		return false
	elseif decl_cat.decl == "3rd" and decl_cat.g == "f" or decl_cat.g == "m" then
		return true
	else
		return false
	end
end

-- Reduce nom sg to stem by eliminating the "epenthetic" vowel. Applies to
-- masculine 2nd-declension hard and soft, and 3rd-declension feminine in
-- -ь. STEM and DECL are after detect_stem_type(), before converting
-- outward-facing declensions to inward ones.
function export.reduce_nom_sg_stem(stem, decl, can_err)
	local full_stem = stem .. (decl == "й" and decl or "")
	local ret = com.reduce_stem(full_stem)
	if not ret and can_err then
		error("Unable to reduce stem " .. stem)
	end
	return ret
end

function is_unreducible(decl_cat)
	if decl_cat.suffix or decl_cat.cant_reduce then
		return false
	elseif decl_cat.decl == "1st" or decl_cat.decl == "2nd" and decl_cat.g == "n" then
		return true
	else
		return false
	end
end

-- Unreduce stem to the form found in the gen pl by inserting an epenthetic
-- vowel. Applies to 1st declension and 2nd declension neuter. STEM and DECL
-- are after detect_stem_type(), before converting outward-facing declensions
-- to inward ones. STRESS is the stess pattern.
function export.unreduce_nom_sg_stem(stem, decl, stress, old, can_err)
	local epenthetic_stress = ending_stressed_gen_pl_patterns[stress]
	local ret = com.unreduce_stem(stem, epenthetic_stress)
	if not ret then
		if can_err then
			error("Unable to unreduce stem " .. stem)
		else
			return nil
		end
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
			-- FIXME: What happens in this case old-style? I assume that
			-- -ъ is added, but this is a guess.
			return ret .. (old and "ъ" or "")
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

-- This needs to be up here because it is called just below.
local function old_to_new(v)
	v = rsub(v, "ъ$", "")
	v = rsub(v, "^ъ", "")
	v = rsub(v, "(%A)ъ", "%1")
	v = rsub(v, "ъ(%A)", "%1")
	v = rsub(v, "і", "и")
	v = rsub(v, "ѣ", "е")
	return v
end

----------------- Masculine hard -------------------

-- Hard-masculine declension, ending in a hard consonant
-- (ending in -ъ, old-style).
declensions_old["ъ"] = {
	["nom_sg"] = "ъ",
	["gen_sg"] = "а́",
	["dat_sg"] = "у́",
	["acc_sg"] = nil,
	["ins_sg"] = "о́мъ",
	["pre_sg"] = "ѣ́",
	["nom_pl"] = "ы́",
	["gen_pl"] = function(stem, stress)
		return sibilant_suffixes[ulower(usub(stem, -1))] and "е́й" or "о́въ"
	end,
	["alt_gen_pl"] = "ъ",
	["dat_pl"] = "а́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "а́ми",
	["pre_pl"] = "а́хъ",
}

declensions_old_cat["ъ"] = { decl="2nd", hard="hard", g="m" }

-- Normal mapping of old ъ would be "" (blank), but we set up "#" as an alias
-- so we have a way of referring to it without defaulting if need be and
-- distinct from auto-detection (e.g. in the second stem of a word, or to
-- override autodetection of -ёнок or -ин -- the latter is necessary in the
-- case of семьянин).
declensions_aliases["#"] = ""

----------------- Masculine hard, irregular plural -------------------

-- Hard-masculine declension, ending in a hard consonant
-- (ending in -ъ, old-style), with irreg nom pl -а.
declensions_old["ъ-а"] = mw.clone(declensions_old["ъ"])
declensions_old["ъ-а"]["nom_pl"] = "а́"

declensions_old_cat["ъ-а"] = { decl="2nd", hard="hard", g="m", irregpl=true }
declensions_cat["-а"] = {
	singular = "ending in a consonant",
	decl="2nd", hard="hard", g="m", irregpl=true
}
declensions_aliases["#-a"] = "-a"

-- Hard-masculine declension, ending in a hard consonant
-- (ending in -ъ, old-style), with irreg soft pl -ья.
-- Differs from the normal declension throughout the plural.
declensions_old["ъ-ья"] = {
	["nom_sg"] = "ъ",
	["gen_sg"] = "а́",
	["dat_sg"] = "у́",
	["acc_sg"] = nil,
	["ins_sg"] = "о́мъ",
	["pre_sg"] = "ѣ́",
	["nom_pl"] = "ья́",
	["gen_pl"] = function(stem, stress)
		return sibilant_suffixes[ulower(usub(stem, -1))] and "е́й" or "ьёвъ"
	end,
	["alt_gen_pl"] = "ь",
	["dat_pl"] = "ья́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "ья́ми",
	["pre_pl"] = "ья́хъ",
}

declensions_old_cat["ъ-ья"] = { decl="2nd", hard="hard", g="m", irregpl=true }
declensions_cat["-ья"] = {
	singular = "ending in a consonant",
	decl="2nd", hard="hard", g="m", irregpl=true,
}
declensions_aliases["#-ья"] = "-ья"

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
	["gen_pl"] = "я́тъ",
	["dat_pl"] = "я́тамъ",
	["acc_pl"] = nil,
	["ins_pl"] = "я́тами",
	["pre_pl"] = "я́тахъ",
}
declensions_old_cat["ёнокъ"] = { decl="2nd", hard="hard", g="m", suffix=true }

declensions_old_aliases["онокъ"] = "ёнокъ"
declensions_old_aliases["енокъ"] = "ёнокъ"

declensions_old["ёночекъ"] = {
	["nom_sg"] = "ёночекъ",
	["gen_sg"] = "ёночка",
	["dat_sg"] = "ёночку",
	["acc_sg"] = nil,
	["ins_sg"] = "ёночкомъ",
	["pre_sg"] = "ёночкѣ",
	["nom_pl"] = "я́тки",
	["gen_pl"] = "я́токъ",
	["dat_pl"] = "я́ткамъ",
	["acc_pl"] = nil,
	["ins_pl"] = "я́тками",
	["pre_pl"] = "я́ткахъ",
}
declensions_old_cat["ёночекъ"] = { decl="2nd", hard="hard", g="m", suffix=true }

declensions_old_aliases["оночекъ"] = "ёночекъ"
declensions_old_aliases["еночекъ"] = "ёночекъ"

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
	["alt_gen_pl"] = "ь",
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

-- Masculine declension in palatal -й
declensions_old["й"] = {
	["nom_sg"] = "й",
	["gen_sg"] = "я́",
	["dat_sg"] = "ю́",
	["acc_sg"] = nil,
	["ins_sg"] = "ёмъ",
	["pre_sg"] = function(stem, stress)
		return rlfind(stem, "[іи]́?$") and "и́" or "ѣ́"
	end,
	["nom_pl"] = "и́",
	["gen_pl"] = "ёвъ",
	["alt_gen_pl"] = "й",
	["dat_pl"] = "я́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "я́ми",
	["pre_pl"] = "я́хъ",
}

declensions_old_cat["й"] = { decl="2nd", hard="palatal", g="m" }

declensions_old["й-я"] = mw.clone(declensions_old["й"])
declensions_old["й-я"]["nom_pl"] = "я́"

declensions_old_cat["й-я"] = { decl="2nd", hard="palatal", g="m", irregpl=true }

--------------------------------------------------------------------------
--                       First-declension feminine                      --
--------------------------------------------------------------------------

----------------- Feminine hard -------------------

-- Hard-feminine declension in -а
declensions_old["а"] = {
	["nom_sg"] = "а́",
	["gen_sg"] = "ы́",
	["dat_sg"] = "ѣ́",
	["acc_sg"] = "у́",
	["ins_sg"] = {"о́й<insa>", "о́ю<insb>"}, -- see show_form_1()
	["pre_sg"] = "ѣ́",
	["nom_pl"] = "ы́",
	["gen_pl"] = function(stem, stress)
		return sibilant_suffixes[ulower(usub(stem, -1))] and ending_stressed_gen_pl_patterns[stress] and "е́й" or "ъ"
	end,
	["alt_gen_pl"] = "е́й",
	["dat_pl"] = "а́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "а́ми",
	["pre_pl"] = "а́хъ",
}

declensions_old_cat["а"] = { decl="1st", hard="hard", g="f" }

----------------- Feminine soft -------------------

-- Soft-feminine declension in -я
declensions_old["я"] = {
	["nom_sg"] = "я́",
	["gen_sg"] = "и́",
	["dat_sg"] = function(stem, stress)
		return rlfind(stem, "[іи]́?$") and not ending_stressed_dat_sg_patterns[stress] and "и" or "ѣ́"
	end,
	["acc_sg"] = "ю́",
	["ins_sg"] = {"ёй<insa>", "ёю<insb>"}, -- see show_form_1()
	["pre_sg"] = function(stem, stress)
		return rlfind(stem, "[іи]́?$") and not ending_stressed_pre_sg_patterns[stress] and "и" or "ѣ́"
	end,
	["nom_pl"] = "и́",
	["gen_pl"] = "й",
	["alt_gen_pl"] = "е́й",
	["dat_pl"] = "я́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "я́ми",
	["pre_pl"] = "я́хъ",
}

declensions_old_cat["я"] = { decl="1st", hard="soft", g="f" }

-- Soft-feminine declension in -ья.
-- Almost like ь + -я endings except for genitive plural.
declensions_old["ья"] = {
	["nom_sg"] = "ья́",
	["gen_sg"] = "ьи́",
	["dat_sg"] = "ьѣ́",
	["acc_sg"] = "ью́",
	["ins_sg"] = {"ьёй<insa>", "ьёю<insb>"}, -- see show_form_1()
	["pre_sg"] = "ьѣ́",
	["nom_pl"] = "ьи́",
	["gen_pl"] = function(stem, stress)
		-- circumflex accent is a signal that forces stress, particularly
		-- in accent pattern 4.
		return (ending_stressed_gen_pl_patterns[stress] or stress == "4" or stress == "4*") and "е̂й" or "ий"
	end,
	["dat_pl"] = "ья́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "ья́ми",
	["pre_pl"] = "ья́хъ",
}

declensions_old_cat["ья"] = {
	decl="1st", hard="soft", g="f",
	stem_suffix="ь", gensg=true,
	ignore_reduce=true -- already has unreduced gen pl
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
	["alt_gen_pl"] = "о́въ",
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

declensions_old_aliases["о-ы"] = "о-и"

-- Hard-neuter declension in -о with irreg soft pl -ья;
-- differs throughout the plural from normal -о.
declensions_old["о-ья"] = {
	["nom_sg"] = "о́",
	["gen_sg"] = "а́",
	["dat_sg"] = "у́",
	["acc_sg"] = "о́",
	["ins_sg"] = "о́мъ",
	["pre_sg"] = "ѣ́",
	["nom_pl"] = "ья́",
	["gen_pl"] = function(stem, stress)
		return sibilant_suffixes[ulower(usub(stem, -1))] and "е́й" or "ьёвъ"
	end,
	["alt_gen_pl"] = "ь",
	["dat_pl"] = "ья́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "ья́ми",
	["pre_pl"] = "ья́хъ",
}

declensions_old_cat["о-ья"] = { decl="2nd", hard="hard", g="n", irregpl=true }

----------------- Neuter soft -------------------

-- Soft-neuter declension in -е (stressed -ё)
declensions_old["е"] = {
	["nom_sg"] = "ё",
	["gen_sg"] = "я́",
	["dat_sg"] = "ю́",
	["acc_sg"] = "ё",
	["ins_sg"] = "ёмъ",
	["pre_sg"] = function(stem, stress)
		return rlfind(stem, "[іи]́?$") and not ending_stressed_pre_sg_patterns[stress] and "и" or "ѣ́"
	end,
	["nom_pl"] = "я́",
	["gen_pl"] = function(stem, stress)
		return rlfind(stem, "[іи]́?$") and "й" or "е́й"
	end,
	["alt_gen_pl"] = "е́въ",
	["dat_pl"] = "я́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "я́ми",
	["pre_pl"] = "я́хъ",
}

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
declensions_old_aliases["ё"] = "е"

-- Rare soft-neuter declension in stressed -е́ (e.g. муде́, бытие́)
declensions_old["е́"] = {
	["nom_sg"] = "е́",
	["gen_sg"] = "я́",
	["dat_sg"] = "ю́",
	["acc_sg"] = "е́",
	["ins_sg"] = "е́мъ",
	["pre_sg"] = function(stem, stress)
		-- FIXME!!! Are we sure about this condition? This is what was
		-- found in the old template, but the related -е declension has
		-- -ие prep sg ending -(и)и only when *not* stressed.
		return rlfind(stem, "[іи]́?$") and "и́" or "ѣ́"
	end,
	["nom_pl"] = "я́",
	["gen_pl"] = function(stem, stress)
		return rlfind(stem, "[іи]́?$") and "й" or "е́й"
	end,
	["alt_gen_pl"] = "ёвъ",
	["dat_pl"] = "я́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "я́ми",
	["pre_pl"] = "я́хъ",
}

declensions_old_cat["е́"] = {
	singular = "ending in stressed -е",
	decl="2nd", hard="soft", g="n", gensg=true
}

-- Soft-neuter declension in unstressed -ье (stressed -ьё).
declensions_old["ье"] = {
	["nom_sg"] = "ьё",
	["gen_sg"] = "ья́",
	["dat_sg"] = "ью́",
	["acc_sg"] = "ьё",
	["ins_sg"] = "ьёмъ",
	["pre_sg"] = "ьѣ́",
	["nom_pl"] = "ья́",
	["gen_pl"] = function(stem, stress)
		return ending_stressed_gen_pl_patterns[stress] and "е́й" or "ий"
	end,
	["alt_gen_pl"] = "ьёвъ",
	["dat_pl"] = "ья́мъ",
	["acc_pl"] = nil,
	["ins_pl"] = "ья́ми",
	["pre_pl"] = "ья́хъ",
}

declensions_old_cat["ье"] = {
	decl="2nd", hard="soft", g="n",
	stem_suffix="ь", gensg=true,
	ignore_reduce=true -- already has unreduced gen pl
}

declensions_old_aliases["ьё"] = "ье"

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

declensions_old_cat["мя"] = { decl="3rd", hard="soft", g="n", cant_reduce=true }

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

declensions_old_cat["мя-1"] = { decl="3rd", hard="soft", g="n", cant_reduce=true }

--------------------------------------------------------------------------
--                              Invariable                              --
--------------------------------------------------------------------------

-- Invariable declension; no endings.
declensions_old["-"] = {
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
declensions_old_cat["-"] = { decl="invariable", hard="none", g="none" }

--------------------------------------------------------------------------
--                              Adjectival                              --
--------------------------------------------------------------------------

local adj_decl_map = {
	{"ый", "ый", "ое", "ая", "hard", "long", false},
	{"ій", "ій", "ее", "яя", "soft", "long", false},
	{"ой", "о́й", "о́е", "а́я", "hard", "long", false},
	{"ьій", "ьій", "ье", "ья", "palatal", "long", true},
	{"short", "ъ-short", "о-short", "а-short", "hard", "short", true},
	{"mixed", "ъ-mixed", "о-mixed", "а-mixed", "hard", "mixed", true},
}

local function get_adjectival_decl(adjtype, gender, old)
	local decl = m_ru_adj.get_nominal_decl(adjtype, gender, old)
	-- signal to make_table() to use the special tr_adj() function so that
	-- -го gets transliterated to -vo
	decl["gen_sg"] = rsub(decl["gen_sg"], "го$", "го<adj>")
	-- hack fem ins_sg to insert <insa>, <insb>; see show_form_1()
	if gender == "f" and type(decl["ins_sg"]) == "table" and #decl["ins_sg"] == 2 then
		decl["ins_sg"][1] = decl["ins_sg"][1] .. "<insa>"
		decl["ins_sg"][2] = decl["ins_sg"][2] .. "<insb>"
	end
	return decl
end

for _, declspec in ipairs(adj_decl_map) do
	local oadjdecl = declspec[1]
	local nadjdecl = old_to_new(oadjdecl)
	local odecl = {m="+" .. declspec[2], n="+" .. declspec[3], f="+" .. declspec[4]}
	local hard = declspec[5]
	local decltype = declspec[6]
	local possadj = declspec[7]
	for _, g in ipairs({"m", "n", "f"}) do
		declensions_old[odecl[g]] =
			get_adjectival_decl(oadjdecl, g, true)
		declensions[old_to_new(odecl[g])] =
			get_adjectival_decl(nadjdecl, g, false)
		declensions_old_cat[odecl[g]] = {
			decl=decltype, hard=hard, g=g, adj=true, possadj=possadj }
		declensions_cat[old_to_new(odecl[g])] = {
			decl=decltype, hard=hard, g=g, adj=true, possadj=possadj }
	end
end

-- Set up some aliases. е-short and е-mixed exist because е instead of о
-- appears after sibilants and ц.
declensions_old_aliases["+ой"] = "+о́й"
declensions_old_aliases["+е-short"] = "+о-short"
declensions_old_aliases["+е-mixed"] = "+о-mixed"

-- Convert ій/ий to ый after velar or sibilant. This is important for
-- velars; doesn't really matter one way or the other for sibilants as
-- the sibilant rules will convert both sets of endings to the same thing
-- (whereas there will be a difference with о vs. е for velars).
detect_decl_old["+ій"] = function(stem, stress)
	if rfind(stem, "[" .. com.velar .. com.sib .. "]$") then
		return "+ый"
	else
		return "+ій"
	end
end

-- Convert ее to ое after sibilant or ц. This is important for ц;
-- doesn't really matter one way or the other for sibilants as
-- the sibilant rules will convert both sets of endings to the same thing
-- (whereas there will be a difference with ы vs. и for ц).
detect_decl_old["+ее"] = function(stem, stress)
	if rfind(stem, "[" .. com.sib_c .. "]$") then
		return "+ое"
	else
		return "+ее"
	end
end

-- For stressed and unstressed ое and ая, convert to the right stress
-- variant according to the stress pattern (1 or 2).
detect_decl_old["+ое"] = function(stem, stress)
	if stress == "2" then
		return "+о́е"
	else
		return "+ое"
	end
end
detect_decl_old["+о́е"] = detect_decl_old["+ое"]

detect_decl_old["+ая"] = function(stem, stress)
	if stress == "2" then
		return "+а́я"
	else
		return "+ая"
	end
end
detect_decl_old["+а́я"] = detect_decl_old["+ая"]

--------------------------------------------------------------------------
--                         Populate new from old                        --
--------------------------------------------------------------------------

-- Function to convert an entry in an old declensions table to new.
local function old_decl_entry_to_new(v)
	if type(v) == "table" then
		local new_entry = {}
		for _, i in ipairs(v) do
			table.insert(new_entry, old_decl_entry_to_new(i))
		end
		return new_entry
	elseif type(v) == "function" then
		return function(stem, suffix)
			return old_decl_entry_to_new(v(stem, suffix))
		end
	else
		return old_to_new(v)
	end
end

-- Function to convert an old declensions table to new.
local function old_decl_to_new(odecl)
	local ndecl = {}
	for k, v in pairs(odecl) do
		ndecl[k] = old_decl_entry_to_new(v)
	end
	return ndecl
end

-- Function to convert an entry in an old declensions_cat table to new.
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

-- Function to convert an old declensions_cat table to new.
local function old_decl_cat_to_new(odeclcat)
	local ndeclcat = {}
	for k, v in pairs(odeclcat) do
		ndeclcat[k] = old_decl_cat_entry_to_new(v)
	end
	return ndeclcat
end

-- Function to convert an old detect_decl function to new one.
local function old_detect_decl_to_new(ofunc)
	return function(stem, stress)
		return old_to_new(ofunc(stem, stress))
	end
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

-- populate declensions_aliases[] from declensions_old_aliases[]
for ofrom, oto in pairs(declensions_old_aliases) do
	local from = old_to_new(ofrom)
	if not declensions_aliases[from] then
		declensions_aliases[from] = old_to_new(oto)
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

sibilant_suffixes = ut.list_to_set({"ш", "щ", "ч", "ж"})

local function combine_stem_and_suffix(stem, suf, rules, old)
	local first = usub(suf, 1, 1)
	if rules then
		local conv = rules[first]
		if conv then
			local ending = usub(suf, 2)
			if old and conv == "и" and mw.ustring.find(ending, "^́?[" .. com.vowel .. "]") then
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
local function attach_unstressed(args, case, suf, was_stressed)
	if suf == nil then
		return nil, nil
	elseif rfind(suf, "̂") then -- if suf has circumflex accent, it forces stressed
		return attach_stressed(args, case, suf)
	end
	local is_pl = rfind(case, "_pl")
	local old = args.old
	local stem = is_pl and args.pl or args.stem
	if old and old_consonantal_suffixes[suf] or not old and consonantal_suffixes[suf] then
		local barestem = args.bare or stem
		if was_stressed and case == "gen_pl" then
			if not args.bare then
				local gen_pl_stem = com.make_ending_stressed(stem)
				-- FIXME: temporary tracking code to identify places where
				-- the change to the algorithm here that end-stresses the
				-- genitive plural in stress patterns with gen pl end stress
				-- (cf. words like голова́, with nom pl. го́ловы but gen pl.
				-- голо́в) would cause changes.
				if com.is_stressed(stem) and stem ~= gen_pl_stem then
					track("gen-pl-moved-stress")
				end
				barestem = gen_pl_stem
			end
		end

		if rlfind(barestem, old and "[йьъ]$" or "[йь]$") then
			suf = ""
		else
			if suf == "ъ" then
				-- OK
			elseif suf == "й" or suf == "ь" then
				if args.bare and case == "gen_pl" then
					-- FIXME: temporary tracking code
					track("explicit-bare-no-suffix")
					if old then
						track("explicit-bare-old-no-suffix")
					end
					-- explicit bare or reducible, don't add -ь
					suf = ""
				elseif rfind(barestem, "[" .. com.vowel .. "]́?$") then
					-- not reducible, do add -ь and correct to -й if necessary
					suf = "й"
				else
					suf = "ь"
				end
			end
		end
		return barestem .. suf, suf
	end
	suf = com.make_unstressed(suf)
	local rules = unstressed_rules[ulower(usub(stem, -1))]
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
		return attach_unstressed(args, case, suf, "was stressed")
	end
	local is_pl = rfind(case, "_pl")
	local old = args.old
	local stem = is_pl and args.upl or args.ustem
	local rules = stressed_rules[ulower(usub(stem, -1))]
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
local function gen_form(args, decl, case, stress, fun)
	if not args.forms[case] then
		args.forms[case] = {}
	end
	if not args.suffixes[case] then
		args.suffixes[case] = {}
	end
	local suf = decl[case]
	if type(suf) == "function" then
		suf = suf(args.stem, stress)
	end
	if case == "gen_pl" and args.alt_gen_pl then
		suf = decl.alt_gen_pl
		if not suf then
			error("No alternate genitive plural available for this declension class")
		end
	end
	local combineds, realsufs = attach_with(args, case, suf, fun)
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

function do_stress_pattern(stress, args, decl, number)
	for _, case in ipairs(decl_cases) do
		if not number or (number == "sg" and rfind(case, "_sg")) or
			(number == "pl" and rfind(case, "_pl")) then
			gen_form(args, decl, case, stress,
				attachers[stress_patterns[stress][case]])
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

ending_stressed_gen_pl_patterns = ut.list_to_set({"2", "3", "5", "6", "6*"})
ending_stressed_pre_sg_patterns = ut.list_to_set({"2", "4", "4*", "6", "6*"})
ending_stressed_dat_sg_patterns = ending_stressed_pre_sg_patterns
ending_stressed_sg_patterns = ending_stressed_pre_sg_patterns
ending_stressed_pl_patterns = ut.list_to_set({"2", "3"})

local after_titles = {
	["a"] = " (animate)",
	["i"] = " (inanimate)",
	["b"] = "",
}

local numbers = {
	["s"] = "singular",
	["p"] = "plural",
}

local old_title_temp = [=[Pre-reform declension of <b lang="ru" class="Cyrl">{lemma}</b>]=]
local title_temp = [=[Declension of <b lang="ru" class="Cyrl">{lemma}</b>]=]

local partitive = nil
local locative = nil
local vocative = nil
local notes_template = nil
local templates = {}

-- cases that are declined normally instead of handled through overrides
decl_cases = {
	"nom_sg", "gen_sg", "dat_sg", "acc_sg", "ins_sg", "pre_sg",
	"nom_pl", "gen_pl", "dat_pl", "acc_pl", "ins_pl", "pre_pl",
}

-- all cases displayable or handleable through overrides
cases = {
	"nom_sg", "gen_sg", "dat_sg", "acc_sg", "ins_sg", "pre_sg",
	"nom_pl", "gen_pl", "dat_pl", "acc_pl", "ins_pl", "pre_pl",
	"acc_sg_an", "acc_sg_in", "acc_pl_an", "acc_pl_in",
	"par", "loc", "voc",
}

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

local function substitute_locative_partitive(forms, dat_sg, ispar)
	-- handle + in loc/par meaning "the expected form"
	local new_forms = {}
	for _, form in ipairs(forms) do
		-- don't just handle + by itself in case the form has в or на
		-- or whatever attached to it
		if rfind(form, "^%+") or rfind(form, "[%s%[|]%+") then
			for _, dat in ipairs(dat_sg) do
				local subval = ispar and dat or com.make_ending_stressed(dat)
				-- wrap the word in brackets so it's linked; but not if it
				-- appears to already be linked
				local newform = rsub(form, "^%+", "[[" .. subval .. "]]")
				newform = rsub(newform, "([%[|])%+", "%1" .. subval)
				newform = rsub(newform, "(%s)%+", "%1[[" .. subval .. "]]")
				table.insert(new_forms, newform)
			end
		else
			table.insert(new_forms, form)
		end
	end
	return new_forms
end

function handle_forms_and_overrides(args, n, islast)
	local f = args.forms
	for _, case in ipairs(cases) do
		local ispl = rfind(case, "_pl")
		if islast then
			if args.sgtail and not ispl and f[case] then
				local lastarg = #(f[case])
				if lastarg > 0 then
					f[case][lastarg] = f[case][lastarg] .. args.sgtail
				end
			end
			if args.pltail and ispl and f[case] then
				local lastarg = #(f[case])
				if lastarg > 0 then
					f[case][lastarg] = f[case][lastarg] .. args.pltail
				end
			end
		end
		if args[case .. n] then
			f[case] = canonicalize_override(args[case .. n], args, ispl)
			args.any_overridden[case] = true
		end
	end

	-- handle + in loc/par meaning "the expected form"
	for _, case in ipairs({"loc", "par"}) do
		if args[case .. n] then
			f[case] = substitute_locative_partitive(f[case],
				f["dat_sg"], case == "par")
		end
	end

	for _, case in ipairs(cases) do
		if f[case] then
			if type(f[case]) ~= "table" then
				error("Logic error, args[case] should be nil or table")
			end
			if #f[case] == 0 then
				f[case] = nil
			end
		end
	end

	local an = args["a" .. n] or args["a"]
	f.acc_sg_an = f.acc_sg_an or f.acc_sg or an == "i" and f.nom_sg or f.gen_sg
	f.acc_sg_in = f.acc_sg_in or f.acc_sg or an == "a" and f.gen_sg or f.nom_sg
	f.acc_pl_an = f.acc_pl_an or f.acc_pl or an == "i" and f.nom_pl or f.gen_pl
	f.acc_pl_in = f.acc_pl_in or f.acc_pl or an == "a" and f.gen_pl or f.nom_pl

	f.loc = f.loc or f.pre_sg
	f.par = f.par or f.gen_sg
	f.voc = f.voc or f.nom_sg
	-- Set these in case we have a plurale tantum, in which case the
	-- singular will also get set to these same values in case we are
	-- a plural-only word in a singular-only expression. NOTE: It's actually
	-- unnecessary to do "f.loc_pl = f.loc_pl or f.pre_pl" as f.loc_pl should
	-- never previously be set.
	f.loc_pl = f.loc_pl or f.pre_pl
	f.par_pl = f.par_pl or f.gen_pl
	f.voc_pl = f.voc_pl or f.nom_pl

	local nu = f["n" .. n] or f["n"]
	-- If we have a singular-only, set the plural forms to the singular forms,
	-- and vice-versa. This is important so that things work in multi-word
	-- expressions that combine different number restrictions (e.g.
	-- singular-only with singular/plural or singular-only with plural-only,
	-- cf. "St. Vincent and the Grenadines" [Санкт-Винцент и Гренадины]).
	if nu == "s" then
		f.nom_pl = f.nom_sg
		f.gen_pl = f.gen_sg
		f.dat_pl = f.dat_sg
		f.acc_pl = f.acc_sg
		f.acc_pl_an = f.acc_sg_an
		f.acc_pl_in = f.acc_sg_in
		f.ins_pl = f.ins_sg
		f.pre_pl = f.pre_sg
		f.nom_pl = f.nom_sg
		-- Unnecessary because only used below to initialize singular
		-- loc/par/voc with pluralia tantum.
		-- f.loc_pl = f.loc
		-- f.par_pl = f.par
		-- f.voc_pl = f.voc
	elseif nu == "p" then
		f.nom_sg = f.nom_pl
		f.gen_sg = f.gen_pl
		f.dat_sg = f.dat_pl
		f.acc_sg = f.acc_pl
		f.acc_sg_an = f.acc_pl_an
		f.acc_sg_in = f.acc_pl_in
		f.ins_sg = f.ins_pl
		f.pre_sg = f.pre_pl
		f.nom_sg = f.nom_pl
		f.loc = f.loc_pl
		f.par = f.par_pl
		f.voc = f.voc_pl
	end
end

function handle_overall_forms_and_overrides(args)
	for _, case in ipairs(cases) do
		local ispl = rfind(case, "_pl")
		if args[case] then
			args[case] = canonicalize_override(args[case], args, ispl)
			args.per_word_info[case] = {{canonicalize_override(args[case], args, ispl), ""}}
			args.any_overridden[case] = true
		end
	end

	-- Handle + in loc/par meaning "the expected form". HACK: For +, only
	-- substitute the forms from the last word. This will work in the
	-- majority of cases where there's only one word, and it's too
	-- complicated to get working more generally (and not necessarily even
	-- well-defined; the user should use word-specific overrides).
	for _, case in ipairs({"loc", "par"}) do
		if args[case] then
			local nwords = #args.per_word_info
			local subbed = substitute_locative_partitive(args[case],
				args.per_word_info[nwords][1]["dat_sg"], case == "par")
			args.per_word_info[case] == {{subbed, ""}}
		end
	end
end

-- Subfunction of show_form(), used to implement recursively generating
-- all combinations of elements from WORD_FORMS (a list, one element per
-- word, of a list of the forms for a word) and TRAILING_FORMS (a list of
-- forms, the accumulated suffixes for trailing words so far in the
-- recursion process). Each time we recur we take the last FORMS item
-- off of WORD_FORMS and to each form in FORMS we add al elements in
-- TRAILING_FORMS, passing the newly generated list of items down the
-- next recursion level with the shorter WORD_FORMS. We end up
-- returning a string to insert into the Wiki-markup table.
function show_form_1(word_forms, trailing_forms, old, prefix, suffix, lemma)
	if #word_forms == 0 then
		local russianvals = {}
		local latinvals = {}
		local lemmavals = {}

		-- Accumulate separately the Russian and transliteration into
		-- RUSSIANVALS and LATINVALS, then concatenate each down below.
		-- However, if LEMMA, we put each transliteration directly
		-- after the corresponding Russian, in parens, and put the results
		-- in LEMMAVALS, which get concatenated below. (This is used in the
		-- title of the declension table.) (Actually, currently we don't
		-- include the translit in the declension table title.)

		if #trailing_forms == 1 and trailing_forms[1] == "-" then
			return "&mdash;"
		end

		for _, form in ipairs(trailing_forms) do
			local is_adj = rfind(form, "<adj>")
			form = rsub(form, "<adj>", "")
			-- Remove <insa> and <insb> markers; they've served their purpose.
			form = rsub(form, "<ins[ab]>", "")
			local entry, notes = m_table_tools.get_notes(form)
			entry = prefix .. entry .. suffix
			local ruspan, trspan
			if old then
				ruspan = m_links.full_link(com.make_unstressed(entry), entry, lang, nil, nil, nil, {tr = "-"}, false) .. notes
			else
				ruspan = m_links.full_link(entry, nil, lang, nil, nil, nil, {tr = "-"}, false) .. notes
			end
			local nolinks = m_links.remove_links(entry)
			trspan = (is_adj and m_ru_translit.tr_adj(nolinks) or lang:transliterate(nolinks)) .. notes
			trspan = "<span style=\"color: #888\">" .. trspan .. "</span>"

			if lemma then
				-- ut.insert_if_not(lemmavals, ruspan .. " (" .. trspan .. ")")
				ut.insert_if_not(lemmavals, ruspan)
			else
				ut.insert_if_not(russianvals, ruspan)
				ut.insert_if_not(latinvals, trspan)
			end
		end

		if lemma then
			return table.concat(lemmavals, ", ")
		else
			local russian_span = table.concat(russianvals, outersep)
			local latin_span = table.concat(latinvals, outersep)
			return russian_span .. "<br />" .. latin_span
		end
	else
		local last_form_info = table.remove(word_forms)
		local last_forms, joiner = last_form_info[1], last_form_info[2]
		local new_trailing_forms = {}
		for _, form in ipairs(last_forms) do
			for _, trailing_form in ipairs(trailing_forms) do
				local full_form = form .. joiner .. trailing_form
				if rfind(full_form, "<insa>") and rfind(full_form, "<insb>") then
					-- REJECT! So we don't get mixtures of the two feminine
					-- instrumental singular endings.
				else
					table.insert(new_trailing_forms, full_form)
				end
			end
		end
		return show_form_1(word_forms, new_trailing_forms, old, prefix, suffix,
			lemma)
	end
end

-- Generate a string to substitute into a particular form in a Wiki-markup
-- table. PER_WORD_INFO comes from args.per_word_info and is a list of
-- WORD_INFO items, one per word, each of which a two element list of
-- WORD_FORMS (a table listing the forms for each case) and JOINER (a string).
-- We loop over all possible combinations of elements from each word's list
-- of forms for the given case; this requires recursion.
function show_form(per_word_info, case, old, prefix, suffix, lemma)
	local word_forms = {}
	-- Gather the appropriate word forms. We have to recreate this anew
	-- because it will be destructively modified by show_form_1().
	for _, word_info in ipairs(per_word_info) do
		table.insert(word_forms, {word_info[1][case], word_info[2]})
	end
	-- We need to start the recursion with the second parameter containing
	-- one blank element rather than no elements, otherwise no elements
	-- will be propagated to the next recursion level.
	return show_form_1(word_forms, {""}, old, prefix, suffix, lemma)
end


-- Make the table
function make_table(args)
	local data = {}
	local numb = args.n
	local old = args.old
	data.after_title = after_titles[anim]
	data.number = numbers[numb]

	local prefix = args.prefix or ""
	local suffix = args.suffix or ""
	data.lemma = show_form(args.per_word_info, numb == "p" and "nom_pl" or "nom_sg", old, prefix, suffix, true)
	data.title = args.title or strutils.format(old and old_title_temp or title_temp, data)

	for _, case in ipairs(cases) do
		data[case] = show_form(args.per_word_info, case, old, prefix, suffix, false)
	end

	local temp = nil

	if numb == "s" then
		data.nom_x = data.nom_sg
		data.gen_x = data.gen_sg
		data.dat_x = data.dat_sg
		data.acc_x_an = data.acc_sg_an
		data.acc_x_in = data.acc_sg_in
		data.ins_x = data.ins_sg
		data.pre_x = data.pre_sg
		if data.acc_sg_an == data.acc_sg_in then
			temp = "half"
		else
			temp = "half_a"
		end
	elseif numb == "p" then
		data.nom_x = data.nom_pl
		data.gen_x = data.gen_pl
		data.dat_x = data.dat_pl
		data.acc_x_an = data.acc_pl_an
		data.acc_x_in = data.acc_pl_in
		data.ins_x = data.ins_pl
		data.pre_x = data.pre_pl
		data.par = nil
		data.loc = nil
		data.voc = nil
		if data.acc_pl_an == data.acc_pl_in then
			temp = "half"
		else
			temp = "half_a"
		end
	else
		if data.acc_pl_an == data.acc_pl_in then
			temp = "full"
		elseif data.acc_sg_an == data.acc_sg_in then
			temp = "full_af"
		else
			temp = "full_a"
		end
	end

	data.par_clause = args.any_overridden.apr and strutils.format(partitive, data) or ""
	data.loc_clause = args.any_overridden.loc and strutils.format(locative, data) or ""
	data.voc_clause = args.any_overridden.voc and strutils.format(vocative, data) or ""

	data.notes = args.notes
	data.notes_clause = data.notes and strutils.format(notes_template, data) or ""

	return strutils.format(templates[temp], data)
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
| {acc_sg_an}
| {acc_pl_an}
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
| {acc_sg_an}
| {acc_pl_an}
|-
| {acc_sg_in}
| {acc_pl_an}
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
| rowspan="2" | {acc_sg_an}
| {acc_pl_an}
|-
| {acc_pl_in}
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
| {acc_x_an}
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
| {acc_x_an}
|-
| {acc_x_in}
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
