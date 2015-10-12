--[=[
	This module implements the templates {{ru-noun}}, {{ru-adj}}, {{ru-adv}},
	{{ru-noun+}}, etc.
]=]--

local m_common = require("Module:ru-common")
local m_links = require("Module:links")
local m_headword = require("Module:headword")
local m_utilities = require("Module:utilities")
local m_table_tools = require("Module:table tools")

local export = {}
local pos_functions = {}

local lang = require("Module:languages").getByCode("ru")

-- Forward references
local do_noun

local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub

local function ine(x) return x ~= "" and x; end

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
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
	PAGENAME = mw.title.getCurrentTitle().text

	local poscat = ine(frame.args[1]) or error("Part of speech has not been specified. Please pass parameter 1 to the module invocation.")

	local genders = {}
	local inflections = {}
	local categories = {"Russian " .. poscat}
	local tracking_categories = {}

	-- Get the head parameters
	-- First get the 1st parameter. The remainder is named head2=, head3= etc.
	local heads = {}
	local head = args[1]
	local i = 2

	while head do
		if m_common.needs_accents(head) then
			if not args.notrcat then
				table.insert(categories, "Russian terms needing accents")
			end
		end

		table.insert(heads, head)
		head = args["head" .. i]
		i = i + 1
	end

	if #heads == 0 and m_common.needs_accents(PAGENAME) then
		table.insert(categories, "Russian terms needing accents")
	end

	-- Get transliteration
	local head = heads[1] and m_links.remove_links(heads[1]) or PAGENAME
	local head_noaccents = rsub(head, "\204\129", "")
	local tr_gen = mw.ustring.toNFC(lang:transliterate(head, nil))
	local tr_gen_noaccents = mw.ustring.toNFC(lang:transliterate(head_noaccents, nil))

	local tr = args.tr

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
		elseif tr_fixed == tr_gen then
			table.insert(tracking_categories, "ru headword with tr/with manual adjustment")
		elseif rfind(tr, ",") then
			table.insert(tracking_categories, "ru headword with tr/comma")
		elseif head_noaccents == PAGENAME then
			if not args.notrcat then
				table.insert(tracking_categories, "ru headword with tr/headword is pagename")
			end
		else
			table.insert(tracking_categories, "ru headword with tr/headword not pagename")
		end
	end

	if not tr then
		tr = tr_gen
	end

	if pos_functions[poscat] then
		pos_functions[poscat](args, heads, genders, inflections, categories)
	end

	return m_headword.full_headword(lang, nil, heads, tr, genders, inflections, categories, nil) ..
		m_utilities.format_categories(tracking_categories, lang, nil)
end

-- External entry point; implementation of {{ru-noun+}}.
function export.noun_plus(frame)
	local args = clone_args(frame)
	PAGENAME = mw.title.getCurrentTitle().text

	local poscat = ine(frame.args[1]) or error("Part of speech has not been specified. Please pass parameter 1 to the module invocation.")
	local old = ine(frame.args.old)

	local args = require("Module:ru-noun").do_generate_forms(args, old)
	-- do explicit genders using g=, g2=, etc.
	local genders = process_arg_chain(args, "g", "g", genders)
	-- if none, do inferred or explicit genders taken from declension;
	-- clone because will get destructively modified by do_noun()
	if #genders == 0 then
		genders = mw.clone(args.genders)
	end
	local inflections = {}
	local categories = {"Russian " .. poscat}

	local function remove_notes(list)
		if not list then
			return {"-"}
		end
		local newlist = {}
		for _, x in ipairs(list) do
			-- NOTE: <adj> is a sign to transliterate a word adjectivally
			-- (-ovo/-evo instead of -ogo/-ego). But it only occurs in
			-- gen and acc sgs, and the transliteration below is of nom sgs,
			-- so it won't apply; just remove it.
			x = rsub(x, "<adj>", "")
			local entry, notes = m_table_tools.get_notes(x)
			table.insert(newlist, entry)
		end
		return newlist
	end

	local heads, genitives, plurals
	if args.n == "p" then
		heads = remove_notes(args.nom_pl_linked)
		genitives = remove_notes(args.gen_pl)
		plurals = {"-"}
	else
		heads = remove_notes(args.nom_sg_linked)
		genitives = remove_notes(args.gen_sg)
		plurals = args.n == "s" and {"-"} or remove_notes(args.nom_pl)
	end

	local feminines = process_arg_chain(args, "f", "f") -- do feminines
	local masculines = process_arg_chain(args, "m", "m") -- do masculines

	-- FIXME, handle manual transliteration; has to wait until Module:ru-noun
	-- supports manual translit
	local trs = {}
	for _, head in ipairs(heads) do
		table.insert(trs, lang:transliterate(m_links.remove_links(head)))
	end

	do_noun(genders, inflections, categories, args.n == "s",
		genitives, plurals, feminines, masculines)

	return m_headword.full_headword(lang, nil, heads, trs, genders, inflections, categories, nil)
end

pos_functions["proper nouns"] = function(args, heads, genders, inflections, categories)
	pos_functions["nouns"](args, heads, genders, inflections, categories, true)
end

pos_functions["pronouns"] = function(args, heads, genders, inflections, categories)
	pos_functions["nouns"](args, heads, genders, inflections, categories, false)
end

-- Display additional inflection information for a noun
pos_functions["nouns"] = function(args, heads, genders, inflections, categories, no_plural)
	process_arg_chain(args, 2, "g", genders) -- do genders
	local genitives = process_arg_chain(args, 3, "gen") -- do genitives
	local plurals = process_arg_chain(args, 4, "pl") -- do plurals
	local feminines = process_arg_chain(args, "f", "f") -- do feminines
	local masculines = process_arg_chain(args, "m", "m") -- do masculines

	do_noun(genders, inflections, categories, no_plural,
		genitives, plurals, feminines, masculines)
end

do_noun = function(genders, inflections, categories, no_plural,
	        genitives, plurals, feminines, masculines)
	if #genders == 0 then
		if mw.title.getCurrentTitle().nsText ~= "Template" then
			error("Gender must be specified")
		else
			table.insert(genders, "?")
		end
	elseif #genders > 1 then
		table.insert(categories, "Russian nouns with multiple genders")
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

		-- Categorize by gender
		if g:sub(1,1) == "m" then
			table.insert(categories, "Russian masculine nouns")
		elseif g:sub(1,1) == "f" then
			table.insert(categories, "Russian feminine nouns")
		elseif g:sub(1,1) == "n" then
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

	-- Add the genitive forms
	if genitives[1] == "-" then
		table.insert(inflections, {label = "[[Appendix:Glossary#indeclinable|indeclinable]]"})
		table.insert(categories, "Russian indeclinable nouns")
	elseif #genitives > 0 then
		local gen_parts = {label = "genitive"}

		for i, form in ipairs(genitives) do
			table.insert(gen_parts, form)

			if m_common.needs_accents(form) then
				table.insert(categories, "Russian noun inflections needing accents")
			end
		end

		table.insert(inflections, gen_parts)
	end

	-- Add the plural forms
	-- If the noun is a plurale tantum, then ignore the 4th parameter altogether
	if no_plural or genitives[1] == "-" then
		-- do nothing
	elseif plural_genders[genders[1]] then
		table.insert(inflections, {label = "[[Appendix:Glossary#plurale tantum|plurale tantum]]"})
	elseif plurals[1] == "-" then
		table.insert(inflections, {label = "[[Appendix:Glossary#uncountable|uncountable]]"})
		table.insert(categories, "Russian uncountable nouns")
	elseif #plurals > 0 then
		local pl_parts = {label = "nominative plural"}

		for i, form in ipairs(plurals) do
			table.insert(pl_parts, form)

			if m_common.needs_accents(form) then
				table.insert(categories, "Russian noun inflections needing accents")
			end
		end
		if plural and not mw.title.new(plural).exists then
				table.insert(categories, "Russian nouns with missing plurals")
			end
			if plural2 and not mw.title.new(plural2).exists then
				table.insert(categories, "Russian nouns with missing plurals")
			end

		table.insert(inflections, pl_parts)
	end

	-- Add the feminine forms
	if #feminines > 0 then
		local f_parts = {label = "feminine"}

		for i, form in ipairs(feminines) do
			table.insert(f_parts, form)

			if m_common.needs_accents(form) then
				table.insert(categories, "Russian noun inflections needing accents")
			end
		end

		table.insert(inflections, f_parts)
	end

	-- Add the masculine forms
	if #masculines > 0 then
		local m_parts = {label = "masculine"}

		for i, form in ipairs(masculines) do
			table.insert(m_parts, form)

			if m_common.needs_accents(form) then
				table.insert(categories, "Russian noun inflections needing accents")
			end
		end

		table.insert(inflections, m_parts)
	end
end

-- Display additional inflection information for an adjective
pos_functions["adjectives"] = function(args, heads, genders, inflections, categories)
	local comp = args[2]
	local sup = args[3]

	local comp2 = args.comp2
	local comp3 = args.comp3
	local sup2 = args.sup2
	local sup3 = args.sup3

	if comp then
		local comp_parts = {label = "comparative"}

		if comp == "peri" then
			table.insert(comp_parts, "[[бо́лее]] " .. PAGENAME)
		else
			table.insert(comp_parts, comp)

			if m_common.needs_accents(comp) then
				table.insert(categories, "Russian adjective inflections needing accents")
			end
		end

		if comp2 then
			table.insert(comp_parts, comp2)

			if m_common.needs_accents(comp2) then
				table.insert(categories, "Russian adjective inflections needing accents")
			end
		end

		if comp3 then
			table.insert(comp_parts, comp3)

			if m_common.needs_accents(comp3) then
				table.insert(categories, "Russian adjective inflections needing accents")
			end
		end

		table.insert(inflections, comp_parts)
	end

	if sup then
		local sup_parts = {label = "superlative"}

		if sup == "peri" then
			table.insert(sup_parts, "[[са́мый]] " .. PAGENAME)
		else
			table.insert(sup_parts, sup)

			if m_common.needs_accents(sup) then
				table.insert(categories, "Russian adjective inflections needing accents")
			end
		end

		if sup2 then
			table.insert(sup_parts, sup2)

			if m_common.needs_accents(sup2) then
				table.insert(categories, "Russian adjective inflections needing accents")
			end
		end

		if sup3 then
			table.insert(sup_parts, sup3)

			if m_common.needs_accents(sup3) then
				table.insert(categories, "Russian adjective inflections needing accents")
			end
		end

		table.insert(inflections, sup_parts)
	end
end

-- Display additional inflection information for an adverb
pos_functions["adverbs"] = function(args, heads, genders, inflections, categories)
	local comp = args[2]

	local comp2 = args.comp2
	local comp3 = args.comp3

	if comp then
		local encoded_head = ""

		if heads[1] ~= "" then
			-- This is decoded again by [[WT:ACCEL]].
			encoded_head = " origin-" .. heads[1]:gsub("%%", "."):gsub(" ", "_")
		end

		local comp_parts = {label = "comparative", accel = "comparative-form-of" .. encoded_head}
		table.insert(comp_parts, comp)

		if m_common.needs_accents(comp) then
				table.insert(categories, "Russian adverb comparatives needing accents")
		end

		if comp2 then
			table.insert(comp_parts, comp2)
 
			if m_common.needs_accents(comp2) then
				table.insert(categories, "Russian adverb comparatives needing accents")
			end
		end

		if comp3 then
			table.insert(comp_parts, comp3)
 
			if m_common.needs_accents(comp3) then
				table.insert(categories, "Russian adverb comparatives needing accents")
			end
		end
 
		table.insert(inflections, comp_parts)
	end
end

-- Display additional inflection information for a verb
pos_functions["verbs"] = function(args, heads, genders, inflections, categories)
	-- Aspect
	local aspect = args[2]

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
	else
		table.insert(genders, "?")
		table.insert(categories, "Russian verbs needing aspect")
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

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
