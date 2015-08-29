--[=[
	This module contains functions for creating inflection tables for Russian
	adjectives.

	Arguments:
		1: stem
		2: declension type (usually just the ending)
		3 or short_m: masculine singular short form (if exists)
		4 or short_n: neuter singular short form (if exists)
		5 or short_f: feminine singular short form (if exists)
		6 or short_p: plural short form (if exists)
		suffix: any suffix to attach unchanged to the end of each form
		notes: Notes to add to the end of the table
		title: Override the title
		CASE_NUMGEN: Override a given form; see abbreviations below

	Case abbreviations:
		nom: nominative
		gen: genitive
		dat: dative
		acc: accusative
		ins: instrumental
		pre: prepositional
		par: partitive
		loc: locative
		voc: vocative
		
	Number/gender abbreviations:
		m: masculine
		n: neuter
		f: feminine
		p: plural
		mp: masculine plural (old-style tables only)
]=]--

local m_utilities = require("Module:utilities")
local m_utils = require("Module:utils")
local m_links = require("Module:links")
local com = require("Module:ru-common")
local strutils = require("Module:string utilities")
local m_debug = require("Module:debug")

local export = {}

local lang = require("Module:languages").getByCode("ru")

local declensions = {}
local declensions_old = {}
local decline = nil
local cases = nil
local old_cases = nil

local velar = {
	["г"] = true,
	["к"] = true,
	["х"] = true,
}

local function track(page)
	m_debug.track("ru-adjective/" .. page)
	return true
end

local function tracking_code(decl_class, args)
	local hint_types = com.get_stem_trailing_letter_type(args[1])
	local function dotrack(prefix)
		track(decl_class)
		for _, hint_type in ipairs(hint_types) do
			track(hint_type)
			track(decl_class .. "/" .. hint_type)
		end
	end
	dotrack("")
	if args[3] and args[3] ~= args[1] then
		track("short")
		dotrack("short/")
	end
	for _, case in ipairs(old_cases) do
		if args[case] then
			track("irreg/" .. case)
			-- questionable use: dotrack("irreg/" .. case .. "/")
		end
	end
end

local function do_show(frame, old, manual)
	PAGENAME = mw.title.getCurrentTitle().text
	SUBPAGENAME = mw.title.getCurrentTitle().subpageText
	NAMESPACE = mw.title.getCurrentTitle().nsText

	local args = {}
	--cloning parent's args while also assigning nil to empty strings
	for pname, param in pairs(frame:getParent().args) do
		if param == "" then args[pname] = nil
        else args[pname] = param
        end
	end

	if manual then
		args[1] = ""
	elseif not args[1] then
		error("Stem (first argument) must be specified")
	end
	local declension_type = manual and "-" or args[2]
	local short_forms_allowed = manual and true or
		declension_type == "ый" or declension_type == "ой" or declension_type == (old and "ій" or "ий")
	args[3] = args[3] or (not short_forms_allowed and args[1]) or nil
	args[0] = com.make_unstressed_once(args[1])
	args[2] = args[3] and com.make_unstressed_once(args[3])

	args["hint"] = manual and "" or mw.ustring.sub(args[1], -1)
	if velar[args["hint"]] and declension_type == (old and "ій" or "ий") then
		declension_type = "ый"
	end

	args["suffix"] = args["suffix"] or ""
	args["old"] = old
	-- HACK: Escape * at beginning of line so it doesn't show up
	-- as a list entry. Many existing templates use * for footnotes.
	-- FIXME: We should maybe do this in {{ru-adj-table}} instead.
	if args["notes"] then
		args["notes"] = mw.ustring.gsub(args["notes"], "^%*", "&#42;")
	end

	args["categories"] = {}
	-- FIXME: For compatibility with old {{temp|ru-adj7}}, {{temp|ru-adj8}},
	-- {{temp|ru-adj9}}; maybe there's a better way.
	if m_utils.contains({"ьій", "ьий", "short", "mixed", "ъ-short", "ъ-mixed"}, declension_type) then
		table.insert(args["categories"], "Russian possessive adjectives")
	end

	local decls = old and declensions_old or declensions
	if not decls[declension_type] then
		error("Unrecognized declension type " .. declension_type)
	end

	tracking_code(declension_type, args)

	decline(args, decls[declension_type], declension_type == "ой", short_forms_allowed)

	return make_table(args) .. m_utilities.format_categories(args["categories"], lang)
end

-- The main entry point for modern declension tables.
function export.show(frame)
	return do_show(frame, false)
end

-- The main entry point for old declension tables.
function export.show_old(frame)
	return do_show(frame, true)
end

-- The main entry point for manual declension tables.
function export.show_manual(frame)
	return do_show(frame, false, "manual")
end

-- The main entry point for manual old declension tables.
function export.show_manual_old(frame)
	return do_show(frame, true, "manual")
end

-- Entry point for use in Module:ru-noun.
function export.get_nominal_decl(decl, gender, old)
	d = old and declensions_old[decl] or declensions[decl]
	n = {}
	if gender == "m" then
		n.nom_sg = d.nom_m
		n.gen_sg = d.gen_m
		n.dat_sg = d.dat_m
		n.ins_sg = d.ins_m
		n.pre_sg = d.pre_m
	elseif gender == "f" then
		n.nom_sg = d.nom_f
		n.gen_sg = d.gen_f
		n.dat_sg = d.dat_f
		n.acc_sg = d.acc_f
		n.ins_sg = d.ins_f
		n.pre_sg = d.pre_f
	elseif gender == "n" then
		n.nom_sg = d.nom_n
		n.gen_sg = d.gen_m
		n.dat_sg = d.dat_m
		n.acc_sg = d.acc_n
		n.ins_sg = d.ins_m
		n.pre_sg = d.pre_m
	else
		assert(false, "Unrecognized gender: " .. gender)
	end
	n.nom_pl = d.nom_p
	n.gen_pl = d.gen_p
	n.dat_pl = d.dat_p
	n.ins_pl = d.ins_p
	n.pre_pl = d.pre_p
	if gender == "m" and d.nom_mp then
		n.nom_pl = d.nom_mp
	end
	return n
end

declensions["ый"] = {
	["nom_m"] = "ый",
	["nom_n"] = "ое",
	["nom_f"] = "ая",
	["nom_p"] = "ые",
	["gen_m"] = "ого",
	["gen_f"] = "ой",
	["gen_p"] = "ых",
	["dat_m"] = "ому",
	["dat_f"] = "ой",
	["dat_p"] = "ым",
	["acc_f"] = "ую",
	["acc_n"] = "ое",
	["ins_m"] = "ым",
	["ins_f"] = {"ой", "ою"},
	["ins_p"] = "ыми",
	["pre_m"] = "ом",
	["pre_f"] = "ой",
	["pre_p"] = "ых",
}

declensions["ий"] = {
	["nom_m"] = "ий",
	["nom_n"] = "ее",
	["nom_f"] = "яя",
	["nom_p"] = "ие",
	["gen_m"] = "его",
	["gen_f"] = "ей",
	["gen_p"] = "их",
	["dat_m"] = "ему",
	["dat_f"] = "ей",
	["dat_p"] = "им",
	["acc_f"] = "юю",
	["acc_n"] = "ее",
	["ins_m"] = "им",
	["ins_f"] = {"ей", "ею"},
	["ins_p"] = "ими",
	["pre_m"] = "ем",
	["pre_f"] = "ей",
	["pre_p"] = "их",
}

declensions["ой"] = {
	["nom_m"] = "о́й",
	["nom_n"] = "о́е",
	["nom_f"] = "а́я",
	["nom_p"] = "ы́е",
	["gen_m"] = "о́го",
	["gen_f"] = "о́й",
	["gen_p"] = "ы́х",
	["dat_m"] = "о́му",
	["dat_f"] = "о́й",
	["dat_p"] = "ы́м",
	["acc_f"] = "у́ю",
	["acc_n"] = "о́е",
	["ins_m"] = "ы́м",
	["ins_f"] = {"о́й", "о́ю"},
	["ins_p"] = "ы́ми",
	["pre_m"] = "о́м",
	["pre_f"] = "о́й",
	["pre_p"] = "ы́х",
}

declensions["ьий"] = {
	["nom_m"] = "ий",
	["nom_n"] = "ье",
	["nom_f"] = "ья",
	["nom_p"] = "ьи",
	["gen_m"] = "ьего",
	["gen_f"] = "ьей",
	["gen_p"] = "ьих",
	["dat_m"] = "ьему",
	["dat_f"] = "ьей",
	["dat_p"] = "ьим",
	["acc_f"] = "ью",
	["acc_n"] = "ье",
	["ins_m"] = "ьим",
	["ins_f"] = {"ьей", "ьею"},
	["ins_p"] = "ьими",
	["pre_m"] = "ьем",
	["pre_f"] = "ьей",
	["pre_p"] = "ьих",
}

declensions["short"] = {
	["nom_m"] = "",
	["nom_n"] = "о",
	["nom_f"] = "а",
	["nom_p"] = "ы",
	["gen_m"] = "а",
	["gen_f"] = "ой",
	["gen_p"] = "ых",
	["dat_m"] = "у",
	["dat_f"] = "ой",
	["dat_p"] = "ым",
	["acc_f"] = "у",
	["acc_n"] = "о",
	["ins_m"] = "ым",
	["ins_f"] = {"ой", "ою"},
	["ins_p"] = "ыми",
	["pre_m"] = "ом",
	["pre_f"] = "ой",
	["pre_p"] = "ых",
}

declensions["mixed"] = {
	["nom_m"] = "",
	["nom_n"] = "о",
	["nom_f"] = "а",
	["nom_p"] = "ы",
	["gen_m"] = "ого",
	["gen_f"] = "ой",
	["gen_p"] = "ых",
	["dat_m"] = "ому",
	["dat_f"] = "ой",
	["dat_p"] = "ым",
	["acc_f"] = "у",
	["acc_n"] = "о",
	["ins_m"] = "ым",
	["ins_f"] = {"ой", "ою"},
	["ins_p"] = "ыми",
	["pre_m"] = "ом",
	["pre_f"] = "ой",
	["pre_p"] = "ых",
}

declensions["-"] = {
	["nom_m"] = "-",
	["nom_n"] = "-",
	["nom_f"] = "-",
	["nom_p"] = "-",
	["gen_m"] = "-",
	["gen_f"] = "-",
	["gen_p"] = "-",
	["dat_m"] = "-",
	["dat_f"] = "-",
	["dat_p"] = "-",
	["acc_f"] = "-",
	-- don't do this; instead we default it to nom_n
	-- ["acc_n"] = "-",
	["ins_m"] = "-",
	["ins_f"] = "-",
	["ins_p"] = "-",
	["pre_m"] = "-",
	["pre_f"] = "-",
	["pre_p"] = "-",
}

declensions_old["ый"] = {
	["nom_m"] = "ый",
	["nom_n"] = "ое",
	["nom_f"] = "ая",
	["nom_mp"] = "ые",
	["nom_p"] = "ыя",
	["gen_m"] = "аго",
	["gen_f"] = "ой",
	["gen_p"] = "ыхъ",
	["dat_m"] = "ому",
	["dat_f"] = "ой",
	["dat_p"] = "ымъ",
	["acc_f"] = "ую",
	["acc_n"] = "ое",
	["ins_m"] = "ымъ",
	["ins_f"] = {"ой", "ою"},
	["ins_p"] = "ыми",
	["pre_m"] = "омъ",
	["pre_f"] = "ой",
	["pre_p"] = "ыхъ",
}

declensions_old["ій"] = {
	["nom_m"] = "ій",
	["nom_n"] = "ее",
	["nom_f"] = "яя",
	["nom_mp"] = "іе",
	["nom_p"] = "ія",
	["gen_m"] = "яго",
	["gen_f"] = "ей",
	["gen_p"] = "ихъ",
	["dat_m"] = "ему",
	["dat_f"] = "ей",
	["dat_p"] = "имъ",
	["acc_f"] = "юю",
	["acc_n"] = "ее",
	["ins_m"] = "имъ",
	["ins_f"] = {"ей", "ею"},
	["ins_p"] = "ими",
	["pre_m"] = "емъ",
	["pre_f"] = "ей",
	["pre_p"] = "ихъ",
}

declensions_old["ой"] = {
	["nom_m"] = "о́й",
	["nom_n"] = "о́е",
	["nom_f"] = "а́я",
	["nom_mp"] = "ы́е",
	["nom_p"] = "ы́я",
	["gen_m"] = "а́го",
	["gen_f"] = "о́й",
	["gen_p"] = "ы́хъ",
	["dat_m"] = "о́му",
	["dat_f"] = "о́й",
	["dat_p"] = "ы́мъ",
	["acc_f"] = "у́ю",
	["acc_n"] = "о́е",
	["ins_m"] = "ы́мъ",
	["ins_f"] = {"о́й", "о́ю"},
	["ins_p"] = "ы́ми",
	["pre_m"] = "о́мъ",
	["pre_f"] = "о́й",
	["pre_p"] = "ы́хъ",
}

declensions_old["ьій"] = {
	["nom_m"] = "ій",
	["nom_n"] = "ье",
	["nom_f"] = "ья",
	["nom_p"] = "ьи",
	["gen_m"] = "ьяго",
	["gen_f"] = "ьей",
	["gen_p"] = "ьихъ",
	["dat_m"] = "ьему",
	["dat_f"] = "ьей",
	["dat_p"] = "ьимъ",
	["acc_f"] = "ью",
	["acc_n"] = "ье",
	["ins_m"] = "ьимъ",
	["ins_f"] = {"ьей", "ьею"},
	["ins_p"] = "ьими",
	["pre_m"] = "ьемъ",
	["pre_f"] = "ьей",
	["pre_p"] = "ьихъ",
}

declensions_old["short"] = {
	["nom_m"] = "ъ",
	["nom_n"] = "о",
	["nom_f"] = "а",
	["nom_p"] = "ы",
	["gen_m"] = "а",
	["gen_f"] = "ой",
	["gen_p"] = "ыхъ",
	["dat_m"] = "у",
	["dat_f"] = "ой",
	["dat_p"] = "ымъ",
	["acc_f"] = "у",
	["acc_n"] = "о",
	["ins_m"] = "ымъ",
	["ins_f"] = {"ой", "ою"},
	["ins_p"] = "ыми",
	["pre_m"] = "омъ",
	["pre_f"] = "ой",
	["pre_p"] = "ыхъ",
}

declensions_old["ъ"] = declensions_old["short"]

declensions_old["mixed"] = {
	["nom_m"] = "ъ",
	["nom_n"] = "о",
	["nom_f"] = "а",
	["nom_p"] = "ы",
	["gen_m"] = "аго",
	["gen_f"] = "ой",
	["gen_p"] = "ыхъ",
	["dat_m"] = "ому",
	["dat_f"] = "ой",
	["dat_p"] = "ымъ",
	["acc_f"] = "у",
	["acc_n"] = "о",
	["ins_m"] = "ымъ",
	["ins_f"] = {"ой", "ою"},
	["ins_p"] = "ыми",
	["pre_m"] = "омъ",
	["pre_f"] = "ой",
	["pre_p"] = "ыхъ",
}

declensions_old["ъ-mixed"] = declensions_old["mixed"]

declensions_old["-"] = declensions["-"]

local stressed_sibilant_rules = {
	["я"] = "а",
	["ы"] = "и",
	["ё"] = "о́",
	["ю"] = "у",
}

local stressed_c_rules = {
	["я"] = "а",
	["ё"] = "о́",
	["ю"] = "у",
}

local unstressed_sibilant_rules = {
	["я"] = "а",
	["ы"] = "и",
	["о"] = "е",
	["ю"] = "у",
}

local unstressed_c_rules = {
	["я"] = "а",
	["о"] = "е",
	["ю"] = "у",
}

local velar_rules = {
	["ы"] = "и",
}

local stressed_rules = {
	["ш"] = stressed_sibilant_rules,
	["щ"] = stressed_sibilant_rules,
	["ч"] = stressed_sibilant_rules,
	["ж"] = stressed_sibilant_rules,
	["ц"] = stressed_c_rules,
	["к"] = velar_rules,
	["г"] = velar_rules,
	["х"] = velar_rules,
}

local unstressed_rules = {
	["ш"] = unstressed_sibilant_rules,
	["щ"] = unstressed_sibilant_rules,
	["ч"] = unstressed_sibilant_rules,
	["ж"] = unstressed_sibilant_rules,
	["ц"] = unstressed_c_rules,
	["к"] = velar_rules,
	["г"] = velar_rules,
	["х"] = velar_rules,
}

local consonantal_suffixes = {
	[""] = true,
	["ь"] = true,
	["й"] = true,
}

local old_consonantal_suffixes = {
	["ъ"] = true,
	["ь"] = true,
	["й"] = true,
}

local function attach_unstressed(args, suf)
	local old = args["old"]
	if suf == nil then
		return nil
	elseif old and old_consonantal_suffixes[suf] or not old and consonantal_suffixes[suf] then
		if mw.ustring.find(args[3], old and "[йьъ]$" or "[йь]$") then
			return args[3]
		else
			if suf == "й" or suf == "ь" then
				if mw.ustring.find(args[3], "[аеёиіоуэюяѣ́]$") then
					suf = "й"
				else
					suf = "ь"
				end
			end
			return args[3] .. suf
		end
	end
	suf = com.make_unstressed(suf)
	local first = mw.ustring.sub(suf, 1, 1)
	local rules = unstressed_rules[args["hint"]]
	if rules then
		local conv = rules[first]
		if conv then
			if old then
				local ending = mw.ustring.sub(suf, 2)
				if conv == "и" and mw.ustring.find(ending, "^́?[аеёиійоуэюяѣ]") then
					conv = "і"
				end
				suf = conv .. ending
			else
				suf = conv .. mw.ustring.sub(suf, 2)
			end
		end
	end
	return args[1] .. suf
end

local function attach_stressed(args, suf)
	local old = args["old"]
	if suf == nil then
		return nil
	elseif not mw.ustring.find(suf, "[ё́]") then -- if suf has no "ё" or accent marks
		return attach_unstressed(args, suf)
	end
	local first = mw.ustring.sub(suf, 1, 1)
	local rules = stressed_rules[args["hint"]]
	if rules then
		local conv = rules[first]
		if conv then
			if old then
				local ending = mw.ustring.sub(suf, 2)
				if conv == "и" and mw.ustring.find(ending, "^́?[аеёиійоуэюяѣ]") then
					conv = "і"
				end
				suf = conv .. ending
			else
				suf = conv .. mw.ustring.sub(suf, 2)
			end
		end
	end
	return args[0] .. suf
end

local function attach_with(args, suf, fun)
	if type(suf) == "table" then
		local tbl = {}
		for _, x in ipairs(suf) do
			table.insert(tbl, attach_with(args, x, fun))
		end
		return tbl
	else
		local funval = fun(args, suf)
		if funval then
			return funval .. args["suffix"]
		else
			return nil
		end
	end
end

local function gen_form(args, decl, case, fun)
	args[case] = args[case] or attach_with(args, decl[case], fun)
end

decline = function(args, decl, stressed, short_forms_allowed)
	local attacher = stressed and attach_stressed or attach_unstressed
	gen_form(args, decl, "nom_m", attacher)
	gen_form(args, decl, "nom_n", attacher)
	gen_form(args, decl, "nom_f", attacher)
	if args["old"] then
		gen_form(args, decl, "nom_mp", attacher)
	end
	gen_form(args, decl, "nom_p", attacher)
	gen_form(args, decl, "gen_m", attacher)
	gen_form(args, decl, "gen_f", attacher)
	gen_form(args, decl, "gen_p", attacher)
	gen_form(args, decl, "dat_m", attacher)
	gen_form(args, decl, "dat_f", attacher)
	gen_form(args, decl, "dat_p", attacher)
	gen_form(args, decl, "acc_f", attacher)
	gen_form(args, decl, "acc_n", attacher)
	gen_form(args, decl, "ins_m", attacher)
	gen_form(args, decl, "ins_f", attacher)
	gen_form(args, decl, "ins_p", attacher)
	gen_form(args, decl, "pre_m", attacher)
	gen_form(args, decl, "pre_f", attacher)
	gen_form(args, decl, "pre_p", attacher)
	if short_forms_allowed then
		args["short_m"] = args["short_m"] or args[3] or nil
		args["short_n"] = args["short_n"] or args[4] or nil
		args["short_f"] = args["short_f"] or args[5] or nil
		args["short_p"] = args["short_p"] or args[6] or nil
	else
		args["short_m"] = nil
		args["short_n"] = nil
		args["short_f"] = nil
		args["short_p"] = nil
	end
	-- default acc_n to nom_n; applies chiefly in manual declension tables
	if not args["acc_n"] then
		args["acc_n"] = args["nom_n"]
	end

end

local form_temp = [=[{term}<br/><span style="color: #888">{tr}</span>]=]
local title_temp = [=[Declension of <b lang="ru" class="Cyrl">{lemma}</b>]=]
local old_title_temp = [=[Pre-reform declension of <b lang="ru" class="Cyrl">{lemma}</b>]=]

local template = nil
local template_mp = nil
local short_clause = nil
local notes_template = nil

cases = { "nom_m", "nom_n", "nom_f", "nom_p",
	"gen_m", "gen_f", "gen_p",
	"dat_m", "dat_f", "dat_p",
	"acc_f", "acc_n", "ins_m",
	"ins_f", "ins_p", "pre_m",
	"pre_f", "pre_p",
	"short_m", "short_n", "short_f", "short_p",
}

-- Populate old_cases from cases
old_cases = mw.clone(cases)
table.insert(old_cases, "nom_mp")

-- Make the table
function make_table(args)
	local old = args["old"]
	args["lemma"] = args["nom_m"]
	args["title"] = args["title"] or strutils.format(old and old_title_temp or title_temp, args)

	for _, case in ipairs(old and old_cases or cases) do
		if args[case] == "-" then
			args[case] = "&mdash;"
		elseif args[case] then
			if type(args[case]) ~= "table" then
				args[case] = mw.text.split(args[case], "%s*,%s*")
			end
			local ru_vals = {}
			local tr_vals = {}
			for _, x in ipairs(args[case]) do
				if old then
					table.insert(ru_vals, m_links.full_link(com.make_unstressed(x), x, lang, nil, nil, nil, {tr = "-"}, false))
				else
					table.insert(ru_vals, m_links.full_link(x, nil, lang, nil, nil, nil, {tr = "-"}, false))
				end
				local trx = lang:transliterate(m_links.remove_links(x))
				if case == "gen_m" then
					trx = mw.ustring.gsub(trx, "([aoeáóé]́?)go$", "%1vo")
				end
				table.insert(tr_vals, trx)
			end
			local term = table.concat(ru_vals, ", ")
			local tr = table.concat(tr_vals, ", ")
			args[case] = strutils.format(form_temp, {["term"] = term, ["tr"] = tr})
		else
			args[case] = nil
		end
	end

	local temp = template

	if old then
		if args["nom_mp"] then
			temp = template_mp
			if args["short_m"] or args["short_n"] or args["short_f"] or args["short_p"] then
				args["short_m"] = args["short_m"] or "&mdash;"
				args["short_n"] = args["short_n"] or "&mdash;"
				args["short_f"] = args["short_f"] or "&mdash;"
				args["short_p"] = args["short_p"] or "&mdash;"
				args["short_clause"] = strutils.format(short_clause_mp, args)
			else
				args["short_clause"] = ""
			end
		else
			args["short_clause"] = ""
		end
	else
		if args["short_m"] or args["short_n"] or args["short_f"] or args["short_p"] then
			args["short_m"] = args["short_m"] or "&mdash;"
			args["short_n"] = args["short_n"] or "&mdash;"
			args["short_f"] = args["short_f"] or "&mdash;"
			args["short_p"] = args["short_p"] or "&mdash;"
			args["short_clause"] = strutils.format(short_clause, args)
		else
			args["short_clause"] = ""
		end
	end

	if args["notes"] then
		args["notes_clause"] = strutils.format(notes_template, args)
	else
		args["notes_clause"] = ""
	end

	return strutils.format(temp, args)
end

-- Used for new-style templates
short_clause = [===[

! style="height:0.2em;background:#d9ebff" colspan="6" |
|-
! style="background:#eff7ff" colspan="2" | short form
| {short_m}
| {short_n}
| {short_f}
| {short_p}]===]

-- Used for old-style templates
short_clause_mp = [===[

! style="height:0.2em;background:#d9ebff" colspan="7" |
|-
! style="background:#eff7ff" colspan="2" | short form
| {short_m}
| {short_n}
| {short_f}
| colspan="2" | {short_p}]===]

-- Used for both new-style and old-style templates
notes_template = [===[
<div style="width:100%;text-align:left">
<div style="display:inline-block;text-align:left;padding-left:1em;padding-right:1em">
{notes}
</div></div>
]===]

-- Used for both new-style and old-style templates
template = [===[
<div>
<div class="NavFrame" style="display: inline-block; min-width: 70em">
<div class="NavHead" style="background:#eff7ff">{title}</div>
<div class="NavContent">
{\op}| style="background:#F9F9F9;text-align:center; min-width:70em" class="inflection-table"
|-
! style="width:20%;background:#d9ebff" colspan="2" | 
! style="background:#d9ebff" | masculine
! style="background:#d9ebff" | neuter
! style="background:#d9ebff" | feminine
! style="background:#d9ebff" | plural
|-
! style="background:#eff7ff" colspan="2" | nominative
| {nom_m}
| {nom_n}
| {nom_f}
| {nom_p}
|-
! style="background:#eff7ff" colspan="2" | genitive
| colspan="2" | {gen_m}
| {gen_f}
| {gen_p}
|-
! style="background:#eff7ff" colspan="2" | dative
| colspan="2" | {dat_m}
| {dat_f}
| {dat_p}
|-
! style="background:#eff7ff" rowspan="2" | accusative
! style="background:#eff7ff" | animate
| {gen_m}
| rowspan="2" | {acc_n}
| rowspan="2" | {acc_f}
| {gen_p}
|-
! style="background:#eff7ff" | inanimate
| {nom_m}
| {nom_p}
|-
! style="background:#eff7ff" colspan="2" | instrumental
| colspan="2" | {ins_m}
| {ins_f}
| {ins_p}
|-
! style="background:#eff7ff" colspan="2" | prepositional
| colspan="2" | {pre_m}
| {pre_f}
| {pre_p}
|-{short_clause}
|{\cl}{notes_clause}</div></div></div>]===]

-- Used for old-style templates
template_mp = [===[
<div>
<div class="NavFrame" style="display: inline-block; min-width: 70em">
<div class="NavHead" style="background:#eff7ff">{title}</div>
<div class="NavContent">
{\op}| style="background:#F9F9F9;text-align:center; min-width:70em" class="inflection-table"
|-
! style="width:20%;background:#d9ebff" colspan="2" | 
! style="background:#d9ebff" | masculine
! style="background:#d9ebff" | neuter
! style="background:#d9ebff" | feminine
! style="background:#d9ebff" | m. plural
! style="background:#d9ebff" | n./f. plural
|-
! style="background:#eff7ff" colspan="2" | nominative
| {nom_m}
| {nom_n}
| {nom_f}
| {nom_mp}
| {nom_p}
|-
! style="background:#eff7ff" colspan="2" | genitive
| colspan="2" | {gen_m}
| {gen_f}
| colspan="2" | {gen_p}
|-
! style="background:#eff7ff" colspan="2" | dative
| colspan="2" | {dat_m}
| {dat_f}
| colspan="2" | {dat_p}
|-
! style="background:#eff7ff" rowspan="2" | accusative 
! style="background:#eff7ff" | animate
| {gen_m}
| rowspan="2" | {acc_n}
| rowspan="2" | {acc_f}
| colspan="2" | {gen_p}
|-
! style="background:#eff7ff" | inanimate
| {nom_m}
| {nom_mp}
| {nom_p}
|-
! style="background:#eff7ff" colspan="2" | instrumental
| colspan="2" | {ins_m}
| {ins_f}
| colspan="2" | {ins_p}
|-
! style="background:#eff7ff" colspan="2" | prepositional
| colspan="2" | {pre_m}
| {pre_f}
| colspan="2" | {pre_p}
|-{short_clause}
|{\cl}{notes_clause}</div></div></div>]===]

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
