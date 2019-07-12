local export = {}

local lang = require("Module:languages").getByCode("la")
local m_links = require("Module:links")
local m_utilities = require("Module:utilities")
local ut = require("Module:utils")
local m_string_utilities = require("Module:string utilities")
local m_para = require("Module:parameters")

local current_title = mw.title.getCurrentTitle()
local NAMESPACE = current_title.nsText
local PAGENAME = current_title.text

local m_noun_decl = require("Module:la-noun/data")
local m_table = require("Module:la-noun/table")
local m_adj_decl = require("Module:la-adj/data")
local m_la_utilities = require("Module:la-utilities")

local rsplit = mw.text.split
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rgmatch = mw.ustring.gmatch
local rsubn = mw.ustring.gsub
local ulen = mw.ustring.len
local uupper = mw.ustring.upper

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
    local retval = rsubn(term, foo, bar)
    return retval
end

local ligatures = {
	['Ae'] = 'Æ',
	['ae'] = 'æ',
	['Oe'] = 'Œ',
	['oe'] = 'œ',
}

local cases = {
	"nom", "gen", "dat", "acc", "abl", "voc", "loc"
}

local nums = {
	"sg", "pl"
}

-- Canonical order of cases
local case_order = {}

for _, num in ipairs(nums) do
	for _, case in ipairs(cases) do
		table.insert(case_order, case .. "_" .. num)
	end
end

local function itercn()
	local i = 1
	local j = 0
	local function iter()
		j = j + 1
		if j > #nums then
			j = 1
			i = i + 1
			if i > #cases then
				return nil
			end
		end
		return cases[i] .. "_" .. nums[j]
	end
	return iter
end

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
	if type(accel_lemma) == "table" then
		accel_lemma = accel_lemma[1]
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
					local word = data.prefix .. (data.n and rsub(form,"m$","n") or form) .. data.suffix
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
	local seen_notes = {}
	for _, key in ipairs(case_order) do
		local val = data.forms[key]
		if val and val ~= "" and val ~= "—" then
			for i, form in ipairs(val) do
				local link = m_links.full_link({lang = lang, term = form, accel = data.accel[key .. i]})
				local this_notes = data.notes[key .. i]
				if this_notes and not data.user_specified[key] then
					if type(this_notes) == "string" then
						this_notes = {this_notes}
					end
					local link_indices = {}
					for _, this_note in ipairs(this_notes) do
						local this_noteindex = seen_notes[this_note]
						if not this_noteindex then
							-- Generate a footnote index.
							this_noteindex = noteindex
							noteindex = noteindex + 1
							table.insert(notes, '<sup style="color: red">' .. this_noteindex .. '</sup>' .. this_note)
							seen_notes[this_note] = this_noteindex
						end
						ut.insert_if_not(link_indices, this_noteindex)
					end
					val[i] = link .. '<sup style="color: red">' .. table.concat(link_indices, ",") .. '</sup>'
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

	local decl = iargs[1] or parent_args.decl

	if (decl == "2" and data.types.er) or decl == "3" then
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

	m_noun_decl[decl](data, args)

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

-- Given ENDINGS_AND_SUBTYPES (a list of pairs of endings with associated
-- subtypes, where each pair consists of a single ending spec and a list of
-- subtypes), check each ending in turn against LEMMA. If it matches, return
-- the pair BASE, SUBTYPES where BASE is the remainder of LEMMA minus the
-- ending, and SUBTYPES is the subtypes associated with the ending. But don't
-- return SUBTYPES if any of the subtypes in the list is specifically canceled
-- in SPECIFIED_SUBTYPES (a set, i.e. a table where the keys are strings and
-- the value is always true); instead, consider the next ending in turn. If no
-- endings match, throw an error if DECLTYPE is non-nil, mentioning the
-- DECLTYPE (the user-specified declension); but if DECLTYPE is nil, just
-- return the pair nil, nil.
--
-- The ending spec in ENDINGS_AND_SUBTYPES is one of the following:
--
-- 1. A simple string, e.g. "tūdō", specifying an ending.
-- 2. A regex that should match the entire lemma (it should be anchored at
--    the beginning with ^ and at the end with $), and contains a single
--    capturing group to match the base.
-- 3. A pair {SIMPLE_STRING_OR_REGEX, STEM2_ENDING} where
--    SIMPLE_STRING_OR_REGEX is one of the previous two possibilities and
--    STEM2_ENDING is a string specifying the corresponding ending that must
--    be present in STEM2. If this form is used, the combination of
--    base + STEM2_ENDING must exactly match STEM2 in order for this entry
--    to be considered a match. An example is {"is", ""}, which will match
--    lemma == "follis", stem2 == "foll", but not lemma == "lapis",
--    stem2 == "lapid".
local function get_subtype_by_ending(lemma, stem2, decltype, specified_subtypes,
		endings_and_subtypes)
	for _, ending_and_subtypes in ipairs(endings_and_subtypes) do
		local ending = ending_and_subtypes[1]
		local subtypes = ending_and_subtypes[2]
		not_this_subtype = false
		for _, subtype in ipairs(subtypes) do
			-- A subtype is directly canceled by specifying -SUBTYPE.
			-- In addition, M or F as a subtype is canceled by N, and
			-- vice-versa, but M doesn't cancel F or vice-versa; instead,
			-- we simply ignore the conflicting gender specification when
			-- constructing the combination of specified and inferred subtypes.
			-- The reason for this is that neuters have distinct declensions
			-- from masculines and feminines, but masculines and feminines have
			-- the same declension, and various nouns in Latin that are
			-- normally masculine are exceptionally feminine and vice-versa
			-- (nauta, agricola, fraxinus, malus "apple tree", manus, rēs,
			-- etc.).
			--
			-- In addition, sg as a subtype is canceled by pl and vice-versa.
			-- It's also possible to specify both, which will override sg but
			-- not cancel it (in the sense that it won't prevent the relevant
			-- rule from matching). For example, there's a rule specifying that
			-- lemmas beginning with a capital letter and ending in -ius take
			-- the ius.voci.sg subtypes.  Specifying such a lemma with the
			-- subtype both will result in the ius.voci.both subtypes, whereas
			-- specifying such a lemma with the subtype pl will cause this rule
			-- not to match, and it will fall through to a less specific rule
			-- that returns just the ius subtype, which will be combined with
			-- the explicitly specified pl subtype to produce ius.pl.
			if specified_subtypes["-" .. subtype] or
				subtype == "N" and (specified_subtypes.M or specified_subtypes.F) or
				(subtype == "M" or subtype == "F") and specified_subtypes.N or
				subtype == "sg" and specified_subtypes.pl or
				subtype == "pl" and specified_subtypes.sg then
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

-- Autodetect the subtype of a noun given all the information specified by the
-- user: lemma, stem2, declension type and specified subtypes. Two values are
-- returned: the lemma base (i.e. the stem of the lemma, as required by the
-- declension functions) and the autodetected subtypes. Note that this will
-- not detect a given subtype if the explicitly specified subtypes are
-- incompatible (i.e. if -SUBTYPE is specified for any subtype that would be
-- returned; or if M or F is specified when N would be returned, and
-- vice-versa; or if pl is specified when sg would be returned, and vice-versa).
--
-- NOTE: This function has intimate knowledge of the way that the declension
-- functions handle subtypes, particularly for the third declension.
local function detect_subtype(lemma, stem2, typ, subtypes)
	local base, ending

	if typ == "1" then
		return get_subtype_by_ending(lemma, stem2, typ, subtypes, {
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
		return get_subtype_by_ending(lemma, stem2, typ, subtypes, {
			{"os", {"M", "Greek"}},
			{"on", {"N", "Greek"}},
			-- -ius beginning with a capital letter is assumed a proper name,
			-- and takes the voci subtype (vocative in -ī) along with the ius
			-- subtype and sg-only. Other nouns in -ius just take the ius
			-- subtype. Explicitly specify "sg" so that if .pl is given,
			-- this rule won't apply.
			{"^([A-ZĀĒĪŌŪȲĂĔĬŎŬ].*)ius$", {"M", "ius", "voci", "sg"}},
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
			base, detected_subtypes =
				get_subtype_by_ending(lemma, stem2, nil, subtypes, {
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
			base, detected_subtypes = get_subtype_by_ending(lemma, stem2, nil, subtypes, {
				{"^([A-ZĀĒĪŌŪȲĂĔĬŎŬ].*)polis$", {"polis", "sg", "loc"}},
			})
			if base then
				return base, detected_subtypes
			end
			base, detected_subtypes = get_subtype_by_ending(lemma, stem2, nil, subtypes, {
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

		base, detected_subtypes = get_subtype_by_ending(lemma, stem2, nil, subtypes, {
			{{"us", "or"}, {"N"}},
			{{"us", "er"}, {"N"}},
			{{"ma", "mat"}, {"N"}},
			{{"men", "min"}, {"N"}},
			{{"^([A-ZĀĒĪŌŪȲĂĔĬŎŬ].*)e$", ""}, {"N", "sg"}},
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
				error("Declension-4 noun of subtype .echo or .argo should end in -ō: " .. lemma)
			end
			return base, {}
		end
		return get_subtype_by_ending(lemma, stem2, typ, subtypes, {
			{"us", {"M"}},
			{"ū", {"N"}},
			{"ūs", {"M", "pl"}},
			{"ua", {"N", "pl"}},
		})
	elseif typ == "5" then
		return get_subtype_by_ending(lemma, stem2, typ, subtypes, {
			{"iēs", {"F", "i"}},
			{"ēs", {"F"}},
		})
	elseif typ == "irreg" and lemma == "domus" then
		-- [[domus]] auto-sets data.loc = true, but we need to know this
		-- before declining the noun so we can propagate it to other segments.
		return lemma, {"loc"}
	elseif typ == "indecl" or type == "irreg" and (
		lemma == "Deus" or lemma == "Iēsus" or lemma == "venum" or
		lemma == "Callistō" or lemma == "Themistō"
	) then
		-- Indeclinable nouns, and certain irregular nouns, set data.num = "sg",
		-- but we need to know this before declining the noun so we can
		-- propagate it to other segments.
		return lemma, {"sg"}
	else
		return lemma, {}
	end
end

function export.detect_subtype(frame)
	local params = {
		[1] = {required = true},
		[2] = {},
		[3] = {},
		[4] = {},
	}
	local args = m_para.process(frame.args, params)
	local specified_subtypes = {}
	if args[4] then
		for _, subtype in ipairs(rsplit(args[4], ".")) do
			specified_subtypes[subtype] = true
		end
	end
	local base, subtypes = detect_subtype(args[1], args[2], args[3], specified_subtypes)
	return base .. "|" .. table.concat(subtypes, ".")
end

-- Parse a segment (i.e. a string of the form "lūna<1>" or
-- "aegis/aegid<3.Greek>"), consisting of a lemma (or optionally a lemma/stem)
-- and declension+subtypes. The return value is a table, e.g.:
-- {
--   decl = "1",
--   lemma = "lūna",
--   stem2 = nil,
--   data = DATA_TABLE (a table of info extracted from subtypes),
--   args = {"aqua"}
-- }
--
-- or
--
-- {
--   decl = "3",
--   lemma = "aequor",
--   stem2 = "aequor",
--   data = DATA_TABLE (a table of info extracted from subtypes),
--   args = {"aequor", "aequor"}
-- }
local function parse_segment(segment)
	local stem_part, spec_part = rmatch(segment, "^(.*)<(.-)>$")
	local stems = rsplit(stem_part, "/", true)
	local specs = rsplit(spec_part, ".", true)

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
		user_specified = {},
		accel = {},
	}
	local args = {}

	local decl
	for j, spec in ipairs(specs) do
		if j == 1 then
			decl = spec
		else
			data.types[spec] = true
		end
	end

	local lemma = stems[1]
	if not lemma or lemma == "" then
		lemma = current_title.subpageText
	end
	local stem2 = stems[2]
	if stem2 == "" then
		stem2 = nil
	end
	if #stems > 2 then
		error("Too many stems, at most 2 should be given: " .. stem_part)
	end

	local base, detected_subtypes = detect_subtype(lemma, stem2, decl, data.types)

	for _, subtype in ipairs(detected_subtypes) do
		if data.types["-" .. subtype] then
			-- if a "cancel subtype" spec is given, remove the cancel spec
			-- and don't apply the subtype
			data.types["-" .. subtype] = nil
		elseif (subtype == "M" or subtype == "F" or subtype == "N") and
				(data.types.M or data.types.F or data.types.N) then
			-- if gender already specified, don't create conflicting gender spec
		elseif (subtype == "sg" or subtype == "pl" or subtype == "both") and
				(data.types.sg or data.types.pl or data.types.both) then
			-- if number restriction already specified, don't create conflicting
			-- number restriction spec
		else
			data.types[subtype] = true
		end
	end

	if not data.types.pl and not data.types.both and rfind(lemma, "^[A-ZĀĒĪŌŪȲĂĔĬŎŬ]") then
		data.types.sg = true
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
	if data.types.sufn then
		data.n = true
		data.types.sufn = nil
	end

	return {
		decl = decl,
		lemma = lemma,
		stem2 = stem2,
		data = data,
		args = args,
	}
end

-- Parse a segment run (i.e. a string with zero or more segments [see
-- parse_segment] and optional surrounding text, e.g. "foenum<2>-graecum<2>"
-- or "pars/part<3.navis> ōrātiōnis"). The segment run currently cannot contain
-- any alternants (e.g. "((epulum<2.sg>,epulae<1>))"). The return value is a
-- table of the following form:
-- {
--   segments = PARSED_SEGMENTS (a list of parsed segments),
--   loc = LOC (a boolean indicating whether any of the individual segments
--     has a locative),
--   num = NUM (the first specified value for a number restriction, or "" if no
--     number restrictions),
-- }
-- Each element in PARSED_SEGMENTS is as returned by parse_segment() but will
-- have an additional .prefix field indicating the text before the segment. If
-- there is trailing text, the last element will have only a .prefix field
-- containing that trailing text.
local function parse_segment_run(segment_run)
	local loc = nil
	local num = ""
	local segments = m_string_utilities.capturing_split(segment_run, "([^<> ,%-]+<.->)")
	local parsed_segments = {}
	for i = 2, (#segments - 1), 2 do
		local parsed_segment = parse_segment(segments[i])
		-- Overall locative is true if any segments call for locative.
		loc = loc or parsed_segment.data.loc
		-- The first specified value for num is used becomes the overall value.
		if num == "" then
			num = parsed_segment.data.num
		end
		parsed_segment.prefix = segments[i - 1]
		table.insert(parsed_segments, parsed_segment)
	end
	if segments[#segments] ~= "" then
		table.insert(parsed_segments, {prefix = segments[#segments]})
	end
	return {
		segments = parsed_segments,
		loc = loc,
		num = num,
	}
end

-- Parse an alternant, e.g. "((epulum<2.sg>,epulae<1>))",
-- "((Serapis<3.sg>,Serapis/Serapid<3.sg>))" or
-- "((rēs<5>pūblica<1>,rēspūblica<1>))". The return value is a table of the form
-- {
--   alternants = PARSED_ALTERNANTS (a list of segment runs, each of which is a
--     list of parsed segments as returned by parse_segment_run()),
--   loc = LOC (a boolean indicating whether any of the individual segment runs
--     has a locative),
--   num = NUM (the overall number restriction, one of "sg", "pl" or "both"),
-- }
local function parse_alternant(alternant)
	local parsed_alternants = {}
	local alternant_spec = rmatch(alternant, "^%(%((.*)%)%)$")
	local alternants = rsplit(alternant_spec, ",")
	local loc = false
	local num = nil
	for _, alternant in ipairs(alternants) do
		local parsed_run = parse_segment_run(alternant)
		table.insert(parsed_alternants, parsed_run)
		loc = loc or parsed_run.loc
		if not num then
			num = parsed_run.num
		elseif num ~= parsed_run.num then
			-- FIXME, this needs to be rethought to allow for
			-- adjective alternants.
			num = "both"
		end
	end
	return {
		alternants = parsed_alternants,
		loc = loc,
		num = num,
	}
end

-- Parse a segment run (see parse_segment_run()). Unlike for
-- parse_segment_run(), this can contain alternants such as
-- "((epulum<2.sg>,epulae<1>))" or "((Serapis<3.sg>,Serapis/Serapid<3.sg>))"
-- embedded in it to indicate words composed of multiple declensions.
-- The return value is a table of the following form:
-- {
--   segments = PARSED_SEGMENTS (a list of parsed segments),
--   loc = LOC (a boolean indicating whether any of the individual segments has
--     a locative),
--   num = NUM (the first specified value for a number restriction, or "" if no
--     number restrictions),
-- }.
-- Each element in PARSED_SEGMENTS is one of three types:
--
-- 1. A regular segment, as returned by parse_segment() but with an additional
--    .prefix field indicating the text before the segment, as per the
--    return value of parse_segment_run().
-- 2. A raw-text segment, i.e. a table with only a .prefix field containing
--    the raw text.
-- 3. An alternating segment, i.e. a table of the following form:
-- {
--   alternants = PARSED_SEGMENT_RUNS (a list of parsed segment runs),
--   loc = LOC (a boolean indicating whether the segment as a whole has a
--     locative),
--   num = NUM (the number restriction of the segment as a whole),
-- }
-- Note that each alternant is a segment run rather than a single parsed
-- segment to allow for alternants like "((rēs<5>pūblica<1>,rēspūblica<1>))".
-- The parsed segment runs in PARSED_SEGMENT_RUNS are tables as returned by
-- parse_segment_run() (of the same form as the overall return value of
-- parse_segment_run_allowing_alternants()).
local function parse_segment_run_allowing_alternants(segment_run)
	local alternating_segments = m_string_utilities.capturing_split(segment_run, "(%(%(.-%)%))")
	local parsed_segments = {} 
	local loc = false
	local num = ""
	for i = 1, #alternating_segments do
		local alternating_segment = alternating_segments[i]
		if alternating_segment ~= "" then
			if i % 2 == 1 then
				local parsed_run = parse_segment_run(alternating_segment)
				for _, parsed_segment in ipairs(parsed_run.segments) do
					table.insert(parsed_segments, parsed_segment)
				end
				loc = loc or parsed_run.loc
				if num == "" then
					num = parsed_run.num
				end
			else
				local parsed_alternating_segment = parse_alternant(alternating_segment)
				loc = loc or parsed_alternating_segment.loc
				if num == "" then
					num = parsed_alternating_segment.num
				end
				table.insert(parsed_segments, parsed_alternating_segment)
			end
		end
	end

	return {
		segments = parsed_segments,
		loc = loc,
		num = num,
	}
end

-- Combine each form in FORMS (a list of forms associated with a case/number
-- combination) with each form in NEW_FORMS (either a single string for a
-- single form, or a list of forms) by concatenating
-- EXISTING_FORM .. PREFIX .. NEW_FORM. Also combine NOTES (a table specifying
-- the footnotes associated with each existing form, i.e. a map from form
-- indices to lists of footnotes) with NEW_NOTES (new footnotes associated with
-- the new forms, in the same format as NOTES). Return a pair
-- NEW_FORMS, NEW_NOTES where either or both of FORMS and NOTES (but not the
-- sublists in NOTES) may be destructively modified to generate the return
-- values.
local function append_form(forms, notes, new_forms, new_notes, prefix)
	new_forms = new_forms or ""
	notes = notes or {}
	new_notes = new_notes or {}
	prefix = prefix or ""
	if type(new_forms) == "table" and #new_forms == 1 then
		new_forms = new_forms[1]
	end
	if type(new_forms) == "string" then
		-- If there's only one new form, destructively modify the existing
		-- forms and notes for this new form and its footnotes.
		for i = 1, #forms do
			forms[i] = forms[i] .. prefix .. new_forms
			if new_notes[1] then
				if not notes[i] then
					notes[i] = new_notes[1]
				else
					local combined_notes = ut.clone(notes[i])
					for _, note in ipairs(new_notes[1]) do
						table.insert(combined_notes, note)
					end
					notes[i] = combined_notes
				end
			end
		end
		return forms, notes
	else
		-- If there are multiple new forms, we need to loop over all
		-- combinations of new and old forms. In that case, use new tables
		-- for the combined forms and notes.
		local ret_forms = {}
		local ret_notes = {}
		for i=1, #forms do
			for j=1, #new_forms do
				table.insert(ret_forms, forms[i] .. prefix .. new_forms[j])
				if new_notes[j] then
					if not notes[i] then
						-- We are constructing a linearized matrix of size
						-- NI x NJ where J is in the inner loop. If I and J
						-- are zero-based, the linear index of (I, J) is
						-- I * NJ + J. However, we are one-based, so the
						-- same formula won't work. Instead, we effectively
						-- need to convert to zero-based indices, compute
						-- the zero-based linear index, and then convert it
						-- back to a one-based index, i.e.
						--
						-- (I - 1) * NJ + (J - 1) + 1
						--
						-- i.e. (I - 1) * NJ + J.
						ret_notes[(i - 1) * #new_forms + j] = new_notes[j]
					else
						local combined_notes = ut.clone(notes[i])
						for _, note in ipairs(new_notes[j]) do
							table.insert(combined_notes, note)
						end
						ret_notes[(i - 1) * #new_forms + j] = combined_notes
					end
				end
			end
		end
		return ret_forms, ret_notes
	end
end

-- Destructively modify any forms in FORMS (a map from a case/number combination
-- to a form or a list of forms) by converting sequences of ae, oe, Ae or Oe
-- to the appropriate ligatures.
local function apply_ligatures(forms)
	for name in itercn() do
		if type(forms[name]) == "string" then
			forms[name] = forms[name]:gsub("[AaOo]e", ligatures)
		elseif type(forms[name]) == "table" then
			for i = 1, #forms[name] do
				forms[name][i] = forms[name][i]:gsub("[AaOo]e", ligatures)
			end
		end
	end
end

-- If NUM == "sg", copy the singular forms to the plural ones; vice-versa if
-- NUM == "pl". This should allow for the equivalent of plural
-- "alpha and omega" formed from two singular nouns, and for the equivalent of
-- plural "St. Vincent and the Grenadines" formed from a singular noun and a
-- plural noun. (These two examples actually occur in Russian, at least.)
local function propagate_number_restrictions(forms, num)
	if num == "sg" or num == "pl" then
		for name in itercn() do
			if rfind(name, num) then
				local other_num_name = num == "sg" and name:gsub("sg", "pl") or name:gsub("pl", "sg")
				forms[other_num_name] = type(forms[name]) == "table" and ut.clone(forms[name]) or forms[name]
			end
		end
	end
end

-- Construct the declension of a parsed segment run of the form returned by
-- parse_segment_run() or parse_segment_run_allowing_alternants(). Return value
-- is a table
-- {
--   forms = FORMS (keyed by case/number, list of forms for that case/number),
--   notes = NOTES (keyed by case/number, map from form indices to lists of
--     footnotes),
--   title = TITLE (list of titles for each segment in the run),
--   categories = CATEGORIES (combined categories for all segments),
-- }
local function decline_segment_run(parsed_run)
	local declensions = {
		-- For each possible case/number combination (e.g. "abl_sg"),
		-- list of possible forms.
		forms = {},
		-- Keyed by case/number combination (e.g. "abl_sg"). Value is a
		-- table indicating the footnotes corresponding to the forms for
		-- that case/number combination. Each such table maps indices
		-- (the index of the corresponding form) to a list of one or more
		-- footnotes.
		notes = {},
		title = {},
		categories = {},
	}

	for name in itercn() do
		declensions.forms[name] = {""}
	end

	for _, seg in ipairs(parsed_run.segments) do
		if seg.decl then
			seg.data.loc = parsed_run.loc
			if seg.data.num == "" then
				seg.data.num = parsed_run.num
			end

			if not m_noun_decl[seg.decl] then
				error("Unrecognized declension '" .. seg.decl .. "'")
			end


			m_noun_decl[seg.decl](seg.data, seg.args)

			if seg.data.lig then
				apply_ligatures(seg.data.forms)
			end

			propagate_number_restrictions(seg.data.forms, seg.data.num)

			for name in itercn() do
				local new_forms = seg.data.forms[name]
				local new_notes = {}

				if type(new_forms) == "string" and seg.data.notes[name .. "1"] then
					new_notes[1] = {seg.data.notes[name .. "1"]}
				elseif new_forms then
					for j = 1, #new_forms do
						if seg.data.notes[name .. j] then
							new_notes[j] = {seg.data.notes[name .. j]}
						end
					end
				end

				declensions.forms[name], declensions.notes[name] = append_form(
					declensions.forms[name], declensions.notes[name],
					new_forms, new_notes, seg.prefix)
			end

			if not seg.data.types.nocat then
				for _, cat in ipairs(seg.data.categories) do
					ut.insert_if_not(declensions.categories, cat)
				end
			end

			table.insert(declensions.title, seg.data.title)
		elseif seg.alternants then
			local seg_declensions = nil
			local seg_titles = {}
			local seg_categories = {}
			for _, this_parsed_run in ipairs(seg.alternants) do
				local this_declensions = decline_segment_run(this_parsed_run)
				-- If there's a number restriction on the segment run, blank
				-- out the forms outside the restriction. This allows us to
				-- e.g. construct heteroclites that decline one way in the
				-- singular and a different way in the plural.
				if this_parsed_run.num == "sg" or this_parsed_run.num == "pl" then
					for name in itercn() do
						if this_parsed_run.num == "sg" and rfind(name, "pl") or
							this_parsed_run.num == "pl" and rfind(name, "sg") then
							this_declensions.forms[name] = {}
							this_declensions.notes[name] = nil
						end
					end
				end
				if not seg_declensions then
					seg_declensions = this_declensions
				else
					for name in itercn() do
						-- For a given case/number combination, combine
						-- the existing and new forms. We do this by
						-- checking to see whether a new form is already
						-- present and not adding it if so; in the process,
						-- we keep a map from indices in the new forms to
						-- indices in the combined forms, for use in
						-- combining footnotes below.
						local curforms = seg_declensions.forms[name] or {}
						local newforms = this_declensions.forms[name] or {}
						local newform_index_to_new_index = {}
						for newj, form in ipairs(newforms) do
							local did_break = false
							for j = 1, #curforms do
								if curforms[j] == form then
									newform_index_to_new_index[newj] = j
									did_break = true
									break
								end
							end
							if not did_break then
								table.insert(curforms, form)
								newform_index_to_new_index[newj] = #curforms
							end
						end
						seg_declensions.forms[name] = curforms
						-- Now combine the footnotes. Keep in mind that
						-- each form may have its own set of footnotes, and
						-- in some cases we didn't add a form from the new
						-- list of forms because it already occurred in the
						-- existing list of forms; in that case, we combine
						-- footnotes from the two sources.
						local curnotes = seg_declensions.notes[name]
						local newnotes = this_declensions.notes[name]
						if newnotes then
							if not curnotes then
								curnotes = {}
							end
							for index, notes in pairs(newnotes) do
								local combined_index = newform_index_to_new_index[index]
								if not curnotes[combined_index] then
									curnotes[combined_index] = notes
								else
									local combined = mw.clone(curnotes[combined_index])
									for _, note in ipairs(newnotes) do
										ut.insert_if_not(combined, newnotes)
									end
									curnotes[combined_index] = combined
								end
							end
						end
					end
				end
				for _, cat in ipairs(this_declensions.categories) do
					ut.insert_if_not(seg_categories, cat)
				end
				ut.insert_if_not(seg_titles, table.concat(this_declensions.title, " and "))
			end

			-- If overall run is singular, copy singular to plural, and
			-- vice-versa. See propagate_number_restrictions() for rationale;
			-- also, this should eliminate cases of empty forms, which will
			-- cause the overall set of forms for that case/number combination
			-- to be empty.
			propagate_number_restrictions(seg_declensions.forms, parsed_run.num)

			for name in itercn() do
				declensions.forms[name], declensions.notes[name] = append_form(
					declensions.forms[name], declensions.notes[name],
					seg_declensions.forms[name], seg_declensions.notes[name], nil)
			end

			for _, cat in ipairs(seg_categories) do
				ut.insert_if_not(declensions.categories, cat)
			end

			table.insert(declensions.title, table.concat(seg_titles, " or "))

		else
			for name in itercn() do
				declensions.forms[name], declensions.notes[name] = append_form(
					declensions.forms[name], declensions.notes[name],
					seg.prefix)
			end
		end
	end

	return declensions
end

local function new_generate_forms(frame)
	local params = {
		[1] = {required = true, default = "aqua<1>"},
		footnote = {},
		title = {},
		num = {},
	}
	for _, case in ipairs(case_order) do
		params[case] = {}
	end

	local parent_args = frame:getParent().args

	local args = m_para.process(parent_args, params)

	local parsed_run = parse_segment_run_allowing_alternants(args[1])
	parsed_run.loc = parsed_run.loc or not not (args.loc_sg or args.loc_pl)
	parsed_run.num = args.num or parsed_run.num

	local declensions = decline_segment_run(parsed_run)

	if not parsed_run.loc then
		declensions.forms.loc_sg = nil
		declensions.forms.loc_pl = nil
	end

	if args.title then
		declensions.title = "^" .. args.title
		declensions.title = rsub(declensions.title, "<1>", "[[Appendix:Latin first declension|first declension]]")
		declensions.title = rsub(declensions.title, "<1&2>", "[[Appendix:Latin first declension|first]]/[[Appendix:Latin second declension|second declension]]")
		declensions.title = rsub(declensions.title, "<2>", "[[Appendix:Latin second declension|second declension]]")
		declensions.title = rsub(declensions.title, "<3>", "[[Appendix:Latin third declension|third declension]]")
		declensions.title = rsub(declensions.title, "<4>", "[[Appendix:Latin fourth declension|fourth declension]]")
		declensions.title = rsub(declensions.title, "<5>", "[[Appendix:Latin fifth declension|fifth declension]]")
		declensions.title = rsub(declensions.title, "%^(%[%[[^|%]]+|)(.)([^|%]]+%]%])", function(a, b, c)
			return a .. uupper(b) .. c
		end)
		declensions.title = rsub(declensions.title, "%^%[%[(.)([^|%]]+)%]%]", function(a, b, c)
			return "[[" .. a .. b .. "|" .. uupper(a) .. b .. "]]"
		end)
		declensions.title = rsub(declensions.title, "%^(.)", uupper)
	else
		declensions.title = table.concat(declensions.title, "<br/>")
	end

	local all_data = {
		title = declensions.title,
		footnote = args.footnote or "",
		num = parsed_run.num,
		forms = declensions.forms,
		categories = declensions.categories,
		notes = {},
		user_specified = {},
		accel = {},
		prefix = "",
		suffix = "",
	}

	for name in itercn() do
		if declensions.notes[name] then
			for index, notes in pairs(declensions.notes[name]) do
				all_data.notes[name .. index] = notes
			end
		end
	end

	process_forms_and_overrides(all_data, args)

	return all_data
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
