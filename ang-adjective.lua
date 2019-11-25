--[=[
	This module contains functions for creating inflection tables for Old English
	adjectives. It implements {{ang-adecl}} and {{ang-decl-adj-table}}.

	Author: Benwing2

	External entry points:

	show(): For {{ang-adecl}}
	make_table(): For {{ang-decl-adj-table}}
]=]--

local m_links = require("Module:links")
local strutils = require("Module:string utilities")
local ut = require("Module:utils")

local lang = require("Module:languages").getByCode("ang")

local u = mw.ustring.char
local rsubn = mw.ustring.gsub
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsplit = mw.text.split

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

local export = {}

local MACRON = u(0x0304)

local long_vowel = "āēīōūȳǣ" .. MACRON -- No precomposed œ + macron
local short_vowel = "aeiouyæœ"
local short_vowel_c = "[" .. short_vowel .. "]"
local vowel = long_vowel .. short_vowel
local vowel_c = "[" .. vowel .. "]"
local long_vowel_c = "[" .. long_vowel .. "]"
local cons_c = "[^" .. vowel .. "]"

local cases = { "nom", "acc", "gen", "dat", "ins" }
local numbers = { "sg", "pl" }
local genders = { "m", "f", "n" }
local slots = {}
for _, case in ipairs(cases) do
	for _, number in ipairs(numbers) do
		local accel_number = number == "sg" and "s" or "p"
		for _, gender in ipairs(genders) do
			slots[case .. "_" .. number .. "_" .. gender] = case .. "|" .. gender .. "|" .. accel_number
		end
	end
end

local diphthongs = {
	["ea"] = true,
	["ēa"] = true,
	["eā"] = true,
	["eo"] = true,
	["ēo"] = true,
	["eō"] = true,
	["io"] = true,
	["īo"] = true,
	["iō"] = true,
	["ie"] = true,
	["īe"] = true,
	["iē"] = true,
}

local short_to_long_vowel = {
	["a"] = "ā",
	["e"] = "ē",
	["i"] = "ī",
	["o"] = "ō",
	["u"] = "ū",
	["y"] = "ȳ",
	["æ"] = "ǣ",
	["œ"] = "œ̄", -- the long vowel is two chars
}

local end_syllable_ok_list = {
	"ġn", "ġl",
	"sp", "st", "sc", "sċ", "sk",
	"ps", "ts", "cs", "þs", "ðs", "fs", "ks",
	"pt", "ct", "ft"
}

local end_syllable_ok = require("Module:table").listToSet(end_syllable_ok_list)

-- This is used to determine whether a sequence of consonants XYZ is ok.
-- If X == Y, or end_syllable_ok[XY], or sonority_classes[X] > sonority_classes[Y],
-- we consider this OK (although when X == Y, the sequence XY reduces to a single
-- consonant before another consonant). If a sesquence of consonants XYZ is OK,
-- contraction of a vowel in the sequence XYVZ is possible (e.g. in adjective and
-- verb forms), otherwise not.
local sonority_classes = {
	["b"] = 1,
	["c"] = 1,
	["ċ"] = 1,
	["d"] = 1,
	["f"] = 1,
	["g"] = 1,
	["ġ"] = 1,
	["k"] = 1,
	["p"] = 1,
	["t"] = 1,
	["þ"] = 1,
	["ð"] = 1,
	["x"] = 1,
	["z"] = 1,
	["h"] = 2,
	["n"] = 3,
	["m"] = 3,
	["l"] = 4,
	["r"] = 5,
	["w"] = 6,
	["ƿ"] = 6,
}

local function contraction_possible(x, y)
	-- If X or Y is unknown, treat contraction as not possible.
	return x == y or end_syllable_ok[x .. y] or (sonority_classes[x] or 0) > (sonority_classes[y] or 100)
end

local function break_vowels(vowelseq)
	local chars = rsplit(vowelseq, "")
	local vowels = {}
	local i = 1
	while i <= #chars do
		if i < #chars and diphthongs[chars[i] .. chars[i + 1]] then
			table.insert(vowels, chars[i] .. chars[i + 1])
			i = i + 2
		else
			table.insert(vowels, chars[i])
			i = i + 1
		end
	end
	return vowels
end

-- Break a word into "syllables" where all syllables but the last one
-- consist of zero or more consonants + a single vowel or dipthong,
-- and the last "syllable" contains zero or more consonants without
-- a vowel, representing any final consonants. (Even if there are no
-- final consonants, there will always be a last vowelless syllable,
-- in that case consisting of the empty string.)
local function break_into_syllables(word)
	local vowel_cons = strutils.capturing_split(word, "(" .. vowel_c .. "+)")
	local syllables = {}
	for i = 1, #vowel_cons do
		if i % 2 == 1 then
			table.insert(syllables, vowel_cons[i])
		else
			local vowels = break_vowels(vowel_cons[i])
			for j = 1, #vowels do
				if j == 1 then
					syllables[#syllables] = syllables[#syllables] .. vowels[j]
				else
					table.insert(syllables, vowels[j])
				end
			end
		end
	end
	return syllables
end

local function is_long(syllable, next_syllable)
	if rfind(syllable, long_vowel_c) or
		rfind(next_syllable, "^" .. cons_c .. cons_c) or
		rfind(next_syllable, "^x") then
		return true
	else
		return false
	end
end

local function lengthen_final_vowel(stem)
	local prefix, vowel = rmatch(stem, "^(.-)([eē][ao])$")
	if prefix then
		return prefix .. vowel:gsub("^e", "ē")
	end
	prefix, vowel = rmatch(stem, "^(.-)([iī][eo])$")
	if prefix then
		return prefix .. vowel:gsub("^i", "ī")
	end
	prefix, vowel = rmatch(stem, "^(.-)(" .. short_vowel_c .. ")$")
	if prefix then
		return prefix .. short_to_long_vowel[vowel]
	end
	return stem
end

local function unpalatalize_final_c(stem)
	if type(stem) == "table" then
		local ret = {}
		for _, s in ipairs(stem) do
			table.insert(ret, unpalatalize_final_c(s))
		end
		return ret
	end
	if rfind(stem, "ċċ$") then
		return rsub(stem, "ċċ$", "cc")
	elseif rfind(stem, "sċ$") then
		return stem
	else
		return rsub(stem, "ċ$", "c")
	end
end

local function make_table(args)
	local table_args = {title = args.title}
	local num = args.num
	local accel_lemma = args["lemma"] or args["nom_sg_m"] and args["nom_sg_m"][1] or nil
	local weakness = args["type"] == "strong" and "str|" or args["type"] == "weak" and "wk|" or ""
	for slot, accel_form in pairs(slots) do
		local table_arg = {}
		local forms = args[slot] or {"—"}
		for _, form in ipairs(forms) do
			table.insert(table_arg, form == "—" and form or m_links.full_link{
				lang = lang, term = form, accel = {
					form = weakness .. accel_form,
					lemma = accel_lemma,
				}
			})
			table_args[slot] = table.concat(table_arg, ", ")
		end
	end

	local sgtable = [=[! style="background: #EFEFFF; font-size: 90%;"|[[masculine|Masculine]]
! style="background: #EFEFFF; font-size: 90%;"|[[feminine|Feminine]]
! style="background: #EFEFFF; font-size: 90%;"|[[neuter|Neuter]]
|-
! style="background: #EFEFFF; text-align: left; font-size: 90%;"|[[nominative case|Nominative]]
| {nom_sg_m}
| {nom_sg_f}
| {nom_sg_n}
|-
! style="background: #EFEFFF; text-align: left; font-size: 90%;"|[[accusative case|Accusative]]
| {acc_sg_m}
| {acc_sg_f}
| {acc_sg_n}
|-
! style="background: #EFEFFF; text-align: left; font-size: 90%;"|[[genitive case|Genitive]]
| {gen_sg_m}
| {gen_sg_f}
| {gen_sg_n}
|-
! style="background: #EFEFFF; text-align: left; font-size: 90%;"|[[dative case|Dative]]
| {dat_sg_m}
| {dat_sg_f}
| {dat_sg_n}
|-
! style="background: #EFEFFF; text-align: left; font-size: 90%;"|[[instrumental case|Instrumental]]
| {ins_sg_m}
| {ins_sg_f}
| {ins_sg_n}
]=]

	local pltable = [=[! style="background: #EFEFFF; font-size: 90%;"|[[masculine|Masculine]]
! style="background: #EFEFFF; font-size: 90%;"|[[feminine|Feminine]]
! style="background: #EFEFFF; font-size: 90%;"|[[neuter|Neuter]]
|-
! style="background: #EFEFFF; text-align: left; font-size: 90%;"|[[nominative case|Nominative]]
| {nom_pl_m}
| {nom_pl_f}
| {nom_pl_n}
|-
! style="background: #EFEFFF; text-align: left; font-size: 90%;"|[[accusative case|Accusative]]
| {acc_pl_m}
| {acc_pl_f}
| {acc_pl_n}
|-
! style="background: #EFEFFF; text-align: left; font-size: 90%;"|[[genitive case|Genitive]]
| {gen_pl_m}
| {gen_pl_f}
| {gen_pl_n}
|-
! style="background: #EFEFFF; text-align: left; font-size: 90%;"|[[dative case|Dative]]
| {dat_pl_m}
| {dat_pl_f}
| {dat_pl_n}
|-
! style="background: #EFEFFF; text-align: left; font-size: 90%;"|[[instrumental case|Instrumental]]
| {ins_pl_m}
| {ins_pl_f}
| {ins_pl_n}
]=]

	local table_header = [=[<div class="NavFrame" style="width: 50em;">
<div class="NavHead" style="background:#EFF7FF" >Declension of {title}</div>
<div class="NavContent">
{\op}| style="background: #F9F9F9; text-align:center; width:100%; line-height: 125%; border: 1px solid #CCCCFF;" cellpadding="3" cellspacing="1" class="inflection-table"
]=]

	local table_footer = [=[|{\cl}</div></div>]=]

	local table = [=[{table_header}! style="width: 16%; background: #EFEFFF;" |[[singular|Singular]]
{sgtable}|-
! style="background: #EFEFFF;" |[[plural|Plural]]
{pltable}{table_footer}]=]

	local sg_table = [=[{table_header}! style="width: 16%; background: #EFEFFF;" |[[singular|Singular]]
{sgtable}{table_footer}]=]

	local pl_table = [=[{table_header}! style="background: #EFEFFF;" |[[plural|Plural]]
{pltable}{table_footer}]=]

	local formatted_table = strutils.format(num == "sg" and sg_table or num == "pl" and pl_table or table,
		{table_header = table_header, table_footer = table_footer,
		 sgtable = sgtable, pltable = pltable})
	return strutils.format(formatted_table, table_args)
end

local function make_table_with_overrides(genargs, lemma, userargs, userpref)
	genargs.lemma = lemma
	for slot, _ in pairs(slots) do
		if userargs[userpref .. slot] then
			genargs[slot] = rsplit(userargs[userpref .. slot], ", *")
		end
	end
	genargs.num = userargs.num
	return make_table(genargs)
end
	
local function compute_adj_args(adjtype, bare, vstem, cstemn, cstemr, short, h)
	local args = {}
	local function add_ending(slot, stems, ending, construct_stem_ending)
		local function default_construct_stem_ending(stem, ending)
			if ending == "-" then
				return stem
			else
				return stem .. ending
			end
		end
		construct_stem_ending = construct_stem_ending or default_construct_stem_ending
		if type(stems) ~= "table" then
			stems = {stems}
		end
		if not args[slot] then
			args[slot] = {}
		end
		for _, stem in ipairs(stems) do
			local form = construct_stem_ending(stem, ending)
			if type(form) == "string" then
				ut.insert_if_not(args[slot], form)
			else
				for _, f in ipairs(form) do
					ut.insert_if_not(args[slot], f)
				end
			end
		end
	end

	local function compute_stem_for_ending(ending)
		if ending == "" then
			return bare
		elseif ending:find("^n") then
			return cstemn
		elseif ending:find("^r") then
			return cstemr
		else
			return vstem
		end
	end

	local function construct_h_stem_ending(stem, ending)
		-- Delete a vowel at the beginning of the ending. But -um can
		-- either assume the contracted form (-m) or the full form (-um).
		if ending == "um" then
			return {stem .. "m", stem .. "um"}
		elseif ending:find("^[aeiou%-]") then
			return stem .. ending:gsub("^.", "")
		else
			return stem .. ending
		end
	end

	local construct_stem_ending
	if h then
		construct_stem_ending = construct_h_stem_ending
	end

	local function add_row(slot_suffix, nom, acc, gen, dat, ins)
		local function add(slot_prefix, ending)
			if type(ending) ~= "table" then
				ending = {ending}
			end
			for _, e in ipairs(ending) do
				local stem = compute_stem_for_ending(e)
				add_ending(slot_prefix .. "_" .. slot_suffix, stem, e,
					construct_stem_ending)
			end
		end
		add("nom", nom)
		add("acc", acc)
		add("gen", gen)
		add("dat", dat)
		add("ins", ins)
	end

	if adjtype == "strong" then
		-- short == "h" is a special signal for adjectives in -h (esp. sċeolh, þweorh);
		-- use the vowel stem but have no ending.
		local short_ending = short == "opt" and {"", "u", "o"} or short == "h" and "-" or
			short and {"u", "o"} or ""
		add_row("sg_m", "", "ne", "es", "um", "e")
		add_row("sg_f", short_ending, "e", "re", "re", "re")
		add_row("sg_n", "", "", "es", "um", "e")
		add_row("pl_m", "e", "e", "ra", "um", "um")
		add_row("pl_f", {"a", "e"}, {"a", "e"}, "ra", "um", "um")
		add_row("pl_n", short_ending, short_ending, "ra", "um", "um")
	elseif adjtype == "weak" then
		add_row("sg_m", "a", "an", "an", "an", "an")
		add_row("sg_f", "e", "an", "an", "an", "an")
		add_row("sg_n", "e", "e", "an", "an", "an")
		add_row("pl_m", "an", "an", {"ra", "ena"}, "um", "um")
		add_row("pl_f", "an", "an", {"ra", "ena"}, "um", "um")
		add_row("pl_n", "an", "an", {"ra", "ena"}, "um", "um")
	else
		error("Unrecognized adjective type: '" .. adjtype .. "'")
	end

	return args
end

function export.show(frame)
	local parent_args = frame:getParent().args
	local params = {
		[1] = {required = true, default = "glæd"},
		["stem"] = {},
		["bare"] = {},
		["vstem"] = {},
		["cstem"] = {},
		["cstemn"] = {},
		["cstemr"] = {},
		["short"] = {},
		["contractable"] = {},
		["type"] = {},
		["h"] = {},
		["num"] = {},
	}
	if parent_args["type"] == "strong" or parent_args["type"] == "weak" then
		for slot, _ in pairs(slots) do
			params[slot] = {}
		end
	else
		for slot, _ in pairs(slots) do
			params["str_" .. slot] = {}
			params["wk_" .. slot] = {}
		end
	end
	
	local args = require("Module:parameters").process(parent_args, params)

	local lemma = args[1]
	local stem, bare, vstem, cstemn, cstemr
	local short = false
	local contractable = false
	local adjtype = "normal"
	local h = false
	if rfind(lemma, cons_c .. "a$") then
		adjtype = "weak"
		stem = args.stem or lemma:gsub("a$", "")
		bare = stem
	else
		bare = lemma
		if rfind(lemma, cons_c .. "e$") then
			short = true
			stem = args.stem or lemma:gsub("e$", "")
		elseif rfind(lemma, cons_c .. "[ou]$") then
			short = true
			if lemma:find("o$") then
				bare = {lemma, lemma:gsub("o$", "u")}
			else
				bare = {lemma, lemma:gsub("u$", "o")}
			end
			stem = args.stem or lemma:gsub(".$", "w")
		else
			stem = args.stem or lemma
			local syllables = break_into_syllables(stem)
			if #syllables == 1 then
				error("No vowels in stem: '" .. stem .. "'")
			end
			if rfind(stem, vowel_c .. ".*l[iī][cċ]$") then
				short = "opt"
			elseif is_long(syllables[#syllables - 1], syllables[#syllables]) or
				#syllables > 2 and not is_long(syllables[#syllables - 1], syllables[#syllables]) and
				not is_long(syllables[#syllables - 2], syllables[#syllables - 1]) then
				-- "long stem", no -u in fem. sg.
			else
				short = true
			end
			if #syllables > 2 and
				--Special-case final -isċ and -iġ, which are contractable;
				--otherwise, should end in [eou] + single consonant, and not -ed or -sum.
				--In addition, the preceding syllable should be long.
				(rfind(stem, "is[cċ]$") or rfind(stem, "i[gġ]$") or
					(rfind(stem, cons_c .. "[eou]" .. cons_c .. "$") and
					 not rfind(stem, "ed$") and not rfind(stem, "sum$"))) and
				is_long(syllables[#syllables - 2], syllables[#syllables - 1]) then
				local x, y = rmatch(syllables[#syllables - 1], "^" .. cons_c .. "*(" .. cons_c .. ")(" .. cons_c .. ")")
				if not x or contraction_possible(x, y) then
					contractable = true
				end
			end
		end
	end

	if args.contractable then
		contractable = require("Module:yesno")(args.contractable)
	end

	if rfind(stem, "(" .. cons_c .. ")%1$") then
		-- þicce, þynne, wann, ierre, etc.
		cstemn = rsub(stem, ".$", "")
		cstemr = cstemn
	elseif rfind(stem, "(" .. cons_c .. ")r$") then
		-- ġīfre
		cstemn = stem:gsub("r$", "er")
		cstemr = stem:gsub("r$", "")
	elseif stem:find("[lr]n$") then
		-- dyrne
		cstemn = stem:gsub("n$", "")
		cstemr = stem
	elseif rfind(stem, "(" .. cons_c .. ")n$") then
		-- fǣcne
		cstemn = stem:gsub("n$", "")
		cstemr = stem:gsub("n$", "en")
	elseif rfind(stem, "(" .. cons_c .. ")[lm]$") and not stem:find("[rl]m$") and not stem:find("rl$") then
		-- ǣ-cnōsle
		cstemn = stem:gsub("(.)$", "e%1")
		cstemr = cstemn
	elseif rfind(stem, vowel_c .. "h$") then
		-- hēah, wōh
		h = true
		short = "h"
		vstem = lengthen_final_vowel(stem:gsub("h$", ""))
		cstemn = {vstem, vstem .. "n"}
		cstemr = {vstem, vstem .. "r"}
	elseif rfind(stem, "[lr]h$") then
		-- sċeolh, þweorh
		short = "h"
		local prefix, final_cons = rmatch(stem, "^(.-)([lr])h$")
		vstem = lengthen_final_vowel(prefix) .. final_cons
		cstemn = vstem
		cstemr = vstem
	elseif rfind(stem, vowel_c .. "$") then
		-- frēo
		h = true
		short = "h"
		vstem = lengthen_final_vowel(stem)
		cstemn = vstem
		cstemr = vstem
	else
		cstemn = stem
		cstemr = stem
	end
	cstemn = unpalatalize_final_c(cstemn)
	cstemr = unpalatalize_final_c(cstemr)
	
	if vstem then
		-- already set for vowel-final and h-final stems
	elseif contractable then
		local beginning, c1, v, c2 = rmatch(stem, "(.-)(" .. cons_c .. "*)(" .. vowel_c .. "+)(" .. cons_c .. "+)$")
		if not c1 then
			error("Stem '" .. stem .. "' isn't contractable")
		end
		local contracted_c1 = c1
		if rfind(contracted_c1, "(.)%1$") then
			contracted_c1 = rsub(contracted_c1, ".$", "")
		end
		vstem = {beginning .. c1 .. v .. c2, beginning .. unpalatalize_final_c(contracted_c1) .. c2}
	elseif rfind(stem, "æ" .. cons_c .. "$") then
		vstem = rsub(stem, "æ(" .. cons_c .. ")$", "a%1")
	elseif rfind(stem, "ea" .. cons_c .. "$") then
		vstem = rsub(stem, "ea(" .. cons_c .. ")$", "a%1")
	else
		vstem = stem
	end

	if args.short == "opt" then
		short = "opt"
	elseif args.short then
		short = require("Module:yesno")(args.short)
	end
	if args.h then
		h = require("Module:yesno")(args.h)
	end
	if args["type"] then
		adjtype = args["type"]
	end
	if args.bare then
		bare = rsplit(args.bare, ", *")
	end
	if args.vstem then
		vstem = rsplit(args.vstem, ", *")
	end
	if args.cstem then
		cstemn = rsplit(args.cstem, ", *")
		cstemr = cstemn
	end
	if args.cstemn then
		cstemn = rsplit(args.cstemn, ", *")
	end
	if args.cstemr then
		cstemr = rsplit(args.cstemr, ", *")
	end

	local function make_title(title_type)
		if args.title then
			return args.title
		end
		return require("Module:links").full_link({lang = lang, alt = lemma}, "term") ..
			" &mdash; " .. title_type
	end

	if adjtype == "strong" or adjtype == "weak" then
		local forms = compute_adj_args(adjtype, bare, vstem, cstemn, cstemr, short, h)
		forms.title = make_title(adjtype == "strong" and "Strong only" or "Weak only")
		return make_table_with_overrides(forms, lemma, args, "")
	else
		local strong_forms = compute_adj_args("strong", bare, vstem, cstemn, cstemr, short, h)
		strong_forms.title = make_title("Strong")
		strong_forms["type"] = "strong"
		local strong_table = make_table_with_overrides(strong_forms, lemma, args, "str_")
		local weak_forms = compute_adj_args("weak", bare, vstem, cstemn, cstemr, short, h)
		weak_forms.title = make_title("Weak")
		weak_forms["type"] = "weak"
		local weak_table = make_table_with_overrides(weak_forms, lemma, args, "wk_")
		return strong_table .. weak_table
	end
end

function export.make_table(frame)
	local parent_args = frame:getParent().args
	local params = {
		["title"] = {default = "—"},
		["type"] = {},
		["lemma"] = {},
	}
	for slot, _ in pairs(slots) do
		params[slot] = {}
	end
	
	local args = require("Module:parameters").process(parent_args, params)

	for k, v in pairs(args) do
		if slots[k] then
			args[k] = rsplit(v, ", *")
		end
	end
		
	return make_table(args)
end

return export
