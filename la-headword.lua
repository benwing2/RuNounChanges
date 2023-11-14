local export = {}
local pos_functions = {}

local m_table = require("Module:table")

local legal_gender = {
	["m"] = true,
	["f"] = true,
	["n"] = true,
	["?"] = true,
	["?!"] = true,
}

local declension_to_english = {
	["1"] = "first",
	["2"] = "second",
	["3"] = "third",
	["4"] = "fourth",
	["5"] = "fifth",
}

local gender_names = {
	["m"] = "masculine",
	["f"] = "feminine",
	["n"] = "neuter",
	["?"] = "unknown gender",
	["?!"] = "unattested gender",
}

local lang = require("Module:languages").getByCode("la")

local u = mw.ustring.char
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
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

local function track(page)
	require("Module:debug").track("la-headword/" .. page)
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
	local infl_classes = {}
	local appendix = {}
	local postscript = {}

	if poscat == "suffixes" then
		table.insert(data.categories, "Latin " .. suff_type .. "-forming suffixes")
	end

	if pos_functions[postype] then
		local new_poscat = pos_functions[postype](def, args, data, infl_classes, appendix, postscript)
		if new_poscat then
			poscat = new_poscat
		end
	end

	if (NAMESPACE == "Reconstruction") then
		data.pos_category = "reconstructed " .. poscat
		data.nolink = true
	else
		data.pos_category = poscat
	end

	postscript = table.concat(postscript, ", ")

	return
		require("Module:headword").full_headword(data)
		.. format(infl_classes, "/")
		.. format(appendix, ", ")
		.. (postscript ~= "" and " (" .. postscript .. ")" or "")
end

local function process_num_type(numtype, categories)
	if numtype == "card" then
		table.insert(categories, "Latin cardinal numbers")
	elseif numtype == "ord" then
		table.insert(categories, "Latin ordinal numbers")
	elseif numtype == "dist" then
		-- FIXME, should be named 'Latin distributive numbers'
		table.insert(categories, "la:Distributive numbers")
	elseif numtype == "mul" then
		-- FIXME, should be named 'Latin multiplicative numbers'
		table.insert(categories, "la:Multiplicative numbers")
	elseif numtype == "coll" then
		-- FIXME, should be named 'Latin collective numbers'
		table.insert(categories, "la:Collective numbers")
	elseif numtype then
		error("Unrecognized numeral type '" .. numtype .. "'")
	end
end

local function nouns(pos, def, args, data, infl_classes, appendix)
	local NAMESPACE = mw.title.getCurrentTitle().nsText
	local is_num = pos == "numerals"
	local is_pn = false
	if pos == "proper nouns" then
		is_pn = true
		pos = "nouns"
	end
	local decldata = require("Module:la-nominal").do_generate_noun_forms(
	  args, pos, true, def, is_num)
	local lemma = decldata.overriding_lemma
	local lemma_num = decldata.num == "pl" and "pl" or "sg"
	if not lemma or #lemma == 0 then
		lemma = decldata.forms["linked_nom_" .. lemma_num]
		if decldata.unattested["nom_" .. lemma_num] then
			lemma[1] = '*' .. lemma[1]
		end
	end

	data.heads = lemma
	-- Since we always set data.heads to the lemma and specification of the lemma is mandatory in {{la-noun}}, there aren't
	-- really any redundant heads.
	data.no_redundant_head_cat = true
	data.id = decldata.id
	
	local genders = decldata.overriding_genders
	if #genders == 0 then
		if decldata.gender then
			genders = {ulower(decldata.gender)}
		elseif not is_num then
			error("No gender explicitly specified in headword template using g=, and can't infer gender from lemma spec")
		end
	end

	if is_num then
		process_num_type(decldata.num_type, data.categories)
	end

	if decldata.indecl then
		table.insert(data.inflections, {label = glossary_link("indeclinable")})
		table.insert(data.categories, "Latin indeclinable " .. decldata.pos)

		for _, g in ipairs(genders) do
			local gender, number = rmatch(g, "^(.)%-([sp])$")
			if not gender then
				gender = g
			end
			if not legal_gender[gender] then
				error("Gender “" .. gender .. "” is not a valid Latin gender.")
			end
			table.insert(data.genders, g)
			local gender_name = gender_names[gender]
			table.insert(data.categories, "Latin " .. gender_name ..  " indeclinable " .. decldata.pos)
		end
	else
		local is_irreg = false
		local is_indecl = false
		local is_decl = false
		local has_multiple_decls = false
		local has_multiple_variants = false
		-- flatten declension specs
		local decls = {}

		for _, g in ipairs(genders) do
			if not legal_gender[g] then
				error("Gender “" .. g .. "” is not a valid Latin gender.")
			end
			local gender_name = gender_names[g]
			if decldata.num == "pl" then
				g = g .. "-p"
			elseif decldata.num == "sg" then
				g = g .. "-s"
			end
			table.insert(data.genders, g)
		end

		local function process_decl(decl_list, decl)
			-- skip adjectival declensions
			if not rfind(decl, "%+$") then
				local irreg_decl_spec = rmatch(decl, "^irreg/(.*)$")
				if irreg_decl_spec then
					is_irreg = true
					local irreg_decls = rsplit(irreg_decl_spec, ",")
					if #irreg_decls > 1 then
						has_multiple_decls = true
					end
					for _, d in ipairs(irreg_decls) do
						if d == "indecl" or decl == "0" then
							is_indecl = true
						else
							is_decl = true
						end
						m_table.insertIfNot(decl_list, d)
					end
				else
					if decl == "indecl" or decl == "0" then
						is_indecl = true
					else
						is_decl = true
					end
					m_table.insertIfNot(decl_list, decl)
				end
			end
		end

		for _, props in ipairs(decldata.propses) do
			if props.headword_decl then
				process_decl(decls, props.headword_decl)
			else
				local alternant_decls = {}
				for _, alternant in ipairs(props) do
					for _, single_props in ipairs(alternant) do
						process_decl(alternant_decls, single_props.headword_decl)
					end
				end
				if #alternant_decls > 1 then
					has_multiple_decls = true
				elseif #decls > 1 then
					has_multiple_variants = true
				end
				for _, d in ipairs(alternant_decls) do
					m_table.insertIfNot(decls, d)
				end
			end
		end

		if is_indecl and is_decl then
			has_multiple_decls = true
		end
		if has_multiple_decls then
			table.insert(data.categories, "Latin " .. decldata.pos .. " with multiple declensions")
		end
		if has_multiple_variants then
			table.insert(data.categories, "Latin " .. decldata.pos .. " with multiple variants of a single declension")
		end
		if is_irreg then
			table.insert(data.inflections, {label = glossary_link("irregular")})
			table.insert(data.categories, "Latin irregular " .. decldata.pos)
			for _, g in ipairs(genders) do
				table.insert(data.categories, "Latin " .. gender_names[g] ..  " irregular " .. decldata.pos)
			end
		end

		if is_indecl then
			if is_decl then
				table.insert(appendix, glossary_link("indeclinable"))
			else
				table.insert(data.inflections, {label = glossary_link("indeclinable")})
			end
			table.insert(data.categories, "Latin indeclinable " .. decldata.pos)
			for _, g in ipairs(genders) do
				table.insert(data.categories, "Latin " .. gender_names[g] ..  " indeclinable " .. decldata.pos)
			end
		end

		if #decls > 1 then
			table.insert(data.inflections, {label = 'variously declined'})
			--This causes multipart nouns composed of two nouns of different declensions
			--to go into the category. The above code only triggers if a given term has
			--multiple declensions.
			--table.insert(data.categories, "Latin " .. decldata.pos .. " with multiple declensions")
		end

		for _, decl in ipairs(decls) do
			if decl ~= "irreg" and decl ~= "indecl" and decl ~= "0" then
				local decl_class = declension_to_english[decl]
				if not decl_class then
					error("Something wrong with declension '" .. decl .. "', don't recognize it")
				end
				table.insert(appendix, "[[Appendix:Latin " .. decl_class .. " declension|" .. decl_class .. " declension]]")
				table.insert(data.categories, "Latin " .. decl_class .. " declension " .. decldata.pos)

				for _, g in ipairs(genders) do
					table.insert(data.categories, "Latin " .. gender_names[g] ..  " " .. decldata.pos .. " in the " .. decl_class .. " declension")
				end
			end
		end

		if NAMESPACE == 'Reconstruction' then
			-- For reconstructed nouns:
			if data.genders[1] == 'n' and lemma_num == 'sg' then
				-- singular neuter nouns give a plural
				local pl = decldata.forms["nom_pl"]
				if pl and pl ~= "" and #pl > 0 then
					pl.label = "plural"
					table.insert(data.inflections, pl)
				end
			else
				-- all others give an oblique
				local obl = decldata.forms["acc_" .. lemma_num]
				if obl and obl ~= "" and #obl > 0 then
					obl.label = "oblique"
					table.insert(data.inflections, obl)
				end
			end
		else
			local gen = decldata.forms["gen_" .. lemma_num]
			if (decldata.unattested["gen_" .. lemma_num]) then
				gen[1] = '*' .. gen[1]
				data.nolink = true
			end
			if gen and gen ~= "" and gen ~= "—" and #gen > 0 then
				if is_decl then
					-- Skip displaying the genitive for nouns that are only
					-- indeclinable. But we do display it for nouns like Abrahām
					-- and Ādām that can be either indeclinable or declined.
					gen.label = "genitive"
					table.insert(data.inflections, gen)
				end
			else
				table.insert(data.inflections, {label = "no genitive"})
				table.insert(data.categories, "Latin " .. decldata.pos .. " without a genitive singular")
			end
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

	for _, cat in ipairs(decldata.categories) do
		m_table.insertIfNot(data.categories, cat)
	end

	for _, cat in ipairs(decldata.cat) do
		m_table.insertIfNot(data.categories, "Latin " .. cat)
	end
	
	return is_pn and decldata.pos == "nouns" and "proper nouns" or decldata.pos
end

pos_functions["nouns"] = function(def, args, data, infl_classes, appendix)
	return nouns("nouns", def, args, data, infl_classes, appendix)
end

pos_functions["proper nouns"] = function(def, args, data, infl_classes, appendix)
	return nouns("proper nouns", def, args, data, infl_classes, appendix)
end

pos_functions["suffixes-noun"] = function(def, args, data, infl_classes, appendix)
	return nouns("suffixes", def, args, data, infl_classes, appendix)
end

pos_functions["numerals-noun"] = function(def, args, data, infl_classes, appendix)
	return nouns("numerals", def, args, data, infl_classes, appendix)
end

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
}

pos_functions["verbs"] = function(def, args, data, infl_classes, appendix)
	local m_la_verb = require("Module:la-verb")
	local NAMESPACE = mw.title.getCurrentTitle().nsText
	local def1, def2
	if def then
		def1, def2 = rmatch(def, "^(.*):(.*)$")
	end
	local conjdata, typeinfo = m_la_verb.make_data(args, true, def1, def2)
	local lemma_forms = conjdata.overriding_lemma
	if not lemma_forms or #lemma_forms == 0 then
		lemma_forms = m_la_verb.get_lemma_forms(conjdata, true)
	end
	local first_lemma = ""
	if #lemma_forms > 0 then
		first_lemma = require("Module:links").remove_links(lemma_forms[1])
	end
	data.heads = lemma_forms
	-- Since we always set data.heads to the lemma and specification of the lemma is mandatory in {{la-verb}}, there aren't
	-- really any redundant heads.
	data.no_redundant_head_cat = true
	data.id = conjdata.id
	local conj = typeinfo.conj_type
	local subconj = typeinfo.conj_subtype
	local subtypes = typeinfo.subtypes
	local perf_only = false

	local function insert_inflection(infl, label)
		for _, form in ipairs(infl) do
			if rsub(form, "^[*%[%]|%-a-zA-ZĀāĒēĪīŌōŪūȲȳÄäËëÏïÖöÜüŸÿĂăĔĕĬĭŎŏŬŭ " .. accents .. "]+$", "") ~= "" then
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
	if (conj == "3rd" or conj == "irreg") and rfind(first_lemma, "d[īū]cō$") then
		--dīcō
		table.insert(appendix, "irregular short [[imperative#English|imperative]]")
	end
	if subtypes.nofut then
		--soleō
		table.insert(appendix, "no [[future#English|future]]")
	end
end

pos_functions["suffixes-verb"] = pos_functions["verbs"]

local function adjectives(pos, def, args, data, infl_classes, appendix)
	local is_num = pos == "numerals"
	local decldata = require("Module:la-nominal").do_generate_adj_forms(
	  args, pos, true, def, is_num)
	local lemma = decldata.overriding_lemma
	local lemma_num = decldata.num == "pl" and "pl" or "sg"
	if not lemma or #lemma == 0 then
		lemma = decldata.forms["linked_nom_" .. lemma_num .. "_m"]
		if decldata.unattested["nom_" .. lemma_num .. "_m"] then
			lemma[1] = '*' .. lemma[1]
		end
	end

	data.heads = lemma
	-- Since we always set data.heads to the lemma and specification of the lemma is mandatory in {{la-noun}}, there aren't
	-- really any redundant heads.
	data.no_redundant_head_cat = true
	data.id = decldata.id

	if is_num then
		process_num_type(decldata.num_type, data.categories)
	end

	if decldata.num == "pl" then
		table.insert(data.categories, "Latin plural-only " .. decldata.pos)
	end

	if decldata.indecl then
		table.insert(data.inflections, {label = glossary_link("indeclinable")})

		if decldata.pos == "participles" then
			if rfind(lemma[1], "[stxu]um$") then
				table.insert(data.categories, "Latin perfect participles")
			end
		end
	else

		local function attested_form(index)
			local form
			if (decldata.unattested[index]) then
				form = { { term = '*' .. decldata.forms[index][1], nolink = true } }
			else
				form = decldata.forms[index]
			end
			return form
		end

		local masc = decldata.forms["nom_" .. lemma_num .. "_m"]
		local fem = attested_form("nom_" .. lemma_num .. "_f")
		local neut = attested_form("nom_" .. lemma_num .. "_n")
		local gen = attested_form("gen_" .. lemma_num .. "_m")
	
		if decldata.pos == "participles" then
			if rfind(masc[1], "ūrus$") then
				table.insert(data.categories, "Latin future participles")
			elseif rfind(masc[1], "ndus$") then
				-- FIXME, should rename to "Latin gerundives")
				table.insert(data.categories, "Latin future passive participles")
			elseif rfind(masc[1], "[stxu]us$") then
				table.insert(data.categories, "Latin perfect participles")
			elseif rfind(masc[1], "ns$") then
				table.insert(data.categories, "Latin present participles")
			else
				error("Unrecognized participle ending: " .. masc[1])
			end
		end
	
		local function is_missing(form)
			return not form or form == "" or form == "—" or #form == 0
		end
		-- We display the inflections in three different ways to mimic the
		-- old way of doing things:
		--
		-- 1. If masc and fem are different, show masc, fem and neut.
		-- 2. Otherwise, if masc and neut are different, show masc and neut.
		-- 3. Otherwise, show masc nominative and masc genitive.
		if not is_missing(fem) and not m_table.deepEquals(masc, fem) then
			fem.label = "feminine"
			table.insert(data.inflections, fem)
			if not is_missing(neut) then
				neut.label = "neuter"
				table.insert(data.inflections, neut)
			end
		elseif not is_missing(neut) and not m_table.deepEquals(masc, neut) then
			neut.label = "neuter"
			table.insert(data.inflections, neut)
		elseif not is_missing(gen) then
			gen.label = "genitive"
			table.insert(data.inflections, gen)
		end

		table.insert(infl_classes, decldata.title)
	end

	if #decldata.comp > 0 then
		decldata.comp.label = "comparative"
		table.insert(data.inflections, decldata.comp)
	end
	if #decldata.sup > 0 then
		decldata.sup.label = "superlative"
		table.insert(data.inflections, decldata.sup)
	end
	if #decldata.adv > 0 then
		decldata.adv.label = "adverb"
		table.insert(data.inflections, decldata.adv)
	end

	for _, cat in ipairs(decldata.categories) do
		m_table.insertIfNot(data.categories, cat)
	end

	for _, cat in ipairs(decldata.cat) do
		m_table.insertIfNot(data.categories, "Latin " .. cat)
	end
	
	return decldata.pos
end

local function adjectives_comp(pos, def, args, data, infl_classes, appendix)
	local params = {
		[1] = {alias_of = 'head'},
		[2] = {alias_of = 'pos'},
		["head"] = {list = true},
		["pos"] = {list = true},
		["is_lemma"] = {type = "boolean"},
		["id"] = {},
	}
	local args = require("Module:parameters").process(args, params)
	data.no_redundant_head_cat = #args.head == 0
	-- Set default manually so we can tell whether the user specified head=.
	if #args.head == 0 then
		args.head = {mw.title.getCurrentTitle().text}
	end
	data.heads = args.head
	data.id = args.id

	if args.is_lemma then
		-- See below. This happens automatically by virtue of the default POS
		-- unless we override it, which we do when is_lemma.
		table.insert(data.categories, "Latin comparative " .. pos)
	end
	table.insert(infl_classes, "[[Appendix:Latin third declension|third declension]]")

	local n = {label = "neuter"}
	for _, head in ipairs(args.head) do
		local neuter = mw.ustring.gsub(head, "or$", "us")
		table.insert(n, neuter)
	end

	table.insert(data.inflections, n)

	if #args.pos > 0 then
		args.pos.label = "positive"
		table.insert(data.inflections, args.pos)
	end
	if args.is_lemma then
		-- If is_lemma, we're a comparative adjective without positive form,
		-- so we're treated as a lemma. In that case, we return "adjectives" as
		-- the part of speech, which will automatically categorize into
		-- "Latin adjectives" and "Latin lemmas", otherwise we don't return
		-- anything, which defaults to the passed-in POS (usually
		-- "comparative adjectives"), which will automatically categorize into
		-- that POS (e.g. "Latin comparative adjectives") and into
		-- "Latin non-lemma forms".
		return pos
	end
end

local function adjectives_sup(pos, def, args, data, infl_classes, appendix)
	local params = {
		[1] = {alias_of = 'head'},
		[2] = {alias_of = 'pos'},
		["head"] = {list = true},
		["pos"] = {list = true},
		["is_lemma"] = {type = "boolean"},
		["id"] = {},
	}
	local args = require("Module:parameters").process(args, params)
	data.no_redundant_head_cat = #args.head == 0
	-- Set default manually so we can tell whether the user specified head=.
	if #args.head == 0 then
		args.head = {mw.title.getCurrentTitle().text}
	end
	data.heads = args.head
	data.id = args.id

	if args.is_lemma then
		-- See below. This happens automatically by virtue of the default POS
		-- unless we overrride it, which we do when is_lemma.
		table.insert(data.categories, "Latin superlative " .. pos)
	end
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

	if #args.pos > 0 then
		args.pos.label = "positive"
		table.insert(data.inflections, args.pos)
	end
	if args.is_lemma then
		-- If is_lemma, we're a superlative adjective without positive form,
		-- so we're treated as a lemma. In that case, we return "adjectives" as
		-- the part of speech, which will automatically categorize into
		-- "Latin adjectives" and "Latin lemmas", otherwise we don't return
		-- anything, which defaults to the passed-in POS (usually
		-- "superlative adjectives"), which will automatically categorize into
		-- that POS (e.g. "Latin superlative adjectives") and into
		-- "Latin non-lemma forms".
		return pos
	end
end

pos_functions["adjectives"] = function(def, args, data, infl_classes, appendix)
	return adjectives("adjectives", def, args, data, infl_classes, appendix)
end

pos_functions["comparative adjectives"] = function(def, args, data, infl_classes, appendix)
	return adjectives_comp("adjectives", def, args, data, infl_classes, appendix)
end

pos_functions["superlative adjectives"] = function(def, args, data, infl_classes, appendix)
	return adjectives_sup("adjectives", def, args, data, infl_classes, appendix)
end

pos_functions["participles"] = function(def, args, data, infl_classes, appendix)
	return adjectives("participles", def, args, data, infl_classes, appendix)
end

pos_functions["determiners"] = function(def, args, data, infl_classes, appendix)
	return adjectives("determiners", def, args, data, infl_classes, appendix)
end

pos_functions["pronouns"] = function(def, args, data, infl_classes, appendix)
	return adjectives("pronouns", def, args, data, infl_classes, appendix)
end

pos_functions["suffixes-adjective"] = function(def, args, data, infl_classes, appendix)
	return adjectives("suffixes", def, args, data, infl_classes, appendix)
end

pos_functions["numerals-adjective"] = function(def, args, data, infl_classes, appendix)
	return adjectives("numerals", def, args, data, infl_classes, appendix)
end

pos_functions["adverbs"] = function(def, args, data, infl_classes, appendix)
	local params = {
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
	data.no_redundant_head_cat = true -- since head= is required.
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

pos_functions["prepositions"] = function(def, args, data, infl_classes, appendix, postscript)
	local params = {
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
	data.no_redundant_head_cat = true -- since 1= is required and goes into data.heads
	data.id = args.id
end

pos_functions["gerunds"] = function(def, args, data, infl_classes, appendix, postscript)
	local params = {
		[1] = {required = true, default = "labōrandum"}, -- headword
		[2] = {}, -- gerundive
	}

	local args = require("Module:parameters").process(args, params)

	data.heads = {args[1]}
	data.no_redundant_head_cat = true -- since 1= is required and goes into data.heads
	table.insert(data.inflections, {label = "[[Appendix:Glossary#accusative|accusative]]"})
	local stem = rmatch(args[1], "^(.*)um$")
	if not stem then
		error("Unrecognized gerund ending: " .. stem)
	end
	if args[2] == "-" then
		table.insert(data.inflections, {label = "no [[Appendix:Glossary#gerundive|gerundive]]"})
	else
		table.insert(data.inflections, {[1] = args[2] or stem .. "us", label = "[[Appendix:Glossary#gerundive|gerundive]]"})
	end
end

local function non_lemma_forms(def, args, data, infl_classes, appendix, postscript)
	local params = {
		[1] = {required = true, default = def}, -- headword or cases
		["head"] = {list = true, require_index = true},
		["g"] = {list = true},
		["id"] = {},
	}

	local args = require("Module:parameters").process(args, params)

	local heads = {args[1]}
	for _, head in ipairs(args.head) do
		table.insert(heads, head)
	end
	data.heads = heads
	data.no_redundant_head_cat = true -- since 1= is required and goes into data.heads
	data.genders = args.g
	data.id = args.id
end

pos_functions["noun forms"] = non_lemma_forms
pos_functions["proper noun forms"] = non_lemma_forms
pos_functions["pronoun forms"] = non_lemma_forms
pos_functions["verb forms"] = non_lemma_forms
pos_functions["gerund forms"] = non_lemma_forms
pos_functions["adjective forms"] = non_lemma_forms
pos_functions["participle forms"] = non_lemma_forms
pos_functions["determiner forms"] = non_lemma_forms
pos_functions["numeral forms"] = non_lemma_forms
pos_functions["suffix forms"] = non_lemma_forms

return export
