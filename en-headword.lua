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
		["head"] = {list = true, default = ""},
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
		
		local function check_ies(pl, stem)			local newplural, nummatches = stem:gsub("([^aeiou])y$","%1ies")
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
		["new"] = {type = "boolean"},
		["pagename"] = {}, -- for testing
		},
	func = function(args, data)
		-- Get parameters
		local par1 = args[1][1]
		local par2 = args[2][1]
		local par3 = args[3][1]
		local par4 = args[4][1]
		
		local pres_3sg_forms = {label = "third-person singular simple present", accel = {form = "3|s|pres"}}
		local pres_ptc_forms = {label = "present participle", accel = {form = "pres|ptcp"}}
		local past_forms = {label = "simple past", accel = {form = "past"}}
		local past_ptc_forms = {label = "past participle", accel = {form = "past|ptcp"}}
		local pres_3sg_form, pres_ptc_form, past_form, past_ptc_form

		local pagename = args.pagename or PAGENAME

		-- temporary tracking for use of new=1 so it can be removed later
		if args.new then
			track("verb-new")
		end
		
		local new_default_s, new_default_ing, new_default_ed, split_default_s, split_default_ing, split_default_ed =
			default_verb_forms(pagename)

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

		if par1 and par1:find("<") then
			if par2 or par3 or par4 then
				error("Can't specify 2=, 3= or 4= when 1= contains angle brackets: " .. par1)
			end
			local function parse_indicator_spec(angle_bracket_spec)
				local inside = angle_bracket_spec:match("^<(.*)>$")
				assert(inside)
				local parts = mw.text.split(inside, "%s*,%s*")
				if #parts > 4 then
					error("Too many comma-separated parts in indicator spec: " .. angle_bracket_spec)
				end
				local s_form, ing_form, ed_form, en_form = unpack(parts)
				local function ine(arg)
					if arg == "*" or arg == "++*" then
						error("* and ++* not allowed inside of indicator specs: " .. angle_bracket_spec)
					end
					return arg ~= "" and arg or nil
				end
				s_form = ine(s_form)
				ing_form = ine(ing_form)
				ed_form = ine(ed_form)
				en_form = ine(en_form)
				if s_form == "++" and not ing_form and not ed_form then
					ing_form = "++"
					ed_form = "++"
				end
				return {
					forms = {},
					s_form = s_form,
					ing_form = ing_form,
					ed_form = ed_form,
					en_form = en_form,
				}
			end

			local parse_props = {
				parse_indicator_spec = parse_indicator_spec,
			}
			local iut = require("Module:inflection utilities")
			local alternant_multiword_spec = iut.parse_inflected_text(par1, parse_props)
			local all_verb_slots = {
				lemma = "infinitive",
				s_form = "3|s|pres",
				ing_form = "pres|ptcp",
				ed_form = "past",
				en_form = "past|ptcp",
			}
			local function conjugate_verb(base)
				local def_s_form, def_ing_form, def_ed_form = base_default_verb_forms(base.lemma)
				local function combine_stem_ending(stem, ending)
					return stem
				end
				local s_form = base.s_form
				if not s_form or s_form == "+" then
					s_form = def_s_form
				elseif s_form == "++" then
					s_form = compute_plusplus_s_form(base.lemma, def_s_form)
				end
				local ing_form = base.ing_form
				if not ing_form or ing_form == "+" then
					ing_form = def_ing_form
				elseif ing_form == "++" then
					ing_form = compute_double_last_cons_stem(base.lemma) .. "ing"
				end
				local ed_form = base.ed_form
				if not ed_form or ed_form == "+" then
					ed_form = def_ed_form
				elseif ed_form == "++" then
					ed_form = compute_double_last_cons_stem(base.lemma) .. "ed"
				end
				local en_form = base.en_form
				if not en_form then
					en_form = ed_form
				elseif en_form == "+" then
					en_form = def_ed_form
				elseif en_form == "++" then
					en_form = compute_double_last_cons_stem(base.lemma) .. "ed"
				end
				iut.add_forms(base.forms, "lemma", base.lemma, "", combine_stem_ending)
				iut.add_forms(base.forms, "s_form", s_form, "", combine_stem_ending)
				iut.add_forms(base.forms, "ing_form", ing_form, "", combine_stem_ending)
				iut.add_forms(base.forms, "ed_form", ed_form, "", combine_stem_ending)
				iut.add_forms(base.forms, "en_form", en_form, "", combine_stem_ending)
			end
			local inflect_props = {
				slot_table = all_verb_slots,
				inflect_word_spec = conjugate_verb,
			}
			iut.inflect_multiword_or_alternant_multiword_spec(alternant_multiword_spec, inflect_props)
			local function fetch_form(slot)
				if not alternant_multiword_spec.forms[slot] or #alternant_multiword_spec.forms[slot] == 0 then
					error("Internal error: Something wrong, no forms for slot '" .. slot .. "'")
				end
				if #alternant_multiword_spec.forms[slot] > 1 then
					error("Can't currently support multiple forms for slot '" .. slot .. "'")
				end
				local form = alternant_multiword_spec.forms[slot][1].form
				if not form then
					error("Internal error: Something wrong, missing form in first position for slot '" .. slot .. "'")
				end
				return form
			end
			pres_3sg_form = fetch_form("s_form")
			pres_ptc_form = fetch_form("ing_form")
			past_form = fetch_form("ed_form")
			past_ptc_form = fetch_form("en_form")

		else
			if par1 and not par2 and not par3 then
				-- Use of a single parameter other than "++", "*" or "++*" is now the "legacy" format,
				-- and no longer supported.
				if par1 == "es" then
					error("Legacy parameter 1=es no longer supported, just use 'en-verb' without params")
				elseif par1 == "ies" then
					error("Legacy parameter 1=ies no longer supported, just use 'en-verb' without params")
				elseif par1 == "d" then
					error("Legacy parameter 1=d no longer supported, just use 'en-verb' without params")
				elseif par1 == "++" or par1 == "*" or par1 == "++*" then
					pres_3sg_form = canonicalize_s_form(par1)
					pres_ptc_form = canonicalize_ing_form(par1)
					past_form = canonicalize_ed_form(par1)
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

			if not pres_3sg_form or not pres_ptc_form or not past_form then
				-- Either all three should be set above, or none of them.
				assert(not pres_3sg_form and not pres_ptc_form and not past_form)

				if par1 then
					pres_3sg_form = canonicalize_s_form(par1)
				else
					pres_3sg_form = new_default_s
				end

				if par2 then
					pres_ptc_form = canonicalize_ing_form(par2)
				else
					pres_ptc_form = new_default_ing
				end

				if par3 then
					past_form = canonicalize_ed_form(par3)
				else
					past_form = new_default_ed
				end
			end

			if par4 then
				past_ptc_form = canonicalize_ed_form(par4)
			else
				past_ptc_form = past_form
			end
		end

		table.insert(pres_ptc_forms, {term = pres_ptc_form, qualifiers = {args["pres_ptc_qual"][1]}})
		table.insert(pres_3sg_forms, {term = pres_3sg_form, qualifiers = {args["pres_3sg_qual"][1]}})
		table.insert(past_forms, {term = past_form, qualifiers = {args["past_qual"][1]}})
		
		-- Present 3rd singular
		for i = 2, args[1].maxindex do
			local form = canonicalize_s_form(args[1][i])
			local qual = args["pres_3sg_qual"][i]

			if form then
				table.insert(pres_3sg_forms, {term = form, qualifiers = {qual}})
			end
		end
		
		-- Present participle
		for i = 2, args[2].maxindex do
			local form = canonicalize_ing_form(args[2][i])
			local qual = args["pres_ptc_qual"][i]
			
			if form then
				table.insert(pres_ptc_forms, {term = form, qualifiers = {qual}})
			end
		end
		
		-- Past
		for i = 2, args[3].maxindex do
			local form = canonicalize_ed_form(args[3][i])
			local qual = args["past_qual"][i]
			
			if form then
				table.insert(past_forms, {term = form, qualifiers = {qual}})
			end
		end
		
		-- Past participle
		local found_past_ptc = false
		local qual = args["past_ptc_qual"][1]
		table.insert(past_ptc_forms, {term = past_ptc_form, qualifiers = {qual}})
		if past_ptc_form ~= past_form or qual then
			found_past_ptc = true
		end
		for i = 2, args[4].maxindex do
			local form = canonicalize_ed_form(args[4][i])
			local qual = args["past_ptc_qual"][i]

			if form then
				table.insert(past_ptc_forms, {term = form, qualifiers = {qual}})
				found_past_ptc = true
			end
		end
		
		-- Are the past forms identical to the past participle forms?
		local identical = true
		
		if #past_forms ~= #past_ptc_forms then
			identical = false
		else
			for key, val in ipairs(past_forms) do
				if past_ptc_forms[key].term ~= val.term or past_ptc_forms[key].qual ~= val.qual then
					identical = false
					break
				end
			end
		end
		
		-- Insert the forms
		table.insert(data.inflections, pres_3sg_forms)
		table.insert(data.inflections, pres_ptc_forms)
		
		if not found_past_ptc or identical then
			past_forms.label = "simple past and past participle"
			past_forms.accel = {form = "past|and|past|ptcp"}
			table.insert(data.inflections, past_forms)
		else
			table.insert(data.inflections, past_forms)
			table.insert(data.inflections, past_ptc_forms)
		end
	end
}

return export
