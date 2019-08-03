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

local new_legal_gender = {
	["m"] = true,
	["f"] = true,
	["n"] = true,
	["c"] = true,
	["?"] = true,
}

local legal_declension = {
	["first"] = true,
	["second"] = true,
	["third"] = true,
	["fourth"] = true,
	["fifth"] = true,
	["irregular"] = true,
}

local new_declension_to_old_declension = {
	["1"] = "first",
	["2"] = "second",
	["3"] = "third",
	["4"] = "fourth",
	["5"] = "fifth",
	["irreg"] = "irregular",
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

local new_gender_names = {
	["m"] = "masculine",
	["f"] = "feminine",
	["n"] = "neuter",
	["c"] = "common",
	["?"] = "unknown gender",
}

local lang = require("Module:languages").getByCode("la")

local u = mw.ustring.char
local rfind = mw.ustring.find
local rsplit = mw.text.split
local rsubn = mw.ustring.gsub
local ulower = mw.ustring.lower

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
	local args = frame:getParent().args
	local NAMESPACE = mw.title.getCurrentTitle().nsText
	local PAGENAME = mw.title.getCurrentTitle().text
	
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
	end

	if pos_functions[postype] then
		pos_functions[postype](class, args, data, infl_classes, appendix, postscript)
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
	if not args[2] and not args[3] and not args[4] then
		return pos_functions["nouns-new"](class, args, data, infl_classes, appendix)
	end

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
			error("Gender “" .. g .. "” is not a valid Latin gender.")
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
			local NAMESPACE = mw.title.getCurrentTitle().nsText
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
			table.insert(data.inflections, args.gen)
		end
	end

	if #args.m > 0 then
		args.m.label = "masculine"
		table.insert(data.inflections, args.m)
	end

	if #args.f > 0 then
		args.f.label = "feminine"
		table.insert(data.inflections, args.f)
	end
end

pos_functions["nouns-new"] = function(class, args, data, infl_classes, appendix)
	local decldata = require("Module:la-nominal").do_generate_noun_forms(args, true)
	local lemma = decldata.overriding_lemma
	local lemma_num = decldata.num == "pl" and "pl" or "sg"
	if not lemma or #lemma == 0 then
		lemma = decldata.forms["linked_nom_" .. lemma_num]
	end

	data.heads = lemma
	data.id = decldata.id
	if decldata.pos then
		local NAMESPACE = mw.title.getCurrentTitle().nsText
		data.pos_category = (NAMESPACE == "Reconstruction" and "reconstructed " or "") .. decldata.pos
	end

	local genders = decldata.overriding_genders
	if #genders == 0 then
		if decldata.gender then
			genders = {ulower(decldata.gender)}
		else
			error("No gender explicitly specified in headword template using g=, and can't infer gender from lemma spec")
		end
	end

	for _, g in ipairs(genders) do
		if not new_legal_gender[g] then
			error("Gender “" .. g .. "” is not a valid Latin gender.")
		end
		local gender_name = new_gender_names[g]
		if decldata.num == "pl" then
			g = g .. "-p"
		elseif decldata.num == "sg" then
			g = g .. "-s"
		end
		table.insert(data.genders, g)
		table.insert(data.categories, "Latin " .. gender_name .. " nouns")
	end

	if decldata.indecl then
		table.insert(data.inflections, {label = glossary_link("indeclinable")})
		table.insert(data.categories, "Latin indeclinable nouns")
		for _, g in ipairs(genders) do
			table.insert(data.categories, "Latin " .. new_gender_names[g] ..  " indeclinable nouns")
		end
	else
		-- flatten declension specs
		local decls = {}
		for _, decl in ipairs(decldata.decls) do
			if type(decl) ~= "table" then
				-- skip adjectival declensions
				if not rfind(decl, "%+$") then
					ut.insert_if_not(decls, decl)
				end
			else
				for _, alternant in ipairs(decl) do
					for _, single_decl in ipairs(alternant) do
						-- skip adjectival declensions
						if not rfind(single_decl, "%+$") then
							ut.insert_if_not(decls, single_decl)
						end
					end
				end
			end
		end

		if #decls > 1 then
			table.insert(data.inflections, {label = 'variously declined'})
			table.insert(data.categories, "Latin nouns with multiple declensions")
		end

		for _, decl in ipairs(decls) do
			local decl_class = new_declension_to_old_declension[decl]
			if not decl_class then
				error("Something wrong with declension '" .. decl .. "', don't recognize it")
			end
			table.insert(appendix, "[[Appendix:Latin " .. decl_class .. " declension|" .. decl_class .. " declension]]")
			if decl_class ~= "irregular" then
				table.insert(data.categories, "Latin " .. decl_class .. " declension nouns")
			end

			for _, g in ipairs(genders) do
				table.insert(data.categories, "Latin " .. new_gender_names[g] ..  " nouns in the " .. decl_class .. " declension")
			end
		end

		local gen = decldata.forms["gen_" .. lemma_num]
		if gen and gen ~= "" and gen ~= "—" and #gen > 0 then
			gen.label = "genitive"
			table.insert(data.inflections, gen)
		else
			table.insert(data.inflections, {label = "no genitive"})
			table.insert(data.categories, "Latin nouns without a genitive singular")
		end
	end

	if #decldata.m > 0 then
		decldata.m.label = "masculine"
		table.insert(data.inflections, decldata.m)
	end

	if #decldata.f > 0 then
		decldata.f.label = "feminine"
		table.insert(data.inflections, decldata.f)
	end
end

pos_functions["proper nouns"] = pos_functions["nouns"]
pos_functions["suffixes-noun"] = pos_functions["nouns"]

export.allowed_subtypes = {
	["impers"] = true,
	["3only"] = true,
	["depon"] = true,
	["semidepon"] = true,
	["optsemidepon"] = true,
	["nopass"] = true,
	["pass3only"] = true,
	["passimpers"] = true,
	["perfaspres"] = true,
	["noperf"] = true,
	["nopasvperf"] = true,
	["nosup"] = true,
	["supfutractvonly"] = true,
	["noimp"] = true,
	["nofut"] = true,
	["p3inf"] = true,
	["poetsyncperf"] = true,
	["optsyncperf"] = true,
	["alwayssyncperf"] = true,
	["m"] = true,
	["f"] = true,
	["n"] = true,
	["mp"] = true,
	["fp"] = true,
	["np"] = true,
	-- can be specified manually in the headword to display "highly defective"
	-- in the title (e.g. aveō)
	["highlydef"] = true,
	-- FIXME, remove the remainder once we've converted all the verbs
	["shortimp"] = true,
	["def"] = true,
	["facio"] = true,
	["irreg"] = true,
}

-- FIXME, remove this once we've converted all the verbs
function export.split_verb_subtype(subtype)
	if not subtype or subtype == "" then
		return {}
	end

	subtype = rsub(subtype, "opt%-semi%-depon", "optsemidepon")
	subtype = rsub(subtype, "semi%-depon", "semidepon")
	subtype = rsub(subtype, "pass%-3only", "pass3only")
	subtype = rsub(subtype, "pass%-impers", "passimpers")
	subtype = rsub(subtype, "no%-pasv%-perf", "nopasvperf")
	subtype = rsub(subtype, "perf%-as%-pres", "perfaspres")
	subtype = rsub(subtype, "short%-imp", "shortimp")
	subtype = rsub(subtype, "sup%-futr%-actv%-only", "supfutractvonly")

	local subtypes = rsplit(subtype, "%-")

	for _, subtype in ipairs(subtypes) do
		if not export.allowed_subtypes[subtype] then
			error("Unrecognized verb subtype " .. subtype)
		end
	end

	return subtypes
end

-- FIXME, remove this and replace with verbs-new once we've converted all the verbs
pos_functions["verbs"] = function(class, args, data, infl_classes, appendix)
	if args[1] and (
		rfind(args[1], "^[0-9]%+*$") or rfind(args[1], "^[0-9]%+*%.") or
		rfind(args[1], "^irreg$") or rfind(args[1], "^irreg%.")
	) then
		return pos_functions["verbs-new"](class, args, data, infl_classes, appendix)
	end

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
		local NAMESPACE = mw.title.getCurrentTitle().nsText
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
			table.insert(appendix, "no [[perfect#English|perfect]] stem")
		end
	end
	if (ut.contains(subtypes, "nopasvperf") or
		ut.contains(subtypes, "perfaspres") or
		ut.contains(subtypes, "def")
	) then
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

pos_functions["verbs-new"] = function(class, args, data, infl_classes, appendix)
	local m_la_verb = require("Module:la-verb")
	local conjdata, typeinfo = m_la_verb.make_data(args, true)
	local lemma_forms = conjdata.overriding_lemma
	if not lemma_forms or #lemma_forms == 0 then
		lemma_forms = m_la_verb.get_lemma_forms(conjdata, true)
	end
	local first_lemma = ""
	if #lemma_forms > 0 then
		first_lemma = require("Module:links").remove_links(lemma_forms[1])
	end
	data.heads = lemma_forms
	data.id = conjdata.id
	local conj = typeinfo.conj_type
	local subconj = typeinfo.conj_subtype
	local subtypes = typeinfo.subtypes
	local perf_only = false

	local function insert_inflection(infl, label)
		for _, form in ipairs(infl) do
			if rsub(form, "^[*%[%]a-zA-ZĀāĒēĪīŌōŪūȲȳÄäËëÏïÖöÜüŸÿĂăĔĕĬĭŎŏŬŭ " .. accents .. "]+$", "") ~= "" then
				table.insert(data.categories, "la-verb invalid parameters")
			end
		end
		infl.label = label
		table.insert(data.inflections, infl)
	end


	local inf = m_la_verb.get_valid_forms(conjdata.forms["pres_actv_inf"])
	if #inf > 0 then
		insert_inflection(inf, "present infinitive")
	else
		inf = m_la_verb.get_valid_forms(conjdata.forms["perf_actv_inf"])
		if #inf > 0 then
			perf_only = true
			insert_inflection(inf, "perfect infinitive")
		end
	end

	local depon = typeinfo.subtypes.depon or typeinfo.subtypes.semidepon
	if not perf_only then
		local perf
		if depon then
			local sup = m_la_verb.get_valid_forms(conjdata.forms["sup_acc"])
			perf = {}
			for _, form in ipairs(sup) do
				if typeinfo.subtypes.impers then
					form = rsub(form, "^(.*)m$", "[[%1s|%1m]] est")
				elseif typeinfo.subtypes["3only"] then
					form = rsub(form, "^(.*)m$", "[[%1s]] est")
				else
					form = rsub(form, "^(.*)m$", "[[%1s]] sum")
				end
				table.insert(perf, form)
			end
		else
			perf = m_la_verb.get_valid_forms(conjdata.forms["1s_perf_actv_indc"])
			if #perf == 0 then
				perf = m_la_verb.get_valid_forms(conjdata.forms["3s_perf_actv_indc"])
			end
		end
		if #perf > 0 then
			insert_inflection(perf, "perfect active")
		end
	end

	if not depon then
		local sup = m_la_verb.get_valid_forms(conjdata.forms["sup_acc"])
		if #sup > 0 then
			insert_inflection(sup, "supine")
		else
			local fap = m_la_verb.get_valid_forms(conjdata.forms["futr_actv_ptc"])
			if #fap > 0 then
				insert_inflection(fap, "future participle")
			end
		end
	end

	if conj == "1st" or subconj == "1st" then
		table.insert(appendix, "[[Appendix:Latin first conjugation|first conjugation]]")
	elseif conj == "2nd" or subconj == "2nd" then
		table.insert(appendix, "[[Appendix:Latin second conjugation|second conjugation]]")
	elseif conj == "3rd" or subconj == "3rd" then
		table.insert(appendix, "[[Appendix:Latin third conjugation|third conjugation]]")
	elseif conj == "3rd-io" or subconj == "3rd-io" then
		table.insert(appendix, "[[Appendix:Latin third conjugation|third conjugation]] iō-variant")
	elseif conj == "4th" or subconj == "4th" then
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

	if conj == "irreg" and subconj == "irreg" or subtypes.irreg then
		--sum, volō, ferō etc.
		table.insert(appendix, "[[irregular#English|irregular]]")
	end
	if subtypes.highlydef then
		-- āiō, inquam
		table.insert(appendix, "highly [[defective#English|defective]]")
	end
	if subtypes.perfaspres then
		-- ōdī, meminī, commeminī
		table.insert(appendix, "[[perfect#English|perfect]] forms have [[present#English|present]] meaning")
	end
	if subtypes.impers then
		-- decet
		-- advesperāscit (also nopass)
		table.insert(appendix, "[[impersonal#English|impersonal]]")
	end
	if subtypes.nopass then
		--coacēscō
		table.insert(appendix, "no [[passive#English|passive]]")
	end
	if subtypes.depon then
		-- dēmōlior
		-- calvor (also noperf)
		table.insert(appendix, "[[deponent#English|deponent]]")
	end
	if subtypes.semidepon then
		-- fīdō, gaudeō
		table.insert(appendix, "[[semi-deponent#English|semi-deponent]]")
	end
	if subtypes.optsemidepon then
		-- audeō, placeō, soleō, pudeō
		table.insert(appendix, "optionally [[semi-deponent#English|semi-deponent]]")
	end
	if subtypes.nosup and subtypes.noperf then
		-- many verbs
		table.insert(appendix, "no [[perfect#English|perfect]] or [[supine#English|supine]] stem")
	elseif subtypes.noperf then
		-- īnsolēscō etc.
		table.insert(appendix, "no [[perfect#English|perfect]] stem")
	elseif subtypes.nosup then
		-- deeō etc.
		table.insert(appendix, "no [[supine#English|supine]] stem")
	elseif subtypes.supfutractvonly then
		-- sum, dēpereō, etc.
		table.insert(appendix, "no [[supine#English|supine]] stem except in the [[future#English|future]] [[active#English|active]] [[participle#English|participle]]")
	end
	if typeinfo.subtypes.nopasvperf and not typeinfo.subtypes.nosup and
			not typeinfo.subtypes.supfutractvonly then
		table.insert(appendix, "no [[passive#English|passive]] [[perfect#English|perfect]] forms")
	end
	if subtypes.pass3only then
		--praefundō
		table.insert(appendix, "limited [[passive#English|passive]]")
	end
	if subtypes.passimpers then
		--abambulō
		table.insert(appendix, "[[impersonal#English|impersonal]] in the passive")
	end
	if rfind(first_lemma, "faciō$") then
		--faciō
		table.insert(appendix, "irregular [[passive voice#English|passive voice]]")
	end
	if subtypes["3only"] then
		--decet
		table.insert(appendix,"[[third person#English|third person]] only")
	end
	if subtypes.noimp then
		--volō
		table.insert(appendix, "no [[imperative#English|imperative]]")
	end
	if rfind(first_lemma, "d[īū]cō$") then
		--dīcō
		table.insert(appendix, "irregular short [[imperative#English|imperative]]")
	end
	if subtypes.nofut then
		--soleō
		table.insert(appendix, "no [[future#English|future]]")
	end
end

pos_functions["suffixes-verb"] = pos_functions["verbs"]

pos_functions["adjectives"] = function(class, args, data, infl_classes, appendix)
	if class == "new" then
		pos_functions["adjectives-new"](class, args, data, infl_classes, appendix)
	elseif class == "comp" then
		pos_functions["adjectives-comp"](class, args, data, infl_classes, appendix)
	elseif class == "sup" then
		pos_functions["adjectives-sup"](class, args, data, infl_classes, appendix)
	end
end

pos_functions["adjectives-new"] = function(class, args, data, infl_classes, appendix)
	local decldata = require("Module:la-nominal").do_generate_adj_forms(args, true)
	local lemma = decldata.overriding_lemma
	local lemma_num = decldata.num == "pl" and "pl" or "sg"
	if not lemma or #lemma == 0 then
		lemma = decldata.forms["linked_nom_" .. lemma_num .. "_m"]
	end

	data.heads = lemma
	data.id = decldata.id
	if decldata.pos then
		local NAMESPACE = mw.title.getCurrentTitle().nsText
		data.pos_category = (NAMESPACE == "Reconstruction" and "reconstructed " or "") .. decldata.pos
	end

	local masc = decldata.forms["nom_" .. lemma_num .. "_m"]
	local fem = decldata.forms["nom_" .. lemma_num .. "_f"]
	local neut = decldata.forms["nom_" .. lemma_num .. "_n"]
	local gen = decldata.forms["gen_" .. lemma_num .. "_m"]

	local function is_missing(form)
		return not form or form == "" or form == "—" or #form == 0
	end
	-- We display the inflections in three different ways to mimic the
	-- old way of doing things:
	--
	-- 1. If masc and fem are different, show masc, fem and neut.
	-- 2. Otherwise, if masc and neut are different, show masc and neut.
	-- 3. Otherwise, show masc nominative and masc genitive.
	if not is_missing(fem) and not ut.equals(masc, fem) then
		fem.label = "feminine"
		table.insert(data.inflections, fem)
		if not is_missing(neut) then
			neut.label = "neuter"
			table.insert(data.inflections, neut)
		end
	elseif not is_missing(neut) and not ut.equals(masc, neut) then
		neut.label = "neuter"
		table.insert(data.inflections, neut)
	elseif not is_missing(gen) then
		gen.label = "genitive"
		table.insert(data.inflections, gen)
	end

	if #decldata.comp > 0 then
		decldata.comp.label = "comparative"
		table.insert(data.inflections, decldata.comp)
	end
	if #decldata.sup > 0 then
		decldata.sup.label = "superlative"
		table.insert(data.inflections, decldata.sup)
	end

	table.insert(infl_classes, decldata.title)
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

pos_functions["suffixes-adjective"] = pos_functions["adjectives"]

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
	local comp, sup
	local irreg = false

	if args.comp[1] == "-" then
		comp = "-"
	elseif #args.comp > 0 then
		args.comp.label = glossary_link("comparative")
		comp = args.comp
		irreg = true
	end
	if args.comp[1] == "-" or args.sup[1] == "-" then
		sup = "-"
	elseif #args.sup > 0 then
		args.sup.label = glossary_link("superlative")
		sup = args.sup
		irreg = true
	end
	if irreg then
		table.insert(data.categories, "Latin irregular adverbs")
	end

	if not comp or not sup then
		local default_comp = {label = glossary_link("comparative")}
		local default_sup = {label = glossary_link("superlative")}
		for _, head in ipairs(args.head) do
			local stem = nil
			for _, suff in ipairs({"iter", "nter", "ter", "er", "iē", "ē", "im", "ō"}) do
				stem = mw.ustring.match(head, "(.*)" .. suff .. "$")
				if stem ~= nil then
					if suff == "nter" then
						stem = stem .. "nt"
						suff = "er"
					end
					table.insert(default_comp, stem .. "ius")
					table.insert(default_sup, stem .. "issimē")
					break
				end
			end
			if not stem then
				error("Unrecognized adverb type, recognized types are “-ē”, “-er”, “-ter”, “-iter”, “-im”, or “-ō” or specify irregular forms or “-” if incomparable.")
			end
		end
		comp = comp or default_comp
		sup = sup or default_sup
	end

	if comp == "-" then
		table.insert(data.inflections, {label = "not [[Appendix:Glossary#comparative|comparable]]"})
		table.insert(data.categories, "Latin uncomparable adverbs")
	else
		table.insert(data.inflections, comp)
	end
	if sup == "-" then
		if comp ~= "-" then
			table.insert(data.inflections, {label = "no [[Appendix:Glossary#superlative|superlative]]"})
		end
	else
		table.insert(data.inflections, sup)
	end
end

pos_functions["suffixes-adverb"] = pos_functions["adverbs"]

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
