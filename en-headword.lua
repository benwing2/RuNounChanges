local export = {}
local pos_functions = {}

local lang = require("Module:languages").getByCode("en")
local PAGENAME = mw.title.getCurrentTitle().text

local function glossary_link(entry, text)
	text = text or entry
	return "[[Appendix:Glossary#" .. entry .. "|" .. text .. "]]"
end

local function track(page)
	require("Module:debug").track("en-headword/" .. page)
	return true
end

-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	
	local poscat = frame.args[1] or error("Part of speech has not been specified. Please pass parameter 1 to the module invocation.")
	
	local params = {
		["head"] = {list = true},
		["suff"] = {type = "boolean"},
		["sort"] = {},
	}
	
	local pos_data = pos_functions[poscat]
	if pos_data then
		for key, val in pairs(pos_data.params) do
			params[key] = val
		end
	end
	
	local args, unknown_args = require("Module:parameters").process(frame:getParent().args, params, pos_data.return_unknown)
	
	if unknown_args and next(unknown_args) then
		track("unknown args")
		track("unknown args/POS/" .. tostring(poscat))
		for parameter, value in pairs(unknown_args) do
			track("unknown args/param/" .. tostring(parameter))
			mw.log("unknown parameter in [[Module:headword]]: |" .. tostring(parameter) .. "=" .. tostring(value))
		end
	end
	
	local data = {lang = lang, pos_category = poscat, categories = {}, heads = args["head"], inflections = {}}
	
	if args["suff"] then
		data.pos_category = "suffixes"
		
		if poscat == "adjectives" or poscat == "adverbs" or poscat == "nouns" or poscat == "verbs" then
			table.insert(data.categories, ("%s %s-forming suffixes")
				:format(lang:getCanonicalName(), poscat:gsub("s$", "")))
		else
			error("No category exists for suffixes forming " .. poscat .. ".")
		end
	end
	
	if pos_data then
		pos_data.func(args, data)
	end
	
	local extra_categories = {}
	if PAGENAME:find("[Qq][^Uu]") or PAGENAME:find("[Qq]$") then
		table.insert(data.categories, lang:getCanonicalName() .. " words containing Q not followed by U")
	end
	if PAGENAME:find("([A-Za-z])%1%1") then
		table.insert(data.categories, lang:getCanonicalName() .. " words containing three consecutive instances of the same letter")
	end
	if PAGENAME:find("([A-Za-z])%1%1%1") then
		table.insert(data.categories, lang:getCanonicalName() .. " words containing four consecutive instances of the same letter")
	end
	if PAGENAME:find("[^c]ie") or PAGENAME:find("cei") then
		table.insert(data.categories, lang:getCanonicalName() .. " words following the I before E except after C rule")
	end
	if PAGENAME:find("[^c]ei") or PAGENAME:find("cie") then
		table.insert(data.categories, lang:getCanonicalName() .. " words not following the I before E except after C rule")
	end
	-- mw.ustring.toNFD performs decomposition, so letters that decompose
	-- to an ASCII vowel and a diacritic, such as é, are counted as vowels and
	-- do not need to be included in the pattern.
	if not mw.ustring.find(mw.ustring.lower(mw.ustring.toNFD(PAGENAME)), "[aeiouyæœø]") then
		table.insert(data.categories, lang:getCanonicalName() .. " words without vowels")
	end
	if PAGENAME:find("yre$") then
		table.insert(data.categories, lang:getCanonicalName() .. ' words ending in "-yre"')
	end
	if not PAGENAME:find(" ") and PAGENAME:len() > 25 then
		table.insert(extra_categories, "Long " .. lang:getCanonicalName() .. ' words')
	end
	if PAGENAME:find("^[^aeiou ]*a[^aeiou ]*e[^aeiou ]*i[^aeiou ]*o[^aeiou ]*u[^aeiou ]*$") then
		table.insert(data.categories, lang:getCanonicalName() .. ' words that use all vowels in alphabetical order')
	end
	data.sort_key = args.sort
	return require("Module:headword").full_headword(data)
		.. (#extra_categories > 0
			and require("Module:utilities").format_categories(extra_categories, lang, args.sort)
			or "")
end

-- This function does the common work between adjectives and adverbs
function make_comparatives(params, data)
	local comp_parts = {label = glossary_link("comparative"), accel = {form = "comparative"}}
	local sup_parts = {label = glossary_link("superlative"), accel = {form = "superlative"}}
	
	if #params == 0 then
		table.insert(params, {"more"})
	end
	
	-- To form the stem, replace -(e)y with -i and remove a final -e.
	local stem = PAGENAME:gsub("([^aeiou])e?y$", "%1i"):gsub("e$", "")
	
	-- Go over each parameter given and create a comparative and superlative form
	for i, val in ipairs(params) do
		local comp = val[1]
		local sup = val[2]
		
		if comp == "more" and PAGENAME ~= "many" and PAGENAME ~= "much" then
			table.insert(comp_parts, "[[more]] " .. PAGENAME)
			table.insert(sup_parts, "[[most]] " .. PAGENAME)
		elseif comp == "further" and PAGENAME ~= "far" then
			table.insert(comp_parts, "[[further]] " .. PAGENAME)
			table.insert(sup_parts, "[[furthest]] " .. PAGENAME)
		elseif comp == "er" then
			table.insert(comp_parts, stem .. "er")
			table.insert(sup_parts, stem .. "est")
		elseif comp == "-" or sup == "-" then
			-- Allowing '-' makes it more flexible to not have some forms
			if comp ~= "-" then
				table.insert(comp_parts, comp)
			end
			if sup ~= "-" then
				table.insert(sup_parts, sup)
			end
		else
			-- If the full comparative was given, but no superlative, then
			-- create it by replacing the ending -er with -est.
			if not sup then
				if comp:find("er$") then
					sup = comp:gsub("er$", "est")
				else
					error("The superlative of \"" .. comp .. "\" cannot be generated automatically. Please provide it with the \"sup" .. (i == 1 and "" or i) .. "=\" parameter.")
				end
			end
			
			table.insert(comp_parts, comp)
			table.insert(sup_parts, sup)
		end
	end
	
	table.insert(data.inflections, comp_parts)
	table.insert(data.inflections, sup_parts)
end

pos_functions["adjectives"] = {
	params = {
		[1] = {list = true, allow_holes = true},
		["sup"] = {list = true, allow_holes = true},
		},
	func = function(args, data)
		local shift = 0
		local is_not_comparable = false
		local is_comparative_only = false
		
		-- If the first parameter is ?, then don't show anything, just return.
		if args[1][1] == "?" then
			return
		-- If the first parameter is -, then move all parameters up one position.
		elseif args[1][1] == "-" then
			shift = 1
			is_not_comparable = true
		-- If the only argument is +, then remember this and clear parameters
		elseif args[1][1] == "+" and args[1].maxindex == 1 then
			shift = 1
			is_comparative_only = true
		end
		
		-- Gather all the comparative and superlative parameters.
		local params = {}
		
		for i = 1, args[1].maxindex - shift do
			local comp = args[1][i + shift]
			local sup = args["sup"][i]
			
			if comp or sup then
				table.insert(params, {comp, sup})
			end
		end
		
		if shift == 1 then
			-- If the first parameter is "-" but there are no parameters,
			-- then show "not comparable" only and return.
			-- If there are parameters, then show "not generally comparable"
			-- before the forms.
			if #params == 0 then
				if is_not_comparable then
					table.insert(data.inflections, {label = "not " .. glossary_link("comparable")})
					table.insert(data.categories, lang:getCanonicalName() .. " uncomparable adjectives")
					return
				end
				if is_comparative_only then
					table.insert(data.inflections, {label = glossary_link("comparative") .. " form only"})
					table.insert(data.categories, lang:getCanonicalName() .. " comparative-only adjectives")
					return
				end
			else
				table.insert(data.inflections, {label = "not generally " .. glossary_link("comparable")})
			end
		end
		
		-- Process the parameters
		make_comparatives(params, data)
	end
}

pos_functions["adverbs"] = {
	params = {
		[1] = {list = true, allow_holes = true},
		["sup"] = {list = true, allow_holes = true},
		},
	func = function(args, data)
		local shift = 0
		
		-- If the first parameter is ?, then don't show anything, just return.
		if args[1][1] == "?" then
			return
		-- If the first parameter is -, then move all parameters up one position.
		elseif args[1][1] == "-" then
			shift = 1
		end
		
		-- Gather all the comparative and superlative parameters.
		local params = {}
		
		for i = 1, args[1].maxindex - shift do
			local comp = args[1][i + shift]
			local sup = args["sup"][i]
			
			if comp or sup then
				table.insert(params, {comp, sup})
			end
		end
		
		if shift == 1 then
			-- If the first parameter is "-" but there are no parameters,
			-- then show "not comparable" only and return. If there are parameters,
			-- then show "not generally comparable" before the forms.
			if #params == 0 then
				table.insert(data.inflections, {label = "not " .. glossary_link("comparable")})
				table.insert(data.categories, lang:getCanonicalName() .. " uncomparable adverbs")
				return
			else
				table.insert(data.inflections, {label = "not generally " .. glossary_link("comparable")})
			end
		end
		
		-- Process the parameters
		make_comparatives(params, data)
	end
}

pos_functions["conjunctions"] = {
	params = {
		[1] = { alias_of = "head" },
	},
	return_unknown = true,
	func = function (args, data)
		
	end,
}

pos_functions["interjections"] = {
	params = {
		[1] = { alias_of = "head" },
	},
	return_unknown = true,
	func = function (args, data)
		
	end,
}

local function default_plural(noun)
	local new_pl
	if noun:find("[sxz]$") or noun:find("[cs]h$") then
		new_pl = noun .. "es"
	elseif noun:find("[^aeiou]y$") then
		new_pl = noun:gsub("y$", "i") .. "es"
	else
		new_pl = noun .. "s"
	end
	return new_pl
end

local function canonicalize_plural(pl, stem)
	if pl == "s" then
		return stem .. "s"
	elseif pl == "es" then
		return stem .. "es"
	elseif pl == "+" then
		return default_plural(PAGENAME)
	else
		return nil
	end
end

pos_functions["nouns"] = {
	params = {
		[1] = {list = true, allow_holes = true},
		["pl=qual"] = { list = true, allow_holes = true },
		},
	func = function(args, data)
		-- Gather all the plural parameters from the numbered parameters.
		local plurals = {}
		
		for i = 1, args[1].maxindex do
			local pl = args[1][i]
			
			if pl then
				local qual = args["plqual"][i]
				
				if qual then
					table.insert(plurals, {term = pl, qualifiers = {qual}})
				else
					table.insert(plurals, pl)
				end
			end
		end
		
		-- Decide what to do next...
		local mode = nil
		
		if plurals[1] == "?" or plurals[1] == "!" or plurals[1] == "-" or plurals[1] == "~" then
			mode = plurals[1]
			table.remove(plurals, 1)  -- Remove the mode parameter
		end
		
		-- Plural is unknown
		if mode == "?" then
			table.insert(data.categories, lang:getCanonicalName() .. " nouns with unknown or uncertain plurals")
			return
		-- Plural is not attested
		elseif mode == "!" then
			table.insert(data.inflections, {label = "plural not attested"})
			table.insert(data.categories, lang:getCanonicalName() .. " nouns with unattested plurals")
			return
		-- Uncountable noun; may occasionally have a plural
		elseif mode == "-" then
			table.insert(data.categories, lang:getCanonicalName() .. " uncountable nouns")
			
			-- If plural forms were given explicitly, then show "usually"
			if #plurals > 0 then
				table.insert(data.inflections, {label = "usually " .. glossary_link("uncountable")})
				table.insert(data.categories, lang:getCanonicalName() .. " countable nouns")
			else
				table.insert(data.inflections, {label = glossary_link("uncountable")})
			end
		-- Mixed countable/uncountable noun, always has a plural
		elseif mode == "~" then
			table.insert(data.inflections, {label = glossary_link("countable") .. " and " .. glossary_link("uncountable")})
			table.insert(data.categories, lang:getCanonicalName() .. " uncountable nouns")
			table.insert(data.categories, lang:getCanonicalName() .. " countable nouns")
			
			-- If no plural was given, add a default one now
			if #plurals == 0 then
				plurals = {default_plural(PAGENAME)}
			end
		-- The default, always has a plural
		else
			table.insert(data.categories, lang:getCanonicalName() .. " countable nouns")
			
			-- If no plural was given, add a default one now
			if #plurals == 0 then
				plurals = {default_plural(PAGENAME)}
			end
		end
		
		-- If there are no plurals to show, return now
		if #plurals == 0 then
			return
		end
		
		-- There are plural forms to show, so show them
		local pl_parts = {label = "plural", accel = {form = "p"}}
		
		local function check_ies(pl, stem)
			local newplural, nummatches = stem:gsub("([^aeiou])y$","%1ies")
			return nummatches > 0 and pl == newplural
		end
		local stem = PAGENAME
		local irregular = false
		for i, pl in ipairs(plurals) do
			local canon_pl = canonicalize_plural(pl, stem)
			if canon_pl then
				table.insert(pl_parts, canon_pl)
			elseif type(pl) == "table" then
				canon_pl = canonicalize_plural(pl.term, stem)
				if canon_pl then
					table.insert(pl_parts, {term=canon_pl, qualifiers=pl.qualifiers})
				end
			end
			if not canon_pl then
				table.insert(pl_parts, pl)
				if type(pl) == "table" then
					pl = pl.term
				end
				if not stem:find(" ") and not (pl == stem .. "s" or pl == stem .. "es" or check_ies(pl, stem)) then
					irregular = true
					if pl == stem then
						table.insert(data.categories, lang:getCanonicalName() .. " indeclinable nouns")
					end
				end
			end
		end
		if irregular then
			table.insert(data.categories, lang:getCanonicalName() .. " nouns with irregular plurals")
		end
		
		table.insert(data.inflections, pl_parts)
	end
}

pos_functions["proper nouns"] = {
	params = {
		[1] = {list = true},
		},
	func = function(args, data)
		local plurals = args[1]
		
		-- Decide what to do next...
		local mode = nil
		
		if plurals[1] == "?" or plurals[1] == "!" or plurals[1] == "-" or plurals[1] == "~" then
			mode = plurals[1]
			table.remove(plurals, 1)  -- Remove the mode parameter
		end
		
		-- Plural is unknown
		if mode == "?" then
			table.insert(data.categories, lang:getCanonicalName() .. " proper nouns with unknown or uncertain plurals")
			return
		-- Plural is not attested
		elseif mode == "!" then
			table.insert(data.inflections, {label = "plural not attested"})
			table.insert(data.categories, lang:getCanonicalName() .. " proper nouns with unattested plurals")
			return
		-- Uncountable noun; may occasionally have a plural
		elseif mode == "-" then
			-- If plural forms were given explicitly, then show "usually"
			if #plurals > 0 then
				table.insert(data.inflections, {label = "usually " .. glossary_link("uncountable")})
				table.insert(data.categories, lang:getCanonicalName() .. " countable proper nouns")
			else
				table.insert(data.inflections, {label = glossary_link("uncountable")})
			end
		-- Mixed countable/uncountable noun, always has a plural
		elseif mode == "~" then
			table.insert(data.inflections, {label = glossary_link("countable") .. " and " .. glossary_link("uncountable")})
			table.insert(data.categories, lang:getCanonicalName() .. " countable proper nouns")
			
			-- If no plural was given, add a default one now
			if #plurals == 0 then
				plurals = {"s"}
			end
		elseif #plurals > 0 then
			table.insert(data.categories, lang:getCanonicalName() .. " countable proper nouns")
		end
		
		-- If there are no plurals to show, return now
		if #plurals == 0 then
			return
		end
		
		-- There are plural forms to show, so show them
		local pl_parts = {label = "plural", accel = {form = "p"}}
		
		local stem = PAGENAME
		
		for i, pl in ipairs(plurals) do
			if pl == "s" then
				table.insert(pl_parts, stem .. "s")
			elseif pl == "es" then
				table.insert(pl_parts, stem .. "es")
			else
				table.insert(pl_parts, pl)
			end
	
		end
		
		table.insert(data.inflections, pl_parts)
	end
}

local function base_default_verb_forms(verb)
	local s_form = default_plural(verb)
	local ing_form, ed_form
	local vowel = "aeiouáéíóúàèìòùâêîôûäëïöüæœø"
	local ulvowel = vowel .. "AEIOUÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÄËÏÖÜÆŒØ"

	-- (1) Check for C*VC verbs.
	--
	-- flip -> flipping/flipped, strum -> strumming/strummed, nag -> nagging/nagged, etc.
	-- Do not include words with final -y, e.g. 'stay' (staying/stayed), 'toy' (toying/toyed),
	-- or with final -w, e.g. 'flow' (flowing/flowed), or with final -h, e.g. 'ah' (ahing/ahed),
	-- or with final -x, e.g. 'box' (boxing/boxed), or ending in an uppercase consonant,
	-- e.g. 'XOR' (XORing/XORed), 'OK' (OKing/OKed). Check specially for initial y- as a consonant,
	-- e.g. 'yip' (yipping/yipped), otherwise treat y as a vowel, so we don't trigger on 'hyphen'
	-- but do trigger on 'gyp'.
	local last_cons = mw.ustring.match(verb, "^[Yy][" .. vowel .. "y]([^A-Z" .. vowel .. "ywxh])$")
	if not last_cons then
		last_cons = mw.ustring.match(verb, "^[^" .. ulvowel .. "yY]*[" .. ulvowel .. "yY]([^A-Z" .. vowel .. "ywxh])$")
	end
	if last_cons then
		ing_form = verb .. last_cons .. "ing"
		ed_form = verb .. last_cons .. "ed"
	else
		-- (2) Generate -ing form.
		-- (2a) lie -> lying, untie -> untying, etc.
		local stem = verb:match("^(.*)ie$")
		if stem then
			ing_form = stem .. "ying"
		else
			-- (2b) argue -> arguing, sprue -> spruing, dialogue -> dialoguing, etc.
			stem = verb:match("^(.*)ue$")
			if stem then
				ing_form = stem .. "uing"
			else
				stem = mw.ustring.match(verb, "^(.*[" .. ulvowel .. "yY][^" .. vowel .. "y]+)e$")
				if stem then
					-- (2c) baptize -> baptizing, rake -> raking, type -> typing, parse -> parsing, etc.
					-- (ending in vowel + consonant(s) + -e); but not referee -> refereeing,
					-- backhoe -> backhoeing, redye -> redyeing (ending in some other vowel + -e or in -ye);
					-- and not be -> being (no vowel before the consonant preceding the -e)
					ing_form = stem .. "ing"
				else
					-- (2d) regular verbs
					ing_form = verb .. "ing"
				end
			end
		end

		-- (3) Generate -ed form.
		if verb:find("e$") then
			-- (3a) baptize -> baptized, rake -> raked, parse -> parsed, free -> freed, hoe -> hoed
			ed_form = verb .. "d"
		else
			stem = mw.ustring.match(verb, "^(.*[^" .. ulvowel .. "yY])y$")
			if stem then
				-- (3b) marry -> married, levy -> levied, try -> tried, etc.; but not toy -> toyed
				ed_form = stem .. "ied"
			else
				-- (3c) regular verbs
				ed_form = verb .. "ed"
			end
		end
	end

	return s_form, ing_form, ed_form
end


local function default_verb_forms(verb)
	local full_s_form, full_ing_form, full_ed_form = base_default_verb_forms(verb)
	if verb:find(" ") then
		local first, rest = verb:match("^(.-)( .*)$")
		local first_s_form, first_ing_form, first_ed_form = base_default_verb_forms(first)
		return full_s_form, full_ing_form, full_ed_form, first_s_form .. rest, first_ing_form .. rest, first_ed_form .. rest
	else
		return full_s_form, full_ing_form, full_ed_form, nil, nil, nil
	end
end


pos_functions["verbs"] = {
	params = {
		[1] = {list = "pres_3sg", allow_holes = true},
		["pres_3sg_qual"] = {list = "pres_3sg=_qual", allow_holes = true},
		[2] = {list = "pres_ptc", allow_holes = true},
		["pres_ptc_qual"] = {list = "pres_ptc=_qual", allow_holes = true},
		[3] = {list = "past", allow_holes = true},
		["past_qual"] = {list = "past=_qual", allow_holes = true},
		[4] = {list = "past_ptc", allow_holes = true},
		["past_ptc_qual"] = {list = "past_ptc=_qual", allow_holes = true},
		["pagename"] = {}, -- for testing
		},
	func = function(args, data)
		-- Get parameters
		local par1 = args[1][1]
		local par2 = args[2][1]
		local par3 = args[3][1]
		local par4 = args[4][1]
		
		local pres_3sgs, pres_ptcs, pasts, past_ptcs

		local pagename = args.pagename or PAGENAME

		------------------------------------------- UTILITY FUNCTIONS #1 ------------------------------------------

		-- These functions are used directly in the <> format as well as in the utility functions #2 below.

		local function compute_double_last_cons_stem(verb)
			local last_cons = verb:match("([bcdfghjklmnpqrstvwxyzBCDFGHJKLMNPQRSTVWXYZ])$")
			if not last_cons then
				error("Verb stem '" .. verb .. "' must end in a consonant to use ++")
			end
			return verb .. last_cons
		end

		local function compute_plusplus_s_form(verb, default_s_form)
			if verb:find("[sz]$") then
				-- regas -> regasses, derez -> derezzes
				return compute_double_last_cons_stem(verb) .. "es"
			else
				return default_s_form
			end
		end

		------------------------------------------- UTILITY FUNCTIONS #2 ------------------------------------------

		-- These functions are used in both in the separate-parameter format and in the override params such as past_ptc2=.

		local new_default_s, new_default_ing, new_default_ed, split_default_s, split_default_ing, split_default_ed =
			default_verb_forms(pagename)

		local function compute_double_last_cons_stem_of_split_verb(verb, ending)
			local first, rest = verb:match("^(.-)( .*)$")
			if not first then
				error("Verb '" .. verb .. "' must have a space in it to use ++*")
			end
			local last_cons = first:match("([bcdfghjklmnpqrstvwxyzBCDFGHJKLMNPQRSTVWXYZ])$")
			if not last_cons then
				error("First word '" .. first .. "' must end in a consonant to use ++*")
			end
			return first .. last_cons .. ending .. rest
		end

		local function check_non_nil_star_form(form)
			if form == nil then
				error("Verb '" .. pagename .. "' must have a space in it to use * or ++*")
			end
			return form
		end

		local function sub_tilde(form)
			if not form then
				return nil
			end
			local retval = form:gsub("~", pagename) -- discard second return value
			return retval
		end

		local function canonicalize_s_form(form)
			if form == "+" then
				return new_default_s
			elseif form == "*" then
				return check_non_nil_star_form(split_default_s)
			elseif form == "++" then
				return compute_plusplus_s_form(pagename, new_default_s)
			elseif form == "++*" then
				if pagename:find("^[^ ]*[sz] ") then
					return compute_double_last_cons_stem_of_split_verb(pagename, "es")
				else
					return check_non_nil_star_form(split_default_s)
				end
			else
				return sub_tilde(form)
			end
		end
		
		local function canonicalize_ing_form(form)
			if form == "+" then
				return new_default_ing
			elseif form == "*" then
				return check_non_nil_star_form(split_default_ing)
			elseif form == "++" then
				return compute_double_last_cons_stem(pagename) .. "ing"
			elseif form == "++*" then
				return compute_double_last_cons_stem_of_split_verb(pagename, "ing")
			else
				return sub_tilde(form)
			end
		end
			
		local function canonicalize_ed_form(form)
			if form == "+" then
				return new_default_ed
			elseif form == "*" then
				return check_non_nil_star_form(split_default_ed)
			elseif form == "++" then
				return compute_double_last_cons_stem(pagename) .. "ed"
			elseif form == "++*" then
				return compute_double_last_cons_stem_of_split_verb(pagename, "ed")
			else
				return sub_tilde(form)
			end
		end

		--------------------------------- MAIN PARSING/CONJUGATING CODE --------------------------------

		local past_ptcs_given

		if par1 and par1:find("<") then

			-------------------------- ANGLE-BRACKET FORMAT --------------------------

			if par2 or par3 or par4 then
				error("Can't specify 2=, 3= or 4= when 1= contains angle brackets: " .. par1)
			end
			-- In the angle bracket format, we always copy the full past tense specs to the past participle
			-- specs if none of the latter are given, so act as if the past participle is always given.
			-- There is a separate check to see if the past tense and past participle are identical, in any case.
			past_ptcs_given = true
			local iut = require("Module:inflection utilities")

			-- (1) Parse the indicator specs inside of angle brackets.

			local function parse_indicator_spec(angle_bracket_spec)
				local inside = angle_bracket_spec:match("^<(.*)>$")
				assert(inside)
				local segments = iut.parse_balanced_segment_run(inside, "[", "]")
				local comma_separated_groups = iut.split_alternating_runs(segments, ",")
				if #comma_separated_groups > 4 then
					error("Too many comma-separated parts in indicator spec: " .. angle_bracket_spec)
				end

				local function fetch_qualifiers(separated_group)
					local qualifiers
					for j = 2, #separated_group - 1, 2 do
						if separated_group[j + 1] ~= "" then
							error("Extraneous text after bracketed qualifiers: '" .. table.concat(separated_group) .. "'")
						end
						if not qualifiers then
							qualifiers = {}
						end
						table.insert(qualifiers, separated_group[j])
					end
					return qualifiers
				end

				local function fetch_specs(comma_separated_group)
					if not comma_separated_group then
						return {{}}
					end
					local specs = {}
					
					local colon_separated_groups = iut.split_alternating_runs(comma_separated_group, ":")
					for _, colon_separated_group in ipairs(colon_separated_groups) do
						local form = colon_separated_group[1]
						if form == "*" or form == "++*" then
							error("* and ++* not allowed inside of indicator specs: " .. angle_bracket_spec)
						end
						if form == "" then
							form = nil
						end
						table.insert(specs, {form = form, qualifiers = fetch_qualifiers(colon_separated_group)})
					end
					return specs
				end

				local s_specs = fetch_specs(comma_separated_groups[1])
				local ing_specs = fetch_specs(comma_separated_groups[2])
				local ed_specs = fetch_specs(comma_separated_groups[3])
				local en_specs = fetch_specs(comma_separated_groups[4])
				for _, spec in ipairs(s_specs) do
					if spec.form == "++" and #ing_specs == 1 and not ing_specs[1].form and not ing_specs[1].qualifiers
						and #ed_specs == 1 and ed_specs[1].form and not ed_specs[1].qualifiers then
						ing_specs[1].form = "++"
						ed_specs[1].form = "++"
						break
					end
				end

				return {
					forms = {},
					s_specs = s_specs,
					ing_specs = ing_specs,
					ed_specs = ed_specs,
					en_specs = en_specs,
				}
			end

			local parse_props = {
				parse_indicator_spec = parse_indicator_spec,
			}
			local alternant_multiword_spec = iut.parse_inflected_text(par1, parse_props)

			-- (2) Remove any links from the lemma, but remember the original form
			--     so we can use it below in the 'lemma_linked' form.

			iut.map_word_specs(alternant_multiword_spec, function(base)
				if base.lemma == "" then
					base.lemma = pagename
				end
				base.orig_lemma = base.lemma
				base.lemma = require("Module:links").remove_links(base.lemma)
			end)

			-- (3) Conjugate the verbs according to the indicator specs parsed above.

			local all_verb_slots = {
				lemma = "infinitive",
				lemma_linked = "infinitive",
				s_form = "3|s|pres",
				ing_form = "pres|ptcp",
				ed_form = "past",
				en_form = "past|ptcp",
			}
			local function conjugate_verb(base)
				local def_s_form, def_ing_form, def_ed_form = base_default_verb_forms(base.lemma)

				local function process_specs(slot, specs, default_form, canonicalize_plusplus)
					for _, spec in ipairs(specs) do
						local form = spec.form
						if not form or form == "+" then
							form = default_form
						elseif form == "++" then
							form = canonicalize_plusplus()
						end
						iut.insert_form(base.forms, slot, {form = form, footnotes = spec.qualifiers})
					end
				end

				process_specs("s_form", base.s_specs, def_s_form,
					function() return compute_plusplus_s_form(base.lemma, def_s_form) end)
				process_specs("ing_form", base.ing_specs, def_ing_form,
					function() return compute_double_last_cons_stem(base.lemma) .. "ing" end)
				process_specs("ed_form", base.ed_specs, def_ed_form,
					function() return compute_double_last_cons_stem(base.lemma) .. "ed" end)

				-- If the -en spec is completely missing, substitute the -ed spec in its entirely.
				-- Otherwise, if individual -en forms are missing or use +, we will substitute the
				-- default -ed form, as with the -ed spec.
				local en_specs = base.en_specs
				if #en_specs == 1 and not en_specs[1].form and not en_specs[1].qualifiers then
					en_specs = base.ed_specs
				end

				process_specs("en_form", en_specs, def_ed_form,
					function() return compute_double_last_cons_stem(base.lemma) .. "ed" end)

				iut.insert_form(base.forms, "lemma", {form = base.lemma})
				-- Add linked version of lemma for use in head=. We write this in a general fashion in case
				-- there are multiple lemma forms (which isn't possible currently at this level, although it's
				-- possible overall using the ((...,...)) notation).
				iut.insert_forms(base.forms, "lemma_linked", iut.map_forms(base.forms.lemma, function(form)
					if form == base.lemma and base.orig_lemma:find("%[%[") then
						return base.orig_lemma
					else
						return form
					end
				end))
			end

			local inflect_props = {
				slot_table = all_verb_slots,
				inflect_word_spec = conjugate_verb,
			}
			iut.inflect_multiword_or_alternant_multiword_spec(alternant_multiword_spec, inflect_props)

			-- (4) Fetch the forms and put the conjugated lemmas in data.heads if not explicitly given.

			pres_3sgs = alternant_multiword_spec.forms.s_form
			pres_ptcs = alternant_multiword_spec.forms.ing_form
			pasts = alternant_multiword_spec.forms.ed_form
			past_ptcs = alternant_multiword_spec.forms.en_form
			-- Use the "linked" form of the lemma as the head if no head= explicitly given.
			-- If no links in this form and it has multiple words, autolink the individual words.
			-- The user can override this using head=.
			if #data.heads == 0 then
				for _, lemma_obj in ipairs(alternant_multiword_spec.forms.lemma_linked) do
					local lemma = lemma_obj.form
					if not lemma:find("%[%[") then
						local m_headword = require("Module:headword")
						if m_headword.head_is_multiword(lemma) then
							lemma = m_headword.add_multiword_links(lemma)
						end
					end
					table.insert(data.heads, lemma)
				end
			end
		else
			-------------------------- SEPARATE-PARAM FORMAT --------------------------

			local pres_3sg, pres_ptc, past

			if par1 and not par2 and not par3 then
				-- Use of a single parameter other than "++", "*" or "++*" is now the "legacy" format,
				-- and no longer supported.
				if par1 == "es" or par1 == "ies" or par1 == "d" then
					error("Legacy parameter 1=es/ies/d no longer supported, just use 'en-verb' without params")
				elseif par1 == "++" or par1 == "*" or par1 == "++*" then
					pres_3sg = canonicalize_s_form(par1)
					pres_ptc = canonicalize_ing_form(par1)
					past = canonicalize_ed_form(par1)
				else
					error("Legacy parameter 1=STEM no longer supported, just use 'en-verb' without params")
				end
			else
				if par3 then
					track("xxx3")
				elseif par2 then
					track("xxx2")
				end
			end

			if not pres_3sg or not pres_ptc or not past then
				-- Either all three should be set above, or none of them.
				assert(not pres_3sg and not pres_ptc and not past)

				if par1 then
					pres_3sg = canonicalize_s_form(par1)
				else
					pres_3sg = new_default_s
				end

				if par2 then
					pres_ptc = canonicalize_ing_form(par2)
				else
					pres_ptc = new_default_ing
				end

				if par3 then
					past = canonicalize_ed_form(par3)
				else
					past = new_default_ed
				end
			end

			if par4 then
				past_ptcs_given = true
				past_ptc = canonicalize_ed_form(par4)
			else
				past_ptc = past
			end

			pres_3sgs = {{form = pres_3sg}}
			pres_ptcs = {{form = pres_ptc}}
			pasts = {{form = past}}
			past_ptcs = {{form = past_ptc}}
		end

		------------------------------------------- HANDLE OVERRIDES ------------------------------------------

		local pres_3sg_infls, pres_ptc_infls, past_infls, past_ptc_infls

		local function strip_brackets(qualifiers)
			if not qualifiers then
				return nil
			end
			local stripped_qualifiers = {}
			for _, qualifier in ipairs(qualifiers) do
				local stripped_qualifier = qualifier:match("^%[(.*)%]$")
				if not stripped_qualifier then
					error("Internal error: Qualifier should be surrounded by brackets at this stage: " .. qualifier)
				end
				table.insert(stripped_qualifiers, stripped_qualifier)
			end
			return stripped_qualifiers
		end

		local function collect_forms(label, accel_form, defaults, overrides, override_qualifiers, canonicalize)
			if defaults[1].form == "-" then
				return {label = "no " .. label}
			else
				local into_table = {label = label, accel = {form = accel_form}}
				local maxindex = math.max(#defaults, overrides.maxindex)
				local qualifiers = override_qualifiers[1] and {override_qualifiers[1]} or strip_brackets(defaults[1].footnotes)
				table.insert(into_table, {term = defaults[1].form, qualifiers = qualifiers})

				-- Present 3rd singular
				for i = 2, maxindex do
					local override_form = canonicalize(overrides[i])
		
					if override_form then
						-- If there is an override such as past_ptc2=..., only use the qualifier specified
						-- using an override (past_ptc2_qual=...), if any; it doesn't make sense to combine
						-- an override form with a qualifier specified inside of angle brackets.
						table.insert(into_table, {term = override_form, qualifiers = {override_qualifiers[i]}})
					elseif defaults[i] then
						-- If the form comes from inside angle brackets, allow any override qualifier
						-- (past_ptc2_qual=...) to override any qualifier specified inside of angle brackets.
						-- FIXME: Maybe we should throw an error here if both exist.
						local qualifiers = override_qualifiers[i] and {override_qualifiers[i]} or strip_brackets(defaults[i].footnotes)
						table.insert(into_table, {term = defaults[i].form, qualifiers = qualifiers})
					end
				end

				return into_table
			end
		end

		local pres_3sg_infls = collect_forms("third-person singular simple present", "3|s|pres",
			pres_3sgs, args[1], args.pres_3sg_qual, canonicalize_s_form)
		local pres_ptc_infls = collect_forms("present participle", "pres|ptcp",
			pres_ptcs, args[2], args.pres_ptc_qual, canonicalize_ing_form)
		local past_infls = collect_forms("simple past", "past",
			pasts, args[3], args.past_qual, canonicalize_ed_form)
		local past_ptc_infls = collect_forms("past participle", "past|ptcp",
			past_ptcs, args[4], args.past_ptc_qual, canonicalize_ed_form)
		
		-- Are the past forms identical to the past participle forms? If so, we use a single
		-- combined "simple past and past participle" label on the past tense forms.
		-- We check for two conditions: Either no past participle forms were given at all, or
		-- they were given but are identical in every way (all forms and qualifiers) to the past
		-- tense forms. The former "no explicit past participle forms" check is important in the
		-- "separate-parameter" format; if past tense overrides are given and no past participle
		-- forms given, the past tense overrides should apply to the past participle as well.
		-- In the angle-bracket format, it's expected that all forms and qualifiers are specified
		-- using that format, and we explicitly copy past tense forms and qualifiers to past
		-- participle ones if the latter are omitted, so we disable to "no explicit past participle
		-- forms" check.
		if args[4].maxindex > 0 or args.past_ptc_qual.maxindex > 0 then
			past_ptcs_given = true
		end

		local identical = true

		-- For the past and past participle to be identical, there must be
		-- the same number of inflections, and each inflection must match
		-- in term and qualifiers.
		if #past_infls ~= #past_ptc_infls then
			identical = false
		else
			for key, val in ipairs(past_infls) do
				if past_ptc_infls[key].term ~= val.term then
					identical = false
					break
				else
					local quals1 = past_ptc_infls[key].qualifiers
					local quals2 = val.qualifiers
					if (not not quals1) ~= (not not quals2) then
						-- one is nil, the other is not
						identical = false
					elseif quals1 and quals2 then
						-- qualifiers present in both; each qualifier must match
						if #quals1 ~= #quals2 then
							identical = false
						else
							for k, v in ipairs(quals1) do
								if v ~= quals2[k] then
									identical = false
									break
								end
							end
						end
					end
					if not identical then
						break
					end
				end
			end
		end
		
		-- Insert the forms
		table.insert(data.inflections, pres_3sg_infls)
		table.insert(data.inflections, pres_ptc_infls)
		
		if not past_ptcs_given or identical then
			if past_ptcs[1].form == "-" then
				past_infls.label = "no simple past or past participle"
			else
				past_infls.label = "simple past and past participle"
				past_infls.accel = {form = "past|and|past|ptcp"}
			end
			table.insert(data.inflections, past_infls)
		else
			table.insert(data.inflections, past_infls)
			table.insert(data.inflections, past_ptc_infls)
		end
	end
}

return export
