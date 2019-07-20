local export = {}
local pos_functions = {}

-- FIXME: Replace with Module:table
local ut = require("Module:utils")

local legal_gender = {
	["m"] = true,
	["m-s"] = true,
	["m-p"] = true,
	["f"] = true,
	["f-s"] = true,
	["f-p"] = true,
	["n"] = true,
	["n-s"] = true,
	["n-p"] = true,
	["c"] = true,
	["c-s"] = true,
	["c-p"] = true,
	["?"] = true,
	["?-s"] = true,
	["?-p"] = true,
}

local legal_declension = {
	["first"] = true,
	["second"] = true,
	["third"] = true,
	["fourth"] = true,
	["fifth"] = true,
	["irregular"] = true,
}

local gender_names = {
	["m"] = "masculine",
	["m-s"] = "masculine",
	["m-p"] = "masculine",
	["f"] = "feminine",
	["f-s"] = "feminine",
	["f-p"] = "feminine",
	["n"] = "neuter",
	["n-s"] = "neuter",
	["n-p"] = "neuter",
	["c"] = "common",
	["c-s"] = "common",
	["c-p"] = "common",
	["?"] = "unknown gender",
	["?-s"] = "unknown gender",
	["?-p"] = "unknown gender",
}

local lang = require("Module:languages").getByCode("la")
local suffix = nil

local u = mw.ustring.char
local rfind = mw.ustring.find
local rsplit = mw.text.split
local rsubn = mw.ustring.gsub

local MACRON = u(0x0304)
local BREVE = u(0x0306)
local DIAER = u(0x0308)
local DOUBLE_INV_BREVE = u(0x0361)
local accents = MACRON .. BREVE .. DIAER .. DOUBLE_INV_BREVE

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

local function format(array, concatenater)
	if #array == 0 then
		return ""
	else
		return "; ''" .. table.concat(array, concatenater) .. "''"
	end
end

local function glossary_link(anchor, text)
	text = text or anchor
	return "[[Appendix:Glossary#" .. anchor .. "|" .. text .. "]]"
end

-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	local args = frame:getParent().args
	NAMESPACE = mw.title.getCurrentTitle().nsText
	PAGENAME = mw.title.getCurrentTitle().text
	
	local head = args["head"]; if head == "" then head = nil end
	
	local poscat = frame.args[1] or error("Part of speech has not been specified. Please pass parameter 1 to the module invocation.")
	local class = frame.args[2]
	local suff_type = frame.args.suff_type
	local postype = nil
	if suff_type then
		postype = poscat .. '-' .. suff_type
	else
		postype = poscat
	end
	
	local data = {lang = lang, pos_category = (NAMESPACE == "Reconstruction" and "reconstructed " or "") .. poscat, categories = {}, heads = {head}, genders = {}, inflections = {}}
	local infl_classes = {}
	local appendix = {}
	local postscript = {}
	
	if poscat == "suffixes" then
		table.insert(data.categories, "Latin " .. suff_type .. "-forming suffixes")
		suffix = '-'
	end
	
	if pos_functions[postype] then
		pos_functions[postype](class, args, data, infl_classes, appendix, postscript)
	end
	
	if suffix then
		for i, h in ipairs(data.heads) do
			data.heads[i] = suffix .. h
		end
	end
	
	if mw.ustring.find(mw.ustring.gsub(PAGENAME,"qu","kv"),"[aeiouāēīōū][iu][aeiouāēīōū]") then
		table.insert(data.categories, "Kenny's testing category 7")
	end
	
	postscript = table.concat(postscript, ", ")
	
	return
		require("Module:headword").full_headword(data)
		.. format(infl_classes, "/")
		.. format(appendix, ", ")
		.. (postscript ~= "" and " (" .. postscript .. ")" or "")
end

pos_functions["nouns"] = function(class, args, data, infl_classes, appendix)
	params = {
		[1] = {alias_of = 'head'},
		[2] = {alias_of = 'gen'},
		[3] = {alias_of = 'g'},
		[4] = {alias_of = 'decl'},
		head = {list = true, default = mw.title.getCurrentTitle().text},
		gen = {list = true},
		g = {list = true, default = '?'},
		decl = {list = true},
		indecl = {type = "boolean"},
		id = {},
		m = {list = true},
		f = {list = true},
	}
	local args = require("Module:parameters").process(args, params)
	data.heads = args.head
	data.id = args.id
	
	for _, g in ipairs(args.g) do
		if legal_gender[g] then
			table.insert(data.genders, g)
			table.insert(data.categories, "Latin " .. gender_names[g] .. " nouns")
		else
			error("Gender “" .. g .. "” is not an valid Latin gender.")
		end
	end

	if args.indecl then
		table.insert(data.inflections, {label = glossary_link("indeclinable")})
		table.insert(data.categories, "Latin indeclinable nouns")
		for _, g in ipairs(args.g) do
			table.insert(data.categories, "Latin " .. gender_names[g] ..  " indeclinable nouns")
		end
	else
		if #args.decl > 1 then
			table.insert(data.inflections, {label = 'variously declined'})
			table.insert(data.categories, "Latin nouns with multiple declensions")
		elseif #args.decl == 0 then
			if NAMESPACE == "Template" then
				table.insert(appendix, "? declension")
			else
				error("Please provide the declension class.")
			end
		end
	
		for _, decl_class in ipairs(args.decl) do
			if legal_declension[decl_class] then
				table.insert(appendix, "[[Appendix:Latin " .. decl_class .. " declension|" .. decl_class .. " declension]]")
				if decl_class ~= "irregular" then
					table.insert(data.categories, "Latin " .. decl_class .. " declension nouns")
				end
				
				for _, g in ipairs(args.g) do
					table.insert(data.categories, "Latin " .. gender_names[g] ..  " nouns in the " .. decl_class .. " declension")
				end
			else
				error("Declension “" .. decl_class .. "” is not an legal Latin declension.")
			end
		end
	
		if #args.gen == 0 then
			table.insert(data.inflections, {label = "no genitive"})
			table.insert(data.categories, "Latin nouns without a genitive singular")
		else
			args.gen.label = "genitive"
			if suffix then
				for i, g in ipairs(args.gen) do
					args.gen[i] = suffix .. g
				end
			end
			table.insert(data.inflections, args.gen)
		end

		if #args.m > 0 then
			args.m.label = "masculine"
			if suffix then
				for i, m in ipairs(args.m) do
					args.m[i] = suffix .. m
				end
			end
			table.insert(data.inflections, args.m)
		end

		if #args.f > 0 then
			args.f.label = "feminine"
			if suffix then
				for i, f in ipairs(args.f) do
					args.f[i] = suffix .. f
				end
			end
			table.insert(data.inflections, args.f)
		end
	end
end

pos_functions["proper nouns"] = pos_functions["nouns"]
pos_functions["suffixes-noun"] = pos_functions["nouns"]

local allowed_subtypes = {
	["impers"] = true,
	["3only"] = true,
	["depon"] = true,
	["semidepon"] = true,
	["optsemidepon"] = true,
	["nopass"] = true,
	["pass3only"] = true,
	["passimpers"] = true,
	["perfaspres"] = true,
	["memini"] = true,
	["noperf"] = true,
	["noactvperf"] = true,
	["nopasvperf"] = true,
	["nosup"] = true,
	["supfutractvonly"] = true,
	["noimp"] = true,
	["shortimp"] = true,
	["nofut"] = true,
	["def"] = true,
	["facio"] = true,
	["irreg"] = true,
}

function export.split_verb_subtype(subtype)
	if not subtype or subtype == "" then
		return {}
	end

	subtype = rsub(subtype, "opt%-semi%-depon", "optsemidepon")
	subtype = rsub(subtype, "semi%-depon", "semidepon")
	subtype = rsub(subtype, "pass%-3only", "pass3only")
	subtype = rsub(subtype, "pass%-impers", "passimpers")
	subtype = rsub(subtype, "no%-actv%-perf", "noactvperf")
	subtype = rsub(subtype, "no%-pasv%-perf", "nopasvperf")
	subtype = rsub(subtype, "perf%-as%-pres", "perfaspres")
	subtype = rsub(subtype, "short%-imp", "shortimp")
	subtype = rsub(subtype, "sup%-futr%-actv%-only", "supfutractvonly")

	local subtypes = rsplit(subtype, "%-")

	for _, subtype in ipairs(subtypes) do
		if not allowed_subtypes[subtype] then
			error("Unrecognized verb subtype " .. subtype)
		end
	end

	return subtypes
end

pos_functions["verbs"] = function(class, args, data, infl_classes, appendix)
	params = {
		[1] = {alias_of = 'head'},
		[2] = {alias_of = 'inf'},
		[3] = {alias_of = 'perf'},
		[4] = {alias_of = 'sup'},
		[44] = {},
		head = {list = true},
		inf = {list = true},
		perf = {list = true},
		sup = {list = true},
		pattern = {},
		c = {alias_of = 'conj'},
		conj = {},
		id = {},
	}
	local args = require("Module:parameters").process(args,params)
	data.heads = args.head
	data.id = args.id
	local conj = args.conj
	local pattern = args.pattern
	
	args.inf.label = "present infinitive"
	args.perf.label = "perfect active"
	if not args[44] then
		args[44] = #args.sup > 0 and rfind(args.sup[1], "ūrus$") and "future participle" or "supine"
	end
	args.sup.label = args[44]
	
	for i, array in ipairs({args.head, args.inf, args.perf, args.sup}) do
		for j, param in ipairs(array) do
			if mw.ustring.gsub(param, "^[*%[%]a-zA-ZĀāĒēĪīŌōŪūȲȳÄäËëÏïÖöÜüŸÿĂăĔĕĬĭŎŏŬŭ " .. accents .. "]+$", "") ~= "" then
				table.insert(data.categories, "la-verb invalid parameters")
			end
			
			if i == 3 then
				-- For (semi-)deponent verbs, remove sum/est ("est" for impersonal
				-- verbs like [[pertaedet]]) when constructing the link.
				array[j] = {term = mw.ustring.gsub(mw.ustring.gsub(param, " sum$", ""), " est$", ""), alt = param}
			end
		end
	end
	
	table.insert(data.inflections, args.inf)
	if #args.perf > 0 then table.insert(data.inflections, args.perf) end
	if #args.sup > 0 then table.insert(data.inflections, args.sup) end

	if not pattern and #args.head > 0 and rfind(args.head[1], "r$") then
		pattern = "depon"
	end

	if conj == "1" then
		table.insert(appendix, "[[Appendix:Latin first conjugation|first conjugation]]")
	elseif conj == "2" then
		table.insert(appendix, "[[Appendix:Latin second conjugation|second conjugation]]")
	elseif conj == "3" then
		table.insert(appendix, "[[Appendix:Latin third conjugation|third conjugation]]")
	elseif conj == "io" then
		table.insert(appendix, "[[Appendix:Latin third conjugation|third conjugation]] iō-variant")
	elseif conj == "4" then
		table.insert(appendix, "[[Appendix:Latin fourth conjugation|fourth conjugation]]")
	elseif conj == "irreg" then --sum
		table.insert(appendix, "[[Appendix:Latin irregular verbs|irregular conjugation]]")
	else
		if NAMESPACE == "Template" then
			table.insert(appendix, "? declension")
		else
			table.insert(data.categories, "Latin verbs without the conjugation in their headwords")
		end
	end
	
	local subtypes = export.split_verb_subtype(pattern)

	if ut.contains(subtypes, "impers") then
		-- decet
		-- advesperāscit (also nopass)
		table.insert(appendix, "[[impersonal#English|impersonal]]")
	end
	if ut.contains(subtypes, "nopass") then
		--coacēscō
		table.insert(appendix, "no [[passive#English|passive]]")
	end
	if ut.contains(subtypes, "depon") then
		-- dēmōlior
		-- calvor (also noperf)
		table.insert(appendix, "[[deponent#English|deponent]]")
	end
	if ut.contains(subtypes, "semidepon") then
		-- fīdō, gaudeō
		table.insert(appendix, "[[semi-deponent#English|semi-deponent]]")
	end
	if ut.contains(subtypes, "optsemidepon") then
		-- audeō, placeō, soleō, pudeō
		table.insert(appendix, "optionally [[semi-deponent#English|semi-deponent]]")
	end
	if ut.contains(subtypes, "noperf") then
		if (ut.contains(subtypes, "nopass") and not
			ut.contains(subtypes, "nosup") and not
			ut.contains(subtypes, "supfutractvonly")
		) then
			-- albēscō
			-- FIXME, this seems wrong
			table.insert(appendix, "no [[perfect#English|perfect]] or [[supine#English|supine]] forms")
		else
			-- īnsolēscō
			table.insert(appendix, "no [[perfect#English|perfect]]")
		end
	end
	if (ut.contains(subtypes, "noactvperf") or
		ut.contains(subtypes, "nopasvperf") or
		ut.contains(subtypes, "perfaspres") or
		ut.contains(subtypes, "def")
	) then
		-- interstinguō (noactvperf)
		-- ārēscō (nopasvperf)
		-- ōdī (perfaspres)
		-- āiō (def)
		table.insert(appendix, "[[defective#English|defective]]")
	end
	if ut.contains(subtypes, "nosup") then
		-- deeō etc.
		table.insert(appendix, "no [[supine#English|supine]] stem")
	end
	if ut.contains(subtypes, "supfutractvonly") then
		-- sum, dēpereō, etc.
		table.insert(appendix, "no [[supine#English|supine]] stem except in the [[future#English|future]] [[active#English|active]] [[participle#English|participle]]")
	end
	if ut.contains(subtypes, "pass3only") then
		--praefundō
		table.insert(appendix, "limited [[passive#English|passive]]")
	end
	if ut.contains(subtypes, "passimpers") then
		--abambulō
		table.insert(appendix, "[[impersonal#English|impersonal]] in the passive")
	end
	if ut.contains(subtypes, "facio") then
		--faciō
		table.insert(appendix, "irregular [[passive voice#English|passive voice]]")
	end
	if ut.contains(subtypes, "3only") then
		--decet
		table.insert(appendix,"[[third person#English|third person]] only")
	end
	if ut.contains(subtypes, "irreg") then
		--ferō
		table.insert(appendix, "[[irregular#English|irregular]]")
	end
	if ut.contains(subtypes, "noimp") then
		--volō
		table.insert(appendix, "no [[imperative#English|imperative]]")
	end
	if ut.contains(subtypes, "shortimp") then
		--dīcō
		table.insert(appendix, "irregular short [[imperative#English|imperative]]")
	end
	if ut.contains(subtypes, "nofut") then
		--soleō
		table.insert(appendix, "no [[future#English|future]]")
	end
end

pos_functions["adjectives"] = function(class, args, data, infl_classes, appendix)
	if class == "1&2" or class == "3-3E" then
		pos_functions["adjectives-m-f-n"](class, args, data, infl_classes, appendix)
	elseif class == "3-1E" then
		pos_functions["adjectives-mfn-gen"](class, args, data, infl_classes, appendix)
	elseif class == "3-2E" then
		pos_functions["adjectives-mf-n"](class, args, data, infl_classes, appendix)
	elseif class == "comp" then
		pos_functions["adjectives-comp"](class, args, data, infl_classes, appendix)
	elseif class == "sup" then
		pos_functions["adjectives-sup"](class, args, data, infl_classes, appendix)
	end
end

pos_functions["adjectives-m-f-n"] = function(class, args, data, infl_classes, appendix)
	params = {
		[1] = {alias_of = 'head'},
		[2] = {alias_of = 'f'},
		[3] = {alias_of = 'n'},
		["head"] = {list = true, required = true},
		["f"] = {list = true, required = true},
		["n"] = {list = true, required = true},
		["comp"] = {list = true},
		["sup"] = {list = true},
		["id"] = {},
	}
	local args = require("Module:parameters").process(args, params)
	data.heads = args.head
	data.id = args.id
	
	args.f.label = "feminine"
	args.n.label = "neuter"
	
	table.insert(data.inflections, args.f)
	table.insert(data.inflections, args.n)
	if #args.comp > 0 then
		args.comp.label = "comparative"
		table.insert(data.inflections, args.comp)
	end
	if #args.sup > 0 then
		args.sup.label = "superlative"
		table.insert(data.inflections, args.sup)
	end
	
	if class == "1&2" then
		table.insert(infl_classes, "[[Appendix:Latin first declension|first]]")
		table.insert(infl_classes, "[[Appendix:Latin second declension|second declension]]")
	elseif class == "3-3E" then
		table.insert(infl_classes, "[[Appendix:Latin third declension|third declension]]")
	end
end

pos_functions["adjectives-mfn-gen"] = function(class, args, data, infl_classes, appendix)
	params = {
		[1] = {alias_of = 'head'},
		[2] = {alias_of = 'gen'},
		["head"] = {list = true, required = true},
		["gen"] = {list = true, required = true},
		["comp"] = {list = true},
		["sup"] = {list = true},
		["id"] = {},
	}
	local args = require("Module:parameters").process(args, params)
	data.heads = args.head
	data.id = args.id
	
	args.gen.label = "genitive"
	
	table.insert(data.inflections, args.gen)
	
	if #args.comp > 0 then
		args.comp.label = "comparative"
		table.insert(data.inflections, args.comp)
	end
	if #args.sup > 0 then
		args.sup.label = "superlative"
		table.insert(data.inflections, args.sup)
	end
	
	if class == "3-1E" then
		table.insert(infl_classes, "[[Appendix:Latin third declension|third declension]]")
	end
end

pos_functions["adjectives-mf-n"] = function(class, args, data, infl_classes, appendix)
	params = {
		[1] = {alias_of = 'head'},
		[2] = {alias_of = 'n'},
		["head"] = {list = true, required = true},
		["n"] = {list = true, required = true},
		["comp"] = {list = true},
		["sup"] = {list = true},
		["id"] = {},
	}
	local args = require("Module:parameters").process(args, params)
	data.heads = args.head
	data.id = args.id
	
	args.n.label = "neuter"
	
	table.insert(data.inflections, args.n)
	
	if #args.comp > 0 then
		args.comp.label = "comparative"
		table.insert(data.inflections, args.comp)
	end
	if #args.sup > 0 then
		args.sup.label = "superlative"
		table.insert(data.inflections, args.sup)
	end
	
	if class == "3-2E" then
		table.insert(infl_classes, "[[Appendix:Latin third declension|third declension]]")
	end
end

pos_functions["adjectives-comp"] = function(class, args, data, infl_classes, appendix)
	params = {
		[1] = {alias_of = 'head'},
		[2] = {alias_of = 'comp'},
		["head"] = {list = true, default = mw.title.getCurrentTitle().text},
		["comp"] = {},
		["id"] = {},
	}
	local args = require("Module:parameters").process(args, params)
	data.heads = args.head
	data.id = args.id
	table.insert(data.categories, "Latin comparative adjectives")
	table.insert(infl_classes, "[[Appendix:Latin third declension|third declension]]")
	
	local n = {label = "neuter"}
	for _, head in ipairs(args.head) do
		local neuter = mw.ustring.gsub(head, "or$", "us")
		table.insert(n, neuter)
	end
	
	table.insert(data.inflections, n)
	
	if args.comp then
		-- [[Special:WhatLinksHere/Template:tracking/la-adj-comparative]]
		require("Module:debug").track("la-adj-comparative")
	end
end

pos_functions["adjectives-sup"] = function(class, args, data, infl_classes, appendix)
	params = {
		[1] = {alias_of = 'head'},
		[2] = {alias_of = 'sup'},
		["head"] = {list = true, default = mw.title.getCurrentTitle().text},
		["sup"] = {},
		["id"] = {},
	}
	local args = require("Module:parameters").process(args, params)
	data.heads = args.head
	data.id = args.id
	
	table.insert(data.categories, "Latin superlative adjectives")
	table.insert(infl_classes, "[[Appendix:Latin first declension|first]]")
	table.insert(infl_classes, "[[Appendix:Latin second declension|second declension]]")
	
	local f, n = {label = "feminine"}, {label = "neuter"}
	for _, head in ipairs(args.head) do
		local stem = mw.ustring.gsub(head, "us$", "")
		table.insert(f, stem .. "a")
		table.insert(n, stem .. "um")
	end
	
	table.insert(data.inflections, f)
	table.insert(data.inflections, n)
	
	if args.sup then
		-- [[Special:WhatLinksHere/Template:tracking/la-adj-superlative]]
		require("Module:debug").track("la-adj-superlative")
	end
end

pos_functions["adverbs"] = function(class, args, data, infl_classes, appendix)
	params = {
		[1] = {alias_of = 'head'},
		[2] = {alias_of = 'comp'},
		[3] = {alias_of = 'sup'},
		["head"] = {list = true, required = true},
		["comp"] = {list = true},
		["sup"] = {list = true},
		["id"] = {},
	}
	
	local args = require("Module:parameters").process(args, params)
	data.heads = args.head
	data.id = args.id
	
	if #args.comp > 0 and args.comp[1] ~= "-" then
		args.comp.label = glossary_link("comparative")
		table.insert(data.inflections, args.comp)
		if #args.sup > 0 and args.sup[1] ~= "-" then
			args.sup.label = glossary_link("superlative")
			table.insert(data.inflections, args.sup)
		else
			table.insert(data.inflections, {label = "no [[Appendix:Glossary#superlative|superlative]]"})
		end
		table.insert(data.categories, "Latin irregular adverbs")
	elseif args.comp[1] == "-" then
		table.insert(data.inflections, {label = "not [[Appendix:Glossary#comparative|comparable]]"})
		table.insert(data.categories, "Latin uncomparable adverbs")
	else
		local comp = {label = glossary_link("comparative")}
		local sup = {label = glossary_link("superlative")}
		for _, head in ipairs(args.head) do
			local stem = nil
			for _, suff in ipairs({"iter", "nter", "ter", "er", "iē", "ē", "im", "ō"}) do
				stem = mw.ustring.match(head, "(.*)" .. suff .. "$")
				if stem ~= nil then
					if suff == "nter" then
						stem = stem .. "nt"
						suff = "er"
					end
					table.insert(comp, stem .. "ius")
					table.insert(sup, stem .. "issimē")
					break
				end
			end
			if not stem then
				error("Unrecognized adverb type, recognized types are “-ē”, “-er”, “-ter”, “-iter”, “-im”, or “-ō” or specify irregular forms or “-” if incomparable.")
			end
		end
		table.insert(data.inflections, comp)
		if args.sup[1] ~= '-' then
			table.insert(data.inflections, sup)
		else
			table.insert(data.inflections, {label = "no [[Appendix:Glossary#superlative|superlative]]"})
			table.insert(data.categories, "Latin irregular adverbs")
		end
	end
end

local prepositional_cases = {
	genitive = true, accusative = true, ablative = true,
}
pos_functions["prepositions"] = function(class, args, data, infl_classes, appendix, postscript)
	params = {
		[1] = {list = true, required = true}, -- headword or cases
		["head"] = {list = true},
		["id"] = {},
	}
	
	local args = require("Module:parameters").process(args, params)
	
	-- Case names are supplied in numbered arguments, optionally preceded by
	-- headwords.
	local cases = {}
	while prepositional_cases[args[1][#args[1]]] do
		table.insert(cases, 1, table.remove(args[1]))
	end
	
	for i = 1, #cases do
		for j = i + 1, #cases do
			if cases[i] == cases[j] then
				error("Duplicate case")
			end
		end
		local case = cases[i]
		local appendix_link = glossary_link(case)
		if i == 1 then
			appendix_link = "+ " .. appendix_link
		end
		table.insert(postscript, appendix_link)
		table.insert(data.categories, "Latin " .. case .. " prepositions")
	end
	
	for _, v in ipairs(args[1]) do
		table.insert(args.head, 1, v)
	end
	
	data.heads = args.head
	data.id = args.id
end

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
