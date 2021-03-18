local export = {}
local pos_functions = {}

local rfind = mw.ustring.find
local rmatch = mw.ustring.match

local lang = require("Module:languages").getByCode("es")
local langname = lang:getCanonicalName()

local PAGENAME = mw.title.getCurrentTitle().text

local suffix_categories = {
	["adjectives"] = true,
	["adverbs"] = true,
	["nouns"] = true,
	["verbs"] = true,
}

local remove_stress = {
	["á"] = "a", ["é"] = "e", ["í"] = "i", ["ó"] = "o", ["ú"] = "u"
}
local add_stress = {
	["a"] = "á", ["e"] = "é", ["i"] = "í", ["o"] = "ó", ["u"] = "ú"
}

local allowed_special_indicators = {
	["first"] = true,
	["first-last"] = true,
	["second"] = true,
}

local function get_special_indicator(form)
	if form:find("^%*") then
		form = form:gsub("^%*", "")
		if not allowed_special_indicators[form] then
			error("Special inflection indicator beginning with '*' can only be '*first', '*first-last' or '*second': " .. form)
		end
		return form
	end
	return nil
end

local function track(page)
	require("Module:debug").track("es-headword/" .. page)
	return true
end

local function glossary_link(entry, text)
	text = text or entry
	return "[[Appendix:Glossary#" .. entry .. "|" .. text .. "]]"
end

local function check_all_missing(forms, plpos, tracking_categories)
	for _, form in ipairs(forms) do
		if type(form) == "table" then
			form = form.term
		end
		if form and not mw.title.new(form).exists then
			table.insert(tracking_categories, langname .. " " .. plpos .. " with red links in their headword lines")
		end
	end
end
	
-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	local tracking_categories = {}
	
	local poscat = frame.args[1]
		or error("Part of speech has not been specified. Please pass parameter 1 to the module invocation.")
	
	local params = {
		["head"] = {list = true},
		["suff"] = {type = "boolean"},
		["json"] = {type = "boolean"},
	}

	local parargs = frame:getParent().args
	if poscat == "nouns" and (not parargs[2] or parargs[2] == "") and parargs.pl2 then
		track("noun-pl2-without-pl")
	end

	if pos_functions[poscat] then
		for key, val in pairs(pos_functions[poscat].params) do
			params[key] = val
		end
	end
	
	local args = require("Module:parameters").process(parargs, params)
	local data = {
		lang = lang,
		pos_category = poscat,
		categories = {},
		heads = args["head"],
		genders = {},
		inflections = {},
		categories = {}
	}
	
	if args["suff"] then
		data.pos_category = "suffixes"
		
		if suffix_categories[poscat] then
			local singular_poscat = poscat:gsub("s$", "")
			table.insert(data.categories, langname .. " " .. singular_poscat .. "-forming suffixes")
		else
			error("No category exists for suffixes forming " .. poscat .. ".")
		end
	end
	
	if pos_functions[poscat] then
		pos_functions[poscat].func(args, data, tracking_categories)
	end
	
	if args["json"] then
		return require("Module:JSON").toJSON(data)
	end

	return require("Module:headword").full_headword(data)
		.. require("Module:utilities").format_categories(tracking_categories, lang)
end


local function add_ending_to_plurals(plurals, ending)
	local retval = {}
	for _, pl in ipairs(plurals) do
		if type(ending) == "table" then
			for _, en in ipairs(ending) do
				table.insert(retval, pl .. en)
			end
		else
			table.insert(retval, pl .. ending)
		end
	end
	return retval
end


function export.make_plural(singular, special)
	if special == "first" then
		local first, rest = rmatch(singular, "^(.-)( .*)$")
		if not first then
			error("Special indicator 'first' can only be used with a multiword term: " .. singular)
		end
		return add_ending_to_plurals(export.make_plural(first), rest)
	elseif special == "second" then
		local first, second, rest = rmatch(singular, "^([^ ]+ )([^ ]+)( .*)$")
		if not first then
			error("Special indicator 'second' can only be used with a term with three or more words: " .. singular)
		end
		return add_ending_to_plurals(add_ending_to_plurals({first}, export.make_plural(second)), rest)
	elseif special == "first-last" then
		local first, middle, last = rmatch(singular, "^(.-)( .* )(.-)$")
		if not first then
			first, middle, last = rmatch(singular, "^(.-)( )(.*)$")
		end
		if not first then
			error("Special indicator 'first-last' can only be used with a multiword term: " .. singular)
		end
		return add_ending_to_plurals(add_ending_to_plurals(export.make_plural(first), middle), export.make_plural(last))
	elseif special then
		error("Unrecognized special=" .. special)
	end
	
	-- ends in unstressed vowel or á, é, ó
	if rfind(singular, "[aeiouáéó]$") then return {singular .. "s"} end
	
	-- ends in í or ú
	if rfind(singular, "[íú]$") then
		return {singular .. "s", singular .. "es"}
	end
	
	-- ends in a vowel + z
	if rfind(singular, "[aeiouáéíóú]z$") then
		-- discard all but first return value
		local retval = mw.ustring.gsub(singular, "z$", "ces")
		return {retval}
	end
	
	-- ends in tz
	if rfind(singular, "tz$") then return {singular} end

	local vowels = {}
	-- Replace qu before e or i with k so that the u isn't counted as a vowel.
	local modified_singular = mw.ustring.gsub(singular, "qu([ie])", "k%1")
	for i in mw.ustring.gmatch(modified_singular, "[aeiouáéíóú]") do vowels[#vowels + 1] = i end
	
	-- ends in s or x with more than 1 syllable, last syllable unstressed
	if vowels[2] and rfind(singular, "[sx]$")
	and rfind(vowels[#vowels], "[aeiou]") then
		return {singular}
	end
	
	-- ends in l, r, n, d, z, or j with 3 or more syllables, accented on third to last syllable
	if vowels[3] and rfind(singular, "[lrndzj]$")
	and rfind(vowels[#vowels-2], "[áéíóú]") then
		return {singular}
	end
	
	-- ends in a in a stressed vowel + consonant
	if rfind(singular, "[áéíóú][^aeiouáéíóú]$") then
		-- discard all but first return value
		local retval = mw.ustring.gsub(
			singular,
			"(.)(.)$",
			function (vowel, consonant)
				return remove_stress[vowel] .. consonant .. "es"
			end)
		return {retval}
	end
	
	-- ends in a vowel + y, l, r, n, d, j, s, x
	if rfind(singular, "[aeiou][ylrndjsx]$") then
		--  two or more vowels: add stress mark to plural
		if vowels[2] and rfind(singular, "n$") then
			local before_stress, after_stress = rmatch(
				modified_singular,
				"^(.*)[aeiou]([^aeiou]*[aeiou][nl])$")
			local stress = add_stress[vowels[#vowels - 1]]
			if before_stress and stress then
				-- discard all but first return value
				local retval = (before_stress .. stress .. after_stress .. "es"):gsub("k", "qu")
				return {retval}
			end
		end
		
		return {singular .. "es"}
	end
	
	-- ends in a vowel + ch
	if rfind(singular, "[aeiou]ch$") then return {singular .. "es"} end
	
	-- ends in two consonants
	if rfind(singular, "[^aeiouáéíóú][^aeiouáéíóú]$") then return {singular .. "s"} end
	
	-- ends in a vowel + consonant other than l, r, n, d, z, j, s, or x
	if rfind(singular, "[aeiou][^aeioulrndzjsx]$") then return {singular .. "s"} end

	return nil
end

local function make_feminine(form, special)
	if special == "first" then
		local first, rest = rmatch(form, "^(.-)( .*)$")
		if not first then
			error("Special indicator 'first' can only be used with a multiword term: " .. form)
		end
		return make_feminine(first) .. rest
	elseif special == "second" then
		local first, second, rest = rmatch(form, "^([^ ]+ )([^ ]+)( .*)$")
		if not first then
			error("Special indicator 'second' can only be used with a term with three or more words: " .. form)
		end
		return first .. make_feminine(second) .. rest
	elseif special == "first-last" then
		local first, middle, last = rmatch(form, "^(.-)( .* )(.-)$")
		if not first then
			first, middle, last = rmatch(form, "^(.-)( )(.*)$")
		end
		if not first then
			error("Special indicator 'first-last' can only be used with a multiword term: " .. form)
		end
		return make_feminine(first) .. middle .. make_feminine(last)
	elseif special then
		error("Unrecognized special=" .. special)
	end

	if form:match("o$") then
		local retval = form:gsub("o$", "a") -- discard second retval
		return retval
	end
	
	local function make_stem(form)
		return mw.ustring.gsub(
			form,
			"^(.+)(.)(.)$",
			function (before_stress, stressed_vowel, after_stress)
				return before_stress .. (remove_stress[stressed_vowel] or stressed_vowel) .. after_stress
			end)
	end
	
	if rfind(form, "[áíó]n$") or rfind(form, "[éí]s$") or rfind(form, "[dtszxñ]or$") or rfind(form, "ol$") then
		-- holgazán, comodín, bretón (not común); francés, kirguís (not mandamás);
		-- volador, agricultor, defensor, avizor, flexor, señor (not posterior, bicolor, mayor, mejor, menor, peor);
		-- español
		local stem = make_stem(form)
		return stem .. "a"
	end

	return form
end

local function make_masculine(form)
	if special == "first" then
		local first, rest = rmatch(form, "^(.-)( .*)$")
		if not first then
			error("Special indicator 'first' can only be used with a multiword term: " .. form)
		end
		return make_masculine(first) .. rest
	elseif special == "second" then
		local first, second, rest = rmatch(form, "^([^ ]+ )([^ ]+)( .*)$")
		if not first then
			error("Special indicator 'second' can only be used with a term with three or more words: " .. form)
		end
		return first .. make_masculine(second) .. rest
	elseif special == "first-last" then
		local first, middle, last = rmatch(form, "^(.-)( .* )(.-)$")
		if not first then
			first, middle, last = rmatch(form, "^(.-)( )(.*)$")
		end
		if not first then
			error("Special indicator 'first-last' can only be used with a multiword term: " .. form)
		end
		return make_masculine(first) .. middle .. make_masculine(last)
	elseif special then
		error("Unrecognized special=" .. special)
	end
	if form:match("dora$") then
		local retval = form:gsub("a$", "") -- discard second retval
		return retval
	end
	
	if form:match("a$") then
		local retval = form:gsub("a$", "o") -- discard second retval
		return retval
	end

	return form
end

local function do_adjective(args, data, tracking_categories, is_superlative)
	local feminines = {}
	local plurals = {}
	local masculine_plurals = {}
	local feminine_plurals = {}

	if args.sp and not allowed_special_indicators[args.sp] then
		error("Special inflection indicator can only be 'first', 'first-last' or 'second': " .. args.sp)
	end

	if args.inv then
		-- invariable adjective
		table.insert(data.inflections, {label = "invariable"})
		table.insert(data.categories, langname .. " indeclinable adjectives")
		if args.sp or #args.f > 0 or #args.pl > 0 or #args.mpl > 0 or #args.fpl > 0 then
			error("Can't specify inflections with an invariable adjective")
		end
	else
		local lemma = require("Module:links").remove_links(data.heads[1] or PAGENAME)

		-- Gather feminines.
		local argsf = args.f
		if #argsf == 0 then
			argsf = {"+"}
		end
		for _, f in ipairs(argsf) do
			if f == "+" then
				-- Generate default feminine.
				f = make_feminine(lemma, args.sp)
			end
			table.insert(feminines, f)
		end

		local argspl = args.pl
		local argsmpl = args.mpl
		local argsfpl = args.fpl
		if #argspl > 0 and (#argsmpl > 0 or #argsfpl > 0) then
			error("Can't specify both pl= and mpl=/fpl=")
		end
		if #feminines == 1 and feminines[1] == lemma then
			-- Feminine like the masculine; just generate a plural
			if #argspl == 0 then
				argspl = {"+"}
			end
		elseif #argspl == 0 then
			-- Distinct masculine and feminine plurals
			if #argsmpl == 0 then
				argsmpl = {"+"}
			end
			if #argsfpl == 0 then
				argsfpl = {"+"}
			end
		end

		for _, pl in ipairs(argspl) do
			if pl == "+" then
				-- Generate default plural.
				local defpls = export.make_plural(lemma, args.sp)
				if not defpls then
					error("Unable to generate default plural of '" .. lemma .. "'")
				end
				for _, defpl in ipairs(defpls) do
					table.insert(plurals, defpl)
				end
			else
				table.insert(plurals, pl)
			end
		end

		for _, mpl in ipairs(argsmpl) do
			if mpl == "+" then
				-- Generate default masculine plural.
				local defpls = export.make_plural(lemma, args.sp)
				if not defpls then
					error("Unable to generate default plural of '" .. lemma .. "'")
				end
				for _, defpl in ipairs(defpls) do
					table.insert(masculine_plurals, defpl)
				end
			else
				table.insert(masculine_plurals, mpl)
			end
		end

		for _, fpl in ipairs(argsfpl) do
			if fpl == "+" then
				for _, f in ipairs(feminines) do
					-- Generate default feminine plural.
					local defpls = export.make_plural(f, args.sp)
					if not defpls then
						error("Unable to generate default plural of '" .. f .. "'")
					end
					for _, defpl in ipairs(defpls) do
						table.insert(feminine_plurals, defpl)
					end
				end
			else
				table.insert(feminine_plurals, fpl)
			end
		end

		check_all_missing(feminines, "adjectives", tracking_categories)
		check_all_missing(plurals, "adjectives", tracking_categories)
		check_all_missing(masculine_plurals, "adjectives", tracking_categories)
		check_all_missing(feminine_plurals, "adjectives", tracking_categories)

		-- Make sure there are feminines given and not same as lemma.
		if #feminines > 0 and not (#feminines == 1 and feminines[1] == lemma) then
			feminines.label = "feminine"
			feminines.accel = {form = "f|s"}
			table.insert(data.inflections, feminines)
		end

		if #plurals > 0 then
			plurals.label = "plural"
			plurals.accel = {form = "p"}
			table.insert(data.inflections, plurals)
		end
	
		if #masculine_plurals > 0 then
			masculine_plurals.label = "masculine plural"
			masculine_plurals.accel = {form = "m|p"}
			table.insert(data.inflections, masculine_plurals)
		end

		if #feminine_plurals > 0 then
			feminine_plurals.label = "feminine plural"
			masculine_plurals.accel = {form = "f|p"}
			table.insert(data.inflections, feminine_plurals)
		end
	end
	
	if args.comp and #args.comp > 0 then
		check_all_missing(args.comp, "adjectives", tracking_categories)
		args.comp.label = "comparative"
		table.insert(data.inflections, args.comp)
	end
	
	if args.sup and #args.sup > 0 then
		check_all_missing(args.sup, "adjectives", tracking_categories)
		args.sup.label = "superlative"
		table.insert(data.inflections, args.sup)
	end
	
	if args.irreg and is_superlative then
		table.insert(data.categories, langname .. " irregular superlative adjectives")
	end
end


pos_functions["adjectives"] = {
	params = {
		["inv"] = {type = "boolean"}, --invariable
		["sp"] = {}, -- special indicator: "first", "second", "first-last"
		["f"] = {list = true}, --feminine form(s)
		["pl"] = {list = true}, --plural override(s)
		["fpl"] = {list = true}, --feminine plural override(s)
		["mpl"] = {list = true}, --masculine plural override(s)
		["comp"] = {list = true}, --comparative(s)
		["sup"] = {list = true}, --comparative(s)
	},
	func = function(args, data, tracking_categories)
		return do_adjective(args, data, tracking_categories, false)
	end
}

pos_functions["superlative adjectives"] = {
	params = {
		["inv"] = {type = "boolean"}, --invariable
		["sp"] = {}, -- special indicator: "first", "second", "first-last"
		["f"] = {list = true}, --feminine form(s)
		["pl"] = {list = true}, --plural override(s)
		["fpl"] = {list = true}, --feminine plural override(s)
		["mpl"] = {list = true}, --masculine plural override(s)
		["irreg"] = {type = "boolean"},
	},
	func = function(args, data, tracking_categories)
		return do_adjective(args, data, tracking_categories, true)
	end
}


-- Display information for a noun's gender
-- This is separate so that it can also be used for proper nouns
function noun_gender(args, data)
	local gender = args[1]
	table.insert(data.genders, gender)
	if #data.genders == 0 then
		table.insert(data.genders, "?")
	end
end

pos_functions["proper nouns"] = {
	params = {
		[1] = {},
		},
	func = function(args, data)
		noun_gender(args, data)
	end
}

-- Display additional inflection information for a noun
pos_functions["nouns"] = {
	params = {
		[1] = {required = true, default = "m"}, --gender
		["g2"] = {}, --second gender
		["e"] = {type = "boolean"}, --epicene
		[2] = {list = "pl"}, --plural override(s)
		["f"] = {list = true}, --feminine form(s)
		["m"] = {list = true}, --masculine form(s)
		["fpl"] = {list = true}, --feminine plural override(s)
		["mpl"] = {list = true}, --masculine plural override(s)
	},
	func = function(args, data, tracking_categories)
		local allowed_genders = {
			["m"] = true,
			["f"] = true,
			["m-p"] = true,
			["f-p"] = true,
			["mf"] = true,
			["mf-p"] = true,
			["mfbysense"] = true,
			["mfbysense-p"] = true,
		}

		local title = require("Module:links").remove_links(
			(#data.heads > 0 and data.heads[1]) or PAGENAME
		)

		if args[1] == "m-f" then
			args[1] = "mf"
		elseif args[1] == "mfp" or args[1] == "m-f-p" then
			args[1] = "mf-p"
		end
		
		if not allowed_genders[args[1]] then error("Unrecognized gender: " .. args[1]) end

		table.insert(data.genders, args[1])	

		if args.g2 then table.insert(data.genders, args.g2) end
		
		if args["e"] then
			table.insert(data.categories, langname .. " epicene nouns")
			table.insert(data.inflections, {label = glossary_link("epicene")})
		end

		local plurals = {}

		if args[1]:find("%-p$") then
			table.insert(data.inflections, {label = glossary_link("plural only")})
			if #args[2] > 0 then
				error("Can't specify plurals of a plurale tantum noun")
			end
		else
			-- Gather plurals, handling requests for default plurals
			for _, pl in ipairs(args[2]) do
				if pl == "+" then
					local default_pls = export.make_plural(title)
					for _, defp in ipairs(default_pls) do
						table.insert(plurals, defp)
					end
				elseif pl:find("^%*") then
					pl = get_special_indicator(pl)
					local default_pls = export.make_plural(title, pl)
					for _, defp in ipairs(default_pls) do
						table.insert(plurals, defp)
					end
				else
					table.insert(plurals, pl)
				end
			end

			-- Check for special plural signals
			local mode = nil
			
			if plurals[1] == "?" or plurals[1] == "!" or plurals[1] == "-" or plurals[1] == "~" then
				mode = plurals[1]
				table.remove(plurals, 1)  -- Remove the mode parameter
			end
			
			if mode == "?" then
				-- Plural is unknown
				table.insert(data.categories, langname .. " nouns with unknown or uncertain plurals")
			elseif mode == "!" then
				-- Plural is not attested
				table.insert(data.inflections, {label = "plural not attested"})
				table.insert(data.categories, langname .. " nouns with unattested plurals")
				return
			elseif mode == "-" then
				-- Uncountable noun; may occasionally have a plural
				table.insert(data.categories, langname .. " uncountable nouns")
				
				-- If plural forms were given explicitly, then show "usually"
				if #plurals > 0 then
					table.insert(data.inflections, {label = "usually " .. glossary_link("uncountable")})
					table.insert(data.categories, langname .. " countable nouns")
				else
					table.insert(data.inflections, {label = glossary_link("uncountable")})
				end
			else
				-- Countable or mixed countable/uncountable
				if #plurals == 0 then
					local pls = export.make_plural(title)
					if pls then
						for _, pl in ipairs(pls) do
							table.insert(plurals, pl)
						end
					end
				end
				if mode == "~" then
					-- Mixed countable/uncountable noun, always has a plural
					table.insert(data.inflections, {label = glossary_link("countable") .. " and " .. glossary_link("uncountable")})
					table.insert(data.categories, langname .. " uncountable nouns")
					table.insert(data.categories, langname .. " countable nouns")
				else
					-- Countable nouns
					table.insert(data.categories, langname .. " countable nouns")
				end
			end
		end

		local masculines = {}
		local feminines = {}
		local masculine_plurals = {}
		local feminine_plurals = {}
	
		-- Gather feminines. For each feminine, generate the corresponding plural(s).
		for _, f in ipairs(args.f) do
			if f == "1" then
				track("noun-f-1")
			end
			if f == "1" or f == "+" then
				-- Generate default feminine.
				f = make_feminine(title)
			end
			local special = get_special_indicator(f)
			if special then
				f = make_feminine(title, special)
			end
			table.insert(feminines, f)
			local fpls = export.make_plural(f, special)
			if fpls then
				for _, pl in ipairs(fpls) do
					-- Add an accelerator for each feminine plural whose lemma
					-- is the feminine singular, so that the accelerated entry
					-- that is generated has a definition that looks like
					-- # {{plural of|es|FEMININE}}
					table.insert(feminine_plurals, {term = pl, accel = {form = "p", lemma = f}})
				end
			end
		end
	
		-- Gather feminines. For each masculine, generate the corresponding plural(s).
		for _, m in ipairs(args.m) do
			if m == "+" then
				-- Generate default masculine.
				m = make_masculine(title)
			end
			local special = get_special_indicator(m)
			if special then
				m = make_masculine(title, special)
			end
			table.insert(masculines, m)
			local mpls = export.make_plural(m, special)
			if mpls then
				for _, pl in ipairs(mpls) do
					table.insert(masculine_plurals, pl)
				end
			end
		end
	
		if #args.fpl > 0 then
			-- Override any existing feminine plurals.
			if #args.fpl == #feminines then
				-- If same number of overriding feminine plurals as feminines,
				-- assume each feminine plural goes with the corresponding feminine
				-- and use each corresponding feminine as the lemma in the accelerator.
				-- The generated entry will have # {{plural of|es|FEMININE}} as the
				-- definition.
				feminine_plurals = {}
				for i, fpl in ipairs(args.fpl) do
					table.insert(feminine_plurals, {term = fpl, accel = {form = "p", lemma = feminines[i]}})
				end
			else
				-- Otherwise, don't add any accelerators.
				feminine_plurals = args.fpl
			end
		end
		if #args.mpl > 0 then
			-- Override any existing masculine plurals.
			masculine_plurals = args.mpl
		end
	
		check_all_missing(plurals, "nouns", tracking_categories)
		check_all_missing(feminines, "nouns", tracking_categories)
		check_all_missing(feminine_plurals, "nouns", tracking_categories)
		check_all_missing(masculines, "nouns", tracking_categories)
		check_all_missing(masculine_plurals, "nouns", tracking_categories)

		local function redundant_plural(pl)
			for _, p in ipairs(plurals) do
				if p == pl then
					return true
				end
			end
			return false
		end

		for _, mpl in ipairs(masculine_plurals) do
			if redundant_plural(mpl) then
				track("noun-redundant-mpl")
			end
		end
		
		for _, fpl in ipairs(feminine_plurals) do
			if redundant_plural(fpl) then
				track("noun-redundant-fpl")
			end
		end

		if #plurals > 0 then
			plurals.label = "plural"
			plurals.accel = {form = "p"}
			table.insert(data.inflections, plurals)
		end
	
		if #feminines > 0 then
			feminines.label = "feminine"
			feminines.accel = {form = "f"}
			table.insert(data.inflections, feminines)
		end

		if #feminine_plurals > 0 then
			feminine_plurals.label = "feminine plural"
			table.insert(data.inflections, feminine_plurals)
		end
	
		if #masculines > 0 then
			masculines.label = "masculine"
			table.insert(data.inflections, masculines)
		end

		if #masculine_plurals > 0 then
			masculine_plurals.label = "masculine plural"
			masculine_plurals.accel = {form = "p"}
			table.insert(data.inflections, masculine_plurals)
		end
	end
}

return export
