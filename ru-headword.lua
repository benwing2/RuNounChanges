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
		  'head', 'head2', 'head3', ...
	   -- TRANSLITS on entry is a list of translits, matching one-to-one with
		  heads in HEADS. These come either from 'tr', 'tr2', etc. or from
		  auto-transliterating the corresponding head (i.e. the translits will
		  always be non-empty whether or not the user explicitly specified the
		  translit).
	   -- GENDERS on entry is an empty list. On exit it should be the appropriate
		  gender settings, and will be passed directly to full_headword() in
		  [[Module:headword]]. See the documentation for that module for info on
		  the format of this setting.
	   -- INFLECTIONS on entry is an empty list. On exit it should be the
		  appropriate inflections to be displayed in the headword, and will be
		  passed directly to full_headword() in [[Module:headword]]. See the
		  documentation for that module for info on the format of this setting.
]=]--

local m_common = require("Module:ru-common")
local m_links = require("Module:links")
local m_headword = require("Module:headword")
local m_utilities = require("Module:utilities")
local ut = require("Module:utils")
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

local function track(page)
	m_debug.track("ru-headword/" .. page)
	return true
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

-- The main entry point.
function export.show(frame)
	local args = clone_args(frame)
	local PAGENAME = mw.title.getCurrentTitle().text
	local NAMESPACE = mw.title.getCurrentTitle().nsText

	local poscat = ine(frame.args[1]) or error("Part of speech has not been specified. Please pass parameter 1 to the module invocation.")

	local data = {lang = lang, pos_category = poscat, categories = {}, heads = {},
		translits = {}, genders = {}, inflections = {}, noposcat = args.noposcat}
	local tracking_categories = {}

	-- Get the head parameters
	-- First get the 1st parameter. The remainder is named head2=, head3= etc.
	local head = args[1] or PAGENAME
	local i = 2

	while head do
		-- catch errors in arguments where headword doesn't match page title,
		-- but only in the main namespace; for the moment, do only with tracking;
		-- FIXME, duplicates tracking down below a bit, clean that stuff up
		local head_no_links = m_links.remove_links(head)
		local head_noaccent = m_common.remove_accents(head_no_links)
		if NAMESPACE == "" and head_noaccent ~= PAGENAME then
			track("bad-headword")
			--error("Headword " .. head .. " doesn't match pagename " ..
			--	PAGENAME)
		end

		if rfind(head_no_links, " ") then
			track("space-in-headword/" .. poscat)
		elseif rfind(head_no_links, ".%-.") then
			-- The following is for bot scripts
			-- We only look for hyphens between characters so we don't
			-- get tripped up by prefixes and suffixes
			track("hyphen-no-space-in-headword/" .. poscat)
		end
		if m_common.needs_accents(head_no_links) then
			if not args.noacccat then
				table.insert(data.categories, "Requests for accents in Russian entries")
			end
		end
		if rfind(ulower(head_no_links), latin_text_class) then
			track("latin-text-in-headword")
		end
		if rfind(head_no_links, "ьо") then
			track("ьо")
		end

		table.insert(data.heads, head)
		head = args["head" .. i]
		i = i + 1
	end

	-- Get transliteration(s)
	local i = 0
	for _, head in ipairs(data.heads) do
		head = m_links.remove_links(head)
		local head_noaccents = rsub(head, "\204\129", "")
		local tr_gen = mw.ustring.toNFC(lang:transliterate(head, nil))
		local tr_gen_noaccents = mw.ustring.toNFC(lang:transliterate(head_noaccents, nil))

		i = i + 1
		local tr
		if i == 1 then
			tr = args.tr
		else
			tr = args["tr" .. i]
		end

		if tr then
			if not args.notrcat then
				table.insert(data.categories, "Russian terms with irregular pronunciations")
			end
			local tr_fixed = tr
			tr_fixed = rsub(tr_fixed, "ɛ", "e")
			tr_fixed = rsub(tr_fixed, "([eoéó])v([oó])$", "%1g%2")
			tr_fixed = rsub(tr_fixed, "([eoéó])v([oó][- ])", "%1g%2")
			tr_fixed = mw.ustring.toNFC(tr_fixed)

			if tr == tr_gen or tr == tr_gen_noaccents then
				table.insert(tracking_categories, "ru headword with tr/redundant")
			--elseif tr_fixed == tr_gen then
			--	table.insert(tracking_categories, "ru headword with tr/with manual adjustment")
			elseif rfind(tr, ",") then
				table.insert(tracking_categories, "ru headword with tr/comma")
			elseif head_noaccents == PAGENAME then
				if not args.notrcat then
					table.insert(tracking_categories, "ru headword with tr/headword is pagename")
				end
			else
				table.insert(tracking_categories, "ru headword with tr/headword not pagename")
			end
		else
			local orighead, transformed_head = m_ru_translit.apply_tr_fixes(head)
			if orighead ~= transformed_head and not args.notrcat then
				table.insert(data.categories, "Russian terms with irregular pronunciations")
			end
			tr = tr_gen
		end

		table.insert(data.translits, tr)
	end

	if pos_functions[poscat] then
		pos_functions[poscat](args, data)
	end

	return m_headword.full_headword(data) .. (data.extra_text or "") ..
		m_utilities.format_categories(tracking_categories, lang, nil)
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

local function noun_plus_or_multi(frame, multi)
	local poscat = ine(frame.args[1]) or error("Part of speech has not been specified. Please pass parameter 1 to the module invocation.")

	local params = add_common_noun_params({
		["g"] = {list = true}, -- genders
		["notes"] = {list = true}, -- "footnotes" displayed after headword
	})
	local parargs = frame:getParent().args
	local headword_args, args = require("Module:parameters").process(parargs, params, "return unknown")
	args = clone_args(args)
	local old = ine(frame.args.old)
	-- default value of n=, used in ru-proper noun+ where ndef=sg is set
	local ndef = ine(frame.args.ndef)
	args.ndef = args.ndef or ndef

	local m_noun = require("Module:ru-noun")
	if multi then
		args = m_noun.do_generate_forms_multi(args, old)
	else
		args = m_noun.do_generate_forms(args, old)
	end

	local data = {lang = lang, pos_category = poscat, categories = {}, heads = {},
		translits = {}, genders = {}, inflections = {}}

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
			if m_common.is_monosyllabic(ruentry) then
				ruentry = m_common.remove_accents(ruentry)
				if trentry then
					trentry = m_common.remove_accents(trentry)
				end
			end
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
				elseif old then
					ruspan = "[[" .. com.remove_jo(ruentry) .. "|" .. ruentry .. "]]" .. runotes
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

	local function remove_tr(list)
		local newlist = {}
		for _, x in ipairs(list) do
			table.insert(newlist, x[1])
		end
		return newlist
	end

	local argsn = args.n or args.ndef
	local genitives, plurals, genpls
	if argsn == "p" then
		data.heads = prepare_entry(args.nom_pl_linked, "ishead")
		genitives = prepare_entry(args.gen_pl)
		plurals = {{"-"}}
		genpls = {{"-"}}
	else
		data.heads = prepare_entry(args.nom_sg_linked, "ishead")
		genitives = prepare_entry(args.gen_sg)
		plurals = argsn == "s" and {{"-"}} or prepare_entry(args.nom_pl)
		genpls = argsn == "s" and {{"-"}} or prepare_entry(args.gen_pl)
	end

	local irregtr = false
	for _, head in ipairs(data.heads) do
		local ru, tr = head[1], head[2]

		if rfind(ru, " ") then
			ut.insert_if_not(data.categories, "Russian multiword terms")
			track("space-in-headword/" .. poscat)
		elseif rfind(ru, ".%-.") then
			-- The following are for bot scripts
			-- We only look for hyphens between characters so we don't
			-- get tripped up by prefixes and suffixes
			track("hyphen-no-space-in-headword/" .. poscat)
		end

		if not tr then
			tr = lang:transliterate(m_links.remove_links(ru))
		else
			irregtr = true
		end
		table.insert(data.translits, tr)
	end
	if irregtr and not args.notrcat then
		table.insert(data.categories, "Russian terms with irregular pronunciations")
	end

	-- Combine adjacent heads by their transliteration (which should always
	-- be different, as identical heads including translit have previously
	-- been removed)
	data.heads = remove_tr(data.heads)
	local i = 1
	while i < #data.heads do
		if data.heads[i] == data.heads[i+1] then
			data.translits[i] = data.translits[i] .. ", " .. data.translits[i+1]
			table.remove(data.heads, i+1)
			table.remove(data.translits, i+1)
		else
			i = i + 1
		end
	end

	-- Eliminate transliteration from genitives and remove duplicates
	-- (which may occur when there are two translits for a form)
	genitives = remove_tr(genitives)
	local genitives_no_dups = {}
	for _, gen in ipairs(genitives) do
		ut.insert_if_not(genitives_no_dups, gen)
	end
	genitives = genitives_no_dups

	-- Eliminate transliteration from plurals and remove duplicates
	-- (which may occur when there are two translits for a form)
	plurals = remove_tr(plurals)
	local plurals_no_dups = {}
	for _, pl in ipairs(plurals) do
		ut.insert_if_not(plurals_no_dups, pl)
	end
	plurals = plurals_no_dups

	-- Eliminate transliteration from genitive plurals and remove duplicates
	-- (which may occur when there are two translits for a form)
	genpls = remove_tr(genpls)
	local genpls_no_dups = {}
	for _, gpl in ipairs(genpls) do
		ut.insert_if_not(genpls_no_dups, gpl)
	end
	genpls = genpls_no_dups

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

-- External entry point; implementation of {{ru-noun-m}}.
function export.noun_multi(frame)
	return noun_plus_or_multi(frame, true)
end

-- Display additional inflection information for a noun
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

	do_noun(data, args, pos == "proper nouns", genitives, plurals, genpls, pos)
end

pos_functions["proper nouns"] = get_noun_pos("proper nouns")

pos_functions["pronouns"] = get_noun_pos("pronouns")

-- Display additional inflection information for a noun
pos_functions["nouns"] = get_noun_pos("nouns")

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
	for _, numbers in ipairs(recognized_numbers) do
		for _, gender in ipairs(recognized_genders) do
			for _, animacy in ipairs(recognized_animacies) do
				local set = number == "" and singular_genders or plural_genders
				if gender ~= "" or number == "p" then -- disallow blank gender unless plural
					local gender_number = {}
					insert_if_not_blank(gender_number, gender)
					insert_if_not_blank(gender_number, animacy)
					insert_if_not_blank(gender_number, plural)
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

	local function add_forms(inflection, forms)
		for i, form in ipairs(forms) do
			if rfind(form, HYPMARKER) then
				form = rsub(form, HYPMARKER, "")
				table.insert(inflection, {term=form, hypothetical=true})
			else
				table.insert(inflection, form)
			end

			if m_common.needs_accents(form) then
				table.insert(data.categories, "Requests for accents in Russian noun entries")
			end
		end
	end

	-- Add the genitive forms
	if genitives[1] == "-" then
		table.insert(data.inflections, {label = "[[Appendix:Glossary#indeclinable|indeclinable]]"})
		table.insert(data.categories, "Russian indeclinable nouns")
	elseif #genitives > 0 then
		local gen_parts = {label = "genitive"}
		add_forms(gen_parts, genitives)
		table.insert(data.inflections, gen_parts)
	end

	-- Add the plural forms
	-- If the noun is plural only, then ignore the 4th parameter altogether
	if genitives[1] == "-" then
		-- do nothing
	elseif plural_genders[data.genders[1]] then
		table.insert(data.inflections, {label = "[[Appendix:Glossary#plural only|plural only]]"})
	elseif plurals[1] == "-" then
		if pos ~= "proper nouns" then
			table.insert(data.inflections, {label = "[[Appendix:Glossary#uncountable|uncountable]]"})
			table.insert(data.categories, "Russian uncountable nouns")
		end
	elseif #plurals > 0 then
		local pl_parts = {label = "nominative plural"}

		add_forms(pl_parts, plurals)
		--This can't work currently because the forms in plurals are already
		--linked with spans around them, superscripted notes, etc.
		--for _, form in ipairs(plurals) do
		--	if not rfind(form, HYPMARKER) and not mw.title.new(form).exists then
		--		table.insert(categories, "Russian nouns with missing plurals")
		--	end
		--end

		table.insert(data.inflections, pl_parts)
	end

	-- Add the genitive plural forms
	if genitives[1] == "-" or plural_genders[data.genders[1]] or plurals[1] == "-" then
		-- indeclinable, plural only or uncountable; do nothing
	elseif genpls[1] == "-" then
		table.insert(data.inflections, {label = "genitive plural missing"})
	elseif #genpls > 0 then
		local genpl_parts = {label = "genitive plural"}
		add_forms(genpl_parts, genpls)
		table.insert(data.inflections, genpl_parts)
	end

	-- Add the feminine forms
	local feminines = args.f
	if #feminines > 0 then
		local f_parts = {label = "feminine"}
		add_forms(f_parts, feminines)
		table.insert(data.inflections, f_parts)
	end

	-- Add the masculine forms
	local masculines = args.m
	if #masculines > 0 then
		local m_parts = {label = "masculine"}
		add_forms(m_parts, masculines)
		table.insert(data.inflections, m_parts)
	end

	-- Add the related adjective forms
	local adjectives = args.adj
	if #adjectives > 0 then
		local adj_parts = {label = "related adjective"}
		add_forms(adj_parts, adjectives)
		table.insert(data.inflections, adj_parts)
	end

	-- Add the diminutive forms
	local diminutives = args.dim
	if #diminutives > 0 then
		local dim_parts = {label = "diminutive"}
		add_forms(dim_parts, diminutives)
		table.insert(data.inflections, dim_parts)
	end

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
	if rfind(comp, "е́?е$") then
		return rsub(comp, "(е́?)е$", "%1й")
	else
		return nil
	end
end

local function generate_po_variant(comp)
	if rfind(comp, "е$") or rfind(comp, "е́?й$") then
		return "[[по" .. comp .. "|(по)]][[" .. comp .. "]]"
	else
		return comp
	end
end

local allowed_endings = {
	{"ый", "yj"},
	{"ий", "ij"},
	{"о́й", "o" .. AC .. "j"},
	-- last two for adverbs
	{"о", "o"},
	{"о́", "o" .. AC}
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

-- Generate the comparative(s) given the positive(s). Note that this is written
-- to take in and generate comparative(s) for transliteration(s) as well as
-- Russian. This isn't currently used by {{ru-adjective}} but will be used by
-- a bot that generates entries for comparatives.
local function generate_comparative(heads, trs, compspec)
	local comps = {}
	if not rfind(compspec, "^%+") then
		error("Compspec '" .. compspec .. "' must begin with + in this function")
	end
	if compspec ~= "+" and not rfind(compspec, "^%+[abc]'*$") then
		error("Compsec '" .. compspec .. "' has illegal format, should be e.g. + or +c''")
	end
	compspec = rsub(compspec, "^%+", "")
	for i, head in ipairs(heads) do
		local tr = m_common.decompose(trs[i])
		head = m_links.remove_links(head)
		local removed_ending = false
		for j, endingpair in ipairs(allowed_endings) do
			if rfind(head, endingpair[1] .. "$") then
				if not rfind(tr, endingpair[2] .. "$") then
					error("Translit '" .. tr .. "' doesn't end with expected '"
						.. endingpair[2] .. "', corresponding to head '" .. head .. "'")
				end
				if endingpair[1] == "о́й" then
					if compspec == "a" then
						error("Short stress pattern a not allowed with ending-stressed adjectives")
					elseif compspec == "" then
						compspec = "b"
					end
				end
				head = rsub(head, endingpair[1] .. "$", "")
				tr = rsub(tr, endingpair[2] .. "$", "")
				removed_ending = true
				break
			end
		end
		if not removed_ending then
			error("Head '" .. head .. "' doesn't end with expected ending")
		end
		local comp, comptr
		if rfind(head, "[кгх]$") then
			stemhead, lastheadchar = rmatch(head, "^(.*)(.)$")
			stemtr, lasttrchar = rmatch(tr, "^(.*)(.)$")
			if velar_to_translit[lastheadchar] ~= lasttrchar then
				error("Translit '" .. tr .. "' doesn't end with transliterated equivalent of last char '" ..
					lastheadchar .. "' of head '" .. head .. "'")
			end
			comp, comptr = m_common.make_ending_stressed(stemhead, stemtr)
			comp = comp .. velar_to_palatal[lastheadchar] .. "е" -- Cyrillic е
			comptr = comptr .. velar_to_palatal[lasttrchar] .. "e" -- Latin e
		elseif compspec == "" or compspec == "a" then
			comp = head .. "ее" -- Cyrillic ее
			comptr = tr .. "ee" -- Latin ee
		else -- end-stressed comparative, including pattern a'
			comp, comptr = m_common.make_unstressed_once(head, tr)
			comp = comp .. "е́е" -- Cyrillic е́е
			comptr = comptr .. "e" .. AC .. "e" -- Latin decomposed ée
		end
		ut.insert_if_not(comps, {comp, comptr})
	end
	return comps
end

-- Meant to be called from a bot
function export.generate_comparative(frame)
	local comps = ine(frame.args[1]) or error("Must specify comparative(s) in parameter 1")
	local compspec = ine(frame.args[2]) or ""
	comps = rsplit(comps, ",")
	local heads = {}
	local trs = {}
	for _, comp in ipairs(comps) do
		local splitvals = rsplit(comp, "//")
		if #splitvals > 2 then
			error("HEAD or HEAD//TR expected: " .. comp)
		end
		table.insert(heads, splitvals[1])
		table.insert(trs, #splitvals == 1 and lang:transliterate(splitvals[1], nil) or splitvals[2])
	end
	comps = generate_comparative(heads, trs, compspec)
	local combined_comps = {}
	for _, comp in ipairs(comps) do
		table.insert(combined_comps, comp[1] .. "//" .. comp[2])
	end
	return m_common.recompose(table.concat(combined_comps, ","))
end

local function handle_comparatives(data, comps, catpos, noinf, accel)
	if #comps == 1 and comps[1] == "-" then
		table.insert(data.inflections, {label = "no comparative"})
		track("nocomp")
	elseif #comps > 0 then
		local normal_comp_parts = {label = "comparative", accel = accel}
		-- Skip accelerators for these thre
		local rare_comp_parts = {label = "rare comparative"}
		local dated_comp_parts = {label = "dated comparative"}
		local awkward_comp_parts = {label = "rare/awkward comparative"}
		local function insert_comp(comp, comptype)
			local comp_parts = comptype == "rare" and rare_comp_parts or
				comptype == "dated" and dated_comp_parts or
				comptype == "awkward" and awkward_comp_parts or
				normal_comp_parts
			ut.insert_if_not(comp_parts, generate_po_variant(comp))
			if not noinf then
				local informal = generate_informal_comp(comp)
				if informal then
					ut.insert_if_not(comp_parts, generate_po_variant(informal))
				end
			end
			if m_common.needs_accents(comp) then
				table.insert(data.categories, "Requests for accents in Russian " .. catpos .. " entries")
			end
		end

		for _, comp in ipairs(comps) do
			if comp == "peri" then
				for _, head in ipairs(data.heads) do
					ut.insert_if_not(normal_comp_parts, "[[бо́лее]] " .. head)
				end
				track("pericomp")
			else
				local comptype = "normal"
				if rfind(comp, "^rare%-") then
					comptype = "rare"
					comp = rsub(comp, "^rare%-", "")
				elseif rfind(comp, "^dated%-") then
					comptype = "dated"
					comp = rsub(comp, "^dated%-", "")
				elseif rfind(comp, "^awkward%-") then
					comptype = "awkward"
					comp = rsub(comp, "^awkward%-", "")
				end
				if rfind(comp, "^+") then
					local autocomps = generate_comparative(data.heads, data.translits, comp)
					for _, autocomp in ipairs(autocomps) do
						insert_comp(autocomp[1], comptype)
					end
				else
					insert_comp(comp, comptype)
				end
			end
		end

		if #normal_comp_parts > 0 then
			table.insert(data.inflections, normal_comp_parts)
		end
		if #rare_comp_parts > 0 then
			table.insert(data.inflections, rare_comp_parts)
		end
		if #dated_comp_parts > 0 then
			table.insert(data.inflections, dated_comp_parts)
		end
		if #awkward_comp_parts > 0 then
			table.insert(data.inflections, awkward_comp_parts)
		end
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
		local sups = args[3]

		if args.indecl then
			table.insert(data.inflections, {label = "indeclinable"})
			table.insert(data.categories, "Russian indeclinable adjectives")
		end

		-- FIXME, why accelerators for adverbs but not adjectives?
		handle_comparatives(data, comps, "adjective", args.noinf, nil)

		if #sups > 0 then
			local sup_parts = {label = "superlative"}

			for _, sup in ipairs(sups) do
				if sup == "peri" then
					for _, head in ipairs(data.heads) do
						table.insert(sup_parts, "[[са́мый]] " .. head)
					end
				else
					table.insert(sup_parts, sup)

					if m_common.needs_accents(sup) then
						table.insert(data.categories, "Requests for accents in Russian adjective entries")
					end
				end
			end

			table.insert(data.inflections, sup_parts)
		end

		local function add_forms(inflection, forms)
			for i, form in ipairs(forms) do
				table.insert(inflection, form)

				if m_common.needs_accents(form) then
					table.insert(data.categories, "Requests for accents in Russian adjective entries")
				end
			end
		end

		-- Add the adverbs
		local adverbs = args.adv
		if #adverbs > 0 then
			local adv_parts = {label = "adverb"}
			add_forms(adv_parts, adverbs)
			table.insert(data.inflections, adv_parts)
		end

		-- Add the abstract nouns
		local abstract_nouns = args.absn
		if #abstract_nouns > 0 then
			local absn_parts = {label = "abstract noun"}
			add_forms(absn_parts, abstract_nouns)
			table.insert(data.inflections, absn_parts)
		end

		-- Add the diminutives
		local diminutives = args.dim
		if #diminutives > 0 then
			local dim_parts = {label = "diminutive"}
			add_forms(dim_parts, diminutives)
			table.insert(data.inflections, dim_parts)
		end
	end
}

-- Display additional inflection information for an adverb
pos_functions["adverbs"] = {
	 params = {
		["noinf"] = {type = "boolean"}, --suppress informal comparatives
		[2] = {list = "comp"}, --comparative(s)
		-- ["3"] = {list = "sup"}, --why no superlatives?
		["dim"] = {list = true}, --corresponding diminutive(s)
	},
	func = function(args, data)
		local comps = args[2]

		-- FIXME, why is this necessary?
		local encoded_head = data.heads[1]
		if encoded_head == "" then
			encoded_head = nil
		end

		handle_comparatives(data, comps, "adverb", args.noinf, {form = "comparative", lemma = encoded_head})

		local function add_forms(inflection, forms)
			for i, form in ipairs(forms) do
				table.insert(inflection, form)

				if m_common.needs_accents(form) then
					table.insert(data.categories, "Requests for accents in Russian adverb entries")
				end
			end
		end

		-- Add the diminutives
		local diminutives = args.dim
		if #diminutives > 0 then
			local dim_parts = {label = "diminutive"}
			add_forms(dim_parts, diminutives)
			table.insert(data.inflections, dim_parts)
		end
	end
}

-- Display additional inflection information for a verb and verbal combining form
local function get_verb_pos(pos)
	return {
		params = {
			[2] = {required = true, default = "?"}, --aspect
			["impf"] = {list = true}, -- imperfective(s),
			["pf"] = {list = true}, -- perfective(s),
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

			-- Get the imperfective parameters
			local imperfectives = args.impf
			-- Get the perfective parameters
			local perfectives = args.pf

			-- Add the imperfective forms
			if #imperfectives > 0 then
				if aspect == "impf" then
					error("Can't specify imperfective counterparts for an imperfective verb")
				end
				local impf_parts = {label = "imperfective"}

				for i, form in ipairs(imperfectives) do
					table.insert(impf_parts, form)

					if m_common.needs_accents(form) then
						table.insert(data.categories, "Requests for accents in Russian verb entries")
					end
				end

				table.insert(data.inflections, impf_parts)
			end

			-- Add the perfective forms
			if #perfectives > 0 then
				if aspect == "pf" then
					error("Can't specify perfective counterparts for a perfective verb")
				end
				local pf_parts = {label = "perfective"}

				for i, form in ipairs(perfectives) do
					table.insert(pf_parts, form)

					if m_common.needs_accents(form) then
						table.insert(data.categories, "Requests for accents in Russian verb entries")
					end
				end

				table.insert(data.inflections, pf_parts)
			end
		end,
	}
end

pos_functions["verbs"] = get_verb_pos("verbs")

pos_functions["verbal combining forms"] = get_verb_pos("verbal combining forms")

return export
