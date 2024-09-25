-- Author: Benwing2; based on an early version by Rua

local ar_translit = require("Module:ar-translit")
local m_str_utils = require("Module:string utilities")
local ar_verb_module = "Module:ar-verb"
local inflection_utilities_module = "Module:inflection utilities"
local parse_utilities_module = "Module:parse utilities"

local list_to_set = require("Module:table").listToSet
local rfind = m_str_utils.find
local rsubn = m_str_utils.gsub
local u = m_str_utils.char
local rsplit = m_str_utils.split

local lang = require("Module:languages").getByCode("ar")

local export = {}
local pos_functions = {}

local force_cat = false -- for testing; if true, categories appear in non-mainspace pages

-- diacritics
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

local TEMPCOMMA = u(0xFFF0)
local TEMPARCOMMA = u(0xFFF1)

-----------------------
-- Utility functions --
-----------------------

local dump = mw.dumpObject

-- version of mw.ustring.gsub() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

-- Replace comma with a temporary char in comma + whitespace.
local function escape_comma_whitespace(run)
	local escaped = false

	if run:find("\\,") then
		run = run:gsub("\\,", "\\" .. TEMPCOMMA)
		escaped = true
	end
	if run:find("\\،") then
		run = run:gsub("\\،", "\\" .. TEMPARCOMMA)
		escaped = true
	end
	if run:find(",%s") then
		run = run:gsub(",(%s)", TEMPCOMMA .. "%1")
		escaped = true
	end
	if run:find("،%s") then
		run = run:gsub("،(%s)", TEMPARCOMMA .. "%1")
		escaped = true
	end
	return run, escaped
end

-- Undo replacement of comma with a temporary char in comma + whitespace.
local function unescape_comma_whitespace(run)
	return (run:gsub(TEMPCOMMA, ","):gsub(TEMPARCOMMA, "،"))
end

-- Split an argument on comma or Arabic comma, but not either type of comma followed by whitespace.
local function split_on_comma(val)
	if rfind(val, "[,،]%s") or val:find("\\") then
		return export.split_escaping(val, "[,،]", false, escape_comma_whitespace, unescape_comma_whitespace)
	else
		return rsplit(val, "[,،]")
	end
end


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

[[Special:WhatLinksHere/Wiktionary:Tracking/ar-headword/unvocalized]]
	all unvocalized pages
[[Special:WhatLinksHere/Wiktionary:Tracking/ar-headword/unvocalized/pl]]
	all unvocalized pages where the plural is unvocalized,
	  whether specified using pl=, pl2=, etc.
[[Special:WhatLinksHere/Wiktionary:Tracking/ar-headword/unvocalized/head]]
	all unvocalized pages where the head is unvocalized
[[Special:WhatLinksHere/Wiktionary:Tracking/ar-headword/unvocalized/head/nouns]]
	all nouns excluding proper nouns, collective nouns,
	 singulative nouns where the head is unvocalized
[[Special:WhatLinksHere/Wiktionary:Tracking/ar-headword/unvocalized/head/proper]]
	nouns all proper nouns where the head is unvocalized
[[Special:WhatLinksHere/Wiktionary:Tracking/ar-headword/unvocalized/head/not]]
	proper nouns all words that are not proper nouns
	  where the head is unvocalized
[[Special:WhatLinksHere/Wiktionary:Tracking/ar-headword/unvocalized/adjectives]]
	all adjectives where any parameter is unvocalized;
	  currently only works for heads,
	  so equivalent to .../unvocalized/head/adjectives
[[Special:WhatLinksHere/Wiktionary:Tracking/ar-headword/unvocalized-empty-head]]
	all pages with an empty head
[[Special:WhatLinksHere/Wiktionary:Tracking/ar-headword/unvocalized-manual-translit]]
	all unvocalized pages with manual translit
[[Special:WhatLinksHere/Wiktionary:Tracking/ar-headword/unvocalized-manual-translit/head/nouns]]
	all nouns where the head is unvocalized but has manual translit
[[Special:WhatLinksHere/Wiktionary:Tracking/ar-headword/unvocalized-no-translit]]
	all unvocalized pages without manual translit
[[Special:WhatLinksHere/Wiktionary:Tracking/ar-headword/i3rab]]
	all pages with any parameter containing i3rab
	  of either -un, -u, -a or -i
[[Special:WhatLinksHere/Wiktionary:Tracking/ar-headword/i3rab-un]]
	all pages with any parameter containing an -un i3rab ending
[[Special:WhatLinksHere/Wiktionary:Tracking/ar-headword/i3rab-un/pl]]
	all pages where a form specified using pl=, pl2=, etc.
	  contains an -un i3rab ending
[[Special:WhatLinksHere/Wiktionary:Tracking/ar-headword/i3rab-u/head]]
	all pages with a head containing an -u i3rab ending
[[Special:WhatLinksHere/Wiktionary:Tracking/ar-headword/i3rab/head/proper]]
	nouns (all proper nouns with a head containing i3rab
	  of either -un, -u, -a or -i)

In general, the format is one of the following:

Wiktionary:Tracking/ar-headword/FIRSTLEVEL
Wiktionary:Tracking/ar-headword/FIRSTLEVEL/ARGNAME
Wiktionary:Tracking/ar-headword/FIRSTLEVEL/POS
Wiktionary:Tracking/ar-headword/FIRSTLEVEL/ARGNAME/POS

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
		["tr"] = {list = true, allow_holes = true},
		["id"] = {},
		["nolinkhead"] = {type = "boolean"},
		["json"] = {type = "boolean"},
		["pagename"] = {}, -- for testing
	}
	local head_is_head = pos_functions[poscat] and pos_functions[poscat].head_is_not_1
	if head_is_head then
		params.head = {list = true, disallow_holes = true}
	else
		params[1] = {list = "head", disallow_holes = true}
	end

	if pos_functions[poscat] then
		for key, val in pairs(pos_functions[poscat].params) do
			params[key] = val
		end
	end

	local args = require("Module:parameters").process(parargs, params)

	local pagename = args.pagename or mw.loadData("Module:headword/data").pagename

	local data = {
		lang = lang,
		pos_category = poscat,
		categories = {},
		heads = {},
		genders = {},
		inflections = {enable_auto_translit = true},
		pagename = pagename,
		id = args.id,
		sort_key = args.sort,
		force_cat_output = force_cat,
	}

	local heads = head_is_head and args.head or args[1]
	for i = 1, #heads do
		table.insert(data.heads, {
			term = heads[i],
			tr = args.tr[i],
		})
	end

	if pos_functions[poscat] then
		pos_functions[poscat].func(args, data)
	end

	-- Do this after calling pos_functions[poscat].func() as it may modify data.heads (as verbs do).
	local irreg_translit = false
	for _, head in ipairs(data.heads) do
		if ar_translit.irregular_translit(head.term, head.tr) then
			irreg_translit = true
			break
		end
	end

	if irreg_translit then
		table.insert(data.categories, lang:getCanonicalName() .. " terms with irregular pronunciations")
	end

	if args.json then
		return require("Module:JSON").toJSON(data)
	end

	return require("Module:headword").full_headword(data)
end

-- Fetch a list of user-specified inflections from `args` that begin with `argpref`, e.g. "pl" for plural inflections.
-- Also fetches translit under (e.g.) "pltr", "pl2tr", etc.; gender under (e.g.) "plg", "pl2g", etc.; and a second
-- gender under (e.g.) "plg2", "pl2g2", etc.
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

-- Add list parameters to `params` (a structure as passed to [[Module:parameters]]) for a parameter named `argpref`,
-- along with related transliteration and gender parameters. If `defgender` is given, the gender parameter will have the
-- specified default value if no values are given.
local function add_infl_params(params, argpref, defgender)
	params[argpref] = {list = true, disallow_holes = true}
	params[argpref .. "\1tr"] = {list = true, allow_holes = true}
	params[argpref .. "\1g"] = {list = true, default = defgender}
	params[argpref .. "\1g2"] = {list = true}
end

--[=[
Fetch a list of inflections from the arguments in `args` based on argument prefix `argpref` (e.g. "pl" to snarf
arguments called "pl", "pl2", etc., along with "pltr", "pl2tr", etc. and optional gender(s) "plg", "plg2", "pl2g",
"pl2g2", "pl3g", "pl3g2", etc.). Label with `label` (e.g. "plural"), which will appear in the headword. Insert into
`data.inflections`, where `data` is the structure passed to [[Module:headword]]. If `generate_default` is specified,
it should be a function of two arguments (`args`, `data`), which should generate the default value if no values are
specified or if "+" is explicitly given. If `generate_default` isn't specified and the user gave no values, no
inflection will be inserted.
]=]
local function handle_infl(args, data, argpref, label, generate_default)
	local newinfls = getargs(args, argpref)
	if #newinfls == 0 and generate_default then
		newinfls = {{term = "+"}}
	end
	if generate_default then
		local saw_plus = false
		for _, newinfl in ipairs(newinfls) do
			if newinfl.term == "+" then
				saw_plus = true
				break
			end
		end
		if saw_plus then
			local newnewinfls = {}
			for _, newinfl in ipairs(newinfls) do
				if newinfl.term == "+" then
					local definfls = generate_default(args, data)
					for _, definfl in ipairs(definfls) do
						table.insert(newnewinfls, definfl)
					end
				else
					table.insert(newnewinfls, newinfl)
				end
			end
			newinfls = newnewinfls
		end
	end
	if #newinfls > 0 then
		newinfls.label = label
		table.insert(data.inflections, newinfls)
	end
end


-- Add the parameter specs to `params` (a structure of the sort passed to [[Module:parameters]]) for a basic inflection
-- (e.g. plural, feminine), along with the construct, definite and oblique variants of this inflection. This is similar
-- to `add_infl_params`, and all arguments are the same as that function, but also adds specs for the variant arguments;
-- e.g. if `argpref` is "pl", this also adds specs for "plcons" for the plural construct state, "pldef" for the plural
-- definite state, etc. Can also handle the base construct/definite/oblique variants if `argpref` is given as a blank
-- string (if `argpref` is blank, skip the base inflection).
local function add_all_infl_params(params, argpref)
	if argpref ~= "" then
		add_infl_params(params, argpref)
	end

	add_infl_params(params, argpref .. "cons")
	add_infl_params(params, argpref .. "def")
	add_infl_params(params, argpref .. "obl")
	add_infl_params(params, argpref .. "inf")
end

-- Insert a basic inflection (e.g. plural, feminine) into `data.inflections` based on user-specified arguments, along
-- with the construct, definite and oblique variants of this inflection. This is similar to `handle_infl`, and all
-- arguments are the same as that function, but also checks for the variant arguments; e.g. if `argpref` is "pl", this
-- also checks for "plcons" for the plural construct state, "pldef" for the plural definite state, etc. Can also handle
-- the base construct/definite/oblique variants if both `argpref` and `label` are given as blank strings. If `argpref`
-- is blank, skip the base inflection.
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

local valid_bare_genders = {false, "m", "f", "mf", "mfbysense", "mfequiv"}
local valid_bare_numbers = {false, "d", "p"}
local valid_bare_animacies = {false, "pr", "np"}

local valid_genders = {}
for _, gender in ipairs(valid_bare_genders) do
	for _, number in ipairs(valid_bare_numbers) do
		for _, animacy in ipairs(valid_bare_animacies) do
			local parts = {}
			local function ins_part(part)
				if part then
					table.insert(parts, part)
				end
			end
			ins_part(gender)
			ins_part(number)
			ins_part(animacy)
			local full_gender = table.concat(parts, "-")
			valid_genders[full_gender == "" and "?" or full_gender] = true
		end
	end
end

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
			heads = {{term = data.pagename}}
		end
		local forms = {}
		for i = 1, #heads do
			local tr = heads[i].tr
			table.insert(forms, {term = heads[i].term .. ending, translit = tr and tr .. endingtr or nil})
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
	{pref = "pl", label = "masculine plural", generate_default = make_nisba_default(U .. "ونَ", "ūna")},
	{pref = "fpl", label = "feminine plural", generate_default = make_nisba_default(A .. "ات", "āt")},
}

pos_functions["nisba adjectives"] = {
	params = (function()
		return create_infl_list_params(nisba_adj_inflections)
	end)(),
	func = function(args, data)
		data.pos_category = "adjectives"
		handle_infl_list_args(args, data, nisba_adj_inflections)
	end
}

local nisba_noun_inflections = {
	{pref = "", label = ""}, -- handle cons, def, obl, inf
	{pref = "pl", label = "plural", generate_default = make_nisba_default(U .. "ونَ", "ūna")},
	{pref = "f", label = "feminine", generate_default = make_nisba_default(A .. "ة", "a")},
}

pos_functions["nisba nouns"] = {
	params = (function()
		return create_infl_list_params(nisba_noun_inflections)
	end)(),
	func = function(args, data)
		data.pos_category = "nouns"
		data.genders = {"m"}
		handle_infl_list_args(args, data, nisba_noun_inflections)
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
		data.pos_category = "adjective feminine forms"
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

-- FIXME: Partly duplicated in [[Module:ar-inflections]].
local function handle_conj_form(args, data)
	local form = args[2]
	if form then
		if not valid_forms[form] then
			error("Invalid verb conjugation form " .. form)
		end

		table.insert(data.inflections, { label = "[[Appendix:Arabic verbs#Form " .. form .. "|form " .. form .. "]]" })
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

-----------------------------------------------------------------------------------------
--                                         Verbs                                       --
-----------------------------------------------------------------------------------------

pos_functions["verbs"] = {
	head_is_not_1 = true,
	params = {
		[1] = {},
		-- Comma-separated lists with possible inline modifiers
		["past"] = {},
		["past1s"] = {},
		["nonpast"] = {},
		["vn"] = {},
		["noautolinktext"] = {type = "boolean"},
		["noautolinkverb"] = {type = "boolean"},
	},
	func = function(args, data)
		local ar_verb = require(ar_verb_module)
		local alternant_multiword_spec =
			args[1] ~= "-" and ar_verb.do_generate_forms(args, "ar-verb", data.pagename) or nil

		local function do_slot(slots_to_check, override, label, slot_is_headword)
			-- Do this even with an override so we can return the correct filled slot.
			local slot, slotval
			if alternant_multiword_spec then
				for _, potential_slot in ipairs(slots_to_check) do
					slotval = alternant_multiword_spec.forms[potential_slot]
					if slotval then
						slot = potential_slot
						break
					end
				end
			end

			local function get_slot_values()
				local terms = {}
				for _, form in ipairs(slotval) do
					local term = {
						term = form.form,
						id = form.id,
						genders = form.genders,
						pos = form.pos,
						lit = form.lit,
					}
					-- Yuck, harmonize these.
					term[slot_is_headword and "tr" or "translit"] = form.translit
					if form.footnotes then
						local quals, refs = require(inflection_utilities_module).
							convert_footnotes_to_qualifiers_and_references(form.footnotes)
						term.q = quals
						term.refs = refs
					end
					table.insert(terms, term)
				end

				return terms
			end

			if override then
				local override_param_mods = {
					alt = {},
					t = {
						-- [[Module:headword]] expects the gloss in "gloss".
						item_dest = "gloss",
					},
					gloss = {},
					g = {
						-- [[Module:headword]] expects the genders in "genders". `sublist = true` automatically splits
						-- on comma (optionally with surrounding whitespace).
						item_dest = "genders",
						sublist = true,
					},
					pos = {},
					lit = {},
					id = {},
					-- Qualifiers and labels
					q = {
						type = "qualifier",
					},
					qq = {
						type = "qualifier",
					},
					l = {
						type = "labels",
					},
					ll = {
						type = "labels",
					},
					ref = {
						-- [[Module:headword]] expects the references in "refs".
						item_dest = "refs",
						type = "references",
					},
				}

				local function generate_obj(formval, parse_err)
					if formval == "+" then
						return {term = "+", underlying_terms = get_slot_values()}
					end
					local val, uncertain = formval:match("^(.*)(%?)$")
					val = val or formval
					uncertain = not not uncertain
					local ar, translit = val:match("^(.*)//(.*)$")
					if not ar then
						ar = formval
					end
					local retval = {term = ar, uncertain = uncertain}
					-- Yuck, harmonize these.
					retval[slot_is_headword and "tr" or "translit"] = translit
				end

				local terms
				if override:find("<") then
					terms = require(parse_utilities_module).parse_inline_modifiers(override, {
						paramname = paramname,
						param_mods = override_param_mods,
						generate_obj = generate_obj,
						splitchar = "[,،]",
						escape_fun = escape_comma_whitespace,
						unescape_fun = unescape_comma_whitespace,
					})
				else
					terms = split_on_comma(override)
					for i, split in ipairs(terms) do
						terms[i] = generate_obj(split)
					end
				end
				-- See if + was supplied and we have to potentially flatten multiple default terms and harmonize
				-- default properties with override properties.
				local saw_underlying_terms = false
				for _, term in ipairs(terms) do
					if term.underlying_terms then
						saw_underlying_terms = true
						break
					end
				end
				if saw_underlying_terms then
					-- Flatten any default terms, copying the corresponding override properties over the default
					-- properties. Non-default terms get inserted directly.
					local flattened = {}
					for _, term in ipairs(terms) do
						if term.underlying_terms then
							for _, underlying in ipairs(term.underlying_terms) do
								for k, v in pairs(term) do
									if k ~= "term" and k ~= "underlying_terms" then
										if k == "uncertain" then
											underlying.uncertain = underlying.uncertain or v
										elseif type(v) ~= "table" or v[1] then
											-- Don't copy empty lists (which are the default) over possibly non-empty
											-- lists.
											underlying[k] = v
										end
									end
								end
								table.insert(flattened, underlying)
							end
						else
							table.insert(flattened, term)
						end
					end
					terms = flattened
				end
				if not slot_is_headword then
					terms.label = label
				end
				return terms, slot
			elseif not alternant_multiword_spec then
				return nil, slot
			else
				if not slotval then
					if slot_is_headword then
						-- FIXME, put "uncertain" as qualifier? Does this ever happen?
						return nil, slot
					elseif alternant_multiword_spec.slot_uncertain[slot] then
						return {label = label .. " uncertain"}, slot
					elseif alternant_multiword_spec.slot_explicitly_missing[slot] then
						return {label = "no " .. label}, slot
					else
						-- just say nothing about this slot
						return nil, slot
					end
				end
				local terms = get_slot_values()
				if not slot_is_headword then
					terms.label = label
				end
				return terms, slot
			end
		end

		local gloss_parts = {}
		for _, vform in ipairs(alternant_multiword_spec.verb_forms) do
			table.insert(gloss_parts, "[[Appendix:Arabic verbs#Form " .. vform .. "|" .. vform .. "]]")
		end
		if gloss_parts[1] then
			data.gloss = table.concat(gloss_parts, ", ")
		end

		if data.heads[1] and args.past then
			error("Can't specify both head= and past= to {{ar-verb}}; prefer past=")
		end
		
		if not alternant_multiword_spec.has_active then
			table.insert(data.inflections, {label = "passive-only"})
		end

		-- Do this always so `past_slot` is correctly filled.
		local past, past_slot = do_slot(ar_verb.potential_lemma_slots, args.past, "-", "slot is headword")
		if data.heads[1] then
			-- user specified head=; don't override with past= or slot 'past_3sm' etc.
		else
			if past then
				data.heads = past
			end
		end

		local should_do_past1s = not not args.past1s
		if not should_do_past1s then
			local is_form_I = false
			for _, vform in ipairs(alternant_multiword_spec.verb_forms) do
				if vform == "I" then
					is_form_I = true
					break
				end
			end

			if is_form_I then
				require(inflection_utilities_module).map_word_specs(alternant_multiword_spec, function(base)
					if base.verb_form == "I" then
						for _, vowel_spec in ipairs(base.conj_vowels) do
							-- For form-I geminate verbs, the final vowel of the past is elided in the citation form.
							-- We want to display it for all cases other than active a~u and a~i (the most common
							-- cases).
							if vowel_spec.weakness == "geminate" then
								if ar_verb.is_passive_only(base.passive) then
									should_do_past1s = true
									break
								end
								local past_vowel = ar_verb.rget(vowel_spec.past)
								local nonpast_vowel = ar_verb.rget(vowel_spec.nonpast)
								if not (past_vowel == A and (nonpast_vowel == U or nonpast_vowel == I)) then
									should_do_past1s = true
									break
								end
							end
						end
						-- FIXME, provide way of breaking early from map_word_specs().
					end
				end)
			end
		end

		local past1s
		if should_do_past1s then
			past1s, _ = do_slot({"past_1s", "past_pass_1s"}, args.past1s, "first-person singular past")
			if past1s then
				table.insert(data.inflections, past1s)
			end
		end

		local nonpast_slots
		if not past_slot or past_slot:find("^past_") then
			nonpast_slots = {"ind_3ms", "ind_pass_3ms", "imp_2ms"}
		else
			nonpast_slots = {}
		end
		local nonpast, _ = do_slot(nonpast_slots, args.nonpast, "non-past")
		if nonpast then
			table.insert(data.inflections, nonpast)
		end

		local vn, _ = do_slot({"vn"}, args.vn, "verbal noun")
		if vn then
			table.insert(data.inflections, vn)
		end

		-- FIXME: Should we insert categories? Conjugation also does it and is more likely to be accurate.
		--for _, cat in ipairs(alternant_multiword_spec.categories) do
		--	table.insert(data.categories, cat)
		--end

		--[=[
		-- FIXME: Review this to see if we need to port it.
		-- If the user didn't explicitly specify head=, or specified exactly one head (not 2+) and we were able to
		-- incorporate any links in that head into the 1= specification, use the infinitive generated by
		-- [[Module:pt-verb]] in place of the user-specified or auto-generated head. This was copied from
		-- [[Module:it-headword]], where doing this gets accents marked on the verb(s). We don't have accents marked on
		-- the verb but by doing this we do get any footnotes on the infinitive propagated here. Don't do this if the
		-- user gave multiple heads or gave a head with a multiword-linked verbal expression such as Italian
		-- '[[dare esca]] [[al]] [[fuoco]]' (FIXME: give Portuguese equivalent).
		if #data.user_specified_heads == 0 or (
			#data.user_specified_heads == 1 and alternant_multiword_spec.incorporated_headword_head_into_lemma
		) then
			data.heads = {}
			for _, lemma_obj in ipairs(alternant_multiword_spec.forms.infinitive_linked) do
				local quals, refs = require(inflection_utilities_module).
					convert_footnotes_to_qualifiers_and_references(lemma_obj.footnotes)
				table.insert(data.heads, {term = lemma_obj.form, q = quals, refs = refs})
			end
		end
		]=]
	end
}

return export
