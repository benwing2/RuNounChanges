local export = {}
local pos_functions = {}
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsubn = mw.ustring.gsub
local rsplit = mw.text.split

local lang = require("Module:languages").getByCode("fr")
local langname = lang:getCanonicalName()

local suffix_categories = {
	["adjectives"] = true,
	["adverbs"] = true,
	["nouns"] = true,
	["verbs"] = true,
	["prepositional phrases"] = true,
}

local prepositions = {
	"à ",
	"aux? ",
	"d[eu] ",
	"d['’]",
	"des ",
	"en ",
	"sous ",
	"sur ",
	"avec ",
	"pour ",
	"par ",
	"dans ",
	"contre ",
	"sans ",
	"comme ",
	"jusqu['’]",
	-- We could list others but you get diminishing returns
}

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

local function track(page)
	require("Module:debug").track("fr-headword/" .. page)
	return true
end

local function glossary_link(entry, text)
	text = text or entry
	return "[[Appendix:Glossary#" .. entry .. "|" .. text .. "]]"
end

-- mw.title.new() returns nil if there are weird chars in the pagename.
local function exists(pagename)
	local title = mw.title.new(pagename)
	return title and title.exists
end

local function check_exists(forms, cats, pos)
	for _, form in ipairs(forms) do
		if type(form) == "table" then
			form = form.term
		end
		if not exists(form) then
			table.insert(cats, langname .. " " .. pos .. " with red links in their headword lines")
			return false
		end
	end
	return true
end

local function make_plural(form, special)
	local retval = require("Module:romance utilities").handle_multiword(form, special, make_plural, prepositions)
	if retval then
		if #retval > 1 then
			error("Internal error: Got multiple plurals from handle_multiword(): " .. table.concat(retval))
		end
		return retval[1]
	end

	if rfind(form, "[sxz]$") then
		return form
	elseif rfind(form, "au$") then
		return form .. "x"
	elseif rfind(form, "al$") then
		return rsub(form, "al$", "aux")
	else
		return form .. "s"
	end
end

local function make_feminine(form, special)
	local retval = require("Module:romance utilities").handle_multiword(form, special, make_feminine, prepositions)
	if retval then
		if #retval > 1 then
			error("Internal error: Got multiple feminines from handle_multiword(): " .. table.concat(retval))
		end
		return retval[1]
	end

	if rfind(form, "e$") then
		return form
	elseif rfind(form, "en$") then
		return form .. "ne"
	elseif rfind(form, "er$") then
		return rsub(form, "er$", "ère")
	elseif rfind(form, "el$") then
		return form .. "le"
	elseif rfind(form, "et$") then
		return form .. "te"
	elseif rfind(form, "on$") then
		return form .. "ne"
	elseif rfind(form, "ieur$") then
		return form .. "e"
	elseif rfind(form, "teur$") then
		return rsub(form, "teur$", "trice")
	elseif rfind(form, "eu[rx]$") then
		return rsub(form, "eu[rx]$", "euse")
	elseif rfind(form, "if$") then
		return rsub(form, "if$", "ive")
	elseif rfind(form, "c$") then
		return rsub(form, "c$", "que")
	elseif rfind(form, "eau$") then
		return rsub(form, "eau$", "elle")
	else
		return form .. "e"
	end
end

-- For bot use
function export.make_feminine(frame)
	local masc = frame.args[1] or error("Masculine in 1= is required.")
	local special = frame.args[2]
	return make_feminine(masc, special)
end


local function add_suffix(list, suffix, special)
	local newlist = {}
	for _, form in ipairs(list) do
		if suffix == "s" then
			form = make_plural(form, special)
		elseif suffix == "e" then
			form = make_feminine(form, special)
		else
			error("Internal error: Unrecognized suffix '" .. suffix .. "'")
		end
		table.insert(newlist, form)
	end
	return newlist
end


local no_split_apostrophe_words = {
	["c'est"] = true,
	["quelqu'un"] = true,
	["aujourd'hui"] = true,
}


-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	local poscat = frame.args[1] or error("Part of speech has not been specified. Please pass parameter 1 to the module invocation.")

	local params = {
		["head"] = {list = true},
		["splithyph"] = {type = "boolean"},
		["nolinkhead"] = {type = "boolean"},
		["pagename"] = {}, -- for testing
	}

	if pos_functions[poscat] then
		for key, val in pairs(pos_functions[poscat].params) do
			params[key] = val
		end
	end

	local parargs = frame:getParent().args
	local args = require("Module:parameters").process(parargs, params)

	local pagename = args.pagename or mw.title.getCurrentTitle().text

	local heads = args["head"]
	if pos_functions[poscat] and pos_functions[poscat].param1_is_head and args[1] then
		table.insert(heads, 1, args[1])
	end
	if args.nolinkhead then
		if #heads == 0 then
			heads = {pagename}
		end
	else
		local auto_linked_head = require("Module:romance utilities").add_lemma_links(pagename, args.splithyph,
			no_split_apostrophe_words)
		if #heads == 0 then
			heads = {auto_linked_head}
		else
			for _, head in ipairs(heads) do
				if head == auto_linked_head then
					track("redundant-head")
				end
			end
		end
	end

	local data = {
		lang = lang,
		pos_category = poscat,
		categories = {},
		heads = heads,
		no_redundant_head_cat = #args.head == 0,
		genders = {},
		inflections = {},
		categories = {},
		pagename = pagename
	}

	if pagename:find("^%-") and suffix_categories[poscat] then
		data.pos_category = "suffixes"
		local singular_poscat = poscat:gsub("s$", "")
		table.insert(data.categories, langname .. " " .. singular_poscat .. "-forming suffixes")
	end

	if pos_functions[poscat] then
		pos_functions[poscat].func(args, data)
	end

	return require("Module:headword").full_headword(data)
end

local allowed_genders = {
	["m"] = true,
	["f"] = true,
	["mf"] = true,
	["mfbysense"] = true,
	["mfequiv"] = true,
	["gneut"] = true,
	["m-p"] = true,
	["f-p"] = true,
	["mf-p"] = true,
	["mfbysense-p"] = true,
	["mfequiv-p"] = true,
	["gneut-p"] = true,
}

local additional_allowed_pronoun_genders = {
	["m-s"] = true,
	["f-s"] = true,
	["mf-s"] = true,
	["p"] = true, -- mf-p doesn't make sense for e.g. [[iels]]/[[ielles]]
}

local function get_noun_pos(pos)
	return {
		params = {
			[1] = {},
			["g"] = {list = true},
			[2] = {list = true},
			["pqual"] = {list = true, allow_holes = true},
			["f"] = {list = true},
			["fqual"] = {list = true, allow_holes = true},
			["m"] = {list = true},
			["mqual"] = {list = true, allow_holes = true},
			["dim"] = {list = true},
			["dimqual"] = {list = true, allow_holes = true},
			},
		func = function(args, data)
			local lemma = data.pagename
			local is_proper = pos == "proper nouns"

			if pos == "cardinal nouns" then
				pos = "numerals"
				data.pos_category = "numerals"
				table.insert(data.categories, 1, langname .. " cardinal numbers")
			end

			-- Gather genders
			table.insert(data.genders, args[1])
			for _, g in ipairs(args.g) do
				table.insert(data.genders, g)
			end

			local function process_inflection(label, infls, quals)
				infls.label = label
				for i, infl in ipairs(infls) do
					if quals[i] then
						infls[i] = {term = infl, q = {quals[i]}}
					end
				end
			end

			-- Gather all the plural parameters from the numbered parameters.
			local plurals = args[2]

			-- Add categories for genders
			if #data.genders == 0 then
				table.insert(data.genders, "?")
			end

			local mode = nil

			for _, g in ipairs(data.genders) do
				if g == "m-p" or g == "f-p" or g =="mf-p" or g == "mfbysense-p" then
					mode = "p"
				end

				if g == "?" and (is_proper or mw.title.getCurrentTitle().nsText == "Template") then
					-- allow unknown gender in template example and proper nouns,
					-- since there are currently so many proper nouns with
					-- unspecified gender
				elseif g and g ~= "" and not allowed_genders[g] then
					error("Unrecognized " .. langname .. " gender: " .. g)
				end
			end

			-- Decide how to show the plurals
			mode = mode or plurals[1]

			local function insert_countable_cat()
				table.insert(data.categories, langname .. " countable " .. pos)
			end
			local function insert_uncountable_cat()
				-- Most proper nouns are uncountable, so don't create a category for them
				if not is_proper then
					table.insert(data.categories, langname .. " uncountable " .. pos)
				end
			end
				
			if mode == "!" then
				-- Plural is not attested
				table.insert(data.inflections, {label = "plural not attested"})
				table.insert(data.categories, langname .. " " .. pos .. " with unattested plurals")
			elseif mode == "p" then
				-- Plural-only noun, doesn't have a plural
				table.insert(data.inflections, {label = "plural only"})
				table.insert(data.categories, langname .. " pluralia tantum")
			else
				if mode == "?" then
					-- Plural is unknown
					table.remove(plurals, 1)  -- Remove the mode parameter
				elseif mode == "-" then
					-- Uncountable noun; may occasionally have a plural
					table.remove(plurals, 1)  -- Remove the mode parameter
					insert_uncountable_cat()

					-- If plural forms were given explicitly, then show "usually"
					if #plurals > 0 then
						track("count-uncount")
						table.insert(data.inflections, {label = "usually " .. glossary_link("uncountable")})
						insert_countable_cat()
					else
						table.insert(data.inflections, {label = glossary_link("uncountable")})
					end
				elseif mode == "~" then
					-- Mixed countable/uncountable noun, always has a plural
					table.remove(plurals, 1)  -- Remove the mode parameter
					table.insert(data.inflections, {label = glossary_link("countable") .. " and " .. glossary_link("uncountable")})
					insert_uncountable_cat()
					insert_countable_cat()

					-- If no plural was given, add a default one now
					if #plurals == 0 then
						plurals = {"+"}
					end
				elseif is_proper then
					-- Default proper noun; uncountable unless plural(s) specified
					if #plurals > 0 then
						insert_countable_cat()
					else
						insert_uncountable_cat()
					end
				else
					-- The default, always has a plural
					insert_countable_cat()

					-- If no plural was given, add a default one now
					if #plurals == 0 then
						plurals = {"+"}
					end
				end

				-- Gather plurals, handling requests for default plurals
				for i, pl in ipairs(plurals) do
					if pl == "#" then
						pl = lemma
					elseif pl == "s" or pl == "x" then
						pl = lemma .. pl
					elseif pl == "+" then
						pl = make_plural(lemma)
					elseif pl:find("^%+") then
						pl = require("Module:romance utilities").get_special_indicator(pl)
						pl = make_plural(lemma, pl)
					end

					if not exists(pl) then
						table.insert(data.categories, langname .. " " .. pos .. " with red links in their headword lines")
					end

					plurals[i] = pl
				end

				process_inflection("plural", plurals, args["pqual"])
				plurals.accel = {form = "p"}
				plurals.request = true

				-- Add the plural forms; do this in some cases even if no plurals
				-- specified so we get a "please provide plural" message.
				if mode ~= "-" and (not is_proper or mode) or #plurals > 0 then
					table.insert(data.inflections, plurals)
				end
			end

			local function insert_inflection(label, arg, process_arg)
				local forms = args[arg]
				if process_arg then
					for i, form in ipairs(forms) do
						forms[i] = process_arg(form)
					end
				end
				process_inflection(label, forms, args[arg .. "qual"])
				if #forms > 0 then
					table.insert(data.inflections, forms)
					check_exists(forms, data.categories, pos)
				end
				return forms
			end

			-- Add the feminine forms
			local fems = insert_inflection("feminine", "f", function(form)
				-- Allow '#', 'e', '+', '+first', etc. for feminine.
				if form == "#" then
					return lemma
				elseif form == "e" then
					return lemma .. form
				elseif form == "+" then
					return make_feminine(lemma)
				elseif form:find("^%+") then
					form = require("Module:romance utilities").get_special_indicator(form)
					return make_feminine(lemma, form)
				else
					return form
				end
			end)
			fems.accel = {form = "f"}

			-- Add the masculine forms
			insert_inflection("masculine", "m")

			-- Add the diminutives
			local dims = insert_inflection("diminutive", "dim")
			dims.accel = {form = "diminutive"}
		end
	}
end

for _, noun_pos in ipairs { "nouns", "proper nouns", "cardinal nouns" } do
	pos_functions[noun_pos] = get_noun_pos(noun_pos)
end

local function get_pronoun_pos()
	return {
		params = {
			["head"] = {list = true},
			[1] = {alias_of = "g"},
			["g"] = {list = true},
			["f"] = {list = true},
			["fqual"] = {list = true, allow_holes = true},
			["m"] = {list = true},
			["mqual"] = {list = true, allow_holes = true},
			["mv"] = {list = true},
			["mvqual"] = {list = true, allow_holes = true},
			["fp"] = {list = true},
			["fpqual"] = {list = true, allow_holes = true},
			["mp"] = {list = true},
			["mpqual"] = {list = true, allow_holes = true},
			["p"] = {list = true},
			["pqual"] = {list = true, allow_holes = true},
			["type"] = {list = true},
			},
		func = function(args, data)
			-- Gather genders
			data.genders = args.g

			local function process_inflection(label, infls, quals)
				infls.label = label
				for i, infl in ipairs(infls) do
					if quals[i] then
						infls[i] = {term = infl, q = {quals[i]}}
					end
				end
			end

			local function insert_inflection()
			end

			-- Validate/canonicalize genders
			for i, g in ipairs(data.genders) do
				if g == "?" and mw.title.getCurrentTitle().nsText == "Template" then
					-- allow unknown gender in template example
				elseif g == "?" then
					-- FIXME, remove this branch once we’ve added the required genders
					track("missing-pron-gender")
				elseif g and not allowed_genders[g] and not additional_allowed_pronoun_genders[g] then
					error("Unrecognized " .. langname .. " gender: " .. g)
				end
			end

			-- Gather all inflections.
			process_inflection("masculine", args["m"], args["mqual"])
			process_inflection("masculine singular before vowel", args["mv"], args["mvqual"])
			process_inflection("feminine", args["f"], args["fqual"])
			process_inflection("masculine plural", args["mp"], args["mpqual"])
			process_inflection("feminine plural", args["fp"], args["fpqual"])
			process_inflection("plural", args["p"], args["pqual"])

			-- Add the inflections
			if #args["m"] > 0 then
				table.insert(data.inflections, args["m"])
			end
			if #args["f"] > 0 then
				table.insert(data.inflections, args["f"])
			end
			if #args["mp"] > 0 then
				table.insert(data.inflections, args["mp"])
			end
			if #args["fp"] > 0 then
				table.insert(data.inflections, args["fp"])
			end
			if #args["p"] > 0 then
				table.insert(data.inflections, args["p"])
			end
			
			-- Categorize by "type"
			local pos = "pronouns"
			for _, ty in ipairs(args.type) do
				local category, label
				if ty == "indefinite" then
					category = "indefinite"
				elseif ty == "interrogative" then
					category = "interrogative"
				elseif ty == "personal" then
					category = "personal"
				elseif ty == "possessive" then
					category = "possessive"
				elseif ty == "reflexive" then
					category = "reflexive"
				elseif ty == "relative" then
					category = "relative"
				end
				if category then
					if type(category) == "table" then
						for _, cat in ipairs(category) do
							table.insert(data.categories, langname .. " " .. cat .. " " .. pos)
						end
					else
						table.insert(data.categories, langname .. " " .. category .. " " .. pos)
					end
				end
			end
		end
	}
end

pos_functions["pronouns"] = get_pronoun_pos(true)
pos_functions["determiners"] = get_pronoun_pos(true)

local function get_misc_pos()
	return {
		param1_is_head = true,
		params = {
			[1] = {},
		},
		func = function(args, data)
		end
	}
end

pos_functions["adverbs"] = get_misc_pos()

pos_functions["prepositions"] = get_misc_pos()

pos_functions["phrases"] = get_misc_pos()

pos_functions["prepositional phrases"] = get_misc_pos()

pos_functions["proverbs"] = get_misc_pos()

pos_functions["punctuation marks"] = get_misc_pos()

pos_functions["diacritical marks"] = get_misc_pos()

pos_functions["interjections"] = get_misc_pos()

pos_functions["prefixes"] = get_misc_pos()

pos_functions["abbreviations"] = get_misc_pos()

local function do_adjective(pos)
	return {
		params = {
			[1] = {},
			["inv"] = {type = "boolean"},
			["sp"] = {}, -- special indicator: "first", "first-last", etc.
			["onlyg"] = {},
			["m"] = {list = true},
			["mqual"] = {list = true},
			["mv"] = {list = true},
			["mvqual"] = {list = true},
			["f"] = {list = true},
			["fqual"] = {list = true},
			["mp"] = {list = true},
			["mpqual"] = {list = true},
			["fp"] = {list = true},
			["fpqual"] = {list = true},
			["p"] = {list = true},
			["pqual"] = {list = true},
			["current"] = {list = true},
			["comp"] = {list = true},
			["compqual"] = {list = true},
			["sup"] = {list = true},
			["supqual"] = {list = true},
			["intr"] = {type = "boolean"},
			},
		func = function(args, data)
			local lemma = data.pagename
			if pos == "cardinal adjectives" then
				pos = "numerals"
				data.pos_category = "numerals"
				table.insert(data.categories, 1, langname .. " cardinal numbers")
			end

			if pos ~= "numerals" then
				if args.onlyg == "p" or args.onlyg == "m-p" or args.onlyg == "f-p" then
					table.insert(data.categories, langname .. " pluralia tantum")
				end
				if args.onlyg == "s" or args.onlyg == "f-s" or args.onlyg == "f-s" then
					table.insert(data.categories, langname .. " singularia tantum")
				end
				if args.onlyg then
					table.insert(data.categories, langname .. " defective " .. pos)
				end
			end

			local function process_inflection(label, arg, accel, get_default, explicit_default_only)
				local default_val
				local function default()
					if default_val == nil then
						if get_default then
							default_val = get_default()
						else
							default_val = false
						end
					end
					return default_val
				end
				local orig_infls = #args[arg] > 0 and args[arg] or explicit_default_only and {} or default() or {}
				local infls = {}
				if #orig_infls > 0 then
					infls.label = label
					infls.accel = accel and {form = accel} or nil
					local quals = args[arg .. "qual"]
					for i, infl in ipairs(orig_infls) do
						if infl == "#" then
							infl = lemma
						elseif infl == "e" or infl == "s" or infl == "x" then
							infl = lemma .. infl
						elseif infl == "+" then
							infl = default()
							if not infl then
								error("Can't use '+' with " .. arg .. "=; no default available")
							end
						end
						if type(infl) == "table" then
							for _, inf in ipairs(infl) do
								if quals[i] then
									table.insert(infls, {term = inf, q = {quals[i]}})
								else
									table.insert(infls, inf)
								end
							end
						elseif quals[i] then
							table.insert(infls, {term = infl, q = {quals[i]}})
						else
							table.insert(infls, infl)
						end
					end
					table.insert(data.inflections, infls)
				end
				return infls
			end

			if args.sp and not require("Module:romance utilities").allowed_special_indicators[args.sp] then
				local indicators = {}
				for indic, _ in pairs(require("Module:romance utilities").allowed_special_indicators) do
					table.insert(indicators, "'" .. indic .. "'")
				end
				table.sort(indicators)
				error("Special inflection indicator beginning can only be " ..
					require("Module:table").serialCommaJoin(indicators, {dontTag = true}) .. ": " .. args.sp)
			end

			local function get_current()
				return #args.current > 0 and args.current or {data.pagename}
			end

			if args.onlyg == "p" then
				table.insert(data.inflections, {label = "plural only"})
				if args[1] ~= "mf" then
					-- Handle feminine plurals
					process_inflection("feminine plural", "fp", "f|p")
				end
			elseif args.onlyg == "s" then
				table.insert(data.inflections, {label = "singular only"})
				if not (args[1] == "mf" or #args.f == 0 and rfind(data.pagename, "e$")) then
					-- Handle feminines
					process_inflection("feminine singular", "f", "f", function()
						return add_suffix(get_current(), "e", args.sp)
					end)
				end
			elseif args.onlyg == "m" then
				table.insert(data.genders, "m")
				table.insert(data.inflections, {label = "masculine only"})
				-- Handle masculine plurals
				process_inflection("masculine plural", "mp", "m|p", function()
					return add_suffix(get_current(), "s", args.sp)
				end)
			elseif args.onlyg == "f" then
				table.insert(data.genders, "f")
				table.insert(data.inflections, {label = "feminine only"})
				-- Handle feminine plurals
				process_inflection("feminine plural", "fp", "f|p", function()
					return add_suffix(get_current(), "s", args.sp)
				end)
			elseif args.onlyg then
				table.insert(data.genders, args.onlyg)
				table.insert(data.inflections, {label = "defective"})
			else
				-- Gather genders
				local gender = args[1]
				-- Default to mf if base form ends in -e and no feminine,
				-- feminine plural or gender specified
				if not gender and #args.f == 0 and #args.fp == 0 and rfind(data.pagename, "e$")
					and not rfind(data.pagename, " ") then
					gender = "mf"
				end

				if #args.current > 0 then
					track("adj-current")
				end

				if args.intr then
					table.insert(data.inflections, {label = glossary_link("intransitive")})
					table.insert(data.inflections, {label = "hence " .. glossary_link("invariable")})
					args.inv = true
				elseif args.inv then
					table.insert(data.inflections, {label = glossary_link("invariable")})
				end

				-- Handle plurals of mf adjectives
				if not args.inv and gender == "mf" then
					process_inflection("plural", "p", "p", function()
						return add_suffix(get_current(), "s", args.sp)
					end)
				end

				if not args.inv and gender ~= "mf" then
					-- Handle masculine form if not same as lemma; e.g. [[sûr de soi]] with m=+, m2=sûr de lui
					process_inflection("masculine singular", "m", "m|s",
						function() return {data.pagename} end, "explicit default only")

					-- Handle case of special masculine singular before vowel
					process_inflection("masculine singular before vowel", "mv", "m|s")

					-- Handle feminines
					local feminines = process_inflection("feminine", "f", "f|s", function()
						return add_suffix(get_current(), "e", args.sp)
					end)

					-- Handle masculine plurals
					process_inflection("masculine plural", "mp", "m|p", function()
						return add_suffix(get_current(), "s", args.sp)
					end)

					-- Handle feminine plurals
					process_inflection("feminine plural", "fp", "f|p", function()
						return add_suffix(feminines, "s", args.sp)
					end)
				end
			end

			-- Handle comparatives
			process_inflection("comparative", "comp", "comparative")

			-- Handle superlatives
			process_inflection("superlative", "sup", "superlative")

			-- Check existence
			for _, infls in pairs(data.inflections) do
				if not check_exists(infls, data.categories, pos) then
					break
				end
			end
		end
	}
end

pos_functions["adjectives"] = do_adjective("adjectives")
pos_functions["past participles"] = do_adjective("participles")
pos_functions["cardinal adjectives"] = do_adjective("cardinal adjectives")

pos_functions["verbs"] = {
	param1_is_head = true,
	params = {
		[1] = {},
		["type"] = {list = true},
	},
	func = function(args, data)
		local pos = "verbs"
		for _, ty in ipairs(args.type) do
			local category, label
			if ty == "auxiliary" then
				category = "auxiliary"
			elseif ty == "defective" then
				category = "defective"
				label = glossary_link("defective")
			elseif ty == "impersonal" then
				category = "impersonal"
				label = glossary_link("impersonal")
			elseif ty == "modal" then
				category = "modal"
			elseif ty == "reflexive" then
				category = "reflexive"
			elseif ty == "transitive" then
				label = glossary_link("transitive")
				category = "transitive"
			elseif ty == "intransitive" then
				label = glossary_link("intransitive")
				category = "intransitive"
			elseif ty == "ambitransitive" or ty == "ambi" then
				category = {"transitive", "intransitive"}
				label = glossary_link("transitive") .. " and " .. glossary_link("intransitive")
			end
			if category then
				if type(category) == "table" then
					for _, cat in ipairs(category) do
						table.insert(data.categories, langname .. " " .. cat .. " " .. pos)
					end
				else
					table.insert(data.categories, langname .. " " .. category .. " " .. pos)
				end
			end
			if label then
				table.insert(data.inflections, {label = label})
			end
		end
	end
}

pos_functions["cardinal invariable"] = {
	params = {},
	func = function(args, data)
		data.pos_category = "numerals"
		table.insert(data.categories, langname .. " cardinal numbers")
		table.insert(data.categories, langname .. " indeclinable numerals")
		table.insert(data.inflections, {label = glossary_link("invariable")})
	end
}

return export
