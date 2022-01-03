--[=[
	This module implements the headword templates {{ru-noun}}, {{ru-adj}},
	{{ru-adv}}, {{ru-noun+}}, etc. The main entry point is show(), which is
	meant to be called from one of the above templates. However, {{ru-noun+}}
	uses the entry point noun_plus(), and {{ru-noun-m}} (not currently used)
	uses the entry point noun_multi(). When calling show(), the first parameter
	of the #invoke call is the part of speech. Other parameters are taken from
	the parent template call.

	The implementations for different types of headwords (different parts of
	speech) are set in pos_functions[POS] for a given POS (part of speech).
	The value is a 2-argument function of (ARGS, DATA):
	-- ARGS on entry is initialized to the parent template call's arguments,
	   with blank arguments converted to nil.
	-- DATA on entry is initialized to a table, with entries like this:
		local data = {lang = lang, pos_category = poscat, categories = {}, heads = {}, translits = {}, genders = {}, inflections = {}}
	   where:
	   -- LANG is an object describing the language.
	   -- POS_CATEGORY is the (plural) part of speech, e.g. "nouns" or "verbs".
	   -- CATEGORIES on entry is a list of categories. There will be one category
		  corresponding to the part of speech (e.g. [[Category:Russian adverbs]]),
		  and possibly additional categories such as [[Category:Requests for accents in Russian entries]]
		  and [[Category:Russian terms with irregular pronunciations]]. On exit
		  it may contain additional categories to place the page in.
	   -- HEADS on entry is a list of the headwords, taken directly from arguments
		  '1', 'head2', 'head3', ...
	   -- TRANSLITS on entry is a list of translits, matching one-to-one with
		  heads in HEADS, or nil if no manual translit was specified.
	   -- GENDERS on entry is an empty list. On exit it should be the appropriate
		  gender settings, and will be passed directly to full_headword() in
		  [[Module:headword]]. See the documentation for that module for info on
		  the format of this setting.
	   -- INFLECTIONS on entry is an empty list. On exit it should be the
		  appropriate inflections to be displayed in the headword, and will be
		  passed directly to full_headword() in [[Module:headword]]. See the
		  documentation for that module for info on the format of this setting.
]=]--

local com = require("Module:User:Benwing2/ru-common")
local m_links = require("Module:links")
local m_headword = require("Module:headword")
local m_utilities = require("Module:utilities")
local m_table = require("Module:table")
local m_table_tools = require("Module:table tools")
local m_debug = require("Module:debug")
local m_ru_translit = require("Module:ru-translit")

local export = {}
local pos_functions = {}

local lang = require("Module:languages").getByCode("ru")

local IRREGMARKER = "△"
local HYPMARKER = "⟐"
local latin_text_class = "[a-zščžěáéíóúýàèìòùỳâêîôûŷạẹịọụỵȧėȯẏ]"
-- Forward references
local do_noun

local u = mw.ustring.char
local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local ulower = mw.ustring.lower

local AC = u(0x0301) -- acute =  ́

local function ine(x) return x ~= "" and x; end

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

local function glossary_link(entry, text)
	text = text or entry
	return "[[Appendix:Glossary#" .. entry .. "|" .. text .. "]]"
end

local function track(page)
	m_debug.track("ru-headword/" .. page)
	return true
end

local function insert_if_not(list, item)
	return m_table.insertIfNot(list, item, nil, "deep compare")
end

-- Clone args while also assigning nil to empty strings.
local function clone_args(in_args)
	local args = {}
	for pname, param in pairs(in_args) do
		if param == "" then args[pname] = nil
		else args[pname] = param
		end
	end
	return args
end

local function make_qualifier_text(text)
	return require("Module:qualifier").format_qualifier(text)
end

-- Split a list of "RUSSIAN" or "RUSSIAN/TRANSLIT" strings into a list of {RUSSIAN, TRANSLIT} objects.
local function split_list_into_russian_tr(list)
	local splitlist = {}
	for i, item in ipairs(list) do
		table.insert(splitlist, com.split_russian_tr(item, "dopair"))
	end
	return splitlist
end

-- Convert {RUSSIAN, TR} in `form` into an "inflection object" of the form needed for one of the inflection parts in
-- the inflections passed to [[Module:headword]]. The format of this object is as follows:
--   {term = "TERM", translit = "TRANSLIT", hypothetical = BOOLEAN, accel = ACCELERATOR_OBJECT} where
-- ACCELERATOR_OBJECT is
--   {form = "FORM USED IN {{inflection of}} OR SIMILAR", lemma = "TERM" or LIST, lemma_translit = "TRANSLIT" or LIST,
--    target = "|head= USED IN {{head}} OR SIMILAR", translit = "|tr= USED IN {{head}} OR SIMILAR"}
-- Normally, `target` in the accelerator object is handled automatically and taken from the displayed text of the link,
-- but this doesn't work in comparative forms, where the form reads e.g. "([[покраснее|по]])[[краснее|красне́е]]" but we
-- want the target to be just красне́е. So we always specify the target and translit, but default it to the form and its
-- translit unless the `target` parameter is passed in. Note also that we don't specify translit="TRANSLIT" in the
-- outer (inflection) object because then the translit will be displayed in the headword inflection.
--
-- `data` is used to fetch the values of `lemma` and `lemma_translit` in the accelerator object and to add a "Requests
-- for accents" category if the form is missing accents. (FIXME: Consider throwing an error instead.) `pos` is the
-- part of speech of the lemma and is used for naming the "Requests for accents" category. `accel_form` goes in the
-- accelerator object; if nil, no accelerator object is specified. `target` is used to populate the `target` and
-- `translit` fields in the accelerator object and is the form used to check for missing accents; in both cases it
-- defaults to `form` if omitted.
local function russian_tr_to_inflection_obj(data, form, pos, accel_form, target)
	local ru, tr
	if type(form) == "string" then
		ru, tr = com.split_russian_tr(form)
	else
		ru, tr = unpack(form)
	end
	local sawhyp_ru, sawhyp_tr
	ru, sawhyp_ru = rsubb(ru, HYPMARKER, "")
	if tr then
		tr, sawhyp_tr = rsubb(tr, HYPMARKER, "")
	end
	local accel
	local target_ru, target_tr
	if target then
		target_ru, target_tr = unpack(target)
	else
		target_ru, target_tr = ru, tr
	end
	if accel_form then
		-- FIXME, consider removing redundant translit
		-- Stuff in data.heads and data.translits gets destructively modified by [[Module:headword]] (YUCK), so clone it.
		accel = {form = accel_form, lemma = m_table.deepcopy(data.heads),
			lemma_translit = m_table.deepcopy(data.translits), target = target_ru, translit = target_tr
		}
	end
	local obj = {term=ru, hypothetical=sawhyp_ru or sawhyp_tr, accel=accel}
	--Uncomment to see the manual translit for each inflected part.
	--local obj = {term=ru, translit=tr, hypothetical=sawhyp_ru or sawhyp_tr, accel=accel}
	if com.needs_accents(m_links.remove_links(target_ru)) then
		table.insert(data.categories, "Requests for accents in Russian " .. pos .. " entries")
	end
	return obj
end

-- Add a full inflection (e.g. genitive singular of nouns, abstract noun of adjectives) to `data.inflections`. `label`
-- is the label of the inflection (e.g. "abstract noun"). `forms` is a list of {RUSSIAN, TRANSLIT} objects specifying
-- the inflections, or a list of "RUSSIAN//TRANSLIT" strings. `pos` is the part of speech of the lemma, used for adding
-- a "Request for accents" category. `accel_form` is the accelerator form (e.g. "gen|s" for genitive singular) of the
-- inflection, or nil to add no accelerator.
local function add_inflection(data, label, forms, pos, accel_form)
	if #forms == 0 then
		return
	end
	local parts = {label = label}
	if #forms > 0 and type(forms[1]) == "string" then
		forms = split_list_into_russian_tr(forms)
	end
	forms = com.combine_translit_of_duplicate_forms(forms)
	for _, form in ipairs(forms) do
		insert_if_not(parts, russian_tr_to_inflection_obj(data, form, pos, accel_form))
	end
	table.insert(data.inflections, parts)
end

-- Zip the lemma heads and corresponding translits into a list of {RUSSIAN, TRANSLIT} objects. In the process, split
-- any combined translits (e.g. "azerbajdžánskij, azɛrbajdžánskij" with corresponding head "азербайджа́нский") into two
-- separate objects.
local function zip_head_and_translit(data)
	return com.split_translit_of_duplicate_forms(com.zip_forms(data.heads, data.translits))
end

-- The main entry point.
function export.show(frame)
	local iparams = {
		[1] = {required = true, desc = "part of speech"},
	}
	local iargs = require("Module:parameters").process(frame.args, iparams)
	local poscat = iargs[1]

	local params = {
		[1] = {list = "head"}, -- heads
		["tr"] = {list = true}, -- translits
		["noposcat"] = {type = "boolean"}, -- don't add part of speech category
		["noacccat"] = {type = "boolean"}, -- don't add missing-accent tracking category
		["notrcat"] = {type = "boolean"}, -- don't add 'irregular pronunciations' tracking category
	}
	if pos_functions[poscat] then
		for key, val in pairs(pos_functions[poscat].params) do
			params[key] = val
		end
	end

	local parargs = frame:getParent().args
	local args = require("Module:parameters").process(parargs, params)

	local data = {lang = lang, pos_category = poscat, categories = {}, heads = {},
		translits = {}, redundant_translits = {}, genders = {}, inflections = {},
		noposcat = args.noposcat}

	local PAGENAME = mw.title.getCurrentTitle().text
	local NAMESPACE = mw.title.getCurrentTitle().nsText

	-- Get the head parameters
	local heads = args[1]
	if #heads == 0 then
		heads = {PAGENAME}
	end
	data.heads = heads
	for i, head in ipairs(heads) do
		-- Catch errors in arguments where headword doesn't match page title,
		-- but only in the main namespace; for the moment, do only with tracking.
		local head_no_links = m_links.remove_links(head)
		local head_noaccent = com.remove_accents(head_no_links)
		if NAMESPACE == "" and head_noaccent ~= PAGENAME then
			track("bad-headword")
			--error("Headword " .. head .. " doesn't match pagename " .. PAGENAME)
		end

		if com.needs_accents(head_no_links) then
			if not args.noacccat then
				table.insert(data.categories, "Requests for accents in Russian entries")
			end
		end

		local tr = args.tr[i]
		if tr then
			tr = com.decompose(tr)
			local tr_gen = com.translit_no_links(head)
			if tr == tr_gen then
				data.redundant_translits[i] = true
			elseif not args.notrcat then
				table.insert(data.categories, "Russian terms with irregular pronunciations")
			end
			data.translits[i] = tr
		end
	end

	if pos_functions[poscat] then
		pos_functions[poscat].func(args, data)
	end

	return m_headword.full_headword(data) .. (data.extra_text or "")
end

-- Common params shared by {{ru-noun}} and {{ru-noun+}}.
local function add_common_noun_params(params)
	params["unknown_decl"] = {type = "boolean"} -- declension unknown
	params["unknown_stress"] = {type = "boolean"} -- stress position unknown
	params["unknown_pattern"] = {type = "boolean"} -- stress pattern (a, b, b', ...) unknown
	params["unknown_gender"] = {type = "boolean"} -- gender unknown
	params["unknown_animacy"] = {type = "boolean"} -- animacy unknown
	params["f"] = {list = true} -- feminine equivalent(s)
	params["m"] = {list = true} -- masculine equivalent(s)
	params["adj"] = {list = true} -- related adjective(s)
	params["dim"] = {list = true} -- diminutive(s)
	return params
end

-- Implementation of {{ru-noun+}} and never-created {{ru-noun-m}}, an attempt to implement a slightly different
-- interface for nouns. If we plan to add a different noun interface, it should follow the form of {{uk-noun}}; e.g.
-- instead of existing {{ru-noun-table|[[дви́гатель]]|m|_|[[внутренний|вну́треннего]]|+$|_|[[сгорание|сгора́ния]]|$}}, it
-- should look more like {{ru-ndecl|дви́гатель<M> [[внутренний|вну́треннего]] [[сгорание|сгора́ния]]}}.
local function noun_plus_or_multi(frame, multi)
	local iparams = {
		[1] = {required = true, desc = "part of speech"},
		["old"] = {type = "boolean"},
		["ndef"] = {},
	}
	local iargs = require("Module:parameters").process(frame.args, iparams)
	local poscat = iargs[1]

	local params = add_common_noun_params({
		["g"] = {list = true}, -- genders
		["notes"] = {list = true}, -- "footnotes" displayed after headword
	})
	local parargs = frame:getParent().args
	local headword_args, args = require("Module:parameters").process(parargs, params, "return unknown")
	args = clone_args(args)
	-- default value of n=, used in ru-proper noun+ where ndef=sg is set
	args.ndef = args.ndef or iargs.ndef

	local m_noun = require("Module:ru-noun")
	if multi then
		args = m_noun.do_generate_forms_multi(args, iargs.old)
	else
		args = m_noun.do_generate_forms(args, iargs.old)
	end

	local data = {lang = lang, pos_category = poscat, categories = {}, inflections = {}}

	-- do explicit genders using g=, g2=, etc.
	data.genders = headword_args.g
	-- if none, do inferred or explicit genders taken from declension;
	-- clone because will get destructively modified by do_noun()
	if #data.genders == 0 then
		data.genders = mw.clone(args.genders)
	end

	local saw_note = false

	-- Given a list of {RU, TR} pairs, where TR may be nil, separate off the
	-- footnote symbols from RU and TR, link the remainder if it's not already
	-- linked, and remove monosyllabic accents (but not from multiword
	-- expressions).
	local function prepare_entry(list, ishead)
		if not list or #list == 0 then
			return {{"-"}}
		end
		local newlist = {}
		for _, x in ipairs(list) do
			local ru, tr = x[1], x[2]
			-- separate_notes() just returns the note, but get_notes() adds
			-- <sup>...</sup>. We want the former for checking whether the
			-- note is nonempty after removing IRREGMARKER (if we use the
			-- latter we'll get <sup></sup> in the case of just IRREGMARKER),
			-- but the latter when generating the inflectional form.
			if not ishead and (rfind(ru, "[%[|%]]") or tr and rfind(tr, "[%[|%]]")) then
				track("form-with-link")
			end
			local ruentry, runotes = m_table_tools.separate_notes(ru)
			local sawhyp
			runotes = rsub(runotes, IRREGMARKER, "") -- remove note of irregularity
			runotes, sawhyp = rsubb(runotes, HYPMARKER, "")
			if runotes ~= "" then
				saw_note = true
			end
			runotes = m_table_tools.superscript_notes(runotes)
			local trentry, trnotes
			if tr then
				trentry, trnotes = m_table_tools.separate_notes(tr)
				trnotes = rsub(trnotes, IRREGMARKER, "") -- remove note of irregularity
				trnotes = m_table_tools.superscript_notes(trnotes)
			end
			ruentry, trentry = com.remove_monosyllabic_accents(ruentry, trentry)
			if sawhyp then
				table.insert(newlist, {ruentry .. runotes .. HYPMARKER,
					trentry and trentry .. trnotes .. HYPMARKER})
			elseif ishead then
				table.insert(newlist, {ruentry .. runotes, trentry and trentry .. trnotes})
			else
				local ruspan, trspan
				if ruentry == "-" then
					ruspan = "-"
				elseif rfind(ruentry, "[%[|%]]") then
					-- don't add links around a form that's already linked
					ruspan = ruentry .. runotes
				else
					ruspan = "[[" .. ruentry .. "]]" .. runotes
				end
				if trentry then
					trspan = trentry .. trnotes
				end
				table.insert(newlist, {ruspan, trspan})
			end
		end
		return newlist
	end

	local argsn = args.n or args.ndef
	local heads, genitives, plurals, genpls
	if argsn == "p" then
		heads = prepare_entry(args.nom_pl_linked, "ishead")
		genitives = prepare_entry(args.gen_pl)
		plurals = {{"-"}}
		genpls = {{"-"}}
	else
		heads = prepare_entry(args.nom_sg_linked, "ishead")
		genitives = prepare_entry(args.gen_sg)
		plurals = argsn == "s" and {{"-"}} or prepare_entry(args.nom_pl)
		genpls = argsn == "s" and {{"-"}} or prepare_entry(args.gen_pl)
	end

	heads = com.combine_translit_of_duplicate_forms(heads)
	data.heads, data.translits = com.unzip_forms(heads)
	if next(data.translits) and not args.notrcat then
		table.insert(data.categories, "Russian terms with irregular pronunciations")
	end

	do_noun(data, headword_args, argsn == "s", genitives, plurals, genpls, poscat)

	local notes = headword_args.notes
	local notes_segments = {}
	if saw_note then
		for _, note in ipairs(notes) do
			table.insert(notes_segments, " " .. make_qualifier_text(note))
		end
	end
	local notes_text = table.concat(notes_segments, "")

	return m_headword.full_headword(data) .. (data.extra_text or "") .. notes_text
end

-- External entry point; implementation of {{ru-noun+}}.
function export.noun_plus(frame)
	return noun_plus_or_multi(frame, false)
end

-- External entry point; implementation of never-created {{ru-noun-m}}.
function export.noun_multi(frame)
	return noun_plus_or_multi(frame, true)
end

-- Implementation of {{ru-noun}} and {{ru-proper noun}}.
local function get_noun_pos(pos)
	return {
		params = add_common_noun_params({
			[2] = {list = "g", required = true, default = "?"}, -- genders
			[3] = {list = "gen"}, -- genitive singulars, or - for indeclinable
			[4] = {list = "pl"}, -- nominative plurals
			[5] = {list = "genpl"}, -- genitive plurals
			["altyo"] = {type = "boolean"}, -- called from {{ru-noun-alt-ё}} or variants
			["manual"] = {type = "boolean"}, -- allow manual specification of principal parts
		}),
		func = function(args, data)
			data.genders = args[2]
			local genitives = args[3]
			local plurals = args[4]
			local genpls = args[5]
			if not args.altyo and not args.manual and genitives[1] ~= "-" and
				mw.title.getCurrentTitle().nsText == "" and
				not args.unknown_decl and not args.unknown_stress and
				not args.unknown_pattern and not args.unknown_gender and
				not args.unknown_animacy then
				error("[[Template:ru-noun]] can now only be used with indeclinable and manually-declined nouns; use [[Template:ru-noun+]] instead")
			end
			genitives = split_list_into_russian_tr(genitives)
			plurals = split_list_into_russian_tr(plurals)
			genpls = split_list_into_russian_tr(genpls)
			do_noun(data, args, pos == "proper nouns", genitives, plurals, genpls, pos)
		end,
	}
end

pos_functions["proper nouns"] = get_noun_pos("proper nouns")

pos_functions["pronouns"] = get_noun_pos("pronouns")

-- Display additional inflection information for a noun.
pos_functions["nouns"] = get_noun_pos("nouns")

-- Guts of {{ru-noun}} and {{ru-noun+}}.
do_noun = function(data, args, no_plural, genitives, plurals, genpls, pos)
	local recognized_genders = {
		"", -- not allowed when singular; this is needed because some invariant plural only words have no gender to speak of
		"m",
		"f",
		"n",
		"mf",
		"mfbysense",
	}
	local recognized_animacies = {
		"",
		"?",
		"an",
		"in",
	}
	local recognized_numbers = {
		"",
		"p",
	}

	local function insert_if_not_blank(seq, part)
		if part ~= "" then
			table.insert(seq, part)
		end
	end

	local singular_genders = {} -- a set
	local plural_genders = {} -- a set

	-- Generate the allowed gender/number/animacy specs.
	for _, number in ipairs(recognized_numbers) do
		for _, gender in ipairs(recognized_genders) do
			for _, animacy in ipairs(recognized_animacies) do
				local set = number == "" and singular_genders or plural_genders
				if gender ~= "" or number == "p" then -- disallow blank gender unless plural
					local gender_number = {}
					insert_if_not_blank(gender_number, gender)
					insert_if_not_blank(gender_number, animacy)
					insert_if_not_blank(gender_number, number)
					local spec = table.concat(gender_number, "-")
					set[spec] = true
				end
			end
		end
	end

	local seen_gender = nil
	local seen_animacy = nil
	for i, g in ipairs(data.genders) do
		if g == "m" then
			g = "m-?"
		elseif g == "m-p" then
			g = "m-?-p"
		elseif g == "f" and plurals[1] ~= "-" and not no_plural then
			g = "f-?"
		elseif g == "f-p" then
			g = "f-?-p"
		elseif g == "p" then
			g = "?-p"
		end

		if not singular_genders[g] and not plural_genders[g] and g ~= "?" and g ~= "?-in" and g ~= "?-an" then
			error("Unrecognized gender: " .. g)
		end

		data.genders[i] = g

		-- Categorize by number
		if plural_genders[g] then
			if g == "?-p" or g == "an-p" or g == "in-p" then
				table.insert(data.categories, "Russian pluralia tantum with incomplete gender")
			end
		end
	end

	local function add_noun_forms(label, forms, accel_form)
		add_inflection(data, label, forms, "noun", accel_form)
	end

	local function form_is_intentionally_missing(forms)
		return #forms > 0 and forms[1][1] == "-"
	end

	-- Add the genitive forms
	if form_is_intentionally_missing(genitives) then
		table.insert(data.inflections, {label = glossary_link("indeclinable")})
		table.insert(data.categories, "Russian indeclinable nouns")
	else
		add_noun_forms("genitive", genitives)
	end

	-- Add the plural forms
	-- If the noun is plural only, then ignore the 4th parameter altogether
	if form_is_intentionally_missing(genitives) then
		-- do nothing
	elseif plural_genders[data.genders[1]] then
		table.insert(data.inflections, {label = glossary_link("plural only")})
	elseif form_is_intentionally_missing(plurals) then
		if pos ~= "proper nouns" then
			table.insert(data.inflections, {label = glossary_link("uncountable")})
			table.insert(data.categories, "Russian uncountable nouns")
		end
	else
		add_noun_forms("nominative plural", plurals)
		--This can't work currently because the forms in plurals are already
		--linked with spans around them, superscripted notes, etc.
		--for _, form in ipairs(plurals) do
		--	local ru, tr = unpack(form)
		--	if not rfind(form, HYPMARKER) and not mw.title.new(form).exists then
		--		table.insert(categories, "Russian nouns with missing plurals")
		--	end
		--end
	end

	-- Add the genitive plural forms
	if form_is_intentionally_missing(genitives) or plural_genders[data.genders[1]]
		or form_is_intentionally_missing(plurals) then
		-- indeclinable, plural only or uncountable; do nothing
	elseif form_is_intentionally_missing(genpls) then
		table.insert(data.inflections, {label = "genitive plural missing"})
	else
		add_noun_forms("genitive plural", genpls)
	end

	-- Add the feminine forms
	add_noun_forms("feminine", args.f, "f")
	-- Add the masculine forms; intentionally no accelerator as the masculine forms are lemmas and need manual handling
	add_noun_forms("masculine", args.m)
	-- Add the related adjective forms; intentionally no accelerator, need manual handling
	add_noun_forms("related adjective", args.adj)
	-- Add the diminutive forms
	add_noun_forms("diminutive", args.dim, "diminutive")

	local extra_notes = {}
	if args.unknown_decl then
		track("unknown-decl")
		table.insert(extra_notes, "unknown declension")
	end
	if args.unknown_stress then
		track("unknown-stress")
		table.insert(extra_notes, "unknown stress")
	end
	if args.unknown_pattern then
		track("unknown-pattern")
		table.insert(extra_notes, "unknown accent pattern")
	end
	if args.unknown_gender then
		track("unknown-gender")
		table.insert(extra_notes, "unknown gender")
	end
	if args.unknown_animacy then
		track("unknown-animacy")
		table.insert(extra_notes, "unknown animacy")
	end
	if #extra_notes > 0 then
		data.extra_text = " " .. make_qualifier_text(table.concat(extra_notes, ", "))
	end
end

local function generate_informal_comp(comp)
	local ru, tr = unpack(comp)
	if rfind(ru, "е́?е$") then
		ru, tr = com.strip_ending(ru, tr, "е") -- Cyrillic е
		return com.concat_russian_tr(ru, tr, "й", nil, "dopair")
	else
		return nil
	end
end

local function generate_po_variant(comp)
	local ru, tr = unpack(comp)
	if rfind(ru, "е$") or rfind(ru, "е́?й$") then
		ru = "[[по" .. ru .. "|(по)]][[" .. ru .. "]]"
		tr = tr and "(po)" .. tr or nil
		return {ru, tr}
	else
		return comp
	end
end

local function generate_periphrastic_comp(positive)
	local ru, tr = unpack(positive)
	return com.concat_russian_tr("[[бо́лее]] ", nil, ru, tr, "dopair")
end

local allowed_endings = {
	"ый",
	"ий",
	"о́й",
	-- last two for adverbs
	"о",
	"о́",
}

local velar_to_translit = {
	["к"] = "k",
	["г"] = "g",
	["х"] = "x"
}

local velar_to_palatal = {
	["к"] = "ч",
	["г"] = "ж",
	["х"] = "ш",
	["k"] = "č",
	["g"] = "ž",
	["x"] = "š"
}

-- Generate the comparative(s) given the positive(s). `positives` is a list of {RUSSIAN, TR} forms. `compspec` is the
-- comparative spec (either + or a spec giving an adjectival accent pattern, such as +c'). If + is given, the default
-- is +a unless the positive is ending-stressed, in which case the default is +b. Return value is a list of
-- {RUSSIAN, TR} forms. Upon input, transliterations must be decomposed.
local function generate_comparative(positives, compspec)
	local comps = {}
	if not rfind(compspec, "^%+") then
		error("Compspec '" .. compspec .. "' must begin with + in this function")
	end
	if compspec ~= "+" and not rfind(compspec, "^%+[abc]'*$") then
		error("Compsec '" .. compspec .. "' has illegal format, should be e.g. + or +c''")
	end
	compspec = rsub(compspec, "^%+", "")
	for _, positive in ipairs(positives) do
		local ru, tr = unpack(positive)
		ru = m_links.remove_links(ru)
		local removed_ending = false
		for _, allowed_ending in ipairs(allowed_endings) do
			if rfind(ru, allowed_ending .. "$") then
				if allowed_ending == "о́й" or allowed_ending == "о́" then
					if compspec == "a" then
						error("Short stress pattern a not allowed with ending-stressed adjectives/adverbs")
					elseif compspec == "" then
						compspec = "b"
					end
				end
				ru, tr = com.strip_ending(ru, tr, allowed_ending)
				removed_ending = true
				break
			end
		end
		if not removed_ending then
			error("Russian '" .. ru .. "' doesn't end with expected ending")
		end
		local comp, comptr
		if rfind(ru, "[кгх]$") then
			local stemru, lastruchar = rmatch(ru, "^(.*)(.)$")
			local stemtr, lasttrchar
			if tr then
				stemtr, lasttrchar = rmatch(tr, "^(.*)(.)$")
				if velar_to_translit[lastruchar] ~= lasttrchar then
					error("Translit '" .. tr .. "' doesn't end with transliterated equivalent of last char '" ..
						lastruchar .. "' of Russian '" .. ru .. "'")
				end
			end
			comp, comptr = com.make_ending_stressed(stemru, stemtr)
			comp = comp .. velar_to_palatal[lastruchar] .. "е" -- Cyrillic е
			if comptr then
				comptr = comptr .. velar_to_palatal[lasttrchar] .. "e" -- Latin e
			end
		elseif compspec == "" or compspec == "a" then
			comp = ru .. "ее" -- Cyrillic ее
			if comptr then
				comptr = tr .. "ee" -- Latin ee
			end
		else -- end-stressed comparative, including pattern a'
			comp, comptr = com.make_unstressed_once(ru, tr)
			comp = comp .. "е́е" -- Cyrillic е́е
			if comptr then
				comptr = comptr .. "e" .. AC .. "e" -- Latin decomposed ée
			end
		end
		insert_if_not(comps, {comp, comptr})
	end
	return comps
end

-- Meant to be called from a bot
function export.generate_comparative(frame)
	local iparams = {
		[1] = {required = true, desc = "comparative"},
		[2] = {},
	}
	local iargs = require("Module:parameters").process(frame.args, iparams)
	local comps = iargs[1]
	local compspec = iargs[2] or ""
	comps = rsplit(comps, ",")
	for i, comp in ipairs(comps) do
		comps[i] = com.split_russian_tr(comp, "dopair")
	end
	comps = generate_comparative(comps, compspec)
	return com.recompose(com.concat_forms(comps))
end

-- Handle comparative inflections. If an explicit form is given such as коро́че or красне́е, we add it in a "hacked"
-- format that notes that e.g. покоро́че or покрасне́е is a possible variant. We also generate an informal form in -ей
-- if possible, e.g. красне́й, with по-hacking applied (but no such variatn is possible for коро́че). We also handle
-- autogenerating comparatives when specified as + or +b, +c'', etc. (All specifications with an accent pattern are
-- equivalent other than +a.) We also allow and handle certain qualifiers such as dated-+b or awkward-нехитре́е.
-- Finally, we allow and handle periphrastic comparatives noted using "peri".
local function handle_comparatives(data, comps, catpos, noinf)
	comps = split_list_into_russian_tr(comps)
	if #comps == 1 and comps[1][1] == "-" then
		table.insert(data.inflections, {label = "no comparative"})
		track("nocomp")
	elseif #comps > 0 then
		local normal_comp_parts = {}
		local rare_comp_parts = {}
		local dated_comp_parts = {}
		local awkward_comp_parts = {}

		local function get_comp_parts(comptype)
			return comptype == "rare" and rare_comp_parts or
				comptype == "dated" and dated_comp_parts or
				comptype == "awkward" and awkward_comp_parts or
				normal_comp_parts
		end

		local function insert_comp_inflection(comptype, comp)
			local comp_parts = get_comp_parts(comptype)
			insert_if_not(comp_parts, comp)
		end

		local function insert_comp_of_type(comp, comptype)
			insert_comp_inflection(comptype, generate_po_variant(comp))
			if not noinf then
				local informal = generate_informal_comp(comp)
				if informal then
					insert_comp_inflection(comptype, generate_po_variant(informal))
				end
			end
		end

		for _, comp in ipairs(comps) do
			local ru, tr = unpack(comp)
			local comptype = "normal"
			if rfind(ru, "^rare%-") then
				comptype = "rare"
				comp = rsub(ru, "^rare%-", "")
			elseif rfind(ru, "^dated%-") then
				comptype = "dated"
				comp = rsub(ru, "^dated%-", "")
			elseif rfind(ru, "^awkward%-") then
				comptype = "awkward"
				comp = rsub(ru, "^awkward%-", "")
			end
			if ru == "peri" then
				for _, positive in ipairs(zip_head_and_translit(data)) do
					local comp = generate_periphrastic_comp(positive)
					insert_comp_inflection(comptype, comp)
				end
				track("pericomp")
			elseif rfind(ru, "^+") then
				local autocomps = generate_comparative(zip_head_and_translit(data), ru)
				for _, autocomp in ipairs(autocomps) do
					insert_comp_of_type(autocomp, comptype)
				end
			else
				insert_comp_of_type(comp, comptype)
			end
		end

		local function add_comp_inflection(label, comp_parts, accel_form)
			if #comp_parts == 0 then
				return
			end
			local parts = {label = label}
			comp_parts = com.combine_translit_of_duplicate_forms(comp_parts)
			for _, form in ipairs(comp_parts) do
				local ru, tr = unpack(form)
				-- WARNING: This has intimate knowledge of how generate_po_variant() works. To avoid this, we could
				-- maintain the un-po-hacked target in each form in comp_parts, but then we'd have to modify
				-- com.combine_translit_of_duplicate_forms() to preserve the extra target info when combining
				-- duplicate forms, or use a map from hacked Russian form to target.
				local un_po_hacked_ru = rsub(ru, "^%[%[.-%]%]", "")
				local un_po_hacked_tr = tr and rsub(tr, "^%(po%)", "") or nil
				local un_po_hacked_form = {un_po_hacked_ru, un_po_hacked_tr}
				insert_if_not(parts, russian_tr_to_inflection_obj(data, form, pos, accel_form, un_po_hacked_form))
			end
			table.insert(data.inflections, parts)
		end

		add_comp_inflection("comparative", normal_comp_parts, "comparative")
		add_comp_inflection("rare comparative", rare_comp_parts)
		add_comp_inflection("dated comparative", dated_comp_parts)
		add_comp_inflection("rare/awkward comparative", awkward_comp_parts)
	end
end

-- Display additional inflection information for an adjective
pos_functions["adjectives"] = {
	 params = {
		["indecl"] = {type = "boolean"}, --indeclinable
		["noinf"] = {type = "boolean"}, --suppress informal comparatives
		[2] = {list = "comp"}, --comparative(s)
		[3] = {list = "sup"}, --superlative(s)
		["adv"] = {list = true}, --corresponding adverb(s)
		["absn"] = {list = true}, --corresponding abstract noun(s)
		["dim"] = {list = true}, --corresponding diminutive(s)
	},
	func = function(args, data)
		local comps = args[2]

		if args.indecl then
			table.insert(data.inflections, {label = "indeclinable"})
			table.insert(data.categories, "Russian indeclinable adjectives")
		end

		handle_comparatives(data, comps, "adjective", args.noinf)

		local function add_adj_forms(label, forms, accel_form)
			add_inflection(data, label, forms, "adjective", accel_form)
		end

		-- Add the superlatives
		if #args[3] > 0 then
			local normalized_sups = {}
			for _, sup in ipairs(args[3]) do
				if sup == "peri" then
					local lemmas = zip_head_and_translit(data)
					for _, lemma in ipairs(lemmas) do
						local ru, tr = unpack(lemma)
						insert_if_not(normalized_sups, com.concat_russian_tr("[[са́мый]] ", nil, ru, tr, "dopair"))
					end
				else
					insert_if_not(normalized_sups, com.split_russian_tr(sup, "dopair"))
				end
			end
			add_adj_forms("superlative", normalized_sups, "superlative")
		end

		-- Add the adverbs
		add_adj_forms("adverb", args.adv)
		-- Add the abstract nouns
		if #args.absn > 0 then
			local normalized_absn = {}
			for _, absn in ipairs(args.absn) do
				if absn == "+" then
					local lemmas = zip_head_and_translit(data)
					for _, lemma in ipairs(lemmas) do
						local ru, tr = unpack(lemma)
						if rfind(ru, "о́?й$") then
							error("Can't form default abstract noun of ending-stressed adjective " .. ru)
						end
						if rfind(ru, "ий$") then
							ru, tr = com.strip_ending(ru, tr, "ий")
						else
							ru, tr = com.strip_ending(ru, tr, "ый")
						end
						insert_if_not(normalized_absn, com.concat_russian_tr(ru, tr, "ость", nil, "dopair"))
					end
				else
					insert_if_not(normalized_absn, com.split_russian_tr(absn, "dopair"))
				end
			end
			add_adj_forms("abstract noun", normalized_absn, "abstract noun")
		end
		-- Add the diminutives
		add_adj_forms("diminutive", args.dim, "diminutive")
	end
}

-- Display additional inflection information for an adverb
pos_functions["adverbs"] = {
	 params = {
		["noinf"] = {type = "boolean"}, --suppress informal comparatives
		[2] = {list = "comp"}, --comparative(s)
		-- ["3"] = {list = "sup"}, --FIXME: why no superlatives?
		["dim"] = {list = true}, --corresponding diminutive(s)
	},
	func = function(args, data)
		local comps = args[2]

		handle_comparatives(data, comps, "adverb", args.noinf)

		local function add_adv_forms(label, forms, accel_form)
			add_inflection(data, label, forms, "adverb", accel_form)
		end

		-- Add the diminutives
		add_adv_forms("diminutive", args.dim, "diminutive")
	end
}

-- Display additional inflection information for a verb and verbal combining form
local function get_verb_pos(pos)
	return {
		params = {
			[2] = {required = true, default = "?"}, --aspect
			["impf"] = {list = true}, -- imperfective(s),
			["pf"] = {list = true}, -- perfective(s),
			["vn"] = {list = true}, -- verbal noun(s),
		},
		func = function(args, data)
			local cform = pos == "verbal combining forms"
			if cform then
				table.insert(data.categories, "Russian verbs")
			end
			-- Aspect
			local aspect = args[2]
			if aspect == "impf" then
				table.insert(data.genders, "impf")
				table.insert(data.categories, "Russian imperfective verbs")
			elseif aspect == "pf" then
				table.insert(data.genders, "pf")
				table.insert(data.categories, "Russian perfective verbs")
			elseif aspect == "both" then
				table.insert(data.genders, "impf")
				table.insert(data.genders, "pf")
				table.insert(data.categories, "Russian imperfective verbs")
				table.insert(data.categories, "Russian perfective verbs")
				table.insert(data.categories, "Russian biaspectual verbs")
			elseif aspect == "?" then
				table.insert(data.genders, "?")
				table.insert(data.categories, "Requests for aspect in Russian entries")
			else
				error("Invalid Russian verb aspect '" .. aspect .. "', should be 'pf', 'impf', 'both' or '?'")
			end

			local function add_verb_forms(label, forms, accel_form)
				add_inflection(data, label, forms, "verb", accel_form)
			end

			-- Add the imperfective forms; intentionally no accelerator, need manual handling
			if #args.impf > 0 and aspect == "impf" then
				error("Can't specify imperfective counterparts for an imperfective verb")
			end
			add_verb_forms("imperfective", args.impf)

			-- Add the perfective forms; intentionally no accelerator, need manual handling
			if #args.pf > 0 and aspect == "pf" then
				error("Can't specify perfective counterparts for a perfective verb")
			end
			add_verb_forms("perfective", args.pf)

			-- Add the verbal nouns
			add_verb_forms("verbal noun", args.vn, "verbal noun")
		end,
	}
end

pos_functions["verbs"] = get_verb_pos("verbs")

pos_functions["verbal combining forms"] = get_verb_pos("verbal combining forms")

return export
