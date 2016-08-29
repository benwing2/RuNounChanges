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
	The value is a 5-argument function of (ARGS, HEADS, GENDERS, INFLECTIONS,
	CATEGORIES):
	-- ARGS on entry is initialized to the parent template call's arguments,
	   with blank arguments converted to nil. 
	-- HEADS on entry is a list of the headwords, taken directly from arguments
	   'head', 'head2', 'head3', ... (The transliterations found in 'tr',
	   'tr2', etc. aren't currently passed in.)
	-- GENDERS on entry is an empty list. On exit it should be the appropriate
	   gender settings, and will be passed directly to full_headword() in
	   [[Module:headword]]. See the documentation for that module for info on
	   the format of this setting.
	-- INFLECTIONS on entry is an empty list. On exit it should be the
	   appropriate inflections to be displayed in the headword, and will be
	   passed directly to full_headword() in [[Module:headword]]. See the
	   documentation for that module for info on the format of this setting.
	-- CATEGORIES on entry is a list of categories. There will be one category
	   corresponding to the part of speech (e.g. [[Category:Russian adverbs]]),
	   and possibly additional categories such as [[Category:Russian terms needing accents]]
	   and [[Category:Russian terms with irregular pronunciations]]. On exit
	   it may contain additional categories to place the page in.
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

local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local ulower = mw.ustring.lower

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

-- Iterate over a chain of parameters, FIRST then PREF2, PREF3, ...,
-- inserting into LIST (newly created if omitted). Return LIST.
local function process_arg_chain(args, first, pref, list)
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

-- The main entry point.
function export.show(frame)
	local args = clone_args(frame)
	local PAGENAME = mw.title.getCurrentTitle().text
	local NAMESPACE = mw.title.getCurrentTitle().nsText

	local poscat = ine(frame.args[1]) or error("Part of speech has not been specified. Please pass parameter 1 to the module invocation.")

	local genders = {}
	local inflections = {}
	local categories
	local tracking_categories = {}

	-- Get the head parameters
	-- First get the 1st parameter. The remainder is named head2=, head3= etc.
	local heads = {}
	local head = args[1] or PAGENAME
	local i = 2

	if rfind(head, "^%-") then
		-- If head begins with hyphen, remove it when indexing main category,
		-- so that suffixes and combining forms don't all end up indexed under
		-- a hyphen
		categories = {"Russian " .. poscat .. "|" .. rsub(head, "^%-", "")}
	else
		categories = {"Russian " .. poscat}
	end		

	while head do
		-- catch errors in arguments where headword doesn't match page title,
		-- but only in the main namespace; for the moment, do only with tracking;
		-- FIXME, duplicates tracking down below a bit, clean that stuff up
		local head_noaccent = m_common.remove_accents(m_links.remove_links(head))
		if NAMESPACE == "" and head_noaccent ~= PAGENAME then
			track("bad-headword")
			--error("Headword " .. head .. " doesn't match pagename " ..
			--	PAGENAME)
		end

		-- The following are for bot scripts
		if rfind(head, " ") then
			track("space-in-headword/" .. poscat)
		elseif rfind(head, ".%-.") then
			-- We only look for hyphens between characters so we don't
			-- get tripped up by prefixes and suffixes
			track("hyphen-no-space-in-headword/" .. poscat)
		end
		if m_common.needs_accents(head) then
			if not args.notrcat then
				table.insert(categories, "Russian terms needing accents")
			end
		end
		if rfind(ulower(head), latin_text_class) then
			track("latin-text-in-headword")
		end

		table.insert(heads, head)
		head = args["head" .. i]
		i = i + 1
	end

	-- Get transliteration(s)
	local trs = {}
	local i = 0
	for _, head in ipairs(heads) do
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
				table.insert(categories, "Russian terms with irregular pronunciations")
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
				table.insert(categories, "Russian terms with irregular pronunciations")
			end
			tr = tr_gen
		end
		
		table.insert(trs, tr)
	end

	if pos_functions[poscat] then
		pos_functions[poscat](args, heads, genders, inflections, categories)
	end

	return m_headword.full_headword(lang, nil, heads, trs, genders, inflections, categories, nil) ..
		m_utilities.format_categories(tracking_categories, lang, nil)
end

local function noun_plus_or_multi(frame, multi)
	local args = clone_args(frame)
	PAGENAME = mw.title.getCurrentTitle().text

	local poscat = ine(frame.args[1]) or error("Part of speech has not been specified. Please pass parameter 1 to the module invocation.")
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
	-- do explicit genders using g=, g2=, etc.
	local genders = process_arg_chain(args, "g", "g", genders)
	-- if none, do inferred or explicit genders taken from declension;
	-- clone because will get destructively modified by do_noun()
	if #genders == 0 then
		if args["g2"] or args["g3"] or args["g4"] then
			error("Cannot specify g2=, g3= or g4= without g=")
		end
		genders = mw.clone(args.genders)
	end
	local inflections = {}
	local categories = {"Russian " .. poscat}
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

	local feminines = process_arg_chain(args, "f", "f") -- do feminines
	local masculines = process_arg_chain(args, "m", "m") -- do masculines

	local trs = {}
	local irregtr = false
	for _, head in ipairs(heads) do
		local ru, tr = head[1], head[2]

		-- The following are for bot scripts
		if rfind(ru, " ") then
			track("space-in-headword/" .. poscat)
		elseif rfind(ru, ".%-.") then
			-- We only look for hyphens between characters so we don't
			-- get tripped up by prefixes and suffixes
			track("hyphen-no-space-in-headword/" .. poscat)
		end

		if not tr then
			tr = lang:transliterate(m_links.remove_links(ru))
		else
			irregtr = true
		end
		table.insert(trs, tr)
	end
	if irregtr and not args.notrcat then
		table.insert(categories, "Russian terms with irregular pronunciations")
	end

	-- Combine adjacent heads by their transliteration (which should always
	-- be different, as identical heads including translit have previously
	-- been removed)
	heads = remove_tr(heads)
	local i = 1
	while i < #heads do
		if heads[i] == heads[i+1] then
			trs[i] = trs[i] .. ", " .. trs[i+1]
			table.remove(heads, i+1)
			table.remove(trs, i+1)
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

	do_noun(genders, inflections, categories, argsn == "s",
		genitives, plurals, genpls, feminines, masculines, poscat == "proper nouns")

	return m_headword.full_headword(lang, nil, heads, trs, genders, inflections, categories, nil) .. (
		args.notes and saw_note and " " .. '<span class="ib-brac"><span class="qualifier-brac">(</span></span>' ..
		'<span class="ib-content"><span class="qualifier-content">' .. args.notes ..
		'</span></span><span class="ib-brac"><span class="qualifier-brac">)</span></span>' or "")
end

-- External entry point; implementation of {{ru-noun+}}.
function export.noun_plus(frame)
	return noun_plus_or_multi(frame, false)
end

-- External entry point; implementation of {{ru-noun-m}}.
function export.noun_multi(frame)
	return noun_plus_or_multi(frame, true)
end

pos_functions["proper nouns"] = function(args, heads, genders, inflections, categories)
	pos_functions["nouns"](args, heads, genders, inflections, categories, true)
end

pos_functions["pronouns"] = function(args, heads, genders, inflections, categories)
	pos_functions["nouns"](args, heads, genders, inflections, categories)
end

-- Display additional inflection information for a noun
pos_functions["nouns"] = function(args, heads, genders, inflections, categories, proper)
	process_arg_chain(args, 2, "g", genders) -- do genders
	local genitives = process_arg_chain(args, 3, "gen") -- do genitives
	local plurals = process_arg_chain(args, 4, "pl") -- do plurals
	local genpls = process_arg_chain(args, 5, "genpl") -- do genitive plurals
	local feminines = process_arg_chain(args, "f", "f") -- do feminines
	local masculines = process_arg_chain(args, "m", "m") -- do masculines

	do_noun(genders, inflections, categories, proper,
		genitives, plurals, genpls, feminines, masculines, proper)
end

do_noun = function(genders, inflections, categories, no_plural,
	        genitives, plurals, genpls, feminines, masculines, proper)
	if #genders == 0 then
		if mw.title.getCurrentTitle().nsText ~= "Template" then
			error("Gender must be specified")
		else
			table.insert(genders, "?")
		end
	end

	-- Process the genders
	local singular_genders = {
		["m"] = true,
		["m-?"] = true,
		["m-an"] = true,
		["m-in"] = true,

		["f"] = true,
		["f-?"] = true,
		["f-an"] = true,
		["f-in"] = true,

		["n"] = true,
		["n-an"] = true,
		["n-in"] = true}

	local plural_genders = {
		["p"] = true,  -- This is needed because some invariant plurale tantums have no gender to speak of
		["?-p"] = true,
		["an-p"] = true,
		["in-p"] = true,

		["m-p"] = true,
		["m-?-p"] = true,
		["m-an-p"] = true,
		["m-in-p"] = true,

		["f-p"] = true,
		["f-?-p"] = true,
		["f-an-p"] = true,
		["f-in-p"] = true,

		["n-p"] = true,
		["n-?-p"] = true,
		["n-an-p"] = true,
		["n-in-p"] = true }

	local real_genders = {}
	for i, g in ipairs(genders) do
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

		genders[i] = g

		local first_letter = g:sub(1,1)

		-- Categorize by gender
		if first_letter == "m" then
			ut.insert_if_not(real_genders, "m")
			table.insert(categories, "Russian masculine nouns")
		elseif first_letter == "f" then
			ut.insert_if_not(real_genders, "f")
			table.insert(categories, "Russian feminine nouns")
		elseif first_letter == "n" then
			ut.insert_if_not(real_genders, "n")
			table.insert(categories, "Russian neuter nouns")
		end

		-- Categorize by animacy
		if rfind(g, "an") then
			table.insert(categories, "Russian animate nouns")
		elseif rfind(g, "in") then
			table.insert(categories, "Russian inanimate nouns")
		end

		-- Categorize by number
		if plural_genders[g] then
			table.insert(categories, "Russian pluralia tantum")

			if g == "?-p" or g == "an-p" or g == "in-p" then
				table.insert(categories, "Russian pluralia tantum with incomplete gender")
			end
		end
	end

	if #real_genders > 1 then
		table.insert(categories, "Russian nouns with multiple genders")
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
				table.insert(categories, "Russian noun inflections needing accents")
			end
		end
	end

	-- Add the genitive forms
	if genitives[1] == "-" then
		table.insert(inflections, {label = "[[Appendix:Glossary#indeclinable|indeclinable]]"})
		table.insert(categories, "Russian indeclinable nouns")
	elseif #genitives > 0 then
		local gen_parts = {label = "genitive"}
		add_forms(gen_parts, genitives)
		table.insert(inflections, gen_parts)
	end

	-- Add the plural forms
	-- If the noun is a plurale tantum, then ignore the 4th parameter altogether
	if genitives[1] == "-" then
		-- do nothing
	elseif plural_genders[genders[1]] then
		table.insert(inflections, {label = "[[Appendix:Glossary#plurale tantum|plurale tantum]]"})
	elseif plurals[1] == "-" then
		if not proper then
			table.insert(inflections, {label = "[[Appendix:Glossary#uncountable|uncountable]]"})
			table.insert(categories, "Russian uncountable nouns")
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

		table.insert(inflections, pl_parts)
	end

	-- Add the genitive plural forms
	if genitives[1] == "-" or plural_genders[genders[1]] or plurals[1] == "-" then
		-- indeclinable, plurale tantum or uncountable; do nothing
	elseif genpls[1] == "-" then
		table.insert(inflections, {label = "genitive plural missing"})
	elseif #genpls > 0 then
		local genpl_parts = {label = "genitive plural"}
		add_forms(genpl_parts, genpls)
		table.insert(inflections, genpl_parts)
	end

	-- Add the feminine forms
	if #feminines > 0 then
		local f_parts = {label = "feminine"}
		add_forms(f_parts, feminines)
		table.insert(inflections, f_parts)
	end

	-- Add the masculine forms
	if #masculines > 0 then
		local m_parts = {label = "masculine"}
		add_forms(m_parts, masculines)
		table.insert(inflections, m_parts)
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
		return "[[" .. comp .. "|(по)" .. comp .. "]]"
	else
		return comp
	end
end

-- Display additional inflection information for an adjective
pos_functions["adjectives"] = function(args, heads, genders, inflections, categories)
	local comps = process_arg_chain(args, 2, "comp") -- do comparatives
	local sups = process_arg_chain(args, 3, "sup") -- do superlatives

	if #comps > 0 then
		local comp_parts = {label = "comparative"}

		for _, comp in ipairs(comps) do
			if comp == "peri" then
				for _, head in ipairs(heads) do
					ut.insert_if_not(comp_parts, "[[бо́лее]] " .. head)
				end
			else
				ut.insert_if_not(comp_parts, generate_po_variant(comp))
				if not args["noinf"] then
					local informal = generate_informal_comp(comp)
					if informal then
						ut.insert_if_not(comp_parts, generate_po_variant(informal))
					end
				end

				if m_common.needs_accents(comp) then
					table.insert(categories, "Russian adjective inflections needing accents")
				end
			end
		end

		table.insert(inflections, comp_parts)
	end

	if #sups > 0 then
		local sup_parts = {label = "superlative"}

		for _, sup in ipairs(sups) do
			if sup == "peri" then
				for _, head in ipairs(heads) do
					table.insert(sup_parts, "[[са́мый]] " .. head)
				end
			else
				table.insert(sup_parts, sup)

				if m_common.needs_accents(sup) then
					table.insert(categories, "Russian adjective inflections needing accents")
				end
			end
		end

		table.insert(inflections, sup_parts)
	end
end

-- Display additional inflection information for an adverb
pos_functions["adverbs"] = function(args, heads, genders, inflections, categories)
	local comps = process_arg_chain(args, 2, "comp") -- do comparatives

	if #comps > 0 then
		local encoded_head = ""

		if heads[1] ~= "" then
			-- This is decoded again by [[WT:ACCEL]].
			encoded_head = " origin-" .. heads[1]:gsub("%%", "."):gsub(" ", "_")
		end

		local comp_parts = {label = "comparative", accel = "comparative-form-of" .. encoded_head}
		for _, comp in ipairs(comps) do
			ut.insert_if_not(comp_parts, generate_po_variant(comp))
			if not args["noinf"] then
				local informal = generate_informal_comp(comp)
				if informal then
					ut.insert_if_not(comp_parts, generate_po_variant(informal))
				end
			end

			if m_common.needs_accents(comp) then
					table.insert(categories, "Russian adverb comparatives needing accents")
			end
		end

		table.insert(inflections, comp_parts)
	end
end

-- Display additional inflection information for a verb and verbal combining form
local function do_verb(args, heads, genders, inflections, categories, pos)
	local cform = pos == "verbal combining forms"
	if cform then
		table.insert(categories, "Russian verbs")
	end
	-- Aspect
	local aspect = args[2] or mw.title.getCurrentTitle().nsText == "Template" and "?"
	if aspect == "impf" then
		table.insert(genders, "impf")
		table.insert(categories, "Russian imperfective verbs")
	elseif aspect == "pf" then
		table.insert(genders, "pf")
		table.insert(categories, "Russian perfective verbs")
	elseif aspect == "both" then
		table.insert(genders, "impf")
		table.insert(genders, "pf")
		table.insert(categories, "Russian imperfective verbs")
		table.insert(categories, "Russian perfective verbs")
		table.insert(categories, "Russian biaspectual verbs")
	elseif aspect == "?" then
		table.insert(genders, "?")
		table.insert(categories, "Russian verbs needing aspect")
	elseif not aspect then
		error("Missing Russian verb aspect, should be 'pf', 'impf', 'both' or '?'")
	else
		error("Invalid Russian verb aspect '" .. aspect .. "', should be 'pf', 'impf', 'both' or '?'")
	end

	if pos == "verbal combining forms" then
		table.insert(categories, "Russian verbal combining forms|" .. rsub(heads[1], "^%-", ""))
	end
	
	-- Get the imperfective parameters
	-- First get the impf= parameter. The remainder is named impf2=, impf3= etc.
	local imperfectives = {}
	local form = args.impf
	local i = 2

	while form do
		table.insert(imperfectives, form)
		form = args["impf" .. i]
		i = i + 1
	end

	-- Get the perfective parameters
	-- First get the pf= parameter. The remainder is named pf2=, pf3= etc.
	local perfectives = {}
	local form = args.pf
	local i = 2

	while form do
		table.insert(perfectives, form)
		form = args["pf" .. i]
		i = i + 1
	end

	-- Add the imperfective forms
	if #imperfectives > 0 then
		if aspect == "impf" then
			error("Can't specify imperfective counterparts for an imperfective verb")
		end
		local impf_parts = {label = "imperfective"}

		for i, form in ipairs(imperfectives) do
			table.insert(impf_parts, form)

			if m_common.needs_accents(form) then
				table.insert(categories, "Russian verb inflections needing accents")
			end
		end

		table.insert(inflections, impf_parts)
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
				table.insert(categories, "Russian verb inflections needing accents")
			end
		end

		table.insert(inflections, pf_parts)
	end
end

pos_functions["verbs"] = function(args, heads, genders, inflections, categories)
	do_verb(args, heads, genders, inflections, categories, "verbs")
end

pos_functions["verbal combining forms"] = function(args, heads, genders, inflections, categories)
	do_verb(args, heads, genders, inflections, categories, "verbal combining forms")
end

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
