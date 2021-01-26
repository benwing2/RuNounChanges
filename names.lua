local m_languages = require("Module:languages")
local m_links = require("Module:links")
local m_utilities = require("Module:utilities")
local m_table = require("Module:table")

local export = {}

local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsubn = mw.ustring.gsub
local rsplit = mw.text.split

local force_cat = true

--[=[

FIXME:

1. from=the Bible (DONE)
2. origin=18th century
3. popular= (DONE)
4. varoftype= (DONE)
5. eqtype= [DONE]
6. dimoftype= [DONE]
7. from=de:Elisabeth (same language) (DONE)
8. blendof=, blendof2= [DONE]
9. varform, dimform
10. from=English < Latin
11. usage=rare -> categorize as rare?
12. dimeq= (also vareq=?)
13. fromtype=
14. <tr:...> and similar params
]=]

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

-- Used in category code
export.personal_name_types = {
	"surnames", "patronymics", "given names",
	"male given names", "female given names", "unisex given names",
	"diminutives of male given names", "diminutives of female given names",
	"diminutives of unisex given names",
	"augmentatives of male given names", "augmentatives of female given names",
	"augmentatives of unisex given names"
}


local translit_name_type_list = {
	"surname", "male given name", "female given name", "unisex given name",
	"patronymic"
}
local translit_name_types = m_table.listToSet(translit_name_type_list)

local param_mods = {"t", "alt", "tr", "ts", "pos", "lit", "id", "sc", "g", "q"}
local param_mod_set = m_table.listToSet(param_mods)


local function track(page)
	require("Module:debug").track("names/" .. page)
end


--[=[
Fetch a term and associated properties and return a terminfo object that can be passed to full_link()
in [[Module:links]]. The properties are specified using separate parameters, where the term itself is
specified by `pname` and `index` (e.g. "f2") and the various properties are specified by parameters with
the property name appended, e.g. "f2tr". It is assumed that the arguments themselves have already been
processed using [[Module:parameters]] to that e.g. all "f" parameters ("f", "f2", "f3", ...) are contained
in a list in args["f"], and similarly all "fNtr" parameters ("ftr", "f2tr", "f3tr", ...) are contained in
a list in args["ftr"].
* `args` is the arguments returned by [[Module:parameters]]
* `pname` is the basic parameter prefix, e.g. "f" or "varof"
* `index` says to pull out the index'th parameter of this type
* `lang` is the language to store in the returned terminfo structure
* `term` can be used to override the term itself; if not specified, the term comes from the `pname`
  parameter in `args`
]=]
local function get_terminfo(lang, args, pname, index, term)
	local function fetch(mod)
		return args[pname .. mod] and args[pname .. mod][index]
	end
	local sc = require("Module:scripts").getByCode(fetch("sc"), pname .. (index == 1 and "" or index) .. "sc")
	local g = fetch("g")
	g = g and rsplit(g, ",") or {}
	
	return {
		lang = lang, term = term or fetch(""), alt = fetch("alt"), tr = fetch("tr"), ts = fetch("ts"), id = fetch("id"),
		gloss = fetch("t"), pos = fetch("pos"), lit = fetch("lit"), g = g, sc = sc, q = fetch("q") 
	}
end


--[=[
Fetch a term and associated properties and return a terminfo object that can be passed to full_link()
in [[Module:links]]. This works with parameters of the form 'Karlheinz' or 'Kunigunde<q:medieval, now rare>' or
'non:Óláfr' or 'ru:Фру́нзе<tr:Frúnzɛ><q:rare>' where the modifying properties are contained in <...>
specifications after the term. `term` is the full parameter value including any angle brackets and colons;
`pname` is the name of the parameter that this value comes from, for error purposes; and `deflang` is a
language object used in the return value when the language isn't specified (e.g. in the examples 'Karlheinz'
and 'Kunigunde<q:medieval, now rare>' above).
]=]
local function get_term_with_annotations(term, pname, deflang)
	local iut = require("Module:inflection utilities")
	local run = iut.parse_balanced_segment_run(term, "<", ">")
	local function parse_err(msg)
		error(msg .. ": " .. pname .. "= " .. table.concat(run))
	end
	if #run == 1 and run[1] == "" then
		error("Blank form for param '" .. pname .. "' not allowed")
	end
	local terminfo = {}
	local lang, form = run[1]:match("^(.-):(.*)$")
	if lang then
		terminfo.lang = m_languages.getByCode(lang, pname, "allow etym lang")
		terminfo.term = form
	else
		terminfo.lang = deflang
		terminfo.term = run[1]
	end

	for i = 2, #run - 1, 2 do
		if run[i + 1] ~= "" then
			parse_err("Extraneous text '" .. run[i + 1] .. "' after modifier")
		end
		local modtext = run[i]:match("^<(.*)>$")
		if not modtext then
			parse_err("Internal error: Modifier '" .. modtext .. "' isn't surrounded by angle brackets")
		end
		local prefix, arg = modtext:match("^([a-z]+):(.*)$")
		if not prefix then
			parse_err("Modifier " .. run[i] .. " lacks a prefix, should begin with one of '" ..
				table.concat(param_mods, ":', '") .. ":'")
		end
		if param_mod_set[prefix] then
			if terminfo[prefix] then
				parse_err("Modifier '" .. prefix .. "' occurs twice, second occurrence " .. run[i])
			end
			terminfo[prefix] = arg
		else
			parse_err("Unrecognized prefix '" .. prefix .. "' in modifier " .. run[i])
		end
	end
	return terminfo
end


--[=[
Join the terms in `terms` (where each is a terminfo structure suitable for passing to full_link() or language_link()
in [[Module:links]] using the conjugation in `conj` (defaulting to "or"). Joining is done using serialCommaJoin()
in [[Module:table]], so that e.g. two terms are joined as "TERM or TERM" while three terms are joined as
"TERM, TERM or TERM" with special CSS spans before the final "or" to allow an "Oxford comma" to appear if configured
appropriately. If `include_langname` is given, the language of the first term will be prepended to the joined
terms. If `do_language_link` is given, or if a given term's language is English, the link will be constructed
using language_link() in [[Module:links]]; otherwise, with full_link().
]=]
local function join_terms(terms, include_langname, do_language_link, conj)
	local links = {}
	local langnametext
	for _, term in ipairs(terms) do
		if include_langname and not langnametext then
			langnametext = term.lang:getCanonicalName() .. " "
		end
		term.lang = m_languages.getNonEtymological(term.lang)
		if do_language_link and term.lang:getCode() == "en" then
			link = m_links.language_link(term, nil, true)
		else
			link = m_links.full_link(term, nil, true)
		end
		if term.q then
			link = require("Module:qualifier").format_qualifier(term.q) .. " " .. link
		end
		table.insert(links, link)
	end
	return (langnametext or "") .. m_table.serialCommaJoin(links, {conj = conj or "or"})
end


--[=[
Gather the parameters for multiple names, each specified using a set of parameters, an link each name using
full_link() (for foreign names) or language_link() (for English names), joining the names using
serialCommaJoin() in [[Module:table]] with the conjugation `conj` (defaulting to "or"). This can be used,
for example, to fetch and join all the masculine equivalent names for a feminine given name. Each name is
specified using parameters beginning with `pname` in `args`, and `lang` is the language of the names, for
use in linking them. For example, if `pname` is "m" (for masculine equivalent names), the names themselves
will be contained in arguments "m", "m2", "m3", ...; the associated manual transliterations will be contained
in "mtr", "m2tr", "m3tr", ...; etc. This function assumes that the parameters have already been parsed by
[[Module:parameters]] and gathered into lists, so that e.g. all "mN" parameters are in a list in args["m"],
all "mNtr" parameters are in a list in args["mtr"], etc.
]=]
local function join_names(lang, args, pname, conj)
	local term_objs = {}
	local i = 1
	local do_language_link = false
	if not lang then
		lang = m_languages.getByCode("en")
		do_language_link = true
	end

	-- Find the maximum index among any of the list parameters.
	local maxmaxindex = #args[pname]
	for _, mod in ipairs(param_mods) do
		local v = args[pname .. mod]
		if type(v) == "table" and v.maxindex and v.maxindex > maxmaxindex then
			maxmaxindex = v.maxindex
		end
	end

	for i = 1, maxmaxindex do
		table.insert(term_objs, get_terminfo(lang, args, pname, i))
	end
	return join_terms(term_objs, nil, do_language_link, conj), #term_objs
end


local function get_eqtext(args)
	local eqsegs = {}
	local i = 1
	local lastlang = nil
	local last_eqseg = {}
	while args.eq[i] do
		local eqlang, eqterm = rmatch(args.eq[i], "^(.-):(.*)$")
		if not eqlang then
			eqlang = "en"
			eqterm = args.eq[i]
		end
		if lastlang and lastlang ~= eqlang then
			if #last_eqseg > 0 then
				table.insert(eqsegs, last_eqseg)
			end
			last_eqseg = {}
		end
		lastlang = eqlang
		local terminfo = get_terminfo(
			m_languages.getByCode(eqlang, "eq" .. (i == 1 and "" or i), "allow etym lang"),
			args, "eq", i, eqterm)
		table.insert(last_eqseg, terminfo)
		i = i + 1
	end
	if #last_eqseg > 0 then
		table.insert(eqsegs, last_eqseg)
	end
	local eqtextsegs = {}
	for _, eqseg in ipairs(eqsegs) do
		table.insert(eqtextsegs, join_terms(eqseg, "include langname"))
	end
	return m_table.serialCommaJoin(eqtextsegs)
end


local function get_fromtext(lang, args)
	local catparts = {}
	local fromsegs = {}
	local i = 1

	local function parse_from(from)
		local unrecognized = false
		local prefix, suffix
		if from == "surnames" then
			prefix = "transferred from the "
			suffix = "surname"
			table.insert(catparts, from)
		elseif from == "place names" then
			prefix = "transferred from the "
			suffix = "place name"
			table.insert(catparts, from)
		elseif from == "coinages" then
			prefix = "originating "
			suffix = "as a coinage"
			table.insert(catparts, from)
		elseif from == "the Bible" then
			prefix = "originating "
			suffix = "from the Bible"
			table.insert(catparts, from)
		else
			prefix = "from "
			if from:find(":") then
				local terminfo = get_term_with_annotations(from, "from" .. (i == 1 and "" or i), lang)
				local fromlangname = ""
				if terminfo.lang:getCode() ~= lang:getCode() then
					-- If name is derived from another name in the same language, don't include lang name after text "from "
					-- or create a category like "German male given names derived from German".
					local canonical_name = terminfo.lang:getCanonicalName()
					fromlangname = canonical_name .. " "
					table.insert(catparts, canonical_name)
				end
				terminfo.lang = m_languages.getNonEtymological(terminfo.lang)
				suffix = fromlangname .. m_links.full_link(terminfo, nil, true)
			elseif from:find(" languages$") then
				local family = from:match("^(.*) languages$")
				if require("Module:families").getByCanonicalName(family) then
					table.insert(catparts, from)
				else
					unrecognized = true
				end
				suffix = "the " .. from
			else
				if m_languages.getByCanonicalName(from, nil, "allow etym") then
					table.insert(catparts, from)
				else
					unrecognized = true
				end
				suffix = from
			end
		end
		if unrecognized then
			track("unrecognized from")
			track("unrecognized from/" .. from)
		end
		return prefix, suffix
	end

	local last_fromseg = nil
	while args.from[i] do
		local rawfrom = args.from[i]
		local froms = rsplit(rawfrom, "%s+<<%s+")
		if #froms == 1 then
			local prefix, suffix = parse_from(froms[1])
			if last_fromseg and (last_fromseg.has_multiple_froms or last_fromseg.prefix ~= prefix) then
				table.insert(fromsegs, last_fromseg)
				last_fromseg = nil
			end
			if not last_fromseg then
				last_fromseg = {prefix = prefix, suffixes = {}}
			end
			table.insert(last_fromseg.suffixes, suffix)
		else
			if last_fromseg then
				table.insert(fromsegs, last_fromseg)
				last_fromseg = nil
			end
			local first_suffixpart = ""
			local rest_suffixparts = {}
			for j, from in ipairs(froms) do
				local prefix, suffix = parse_from(from)
				if j == 1 then
					first_suffixpart = prefix .. suffix
				else
					table.insert(rest_suffixparts, prefix .. suffix)
				end
			end
			local full_suffix = first_suffixpart .. "(" .. table.concat(rest_suffixparts, ", in turn ") .. ")"
			last_fromseg = {prefix = "", has_multiple_froms = true, suffixes = {full_suffix}}
		end
		i = i + 1
	end
	table.insert(fromsegs, last_fromseg)
	local fromtextsegs = {}
	for _, fromseg in ipairs(fromsegs) do
		table.insert(fromtextsegs, fromseg.prefix ..  m_table.serialCommaJoin(fromseg.suffixes, {conj = "or"}))
	end
	return m_table.serialCommaJoin(fromtextsegs, {conj = "or"}), catparts
end


-- The entry point for {{given name}}.
function export.given_name(frame)
	local parent_args = frame:getParent().args
	local compat = parent_args.lang
	local offset = compat and 0 or 1

	local params = {
		[compat and "lang" or 1] = { required = true, default = "und" },
		["gender"] = { default = "unknown-gender" },
		[1 + offset] = { alias_of = "gender", default = "unknown-gender" },
		-- second gender
		["or"] = {},
		["usage"] = {},
		["popular"] = {},
		["populartype"] = {},
		["meaning"] = { list = true },
		["meaningtype"] = {},
		-- initial article: A or An
		["A"] = {},
		["sort"] = {},
		[2 + offset] = { alias_of = "from", list = true },
		["xlit"] = { list = true },
		["xlitalt"] = { list = "xlit=alt", allow_holes = true },
	}

	local function add_list_param(pname, alias_of)
		params[pname] = { list = true, alias_of = alias_of }
		for _, mod in ipairs(param_mods) do
			params[pname .. mod] = { list = pname .. "=" .. mod, allow_holes = true,
				alias_of = alias_of and alias_of .. mod or nil }
		end
		params[pname .. "type"] = { alias_of = alias_of and alias_of .. "type" or nil }
	end

	add_list_param("from")
	add_list_param("dimof")
	add_list_param("dim", "dimof")
	add_list_param("diminutive", "dimof")
	add_list_param("eq")
	add_list_param("varof")
	add_list_param("var", "varof")
	add_list_param("blend")
	add_list_param("m")
	add_list_param("f")
	
	local args = require("Module:parameters").process(parent_args, params)
	
	local textsegs = {}
	local lang = m_languages.getByCode(args[compat and "lang" or 1], compat and "lang" or 1)

	local function fetch_typetext(param)
		return args[param] and args[param] .. " " or ""
	end

	local dimtext, numdims = join_names(lang, args, "dim")
	local xlittext = join_names(nil, args, "xlit")
	local blendtext = join_names(lang, args, "blend", "and")
	local varoftext = join_names(lang, args, "varof")
	local mtext = join_names(lang, args, "m")
	local ftext = join_names(lang, args, "f")
	local meaningsegs = {}
	for _, meaning in ipairs(args.meaning) do
		table.insert(meaningsegs, '"' .. meaning .. '"')
	end
	local meaningtext = m_table.serialCommaJoin(meaningsegs, {conj = "or"})

	local eqtext = get_eqtext(args)

	table.insert(textsegs, "<span class='use-with-mention'>")
	local dimtype = args.dimtype
	local article = args.A or
		dimtype and rfind(dimtype, "^[aeiouAEIOU]") and "An" or
		args.gender == "unknown-gender" and "An" or
		"A"

	table.insert(textsegs, article .. " ")
	if numdims > 0 then
		table.insert(textsegs,
			(dimtype and dimtype .. " " or "") ..
			"[[diminutive]]" ..
			(xlittext ~= "" and ", " .. xlittext .. "," or "") ..
			" of the ")
	end
	local genders = {}
	table.insert(genders, args.gender)
	table.insert(genders, args["or"])
	table.insert(textsegs, table.concat(genders, " or ") .. " ")
	table.insert(textsegs, numdims > 1 and "[[given name|given names]]" or
		"[[given name]]")
	local need_comma = false
	if numdims > 0 then
		table.insert(textsegs, " " .. dimtext)
		need_comma = true
	elseif xlittext ~= "" then
		table.insert(textsegs, ", " .. xlittext)
		need_comma = true
	end
	local from_catparts = {}
	if #args.from > 0 then
		if need_comma then
			table.insert(textsegs, ",")
		end
		need_comma = true
		table.insert(textsegs, " ")
		local textseg, this_catparts = get_fromtext(lang, args)
		for _, catpart in ipairs(this_catparts) do
			m_table.insertIfNot(from_catparts, catpart)
		end
		table.insert(textsegs, textseg)
	end
	
	if meaningtext ~= "" then
		if need_comma then
			table.insert(textsegs, ",")
		end
		need_comma = true
		table.insert(textsegs, " " .. fetch_typetext("meaningtype") .. "meaning " .. meaningtext)
	end
	if args.usage then
		if need_comma then
			table.insert(textsegs, ",")
		end
		need_comma = true
		table.insert(textsegs, " of " .. args.usage .. " usage")
	end
	if varoftext ~= "" then
		table.insert(textsegs, ", " ..fetch_typetext("varoftype") .. "variant of " .. varoftext)
	end
	if blendtext ~= "" then
		table.insert(textsegs, ", " .. fetch_typetext("blendtype") .. "blend of " .. blendtext)
	end
	if args.popular then
		table.insert(textsegs, ", " .. fetch_typetext("populartype") .. "popular " .. args.popular)
	end
	if mtext ~= "" then
		table.insert(textsegs, ", " .. fetch_typetext("mtype") .. "masculine equivalent " .. mtext)
	end
	if ftext ~= "" then
		table.insert(textsegs, ", " .. fetch_typetext("ftype") .. "feminine equivalent " .. ftext)
	end
	if eqtext ~= "" then
		table.insert(textsegs, ", " .. fetch_typetext("eqtype") .. "equivalent to " .. eqtext)
	end
	table.insert(textsegs, "</span>")

	local categories = {}
	local langname = lang:getCanonicalName() .. " "
	local function insert_cats(isdim)
		if isdim == "" then
			-- No category such as "English diminutives of given names"
			table.insert(categories, langname .. isdim .. "given names")
		end
		local function insert_cats_gender(g)
			if g == "unknown-gender" then
				track("unknown gender")
				return
			end
			if g ~= "male" and g ~= "female" and g ~= "unisex" then
				error("Unrecognized gender: " .. g)
			end
			if g == "unisex" then
				insert_cats_gender("male")
				insert_cats_gender("female")
			end
			table.insert(categories, langname .. isdim .. g .. " given names")
			for _, catpart in ipairs(from_catparts) do
				table.insert(categories, langname .. isdim .. g .. " given names from " .. catpart)
			end
		end
		insert_cats_gender(args.gender)
		if args["or"] then
			insert_cats_gender(args["or"])
		end
	end
	insert_cats("")
	if numdims > 0 then
		insert_cats("diminutives of ")
	end

	return table.concat(textsegs, "") ..
		m_utilities.format_categories(categories, lang, args.sort, nil, force_cat)
end

-- The entry point for {{name translit}}.
function export.name_translit(frame)
	local parent_args = frame:getParent().args

	local params = {
		[1] = { required = true },
		[2] = { required = true },
		[3] = { list = true },
		["type"] = { required = true },
		["alt"] = { list = true, allow_holes = true },
		["t"] = { list = true, allow_holes = true },
		["gloss"] = { list = true, alias_of = "t", allow_holes = true },
		["tr"] = { list = true, allow_holes = true },
		["ts"] = { list = true, allow_holes = true },
		["id"] = { list = true, allow_holes = true },
		["sc"] = { list = true, allow_holes = true },
		["g"] = { list = true, allow_holes = true },
		["q"] = { list = true, allow_holes = true },
		["xlit"] = { list = true, allow_holes = true },
		["eq"] = { list = true, allow_holes = true },
		["dim"] = { type = "boolean" },
		["aug"] = { type = "boolean" },
		["sort"] = {},
	}
	
	local args = require("Module:parameters").process(parent_args, params)
	local lang = m_languages.getByCode(args[1], 1)
	local source = m_languages.getByCode(args[2], 2, "allow etym")
	local sourcelang = m_languages.getNonEtymological(source)

	local ty = args["type"]
	if not translit_name_types[ty] then
		local quoted_types = {}
		for _, nametype in ipairs(translit_name_type_list) do
			table.insert(quoted_types, "'" .. nametype .. "'")
		end
		error("Unrecognized type '" .. ty .. "': It should be one of " ..
			m_table.serialCommaJoin(quoted_types, {conj = "or"}))
	end

	local textsegs = {}
	table.insert(textsegs, "<span class='use-with-mention'>A transliteration of the ")
	table.insert(textsegs, source:getCanonicalName() .. " " .. ty)
	if args.dim then
		table.insert(textsegs, " [[diminutive]]")
	elseif args.aug then
		table.insert(textsegs, " [[augmentative]]")
	end
	table.insert(textsegs, " ")
	local names = {}

	-- Find the maximum index among any of the list parameters.
	local maxmaxindex = #args[3]
	for k, v in pairs(args) do
		if type(v) == "table" and v.maxindex and v.maxindex > maxmaxindex then
			maxmaxindex = v.maxindex
		end
	end

	local embedded_comma = false

	for i = 1, maxmaxindex do
		local sc = require("Module:scripts").getByCode(args["sc"][i], true)
		
		local linked_term = m_links.full_link({
			lang = sourcelang, term = args[3][i], alt = args["alt"][i], id = args["id"][i], sc = sc, tr = args["tr"][i],
			ts = args["ts"][i], gloss = args["t"][i], genders = args["g"][i] and rsplit(args["g"][i], ",") or {}
		}, "term")
		if  args["q"][i] then
			linked_term = require("Module:qualifier").format_qualifier(args["q"][i]) .. " " .. linked_term
		end
		if args["xlit"][i] then
			embedded_comma = true
			linked_term = linked_term .. ", " .. m_links.language_link({ lang = m_languages.getByCode("en"), term = args["xlit"][i] })
		end
		if args["eq"][i] then
			embedded_comma = true
			linked_term = linked_term .. ", equivalent to " .. m_links.language_link({ lang = m_languages.getByCode("en"), term = args["eq"][i] })
		end
		table.insert(names, linked_term)
	end

	if embedded_comma then
		table.insert(textsegs, table.concat(names, "; or of "))
	else
		table.insert(textsegs, m_table.serialCommaJoin(names, {conj = "or"}))
	end
	table.insert(textsegs, "</span>")

	local categories = {}
	local function insert_cats(isdim)
		local function insert_cats_type(ty)
			if ty == "unisex given name" then
				insert_cats_type("male given name")
				insert_cats_type("female given name")
			end
			table.insert(categories, lang:getCode() .. ":" .. source:getCanonicalName() .. " " .. isdim .. ty .. "s")
			if source:getCode() ~= sourcelang:getCode() then
				-- etymology language
				table.insert(categories, lang:getCode() .. ":" .. sourcelang:getCanonicalName() .. " " .. isdim .. ty .. "s")
			end
		end
		insert_cats_type(args["type"])
	end
	insert_cats("")
	if args.dim then
		insert_cats("diminutives of ")
	end
	if args.aug then
		insert_cats("augmentatives of ")
	end

	return table.concat(textsegs, "") ..
		m_utilities.format_categories(categories, lang, args.sort, nil, force_cat)
end

return export
