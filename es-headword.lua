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


local function base_default_verb_forms(refl_clitic_verb, categories, post)
	local ret
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
		error("Unrecognized verb '" .. verb .. "', doesn't end in -ar, -er or -ir")
	end
	local suffix = (remove_stress[suffix_vowel] or suffix_vowel) .. "r"
	local ends_in_vowel = rfind(base, "[aeo]$")
	if suffix == "ar" then
		ret.pres = base .. "o"
	elseif base:find("c$") then
		ret.pres = rsub(base, "c$", "zco") -- parecer -> parezco, aducir -> aduzco
	elseif base:find("qu$") then
		ret.pres = rsub(base, "qu$", "co") -- delinquir -> delinco
	elseif base:find("g$") then
		ret.pres = rsub(base, "g$", "jo") -- coger -> cojo, afligir -> aflijo
	elseif base:find("gu$") then
		ret.pres = rsub(base, "gu$", "go") -- distinguir -> distingo
	elseif base:find("u$") then
		ret.pres = base .. "yo" -- concluir -> concluyo
	elseif base:find("ü$") then
		ret.pres = rsub(base, "ü$", "uyo") -- argüir -> arguyo
	else
		ret.pres = base .. "o"
	end
	local pres_stem = rmatch(ret.pres, "^(.*)o$")
	local before_last_vowel, last_vowel, after_last_vowel = rmatch(pres_stem, "^(.*)(" .. V .. ")(.-)$")
	ret.pres_ie = last_vowel == "e" and before_last_vowel .. "ie" .. after_last_vowel .. "o"
	-- allow u for jugar -> juego
	ret.pres_ue = (last_vowel == "o" or last_vowel == "u") and before_last_vowel .. "ue" .. after_last_vowel .. "o"
	ret.pres_i = last_vowel == "e" and before_last_vowel .. "i" .. after_last_vowel .. "o"
	ret.pres_iacc = last_vowel == "i" and before_last_vowel .. "í" .. after_last_vowel .. "o"
	ret.pres_uacc = last_vowel == "u" and before_last_vowel .. "ú" .. after_last_vowel .. "o"
	if suffix == "ar" then
		ret.pret = base .. "é"
		ret.pret = rsub(ret.pret, "gué$", "güé") -- averiguar -> averigüé
		ret.pret = rsub(ret.pret, "gé$", "gué") -- cargar -> cargué
		ret.pret = rsub(ret.pret, "cé$", "qué") -- marcar -> marqué
		ret.pret = rsub(ret.pret, "[çz]é$", "cé") -- aderezar/adereçar -> aderecé
	else
		ret.pret = base .. "í"
	end
	if suffix == "ar" then
		ret.part = base .. "ado"
	elseif ends_in_vowel then
		-- reír -> reído, poseer -> poseído, caer -> caído, etc.
		ret.part = base .. "ído"
	else
		ret.part = base .. "ido"
	end
	if clitic or refl or post then
		ret.pres = "[[" .. ret.pres .. "]]"
		ret.pres_ie = ret.pres_ie and "[[" .. ret.pres_ie .. "]]"
		ret.pres_ue = ret.pres_ue and "[[" .. ret.pres_ue .. "]]"
		ret.pres_i = ret.pres_i and "[[" .. ret.pres_i .. "]]"
		ret.pres_iacc = ret.pres_iacc and "[[" .. ret.pres_iacc .. "]]"
		ret.pres_uacc = ret.pres_uacc and "[[" .. ret.pres_uacc .. "]]"
		ret.pret = "[[" .. ret.pret .. "]]"
		ret.part = "[[" .. ret.part .. "]]"
	end
	if clitic then
		ret.pres = clitic .. " " .. ret.pres
		ret.pres_ie = ret.pres_ie and clitic .. " " .. ret.pres_ie
		ret.pres_ue = ret.pres_ue and clitic .. " " .. ret.pres_ue
		ret.pres_i = ret.pres_i and clitic .. " " .. ret.pres_i
		ret.pres_iacc = ret.pres_iacc and clitic .. " " .. ret.pres_iacc
		ret.pres_uacc = ret.pres_uacc and clitic .. " " .. ret.pres_uacc
		ret.pret = clitic .. " " .. ret.pret
	end
	if refl then
		ret.pres = "me " .. ret.pres
		ret.pres_ie = ret.pres_ie and "me " .. ret.pres_ie
		ret.pres_ue = ret.pres_ue and "me " .. ret.pres_ue
		ret.pres_i = ret.pres_i and "me " .. ret.pres_i
		ret.pres_iacc = ret.pres_iacc and "me " .. ret.pres_iacc
		ret.pres_uacc = ret.pres_uacc and "me " .. ret.pres_uacc
		ret.pret = "me " .. ret.pret
	end
	if post then
		ret.pres = ret.pres .. post
		ret.pres_ie = ret.pres_ie and ret.pres_ie .. post
		ret.pres_ue = ret.pres_ue and ret.pres_ue .. post
		ret.pres_i = ret.pres_i and ret.pres_i .. post
		ret.pres_iacc = ret.pres_iacc and ret.pres_iacc .. post
		ret.pres_uacc = ret.pres_uacc and ret.pres_uacc .. post
		ret.pret = ret.pret .. post
		ret.part = ret.part .. post
	end
	ret.verb = verb
	ret.refl = refl
	ret.clitic = clitic
	ref.suffix = suffix

	table.insert(categories, langname .. " verbs ending in -" .. suffix)
	if refl then
		table.insert(categories, langname .. " reflexive verbs")
	end

	return ret
end


local function pres_special_case(form, def_forms)
	if form == "+ie" then
		return def_forms.pres_ie or error("To use +ie, verb '" .. def_forms.verb .. "' should have -e- as the last vowel")
	elseif form == "+ue" then
		return def_forms.pres_ue or error("To use +ue, verb '" .. def_forms.verb .. "' should have -o- or -u- as the last vowel")
	elseif form == "+i" then
		return def_forms.pres_i or error("To use +i, verb '" .. def_forms.verb .. "' should have -e- as the last vowel")
	elseif form == "+í" then
		return def_forms.pres_iacc or error("To use +í, verb '" .. def_forms.verb .. "' should have -i- as the last vowel")
	elseif form == "+ú" then
		return def_forms.pres_uacc or error("To use +ú, verb '" .. def_forms.verb .. "' should have -u- as the last vowel")
	end
end


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
	},
	func = function(args, data, tracking_categories)
		local preses, prets, parts
		local pagename = args.pagename or PAGENAME
		local def_forms

		if args[1] then
			-------------------------- ANGLE-BRACKET FORMAT --------------------------

			if not args[1]:find("<") then
				error("If 1= is given, it should have angle brackets in it: " .. args[1])
			end

			local iut = require("Module:inflection utilities")

			-- (1) Parse the indicator specs inside of angle brackets.

			local function parse_indicator_spec(angle_bracket_spec)
				local inside = angle_bracket_spec:match("^<(.*)>$")
				assert(inside)
				local segments = iut.parse_balanced_segment_run(inside, "[", "]")
				local comma_separated_groups = iut.split_alternating_runs(segments, ",")
				if #comma_separated_groups > 3 then
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
						-- FIXME, what does this do?
						if form == "" then
							form = nil
						end
						table.insert(specs, {form = form, qualifiers = fetch_qualifiers(colon_separated_group)})
					end
					return specs
				end

				local pres_specs = fetch_specs(comma_separated_groups[1])
				local pret_specs = fetch_specs(comma_separated_groups[2])
				local part_specs = fetch_specs(comma_separated_groups[3])

				return {
					forms = {},
					pres_specs = pres_specs,
					pret_specs = pret_specs,
					part_specs = part_specs,
				}
			end

			local parse_props = {
				parse_indicator_spec = parse_indicator_spec,
			}
			local alternant_multiword_spec = iut.parse_inflected_text(args[1], parse_props)

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
				pres_form = "1|s|pres|ind",
				pret_form = "1|s|pret|ind",
				part_form = "m|s|past|part",
			}
			local function conjugate_verb(base)
				local this_def_forms = base_default_verb_forms(base.lemma, data.categories)

				local function process_specs(slot, specs, default_form, special_case)
					for _, spec in ipairs(specs) do
						local form = spec.form
						if not form or form == "+" then
							form = default_form
						elseif special_case then
							form = special_case(form, this_def_forms) or form
						end
						-- If there's a ~ in the form, substitute it with the lemma,
						-- but make sure to first replace % in the lemma with %% so that
						-- it doesn't get interpreted as a capture replace expression.
						if form:find("~") then
							-- Assign to a var because gsub returns multiple values.
							local subbed_lemma = base.lemma:gsub("%%", "%%%%")
							form = form:gsub("~", subbed_lemma)
						end
						-- If the form is -, don't insert any forms, which will result
						-- in there being no overall forms (in fact it will be nil).
						-- We check for that down below and substitute a single "-" as
						-- the form, which in turn gets turned into special labels like
						-- "no present participle".
						if form ~= "-" then
							iut.insert_form(base.forms, slot, {form = form, footnotes = spec.qualifiers})
						end
					end
				end

				process_specs("pres_form", base.pres_specs, this_def_forms.pres, pres_special_case)
				process_specs("pret_form", base.pret_specs, this_def_forms.pret)
				process_specs("part_form", base.part_specs, this_def_forms.part)

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

			local function fetch_forms(slot)
				local forms = alternant_multiword_spec.forms[slot]
				-- See above. This should only occur if the user explicitly used - for a spec.
				if not forms or #forms == 0 then
					forms = {{form = "-"}}
				end
				return forms
			end

			preses = fetch_forms("pres_form")
			prets = fetch_forms("pret_form")
			parts = fetch_forms("part_form")
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

			-- Here we just handle the defaults so that both formats can use param overrides.
			local lemma = data.heads[1] or pagename
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

			def_forms = base_default_verb_forms(lemma, data.categories, post)

			preses = {{form = def_forms.pres}}
			prets = {{form = def_forms.pret}}
			pasts = {{form = def_forms.past}}
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

		local function do_verb_form(args, qualifiers, current_forms, def_form, label, accel_form, special_case)
			local forms

			if #args == 0 then
				forms = current_forms
			elseif #args == 1 and (args[1] == "-" or args[1] == "no") then
				if args[1] == "no" then
					track("verb-form-no")
				end
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
					if arg == "+" then
						if not def_form then
							-- We don't have a clear default form to use, as there may be multiple lemmas inside of
							-- angle brackets. We could conceivably use the first lemma given in angle brackets in case
							-- of multiple, but that seems hacky. You can always use + inside of the angle bracket
							-- format.
							error("Can't use + in override parameter when using angle-bracket forma")
						end
						table.insert(forms, {{form = def_form, footnotes = qual}})
					else
						local spec
						if special_case then
							spec = special_case(form, def_forms)
						end
						table.insert(retval, {{form = spec or form, footnotes = qual}})
					end
				end
			end

			if forms[1].form == "-" then
				return {label = "no " .. label}
			else
				local into_table = {label = label, accel = {form = accel_form}}
				for _, form in ipairs(forms) do
					local qualifiers = strip_brackets(form.footnotes)
					table.insert(into_table, {term = form.form, qualifiers = qualifiers})
				end
				return into_table
			end
		end

		table.insert(data.inflections, do_verb_form(args.pres, args.pres_qual, preses, def_forms and def_forms.pres,
			"first-person singular present", "1|s|pres|ind", def_forms and pres_special_case))
		table.insert(data.inflections, do_verb_form(args.pret, args.pret_qual, prets, def_forms and def_forms.pret,
			"first-person singular preterite", "1|s|pret|ind"))
		table.insert(data.inflections, do_verb_form(args.part, args.part_qual, parts, def_forms and def_forms.part,
			"past participle", "m|s|past|part"))
	end
}


return export
