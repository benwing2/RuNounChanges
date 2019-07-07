local export = {}

local lang = require("Module:languages").getByCode("la")
local m_links = require("Module:links")
local m_utilities = require("Module:utilities")
local m_para = require("Module:parameters")

local current_title = mw.title.getCurrentTitle()
local NAMESPACE = current_title.nsText
local PAGENAME = current_title.text

local decl = require("Module:la-noun/data")
local m_table = require("Module:la-noun/table")
local m_la_utilities = require("Module:la-utilities")

local rsplit = mw.text.split
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsubn = mw.ustring.gsub

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
    local retval = rsubn(term, foo, bar)
    return retval
end

-- Canonical order of cases
local case_order = {
	"nom_sg",
	"gen_sg",
	"dat_sg",
	"acc_sg",
	"abl_sg",
	"voc_sg",
	"loc_sg",
	"nom_pl",
	"gen_pl",
	"dat_pl",
	"acc_pl",
	"abl_pl",
	"voc_pl",
	"loc_pl"
}

local ligatures = {
	['Ae'] = 'Æ',
	['ae'] = 'æ',
	['Oe'] = 'Œ',
	['oe'] = 'œ',
}

local function process_forms_and_overrides(data, args)
	local redlink = false
	if data.num == "pl" and NAMESPACE == '' then
		table.insert(data.categories, "Latin pluralia tantum")
	elseif data.num == "sg" and NAMESPACE == '' then
		table.insert(data.categories, "Latin singularia tantum")
	end

	local accel_lemma
	if data.num and data.num ~= "" then
		accel_lemma = data.forms["nom_" .. data.num]
	else
		accel_lemma = data.forms["nom_sg"]
	end

	for _, key in ipairs(case_order) do
		if args[key] or data.forms[key] then
			local val
			if args[key] then
				val = args[key]
				data.user_specified[key] = true
			else
				val = data.forms[key]
			end
			if type(val) == "string" then
				val = rsplit(val, "/")
			end
			if (data.num == "pl" and key:find("sg")) or (data.num == "sg" and key:find("pl")) then
				data.forms[key] = ""
			elseif val[1] == "" or val[1] == "-" or val[1] == "—" then
				data.forms[key] = "—"
			else
				for i, form in ipairs(val) do
					local word = data.prefix .. (data.n and mw.ustring.gsub(form,"m$","n") or form) .. data.suffix
					if data.lig then
						word = word:gsub("[AaOo]e", ligatures)
					end
					
					local accel_form = key
					accel_form = accel_form:gsub("_([sp])[gl]$", "|%1")

					data.accel[key .. i] = {form = accel_form, lemma = accel_lemma}
					val[i] = word
					if not redlink and NAMESPACE == '' then
						local title = lang:makeEntryName(word)
						local t = mw.title.new(title)
						if t and not t.exists then
							table.insert(data.categories, 'Latin nouns with red links in their declension tables')
							redlink = true
						end
					end
				end
				data.forms[key] = val
			end
		end
	end
end

local function show_forms(data)
	local noteindex = 1
	local notes = {}
	for _, key in ipairs(case_order) do
		local val = data.forms[key]
		if val and val ~= "" and val ~= "—" then
			for i, form in ipairs(val) do
				local link = m_links.full_link({lang = lang, term = form, accel = data.accel[key .. i]})
				if (data.notes[key .. i] or data.noteindex[key .. i]) and not data.user_specified[key] then
					-- If the decl entry hasn't specified a footnote index, generate one.
					local this_noteindex = data.noteindex[key .. i]
					if not this_noteindex then
						this_noteindex = noteindex
						noteindex = noteindex + 1
						table.insert(notes, '<sup style="color: red">' .. this_noteindex .. '</sup>' .. data.notes[key .. i])
					end
					val[i] = link .. '<sup style="color: red">' .. this_noteindex .. '</sup>'
				else
					val[i] = link
				end
			end
			data.forms[key] = table.concat(val, "<br />")
		end
	end
	data.footnote = table.concat(notes, "<br />") .. data.footnote
end

local function make_table(data)
	if data.num == "sg" then
		return m_table.make_table_sg(data)
	elseif data.num == "pl" then
		return m_table.make_table_pl(data)
	else
		return m_table.make_table(data)
	end
end

local function generate_forms(frame)
	local data = {
		title = "",
		footnote = "",
		num = "",
		loc = false,
		um = false,
		forms = {},
		types = {},
		categories = {},
		notes = {},
		noteindex = {},
		user_specified = {},
		accel = {},
	}
	
	local iparams = {
		[1] = {},
		decl_type = {},
		num = {},
	}
	
	local iargs = m_para.process(frame.args, iparams)

	local parent_args = frame:getParent().args
	
	local decl_type = iargs.decl_type or parent_args.decl_type
	
	if decl_type and decl_type ~= "" then 
		for name, val in ipairs(rsplit(decl_type, "-")) do
			data.types[val] = true
		end
	end
	
	local params = {
		[1] = {required = true},
		decl = {},
		decl_type = {},
		noun = {},
		num = {},
		loc = {type = "boolean"},
		um = {type = "boolean"},
		genplum = {type = "boolean"},
		n = {type = "boolean"},
		lig = {type = "boolean"},
		prefix = {},
		suffix = {},
		footnote = {},
	}
	for _, case in ipairs(case_order) do
		params[case] = {}
	end
	
	local decl_arg = iargs[1] or parent_args.decl
	
	if (decl_arg == "2" and data.types.er) or decl_arg == "3" then
		params[2] = {}
	end
	
	local args = m_para.process(parent_args, params)
	
	data.num = iargs.num or args.num or ""
	data.loc = args.loc
	data.lig = args.lig
	data.um = args.um or args.genplum
	data.prefix = args.prefix or ""
	data.suffix = args.suffix or ""
	data.footnote = args.footnote or ""
	data.n = args.n and (data.suffix ~= "") -- Must have a suffix and n specified
	
	decl[decl_arg](data, args)
	
	process_forms_and_overrides(data, args)
	
	if data.prefix .. data.suffix ~= "" then
		table.insert(data.categories, "Kenny's testing category 6")
	end

	return data
end

function export.show(frame)
	local data = generate_forms(frame)

	show_forms(data)
	
	return make_table(data) .. m_utilities.format_categories(data.categories, lang)
end

local function concat_forms(data)
	local ins_text = {}
	for _, key in ipairs(case_order) do
		local val = data.forms[key]
		if val and val ~= "" and val ~= "—" and #val > 0 then
			local new_vals = {}
			for _, v in ipairs(val) do
				table.insert(new_vals, rsub(v, "|", "<!>"))
			end
			table.insert(ins_text, key .. "=" .. table.concat(new_vals, ","))
		end
	end
	return table.concat(ins_text, "|")
end

function export.generate_forms(frame)
	local data = generate_forms(frame)

	return concat_forms(data)
end

-- Given an ending (or possibly a full regex matching the entire lemma, if
-- a regex group is present), return the base minus the ending, or nil if
-- the ending doesn't match.
local function extract_base(lemma, ending)
	if ending:find("%(") then
		return rmatch(lemma, ending)
	else
		return rmatch(lemma, "^(.*)" .. ending .. "$")
	end
end
	
-- Given ENDINGS_AND_SUBTYPES (a list of pairs of endings with associated subtypes,
-- where each ending (a string) is associated with a list of subtypes), check each
-- ending in turn against LEMMA. If it matches, return the pair BASE, SUBTYPES
-- where BASE is the remainder of LEMMA minus the ending, and SUBTYPES is the
-- subtypes associated with the ending. But don't return SUBTYPES if any of the
-- subtypes in the list is specifically canceled in SPECIFIED_SUBTYPES (a set,
-- i.e. a table where the keys are strings and the value is always true);
-- instead, consider the next ending in turn. If no endings match, throw an error
-- if DECLTYPE is non-nil, mentioning the DECLTYPE (the user-specified declension);
-- but if DECLTYPE is nil, just return the pair nil, nil.
local function get_subtype_by_ending(lemma, decltype, specified_subtypes, stem2,
		endings_and_subtypes)
	for _, ending_and_subtypes in ipairs(endings_and_subtypes) do
		local ending = ending_and_subtypes[1]
		local subtypes = ending_and_subtypes[2]
		not_this_subtype = false
		for _, subtype in ipairs(subtypes) do
			-- A subtype is directly canceled by specifying -SUBTYPE.
			-- In addition, M or F as a subtype is canceled by N, and vice-versa,
			-- but M doesn't cancel F or vice-versa; instead, we simply ignore
			-- the conflicting gender specification when constructing the
			-- combination of specified and inferred subtypes. The reason for this
			-- is that neuters have distinct declensions from masculines and feminines,
			-- but masculines and feminines have the same declension, and various
			-- nouns in Latin that are normally masculine are exceptionally feminine
			-- and vice-versa (nauta, agricola, fraxinus, malus "apple tree",
			-- manus, rēs, etc.).
			if specified_subtypes["-" .. subtype] or
				subtype == "N" and (specified_subtypes.M or specified_subtypes.F) or
				(subtype == "M" or subtype == "F") and specified_subtypes.N then
				not_this_subtype = true
				break
			end
		end
		if not not_this_subtype then
			if type(ending) == "table" then
				local lemma_ending = ending[1]
				local stem2_ending = ending[2]
				local base = extract_base(lemma, lemma_ending)
				if base and base .. stem2_ending == stem2 then
					return base, subtypes
				end
			else
				local base = extract_base(lemma, ending)
				if base then
					return base, subtypes
				end
			end
		end
	end
	if decltype then
		error("Unrecognized ending for declension-" .. decltype .. " noun: " .. lemma)
	end
	return nil, nil
end

local function check_ending(word, ending)
	if not rfind(word, ending .. "$") then
		error("Expected " .. word .. " to end in -" .. ending)
	end
end

local function detect_subtype(lemma, typ, subtypes, stem2)
	local base, ending
	local detected = {}

	if typ == "1" then
		return get_subtype_by_ending(lemma, typ, subtypes, stem2, {
			{"ām", {"F", "am"}},
			{"ās", {"M", "Greek", "Ma"}},
			{"ēs", {"M", "Greek", "Me"}},
			{"ē", {"F", "Greek"}},
			{"ae", {"F", "pl"}},
			{"a", {"F"}},
		})
	elseif typ == "2" then
		if rmatch(lemma, "r$") then
			return lemma, {"er"}
		end
		return get_subtype_by_ending(lemma, typ, subtypes, stem2, {
			{"os", {"M", "Greek"}},
			{"on", {"N", "Greek"}},
			{"ius", {"M", "ius"}},
			{"ium", {"N", "ium"}},
			-- If the lemma ends in -us and the user said N or -M, then the
			-- following won't apply, and the second (neuter) -us will applly.
			{"us", {"M"}},
			{"us", {"N", "us"}},
			{"um", {"N"}},
			{"iī", {"M", "ius", "pl"}},
			{"ia", {"N", "ium", "pl"}},
			-- If the lemma ends in -ī and the user said N or -M, then the
			-- following won't apply, and the second (neuter) -ī will applly.
			{"ī", {"M", "pl"}},
			{"ī", {"N", "us", "pl"}},
			{"a", {"N", "pl"}},
		})
	elseif typ == "3" then
		stem2 = stem2 or m_la_utilities.make_stem2(lemma)
		local detected_subtypes
		if subtypes.Greek then
			base, detected_subtypes = get_subtype_by_ending(lemma, nil, subtypes, stem2, {
				{"ēr", {"er"}},
				{"ōn", {"on"}},
				{"s", {"s"}},
			})
			if base then
				return base, detected_subtypes
			end
			return lemma, {}
		end

		if subtypes.navis or subtypes.ignis then
			return lemma, {}
		end

		if not subtypes.N then
			base, detected_subtypes = get_subtype_by_ending(lemma, nil, subtypes, stem2, {
				{"^([A-ZĀĒĪŌŪȲĂĔĬŎŬ].*)polis$", {"polis", "sg"}},
			})
			if base then
				return base, detected_subtypes
			end
			base, detected_subtypes = get_subtype_by_ending(lemma, nil, subtypes, stem2, {
				{{"tūdō", "tūdin"}, {"F"}},
				{{"tās", "tāt"}, {"F"}},
				{{"tūs", "tūt"}, {"F"}},
				{{"tiō", "tiōn"}, {"F"}},
				{{"siō", "siōn"}, {"F"}},
				{{"xiō", "xiōn"}, {"F"}},
				{{"or", "ōr"}, {"M"}},
				{{"trīx", "trīc"}, {"F"}},
				{{"trix", "trīc"}, {"F"}},
				{{"is", ""}, {"I"}},
				{{"^([a-zāēīōūȳăĕĭŏŭ].*)ēs$", ""}, {"I"}},
			})
			if base then
				return lemma, detected_subtypes
			end
		end

		base, detected_subtypes = get_subtype_by_ending(lemma, nil, subtypes, stem2, {
			{{"us", "or"}, {"N"}},
			{{"us", "er"}, {"N"}},
			{{"ma", "mat"}, {"N"}},
			{{"men", "min"}, {"N"}},
			{{"e", ""}, {"N", "I", "pure"}},
			{{"al", "āl"}, {"N", "I", "pure"}},
			{{"ar", "ār"}, {"N", "I", "pure"}},
		})
		if base then
			return lemma, detected_subtypes
		end
		return lemma, {}
	elseif typ == "4" then
		if subtypes.echo or subtypes.argo then
			base = rmatch(lemma, "^(.*)ō$")
			if not base then
				error("Declension-4 noun of subtype /echo or /argo should end in -ō: " .. lemma)
			end
			return base, {}
		end
		return get_subtype_by_ending(lemma, typ, subtypes, stem2, {
			{"us", {"M"}},
			{"ū", {"N"}},
			{"ūs", {"M", "pl"}},
			{"ua", {"N", "pl"}},
		})
	elseif typ == "5" then
		return get_subtype_by_ending(lemma, typ, subtypes, stem2, {
			{"iēs", {"F", "i"}},
			{"ēs", {"F"}},
		})
	else
		return lemma, {}
	end
end

local function new_generate_forms(frame)
	local data = {
		title = "",
		footnote = "",
		num = "",
		loc = false,
		um = false,
		forms = {},
		types = {},
		categories = {},
		notes = {},
		noteindex = {},
		user_specified = {},
		accel = {},
	}
	
	local params = {
		[1] = {required = true, list = true, default = "1"},
		prefix = {},
		suffix = {},
		footnote = {},
	}
	for _, case in ipairs(case_order) do
		params[case] = {}
	end

	local parent_args = frame:getParent().args

	local args = m_para.process(parent_args, params)

	local specs = rsplit(args[1][1], "/")
	local decl_arg
	for i, spec in ipairs(specs) do
		if i == 1 then
			decl_arg = spec
		else
			data.types[spec] = true
		end
	end

	local lemma = args[1][2]
	if not lemma or lemma == "" then
		if NAMESPACE == "Template" then
			lemma = "aqua"
		else
			lemma = current_title.subpageText
		end
	end
	local stem2 = args[1][3]
	if stem2 == "" then
		stem2 = nil
	end
	if #args[1] > 3 then
		error("Too many unnamed parameters, at most 3 should be given")
	end
	
	local base, detected_subtypes = detect_subtype(lemma, decl_arg, data.types, stem2)

	for _, subtype in ipairs(detected_subtypes) do
		if data.types["-" .. subtype] then
			-- if a "cancel subtype" spec is given, remove the cancel spec
			-- and don't apply the subtype
			data.types["-" .. subtype] = nil
		elseif (subtype == "M" or subtype == "F" or subtype == "N") and
				(data.types.M or data.types.F or data.types.N) then
			-- if gender already specified, don't create conflicting gender spec
		else
			data.types[subtype] = true
		end
	end

	args[1] = base
	args[2] = stem2

	if data.types.pl then
		data.num = "pl"
		data.types.pl = nil
	elseif data.types.sg then
		data.num = "sg"
		data.types.sg = nil
	end
	if data.types.loc then
		data.loc = true
		data.types.loc = nil
	end
	if data.types.lig then
		data.lig = true
		data.types.lig = nil
	end
	if data.types.genplum then
		data.um = true
		data.types.genplum = nil
	end
	data.prefix = args.prefix or ""
	data.suffix = args.suffix or ""
	data.footnote = args.footnote or ""
	if data.types.sufn then
		data.n = (data.suffix ~= "") and true -- Must have a suffix and n specified
		data.types.sufn = nil
	end

	if not decl[decl_arg] then
		error("Unrecognized declension '" .. decl_arg .. "'")
	end
	decl[decl_arg](data, args)
	
	process_forms_and_overrides(data, args)
	
	if data.prefix .. data.suffix ~= "" then
		table.insert(data.categories, "Kenny's testing category 6")
	end

	return data
end

function export.new_show(frame)
	local data = new_generate_forms(frame)

	show_forms(data)
	
	return make_table(data) .. m_utilities.format_categories(data.categories, lang)
end

function export.new_generate_forms(frame)
	local data = new_generate_forms(frame)

	return concat_forms(data)
end

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
