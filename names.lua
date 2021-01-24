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
	local fromsegs = {}
	local i = 1
	local last_fromseg = nil
	while args.from[i] do
		local from = args.from[i]
		local prefix, suffix
		if from == "surnames" then
			prefix = "transferred from the "
			suffix = "surname"
		elseif from == "place names" then
			prefix = "transferred from the "
			suffix = "place name"
		elseif from == "coinages" then
			prefix = "originating "
			suffix = "as a coinage"
		elseif from == "the Bible" then
			prefix = "originating "
			suffix = "from the Bible"
		else
			prefix = "from "
			local fromlang, fromterm = rmatch(from, "^(.-):(.*)$")
			if fromlang then
				fromlang = m_languages.getByCode(fromlang, "from" .. (i == 1 and "" or i), "allow etym lang")
				local fromlangname = ""
				if fromlang:getCode() ~= lang:getCode() then
					-- If name is derived from another name in the same language, don't include lang name after text "from ".
					fromlangname = fromlang:getCanonicalName() .. " "
				end
				local terminfo = get_terminfo(m_languages.getNonEtymological(fromlang), args, "from", i, fromterm)
				suffix = fromlangname .. m_links.full_link(terminfo, nil, true)
			elseif rfind(from, " languages$") then
				suffix = "the " .. from
			else
				suffix = from
			end
		end
		if last_fromseg and last_fromseg.prefix ~= prefix then
			table.insert(fromsegs, last_fromseg)
			last_fromseg = nil
		end
		if not last_fromseg then
			last_fromseg = {prefix = prefix, suffixes = {}}
		end
		table.insert(last_fromseg.suffixes, suffix)
		i = i + 1
	end
	table.insert(fromsegs, last_fromseg)
	local fromtextsegs = {}
	for _, fromseg in ipairs(fromsegs) do
		table.insert(fromtextsegs, fromseg.prefix ..
			m_table.serialCommaJoin(fromseg.suffixes, {conj = "or"}))
	end
	return m_table.serialCommaJoin(fromtextsegs, {conj = "or"})
end

-- The entry point for {{given name}}.
function export.given_name(frame)
	local parent_args = frame:getParent().args
	local compat = parent_args.lang
	local offset = compat and 0 or 1

	local function track(page)
		require("Module:debug").track("given name/" .. page)
	end

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
	if #args.from > 0 then
		if need_comma then
			table.insert(textsegs, ",")
		end
		need_comma = true
		table.insert(textsegs, " ")
		table.insert(textsegs, get_fromtext(lang, args))
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
			for i, from in ipairs(args.from) do
				local same_from_lang
				local fromcatform
				local fromlang, fromterm = rmatch(from, "^(.-):(.*)$")
				if fromlang then
					fromlang = m_languages.getByCode(fromlang, "from" .. (i == 1 and "" or i), "allow etym lang")
					fromcatform = fromlang:getCanonicalName()
					-- If name is derived from another name in the same language, don't create a category like
					-- "German male given names from German".
					same_from_lang = fromlang:getCode() == lang:getCode()
				elseif from == "surnames" or from == "place names" or from == "coinages" or from == "the Bible" then
					fromcatform = from
				else
					local family = rmatch(from, "^(.*) languages$")
					if family then
						if require("Module:families").getByCanonicalName(family) then
							fromcatform = from
						end
					elseif m_languages.getByCanonicalName(from, nil, "allow etym") then
						fromcatform = from
					end
				end
				if fromcatform then
					if not same_from_lang then
						table.insert(categories, langname .. isdim .. g .. " given names from " .. fromcatform)
					end
				else
					track("unrecognized from")
					track("unrecognized from/" .. from)
				end
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
