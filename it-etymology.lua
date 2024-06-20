local export = {}

local m_links = require("Module:links")
local affix_module = "Module:affix"
local com_module = "Module:it-common"
local parameter_utilities_module = "Module:parameter utilities"
local romance_etymology_module = "Module:romance etymology"
local table_module = "Module:table"

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
	local parent_args = frame:getParent().args

	local params = {
		[1] = {required = true, list = true, disallow_holes = true},
		["nocap"] = {type = "boolean"},
		["notext"] = {type = "boolean"},
		["nocat"] = {type = "boolean"},
		["sort"] = {},
		["pagename"] = {}, -- for testing
	}

    local m_param_utils = require(parameter_utilities_module)
	local param_mods = m_param_utils.construct_param_mods {
		{set = "link", exclude = {"tr", "ts", "sc"}}, -- tr, ts, sc not relevant for Italian
		-- for compatibility (at least for q/qq); FIXME: consider changing?
		{set = {"q", "l", "ref"}, separate_no_index = false},
	}
	m_param_utils.augment_params_with_modifiers(params, param_mods)

	local args = require(parameters_module).process(parent_args, params)

	if not args[1][1] then
		local NAMESPACE = mw.title.getCurrentTitle().nsText
		if NAMESPACE == "Template" then
			table.insert(args[1], "cozzare<t:to collide, to crash>")
			args.pagename = "cozzo"
		else
			error("Internal error: Something went wrong with [[Module:parameters]]; it should not allow zero numbered arguments")
		end
	end

	local items = m_param_utils.process_list_arguments {
		args = args,
		param_mods = param_mods,
		termarg = 1,
		parse_lang_prefix = true,
		track_module = "it-etymology",
		lang = lang,
	}

	local pagename = args.pagename or mw.loadData("Module:headword/data").pagename
	local suffix = pagename:match("([aeo])$")
	if not suffix then
		error(("Pagename '%s' does not end in a recognizable deverbal suffix -a, -e or -o"):format(pagename))
	end

	local suffix_obj = m_links.full_link({
		term = "-" .. suffix,
		lang = lang,
		id = "deverbal",
	}, "term")

	for i, item in ipairs(items) do
		local formatted_part = m_links.full_link(parsed, "term", "allow self link", "respect qualifiers")
		items[i] = require(affix_module).join_formatted_parts {
			data = {
				lang = lang,
				nocat = args.nocat,
				sort_key = args.sort,
				-- FIXME: should we support lit= here?
				force_cat = force_cat,
			},
			parts_formatted = {formatted_part, suffix_obj},
			categories = {"deverbals", "terms suffixed with -" .. suffix .. " (deverbal)"},
		}
	end

	local result = {}
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

	if #items == 1 then
		ins(items[1])
	else
		ins(require(table_module).serialCommaJoin(items, {conj = "or"}))
	end

	return table.concat(result)
end


return export
