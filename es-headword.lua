local export = {}
local pos_functions = {}

local u = mw.ustring.char
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local rsubn = mw.ustring.gsub

local lang = require("Module:languages").getByCode("es")
local langname = lang:getCanonicalName()

local PAGENAME = mw.title.getCurrentTitle().text

local TEMPC1 = u(0xFFF1)
local TEMPC2 = u(0xFFF2)
local TEMPV1 = u(0xFFF3)
local DIV = u(0xFFF4)
local vowel = "aeiouáéíóúý" .. TEMPV1
local V = "[" .. vowel .. "]"
local SV = "[áéíóúý]" -- stressed vowel
local W = "[iyuw]" -- glide
local C = "[^" .. vowel .. ".]"

local suffix_categories = {
	["adjectives"] = true,
	["adverbs"] = true,
	["nouns"] = true,
	["verbs"] = true,
}

local remove_stress = {
	["á"] = "a", ["é"] = "e", ["í"] = "i", ["ó"] = "o", ["ú"] = "u", ["ý"] = "y"
}
local add_stress = {
	["a"] = "á", ["e"] = "é", ["i"] = "í", ["o"] = "ó", ["u"] = "ú", ["y"] = "ý"
}

local allowed_special_indicators = {
	["first"] = true,
	["first-second"] = true,
	["first-last"] = true,
	["second"] = true,
	["last"] = true,
	["each"] = true,
}

local prepositions = {
	"al?",
	"del?",
	"como",
	"con",
	"en",
	"para",
	"por",
}

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

-- apply rsub() repeatedly until no change
local function rsub_repeatedly(term, foo, bar)
	while true do
		local new_term = rsub(term, foo, bar)
		if new_term == term then
			return term
		end
		term = new_term
	end
end

local function get_special_indicator(form)
	if form:find("^%+") then
		form = form:gsub("^%+", "")
		if not allowed_special_indicators[form] then
			local indicators = {}
			for indic, _ in pairs(allowed_special_indicators) do
				table.insert(indicators, "+" .. indic)
			end
			table.sort(indicators)
			error("Special inflection indicator beginning with '+' can only be " ..
				require("Module:table").serialCommaJoin(indicators, {dontTag = true}) .. ": +" .. form)
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


local function add_endings(bases, endings)
	local retval = {}
	if type(bases) ~= "table" then
		bases = {bases}
	end
	if type(endings) ~= "table" then
		endings = {endings}
	end
	for _, base in ipairs(bases) do
		for _, ending in ipairs(endings) do
			table.insert(retval, base .. ending)
		end
	end
	return retval
end


function handle_multiword(form, special, inflect)
	if special == "first" then
		local first, rest = rmatch(form, "^(.-)( .*)$")
		if not first then
			error("Special indicator 'first' can only be used with a multiword term: " .. form)
		end
		return add_endings(inflect(first), rest)
	elseif special == "second" then
		local first, second, rest = rmatch(form, "^([^ ]+ )([^ ]+)( .*)$")
		if not first then
			error("Special indicator 'second' can only be used with a term with three or more words: " .. form)
		end
		return add_endings(add_endings({first}, inflect(second)), rest)
	elseif special == "first-second" then
		local first, space, second, rest = rmatch(form, "^([^ ]+)( )([^ ]+)( .*)$")
		if not first then
			error("Special indicator 'first-second' can only be used with a term with three or more words: " .. form)
		end
		return add_endings(add_endings(add_endings(inflect(first), space), inflect(second)), rest)
	elseif special == "each" then
		local terms = rsplit(form, " ")
		if #terms < 2 then
			error("Special indicator 'each' can only be used with a multiword term: " .. form)
		end
		for i, term in ipairs(terms) do
			terms[i] = inflect(term)
			if i > 1 then
				terms[i] = add_endings(" ", terms[i])
			end
		end
		local result = ""
		for _, term in ipairs(terms) do
			result = add_endings(result, term)
		end
		return result
	elseif special == "first-last" then
		local first, middle, last = rmatch(form, "^(.-)( .* )(.-)$")
		if not first then
			first, middle, last = rmatch(form, "^(.-)( )(.*)$")
		end
		if not first then
			error("Special indicator 'first-last' can only be used with a multiword term: " .. form)
		end
		return add_endings(add_endings(inflect(first), middle), inflect(last))
	elseif special == "last" then
		local rest, last = rmatch(form, "^(.* )(.-)$")
		if not rest then
			error("Special indicator 'last' can only be used with a multiword term: " .. form)
		end
		return add_endings(rest, inflect(last))
	elseif special then
		error("Unrecognized special=" .. special)
	end

	if form:find(" ") then
		-- check for prepositions in the middle of the word; do it this way so we can handle
		-- more than one word before the preposition (and usually inflect each word)
		for _, prep in ipairs(prepositions) do
			local first, space_prep, rest = rmatch(form, "^(.-)( " .. prep .. ")( .*)$")
			if first then
				return add_endings(inflect(first), space_prep .. rest)
			end
		end

		-- multiword expressions default to first-last
		return handle_multiword(form, "first-last", inflect)
	end

	return nil
end


-- Syllabify a word. This implements the full syllabification algorithm, based on the corresponding code
-- in [[Module:es-pronunc]]. This is more than is needed for the purpose of this module, which doesn't
-- care so much about syllable boundaries, but won't hurt.
local function syllabify(word)
	word = DIV .. word .. DIV
	-- gu/qu + front vowel; make sure we treat the u as a consonant; a following
	-- i should not be treated as a consonant ([[alguien]] would become ''álguienes''
	-- if pluralized)
	word = rsub(word, "([gq])u([eiéí])", "%1" .. TEMPC2 .. "%2")
	local vowel_to_glide = { ["i"] = TEMPC1, ["u"] = TEMPC2 }
	-- i and u between vowels should behave like consonants ([[paranoia]], [[baiano]], [[abreuense]],
	-- [[alauita]], [[Malaui]], etc.)
	word = rsub_repeatedly(word, "(" .. V .. ")([iu])(" .. V .. ")",
		function(v1, iu, v2) return v1 .. vowel_to_glide[iu] .. v2 end
	)
	-- y between consonants or after a consonant at the end of the word should behave like a vowel
	-- ([[ankylosaurio]], [[cryptomeria]], [[brandy]], [[cherry]], etc.)
	word = rsub_repeatedly(word, "(" .. C .. ")y(" .. C .. ")",
		function(c1, c2) return c1 .. TEMPV1 .. c2 end
	)

	word = rsub_repeatedly(word, "(" .. V .. ")(" .. C .. W .. "?" .. V .. ")", "%1.%2")
	word = rsub_repeatedly(word, "(" .. V .. C .. ")(" .. C .. V .. ")", "%1.%2")
	word = rsub_repeatedly(word, "(" .. V .. C .. "+)(" .. C .. C .. V .. ")", "%1.%2")
	word = rsub(word, "([pbcktdg])%.([lr])", ".%1%2")
	word = rsub_repeatedly(word, "(" .. C .. ")%.s(" .. C .. ")", "%1s.%2")
	-- Any aeo, or stressed iu, should be syllabically divided from a following aeo or stressed iu.
	word = rsub_repeatedly(word, "([aeoáéíóúý])([aeoáéíóúý])", "%1.%2")
	word = rsub_repeatedly(word, "([ií])([ií])", "%1.%2")
	word = rsub_repeatedly(word, "([uú])([uú])", "%1.%2")
	word = rsub(word, "([" .. DIV .. TEMPC1 .. TEMPC2 .. TEMPV1 .. "])", {
		[DIV] = "",
		[TEMPC1] = "i",
		[TEMPC2] = "u",
		[TEMPV1] = "y",
	})
	return word
end


local function make_plural(form, special)
	local retval = handle_multiword(form, special, make_plural)
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

	local syllables = rsplit(syllabify(form), "%.")

	-- ends in s or x with more than 1 syllable, last syllable unstressed
	if syllables[2] and rfind(form, "[sx]$") and not rfind(syllables[#syllables], SV) then
		return {form}
	end

	-- ends in l, r, n, d, z, or j with 3 or more syllables, accented on third to last syllable
	if syllables[3] and rfind(form, "[lrndzj]$") and rfind(syllables[#syllables - 2], SV) then
		return {form}
	end

	-- ends in a stressed vowel + consonant
	if rfind(form, SV .. C .. "$") then
		return {rsub(form, "(.)(.)$", function(vowel, consonant)
			return remove_stress[vowel] .. consonant .. "es"
		end)}
	end

	-- ends in a vowel + y, l, r, n, d, j, s, x
	if rfind(form, "[aeiou][ylrndjsx]$") then
		-- two or more syllables: add stress mark to plural; e.g. joven -> jóvenes
		if syllables[2] and rfind(form, "n$") then
			-- don't do anything if syllable already stressed
			if not rfind(syllables[#syllables - 1], SV) then
				-- prefer to accent an a/e/o in case of a diphthong or triphthong; otherwise, do the
				-- last i or u in case of a diphthong ui or iu
				if rfind(syllables[#syllables - 1], "[aeo]") then
					syllables[#syllables - 1] = rsub(syllables[#syllables - 1], "([aeo])",
						function(vowel) return add_stress[vowel] end
					)
				else
					syllables[#syllables - 1] = rsub(syllables[#syllables - 1], "^(.*)([iu])",
						function(before, vowel) return before .. add_stress[vowel] end
					)
				end
			end
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
	local retval = handle_multiword(form, special, make_feminine)
	if retval then
		if #retval ~= 1 then
			error("Internal error: Should have one return value for make_feminine: " .. table.concat(retval, ","))
		end
		return retval[1]
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
		-- español, mongol
		local stem = make_stem(form)
		return stem .. "a"
	end

	return form
end

local function make_masculine(form)
	local retval = handle_multiword(form, special, make_masculine)
	if retval then
		if #retval ~= 1 then
			error("Internal error: Should have one return value for make_masculine: " .. table.concat(retval, ","))
		end
		return retval[1]
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
		local indicators = {}
		for indic, _ in pairs(allowed_special_indicators) do
			table.insert(indicators, "'" .. indic .. "'")
		end
		table.sort(indicators)
		error("Special inflection indicator beginning can only be " ..
			require("Module:table").serialCommaJoin(indicators, {dontTag = true}) .. ": " .. args.sp)
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
			elseif f == "#" then
				f = lemma
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
		["comp"] = {list = true}, --comparative(s)
		["sup"] = {list = true}, --comparative(s)
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
		return do_adjective(args, data, tracking_categories)
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

		local lemma = require("Module:links").remove_links(
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
					pl = get_special_indicator(pl)
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
				local special = get_special_indicator(mf)
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
					mfpl = get_special_indicator(mfpl)
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
	end
}


pos_functions["verbs"] = {
	params = {
		["pres"] = {list = true}, --present
		["pret"] = {list = true}, --preterite
		["part"] = {list = true}, --participle
	},
	func = function(args, data, tracking_categories)
		local lemma = data.heads[1] or PAGENAME
		local refl_clitic_verb, post
		if lemma:find(" ") then
			-- Try to preserve the brackets in the part after the verb, but don't do it
			-- if there aren't the same number of left and right brackets in the verb
			-- (which means the verb was linked as part of a larger expression).
			refl_clitic_verb, post = rmatch(lemma, "^(.-)( .*)$")
			local left_brackets = rsub(refl_clitic_verb, "[^%[]", "")
			local right_brackets = rsub(refl_clitic_verb, "[^%]]", "")
			if #left_brackets == #right_brackets then
				refl_clitic_verb = require("Module:links").remove_links(refl_clitic_verb)
			else
				lemma = require("Module:links").remove_links(lemma)
				refl_clitic_verb, post = rmatch(lemma, "^(.-)( .*)$")
			end
		else
			refl_clitic_verb = require("Module:links").remove_links(lemma)
			post = nil
		end
		local refl_verb, clitic = rmatch(refl_clitic_verb, "^(.-)(l[ao]s?)$")
		if not refl_verb then
			refl_verb, clitic = refl_clitic_verb, nil
		end
		local verb, refl = rmatch(refl_verb, "^(.-)(se)$")
		if not verb then
			verb, refl = refl_verb, nil
		end
		local base, suffix_vowel = rmatch(verb, "^(.-)([aeiáéí])r$")
		if not base then
			error("Unrecognized verb '" .. verb .. "'")
		end
		local suffix = (remove_stress[suffix_vowel] or suffix_vowel) .. "r"
		local def_pres
		if suffix == "ar" then
			def_pres = base .. "o"
		elseif base:find("c$") then
			def_pres = rsub(base, "c$", "zco") -- parecer -> parezco, aducir -> aduzco
		elseif base:find("qu$") then
			def_pres = rsub(base, "qu$", "co") -- delinquir -> delinco
		elseif base:find("g$") then
			def_pres = rsub(base, "g$", "jo") -- coger -> cojo, afligir -> aflijo
		elseif base:find("gu$") then
			def_pres = rsub(base, "gu$", "go") -- distinguir -> distingo
		elseif base:find("u$") then
			def_pres = base .. "yo" -- concluir -> concluyo
		elseif base:find("ü$") then
			def_pres = rsub(base, "ü$", "uyo") -- argüir -> arguyo
		else
			def_pres = base .. "o"
		end
		local def_pret
		if suffix == "ar" then
			def_pret = base .. "é"
			def_pret = rsub(def_pret, "gué$", "güé") -- averiguar -> averigüé
			def_pret = rsub(def_pret, "gé$", "gué") -- cargar -> cargué
			def_pret = rsub(def_pret, "cé$", "qué") -- marcar -> marqué
			def_pret = rsub(def_pret, "[çz]é$", "cé") -- aderezar/adereçar -> aderecé
		else
			def_pret = base .. "í"
		end
		local def_part
		if suffix == "ar" then
			def_part = base .. "ado"
		else
			def_part = base .. "ido"
		end
		if clitic or refl or post then
			def_pres = "[[" .. def_pres .. "]]"
			def_pret = "[[" .. def_pret .. "]]"
			def_part = "[[" .. def_part .. "]]"
		end
		if clitic then
			def_pres = clitic .. " " .. def_pres
			def_pret = clitic .. " " .. def_pret
		end
		if refl then
			def_pres = "me " .. def_pres
			def_pret = "me " .. def_pret
		end
		if post then
			def_pres = def_pres .. post
			def_pret = def_pret .. post
			def_part = def_part .. post
		end

		local function do_verb_form(forms, def_form, label, accel)
			local retval

			if #forms == 0 then
				retval = {def_form}
			elseif #forms == 1 and (forms[1] == "-" or forms[1] == "no") then
				if forms[1] == "no" then
					track("verb-form-no")
				end
				return {label = "no " .. label}
			else
				retval = {}
				for _, form in ipairs(forms) do
					if form == "+" then
						table.insert(retval, def_form)
					else
						table.insert(retval, form)
					end
				end
			end
			retval.label = label
			retval.accel = {form = accel}
			return retval
		end

		table.insert(data.inflections, do_verb_form(args.pres, def_pres, "first-person singular present", "1|s|pres|ind"))
		table.insert(data.inflections, do_verb_form(args.pret, def_pret, "first-person singular preterite", "1|s|pret|ind"))
		table.insert(data.inflections, do_verb_form(args.part, def_part, "past participle", "m|s|past|part"))
		table.insert(data.categories, langname .. " verbs ending in -" .. suffix)
		if refl then
			table.insert(data.categories, langname .. " reflexive verbs")
		end
	end
}


return export
