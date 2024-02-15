local export = {}
local pos_functions = {}

local m_links = require("Module:links")
local m_table = require("Module:table")

local lang = require("Module:languages").getByCode("cy")
local langname = lang:getCanonicalName()

local PAGENAME = mw.title.getCurrentTitle().text

local suffix_categories = {
	["adjectives"] = true,
	["adverbs"] = true,
	["nouns"] = true,
	["verbs"] = true,
}

local function track(page)
	require("Module:debug").track("cy-headword/" .. page)
	return true
end

local function glossary_link(entry, text)
	text = text or entry
	return "[[Appendix:Glossary#" .. entry .. "|" .. text .. "]]"
end

-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	local tracking_categories = {}
	
	local poscat = frame.args[1]
		or error("Plural part of speech e.g. 'nouns' has not been specified. Please pass parameter 1 to the module invocation.")
	
	local params = {
		["head"] = {list = true},
		["id"] = {},
		["sort"] = {},
		["suff"] = {type = "boolean"},
	}

    local parargs = frame:getParent().args

	if pos_functions[poscat] then
		local posparams
		if type(pos_functions[poscat].params) == "function" then
			posparams = pos_functions[poscat].params(parargs)
		else
			posparams = pos_functions[poscat].params
		end
		for key, val in pairs(posparams) do
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
		sort_key = args["sort"],
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

	if params.mut then
		local mutable
		if args.mut then
			mutable = true
		elseif args.nomut then
			mutable = false
		else
			local head = m_links.remove_links(data.heads[1] or PAGENAME)
			local mutdata = require("Module:cy-mut").get_mutation_data(head)
			if not mutdata.mut1 and not mutdata.mut2 and not mutdata.mut3 then
				mutable = false
			end
		end

		if mutable == false then
			table.insert(data.inflections, {label = "not mutable"})
			table.insert(data.categories, langname .. " non-mutable terms")
		end
	end

	for _, inflection_set in ipairs(data.inflections) do
		for _, inflection in ipairs(inflection_set) do
			if not inflection:find("%[%[") then
				local title = mw.title.new(inflection)
				if title and not title.exists then
					table.insert(tracking_categories, langname .. " " .. poscat .. " with red links in their headword lines")
				end
			end
		end
	end

	return require("Module:headword").full_headword(data)
		.. require("Module:utilities").format_categories(tracking_categories, lang)
end

pos_functions["verbs"] = {
	params = {
		[1] = {list = "stem"},
		["1s"] = {list = true},
		["irr"] = {type = "boolean"},
		["nomut"] = {type = "boolean"},
		["mut"] = {type = "boolean"},
	},
	func = function(args, data, tracking_categories)
		if #args["1s"] == 0 then
			args["1s"] = {"+"}
		end
		local first_singular = {}
		for _, arg1s in ipairs(args["1s"]) do
			if arg1s == "+" then
				local stems = args[1]
				if #stems == 0 and #data.heads > 0 then
					stems = {}
					for _, head in ipairs(data.heads) do
						m_table.insertIfNot(stems, m_links.remove_links(head))
					end
				end
				if #stems == 0 then
					stems = {PAGENAME}
				end
				for _, stem in ipairs(stems) do
					m_table.insertIfNot(first_singular, stem .. "af")
				end
			else
				m_table.insertIfNot(first_singular, arg1s)
			end
		end
		first_singular.label = "first-person singular present"
		first_singular.accel = {form = "1|s|pres:ind//fut"}
		table.insert(data.inflections, first_singular)
		if args.irr then
			table.insert(data.categories, langname .. " irregular verbs")
		end
	end
}
	
pos_functions["adjectives"] = {
	params = {
		["f"] = {list = true},
		["pl"] = {list = true},
		[1] = {},
		["eq"] = {list = true},
		["comp"] = {list = true},
		["sup"] = {list = true},
		["stem"] = {list = true},
		["nomut"] = {type = "boolean"},
		["mut"] = {type = "boolean"},
	},
	func = function(args, data, tracking_categories)
		if #args.f == 0 then
			args.f = mw.clone(data.heads)
		end
		if #args.f == 0 then
			args.f = {PAGENAME}
		end
		args.f.label = "feminine singular"
		args.f.accel = {form = "f|s"}
		table.insert(data.inflections, args.f)

		if #args.pl == 0 then
			args.pl = mw.clone(data.heads)
		end
		if #args.pl == 0 then
			args.pl = {PAGENAME}
		end
		args.pl.label = "plural"
		args.pl.accel = {form = "p"}
		table.insert(data.inflections, args.pl)

		local eqs, comps, sups
		if args[1] == "-" then
			table.insert(data.inflections, {label = "not " .. glossary_link("comparable")})
			table.insert(data.categories, langname .. " uncomparable adjectives")
		else
			local function copy_heads_with_prefix(source, prefix, mutate_head)
				local dest = {}
				local heads = source
				local can_mutate = false
				if #heads == 0 then
					heads = data.heads
					can_mutate = true
				end
				if #heads == 0 then
					heads = {PAGENAME}
					can_mutate = true
				end
				for _, head in ipairs(heads) do
					if not head:find("%[%[") then
						if can_mutate and mutate_head then
							head = mutate_head(head)
						end
						head = "[[" .. head .. "]]"
					end
					head = prefix .. head
					m_table.insertIfNot(dest, head)
				end
				return dest
			end

			local function copy_heads_with_suffix(source, suffix)
				if #source > 0 then
					return source
				end
				local dest = {}
				local heads = args.stem
				if #heads == 0 then
					heads = data.heads
				end
				if #heads == 0 then
					heads = {PAGENAME}
				end
				for _, head in ipairs(heads) do
					head = m_links.remove_links(head) .. suffix
					m_table.insertIfNot(dest, head)
				end
				return dest
			end

			local function mutate_equative(form)
				local mutdata = require("Module:cy-mut").get_mutation_data(form)
				if mutdata.mut1 and mutdata.initial ~= "ll" and mutdata.initial ~= "rh" then
					return mutdata.mut1 .. mutdata.final
				else
					return form
				end
			end

			if args[1] == "mwy" then
				eqs = copy_heads_with_prefix(args.eq, "mor ", mutate_equative)
				comps = copy_heads_with_prefix(args.comp, "mwy ")
				sups = copy_heads_with_prefix(args.sup, "mwyaf ")
			elseif args[1] == "ach" then
				eqs = copy_heads_with_suffix(args.eq, "ed")
				comps = copy_heads_with_suffix(args.comp, "ach")
				sups = copy_heads_with_suffix(args.sup, "af")
			else
				table.insert(data.inflections, {label = '<span style="color: #ff0000;">unknown comparative</span>'})
				table.insert(data.categories, "Requests for inflections in " .. langname .. " adjective entries")
			end
		end

		if eqs then
			eqs.label = glossary_link("equative")
			-- don't add accelerator for multiword equative, or the mutated portion of the
			-- equative will end up with an accelerated entry
			if args[1] == "ach" then
				eqs.accel = {form = "equative"}
			end
			table.insert(data.inflections, eqs)
		end
		if comps then
			comps.label = glossary_link("comparative")
			if args[1] == "ach" then
				comps.accel = {form = "comparative"}
			end
			table.insert(data.inflections, comps)
		end
		if sups then
			sups.label = glossary_link("superlative")
			if args[1] == "ach" then
				sups.accel = {form = "superlative"}
			end
			table.insert(data.inflections, sups)
		end
	end
}

local allowed_genders = {
	["m"] = true,
	["f"] = true,
	["mf"] = true,
	["mfbysense"] = true,
	["m-p"] = true,
	["f-p"] = true,
	["mf-p"] = true,
	["mfbysense-p"] = true,
}

local function noun_params(args)
	local params = {
		[1] = {alias_of = "g"},
		["g"] = {list = true}, --gender(s)
		["f"] = {list = true}, --feminine form(s)
		["m"] = {list = true}, --masculine form(s)
		["dim"] = {list = true}, --diminutive(s)
		["nomut"] = {type = "boolean"},
		["mut"] = {type = "boolean"},
	}
	if args[1] and args[1]:find("%-p$") then
		params[2] = {alias_of = "sg"}
		params["sg"] = {list = true}
	else
		params[2] = {alias_of = "pl"}
		params["pl"] = {list = true}
	end
	return params
end

local function do_nouns(pos, args, data, tracking_categories)
	local genders = {}
	for _, g in ipairs(args.g) do
		if not allowed_genders[g] then
			error("Unrecognized gender: " .. g)
		end
		if g == "c" or g == "mf" then
			table.insert(genders, "m")
			table.insert(genders, "f")
		else
			table.insert(genders, g)
		end
	end

	local plpos = require("Module:string utilities").pluralize(pos)

	if #genders > 0 then
		data.genders = genders
		if #genders > 1 then
			table.insert(data.categories, langname .. " " .. plpos .. " with multiple genders")
		end
	else
		data.genders = {"?"}
		table.insert(data.categories, "Requests for gender in " .. langname .. " entries")
	end
	
	-- Check for special plural signals
	local mode = nil

	if args.pl then
		-- not a plurale tantum
		if args.pl[1] == "?" or args.pl[1] == "!" or args.pl[1] == "-" or args.pl[1] == "~" or args.pl[1] == "#" then
			mode = args.pl[1]
			table.remove(args.pl, 1)  -- Remove the mode parameter
		end
		
		local countable, uncountable
		if mode == "?" then
			-- Plural is unknown
			table.insert(data.categories, langname .. " " .. plpos .. " with unknown or uncertain plurals")
		elseif mode == "!" then
			-- Plural is not attested
			table.insert(data.inflections, {label = "plural not attested"})
			table.insert(data.categories, langname .. " " .. plpos .. " with unattested plurals")
			return
		elseif mode == "-" then
			-- Uncountable noun; may occasionally have a plural
			uncountable = true
			-- If plural forms were given explicitly, then show "usually"
			if #args.pl > 0 then
				table.insert(data.inflections, {label = "usually " .. glossary_link("uncountable")})
				countable = true
			else
				table.insert(data.inflections, {label = glossary_link("uncountable")})
			end
		elseif mode == "~" then
			-- Mixed countable/uncountable noun, always has a plural
			table.insert(data.inflections, {label = glossary_link("countable") .. " and " .. glossary_link("uncountable")})
			uncountable = true
			countable = true
		elseif mode == "#" or pos == "noun" then
			-- Countable nouns; the default for regular nouns but not proper nouns
			if mode == "#" then
				table.insert(data.inflections, {label = glossary_link("countable")})
			end
			countable = true
		end

		if countable then
			table.insert(data.categories, langname .. " countable " .. plpos)
		end
		if uncountable and pos == "noun" then
			table.insert(data.categories, langname .. " uncountable " .. plpos)
		end

		if #args.pl > 0 then
			local plurals = {}

			for _, pl in ipairs(args.pl) do
				if pl == "au" then
					local heads = data.heads
					if #heads == 0 then
						heads = {PAGENAME}
					end
					for _, head in ipairs(heads) do
						head = m_links.remove_links(head) .. "au"
						m_table.insertIfNot(plurals, head)
					end
				else
					m_table.insertIfNot(plurals, pl)
				end
			end
		
			plurals.label = "plural"
			plurals.accel = {form = "p"}
			table.insert(data.inflections, plurals)
		end
	end

	if args.sg then
		if args.sg[1] == "-" then
			table.insert(data.inflections, {label = "no " .. glossary_link("singulative")})
		elseif #args.sg > 0 then
			args.sg.label = glossary_link("singulative")
			args.sg.accel = {form = "singulative"}
			table.insert(data.inflections, args.sg)
		end
	end

	if #args.f > 0 then
		args.f.label = "feminine"
		table.insert(data.inflections, args.f)
	end

	if #args.m > 0 then
		args.m.label = "masculine"
		table.insert(data.inflections, args.m)
	end

	if #args.dim > 0 then
		args.dim.label = glossary_link("diminutive")
		table.insert(data.inflections, args.dim)
	end
end

pos_functions["nouns"] = {
	params = noun_params,
	func = function(args, data, tracking_categories)
		return do_nouns("noun", args, data, tracking_categories)
	end,
}

pos_functions["proper nouns"] = {
	params = noun_params,
	func = function(args, data, tracking_categories)
		return do_nouns("proper noun", args, data, tracking_categories)
	end,
}

local function pos_with_gender()
	return {
		params = {
			["g"] = {list = true},
			["nomut"] = {type = "boolean"},
			["mut"] = {type = "boolean"},
		},
		func = function(args, data)
			data.genders = args["g"]
		end,
	}
end

pos_functions.numerals = pos_with_gender()
pos_functions["adjective forms"] = pos_with_gender()
pos_functions["determiner forms"] = pos_with_gender()
pos_functions["noun forms"] = pos_with_gender()
pos_functions["noun plural forms"] = pos_with_gender()
pos_functions["numeral forms"] = pos_with_gender()
pos_functions["pronoun forms"] = pos_with_gender()
pos_functions["singulatives"] = pos_with_gender()
pos_functions["verb forms"] = pos_with_gender()

return export
