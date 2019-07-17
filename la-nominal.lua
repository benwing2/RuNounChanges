local export = {}

-- TODO:
-- (DONE) Eliminate specification of noteindex from la-adj/data
-- (DONE?) Finish autodetection of adjectives
-- (DONE) Remove old noun code
-- (DONE) Implement <.sufn>
-- (DONE) Look into adj voc=false
-- Handle loc in adjectives

--[=[

TERMINOLOGY:

-- "slot" = A particular case/number combination (for nouns) or
	 case/number/gender combination (for adjectives). Example slot names are
	 "abl_sg" (for noun) or "acc_pl_f" (for adjectives). Each slot is filled
	 with zero or more forms.

-- "form" = The declined Latin form representing the value of a given slot.
	 For example, rēge is a form, representing the value of the abl_sg slot of
	 the lemma rēx.

-- "lemma" = The dictionary form of a given Latin term. For nouns, it's
	 generally the nominative singular, but will be the nominative plural of
	 plurale tantum nouns (e.g. [[castra]]), and may occasionally be another
	 form (e.g. the genitive singular) if the nominative singular is missing.
	 For adjectives, it's generally the masculine nominative singular, but
	 will be the masculine nominative plural of plurale tantum adjectives
	 (e.g. [[dēnī]]).

-- "plurale tantum" (plural "pluralia tantum") = A noun or adjective that
	 exists only in the plural. Examples are castra "army camp", faucēs "throat",
	 and dēnī "ten each" (used for counting pluralia tantum nouns).

-- "singulare tantum" (plural "singularia tantum") = A noun or adjective that
	 exists only in the singular. Examples are geōlogia "geology" (and in
	 general most non-count nouns) and the adjective ūnus "one".

]=]

local lang = require("Module:languages").getByCode("la")
local m_links = require("Module:links")
local m_utilities = require("Module:utilities")
local ut = require("Module:utils")
local m_string_utilities = require("Module:string utilities")
local m_para = require("Module:parameters")

local current_title = mw.title.getCurrentTitle()
local NAMESPACE = current_title.nsText
local PAGENAME = current_title.text

local m_la_adj = require("Module:User:Benwing2/la-adj")
local m_noun_decl = require("Module:la-noun/data")
local m_noun_table = require("Module:la-noun/table")
local m_adj_decl = require("Module:User:Benwing2/la-adj/data")
local m_adj_table = require("Module:la-adj/table")
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

local gender_to_lc = {
	['M'] = 'm',
	['F'] = 'f',
	['N'] = 'n',
}

local cases = {
	"nom", "gen", "dat", "acc", "abl", "voc", "loc"
}

local nums = {
	"sg", "pl"
}

local genders = {
	"m", "f", "n"
}

-- Iterate over all the "slots" associated with a noun declension, where a slot
-- is a particular case/number combination.
local function iter_noun_slots()
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

-- Iterate over all the "slots" associated with an adjective declension, where a slot
-- is a particular case/number/gender combination.
local function iter_adj_slots()
	local i = 1
	local j = 1
	local k = 0
	local function iter()
		k = k + 1
		if k > #genders then
			k = 1
			j = j + 1
			if j > #nums then
				j = 1
				i = i + 1
				if i > #cases then
					return nil
				end
			end
		end
		return cases[i] .. "_" .. nums[j] .. "_" .. genders[k]
	end
	return iter
end

-- Iterate over all the "slots" associated with a noun or adjective declension (depending on
-- the value of IS_ADJ), where a slot is a particular case/number combination (in the case of
-- nouns) or case/number/gender combination (in the case of adjectives).
local function iter_slots(is_adj)
	if is_adj then
		return iter_adj_slots()
	else
		return iter_noun_slots()
	end
end

local function process_noun_forms_and_overrides(data, args)
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

	for slot in iter_noun_slots() do
		if args[slot] or data.forms[slot] then
			local val
			if args[slot] then
				val = args[slot]
				data.user_specified[slot] = true
			else
				val = data.forms[slot]
			end
			if type(val) == "string" then
				val = rsplit(val, "/")
			end
			if (data.num == "pl" and slot:find("sg")) or (data.num == "sg" and slot:find("pl")) then
				data.forms[slot] = ""
			elseif val[1] == "" or val[1] == "-" or val[1] == "—" then
				data.forms[slot] = "—"
			else
				for i, form in ipairs(val) do
					local word = data.prefix .. (data.n and rsub(form,"m$","n") or form) .. data.suffix

					local accel_form = slot
					accel_form = accel_form:gsub("_([sp])[gl]$", "|%1")

					data.accel[slot .. i] = {form = accel_form, lemma = accel_lemma}
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
				data.forms[slot] = val
			end
		end
	end
end

local function process_adj_forms_and_overrides(data, args)
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

	for slot in iter_adj_slots() do
		-- If noneut=1 passed, clear out all neuter forms.
		if data.noneut and slot:find("_n") then
			data.forms[slot] = nil
		end
		if args[slot] or data.forms[slot] then
			if args[slot] then
				val = args[slot]
				data.user_specified[slot] = true
			else
				val = data.forms[slot]
			end
			if type(val) == "string" then
				val = mw.text.split(val, "/")
			end
			if data.num == "pl" and slot:find("sg") then
				data.forms[slot] = ""
			elseif val[1] == "" or val == "" or val[1] == "-" or val[1] == "—" or val == "-" or val == "—" then
				data.forms[slot] = "—"
			else
				for i, form in ipairs(val) do
					local word = data.prefix .. form .. data.suffix

					local accel_form = slot
					accel_form = accel_form:gsub("_([sp])[gl]_", "|%1|")

					if data.noneut then
						-- If noneut=1, we're being asked to do a noun like
						-- Aquītānus or Rōmānus that has masculine and feminine
						-- variants, not an adjective. In that case, make the
						-- accelerators correspond to nominal case/number forms
						-- without the gender, and use the feminine as the
						-- lemma for feminine forms.
						if slot:find("_f") then
							data.accel[slot .. i] = {form = accel_form:gsub("|f$", ""), lemma = accel_lemma_f}
						else
							data.accel[slot .. i] = {form = accel_form:gsub("|m$", ""), lemma = accel_lemma}
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

						data.accel[slot .. i] = {form = accel_form, lemma = accel_lemma}
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
				data.forms[slot] = val
			end
		end
	end

	-- See if the masculine and feminine are the same across all slots. If so, blank out the feminine so we use a
	-- table that combines masculine and feminine.
	local fem_is_masc = true
	for _, case in ipairs(cases) do
		for _, num in ipairs(nums) do
			if not ut.equals(data.forms[case .. "_" .. num .. "_f"], data.forms[case .. "_" .. num .. "_m"]) then
				fem_is_masc = false
				break
			end
		end
		if not fem_is_masc then
			break
		end
	end

	if fem_is_masc then
		for _, case in ipairs(cases) do
			for _, num in ipairs(nums) do
				data.forms[case .. "_" .. num .. "_f"] = nil
			end
		end
	end
end

local function show_forms(data, is_adj)
	local noteindex = 1
	local notes = {}
	local seen_notes = {}
	for slot in iter_slots(is_adj) do
		local val = data.forms[slot]
		if val and val ~= "" and val ~= "—" then
			for i, form in ipairs(val) do
				local link = m_links.full_link({lang = lang, term = form, accel = data.accel[slot .. i]})
				local this_notes = data.notes[slot .. i]
				if this_notes and not data.user_specified[slot] then
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
			-- FIXME, do we want this difference?
			data.forms[slot] = table.concat(val, is_adj and ", " or "<br />")
		end
	end
	data.footnote = table.concat(notes, "<br />") .. data.footnote
end

local function make_noun_table(data)
	if data.num == "sg" then
		return m_noun_table.make_table_sg(data)
	elseif data.num == "pl" then
		return m_noun_table.make_table_pl(data)
	else
		return m_noun_table.make_table(data)
	end
end

local function concat_forms(data, is_adj)
	local ins_text = {}
	for slot in iter_slots(is_adj) do
		local val = data.forms[slot]
		if val and val ~= "" and val ~= "—" and #val > 0 then
			local new_vals = {}
			for _, v in ipairs(val) do
				table.insert(new_vals, rsub(v, "|", "<!>"))
			end
			table.insert(ins_text, slot .. "=" .. table.concat(new_vals, ","))
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
local function get_noun_subtype_by_ending(lemma, stem2, decltype, specified_subtypes,
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
local function detect_noun_subtype(lemma, stem2, typ, subtypes)
	local base, ending

	if typ == "1" then
		return get_noun_subtype_by_ending(lemma, stem2, typ, subtypes, {
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
		return get_noun_subtype_by_ending(lemma, stem2, typ, subtypes, {
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
				get_noun_subtype_by_ending(lemma, stem2, nil, subtypes, {
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
			base, detected_subtypes = get_noun_subtype_by_ending(lemma, stem2, nil, subtypes, {
				{"^([A-ZĀĒĪŌŪȲĂĔĬŎŬ].*)polis$", {"polis", "sg", "loc"}},
			})
			if base then
				return base, detected_subtypes
			end
			base, detected_subtypes = get_noun_subtype_by_ending(lemma, stem2, nil, subtypes, {
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

		base, detected_subtypes = get_noun_subtype_by_ending(lemma, stem2, nil, subtypes, {
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
		if subtypes.echo or subtypes.argo or subtypes.Callisto then
			base = rmatch(lemma, "^(.*)ō$")
			if not base then
				error("Declension-4 noun of subtype .echo, .argo or .Callisto should end in -ō: " .. lemma)
			end
			if subtypes.Callisto then
				return base, {"sg"}
			else
				return base, {}
			end
		end
		return get_noun_subtype_by_ending(lemma, stem2, typ, subtypes, {
			{"us", {"M"}},
			{"ū", {"N"}},
			{"ūs", {"M", "pl"}},
			{"ua", {"N", "pl"}},
		})
	elseif typ == "5" then
		return get_noun_subtype_by_ending(lemma, stem2, typ, subtypes, {
			{"iēs", {"F", "i"}},
			{"ēs", {"F"}},
		})
	elseif typ == "irreg" and lemma == "domus" then
		-- [[domus]] auto-sets data.loc = true, but we need to know this
		-- before declining the noun so we can propagate it to other segments.
		return lemma, {"loc"}
	elseif typ == "indecl" or typ == "irreg" and (
		lemma == "Deus" or lemma == "Iēsus" or lemma == "Jēsus" or lemma == "vēnum"
	) then
		-- Indeclinable nouns, and certain irregular nouns, set data.num = "sg",
		-- but we need to know this before declining the noun so we can
		-- propagate it to other segments.
		return lemma, {"sg"}
	else
		return lemma, {}
	end
end

function export.detect_noun_subtype(frame)
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
	local base, subtypes = detect_noun_subtype(args[1], args[2], args[3], specified_subtypes)
	return base .. "|" .. table.concat(subtypes, ".")
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
local function get_unadjusted_adj_type_and_subtype_by_ending(lemma, stem2, decltype,
		specified_subtypes, endings_and_subtypes)
	for _, ending_and_subtypes in ipairs(endings_and_subtypes) do
		local ending = ending_and_subtypes[1]
		local rettype = ending_and_subtypes[2]
		local subtypes = ending_and_subtypes[3]
		local specified_stem2 = ending_and_subtypes[4]
		not_this_subtype = false
		for _, subtype in ipairs(subtypes) do
			-- A subtype is directly canceled by specifying -SUBTYPE.
			if specified_subtypes["-" .. subtype] then
				not_this_subtype = true
				break
			end
			-- A subtype is canceled if the user specified SUBTYPE and
			-- -SUBTYPE is given in the to-be-returned subtypes.
			must_not_be_present = rmatch(subtype, "^%-(.*)$")
			if must_not_be_present and specified_subtypes[must_not_be_present] then
				not_this_subtype = true
				break
			end
		end
		if not not_this_subtype then
			local base
			if type(ending) == "table" then
				local lemma_ending = ending[1]
				local stem2_ending = ending[2]
				base = extract_base(lemma, lemma_ending)
				if base and base .. stem2_ending ~= stem2 then
					base = nil
				end
			else
				base = extract_base(lemma, ending)
			end
			if base then
				-- Remove subtypes of the form -SUBTYPE from the subtypes
				-- to be returned.
				local new_subtypes = {}
				for _, subtype in ipairs(subtypes) do
					if not rfind(subtype, "^%-") then
						table.insert(new_subtypes, subtype)
					end
				end
				return base, specified_stem2 or stem2, rettype, new_subtypes
			end
		end
	end
	if decltype == "" then
		error("Unrecognized ending for adjective: " .. lemma)
	else
		error("Unrecognized ending for declension-" .. decltype .. " adjective: " .. lemma)
	end
end

-- Hack: The declension functions for 3-1 expect type "par" for non-i-stems. We instead use -I
-- to indicate non-i-stems, which is more standard. This function converts as appropriate.
local function get_adj_type_and_subtype_by_ending(lemma, stem2, decltype, specified_subtypes,
		endings_and_subtypes)
	local base, stem2, decl, subtypes = get_unadjusted_adj_type_and_subtype_by_ending(lemma, stem2,
		decltype, specified_subtypes, endings_and_subtypes)
	--if decl == "3-1" and not ut.contains(subtypes, "I") then
		-- NOTE: This depends on the subtypes list getting generated afresh each time in the
		-- call to this function. This is currently always the case, so we can save space (but be
		-- potentially more dangerous) by not cloning.
	--	table.insert(subtypes, "par")
	--end
	return base, stem2, decl, subtypes
end

-- Autodetect the type and subtype of an adjective given all the information
-- specified by the user: lemma, stem2, declension type and specified subtypes.
-- Four values are returned: the lemma base (i.e. the stem of the lemma, as
-- required by the declension functions), the value of stem2 to pass to the
-- declension function, the declension type and the autodetected subtypes.
-- Note that this will not detect a given subtype if -SUBTYPE is specified for
-- any subtype that would be returned, or if SUBTYPE is specified and -SUBTYPE
-- is among the subtypes that would be returned (such subtypes are filtered out
-- of the returned subtypes).
local function detect_adj_type_and_subtype(lemma, stem2, typ, subtypes)
	if not rfind(typ, "^[123]") then
		subtypes = mw.clone(subtypes)
		subtypes[typ] = true
		typ = ""
	end
	if typ == "" then
		return get_adj_type_and_subtype_by_ending(lemma, stem2, typ, subtypes, {
			{"us", "1&2", {}},
			{"a", "1&2", {}},
			{"um", "1&2", {}},
			{"ī", "1&2", {"pl"}},
			{"ae", "1&2", {"pl"}},
			-- Nearly all -os adjective are greekA
			{"os", "1&2", {"greekA", "-greekE"}},
			{"ē", "1&2", {"greekE", "-greekA"}},
			{"on", "1&2", {"greekA", "-greekE"}},
			{"er", "1&2", {"er"}},
			{"ur", "1&2", {"er"}},
			{"is", "3-2", {}},
			{"e", "3-2", {}},
			{"ior", "3-C", {}},
			{"jor", "3-C", {}, "j"},
			{"^(mi)nor$", "3-C", {}, "n"},
			{"", "3-1", {"I"}},
			{"", "3-1", {"par"}},
		})
	elseif typ == "3" then
		return get_adj_type_and_subtype_by_ending(lemma, stem2, typ, subtypes, {
			{"er", "3-3", {}},
			{"is", "3-2", {}},
			{"e", "3-2", {}},
			{"ior", "3-C", {}},
			{"jor", "3-C", {}, "j"},
			{"^(mi)nor$", "3-C", {}, "n"},
			{"", "3-1", {"I"}},
			{"", "3-1", {"par"}},
		})
	elseif typ == "1&2" then
		return get_adj_type_and_subtype_by_ending(lemma, stem2, typ, subtypes, {
			{"us", "1&2", {}},
			{"a", "1&2", {}},
			{"um", "1&2", {}},
			{"ī", "1&2", {"pl"}},
			{"ae", "1&2", {"pl"}},
			-- Nearly all -os adjective are greekA
			{"os", "1&2", {"greekA", "-greekE"}},
			{"ē", "1&2", {"greekE", "-greekA"}},
			{"on", "1&2", {"greekA", "-greekE"}},
			{"er", "1&2", {"er"}},
			{"ur", "1&2", {"er"}},
		})
	elseif typ == "1-1" then
		return get_adj_type_and_subtype_by_ending(lemma, stem2, typ, subtypes, {
			{"a", "1-1", {}},
			{"ae", "1-1", {}},
		})
	elseif typ == "2-2" then
		return get_adj_type_and_subtype_by_ending(lemma, stem2, typ, subtypes, {
			{"us", "2-2", {}},
			{"um", "2-2", {}},
			{"ī", "2-2", {}},
			{"a", "2-2", {}},
			{"os", "2-2", {"greek"}},
			{"on", "2-2", {"greek"}},
			{"oe", "2-2", {"greek"}},
		})
	elseif typ == "3-1" then
		-- This will cancel out the I if -I is specified in subtypes, and the
		-- resulting lack of I will get converted to "par".
		return get_adj_type_and_subtype_by_ending(lemma, stem2, typ, subtypes, {
			{"", "3-1", {"I"}},
			{"", "3-1", {"par"}},
		})
	elseif typ == "3-2" then
		return get_adj_type_and_subtype_by_ending(lemma, stem2, typ, subtypes, {
			{"is", "3-2", {}},
			{"e", "3-2", {}},
		})
	elseif typ == "3-C" then
		return get_adj_type_and_subtype_by_ending(lemma, stem2, typ, subtypes, {
			{"ior", "3-C", {}},
			{"jor", "3-C", {}, "j"},
			{"^(mi)nor$", "3-C", {}, "n"},
		})
	else
		return lemma, stem2, typ, {}
	end
end

-- Parse a segment (e.g. "lūna<1>", "aegis/aegid<3.Greek>", "bonus<+>", or
-- "vetus/veter<3+.-I>"), consisting of a lemma (or optionally a lemma/stem)
-- and declension+subtypes, where a + in the declension indicates an adjective.
-- The return value is a table, e.g.:
-- {
--   decl = "1",
--   is_adj = false,
--   lemma = "lūna",
--   stem2 = nil,
--   gender = "F",
--   data = DATA_TABLE (a table of info extracted from subtypes),
--   args = {"lūn"}
-- }
--
-- or
--
-- {
--   decl = "3",
--   is_adj = false,
--   lemma = "aegis",
--   stem2 = "aegid",
--   gender = nil,
--   data = DATA_TABLE (a table of info extracted from subtypes),
--   args = {"aegis", "aegid"}
-- }
--
-- or
--
-- {
--   decl = "1&2",
--   is_adj = true,
--   lemma = "bonus",
--   stem2 = nil,
--   gender = nil,
--   data = DATA_TABLE (a table of info extracted from subtypes),
--   args = {"bon"}
-- }
--
-- or
--
-- {
--   decl = "3-1",
--   is_adj = true,
--   lemma = "vetus",
--   stem2 = "veter",
--   gender = nil,
--   data = DATA_TABLE (a table of info extracted from subtypes),
--   args = {"vetus", "veter"}
-- }
local function parse_segment(segment)
	local stem_part, spec_part = rmatch(segment, "^(.*)<(.-)>$")
	local stems = rsplit(stem_part, "/", true)
	local specs = rsplit(spec_part, ".", true)

	local types = {}
	local num = nil
	local loc = false

	local args = {}

	local decl
	for j, spec in ipairs(specs) do
		if j == 1 then
			decl = spec
		else
			types[spec] = true
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

	local base, detected_subtypes
	local is_adj = false
	local gender = nil

	if rfind(decl, "%+") then
		decl = decl:gsub("%+", "")
		base, stem2, decl, detected_subtypes = detect_adj_type_and_subtype(
			lemma, stem2, decl, types
		)
		is_adj = true

		for _, subtype in ipairs(detected_subtypes) do
			if types["-" .. subtype] then
				-- if a "cancel subtype" spec is given, remove the cancel spec
				-- and don't apply the subtype
				types["-" .. subtype] = nil
			else
				types[subtype] = true
			end
		end
	else
		base, detected_subtypes = detect_noun_subtype(lemma, stem2, decl, types)

		for _, subtype in ipairs(detected_subtypes) do
			if types["-" .. subtype] then
				-- if a "cancel subtype" spec is given, remove the cancel spec
				-- and don't apply the subtype
				types["-" .. subtype] = nil
			elseif (subtype == "M" or subtype == "F" or subtype == "N") and
					(types.M or types.F or types.N) then
				-- if gender already specified, don't create conflicting gender spec
			elseif (subtype == "sg" or subtype == "pl" or subtype == "both") and
					(types.sg or types.pl or types.both) then
				-- if number restriction already specified, don't create conflicting
				-- number restriction spec
			else
				types[subtype] = true
			end
		end

		if not types.pl and not types.both and rfind(lemma, "^[A-ZĀĒĪŌŪȲĂĔĬŎŬ]") then
			types.sg = true
		end

		if types.pl then
			num = "pl"
			types.pl = nil
		elseif types.sg then
			num = "sg"
			types.sg = nil
		end
		if types.loc then
			loc = true
			types.loc = nil
		end

		if types.M then
			gender = "M"
		elseif types.F then
			gender = "F"
		elseif types.N then
			gender = "N"
		end
	end

	args[1] = base
	args[2] = stem2

	return {
		decl = decl,
		is_adj = is_adj,
		gender = gender,
		lemma = lemma,
		stem2 = stem2,
		types = types,
		num = num,
		loc = loc,
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
--   num = NUM (the first specified value for a number restriction, or nil if
--     no number restrictions),
--   gender = GENDER (the first specified or inferred gender, or nil if none),
-- }
-- Each element in PARSED_SEGMENTS is as returned by parse_segment() but will
-- have an additional .prefix field indicating the text before the segment. If
-- there is trailing text, the last element will have only a .prefix field
-- containing that trailing text.
local function parse_segment_run(segment_run)
	local loc = nil
	local num = nil
	local segments
	-- If the segment run begins with a hyphen, include the hyphen in the
	-- set of allowed characters for a declined segment. This way, e.g. the
	-- suffix [[-cen]] can be declared as {{la-ndecl|-cen/-cin<3>}} rather than
	-- {{la-ndecl|-cen/cin<3>}}, which is less intuitive.
	if rfind(segment_run, "^%-") then
		segments = m_string_utilities.capturing_split(segment_run, "([^<> ,]+<.->)")
	else
		segments = m_string_utilities.capturing_split(segment_run, "([^<> ,%-]+<.->)")
	end
	local parsed_segments = {}
	local gender = nil
	for i = 2, (#segments - 1), 2 do
		local parsed_segment = parse_segment(segments[i])
		-- Overall locative is true if any segments call for locative.
		loc = loc or parsed_segment.loc
		-- The first specified value for num is used becomes the overall value.
		num = num or parsed_segment.num
		gender = gender or parsed_segment.gender
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
		gender = gender,
	}
end

-- Parse an alternant, e.g. "((epulum<2.sg>,epulae<1>))",
-- "((Serapis<3>,Serapis/Serapid<3>))" or
-- "((rēs<5>pūblica<1>,rēspūblica<1>))". The return value is a table of the form
-- {
--   alternants = PARSED_ALTERNANTS (a list of segment runs, each of which is a
--     list of parsed segments as returned by parse_segment_run()),
--   loc = LOC (a boolean indicating whether any of the individual segment runs
--     has a locative),
--   num = NUM (the overall number restriction, one of "sg", "pl" or "both"),
--   gender = GENDER (the first specified or inferred gender, or nil if none),
-- }
local function parse_alternant(alternant)
	local parsed_alternants = {}
	local alternant_spec = rmatch(alternant, "^%(%((.*)%)%)$")
	local alternants = rsplit(alternant_spec, ",")
	local loc = false
	local num = nil
	local gender = nil
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
		gender = gender or parsed_run.gender
	end
	return {
		alternants = parsed_alternants,
		loc = loc,
		num = num,
		gender = gender,
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
--   num = NUM (the first specified value for a number restriction, or nil if
--     no number restrictions),
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
--   gender = GENDER (the first specified or inferred gender, or nil if none),
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
	local num = nil
	local gender = nil
	for i = 1, #alternating_segments do
		local alternating_segment = alternating_segments[i]
		if alternating_segment ~= "" then
			if i % 2 == 1 then
				local parsed_run = parse_segment_run(alternating_segment)
				for _, parsed_segment in ipairs(parsed_run.segments) do
					table.insert(parsed_segments, parsed_segment)
				end
				loc = loc or parsed_run.loc
				num = num or parsed_run.num
				gender = gender or parsed_run.gender
			else
				local parsed_alternating_segment = parse_alternant(alternating_segment)
				loc = loc or parsed_alternating_segment.loc
				num = num or parsed_alternating_segment.num
				gender = gender or parsed_alternating_segment.gender
				table.insert(parsed_segments, parsed_alternating_segment)
			end
		end
	end

	return {
		segments = parsed_segments,
		loc = loc,
		num = num,
		gender = gender,
	}
end

-- Combine each form in FORMS (a list of forms associated with a slot) with each
-- form in NEW_FORMS (either a single string for a single form, or a list of
-- forms) by concatenating EXISTING_FORM .. PREFIX .. NEW_FORM. Also combine
-- NOTES (a table specifying the footnotes associated with each existing form,
-- i.e. a map from form indices to lists of footnotes) with NEW_NOTES (new
-- footnotes associated with the new forms, in the same format as NOTES). Return
-- a pair NEW_FORMS, NEW_NOTES where either or both of FORMS and NOTES (but not
-- the sublists in NOTES) may be destructively modified to generate the return
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

-- Destructively modify any forms in FORMS (a map from a slot to a form or a
-- list of forms) by converting sequences of ae, oe, Ae or Oe to the
-- appropriate ligatures.
local function apply_ligatures(forms, is_adj)
	for slot in iter_slots(is_adj) do
		if type(forms[slot]) == "string" then
			forms[slot] = forms[slot]:gsub("[AaOo]e", ligatures)
		elseif type(forms[slot]) == "table" then
			for i = 1, #forms[slot] do
				forms[slot][i] = forms[slot][i]:gsub("[AaOo]e", ligatures)
			end
		end
	end
end

-- Destructively modify any forms in FORMS (a map from a slot to a form or a
-- list of forms) by converting final m to n.
local function apply_sufn(forms, is_adj)
	for slot in iter_slots(is_adj) do
		if type(forms[slot]) == "string" then
			forms[slot] = forms[slot]:gsub("m$", "n")
		elseif type(forms[slot]) == "table" then
			for i = 1, #forms[slot] do
				forms[slot][i] = forms[slot][i]:gsub("m$", "n")
			end
		end
	end
end

-- If NUM == "sg", copy the singular forms to the plural ones; vice-versa if
-- NUM == "pl". This should allow for the equivalent of plural
-- "alpha and omega" formed from two singular nouns, and for the equivalent of
-- plural "St. Vincent and the Grenadines" formed from a singular noun and a
-- plural noun. (These two examples actually occur in Russian, at least.)
local function propagate_number_restrictions(forms, num, is_adj)
	if num == "sg" or num == "pl" then
		for slot in iter_slots(is_adj) do
			if rfind(slot, num) then
				local other_num_slot = num == "sg" and slot:gsub("sg", "pl") or slot:gsub("pl", "sg")
				forms[other_num_slot] = type(forms[slot]) == "table" and ut.clone(forms[slot]) or forms[slot]
			end
		end
	end
end

-- Construct the declension of a parsed segment run of the form returned by
-- parse_segment_run() or parse_segment_run_allowing_alternants(). Return value
-- is a table
-- {
--   forms = FORMS (keyed by slot, list of forms for that slot),
--   notes = NOTES (keyed by slot, map from form indices to lists of footnotes),
--   title = TITLE (list of titles for each segment in the run),
--   categories = CATEGORIES (combined categories for all segments),
--   voc = BOOLEAN (false if any adjective in the run has no vocative),
-- }
local function decline_segment_run(parsed_run, is_adj)
	local declensions = {
		-- For each possible slot (e.g. "abl_sg"), list of possible forms.
		forms = {},
		-- Keyed by slot (e.g. "abl_sg"). Value is a table indicating the footnotes
		-- corresponding to the forms for that slot. Each such table maps indices
		-- (the index of the corresponding form) to a list of one or more
		-- footnotes.
		notes = {},
		title = {},
		categories = {},
		-- FIXME, do we really need to special-case this? Maybe the nonexistent vocative
		-- form will automatically propagate up through the other forms.
		voc = true,
	}

	for slot in iter_slots(is_adj) do
		declensions.forms[slot] = {""}
	end

	for _, seg in ipairs(parsed_run.segments) do
		if seg.decl then
			seg.loc = parsed_run.loc
			seg.num = seg.num or parsed_run.num
			seg.gender = seg.gender or parsed_run.gender

			local data

			if seg.is_adj then
				if not m_adj_decl[seg.decl] then
					error("Unrecognized declension '" .. seg.decl .. "'")
				end

				data = {
					title = "",
					footnote = "",
					num = seg.num or "",
					voc = true,
					forms = {},
					types = seg.types,
					categories = {},
					notes = {},
					prefix = "",
					suffix = "",
				}
				m_adj_decl[seg.decl](data, seg.args)
				if not data.voc then
					declensions.voc = false
				end
			else
				if not m_noun_decl[seg.decl] then
					error("Unrecognized declension '" .. seg.decl .. "'")
				end

				data = {
					title = "",
					footnote = "",
					num = seg.num or "",
					loc = seg.loc,
					um = false,
					n = false,
					forms = {},
					types = seg.types,
					categories = {},
					notes = {},
					prefix = "",
					suffix = "",
				}
				if seg.types.genplum then
					data.um = true
					seg.types.genplum = nil
				end
				if seg.types.sufn then
					data.n = true
					seg.types.sufn = nil
				end

				m_noun_decl[seg.decl](data, seg.args)
			end

			if seg.types.lig then
				apply_ligatures(data.forms, is_adj)
			end

			if seg.types.sufn then
				apply_sufn(data.forms, is_adj)
			end

			propagate_number_restrictions(data.forms, seg.num, is_adj)

			for slot in iter_slots(is_adj) do
				-- 1. Select the forms to append to the existing ones.

				local new_forms
				if is_adj then
					if not seg.is_adj then
						error("Can't decline noun '" .. seg.lemma .. "' when overall term is an adjective")
					end
					new_forms = data.forms[slot]
					if not new_forms and slot:find("_[fn]$") then
						new_forms = data.forms[slot:gsub("_[fn]$", "_m")]
					end
				elseif seg.is_adj then
					if not seg.gender then
						error("Declining modifying adjective " .. seg.lemma .. " but don't know gender of associated noun")
					end
					-- Select the appropriately gendered equivalent of the case/number
					-- combination. Some adjectives won't have feminine or neuter
					-- variants, though (e.g. 3-1 and 3-2 adjectives don't have a
					-- distinct feminine), so in that case select the masculine.
					new_forms = data.forms[slot .. "_" .. gender_to_lc[seg.gender]]
						or data.forms[slot .. "_m"]
				else
					new_forms = data.forms[slot]
				end

				-- 2. Extract the new footnotes in the format we require, which is
				-- different from the format passed in by the declension functions.

				local new_notes = {}

				if type(new_forms) == "string" and data.notes[slot .. "1"] then
					new_notes[1] = {data.notes[slot .. "1"]}
				elseif new_forms then
					for j = 1, #new_forms do
						if data.notes[slot .. j] then
							new_notes[j] = {data.notes[slot .. j]}
						end
					end
				end

				-- 3. Append new forms and footnotes to the existing ones.

				declensions.forms[slot], declensions.notes[slot] = append_form(
					declensions.forms[slot], declensions.notes[slot],
					new_forms, new_notes, seg.prefix)
			end

			if not seg.types.nocat then
				for _, cat in ipairs(data.categories) do
					ut.insert_if_not(declensions.categories, cat)
				end
			end

			table.insert(declensions.title, data.title)
		elseif seg.alternants then
			local seg_declensions = nil
			local seg_titles = {}
			local seg_categories = {}
			for _, this_parsed_run in ipairs(seg.alternants) do
				this_parsed_run.loc = seg.loc
				this_parsed_run.num = this_parsed_run.num or seg.num
				this_parsed_run.gender = this_parsed_run.gender or seg.gender
				local this_declensions = decline_segment_run(this_parsed_run, is_adj)
				if not this_declensions.voc then
					declensions.voc = false
				end
				-- If there's a number restriction on the segment run, blank
				-- out the forms outside the restriction. This allows us to
				-- e.g. construct heteroclites that decline one way in the
				-- singular and a different way in the plural.
				if this_parsed_run.num == "sg" or this_parsed_run.num == "pl" then
					for slot in iter_slots(is_adj) do
						if this_parsed_run.num == "sg" and rfind(slot, "pl") or
							this_parsed_run.num == "pl" and rfind(slot, "sg") then
							this_declensions.forms[slot] = {}
							this_declensions.notes[slot] = nil
						end
					end
				end
				if not seg_declensions then
					seg_declensions = this_declensions
				else
					for slot in iter_slots(is_adj) do
						-- For a given slot, combine the existing and new forms.
						-- We do this by checking to see whether a new form is
						-- already present and not adding it if so; in the
						-- process, we keep a map from indices in the new forms
						-- to indices in the combined forms, for use in
						-- combining footnotes below.
						local curforms = seg_declensions.forms[slot] or {}
						local newforms = this_declensions.forms[slot] or {}
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
						seg_declensions.forms[slot] = curforms
						-- Now combine the footnotes. Keep in mind that
						-- each form may have its own set of footnotes, and
						-- in some cases we didn't add a form from the new
						-- list of forms because it already occurred in the
						-- existing list of forms; in that case, we combine
						-- footnotes from the two sources.
						local curnotes = seg_declensions.notes[slot]
						local newnotes = this_declensions.notes[slot]
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
			-- cause the overall set of forms for that slot to be empty.
			propagate_number_restrictions(seg_declensions.forms, parsed_run.num,
				is_adj)

			for slot in iter_slots(is_adj) do
				declensions.forms[slot], declensions.notes[slot] = append_form(
					declensions.forms[slot], declensions.notes[slot],
					seg_declensions.forms[slot], seg_declensions.notes[slot], nil)
			end

			for _, cat in ipairs(seg_categories) do
				ut.insert_if_not(declensions.categories, cat)
			end

			table.insert(declensions.title, table.concat(seg_titles, " or "))

		else
			for slot in iter_slots(is_adj) do
				declensions.forms[slot], declensions.notes[slot] = append_form(
					declensions.forms[slot], declensions.notes[slot],
					seg.prefix)
			end
		end
	end

	return declensions
end

local function construct_title(args_title, declensions_title)
	if args_title then
		declensions_title = "^" .. args_title
		declensions_title = rsub(declensions_title, "<1>", "[[Appendix:Latin first declension|first declension]]")
		declensions_title = rsub(declensions_title, "<1&2>", "[[Appendix:Latin first declension|first]]/[[Appendix:Latin second declension|second declension]]")
		declensions_title = rsub(declensions_title, "<2>", "[[Appendix:Latin second declension|second declension]]")
		declensions_title = rsub(declensions_title, "<3>", "[[Appendix:Latin third declension|third declension]]")
		declensions_title = rsub(declensions_title, "<4>", "[[Appendix:Latin fourth declension|fourth declension]]")
		declensions_title = rsub(declensions_title, "<5>", "[[Appendix:Latin fifth declension|fifth declension]]")
		declensions_title = rsub(declensions_title, "%^(%[%[[^|%]]+|)(.)([^|%]]+%]%])", function(a, b, c)
			return a .. uupper(b) .. c
		end)
		declensions_title = rsub(declensions_title, "%^%[%[(.)([^|%]]+)%]%]", function(a, b, c)
			return "[[" .. a .. b .. "|" .. uupper(a) .. b .. "]]"
		end)
		declensions_title = rsub(declensions_title, "%^(.)", uupper)
	else
		declensions_title = table.concat(declensions_title, "<br/>")
	end

	return declensions_title
end

local function generate_noun_forms(frame)
	local params = {
		[1] = {required = true, default = "aqua<1>"},
		footnote = {},
		title = {},
		num = {},
	}
	for slot in iter_noun_slots() do
		params[slot] = {}
	end

	local parent_args = frame:getParent().args

	local args = m_para.process(parent_args, params)

	local parsed_run = parse_segment_run_allowing_alternants(args[1])
	parsed_run.loc = parsed_run.loc or not not (args.loc_sg or args.loc_pl)
	parsed_run.num = args.num or parsed_run.num

	local declensions = decline_segment_run(parsed_run, false)

	if not parsed_run.loc then
		declensions.forms.loc_sg = nil
		declensions.forms.loc_pl = nil
	end

	declensions.title = construct_title(args.title, declensions.title)

	local all_data = {
		title = declensions.title,
		footnote = args.footnote or "",
		num = parsed_run.num or "",
		forms = declensions.forms,
		categories = declensions.categories,
		notes = {},
		user_specified = {},
		accel = {},
		prefix = "",
		suffix = "",
	}

	for slot in iter_noun_slots() do
		if declensions.notes[slot] then
			for index, notes in pairs(declensions.notes[slot]) do
				all_data.notes[slot .. index] = notes
			end
		end
	end

	process_noun_forms_and_overrides(all_data, args)

	return all_data
end

local function generate_adj_forms(frame)
	local params = {
		[1] = {required = true, default = "bonus"},
		footnote = {},
		title = {},
		num = {},
		noneut = {type = "boolean"},
	}
	for slot in iter_adj_slots() do
		params[slot] = {}
	end

	local parent_args = frame:getParent().args

	local args = m_para.process(parent_args, params)

	local segment_run = args[1]
	if not rfind(segment_run, "[<(]") then
		-- If the segment run doesn't have any explicit declension specs or alternants,
		-- add a default declension spec of <+> to it. This allows the majority of
		-- adjectives to just specify the lemma.
		segment_run = segment_run .. "<+>"
	end
	local parsed_run = parse_segment_run_allowing_alternants(segment_run)
	parsed_run.loc = parsed_run.loc or not not (args.loc_sg or args.loc_pl)
	parsed_run.num = args.num or parsed_run.num

	local declensions = decline_segment_run(parsed_run, true)

	if not parsed_run.loc then
		declensions.forms.loc_sg = nil
		declensions.forms.loc_pl = nil
	end

	declensions.title = construct_title(args.title, declensions.title)

	local all_data = {
		title = declensions.title,
		footnote = args.footnote or "",
		num = parsed_run.num or "",
		forms = declensions.forms,
		categories = declensions.categories,
		notes = {},
		user_specified = {},
		accel = {},
		prefix = "",
		suffix = "",
		voc = declensions.voc,
		noneut = args.noneut,
	}

	for slot in iter_adj_slots() do
		if declensions.notes[slot] then
			for index, notes in pairs(declensions.notes[slot]) do
				all_data.notes[slot .. index] = notes
			end
		end
	end

	process_adj_forms_and_overrides(all_data, args)

	return all_data
end

function export.show_noun(frame)
	local data = generate_noun_forms(frame)

	show_forms(data, false)

	return make_noun_table(data) .. m_utilities.format_categories(data.categories, lang)
end

function export.show_adj(frame)
	local data = generate_adj_forms(frame)

	show_forms(data, true)

	return m_adj_table.make_table(data) .. m_utilities.format_categories(data.categories, lang)
end

function export.generate_noun_forms(frame)
	local data = generate_noun_forms(frame)

	return concat_forms(data, false)
end

function export.generate_adj_forms(frame)
	local data = generate_adj_forms(frame)

	return concat_forms(data, true)
end

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
