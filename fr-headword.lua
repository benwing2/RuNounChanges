local export = {}
local pos_functions = {}
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsubn = mw.ustring.gsub
local rsplit = mw.text.split

local lang = require("Module:languages").getByCode("fr")

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

-- mw.title.new() returns nil if there are weird chars in
-- the pagename.
local function exists(pagename)
	local title = mw.title.new(pagename)
	return title and title.exists
end

local function make_plural(form, special)
	local retval = require("Module:romance utilities").handle_multiword(form, special, make_plural, prepositions)
	if retval then
		return retval
	end

	if rfind(form, "[sx]$") then
		return form
	elseif rfind(rorm, "al$") then
		return rsub(item, "al$", "aux")
	else
		return form .. "s"
	end
end

local function make_feminine(form, special)
	local retval = require("Module:romance utilities").handle_multiword(form, special, make_plural, prepositions)
	if retval then
		return retval
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
	else
		return form .. "e"
	end
end


local function add_suffix(list, suffix, special)
	local newlist = {}
	for _, item in ipairs(list) do
		local form
		if suffix == "s" then
			form = make_plural(form, special)
		elseif suffix == "e" then
			form = make_feminine(form, special)
		else
			form = item .. suffix
		end
		table.insert(newlist, form)
	end
	return newlist
end

local no_split_words = {
	["c'est"] = true,
	["quelqu'un"] = true,
	["aujourd'hui"] = true,
}

-- Auto-add links to a “space word” (after splitting on spaces). We split off
-- final punctuation, and then split on hyphens if split_dash is given, and
-- also split on apostrophes, including the apostrophe in the link to its left
-- (so we auto-split “l’eau” as “[[l']][[eau]]”).
local function add_space_word_links(space_word, split_dash)
	local space_word_no_punct, punct = rmatch(space_word, "^(.*)([,;:?!])$")
	space_word_no_punct = space_word_no_punct or space_word
	punct = punct or ""
	local words
	-- don’t split prefixes and suffixes
	if not split_dash or rfind(space_word_no_punct, "^%-") or rfind(space_word_no_punct, "%-$") then
		words = {space_word_no_punct}
	else
		words = rsplit(space_word_no_punct, "%-")
	end
	local linked_words = {}
	for _, word in ipairs(words) do
		if not no_split_words[word] and rfind(word, "'") then
			word = rsub(word, "([^']+')", "[[%1]]")
			word = rsub(word, "%]([^%[%]]*)$", "][[%1]]")
		else
			word = "[[" .. word .. "]]"
		end
		table.insert(linked_words, word)
	end
	return table.concat(linked_words, "-") .. punct
end

-- Auto-add links to a lemma. We split on spaces, and also on hyphens
-- if split_dash is given or the word has no spaces. In addition, we split
-- on apostrophes, including the apostrophe in the link to its left
-- (so we auto-split "de l’eau" as "[[de]] [[l']][[eau]]"). We don’t always
-- split on hyphens because of cases like “boire du petit-lait” where
-- “petit-lait” should be linked as a whole, but provide the option to do it
-- for cases like “croyez-le ou non”. If there’s no space, however, then
-- it makes sense to split on hyphens by default (e.g. for “avant-avant-hier”).
-- Cases where only some of the hyphens should be split can always be handled
-- by explicitly specifying the head (e.g. “Nord-Pas-de-Calais”).
local function add_lemma_links(lemma, split_dash)
	if not rfind(lemma, " ") then
		split_dash = true
	end
	local words = rsplit(lemma, " ")
	local linked_words = {}
	for _, word in ipairs(words) do
		table.insert(linked_words, add_space_word_links(word, split_dash))
	end
	local retval = table.concat(linked_words, " ")
	-- If we ended up with a single link consisting of the entire lemma,
	-- remove the link.
	local unlinked_retval = rmatch(retval, "^%[%[([^%[%]]*)%]%]$")
	return unlinked_retval or retval
end

-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	local PAGENAME = mw.title.getCurrentTitle().text

	local poscat = frame.args[1] or error("Part of speech has not been specified. Please pass parameter 1 to the module invocation.")

	local params = {
		["head"] = {list = true},
		["suff"] = {type = "boolean"},
		["splithyph"] = {type = "boolean"},
		["nolinkhead"] = {type = "boolean"},
	}

	if rfind(PAGENAME, " ") then
		track("space")
	end

	if pos_functions[poscat] then
		for key, val in pairs(pos_functions[poscat].params) do
			params[key] = val
		end
	end

	local parargs = frame:getParent().args
	local args = require("Module:parameters").process(parargs, params)

	local heads = args["head"]
	if pos_functions[poscat] and pos_functions[poscat].param1_is_head and args[1] then
		table.insert(heads, 1, args[1])
	end
	if args.nolinkhead then
		if #heads == 0 then
			heads = {PAGENAME}
		end
	else
		local auto_linked_head = add_lemma_links(PAGENAME, args["splithyph"])
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

	local data = {lang = lang, pos_category = poscat, categories = {}, heads = heads, genders = {}, inflections = {}, categories = {}}

	if args["suff"] then
		data.pos_category = "suffixes"

		if suffix_categories[poscat] then
			local singular_poscat = poscat:gsub("s$", "")
			table.insert(data.categories, lang:getCanonicalName() .. " " .. singular_poscat .. "-forming suffixes")
		else
			error("No category exists for suffixes forming " .. poscat .. ".")
		end
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
	["m-p"] = true,
	["f-p"] = true,
	["mf-p"] = true,
	["mfbysense-p"] = true,
}

local additional_allowed_pronoun_genders = {
	["m-s"] = true,
	["f-s"] = true,
	["mf-s"] = true,
}

local function get_noun_pos(is_proper)
	return {
		params = {
			[1] = {},
			["g"] = {list = true},
			[2] = {list = true},
			["f"] = {list = true},
			["m"] = {list = true},
			["dim"] = {list = true},
			},
		func = function(args, data)
			local PAGENAME = mw.title.getCurrentTitle().text

			local function default_plural()
				if rfind(PAGENAME, 'x$') then
					track("default-x")
				end
				if rfind(PAGENAME, 'z$') then
					track("default-z")
				end
				if rfind(PAGENAME, '[sxz]$') then
					return PAGENAME
				elseif rfind(PAGENAME, '[ae]u$') then
					return "x"
				elseif rfind(PAGENAME, 'al$') then
					return mw.ustring.sub(PAGENAME, 1, -3) .. 'aux'
				else
					return "s"
				end
			end

			-- Gather genders
			table.insert(data.genders, args[1])
			for _, g in ipairs(args.g) do
				table.insert(data.genders, g)
			end

			-- Gather all the plural parameters from the numbered parameters.
			local plurals = args[2]
			plurals.label = "plural"
			plurals.accel = {form = "p"}
			plurals.request = true

			-- Gather all the feminine parameters
			local feminines = args["f"]
			feminines.label = "feminine"

			-- Gather all the masculine parameters
			local masculines = args["m"]
			masculines.label = "masculine"

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
					error("Unrecognized French gender: " .. g)
				end
			end

			-- Decide how to show the plurals
			mode = mode or plurals[1]

			-- Plural is not attested
			if mode == "!" then
				table.insert(data.inflections, {label = "plural not attested"})
				table.insert(data.categories, "French nouns with unattested plurals")
			-- Plural-only noun, doesn't have a plural
			elseif mode == "p" then
				table.insert(data.inflections, {label = "plural only"})
				table.insert(data.categories, "French pluralia tantum")
			else
				-- Plural is unknown
				if mode == "?" then
					table.remove(plurals, 1)  -- Remove the mode parameter
				-- Uncountable noun; may occasionally have a plural
				elseif mode == "-" then
					table.remove(plurals, 1)  -- Remove the mode parameter
					table.insert(data.categories, "French uncountable nouns")

					-- If plural forms were given explicitly, then show "usually"
					if #plurals > 0 then
						track("count-uncount")
						table.insert(data.inflections, {label = "usually [[Appendix:Glossary#uncountable|uncountable]]"})
						table.insert(data.categories, "French countable nouns")
					else
						table.insert(data.inflections, {label = "[[Appendix:Glossary#uncountable|uncountable]]"})
					end
				-- Mixed countable/uncountable noun, always has a plural
				elseif mode == "~" then
					table.remove(plurals, 1)  -- Remove the mode parameter
					table.insert(data.inflections, {label = "[[Appendix:Glossary#countable|countable]] and [[Appendix:Glossary#uncountable|uncountable]]"})
					table.insert(data.categories, "French uncountable nouns")
					table.insert(data.categories, "French countable nouns")

					-- If no plural was given, add a default one now
					if #plurals == 0 then
						table.insert(plurals, default_plural())
					end
				-- Default proper noun; uncountable unless plural(s) specified
				elseif is_proper then
					if #plurals > 0 then
						table.insert(data.categories, "French countable nouns")
					else
						table.insert(data.categories, "French uncountable nouns")
					end
				-- The default, always has a plural
				else
					table.insert(data.categories, "French countable nouns")

					-- If no plural was given, add a default one now
					if #plurals == 0 then
						table.insert(plurals, default_plural())
					end
				end

				-- Process the plural forms
				for i, pl in ipairs(plurals) do
					if pl == "*" then
						pl = PAGENAME
					elseif pl == "s" then
						pl = PAGENAME .. "s"
					elseif pl == "x" then
						pl = PAGENAME .. "x"
					end

					if not exists(pl) then
						table.insert(data.categories, "French nouns with red links in their headword lines")
					end

					plurals[i] = pl
				end

				-- Add the plural forms; do this in some cases even if no plurals
				-- specified so we get a "please provide plural" message.
				if mode ~= "-" and (not is_proper or mode) or #plurals > 0 then
					table.insert(data.inflections, plurals)
				end
			end

			-- Add the feminine forms
			if #feminines > 0 then
				table.insert(data.inflections, feminines)

				for _, f in ipairs(feminines) do
					if not exists(f) then
						table.insert(data.categories, "French nouns with red links in their headword lines")
					end
				end
			end

			-- Add the masculine forms
			if #masculines > 0 then
				table.insert(data.inflections, masculines)

				for _, m in ipairs(masculines) do
					if not exists(m) then
						table.insert(data.categories, "French nouns with red links in their headword lines")
					end
				end
			end

			-- Handle diminutives
			if #args.dim > 0 then
				local dims_infl = mw.clone(args.dim)
				dims_infl.label = "diminutive"
				dims_infl.accel = {form = "diminutive"}
				table.insert(data.inflections, dims_infl)
			end
		end
	}
end

pos_functions["nouns"] = get_noun_pos(false)

pos_functions["proper nouns"] = get_noun_pos(true)

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
			},
		func = function(args, data)
			local PAGENAME = mw.title.getCurrentTitle().text

			-- Gather genders
			data.genders = args.g

			local function process_inflection(label, infls, quals)
				infls.label = label
				for i, infl in ipairs(infls) do
					if quals[i] then
						infls[i] = {term = infl, qualifiers = {quals[i]}}
					end
				end
			end

			-- Gather all inflections.
			process_inflection("masculine", args["m"], args["mqual"])
			process_inflection("masculine singular before vowel", args["mv"], args["mvqual"])
			process_inflection("feminine", args["f"], args["fqual"])
			process_inflection("masculine plural", args["mp"], args["mpqual"])
			process_inflection("feminine plural", args["fp"], args["fpqual"])
			process_inflection("plural", args["p"], args["pqual"])

			-- Add categories for genders
			if #data.genders == 0 then
				table.insert(data.genders, "?")
			end

			-- Validate/canonicalize genders
			for i, g in ipairs(data.genders) do
				if g == "?" and mw.title.getCurrentTitle().nsText == "Template" then
					-- allow unknown gender in template example
				elseif g == "?" then
					-- FIXME, remove this branch once we’ve added the required genders
					track("missing-pron-gender")
				elseif g and g ~= "" and not allowed_genders[g] and not additional_allowed_pronoun_genders[g] then
					error("Unrecognized French gender: " .. g)
				end
			end

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
			["m2"] = {alias_of = "mv"},
			["onlyg"] = {},
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
			local PAGENAME = mw.title.getCurrentTitle().text
			if args.onlyg == "p" or args.onlyg == "m-p" or args.onlyg == "f-p" then
				table.insert(data.categories, "French pluralia tantum")
			end
			if args.onlyg == "s" or args.onlyg == "f-s" or args.onlyg == "f-s" then
				table.insert(data.categories, "French singularia tantum")
			end
			if args.onlyg then
				table.insert(data.categories, "French defective " .. pos)
			end

			local function process_inflection(label, arg, accel, get_default)
				local orig_infls = #args[arg] > 0 and args[arg] or get_default and get_default() or {}
				if #orig_infls > 0 then
					local infls = mw.clone(orig_infls)
					infls.label = label
					infls.accel = accel and {form = accel} or nil
					local quals = args[arg .. "qual"]
					for i, infl in ipairs(infls) do
						if quals[i] then
							infls[i] = {term = infl, qualifiers = {quals[i]}}
						end
					end
					table.insert(data.inflections, infls)
				end
				return orig_infls
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

			if args.onlyg == "p" then
				table.insert(data.inflections, {label = "plural only"})
				if args[1] ~= "mf" then
					-- Handle feminine plurals
					process_inflection("feminine plural", "fp", "f|p")
				end
			elseif args.onlyg == "s" then
				table.insert(data.inflections, {label = "singular only"})
				if not (args[1] == "mf" or #args.f == 0 and rfind(PAGENAME, "e$")) then
					-- Handle feminines
					process_inflection("feminine plural", "fp", "f|p", function()
						return add_suffix(#args.current > 0 and args.current or {PAGENAME}, "e", args.sp)
					end)
				end
			elseif args.onlyg == "m" then
				table.insert(data.genders, "m")
				table.insert(data.inflections, {label = "masculine only"})
				-- Handle masculine plurals
				process_inflection("masculine plural", "mp", "m|p", function()
					return add_suffix(#args.current > 0 and args.current or {PAGENAME}, "s", args.sp)
				end)
			elseif args.onlyg == "f" then
				table.insert(data.genders, "f")
				table.insert(data.inflections, {label = "feminine only"})
				-- Handle feminine plurals
				process_inflection("feminine plural", "fp", "f|p", function()
					return add_suffix(#args.current > 0 and args.current or {PAGENAME}, "s", args.sp)
				end)
			elseif args.onlyg then
				table.insert(data.genders, args.onlyg)
				table.insert(data.inflections, {label = "defective"})
			else
				-- Gather genders
				local gender = args[1]
				-- Default to mf if base form ends in -e and no feminine,
				-- feminine plural or gender specified
				if not gender and #args.f == 0 and #args.fp == 0 and rfind(PAGENAME, "e$") then
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
						return {PAGENAME .. "s"}
					end)
				end

				if not args.inv and gender ~= "mf" then
					-- Handle case of special masculine singular before vowel
					process_inflection("masculine singular before vowel", "mv", "m|s")

					-- Handle feminines
					local feminines = process_inflection("feminine", "f", "f|s",
						function() return add_suffix(#args.current > 0 and args.current or {PAGENAME}, "e", args.sp) end
					)

					-- Handle masculine plurals
					process_inflection("masculine plural", "mp", "m|p",
						function() return add_suffix(#args.current > 0 and args.current or {PAGENAME}, "s", args.sp) end
					)

					-- Handle feminine plurals
					process_inflection("feminine plural", "fp", "f|p",
						function() return add_suffix(feminines, "s", args.sp) end
					)
				end
			end

			-- Handle comparatives
			process_inflection("comparative", "comp", "comparative")

			-- Handle superlatives
			process_inflection("superlative", "sup", "superlative")

			-- Check existence
			for key, val in pairs(data.inflections) do
				for i, form in ipairs(val) do
					if not exists(form) then
						table.insert(data.categories, "French " .. pos .. " with red links in their headword lines")
						return
					end
				end
			end
		end
	}
end

pos_functions["adjectives"] = do_adjective("adjectives")
pos_functions["past participles"] = do_adjective("participles")

pos_functions["verbs"] = {
	param1_is_head = true,
	params = {
		[1] = {},
		["type"] = {list = true},
	},
	func = function(args, data)
		local PAGENAME = mw.title.getCurrentTitle().text
		for _, ty in ipairs(args.type) do
			local category, label
			if ty == "auxiliary" then
				category = "auxiliary verbs"
			elseif ty == "defective" then
				category = "defective verbs"
				label = "[[defective]]"
			elseif ty == "impersonal" then
				category = "impersonal verbs"
				label = "[[impersonal]]"
			elseif ty == "modal" then
				category = "modal verbs"
			elseif ty == "reflexive" then
				category = "reflexive verbs"
			elseif ty == "transitive" then
				label = "[[transitive]]"
			elseif ty == "intransitive" then
				label = "[[intransitive]]"
			elseif ty == "ambitransitive" or ty == "ambi" then
				label = "[[transitive]] and [[intransitive]]"
			end
			if category then
				table.insert(data.categories, "French " .. category)
			end
			if label then
				table.insert(data.inflections, {label = label})
			end
		end
	end
}

return export
