-- Author: Benwing2; based on an early version by Rua

local ar_translit = require("Module:ar-translit")

local lang = require("Module:languages").getByCode("ar")

local export = {}
local pos_functions = {}

-- diacritics
local u = mw.ustring.char
local A = u(0x064E) -- fatḥa
local AN = u(0x064B) -- fatḥatān (fatḥa tanwīn)
local U = u(0x064F) -- ḍamma
local UN = u(0x064C) -- ḍammatān (ḍamma tanwīn)
local I = u(0x0650) -- kasra
local IN = u(0x064D) -- kasratān (kasra tanwīn)
local SK = u(0x0652) -- sukūn = no vowel
local SH = u(0x0651) -- šadda = gemination of consonants
local DAGGER_ALIF = u(0x0670)
local DIACRITIC_ANY_BUT_SH = "[" .. A .. I .. U .. AN .. IN .. UN .. SK .. DAGGER_ALIF .. "]"

-- various letters and signs
local HAMZA = u(0x0621) -- hamza on the line (stand-alone hamza) = ء
local ALIF = u(0x0627) -- ʾalif = ا
local AMAQ = u(0x0649) -- ʾalif maqṣūra = ى
local TAM = u(0x0629) -- tāʾ marbūṭa = ة

-- common combinations
local UNU = "[" .. UN .. U .. "]"

-----------------------
-- Utility functions --
-----------------------

-- If Not Empty
local function ine(arg)
	if arg == "" then
		return nil
	else
		return arg
	end
end

local function list_to_set(list)
	local set = {}
	for _, item in ipairs(list) do
		set[item] = true
	end
	return set
end

-- version of mw.ustring.gsub() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = mw.ustring.gsub(term, foo, bar)
	return retval
end

local rfind = mw.ustring.find

local function remove_links(text)
	text = rsub(text, "%[%[[^|%]]*|", "")
	text = rsub(text, "%[%[", "")
	text = rsub(text, "%]%]", "")
	return text
end

local function reorder_shadda(text)
	-- shadda+short-vowel (including tanwīn vowels, i.e. -an -in -un) gets
	-- replaced with short-vowel+shadda during NFC normalisation, which
	-- MediaWiki does for all Unicode strings; however, it makes the
	-- detection process inconvenient, so undo it. (For example, the tracking
	-- code below would fail to detect the -un in سِتٌّ because the shadda
	-- would come after the -un.)
	text = rsub(text, "(" .. DIACRITIC_ANY_BUT_SH .. ")" .. SH, SH .. "%1")
	return text
end

-- Tracking functions

local trackfn = require("Module:debug/track")
local function track(page)
	trackfn("ar-headword/" .. page)
	return true
end

--[==[
Examples of what you can find by looking at what links to the given
pages:

[[Special:WhatLinksHere/Template:tracking/ar-headword/unvocalized]]
	all unvocalized pages
[[Special:WhatLinksHere/Template:tracking/ar-headword/unvocalized/pl]]
	all unvocalized pages where the plural is unvocalized,
	  whether specified using pl=, pl2=, etc.
[[Special:WhatLinksHere/Template:tracking/ar-headword/unvocalized/head]]
	all unvocalized pages where the head is unvocalized
[[Special:WhatLinksHere/Template:tracking/ar-headword/unvocalized/head/nouns]]
	all nouns excluding proper nouns, collective nouns,
	 singulative nouns where the head is unvocalized
[[Special:WhatLinksHere/Template:tracking/ar-headword/unvocalized/head/proper]]
	nouns all proper nouns where the head is unvocalized
[[Special:WhatLinksHere/Template:tracking/ar-headword/unvocalized/head/not]]
	proper nouns all words that are not proper nouns
	  where the head is unvocalized
[[Special:WhatLinksHere/Template:tracking/ar-headword/unvocalized/adjectives]]
	all adjectives where any parameter is unvocalized;
	  currently only works for heads,
	  so equivalent to .../unvocalized/head/adjectives
[[Special:WhatLinksHere/Template:tracking/ar-headword/unvocalized-empty-head]]
	all pages with an empty head
[[Special:WhatLinksHere/Template:tracking/ar-headword/unvocalized-manual-translit]]
	all unvocalized pages with manual translit
[[Special:WhatLinksHere/Template:tracking/ar-headword/unvocalized-manual-translit/head/nouns]]
	all nouns where the head is unvocalized but has manual translit
[[Special:WhatLinksHere/Template:tracking/ar-headword/unvocalized-no-translit]]
	all unvocalized pages without manual translit
[[Special:WhatLinksHere/Template:tracking/ar-headword/i3rab]]
	all pages with any parameter containing i3rab
	  of either -un, -u, -a or -i
[[Special:WhatLinksHere/Template:tracking/ar-headword/i3rab-un]]
	all pages with any parameter containing an -un i3rab ending
[[Special:WhatLinksHere/Template:tracking/ar-headword/i3rab-un/pl]]
	all pages where a form specified using pl=, pl2=, etc.
	  contains an -un i3rab ending
[[Special:WhatLinksHere/Template:tracking/ar-headword/i3rab-u/head]]
	all pages with a head containing an -u i3rab ending
[[Special:WhatLinksHere/Template:tracking/ar-headword/i3rab/head/proper]]
	nouns (all proper nouns with a head containing i3rab
	  of either -un, -u, -a or -i)

In general, the format is one of the following:

Template:tracking/ar-headword/FIRSTLEVEL
Template:tracking/ar-headword/FIRSTLEVEL/ARGNAME
Template:tracking/ar-headword/FIRSTLEVEL/POS
Template:tracking/ar-headword/FIRSTLEVEL/ARGNAME/POS

FIRSTLEVEL can be one of "unvocalized", "unvocalized-empty-head" or its
opposite "unvocalized-specified", "unvocalized-manual-translit" or its
opposite "unvocalized-no-translit", "i3rab", "i3rab-un", "i3rab-u",
"i3rab-a", or "i3rab-i".

ARGNAME is either "head" or an argument such as "pl", "f", "cons", etc.
This automatically includes arguments specified as head2=, pl3=, etc.

POS is a part of speech, lowercase and pluralized, e.g. "nouns",
"adjectives", "proper nouns", "collective nouns", etc. or
"not proper nouns", which includes all parts of speech but proper nouns.
]==]

local function track_form(argname, form, translit, pos)
	form = reorder_shadda(remove_links(form))
	function dotrack(page)
		track(page)
		track(page .. "/" .. argname)
		if pos then
			track(page .. "/" .. pos)
			track(page .. "/" .. argname .. "/" .. pos)
			if pos ~= "proper nouns" then
				track(page .. "/not proper nouns")
				track(page .. "/" .. argname .. "/not proper nouns")
			end
		end
	end
	function track_i3rab(arabic, tr)
		if rfind(form, arabic .. "$") then
			dotrack("i3rab")
			dotrack("i3rab-" .. tr)
		end
	end
	track_i3rab(UN, "un")
	track_i3rab(U, "u")
	track_i3rab(A, "a")
	track_i3rab(I, "i")
	if form == "" or not (lang:transliterate(form)) then
		dotrack("unvocalized")
		if form == "" then
			dotrack("unvocalized-empty-head")
		else
			dotrack("unvocalized-specified")
		end
		if translit then
			dotrack("unvocalized-manual-translit")
		else
			dotrack("unvocalized-no-translit")
		end
	end
end

-- The main entry point.
function export.show(frame)
	local poscat = frame.args[1]
		or error("Part of speech has not been specified. Please pass parameter 1 to the module invocation.")

	local parargs = frame:getParent().args

	local params = {
		[1] = {list = "head", disallow_holes = true},
		["tr"] = {list = true, allow_holes = true},
		["id"] = {},
		["nolinkhead"] = {type = "boolean"},
		["json"] = {type = "boolean"},
		["pagename"] = {}, -- for testing
	}

	if pos_functions[poscat] then
		for key, val in pairs(pos_functions[poscat].params) do
			params[key] = val
		end
	end

	local args = require("Module:parameters").process(parargs, params)

	local pagename = args.pagename or mw.title.getCurrentTitle().subpageText

	local data = {
		lang = lang,
		pos_category = poscat,
		categories = {},
		heads = args[1],
		translits = args.tr,
		genders = {},
		inflections = {enable_auto_translit = true},
		pagename = pagename,
		id = args.id,
		sort_key = args.sort,
		force_cat_output = force_cat,
	}

	local irreg_translit = false
	for i = 1, #args[1] do
		if ar_translit.irregular_translit(args[1][i], args.tr[i]) then
			irreg_translit = true
			break
		end
	end

	if irreg_translit then
		table.insert(data.categories, lang:getCanonicalName() .. " terms with irregular pronunciations")
	end

	if pos_functions[poscat] then
		pos_functions[poscat].func(args, data)
	end

	if args.json then
		return require("Module:JSON").toJSON(data)
	end

	return require("Module:headword").full_headword(data)
end

-- Get a list of inflections. See handle_infl() for meaning of ARGS and ARGPREF.
local function getargs(args, argpref)
	local forms = {}
	for i, form in ipairs(args[argpref]) do
		local translit = args[argpref .. "tr"][i]
		local gender = args[argpref .. "g"][i]
		local gender2 = args[argpref .. "g2"][i]
		local genderlist = (gender or gender2) and { gender, gender2 } or nil
		-- FIXME, do we need this?
		track_form(argpref, form, translit)
		table.insert(forms, { term = form, translit = translit, genders = genderlist })
	end

	return forms
end

local function add_infl_params(params, argpref, defgender)
	params[argpref] = {list = true, disallow_holes = true}
	params[argpref .. "=tr"] = {list = true, allow_holes = true}
	params[argpref .. "=g"] = {list = true, default = defgender}
	params[argpref .. "=g2"] = {list = true}
end

-- Get a list of inflections from the arguments in ARGS based on argument
-- prefix ARGPREF (e.g. "pl" to snarf arguments called "pl", "pl2", etc.,
-- along with "pltr", "pl2tr", etc. and optional gender(s) "plg", "plg2",
-- "pl2g", "pl2g2", "pl3g", "pl3g2", etc.). Label with LABEL (e.g. "plural"),
-- which will appear in the headword. Insert into inflections list
-- INFLS. Optional DEFGENDER is default gender to insert if gender
-- isn't given; otherwise, no gender is inserted. (This is used for
-- singulative forms of collective nouns, and collective forms of singulative
-- nouns, which have different gender from the base form(s).)
local function handle_infl(args, data, argpref, label, generate_default)
	local newinfls = getargs(args, argpref)
	if #newinfls == 0 then
		newinfls = generate_default(args, data)
	end
	if #newinfls > 0 then
		newinfls.label = label
		table.insert(data.inflections, newinfls)
	end
end

local function add_all_infl_params(params, argpref)
	if argpref ~= "" then
		add_infl_params(params, argpref)
	end

	add_infl_params(params, argpref .. "cons")
	add_infl_params(params, argpref .. "def")
	add_infl_params(params, argpref .. "obl")
	add_infl_params(params, argpref .. "inf")
end

-- Handle a basic inflection (e.g. plural, feminine) along with the construct,
-- definite and oblique variants of this inflection. Can also handle the base
-- construct/definite/oblique variants if both ARGPREF and LABEL are given
-- as blank strings. If ARGPREF is blank, skip the base inflection.
local function handle_all_infl(args, data, argpref, label, generate_default)
	if argpref ~= "" then
		handle_infl(args, data, argpref, label, generate_default)
	end

	local labelsp = label == "" and "" or label .. " "
	handle_infl(args, data, argpref .. "cons", labelsp .. "construct state")
	handle_infl(args, data, argpref .. "def", labelsp .. "definite state")
	handle_infl(args, data, argpref .. "obl", labelsp .. "oblique")
	handle_infl(args, data, argpref .. "inf", labelsp .. "informal")
end

-- Handle the case where pl=-, indicating an uncountable noun.
local function handle_noun_plural(args, data)
	if args.pl[1] == "-" then
		table.insert(data.inflections, { label = "usually [[Appendix:Glossary#uncountable|uncountable]]" })
		table.insert(data.categories, lang:getCanonicalName() .. " uncountable nouns")
		if args.pauc and #args.pauc > 0 then
			error("Can't specify paucals when pl=-")
		end
	else
		handle_all_infl(args, data, "pl", "plural")
	end
end

local valid_genders = list_to_set(
		{ "m", "m-s", "m-pr", "m-s-pr", "m-np", "m-s-np",
		  "f", "f-s", "f-pr", "f-s-pr", "f-np", "f-s-np",
		  "m-d", "m-d-pr", "m-d-np",
		  "f-d", "f-d-pr", "f-d-np",
		  "m-p", "m-p-pr", "m-p-np",
		  "f-p", "f-p-pr", "f-p-np",
		  "d", "d-pr", "d-np",
		  "p", "p-pr", "p-np",
		  "pr", "np", "?"
		})

local function is_masc_sg(g)
	return g == "m" or g == "m-pr" or g == "m-np"
end
local function is_fem_sg(g)
	return g == "f" or g == "f-pr" or g == "f-np"
end

local function add_gender_params(params, default)
	params[2] = {list = "g", default = default or "?"}
end

-- Handle gender in params 2=, g2=, etc., inserting into `data.genders`. Also, if a lemma, insert categories into
-- `data.categories` if the gender is unexpected for the form of the noun. (Note: If there are multiple genders,
-- [[Module:gender and number]] will automatically insert 'Arabic POS with multiple genders'.)
local function handle_gender(args, data, nonlemma)
	for _, g in ipairs(args[2]) do
		if valid_genders[g] then
			table.insert(data.genders, g)
		else
			error("Unrecognized gender: " .. g)
		end
	end

	if nonlemma then
		return
	end

	if #args[2] == 1 then
		local g = args[2][1]
		if is_masc_sg(g) or is_fem_sg(g) then
			local head = args.head
			if head then
				head = rsub(reorder_shadda(remove_links(head)), UNU .. "?$", "")
				local ends_with_tam = rfind(head, "^[^ ]*" .. TAM .. "$") or
						rfind(head, "^[^ ]*" .. TAM .. " ")
				if is_masc_sg(g) and ends_with_tam then
					table.insert(data.categories, lang:getCanonicalName() .. " masculine terms with feminine ending")
				elseif is_fem_sg(g) and not ends_with_tam and
						not rfind(head, "[" .. ALIF .. AMAQ .. "]$") and
						not rfind(head, ALIF .. HAMZA .. "$") then
					table.insert(data.categories, lang:getCanonicalName() .. " feminine terms lacking feminine ending")
				end
			end
		end
	end
end

-- Part-of-speech functions

local adj_inflections = {
	{pref = "", label = ""}, -- handle cons, def, obl, inf
	{pref = "f", label = "feminine"},
	{pref = "d", label = "masculine dual"},
	{pref = "fd", label = "feminine dual"},
	{pref = "cpl", label = "common plural"},
	{pref = "pl", label = "masculine plural"},
	{pref = "fpl", label = "feminine plural"},
}

local function create_infl_list_params(infl_list)
	params = {}
	for _, infl in ipairs(infl_list) do
		if infl.basic then
			add_infl_params(params, infl.pref)
		else
			add_all_infl_params(params, infl.pref)
		end
	end
	return params
end

local function handle_infl_list_args(args, data, infl_list)
	for _, infl in ipairs(infl_list) do
		if infl.handle then
			infl.handle(args, data)
		elseif infl.basic then
			handle_infl(args, data, infl.pref, infl.label, infl.generate_default)
		else
			handle_all_infl(args, data, infl.pref, infl.label, infl.generate_default)
		end
	end
end

pos_functions["adjectives"] = {
	params = (function()
		local params = create_infl_list_params(adj_inflections)
		add_infl_params(params, "el")
		return params
	end)(),
	func = function(args, data)
		handle_infl_list_args(args, data, adj_inflections)
		handle_infl(args, data, "el", "elative")
	end
}


local function make_nisba_default(ending, endingtr)
	return function(args, data)
		local heads = data.heads
		if #heads == 0 then
			heads = {data.pagename}
		end
		local forms = {}
		for i = 1, #heads do
			local tr = data.translits
			table.insert(forms, {term = heads[i] .. ending, translit = tr and tr .. endingtr or nil})
		end
		return forms
	end
end

local nisba_adj_inflections = {
	{pref = "", label = ""}, -- handle cons, def, obl, inf
	{pref = "f", label = "feminine", generate_default = make_nisba_default(A .. "ة", "a")},
	{pref = "d", label = "masculine dual"},
	{pref = "fd", label = "feminine dual"},
	{pref = "cpl", label = "common plural"},
	{pref = "pl", label = "masculine plural", generate_default = make_nisba_default(U .. "ون", "ūn")},
	{pref = "fpl", label = "feminine plural", generate_default = make_nisba_default(A .. "ات", "āt")},
}

pos_functions["nisba adjectives"] = {
	params = (function()
		return create_infl_list_params(nisba_adj_inflections)
	end)(),
	func = function(args, data)
		handle_infl_list_args(args, data, nisba_adj_inflections)
	end
}

local sing_coll_noun_inflections = {
	{pref = "", label = ""}, -- handle cons, def, obl, inf
	{pref = "d", label = "dual"},
	{pref = "pl", label = "plural", handle = handle_noun_plural},
	{pref = "pauc", label = "paucal"},
}

local function handle_sing_coll_noun_infls(args, data, otherinfl, otherlabel)
	handle_gender(args, data)
	-- Handle sing= (corresponding singulative noun) or coll= (corresponding collective noun) and their gender
	handle_infl(args, data, otherinfl, otherlabel)
	handle_infl_list_args(args, data, sing_coll_noun_inflections)
end

local function get_sing_coll_noun_params(defgender, otherinfl, othergender)
	local params = create_infl_list_params(sing_coll_noun_inflections)
	add_gender_params(params, defgender)
	add_infl_params(params, otherinfl, othergender)
	return params
end

pos_functions["collective nouns"] = {
	params = get_sing_coll_noun_params("m", "sing", "f"),
	func = function(args, data)
		data.pos_category = "nouns"
		table.insert(data.categories, lang:getCanonicalName() .. " collective nouns")
		table.insert(data.inflections, { label = "collective" })
		handle_sing_coll_noun_infls(args, data, "sing", "singulative")
	end
}

pos_functions["singulative nouns"] = {
	params = get_sing_coll_noun_params("f", "coll", "m"),
	func = function(args, data)
		data.pos_category = "nouns"
		table.insert(data.categories, lang:getCanonicalName() .. " singulative nouns")
		table.insert(data.inflections, { label = "singulative" })
		handle_sing_coll_noun_infls(args, data, "coll", "collective")
	end
}

local noun_inflections = {
	{pref = "", label = ""}, -- handle cons, def, obl, inf
	{pref = "d", label = "dual"},
	{pref = "pl", label = "plural", handle = handle_noun_plural},
	{pref = "pauc", label = "paucal"},
	{pref = "f", label = "feminine"},
	{pref = "m", label = "masculine"},
}

local function get_noun_params()
	local params = create_infl_list_params(noun_inflections)
	add_gender_params(params)
	return params
end

local function handle_noun_infls(args, data)
	handle_gender(args, data)
	handle_infl_list_args(args, data, noun_inflections)
end

pos_functions["nouns"] = {
	params = get_noun_params(),
	func = handle_noun_infls,
}

-- FIXME: Do numerals really behave almost as nouns? They vary by masc/fem.
pos_functions["numerals"] = {
	params = get_noun_params(),
	func = function(args, data)
		table.insert(data.categories, lang:getCanonicalName() .. " cardinal numbers")
		handle_noun_infls(args, data)
	end
}

pos_functions["proper nouns"] = {
	params = get_noun_params(),
	func = handle_noun_infls,
}

local pronoun_inflections = {
	{pref = "", label = ""}, -- handle cons, def, obl, inf
	{pref = "d", label = "dual"},
	{pref = "pl", label = "plural", handle = handle_noun_plural},
	{pref = "f", label = "feminine"},
}

local function get_pronoun_params()
	local params = create_infl_list_params(pronoun_inflections)
	add_gender_params(params)
	return params
end

pos_functions["pronouns"] = {
	params = get_pronoun_params(),
	func = function(args, data)
		handle_gender(args, data)
		handle_infl_list_args(args, data, pronoun_inflections)
	end
}

local function get_gender_only_params(default)
	local params = {}
	add_gender_params(params, default)
	return params
end

pos_functions["noun plural forms"] = {
	params = (function()
		local params = {}
		add_gender_params(params, "p")
		add_infl_params(params, "cons")
		return params
	end)(),
	func = function(args, data)
		data.pos_category = "noun forms"
		handle_gender(args, data, "nonlemma")
		handle_infl(args, data, "cons", "construct state")
	end
}

pos_functions["adjective feminine forms"] = {
	params = get_gender_only_params("f"),
	func = function(args, data)
		data.pos_category = "adjective forms"
		handle_gender(args, data, "nonlemma")
	end
}

pos_functions["noun dual forms"] = {
	params = get_gender_only_params("m-d"),
	func = function(args, data)
		data.pos_category = "noun forms"
		handle_gender(args, data, "nonlemma")
	end
}

pos_functions["adjective plural forms"] = {
	params = get_gender_only_params("m-p"),
	func = function(args, data)
		data.pos_category = "adjective forms"
		handle_gender(args, data, "nonlemma")
	end
}

pos_functions["adjective dual forms"] = {
	params = get_gender_only_params("m-p"),
	func = function(args, data)
		data.pos_category = "adjective forms"
		handle_gender(args, data, "m-d", "nonlemma")
	end
}

pos_functions["noun forms"] = {
	params = get_gender_only_params(),
	func = function(args, data)
		handle_gender(args, data, nil, "nonlemma")
	end
}

local valid_forms = list_to_set(
		{ "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII",
		  "XIII", "XIV", "XV", "Iq", "IIq", "IIIq", "IVq" })

local function handle_conj_form(args, data)
	local form = args[2]
	if form then
		if not valid_forms[form] then
			error("Invalid verb conjugation form " .. form)
		end

		table.insert(data.inflections, { label = '[[Appendix:Arabic verbs#Form ' .. form .. '|form ' .. form .. ']]' })
	end
end

pos_functions["verb forms"] = {
	params = {
		[2] = {},
	},
	func = function(args, data)
		handle_conj_form(args, data)
	end
}

local function get_participle_params()
	local params = create_infl_list_params(adj_inflections)
	params[2] = {}
	return params
end

pos_functions["active participles"] = {
	params = get_participle_params(),
	func = function(args, data)
		data.pos_category = "participles"
		table.insert(data.categories, lang:getCanonicalName() .. " active participles")
		handle_conj_form(args, data)
		handle_infl_list_args(args, data, adj_inflections)
	end
}

pos_functions["passive participles"] = {
	params = get_participle_params(),
	func = function(args, data)
		data.pos_category = "participles"
		table.insert(data.categories, lang:getCanonicalName() .. " passive participles")
		handle_conj_form(args, data)
		handle_infl_list_args(args, data, adj_inflections)
	end
}

return export
