local export = {}
local pos_functions = {}

local u = mw.ustring.char
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsplit = mw.text.split

local m_links = require("Module:links")
local com = require("Module:es-common")

local lang = require("Module:languages").getByCode("es")
local langname = lang:getCanonicalName()

local PAGENAME = mw.title.getCurrentTitle().text

local V = com.V -- vowel regex class
local AV = com.AV -- accented vowel regex class
local C = com.C -- consonant regex class

local rsub = com.rsub

local suffix_categories = {
	["adjectives"] = true,
	["adverbs"] = true,
	["nouns"] = true,
	["verbs"] = true,
}

local prepositions = {
	"al? ",
	"del? ",
	"como ",
	"con ",
	"en ",
	"para ",
	"por ",
}

-- Add links around words. If multiword_only, do it only in multiword forms.
local function add_links(form, multiword_only)
	if form == "" or form == " " then
		return form
	end
	if not form:find("%[%[") then
		if rfind(form, "[%s%p]") then --optimization to avoid loading [[Module:headword]] on single-word forms
			local m_headword = require("Module:headword")
			if m_headword.head_is_multiword(form) then
				form = m_headword.add_multiword_links(form)
			end
		end
		if not multiword_only and not form:find("%[%[") then
			form = "[[" .. form .. "]]"
		end
	end
	return form
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
		if form then
			local title = mw.title.new(form)
			if title and not title.exists then
				table.insert(tracking_categories, langname .. " " .. plpos .. " with red links in their headword lines")
			end
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
		["json"] = {type = "boolean"},
		["id"] = {},
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
		id = args["id"],
	}

	local lemma = m_links.remove_links(data.heads[1] or PAGENAME)
	if lemma:find("^%-") then -- suffix
		if poscat:find(" forms?$") then
			data.pos_category = "suffix forms"
		else
			data.pos_category = "suffixes"
		end

		if suffix_categories[poscat] then
			local singular_poscat = poscat:gsub("s$", "")
			table.insert(data.categories, langname .. " " .. singular_poscat .. "-forming suffixes")
		end
	end

	if pos_functions[poscat] then
		pos_functions[poscat].func(args, data, tracking_categories, frame)
	end

	if args["json"] then
		return require("Module:JSON").toJSON(data)
	end

	return require("Module:headword").full_headword(data)
		.. require("Module:utilities").format_categories(tracking_categories, lang)
end


local function make_plural(form, special)
	local retval = require("Module:romance utilities").handle_multiword(form, special, make_plural, prepositions)
	if retval then
		return retval
	end

	-- ends in unstressed vowel or á, é, ó
	if rfind(form, "[aeiouáéó]$") then return {form .. "s"} end

	-- ends in í or ú
	if rfind(form, "[íú]$") then
		return {form .. "s", form .. "es"}
	end

	-- ends in a vowel + z
	if rfind(form, V .. "z$") then
		return {rsub(form, "z$", "ces")}
	end

	-- ends in tz
	if rfind(form, "tz$") then return {form} end

	local syllables = com.syllabify(form)

	-- ends in s or x with more than 1 syllable, last syllable unstressed
	if syllables[2] and rfind(form, "[sx]$") and not rfind(syllables[#syllables], AV) then
		return {form}
	end

	-- ends in l, r, n, d, z, or j with 3 or more syllables, stressed on third to last syllable
	if syllables[3] and rfind(form, "[lrndzj]$") and rfind(syllables[#syllables - 2], AV) then
		return {form}
	end

	-- ends in an accented vowel + consonant
	if rfind(form, AV .. C .. "$") then
		return {rsub(form, "(.)(.)$", function(vowel, consonant)
			return com.remove_accent[vowel] .. consonant .. "es"
		end)}
	end

	-- ends in a vowel + y, l, r, n, d, j, s, x
	if rfind(form, "[aeiou][ylrndjsx]$") then
		-- two or more syllables: add stress mark to plural; e.g. joven -> jóvenes
		if syllables[2] and rfind(form, "n$") then
			syllables[#syllables - 1] = com.add_accent_to_syllable(syllables[#syllables - 1])
			return {table.concat(syllables, "") .. "es"}
		end

		return {form .. "es"}
	end

	-- ends in a vowel + ch
	if rfind(form, "[aeiou]ch$") then return {form .. "es"} end

	-- ends in two consonants
	if rfind(form, C .. C .. "$") then return {form .. "s"} end

	-- ends in a vowel + consonant other than l, r, n, d, z, j, s, or x
	if rfind(form, "[aeiou][^aeioulrndzjsx]$") then return {form .. "s"} end

	return nil
end

local function make_feminine(form, special)
	local retval = require("Module:romance utilities").handle_multiword(form, special, make_feminine, prepositions)
	if retval then
		if #retval ~= 1 then
			error("Internal error: Should have one return value for make_feminine: " .. table.concat(retval, ","))
		end
		return retval[1]
	end

	if form:find("o$") then
		local retval = form:gsub("o$", "a") -- discard second retval
		return retval
	end

	local function make_stem(form)
		return mw.ustring.gsub(
			form,
			"^(.+)(.)(.)$",
			function (before_stress, stressed_vowel, after_stress)
				return before_stress .. (com.remove_accent[stressed_vowel] or stressed_vowel) .. after_stress
			end)
	end

	if rfind(form, "[áíó]n$") or rfind(form, "[éí]s$") or rfind(form, "[dtszxñ]or$") or rfind(form, "ol$") then
		-- holgazán, comodín, bretón (not común); francés, kirguís (not mandamás);
		-- volador, agricultor, defensor, avizor, flexor, señor (not posterior, bicolor, mayor, mejor, menor, peor);
		-- español, mongol
		local stem = make_stem(form)
		return stem .. "a"
	end

	return form
end

local function make_masculine(form, special)
	local retval = require("Module:romance utilities").handle_multiword(form, special, make_masculine, prepositions)
	if retval then
		if #retval ~= 1 then
			error("Internal error: Should have one return value for make_masculine: " .. table.concat(retval, ","))
		end
		return retval[1]
	end

	if form:find("dora$") then
		local retval = form:gsub("a$", "") -- discard second retval
		return retval
	end

	if form:find("a$") then
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

	if args.sp and not require("Module:romance utilities").allowed_special_indicators[args.sp] then
		local indicators = {}
		for indic, _ in pairs(require("Module:romance utilities").allowed_special_indicators) do
			table.insert(indicators, "'" .. indic .. "'")
		end
		table.sort(indicators)
		error("Special inflection indicator beginning can only be " ..
			require("Module:table").serialCommaJoin(indicators, {dontTag = true}) .. ": " .. args.sp)
	end

	local argsf = args.f or {}
	local argspl = args.pl or {}
	local argsmpl = args.mpl or {}
	local argsfpl = args.fpl or {}

	if args.inv then
		-- invariable adjective
		table.insert(data.inflections, {label = "invariable"})
		table.insert(data.categories, langname .. " indeclinable adjectives")
		if args.sp or #argsf > 0 or #argspl > 0 or #argsmpl > 0 or #argsfpl > 0 then
			error("Can't specify inflections with an invariable adjective")
		end
	else
		local lemma = m_links.remove_links(data.heads[1] or PAGENAME)

		-- Gather feminines.
		if #argsf == 0 then
			argsf = {"+"}
		end
		for _, f in ipairs(argsf) do
			if f == "+" then
				-- Generate default feminine.
				f = make_feminine(lemma, args.sp)
			elseif f == "#" then
				f = lemma
			end
			table.insert(feminines, f)
		end

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
				local defpls = make_plural(lemma, args.sp)
				if not defpls then
					error("Unable to generate default plural of '" .. lemma .. "'")
				end
				for _, defpl in ipairs(defpls) do
					table.insert(plurals, defpl)
				end
			elseif pl == "#" then
				table.insert(plurals, lemma)
			else
				table.insert(plurals, pl)
			end
		end

		for _, mpl in ipairs(argsmpl) do
			if mpl == "+" then
				-- Generate default masculine plural.
				local defpls = make_plural(lemma, args.sp)
				if not defpls then
					error("Unable to generate default plural of '" .. lemma .. "'")
				end
				for _, defpl in ipairs(defpls) do
					table.insert(masculine_plurals, defpl)
				end
			elseif mpl == "#" then
				table.insert(masculine_plurals, lemma)
			else
				table.insert(masculine_plurals, mpl)
			end
		end

		for _, fpl in ipairs(argsfpl) do
			if fpl == "+" then
				for _, f in ipairs(feminines) do
					-- Generate default feminine plural.
					local defpls = make_plural(f, args.sp)
					if not defpls then
						error("Unable to generate default plural of '" .. f .. "'")
					end
					for _, defpl in ipairs(defpls) do
						table.insert(feminine_plurals, defpl)
					end
				end
			elseif fpl == "#" then
				table.insert(feminine_plurals, lemma)
			else
				table.insert(feminine_plurals, fpl)
			end
		end

		if args.mapoc then
			check_all_missing(args.mapoc, "adjectives", tracking_categories)
		end
		check_all_missing(feminines, "adjectives", tracking_categories)
		check_all_missing(plurals, "adjectives", tracking_categories)
		check_all_missing(masculine_plurals, "adjectives", tracking_categories)
		check_all_missing(feminine_plurals, "adjectives", tracking_categories)

		if args.mapoc and #args.mapoc > 0 then
			args.mapoc.label = "masculine singular before a noun"
			table.insert(data.inflections, args.mapoc)
		end

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
			feminine_plurals.accel = {form = "f|p"}
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
		["sp"] = {}, -- special indicator: "first", "first-last", etc.
		["f"] = {list = true}, --feminine form(s)
		["pl"] = {list = true}, --plural override(s)
		["fpl"] = {list = true}, --feminine plural override(s)
		["mpl"] = {list = true}, --masculine plural override(s)
		["mapoc"] = {list = true}, --masculine apocopated (before a noun)
		["comp"] = {list = true}, --comparative(s)
		["sup"] = {list = true}, --superlative(s)
	},
	func = function(args, data, tracking_categories)
		return do_adjective(args, data, tracking_categories, false)
	end
}

pos_functions["comparative adjectives"] = {
	params = {
		["inv"] = {type = "boolean"}, --invariable
		["sp"] = {}, -- special indicator: "first", "first-last", etc.
		["f"] = {list = true}, --feminine form(s)
		["pl"] = {list = true}, --plural override(s)
		["fpl"] = {list = true}, --feminine plural override(s)
		["mpl"] = {list = true}, --masculine plural override(s)
	},
	func = function(args, data, tracking_categories)
		return do_adjective(args, data, tracking_categories, false)
	end
}

pos_functions["superlative adjectives"] = {
	params = {
		["inv"] = {type = "boolean"}, --invariable
		["sp"] = {}, -- special indicator: "first", "first-last", etc.
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


pos_functions["past participles"] = {
	params = {
		[1] = {}, --FIXME: ignore this until we've fixed the uses
		["inv"] = {type = "boolean"}, --invariable
		["sp"] = {}, -- special indicator: "first", "first-last", etc.
	},
	func = function(args, data, tracking_categories)
		return do_adjective(args, data, tracking_categories, false)
	end
}


pos_functions["adverbs"] = {
	params = {
		["sup"] = {list = true}, --superlative(s)
	},
	func = function(args, data, tracking_categories, frame)
		if #args.sup > 0 then
			check_all_missing(args.sup, "adverbs", tracking_categories)
			args.sup.label = "superlative"
			table.insert(data.inflections, args.sup)
		end
	end,
}


pos_functions["cardinal numbers"] = {
	params = {
		["f"] = {list = true}, --feminine(s)
		["mapoc"] = {list = true}, --masculine apocopated form(s)
	},
	func = function(args, data, tracking_categories, frame)
		data.pos_category = "numerals"
		table.insert(data.categories, 1, langname .. " cardinal numbers")

		if #args.f > 0 then
			table.insert(data.genders, "m")
			check_all_missing(args.f, "numerals", tracking_categories)
			args.f.label = "feminine"
			table.insert(data.inflections, args.f)
		end
		if #args.mapoc > 0 then
			check_all_missing(args.mapoc, "numerals", tracking_categories)
			args.mapoc.label = "masculine before a noun"
			table.insert(data.inflections, args.mapoc)
		end
	end,
}


-- Display information for a noun's gender
-- This is separate so that it can also be used for proper nouns
local function noun_gender(args, data)
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
		["dim"] = {list = true}, --diminutive(s)
		["aug"] = {list = true}, --diminutive(s)
		["pej"] = {list = true}, --pejorative(s)
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

		local lemma = m_links.remove_links(
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
					local default_pls = make_plural(lemma)
					for _, defp in ipairs(default_pls) do
						table.insert(plurals, defp)
					end
				elseif pl == "#" then
					table.insert(plurals, lemma)
				elseif pl:find("^%+") then
					pl = require("Module:romance utilities").get_special_indicator(pl)
					local default_pls = make_plural(lemma, pl)
					for _, defp in ipairs(default_pls) do
						table.insert(plurals, defp)
					end
				else
					table.insert(plurals, pl)
				end
			end

			-- Check for special plural signals
			local mode = nil

			if #plurals > 0 and #plurals[1] == 1 then
				if plurals[1] == "?" or plurals[1] == "!" or plurals[1] == "-" or plurals[1] == "~" then
					mode = plurals[1]
					table.remove(plurals, 1)  -- Remove the mode parameter
				else
					error("Unexpected plural code")
				end
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
					local pls = make_plural(lemma)
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

		-- Gather masculines/feminines. For each one, generate the corresponding plural(s).
		local function handle_mf(mfs, inflect, default_plurals)
			local retval = {}
			for _, mf in ipairs(mfs) do
				if mf == "1" then
					track("noun-mf-1")
				end
				if mf == "1" or mf == "+" then
					-- Generate default feminine.
					mf = inflect(lemma)
				elseif mf == "#" then
					mf = lemma
				end
				local special = require("Module:romance utilities").get_special_indicator(mf)
				if special then
					mf = inflect(lemma, special)
				end
				table.insert(retval, mf)
				local mfpls = make_plural(mf, special)
				if mfpls then
					for _, mfpl in ipairs(mfpls) do
						-- Add an accelerator for each masculine/feminine plural whose lemma
						-- is the corresponding singular, so that the accelerated entry
						-- that is generated has a definition that looks like
						-- # {{plural of|es|MFSING}}
						table.insert(default_plurals, {term = mfpl, accel = {form = "p", lemma = mf}})
					end
				end
			end
			return retval
		end

		local feminine_plurals = {}
		local feminines = handle_mf(args.f, make_feminine, feminine_plurals)
		local masculine_plurals = {}
		local masculines = handle_mf(args.m, make_masculine, masculine_plurals)

		local function handle_mf_plural(mfpl, default_plurals, singulars)
			local new_mfpls = {}
			for i, mfpl in ipairs(mfpl) do
				local accel
				if #mfpl == #singulars then
					-- If same number of overriding masculine/feminine plurals as singulars,
					-- assume each plural goes with the corresponding singular
					-- and use each corresponding singular as the lemma in the accelerator.
					-- The generated entry will have # {{plural of|es|SINGULAR}} as the
					-- definition.
					accel = {form = "p", lemma = singulars[i]}
				else
					accel = nil
				end
				if mfpl == "+" then
					for _, defpl in ipairs(default_plurals) do
						-- defpl is already a table
						table.insert(new_mfpls, defpl)
					end
				elseif mfpl == "#" then
					table.insert(new_mfpls, {term = lemma, accel = accel})
				elseif mfpl:find("^%+") then
					mfpl = require("Module:romance utilities").get_special_indicator(mfpl)
					for _, mf in ipairs(singulars) do
						local default_mfpls = make_plural(mf, mfpl)
						for _, defp in ipairs(default_mfpls) do
							table.insert(new_mfpls, {term = defp, accel = accel})
						end
					end
				else
					table.insert(new_mfpls, {term = mfpl, accel = accel})
				end
			end
			return new_mfpls
		end

		if #args.fpl > 0 then
			-- Override any existing feminine plurals.
			feminine_plurals = handle_mf_plural(args.fpl, feminine_plurals, feminines)
		end

		if #args.mpl > 0 then
			-- Override any existing masculine plurals.
			masculine_plurals = handle_mf_plural(args.mpl, masculine_plurals, masculines)
		end

		check_all_missing(plurals, "nouns", tracking_categories)
		check_all_missing(feminines, "nouns", tracking_categories)
		check_all_missing(feminine_plurals, "nouns", tracking_categories)
		check_all_missing(masculines, "nouns", tracking_categories)
		check_all_missing(masculine_plurals, "nouns", tracking_categories)
		check_all_missing(args.dim, "nouns", tracking_categories)
		check_all_missing(args.aug, "nouns", tracking_categories)
		check_all_missing(args.pej, "nouns", tracking_categories)

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
			table.insert(data.inflections, masculine_plurals)
		end

		if #args.dim > 0 then
			args.dim.label = glossary_link("diminutive")
			table.insert(data.inflections, args.dim)
		end

		if #args.aug > 0 then
			args.aug.label = glossary_link("augmentative")
			table.insert(data.inflections, args.aug)
		end

		if #args.pej > 0 then
			args.pej.label = glossary_link("pejorative")
			table.insert(data.inflections, args.pej)
		end

		-- Maybe add category 'Spanish nouns with irregular gender' (or similar)
		local irreg_gender_lemma = rsub(lemma, " .*", "") -- only look at first word
		if (rfind(irreg_gender_lemma, "o$") and (args[1] == "f" or args[1] == "mf" or args[1] == "mfbysense")) or
			(irreg_gender_lemma:find("a$") and (args[1] == "m" or args[1] == "mf" or args[1] == "mfbysense")) then
			table.insert(data.categories, langname .. " nouns with irregular gender")
		end
	end
}

pos_functions["verbs"] = {
	params = {
		[1] = {},
		["pres"] = {list = true}, --present
		["pres_qual"] = {list = "pres=_qual", allow_holes = true},
		["pret"] = {list = true}, --preterite
		["pret_qual"] = {list = "pret=_qual", allow_holes = true},
		["part"] = {list = true}, --participle
		["part_qual"] = {list = "part=_qual", allow_holes = true},
		["pagename"] = {}, -- for testing
		["noautolinktext"] = {type = "boolean"},
		["noautolinkverb"] = {type = "boolean"},
		["attn"] = {type = "boolean"},
		["new"] = {type = "boolean"},
	},
	func = function(args, data, tracking_categories, frame)
		local preses, prets, parts
		local pagename = args.pagename or PAGENAME
		local def_forms

		if args.attn then
			table.insert(tracking_categories, "Requests for attention concerning " .. langname)
			return
		end

		if mw.title.getCurrentTitle().nsText == "Template" and PAGENAME == "es-verb" and not args.pagename then
			pagename = "averiguar"
		end
		
		local parargs = frame:getParent().args
		local alternant_multiword_spec = require("Module:es-verb").do_generate_forms(parargs, "from headword")
		for _, cat in ipairs(alternant_multiword_spec.categories) do
			table.insert(data.categories, cat)
		end

		if #data.heads == 0 then
			data.no_redundant_head_cat = true
			for _, head in ipairs(alternant_multiword_spec.forms.infinitive_linked) do
				table.insert(data.heads, head.form)
			end
		end

		local specforms = alternant_multiword_spec.forms
		local function slot_exists(slot)
			return specforms[slot] and #specforms[slot] > 0
		end

		local function do_finite(slot_tense, label_tense)
			-- Use pres_3s if it exists and pres_1s doesn't exist (e.g. impersonal verbs); similarly for pres_3p (only3p verbs);
			-- but fall back to pres_1s if neither pres_1s nor pres_3s nor pres_3p exist (e.g. [[empedernir]]).
			local has_1s = slot_exists(slot_tense .. "_1s")
			local has_3s = slot_exists(slot_tense .. "_3s")
			local has_3p = slot_exists(slot_tense .. "_3p")
			if has_1s or (not has_3s and not has_3p) then
				return {
					slot = slot_tense .. "_1s",
					label = ("first-person singular %s"):format(label_tense),
					accel = ("1|s|%s|ind"):format(slot_tense),
				}
			elseif has_3s then
				return {
					slot = slot_tense .. "_3s",
					label = ("third-person singular %s"):format(label_tense),
					accel = ("3|s|%s|ind"):format(slot_tense),
				}
			else
				return {
					slot = slot_tense .. "_3p",
					label = ("third-person plural %s"):format(label_tense),
					accel = ("3|p|%s|ind"):format(slot_tense),
				}
			end
		end

		preses = do_finite("pres", "present")
		prets = do_finite("pret", "preterite")
		parts = {
			slot = "pp_ms",
			label = "past participle",
			accel = "m|s|past|part"
		}

		if #args.pres > 0 or #args.pret > 0 or #args.part > 0 then
			track("verb-old-multiarg")
		end

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

		local function do_verb_form(args, qualifiers, slot_desc)
			local forms

			if #args == 0 then
				forms = specforms[slot_desc.slot]
				if not forms or #forms == 0 then
					forms = {{form = "-"}}
				end
			elseif #args == 1 and args[1] == "-" then
				forms = {{form = "-"}}
			else
				forms = {}
				for i, arg in ipairs(args) do
					local qual = qualifiers[i]
					if qual then
						-- FIXME: It's annoying we have to add brackets and strip them out later. The inflection
						-- code adds all footnotes with brackets around them; we should change this.
						qual = {"[" .. qual .. "]"}
					end
					local form = arg
					if not args.noautolinkverb then
						form = add_links(form)
					end
					table.insert(forms, {form = form, footnotes = qual})
				end
			end

			if forms[1].form == "-" then
				return {label = "no " .. slot_desc.label}
			else
				local into_table = {label = slot_desc.label}
				local accel = {form = slot_desc.accel}
				for _, form in ipairs(forms) do
					local qualifiers = strip_brackets(form.footnotes)
					-- Strip redundant brackets surrounding entire form. These may get generated e.g.
					-- if we use the angle bracket notation with a single word.
					local stripped_form = rmatch(form.form, "^%[%[([^%[%]]*)%]%]$") or form.form
					-- Don't include accelerators if brackets remain in form, as the result will be wrong.
					local this_accel = not stripped_form:find("%[%[") and accel or nil
					table.insert(into_table, {term = stripped_form, q = qualifiers, accel = this_accel})
				end
				return into_table
			end
		end

		if alternant_multiword_spec.only3s then
			table.insert(data.inflections, {label = glossary_link("impersonal")})
		elseif alternant_multiword_spec.only3sp then
			table.insert(data.inflections, {label = "third-person only"})
		elseif alternant_multiword_spec.only3p then
			table.insert(data.inflections, {label = "third-person plural only"})
		end
	
		table.insert(data.inflections, do_verb_form(args.pres, args.pres_qual, preses))
		table.insert(data.inflections, do_verb_form(args.pret, args.pret_qual, prets))
		table.insert(data.inflections, do_verb_form(args.part, args.part_qual, parts))
	end
}


return export
