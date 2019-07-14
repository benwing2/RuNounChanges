local export = {}

local lang = require("Module:languages").getByCode("la")
local m_links = require("Module:links")
local m_utilities = require("Module:utilities")
local m_para = require("Module:parameters")

NAMESPACE = NAMESPACE or mw.title.getCurrentTitle().nsText
PAGENAME = PAGENAME or mw.title.getCurrentTitle().text

local decl = require("Module:User:Benwing2/la-adj/data")
local m_table = require("Module:la-adj/table")

local rmatch = mw.ustring.match

local case_order = {
	"nom_sg_m",
	"gen_sg_m",
	"dat_sg_m",
	"acc_sg_m",
	"abl_sg_m",
	"voc_sg_m",
	"nom_sg_f",
	"gen_sg_f",
	"dat_sg_f",
	"acc_sg_f",
	"abl_sg_f",
	"voc_sg_f",
	"nom_sg_n",
	"gen_sg_n",
	"dat_sg_n",
	"acc_sg_n",
	"abl_sg_n",
	"voc_sg_n",
	"nom_pl_m",
	"gen_pl_m",
	"dat_pl_m",
	"acc_pl_m",
	"abl_pl_m",
	"voc_pl_m",
	"nom_pl_f",
	"gen_pl_f",
	"dat_pl_f",
	"acc_pl_f",
	"abl_pl_f",
	"voc_pl_f",
	"nom_pl_n",
	"gen_pl_n",
	"dat_pl_n",
	"acc_pl_n",
	"abl_pl_n",
	"voc_pl_n",
}

local function process_forms_and_overrides(data, args)
	local redlink = false
	if data.num == "pl" then
		table.insert(data.categories, "Latin plural-only adjectives")
	end
	
	local accel_lemma, accel_lemma_f
	if data.num and data.num ~= "" then
		accel_lemma = data.forms["nom_" .. data.num .. "_m"]
		accel_lemma_f = data.forms["nom_" .. data.num .. "_f"]
	else
		accel_lemma = data.forms["nom_sg_m"]
		accel_lemma_f = data.forms["nom_sg_f"]
	end
	
	for _, key in ipairs(case_order) do
		-- If noneut=1 passed, clear out all neuter forms.
		if data.noneut and key:find("_n") then
			data.forms[key] = nil
		end
		if args[key] or data.forms[key] then
			if args[key] then
				val = args[key]
				data.user_specified[key] = true
			else
				val = data.forms[key]
			end
			if type(val) == "string" then
				val = mw.text.split(val, "/")
			end
			if data.num == "pl" and key:find("sg") then
				data.forms[key] = ""
			elseif val[1] == "" or val == "" or val[1] == "-" or val[1] == "—" or val == "-" or val == "—" then
				data.forms[key] = "—"
			else
				for i, form in ipairs(val) do
					local word = data.prefix .. form .. data.suffix
					
					local accel_form = key
					accel_form = accel_form:gsub("_([sp])[gl]_", "|%1|")

					if data.noneut then
						-- If noneut=1, we're being asked to do a noun like
						-- Aquītānus or Rōmānus that has masculine and feminine
						-- variants, not an adjective. In that case, make the
						-- accelerators correspond to nomminal case/number forms
						-- without the gender, and use the feminine as the
						-- lemma for feminine forms.
						if key:find("_f") then
							data.accel[key .. i] = {form = accel_form:gsub("|f$", ""), lemma = accel_lemma_f}
						else
							data.accel[key .. i] = {form = accel_form:gsub("|m$", ""), lemma = accel_lemma}
						end
					else
						if not data.forms.nom_sg_n and not data.forms.nom_pl_n then
							-- use multipart tags if called for
							accel_form = accel_form:gsub("|m$", "|m//f//n")
						elseif not data.forms.nom_sg_f and not data.forms.nom_pl_f then
							accel_form = accel_form:gsub("|m$", "|m//f")
						end
						
						-- use the order nom|m|s, which is more standard than nom|s|m
						accel_form = accel_form:gsub("|(.-)|(.-)$", "|%2|%1")
					
						data.accel[key .. i] = {form = accel_form, lemma = accel_lemma}
					end
					val[i] = word
					if not redlink and NAMESPACE == '' then
						local title = lang:makeEntryName(word)
						local t = mw.title.new(title)
						if t and not t.exists then
							table.insert(data.categories, 'Latin adjectives with red links in their declension tables')
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
			data.forms[key] = table.concat(val, ", ")
		end
	end
	data.footnote = table.concat(notes, "<br />") .. data.footnote
end

local function generate_forms(frame)
	local data = {
		title = "",
		footnote = "",
		num = "",
		voc = true,
		forms = {},
		types = {},
		categories = {},
		notes = {},
		user_specified = {},
		accel = {},
	}

	local iparams = {
		[1] = {},
		["type"] = {},
		num = {},
	}

	local iargs = m_para.process(frame.args, iparams)

	local parent_args = frame:getParent().args

	local subtype = iargs["type"] or parent_args["type"]

	if subtype and subtype ~= "" then
		for name, val in ipairs(rsplit(decl_type, "%-")) do
			data.types[val] = true
		end
	end

	local params = {
		[1] = {required = true, default = "{{{1}}}"},
		[2] = {},
		["type"] = {},
		decltype = {},
		noun = {},
		num = {},
		prefix = {},
		suffix = {},
		noneut = {type = "boolean"},
	}
	for _, case in ipairs(case_order) do
		params[case] = {}
	end

	local args = m_para.process(parent_args, params)

	data.num = iargs.num or args.num or ""
	data.prefix = args.prefix or ""
	data.suffix = args.suffix or ""
	data.noneut = args.noneut

	decl[iargs[1] or args.decltype](data, args)

	process_forms_and_overrides(data, args)

	if data.prefix .. data.suffix ~= "" then
		table.insert(data.categories, "Kenny's testing category 6")
	end

	return data
end

function export.show(frame)
	local data = generate_forms(frame)

	show_forms(data)

	return m_table.make_table(data) .. m_utilities.format_categories(data.categories, lang)
end

function export.generate_forms(frame)
	local data = generate_forms(frame)

	local ins_text = {}
	for _, key in ipairs(case_order) do
		local val = data.forms[key]
		if val and val ~= "" and val ~= "—" and #val > 0 then
			table.insert(ins_text, key .. "=" .. table.concat(val, ","))
		end
	end
	return table.concat(ins_text, "|")
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
-- return the tuple nil, nil, nil.
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
local function get_type_and_subtype_by_ending(lemma, stem2, decltype, specified_subtypes,
		endings_and_subtypes)
	for _, ending_and_subtypes in ipairs(endings_and_subtypes) do
		local ending = ending_and_subtypes[1]
		local rettype = decltype
		local subtypes = ending_and_subtypes[2]
		if #ending_and_subtypes == 3 then
			rettype = ending_and_subtypes[2]
			subtypes = ending_and_subtypes[3]
		end
		not_this_subtype = false
		for _, subtype in ipairs(subtypes) do
			-- A subtype is directly canceled by specifying -SUBTYPE.
			if specified_subtypes["-" .. subtype] then
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
					return base, rettype, subtypes
				end
			else
				local base = extract_base(lemma, ending)
				if base then
					return base, rettype, subtypes
				end
			end
		end
	end
	if decltype == "" then
		error("Unrecognized ending for adjective: " .. lemma)
	else
		error("Unrecognized ending for declension-" .. decltype .. " adjective: " .. lemma)
	end
	return nil, nil, nil
end
-- Autodetect the subtype of an adjective given all the information specified
-- by the user: lemma, stem2, declension type and specified subtypes. Two
-- values are returned: the lemma base (i.e. the stem of the lemma, as required
-- by the declension functions) and the autodetected subtypes. Note that this
-- will not detect a given subtype if the explicitly specified subtypes are
-- incompatible (i.e. if -SUBTYPE is specified for any subtype that would be
-- returned; or if M or F is specified when N would be returned, and
-- vice-versa; or if pl is specified when sg would be returned, and vice-versa).
--
-- NOTE: This function has intimate knowledge of the way that the declension
-- functions handle subtypes, particularly for the third declension.
function export.detect_type_and_subtype(lemma, stem2, typ, subtypes)
	local base, ending

	if typ == "" then
		return get_type_and_subtype_by_ending(lemma, stem2, typ, subtypes, {
			{"us", "1&2", {}},
			{"a", "1&2", {}},
			{"um", "1&2", {}},
			{"ī", "1&2", {}},
			{"ae", "1&2", {}},
			-- FIXME, check whether this makes the most sense
			{"os", "1&2", {"greekA"}},
			{"ē", "1&2", {"greekE"}},
			-- FIXME, check whether this makes the most sense
			{"on", "1&2", {"greekA"}},
			{"er", "1&2", {"er"}},
			-- FIXME, maybe should be 3rd declension
			{"ur", "1&2", {"er"}},
			{"is", "3-2", {}},
			{"ior", "3-C", {}},
			{"jor", "3-C", {}},
			{"", "3-1", {}},
		})
	end

	if typ == "1&2" then
		return get_type_and_subtype_by_ending(lemma, stem2, typ, subtypes, {
			{"us", {}},
			{"a", {}},
			{"um", {}},
			{"ī", {}},
			{"ae", {}},
			-- FIXME, check whether this makes the most sense
			{"os", {"greekA"}},
			{"os", {"greekE"}},
			{"ē", {"greekE"}},
			-- FIXME, check whether this makes the most sense
			{"on", {"greekA"}},
			{"er", {"er"}},
			{"ur", {"er"}},
		})
	elseif typ == "1-1" then
		return get_type_and_subtype_by_ending(lemma, stem2, typ, subtypes, {
			{"a", {}},
			{"ae", {}},
		})
	elseif typ == "2-2" then
		return get_type_and_subtype_by_ending(lemma, stem2, typ, subtypes, {
			{"us", {}},
			{"um", {}},
			{"ī", {}},
			{"a", {}},
			{"os", {"greek"}},
			{"on", {"greek"}},
			{"oe", {"greek"}},
		})
	elseif typ == "3" then
		return get_type_and_subtype_by_ending(lemma, stem2, typ, subtypes, {
			{"er", "3-3", {}},
			{"is", "3-2", {}},
			{"e", "3-2", {}},
			{"ior", "3-C", {}},
			{"jor", "3-C", {}},
			{"", "3-1", {}},
		})
	else
		return lemma, typ, {}
	end
end

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
