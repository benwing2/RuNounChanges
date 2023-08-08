local export = {}
local pos_functions = {}

local lang = require("Module:languages").getByCode("bg")

local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

local function track(page)
	require("Module:debug").track("bg-headword/" .. page)
	return true
end

local function format(array, concatenater)
	if #array == 0 then
		return ""
	else
		local concatenated = table.concat(array, concatenater)
		if concatenated == "" then
			return ""
		elseif rfind(concatenated, "'$") then
			concatenated = concatenated .. " "
		end
		return "; ''" .. concatenated .. "''"
	end
end

local function glossary_link(anchor, text)
	text = text or anchor
	return "[[Appendix:Glossary#" .. anchor .. "|" .. text .. "]]"
end

-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	local NAMESPACE = mw.title.getCurrentTitle().nsText
	local PAGENAME = mw.title.getCurrentTitle().text

	local iparams = {
		[1] = {required = true},
		["def"] = {},
		["suff_type"] = {},
	}
	local iargs = require("Module:parameters").process(frame.args, iparams)
	local args = frame:getParent().args
	local poscat = iargs[1]
	local def = iargs.def
	local suff_type = iargs.suff_type
	local postype = nil
	if suff_type then
		postype = poscat .. '-' .. suff_type
	else
		postype = poscat
	end

	local data = {lang = lang, categories = {}, heads = {}, genders = {}, inflections = {}}

	if poscat == "suffixes" then
		table.insert(data.categories, "Bulgarian " .. suff_type .. "-forming suffixes")
	end

	if pos_functions[postype] then
		local new_poscat = pos_functions[postype](postype, def, args, data)
		if new_poscat then
			poscat = new_poscat
		end
	end

	data.pos_category = (NAMESPACE == "Reconstruction" and "reconstructed " or "") .. poscat
	
	return require("Module:headword").full_headword(data)
end

pos_functions["verbs"] = function(postype, def, args, data)
	local params = {
		[1] = {required = true, list = "head"},
		[2] = {},
		["tr"] = {list = true, allow_holes = true},
		["pf"] = {list = true},
		["impf"] = {list = true},
		["id"] = {},
	}

	local args = require("Module:parameters").process(args, params)
	data.heads = args[1]
	data.translits = args.tr
	data.id = args.id
	if args[2] == "pf" then
		data.genders = {"pf"}
	elseif args[2] == "impf" then
		data.genders = {"impf"}
	elseif args[2] == "both" then
		data.genders = {"impf", "pf"}
	elseif args[2] then
		error("Unrecognized aspect '" .. args[2] .. "'")
	end

	local pf = args.pf
	if #pf > 0 then
		pf.label = "perfective"
		table.insert(data.inflections, pf)
	end
	local impf = args.impf
	if #impf > 0 then
		impf.label = "imperfective"
		table.insert(data.inflections, impf)
	end
end

local function nouns(pos, def, args, data)
	local params = {
		[1] = {required = true, list = "head"},
		["tr"] = {list = true, allow_holes = true},
		[2] = {alias_of = "g"},
		["g"] = {list = true},
		["m"] = {list = true},
		["f"] = {list = true},
		["dim"] = {list = true},
		["adj"] = {list = true},
		["id"] = {},
		["indecl"] = {type = "boolean"},
	}
	local args = require("Module:parameters").process(args, params)
	data.heads = args[1]
	data.no_redundant_head_cat = true -- since 1= is required
	data.translits = args.tr
	for _, g in ipairs(args.g) do
		if g == "m" or g == "m-p" or g == "f" or g == "f-p" or g == "n" or g == "n-p" or g == "p" or
			g == "mf" or g == "mf-p" or g == "mfbysense" or g == "mfbysense-p" then
			-- OK
		else
			error("Unrecognized gender: '" .. g .. "'")
		end
	end
	data.genders = args.g
	if args.indecl then
		table.insert(data.inflections, {label = "indeclinable"})
	end
	local m = args.m
	if #m > 0 then
		m.label = "masculine"
		table.insert(data.inflections, m)
	end
	local f = args.f
	if #f > 0 then
		f.label = "feminine"
		table.insert(data.inflections, f)
	end
	local adj = args.adj
	if #adj > 0 then
		adj.label = "relational adjective"
		table.insert(data.inflections, adj)
	end
	local dim = args.dim
	if #dim > 0 then
		dim.label = "diminutive"
		table.insert(data.inflections, dim)
	end
	data.id = args.id
end

pos_functions["nouns"] = nouns
pos_functions["proper nouns"] = nouns

local function adverbs(pos, def, args, data)
	local params = {
		[1] = {required = true, list = "head"},
		["tr"] = {list = true, allow_holes = true},
		[2] = {alias_of = "comp"},
		["comp"] = {list = true},
		[3] = {alias_of = "sup"},
		["sup"] = {list = true},
		["id"] = {},
	}
	local args = require("Module:parameters").process(args, params)
	data.heads = args[1]
	data.translits = args.tr
	local comp = args.comp
	if comp[1] == "-" then
		table.insert(data.inflections, {label = "no comparative"})
	else
		if #comp == 0 then
			for _, head in ipairs(args[1]) do
				table.insert(comp, "по́-" .. head)
			end
		end
		comp.label = "comparative"
		table.insert(data.inflections, comp)
		local sup = args.sup
		if #sup == 0 then
			for _, head in ipairs(args[1]) do
				table.insert(sup, "на́й-" .. head)
			end
		end
		sup.label = "superlative"
		table.insert(data.inflections, sup)
	end
	data.id = args.id
end

pos_functions["adverbs"] = adverbs

local function adjectives(pos, def, args, data)
	local params = {
		[1] = {required = true, list = "head"},
		["tr"] = {list = true, allow_holes = true},
		["g"] = {list = true},
		["indecl"] = {type = "boolean"},
		["dim"] = {list = true},
		["adv"] = {list = true},
		["absn"] = {list = true},
		["id"] = {},
	}
	local args = require("Module:parameters").process(args, params)
	data.heads = args[1]
	data.translits = args.tr
	data.genders = args.g
	if args.indecl then
		table.insert(data.inflections, {label = "indeclinable"})
	end
	local dim = args.dim
	if #dim > 0 then
		dim.label = "diminutive"
		table.insert(data.inflections, dim)
	end
	local adv = args.adv
	if #adv > 0 then
		adv.label = "adverb"
		table.insert(data.inflections, adv)
	end
	local absn = args.absn
	if #absn > 0 then
		absn.label = "abstract noun"
		table.insert(data.inflections, absn)
	end
	data.id = args.id
end

pos_functions["adjectives"] = adjectives
pos_functions["determiners"] = adjectives
pos_functions["pronouns"] = adjectives
pos_functions["suffixes-adjective"] = function(postype, def, args, data)
	return adjectives("suffixes", def, args, data)
end

pos_functions["numerals-adjective"] = function(postype, def, args, data)
	return adjectives("numerals", def, args, data)
end

pos_functions["participles"] = function(pos, def, args, data)
	local params = {
		[1] = {required = true, list = "head"},
		[2] = {required = true, list = true, default = "aor"},
		["tr"] = {list = true, allow_holes = true},
		["id"] = {},
	}
	local args = require("Module:parameters").process(args, params)
	data.heads = args[1]
	data.translits = args.tr
	data.genders = args.g
	data.id = args.id
	table.insert(data.categories, "Bulgarian verb forms")
	for _, part in ipairs(args[2]) do
		if part == "adv" then
			table.insert(data.categories, "Bulgarian adverbial participles")
		elseif part == "aor" then
			table.insert(data.categories, "Bulgarian past active aorist participles")
		elseif part == "impf" then
			table.insert(data.categories, "Bulgarian past active imperfect participles")
		elseif part == "pres" then
			table.insert(data.categories, "Bulgarian present active participles")
		elseif part == "pass" or part == "ppp" then
			table.insert(data.categories, "Bulgarian past passive participles")
		elseif part == "prespass" then
			table.insert(data.categories, "Bulgarian present passive participles")
		else
			error("Unrecognized participle type '" .. part .. "': Should be adv, aor, impf, pres, pass or prespass")
		end
	end
end

pos_functions["phrases"] = function(postype, def, args, data)
	local params = {
		[1] = {required = true, list = "head", default = def},
		["id"] = {},
	}

	local args = require("Module:parameters").process(args, params)

	data.heads = args[1]
	data.id = args.id
end

local function non_lemma_forms(postype, def, args, data)
	local params = {
		[1] = {required = true, list = "head", default = def},
		["g"] = {list = true},
		["id"] = {},
	}

	local args = require("Module:parameters").process(args, params)

	data.heads = args[1]
	data.genders = args.g
	data.id = args.id
	if postype == "participle forms" or postype == "verbal nouns" then
		table.insert(data.categories, "Bulgarian verb forms")
	elseif postype == "verbal noun forms" then
		table.insert(data.categories, "Bulgarian verb forms")
		return "noun forms"
	end
end

pos_functions["noun forms"] = non_lemma_forms
pos_functions["proper noun forms"] = non_lemma_forms
pos_functions["pronoun forms"] = non_lemma_forms
pos_functions["verb forms"] = non_lemma_forms
pos_functions["verbal nouns"] = non_lemma_forms
pos_functions["verbal noun forms"] = non_lemma_forms
pos_functions["adjective forms"] = non_lemma_forms
pos_functions["participle forms"] = non_lemma_forms
pos_functions["determiner forms"] = non_lemma_forms
pos_functions["numeral forms"] = non_lemma_forms
pos_functions["suffix forms"] = non_lemma_forms

return export
