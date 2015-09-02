--[=[
	This module contains functions for creating inflection tables for Russian
	adjectives.

	Arguments:
		1: stem
		2: declension type (usually just the ending)
		3 or short_m: masculine singular short form (if exists)
		4 or short_n: neuter singular short form (if exists)
		5 or short_f: feminine singular short form (if exists)
		6 or short_p: plural short form (if exists)
		suffix: any suffix to attach unchanged to the end of each form
		notes: Notes to add to the end of the table
		title: Override the title
		CASE_NUMGEN: Override a given form; see abbreviations below

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
		
	Number/gender abbreviations:
		m: masculine
		n: neuter
		f: feminine
		p: plural
		mp: masculine plural (old-style tables only)

TODO:

1. Look into the triangle special case (we would indicate this with some
   character, e.g. ^ or @). This appears to refer to irregularities either in
   the comparative (which we don't care about here) or in the accentation of
   the reducible short masculine singular. This might not be doable as it
   might refer simply to any misc. irregularity; and even if it is, it might
   not be worth it, and better simply to have this done using the various
   override mechanisms.
2. Implement handling of * etc. notes at the end of overrides.
3. Implement categorization similar to the way it's done in nouns.
]=]--

local m_utilities = require("Module:utilities")
local ut = require("Module:utils")
local m_utils = require("Module:utils")
local m_links = require("Module:links")
local com = require("Module:ru-common")
local strutils = require("Module:string utilities")
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

-- utility function
local function insert_list_into_table(tab, list)
	if type(list) ~= "table" then
		list = {list}
	end
	for _, item in ipairs(list) do
		ut.insert_if_not(tab, list)
	end
end

local declensions = {}
local declensions_old = {}
local short_declensions = {}
local short_declensions_old = {}
local short_stress_patterns = {}
local decline = nil

local long_cases = {
	"nom_m", "nom_n", "nom_f", "nom_p",
	"gen_m", "gen_f", "gen_p",
	"dat_m", "dat_f", "dat_p",
	"acc_f", "acc_n",
	"ins_m", "ins_f", "ins_p",
	"pre_m", "pre_f", "pre_p",
}

-- Populate old_cases from cases
local old_long_cases = mw.clone(long_cases)
table.insert(old_long_cases, "nom_mp")

-- Short cases and corresponding numbered arguments
local short_cases = {
	["short_m"] = 3,
	["short_n"] = 4,
	["short_f"] = 5,
	["short_p"] = 6,
}

-- Combine long and short cases
local cases = mw.clone(long_cases)
local old_cases = mw.clone(old_long_cases)

for case, _ in pairs(short_cases) do
	table.insert(cases, case)
	table.insert(old_cases, case)
end

local velar = {
	["г"] = true,
	["к"] = true,
	["х"] = true,
}

local function track(page)
	m_debug.track("ru-adjective/" .. page)
	return true
end

local function tracking_code(decl_class, args, orig_short_accent,
		short_accent, short_stem)
	local hint_types = com.get_stem_trailing_letter_type(args.stem)
	local function dotrack(prefix)
		if prefix ~= "" then
			track(prefix)
			prefix = prefix .. "/"
		end
		track(prefix .. decl_class)
		for _, hint_type in ipairs(hint_types) do
			track(prefix .. hint_type)
			track(prefix .. decl_class .. "/" .. hint_type)
		end
	end
	dotrack("")
	if args[3] or short_accent then
		dotrack("short")
	end
	if orig_short_accent then
		if rfind(orig_short_accent, "%*") then
			dotrack("reducible")
			dotrack("reducible/" .. short_accent)
		end
		if rfind(orig_short_accent, "%(1%)") then
			dotrack("special-case-1")
			dotrack("special-case-1/" .. short_accent)
		end
		if rfind(orig_short_accent, "%(2%)") then
			dotrack("special-case-2")
			dotrack("special-case-2/" .. short_accent)
		end
	if short_accent then
		dotrack("short-accent/" .. short_accent)
	end
	if short_stem then
		dotrack("explicit-short-stem")
		dotrack("explicit-short-stem/" .. short_accent)
	end
	for _, case in ipairs(old_cases) do
		if args[case] then
			track("irreg/" .. case)
			-- questionable use: dotrack("irreg/" .. case .. "/")
		end
	end
end

local function do_show(frame, old, manual)
	PAGENAME = mw.title.getCurrentTitle().text
	SUBPAGENAME = mw.title.getCurrentTitle().subpageText
	NAMESPACE = mw.title.getCurrentTitle().nsText

	local args = {}
	--cloning parent's args while also assigning nil to empty strings
	for pname, param in pairs(frame:getParent().args) do
		if param == "" then args[pname] = nil
        else args[pname] = param
        end
	end

	args.forms = {}

	local decl_types = manual and "-" or args[2]
	for _, decl_type in ipairs(rsplit(decl_types, ",")) do
		local stem
		if manual then
			stem = ""
		elseif not args[1] then
			error("Stem (first argument) must be specified")
		else
			stem = args[1]
		end

		-- Auto-detect actual decl type, and get short accent and overriding
		-- short stem, if specified.
		local short_accent, short_stem
		stem, decl_type, short_accent, short_stem =
			detect_stem_and_accent_type(stem, decl_type)
		args.hint = manual and "" or usub(stem, -1)
		if velar[args.hint] and decl_type == (old and "ій" or "ий") then
			decl_type = "ый"
		end

		-- Set stem and unstressed version. Also construct end-accented version
		-- of stem if unstressed; needed for short forms of adjectives of type -о́й.
		-- We do this here before doing the unreduction transformation so that
		-- we don't end up stressing an unstressed epenthetic vowel, and so that
		-- the previous syllable instead ends up stressed (in type -о́й adjectives
		-- the stem won't have any stress). Note that the closest equivalent in
		-- nouns is handled in attach_unstressed(), which puts the stress onto the
		-- final syllable if the stress pattern calls for ending stress in the
		-- genitive plural. This works there because
		-- (1) It won't stress an unstressed epenthetic vowel because the
		--     cases where the epenthetic vowel is unstressed are precisely those
		--     with stem stress in the gen pl, not ending stress;
		-- (2) There isn't a need to stress the syllable preceding an unstressed
		--     epenthetic vowel because that syllable should already have
		--     stress, since we require that the base stem form (parameter 2)
		--     have stress in it whenever any case form has stem stress.
		--     This isn't the case here in type -о́й adjectives.
		args.stem = stem
		args.ustem = com.make_unstressed_once(stem)
		local accented_stem = stem
		if com.is_unstressed(accented_stem) then
			accented_stem = com.make_ending_stressed(accented_stem)
		end

		local short_forms_allowed = manual and true or
			decl_type == "ый" or decl_type == "ой" or decl_type == (old and "ій" or "ий")
		if not short_forms_allowed then
			if short_accent or short_stem then
				error("Cannot specify short accent or short stem with declension type " .. decl_type .. ", as short forms aren't allowed")
			if args[4] or args[5] or args[6] or args.short_m or
				args.short_f or args.short_n or args.short_p then
				error("Cannot specify explicit short forms with declension type " .. decl_type .. ", as shrot forms aren't allowed")
			end
		end

		local orig_short_accent = short_accent
		short_accent = construct_bare_and_short_stem(args, short_accent,
			short_stem, accented_stem)

		args.suffix = args.suffix or ""
		args.old = old
		-- HACK: Escape * at beginning of line so it doesn't show up
		-- as a list entry. Many existing templates use * for footnotes.
		-- FIXME: We should maybe do this in {{ru-adj-table}} instead.
		if args.notes then
			args.notes = rsub(args.notes, "^%*", "&#42;")
		end

		args.categories = {}
		-- FIXME: For compatibility with old {{temp|ru-adj7}}, {{temp|ru-adj8}},
		-- {{temp|ru-adj9}}; maybe there's a better way.
		if m_utils.contains({"ьій", "ьий", "short", "mixed", "ъ-short", "ъ-mixed"}, decl_type) then
			table.insert(args.categories, "Russian possessive adjectives")
		end

		local decls = old and declensions_old or declensions
		local short_decls = old and short_declensions_old or short_declensions
		if not decls[decl_type] then
			error("Unrecognized declension type " .. decl_type)
		end

		if short_accent == "" then
			error("Short accent type cannot be blank, should be omitted or given")
		end
		if short_accent and not short_stress_patterns[short_accent] then
			error("Unrecognized short accent type " .. short_accent)
		end

		tracking_code(decl_type, args, orig_short_accent, short_accent,
			short_stem)

		decline(args, decls[decl_type], decl_type == "ой")
		if short_forms_allowed and short_accent then
			decline_short(args, decls_short[decl_type],
				short_stress_patterns[short_accent])
		end
	end

	handle_forms_and_overrides(args, short_forms_allowed)

	return make_table(args) .. m_utilities.format_categories(args.categories, lang)
end

-- The main entry point for modern declension tables.
function export.show(frame)
	return do_show(frame, false)
end

-- The main entry point for old declension tables.
function export.show_old(frame)
	return do_show(frame, true)
end

-- The main entry point for manual declension tables.
function export.show_manual(frame)
	return do_show(frame, false, "manual")
end

-- The main entry point for manual old declension tables.
function export.show_manual_old(frame)
	return do_show(frame, true, "manual")
end

-- Entry point for use in Module:ru-noun.
function export.get_nominal_decl(decl, gender, old)
	d = old and declensions_old[decl] or declensions[decl]
	n = {}
	if gender == "m" then
		n.nom_sg = d.nom_m
		n.gen_sg = d.gen_m
		n.dat_sg = d.dat_m
		n.ins_sg = d.ins_m
		n.pre_sg = d.pre_m
	elseif gender == "f" then
		n.nom_sg = d.nom_f
		n.gen_sg = d.gen_f
		n.dat_sg = d.dat_f
		n.acc_sg = d.acc_f
		n.ins_sg = d.ins_f
		n.pre_sg = d.pre_f
	elseif gender == "n" then
		n.nom_sg = d.nom_n
		n.gen_sg = d.gen_m
		n.dat_sg = d.dat_m
		n.acc_sg = d.acc_n
		n.ins_sg = d.ins_m
		n.pre_sg = d.pre_m
	else
		assert(false, "Unrecognized gender: " .. gender)
	end
	n.nom_pl = d.nom_p
	n.gen_pl = d.gen_p
	n.dat_pl = d.dat_p
	n.ins_pl = d.ins_p
	n.pre_pl = d.pre_p
	if gender == "m" and d.nom_mp then
		n.nom_pl = d.nom_mp
	end
	return n
end

--------------------------------------------------------------------------
--                   Autodetection and stem munging                     --
--------------------------------------------------------------------------

-- Attempt to detect the type of the stem (= including ending) based
-- on its ending, separating off the base and the ending; also extract
-- the accent type for short adjectives and optional short stem. DECL
-- is the value passed in, and might already specify the ending. Return
-- four values: BASE, DECL, SHORT_ACCENT (accent class of short adjective,
-- or nil for no short adjectives other than specified through overrides),
-- SHORT_STEM (special stem of short adjective, nil if same as long stem).
function detect_stem_and_accent_type(stem, decl)
	if rfind(decl, "^[abc*(]") then
		decl = ":" .. decl
	end
	splitvals = rsplit(decl, ":")
	if #splitvals > 3 then
		error("Should be at most three colon-separated parts of a declension spec: " .. decl)
	end
	decl, short_accent, short_stem = splitvals[1], splitvals[2], splitvals[3]
	if decl == "" then
		local base, ending = rmatch(stem, "^(.*)([ыиіo]́?й)$")
		if base then
			if rfind(ending "^[іи]й$") and rfind(base, "[" .. com.velar .. com.sib .. "]$") then
				return base, "ый", short_accent, short_stem
			end
			return base, com.make_unstressed(ending), short_accent, short_stem
		else
			error("Cannot determine stem type of adjective: " .. stem)
		end
	elseif decl == "short" or decl == "mixed" then
		local base, ending = rmatch(stem, "^(.-)ъ?$")
		assert(base)
		return base, decl, short_accent, short_stem
	else
		return stem, decl, short_accent, short_stem
	end
end

-- Construct bare form. Return nil if unable.
local function unreduce_stem(accented_stem, short_accent, old, decl)
	local ret = com.unreduce_stem(accented_stem, rfind(short_accent, "^b"))
	if not ret then
		return nil
	end
	if old and decl ~= "ій" then
		return ret .. "ъ"
	elseif decl == "ий" or decl == "ій" then
		-- This next special case is mentioned in Zaliznyak's 1980 grammatical
		-- dictionary for adjectives (footnote, p. 60).
		if rfind(ret, "[нН]$") then
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

-- Construct and set bare and short form in args, and canonicalize
-- short accent spec, handling cases *, (1) and (2). Return canonicalized
-- short accent.
function construct_bare_and_short_stem(args, short_accent, short_stem, accented_stem)
	-- Check if short forms allowed; if not, no short-form params can be given.
	-- Construct bare version of stem; used for cases where the ending
	-- is non-syllabic (i.e. short masculine singular of long adjectives,
	-- and masculine singular of short or mixed adjectives). Comes from
	-- short masculine or 3rd argument if explicitly given, else from the
	-- accented stem, possibly with the unreduction transformation applied
	-- (if * occurs in the short accent spec).
	local reducible = short_accent and rfind(short_accent, "%*")
	local sc1 = short_accent and rfind(short_accent, "%(1%)")
	local sc2 = short_accent and rfind(short_accent, "%(2%)")
	if reducible and sc1 then
		error("Reducible and special case 1, i.e. * and (1), not compatible")
	end
	if sc1 and sc2 then
		error("Special cases 1 and 2, i.e. (1) and (2), not compatible")
	end
	if short_accent then
		short_accent = rsub(short_accent, "%*", "")
		short_accent = rsub(short_accent, "%([12]%)", "")
	end
	args.bare = args.short_m or args[3]
	if not args.bare and reducible then
		args.bare = unreduce_stem(accented_stem, short_accent)
		if not args.bare then
			error("Unable to unreduce stem: " .. stem)
		end
	end
	args.bare = args.bare or not short_forms_allowed and accented_stem
	if sc1 or sc2 then
		if not rfind(accented_stem, "нн$") then
			error("With special cases 1 and 2, stem needs to end in -нн: " .. args.stem)
		end
		args.bare = rsub(args.bare, "нн$", "н")
	end

	-- unused: args.ubare = args.bare and com.make_unstressed_once(args.bare)

	-- Construct short stem used for short forms other than masculine sing.
	-- May be explicitly given, else comes from end-accented stem.
	if short_stem then
		args.explicit_short_stem = true
	else
		short_stem = accented_stem
	end
	args.short_stem = short_stem
	if sc2 then
		args.short_stem = rsub(args.short_stem, "нн$", "н")
	end
	args.short_ustem = com.make_unstressed_once(short_stem)

	return short_accent
end

--------------------------------------------------------------------------
--                                Declensions                           --
--------------------------------------------------------------------------

declensions["ый"] = {
	["nom_m"] = "ый",
	["nom_n"] = "ое",
	["nom_f"] = "ая",
	["nom_p"] = "ые",
	["gen_m"] = "ого",
	["gen_f"] = "ой",
	["gen_p"] = "ых",
	["dat_m"] = "ому",
	["dat_f"] = "ой",
	["dat_p"] = "ым",
	["acc_f"] = "ую",
	["acc_n"] = "ое",
	["ins_m"] = "ым",
	["ins_f"] = {"ой", "ою"},
	["ins_p"] = "ыми",
	["pre_m"] = "ом",
	["pre_f"] = "ой",
	["pre_p"] = "ых",
}

declensions["ий"] = {
	["nom_m"] = "ий",
	["nom_n"] = "ее",
	["nom_f"] = "яя",
	["nom_p"] = "ие",
	["gen_m"] = "его",
	["gen_f"] = "ей",
	["gen_p"] = "их",
	["dat_m"] = "ему",
	["dat_f"] = "ей",
	["dat_p"] = "им",
	["acc_f"] = "юю",
	["acc_n"] = "ее",
	["ins_m"] = "им",
	["ins_f"] = {"ей", "ею"},
	["ins_p"] = "ими",
	["pre_m"] = "ем",
	["pre_f"] = "ей",
	["pre_p"] = "их",
}

declensions["ой"] = {
	["nom_m"] = "о́й",
	["nom_n"] = "о́е",
	["nom_f"] = "а́я",
	["nom_p"] = "ы́е",
	["gen_m"] = "о́го",
	["gen_f"] = "о́й",
	["gen_p"] = "ы́х",
	["dat_m"] = "о́му",
	["dat_f"] = "о́й",
	["dat_p"] = "ы́м",
	["acc_f"] = "у́ю",
	["acc_n"] = "о́е",
	["ins_m"] = "ы́м",
	["ins_f"] = {"о́й", "о́ю"},
	["ins_p"] = "ы́ми",
	["pre_m"] = "о́м",
	["pre_f"] = "о́й",
	["pre_p"] = "ы́х",
}

declensions["ьий"] = {
	["nom_m"] = "ий",
	["nom_n"] = "ье",
	["nom_f"] = "ья",
	["nom_p"] = "ьи",
	["gen_m"] = "ьего",
	["gen_f"] = "ьей",
	["gen_p"] = "ьих",
	["dat_m"] = "ьему",
	["dat_f"] = "ьей",
	["dat_p"] = "ьим",
	["acc_f"] = "ью",
	["acc_n"] = "ье",
	["ins_m"] = "ьим",
	["ins_f"] = {"ьей", "ьею"},
	["ins_p"] = "ьими",
	["pre_m"] = "ьем",
	["pre_f"] = "ьей",
	["pre_p"] = "ьих",
}

declensions["short"] = {
	["nom_m"] = "",
	["nom_n"] = "о",
	["nom_f"] = "а",
	["nom_p"] = "ы",
	["gen_m"] = "а",
	["gen_f"] = "ой",
	["gen_p"] = "ых",
	["dat_m"] = "у",
	["dat_f"] = "ой",
	["dat_p"] = "ым",
	["acc_f"] = "у",
	["acc_n"] = "о",
	["ins_m"] = "ым",
	["ins_f"] = {"ой", "ою"},
	["ins_p"] = "ыми",
	["pre_m"] = "ом",
	["pre_f"] = "ой",
	["pre_p"] = "ых",
}

declensions["mixed"] = {
	["nom_m"] = "",
	["nom_n"] = "о",
	["nom_f"] = "а",
	["nom_p"] = "ы",
	["gen_m"] = "ого",
	["gen_f"] = "ой",
	["gen_p"] = "ых",
	["dat_m"] = "ому",
	["dat_f"] = "ой",
	["dat_p"] = "ым",
	["acc_f"] = "у",
	["acc_n"] = "о",
	["ins_m"] = "ым",
	["ins_f"] = {"ой", "ою"},
	["ins_p"] = "ыми",
	["pre_m"] = "ом",
	["pre_f"] = "ой",
	["pre_p"] = "ых",
}

declensions["-"] = {
	["nom_m"] = "-",
	["nom_n"] = "-",
	["nom_f"] = "-",
	["nom_p"] = "-",
	["gen_m"] = "-",
	["gen_f"] = "-",
	["gen_p"] = "-",
	["dat_m"] = "-",
	["dat_f"] = "-",
	["dat_p"] = "-",
	["acc_f"] = "-",
	-- don't do this; instead we default it to nom_n
	-- ["acc_n"] = "-",
	["ins_m"] = "-",
	["ins_f"] = "-",
	["ins_p"] = "-",
	["pre_m"] = "-",
	["pre_f"] = "-",
	["pre_p"] = "-",
}

declensions_old["ый"] = {
	["nom_m"] = "ый",
	["nom_n"] = "ое",
	["nom_f"] = "ая",
	["nom_mp"] = "ые",
	["nom_p"] = "ыя",
	["gen_m"] = "аго",
	["gen_f"] = "ой",
	["gen_p"] = "ыхъ",
	["dat_m"] = "ому",
	["dat_f"] = "ой",
	["dat_p"] = "ымъ",
	["acc_f"] = "ую",
	["acc_n"] = "ое",
	["ins_m"] = "ымъ",
	["ins_f"] = {"ой", "ою"},
	["ins_p"] = "ыми",
	["pre_m"] = "омъ",
	["pre_f"] = "ой",
	["pre_p"] = "ыхъ",
}

declensions_old["ій"] = {
	["nom_m"] = "ій",
	["nom_n"] = "ее",
	["nom_f"] = "яя",
	["nom_mp"] = "іе",
	["nom_p"] = "ія",
	["gen_m"] = "яго",
	["gen_f"] = "ей",
	["gen_p"] = "ихъ",
	["dat_m"] = "ему",
	["dat_f"] = "ей",
	["dat_p"] = "имъ",
	["acc_f"] = "юю",
	["acc_n"] = "ее",
	["ins_m"] = "имъ",
	["ins_f"] = {"ей", "ею"},
	["ins_p"] = "ими",
	["pre_m"] = "емъ",
	["pre_f"] = "ей",
	["pre_p"] = "ихъ",
}

declensions_old["ой"] = {
	["nom_m"] = "о́й",
	["nom_n"] = "о́е",
	["nom_f"] = "а́я",
	["nom_mp"] = "ы́е",
	["nom_p"] = "ы́я",
	["gen_m"] = "а́го",
	["gen_f"] = "о́й",
	["gen_p"] = "ы́хъ",
	["dat_m"] = "о́му",
	["dat_f"] = "о́й",
	["dat_p"] = "ы́мъ",
	["acc_f"] = "у́ю",
	["acc_n"] = "о́е",
	["ins_m"] = "ы́мъ",
	["ins_f"] = {"о́й", "о́ю"},
	["ins_p"] = "ы́ми",
	["pre_m"] = "о́мъ",
	["pre_f"] = "о́й",
	["pre_p"] = "ы́хъ",
}

declensions_old["ьій"] = {
	["nom_m"] = "ій",
	["nom_n"] = "ье",
	["nom_f"] = "ья",
	["nom_p"] = "ьи",
	["gen_m"] = "ьяго",
	["gen_f"] = "ьей",
	["gen_p"] = "ьихъ",
	["dat_m"] = "ьему",
	["dat_f"] = "ьей",
	["dat_p"] = "ьимъ",
	["acc_f"] = "ью",
	["acc_n"] = "ье",
	["ins_m"] = "ьимъ",
	["ins_f"] = {"ьей", "ьею"},
	["ins_p"] = "ьими",
	["pre_m"] = "ьемъ",
	["pre_f"] = "ьей",
	["pre_p"] = "ьихъ",
}

declensions_old["short"] = {
	["nom_m"] = "ъ",
	["nom_n"] = "о",
	["nom_f"] = "а",
	["nom_p"] = "ы",
	["gen_m"] = "а",
	["gen_f"] = "ой",
	["gen_p"] = "ыхъ",
	["dat_m"] = "у",
	["dat_f"] = "ой",
	["dat_p"] = "ымъ",
	["acc_f"] = "у",
	["acc_n"] = "о",
	["ins_m"] = "ымъ",
	["ins_f"] = {"ой", "ою"},
	["ins_p"] = "ыми",
	["pre_m"] = "омъ",
	["pre_f"] = "ой",
	["pre_p"] = "ыхъ",
}

declensions_old["ъ"] = declensions_old["short"]

declensions_old["mixed"] = {
	["nom_m"] = "ъ",
	["nom_n"] = "о",
	["nom_f"] = "а",
	["nom_p"] = "ы",
	["gen_m"] = "аго",
	["gen_f"] = "ой",
	["gen_p"] = "ыхъ",
	["dat_m"] = "ому",
	["dat_f"] = "ой",
	["dat_p"] = "ымъ",
	["acc_f"] = "у",
	["acc_n"] = "о",
	["ins_m"] = "ымъ",
	["ins_f"] = {"ой", "ою"},
	["ins_p"] = "ыми",
	["pre_m"] = "омъ",
	["pre_f"] = "ой",
	["pre_p"] = "ыхъ",
}

declensions_old["ъ-mixed"] = declensions_old["mixed"]

declensions_old["-"] = declensions["-"]

--------------------------------------------------------------------------
--                          Sibilant/Velar/ц rules                      --
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

local consonantal_suffixes = {
	[""] = true,
	["ь"] = true,
	["й"] = true,
}

local old_consonantal_suffixes = {
	["ъ"] = true,
	["ь"] = true,
	["й"] = true,
}

--------------------------------------------------------------------------
--                           Declension functions                       --
--------------------------------------------------------------------------

local function attach_unstressed(args, suf, stem, ustem)
	local old = args.old
	if suf == nil then
		return nil
	elseif old and old_consonantal_suffixes[suf] or not old and consonantal_suffixes[suf] then
		if rfind(args.bare, old and "[йьъ]$" or "[йь]$") then
			return args.bare
		elseif suf == "ъ" then
			return args.bare .. suf
		else
			return args.bare
		end
	end
	suf = com.make_unstressed(suf)
	local first = usub(suf, 1, 1)
	local rules = unstressed_rules[args.hint]
	if rules then
		local conv = rules[first]
		if conv then
			if old then
				local ending = usub(suf, 2)
				if conv == "и" and rfind(ending, "^́?[аеёиійоуэюяѣ]") then
					conv = "і"
				end
				suf = conv .. ending
			else
				suf = conv .. usub(suf, 2)
			end
		end
	end
	return stem .. suf
end

local function attach_stressed(args, suf, stem, ustem)
	local old = args.old
	if suf == nil then
		return nil
	elseif not rfind(suf, "[ё́]") then -- if suf has no "ё" or accent marks
		return attach_unstressed(args, suf, stem, ustem)
	end
	local first = usub(suf, 1, 1)
	local rules = stressed_rules[args.hint]
	if rules then
		local conv = rules[first]
		if conv then
			if old then
				local ending = usub(suf, 2)
				if conv == "и" and rfind(ending, "^́?[аеёиійоуэюяѣ]") then
					conv = "і"
				end
				suf = conv .. ending
			else
				suf = conv .. usub(suf, 2)
			end
		end
	end
	return ustem .. suf
end

local function attach_both(args, suf, stem, ustem)
	local results = {}
	ut.insert_if_not(results, attach_unstressed(args, suf, stem, ustem))
	ut.insert_if_not(results, attach_stressed(args, suf, stem, ustem))
	return results
end

local function attach_with(args, suf, fun, stem, ustem)
	if type(suf) == "table" then
		local tbl = {}
		for _, x in ipairs(suf) do
			table.insert(tbl, attach_with(args, x, fun, stem, ustem))
		end
		return tbl
	else
		local funval = fun(args, suf)
		if funval then
			return funval .. args.suffix
		else
			return nil
		end
	end
end

local function gen_form(args, decl, case, fun)
	if not args.forms[case] then
		args.forms[case] = {}
	end
	insert_list_into_table(args.forms[case],
		attach_with(args, decl[case], fun, args.stem, args.ustem))
end

decline = function(args, decl, stressed)
	local attacher = stressed and attach_stressed or attach_unstressed
	gen_form(args, decl, "nom_m", attacher)
	gen_form(args, decl, "nom_n", attacher)
	gen_form(args, decl, "nom_f", attacher)
	if args.old then
		gen_form(args, decl, "nom_mp", attacher)
	end
	gen_form(args, decl, "nom_p", attacher)
	gen_form(args, decl, "gen_m", attacher)
	gen_form(args, decl, "gen_f", attacher)
	gen_form(args, decl, "gen_p", attacher)
	gen_form(args, decl, "dat_m", attacher)
	gen_form(args, decl, "dat_f", attacher)
	gen_form(args, decl, "dat_p", attacher)
	gen_form(args, decl, "acc_f", attacher)
	gen_form(args, decl, "acc_n", attacher)
	gen_form(args, decl, "ins_m", attacher)
	gen_form(args, decl, "ins_f", attacher)
	gen_form(args, decl, "ins_p", attacher)
	gen_form(args, decl, "pre_m", attacher)
	gen_form(args, decl, "pre_f", attacher)
	gen_form(args, decl, "pre_p", attacher)
	-- default acc_n to nom_n; applies chiefly in manual declension tables
	if not args.acc_n then
		args.acc_n = args.nom_n
	end

end

function handle_forms_and_overrides(args, short_forms_allowed)
	local old = args.old
	for _, case in ipairs(old and old_long_cases or long_cases) do
		args[case] = args[case] or args.forms[case]
	end
	for case, argnum in pairs(short_cases) do
		if short_forms_allowed then
			args[case] = args[case] or args[argnum] or args.forms[case]
		else
			args[case] = nil
		end
	end
end

--------------------------------------------------------------------------
--                        Short adjective declension                    --
--------------------------------------------------------------------------

short_declensions["ый"] = { m="", f="а", n="о", p="ы" }
short_declensions["ой"] = short_declensions["ыи"]
short_declensions["ий"] = { m="ь", f="я", n="е", p="и" }
short_declensions_old["ый"] = { m="ъ", f="а", n="о", p="ы" }
short_declensions_old["ой"] = short_declensions_old["ыи"]
short_declensions_old["ій"] = short_declensions["ий"]

-- Short adjective stress patterns:
--   "-" = stem-stressed
--   "+" = ending-stressed (drawn onto the last syllable of stem in masculine)
--   "-+" = both possibilities
short_stress_patterns["a"] = { m="-", f="-", n="-", p="-" }
short_stress_patterns["a'"] = { m="-", f="-+", n="-", p="-" }
short_stress_patterns["b"] = { m="+", f="-+", n="+", p="+" }
short_stress_patterns["b'"] = { m="+", f="+", n="+", p="-+" }
short_stress_patterns["c"] = { m="-", f="+", n="-", p="-" }
short_stress_patterns["c'"] = { m="-", f="+", n="-", p="-+" }
short_stress_patterns["c''"] = { m="-", f="+", n="-+", p="-+" }

local function gen_short_form(args, decl, case, fun)
	if not args.forms[case] then
		args.forms[case] = {}
	end
	insert_list_into_table(args.forms["short_" .. case],
		attach_with(args, decl[case], fun, args.short_stem, args.short_ustem))
end

local attachers = {
	["+"] = attach_stressed,
	["-"] = attach_unstressed,
	["-+"] = attach_both,
}

function decline_short(args, decl, stress_pattern)
	if stress_pattern then
		for case, _ in ipairs({"m", "f", "n", "p"}) do
			gen_short_form(args, decl, case, attachers[stress_pattern[case]])
		end
	end
end

--------------------------------------------------------------------------
--                             Create the table                         --
--------------------------------------------------------------------------

local form_temp = [=[{term}<br/><span style="color: #888">{tr}</span>]=]
local title_temp = [=[Declension of <b lang="ru" class="Cyrl">{lemma}</b>]=]
local old_title_temp = [=[Pre-reform declension of <b lang="ru" class="Cyrl">{lemma}</b>]=]

local template = nil
local template_mp = nil
local short_clause = nil
local notes_template = nil

-- Make the table
function make_table(args)
	local old = args.old
	args.lemma = args.nom_m
	args.title = args.title or strutils.format(old and old_title_temp or title_temp, args)

	for _, case in ipairs(old and old_cases or cases) do
		if args[case] == "-" then
			args[case] = "&mdash;"
		elseif args[case] then
			if type(args[case]) ~= "table" then
				args[case] = rsplit(args[case], "%s*,%s*")
			end
			local ru_vals = {}
			local tr_vals = {}
			for _, x in ipairs(args[case]) do
				if old then
					ut.insert_if_not(ru_vals, m_links.full_link(com.make_unstressed(x), x, lang, nil, nil, nil, {tr = "-"}, false))
				else
					ut.insert_if_not(ru_vals, m_links.full_link(x, nil, lang, nil, nil, nil, {tr = "-"}, false))
				end
				local trx = lang:transliterate(m_links.remove_links(x))
				if case == "gen_m" then
					trx = rsub(trx, "([aoeáóé]́?)go$", "%1vo")
				end
				ut.insert_if_not(tr_vals, trx)
			end
			local term = table.concat(ru_vals, ", ")
			local tr = table.concat(tr_vals, ", ")
			args[case] = strutils.format(form_temp, {["term"] = term, ["tr"] = tr})
		else
			args[case] = nil
		end
	end

	local temp = template

	if old then
		if args.nom_mp then
			temp = template_mp
			if args.short_m or args.short_n or args.short_f or args.short_p then
				args.short_m = args.short_m or "&mdash;"
				args.short_n = args.short_n or "&mdash;"
				args.short_f = args.short_f or "&mdash;"
				args.short_p = args.short_p or "&mdash;"
				args.short_clause = strutils.format(short_clause_mp, args)
			else
				args.short_clause = ""
			end
		else
			args.short_clause = ""
		end
	else
		if args.short_m or args.short_n or args.short_f or args.short_p then
			args.short_m = args.short_m or "&mdash;"
			args.short_n = args.short_n or "&mdash;"
			args.short_f = args.short_f or "&mdash;"
			args.short_p = args.short_p or "&mdash;"
			args.short_clause = strutils.format(short_clause, args)
		else
			args.short_clause = ""
		end
	end

	if args.notes then
		args.notes_clause = strutils.format(notes_template, args)
	else
		args.notes_clause = ""
	end

	return strutils.format(temp, args)
end

-- Used for new-style templates
short_clause = [===[

! style="height:0.2em;background:#d9ebff" colspan="6" |
|-
! style="background:#eff7ff" colspan="2" | short form
| {short_m}
| {short_n}
| {short_f}
| {short_p}]===]

-- Used for old-style templates
short_clause_mp = [===[

! style="height:0.2em;background:#d9ebff" colspan="7" |
|-
! style="background:#eff7ff" colspan="2" | short form
| {short_m}
| {short_n}
| {short_f}
| colspan="2" | {short_p}]===]

-- Used for both new-style and old-style templates
notes_template = [===[
<div style="width:100%;text-align:left">
<div style="display:inline-block;text-align:left;padding-left:1em;padding-right:1em">
{notes}
</div></div>
]===]

-- Used for both new-style and old-style templates
template = [===[
<div>
<div class="NavFrame" style="display: inline-block; min-width: 70em">
<div class="NavHead" style="background:#eff7ff">{title}</div>
<div class="NavContent">
{\op}| style="background:#F9F9F9;text-align:center; min-width:70em" class="inflection-table"
|-
! style="width:20%;background:#d9ebff" colspan="2" | 
! style="background:#d9ebff" | masculine
! style="background:#d9ebff" | neuter
! style="background:#d9ebff" | feminine
! style="background:#d9ebff" | plural
|-
! style="background:#eff7ff" colspan="2" | nominative
| {nom_m}
| {nom_n}
| {nom_f}
| {nom_p}
|-
! style="background:#eff7ff" colspan="2" | genitive
| colspan="2" | {gen_m}
| {gen_f}
| {gen_p}
|-
! style="background:#eff7ff" colspan="2" | dative
| colspan="2" | {dat_m}
| {dat_f}
| {dat_p}
|-
! style="background:#eff7ff" rowspan="2" | accusative
! style="background:#eff7ff" | animate
| {gen_m}
| rowspan="2" | {acc_n}
| rowspan="2" | {acc_f}
| {gen_p}
|-
! style="background:#eff7ff" | inanimate
| {nom_m}
| {nom_p}
|-
! style="background:#eff7ff" colspan="2" | instrumental
| colspan="2" | {ins_m}
| {ins_f}
| {ins_p}
|-
! style="background:#eff7ff" colspan="2" | prepositional
| colspan="2" | {pre_m}
| {pre_f}
| {pre_p}
|-{short_clause}
|{\cl}{notes_clause}</div></div></div>]===]

-- Used for old-style templates
template_mp = [===[
<div>
<div class="NavFrame" style="display: inline-block; min-width: 70em">
<div class="NavHead" style="background:#eff7ff">{title}</div>
<div class="NavContent">
{\op}| style="background:#F9F9F9;text-align:center; min-width:70em" class="inflection-table"
|-
! style="width:20%;background:#d9ebff" colspan="2" | 
! style="background:#d9ebff" | masculine
! style="background:#d9ebff" | neuter
! style="background:#d9ebff" | feminine
! style="background:#d9ebff" | m. plural
! style="background:#d9ebff" | n./f. plural
|-
! style="background:#eff7ff" colspan="2" | nominative
| {nom_m}
| {nom_n}
| {nom_f}
| {nom_mp}
| {nom_p}
|-
! style="background:#eff7ff" colspan="2" | genitive
| colspan="2" | {gen_m}
| {gen_f}
| colspan="2" | {gen_p}
|-
! style="background:#eff7ff" colspan="2" | dative
| colspan="2" | {dat_m}
| {dat_f}
| colspan="2" | {dat_p}
|-
! style="background:#eff7ff" rowspan="2" | accusative 
! style="background:#eff7ff" | animate
| {gen_m}
| rowspan="2" | {acc_n}
| rowspan="2" | {acc_f}
| colspan="2" | {gen_p}
|-
! style="background:#eff7ff" | inanimate
| {nom_m}
| {nom_mp}
| {nom_p}
|-
! style="background:#eff7ff" colspan="2" | instrumental
| colspan="2" | {ins_m}
| {ins_f}
| colspan="2" | {ins_p}
|-
! style="background:#eff7ff" colspan="2" | prepositional
| colspan="2" | {pre_m}
| {pre_f}
| colspan="2" | {pre_p}
|-{short_clause}
|{\cl}{notes_clause}</div></div></div>]===]

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
