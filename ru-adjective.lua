--[=[
	This module contains functions for creating inflection tables for Russian
	adjectives.

	Arguments:
		1: lemma; nom sg, or just the stem if an explicit declension type is
		   given in arg 2
		2: declension type (usually omitted to autodetect based on the lemma),
		   along with any short accent type and optional irregular short stem;
		   see below.
		3 or short_m: masculine singular short form (if exists); normally,
		   don't use this or args 4/5/6, but instead specify a short accent
		   type in arg 2, and use this only for irregular forms
		4 or short_n: neuter singular short form (if exists)
		5 or short_f: feminine singular short form (if exists)
		6 or short_p: plural short form (if exists)
		suffix: any suffix to attach unchanged to the end of each form
		notes: Notes to add to the end of the table
		title: Override the title
		shorttail: Footnote (e.g. *, 1, 2, etc.) to add to short forms if
		   there's more than one; automatically superscripted
		shorttailall: Same as shorttail= but applies to all short forms even
		   if there's only one
		CASE_NUMGEN: Override a given form; see abbreviations below

	Case abbreviations:
		nom: nominative
		gen: genitive
		dat: dative
		acc: accusative
		ins: instrumental
		pre: prepositional
		short: short form

	Number/gender abbreviations:
		m: masculine singular
		n: neuter singular
		f: feminine singular
		p: plural
		mp: masculine plural (old-style tables only)

	Declension-type argument (arg 2):
		Form is DECLSPEC or DECLSPEC,DECLSPEC,... where DECLSPEC is
		one of the following:
			DECLTYPE:SHORTACCENT:SHORTSTEM
			DECLTYPE:SHORTACCENT
			DECLTYPE
			SHORTACCENT:SHORTSTEM
			(blank)
		DECLTYPE should normally be omitted, and the declension autodetected
			from the ending; or it should be ь, to indicate that an adjective
			in -ий is of the possessive variety with an extra -ь- in most of
			the endings. Alternatively, it can be an explicit declension type,
			in which case the lemma field needs to be replaced with the bare
			stem; the following are the possibilities:
			ый ий ой ьий short mixed (new-style)
			ый ій ьій short stressed-short mixed proper stressed-proper
				ъ-short ъ-stressed-short ъ-mixed ъ-proper ъ-stressed-proper
				(old-style, where ъ-* is a synonym for *, for any *)
		SHORTACCENT is one of a a' b b' c c' c'' to auto-generate the
		    short forms with the specified accent pattern (following
			Zaliznyak); if omitted, no short forms will be auto-generated.
			SHORTACCENT can contain a * in it for "reducible" adjectives,
			where the short masculine singular has an epenthetic vowel
			in the final syllable. It can also contain (1) or (2) to
			indicate special cases. Both are used in conjunction with
			adjectives in -нный/-нний. Special case (1) causes the
			short masculine singular to end in -н instead of -нн; special
			case (2) causes all short forms to end this way.
		SHORTSTEM, if present, is used as the short stem to base the
			short forms off of, instead of the normal adjective long stem
			(possibly with a final-syllable accent added in the case of
			declension type -о́й).

TODO:

1. Figure out what the symbol X-inside-square (⊠) means, which seems to go with
   all adjectives in -о́й with multi-syllabic stems. It may mean that the
   masculine singular short form is missing. If this indeed a regular thing,
   we need to implement it (and if it's regular but means something else,
   we need to implement that, too). Also figure out what the other signs
   on pages 68-76 etc. mean: -, X, ~, П₂, Р₂, diamond (♢), triangle (△; might
   simply mean a misc. irregularity; explained on p. 61).
2. Mark irregular overridden forms with △ (esp. appropriate for short forms).
3. Should non-reducible adjectives in -нный and -нний default to special case
   (1)?
4. In the case of a non-dereducible short masc sing of stress type b, we don't
   currently move the stress to the last syllable. Should we?
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

----------------------------- Utility functions ------------------------

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

-- version of rsubn() that returns a 2nd argument boolean indicating whether
-- a substitution was made.
local function rsubb(term, foo, bar)
	local retval, nsubs = rsubn(term, foo, bar)
	return retval, nsubs > 0
end

local function insert_list_into_table(tab, list)
	if type(list) ~= "table" then
		list = {list}
	end
	for _, item in ipairs(list) do
		ut.insert_if_not(tab, item)
	end
end

local function track(page)
	m_debug.track("ru-adjective/" .. page)
	return true
end

local function ine(arg)
	return arg ~= "" and arg or nil
end

-- Clone parent's args while also assigning nil to empty strings.
local function clone_args(frame)
	local args = {}
	for pname, param in pairs(frame:getParent().args) do
		args[pname] = ine(param)
	end
	return args
end

-------------------- Global declension/case/etc. variables -------------------

-- 'enable_categories' is a special hack for testing, which disables all
-- category insertion if false. Delete this as soon as we've verified the
-- working of the category code and created all the necessary categories.
local enable_categories = false
local declensions = {}
local declensions_old = {}
local internal_notes_table = {}
local internal_notes_table_old = {}
local internal_notes_genders = {}
local internal_notes_genders_old = {}
local short_declensions = {}
local short_declensions_old = {}
local short_internal_notes_table = {}
local short_internal_notes_table_old = {}
local short_stress_patterns = {}

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

-- Forward references to functions
local tracking_code
local categorize
local detect_stem_and_accent_type
local construct_bare_and_short_stem
local deduce_short_accent
local decline
local canonicalize_override
local handle_forms_and_overrides
local decline_short

--------------------------------------------------------------------------
--                               Main code                              --
--------------------------------------------------------------------------

-- Implementation of main entry point
local function generate_forms(args, old, manual)
	PAGENAME = mw.title.getCurrentTitle().text
	SUBPAGENAME = mw.title.getCurrentTitle().subpageText
	NAMESPACE = mw.title.getCurrentTitle().nsText

	args.forms = {}
	old = old or args.old
	args.old = old
	args.suffix = args.suffix or ""
	args.internal_notes = {}
	-- Superscript footnote marker at beginning of note, similarly to what's
	-- done at end of forms.
	if args.notes then
		local notes, entry = m_table_tools.get_initial_notes(args.notes)
		args.notes = notes .. entry
	end

	local overall_short_forms_allowed
	manual = manual or args[2] == "manual"
	local decl_types = manual and "$" or args[2] or ""
	for _, decl_type in ipairs(rsplit(decl_types, ",")) do
		local lemma
		if manual then
			lemma = "-"
		elseif not args[1] then
			error("Lemma (first argument) must be specified")
		else
			lemma = args[1]
		end

		-- Auto-detect actual decl type, and get short accent and overriding
		-- short stem, if specified.
		local stem, short_accent, short_stem
		stem, decl_type, short_accent, short_stem =
			detect_stem_and_accent_type(lemma, decl_type)
		if rfind(decl_type, "^[іи]й$") and rfind(stem, "[" .. com.velar .. com.sib .. "]$") then
			decl_type = "ый"
		end

		local allow_unaccented
		stem, allow_unaccented = rsubb(stem, "^%*", "")
		if not allow_unaccented and decl_type ~= "ой" and com.needs_accents(stem) then
			error("Stem must have an accent in it: " .. stem)
		end

		-- Set stem and unstressed version. Also construct end-accented version
		-- of stem if unstressed; needed for short forms of adjectives of
		-- type -о́й. We do this here before doing the dereduction
		-- transformation so that we don't end up stressing an unstressed
		-- epenthetic vowel, and so that the previous syllable instead ends
		-- up stressed (in type -о́й adjectives the stem won't have any stress).
		-- Note that the closest equivalent in nouns is handled in
		-- attach_unstressed(), which puts the stress onto the final syllable
		-- if the stress pattern calls for ending stress in the genitive
		-- plural. This works there because
		-- (1) It won't stress an unstressed epenthetic vowel because the
		--     cases where the epenthetic vowel is unstressed are precisely
		--     those with stem stress in the gen pl, not ending stress;
		-- (2) There isn't a need to stress the syllable preceding an
		--     unstressed epenthetic vowel because that syllable should
		--     already have stress, since we require that the base stem form
		--     (parameter 2) have stress in it whenever any case form has
		--     stem stress. This isn't the case here in type -о́й adjectives.
		-- NOTE: FIXME: I can't actually quote any forms from Zaliznyak
		-- (at least not from pages 58-60, where this is discussed) that
		-- seem to require last-stem-syllable-stress, i.e. where the stem is
		-- multisyllabic. The two examples given are both unusual: дорого́й
		-- has stress on the initial syllable до́рог etc. and these forms are
		-- marked with a triangle (indicating an apparent irregularity); and
		-- голубо́й seems not to have a masculine singular short form, and it's
		-- accent pattern b, so the remaining forms are all ending-stressed.
		-- In fact it's possible that these examples don't exist: It appears
		-- that all the multisyllabic adjectives in -о́й listed in the
		-- dictionary have a marking next to them consisting of an X inside of
		-- a square, which is glossed p. 69 to something I don't understand,
		-- but may be saying that the masculine singular short form is
		-- missing. If this is regular, we need to implement it.
		args.stem = stem
		args.ustem = com.make_unstressed_once(stem)
		local accented_stem = stem
		if com.is_unstressed(accented_stem) then
			accented_stem = com.make_ending_stressed(accented_stem)
		end

		local short_forms_allowed = manual and true or decl_type == "ый" or
			decl_type == "ой" or decl_type == (old and "ій" or "ий")
		overall_short_forms_allowed = overall_short_forms_allowed or
			short_forms_allowed
		if not short_forms_allowed then
			-- FIXME: We might want to allow this in case we have a
			-- reducible short, mixed or proper possessive adjective. But
			-- in that case we need to reduce rather than dereduce to get
			-- the stem.
			if short_accent or short_stem then
				error("Cannot specify short accent or short stem with declension type " .. decl_type ..  ", as short forms aren't allowed")
			end
			if args[3] or args[4] or args[5] or args[6] or args.short_m or
				args.short_f or args.short_n or args.short_p then
				error("Cannot specify explicit short forms with declension type " .. decl_type .. ", as short forms aren't allowed")
			end
		end

		local orig_short_accent = short_accent
		local short_decl_type
		short_accent, short_decl_type = construct_bare_and_short_stem(args,
			short_accent, short_stem, accented_stem, old, decl_type)

		args.categories = {}

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
			short_stem, short_forms_allowed)
		if not manual and enable_categories then
			categorize(decl_type, args, orig_short_accent, short_stem,
				short_stem)
		end

		decline(args, decls[decl_type], ut.contains({"ой", "stressed-short", "stressed-proper"}, decl_type))
		if short_forms_allowed and short_accent then
			decline_short(args, short_decls[short_decl_type],
				short_stress_patterns[short_accent])
		end

		local intable = old and internal_notes_table_old or internal_notes_table
		local shortintab = old and short_internal_notes_table_old or
			short_internal_notes_table
		local internal_note = intable[decl_type] or shortintab[short_decl_type]
		if internal_note then
			ut.insert_if_not(args.internal_notes, internal_note)
		end
	end

	handle_forms_and_overrides(args, overall_short_forms_allowed)

	return args
end

-- Implementation of main entry point
local function do_show(frame, old, manual)
	local args = clone_args(frame)
	local args = generate_forms(args, old, manual)
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
	local d = old and declensions_old[decl] or declensions[decl]
	local n = {}
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
	local intable = old and internal_notes_table_old or internal_notes_table
	local ingenders = old and internal_notes_genders_old or internal_notes_genders
	-- FIXME, what if there are multiple internal notes? See comment in
	-- generate_forms().
	local internal_notes = ingenders[decl] and ut.contains(ingenders[decl], gender) and intable[decl]
	return n, internal_notes
end

local function get_form(forms)
	local canon_forms = {}
	for _, form in forms do
		local entry, notes = m_table_tools.get_notes(form)
		ut.insert_if_not(canon_forms, m_links.remove_links(entry))
	end
	return table.concat(canon_forms, ",")
end

-- The entry point for 'ru-adj-forms' to generate all adjective forms.
function export.generate_forms(frame)
	local args = clone_args(frame)
	local args = generate_forms(args, false)
	local ins_text = {}
	for _, case in ipairs(old_cases) do
		if args.forms[case] then
			table.insert(ins_text, case .. "=" .. get_form(args.forms[case]))
		end
	end
	return table.concat(ins_text, "|")
end

-- The entry point for 'ru-adj-form' to generate a particular adjective form.
function export.generate_form(frame)
	local args = clone_args(frame)
	if not args.form then
		error("Must specify desired form using form=")
	end
	local form = args.form
	if not ut.contains(old_cases, form) then
		error("Unrecognized form " .. form)
	end
	local args = generate_forms(args, false)
	if not args.forms[form] then
		return ""
	else
		return get_form(args.forms[form])
	end
end

--------------------------------------------------------------------------
--                      Tracking and categorization                     --
--------------------------------------------------------------------------

tracking_code = function(decl_class, args, orig_short_accent, short_accent,
	short_stem, short_forms_allowed)
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
	if args[3] or args[4] or args[5] or args[6] or args.short_m or
		args.short_f or args.short_n or args.short_p then
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
	end
	if short_accent then
		dotrack("short-accent/" .. short_accent)
	end
	if short_stem then
		dotrack("explicit-short-stem")
		dotrack("explicit-short-stem/" .. short_accent)
	end
	if not short_accent and not short_stem and short_forms_allowed then
		local deduced_short = deduce_short_accent(args)
		--for testing output of deduce_short_accent(); remove me!!!
		--error(rsub(deduced_short, "''", "' '"))
		dotrack("explicit-short/" .. deduced_short)
	end
	for _, case in ipairs(old_cases) do
		if args[case] then
			track("irreg/" .. case)
			-- questionable use: dotrack("irreg/" .. case)
		end
	end
end

-- Insert the category CAT (a string) into list CATEGORIES. String will
-- have "Russian " prepended and ~ substituted for the part of speech --
-- currently always "adjectives".
local function insert_category(categories, cat)
	table.insert(categories, "Russian " .. rsub(cat, "~", "adjectives"))
end

categorize = function(decl_type, args, orig_short_accent, short_accent,
	short_stem)
	-- Insert category CAT into the list of categories in ARGS.
	local function insert_cat(cat)
		insert_category(args.categories, cat)
	end

	-- FIXME: For compatibility with old {{temp|ru-adj7}}, {{temp|ru-adj8}},
	-- {{temp|ru-adj9}}; maybe there's a better way.
	if ut.contains({"ьій", "ьий", "short", "stressed-short", "mixed",
		"proper", "stressed-proper"}, decl_type) then
		insert_cat("possessive ~")
	end

	if ut.contains({"ьій", "ьий"}, decl_type) then
		insert_cat("long possessive ~")
	elseif ut.contains({"short", "stressed-short"}) then
		insert_cat("short possessive ~")
	elseif ut.contains({"mixed"}) then
		insert_cat("mixed possessive ~")
	elseif ut.contains({"proper", "stressed-proper"}) then
		insert_cat("proper-name ~")
	elseif decl_type == "$" then
		insert_cat("invariable ~")
	else
		local hint_types = com.get_stem_trailing_letter_type(args.stem)
	-- insert English version of Zaliznyak stem type
		local stem_type =
			ut.contains(hint_types, "velar") and "velar-stem" or
			ut.contains(hint_types, "sibilant") and "sibilant-stem" or
			ut.contains(hint_types, "c") and "ц-stem" or
			ut.contains(hint_types, "i") and "i-stem" or
			ut.contains(hint_types, "vowel") and "vowel-stem" or
			ut.contains(hint_types, "soft-cons") and "vowel-stem" or
			ut.contains(hint_types, "palatal") and "vowel-stem" or
			decl_class == "ий" and "soft-stem" or
			"hard-stem"
		if stem_type == "soft-stem" or stem_type == "vowel-stem" then
			insert_cat(stem_type .. " ~")
		else
			insert_cat(stem_type .. " " .. (decl_class == "ой" and "ending-stressed" or "stem-stressed") .. " ~")
		end
	end
	if decl_type == "ой" then
		insert_cat("ending-stressed ~")
	end

	local short_forms_allowed = ut.contains({"ый", "ой", "ій", "ий"})
	if short_forms_allowed then
		local override_m = args.short_m or args[3]
		local override_f = args.short_f or args[5]
		local override_n = args.short_n or args[4]
		local override_p = args.short_p or args[6]
		local has_short = short_accent or override_m or override_f or
			override_n or override_p
		local missing_short = override_m == "-" or
			override_f == "-" or override_n == "-" or override_p == "-" or
			not short_accent and (not override_m or not override_f or
			not override_n or not override_p)
		if has_short then
			insert_cat("~ with short forms")
			if missing_short then
				insert_cat("~ with missing short forms")
			end
		end
		if short_accent then
			insert_cat("~ with short accent pattern " .. short_accent)
		end
		if orig_short_accent then
			if rfind(orig_short_accent, "%*") then
				insert_cat("~ with reducible short stem")
			end
			if rfind(orig_short_accent, "%(1%)") then
				insert_cat("~ with Zaliznyak short form special case 1")
			end
			if rfind(orig_short_accent, "%(2%)") then
				insert_cat("~ with Zaliznyak short form special case 2")
			end
		end
		if short_stem and short_stem ~= args.stem then
			insert_cat("~ with irregular short stem")
		end
		insert_cat("~ with reducible stem")
	end
	for _, case in ipairs(old_cases) do
		if args[case] then
			local engcase = rsub(case, "^([a-z]*)", {
				nom="nominative", gen="genitive", dat="dative",
				acc="accusative", ins="instrumental", pre="prepositional",
				short="short",
			})
			engcase = rsub(engcase, "(_[a-z]*)$", {
				_m=" masculine singular", _f=" feminine singular",
				_n=" neuter singular", _p=" plural",
				_mp=" masculine plural"
			})
			insert_cat("~ with irregular " .. engcase)
		end
	end
	-- FIXME: Eventually we want to treat the presence of args 3/4/5/6
	-- as irregular, but not till we've converted everything we can to
	-- use the normal short-accent patterns.
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
}

-- Implementation of template 'ruadjcatboiler'.
function export.catboiler(frame)
	local SUBPAGENAME = mw.title.getCurrentTitle().subpageText
	local args = clone_args(frame)

	local cats = {}

	local maintext
	if args[1] == "adj" then
		local stem, stress = rmatch(SUBPAGENAME, "^Russian ([^ ]*) ([^ *]*)-stressed adjectives")
		if not stem then
			stem, stress = rmatch(SUBPAGENAME, "^Russian ([^ ]*) (possessive) adjectives")
		end
		if not stem then
			error("Invalid category name, should be e.g. \"Russian velar-stem ending-stressed adjectives\"")
		end
		local stresstext = stress == "stem" and
			"This adjective has stress on the stem, corresponding to Zaliznyak's type a." or
			stress == "ending" and
			"This adjective has stress on the endings, corresponding to Zaliznyak's type b." or
			"All adjectives of this type have stress on the stem."
		local endingtext = "ending in the nominative in masculine singular " .. args[2] .. ", feminine singular " .. args[3] .. ", neuter singular " .. args[4] .. " and plural " .. args[5] .. "."
		local stemtext, posstext
		if stress == "possessive" then
			posstext = " possessive"
			if stem == "long" then
				stemtext = " The stem ends in a yod, which disappears in the nominative singular but appears in all other forms as a soft sign ь followed by a vowel."
			else
				stemtext = ""
			end
		else
			posstext = ""
			if not stem_expl[stem] then
				error("Invalid stem type " .. stem)
			end
			stemtext = " The stem ends in " .. stem_expl[stem] .. " and is Zaliznyak's type " .. zaliznyak_stem_type[stem] .. "."
		end

		maintext = stem .. posstext .. " ~, " .. endingtext .. stemtext .. " " .. stresstext
		insert_category(cats, "~ by stem type and stress")
	elseif args[1] == "shortaccent" then
		local shortaccent = rmatch(SUBPAGENAME, "^Russian adjectives with short accent pattern ([^ ]*)")
		if not shortaccent then
			error("Invalid category name, should be e.g. \"Russian adjectives with short accent pattern c\"")
		end
		maintext = "~ with short accent pattern " .. shortaccent .. ", with " .. args[2] .. "."
		insert_category(cats, "~ by short accent pattern")
	else
		error("Unknown ruadjcatboiler type " .. (args[1] or "(empty)"))
	end

	return "This category contains Russian " .. rsub(maintext, "~", "adjectives")
		.. "\n" ..
		mw.getCurrentFrame():expandTemplate{title="ru-categoryTOC", args={}}
		.. m_utilities.format_categories(cats, lang)
end

--------------------------------------------------------------------------
--                   Autodetection and stem munging                     --
--------------------------------------------------------------------------

-- Attempt to detect the type of the lemma based on its ending, separating
-- off the base and the ending; also extract the accent type for short
-- adjectives and optional short stem. DECL is the value passed in, and
-- might already specify the ending. Return four values: STEM, DECL,
-- SHORT_ACCENT (accent class of short adjective, or nil for no short
-- adjectives other than specified through overrides), SHORT_STEM (special
-- stem of short adjective, nil if same as long stem).
detect_stem_and_accent_type = function(lemma, decl)
	if rfind(decl, "^[abc*(]") then
		decl = ":" .. decl
	end
	splitvals = rsplit(decl, ":")
	if #splitvals > 3 then
		error("Should be at most three colon-separated parts of a declension spec: " .. decl)
	end
	decl, short_accent, short_stem = splitvals[1], splitvals[2], splitvals[3]
	decl = ine(decl)
	-- Resolve aliases
	if decl then
		decl = rsub(decl, "^ъ%-", "")
	end
	short_accent = ine(short_accent)
	short_stem = ine(short_stem)
	if short_stem and not short_accent then
		error("With explicit short stem " .. short_stem .. ", must specify short accent")
	end
	if not decl or decl == "ь" then
		local base, ending = rmatch(lemma, "^(.*)([ыиіо]́?й)$")
		if base then
			if ending == "ий" and decl == "ь" then
				ending = "ьий"
			elseif ending == "ій" and decl == "ь" then
				ending = "ьій"
			end
			-- -ий/-ій will be converted to -ый after velars and sibilants
			-- by the caller
			return base, com.make_unstressed(ending), short_accent, short_stem
		else
			-- It appears that short, mixed and proper adjectives are always
			-- either of the -ов/ев/ёв or -ин/ын types. The former type is
			-- always (or almost always?) short, while the latter can be
			-- either; apparently mixed is the more "modern" type of
			-- declension, and short is "older". However, both -ов/ев/ёв or
			-- -ин/ын are of type "proper" (similar to "short") when
			-- capitalized.
			--
			-- NOTE: Following regexp is accented
			base = rmatch(lemma, "^([" .. com.uppercase .. "].*[иы]́н)ъ?$")
			if base then
				return base, "stressed-proper", short_accent, short_stem
			end
			base = rmatch(lemma, "^([" .. com.uppercase .. "].*[еёо]́?в)ъ?$")
			if not base then
				-- Following regexp is not stressed
				base = rmatch(lemma, "^([" .. com.uppercase .. "].*[иы]н)ъ?$")
			end
			if base then
				return base, "proper", short_accent, short_stem
			end
			base = rmatch(lemma, "^(.*[еёо]́?в)ъ?$")
			if base then
				return base, "short", short_accent, short_stem
			end
			base = rmatch(lemma, "(.*[иы]́н)ъ?$") --accented
			if base then
				return base, "stressed-short", short_accent, short_stem
			end
			base = rmatch(lemma, "(.*[иы]н)ъ?$") --unaccented
			if base then
				return base, "mixed", short_accent, short_stem
				-- error("With -ин/ын adjectives, must specify 'short' or 'mixed':" .. lemma)
			end
			error("Cannot determine stem type of adjective: " .. lemma)
		end
	elseif ut.contains({"short", "stressed-short", "mixed", "proper",
		"stressed-proper"}, decl) then
		local base, ending = rmatch(lemma, "^(.-)ъ?$")
		assert(base)
		return base, decl, short_accent, short_stem
	else
		return lemma, decl, short_accent, short_stem
	end
end

-- Add a possible suffix to the bare stem, according to the declension and
-- value of OLD. This may be -ь, -ъ, -й or nothing. We need to do this here
-- because we don't actually attach such a suffix in attach_unstressed() due
-- to situations where we don't want the suffix added, e.g. бескра́йний with
-- dereduced nom sg бескра́ен without expected -ь.
local function add_bare_suffix(bare, old, decl, dereduced)
	if old and decl ~= "ій" then
		return bare .. "ъ"
	elseif decl == "ий" or decl == "ій" then
		-- This next special case is mentioned in Zaliznyak's 1980 grammatical
		-- dictionary for adjectives (footnote, p. 60).
		if dereduced and rfind(bare, "[нН]$") then
			-- FIXME: What happens in this case old-style? I assume that
			-- -ъ is added, but this is a guess.
			return bare .. (old and "ъ" or "")
		elseif rfind(bare, "[" .. com.vowel .. "]́?$") then
			-- This happens with adjectives like длинноше́ий, short masculine
			-- singular длинноше́й.
			return bare .. "й"
		else
			return bare .. "ь"
		end
	else
		return bare
	end
end

-- Construct bare form. Return nil if unable.
local function dereduce_stem(accented_stem, short_accent, old, decl)
	local ret = com.dereduce_stem(accented_stem, nil, rfind(short_accent, "^b"))
	if not ret then
		return nil
	end
	return add_bare_suffix(ret, old, decl, true)
end

-- Construct and set bare and short form in args, and canonicalize
-- short accent spec, handling cases *, (1) and (2). Return canonicalized
-- short accent and the short declension, which is usually the same as
-- the corresponding long one.
construct_bare_and_short_stem = function(args, short_accent, short_stem,
	accented_stem, old, decl)
	-- Check if short forms allowed; if not, no short-form params can be given.
	-- Construct bare version of stem; used for cases where the ending
	-- is non-syllabic (i.e. short masculine singular of long adjectives,
	-- and masculine singular of short, mixed and proper adjectives). Comes
	-- from short masculine or 3rd argument if explicitly given, else from the
	-- accented stem, possibly with the dereduction transformation applied
	-- (if * occurs in the short accent spec).
	local reducible, sc1, sc2
	if short_accent then
		short_accent, reducible = rsubb(short_accent, "%*", "")
		short_accent, sc1 = rsubb(short_accent, "%(1%)", "")
		short_accent, sc2 = rsubb(short_accent, "%(2%)", "")
	end
	if sc1 or sc2 then
		-- Reducible isn't compatible with sc1 or sc2, but Zaliznyak's
		-- dictionary always seems to notate sc1 and sc2 with reducible *,
		-- so ignore it.
		reducible = false
	end
	if sc1 and sc2 then
		error("Special cases 1 and 2, i.e. (1) and (2), not compatible")
	end

	local explicit_short_stem = short_stem
	local short_decl = decl

	-- Construct short stem. May be explicitly given, else comes from
	-- end-accented stem.
	short_stem = short_stem or accented_stem
	-- Try to accent unaccented short stem (happens only when explicitly given),
	-- but be conservative -- only if monosyllabic, since otherwise we have
	-- no idea where stress should end up; after all, the explicit short stem
	-- is for exceptional cases.
	if com.is_unstressed(short_stem) and com.is_monosyllabic(short_stem) then
		short_stem = com.make_ending_stressed(short_stem)
	end

	if sc2 then
		if not rfind(short_stem, "нн$") then
			error("With special case 2, stem needs to end in -нн: " .. short_stem)
		end
		short_stem = rsub(short_stem, "нн$", "н")
	end

	-- Construct bare form, used for short masculine; but use explicitly
	-- given form if present.
	local bare = args.short_m or args[3]
	if not bare then
		if reducible then
			bare = dereduce_stem(short_stem, short_accent, old, decl)
			if not bare then
				error("Unable to dereduce stem: " .. short_stem)
			end
		-- Special case when there isn't a short masculine singular and
		-- the other forms are rare.
		elseif short_accent == "b" and decl == "ой" and not explicit_short_stem then
			bare = nil
			short_decl = "ой-rare"
		else
			bare = short_stem
			if sc1 then
				if not rfind(bare, "нн$") then
					error("With special case 1, stem needs to end in -нн: " .. bare)
				end
				bare = rsub(bare, "нн$", "н")
			end
			-- With special case 1 or 2, we don't ever want -ь added, so treat
			-- it like a reducible (that may be why these are marked as
			-- reducible in Zaliznyak).
			bare = add_bare_suffix(bare, old, decl, sc1 or sc2)
		end
	end

	args.short_stem = short_stem
	args.short_ustem = com.make_unstressed_once(short_stem)
	args.bare = bare

	return short_accent, short_decl
end

-- Deduce the short accent pattern given short masc, fem, neut and plural.
-- Each value should be a list of strings.
deduce_short_accent = function(args)
	local masc = canonicalize_override(args.short_m or args[short_cases.short_m])
	local fem = canonicalize_override(args.short_f or args[short_cases.short_f])
	local neut = canonicalize_override(args.short_n or args[short_cases.short_n])
	local pl = canonicalize_override(args.short_p or args[short_cases.short_p])

	local function convert_to_plus_minus(list)
		if not list then return "missing" end
		assert(type(list) == "table")
		if #list == 0 then
			return "missing"
		end
		local stresses = {}
		for _, x in ipairs(list) do
			table.insert(stresses, (com.is_ending_stressed(x) or com.is_monosyllabic(x)) and "+" or "-")
		end
		if #stresses == 1 then
			return stresses[1]
		end
		local has_plus = ut.contains(stresses, "+")
		local has_minus = ut.contains(stresses, "-")
		if has_plus and has_minus then
			return "-+"
		elseif has_plus then
			return "+"
		else
			assert(has_minus)
			return "-"
		end
	end

	masc = convert_to_plus_minus(masc)
	fem = convert_to_plus_minus(fem)
	neut = convert_to_plus_minus(neut)
	pl = convert_to_plus_minus(pl)

	if masc == "missing" and fem == "missing" and neut == "missing" and
			pl == "missing" then
		return "missing"
	elseif masc == "missing" and fem ~= "missing" and neut ~= "missing" and
			pl ~= "missing" then
		return "masc-missing"
	elseif masc == "missing" or fem == "missing" or neut == "missing" or
			pl == "missing" then
		return "part-missing"
	end
	-- If the pattern calls for end stress in the masc, then masc should
	-- be end-stressed; otherwise it may or may not be end-stressed.
	for pattern, stressvals in pairs(short_stress_patterns) do
		if stressvals.f == fem and stressvals.n == neut and stressvals.p == pl
			and (stressvals.m ~= "+" or stressvals.m == masc) then
			return pattern
		end
	end

	return "unknown"
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
	["nom_n"] = "о́",
	["nom_f"] = "а́",
	["nom_p"] = "ы́",
	["gen_m"] = "а́",
	["gen_f"] = "о́й",
	["gen_p"] = "ы́х",
	["dat_m"] = "у́",
	["dat_f"] = "о́й",
	["dat_p"] = "ы́м",
	["acc_f"] = "у́",
	["acc_n"] = "о́",
	["ins_m"] = "ы́м",
	["ins_f"] = {"о́й", "о́ю"},
	["ins_p"] = "ы́ми",
	["pre_m"] = "о́м",
	["pre_f"] = "о́й",
	["pre_p"] = "ы́х",
}

declensions["stressed-short"] = mw.clone(declensions["short"])
declensions["stressed-short"]["pre_m"] = "е́"

declensions["mixed"] = {
	["nom_m"] = "",
	["nom_n"] = "о",
	["nom_f"] = "а",
	["nom_p"] = "ы",
	["gen_m"] = {"ого", "а2"},
	["gen_f"] = "ой",
	["gen_p"] = "ых",
	["dat_m"] = {"ому", "у2"},
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

internal_notes_table["mixed"] = "<sup>2</sup> Dated."
internal_notes_genders["mixed"] = {"m"}
internal_notes_table_old["mixed"] = "<sup>2</sup> Dated."
internal_notes_genders_old["mixed"] = {"m"}

declensions["proper"] = {
	["nom_m"] = "",
	["nom_n"] = nil,
	["nom_f"] = "а́",
	["nom_p"] = "ы́",
	["gen_m"] = "а́",
	["gen_f"] = "о́й",
	["gen_p"] = "ы́х",
	["dat_m"] = "у́",
	["dat_f"] = "о́й",
	["dat_p"] = "ы́м",
	["acc_f"] = "у́",
	["acc_n"] = nil,
	["ins_m"] = "ы́м",
	["ins_f"] = {"о́й", "о́ю1"},
	["ins_p"] = "ы́ми",
	["pre_m"] = "е́",
	["pre_f"] = "о́й",
	["pre_p"] = "ы́х",
}

declensions["stressed-proper"] = declensions["proper"]

for _, decl in ipairs({"proper", "stressed-proper"}) do
	internal_notes_table[decl] = "<sup>1</sup> Rare."
	internal_notes_table_old[decl] = "<sup>1</sup> Rare."
	internal_notes_genders[decl] = {"f"}
	internal_notes_genders_old[decl] = {"f"}
end

declensions["$"] = {
	["nom_m"] = "",
	["nom_n"] = "",
	["nom_f"] = "",
	["nom_p"] = "",
	["gen_m"] = "",
	["gen_f"] = "",
	["gen_p"] = "",
	["dat_m"] = "",
	["dat_f"] = "",
	["dat_p"] = "",
	["acc_f"] = "",
	-- don't do this; instead we default it to nom_n
	-- ["acc_n"] = "",
	["ins_m"] = "",
	["ins_f"] = "",
	["ins_p"] = "",
	["pre_m"] = "",
	["pre_f"] = "",
	["pre_p"] = "",
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

short_internal_notes_table["ой-rare"] = "<sup>1</sup> Rare."
short_internal_notes_table_old["ой-rare"] = "<sup>1</sup> Rare."

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

declensions_old["stressed-short"] = mw.clone(declensions_old["short"])
declensions_old["stressed-short"]["pre_m"] = "ѣ́"

declensions_old["mixed"] = {
	["nom_m"] = "ъ",
	["nom_n"] = "о",
	["nom_f"] = "а",
	["nom_p"] = "ы",
	["gen_m"] = {"аго", "а1"},
	["gen_f"] = "ой",
	["gen_p"] = "ыхъ",
	["dat_m"] = {"ому", "у1"},
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

declensions_old["proper"] = {
	["nom_m"] = "ъ",
	["nom_n"] = nil,
	["nom_f"] = "а́",
	["nom_p"] = "ы́",
	["gen_m"] = "а́",
	["gen_f"] = "о́й",
	["gen_p"] = "ы́хъ",
	["dat_m"] = "у́",
	["dat_f"] = "о́й",
	["dat_p"] = "ы́мъ",
	["acc_f"] = "у́",
	["acc_n"] = nil,
	["ins_m"] = "ы́мъ",
    ["ins_f"] = {"о́й", "о́ю1"},
	["ins_p"] = "ы́ми",
	["pre_m"] = "ѣ́",
	["pre_f"] = "о́й",
	["pre_p"] = "ы́хъ",
}

declensions_old["stressed-proper"] = declensions_old["proper"]

declensions_old["$"] = declensions["$"]

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

local consonantal_suffixes = ut.list_to_set({"", "ь", "й"})

local old_consonantal_suffixes = ut.list_to_set({"ъ", "ь", "й"})

--------------------------------------------------------------------------
--                           Declension functions                       --
--------------------------------------------------------------------------

local function combine_stem_and_suffix(stem, suf, rules, old)
	local first = usub(suf, 1, 1)
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

local function attach_unstressed(args, suf, stem, ustem)
	local old = args.old
	if suf == nil then
		return nil
	elseif old and old_consonantal_suffixes[suf] or not old and consonantal_suffixes[suf] then
		if not args.bare then
			return nil
		elseif rfind(args.bare, old and "[йьъ]$" or "[йь]$") then
			return args.bare
		elseif suf == "ъ" then
			return args.bare .. suf
		else
			return args.bare
		end
	end
	suf = com.make_unstressed(suf)
	local rules = unstressed_rules[ulower(usub(stem, -1))]
	return combine_stem_and_suffix(stem, suf, rules, old)
end

local function attach_stressed(args, suf, stem, ustem)
	local old = args.old
	if suf == nil then
		return nil
	elseif not rfind(suf, "[ё́]") then -- if suf has no "ё" or accent marks
		return attach_unstressed(args, suf, stem, ustem)
	end
	local rules = stressed_rules[ulower(usub(ustem, -1))]
	return combine_stem_and_suffix(ustem, suf, rules, old)
end

local function attach_both(args, suf, stem, ustem)
	local results = {}
	-- Examples with stems with ё on Zaliznyak p. 61 list the
	-- ending-stressed forms first, so go with that.
	ut.insert_if_not(results, attach_stressed(args, suf, stem, ustem))
	ut.insert_if_not(results, attach_unstressed(args, suf, stem, ustem))
	return results
end

local function attach_with(args, suf, fun, stem, ustem)
	if type(suf) == "table" then
		local tbl = {}
		for _, x in ipairs(suf) do
			insert_list_into_table(tbl, attach_with(args, x, fun, stem, ustem))
		end
		return tbl
	else
		local funval = fun(args, suf, stem, ustem)
		if funval then
			local tbl = {}
			if type(funval) ~= "table" then
				funval = {funval}
			end
			for _, x in ipairs(funval) do
				table.insert(tbl, x .. args.suffix)
			end
			return tbl
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
	for _, case in ipairs(args.old and old_long_cases or long_cases) do
		gen_form(args, decl, case, attacher)
	end
	-- default acc_n to nom_n; applies chiefly in the invariable declension
	-- (used with manual declension tables)
	if not args.acc_n then
		args.acc_n = args.nom_n
	end
end

canonicalize_override = function(val)
	if not val then return nil end
	return rsplit(val, "%s*,%s*")
end

handle_forms_and_overrides = function(args, short_forms_allowed)
	for _, case in ipairs(args.old and old_long_cases or long_cases) do
		args[case] = canonicalize_override(args[case]) or args.forms[case]
	end
	for case, argnum in pairs(short_cases) do
		if short_forms_allowed then
			if args.forms[case] then
				local lastarg = #(args.forms[case])
				if lastarg > 0 and args.shorttailall then
					args.forms[case][lastarg] = args.forms[case][lastarg] .. args.shorttailall
				end
				if lastarg > 1 and args.shorttail then
					args.forms[case][lastarg] = args.forms[case][lastarg] .. args.shorttail
				end
			end
			args[case] = canonicalize_override(args[case] or args[argnum]) or args.forms[case]
		else
			args[case] = nil
		end
	end

	-- Convert an empty list to nil, so that an mdash is inserted. This happens,
	-- for example, with words like голубой where args.bare is set to nil.
	for _, case in ipairs(args.old and old_cases or cases) do
		if args[case] and #args[case] == 0 then
			args[case] = nil
		end
	end
end

--------------------------------------------------------------------------
--                        Short adjective declension                    --
--------------------------------------------------------------------------

short_declensions["ый"] = { m="", f="а́", n="о́", p="ы́" }
short_declensions["ой"] = short_declensions["ый"]
short_declensions["ой-rare"] = { m="", f="а́1", n="о́1", p="ы́1" }
short_declensions["ий"] = { m="ь", f="я́", n="е́", p="и́" }
short_declensions_old["ый"] = { m="ъ", f="а́", n="о́", p="ы́" }
short_declensions_old["ой"] = short_declensions_old["ый"]
short_declensions_old["ой-rare"] = { m="ъ", f="а́1", n="о́1", p="ы́1" }
short_declensions_old["ій"] = short_declensions["ий"]

-- Short adjective stress patterns:
--   "-" = stem-stressed
--   "+" = ending-stressed (drawn onto the last syllable of stem in masculine)
--   "-+" = both possibilities
short_stress_patterns["a"] = { m="-", f="-", n="-", p="-" }
short_stress_patterns["a'"] = { m="-", f="-+", n="-", p="-" }
short_stress_patterns["b"] = { m="+", f="+", n="+", p="+" }
short_stress_patterns["b'"] = { m="+", f="+", n="+", p="-+" }
short_stress_patterns["c"] = { m="-", f="+", n="-", p="-" }
short_stress_patterns["c'"] = { m="-", f="+", n="-", p="-+" }
short_stress_patterns["c''"] = { m="-", f="+", n="-+", p="-+" }

local function gen_short_form(args, decl, case, fun)
	if not args.forms["short_" .. case] then
		args.forms["short_" .. case] = {}
	end
	insert_list_into_table(args.forms["short_" .. case],
		attach_with(args, decl[case], fun, args.short_stem, args.short_ustem))
end

local attachers = {
	["+"] = attach_stressed,
	["-"] = attach_unstressed,
	["-+"] = attach_both,
}

decline_short = function(args, decl, stress_pattern)
	if stress_pattern then
		for _, case in ipairs({"m", "f", "n", "p"}) do
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
local proper_name_template = nil
local template_mp = nil
local short_clause = nil
local internal_notes_template = nil
local notes_template = nil

local function show_form(args, case)
	local ru_vals = {}
	local tr_vals = {}
	for _, x in ipairs(args[case]) do
		local entry, notes = m_table_tools.get_notes(x)
		entry = com.remove_monosyllabic_accents(entry)
		if old then
			ut.insert_if_not(ru_vals, m_links.full_link(com.make_unstressed(entry), entry, lang, nil, nil, nil, {tr = "-"}, false) .. notes)
		else
			ut.insert_if_not(ru_vals, m_links.full_link(entry, nil, lang, nil, nil, nil, {tr = "-"}, false) .. notes)
		end
		local trx = lang:transliterate(m_links.remove_links(entry))
		if case == "gen_m" then
			trx = rsub(trx, "([aoeáóé]́?)go$", "%1vo")
		end
		ut.insert_if_not(tr_vals, trx .. notes)
	end
	local term = table.concat(ru_vals, ", ")
	local tr = table.concat(tr_vals, ", ")
	return term, tr
end

-- Make the table
make_table = function(args)
	local old = args.old
	args.lemma, _ = m_links.remove_links(show_form(args, "nom_m"))
	args.title = args.title or strutils.format(old and old_title_temp or title_temp, args)

	for _, case in ipairs(old and old_cases or cases) do
		if args[case] and #args[case] == 1 and args[case][1] == "-" then
			args[case] = "&mdash;"
		elseif args[case] then
			local term, tr = show_form(args, case)
			args[case] = strutils.format(form_temp, {["term"] = term, ["tr"] = tr})
		else
			args[case] = nil
		end
	end

	local temp = not args.nom_n and proper_name_template or template

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

	args.internal_notes = table.concat(args.internal_notes, "<br />")
	args.internal_notes_clause = #args.internal_notes > 0 and strutils.format(internal_notes_template, args) or ""
	args.notes_clause = args.notes and strutils.format(notes_template, args) or ""

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
internal_notes_template = rsub(notes_template, "notes", "internal_notes")

local function template_prelude(min_width)
	min_width = min_width or "70"
	return rsub([===[
<div>
<div class="NavFrame" style="display: inline-block; min-width: MINWIDTHem">
<div class="NavHead" style="background:#eff7ff">{title}</div>
<div class="NavContent">
{\op}| style="background:#F9F9F9;text-align:center; min-width:MINWIDTHem" class="inflection-table"
|-
]===], "MINWIDTH", min_width)
end

local function template_postlude()
	return [===[|-{short_clause}
|{\cl}{internal_notes_clause}{notes_clause}</div></div></div>]===]
end

-- Used for both new-style and old-style templates
template = template_prelude() .. [===[
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
]===] .. template_postlude()

-- Used for both new-style and old-style templates
proper_name_template = template_prelude("55") .. [===[
! style="width:20%;background:#d9ebff" colspan="2" |
! style="background:#d9ebff" | masculine
! style="background:#d9ebff" | feminine
! style="background:#d9ebff" | plural
|-
! style="background:#eff7ff" colspan="2" | nominative
| {nom_m}
| {nom_f}
| {nom_p}
|-
! style="background:#eff7ff" colspan="2" | genitive
| {gen_m}
| {gen_f}
| {gen_p}
|-
! style="background:#eff7ff" colspan="2" | dative
| {dat_m}
| {dat_f}
| {dat_p}
|-
! style="background:#eff7ff" colspan="2" | accusative
| {gen_m}
| {acc_f}
| {gen_p}
|-
! style="background:#eff7ff" colspan="2" | instrumental
| {ins_m}
| {ins_f}
| {ins_p}
|-
! style="background:#eff7ff" colspan="2" | prepositional
| {pre_m}
| {pre_f}
| {pre_p}
]===] .. template_postlude()

-- Used for old-style templates
template_mp = template_prelude() .. [===[
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
]===] .. template_postlude()

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
