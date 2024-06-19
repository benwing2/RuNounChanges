local export = {}

local m_links = require("Module:links")
local put_module = "Module:parse utilities"
local com_module = "Module:it-common"
local affix_module = "Module:affix"
local romance_etymology_module = "Module:romance etymology"
local lang = require("Module:languages").getByCode("it")

local rfind = mw.ustring.find
local rsplit = mw.text.split
local u = mw.ustring.char

local force_cat = false -- set to true for testing


local function glossary_link(entry, text)
	text = text or entry
	return "[[Appendix:Glossary#" .. entry .. "|" .. text .. "]]"
end


local function looks_like_infinitive(term)
	return term:find("[aei]re$")
end


local function form_imperative(imp, inf, parse_err)
	if imp ~= "+" then
		parse_err(("Unrecognized imperative spec '%s'"):format(imp))
	end
	local stem, ending = inf:match("^(.*)([aei]re)$")
	if not stem then
		parse_err(("Unrecognized infinitive '%s', doesn't end in -are, -ere or -ire"):format(inf))
	end
	if ending == "are" then
		return stem .. "a"
	else
		return stem .. "i"
	end
end


local function form_plural(pl, term, parse_err)
	if pl ~= "1" then
		parse_err(("Unrecognized plural spec '%s'"):format(pl))
	end
	-- "Guess" a gender based on the ending. We can't pass in a "?" because then we'll get an error on terms
	-- ending in -a because they have different plurals depending on the gender.
	local gender = term:find("a$") and "f" or "m"
	return require(com_module).make_plural(term, gender)
end


function export.it_verb_obj(frame)
	local data = {
		lang = lang,
		looks_like_infinitive = looks_like_infinitive,
		default_args = {"lavare<t:to wash>", "piatto<t:plates><pl:1>"},
		make_plural = form_plural,
		make_imperative = form_imperative,
	}
	return require(romance_etymology_module).verb_obj(data, frame)
end


function export.it_verb_verb(frame)
	local data = {
		lang = lang,
		looks_like_infinitive = looks_like_infinitive,
		default_args = {"lavare<t:wash>", "asciugare<t:dry>"},
		make_plural = form_plural,
		make_imperative = form_imperative,
	}
	return require(romance_etymology_module).verb_verb(data, frame)
end


function export.it_deverbal(frame)
	local list_with_holes = { list = true, allow_holes = true }
	local params = {
		[1] = {required = true, list = true},
		
		["alt"] = list_with_holes,
		["t"] = list_with_holes,
		["gloss"] = {alias_of = "t", list = true, allow_holes = true},
		["g"] = list_with_holes,
		["id"] = list_with_holes,
		["lit"] = list_with_holes,
		["pos"] = list_with_holes,
		["q"] = list_with_holes,
		["qq"] = list_with_holes,
		-- no tr, ts or sc; not relevant for Italian

		["nocap"] = {type = "boolean"},
		["notext"] = {type = "boolean"},
		["nocat"] = {type = "boolean"},
		["sort"] = {},
		["pagename"] = {}, -- for testing
	}

	local args = require("Module:parameters").process(frame:getParent().args, params)

	if #args[1] == 0 then
		local NAMESPACE = mw.title.getCurrentTitle().nsText
		if NAMESPACE == "Template" then
			table.insert(args[1], "cozzare<t:to collide, to crash>")
			args.pagename = "cozzo"
		else
			error("Internal error: Something went wrong with [[Module:parameters]]; it should not allow zero numbered arguments")
		end
	end

	local pagename = args.pagename or mw.title.getCurrentTitle().subpageText
	local suffix = pagename:match("([aeo])$")
	if not suffix then
		error(("Pagename '%s' does not end in a recognizable deverbal suffix -a, -e or -o"):format(pagename))
	end

	local suffix_obj = m_links.full_link({
		term = "-" .. suffix,
		lang = lang,
		id = "deverbal",
	}, "term")

	for i, term in ipairs(args[1]) do
		local parsed = require(romance_etymology_module).parse_term_with_modifiers(i, term, {
			alt = args.alt[i],
			gloss = args.t[i],
			genders = args.g[i] and rsplit(args.g[i], ",") or nil,
			id = args.id[i],
			pos = args.pos[i],
			lit = args.lit[i],
			q = args.q[i],
			qq = args.qq[i],
		}, false)
		parsed.lang = parsed.lang or lang
		local formatted_part = m_links.full_link(parsed, "term", "allow self link", "respect qualifiers")
		args[1][i] = require(affix_module).concat_parts(lang, {formatted_part, suffix_obj},
			{"deverbals", "terms suffixed with -" .. suffix .. " (deverbal)"},
			args.nocat, args.sort, nil, force_cat) -- FIXME: should we support lit= here?
	end

	result = {}
	local function ins(text)
		table.insert(result, text)
	end

	if not args.notext then
		if args.nocap then
			ins(glossary_link("Appendix:deverbal", "deverbal"))
		else
			ins(glossary_link("Appendix:deverbal", "Deverbal"))
		end
		ins(" from ")
	end

	if #args[1] == 1 then
		ins(args[1][1])
	else
		ins(require("Module:table").serialCommaJoin(args[1], {conj = "or"}))
	end

	return table.concat(result)
end


return export
