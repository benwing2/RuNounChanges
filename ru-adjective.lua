--[=[
	This module contains functions for creating inflection tables for Russian
	adjectives.

	Author: Benwing, rewritten from early version by Wikitiki89

	Arguments:
		1: lemma; nom sg, or just the stem if an explicit declension type is
		   given in arg 2
		2: declension type (usually omitted to autodetect based on the lemma),
		   along with any short accent type and optional irregular short stem;
		   see below.
		CASE_NUMGEN: Override a given form; see abbreviations below
		suffix: any suffix to attach unchanged to the end of each form
		notes: Notes to add to the end of the table
		title: Override the title
		shorttail: Footnote (e.g. *, 1, 2, etc.) to add to short forms if
		   there's more than one; automatically superscripted
		shorttailall: Same as shorttail= but applies to all short forms even
		   if there's only one
		CASE_NUMGEN_tail: Like shorttailall but only for a specific form
		nofull: Short forms only

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
		mp: masculine plural (old-style and special numeral tables only)
		fp: masculine plural (special numeral tables only)

	Animacy abbreviations:
		an: animate
		in: inanimate
		
	Declension-type argument (arg 2):
		Form is DECLSPEC or DECLSPEC,DECLSPEC,... where DECLSPEC is
		one of the following:
			DECLTYPE:SHORTACCENT:SHORTSTEM
			DECLTYPE:SHORTACCENT
			DECLTYPE
			SHORTACCENT:SHORTSTEM
			SHORTACCENT
			(blank)
		DECLTYPE should normally be omitted, and the declension autodetected
			from the ending; or it should be ь, to indicate that an adjective
			in -ий is of the possessive variety with an extra -ь- in most of
			the endings. Alternatively, it can be an explicit declension type,
			in which case the lemma field needs to be replaced with the bare
			stem; the following are the possibilities:
			ый ий ой ьий short mixed manual (new-style)
			ый ій ьій short stressed-short mixed proper stressed-proper
				ъ-short ъ-stressed-short ъ-mixed ъ-proper ъ-stressed-proper
				manual (old-style, where ъ-* is a synonym for *, for any *)
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
5. FIXME: In decline(), we used to default acc_n to nom_n. Now we do that in
   handle_forms_and_overrides(). Verify that this is more correct.
6. FIXME: Allow multiple heads, both to handle cases where two manual translits
   exist (or rather, one automatic and one manual), and cases where two
   stresses are possible, e.g. мину́вший or ми́нувший.
7. FIXME: Add code to generate the regular comparative. The rules are as
   follows: If the stem doesn't end in к г х, add -ee with no stress change
   if the short form is type a, else add -е́е (including type a'). If the stem
   ends in к г х, turn the last consonant into ч ж ш, add -е, and place the
   stress on the syllable preceding the ending. (E.g. дорого́й -> доро́же)
]=]--

local m_utilities = require("Module:utilities")
local ut = require("Module:utils")
local m_links = require("Module:links")
local com = require("Module:ru-common")
local nom = require("Module:ru-nominal")
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

-- Insert a single form (consisting of {RUSSIAN, TR}) or a list of such
-- forms into an existing list of such forms, adding NOTESYM (a string or nil)
-- to the new forms if not nil. Return whether an insertion was performed.
local function insert_forms_into_existing_forms(existing, newforms, notesym)
	if type(newforms) ~= "table" then
		newforms = {newforms}
	end
	local inserted = false
	for _, item in ipairs(newforms) do
		if not ut.contains(existing, item) then
			if notesym then
				item = nom.concat_paired_russian_tr(item, {notesym})
			end
	        table.insert(existing, item)
			inserted = true
	    end
	end
	return inserted
end

local function track(page)
	m_debug.track("ru-adjective/" .. page)
	return true
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
local enable_categories = true
local declensions = {}
local declensions_old = {}
local internal_notes_table = {}
local internal_notes_table_old = {}
local internal_notes_genders = {}
local internal_notes_genders_old = {}
local short_declensions = {}
local short_declensions_old = {}
-- Formerly used for the ой-rare type, which has been removed; but keep
-- the code around in case we need it later.
local short_internal_notes_table = {}
local short_internal_notes_table_old = {}
local short_stress_patterns = {}

local long_cases = {
	"nom_m", "nom_n", "nom_f", "nom_p",
	"gen_m", "gen_f", "gen_p",
	"dat_m", "dat_f", "dat_p",
	"acc_m_an", "acc_m_in", "acc_p_an", "acc_p_in",	"acc_f", "acc_n",
	"ins_m", "ins_f", "ins_p",
	"pre_m", "pre_f", "pre_p",
	-- extra old long cases
	"nom_mp",
	"acc_mp_an", "acc_mp_in",
	-- extra dva cases
	"nom_fp",
	"acc_fp_an", "acc_fp_in",
	-- extra oba cases
	"gen_mp", "gen_fp",
	"dat_mp", "dat_fp",
	"ins_mp", "ins_fp",
	"pre_mp", "pre_fp",
	-- extra cases for compounds of два
	"acc_mp", "acc_fp",
}

-- Short cases and corresponding numbered arguments
local short_cases = {
	"short_m", "short_n", "short_f", "short_p"
}

-- Create master list of all possible cases (actually case/number/gender pairs)
local all_cases = mw.clone(long_cases)
for _, case in ipairs(short_cases) do
	ut.insert_if_not(all_cases, case)
end

-- If enabled, compare this module with new version of module to make
-- sure all declensions are the same.
local test_new_ru_adjective_module = false

-- Forward references to functions
local tracking_code
local categorize
local detect_stem_and_accent_type
local construct_bare_and_short_stem
local decline
local canonicalize_override
local handle_forms_and_overrides
local decline_short
local make_table

--------------------------------------------------------------------------
--                               Main code                              --
--------------------------------------------------------------------------

-- Implementation of main entry point
function export.do_generate_forms(args, old, manual)
	local orig_args
	if test_new_ru_adjective_module then
		orig_args = mw.clone(args)
	end

	if args[3] or args[4] or args[5] or args[6] then
		error("Numbered short forms no longer supported")
	end
	
	if args.shorttailall then
		track("shorttailall")
	end
	
    local SUBPAGENAME = mw.title.getCurrentTitle().subpageText
	args.forms = {}
	args.categories = {}
	old = old or args.old
	args.old = old
	args.suffix = nom.split_russian_tr(args.suffix or "", "dopair")
	args.internal_notes = {}
	-- Superscript footnote marker at beginning of note, similarly to what's
	-- done at end of forms.
	if args.notes then
		local notes, entry = m_table_tools.get_initial_notes(args.notes)
		args.notes = notes .. entry
	end

	local overall_short_forms_allowed
	manual = manual or args[2] == "manual"
	args.manual = manual
	local decl_types = manual and "$" or args[2] or ""
	local lemmas = manual and "-" or args[1] or SUBPAGENAME
	local normal_short_classes, rare_short_classes, dated_short_classes
	local saw_no_short
	for _, lemma_and_tr in ipairs(rsplit(lemmas, ",")) do 
		-- reset these for each lemma so we get the short classes of the last
		-- lemma (doesn't really matter, as they should be the same for all
		-- lemmas)
		normal_short_classes = {}
		rare_short_classes = {}
		dated_short_classes = {}
		saw_no_short = false
		for _, decl_type in ipairs(rsplit(decl_types, ",")) do
			local lemma, lemmatr = nom.split_russian_tr(lemma_and_tr)
			-- if lemma ends with -ся, strip it and act as if suffix=ся given
			-- (or rather, prepend ся to suffix)
			local active_base = rmatch(lemma, "^(.*)ся$")
			if active_base then
				lemma = active_base
				lemmatr = nom.strip_tr_ending(lemmatr, "ся")
				args.refl = true
				args.real_suffix = nom.concat_paired_russian_tr({"ся"}, args.suffix)
			else
				args.refl = false
				args.real_suffix = args.suffix
			end

			-- Auto-detect actual decl type, and get short accent and overriding
			-- short stem, if specified.
			local stem, stemtr, short_accent, short_stem, short_stemtr, datedrare
			stem, stemtr, decl_type, short_accent, short_stem, datedrare =
				detect_stem_and_accent_type(lemma, lemmatr, decl_type, args)
			if rfind(decl_type, "^[іи]й$") and rfind(stem, "[" .. com.velar .. com.sib .. "]$") then
				decl_type = "ый"
			end
			if datedrare == "none" then
				saw_no_short = true
			end
			local short_title
			if short_accent then
				short_title = short_accent
			elseif ut.contains({"proper", "stressed-proper"}, decl_type) then
				short_title = "surname"
			elseif ut.contains({"ьій", "ьий", "short", "stressed-short", "mixed"},
				decl_type) then
				short_title = "possessive"
			end
			if short_title then	
				if datedrare == "dated" then
					ut.insert_if_not(dated_short_classes, short_title)
				elseif datedrare == "rare" then
					ut.insert_if_not(rare_short_classes, short_title)
				else
					ut.insert_if_not(normal_short_classes, short_title)
				end
			end
			if short_stem then
				short_stem, short_stemtr = nom.split_russian_tr(short_stem)
			end

			stem, args.allow_unaccented = rsubb(stem, "^%*", "")
			if args.allow_unaccented then
				track("allow-unaccented")
			end
			-- Treat suffixes without an accent, and suffixes with an accent on
			-- the initial hyphen, as if they were preceded with a *, which
			-- overrides all the logic that normally (a) normalizes the accent,
			-- and (b) complains about multisyllabic words without an accent.
			-- Don't do this if lemma is just -, which is used specially in
			-- manual declension tables.
			if lemma ~= "-" and (rfind(lemma, "^%-́") or (com.is_unstressed(lemma) and rfind(lemma, "^%-"))) then
				args.allow_unaccented = true
			end

			if not args.allow_unaccented and com.needs_accents(lemma) then
				-- Technically we don't need accents in -ой adjectives (which are
				-- always ending-stressed) and in -ый adjectives with a monosyllabic
				-- stem, such as полный (which are always stem-stressed), but it's
				-- better to enforce accents in all multisyllabic words, for
				-- consistency with nouns and verbs. Note that we still don't
				-- require an accent in monosyllabic adjectives such as злой.
				error("Lemma must have an accent in it: " .. lemma)
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
			args.stem, args.stemtr = stem, stemtr
			args.ustem, args.ustemtr = com.make_unstressed_once(stem, stemtr)
			local accented_stem, accented_stemtr = stem, stemtr
			if not args.allow_unaccented then
				if accented_stemtr and com.is_unstressed(accented_stem) ~= com.is_unstressed(accented_stemtr) then
					error("Stem " .. accented_stem .. " and translit " .. accented_stemtr .. " must have same accent pattern")
				end
				if com.is_unstressed(accented_stem) then
					accented_stem, accented_stemtr =
						com.make_ending_stressed(accented_stem, accented_stemtr)
				end
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
					error("Cannot specify short accent or short stem with declension type " .. decl_type .. ", as short forms aren't allowed")
				end
				if args.short_m or args.short_f or args.short_n or args.short_p then
					error("Cannot specify explicit short forms with declension type " .. decl_type .. ", as short forms aren't allowed")
				end
			end

			local orig_short_accent = short_accent
			local short_decl_type
			short_accent, short_decl_type = construct_bare_and_short_stem(args,
				short_accent, short_stem, short_stemtr, accented_stem,
				accented_stemtr, old, decl_type)

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
				short_stem, datedrare, short_forms_allowed)
			if not manual and enable_categories then
				categorize(decl_type, args, orig_short_accent, short_accent,
					short_stem)
			end

			decline(args, decls[decl_type], ut.contains({"ой", "stressed-short", "stressed-proper"}, decl_type))
			if short_forms_allowed and short_accent then
				decline_short(args, short_decls[short_decl_type],
					short_stress_patterns[short_accent], datedrare)
			end

			local intable = old and internal_notes_table_old or internal_notes_table
			local shortintab = old and short_internal_notes_table_old or
				short_internal_notes_table
			local internal_note = intable[decl_type] or shortintab[short_decl_type]
			if internal_note then
				ut.insert_if_not(args.internal_notes, internal_note)
			end
		end
	end

	local short_class_titles = {}
	local function make_short_class_title(short_classes, datedrare)
		local sct = table.concat(short_classes, ",") -- short class title
		if sct == "" then
			return
		end
		if not ut.contains({"surname", "possessive"}, sct) then
			-- Convert e.g. a*,a(1) into a*[(1)], either finally or followed by
			-- comma.
			sct = rsub(sct, "([abc]'*)%*,%1%*?(%([12]%))$", "%1*[%2]")
			sct = rsub(sct, "([abc]'*)%*,%1%*?(%([12]%)),", "%1*[%2],")
			-- Same for a(1),a*.
			sct = rsub(sct, "([abc]'*)%*?(%([12]%)),%1%*$", "%1*[%2]")
			sct = rsub(sct, "([abc]'*)%*?(%([12]%)),%1%*,", "%1*[%2],")
			-- Convert (1), (2) to ①, ②.
			sct = rsub(sct, "%(1%)", "①")
			sct = rsub(sct, "%(2%)", "②")
			-- Add a * before ①, ②, consistent with Zaliznyak.
			sct = rsub(sct, "([abc]'*)([①②])", "%1*%2")
			-- Avoid c'' turning into c with italics.
			sct = rsub(sct, "''", "&#39;&#39;")
			sct = "short class " .. sct
		end
		if datedrare then
			sct = datedrare .. " " .. sct
		end
		table.insert(short_class_titles, sct)
	end

	make_short_class_title(normal_short_classes, nil)
	make_short_class_title(rare_short_classes, "rare")
	make_short_class_title(dated_short_classes, "dated")
	if #short_class_titles == 0 then
		if saw_no_short then
			args.short_class_title = "no short forms"
		else
			args.short_class_title = "unknown short forms"
		end
	else
		args.short_class_title = table.concat(short_class_titles, " / ")
	end

	handle_forms_and_overrides(args, overall_short_forms_allowed)

	-- Test code to compare existing module to new one.
	if test_new_ru_adjective_module then
		local m_new_ru_adjective = require("Module:User:Benwing2/ru-adjective")
		local newargs = m_new_ru_adjective.do_generate_forms(orig_args, old, manual)
		local difdecl = false
		for _, case in ipairs(all_cases) do
			local arg = args[case]
			local newarg = newargs[case]
			if not ut.equals(arg, newarg) then
				-- Uncomment this to display the particular case and
				-- differing forms.
				--error(case .. " " .. (arg and nom.concat_forms(arg) or "nil") .. " || " .. (newarg and nom.concat_forms(newarg) or "nil"))
				track("different-decl")
				difdecl = true
			end
			break
		end
		if not difdecl then
			track("same-decl")
		end
	end

	return args
end

-- Implementation of main entry point
local function do_show(frame, old, manual)
	local args = clone_args(frame)
	local args = export.do_generate_forms(args, old, manual)
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
	-- do_generate_forms().
	local internal_notes = ingenders[decl] and ut.contains(ingenders[decl], gender) and intable[decl]
	return n, internal_notes
end

local function get_form(forms)
	local canon_forms = {}
	for _, form in ipairs(forms) do
		local ru, tr = form[1], form[2]
		local ruentry, runotes = m_table_tools.get_notes(ru)
		local trentry, trnotes
		if tr then
			trentry, trnotes = m_table_tools.get_notes(tr)
		end
		ruentry = m_links.remove_links(ruentry)
		ut.insert_if_not(canon_forms, {ruentry, trentry})
	end
	return nom.concat_forms(canon_forms)
end

-- The entry point for 'ru-adj-forms' to generate all adjective forms.
function export.generate_forms(frame)
	local args = clone_args(frame)
	local args = export.do_generate_forms(args, false)
	local ins_text = {}
	for _, case in ipairs(all_cases) do
		if args[case] then
			table.insert(ins_text, case .. "=" .. get_form(args[case]))
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
	if not ut.contains(all_cases, form) then
		error("Unrecognized form " .. form)
	end
	local args = export.do_generate_forms(args, false)
	if not args[form] then
		return ""
	else
		return get_form(args[form])
	end
end

--------------------------------------------------------------------------
--                      Tracking and categorization                     --
--------------------------------------------------------------------------

tracking_code = function(decl_class, args, orig_short_accent, short_accent,
	short_stem, datedrare, short_forms_allowed)
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
	if args.short_m or args.short_f or args.short_n or args.short_p then
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
		if datedrare == "dated" then
			dotrack("short-accent-dated")
			dotrack("short-accent-dated/" .. short_accent)
		elseif datedrare == "rare" then
			dotrack("short-accent-rare")
			dotrack("short-accent-rare/" .. short_accent)
		end
	elseif datedrare == "none" then
		dotrack("short-accent/none")
	else
		dotrack("short-accent/unknown")
	end
	if short_stem then
		dotrack("explicit-short-stem")
		dotrack("explicit-short-stem/" .. short_accent)
	end
	for _, case in ipairs(all_cases) do
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
	elseif ut.contains({"short", "stressed-short"}, decl_type) then
		insert_cat("short possessive ~")
	elseif ut.contains({"mixed"}, decl_type) then
		insert_cat("mixed possessive ~")
	elseif ut.contains({"proper", "stressed-proper"}, decl_type) then
		insert_cat("proper-name ~")
	elseif decl_type == "$" then
		insert_cat("indeclinable ~")
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
			decl_type == "ий" and "soft-stem" or
			"hard-stem"
		if stem_type == "soft-stem" or stem_type == "vowel-stem" then
			insert_cat(stem_type .. " ~")
		else
			insert_cat(stem_type .. " " .. (decl_type == "ой" and "ending-stressed" or "stem-stressed") .. " ~")
		end
	end
	if decl_type == "ой" then
		insert_cat("ending-stressed ~")
	end

	local short_forms_allowed = ut.contains({"ый", "ой", "ій", "ий"}, decl_type)
	if short_forms_allowed then
		local override_m = args.short_m
		local override_f = args.short_f
		local override_n = args.short_n
		local override_p = args.short_p
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
	end
	for _, case in ipairs(all_cases) do
		if args[case] and args[case] ~= "-" then
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
	
	if args.nofull then
		insert_cat("short-form-only ~")
	end
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

	local maintext, misctext
	if args[1] == "adj" then
		local stem, stress = rmatch(SUBPAGENAME, "^Russian ([^ ]*) ([^ *]*)-stressed adjectives")
		if not stem then
			stem, stress = rmatch(SUBPAGENAME, "^Russian ([^ ]*) (possessive) adjectives")
		end
		if not stem then
			stem = rmatch(SUBPAGENAME, "^Russian ([^ ]*) adjectives")
			stress = ""
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
		insert_category(cats, "~ by stem type and stress|" .. stem .. " " .. stress)
	elseif args[1] == "shortaccent" then
		local shortaccent = rmatch(SUBPAGENAME, "^Russian adjectives with short accent pattern ([^ ]*)")
		if not shortaccent then
			error("Invalid category name, should be e.g. \"Russian adjectives with short accent pattern c\"")
		end
		maintext = "~ with short accent pattern " .. rsub(shortaccent, "'", "&#39;") .. ", with " .. args[2] .. "."
		insert_category(cats, "~ by short accent pattern|" .. shortaccent)
	elseif args[1] == "irreg" then
		local irregularity = rmatch(SUBPAGENAME, "^Russian adjectives with irregular (.*)")
		if not irregularity then
			error("Invalid category name, should be e.g. \"Russian adjectives with irregular nominative masculine singular\"")
		end
		maintext = "~ with irregular " .. irregularity .. " (possibly along with other cases)."
		insert_category(cats, "~ by irregularity|" .. irregularity)
	elseif args[1] == "misc" then
		misctext = args[2]
		local sort_key = rmatch(SUBPAGENAME, "^Russian adjectives with (.*)")
		if not sort_key then
			sort_key = rmatch(SUBPAGENAME, "^Russian adjectives by (.*)")
		end
		if not sort_key then
			sort_key = rmatch(SUBPAGENAME, "^Russian adjectives (.*)")
		end
		if not sort_key then
			sort_key = rmatch(SUBPAGENAME, "^Russian (.*)")
		end
		if not sort_key then
			error("Invalid category name, should begin with \"Russian\": " .. SUBPAGENAME)
		end
		insert_category(cats, "~|" .. sort_key)
	else
		error("Unknown ruadjcatboiler type " .. (args[1] or "(empty)"))
	end

	return (misctext or "This category contains Russian " .. rsub(maintext, "~", "adjectives"))
		.. "\n" ..
		mw.getCurrentFrame():expandTemplate{title="ru-categoryTOC", args={}}
		.. m_utilities.format_categories(cats, lang, nil, nil, "force")
end

--------------------------------------------------------------------------
--                   Autodetection and stem munging                     --
--------------------------------------------------------------------------

-- Attempt to detect the type of the lemma based on its ending, separating
-- off the base and the ending; also extract the accent type for short
-- adjectives and optional short stem. DECL is the value passed in, and
-- might already specify the ending. Return five values: STEM, STEMTR, DECL,
-- SHORT_ACCENT (accent class of short adjective, or nil for no short
-- adjectives other than specified through overrides), SHORT_STEM (special
-- stem of short adjective, nil if same as long stem). The return value of
-- SHORT_STEM is taken directly from the argument and will include any
-- manual translit.
detect_stem_and_accent_type = function(lemma, tr, decl, args)
	local datedrare = false
	-- If it looks like a short decl type, canonicalize. [abc] for types
	-- a, b, c'', etc.; [d] for dated-*; [r] for rare-*;
	-- [-] for - (no short forms); [*(] for * and (1) and (2) modifiers,
	-- which might precede the letter.
	if rfind(decl, "^[abcdr*(-]") then
		decl = ":" .. decl
	end
	splitvals = rsplit(decl, ":")
	if #splitvals > 3 then
		error("Should be at most three colon-separated parts of a declension spec: " .. decl)
	end
	local short_accent, short_stem
	decl, short_accent, short_stem = splitvals[1], splitvals[2], splitvals[3]
	-- Check for dated variant of short accent
	local dated_short = short_accent and rmatch(short_accent, "^dated%-(.*)$")
	if dated_short then
		datedrare = "dated"
		short_accent = dated_short
	else
		-- Check for rare variant of short accent
		local rare_short = short_accent and rmatch(short_accent, "^rare%-(.*)$")
		if rare_short then
			datedrare = "rare"
			short_accent = rare_short
		end
	end

	decl = ine(decl)
	-- Resolve aliases
	if decl then
		decl = rsub(decl, "^ъ%-", "")
	end
	if short_accent == "-" then
		short_accent = nil
		datedrare = "none"
	end
	short_accent = ine(short_accent)
	short_stem = ine(short_stem)
	if short_stem and not short_accent then
		error("With explicit short stem " .. short_stem .. ", must specify short accent")
	end
	local base, ending
	-- The while loop appears to function solely as a way of allowing a
	-- jump to the end of the loop with a 'break' statement. I don't think
	-- the loop is ever run more than once.
	while true do
		if not decl or decl == "ь" then
			base, ending = rmatch(lemma, "^(.*)([ыиіо]́?й)$")
			if base then
				if ending == "ий" and decl == "ь" then
					ending = "ьий"
				elseif ending == "ій" and decl == "ь" then
					ending = "ьій"
				end
				tr = nom.strip_tr_ending(tr, ending)
				-- -ий/-ій will be converted to -ый after velars and sibilants
				-- by the caller
				decl = com.make_unstressed(ending)
				break
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
					decl = "stressed-proper"
					break
				end
				base = rmatch(lemma, "^([" .. com.uppercase .. "].*[еёо]́?в)ъ?$")
				if not base then
					-- Following regexp is not stressed
					base = rmatch(lemma, "^([" .. com.uppercase .. "].*[иы]н)ъ?$")
				end
				if base then
					decl = "proper"
					break
				end
				base = rmatch(lemma, "^(.*[еёо]́?в)ъ?$")
				if base then
					decl = "short"
					break
				end
				base = rmatch(lemma, "(.*[иы]́н)ъ?$") --accented
				if base then
					decl = "stressed-short"
					break
				end
				base = rmatch(lemma, "(.*[иы]н)ъ?$") --unaccented
				if base then
					decl = "mixed"
					break
					-- error("With -ин/ын adjectives, must specify 'short' or 'mixed':" .. lemma)
				end
				error("Cannot determine stem type of adjective: " .. lemma)
			end
		elseif ut.contains({"short", "stressed-short", "mixed", "proper",
			"stressed-proper"}, decl) then
			base = rmatch(lemma, "^(.-)ъ?$")
			assert(base)
			break
		else
			base = lemma
			break
		end
	end
	if not datedrare and (args.refl or not (decl == "ый" or decl == "ий" and not rfind(base, "[цс]к$"))) then
		datedrare = "none"
	end
	return base, tr, decl, short_accent, short_stem, datedrare
end

-- Add a possible suffix to the bare stem, according to the declension and
-- value of OLD. This may be -ь, -ъ, -й or nothing. We need to do this here
-- because we don't actually attach such a suffix in attach_unstressed() due
-- to situations where we don't want the suffix added, e.g. бескра́йний with
-- dereduced nom sg бескра́ен without expected -ь.
local function add_bare_suffix(bare, baretr, old, decl, dereduced)
	if old and decl ~= "ій" and decl ~= "$" then
		return bare .. "ъ", baretr
	elseif decl == "ий" or decl == "ій" then
		-- This next special case is mentioned in Zaliznyak's 1980 grammatical
		-- dictionary for adjectives (footnote, p. 60).
		if dereduced and rfind(bare, "[нН]$") then
			-- FIXME: What happens in this case old-style? I assume that
			-- -ъ is added, but this is a guess.
			return bare .. (old and "ъ" or ""), baretr
		elseif rfind(bare, "[" .. com.vowel .. "]́?$") then
			-- This happens with adjectives like длинноше́ий, short masculine
			-- singular длинноше́й.
			return bare .. "й", baretr and baretr .. "j" or nil
		else
			return bare .. "ь", baretr and baretr .. "ʹ" or nil
		end
	else
		return bare, baretr
	end
end

-- Construct and set bare and short form in args, and canonicalize
-- short accent spec, handling cases *, (1) and (2). Return canonicalized
-- short accent and the short declension, which is usually the same as
-- the corresponding long one.
construct_bare_and_short_stem = function(args, short_accent, short_stem,
	short_stemtr, accented_stem, accented_stemtr, old, decl)
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

	local explicit_short_stem, explicit_short_stemtr = short_stem, short_stemtr
	local short_decl = decl

	-- Construct short stem. May be explicitly given, else comes from
	-- end-accented stem.
	if not short_stem then
		short_stem, short_stemtr = accented_stem, accented_stemtr
	end
	-- Try to accent unaccented short stem (happens only when explicitly given),
	-- but be conservative -- only if monosyllabic, since otherwise we have
	-- no idea where stress should end up; after all, the explicit short stem
	-- is for exceptional cases.
	if not args.allow_unaccented then
		if short_stemtr and com.is_unstressed(short_stem) ~= com.is_unstressed(short_stemtr) then
			error("Explicit short stem " .. short_stem .. " and translit " .. short_stemtr .. " must have same accent pattern")
		end
		if com.is_monosyllabic(short_stem) then
			short_stem, short_stemtr = com.make_ending_stressed(short_stem, short_stemtr)
		elseif com.needs_accents(short_stem) then
			error("Explicit short stem " .. short_stem .. " needs an accent")
		end
	end

	if sc2 then
		if not rfind(short_stem, "нн$") then
			error("With special case 2, stem needs to end in -нн: " .. short_stem)
		end
		short_stem = rsub(short_stem, "нн$", "н")
		if short_stemtr then
			if not rfind(short_stemtr, "nn$") then
				error("With special case 2, stem translit needs to end in -nn: " .. short_stemtr)
			end
			short_stemtr = rsub(short_stemtr, "nn$", "n")
		end
	end

	-- Construct bare form, used for short masculine.
	local bare, baretr
	if reducible then
		bare, baretr = com.dereduce_stem(short_stem, short_stemtr, rfind(short_accent, "^b"))
		if not bare then
			error("Unable to dereduce stem: " .. short_stem)
		end
		bare, baretr = add_bare_suffix(bare, baretr, old, decl, true)
	else
		bare, baretr = short_stem, short_stemtr
		if sc1 then
			if not rfind(bare, "нн$") then
				error("With special case 1, stem needs to end in -нн: " .. bare)
			end
			bare = rsub(bare, "нн$", "н")
			if baretr then
				if not rfind(baretr, "nn$") then
					error("With special case 1, stem translit needs to end in -nn: " .. baretr)
				end
				baretr = rsub(baretr, "nn$", "n")
			end
		end
		-- With special case 1 or 2, we don't ever want -ь added, so treat
		-- it like a reducible (that may be why these are marked as
		-- reducible in Zaliznyak).
		bare, baretr = add_bare_suffix(bare, baretr, old, decl, sc1 or sc2)
	end

	args.short_stem, args.short_stemtr = short_stem, short_stemtr
	args.short_ustem, args.short_ustemtr = com.make_unstressed_once(short_stem, short_stemtr)
	args.bare, args.baretr = bare, baretr

	return short_accent, short_decl
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

-- These can be stressed in ничья́ "draw, tie (in sports)".
declensions["ьий"] = {
	["nom_m"] = "и́й",
	["nom_n"] = "ье́",
	["nom_f"] = "ья́",
	["nom_p"] = "ьи́",
	["gen_m"] = "ье́го",
	["gen_f"] = "ье́й",
	["gen_p"] = "ьи́х",
	["dat_m"] = "ье́му",
	["dat_f"] = "ье́й",
	["dat_p"] = "ьи́м",
	["acc_f"] = "ью́",
	["acc_n"] = "ье́",
	["ins_m"] = "ьи́м",
	["ins_f"] = {"ье́й", "ье́ю"},
	["ins_p"] = "ьи́ми",
	["pre_m"] = "ье́м",
	["pre_f"] = "ье́й",
	["pre_p"] = "ьи́х",
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

internal_notes_table["mixed"] = "<sup>2</sup> Obsolete."
internal_notes_genders["mixed"] = {"m"}
internal_notes_table_old["mixed"] = "<sup>2</sup> Obsolete."
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
	-- for old-style templates, два, оба, compounds of два
	["nom_mp"] = "",
	["nom_fp"] = "",
	["gen_mp"] = "",
	["gen_fp"] = "",
	["dat_mp"] = "",
	["dat_fp"] = "",
	-- don't do this; instead we default them to nom_mp, nom_fp
	-- ["acc_mp"] = "",
	-- ["acc_fp"] = "",
	["ins_mp"] = "",
	["ins_fp"] = "",
	["pre_mp"] = "",
	["pre_fp"] = "",
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

local function frob_genitive_masc(decl)
	-- signal to combine_stem_and_suffix() to use the special tr_adj()
	-- function so that -го gets transliterated to -vo
	if type(decl["gen_m"]) == "table" then
		local entries = {}
		for _, entry in ipairs(decl["gen_m"]) do
			table.insert(entries, rsub(entry, "го$", "го<adj>"))
		end
		decl["gen_m"] = entries
	else
		decl["gen_m"] = rsub(decl["gen_m"], "го$", "го<adj>")
	end
end

-- Frob declensions, adding <adj> to gen_m forms ending in -го. This is
-- a signal to add manual translit early on that renders -го as -vo.
for decltype, decl in pairs(declensions_old) do
	frob_genitive_masc(decl)
end
for decltype, decl in pairs(declensions) do
	frob_genitive_masc(decl)
end

--------------------------------------------------------------------------
--                           Declension functions                       --
--------------------------------------------------------------------------

local function attach_unstressed(args, suf, short)
	local stem, stemtr
	if short then
		stem, stemtr = args.short_stem, args.short_stemtr
	else
		stem, stemtr = args.stem, args.stemtr
	end
	if suf == nil then
		return nil
	elseif nom.nonsyllabic_suffixes[suf] then
		if not args.bare then
			return nil
		elseif rfind(args.bare, "[йьъ]$") then
			return {args.bare, args.baretr}
		elseif suf == "ъ" then
			return nom.concat_russian_tr(args.bare, args.baretr, suf, nil, "dopair")
		else
			return {args.bare, args.baretr}
		end
	end
	suf = com.make_unstressed(suf)
	local rules = nom.unstressed_rules[ulower(usub(stem, -1))]
	-- The parens around the return value drop all but the first return value
	return (nom.combine_stem_and_suffix(stem, stemtr, suf, rules, args.old))
end

local function attach_stressed(args, suf, short)
	local ustem, ustemtr
	if short then
		ustem, ustemtr = args.short_ustem, args.short_ustemtr
	else
		ustem, ustemtr = args.ustem, args.ustemtr
	end
	if suf == nil then
		return nil
	elseif not rfind(suf, "[ё́]") then -- if suf has no "ё" or accent marks
		return attach_unstressed(args, suf, short)
	end
	local rules = nom.stressed_rules[ulower(usub(ustem, -1))]
	-- The parens around the return value drop all but the first return value
	return (nom.combine_stem_and_suffix(ustem, ustemtr, suf, rules, args.old))
end

local function attach_both(args, suf, short)
	local results = {}
	-- Examples with stems with ё on Zaliznyak p. 61 list the
	-- ending-stressed forms first, so go with that.
	-- NOTE: This assumes we get one value returned, not a list of such values.
	table.insert(results, attach_stressed(args, suf, short))
	table.insert(results, attach_unstressed(args, suf, short))
	return results
end

local function attach_with(args, suf, fun, short)
	if type(suf) == "table" then
		local all_combineds = {}
		for _, x in ipairs(suf) do
			local combineds = attach_with(args, x, fun, short)
			for _, combined in ipairs(combineds) do
				table.insert(all_combineds, combined)
			end
		end
		return all_combineds
	else
		local funval = fun(args, suf, short)
		if funval then
			local tbl = {}
			assert(type(funval) == "table")
			if type(funval[1]) ~= "table" then
				funval = {funval}
			end
			for _, x in ipairs(funval) do
				table.insert(tbl,
					nom.concat_paired_russian_tr(x, args.real_suffix))
			end
			return tbl
		else
			return {}
		end
	end
end

local function gen_form(args, decl, case, fun)
	if not args.forms[case] then
		args.forms[case] = {}
	end
	insert_forms_into_existing_forms(args.forms[case],
		attach_with(args, decl[case], fun, false))
end

decline = function(args, decl, stressed)
	local attacher = stressed and attach_stressed or attach_unstressed
	for _, case in ipairs(long_cases) do
		gen_form(args, decl, case, attacher)
	end
end

canonicalize_override = function(args, case)
	local val = args[case]
	if not val then
		return nil
	end
	val = rsplit(val, "%s*,%s*")

	-- auto-accent/check for necessary accents
	local newvals = {}
	for _, v in ipairs(val) do
		local ru, tr = nom.split_russian_tr(v)
		if not args.allow_unaccented then
			if tr and com.is_unstressed(ru) ~= com.is_unstressed(tr) then
				error("Override " .. ru .. " and translit " .. tr .. " must have same accent pattern")
			end
			-- it's safe to accent monosyllabic stems
			if com.is_monosyllabic(ru) then
				ru, tr = com.make_ending_stressed(ru, tr)
			elseif com.needs_accents(ru) then
				error("Override " .. ru .. " for case " .. case .. " requires an accent")
			end
		end
		table.insert(newvals, {ru, tr})
	end
	val = newvals

	return val
end

handle_forms_and_overrides = function(args, short_forms_allowed)
	local f = args.forms

	local function append_note_all(case, value)
		value = nom.split_russian_tr(value, "dopair")
		if f[case] then
			for i=1,#f[case] do
				f[case][i] = nom.concat_paired_russian_tr(f[case][i], value)
			end
		end
	end

	local function append_note_last(case, value, gt_one)
		value = nom.split_russian_tr(value, "dopair")
		if f[case] then
			local lastarg = #f[case]
			if lastarg > (gt_one and 1 or 0) then
				f[case][lastarg] = nom.concat_paired_russian_tr(f[case][lastarg], value)
			end
		end
	end

	for _, case in ipairs(long_cases) do
		if args[case .. "_tail"] then
			append_note_last(case, args[case .. "_tail"])
		end
		if args[case .. "_tailall"] then
			append_note_all(case, args[case .. "_tailall"])
		end
		args[case] = canonicalize_override(args, case) or f[case]
	end

	for _, case in ipairs(short_cases) do
		if short_forms_allowed then
			if args[case .. "_tail"] then
				append_note_last(case, args[case .. "_tail"])
			end
			if args[case .. "_tailall"] then
				append_note_all(case, args[case .. "_tailall"])
			end
			if args.shorttailall then
				append_note_all(case, args.shorttailall)
			end
			if args.shorttail then
				append_note_last(case, args.shorttail, ">1")
			end
			args[case] = canonicalize_override(args, case) or f[case]
		else
			args[case] = nil
		end
	end

	-- Convert an empty list to nil, so that an mdash is inserted. This happens,
	-- for example, with words like голубой where args.bare is set to nil.
	for _, case in ipairs(all_cases) do
		if args[case] and #args[case] == 0 then
			args[case] = nil
		end
	end

	-- default acc_n to nom_n; applies chiefly in the indeclinable declension
	-- (used with manual declension tables)
	if not args.acc_n then
		args.acc_n = args.nom_n
	end

	-- default inanimate/animate accusative variants as appropriate; this is
	-- almost always correct, but not with e.g. два́дцать оди́н, where the
	-- masculine animate accusative два́дцать одного́ differs from both the
	-- masculine nominative два́дцать оди́н and the masculine genitive
	-- двадцати́ одного́.
	if not args.acc_m_an then
		args.acc_m_an = args.gen_m
	end
	if not args.acc_m_in then
		args.acc_m_in = args.nom_m
	end
	-- Compounds of два do not have animacy; everything else does.
	-- Only copy either the with-animacy or without-animacy variants to avoid
	-- having both forms in {{ru-generate-adj-forms}}.
	if args.special ~= "cdva" then
		if not args.acc_p_an then
			args.acc_p_an = args.gen_p
		end
		if not args.acc_p_in then
			args.acc_p_in = args.nom_p
		end
		if not args.acc_mp_an then
			args.acc_mp_an = args.gen_mp
		end
		if not args.acc_mp_in then
			args.acc_mp_in = args.nom_mp
		end
		if not args.acc_fp_an then
			args.acc_fp_an = args.gen_fp
		end
		if not args.acc_fp_in then
			args.acc_fp_in = args.nom_fp
		end
	else
		if not args.acc_mp then
			args.acc_mp = args.nom_mp
		end
		if not args.acc_fp then
			args.acc_fp = args.nom_fp
		end
	end
end

--------------------------------------------------------------------------
--                        Short adjective declension                    --
--------------------------------------------------------------------------

short_declensions["ый"] = { m="", f="а́", n="о́", p="ы́" }
short_declensions["ой"] = short_declensions["ый"]
short_declensions["ий"] = { m="ь", f="я́", n="е́", p="и́" }
short_declensions_old["ый"] = { m="ъ", f="а́", n="о́", p="ы́" }
short_declensions_old["ой"] = short_declensions_old["ый"]
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

local function gen_short_form(args, decl, case, fun, datedrare)
	if not args.forms["short_" .. case] then
		args.forms["short_" .. case] = {}
	end
	local inserted = insert_forms_into_existing_forms(
		args.forms["short_" .. case], attach_with(args, decl[case], fun, true),
		(datedrare == "dated" and datedrare == "rare") and "*" or nil)
	if datedrare == "dated" and inserted then
		ut.insert_if_not(args.internal_notes, "<sup>*</sup> Dated.")
	elseif datedrare == "rare" and inserted then
		ut.insert_if_not(args.internal_notes, "<sup>*</sup> Rare.")
	end
end

local attachers = {
	["+"] = attach_stressed,
	["-"] = attach_unstressed,
	["-+"] = attach_both,
}

decline_short = function(args, decl, stress_pattern, dated)
	if stress_pattern then
		for _, case in ipairs({"m", "f", "n", "p"}) do
			gen_short_form(args, decl, case, attachers[stress_pattern[case]],
				dated)
		end
	end
end

--------------------------------------------------------------------------
--                             Create the table                         --
--------------------------------------------------------------------------

local title_temp = [=[Declension of <b lang="ru" class="Cyrl">{lemma}</b> ({short_class_title})]=]
local old_title_temp = [=[Pre-reform declension of <b lang="ru" class="Cyrl">{lemma}</b> ({short_class_title})]=]
local title_temp_no_short_msg = [=[Declension of <b lang="ru" class="Cyrl">{lemma}</b>]=]
local old_title_temp_no_short_msg = [=[Pre-reform declension of <b lang="ru" class="Cyrl">{lemma}</b>]=]

local template = nil
local full_clause = nil
local template_no_neuter = nil
local full_clause_no_neuter = nil
local proper_name_template = nil
local proper_name_full_clause = nil
local template_mp = nil
local full_clause_mp = nil
local template_mp_no_neuter = nil
local full_clause_mp_no_neuter = nil
local short_clause_separator = nil
local short_clause = nil
local short_clause_no_neuter_separator = nil
local short_clause_no_neuter = nil
local short_clause_mp_separator = nil
local short_clause_mp = nil
local short_clause_mp_no_neuter_separator = nil
local short_clause_mp_no_neuter = nil
local internal_notes_template = nil
local notes_template = nil

local function get_accel_forms(old, special, has_nom_mp)
	return {
		-- used with all variants
		nom_m = "nom|m|s",
		nom_f = "nom|f|s",
		nom_n = "nom|n|s",
		-- not used with special; applies to all genders normally but only
		-- feminine and neuter with old=1
		nom_p = old and has_nom_mp and "nom|f//n|p" or "nom|p",
		-- only used with old=1 or special; applies to the masculine and neuter if
		-- special, but only masculine if old=1
		nom_mp = special and "nom|m//n|p" or "nom|m|p",
		-- only used with special
		nom_fp = "nom|f|p",
		-- the remaining singulars and non-gendered plurals used with all variants
		-- except special == "oba"
		gen_m = "gen|m//n|s",
		gen_f = "gen|f|s",
		gen_p = "gen|p",
		dat_m = "dat|m//n|s",
		dat_f = "dat|f|s",
		dat_p = "dat|p",
		acc_m_an = "an|acc|m|s",
		acc_m_in = "in|acc|m|s",
		acc_f = "acc|f|s",
		acc_n = "acc|n|s",
		-- the following two not used with special in ("dva", "oba"); applies to
		-- all genders normally but only feminine and neuter with old=1
		acc_p_an = old and has_nom_mp and "an|acc|f//n|p" or "an|acc|p",
		acc_p_in = old and has_nom_mp and "in|acc|f//n|p" or "in|acc|p",
		-- the following two only used with old=1 or special in ("dva|oba");
		-- applies to the masculine and neuter if special, but only masculine if
		-- old=1
		acc_mp_an = special and "an|acc|m//n|p" or "an|acc|m|p",
		acc_mp_in = special and "in|acc|m//n|p" or "in|acc|m|p",
		-- the following two only used with special in ("dva", "oba")
		acc_fp_an = "an|acc|f|p",
		acc_fp_in = "in|acc|f|p",
		-- the next 6 are used with all variants except special == "oba"
		ins_m = "ins|m//n|s",
		ins_f = "ins|f|s",
		ins_p = "ins|p",
		pre_m = "pre|m//n|s",
		pre_f = "pre|f|s",
		pre_p = "pre|p",
		-- the following two gendered plurals are only used with special == "cdva"
		acc_mp == "acc|m//n|p",
		acc_fp = "acc|f|p",
		-- the remaining gendered plurals are only used with special == "oba"
		gen_mp = "gen|m//n|p",
		gen_fp = "gen|f|p",
		dat_mp = "dat|m//n|p",
		dat_fp = "dat|f|p",
		ins_mp = "ins|m//n|p",
		ins_fp = "ins|f|p",
		pre_mp = "pre|m//n|p",
		pre_fp = "pre|f|p",
		-- short forms
		short_m = "short|m|s",
		short_f = "short|f|s",
		short_n = "short|n|s",
		short_p = "short|p",
	}
end

-- Generate a string to substitute into a particular form in a Wiki-markup
-- table. FORMS is the list of forms.
local function show_form(forms, old, lemma, accel_form)
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

	if #forms == 1 and forms[1][1] == "-" then
		return "&mdash;"
	end

	for _, form in ipairs(forms) do
		local ru, tr = form[1], form[2]
		local ruentry, runotes = m_table_tools.get_notes(ru)
		local trentry, trnotes
		if tr then
			trentry, trnotes = m_table_tools.get_notes(tr)
		end
		ruentry = com.remove_monosyllabic_accents(ruentry)
		local ruspan, trspan
		local accel = {form = accel_form, transliteration = tr}
		if old then
			ruspan = m_links.full_link({lang = lang, term = com.remove_jo(ruentry), alt = ruentry, tr = "-", accel}) .. runotes
		else
			ruspan = m_links.full_link({lang = lang, term = ruentry, tr = "-", accel}) .. runotes
		end
		if not trentry then
			trentry = nom.translit_no_links(ruentry)
		end
		if not trnotes then
			trnotes = nom.translit_no_links(runotes)
		end
		trspan = m_links.remove_links(trentry) .. trnotes
		trspan = require("Module:script utilities").tag_translit(trspan, lang, "default", " style=\"color: #888;\"")

		if lemma then
			-- insert_if_not(lemmavals, ruspan .. " (" .. trspan .. ")")
			ut.insert_if_not(lemmavals, ruspan)
		else
			ut.insert_if_not(russianvals, ruspan)
			ut.insert_if_not(latinvals, trspan)
		end
	end

	if lemma then
		return table.concat(lemmavals, ", ")
	else
		local russian_span = table.concat(russianvals, ", ")
		local latin_span = table.concat(latinvals, ", ")
		return russian_span .. "<br />" .. latin_span
	end
end

-- Make the table
make_table = function(args)
	args.lemma = m_links.remove_links(show_form(args.special and args.nom_mp or
		args.nofull and args.short_m or args.nom_m, args.old, true, nil))
	args.title = args.title or strutils.format(
		(args.special or args.manual) and args.old and old_title_temp_no_short_msg or
		(args.special or args.manual) and title_temp_no_short_msg or
		args.old and old_title_temp or
		title_temp,
		args)

	local has_nom_mp = args.nom_mp and not (#args.nom_mp == 1 and args.nom_mp[1][1] == "-")

	local accel_forms = get_accel_forms(args.old, args.special, has_nom_mp)

	for _, case in ipairs(all_cases) do
		if args[case] then
			local accel_form = accel_forms[case]
			if not accel_form then
				error("Unrecognized case " .. case .. " when looking up accelerator form")
			end
			if noneuter then
				accel_form = rsub(accel_form, "//n", "")
			end
			args[case] = show_form(args[case], args.old, false, accel_form)
		else
			args[case] = nil
		end
	end

	local temp = args.special == "oba" and template_oba or
		(args.special == "dva" or args.special == "cdva") and template_dva or
		not args.nom_n and proper_name_template or
		args.noneuter and args.old and has_nom_mp and template_mp_no_neuter or
		args.noneuter and template_no_neuter or
		args.old and has_nom_mp and template_mp or
		template
	local fullc = args.special == "oba" and full_clause_oba or
		args.special == "dva" and full_clause_dva or
		args.special == "cdva" and full_clause_compound_dva or
		not args.nom_n and proper_name_full_clause or
		args.noneuter and args.old and has_nom_mp and full_clause_mp_no_neuter or
		args.noneuter and full_clause_no_neuter or
		args.old and has_nom_mp and full_clause_mp or
		full_clause

	if args.old then
		if has_nom_mp then
			if args.short_m or args.short_n or args.short_f or args.short_p then
				args.short_m = args.short_m or "&mdash;"
				args.short_n = args.short_n or "&mdash;"
				args.short_f = args.short_f or "&mdash;"
				args.short_p = args.short_p or "&mdash;"
				args.shortsep = not args.nofull and (
					args.noneuter and short_clause_mp_no_neuter_separator or short_clause_mp_separator
				) or ""
				args.short_clause = strutils.format(args.noneuter and short_clause_mp_no_neuter or short_clause_mp, args)
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
			args.shortsep = not args.nofull and (
				args.noneuter and short_clause_no_neuter_separator or short_clause_separator
			) or ""
			args.short_clause = strutils.format(args.noneuter and short_clause_no_neuter or short_clause, args)
		else
			args.short_clause = ""
		end
	end

	if not args.nofull then
		args.full_clause = strutils.format(fullc, args)
	else
		args.full_clause = ""
	end

	args.internal_notes = table.concat(args.internal_notes, "<br />")
	args.internal_notes_clause = #args.internal_notes > 0 and strutils.format(internal_notes_template, args) or ""
	args.notes_clause = args.notes and strutils.format(notes_template, args) or ""

	return strutils.format(temp, args)
end

-- Used for new-style templates
short_clause_separator = [===[
! style="height:0.2em;background:#d9ebff" colspan="6" |
|-
]===]

-- Used for new-style templates
short_clause = [===[

{shortsep}! style="background:#eff7ff" colspan="2" | short form
| {short_m}
| {short_n}
| {short_f}
| {short_p}]===]

-- Used for new-style templates
short_clause_no_neuter_separator = [===[
! style="height:0.2em;background:#d9ebff" colspan="5" |
|-
]===]

-- Used for new-style templates
short_clause_no_neuter = [===[

{shortsep}! style="background:#eff7ff" colspan="2" | short form
| {short_m}
| {short_f}
| {short_p}]===]

-- Used for old-style templates
short_clause_mp_separator = [===[
! style="height:0.2em;background:#d9ebff" colspan="7" |
|-
]===]

-- Used for old-style templates
short_clause_mp = [===[

{shortsep}! style="background:#eff7ff" colspan="2" | short form
| {short_m}
| {short_n}
| {short_f}
| colspan="2" | {short_p}]===]

-- Used for old-style templates
short_clause_mp_no_neuter_separator = [===[
! style="height:0.2em;background:#d9ebff" colspan="6" |
|-
]===]

-- Used for old-style templates
short_clause_mp_no_neuter = [===[

{shortsep}! style="background:#eff7ff" colspan="2" | short form
| {short_m}
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
	return [===[{full_clause}|-{short_clause}
|{\cl}{internal_notes_clause}{notes_clause}</div></div></div>]===]
end

-- Used for both new-style and old-style templates
template = template_prelude() .. [===[
! style="width:20%;background:#d9ebff" colspan="2" |
! style="background:#d9ebff" | masculine
! style="background:#d9ebff" | neuter
! style="background:#d9ebff" | feminine
! style="background:#d9ebff" | plural
]===] .. template_postlude()

-- Used for both new-style and old-style templates
full_clause = [===[
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
| {acc_m_an}
| rowspan="2" | {acc_n}
| rowspan="2" | {acc_f}
| {acc_p_an}
|-
! style="background:#eff7ff" | inanimate
| {acc_m_in}
| {acc_p_in}
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
]===]

-- Used for both new-style and old-style templates
template_no_neuter = template_prelude("55") .. [===[
! style="width:20%;background:#d9ebff" colspan="2" |
! style="background:#d9ebff" | masculine
! style="background:#d9ebff" | feminine
! style="background:#d9ebff" | plural
]===] .. template_postlude()

-- Used for both new-style and old-style templates
full_clause_no_neuter = [===[
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
! style="background:#eff7ff" rowspan="2" | accusative
! style="background:#eff7ff" | animate
| {acc_m_an}
| rowspan="2" | {acc_f}
| {acc_p_an}
|-
! style="background:#eff7ff" | inanimate
| {acc_m_in}
| {acc_p_in}
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
]===]

-- Used for both new-style and old-style templates
proper_name_template = template_prelude("55") .. [===[
! style="width:20%;background:#d9ebff" colspan="2" |
! style="background:#d9ebff" | masculine
! style="background:#d9ebff" | feminine
! style="background:#d9ebff" | plural
]===] .. template_postlude()

-- Used for both new-style and old-style templates
proper_name_full_clause = [===[
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
| {acc_m_an}
| {acc_f}
| {acc_p_an}
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
]===]

-- Used for old-style templates
template_mp = template_prelude() .. [===[
! style="width:20%;background:#d9ebff" colspan="2" |
! style="background:#d9ebff" | masculine
! style="background:#d9ebff" | neuter
! style="background:#d9ebff" | feminine
! style="background:#d9ebff" | m. plural
! style="background:#d9ebff" | n./f. plural
]===] .. template_postlude()

-- Used for old-style templates
full_clause_mp = [===[
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
| {acc_m_an}
| rowspan="2" | {acc_n}
| rowspan="2" | {acc_f}
| colspan="2" | {acc_p_an}
|-
! style="background:#eff7ff" | inanimate
| {acc_m_in}
| {acc_mp_in}
| {acc_p_in}
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
]===]

-- Used for old-style templates
template_mp_no_neuter = template_prelude("60") .. [===[
! style="width:20%;background:#d9ebff" colspan="2" |
! style="background:#d9ebff" | masculine
! style="background:#d9ebff" | feminine
! style="background:#d9ebff" | m. plural
! style="background:#d9ebff" | n./f. plural
]===] .. template_postlude()

-- Used for old-style templates
full_clause_mp_no_neuter = [===[
|-
! style="background:#eff7ff" colspan="2" | nominative
| {nom_m}
| {nom_f}
| {nom_mp}
| {nom_p}
|-
! style="background:#eff7ff" colspan="2" | genitive
| {gen_m}
| {gen_f}
| colspan="2" | {gen_p}
|-
! style="background:#eff7ff" colspan="2" | dative
| {dat_m}
| {dat_f}
| colspan="2" | {dat_p}
|-
! style="background:#eff7ff" rowspan="2" | accusative
! style="background:#eff7ff" | animate
| {acc_m_an}
| rowspan="2" | {acc_f}
| colspan="2" | {acc_p_an}
|-
! style="background:#eff7ff" | inanimate
| {acc_m_in}
| {acc_mp_in}
| {acc_p_in}
|-
! style="background:#eff7ff" colspan="2" | instrumental
| {ins_m}
| {ins_f}
| colspan="2" | {ins_p}
|-
! style="background:#eff7ff" colspan="2" | prepositional
| {pre_m}
| {pre_f}
| colspan="2" | {pre_p}
]===]

-- Used for два and compounds
template_dva = template_prelude("55") .. [===[
! style="width:20%;background:#d9ebff" colspan="2" |
! style="background:#d9ebff" | masculine/neuter
! style="background:#d9ebff" | feminine
]===] .. template_postlude()

-- Used for both new-style and old-style templates of два (only for два itself,
-- which has an animacy distinction; not for compounds)
full_clause_dva = [===[
|-
! style="background:#eff7ff" colspan="2" | nominative
| {nom_mp}
| {nom_fp}
|-
! style="background:#eff7ff" colspan="2" | genitive
| colspan="2" | {gen_p}
|-
! style="background:#eff7ff" colspan="2" | dative
| colspan="2" | {dat_p}
|-
! style="background:#eff7ff" rowspan="2" | accusative
! style="background:#eff7ff" | animate
| colspan="2" | {acc_p_an}
|-
! style="background:#eff7ff" | inanimate
| {acc_mp_in}
| {acc_fp_in}
|-
! style="background:#eff7ff" colspan="2" | instrumental
| colspan="2" | {ins_p}
|-
! style="background:#eff7ff" colspan="2" | prepositional
| colspan="2" | {pre_p}
]===]

-- Used for both new-style and old-style templates of compounds of два
full_clause_compound_dva = [===[
|-
! style="background:#eff7ff" colspan="2" | nominative
| {nom_mp}
| {nom_fp}
|-
! style="background:#eff7ff" colspan="2" | genitive
| colspan="2" | {gen_p}
|-
! style="background:#eff7ff" colspan="2" | dative
| colspan="2" | {dat_p}
|-
! style="background:#eff7ff" colspan="2" | accusative
| {acc_mp}
| {acc_fp}
|-
! style="background:#eff7ff" colspan="2" | instrumental
| colspan="2" | {ins_p}
|-
! style="background:#eff7ff" colspan="2" | prepositional
| colspan="2" | {pre_p}
]===]

-- Used for оба
template_oba = template_prelude() .. [===[
! style="width:20%;background:#d9ebff" colspan="2" |
! style="background:#d9ebff" | masculine
! style="background:#d9ebff" | neuter
! style="background:#d9ebff" | feminine
! style="background:#d9ebff" | m./n. plural
! style="background:#d9ebff" | f. plural
]===] .. template_postlude()

-- Used for both new-style and old-style templates of оба
full_clause_oba = [===[
|-
! style="background:#eff7ff" colspan="2" | nominative
| {nom_m}
| {nom_n}
| {nom_f}
| {nom_mp}
| {nom_fp}
|-
! style="background:#eff7ff" colspan="2" | genitive
| colspan="2" | {gen_m}
| {gen_f}
| {gen_mp}
| {gen_fp}
|-
! style="background:#eff7ff" colspan="2" | dative
| colspan="2" | {dat_m}
| {dat_f}
| {dat_mp}
| {dat_fp}
|-
! style="background:#eff7ff" rowspan="2" | accusative
! style="background:#eff7ff" | animate
| {acc_m_an}
| rowspan="2" | {acc_n}
| rowspan="2" | {acc_f}
| {acc_mp_an}
| {acc_fp_an}
|-
! style="background:#eff7ff" | inanimate
| {acc_m_in}
| {acc_mp_in}
| {acc_fp_in}
|-
! style="background:#eff7ff" colspan="2" | instrumental
| colspan="2" | {ins_m}
| {ins_f}
| {ins_mp}
| {ins_fp}
|-
! style="background:#eff7ff" colspan="2" | prepositional
| colspan="2" | {pre_m}
| {pre_f}
| {pre_mp}
| {pre_fp}
]===]

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
