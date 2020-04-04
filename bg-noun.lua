local export = {}


--[=[

Authorship: Ben Wing <benwing2>

]=]

--[=[

TERMINOLOGY:

-- "slot" = A particular case/number/definiteness combination. Example slot
	 names are "ind_pl" (indefinite plural), "def_obj_sg" (definite objective
	 singular), "voc_sg" (vocative singular). Each slot is filled with zero or
	 more forms.

-- "form" = The declined Bulgarian form representing the value of a given slot.
	 For example, мо́мко is a form, representing the value of the voc_sg slot of
	 the lemma мо́мък "youth".

-- "lemma" = The dictionary form of a given Bulgarian term. Generally the
	 indefinite singular, but will be the indefinite plural of plurale tantum
	 nouns (e.g. га́щи "pants"), and may occasionally be another form if the
	 indefinite singular is missing.

-- "plurale tantum" (plural "pluralia tantum") = A noun that exists only in
	 the plural. Examples are очила́ "glasses" and три́ци "bran".

-- "singulare tantum" (plural "singularia tantum") = A noun or adjective that
	 exists only in the singular. Examples are ори́з "rice" and Бълга́рия "Bulgaria".
]=]

local lang = require("Module:languages").getByCode("bg")
local m_links = require("Module:links")
local m_table = require("Module:table")
local m_string_utilities = require("Module:string utilities")
local m_para = require("Module:parameters")

local current_title = mw.title.getCurrentTitle()
local NAMESPACE = current_title.nsText
local PAGENAME = current_title.text

local u = mw.ustring.char
local rsplit = mw.text.split
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rgmatch = mw.ustring.gmatch
local rsubn = mw.ustring.gsub
local ulen = mw.ustring.len
local uupper = mw.ustring.upper

local AC = u(0x0301) -- acute =  ́

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

-- version of rsubn() that returns a 2nd argument boolean indicating whether
-- a substitution was made.
local function rsubb(term, foo, bar)
    local retval, nsubs = rsubn(term, foo, bar)
    return retval, nsubs > 0
end


local footnote_abbrevs = {
	["a"] = "archaic",
	["c"] = "colloquial",
	["d"] = "dialectal",
	["fp"] = "folk-poetic",
	["l"] = "literary",
	["lc"] = "low colloquial",
	["p"] = "poetic",
	["pej"] = "pejorative",
	["r"] = "rare",
}


local overriding_forms = {
	["pl"] = true,
	["def"] = true,
	["count"] = true,
	["voc"] = true,
	["acc"] = true,
	["gen"] = true,
	["dat"] = true,
	["accpl"] = true,
	["genpl"] = true,
	["datpl"] = true,
}


local negative_overriding_forms = {
	["-pl"] = true,
	["-def"] = true,
	["-defpl"] = true,
	["-count"] = true,
}


local noun_slots = {
	["ind_sg"] = "indef|s",
	["def_sub_sg"] = "def|sbjv|s",
	["def_obj_sg"] = "def|objv|s",
	["voc_sg"] = "voc|s",
	["acc_sg"] = "acc|s",
	["gen_sg"] = "gen|s",
	["dat_sg"] = "dat|s",
	["voc_pl"] = "voc|p",
	["acc_pl"] = "acc|p",
	["gen_pl"] = "gen|p",
	["dat_pl"] = "dat|p",
	["ind_pl"] = "indef|p",
	["def_pl"] = "def|p",
	["count"] = "count|form",
}

local adj_slots = {
	["ind_m_sg"] = "indef|m|s",
	["def_sub_m_sg"] = "def|sbjv|m|s",
	["def_obj_m_sg"] = "def|objv|m|s",
	["ind_f_sg"] = "indef|f|s",
	["def_f_sg"] = "def|f|s",
	["ind_n_sg"] = "indef|n|s",
	["def_n_sg"] = "def|n|s",
	["ind_pl"] = "indef|p",
	["def_pl"] = "def|p",
	["voc_m_sg"] = "voc|m|s",
}

local potential_noun_lemma_slots = {
	"ind_sg",
	"ind_pl"
}

local potential_adj_lemma_slots = {
	"ind_m_sg",
	"ind_pl"
}

local linked_to_non_linked_noun_slots = {}
for _, slot in ipairs(potential_noun_lemma_slots) do
	linked_to_non_linked_noun_slots["linked_" .. slot] = slot
end

local noun_slots_list = {}
for slot, _ in pairs(noun_slots) do
	table.insert(noun_slots_list, slot)
end

local noun_slots_list_with_linked = {}
for slot, _ in pairs(noun_slots) do
	table.insert(noun_slots_list_with_linked, slot)
end
for slot, _ in pairs(linked_to_non_linked_noun_slots) do
	table.insert(noun_slots_list_with_linked, slot)
end

local linked_to_non_linked_adj_slots = {}
for _, slot in ipairs(potential_adj_lemma_slots) do
	linked_to_non_linked_adj_slots["linked_" .. slot] = slot
end

local adj_slots_list = {}
for slot, _ in pairs(adj_slots) do
	table.insert(adj_slots_list, slot)
end

local adj_slots_list_with_linked = {}
for slot, _ in pairs(adj_slots) do
	table.insert(adj_slots_list_with_linked, slot)
end
for slot, _ in pairs(linked_to_non_linked_adj_slots) do
	table.insert(adj_slots_list_with_linked, slot)
end


local vowel = "аеиоуяюъАЕИОУЯЮЪ"
local vowel_c = "[" .. vowel .. "]"
local non_vowel_c = "[^" .. vowel .. "]"
local cons = "бцдфгчйклмнпрствшхзжьщБЦДФГЧЙКЛМНПРСТВШХЗЖЬЩ"
local cons_c = "[" .. cons .. "]"


local second_palatalization = {
	["к"] = "ц",
	["г"] = "з",
	["х"] = "с",
}


-- Check if word is monosyllabic (also includes words without vowels).
local function is_monosyllabic(word)
	local num_syl = ulen(rsub(word, non_vowel_c, ""))
	return num_syl <= 1
end


-- If word is monosyllabic, add stress to the vowel.
local function add_monosyllabic_stress(word)
	if is_monosyllabic(word) and not rfind(word, AC) then
		word = rsub(word, "(" .. vowel_c .. ")", "%1" .. AC)
	end
	return word
end


-- If word is unstressed, add stress onto initial syllable.
local function maybe_stress_initial_syllable(word)
	if not rfind(word, AC) then
		-- stress first syllable
		word = rsub(word, "^(.-" .. vowel_c .. ")", "%1" .. AC)
	end
	return word
end


-- If word is unstressed, add stress onto final syllable.
local function maybe_stress_final_syllable(word)
	if not rfind(word, AC) then
		-- stress last syllable
		word = rsub(word, "(.*" .. vowel_c .. ")", "%1" .. AC)
	end
	return word
end


-- Given a list of forms (each of which is a table of the form {form=FORM, footnotes=FOOTNOTES}),
-- concatenate into a SLOT=FORM,FORM,... string, replacing embedded | signs with <!>.
local function concat_forms_in_slot(forms)
	if forms then
		local new_vals = {}
		for _, v in ipairs(forms) do
			table.insert(new_vals, rsub(v.form, "|", "<!>"))
		end
		return table.concat(new_vals, ",")
	else
		return nil
	end
end


-- Add a tracking category to the page.
local function track(page)
	require("Module:debug").track("bg-nominal/" .. page)
	return true
end


-- Parse a string containing matched instances of parens, brackets or the like.
-- Return a list of strings, alternating between textual runs not containing the
-- open/close characters and runs beginning and ending with the open/close
-- characters. For example,
--
-- parse_balanced_segment_run("foo(x(1)), bar(2)", "(", ")") = {"foo", "(x(1))", ", bar", "(2)", ""}.
local function parse_balanced_segment_run(segment_run, open, close)
	local break_on_open_close = m_string_utilities.capturing_split(segment_run, "([%" .. open .. "%" .. close .. "])")
	local text_and_specs = {}
	local level = 0
	local seg_group = {}
	for i, seg in ipairs(break_on_open_close) do
		if i % 2 == 0 then
			if seg == open then
				table.insert(seg_group, seg)
				level = level + 1
			else
				assert(seg == close)
				table.insert(seg_group, seg)
				level = level - 1
				if level < 0 then
					error("Unmatched " .. close .. " sign: '" .. segment_run .. "'")
				elseif level == 0 then
					table.insert(text_and_specs, table.concat(seg_group))
					seg_group = {}
				end
			end
		elseif level > 0 then
			table.insert(seg_group, seg)
		else
			table.insert(text_and_specs, seg)
		end
	end
	if level > 0 then
		error("Unmatched " .. open .. " sign: '" .. segment_run .. "'")
	end
	return text_and_specs
end


-- Split a list of alternating textual runs of the format returned by
-- `parse_balanced_segment_run` on `splitchar`. This only splits the odd-numbered
-- textual runs (the portions between the balanced open/close characters).
-- The return value is a list of lists, where each list contains an odd number of
-- elements, where the even-numbered elements of the sublists are the original
-- balanced textual run portions. For example, if we do
--
-- parse_balanced_segment_run("foo[x[1]][2]/baz:bar[3]", "[", "]") =
--   {"foo", "[x[1]]", "", "[2]", "/baz:bar", "[3]", ""}
--
-- then
--
-- split_alternating_runs({"foo", "[x[1]]", "", "[2]", "/baz:bar", "[3]", ""}, ":") =
--   {{"foo", "[x[1]]", "", "[2]", "/baz"}, {"bar", "[2]", ""}}
--
-- Note that each element of the outer list is of the same form as the input,
-- consisting of alternating textual runs where the even-numbered segments
-- are balanced runs, and can in turn be passed to split_alternating_runs().
local function split_alternating_runs(segment_runs, splitchar)
	local grouped_runs = {}
	local run = {}
	for i, seg in ipairs(segment_runs) do
		if i % 2 == 0 then
			table.insert(run, seg)
		else
			local parts = rsplit(seg, splitchar, true)
			table.insert(run, parts[1])
			for j=2,#parts do
				table.insert(grouped_runs, run)
				run = {parts[j]}
			end
		end
	end
	if #run > 0 then
		table.insert(grouped_runs, run)
	end
	return grouped_runs
end


-- Given an alternating run of the format returned by `parse_balanced_segment_run`,
-- where the even-numbered segments are footnotes and the whole run describes
-- a noun accent spec (e.g. "ad(v)+ове++и[a]" split as {"ad(v)+ове++и", "[a]", ""}),
-- parse the accent spec and return an object describing this spec. The returned
-- object is e.g. (for the above spec)
--
-- {
--   accents = {"a", "d"},
--   plurals = {{plural = "ове"}, {plural = "и", double_plus = true, footnotes = {"[a]"}}},
--   vocative = true,
-- }
--
-- Other possible fields of the object:
--
-- gender = STRING (either "m", "f" or "n")
-- reducible = BOOLEAN
-- reducible_vocative = BOOLEAN
-- reducible_count = BOOLEAN
-- reducible_definite = BOOLEAN
-- soft_sign = BOOLEAN
-- no_sign_sign = BOOLEAN
-- remove_in = BOOLEAN
-- ur = BOOLEAN
local function parse_noun_accent_spec(accent_run)
	local retval = {accents = {}, plurals = {}}
	local plurals = {}
	local plural_groups = split_alternating_runs(accent_run, "+")
	local double_plus = false
	for i, plural_group in ipairs(plural_groups) do
		if i > 1 then
			if #plural_group == 1 and plural_group[1] == "" then
				if double_plus then
					error("Too many plus signs: '" .. table.concat(accent_spec) .. "'")
				else
					double_plus = true
				end
			else
				local plural = {plural = plural_group[1], double_plus = double_plus}
				double_plus = false
				for j = 2, #plural_group - 1, 2 do
					if plural_group[j + 1] ~= "" then
						error("Extraneous text after bracketed footnotes: '" .. table.concat(plural_group) .. "'")
					end
					if not plural.footnotes then
						plural.footnotes = {}
					end
					table.insert(plural.footnotes, plural_group[j])
				end
				table.insert(retval.plurals, plural)
			end
		elseif #plural_group ~= 1 then
			error("Bracketed footnotes only allowed after plurals: '" .. table.concat(plural_group) .. "'")
		else
			local accents, rest = plural_group[1]:match("^([abcd]*)(.-)$")
			for accent in accents:gmatch(".") do
				table.insert(retval.accents, accent)
			end
			rest, retval.reducible_vocative = rsubb(rest, "%(v%*%)", "")
			rest, retval.reducible_count = rsubb(rest, "%(c%*%)", "")
			rest, retval.reducible_definite = rsubb(rest, "%(d%*%)", "")
			rest, retval.reducible = rsubb(rest, "%*", "")
			rest, retval.vocative = rsubb(rest, "%(v%)", "")
			rest, retval.soft_sign = rsubb(rest, "%(ь%)", "")
			rest, retval.no_soft_sign = rsubb(rest, "%(%-ь%)", "")
			if retval.soft_sign and retval.no_soft_sign then
				error("Conflicting specs: Can't specify both (ь) and (-ь)")
			end
			rest, retval.remove_in = rsubb(rest, "%(ин%)", "")
			rest, retval.ur = rsubb(rest, "%(ър%)", "")
			rest, retval.ya = rsubb(rest, "%(я%)", "")
			rest, retval.no_ya = rsubb(rest, "%(%-я%)", "")
			if retval.ya and retval.no_ya then
				error("Conflicting specs: Can't specify both (я) and (-я)")
			end
			local masc, fem, neut, g
			rest, masc = rsubb(rest, "%(m%)", "")
			if masc then
				g = "m"
			end
			rest, fem = rsubb(rest, "%(f%)", "")
			if fem then
				if g then
					error("Conflicting gender specs: Can't specify both (m) and (f)")
				end
				g = "f"
			end
			rest, neut = rsubb(rest, "%(n%)", "")
			if neut then
				if g then
					error("Conflicting gender specs: Can't specify both (" .. g .. ") and (n)")
				end
				g = "n"
			end
			retval.gender = g
			if rest ~= "" then
				error("Unrecognized indicator: '" .. rest .. "'")
			end
		end
	end
	return retval
end


-- Given the text of an adjective accent spec (e.g. "b*(я)"), parse the accent spec and return
-- an object describing this spec. The returned object is e.g. (for the above spec)
--
-- {
--   accents = {"b"},
--   reducible = true,
--   ya = true,
-- }
--
-- Other possible fields of the object:
--
-- soft_sign = BOOLEAN
-- ch = BOOLEAN
local function parse_adj_accent_spec(text)
	local retval = {accents = {}}
	local accents, rest = text:match("^([ab]*)(.-)$")
	for accent in accents:gmatch(".") do
		table.insert(retval.accents, accent)
	end
	rest, retval.reducible = rsubb(rest, "%*", "")
	rest, retval.soft_sign = rsubb(rest, "%(ь%)", "")
	rest, retval.ch = rsubb(rest, "%(ч%)", "")
	rest, retval.ur = rsubb(rest, "%(ър%)", "")
	rest, retval.ya = rsubb(rest, "%(я%)", "")
	if rest ~= "" then
		error("Unrecognized indicator: '" .. rest .. "'")
	end
	return retval
end


-- Given an alternating run of the format returned by `parse_balanced_segment_run`,
-- where the even-numbered segments are footnotes and the whole run describes
-- a form spec (e.g. "pl:+:мо́мце:момци́[a][collective]" split as
-- {"pl:+:мо́мце:момци́", "[a]", "", "[collective]", ""}), parse the form spec and return
-- two values, e.g. (for the above spec)
--
-- "pl", {{value = "+"}, {value = "мо́мце"}, {value = "момци́", footnotes = {"[a]", "[collective]"}}}
--
-- As special cases, if the form name is "n", the second value will be a string, one of
-- "sg", "pl" or "both", and if the form name is in `negative_overriding_forms`, the second value
-- will be `true`. Only "n" and the values in `overriding_forms` and `negative_overriding_forms`
-- are recognized as form names.
local function parse_form_spec(form_run)
	local colon_separated_groups = split_alternating_runs(form_run, ":")
	local form_name_group = colon_separated_groups[1]
	if #form_name_group ~= 1 then
		error("Bracketed footnotes not allowed after form name: '" .. table.concat(form_name_group) .. "'")
	end
	local form_name = form_name_group[1]
	if form_name == "n" then
		if #colon_separated_groups == 2 and #colon_separated_groups[2] == 1 then
			local number = colon_separated_groups[2][1]
			if number == "sg" or number == "pl" or number == "both" then
				return "n", number
			end
		end
		error("Number spec should be 'n:sg', 'n:pl' or 'n:both': '" .. table.concat(form_run))
	elseif negative_overriding_forms[form_name] then
		if #colon_separated_groups > 1 then
			error("Cannot specify a value for negative spec '" .. form_name .. "'")
		end
		return form_name, true
	elseif overriding_forms[form_name] then
		local forms = {}
		for i, colon_separated_group in ipairs(colon_separated_groups) do
			if i > 1 then
				local form = {value = colon_separated_group[1]}
				for j = 2, #colon_separated_group - 1, 2 do
					if colon_separated_group[j + 1] ~= "" then
						error("Extraneous text after bracketed footnotes: '" .. table.concat(colon_separated_group) .. "'")
					end
					if not form.footnotes then
						form.footnotes = {}
					end
					table.insert(form.footnotes, colon_separated_group[j])
				end
				table.insert(forms, form)
			end
		end
		return form_name, forms
	else
		error("Unrecognized form name: '" .. form_name .. "'")
	end
end


-- Given an angle-bracket spec (the entire spec following a word, including the angle brackets),
-- parse the accent and form specs inside the angle brackets. The return value is a list of
-- accent-and-form specs, where each such spec is an object with a field 'accent_spec' in the
-- format returned by parse_noun_accent_spec(), plus zero or more fields describing forms, where the
-- field name is the form name and the value is the second return value of parse_form_spec().
-- For example, given "<a*+ове+а[d],/pl:момци́[a][collective]>", the return value will be
-- 
-- {
--   {
--     accent_spec = {
--       accents = {"a"},
--       reducible = true,
--       plurals = {{plural = "ове"}, {plural = "а", footnotes = {"[d]"}}},
--     }
--   },
--   {
--     accent_spec = {
--       accents = {},
--       plurals = {},
--     },
--     pl = {{value = "момци́", footnotes = {"[a]", "[collective]"}}},
--   },
-- }
local function parse_accent_and_form_specs(angle_bracket_spec)
	local inside = rmatch(angle_bracket_spec, "^<(.*)>$")
	assert(inside)
	local bracketed_runs = parse_balanced_segment_run(inside, "[", "]")
	local comma_separated_groups = split_alternating_runs(bracketed_runs, ",")
	local accent_and_form_specs = {}
	for _, comma_separated_group in ipairs(comma_separated_groups) do
		local accent_and_form_spec = {}
		local slash_separated_groups = split_alternating_runs(comma_separated_group, "/")
		accent_and_form_spec.accent_spec = parse_noun_accent_spec(slash_separated_groups[1])
		for i, slash_separated_group in ipairs(slash_separated_groups) do
			if i > 1 then
				local form_name, forms = parse_form_spec(slash_separated_group)
				if accent_and_form_spec[form_name] then
					error("Cannot specify '" .. form_name .. "' twice")
				end
				accent_and_form_spec[form_name] = forms
			end
		end
		if accent_and_form_spec["count"] and accent_and_form_spec["-count"] then
			error("Can't specify both 'count' and '-count'")
		end
		if accent_and_form_spec["def"] and accent_and_form_spec["-def"] then
			error("Can't specify both 'def' and '-def'")
		end
		table.insert(accent_and_form_specs, accent_and_form_spec)
	end
	return accent_and_form_specs
end


-- Parse a "simplified" specification that consists of a single word followed by an
-- accent-and-form spec in angle brackets. SEGMENTS is a list of strings (textual runs),
-- as returned by parse_balanced_segment_run(text, "<", ">"). The return value is an
-- object of the form
--
-- {
--   word = "WORD",
--   accent_and_form_specs = return value of parse_accent_and_form_specs(),
--   forms = {},
--   footnote = "",
-- }
--
-- Eventually the format should be changed to allow for multiple words.
local function parse_simplified_specification(segments)
	local dataspec = {}
	if #segments ~= 3 or segments[3] ~= "" then
		error("Can't currently parse: '" .. table.concat(segments) .. "'")
	end
	if segments[1] == "" then
		error("Word is blank: '" .. table.concat(segments) .. "'")
	end
	dataspec.word = segments[1]
	dataspec.accent_and_form_specs = parse_accent_and_form_specs(segments[2])
	dataspec.forms = {}
	return dataspec
end


-- Parse an alternant, e.g. "((мо́лив<>,моли́в<>))". The return value is a table of the form
-- {
--   alternants = {DATASPEC, DATASPEC, ...}
-- }
--
-- where DATASPEC describes a given alternant and is as returned by parse_simplified_specification().
local function parse_alternant(alternant)
	local parsed_alternants = {}
	local alternant_spec = rmatch(alternant, "^%(%((.*)%)%)$")
	local segments = parse_balanced_segment_run(alternant_spec, "<", ">")
	local comma_separated_groups = split_alternating_runs(segments, ",")
	local alternant_dataspec = {alternants = {}}
	for _, comma_separated_group in ipairs(comma_separated_groups) do
		table.insert(alternant_dataspec.alternants, parse_simplified_specification(comma_separated_group))
end
	return alternant_dataspec
end


-- Parse a "simplified" specification that consists of a either a single word followed by an
-- accent-and-form spec in angle brackets, or an alternant specification such as
-- "((мо́лив<>,моли́в<>))". The return value is a table of the form
-- {
--   alternants = {DATASPEC, DATASPEC, ...}
-- }
--
-- where DATASPEC describes a given alternant and is as returned by parse_simplified_specification().
-- If the text passed in does not consist of an alternant specification, there will be only
-- one element in the `alternants` list.
local function parse_simplified_specification_allowing_alternants(text)
	if rfind(text, "^%(%(.*%)%)$") then
		return parse_alternant(text)
	else
		local segments = parse_balanced_segment_run(text, "<", ">")
		return {alternants = {parse_simplified_specification(segments)}}
	end
end


-- Construct the "reduced" version of a stem. This removes an е or ъ followed by a word-final
-- consonant, stresses the final syllable of the result if necessary, and converts бое́ц into бо́йц- and бо́як into бо́йк-.
-- An error is thrown if the stem can't be reduced.
local function reduce_stem(stem)
	local vowel_ending_stem, final_cons = rmatch(stem, "^(.*" .. vowel_c .. AC .. "?)[ея]́?(" .. cons_c .. ")$")
	if vowel_ending_stem then
		-- бое́ц etc.
		return maybe_stress_final_syllable(vowel_ending_stem .. "й" .. final_cons)
	end
	local initial_stem, final_cons = rmatch(stem, "^(.*)[еъ]́?(" .. cons_c .. ")$")
	if initial_stem then
		return maybe_stress_final_syllable(initial_stem .. final_cons)
	end
	error("Unable to reduce stem: '" .. stem .. "'")
end


-- Return the stem of a given noun. This removes any endings -а/-я/-е/-о/-й, and if
-- the result lacks an accent, it is added onto the last syllable.
local function get_noun_stem(word)
	local stem
	stem = rmatch(word, "^(.*)[аеоя]́?$")
	if stem then
		return maybe_stress_final_syllable(stem)
	end
	stem = rmatch(word, "^(%u.*)и́?$")
	if stem then
		-- proper names like До́бри
		return maybe_stress_final_syllable(stem)
	end
	stem = rmatch(word, "^(.*)й$")
	if stem then
		return stem
	end
	return word
end


-- Return the stem of a given adjective. This does the following:
-- (1) removes an ending -и, and if the result lacks an accent, it is added onto the last syllable;
-- (2) if (ър) was given, converts -ъ́р- to -ръ́- and vice-versa;
-- (3) if (я) was given, converts -е́- to -я́-;
-- (4) reduces the stem if appropriate.
local function get_adj_stem(word, accent_spec)
	local stem = word
	stem = rmatch(stem, "^(.*)и́?$")
	if stem then
		stem = maybe_stress_final_syllable(stem)
	end
	if accent_spec.ur then
		if rfind(stem, "ъ́р") then
			stem = rsub(stem, "ъ́р", "ръ́")
		elseif rfind(stem, "ръ́") then
			stem = rsub(stem, "ръ́", "ъ́р")
		then
			error("Indicator (ър) specified but stem doesn't contain -ъ́р- or -ръ́-")
		end
	elseif accent_spec.ya then
		if rfind(stem, "е́") then
			stem = rsub(stem, "е́", "я́")
		elseif not rfind(stem, "я́") then
			error("Indicator (я) specified but stem doesn't contain -я́- or -е́-")
		end
	end
	if accent_spec.reducible then
		return reduce_stem(stem)
	else
		return stem
	end
end


-- Construct all the stems needed for declining a noun. This does the following:
-- (1) adds stress to a monosyllabic word if needed;
-- (2) throws an error if a multisyllabic word is given without any stress;
-- (3) constructs the stem using get_noun_stem();
-- (4) constructs the reduced stem using reduce_stem(), if needed.
-- We don't construct the reduced stem unless the user gave a reduction spec somewhere;
-- otherwise we'll get an error on non-reducible stems.
local function construct_noun_stems(alternant_dataspec)
	for _, dataspec in ipairs(alternant_dataspec.alternants) do
		dataspec.word = add_monosyllabic_stress(dataspec.word)
		if not rfind(dataspec.word, AC) then
			error("Multisyllabic word '" .. dataspec.word .. "' needs an accent")
		end
		dataspec.stem = get_noun_stem(dataspec.word)
		local needs_reduced_stem = false
		for _, accent_and_form_spec in ipairs(dataspec.accent_and_form_specs) do
			local accent_spec = accent_and_form_spec.accent_spec
			if accent_spec.reducible or accent_spec.reducible_definite or accent_spec.reducible_count or
				accent_spec.reducible_vocative then
				needs_reduced_stem = true
				break
			end
		end
		if needs_reduced_stem then
			dataspec.reduced_stem = reduce_stem(dataspec.stem)
		end
	end
end


-- Construct all the stems needed for declining an adjective. This does the following:
-- (1) adds stress to a monosyllabic word if needed;
-- (2) throws an error if a multisyllabic word is given without any stress;
-- (3) constructs the stem of each accent_spec using get_adj_stem().
local function construct_adj_stems(alternant_dataspec)
	for _, dataspec in ipairs(alternant_dataspec.alternants) do
		dataspec.word = add_monosyllabic_stress(dataspec.word)
		if not rfind(dataspec.word, AC) then
			error("Multisyllabic word '" .. dataspec.word .. "' needs an accent")
		end
		for _, accent_and_form_spec in ipairs(dataspec.accent_and_form_specs) do
			local accent_spec = accent_and_form_spec.accent_spec
			accent_spec.stem = get_adj_stem(dataspec.word, accent_spec)
		end
	end
end


-- Concatenate a stem and an ending. If the ending has an accent, any accent on the stem is removed.
-- If UR is specified, convert the sequence CръC to CърC, preserving any accent on -ъ-.
local function combine_stem_and_ending(stem, ending, accent_spec, is_adj)
	if not is_adj and accent_spec.ur and rfind(ending, "^" .. vowel_c) then
		stem = rsub(stem, "(" .. cons_c .. ")ръ(" .. AC .. "?)(" .. cons_c .. ")", "%1ъ%2р%3")
	end
	if not accent_spec.no_ya and (rfind(ending, AC) or (accent_spec.ya and rfind(ending, "^[еиь]"))) then
		stem = rsub(stem, "я́", "е́")
	end
	if rfind(ending, AC) then
		stem = rsub(stem, AC, "")
	end
	return stem .. ending
end


-- Given a noun and an accent-and-form spec (an element of the list returned by parse_accent_and_form_specs()),
-- do any autodetection of gender, accent and indicators. This modifies the accent-and-form spec in place.
local function detect_noun_accent_and_form_spec(word, accent_and_form_spec)
	local accent_spec = accent_and_form_spec.accent_spec
	-- Detect gender if not specified.
	local g = accent_spec.gender
	if not g then
		if rfind(word, "[ая]́?$") then
			g = "f"
		elseif rfind(word, "^%u.*и́?$") then
			-- proper names like До́бри
			g = "m"
		elseif rfind(word, "[еиоую]́?$") then
			g = "n"
		else
			g = "m"
		end
		accent_spec.gender = g
	end
	-- Detect accent if not specified.
	if #accent_spec.accents == 0 then
		local accent
		if g == "f" and rfind(word, cons_c .. "$") then
			accent = "d"
		elseif accent_spec.reducible and rfind(word, "[ъе]́" .. cons_c .. "$") then
			-- Reducible noun and accent on reducible vowel, e.g. чуждене́ц -> чужденци́
			accent = "c"
		elseif rfind(word, "[еоая]́$") then
			accent = "c"
		else
			accent = "a"
		end
		table.insert(accent_spec.accents, accent)
	end
	-- Detect soft-sign indicator.
	if g == "m" and not accent_spec.no_soft_sign and (
		rfind(word, "й$") or rfind(word, vowel_c .. AC .. "?тел$") or rfind(word, vowel_c .. AC .. "?" .. cons_c .. "ар$")
	) then
		accent_spec.soft_sign = true
	end
	-- Detect plural if not specified.
	if #accent_spec.plurals == 0 then
		local plural
		if g == "f" then
			plural = "и"
		elseif g == "m" then
			if rfind(word, "^%u") then
				if rfind(word, "[ияй]́?$") then
					-- До́бри, Или́я, Благо́й
					plural = "евци"
				elseif rfind(word, "[ое]́?в$") then
					-- Ива́нов/Ивано́в, Пе́нчев
					plural = {"и", "ци"}
				else
					-- Пе́тър, Ива́н, Кру́м, Нико́ла
					plural = "овци"
				end
			elseif rfind(word, "о́?$") or rfind(word, "а́н$") then
				-- дя́до, гле́зльо; готова́н
				plural = "овци"
			elseif rfind(word, "е́?$") then
				-- аташе́
				plural = "ета"
			elseif not is_monosyllabic(word) then
				-- ези́к, друга́р, геро́й, etc.; баща́, коле́га
				plural = "и"
			elseif rfind(word, "й$") then
				-- край, брой
				plural = "еве"
			elseif accent_spec.soft_sign then
				-- кон, зет, цар
				plural = "ьове"
			else
				plural = "ове"
			end
		elseif rfind(word, "о́?$") or rfind(word, "[щц]е́?$") then
			plural = "а"
		elseif rfind(word, "и́?е$") then
			plural = "я"
		elseif rfind(word, "е́?$") then
			plural = "ета"
		else
			plural = "та"
		end
		if type(plural) == "table" then
			for _, p in ipairs(plural) do
				table.insert(accent_spec.plurals, {plural=p})
			end
		else
			table.insert(accent_spec.plurals, {plural=plural})
		end
	end
	-- Detect vocative indicators.
	if accent_spec.reducible_vocative or accent_and_form_spec.voc then
		accent_spec.vocative = true
	end
	-- Detect reducible indicators.
	if g == "m" and rfind(word, vowel_c .. AC .. "?зъм$") then
		accent_spec.reducible = true
		accent_spec.reducible_definite = true
		if accent_spec.vocative then
			accent_spec.reducible_vocative = true
		end
	end
	-- Detect no-def-sg indicators.
	if rfind(word, "^%u") and not accent_and_form_spec.def then
		accent_and_form_spec["-def"] = true
	end
end


-- Given an adjective and an accent-and-form spec (an element of the list returned by parse_accent_and_form_specs()),
-- do any autodetection of gender, accent and indicators. This modifies the accent-and-form spec in place.
local function detect_adj_accent_and_form_spec(word, accent_and_form_spec)
	-- Detect accent if not specified.
	if #accent_spec.accents == 0 then
		local accent
		if rfind(word, "и́$") then
			accent = "b"
		elseif accent_spec.reducible and rfind(word, "[ъяе]́" .. cons_c .. "$") then
			-- Reducible adjective and accent on reducible vowel, e.g. добъ́р -> fem добра́
			accent = "b"
		else
			accent = "a"
		end
		table.insert(accent_spec.accents, accent)
	end
	-- Detect soft-sign indicator.
	local accent_spec = accent_and_form_spec.accent_spec
	if rfind(word, "и́?$") and accent_spec.soft_sign then
		accent_spec.soft_sign_i = true
	end
end


-- Call detect_noun_accent_and_form_spec() on all accent-and-form specs in ALTERNANT_DATASPEC.
-- In the process, set ALTERNANT_DATASPEC.n to the overall number ("sg", "pl" or "both") of
-- the word or alternant.
local function detect_all_noun_accent_and_form_specs(alternant_dataspec)
	local n -- overall number spec
	for _, dataspec in ipairs(alternant_dataspec.alternants) do
		for _, accent_and_form_spec in ipairs(dataspec.accent_and_form_specs) do
			detect_accent_and_form_spec(dataspec.word, accent_and_form_spec)
			local specn = accent_and_form_spec.n
			if specn then
				if n == specn then
					-- do nothing
				elseif not n then
					n = specn
				else
					n = "both"
				end
			end
		end
	end
	alternant_dataspec.n = n
end


-- Call detect_adj_accent_and_form_spec() on all accent-and-form specs in ALTERNANT_DATASPEC.
local function detect_all_adj_accent_and_form_specs(alternant_dataspec)
	for _, dataspec in ipairs(alternant_dataspec.alternants) do
		for _, accent_and_form_spec in ipairs(dataspec.accent_and_form_specs) do
			detect_adj_accent_and_form_spec(dataspec.word, accent_and_form_spec)
		end
	end
end


-- Insert a form (an object of the form {form=FORM, footnotes=FOOTNOTES}) into a list of such
-- forms. If the form is already present, the footnotes of the existing and new form are combined.
local function insert_form_into_list(list, form)
	-- Don't do anything if the form object or the form inside it is nil. This simplifies
	-- form insertion in the presence of declension generating functions that may return nil,
	-- such as generate_noun_vocative() and generate_noun_count_form().
	if not form or not form.form then
		return
	end
	for _, listform in ipairs(list) do
		if listform.form == form.form then
			-- Form already present; combine footnotes.
			if form.footnotes and #form.footnotes > 0 then
				if not listform.footnotes then
					listform.footnotes = {}
				end
				for _, footnote in ipairs(form.footnotes) do
					m_table.insertIfNot(listform.footnotes, footnote)
				end
			end
			return
		end
	end
	-- Form not found. Do a shallow copy of the footnotes because we may modify them in-place.
	table.insert(list, {form=form.form, footnotes=m_table.shallowcopy(form.footnotes)})
end


-- Insert a form (an object of the form {form=FORM, footnotes=FOOTNOTES}) into the given slot in
-- the given form table.
local function insert_form(formtable, slot, form)
	-- Don't do anything if the form object or the form inside it is nil. This simplifies
	-- form insertion in the presence of declension generating functions that may return nil,
	-- such as generate_noun_vocative() and generate_noun_count_form().
	if not form or not form.form then
		return
	end
	if not formtable[slot] then
		formtable[slot] = {}
	end
	insert_form_into_list(formtable[slot], form)
end


-- Insert a list of forms (each of which is an object of the form {form=FORM, footnotes=FOOTNOTES})
-- into the given slot in the given form table. FORMS can be nil.
local function insert_forms(formtable, slot, forms)
	if not forms then
		return
	end
	for _, form in ipairs(forms) do
		insert_form(formtable, slot, form)
	end
end


-- Map a function over the form values in FORMS (a list of objects of the form
-- {form=FORM, footnotes=FOOTNOTES}). Use insert_form_into_list() to insert them into
-- the returned list in case two different forms map to the same thing.
local function map_forms(forms, fun)
	if not forms then
		return nil
	end
	local retval = {}
	for _, form in ipairs(forms) do
		local newform = {form=fun(form.form), footnotes=form.footnotes}
		insert_form_into_list(retval, newform)
	end
	return retval
end


-- Construct the plural of the word specified in DATASPEC, given the accent spec
-- (as returned by parse_noun_accent_spec()), the plural ending (e.g. "ове"), and the accent indicator
-- (e.g. "a" or "d"). Return value is a string. This handles accenting the plural ending as necessary,
-- fetching the reduced stem if appropriate, removing final -ин if called for, and applying the
-- second palatalization if appropriate (e.g. ези́к -> ези́ци).
local function generate_noun_plural(dataspec, accent_spec, plural, accent)
	local ending = plural.plural
	if accent == "b" or accent == "c" then
		if accent == "b" and (ending == "ове" or ending == "ьове" or ending == "йове" or ending == "еве") or
			ending == "еса" or ending == "ена" then
			ending = ending .. AC
		else
			-- for any other plurals, put the stress on the first vowel if a stress isn't already present
			ending = maybe_stress_initial_syllable(ending)
		end
	end

	local stem = accent_spec.reducible and dataspec.reduced_stem or dataspec.stem
	
	if accent_spec.remove_in then
		local new_stem, removed = rsubb(stem, "и́?н$", "")
		if not removed then
			error("(ин) specified but stem '" .. stem .. "' doesn't end in -ин")
		end
		stem = maybe_stress_final_syllable(new_stem)
	end

	if not plural.double_plus and not rfind(dataspec.word, "нг$") and (
		-- ези́к -> ези́ци
		rfind(ending, "^и́?$") and rfind(dataspec.word, "[кгх]$") or
		-- ръка́ -> ръце́
		rfind(ending, "^е́?$") and rfind(dataspec.word, "[кгх]а́?$")
	) then
		local initial, last_cons = rmatch(stem, "^(.*)([кгх])$")
		if initial then
			return combine_stem_and_ending(initial .. second_palatalization[last_cons], ending, accent_spec)
		end
	end

	return combine_stem_and_ending(stem, ending, accent_spec)
end


-- Construct the definite singular of the word specified in DATASPEC, given the accent spec
-- (as returned by parse_noun_accent_spec()) and the accent indicator (e.g. "a" or "d").
-- Return value is a string. This handles determining the appropriate ending (handling the
-- soft sign spec (ь) as needed), accenting the ending as necessary, and fetching the
-- reduced stem if appropriate.
local function generate_noun_definite_singular(dataspec, accent_spec, accent)
	local function stressed_ending()
		return accent == "b" or accent == "d"
	end
	if accent_spec.gender == "m" then
		if rfind(dataspec.word, "[ая]́?$") then
			return dataspec.word .. "та"
		elseif rfind(dataspec.word, "[ео]́?$") then
			return dataspec.word .. "то"
		else
			local ending
			if accent_spec.soft_sign then
				ending = stressed_ending() and "я́т" or "ят"
			elseif stressed_ending() then
				ending = "ъ́т"
			else
				ending = "ът"
			end
			local stem = accent_spec.reducible_definite and dataspec.reduced_stem or dataspec.stem
			return combine_stem_and_ending(stem, ending, accent_spec)
		end
	elseif accent_spec.gender == "f" then
		return combine_stem_and_ending(dataspec.word, stressed_ending() and "та́" or "та", accent_spec)
	else
		return combine_stem_and_ending(dataspec.word, "то", accent_spec)
	end
end
	

-- Construct the definite objective singular given the definite subjective singular form.
local function generate_noun_definite_objective_singular(def_sg)
	local stem, ending = rmatch(def_sg, "^(.*)(ъ́?т)$") 
	if stem then
		return stem .. (ending == "ъ́т" and "а́" or "а")
	end
	stem = rmatch(def_sg, "^(.*я́?)т$") 
	if stem then
		return stem
	end
	if rfind(def_sg, "т[ао]́?$") then
		return def_sg
	end
	error("Unrecognized ending for definite subjective singular: '" .. def_sg .. "'")
end


-- Construct the definite plural given the indefinite plural form.
local function generate_noun_definite_plural(plural_form)
	if rfind(plural_form, "[еи]́?$") then
		return plural_form .. "те"
	else
		return plural_form .. "та"
	end
end


-- Construct the count form of the word specified in DATASPEC, given the accent spec
-- (as returned by parse_noun_accent_spec()). Return value is a string, or nil if no count
-- form can be constructed (not a masculine word ending in a consonant). This handles
-- determining the appropriate ending (handling the soft sign spec (ь) as needed) and
-- fetching the reduced stem if appropriate.
local function generate_noun_count_form(dataspec, accent_spec)
	if accent_spec.gender ~= "m" or not rfind(dataspec.word, cons_c .. "$") then
		return nil
	end
	local stem = accent_spec.reducible_count and dataspec.reduced_stem or dataspec.stem
	if accent_spec.soft_sign then
		return combine_stem_and_ending(stem, "я", accent_spec)
	else
		return combine_stem_and_ending(stem, "а", accent_spec)
	end
end


-- Construct the vocative of the word specified in DATASPEC, given the accent spec
-- (as returned by parse_noun_accent_spec()). Return value is a string, or nil if no vocative
-- form can be constructed. This applies the rules described in [[w:Bulgarian nouns]].
local function generate_noun_vocative(dataspec, accent_spec)
	if accent_spec.gender == "n" or not accent_spec.vocative then
		return nil
	end
	local word = dataspec.word
	if accent_spec.gender == "f" and rfind(word, cons_c .. "$") then
		return nil
	end
	local stem = accent_spec.reducible_vocative and dataspec.reduced_stem or dataspec.stem
	local ending
	if accent_spec.soft_sign then
		ending = "ю"
	elseif rfind(word, vowel_c .. AC .. "?я́?$") then
		ending = "йо"
	elseif rfind(word, "я́?$") then
		ending = "ьо"
	elseif rfind(word, "ца́?$") or rfind(word, "[рч]ка́?$") or rfind(word, "^%u.*ка́?$") then
		ending = "е"
	elseif rfind(word, "а́?$") or rfind(word, "[кчц]$") or rfind(word, "и́?н$") then
		ending = "о"
	elseif rfind(word, "[гз]$") then
		return combine_stem_and_ending(rsub(stem, "[гз]$", "ж"), "е", accent_spec)
	else
		ending = "е"
	end
	return combine_stem_and_ending(stem, ending, accent_spec)
end


-- Construct the indefinite adjective forms as well as the definite subjective masculine
-- singular.
local function generate_adj_forms(formtable, accent_spec, accent)
	local stem = accent_spec.stem
	local accent = accent == "b" and AC or ""
	insert_form(formtable, "def_sub_m_sg",
		{form=combine_stem_and_ending(stem, "и" .. accent .. "ят", accent_spec, "is adj")})
	insert_form(formtable, "ind_f_sg",
		{form=combine_stem_and_ending(stem, (accent_spec.soft_sign and "я" or "а") .. accent, accent_spec)})
	if accent_spec.ch then
		insert_form(formtable, "ind_n_sg",
			{form=combine_stem_and_ending(stem, "е" .. accent, accent_spec, "is adj")})
		insert_form(formtable, "ind_n_sg",
			{form=combine_stem_and_ending(stem, "о" .. accent, accent_spec, "is adj")})
	else
		insert_form(formtable, "ind_n_sg",
			{form=combine_stem_and_ending(stem,
				(accent_spec.soft_sign_i and "е" or
				accent_spec.soft_sign and "ьо" or "о", accent_spec)
				.. accent, "is adj")})
	end
	insert_form(formtable, "ind_pl",
		{form=combine_stem_and_ending(stem, "и" .. accent, accent_spec, "is adj")})
end


-- Construct the definite objective masculine singular adjective form and other definite forms.
local function generate_adj_definite_forms(formtable, accent_spec, accent, forms)
	insert_forms(formtable, "def_obj_m_sg", map_forms(forms["def_sub_m_sg"],
		function(form) return rsub(form, "т$", "") end))
	insert_forms(formtable, "def_f_sg", map_forms(forms["ind_f_sg"],
		function(form) return form .. "та" end))
	insert_forms(formtable, "def_n_sg", map_forms(forms["ind_n_sg"],
		function(form) return form .. "то" end))
	insert_forms(formtable, "def_pl", map_forms(forms["ind_pl"],
		function(form) return form .. "те" end))
	for _, formobj in ipairs(forms["ind_pl"]) do
		insert_form(formtable, "voc_m_sg",
			{form=formobj.form, footnotes=formobj.footnotes})
		insert_form(formtable, "voc_m_sg",
			{form=formobj.form .. "й", footnotes=formobj.footnotes})
	end
end


-- Handle a list of overriding forms (e.g. the forms specified by "/pl:мо́мце:момци́[a][collective]").
-- FORMS is the list of default forms generated according to the accent spec, and OVERRIDING_FORMS
-- is the list of overriding forms. Both of them are lists of objects of the form
-- {form=FORM, footnotes=FOOTNOTES}. Return the same sort of list. If there are no overriding
-- forms (OVERRIDING_FORMS is nil), the list in FORMS will be returned directly; otherwise a new
-- list of forms will be constructed from OVERRIDING_FORMS. If an element of OVERRIDING_FORMS has
-- the value "+", the forms in FORMS are inserted in its place. LEMMA and STEM are used in handling
-- forms in OVERRIDING_FORMS containing ~ or ~~ in them, replaced respectively lemma and stem.
-- FORMS may be a string such as "dat" or "gen", specifying the name of the overriding form. This
-- indicates that there are no default forms for this slot, and any use of "+" in OVERRIDING_FORMS
-- will cause an error (where the string is inserted into the error message).
local function handle_overriding_forms(lemma, stem, forms, overriding_forms)
	if not overriding_forms then
		if type(forms) == "table" then
			return forms
		else
			return nil
		end
	else
		local retforms = {}
		for _, overriding_spec in ipairs(overriding_forms) do
			local form = overriding_spec.value
			if form == "+" then
				if type(forms) == "string" then
					error("'/" .. forms .. "+' not supported, no default value")
				end
				for _, f in ipairs(forms) do
					insert_form_into_list(retforms, {form=f.form, footnotes=overriding_spec.footnotes})
				end
			else
				form = rsub(form, "~~", stem)
				form = rsub(form, "~", lemma)
				insert_form_into_list(retforms, {form=form, footnotes=overriding_spec.footnotes})
			end
		end
		return retforms
	end
end


-- Decline the noun in DATASPEC (an object as returned by parse_simplified_specification()).
-- This sets the form values in `DATASPEC.forms` for all slots. (If a given slot has no values,
-- it will not be present in `DATASPEC.forms`).
local function decline_noun(dataspec)
	local needs_vocative = false
	local lemma = dataspec.word
	local stem = dataspec.stem
	for _, accent_and_form_spec in ipairs(dataspec.accent_and_form_specs) do
		local n = accent_and_form_spec.n or dataspec.n
		if n == "pl" then
			for _, overriding_form in ipairs(overriding_forms) do
				if accent_and_form_spec[overriding_form] then
					error("'/" .. overriding_form .. ":' not allowed for plurale tantum")
				end
			end
			local plurals = {{form=lemma}}
			insert_forms(dataspec.forms, "ind_pl", plurals)
			if not accent_and_form_spec["-defpl"] then
				insert_forms(dataspec.forms, "def_pl", map_forms(plurals, generate_noun_definite_plural))
			end
			if accent_and_form_spec.accent_spec.vocative then
				needs_vocative = true
			end
		else
			local accent_spec = accent_and_form_spec.accent_spec
			local plurals = {}
			local definite_singulars = {}
			local count_forms = {}
			local vocatives = {}
			for _, plspec in ipairs(accent_spec.plurals) do
				for _, accent in ipairs(accent_spec.accents) do
					insert_form_into_list(plurals,
						{form=generate_noun_plural(dataspec, accent_spec, plspec, accent), footnotes=plspec.footnotes}
					)
				end
			end
			for _, accent in ipairs(accent_spec.accents) do
				insert_form_into_list(definite_singulars,
					{form=generate_noun_definite_singular(dataspec, accent_spec, accent)}
				)
			end
			insert_form_into_list(count_forms, {form=generate_noun_count_form(dataspec, accent_spec)})
			insert_form_into_list(vocatives, {form=generate_noun_vocative(dataspec, accent_spec)})
			if not accent_and_form_spec["-pl"] then
				plurals = handle_overriding_forms(lemma, stem, plurals, accent_and_form_spec.pl)
				insert_forms(dataspec.forms, "ind_pl", plurals)
				if not accent_and_form_spec["-defpl"] then
					insert_forms(dataspec.forms, "def_pl", map_forms(plurals, generate_noun_definite_plural))
				end
			end
			if not accent_and_form_spec["-def"] then
				definite_singulars = handle_overriding_forms(lemma, stem, definite_singulars, accent_and_form_spec.def)
				insert_forms(dataspec.forms, "def_sub_sg", definite_singulars)
				insert_forms(dataspec.forms, "def_obj_sg", map_forms(definite_singulars, generate_noun_definite_objective_singular))
			end
			if not accent_and_form_spec["-count"] then
				insert_forms(dataspec.forms, "count", handle_overriding_forms(lemma, stem, count_forms, accent_and_form_spec.count))
			end
			vocatives = handle_overriding_forms(lemma, stem, vocatives, accent_and_form_spec.voc)
			if vocatives and #vocatives > 0 then
				needs_vocative = true
			end
			insert_forms(dataspec.forms, "voc_sg", vocatives)
			insert_forms(dataspec.forms, "acc_sg", handle_overriding_forms(lemma, stem, "acc", accent_and_form_spec.acc))
			insert_forms(dataspec.forms, "gen_sg", handle_overriding_forms(lemma, stem, "gen", accent_and_form_spec.gen))
			insert_forms(dataspec.forms, "dat_sg", handle_overriding_forms(lemma, stem, "dat", accent_and_form_spec.dat))
			insert_forms(dataspec.forms, "acc_pl", handle_overriding_forms(lemma, stem, "accpl", accent_and_form_spec.accpl))
			insert_forms(dataspec.forms, "gen_pl", handle_overriding_forms(lemma, stem, "genpl", accent_and_form_spec.genpl))
			insert_forms(dataspec.forms, "dat_pl", handle_overriding_forms(lemma, stem, "datpl", accent_and_form_spec.datpl))
		end
	end
	if dataspec.n ~= "pl" then
		dataspec.forms["ind_sg"] = {{form=lemma}}
	end
	if needs_vocative then
		-- don't generate voc_pl unless the vocative was called for; otherwise it will
		-- wrongly display for nouns without vocatives
		dataspec.forms["voc_pl"] = map_forms(dataspec.forms["ind_pl"], function(x) return x end)
	end
end


-- Decline the adjective in DATASPEC (an object as returned by parse_simplified_specification()).
-- This sets the form values in `DATASPEC.forms` for all slots. (If a given slot has no values,
-- it will not be present in `DATASPEC.forms`).
local function decline_adj(dataspec)
	local lemma = dataspec.word
	local stem = dataspec.stem
	for _, accent_and_form_spec in ipairs(dataspec.accent_and_form_specs) do
		local accent_spec = accent_and_form_spec.accent_spec
		local formtable = {}
		for _, accent in ipairs(accent_spec.accents) do
			generate_adj_forms(formtable, accent_spec, accent)
		end
			formtable["ind_pl"] = handle_overriding_forms(lemma, stem, plurals, accent_and_form_spec.pl)
			insert_forms(dataspec.forms, "ind_pl", plurals)
			if not accent_and_form_spec["-defpl"] then
				insert_forms(dataspec.forms, "def_pl", map_forms(plurals, generate_noun_definite_plural))
			end
		end
		if not accent_and_form_spec["-def"] then
			definite_singulars = handle_overriding_forms(lemma, stem, definite_singulars, accent_and_form_spec.def)
			insert_forms(dataspec.forms, "def_sub_sg", definite_singulars)
			insert_forms(dataspec.forms, "def_obj_sg", map_forms(definite_singulars, generate_noun_definite_objective_singular))
		end
		if not accent_and_form_spec["-count"] then
			insert_forms(dataspec.forms, "count", handle_overriding_forms(lemma, stem, count_forms, accent_and_form_spec.count))
		end
		vocatives = handle_overriding_forms(lemma, stem, vocatives, accent_and_form_spec.voc)
		if vocatives and #vocatives > 0 then
			needs_vocative = true
		end
		insert_forms(dataspec.forms, "voc_sg", vocatives)
		insert_forms(dataspec.forms, "acc_sg", handle_overriding_forms(lemma, stem, "acc", accent_and_form_spec.acc))
		insert_forms(dataspec.forms, "gen_sg", handle_overriding_forms(lemma, stem, "gen", accent_and_form_spec.gen))
		insert_forms(dataspec.forms, "dat_sg", handle_overriding_forms(lemma, stem, "dat", accent_and_form_spec.dat))
		insert_forms(dataspec.forms, "acc_pl", handle_overriding_forms(lemma, stem, "accpl", accent_and_form_spec.accpl))
		insert_forms(dataspec.forms, "gen_pl", handle_overriding_forms(lemma, stem, "genpl", accent_and_form_spec.genpl))
		insert_forms(dataspec.forms, "dat_pl", handle_overriding_forms(lemma, stem, "datpl", accent_and_form_spec.datpl))
	end
	if dataspec.n ~= "pl" then
		dataspec.forms["ind_m_sg"] = {{form=lemma}}
	end
end


-- Decline the noun or adjective alternants in ALTERNANT_DATASPEC (an object as returned by
-- parse_simplified_specification_allowing_alternants()). This sets the form values
-- in `ALTERNANT_DATASPEC.forms` for all slots. (If a given slot has no values, it will
-- not be present in `DATASPEC.forms`). It also sets `ALTERNANT_DATASPEC.forms.lemma`,
-- which is a list of strings to use as lemmas (e.g. in the title of the generated table
-- and in accelerators).
local function decline_alternants(alternant_dataspec, is_adj)
	alternant_dataspec.forms = {}
	for _, dataspec in ipairs(alternant_dataspec.alternants) do
		if is_adj then
			decline_adj(dataspec)
		else
			decline_noun(dataspec)
		end
		for _, slot in ipairs(is_adj and adj_slots_list or noun_slots_list) do
			if dataspec.forms[slot] then
				for _, form in ipairs(dataspec.forms[slot]) do
					insert_form(alternant_dataspec.forms, slot, form)
				end
			end
		end
	end
	alternant_dataspec.forms.lemma = {}
	local lemma_slot = is_adj and "ind_m_sg" or alternant_dataspec.n == "pl" and "ind_pl" or "ind_sg"
	for _, form in ipairs(alternant_dataspec.forms[lemma_slot]) do
		m_table.insertIfNot(alternant_dataspec.forms.lemma, form.form)
	end
end


-- Expand a given footnote (as specified by the user, including the surrounding brackets)
-- into the form to be inserted into the final generated table.
local function expand_footnote(note)
	local notetext = rmatch(note, "^%[(.*)%]$")
	assert(notetext)
	if footnote_abbrevs[notetext] then
		notetext = footnote_abbrevs[notetext]
	else
		local split_notes = m_string_utilities.capturing_split(notetext, "<(.-)>")
		for i, split_note in ipairs(split_notes) do
			if i % 2 == 0 then
				split_notes[i] = footnote_abbrevs[split_note]
				if not split_notes[i] then
					error("Unrecognized footnote abbrev: <" .. split_note .. ">")
				end
			end
		end
		notetext = table.concat(split_notes)
	end
	return m_string_utilities.ucfirst(notetext) .. "."
end


-- Convert `ALTERNANT_DATASPEC.forms[SLOT]` (for ALTERNANT_DATASPEC as returned by
-- parse_simplified_specification_allowing_alternants()) for all slots into displayable text.
-- This also sets ALTERNANT_DATASPEC.combined_def_sg to true if the definite subjective and
-- objective singular forms are the same (and hence should be combined in the generated table),
-- and sets ALTERNANT_DATASPEC.forms.footnote to the combined string to insert as a footnote
-- (if there are no footnotes, it will be the empty string).
local function show_forms(alternant_dataspec, is_adj)
	local accel_lemma = alternant_dataspec.forms.lemma[1]
	alternant_dataspec.forms.lemma = table.concat(alternant_dataspec.forms.lemma, ", ")
	local noteindex = 1
	local notes = {}
	local seen_notes = {}

	local function set_forms(from_forms, to_forms, slotslist, raw, combined_def_sg)
		for _, slot in ipairs(slotslist) do
			local forms = from_forms[slot] or {{form="—"}}
			local accel_form = is_adj and adj_slots[slot] or noun_slots[slot]
			local formatted_forms = {}
			-- HACK!
			if combined_def_sg and slot == "def_sub_sg" then
				accel_form = "def|s"
			end
			if forms then
				for i, form in ipairs(forms) do
					local link = (raw or form.form == "—") and form.form or
						m_links.full_link{lang = lang, term = form.form, accel = {
							form = accel_form,
							lemma = accel_lemma,
						}}
					if form.footnotes then
						local link_indices = {}
						for _, footnote in ipairs(form.footnotes) do
							footnote = expand_footnote(footnote)
							local this_noteindex = seen_notes[footnote]
							if not this_noteindex then
								-- Generate a footnote index.
								this_noteindex = noteindex
								noteindex = noteindex + 1
								table.insert(notes, '<sup style="color: red">' .. this_noteindex .. '</sup>' .. footnote)
								seen_notes[footnote] = this_noteindex
							end
							m_table.insertIfNot(link_indices, this_noteindex)
						end
						table.insert(formatted_forms, link .. '<sup style="color: red">' .. table.concat(link_indices, ",") .. '</sup>')
					else
						table.insert(formatted_forms, link)
					end
				end
				to_forms[slot] = table.concat(formatted_forms, "<br />") -- ", "
			end
		end
	end

	if is_adj then
		set_forms(alternant_dataspec.forms, alternant_dataspec.forms, noun_slots_list, false)
	else
		-- For def_sub_sg and def_obj_sg, first compute "raw" (unlinked) forms so we can
		-- compare them properly; linked forms have accelerator info in them which differs
		-- between sub and obj.
		local raw_forms = {}
		set_forms(alternant_dataspec.forms, raw_forms, {"def_sub_sg", "def_obj_sg"}, true)
		-- Then generate the linked forms, using a special accelerator form if the def_sub_sg and def_obj_sg are the same.
		alternant_dataspec.combined_def_sg = raw_forms.def_sub_sg == raw_forms.def_obj_sg
		set_forms(alternant_dataspec.forms, alternant_dataspec.forms, noun_slots_list, false, alternant_dataspec.combined_def_sg)
	end
	if alternant_dataspec.footnote then
		table.insert(notes, alternant_dataspec.footnote)
	end
	alternant_dataspec.forms.footnote = table.concat(notes, "<br />")
end


-- Generate the displayable table of all forms, given ALTERNANT_DATASPEC (as returned by
-- parse_simplified_specification_allowing_alternants()) where show_forms() has already
-- been called to convert `ALTERNANT_DATASPEC.forms` into a table of strings.
local function make_noun_table(alternant_dataspec)
	local num = alternant_dataspec.n
	local forms = alternant_dataspec.forms

	local table_begin = [=[
<div class="NavFrame" style="width: 50%;">
<div class="NavHead" style="background: #eff7ff;">Inflection of {lemma}</div>
<div class="NavContent">
{\op}| border="1px solid #000000" style="border-collapse: collapse; background: #F9F9F9; width: 100%;" class="inflection-table"
! style="width: 33%; background: #d9ebff; " |
! style="font-size: 90%; background: #d9ebff;" | singular
! style="font-size: 90%; background: #d9ebff;" | plural
|-
! style="font-size:90%; background: #eff7ff;" | indefinite
| {ind_sg}
| {ind_pl}
|-
]=]

	local table_cont_def_split = [=[
! style="font-size: 90%; background: #eff7ff;" | definite<br>(subject form)
| {def_sub_sg}
| rowspan="2" | {def_pl}
|-
! style="font-size: 90%; background: #eff7ff;" | definite<br>(object form)
| {def_obj_sg}
]=]

	local table_cont_def_combined = [=[
! style="font-size: 90%; background: #eff7ff;" | definite
| {def_sub_sg}
| {def_pl}
]=]

	local table_cont_count = [=[
|-
! style="font-size: 90%; background: #eff7ff;" | count form
| —
| {count}
]=]

	local table_cont_voc = [=[
|-
! style="font-size: 90%; background: #eff7ff;" | vocative form
| {voc_sg}
| {voc_pl}
]=]

	local table_cont_acc = [=[
|-
! style="font-size: 90%; background: #eff7ff;" | accusative form
| {acc_sg}
| {acc_pl}
]=]

	local table_cont_gen = [=[
|-
! style="font-size: 90%; background: #eff7ff;" | genitive form
| {gen_sg}
| {gen_pl}
]=]

	local table_cont_dat = [=[
|-
! style="font-size: 90%; background: #eff7ff;" | dative form
| {dat_sg}
| {dat_pl}
]=]

	local table_end = [=[
|{\cl}{notes_clause}</div></div>]=]

	local table_sg_begin = [=[
<div class="NavFrame" style="width: 30%;">
<div class="NavHead" style="background: #eff7ff;">Inflection of {lemma}</div>
<div class="NavContent">
{\op}| border="1px solid #000000" style="border-collapse: collapse; background: #F9F9F9; width: 100%;" class="inflection-table"
! style="width: 50%; background: #d9ebff; " |
! style="font-size: 90%; background: #d9ebff;" | singular
|-
! style="font-size:90%; background: #eff7ff;" | indefinite
| {ind_sg}
|-
]=]

	local table_sg_cont_def_split = [=[
! style="font-size: 90%; background: #eff7ff;" | definite<br>(subject form)
| {def_sub_sg}
|-
! style="font-size: 90%; background: #eff7ff;" | definite<br>(object form)
| {def_obj_sg}
]=]

	local table_sg_cont_def_combined = [=[
! style="font-size: 90%; background: #eff7ff;" | definite
| {def_sub_sg}
]=]

	local table_sg_cont_voc = [=[
|-
! style="font-size: 90%; background: #eff7ff;" | vocative form
| {voc_sg}
]=]

	local table_sg_cont_acc = [=[
|-
! style="font-size: 90%; background: #eff7ff;" | accusative form
| {acc_sg}
]=]

	local table_sg_cont_gen = [=[
|-
! style="font-size: 90%; background: #eff7ff;" | genitive form
| {gen_sg}
]=]

	local table_sg_cont_dat = [=[
|-
! style="font-size: 90%; background: #eff7ff;" | dative form
| {dat_sg}
]=]

	local table_pl = [=[
<div class="NavFrame" style="width: 30%;">
<div class="NavHead" style="background: #eff7ff;">Inflection of {lemma}</div>
<div class="NavContent">
{\op}| border="1px solid #000000" style="border-collapse: collapse; background: #F9F9F9; width: 100%;" class="inflection-table"
! style="width: 50%; background: #d9ebff; " |
! style="font-size: 90%; background: #d9ebff;" | plural
|-
! style="font-size:90%; background: #eff7ff;" | indefinite
| {ind_pl}
|-
! style="font-size: 90%; background: #eff7ff;" | definite
| {def_pl}
]=]

	local table_pl_cont_voc = [=[
|-
! style="font-size: 90%; background: #eff7ff;" | vocative form
| {voc_pl}
]=]

	local table_pl_cont_acc = [=[
|-
! style="font-size: 90%; background: #eff7ff;" | accusative form
| {acc_pl}
]=]

	local table_pl_cont_gen = [=[
|-
! style="font-size: 90%; background: #eff7ff;" | genitive form
| {gen_pl}
]=]

	local table_pl_cont_dat = [=[
|-
! style="font-size: 90%; background: #eff7ff;" | dative form
| {dat_pl}
]=]

	local table_spec
	if num == "sg" then
		table_spec = table_sg_begin ..
			(alternant_dataspec.combined_def_sg and table_sg_cont_def_combined or table_sg_cont_def_split) ..
			(forms.voc_sg ~= "—" and table_sg_cont_voc or "") ..
			(forms.acc_sg ~= "—" and table_sg_cont_acc or "") ..
			(forms.gen_sg ~= "—" and table_sg_cont_gen or "") ..
			(forms.dat_sg ~= "—" and table_sg_cont_dat or "") ..
			table_end
	elseif num == "pl" then
		table_spec = table_pl ..
			(forms.voc_pl ~= "—" and table_pl_cont_voc or "") ..
			(forms.acc_pl ~= "—" and table_pl_cont_acc or "") ..
			(forms.gen_pl ~= "—" and table_pl_cont_gen or "") ..
			(forms.dat_pl ~= "—" and table_pl_cont_dat or "") ..
			table_end
	else
		table_spec = table_begin ..
			(alternant_dataspec.combined_def_sg and table_cont_def_combined or table_cont_def_split) ..
			(forms.count ~= "—" and table_cont_count or "") ..
			((forms.voc_sg ~= "—" or forms.voc_pl ~= "—") and table_cont_voc or "") ..
			((forms.acc_sg ~= "—" or forms.acc_pl ~= "—") and table_cont_acc or "") ..
			((forms.gen_sg ~= "—" or forms.gen_pl ~= "—") and table_cont_gen or "") ..
			((forms.dat_sg ~= "—" or forms.dat_pl ~= "—") and table_cont_dat or "") ..
			table_end
	end

	local notes_template = [===[
<div style="width:100%;text-align:left;background:#d9ebff">
<div style="display:inline-block;text-align:left;padding-left:1em;padding-right:1em">
{footnote}
</div></div>
]===]

	alternant_dataspec.forms.notes_clause = alternant_dataspec.forms.footnote ~= "" and m_string_utilities.format(notes_template, alternant_dataspec.forms) or ""
	return m_string_utilities.format(table_spec, alternant_dataspec.forms)
end


-- Generate the displayable table of all adjective forms, given ALTERNANT_DATASPEC (as returned by
-- parse_simplified_specification_allowing_alternants()) where show_forms() has already
-- been called to convert `ALTERNANT_DATASPEC.forms` into a table of strings.
local function make_adj_table(alternant_dataspec)
	local table_spec = [=[
<div class="NavFrame" style="width: 50em;">
<div class="NavHead" style="background: #eff7ff;">{comp} forms of {lemma}</div>
<div class="NavContent">
{\op}| border="1px solid #000000" style="border-collapse: collapse; background: #F9F9F9; width: 100%;" class="inflection-table"
! style="width: 33%; background: #d9ebff; " |
! style="font-size: 90%; background: #d9ebff;" | masculine
! style="font-size: 90%; background: #d9ebff;" | feminine
! style="font-size: 90%; background: #d9ebff;" | neuter
! style="font-size: 90%; background: #d9ebff;" | plural
|-
! style="font-size: 90%; background: #eff7ff;" | indefinite
| {ind_m_sg}
| {ind_f_sg}
| {ind_n_sg}
| {ind_pl}
|-
! style="font-size: 90%; background: #eff7ff;" | definite<br />(subject form)
| {def_sub_m_sg}
| rowspan="2" | {def_f_sg}
| rowspan="2" | {def_n_sg}
| rowspan="2" | {def_pl}
|-
! style="font-size: 90%; background: #eff7ff;" | definite<br />(object form)
| {def_obj_m_sg}
|-
! style="font-size: 90%; background: #eff7ff;" | extended<br />(vocative form)
| {voc_m_sg}
|{\cl}{notes_clause}</div></div>
]=]

	local notes_template = [===[
<div style="width:100%;text-align:left;background:#d9ebff">
<div style="display:inline-block;text-align:left;padding-left:1em;padding-right:1em">
{footnote}
</div></div>
]===]

	alternant_dataspec.forms.notes_clause = alternant_dataspec.forms.footnote ~= "" and m_string_utilities.format(notes_template, alternant_dataspec.forms) or ""
	alternant_dataspec.comp = "Positive"
	local postable = m_string_utilities.format(table_spec, alternant_dataspec.forms)
	local comptable = ""
	local suptable = ""
	if alternant_dataspec.comparable then
		for _, slot in ipairs(slots_list) do
			if alternant_dataspec.forms[slot] ~= "—" then
				alternant_dataspec.forms[slot] = "по-" .. alternant_dataspec.forms[slot]
			end
		end
		alternant_dataspec.comp = "Comparative"
		comptable = m_string_utilities.format(table_spec, alternant_dataspec.forms)
		for _, slot in ipairs(slots_list) do
			alternant_dataspec.forms[slot] = rsub(alternant_dataspec.forms[slot], "^по%-", "най-")
		end
		alternant_dataspec.comp = "Superlative"
		suptable = m_string_utilities.format(table_spec, alternant_dataspec.forms)
	end
	return postable .. comptable .. suptable
end


-- Concatenate all forms of all slots into a single string of the form
-- "SLOT=FORM,FORM,...|SLOT=FORM,FORM,...|...". Embedded pipe symbols (as might occur
-- in embedded links) are converted to <!>. If INCLUDE_PROPS is given, also include
-- additional properties (currently, only "|n=NUMBER"). This is for use by bots.
local function concat_forms(alternant_dataspec, include_props, is_adj)
	local ins_text = {}
	for _, slot in ipairs(is_adj and adj_slots_list_with_linked or noun_slots_list_with_linked) do
		local formtext = concat_forms_in_slot(alternant_dataspec.forms[slot])
		if formtext then
			table.insert(ins_text, slot .. "=" .. formtext)
		end
	end
	if include_props then
		if is_adj then
			table.insert(ins_text, "comp=" .. (alternant_dataspec.comparable and "1" or "0"))
		else
			if alternant_dataspec.n then
				table.insert(ins_text, "n=" .. alternant_dataspec.n)
			end
		end
	end
	return table.concat(ins_text, "|")
end


-- Externally callable function to parse and decline a noun given user-specified arguments.
-- Return value is DATASPEC, an object where the declined forms are in `DATASPEC.forms` for
-- each slot. If there are no values for a slot, the slot key will be missing. The value for
-- a given slot is a list of objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_noun_forms(parent_args, pos, from_headword, def, support_num_type)
	local params = {
		[1] = {required = true, default = def or "бряг<b>"},
		footnote = {},
		title = {},
	}
	if from_headword then
		params.lemma = {list = true}
		params.id = {}
		params.pos = {default = pos}
		params.cat = {list = true}
		params.indecl = {type = "boolean"}
		params.m = {list = true}
		params.f = {list = true}
		params.g = {list = true}
	end
	if support_num_type then
		params["type"] = {}
	end

	local args = m_para.process(parent_args, params)

	if args.title then
		track("overriding-title")
	end
	pos = args.pos or pos -- args.pos only set when from_headword
	
	local alternant_dataspec = parse_simplified_specification_allowing_alternants(args[1])
	detect_all_noun_accent_and_form_specs(alternant_dataspec)
	construct_noun_stems(alternant_dataspec)
	decline_alternants(alternant_dataspec)
	alternant_dataspec.forms.lemma = args.lemma and #args.lemma > 0 and args.lemma or alternant_dataspec.forms.lemma
	return alternant_dataspec
end


-- Externally callable function to parse and decline an adjective given user-specified arguments.
-- Return value is DATASPEC, an object where the declined forms are in `DATASPEC.forms` for
-- each slot. If there are no values for a slot, the slot key will be missing. The value for
-- a given slot is a list of objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_adj_forms(parent_args, pos, from_headword, def, support_num_type)
	local params = {
		[1] = {required = true, default = def or "бял<(я)>"},
		footnote = {},
		title = {},
	}
	if from_headword then
		params.lemma = {list = true}
		params.id = {}
		params.pos = {default = pos}
		params.cat = {list = true}
		params.indecl = {type = "boolean"}
	end
	if support_num_type then
		params["type"] = {}
	end

	local args = m_para.process(parent_args, params)

	if args.title then
		track("overriding-title")
	end
	pos = args.pos or pos -- args.pos only set when from_headword
	
	local alternant_dataspec = parse_simplified_specification_allowing_alternants(args[1])
	detect_all_adj_accent_and_form_specs(alternant_dataspec)
	construct_adj_stems(alternant_dataspec)
	decline_alternants(alternant_dataspec, "is adj")
	alternant_dataspec.forms.lemma = args.lemma and #args.lemma > 0 and args.lemma or alternant_dataspec.forms.lemma
	return alternant_dataspec
end


-- Main entry point for nouns. Template-callable function to parse and decline a noun given
-- user-specified arguments and generate a displayable table of the declined forms.
function export.show_noun(frame)
	local parent_args = frame:getParent().args
	local alternant_dataspec = export.do_generate_noun_forms(parent_args, "nouns")
	show_forms(alternant_dataspec)
	return make_noun_table(alternant_dataspec)
end


-- Main entry point for adjectives. Template-callable function to parse and decline an adjective given
-- user-specified arguments and generate a displayable table of the declined forms.
function export.show_adj(frame)
	local parent_args = frame:getParent().args
	local alternant_dataspec = export.do_generate_adj_forms(parent_args, "adjectives")
	show_forms(alternant_dataspec, "is adj")
	return make_adj_table(alternant_dataspec)
end


-- Template-callable function to parse and decline a noun given user-specified arguments and return
-- the forms as a string "SLOT=FORM,FORM,...|SLOT=FORM,FORM,...|...". Embedded pipe symbols (as might
-- occur in embedded links) are converted to <!>. If |include_props=1 is given, also include
-- additional properties (currently, only "|n=NUMBER"). This is for use by bots.
function export.generate_noun_forms(frame)
	local include_props = frame.args["include_props"]
	local parent_args = frame:getParent().args
	local alternant_dataspec = export.do_generate_noun_forms(parent_args, "nouns")

	return concat_forms(alternant_dataspec, include_props)
end


-- Template-callable function to parse and decline an adjective given user-specified arguments and return
-- the forms as a string "SLOT=FORM,FORM,...|SLOT=FORM,FORM,...|...". Embedded pipe symbols (as might
-- occur in embedded links) are converted to <!>. If |include_props=1 is given, also include
-- additional properties (currently, only "|comp=1" if comparable). This is for use by bots.
function export.generate_adj_forms(frame)
	local include_props = frame.args["include_props"]
	local parent_args = frame:getParent().args
	local alternant_dataspec = export.do_generate_adj_forms(parent_args, "adjectives")

	return concat_forms(alternant_dataspec, include_props)
end


return export
