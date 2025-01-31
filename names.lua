local export = {}

local m_languages = require("Module:languages")
local m_links = require("Module:links")
local m_utilities = require("Module:utilities")
local m_table = require("Module:table")
local en_utilities_module = "Module:User:Benwing2/en-utilities"
local parameter_utilities_module = "Module:parameter utilities"
local parse_interface_module = "Module:parse interface"
local pron_qualifier_module = "Module:User:Benwing2/pron qualifier"

local enlang = m_languages.getByCode("en")

local rsplit = mw.text.split

local force_cat = true -- for testing

--[=[

FIXME:

1. from=the Bible (DONE)
2. origin=18th century [DONE]
3. popular= (DONE)
4. varoftype= (DONE)
5. eqtype= [DONE]
6. dimoftype= [DONE]
7. from=de:Elisabeth (same language) (DONE)
8. blendof=, blendof2= [DONE]
9. varform, dimform [DONE]
10. from=English < Latin [DONE]
11. usage=rare -> categorize as rare?
12. dimeq= (also vareq=?) [DONE]
13. fromtype= [DONE]
14. <tr:...> and similar params [DONE]
]=]

-- Used in category code; name types which are full-word end-matching substrings of longer name types (e.g. "surnames"
-- of "male surnames", but not "male surnames" of "female surnames" because "male" only matches a part of the word
-- "female") should follow the longer name.
export.personal_name_types = {
	"male surnames", "female surnames", "common-gender surnames", "surnames",
	"patronymics", "matronymics",
}

export.personal_name_type_set = m_table.listToSet(export.personal_name_types)

local given_name_genders = {
	male = {type = "human"},
	female = {type = "human"},
	unisex = {type = "human", cat = {"male given names", "female given names", "unisex given names"}, article = "a"},
	["unknown-gender"] = {type = "human", cat = {}, track = true},
	animal = {type = "animal", track = true},
	dog = {type = "animal"},
	cat = {type = "animal"},
	horse = {type = "animal"},
	cow = {type = "animal"},
}

local function get_given_name_cats(gender, props)
	local cats = props.cat
	if not cats then
		if props.type == "animal" then
			cats = {gender .. " names"}
		else
			cats = {gender .. " given names"}
		end
	end
	return cats
end

do
	local function do_cat(cat)
		if not export.personal_name_type_set[cat] then
			export.personal_name_type_set[cat] = true
			table.insert(export.personal_name_types, cat)
		end
	end
	
	for gender, props in pairs(given_name_genders) do
		local cats = get_given_name_cats(gender, props)
		for _, cat in ipairs(cats) do
			do_cat("diminutives of " .. cat)
			do_cat("augmentatives of " .. cat)
			do_cat(cat)
		end
	end
	
	do_cat("given names")
end

local translit_name_type_list = {
	"surname", "male given name", "female given name", "unisex given name",
	"patronymic"
}
local translit_name_types = m_table.listToSet(translit_name_type_list)

local param_mods = {"t", "alt", "tr", "ts", "pos", "lit", "id", "sc", "g", "q", "eq"}
local param_mod_set = m_table.listToSet(param_mods)


local function track(page)
	require("Module:debug").track("names/" .. page)
end


-- Get raw text, for use in computing the indefinite article. Use get_plaintext() in [[Module:utilities]] and also
-- remove parens that may surround qualifier or label text preceding a term.
local function get_rawtext(text)
	text = m_utilities.get_plaintext(text)
	text = text:gsub("[()%[%]]", "")
	return text
end


--[=[
Parse a term and associated properties. This works with parameters of the form 'Karlheinz' or
'Kunigunde<q:medieval, now rare>' or 'non:Óláfr' or 'ru:Фру́нзе<tr:Frúnzɛ><q:rare>' where the modifying properties
are contained in <...> specifications after the term. `term` is the full parameter value including any angle brackets
and colons; `pname` is the name of the parameter that this value comes from, for error purposes; `deflang` is a
language object used in the return value when the language isn't specified (e.g. in the examples 'Karlheinz' and
'Kunigunde<q:medieval, now rare>' above); `allow_explicit_lang` indicates whether the language can be explicitly given
(e.g. in the examples 'non:Óláfr' or 'ru:Фру́нзе<tr:Frúnzɛ><q:rare>' above).

Normally the return value is an object with properties '.term' (a terminfo object that can be passed to full_link() in
[[Module:links]]) and '.q' (a qualifier). However, if `allow_multiple_terms` is given, multiple comma-separated names
can be given in `term`, and the return value is a list of objects of the form described just above.
]=]
local function parse_term_with_annotations(term, pname, deflang, allow_explicit_lang, allow_multiple_terms)
	local function parse_single_run_with_annotations(run)
		local function parse_err(msg)
			error(msg .. ": " .. pname .. "= " .. table.concat(run))
		end
		if #run == 1 and run[1] == "" then
			error("Blank form for param '" .. pname .. "' not allowed")
		end
		local termobj = {term = {}}
		local lang, form = run[1]:match("^([^%[%]]-):(.*)$")
		if lang and lang ~= "w" then
			if not allow_explicit_lang then
				parse_err("Explicit language '" .. lang .. "' not allowed for this parameter")
			end
			termobj.term.lang = m_languages.getByCode(lang, nil, true) or
				require("Module:languages/errorGetBy").code(lang, pname, true)
			termobj.term.term = form
		else
			termobj.term.lang = deflang
			termobj.term.term = run[1]
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
				local obj_to_set
				if prefix == "q" or prefix == "eq" then
					obj_to_set = termobj
				else
					obj_to_set = termobj.term
				end
				if obj_to_set[prefix] then
					parse_err("Modifier '" .. prefix .. "' occurs twice, second occurrence " .. run[i])
				end
				if prefix == "t" then
					termobj.term.gloss = arg
				elseif prefix == "g" then
					termobj.term.genders = rsplit(arg, ",")
				elseif prefix == "sc" then
					termobj.term.sc = require("Module:scripts").getByCode(arg) or
						require("Module:languages/error")(arg, pname, "script code", nil, "not real lang")
				elseif prefix == "eq" then
					termobj.eq = parse_term_with_annotations(arg, pname .. ".eq", enlang, false, "allow multiple terms")
				else
					obj_to_set[prefix] = arg
				end
			else
				parse_err("Unrecognized prefix '" .. prefix .. "' in modifier " .. run[i])
			end
		end
		return termobj
	end

	local iut = require("Module:inflection utilities")
	local run = iut.parse_balanced_segment_run(term, "<", ">")
	if allow_multiple_terms then
		local comma_separated_runs = iut.split_alternating_runs(run, "%s*,%s*")
		local termobjs = {}
		for _, comma_separated_run in ipairs(comma_separated_runs) do
			table.insert(termobjs, parse_single_run_with_annotations(comma_separated_run))
		end
		return termobjs
	else
		return parse_single_run_with_annotations(run)
	end
end


--[=[
Link a single term. If `do_language_link` is given and a given term's language is English, the link will be constructed
using language_link() in [[Module:links]]; otherwise, with full_link(). Each term in `terms` is an object as returned
by parse_term_with_annotations(), i.e. it contains fields '.term' (a terminfo structure suitable for passing to
full_link() or language_link()), optional '.q' (a qualifier) and optional '.eq' (a list of objects of the same form as
`termobj`).
]=]
local function link_one_term(termobj, do_language_link)
	local link
	if do_language_link and termobj.term.lang:getCode() == "en" then
		link = m_links.language_link(termobj.term)
	else
		link = m_links.full_link(termobj.term)
	end
	if termobj.q then
		link = require("Module:qualifier").format_qualifier(termobj.q) .. " " .. link
	end
	if termobj.eq then
		local eqtext = {}
		for _, eqobj in ipairs(termobj.eq) do
			table.insert(eqtext, link_one_term(eqobj, true))
		end
		link = link .. " [=" .. m_table.serialCommaJoin(eqtext, {conj = "or"}) .. "]"
	end
	return link
end


--[=[
Link the terms in `terms`, and join them using the conjunction in `conj` (defaulting to "or"). Joining is done using
serialCommaJoin() in [[Module:table]], so that e.g. two terms are joined as "TERM or TERM" while three terms are joined
as "TERM, TERM or TERM" with special CSS spans before the final "or" to allow an "Oxford comma" to appear if configured
appropriately. (However, if `conj` is the special value ", ", joining is done directly using that value.)
If `include_langname` is given, the language of the first term will be prepended to the joined terms. If
`do_language_link` is given and a given term's language is English, the link will be constructed using language_link()
in [[Module:links]]; otherwise, with full_link(). Each term in `terms` is an object as returned by
parse_term_with_annotations(), i.e. it contains fields '.term' (a terminfo structure suitable for passing to full_link()
or language_link()), optional '.q' (a qualifier) and optional '.eq' (a list of objects of the same form as in `terms`).
]=]
local function join_terms(terms, include_langname, do_language_link, conj)
	local links = {}
	local langnametext
	for _, termobj in ipairs(terms) do
		if include_langname and not langnametext then
			langnametext = termobj.term.lang:getCanonicalName() .. " "
		end
		table.insert(links, link_one_term(termobj, do_language_link))
	end
	local joined_terms
	if conj == ", " then
		joined_terms = table.concat(links, conj)
	else
		joined_terms = m_table.serialCommaJoin(links, {conj = conj or "or"})
	end
	return (langnametext or "") .. joined_terms
end


--[=[
Gather the parameters for multiple names and link each name using full_link() (for foreign names) or language_link()
(for English names), joining the names using serialCommaJoin() in [[Module:table]] with the conjunction `conj`
(defaulting to "or"). (However, if `conj` is the special value ", ", joining is done directly using that value.)
This can be used, for example, to fetch and join all the masculine equivalent names for a feminine given name. Each
name is specified using parameters beginning with `pname` in `args`, e.g. "m", "m2", "m3", etc. `lang` is a language
object specifying the language of the names (defaulting to English), for use in linking them. If `allow_explicit_lang`
is given, the language of the terms can be specified explicitly by prefixing a term with a language code, e.g.
'sv:Björn' or 'la:[[Nicolaus|Nīcolāī]]'. This function assumes that the parameters have already been parsed by
[[Module:parameters]] and gathered into lists, so that e.g. all "mN" parameters are in a list in args["m"].
]=]
local function join_names(lang, args, pname, conj, allow_explicit_lang)
	local termobjs = {}
	local do_language_link = false
	if not lang then
		lang = enlang
		do_language_link = true
	end

	for i, term in ipairs(args[pname]) do
		table.insert(termobjs, parse_term_with_annotations(term, pname .. (i == 1 and "" or i), lang, allow_explicit_lang))
	end
	return join_terms(termobjs, nil, do_language_link, conj), #termobjs
end


local function get_eqtext(args)
	local eqsegs = {}
	local lastlang = nil
	local last_eqseg = {}
	for i, term in ipairs(args.eq) do
		local termobj = parse_term_with_annotations(term, "eq" .. (i == 1 and "" or i), enlang, "allow explicit lang")
		local termlang = termobj.term.lang:getCode()
		if lastlang and lastlang ~= termlang then
			if #last_eqseg > 0 then
				table.insert(eqsegs, last_eqseg)
			end
			last_eqseg = {}
		end
		lastlang = termlang
		table.insert(last_eqseg, termobj)
	end
	if #last_eqseg > 0 then
		table.insert(eqsegs, last_eqseg)
	end
	local eqtextsegs = {}
	for _, eqseg in ipairs(eqsegs) do
		table.insert(eqtextsegs, join_terms(eqseg, "include langname"))
	end
	return m_table.serialCommaJoin(eqtextsegs, {conj = "or"})
end


local function get_fromtext(lang, args)
	local catparts = {}
	local fromsegs = {}
	local i = 1

	local function parse_from(from)
		local unrecognized = false
		local prefix, suffix
		if from == "surnames" or from == "given names" or from == "nicknames" or from == "place names" or from == "common nouns" or from == "month names" then
			prefix = "transferred from the "
			suffix = from:gsub("s$", "")
			table.insert(catparts, from)
		elseif from == "patronymics" or from == "matronymics" or from == "coinages" then
			prefix = "originating "
			suffix = "as a " .. from:gsub("s$", "")
			table.insert(catparts, from)
		elseif from == "occupations" or from == "ethnonyms" then
			prefix = "originating "
			suffix = "as an " .. from:gsub("s$", "")
			table.insert(catparts, from)
		elseif from == "the Bible" then
			prefix = "originating "
			suffix = "from the Bible"
			table.insert(catparts, from)
		else
			prefix = "from "
			if from:find(":") then
				local termobj = parse_term_with_annotations(from, "from" .. (i == 1 and "" or i), lang, "allow explicit lang")
				local fromlangname = ""
				if termobj.term.lang:getCode() ~= lang:getCode() then
					-- If name is derived from another name in the same language, don't include lang name after text "from "
					-- or create a category like "German male given names derived from German".
					local canonical_name = termobj.term.lang:getCanonicalName()
					fromlangname = canonical_name .. " "
					table.insert(catparts, canonical_name)
				end
				suffix = fromlangname .. link_one_term(termobj)
			else
				local family = from:match("^(.+) languages$") or
					from:match("^.+ Languages$") or
					from:match("^.+ [Ll]ects$")
				if family then
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
		local froms = rsplit(rawfrom, "%s+<%s+")
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
			local full_suffix = first_suffixpart .. " [in turn " .. table.concat(rest_suffixparts, ", in turn ") .. "]"
			last_fromseg = {prefix = "", has_multiple_froms = true, suffixes = {full_suffix}}
		end
		i = i + 1
	end
	table.insert(fromsegs, last_fromseg)
	local fromtextsegs = {}
	for _, fromseg in ipairs(fromsegs) do
		table.insert(fromtextsegs, fromseg.prefix .. m_table.serialCommaJoin(fromseg.suffixes, {conj = "or"}))
	end
	return m_table.serialCommaJoin(fromtextsegs, {conj = "or"}), catparts
end


local function parse_given_name_genders(genderspec)
	if given_name_genders[genderspec] then -- optimization
		return {{
			type = genderspec,
			props = given_name_genders[genderspec],
		}}, given_name_genders[genderspec].type == "animal"
	end
	local genders = {}
	local is_animal = nil
	local param_mods = require(parameter_utilities_module).construct_param_mods {
		{group = {"l", "q", "ref"}},
		{param = {"text", "article"}},
	}
	local function generate_obj(term, parse_err)
		if not given_name_genders[term] then
			local valid_genders = {}
			for k, _ in pairs(given_name_genders) do
				table.insert(valid_genders, k)
			end
			table.sort(valid_genders)
			parse_err(("Unrecognized gender '%s': valid genders are %s"):format(
				term, table.concat(valid_genders, ", ")))
		end
		return {
			type = term,
			props = given_name_genders[term],
		}
	end
	local retval = require(parse_interface_module).parse_inline_modifiers(genderspec, {
		param_mods = param_mods,
		paramname = "2",
		generate_obj = generate_obj,
		splitchar = ",",
	})
	for _, spec in ipairs(retval) do
		local this_is_animal = spec.props.type == "animal"
		if is_animal == nil then
			is_animal = this_is_animal
		elseif is_animal ~= this_is_animal then
			error("Can't mix animal and human genders")
		end
	end
	return retval, is_animal
end


local function generate_given_name_genders(lang, genders)
	local parts = {}
	for _, spec in ipairs(genders) do
		local text
		if spec.text then
			-- NOTE: This assumes no % sign in the gender type, which seems safe.
			text = spec.text:gsub("%+", spec.type)
		else
			text = spec.type
		end
		if spec.q and spec.q[1] or spec.qq and spec.qq[1] or spec.l and spec.l[1] or spec.ll and spec.ll[1] or
			spec.refs and spec.refs[1] then
			text = require(pron_qualifier_module).format_qualifiers {
				lang = data.lang,
				text = text,
				q = spec.q,
				qq = spec.qq,
				l = spec.l,
				ll = spec.ll,
				refs = spec.refs,
				raw = true,
			}
		end
		table.insert(parts, text)
	end
	local retval = m_table.serialCommaJoin(parts, {conj = "or"})
	local article = genders[1].article
	if not article and not genders[1].text and not genders[1].q and not genders[1].l then
		article = genders[1].props.article
	end
	if not article then
		article = require(en_utilities_module).get_indefinite_article(get_rawtext(retval))
	end
	return retval, article
end


-- The entry point for {{given name}}.
function export.given_name(frame)
	local parent_args = frame:getParent().args
	local compat = parent_args.lang
	local offset = compat and 0 or 1

	local lang_index = compat and "lang" or 1

	local list = {list = true}
	local alias_of_dimof = {alias_of = "dimof", list = true}
	local alias_of_dimoftype = {alias_of = "dimoftype"}
	local alias_of_augof = {alias_of = "augof", list = true}
	local alias_of_augoftype = {alias_of = "augoftype"}
	local args = require("Module:parameters").process(parent_args, {
		[lang_index] = {required = true, type = "language", default = "und"},
		["gender"] = {default = "unknown-gender"},
		[1 + offset] = {alias_of = "gender", default = "unknown-gender"},
		["or"] = true, -- former second gender; ignored; FIXME: convert uses
		["orq"] = true, -- second gender qualifier; ignored; FIXME: convert uses
		["usage"] = true,
		["origin"] = true,
		["popular"] = true,
		["populartype"] = true,
		["meaning"] = list,
		["meaningtype"] = true,
		["addl"] = true,
		["q"] = {alias_of = "addl"}, -- FIXME: obsolete me
		-- initial article: A or An
		["A"] = true,
		["sort"] = true,
		["from"] = list,
		[2 + offset] = {alias_of = "from", list = true},
		["fromtype"] = true,
		["xlit"] = list,
		["eq"] = list,
		["eqtype"] = true,
		["varof"] = list,
		["varoftype"] = true,
		["var"] = {alias_of = "varof", list = true},
		["vartype"] = {alias_of = "varoftype"},
		["varform"] = list,
		["dimof"] = list,
		["dimoftype"] = true,
		["dim"] = alias_of_dimof,
		["dimtype"] = alias_of_dimoftype,
		["diminutive"] = alias_of_dimof,
		["diminutivetype"] = alias_of_dimoftype,
		["dimform"] = list,
		["augof"] = list,
		["augoftype"] = true,
		["aug"] = alias_of_augof,
		["augtype"] = alias_of_augoftype,
		["augmentative"] = alias_of_augof,
		["augmentativetype"] = alias_of_augoftype,
		["augform"] = list,
		["blend"] = list,
		["blendtype"] = true,
		["m"] = list,
		["mtype"] = true,
		["f"] = list,
		["ftype"] = true,
	})

	local textsegs = {}
	local lang = args[lang_index]
	local langcode = lang:getCode()

	local function fetch_typetext(param)
		return args[param] and args[param] .. " " or ""
	end

	local genders, is_animal = parse_given_name_genders(args.gender)

	local dimoftext, numdims = join_names(lang, args, "dimof")
	local augoftext, numaugs = join_names(lang, args, "augof")
	local xlittext = join_names(nil, args, "xlit")
	local blendtext = join_names(lang, args, "blend", "and")
	local varoftext = join_names(lang, args, "varof")
	local mtext = join_names(lang, args, "m")
	local ftext = join_names(lang, args, "f")
	local varformtext, numvarforms = join_names(lang, args, "varform", ", ")
	local dimformtext, numdimforms = join_names(lang, args, "dimform", ", ")
	local augformtext, numaugforms = join_names(lang, args, "augform", ", ")
	local meaningsegs = {}
	for _, meaning in ipairs(args.meaning) do
		table.insert(meaningsegs, '“' .. meaning .. '”')
	end
	local meaningtext = m_table.serialCommaJoin(meaningsegs, {conj = "or"})
	local eqtext = get_eqtext(args)

	local function ins(txt)
		table.insert(textsegs, txt)
	end
	local dimtype = args.dimtype
	local augtype = args.augtype
	if numdims > 0 then
		ins((dimtype and dimtype .. " " or "") .. "[[diminutive]]" ..
			(xlittext ~= "" and ", " .. xlittext .. "," or "") .. " of the ")
	elseif numaugs > 0 then
		ins((augtype and augtype .. " " or "") .. "[[augmentative]]" ..
			(xlittext ~= "" and ", " .. xlittext .. "," or "") .. " of the ")
	end
	local article = args.A
	if not article and textsegs[1] then
		article = require(en_utilities_module).get_indefinite_article(textsegs[1])
	end
	if not is_animal then
		local gendertext, gender_article = generate_given_name_genders(lang, genders)
		article = article or gender_article
		ins(gendertext)
		ins(" ")
	end
	ins((numdims > 1 or numaugs > 1) and "[[given name|given names]]" or "[[given name]]")
	article = article or "a" -- if no article set yet, it's "a" based on "given name"
	if langcode == "en" then
		article = mw.getContentLanguage():ucfirst(article)
	end

	local need_comma = false
	if numdims > 0 then
		ins(" " .. dimoftext)
		need_comma = not is_animal
	elseif numaugs > 0 then
		ins(" " .. augoftext)
		need_comma = not is_animal
	elseif xlittext ~= "" then
		ins(", " .. xlittext)
		need_comma = true
	end

	if is_animal then
		if need_comma then
			ins(",")
		end
		need_comma = true
		ins(" for ")
		local gendertext, gender_article = generate_given_name_genders(lang, genders)
		ins(gender_article)
		ins(" ")
		ins(gendertext)
	end

	local from_catparts = {}
	if #args.from > 0 then
		if need_comma then
			ins(",")
		end
		need_comma = true
		ins(" " .. fetch_typetext("fromtype"))
		local textseg, this_catparts = get_fromtext(lang, args)
		for _, catpart in ipairs(this_catparts) do
			m_table.insertIfNot(from_catparts, catpart)
		end
		ins(textseg)
	end
	
	if meaningtext ~= "" then
		if need_comma then
			ins(",")
		end
		need_comma = true
		ins(" " .. fetch_typetext("meaningtype") .. "meaning " .. meaningtext)
	end
	if args.origin then
		if need_comma then
			ins(",")
		end
		need_comma = true
		ins(" of " .. args.origin .. " origin")
	end
	if args.usage then
		if need_comma then
			ins(",")
		end
		need_comma = true
		ins(" of " .. args.usage .. " usage")
	end
	if varoftext ~= "" then
		ins(", " ..fetch_typetext("varoftype") .. "variant of " .. varoftext)
	end
	if blendtext ~= "" then
		ins(", " .. fetch_typetext("blendtype") .. "blend of " .. blendtext)
	end
	if args.popular then
		ins(", " .. fetch_typetext("populartype") .. "popular " .. args.popular)
	end
	if mtext ~= "" then
		ins(", " .. fetch_typetext("mtype") .. "masculine equivalent " .. mtext)
	end
	if ftext ~= "" then
		ins(", " .. fetch_typetext("ftype") .. "feminine equivalent " .. ftext)
	end
	if eqtext ~= "" then
		ins(", " .. fetch_typetext("eqtype") .. "equivalent to " .. eqtext)
	end
	if args.addl then
		ins(", " .. args.addl)
	end
	if varformtext ~= "" then
		ins("; variant form" .. (numvarforms > 1 and "s" or "") .. " " .. varformtext)
	end
	if dimformtext ~= "" then
		ins("; diminutive form" .. (numdimforms > 1 and "s" or "") .. " " .. dimformtext)
	end
	if augformtext ~= "" then
		ins("; augmentative form" .. (numaugforms > 1 and "s" or "") .. " " .. augformtext)
	end
	textsegs = "<span class='use-with-mention'>" .. article .. " " .. table.concat(textsegs) .. "</span>"

	local categories = {}
	local langname = lang:getCanonicalName() .. " "
	local function insert_cats(dimaugof)
		if dimaugof == "" and genders[1].props.type == "human" then
			-- No category such as "English diminutives of given names"
			table.insert(categories, langname .. "given names")
		end
		local function insert_cat(cat)
			table.insert(categories, langname .. dimaugof .. cat)
			for _, catpart in ipairs(from_catparts) do
				table.insert(categories, langname .. dimaugof .. cat .. "  from " .. catpart)
			end
		end
		for _, spec in ipairs(genders) do
			local typ = spec.type
			if spec.props.track then
				track(typ)
			end
			local cats = get_given_name_cats(spec.type, spec.props)
			for _, cat in ipairs(cats) do
				insert_cat(cat)
			end
		end
	end
	insert_cats("")
	if numdims > 0 then
		insert_cats("diminutives of ")
	elseif numaugs > 0 then
		insert_cats("augmentatives of ")
	end

	return textsegs .. m_utilities.format_categories(categories, lang, args.sort, nil, force_cat)
end

-- The entry point for {{surname}}.
function export.surname(frame)
	local parent_args = frame:getParent().args
	local compat = parent_args.lang
	local offset = compat and 0 or 1

	if parent_args.dot or parent_args.nodot then
		error("dot= and nodot= are no longer supported in [[Template:surname]] because a trailing period is no longer added by "
				.. "default; if you want it, add it explicitly after the template")
	end

	local lang_index = compat and "lang" or 1
	
	local list = {list = true}
	local args = require("Module:parameters").process(parent_args, {
		[lang_index] = {required = true, type = "language", default = "und"},
		["g"] = list, -- gender(s)
		[1 + offset] = true, -- adjective/qualifier
		["usage"] = true,
		["origin"] = true,
		["popular"] = true,
		["populartype"] = true,
		["meaning"] = list,
		["meaningtype"] = true,
		["q"] = true,
		-- initial article: by default A or An (English), a or an (otherwise)
		["A"] = true,
		["sort"] = true,
		["from"] = list,
		["fromtype"] = true,
		["xlit"] = list,
		["eq"] = list,
		["eqtype"] = true,
		["varof"] = list,
		["varoftype"] = true,
		["var"] = {alias_of = "varof", list = true},
		["vartype"] = {alias_of = "varoftype"},
		["varform"] = list,
		["blend"] = list,
		["blendtype"] = true,
		["m"] = list,
		["mtype"] = true,
		["f"] = list,
		["ftype"] = true,
		["nocat"] = {type = "boolean"},
	})
	
	local textsegs = {}
	local lang = args[lang_index]
	local langcode = lang:getCode()

	local function fetch_typetext(param)
		return args[param] and args[param] .. " " or ""
	end

	local adj = args[1 + offset]
	local xlittext = join_names(nil, args, "xlit")
	local blendtext = join_names(lang, args, "blend", "and")
	local varoftext = join_names(lang, args, "varof")
	local mtext = join_names(lang, args, "m")
	local ftext = join_names(lang, args, "f")
	local varformtext, numvarforms = join_names(lang, args, "varform", ", ")
	local meaningsegs = {}
	for _, meaning in ipairs(args.meaning) do
		table.insert(meaningsegs, '"' .. meaning .. '"')
	end
	local meaningtext = m_table.serialCommaJoin(meaningsegs, {conj = "or"})
	local eqtext = get_eqtext(args)

	table.insert(textsegs, "<span class='use-with-mention'>")

	local genders = {}
	for _, g in ipairs(args.g) do
		local origg = g
		if g == "unknown" or g == "unknown gender" or g == "?" then
			g = "unknown-gender"
		elseif g == "unisex" or g == "common gender" or g == "c" then
			g = "common-gender"
		elseif g == "m" then
			g = "male"
		elseif g == "f" then
			g = "female"
		end
		if g == "unknown-gender" then
			track("unknown gender")
		elseif g ~= "male" and g ~= "female" and g ~= "common-gender" then
			error("Unrecognized gender: " .. origg)
		end
		table.insert(genders, g)
	end

	-- If gender is supplied, it goes before the specified adjective in adj=. The only value of gender that uses "an" is
	-- "unknown-gender" (note that "unisex" wouldn't use it but in any case we map "unisex" to "common-gender"). If gender
	-- isn't supplied, look at the first letter of the value of adj= if supplied; otherwise, the article is always "a"
	-- because the word "surname" follows. Capitalize "A"/"An" if English.
	local article
	if args.A then
		article = args.A
	else
		article = #genders > 0 and genders[1] == "unknown-gender" and "an" or
			#genders == 0 and adj and require(en_utilities_module).get_indefinite_article(adj) or
			"a"
		if langcode == "en" then
			article = mw.getContentLanguage():ucfirst(article)
		end
	end
	table.insert(textsegs, article .. " ")

	if #genders > 0 then
		table.insert(textsegs, table.concat(genders, " or ") .. " ")
	end
	if adj then
		table.insert(textsegs, adj .. " ")
	end
	table.insert(textsegs, "[[surname]]")
	local need_comma = false
	if xlittext ~= "" then
		table.insert(textsegs, ", " .. xlittext)
		need_comma = true
	end
	local from_catparts = {}
	if #args.from > 0 then
		if need_comma then
			table.insert(textsegs, ",")
		end
		need_comma = true
		table.insert(textsegs, " " .. fetch_typetext("fromtype"))
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
	if args.origin then
		if need_comma then
			table.insert(textsegs, ",")
		end
		need_comma = true
		table.insert(textsegs, " of " .. args.origin .. " origin")
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
	if args.q then
		table.insert(textsegs, ", " .. args.q)
	end
	if varformtext ~= "" then
		table.insert(textsegs, "; variant form" .. (numvarforms > 1 and "s" or "") .. " " .. varformtext)
	end
	table.insert(textsegs, "</span>")

	local text = table.concat(textsegs, "")
	if args.nocat then
		return text
	end

	local categories = {}
	local langname = lang:getCanonicalName() .. " "
	local function insert_cats(g)
		g = g and g .. " " or ""
		table.insert(categories, langname .. g .. "surnames")
		for _, catpart in ipairs(from_catparts) do
			table.insert(categories, langname .. g .. "surnames from " .. catpart)
		end
	end
	insert_cats(nil)
	local function insert_cats_gender(g)
		if g == "unknown-gender" then
			return
		end
		if g == "common-gender" then
			insert_cats_gender("male")
			insert_cats_gender("female")
		end
		insert_cats(g)
	end
	for _, g in ipairs(genders) do
		insert_cats_gender(g)
	end

	return text .. m_utilities.format_categories(categories, lang, args.sort, nil, force_cat)
end

-- The entry point for {{name translit}}, {{name respelling}}, {{name obor}} and {{foreign name}}.
function export.name_translit(frame)
	local boolean = {type = "boolean"}
	local list_allow_holes = {list = true, allow_holes = true}

	local iargs = require("Module:parameters").process(frame.args, {
		["desctext"] = {required = true},
		["obor"] = boolean,
		["foreign_name"] = boolean,
	})

	local args = require("Module:parameters").process(frame:getParent().args, {
		[1] = {required = true, type = "language", default = "en"},
		[2] = {required = true, type = "language", sublist = true, default = "ru"},
		[3] = {list = true},
		["type"] = {required = true, list = true, default = "patronymic"},
		["alt"] = list_allow_holes,
		["t"] = list_allow_holes,
		["gloss"] = {list = true, alias_of = "t", allow_holes = true},
		["tr"] = list_allow_holes,
		["ts"] = list_allow_holes,
		["id"] = list_allow_holes,
		["sc"] = {type = "script", list = true, allow_holes = true},
		["g"] = list_allow_holes,
		["q"] = list_allow_holes,
		["xlit"] = list_allow_holes,
		["eq"] = list_allow_holes,
		["dim"] = boolean,
		["aug"] = boolean,
		["nocap"] = boolean,
		["sort"] = true,
		["pagename"] = true,
	})
	local lang = args[1]
	local sources = args[2]

	local nametypes = {}
	for _, typearg in ipairs(args["type"]) do
		for _, ty in ipairs(rsplit(typearg, "%s*,%s*")) do
			if not translit_name_types[ty] then
				local quoted_types = {}
				for _, nametype in ipairs(translit_name_type_list) do
					table.insert(quoted_types, "'" .. nametype .. "'")
				end
				error("Unrecognized type '" .. ty .. "': It should be one of " ..
					m_table.serialCommaJoin(quoted_types, {conj = "or"}))
			end
			table.insert(nametypes, ty)
		end
	end

	-- Find the maximum index among any of the list parameters, to determine how many names are given.
	local maxmaxindex = #args[3]
	for _, v in pairs(args) do
		if type(v) == "table" and v.maxindex and v.maxindex > maxmaxindex then
			maxmaxindex = v.maxindex
		end
	end

	local SUBPAGENAME = args.pagename or mw.title.getCurrentTitle().subpageText
	
	local textsegs = {}
	table.insert(textsegs, "<span class='use-with-mention'>")
	local desctext = iargs.desctext
	if not args.nocap then
		desctext = mw.getContentLanguage():ucfirst(desctext)
	end
	table.insert(textsegs, desctext .. " ")
	if not iargs.foreign_name then
		table.insert(textsegs, "of ")
	end
	local langsegs = {}
	for i, source in ipairs(sources) do
		local sourcename = source:getCanonicalName()
		local function get_source_link()
			local term_to_link = args[3][1] or SUBPAGENAME
			-- We link the language name to either the first specified name or the pagename, in the following circumstances:
			-- (1) More than one language was given along with at least one name; or
			-- (2) We're handling {{foreign name}} or {{name obor}}, and no name was given.
			-- The reason for (1) is that if more than one language was given, we want a link to the name
			-- in each language, as the name that's displayed is linked only to the first specified language.
			-- However, if only one language was given, linking the language to the name is redundant.
			-- The reason for (2) is that {{foreign name}} is often used when the name in the destination language
			-- is spelled the same as the name in the source language (e.g. [[Clinton]] or [[Obama]] in Italian),
			-- and in that case no name will be explicitly specified but we still want a link to the name in the
			-- source language. The reason we restrict this to {{foreign name}} or {{name obor}}, not to {{name translit}}
			-- or {{name respelling}}, is that {{name translit}} and {{name respelling}} ought to be used for names
			-- spelled differently in the destination language (either transliterated or respelled), so assuming the
			-- pagename is the name in the source language is wrong.
			if args[3][1] and #sources > 1 or (iargs.foreign_name or iargs.obor) and not args[3][1] then
				return m_links.language_link{
					lang = sources[i], term = term_to_link, alt = sourcename, tr = "-"
				}
			else
				return sourcename
			end
		end
		
		if i == 1 and not iargs.foreign_name then
			-- If at least one name is given, we say "A transliteration of the LANG surname FOO", linking LANG to FOO.
			-- Otherwise we say "A transliteration of a LANG surname".
			if maxmaxindex > 0 then
				table.insert(langsegs, "the " .. get_source_link())
			else
				table.insert(langsegs, require(en_utilities_module).add_indefinite_article(sourcename))
			end
		else
			table.insert(langsegs, get_source_link())
		end
	end
	local langseg_text = m_table.serialCommaJoin(langsegs, {conj = "or"})
	local augdim_text
	if args.dim then
		augdim_text = " [[diminutive]]"
	elseif args.aug then
		augdim_text = " [[augmentative]]"
	else
		augdim_text = ""
	end
	local nametype_text = m_table.serialCommaJoin(nametypes) .. augdim_text

	if not iargs.foreign_name then
		table.insert(textsegs, langseg_text .. " ")
		table.insert(textsegs, nametype_text)
		if maxmaxindex > 0 then
			table.insert(textsegs, " ")
		end
	else
		table.insert(textsegs, nametype_text)
		table.insert(textsegs, " in " .. langseg_text)
		if maxmaxindex > 0 then
			table.insert(textsegs, ", ")
		end
	end

	local names = {}
	local embedded_comma = false

	for i = 1, maxmaxindex do
		local sc = args["sc"][i]
		
		local terminfo = {
			lang = sources[1], term = args[3][i], alt = args["alt"][i], id = args["id"][i], sc = sc,
			tr = args["tr"][i], ts = args["ts"][i], gloss = args["t"][i],
			genders = args["g"][i] and rsplit(args["g"][i], ",") or {}
		}
		local linked_term = m_links.full_link(terminfo, "term")
		if args["q"][i] then
			linked_term = require("Module:qualifier").format_qualifier(args["q"][i]) .. " " .. linked_term
		end
		if args["xlit"][i] then
			embedded_comma = true
			linked_term = linked_term .. ", " .. m_links.language_link{ lang = enlang, term = args["xlit"][i] }
		end
		if args["eq"][i] then
			embedded_comma = true
			linked_term = linked_term .. ", equivalent to " .. m_links.language_link{ lang = enlang, term = args["eq"][i] }
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
	for _, nametype in ipairs(nametypes) do
		local function insert_cats(dimaugof)
			local function insert_cats_type(ty)
				if ty == "unisex given name" then
					insert_cats_type("male given name")
					insert_cats_type("female given name")
				end
				for _, source in ipairs(sources) do
					table.insert(categories, lang:getFullName() .. " renderings of " .. source:getCanonicalName() .. " " .. dimaugof .. ty .. "s")
					table.insert(categories, lang:getFullName() .. " terms derived from " .. source:getCanonicalName())
					table.insert(categories, lang:getFullName() .. " terms borrowed from " .. source:getCanonicalName())
					if iargs.obor then
						table.insert(categories, lang:getFullName() .. " orthographic borrowings from " .. source:getCanonicalName())
					end
					if source:getCode() ~= source:getFullCode() then
						-- etymology language
						table.insert(categories, lang:getFullName() .. " renderings of " .. source:getFullName() .. " " .. dimaugof .. ty .. "s")
					end
				end
			end
			insert_cats_type(nametype)
		end
		insert_cats("")
		if args.dim then
			insert_cats("diminutives of ")
		end
		if args.aug then
			insert_cats("augmentatives of ")
		end
	end

	return table.concat(textsegs, "") ..
		m_utilities.format_categories(categories, lang, args.sort, nil, force_cat)
end

return export
